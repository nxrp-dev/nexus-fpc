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
      TVarDecOption=(vdRecord,vdObject,vdThreadVar,vdClass,vdFinal,vdCanReorder,vdCheckGeneric);
      TVarDecOptions=set of TVarDecOption;

    function  ReadPropertyDec(AIsClassProperty:Boolean;AStruct:TAbstractRecordDef):TPropertySym;

    procedure ReadVarDecls(AOptions:TVarDecOptions;out AHadGeneric:Boolean);

    procedure ReadRecordFields(AOptions:TVarDecOptions; AReorderList: TFPObjectList; AVariantDesc: PPVariantRecDesc;out AHadGeneric:Boolean; out AAttrElementCount : Integer);

    procedure ReadPublicAndExternal(AVarSym: TAbstractVarSym);

    procedure TryConsumeSectionDirective(var ASection: AnsiString);

    function CheckAllowedForVarOrConst(ADef:TDef;AAllowDynArray:Boolean):Boolean;

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


    function ReadPropertyDec(AIsClassProperty:Boolean;AStruct:TAbstractRecordDef):TPropertySym;

        { convert a node tree to symlist and return the last
          symbol }
        function ParseSymList(AAccessList:TPropAccessList;out ADef:TDef):Boolean;
          var
            lIndex : LongInt;
            lSym : TSym;
            lSearchSymTable : TSymTable;
            lSymTable  : TSymTable;
            lNode   : TNode;
          begin
            Result:=true;
            ADef:=nil;
            if CurrentScanner.FToken=_ID then
             begin
               if Assigned(AStruct) then
                 lSym:=Search_Struct_Member(AStruct,CurrentScanner.FPattern)
               else
                 SearchSym(CurrentScanner.FPattern,lSym,lSearchSymTable);
               if Assigned(lSym) then
                begin
                  if Assigned(AStruct) and
                     not Is_Visible_For_Object(lSym,AStruct) then
                    Message(parser_e_cant_access_private_member);
                  case lSym.typ of
                    FieldVarSym :
                      begin
                        AddSymRef(lSym);
                        AAccessList.AddSym(sl_load,lSym);
                        ADef:=TFieldVarSym(lSym).vardef;
                      end;
                    ProcSym :
                      begin
                        AddSymRef(lSym);
                        AAccessList.AddSym(sl_call,lSym);
                      end;
                    else
                      begin
                        Message1(parser_e_illegal_field_or_method,CurrentScanner.FOrgPattern);
                        ADef:=GenErrorDef;
                        Result:=false;
                      end;
                  end;
                end
               else
                begin
                  Message1(parser_e_illegal_field_or_method,CurrentScanner.FOrgPattern);
                  ADef:=GenErrorDef;
                  Result:=false;
                end;
               Consume(_ID);
               repeat
                 case CurrentScanner.FToken of
                   _ID,
                   _SEMICOLON :
                     begin
                       break;
                     end;
                   _POINT :
                     begin
                       if not Is_Object(ADef) and not Is_Record(ADef) then
                         message(sym_e_type_must_be_rec_or_object);
                       Consume(_POINT);
                       if Assigned(ADef) then
                        begin
                          lSymTable:=ADef.GetSymTable(gs_record);
                          if Assigned(lSymTable) then
                           begin
                             lSym:=TSym(lSymTable.Find(CurrentScanner.FPattern));
                             if not(Assigned(lSym)) and Is_Object(ADef) then
                               lSym:=Search_Struct_Member(TObjectDef(ADef),CurrentScanner.FPattern);
                             if Assigned(lSym) then
                              begin
                                AAccessList.AddSym(sl_subscript,lSym);
                                case lSym.typ of
                                  FieldVarSym :
                                    ADef:=TFieldVarSym(lSym).vardef;
                                  else
                                    begin
                                      Message1(sym_e_illegal_field,CurrentScanner.FOrgPattern);
                                      Result:=false;
                                    end;
                                end;
                              end
                             else
                              begin
                                Message1(sym_e_illegal_field,CurrentScanner.FOrgPattern);
                                Result:=false;
                              end;
                           end
                          else
                           begin
                             Message(parser_e_invalid_qualifier);
                             Result:=false;
                           end;
                        end
                       else
                        begin
                          Message(parser_e_invalid_qualifier);
                          Result:=false;
                        end;
                       Consume(_ID);
                     end;
                   _LECKKLAMMER :
                     begin
                       Consume(_LECKKLAMMER);
                       repeat
                         if Assigned(ADef) and (ADef.typ=arraydef) then
                          begin
                            lIndex:=0;
                            lNode:=CompExpr([efAcceptEqual]);
                            if (not CodeGenError) then
                             begin
                               if (lNode.nodetype=ordconstn) then
                                 begin
                                   { type/range checking }
                                   InsertTypeConv(lNode,TArrayDef(ADef).RangeDef);
                                   if (TOrdConstNode(lNode).Value<Int64(low(LongInt))) or
                                      (TOrdConstNode(lNode).Value>Int64(high(LongInt))) then
                                     message(parser_e_array_range_out_of_bounds)
                                   else
                                     lIndex:=TOrdConstNode(lNode).Value.svalue
                                 end
                               else
                                Message(type_e_ordinal_expr_expected)
                             end;
                            AAccessList.AddConst(sl_vec,lIndex,lNode.resultdef);
                            lNode.free;
                            lNode := nil;
                            ADef:=TArrayDef(ADef).ElementDef;
                          end
                         else
                          begin
                            Message(parser_e_invalid_qualifier);
                            Result:=false;
                          end;
                       until not TryToConsume(_COMMA);
                       Consume(_RECKKLAMMER);
                     end;
                   else
                     begin
                       Message(parser_e_ill_property_access_sym);
                       Result:=false;
                       break;
                     end;
                 end;
               until false;
             end
            else
             begin
               Message(parser_e_ill_property_access_sym);
               Result:=false;
             end;
          end;

          function HasImplicitDefault(AProperty : TPropertySym) : Boolean;

          begin
             HasImplicitDefault:=
               (Is_String(AProperty.PropDef) or
               Is_Real(AProperty.PropDef) or
               Is_Pointer(AProperty.PropDef));
          end;

          function AllowDefaultProperty(AProperty : TPropertySym) : Boolean;

          begin
             AllowDefaultProperty:=
               (Is_Ordinal(AProperty.PropDef) or
{$ifndef cpu64bitaddr}
               Is_64BitInt(AProperty.PropDef) or
{$endif cpu64bitaddr}
               Is_Class(AProperty.PropDef) or
               Is_Single(AProperty.PropDef) or
               (AProperty.PropDef.typ in [classrefdef,pointerdef]) or
                 Is_SmallSet(AProperty.PropDef)
               ) and not
               (
                (AProperty.PropDef.typ=arraydef) and
                (ppo_indexed in AProperty.PropOptions)
               ) and not
               (ppo_hasparameters in AProperty.PropOptions);
          end;

          procedure CreateAccessorProcSym(AProperty: TPropertySym; AProcDef: TProcDef; const APrefix: String;
              AAccessType: TPropAccessListTypes);
            var
              lProcSym: TProcSym;
            begin
              if not Assigned(AStruct) then
                Handle_Calling_Convention(AProcDef,cHCCDefaultActionsIntf)
              else
                Handle_Calling_Convention(AProcDef,cHCCDefaultActionsIntfStruct);
              lProcSym:=CProcSym.Create(APrefix+lower(AProperty.realname));
              SymTableStack.top.InsertSym(lProcSym);
              AProcDef.ProcSym:=lProcSym;
              include(AProcDef.ProcOptions,po_dispid);
              include(AProcDef.ProcOptions,po_global);
              AProcDef.visibility:=vis_private;
              Proc_Add_Definition(AProcDef);
              AProperty.PropAccessList[AAccessType].AddSym(sl_call,lProcSym);
              AProperty.PropAccessList[AAccessType].procdef:=AProcDef;
            end;

          procedure ParseDispInterface(AProperty : TPropertySym; AReadProcDef,AWriteProcDef: TProcDef;
              var AParaNr: Word);
            var
              lHasRead, lHasWrite: Boolean;
              lNode: TNode;
              lDispID: LongInt;
              lParaVarSym: TParaVarSym;
            begin
              AProperty.PropAccessList[palt_read].clear;
              AProperty.PropAccessList[palt_write].clear;

              lHasRead:=true;
              lHasWrite:=true;
              lDispID:=0;

              if TryToConsume(_READONLY) then
                lHasWrite:=false
              else if TryToConsume(_WRITEONLY) then
                lHasRead:=false;

              if TryToConsume(_DISPID) then
                begin
                  lNode:=CompExpr([efAcceptEqual]);
                  if Is_ConstIntNode(lNode) then
                    if (TOrdConstNode(lNode).Value<Int64(low(LongInt))) or (TOrdConstNode(lNode).Value>Int64(high(LongInt))) then
                      message3(type_e_range_check_error_bounds,ToStr(TOrdConstNode(lNode).Value),ToStr(low(LongInt)),ToStr(high(LongInt)))
                    else
                      lDispID:=TOrdConstNode(lNode).Value.svalue
                  else
                    Message(parser_e_dispid_must_be_ord_const);
                  lNode.free;
                  lNode := nil;
                end
              else
                lDispID:=TObjectDef(AStruct).Get_Next_DispID;

              { COM property is simply a pair of methods, tagged with 'propertyget'
                and 'propertyset' flags (or a single method if access is restricted).
                Creating these implicit accessor methods also allows the rest of compiler
                to handle dispinterface properties the same way as regular ones. }
              if lHasRead then
                begin
                  AReadProcDef.ReturnDef:=AProperty.PropDef;
                  AReadProcDef.DispID:=lDispID;
                  AReadProcDef.ProcTypeOption:=potype_propgetter;
                  CreateAccessorProcSym(AProperty,AReadProcDef,'get$',palt_read);
                end;
              if lHasWrite then
                begin
                  { add an extra parameter, a placeholder of the value to set }
                  inc(AParaNr);
                  lParaVarSym:=CParaVarSym.Create('$value',10*AParaNr,vs_value,AProperty.PropDef,[]);
                  AWriteProcDef.ParaST.InsertSym(lParaVarSym);

                  AWriteProcDef.ProcTypeOption:=potype_propsetter;
                  AWriteProcDef.DispID:=lDispID;
                  CreateAccessorProcSym(AProperty,AWriteProcDef,'put$',palt_write);
                end;
            end;

      var
         lSym : TSym;
         lSearchSymTable: TSymTable;
         lProperty : TPropertySym;
         lOverridden : TSym;
         lVarSpez : TVarSpez;
         lDef : TDef;
         lArrayType : TDef;
         lAccessDef : TDef;
         lNode : TNode;
         lSymbols : TFPObjectList;
         lParaNr : Word;
         lIndex      : LongInt;
	 lSingleValue : Single;
         lImplIntf     : TImplementedInterface;
         lFound,
         lGotReadOrWrite: Boolean;
         lReadParaVarSym,
         lParaVarSym      : TParaVarSym;
         lStoredProcDef: TProcVarDef;
         lReadProcDef,
         lWriteProcDef : TProcDef;
      begin
         Result:=nil;
         { Generate temp procdefs to search for matching read/write
           procedures. the readprocdef will store all definitions }
         lParaNr:=0;
         lReadProcDef:=CProcDef.Create(NormalFunctionLevel,false);
         lWriteProcDef:=CProcDef.Create(NormalFunctionLevel,false);

         lReadProcDef.struct:=AStruct;
         lWriteProcDef.struct:=AStruct;

         if Assigned(AStruct) and AIsClassProperty then
           begin
             lReadProcDef.ProcOptions:=[po_staticmethod,po_classmethod];
             lWriteProcDef.ProcOptions:=[po_staticmethod,po_classmethod];
           end;

         if CurrentScanner.FToken<>_ID then
           begin
              Consume(_ID);
              Consume(_SEMICOLON);
              exit;
           end;
         { Generate propertysym and insert in symtablestack }
         lProperty:=CPropertySym.Create(CurrentScanner.FOrgPattern);
         lProperty.visibility:=SymTableStack.top.CurrentVisibility;
         lProperty.default:=LongInt($80000000);
         if AIsClassProperty then
           include(lProperty.SymOptions, sp_static);
         SymTableStack.top.InsertSym(lProperty);
         Consume(_ID);
         { property parameters ? }
         if TryToConsume(_LECKKLAMMER) then
           begin
              { Published indexed properties are allowed in Delphi in interfaces compiled with $M+. }
              if (lProperty.visibility=vis_published) and
                not((m_delphi in CurrentSettings.ModeSwitches) and Is_InterfaceCOM_Or_DispInterface(AStruct)) then
                Message(parser_e_cant_publish_that_property);
              { create a list of the parameters }
              lProperty.ParaST:=TParaSymTable.Create(nil,0);
              SymTableStack.push(lProperty.ParaST);
              lSymbols:=TFPObjectList.Create(false);
              repeat
                if TryToConsume(_VAR) then
                  lVarSpez:=vs_var
                else if TryToConsume(_CONST) then
                  lVarSpez:=vs_const
                else if TryToConsume(_CONSTREF) then
                  lVarSpez:=vs_constref
                else if (m_out in CurrentSettings.ModeSwitches) and TryToConsume(_OUT) then
                  lVarSpez:=vs_out
                else
                  lVarSpez:=vs_value;
                lSymbols.clear;
                repeat
                  inc(lParaNr);
                  lReadParaVarSym:=CParaVarSym.Create(CurrentScanner.FOrgPattern,10*lParaNr,lVarSpez,GenErrorDef,[]);
                  lProperty.ParaST.InsertSym(lReadParaVarSym);
                  lSymbols.add(lReadParaVarSym);
                  Consume(_ID);
                until not TryToConsume(_COMMA);
                if TryToConsume(_COLON) then
                  begin
                    if TryToConsume(_ARRAY) then
                      begin
                        Consume(_OF);
                        { define range and type of range }
                        lDef:=CArrayDef.Create_OpenArray;
                        lDef.owner:=AStruct.SymTable;
                        { define field type }
                        SingleType(lArrayType,[]);
                        TArrayDef(lDef).ElementDef:=lArrayType;
                      end
                    else
                      SingleType(lDef,[]);
                  end
                else
                  lDef:=CFormalType;
                for lIndex:=0 to lSymbols.count-1 do
                  TParaVarSym(lSymbols[lIndex]).vardef:=lDef;
              until not TryToConsume(_SEMICOLON);
              lSymbols.free;
              lSymbols := nil;
              SymTableStack.pop(lProperty.ParaST);
              Consume(_RECKKLAMMER);

              { the parser need to know if a property has parameters, the
                index parameter doesn't count (PFV) }
              if lParaNr>0 then
                begin
                  lProperty.Add_Accessor_Parameters(lReadProcDef,lWriteProcDef);
                  include(lProperty.PropOptions,ppo_hasparameters);
                end;
           end;
         { overridden property ?                                 }
         { force property interface
             there is a property parameter
             a global property }
         if (CurrentScanner.FToken=_COLON) or (lParaNr>0) or (AStruct=nil) then
           begin
              Consume(_COLON);
              SingleType(lProperty.PropDef,[stoAllowSpecialization]);

              if Is_DispInterface(AStruct) and not Is_Automatable(lProperty.PropDef) then
                Message1(type_e_not_automatable,lProperty.PropDef.TypeName);

              if (CurrentScanner.FIDToken=_INDEX) then
                begin
                   Consume(_INDEX);
                   lNode:=CompExpr([efAcceptEqual]);
                   { Only allow enum and integer indexes. Convert all integer
                     values to objpas.integer (s32int on 32- and 64-bit targets,
                     s16int on 16- and 8-bit) to be compatible with delphi,
                     because the procedure matching requires equal parameters }
                   if Is_ConstNode(lNode) and
                      Is_Ordinal(lNode.resultdef)
                      and (not Is_64BitInt(lNode.resultdef))

                      then
                     begin
                       if Is_Integer(lNode.resultdef) then

                         InsertTypeConv_Internal(lNode,S32IntType);

                       lProperty.Index:=TOrdConstNode(lNode).Value.svalue;
                     end
                   else
                     begin
                       Message(parser_e_invalid_property_index_value);
                       lProperty.Index:=0;
                     end;
                   lProperty.IndexDef:=lNode.resultdef;
                   include(lProperty.PropOptions,ppo_indexed);
                   { concat a longint to the para templates }
                   lProperty.Add_Index_Parameter(lParaNr,lReadProcDef,lWriteProcDef);
                   lNode.free;
                   lNode := nil;
                end;
           end
         else
           begin
              { do an property override }
              if (AStruct.typ=objectdef) and Assigned(TObjectDef(AStruct).ChildOf) then
                lOverridden:=Search_Struct_Member(TObjectDef(AStruct).ChildOf,lProperty.name)
              else
                lOverridden:=nil;
              if Assigned(lOverridden) and
                 (lOverridden.typ=propertysym) and
                 not(Is_DispInterface(AStruct)) then
                begin
                  TPropertySym(lOverridden).MakeDuplicate(lProperty,lReadProcDef,lWriteProcDef,lParaNr);
                  lProperty.Register_Override(TPropertySym(lOverridden));
                end
              else
                begin
                  lProperty.PropDef:=GenErrorDef;
                  message(parser_e_no_property_found_to_override);
                end;
           end;
         if ((lProperty.visibility=vis_published) or Is_DispInterface(AStruct))
             and not (AStruct.Is_Generic and (lProperty.PropDef.typ=undefineddef)) then
           begin
             { ignore is_publishable for interfaces (related to $M+ directive).
               $M has effect on visibility of default section for classes.
               Interface has always only public section (fix for problem in tb0631.pas) }
             if (sp_static in lProperty.SymOptions) or ((lProperty.PropDef.IsPublishable=pp_error) and not Is_Interface(AStruct)) then
               begin
                 Message(parser_e_cant_publish_that_property);
                 lProperty.visibility:=vis_public;
               end
             else
             if (lProperty.PropDef.IsPublishable=pp_ignore) and not Is_Interface(AStruct) then
               begin
                 Message(parser_w_ignoring_published_property);
                 lProperty.visibility:=vis_public;
               end;
           end;

         if not(Is_DispInterface(AStruct)) then
           begin
             lGotReadOrWrite:=false;
             { parse accessors }
             if TryToConsume(_READ) then
               begin
                 lGotReadOrWrite:=true;
                 lProperty.PropAccessList[palt_read].clear;
                 if ParseSymList(lProperty.PropAccessList[palt_read],lAccessDef) then
                  begin
                    lSym:=lProperty.PropAccessList[palt_read].FirstSym^.sym;
                    { getter is a function returning the type of the property }
                    if lSym.typ=ProcSym then
                      begin
                        lReadProcDef.ReturnDef:=lProperty.PropDef;
                        { Insert hidden parameters }
                        if Assigned(AStruct) then
                          Handle_Calling_Convention(lReadProcDef,cHCCDefaultActionsIntfStruct)
                        else
                          Handle_Calling_Convention(lReadProcDef,cHCCDefaultActionsIntf);
                      end;
                    lProperty.Add_Getter_Or_Setter_For_Sym(palt_read,lSym,lAccessDef,lReadProcDef);
                  end;
               end
             else
               lProperty.Inherit_Accessor(palt_read);
             if TryToConsume(_WRITE) then
               begin
                 lGotReadOrWrite:=true;
                 lProperty.PropAccessList[palt_write].clear;
                 if ParseSymList(lProperty.PropAccessList[palt_write],lAccessDef) then
                  begin
                    lSym:=lProperty.PropAccessList[palt_write].FirstSym^.sym;
                    if lSym.typ=ProcSym then
                      begin
                        { setter is a procedure with an extra value parameter
                          of the of the property }
                        lWriteProcDef.ReturnDef:=VoidType;
                        inc(lParaNr);
                        lParaVarSym:=CParaVarSym.Create('$value',10*lParaNr,vs_value,lProperty.PropDef,[]);
                        lWriteProcDef.ParaST.InsertSym(lParaVarSym);
                        { Insert hidden parameters }
                        if not Assigned(AStruct) then
                          Handle_Calling_Convention(lWriteProcDef,cHCCDefaultActionsIntf)
                        else
                          Handle_Calling_Convention(lWriteProcDef,cHCCDefaultActionsIntfStruct);
                      end;
                    lProperty.Add_Getter_Or_Setter_For_Sym(palt_write,lSym,lAccessDef,lWriteProcDef);
                  end;
               end
             else
               lProperty.Inherit_Accessor(palt_write);
             { a new property (needs to declare a getter or setter, except in
               an interface }
             if not(ppo_overrides in lProperty.PropOptions) and
                not Is_Interface(AStruct) and
                not lGotReadOrWrite then
               Consume(_READ);
           end
         else
           ParseDispInterface(lProperty,lReadProcDef,lWriteProcDef,lParaNr);

         { stored is not allowed for dispinterfaces, records or class properties }
         if Assigned(AStruct) and not(Is_DispInterface(AStruct) or Is_Record(AStruct)) and not AIsClassProperty then
           begin
             { ppo_stored is default on for not overridden properties }
             if not Assigned(lProperty.OverriddenPropSym) then
               include(lProperty.PropOptions,ppo_stored);
             if TryToConsume(_STORED) then
              begin
                include(lProperty.PropOptions,ppo_stored);
                lProperty.PropAccessList[palt_stored].clear;
                if CurrentScanner.FToken=_ID then
                  begin
                    { in the case that idtoken=_DEFAULT }
                    { we have to do nothing except      }
                    { setting ppo_stored, it's the same }
                    { as stored true                    }
                    if CurrentScanner.FIDToken<>_DEFAULT then
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
                       lSym:=nil;
                       if (not Assigned(AStruct) or
                           (Search_Struct_Member(AStruct,CurrentScanner.FPattern)=nil)) and
                          SearchSym(CurrentScanner.FPattern,lSym,lSearchSymTable) and
                          (lSym.typ = constsym) then
                         begin
                            AddSymRef(lSym);
                            if not Is_Boolean(TConstSym(lSym).ConstDef) then
                              Message(parser_e_stored_property_must_be_boolean)
                            else if (TConstSym(lSym).Value.ValueOrd=0) then
                              { same as for _FALSE }
                              exclude(lProperty.PropOptions,ppo_stored)
                            else
                              begin
                                { same as for _TRUE }
                                { do nothing - ppo_stored is already set to p.propoptions in "include(p.propoptions,ppo_stored);" above }
                                { especially do not reset the default value - the stored specifier is independent on the default value! }
                              end;
                            Consume(_ID);
                          end
                       else if ParseSymList(lProperty.PropAccessList[palt_stored],lAccessDef) then
                        begin
                          lSym:=lProperty.PropAccessList[palt_stored].FirstSym^.sym;
                          case lSym.typ of
                            ProcSym :
                              begin
                                 { Create a temporary procvardef to handle parameters }
                                 lStoredProcDef:=CProcVarDef.Create(NormalFunctionLevel,true);
                                 include(lStoredProcDef.ProcOptions,po_methodpointer);
                                 { Return type must be boolean }
                                 lStoredProcDef.ReturnDef:=PasBool1Type;
                                 { Add index parameter if needed }
                                 if ppo_indexed in lProperty.PropOptions then
                                   begin
                                     lParaVarSym:=CParaVarSym.Create('$index',10,vs_value,lProperty.IndexDef,[]);
                                     lStoredProcDef.ParaST.InsertSym(lParaVarSym);
                                   end;

                                 { Insert hidden parameters }
                                 if not Assigned(AStruct) then
                                   Handle_Calling_Convention(lStoredProcDef,cHCCDefaultActionsIntf)
                                 else
                                   Handle_Calling_Convention(lStoredProcDef,cHCCDefaultActionsIntfStruct);
                                 lProperty.PropAccessList[palt_stored].procdef:=TProcSym(lSym).Find_ProcDef_ByPara(lStoredProcDef.paras,lStoredProcDef.ReturnDef,[cpo_allowdefaults,cpo_ignorehidden]);
                                 if not Assigned(lProperty.PropAccessList[palt_stored].procdef) then
                                   message(parser_e_ill_property_storage_sym);
                                 { Not needed anymore }
                                 lStoredProcDef.owner.DeleteDef(lStoredProcDef);
                              end;
                            FieldVarSym :
                              begin
                                if not Assigned(lAccessDef) then
                                  InternalError(200310073);
                                if (ppo_hasparameters in lProperty.PropOptions) or
                                   not(Is_Boolean(lAccessDef)) then
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
         if HasImplicitDefault(lProperty) and not Assigned(lProperty.OverriddenPropSym) then
           begin
              lProperty.default:=0;
           end;
         if not Is_Record(AStruct) and TryToConsume(_DEFAULT) then
           begin
              if not AllowDefaultProperty(lProperty) then
                begin
                  Message(parser_e_property_cant_have_a_default_value);
                  { Error recovery }
                  lNode:=CompExpr([efAcceptEqual]);
                  lNode.free;
                  lNode := nil;
                end
              else
                begin
                  { Get the result of the default, the firstpass is
                    needed to support values like -1 }
                  lNode:=CompExpr([efAcceptEqual]);
                  if (lProperty.PropDef.typ=setdef) and
                     (lNode.nodetype=arrayconstructorn) then
                    begin
                      ArrayConstructor_To_Set(lNode);
                      DoTypeCheckPass(lNode);
                    end;
                  InsertTypeConv(lNode,lProperty.PropDef);
                  if not(Is_ConstNode(lNode)) then
                    Message(parser_e_property_default_value_must_const);
                  { Set default value }
                  case lNode.nodetype of
                    setconstn :
                      begin
                        lProperty.default:=PLongInt(TSetConstNode(lNode).ValueSet)^;
                        include(lProperty.PropOptions,ppo_default_is_set);
                      end;
                    ordconstn :
                      if Is_Real(lProperty.PropDef) then
                        begin
                          if TOrdConstNode(lNode).Value.Is_Negative then
                            lSingleValue:=TOrdConstNode(lNode).Value.svalue
                          else
                            lSingleValue:=TOrdConstNode(lNode).Value.uvalue;
                          lProperty.default:=PLongInt(@lSingleValue)^;
                          include(lProperty.PropOptions,ppo_default_is_single);
                        end
                      else if (TOrdConstNode(lNode).Value<Int64(low(LongInt))) or
                         (TOrdConstNode(lNode).Value>Int64(high(cardinal))) then
                        message3(type_e_range_check_error_bounds,ToStr(TOrdConstNode(lNode).Value),ToStr(low(LongInt)),ToStr(high(cardinal)))
                      else
                        lProperty.default:=LongInt(TOrdConstNode(lNode).Value.svalue);
                    niln :
                      lProperty.default:=0;
                    realconstn:
                      begin
                        lSingleValue:=Single(TRealConstNode(lNode).ValueReal);
                        lProperty.default:=PLongInt(@lSingleValue)^;
                        include(lProperty.PropOptions,ppo_default_is_single);
                      end;
                    else if not CodeGenError then
                      InternalError(2019050525);
                  end;
                  lNode.free;
                  lNode := nil;
                end;
           end
         else if not Is_Record(AStruct) and TryToConsume(_NODEFAULT) then
           begin
              lProperty.default:=LongInt($80000000);
           end;
(*
         else {if allow_default_property(p) then
           begin
              p.default:=longint($80000000);
           end;
*)
         { Parse possible "implements" keyword }
         if not Is_Record(AStruct) and TryToConsume(_IMPLEMENTS) then
           repeat
             SingleType(lAccessDef,[]);

             if not(Is_Interface(lAccessDef)) then
               message(parser_e_class_implements_must_be_interface);

             if Is_Interface(lProperty.PropDef) then
               begin
                 { an interface type may delegate itself or one of its ancestors }
                 if not Def_Is_Related(lProperty.PropDef,lAccessDef) then
                   begin
                     message2(parser_e_implements_must_have_correct_type,lAccessDef.TypeName,lProperty.PropDef.TypeName);
                     exit;
                   end;
               end
             else if Is_Class(lProperty.PropDef) then
               begin
                 lImplIntf:=Find_Implemented_Interface(TObjectDef(lProperty.PropDef),TObjectDef(lAccessDef));
                 if Assigned(lImplIntf) then
                   begin
                     if Compare_Defs(lImplIntf.IntfDef,lAccessDef,nothingn)<te_equal then
                       begin
                         message2(parser_e_implements_must_have_correct_type,lImplIntf.IntfDef.TypeName,lAccessDef.TypeName);
                         exit;
                       end;
                   end
                 else
                   begin
                     message2(parser_e_class_doesnt_implement_interface,lProperty.PropDef.TypeName,lAccessDef.TypeName);
                     exit;
                   end;
               end
             else
               begin
                 message(parser_e_implements_must_be_class_or_interface);
                 exit;
               end;


             if not Assigned(lProperty.PropAccessList[palt_read].FirstSym) then
               begin
                 message(parser_e_implements_must_read_specifier);
                 exit;
               end;
             if Assigned(lProperty.PropAccessList[palt_read].procdef) and
                (TProcDef(lProperty.PropAccessList[palt_read].procdef).ProcCallOption<>pocall_default) then
               message(parser_e_implements_getter_not_default_cc);
             if Assigned(lProperty.PropAccessList[palt_write].FirstSym) then
               begin
                 message(parser_e_implements_must_not_have_write_specifier);
                 exit;
               end;
             if Assigned(lProperty.PropAccessList[palt_stored].FirstSym) then
               begin
                 message(parser_e_implements_must_not_have_stored_specifier);
                 exit;
               end;
             lFound:=false;
             lImplIntf:=nil;
             for lIndex:=0 to TObjectDef(AStruct).ImplementedInterfaces.Count-1 do
               begin
                 lImplIntf:=TImplementedInterface(TObjectDef(AStruct).ImplementedInterfaces[lIndex]);

                 if Compare_Defs(lAccessDef,lImplIntf.IntfDef,nothingn)>=te_equal then
                   begin
                     lFound:=true;
                     break;
                   end;
               end;
             if lFound then
               begin
                 { An interface may not be delegated by more than one property,
                   it also may not have method mappings. }
                 if Assigned(lImplIntf.ImplementsGetter) then
                   message1(parser_e_duplicate_implements_clause,lImplIntf.IntfDef.TypeName);
                 if Assigned(lImplIntf.NameMappings) then
                   message2(parser_e_mapping_no_implements,lImplIntf.IntfDef.TypeName,AStruct.ObjRealName^);

                 lImplIntf.ImplementsGetter:=lProperty;
                 lImplIntf.VtblImplIntf:=lImplIntf;
                 case lProperty.PropAccessList[palt_read].FirstSym^.sym.typ of
                   ProcSym :
                     begin
                       if (po_virtualmethod in TProcDef(lProperty.PropAccessList[palt_read].procdef).ProcOptions) and
                           not Is_ObjectPascal_Helper(TProcDef(lProperty.PropAccessList[palt_read].procdef).struct) then
                         lImplIntf.IType:=etVirtualMethodResult
                       else
                         lImplIntf.IType:=etStaticMethodResult;
                     end;
                   FieldVarSym :
                     begin
                       lImplIntf.IType:=etFieldValue;
                       { this must be done in a more robust way. Can't read the
                         fieldvarsym's fieldoffset yet, because it may not yet
                         be set }
                       lImplIntf.ImplementsField:=lProperty.PropAccessList[palt_read].FirstSym^.sym;
                     end
                   else
                     InternalError(200802161);
                 end;
                 if not Is_Interface(lProperty.PropDef) then
                   case lImplIntf.IType of
                     etVirtualMethodResult: lImplIntf.IType := etVirtualMethodClass;
                     etStaticMethodResult:  lImplIntf.IType := etStaticMethodClass;
                     etFieldValue:          lImplIntf.IType := etFieldValueClass;
                   else
                     InternalError(200912101);
                   end;
               end
             else
               message1(parser_e_implements_uses_non_implemented_interface,lAccessDef.TypeName);
           until not TryToConsume(_COMMA);

         { register propgetter and propsetter procdefs }
         if Assigned(CurrentModule) and CurrentModule.InInterface then
           begin
             if lReadProcDef.ProcTypeOption=potype_propgetter then
               lReadProcDef.RegisterDef
             else
               lReadProcDef.free; // no nil needed
             if lWriteProcDef.ProcTypeOption=potype_propsetter then
               lWriteProcDef.RegisterDef
             else
               lWriteProcDef.free; // no nil needed
           end
         else
           begin
             if lReadProcDef.ProcTypeOption=potype_propgetter then
               lReadProcDef.Maybe_Put_In_SymTable_Stack
             else
               lReadProcDef.free; // no nil needed
             if lWriteProcDef.ProcTypeOption=potype_propsetter then
               lWriteProcDef.Maybe_Put_In_SymTable_Stack
             else
               lWriteProcDef.free; // no nil needed
           end;

         Result:=lProperty;
      end;


     function MaybeParseProcDirectives(ADef:TDef):Boolean;
       begin
         Result:=false;
         { Process procvar directives before = and ; }
         if (
              (ADef.typ=procvardef) or
              Is_FuncRef(ADef)
            ) and
            (ADef.TypeSym=nil) and
            CheckProcDirective(true) then
           begin
              ParseProcTypeDirectives(ADef);
              Result:=true;
           end;
       end;


    var
       VariantRecordLevel : LongInt = 0;


    procedure ReadPublicAndExternalSC(ASymbols:TFPObjectList);
    var
      lVarSym: TAbstractVarSym;
    begin
      { only allowed for one var }
      lVarSym:=TAbstractVarSym(ASymbols[0]);
      if ASymbols.count>1 then
        Message1(parser_e_directive_only_one_var,arraytokeninfo[CurrentScanner.FIDToken].str);
      ReadPublicAndExternal(lVarSym);
    end;


    procedure ReadPublicAndExternal(AVarSym: TAbstractVarSym);
    var
      lIsDLL,
      lIsCDecl,
      lIsExternalVar,
      lIsWeakExternal,
      lIsPublicVar  : Boolean;
      lDLLName,lSectionName,
      lCName,lMangledName      : String;
    begin
      { only allowed for one var }
      { only allow external and public on global symbols }
      if AVarSym.typ<>staticvarsym then
        begin
          Message(parser_e_no_local_var_external);
          exit;
        end;
      { defaults }
      lIsDLL:=false;
      lIsCDecl:=false;
      lIsExternalVar:=false;
      lIsPublicVar:=false;
      lSectionName := '';
      lDLLName := '';
      lCName:=AVarSym.realname;

      { macpas specific handling due to some switches}
      if (m_mac in CurrentSettings.ModeSwitches) then
        begin
          if (cs_external_var in CurrentSettings.LocalSwitches) then
            begin {The effect of this is the same as if cvar; external; has been given as directives.}
              lIsCDecl:=true;
              lIsExternalVar:=true;
            end
          else if (cs_externally_visible in CurrentSettings.LocalSwitches) then
            begin {The effect of this is the same as if cvar has been given as directives and it's made public.}
              lIsCDecl:=true;
              lIsPublicVar:=true;
            end;
        end;

      { cdecl }
      if TryToConsume(_CVAR) then
        begin
          Consume(_SEMICOLON);
          lIsCDecl:=true;
        end;

      { external }
      lIsWeakExternal:=TryToConsume(_WEAKEXTERNAL);
      if lIsWeakExternal or
         TryToConsume(_EXTERNAL) then
        begin
          lIsExternalVar:=true;
          if (CurrentScanner.FIDToken<>_NAME) and (CurrentScanner.FToken<>_SEMICOLON) then
            begin
              lIsDLL:=true;
              lDLLName:=GetStringConst;
              if ExtractFileExt(lDLLName)='' then
                lDLLName:=ChangeFileExt(lDLLName,TargetInfo.sharedlibext);
            end;
          if not(lIsCDecl) and TryToConsume(_NAME) then
            lCName:=GetStringConst;
          Consume(_SEMICOLON);
        end;

      { export or public }
      if CurrentScanner.FIDToken in [_EXPORT,_PUBLIC] then
        begin
          Consume(_ID);
          if lIsExternalVar then
            Message(parser_e_not_external_and_export)
          else
            lIsPublicVar:=true;
          if TryToConsume(_NAME) then
            lCName:=GetStringConst;
{$ifndef DISABLE_TLS_DIRECTORY}
          if (TargetInfo.system in systems_windows) and
             (AVarSym.typ=staticvarsym) and
             TryToConsume (_SECTION) then
            lSectionName:=GetStringConst;
{$endif not DISABLE_TLS_DIRECTORY}
          Consume(_SEMICOLON);
        end;

      { Windows uses an indirect reference using import tables }
      if lIsDLL and
         (TargetInfo.system in systems_all_windows) then
        include(AVarSym.VarOptions,vo_is_dll_var);

      { This can only happen if vs.typ=staticvarsym }
      if lSectionName<>'' then
        begin
          TStaticVarSym(AVarSym).section:=lSectionName;
          include(AVarSym.VarOptions,vo_has_section);
        end;


      { Add C _ prefix }
      if lIsCDecl or
         (
          lIsDLL and
          (TargetInfo.system in systems_darwin)
         ) then
        lCName := TargetInfo.Cprefix+lCName;

      if lIsPublicVar then
        begin
          include(AVarSym.VarOptions,vo_is_public);
          AVarSym.VarRegable := vr_none;
          { mark as referenced }
          inc(AVarSym.refs);
        end;

      lMangledName:=lCName;
      { now we can insert it in the import lib if its a dll, or
        add it to the externals }
      if lIsExternalVar then
        begin
          if vo_is_typed_const in AVarSym.VarOptions then
            Message(parser_e_initialized_not_for_external);
          include(AVarSym.VarOptions,vo_is_external);
          if (lIsWeakExternal) then
            begin
              if not(TargetInfo.system in systems_weak_linking) then
                message(parser_e_weak_external_not_supported);
              include(AVarSym.VarOptions,vo_is_weak_external);
            end;
          AVarSym.VarRegable := vr_none;
          if lIsDLL then
            begin
              if TargetInfo.system in systems_all_windows then
                lMangledName:=Make_DLLMangledName(lDLLName,lCName,0,pocall_none);

              CurrentModule.AddExternalImport(lDLLName,lCName,lMangledName,0,true,false);
            end
          else
            if tf_has_dllscanner in TargetInfo.flags then
              CurrentModule.DLLScannerInputList.Add(AVarSym.MangledName,AVarSym);
        end;

      { Set the assembler name }
      TStaticVarSym(AVarSym).Set_MangledBaseName(lMangledName);
      TStaticVarSym(AVarSym).Set_MangledName(lMangledName);
    end;


    procedure TryConsumeSectionDirective(var ASection: AnsiString);
      begin
        if CurrentScanner.FIDToken=_SECTION then
          begin
            Consume(_ID);
            ASection:=GetStringConst;
            Consume(_SEMICOLON);
          end;
      end;


    procedure ReadVarDecls(AOptions:TVarDecOptions;out AHadGeneric:Boolean);

        procedure ReadDefaultValue(ASymbols : TFPObjectList);
        var
          lVarSym : TAbstractNormalVarSym;
          lConstSym : TStaticVarSym;
          lTempList : TAsmList;
        begin
          lVarSym:=TAbstractNormalVarSym(ASymbols[0]);
          if ASymbols.count>1 then
            Message(parser_e_initialized_only_one_var);
          if vo_is_thread_var in lVarSym.VarOptions then
            Message(parser_e_initialized_not_for_threadvar);
          Consume(_EQ);
          case lVarSym.typ of
            localvarsym :
              begin
                lConstSym:=CStaticVarSym.Create('$default'+lVarSym.realname,vs_const,lVarSym.vardef,[]);
                include(lConstSym.SymOptions,sp_internal);
                SymTableStack.top.InsertSym(lConstSym);
                lTempList:=TAsmList.Create;
                ReadTypedConst(lTempList,lConstSym,false);
                { in case of a generic routine, this initialisation value is not
                  used, and will be re-parsed during specialisations (and the
                  current version is not type-correct and hence breaks code
                  generation for LLVM) }
                if not ParseGeneric then
                  begin
                    lVarSym.DefaultConstSym:=lConstSym;
                    CurrentAsmData.asmlists[al_typedconsts].ConcatList(lTempList);
                  end;
                lTempList.free;
                lTempList := nil;
              end;
            staticvarsym :
              begin
                ReadTypedConst(CurrentAsmData.asmlists[al_typedconsts],TStaticVarSym(lVarSym),false);
              end;
            else
              InternalError(200611051);
          end;
          lVarSym.VarState:=vs_initialised;
        end;

        procedure ReadAbsolute(ASymbols : TFPObjectList);
        var
          lVarSym     : TAbstractVarSym;
          lAbsoluteSym : TAbsoluteVarSym;
          lNode,lBaseNode  : TNode;
          lSymTable     : TSymTable;
        begin
          lAbsoluteSym:=nil;
          { only allowed for one var }
          lVarSym:=TAbstractVarSym(ASymbols[0]);
          if ASymbols.count>1 then
            Message1(parser_e_directive_only_one_var,'ABSOLUTE');
          if vo_is_typed_const in lVarSym.VarOptions then
            Message(parser_e_initialized_not_for_external);
          { parse the rest }
          lNode:=Expr(true);
          { check allowed absolute types }
          if (lNode.nodetype=stringconstn) or
            (Is_ConstCharNode(lNode)) then
            begin
              lAbsoluteSym:=CAbsoluteVarSym.Create(lVarSym.realname,lVarSym.vardef);
              lAbsoluteSym.fileinfo:=lVarSym.fileinfo;
              if lNode.nodetype=stringconstn then
                lAbsoluteSym.AsmName:=StringDup(TStringConstNode(lNode).AsRawByteString)
              else
                lAbsoluteSym.AsmName:=StringDup(chr(TOrdConstNode(lNode).Value.svalue));
              lAbsoluteSym.AbsTyp:=toasm;
            end
          { address }
          else if Is_ConstIntNode(lNode) then
            begin
              lAbsoluteSym:=CAbsoluteVarSym.Create(lVarSym.realname,lVarSym.vardef);
              lAbsoluteSym.fileinfo:=lVarSym.fileinfo;
              lAbsoluteSym.AbsTyp:=toaddr;
{$ifndef cpu64bitaddr}
              { on 64 bit systems, abssym.addroffset is a qword and hence this
                test is useless (value is a 64 bit entity) and will always fail
                for positive values (since int64(high(abssym.addroffset))=-1
              }
              if (TOrdConstNode(lNode).Value<Int64(low(lAbsoluteSym.AddrOffset))) or
                 (TOrdConstNode(lNode).Value>Int64(high(lAbsoluteSym.AddrOffset))) then
                message3(type_e_range_check_error_bounds,ToStr(TOrdConstNode(lNode).Value),ToStr(low(lAbsoluteSym.AddrOffset)),ToStr(high(lAbsoluteSym.AddrOffset)))
             else
{$endif}
                lAbsoluteSym.AddrOffset:=TOrdConstNode(lNode).Value.svalue;
{$if defined(i386)}
              TCPUAbsoluteVarSym(lAbsoluteSym).AbsSeg:=false;
{$endif i386}
            end
          { variable }
          else
            begin
              { we have to be able to take the address of the absolute
                expression
              }
              Valid_For_Addr(lNode,true);
              { remove subscriptn before checking for loadn }
              lBaseNode:=lNode;
              while (lBaseNode.nodetype in [subscriptn,typeconvn,vecn]) do
                begin
                  { check for implicit dereferencing and reject it }
                  if (lBaseNode.nodetype in [subscriptn,vecn]) then
                    begin
                      if (TUnaryNode(lBaseNode).left.resultdef.typ in [pointerdef,classrefdef]) then
                        break;
                      { catch, e.g., 'var b: char absolute pchar_var[5];"
                        (pchar_var[5] is a pchar_2_string typeconv ->
                         the vecn only sees an array of char)
                        I don't know if all of these type conversions are
                        possible, but they're definitely all bad.
                      }
                      if (TUnaryNode(lBaseNode).left.nodetype=typeconvn) and
                         (TTypeConvNode(TUnaryNode(lBaseNode).left).ConvType in
                           [tc_pchar_2_string,tc_pointer_2_array,
                            tc_intf_2_string,tc_intf_2_guid,
                            tc_dynarray_2_variant,tc_interface_2_variant,
                            tc_array_2_dynarray]) then
                        break;

                      if (TUnaryNode(lBaseNode).left.resultdef.typ=stringdef) and
                         not(TStringDef(TUnaryNode(lBaseNode).left.resultdef).StringType in [st_shortstring,st_longstring]) then
                        break;
                      if (TUnaryNode(lBaseNode).left.resultdef.typ=objectdef) and
                         (TObjectDef(TUnaryNode(lBaseNode).left.resultdef).ObjectType<>odt_object) then
                        break;
                      if Is_Dynamic_Array(TUnaryNode(lBaseNode).left.resultdef) then
                        break;
                    end;
                  lBaseNode:=TUnaryNode(lBaseNode).left;
                end;
              if (lBaseNode.nodetype=loadn) then
                begin
                  { we should check the result type of loadn }
                  if not (TLoadNode(lBaseNode).SymTableEntry.typ in [FieldVarSym,staticvarsym,localvarsym,paravarsym,absolutevarsym]) then
                    Message(parser_e_absolute_only_to_var_or_const);
                  if lVarSym=TLoadNode(lBaseNode).SymTableEntry then
                    Message(parser_e_absolute_sym_cannot_reference_itself)
                  else
                    begin
                      lAbsoluteSym:=CAbsoluteVarSym.Create(lVarSym.realname,lVarSym.vardef);
                      lAbsoluteSym.fileinfo:=lVarSym.fileinfo;
                      lAbsoluteSym.AbsTyp:=tovar;
                      lAbsoluteSym.Ref:=Node_To_PropAccessList(lNode);
                      { if the sizes are different, can't be a regvar since you }
                      { can't be "absolute upper 8 bits of a register" (except  }
                      { if its a record field of the same size of a record      }
                      { regvar, but in that case pt.resultdef.size will have    }
                      { the same size since it refers to the field and not to   }
                      { the whole record -- which is why we use pt and not hp)  }

                      { we can't take the size of an open array or an array of const }
                      if Is_Open_Array(lNode.resultdef) or
                         Is_Array_Of_Const(lNode.resultdef) or
                         (lVarSym.vardef.Size <> lNode.resultdef.Size) then
                        Make_Not_Regable(lNode,[ra_addr_regable]);
                      TAbsoluteVarSym(lAbsoluteSym).Adjust_VarRegable;
                    end;
                end
              else
                Message(parser_e_absolute_only_to_var_or_const);
            end;
          lNode.free;
          lNode := nil;
          { replace old varsym with the new absolutevarsym }
          if Assigned(lAbsoluteSym) then
            begin
              lSymTable:=lVarSym.owner;
              lVarSym.owner.DeleteSym(lVarSym);
              lSymTable.InsertSym(lAbsoluteSym);
              ASymbols[0]:=lAbsoluteSym;
            end;
        end;

      var
         lSymbols   : TFPObjectList;
         lVarSym   : TAbstractVarSym;
         lDef : TDef;
         lIndex    : LongInt;
         lFlags : THCCFlags;
         lFirst,
         lIsGeneric,
         lSemicolonEaten,
         lAllowDefaultValue,
         lHasDefaultValue : Boolean;
         lHintSymOptions  : TSymOptions;
         lDeprecatedMsg   : PShortString;
         lOldBlockType  : TBlockType;
         lTypePos,
         lTempFilePos,
         lOldCurrentFilePos     : TFilePosInfo;
      begin
         lOldBlockType:=Block_Type;
         Block_Type:=bt_var;
         { Force an expected ID error message }
         if not (CurrentScanner.FToken in [_ID,_CASE,_END]) then
           Consume(_ID);
         { read vars }
         lSymbols:=TFPObjectList.Create(false);
         lFirst:=true;
         AHadGeneric:=false;
         lVarSym:=nil;
         fillchar(lTempFilePos,sizeof(lTempFilePos),0);
         while (CurrentScanner.FToken=_ID) do
           begin
             lSemicolonEaten:=false;
             lHasDefaultValue:=false;
             lAllowDefaultValue:=true;
             lSymbols.clear;
             repeat
               if (CurrentScanner.FToken = _ID) then
                 begin
                   lIsGeneric:=(vdCheckGeneric in AOptions) and
                                not (m_delphi in CurrentSettings.ModeSwitches) and
                                (CurrentScanner.FIDToken=_GENERIC);
                   case SymTableStack.top.SymTableType of
                     LocalSymTable :
                       lVarSym:=CLocalVarSym.Create(CurrentScanner.FOrgPattern,vs_value,GenErrorDef,[]);
                     staticsymtable,
                     GlobalSymTable :
                       begin
                         lVarSym:=CStaticVarSym.Create(CurrentScanner.FOrgPattern,vs_value,GenErrorDef,[]);
                         if vdThreadVar in AOptions then
                           include(lVarSym.VarOptions,vo_is_thread_var);
                       end;
                     else
                       InternalError(200411064);
                   end;
                   lSymbols.add(lVarSym);
                   if lIsGeneric then
                     lTempFilePos:=CurrentFilePos;
                 end
               else
                 lIsGeneric:=false;
               Consume(_ID);
               { when the first variable had been read the next declaration could be
                 a "generic procedure", "generic function" or
                 "generic class (function/procedure)" }
               if not lFirst
                   and lIsGeneric
                   and (lSymbols.count=1)
                   and (CurrentScanner.FToken in [_PROCEDURE,_FUNCTION,_CLASS]) then
                 begin
                   lVarSym.free;
                   lVarSym := nil;
                   lSymbols.clear;
                   AHadGeneric:=true;
                   break;
                 end
               else
                 begin
                   lVarSym.RegisterSym;
                   if lIsGeneric then
                     begin
                       { ensure correct error position }
                       lOldCurrentFilePos:=CurrentFilePos;
                       CurrentFilePos:=lTempFilePos;
                       SymTableStack.top.InsertSym(lVarSym);
                       CurrentFilePos:=lOldCurrentFilePos;
                     end
                   else
                     SymTableStack.top.InsertSym(lVarSym);
                 end;
             until not TryToConsume(_COMMA);

             if AHadGeneric then
               break;

             { read variable type def }
             Block_Type:=bt_var_type;
             Consume(_COLON);
             lTypePos:=CurrentTokenPos;

             ReadAnonType(lDef,false,nil);
             for lIndex:=0 to lSymbols.count-1 do
               begin
                 lVarSym:=TAbstractVarSym(lSymbols[lIndex]);
                 lVarSym.vardef:=lDef;
               end;
             Block_Type:=bt_var;

             { Process procvar directives }
             if MaybeParseProcDirectives(lDef) then
               lSemicolonEaten:=true;

             { check for absolute }
             if TryToConsume(_ABSOLUTE) then
               begin
                 ReadAbsolute(lSymbols);
                 lAllowDefaultValue:=false;
               end;

             { Check for EXTERNAL etc directives before a semicolon }
             if (CurrentScanner.FIDToken in [_EXPORT,_EXTERNAL,_PUBLIC,_CVAR]) or (CurrentScanner.FIDToken = _WEAKEXTERNAL) then
               begin
                 ReadPublicAndExternalSC(lSymbols);
                 lAllowDefaultValue:=false;
                 lSemicolonEaten:=true;
               end;

             { try to parse the hint directives }
             lHintSymOptions:=[];
             lDeprecatedMsg:=nil;
             TryConsumeHintDirective(lHintSymOptions,lDeprecatedMsg);
             for lIndex:=0 to lSymbols.count-1 do
               begin
                 lVarSym:=TAbstractVarSym(lSymbols[lIndex]);
                 lVarSym.SymOptions := lVarSym.SymOptions + lHintSymOptions;
                 if lDeprecatedMsg<>nil then
                   lVarSym.DeprecatedMsg:=StringDup(lDeprecatedMsg^);
               end;
             StringDispose(lDeprecatedMsg);

             { Handling of Delphi typed const = initialized vars }
             if lAllowDefaultValue and
                (CurrentScanner.FToken=_EQ) and
                (SymTableStack.top.SymTableType<>parasymtable) then
               begin
                 { Add calling convention for procvar }
                 if (
                      (lDef.typ=procvardef) or
                      Is_FuncRef(lDef)
                    ) and
                    (lDef.TypeSym=nil) then
                   begin
                     if po_is_function_ref in TProcVarDef(lDef).ProcOptions then
                       begin
                         if not (m_function_references in CurrentSettings.ModeSwitches) and
                             not (po_is_block in TProcVarDef(lDef).ProcOptions) then
                           messagepos(lTypePos,sym_e_error_in_type_def)
                         else
                           begin
                             if Adjust_FuncRef(lDef,nil,nil) then
                               { the def was changed, so update it }
                               for lIndex:=0 to lSymbols.count-1 do
                                 begin
                                   lVarSym:=TAbstractVarSym(lSymbols[lIndex]);
                                   lVarSym.vardef:=lDef;
                                 end;
                             if CurrentScanner.ReplayStackDepth=0 then
                               lDef.RegisterDef;
                           end;
                       end;
                     Handle_Calling_Convention(lDef,cHCCDefaultActionsIntf);
                   end;
                 ReadDefaultValue(lSymbols);
                 lHasDefaultValue:=true;
               end
             else
               begin
                 if not(lSemicolonEaten) then
                   Consume(_SEMICOLON);
               end;

             { Support calling convention for procvars after semicolon }
             if not(lHasDefaultValue) and
                (
                  (lDef.typ=procvardef) or
                  Is_FuncRef(lDef)
                ) and
                (lDef.TypeSym=nil) then
               begin
                 { Parse procvar directives after ; }
                 MaybeParseProcDirectives(lDef);
                 if (lDef.typ=procvardef) and (po_is_function_ref in TProcVarDef(lDef).ProcOptions) then
                   begin
                     if not (m_function_references in CurrentSettings.ModeSwitches) and
                         not (po_is_block in TProcVarDef(lDef).ProcOptions) then
                       messagepos(lTypePos,sym_e_error_in_type_def)
                     else
                       begin
                         if Adjust_FuncRef(lDef,nil,nil) then
                           { the def was changed, so update it }
                           for lIndex:=0 to lSymbols.count-1 do
                             begin
                               lVarSym:=TAbstractVarSym(lSymbols[lIndex]);
                               lVarSym.vardef:=lDef;
                             end;
                         if CurrentScanner.ReplayStackDepth=0 then
                           lDef.RegisterDef;
                       end;
                   end;
                 { Add calling convention for procvar }
                 if lDef.typ=procvardef then
                   lFlags:=cHCCDefaultActionsIntf
                 else
                   lFlags:=cHCCDefaultActionsIntfStruct;
                 Handle_Calling_Convention(lDef,lFlags);
                 { Handling of Delphi typed const = initialized vars }
                 if (CurrentScanner.FToken=_EQ) and
                    (SymTableStack.top.SymTableType<>parasymtable) then
                   begin
                     ReadDefaultValue(lSymbols);
                     lHasDefaultValue:=true;
                   end;
               end;

             { Check for EXTERNAL etc directives or, in macpas, if cs_external_var is set}
             if (
                 (
                  ((CurrentScanner.FIDToken in [_EXPORT,_EXTERNAL,_PUBLIC,_CVAR]) or (CurrentScanner.FIDToken = _WEAKEXTERNAL)) and
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
               ReadPublicAndExternalSC(lSymbols);

             { allocate normal variable (non-external and non-typed-const) staticvarsyms }
             for lIndex:=0 to lSymbols.count-1 do
               begin
                 lVarSym:=TAbstractVarSym(lSymbols[lIndex]);
                 if (lVarSym.typ=staticvarsym) and
                    not(vo_is_typed_const in lVarSym.VarOptions) and
                    not(vo_is_external in lVarSym.VarOptions) then
                   CNodeUtils.InsertBSSData(TStaticVarSym(lVarSym));
                 if vo_is_public in lVarSym.VarOptions then
                   CurrentModule.Add_Public_AsmSym(lVarSym.MangledName,AB_GLOBAL,AT_DATA);
               end;

             lFirst:=false;
           end;
         Block_Type:=lOldBlockType;
         { free the list }
         lSymbols.free;
         lSymbols := nil;
      end;


    function CheckAllowedForVarOrConst(ADef:TDef;AAllowDynArray:Boolean):Boolean;
      var
        lOwnerDef,lTempDef : TDef;
        lSymTable : TSymTable;
      begin
        Result:=true;
        lSymTable:=SymTableStack.top;
        if not (lSymTable.SymTableType in [recordsymtable,objectsymtable]) then
          exit;
        lOwnerDef:=TDef(lSymTable.DefOwner);
        while Assigned(lOwnerDef) and (lOwnerDef.typ in [objectdef,recorddef]) do
          begin
            if ADef.typ=arraydef then
              begin
                lTempDef:=ADef;
                while (lTempDef.typ=arraydef) do
                  begin
                    { dynamic arrays are allowed in certain cases }
                    if AAllowDynArray and (ado_IsDynamicArray in TArrayDef(lTempDef).ArrayOptions) then
                      begin
                        lTempDef:=nil;
                        break;
                      end;
                    lTempDef:=TArrayDef(lTempDef).ElementDef;
                  end;
              end
            else
              lTempDef:=ADef;
            if Assigned(lTempDef) and
                (Is_Object(lTempDef) or Is_Record(lTempDef)) and
                Is_Owned_By(TAbstractRecordDef(lOwnerDef),TAbstractRecordDef(lTempDef)) then
              begin
                Message1(type_e_type_is_not_completly_defined,TAbstractRecordDef(lTempDef).RTTIName);
                Result:=false;
                break;
              end;
            lOwnerDef:=TDef(lOwnerDef.owner.DefOwner);
          end;
      end;


    procedure ReadRecordFields(AOptions:TVarDecOptions; AReorderList: TFPObjectList; AVariantDesc : PPVariantRecDesc;out AHadGeneric:Boolean; out AAttrElementCount : Integer);
      var
         lSymbols : TFPObjectList;
         lIndex  : LongInt;
         lName,lOrgName : String;
         lGenDef,lDef,lCaseType : TDef;
         { maxsize contains the max. size of a variant }
         { startvarrec contains the start of the variant part of a record }
         lMaxSize, lStartVarRecSize : ASizeInt;
         lUsedAlign,
         lMaxAlignment,lStartVarRecAlign,
         lMaxPadAlign, lStartPadAlign: ShortInt;
         lNode : TNode;
         lFieldVarSym   : TFieldVarSym;
         lStaticVarSym : TStaticVarSym;
         lVarSym    : TAbstractVarSym;
         lSearchSym : TSym;
         lSearchSymTable : TSymTable;
         lVisibility : TVisibility;
         lRecordSymTable : TAbstractRecordSymTable;
         lUnionSymTable : TRecordSymTable;
         lOffset : LongInt;
         lUnionDef : TRecordDef;
         lHintSymOptions : TSymOptions;
         lDeprecatedMsg : PShortString;
         lHadGenDummy,
         lSemicolonEaten,
         lRemoveClassOption: Boolean;
         lDummyAttrElementCount : Integer;
         lOldBlockType: TBlockType;
         lTypePos : TFilePosInfo;
      begin
         lOldBlockType:=Block_Type;
         Block_Type:=bt_var;
         lRecordSymTable:=TAbstractRecordSymTable(SymTableStack.top);
         { Force an expected ID error message }
         if not (CurrentScanner.FToken in [_ID,_CASE,_END]) then
           Consume(_ID);
         { read vars }
         lSymbols:=TFPObjectList.Create(false);
         lRemoveClassOption:=false;
         AHadGeneric:=false;
         AAttrElementCount:=0;
         while (CurrentScanner.FToken=_ID) and
            not(((vdObject in AOptions) or
                 ((vdRecord in AOptions) and (m_advanced_records in CurrentSettings.ModeSwitches))) and
                ((CurrentScanner.FIDToken in [_PUBLIC,_PRIVATE,_PUBLISHED,_PROTECTED,_STRICT]) or
                 ((m_final_fields in CurrentSettings.ModeSwitches) and
                  (CurrentScanner.FIDToken=_FINAL)))) do
           begin
             lVisibility:=SymTableStack.top.CurrentVisibility;
             lSemicolonEaten:=false;
             lSymbols.clear;
             repeat
               lOrgName:=CurrentScanner.FOrgPattern;
               if CurrentScanner.FToken=_ID then
                 begin
                   lVarSym:=CFieldVarSym.Create(lOrgName,vs_value,GenErrorDef,[]);

                   { normally the visibility is set via addfield, but sometimes
                     we collect symbols so we can add them in a batch of
                     potentially mixed visibility, and then the individual
                     symbols need to have their visibility already set }
                   lVarSym.visibility:=lVisibility;
                   if (vdCheckGeneric in AOptions) and (CurrentScanner.FIDToken=_GENERIC) then
                     AHadGeneric:=true;
                 end
               else
                 lVarSym:=nil;
               Consume(_ID);
               if Assigned(lVarSym) and
                  (
                    not AHadGeneric or
                    not (CurrentScanner.FToken in [_PROCEDURE,_FUNCTION,_CLASS])
                  ) then
                 begin
                   lVarSym.RegisterSym;
                   lSymbols.add(lVarSym);
                   lRecordSymTable.InsertSym(lVarSym);
                   AHadGeneric:=false;
                 end
               else
                 lVarSym.free; // no nil needed
             until not TryToConsume(_COMMA);
             if m_delphi in CurrentSettings.ModeSwitches then
               Block_Type:=bt_var_type
             else
               Block_Type:=lOldBlockType;
             if AHadGeneric and (lSymbols.count=0) then
               break;
             Consume(_COLON);
             if AAttrElementCount=0 then
               AAttrElementCount:=lSymbols.Count;

             lTypePos:=CurrentFilePos;

             { make sure that the correct genericdef is set up, especially if
               we're dealing with anonymous type declarations }
             lGenDef:=nil;
             if df_specialization in CurrentStructDef.DefOptions then
               begin
                 lSearchSymTable:=CurrentStructDef.GenericDef.GetSymTable(gs_record);
                 if not Assigned(lSearchSymTable) then
                   InternalError(2024041204);
                 lSearchSym:=TSym(lSearchSymTable.find(TAbstractVarSym(lSymbols[0]).name));
                 if not Assigned(lSearchSym) then
                   InternalError(2024041205);
                 if lSearchSym.typ<>FieldVarSym then
                   InternalError(2024041206);
                 lGenDef:=TFieldVarSym(lSearchSym).vardef;
               end;

             ReadAnonType(lDef,false,TStoredDef(lGenDef));
             Block_Type:=bt_var;
             { allow only static fields reference to struct where they are declared }
             if not (vdClass in AOptions) then
               begin
                 if not CheckAllowedForVarOrConst(lDef,true) then
                   { for error recovery or compiler will crash later }
                   lDef:=GenErrorDef;
               end;

             { field type is a generic param so set a flag in the struct }
             if Assigned(lDef.TypeSym) and (sp_generic_para in lDef.TypeSym.SymOptions) then
               include(CurrentStructDef.DefOptions,df_has_generic_fields);

             { Process procvar directives }
             if MaybeParseProcDirectives(lDef) then
               lSemicolonEaten:=true;


             { types that use init/final are not allowed in variant parts, but
               classes are allowed }
             if (VariantRecordLevel>0) then
               if Is_Managed_Type(lDef) then
                 Message(parser_e_cant_use_inittable_here);

             { try to parse the hint directives }
             lHintSymOptions:=[];
             lDeprecatedMsg:=nil;
             TryConsumeHintDirective(lHintSymOptions,lDeprecatedMsg);

             { update variable type and hints }
             for lIndex:=0 to lSymbols.count-1 do
               begin
                 lFieldVarSym:=TFieldVarSym(lSymbols[lIndex]);
                 lFieldVarSym.vardef:=lDef;
                 { insert any additional hint directives }
                 lFieldVarSym.SymOptions := lFieldVarSym.SymOptions + lHintSymOptions;
                 if lDeprecatedMsg<>nil then
                   lFieldVarSym.DeprecatedMsg:=StringDup(lDeprecatedMsg^);
               end;
               StringDispose(lDeprecatedMsg);

             { Records and objects can't have default values }
             { for a record there doesn't need to be a ; before the END or )    }
             if not(CurrentScanner.FToken in [_END,_RKLAMMER]) and
                not(lSemicolonEaten) then
               Consume(_SEMICOLON);

             { Parse procvar directives after ; }
             MaybeParseProcDirectives(lDef);

             { Add calling convention for procvar }
             if (
                 (lDef.typ=procvardef) or
                 Is_FuncRef(lDef)
               ) and (lDef.TypeSym=nil) then
               begin
                 if (lDef.typ=procvardef) and (po_is_function_ref in TProcVarDef(lDef).ProcOptions) then
                   begin
                     if not (m_function_references in CurrentSettings.ModeSwitches) and
                         not (po_is_block in TProcVarDef(lDef).ProcOptions) then
                       messagepos(lTypePos,sym_e_error_in_type_def)
                     else
                       begin
                         if Adjust_FuncRef(lDef,nil,nil) then
                           { the def was changed, so update it }
                           for lIndex:=0 to lSymbols.count-1 do
                             begin
                               lFieldVarSym:=TFieldVarSym(lSymbols[lIndex]);
                               lFieldVarSym.vardef:=lDef;
                             end;
                         if CurrentScanner.ReplayStackDepth=0 then
                           lDef.RegisterDef;
                       end;
                   end;
                 Handle_Calling_Convention(lDef,cHCCDefaultActionsIntf);
               end;

             if (vdObject in AOptions) then
               begin
                 { if it is not a class var section and token=STATIC then it is a class field too }
                 if not (vdClass in AOptions) and TryToConsume(_STATIC) then
                   begin
                     Consume(_SEMICOLON);
                     include(AOptions,vdClass);
                     lRemoveClassOption:=true;
                   end;

               end;
             if (lVisibility=vis_published) and
                not(Is_Class(lDef)) then
               begin
                 MessagePos(TFieldVarSym(lSymbols[0]).fileinfo,parser_e_cant_publish_that);
                 lVisibility:=vis_public;
               end;

             if (lVisibility=vis_published) and
                not(oo_can_have_published in TObjectDef(lDef).ObjectOptions) and
                not(m_delphi in CurrentSettings.ModeSwitches) then
               begin
                 MessagePos(TFieldVarSym(lSymbols[0]).fileinfo,parser_e_only_publishable_classes_can_be_published);
                 lVisibility:=vis_public;
               end;
             if vdClass in AOptions then
               begin
                 { add static flag and staticvarsyms }
                 for lIndex:=0 to lSymbols.count-1 do
                   begin
                     lFieldVarSym:=TFieldVarSym(lSymbols[lIndex]);
                     lFieldVarSym.visibility:=lVisibility;
                     lStaticVarSym:=Make_Field_Static(lRecordSymTable,lFieldVarSym);
                     if vdThreadVar in AOptions then
                       include(lStaticVarSym.VarOptions,vo_is_thread_var);
                     if not ParseGeneric then
                       CNodeUtils.InsertBSSData(lStaticVarSym);
                     if vdFinal in AOptions then
                       lStaticVarSym.VarSpez:=vs_final;
                   end;
                 if lRemoveClassOption then
                   begin
                     exclude(AOptions,vdClass);
                     lRemoveClassOption:=false;
                   end;
               end;
             if vdFinal in AOptions then
               begin
                 { add final flag }
                 for lIndex:=0 to lSymbols.count-1 do
                   begin
                     lFieldVarSym:=TFieldVarSym(lSymbols[lIndex]);
                     lFieldVarSym.VarSpez:=vs_final;
                   end;
               end;

             if not(vdCanReorder in AOptions) then
               { add field(s) to the recordsymtable }
               lRecordSymTable.AddFieldList(lSymbols,false)
             else
               { we may reorder the fields before adding them to the symbol
                 table }
               AReorderList.ConcatListCopy(lSymbols)
           end;

         if m_delphi in CurrentSettings.ModeSwitches then
           Block_Type:=bt_var_type
         else
           Block_Type:=lOldBlockType;
         { Check for Case }
         if (vdRecord in AOptions) and
            TryToConsume(_CASE) then
           begin
              lMaxSize:=0;
              lMaxAlignment:=0;
              lMaxPadAlign:=0;

              { already inside a variant record? if not, setup a new variantdesc chain }
              if not(Assigned(AVariantDesc)) then
                AVariantDesc:=@TRecordDef(TRecordSymTable(lRecordSymTable).DefOwner).VariantRecDesc;

              { else just concat the info to the given one }
              new(AVariantDesc^);
              fillchar(AVariantDesc^^,sizeof(TVariantRecDesc),0);

              { including a field declaration? }
              lFieldVarSym:=nil;
              if CurrentScanner.FToken=_ID then
                begin
                  lOrgName:=CurrentScanner.FOrgPattern;
                  lName:=CurrentScanner.FPattern;
                  SearchSym(lName,lSearchSym,lSearchSymTable);
                  if not(Assigned(lSearchSym) and (lSearchSym.typ in [TypeSym,UnitSym])) then
                    begin
                      Consume(_ID);
                      Consume(_COLON);
                      lFieldVarSym:=CFieldVarSym.Create(lOrgName,vs_value,GenErrorDef,[]);
                      AVariantDesc^^.VariantSelector:=lFieldVarSym;
                      SymTableStack.top.InsertSym(lFieldVarSym);
                    end;
                end;
              ReadAnonType(lCaseType,true,nil);
              Block_Type:=bt_var;
              if Assigned(lFieldVarSym) then
                begin
                  lFieldVarSym.vardef:=lCaseType;
                  lRecordSymTable.AddField(lFieldVarSym,lRecordSymTable.CurrentVisibility);
                end;
              if not(Is_Ordinal(lCaseType))
{$ifndef cpu64bitaddr}
                 or Is_64BitInt(lCaseType)
{$endif cpu64bitaddr}
                 then
                Message(type_e_ordinal_expr_expected);
              Consume(_OF);

              lUnionSymTable:=TRecordSymTable.Create('',CurrentSettings.PackRecords,CurrentSettings.Alignment.RecordAlignMin);
              lUnionDef:=CRecordDef.Create('',lUnionSymTable);
              lUnionDef.IsUnion:=true;

              lStartVarRecSize:=lUnionSymTable.DataSize;
              { align the bitpacking to the next byte }
              lUnionSymTable.DataSize:=lStartVarRecSize;
              lStartVarRecAlign:=lUnionSymTable.FieldAlignment;
              lStartPadAlign:=lUnionSymTable.PadAlignment;
              SymTableStack.push(lUnionSymTable);
              repeat
                SetLength(AVariantDesc^^.branches,length(AVariantDesc^^.branches)+1);
                fillchar(AVariantDesc^^.branches[high(AVariantDesc^^.branches)],
                  sizeof(AVariantDesc^^.branches[high(AVariantDesc^^.branches)]),0);
                repeat
                  lNode:=CompExpr([efAcceptEqual]);
                  if not(lNode.nodetype=ordconstn) then
                    Message(parser_e_illegal_expression);
                  InsertTypeConv(lNode,lCaseType);
                  { iso pascal does not support ranges in variant record definitions }
                  if (([m_iso]*CurrentSettings.ModeSwitches)=[]) and TryToConsume(_POINTPOINT) then
                    lNode:=CRangeNode.Create(lNode,CompExpr([efAcceptEqual]))
                  else
                    begin
                      with AVariantDesc^^.branches[high(AVariantDesc^^.branches)] do
                        begin
                          SetLength(values,length(values)+1);
                          values[high(values)]:=TOrdConstNode(lNode).Value;
                        end;
                    end;
                  lNode.free;
                  lNode := nil;
                  if CurrentScanner.FToken=_COMMA then
                    Consume(_COMMA)
                  else
                    break;
                until false;
                if m_delphi in CurrentSettings.ModeSwitches then
                  Block_Type:=bt_var_type
                else
                  Block_Type:=lOldBlockType;
                Consume(_COLON);
                { read the vars }
                Consume(_LKLAMMER);
                inc(VariantRecordLevel);
                if CurrentScanner.FToken<>_RKLAMMER then
                  ReadRecordFields([vdRecord],nil,@AVariantDesc^^.branches[high(AVariantDesc^^.branches)].NestedVariant,lHadGenDummy,lDummyAttrElementCount);
                dec(VariantRecordLevel);
                Consume(_RKLAMMER);

                { calculates maximal variant size }
                lMaxSize:=max(lMaxSize,lUnionSymTable.DataSize);
                lMaxAlignment:=max(lMaxAlignment,lUnionSymTable.FieldAlignment);
                lMaxPadAlign:=max(lMaxPadAlign,lUnionSymTable.PadAlignment);
                { the items of the next variant are overlayed }
                lUnionSymTable.DataSize:=lStartVarRecSize;
                lUnionSymTable.FieldAlignment:=lStartVarRecAlign;
                lUnionSymTable.PadAlignment:=lStartPadAlign;
                if (CurrentScanner.FToken<>_END) and (CurrentScanner.FToken<>_RKLAMMER) then
                  Consume(_SEMICOLON)
                else
                  break;
              until (CurrentScanner.FToken=_END) or (CurrentScanner.FToken=_RKLAMMER);
              SymTableStack.pop(lUnionSymTable);
              { at last set the record size to that of the biggest variant }
              lUnionSymTable.DataSize:=lMaxSize;
              lUnionSymTable.FieldAlignment:=lMaxAlignment;
              lUnionSymTable.AddAlignmentPadding;
              { Align the offset where the union symtable is added }
              case lRecordSymTable.UseFieldAlignment of
                { allow the unionsymtable to be aligned however it wants }
                { (within the global min/max limits)                     }
                0, { default }
                CAlignment:
                  lUsedAlign:=Used_Align(lUnionSymTable.RecordAlignment,CurrentSettings.Alignment.RecordAlignMin,CurrentSettings.Alignment.MaxCRecordAlign);
                { 1 byte alignment if we are bitpacked }
                BitAlignment:
                  lUsedAlign:=1;
                Mac68KAlignment:
                  lUsedAlign:=2;
                { otherwise alignment at the packrecords alignment of the }
                { current record                                          }
                else
                  lUsedAlign:=Used_Align(lRecordSymTable.FieldAlignment,CurrentSettings.Alignment.RecordAlignMin,CurrentSettings.Alignment.RecordAlignMax);
              end;
              lOffset:=align(lRecordSymTable.DataSize,lUsedAlign);
              lRecordSymTable.DataSize:=lOffset+lUnionSymTable.DataSize;

              if lUnionSymTable.RecordAlignment>lRecordSymTable.FieldAlignment then
                lRecordSymTable.FieldAlignment:=lUnionSymTable.RecordAlignment;

              if lUnionSymTable.ExplicitRecordAlignment>lRecordSymTable.ExplicitRecordAlignment then
                lRecordSymTable.ExplicitRecordAlignment:=lUnionSymTable.ExplicitRecordAlignment;

              TRecordSymTable(lRecordSymTable).InsertUnionST(lUnionSymTable,lOffset);
              lUnionDef.owner.DeleteDef(lUnionDef);
           end;
         { free the list }
         lSymbols.free;
         lSymbols := nil;
         Block_Type:=lOldBlockType;
      end;

end.
