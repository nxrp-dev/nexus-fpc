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
         data : TProcDef;
         nl   : TAsmLabel;
         l,r  : PProcDefTree;
      end;

      TVMTWriter=class
      protected
        _Class : TObjectDef;
        { message tables }
        root : PProcDefTree;
        { implemented interface vtables }
        fintfvtablelabels: array of TAsmLabel;

        procedure disposeprocdeftree(p : PProcDefTree);
        procedure insertmsgint(p:TObject;arg:pointer);
        procedure insertmsgstr(p:TObject;arg:pointer);
        procedure insertint(p : PProcDefTree;var at : PProcDefTree;var count:LongInt);
        procedure insertstr(p : PProcDefTree;var at : PProcDefTree;var count:LongInt);
        function RedirectToEmpty(procdef: TProcDef): boolean;
        procedure writenames(tcb: TTAITypedConstBuilder; p: PProcDefTree);
        procedure writeintentry(tcb: TTAITypedConstBuilder; p: PProcDefTree; entrydef: TDef);
        procedure writestrentry(tcb: TTAITypedConstBuilder; p: PProcDefTree; entrydef: TDef);
{$ifdef WITHDMT}
        { dmt }
        procedure insertdmtentry(p:TObject;arg:pointer);
        procedure writedmtindexentry(p : PProcDefTree);
        procedure writedmtaddressentry(p : PProcDefTree);
{$endif}
        { published methods }
        procedure do_count_published_methods(p:TObject;arg:pointer);
        procedure do_gen_published_methods(p:TObject;arg:pointer);
        { virtual methods }
        procedure writevirtualmethods(tcb: TTAITypedConstBuilder);
        { interface tables }
        procedure intf_create_vtbl(tcb: TTAITypedConstBuilder; AImplIntf: TImplementedInterface; intfindex: LongInt);
        procedure intf_gen_intf_ref(tcb: TTAITypedConstBuilder; AImplIntf: TImplementedInterface; intfindex: LongInt; interfaceentrydef, interfaceentrytypedef: TDef);
        procedure intf_write_table(tcb: TTAITypedConstBuilder; out lab: TAsmLabel; out intftabledef: TRecordDef);
        { generates the message tables for a class }
        procedure genstrmsgtab(tcb: TTAITypedConstBuilder; out lab: TAsmLabel; out msgstrtabledef: TRecordDef);
        procedure genintmsgtab(tcb: TTAITypedConstBuilder; out lab: TAsmLabel; out msginttabledef: TRecordDef);
        procedure genpublishedmethodstable(tcb: TTAITypedConstBuilder; out lab: TAsmLabel; out pubmethodsdef: TRecordDef);
        procedure generate_field_table(tcb: TTAITypedConstBuilder; out lab: TAsmLabel; out fieldtabledef: TRecordDef);
        procedure generate_abstract_stub(list:TAsmList;pd:TProcDef); virtual;
{$ifdef WITHDMT}
        { generates a DMT for _class }
        function  gendmt : TAsmLabel;
{$endif WITHDMT}
      public
        constructor create(c:TObjectDef); virtual;
        { write the VMT to al_globals }
        procedure writevmt;
        procedure writeinterfaceids(list: TAsmList);

        class function use_vmt_writer: boolean; virtual;
      end;
      TVMTWriterClass = class of TVMTWriter;

    { generate VMTs }
    procedure write_vmts(st:TSymTable;is_global:boolean);

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

    constructor TVMTWriter.create(c:TObjectDef);
      begin
        inherited Create;
        _Class:=c;
      end;


