{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Builds data structures like VMT, Messages, VTables, Interfaces descs

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
unit nobj;

{$i fpcdefs.inc}

interface

    uses
       CUtils,CClasses,
       GlobType,
       symdef,SymSym
       ;

    type
      TVMTBuilder=class
      private
        FClass : TObjectDef;
        FHandledProtocols: TFPObjectList;
        function  IsNewVMTEntry(AProcDef:TProcDef; out AOverridesClassHelper: Boolean):Boolean;
        procedure AddNewVMTEntry(AProcDef:TProcDef; AAllowOverridingMethod: Boolean);
        function  CheckMsgStr(AVMTProcDef, AProcDef: TProcDef):Boolean;
        function  IntfSearchProcDefByName(AProcDef: TProcDef;const AName: String): TProcDef;
        procedure IntfGetProcDefs(AImplIntf:TImplementedInterface;AInterfaceDef:TObjectDef);
        procedure IntfGetProcDefsRecursive(AImplIntf:TImplementedInterface;AInterfaceDef:TObjectDef);
        procedure ProtGetProcDefsRecursive(AImplProtocol:TImplementedInterface;AProtocolDef:TObjectDef);
        procedure IntfOptimizeVTbls;
        procedure IntfAllocateVTbls;
        procedure CreateVMTDef;
        procedure BuildInterfaceMappings;
      public
        constructor Create(AClassDef:TObjectDef);
        procedure Build;
      end;


{ convenience routine to build the VMT for an objectdef
  Note: also ensures that the procdefs of the objectdef have their hidden
  parameters inserted }
procedure Build_VMT(ADef:TObjectDef);


implementation

    uses
       Globals,Verbose,Systems,
       node,
       SymBase,SymTable,symconst,symtype,symcpu,
       defcmp,
       pparautl;


{*****************************************************************************
                              TVMTBuilder
*****************************************************************************}

    constructor TVMTBuilder.Create(AClassDef:TObjectDef);
      begin
        inherited Create;
        FClass:=AClassDef;
      end;


    procedure TVMTBuilder.AddNewVMTEntry(AProcDef:TProcDef; AAllowOverridingMethod: Boolean);
      var
        lIndex : LongInt;
        lVMTEntry : PVMTEntry;
        lVMTProcDef : TProcDef;
      begin
        { new entry is needed, override was not possible }
        { Allowed when overriding a category method for a parent class in a
          descendent Objective-C class }
        if not AAllowOverridingMethod and
           (po_overridingmethod in AProcDef.ProcOptions) then
          begin
            MessagePos1(AProcDef.FileInfo,parser_e_nothing_to_be_overridden,AProcDef.FullProcName(true));
            for lIndex:=0 to FClass.VMTEntries.count-1 do
              begin
                lVMTEntry:=PVMTEntry(FClass.VMTEntries[lIndex]);
                lVMTProcDef:=TProcDef(lVMTEntry^.procdef);
                if (upper(lVMTProcDef.ProcSym.realname)=upper(AProcDef.ProcSym.realname)) then
                  MessagePos1(lVMTProcDef.FileInfo,sym_h_param_list,lVMTProcDef.FullProcName(true));
	      end;
          end;

        { check that all methods have overload directive }
        if not(m_fpc in CurrentSettings.ModeSwitches) then
          begin
            for lIndex:=0 to FClass.VMTEntries.count-1 do
              begin
                lVMTEntry:=PVMTEntry(FClass.VMTEntries[lIndex]);
                lVMTProcDef:=TProcDef(lVMTEntry^.procdef);
                if (lVMTProcDef.ProcSym=AProcDef.ProcSym) and
                   (not(po_overload in AProcDef.ProcOptions) or
                    not(po_overload in lVMTProcDef.ProcOptions)) then
                  begin
                    MessagePos1(AProcDef.FileInfo,parser_e_no_overload_for_all_procs,AProcDef.ProcSym.realname);
                    { recover }
                    include(lVMTProcDef.ProcOptions,po_overload);
                    include(AProcDef.ProcOptions,po_overload);
                  end;
              end;
          end;

        { Register virtual method and give it a number }
        if (po_virtualmethod in AProcDef.ProcOptions) then
          begin
             { store vmt entry number in procdef }
             if (AProcDef.ExtNumber<>$ffff) and
                (AProcDef.ExtNumber<>FClass.VMTEntries.Count) then
               InternalError(200810283);
             AProcDef.ExtNumber:=FClass.VMTEntries.Count;
             new(lVMTEntry);
             lVMTEntry^.procdef:=AProcDef;
             lVMTEntry^.ProcDefDeref.reset;
             lVMTEntry^.visibility:=AProcDef.visibility;
             FClass.VMTEntries.Add(lVMTEntry);
          end;
      end;


      function TVMTBuilder.CheckMsgStr(AVMTProcDef, AProcDef: TProcDef): Boolean;
        begin
          Result:=true;
          if not(Is_ObjC_Class_Or_Protocol(FClass)) then
            begin
              { the only requirement for normal methods is that both either
                have a message string or not (the value is irrelevant) }
              if ((AProcDef.ProcOptions * [po_msgstr]) <> (AVMTProcDef.ProcOptions * [po_msgstr])) then
                begin
                  MessagePos1(AProcDef.FileInfo,parser_e_header_dont_match_forward,AProcDef.FullProcName(false));
                  TProcSym(AVMTProcDef.ProcSym).Write_Parameter_Lists(AProcDef);
                  Result:=false;
                end
            end
          else
            begin
              { the compiler should have ensured that the protocol or parent
                class method has a message name specified }
              if not(po_msgstr in AVMTProcDef.ProcOptions) then
                InternalError(2009070601);
              if not(po_msgstr in AProcDef.ProcOptions) then
                begin
                  { copy the protocol's/parent class' message name to the one in
                    the class if none has been specified there }
                  include(AProcDef.ProcOptions,po_msgstr);
                  AProcDef.MessageInf.str:=StringDup(AVMTProcDef.MessageInf.str^);
                end
              else
                begin
                  { if both have a message name, make sure they are equal }
                  if (AVMTProcDef.MessageInf.str^<>AProcDef.MessageInf.str^) then
                    begin
                      MessagePos2(AProcDef.FileInfo,parser_e_objc_message_name_changed,AVMTProcDef.MessageInf.str^,AProcDef.MessageInf.str^);
                      Result:=false;
                    end;
                end;
            end;
        end;


    function TVMTBuilder.IsNewVMTEntry(AProcDef:TProcDef; out AOverridesClassHelper: Boolean):Boolean;
      const
        cProcOptionsToCompare = [po_classmethod,po_virtualmethod,po_staticmethod,po_interrupt,po_iocheck,po_msgint,
                   po_exports,po_varargs,po_nostackframe];
      var
        lIndex : LongInt;
        lHasEqualPara,
        lHasOverloads,
        lProcDefOverload : Boolean;
        lFoundSym : TSym;
        lSymTable : TSymTable;

      // returns true if we can stop checking, false if we have to continue
      function FoundEntry(var AVMTProcDef: TProcDef; var AVMTEntryVisibility: TVisibility; AUpdateValues: Boolean): Boolean;
        begin
          Result:=false;

          { ignore hidden entries (e.g. virtual overridden by a static) that are not visible anymore }
          if AVMTEntryVisibility=vis_hidden then
            exit;

          { ignore different names }
          if AVMTProcDef.ProcSym.name<>AProcDef.ProcSym.name then
            exit;

          { hide private methods that are not visible anymore. For this check we
            must override the visibility with the highest value in the override chain.
            This is required for case (see tw3292) with protected-private-protected where the
            same vmtentry is used (PFV) }
          if not Is_Visible_For_Object(AVMTProcDef.owner,AVMTEntryVisibility,FClass) then
            exit;

          { inherit overload }
          if (po_overload in AVMTProcDef.ProcOptions) then
            begin
              include(AProcDef.ProcOptions,po_overload);
              lProcDefOverload:=true;
            end;

          { compare parameter types only, no specifiers yet }
          lHasEqualPara:=(Compare_Paras(AVMTProcDef.paras,AProcDef.paras,cp_none,[cpo_ignoreuniv,cpo_ignorehidden])>=te_equal);

          { check that we are not trying to override a final method }

          if (po_finalmethod in AVMTProcDef.ProcOptions) and
             lHasEqualPara and
             ((po_overridingmethod in AProcDef.ProcOptions)) and
             (Is_Class(FClass) or Is_ObjectPascal_Helper(FClass)) then
            MessagePos1(AProcDef.FileInfo,parser_e_final_can_no_be_overridden,AProcDef.FullProcName(false))
          else
          { old definition has virtual
            new definition has no virtual or override }
          if (po_virtualmethod in AVMTProcDef.ProcOptions) and
             (
              not(po_virtualmethod in AProcDef.ProcOptions) or
              (
               { new one does not have reintroduce in case of an objccategory }
               (Is_ObjCCategory(FClass) and
                 not(po_reintroduce in AProcDef.ProcOptions)) or

               ((Is_Class_Or_Interface_Or_ObjC(FClass) or Is_ObjectPascal_Helper(FClass)) and
                not Is_ObjCCategory(FClass) and
                not(po_overridingmethod in AProcDef.ProcOptions)
               )
              )
             ) then
            begin
              if (
                  not(lProcDefOverload or lHasOverloads) or
                  lHasEqualPara
                 ) then
                begin
                  if not(po_reintroduce in AProcDef.ProcOptions) then
                    if not(Is_ObjC_Class_Or_Protocol(FClass))
                       then
                      MessagePos1(AProcDef.FileInfo,parser_w_should_use_override,AProcDef.FullProcName(false))
                    else
                      begin

                        if lHasEqualPara then
                          begin
                            if not(oo_is_external in FClass.ObjectOptions) then
                              if not Is_ObjCCategory(FClass) then
                                MessagePos1(AProcDef.FileInfo,parser_e_must_use_override,FullTypeName(TDef(AVMTProcDef.owner.DefOwner),nil))
                              else
                                MessagePos1(AProcDef.FileInfo,parser_e_must_use_reintroduce_objc,FullTypeName(TDef(AVMTProcDef.owner.DefOwner),nil))
                            { there may be a lot of these in auto-translated
                              headers, so only calculate the fulltypename if
                              the hint will be shown  }
                            else if CheckVerbosity(VHint) then
                              if not Is_ObjCCategory(FClass) then
                                MessagePos1(AProcDef.FileInfo,parser_h_should_use_override,FullTypeName(TDef(AVMTProcDef.owner.DefOwner),nil))
                              else
                                MessagePos1(AProcDef.FileInfo,parser_h_should_use_reintroduce_objc,FullTypeName(TDef(AVMTProcDef.owner.DefOwner),nil));
                          end;
                        { no new entry, but copy the message name if any from
                          the procdef in the parent class }
                        if not Is_ObjC_Class_Or_Protocol(FClass) or
                           lHasEqualPara then
                          CheckMsgStr(AVMTProcDef,AProcDef);
                        if AUpdateValues then
                          begin

                            { in case we are overriding an abstract method,
                              decrease the number of abstract methods in this class }
                            if (po_abstractmethod in AVMTProcDef.ProcOptions) then
                              dec(TObjectDef(AProcDef.owner.DefOwner).AbstractCnt);
                            if (AVMTProcDef.ExtNumber<>lIndex) then
                              InternalError(2011083101);
                            AProcDef.ExtNumber:=AVMTProcDef.ExtNumber;
                            AVMTProcDef:=AProcDef;
                          end;
                        Result:=true;
                        exit;
                      end;
                  { disable/hide old VMT entry }
                  if AUpdateValues then
                    AVMTEntryVisibility:=vis_hidden;
                end;
            end
          { both are virtual? }
          else if (po_virtualmethod in AProcDef.ProcOptions) and
                  (po_virtualmethod in AVMTProcDef.ProcOptions) then
            begin
              { same parameter and return types (parameter specifiers will be checked below) }
              if lHasEqualPara and
                 Compatible_ChildMethod_ResultDef(AVMTProcDef.ReturnDef,AProcDef.ReturnDef) then
                begin
                  { inherit calling convention when it was explicit and the
                    current definition has none explicit set }
                  if (po_hascallingconvention in AVMTProcDef.ProcOptions) and
                     not(po_hascallingconvention in AProcDef.ProcOptions) then
                    begin
                      AProcDef.ProcCallOption:=AVMTProcDef.ProcCallOption;
                      include(AProcDef.ProcOptions,po_hascallingconvention);
                    end;

                  { All parameter specifiers and some procedure the flags have to match
                    except abstract and override }
                  if (Compare_Paras(AVMTProcDef.paras,AProcDef.paras,cp_all,[cpo_ignoreuniv,cpo_ignorehidden])<te_equal) or
                     (AVMTProcDef.ProcCallOption<>AProcDef.ProcCallOption) or
                     (AVMTProcDef.ProcTypeOption<>AProcDef.ProcTypeOption) or
                     ((AVMTProcDef.ProcOptions*cProcOptionsToCompare)<>(AProcDef.ProcOptions*cProcOptionsToCompare)) then
                     begin
                       MessagePos1(AProcDef.FileInfo,parser_e_header_dont_match_forward,AProcDef.FullProcName(false));
                       TProcSym(AVMTProcDef.ProcSym).Write_Parameter_Lists(AProcDef);
                     end;

                  CheckMsgStr(AVMTProcDef,AProcDef);

                  { Give a note if the new visibility is lower. For a higher
                    visibility update the vmt info }
                  if AVMTEntryVisibility>AProcDef.visibility then
                    begin
                      MessagePos4(AProcDef.FileInfo,parser_n_ignore_lower_visibility,
                          AProcDef.FullProcName(false),
                          VisibilityName[AProcDef.visibility],TObjectDef(AVMTProcDef.owner.DefOwner).ObjRealName^,VisibilityName[AVMTEntryVisibility])
                      end
                  else if AProcDef.visibility>AVMTEntryVisibility then
                    begin
                      if AUpdateValues then
                        AVMTEntryVisibility:=AProcDef.visibility;
                    end;

                  { override old virtual method in VMT }
                  if AUpdateValues then
                    begin
                      { in case we are overriding an abstract method,
                        decrease the number of abstract methods in this class }
                      if (po_overridingmethod in AProcDef.ProcOptions) and
                         (po_abstractmethod in AVMTProcDef.ProcOptions) then
                        dec(TObjectDef(AProcDef.owner.DefOwner).AbstractCnt);

                      if (AVMTProcDef.ExtNumber<>lIndex) then
                        InternalError(200611084);
                      AProcDef.ExtNumber:=AVMTProcDef.ExtNumber;

                      AVMTProcDef:=AProcDef;
                    end;
                  Result:=true;
                  exit;
                end
              { different parameters }
              else
               begin
                 { when we got an override directive then can search further for
                   the procedure to override.
                   If we are starting a new virtual tree then hide the old tree }
                 if not(po_overridingmethod in AProcDef.ProcOptions) and
                    not(lProcDefOverload or lHasOverloads) then
                   begin
                     if not(po_reintroduce in AProcDef.ProcOptions) then
                       begin
                         if not Is_Object(FClass) and
                            not Is_ObjC_Class_Or_Protocol(FClass) then
                           MessagePos1(AProcDef.FileInfo,parser_w_should_use_override,AProcDef.FullProcName(false))
                         else

                           MessagePos1(AProcDef.FileInfo,parser_e_header_dont_match_forward,AVMTProcDef.FullProcName(false));
                       end;
                     { disable/hide old VMT entry }
                     if AUpdateValues then
                       AVMTEntryVisibility:=vis_hidden;
                   end;
               end;
            end;
        end;

        function FoundCategoryMethod(ASymTable: TSymTable): Boolean;
          var
            lEntryCount: LongInt;
            lCategory: TObjectDef;
            lVMTProcDef: TProcDef;
            lVMTVisibility: TVisibility;
          begin
            Result:=false;
            if Is_ObjCCategory(TDef(ASymTable.DefOwner)) then
              begin
                lCategory:=TObjectDef(ASymTable.DefOwner);
                { go through all of the category's methods to find the
                  vmtentry corresponding to the procdef we are handling }
                for lEntryCount:=0 to lCategory.VMTEntries.Count-1 do
                  begin
                    lVMTProcDef:=PVMTEntry(lCategory.VMTEntries[lEntryCount])^.procdef;
                    lVMTVisibility:=PVMTEntry(lCategory.VMTEntries[lEntryCount])^.visibility;
                    { don't change the vmtentry of the category }
                    if FoundEntry(lVMTProcDef,lVMTVisibility,false) then
                      begin
                        Result:=true;
                        exit;
                      end;
                  end;
              end;
          end;

      begin
        Result:=false;
        AOverridesClassHelper:=false;
        { Load other values for easier readability }
        lHasOverloads:=(TProcSym(AProcDef.ProcSym).ProcdefList.Count>1);
        lProcDefOverload:=(po_overload in AProcDef.ProcOptions);

        { compare with all stored definitions }
        for lIndex:=0 to FClass.VMTEntries.Count-1 do
          begin
            if FoundEntry(PVMTEntry(FClass.VMTEntries[lIndex])^.procdef, PVMTEntry(FClass.VMTEntries[lIndex])^.visibility,true) then
              exit;
          end;

        { in case of Objective-C, also check the categories that apply to this
          class' *parent* for methods to override (don't allow class X to
          "override" a method added by a category to class X itself, since in
          that case the category method will in fact replace class X'
          "overriding" method }
        if Is_ObjCClass(FClass) and
           Assigned(FClass.ChildOf) and
           Search_ObjC_Helper(FClass.ChildOf,AProcDef.ProcSym.name,lFoundSym,lSymTable) then
          begin
            AOverridesClassHelper:=FoundCategoryMethod(lSymTable);
          end;

        { No entry found, we need to create a new entry }
        Result:=true;
      end;


    function TVMTBuilder.IntfSearchProcDefByName(AProcDef: TProcDef;const AName: String): TProcDef;
      const
        cProcOptionsToCompare = [po_classmethod,po_staticmethod,po_interrupt,po_iocheck,po_msgint,
                   po_exports,po_varargs,po_nostackframe];
      var
        lImplProcDef : TProcDef;
        lIndex: Cardinal;
        lClass : TObjectDef;
        lHashedID : THashedIDString;
        lFoundSym      : TSym;
        lOverload: Boolean;
      begin
        Result:=nil;
        lHashedID.id:=AName;
        lClass:=FClass;
        while Assigned(lClass) do
          begin
            lFoundSym:=TSym(lClass.SymTable.FindWithHash(lHashedID));
            if Assigned(lFoundSym) and
               (lFoundSym.typ=ProcSym) and
               ((lClass=FClass) or
                Is_Visible_For_Object(lFoundSym,FClass)) then
              begin
                lOverload:=false;
                for lIndex:=0 to TProcSym(lFoundSym).ProcdefList.Count-1 do
                  begin
                    lImplProcDef:=TProcDef(TProcSym(lFoundSym).ProcdefList[lIndex]);
                    if po_overload in lImplProcDef.ProcOptions then
                      lOverload:=true;
                    if (lImplProcDef.ProcSym=TProcSym(lFoundSym)) and
                       (Compare_Paras(AProcDef.paras,lImplProcDef.paras,cp_all,[cpo_ignorehidden,cpo_ignoreuniv])>=te_equal) and
                       (Compare_Defs(AProcDef.ReturnDef,lImplProcDef.ReturnDef,nothingn)>=te_equal) and
                       (AProcDef.ProcCallOption=lImplProcDef.ProcCallOption) and
                       (AProcDef.ProcTypeOption=lImplProcDef.ProcTypeOption) and
                       ((AProcDef.ProcOptions*cProcOptionsToCompare)=((lImplProcDef.ProcOptions+[po_virtualmethod])*cProcOptionsToCompare)) and
                       CheckMsgStr(AProcDef,lImplProcDef) then
                      begin
                        { does the interface increase the visibility of the
                          implementing method? }
                        if lImplProcDef.visibility<AProcDef.visibility then
                          MessagePos2(lImplProcDef.FileInfo,type_w_interface_lower_visibility,AProcDef.FullProcName(false),lImplProcDef.FullProcName(false));
                        Result:=lImplProcDef;
                        AddSymRef(Result.ProcSym,Result);
                        exit;
                      end;
                  end;
                { like with normal procdef resolution (in htypechk), stop if
                  we encounter a proc without the overload directive }
                if not lOverload then
                  exit;
              end;
            lClass:=lClass.ChildOf;
          end;
      end;


    procedure TVMTBuilder.IntfGetProcDefs(AImplIntf:TImplementedInterface;AInterfaceDef:TObjectDef);
      var
        lIndex   : LongInt;
        lDef : TDef;
        lString,
        lPrefix,
        lMappedName: String;
        lImplProcDef: TProcDef;
      begin
        lPrefix:=AImplIntf.IntfDef.SymTable.name^+'.';
        for lIndex:=0 to AInterfaceDef.SymTable.DefList.Count-1 do
          begin
            lDef:=TDef(AInterfaceDef.SymTable.DefList[lIndex]);
            if Assigned(lDef) and
               (lDef.typ=procdef) then
              begin
                { Find implementing procdef
                   1. Check for mapped name
                   2. Use symbol name, but only if there's no mapping,
                      or we're processing ancestor of interface.
                  When modifying this code, ensure that tbs/tb_interfaces_delphi_run_01.pas (case tw11862.pas), tbs/tw4950
                  and webtbf/tw19591 stay correct. }
                lImplProcDef:=nil;
                lString:=lPrefix+TProcDef(lDef).ProcSym.name;
                lMappedName:=AImplIntf.GetMapping(lString);
                if lMappedName<>'' then
                  lImplProcDef:=IntfSearchProcDefByName(TProcDef(lDef),lMappedName);
                if not Assigned(lImplProcDef) then
                  if (lMappedName='') or (AImplIntf.IntfDef<>AInterfaceDef) then
                    lImplProcDef:=IntfSearchProcDefByName(TProcDef(lDef),TProcDef(lDef).ProcSym.name);

                { Add procdef to the implemented interface }
                if Assigned(lImplProcDef) then
                  begin
                    if (TObjectDef(lImplProcDef.struct).ObjectType<>odt_objcclass) then
                      begin

                        AImplIntf.AddImplProc(lImplProcDef);
                      end
                    else
                      begin
                        { If no message name has been specified for the method
                          in the objcclass, copy it from the protocol
                          definition.  }
                        if not(po_msgstr in TProcDef(lDef).ProcOptions) then
                          begin
                            include(TProcDef(lDef).ProcOptions,po_msgstr);
                            lImplProcDef.MessageInf.str:=StringDup(TProcDef(lDef).MessageInf.str^);
                          end
                        else
                          begin
                            { If a message name has been specified in the
                              objcclass, it has to match the message name in the
                              protocol definition.  }
                            if (lImplProcDef.MessageInf.str^<>TProcDef(lDef).MessageInf.str^) then
                              MessagePos2(lImplProcDef.FileInfo,parser_e_objc_message_name_changed,TProcDef(lDef).MessageInf.str^,lImplProcDef.MessageInf.str^);
                          end;
                      end;
                  end
                else
                  if (AImplIntf.IType=etStandard) and
                     not(po_optional in TProcDef(lDef).ProcOptions) then
                    MessagePos1(FClass.TypeSym.FileInfo,sym_e_no_matching_implementation_found,TProcDef(lDef).FullProcName(false));
              end;
          end;
      end;


    procedure TVMTBuilder.IntfGetProcDefsRecursive(AImplIntf:TImplementedInterface;AInterfaceDef:TObjectDef);
      begin
        if Assigned(AInterfaceDef.ChildOf) then
          IntfGetProcDefsRecursive(AImplIntf,AInterfaceDef.ChildOf);
        IntfGetProcDefs(AImplIntf,AInterfaceDef);
      end;


    procedure TVMTBuilder.ProtGetProcDefsRecursive(AImplProtocol:TImplementedInterface;AProtocolDef:TObjectDef);
      var
        lIndex: LongInt;
      begin
        { don't check the same protocol twice }
        if FHandledProtocols.IndexOf(AProtocolDef)<>-1 then
          exit;
        FHandledProtocols.add(AProtocolDef);
        for lIndex:=0 to AProtocolDef.ImplementedInterfaces.count-1 do
          ProtGetProcDefsRecursive(AImplProtocol,TImplementedInterface(AProtocolDef.ImplementedInterfaces[lIndex]).intfdef);
        IntfGetProcDefs(AImplProtocol,AProtocolDef);
      end;


    procedure TVMTBuilder.IntfOptimizeVTbls;
      type
        TCompIntfEntry = record
          Weight: LongInt;
          CompIntf: LongInt;
        end;
      var
        lEqualInterfaces: array of LongInt;
        lCompatibleInterfaces: array of TCompIntfEntry;
        lImplementations: array of LongInt;
        lImplIntfCount,
        lWeight,lIndex,lIndexJ,lIndexK: LongInt;
        lImplIntfI,
        lImplIntfJ  : TImplementedInterface;
        lCompatibleIJ: Boolean;
        lCompatibleJI: Boolean;
      begin
        lImplIntfCount:=FClass.ImplementedInterfaces.count;
        if lImplIntfCount=0 then
          exit;
        SetLength(lCompatibleInterfaces,lImplIntfCount);
        SetLength(lEqualInterfaces,lImplIntfCount);
        SetLength(lImplementations,lImplIntfCount);
        filldword(lCompatibleInterfaces[0],(sizeof(TCompIntfEntry) div sizeof(dword))*lImplIntfCount,dword(-1));
        filldword(lEqualInterfaces[0],lImplIntfCount,dword(-1));
        filldword(lImplementations[0],lImplIntfCount,dword(-1));
        { ismergepossible is a containing relation
          meaning of ismergepossible(a,b,w) =
          if implementorfunction map of a is contained implementorfunction map of b
          imp(a,b) and imp(b,c) => imp(a,c) ; imp(a,b) and imp(b,a) => a == b
        }
        { the order is very important for correct allocation }
        for lIndex:=0 to lImplIntfCount-1 do
          begin
            for lIndexJ:=lIndex+1 to lImplIntfCount-1 do
              begin
                lImplIntfI:=TImplementedInterface(FClass.ImplementedInterfaces[lIndex]);
                lImplIntfJ:=TImplementedInterface(FClass.ImplementedInterfaces[lIndexJ]);
                lCompatibleIJ:=lImplIntfI.IsImplMergePossible(lImplIntfJ,lWeight);
                lCompatibleJI:=lImplIntfJ.IsImplMergePossible(lImplIntfI,lWeight);
                if lCompatibleIJ and lCompatibleJI then { i equal j }
                  begin
                    { get minimum index of equal }
                    if lEqualInterfaces[lIndexJ]=-1 then
                      lEqualInterfaces[lIndexJ]:=lIndex;
                  end
                else if lCompatibleIJ then
                  begin
                    { get minimum index of maximum weight  }
                    if lCompatibleInterfaces[lIndex].Weight<lWeight then
                      begin
                        lCompatibleInterfaces[lIndex].Weight:=lWeight;
                        lCompatibleInterfaces[lIndex].CompIntf:=lIndexJ;
                      end;
                  end
                else if lCompatibleJI then
                  begin
                    { get minimum index of maximum weight  }
                    if (lCompatibleInterfaces[lIndexJ].Weight<lWeight) then
                      begin
                        lCompatibleInterfaces[lIndexJ].Weight:=lWeight;
                        lCompatibleInterfaces[lIndexJ].CompIntf:=lIndex;
                      end;
                  end;
              end;
          end;
        { Reset, no replacements by default }
        for lIndex:=0 to lImplIntfCount-1 do
          lImplementations[lIndex]:=lIndex;
        { Replace vtbls when equal or compat, repeat
          until there are no replacements possible anymore. This is
          needed for the cases like:
            First loop: 2->3, 3->1
            Second loop: 2->1 (because 3 was replaced with 1)
        }
        repeat
          lIndexK:=0;
          for lIndex:=0 to lImplIntfCount-1 do
            begin
              if lCompatibleInterfaces[lImplementations[lIndex]].CompIntf<>-1 then
                lImplementations[lIndex]:=lCompatibleInterfaces[lImplementations[lIndex]].CompIntf
              else if lEqualInterfaces[lImplementations[lIndex]]<>-1 then
                lImplementations[lIndex]:=lEqualInterfaces[lImplementations[lIndex]]
              else
                inc(lIndexK);
            end;
        until lIndexK=lImplIntfCount;
        { Update the VtblImplIntf }
        for lIndex:=0 to lImplIntfCount-1 do
          begin
            lImplIntfI:=TImplementedInterface(FClass.ImplementedInterfaces[lIndex]);
            lImplIntfI.VtblImplIntf:=TImplementedInterface(FClass.ImplementedInterfaces[lImplementations[lIndex]]);
          end;
      end;


    procedure TVMTBuilder.IntfAllocateVTbls;
      var
        lIndex : LongInt;
        lImplIntf : TImplementedInterface;
      begin
        { Allocation vtbl space }
        for lIndex:=0 to FClass.ImplementedInterfaces.count-1 do
          begin
            lImplIntf:=TImplementedInterface(FClass.ImplementedInterfaces[lIndex]);
            { if it implements itself and if it's not implemented by delegation }
            if (lImplIntf.VtblImplIntf=lImplIntf) and (lImplIntf.IType=etStandard) then
              begin
                { allocate a pointer in the object memory }
                with TObjectSymTable(FClass.SymTable) do
                  begin
                    DataSize:=align(DataSize,VoidPointerType.Alignment);
                    lImplIntf.Ioffset:=DataSize;
                    DataSize:=DataSize+VoidPointerType.Size;
                  end;
              end;
          end;
        { Update ioffset of current interface with the ioffset from
          the interface that is reused to implements this interface }
        for lIndex:=0 to FClass.ImplementedInterfaces.count-1 do
          begin
            lImplIntf:=TImplementedInterface(FClass.ImplementedInterfaces[lIndex]);
            if lImplIntf.VtblImplIntf<>lImplIntf then
              lImplIntf.IOffset:=lImplIntf.VtblImplIntf.IOffset;
          end;
      end;


    procedure TVMTBuilder.CreateVMTDef;
      var
        lIndex: LongInt;
        lVMTDef: TRecordDef;
        lSystemVMT: TDef;
        lSym: TSym;
      begin
        { these types don't have an actual VMT, we only use the other methods
          in TVMTBuilder to determine duplicates/overrides }
        if FClass.ObjectType in [
           odt_helper,
           odt_objcclass,
           odt_objccategory,
           odt_objcprotocol,
           odt_interfacecom_property,
           odt_interfacecom_function] then
         exit;

        { don't generate VMT for generics (only use duplicates/overrides detection) }
        { Note: don't use is_generic here as we also need to check nested non-
                generic classes }
        if df_generic in FClass.DefOptions then
          exit;

        { todo in the future }
        if FClass.ObjectType = odt_cppclass then
          exit;

        { create VMT type definition }
        lVMTDef:=CRecordDef.Create_Internal(
          '$vmtdef',
          0,
          TargetInfo.Alignment.RecordAlignMin,
          FClass.SymTable);

        { standard VMT fields }
        case FClass.ObjectType of
          odt_class:
            begin
              lSystemVMT:=Search_System_Type('TVMT').TypeDef;
              if not Assigned(lSystemVMT) then
                Message1(cg_f_internal_type_not_found,'TVMT');

              { does the TVMT type look like we expect? (so that this code is
                easily triggered in case the definition of the VMT would
                change) }
              if (lSystemVMT.typ<>recorddef) or
                 (TRecordDef(lSystemVMT).SymTable.SymList.count<>27) then
                Message1(cg_f_internal_type_does_not_match,'TVMT');
              { system.tvmt is a record that represents the VMT of TObject,
                including its virtual methods. We only want the non-method
                fields, as the methods will be added automatically based on
                the VMT we generated here only add the 12 first fields }
              for lIndex:=0 to 11 do
                begin
                  lSym:=TSym(TRecordDef(lSystemVMT).SymTable.SymList[lIndex]);
                  if lSym.typ in [ProcSym,propertysym] then
                    continue;
                  if lSym.typ<>FieldVarSym then
                    InternalError(2015052602);
                  lVMTDef.Add_Field_By_Def('',TFieldVarSym(lSym).vardef);
                end;
            end;
           odt_interfacecom,odt_interfacecorba,odt_dispinterface:
             { nothing }
             ;
          odt_object:
            begin
              { size, -size, parent vmt [, dmt ] (same names as for class) }
              lVMTDef.Add_Field_By_Def('vInstanceSize',SizeSIntType);
              lVMTDef.Add_Field_By_Def('vInstanceSize2',SizeSIntType);
              lVMTDef.Add_Field_By_Def('vParent',VoidPointerType);
{$ifdef WITHDMT}
              lVMTDef.Add_Field_By_Def('',VoidPointerType);
{$endif WITHDMT}
            end;
          else
            InternalError(2015052605);
        end;

        { now add the methods }
        for lIndex:=0 to FClass.VMTEntries.count-1 do
          lVMTDef.Add_Field_By_Def('',
            CProcVarDef.GetReusableProcAddr(PVMTEntry(FClass.VMTEntries[lIndex])^.procdef,pc_address_only)
          );
        { the VMT ends with a nil pointer }
        lVMTDef.Add_Field_By_Def('',VoidCodePointerType);
      end;


    procedure TVMTBuilder.Build;
      var
        lIndex : LongInt;
        lDef : TDef;
        lOldCurrentStructDef : TAbstractRecordDef;
        lOverridesClassHelper : Boolean;
      begin
        lOldCurrentStructDef:=CurrentStructDef;
        CurrentStructDef:=FClass;

        { inherit (copy) VMT from parent object }
        if Assigned(FClass.ChildOf) then
          FClass.CopyVMTEntries(FClass.ChildOf);

        { process all procdefs, we must process the defs to
          keep the same order as that is written in the source
          to be compatible with the indexes in the interface vtable (PFV) }
        for lIndex:=0 to FClass.SymTable.DefList.Count-1 do
          begin
            lDef:=TDef(FClass.SymTable.DefList[lIndex]);
            if lDef.typ=procdef then
              begin
                { VMT entry }
                if IsNewVMTEntry(TProcDef(lDef),lOverridesClassHelper) then
                  AddNewVMTEntry(TProcDef(lDef),lOverridesClassHelper);
              end;
          end;
        Insert_Struct_Hidden_Paras(FClass);
        BuildInterfaceMappings;
        if Assigned(FClass.ImplementedInterfaces) and
           not(Is_ObjC_Class_Or_Protocol(FClass)) then
          begin
            { Optimize interface tables to reuse wrappers }
            IntfOptimizeVTbls;
            { Allocate interface tables }
            IntfAllocateVTbls;
          end;
        CreateVMTDef;
        CurrentStructDef:=lOldCurrentStructDef;
      end;


    procedure TVMTBuilder.BuildInterfaceMappings;
      var
        lImplIntf : TImplementedInterface;
        lIndex: LongInt;
      begin

        if Assigned(FClass.ImplementedInterfaces) and
           not(FClass.ObjectType in [odt_objcprotocol]) then
          begin
            { Collect implementor functions into the tImplementedInterface.procdefs }
            case FClass.ObjectType of
              odt_class:
                begin
                  for lIndex:=0 to FClass.ImplementedInterfaces.count-1 do
                    begin
                      lImplIntf:=TImplementedInterface(FClass.ImplementedInterfaces[lIndex]);
                      IntfGetProcDefsRecursive(lImplIntf,lImplIntf.IntfDef)
                    end;
                end;
              odt_objcclass:
                begin

                  FHandledProtocols:=TFPObjectList.Create(false);
                  for lIndex:=0 to FClass.ImplementedInterfaces.count-1 do
                    begin
                      lImplIntf:=TImplementedInterface(FClass.ImplementedInterfaces[lIndex]);
                      ProtGetProcDefsRecursive(lImplIntf,lImplIntf.IntfDef);
                    end;
                  FHandledProtocols.free;
                  FHandledProtocols := nil;
                end
              else
                InternalError(2009091801);
            end
          end;
      end;


    procedure Build_VMT(ADef:TObjectDef);
      var
        lVMTBuilder : TVMTBuilder;
      begin
        lVMTBuilder:=TVMTBuilder.Create(ADef);
        lVMTBuilder.Build;
        lVMTBuilder.free;
        lVMTBuilder := nil;
      end;

end.
