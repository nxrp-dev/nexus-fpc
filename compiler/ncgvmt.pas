{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Generates VMT for classes/objects and interface wrappers

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
unit ncgvmt;

{$i fpcdefs.inc}

interface

    uses
      AAsmData,aasmbase,aasmcnst,
      SymBase,symconst,symtype,symdef;

    type
      PProcDefTree = ^TProcDefTree;
      TProcDefTree = record
         Data : TProcDef;
         NameLabel   : TAsmLabel;
         Left,Right  : PProcDefTree;
      end;

      TVMTWriter=class
      protected
        FClass : TObjectDef;
        { message tables }
        FRoot : PProcDefTree;
        { implemented interface vtables }
        FIntfVTableLabels: array of TAsmLabel;

        procedure DisposeProcDefTree(ATree : PProcDefTree);
        procedure InsertMsgInt(AObject:TObject;AArg:Pointer);
        procedure InsertMsgStr(AObject:TObject;AArg:Pointer);
        procedure InsertInt(ATree : PProcDefTree;var ACurrent : PProcDefTree;var ACount:LongInt);
        procedure InsertStr(ATree : PProcDefTree;var ACurrent : PProcDefTree;var ACount:LongInt);
        function RedirectToEmpty(AProcDef: TProcDef): Boolean;
        procedure WriteNames(ATypedConstBuilder: TTAITypedConstBuilder; ATree: PProcDefTree);
        procedure WriteIntEntry(ATypedConstBuilder: TTAITypedConstBuilder; ATree: PProcDefTree; AEntryDef: TDef);
        procedure WriteStrEntry(ATypedConstBuilder: TTAITypedConstBuilder; ATree: PProcDefTree; AEntryDef: TDef);
        { published methods }
        procedure Do_Count_Published_Methods(AObject:TObject;AArg:Pointer);
        procedure Do_Gen_Published_Methods(AObject:TObject;AArg:Pointer);
        { virtual methods }
        procedure writevirtualmethods(ATypedConstBuilder: TTAITypedConstBuilder);
        { interface tables }
        procedure Intf_Create_VTbl(ATypedConstBuilder: TTAITypedConstBuilder; AImplIntf: TImplementedInterface; AInterfaceIndex: LongInt);
        procedure Intf_Gen_Intf_Ref(ATypedConstBuilder: TTAITypedConstBuilder; AImplIntf: TImplementedInterface; AInterfaceIndex: LongInt; AInterfaceEntryDef, AInterfaceEntryTypeDef: TDef);
        procedure Intf_Write_Table(ATypedConstBuilder: TTAITypedConstBuilder; out ALabel: TAsmLabel; out AInterfaceTableDef: TRecordDef);
        { generates the message tables for a class }
        procedure GenStrMsgTab(ATypedConstBuilder: TTAITypedConstBuilder; out ALabel: TAsmLabel; out AMsgStrTableDef: TRecordDef);
        procedure GenIntMsgTab(ATypedConstBuilder: TTAITypedConstBuilder; out ALabel: TAsmLabel; out AMsgIntTableDef: TRecordDef);
        procedure GenPublishedMethodsTable(ATypedConstBuilder: TTAITypedConstBuilder; out ALabel: TAsmLabel; out APublishedMethodsDef: TRecordDef);
        procedure Generate_Field_Table(ATypedConstBuilder: TTAITypedConstBuilder; out ALabel: TAsmLabel; out AFieldTableDef: TRecordDef);
        procedure Generate_Abstract_Stub(AList:TAsmList;AProcDef:TProcDef); virtual;
      public
        constructor Create(AClassDef:TObjectDef); virtual;
        { write the VMT to al_globals }
        procedure WriteVMT;
        procedure WriteInterfaceIDs(AList: TAsmList);

        class function Use_VMT_Writer: Boolean; virtual;
      end;
      TVMTWriterClass = class of TVMTWriter;

    { generate VMTs }
    procedure Write_VMTs(ASymTable:TSymTable;AIsGlobal:Boolean);

  var
    CVMTWriter: TVMTWriterClass = TVMTWriter;

implementation

    uses
      CUtils,CClasses,
      FPCHash,
      GlobType,Globals,Verbose,ConstExp,
      Systems,FModule,
      SymSym,SymTable,symcreat,
{$ifdef cpuhighleveltarget}
      pparautl,
{$endif cpuhighleveltarget}
      aasmtai,
      wpobase,
      cgbase,parabase,paramgr,
      hlcgobj,hlcgcpu,DbgBase,
      ncgrtti;


{*****************************************************************************
                                TVMTWriter
*****************************************************************************}

    constructor TVMTWriter.Create(AClassDef:TObjectDef);
      begin
        inherited Create;
        FClass:=AClassDef;
      end;


{**************************************
           Message Tables
**************************************}

    procedure TVMTWriter.DisposeProcDefTree(ATree : PProcDefTree);
      begin
         if Assigned(ATree^.Left) then
           DisposeProcDefTree(ATree^.Left);
         if Assigned(ATree^.Right) then
           DisposeProcDefTree(ATree^.Right);
         dispose(ATree);
      end;


    procedure TVMTWriter.InsertInt(ATree : PProcDefTree;var ACurrent : PProcDefTree;var ACount:LongInt);
      begin
         if ACurrent=nil then
           begin
              ACurrent:=ATree;
              inc(ACount);
           end
         else
           begin
              if ATree^.Data.MessageInf.i<ACurrent^.Data.MessageInf.i then
                InsertInt(ATree,ACurrent^.Left,ACount)
              else if ATree^.Data.MessageInf.i>ACurrent^.Data.MessageInf.i then
                InsertInt(ATree,ACurrent^.Right,ACount)
              else
                Message1(parser_e_duplicate_message_label,ToStr(ATree^.Data.MessageInf.i));
           end;
      end;


    procedure TVMTWriter.InsertStr(ATree : PProcDefTree;var ACurrent : PProcDefTree;var ACount:LongInt);
      var
         lIndex : Integer;
      begin
         if ACurrent=nil then
           begin
              ACurrent:=ATree;
              inc(ACount);
           end
         else
           begin
              lIndex:=CompareStr(ATree^.Data.MessageInf.str^,ACurrent^.Data.MessageInf.str^);
              if lIndex<0 then
                InsertStr(ATree,ACurrent^.Left,ACount)
              else if lIndex>0 then
                InsertStr(ATree,ACurrent^.Right,ACount)
              else
                Message1(parser_e_duplicate_message_label,ATree^.Data.MessageInf.str^);
           end;
      end;


    procedure TVMTWriter.InsertMsgInt(AObject:TObject;AArg:Pointer);
      var
        lIndex  : LongInt;
        lProcDef : TProcDef;
        lTree : PProcDefTree;
      begin
        if TSym(AObject).typ<>ProcSym then
          exit;
        for lIndex:=0 to TProcSym(AObject).ProcdefList.Count-1 do
          begin
            lProcDef:=TProcDef(TProcSym(AObject).ProcdefList[lIndex]);
            if po_msgint in lProcDef.ProcOptions then
              begin
                new(lTree);
                lTree^.Data:=lProcDef;
                lTree^.Left:=nil;
                lTree^.Right:=nil;
                InsertInt(lTree,FRoot,PLongInt(AArg)^);
              end;
          end;
      end;


    procedure TVMTWriter.InsertMsgStr(AObject:TObject;AArg:Pointer);
      var
        lIndex  : LongInt;
        lProcDef : TProcDef;
        lTree : PProcDefTree;
      begin
        if TSym(AObject).typ<>ProcSym then
          exit;
        for lIndex:=0 to TProcSym(AObject).ProcdefList.Count-1 do
          begin
            lProcDef:=TProcDef(TProcSym(AObject).ProcdefList[lIndex]);
            if po_msgstr in lProcDef.ProcOptions then
              begin
                new(lTree);
                lTree^.Data:=lProcDef;
                lTree^.Left:=nil;
                lTree^.Right:=nil;
                InsertStr(lTree,FRoot,PLongInt(AArg)^);
              end;
          end;
      end;


    procedure TVMTWriter.WriteNames(ATypedConstBuilder: TTAITypedConstBuilder; ATree: PProcDefTree);
      var
        lDataTypedConstBuilder : TTAITypedConstBuilder;
        lLength : Byte;
      begin
         if Assigned(ATree^.Left) then
           WriteNames(ATypedConstBuilder,ATree^.Left);
         ATypedConstBuilder.start_internal_data_builder(CurrentAsmData.AsmLists[al_const],sec_rodata,FClass.VMT_MangledName,lDataTypedConstBuilder,ATree^.NameLabel);
         lLength:=length(ATree^.Data.MessageInf.str^);
         lDataTypedConstBuilder.maybe_begin_aggregate(CArrayDef.getreusable(CAnsiCharType,lLength+1));
         lDataTypedConstBuilder.emit_tai(TAIString.Create_Data(@ATree^.Data.MessageInf.str^[0],lLength+1,false),CArrayDef.getreusable(CAnsiCharType,lLength+1));
         lDataTypedConstBuilder.maybe_end_aggregate(CArrayDef.getreusable(CAnsiCharType,lLength+1));
         ATypedConstBuilder.finish_internal_data_builder(lDataTypedConstBuilder,ATree^.NameLabel,CArrayDef.getreusable(CAnsiCharType,lLength+1),sizeof(PInt));
         if Assigned(ATree^.Right) then
           WriteNames(ATypedConstBuilder,ATree^.Right);
      end;

    procedure TVMTWriter.WriteStrEntry(ATypedConstBuilder: TTAITypedConstBuilder; ATree: PProcDefTree; AEntryDef: TDef);
      begin
         if Assigned(ATree^.Left) then
           WriteStrEntry(ATypedConstBuilder,ATree^.Left,AEntryDef);

         { write name label }
         ATypedConstBuilder.maybe_begin_aggregate(AEntryDef);
         ATypedConstBuilder.emit_tai(TAIConst.Create_sym(ATree^.NameLabel),CPointerDef.getreusable(CArrayDef.getreusable(CAnsiCharType,length(ATree^.Data.MessageInf.str^)+1)));
         ATypedConstBuilder.queue_init(VoidCodePointerType);
         ATypedConstBuilder.queue_emit_proc(ATree^.Data);
         ATypedConstBuilder.maybe_end_aggregate(AEntryDef);

         if Assigned(ATree^.Right) then
           WriteStrEntry(ATypedConstBuilder,ATree^.Right,AEntryDef);
     end;


    procedure TVMTWriter.GenStrMsgTab(ATypedConstBuilder: TTAITypedConstBuilder; out ALabel: TAsmLabel; out AMsgStrTableDef: TRecordDef);
      var
         lCount : LongInt;
         lDataTypedConstBuilder: TTAITypedConstBuilder;
         lMsgStrEntry: TDef;
         lMsgArrayDef: TArrayDef;
      begin
         FRoot:=nil;
         lCount:=0;
         { insert all message handlers into a tree, sorted by name }
         FClass.SymTable.SymList.ForEachCall(@InsertMsgStr,@lCount);

         { write all names }
         if Assigned(FRoot) then
           WriteNames(ATypedConstBuilder,FRoot);

         { now start writing the message string table }
         ATypedConstBuilder.start_internal_data_builder(CurrentAsmData.AsmLists[al_const],sec_rodata,FClass.VMT_MangledName,lDataTypedConstBuilder,ALabel);
         {
           TStringMessageTable = record
              count : longint;
              msgstrtable : array[0..0] of tmsgstrtable;
           end;

           Instead of 0 as the upper bound, use the actual upper bound
         }
         lMsgStrEntry:=Search_System_Type('TMSGSTRTABLE').TypeDef;
         Get_TableDef(itp_vmt_tstringmesssagetable,S32IntType,lMsgStrEntry,lCount,0,AMsgStrTableDef,lMsgArrayDef);
         { outer record (TStringMessageTable) }
         lDataTypedConstBuilder.maybe_begin_aggregate(AMsgStrTableDef);
         lDataTypedConstBuilder.emit_tai(TAIConst.Create_32bit(lCount),S32IntType);
         if Assigned(FRoot) then
           begin
              { array of TMsgStrTable }
              lDataTypedConstBuilder.maybe_begin_aggregate(lMsgArrayDef);
              WriteStrEntry(lDataTypedConstBuilder,FRoot,lMsgStrEntry);
              lDataTypedConstBuilder.maybe_end_aggregate(lMsgArrayDef);
              DisposeProcDefTree(FRoot);
           end;
         lDataTypedConstBuilder.maybe_end_aggregate(AMsgStrTableDef);
         ATypedConstBuilder.finish_internal_data_builder(lDataTypedConstBuilder,ALabel,AMsgStrTableDef,sizeof(PInt));
      end;


    procedure TVMTWriter.WriteIntEntry(ATypedConstBuilder: TTAITypedConstBuilder; ATree: PProcDefTree; AEntryDef: TDef);
      begin
         if Assigned(ATree^.Left) then
           WriteIntEntry(ATypedConstBuilder,ATree^.Left,AEntryDef);

         ATypedConstBuilder.maybe_begin_aggregate(AEntryDef);
         { write integer dispatch number }
         ATypedConstBuilder.emit_tai(TAIConst.Create_32bit(ATree^.Data.MessageInf.i),U32IntType);
         ATypedConstBuilder.queue_init(VoidCodePointerType);
         ATypedConstBuilder.queue_emit_proc(ATree^.Data);
         ATypedConstBuilder.maybe_end_aggregate(AEntryDef);

         if Assigned(ATree^.Right) then
           WriteIntEntry(ATypedConstBuilder,ATree^.Right,AEntryDef);
      end;


    procedure TVMTWriter.GenIntMsgTab(ATypedConstBuilder: TTAITypedConstBuilder; out ALabel: TAsmLabel; out AMsgIntTableDef: TRecordDef);
      var
         lCount : LongInt;
         lDataTypedConstBuilder: TTAITypedConstBuilder;
         lMsgIntDef: TRecordDef;
         lMsgIntArrayDef: TArrayDef;
      begin
         FRoot:=nil;
         lCount:=0;
         { insert all message handlers into a tree, sorted by name }
         FClass.SymTable.SymList.ForEachCall(@InsertMsgInt,@lCount);

         { now start writing of the message string table }

         { from objpas.inc:
             TMsgIntTable = record
                index : dword;
                method : codepointer;
             end;
         }
         AMsgIntTableDef:=Get_RecordDef(itp_vmt_intern_msgint_table,[U32IntType,VoidCodePointerType],0);
         { from objpas.inc:
             TMsgInt = record
                count : longint;
                msgs : array[0..0] of TMsgIntTable;
             end;
         }
         ATypedConstBuilder.start_internal_data_builder(CurrentAsmData.AsmLists[al_const],sec_rodata,FClass.VMT_MangledName,lDataTypedConstBuilder,ALabel);
         Get_TableDef(itp_vmt_msgint_table_entries,S32IntType,AMsgIntTableDef,lCount,0,lMsgIntDef,lMsgIntArrayDef);
         lDataTypedConstBuilder.maybe_begin_aggregate(lMsgIntDef);
         lDataTypedConstBuilder.emit_tai(TAIConst.Create_32bit(lCount),S32IntType);
         if Assigned(FRoot) then
           begin
              lDataTypedConstBuilder.maybe_begin_aggregate(lMsgIntArrayDef);
              WriteIntEntry(lDataTypedConstBuilder,FRoot,AMsgIntTableDef);
              lDataTypedConstBuilder.maybe_end_aggregate(lMsgIntArrayDef);
              DisposeProcDefTree(FRoot);
           end;
         lDataTypedConstBuilder.maybe_end_aggregate(lMsgIntDef);
         ATypedConstBuilder.finish_internal_data_builder(lDataTypedConstBuilder,ALabel,lMsgIntDef,sizeof(PInt));
      end;


{**************************************
        Published Methods
**************************************}

    procedure TVMTWriter.Do_Count_Published_Methods(AObject:TObject;AArg:Pointer);
      var
        lIndex  : LongInt;
        lProcDef : TProcDef;
      begin
        if (TSym(AObject).typ<>ProcSym) then
          exit;
        for lIndex:=0 to TProcSym(AObject).ProcdefList.Count-1 do
          begin
            lProcDef:=TProcDef(TProcSym(AObject).ProcdefList[lIndex]);
            if (lProcDef.ProcSym=TSym(AObject)) and
               (lProcDef.visibility=vis_published) then
              inc(PLongInt(AArg)^);
          end;
      end;


    type
      TVMTAsmOutput = record
        PubMethodsTCB: TTAITypedConstBuilder;
        MethodNameRec: TRecordDef;
      end;
      PVMTAsmOutput = ^TVMTAsmOutput;

    procedure TVMTWriter.Do_Gen_Published_Methods(AObject:TObject;AArg:Pointer);
      var
        lIndex  : LongInt;
        lLabel  : TAsmLabel;
        lProcDef : TProcDef;
        lLists: PVMTAsmOutput absolute AArg;
        lDataTypedConstBuilder  : TTAITypedConstBuilder;
        lNameDef : TDef;
      begin
        if (TSym(AObject).typ<>ProcSym) then
          exit;
        for lIndex:=0 to TProcSym(AObject).ProcdefList.Count-1 do
          begin
            lProcDef:=TProcDef(TProcSym(AObject).ProcdefList[lIndex]);
            if (lProcDef.ProcSym=TSym(AObject)) and
               (lProcDef.visibility=vis_published) then
              begin
                { l: name_of_method }
                lLists^.PubMethodsTCB.start_internal_data_builder(CurrentAsmData.AsmLists[al_const],sec_rodata,FClass.VMT_MangledName,lDataTypedConstBuilder,lLabel);
                lNameDef:=lDataTypedConstBuilder.emit_shortstring_const(TSym(AObject).realname);
                lLists^.PubMethodsTCB.finish_internal_data_builder(lDataTypedConstBuilder,lLabel,lNameDef,sizeof(PInt));
                { the tmethodnamerec }
                lLists^.PubMethodsTCB.maybe_begin_aggregate(lLists^.MethodNameRec);
                { convert the pointer to the name into a generic pshortstring,
                  so all entries can share the same recorddef }
                lLists^.PubMethodsTCB.queue_init(CharPointerType);
                lLists^.PubMethodsTCB.queue_emit_asmsym(lLabel,lNameDef);
                if po_abstractmethod in lProcDef.ProcOptions then
                  lLists^.PubMethodsTCB.emit_tai(TAIConst.Create_nil_codeptr,VoidCodePointerType)
                else
                  begin
                    { convert the procdef in a generic voidcodepointer, same
                      reason as above }
                    lLists^.PubMethodsTCB.queue_init(VoidCodePointerType);
                    lLists^.PubMethodsTCB.queue_emit_proc(lProcDef);
                  end;
                lLists^.PubMethodsTCB.maybe_end_aggregate(lLists^.MethodNameRec);
              end;
           end;
      end;


    procedure TVMTWriter.GenPublishedMethodsTable(ATypedConstBuilder: TTAITypedConstBuilder; out ALabel: TAsmLabel; out APublishedMethodsDef: TRecordDef);
      var
         lCount : LongInt;
         lLists : TVMTAsmOutput;
         lPublishedMethodsArrayDef: TArrayDef;
         lMethodsTableDef: TRecordDef;
         lDataTypedConstBuilder: TTAITypedConstBuilder;
         lPackRecords: LongInt;
      begin
        // TODO(ryan): is extended method table packed?
        if (tf_requires_proper_alignment in TargetInfo.Flags) then
          lPackRecords:=0
        else
          lPackRecords:=1;

         lCount:=0;
         FClass.SymTable.SymList.ForEachCall(@Do_Count_Published_Methods,@lCount);
         if (lCount>0) or (FClass.RTTI.options[ro_methods]<>[]) then
           begin
              { in the list of the published methods (from objpas.inc):
                  tmethodnamerec = packed record
                     name : pshortstring;
                     addr : codepointer;
                  end;
              }
              lLists.MethodNameRec:=Get_RecordDef(itp_vmt_intern_tmethodnamerec,[CPointerDef.getreusable(CShortStringType),VoidCodePointerType],1);
              { from objpas.inc:
                  tmethodnametable = packed record
                    count : dword;
                    entries : packed array[0..0] of tmethodnamerec;
                  end;
               }
              ATypedConstBuilder.start_internal_data_builder(CurrentAsmData.AsmLists[al_const],sec_rodata,FClass.VMT_MangledName,lLists.PubMethodsTCB,ALabel);
              Get_TableDef(itp_vmt_intern_tmethodnametable,U32IntType,lLists.MethodNameRec,lCount,lPackRecords,APublishedMethodsDef,lPublishedMethodsArrayDef);
              { begin record encompassing the tmethodnametable and the extended method table }
              lLists.PubMethodsTCB.begin_anonymous_record('',lPackRecords,
                  APublishedMethodsDef.Alignment, targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
              { begin tmethodnametable }
              lLists.PubMethodsTCB.maybe_begin_aggregate(APublishedMethodsDef);
              { emit count field }
              lLists.PubMethodsTCB.emit_tai(TAIConst.Create_32bit(lCount),U32IntType);
              if lCount>0 then
                begin
                  { begin entries field (array) }
                  lLists.PubMethodsTCB.maybe_begin_aggregate(lPublishedMethodsArrayDef);
                  { add all entries elements }
                  FClass.SymTable.SymList.ForEachCall(@Do_Gen_Published_Methods,@lLists);
                  { end entries field (array) }
                  lLists.PubMethodsTCB.maybe_end_aggregate(lPublishedMethodsArrayDef);
                end;
              { end methodnametable }
              lLists.PubMethodsTCB.maybe_end_aggregate(APublishedMethodsDef);
              { write extended method rtti }
              RTTIWriter.Write_Extended_Method_Table(lLists.PubMethodsTCB,FClass);
              { end the encompassing record }
              lMethodsTableDef:=lLists.PubMethodsTCB.end_anonymous_record;
              ATypedConstBuilder.finish_internal_data_builder(lLists.PubMethodsTCB,ALabel,lMethodsTableDef,sizeof(PInt));
           end
         else
           begin
             ALabel:=nil;
             APublishedMethodsDef:=nil;
           end;
      end;


    procedure TVMTWriter.Generate_Field_Table(ATypedConstBuilder: TTAITypedConstBuilder; out ALabel: TAsmLabel; out AFieldTableDef: TRecordDef);
      var
        lIndex   : LongInt;
        lSym : TSym;
        lClassTable : TAsmLabel;
        lClassIndex,
        lFieldCount : LongInt;
        lClassTableList : TFPList;
        lDataTypedConstBuilder: TTAITypedConstBuilder;
        lPackRecords: LongInt;
        lClassDef: TObjectDef;
        lClassTableDef: TRecordDef;
      begin
        lClassTable:=nil;
        lClassTableList:=TFPList.Create;
        lClassTableDef:=nil;
        { retrieve field info fields }
        lFieldCount:=0;
        for lIndex:=0 to FClass.SymTable.SymList.Count-1 do
          begin
            lSym:=TSym(FClass.SymTable.SymList[lIndex]);
            if (lSym.typ=FieldVarSym) and
               not(sp_static in lSym.SymOptions) and
               (lSym.visibility=vis_published) then
             begin
                if TFieldVarSym(lSym).vardef.typ<>objectdef then
                  InternalError(200611032);
                lClassIndex:=lClassTableList.IndexOf(TFieldVarSym(lSym).vardef);
                if lClassIndex=-1 then
                  lClassTableList.Add(TFieldVarSym(lSym).vardef);
                inc(lFieldCount);
             end;
          end;

        if (lFieldCount>0) or (FClass.RTTI.options[ro_fields]<>[]) then
          begin
            if (tf_requires_proper_alignment in TargetInfo.Flags) then
              lPackRecords:=0
            else
              lPackRecords:=1;

            { generate the class table }
            if lClassTableList.count>0 then
              begin
                ATypedConstBuilder.start_internal_data_builder(CurrentAsmData.AsmLists[al_const],sec_rodata,FClass.VMT_MangledName,lDataTypedConstBuilder,lClassTable);
                lDataTypedConstBuilder.begin_anonymous_record('$fpc_intern_classtable_'+ToStr(lClassTableList.Count-1),
                  lPackRecords,1,
                  targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
                lDataTypedConstBuilder.emit_tai(TAIConst.Create_16bit(lClassTableList.count),U16IntType);
                for lIndex:=0 to lClassTableList.Count-1 do
                  begin
                    lClassDef:=TObjectDef(lClassTableList[lIndex]);
                    { type of the field }
                    lDataTypedConstBuilder.queue_init(VoidPointerType);
                    { reference to the vmt }
                    lDataTypedConstBuilder.queue_emit_asmsym(
                      CurrentAsmData.RefAsmSymbol(lClassDef.VMT_MangledName,AT_DATA,true),
                      TFieldVarSym(lClassDef.VMTField).vardef);
                  end;
                lClassTableDef:=lDataTypedConstBuilder.end_anonymous_record;
                ATypedConstBuilder.finish_internal_data_builder(lDataTypedConstBuilder,lClassTable,lClassTableDef,sizeof(PInt));
              end;

            { write fields }
            {
              TFieldTable =
             $ifndef FPC_REQUIRES_PROPER_ALIGNMENT
              packed
             $endif FPC_REQUIRES_PROPER_ALIGNMENT
              record
                FieldCount: Word;
                ClassTable: Pointer;
                Fields: array[0..0] of TFieldInfo
              end;
            }
            ATypedConstBuilder.start_internal_data_builder(CurrentAsmData.AsmLists[al_const],sec_rodata,FClass.VMT_MangledName,lDataTypedConstBuilder,ALabel);
            { can't easily specify a name here for reuse of the constructed def,
              since it's full of variable length shortstrings (-> all of those
              lengths and their order would have to incorporated in the name,
              plus there would be very little chance that it could actually be
              reused }
            lDataTypedConstBuilder.begin_anonymous_record('',lPackRecords,1,
              targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
            lDataTypedConstBuilder.emit_tai(TAIConst.Create_16bit(lFieldCount),U16IntType);
            if lClassTable<>nil then
              lDataTypedConstBuilder.emit_tai(TAIConst.Create_sym(lClassTable),CPointerDef.getreusable(lClassTableDef))
            else
              lDataTypedConstBuilder.emit_tai(TAIConst.Create_nil_codeptr,VoidPointerType);
            if lFieldCount>0 then
              begin
                for lIndex:=0 to FClass.SymTable.SymList.Count-1 do
                  begin
                    lSym:=TSym(FClass.SymTable.SymList[lIndex]);
                    if (lSym.typ=FieldVarSym) and
                       not(sp_static in lSym.SymOptions) and
                      (lSym.visibility=vis_published) then
                      begin
                        { skip non-object defs for legacy rtti }
                        if TFieldVarSym(lSym).vardef.typ<>objectdef then
                          continue;
                        {
                          TFieldInfo =
                         $ifndef FPC_REQUIRES_PROPER_ALIGNMENT
                          packed
                         $endif FPC_REQUIRES_PROPER_ALIGNMENT
                          record
                            FieldOffset: SizeUInt;
                            ClassTypeIndex: Word;
                            Name: ShortString;
                          end;
                        }
                        lDataTypedConstBuilder.begin_anonymous_record('$fpc_intern_fieldinfo_'+ToStr(length(TFieldVarSym(lSym).realname)),lPackRecords,1,
                          targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
                        lDataTypedConstBuilder.emit_tai(TAIConst.Create_sizeint(TFieldVarSym(lSym).FieldOffset),SizeUIntType);
                        lClassIndex:=lClassTableList.IndexOf(TFieldVarSym(lSym).vardef);
                        if lClassIndex=-1 then
                          InternalError(200611033);
                        lDataTypedConstBuilder.emit_tai(TAIConst.Create_16bit(lClassIndex+1),U16IntType);
                        lDataTypedConstBuilder.emit_shortstring_const(TFieldVarSym(lSym).realname);
                        lDataTypedConstBuilder.end_anonymous_record;
                      end;
                  end;
              end;
            { append the extended rtti table }
            RTTIWriter.Write_Extended_Field_Table(lDataTypedConstBuilder,FClass);
            AFieldTableDef:=lDataTypedConstBuilder.end_anonymous_record;
            ATypedConstBuilder.finish_internal_data_builder(lDataTypedConstBuilder,ALabel,AFieldTableDef,sizeof(PInt));
          end
        else
          begin
            AFieldTableDef:=nil;
            ALabel:=nil;
          end;

        lClassTableList.free;
        lClassTableList := nil;
      end;


{**************************************
           Interface tables
**************************************}

    function CreateWrapperName(AClassDef : TObjectDef;AImplIntf : TImplementedInterface;AIndex : LongInt;AProcDef : TProcDef) : TSymStr;
      var
        lRealInterfaceDef: TObjectDef;
        lTempString : AnsiString;
        lString : TSymStr;
        lHash : QWord;
      begin
        lRealInterfaceDef:=AImplIntf.IntfDef;
        while lRealInterfaceDef.Is_Unique_ObjPasDef do
          lRealInterfaceDef:=lRealInterfaceDef.ChildOf;

        lTempString:=AClassDef.ObjName^+'_$_'+Make_MangledName('',lRealInterfaceDef.owner,'')+'_$$_'+lRealInterfaceDef.ObjName^+'_$_'+ToStr(AIndex)+'_$_'+AProcDef.MangledName;
        if length(lTempString)>50 then
          begin
            lHash:=InitFNV64;
            lHash:=UpdateFNV64(lHash,lTempString[51],length(lTempString)-50);
            lString:=copy(lTempString,1,50)+'$H'+Base64Mangle(lHash);
          end
        else
          lString:=lTempString;
        Result:=Make_MangledName('WRPR',AClassDef.owner,lString);
      end;


    procedure TVMTWriter.Intf_Create_VTbl(ATypedConstBuilder: TTAITypedConstBuilder; AImplIntf: TImplementedInterface; AInterfaceIndex: LongInt);
      var
        lDataTypedConstBuilder : TTAITypedConstBuilder;
        lProcDef : TProcDef;
        lString : TSymStr;
        lIndex  : LongInt;
      begin
        ATypedConstBuilder.start_internal_data_builder(CurrentAsmData.AsmLists[al_const],sec_rodata,'',lDataTypedConstBuilder,FIntfVTableLabels[AInterfaceIndex]);
        lDataTypedConstBuilder.begin_anonymous_record('',0,1,
          targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
        if Assigned(AImplIntf.procdefs) then
          begin
            for lIndex:=0 to AImplIntf.procdefs.count-1 do
              begin
                lProcDef:=TProcDef(AImplIntf.procdefs[lIndex]);
                lString:=CreateWrapperName(FClass,AImplIntf,lIndex,lProcDef);
                { create reference }
                lDataTypedConstBuilder.emit_tai(TAIConst.Createname(lString,AT_FUNCTION,0),CProcVarDef.GetReusableProcAddr(lProcDef,pc_address_only));
              end;
           end
        else
          { can't have an empty symbol on LLVM }
          lDataTypedConstBuilder.emit_tai(TAIConst.Create_nil_codeptr,VoidPointerType);
        ATypedConstBuilder.finish_internal_data_builder(lDataTypedConstBuilder,FIntfVTableLabels[AInterfaceIndex],
          lDataTypedConstBuilder.end_anonymous_record,sizeof(PInt));
      end;


    procedure TVMTWriter.Intf_Gen_Intf_Ref(ATypedConstBuilder: TTAITypedConstBuilder; AImplIntf: TImplementedInterface; AInterfaceIndex: LongInt; AInterfaceEntryDef, AInterfaceEntryTypeDef: TDef);
      var
        lProcDef: TProcDef;
        lIID,
        lIIDString: TSymStr;
        lNonUniqueInterface: TObjectDef;
      begin
        lNonUniqueInterface:=AImplIntf.IntfDef;
        while lNonUniqueInterface.Is_Unique_ObjPasDef do
          lNonUniqueInterface:=lNonUniqueInterface.ChildOf;
        ATypedConstBuilder.maybe_begin_aggregate(AInterfaceEntryDef);
        { GUID (or nil for Corba interfaces) }
        ATypedConstBuilder.next_field:=TAbstractRecordDef(AInterfaceEntryDef).SymTable.Find('IIDREF') as TFieldVarSym;
        lIID:='';
        if lNonUniqueInterface.ObjectType in [odt_interfacecom] then
          begin
            lIID:=Make_MangledName('IID',lNonUniqueInterface.owner,lNonUniqueInterface.ObjName^);
            ATypedConstBuilder.emit_tai(TAIConst.Create_sym_offset(
              CurrentAsmData.RefAsmSymbol(lIID,AT_DATA,true),0),CPointerDef.getreusable(Rec_TGUID));
          end
        else
          ATypedConstBuilder.emit_tai(TAIConst.Create_nil_dataptr,CPointerDef.getreusable(Rec_TGUID));

        { VTable }
        ATypedConstBuilder.next_field:=TAbstractRecordDef(AInterfaceEntryDef).SymTable.Find('VTABLE') as TFieldVarSym;
        ATypedConstBuilder.queue_init(VoidPointerType);
        ATypedConstBuilder.queue_emit_asmsym(FIntfVTableLabels[AInterfaceIndex],lNonUniqueInterface);
        { IOffset field }
        case AImplIntf.VtblImplIntf.IType of
          etFieldValue, etFieldValueClass,
          etStandard:
            begin
              ATypedConstBuilder.next_field:=TAbstractRecordDef(AInterfaceEntryDef).SymTable.Find('IOFFSET') as TFieldVarSym;
              ATypedConstBuilder.emit_tai(TAIConst.Create_sizeint(AImplIntf.VtblImplIntf.IOffset),SizeUIntType);
            end;
          etStaticMethodResult, etStaticMethodClass:
            begin
              ATypedConstBuilder.next_field:=TAbstractRecordDef(AInterfaceEntryDef).SymTable.Find('IOFFSETASCODEPTR') as TFieldVarSym;
              lProcDef:=TProcDef(TPropertySym(AImplIntf.ImplementsGetter).PropAccessList[palt_read].procdef);
              ATypedConstBuilder.queue_init(CodePtrUIntType);
              ATypedConstBuilder.queue_emit_proc(lProcDef);
            end;
          etVirtualMethodResult, etVirtualMethodClass:
            begin
              ATypedConstBuilder.next_field:=TAbstractRecordDef(AInterfaceEntryDef).SymTable.Find('IOFFSET') as TFieldVarSym;
              lProcDef:=TProcDef(TPropertySym(AImplIntf.ImplementsGetter).PropAccessList[palt_read].procdef);
              ATypedConstBuilder.emit_tai(TAIConst.Create_sizeint(TObjectDef(lProcDef.struct).VMTMethodOffset(lProcDef.ExtNumber)),SizeUIntType);
            end;
        end;

        { IIDStr }
        ATypedConstBuilder.next_field:=TAbstractRecordDef(AInterfaceEntryDef).SymTable.Find('IIDSTRREF') as TFieldVarSym;
        lIIDString:=Make_MangledName('IIDSTR',lNonUniqueInterface.owner,lNonUniqueInterface.ObjName^);
        ATypedConstBuilder.queue_init(CPointerDef.getreusable(CShortStringType));
        ATypedConstBuilder.queue_emit_asmsym(
          CurrentAsmData.RefAsmSymbol(
            lIIDString,
            AT_DATA,
            true),
          CPointerDef.getreusable(CArrayDef.getreusable(CAnsiCharType,length(lNonUniqueInterface.IIDStr^)+1)));
        { IType }
        ATypedConstBuilder.next_field:=TAbstractRecordDef(AInterfaceEntryDef).SymTable.Find('ITYPE') as TFieldVarSym;
        ATypedConstBuilder.emit_ord_const(AInt(AImplIntf.VtblImplIntf.IType),AInterfaceEntryTypeDef);
        ATypedConstBuilder.maybe_end_aggregate(AInterfaceEntryDef);

        if FindUnitSymTable(lNonUniqueInterface.owner).ModuleID<>FindUnitSymTable(FClass.owner).ModuleID then
          begin
            if lIID<>'' then
              CurrentModule.Add_Extern_AsmSym(lIID,AB_EXTERNAL,AT_DATA);
            CurrentModule.Add_Extern_AsmSym(lIIDString,AB_EXTERNAL,AT_DATA);
          end;
      end;


    procedure TVMTWriter.Intf_Write_Table(ATypedConstBuilder: TTAITypedConstBuilder; out ALabel: TAsmLabel; out AInterfaceTableDef: TRecordDef);
      var
        lIndex        : LongInt;
        lImplIntf : TImplementedInterface;
        lDataTypedConstBuilder      : TTAITypedConstBuilder;
        lInterfaceEntryDef : TDef;
        lInterfaceEntryTypeDef: TDef;
        lInterfaceArray: TDef;
      begin
        SetLength(FIntfVTableLabels,FClass.ImplementedInterfaces.count);

        { Write unique vtbls }
        for lIndex:=0 to FClass.ImplementedInterfaces.count-1 do
          begin
            lImplIntf:=TImplementedInterface(FClass.ImplementedInterfaces[lIndex]);
            if lImplIntf.VtblImplIntf=lImplIntf then
              Intf_Create_VTbl(ATypedConstBuilder,lImplIntf,lIndex)
          end;
        { Set labels for aliased vtbls (after all unique vtbls have been
          written, so all labels have been defined already) }
        for lIndex:=0 to FClass.ImplementedInterfaces.count-1 do
          begin
            lImplIntf:=TImplementedInterface(FClass.ImplementedInterfaces[lIndex]);
            if lImplIntf.VtblImplIntf<>lImplIntf then
              FIntfVTableLabels[lIndex]:=FIntfVTableLabels[FClass.ImplementedInterfaces.IndexOf(lImplIntf.VtblImplIntf)];
          end;

        ATypedConstBuilder.start_internal_data_builder(CurrentAsmData.AsmLists[al_const],sec_rodata,FClass.VMT_MangledName,lDataTypedConstBuilder,ALabel);
        lDataTypedConstBuilder.begin_anonymous_record('',Default_Settings.PackRecords,1,
          targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
        lDataTypedConstBuilder.emit_tai(TAIConst.Create_sizeint(FClass.ImplementedInterfaces.count),SizeUIntType);
        lInterfaceEntryDef:=Search_System_Type('TINTERFACEENTRY').TypeDef;
        lInterfaceEntryTypeDef:=Search_System_Type('TINTERFACEENTRYTYPE').TypeDef;
        if FClass.ImplementedInterfaces.count>0 then
          begin
            lInterfaceArray:=CArrayDef.getreusable(lInterfaceEntryDef,FClass.ImplementedInterfaces.count);
            lDataTypedConstBuilder.maybe_begin_aggregate(lInterfaceArray);
            { Write vtbl references }
            for lIndex:=0 to FClass.ImplementedInterfaces.count-1 do
              begin
                lImplIntf:=TImplementedInterface(FClass.ImplementedInterfaces[lIndex]);
                Intf_Gen_Intf_Ref(lDataTypedConstBuilder,lImplIntf,lIndex,lInterfaceEntryDef,lInterfaceEntryTypeDef);
              end;
            lDataTypedConstBuilder.maybe_end_aggregate(lInterfaceArray);
          end;
        AInterfaceTableDef:=lDataTypedConstBuilder.end_anonymous_record;
        ATypedConstBuilder.finish_internal_data_builder(lDataTypedConstBuilder,ALabel,AInterfaceTableDef,AInterfaceTableDef.Alignment);

      end;


  { Write interface identifiers to the data section }
  procedure TVMTWriter.WriteInterfaceIDs(AList: TAsmList);
    var
      lString : String;
      lTypedConstBuilder : TTAITypedConstBuilder;
      lDef : TDef;
      lSym : TAsmSymbol;
    begin
      if Assigned(FClass.IIDGUID) then
        begin
          lString:=Make_MangledName('IID',FClass.owner,FClass.ObjName^);
          lTypedConstBuilder:=CTAITypedConstBuilder.Create([tcalo_make_dead_strippable,tcalo_data_force_indirect]);
          lTypedConstBuilder.emit_guid_const(FClass.IIDGUID^);
          lSym:=CurrentAsmData.DefineAsmSymbol(lString,AB_GLOBAL,AT_DATA_NOINDIRECT,Rec_TGUID);
          AList.ConcatList(lTypedConstBuilder.get_final_asmlist(
            lSym,
            Rec_TGUID,
            sec_rodata,
            lString,
            sizeof(PInt)));
          lTypedConstBuilder.free;
          lTypedConstBuilder := nil;
          CurrentModule.Add_Public_AsmSym(lSym);
        end;
      lString:=Make_MangledName('IIDSTR',FClass.owner,FClass.ObjName^);
      lTypedConstBuilder:=CTAITypedConstBuilder.Create([tcalo_make_dead_strippable,tcalo_data_force_indirect]);
      lDef:=lTypedConstBuilder.emit_shortstring_const(FClass.IIDStr^);
      lSym:=CurrentAsmData.DefineAsmSymbol(lString,AB_GLOBAL,AT_DATA_NOINDIRECT,lDef);
      AList.ConcatList(lTypedConstBuilder.get_final_asmlist(
        lSym,
        lDef,
        sec_rodata,
        lString,
        sizeof(PInt)));
      lTypedConstBuilder.free;
      lTypedConstBuilder := nil;
      CurrentModule.Add_Public_AsmSym(lSym);
    end;


  class function TVMTWriter.Use_VMT_Writer: Boolean;
    begin
      Result:=true;
    end;


    function TVMTWriter.RedirectToEmpty(AProcDef : TProcDef) : Boolean;
      var
        lIndex : LongInt;
        lParaLocation : PCGParaLocation;
      begin
        Result:=false;
        if AProcDef.isempty then
          begin
{$ifdef x86}
            ParaManager.Create_FuncRetLoc_Info(AProcDef,calleeside);
            if (AProcDef.FuncRetLoc[calleeside].Location^.Loc=LOC_FPUREGISTER) then
              exit;
{$endif x86}
            AProcDef.Init_ParaLoc_Info(callerside);
            { we can redirect the call if no memory parameter is passed }
            for lIndex:=0 to AProcDef.paras.count-1 do
              begin
                lParaLocation:=TParaVarSym(AProcDef.paras[lIndex]).ParaLoc[callerside].Location;
                while Assigned(lParaLocation) do
                  begin
                    if not(lParaLocation^.Loc in [LOC_REGISTER,LOC_MMREGISTER,LOC_FPUREGISTER]) then
                      exit;
                    lParaLocation:=lParaLocation^.Next;
                  end;
              end;
            Result:=true;
          end;
      end;


    procedure TVMTWriter.Generate_Abstract_Stub(AList:TAsmList;AProcDef:TProcDef);
      begin
        { Generate stubs for abstract methods, so their symbols are present and
          can be used e.g. to take address (see issue #24536). }
        if (po_global in AProcDef.ProcOptions) and
           (AProcDef.owner.DefOwner<>Self.FClass) then
          exit;
        AProcDef.SyntheticKind:=tsk_call_no_parameters;
        AProcDef.SKPara:=Search_System_Proc('ABSTRACTERROR');
        { abstract methods are not marked as forwarddef, because otherwise
          the compiler would accept implementations for them (and complain if
          they were missing); we are now after parsing the user code, so we can
          mark them again as forwarddef to indicate they need to be parsed }
        AProcDef.ForwardDef:=true;
      end;


    procedure TVMTWriter.writevirtualmethods(ATypedConstBuilder: TTAITypedConstBuilder);
      var
         lVMTProcDef : TProcDef;
         lVMTEntry : PVMTEntry;
         lIndex  : LongInt;
         lProcName : TSymStr;
{$ifdef vtentry}
         lString : String;
{$endif vtentry}
      begin
        for lIndex:=0 to FClass.VMTEntries.Count-1 do
         begin
           lVMTEntry:=PVMTEntry(FClass.VMTEntries[lIndex]);
           lVMTProcDef:=lVMTEntry^.procdef;
           { safety checks }
           if not(po_virtualmethod in lVMTProcDef.ProcOptions) then
             InternalError(200611082);
           if lVMTProcDef.ExtNumber<>lIndex then
             InternalError(200611083);
           if (po_abstractmethod in lVMTProcDef.ProcOptions) then
             begin
               lProcName:='FPC_ABSTRACTERROR';
               Generate_Abstract_Stub(CurrentAsmData.AsmLists[al_procedures],lVMTProcDef);
             end
           else if (cs_opt_remove_empty_proc in CurrentSettings.OptimizerSwitches) and RedirectToEmpty(lVMTProcDef) then
             begin
               lProcName:='FPC_EMPTYMETHOD';
               if CurrentModule.GlobalSymTable<>SystemUnit then
                 CurrentModule.Add_Extern_AsmSym(lProcName,AB_EXTERNAL,AT_FUNCTION);
             end
           else if not wpoinfomanager.optimized_name_for_vmt(FClass,lVMTProcDef,lProcName) then
             begin
               lProcName:=lVMTProcDef.MangledName;
               if CurrentModule.ModuleID<>lVMTProcDef.owner.ModuleID then
                 CurrentModule.AddImportedSym(lVMTProcDef.ProcSym);
             end;
           ATypedConstBuilder.emit_tai(TAIConst.Createname(lProcName,AT_FUNCTION,0),CProcVarDef.GetReusableProcAddr(lVMTProcDef,pc_address_only));
{$ifdef vtentry}
           lString:='VTENTRY'+'_'+FClass.VMT_MangledName+'$$'+ToStr(FClass.VMTMethodOffset(lIndex) div sizeof(PInt));
           CurrentAsmData.asmlists[al_globals].concat(TAISymbol.CreateName(lString,AT_DATA,0,voidpointerdef));
{$endif vtentry}
         end;
      end;


    procedure TVMTWriter.WriteVMT;
      var
         lMethodNameTable,lIntMessageTable,
         lStringMessageTable,lClassNameLabel,
         lFieldTableLabel : TAsmLabel;
{$ifdef vtentry}
         lString: String;
{$endif vtentry}
         lInterfaceTable : TAsmLabel;
         lTypedConstBuilder, lDataTypedConstBuilder: TTAITypedConstBuilder;
         lClassNameDef: TDef;
         lMethodNameTableDef,
         lFieldTableDef,
         lInterfaceTableDef,
         lStringMessageTableDef,
         lIntMessageTableDef: TRecordDef;
         lParentVMTDef: TDef;
         lInterfaceTablePointerDef,
         lStringMessageTablePointerDef: TDef;
         lVMTTypeSym: TTypeSym;
         lVMTDef: TDef;
         lSym : TAsmSymbol;
      begin
         { this code gets executed after the current module's symtable has
           already been removed from the symtablestack -> add it again, so that
           newly created defs here end up in the right unit }
         SymTableStack.push(CurrentModule.LocalSymTable);
         lStringMessageTable:=nil;
         lInterfaceTable:=nil;
         lFieldTableLabel:=nil;
         lMethodNameTable:=nil;
         lIntMessageTable:=nil;
         lClassNameLabel:=nil;

         lClassNameDef:=nil;
         lMethodNameTableDef:=nil;
         lFieldTableDef:=nil;
         lInterfaceTableDef:=nil;
         lStringMessageTableDef:=nil;
         lIntMessageTableDef:=nil;

         { generate VMT }
         lTypedConstBuilder:=CTAITypedConstBuilder.Create([tcalo_make_dead_strippable,tcalo_data_force_indirect]);

         { write tables for classes, this must be done before the actual
           class is written, because we need the labels defined }
         if Is_Class(FClass) then
          begin
            { write class name }
            lTypedConstBuilder.start_internal_data_builder(CurrentAsmData.asmlists[al_const],sec_rodata,FClass.VMT_MangledName,lDataTypedConstBuilder,lClassNameLabel);
            lClassNameDef:=lDataTypedConstBuilder.emit_shortstring_const(FClass.RTTIName);
            lTypedConstBuilder.finish_internal_data_builder(lDataTypedConstBuilder,lClassNameLabel,lClassNameDef,sizeof(PInt));

            { interface table }
            if FClass.Implements_Any_Interfaces then
              Intf_Write_Table(lTypedConstBuilder,lInterfaceTable,lInterfaceTableDef);

            GenPublishedMethodsTable(lTypedConstBuilder,lMethodNameTable,lMethodNameTableDef);
            Generate_Field_Table(lTypedConstBuilder,lFieldTableLabel,lFieldTableDef);

            { generate message and dynamic tables }
            if (oo_has_msgstr in FClass.ObjectOptions) then
              GenStrMsgTab(lTypedConstBuilder,lStringMessageTable,lStringMessageTableDef);
            if (oo_has_msgint in FClass.ObjectOptions) then
              GenIntMsgTab(lTypedConstBuilder,lIntMessageTable,lIntMessageTableDef);
          end;

         { reuse the type created in nobj, so we get internal consistency
           checking for free }
         lVMTTypeSym:=TTypeSym(FClass.SymTable.find('vmtdef'));
         if not Assigned(lVMTTypeSym) or
            (lVMTTypeSym.typ<>TypeSym) or
            (lVMTTypeSym.TypeDef.typ<>recorddef) then
           InternalError(2015071403);
         lVMTDef:=TRecordDef(lVMTTypeSym.TypeDef);

         lTypedConstBuilder.maybe_begin_aggregate(lVMTDef);

         { determine the size with symtable.datasize, because }
         { size gives back 4 for classes                    }
         lTypedConstBuilder.emit_ord_const(TObjectSymTable(FClass.SymTable).DataSize,SizeSIntType);
         lTypedConstBuilder.emit_ord_const(-Int64(TObjectSymTable(FClass.SymTable).DataSize),SizeSIntType);
         { write pointer to parent VMT, this isn't implemented in TP }
         { but this is not used in FPC ? (PM) }
         { it's not used yet, but the delphi-operators as and is need it (FK) }
         { it is not written for parents that don't have any vmt !! }
         if Is_Class(FClass) then
           lParentVMTDef:=CPointerDef.getreusable(Search_System_Type('TVMT').TypeDef)
         else
           lParentVMTDef:=VoidPointerType;
         if Assigned(FClass.ChildOf) and
            (oo_has_vmt in FClass.ChildOf.ObjectOptions) then
           begin
             lTypedConstBuilder.queue_init(lParentVMTDef);
             lSym:=CurrentAsmData.RefAsmSymbol(FClass.ChildOf.VMT_MangledName,AT_DATA,true);
             lTypedConstBuilder.queue_emit_asmsym(
               lSym,
               TFieldVarSym(FClass.ChildOf.VMTField).vardef);
             if FClass.ChildOf.owner.ModuleID<>CurrentModule.ModuleID then
               CurrentModule.Add_Extern_AsmSym(lSym);
           end
         else
           lTypedConstBuilder.emit_tai(TAIConst.Create_nil_dataptr,lParentVMTDef);

         { write extended info for classes, for the order see rtl/inc/objpash.inc }
         if Is_Class(FClass) then
          begin
            { pointer to class name string }
            lTypedConstBuilder.queue_init(CPointerDef.getreusable(CShortStringType));
            lTypedConstBuilder.queue_emit_asmsym(lClassNameLabel,lClassNameDef);
            { pointer to dynamic table or nil }
            if (oo_has_msgint in FClass.ObjectOptions) then
              begin
                lTypedConstBuilder.queue_init(VoidPointerType);
                lTypedConstBuilder.queue_emit_asmsym(lIntMessageTable,CPointerDef.getreusable(lIntMessageTableDef));
              end
            else
              lTypedConstBuilder.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
            { pointer to method table or nil }
            if Assigned(lMethodNameTable) then
              begin
                lTypedConstBuilder.queue_init(VoidPointerType);
                lTypedConstBuilder.queue_emit_asmsym(lMethodNameTable,CPointerDef.getreusable(lMethodNameTableDef))
              end
            else
              lTypedConstBuilder.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
            { pointer to field table }
            if Assigned(lFieldTableLabel) then
              begin
                lTypedConstBuilder.queue_init(VoidPointerType);
                lTypedConstBuilder.queue_emit_asmsym(lFieldTableLabel,lFieldTableDef)
              end
            else
              lTypedConstBuilder.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
            { pointer to type info of published section }
            lTypedConstBuilder.emit_tai(TAIConst.Create_sym(RTTIWriter.Get_RTTI_Label(FClass,fullrtti,false)),VoidPointerType);
            { inittable for con-/destruction }
            if FClass.Members_Need_InitTable then
              lTypedConstBuilder.emit_tai(TAIConst.Create_sym(RTTIWriter.Get_RTTI_Label(FClass,initrtti,false)),VoidPointerType)
            else
              lTypedConstBuilder.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
            { auto table }
            lTypedConstBuilder.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
            { interface table }
            lInterfaceTablePointerDef:=Search_System_Type('PINTERFACETABLE').TypeDef;
            if FClass.Implements_Any_Interfaces then
              begin
                lTypedConstBuilder.queue_init(lInterfaceTablePointerDef);
                lTypedConstBuilder.queue_emit_asmsym(lInterfaceTable,lInterfaceTableDef)
              end
            else
              lTypedConstBuilder.emit_tai(TAIConst.Create_nil_dataptr,lInterfaceTablePointerDef);
            { table for string messages }
            lStringMessageTablePointerDef:=Search_System_Type('PSTRINGMESSAGETABLE').TypeDef;
            if (oo_has_msgstr in FClass.ObjectOptions) then
              begin
                lTypedConstBuilder.queue_init(VoidPointerType);
                lTypedConstBuilder.queue_emit_asmsym(lStringMessageTable,lStringMessageTablePointerDef);
              end
            else
              lTypedConstBuilder.emit_tai(TAIConst.Create_nil_dataptr,lStringMessageTablePointerDef);
          end;
         { write virtual methods }
         writevirtualmethods(lTypedConstBuilder);
         lTypedConstBuilder.emit_tai(TAIConst.Create_nil_codeptr,VoidCodePointerType);

         lTypedConstBuilder.maybe_end_aggregate(lVMTDef);

         lSym:=CurrentAsmData.DefineAsmSymbol(FClass.VMT_MangledName,AB_GLOBAL,AT_DATA_NOINDIRECT,lVMTDef);
         CurrentModule.Add_Public_AsmSym(lSym);

         { concatenate the VMT to the asmlist }
         CurrentAsmData.asmlists[al_globals].ConcatList(
           lTypedConstBuilder.get_final_asmlist(
             lSym,
             lVMTDef,sec_rodata,FClass.VMT_MangledName,sizeof(PInt)
           )
         );
         lTypedConstBuilder.free;
         lTypedConstBuilder := nil;
{$ifdef vtentry}
         { write vtinherit symbol to notify the linker of the class inheritance tree }
         lString:='VTINHERIT'+'_'+FClass.VMT_MangledName+'$$';
         if Assigned(FClass.ChildOf) then
           lString:=lString+FClass.ChildOf.VMT_MangledName
         else
           lString:=lString+FClass.VMT_MangledName;
         CurrentAsmData.asmlists[al_globals].concat(TAISymbol.CreateName(lString,AT_DATA,0,voidpointerdef));
{$endif vtentry}
        SymTableStack.pop(CurrentModule.LocalSymTable);
      end;


    procedure GenIntfWrapper(AList:TAsmList;AClassDef:TObjectDef);
      var
        lIndex,lIndexJ  : LongInt;
        lTempString : String;
        lProcDef   : TProcDef;
        lImplIntf : TImplementedInterface;
        lWrapperProcDef: TProcDef;
        lWrapperInfo: PSKParaInterfaceWrapper;
        lTempList: TAsmList;
        lOldFilePosInfo: TFilePosInfo;
        lUseHighLevelWrapper: Boolean;
      begin
{$if defined(cpuhighleveltarget)}
        lUseHighLevelWrapper:=true;
{$else defined(cpuhighleveltarget)}
        lUseHighLevelWrapper:=false;
{$endif defined(cpuhighleveltarget)}
        for lIndex:=0 to AClassDef.ImplementedInterfaces.count-1 do
          begin
            lImplIntf:=TImplementedInterface(AClassDef.ImplementedInterfaces[lIndex]);
            if (lImplIntf=lImplIntf.VtblImplIntf) and
               Assigned(lImplIntf.ProcDefs) then
              begin
                for lIndexJ:=0 to lImplIntf.ProcDefs.Count-1 do
                  begin
                    lProcDef:=TProcDef(lImplIntf.ProcDefs[lIndexJ]);
                    { we don't track method calls via interfaces yet ->
                      assume that every method called via an interface call
                      is reachable for now }
                    if (po_virtualmethod in lProcDef.ProcOptions) and
                       not Is_ObjectPascal_Helper(TProcDef(lProcDef).struct) then
                      TObjectDef(TProcDef(lProcDef).struct).Register_VMT_Call(TProcDef(lProcDef).ExtNumber);
                    lTempString:=CreateWrapperName(AClassDef,lImplIntf,lIndexJ,lProcDef);

                  if lUseHighLevelWrapper then
                    begin
                      new(lWrapperInfo);
                      lWrapperInfo^.PD:=lProcDef;
                      lWrapperInfo^.Offset:=lImplIntf.ioffset;
                      { insert the wrapper procdef in the current unit's local
                        symbol table, but set the owning "struct" to the current
                        class (so self will have the correct type) }
                      lWrapperProcDef:=Create_ProcDef_Alias(lProcDef,lTempString,lTempString,
                        CurrentModule.LocalSymTable,AClassDef,
                        tsk_interface_wrapper,lWrapperInfo);
                      include(lWrapperProcDef.ImplProcOptions,pio_thunk);
                    end
                  else
                    begin
                      lOldFilePosInfo:=CurrentFilePos;
                      if lProcDef.owner.IsCurrentUnit then
                        CurrentFilePos:=lProcDef.FileInfo
                      else
                        begin
                          CurrentFilePos.moduleindex:=CurrentModule.ModuleID;
                          CurrentFilePos.fileindex:=1;
                          CurrentFilePos.line:=1;
                          CurrentFilePos.column:=1;
                        end;
                      { create wrapper code }
                      lTempList:=TAsmList.Create;
                      new_section(lTempList,sec_code,lTempString,TargetInfo.Alignment.ProcAlign);
                      lTempList.Concat(TAIFunctionName.Create(lTempString));
                      hlcg.Init_Register_Allocators;
                      hlcg.G_Intf_Wrapper(lTempList,lProcDef,lTempString,lImplIntf.ioffset);
                      hlcg.Done_Register_Allocators;
                      if ((cs_debuginfo in CurrentSettings.ModuleSwitches) or
                         (cs_use_lineinfo in CurrentSettings.GlobalSwitches)) then
                        CurrentDebugInfo.insertlineinfo(lTempList);
                      AList.ConcatList(lTempList);
                      lTempList.Free;
                      lTempList := nil;
                      CurrentFilePos:=lOldFilePosInfo;
                    end;
                  end;
              end;
          end;
      end;


    procedure DoWriteVMTs(ASymTable:TSymTable;AIsGlobal:Boolean);
      var
        lIndex : LongInt;
        lDef : TDef;
        lVMTWriter  : TVMTWriter;
      begin
        if not CVMTWriter.Use_VMT_Writer then
          exit;
        for lIndex:=0 to ASymTable.DefList.Count-1 do
          begin
            lDef:=TDef(ASymTable.DefList[lIndex]);
            case lDef.typ of
              recorddef :
                DoWriteVMTs(TRecordDef(lDef).SymTable,AIsGlobal);
              objectdef :
                begin
                  { Skip generics and forward defs }
                  if ([df_generic,df_genconstraint]*lDef.DefOptions<>[]) or
                     (oo_is_forward in TObjectDef(lDef).ObjectOptions) then
                    continue;
                  if TObjectDef(lDef).Is_Unique_ObjPasDef then
                    continue;
                  DoWriteVMTs(TObjectDef(lDef).SymTable,AIsGlobal);
                  { Write also VMT if not done yet }
                  if not(ds_vmt_written in lDef.DefStates) then
                    begin
                      lVMTWriter:=CVMTWriter.Create(TObjectDef(lDef));
                      if Is_Interface(TObjectDef(lDef)) then
                        lVMTWriter.WriteInterfaceIDs(CurrentAsmData.AsmLists[al_globals]);
                      if (oo_has_vmt in TObjectDef(lDef).ObjectOptions) then
                        lVMTWriter.WriteVMT;
                      lVMTWriter.free;
                      lVMTWriter := nil;
                      include(lDef.DefStates,ds_vmt_written);
                    end;
                  if Is_Class(lDef) then
                    GenIntfWrapper(CurrentAsmData.asmlists[al_procedures],TObjectDef(lDef));
                end;
              procdef :
                begin
                  if Assigned(TProcDef(lDef).LocalST) and
                     (TProcDef(lDef).LocalST.SymTableType=LocalSymTable) then
                    DoWriteVMTs(TProcDef(lDef).LocalST,false);
                  if Assigned(TProcDef(lDef).ParaST) then
                    DoWriteVMTs(TProcDef(lDef).ParaST,false);
                end;
              else
                ;
            end;
          end;
      end;

    procedure Write_VMTs(ASymTable:TSymTable;AIsGlobal:Boolean);
      begin
{$ifndef cpuhighleveltarget}
        Create_HLCodeGen(THLCGObjHelpers);
{$endif}
        DoWriteVMTs(ASymTable,AIsGlobal);
{$ifndef cpuhighleveltarget}
        Destroy_HLCodeGen;
{$endif}
      end;

end.
