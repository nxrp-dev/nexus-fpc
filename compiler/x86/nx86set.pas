{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Generate x86 assembler for in/case nodes

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

 ****************************************************************************
}
unit nx86set;

{$i fpcdefs.inc}

interface

    uses
      GlobType,ConstExp,
      node,nset,pass_1,ncgset;

    type
       TX86InNode = class(TInNode)
         procedure pass_generate_code;override;
         function pass_1 : TNode;override;
       end;

      TX86CaseNode = class(TCGCaseNode)
         function  has_jumptable : boolean;override;
         procedure genjumptable(hp : PCaseLabel;min_,max_ : int64);override;
         procedure genlinearlist(hp : PCaseLabel);override;
         procedure genjmptreeentry(p : PCaseLabel;parentvalue : TConstExprInt);override;
      end;

implementation

    uses
      Systems,
      Verbose,Globals,
      symconst,symdef,defutil,CUtils,
      aasmbase,aasmtai,AAsmData,aasmcpu,
      cgbase,pass_2,tgobj,
      ncon,
      cpubase,
      cga,cgobj,hlcgobj,cgutils,ncgutil,
      cgx86,
      ProcInfo;

{*****************************************************************************
                                  TX86CASENODE
*****************************************************************************}

    function TX86CaseNode.has_jumptable : boolean;
      begin
        has_jumptable:=true;
      end;


    procedure TX86CaseNode.genjumptable(hp : PCaseLabel;min_,max_ : int64);
      var
        table : TAsmLabel;
        last : TConstExprInt;
        indexreg : TRegister;
        href : TReference;
        jtlist: TAsmList;
        opcgsize: TCgSize;
        jumpreg: TRegister;
        labeltyp: TAIConstType;
        AlmostExhaustive: Boolean;
        lv, hv: TConstExprInt;
        ExhaustiveLimit, Range, x, oldmin : int64;

      const
        ExhaustiveLimitBase = 32;

        procedure genitem(list:TAsmList;t : PCaseLabel);
          var
            i : TConstExprInt;
          begin
            if Assigned(t^.less) then
              genitem(list,t^.less);

            { fill possible hole }
            i:=last+1;
            while i<=t^._low-1 do
              begin
                list.concat(TAIConst.Create_type_sym(labeltyp,elselabel));
                i:=i+1;
              end;
            i:=t^._low;
            while i<=t^._high do
              begin
                list.concat(TAIConst.Create_type_sym(labeltyp,blocklabel(t^.blockid)));
                i:=i+1;
              end;
            last:=t^._high;
            if Assigned(t^.greater) then
              genitem(list,t^.greater);
          end;

      begin
        lv:=0;
        hv:=0;
        oldmin:=0;
        last:=min_;
        { This generates near pointers on i8086 }
        labeltyp:=aitconst_ptr;
        opcgsize:=Def_CGSize(opsize);

        AlmostExhaustive := False;

        if not(jumptable_no_range) then
          begin

            GetRange(left.resultdef,lv,hv);
            Range := aint(max_)-aint(min_);

            if (cs_opt_size in CurrentSettings.OptimizerSwitches) then
              { Limit size of jump tables for small enumerations so they have
                to be at least two-thirds full before being considered for the
                "almost exhaustive" treatment }
              ExhaustiveLimit := min(ExhaustiveLimitBase, labelcoverage shl 1)
            else
              ExhaustiveLimit := ExhaustiveLimitBase;

            { If true, then this indicates that almost every possible value of x is covered by
              a label.  As such, it's more cost-efficient to remove the initial range check and
              instead insert the remaining values into the jump table, pointing at elselabel. [Kit] }
            if ((hv - lv) - Range <= ExhaustiveLimit) then
              begin
                oldmin := min_;
                min_ := lv.svalue;
                AlmostExhaustive := True;
              end
            else
              begin
                { a <= x <= b <-> unsigned(x-a) <= (b-a) }
                cg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_SUB,opcgsize,aint(min_),hregister);
                { case expr greater than max_ => goto elselabel }
                cg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,opcgsize,OC_A,aint(max_)-aint(min_),hregister,elselabel);
                min_:=0;
                { do not sign extend when we load the index register, as we applied an offset above }
                opcgsize:=TCgSize2Unsigned[opcgsize];
              end;
          end;

        CurrentAsmData.getdatalabel(table);
        { make it a 32bit register }
        indexreg:=cg.MakeRegSize(CurrentAsmData.CurrAsmList,hregister,OS_INT);
        cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,opcgsize,OS_INT,hregister,indexreg);
        { create reference }
        Reference_Reset_Symbol(href,table,0,sizeof(PInt),[]);
        href.Offset:=(-aint(min_))*sizeof(aint);
        href.Index:=indexreg;

        href.ScaleFactor:=sizeof(aint);


        if (not (TargetInfo.system in [system_i386_darwin,system_i386_iphonesim])) and
           (cs_create_pic in CurrentSettings.ModuleSwitches) then
          begin
            labeltyp:=aitconst_gotoff_symbol;
            jumpreg:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_ADDR);
            cg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,OS_ADDR,OS_ADDR,href,jumpreg);
            cg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,OP_ADD,OS_ADDR,CurrentProcInfo.got,jumpreg);
            emit_reg(A_JMP,S_NO,jumpreg);
            include(CurrentProcInfo.flags,pi_needs_got);
          end
        else
          emit_ref(A_JMP,S_NO,href);
        { generate jump table }
        if (TargetInfo.system in [system_i386_darwin,system_i386_iphonesim]) then
          jtlist:=CurrentAsmData.asmlists[al_const]
        else
          jtlist:=CurrentProcInfo.AktLocalData;
        new_section(jtlist,sec_rodata,CurrentProcInfo.procdef.MangledName,sizeof(aint));
        jtlist.concat(TAILabel.Create(table));

        if AlmostExhaustive then
          begin
            { Fill the table with the values below _min }
            x := lv.svalue;
            while x < oldmin do
              begin
                jtlist.concat(TAIConst.Create_type_sym(labeltyp, elselabel));
                Inc(x);
              end;

            genitem(jtlist,hp);

            { Fill the table with the values above _max }
            { Subtracting one from hv and not adding 1 to max averts the risk of an overflow }
            x := max_;
            hv := hv - 1;
            while x <= hv.svalue do
              begin
                jtlist.concat(TAIConst.Create_type_sym(labeltyp, elselabel));
                Inc(x);
              end;
          end
        else
          genitem(jtlist,hp)
      end;


    procedure TX86CaseNode.genlinearlist(hp : PCaseLabel);
      var
        first : boolean;
        lastrange : boolean;
        last : TConstExprInt;
        cond_lt,cond_le : TResFlags;
        opcgsize: TCgSize;

        procedure genitem(t : PCaseLabel);
          var
             range, gap, extra: aint;
          begin
             if Assigned(t^.less) then
               genitem(t^.less);
             { need we to test the first value }
             if first and (t^._low>Get_Min_Value(left.resultdef)) then
               begin
                 cg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,opcgsize,jmp_lt,aint(t^._low.svalue),hregister,elselabel);
               end;
             if t^._low=t^._high then
               begin
                  if t^._low-last=0 then
                    cg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList, opcgsize, OC_EQ,0,hregister,blocklabel(t^.blockid))
                  else
                    begin
                      cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
                      cg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList, OP_SUB, opcgsize, aint(t^._low.svalue-last.svalue), hregister);
                      cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,F_E,blocklabel(t^.blockid));
                      cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
                    end;
                  last:=t^._low;
                  lastrange:=false;
               end
             else
               begin
                  range := aint(t^._high.svalue - t^._low.svalue);
                  extra := 0;
                  { it begins with the smallest label, if the value }
                  { is even smaller then jump immediately to the    }
                  { ELSE-label                                }
                  cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
                  if first then
                    begin
                       { have we to adjust the first value ? }
                       if (t^._low>Get_Min_Value(left.resultdef)) or (Get_Min_Value(left.resultdef)<>0) then
                         cg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList, OP_SUB, opcgsize, aint(t^._low.svalue), hregister);
                    end
                  else
                    begin
                      gap := aint(t^._low.svalue - last.svalue);
                      { if there is no unused label between the last and the }
                      { present label then the lower limit can be checked    }
                      { immediately. else check the range in between:       }

                      { we need to use A_SUB, if cond_lt uses the carry flags
                        because A_DEC does not set the correct flags, therefor
                        using a_op_const_reg(OP_SUB) is not possible }
                      if (gap = 1) and (cond_lt in [F_C,F_NC,F_A,F_AE,F_B,F_BE]) then
                        extra := 1
                      else
                        cg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList, OP_SUB, opcgsize, gap, hregister);
                      { no jump necessary here if the new range starts at
                        at the value following the previous one           }
                      if (gap <> 1) or
                         (not lastrange) then
                        cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,cond_lt,elselabel);
                    end;
                  { we need to use A_SUB, if cond_le uses the carry flags
                    because A_DEC does not set the correct flags, therefor
                    using a_op_const_reg(OP_SUB) is not possible }
                  if (cond_le in [F_C,F_NC,F_A,F_AE,F_B,F_BE]) and (range = 1) then
                    emit_const_reg(A_SUB,TCGSize2OpSize[opcgsize], range + extra, hregister)
                  else
                    cg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList, OP_SUB, opcgsize, range + extra, hregister);

                  cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,cond_le,blocklabel(t^.blockid));
                  cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
                  last:=t^._high;
                  lastrange:=true;
               end;
             first:=false;
             if Assigned(t^.greater) then
               genitem(t^.greater);
          end;

        begin
           opcgsize:=Def_CGSize(opsize);
           if with_sign then
             begin
                cond_lt:=F_L;
                cond_le:=F_LE;
             end
           else
              begin
                cond_lt:=F_B;
                cond_le:=F_BE;
             end;
           { do we need to generate cmps? }

           if (with_sign and (min_label<0)) then

             genlinearcmplist(hp)
           else
             begin
                if (labelcnt>1) or not(cs_opt_level1 in CurrentSettings.OptimizerSwitches) then
                  begin
                    last:=0;
                    lastrange:=false;
                    first:=true;
                    genitem(hp);
                  end
                else
                  begin
                    { If only one label exists, we can greatly simplify the checks to a simple comparison }
                    if hp^._low=hp^._high then
                      cg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList, opcgsize, OC_EQ, TCGInt(hp^._low.svalue), hregister, blocklabel(hp^.blockid))
                    else
                      begin
                        cg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList, OP_SUB, opcgsize, TCGInt(hp^._low.svalue), hregister);
                        cg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList, opcgsize, OC_BE, TCGInt(hp^._high.svalue - hp^._low.svalue), hregister,blocklabel(hp^.blockid));
                      end;
                  end;
                cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,elselabel);
             end;
        end;

      procedure TX86CaseNode.genjmptreeentry(p : PCaseLabel;parentvalue : TConstExprInt);
        var
          lesslabel,greaterlabel : TAsmLabel;
          cond_gt: TResFlags;
          cmplow : Boolean;
        begin
           if with_sign then
             cond_gt:=F_G
           else
             cond_gt:=F_A;
          CurrentAsmData.CurrAsmList.concat(CAIAlign.Create(CurrentSettings.Alignment.JumpAlign));
          cg.A_Label(CurrentAsmData.CurrAsmList,p^.labellabel);

          { calculate labels for left and right }
          if p^.less=nil then
            lesslabel:=elselabel
          else
            lesslabel:=p^.less^.labellabel;
          if p^.greater=nil then
            greaterlabel:=elselabel
          else
            greaterlabel:=p^.greater^.labellabel;

          { calculate labels for left and right }
          { no range label: }
          if p^._low=p^._high then
            begin
              if greaterlabel=lesslabel then
                hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,opsize,OC_NE,p^._low,hregister,lesslabel)
              else
                begin
                  cmplow:=p^._low-1<>parentvalue;
                  if cmplow then
                    hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,opsize,jmp_lt,p^._low,hregister,lesslabel);
                  if p^._high+1<>parentvalue then
                    begin
                      if cmplow then
                        hlcg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,cond_gt,greaterlabel)
                      else
                        hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,opsize,jmp_gt,p^._low,hregister,greaterlabel);
                    end;
                end;
              hlcg.A_Jmp_Always(CurrentAsmData.CurrAsmList,blocklabel(p^.blockid));
            end
          else
            begin
              if p^._low-1<>parentvalue then
                hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,opsize,jmp_lt,p^._low,hregister,lesslabel);
              if p^._high+1<>parentvalue then
                hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,opsize,jmp_gt,p^._high,hregister,greaterlabel);
              hlcg.A_Jmp_Always(CurrentAsmData.CurrAsmList,blocklabel(p^.blockid));
            end;
           if Assigned(p^.less) then
             genjmptreeentry(p^.less,p^._low);
           if Assigned(p^.greater) then
             genjmptreeentry(p^.greater,p^._high);
        end;


