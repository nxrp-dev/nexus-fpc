{
    Copyright (c) 2008 by Jonas Maebe

    Virtual methods optimizations (devirtualization)

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
unit optvirt;

{$i fpcdefs.inc}

  interface

    uses
      GlobType,
      CClasses,
      symtype,symdef,
      wpobase;

    type
       { node in an inheritance tree, contains a link to the parent type (if any) and to all
        child types
      }
      TInheritanceTreeNode = class
       private
        fdef: TObjectDef;
        fparent: TInheritanceTreeNode;
        fchilds: TFPObjectList;
        fcalledvmtmethods: TBitSet;
        finstantiated: boolean;

        function getchild(index: LongInt): TInheritanceTreeNode;
       public
        constructor create(_parent: TInheritanceTreeNode; _def: TObjectDef; _instantiated: boolean);
        { destroys both this node and all of its siblings }
        destructor Destroy; override;
        function  childcount: LongInt;
        function  haschilds: boolean;
        property  childs[index: LongInt]: TInheritanceTreeNode read getchild;
        property  parent: TInheritanceTreeNode read fparent;
        property  def: TObjectDef read fdef;
        property  instantiated: boolean read finstantiated write finstantiated;
        { if def is not yet a child of this node, add it. In all cases, return node containing
          this def (either new or existing one
        }
        function  maybeaddchild(_def: TObjectDef; _instantiated: boolean): TInheritanceTreeNode;
        function  findchild(_def: TObjectDef): TInheritanceTreeNode;
      end;


      TInheritanceTreeCallback = procedure(node: TInheritanceTreeNode; arg: pointer) of object;

      TInheritanceTree = class
       private
        { just a regular node with parent = nil }
        froots: TInheritanceTreeNode;

        classrefdefs: TFPObjectList;

        procedure foreachnodefromroot(root: TInheritanceTreeNode; proctocall: TInheritanceTreeCallback; arg: pointer);
        function registerinstantiatedobjectdefrecursive(def: TObjectDef; instantiated: boolean): TInheritanceTreeNode;
        procedure markvmethods(node: TInheritanceTreeNode; p: pointer);
        procedure printobjectvmtinfo(node: TInheritanceTreeNode; arg: pointer);
        procedure addcalledvmtentries(node: TInheritanceTreeNode; arg: pointer);

        function  getnodefordef(def: TObjectDef): TInheritanceTreeNode;
       public
        constructor create;
        destructor Destroy; override;
        { adds an objectdef (the def itself, and all of its parents that do not yet exist) to
          the tree, and returns the leaf node
        }
        procedure registerinstantiatedobjdef(def: TDef);
        procedure registerinstantiatedclassrefdef(def: TDef);
        procedure registercalledvmtentries(entries: TCalledVMTEntries);
        procedure checkforclassrefinheritance(def: TDef);
        procedure foreachnode(proctocall: TInheritanceTreeCallback; arg: pointer);
        procedure foreachleafnode(proctocall: TInheritanceTreeCallback; arg: pointer);
        procedure optimizevirtualmethods;
        procedure printvmtinfo;
      end;


      { devirtualisation information for a class }

      TClassDevirtInfo = class(TFPHashObject)
       private
        { array (indexed by vmt entry nr) of replacement statically callable method names }
        fstaticmethodnames: TFPList;
        { is this class instantiated by the program? }
        finstantiated: boolean;
        function isstaticvmtentry(vmtindex: LongInt; out replacementname: PShortString): boolean;
       public
        constructor create(hashobjectlist:TFPHashObjectList;const n: shortstring; instantiated: boolean);
        destructor Destroy; override;

        property instantiated: boolean read finstantiated;

        procedure addstaticmethod(vmtindex: LongInt; const replacementname: shortstring);
      end;


      { devirtualisation information for all classes in a unit }

      TUnitDevirtInfo = class(TFPHashObject)
       private
        { hashtable of classes }
        fclasses: TFPHashObjectList;
       public
        constructor create(hashobjectlist:TFPHashObjectList;const n: shortstring);reintroduce;
        destructor Destroy; override;

        function addclass(const n: shortstring; instantiated: boolean): TClassDevirtInfo;
        function findclass(const n: shortstring): TClassDevirtInfo;
      end;

      { devirtualisation information for all units in a program }

      { tprogdevirtinfo }

      TProgDevirtInfo = class(TWPODevirtualisationHandler)
       private
        { hashtable of tunitdevirtinfo (which contain tclassdevirtinfo) }
        funits: TFPHashObjectList;

        procedure converttreenode(node: TInheritanceTreeNode; arg: pointer);
        function addunitifnew(const n: shortstring): TUnitDevirtInfo;
        function findunit(const n: shortstring): TUnitDevirtInfo;
        function getstaticname(forvmtentry: boolean; objdef, procdef: TDef; out staticname: TSymStr): boolean;
        procedure documentformat(writer: TWPOSectionWriterIntf);
       public
        constructor create; override;
        destructor Destroy; override;

        class function getwpotype: TWPOType; override;
        class function generatesinfoforwposwitches: TWPOptimizerSwitches; override;
        class function performswpoforswitches: TWPOptimizerSwitches; override;
        class function sectionname: shortstring; override;

        { information collection }
        procedure constructfromcompilerstate; override;
        procedure storewpofilesection(writer: TWPOSectionWriterIntf); override;

        { information providing }
        procedure loadfromwpofilesection(reader: TWPOSectionReaderIntf); override;
        function staticnameforcallingvirtualmethod(objdef, procdef: TDef; out staticname: TSymStr): boolean; override;
        function staticnameforvmtentry(objdef, procdef: TDef; out staticname: TSymStr): boolean; override;

      end;


  implementation

    uses
      CUtils,
      FModule,
      symconst,
      SymBase,
      defcmp,
      Verbose;

    const
      DEVIRT_SECTION_NAME = 'contextinsensitive_devirtualization';

   { *************************** tinheritancetreenode ************************* }

    constructor TInheritanceTreeNode.create(_parent: TInheritanceTreeNode; _def: TObjectDef; _instantiated: boolean);
      begin
        fparent:=_parent;
        fdef:=_def;
        finstantiated:=_instantiated;
        if Assigned(_def) then
          fcalledvmtmethods:=TBitSet.create(_def.VMTEntries.count);
      end;


    destructor TInheritanceTreeNode.Destroy;
      begin
        { fchilds owns its members, so it will free them too }
        fchilds.free;
        fchilds:=nil;
        fcalledvmtmethods.free;
        fcalledvmtmethods:=nil;
        inherited Destroy;
      end;


    function TInheritanceTreeNode.childcount: LongInt;
      begin
        if Assigned(fchilds) then
          result:=fchilds.count
        else
          result:=0;
      end;


    function TInheritanceTreeNode.haschilds: boolean;
      begin
        result:=Assigned(fchilds)
      end;


    function TInheritanceTreeNode.getchild(index: LongInt): TInheritanceTreeNode;
      begin
        result:=TInheritanceTreeNode(fchilds[index]);
      end;


    function TInheritanceTreeNode.maybeaddchild(_def: TObjectDef; _instantiated: boolean): TInheritanceTreeNode;
      begin
        { sanity check }
        if Assigned(_def.ChildOf) then
          begin
            if (_def.ChildOf<>def) then
              InternalError(2008092201);
          end
        else if Assigned(fparent) then
          InternalError(2008092202);

        if not Assigned(fchilds) then
          fchilds:=TFPObjectList.create(true);
        { def already a child -> return }
        result:=findchild(_def);
        if Assigned(result) then
          result.finstantiated:=result.finstantiated or _instantiated
        else
          begin
            { not found, add new child }
            result:=TInheritanceTreeNode.create(self,_def,_instantiated);
            fchilds.add(result);
          end;
      end;


    function TInheritanceTreeNode.findchild(_def: TObjectDef): TInheritanceTreeNode;
      var
        i: LongInt;
      begin
        result:=nil;
        if Assigned(fchilds) then
          for i := 0 to fchilds.count-1 do
            if (TInheritanceTreeNode(fchilds[i]).def=_def) then
              begin
                result:=TInheritanceTreeNode(fchilds[i]);
                break;
              end;
      end;

    { *************************** tinheritancetree ************************* }

    constructor TInheritanceTree.create;
      begin
        froots:=TInheritanceTreeNode.create(nil,nil,false);
        classrefdefs:=TFPObjectList.create(false);
      end;


    destructor TInheritanceTree.Destroy;
      begin
        froots.free;
        froots:=nil;
        classrefdefs.free;
        classrefdefs:=nil;
        inherited Destroy;
      end;


    function TInheritanceTree.registerinstantiatedobjectdefrecursive(def: TObjectDef; instantiated: boolean): TInheritanceTreeNode;
      begin
        if Assigned(def.ChildOf) then
          begin
            { recursively add parent, of which we have no info about whether or not it is
              instantiated at this point -> default to false (will be overridden by "true"
              if this class is instantiated, since then registerinstantiatedobjdef() will
              be called for this class as well)
            }
            result:=registerinstantiatedobjectdefrecursive(def.ChildOf,false);
            { and add ourselves to the parent }
            result:=result.maybeaddchild(def,instantiated);
          end
        else
          { add ourselves to the roots }
          result:=froots.maybeaddchild(def,instantiated);
      end;


    procedure TInheritanceTree.registerinstantiatedobjdef(def: TDef);
      begin
        { add the def }
        if (def.typ=objectdef) then
          registerinstantiatedobjectdefrecursive(TObjectDef(def),true)
        else
          InternalError(2008092401);
      end;


    procedure TInheritanceTree.registerinstantiatedclassrefdef(def: TDef);
      begin
        { queue for later checking (these are the objectdefs
          to which the classrefdefs point) }
        if (def.typ=objectdef) then
          classrefdefs.add(def)
        else
          InternalError(2008101401);
      end;


    function TInheritanceTree.getnodefordef(def: TObjectDef): TInheritanceTreeNode;
      begin
        if Assigned(def.ChildOf) then
          begin
            result:=getnodefordef(def.ChildOf);
            if Assigned(result) then
              result:=result.findchild(def);
          end
        else
          result:=froots.findchild(def);
      end;


    procedure TInheritanceTree.registercalledvmtentries(entries: TCalledVMTEntries);
      var
        node: TInheritanceTreeNode;
      begin
        node:=getnodefordef(TObjectDef(entries.objdef));
        { it's possible that no instance of this class or its descendants are
          instantiated
        }
        if not Assigned(node) then
          exit;
        { now mark these methods as (potentially) called for this type and for
          all of its descendants
        }
        addcalledvmtentries(node,entries.calledentries);
        foreachnodefromroot(node,@addcalledvmtentries,entries.calledentries);
      end;


   procedure TInheritanceTree.checkforclassrefinheritance(def: TDef);
     var
       i: LongInt;
     begin
       if (def.typ=objectdef) then
         begin
{$ifdef debug_devirt}
           write('   Checking for classrefdef inheritance of ',def.TypeName);
{$endif debug_devirt}
           for i:=0 to classrefdefs.count-1 do
             if Def_Is_Related(TObjectDef(def),TObjectDef(classrefdefs[i])) then
               begin
{$ifdef debug_devirt}
                 WriteLn('... Found: inherits from Class Of ',TObjectDef(classrefdefs[i]).TypeName);
{$endif debug_devirt}
                 registerinstantiatedobjdef(def);
                 exit;
               end;
{$ifdef debug_devirt}
           WriteLn('... Not found!');
{$endif debug_devirt}
         end;
     end;


    procedure TInheritanceTree.foreachnodefromroot(root: TInheritanceTreeNode; proctocall: TInheritanceTreeCallback; arg: pointer);

      procedure process(const node: TInheritanceTreeNode);
        var
         i: LongInt;
        begin
          for i:=0 to node.childcount-1 do
            if node.childs[i].haschilds then
              begin
                proctocall(node.childs[i],arg);
                process(node.childs[i])
              end
            else
              proctocall(node.childs[i],arg);
        end;

      begin
        process(root);
      end;


    procedure TInheritanceTree.foreachnode(proctocall: TInheritanceTreeCallback; arg: pointer);
      begin
        foreachnodefromroot(froots,proctocall,arg);
      end;


    procedure TInheritanceTree.foreachleafnode(proctocall: TInheritanceTreeCallback; arg: pointer);

      procedure process(const node: TInheritanceTreeNode);
        var
         i: LongInt;
        begin
          for i:=0 to node.childcount-1 do
            if node.childs[i].haschilds then
              process(node.childs[i])
            else
              proctocall(node.childs[i],arg);
        end;

      begin
        process(froots);
      end;


    procedure TInheritanceTree.markvmethods(node: TInheritanceTreeNode; p: pointer);
      var
        currnode: TInheritanceTreeNode;
        pd: TProcDef;
        i: LongInt;
        makeallvirtual: boolean;
      begin
        {$IFDEF DEBUG_DEVIRT}
        WriteLn('processing leaf node ',node.def.TypeName);
        {$ENDIF}
        { todo: also process interfaces (ImplementedInterfaces) }
        if (node.def.VMTEntries.count=0) then
          exit;
        { process all vmt entries for this class/object }
        for i:=0 to node.def.VMTEntries.count-1 do
          begin
            currnode:=node;
            { extra tprocdef(tobject(..)) typecasts so that -CR can catch
              errors in case the vmtentries are not properly (re)deref'd }
            pd:=TProcDef(tobject(PVMTEntry(currnode.def.VMTEntries[i])^.procdef));
            { abstract methods cannot be called directly }
            if (po_abstractmethod in pd.ProcOptions) then
              continue;
            {$IFDEF DEBUG_DEVIRT}
            WriteLn('  method ',pd.TypeName);
            {$ENDIF}
            { Now mark all virtual methods static that are the same in parent
              classes as in this instantiated child class (only instantiated
              classes can be leaf nodes, since only instantiated classes were
              added to the tree).
              If a first child does not override a parent method while a
              a second one does, the first will mark it as statically
              callable, but the second will set it to not statically callable.
              In the opposite situation, the first will mark it as not
              statically callable and the second will leave it alone.
            }
            makeallvirtual:=false;
            repeat
              if { stop when this method does not exist in a parent }
                 (currnode.def.VMTEntries.count<=i) then
                break;

              if not Assigned(currnode.def.VMCallStaticInfo) then
                currnode.def.VMCallStaticInfo:=allocmem(currnode.def.VMTEntries.count*sizeof(TVMCallStatic));
              { if this method cannot be called, we can just mark it as
                unreachable. This will cause its static name to be set to
                FPC_ABSTRACTERROR later on. Exception: published methods are
                always reachable (via RTTI).
              }
              if (pd.visibility<>vis_published) and
                 not(currnode.fcalledvmtmethods.IsSet(i)) then
                begin
                  currnode.def.VMCallStaticInfo^[i]:=vmcs_unreachable;
                  currnode:=currnode.parent;
                end
              { same procdef as in all instantiated childs? (yes or don't know) }
              else if (currnode.def.VMCallStaticInfo^[i] in [vmcs_default,vmcs_yes]) then
                begin
                  { methods in uninstantiated classes can be made static if
                    they are the same in all instantiated derived classes
                  }
                  if ((PVMTEntry(currnode.def.VMTEntries[i])^.procdef=pd) or
                      (not currnode.instantiated and
                       (currnode.def.VMCallStaticInfo^[i]=vmcs_default))) and
                      not makeallvirtual then
                    begin
                      {$IFDEF DEBUG_DEVIRT}
                      WriteLn('    marking as static for ',currnode.def.TypeName);
                      {$ENDIF}
                      currnode.def.VMCallStaticInfo^[i]:=vmcs_yes;
                      { this is in case of a non-instantiated parent of an instantiated child:
                        the method declared in the child will always be called here
                      }
                      PVMTEntry(currnode.def.VMTEntries[i])^.procdef:=pd;
                    end
                  else
                    begin
                      {$IFDEF DEBUG_DEVIRT}
                      WriteLn('    marking as non-static for ',currnode.def.TypeName);
                      {$ENDIF}
                      { this vmt entry must also remain virtual for all parents }
                      makeallvirtual:=true;
                      currnode.def.VMCallStaticInfo^[i]:=vmcs_no;
                    end;
                  currnode:=currnode.parent;
                end
              else if (currnode.def.VMCallStaticInfo^[i]=vmcs_no) then
                begin
                  {$IFDEF DEBUG_DEVIRT}
                  WriteLn('    not processing parents, already non-static for ',currnode.def.TypeName);
                  {$ENDIF}
                  { parents are already set to vmcs_no, so no need to continue }
                  currnode:=nil;
                end
              else
                currnode:=currnode.parent;
            until not Assigned(currnode) or
                  not Assigned(currnode.def);
          end;
      end;


    procedure TInheritanceTree.optimizevirtualmethods;
      begin
        foreachleafnode(@markvmethods,nil);
      end;


    procedure TInheritanceTree.printobjectvmtinfo(node: TInheritanceTreeNode; arg: pointer);
      var
        i,
        totaldevirtualised,
        totalvirtual,
        totalunreachable: ptrint;
      begin
        totaldevirtualised:=0;
        totalvirtual:=0;
        totalunreachable:=0;
        WriteLn(node.def.TypeName);
        if (node.def.VMTEntries.count=0) then
          begin
            WriteLn('  No virtual methods!');
            exit;
          end;
        for i:=0 to node.def.VMTEntries.count-1 do
          if (po_virtualmethod in PVMTEntry(node.def.VMTEntries[i])^.procdef.ProcOptions) then
            begin
              inc(totalvirtual);
              if (node.def.VMCallStaticInfo^[i]=vmcs_yes) then
                begin
                  inc(totaldevirtualised);
                  WriteLn('  Devirtualised: ',PVMTEntry(node.def.VMTEntries[i])^.procdef.TypeName);
                end
              else if (node.def.VMCallStaticInfo^[i]=vmcs_unreachable) then
                begin
                  inc(totalunreachable);
                  WriteLn('   Unreachable: ',PVMTEntry(node.def.VMTEntries[i])^.procdef.TypeName);
                end;
            end;
        WriteLn('Total devirtualised/unreachable/all: ',totaldevirtualised,'/',totalunreachable,'/',totalvirtual);
        WriteLn;
      end;


    procedure TInheritanceTree.addcalledvmtentries(node: TInheritanceTreeNode; arg: pointer);
      var
        VMTEntries: TBitSet absolute arg;
      begin
        node.fcalledvmtmethods.AddSet(VMTEntries);
      end;


    procedure TInheritanceTree.printvmtinfo;
      begin
        foreachnode(@printobjectvmtinfo,nil);
      end;


    { helper routines: decompose an object & procdef combo into a unitname, class name and vmtentry number
      (unit name where the objectdef is declared, class name of the objectdef, vmtentry number of the
       procdef -- procdef does not necessarily belong to objectdef, it may also belong to a descendant
       or parent). classprefix is set in case of nested classes.
    }

    procedure defunitclassname(objdef: TObjectDef; out unitname, classname: PShortString; out classprefix: shortstring);
      const
        mainprogname: string[2] = 'P$';
      var
        mainsymtab,
        objparentsymtab : TSymTable;
      begin
        objparentsymtab:=objdef.SymTable;
        mainsymtab:=objparentsymtab.DefOwner.owner;
        classprefix:='';
        while mainsymtab.SymTableType in [recordsymtable,objectsymtable,LocalSymTable] do
          begin
            classprefix:=mainsymtab.name^+'.'+classprefix;
            mainsymtab:=mainsymtab.DefOwner.owner;
          end;
        { main symtable must be static or global }
        if not(mainsymtab.SymTableType in [staticsymtable,GlobalSymTable]) then
         InternalError(200204177);
        if (TSymTable(Main_Module.LocalSymTable)=mainsymtab) and
            (not Main_Module.IsUnit) then
           { same convention as for mangled names }
          unitname:=@mainprogname
        else
          unitname:=mainsymtab.name;
        classname:=TObjectDef(objparentsymtab.DefOwner).ObjName;
      end;


    procedure defsdecompose(objdef: TObjectDef; procdef: TProcDef; out unitname, classname: PShortString; out classprefix: shortstring; out vmtentry: LongInt);
      begin
        defunitclassname(objdef,unitname,classname,classprefix);
        vmtentry:=procdef.ExtNumber;
        { if it's $ffff, this is not a valid virtual method }
        if (vmtentry=$ffff) then
          InternalError(2008100509);
      end;


   { tclassdevirtinfo }

    constructor TClassDevirtInfo.create(hashobjectlist:TFPHashObjectList;const n: shortstring; instantiated: boolean);
      begin
        inherited create(hashobjectlist,n);
        finstantiated:=instantiated;
        fstaticmethodnames:=TFPList.create;
      end;

    destructor TClassDevirtInfo.Destroy;
      var
        i: LongInt;
      begin
        for i:=0 to fstaticmethodnames.count-1 do
          if Assigned(fstaticmethodnames[i]) then
            FreeMem(fstaticmethodnames[i]);
        fstaticmethodnames.free;
        fstaticmethodnames:=nil;
        inherited Destroy;
      end;

    procedure TClassDevirtInfo.addstaticmethod(vmtindex: LongInt;
      const replacementname: shortstring);
      begin
        if (vmtindex>=fstaticmethodnames.count) then
          fstaticmethodnames.Count:=vmtindex+10;
        fstaticmethodnames[vmtindex]:=StringDup(replacementname);
      end;

    function TClassDevirtInfo.isstaticvmtentry(vmtindex: LongInt; out
      replacementname: PShortString): boolean;
      begin
         result:=false;
         if (vmtindex>=fstaticmethodnames.count) then
           exit;

         replacementname:=fstaticmethodnames[vmtindex];
         result:=Assigned(replacementname);
      end;

    { tunitdevirtinfo }

    constructor TUnitDevirtInfo.create(hashobjectlist:TFPHashObjectList;const n: shortstring);
      begin
        inherited create(hashobjectlist,n);
        fclasses:=TFPHashObjectList.create(true);
      end;

    destructor TUnitDevirtInfo.Destroy;
      begin
        fclasses.free;
        fclasses:=nil;
        inherited Destroy;
      end;

    function TUnitDevirtInfo.addclass(const n: shortstring; instantiated: boolean): TClassDevirtInfo;
      begin
        result:=findclass(n);
        { can't have two classes with the same name in a single unit }
        if Assigned(result) then
          InternalError(2008100501);
        result:=TClassDevirtInfo.create(fclasses,n,instantiated);
      end;

    function TUnitDevirtInfo.findclass(const n: shortstring): TClassDevirtInfo;
      begin
        result:=TClassDevirtInfo(fclasses.find(n));
      end;


    { tprogdevirtinfo }

    procedure TProgDevirtInfo.converttreenode(node: TInheritanceTreeNode; arg: pointer);
      var
        i: LongInt;
        classprefix: shortstring;
        unitid, classid: PShortString;
        unitdevirtinfo: TUnitDevirtInfo;
        classdevirtinfo: TClassDevirtInfo;
      begin
        if (not node.instantiated) and
           (node.def.VMTEntries.count=0) then
          exit;
        { always add a class entry for an instantiated class, so we can
          fill the vmt's of non-instantiated classes with calls to
          FPC_ABSTRACTERROR during the optimisation phase
        }
        defunitclassname(node.def,unitid,classid,classprefix);
        unitdevirtinfo:=addunitifnew(unitid^);
        classdevirtinfo:=unitdevirtinfo.addclass(classprefix+classid^,node.instantiated);
        { node.def.vmcallstaticinfo can be nil if the object only has abstract
          virtual methods }
        if (node.def.VMTEntries.count=0) or
            not Assigned(node.def.VMCallStaticInfo) then
          exit;
        for i:=0 to node.def.VMTEntries.count-1 do
          if (po_virtualmethod in PVMTEntry(node.def.VMTEntries[i])^.procdef.ProcOptions) then
            case node.def.VMCallStaticInfo^[i] of
              vmcs_yes:
                begin
                  { add info about devirtualised vmt entry }
                  classdevirtinfo.addstaticmethod(i,PVMTEntry(node.def.VMTEntries[i])^.procdef.MangledName);
                end;
              vmcs_unreachable:
                begin
                  { static reference to FPC_ABSTRACTERROR }
                  classdevirtinfo.addstaticmethod(i,'FPC_ABSTRACTERROR');
                end;
              else
                ;
            end;
      end;


    constructor TProgDevirtInfo.create;
      begin
        inherited create;
      end;


    destructor TProgDevirtInfo.Destroy;
      begin
        funits.free;
        funits:=nil;
        inherited Destroy;
      end;


    class function TProgDevirtInfo.getwpotype: TWPOType;
      begin
        result:=wpo_devirtualization_context_insensitive;
      end;


    class function TProgDevirtInfo.generatesinfoforwposwitches: TWPOptimizerSwitches;
      begin
        result:=[cs_wpo_devirtualize_calls,cs_wpo_optimize_vmts];
      end;


    class function TProgDevirtInfo.performswpoforswitches: TWPOptimizerSwitches;
      begin
        result:=[cs_wpo_devirtualize_calls,cs_wpo_optimize_vmts];
      end;


    class function TProgDevirtInfo.sectionname: shortstring;
      begin
        result:=DEVIRT_SECTION_NAME;
      end;


    procedure TProgDevirtInfo.constructfromcompilerstate;
      var
        hp: TModule;
        i: LongInt;
        inheritancetree: TInheritanceTree;
      begin
         { register all instantiated class/object types }
         hp:=TModule(Loaded_Units.first);
         while Assigned(hp) do
          begin
            if Assigned(hp.WPOInfo.createdobjtypes) then
              for i:=0 to hp.WPOInfo.createdobjtypes.count-1 do
                TDef(hp.WPOInfo.createdobjtypes[i]).RegisterCreatedObjectType;
            if Assigned(hp.WPOInfo.createdclassrefobjtypes) then
              for i:=0 to hp.WPOInfo.createdclassrefobjtypes.count-1 do
                TObjectDef(hp.WPOInfo.createdclassrefobjtypes[i]).RegisterCreatedClassRefType;
            if Assigned(hp.WPOInfo.maybecreatedbyclassrefdeftypes) then
              for i:=0 to hp.WPOInfo.maybecreatedbyclassrefdeftypes.count-1 do
                TObjectDef(hp.WPOInfo.maybecreatedbyclassrefdeftypes[i]).Register_Maybe_Created_Object_Type;
            hp:=TModule(hp.next);
          end;
         inheritancetree:=TInheritanceTree.create;

         { add all constructed class/object types to the tree }
{$IFDEF DEBUG_DEVIRT}
         WriteLn('constructed object/class/classreftypes in ',CurrentModule.RealModuleName^);
{$ENDIF}
         for i := 0 to CurrentModule.WPOInfo.createdobjtypes.count-1 do
           begin
             inheritancetree.registerinstantiatedobjdef(TDef(CurrentModule.WPOInfo.createdobjtypes[i]));
{$IFDEF DEBUG_DEVIRT}
             write('  ',TDef(CurrentModule.WPOInfo.createdobjtypes[i]).GetTypeName);
{$ENDIF}
             case TDef(CurrentModule.WPOInfo.createdobjtypes[i]).typ of
               objectdef:
                 case TObjectDef(CurrentModule.WPOInfo.createdobjtypes[i]).ObjectType of
                   odt_object:
{$IFDEF DEBUG_DEVIRT}
                     WriteLn(' (object)')
{$ENDIF}
                     ;
                   odt_class:
{$IFDEF DEBUG_DEVIRT}
                     WriteLn(' (class)')
{$ENDIF}
                     ;
                   else
                     InternalError(2008092101);
                 end;
               else
                 InternalError(2008092102);
             end;
           end;

         { register all instantiated classrefdefs with the tree }
         for i := 0 to CurrentModule.WPOInfo.createdclassrefobjtypes.count-1 do
           begin
             inheritancetree.registerinstantiatedclassrefdef(TDef(CurrentModule.WPOInfo.createdclassrefobjtypes[i]));
{$IFDEF DEBUG_DEVIRT}
             write('  Class Of ',TDef(CurrentModule.WPOInfo.createdclassrefobjtypes[i]).GetTypeName);
{$ENDIF}
             case TDef(CurrentModule.WPOInfo.createdclassrefobjtypes[i]).typ of
               objectdef:
{$IFDEF DEBUG_DEVIRT}
                 WriteLn(' (classrefdef)')
{$ENDIF}
                 ;
               else
                 InternalError(2008101101);
             end;
           end;


         { now add all objectdefs that are referred somewhere (via a
           loadvmtaddr node) and that are derived from an instantiated
           classrefdef to the tree (as they can, in theory, all
           be instantiated as well)
         }
         for i := 0 to CurrentModule.WPOInfo.maybecreatedbyclassrefdeftypes.count-1 do
           begin
             inheritancetree.checkforclassrefinheritance(TDef(CurrentModule.WPOInfo.maybecreatedbyclassrefdeftypes[i]));
{$IFDEF DEBUG_DEVIRT}
             write('  Class Of ',TDef(CurrentModule.WPOInfo.maybecreatedbyclassrefdeftypes[i]).GetTypeName);
{$ENDIF}
             case TDef(CurrentModule.WPOInfo.maybecreatedbyclassrefdeftypes[i]).typ of
               objectdef:
{$IFDEF DEBUG_DEVIRT}
                 WriteLn(' (classrefdef)')
{$ENDIF}
                 ;
               else
                 InternalError(2008101106);
             end;
           end;

         { add info about called virtual methods }
         hp:=TModule(Loaded_Units.first);
         while Assigned(hp) do
          begin
            if Assigned(hp.WPOInfo.calledvmtentries) then
              for i:=0 to hp.WPOInfo.calledvmtentries.count-1 do
                inheritancetree.registercalledvmtentries(TCalledVMTEntries(hp.WPOInfo.calledvmtentries[i]));
            hp:=TModule(hp.next);
          end;


         inheritancetree.optimizevirtualmethods;
{$ifdef DEBUG_DEVIRT}
         inheritancetree.printvmtinfo;
{$endif DEBUG_DEVIRT}
         inheritancetree.foreachnode(@converttreenode,nil);
         inheritancetree.free;
         inheritancetree:=nil;
      end;


    function TProgDevirtInfo.addunitifnew(const n: shortstring): TUnitDevirtInfo;
      begin
        if Assigned(funits) then
          result:=findunit(n)
        else
          begin
            funits:=TFPHashObjectList.create;
            result:=nil;
          end;
        if not Assigned(result) then
          begin
            result:=TUnitDevirtInfo.create(funits,n);
          end;
      end;


    function TProgDevirtInfo.findunit(const n: shortstring): TUnitDevirtInfo;
      begin
        result:=TUnitDevirtInfo(funits.find(n));
      end;


    procedure TProgDevirtInfo.loadfromwpofilesection(reader: TWPOSectionReaderIntf);
      var
        unitid,
        classid,
        vmtentryname: ShortString;
        VMTType: string[15];
        vmtentrynrstr: string[7];
        classinstantiated: string[1];
        vmtentry, error: LongInt;
        unitdevirtinfo: TUnitDevirtInfo;
        classdevirtinfo: TClassDevirtInfo;
        instantiated: boolean;
      begin
        { format:
            # unitname^
            unit1^
            # classname&
            class1&
            # instantiated?
            1
            # vmt type (base or some interface)
            basevmt
            # vmt entry nr
            0
            # name of routine to call instead
            staticvmtentryforslot0
            5
            staticvmtentryforslot5
            intfvmt1
            0
            staticvmtentryforslot0

            # non-instantiated class (but if we encounter a variable of this
            # type, we can optimise class to vmtentry 1)
            class2&
            0
            basevmt
            1
            staticvmtentryforslot1

            # instantiated class without optimisable virtual methods
            class3&
            1

            unit2^
            1
            class3&
            ...

            currently, only basevmt is supported (no interfaces yet)
        }
        { could be empty if no classes or so }
        if not reader.sectiongetnextline(unitid) then
          exit;
        repeat
          if (unitid='') or
             (unitid[length(unitid)]<>'^') then
            InternalError(2008100502);
          { cut off the trailing ^ }
          SetLength(unitid,length(unitid)-1);
          unitdevirtinfo:=addunitifnew(unitid);
          { now read classes }
          if not reader.sectiongetnextline(classid) then
            InternalError(2008100505);
          repeat
            if (classid='') or
               (classid[length(classid)]<>'&') then
              InternalError(2008100503);
            { instantiated? }
            if not reader.sectiongetnextline(classinstantiated) then
              InternalError(2008101901);
            instantiated:=classinstantiated='1';
            { cut off the trailing & }
            SetLength(classid,length(classid)-1);
            classdevirtinfo:=unitdevirtinfo.addclass(classid,instantiated);
            { last class could be an instantiated class without any
               optimisable methods. }
            if not reader.sectiongetnextline(VMTType) then
              exit;
            { any optimisable virtual methods? }
            if (VMTType<>'') then
              begin
                { interface info is not yet supported }
                if (VMTType<>'basevmt') then
                  InternalError(2008100507);
                { read all vmt entries for this class }
                while reader.sectiongetnextline(vmtentrynrstr) and
                      (vmtentrynrstr<>'') do
                  begin
                    val(vmtentrynrstr,vmtentry,error);
                    if (error<>0) then
                      InternalError(2008100504);
                    if not reader.sectiongetnextline(vmtentryname) or
                       (vmtentryname='') then
                      InternalError(2008100508);
                    classdevirtinfo.addstaticmethod(vmtentry,vmtentryname);
                  end;
              end;
            { end of section -> exit }
            if not(reader.sectiongetnextline(classid)) then
              exit;
          until (classid='') or
                (classid[length(classid)]='^');
          { next unit, or error }
          unitid:=classid;
        until false;
      end;


    procedure TProgDevirtInfo.documentformat(writer: TWPOSectionWriterIntf);
      begin
        writer.sectionputline('# section format:');
        writer.sectionputline('# unit1^');
        writer.sectionputline('# class1&                ; classname&');
        writer.sectionputline('# 1                      ; instantiated or not');
        writer.sectionputline('# basevmt                ; vmt type (base or some interface)');
        writer.sectionputline('# # vmt entry nr');
        writer.sectionputline('# 0                      ; vmt entry nr');
        writer.sectionputline('# staticvmtentryforslot0 ; name or routine to call instead');
        writer.sectionputline('# 5');
        writer.sectionputline('# staticvmtentryforslot5');
        writer.sectionputline('# intfvmt1');
        writer.sectionputline('# 0');
        writer.sectionputline('# staticvmtentryforslot0');
        writer.sectionputline('#');
        writer.sectionputline('# class2&');
        writer.sectionputline('# 0                      ; non-instantiated class (can be variables of this type, e.g. TObject)');
        writer.sectionputline('# basevmt');
        writer.sectionputline('# 1');
        writer.sectionputline('# staticvmtentryforslot1');
        writer.sectionputline('#');
        writer.sectionputline('# class3&                ; instantiated class without optimisable virtual methods');
        writer.sectionputline('# 1');
        writer.sectionputline('#');
        writer.sectionputline('# unit2^');
        writer.sectionputline('# 1');
        writer.sectionputline('# class3&');
        writer.sectionputline('# ...');
        writer.sectionputline('#');
        writer.sectionputline('# currently, only basevmt is supported (no interfaces yet)');
        writer.sectionputline('#');
      end;


    procedure TProgDevirtInfo.storewpofilesection(writer: TWPOSectionWriterIntf);
      var
        unitcount,
        classcount,
        vmtentrycount: LongInt;
        unitdevirtinfo: TUnitDevirtInfo;
        classdevirtinfo: TClassDevirtInfo;
        first: boolean;
      begin
        writer.startsection(DEVIRT_SECTION_NAME);
        { if there are no optimised virtual methods, we have stored no info }
        if not Assigned(funits) then
          exit;
        documentformat(writer);
        for unitcount:=0 to funits.count-1 do
          begin
            unitdevirtinfo:=TUnitDevirtInfo(funits[unitcount]);
            writer.sectionputline(unitdevirtinfo.name+'^');
            for classcount:=0 to unitdevirtinfo.fclasses.count-1 do
              begin
                classdevirtinfo:=TClassDevirtInfo(TUnitDevirtInfo(funits[unitcount]).fclasses[classcount]);
                writer.sectionputline(classdevirtinfo.name+'&');
                writer.sectionputline(ToStr(ord(classdevirtinfo.instantiated)));
                first:=true;
                for vmtentrycount:=0 to classdevirtinfo.fstaticmethodnames.count-1 do
                  if Assigned(classdevirtinfo.fstaticmethodnames[vmtentrycount]) then
                    begin
                      if first then
                        begin
                          writer.sectionputline('basevmt');
                          first:=false;
                        end;
                      writer.sectionputline(ToStr(vmtentrycount));
                      writer.sectionputline(PShortString(classdevirtinfo.fstaticmethodnames[vmtentrycount])^);
                    end;
                writer.sectionputline('');
              end;
          end;
      end;


    function TProgDevirtInfo.getstaticname(forvmtentry: boolean; objdef, procdef: TDef; out staticname: TSymStr): boolean;
      var
        unitid,
        classid,
        newname: PShortString;
        unitdevirtinfo: TUnitDevirtInfo;
        classdevirtinfo: TClassDevirtInfo;
        vmtentry: LongInt;
        realobjdef: TObjectDef;
        classprefix: shortstring;
      begin
         { if we don't have any devirtualisation info, exit }
         if not Assigned(funits) then
           begin
             result:=false;
             exit
           end;
         { class methods are in the regular vmt, so we can handle classrefs
           the same way as plain objectdefs
         }
         if (objdef.typ=classrefdef) then
           realobjdef:=TObjectDef(TClassRefDef(objdef).PointedDef)
         else if (objdef.typ=objectdef) and
            (TObjectDef(objdef).ObjectType in [odt_class,odt_object]) then
           realobjdef:=TObjectDef(objdef)
         else
           begin
             { we don't support interfaces yet }
             result:=false;
             exit;
           end;

         { if it's for a vmtentry of an objdef and the objdef is
           not instantiated, then we can fill the vmt with pointers
           to FPC_ABSTRACTERROR, except for published methods
           (these can be called via rtti, so always have to point
            to the original method)
         }
         if forvmtentry and
            (TProcDef(procdef).visibility=vis_published) then
           begin
             result:=false;
             exit;
           end;

         { get the component names for the class/procdef combo }
         defsdecompose(realobjdef,TProcDef(procdef),unitid,classid,classprefix,vmtentry);

         { If we don't have information about a particular unit/class/method,
           it means that such class cannot be instantiated. So if we are
           looking up information for a vmt entry, we can always safely return
           FPC_ABSTRACTERROR if we do not find anything, unless it's a
           published method (but those are handled already above) or a
           class method (can be called even if the class is not instantiated).
         }
         result:=
           forvmtentry and
           not(po_classmethod in TProcDef(procdef).ProcOptions);
         staticname:='FPC_ABSTRACTERROR';

         { do we have any info for this unit? }
         unitdevirtinfo:=findunit(unitid^);
         if not Assigned(unitdevirtinfo) then
           exit;
         { and for this class? }
         classdevirtinfo:=unitdevirtinfo.findclass(classprefix+classid^);
         if not Assigned(classdevirtinfo) then
           exit;
         if forvmtentry and
            (objdef.typ=objectdef) and
            not classdevirtinfo.instantiated and
            { virtual class methods can be called even if the class is not instantiated }
            not(po_classmethod in TProcDef(procdef).ProcOptions) then
           begin
             { already set above
               staticname:='FPC_ABSTRACTERROR';
             }
             result:=true;
           end
         else
           begin
             { now check whether it can be devirtualised, and if so to what }
             result:=classdevirtinfo.isstaticvmtentry(vmtentry,newname);
             if result then
               staticname:=newname^;
           end;
      end;



    function TProgDevirtInfo.staticnameforcallingvirtualmethod(objdef, procdef: TDef; out staticname: TSymStr): boolean;
      begin
        result:=getstaticname(false,objdef,procdef,staticname);
      end;


    function TProgDevirtInfo.staticnameforvmtentry(objdef, procdef: TDef; out staticname: TSymStr): boolean;
      begin
        result:=getstaticname(true,objdef,procdef,staticname);
      end;

end.
