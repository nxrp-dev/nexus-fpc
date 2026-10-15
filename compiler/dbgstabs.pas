{
    Copyright (c) 2003-2004 by Peter Vreman and Florian Klaempfl

    This units contains support for STABS debug info generation

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
unit dbgstabs;

{$i fpcdefs.inc}

interface

    uses
      TPCompilerReal,
      CClasses,
      Systems,DbgBase,cgbase,
      symconst,symtype,symdef,SymSym,SymTable,SymBase,
      aasmtai,AAsmData;

    const
      { stab types }
      STABS_N_GSYM = $20;
      STABS_N_STSYM = 38;     { initialized const }
      STABS_N_LCSYM = 40;     { non initialized variable}
      STABS_N_Function = $24; { function or const }
      STABS_N_TextLine = $44;
      STABS_N_DataLine = $46;
      STABS_N_BssLine = $48;
      STABS_N_RSYM = $40;     { register variable }
      STABS_N_LSYM = $80;
      STABS_N_DECL = $8c;
      STABS_N_RPSYM = $8e;
      STABS_N_tsym = 160;
      STABS_N_SourceFile = $64;
{ APPLE LOCAL N_OSO: This is the stab that associated the .o file with the
   N_SO stab, in the case where debug info is mostly stored in the .o file.  }
      STABS_N_OSO        = $66;
      STABS_N_IncludeFile = $84;
      STABS_N_BINCL = $82;
      STABS_N_EINCL = $A2;
      STABS_N_LBRAC = $C0;
      STABS_N_EXCL  = $C2;
      STABS_N_RBRAC = $E0;

    type
      TDebugInfoStabs=class(TDebugInfo)
      protected
        dbgtype: TDbg;
        stabsdir: TStabType;
        def_stab,
        regvar_stab,
        procdef_stab,
        constsym_stab,
        typesym_stab,
        globalvarsym_uninited_stab,
        globalvarsym_inited_stab,
        staticvarsym_uninited_stab,
        staticvarsym_inited_stab,
        localvarsymref_stab,
        paravarsymref_stab: byte;
        writing_def_stabs  : boolean;
        global_stab_number : word;
        vardatadef: TRecordDef;
        tagtypeprefix: AnsiString;
        function use_tag_prefix(def : TDef) : boolean;
        { tsym writing }
        function  sym_var_value(const s:string;arg:pointer):string;
        function  sym_stabstr_evaluate(sym:TSym;const s:string;const vars:array of string):AnsiString;
        procedure write_sym_stabstr(list:TAsmList;sym:TSym;const ss:AnsiString);
        function  staticvarsym_mangled_name(sym: TStaticVarSym):string;virtual;
        procedure maybe_add_vmt_sym(list:TAsmList;def: TObjectDef);virtual;
        { tdef writing }
        function  def_stab_number(def:TDef):string;
        function  def_stab_classnumber(def:TAbstractRecordDef):string;
        function  def_var_value(const s:string;arg:pointer):string;
        function  def_stabstr_evaluate(def:TDef;const s:string;const vars:array of string):AnsiString;
        procedure write_def_stabstr(list:TAsmList;def:TDef;const ss:AnsiString);virtual;
        procedure field_add_stabstr(p:TObject;arg:pointer);
        procedure method_add_stabstr(p:TObject;arg:pointer);
        procedure field_write_defs(p:TObject;arg:pointer);
        function  get_enum_defstr(def: TEnumDef; lowerbound: LongInt): AnsiString;
        function  get_appendsym_paravar_reg(sym:TParaVarSym;const typ,stabstr:string;reg: TRegister): AnsiString;
        function  base_stabs_str(typ: LongInt; const other, desc, value: AnsiString): AnsiString;overload;
        function  base_stabs_str(const typ, other, desc, value: AnsiString): AnsiString;overload;virtual;
        function  gen_procdef_startsym_stabs(def: TProcDef): TAsmList;virtual;
        function  gen_procdef_endsym_stabs(def: TProcDef): TAsmList;virtual;
      protected
        procedure appendsym_staticvar(list:TAsmList;sym:TStaticVarSym);override;
        procedure appendsym_paravar(list:TAsmList;sym:TParaVarSym);override;
        procedure appendsym_localvar(list:TAsmList;sym:TLocalVarSym);override;
        procedure appendsym_fieldvar(list:TAsmList;sym:TFieldVarSym);override;
        procedure appendsym_const(list:TAsmList;sym:TConstSym);override;
        procedure appendsym_type(list:TAsmList;sym:TTypeSym);override;
        procedure appendsym_label(list:TAsmList;sym:TLabelSym);override;
        procedure beforeappenddef(list:TAsmList;def:TDef);override;
        procedure appenddef_ord(list:TAsmList;def:TOrdDef);override;
        procedure appenddef_float(list:TAsmList;def:TFloatDef);override;
        procedure appenddef_file(list:TAsmList;def:TFileDef);override;
        procedure appenddef_enum(list:TAsmList;def:TEnumDef);override;
        procedure appenddef_array(list:TAsmList;def:TArrayDef);override;
        procedure appenddef_record(list:TAsmList;def:TRecordDef);override;
        procedure appenddef_object(list:TAsmList;def:TObjectDef);override;
        procedure appenddef_pointer(list:TAsmList;def:TPointerDef);override;
        procedure appenddef_string(list:TAsmList;def:TStringDef);override;
        procedure appenddef_procvar(list:TAsmList;def:TProcVarDef);override;
        procedure appenddef_variant(list:TAsmList;def:TVariantDef);override;
        procedure appenddef_set(list:TAsmList;def:TSetDef);override;
        procedure appenddef_formal(list:TAsmList;def:TFormalDef);override;
        procedure appenddef_undefined(list:TAsmList;def: TUndefinedDef);override;
        procedure appendprocdef(list:TAsmList;def:TProcDef);override;
      public
        procedure inserttypeinfo;override;
        procedure insertmoduleinfo;override;
        procedure insertlineinfo(list:TAsmList);override;
        procedure referencesections(list:TAsmList);override;

        constructor Create;override;
      end;


    function GetSymTableName(SymTable : TSymTable) : string;

    const
      tagtypes = [
        recorddef,
        variantdef,
        enumdef,
        stringdef,
        filedef,
        objectdef
      ];


implementation

    uses
      SysUtils,CUtils,CFileUtl,
      Globals,GlobType,Verbose,ConstExp,
      defutil, cgutils, parabase,
      CPUInfo,cpubase,cpupi,paramgr,
      aasmbase,ProcInfo,
      FinPut,FModule,PPU,
      symutil;


    var
      current_procdef : TProcDef = nil;

    function GetOffsetStr(reference : TReference) : string;
    begin
      GetOffsetStr:=ToStr(reference.offset);
    end;

    function GetParaOffsetStr(reference : TCGParaReference) : string;
    begin
      GetParaOffsetStr:=ToStr(reference.offset);
    end;

    function GetSymName(Sym : TSymEntry) : string;
    begin
      if Not (cs_stabs_preservecase in CurrentSettings.GlobalSwitches) then
        result := Sym.Name
      else
        result := Sym.RealName;
      if (Sym.typ=typesym) and (TTypeSym(Sym).Fprettyname<>'') then
        result:=TTypeSym(Sym).FPrettyName;
      if TargetAsm.dollarsign<>'$' then
        result:=ApplyAsmSymbolRestrictions(result);
    end;

    function GetSymTableName(SymTable : TSymTable) : string;
    begin
      if Not (cs_stabs_preservecase in CurrentSettings.GlobalSwitches) then
        result := SymTable.Name^
      else
        result := SymTable.RealName^;
      if TargetAsm.dollarsign<>'$' then
        result:=ApplyAsmSymbolRestrictions(result);
    end;

    const
      memsizeinc = 512;

    type
       TGetVarValueProc=function(const s:string;arg:pointer):string of object;


    function string_evaluate(s:string;get_var_value:TGetVarValueProc;get_var_value_arg:pointer;const vars:array of string):AnsiString;
    (*
     S contains a prototype of a result. Stabstr_evaluate will expand
     variables and parameters.

     Output is s in ASCIIZ format, with the following expanded:

     ${varname}   - The variable name is expanded.
     $n           - The parameter n is expanded.
     $$           - Is expanded to $
    *)

    const maxvalue=9;
          maxdata=1023;

    var i,j:byte;
        varname:string[63];
        varno,varcounter:byte;
        varvalues:array[0..9] of PShortString;
        {1 kb of parameters is the limit. 256 extra bytes are allocated to
         ensure buffer integrity.}
        varvaluedata:array[0..maxdata+256] of char;
        varptr:Pchar;
        varidx : byte;
        len:LongInt;
        r:Pchar;

    begin
      {Two pass approach, first, calculate the length and receive variables.}
      i:=1;
      len:=0;
      varcounter:=0;
      varptr:=@varvaluedata[0];
      varvalues[0]:=nil;
      result:='';
      while i<=length(s) do
        begin
          if (s[i]='$') and (i<length(s)) then
            begin
             if s[i+1]='$' then
               begin
                 inc(len);
                 inc(i);
               end
             else if (s[i+1]='{') and (length(s)>2) and (i<length(s)-2) then
               begin
                 varname:='';
                 inc(i,2);
                 repeat
                   inc(varname[0]);
                   varname[length(varname)]:=s[i];
                   s[i]:=char(varcounter);
                   inc(i);
                 until s[i]='}';
                 varvalues[varcounter]:=PShortString(varptr);
                 if varptr>@varvaluedata[maxdata] then
                   InternalErrorProc(200411152);
                 PShortString(varptr)^:=get_var_value(varname,get_var_value_arg);
                 inc(len,length(PShortString(varptr)^));
                 inc(varptr,length(PShortString(varptr)^)+1);
                 inc(varcounter);
               end
             else if s[i+1] in ['1'..'9'] then
               begin
                 varidx:=byte(s[i+1])-byte('1');
                 if varidx>high(vars) then
                   InternalError(200509263);
                 inc(len,length(vars[varidx]));
                 inc(i);
               end;
            end
          else
            inc(len);
          inc(i);
        end;

      {Second pass, writeout result.}
      SetLength(result,len);
      r:=pchar(result);
      i:=1;
      while i<=length(s) do
        begin
          if (s[i]='$') and (i<length(s)) then
            begin
             if s[i+1]='$' then
               begin
                 r^:='$';
                 inc(r);
                 inc(i);
               end
             else if (s[i+1]='{') and (length(s)>2) and (i<length(s)-2) then
               begin
                 varname:='';
                 inc(i,2);
                 varno:=byte(s[i]);
                 repeat
                   inc(i);
                 until s[i]='}';
                 for j:=1 to length(varvalues[varno]^) do
                   begin
                     r^:=varvalues[varno]^[j];
                     inc(r);
                   end;
               end
             else if s[i+1] in ['0'..'9'] then
               begin
                 for j:=1 to length(vars[byte(s[i+1])-byte('1')]) do
                   begin
                     r^:=vars[byte(s[i+1])-byte('1')][j];
                     inc(r);
                   end;
                 inc(i);
               end
            end
          else
            begin
              r^:=s[i];
              inc(r);
            end;
          inc(i);
        end;
      { verify that the length was correct }
      if r^<>#0 then
        InternalError(200802031);
    end;


{****************************************************************************
                               TDef support
****************************************************************************}

    function TDebugInfoStabs.def_stab_number(def:TDef):string;
      begin
        { procdefs only need a number, mark them as already written
          so they won't be written implicitly }
        if (def.typ=procdef) then
          def.dbg_state:=dbg_state_written;

        { Stab must already be written, or we must be busy writing it }
        if writing_def_stabs and
           not(def.dbg_state in [dbg_state_writing,dbg_state_written,dbg_state_queued]) then
          InternalError(200403091);

        { Keep track of used stabs, this info is only useful for stabs
          referenced by the symbols. Definitions will always include all
          required stabs }
        if def.dbg_state=dbg_state_unused then
          begin
            def.dbg_state:=dbg_state_used;
            deftowritelist.Add(def);
          end;
        { Need a new number? }
        if def.stab_number=0 then
          begin
            inc(global_stab_number);
            { classes require 2 numbers }
            if is_class(def) then
              inc(global_stab_number);
            def.stab_number:=global_stab_number;
            if global_stab_number>=defnumberlist.count then
              defnumberlist.count:=global_stab_number+250;
            defnumberlist[global_stab_number]:=def;
          end;
        result:=ToStr(def.stab_number);
      end;


    function TDebugInfoStabs.def_stab_classnumber(def:TAbstractRecordDef):string;
      begin
        if def.stab_number=0 then
          def_stab_number(def);
        if (def.typ=objectdef) and (TObjectDef(def).objecttype=odt_class) then
          result:=ToStr(def.stab_number-1)
        else
          result:=ToStr(def.stab_number);
      end;


    function TDebugInfoStabs.def_var_value(const s:string;arg:pointer):string;
      var
        def : TDef;
      begin
        def:=TDef(arg);
        result:='';
        if s='numberstring' then
          result:=def_stab_number(def)
        else if s='sym_name' then
          begin
            if Assigned(def.typesym) then
               result:=GetSymName(TTypeSym(def.typesym));
          end
        else if s='savesize' then
          result:=ToStr(def.size);
      end;


    function TDebugInfoStabs.def_stabstr_evaluate(def:TDef;const s:string;const vars:array of string):AnsiString;
      begin
        result:=string_evaluate(s,@def_var_value,def,vars);
      end;


    procedure TDebugInfoStabs.field_add_stabstr(p:TObject;arg:pointer);
      var
        spec    : string[3];
        varsize : asizeint;
        newss   : AnsiString;
        ss      : pansistring absolute arg;
      begin
        if (TSym(p).visibility=vis_hidden) then
          exit;
        { static variables from objects are like global objects }
        if is_normal_fieldvarsym(TSym(p)) then
          begin
           case TSym(p).visibility of
             vis_private,
             vis_strictprivate :
               spec:='/0';
             vis_protected,
             vis_strictprotected :
               spec:='/1';
             else
               spec:='';
           end;
           if (TAbstractRecordSymTable(TSym(p).owner).usefieldalignment<>bit_alignment) then
              begin
                varsize:=TFieldVarSym(p).vardef.size;
                { open arrays made overflows !! }
                { how can a record/object/class contain an open array? (JM) }

                if varsize>$fffffff then
                  varsize:=$fffffff;

                newss:=def_stabstr_evaluate(nil,'$1:$2,$3,$4;',[GetSymName(TFieldVarSym(p)),
                                     spec+def_stab_number(TFieldVarSym(p).vardef),
                                     ToStr(TConstExprInt(TFieldVarSym(p).fieldoffset)*8),ToStr(varsize*8)])
              end
            else
              newss:=def_stabstr_evaluate(nil,'$1:$2,$3,$4;',[GetSymName(TFieldVarSym(p)),
                                   spec+def_stab_number(TFieldVarSym(p).vardef),
                                   ToStr(TConstExprInt(TFieldVarSym(p).fieldoffset)),ToStr(TFieldVarSym(p).vardef.packedbitsize)]);
            ss^:=ss^+newss;
          end;
      end;


    procedure TDebugInfoStabs.method_add_stabstr(p:TObject;arg:pointer);
      var
        virtualind,argnames : string;
        pd     : TProcDef;
        lindex : LongInt;
        arglength : byte;
        sp : char;
        i : integer;
        parasym : TParaVarSym;
        newss   : AnsiString;
        ss      : pansistring absolute arg;
      begin
        if TSym(p).typ = procsym then
         begin
           if (sp_generic_dummy in TSym(p).symoptions) and
               (TProcSym(p).procdeflist.count=0) then
             exit;
           pd :=TProcDef(TProcSym(p).ProcdefList[0]);
           if (po_virtualmethod in pd.procoptions) and
               not is_objectpascal_helper(pd.struct) then
             begin
               lindex := pd.extnumber;
               {doesnt seem to be necessary
               lindex := lindex or $80000000;}
               virtualind := '*'+ToStr(lindex)+';'+def_stab_classnumber(pd.struct)+';'
             end
            else
             virtualind := '.';

            { used by gdbpas to recognize constructor and destructors }
            if (pd.proctypeoption=potype_constructor) then
              argnames:='__ct__'
            else if (pd.proctypeoption=potype_destructor) then
              argnames:='__dt__'
            else
              argnames := '';

           { arguments are not listed here }
           {we don't need another definition}
            for i:=0 to pd.paras.count-1 do
              begin
                parasym:=TParaVarSym(pd.paras[i]);
                if Parasym.vardef.typ = formaldef then
                  begin
                    case Parasym.varspez of
                      vs_var :
                        argnames := argnames+'3var';
                      vs_const :
                        argnames:=argnames+'5const';
                      vs_out :
                        argnames:=argnames+'3out';
                      vs_constref :
                        argnames:=argnames+'8constref';
                      vs_value :
                        ;
                      vs_final:
                        InternalError(2019050911);
                    end;
                  end
                else
                  begin
                    { if the arg definition is like (v: ^byte;..
                    there is no sym attached to data !!! }
                    if Assigned(Parasym.vardef.typesym) then
                      begin
                        arglength := length(GetSymName(Parasym.vardef.typesym));
                        argnames := argnames + ToStr(arglength)+GetSymName(Parasym.vardef.typesym);
                      end
                    else
                      argnames:=argnames+'11unnamedtype';
                  end;
              end;
           { here 2A must be changed for private and protected }
           { 0 is private 1 protected and 2 public }
           case TSym(p).visibility of
             vis_private,
             vis_strictprivate :
               sp:='0';
             vis_protected,
             vis_strictprotected :
               sp:='1'
             else
               sp:='2';
           end;
           newss:=def_stabstr_evaluate(nil,'$1::$2=##$3;:$4;$5A$6;',[GetSymName(TSym(p)),def_stab_number(pd),
                                    def_stab_number(pd.returndef),argnames,sp,
                                    virtualind]);
           ss^:=ss^+newss;
         end;
      end;


    procedure TDebugInfoStabs.field_write_defs(p:TObject;arg:pointer);
      begin
        if is_normal_fieldvarsym(TSym(p)) then
          appenddef(TAsmList(arg),TFieldVarSym(p).vardef);
      end;

    function TDebugInfoStabs.use_tag_prefix(def : TDef) : boolean;
      begin
        { stringdefs are not all considered as 'taggable',
          because ansi, unicode and wide strings are
          just associated to pointer types }
        use_tag_prefix:=(def.typ in tagtypes) and
                      ((def.typ<>stringdef) or
                       (TStringDef(def).stringtype in [st_shortstring,st_longstring]));
      end;


    procedure TDebugInfoStabs.write_def_stabstr(list:TAsmList;def:TDef;const ss:AnsiString);
      var
        stabchar : string[2];
        symname  : string[20];
        st    : AnsiString;
      begin
        { type prefix }
        if use_tag_prefix(def) then
          stabchar := tagtypeprefix
        else
          stabchar := 't';
        { in case of writing the class record structure, we always have to
          use the class name (so it refers both to the struct and the
          pointer to the struct), otherwise gdb crashes (see tests/tbs/tw9766.pas) }
        if is_class(def) and
           TObjectDef(def).writing_class_record_dbginfo then
          st:=def_stabstr_evaluate(def,'"${sym_name}:$1$2=',[stabchar,def_stab_classnumber(TObjectDef(def))])
        else
          begin
            { Type names for types defined in the current unit are already written in
              the typesym }
            if (def.owner.symtabletype=GlobalSymTable) and
               not(def.owner.iscurrentunit) then
              symname:='${sym_name}'
            else
              symname:='';
            st:=def_stabstr_evaluate(def,'"'+symname+':$1$2=',[stabchar,def_stab_number(def)]);
          end;
        st:=st+ss;
        { line info is set to 0 for all defs, because the def can be in another
          unit and then the linenumber is invalid in the current sourcefile }
        st:=st+def_stabstr_evaluate(def,'",'+base_stabs_str(def_stab,'0','0','0'),[]);
        { add to list }
        list.concat(TAIStab.create_ansistr(stabsdir,st));
      end;


    procedure TDebugInfoStabs.appenddef_string(list:TAsmList;def:TStringDef);
      var
        bytest,charst,longst : string;
        ss : AnsiString;
        slen : LongInt;
      begin
        ss:='';
        case def.stringtype of
          st_shortstring:
            begin
              { fix length of openshortstring }
              slen:=def.len;
              if slen=0 then
                slen:=255;
              charst:=def_stab_number(cansichartype);
              bytest:=def_stab_number(u8inttype);
              ss:=def_stabstr_evaluate(def,'s$1length:$2,0,8;st:ar$2;1;$3;$4,8,$5;;',
                          [ToStr(slen+1),bytest,ToStr(slen),charst,ToStr(slen*8)]);
            end;
          st_longstring:
            begin
              charst:=def_stab_number(cansichartype);
              bytest:=def_stab_number(u8inttype);
              longst:=def_stab_number(u32inttype);
              ss:=def_stabstr_evaluate(def,'s$1length:$2,0,32;dummy:$6,32,8;st:ar$2;1;$3;$4,40,$5;;',
                          [ToStr(def.len+5),longst,ToStr(def.len),charst,ToStr(def.len*8),bytest]);
           end;
         st_ansistring:
           begin
             { looks like a pchar }
             ss:='*'+def_stab_number(cansichartype);
           end;
         st_unicodestring,
         st_widestring:
           begin
             { looks like a pwidechar }
             ss:='*'+def_stab_number(cwidechartype);
           end;
        end;
        write_def_stabstr(list,def,ss);
      end;


    function TDebugInfoStabs.get_enum_defstr(def: TEnumDef; lowerbound: LongInt): AnsiString;
      var
        i: LongInt;
        p: TEnumSym;
      begin
        { we can specify the size with @s<size>; prefix PM }
        if def.size <> std_param_align then
          result:='@s'+ToStr(def.size*8)+';e'
        else
          result:='e';
        { the if-test is required because pred(def.minval) might overflow;
          the longint() typecast should be safe because stabs is not
          supported for 64 bit targets }
        if (def.minval<>lowerbound) then
          for i:=lowerbound to pred(LongInt(def.minval)) do
            result:=result+'<invalid>:'+ToStr(i)+',';

        for i := 0 to def.SymTable.SymList.Count - 1 do
          begin
            p := TEnumSym(def.SymTable.SymList[i]);
            if p.value<def.minval then
              continue
            else
            if p.value>def.maxval then
              break;
            result:=result+GetSymName(p)+':'+ToStr(p.value)+',';
          end;
        { the final ',' is required to have a valid stabs }
        result:=result+';';
      end;

    procedure TDebugInfoStabs.appenddef_enum(list:TAsmList;def:TEnumDef);
      begin
        write_def_stabstr(list,def,get_enum_defstr(def,def.minval));
      end;


    procedure TDebugInfoStabs.appenddef_ord(list:TAsmList;def:TOrdDef);
      var
        ss : AnsiString;
      begin
        ss:='';
        if cs_gdb_valgrind in CurrentSettings.GlobalSwitches then
          begin
            case def.ordtype of
              uvoid :
                ss:=def_stab_number(def);
              pasbool1,
              pasbool8,
              pasbool16,
              pasbool32,
              pasbool64,
              bool8bit,
              bool16bit,
              bool32bit,
              bool64bit :
                ss:=def_stabstr_evaluate(def,'r${numberstring};0;255;',[]);
              u32bit,
              s64bit,
              u64bit,
              s128bit,
              u128bit:
                ss:=def_stabstr_evaluate(def,'r${numberstring};0;-1;',[]);
              else
                ss:=def_stabstr_evaluate(def,'r${numberstring};$1;$2;',[ToStr(LongInt(def.low.svalue)),ToStr(LongInt(def.high.svalue))]);
            end;
          end
        else
          begin
            case def.ordtype of
              uvoid :
                ss:=def_stab_number(def);
              uchar :
                ss:='-20;';
              uwidechar :
                ss:='-30;';
              pasbool1,
              pasbool8,
              bool8bit :
                ss:='-21;';
              pasbool16,
              bool16bit :
                ss:='-22;';
              pasbool32,
              bool32bit :
                ss:='-23;';
              pasbool64,
              bool64bit :
                { no clue if this is correct (FK) }
                ss:='-23;';
              u64bit :
                ss:='-32;';
              s64bit :
                ss:='-31;';
              {u32bit : result:=def_stab_number(s32inttype)+';0;-1;'); }
              else
                begin
                  if def.size <> std_param_align then
                    ss:='@s'+ToStr(def.size*8)+';'
                  else
                    ss:='';
                  ss:=ss+def_stabstr_evaluate(def,'r${numberstring};$1;$2;',[ToStr(LongInt(def.low.svalue)),ToStr(LongInt(def.high.svalue))]);
                end;
            end;
         end;
        write_def_stabstr(list,def,ss);
      end;


    procedure TDebugInfoStabs.appenddef_float(list:TAsmList;def:TFloatDef);
      var
        ss : AnsiString;
      begin
        ss:='';
        case def.floattype of
          S32Real,
          S64Real,
          s80real,
          sc80real:
            ss:=def_stabstr_evaluate(def,'r$1;${savesize};0;',[def_stab_number(s32inttype)]);
          s64currency,
          s64comp:
            ss:=def_stabstr_evaluate(def,'r$1;-${savesize};0;',[def_stab_number(s32inttype)]);
        end;
        write_def_stabstr(list,def,ss);
      end;


    procedure TDebugInfoStabs.appenddef_file(list:TAsmList;def:TFileDef);
      var
        ss : AnsiString;
      begin
{$ifdef cpu64bitaddr}
        ss:=def_stabstr_evaluate(def,'s${savesize}HANDLE:$1,0,32;MODE:$1,32,32;RECSIZE:$2,64,64;'+
                                 '_PRIVATE:ar$1;1;64;$3,128,256;USERDATA:ar$1;1;32;$3,384,256;'+
                                 'NAME:ar$1;0;255;$4,640,2048;;',[def_stab_number(s32inttype),
                                 def_stab_number(s64inttype),
                                 def_stab_number(u8inttype),
                                 def_stab_number(cansichartype)]);
{$else cpu64bitaddr}
        ss:=def_stabstr_evaluate(def,'s${savesize}HANDLE:$1,0,32;MODE:$1,32,32;RECSIZE:$1,64,32;'+
                                 '_PRIVATE:ar$1;1;32;$3,96,256;USERDATA:ar$1;1;32;$2,352,256;'+
                                 'NAME:ar$1;0;255;$3,608,2048;;',[def_stab_number(s32inttype),
                                 def_stab_number(u8inttype),
                                 def_stab_number(cansichartype)]);
{$endif cpu64bitaddr}
        write_def_stabstr(list,def,ss);
      end;


    procedure TDebugInfoStabs.appenddef_record(list:TAsmList;def:TRecordDef);
      var
        ss : AnsiString;
      begin
        ss:='s'+ToStr(def.size);
        def.SymTable.SymList.ForEachCall(@field_add_stabstr,@ss);
        ss[length(ss)]:=';';
        write_def_stabstr(list,def,ss);
      end;


    procedure TDebugInfoStabs.appenddef_object(list:TAsmList;def:TObjectDef);

        procedure do_write_object(list:TAsmList;def:TObjectDef);
        var
          ss : AnsiString;
          anc    : TObjectDef;
        begin
          ss:='';
          { Write the invisible pointer for the class? }
          if (def.objecttype=odt_class) and
             (not def.writing_class_record_dbginfo) then
            begin
              ss:='*'+def_stab_classnumber(def);
              write_def_stabstr(list,def,ss);
              exit;
            end;

          ss:='s'+ToStr(TObjectSymTable(def.SymTable).DataSize);
          if Assigned(def.childof) then
            begin
              {only one ancestor not virtual, public, at base offset 0 }
              {       !1           ,    0       2         0    ,       }
              ss:=ss+'!1,020,'+def_stab_classnumber(def.childof)+';';
            end;

          {virtual table to implement yet}
          def.SymTable.symList.ForEachCall(@field_add_stabstr,@ss);

          if (oo_has_vmt in def.objectoptions) and
             (
              not Assigned(def.childof) or
              not(oo_has_vmt in def.childof.objectoptions)
             ) then
            ss:=ss+'$vf'+def_stab_classnumber(def)+':'+def_stab_number(vmtarraytype)+','+ToStr(def.vmt_offset*8)+';';
          def.SymTable.symList.ForEachCall(@method_add_stabstr,@ss);
          if (oo_has_vmt in def.objectoptions) then
            begin
               anc := def;
               while Assigned(anc.childof) and (oo_has_vmt in anc.childof.objectoptions) do
                 anc := anc.childof;
               { just in case anc = self }
               ss:=ss+';~%'+def_stab_classnumber(anc)+';';
            end
          else
            ss:=ss+';';
          write_def_stabstr(list,def,ss);
        end;

      var
        oldtypesym : TSym;
      begin
        TObjectDef(def).SymTable.symList.ForEachCall(@field_write_defs,list);
        { classes require special code to write the record and the invisible pointer }
        if is_class(def) then
          begin
            { Write the record class itself }
            TObjectDef(def).writing_class_record_dbginfo:=true;
            do_write_object(list,def);
            TObjectDef(def).writing_class_record_dbginfo:=false;
            { Write the invisible pointer class }
            oldtypesym:=def.typesym;
            def.typesym:=nil;
            do_write_object(list,def);
            def.typesym:=oldtypesym;
          end
        else
          do_write_object(list,def);
        { VMT symbol }
        maybe_add_vmt_sym(list,def);
      end;


    procedure TDebugInfoStabs.appenddef_variant(list:TAsmList;def:TVariantDef);
      var
        ss : AnsiString;
      begin
        if not Assigned(vardatadef) then
          exit;

        ss:='s'+ToStr(vardatadef.size);
        vardatadef.SymTable.SymList.ForEachCall(@field_add_stabstr,@ss);
        ss[length(ss)]:=';';
        write_def_stabstr(list,def,ss);
      end;


    procedure TDebugInfoStabs.appenddef_pointer(list:TAsmList;def:TPointerDef);
      var
        ss : AnsiString;
      begin
        ss:='*'+def_stab_number(TPointerDef(def).pointeddef);
        write_def_stabstr(list,def,ss);
      end;


    procedure TDebugInfoStabs.appenddef_set(list:TAsmList;def:TSetDef);
      var
        st,
        ss : AnsiString;
        elementdefstabnr: string;
      begin
        { ugly hack: create a temporary subrange type if the lower bound of
          the set's element type is not a multiple of 8 (because we store them
          as if the lower bound is a multiple of 8) }
        if (def.setbase<>get_min_value(def.elementdef)) then
          begin
            { allocate a def number }
            inc(global_stab_number);
            elementdefstabnr:=ToStr(global_stab_number);
            { anonymous subrange def }
            st:='":t'+elementdefstabnr+'=';
            if (def.elementdef.typ = enumdef) then
              st:=st+get_enum_defstr(TEnumDef(def.elementdef),def.setbase)
            else
              st:=st+def_stabstr_evaluate(def.elementdef,'r'+elementdefstabnr+';$1;$2;',[ToStr(LongInt(def.setbase)),ToStr(LongInt(get_max_value(def.elementdef).svalue))]);
            st:=st+'",'+base_stabs_str(def_stab,'0','0','0');
            { add to list }
            list.concat(TAIStab.create_ansistr(stabsdir,st));
          end
        else
          elementdefstabnr:=def_stab_number(def.elementdef);
        ss:=def_stabstr_evaluate(def,'@s$1;S$2',[ToStr(def.size*8),elementdefstabnr]);
        write_def_stabstr(list,def,ss);
      end;


    procedure TDebugInfoStabs.appenddef_formal(list:TAsmList;def:TFormalDef);
      var
        ss : AnsiString;
      begin
        ss:=def_stabstr_evaluate(def,'${numberstring};',[]);
        write_def_stabstr(list,def,ss);
      end;


    procedure TDebugInfoStabs.appenddef_array(list:TAsmList;def:TArrayDef);
      var
        tempstr: shortstring;
        ss : AnsiString;
      begin
        if not is_packed_array(def) then
          begin
            { Try to used P if ememlent size is smaller than
              usual integer }
            if def.elesize <> std_param_align then
              tempstr:='ar@s'+ToStr(def.elesize*8)+';$1;$2;$3;$4'
            else
              tempstr:='ar$1;$2;$3;$4';
            if is_dynamic_array(def) then
              tempstr:='*'+tempstr;
            ss:=def_stabstr_evaluate(def,tempstr,[def_stab_number(TArrayDef(def).rangedef),
                     ToStr(TArrayDef(def).lowrange),ToStr(TArrayDef(def).highrange),def_stab_number(TArrayDef(def).elementdef)])
          end
        else
          begin
            // the @P seems to be ignored by gdb
            tempstr:=def_stabstr_evaluate(TArrayDef(def).rangedef,'r${numberstring};$1;$2;',
              [ToStr(TArrayDef(def).lowrange),ToStr(TArrayDef(def).highrange)]);
            // will only show highrange-lowrange+1 bits in gdb
            ss:=def_stabstr_evaluate(def,'@s$1;@S;S$2',
              [ToStr(TConstExprInt(TArrayDef(def).elepackedbitsize) * TArrayDef(def).elecount),tempstr]);
          end;
        write_def_stabstr(list,def,ss);
      end;


    procedure TDebugInfoStabs.appenddef_procvar(list:TAsmList;def:TProcVarDef);
      var
        ss : AnsiString;
      begin
        ss:='*f'+def_stab_number(TProcVarDef(def).returndef);
        write_def_stabstr(list,def,ss);
      end;


    procedure TDebugInfoStabs.appenddef_undefined(list:TAsmList;def:TUndefinedDef);
      var
        ss : AnsiString;
      begin
        ss:=def_stabstr_evaluate(def,'${numberstring};',[]);
        write_def_stabstr(list,def,ss);
      end;


    procedure TDebugInfoStabs.beforeappenddef(list:TAsmList;def:TDef);
      var
        anc : TObjectDef;
        i : LongInt;
      begin
        { write dependencies first }
        case def.typ of
          stringdef :
            begin
              if TStringDef(def).stringtype in [st_widestring,st_unicodestring] then
                appenddef(list,cwidechartype)
              else
                begin
                  appenddef(list,cansichartype);
                  appenddef(list,u8inttype);
                end;
            end;
          floatdef :
            appenddef(list,s32inttype);
          filedef :
            begin
              appenddef(list,s32inttype);
{$ifdef cpu64bitaddr}
              appenddef(list,s64inttype);
{$endif cpu64bitaddr}
              appenddef(list,u8inttype);
              appenddef(list,cansichartype);
            end;
          classrefdef :
            appenddef(list,pvmttype);
          pointerdef :
            appenddef(list,TPointerDef(def).pointeddef);
          setdef :
            appenddef(list,TSetDef(def).elementdef);
          procvardef :
            begin
              appenddef(list,TProcVarDef(def).returndef);
              if Assigned(TProcVarDef(def).parast) then
                write_symtable_defs(list,TProcVarDef(def).parast);
            end;
          procdef :
            begin
              appenddef(list,TProcDef(def).returndef);
              if Assigned(TProcDef(def).parast) then
                write_symtable_defs(list,TProcDef(def).parast);
              if Assigned(TProcDef(def).localst) and
                 (TProcDef(def).localst.symtabletype=localsymtable) then
                write_symtable_defs(list,TProcDef(def).localst);
            end;
          arraydef :
            begin
              appenddef(list,TArrayDef(def).rangedef);
              appenddef(list,TArrayDef(def).elementdef);
            end;
          recorddef :
            TRecordDef(def).SymTable.symList.ForEachCall(@field_write_defs,list);
          enumdef :
            if Assigned(TEnumDef(def).basedef) then
              appenddef(list,TEnumDef(def).basedef);
          objectdef :
            begin
              { make sure we don't write child classdefs before their parent }
              { classdefs, because this crashes gdb                          }
              anc:=TObjectDef(def);
              while Assigned(anc.childof) do
                begin
                  anc:=anc.childof;
                  case anc.dbg_state of
                    dbg_state_writing:
                      { happens in case a field of a parent is of the (forward
                        defined) child type
                      }
                      begin
                        { We don't explicitly requeue it, but the fact that
                          a child type was used in a parent before the child
                          type was fully defined means that it was forward
                          declared, and will still be encountered later.
                          Setting the state to queued however allows us to
                          get the def number already without an IE
                        }
                        def.dbg_state:=dbg_state_queued;
                        break;
                      end;
                    else
                      ;
                  end;
                end;
              appenddef(list,vmtarraytype);
              if Assigned(TObjectDef(def).ImplementedInterfaces) then
                for i:=0 to TObjectDef(def).ImplementedInterfaces.Count-1 do
                  appenddef(list,TImplementedInterface(TObjectDef(def).ImplementedInterfaces[i]).IntfDef);
              { first the parents }
              anc:=TObjectDef(def);
              while Assigned(anc.childof) do
                begin
                  anc:=anc.childof;
                  { in case this is an object family declared in another unit
                    that was compiled without debug info, this ancestor may not
                    yet have a stabs number and not yet be added to defstowrite
                    -> take care of that now, while its dbg_state is still
                    dbg_state_unused in case the aforementioned things haven't
                    happened yet (afterwards it will become dbg_state_writing,
                    and then def_stab_number() won't do anything anymore because
                    it assumes it's already happened
                  }
                  def_stab_number(anc);
                  appenddef(list,anc);
                  if Assigned(anc.ImplementedInterfaces) then
                    for i:=0 to anc.ImplementedInterfaces.Count-1 do
                      appenddef(list,TImplementedInterface(anc.ImplementedInterfaces[i]).IntfDef);
                end;
            end;
          else
            ;
        end;
      end;


    procedure TDebugInfoStabs.appendprocdef(list:TAsmList;def:TProcDef);
      var
        hs : AnsiString;
        templist : TAsmList;
        prev_procdef : TProcDef;
      begin
        if not(def.in_currentunit) or
           { happens for init procdef of units without init section }
           not Assigned(def.procstarttai) then
          exit;

        { mark as used so the local type defs also be written }
        def.dbg_state:=dbg_state_used;
        prev_procdef:=current_procdef;
        current_procdef:=def;

        templist:=gen_procdef_endsym_stabs(def);
        CurrentAsmData.asmlists[al_procedures].InsertListAfter(def.procendtai,templist);

        { FUNC stabs }
        templist.free;
        templist:=gen_procdef_startsym_stabs(def);
        CurrentAsmData.asmlists[al_procedures].InsertListBefore(def.procstarttai,templist);

        { para types }
        if Assigned(def.parast) then
          write_symtable_syms(templist,def.parast);
        { local type defs and vars should not be written
          inside the main proc stab }
        if Assigned(def.localst) and
           (def.localst.symtabletype=localsymtable) then
          write_symtable_syms(templist,def.localst);

        if Assigned(def.funcretsym) and
           (TAbstractNormalVarSym(def.funcretsym).refs>0) then
          begin
            if TAbstractNormalVarSym(def.funcretsym).localloc.loc=LOC_REFERENCE then
              begin
{ TODO: Need to add gdb support for ret in param register calling}
                if paramanager.ret_in_param(def.returndef,def) then
                  hs:='X*'
                else
                  hs:='X';
                templist.concat(TAIStab.create(stabsdir,StrPNew(
                   '"'+GetSymName(def.procsym)+':'+hs+def_stab_number(def.returndef)+'",'+
                   base_stabs_str(localvarsymref_stab,'0','0',getoffsetstr(TAbstractNormalVarSym(def.funcretsym).localloc.reference)))));
                if (m_result in CurrentSettings.ModeSwitches) then
                  templist.concat(TAIStab.create(stabsdir,StrPNew(
                     '"RESULT:'+hs+def_stab_number(def.returndef)+'",'+
                     base_stabs_str(localvarsymref_stab,'0','0',getoffsetstr(TAbstractNormalVarSym(def.funcretsym).localloc.reference)))));
              end;
          end;


        CurrentAsmData.asmlists[al_procedures].InsertListBefore(def.procstarttai,templist);

        templist.free;
        templist := nil;
        current_procdef:=prev_procdef;
      end;


{****************************************************************************
                               TSym support
****************************************************************************}

    function TDebugInfoStabs.sym_var_value(const s:string;arg:pointer):string;
      var
        sym : TSym absolute arg;
      begin
        result:='';
        if s='name' then
          result:=GetSymName(sym)
        else if s='mangledname' then
          result:=ApplyAsmSymbolRestrictions(sym.mangledname)
        else if s='ownername' then
          result:=GetSymTableName(sym.owner)
        else if s='line' then
          result:=ToStr(sym.fileinfo.line)
        else
          InternalError(200401152);
      end;


    function TDebugInfoStabs.sym_stabstr_evaluate(sym:TSym;const s:string;const vars:array of string):AnsiString;
      begin
        result:=string_evaluate(s,@sym_var_value,sym,vars);
      end;


    procedure TDebugInfoStabs.write_sym_stabstr(list:TAsmList;sym:TSym;const ss:AnsiString);
      begin
        if ss='' then
          exit;
        { add to list }
        list.concat(TAIStab.create_ansistr(stabsdir,ss));
      end;


    function TDebugInfoStabs.staticvarsym_mangled_name(sym: TStaticVarSym): string;
      begin
        result:=ApplyAsmSymbolRestrictions(sym.mangledname);
      end;


    procedure TDebugInfoStabs.maybe_add_vmt_sym(list: TAsmList; def: TObjectDef);
      begin
        if (oo_has_vmt in def.objectoptions) and
           Assigned(def.owner) and
           Assigned(def.owner.name) then
          list.concat(TAIStab.create_ansistr(stabsdir,AnsiString('"vmt_')+GetSymTableName(def.owner)+TObjectDef(def).objname^+':S'+
                 def_stab_number(vmttype)+'",'+
                 base_stabs_str(globalvarsym_inited_stab,'0','0',ApplyAsmSymbolRestrictions(TObjectDef(def).vmt_mangledname))));
      end;


    procedure TDebugInfoStabs.appendsym_fieldvar(list:TAsmList;sym:TFieldVarSym);
      var
        ss : AnsiString;
      begin
        ss:='';
        if (sym.owner.symtabletype in [ObjectSymtable,recordsymtable]) and
           (sp_static in sym.symoptions) then
          ss:=sym_stabstr_evaluate(sym,'"${ownername}__${name}:S$1",'+base_stabs_str(globalvarsym_uninited_stab,'0','${line}','${mangledname}'),
              [def_stab_number(sym.vardef)]);
        write_sym_stabstr(list,sym,ss);
      end;


    procedure TDebugInfoStabs.appendsym_staticvar(list:TAsmList;sym:TStaticVarSym);
      var
        ss : AnsiString;
        st : string;
        threadvaroffset : string;
        regidx : TRegisterIndex;
        nsym : byte;
      begin
        { external symbols can't be resolved at link time, so we
          can't generate stabs for them }
        if vo_is_external in sym.varoptions then
          exit;
        ss:='';
        st:=def_stab_number(sym.vardef);
        case sym.localloc.loc of
          LOC_REGISTER,
          LOC_CREGISTER,
          LOC_MMREGISTER,
          LOC_CMMREGISTER,
          LOC_FPUREGISTER,
          LOC_CFPUREGISTER :
            begin
              regidx:=findreg_by_number(sym.localloc.register);
              { "eax", "ecx", "edx", "ebx", "esp", "ebp", "esi", "edi", "eip", "ps", "cs", "ss", "ds", "es", "fs", "gs", }
              { this is the register order for GDB}
              if regidx<>0 then
                ss:=sym_stabstr_evaluate(sym,'"${name}:r$1",'+base_stabs_str(regvar_stab,'0','${line}','$2'),[st,ToStr(regstabs_table[regidx])]);
            end;
          else
            begin
              if vo_is_thread_var in sym.varoptions then
                exit; { STABS cannot describe the image/context indirection. }
              threadvaroffset:='';
              if (vo_is_typed_const in sym.varoptions) then
                if vo_is_public in sym.varoptions then
                  nsym:=globalvarsym_inited_stab
                else
                  nsym:=staticvarsym_inited_stab
              else if vo_is_public in sym.varoptions then
                nsym:=globalvarsym_uninited_stab
              else
                nsym:=staticvarsym_uninited_stab;
              { Here we used S instead of
                because with G GDB doesn't look at the address field
                but searches the same name or with a leading underscore
                but these names don't exist in pascal !}
              st:='S'+st;
              ss:=sym_stabstr_evaluate(sym,'"${name}:$1",'+base_stabs_str(nsym,'0','${line}','$2$3'),[st,staticvarsym_mangled_name(sym),threadvaroffset]);
            end;
        end;
        write_sym_stabstr(list,sym,ss);
      end;


    procedure TDebugInfoStabs.appendsym_localvar(list:TAsmList;sym:TLocalVarSym);
      var
        ss : AnsiString;
        st : string;
        regidx : TRegisterIndex;
      begin
        { There is no space allocated for not referenced locals }
        if (sym.owner.symtabletype=localsymtable) and (sym.refs=0) then
          exit;

        ss:='';
        st:=def_stab_number(sym.vardef);
        case sym.localloc.loc of
          LOC_REGISTER,
          LOC_CREGISTER,
          LOC_MMREGISTER,
          LOC_CMMREGISTER,
          LOC_FPUREGISTER,
          LOC_CFPUREGISTER :
            begin
              regidx:=findreg_by_number(sym.localloc.register);
              { "eax", "ecx", "edx", "ebx", "esp", "ebp", "esi", "edi", "eip", "ps", "cs", "ss", "ds", "es", "fs", "gs", }
              { this is the register order for GDB}
              if regidx<>0 then
                ss:=sym_stabstr_evaluate(sym,'"${name}:r$1",'+base_stabs_str(regvar_stab,'0','${line}','$2'),[st,ToStr(regstabs_table[regidx])]);
            end;
          LOC_REFERENCE :
            { offset to ebp => will not work if the framepointer is esp
              so some optimizing will make things harder to debug }
            ss:=sym_stabstr_evaluate(sym,'"${name}:$1",'+base_stabs_str(localvarsymref_stab,'0','${line}','$2'),[st,getoffsetstr(sym.localloc.reference)])
          else
            InternalError(2003091814);
        end;
        write_sym_stabstr(list,sym,ss);
      end;


    function TDebugInfoStabs.get_appendsym_paravar_reg(sym:TParaVarSym;const typ,stabstr:string;reg: TRegister): AnsiString;
      var
        ltyp: string[1];
        regidx : TRegisterIndex;
      begin
        result:='';
        if typ='p' then
          ltyp:='R'
        else
          ltyp:='a';
        regidx:=findreg_by_number(reg);
        { "eax", "ecx", "edx", "ebx", "esp", "ebp", "esi", "edi", "eip", "ps", "cs", "ss", "ds", "es", "fs", "gs", }
        { this is the register order for GDB}
        if regidx<>0 then
          result:=sym_stabstr_evaluate(sym,'"${name}:$1",'+base_stabs_str(regvar_stab,'0','${line}','$2'),[ltyp+stabstr,ToStr(LongInt(regstabs_table[regidx]))]);
      end;


    function TDebugInfoStabs.base_stabs_str(typ: LongInt; const other, desc, value: AnsiString): AnsiString;
      begin
        result:=base_stabs_str(ToStr(typ),other,desc,value);
      end;


    function TDebugInfoStabs.base_stabs_str(const typ, other, desc, value: AnsiString): AnsiString;
      begin
        result:=typ+','+other+','+desc+','+value
      end;


    function TDebugInfoStabs.gen_procdef_startsym_stabs(def: TProcDef): TAsmList;
      var
        RType : Char;
        Obj,Info,
        mangledname: AnsiString;
      begin
        result:=TAsmList.create;
        { "The stab representing a procedure is located immediately
          following the code of the procedure. This stab is in turn
          directly followed by a group of other stabs describing
          elements of the procedure. These other stabs describe the
          procedure's parameters, its block local variables, and its
          block structure." (stab docs)                               }
        { this is however incorrect in case "include source" statements }
        { appear in the block, in that case the procedure stab must     }
        { appear before this include stabs (and we generate such an     }
        { stabs for all functions) (JM)                                 }

        obj := GetSymName(def.procsym);
        info := '';
        if (po_global in def.procoptions) then
          RType := 'F'
        else
          RType := 'f';
        if Assigned(def.owner) then
          begin
            if (def.owner.symtabletype in [ObjectSymtable,recordsymtable]) then
              obj := GetSymTableName(def.owner)+'__'+GetSymName(def.procsym);
            if not(cs_gdb_valgrind in CurrentSettings.GlobalSwitches) and
               (def.owner.symtabletype=localsymtable) and
               Assigned(def.owner.defowner) and
               Assigned(TProcDef(def.owner.defowner).procsym) then
              info := ','+GetSymName(def.procsym)+','+GetSymName(TProcDef(def.owner.defowner).procsym);
          end;
        mangledname:=ApplyAsmSymbolRestrictions(def.mangledname);
        result.concat(TAIStab.Create_ansistr(stabsdir,'"'+obj+':'+RType+def_stab_number(def.returndef)+info+'",'+
          base_stabs_str(procdef_stab,'0',ToStr(def.fileinfo.line),mangledname)));
      end;


    function TDebugInfoStabs.gen_procdef_endsym_stabs(def: TProcDef): TAsmList;
      var
        ss, mangledname: AnsiString;
        stabsendlabel: TAsmLabel;
      begin
        result:=TAsmList.create;

        { end of procedure }
        CurrentAsmData.getlabel(stabsendlabel,alt_dbgtype);

        if dbgtype<>dbg_stabx then
          begin
            mangledname:=def.mangledname;
            // LBRAC
            if af_stabs_use_function_absolute_addresses in TargetAsm.flags then
              ss:=ToStr(STABS_N_LBRAC)+',0,0,'+mangledname
            else
              ss:=ToStr(STABS_N_LBRAC)+',0,0,0';
            result.concat(TAIStab.Create_ansistr(stab_stabn,ss));

            // RBRAC
            ss:=ToStr(STABS_N_RBRAC)+',0,0,'+stabsendlabel.name;
            stabsendlabel.increfs;
            if not(af_stabs_use_function_absolute_addresses in TargetAsm.flags) then
              ss:=ss+'-'+mangledname;
            result.concat(TAIStab.Create_ansistr(stab_stabn,ss));

            { the stabsendlabel must come after all other stabs for this }
            { function                                                   }
            result.concat(TAILabel.create(stabsendlabel));

            { Add a "size" stab as described in the last paragraph of 2.5 at  }
            { http://sourceware.org/gdb/current/onlinedocs/stabs_2.html#SEC12 }
            { This works at least on Darwin (and is needed on Darwin to get   }
            { correct smartlinking of stabs), but I don't know which binutils }
            { version is required on other platforms                          }
            { This stab must come after all other stabs for the procedure,    }
            { including the LBRAC/RBRAC ones                                  }
            if (TargetInfo.system in systems_darwin) then
              result.concat(TAIStab.create(stabsdir,
                StrPNew('"",'+base_stabs_str(procdef_stab,'0','0',stabsendlabel.name+'-'+mangledname))));
          end;
      end;


    procedure TDebugInfoStabs.appendsym_paravar(list:TAsmList;sym:TParaVarSym);
      var
        ss : AnsiString;
        c  : string[1];
        st : string;
        regidx : TRegisterIndex;
      begin
        ss:='';
         { set loc to LOC_REFERENCE to get somewhat usable debugging info }
        { while stabs aren't adapted for regvars yet                             }
        if (vo_is_self in sym.varoptions) then
          begin
            case sym.localloc.loc of
              LOC_REGISTER,
              LOC_CREGISTER:
                regidx:=findreg_by_number(sym.localloc.register);
              LOC_REFERENCE: ;
              else
                InternalError(2003091815);
            end;
            if (po_classmethod in TAbstractProcDef(sym.owner.defowner).procoptions) or
               (po_staticmethod in TAbstractProcDef(sym.owner.defowner).procoptions) then
              begin
                if (sym.localloc.loc=LOC_REFERENCE) then
                  ss:=sym_stabstr_evaluate(sym,'"pvmt:p$1",'+base_stabs_str(localvarsymref_stab,'0','0','$2'),
                    [def_stab_number(pvmttype),getoffsetstr(sym.localloc.reference)])
                else
                  begin
                    regidx:=findreg_by_number(sym.localloc.register);
                    ss:=sym_stabstr_evaluate(sym,'"pvmt:r$1",'+base_stabs_str(regvar_stab,'0','0','$2'),
                      [def_stab_number(pvmttype),ToStr(regstabs_table[regidx])]);
                  end
                end
            else
              begin
                if not(is_class(TProcDef(sym.owner.defowner).struct)) then
                  c:='v'
                else
                  c:='p';
                if (sym.localloc.loc=LOC_REFERENCE) then
                  ss:=sym_stabstr_evaluate(sym,'"$$t:$1",'+base_stabs_str(localvarsymref_stab,'0','0','$2'),
                        [c+def_stab_number(TProcDef(sym.owner.defowner).struct),getoffsetstr(sym.localloc.reference)])
                else
                  begin
                    if (c='p') then
                      c:='R'
                    else
                      c:='a';
                    regidx:=findreg_by_number(sym.localloc.register);
                    ss:=sym_stabstr_evaluate(sym,'"$$t:$1",'+base_stabs_str(regvar_stab,'0','0','$2'),
                        [c+def_stab_number(TProcDef(sym.owner.defowner).struct),ToStr(regstabs_table[regidx])]);
                  end
              end;
          end
        else
          begin
            st:=def_stab_number(sym.vardef);

            if paramanager.push_addr_param(sym.varspez,sym.vardef,TProcDef(sym.owner.defowner).proccalloption) and
               not(vo_has_local_copy in sym.varoptions) and
               not is_open_string(sym.vardef) then
              c:='v' { should be 'i' but 'i' doesn't work }
            else
              c:='p';
            case sym.localloc.loc of
              LOC_REGISTER,
              LOC_CREGISTER,
              LOC_MMREGISTER,
              LOC_CMMREGISTER,
              LOC_FPUREGISTER,
              LOC_CFPUREGISTER :
                begin
                  ss:=get_appendsym_paravar_reg(sym,c,st,sym.localloc.register);
                end;
              LOC_REFERENCE :
                begin
                  { When the *value* of a parameter (so not its address!) is
                    copied into a local variable, you have to generate two
                    stabs: one for the parameter, and one for the local copy.
                    Not doing this breaks debugging under e.g. SPARC. Doc:
                    http://sourceware.org/gdb/current/onlinedocs/stabs_4.html#SEC26
                  }
                  if (TargetDbg.id<>dbg_stabx) and
                     (c='p') and
                     not is_open_string(sym.vardef) and
                     ((sym.paraloc[calleeside].location^.loc<>sym.localloc.loc) or
                      ((sym.localloc.loc in [LOC_REFERENCE,LOC_CREFERENCE]) and
                       ((sym.paraloc[calleeside].location^.reference.index<>sym.localloc.reference.base) or
                        (sym.paraloc[calleeside].location^.reference.offset<>sym.localloc.reference.offset))) or
                      ((sym.localloc.loc in [LOC_REGISTER,LOC_CREGISTER,LOC_MMREGISTER,LOC_CMMREGISTER,LOC_FPUREGISTER,LOC_CFPUREGISTER]) and
                       (sym.localloc.register<>sym.paraloc[calleeside].location^.register))) then
                    begin
                      if not(sym.paraloc[calleeside].location^.loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
                        ss:=get_appendsym_paravar_reg(sym,c,st,sym.paraloc[calleeside].location^.register)
                      else
                        ss:=sym_stabstr_evaluate(sym,'"${name}:$1",'+base_stabs_str(localvarsymref_stab,'0','${line}','$2'),
                              [c+st,getparaoffsetstr(sym.paraloc[calleeside].location^.reference)]);
                      write_sym_stabstr(list,sym,ss);
                      { second stab has no parameter specifier }
                      c:='';
                    end;
                  { offset to ebp => will not work if the framepointer is esp
                    so some optimizing will make things harder to debug }
                  ss:=sym_stabstr_evaluate(sym,'"${name}:$1",'+base_stabs_str(paravarsymref_stab,'0','${line}','$2'),[c+st,getoffsetstr(sym.localloc.reference)])
                end;
              else
                InternalError(2003091805);
            end;
          end;
        write_sym_stabstr(list,sym,ss);
      end;


    function stabx_quote_const(const s: string): string;
      var
        i:byte;
      begin
        stabx_quote_const:='';
        for i:=1 to length(s) do
          begin
            case s[i] of
              #10:
                stabx_quote_const:=stabx_quote_const+'\n';
              #13:
                stabx_quote_const:=stabx_quote_const+'\r';
              { stabx strings cannot deal with embedded quotes }
              '"':
                stabx_quote_const:=stabx_quote_const+' ';
              else
                stabx_quote_const:=stabx_quote_const+s[i];
            end;
          end;
      end;


    procedure TDebugInfoStabs.appendsym_const(list:TAsmList;sym:TConstSym);
      var
        st : string;
        ss : AnsiString;
        i : LongInt;
      begin
        ss:='';
        { Don't write info for default parameter values, the N_Func breaks
          the N_Func for the function itself.
          Valgrind does not support constants }
        if (sym.owner.symtabletype=parasymtable) or
           (cs_gdb_valgrind in CurrentSettings.GlobalSwitches) then
          exit;
        case sym.consttyp of
          conststring:
            begin
              if sym.value.len<200 then
                begin
                  SetLength(ss,sym.value.len);
                  for i:=0 to sym.value.len-1 do
                    ss[i+1]:=pchar(sym.value.valueptr)[i];
                  if TargetDbg.id=dbg_stabs then
                    st:='s'''+Backspace_Quote(Octal_Quote(ss,[#0..#9,#11,#12,#14..#31,'''']),['"','\',#10,#13])+''''
                  else
                    st:='s'''+stabx_quote_const(Octal_Quote(ss,[#0..#9,#11,#12,#14..#31,'''']))+'''';
                end
              else
                st:='<constant string too long>';
            end;
          constord:
            st:='i'+ToStr(sym.value.valueord);
          constpointer:
            st:='i'+ToStr(sym.value.valueordptr);
          constreal:
            begin
              st:=RealToStr(PBestReal(sym.value.valueptr)^);
              st := 'r'+st;
            end;
          else
            begin
              { if we don't know just put zero !! }
              st:='i0';
            end;
        end;
        ss:=sym_stabstr_evaluate(sym,'"${name}:c=$1;",'+base_stabs_str(constsym_stab,'0','${line}','0'),[st]);
        write_sym_stabstr(list,sym,ss);
      end;


    procedure TDebugInfoStabs.appendsym_type(list:TAsmList;sym:TTypeSym);
      var
        ss : AnsiString;
        stabchar : string[2];
      begin
        ss:='';
        if not Assigned(sym.typedef) then
          InternalError(200509262);
        if use_tag_prefix(sym.typedef) then
          stabchar:=tagtypeprefix
        else
          stabchar:='t';
        ss:=sym_stabstr_evaluate(sym,'"${name}:$1$2",'+base_stabs_str(typesym_stab,'0','${line}','0'),[stabchar,def_stab_number(sym.typedef)]);
        write_sym_stabstr(list,sym,ss);
      end;


    procedure TDebugInfoStabs.appendsym_label(list:TAsmList;sym:TLabelSym);
      var
        ss : AnsiString;
      begin
        ss:=sym_stabstr_evaluate(sym,'"${name}",'+base_stabs_str(localvarsymref_stab,'0','${line}','0'),[]);
        write_sym_stabstr(list,sym,ss);
      end;


{****************************************************************************
                             Proc/Module support
****************************************************************************}

    procedure TDebugInfoStabs.inserttypeinfo;
      var
        stabsvarlist,
        stabstypelist : TAsmList;
        storefilepos  : TFilePosInfo;
        i  : LongInt;
        vardatatype : TTypeSym;
      begin
        storefilepos:=CurrentFilePos;
        CurrentFilePos:=CurrentModule.mainfilepos;

        global_stab_number:=0;
        defnumberlist:=TFPObjectList.create(false);
        deftowritelist:=TFPObjectList.create(false);
        stabsvarlist:=TAsmList.create;
        stabstypelist:=TAsmList.create;

        vardatatype:=try_search_system_type('TVARDATA');
        if Assigned(vardatatype) then
          vardatadef:=TRecordDef(vardatatype.typedef);

        { include symbol that will be referenced from the main to be sure to
          include this debuginfo .o file }
        include(CurrentModule.moduleflags,mf_has_stabs_debuginfo);
        if not(TargetInfo.system in systems_darwin) then
          begin
            new_section(CurrentAsmData.asmlists[al_stabs],sec_data,GetSymTableName(CurrentModule.localsymtable),sizeof(PInt));
            CurrentAsmData.asmlists[al_stabs].concat(TAISymbol.Createname_global(make_mangledname('DEBUGINFO',CurrentModule.localsymtable,''),AT_METADATA,0,voidpointertype));
          end
        else
          new_section(CurrentAsmData.asmlists[al_stabs],sec_code,GetSymTableName(CurrentModule.localsymtable),sizeof(PInt));

        { write all global/local variables. This will flag all required tdefs  }
        if Assigned(CurrentModule.GlobalSymTable) then
          write_symtable_syms(stabsvarlist,CurrentModule.GlobalSymTable);
        if Assigned(CurrentModule.localsymtable) then
          write_symtable_syms(stabsvarlist,CurrentModule.localsymtable);

        { write all procedures and methods. This will flag all required tdefs }
        if Assigned(CurrentModule.GlobalSymTable) then
          write_symtable_procdefs(stabsvarlist,CurrentModule.GlobalSymTable);
        if Assigned(CurrentModule.localsymtable) then
          write_symtable_procdefs(stabsvarlist,CurrentModule.localsymtable);

        { reset unit type info flag }
        reset_unit_type_info;

        { write used types from the used units }
        write_used_unit_type_info(stabstypelist,CurrentModule);
        { last write the types from this unit }
        if Assigned(CurrentModule.GlobalSymTable) then
          write_symtable_defs(stabstypelist,CurrentModule.GlobalSymTable);
        if Assigned(CurrentModule.localsymtable) then
          write_symtable_defs(stabstypelist,CurrentModule.localsymtable);

        write_remaining_defs_to_write(stabstypelist);

        CurrentAsmData.asmlists[al_stabs].ConcatList(stabstypelist);
        CurrentAsmData.asmlists[al_stabs].ConcatList(stabsvarlist);

        { reset stab numbers }
        for i:=0 to defnumberlist.count-1 do
          begin
            if Assigned(defnumberlist[i]) then
              begin
                TDef(defnumberlist[i]).stab_number:=0;
                TDef(defnumberlist[i]).dbg_state:=dbg_state_unused;
              end;
          end;

        defnumberlist.free;
        defnumberlist:=nil;
        deftowritelist.free;
        deftowritelist:=nil;

        stabsvarlist.free;
        stabsvarlist := nil;
        stabstypelist.free;
        stabstypelist := nil;
        CurrentFilePos:=storefilepos;
      end;


    procedure TDebugInfoStabs.insertlineinfo(list: TAsmList);
      var
        currfileinfo,
        lastfileinfo : TFilePosInfo;
        currfuncname : PShortString;
        currsectype  : TAsmSectiontype;
        hlabel       : TAsmLabel;
        hp : TAI;
        infile : TInputFile;
      begin
        FillChar(lastfileinfo,sizeof(lastfileinfo),0);
        currfuncname:=nil;
        currsectype:=sec_code;
        hp:=TAI(list.first);
        while Assigned(hp) do
          begin
            case hp.typ of
              ait_section :
                currsectype:=TAISection(hp).sectype;
              ait_function_name :
                currfuncname:=TAIFunctionName(hp).funcname;
              ait_force_line :
                lastfileinfo.line:=-1;
              else
                ;
            end;

            if (currsectype=sec_code) and
               (hp.typ=ait_instruction) then
              begin
                currfileinfo:=TAILineInfo(hp).fileinfo;
                { file changed ? (must be before line info) }
                if (currfileinfo.fileindex<>0) and
                   ((lastfileinfo.fileindex<>currfileinfo.fileindex) or
                    (lastfileinfo.moduleindex<>currfileinfo.moduleindex)) then
                  begin
                    infile:=Get_Module(currfileinfo.moduleindex).SourceFiles.Get_File(currfileinfo.fileindex);
                    if Assigned(infile) then
                      begin
                        CurrentAsmData.getlabel(hlabel,alt_dbgfile);
                        { emit stabs }
                        if not(ds_stabs_abs_include_files in CurrentSettings.DebugSwitches) or
                           Path_Absolute(infile.path) then
                          list.insertbefore(TAIStab.Create_str(stabsdir,'"'+BSToSlash(FixPath(infile.path,false))+FixFileName(infile.name)+'",'+ToStr(stabs_n_includefile)+
                                            ',0,0,'+hlabel.name),hp)
                        else
                          list.insertbefore(TAIStab.Create_str(stabsdir,'"'+BSToSlash(FixPath(getcurrentdir,false)+FixPath(infile.path,false))+FixFileName(infile.name)+'",'+ToStr(stabs_n_includefile)+
                                            ',0,0,'+hlabel.name),hp);
                        list.insertbefore(TAILabel.create(hlabel),hp);
                        hlabel.increfs;

                        { force new line info }
                        lastfileinfo.line:=-1;
                      end;
                  end;

                { line changed ? }
                if (currfileinfo.line>lastfileinfo.line) and (currfileinfo.line<>0) then
                  begin
                     if Assigned(currfuncname) and
                        not(af_stabs_use_function_absolute_addresses in TargetAsm.flags) then
                      begin
                        CurrentAsmData.getlabel(hlabel,alt_dbgline);
                        list.insertbefore(TAIStab.Create_str(stab_stabn,ToStr(stabs_n_textline)+',0,'+ToStr(currfileinfo.line)+','+
                                          hlabel.name+' - '+currfuncname^),hp);
                        list.insertbefore(TAILabel.create(hlabel),hp);
                        hlabel.increfs;
                      end
                     else
                      list.insertbefore(TAIStab.Create_str(stab_stabd,ToStr(stabs_n_textline)+',0,'+ToStr(currfileinfo.line)),hp);
                  end;
                lastfileinfo:=currfileinfo;
              end;

            hp:=TAI(hp.next);
          end;
      end;


    procedure TDebugInfoStabs.insertmoduleinfo;
      var
        hlabel : TAsmLabel;
        infile : TInputFile;
      begin
        { emit main source n_sourcefile for start of module }
        CurrentAsmData.getlabel(hlabel,alt_dbgfile);
        infile:=CurrentModule.SourceFiles.Get_File(1);
        new_section(CurrentAsmData.asmlists[al_start],sec_code,make_mangledname('DEBUGSTART',CurrentModule.localsymtable,''),sizeof(PInt),secorder_begin);
        if not(TargetInfo.system in systems_darwin) then
          CurrentAsmData.asmlists[al_start].concat(TAISymbol.Createname_global(make_mangledname('DEBUGSTART',CurrentModule.localsymtable,''),AT_METADATA,0,voidpointertype));
        CurrentAsmData.asmlists[al_start].concat(TAIStab.Create_str(stabsdir,'"'+BSToSlash(FixPath(getcurrentdir,false))+'",'+
          base_stabs_str(stabs_n_sourcefile,'0','0',hlabel.name)));
        CurrentAsmData.asmlists[al_start].concat(TAIStab.Create_str(stabsdir,'"'+BSToSlash(FixPath(infile.path,false))+FixFileName(infile.name)+'",'+
          base_stabs_str(stabs_n_sourcefile,'0','0',hlabel.name)));
        hlabel.increfs;
        CurrentAsmData.asmlists[al_start].concat(TAILabel.create(hlabel));
        { for darwin, you need a "module marker" too to work around      }
        { either some assembler or gdb bug (radar 4386531 according to a }
        { comment in dbxout.c of Apple's gcc)                            }
        if (TargetInfo.system in systems_darwin) then
          CurrentAsmData.asmlists[al_end].concat(TAIStab.Create_str(stabsdir,'"",'+base_stabs_str(STABS_N_OSO,'0','0','0')));
        { emit empty n_sourcefile for end of module }
        CurrentAsmData.getlabel(hlabel,alt_dbgfile);
        new_section(CurrentAsmData.asmlists[al_end],sec_code,make_mangledname('DEBUGEND',CurrentModule.localsymtable,''),sizeof(PInt),secorder_end);
        if not(TargetInfo.system in systems_darwin) then
          CurrentAsmData.asmlists[al_end].concat(TAISymbol.Createname_global(make_mangledname('DEBUGEND',CurrentModule.localsymtable,''),AT_METADATA,0,voidpointertype));
        CurrentAsmData.asmlists[al_end].concat(TAIStab.Create_str(stabsdir,'"",'+base_stabs_str(stabs_n_sourcefile,'0','0',hlabel.name)));
        CurrentAsmData.asmlists[al_end].concat(TAILabel.create(hlabel));
        hlabel.increfs;
      end;


        procedure TDebugInfoStabs.referencesections(list: TAsmList);
      var
        hp : TModule;
        dbgtable : TAISymbol;
      begin
        { Reference all DEBUGINFO sections from the main .fpc section }
        if (TargetInfo.system in systems_darwin) then
          exit;
        new_section(list,sec_fpc,'links',0);
        { make sure the debuginfo doesn't get stripped out }
        if (TargetInfo.system in systems_darwin) then
          begin
            dbgtable:=TAISymbol.createname('DEBUGINFOTABLE',AT_METADATA,0,voidpointertype);
            list.concat(TAIDirective.create(asd_no_dead_strip,dbgtable.sym.name));
            list.concat(dbgtable);
          end;
        { include reference to all debuginfo sections of used units }
        hp:=TModule(loaded_units.first);
        while Assigned(hp) do
          begin
            If (mf_has_stabs_debuginfo in hp.moduleflags) and not Assigned(hp.package) then
              begin
                list.concat(TAIConst.Createname(make_mangledname('DEBUGINFO',hp.localsymtable,''),0));
                list.concat(TAIConst.Createname(make_mangledname('DEBUGSTART',hp.localsymtable,''),0));
                list.concat(TAIConst.Createname(make_mangledname('DEBUGEND',hp.localsymtable,''),0));
              end;
            hp:=TModule(hp.next);
          end;
      end;

    constructor TDebugInfoStabs.Create;
      begin
        inherited Create;
        dbgtype:=dbg_stabs;
        stabsdir:=stab_stabs;

        def_stab:=STABS_N_LSYM;
        regvar_stab:=STABS_N_RSYM;
        procdef_stab:=STABS_N_Function;
        constsym_stab:=STABS_N_Function;
        typesym_stab:=STABS_N_LSYM;
        globalvarsym_uninited_stab:=STABS_N_STSYM;
        globalvarsym_inited_stab:=STABS_N_LCSYM;
        staticvarsym_uninited_stab:=STABS_N_STSYM;
        staticvarsym_inited_stab:=STABS_N_LCSYM;
        localvarsymref_stab:=STABS_N_TSYM;
        paravarsymref_stab:=STABS_N_TSYM;
        tagtypeprefix:='Tt';

        vardatadef:=nil;
      end;

    const
      dbg_stabs_info : TDbgInfo =
         (
           id     : dbg_stabs;
           idtxt  : 'STABS';
         );

initialization
  RegisterDebugInfo(dbg_stabs_info,TDebugInfoStabs);
end.
