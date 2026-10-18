{
    Copyright (c) 2018 by Jonas Maebe
    Copyright (c) 2011-2021 by Blaise.ru

    This unit provides helpers for creating procdefs

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
{$i fpcdefs.inc}
unit procdefutil;

interface

uses
  GlobType,ProcInfo,
  SymConst,SymType,SymDef,
  Node,NBas;

{ create a nested procdef that will be used to outline code from a procedure;
  astruct should usually be nil, except in special cases like the Windows SEH
  exception handling funclets }
function Create_Outline_ProcDef(const BaseSymName: string; AStruct: TAbstractRecordDef; POType: TProcTypeOption; ResultDef: TDef): TProcDef;

procedure Convert_To_FuncRef_Intf(const N:TIDString;var Def:TDef);
function Adjust_FuncRef(var Def:TDef;Sym,DummySym:TSym):Boolean;

{ functionality related to capturing local variables for anonymous functions }

function Get_Or_Create_Capturer(PD:TProcDef):TSym;
function Capturer_Add_Anonymous_Proc(Owner:TProcInfo;PD:TProcDef;out Capturer:TSym):TObjectDef;
function Capturer_Add_ProcVar_Or_Proc(Owner:TProcInfo;N:TNode;out Capturer:TSym;out CaptureN:TNode):TObjectDef;
procedure Initialize_Capturer(Ctx:TProcInfo;var Stmt:TStatementNode);
procedure PostProcess_Capturer(Ctx:TProcInfo);
procedure Convert_Captured_Syms(PD:TProcDef;Tree:TNode);

implementation

  uses
    CUtils,CClasses,Verbose,Globals,
    FModule,
    Pass_1,
    NObj,NCal,NMem,NLd,NUtils,
    NGenUtil,
    SymBase,SymSym,SymTable,DefUtil,DefCmp,
    HTypeChk,
    PParaUtl,PSub;


  function Create_Outline_ProcDef(const BaseSymName: string; AStruct: TAbstractRecordDef; POType: TProcTypeOption; ResultDef: TDef): TProcDef;
    var
      ST:TSymTable;
      CheckStack: PSymTableStackItem;
      OldSymTableStack: TSymTableStack;
      Sym:TProcSym;
    begin
      { get actual procedure symtable (skip withsymtables, etc.) }
      ST:=nil;
      CheckStack:=SymTableStack.Stack;
      while Assigned(CheckStack) do
        begin
          ST:=CheckStack^.SymTable;
          if ST.SymTableType in [StaticSymTable,GlobalSymTable,LocalSymTable] then
            Break;
          CheckStack:=CheckStack^.Next;
        end;
      { Create a nested procedure, even from main_program_level.
        Furthermore, force procdef and procsym into the same symtable
        (by default, defs are registered with symtablestack.top which may be
        something temporary like exceptsymtable - in that case, procdef can be
        destroyed before procsym, leaving invalid pointers). }
      OldSymTableStack:=SymTableStack;
      SymTableStack:=nil;
      Result:=CProcDef.Create(Max(NormalFunctionLevel,ST.SymTableLevel)+1,True);
      Result.ReturnDef:=ResultDef;
      { if the parent is a generic or a specialization, the new function is one
        as well }
      if ST.SymTableType=LocalSymTable then
        Result.DefOptions:=Result.DefOptions+(TStoredDef(ST.DefOwner).DefOptions*[df_generic,df_specialization]);
      SymTableStack:=OldSymTableStack;
      ST.InsertDef(Result);
      Result.Struct:=AStruct;
      { tabstractprocdef constructor sets po_delphi_nested_cc whenever
        nested procvars modeswitch is active. We must be independent of this switch. }
      Exclude(Result.ProcOptions,po_delphi_nested_cc);
      Result.ProcTypeOption:=POType;
      { always use the default calling convention }
      Result.ProcCallOption:=pocall_default;
      Include(Result.ProcOptions,po_hascallingconvention);
      handle_calling_convention(Result,hcc_default_actions_impl);
      Sym:=CProcSym.Create(BaseSymName+Result.UniqueIDStr);
      ST.InsertSym(Sym);

      Result.ProcSym:=Sym;
      proc_add_definition(Result);
      { the code will be assigned directly to the "code" field later }
      Result.ForwardDef:=False;
      Result.AliasNames.Insert(Result.MangledName);
    end;


  function FileInfoToSuffix(const FileInfo:TFilePosInfo):TSymStr;inline;
    begin
      Result:=ToStr(FileInfo.ModuleIndex)+'_'+
              ToStr(FileInfo.FileIndex)+'_'+
              ToStr(FileInfo.Line)+'_'+
              ToStr(FileInfo.Column);
    end;


  const
    AnonFuncRefPrefix='$FuncRef_';
    CapturerClassName='$CapturerClass';
    { the leading $ is only added when registering the var symbol }
    CapturerVarName='Capturer';
    KeepAliveSuffix='_keepalive';
    OuterSelfFieldName='OuterSelf';


  procedure Convert_To_FuncRef_Intf(const N:TIDString;var Def:TDef);
    var
      OldSymTableStack : TSymTableStack;
      PVDef : TProcVarDef absolute Def;
      IntfDef : TObjectDef;
      InvokeDef : TProcDef;
      Sym : TSym;
      I : LongInt;
      Name : TIDString;
    begin
      if Def.Typ<>ProcVarDef then
        InternalError(2021040201);
      if not (po_is_function_ref in TProcVarDef(PVDef).ProcOptions) then
        InternalError(2021022101);
      if N='' then
        Name:=AnonFuncRefPrefix+FileInfoToSuffix(CurrentFilePos)
      else
        Name:=N;
      IntfDef:=CObjectDef.Create(odt_interfacecom,Name,Interface_IUnknown,True);
      Include(IntfDef.ObjectOptions,oo_is_funcref);
      Include(IntfDef.ObjectOptions,oo_is_invokable);
      Include(IntfDef.ObjectOptions,oo_has_virtual);
      IntfDef.TypeSym:=PVDef.TypeSym;
      PVDef.TypeSym:=nil;

      IntfDef.DefOptions:=IntfDef.DefOptions+PVDef.DefOptions*[df_generic,df_specialization];
      { also inherit the general flags from the surrounding structured type or
        function }
      if Assigned(CurrentStructDef) then
        begin
          IntfDef.DefOptions:=IntfDef.DefOptions+CurrentStructDef.DefOptions*[df_generic,df_specialization];
        end
      else if Assigned(CurrentProcInfo) then
        begin
          IntfDef.DefOptions:=IntfDef.DefOptions+CurrentProcInfo.ProcDef.DefOptions*[df_generic,df_specialization];
        end;

      if cs_generate_rtti in CurrentSettings.LocalSwitches then
        Include(IntfDef.ObjectOptions,oo_can_have_published);

      OldSymTableStack:=SymTableStack;
      SymTableStack:=nil;

      InvokeDef:=TProcDef(PVDef.GetCopyAs(ProcDef,pc_normal_no_paras,'',False));
      InvokeDef.Struct:=IntfDef;
      InvokeDef.ForwardDef:=False;

      Include(InvokeDef.ProcOptions,po_overload);
      Include(InvokeDef.ProcOptions,po_virtualmethod);

      InvokeDef.ProcSym:=CProcSym.Create(MethodNameFuncRefInvokeDecl);
      if cs_generate_rtti in CurrentSettings.LocalSwitches then
        InvokeDef.Visibility:=vis_published
      else
        InvokeDef.Visibility:=vis_public;

      IntfDef.SymTable.InsertSym(InvokeDef.ProcSym);
      IntfDef.SymTable.InsertDef(InvokeDef);

      { we need to do this even if the def isn't a generic/specialization itself,
        but *belongs* to one }
      if IntfDef.DefOptions*[df_generic,df_specialization]<>[] then
        begin
          if Assigned(PVDef.GenericDef) and (PVDef.GenericDef.Typ<>ObjectDef) then
            InternalError(2021040501);
          IntfDef.GenericDef:=PVDef.GenericDef;
          { in case of a generic we move all involved syms/defs to the interface }
          IntfDef.GenericParas:=PVDef.GenericParas;
          PVDef.GenericParas:=nil;
          if Assigned(IntfDef.GenericParas) then
            for I:=0 to IntfDef.GenericParas.Count-1 do
              begin
                Sym:=TSym(IntfDef.GenericParas[I]);
                if Sym.Owner<>PVDef.ParaST then
                  Continue;
                Sym.ChangeOwner(IntfDef.SymTable);
                if (Sym.Typ=TypeSym) and (TTypeSym(Sym).TypeDef.Owner=PVDef.ParaST) then
                  TTypeSym(Sym).TypeDef.ChangeOwner(IntfDef.SymTable);
              end;
        end;

      { now move the symtable over }
      InvokeDef.ParaST.Free;
      InvokeDef.ParaST:=PVDef.ParaST;
      InvokeDef.ParaST.DefOwner:=InvokeDef;
      PVDef.ParaST:=nil;

      for I:=0 to InvokeDef.ParaST.SymList.Count-1 do
        begin
          Sym:=TSym(InvokeDef.ParaST.SymList[I]);
          if Sym.Typ<>ParaVarSym then
            Continue;
          if TParaVarSym(Sym).VarDef=PVDef then
            TParaVarSym(Sym).VarDef:=IntfDef;
        end;

      SymTableStack:=OldSymTableStack;

      if InvokeDef.ReturnDef=PVDef then
        InvokeDef.ReturnDef:=IntfDef;

      handle_calling_convention(InvokeDef,hcc_default_actions_intf_struct);
      proc_add_definition(InvokeDef);
      InvokeDef.CalcParas;
      { def is not owned, so it can be simply freed }
      Def.Free;
      Def:=IntfDef;
    end;


  function Adjust_FuncRef(var Def:TDef;Sym,DummySym:TSym):Boolean;
    var
      SymPos : TFilePosInfo;
      Name : string;
    begin
      Result:=False;
      if (Def.Typ<>ProcVarDef) and not Is_FuncRef(Def) then
        InternalError(2022020401);
      if Assigned(Sym) and not (Sym.Typ=TypeSym) then
        InternalError(2022020402);
      { these always support everything, no "of object" or
        "is_nested" is allowed }
      if Is_Nested_PD(TProcVarDef(Def)) or
         Is_MethodPointer(Def) then
        CGMessage(type_e_function_reference_kind);
      if not (po_is_block in TProcVarDef(Def).ProcOptions) then
        begin
          if Assigned(DummySym) then
            TTypeSym(DummySym).TypeDef:=nil;
          if Assigned(Sym) then
            begin
              TTypeSym(Sym).TypeDef:=nil;
              Name:=Sym.Name;
            end
          else
            Name:='';
          Convert_To_FuncRef_Intf(Name,Def);
          if Assigned(Sym) then
            TTypeSym(Sym).TypeDef:=Def;
          if Assigned(DummySym) then
            TTypeSym(DummySym).TypeDef:=Def;
          Build_VMT(TObjectDef(Def));
          Result:=True;
        end
      else
        begin
          if Assigned(Sym) and (Sym.Refs>0) then
            begin
              { find where the symbol was used and trigger
                a "symbol not completely defined" error }
              if not FileInfo_Of_TypeSym_In_Def(Def,Sym,SymPos) then
                SymPos:=Sym.FileInfo;
              MessagePos1(SymPos,type_e_type_is_not_completly_defined,Sym.RealName);
            end;
        end;
    end;


  function FuncRefIntfForProc(PD:TAbstractProcDef;const Suffix:string):TObjectDef;
    var
      Name : TSymStr;
      Sym : TSym;
      SymOwner : TSymTable;
      OldSymTableStack: TSymTableStack;
      InvokeDef: TProcDef;
    begin
      if PD.Is_Generic then
        InternalError(2022010710);

      Name:='funcrefintf_'+Suffix;
      if PD.Owner.SymTableType=GlobalSymTable then
        SymOwner:=CurrentModule.LocalSymTable
      else
        SymOwner:=PD.Owner;
      Sym:=TSym(SymOwner.Find(Name));
      if Assigned(Sym) then
        begin
          if Sym.Typ<>TypeSym then
            InternalError(2022010708);
          if not Is_FuncRef(TTypeSym(Sym).TypeDef) then
            InternalError(2022010709);
          Result:=TObjectDef(TTypeSym(Sym).TypeDef);
          Exit;
        end;

      Name:='$'+Name;

      Result:=CObjectDef.Create(odt_interfacecom,Name,Interface_IUnknown,False);
      Include(Result.ObjectOptions,oo_is_funcref);
      Include(Result.ObjectOptions,oo_is_invokable);

      Sym:=CTypeSym.Create(Name,Result);

      OldSymTableStack:=SymTableStack;
      SymTableStack:=nil;

      InvokeDef:=TProcDef(PD.GetCopyAs(ProcDef,pc_normal_no_hidden,'',False));
      InvokeDef.Struct:=Result;
      InvokeDef.Visibility:=vis_public;
      InvokeDef.ProcSym:=CProcSym.Create(MethodNameFuncRefInvokeDecl);
      InvokeDef.ParaST.SymTableLevel:=NormalFunctionLevel;
      InvokeDef.LocalST.SymTableLevel:=NormalFunctionLevel;
      Include(InvokeDef.ProcOptions,po_virtualmethod);
      Exclude(InvokeDef.ProcOptions,po_staticmethod);
      Exclude(InvokeDef.ProcOptions,po_classmethod);
      InvokeDef.ForwardDef:=False;

      SymTableStack:=OldSymTableStack;

      Result.SymTable.InsertSym(InvokeDef.ProcSym);
      Result.SymTable.InsertDef(InvokeDef);

      proc_add_definition(InvokeDef);
      InvokeDef.CalcParas;
      Include(Result.ObjectOptions,oo_has_virtual);

      SymOwner.InsertSym(Sym);
      SymOwner.InsertDef(Result);
      AddSymRef(Sym);

      Build_VMT(Result);
    end;



  function AcceptableTyp(Sym:TAbstractVarSym;Typ :TSymTyp) : Boolean;
    begin
      AcceptableTyp:=False;
      if (Sym.Typ=Typ) then
        AcceptableTyp:=True
      else if (Sym.Typ=AbsoluteVarSym) and (TAbsoluteVarSym(Sym).RefTyp=Typ) then
        AcceptableTyp:=True;
    end;

  function GetCapturer(PD:TProcDef):TAbstractVarSym;

    function GetSym(ST:TSymTable;Typ:TSymTyp):TAbstractVarSym;
      begin
        Result:=TAbstractVarSym(ST.Find(CapturerVarName));
        if not Assigned(Result) then
          InternalError(2022010703);
       if not AcceptableTyp(Result,Typ) then
          InternalError(2022010704);
        if not Is_Class(Result.VarDef) then
          InternalError(2022010705);
      end;

    begin
      case PD.ProcTypeOption of
        potype_unitfinalize,
        potype_unitinit,
        potype_proginit:
          begin
            if not Assigned(PD.Owner) then
              InternalError(2022052401);
            if PD.Owner.SymTableType<>StaticSymTable then
              InternalError(2022052402);
            Result:=GetSym(PD.Owner,StaticVarSym);
          end;
        else
          begin
            if not Assigned(PD.LocalST) then
              InternalError(2022020502);
            Result:=GetSym(PD.LocalST,LocalVarSym);
          end;
      end;
    end;


  function GetCapturerAlive(PD:TProcDef):TAbstractVarSym;

    function GetSym(ST:TSymTable;Typ:TSymTyp):TAbstractVarSym;
      begin
        Result:=TAbstractVarSym(ST.Find(CapturerVarName+KeepAliveSuffix));
        if not Assigned(Result) then
          InternalError(2022051703);
        if not AcceptableTyp(Result,Typ) then
          InternalError(2022051704);
        if not Is_InterfaceCOM(Result.VarDef) then
          InternalError(2022051705);
      end;

    begin
      case PD.ProcTypeOption of
        potype_unitfinalize,
        potype_unitinit,
        potype_proginit:
          begin
            if not Assigned(PD.Owner) then
              InternalError(2022052403);
            if PD.Owner.SymTableType<>StaticSymTable then
              InternalError(2022052404);
            Result:=GetSym(PD.Owner,StaticVarSym);
          end;
        else
          begin
            if not Assigned(PD.LocalST) then
              InternalError(2022051702);
            Result:=GetSym(PD.LocalST,LocalVarSym);
          end;
      end;
    end;


  function Get_Or_Create_Capturer(PD:TProcDef):TSym;
    var
      Name : TSymStr;
      Parent,
      Def : TObjectDef;
      TypeSym : TSym;
      KeepAlive : TAbstractVarSym;
      ST : TSymTable;
    begin
      if PD.HasCapturer then
        begin
          Result:=GetCapturer(PD);
        end
      else
        begin
          Parent:=TObjectDef(Search_System_Type('TINTERFACEDOBJECT').TypeDef);
          if not Is_Class(Parent) then
            InternalError(2022010706);

          Name:=CapturerClassName+'_'+FileInfoToSuffix(PD.FileInfo);

          case PD.ProcTypeOption of
            potype_unitfinalize,
            potype_unitinit,
            potype_proginit:
              ST:=PD.Owner;
            else
              ST:=PD.LocalST;
          end;

          Def:=CObjectDef.Create(odt_class,Name,Parent,False);
          Include(Def.ObjectOptions,oo_is_capturer);
          TypeSym:=CTypeSym.Create(Name,Def);
          TypeSym.FileInfo:=PD.FileInfo;
          ST.InsertDef(Def);
          ST.InsertSym(TypeSym);
          AddSymRef(TypeSym);

          if df_generic in PD.DefOptions then
            Include(Def.DefOptions,df_generic);
          { don't set df_specialization as in that case genericdef needs to be
            set, but the local symtables are freed once a unit is finished }
          {if df_specialization in pd.defoptions then
            begin
              if not assigned(pd.genericdef) or (pd.genericdef.typ<>procdef) then
                internalerror(2022020501);
              def.genericdef:=tstoreddef(get_capturer(tprocdef(pd.genericdef)).vardef);
              include(def.defoptions,df_specialization);
            end;}

          if ST.SymTableType=LocalSymTable then
            Result:=CLocalVarSym.Create('$'+CapturerVarName,vs_value,Def,[vo_is_internal])
          else
            Result:=CStaticVarSym.Create('$'+CapturerVarName,vs_value,Def,[vo_is_internal]);
          Result.FileInfo:=PD.FileInfo;
          ST.InsertSym(Result);
          AddSymRef(Result);

          if ST.SymTableType=LocalSymTable then
            KeepAlive:=CLocalVarSym.Create('$'+CapturerVarName+KeepAliveSuffix,vs_value,Interface_IUnknown,[vo_is_internal])
          else
            KeepAlive:=CStaticVarSym.Create('$'+CapturerVarName+KeepAliveSuffix,vs_value,Interface_IUnknown,[vo_is_internal]);
          KeepAlive.FileInfo:=PD.FileInfo;
          ST.InsertSym(KeepAlive);
          AddSymRef(KeepAlive);

          if ST.SymTableType<>LocalSymTable then
            begin
              CNodeUtils.InsertBSSData(TStaticVarSym(Result));
              CNodeUtils.InsertBSSData(TStaticVarSym(KeepAlive));
            end;

          { avoid warnings as these symbols are initialized using initialize_capturer
            after parsing the body }
          TAbstractVarSym(Result).VarState:=vs_readwritten;
          KeepAlive.VarState:=vs_readwritten;

          PD.HasCapturer:=True;
        end;
    end;


  function CanBeCaptured(Sym:TSym;CurPD:TProcDef):Boolean;
    begin
      Result:=False;
      if (Sym.Typ=ProcSym) and Assigned(CurPD) and (CurPD.ProcSym=Sym) then
        Exit(True);
      if not (Sym.Typ in [LocalVarSym,ParaVarSym]) then
        Exit;
      if TAbstractNormalVarSym(Sym).VarOptions*[vo_is_result,vo_is_funcret]<>[] then
        Exit;
      if Sym.Typ=ParaVarSym then
        begin
          if (TParaVarSym(Sym).VarSpez in [vs_out,vs_var]) and
              not (vo_is_self in TParaVarSym(Sym).VarOptions) then
            Exit;
          if Is_Open_Array(TParaVarSym(Sym).VarDef) then
            Exit;
        end;
      Result:=True;
    end;


  type
    TSymMapping = record
      OldSym:TSym;
      NewSym:TSym;
    end;
    PSymMapping = ^TSymMapping;


  function ReplaceSelfSym(var N:TNode;Arg:Pointer):TForEachNodeResult;
    var
      Mapping : PSymMapping absolute Arg;
      LD : TLoadNode;
    begin
      if N.NodeType=LoadN then
        begin
          LD:=TLoadNode(N);
          if LD.SymTableEntry=Mapping^.OldSym then
            begin
              LD.SymTableEntry:=Mapping^.NewSym;
              { make sure that the node is processed again }
              LD.ResultDef:=nil;
              if Assigned(LD.Left) then
                begin
                  { no longer loaded through the frame pointer }
                  LD.Left.Free;
                  LD.Left:=nil;
                end;
              TypeCheckPass(N);
            end;
        end;
      Result:=fen_true;
    end;


  procedure CaptureCapturedSyms(PD:TProcDef;Owner:TProcInfo;CaptureDef:TObjectDef;OldPD:TProcDef);
    var
      CurPD : TProcDef;
      SubCapturer : TObjectDef;
      SymsToDo : TFPList;
      I : LongInt;
      Sym : TSym;
      FieldSym : TFieldVarSym;
      FieldName : TSymStr;
      FieldDef : TDef;
    begin
      if not PD.WasAnonymous or not Assigned(PD.CapturedSyms) or (PD.CapturedSyms.Count=0) then
        Exit;
      { capture all variables that the original procdef captured }
      CurPD:=Owner.ProcDef;
      SubCapturer:=CaptureDef;
      SymsToDo:=TFPList.Create;
      for I:=0 to PD.CapturedSyms.Count-1 do
        if CanBeCaptured(PCapturedSymInfo(PD.CapturedSyms[I])^.Sym,OldPD) and
            (PCapturedSymInfo(PD.CapturedSyms[I])^.Sym.Typ<>ProcSym) then
          SymsToDo.Add(PCapturedSymInfo(PD.CapturedSyms[I])^.Sym);
      while SymsToDo.Count>0 do
        begin
          { we know we have symbols left to capture thus we either have a
            symbol that's located in the capturer of the current procdef or
            we need to put in the OuterSelf reference }
          if CurPD=Owner.ProcDef then
            SubCapturer:=CaptureDef
          else
            SubCapturer:=TObjectDef(TAbstractVarSym(Get_Or_Create_Capturer(CurPD)).VarDef);
          I:=0;
          while I<SymsToDo.Count do
            begin
              Sym:=TSym(SymsToDo[I]);
              if (Sym.Owner=CurPD.LocalST) or
                  (Sym.Owner=CurPD.ParaST) then
                begin
                  { the symbol belongs to the current procdef, so add a field to
                    the capturer if it doesn't already exist }
                  if vo_is_self in TAbstractNormalVarSym(Sym).VarOptions then
                    FieldName:=OuterSelfFieldName
                  else
                    FieldName:=Sym.Name;
                  FieldSym:=TFieldVarSym(SubCapturer.SymTable.Find(FieldName));
                  if not Assigned(FieldSym) then
                    begin
                      FieldDef:=TAbstractVarSym(Sym).VarDef;
                      if vo_is_self in TAbstractNormalVarSym(Sym).VarOptions then
                        begin
                          FieldName:='$'+FieldName;
                          if not Is_Implicit_Pointer_Object_Type(FieldDef) then
                            FieldDef:=CPointerDef.GetReusable(FieldDef);
                        end;
                      FieldSym:=CFieldVarSym.Create(FieldName,vs_value,FieldDef,[]);
                      FieldSym.FileInfo:=Sym.FileInfo;
                      SubCapturer.SymTable.InsertSym(FieldSym);
                      TAbstractRecordSymTable(SubCapturer.SymTable).AddField(FieldSym,vis_public);
                    end;
                  if not Assigned(TAbstractNormalVarSym(Sym).CaptureSym) then
                    TAbstractNormalVarSym(Sym).CaptureSym:=FieldSym
                  else if TAbstractNormalVarSym(Sym).CaptureSym<>FieldSym then
                    InternalError(2022011602);
                  SymsToDo.Delete(I);
                end
              else if Sym=PD.ProcSym then
                { no explicit capturing needed here }
                SymsToDo.Delete(I)
              else
                Inc(I);
            end;
          if SymsToDo.Count>0 then
            begin
              if CurPD.Owner.SymTableType<>LocalSymTable then
                InternalError(2022011001);
              { there are still symbols left, so before we move to the parent
                procdef we add the OuterSelf field to set up the chain of
                capturers }
              { we no longer need the curpd, but we need the parent, so change
                curpd here }
                CurPD:=TProcDef(CurPD.Owner.DefOwner);
                if CurPD.Typ<>ProcDef then
                  InternalError(2022011002);
              if not Assigned(SubCapturer.SymTable.Find(OuterSelfFieldName)) then
                begin
                  if SubCapturer.Owner.SymTableLevel>NormalFunctionLevel then
                    begin
                      { the outer self is the capturer of the outer procdef }
                      Sym:=Get_Or_Create_Capturer(CurPD);
                      { ensure that the outer capturer isn't put into a register anymore }
                      TAbstractVarSym(Sym).DifferentScope:=True;
                      TAbstractVarSym(Sym).VarRegable:=vr_none;
                    end
                  else
                    begin
                      { the outer self is the self of the method }
                      if not (CurPD.Owner.SymTableType in [ObjectSymTable,RecordSymTable]) then
                        InternalError(2022011603);
                      Sym:=TSym(CurPD.ParaST.Find('self'));
                      if not Assigned(Sym) then
                        InternalError(2022011604);
                    end;
                  { add the keep alive IUnknown symbol }
                  FieldSym:=CFieldVarSym.Create('$'+OuterSelfFieldName+KeepAliveSuffix,vs_value,Interface_IUnknown,[]);
                  FieldSym.FileInfo:=Sym.FileInfo;
                  SubCapturer.SymTable.InsertSym(FieldSym);
                  TAbstractRecordSymTable(SubCapturer.SymTable).AddField(FieldSym,vis_public);
                  { add the capturer symbol }
                  FieldSym:=CFieldVarSym.Create('$'+OuterSelfFieldName,vs_value,TAbstractVarSym(Sym).VarDef,[]);
                  FieldSym.FileInfo:=Sym.FileInfo;
                  SubCapturer.SymTable.InsertSym(FieldSym);
                  TAbstractRecordSymTable(SubCapturer.SymTable).AddField(FieldSym,vis_public);
                  if (Sym.Typ=ParaVarSym) and (vo_is_self in TParaVarSym(Sym).VarOptions) then
                    begin
                      if Assigned(TParaVarSym(Sym).CaptureSym) then
                        InternalError(2022011705);
                      TParaVarSym(Sym).CaptureSym:=FieldSym;
                    end;
                end;
            end;
        end;
      SymsToDo.Free;
      SymsToDo := nil;
    end;


  function RetrieveSymForFilePos(var N:TNode;Arg:Pointer):TForEachNodeResult;
    var
      Sym : ^TSym absolute Arg;
    begin
      if Assigned(Sym^) then
        Exit(fen_norecurse_true);
      Result:=fen_false;
      if not (N.ResultDef.Typ in [ProcDef,ProcVarDef]) then
        Exit;
      if N.NodeType=LoadN then
        begin
          Sym^:=TLoadNode(N).SymTableEntry;
          Result:=fen_norecurse_true;
        end
      else if N.NodeType=SubscriptN then
        begin
          Sym^:=TSubscriptNode(N).FieldSym;
          Result:=fen_norecurse_true;
        end;
    end;


  function CollectSymsToCapture(var N:TNode;Arg:Pointer):TForEachNodeResult;
    var
      PD : TProcDef absolute Arg;
      Sym : TSym;
    begin
      Result:=fen_false;
      if N.NodeType<>LoadN then
        Exit;
      Sym:=TSym(TLoadNode(N).SymTableEntry);
      if not (Sym.Owner.SymTableType in [ParaSymTable,LocalSymTable]) then
        Exit;
      if Sym.Owner.SymTableLevel>NormalFunctionLevel then begin
        PD.Add_Captured_Sym(Sym,TLoadNode(N).ResultDef,N.FileInfo);
        Result:=fen_true;
      end;
    end;


  type
    TSelfInfo=record
      SelfSym:TSym;
      Ignore:TSym;
    end;
    PSelfInfo=^TSelfInfo;


  function FindSelfSym(var N:TNode;Arg:Pointer):TForEachNodeResult;
    var
      Info : PSelfInfo absolute Arg;
    begin
      Result:=fen_false;
      if Assigned(Info^.SelfSym) then
        Exit(fen_norecurse_true);
      if N.NodeType<>LoadN then
        Exit;
      if TLoadNode(N).SymTableEntry.Typ<>ParaVarSym then
        Exit;
      if TLoadNode(N).SymTableEntry=Info^.Ignore then
        Exit;
      if vo_is_self in TParaVarSym(TLoadNode(N).SymTableEntry).VarOptions then
        begin
          Info^.SelfSym:=TParaVarSym(TLoadNode(N).SymTableEntry);
          Result:=fen_norecurse_true;
        end;
    end;


  function FindOutermostLoadedSym(var N:TNode;Arg:Pointer):TForEachNodeResult;
    var
      Sym : ^TSym absolute Arg;
    begin
      if Assigned(Sym^) then
        Exit(fen_norecurse_true);
      Result:=fen_false;
      if N.NodeType<>LoadN then
        Exit;
      if not (N.ResultDef.Typ in [ProcDef,ProcVarDef]) then
        Exit;
      Sym^:=TLoadNode(N).SymTableEntry;
      Result:=fen_norecurse_true;
    end;


  function FindProcDef(var N:TNode;Arg:Pointer):TForEachNodeResult;
    var
      PD : ^TProcDef absolute Arg;
    begin
      if Assigned(PD^) then
        Exit(fen_norecurse_true);
      Result:=fen_false;
      if N.ResultDef.Typ<>ProcDef then
        Exit;
      PD^:=TProcDef(N.ResultDef);
      Result:=fen_norecurse_true;
    end;


  function Capturer_Add_ProcVar_Or_Proc(Owner:TProcInfo;N:TNode;out Capturer:TSym;out CaptureN:TNode):TObjectDef;

    function CreateParas(PD:TProcDef):TCallParaNode;
      var
        Para : TParaVarSym;
        I : LongInt;
      begin
        Result:=nil;
        for I:=0 to PD.Paras.Count-1 do
          begin
            Para:=TParaVarSym(PD.Paras[I]);
            if vo_is_hidden_para in Para.VarOptions then
              Continue;
            Result:=CCallParaNode.Create(CLoadNode.Create(Para,PD.ParaST),Result);
          end;
      end;

      function FindNestedProcInfo(PD:TProcDef):TCGProcInfo;
        var
          Tmp,
          Res : TProcInfo;
        begin
          Tmp:=Owner;
          while Assigned(Tmp) and (Tmp.ProcDef.ParaST.SymTableLevel>=NormalFunctionLevel) do
            begin
              Res:=Tmp.Find_NestedProc_By_PD(PD);
              if Assigned(Res) then
                Exit(TCGProcInfo(Res));
              Tmp:=Tmp.Parent;
            end;
          Result:=nil;
        end;

      procedure SwapSymTable(var ST1,ST2:TSymTable);
        var
          ST : TSymTable;
          Owner : TDefEntry;
          Level : Byte;
        begin
          { first swap the symtables themselves }
          ST:=ST1;
          ST1:=ST2;
          ST2:=ST;
          { then swap the symtables' owners }
          Owner:=ST1.DefOwner;
          ST1.DefOwner:=ST2.DefOwner;
          ST2.DefOwner:=Owner;
          { and finally the symtable level }
          Level:=ST1.SymTableLevel;
          ST1.SymTableLevel:=ST2.SymTableLevel;
          ST2.SymTableLevel:=Level;
        end;

      procedure PrintProcInfo(PI:TCGProcInfo);
        begin
          { Print the node to tree.log }
          if ParaPrintNodeTree <> 0 then
            PI.PrintProc('after parsing');

        end;

    var
      PS : TProcSym;
      OldPD,
      PD : TProcDef;
      PINested,
      PI : TCGProcInfo;
      Sym,
      FPSym,
      SelfSym : TSym;
      InvokeName : TSymStr;
      CaptureDef : TObjectDef;
      CaptureSyms : TFPList;
      Captured : PCapturedSymInfo;
      ImplIntf : TImplementedInterface;
      I : LongInt;
      Stmt : TStatementNode;
      N1 : TNode;
      FieldSym : TFieldVarSym;
      SelfInfo : TSelfInfo;
    begin
      if not (N.ResultDef.Typ in [ProcDef,ProcVarDef]) then
        InternalError(2022022101);

      Capturer:=nil;
      CaptureN:=nil;
      PINested:=nil;
      OldPD:=nil;

      { determine a unique name for the variable, field for function of the
        node we're trying to load }

      Sym:=nil;
      if not ForEachNodeStatic(pm_preprocess,N,@FindOutermostLoadedSym,@Sym) then
        InternalError(2022022102);

      Result:=FuncRefIntfForProc(TAbstractProcDef(N.ResultDef),FileInfoToSuffix(Sym.FileInfo));

      if (Sym.Typ=ProcSym) and (Sym.Owner.SymTableType=LocalSymTable) then
        begin
          { this is assigning a nested function, so retrieve the correct procdef
            so that we can then retrieve the procinfo for it }
          if N.ResultDef.Typ=ProcDef then
            PD:=TProcDef(N.ResultDef)
          else
            begin
              PD:=nil;
              if not ForEachNodeStatic(pm_preprocess,N,@FindProcDef,@PD) then
                InternalError(2022041801);
              if not Assigned(PD) then
                InternalError(2022041802);
            end;
          { check whether all captured symbols can indeed be captured }
          CaptureSyms:=PD.CapturedSyms;
          if Assigned(CaptureSyms) then
            for I:=0 to CaptureSyms.Count-1 do
              begin
                Captured:=PCapturedSymInfo(CaptureSyms[I]);
                if not CanBeCaptured(Captured^.Sym,PD) then
                  MessagePos1(Captured^.FileInfo,sym_e_symbol_no_capture,Captured^.Sym.RealName);
              end;
          if not (df_generic in Owner.ProcDef.DefOptions) then
            begin
              PINested:=FindNestedProcInfo(PD);
              if not Assigned(PINested) then
                InternalError(2022041803);
              OldPD:=PD;
              if PINested.Parent<>Owner then
                begin
                  { we need to capture this into the owner of the nested function
                    instead }
                  Owner:=PINested;
                  Capturer:=Get_Or_Create_Capturer(PINested.ProcDef);
                  if not Assigned(Capturer) then
                    InternalError(2022041804);
                end;
            end;
        end
      else if (N.ResultDef.Typ=ProcVarDef) and
          (po_delphi_nested_cc in TProcVarDef(N.ResultDef).ProcOptions) then
        begin
          MessagePos(N.FileInfo,type_e_nested_procvar_to_funcref);
          Exit;
        end
      else
        PINested:=nil;

      if df_generic in Owner.ProcDef.DefOptions then
        Exit;

      if not Assigned(Capturer) then
        Capturer:=Get_Or_Create_Capturer(Owner.ProcDef);

      if not (Capturer.Typ in [LocalVarSym,StaticVarSym]) then
        InternalError(2022022103);
      CaptureDef:=TObjectDef(TAbstractVarSym(Capturer).VarDef);
      if not Is_Class(CaptureDef) then
        InternalError(2022022104);
      ImplIntf:=Find_Implemented_Interface(CaptureDef,Result);
      if Assigned(ImplIntf) then
        begin
          { this is already captured into a method of the capturer, so nothing
            further to do }
          Exit;
        end;
      ImplIntf:=CaptureDef.Register_Implemented_Interface(Result,True);

      InvokeName:=MethodNameFuncRefInvokeDecl+'__FPCINTERNAL__'+FileInfoToSuffix(Sym.FileInfo);

      PS:=CProcSym.Create(InvokeName);
      PD:=TProcDef(TAbstractProcDef(N.ResultDef).GetCopyAs(ProcDef,pc_normal_no_hidden,'',False));
      PD.AliasNames.Clear;

      PD.ProcSym:=PS;
      PD.Struct:=CaptureDef;
      PD.ChangeOwner(CaptureDef.SymTable);
      PD.ParaST.SymTableLevel:=NormalFunctionLevel;
      PD.LocalST.SymTableLevel:=NormalFunctionLevel;
      { reset procoptions }
      PD.ProcOptions:=[];
      PS.ProcdefList.Add(PD);
      PD.ForwardDef:=False;
      { set procinfo and current_procinfo.procdef }
      PI:=TCGProcInfo(CProcInfo.Create(nil));
      PI.ProcDef:=PD;
      if not Assigned(PINested) then
        begin
          insert_funcret_para(PD);
          insert_funcret_local(PD);
          { we always do a call, namely to the provided function }
          Include(PI.Flags,pi_do_call);
        end
      else
        begin
          { the original nested function now calls the method }
          Include(PINested.Flags,pi_do_call);
          { swap the para and local symtables of the nested and new routine }
          SwapSymTable(PINested.ProcDef.ParaST,PD.ParaST);
          SwapSymTable(PINested.ProcDef.LocalST,PD.LocalST);
          { fix function return symbol }
          PD.FuncRetSym:=PINested.ProcDef.FuncRetSym;
          PINested.ProcDef.FuncRetSym:=nil;
          PINested.ProcDef.Reset_After_Conv;
          insert_funcret_para(PINested.ProcDef);
          insert_funcret_local(PINested.ProcDef);
          { the nested function needs access to the parent's framepointer to
            access the capturer }
          insert_parentfp_para(PINested.ProcDef);
          PD.CopiedFrom:=PINested.ProcDef;
        end;
      { to simplify some checks, but only after insert_funcret_para }
      PD.WasAnonymous:=True;
      CaptureDef.SymTable.InsertSym(PS);
      Owner.AddNestedProc(PI);

      { remove self and parentfp parameter if any as that will be replaced by
        the capturer }
      SelfSym:=nil;
      FPSym:=nil;
      for I:=0 to PD.ParaST.SymList.Count-1 do
        begin
          Sym:=TSym(PD.ParaST.SymList[I]);
          if Sym.Typ<>ParaVarSym then
            Continue;
          if vo_is_self in TParaVarSym(Sym).VarOptions then
            SelfSym:=Sym
          else if vo_is_parentfp in TParaVarSym(Sym).VarOptions then
            FPSym:=Sym;
          if Assigned(SelfSym) and Assigned(FPSym) then
            Break;
        end;
      if Assigned(SelfSym) then
        PD.ParaST.DeleteSym(SelfSym);
      if Assigned(FPSym) then
        PD.ParaST.DeleteSym(FPSym);
      PD.CalcParas;
      if Assigned(PINested) then
        PINested.ProcDef.CalcParas;

      insert_self_and_vmt_para(PD);

      if Assigned(PINested) then
        begin
          { when we're assigning a nested function to a function reference we
            move the code of the nested function to the newly created capturer
            method (including the captured symbols) and have the original nested
            function simply call that function-turned-method }
          PI.Code:=PINested.Code;
          PINested.Code:=InternalStatements(Stmt);
        end
      else
        PI.Code:=InternalStatements(Stmt);

      SelfInfo.SelfSym:=nil;
      SelfInfo.Ignore:=nil;

      FieldSym:=nil;
      if Assigned(PINested) then
        begin
          N1:=CCallNode.Create(CreateParas(PINested.ProcDef),PS,CaptureDef.SymTable,CLoadNode.Create(Capturer,Capturer.Owner),[],nil);
          { captured variables cannot be in registers }
          make_not_regable(TCallNode(N1).MethodPointer,[ra_addr_regable,ra_addr_taken]);
        end
      else if N.ResultDef.Typ=ProcVarDef then
        begin
          { store the procvar in a field so that it won't be changed if the
            procvar itself is changed }
          FieldSym:=CFieldVarSym.Create('$'+FileInfoToSuffix(N.FileInfo),vs_value,N.ResultDef,[]);
          FieldSym.FileInfo:=N.FileInfo;
          CaptureDef.SymTable.InsertSym(FieldSym);
          TAbstractRecordSymTable(CaptureDef.SymTable).AddField(FieldSym,vis_public);

          CaptureN:=CSubscriptNode.Create(FieldSym,CLoadNode.Create(Capturer,Capturer.Owner));

          SelfSym:=TSym(PD.ParaST.Find('self'));
          if not Assigned(SelfSym) then
            InternalError(2022052301);
          SelfInfo.Ignore:=SelfSym;
          N1:=CCallNode.Create_ProcVar(CreateParas(PD),CSubscriptNode.Create(FieldSym,CLoadNode.Create(SelfSym,SelfSym.Owner)));
        end
      else
        begin
          if N.NodeType<>LoadN then
            InternalError(2022032401);
          if TLoadNode(N).SymTableEntry.Typ<>ProcSym then
            InternalError(2022032402);
          N1:=CCallNode.Create(CreateParas(PD),TProcSym(TLoadNode(N).SymTableEntry),TLoadNode(N).SymTable,TLoadNode(N).Left,[],nil);
          TLoadNode(N).Left:=nil;
        end;
      if Assigned(PD.ReturnDef) and not Is_Void(PD.ReturnDef) then
        begin
          if Assigned(PINested) then
            Sym:=PINested.ProcDef.FuncRetSym
          else
            Sym:=PD.FuncRetSym;
          N1:=CAssignmentNode.Create(
                      CLoadNode.Create(Sym,Sym.Owner),
                      N1
                    );
          { captured variables cannot be in registers }
          make_not_regable(TAssignmentNode(N1).Left,[ra_addr_regable,ra_addr_taken]);
        end;
      AddStatement(Stmt,N1);
      PD.AliasNames.Insert(PD.MangledName);

      if Assigned(PINested) then
        begin
          { transfer all captured syms }
          CaptureSyms:=PINested.ProcDef.CapturedSyms;
          if Assigned(CaptureSyms) then
            begin
              for I:=0 to CaptureSyms.Count-1 do
                begin
                  Captured:=PCapturedSymInfo(CaptureSyms[I]);
                  PI.Add_Captured_Sym(Captured^.Sym,Captured^.Def,Captured^.FileInfo);
                  Dispose(Captured);
                end;
              CaptureSyms.Clear;
            end;
          { the original nested function now needs to capture only the capturer }
          PINested.ProcDef.Add_Captured_Sym(Capturer,CaptureDef,N.FileInfo);
        end
      { does this need to capture Self? }
      else if not ForEachNodeStatic(pm_postprocess,N,@FindSelfSym,@SelfInfo) then
        begin
          { is this a method of the current class? }
          if (N.ResultDef.Typ=ProcDef) and
              Assigned(TProcDef(N.ResultDef).Struct) and
              not (po_staticmethod in TProcDef(N.ResultDef).ProcOptions) and
              Assigned(CurrentProcInfo.ProcDef.Struct) and
              Def_Is_Related(CurrentProcInfo.ProcDef.Struct,TProcDef(N.ResultDef).Struct) then
            begin
              SelfInfo.SelfSym:=TSym(CurrentProcInfo.ProcDef.ParaST.Find('self'));
              if not Assigned(SelfInfo.SelfSym) then
                InternalError(2022110601);
            end
          else
            { does this need some other local variable or parameter? }
            ForEachNodeStatic(pm_postprocess,N,@CollectSymsToCapture,@PD)
        end;

      if Assigned(SelfInfo.SelfSym) and not Assigned(FieldSym) then
        { this isn't a procdef that was captured into a field, so capture the
          self }
        PD.Add_Captured_Sym(SelfInfo.SelfSym,TAbstractVarSym(SelfInfo.SelfSym).VarDef,N.FileInfo);

      PrintProcInfo(PI);
      if Assigned(PINested) then
        PrintProcInfo(PINested);

      ImplIntf.AddMapping(UpCase(Result.ObjRealName^+'.')+MethodNameFuncRefInvokeFind,UpCase(InvokeName));

      CaptureCapturedSyms(PD,Owner,CaptureDef,OldPD);
    end;


  function Capturer_Add_Anonymous_Proc(Owner:TProcInfo;PD:TProcDef;out Capturer:TSym):TObjectDef;
    var
      CaptureDef : TObjectDef;
      ImplIntf : TImplementedInterface;
      InvokeName : TSymStr;
      I : LongInt;
      OuterSelf,
      FPSym,
      SelfSym,
      Sym : TSym;
      Info : PCapturedSymInfo;
      PI : TProcInfo;
      Mapping : TSymMapping;
    begin
      Capturer:=nil;
      Result:=FuncRefIntfForProc(PD,FileInfoToSuffix(PD.FileInfo));

      if df_generic in PD.DefOptions then
        begin
          if (po_anonymous in PD.ProcOptions) and
              Assigned(PD.CapturedSyms) and
              (PD.CapturedSyms.Count>0) then
            begin
              { only check whether the symbols can be captured, but don't
                convert anything to avoid problems }
              for I:=0 to PD.CapturedSyms.Count-1 do
                begin
                  Info:=PCapturedSymInfo(PD.CapturedSyms[I]);
                  if not CanBeCaptured(Info^.Sym,PD) then
                    MessagePos1(Info^.FileInfo,sym_e_symbol_no_capture,Info^.Sym.RealName)
                end;
            end;
          Exit;
        end;

      Capturer:=Get_Or_Create_Capturer(Owner.ProcDef);

      if not (Capturer.Typ in [LocalVarSym,StaticVarSym]) then
        InternalError(2022010711);
      CaptureDef:=TObjectDef(TAbstractVarSym(Capturer).VarDef);
      if not Is_Class(CaptureDef) then
        InternalError(2022010712);
      ImplIntf:=Find_Implemented_Interface(CaptureDef,Result);
      if Assigned(ImplIntf) then
        begin
          { this can only already be an implemented interface if a named procdef
            was assigned to a function ref at an earlier point, an anonymous
            function can be used only once }
          if po_anonymous in PD.ProcOptions then
            InternalError(2022010713);
          Exit;
        end;
      ImplIntf:=CaptureDef.Register_Implemented_Interface(Result,True);

      InvokeName:=MethodNameFuncRefInvokeDecl+'__FPCINTERNAL__'+FileInfoToSuffix(PD.FileInfo);
      if po_anonymous in PD.ProcOptions then
        begin
          { turn the anonymous function into a method of the capturer }
          PD.ChangeOwner(CaptureDef.SymTable);
          PD.Struct:=CaptureDef;
          Exclude(PD.ProcOptions,po_anonymous);
          Exclude(PD.ProcOptions,po_delphi_nested_cc);
          Exclude(PD.ProcOptions,po_staticmethod);
          Exclude(PD.ProcOptions,po_classmethod);
          PD.WasAnonymous:=True;
          PD.ProcSym.ChangeOwnerAndName(CaptureDef.SymTable,UpCase(InvokeName));
          PD.ProcSym.RealName:=InvokeName;
          PD.ParaST.SymTableLevel:=NormalFunctionLevel;
          PD.LocalST.SymTableLevel:=NormalFunctionLevel;
          { retrieve framepointer and self parameters if any }
          FPSym:=nil;
          SelfSym:=nil;
          for I:=0 to PD.ParaST.SymList.Count-1 do
            begin
              Sym:=TSym(PD.ParaST.SymList[I]);
              if Sym.Typ<>ParaVarSym then
                Continue;
              if vo_is_parentfp in TParaVarSym(Sym).VarOptions then
                FPSym:=Sym
              else if vo_is_self in TParaVarSym(Sym).VarOptions then
                SelfSym:=Sym;
              if Assigned(FPSym) and Assigned(SelfSym) then
                Break;
            end;
          { get rid of the framepointer parameter }
          if Assigned(FPSym) then
            PD.ParaST.DeleteSym(FPSym);
          OuterSelf:=nil;
          { complain about all symbols that can't be captured and add the symbols
            to this procdefs capturedsyms if it isn't a top level function }
          if Assigned(PD.CapturedSyms) and (PD.CapturedSyms.Count>0) then
            begin
              for I:=0 to PD.CapturedSyms.Count-1 do
                begin
                  Info:=PCapturedSymInfo(PD.CapturedSyms[I]);
                  if not CanBeCaptured(Info^.Sym,PD) then
                    MessagePos1(Info^.FileInfo,sym_e_symbol_no_capture,Info^.Sym.RealName)
                  else if Info^.Sym=SelfSym then
                    begin
                      { we need to replace the captured "dummy" self parameter
                        with the real self parameter symbol from the surrounding
                        method }
                      if not Assigned(OuterSelf) then
                        OuterSelf:=TSym(Owner.Get_Normal_Proc.ProcDef.ParaST.Find('self'));
                      if not Assigned(OuterSelf) then
                        InternalError(2022010905);

                      { the anonymous function can only be a direct child of the
                        owner }
                      PI:=Owner.Get_First_NestedProc;
                      while Assigned(PI) do
                        begin
                          if PI.ProcDef=PD then
                            Break;
                          PI:=TProcInfo(PI.Next);
                        end;

                      if not Assigned(PI) then
                        InternalError(2022010906);

                      Mapping.OldSym:=SelfSym;
                      Mapping.NewSym:=OuterSelf;

                      { replace all uses of the captured Self by the new Self
                        parameter }
                      ForEachNodeStatic(pm_preprocess,TCGProcInfo(PI).Code,@ReplaceSelfSym,@Mapping);

                      { update the captured symbol }
                      Info^.Sym:=OuterSelf;
                      Info^.Def:=TAbstractVarSym(OuterSelf).VarDef;
                    end
                  else if Info^.Sym.Owner.DefOwner<>Owner.ProcDef then
                    Owner.ProcDef.Add_Captured_Sym(Info^.Sym,Info^.Def,Info^.FileInfo);
                end;
            end;
          { delete the original self parameter }
          if Assigned(SelfSym) then
            PD.ParaST.DeleteSym(SelfSym);
          { note: don't call insert_self_and_vmt_para here, as that is later on
                  done when building the VMT }
        end
      else
        InternalError(2022022201);
      ImplIntf.AddMapping(UpCase(Result.ObjRealName^+'.')+MethodNameFuncRefInvokeFind,UpCase(InvokeName));

      CaptureCapturedSyms(PD,Owner,CaptureDef,nil);
    end;


  function LoadCapturer(Capturer:TAbstractVarSym):TNode;inline;
    begin
      Result:=CLoadNode.Create(Capturer,Capturer.Owner);
    end;


  function InstantiateCapturer(CapturerSym:TAbstractVarSym):TNode;
    var
      CapturerDef : TObjectDef;
      Ctor : TProcSym;
    begin
      CapturerDef:=TObjectDef(CapturerSym.VarDef);

      { Neither TInterfacedObject, nor TCapturer have a custom constructor }
      Ctor:=TProcSym(Class_TObject.SymTable.Find('CREATE'));
      if not Assigned(Ctor) then
        InternalError(2022010801);

      { Insert "Capturer := TCapturer.Create()" as the first statement of the routine }
      Result:=CLoadVMTAddrNode.Create(CTypeNode.Create(CapturerDef));
      Result:=CCallNode.Create(nil,Ctor,CapturerDef.SymTable,Result,[],nil);
      Result:=CAssignmentNode.Create(LoadCapturer(CapturerSym),Result);
    end;


  procedure InitializeCapturedParas(PD:TProcDef;Capturer:TAbstractVarSym;var Stmt:TStatementNode);
    var
      I : LongInt;
      PSym: TParaVarSym;
      N : TNode;
    begin
      for I:=0 to PD.Paras.Count-1 do
        begin
          PSym:=TParaVarSym(PD.Paras[I]);
          if not PSym.Is_Captured then
            Continue;
          N:=CLoadNode.Create(PSym,PSym.Owner);
          if PSym.CaptureSym.Owner.DefOwner<>Capturer.VarDef then
            InternalError(2022010903);
          if (vo_is_self in PSym.VarOptions) and not Is_Implicit_Pointer_Object_Type(PSym.VarDef) then
            N:=CAddrNode.Create(N);
          N:=CAssignmentNode.Create(
               CSubscriptNode.Create(PSym.CaptureSym,CLoadNode.Create(Capturer,Capturer.Owner)),
               N
               );
          AddStatement(Stmt,N);
        end;
    end;


  procedure AttachOuterCapturer(Ctx:TProcInfo;Capturer:TAbstractVarSym;var Stmt:TStatementNode);
    var
      AliveField,
      SelfField : TFieldVarSym;
      OuterAlive,
      OuterCapturer : TAbstractVarSym;
      AliveNode,
      SelfNode : TNode;
    begin
      if not Ctx.ProcDef.WasAnonymous and
          not (Ctx.ProcDef.Owner.SymTableType=LocalSymTable) then
        Exit;
      SelfField:=TFieldVarSym(TObjectDef(Capturer.VarDef).SymTable.Find(OuterSelfFieldName));
      if not Assigned(SelfField) then
        { we'll simply assume that we don't need the outer capturer }
        Exit;
      AliveField:=TFieldVarSym(TObjectDef(Capturer.VarDef).SymTable.Find(OuterSelfFieldName+KeepAliveSuffix));
      if not Assigned(AliveField) then
        InternalError(2022051701);
      if Ctx.ProcDef.WasAnonymous then
        begin
          SelfNode:=Load_Self_Node;
          AliveNode:=SelfNode.GetCopy;
        end
      else
        begin
          OuterCapturer:=GetCapturer(TProcDef(Ctx.ProcDef.Owner.DefOwner));
          if not Assigned(OuterCapturer) then
            InternalError(2022011605);
          SelfNode:=CLoadNode.Create(OuterCapturer,OuterCapturer.Owner);
          make_not_regable(SelfNode,[ra_different_scope]);
          OuterAlive:=GetCapturerAlive(TProcDef(Ctx.ProcDef.Owner.DefOwner));
          if not Assigned(OuterAlive) then
            InternalError(2022051706);
          AliveNode:=CLoadNode.Create(OuterAlive,OuterAlive.Owner);
          make_not_regable(AliveNode,[ra_different_scope]);
        end;
      AddStatement(Stmt,CAssignmentNode.Create(
                          CSubscriptNode.Create(
                            SelfField,
                            CLoadNode.Create(
                              Capturer,
                              Capturer.Owner
                              )
                            ),
                            SelfNode));
      AddStatement(Stmt,CAssignmentNode.Create(
                          CSubscriptNode.Create(
                            AliveField,
                            CLoadNode.Create(
                              Capturer,
                              Capturer.Owner
                              )
                            ),
                            AliveNode));
    end;


  procedure Initialize_Capturer(Ctx:TProcInfo;var Stmt:TStatementNode);
    var
      CapturerSym,
      KeepAliveSym : TAbstractVarSym;
    begin
      if Ctx.ProcDef.HasCapturer then
        begin
          CapturerSym:=GetCapturer(Ctx.ProcDef);

          AddStatement(Stmt,InstantiateCapturer(CapturerSym));
          AttachOuterCapturer(Ctx,CapturerSym,Stmt);
          InitializeCapturedParas(Ctx.ProcDef,CapturerSym,Stmt);

          KeepAliveSym:=GetCapturerAlive(Ctx.ProcDef);
          if not Assigned(KeepAliveSym) then
            InternalError(2022010701);
          AddStatement(Stmt,CAssignmentNode.Create(CLoadNode.Create(KeepAliveSym,KeepAliveSym.Owner),LoadCapturer(CapturerSym)));
        end;
    end;


  procedure PostProcess_Capturer(Ctx: TProcInfo);
    var
      Def: TObjectDef;
    begin
      if not Ctx.ProcDef.HasCapturer then
        Exit;

      Def:=TObjectDef(GetCapturer(Ctx.ProcDef).VarDef);
      { These two are delayed until this point because
        ... we have been adding fields on-the-fly }
      TAbstractRecordSymTable(Def.SymTable).AddAlignmentPadding;
      { ... we have been adding interfaces on-the-fly }
      Build_VMT(Def);
    end;


  type
    TConvertArg=record
      Mappings:TFPList;
    end;
    PConvertArg=^TConvertArg;

    TConvertMapping=record
      OldSym:TSym;
      NewSym:TSym;
      OldDef:TDef;
      SelfNode:TNode;
    end;
    PConvertMapping=^TConvertMapping;


  function ConvertCapturedSym(var N:TNode;Arg:Pointer):TForEachNodeResult;
    var
      ConvertArg : PConvertArg absolute Arg;
      Mapping : PConvertMapping;
      I : LongInt;
      OldFilePos : TFilePosInfo;
      LoadProcVar : Boolean;
      Paras: TNode;
      CNF : TCallNodeFlags;
      ParaOld,
      ParaNew : TCallParaNode;
    begin
      Result:=fen_true;
      if not (N.NodeType in [LoadN,CallN]) then
        Exit;
      for I:=0 to ConvertArg^.Mappings.Count-1 do
        begin
          Mapping:=ConvertArg^.Mappings[I];
          case N.NodeType of
            LoadN:
              begin
                if TLoadNode(N).SymTableEntry<>Mapping^.OldSym then
                  Continue;
                OldFilePos:=CurrentFilePos;
                CurrentFilePos:=N.FileInfo;
                LoadProcVar:=nf_load_procvar in N.Flags;
                N.Free;
                N:=CSubscriptNode.Create(Mapping^.NewSym,Mapping^.SelfNode.GetCopy);
                if LoadProcVar then
                  Include(N.Flags,nf_load_procvar);
                if (Mapping^.OldSym.Typ=ParaVarSym) and
                    (vo_is_self in TParaVarSym(Mapping^.OldSym).VarOptions) and
                    not Is_Implicit_Pointer_Object_Type(TParaVarSym(Mapping^.OldSym).VarDef) then
                  N:=CDerefNode.Create(N);
                TypeCheckPass(N);
                CurrentFilePos:=OldFilePos;
                Break;
              end;
            CallN:
              begin
                if Mapping^.OldSym.Typ<>ProcSym then
                  Continue;
                if TCallNode(N).SymTableProcEntry<>TProcSym(Mapping^.OldSym) then
                  Continue;
                if TCallNode(N).ProcDefinition<>TProcDef(Mapping^.OldDef) then
                  Continue;
                OldFilePos:=CurrentFilePos;
                CurrentFilePos:=N.FileInfo;
                LoadProcVar:=nf_load_procvar in N.Flags;
                Paras:=TCallNode(N).Left;
                ParaOld:=TCallParaNode(Paras);
                ParaNew:=nil;
                while Assigned(ParaOld) do
                  begin
                    if not (vo_is_hidden_para in ParaOld.ParaSym.VarOptions) then
                      begin
                        ParaNew:=CCallParaNode.Create(ParaOld.Left,ParaNew);
                        ParaOld.Left:=nil;
                      end;
                    ParaOld:=TCallParaNode(ParaOld.Right);
                  end;
                ReverseParameters(ParaNew);
                if Assigned(TCallNode(N).MethodPointer) then
                  InternalError(2023120802);
                CNF:=TCallNode(N).CallNodeFlags;
                N.Free;
                N:=CCallNode.Create(ParaNew,TProcSym(Mapping^.NewSym),Mapping^.NewSym.Owner,Mapping^.SelfNode.GetCopy,CNF,nil);
                if LoadProcVar then
                  Include(N.Flags,nf_load_procvar);
                TypeCheckPass(N);
                CurrentFilePos:=OldFilePos;
                Break;
              end;
            else
              InternalError(2023120801);
          end;
        end;
    end;


  procedure Convert_Captured_Syms(PD:TProcDef;Tree:TNode);

    function SelfTreeForSym(SelfSym:TSym;FieldSym:TSym):TNode;
      var
        FieldOwner : TDef;
        NewSym : TSym;
      begin
        Result:=CLoadNode.Create(SelfSym,SelfSym.Owner);
        FieldOwner:=TDef(FieldSym.Owner.DefOwner);
        NewSym:=SelfSym;
        while (TAbstractVarSym(NewSym).VarDef<>FieldOwner) do
          begin
            NewSym:=TSym(TObjectDef(TAbstractVarSym(NewSym).VarDef).SymTable.Find(OuterSelfFieldName));
            if not Assigned(NewSym) then
              InternalError(2022011101);
            Result:=CSubscriptNode.Create(NewSym,Result);
          end;
      end;

    var
      I: LongInt;
      Capturer : TObjectDef;
      ToCapture,
      CapturedSyms : TFPList;
      ConvertArg : TConvertArg;
      Mapping : PConvertMapping;
      SelfSym,
      Sym : TSym;
    begin

      ConvertArg.Mappings:=TFPList.Create;

      CapturedSyms:=TFPList.Create;

      if PD.WasAnonymous and
          Assigned(PD.CapturedSyms) and
          (PD.CapturedSyms.Count>0) then
        begin

          { this is a converted anonymous function, so rework all symbols that
            now belong to the new Self }

          SelfSym:=TSym(PD.ParaST.Find('self'));
          if not Assigned(SelfSym) then
            InternalError(2022010809);

          for I:=0 to PD.CapturedSyms.Count-1 do
            begin
              Sym:=TSym(PCapturedSymInfo(PD.CapturedSyms[I])^.Sym);
              if not CanBeCaptured(Sym,PD) and
                  not (
                    (Sym.Typ=ProcSym) and
                    Assigned(PD.CopiedFrom) and
                    (PD.CopiedFrom.ProcSym=Sym)
                  ) then
                Continue;
              New(Mapping);
              Mapping^.OldSym:=Sym;
              if Sym.Typ=ProcSym then
                begin
                  if not Assigned(PD.CopiedFrom) or
                      (PD.CopiedFrom.ProcSym<>Sym) then
                    InternalError(2023123001);
                  Mapping^.NewSym:=PD.ProcSym;
                end
              else
                Mapping^.NewSym:=TAbstractNormalVarSym(Sym).CaptureSym;
              Mapping^.OldDef:=PCapturedSymInfo(PD.CapturedSyms[I])^.Def;
              if not Assigned(Mapping^.NewSym) then
                InternalError(2022010810);
              Mapping^.SelfNode:=SelfTreeForSym(SelfSym,Mapping^.NewSym);
              ConvertArg.Mappings.Add(Mapping);
              CapturedSyms.Add(Sym);
            end;
        end;

      if (PD.ParaST.SymTableLevel>NormalFunctionLevel) and
          Assigned(PD.CapturedSyms) and
          (PD.CapturedSyms.Count>0) then
        begin
          if PD.WasAnonymous then
            InternalError(2022081201);


          { this is a nested function, so rework all symbols that are used from
            a parent function, but that might have been captured }

          for I:=0 to PD.CapturedSyms.Count-1 do
            begin
              Sym:=TSym(PCapturedSymInfo(PD.CapturedSyms[I])^.Sym);
              if not CanBeCaptured(Sym,PD) or
                  (Sym.Typ=ProcSym) or
                  not Assigned(TAbstractNormalVarSym(Sym).CaptureSym) then
                Continue;
              New(Mapping);
              Mapping^.OldSym:=Sym;
              Mapping^.NewSym:=TAbstractNormalVarSym(Sym).CaptureSym;
              Mapping^.OldDef:=PCapturedSymInfo(PD.CapturedSyms[I])^.Def;
              Capturer:=TObjectDef(Mapping^.NewSym.Owner.DefOwner);
              if not Is_Class(Capturer) then
                InternalError(2022012701);
              if not (Capturer.TypeSym.Owner.SymTableType in [LocalSymTable,StaticSymTable]) then
                InternalError(2022012702);
              SelfSym:=TSym(Capturer.TypeSym.Owner.Find(CapturerVarName));
              if not Assigned(SelfSym) then
                InternalError(2022012703);
              Mapping^.SelfNode:=SelfTreeForSym(SelfSym,Mapping^.NewSym);
              ConvertArg.Mappings.Add(Mapping);
              CapturedSyms.Add(Sym);
            end;
        end;

      if PD.HasCapturer then
        begin
          { this procedure has a capturer, so rework all symbols that are
            captured in that capturer }

          SelfSym:=GetCapturer(PD);

          { only capture those symbols that weren't captured already by one of
            the above if-clauses and thus are now listed in capturedsyms }
          ToCapture:=TFPList.Create;

          for I:=0 to PD.LocalST.SymList.Count-1 do
            begin
              Sym:=TSym(PD.LocalST.SymList[I]);
              if Sym.Typ<>LocalVarSym then
                Continue;
              if Assigned(TAbstractNormalVarSym(Sym).CaptureSym) then
                if CapturedSyms.IndexOf(Sym)<0 then
                  ToCapture.Add(Sym);
            end;

          for I:=0 to PD.ParaST.SymList.Count-1 do
            begin
              Sym:=TSym(PD.ParaST.SymList[I]);
              if Sym.Typ<>ParaVarSym then
                Continue;
              if Assigned(TAbstractNormalVarSym(Sym).CaptureSym) and
                  { no need to adjust accesses to the outermost Self inside the
                    outermost method }
                  not (vo_is_self in TAbstractVarSym(Sym).VarOptions) then
                if CapturedSyms.IndexOf(Sym)<0 then
                  ToCapture.Add(Sym);
            end;

          ConvertArg.Mappings.Capacity:=ConvertArg.Mappings.Count+ToCapture.Count;
          for I:=0 to ToCapture.Count-1 do
            begin
              New(Mapping);
              Mapping^.OldSym:=TSym(ToCapture[I]);
              Mapping^.NewSym:=TAbstractNormalVarSym(Mapping^.OldSym).CaptureSym;
              if not Assigned(Mapping^.NewSym) then
                InternalError(2022010805);
              Mapping^.SelfNode:=SelfTreeForSym(SelfSym,Mapping^.NewSym);
              ConvertArg.Mappings.Add(Mapping);
            end;

          ToCapture.Free;
          ToCapture := nil;
        end;

      { not required anymore }
      CapturedSyms.Free;
      CapturedSyms := nil;

      if ConvertArg.Mappings.Count>0 then
        ForEachNodeStatic(pm_postprocess,Tree,@ConvertCapturedSym,@ConvertArg);

      for I:=0 to ConvertArg.Mappings.Count-1 do
        begin
          Mapping:=PConvertMapping(ConvertArg.Mappings[I]);
          Mapping^.SelfNode.Free; // no nil needed
          Dispose(Mapping);
        end;

      ConvertArg.Mappings.Free; // no nil needed
    end;


end.

