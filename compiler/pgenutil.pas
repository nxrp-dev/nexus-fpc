{
    Copyright (c) 2011

    Contains different functions that are used in the context of
    parsing generics.

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
unit pgenutil;

{$i fpcdefs.inc}

interface

uses
  TPCompilerReal,
    { common }
  CClasses,
  { global }
  GlobType,
  { parser }
  pgentype,
  { node }
  node,
  { symtable }
  symtype,symdef,SymBase;

    procedure generate_specialization(var tt:TDef;enforce_unit:boolean;parse_class_parent:boolean;const _prettyname:string;parsedtype:TDef;const symname:string;parsedpos:TFilePosInfo);inline;
    procedure generate_specialization(var tt:TDef;enforce_unit:boolean;parse_class_parent:boolean;const _prettyname:string;const symname:string;SymTable:TSymTable);inline;
    function generate_specialization_phase1(out context:TSpecializationContext;genericdef:TDef;enforce_unit:boolean):TDef;inline;
    function generate_specialization_phase1(out context:TSpecializationContext;genericdef:TDef;enforce_unit:boolean;const symname:string;SymTable:TSymTable):TDef;inline;
    function generate_specialization_phase1(out context:TSpecializationContext;genericdef:TDef;enforce_unit:boolean;parsedtype:TDef;const symname:string;SymTable:TSymTable;parsedpos:TFilePosInfo):TDef;
    function generate_specialization_phase2(context:TSpecializationContext;genericdef:TStoredDef;parse_class_parent:boolean;const _prettyname:AnsiString):TDef;
    function check_generic_constraints(genericdef:TStoredDef;paramlist:TFPObjectList;poslist:TFPList):boolean;
    function parse_generic_parameters(allowconstraints:boolean):TFPHashObjectList;
    function parse_generic_specialization_types(paramlist:TFPObjectList;poslist:TFPList;out prettyname,specializename:AnsiString):boolean;
    procedure insert_generic_parameter_types(def:TStoredDef;genericdef:TStoredDef;genericlist:TFPHashObjectList;isfwd:boolean);
    procedure maybe_insert_generic_rename_symbol(const name:TIDString;genericlist:TFPHashObjectList);
    function generate_generic_name(const name:TIDString;const specializename:AnsiString;const owner_hierarchy:AnsiString):TIDString;
    procedure split_generic_name(const name:TIDString;out nongeneric:string;out count:LongInt);
    procedure add_generic_dummysym(sym:TSym;const name:TIDString);
    function resolve_generic_dummysym(const name:TIDString):TSym;
    function could_be_generic(const name:TIDString):boolean;inline;
    function try_implicit_specialization(sym:TSym;para:TNode;pdoverloadlist:TFPObjectList;var unnamed_syms:TFPList;var first_procsym:TSym;var hasoverload:boolean):boolean;
    function finalize_specialization(var pd:TProcDef;spezcontext:TSpecializationContext):boolean;

    procedure generate_specialization_procs;
    procedure generate_specializations_for_forwarddef(def:TDef);
    procedure maybe_add_pending_specialization(def:TDef;unnamed_syms:TFPList);
    function determine_generic_def(const name:TIDString):TStoredDef;

    function is_or_belongs_to_current_genericdef(def:TDef):boolean;

    procedure specialization_init(genericdef:TDef;var state:TSpecializationState);
    procedure specialization_done(var state:TSpecializationState);

implementation

uses
  { common }
  CUtils,FPCHash,
  { global }
  Globals,tokens,Verbose,FinPut,ConstExp,
  { symtable }
  symconst,SymSym,SymTable,defcmp,defutil,ProcInfo,
  { modules }
  FModule,
  { node }
  nobj,ncon,ncal,
  { parser }
  Scanner,
  pbase,pexpr,pdecsub,ptype,psub,pparautl,pdecl,procdefutil;

  type
    TDefTypeSet = set of TDefTyp;
  const
    tgeneric_param_const_types : TDefTypeSet = [orddef,stringdef,floatdef,setdef,pointerdef,enumdef];
    tgeneric_param_nodes : TNodeTypeSet = [typen,ordconstn,stringconstn,realconstn,setconstn,niln];

    procedure make_prettystring(paramtype:TDef;first:boolean;constprettyname:AnsiString;var prettyname,specializename:AnsiString);
      var
        namepart : string;
        prettynamepart : AnsiString;
        module : TModule;
      begin
        if Assigned(paramtype.owner) then
          module:=find_module_from_symtable(paramtype.owner)
        else
          module:=CurrentModule;
        if not Assigned(module) then
          InternalError(2016112802);
        namepart:='_$'+HexStr(module.ModuleID,8)+'$$'+paramtype.UniqueIDStr;
        if constprettyname<>'' then
          namepart:=namepart+'$$'+constprettyname;
        { we use the full name of the type to uniquely identify it }
        if (SymTableStack.top.symtabletype=parasymtable) and
            (SymTableStack.top.defowner.typ=procdef) and
            (paramtype.owner=SymTableStack.top) then
          begin
            { special handling for specializations inside generic function declarations }
            prettynamepart:=TDef(SymTableStack.top.defowner).fullownerhierarchyname(true,true)+TProcDef(SymTableStack.top.defowner).procsym.prettyname;
          end
        else
          begin
            prettynamepart:=paramtype.fullownerhierarchyname(true,true);
          end;
        specializename:=specializename+namepart;
        if not first then
          prettyname:=prettyname+',';
        if constprettyname<>'' then
          prettyname:=prettyname+constprettyname
        else
          prettyname:=prettyname+prettynamepart+paramtype.typesym.prettyname;
      end;

    function get_generic_param_def(sym:TSym):TDef;
      begin
        if sym.typ=constsym then
          result:=TConstSym(sym).constdef
        else
          result:=TTypeSym(sym).typedef;
      end;

    function compare_orddef_by_range(param1,param2:TOrdDef;value:TConstValue):boolean;
      begin
        if (value.valueord<param2.low) or (value.valueord>param2.high) then
          result:=false
        else
          result:=true;
      end;

    function compare_generic_params(param1,param2:TDef;constparamsym:TConstSym):boolean;
      begin
        if (param1.typ=orddef) and (param2.typ=orddef) then
          begin
            if is_boolean(param2) then
              result:=is_boolean(param1)
            else if is_char(param2) then
              result:=is_char(param1)
            else if compare_orddef_by_range(TOrdDef(param1),TOrdDef(param2),constparamsym.value) then
              result:=true
            else
              result:=false;
          end
        { arraydef is string constant so it's compatible with stringdef }
        else if (param1.typ=arraydef) and (param2.typ=stringdef) then
          result:=true
        { integer ords are compatible with float }
        else if (param1.typ=orddef) and is_integer(param1) and (param2.typ=floatdef) then
          result:=true
        { chars are compatible with stringdef }
        else if (param1.typ=orddef) and is_char(param1) and (param2.typ=stringdef) then
          result:=true
        { undefined def is compatible with all types }
        else if param2.typ=undefineddef then
          result:=true
        { sets require stricter checks }
        else if is_set(param2) then
          result:=equal_defs(param1,param2) or
            { constant could be empty set }
            not(Assigned(TSetDef(param1).elementdef))
        else
          result:=param1.typ=param2.typ;
      end;

    function create_generic_constsym(fromdef:TDef;node:TNode;out prettyname:string):TConstSym;
      const
        undefinedname = 'undefined';
      var
        sym : TConstSym;
        setdef : TSetDef;
        enumsym : TSym;
        enumname : string;
        sp : pchar;
        ps : ^TConstSet;
        pd : ^BestReal;
        i,l : integer;
      begin
        if node=nil then
          InternalError(2020011401);
        case node.nodetype of
          ordconstn:
            begin
              sym:=CConstSym.create_ord(undefinedname,constord,TOrdConstNode(node).value,fromdef);
              prettyname:=ToStr(TOrdConstNode(node).value.svalue);
            end;
          stringconstn:
            begin
              // unicode, convert to utf8
              if TStringConstNode(node).cst_type in [cst_widestring,cst_unicodestring] then
                begin
                l:=UnicodeToUtf8(nil,0,TStringConstNode(node).valuews.AsConstPUnicodeChar,TStringConstNode(node).valuews.len);
                GetMem(sp,l);
                UnicodeToUtf8(sp,l,TStringConstNode(node).valuews.AsConstPUnicodeChar,TStringConstNode(node).valuews.len);
                sym:=CConstSym.create_string(undefinedname,conststring,sp,l,fromdef);
                prettyname:=''''+sp+'''';
                end
              else
                begin
                GetMem(sp,TStringConstNode(node).len+1);
                move(TStringConstNode(node).asconstpchar^,sp^,TStringConstNode(node).len+1);
                sym:=CConstSym.create_string(undefinedname,conststring,sp,TStringConstNode(node).len,fromdef);
                prettyname:=''''+TStringConstNode(node).asconstpchar+'''';
                end;
            end;
          realconstn:
            begin
              new(pd);
              pd^:=TRealConstNode(node).value_real;
              sym:=CConstSym.create_ptr(undefinedname,constreal,pd,fromdef);
              prettyname:=RealToStr(TRealConstNode(node).value_real);
            end;
          setconstn:
            begin
              new(ps);
              ps^:=TSetConstNode(node).value_set^;
              sym:=CConstSym.create_ptr(undefinedname,constset,ps,fromdef);
              setdef:=TSetDef(TSetConstNode(node).resultdef);
              prettyname:='[';
              for i := setdef.setbase to setdef.setmax do
                if i in TSetConstNode(node).value_set^ then
                  begin
                    if setdef.elementdef.typ=enumdef then
                      enumsym:=TEnumDef(setdef.elementdef).int2enumsym(i)
                    else
                      enumsym:=nil;
                    if Assigned(enumsym) then
                      enumname:=enumsym.realname
                    else if setdef.elementdef.typ=orddef then
                      begin
                        if TOrdDef(setdef.elementdef).ordtype=uchar then
                          enumname:=chr(i)
                        else
                          enumname:=ToStr(i);
                      end
                    else
                      enumname:=ToStr(i);
                    if length(prettyname) > 1 then
                      prettyname:=prettyname+','+enumname
                    else
                      prettyname:=prettyname+enumname;
                  end;
              prettyname:=prettyname+']';
            end;
          niln:
            begin
              { only "nil" is available for pointer constants }
              sym:=CConstSym.create_ord(undefinedname,constnil,0,fromdef);
              prettyname:='nil';
            end;
          else
            InternalError(2019021601);
        end;
        { the sym needs an owner for later checks so use the typeparam owner }
        sym.owner:=fromdef.owner;
        include(sym.symoptions,sp_generic_const);
        result:=sym;
      end;

    procedure maybe_add_waiting_unit(tt:TDef);
    { called only by a pas module when specializing or inlining, not by a ppu module }
      var
        hmodule : TModule;
      begin
        if not Assigned(tt) or
            not (df_generic in tt.defoptions) then
          exit;

        hmodule:=find_module_from_symtable(tt.owner);
        if not Assigned(hmodule) then
          InternalError(2012092401);

        if hmodule=CurrentModule then
          exit;

        { Note: if hmodule.state=ms_load its implementation is not yet ready }

        if hmodule.state<ms_compiling_waitfinish then
          begin
            TModule.ctask_fast_backtrack:=true;
            if CurrentModule.waitingforunit.indexof(hmodule)<0 then
              CurrentModule.waitingforunit.add(hmodule);
            if hmodule.waitingunits.indexof(CurrentModule)<0 then
              hmodule.waitingunits.add(CurrentModule);
          end;
      end;


    procedure add_forward_generic_def(def:TDef;context:TSpecializationContext);
      var
        list : TFPObjectList;
        fwdcontext : TSpecializationContext;
      begin
        if not is_implicit_pointer_object_type(def) then
          InternalError(2020070301);
        if not (oo_is_forward in TObjectDef(def).objectoptions) then
          InternalError(2020070302);
        if not Assigned(TObjectDef(def).genericdef) then
          InternalError(2020070303);
        list:=TFPObjectList(CurrentModule.forwardgenericdefs.find(TObjectDef(def).genericdef.fulltypename));
        if not Assigned(list) then
          begin
            list:=TFPObjectList.create(true);
            CurrentModule.forwardgenericdefs.add(TObjectDef(def).genericdef.fulltypename,list);
          end;
        fwdcontext:=context.getcopy;
        fwdcontext.forwarddef:=def;
        list.add(fwdcontext);
      end;


    function check_generic_constraints(genericdef:TStoredDef;paramlist:TFPObjectList;poslist:TFPList):boolean;
      var
        i,j,
        intfcount : LongInt;
        formaldef,
        paradef : TStoredDef;
        genparadef : TDef;
        objdef,
        paraobjdef,
        formalobjdef : TObjectDef;
        intffound : boolean;
        filepos : TFilePosInfo;
        is_const : boolean;
      begin
        { check whether the given specialization parameters fit to the eventual
          constraints of the generic }
        if not Assigned(genericdef.genericparas) or (genericdef.genericparas.count=0) then
          InternalError(2012101001);
        if genericdef.genericparas.count<>paramlist.count then
          InternalError(2012101002);
        if paramlist.count<>poslist.count then
          InternalError(2012120801);
        result:=true;
        for i:=0 to genericdef.genericparas.count-1 do
          begin
            filepos:=PFilePosInfo(poslist[i])^;
            paradef:=TStoredDef(get_generic_param_def(TSym(paramlist[i])));
            is_const:=TSym(paramlist[i]).typ=constsym;
            genparadef:=genericdef.get_generic_param_def(i);
            { validate const params }
            if not genericdef.is_generic_param_const(i) and is_const then
              begin
                MessagePos(filepos,type_e_mismatch);
                exit(false);
              end
            else if genericdef.is_generic_param_const(i) then
              begin
                { param type mismatch (type <> const) }
                 if genericdef.is_generic_param_const(i)<>is_const then
                   begin
                    MessagePos(filepos,type_e_mismatch);
                    exit(false);
                  end;
                { type constrained param doesn't match type }
                if not compare_generic_params(paradef,genericdef.get_generic_param_def(i),TConstSym(paramlist[i])) then
                  begin
                    MessagePos2(filepos,type_e_incompatible_types,FullTypeName(paradef,genparadef),FullTypeName(genparadef,paradef));
                    exit(false);
                  end;
              end;
            { test constraints for non-const params }
            if not genericdef.is_generic_param_const(i) then
              begin
                formaldef:=TStoredDef(TTypeSym(genericdef.genericparas[i]).typedef);
                if formaldef.typ=undefineddef then
                  { the parameter is of unspecified type, so no need to check }
                  continue;
                if not (df_genconstraint in formaldef.defoptions) or
                    not Assigned(formaldef.genconstraintdata) then
                  InternalError(2013021602);
                { undefineddef is compatible with anything }
                if formaldef.typ=undefineddef then
                  continue;
                if paradef.typ<>formaldef.typ then
                  begin
                    case formaldef.typ of
                      recorddef:
                        { delphi has own fantasy about record constraint
                          (almost non-nullable/non-nil-able value type) }
                        if m_delphi in CurrentSettings.ModeSwitches then
                          case paradef.typ of
                            floatdef,enumdef,orddef:
                              continue;
                            objectdef:
                              if TObjectDef(paradef).objecttype=odt_object then
                                continue
                              else
                                MessagePos(filepos,type_e_record_type_expected);
                            else
                              MessagePos(filepos,type_e_record_type_expected);
                          end
                        else
                          MessagePos(filepos,type_e_record_type_expected);
                      objectdef:
                        case TObjectDef(formaldef).objecttype of
                          odt_class,
                          odt_javaclass:
                            MessagePos1(filepos,type_e_class_type_expected,paradef.typename);
                          odt_interfacecom,
                          odt_interfacecorba,
                          odt_dispinterface,
                          odt_interfacejava:
                            MessagePos1(filepos,type_e_interface_type_expected,paradef.typename);
                          else
                            InternalError(2012101003);
                        end;
                      errordef:
                        { ignore }
                        ;
                      else
                        InternalError(2012101004);
                    end;
                    result:=false;
                  end
                else
                  begin
                    { the paradef types are the same, so do special checks for the
                      cases in which they are needed }
                    if formaldef.typ=objectdef then
                      begin
                        paraobjdef:=TObjectDef(paradef);
                        formalobjdef:=TObjectDef(formaldef);
                        if not (formalobjdef.objecttype in [odt_class,odt_javaclass,odt_interfacecom,odt_interfacecorba,odt_interfacejava,odt_dispinterface]) then
                          InternalError(2012101102);
                        if formalobjdef.objecttype in [odt_interfacecom,odt_interfacecorba,odt_interfacejava,odt_dispinterface] then
                          begin
                            { this is either a concrete interface or class type (the
                              latter without specific implemented interfaces) }
                            case paraobjdef.objecttype of
                              odt_interfacecom,
                              odt_interfacecorba,
                              odt_interfacejava,
                              odt_dispinterface:
                                begin
                                  if (oo_is_forward in paraobjdef.objectoptions) and
                                      (paraobjdef.objecttype=formalobjdef.objecttype) and
                                      (df_genconstraint in formalobjdef.defoptions) and
                                      (
                                        (formalobjdef.objecttype=odt_interfacecom) and
                                        (formalobjdef.childof=interface_iunknown)
                                      )
                                      or
                                      (
                                        (formalobjdef.objecttype=odt_interfacecorba) and
                                        (formalobjdef.childof=nil)
                                      ) then
                                    continue;
                                  if not def_is_related(paraobjdef,formalobjdef.childof) then
                                    begin
                                      MessagePos2(filepos,type_e_incompatible_types,paraobjdef.typename,formalobjdef.childof.typename);
                                      result:=false;
                                    end;
                                end;
                              odt_class,
                              odt_javaclass:
                                begin
                                  objdef:=paraobjdef;
                                  intffound:=false;
                                  while Assigned(objdef) do
                                    begin
                                      for j:=0 to objdef.implementedinterfaces.count-1 do
                                        if TImplementedInterface(objdef.implementedinterfaces[j]).intfdef=formalobjdef.childof then
                                          begin
                                            intffound:=true;
                                            break;
                                          end;
                                      if intffound then
                                        break;
                                      objdef:=objdef.childof;
                                    end;
                                  result:=intffound;
                                  if not result then
                                    MessagePos2(filepos,parser_e_class_doesnt_implement_interface,paraobjdef.typename,formalobjdef.childof.typename);
                                end;
                              else
                                begin
                                  MessagePos1(filepos,type_e_class_or_interface_type_expected,paraobjdef.typename);
                                  result:=false;
                                end;
                            end;
                          end
                        else
                          begin
                            { this is either a "class" or a concrete instance with
                              or without implemented interfaces }
                            if not (paraobjdef.objecttype in [odt_class,odt_javaclass]) then
                              begin
                                MessagePos1(filepos,type_e_class_type_expected,paraobjdef.typename);
                                result:=false;
                                continue;
                              end;
                            { for forward declared classes we allow pure TObject/class declarations }
                            if (oo_is_forward in paraobjdef.objectoptions) and
                                (df_genconstraint in formaldef.defoptions) then
                              begin
                                if (formalobjdef.childof=class_tobject) and
                                    not formalobjdef.implements_any_interfaces then
                                  continue;
                              end;
                            if Assigned(formalobjdef.childof) and
                                not def_is_related(paradef,formalobjdef.childof) then
                              begin
                                MessagePos2(filepos,type_e_incompatible_types,paraobjdef.typename,formalobjdef.childof.typename);
                                result:=false;
                              end;
                            intfcount:=0;
                            for j:=0 to formalobjdef.implementedinterfaces.count-1 do
                              begin
                                objdef:=paraobjdef;
                                intffound:=false;
                                while Assigned(objdef) do
                                  begin
                                    intffound:=Assigned(
                                                 find_implemented_interface(objdef,
                                                   TImplementedInterface(formalobjdef.implementedinterfaces[j]).intfdef
                                                 )
                                               );
                                    if intffound then
                                      break;
                                    objdef:=objdef.childof;
                                  end;
                                if intffound then
                                  inc(intfcount)
                                else
                                  MessagePos2(filepos,parser_e_class_doesnt_implement_interface,paraobjdef.typename,TImplementedInterface(formalobjdef.implementedinterfaces[j]).intfdef.typename);
                              end;
                            if intfcount<>formalobjdef.implementedinterfaces.count then
                              result:=false;
                          end;
                      end;
                  end;
              end;
          end;
      end;

    function parse_generic_specialization_types_internal(paramlist:TFPObjectList;poslist:TFPList;out prettyname,specializename:AnsiString;parsedtype:TDef;parsedpos:TFilePosInfo):boolean;
      var
        old_block_type : TBlockType;
        first : boolean;
        typeparam : TNode;
        parampos : PFilePosInfo;
        tmpparampos : TFilePosInfo;
        namepart : string;
        module : TModule;
        constprettyname : string;
        validparam : boolean;
      begin
        result:=true;
        prettyname:='';
        constprettyname:='';
        if paramlist=nil then
          InternalError(2012061401);
        { set the block type to type, so that the parsed type are returned as
          ttypenode (e.g. classes are in non type-compatible blocks returned as
          tloadvmtaddrnode) }
        old_block_type:=Block_Type;
        { if parsedtype is set, then the first type identifer was already parsed
          (happens in inline specializations) and thus we only need to parse
          the remaining types and do as if the first one was already given }
        first:=not Assigned(parsedtype);
        if Assigned(parsedtype) then
          begin
            paramlist.Add(parsedtype.typesym);
            module:=find_module_from_symtable(parsedtype.owner);
            if not Assigned(module) then
              InternalError(2016112801);
            namepart:='_$'+HexStr(module.ModuleID,8)+'$$'+parsedtype.UniqueIDStr;
            specializename:='$'+namepart;
            prettyname:=parsedtype.fullownerhierarchyname(true,true)+parsedtype.typesym.prettyname;
            if Assigned(poslist) then
              begin
                New(parampos);
                parampos^:=parsedpos;
                poslist.add(parampos);
              end;
          end
        else
          specializename:='$';
        while not (CurrentScanner.token in [_GT,_RSHARPBRACKET]) do
          begin
            { "first" is set to false at the end of the loop! }
            if not first then
              consume(_COMMA);
            Block_Type:=bt_type;
            tmpparampos:=CurrentFilePos;
            typeparam:=factor(false,[ef_accept_equal]);
            { determine if the typeparam node is a valid type or const }
            validparam:=typeparam.nodetype in tgeneric_param_nodes;
            if validparam then
              begin
                if TStoredDef(typeparam.resultdef).is_generic and
                    not is_or_belongs_to_current_genericdef(typeparam.resultdef) and
                    (
                      not parse_generic or
                      not defs_belong_to_same_generic(typeparam.resultdef,CurrentGenericDef)
                    ) then
                  Message(parser_e_no_generics_as_params);
                if Assigned(poslist) then
                  begin
                    New(parampos);
                    parampos^:=tmpparampos;
                    poslist.add(parampos);
                  end;
                if typeparam.resultdef.typ<>errordef then
                  begin
                    if (typeparam.nodetype=typen) and not Assigned(typeparam.resultdef.typesym) then
                      message(type_e_generics_cannot_reference_itself)
                    else if (typeparam.resultdef.typ<>errordef) then
                      begin
                        { all non-type nodes are considered const }
                        if typeparam.nodetype<>typen then
                          paramlist.Add(create_generic_constsym(typeparam.resultdef,typeparam,constprettyname))
                        else
                          begin
                            constprettyname:='';
                            paramlist.Add(typeparam.resultdef.typesym);
                          end;
                        make_prettystring(typeparam.resultdef,first,constprettyname,prettyname,specializename);
                      end;
                  end
                else
                  begin
                    result:=false;
                  end;
              end
            else
              begin
                Message(type_e_type_id_expected);
                result:=false;
              end;
            typeparam.free;
            typeparam := nil;
            first:=false;
          end;
        Block_Type:=old_block_type;
      end;


    function parse_generic_specialization_types(paramlist:TFPObjectList;poslist:TFPList;out prettyname,specializename:AnsiString):boolean;
      var
        dummypos : TFilePosInfo;
      begin
        FillChar(dummypos, SizeOf(TFilePosInfo), 0);
        result:=parse_generic_specialization_types_internal(paramlist,poslist,prettyname,specializename,nil,dummypos);
      end;


    procedure generate_specialization(var tt:TDef;enforce_unit:boolean;parse_class_parent:boolean;const _prettyname:string;const symname:string;SymTable:TSymTable);
      var
        context : TSpecializationContext;
        genericdef : TStoredDef;
        dummypos : TFilePosInfo;
      begin
        FillChar(dummypos, SizeOf(TFilePosInfo), 0);
        genericdef:=TStoredDef(generate_specialization_phase1(context,tt,enforce_unit,nil,symname,SymTable,dummypos));
        if genericdef<>generrordef then
          genericdef:=TStoredDef(generate_specialization_phase2(context,genericdef,parse_class_parent,_prettyname));
        tt:=genericdef;
        if Assigned(context) then
          context.free; // no nil needed
      end;


    function finalize_specialization(var pd:TProcDef;spezcontext:TSpecializationContext):boolean;
      var
        def : TDef;
      begin
        result:=false;
        if Assigned(spezcontext) then
          begin
            if not (df_generic in pd.defoptions) then
              InternalError(2015060301);
            { check whether the given parameters are compatible
              to the def's constraints }
            if not check_generic_constraints(pd,spezcontext.paramlist,spezcontext.poslist) then
              exit;
            def:=generate_specialization_phase2(spezcontext,pd,false,'');
            case def.typ of
              errordef:
                { do nothing }
                ;
              procdef:
                pd:=TProcDef(def);
              else
                InternalError(2015070303);
            end;
          end;
        result:=true;
      end;


    procedure transfer_unnamed_symbols(owner:TSymTable;unnamed_syms:TFPList);
      var
        i : integer;
        sym : TSym;
      begin
        for i:=0 to unnamed_syms.count-1 do
          begin
            sym:=TSym(unnamed_syms[i]);
            sym.ChangeOwnerAndName(owner,sym.realname);
          end;
        unnamed_syms.clear;
      end;


    function try_implicit_specialization(sym:TSym;para:TNode;pdoverloadlist:TFPObjectList;var unnamed_syms:TFPList;var first_procsym:TSym;var hasoverload:boolean):boolean;

      { hash key for generic parameter lookups }
      function generic_param_hash(def:TDef):string;inline;
        begin
          result:=def.typename;
        end;

      { returns true if the def a literal array such as [1,2,3] and not a shortstring }
      function is_array_literal(def:TDef):boolean;
        begin
          result:=(def.typ=arraydef) and not is_conststring_array(def);
        end;

      { makes the specialization context from the generic proc def and generic params }
      procedure generate_implicit_specialization(out context:TSpecializationContext;genericdef:TProcDef;genericparams:TFPHashList);
        var
          parsedpos:TFilePosInfo;
          poslist:TFPList;
          i: LongInt;
          paramtype: TTypeSym;
          parampos : PFilePosInfo;
          tmpparampos : TFilePosInfo;
          paramname: string;
        begin
          context:=TSpecializationContext.create;
          fillchar(parsedpos,sizeof(parsedpos),0);
          poslist:=context.poslist;
          tmpparampos:=CurrentFilePos;
          if genericparams.count<>genericdef.genericparas.count then
            InternalError(2021020901);
          poslist.capacity:=poslist.count+genericparams.count;
          context.paramlist.capacity:=context.paramlist.count+genericparams.count;
          for i:=0 to genericparams.count-1 do
            begin
              paramname:=generic_param_hash(TTypeSym(genericdef.genericparas[i]).typedef);
              paramtype:=TTypeSym(genericparams.find(paramname));
              if not Assigned(paramtype) then
                InternalError(2021020902);
              new(parampos);
              parampos^:=tmpparampos;
              poslist.add(parampos);
              context.paramlist.Add(paramtype);
              make_prettystring(paramtype.typedef,i=0,'',context.prettyname,context.specializename);
            end;
          context.genname:=genericdef.procsym.realname;
        end;

      { specialization context parameter lists require a typesym so we need
        to generate a placeholder for unnamed constant types like
        short strings, open arrays, function pointers etc... }
      function create_unnamed_typesym(def:TDef):TSym;
        var
          newtype: TSym;
        begin
          newtype:=nil;
          if is_conststring_array(def) then
            begin
              { for constant strings we need to respect various modeswitches }
              if (cs_refcountedstrings in CurrentSettings.LocalSwitches) then
                begin
                  if m_default_unicodestring in CurrentSettings.ModeSwitches then
                    newtype:=cunicodestringtype.typesym
                  else
                    newtype:=cansistringtype.typesym;
                end
              else
                newtype:=cshortstringtype.typesym;
            end
          else if def.typ=stringdef then
            newtype:=TStringDef(def).get_default_string_type.typesym
          else
            begin
              if is_array_constructor(def) then
                begin
                  { array constructor is not a valid parameter type; getreusable
                    avoids creating multiple implementations for calls with the
                    same number of array elements of a particular type }
                  def:=CArrayDef.getreusable(TArrayDef(def).elementdef,TArrayDef(def).highrange-TArrayDef(def).lowrange+1);
                end;
              newtype:=CTypeSym.create(def.fullownerhierarchyname(false,true)+typName[def.typ]+'$'+def.UniqueIDStr,def);
              include(newtype.symoptions,sp_generic_unnamed_type);
              newtype.owner:=def.owner;
              { ensure that there's no warning }
              newtype.refs:=1;
            end;
          if not Assigned(newtype) then
            InternalError(2021020904);
          result:=newtype;
        end;

      { searches for the generic param in specializations }
      function find_param_in_specialization(owner:TProcDef;genericparam:TTypeSym;def:TStoredDef):boolean;
        var
          parasym: TTypeSym;
          i: integer;
        begin
          result:=false;
          for i:=0 to def.genericparas.count-1 do
            begin
              parasym:=TTypeSym(def.genericparas[i]);
              { the generic param must have a named typesym }
              if not Assigned(parasym.typedef.typesym) then
                InternalError(2021020907);
              { recurse into inline specialization }
              if TStoredDef(parasym.typedef).is_specialization then
                begin
                  result:=find_param_in_specialization(owner,genericparam,TStoredDef(parasym.typedef));
                  if result then
                    exit;
                end
              else if (genericparam=parasym.typedef.typesym) and owner.is_generic_param(parasym.typedef) then
                exit(true);
            end;
        end;

      { searches for the generic param in arrays }
      function find_param_in_array(owner:TProcDef;genericparam:TTypeSym;def:TArrayDef):boolean;
        var
          elementdef:TStoredDef;
        begin
          elementdef:=TStoredDef(def.elementdef);
          { recurse into multi-dimensional array }
          if elementdef.typ=arraydef then
            result:=find_param_in_array(owner,genericparam,TArrayDef(elementdef))
          { something went wrong during parsing and the element is invalid }
          else if elementdef.typ=errordef then
            result:=false
          else
            begin
              { the element must have a named typesym }
              if not Assigned(elementdef.typesym) then
                InternalError(2021020906);
              result:=(genericparam=elementdef.typesym) and owner.is_generic_param(elementdef);
            end;
        end;

      { tests if the generic param is used in the parameter list }
      function is_generic_param_used(owner:TProcDef;genericparam:TTypeSym;paras:TFPList):boolean;
        var
          paravar:TParaVarSym;
          i: integer;
        begin
          result:=false;
          for i:=0 to paras.count-1 do
            begin
              paravar:=TParaVarSym(paras[i]);

              { handle array types by using element types (for example: array of T) }
              if paravar.vardef.typ=arraydef then
                result:=find_param_in_array(owner,genericparam,TArrayDef(paravar.vardef))
              { for specializations check search in generic params }
              else if TStoredDef(paravar.vardef).is_specialization then
                result:=find_param_in_specialization(owner,genericparam,TStoredDef(paravar.vardef))
              { something went wrong during parsing and the parameter is invalid }
              else if paravar.vardef.typ=errordef then
                exit(false)
              else
                begin
                  if not Assigned(paravar.vardef.typesym) then
                    InternalError(2021020905);
                  result:=(genericparam=paravar.vardef.typesym) and owner.is_generic_param(paravar.vardef)
                end;

              { exit if we find a used parameter }
              if result then
                exit;
            end;
        end;

      { handle generic specializations by using generic params from caller
        to specialize the target. for example "TRec<Integer>" can use "Integer"
        to specialize "TRec<T>" with "Integer" for "T". }
      procedure handle_specializations(genericparams:TFPHashList;target_def,caller_def:TStoredDef);
        var
          i,
          index : integer;
          key : string;
          target_param,
          caller_param : TTypeSym;
        begin
          { the target and the caller must the same generic def
            with the same set of generic parameters }
          if target_def.genericdef<>caller_def.genericdef then
            InternalError(2021020909);

          for i:=0 to target_def.genericparas.count-1 do
            begin
              target_param:=TTypeSym(target_def.genericparas[i]);
              caller_param:=TTypeSym(caller_def.genericparas[i]);

              { reject generics with constants }
              if (target_param.typ=constsym) or (caller_param.typ=constsym) then
                exit;

              key:=generic_param_hash(target_param.typedef);

              { the generic param is already used }
              index:=genericparams.findindexof(key);
              if index>=0 then
                continue;

              { add the type to the generic params }
              genericparams.add(key,caller_param);
            end;
        end;

      { specialize arrays by using element types but arrays may be multi-dimensional
        so we need to examine the caller/target pairs recursively in order to
        verify the dimensionality is equal }
      function handle_arrays(owner:TProcDef;target_def,caller_def:TArrayDef;out target_element,caller_element:TDef):boolean;
        begin
          { the target and the caller are both arrays and the target is a
            specialization so we can recurse into the targets element def }
          if is_array_literal(target_def.elementdef) and
            is_array_literal(caller_def.elementdef) and
            target_def.is_specialization then
            result:=handle_arrays(owner,TArrayDef(target_def.elementdef),TArrayDef(caller_def.elementdef),target_element,caller_element)
          else
            begin
              { the caller is an array which means the dimensionality is unbalanced
                and thus the arrays are compatible }
              if is_array_literal(caller_def.elementdef) then
                exit(false);
              { if the element is a generic param then return this type
                along with the caller element type at the same level }
              result:=owner.is_generic_param(target_def.elementdef);
              if result then
                begin
                  target_element:=target_def.elementdef;
                  caller_element:=caller_def.elementdef;
                end;
            end;
        end;

      { handle procvars by using the parameters from the caller to specialize
        the parameters of the target generic procedure specialization. for example:

          type generic TProc<S> = procedure(value: S);
          generic procedure Run<T>(proc: specialize TProc<T>);
          procedure DoCallback(value: integer);
          Run(@DoCallback);

        will specialize as Run<integer> because the signature
        of DoCallback() matches TProc<S> so we can specialize "S"
        with "integer", as they are both parameter #1
      }

      function handle_procvars(genericparams:TFPHashList;callerparams:TFPList;target_def:TDef;caller_def:TDef):boolean;
        var
          newparams : TFPHashList;

        procedure handle_generic_param(targetparadef,callerparadef:TDef);
          var
            key : string;
            index : integer;
          begin
            if not Assigned(callerparadef.typesym) then
              InternalError(2021020908);

            key:=generic_param_hash(targetparadef);

            { the generic param must not already be used }
            index:=genericparams.findindexof(key);
            if index<0 then
              begin
                { add the type to the list }
                index:=newparams.findindexof(key);
                if index<0 then
                  newparams.add(key,callerparadef.typesym);
              end;
          end;

        var
          i,j : integer;
          paravar : TParaVarSym;
          target_proc,
          caller_proc : TProcVarDef;
          target_proc_para,
          caller_proc_para : TParaVarSym;
          valid_params : integer;
        begin
          result := false;

          target_proc:=TProcVarDef(target_def);
          caller_proc:=TProcVarDef(caller_def);

          { parameter count must match exactly
            currently default values are not considered }
          if target_proc.paras.count<>caller_proc.paras.count then
            exit;

          { a mixture of functions and procedures is not allowed }
          if (not Assigned(target_proc.returndef) or is_void(target_proc.returndef)) xor
              (not Assigned(caller_proc.returndef) or is_void(caller_proc.returndef)) then
            exit;

          { reject generics with constants }
          for i:=0 to target_proc.genericdef.genericparas.count-1 do
            if TSym(target_proc.genericdef.genericparas[i]).typ=constsym then
              exit;

          newparams:=TFPHashList.create;
          valid_params:=0;

          for i:=0 to target_proc.paras.count-1 do
            begin
              target_proc_para:=TParaVarSym(target_proc.paras[i]);
              caller_proc_para:=TParaVarSym(caller_proc.paras[i]);

              { the parameters are not compatible }
              if compare_defs(caller_proc_para.vardef,target_proc_para.vardef,nothingn)=te_incompatible then
                begin
                  newparams.free;
                  newparams := nil;
                  exit(false);
                end;

              if sp_generic_para in target_proc_para.vardef.typesym.symoptions then
                begin
                  paravar:=TParaVarSym(TProcVarDef(target_proc.genericdef).paras[i]);

                  { find the generic param name in the generic def parameters }
                  j:=target_proc.genericdef.genericparas.findindexof(paravar.vardef.typesym.name);

                  handle_generic_param(TTypeSym(target_proc.genericparas[j]).typedef,caller_proc_para.vardef);
                end;

              inc(valid_params);
            end;

          if Assigned(target_proc.returndef) and not is_void(target_proc.returndef) then
            begin
              { or check for exact? }
              if compare_defs(caller_proc.returndef,target_proc.returndef,nothingn)<te_equal then
                begin
                  newparams.free;
                  newparams := nil;
                  exit(false);
                end;

              if sp_generic_para in target_proc.returndef.typesym.symoptions then
                begin
                  handle_generic_param(target_proc.returndef,caller_proc.returndef);
                end;
            end;

          { if the count of valid params matches the target then
            transfer the temporary params to the actual params }
          result:=valid_params=target_proc.paras.count;
          if result then
            for i := 0 to newparams.count-1 do
              genericparams.add(newparams.nameofindex(i),newparams[i]);

          newparams.free;
          newparams := nil;
        end;

      function maybe_inherited_specialization(givendef,desireddef:TStoredDef;out basedef:TStoredDef):boolean;
        begin
          result:=false;
          basedef:=nil;
          if givendef.typ<>objectdef then
            begin
              result:=givendef.is_specialization and (givendef.genericdef=desireddef.genericdef);
              if result then
                basedef:=givendef;
            end
          else
            begin
              while Assigned(givendef) do
                begin
                  if givendef.is_specialization and (givendef.genericdef=desireddef.genericdef) then
                    begin
                      basedef:=givendef;
                      result:=true;
                      break;
                    end;

                  givendef:=TObjectDef(givendef).childof;
                end;
            end;
        end;

      { compare generic parameters <T> with call node parameters. }
      function is_possible_specialization(callerparams:TFPList;genericdef:TProcDef;out unnamed_syms:TFPList;out genericparams:TFPHashList):boolean;
        var
          i,
          count : integer;
          paravar : TParaVarSym;
          base_def : TStoredDef;
          target_def,
          caller_def : TDef;
          target_key : string;
          index : integer;
          paras : TFPList;
          target_element,
          caller_element : TDef;
          required_param_count : integer;
        begin
          result:=false;
          paras:=nil;
          genericparams:=nil;
          required_param_count:=0;
          unnamed_syms:=nil;

          { first perform a check to reject generics with constants }
          for i:=0 to genericdef.genericparas.count-1 do
            if TSym(genericdef.genericparas[i]).typ=constsym then
              exit;

          { build list of visible target function parameters }
          paras:=TFPList.create;
          for i:=0 to genericdef.paras.count-1 do
            begin
              paravar:=TParaVarSym(genericdef.paras[i]);
              { ignore hidden parameters }
              if vo_is_hidden_para in paravar.varoptions then
                continue;
              paras.add(paravar);

              { const non-default parameters are required }
              if not Assigned(paravar.defaultconstsym) then
                inc(required_param_count);
            end;

          { not enough parameters were supplied }
          if callerparams.count<required_param_count then
            begin
              paras.free;
              paras := nil;
              exit;
            end;

          { check to make sure the generic parameters are all used
            at least once in the  caller parameters. }
          count:=0;
          for i:=0 to genericdef.genericparas.count-1 do
            if is_generic_param_used(genericdef,TTypeSym(genericdef.genericparas[i]),paras) then
              inc(count);

          if count<genericdef.genericparas.count then
            begin
              paras.free;
              paras := nil;
              exit;
            end;

          genericparams:=TFPHashList.create;
          for i:=0 to callerparams.count-1 do
            begin
              caller_def:=TTypeSym(callerparams[i]).typedef;

              { caller parameter exceeded the possible parameters }
              if i=paras.count then
                begin
                  genericparams.free;
                  genericparams := nil;
                  paras.free;
                  paras := nil;
                  exit;
                end;

              target_def:=TParaVarSym(paras[i]).vardef;
              target_key:='';

              { strings are compatible with "array of T" so we
                need to use the element type for specialization }
              if is_stringlike(caller_def) and
                is_array_literal(target_def) and
                genericdef.is_generic_param(TArrayDef(target_def).elementdef) then
                begin
                  target_def:=TArrayDef(target_def).elementdef;
                  target_key:=generic_param_hash(target_def);
                  caller_def:=chartype_for_stringlike(caller_def);
                end
              { non-uniform array constructors (i.e. array of const) are not compatible
                with normal arrays like "array of T" so we reject them }
              else if is_array_literal(target_def) and
                (caller_def.typ=arraydef) and
                (ado_IsConstructor in TArrayDef(caller_def).arrayoptions) and
                (ado_IsArrayOfConst in TArrayDef(caller_def).arrayoptions) then
                begin
                  continue;
                end
              { handle generic arrays }
              else if is_array_literal(caller_def) and
                is_array_literal(target_def) and
                handle_arrays(genericdef,TArrayDef(target_def),TArrayDef(caller_def),target_element,caller_element) then
                begin
                  target_def:=target_element;
                  caller_def:=caller_element;
                  target_key:=generic_param_hash(target_def);
                end
              { handle generic procvars }
              else if (caller_def.typ=procvardef) and
                (target_def.typ=procvardef) and
                TProcVarDef(target_def).is_specialization and
                handle_procvars(genericparams,callerparams,target_def,caller_def) then
                begin
                  continue;
                end
              { handle specialized objects by taking the base class as the type to specialize }
              else if is_class_or_object(caller_def) and
                is_class_or_object(target_def) and
                genericdef.is_generic_param(target_def) then
                begin
                  target_key:=generic_param_hash(target_def);
                  target_def:=TObjectDef(target_def).childof;
                end
              { handle generic specializations }
              else if TStoredDef(target_def).is_specialization and
                maybe_inherited_specialization(TStoredDef(caller_def),TStoredDef(target_def),base_def) then
                begin
                  handle_specializations(genericparams,TStoredDef(target_def),base_def);
                  continue;
                end
              { handle all other generic params }
              else if target_def.typ=undefineddef then
                target_key:=generic_param_hash(target_def);

              { the param doesn't have a generic key which means we don't need to consider it }
              if target_key='' then
                continue;

              { the generic param is already used }
              index:=genericparams.findindexof(target_key);
              if index>=0 then
                continue;

              { the caller type may not have a typesym so we need to create an unnamed one }
              if not Assigned(caller_def.typesym) then
                begin
                  sym:=create_unnamed_typesym(caller_def);
                  { add the unnamed sym to the list but only it was allocated manually }
                  if sym.owner=caller_def.owner then
                    TFPList.AddOnDemand(unnamed_syms,sym);
                  genericparams.add(target_key,sym);
                end
              else
                genericparams.add(target_key,caller_def.typesym);
            end;

          { if the parameter counts match then the specialization is possible }
          result:=genericparams.count=genericdef.genericparas.count;

          { cleanup }
          paras.free;
          paras := nil;
          if not result then begin
            genericparams.free;
            genericparams := nil;
          end;
        end;

      { make an ordered list of parameters from the caller }
      function make_param_list(dummysym:TSym;para:TNode;var unnamed_syms:TFPList):TFPList;
        var
          pt : TCallParaNode;
          paradef : TDef;
          sym : TSym;
        begin
          result:=TFPList.create;
          pt:=TCallParaNode(para);
          while Assigned(pt) do
            begin
              paradef:=pt.paravalue.resultdef;
              { unnamed parameter types can not be specialized }
              if not Assigned(paradef.typesym) then
                begin
                  sym:=create_unnamed_typesym(paradef);
                  result.insert(0,sym);
                  { add the unnamed sym to the list but only if it was allocated manually }
                  if sym.owner=paradef.owner then
                    TFPList.AddOnDemand(unnamed_syms,sym);
                end
              else
                result.insert(0,paradef.typesym);
              pt:=TCallParaNode(pt.nextpara);
            end;
        end;

      var
        i,j,k : integer;
        srsym : TProcSym;
        callerparams : TFPList;
        pd : TProcDef;
        dummysym : TProcSym;
        genericparams : TFPHashList;
        spezcontext : TSpecializationContext;
        pd_unnamed_syms : TFPList;
      begin
        result:=false;
        spezcontext:=nil;
        genericparams:=nil;
        dummysym:=TProcSym(sym);
        callerparams:=make_param_list(dummysym,para,unnamed_syms);

        { failed to build the parameter list }
        if not Assigned(callerparams) then
          exit;

        for i:=0 to dummysym.genprocsymovlds.count-1 do
          begin
            srsym:=TProcSym(dummysym.genprocsymovlds[i]);
            for j:=0 to srsym.ProcdefList.Count-1 do
              begin
                pd:=TProcDef(srsym.ProcdefList[j]);
                if is_possible_specialization(callerparams,pd,pd_unnamed_syms,genericparams) then
                  begin
                    generate_implicit_specialization(spezcontext,pd,genericparams);
                    genericparams.free;
                    genericparams := nil;
                    { finalize the specialization so it can be added to the list of overloads }
                    if not finalize_specialization(pd,spezcontext) then
                      begin
                        spezcontext.free;
                        spezcontext := nil;
                        continue;
                      end;
                    { handle unnamed syms used by the specialization }
                    if pd_unnamed_syms<>nil then
                      begin
                        transfer_unnamed_symbols(pd.owner,pd_unnamed_syms);
                        pd_unnamed_syms.free;
                        pd_unnamed_syms := nil;
                      end;
                    pdoverloadlist.add(pd);
                    spezcontext.free;
                    spezcontext := nil;
                    if po_overload in pd.procoptions then
                      hasoverload:=true;
                    { store first procsym found }
                    if not Assigned(first_procsym) then
                      first_procsym:=srsym;
                    result:=true;
                  end
                else
                  begin
                    { the specialization was not chosen so clean up any unnamed syms }
                    TFPList.FreeAndNilObjects(pd_unnamed_syms);
                  end;
              end;
          end;

        { unlink unused defs }
        if not(result) and Assigned(callerparams) then
          begin
            for k:=0 to callerparams.count-1 do
              begin
                if (TSym(callerparams[k]).typ=typesym) and (sp_generic_unnamed_type in TTypeSym(callerparams[k]).symoptions) then
                  TTypeSym(callerparams[k]).typedef.typesym:=nil;
              end;
          end;

        callerparams.free;
        callerparams := nil;
      end;

    function generate_specialization_phase1(out context:TSpecializationContext;genericdef:TDef;enforce_unit:boolean):TDef;
      var
        dummypos : TFilePosInfo;
{$push}
{$warn 5036 off}
      begin
        result:=generate_specialization_phase1(context,genericdef,enforce_unit,nil,'',nil,dummypos);
      end;
{$pop}


    function generate_specialization_phase1(out context:TSpecializationContext;genericdef:TDef;enforce_unit:boolean;const symname:string;SymTable:TSymTable):TDef;
      var
        dummypos : TFilePosInfo;
{$push}
{$warn 5036 off}
      begin
        result:=generate_specialization_phase1(context,genericdef,enforce_unit,nil,symname,SymTable,dummypos);
      end;
{$pop}


    function generate_specialization_phase1(out context:TSpecializationContext;genericdef:TDef;enforce_unit:boolean;parsedtype:TDef;const symname:string;SymTable:TSymTable;parsedpos:TFilePosInfo):TDef;
      var
        found,
        err : boolean;
        i,
        gencount : LongInt;
        countstr,genname,ugenname,prettygenname: string;
        tmpstack : TFPObjectList;
        symowner : TSymTable;
        hmodule : TModule;
      begin
        context:=nil;
        result:=nil;

        { either symname must be given or genericdef needs to be valid }
        if (symname='') and
            (not Assigned(genericdef) or
              (
                (genericdef.typ<>procdef) and
                (
                  not Assigned(genericdef.typesym) or
                  (genericdef.typesym.typ<>typesym)
                ) and
                (
                  (genericdef.typ<>objectdef) or
                  not (oo_is_forward in TObjectDef(genericdef).objectoptions)
                )
              ) or
              (
                (genericdef.typ=procdef) and
                (
                  not Assigned(TProcDef(genericdef).procsym) or
                  (TProcDef(genericdef).procsym.typ<>procsym)
                )
              )
            ) then
          begin
            InternalError(2019112401);
          end;

        if not Assigned(parsedtype) and not try_to_consume(_LT) then
          begin
            consume(_LSHARPBRACKET);
            { handle "<>" }
            if (CurrentScanner.token=_GT) or (CurrentScanner.token=_RSHARPBRACKET) then
              begin
                Message(type_e_type_id_expected);
                if not try_to_consume(_GT) then
                  try_to_consume(_RSHARPBRACKET);
                result:=generrordef;
                exit;
              end;
          end;

        context:=TSpecializationContext.create;

        { Parse type parameters }
        err:=not parse_generic_specialization_types_internal(context.paramlist,context.poslist,context.prettyname,context.specializename,parsedtype,parsedpos);
        if err then
          begin
            if not try_to_consume(_GT) then
              try_to_consume(_RSHARPBRACKET);
            context.free;
            context:=nil;
            result:=generrordef;
            exit;
          end;

        { use the name of the symbol as procvars return a user friendly version
          of the name }
        if symname='' then
          begin
            if genericdef.typ=procdef then
              genname:=TProcDef(genericdef).procsym.realname
            else if Assigned(genericdef.typesym) then
              genname:=TTypeSym(genericdef.typesym).realname
            else if (genericdef.typ=objectdef) and (oo_is_forward in TObjectDef(genericdef).objectoptions) then
              genname:=TObjectDef(genericdef).objrealname^
            else
              InternalError(2020071201);
          end
        else
          genname:=symname;

        { in case of non-Delphi mode the type name could already be a generic
          def (but maybe the wrong one) }
        if Assigned(genericdef) and
            ([df_generic,df_specialization]*genericdef.defoptions<>[]) then
          begin
            { remove the type count suffix from the generic's name }
            for i:=Length(genname) downto 1 do
              if genname[i]='$' then
                begin
                  genname:=copy(genname,1,i-1);
                  break;
                end;
            { in case of a specialization we've only reached the specialization
              checksum yet }
            if df_specialization in genericdef.defoptions then
              for i:=length(genname) downto 1 do
                if genname[i]='$' then
                  begin
                    genname:=copy(genname,1,i-1);
                    break;
                  end;
          end
        else
          begin
            split_generic_name(genname,ugenname,gencount);
            if genname<>ugenname then
              genname:=ugenname;
          end;

        { search a generic with the given count of params }
        countstr:='';
        str(context.paramlist.Count,countstr);

        prettygenname:=genname;
        genname:=genname+'$'+countstr;
        ugenname:=upper(genname);

        context.genname:=genname;

        if Assigned(genericdef) then
          symowner:=genericdef.owner
        else
          symowner:=SymTable;

        if Assigned(symowner) and (symowner.symtabletype in [objectsymtable,recordsymtable]) then
          begin
            if symowner.symtabletype = objectsymtable then
              found:=searchsym_in_class(TObjectDef(symowner.defowner),TObjectDef(symowner.defowner),ugenname,context.sym,context.SymTable,[])
            else
              found:=searchsym_in_record(TAbstractRecordDef(symowner.defowner),ugenname,context.sym,context.SymTable);
            if not found then
              found:=searchsym(ugenname,context.sym,context.SymTable);
          end
        else if enforce_unit then
          begin
            if not Assigned(symowner) then
              InternalError(2022102101);
            if not (symowner.symtabletype in [GlobalSymTable,staticsymtable]) then
              InternalError(2022102102);
            hmodule:=find_module_from_symtable(symowner);
            if not Assigned(hmodule) then
              InternalError(2022102103);
            found:=searchsym_in_module(hmodule,ugenname,context.sym,context.SymTable);
          end
        else
          found:=searchsym(ugenname,context.sym,context.SymTable);

        if found and (context.sym.typ=absolutevarsym) and
            (vo_is_funcret in TAbstractVarSym(context.sym).varoptions) then
          begin
            { we found the function result alias of a generic function; go up the
              symbol stack *before* this alias was inserted, so that we can
              (hopefully) find the correct generic symbol }
            tmpstack:=TFPObjectList.create(false);
            while Assigned(SymTableStack.top) do
              begin
                tmpstack.Add(SymTableStack.top);
                SymTableStack.pop(SymTableStack.top);
                if tmpstack.Last=context.SymTable then
                  break;
              end;
            if not Assigned(SymTableStack.top) then
              InternalError(2019123001);
            found:=searchsym(ugenname,context.sym,context.SymTable);
            for i:=tmpstack.count-1 downto 0 do
              SymTableStack.push(TSymTable(tmpstack[i]));
            tmpstack.free;
            tmpstack := nil;
          end;

        if not found or not (context.sym.typ in [typesym,procsym]) then
          begin
            identifier_not_found(prettygenname);
            if not try_to_consume(_GT) then
              try_to_consume(_RSHARPBRACKET);
            context.free;
            context:=nil;
            result:=generrordef;
            exit;
          end;

        { we've found the correct def }
        if context.sym.typ=typesym then
          result:=TStoredDef(TTypeSym(context.sym).typedef)
        else
          begin
            if TProcSym(context.sym).procdeflist.count=0 then
              InternalError(2015061203);
            result:=TStoredDef(TProcSym(context.sym).procdefList[0]);
          end;

        if not try_to_consume(_GT) then
          consume(_RSHARPBRACKET);
      end;

    function generate_specialization_phase2(context:TSpecializationContext;genericdef:TStoredDef;parse_class_parent:boolean;const _prettyname:AnsiString):TDef;

        procedure unset_forwarddef(def: TDef);
          var
            st : TSymTable;
            i : LongInt;
          begin
            case def.typ of
              procdef:
                TProcDef(def).forwarddef:=false;
              objectdef,
              recorddef:
                begin
                  st:=def.getsymtable(gs_record);
                  for i:=0 to st.deflist.count-1 do
                    unset_forwarddef(TDef(st.deflist[i]));
                end;
              else
                ;
            end;
          end;

        procedure retrieve_genericdef_or_procsym(sym:TSym;out gendef:TDef;out psym:TSym);
          var
            i : LongInt;
          begin
            gendef:=nil;
            psym:=nil;
            case sym.typ of
              typesym:
                begin
                  gendef:=TTypeSym(sym).typedef
                end;
              procsym:
                begin
                  for i:=0 to TProcSym(sym).procdeflist.count-1 do
                    if TStoredDef(TProcSym(sym).procdeflist[i]).genericdef=genericdef then
                      begin
                        gendef:=TDef(TProcSym(sym).procdeflist[i]);
                        break;
                      end;
                  psym:=sym;
                end
              else
                InternalError(200710171);
            end;
          end;

        function find_in_hierarchy(def:TDef;generictypelist:TFPHashObjectList):TDef;
          var
            paramdef1,
            paramdef2 : TDef;
            allequal : boolean;
            i : LongInt;
          begin
            result:=nil;
            while Assigned(def) do
              begin
                if (df_generic in def.defoptions) and (def=genericdef) then
                  begin
                    result:=def;
                    break;
                  end;
                { the following happens when a routine with its parent struct
                  as parameter is specialized as a parameter or result of a
                  generic function }
                if (df_specialization in def.defoptions) and (TStoredDef(def).genericdef=genericdef) then
                  begin
                    if TStoredDef(def).genericparas.count=generictypelist.count then
                      begin
                        allequal:=true;
                        for i:=0 to generictypelist.count-1 do
                          begin
                            if TSym(generictypelist[i]).typ<>TSym(TStoredDef(def).genericparas[i]).typ then
                              begin
                                allequal:=false;
                                break;
                              end;
                            if TSym(generictypelist[i]).typ=constsym then
                              paramdef1:=TConstSym(generictypelist[i]).constdef
                            else
                              paramdef1:=TTypeSym(generictypelist[i]).typedef;
                            if TSym(TStoredDef(def).genericparas[i]).typ=constsym then
                              paramdef2:=TConstSym(TStoredDef(def).genericparas[i]).constdef
                            else
                              paramdef2:=TTypeSym(TStoredDef(def).genericparas[i]).typedef;
                            if not equal_defs(paramdef1,paramdef2) then
                              begin
                                allequal:=false;
                                break;
                              end;
                            if (TSym(generictypelist[i]).typ=constsym) and
                                (
                                  (TConstSym(generictypelist[i]).consttyp<>TConstSym(TStoredDef(def).genericparas[i]).consttyp) or
                                  not same_constvalue(TConstSym(generictypelist[i]).consttyp,TConstSym(generictypelist[i]).value,TConstSym(TStoredDef(def).genericparas[i]).value)
                                ) then
                                begin
                                  allequal:=false;
                                  break;
                                end;
                          end;
                        if allequal then
                          begin
                            result:=def;
                            break;
                          end;
                      end;
                  end;
                if Assigned(def.owner) then
                  def:=TStoredDef(def.owner.defowner)
                else
                  def:=nil;
              end;
          end;

      function has_generic_paras(adef: TStoredDef): boolean;
        var
          i: Integer;
        begin
          result:=False;
          if adef.genericparas<>nil then
            for i:=0 to adef.genericparas.Count-1 do
              if ((TSym(adef.genericparas[i]).typ=typesym) and (sp_generic_para in TSym(adef.genericparas[i]).symoptions)) or
                  ((TSym(adef.genericparas[i]).typ=constsym) and not (sp_generic_const in TSym(adef.genericparas[i]).symoptions)) then
                exit(true);
        end;

      var
        finalspecializename,
        ufinalspecializename : TIDString;
        hierarchy,
        prettyname : AnsiString;
        generictypelist : TFPHashObjectList;
        srsymtable,
        specializest : TSymTable;
        hashedid : THashedIDString;
        tempst : TGlobalSymTable;
        tsrsym : TTypeSym;
        psym,
        srsym : TSym;
        flags : THCCFlags;
        def : TDef;
        old_block_type : TBlockType;
        state : TSpecializationState;
        old_current_structdef : TAbstractRecordDef;
        old_current_specializedef,
        old_current_genericdef : TStoredDef;
        old_current_procinfo : TProcInfo;
        old_module_procinfo : tobject;
        hmodule : TModule;
        oldcurrent_filepos : TFilePosInfo;
        recordbuf : TDynamicArray;
        hadtypetoken : boolean;
        i,
        replaydepth : LongInt;
        hdef : TDef;
        item : tobject;
        hintsprocessed : boolean;
        pd : TProcDef;
        pdflags : TPDFlags;
        ppflags : TParseProcFlags;
      begin
        if not Assigned(context) then
          InternalError(2015052203);

        result:=nil;

        pd:=nil;
        hmodule:=nil;

        if not check_generic_constraints(genericdef,context.paramlist,context.poslist) then
          begin
            { the parameters didn't fit the constraints, so don't continue with the
              specialization }
            result:=generrordef;
            exit;
          end;

        { build the new type's name }
        hierarchy:=genericdef.ownerhierarchyname;
        if Assigned(genericdef.owner) then
          begin
            hmodule:=find_module_from_symtable(genericdef.owner);
            if not Assigned(hmodule) then
              InternalError(2022102801);
            if hierarchy<>'' then
              hierarchy:='.'+hierarchy;
            hierarchy:=hmodule.ModuleName^+hierarchy;
          end;
        finalspecializename:=generate_generic_name(context.genname,context.specializename,hierarchy);
        ufinalspecializename:=upper(finalspecializename);
        if genericdef.typ=procdef then
          prettyname:=TProcDef(genericdef).procsym.prettyname
        else
          prettyname:=genericdef.typesym.prettyname;
        prettyname:=prettyname+'<'+context.prettyname+'>';
        generictypelist:=TFPHashObjectList.create(false);

        { build the list containing the types for the generic params }
        if not Assigned(genericdef.genericparas) then
          InternalError(2013092601);
        if context.paramlist.count<>genericdef.genericparas.count then
          InternalError(2013092603);
        for i:=0 to genericdef.genericparas.Count-1 do
          begin
            srsym:=TSym(genericdef.genericparas[i]);
            if not (sp_generic_para in srsym.symoptions) then
              InternalError(2013092602);
            generictypelist.add(srsym.realname,context.paramlist[i]);
          end;

        { Special case if we are referencing the current defined object }
        if Assigned(CurrentStructDef) and
           (CurrentStructDef.objname^=ufinalspecializename) then
          result:=CurrentStructDef;

        { Can we reuse an already specialized type? }

        { for this first check whether we are currently specializing a nested
          type of the current (main) specialization (this is necessary, because
          during that time the symbol of the main specialization will still
          contain a reference to an errordef) }
        if not Assigned(result) and Assigned(CurrentSpecializeDef) then
          begin
            def:=CurrentSpecializeDef;
            repeat
              if def.typ in [objectdef,recorddef] then
                if TAbstractRecordDef(def).objname^=ufinalspecializename then begin
                  result:=def;
                  break;
                end;
              if Assigned(def.owner) then
                def:=TStoredDef(def.owner.defowner)
              else
                { this can happen when specializing a generic function }
                def:=nil;
            until not Assigned(def) or not (df_specialization in def.defoptions);
          end;

        { if the genericdef is the def we are currently parsing (or one of its parents) then we can
          not use it for specializing as the tokenbuffer is not yet set (and we aren't done with
          parsing anyway), so for now we treat those still as generic defs without doing a partial
          specialization }
        if not Assigned(result) then
          begin
            def:=CurrentGenericDef;
            if def=genericdef then
              result:=def
            else if Assigned(CurrentGenericDef) then
              result:=find_in_hierarchy(CurrentGenericDef,generictypelist);
            if not Assigned(result) and Assigned(CurrentSpecializeDef) then
              result:=find_in_hierarchy(CurrentSpecializeDef,generictypelist);
          end;

        { decide in which symtable to put the specialization }
        if Assigned(context.forwarddef) then
          begin
            specializest:=context.forwarddef.owner;
          end
        else if parse_generic and not Assigned(result) then
          begin
            srsymtable:=SymTableStack.top;
            if (srsymtable.symtabletype in [localsymtable,parasymtable]) and TStoredDef(srsymtable.defowner).is_specialization then
              { if we are currently specializing a routine we need to specialize into
                the routine's local- or parasymtable so that they are correctly
                registered should the specialization be finalized }
              specializest:=srsymtable
            else if Assigned(CurrentProcInfo) and (df_generic in CurrentProcInfo.procdef.defoptions) then
              { if we are parsing the definition of a method we specialize into
                the local symtable of it }
              specializest:=CurrentProcInfo.procdef.getsymtable(gs_local)
            else
              begin
                if not Assigned(CurrentGenericDef) then
                  InternalError(2014050901);
                { we specialize the partial specialization into the symtable of the currently parsed
                  generic }
                case CurrentGenericDef.typ of
                  procvardef:
                    specializest:=CurrentGenericDef.getsymtable(gs_para);
                  procdef:
                    specializest:=CurrentGenericDef.getsymtable(gs_local);
                  objectdef,
                  recorddef:
                    specializest:=CurrentGenericDef.getsymtable(gs_record);
                  arraydef:
                    specializest:=TArrayDef(CurrentGenericDef).SymTable;
                  else
                    InternalError(2014050902);
                end;
              end;
          end
        else
          begin
            { if one of the type parameters resolves to a type living in a
              local- or parasymtable then use that local symtable for the
              specialization. Walk the underlying typedef chain (pointer,
              array, set, ...) so that e.g. TEnumerable<TLocal>.PT = ^TLocal,
              when used to specialize TEnumerator<PT>, is recognised as
              proc-local rather than wrongly placed at unit scope (which
              would result in a PPU defref that fails to resolve on reload). }
            specializest:=nil;
            for i:=0 to context.paramlist.count-1 do
              begin
                psym:=TSym(context.paramlist[i]);
                if psym.typ=typesym then
                  hdef:=TTypeSym(psym).typedef
                else
                  hdef:=nil;
                while Assigned(hdef) do
                  begin
                    if Assigned(hdef.owner) and
                       (hdef.owner.symtabletype in [localsymtable,parasymtable]) then
                      begin
                        if (hdef.owner.symtabletype=parasymtable) and
                           Assigned(hdef.owner.defowner) and
                           (hdef.owner.defowner.typ=procdef) then
                          specializest:=TProcDef(hdef.owner.defowner).getsymtable(gs_local)
                        else
                          specializest:=hdef.owner;
                        break;
                      end;
                    case hdef.typ of
                      pointerdef:
                        hdef:=TPointerDef(hdef).pointeddef;
                      arraydef:
                        hdef:=TArrayDef(hdef).elementdef;
                      setdef:
                        hdef:=TSetDef(hdef).elementdef;
                      filedef:
                        hdef:=TFileDef(hdef).typedfiledef;
                      classrefdef:
                        hdef:=TClassRefDef(hdef).pointeddef;
                      else
                        hdef:=nil;
                    end;
                  end;
                if Assigned(specializest) then
                  break;
                { also accept the param's immediate sym owner being a local
                  scope — covers the case where the type-arg is a const-sym
                  rather than a typesym }
                if psym.owner.symtabletype in [localsymtable,parasymtable] then
                  begin
                    if (psym.owner.symtabletype=parasymtable) and
                       Assigned(psym.owner.defowner) and
                       (psym.owner.defowner.typ=procdef) then
                      specializest:=TProcDef(psym.owner.defowner).getsymtable(gs_local)
                    else
                      specializest:=psym.owner;
                    break;
                  end;
              end;

            if not Assigned(specializest) then
              if CurrentModule.is_unit and CurrentModule.in_interface then
                specializest:=CurrentModule.GlobalSymTable
              else
                specializest:=CurrentModule.localsymtable;
          end;
        if not Assigned(specializest) then
          InternalError(2014050910);

        { now check whether there is a specialization somewhere else }
        psym:=nil;
        if not Assigned(result) then
          begin
            hashedid.id:=ufinalspecializename;

            if (specializest.symtabletype=objectsymtable) and not Assigned(context.forwarddef) then
              begin
                { search also in parent classes }
                if not Assigned(CurrentGenericDef) or (CurrentGenericDef.typ<>objectdef) then
                  InternalError(2016112901);
                if not searchsym_in_class(TObjectDef(CurrentGenericDef),TObjectDef(CurrentGenericDef),ufinalspecializename,srsym,srsymtable,[]) then
                  srsym:=nil;
              end
            else
              srsym:=TSym(specializest.findwithhash(hashedid));

            if Assigned(context.forwarddef) then
              begin
                { just do a few sanity checks }
                if not Assigned(srsym) or not (srsym.typ=typesym) then
                  InternalError(2020070306);
                if TTypeSym(srsym).typedef<>context.forwarddef then
                  InternalError(2020070307);
              end
            else if Assigned(srsym) then
              begin
                retrieve_genericdef_or_procsym(srsym,result,psym);
              end
            else
              { the generic could have been specialized in the globalsymtable
                already, so search there as well }
              if (specializest<>CurrentModule.GlobalSymTable) and Assigned(CurrentModule.GlobalSymTable) then
                begin
                  srsym:=TSym(CurrentModule.GlobalSymTable.findwithhash(hashedid));
                  if Assigned(srsym) then
                    begin
                      retrieve_genericdef_or_procsym(srsym,result,psym);
                    end;
                end;
          end;

        if not Assigned(result) then
          begin
            specialization_init(genericdef,state);

            { push a temporary global symtable so that the specialization is
              added to the correct symtable; this symtable does not contain
              any other symbols, so that the type resolution can not be
              influenced by symbols in the current unit }
            tempst:=TSpecializeSymTable.create(CurrentModule.ModuleName^,CurrentModule.ModuleID);
            SymTableStack.push(tempst);

            { Reparse the original type definition }
              begin
                old_current_specializedef:=nil;
                old_current_genericdef:=nil;
                old_current_structdef:=nil;
                old_current_procinfo:=CurrentProcInfo;
                old_module_procinfo:=CurrentModule.ProcInfo;

                CurrentProcInfo:=nil;
                CurrentModule.ProcInfo:=nil;

                if parse_class_parent then
                  begin
                    old_current_structdef:=CurrentStructDef;
                    old_current_genericdef:=CurrentGenericDef;
                    old_current_specializedef:=CurrentSpecializeDef;

                    if genericdef.owner.symtabletype in [recordsymtable,objectsymtable] then
                      CurrentStructDef:=TAbstractRecordDef(genericdef.owner.defowner)
                    else
                      CurrentStructDef:=nil;
                    CurrentGenericDef:=nil;
                    CurrentSpecializeDef:=nil;
                  end;

                maybe_add_waiting_unit(genericdef);

                { First a new sym so we can reuse this specialization and
                  references to this specialization can be handled }
                if genericdef.typ=procdef then
                  if Assigned(psym) then
                    srsym:=psym
                  else
                    srsym:=CProcSym.create(finalspecializename)
                else
                  srsym:=CTypeSym.create(finalspecializename,generrordef);
                { insert the symbol only if we don't know already that we have
                  a procsym to add it to and we aren't dealing with a forwarddef }
                if not Assigned(psym) and not Assigned(context.forwarddef) then
                  specializest.insertsym(srsym);

                { specializations are declarations as such it is the wisest to
                  declare set the blocktype to "type"; otherwise we'll
                  experience unexpected side effects like the addition of
                  classrefdefs if we have a generic that's derived from another
                  generic }
                old_block_type:=Block_Type;
                Block_Type:=bt_type;

                if (
                     (genericdef.typ=procdef) and
                     not Assigned(TProcDef(genericdef).genericdecltokenbuf)
                   ) or (
                     (genericdef.typ<>procdef) and
                     not Assigned(genericdef.generictokenbuf)
                   ) then
                  InternalError(200511171);
                if hmodule=nil then
                  InternalError(2012051202);
                oldcurrent_filepos:=CurrentFilePos;
                { use the index the module got from the current compilation process }
                CurrentFilePos.moduleindex:=hmodule.ModuleID;
                CurrentTokenPos:=CurrentFilePos;
                if parse_generic then
                  begin
                    recordbuf:=CurrentScanner.recordtokenbuf;
                    CurrentScanner.recordtokenbuf:=nil;
                  end
                else
                  recordbuf:=nil;
                replaydepth:=CurrentScanner.replay_stack_depth;
                if genericdef.typ=procdef then
                  begin
                    CurrentScanner.startreplaytokens(TProcDef(genericdef).genericdecltokenbuf,hmodule.ChangeEndian);
                    parse_proc_head(TProcDef(genericdef).struct,TProcDef(genericdef).proctypeoption,[],genericdef,generictypelist,pd);
                    if Assigned(pd) then
                      begin
                        if Assigned(psym) then
                          pd.procsym:=psym
                        else
                          pd.procsym:=srsym;
                        ppflags:=[];
                        if po_classmethod in TProcDef(genericdef).procoptions then
                          include(ppflags,ppf_classmethod);
                        parse_proc_dec_finish(pd,ppflags,TProcDef(genericdef).struct);
                      end;
                    result:=pd;
                  end
                else
                  begin
                    CurrentScanner.startreplaytokens(genericdef.generictokenbuf,hmodule.ChangeEndian);
                    if Assigned(context.forwarddef) then
                      begin
                        tsrsym:=nil;
                        result:=parse_forward_declaration(context.forwarddef.typesym,ufinalspecializename,finalspecializename,genericdef,generictypelist,tsrsym);
                        srsym:=tsrsym;
                      end
                    else
                      begin
                        hadtypetoken:=false;

                        { ensure a pretty name for error messages, might be chanced below }
                        if _prettyname<>'' then
                          TTypeSym(srsym).fprettyname:=_prettyname
                        else
                          TTypeSym(srsym).fprettyname:=prettyname;

                        read_named_type(result,srsym,genericdef,generictypelist,false,hadtypetoken);
                        TTypeSym(srsym).typedef:=result;
                        result.typesym:=srsym;
                      end;

                    if _prettyname<>'' then
                      TTypeSym(result.typesym).fprettyname:=_prettyname
                    else
                      TTypeSym(result.typesym).fprettyname:=prettyname;
                  end;
                CurrentFilePos:=oldcurrent_filepos;

                { Note regarding hint directives:
                  There is no need to remove the flags for them from the
                  specialized generic symbol, because hint directives that
                  follow the specialization are handled by the code in
                  pdecl.types_dec and added to the type symbol.
                  E.g.: TFoo = TBar<Blubb> deprecated;
                  Here the symbol TBar$1$Blubb will contain the
                  "sp_hint_deprecated" flag while the TFoo symbol won't.}

                case result.typ of
                  { Build VMT indexes for classes and read hint directives }
                  objectdef:
                    begin
                      if replaydepth<CurrentScanner.replay_stack_depth then
                        begin
                          try_consume_hintdirective(srsym.symoptions,srsym.deprecatedmsg);
                          if replaydepth<CurrentScanner.replay_stack_depth then
                            consume(_SEMICOLON);
                        end;

                      if oo_is_forward in TObjectDef(result).objectoptions then
                        add_forward_generic_def(result,context)
                      else if not (oo_inherits_not_specialized in TObjectDef(result).objectoptions) then
                        build_vmt(TObjectDef(result))
                      else
                        { update the procdevs to add hidden self param }
                        insert_struct_hidden_paras(TObjectDef(result));
                    end;
                  { handle params, calling convention, etc }
                  procvardef:
                    begin
                      hintsprocessed:=false;
                      if replaydepth<CurrentScanner.replay_stack_depth then
                        begin
                          if not check_proc_directive(true) then
                            begin
                              hintsprocessed:=try_consume_hintdirective(TTypeSym(srsym).symoptions,TTypeSym(srsym).deprecatedmsg);
                              if replaydepth<CurrentScanner.replay_stack_depth then
                                consume(_SEMICOLON);
                            end
                          else
                            hintsprocessed:=true;
                        end;
                      if replaydepth<CurrentScanner.replay_stack_depth then
                        parse_proctype_directives(TProcVarDef(result));
                      if po_is_function_ref in TProcVarDef(result).procoptions then
                        adjust_funcref(result,srsym,nil);
                      if result.typ=procvardef then
                        flags:=hcc_default_actions_intf
                      else
                        flags:=hcc_default_actions_intf_struct;
                      handle_calling_convention(result,flags);
                      if not hintsprocessed and (replaydepth<CurrentScanner.replay_stack_depth) then
                        begin
                          try_consume_hintdirective(TTypeSym(srsym).symoptions,TTypeSym(srsym).deprecatedmsg);
                          if replaydepth<CurrentScanner.replay_stack_depth then
                            consume(_SEMICOLON);
                        end;
                    end;
                  procdef:
                    begin
                      pdflags:=[];
                      if genericdef.owner.symtabletype=objectsymtable then
                        include(pdflags,pd_object)
                      else if genericdef.owner.symtabletype=recordsymtable then
                        include(pdflags,pd_record);
                      parse_proc_directives(pd,pdflags);
                      while try_consume_hintdirective(pd.symoptions,pd.deprecatedmsg) do
                        consume(_SEMICOLON);
                      if parse_generic then
                        handle_calling_convention(TProcDef(result),hcc_default_actions_intf)
                      else
                        handle_calling_convention(TProcDef(result),hcc_default_actions_impl);
                      proc_add_definition(TProcDef(result));
                      { for partial specializations we implicitly declare the routine as
                        having its implementation although we'll not specialize it in reality }
                      if parse_generic then
                        unset_forwarddef(result);
                    end;
                  else
                    { parse hint directives for records and arrays }
                    if replaydepth<CurrentScanner.replay_stack_depth then begin
                      try_consume_hintdirective(srsym.symoptions,srsym.deprecatedmsg);
                      if replaydepth<CurrentScanner.replay_stack_depth then
                        consume(_SEMICOLON);
                    end;
                end;
                { Consume the remainder of the buffer }
                while CurrentScanner.replay_stack_depth>replaydepth do
                  consume(CurrentScanner.token);

                if Assigned(recordbuf) then
                  begin
                    if Assigned(CurrentScanner.recordtokenbuf) then
                      InternalError(2014050909);
                    CurrentScanner.recordtokenbuf:=recordbuf;
                  end;

                Block_Type:=old_block_type;
                CurrentProcInfo:=old_current_procinfo;
                CurrentModule.ProcInfo:=old_module_procinfo;
                if parse_class_parent then
                  begin
                    CurrentStructDef:=old_current_structdef;
                    CurrentGenericDef:=old_current_genericdef;
                    CurrentSpecializeDef:=old_current_specializedef;
                  end;
              end;

            { extract all created symbols and defs from the temporary symtable
              and add them to the specializest }
            for i:=tempst.SymList.Count-1 downto 0 do
              begin
                item:=tempst.SymList.Items[i];
                { using changeowner the symbol is automatically added to the
                  new symtable }
                TSym(item).ChangeOwner(specializest);
              end;

            for i:=tempst.DefList.Count-1 downto 0 do
              begin
                item:=tempst.DefList.Items[i];
                { using changeowner the def is automatically added to the new
                  symtable }
                TDef(item).ChangeOwner(specializest);
                { for partial specializations we implicitly declare any methods as having their
                  implementations although we'll not specialize them in reality }
                if parse_generic or has_generic_paras(TStoredDef(item)) then
                  unset_forwarddef(TDef(item));
              end;

            { if a generic was declared during the specialization we need to
              flag the specialize symtable accordingly }
            if sto_has_generic in tempst.tableoptions then
              specializest.includeoption(sto_has_generic);

            tempst.free;
            tempst := nil;

            specialization_done(state);

            { procdefs are only added once we know which overload we use }
            if not parse_generic and (result.typ<>procdef) and
              not has_generic_paras(TStoredDef(result)) then
                  CurrentModule.pendingspecializations.add(result.typename,result);
          end;

        generictypelist.free;
        generictypelist := nil;
        if Assigned(genericdef) then
          begin
            { check the hints of the found generic symbol }
            if genericdef.typ=procdef then
              srsym:=TProcDef(genericdef).procsym
            else
              srsym:=genericdef.typesym;
            check_hints(srsym,srsym.symoptions,srsym.deprecatedmsg);
          end;
      end;


    procedure generate_specialization(var tt:TDef;enforce_unit:boolean;parse_class_parent:boolean;const _prettyname:string;parsedtype:TDef;const symname:string;parsedpos:TFilePosInfo);
      var
        context : TSpecializationContext;
        genericdef : TStoredDef;
      begin
        genericdef:=TStoredDef(generate_specialization_phase1(context,tt,enforce_unit,parsedtype,symname,nil,parsedpos));
        if genericdef<>generrordef then
          genericdef:=TStoredDef(generate_specialization_phase2(context,genericdef,parse_class_parent,_prettyname));
        tt:=genericdef;
        if Assigned(context) then
          context.free; // no nil needed
      end;


    function parse_generic_parameters(allowconstraints:boolean):TFPHashObjectList;
      var
        generictype : TStoredSym;
        i,firstidx,const_list_index : LongInt;
        srsymtable : TSymTable;
        basedef,def : TDef;
        defname : TIDString;
        allowconst,
        allowconstructor,
        is_const,
        doconsume : boolean;
        constraintdata : TGenericConstraintData;
        old_block_type : TBlockType;
        fileinfo : TFilePosInfo;
      begin
        result:=TFPHashObjectList.create(false);
        firstidx:=0;
        const_list_index:=0;
        old_block_type:=Block_Type;
        Block_Type:=bt_type;
        allowconst:=true;
        is_const:=false;
        repeat
          if allowconst and try_to_consume(_CONST) then
            begin
              allowconst:=false;
              is_const:=true;
              const_list_index:=result.count;
            end;
          if CurrentScanner.token=_ID then
            begin
              if is_const then
                generictype:=CConstSym.create_undefined(CurrentScanner.orgpattern,cundefinedtype)
              else
                generictype:=CTypeSym.create(CurrentScanner.orgpattern,cundefinedtype);
              { type parameters need to be added as strict private }
              generictype.visibility:=vis_strictprivate;
              include(generictype.symoptions,sp_generic_para);
              result.add(CurrentScanner.orgpattern,generictype);
            end;
          consume(_ID);
          fileinfo:=CurrentTokenPos;
          { const restriction }
          if is_const and try_to_consume(_COLON) then
            begin
              def:=nil;
              { parse the type and assign the const type to generictype  }
              single_type(def,[]);
              for i:=const_list_index to result.count-1 do
                begin
                  { finalize constant information once type is known }
                  if Assigned(def) and (def.typ in tgeneric_param_const_types) then
                    begin
                      case def.typ of
                        orddef,
                        enumdef:
                          TConstSym(result[i]).consttyp:=constord;
                        stringdef:
                          TConstSym(result[i]).consttyp:=conststring;
                        floatdef:
                          TConstSym(result[i]).consttyp:=constreal;
                        setdef:
                          TConstSym(result[i]).consttyp:=constset;
                        { pointer always refers to nil with constants }
                        pointerdef:
                          TConstSym(result[i]).consttyp:=constnil;
                        else
                          InternalError(2020011402);
                      end;
                      TConstSym(result[i]).constdef:=def;
                    end
                  else
                    Message1(type_e_generic_const_type_not_allowed,def.fulltypename);
                end;
              { after type restriction const list terminates }
              is_const:=false;
            end
          { type restriction }
          else if try_to_consume(_COLON) then
            begin
              if not allowconstraints then
                Message(parser_e_generic_constraints_not_allowed_here);
              { construct a name which can be used for a type specification }
              constraintdata:=TGenericConstraintData.create;
              constraintdata.fileinfo:=fileinfo;
              defname:='';
              str(CurrentModule.deflist.count,defname);
              defname:='$gendef'+defname;

              allowconstructor:=m_delphi in CurrentSettings.ModeSwitches;

              basedef:=generrordef;
              repeat
                doconsume:=true;

                case CurrentScanner.token of
                  _CONSTRUCTOR:
                    begin
                      if not allowconstructor or (gcf_constructor in constraintdata.flags) then
                        Message(parser_e_illegal_expression);
                      include(constraintdata.flags,gcf_constructor);
                      allowconstructor:=false;
                    end;
                  _CLASS:
                    begin
                      if gcf_class in constraintdata.flags then
                        Message(parser_e_illegal_expression);
                      if basedef=generrordef then
                        include(constraintdata.flags,gcf_class)
                      else
                        Message(parser_e_illegal_expression);
                    end;
                  _RECORD:
                    begin
                      if ([gcf_constructor,gcf_class]*constraintdata.flags<>[])
                          or (constraintdata.interfaces.count>0) then
                        Message(parser_e_illegal_expression)
                      else
                        begin
                          srsymtable:=TRecordSymTable.create(defname,0,1);
                          basedef:=CRecordDef.create(defname,srsymtable);
                          include(constraintdata.flags,gcf_record);
                          allowconstructor:=false;
                        end;
                    end;
                  else
                    begin
                      { after single_type "token" is the trailing ",", ";" or
                        ">"! }
                      doconsume:=false;
                      { def is already set to a class or record }
                      if gcf_record in constraintdata.flags then
                        Message(parser_e_illegal_expression);
                      single_type(def, [stoAllowSpecialization]);
                      { only types that are inheritable are allowed }
                      if (def.typ<>objectdef) or
                          not (TObjectDef(def).objecttype in [odt_class,odt_interfacecom,odt_interfacecorba,odt_interfacejava,odt_javaclass]) then
                        Message1(type_e_class_or_interface_type_expected,def.typename)
                      else
                        case TObjectDef(def).objecttype of
                          odt_class,
                          odt_javaclass:
                            begin
                              if gcf_class in constraintdata.flags then
                                { "class" + concrete class is not allowed }
                                Message(parser_e_illegal_expression)
                              else
                                { do we already have a concrete class? }
                                if basedef<>generrordef then
                                  Message(parser_e_illegal_expression)
                                else
                                  basedef:=def;
                            end;
                          odt_interfacecom,
                          odt_interfacecorba,
                          odt_interfacejava,
                          odt_dispinterface:
                            constraintdata.interfaces.add(def);
                          else
                            ;
                        end;
                    end;
                end;
                if doconsume then
                  consume(CurrentScanner.token);
              until not try_to_consume(_COMMA);

              if ([gcf_class,gcf_constructor]*constraintdata.flags<>[]) or
                  (constraintdata.interfaces.count>1) or
                  (
                    (basedef.typ=objectdef) and
                    (TObjectDef(basedef).objecttype in [odt_javaclass,odt_class])
                  ) then
                begin
                  if basedef.typ=errordef then
                    { don't pass an errordef as a parent to a tobjectdef }
                    basedef:=class_tobject
                  else
                    if (basedef.typ<>objectdef) or
                        not (TObjectDef(basedef).objecttype in [odt_javaclass,odt_class]) then
                      InternalError(2012101101);
                  basedef:=CObjectDef.create(TObjectDef(basedef).objecttype,defname,TObjectDef(basedef),false);
                  for i:=0 to constraintdata.interfaces.count-1 do
                    TObjectDef(basedef).register_implemented_interface(TObjectDef(constraintdata.interfaces[i]),false);
                end
              else
                if constraintdata.interfaces.count=1 then
                  begin
                    if basedef.typ<>errordef then
                      InternalError(2013021601);
                    def:=TDef(constraintdata.interfaces[0]);
                    basedef:=CObjectDef.create(TObjectDef(def).objecttype,defname,TObjectDef(def),false);
                    constraintdata.interfaces.delete(0);
                  end;

              if basedef.typ<>errordef then
                with TStoredDef(basedef) do
                  begin
                    genconstraintdata:=TGenericConstraintData.create;
                    genconstraintdata.flags:=constraintdata.flags;
                    genconstraintdata.interfaces.assign(constraintdata.interfaces);
                    genconstraintdata.fileinfo:=constraintdata.fileinfo;
                    include(defoptions,df_genconstraint);
                  end
              else
                { the constraint was rejected: recover as an unconstrained
                  parameter; keeping the shared errordef would corrupt its
                  typesym below and IE in check_generic_constraints later }
                basedef:=CUndefinedDef.create(false);

              for i:=firstidx to result.count-1 do
                TTypeSym(result[i]).typedef:=basedef;
              { we need a typesym in case we do a Delphi-mode inline
                specialization with this parameter; so just use the first sym }
              if not Assigned(basedef.typesym) then
                basedef.typesym:=TTypeSym(result[firstidx]);
              firstidx:=result.count;

              constraintdata.free;
              constraintdata := nil;
            end
          else
            begin
              if CurrentScanner.token=_SEMICOLON then
                begin
                  { two different typeless parameters are considered as incompatible }
                  for i:=firstidx to result.count-1 do
                    if TSym(result[i]).typ<>constsym then
                      begin
                        TTypeSym(result[i]).typedef:=CUndefinedDef.create(false);
                        TTypeSym(result[i]).typedef.typesym:=TTypeSym(result[i]);
                      end;
                  { a semicolon terminates a type parameter group }
                  firstidx:=result.count;
                end;
            end;
          if CurrentScanner.token=_SEMICOLON then
            begin
              is_const:=false;
              allowconst:=true;
            end;
        until not (try_to_consume(_COMMA) or try_to_consume(_SEMICOLON));
        { if the constant parameter is not terminated then the type restriction was
          not specified and we need to give an error }
        if is_const then
          consume(_COLON);
        { two different typeless parameters are considered as incompatible }
        for i:=firstidx to result.count-1 do
          if TSym(result[i]).typ<>constsym then
            begin
              TTypeSym(result[i]).typedef:=CUndefinedDef.create(false);
              TTypeSym(result[i]).typedef.typesym:=TTypeSym(result[i]);
            end;
        Block_Type:=old_block_type;
      end;


    procedure insert_generic_parameter_types(def:TStoredDef;genericdef:TStoredDef;genericlist:TFPHashObjectList;isfwd:boolean);
      var
        i : LongInt;
        generictype,
        fwdparam : TStoredSym;
        generictypedef : TDef;
        sym : TSym;
        st : TSymTable;
        fwdok : boolean;
        conv : TConvertType;
        op : TProcDef;
      begin
        def.genericdef:=genericdef;
        if not Assigned(genericlist) then
          exit;

        if Assigned(genericdef) then
          include(def.defoptions,df_specialization)
        else
          if genericlist.count>0 then
            include(def.defoptions,df_generic);

        case def.typ of
          recorddef,objectdef: st:=TAbstractRecordDef(def).SymTable;
          arraydef: st:=TArrayDef(def).SymTable;
          procvardef,procdef: st:=TAbstractProcDef(def).parast;
          else
            InternalError(201101020);
        end;

        { if we have a forwarddef we check whether the generic parameters are
          equal and otherwise ignore the list }
        if isfwd then
          begin
            fwdok:=true;
            if (genericlist.count>0) and
                (
                  not Assigned(def.genericparas)
                  or (def.genericparas.count<>genericlist.count)
                ) then
              fwdok:=false
            else
              begin
                for i:=0 to genericlist.count-1 do
                  begin
                    if def.genericparas.nameofindex(i)<>genericlist.nameofindex(i) then
                      begin
                        fwdok:=false;
                        break;
                      end;
                    generictype:=TStoredSym(genericlist[i]);
                    fwdparam:=TStoredSym(def.genericparas[i]);
                    op:=nil;
                    conv:=tc_equal;
                    if generictype.typ<>fwdparam.typ then
                      fwdok:=false
                    else if (generictype.typ=typesym) then
                      begin
                        if compare_defs_ext(TTypeSym(generictype).typedef,TTypeSym(fwdparam).typedef,nothingn,conv,op,[cdo_strict_genconstraint_check])<te_exact then
                          fwdok:=false;
                      end
                    else if (generictype.typ=constsym) then
                      begin
                        if (TConstSym(generictype).consttyp<>TConstSym(fwdparam).consttyp) or
                            (compare_defs_ext(TConstSym(generictype).constdef,TConstSym(fwdparam).constdef,nothingn,conv,op,[cdo_strict_genconstraint_check])<te_exact) then
                          fwdok:=false;
                      end
                    else
                      InternalError(2020070101);

                    if not fwdok then
                      break;
                  end;
              end;

            if not fwdok then
              Message(parser_e_forward_mismatch);

            exit;
          end;

        if (genericlist.count>0) and not Assigned(def.genericparas) then
          def.genericparas:=TFPHashObjectList.create(false);
        for i:=0 to genericlist.count-1 do
          begin
            generictype:=TStoredSym(genericlist[i]);
            if Assigned(generictype.owner) then
              begin
                if generictype.typ=typesym then
                  sym:=CTypeSym.create(genericlist.nameofindex(i),TTypeSym(generictype).typedef)
                else if generictype.typ=constsym then
                  { generictype is a constsym that was created in create_generic_constsym
                    during phase 1 so we pass this directly without copying }
                  begin
                    sym:=generictype;
                    { the sym name is still undefined so we set it to match
                      the generic param name so it's accessible }
                    sym.realname:=genericlist.nameofindex(i);
                    include(sym.symoptions,sp_generic_const);
                  end
                else
                  InternalError(2019021602);
                { type parameters need to be added as strict private }
                sym.visibility:=vis_strictprivate;
                st.insertsym(sym);
                include(sym.symoptions,sp_generic_para);
              end
            else
              begin
                if generictype.typ=typesym then
                  begin
                    generictypedef:=TTypeSym(generictype).typedef;
                    if (generictypedef.typ=undefineddef) and (generictypedef<>cundefinedtype) then
                      begin
                        { the generic parameters were parsed before the genericdef existed thus the
                          undefineddefs were added as part of the parent symtable }
                        if Assigned(generictypedef.owner) then
                          generictypedef.owner.DefList.Extract(generictypedef);
                        generictypedef.changeowner(st);
                      end;
                  end;
                st.insertsym(generictype);
                include(generictype.symoptions,sp_generic_para);
              end;
            def.genericparas.add(genericlist.nameofindex(i),generictype);
          end;
       end;

    procedure maybe_insert_generic_rename_symbol(const name:TIDString;genericlist:TFPHashObjectList);
      var
        gensym : TTypeSym;
      begin
        { for generics in non-Delphi modes we insert a private type symbol
          that has the same base name as the currently parsed generic and
          that references this defs }
        if not (m_delphi in CurrentSettings.ModeSwitches) and
            (
              (
                parse_generic and
                Assigned(genericlist) and
                (genericlist.count>0)
              ) or
              (
                Assigned(CurrentSpecializeDef) and
                Assigned(CurrentStructDef.genericdef) and
                (CurrentStructDef.genericdef.typ in [objectdef,recorddef]) and
                (pos('$',name)>0)
              )
            ) then
          begin
            { we need to pass nil as def here, because the constructor wants
              to set the typesym of the def which is not what we want }
            gensym:=CTypeSym.create(copy(name,1,pos('$',name)-1),nil);
            gensym.typedef:=CurrentStructDef;
            include(gensym.symoptions,sp_internal);
            { the symbol should be only visible to the generic class
              itself }
            gensym.visibility:=vis_strictprivate;
            SymTableStack.top.insertsym(gensym);
          end;
      end;

    function generate_generic_name(const name:TIDString;const specializename:AnsiString;const owner_hierarchy:AnsiString):TIDString;
    var
      crc : cardinal;
    begin
      if specializename='' then
        InternalError(2012061901);
      { build the new type's name }
      crc:=UpdateCRC32(0,specializename[1],length(specializename));
      result:=name+'$crc'+HexStr(crc,8);
      if owner_hierarchy<>'' then
        begin
          crc:=UpdateCRC32(0,owner_hierarchy[1],length(owner_hierarchy));
          result:=result+'_crc'+HexStr(crc,8);
        end;
    end;

    procedure split_generic_name(const name:TIDString;out nongeneric:string;out count:LongInt);
      var
        i,code : LongInt;
        countstr : string;
      begin
        for i:=length(name) downto 1 do
          if name[i]='$' then
            begin
              nongeneric:=copy(name,1,i-1);
              countstr:=copy(name,i+1,length(name)-i);
              val(countstr,count,code);
              if code<>0 then
                break;
              exit;
            end;
        nongeneric:=name;
        count:=0;
      end;


    procedure add_generic_dummysym(sym:TSym;const name:TIDString);
      var
        list: TFPObjectList;
        srsym : TSym;
        srsymtable : TSymTable;
        entry : TGenericDummyEntry;
        n : TIDString;
      begin
        if sp_generic_dummy in sym.symoptions then
          begin
            n:=sym.name;
            if n='' then
              n:=name;
            { did we already search for a generic with that name? }
            list:=TFPObjectList(CurrentModule.genericdummysyms.find(n));
            if not Assigned(list) then
              begin
                list:=TFPObjectList.create(true);
                CurrentModule.genericdummysyms.add(n,list);
              end;
            { is the dummy sym still "dummy"? }
            if (sym.typ=typesym) and
                (
                  { dummy sym defined in mode Delphi }
                  (TTypeSym(sym).typedef.typ=undefineddef) or
                  { dummy sym defined in non-Delphi mode }
                  (TStoredDef(TTypeSym(sym).typedef).is_generic)
                ) then
              begin
                { do we have a non-generic type of the same name
                  available? }
                if not searchsym_with_flags(n,srsym,srsymtable,[ssf_no_addsymref]) then
                  srsym:=nil;
              end
            else if sym.typ=procsym then
              srsym:=sym
            else
              { dummy symbol is already not so dummy anymore }
              srsym:=nil;
            if Assigned(srsym) then
              begin
                entry:=TGenericDummyEntry.create;
                entry.resolvedsym:=srsym;
                entry.dummysym:=sym;
                list.add(entry);
              end;
          end;
      end;


    function resolve_generic_dummysym(const name:TIDString):TSym;
      var
        list : TFPObjectList;
      begin
        list:=TFPObjectList(CurrentModule.genericdummysyms.find(name));
        if Assigned(list) and (list.count>0) then
          result:=TGenericDummyEntry(list.last).resolvedsym
        else
          result:=nil;
      end;


    function could_be_generic(const name:TIDString):boolean;
      begin
        result:=(name<>'') and
                  (CurrentModule.genericdummysyms.findindexof(name)>=0);
      end;


    function is_or_belongs_to_current_genericdef(def:TDef):boolean;
      var
        state : PSpecializationState;
      begin
        result:=true;
        if (def=CurrentGenericDef) or
            defs_belong_to_same_generic(def,CurrentGenericDef) then
          exit;
        state:=PSpecializationState(CurrentModule.specializestate);
        while Assigned(state) do
          begin
            if (state^.oldcurrent_genericdef=def) or
                defs_belong_to_same_generic(state^.oldcurrent_genericdef,def) then
              exit;
            state:=state^.oldspecializestate;
          end;
        result:=false;
      end;


    procedure specialization_init(genericdef:TDef;var state: TSpecializationState);
    var
      pu : TUsedUnit;
      hmodule : TModule;
      unitsyms : TFPHashObjectList;
      sym : TSym;
      SymTable : TSymTable;
      i : Integer;
      n : string;

    begin
      if not Assigned(genericdef) then
        InternalError(200705151);
      { Setup symtablestack at definition time
        to get types right, however this is not perfect, we should probably record
        the resolved symbols }
      state.OldSymTableStack:=SymTableStack;
      state.oldextendeddefs:=CurrentModule.extendeddefs;
      state.oldgenericdummysyms:=CurrentModule.genericdummysyms;
      state.oldcurrent_genericdef:=CurrentGenericDef;
      state.oldspecializestate:=PSpecializationState(CurrentModule.specializestate);
      state.oldoptoken:=optoken;
      optoken:=NOTOKEN;
      CurrentModule.specializestate:=@state;
      CurrentModule.extendeddefs:=TFPHashObjectList.create(true);
      CurrentModule.genericdummysyms:=TFPHashObjectList.create(true);
      SymTableStack:=TDefAwareSymTableStack.create;
      if not Assigned(genericdef.owner) then
        hmodule:=CurrentModule
      else
        hmodule:=find_module_from_symtable(genericdef.owner);
      if hmodule=nil then
        InternalError(200705152);
      { collect all unit syms in the generic's unit as we need to establish
        their unitsym.module link again so that unit identifiers can be used }
      unitsyms:=TFPHashObjectList.create(false);
      if (hmodule<>CurrentModule) and Assigned(hmodule.GlobalSymTable) then
        for i:=0 to hmodule.GlobalSymTable.symlist.count-1 do
          begin
            sym:=TSym(hmodule.GlobalSymTable.symlist[i]);
            if sym.typ=unitsym then
              begin
              n:=sym.realname;
              if (Copy(n,1,7)='$hidden') then
                Delete(n,1,7);
              unitsyms.add(upper(n),sym);
              end;
          end;
      { add all units if we are specializing inside the current unit (as the
        generic could have been declared in the implementation part), but load
        only interface units, if we are in a different unit as then the generic
        needs to be in the interface section }
      pu:=TUsedUnit(hmodule.used_units.first);
      while Assigned(pu) do
        begin
          if not Assigned(pu.u.GlobalSymTable) then
            { in certain circular, but valid unit constellations it can happen
              that we specialize a generic in a different unit that was used
              in the implementation section of the generic's unit and were the
              interface is still being parsed and thus the localsymtable is in
              reality the global symtable

              In addition to that it can also be the case that neither the
              global- nor the localsymtable is set, namely when the compiler
              didn't yet have the chance to process on of the units in the
              (implementation) uses clause simply due to the orders, so don't
              add anything of that unit yet (once routine bodies need to be
              specialized everything needed should be in place however). }
            if pu.u.in_interface then
              begin
                if Assigned(pu.u.localsymtable) then
                  SymTableStack.push(pu.u.localsymtable)
              end
            else
              InternalError(200705153)
          else
            SymTableStack.push(pu.u.GlobalSymTable);
          sym:=TSym(unitsyms.find(pu.u.ModuleName^));
          if Assigned(sym) and not Assigned(TUnitSym(sym).module) then
            TUnitSym(sym).module:=pu.u;
          pu:=TUsedUnit(pu.next);
        end;
      unitsyms.free;
      unitsyms := nil;
      if Assigned(hmodule.GlobalSymTable) then
        SymTableStack.push(hmodule.GlobalSymTable);
      SymTable:=genericdef.owner;
      { push the localsymtable if needed }
      if ((hmodule<>CurrentModule) or not CurrentModule.in_interface)
          and Assigned(hmodule.localsymtable) then
        SymTableStack.push(hmodule.localsymtable);
      { also push the symtables of all owning types }
      while Assigned(SymTable) and (SymTable.symtabletype in [objectsymtable,recordsymtable]) do
        begin
          SymTableStack.push(SymTable);
          if Assigned(SymTable.defowner) then
            SymTable:=SymTable.defowner.owner
          else
            SymTable:=nil;
        end;
    end;

    procedure specialization_done(var state: TSpecializationState);
    begin
      { Restore symtablestack }
      CurrentModule.extendeddefs.free;
      CurrentModule.extendeddefs:=state.oldextendeddefs;
      CurrentModule.genericdummysyms.free;
      CurrentModule.genericdummysyms:=state.oldgenericdummysyms;
      CurrentModule.specializestate:=state.oldspecializestate;
      optoken:=state.oldoptoken;
      SymTableStack.free;
      SymTableStack:=state.OldSymTableStack;
      { clear the state record to be on the safe side }
      fillchar(state, sizeof(state), 0);
    end;


{****************************************************************************
                      SPECIALIZATION BODY GENERATION
****************************************************************************}


    procedure process_procdef(def:TProcDef;hmodule:TModule);
      var
        oldcurrent_filepos : TFilePosInfo;
      begin
        if Assigned(def.genericdef) and
            (def.genericdef.typ=procdef) and
            Assigned(TProcDef(def.genericdef).generictokenbuf) then
          begin
            if not Assigned(TProcDef(def.genericdef).generictokenbuf) then
              InternalError(2015061902);
            oldcurrent_filepos:=CurrentFilePos;
            CurrentFilePos:=TProcDef(def.genericdef).fileinfo;
            { use the index the module got from the current compilation process }
            CurrentFilePos.moduleindex:=hmodule.ModuleID;
            CurrentTokenPos:=CurrentFilePos;
            CurrentScanner.startreplaytokens(TProcDef(def.genericdef).generictokenbuf,hmodule.ChangeEndian);
            read_proc_body(def);
            CurrentFilePos:=oldcurrent_filepos;
          end
        { synthetic routines will be implemented afterwards }
        else if def.synthetickind=tsk_none then
          MessagePos1(def.fileinfo,sym_e_forward_not_resolved,def.fullprocname(false));
      end;


    function process_abstractrecorddef(def:TAbstractRecordDef):boolean;
      var
        i  : LongInt;
        hp : TDef;
        hmodule : TModule;
      begin
        result:=true;
        hmodule:=nil;
        if Assigned(def.genericdef) then
          hmodule:=find_module_from_symtable(def.genericdef.owner)
        else if not (df_internal in def.defoptions) then
          InternalError(201202041);
        for i:=0 to def.SymTable.DefList.Count-1 do
          begin
            hp:=TDef(def.SymTable.DefList[i]);
            if hp.typ=procdef then
             begin
               { only generate the code if we need a body }
               if Assigned(TProcDef(hp).struct) and not TProcDef(hp).forwarddef then
                 continue;
               { and the body is available already (which is implicitly the
                 case if the generic routine is part of another unit) }
               if (
                    not Assigned(hmodule) or
                    (hmodule=CurrentModule) or
                    (hmodule.state=ms_compile)
                  ) and
                  { may not be assigned in case it's a synthetic procdef that
                    still needs to be generated }
                  (Assigned(TProcDef(hp).genericdef) and
                  TProcDef(TProcDef(hp).genericdef).forwarddef)
                  { when the implementation of the module was not yet parsed, it will not yet have a generictokenbuf }
                  or not Assigned(TProcDef(TProcDef(hp).genericdef).generictokenbuf) then

                 begin
                   result:=false;
                   continue;
                 end;
               process_procdef(TProcDef(hp),hmodule);
             end
           else
             if hp.typ in [objectdef,recorddef] then
               { generate code for subtypes as well }
               result:=process_abstractrecorddef(TAbstractRecordDef(hp)) and result;
         end;
      end;


    procedure generate_specialization_procs;
      var
        i : LongInt;
        list,
        readdlist : TFPObjectList;
        def : TStoredDef;
        state : TSpecializationState;
        hmodule : TModule;

      begin
        { first copy all entries and then work with that list to ensure that
          we don't get an infinite recursion }
        list:=TFPObjectList.create(false);
        readdlist:=TFPObjectList.create(false);

        list.Capacity:=CurrentModule.pendingspecializations.Count;
        for i:=0 to CurrentModule.pendingspecializations.Count-1 do
          list.add(CurrentModule.pendingspecializations.Items[i]);

        CurrentModule.pendingspecializations.clear;

        for i:=0 to list.count-1 do
          begin
            def:=TStoredDef(list[i]);
            if not TStoredDef(def).is_specialization then
              continue;
            case def.typ of
              procdef:
                begin
                  { the use of forwarddef should not backfire as the
                    specialization always belongs to the current module }
                  if not TProcDef(def).forwarddef then
                    continue;
                  if not Assigned(def.genericdef) then
                    InternalError(2015061903);
                  hmodule:=find_module_from_symtable(def.genericdef.owner);
                  if hmodule=nil then
                    InternalError(2015061904);
                  { we need to check for a forward declaration only if the
                    generic was declared in the same unit (otherwise there
                    should be one) }
                  if ((hmodule=CurrentModule) and TProcDef(def.genericdef).forwarddef)
                      or ((hmodule<>CurrentModule) and (hmodule.state<ms_compiling_waitfinish)) then
                    begin
                      readdlist.add(def);
                      continue;
                    end;

                  specialization_init(TStoredDef(def).genericdef,state);

                  process_procdef(TProcDef(def),hmodule);

                  specialization_done(state);
                end;
              recorddef,
              objectdef:
                begin
                  specialization_init(TStoredDef(def).genericdef,state);

                  if not process_abstractrecorddef(TAbstractRecordDef(def)) then
                    readdlist.add(def);

                  specialization_done(state);
                end;
              else
                ;
            end;
          end;

        { add those defs back to the pending list for which we don't yet have
          all method bodies }
        for i:=0 to readdlist.count-1 do
          CurrentModule.pendingspecializations.add(TStoredDef(readdlist[i]).typename,readdlist[i]);

        readdlist.free;
        readdlist := nil;
        list.free;
        list := nil;
      end;


    procedure generate_specializations_for_forwarddef(def:TDef);
      var
        list : TFPObjectList;
        idx,
        i : LongInt;
        context : TSpecializationContext;
      begin
        if not TStoredDef(def).is_generic then
          InternalError(2020070304);
        idx:=CurrentModule.forwardgenericdefs.findindexof(def.fulltypename);
        if idx<0 then
          exit;
        list:=TFPObjectList(CurrentModule.forwardgenericdefs.items[idx]);
        if not Assigned(list) then
          InternalError(2020070305);
        for i:=0 to list.count-1 do begin
          context:=TSpecializationContext(list[i]);
          generate_specialization_phase2(context,TStoredDef(def),false,'');
        end;
        CurrentModule.forwardgenericdefs.delete(idx);
      end;


    procedure maybe_add_pending_specialization(def:TDef;unnamed_syms: TFPList);
      var
        hmodule : TModule;
        st : TSymTable;
      begin
        if parse_generic then
          exit;
        { transfer ownership of any unnamed syms to be the specialization }
        if unnamed_syms<>nil then
          transfer_unnamed_symbols(TProcDef(def).parast,unnamed_syms);
        st:=def.owner;
        while st.symtabletype in [localsymtable] do
          st:=st.defowner.owner;
        hmodule:=find_module_from_symtable(st);
        if TStoredDef(def).is_specialization and (hmodule=CurrentModule) then
          CurrentModule.pendingspecializations.add(def.typename,def);
      end;


    function determine_generic_def(const name:TIDString):TStoredDef;
      var
        hashedid : THashedIDString;
        pd : TProcDef;
        sym : TSym;
      begin
        result:=nil;
        { check whether this is a declaration of a type inside a
          specialization }
        if Assigned(CurrentStructDef) and
            (df_specialization in CurrentStructDef.defoptions) then
          begin
            if not Assigned(CurrentStructDef.genericdef) or
                not (CurrentStructDef.genericdef.typ in [recorddef,objectdef]) then
              InternalError(2011052301);
            hashedid.id:=name;
            { we could be inside a method of the specialization
              instead of its declaration, so check that first (as
              local nested types aren't allowed we don't need to
              walk the symtablestack to find the localsymtable) }
            if SymTableStack.top.symtabletype=localsymtable then
              begin
                { we are in a method }
                if not Assigned(SymTableStack.top.defowner) or
                    (SymTableStack.top.defowner.typ<>procdef) then
                  InternalError(2011120701);
                pd:=TProcDef(SymTableStack.top.defowner);
                if not Assigned(pd.genericdef) or (pd.genericdef.typ<>procdef) then
                  InternalError(2011120702);
                sym:=TSym(TProcDef(pd.genericdef).localst.findwithhash(hashedid));
              end
            else
              sym:=nil;
            if not Assigned(sym) or not (sym.typ=typesym) then
              begin
                { now search in the declaration of the generic }
                sym:=TSym(TAbstractRecordDef(CurrentStructDef.genericdef).SymTable.findwithhash(hashedid));
                if not Assigned(sym) or not (sym.typ=typesym) then
                  InternalError(2011052302);
              end;
            { use the corresponding type in the generic's symtable as
              genericdef for the specialized type }
            result:=TStoredDef(TTypeSym(sym).typedef);
          end;
      end;


end.
