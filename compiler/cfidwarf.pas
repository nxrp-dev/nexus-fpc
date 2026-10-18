{
    Copyright (c) 2003-2004 by Peter Vreman and Florian Klaempfl

    This units contains special support for DWARF debug info

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
unit cfidwarf;

{$i fpcdefs.inc}

{ $define debug_eh}

interface

    uses
      CClasses,
      GlobType,
      cgbase,cpubase,
      aasmbase,aasmcfi,aasmtai,AAsmData;

    const
      maxdwarfops = 2;

    type
      TDwarfOperEnc=(doe_uleb,doe_sleb,doe_ptr,doe_32bit,doe_16bit,doe_8bit);
      TDwarfOperType=(dop_reg,dop_const,dop_sym,dop_reloffset);

      TDwarfOper=record
        enc : TDwarfOperEnc;
        case typ:TDwarfOperType of
          dop_reg : (register:TRegister);
          dop_const : (value:int64);
          dop_sym : (sym:TAsmSymbol);
          dop_reloffset : (beginsym,endsym:TAsmSymbol);
      end;

      TDwarfItem=class(TLinkedListItem)
        op   : byte;
        ops  : byte;
        oper : array[0..maxdwarfops-1] of TDwarfOper;
        constructor Create(aop:byte);
        constructor create_reg(aop:byte;enc1:TDwarfOperEnc;reg:TRegister);
        constructor create_const(aop:byte;enc1:TDwarfOperEnc;val:int64);
        constructor create_sym(aop: byte; enc1: TDwarfOperEnc; sym: TAsmSymbol);
        constructor create_reloffset(aop:byte;enc1:TDwarfOperEnc;beginlab,endlab:TAsmSymbol);
        constructor create_reg_const(aop:byte;enc1:TDwarfOperEnc;reg:TRegister;enc2:TDwarfOperEnc;val:LongInt);
        procedure Generate_Code(list:TAsmList);
      end;

      TDwarfAsmCFI=class(TAsmCFI)
      public type
        TDataType = (
          dt_none,
          dt_debug,
          dt_eh_frame
        );
      public
        datatype : TDataType;
        constructor Create;override;
      end;

      TDwarfAsmCFILowLevel=class(TDwarfAsmCFI)
      private
        FDwarfList : TLinkedList;
        FFrameStartLabel,
        FFrameEndLabel,
        FLastloclabel : TAsmLabel;
        procedure cfa_advance_loc(list:TAsmList);
        procedure generate_initial_instructions(list:TAsmList);virtual;
      protected
        code_alignment_factor,
        data_alignment_factor : shortint;
        property DwarfList:TLinkedList read FDwarfList;
      public
        constructor Create;override;
        destructor Destroy;override;
        procedure Generate_Code(list:TAsmList);override;

        function get_frame_start: TAsmLabel;override;
        function get_cfa_list : TAsmList;override;

        { operations }
        procedure start_frame(list:TAsmList);override;
        procedure end_frame(list:TAsmList);override;
        procedure outmost_frame(list: TAsmList);override;
        procedure cfa_offset(list:TAsmList;reg:TRegister;ofs:LongInt);override;
        procedure cfa_restore(list:TAsmList;reg:TRegister);override;
        procedure cfa_def_cfa(list:TAsmList;reg:TRegister;ofs:LongInt);override;
        procedure cfa_def_cfa_register(list:TAsmList;reg:TRegister);override;
        procedure cfa_def_cfa_offset(list:TAsmList;ofs:LongInt);override;
      end;


      TDwarfAsmCFIHighLevel=class(TDwarfAsmCFILowLevel)
      public
        procedure Generate_Code(list:TAsmList);override;

        { operations }
        procedure start_frame(list:TAsmList);override;
        procedure end_frame(list:TAsmList);override;
        procedure outmost_frame(list: TAsmList);override;
        procedure cfa_offset(list:TAsmList;reg:TRegister;ofs:LongInt);override;
        procedure cfa_restore(list:TAsmList;reg:TRegister);override;
        procedure cfa_def_cfa(list:TAsmList;reg:TRegister;ofs:LongInt);override;
        procedure cfa_def_cfa_register(list:TAsmList;reg:TRegister);override;
        procedure cfa_def_cfa_offset(list:TAsmList;ofs:LongInt);override;
      end;

implementation

    uses
      Systems,Globals,
      CUtils,
      Verbose,
      dwarfbase;

{****************************************************************************
                                TDWARFITEM
****************************************************************************}

    constructor TDwarfItem.Create(aop:byte);
      begin
        inherited Create;
        op:=aop;
        ops:=0;
      end;


    constructor TDwarfItem.create_reg(aop:byte;enc1:TDwarfOperEnc;reg:TRegister);
      begin
        inherited Create;
        op:=aop;
        ops:=1;
        oper[0].typ:=dop_reg;
        oper[0].enc:=enc1;
        oper[0].Register:=reg;
      end;


    constructor TDwarfItem.create_const(aop:byte;enc1:TDwarfOperEnc;val:int64);
      begin
        inherited Create;
        op:=aop;
        ops:=1;
        oper[0].typ:=dop_const;
        oper[0].enc:=enc1;
        oper[0].Value:=val;
      end;


    constructor TDwarfItem.create_sym(aop:byte;enc1:TDwarfOperEnc;sym:TAsmSymbol);
      begin
        inherited Create;
        op:=aop;
        ops:=1;
        oper[0].typ:=dop_sym;
        oper[0].enc:=enc1;
        oper[0].sym:=sym;
      end;


    constructor TDwarfItem.create_reloffset(aop:byte;enc1:TDwarfOperEnc;beginlab,endlab:TAsmSymbol);
      begin
        inherited Create;
        op:=aop;
        ops:=1;
        { relative offsets are passed }
        oper[0].typ:=dop_reloffset;
        oper[0].enc:=enc1;
        oper[0].beginsym:=beginlab;
        oper[0].endsym:=endlab;
      end;


    constructor TDwarfItem.create_reg_const(aop:byte;enc1:TDwarfOperEnc;reg:TRegister;enc2:TDwarfOperEnc;val:LongInt);
      begin
        inherited Create;
        op:=aop;
        ops:=2;
        oper[0].typ:=dop_reg;
        oper[0].enc:=enc1;
        oper[0].Register:=reg;
        oper[1].typ:=dop_const;
        oper[1].enc:=enc2;
        oper[1].Value:=val;
      end;


    procedure TDwarfItem.Generate_Code(list:TAsmList);
      const
        enc2ait_const : array[TDwarfOperEnc] of TAIConstType = (
          aitconst_uleb128bit,aitconst_sleb128bit,aitconst_ptr,
          aitconst_32bit,aitconst_16bit,aitconst_8bit
        );
      var
        i : integer;
      begin
        list.concat(TAIConst.create_8bit(op));
        for i:=0 to ops-1 do
          begin
            case oper[i].typ of
              dop_const :
                list.concat(TAIConst.Create(enc2ait_const[oper[i].enc],oper[i].Value));
              dop_sym :
                begin
                  if oper[i].enc<>doe_ptr then
                    InternalError(200404127);
                  list.concat(TAIConst.create_sym(oper[i].sym));
                end;
              dop_reloffset :
                list.concat(TAIConst.create_rel_sym(enc2ait_const[oper[i].enc],oper[i].beginsym,oper[i].endsym));
              dop_reg :
                list.concat(TAIConst.Create(enc2ait_const[oper[i].enc],dwarf_reg(oper[i].Register)));
            end;
          end;
      end;


{****************************************************************************
                                 TDwarfAsmCFI
****************************************************************************}

    constructor TDwarfAsmCFI.Create;
      begin
        inherited;
        if tf_use_psabieh in TargetInfo.flags then
          datatype:=dt_eh_frame
        else
          { The CFI-information is always generated, regardless of the debug
            settings. This way the CFI-information for units is always available
            and during linking it can be omitted or not, based on the debug
            settings. }
          datatype:=dt_debug;
      end;

{****************************************************************************
                             TDwarfAsmCFILowLevel
****************************************************************************}

    constructor TDwarfAsmCFILowLevel.Create;
      begin
        inherited Create;
        FFrameStartLabel:=nil;
        FFrameEndLabel:=nil;
        FLastLocLabel:=nil;
        code_alignment_factor:=1;
        data_alignment_factor:=-4;
        FDwarfList:=TAsmList.Create;
      end;


    destructor TDwarfAsmCFILowLevel.Destroy;
      begin
        FDwarfList.Free;
        FDwarfList := nil;
      end;


{$if defined(i386)}
    { if more cpu dependent stuff is implemented, this needs more refactoring }
    procedure TDwarfAsmCFILowLevel.generate_initial_instructions(list:TAsmList);
      begin
        list.concat(TAIConst.create_8bit(DW_CFA_def_cfa));
        list.concat(TAIConst.create_uleb128bit(dwarf_reg(NR_STACK_POINTER_REG)));
        list.concat(TAIConst.create_uleb128bit(sizeof(aint)));
        list.concat(TAIConst.create_8bit(DW_CFA_offset_extended));
        list.concat(TAIConst.create_uleb128bit(dwarf_reg(NR_RETURN_ADDRESS_REG)));
        list.concat(TAIConst.create_uleb128bit((-sizeof(aint)) div data_alignment_factor));
      end;
{$elseif defined(aarch64)}
    procedure TDwarfAsmCFILowLevel.generate_initial_instructions(list:TAsmList);
      begin
        list.concat(TAIConst.create_8bit(DW_CFA_def_cfa));
        list.concat(TAIConst.create_uleb128bit(dwarf_reg(NR_STACK_POINTER_REG)));
        list.concat(TAIConst.create_uleb128bit(0));
      end;
{$else}
    { if more cpu dependent stuff is implemented, this needs more refactoring }
    procedure TDwarfAsmCFILowLevel.generate_initial_instructions(list:TAsmList);
      begin
        list.concat(TAIConst.create_8bit(DW_CFA_def_cfa));
        list.concat(TAIConst.create_uleb128bit(dwarf_reg(NR_STACK_POINTER_REG)));
        list.concat(TAIConst.create_uleb128bit(sizeof(aint)));
        list.concat(TAIConst.create_8bit(DW_CFA_offset_extended));
        list.concat(TAIConst.create_uleb128bit(dwarf_reg(NR_RETURN_ADDRESS_REG)));
        list.concat(TAIConst.create_uleb128bit((-sizeof(aint)) div data_alignment_factor));
      end;
{$endif}

    procedure TDwarfAsmCFILowLevel.Generate_Code(list:TAsmList);
      var
        hp : TDwarfItem;
        CurrentLSDALabel,
        cielabel,
        lenstartlabel,
        lenendlabel,
        augendlabel,
        augstartlabel,
        fdeofslabel, curpos: TAsmLabel;
        tc             : TAIConst;
      begin
        if DwarfList.Empty then
          exit;
        CurrentLSDALabel:=nil;
        case datatype of
          dt_none:
            exit;
          dt_debug:
            new_section(list,sec_debug_frame,'',0);
          dt_eh_frame:
            new_section(list,sec_eh_frame,'',0);
        end;
        { debug_frame:
            CIE
             DWORD   length
             DWORD   CIE_Id = 0xffffffff
             BYTE    version = 1
             STRING  augmentation = "" = BYTE 0
             ULEB128 code alignment factor = 1
             ULEB128 data alignment factor = -1
             BYTE    return address register
             <...>   augmentation
             <...>   start sequence

          eh_frame:
            CIE
             DWORD   length
             DWORD   CIE_Id = 0
             BYTE    version = 1
             STRING  augmentation = 'zPLR'#0
             ULEB128 code alignment factor = 1
             ULEB128 data alignment factor = -1
             BYTE    return address register
             <...>   start sequence

        }
        CurrentAsmData.getlabel(cielabel,alt_dbgframe);
        list.concat(TAILabel.Create(cielabel));
        CurrentAsmData.getlabel(lenstartlabel,alt_dbgframe);
        CurrentAsmData.getlabel(lenendlabel,alt_dbgframe);
        list.concat(TAIConst.create_rel_sym(aitconst_32bit,lenstartlabel,lenendlabel));
        list.concat(TAILabel.Create(lenstartlabel));
        if datatype=dt_eh_frame then
          begin
            list.concat(TAIConst.create_32bit(0));
            list.concat(TAIConst.create_8bit(1));
            list.concat(TAIConst.create_8bit(ord('z')));
            list.concat(TAIConst.create_8bit(ord('P')));
            list.concat(TAIConst.create_8bit(ord('L')));
            list.concat(TAIConst.create_8bit(ord('R')));
            list.concat(TAIConst.create_8bit(0));
          end
        else
          begin
            list.concat(TAIConst.create_32bit(LongInt($ffffffff)));
            list.concat(TAIConst.create_8bit(1));
            list.concat(TAIConst.create_8bit(0)); { empty string }
          end;
        list.concat(TAIConst.create_uleb128bit(code_alignment_factor));
        list.concat(TAIConst.create_sleb128bit(data_alignment_factor));
        list.concat(TAIConst.create_8bit(dwarf_reg(NR_RETURN_ADDRESS_REG)));
        { augmentation data }
        if datatype=dt_eh_frame then
          begin
            CurrentAsmData.getlabel(augstartlabel,alt_dbgframe);
            CurrentAsmData.getlabel(augendlabel,alt_dbgframe);
            { size of augmentation data ('z') }
            list.concat(TAIConst.create_rel_sym(aitconst_uleb128bit,augstartlabel,augendlabel));
            list.concat(TAILabel.Create(augstartlabel));
            { personality function ('P') }
            { encoding }
            list.concat(TAIConst.create_8bit({DW_EH_PE_indirect or DW_EH_PE_pcrel or} DW_EH_PE_sdata4));
            { address of personality function }
            list.concat(TAIConst.Createname('_FPC_psabieh_personality_v0',AT_FUNCTION,0));

            { LSDA encoding  ('L')}
            list.concat(TAIConst.create_8bit({DW_EH_PE_pcrel or }DW_EH_PE_sdata4));

            { FDE encoding ('R') }
            list.concat(TAIConst.create_8bit({DW_EH_PE_pcrel or }DW_EH_PE_sdata4));
            list.concat(TAILabel.Create(augendlabel));
          end;

        { Generate standard code
            def_cfa(stackpointer,sizeof(aint))
            cfa_offset_extended(returnaddres,-sizeof(aint))
        }
        generate_initial_instructions(list);

        list.concat(CAIAlign.create_zeros(sizeof(PInt)));
        list.concat(TAILabel.Create(lenendlabel));
        lenstartlabel:=nil;
        lenendlabel:=nil;

        hp:=TDwarfItem(DwarfList.first);
        while Assigned(hp) do
          begin
            case hp.op of
              DW_CFA_Start_Frame :
                begin
                  if Assigned(lenstartlabel) then
                    InternalError(200404125);
                  if (hp.ops<>1) or
                     (hp.oper[0].typ<>dop_reloffset) then
                    InternalError(200404126);
                  CurrentAsmData.getlabel(lenstartlabel,alt_dbgframe);
                  CurrentAsmData.getlabel(lenendlabel,alt_dbgframe);
                  { FDE
                     DWORD length
                     DWORD CIE-pointer = cielabel relative to section start
                     PTRSIZE initial location = oper[0]
                     PTRSIZE function size = oper[1]
                  }
                  list.concat(TAIConst.create_rel_sym(aitconst_32bit,lenstartlabel,lenendlabel));
                  list.concat(TAILabel.Create(lenstartlabel));
                  if datatype=dt_eh_frame then
                    begin
                      { relative offset to the CIE }
                      CurrentAsmData.getlabel(fdeofslabel,alt_dbgframe);
                      list.concat(TAILabel.Create(fdeofslabel));
                      list.concat(TAIConst.create_rel_sym(aitconst_32bit,cielabel,fdeofslabel));
                    end
                  else
                    begin
                      { according to the dwarf (2 to 4) standard, this is an uword being always 32 bit unsigned }
                      tc:=TAIConst.create_type_sym(aitconst_32bit,cielabel);
                      { force label offset to secrel32 for windows systems }
                      if (TargetInfo.system in systems_windows) then
                        tc.consttype:=aitconst_secrel32_symbol;
                      list.concat(tc);
                    end;

                  CurrentAsmData.getlabel(curpos,alt_dbgframe);
                  list.concat(TAILabel.Create(curpos));
                  list.concat(TAIConst.Create_sym(hp.oper[0].beginsym));
                  list.concat(TAIConst.create_rel_sym(aitconst_ptr,hp.oper[0].beginsym,hp.oper[0].endsym));

                  { we wrote a 'z' into the CIE augmentation data }
                  if datatype=dt_eh_frame then
                    begin
                      { size of augmentation }
                      list.concat(TAIConst.create_8bit(sizeof(PInt)));
{$ifdef debug_eh}
                      list.concat(TAIComment.Create(StrPNew('LSDA')));
{$endif debug_eh}
                      { address of LSDA}
                      list.concat(TAIConst.Create_sym(CurrentLSDALabel));
                      { do not reuse LSDA label }
                      CurrentLSDALabel:=nil;
                    end;
                end;
              DW_CFA_End_Frame :
                begin
                  list.concat(CAIAlign.create_zeros(sizeof(PInt)));
                  list.concat(TAILabel.Create(lenendlabel));
                  lenstartlabel:=nil;
                  lenendlabel:=nil;
                end;
              DW_Set_LSDALabel:
                CurrentLSDALabel:=hp.oper[0].sym as TAsmLabel;
              else
                hp.Generate_Code(list);
            end;
            hp:=TDwarfItem(hp.next);
          end;
        { Check for open frames }
        if Assigned(lenstartlabel) then
          InternalError(2004041210);
        { DwarfList is processed, remove items }
        DwarfList.Clear;
      end;


    procedure TDwarfAsmCFILowLevel.start_frame(list:TAsmList);
      begin
        if datatype=dt_none then
          exit;
        CurrentAsmData.getlabel(FFrameEndLabel,alt_dbgframe);
        FLastloclabel:=get_frame_start;
        list.concat(TAILabel.Create(get_frame_start));
        DwarfList.concat(TDwarfItem.create_reloffset(DW_CFA_start_frame,doe_32bit,get_frame_start,FFrameEndLabel));
      end;


    function TDwarfAsmCFILowLevel.get_frame_start : TAsmLabel;
      begin
        if not(Assigned(FFrameStartLabel)) then
          CurrentAsmData.getlabel(FFrameStartLabel,alt_dbgframe);
        Result:=FFrameStartLabel;
      end;


    function TDwarfAsmCFILowLevel.get_cfa_list: TAsmList;
      begin
       Result:=TAsmList(DwarfList);
      end;


    procedure TDwarfAsmCFILowLevel.outmost_frame(list: TAsmList);
      begin
        if datatype=dt_none then
          exit;
        cfa_advance_loc(list);
        DwarfList.concat(TDwarfItem.create_reg(DW_CFA_undefined,doe_uleb,NR_RETURN_ADDRESS_REG));
      end;


    procedure TDwarfAsmCFILowLevel.end_frame(list:TAsmList);
      begin
        if datatype=dt_none then
          exit;
        if not Assigned(FFrameStartLabel) then
          InternalError(2004041213);
        DwarfList.concat(TDwarfItem.Create(DW_CFA_end_frame));
        list.concat(TAILabel.Create(FFrameEndLabel));
        FFrameStartLabel:=nil;
        FFrameEndLabel:=nil;
        FLastLocLabel:=nil;
      end;


    procedure TDwarfAsmCFILowLevel.cfa_advance_loc(list:TAsmList);
      var
        currloclabel : TAsmLabel;
        hp : TAI;
        instrcount : LongInt;
        dwarfloc: Integer;
      begin
        if FLastloclabel=nil then
          InternalError(200404082);
        { search the list backwards and check if we really need an advance loc,
          i.e. if real code/data has been generated since the last cfa_advance_loc
          call
        }
        hp:=TAI(list.Last);
        while Assigned(hp) do
          begin
            { if we encounter FLastloclabel without encountering code/data, see check below,
              we do not need insert an advance_loc entry }
            if (hp.typ=ait_label) and (TAILabel(hp).LabSym=FLastloclabel) then
              exit;
            { stop if we find any tai which results in code or data }
            if not(hp.typ in ([ait_label]+SkipInstr)) then
              break;
            hp:=TAI(hp.Previous);
          end;

        { check if the last advance entry is less then 8 instructions away:
          as x86 instructions might not be bigger than 15 bytes and most other
          CPUs use only 4 byte instructions or smaller, this is safe
          we could search even more but this takes more time and 8 instructions should be normally enough
        }
        hp:=TAI(list.Last);
        instrcount:=0;
        dwarfloc:=DW_CFA_advance_loc4;
        while Assigned(hp) and (instrcount<8) do
          begin
            { stop if we find any tai which results in code or data }
            if not(hp.typ in ([ait_label,ait_instruction]+SkipInstr)) then
              break;
            if (hp.typ=ait_label) and (TAILabel(hp).LabSym=FLastloclabel) then
              begin
                dwarfloc:=DW_CFA_advance_loc1;
                break;
              end;
            if hp.typ=ait_instruction then
              inc(instrcount);
            hp:=TAI(hp.Previous);
          end;

        CurrentAsmData.getlabel(currloclabel,alt_dbgframe);
        list.concat(TAILabel.Create(currloclabel));
        if dwarfloc=DW_CFA_advance_loc1 then
          DwarfList.concat(TDwarfItem.create_reloffset(DW_CFA_advance_loc1,doe_8bit,FLastloclabel,currloclabel))
        else
          DwarfList.concat(TDwarfItem.create_reloffset(DW_CFA_advance_loc4,doe_32bit,FLastloclabel,currloclabel));
        FLastloclabel:=currloclabel;
      end;


    procedure TDwarfAsmCFILowLevel.cfa_offset(list:TAsmList;reg:TRegister;ofs:LongInt);
      begin
        if datatype=dt_none then
          exit;
        cfa_advance_loc(list);
{ TODO: check if ref is a temp}
        { offset must be positive }
        DwarfList.concat(TDwarfItem.create_reg_const(DW_CFA_offset_extended,doe_uleb,reg,doe_uleb,ofs div data_alignment_factor));
      end;


    procedure TDwarfAsmCFILowLevel.cfa_restore(list:TAsmList;reg:TRegister);
      begin
        if datatype=dt_none then
          exit;
        cfa_advance_loc(list);
        DwarfList.concat(TDwarfItem.create_reg(DW_CFA_restore_extended,doe_uleb,reg));
      end;


    procedure TDwarfAsmCFILowLevel.cfa_def_cfa(list:TAsmList;reg:TRegister;ofs:LongInt);
      begin
        if datatype=dt_none then
          exit;
        cfa_advance_loc(list);
        DwarfList.concat(TDwarfItem.create_reg_const(DW_CFA_def_cfa,doe_uleb,reg,doe_uleb,ofs));
      end;


    procedure TDwarfAsmCFILowLevel.cfa_def_cfa_register(list:TAsmList;reg:TRegister);
      begin
        if datatype=dt_none then
          exit;
        cfa_advance_loc(list);
        DwarfList.concat(TDwarfItem.create_reg(DW_CFA_def_cfa_register,doe_uleb,reg));
      end;


    procedure TDwarfAsmCFILowLevel.cfa_def_cfa_offset(list:TAsmList;ofs:LongInt);
      begin
        if datatype=dt_none then
          exit;
        cfa_advance_loc(list);
        DwarfList.concat(TDwarfItem.create_const(DW_CFA_def_cfa_offset,doe_uleb,ofs));
      end;


{****************************************************************************
                             TDwarfAsmCFILowLevel
****************************************************************************}


    procedure TDwarfAsmCFIHighLevel.Generate_Code(list: TAsmList);
      begin
        if not(tf_use_hlcfi in TargetInfo.flags) then
          begin
            inherited;
            exit;
          end;
      end;


    procedure TDwarfAsmCFIHighLevel.start_frame(list: TAsmList);
      begin
        if not(tf_use_hlcfi in TargetInfo.flags) then
          begin
            inherited;
            exit;
          end;
        if not(af_supports_hlcfi in TargetAsm.flags) then
          exit;
        list.concat(TAICFIOpNone.Create(cfi_startproc));
      end;


    procedure TDwarfAsmCFIHighLevel.end_frame(list: TAsmList);
      begin
        if not(tf_use_hlcfi in TargetInfo.flags) then
          begin
            inherited;
            exit;
          end;
        if not(af_supports_hlcfi in TargetAsm.flags) then
          exit;
        list.concat(TAICFIOpNone.Create(cfi_endproc));
      end;


    procedure TDwarfAsmCFIHighLevel.outmost_frame(list: TAsmList);
      begin
        if not(tf_use_hlcfi in TargetInfo.flags) then
          begin
            inherited;
            exit;
          end;
        if not(af_supports_hlcfi in TargetAsm.flags) then
          exit;
        list.concat(TAICFIOpReg.Create(cfi_undefined,NR_RETURN_ADDRESS_REG));
      end;


    procedure TDwarfAsmCFIHighLevel.cfa_offset(list: TAsmList; reg: TRegister; ofs: LongInt);
      begin
        if not(tf_use_hlcfi in TargetInfo.flags) then
          begin
            inherited;
            exit;
          end;
        if not(af_supports_hlcfi in TargetAsm.flags) then
          exit;
        list.concat(TAICFIOpRegVal.Create(cfi_offset,reg,ofs));
      end;


    procedure TDwarfAsmCFIHighLevel.cfa_restore(list: TAsmList; reg: TRegister);
      begin
        if not(tf_use_hlcfi in TargetInfo.flags) then
          begin
            inherited;
            exit;
          end;
        if not(af_supports_hlcfi in TargetAsm.flags) then
          exit;
        list.concat(TAICFIOpReg.Create(cfi_restore,reg));
      end;


    procedure TDwarfAsmCFIHighLevel.cfa_def_cfa(list: TAsmList; reg: TRegister; ofs: LongInt);
      begin
        if not(tf_use_hlcfi in TargetInfo.flags) then
          begin
            inherited;
            exit;
          end;
        if not(af_supports_hlcfi in TargetAsm.flags) then
          exit;
        list.concat(TAICFIOpRegVal.Create(cfi_def_cfa,reg,ofs));
      end;


    procedure TDwarfAsmCFIHighLevel.cfa_def_cfa_register(list: TAsmList; reg: TRegister);
      begin
        if not(tf_use_hlcfi in TargetInfo.flags) then
          begin
            inherited;
            exit;
          end;
        if not(af_supports_hlcfi in TargetAsm.flags) then
          exit;
        list.concat(TAICFIOpReg.Create(cfi_def_cfa_register,reg));
      end;


    procedure TDwarfAsmCFIHighLevel.cfa_def_cfa_offset(list: TAsmList; ofs: LongInt);
      begin
        if not(tf_use_hlcfi in TargetInfo.flags) then
          begin
            inherited;
            exit;
          end;
        if not(af_supports_hlcfi in TargetAsm.flags) then
          exit;
        list.concat(TAICFIOpVal.Create(cfi_def_cfa_offset,ofs));
      end;


begin
  CAsmCFI:=TDwarfAsmCFIHighLevel;
end.