{**************************************
           Message Tables
**************************************}

    procedure TVMTWriter.disposeprocdeftree(p : PProcDefTree);
      begin
         if Assigned(p^.l) then
           disposeprocdeftree(p^.l);
         if Assigned(p^.r) then
           disposeprocdeftree(p^.r);
         dispose(p);
      end;


    procedure TVMTWriter.insertint(p : PProcDefTree;var at : PProcDefTree;var count:LongInt);
      begin
         if at=nil then
           begin
              at:=p;
              inc(count);
           end
         else
           begin
              if p^.data.MessageInf.i<at^.data.MessageInf.i then
                insertint(p,at^.l,count)
              else if p^.data.MessageInf.i>at^.data.MessageInf.i then
                insertint(p,at^.r,count)
              else
                Message1(parser_e_duplicate_message_label,ToStr(p^.data.MessageInf.i));
           end;
      end;


    procedure TVMTWriter.insertstr(p : PProcDefTree;var at : PProcDefTree;var count:LongInt);
      var
         i : integer;
      begin
         if at=nil then
           begin
              at:=p;
              inc(count);
           end
         else
           begin
              i:=CompareStr(p^.data.MessageInf.str^,at^.data.MessageInf.str^);
              if i<0 then
                insertstr(p,at^.l,count)
              else if i>0 then
                insertstr(p,at^.r,count)
              else
                Message1(parser_e_duplicate_message_label,p^.data.MessageInf.str^);
           end;
      end;


    procedure TVMTWriter.insertmsgint(p:TObject;arg:pointer);
      var
        i  : LongInt;
        pd : TProcDef;
        pt : PProcDefTree;
      begin
        if TSym(p).typ<>ProcSym then
          exit;
        for i:=0 to TProcSym(p).ProcdefList.Count-1 do
          begin
            pd:=TProcDef(TProcSym(p).ProcdefList[i]);
            if po_msgint in pd.ProcOptions then
              begin
                new(pt);
                pt^.data:=pd;
                pt^.l:=nil;
                pt^.r:=nil;
                insertint(pt,root,PLongInt(arg)^);
              end;
          end;
      end;


    procedure TVMTWriter.insertmsgstr(p:TObject;arg:pointer);
      var
        i  : LongInt;
        pd : TProcDef;
        pt : PProcDefTree;
      begin
        if TSym(p).typ<>ProcSym then
          exit;
        for i:=0 to TProcSym(p).ProcdefList.Count-1 do
          begin
            pd:=TProcDef(TProcSym(p).ProcdefList[i]);
            if po_msgstr in pd.ProcOptions then
              begin
                new(pt);
                pt^.data:=pd;
                pt^.l:=nil;
                pt^.r:=nil;
                insertstr(pt,root,PLongInt(arg)^);
              end;
          end;
      end;


    procedure TVMTWriter.writenames(tcb: TTAITypedConstBuilder; p: PProcDefTree);
      var
        datatcb : TTAITypedConstBuilder;
        len : byte;
      begin
         if Assigned(p^.l) then
           writenames(tcb,p^.l);
         tcb.start_internal_data_builder(CurrentAsmData.AsmLists[al_const],sec_rodata,_class.VMT_MangledName,datatcb,p^.nl);
         len:=length(p^.data.MessageInf.str^);
         datatcb.maybe_begin_aggregate(CArrayDef.getreusable(CAnsiCharType,len+1));
         datatcb.emit_tai(TAIString.Create_Data(@p^.data.MessageInf.str^[0],len+1,false),CArrayDef.getreusable(CAnsiCharType,len+1));
         datatcb.maybe_end_aggregate(CArrayDef.getreusable(CAnsiCharType,len+1));
         tcb.finish_internal_data_builder(datatcb,p^.nl,CArrayDef.getreusable(CAnsiCharType,len+1),sizeof(PInt));
         if Assigned(p^.r) then
           writenames(tcb,p^.r);
      end;

    procedure TVMTWriter.writestrentry(tcb: TTAITypedConstBuilder; p: PProcDefTree; entrydef: TDef);
      begin
         if Assigned(p^.l) then
           writestrentry(tcb,p^.l,entrydef);

         { write name label }
         tcb.maybe_begin_aggregate(entrydef);
         tcb.emit_tai(TAIConst.Create_sym(p^.nl),CPointerDef.getreusable(CArrayDef.getreusable(CAnsiCharType,length(p^.data.MessageInf.str^)+1)));
         tcb.queue_init(VoidCodePointerType);
         tcb.queue_emit_proc(p^.data);
         tcb.maybe_end_aggregate(entrydef);

         if Assigned(p^.r) then
           writestrentry(tcb,p^.r,entrydef);
     end;


    procedure TVMTWriter.genstrmsgtab(tcb: TTAITypedConstBuilder; out lab: TAsmLabel; out msgstrtabledef: TRecordDef);
      var
         count : LongInt;
         datatcb: TTAITypedConstBuilder;
         msgstrentry: TDef;
         msgarraydef: TArrayDef;
      begin
         root:=nil;
         count:=0;
         { insert all message handlers into a tree, sorted by name }
         _class.SymTable.SymList.ForEachCall(@insertmsgstr,@count);

         { write all names }
         if Assigned(root) then
           writenames(tcb,root);

         { now start writing the message string table }
         tcb.start_internal_data_builder(CurrentAsmData.AsmLists[al_const],sec_rodata,_class.VMT_MangledName,datatcb,lab);
         {
           TStringMessageTable = record
              count : longint;
              msgstrtable : array[0..0] of tmsgstrtable;
           end;

           Instead of 0 as the upper bound, use the actual upper bound
         }
         msgstrentry:=Search_System_Type('TMSGSTRTABLE').typedef;
         Get_TableDef(itp_vmt_tstringmesssagetable,S32IntType,msgstrentry,count,0,msgstrtabledef,msgarraydef);
         { outer record (TStringMessageTable) }
         datatcb.maybe_begin_aggregate(msgstrtabledef);
         datatcb.emit_tai(TAIConst.Create_32bit(count),S32IntType);
         if Assigned(root) then
           begin
              { array of TMsgStrTable }
              datatcb.maybe_begin_aggregate(msgarraydef);
              writestrentry(datatcb,root,msgstrentry);
              datatcb.maybe_end_aggregate(msgarraydef);
              disposeprocdeftree(root);
           end;
         datatcb.maybe_end_aggregate(msgstrtabledef);
         tcb.finish_internal_data_builder(datatcb,lab,msgstrtabledef,sizeof(PInt));
      end;


    procedure TVMTWriter.writeintentry(tcb: TTAITypedConstBuilder; p: PProcDefTree; entrydef: TDef);
      begin
         if Assigned(p^.l) then
           writeintentry(tcb,p^.l,entrydef);

         tcb.maybe_begin_aggregate(entrydef);
         { write integer dispatch number }
         tcb.emit_tai(TAIConst.Create_32bit(p^.data.MessageInf.i),U32IntType);
         tcb.queue_init(VoidCodePointerType);
         tcb.queue_emit_proc(p^.data);
         tcb.maybe_end_aggregate(entrydef);

         if Assigned(p^.r) then
           writeintentry(tcb,p^.r,entrydef);
      end;


    procedure TVMTWriter.genintmsgtab(tcb: TTAITypedConstBuilder; out lab: TAsmLabel; out msginttabledef: TRecordDef);
      var
         count : LongInt;
         datatcb: TTAITypedConstBuilder;
         msgintdef: TRecordDef;
         msgintarrdef: TArrayDef;
      begin
         root:=nil;
         count:=0;
         { insert all message handlers into a tree, sorted by name }
         _class.SymTable.SymList.ForEachCall(@insertmsgint,@count);

         { now start writing of the message string table }

         { from objpas.inc:
             TMsgIntTable = record
                index : dword;
                method : codepointer;
             end;
         }
         msginttabledef:=Get_RecordDef(itp_vmt_intern_msgint_table,[U32IntType,VoidCodePointerType],0);
         { from objpas.inc:
             TMsgInt = record
                count : longint;
                msgs : array[0..0] of TMsgIntTable;
             end;
         }
         tcb.start_internal_data_builder(CurrentAsmData.AsmLists[al_const],sec_rodata,_class.VMT_MangledName,datatcb,lab);
         Get_TableDef(itp_vmt_msgint_table_entries,S32IntType,msginttabledef,count,0,msgintdef,msgintarrdef);
         datatcb.maybe_begin_aggregate(msgintdef);
         datatcb.emit_tai(TAIConst.Create_32bit(count),S32IntType);
         if Assigned(root) then
           begin
              datatcb.maybe_begin_aggregate(msgintarrdef);
              writeintentry(datatcb,root,msginttabledef);
              datatcb.maybe_end_aggregate(msgintarrdef);
              disposeprocdeftree(root);
           end;
         datatcb.maybe_end_aggregate(msgintdef);
         tcb.finish_internal_data_builder(datatcb,lab,msgintdef,sizeof(PInt));
      end;

{$ifdef WITHDMT}

{**************************************
              DMT
**************************************}

    procedure TVMTWriter.insertdmtentry(p:TObject;arg:pointer);

      var
         hp : TProcDef;
         pt : PProcDefTree;

      begin
         if TSym(p).typ=ProcSym then
           begin
              hp:=TProcSym(p).definition;
              while Assigned(hp) do
                begin
                   if (po_msgint in hp.ProcOptions) then
                     begin
                        new(pt);
                        pt^.p:=hp;
                        pt^.l:=nil;
                        pt^.r:=nil;
                        insertint(pt,root);
                     end;
                   hp:=hp.nextoverloaded;
                end;
           end;
      end;

    procedure TVMTWriter.writedmtindexentry(p : PProcDefTree);

      begin
         if Assigned(p^.l) then
           writedmtindexentry(p^.l);
         al_globals.concat(TAIConst.Create_32bit(p^.data.MessageInf.i));
         if Assigned(p^.r) then
           writedmtindexentry(p^.r);
      end;

    procedure TVMTWriter.writedmtaddressentry(p : PProcDefTree);

      begin
         if Assigned(p^.l) then
           writedmtaddressentry(p^.l);
         al_globals.concat(Tai_const_symbol.Createname(p^.data.MangledName,0));
         if Assigned(p^.r) then
           writedmtaddressentry(p^.r);
      end;

    function TVMTWriter.gendmt : TAsmLabel;

      var
         r : TAsmLabel;

      begin
         root:=nil;
         count:=0;
         gendmt:=nil;
         { insert all message handlers into a tree, sorted by number }
         _class.SymTable.SymList.ForEachCall(insertdmtentry);

         if count>0 then
           begin
              CurrentAsmData.getglobaldatalabel(r);
              gendmt:=r;
              al_globals.concat(CAIAlign.create(sizeof(PInt)));
              al_globals.concat(TAILabel.Create(r));
              { entries for caching }
              al_globals.concat(TAIConst.Create_Ptr(0));
              al_globals.concat(TAIConst.Create_Ptr(0));

              al_globals.concat(TAIConst.Create_32bit(count));
              if Assigned(root) then
                begin
                   writedmtindexentry(root);
                   writedmtaddressentry(root);
                   disposeprocdeftree(root);
                end;
           end;
      end;

