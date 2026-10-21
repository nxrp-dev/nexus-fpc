{
    Copyright (c) 1998-2008 by Peter Vreman

    This unit implements support import,export,link routines
    for the (i386) Win32 target

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
unit t_win;

{$i fpcdefs.inc}

interface

    uses
       CUtils,CClasses,
       aasmbase,aasmtai,AAsmData,aasmcpu,FModule,GlobType,Globals,Systems,Verbose,
       symconst,symdef,SymSym,
       CScript,gendef,
       cpubase,
       import,export,link,CompRsrc,i_win;


    const
       MAX_DEFAULT_EXTENSIONS = 3;

    type
       TStr4=array[1..MAX_DEFAULT_EXTENSIONS] of string[4];
       PStr4=^TStr4;

      TImportLibWin=class(TImportLib)
      private
        procedure generateimportlib;
        procedure generateidatasection;
      public
        procedure generatelib;override;
      end;

      TExportLibWin=class(TExportLib)
      private
        st : string;
        EList_indexed:TFPList;
        EList_nonindexed:TFPList;
      public
        destructor Destroy;override;
        procedure preparelib(const s:string);override;
        procedure exportprocedure(hp : TExportedItem);override;
        procedure exportvar(hp : TExportedItem);override;
        procedure exportfromlist(hp : TExportedItem);
        procedure generatelib;override;
      end;


{$if defined(i386) or defined(x86_64) or defined(aarch64)}
      TExternalLinkerWin64LLD=class(TExternalLinker)
      private
         function WriteLLDResponseFile(const OutputFile:string;IsDLL:boolean):boolean;
         function DoLLDLink(const OutputFile:string;IsDLL:boolean):boolean;
      public
         constructor Create;override;
         function MakeExecutable:boolean;override;
         function MakeSharedLibrary:boolean;override;
         procedure InitSysInitUnitName;override;
      end;
{$endif i386 or x86_64 or aarch64}

      TDLLScannerWin=class(TDLLScanner)
      private
        importfound : boolean;
        procedure CheckDLLFunc(const dllname,funcname:string);
      public
        function Scan(const binname:string):boolean;override;
      end;

implementation

  uses
    SysUtils,
    CFileUtl,
    cgutils,DbgBase,
    owar,ogbase
    ,ogcoff;


  Procedure GlobalInitSysInitUnitName(Linker : TLinker);
    var
      hp           : TModule;
      linkcygwin : boolean;
    begin
      if TargetInfo.system=system_i386_win32 then
        begin
          linkcygwin := false;
          hp:=TModule(Loaded_Units.first);
          while Assigned(hp) do
           begin
             linkcygwin := hp.LinkOtherSharedLibs.find('cygwin') or hp.LinkOtherStaticLibs.find('cygwin');
             if linkcygwin then
               break;
             hp:=TModule(hp.next);
           end;
          if linkcygwin or (Linker.SharedLibFiles.Find('cygwin')<>nil) or (Linker.StaticLibFiles.Find('cygwin')<>nil) then
            linker.sysinitunit:='sysinitcyg'
          else
            linker.sysinitunit:='sysinitpas';
        end
      else if TargetInfo.system in [system_x86_64_win64,system_aarch64_win64] then
        linker.sysinitunit:='sysinit';
    end;


{*****************************************************************************
                             TImportLibWin
*****************************************************************************}

    procedure TImportLibWin.generateimportlib;
      var
        ObjWriter        : TArObjectWriter;
        ObjOutput        : TPECoffObjOutput;
        basedllname      : string;
        AsmPrefix        : string;
        idatalabnr,
        SmartFilesCount,
        SmartHeaderCount : LongInt;

        function CreateObjData(place:TCutPlace):TObjData;
        var
          s : string;
        begin
          s:='';
          case place of
            cut_begin :
              begin
                inc(SmartHeaderCount);
                s:=AsmPrefix+ToStr(SmartHeaderCount)+'h';
              end;
            cut_normal :
              s:=AsmPrefix+ToStr(SmartHeaderCount)+'s';
            cut_end :
              s:=AsmPrefix+ToStr(SmartHeaderCount)+'t';
          end;
          inc(SmartFilesCount);
          result:=ObjOutput.NewObjData(FixFileName(s+ToStr(SmartFilesCount)+TargetInfo.objext));
          ObjOutput.startobjectfile(Result.Name);
        end;

        procedure WriteObjData(objdata:TObjData);
        begin
          ObjOutput.writeobjectfile(ObjData);
        end;

        procedure StartImport(const dllname:string);
        var
          headlabel,
          idata4label,
          idata5label,
          idata7label : TObjSymbol;
          emptyint    : LongInt;
          objdata     : TObjData;
          idata2objsection,
          idata4objsection,
          idata5objsection : TObjSection;
        begin
          objdata:=CreateObjData(cut_begin);
          idata2objsection:=objdata.createsection(sec_idata2,'');
          idata4objsection:=objdata.createsection(sec_idata4,'');
          idata5objsection:=objdata.createsection(sec_idata5,'');
          emptyint:=0;
          basedllname:=ExtractFileName(dllname);
          { idata4 }
          objdata.SetSection(idata4objsection);
          idata4label:=objdata.SymbolDefine(AsmPrefix+'_names_'+basedllname,AB_GLOBAL,AT_DATA);
          { idata5 }
          objdata.SetSection(idata5objsection);
          idata5label:=objdata.SymbolDefine(AsmPrefix+'_fixup_'+basedllname,AB_GLOBAL,AT_DATA);
          { idata2 }
          objdata.SetSection(idata2objsection);
          headlabel:=objdata.SymbolDefine(AsmPrefix+'_head_'+basedllname,AB_GLOBAL,AT_DATA);
          ObjOutput.exportsymbol(headlabel);
          objdata.writereloc(0,sizeof(LongInt),idata4label,RELOC_RVA);
          objdata.writebytes(emptyint,sizeof(emptyint));
          objdata.writebytes(emptyint,sizeof(emptyint));
          idata7label:=objdata.SymbolRef(AsmPrefix+'_dll_'+basedllname);
          objdata.writereloc(0,sizeof(LongInt),idata7label,RELOC_RVA);
          objdata.writereloc(0,sizeof(LongInt),idata5label,RELOC_RVA);
          WriteObjData(objdata);
          objdata.free;
        end;

        procedure EndImport;
        var
          idata7label : TObjSymbol;
          emptyint : LongInt;
          objdata     : TObjData;
          idata4objsection,
          idata5objsection,
          idata7objsection : TObjSection;
        begin
          objdata:=CreateObjData(cut_end);
          idata4objsection:=objdata.createsection(sec_idata4,'');
          idata5objsection:=objdata.createsection(sec_idata5,'');
          idata7objsection:=objdata.createsection(sec_idata7,'');
          emptyint:=0;
          { idata4 }
          objdata.SetSection(idata4objsection);
          objdata.writebytes(emptyint,sizeof(emptyint));
          if TargetInfo.system in systems_peoptplus then
            objdata.writebytes(emptyint,sizeof(emptyint));
          { idata5 }
          objdata.SetSection(idata5objsection);
          objdata.writebytes(emptyint,sizeof(emptyint));
          if TargetInfo.system in systems_peoptplus then
            objdata.writebytes(emptyint,sizeof(emptyint));
          { idata7 }
          objdata.SetSection(idata7objsection);
          idata7label:=objdata.SymbolDefine(AsmPrefix+'_dll_'+basedllname,AB_GLOBAL,AT_DATA);
          objoutput.exportsymbol(idata7label);
          objdata.writebytes(basedllname[1],length(basedllname));
          objdata.writebytes(emptyint,1);
          WriteObjData(objdata);
          objdata.free;
        end;

        procedure AddImport(const afuncname,MangledName:string;ordnr:LongInt;isvar:boolean);
        const
{$if defined(x86_64)}
          jmpopcode : array[0..1] of byte = (
            $ff,$25             // jmp qword [rip + offset32]
          );
{$elseif defined(aarch64)}
          jmpopcode : array[0..11] of byte = (
            $70,$00,$00,$58,    // ldr ip0, .+12
            $10,$02,$40,$F9,    // ldr ip0, [ip0]
            $00,$02,$1F,$D6     // br ip0
          );
{$elseif defined(i386)}
          jmpopcode : array[0..1] of byte = (
            $ff,$25
          );
{$endif}
          nopopcodes : array[0..1] of byte = (
            $90,$90
          );
        var
          implabel,
          idata2label,
          idata5label,
          idata6label : TObjSymbol;
          emptyint : LongInt;
          objdata     : TObjData;
          textobjsection,
          idata4objsection,
          idata5objsection,
          idata6objsection,
          idata7objsection : TObjSection;
          absordnr: word;

          procedure WriteTableEntry;
          var
            ordint: dword;
          begin
            if ordnr <= 0 then
              begin
                { import by name }
                objdata.writereloc(0,sizeof(LongInt),idata6label,RELOC_RVA);
                if TargetInfo.system in systems_peoptplus then
                  objdata.writebytes(emptyint,sizeof(emptyint));
              end
            else
              begin
                { import by ordinal }
                ordint:=ordnr;
                if TargetInfo.system in systems_peoptplus then
                  begin
                    objdata.writeUInt32LE(ordint);
                    ordint:=$80000000;
                    objdata.writeUInt32LE(ordint);
                  end
                else
                  begin
                    ordint:=ordint or $80000000;
                    objdata.writeUInt32LE(ordint);
                  end;
              end;
          end;

        begin
          implabel:=nil;
          idata5label:=nil;
          textobjsection:=nil;
          objdata:=CreateObjData(cut_normal);
          if not isvar then
            textobjsection:=objdata.createsection(sec_code,'');
          idata4objsection:=objdata.createsection(sec_idata4,'');
          idata5objsection:=objdata.createsection(sec_idata5,'');
          idata6objsection:=objdata.createsection(sec_idata6,'');
          idata7objsection:=objdata.createsection(sec_idata7,'');
          emptyint:=0;
          { idata7, link to head }
          objdata.SetSection(idata7objsection);
          idata2label:=objdata.SymbolRef(AsmPrefix+'_head_'+basedllname);
          objdata.writereloc(0,sizeof(LongInt),idata2label,RELOC_RVA);
          { idata6, import data (ordnr+name) }
          objdata.SetSection(idata6objsection);
          inc(idatalabnr);
          idata6label:=objdata.SymbolDefine(AsmPrefix+'_'+ToStr(idatalabnr),AB_LOCAL,AT_DATA);
          absordnr:=Abs(ordnr);
          { write index hint }
          objdata.writeUInt16LE(absordnr);
          if ordnr <= 0 then
            objdata.writebytes(afuncname[1],length(afuncname));
          objdata.writebytes(emptyint,1);
          objdata.writebytes(emptyint,align(objdata.CurrObjSec.Size,2)-objdata.CurrObjSec.Size);
          { idata4, import lookup table }
          objdata.SetSection(idata4objsection);
          WriteTableEntry;
          { idata5, import address table }
          objdata.SetSection(idata5objsection);
          if isvar then
            implabel:=objdata.SymbolDefine(MangledName,AB_GLOBAL,AT_DATA)
          else
            idata5label:=objdata.SymbolDefine(AsmPrefix+'_'+MangledName,AB_LOCAL,AT_DATA);
          WriteTableEntry;
          { text, jmp }
          if not isvar then
            begin
              objdata.SetSection(textobjsection);
              if MangledName <> '' then
                implabel:=objdata.SymbolDefine(MangledName,AB_GLOBAL,AT_FUNCTION)
              else
                implabel:=objdata.SymbolDefine(basedllname+'_index_'+ToStr(ordnr),AB_GLOBAL,AT_FUNCTION);
              objdata.writebytes(jmpopcode,sizeof(jmpopcode));
{$if defined(x86_64)}
              objdata.writereloc(0,sizeof(LongInt),idata5label,RELOC_RELATIVE);
{$elseif defined(aarch64)}
              objdata.writereloc(0,sizeof(aint),idata5label,RELOC_ABSOLUTE);
{$else}
              objdata.writereloc(0,sizeof(LongInt),idata5label,RELOC_ABSOLUTE32);
{$endif x86_64 or aarch64}
              objdata.writebytes(nopopcodes,align(objdata.CurrObjSec.Size,qword(sizeof(nopopcodes)))-objdata.CurrObjSec.Size);
            end;
          ObjOutput.exportsymbol(implabel);
          WriteObjData(objdata);
          objdata.free;
        end;

      var
        i,j  : LongInt;
        ImportLibrary : TImportLibrary;
        ImportSymbol  : TImportSymbol;
      begin
        AsmPrefix:='imp'+Lower(CurrentModule.ModuleName^);
        idatalabnr:=0;
        SmartFilesCount:=0;
        SmartHeaderCount:=0;
        CurrentModule.LinkOtherStaticLibs.add(CurrentModule.ImportLibFileName,link_always);
        ObjWriter:=TArObjectWriter.CreateAr(CurrentModule.ImportLibFileName);
        ObjOutput:=TPECoffObjOutput.Create(ObjWriter);
        for i:=0 to CurrentModule.ImportLibraryList.Count-1 do
          begin
            ImportLibrary:=TImportLibrary(CurrentModule.ImportLibraryList[i]);
            StartImport(ImportLibrary.Name);
            for j:=0 to ImportLibrary.ImportSymbolList.Count-1 do
              begin
                ImportSymbol:=TImportSymbol(ImportLibrary.ImportSymbolList[j]);
                AddImport(ImportSymbol.Name,ImportSymbol.MangledName,ImportSymbol.OrdNr,ImportSymbol.IsVar);
              end;
            EndImport;
          end;
        ObjOutput.Free;
        ObjWriter.Free;
      end;


    procedure TImportLibWin.generateidatasection;
      var
         templab,
         l1,l2,l3,l4  : TAsmLabel;
         importname : string;
         suffix : integer;
{$ifndef AARCH64}
         href : TReference;
{$endif AARCH64}
         i,j  : LongInt;
         ImportLibrary : TImportLibrary;
         ImportSymbol  : TImportSymbol;
         ImportLabels  : TFPList;
      begin
        if CurrentAsmData.asmlists[al_imports]=nil then
          CurrentAsmData.asmlists[al_imports]:=TAsmList.Create;

        for i:=0 to CurrentModule.ImportLibraryList.Count-1 do
          begin
            ImportLibrary:=TImportLibrary(CurrentModule.ImportLibraryList[i]);
            { align al_procedures for the jumps }
            new_section(CurrentAsmData.asmlists[al_imports],sec_code,'',sizeof(aint));
            { Get labels for the sections }
            CurrentAsmData.getjumplabel(l1);
            CurrentAsmData.getjumplabel(l2);
            CurrentAsmData.getjumplabel(l3);
            new_section(CurrentAsmData.asmlists[al_imports],sec_idata2,'',0);
            { pointer to procedure names }
            CurrentAsmData.asmlists[al_imports].concat(TAIConst.Create_rva_sym(l2));
            { two empty entries follow }
            CurrentAsmData.asmlists[al_imports].concat(TAIConst.Create_32bit(0));
            CurrentAsmData.asmlists[al_imports].concat(TAIConst.Create_32bit(0));
            { pointer to dll name }
            CurrentAsmData.asmlists[al_imports].concat(TAIConst.Create_rva_sym(l1));
            { pointer to fixups }
            CurrentAsmData.asmlists[al_imports].concat(TAIConst.Create_rva_sym(l3));

            { only create one section for each else it will
              create a lot of idata* }

            { first write the name references }
            new_section(CurrentAsmData.asmlists[al_imports],sec_idata4,'',0);
            CurrentAsmData.asmlists[al_imports].concat(TAILabel.Create(l2));

            ImportLabels:=TFPList.Create;
            ImportLabels.Count:=ImportLibrary.ImportSymbolList.Count;
            for j:=0 to ImportLibrary.ImportSymbolList.Count-1 do
              begin
                ImportSymbol:=TImportSymbol(ImportLibrary.ImportSymbolList[j]);

                CurrentAsmData.getjumplabel(templab);
                ImportLabels[j]:=templab;
                if ImportSymbol.Name<>'' then
                  begin
                    CurrentAsmData.asmlists[al_imports].concat(TAIConst.Create_rva_sym(TAsmLabel(ImportLabels[j])));
                    if TargetInfo.system in systems_peoptplus then
                      CurrentAsmData.asmlists[al_imports].concat(TAIConst.Create_32bit(0));
                  end
                else
                  begin
                    if TargetInfo.system in systems_peoptplus then
                      CurrentAsmData.asmlists[al_imports].concat(TAIConst.Create_64bit(int64($8000000000000000) or ImportSymbol.ordnr))
                    else
                      CurrentAsmData.asmlists[al_imports].concat(TAIConst.Create_32bit(LongInt($80000000) or ImportSymbol.ordnr));
                  end;
              end;
            { finalize the names ... }
            CurrentAsmData.asmlists[al_imports].concat(TAIConst.Create_32bit(0));
            if TargetInfo.system in systems_peoptplus then
              CurrentAsmData.asmlists[al_imports].concat(TAIConst.Create_32bit(0));

            { then the addresses and create also the indirect jump }
            new_section(CurrentAsmData.asmlists[al_imports],sec_idata5,'',0);
            CurrentAsmData.asmlists[al_imports].concat(TAILabel.Create(l3));

            for j:=0 to ImportLibrary.ImportSymbolList.Count-1 do
              begin
                ImportSymbol:=TImportSymbol(ImportLibrary.ImportSymbolList[j]);
                if not ImportSymbol.IsVar then
                  begin
                    CurrentAsmData.getjumplabel(l4);
                    { create indirect jump and }
                    { place jump in al_procedures }
                    new_section(CurrentAsmData.asmlists[al_imports],sec_code,'',0);
                    if ImportSymbol.Name <> '' then
                      CurrentAsmData.asmlists[al_imports].concat(TAISymbol.Createname_global(ImportSymbol.MangledName,AT_FUNCTION,0,VoidCodePointerType))
                    else
                      CurrentAsmData.asmlists[al_imports].concat(TAISymbol.Createname_global(ExtractFileName(ImportLibrary.Name)+'_index_'+ToStr(ImportSymbol.ordnr),AT_FUNCTION,0,VoidCodePointerType));
                    CurrentAsmData.asmlists[al_imports].concat(TAIFunctionName.Create(''));
                  {$if defined(AARCH64)}
                    { ToDo }
                    InternalError(2020033001);
                  {$else X86}
                    Reference_Reset_Symbol(href,l4,0,sizeof(PInt),[]);
{$ifdef X86_64}
                    href.Base:=NR_RIP;
{$endif X86_64}

                    CurrentAsmData.asmlists[al_imports].concat(TAICPU.Op_ref(A_JMP,S_NO,href));
                    CurrentAsmData.asmlists[al_imports].concat(TAIAlign.Create_op(4,$90));
                  {$endif}
                    { add jump field to al_imports }
                    new_section(CurrentAsmData.asmlists[al_imports],sec_idata5,'',0);
                    if (cs_debuginfo in CurrentSettings.ModuleSwitches) then
                      begin
                        if ImportSymbol.MangledName<>'' then
                          begin
                            importname:='__imp_'+ImportSymbol.MangledName;
                            suffix:=0;
                            while Assigned(CurrentAsmData.GetAsmSymbol(importname)) do
                              begin
                                inc(suffix);
                                importname:='__imp_'+ImportSymbol.MangledName+'_'+ToStr(suffix);
                              end;
                            CurrentAsmData.asmlists[al_imports].concat(TAISymbol.createname(importname,AT_FUNCTION,4,VoidCodePointerType));
                          end
                        else
                          begin
                            importname:='__imp_by_ordinal'+ToStr(ImportSymbol.ordnr);
                            suffix:=0;
                            while Assigned(CurrentAsmData.GetAsmSymbol(importname)) do
                              begin
                                inc(suffix);
                                importname:='__imp_by_ordinal'+ToStr(ImportSymbol.ordnr)+'_'+ToStr(suffix);
                              end;
                            CurrentAsmData.asmlists[al_imports].concat(TAISymbol.createname(importname,AT_FUNCTION,4,VoidCodePointerType));
                          end;
                      end;
                     CurrentAsmData.asmlists[al_imports].concat(TAILabel.Create(l4));
                  end
                else
                  CurrentAsmData.asmlists[al_imports].concat(TAISymbol.Createname_global(ImportSymbol.MangledName,AT_DATA,0,VoidPointerType));
                CurrentAsmData.asmlists[al_imports].concat(TAIConst.Create_rva_sym(TAsmLabel(Importlabels[j])));
                if TargetInfo.system in systems_peoptplus then
                  CurrentAsmData.asmlists[al_imports].concat(TAIConst.Create_32bit(0));
              end;
            { finalize the addresses }
            CurrentAsmData.asmlists[al_imports].concat(TAIConst.Create_32bit(0));
            if TargetInfo.system in systems_peoptplus then
              CurrentAsmData.asmlists[al_imports].concat(TAIConst.Create_32bit(0));

            { finally the import information }
            new_section(CurrentAsmData.asmlists[al_imports],sec_idata6,'',0);
            for j:=0 to ImportLibrary.ImportSymbolList.Count-1 do
              begin
                ImportSymbol:=TImportSymbol(ImportLibrary.ImportSymbolList[j]);
                CurrentAsmData.asmlists[al_imports].concat(TAILabel.Create(TAsmLabel(ImportLabels[j])));
                { the ordinal number }
                CurrentAsmData.asmlists[al_imports].concat(TAIConst.Create_16bit(ImportSymbol.ordnr));
                CurrentAsmData.asmlists[al_imports].concat(TAIString.Create(ImportSymbol.Name+#0));
                CurrentAsmData.asmlists[al_imports].concat(TAIAlign.Create_op(2,0));
              end;
            { create import dll name }
            new_section(CurrentAsmData.asmlists[al_imports],sec_idata7,'',0);
            CurrentAsmData.asmlists[al_imports].concat(TAILabel.Create(l1));
            CurrentAsmData.asmlists[al_imports].concat(TAIString.Create(ImportLibrary.Name+#0));
            ImportLabels.Free;
            ImportLabels:=nil;
          end;
      end;


    procedure TImportLibWin.generatelib;
      begin
        if GenerateImportSection then
          generateidatasection
        else
          generateimportlib;
      end;


{*****************************************************************************
                             TExportLibWin
*****************************************************************************}

    destructor TExportLibWin.Destroy;
      begin
        EList_indexed.Free;
        EList_nonindexed.Free;
        inherited;
      end;


    procedure TExportLibWin.preparelib(const s:string);
      begin
         if CurrentAsmData.asmlists[al_exports]=nil then
           CurrentAsmData.asmlists[al_exports]:=TAsmList.Create;
         if EList_indexed=nil then
           EList_indexed:=TFPList.Create;
         if EList_nonindexed=nil then
           EList_nonindexed:=TFPList.Create;
      end;


    procedure TExportLibWin.exportvar(hp : TExportedItem);
      begin
         { same code used !! PM }
         exportprocedure(hp);
      end;

    var
      Gl_DoubleIndex:boolean;
      Gl_DoubleIndexValue:LongInt;

    function IdxCompare(Item1, Item2: Pointer): Integer;
      var
        I1:TExportedItem absolute Item1;
        I2:TExportedItem absolute Item2;
      begin
        Result:=I1.Index-I2.Index;
        if(Result=0)and(Item1<>Item2)then
         begin
          Gl_DoubleIndex:=true;
          Gl_DoubleIndexValue:=I1.Index;
         end;
      end;


    procedure TExportLibWin.exportprocedure(hp : TExportedItem);
      begin
        if (eo_index in hp.options) and ((hp.Index<=0) or (hp.Index>$ffff)) then
          begin
           message1(parser_e_export_invalid_index,ToStr(hp.Index));
           hp.free;
           exit;
          end;
        if Assigned(hp.sym) and not (eo_no_sym_name in hp.options) then
          begin
            case hp.sym.typ of
              staticvarsym:
                hp.internalname:=TStaticVarSym(hp.sym).MangledName;
              ProcSym:
                hp.internalname:=TProcDef(TProcSym(hp.sym).ProcdefList[0]).MangledName;
              else
                InternalError(200709272);
            end;
          end;
        { Unit cleanup may release the implementation-only symbol. }
        hp.sym:=nil;
        if CurrentModule.IsUnit then
          begin
            CurrentModule.ExportList.concat(hp);
            exit;
          end;
        if eo_index in hp.options then
          EList_indexed.Add(hp)
        else
          EList_nonindexed.Add(hp);
      end;


    procedure TExportLibWin.exportfromlist(hp : TExportedItem);
      //formerly TExportLibWin.exportprocedure
      { must be ordered at least for win32 !! }
      var
        hp2 : TExportedItem;
      begin
        hp2:=TExportedItem(CurrentModule.ExportList.first);
        while Assigned(hp2) and
           (hp.name^>hp2.name^) do
          hp2:=TExportedItem(hp2.next);
        { insert hp there !! }
        if hp2=nil then
          CurrentModule.ExportList.concat(hp)
        else
          begin
            if hp2.name^=hp.name^ then
              begin
                { this is not allowed !! }
                duplicatesymbol(hp.name^);
                hp.free;
                exit;
              end;
            CurrentModule.ExportList.insertbefore(hp,hp2);
          end;
      end;


    procedure TExportLibWin.generatelib;
      var
         ordinal_base,ordinal_max,ordinal_min : LongInt;
         current_index : LongInt;
         entries,named_entries : LongInt;
         name_label,dll_name_label,export_address_table : TAsmLabel;
         export_name_table_pointers,export_ordinal_table : TAsmLabel;
         hp,hp2 : TExportedItem;
         temtexport : TLinkedList;
         address_table,name_table_pointers,
         name_table,ordinal_table : TAsmList;
         i,autoindex,ni_high : LongInt;
         hole : boolean;
         asmsym : TAsmSymbol;
         unitmodule : TModule;
      begin
         { Both source-built and cached units own their export declarations. }
         unitmodule:=TModule(Loaded_Units.first);
         while Assigned(unitmodule) do
           begin
             if unitmodule.IsUnit then
               begin
                 hp:=TExportedItem(unitmodule.ExportList.first);
                 while Assigned(hp) do
                   begin
                     hp2:=TExportedItem.Create;
                     hp2.name:=StringDup(hp.name^);
                     hp2.internalname:=hp.internalname;
                     hp2.Index:=hp.Index;
                     hp2.options:=hp.options;
                     hp2.is_var:=hp.is_var;
                     exportprocedure(hp2);
                     hp:=TExportedItem(hp.next);
                   end;
               end;
             unitmodule:=TModule(unitmodule.next);
           end;
         Gl_DoubleIndex:=false;
         ELIst_indexed.Sort(@IdxCompare);

         if Gl_DoubleIndex then
           begin
             message1(parser_e_export_ordinal_double,ToStr(Gl_DoubleIndexValue));
             FreeAndNil(EList_indexed);
             FreeAndNil(EList_nonindexed);
             exit;
           end;

         autoindex:=1;
         while EList_nonindexed.Count>0 do
          begin
           hole:=(EList_indexed.Count>0) and (TExportedItem(EList_indexed.Items[0]).Index>1);
           if not hole then
            for i:=autoindex to pred(EList_indexed.Count) do
             if TExportedItem(EList_indexed.Items[i]).Index-TExportedItem(EList_indexed.Items[pred(i)]).Index>1 then
              begin
               autoindex:=succ(TExportedItem(EList_indexed.Items[pred(i)]).Index);
               hole:=true;
               break;
              end;
           ni_high:=pred(EList_nonindexed.Count);
           if not hole then
            begin
             autoindex:=succ(EList_indexed.Count);
             EList_indexed.Add(EList_nonindexed.Items[ni_high]);
            end
           else
            EList_indexed.Insert(pred(AutoIndex),EList_nonindexed.Items[ni_high]);
           EList_nonindexed.Delete(ni_high);
           TExportedItem(EList_indexed.Items[pred(AutoIndex)]).Index:=autoindex;
          end;
         FreeAndNil(EList_nonindexed);
         for i:=0 to pred(EList_indexed.Count) do
           exportfromlist(TExportedItem(EList_indexed.Items[i]));
         FreeAndNil(EList_indexed);

         hp:=TExportedItem(CurrentModule.ExportList.first);
         if not Assigned(hp) then
           exit;

         ordinal_max:=0;
         ordinal_min:=$7FFFFFFF;
         entries:=0;
         named_entries:=0;
         CurrentAsmData.getjumplabel(dll_name_label);
         CurrentAsmData.getjumplabel(export_address_table);
         CurrentAsmData.getjumplabel(export_name_table_pointers);
         CurrentAsmData.getjumplabel(export_ordinal_table);

         { count entries }
         while Assigned(hp) do
           begin
              inc(entries);
              if (hp.Index>ordinal_max) then
                ordinal_max:=hp.Index;
              if (hp.Index>0) and (hp.Index<ordinal_min) then
                ordinal_min:=hp.Index;
              if Assigned(hp.name) then
                inc(named_entries);
              hp:=TExportedItem(hp.next);
           end;

         { no support for higher ordinal base yet !! }
         ordinal_base:=1;
         current_index:=ordinal_base;
         { we must also count the holes !! }
         entries:=ordinal_max-ordinal_base+1;

         new_section(CurrentAsmData.asmlists[al_exports],sec_edata,'',0);
         { create label to reference from main so smartlink will include
           the .edata section }
         CurrentAsmData.asmlists[al_exports].concat(TAISymbol.Createname_global(Make_MangledName('EDATA',CurrentModule.LocalSymTable,''),AT_METADATA,0,VoidPointerType));
         { export flags }
         CurrentAsmData.asmlists[al_exports].concat(TAIConst.Create_32bit(0));
         { date/time stamp }
         CurrentAsmData.asmlists[al_exports].concat(TAIConst.Create_32bit(0));
         { major version }
         CurrentAsmData.asmlists[al_exports].concat(TAIConst.Create_16bit(0));
         { minor version }
         CurrentAsmData.asmlists[al_exports].concat(TAIConst.Create_16bit(0));
         { pointer to dll name }
         CurrentAsmData.asmlists[al_exports].concat(TAIConst.Create_rva_sym(dll_name_label));
         { ordinal base normally set to 1 }
         CurrentAsmData.asmlists[al_exports].concat(TAIConst.Create_32bit(ordinal_base));
         { number of entries }
         CurrentAsmData.asmlists[al_exports].concat(TAIConst.Create_32bit(entries));
         { number of named entries }
         CurrentAsmData.asmlists[al_exports].concat(TAIConst.Create_32bit(named_entries));
         { address of export address table }
         CurrentAsmData.asmlists[al_exports].concat(TAIConst.Create_rva_sym(export_address_table));
         { address of name pointer pointers }
         CurrentAsmData.asmlists[al_exports].concat(TAIConst.Create_rva_sym(export_name_table_pointers));
         { address of ordinal number pointers }
         CurrentAsmData.asmlists[al_exports].concat(TAIConst.Create_rva_sym(export_ordinal_table));
         { the name }
         CurrentAsmData.asmlists[al_exports].concat(TAILabel.Create(dll_name_label));
         if st='' then
           CurrentAsmData.asmlists[al_exports].concat(TAIString.Create(CurrentModule.ModuleName^+TargetInfo.sharedlibext+#0))
         else
           CurrentAsmData.asmlists[al_exports].concat(TAIString.Create(st+TargetInfo.sharedlibext+#0));

         {  export address table }
         address_table:=TAsmList.Create;
         address_table.concat(TAIAlign.Create_op(4,0));
         address_table.concat(TAILabel.Create(export_address_table));
         name_table_pointers:=TAsmList.Create;
         name_table_pointers.concat(TAIAlign.Create_op(4,0));
         name_table_pointers.concat(TAILabel.Create(export_name_table_pointers));
         ordinal_table:=TAsmList.Create;
         ordinal_table.concat(TAIAlign.Create_op(4,0));
         ordinal_table.concat(TAILabel.Create(export_ordinal_table));
         name_table:=TAsmList.Create;
         name_table.concat(TAIAlign.Create_op(4,0));
         { write each address }
         hp:=TExportedItem(CurrentModule.ExportList.first);
         while Assigned(hp) do
           begin
              if eo_name in hp.options then
                begin
                   CurrentAsmData.getjumplabel(name_label);
                   name_table_pointers.concat(TAIConst.Create_rva_sym(name_label));
                   ordinal_table.concat(TAIConst.Create_16bit(hp.Index-ordinal_base));
                   name_table.concat(TAIAlign.Create_op(2,0));
                   name_table.concat(TAILabel.Create(name_label));
                   name_table.concat(TAIString.Create(hp.name^+#0));
                end;
              hp:=TExportedItem(hp.next);
           end;
         { order in increasing ordinal values }
         { into temtexport list }
         temtexport:=TLinkedList.Create;
         hp:=TExportedItem(CurrentModule.ExportList.first);
         while Assigned(hp) do
           begin
              CurrentModule.ExportList.remove(hp);
              hp2:=TExportedItem(temtexport.first);
              while Assigned(hp2) and (hp.Index>hp2.Index) do
                hp2:=TExportedItem(hp2.next);
              if hp2=nil then
                temtexport.concat(hp)
              else
                temtexport.insertbefore(hp,hp2);
              hp:=TExportedItem(CurrentModule.ExportList.first);
           end;

         { write the export adress table }
         current_index:=ordinal_base;
         hp:=TExportedItem(temtexport.first);
         while Assigned(hp) do
           begin
              { fill missing values }
              while current_index<hp.Index do
                begin
                   address_table.concat(TAIConst.Create_32bit(0));
                   inc(current_index);
                end;

              if hp.internalname<>'' then
                begin
                  if hp.is_var then
                    asmsym:=CurrentAsmData.RefAsmSymbol(hp.internalname,AT_DATA)
                  else
                    asmsym:=CurrentAsmData.RefAsmSymbol(hp.internalname,AT_FUNCTION);
                end
              else
                asmsym:=CurrentAsmData.RefAsmSymbol(hp.name^,AT_DATA);
              address_table.concat(TAIConst.Create_rva_sym(asmsym));
              inc(current_index);
              hp:=TExportedItem(hp.next);
           end;

         CurrentAsmData.asmlists[al_exports].ConcatList(address_table);
         CurrentAsmData.asmlists[al_exports].ConcatList(name_table_pointers);
         CurrentAsmData.asmlists[al_exports].ConcatList(ordinal_table);
         CurrentAsmData.asmlists[al_exports].ConcatList(name_table);
         address_table.Free;
         name_table_pointers.free;
         ordinal_table.free;
         name_table.free;

         { the package support needs this data later on
           to create the import library }
         CurrentModule.ExportList.ConcatList(temtexport);
         temtexport.free;
      end;


{$if defined(i386) or defined(x86_64) or defined(aarch64)}
{****************************************************************************
                            TExternalLinkerWin64LLD
****************************************************************************}

    constructor TExternalLinkerWin64LLD.Create;
      begin
        inherited Create;
        SharedLibFiles.doubles:=true;
        StaticLibFiles.doubles:=true;
      end;


    function TExternalLinkerWin64LLD.WriteLLDResponseFile(const OutputFile:string;IsDLL:boolean):boolean;
      var
        LinkRes : TLinkRes;
        HPath   : TCmdStrListItem;
        S,S2,
        SubsystemStr : TCmdStr;
        I       : LongInt;
        StackReserve : qword;
      begin
        WriteLLDResponseFile:=false;
        LinkRes:=TLinkRes.Create(OutputExeDir+Info.ResName,true);
        with LinkRes do
          begin
            case TargetInfo.system of
              system_i386_win32:
                begin
                  Add('/machine:x86');
                  Add('/safeseh:no');
                end;
              system_x86_64_win64:
                Add('/machine:x64');
              system_aarch64_win64:
                Add('/machine:arm64');
              else
                InternalError(2026092202);
            end;
            Add('/nodefaultlib');
            { lld-link response files use Windows quoting on every host. }
            Add('/out:'+MaybeQuoted_For_Script(OutputFile,script_dos));
            if Info.ExtraOptions<>'' then
              Add(Info.ExtraOptions);
            if IsDLL then
              begin
                Add('/dll');
                Add('/noimplib');
                if TargetInfo.system=system_i386_win32 then
                  begin
                    if AppType=app_gui then
                      Add('/entry:DLLWinMainCRTStartup')
                    else
                      Add('/entry:DLLMainCRTStartup');
                  end
                else
                if AppType=app_gui then
                  Add('/entry:_DLLWinMainCRTStartup')
                else
                  Add('/entry:_DLLMainCRTStartup');
              end
            else if TargetInfo.system=system_i386_win32 then
              begin
                if AppType=app_gui then
                  Add('/entry:WinMainCRTStartup')
                else
                  Add('/entry:mainCRTStartup');
              end
            else if AppType=app_gui then
              Add('/entry:_WinMainCRTStartup')
            else
              Add('/entry:_mainCRTStartup');

            case AppType of
              app_native:
                SubsystemStr:='/subsystem:native';
              app_gui:
                SubsystemStr:='/subsystem:windows';
              else
                SubsystemStr:='/subsystem:console';
            end;
            if SetPESubSysVersionSetExplicitely then
              SubsystemStr:=SubsystemStr+','+ToStr(PESubSysVersionMajor)+'.'+ToStr(PESubSysVersionMinor);
            Add(SubsystemStr);

            if create_smartlink_sections then
              Add('/opt:ref,noicf')
            else
              Add('/opt:noref,noicf');
            if cs_link_strip in CurrentSettings.GlobalSwitches then
              Add('/debug:none')
            else if cs_debuginfo in CurrentSettings.ModuleSwitches then
              Add('/debug:dwarf');
            if RelocSection then
              Add('/fixed:no')
            else
              Add('/fixed');
            Add('/timestamp:0');
            if SetPEUserVersionSetExplicitely then
              Add('/version:'+ToStr(PEUserVersionMajor)+'.'+ToStr(PEUserVersionMinor))
            else if DLLVersion<>'' then
              Add('/version:'+ToStr(DLLMajor)+'.'+ToStr(DLLMinor));
            if SetPEOSVersionSetExplicitely then
              Add('/osversion:'+ToStr(PEOSVersionMajor)+'.'+ToStr(PEOSVersionMinor))
            else if SetPESubSysVersionSetExplicitely then
              { lld-link otherwise copies an explicit subsystem version into
                the OS version fields as well. }
              Add('/osversion:6.0');
            if ImageBaseSetExplicity then
              Add('/base:0x'+HexStr(ImageBase,SizeOf(ImageBase)*2));
            StackReserve:=StackSize;
            if MaxStackSizeSetExplicity then
              StackReserve:=MaxStackSize;
            if StackReserve<>0 then
              if MinStackSizeSetExplicity then
                Add('/stack:'+ToStr(StackReserve)+','+ToStr(MinStackSize))
              else
                Add('/stack:'+ToStr(StackReserve));
            if cs_link_map in CurrentSettings.GlobalSwitches then
              Add('/map:'+MaybeQuoted_For_Script(ChangeFileExt(OutputFile,'.map'),script_dos));

            HPath:=TCmdStrListItem(CurrentModule.LocalLibrarySearchPath.First);
            while Assigned(HPath) do
              begin
                { A trailing backslash would escape the closing response-file quote. }
                Add('/libpath:'+MaybeQuoted_For_Script(BSToSlash(HPath.Str),script_dos));
                HPath:=TCmdStrListItem(HPath.Next);
              end;
            HPath:=TCmdStrListItem(LibrarySearchPath.First);
            while Assigned(HPath) do
              begin
                Add('/libpath:'+MaybeQuoted_For_Script(BSToSlash(HPath.Str),script_dos));
                HPath:=TCmdStrListItem(HPath.Next);
              end;

            while not ObjectFiles.Empty do
              begin
                S:=ObjectFiles.GetFirst;
                if S<>'' then
                  AddFileName(MaybeQuoted_For_Script(S,script_dos));
              end;
            while not StaticLibFiles.Empty do
              begin
                S:=StaticLibFiles.GetFirst;
                if S<>'' then
                  AddFileName(MaybeQuoted_For_Script(S,script_dos));
              end;
            if CurrentModule.ResourceLinkFile<>'' then
              AddFileName(MaybeQuoted_For_Script(CurrentModule.ResourceLinkFile,script_dos));
            while not SharedLibFiles.Empty do
              begin
                S:=SharedLibFiles.GetFirst;
                if FindLibraryFile(S,TargetInfo.staticClibprefix,TargetInfo.staticClibext,S2) then
                  AddFileName(MaybeQuoted_For_Script(S2,script_dos))
                else
                  begin
                    if Pos(TargetInfo.sharedlibprefix,S)=1 then
                      Delete(S,1,Length(TargetInfo.sharedlibprefix));
                    I:=Pos(TargetInfo.sharedlibext,S);
                    if I>0 then
                      Delete(S,I,Length(TargetInfo.sharedlibext));
                    AddFileName(MaybeQuoted_For_Script(TargetInfo.staticClibprefix+S+TargetInfo.staticClibext,script_dos));
                  end;
              end;
            if not DefFile.Empty then
              begin
                DefFile.WriteFile;
                Add('/def:'+MaybeQuoted_For_Script(DefFile.FName,script_dos));
              end;
            WriteToDisk;
          end;
        LinkRes.Free;
        WriteLLDResponseFile:=true;
      end;


    function TExternalLinkerWin64LLD.DoLLDLink(const OutputFile:string;IsDLL:boolean):boolean;
      var
        CmdStr : TCmdStr;
      begin
        if not(cs_link_nolink in CurrentSettings.GlobalSwitches) then
          Message1(exec_i_linking,OutputFile);
        if not WriteLLDResponseFile(OutputFile,IsDLL) then
          exit(false);
        { Quote the whole argument: the Unix process parser only recognizes
          quotes at the start of an argument. }
        CmdStr:=MaybeQuoted('@'+OutputExeDir+Info.ResName);
        DoLLDLink:=DoExec(FindUtil('lld-link'),CmdStr,true,false);
        if DoLLDLink and
           not(cs_link_nolink in CurrentSettings.GlobalSwitches) then
          DeleteFile(OutputExeDir+Info.ResName);
      end;


    function TExternalLinkerWin64LLD.MakeExecutable:boolean;
      begin
        MakeExecutable:=DoLLDLink(CurrentModule.ExeFileName,false);
      end;


    function TExternalLinkerWin64LLD.MakeSharedLibrary:boolean;
      begin
        MakeSharedLibrary:=DoLLDLink(CurrentModule.SharedLibFileName,true);
      end;


    procedure TExternalLinkerWin64LLD.InitSysInitUnitName;
      begin
        GlobalInitSysInitUnitName(self);
      end;
{$endif i386 or x86_64 or aarch64}




{****************************************************************************
                            TDLLScannerWin
****************************************************************************}

    procedure TDLLScannerWin.CheckDLLFunc(const dllname,funcname:string);
      var
        i : LongInt;
        ExtName : string;
      begin
        for i:=0 to CurrentModule.DLLScannerInputList.count-1 do
          begin
            ExtName:=CurrentModule.DLLScannerInputList.NameOfIndex(i);
            if (ExtName=funcname) then
              begin
                CurrentModule.AddExternalImport(dllname,funcname,funcname,0,false,false);
                importfound:=true;
                CurrentModule.DLLScannerInputList.Delete(i);
                exit;
              end;
          end;
      end;


    function TDLLScannerWin.scan(const binname:string):boolean;
      var
        hs,
        dllname : TCmdStr;
      begin
        result:=false;
        { is there already an import library the we will use that one }
        if FindLibraryFile(binname,TargetInfo.staticClibprefix,TargetInfo.staticClibext,hs) then
          exit;
        { check if we can find the dll }
        hs:=binname;
        if ExtractFileExt(hs)='' then
          hs:=ChangeFileExt(hs,TargetInfo.sharedlibext);
        if not FindDll(hs,dllname) then
          exit;
        importfound:=false;
        ReadDLLImports(dllname,@CheckDLLFunc);
        if importfound then
          CurrentModule.DLLScannerInputList.Pack;
        result:=importfound;
      end;

{*****************************************************************************
                                     Initialize
*****************************************************************************}

initialization
{$if defined(i386) or defined(x86_64) or defined(aarch64)}
  RegisterLinker(ld_lld_windows,TExternalLinkerWin64LLD);
{$endif i386 or x86_64 or aarch64}
{$ifdef i386}
  RegisterImport(system_i386_win32,TImportLibWin);
  RegisterExport(system_i386_win32,TExportLibWin);
  RegisterDLLScanner(system_i386_win32,TDLLScannerWin);
  RegisterTarget(system_i386_win32_info);
{$endif i386}
{$ifdef x86_64}
  RegisterImport(system_x86_64_win64,TImportLibWin);
  RegisterExport(system_x86_64_win64,TExportLibWin);
  RegisterDLLScanner(system_x86_64_win64,TDLLScannerWin);
  RegisterTarget(system_x64_win64_info);
{$endif x86_64}
{$ifdef aarch64}
  RegisterImport(system_aarch64_win64,TImportLibWin);
  RegisterExport(system_aarch64_win64,TExportLibWin);
  RegisterDLLScanner(system_aarch64_win64,TDLLScannerWin);
  // ToDo?
  RegisterTarget(system_aarch64_win64_info);
{$endif aarch64}
end.
