{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Parses variable declarations. Used for var statement and record
    definitions

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
unit pdecvar;

{$i fpcdefs.inc}

interface

    uses
      TPCompilerReal,
      CClasses,
      SymTable,SymSym,symdef,symtype;

    type
      TVarDecOption=(vd_record,vd_object,vd_threadvar,vd_class,vd_final,vd_canreorder,vd_check_generic);
      TVarDecOptions=set of TVarDecOption;

    function  read_property_dec(is_classproperty:boolean;astruct:TAbstractRecordDef):TPropertySym;

    procedure read_var_decls(options:TVarDecOptions;out had_generic:boolean);

    procedure read_record_fields(options:TVarDecOptions; reorderlist: TFPObjectList; variantdesc: PPVariantRecDesc;out had_generic:boolean; out attr_element_count : integer);

    procedure read_public_and_external(vs: TAbstractVarSym);

    procedure try_consume_sectiondirective(var asection: AnsiString);

    function check_allowed_for_var_or_const(def:TDef;allowdynarray:boolean):boolean;

implementation

    uses
       SysUtils,
       { common }
       CUtils,
       { global }
       GlobType,Globals,tokens,Verbose,ConstExp,
       Systems,
       { symtable }
       symconst,SymBase,defutil,defcmp,symutil,symcreat,
{$ifdef i386}
       symcpu,
{$endif i386}
       FModule,htypechk,procdefutil,
       { pass 1 }
       node,Pass_1,aasmbase,AAsmData,
       ncon,nset,ncnv,nld,nutils,
       { codegen }
       ngenutil,
       { parser }
       Scanner,
       pbase,pexpr,ptype,ptconst,pdecsub,pparautl;


    function read_property_dec(is_classproperty:boolean;astruct:TAbstractRecordDef):TPropertySym;

        { convert a node tree to symlist and return the last
          symbol }
        function parse_symlist(pl:TPropAccessList;out def:TDef):boolean;
          var
            idx : LongInt;
            sym : TSym;
            srsymtable : TSymTable;
            st  : TSymTable;
            p   : TNode;
          begin
            result:=true;
            def:=nil;
            if CurrentScanner.token=_ID then
             begin
               if Assigned(astruct) then
                 sym:=Search_Struct_Member(astruct,CurrentScanner.pattern)
               else
                 SearchSym(CurrentScanner.pattern,sym,srsymtable);
               if Assigned(sym) then
                begin
                  if Assigned(astruct) and
                     not Is_Visible_For_Object(sym,astruct) then
                    Message(parser_e_cant_access_private_member);
                  case sym.typ of
                    FieldVarSym :
                      begin
                        AddSymRef(sym);
                        pl.AddSym(sl_load,sym);
                        def:=TFieldVarSym(sym).vardef;
                      end;
                    ProcSym :
                      begin
                        AddSymRef(sym);
                        pl.AddSym(sl_call,sym);
                      end;
                    else
                      begin
                        Message1(parser_e_illegal_field_or_method,CurrentScanner.orgpattern);
                        def:=GenErrorDef;
                        result:=false;
                      end;
                  end;
                end
               else
                begin
                  Message1(parser_e_illegal_field_or_method,CurrentScanner.orgpattern);
                  def:=GenErrorDef;
                  result:=false;
                end;
               consume(_ID);
               repeat
                 case CurrentScanner.token of
                   _ID,
                   _SEMICOLON :
                     begin
                       break;
                     end;
                   _POINT :
                     begin
                       if not Is_Object(def) and not Is_Record(def) then
                         message(sym_e_type_must_be_rec_or_object);
                       consume(_POINT);
                       if Assigned(def) then
                        begin
                          st:=def.GetSymTable(gs_record);
                          if Assigned(st) then
                           begin
                             sym:=TSym(st.Find(CurrentScanner.pattern));
                             if not(Assigned(sym)) and Is_Object(def) then
                               sym:=Search_Struct_Member(TObjectDef(def),CurrentScanner.pattern);
                             if Assigned(sym) then
                              begin
                                pl.AddSym(sl_subscript,sym);
                                case sym.typ of
                                  FieldVarSym :
                                    def:=TFieldVarSym(sym).vardef;
                                  else
                                    begin
                                      Message1(sym_e_illegal_field,CurrentScanner.orgpattern);
                                      result:=false;
                                    end;
                                end;
                              end
                             else
                              begin
                                Message1(sym_e_illegal_field,CurrentScanner.orgpattern);
                                result:=false;
                              end;
                           end
                          else
                           begin
                             Message(parser_e_invalid_qualifier);
                             result:=false;
                           end;
                        end
                       else
                        begin
                          Message(parser_e_invalid_qualifier);
                          result:=false;
                        end;
                       consume(_ID);
                     end;
                   _LECKKLAMMER :
                     begin
                       consume(_LECKKLAMMER);
                       repeat
                         if Assigned(def) and (def.typ=arraydef) then
                          begin
                            idx:=0;
                            p:=comp_expr([ef_accept_equal]);
                            if (not CodeGenError) then
                             begin
                               if (p.nodetype=ordconstn) then
                                 begin
                                   { type/range checking }
                                   InsertTypeConv(p,TArrayDef(def).RangeDef);
                                   if (TOrdConstNode(p).Value<int64(low(LongInt))) or
                                      (TOrdConstNode(p).Value>int64(high(LongInt))) then
                                     message(parser_e_array_range_out_of_bounds)
                                   else
                                     idx:=TOrdConstNode(p).Value.svalue
                                 end
                               else
                                Message(type_e_ordinal_expr_expected)
                             end;
                            pl.AddConst(sl_vec,idx,p.resultdef);
                            p.free;
                            p := nil;
                            def:=TArrayDef(def).ElementDef;
                          end
                         else
                          begin
                            Message(parser_e_invalid_qualifier);
                            result:=false;
                          end;
                       until not try_to_consume(_COMMA);
                       consume(_RECKKLAMMER);
                     end;
                   else
                     begin
                       Message(parser_e_ill_property_access_sym);
                       result:=false;
                       break;
                     end;
                 end;
               until false;
             end
            else
             begin
               Message(parser_e_ill_property_access_sym);
               result:=false;
             end;
          end;

          function has_implicit_default(p : TPropertySym) : boolean;

          begin
             has_implicit_default:=
               (Is_String(p.PropDef) or
               Is_Real(p.PropDef) or
               Is_Pointer(p.PropDef));
          end;

          function allow_default_property(p : TPropertySym) : boolean;

          begin
             allow_default_property:=
               (Is_Ordinal(p.PropDef) or
{$ifndef cpu64bitaddr}
               Is_64BitInt(p.PropDef) or
{$endif cpu64bitaddr}
               Is_Class(p.PropDef) or
               Is_Single(p.PropDef) or
               (p.PropDef.typ in [classrefdef,pointerdef]) or
                 Is_SmallSet(p.PropDef)
               ) and not
               (
                (p.PropDef.typ=arraydef) and
                (ppo_indexed in p.PropOptions)
               ) and not
               (ppo_hasparameters in p.PropOptions);
          end;

          procedure create_accessor_procsym(p: TPropertySym; pd: TProcDef; const prefix: string;
              accesstype: TPropAccessListTypes);
            var
              sym: TProcSym;
            begin
              if not Assigned(astruct) then
                handle_calling_convention(pd,hcc_default_actions_intf)
              else
                handle_calling_convention(pd,hcc_default_actions_intf_struct);
              sym:=CProcSym.Create(prefix+lower(p.realname));
              SymTableStack.top.InsertSym(sym);
              pd.ProcSym:=sym;
              include(pd.ProcOptions,po_dispid);
              include(pd.ProcOptions,po_global);
              pd.visibility:=vis_private;
              proc_add_definition(pd);
              p.PropAccessList[accesstype].AddSym(sl_call,sym);
              p.PropAccessList[accesstype].procdef:=pd;
            end;

          procedure parse_dispinterface(p : TPropertySym; readpd,writepd: TProcDef;
              var ParaNr: word);
            var
              hasread, haswrite: boolean;
              pt: TNode;
              hdispid: LongInt;
              hparavs: TParaVarSym;
            begin
              p.PropAccessList[palt_read].clear;
              p.PropAccessList[palt_write].clear;

              hasread:=true;
              haswrite:=true;
              hdispid:=0;

              if try_to_consume(_READONLY) then
                haswrite:=false
              else if try_to_consume(_WRITEONLY) then
                hasread:=false;

              if try_to_consume(_DISPID) then
                begin
                  pt:=comp_expr([ef_accept_equal]);
                  if Is_ConstIntNode(pt) then
                    if (TOrdConstNode(pt).Value<int64(low(LongInt))) or (TOrdConstNode(pt).Value>int64(high(LongInt))) then
                      message3(type_e_range_check_error_bounds,ToStr(TOrdConstNode(pt).Value),ToStr(low(LongInt)),ToStr(high(LongInt)))
                    else
                      hdispid:=TOrdConstNode(pt).Value.svalue
                  else
                    Message(parser_e_dispid_must_be_ord_const);
                  pt.free;
                  pt := nil;
                end
              else
                hdispid:=TObjectDef(astruct).Get_Next_DispID;

              { COM property is simply a pair of methods, tagged with 'propertyget'
                and 'propertyset' flags (or a single method if access is restricted).
                Creating these implicit accessor methods also allows the rest of compiler
                to handle dispinterface properties the same way as regular ones. }
              if hasread then
                begin
                  readpd.ReturnDef:=p.PropDef;
                  readpd.DispID:=hdispid;
                  readpd.ProcTypeOption:=potype_propgetter;
                  create_accessor_procsym(p,readpd,'get$',palt_read);
                end;
              if haswrite then
                begin
                  { add an extra parameter, a placeholder of the value to set }
                  inc(ParaNr);
                  hparavs:=CParaVarSym.Create('$value',10*ParaNr,vs_value,p.PropDef,[]);
                  writepd.ParaST.InsertSym(hparavs);

                  writepd.ProcTypeOption:=potype_propsetter;
                  writepd.DispID:=hdispid;
                  create_accessor_procsym(p,writepd,'put$',palt_write);
                end;
            end;

      var
         sym : TSym;
         srsymtable: TSymTable;
         p : TPropertySym;
         overridden : TSym;
         VarSpez : TVarSpez;
         hdef : TDef;
         arraytype : TDef;
         def : TDef;
         pt : TNode;
         sc : TFPObjectList;
         ParaNr : word;
         i      : LongInt;
	 s : single;
         ImplIntf     : TImplementedInterface;
         found,
         gotreadorwrite: boolean;
         hreadparavs,
         hparavs      : TParaVarSym;
         storedprocdef: TProcVarDef;
         ReadProcDef,
         WriteProcDef : TProcDef;
      begin
         result:=nil;
         { Generate temp procdefs to search for matching read/write
           procedures. the readprocdef will store all definitions }
         ParaNr:=0;
         ReadProcDef:=CProcDef.Create(NormalFunctionLevel,false);
         WriteProcDef:=CProcDef.Create(NormalFunctionLevel,false);

         ReadProcDef.struct:=astruct;
         WriteProcDef.struct:=astruct;

         if Assigned(astruct) and is_classproperty then
           begin
             ReadProcDef.ProcOptions:=[po_staticmethod,po_classmethod];
             WriteProcDef.ProcOptions:=[po_staticmethod,po_classmethod];
           end;

         if CurrentScanner.token<>_ID then
           begin
              consume(_ID);
              consume(_SEMICOLON);
              exit;
           end;
         { Generate propertysym and insert in symtablestack }
         p:=CPropertySym.Create(CurrentScanner.orgpattern);
         p.visibility:=SymTableStack.top.CurrentVisibility;
         p.default:=LongInt($80000000);
         if is_classproperty then
           include(p.SymOptions, sp_static);
         SymTableStack.top.InsertSym(p);
         consume(_ID);
         { property parameters ? }
         if try_to_consume(_LECKKLAMMER) then
           begin
              { Published indexed properties are allowed in Delphi in interfaces compiled with $M+. }
              if (p.visibility=vis_published) and
                not((m_delphi in CurrentSettings.ModeSwitches) and Is_InterfaceCOM_Or_DispInterface(astruct)) then
                Message(parser_e_cant_publish_that_property);
              { create a list of the parameters }
              p.ParaST:=TParaSymTable.Create(nil,0);
              SymTableStack.push(p.ParaST);
              sc:=TFPObjectList.Create(false);
              repeat
                if try_to_consume(_VAR) then
                  VarSpez:=vs_var
                else if try_to_consume(_CONST) then
                  VarSpez:=vs_const
                else if try_to_consume(_CONSTREF) then
                  VarSpez:=vs_constref
                else if (m_out in CurrentSettings.ModeSwitches) and try_to_consume(_OUT) then
                  VarSpez:=vs_out
                else
                  VarSpez:=vs_value;
                sc.clear;
                repeat
                  inc(ParaNr);
                  hreadparavs:=CParaVarSym.Create(CurrentScanner.orgpattern,10*ParaNr,VarSpez,GenErrorDef,[]);
                  p.ParaST.InsertSym(hreadparavs);
                  sc.add(hreadparavs);
                  consume(_ID);
                until not try_to_consume(_COMMA);
                if try_to_consume(_COLON) then
                  begin
                    if try_to_consume(_ARRAY) then
                      begin
                        consume(_OF);
                        { define range and type of range }
                        hdef:=CArrayDef.Create_OpenArray;
                        hdef.owner:=astruct.SymTable;
                        { define field type }
                        single_type(arraytype,[]);
                        TArrayDef(hdef).ElementDef:=arraytype;
                      end
                    else
                      single_type(hdef,[]);
                  end
                else
                  hdef:=CFormalType;
                for i:=0 to sc.count-1 do
                  TParaVarSym(sc[i]).vardef:=hdef;
              until not try_to_consume(_SEMICOLON);
              sc.free;
              sc := nil;
              SymTableStack.pop(p.ParaST);
              consume(_RECKKLAMMER);

              { the parser need to know if a property has parameters, the
                index parameter doesn't count (PFV) }
              if ParaNr>0 then
                begin
                  p.Add_Accessor_Parameters(ReadProcDef,WriteProcDef);
                  include(p.PropOptions,ppo_hasparameters);
                end;
           end;
         { overridden property ?                                 }
         { force property interface
             there is a property parameter
             a global property }
         if (CurrentScanner.token=_COLON) or (ParaNr>0) or (astruct=nil) then
           begin
              consume(_COLON);
              single_type(p.PropDef,[stoAllowSpecialization]);

              if Is_DispInterface(astruct) and not Is_Automatable(p.PropDef) then
                Message1(type_e_not_automatable,p.PropDef.TypeName);

              if (CurrentScanner.idtoken=_INDEX) then
                begin
                   consume(_INDEX);
                   pt:=comp_expr([ef_accept_equal]);
                   { Only allow enum and integer indexes. Convert all integer
                     values to objpas.integer (s32int on 32- and 64-bit targets,
                     s16int on 16- and 8-bit) to be compatible with delphi,
                     because the procedure matching requires equal parameters }
                   if Is_ConstNode(pt) and
                      Is_Ordinal(pt.resultdef)
                      and (not Is_64BitInt(pt.resultdef))

                      then
                     begin
                       if Is_Integer(pt.resultdef) then

                         InsertTypeConv_Internal(pt,S32IntType);

                       p.Index:=TOrdConstNode(pt).Value.svalue;
                     end
                   else
                     begin
                       Message(parser_e_invalid_property_index_value);
                       p.Index:=0;
                     end;
                   p.IndexDef:=pt.resultdef;
                   include(p.PropOptions,ppo_indexed);
                   { concat a longint to the para templates }
                   p.Add_Index_Parameter(ParaNr,ReadProcDef,WriteProcDef);
                   pt.free;
                   pt := nil;
                end;
           end
         else
           begin
              { do an property override }
              if (astruct.typ=objectdef) and Assigned(TObjectDef(astruct).ChildOf) then
                overridden:=Search_Struct_Member(TObjectDef(astruct).ChildOf,p.name)
              else
                overridden:=nil;
              if Assigned(overridden) and
                 (overridden.typ=propertysym) and
                 not(Is_DispInterface(astruct)) then
                begin
                  TPropertySym(overridden).MakeDuplicate(p,ReadProcDef,WriteProcDef,ParaNr);
                  p.Register_Override(TPropertySym(overridden));
                end
              else
                begin
                  p.PropDef:=GenErrorDef;
                  message(parser_e_no_property_found_to_override);
                end;
           end;
         if ((p.visibility=vis_published) or Is_DispInterface(astruct))
             and not (astruct.Is_Generic and (p.PropDef.typ=undefineddef)) then
           begin
             { ignore is_publishable for interfaces (related to $M+ directive).
               $M has effect on visibility of default section for classes.
               Interface has always only public section (fix for problem in tb0631.pas) }
             if (sp_static in p.SymOptions) or ((p.PropDef.IsPublishable=pp_error) and not Is_Interface(astruct)) then
               begin
                 Message(parser_e_cant_publish_that_property);
                 p.visibility:=vis_public;
               end
             else
             if (p.PropDef.IsPublishable=pp_ignore) and not Is_Interface(astruct) then
               begin
                 Message(parser_w_ignoring_published_property);
                 p.visibility:=vis_public;
               end;
           end;

         if not(Is_DispInterface(astruct)) then
           begin
             gotreadorwrite:=false;
             { parse accessors }
             if try_to_consume(_READ) then
               begin
                 gotreadorwrite:=true;
                 p.PropAccessList[palt_read].clear;
                 if parse_symlist(p.PropAccessList[palt_read],def) then
                  begin
                    sym:=p.PropAccessList[palt_read].FirstSym^.sym;
                    { getter is a function returning the type of the property }
                    if sym.typ=ProcSym then
                      begin
                        ReadProcDef.ReturnDef:=p.PropDef;
                        { Insert hidden parameters }
                        if Assigned(astruct) then
                          handle_calling_convention(ReadProcDef,hcc_default_actions_intf_struct)
                        else
                          handle_calling_convention(ReadProcDef,hcc_default_actions_intf);
                      end;
                    p.Add_Getter_Or_Setter_For_Sym(palt_read,sym,def,ReadProcDef);
                  end;
               end
             else
               p.Inherit_Accessor(palt_read);
             if try_to_consume(_WRITE) then
               begin
                 gotreadorwrite:=true;
                 p.PropAccessList[palt_write].clear;
                 if parse_symlist(p.PropAccessList[palt_write],def) then
                  begin
                    sym:=p.PropAccessList[palt_write].FirstSym^.sym;
                    if sym.typ=ProcSym then
                      begin
                        { setter is a procedure with an extra value parameter
                          of the of the property }
                        WriteProcDef.ReturnDef:=VoidType;
                        inc(ParaNr);
                        hparavs:=CParaVarSym.Create('$value',10*ParaNr,vs_value,p.PropDef,[]);
                        WriteProcDef.ParaST.InsertSym(hparavs);
                        { Insert hidden parameters }
                        if not Assigned(astruct) then
                          handle_calling_convention(WriteProcDef,hcc_default_actions_intf)
                        else
                          handle_calling_convention(WriteProcDef,hcc_default_actions_intf_struct);
                      end;
                    p.Add_Getter_Or_Setter_For_Sym(palt_write,sym,def,WriteProcDef);
                  end;
               end
             else
               p.Inherit_Accessor(palt_write);
             { a new property (needs to declare a getter or setter, except in
               an interface }
             if not(ppo_overrides in p.PropOptions) and
                not Is_Interface(astruct) and
                not gotreadorwrite then
               Consume(_READ);
           end
         else
           parse_dispinterface(p,ReadProcDef,WriteProcDef,ParaNr);

         { stored is not allowed for dispinterfaces, records or class properties }
         if Assigned(astruct) and not(Is_DispInterface(astruct) or Is_Record(astruct)) and not is_classproperty then
           begin
             { ppo_stored is default on for not overridden properties }
             if not Assigned(p.OverriddenPropSym) then
               include(p.PropOptions,ppo_stored);
             if try_to_consume(_STORED) then
              begin
                include(p.PropOptions,ppo_stored);
                p.PropAccessList[palt_stored].clear;
                if CurrentScanner.token=_ID then
                  begin
                    { in the case that idtoken=_DEFAULT }
                    { we have to do nothing except      }
                    { setting ppo_stored, it's the same }
                    { as stored true                    }
                    if CurrentScanner.idtoken<>_DEFAULT then
                     begin
                       { parse_symlist cannot deal with constsyms, and
                         we also don't want to put constsyms in symlists
                         since they have to be evaluated immediately rather
                         than each time the property is accessed

                         The proper fix would be to always create a parse tree
                         and then convert that one, if appropriate, to a symlist.
                         Currently, we e.g. don't support any constant expressions
                         yet either here, while Delphi does.

                       }
                       { make sure we don't let constants mask class fields/
                         methods
                       }
                       sym:=nil;
                       if (not Assigned(astruct) or
                           (Search_Struct_Member(astruct,CurrentScanner.pattern)=nil)) and
                          SearchSym(CurrentScanner.pattern,sym,srsymtable) and
                          (sym.typ = constsym) then
                         begin
                            AddSymRef(sym);
                            if not Is_Boolean(TConstSym(sym).ConstDef) then
                              Message(parser_e_stored_property_must_be_boolean)
                            else if (TConstSym(sym).Value.ValueOrd=0) then
                              { same as for _FALSE }
                              exclude(p.PropOptions,ppo_stored)
                            else
                              begin
                                { same as for _TRUE }
                                { do nothing - ppo_stored is already set to p.propoptions in "include(p.propoptions,ppo_stored);" above }
                                { especially do not reset the default value - the stored specifier is independent on the default value! }
                              end;
                            consume(_ID);
                          end
                       else if parse_symlist(p.PropAccessList[palt_stored],def) then
                        begin
                          sym:=p.PropAccessList[palt_stored].FirstSym^.sym;
                          case sym.typ of
                            ProcSym :
                              begin
                                 { Create a temporary procvardef to handle parameters }
                                 storedprocdef:=CProcVarDef.Create(NormalFunctionLevel,true);
                                 include(storedprocdef.ProcOptions,po_methodpointer);
                                 { Return type must be boolean }
                                 storedprocdef.ReturnDef:=PasBool1Type;
                                 { Add index parameter if needed }
                                 if ppo_indexed in p.PropOptions then
                                   begin
                                     hparavs:=CParaVarSym.Create('$index',10,vs_value,p.IndexDef,[]);
                                     storedprocdef.ParaST.InsertSym(hparavs);
                                   end;

                                 { Insert hidden parameters }
                                 if not Assigned(astruct) then
                                   handle_calling_convention(storedprocdef,hcc_default_actions_intf)
                                 else
                                   handle_calling_convention(storedprocdef,hcc_default_actions_intf_struct);
                                 p.PropAccessList[palt_stored].procdef:=TProcSym(sym).Find_ProcDef_ByPara(storedprocdef.paras,storedprocdef.ReturnDef,[cpo_allowdefaults,cpo_ignorehidden]);
                                 if not Assigned(p.PropAccessList[palt_stored].procdef) then
                                   message(parser_e_ill_property_storage_sym);
                                 { Not needed anymore }
                                 storedprocdef.owner.DeleteDef(storedprocdef);
                              end;
                            FieldVarSym :
                              begin
                                if not Assigned(def) then
                                  InternalError(200310073);
                                if (ppo_hasparameters in p.PropOptions) or
                                   not(Is_Boolean(def)) then
                                 Message(parser_e_stored_property_must_be_boolean);
                              end;
                            else
                              Message(parser_e_ill_property_access_sym);
                          end;
                        end;
                     end;
                  end;
              end;
           end;
         if has_implicit_default(p) and not Assigned(p.OverriddenPropSym) then
           begin
              p.default:=0;
           end;
         if not Is_Record(astruct) and try_to_consume(_DEFAULT) then
           begin
              if not allow_default_property(p) then
                begin
                  Message(parser_e_property_cant_have_a_default_value);
                  { Error recovery }
                  pt:=comp_expr([ef_accept_equal]);
                  pt.free;
                  pt := nil;
                end
              else
                begin
                  { Get the result of the default, the firstpass is
                    needed to support values like -1 }
                  pt:=comp_expr([ef_accept_equal]);
                  if (p.PropDef.typ=setdef) and
                     (pt.nodetype=arrayconstructorn) then
                    begin
                      ArrayConstructor_To_Set(pt);
                      DoTypeCheckPass(pt);
                    end;
                  InsertTypeConv(pt,p.PropDef);
                  if not(Is_ConstNode(pt)) then
                    Message(parser_e_property_default_value_must_const);
                  { Set default value }
                  case pt.nodetype of
                    setconstn :
                      begin
                        if (SourceInfo.endian=TargetInfo.endian) then
                          p.default:=PLongInt(TSetConstNode(pt).ValueSet)^
                        else
                          p.default:=LongInt(Reverse_LongWord(plongword(TSetConstNode(pt).ValueSet)^));
                        include(p.PropOptions,ppo_default_is_set);
                      end;
                    ordconstn :
                      if Is_Real(p.PropDef) then
                        begin
                          if TOrdConstNode(pt).Value.Is_Negative then
                            s:=TOrdConstNode(pt).Value.svalue
                          else
                            s:=TOrdConstNode(pt).Value.uvalue;
                          p.default:=PLongInt(@s)^;
                          include(p.PropOptions,ppo_default_is_single);
                        end
                      else if (TOrdConstNode(pt).Value<int64(low(LongInt))) or
                         (TOrdConstNode(pt).Value>int64(high(cardinal))) then
                        message3(type_e_range_check_error_bounds,ToStr(TOrdConstNode(pt).Value),ToStr(low(LongInt)),ToStr(high(cardinal)))
                      else
                        p.default:=LongInt(TOrdConstNode(pt).Value.svalue);
                    niln :
                      p.default:=0;
                    realconstn:
                      begin
                        s:=Single(TRealConstNode(pt).ValueReal);
                        p.default:=PLongInt(@s)^;
                        include(p.PropOptions,ppo_default_is_single);
                      end;
                    else if not CodeGenError then
                      InternalError(2019050525);
                  end;
                  pt.free;
                  pt := nil;
                end;
           end
         else if not Is_Record(astruct) and try_to_consume(_NODEFAULT) then
           begin
              p.default:=LongInt($80000000);
           end;
(*
         else {if allow_default_property(p) then
           begin
              p.default:=longint($80000000);
           end;
*)
         { Parse possible "implements" keyword }
         if not Is_Record(astruct) and try_to_consume(_IMPLEMENTS) then
           repeat
             single_type(def,[]);

             if not(Is_Interface(def)) then
               message(parser_e_class_implements_must_be_interface);

             if Is_Interface(p.PropDef) then
               begin
                 { an interface type may delegate itself or one of its ancestors }
                 if not Def_Is_Related(p.PropDef,def) then
                   begin
                     message2(parser_e_implements_must_have_correct_type,def.TypeName,p.PropDef.TypeName);
                     exit;
                   end;
               end
             else if Is_Class(p.PropDef) then
               begin
                 ImplIntf:=Find_Implemented_Interface(TObjectDef(p.PropDef),TObjectDef(def));
                 if Assigned(ImplIntf) then
                   begin
                     if Compare_Defs(ImplIntf.IntfDef,def,nothingn)<te_equal then
                       begin
                         message2(parser_e_implements_must_have_correct_type,ImplIntf.IntfDef.TypeName,def.TypeName);
                         exit;
                       end;
                   end
                 else
                   begin
                     message2(parser_e_class_doesnt_implement_interface,p.PropDef.TypeName,def.TypeName);
                     exit;
                   end;
               end
             else
               begin
                 message(parser_e_implements_must_be_class_or_interface);
                 exit;
               end;


             if not Assigned(p.PropAccessList[palt_read].FirstSym) then
               begin
                 message(parser_e_implements_must_read_specifier);
                 exit;
               end;
             if Assigned(p.PropAccessList[palt_read].procdef) and
                (TProcDef(p.PropAccessList[palt_read].procdef).ProcCallOption<>pocall_default) then
               message(parser_e_implements_getter_not_default_cc);
             if Assigned(p.PropAccessList[palt_write].FirstSym) then
               begin
                 message(parser_e_implements_must_not_have_write_specifier);
                 exit;
               end;
             if Assigned(p.PropAccessList[palt_stored].FirstSym) then
               begin
                 message(parser_e_implements_must_not_have_stored_specifier);
                 exit;
               end;
             found:=false;
             ImplIntf:=nil;
             for i:=0 to TObjectDef(astruct).ImplementedInterfaces.Count-1 do
               begin
                 ImplIntf:=TImplementedInterface(TObjectDef(astruct).ImplementedInterfaces[i]);

                 if Compare_Defs(def,ImplIntf.IntfDef,nothingn)>=te_equal then
                   begin
                     found:=true;
                     break;
                   end;
               end;
             if found then
               begin
                 { An interface may not be delegated by more than one property,
                   it also may not have method mappings. }
                 if Assigned(ImplIntf.ImplementsGetter) then
                   message1(parser_e_duplicate_implements_clause,ImplIntf.IntfDef.TypeName);
                 if Assigned(ImplIntf.NameMappings) then
                   message2(parser_e_mapping_no_implements,ImplIntf.IntfDef.TypeName,astruct.ObjRealName^);

                 ImplIntf.ImplementsGetter:=p;
                 ImplIntf.VtblImplIntf:=ImplIntf;
                 case p.PropAccessList[palt_read].FirstSym^.sym.typ of
                   ProcSym :
                     begin
                       if (po_virtualmethod in TProcDef(p.PropAccessList[palt_read].procdef).ProcOptions) and
                           not Is_ObjectPascal_Helper(TProcDef(p.PropAccessList[palt_read].procdef).struct) then
                         ImplIntf.IType:=etVirtualMethodResult
                       else
                         ImplIntf.IType:=etStaticMethodResult;
                     end;
                   FieldVarSym :
                     begin
                       ImplIntf.IType:=etFieldValue;
                       { this must be done in a more robust way. Can't read the
                         fieldvarsym's fieldoffset yet, because it may not yet
                         be set }
                       ImplIntf.ImplementsField:=p.PropAccessList[palt_read].FirstSym^.sym;
                     end
                   else
                     InternalError(200802161);
                 end;
                 if not Is_Interface(p.PropDef) then
                   case ImplIntf.IType of
                     etVirtualMethodResult: ImplIntf.IType := etVirtualMethodClass;
                     etStaticMethodResult:  ImplIntf.IType := etStaticMethodClass;
                     etFieldValue:          ImplIntf.IType := etFieldValueClass;
                   else
                     InternalError(200912101);
                   end;
               end
             else
               message1(parser_e_implements_uses_non_implemented_interface,def.TypeName);
           until not try_to_consume(_COMMA);

         { register propgetter and propsetter procdefs }
         if Assigned(CurrentModule) and CurrentModule.InInterface then
           begin
             if ReadProcDef.ProcTypeOption=potype_propgetter then
               ReadProcDef.RegisterDef
             else
               ReadProcDef.free; // no nil needed
             if WriteProcDef.ProcTypeOption=potype_propsetter then
               WriteProcDef.RegisterDef
             else
               WriteProcDef.free; // no nil needed
           end
         else
           begin
             if ReadProcDef.ProcTypeOption=potype_propgetter then
               ReadProcDef.Maybe_Put_In_SymTable_Stack
             else
               ReadProcDef.free; // no nil needed
             if WriteProcDef.ProcTypeOption=potype_propsetter then
               WriteProcDef.Maybe_Put_In_SymTable_Stack
             else
               WriteProcDef.free; // no nil needed
           end;

         result:=p;
      end;


     function maybe_parse_proc_directives(def:TDef):boolean;
       begin
         result:=false;
         { Process procvar directives before = and ; }
         if (
              (def.typ=procvardef) or
              Is_FuncRef(def)
            ) and
            (def.TypeSym=nil) and
            check_proc_directive(true) then
           begin
              parse_proctype_directives(def);
              result:=true;
           end;
       end;


    var
       variantrecordlevel : LongInt = 0;


    procedure read_public_and_external_sc(sc:TFPObjectList);
    var
      vs: TAbstractVarSym;
    begin
      { only allowed for one var }
      vs:=TAbstractVarSym(sc[0]);
      if sc.count>1 then
        Message1(parser_e_directive_only_one_var,arraytokeninfo[CurrentScanner.idtoken].str);
      read_public_and_external(vs);
    end;


    procedure read_public_and_external(vs: TAbstractVarSym);
    var
      is_dll,
      is_cdecl,
      is_external_var,
      is_weak_external,
      is_public_var  : boolean;
      dll_name,section_name,
      C_name,MangledName      : string;
    begin
      { only allowed for one var }
      { only allow external and public on global symbols }
      if vs.typ<>staticvarsym then
        begin
          Message(parser_e_no_local_var_external);
          exit;
        end;
      { defaults }
      is_dll:=false;
      is_cdecl:=false;
      is_external_var:=false;
      is_public_var:=false;
      section_name := '';
      dll_name := '';
      C_name:=vs.realname;

      { macpas specific handling due to some switches}
      if (m_mac in CurrentSettings.ModeSwitches) then
        begin
          if (cs_external_var in CurrentSettings.LocalSwitches) then
            begin {The effect of this is the same as if cvar; external; has been given as directives.}
              is_cdecl:=true;
              is_external_var:=true;
            end
          else if (cs_externally_visible in CurrentSettings.LocalSwitches) then
            begin {The effect of this is the same as if cvar has been given as directives and it's made public.}
              is_cdecl:=true;
              is_public_var:=true;
            end;
        end;

      { cdecl }
      if try_to_consume(_CVAR) then
        begin
          consume(_SEMICOLON);
          is_cdecl:=true;
        end;

      { external }
      is_weak_external:=try_to_consume(_WEAKEXTERNAL);
      if is_weak_external or
         try_to_consume(_EXTERNAL) then
        begin
          is_external_var:=true;
          if (CurrentScanner.idtoken<>_NAME) and (CurrentScanner.token<>_SEMICOLON) then
            begin
              is_dll:=true;
              dll_name:=get_stringconst;
              if ExtractFileExt(dll_name)='' then
                dll_name:=ChangeFileExt(dll_name,TargetInfo.sharedlibext);
            end;
          if not(is_cdecl) and try_to_consume(_NAME) then
            C_name:=get_stringconst;
          consume(_SEMICOLON);
        end;

      { export or public }
      if CurrentScanner.idtoken in [_EXPORT,_PUBLIC] then
        begin
          consume(_ID);
          if is_external_var then
            Message(parser_e_not_external_and_export)
          else
            is_public_var:=true;
          if try_to_consume(_NAME) then
            C_name:=get_stringconst;
{$ifndef DISABLE_TLS_DIRECTORY}
          if (TargetInfo.system in systems_windows) and
             (vs.typ=staticvarsym) and
             try_to_consume (_SECTION) then
            section_name:=get_stringconst;
{$endif not DISABLE_TLS_DIRECTORY}
          consume(_SEMICOLON);
        end;

      { Windows uses an indirect reference using import tables }
      if is_dll and
         (TargetInfo.system in systems_all_windows) then
        include(vs.VarOptions,vo_is_dll_var);

      { This can only happen if vs.typ=staticvarsym }
      if section_name<>'' then
        begin
          TStaticVarSym(vs).section:=section_name;
          include(vs.VarOptions,vo_has_section);
        end;


      { Add C _ prefix }
      if is_cdecl or
         (
          is_dll and
          (TargetInfo.system in systems_darwin)
         ) then
        C_Name := TargetInfo.Cprefix+C_Name;

      if is_public_var then
        begin
          include(vs.VarOptions,vo_is_public);
          vs.VarRegable := vr_none;
          { mark as referenced }
          inc(vs.refs);
        end;

      MangledName:=C_name;
      { now we can insert it in the import lib if its a dll, or
        add it to the externals }
      if is_external_var then
        begin
          if vo_is_typed_const in vs.VarOptions then
            Message(parser_e_initialized_not_for_external);
          include(vs.VarOptions,vo_is_external);
          if (is_weak_external) then
            begin
              if not(TargetInfo.system in systems_weak_linking) then
                message(parser_e_weak_external_not_supported);
              include(vs.VarOptions,vo_is_weak_external);
            end;
          vs.VarRegable := vr_none;
          if is_dll then
            begin
              if TargetInfo.system in systems_all_windows then
                MangledName:=Make_DLLMangledName(dll_name,C_name,0,pocall_none);

              CurrentModule.AddExternalImport(dll_name,C_Name,MangledName,0,true,false);
            end
          else
            if tf_has_dllscanner in TargetInfo.flags then
              CurrentModule.DLLScannerInputList.Add(vs.MangledName,vs);
        end;

      { Set the assembler name }
      TStaticVarSym(vs).Set_MangledBaseName(MangledName);
      TStaticVarSym(vs).Set_MangledName(MangledName);
    end;


    procedure try_consume_sectiondirective(var asection: AnsiString);
      begin
        if CurrentScanner.idtoken=_SECTION then
          begin
            consume(_ID);
            asection:=get_stringconst;
            consume(_SEMICOLON);
          end;
      end;


    procedure read_var_decls(options:TVarDecOptions;out had_generic:boolean);

        procedure read_default_value(sc : TFPObjectList);
        var
          vs : TAbstractNormalVarSym;
          tcsym : TStaticVarSym;
          TempList : TAsmList;
        begin
          vs:=TAbstractNormalVarSym(sc[0]);
          if sc.count>1 then
            Message(parser_e_initialized_only_one_var);
          if vo_is_thread_var in vs.VarOptions then
            Message(parser_e_initialized_not_for_threadvar);
          consume(_EQ);
          case vs.typ of
            localvarsym :
              begin
                tcsym:=CStaticVarSym.Create('$default'+vs.realname,vs_const,vs.vardef,[]);
                include(tcsym.SymOptions,sp_internal);
                SymTableStack.top.InsertSym(tcsym);
                TempList:=TAsmList.Create;
                read_typed_const(TempList,tcsym,false);
                { in case of a generic routine, this initialisation value is not
                  used, and will be re-parsed during specialisations (and the
                  current version is not type-correct and hence breaks code
                  generation for LLVM) }
                if not parse_generic then
                  begin
                    vs.DefaultConstSym:=tcsym;
                    CurrentAsmData.asmlists[al_typedconsts].ConcatList(TempList);
                  end;
                TempList.free;
                TempList := nil;
              end;
            staticvarsym :
              begin
                read_typed_const(CurrentAsmData.asmlists[al_typedconsts],TStaticVarSym(vs),false);
              end;
            else
              InternalError(200611051);
          end;
          vs.VarState:=vs_initialised;
        end;

        procedure read_absolute(sc : TFPObjectList);
        var
          vs     : TAbstractVarSym;
          abssym : TAbsoluteVarSym;
          pt,hp  : TNode;
          st     : TSymTable;
        begin
          abssym:=nil;
          { only allowed for one var }
          vs:=TAbstractVarSym(sc[0]);
          if sc.count>1 then
            Message1(parser_e_directive_only_one_var,'ABSOLUTE');
          if vo_is_typed_const in vs.VarOptions then
            Message(parser_e_initialized_not_for_external);
          { parse the rest }
          pt:=expr(true);
          { check allowed absolute types }
          if (pt.nodetype=stringconstn) or
            (Is_ConstCharNode(pt)) then
            begin
              abssym:=CAbsoluteVarSym.Create(vs.realname,vs.vardef);
              abssym.fileinfo:=vs.fileinfo;
              if pt.nodetype=stringconstn then
                abssym.AsmName:=StringDup(TStringConstNode(pt).AsRawByteString)
              else
                abssym.AsmName:=StringDup(chr(TOrdConstNode(pt).Value.svalue));
              abssym.AbsTyp:=toasm;
            end
          { address }
          else if Is_ConstIntNode(pt) then
            begin
              abssym:=CAbsoluteVarSym.Create(vs.realname,vs.vardef);
              abssym.fileinfo:=vs.fileinfo;
              abssym.AbsTyp:=toaddr;
{$ifndef cpu64bitaddr}
              { on 64 bit systems, abssym.addroffset is a qword and hence this
                test is useless (value is a 64 bit entity) and will always fail
                for positive values (since int64(high(abssym.addroffset))=-1
              }
              if (TOrdConstNode(pt).Value<int64(low(abssym.AddrOffset))) or
                 (TOrdConstNode(pt).Value>int64(high(abssym.AddrOffset))) then
                message3(type_e_range_check_error_bounds,ToStr(TOrdConstNode(pt).Value),ToStr(low(abssym.AddrOffset)),ToStr(high(abssym.AddrOffset)))
             else
{$endif}
                abssym.AddrOffset:=TOrdConstNode(pt).Value.svalue;
{$if defined(i386)}
              TCPUAbsoluteVarSym(abssym).AbsSeg:=false;
{$endif i386}
            end
          { variable }
          else
            begin
              { we have to be able to take the address of the absolute
                expression
              }
              valid_for_addr(pt,true);
              { remove subscriptn before checking for loadn }
              hp:=pt;
              while (hp.nodetype in [subscriptn,typeconvn,vecn]) do
                begin
                  { check for implicit dereferencing and reject it }
                  if (hp.nodetype in [subscriptn,vecn]) then
                    begin
                      if (TUnaryNode(hp).left.resultdef.typ in [pointerdef,classrefdef]) then
                        break;
                      { catch, e.g., 'var b: char absolute pchar_var[5];"
                        (pchar_var[5] is a pchar_2_string typeconv ->
                         the vecn only sees an array of char)
                        I don't know if all of these type conversions are
                        possible, but they're definitely all bad.
                      }
                      if (TUnaryNode(hp).left.nodetype=typeconvn) and
                         (TTypeConvNode(TUnaryNode(hp).left).ConvType in
                           [tc_pchar_2_string,tc_pointer_2_array,
                            tc_intf_2_string,tc_intf_2_guid,
                            tc_dynarray_2_variant,tc_interface_2_variant,
                            tc_array_2_dynarray]) then
                        break;

                      if (TUnaryNode(hp).left.resultdef.typ=stringdef) and
                         not(TStringDef(TUnaryNode(hp).left.resultdef).StringType in [st_shortstring,st_longstring]) then
                        break;
                      if (TUnaryNode(hp).left.resultdef.typ=objectdef) and
                         (TObjectDef(TUnaryNode(hp).left.resultdef).ObjectType<>odt_object) then
                        break;
                      if Is_Dynamic_Array(TUnaryNode(hp).left.resultdef) then
                        break;
                    end;
                  hp:=TUnaryNode(hp).left;
                end;
              if (hp.nodetype=loadn) then
                begin
                  { we should check the result type of loadn }
                  if not (TLoadNode(hp).SymTableEntry.typ in [FieldVarSym,staticvarsym,localvarsym,paravarsym,absolutevarsym]) then
                    Message(parser_e_absolute_only_to_var_or_const);
                  if vs=TLoadNode(hp).SymTableEntry then
                    Message(parser_e_absolute_sym_cannot_reference_itself)
                  else
                    begin
                      abssym:=CAbsoluteVarSym.Create(vs.realname,vs.vardef);
                      abssym.fileinfo:=vs.fileinfo;
                      abssym.AbsTyp:=tovar;
                      abssym.Ref:=Node_To_PropAccessList(pt);
                      { if the sizes are different, can't be a regvar since you }
                      { can't be "absolute upper 8 bits of a register" (except  }
                      { if its a record field of the same size of a record      }
                      { regvar, but in that case pt.resultdef.size will have    }
                      { the same size since it refers to the field and not to   }
                      { the whole record -- which is why we use pt and not hp)  }

                      { we can't take the size of an open array or an array of const }
                      if Is_Open_Array(pt.resultdef) or
                         Is_Array_Of_Const(pt.resultdef) or
                         (vs.vardef.Size <> pt.resultdef.Size) then
                        make_not_regable(pt,[ra_addr_regable]);
                      TAbsoluteVarSym(abssym).Adjust_VarRegable;
                    end;
                end
              else
                Message(parser_e_absolute_only_to_var_or_const);
            end;
          pt.free;
          pt := nil;
          { replace old varsym with the new absolutevarsym }
          if Assigned(abssym) then
            begin
              st:=vs.owner;
              vs.owner.DeleteSym(vs);
              st.InsertSym(abssym);
              sc[0]:=abssym;
            end;
        end;

      var
         sc   : TFPObjectList;
         vs   : TAbstractVarSym;
         hdef : TDef;
         i    : LongInt;
         flags : THCCFlags;
         first,
         isgeneric,
         semicoloneaten,
         allowdefaultvalue,
         hasdefaultvalue : boolean;
         hintsymoptions  : TSymOptions;
         DeprecatedMsg   : PShortString;
         old_block_type  : TBlockType;
         typepos,
         tmp_filepos,
         old_current_filepos     : TFilePosInfo;
      begin
         old_block_type:=Block_Type;
         Block_Type:=bt_var;
         { Force an expected ID error message }
         if not (CurrentScanner.token in [_ID,_CASE,_END]) then
           consume(_ID);
         { read vars }
         sc:=TFPObjectList.Create(false);
         first:=true;
         had_generic:=false;
         vs:=nil;
         fillchar(tmp_filepos,sizeof(tmp_filepos),0);
         while (CurrentScanner.token=_ID) do
           begin
             semicoloneaten:=false;
             hasdefaultvalue:=false;
             allowdefaultvalue:=true;
             sc.clear;
             repeat
               if (CurrentScanner.token = _ID) then
                 begin
                   isgeneric:=(vd_check_generic in options) and
                                not (m_delphi in CurrentSettings.ModeSwitches) and
                                (CurrentScanner.idtoken=_GENERIC);
                   case SymTableStack.top.SymTableType of
                     LocalSymTable :
                       vs:=CLocalVarSym.Create(CurrentScanner.orgpattern,vs_value,GenErrorDef,[]);
                     staticsymtable,
                     GlobalSymTable :
                       begin
                         vs:=CStaticVarSym.Create(CurrentScanner.orgpattern,vs_value,GenErrorDef,[]);
                         if vd_threadvar in options then
                           include(vs.VarOptions,vo_is_thread_var);
                       end;
                     else
                       InternalError(200411064);
                   end;
                   sc.add(vs);
                   if isgeneric then
                     tmp_filepos:=CurrentFilePos;
                 end
               else
                 isgeneric:=false;
               consume(_ID);
               { when the first variable had been read the next declaration could be
                 a "generic procedure", "generic function" or
                 "generic class (function/procedure)" }
               if not first
                   and isgeneric
                   and (sc.count=1)
                   and (CurrentScanner.token in [_PROCEDURE,_FUNCTION,_CLASS]) then
                 begin
                   vs.free;
                   vs := nil;
                   sc.clear;
                   had_generic:=true;
                   break;
                 end
               else
                 begin
                   vs.RegisterSym;
                   if isgeneric then
                     begin
                       { ensure correct error position }
                       old_current_filepos:=CurrentFilePos;
                       CurrentFilePos:=tmp_filepos;
                       SymTableStack.top.InsertSym(vs);
                       CurrentFilePos:=old_current_filepos;
                     end
                   else
                     SymTableStack.top.InsertSym(vs);
                 end;
             until not try_to_consume(_COMMA);

             if had_generic then
               break;

             { read variable type def }
             Block_Type:=bt_var_type;
             consume(_COLON);
             typepos:=CurrentTokenPos;

             read_anon_type(hdef,false,nil);
             for i:=0 to sc.count-1 do
               begin
                 vs:=TAbstractVarSym(sc[i]);
                 vs.vardef:=hdef;
               end;
             Block_Type:=bt_var;

             { Process procvar directives }
             if maybe_parse_proc_directives(hdef) then
               semicoloneaten:=true;

             { check for absolute }
             if try_to_consume(_ABSOLUTE) then
               begin
                 read_absolute(sc);
                 allowdefaultvalue:=false;
               end;

             { Check for EXTERNAL etc directives before a semicolon }
             if (CurrentScanner.idtoken in [_EXPORT,_EXTERNAL,_PUBLIC,_CVAR]) or (CurrentScanner.idtoken = _WEAKEXTERNAL) then
               begin
                 read_public_and_external_sc(sc);
                 allowdefaultvalue:=false;
                 semicoloneaten:=true;
               end;

             { try to parse the hint directives }
             hintsymoptions:=[];
             DeprecatedMsg:=nil;
             try_consume_hintdirective(hintsymoptions,DeprecatedMsg);
             for i:=0 to sc.count-1 do
               begin
                 vs:=TAbstractVarSym(sc[i]);
                 vs.SymOptions := vs.SymOptions + hintsymoptions;
                 if DeprecatedMsg<>nil then
                   vs.DeprecatedMsg:=StringDup(DeprecatedMsg^);
               end;
             StringDispose(DeprecatedMsg);

             { Handling of Delphi typed const = initialized vars }
             if allowdefaultvalue and
                (CurrentScanner.token=_EQ) and
                (SymTableStack.top.SymTableType<>parasymtable) then
               begin
                 { Add calling convention for procvar }
                 if (
                      (hdef.typ=procvardef) or
                      Is_FuncRef(hdef)
                    ) and
                    (hdef.TypeSym=nil) then
                   begin
                     if po_is_function_ref in TProcVarDef(hdef).ProcOptions then
                       begin
                         if not (m_function_references in CurrentSettings.ModeSwitches) and
                             not (po_is_block in TProcVarDef(hdef).ProcOptions) then
                           messagepos(typepos,sym_e_error_in_type_def)
                         else
                           begin
                             if Adjust_FuncRef(hdef,nil,nil) then
                               { the def was changed, so update it }
                               for i:=0 to sc.count-1 do
                                 begin
                                   vs:=TAbstractVarSym(sc[i]);
                                   vs.vardef:=hdef;
                                 end;
                             if CurrentScanner.replay_stack_depth=0 then
                               hdef.RegisterDef;
                           end;
                       end;
                     handle_calling_convention(hdef,hcc_default_actions_intf);
                   end;
                 read_default_value(sc);
                 hasdefaultvalue:=true;
               end
             else
               begin
                 if not(semicoloneaten) then
                   consume(_SEMICOLON);
               end;

             { Support calling convention for procvars after semicolon }
             if not(hasdefaultvalue) and
                (
                  (hdef.typ=procvardef) or
                  Is_FuncRef(hdef)
                ) and
                (hdef.TypeSym=nil) then
               begin
                 { Parse procvar directives after ; }
                 maybe_parse_proc_directives(hdef);
                 if (hdef.typ=procvardef) and (po_is_function_ref in TProcVarDef(hdef).ProcOptions) then
                   begin
                     if not (m_function_references in CurrentSettings.ModeSwitches) and
                         not (po_is_block in TProcVarDef(hdef).ProcOptions) then
                       messagepos(typepos,sym_e_error_in_type_def)
                     else
                       begin
                         if Adjust_FuncRef(hdef,nil,nil) then
                           { the def was changed, so update it }
                           for i:=0 to sc.count-1 do
                             begin
                               vs:=TAbstractVarSym(sc[i]);
                               vs.vardef:=hdef;
                             end;
                         if CurrentScanner.replay_stack_depth=0 then
                           hdef.RegisterDef;
                       end;
                   end;
                 { Add calling convention for procvar }
                 if hdef.typ=procvardef then
                   flags:=hcc_default_actions_intf
                 else
                   flags:=hcc_default_actions_intf_struct;
                 handle_calling_convention(hdef,flags);
                 { Handling of Delphi typed const = initialized vars }
                 if (CurrentScanner.token=_EQ) and
                    (SymTableStack.top.SymTableType<>parasymtable) then
                   begin
                     read_default_value(sc);
                     hasdefaultvalue:=true;
                   end;
               end;

             { Check for EXTERNAL etc directives or, in macpas, if cs_external_var is set}
             if (
                 (
                  ((CurrentScanner.idtoken in [_EXPORT,_EXTERNAL,_PUBLIC,_CVAR]) or (CurrentScanner.idtoken = _WEAKEXTERNAL)) and
                  (m_cvar_support in CurrentSettings.ModeSwitches)
                 ) or
                 (
                  (m_mac in CurrentSettings.ModeSwitches) and
                  (
                   (cs_external_var in CurrentSettings.LocalSwitches) or
                   (cs_externally_visible in CurrentSettings.LocalSwitches)
                  )
                 )
                ) then
               read_public_and_external_sc(sc);

             { allocate normal variable (non-external and non-typed-const) staticvarsyms }
             for i:=0 to sc.count-1 do
               begin
                 vs:=TAbstractVarSym(sc[i]);
                 if (vs.typ=staticvarsym) and
                    not(vo_is_typed_const in vs.VarOptions) and
                    not(vo_is_external in vs.VarOptions) then
                   CNodeUtils.InsertBSSData(TStaticVarSym(vs));
                 if vo_is_public in vs.VarOptions then
                   CurrentModule.Add_Public_AsmSym(vs.MangledName,AB_GLOBAL,AT_DATA);
               end;

             first:=false;
           end;
         Block_Type:=old_block_type;
         { free the list }
         sc.free;
         sc := nil;
      end;


    function check_allowed_for_var_or_const(def:TDef;allowdynarray:boolean):boolean;
      var
        stowner,tmpdef : TDef;
        st : TSymTable;
      begin
        result:=true;
        st:=SymTableStack.top;
        if not (st.SymTableType in [recordsymtable,objectsymtable]) then
          exit;
        stowner:=TDef(st.DefOwner);
        while Assigned(stowner) and (stowner.typ in [objectdef,recorddef]) do
          begin
            if def.typ=arraydef then
              begin
                tmpdef:=def;
                while (tmpdef.typ=arraydef) do
                  begin
                    { dynamic arrays are allowed in certain cases }
                    if allowdynarray and (ado_IsDynamicArray in TArrayDef(tmpdef).ArrayOptions) then
                      begin
                        tmpdef:=nil;
                        break;
                      end;
                    tmpdef:=TArrayDef(tmpdef).ElementDef;
                  end;
              end
            else
              tmpdef:=def;
            if Assigned(tmpdef) and
                (Is_Object(tmpdef) or Is_Record(tmpdef)) and
                Is_Owned_By(TAbstractRecordDef(stowner),TAbstractRecordDef(tmpdef)) then
              begin
                Message1(type_e_type_is_not_completly_defined,TAbstractRecordDef(tmpdef).RTTIName);
                result:=false;
                break;
              end;
            stowner:=TDef(stowner.owner.DefOwner);
          end;
      end;


    procedure read_record_fields(options:TVarDecOptions; reorderlist: TFPObjectList; variantdesc : PPVariantRecDesc;out had_generic:boolean; out attr_element_count : integer);
      var
         sc : TFPObjectList;
         i  : LongInt;
         hs,sorg : string;
         gendef,hdef,casetype : TDef;
         { maxsize contains the max. size of a variant }
         { startvarrec contains the start of the variant part of a record }
         maxsize, startvarrecsize : asizeint;
         usedalign,
         maxalignment,startvarrecalign,
         maxpadalign, startpadalign: shortint;
         pt : TNode;
         fieldvs   : TFieldVarSym;
         hstaticvs : TStaticVarSym;
         vs    : TAbstractVarSym;
         srsym : TSym;
         srsymtable : TSymTable;
         visibility : TVisibility;
         recst : TAbstractRecordSymTable;
         unionsymtable : TRecordSymTable;
         offset : LongInt;
         uniondef : TRecordDef;
         hintsymoptions : TSymOptions;
         DeprecatedMsg : PShortString;
         hadgendummy,
         semicoloneaten,
         removeclassoption: boolean;
         dummyattrelementcount : integer;
         old_block_type: TBlockType;
         typepos : TFilePosInfo;
      begin
         old_block_type:=Block_Type;
         Block_Type:=bt_var;
         recst:=TAbstractRecordSymTable(SymTableStack.top);
         { Force an expected ID error message }
         if not (CurrentScanner.token in [_ID,_CASE,_END]) then
           consume(_ID);
         { read vars }
         sc:=TFPObjectList.Create(false);
         removeclassoption:=false;
         had_generic:=false;
         attr_element_count:=0;
         while (CurrentScanner.token=_ID) and
            not(((vd_object in options) or
                 ((vd_record in options) and (m_advanced_records in CurrentSettings.ModeSwitches))) and
                ((CurrentScanner.idtoken in [_PUBLIC,_PRIVATE,_PUBLISHED,_PROTECTED,_STRICT]) or
                 ((m_final_fields in CurrentSettings.ModeSwitches) and
                  (CurrentScanner.idtoken=_FINAL)))) do
           begin
             visibility:=SymTableStack.top.CurrentVisibility;
             semicoloneaten:=false;
             sc.clear;
             repeat
               sorg:=CurrentScanner.orgpattern;
               if CurrentScanner.token=_ID then
                 begin
                   vs:=CFieldVarSym.Create(sorg,vs_value,GenErrorDef,[]);

                   { normally the visibility is set via addfield, but sometimes
                     we collect symbols so we can add them in a batch of
                     potentially mixed visibility, and then the individual
                     symbols need to have their visibility already set }
                   vs.visibility:=visibility;
                   if (vd_check_generic in options) and (CurrentScanner.idtoken=_GENERIC) then
                     had_generic:=true;
                 end
               else
                 vs:=nil;
               consume(_ID);
               if Assigned(vs) and
                  (
                    not had_generic or
                    not (CurrentScanner.token in [_PROCEDURE,_FUNCTION,_CLASS])
                  ) then
                 begin
                   vs.RegisterSym;
                   sc.add(vs);
                   recst.InsertSym(vs);
                   had_generic:=false;
                 end
               else
                 vs.free; // no nil needed
             until not try_to_consume(_COMMA);
             if m_delphi in CurrentSettings.ModeSwitches then
               Block_Type:=bt_var_type
             else
               Block_Type:=old_block_type;
             if had_generic and (sc.count=0) then
               break;
             consume(_COLON);
             if attr_element_count=0 then
               attr_element_count:=sc.Count;

             typepos:=CurrentFilePos;

             { make sure that the correct genericdef is set up, especially if
               we're dealing with anonymous type declarations }
             gendef:=nil;
             if df_specialization in CurrentStructDef.DefOptions then
               begin
                 srsymtable:=CurrentStructDef.GenericDef.GetSymTable(gs_record);
                 if not Assigned(srsymtable) then
                   InternalError(2024041204);
                 srsym:=TSym(srsymtable.find(TAbstractVarSym(sc[0]).name));
                 if not Assigned(srsym) then
                   InternalError(2024041205);
                 if srsym.typ<>FieldVarSym then
                   InternalError(2024041206);
                 gendef:=TFieldVarSym(srsym).vardef;
               end;

             read_anon_type(hdef,false,TStoredDef(gendef));
             Block_Type:=bt_var;
             { allow only static fields reference to struct where they are declared }
             if not (vd_class in options) then
               begin
                 if not check_allowed_for_var_or_const(hdef,true) then
                   { for error recovery or compiler will crash later }
                   hdef:=GenErrorDef;
               end;

             { field type is a generic param so set a flag in the struct }
             if Assigned(hdef.TypeSym) and (sp_generic_para in hdef.TypeSym.SymOptions) then
               include(CurrentStructDef.DefOptions,df_has_generic_fields);

             { Process procvar directives }
             if maybe_parse_proc_directives(hdef) then
               semicoloneaten:=true;


             { types that use init/final are not allowed in variant parts, but
               classes are allowed }
             if (variantrecordlevel>0) then
               if Is_Managed_Type(hdef) then
                 Message(parser_e_cant_use_inittable_here);

             { try to parse the hint directives }
             hintsymoptions:=[];
             DeprecatedMsg:=nil;
             try_consume_hintdirective(hintsymoptions,DeprecatedMsg);

             { update variable type and hints }
             for i:=0 to sc.count-1 do
               begin
                 fieldvs:=TFieldVarSym(sc[i]);
                 fieldvs.vardef:=hdef;
                 { insert any additional hint directives }
                 fieldvs.SymOptions := fieldvs.SymOptions + hintsymoptions;
                 if DeprecatedMsg<>nil then
                   fieldvs.DeprecatedMsg:=StringDup(DeprecatedMsg^);
               end;
               StringDispose(DeprecatedMsg);

             { Records and objects can't have default values }
             { for a record there doesn't need to be a ; before the END or )    }
             if not(CurrentScanner.token in [_END,_RKLAMMER]) and
                not(semicoloneaten) then
               consume(_SEMICOLON);

             { Parse procvar directives after ; }
             maybe_parse_proc_directives(hdef);

             { Add calling convention for procvar }
             if (
                 (hdef.typ=procvardef) or
                 Is_FuncRef(hdef)
               ) and (hdef.TypeSym=nil) then
               begin
                 if (hdef.typ=procvardef) and (po_is_function_ref in TProcVarDef(hdef).ProcOptions) then
                   begin
                     if not (m_function_references in CurrentSettings.ModeSwitches) and
                         not (po_is_block in TProcVarDef(hdef).ProcOptions) then
                       messagepos(typepos,sym_e_error_in_type_def)
                     else
                       begin
                         if Adjust_FuncRef(hdef,nil,nil) then
                           { the def was changed, so update it }
                           for i:=0 to sc.count-1 do
                             begin
                               fieldvs:=TFieldVarSym(sc[i]);
                               fieldvs.vardef:=hdef;
                             end;
                         if CurrentScanner.replay_stack_depth=0 then
                           hdef.RegisterDef;
                       end;
                   end;
                 handle_calling_convention(hdef,hcc_default_actions_intf);
               end;

             if (vd_object in options) then
               begin
                 { if it is not a class var section and token=STATIC then it is a class field too }
                 if not (vd_class in options) and try_to_consume(_STATIC) then
                   begin
                     consume(_SEMICOLON);
                     include(options,vd_class);
                     removeclassoption:=true;
                   end;

               end;
             if (visibility=vis_published) and
                not(Is_Class(hdef)) then
               begin
                 MessagePos(TFieldVarSym(sc[0]).fileinfo,parser_e_cant_publish_that);
                 visibility:=vis_public;
               end;

             if (visibility=vis_published) and
                not(oo_can_have_published in TObjectDef(hdef).ObjectOptions) and
                not(m_delphi in CurrentSettings.ModeSwitches) then
               begin
                 MessagePos(TFieldVarSym(sc[0]).fileinfo,parser_e_only_publishable_classes_can_be_published);
                 visibility:=vis_public;
               end;
             if vd_class in options then
               begin
                 { add static flag and staticvarsyms }
                 for i:=0 to sc.count-1 do
                   begin
                     fieldvs:=TFieldVarSym(sc[i]);
                     fieldvs.visibility:=visibility;
                     hstaticvs:=Make_Field_Static(recst,fieldvs);
                     if vd_threadvar in options then
                       include(hstaticvs.VarOptions,vo_is_thread_var);
                     if not parse_generic then
                       CNodeUtils.InsertBSSData(hstaticvs);
                     if vd_final in options then
                       hstaticvs.VarSpez:=vs_final;
                   end;
                 if removeclassoption then
                   begin
                     exclude(options,vd_class);
                     removeclassoption:=false;
                   end;
               end;
             if vd_final in options then
               begin
                 { add final flag }
                 for i:=0 to sc.count-1 do
                   begin
                     fieldvs:=TFieldVarSym(sc[i]);
                     fieldvs.VarSpez:=vs_final;
                   end;
               end;

             if not(vd_canreorder in options) then
               { add field(s) to the recordsymtable }
               recst.AddFieldList(sc,false)
             else
               { we may reorder the fields before adding them to the symbol
                 table }
               reorderlist.ConcatListCopy(sc)
           end;

         if m_delphi in CurrentSettings.ModeSwitches then
           Block_Type:=bt_var_type
         else
           Block_Type:=old_block_type;
         { Check for Case }
         if (vd_record in options) and
            try_to_consume(_CASE) then
           begin
              maxsize:=0;
              maxalignment:=0;
              maxpadalign:=0;

              { already inside a variant record? if not, setup a new variantdesc chain }
              if not(Assigned(variantdesc)) then
                variantdesc:=@TRecordDef(TRecordSymTable(recst).DefOwner).VariantRecDesc;

              { else just concat the info to the given one }
              new(variantdesc^);
              fillchar(variantdesc^^,sizeof(TVariantRecDesc),0);

              { including a field declaration? }
              fieldvs:=nil;
              if CurrentScanner.token=_ID then
                begin
                  sorg:=CurrentScanner.orgpattern;
                  hs:=CurrentScanner.pattern;
                  SearchSym(hs,srsym,srsymtable);
                  if not(Assigned(srsym) and (srsym.typ in [TypeSym,UnitSym])) then
                    begin
                      consume(_ID);
                      consume(_COLON);
                      fieldvs:=CFieldVarSym.Create(sorg,vs_value,GenErrorDef,[]);
                      variantdesc^^.VariantSelector:=fieldvs;
                      SymTableStack.top.InsertSym(fieldvs);
                    end;
                end;
              read_anon_type(casetype,true,nil);
              Block_Type:=bt_var;
              if Assigned(fieldvs) then
                begin
                  fieldvs.vardef:=casetype;
                  recst.AddField(fieldvs,recst.CurrentVisibility);
                end;
              if not(Is_Ordinal(casetype))
{$ifndef cpu64bitaddr}
                 or Is_64BitInt(casetype)
{$endif cpu64bitaddr}
                 then
                Message(type_e_ordinal_expr_expected);
              consume(_OF);

              UnionSymtable:=TRecordSymTable.Create('',CurrentSettings.PackRecords,CurrentSettings.Alignment.RecordAlignMin);
              UnionDef:=CRecordDef.Create('',unionsymtable);
              uniondef.IsUnion:=true;

              startvarrecsize:=UnionSymtable.DataSize;
              { align the bitpacking to the next byte }
              UnionSymtable.DataSize:=startvarrecsize;
              startvarrecalign:=UnionSymtable.FieldAlignment;
              startpadalign:=Unionsymtable.PadAlignment;
              SymTableStack.push(UnionSymtable);
              repeat
                SetLength(variantdesc^^.branches,length(variantdesc^^.branches)+1);
                fillchar(variantdesc^^.branches[high(variantdesc^^.branches)],
                  sizeof(variantdesc^^.branches[high(variantdesc^^.branches)]),0);
                repeat
                  pt:=comp_expr([ef_accept_equal]);
                  if not(pt.nodetype=ordconstn) then
                    Message(parser_e_illegal_expression);
                  InsertTypeConv(pt,casetype);
                  { iso pascal does not support ranges in variant record definitions }
                  if (([m_iso,m_extpas]*CurrentSettings.ModeSwitches)=[]) and try_to_consume(_POINTPOINT) then
                    pt:=CRangeNode.Create(pt,comp_expr([ef_accept_equal]))
                  else
                    begin
                      with variantdesc^^.branches[high(variantdesc^^.branches)] do
                        begin
                          SetLength(values,length(values)+1);
                          values[high(values)]:=TOrdConstNode(pt).Value;
                        end;
                    end;
                  pt.free;
                  pt := nil;
                  if CurrentScanner.token=_COMMA then
                    consume(_COMMA)
                  else
                    break;
                until false;
                if m_delphi in CurrentSettings.ModeSwitches then
                  Block_Type:=bt_var_type
                else
                  Block_Type:=old_block_type;
                consume(_COLON);
                { read the vars }
                consume(_LKLAMMER);
                inc(variantrecordlevel);
                if CurrentScanner.token<>_RKLAMMER then
                  read_record_fields([vd_record],nil,@variantdesc^^.branches[high(variantdesc^^.branches)].NestedVariant,hadgendummy,dummyattrelementcount);
                dec(variantrecordlevel);
                consume(_RKLAMMER);

                { calculates maximal variant size }
                maxsize:=max(maxsize,unionsymtable.DataSize);
                maxalignment:=max(maxalignment,unionsymtable.FieldAlignment);
                maxpadalign:=max(maxpadalign,unionsymtable.PadAlignment);
                { the items of the next variant are overlayed }
                unionsymtable.DataSize:=startvarrecsize;
                unionsymtable.FieldAlignment:=startvarrecalign;
                unionsymtable.PadAlignment:=startpadalign;
                if (CurrentScanner.token<>_END) and (CurrentScanner.token<>_RKLAMMER) then
                  consume(_SEMICOLON)
                else
                  break;
              until (CurrentScanner.token=_END) or (CurrentScanner.token=_RKLAMMER);
              SymTableStack.pop(UnionSymtable);
              { at last set the record size to that of the biggest variant }
              unionsymtable.DataSize:=maxsize;
              unionsymtable.FieldAlignment:=maxalignment;
              unionsymtable.AddAlignmentPadding;
              { Align the offset where the union symtable is added }
              case recst.UseFieldAlignment of
                { allow the unionsymtable to be aligned however it wants }
                { (within the global min/max limits)                     }
                0, { default }
                CAlignment:
                  usedalign:=Used_Align(unionsymtable.RecordAlignment,CurrentSettings.Alignment.RecordAlignMin,CurrentSettings.Alignment.MaxCRecordAlign);
                { 1 byte alignment if we are bitpacked }
                BitAlignment:
                  usedalign:=1;
                Mac68KAlignment:
                  usedalign:=2;
                { otherwise alignment at the packrecords alignment of the }
                { current record                                          }
                else
                  usedalign:=Used_Align(recst.FieldAlignment,CurrentSettings.Alignment.RecordAlignMin,CurrentSettings.Alignment.RecordAlignMax);
              end;
              offset:=align(recst.DataSize,usedalign);
              recst.DataSize:=offset+unionsymtable.DataSize;

              if unionsymtable.RecordAlignment>recst.FieldAlignment then
                recst.FieldAlignment:=unionsymtable.RecordAlignment;

              if unionsymtable.ExplicitRecordAlignment>recst.ExplicitRecordAlignment then
                recst.ExplicitRecordAlignment:=unionsymtable.ExplicitRecordAlignment;

              TRecordSymTable(recst).InsertUnionST(Unionsymtable,offset);
              uniondef.owner.DeleteDef(uniondef);
           end;
         { free the list }
         sc.free;
         sc := nil;
         Block_Type:=old_block_type;
      end;

end.