{$endif WITHDMT}

{**************************************
        Published Methods
**************************************}

    procedure TVMTWriter.do_count_published_methods(p:TObject;arg:pointer);
      var
        i  : LongInt;
        pd : TProcDef;
      begin
        if (TSym(p).typ<>ProcSym) then
          exit;
        for i:=0 to TProcSym(p).ProcdefList.Count-1 do
          begin
            pd:=TProcDef(TProcSym(p).ProcdefList[i]);
            if (pd.ProcSym=TSym(p)) and
               (pd.visibility=vis_published) then
              inc(PLongInt(arg)^);
          end;
      end;


    type
      TVMTAsmOutput = record
        pubmethodstcb: TTAITypedConstBuilder;
        methodnamerec: TRecordDef;
      end;
      PVMTAsmOutput = ^TVMTAsmOutput;

    procedure TVMTWriter.do_gen_published_methods(p:TObject;arg:pointer);
      var
        i  : LongInt;
        l  : TAsmLabel;
        pd : TProcDef;
        lists: PVMTAsmOutput absolute arg;
        datatcb  : TTAITypedConstBuilder;
        namedef : TDef;
      begin
        if (TSym(p).typ<>ProcSym) then
          exit;
        for i:=0 to TProcSym(p).ProcdefList.Count-1 do
          begin
            pd:=TProcDef(TProcSym(p).ProcdefList[i]);
            if (pd.ProcSym=TSym(p)) and
               (pd.visibility=vis_published) then
              begin
                { l: name_of_method }
                lists^.pubmethodstcb.start_internal_data_builder(CurrentAsmData.AsmLists[al_const],sec_rodata,_class.VMT_MangledName,datatcb,l);
                namedef:=datatcb.emit_shortstring_const(TSym(p).realname);
                lists^.pubmethodstcb.finish_internal_data_builder(datatcb,l,namedef,sizeof(PInt));
                { the tmethodnamerec }
                lists^.pubmethodstcb.maybe_begin_aggregate(lists^.methodnamerec);
                { convert the pointer to the name into a generic pshortstring,
                  so all entries can share the same recorddef }
                lists^.pubmethodstcb.queue_init(CharPointerType);
                lists^.pubmethodstcb.queue_emit_asmsym(l,namedef);
                if po_abstractmethod in pd.ProcOptions then
                  lists^.pubmethodstcb.emit_tai(TAIConst.Create_nil_codeptr,VoidCodePointerType)
                else
                  begin
                    { convert the procdef in a generic voidcodepointer, same
                      reason as above }
                    lists^.pubmethodstcb.queue_init(VoidCodePointerType);
                    lists^.pubmethodstcb.queue_emit_proc(pd);
                  end;
                lists^.pubmethodstcb.maybe_end_aggregate(lists^.methodnamerec);
              end;
           end;
      end;


    procedure TVMTWriter.genpublishedmethodstable(tcb: TTAITypedConstBuilder; out lab: TAsmLabel; out pubmethodsdef: TRecordDef);
      var
         count : LongInt;
         lists : TVMTAsmOutput;
         pubmethodsarraydef: TArrayDef;
         methodstabledef: TRecordDef;
         datatcb: TTAITypedConstBuilder;
         PackRecords: LongInt;
      begin
        // TODO(ryan): is extended method table packed?
        if (tf_requires_proper_alignment in TargetInfo.flags) then
          PackRecords:=0
        else
          PackRecords:=1;

         count:=0;
         _class.SymTable.SymList.ForEachCall(@do_count_published_methods,@count);
         if (count>0) or (_class.RTTI.options[ro_methods]<>[]) then
           begin
              { in the list of the published methods (from objpas.inc):
                  tmethodnamerec = packed record
                     name : pshortstring;
                     addr : codepointer;
                  end;
              }
              lists.methodnamerec:=Get_RecordDef(itp_vmt_intern_tmethodnamerec,[CPointerDef.getreusable(CShortStringType),VoidCodePointerType],1);
              { from objpas.inc:
                  tmethodnametable = packed record
                    count : dword;
                    entries : packed array[0..0] of tmethodnamerec;
                  end;
               }
              tcb.start_internal_data_builder(CurrentAsmData.AsmLists[al_const],sec_rodata,_class.VMT_MangledName,lists.pubmethodstcb,lab);
              Get_TableDef(itp_vmt_intern_tmethodnametable,U32IntType,lists.methodnamerec,count,PackRecords,pubmethodsdef,pubmethodsarraydef);
              { begin record encompassing the tmethodnametable and the extended method table }
              lists.pubmethodstcb.begin_anonymous_record('',PackRecords,
                  pubmethodsdef.Alignment, targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
              { begin tmethodnametable }
              lists.pubmethodstcb.maybe_begin_aggregate(pubmethodsdef);
              { emit count field }
              lists.pubmethodstcb.emit_tai(TAIConst.Create_32bit(count),U32IntType);
              if count>0 then
                begin
                  { begin entries field (array) }
                  lists.pubmethodstcb.maybe_begin_aggregate(pubmethodsarraydef);
                  { add all entries elements }
                  _class.SymTable.SymList.ForEachCall(@do_gen_published_methods,@lists);
                  { end entries field (array) }
                  lists.pubmethodstcb.maybe_end_aggregate(pubmethodsarraydef);
                end;
              { end methodnametable }
              lists.pubmethodstcb.maybe_end_aggregate(pubmethodsdef);
              { write extended method rtti }
              RTTIWriter.write_extended_method_table(lists.pubmethodstcb,_class);
              { end the encompassing record }
              methodstabledef:=lists.pubmethodstcb.end_anonymous_record;
              tcb.finish_internal_data_builder(lists.pubmethodstcb,lab,methodstabledef,sizeof(PInt));
           end
         else
           begin
             lab:=nil;
             pubmethodsdef:=nil;
           end;
      end;


    procedure TVMTWriter.generate_field_table(tcb: TTAITypedConstBuilder; out lab: TAsmLabel; out fieldtabledef: TRecordDef);
      var
        i   : LongInt;
        sym : TSym;
        classtable : TAsmLabel;
        classindex,
        fieldcount : LongInt;
        classtablelist : TFPList;
        datatcb: TTAITypedConstBuilder;
        PackRecords: LongInt;
        classdef: TObjectDef;
        classtabledef: TRecordDef;
      begin
        classtable:=nil;
        classtablelist:=TFPList.Create;
        classtabledef:=nil;
        { retrieve field info fields }
        fieldcount:=0;
        for i:=0 to _class.SymTable.SymList.Count-1 do
          begin
            sym:=TSym(_class.SymTable.SymList[i]);
            if (sym.typ=FieldVarSym) and
               not(sp_static in sym.SymOptions) and
               (sym.visibility=vis_published) then
             begin
                if TFieldVarSym(sym).vardef.typ<>objectdef then
                  InternalError(200611032);
                classindex:=classtablelist.IndexOf(TFieldVarSym(sym).vardef);
                if classindex=-1 then
                  classtablelist.Add(TFieldVarSym(sym).vardef);
                inc(fieldcount);
             end;
          end;

        if (fieldcount>0) or (_class.RTTI.options[ro_fields]<>[]) then
          begin
            if (tf_requires_proper_alignment in TargetInfo.flags) then
              PackRecords:=0
            else
              PackRecords:=1;

            { generate the class table }
            if classtablelist.count>0 then
              begin
                tcb.start_internal_data_builder(CurrentAsmData.AsmLists[al_const],sec_rodata,_class.VMT_MangledName,datatcb,classtable);
                datatcb.begin_anonymous_record('$fpc_intern_classtable_'+ToStr(classtablelist.Count-1),
                  PackRecords,1,
                  targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
                datatcb.emit_tai(TAIConst.Create_16bit(classtablelist.count),U16IntType);
                for i:=0 to classtablelist.Count-1 do
                  begin
                    classdef:=TObjectDef(classtablelist[i]);
                    { type of the field }
                    datatcb.queue_init(VoidPointerType);
                    { reference to the vmt }
                    datatcb.queue_emit_asmsym(
                      CurrentAsmData.RefAsmSymbol(classdef.VMT_MangledName,AT_DATA,true),
                      TFieldVarSym(classdef.VMTField).vardef);
                  end;
                classtabledef:=datatcb.end_anonymous_record;
                tcb.finish_internal_data_builder(datatcb,classtable,classtabledef,sizeof(PInt));
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
            tcb.start_internal_data_builder(CurrentAsmData.AsmLists[al_const],sec_rodata,_class.VMT_MangledName,datatcb,lab);
            { can't easily specify a name here for reuse of the constructed def,
              since it's full of variable length shortstrings (-> all of those
              lengths and their order would have to incorporated in the name,
              plus there would be very little chance that it could actually be
              reused }
            datatcb.begin_anonymous_record('',PackRecords,1,
              targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
            datatcb.emit_tai(TAIConst.Create_16bit(fieldcount),U16IntType);
            if classtable<>nil then
              datatcb.emit_tai(TAIConst.Create_sym(classtable),CPointerDef.getreusable(classtabledef))
            else
              datatcb.emit_tai(TAIConst.Create_nil_codeptr,VoidPointerType);
            if fieldcount>0 then
              begin
                for i:=0 to _class.SymTable.SymList.Count-1 do
                  begin
                    sym:=TSym(_class.SymTable.SymList[i]);
                    if (sym.typ=FieldVarSym) and
                       not(sp_static in sym.SymOptions) and
                      (sym.visibility=vis_published) then
                      begin
                        { skip non-object defs for legacy rtti }
                        if TFieldVarSym(sym).vardef.typ<>objectdef then
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
                        datatcb.begin_anonymous_record('$fpc_intern_fieldinfo_'+ToStr(length(TFieldVarSym(sym).realname)),PackRecords,1,
                          targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
                        datatcb.emit_tai(TAIConst.Create_sizeint(TFieldVarSym(sym).FieldOffset),SizeUIntType);
                        classindex:=classtablelist.IndexOf(TFieldVarSym(sym).vardef);
                        if classindex=-1 then
                          InternalError(200611033);
                        datatcb.emit_tai(TAIConst.Create_16bit(classindex+1),U16IntType);
                        datatcb.emit_shortstring_const(TFieldVarSym(sym).realname);
                        datatcb.end_anonymous_record;
                      end;
                  end;
              end;
            { append the extended rtti table }
            RTTIWriter.write_extended_field_table(datatcb,_class);
            fieldtabledef:=datatcb.end_anonymous_record;
            tcb.finish_internal_data_builder(datatcb,lab,fieldtabledef,sizeof(PInt));
          end
        else
          begin
            fieldtabledef:=nil;
            lab:=nil;
          end;

        classtablelist.free;
        classtablelist := nil;
      end;


{**************************************
           Interface tables
**************************************}

    function CreateWrapperName(_class : TObjectDef;AImplIntf : TImplementedInterface;i : LongInt;pd : TProcDef) : TSymStr;
      var
        realintfdef: TObjectDef;
        tmpstr : AnsiString;
        hs : TSymStr;
        hash : QWord;
      begin
        realintfdef:=AImplIntf.IntfDef;
        while realintfdef.Is_Unique_ObjPasDef do
          realintfdef:=realintfdef.ChildOf;

        tmpstr:=_class.ObjName^+'_$_'+Make_MangledName('',realintfdef.owner,'')+'_$$_'+realintfdef.ObjName^+'_$_'+ToStr(i)+'_$_'+pd.MangledName;
        if length(tmpstr)>50 then
          begin
            hash:=InitFNV64;
            hash:=UpdateFNV64(hash,tmpstr[51],length(tmpstr)-50);
            hs:=copy(tmpstr,1,50)+'$H'+Base64Mangle(hash);
          end
        else
          hs:=tmpstr;
        result:=Make_MangledName('WRPR',_class.owner,hs);
      end;


    procedure TVMTWriter.intf_create_vtbl(tcb: TTAITypedConstBuilder; AImplIntf: TImplementedInterface; intfindex: LongInt);
      var
        datatcb : TTAITypedConstBuilder;
        pd : TProcDef;
        hs : TSymStr;
        i  : LongInt;
      begin
        tcb.start_internal_data_builder(CurrentAsmData.AsmLists[al_const],sec_rodata,'',datatcb,fintfvtablelabels[intfindex]);
        datatcb.begin_anonymous_record('',0,1,
          targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
        if Assigned(AImplIntf.procdefs) then
          begin
            for i:=0 to AImplIntf.procdefs.count-1 do
              begin
                pd:=TProcDef(AImplIntf.procdefs[i]);
                hs:=CreateWrapperName(_Class,AImplIntf,i,pd);
                { create reference }
                datatcb.emit_tai(TAIConst.Createname(hs,AT_FUNCTION,0),CProcVarDef.GetReusableProcAddr(pd,pc_address_only));
              end;
           end
        else
          { can't have an empty symbol on LLVM }
          datatcb.emit_tai(TAIConst.Create_nil_codeptr,VoidPointerType);
        tcb.finish_internal_data_builder(datatcb,fintfvtablelabels[intfindex],
          datatcb.end_anonymous_record,sizeof(PInt));
      end;


    procedure TVMTWriter.intf_gen_intf_ref(tcb: TTAITypedConstBuilder; AImplIntf: TImplementedInterface; intfindex: LongInt; interfaceentrydef, interfaceentrytypedef: TDef);
      var
        pd: TProcDef;
        siid,
        siidstr: TSymStr;
        nonuniqueintf: TObjectDef;
      begin
        nonuniqueintf:=AImplIntf.IntfDef;
        while nonuniqueintf.Is_Unique_ObjPasDef do
          nonuniqueintf:=nonuniqueintf.ChildOf;
        tcb.maybe_begin_aggregate(interfaceentrydef);
        { GUID (or nil for Corba interfaces) }
        tcb.next_field:=TAbstractRecordDef(interfaceentrydef).SymTable.Find('IIDREF') as TFieldVarSym;
        siid:='';
        if nonuniqueintf.ObjectType in [odt_interfacecom] then
          begin
            siid:=Make_MangledName('IID',nonuniqueintf.owner,nonuniqueintf.ObjName^);
            tcb.emit_tai(TAIConst.Create_sym_offset(
              CurrentAsmData.RefAsmSymbol(siid,AT_DATA,true),0),CPointerDef.getreusable(Rec_TGUID));
          end
        else
          tcb.emit_tai(TAIConst.Create_nil_dataptr,CPointerDef.getreusable(Rec_TGUID));

        { VTable }
        tcb.next_field:=TAbstractRecordDef(interfaceentrydef).SymTable.Find('VTABLE') as TFieldVarSym;
        tcb.queue_init(VoidPointerType);
        tcb.queue_emit_asmsym(fintfvtablelabels[intfindex],nonuniqueintf);
        { IOffset field }
        case AImplIntf.VtblImplIntf.IType of
          etFieldValue, etFieldValueClass,
          etStandard:
            begin
              tcb.next_field:=TAbstractRecordDef(interfaceentrydef).SymTable.Find('IOFFSET') as TFieldVarSym;
              tcb.emit_tai(TAIConst.Create_sizeint(AImplIntf.VtblImplIntf.IOffset),SizeUIntType);
            end;
          etStaticMethodResult, etStaticMethodClass:
            begin
              tcb.next_field:=TAbstractRecordDef(interfaceentrydef).SymTable.Find('IOFFSETASCODEPTR') as TFieldVarSym;
              pd:=TProcDef(TPropertySym(AImplIntf.ImplementsGetter).PropAccessList[palt_read].procdef);
              tcb.queue_init(CodePtrUIntType);
              tcb.queue_emit_proc(pd);
            end;
          etVirtualMethodResult, etVirtualMethodClass:
            begin
              tcb.next_field:=TAbstractRecordDef(interfaceentrydef).SymTable.Find('IOFFSET') as TFieldVarSym;
              pd:=TProcDef(TPropertySym(AImplIntf.ImplementsGetter).PropAccessList[palt_read].procdef);
              tcb.emit_tai(TAIConst.Create_sizeint(TObjectDef(pd.struct).VMTMethodOffset(pd.ExtNumber)),SizeUIntType);
            end;
        end;

        { IIDStr }
        tcb.next_field:=TAbstractRecordDef(interfaceentrydef).SymTable.Find('IIDSTRREF') as TFieldVarSym;
        siidstr:=Make_MangledName('IIDSTR',nonuniqueintf.owner,nonuniqueintf.ObjName^);
        tcb.queue_init(CPointerDef.getreusable(CShortStringType));
        tcb.queue_emit_asmsym(
          CurrentAsmData.RefAsmSymbol(
            siidstr,
            AT_DATA,
            true),
          CPointerDef.getreusable(CArrayDef.getreusable(CAnsiCharType,length(nonuniqueintf.IIDStr^)+1)));
        { IType }
        tcb.next_field:=TAbstractRecordDef(interfaceentrydef).SymTable.Find('ITYPE') as TFieldVarSym;
        tcb.emit_ord_const(aint(AImplIntf.VtblImplIntf.IType),interfaceentrytypedef);
        tcb.maybe_end_aggregate(interfaceentrydef);

        if FindUnitSymTable(nonuniqueintf.owner).ModuleID<>FindUnitSymTable(_Class.owner).ModuleID then
          begin
            if siid<>'' then
              CurrentModule.Add_Extern_AsmSym(siid,AB_EXTERNAL,AT_DATA);
            CurrentModule.Add_Extern_AsmSym(siidstr,AB_EXTERNAL,AT_DATA);
          end;
      end;


    procedure TVMTWriter.intf_write_table(tcb: TTAITypedConstBuilder; out lab: TAsmLabel; out intftabledef: TRecordDef);
      var
        i        : LongInt;
        ImplIntf : TImplementedInterface;
        datatcb      : TTAITypedConstBuilder;
        interfaceentrydef : TDef;
        interfaceentrytypedef: TDef;
        interfacearray: TDef;
      begin
        SetLength(fintfvtablelabels,_class.ImplementedInterfaces.count);

        { Write unique vtbls }
        for i:=0 to _class.ImplementedInterfaces.count-1 do
          begin
            ImplIntf:=TImplementedInterface(_class.ImplementedInterfaces[i]);
            if ImplIntf.VtblImplIntf=ImplIntf then
              intf_create_vtbl(tcb,ImplIntf,i)
          end;
        { Set labels for aliased vtbls (after all unique vtbls have been
          written, so all labels have been defined already) }
        for i:=0 to _class.ImplementedInterfaces.count-1 do
          begin
            ImplIntf:=TImplementedInterface(_class.ImplementedInterfaces[i]);
            if ImplIntf.VtblImplIntf<>ImplIntf then
              fintfvtablelabels[i]:=fintfvtablelabels[_class.ImplementedInterfaces.IndexOf(ImplIntf.VtblImplIntf)];
          end;

        tcb.start_internal_data_builder(CurrentAsmData.AsmLists[al_const],sec_rodata,_class.VMT_MangledName,datatcb,lab);
        datatcb.begin_anonymous_record('',Default_Settings.PackRecords,1,
          targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
        datatcb.emit_tai(TAIConst.Create_sizeint(_class.ImplementedInterfaces.count),SizeUIntType);
        interfaceentrydef:=Search_System_Type('TINTERFACEENTRY').typedef;
        interfaceentrytypedef:=Search_System_Type('TINTERFACEENTRYTYPE').typedef;
        if _class.ImplementedInterfaces.count>0 then
          begin
            interfacearray:=CArrayDef.getreusable(interfaceentrydef,_class.ImplementedInterfaces.count);
            datatcb.maybe_begin_aggregate(interfacearray);
            { Write vtbl references }
            for i:=0 to _class.ImplementedInterfaces.count-1 do
              begin
                ImplIntf:=TImplementedInterface(_class.ImplementedInterfaces[i]);
                intf_gen_intf_ref(datatcb,ImplIntf,i,interfaceentrydef,interfaceentrytypedef);
              end;
            datatcb.maybe_end_aggregate(interfacearray);
          end;
        intftabledef:=datatcb.end_anonymous_record;
        tcb.finish_internal_data_builder(datatcb,lab,intftabledef,intftabledef.Alignment);

      end;


  { Write interface identifiers to the data section }
  procedure TVMTWriter.writeinterfaceids(list: TAsmList);
    var
      s : string;
      tcb : TTAITypedConstBuilder;
      def : TDef;
      sym : TAsmSymbol;
    begin
      if Assigned(_class.IIDGUID) then
        begin
          s:=Make_MangledName('IID',_class.owner,_class.ObjName^);
          tcb:=CTAITypedConstBuilder.create([tcalo_make_dead_strippable,tcalo_data_force_indirect]);
          tcb.emit_guid_const(_class.IIDGUID^);
          sym:=CurrentAsmData.DefineAsmSymbol(s,AB_GLOBAL,AT_DATA_NOINDIRECT,Rec_TGUID);
          list.ConcatList(tcb.get_final_asmlist(
            sym,
            Rec_TGUID,
            sec_rodata,
            s,
            sizeof(PInt)));
          tcb.free;
          tcb := nil;
          CurrentModule.Add_Public_AsmSym(sym);
        end;
      s:=Make_MangledName('IIDSTR',_class.owner,_class.ObjName^);
      tcb:=CTAITypedConstBuilder.create([tcalo_make_dead_strippable,tcalo_data_force_indirect]);
      def:=tcb.emit_shortstring_const(_class.IIDStr^);
      sym:=CurrentAsmData.DefineAsmSymbol(s,AB_GLOBAL,AT_DATA_NOINDIRECT,def);
      list.ConcatList(tcb.get_final_asmlist(
        sym,
        def,
        sec_rodata,
        s,
        sizeof(PInt)));
      tcb.free;
      tcb := nil;
      CurrentModule.Add_Public_AsmSym(sym);
    end;


  class function TVMTWriter.use_vmt_writer: boolean;
    begin
      result:=true;
    end;


    function TVMTWriter.RedirectToEmpty(procdef : TProcDef) : boolean;
      var
        i : LongInt;
        hp : PCGParaLocation;
      begin
        result:=false;
        if procdef.isempty then
          begin
{$ifdef x86}
            ParaManager.Create_FuncRetLoc_Info(procdef,calleeside);
            if (procdef.FuncRetLoc[calleeside].Location^.Loc=LOC_FPUREGISTER) then
              exit;
{$endif x86}
            procdef.Init_ParaLoc_Info(callerside);
            { we can redirect the call if no memory parameter is passed }
            for i:=0 to procdef.paras.count-1 do
              begin
                hp:=TParaVarSym(procdef.paras[i]).ParaLoc[callerside].Location;
                while Assigned(hp) do
                  begin
                    if not(hp^.Loc in [LOC_REGISTER,LOC_MMREGISTER,LOC_FPUREGISTER]) then
                      exit;
                    hp:=hp^.Next;
                  end;
              end;
            result:=true;
          end;
      end;


    procedure TVMTWriter.generate_abstract_stub(list:TAsmList;pd:TProcDef);
      begin
        { Generate stubs for abstract methods, so their symbols are present and
          can be used e.g. to take address (see issue #24536). }
        if (po_global in pd.ProcOptions) and
           (pd.owner.DefOwner<>self._class) then
          exit;
        pd.SyntheticKind:=tsk_call_no_parameters;
        pd.SKPara:=Search_System_Proc('ABSTRACTERROR');
        { abstract methods are not marked as forwarddef, because otherwise
          the compiler would accept implementations for them (and complain if
          they were missing); we are now after parsing the user code, so we can
          mark them again as forwarddef to indicate they need to be parsed }
        pd.ForwardDef:=true;
      end;


    procedure TVMTWriter.writevirtualmethods(tcb: TTAITypedConstBuilder);
      var
         vmtpd : TProcDef;
         vmtentry : PVMTEntry;
         i  : LongInt;
         procname : TSymStr;
{$ifdef vtentry}
         hs : string;
{$endif vtentry}
      begin
        for i:=0 to _class.VMTEntries.Count-1 do
         begin
           vmtentry:=PVMTEntry(_class.VMTEntries[i]);
           vmtpd:=vmtentry^.procdef;
           { safety checks }
           if not(po_virtualmethod in vmtpd.ProcOptions) then
             InternalError(200611082);
           if vmtpd.ExtNumber<>i then
             InternalError(200611083);
           if (po_abstractmethod in vmtpd.ProcOptions) then
             begin
               procname:='FPC_ABSTRACTERROR';
               generate_abstract_stub(CurrentAsmData.AsmLists[al_procedures],vmtpd);
             end
           else if (cs_opt_remove_empty_proc in CurrentSettings.OptimizerSwitches) and RedirectToEmpty(vmtpd) then
             begin
               procname:='FPC_EMPTYMETHOD';
               if CurrentModule.GlobalSymTable<>SystemUnit then
                 CurrentModule.Add_Extern_AsmSym(procname,AB_EXTERNAL,AT_FUNCTION);
             end
           else if not wpoinfomanager.optimized_name_for_vmt(_class,vmtpd,procname) then
             begin
               procname:=vmtpd.MangledName;
               if CurrentModule.ModuleID<>vmtpd.owner.ModuleID then
                 CurrentModule.AddImportedSym(vmtpd.ProcSym);
             end;
           tcb.emit_tai(TAIConst.Createname(procname,AT_FUNCTION,0),CProcVarDef.GetReusableProcAddr(vmtpd,pc_address_only));
{$ifdef vtentry}
           hs:='VTENTRY'+'_'+_class.VMT_MangledName+'$$'+ToStr(_class.VMTMethodOffset(i) div sizeof(PInt));
           CurrentAsmData.asmlists[al_globals].concat(TAISymbol.CreateName(hs,AT_DATA,0,voidpointerdef));
{$endif vtentry}
         end;
      end;


    procedure TVMTWriter.writevmt;
      var
         methodnametable,intmessagetable,
         strmessagetable,classnamelabel,
         fieldtablelabel : TAsmLabel;
{$ifdef vtentry}
         hs: string;
{$endif vtentry}
{$ifdef WITHDMT}
         dmtlabel : TAsmLabel;
{$endif WITHDMT}
         interfacetable : TAsmLabel;
         tcb, datatcb: TTAITypedConstBuilder;
         classnamedef: TDef;
         methodnametabledef,
         fieldtabledef,
         interfacetabledef,
         strmessagetabledef,
         intmessagetabledef: TRecordDef;
         parentvmtdef: TDef;
         pinterfacetabledef,
         pstringmessagetabledef: TDef;
         vmttypesym: TTypeSym;
         vmtdef: TDef;
         sym : TAsmSymbol;
      begin
{$ifdef WITHDMT}
         dmtlabel:=gendmt;
{$endif WITHDMT}
         { this code gets executed after the current module's symtable has
           already been removed from the symtablestack -> add it again, so that
           newly created defs here end up in the right unit }
         SymTableStack.push(CurrentModule.LocalSymTable);
         strmessagetable:=nil;
         interfacetable:=nil;
         fieldtablelabel:=nil;
         methodnametable:=nil;
         intmessagetable:=nil;
         classnamelabel:=nil;

         classnamedef:=nil;
         methodnametabledef:=nil;
         fieldtabledef:=nil;
         interfacetabledef:=nil;
         strmessagetabledef:=nil;
         intmessagetabledef:=nil;

         { generate VMT }
         tcb:=CTAITypedConstBuilder.create([tcalo_make_dead_strippable,tcalo_data_force_indirect]);

         { write tables for classes, this must be done before the actual
           class is written, because we need the labels defined }
         if Is_Class(_class) then
          begin
            { write class name }
            tcb.start_internal_data_builder(CurrentAsmData.asmlists[al_const],sec_rodata,_class.VMT_MangledName,datatcb,classnamelabel);
            classnamedef:=datatcb.emit_shortstring_const(_class.RTTIName);
            tcb.finish_internal_data_builder(datatcb,classnamelabel,classnamedef,sizeof(PInt));

            { interface table }
            if _class.Implements_Any_Interfaces then
              intf_write_table(tcb,interfacetable,interfacetabledef);

            genpublishedmethodstable(tcb,methodnametable,methodnametabledef);
            generate_field_table(tcb,fieldtablelabel,fieldtabledef);

            { generate message and dynamic tables }
            if (oo_has_msgstr in _class.ObjectOptions) then
              genstrmsgtab(tcb,strmessagetable,strmessagetabledef);
            if (oo_has_msgint in _class.ObjectOptions) then
              genintmsgtab(tcb,intmessagetable,intmessagetabledef);
          end;

         { reuse the type created in nobj, so we get internal consistency
           checking for free }
         vmttypesym:=TTypeSym(_class.SymTable.find('vmtdef'));
         if not Assigned(vmttypesym) or
            (vmttypesym.typ<>TypeSym) or
            (vmttypesym.typedef.typ<>recorddef) then
           InternalError(2015071403);
         vmtdef:=TRecordDef(vmttypesym.typedef);

         tcb.maybe_begin_aggregate(vmtdef);

         { determine the size with symtable.datasize, because }
         { size gives back 4 for classes                    }
         tcb.emit_ord_const(TObjectSymTable(_class.SymTable).DataSize,SizeSIntType);
         tcb.emit_ord_const(-int64(TObjectSymTable(_class.SymTable).DataSize),SizeSIntType);
{$ifdef WITHDMT}
         if _class.classtype=ct_object then
           begin
              if Assigned(dmtlabel) then
                tcb.emit_tai(dmtlabel,VoidPointerType)
              else
                tcb.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
           end;
{$endif WITHDMT}
         { write pointer to parent VMT, this isn't implemented in TP }
         { but this is not used in FPC ? (PM) }
         { it's not used yet, but the delphi-operators as and is need it (FK) }
         { it is not written for parents that don't have any vmt !! }
         if Is_Class(_class) then
           parentvmtdef:=CPointerDef.getreusable(Search_System_Type('TVMT').typedef)
         else
           parentvmtdef:=VoidPointerType;
         if Assigned(_class.ChildOf) and
            (oo_has_vmt in _class.ChildOf.ObjectOptions) then
           begin
             tcb.queue_init(parentvmtdef);
             sym:=CurrentAsmData.RefAsmSymbol(_class.ChildOf.VMT_MangledName,AT_DATA,true);
             tcb.queue_emit_asmsym(
               sym,
               TFieldVarSym(_class.ChildOf.VMTField).vardef);
             if _class.ChildOf.owner.ModuleID<>CurrentModule.ModuleID then
               CurrentModule.Add_Extern_AsmSym(sym);
           end
         else
           tcb.emit_tai(TAIConst.Create_nil_dataptr,parentvmtdef);

         { write extended info for classes, for the order see rtl/inc/objpash.inc }
         if Is_Class(_class) then
          begin
            { pointer to class name string }
            tcb.queue_init(CPointerDef.getreusable(CShortStringType));
            tcb.queue_emit_asmsym(classnamelabel,classnamedef);
            { pointer to dynamic table or nil }
            if (oo_has_msgint in _class.ObjectOptions) then
              begin
                tcb.queue_init(VoidPointerType);
                tcb.queue_emit_asmsym(intmessagetable,CPointerDef.getreusable(intmessagetabledef));
              end
            else
              tcb.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
            { pointer to method table or nil }
            if Assigned(methodnametable) then
              begin
                tcb.queue_init(VoidPointerType);
                tcb.queue_emit_asmsym(methodnametable,CPointerDef.getreusable(methodnametabledef))
              end
            else
              tcb.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
            { pointer to field table }
            if Assigned(fieldtablelabel) then
              begin
                tcb.queue_init(VoidPointerType);
                tcb.queue_emit_asmsym(fieldtablelabel,fieldtabledef)
              end
            else
              tcb.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
            { pointer to type info of published section }
            tcb.emit_tai(TAIConst.Create_sym(RTTIWriter.get_rtti_label(_class,fullrtti,false)),VoidPointerType);
            { inittable for con-/destruction }
            if _class.Members_Need_InitTable then
              tcb.emit_tai(TAIConst.Create_sym(RTTIWriter.get_rtti_label(_class,initrtti,false)),VoidPointerType)
            else
              tcb.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
            { auto table }
            tcb.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
            { interface table }
            pinterfacetabledef:=Search_System_Type('PINTERFACETABLE').typedef;
            if _class.Implements_Any_Interfaces then
              begin
                tcb.queue_init(pinterfacetabledef);
                tcb.queue_emit_asmsym(interfacetable,interfacetabledef)
              end
            else
              tcb.emit_tai(TAIConst.Create_nil_dataptr,pinterfacetabledef);
            { table for string messages }
            pstringmessagetabledef:=Search_System_Type('PSTRINGMESSAGETABLE').typedef;
            if (oo_has_msgstr in _class.ObjectOptions) then
              begin
                tcb.queue_init(VoidPointerType);
                tcb.queue_emit_asmsym(strmessagetable,pstringmessagetabledef);
              end
            else
              tcb.emit_tai(TAIConst.Create_nil_dataptr,pstringmessagetabledef);
          end;
         { write virtual methods }
         writevirtualmethods(tcb);
         tcb.emit_tai(TAIConst.Create_nil_codeptr,VoidCodePointerType);

         tcb.maybe_end_aggregate(vmtdef);

         sym:=CurrentAsmData.DefineAsmSymbol(_class.VMT_MangledName,AB_GLOBAL,AT_DATA_NOINDIRECT,vmtdef);
         CurrentModule.Add_Public_AsmSym(sym);

         { concatenate the VMT to the asmlist }
         CurrentAsmData.asmlists[al_globals].ConcatList(
           tcb.get_final_asmlist(
             sym,
             vmtdef,sec_rodata,_class.VMT_MangledName,sizeof(PInt)
           )
         );
         tcb.free;
         tcb := nil;
{$ifdef vtentry}
         { write vtinherit symbol to notify the linker of the class inheritance tree }
         hs:='VTINHERIT'+'_'+_class.VMT_MangledName+'$$';
         if Assigned(_class.ChildOf) then
           hs:=hs+_class.ChildOf.VMT_MangledName
         else
           hs:=hs+_class.VMT_MangledName;
         CurrentAsmData.asmlists[al_globals].concat(TAISymbol.CreateName(hs,AT_DATA,0,voidpointerdef));
{$endif vtentry}
        SymTableStack.pop(CurrentModule.LocalSymTable);
      end;


    procedure gen_intf_wrapper(list:TAsmList;_class:TObjectDef);
      var
        i,j  : LongInt;
        tmps : string;
        pd   : TProcDef;
        ImplIntf : TImplementedInterface;
        wrapperpd: TProcDef;
        wrapperinfo: PSKParaInterfaceWrapper;
        tmplist: TAsmList;
        oldfileposinfo: TFilePosInfo;
        usehighlevelwrapper: Boolean;
      begin
{$if defined(cpuhighleveltarget)}
        usehighlevelwrapper:=true;
{$else defined(cpuhighleveltarget)}
        { on PPC systems that use a TOC the linker needs to be able to insert
          an instruction to restore the TOC register after every branch
          between code fragments that use a different TOC (which has to be
          executed when that "branch" returns). So we can't use tail call
          branches to routines potentially using a different TOC there }
        if TargetInfo.abi in abis_ppc_toc then
          usehighlevelwrapper:=true
        else
          usehighlevelwrapper:=false;
{$endif defined(cpuhighleveltarget)}
        for i:=0 to _class.ImplementedInterfaces.count-1 do
          begin
            ImplIntf:=TImplementedInterface(_class.ImplementedInterfaces[i]);
            if (ImplIntf=ImplIntf.VtblImplIntf) and
               Assigned(ImplIntf.ProcDefs) then
              begin
                for j:=0 to ImplIntf.ProcDefs.Count-1 do
                  begin
                    pd:=TProcDef(ImplIntf.ProcDefs[j]);
                    { we don't track method calls via interfaces yet ->
                      assume that every method called via an interface call
                      is reachable for now }
                    if (po_virtualmethod in pd.ProcOptions) and
                       not Is_ObjectPascal_Helper(TProcDef(pd).struct) then
                      TObjectDef(TProcDef(pd).struct).Register_VMT_Call(TProcDef(pd).ExtNumber);
                    tmps:=CreateWrapperName(_Class,ImplIntf,j,pd);

                  if usehighlevelwrapper then
                    begin
                      new(wrapperinfo);
                      wrapperinfo^.PD:=pd;
                      wrapperinfo^.Offset:=ImplIntf.ioffset;
                      { insert the wrapper procdef in the current unit's local
                        symbol table, but set the owning "struct" to the current
                        class (so self will have the correct type) }
                      wrapperpd:=Create_ProcDef_Alias(pd,tmps,tmps,
                        CurrentModule.LocalSymTable,_class,
                        tsk_interface_wrapper,wrapperinfo);
                      include(wrapperpd.ImplProcOptions,pio_thunk);
                    end
                  else
                    begin
                      oldfileposinfo:=CurrentFilePos;
                      if pd.owner.IsCurrentUnit then
                        CurrentFilePos:=pd.fileinfo
                      else
                        begin
                          CurrentFilePos.moduleindex:=CurrentModule.ModuleID;
                          CurrentFilePos.fileindex:=1;
                          CurrentFilePos.line:=1;
                          CurrentFilePos.column:=1;
                        end;
                      { create wrapper code }
                      tmplist:=TAsmList.create;
                      new_section(tmplist,sec_code,tmps,TargetInfo.Alignment.ProcAlign);
                      tmplist.Concat(TAIFunctionName.create(tmps));
                      hlcg.Init_Register_Allocators;
                      hlcg.G_Intf_Wrapper(tmplist,pd,tmps,ImplIntf.ioffset);
                      hlcg.Done_Register_Allocators;
                      if ((cs_debuginfo in CurrentSettings.ModuleSwitches) or
                         (cs_use_lineinfo in CurrentSettings.GlobalSwitches)) then
                        CurrentDebugInfo.insertlineinfo(tmplist);
                      list.ConcatList(tmplist);
                      tmplist.Free;
                      tmplist := nil;
                      CurrentFilePos:=oldfileposinfo;
                    end;
                  end;
              end;
          end;
      end;


    procedure do_write_vmts(st:TSymTable;is_global:boolean);
      var
        i : LongInt;
        def : TDef;
        vmtwriter  : TVMTWriter;
      begin
        if not CVMTWriter.use_vmt_writer then
          exit;
        for i:=0 to st.DefList.Count-1 do
          begin
            def:=TDef(st.DefList[i]);
            case def.typ of
              recorddef :
                do_write_vmts(TRecordDef(def).SymTable,is_global);
              objectdef :
                begin
                  { Skip generics and forward defs }
                  if ([df_generic,df_genconstraint]*def.DefOptions<>[]) or
                     (oo_is_forward in TObjectDef(def).ObjectOptions) then
                    continue;
                  if TObjectDef(def).Is_Unique_ObjPasDef then
                    continue;
                  do_write_vmts(TObjectDef(def).SymTable,is_global);
                  { Write also VMT if not done yet }
                  if not(ds_vmt_written in def.DefStates) then
                    begin
                      vmtwriter:=CVMTWriter.create(TObjectDef(def));
                      if Is_Interface(TObjectDef(def)) then
                        vmtwriter.writeinterfaceids(CurrentAsmData.AsmLists[al_globals]);
                      if (oo_has_vmt in TObjectDef(def).ObjectOptions) then
                        vmtwriter.writevmt;
                      vmtwriter.free;
                      vmtwriter := nil;
                      include(def.DefStates,ds_vmt_written);
                    end;
                  if Is_Class(def) then
                    gen_intf_wrapper(CurrentAsmData.asmlists[al_procedures],TObjectDef(def));
                end;
              procdef :
                begin
                  if Assigned(TProcDef(def).LocalST) and
                     (TProcDef(def).LocalST.SymTableType=LocalSymTable) then
                    do_write_vmts(TProcDef(def).LocalST,false);
                  if Assigned(TProcDef(def).ParaST) then
                    do_write_vmts(TProcDef(def).ParaST,false);
                end;
              else
                ;
            end;
          end;
      end;

    procedure write_vmts(st:TSymTable;is_global:boolean);
      begin
{$ifndef cpuhighleveltarget}
        Create_HLCodeGen(THLCGObjHelpers);
{$endif}
        do_write_vmts(st,is_global);
{$ifndef cpuhighleveltarget}
        Destroy_HLCodeGen;
{$endif}
      end;

end.