{*****************************************************************************
                              TX86INNODE
*****************************************************************************}

    function TX86InNode.pass_1 : TNode;
      begin
         result:=nil;
         { this is the only difference from the generic version }
         expectloc:=LOC_FLAGS;

         FirstPass(right);
         FirstPass(left);
         if CodeGenError then
           exit;
      end;

    procedure TX86InNode.pass_generate_code;
       type
         Tsetpart=record
           range : boolean;      {Part is a range.}
           start,stop : byte;    {Start/stop when range; Stop=element when an element.}
         end;
       var
         hreg, hreg2,
         pleftreg   : TRegister;
         opsize     : TCgSize;
         opdef      : TOrdDef;
         orgopsize  : TCgSize;
         setparts   : array[1..8] of Tsetpart;
         SetBase    : aint;
         adjustment : LongInt;
         l,l2       : TAsmLabel;
         i,numparts : byte;
         genjumps,
         use_small,
         ranges     : boolean;
{$ifdef CORRECT_SET_IN_FPC}
         AM         : TAsmOp;
{$endif CORRECT_SET_IN_FPC}


         function analizeset(Aset:PConstSet;is_small:boolean):boolean;
           var
             compares,maxcompares:word;
             i:byte;
           begin
             if TNormalSet(Aset^)=[] then
                {The expression...
                    if expr in []
                 ...is always false. It should be optimized away in the
                 resultdef pass, and thus never occur here. Since we
                 do generate wrong code for it, do internalerror.}
                InternalError(2002072301);
             analizeset:=false;
             ranges:=false;
             numparts:=0;
             compares:=0;
             { Lots of comparisons take a lot of time, so do not allow
               too much comparisons. 8 comparisons are, however, still
               smaller than emitting the set }
             if cs_opt_size in CurrentSettings.OptimizerSwitches then
               maxcompares:=8
             else
               maxcompares:=5;
             { when smallset is possible allow only 3 compares the smallset
               code is for littlesize also smaller when more compares are used }
             if is_small then
               maxcompares:=3;
             for i:=0 to 255 do
              if i in TNormalSet(Aset^) then
               begin
                 if (numparts=0) or (i<>setparts[numparts].stop+1) then
                  begin
                  {Set element is a separate element.}
                    inc(compares);
                    if compares>maxcompares then
                         exit;
                    inc(numparts);
                    setparts[numparts].range:=false;
                    setparts[numparts].stop:=i;
                  end
                 else
                  {Set element is part of a range.}
                  if not setparts[numparts].range then
                   begin
                     {Transform an element into a range.}
                     setparts[numparts].range:=true;
                     setparts[numparts].start:=setparts[numparts].stop;
                     setparts[numparts].stop:=i;
                     ranges := true;
                   end
                  else
                   begin
                    {Extend a range.}
                    setparts[numparts].stop:=i;
                   end;
              end;
             analizeset:=true;
           end;



       begin
         ranges:=false;
         numparts:=0;
         fillchar(setparts,sizeof(setparts),0);

         { We check first if we can generate jumps, this can be done
           because the resultdef is already set in firstpass }

         { check if we can use smallset operation using btl which is limited
           to 32 bits, the left side may also not contain higher values or be signed !! }
         use_small:=Is_SmallSet(right.resultdef) and
                    not Is_Signed(left.resultdef) and
                    ((left.resultdef.typ=orddef) and (TOrdDef(left.resultdef).high.svalue<32) or
                     (left.resultdef.typ=enumdef) and (TEnumDef(left.resultdef).max<32));

         { Can we generate jumps? Possible for all types of sets }
         genjumps:=(right.nodetype=setconstn) and
                   analizeset(TSetConstNode(right).value_set,use_small);
         { calculate both operators }
         { the complex one first }
         { not in case of genjumps, because then we don't secondpass    }
         { right at all (so we have to make sure that "right" really is }
         { "right" and not "swapped left" in that case)                 }
         if not(genjumps) then
           firstcomplex(self);
         SecondPass(left);
         { Only process the right if we are not generating jumps }
         if not genjumps then
          begin
            SecondPass(right);
          end;
         if CodeGenError then
          exit;

         { of course not commutative }
         if nf_swapped in flags then
          swapleftright;

         orgopsize := Def_CGSize(left.resultdef);

         opsize := OS_32;

         if Is_Signed(left.resultdef) then
           opsize := TCgSize(ord(opsize)+(ord(OS_S8)-ord(OS_8)));
         opdef:=CGSize_OrdDef(opsize);

         if not(left.Location.Loc in [LOC_REGISTER,LOC_CREGISTER,LOC_REFERENCE,LOC_CREFERENCE,LOC_CONSTANT]) then
           hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,opdef,true);
         if (right.Location.Loc in [LOC_SUBSETREG,LOC_CSUBSETREG]) then
           hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,right.Location,left.resultdef,opdef,true);

         if genjumps then
          begin
            { It gives us advantage to check for the set elements
              separately instead of using the SET_IN_BYTE procedure.
              To do: Build in support for LOC_JUMP }

            { load and zero or sign extend as necessary }
            hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,opdef,false);
            pleftreg:=left.Location.Register;

            { Get a label to jump to the end }
            Location_Reset(location,LOC_FLAGS,OS_NO);

            { It's better to use the zero flag when there are
              no ranges }
            if ranges then
              location.ResFlags:=F_C
            else
              location.ResFlags:=F_E;

            CurrentAsmData.getjumplabel(l);

            { how much have we already subtracted from the x in the  }
            { "x in [y..z]" expression                               }
            adjustment := 0;

            cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);

            for i:=1 to numparts do
             if setparts[i].range then
              { use fact that a <= x <= b <=> cardinal(x-a) <= cardinal(b-a) }
              begin
                { is the range different from all legal values? }
                if (setparts[i].stop-setparts[i].start <> 255) or not (orgopsize = OS_8) then
                  begin
                    { yes, is the lower bound <> 0? }
                    if (setparts[i].start <> 0) then
                      begin
                        hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,opdef,false);
                        hreg:=left.Location.Register;
                        pleftreg:=hreg;
                        cg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_SUB,opsize,setparts[i].start-adjustment,pleftreg);
                      end;

                    { new total value subtracted from x:            }
                    { adjustment + (setparts[i].start - adjustment) }
                    adjustment := setparts[i].start;

                    { check if result < b-a+1 (not "result <= b-a", since }
                    { we need a carry in case the element is in the range }
                    { (this will never overflow since we check at the     }
                    { beginning whether stop-start <> 255)                }
                    cg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,opsize,OC_B,setparts[i].stop-setparts[i].start+1,pleftreg,l);
                    cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
                  end
                else
                  { if setparts[i].start = 0 and setparts[i].stop = 255,  }
                  { it's always true since "in" is only allowed for bytes }
                  begin
                    CurrentAsmData.CurrAsmList.concat(TAICPU.op_none(A_STC,S_NO));
                    cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,l);
                  end;
              end
             else
              begin
                { Emit code to check if left is an element }
                CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg(A_CMP,TCGSize2OpSize[opsize],setparts[i].stop-adjustment,
                  pleftreg));
                { Result should be in carry flag when ranges are used }
                if ranges then
                  CurrentAsmData.CurrAsmList.concat(TAICPU.op_none(A_STC,S_NO));
                { If found, jump to end }
                cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,F_E,l);
              end;
             if ranges and
                { if the last one was a range, the carry flag is already }
                { set appropriately                                      }
                not(setparts[numparts].range) then
                  CurrentAsmData.CurrAsmList.concat(TAICPU.op_none(A_CLC,S_NO));
             { To compensate for not doing a second pass }
             right.Location.Reference.Symbol:=nil;
             { Now place the end label }
             cg.A_Label(CurrentAsmData.CurrAsmList,l);
          end
         else
          begin
            Location_Reset(location,LOC_FLAGS,OS_NO);
            SetBase:=TSetDef(right.resultdef).SetBase;

            { We will now generated code to check the set itself, no jmps,
              handle smallsets separate, because it allows faster checks }
            if use_small then
             begin
               if left.Location.Loc=LOC_CONSTANT then
                begin
                  cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
                  location.ResFlags:=F_NE;
                  case right.Location.Loc of
                    LOC_REGISTER,
                    LOC_CREGISTER:
                      begin
                         emit_const_reg(A_TEST,TCGSize2OpSize[right.Location.Size],
                           1 shl ((left.Location.Value-SetBase) and 31),right.Location.Register);
                      end;
                    LOC_REFERENCE,
                    LOC_CREFERENCE :
                      begin
                        emit_const_ref(A_TEST,TCGSize2OpSize[right.Location.Size],1 shl ((left.Location.Value-SetBase) and 31),
                           right.Location.Reference);
                      end;
                    else
                      InternalError(200203312);
                  end;
                end
               else
                begin

                  hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,U32IntType,true);
                  register_maybe_adjust_setbase(CurrentAsmData.CurrAsmList,U32IntType,left.Location,SetBase);

                  if (TCgSize2Size[right.Location.Size] < opdef.Size) or
                    (right.Location.Loc = LOC_CONSTANT) or
                    { bt ...,[mem] is slow, see #40039, so try to use a register if we are not optimizing for size }
                    ((right.resultdef.Size<=U32IntType.Size) and not(cs_opt_size in CurrentSettings.OptimizerSwitches)) then
                    hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,right.Location,right.resultdef,U32IntType,true);

                  hreg:=left.Location.Register;

                  cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
                  case right.Location.Loc of
                    LOC_REGISTER,
                    LOC_CREGISTER :
                      begin
                        emit_reg_reg(A_BT,S_L,hreg,right.Location.Register);
                      end;
                     LOC_CREFERENCE,
                     LOC_REFERENCE :
                       begin
                         emit_reg_ref(A_BT,S_L,hreg,right.Location.Reference);
                       end;
                     else
                       InternalError(2002032210);
                  end;
                  location.ResFlags:=F_C;

                end;
             end
            else
             begin
               if right.Location.Loc=LOC_CONSTANT then
                begin

                  location.ResFlags:=F_C;
                  CurrentAsmData.getjumplabel(l);
                  CurrentAsmData.getjumplabel(l2);

                  { load constants to a register }
                  if (left.Location.Loc=LOC_CONSTANT) or
                     (SetBase<>0) then
                    begin
                      hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,opdef,true);
                      register_maybe_adjust_setbase(CurrentAsmData.CurrAsmList,opdef,left.Location,SetBase);
                    end;

                  case left.Location.Loc of
                     LOC_REGISTER,
                     LOC_CREGISTER:
                       begin
                          hreg:=cg.MakeRegSize(CurrentAsmData.CurrAsmList,left.Location.Register,opsize);
                          cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,left.Location.Size,opsize,left.Location.Register,hreg);
                          cg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,opsize,OC_BE,31,hreg,l);
                          cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
                          { reset carry flag }
                          CurrentAsmData.CurrAsmList.concat(TAICPU.op_none(A_CLC,S_NO));
                          cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,l2);
                          cg.A_Label(CurrentAsmData.CurrAsmList,l);
                          { We have to load the value into a register because
                            btl does not accept values only refs or regs (PFV) }
                          hreg2:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
                          cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,OS_32,right.Location.Value,hreg2);
                          emit_reg_reg(A_BT,S_L,hreg,hreg2);
                       end;
                     else
                       begin
                          cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
                          emit_const_ref(A_CMP,TCGSize2OpSize[orgopsize],31,left.Location.Reference);
                          cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,F_BE,l);
                          { reset carry flag }
                          CurrentAsmData.CurrAsmList.concat(TAICPU.op_none(A_CLC,S_NO));
                          cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,l2);
                          cg.A_Label(CurrentAsmData.CurrAsmList,l);
                          hreg:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
                          cg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,OS_32,OS_32,left.Location.Reference,hreg);
                          { We have to load the value into a register because
                            btl does not accept values only refs or regs (PFV) }
                          hreg2:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
                          cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,OS_32,right.Location.Value,hreg2);
                          emit_reg_reg(A_BT,S_L,hreg,hreg2);
                       end;
                  end;
                  cg.A_Label(CurrentAsmData.CurrAsmList,l2);

                end { of right.location.loc=LOC_CONSTANT }
               { do search in a normal set which could have >32 elementsm
                 but also used if the left side contains values > 32 or < 0 }
               else if left.Location.Loc=LOC_CONSTANT then
                begin
                  if (left.Location.Value<SetBase) or (((left.Location.Value-SetBase) shr 3) >= right.resultdef.Size) then
                    {should be caught earlier }
                    InternalError(2007020201);

                  location.ResFlags:=F_NE;
                  case right.Location.Loc of
                    LOC_REFERENCE,LOC_CREFERENCE:
                      begin
                        inc(right.Location.Reference.Offset,(left.Location.Value-SetBase) shr 3);
                        cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
                        emit_const_ref(A_TEST,S_B,1 shl ((left.Location.Value-SetBase) and 7),right.Location.Reference);
                      end;
                    LOC_REGISTER,LOC_CREGISTER:
                      begin
                        cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
                        emit_const_reg(A_TEST,TCGSize2OpSize[right.Location.Size],1 shl (left.Location.Value-SetBase),right.Location.Register);
                      end;
                    else
                      InternalError(2007051901);
                  end;
                end
               else
                begin

                  hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,opdef,false);
                  register_maybe_adjust_setbase(CurrentAsmData.CurrAsmList,opdef,left.Location,SetBase);

                  if (right.Location.Loc in [LOC_REGISTER,LOC_CREGISTER]) or
                    { bt ...,[mem] is slow, see #40039, so try to use a register if we are not optimizing for size }
                    ((right.resultdef.Size<=opdef.Size) and not(cs_opt_size in CurrentSettings.OptimizerSwitches)) then
                    hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,right.Location,right.resultdef,opdef,true);

                  pleftreg:=left.Location.Register;

                  if (opsize >= OS_S8) or { = if signed }
                     ((left.resultdef.typ=orddef) and
                      ((TOrdDef(left.resultdef).low < int64(TSetDef(right.resultdef).SetBase)) or
                       (TOrdDef(left.resultdef).high > int64(TSetDef(right.resultdef).SetMax)))) or
                     ((left.resultdef.typ=enumdef) and
                      ((TEnumDef(left.resultdef).min < aint(TSetDef(right.resultdef).SetBase)) or
                       (TEnumDef(left.resultdef).max > aint(TSetDef(right.resultdef).SetMax)))) then
                    begin
                      { we have to check if the value is < 0 or > setmax }

                      CurrentAsmData.getjumplabel(l);
                      CurrentAsmData.getjumplabel(l2);

                      { BE will be false for negative values }
                      cg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,opsize,OC_BE,TSetDef(right.resultdef).SetMax-TSetDef(right.resultdef).SetBase,pleftreg,l);
                      cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
                      { reset carry flag }
                      CurrentAsmData.CurrAsmList.concat(TAICPU.op_none(A_CLC,S_NO));
                      cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,l2);

                      cg.A_Label(CurrentAsmData.CurrAsmList,l);

                      pleftreg:=left.Location.Register;
                      case right.Location.Loc of
                        LOC_REGISTER, LOC_CREGISTER :
                          emit_reg_reg(A_BT,S_L,pleftreg,right.Location.Register);
                        LOC_CREFERENCE, LOC_REFERENCE :
                          emit_reg_ref(A_BT,S_L,pleftreg,right.Location.Reference);
                      else
                        InternalError(2007020301);
                      end;

                      cg.A_Label(CurrentAsmData.CurrAsmList,l2);

                      location.ResFlags:=F_C;
                    end
                  else
                    begin
                      cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
                      case right.Location.Loc of
                        LOC_REGISTER, LOC_CREGISTER :
                          emit_reg_reg(A_BT,S_L,pleftreg,right.Location.Register);
                        LOC_CREFERENCE, LOC_REFERENCE :
                          emit_reg_ref(A_BT,S_L,pleftreg,right.Location.Reference);
                      else
                        InternalError(2007020302);
                      end;
                      location.ResFlags:=F_C;
                    end;

                end;
             end;
          end;
          if not genjumps then
            location_freetemp(CurrentAsmData.CurrAsmList,right.Location);
       end;

begin
   CInNode:=TX86InNode;
   CCaseNode:=TX86CaseNode;
end.
