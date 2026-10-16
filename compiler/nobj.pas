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
        _Class : TObjectDef;
        handledprotocols: TFPObjectList;
        function  is_new_vmt_entry(pd:TProcDef; out overridesclasshelper: boolean):boolean;
        procedure add_new_vmt_entry(pd:TProcDef; allowoverridingmethod: boolean);
        function  check_msg_str(vmtpd, pd: TProcDef):boolean;
        function  intf_search_procdef_by_name(proc: TProcDef;const name: string): TProcDef;
        procedure intf_get_procdefs(ImplIntf:TImplementedInterface;IntfDef:TObjectDef);
        procedure intf_get_procdefs_recursive(ImplIntf:TImplementedInterface;IntfDef:TObjectDef);
        procedure prot_get_procdefs_recursive(ImplProt:TImplementedInterface;ProtDef:TObjectDef);
        procedure intf_optimize_vtbls;
        procedure intf_allocate_vtbls;
        procedure create_vmt_def;
        procedure build_interface_mappings;
      public
        constructor create(c:TObjectDef);
        procedure build;
      end;


{ convenience routine to build the VMT for an objectdef
  Note: also ensures that the procdefs of the objectdef have their hidden
  parameters inserted }
procedure build_vmt(def:TObjectDef);


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

    constructor TVMTBuilder.create(c:TObjectDef);
      begin
        inherited Create;
        _Class:=c;
      end;


    procedure TVMTBuilder.add_new_vmt_entry(pd:TProcDef; allowoverridingmethod: boolean);
      var
        i : LongInt;
        vmtentry : PVMTEntry;
        vmtpd : TProcDef;
      begin
        { new entry is needed, override was not possible }
        { Allowed when overriding a category method for a parent class in a
          descendent Objective-C class }
        if not allowoverridingmethod and
           (po_overridingmethod in pd.ProcOptions) then
          begin
            MessagePos1(pd.fileinfo,parser_e_nothing_to_be_overridden,pd.FullProcName(true));
            for i:=0 to _class.VMTEntries.count-1 do
              begin
                vmtentry:=PVMTEntry(_class.VMTEntries[i]);
                vmtpd:=TProcDef(vmtentry^.procdef);
                if (upper(vmtpd.ProcSym.realname)=upper(pd.ProcSym.realname)) then
                  MessagePos1(vmtpd.fileinfo,sym_h_param_list,vmtpd.FullProcName(true));
	      end;
          end;

        { check that all methods have overload directive }
        if not(m_fpc in CurrentSettings.ModeSwitches) then
          begin
            for i:=0 to _class.VMTEntries.count-1 do
              begin
                vmtentry:=PVMTEntry(_class.VMTEntries[i]);
                vmtpd:=TProcDef(vmtentry^.procdef);
                if (vmtpd.ProcSym=pd.ProcSym) and
                   (not(po_overload in pd.ProcOptions) or
                    not(po_overload in vmtpd.ProcOptions)) then
                  begin
                    MessagePos1(pd.fileinfo,parser_e_no_overload_for_all_procs,pd.ProcSym.realname);
                    { recover }
                    include(vmtpd.ProcOptions,po_overload);
                    include(pd.ProcOptions,po_overload);
                  end;
              end;
          end;

        { Register virtual method and give it a number }
        if (po_virtualmethod in pd.ProcOptions) then
          begin
             { store vmt entry number in procdef }
             if (pd.ExtNumber<>$ffff) and
                (pd.ExtNumber<>_class.VMTEntries.Count) then
               InternalError(200810283);
             pd.ExtNumber:=_class.VMTEntries.Count;
             new(vmtentry);
             vmtentry^.procdef:=pd;
             vmtentry^.ProcDefDeref.reset;
             vmtentry^.visibility:=pd.visibility;
             _class.VMTEntries.Add(vmtentry);
          end;
      end;


      function TVMTBuilder.check_msg_str(vmtpd, pd: TProcDef): boolean;
        begin
          result:=true;
          if not(Is_ObjC_Class_Or_Protocol(_class)) then
            begin
              { the only requirement for normal methods is that both either
                have a message string or not (the value is irrelevant) }
              if ((pd.ProcOptions * [po_msgstr]) <> (vmtpd.ProcOptions * [po_msgstr])) then
                begin
                  MessagePos1(pd.fileinfo,parser_e_header_dont_match_forward,pd.FullProcName(false));
                  TProcSym(vmtpd.ProcSym).Write_Parameter_Lists(pd);
                  result:=false;
                end
            end
          else
            begin
              { the compiler should have ensured that the protocol or parent
                class method has a message name specified }
              if not(po_msgstr in vmtpd.ProcOptions) then
                InternalError(2009070601);
              if not(po_msgstr in pd.ProcOptions) then
                begin
                  { copy the protocol's/parent class' message name to the one in
                    the class if none has been specified there }
                  include(pd.ProcOptions,po_msgstr);
                  pd.MessageInf.str:=StringDup(vmtpd.MessageInf.str^);
                end
              else
                begin
                  { if both have a message name, make sure they are equal }
                  if (vmtpd.MessageInf.str^<>pd.MessageInf.str^) then
                    begin
                      MessagePos2(pd.fileinfo,parser_e_objc_message_name_changed,vmtpd.MessageInf.str^,pd.MessageInf.str^);
                      result:=false;
                    end;
                end;
            end;
        end;


    function TVMTBuilder.is_new_vmt_entry(pd:TProcDef; out overridesclasshelper: boolean):boolean;
      const
        po_comp = [po_classmethod,po_virtualmethod,po_staticmethod,po_interrupt,po_iocheck,po_msgint,
                   po_exports,po_varargs,po_explicitparaloc,po_nostackframe];
      var
        i : LongInt;
        hasequalpara,
        hasoverloads,
        pdoverload : boolean;
        srsym : TSym;
        st : TSymTable;

      // returns true if we can stop checking, false if we have to continue
      function found_entry(var vmtpd: TProcDef; var vmtentryvis: TVisibility; updatevalues: boolean): boolean;
        begin
          result:=false;

          { ignore hidden entries (e.g. virtual overridden by a static) that are not visible anymore }
          if vmtentryvis=vis_hidden then
            exit;

          { ignore different names }
          if vmtpd.ProcSym.name<>pd.ProcSym.name then
            exit;

          { hide private methods that are not visible anymore. For this check we
            must override the visibility with the highest value in the override chain.
            This is required for case (see tw3292) with protected-private-protected where the
            same vmtentry is used (PFV) }
          if not Is_Visible_For_Object(vmtpd.owner,vmtentryvis,_class) then
            exit;

          { inherit overload }
          if (po_overload in vmtpd.ProcOptions) then
            begin
              include(pd.ProcOptions,po_overload);
              pdoverload:=true;
            end;

          { compare parameter types only, no specifiers yet }
          hasequalpara:=(Compare_Paras(vmtpd.paras,pd.paras,cp_none,[cpo_ignoreuniv,cpo_ignorehidden])>=te_equal);

          { check that we are not trying to override a final method }

          if (po_finalmethod in vmtpd.ProcOptions) and
             hasequalpara and
             ((po_overridingmethod in pd.ProcOptions)) and
             (Is_Class(_class) or Is_ObjectPascal_Helper(_class)) then
            MessagePos1(pd.fileinfo,parser_e_final_can_no_be_overridden,pd.FullProcName(false))
          else
          { old definition has virtual
            new definition has no virtual or override }
          if (po_virtualmethod in vmtpd.ProcOptions) and
             (
              not(po_virtualmethod in pd.ProcOptions) or
              (
               { new one does not have reintroduce in case of an objccategory }
               (Is_ObjCCategory(_class) and
                 not(po_reintroduce in pd.ProcOptions)) or

               ((Is_Class_Or_Interface_Or_ObjC(_class) or Is_ObjectPascal_Helper(_class)) and
                not Is_ObjCCategory(_class) and
                not(po_overridingmethod in pd.ProcOptions)
               )
              )
             ) then
            begin
              if (
                  not(pdoverload or hasoverloads) or
                  hasequalpara
                 ) then
                begin
                  if not(po_reintroduce in pd.ProcOptions) then
                    if not(Is_ObjC_Class_Or_Protocol(_class))
                       then
                      MessagePos1(pd.fileinfo,parser_w_should_use_override,pd.FullProcName(false))
                    else
                      begin

                        if hasequalpara then
                          begin
                            if not(oo_is_external in _class.ObjectOptions) then
                              if not Is_ObjCCategory(_class) then
                                MessagePos1(pd.fileinfo,parser_e_must_use_override,FullTypeName(TDef(vmtpd.owner.DefOwner),nil))
                              else
                                MessagePos1(pd.fileinfo,parser_e_must_use_reintroduce_objc,FullTypeName(TDef(vmtpd.owner.DefOwner),nil))
                            { there may be a lot of these in auto-translated
                              headers, so only calculate the fulltypename if
                              the hint will be shown  }
                            else if CheckVerbosity(VHint) then
                              if not Is_ObjCCategory(_class) then
                                MessagePos1(pd.fileinfo,parser_h_should_use_override,FullTypeName(TDef(vmtpd.owner.DefOwner),nil))
                              else
                                MessagePos1(pd.fileinfo,parser_h_should_use_reintroduce_objc,FullTypeName(TDef(vmtpd.owner.DefOwner),nil));
                          end;
                        { no new entry, but copy the message name if any from
                          the procdef in the parent class }
                        if not Is_ObjC_Class_Or_Protocol(_class) or
                           hasequalpara then
                          check_msg_str(vmtpd,pd);
                        if updatevalues then
                          begin

                            { in case we are overriding an abstract method,
                              decrease the number of abstract methods in this class }
                            if (po_abstractmethod in vmtpd.ProcOptions) then
                              dec(TObjectDef(pd.owner.DefOwner).AbstractCnt);
                            if (vmtpd.ExtNumber<>i) then
                              InternalError(2011083101);
                            pd.ExtNumber:=vmtpd.ExtNumber;
                            vmtpd:=pd;
                          end;
                        result:=true;
                        exit;
                      end;
                  { disable/hide old VMT entry }
                  if updatevalues then
                    vmtentryvis:=vis_hidden;
                end;
            end
          { both are virtual? }
          else if (po_virtualmethod in pd.ProcOptions) and
                  (po_virtualmethod in vmtpd.ProcOptions) then
            begin
              { same parameter and return types (parameter specifiers will be checked below) }
              if hasequalpara and
                 Compatible_ChildMethod_ResultDef(vmtpd.ReturnDef,pd.ReturnDef) then
                begin
                  { inherit calling convention when it was explicit and the
                    current definition has none explicit set }
                  if (po_hascallingconvention in vmtpd.ProcOptions) and
                     not(po_hascallingconvention in pd.ProcOptions) then
                    begin
                      pd.ProcCallOption:=vmtpd.ProcCallOption;
                      include(pd.ProcOptions,po_hascallingconvention);
                    end;

                  { All parameter specifiers and some procedure the flags have to match
                    except abstract and override }
                  if (Compare_Paras(vmtpd.paras,pd.paras,cp_all,[cpo_ignoreuniv,cpo_ignorehidden])<te_equal) or
                     (vmtpd.ProcCallOption<>pd.ProcCallOption) or
                     (vmtpd.ProcTypeOption<>pd.ProcTypeOption) or
                     ((vmtpd.ProcOptions*po_comp)<>(pd.ProcOptions*po_comp)) then
                     begin
                       MessagePos1(pd.fileinfo,parser_e_header_dont_match_forward,pd.FullProcName(false));
                       TProcSym(vmtpd.ProcSym).Write_Parameter_Lists(pd);
                     end;

                  check_msg_str(vmtpd,pd);

                  { Give a note if the new visibility is lower. For a higher
                    visibility update the vmt info }
                  if vmtentryvis>pd.visibility then
                    begin
                      MessagePos4(pd.fileinfo,parser_n_ignore_lower_visibility,
                          pd.FullProcName(false),
                          VisibilityName[pd.visibility],TObjectDef(vmtpd.owner.DefOwner).ObjRealName^,VisibilityName[vmtentryvis])
                      end
                  else if pd.visibility>vmtentryvis then
                    begin
                      if updatevalues then
                        vmtentryvis:=pd.visibility;
                    end;

                  { override old virtual method in VMT }
                  if updatevalues then
                    begin
                      { in case we are overriding an abstract method,
                        decrease the number of abstract methods in this class }
                      if (po_overridingmethod in pd.ProcOptions) and
                         (po_abstractmethod in vmtpd.ProcOptions) then
                        dec(TObjectDef(pd.owner.DefOwner).AbstractCnt);

                      if (vmtpd.ExtNumber<>i) then
                        InternalError(200611084);
                      pd.ExtNumber:=vmtpd.ExtNumber;

                      vmtpd:=pd;
                    end;
                  result:=true;
                  exit;
                end
              { different parameters }
              else
               begin
                 { when we got an override directive then can search further for
                   the procedure to override.
                   If we are starting a new virtual tree then hide the old tree }
                 if not(po_overridingmethod in pd.ProcOptions) and
                    not(pdoverload or hasoverloads) then
                   begin
                     if not(po_reintroduce in pd.ProcOptions) then
                       begin
                         if not Is_Object(_class) and
                            not Is_ObjC_Class_Or_Protocol(_class) then
                           MessagePos1(pd.fileinfo,parser_w_should_use_override,pd.FullProcName(false))
                         else

                           MessagePos1(pd.fileinfo,parser_e_header_dont_match_forward,vmtpd.FullProcName(false));
                       end;
                     { disable/hide old VMT entry }
                     if updatevalues then
                       vmtentryvis:=vis_hidden;
                   end;
               end;
            end;
        end;

        function found_category_method(st: TSymTable): boolean;
          var
            entrycount: LongInt;
            cat: TObjectDef;
            vmtpd: TProcDef;
            vmtvis: TVisibility;
          begin
            result:=false;
            if Is_ObjCCategory(TDef(st.DefOwner)) then
              begin
                cat:=TObjectDef(st.DefOwner);
                { go through all of the category's methods to find the
                  vmtentry corresponding to the procdef we are handling }
                for entrycount:=0 to cat.VMTEntries.Count-1 do
                  begin
                    vmtpd:=PVMTEntry(cat.VMTEntries[entrycount])^.procdef;
                    vmtvis:=PVMTEntry(cat.VMTEntries[entrycount])^.visibility;
                    { don't change the vmtentry of the category }
                    if found_entry(vmtpd,vmtvis,false) then
                      begin
                        result:=true;
                        exit;
                      end;
                  end;
              end;
          end;

      begin
        result:=false;
        overridesclasshelper:=false;
        { Load other values for easier readability }
        hasoverloads:=(TProcSym(pd.ProcSym).ProcdefList.Count>1);
        pdoverload:=(po_overload in pd.ProcOptions);

        { compare with all stored definitions }
        for i:=0 to _class.VMTEntries.Count-1 do
          begin
            if found_entry(PVMTEntry(_class.VMTEntries[i])^.procdef, PVMTEntry(_class.VMTEntries[i])^.visibility,true) then
              exit;
          end;

        { in case of Objective-C, also check the categories that apply to this
          class' *parent* for methods to override (don't allow class X to
          "override" a method added by a category to class X itself, since in
          that case the category method will in fact replace class X'
          "overriding" method }
        if Is_ObjCClass(_class) and
           Assigned(_class.ChildOf) and
           Search_ObjC_Helper(_class.ChildOf,pd.ProcSym.name,srsym,st) then
          begin
            overridesclasshelper:=found_category_method(st);
          end;

        { No entry found, we need to create a new entry }
        result:=true;
      end;


    function TVMTBuilder.intf_search_procdef_by_name(proc: TProcDef;const name: string): TProcDef;
      const
        po_comp = [po_classmethod,po_staticmethod,po_interrupt,po_iocheck,po_msgint,
                   po_exports,po_varargs,po_explicitparaloc,po_nostackframe];
      var
        implprocdef : TProcDef;
        i: cardinal;
        hclass : TObjectDef;
        hashedid : THashedIDString;
        srsym      : TSym;
        overload: boolean;
      begin
        result:=nil;
        hashedid.id:=name;
        hclass:=_class;
        while Assigned(hclass) do
          begin
            srsym:=TSym(hclass.SymTable.FindWithHash(hashedid));
            if Assigned(srsym) and
               (srsym.typ=ProcSym) and
               ((hclass=_class) or
                Is_Visible_For_Object(srsym,_class)) then
              begin
                overload:=false;
                for i:=0 to TProcSym(srsym).ProcdefList.Count-1 do
                  begin
                    implprocdef:=TProcDef(TProcSym(srsym).ProcdefList[i]);
                    if po_overload in implprocdef.ProcOptions then
                      overload:=true;
                    if (implprocdef.ProcSym=TProcSym(srsym)) and
                       (Compare_Paras(proc.paras,implprocdef.paras,cp_all,[cpo_ignorehidden,cpo_ignoreuniv])>=te_equal) and
                       (Compare_Defs(proc.ReturnDef,implprocdef.ReturnDef,nothingn)>=te_equal) and
                       (proc.ProcCallOption=implprocdef.ProcCallOption) and
                       (proc.ProcTypeOption=implprocdef.ProcTypeOption) and
                       ((proc.ProcOptions*po_comp)=((implprocdef.ProcOptions+[po_virtualmethod])*po_comp)) and
                       check_msg_str(proc,implprocdef) then
                      begin
                        { does the interface increase the visibility of the
                          implementing method? }
                        if implprocdef.visibility<proc.visibility then
                          MessagePos2(implprocdef.fileinfo,type_w_interface_lower_visibility,proc.FullProcName(false),implprocdef.FullProcName(false));
                        result:=implprocdef;
                        AddSymRef(result.ProcSym,result);
                        exit;
                      end;
                  end;
                { like with normal procdef resolution (in htypechk), stop if
                  we encounter a proc without the overload directive }
                if not overload then
                  exit;
              end;
            hclass:=hclass.ChildOf;
          end;
      end;


    procedure TVMTBuilder.intf_get_procdefs(ImplIntf:TImplementedInterface;IntfDef:TObjectDef);
      var
        i   : LongInt;
        def : TDef;
        hs,
        prefix,
        mappedname: string;
        implprocdef: TProcDef;
      begin
        prefix:=ImplIntf.IntfDef.SymTable.name^+'.';
        for i:=0 to IntfDef.SymTable.DefList.Count-1 do
          begin
            def:=TDef(IntfDef.SymTable.DefList[i]);
            if Assigned(def) and
               (def.typ=procdef) then
              begin
                { Find implementing procdef
                   1. Check for mapped name
                   2. Use symbol name, but only if there's no mapping,
                      or we're processing ancestor of interface.
                  When modifying this code, ensure that tbs/tb_interfaces_delphi_run_01.pas (case tw11862.pas), tbs/tw4950
                  and webtbf/tw19591 stay correct. }
                implprocdef:=nil;
                hs:=prefix+TProcDef(def).ProcSym.name;
                mappedname:=ImplIntf.GetMapping(hs);
                if mappedname<>'' then
                  implprocdef:=intf_search_procdef_by_name(TProcDef(def),mappedname);
                if not Assigned(implprocdef) then
                  if (mappedname='') or (ImplIntf.IntfDef<>IntfDef) then
                    implprocdef:=intf_search_procdef_by_name(TProcDef(def),TProcDef(def).ProcSym.name);

                { Add procdef to the implemented interface }
                if Assigned(implprocdef) then
                  begin
                    if (TObjectDef(implprocdef.struct).ObjectType<>odt_objcclass) then
                      begin

                        ImplIntf.AddImplProc(implprocdef);
                      end
                    else
                      begin
                        { If no message name has been specified for the method
                          in the objcclass, copy it from the protocol
                          definition.  }
                        if not(po_msgstr in TProcDef(def).ProcOptions) then
                          begin
                            include(TProcDef(def).ProcOptions,po_msgstr);
                            implprocdef.MessageInf.str:=StringDup(TProcDef(def).MessageInf.str^);
                          end
                        else
                          begin
                            { If a message name has been specified in the
                              objcclass, it has to match the message name in the
                              protocol definition.  }
                            if (implprocdef.MessageInf.str^<>TProcDef(def).MessageInf.str^) then
                              MessagePos2(implprocdef.fileinfo,parser_e_objc_message_name_changed,TProcDef(def).MessageInf.str^,implprocdef.MessageInf.str^);
                          end;
                      end;
                  end
                else
                  if (ImplIntf.IType=etStandard) and
                     not(po_optional in TProcDef(def).ProcOptions) then
                    MessagePos1(_Class.TypeSym.fileinfo,sym_e_no_matching_implementation_found,TProcDef(def).FullProcName(false));
              end;
          end;
      end;


    procedure TVMTBuilder.intf_get_procdefs_recursive(ImplIntf:TImplementedInterface;IntfDef:TObjectDef);
      begin
        if Assigned(IntfDef.ChildOf) then
          intf_get_procdefs_recursive(ImplIntf,IntfDef.ChildOf);
        intf_get_procdefs(ImplIntf,IntfDef);
      end;


    procedure TVMTBuilder.prot_get_procdefs_recursive(ImplProt:TImplementedInterface;ProtDef:TObjectDef);
      var
        i: LongInt;
      begin
        { don't check the same protocol twice }
        if handledprotocols.IndexOf(ProtDef)<>-1 then
          exit;
        handledprotocols.add(ProtDef);
        for i:=0 to ProtDef.ImplementedInterfaces.count-1 do
          prot_get_procdefs_recursive(ImplProt,TImplementedInterface(ProtDef.ImplementedInterfaces[i]).intfdef);
        intf_get_procdefs(ImplProt,ProtDef);
      end;


    procedure TVMTBuilder.intf_optimize_vtbls;
      type
        TCompIntfEntry = record
          weight: LongInt;
          compintf: LongInt;
        end;
      var
        aequals: array of LongInt;
        compats: array of TCompIntfEntry;
        impls: array of LongInt;
        ImplIntfCount,
        w,i,j,k: LongInt;
        ImplIntfI,
        ImplIntfJ  : TImplementedInterface;
        cij: boolean;
        cji: boolean;
      begin
        ImplIntfCount:=_class.ImplementedInterfaces.count;
        if ImplIntfCount=0 then
          exit;
        SetLength(compats,ImplIntfCount);
        SetLength(aequals,ImplIntfCount);
        SetLength(impls,ImplIntfCount);
        filldword(compats[0],(sizeof(TCompIntfEntry) div sizeof(dword))*ImplIntfCount,dword(-1));
        filldword(aequals[0],ImplIntfCount,dword(-1));
        filldword(impls[0],ImplIntfCount,dword(-1));
        { ismergepossible is a containing relation
          meaning of ismergepossible(a,b,w) =
          if implementorfunction map of a is contained implementorfunction map of b
          imp(a,b) and imp(b,c) => imp(a,c) ; imp(a,b) and imp(b,a) => a == b
        }
        { the order is very important for correct allocation }
        for i:=0 to ImplIntfCount-1 do
          begin
            for j:=i+1 to ImplIntfCount-1 do
              begin
                ImplIntfI:=TImplementedInterface(_class.ImplementedInterfaces[i]);
                ImplIntfJ:=TImplementedInterface(_class.ImplementedInterfaces[j]);
                cij:=ImplIntfI.IsImplMergePossible(ImplIntfJ,w);
                cji:=ImplIntfJ.IsImplMergePossible(ImplIntfI,w);
                if cij and cji then { i equal j }
                  begin
                    { get minimum index of equal }
                    if aequals[j]=-1 then
                      aequals[j]:=i;
                  end
                else if cij then
                  begin
                    { get minimum index of maximum weight  }
                    if compats[i].weight<w then
                      begin
                        compats[i].weight:=w;
                        compats[i].compintf:=j;
                      end;
                  end
                else if cji then
                  begin
                    { get minimum index of maximum weight  }
                    if (compats[j].weight<w) then
                      begin
                        compats[j].weight:=w;
                        compats[j].compintf:=i;
                      end;
                  end;
              end;
          end;
        { Reset, no replacements by default }
        for i:=0 to ImplIntfCount-1 do
          impls[i]:=i;
        { Replace vtbls when equal or compat, repeat
          until there are no replacements possible anymore. This is
          needed for the cases like:
            First loop: 2->3, 3->1
            Second loop: 2->1 (because 3 was replaced with 1)
        }
        repeat
          k:=0;
          for i:=0 to ImplIntfCount-1 do
            begin
              if compats[impls[i]].compintf<>-1 then
                impls[i]:=compats[impls[i]].compintf
              else if aequals[impls[i]]<>-1 then
                impls[i]:=aequals[impls[i]]
              else
                inc(k);
            end;
        until k=ImplIntfCount;
        { Update the VtblImplIntf }
        for i:=0 to ImplIntfCount-1 do
          begin
            ImplIntfI:=TImplementedInterface(_class.ImplementedInterfaces[i]);
            ImplIntfI.VtblImplIntf:=TImplementedInterface(_class.ImplementedInterfaces[impls[i]]);
          end;
      end;


    procedure TVMTBuilder.intf_allocate_vtbls;
      var
        i : LongInt;
        ImplIntf : TImplementedInterface;
      begin
        { Allocation vtbl space }
        for i:=0 to _class.ImplementedInterfaces.count-1 do
          begin
            ImplIntf:=TImplementedInterface(_class.ImplementedInterfaces[i]);
            { if it implements itself and if it's not implemented by delegation }
            if (ImplIntf.VtblImplIntf=ImplIntf) and (ImplIntf.IType=etStandard) then
              begin
                { allocate a pointer in the object memory }
                with TObjectSymTable(_class.SymTable) do
                  begin
                    DataSize:=align(DataSize,VoidPointerType.Alignment);
                    ImplIntf.Ioffset:=DataSize;
                    DataSize:=DataSize+VoidPointerType.Size;
                  end;
              end;
          end;
        { Update ioffset of current interface with the ioffset from
          the interface that is reused to implements this interface }
        for i:=0 to _class.ImplementedInterfaces.count-1 do
          begin
            ImplIntf:=TImplementedInterface(_class.ImplementedInterfaces[i]);
            if ImplIntf.VtblImplIntf<>ImplIntf then
              ImplIntf.IOffset:=ImplIntf.VtblImplIntf.IOffset;
          end;
      end;


    procedure TVMTBuilder.create_vmt_def;
      var
        i: LongInt;
        vmtdef: TRecordDef;
        systemvmt: TDef;
        sym: TSym;
      begin
        { these types don't have an actual VMT, we only use the other methods
          in TVMTBuilder to determine duplicates/overrides }
        if _class.ObjectType in [
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
        if df_generic in _class.DefOptions then
          exit;

        { todo in the future }
        if _class.ObjectType = odt_cppclass then
          exit;

        { create VMT type definition }
        vmtdef:=CRecordDef.Create_Internal(
          '$vmtdef',
          0,
          TargetInfo.Alignment.RecordAlignMin,
          _class.SymTable);

        { standard VMT fields }
        case _Class.ObjectType of
          odt_class:
            begin
              systemvmt:=Search_System_Type('TVMT').typedef;
              if not Assigned(systemvmt) then
                Message1(cg_f_internal_type_not_found,'TVMT');

              { does the TVMT type look like we expect? (so that this code is
                easily triggered in case the definition of the VMT would
                change) }
              if (systemvmt.typ<>recorddef) or
                 (TRecordDef(systemvmt).SymTable.SymList.count<>27) then
                Message1(cg_f_internal_type_does_not_match,'TVMT');
              { system.tvmt is a record that represents the VMT of TObject,
                including its virtual methods. We only want the non-method
                fields, as the methods will be added automatically based on
                the VMT we generated here only add the 12 first fields }
              for i:=0 to 11 do
                begin
                  sym:=TSym(TRecordDef(systemvmt).SymTable.SymList[i]);
                  if sym.typ in [ProcSym,propertysym] then
                    continue;
                  if sym.typ<>FieldVarSym then
                    InternalError(2015052602);
                  vmtdef.Add_Field_By_Def('',TFieldVarSym(sym).vardef);
                end;
            end;
           odt_interfacecom,odt_interfacecorba,odt_dispinterface:
             { nothing }
             ;
          odt_object:
            begin
              { size, -size, parent vmt [, dmt ] (same names as for class) }
              vmtdef.Add_Field_By_Def('vInstanceSize',SizeSIntType);
              vmtdef.Add_Field_By_Def('vInstanceSize2',SizeSIntType);
              vmtdef.Add_Field_By_Def('vParent',VoidPointerType);
{$ifdef WITHDMT}
              vmtdef.Add_Field_By_Def('',VoidPointerType);
{$endif WITHDMT}
            end;
          else
            InternalError(2015052605);
        end;

        { now add the methods }
        for i:=0 to _class.VMTEntries.count-1 do
          vmtdef.Add_Field_By_Def('',
            CProcVarDef.GetReusableProcAddr(PVMTEntry(_class.VMTEntries[i])^.procdef,pc_address_only)
          );
        { the VMT ends with a nil pointer }
        vmtdef.Add_Field_By_Def('',VoidCodePointerType);
      end;


    procedure TVMTBuilder.build;
      var
        i : LongInt;
        def : TDef;
        old_current_structdef : TAbstractRecordDef;
        overridesclasshelper : boolean;
      begin
        old_current_structdef:=CurrentStructDef;
        CurrentStructDef:=_class;

        { inherit (copy) VMT from parent object }
        if Assigned(_class.ChildOf) then
          _class.CopyVMTEntries(_class.ChildOf);

        { process all procdefs, we must process the defs to
          keep the same order as that is written in the source
          to be compatible with the indexes in the interface vtable (PFV) }
        for i:=0 to _class.SymTable.DefList.Count-1 do
          begin
            def:=TDef(_class.SymTable.DefList[i]);
            if def.typ=procdef then
              begin
                { VMT entry }
                if is_new_vmt_entry(TProcDef(def),overridesclasshelper) then
                  add_new_vmt_entry(TProcDef(def),overridesclasshelper);
              end;
          end;
        insert_struct_hidden_paras(_class);
        build_interface_mappings;
        if Assigned(_class.ImplementedInterfaces) and
           not(Is_ObjC_Class_Or_Protocol(_class)) then
          begin
            { Optimize interface tables to reuse wrappers }
            intf_optimize_vtbls;
            { Allocate interface tables }
            intf_allocate_vtbls;
          end;
        create_vmt_def;
        CurrentStructDef:=old_current_structdef;
      end;


    procedure TVMTBuilder.build_interface_mappings;
      var
        ImplIntf : TImplementedInterface;
        i: LongInt;
      begin

        if Assigned(_class.ImplementedInterfaces) and
           not(_class.ObjectType in [odt_objcprotocol]) then
          begin
            { Collect implementor functions into the tImplementedInterface.procdefs }
            case _class.ObjectType of
              odt_class:
                begin
                  for i:=0 to _class.ImplementedInterfaces.count-1 do
                    begin
                      ImplIntf:=TImplementedInterface(_class.ImplementedInterfaces[i]);
                      intf_get_procdefs_recursive(ImplIntf,ImplIntf.IntfDef)
                    end;
                end;
              odt_objcclass:
                begin

                  handledprotocols:=TFPObjectList.create(false);
                  for i:=0 to _class.ImplementedInterfaces.count-1 do
                    begin
                      ImplIntf:=TImplementedInterface(_class.ImplementedInterfaces[i]);
                      prot_get_procdefs_recursive(ImplIntf,ImplIntf.IntfDef);
                    end;
                  handledprotocols.free;
                  handledprotocols := nil;
                end
              else
                InternalError(2009091801);
            end
          end;
      end;


    procedure build_vmt(def:TObjectDef);
      var
        vmtbuilder : TVMTBuilder;
      begin
        vmtbuilder:=TVMTBuilder.create(def);
        vmtbuilder.build;
        vmtbuilder.free;
        vmtbuilder := nil;
      end;

end.
