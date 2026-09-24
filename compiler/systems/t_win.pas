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
       cutils,cclasses,
       aasmbase,aasmtai,aasmdata,aasmcpu,fmodule,globtype,globals,systems,verbose,
       symconst,symdef,symsym,
       cscript,gendef,
       cpubase,
       import,export,link,comprsrc,i_win;


    const
       MAX_DEFAULT_EXTENSIONS = 3;

    type
       tStr4=array[1..MAX_DEFAULT_EXTENSIONS] of string[4];
       pStr4=^tStr4;

      TImportLibWin=class(timportlib)
      private
        procedure generateimportlib;
        procedure generateidatasection;
      public
        procedure generatelib;override;
      end;

      TExportLibWin=class(texportlib)
      private
        st : string;
        EList_indexed:TFPList;
        EList_nonindexed:TFPList;
      public
        destructor Destroy;override;
        procedure preparelib(const s:string);override;
        procedure exportprocedure(hp : texported_item);override;
        procedure exportvar(hp : texported_item);override;
        procedure exportfromlist(hp : texported_item);
        procedure generatelib;override;
        procedure generatenasmlib;virtual;
      end;


{$if defined(x86_64) or defined(aarch64)}
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
{$endif x86_64 or aarch64}

      TDLLScannerWin=class(tDLLScanner)
      private
        importfound : boolean;
        procedure CheckDLLFunc(const dllname,funcname:string);
      public
        function Scan(const binname:string):boolean;override;
      end;

implementation

  uses
    SysUtils,
    cfileutl,
    cgutils,dbgbase,
    owar,ogbase
{$ifdef SUPPORT_OMF}
    ,ogomf
{$endif SUPPORT_OMF}
    ,ogcoff;


  const
    res_gnu_windres_info : tresinfo =
        (
          id     : res_gnu_windres;
          resbin : 'fpcres';
          rescmd : '-o $OBJ -a $ARCH -of coff $DBG';
          rcbin  : 'windres';
          rccmd  : '--include $INC -O res -D FPC -o $RES $RC';
          resourcefileclass : nil;
          resflags : [];
        );
{$ifdef x86_64}
    res_win64_gorc_info : tresinfo =
        (
          id     : res_win64_gorc;
          resbin : 'fpcres';
          rescmd : '-o $OBJ -a $ARCH -of coff $DBG';
          rcbin  : 'gorc';
          rccmd  : '/machine x64 /nw /ni /r /d FPC /fo $RES $RC';
          resourcefileclass : nil;
          resflags : [];
        );
{$endif x86_64}


  Procedure GlobalInitSysInitUnitName(Linker : TLinker);
    var
      hp           : tmodule;
      linkcygwin : boolean;
    begin
      if target_info.system=system_i386_win32 then
        begin
          linkcygwin := false;
          hp:=tmodule(loaded_units.first);
          while assigned(hp) do
           begin
             linkcygwin := hp.linkothersharedlibs.find('cygwin') or hp.linkotherstaticlibs.find('cygwin');
             if linkcygwin then
               break;
             hp:=tmodule(hp.next);
           end;
          if linkcygwin or (Linker.SharedLibFiles.Find('cygwin')<>nil) or (Linker.StaticLibFiles.Find('cygwin')<>nil) then
            linker.sysinitunit:='sysinitcyg'
          else
            linker.sysinitunit:='sysinitpas';
        end
      else if target_info.system in [system_x86_64_win64,system_aarch64_win64] then
        linker.sysinitunit:='sysinit';
    end;


{*****************************************************************************
                             TImportLibWin
*****************************************************************************}

    procedure TImportLibWin.generateimportlib;
      var
        ObjWriter        : tarobjectwriter;
        ObjOutput        : TPECoffObjOutput;
        basedllname      : string;
        AsmPrefix        : string;
        idatalabnr,
        SmartFilesCount,
        SmartHeaderCount : longint;

        function CreateObjData(place:tcutplace):TObjData;
        var
          s : string;
        begin
          s:='';
          case place of
            cut_begin :
              begin
                inc(SmartHeaderCount);
                s:=asmprefix+tostr(SmartHeaderCount)+'h';
              end;
            cut_normal :
              s:=asmprefix+tostr(SmartHeaderCount)+'s';
            cut_end :
              s:=asmprefix+tostr(SmartHeaderCount)+'t';
          end;
          inc(SmartFilesCount);
          result:=ObjOutput.NewObjData(FixFileName(s+tostr(SmartFilesCount)+target_info.objext));
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
          emptyint    : longint;
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
          idata4label:=objdata.SymbolDefine(asmprefix+'_names_'+basedllname,AB_GLOBAL,AT_DATA);
          { idata5 }
          objdata.SetSection(idata5objsection);
          idata5label:=objdata.SymbolDefine(asmprefix+'_fixup_'+basedllname,AB_GLOBAL,AT_DATA);
          { idata2 }
          objdata.SetSection(idata2objsection);
          headlabel:=objdata.SymbolDefine(asmprefix+'_head_'+basedllname,AB_GLOBAL,AT_DATA);
          ObjOutput.exportsymbol(headlabel);
          objdata.writereloc(0,sizeof(longint),idata4label,RELOC_RVA);
          objdata.writebytes(emptyint,sizeof(emptyint));
          objdata.writebytes(emptyint,sizeof(emptyint));
          idata7label:=objdata.SymbolRef(asmprefix+'_dll_'+basedllname);
          objdata.writereloc(0,sizeof(longint),idata7label,RELOC_RVA);
          objdata.writereloc(0,sizeof(longint),idata5label,RELOC_RVA);
          WriteObjData(objdata);
          objdata.free;
        end;

        procedure EndImport;
        var
          idata7label : TObjSymbol;
          emptyint : longint;
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
          if target_info.system in systems_peoptplus then
            objdata.writebytes(emptyint,sizeof(emptyint));
          { idata5 }
          objdata.SetSection(idata5objsection);
          objdata.writebytes(emptyint,sizeof(emptyint));
          if target_info.system in systems_peoptplus then
            objdata.writebytes(emptyint,sizeof(emptyint));
          { idata7 }
          objdata.SetSection(idata7objsection);
          idata7label:=objdata.SymbolDefine(asmprefix+'_dll_'+basedllname,AB_GLOBAL,AT_DATA);
          objoutput.exportsymbol(idata7label);
          objdata.writebytes(basedllname[1],length(basedllname));
          objdata.writebytes(emptyint,1);
          WriteObjData(objdata);
          objdata.free;
        end;

        procedure AddImport(const afuncname,mangledname:string;ordnr:longint;isvar:boolean);
        const
{$if defined(x86_64)}
          jmpopcode : array[0..1] of byte = (
            $ff,$25             // jmp qword [rip + offset32]
          );
{$elseif defined(arm)}
          jmpopcode : array[0..7] of byte = (
            $00,$c0,$9f,$e5,    // ldr ip, [pc, #0]
            $00,$f0,$9c,$e5     // ldr pc, [ip]
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
          emptyint : longint;
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
                objdata.writereloc(0,sizeof(longint),idata6label,RELOC_RVA);
                if target_info.system in systems_peoptplus then
                  objdata.writebytes(emptyint,sizeof(emptyint));
              end
            else
              begin
                { import by ordinal }
                ordint:=ordnr;
                if target_info.system in systems_peoptplus then
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
          idata2label:=objdata.SymbolRef(asmprefix+'_head_'+basedllname);
          objdata.writereloc(0,sizeof(longint),idata2label,RELOC_RVA);
          { idata6, import data (ordnr+name) }
          objdata.SetSection(idata6objsection);
          inc(idatalabnr);
          idata6label:=objdata.SymbolDefine(asmprefix+'_'+tostr(idatalabnr),AB_LOCAL,AT_DATA);
          absordnr:=Abs(ordnr);
          { write index hint }
          objdata.writeUInt16LE(absordnr);
          if ordnr <= 0 then
            objdata.writebytes(afuncname[1],length(afuncname));
          objdata.writebytes(emptyint,1);
          objdata.writebytes(emptyint,align(objdata.CurrObjSec.size,2)-objdata.CurrObjSec.size);
          { idata4, import lookup table }
          objdata.SetSection(idata4objsection);
          WriteTableEntry;
          { idata5, import address table }
          objdata.SetSection(idata5objsection);
          if isvar then
            implabel:=objdata.SymbolDefine(mangledname,AB_GLOBAL,AT_DATA)
          else
            idata5label:=objdata.SymbolDefine(asmprefix+'_'+mangledname,AB_LOCAL,AT_DATA);
          WriteTableEntry;
          { text, jmp }
          if not isvar then
            begin
              objdata.SetSection(textobjsection);
              if mangledname <> '' then
                implabel:=objdata.SymbolDefine(mangledname,AB_GLOBAL,AT_FUNCTION)
              else
                implabel:=objdata.SymbolDefine(basedllname+'_index_'+tostr(ordnr),AB_GLOBAL,AT_FUNCTION);
              objdata.writebytes(jmpopcode,sizeof(jmpopcode));
{$if defined(x86_64)}
              objdata.writereloc(0,sizeof(longint),idata5label,RELOC_RELATIVE);
{$elseif defined(aarch64)}
              objdata.writereloc(0,sizeof(aint),idata5label,RELOC_ABSOLUTE);
{$else}
              objdata.writereloc(0,sizeof(longint),idata5label,RELOC_ABSOLUTE32);
{$endif x86_64 or aarch64}
              objdata.writebytes(nopopcodes,align(objdata.CurrObjSec.size,qword(sizeof(nopopcodes)))-objdata.CurrObjSec.size);
            end;
          ObjOutput.exportsymbol(implabel);
          WriteObjData(objdata);
          objdata.free;
        end;

      var
        i,j  : longint;
        ImportLibrary : TImportLibrary;
        ImportSymbol  : TImportSymbol;
      begin
        AsmPrefix:='imp'+Lower(current_module.modulename^);
        idatalabnr:=0;
        SmartFilesCount:=0;
        SmartHeaderCount:=0;
        current_module.linkotherstaticlibs.add(current_module.importlibfilename,link_always);
        ObjWriter:=TARObjectWriter.CreateAr(current_module.importlibfilename);
        ObjOutput:=TPECoffObjOutput.Create(ObjWriter);
        for i:=0 to current_module.ImportLibraryList.Count-1 do
          begin
            ImportLibrary:=TImportLibrary(current_module.ImportLibraryList[i]);
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
         l1,l2,l3,l4 {$ifdef ARM} ,l5 {$endif ARM} : tasmlabel;
         importname : string;
         suffix : integer;
{$ifndef AARCH64}
         href : treference;
{$endif AARCH64}
         i,j  : longint;
         ImportLibrary : TImportLibrary;
         ImportSymbol  : TImportSymbol;
         ImportLabels  : TFPList;
      begin
        if current_asmdata.asmlists[al_imports]=nil then
          current_asmdata.asmlists[al_imports]:=TAsmList.create;

        if (target_asm.id in [as_i386_masm,as_i386_tasm,as_i386_nasmwin32]) then
          begin
            new_section(current_asmdata.asmlists[al_imports],sec_code,'',0);
            for i:=0 to current_module.ImportLibraryList.Count-1 do
              begin
                ImportLibrary:=TImportLibrary(current_module.ImportLibraryList[i]);
                for j:=0 to ImportLibrary.ImportSymbolList.Count-1 do
                  begin
                    ImportSymbol:=TImportSymbol(ImportLibrary.ImportSymbolList[j]);
                    current_asmdata.asmlists[al_imports].concat(tai_directive.create(asd_extern,ImportSymbol.Name));
                    current_asmdata.asmlists[al_imports].concat(tai_directive.create(asd_nasm_import,ImportSymbol.Name+' '+ImportLibrary.Name+' '+ImportSymbol.Name));
                  end;
              end;
            exit;
          end;

        for i:=0 to current_module.ImportLibraryList.Count-1 do
          begin
            ImportLibrary:=TImportLibrary(current_module.ImportLibraryList[i]);
            { align al_procedures for the jumps }
            new_section(current_asmdata.asmlists[al_imports],sec_code,'',sizeof(aint));
            { Get labels for the sections }
            current_asmdata.getjumplabel(l1);
            current_asmdata.getjumplabel(l2);
            current_asmdata.getjumplabel(l3);
            new_section(current_asmdata.asmlists[al_imports],sec_idata2,'',0);
            { pointer to procedure names }
            current_asmdata.asmlists[al_imports].concat(Tai_const.Create_rva_sym(l2));
            { two empty entries follow }
            current_asmdata.asmlists[al_imports].concat(Tai_const.Create_32bit(0));
            current_asmdata.asmlists[al_imports].concat(Tai_const.Create_32bit(0));
            { pointer to dll name }
            current_asmdata.asmlists[al_imports].concat(Tai_const.Create_rva_sym(l1));
            { pointer to fixups }
            current_asmdata.asmlists[al_imports].concat(Tai_const.Create_rva_sym(l3));

            { only create one section for each else it will
              create a lot of idata* }

            { first write the name references }
            new_section(current_asmdata.asmlists[al_imports],sec_idata4,'',0);
            current_asmdata.asmlists[al_imports].concat(Tai_label.Create(l2));

            ImportLabels:=TFPList.Create;
            ImportLabels.Count:=ImportLibrary.ImportSymbolList.Count;
            for j:=0 to ImportLibrary.ImportSymbolList.Count-1 do
              begin
                ImportSymbol:=TImportSymbol(ImportLibrary.ImportSymbolList[j]);

                current_asmdata.getjumplabel(templab);
                ImportLabels[j]:=templab;
                if ImportSymbol.Name<>'' then
                  begin
                    current_asmdata.asmlists[al_imports].concat(Tai_const.Create_rva_sym(TAsmLabel(ImportLabels[j])));
                    if target_info.system in systems_peoptplus then
                      current_asmdata.asmlists[al_imports].concat(Tai_const.Create_32bit(0));
                  end
                else
                  begin
                    if target_info.system in systems_peoptplus then
                      current_asmdata.asmlists[al_imports].concat(Tai_const.Create_64bit(int64($8000000000000000) or ImportSymbol.ordnr))
                    else
                      current_asmdata.asmlists[al_imports].concat(Tai_const.Create_32bit(longint($80000000) or ImportSymbol.ordnr));
                  end;
              end;
            { finalize the names ... }
            current_asmdata.asmlists[al_imports].concat(Tai_const.Create_32bit(0));
            if target_info.system in systems_peoptplus then
              current_asmdata.asmlists[al_imports].concat(Tai_const.Create_32bit(0));

            { then the addresses and create also the indirect jump }
            new_section(current_asmdata.asmlists[al_imports],sec_idata5,'',0);
            current_asmdata.asmlists[al_imports].concat(Tai_label.Create(l3));

            for j:=0 to ImportLibrary.ImportSymbolList.Count-1 do
              begin
                ImportSymbol:=TImportSymbol(ImportLibrary.ImportSymbolList[j]);
                if not ImportSymbol.IsVar then
                  begin
                    current_asmdata.getjumplabel(l4);
                  {$ifdef ARM}
                    current_asmdata.getjumplabel(l5);
                  {$endif ARM}
                    { create indirect jump and }
                    { place jump in al_procedures }
                    new_section(current_asmdata.asmlists[al_imports],sec_code,'',0);
                    if ImportSymbol.Name <> '' then
                      current_asmdata.asmlists[al_imports].concat(Tai_symbol.Createname_global(ImportSymbol.MangledName,AT_FUNCTION,0,voidcodepointertype))
                    else
                      current_asmdata.asmlists[al_imports].concat(Tai_symbol.Createname_global(ExtractFileName(ImportLibrary.Name)+'_index_'+tostr(ImportSymbol.ordnr),AT_FUNCTION,0,voidcodepointertype));
                    current_asmdata.asmlists[al_imports].concat(tai_function_name.create(''));
                  {$if defined(ARM)}
                    reference_reset_symbol(href,l5,0,sizeof(pint),[]);
                    current_asmdata.asmlists[al_imports].concat(Taicpu.op_reg_ref(A_LDR,NR_R12,href));
                    reference_reset_base(href,NR_R12,0,ctempposinvalid,sizeof(pint),[]);
                    current_asmdata.asmlists[al_imports].concat(Taicpu.op_reg_ref(A_LDR,NR_R15,href));
                    current_asmdata.asmlists[al_imports].concat(Tai_label.Create(l5));
                    reference_reset_symbol(href,l4,0,sizeof(pint),[]);
                    current_asmdata.asmlists[al_imports].concat(tai_const.create_sym_offset(href.symbol,href.offset));
                  {$elseif defined(AARCH64)}
                    { ToDo }
                    internalerror(2020033001);
                  {$else X86}
                    reference_reset_symbol(href,l4,0,sizeof(pint),[]);
{$ifdef X86_64}
                    href.base:=NR_RIP;
{$endif X86_64}

                    current_asmdata.asmlists[al_imports].concat(Taicpu.Op_ref(A_JMP,S_NO,href));
                    current_asmdata.asmlists[al_imports].concat(Tai_align.Create_op(4,$90));
                  {$endif X86}
                    { add jump field to al_imports }
                    new_section(current_asmdata.asmlists[al_imports],sec_idata5,'',0);
                    if (cs_debuginfo in current_settings.moduleswitches) then
                      begin
                        if ImportSymbol.MangledName<>'' then
                          begin
                            importname:='__imp_'+ImportSymbol.MangledName;
                            suffix:=0;
                            while assigned(current_asmdata.getasmsymbol(importname)) do
                              begin
                                inc(suffix);
                                importname:='__imp_'+ImportSymbol.MangledName+'_'+tostr(suffix);
                              end;
                            current_asmdata.asmlists[al_imports].concat(tai_symbol.createname(importname,AT_FUNCTION,4,voidcodepointertype));
                          end
                        else
                          begin
                            importname:='__imp_by_ordinal'+tostr(ImportSymbol.ordnr);
                            suffix:=0;
                            while assigned(current_asmdata.getasmsymbol(importname)) do
                              begin
                                inc(suffix);
                                importname:='__imp_by_ordinal'+tostr(ImportSymbol.ordnr)+'_'+tostr(suffix);
                              end;
                            current_asmdata.asmlists[al_imports].concat(tai_symbol.createname(importname,AT_FUNCTION,4,voidcodepointertype));
                          end;
                      end;
                     current_asmdata.asmlists[al_imports].concat(Tai_label.Create(l4));
                  end
                else
                  current_asmdata.asmlists[al_imports].concat(Tai_symbol.Createname_global(ImportSymbol.MangledName,AT_DATA,0,voidpointertype));
                current_asmdata.asmlists[al_imports].concat(Tai_const.Create_rva_sym(TAsmLabel(Importlabels[j])));
                if target_info.system in systems_peoptplus then
                  current_asmdata.asmlists[al_imports].concat(Tai_const.Create_32bit(0));
              end;
            { finalize the addresses }
            current_asmdata.asmlists[al_imports].concat(Tai_const.Create_32bit(0));
            if target_info.system in systems_peoptplus then
              current_asmdata.asmlists[al_imports].concat(Tai_const.Create_32bit(0));

            { finally the import information }
            new_section(current_asmdata.asmlists[al_imports],sec_idata6,'',0);
            for j:=0 to ImportLibrary.ImportSymbolList.Count-1 do
              begin
                ImportSymbol:=TImportSymbol(ImportLibrary.ImportSymbolList[j]);
                current_asmdata.asmlists[al_imports].concat(Tai_label.Create(TAsmLabel(ImportLabels[j])));
                { the ordinal number }
                current_asmdata.asmlists[al_imports].concat(Tai_const.Create_16bit(ImportSymbol.ordnr));
                current_asmdata.asmlists[al_imports].concat(Tai_string.Create(ImportSymbol.Name+#0));
                current_asmdata.asmlists[al_imports].concat(Tai_align.Create_op(2,0));
              end;
            { create import dll name }
            new_section(current_asmdata.asmlists[al_imports],sec_idata7,'',0);
            current_asmdata.asmlists[al_imports].concat(Tai_label.Create(l1));
            current_asmdata.asmlists[al_imports].concat(Tai_string.Create(ImportLibrary.Name+#0));
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
         if current_asmdata.asmlists[al_exports]=nil then
           current_asmdata.asmlists[al_exports]:=TAsmList.create;
         if EList_indexed=nil then
           EList_indexed:=tFPList.Create;
         if EList_nonindexed=nil then
           EList_nonindexed:=tFPList.Create;
      end;


    procedure TExportLibWin.exportvar(hp : texported_item);
      begin
         { same code used !! PM }
         exportprocedure(hp);
      end;

    var
      Gl_DoubleIndex:boolean;
      Gl_DoubleIndexValue:longint;

    function IdxCompare(Item1, Item2: Pointer): Integer;
      var
        I1:texported_item absolute Item1;
        I2:texported_item absolute Item2;
      begin
        Result:=I1.index-I2.index;
        if(Result=0)and(Item1<>Item2)then
         begin
          Gl_DoubleIndex:=true;
          Gl_DoubleIndexValue:=I1.index;
         end;
      end;


    procedure TExportLibWin.exportprocedure(hp : texported_item);
      begin
        if (eo_index in hp.options) and ((hp.index<=0) or (hp.index>$ffff)) then
          begin
           message1(parser_e_export_invalid_index,tostr(hp.index));
           exit;
          end;
        if eo_index in hp.options then
          EList_indexed.Add(hp)
        else
          EList_nonindexed.Add(hp);
      end;


    procedure TExportLibWin.exportfromlist(hp : texported_item);
      //formerly TExportLibWin.exportprocedure
      { must be ordered at least for win32 !! }
      var
        hp2 : texported_item;
      begin
        hp2:=texported_item(current_module._exports.first);
        while assigned(hp2) and
           (hp.name^>hp2.name^) do
          hp2:=texported_item(hp2.next);
        { insert hp there !! }
        if hp2=nil then
          current_module._exports.concat(hp)
        else
          begin
            if hp2.name^=hp.name^ then
              begin
                { this is not allowed !! }
                duplicatesymbol(hp.name^);
                exit;
              end;
            current_module._exports.insertbefore(hp,hp2);
          end;
      end;


    procedure TExportLibWin.generatelib;
      var
         ordinal_base,ordinal_max,ordinal_min : longint;
         current_index : longint;
         entries,named_entries : longint;
         name_label,dll_name_label,export_address_table : tasmlabel;
         export_name_table_pointers,export_ordinal_table : tasmlabel;
         hp,hp2 : texported_item;
         temtexport : TLinkedList;
         address_table,name_table_pointers,
         name_table,ordinal_table : TAsmList;
         i,autoindex,ni_high : longint;
         hole : boolean;
         asmsym : TAsmSymbol;
      begin
         Gl_DoubleIndex:=false;
         ELIst_indexed.Sort(@IdxCompare);

         if Gl_DoubleIndex then
           begin
             message1(parser_e_export_ordinal_double,tostr(Gl_DoubleIndexValue));
             FreeAndNil(EList_indexed);
             FreeAndNil(EList_nonindexed);
             exit;
           end;

         autoindex:=1;
         while EList_nonindexed.Count>0 do
          begin
           hole:=(EList_indexed.Count>0) and (texported_item(EList_indexed.Items[0]).index>1);
           if not hole then
            for i:=autoindex to pred(EList_indexed.Count) do
             if texported_item(EList_indexed.Items[i]).index-texported_item(EList_indexed.Items[pred(i)]).index>1 then
              begin
               autoindex:=succ(texported_item(EList_indexed.Items[pred(i)]).index);
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
           texported_item(EList_indexed.Items[pred(AutoIndex)]).index:=autoindex;
          end;
         FreeAndNil(EList_nonindexed);
         for i:=0 to pred(EList_indexed.Count) do
           exportfromlist(texported_item(EList_indexed.Items[i]));
         FreeAndNil(EList_indexed);

         if (target_asm.id in [as_i386_masm,as_i386_tasm,as_i386_nasmwin32]) then
          begin
            generatenasmlib;
            exit;
          end;

         hp:=texported_item(current_module._exports.first);
         if not assigned(hp) then
           exit;

         ordinal_max:=0;
         ordinal_min:=$7FFFFFFF;
         entries:=0;
         named_entries:=0;
         current_asmdata.getjumplabel(dll_name_label);
         current_asmdata.getjumplabel(export_address_table);
         current_asmdata.getjumplabel(export_name_table_pointers);
         current_asmdata.getjumplabel(export_ordinal_table);

         { count entries }
         while assigned(hp) do
           begin
              inc(entries);
              if (hp.index>ordinal_max) then
                ordinal_max:=hp.index;
              if (hp.index>0) and (hp.index<ordinal_min) then
                ordinal_min:=hp.index;
              if assigned(hp.name) then
                inc(named_entries);
              hp:=texported_item(hp.next);
           end;

         { no support for higher ordinal base yet !! }
         ordinal_base:=1;
         current_index:=ordinal_base;
         { we must also count the holes !! }
         entries:=ordinal_max-ordinal_base+1;

         new_section(current_asmdata.asmlists[al_exports],sec_edata,'',0);
         { create label to reference from main so smartlink will include
           the .edata section }
         current_asmdata.asmlists[al_exports].concat(Tai_symbol.Createname_global(make_mangledname('EDATA',current_module.localsymtable,''),AT_METADATA,0,voidpointertype));
         { export flags }
         current_asmdata.asmlists[al_exports].concat(Tai_const.Create_32bit(0));
         { date/time stamp }
         current_asmdata.asmlists[al_exports].concat(Tai_const.Create_32bit(0));
         { major version }
         current_asmdata.asmlists[al_exports].concat(Tai_const.Create_16bit(0));
         { minor version }
         current_asmdata.asmlists[al_exports].concat(Tai_const.Create_16bit(0));
         { pointer to dll name }
         current_asmdata.asmlists[al_exports].concat(Tai_const.Create_rva_sym(dll_name_label));
         { ordinal base normally set to 1 }
         current_asmdata.asmlists[al_exports].concat(Tai_const.Create_32bit(ordinal_base));
         { number of entries }
         current_asmdata.asmlists[al_exports].concat(Tai_const.Create_32bit(entries));
         { number of named entries }
         current_asmdata.asmlists[al_exports].concat(Tai_const.Create_32bit(named_entries));
         { address of export address table }
         current_asmdata.asmlists[al_exports].concat(Tai_const.Create_rva_sym(export_address_table));
         { address of name pointer pointers }
         current_asmdata.asmlists[al_exports].concat(Tai_const.Create_rva_sym(export_name_table_pointers));
         { address of ordinal number pointers }
         current_asmdata.asmlists[al_exports].concat(Tai_const.Create_rva_sym(export_ordinal_table));
         { the name }
         current_asmdata.asmlists[al_exports].concat(Tai_label.Create(dll_name_label));
         if st='' then
           current_asmdata.asmlists[al_exports].concat(Tai_string.Create(current_module.modulename^+target_info.sharedlibext+#0))
         else
           current_asmdata.asmlists[al_exports].concat(Tai_string.Create(st+target_info.sharedlibext+#0));

         {  export address table }
         address_table:=TAsmList.create;
         address_table.concat(Tai_align.Create_op(4,0));
         address_table.concat(Tai_label.Create(export_address_table));
         name_table_pointers:=TAsmList.create;
         name_table_pointers.concat(Tai_align.Create_op(4,0));
         name_table_pointers.concat(Tai_label.Create(export_name_table_pointers));
         ordinal_table:=TAsmList.create;
         ordinal_table.concat(Tai_align.Create_op(4,0));
         ordinal_table.concat(Tai_label.Create(export_ordinal_table));
         name_table:=TAsmList.Create;
         name_table.concat(Tai_align.Create_op(4,0));
         { write each address }
         hp:=texported_item(current_module._exports.first);
         while assigned(hp) do
           begin
              if eo_name in hp.options then
                begin
                   current_asmdata.getjumplabel(name_label);
                   name_table_pointers.concat(Tai_const.Create_rva_sym(name_label));
                   ordinal_table.concat(Tai_const.Create_16bit(hp.index-ordinal_base));
                   name_table.concat(Tai_align.Create_op(2,0));
                   name_table.concat(Tai_label.Create(name_label));
                   name_table.concat(Tai_string.Create(hp.name^+#0));
                end;
              hp:=texported_item(hp.next);
           end;
         { order in increasing ordinal values }
         { into temtexport list }
         temtexport:=TLinkedList.Create;
         hp:=texported_item(current_module._exports.first);
         while assigned(hp) do
           begin
              current_module._exports.remove(hp);
              hp2:=texported_item(temtexport.first);
              while assigned(hp2) and (hp.index>hp2.index) do
                hp2:=texported_item(hp2.next);
              if hp2=nil then
                temtexport.concat(hp)
              else
                temtexport.insertbefore(hp,hp2);
              hp:=texported_item(current_module._exports.first);
           end;

         { write the export adress table }
         current_index:=ordinal_base;
         hp:=texported_item(temtexport.first);
         while assigned(hp) do
           begin
              { fill missing values }
              while current_index<hp.index do
                begin
                   address_table.concat(Tai_const.Create_32bit(0));
                   inc(current_index);
                end;

              { symbol known? then get a new name }
              if assigned(hp.sym) and not (eo_no_sym_name in hp.options) then
                case hp.sym.typ of
                  staticvarsym :
                    asmsym:=current_asmdata.RefAsmSymbol(tstaticvarsym(hp.sym).mangledname,AT_DATA);
                  procsym :
                    asmsym:=current_asmdata.RefAsmSymbol(tprocdef(tprocsym(hp.sym).ProcdefList[0]).mangledname,AT_FUNCTION)
                  else
                    internalerror(200709272);
                end
              else
                asmsym:=current_asmdata.RefAsmSymbol(hp.name^,AT_DATA);
              address_table.concat(Tai_const.Create_rva_sym(asmsym));
              inc(current_index);
              hp:=texported_item(hp.next);
           end;

         current_asmdata.asmlists[al_exports].concatlist(address_table);
         current_asmdata.asmlists[al_exports].concatlist(name_table_pointers);
         current_asmdata.asmlists[al_exports].concatlist(ordinal_table);
         current_asmdata.asmlists[al_exports].concatlist(name_table);
         address_table.Free;
         name_table_pointers.free;
         ordinal_table.free;
         name_table.free;

         { the package support needs this data later on
           to create the import library }
         current_module._exports.concatlist(temtexport);
         temtexport.free;
      end;


    procedure TExportLibWin.generatenasmlib;
      var
         hp : texported_item;
         {p  : pchar;
         s  : string;}
      begin
         new_section(current_asmdata.asmlists[al_exports],sec_code,'',0);
         hp:=texported_item(current_module._exports.first);
         while assigned(hp) do
           begin
{             case hp.sym.typ of
               staticvarsym :
                 s:=tstaticvarsym(hp.sym).mangledname;
               procsym :
                 s:=tprocdef(tprocsym(hp.sym).ProcdefList[0]).mangledname;
               else
                 s:='';
             end;
             p:=strpnew(#9+'export '+s+' '+hp.Name^+' '+tostr(hp.index));
             current_asmdata.asmlists[al_exports].concat(tai_direct.create(p));}
             hp:=texported_item(hp.next);
           end;
      end;


{$if defined(x86_64) or defined(aarch64)}
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
        I       : longint;
        StackReserve : qword;
      begin
        WriteLLDResponseFile:=false;
        LinkRes:=TLinkRes.Create(outputexedir+Info.ResName,true);
        with LinkRes do
          begin
            case target_info.system of
              system_x86_64_win64:
                Add('/machine:x64');
              system_aarch64_win64:
                Add('/machine:arm64');
              else
                internalerror(2026092202);
            end;
            Add('/nodefaultlib');
            Add('/out:'+MaybeQuoted(OutputFile));
            if Info.ExtraOptions<>'' then
              Add(Info.ExtraOptions);
            if IsDLL then
              begin
                Add('/dll');
                Add('/noimplib');
                if apptype=app_gui then
                  Add('/entry:_DLLWinMainCRTStartup')
                else
                  Add('/entry:_DLLMainCRTStartup');
              end
            else if apptype=app_gui then
              Add('/entry:_WinMainCRTStartup')
            else
              Add('/entry:_mainCRTStartup');

            case apptype of
              app_native:
                SubsystemStr:='/subsystem:native';
              app_gui:
                SubsystemStr:='/subsystem:windows';
              else
                SubsystemStr:='/subsystem:console';
            end;
            if SetPESubSysVersionSetExplicitely then
              SubsystemStr:=SubsystemStr+','+tostr(pesubsysversionmajor)+'.'+tostr(pesubsysversionminor);
            Add(SubsystemStr);

            if create_smartlink_sections then
              Add('/opt:ref,noicf')
            else
              Add('/opt:noref,noicf');
            if cs_link_strip in current_settings.globalswitches then
              Add('/debug:none')
            else if cs_debuginfo in current_settings.moduleswitches then
              Add('/debug:dwarf');
            if RelocSection then
              Add('/fixed:no')
            else
              Add('/fixed');
            Add('/timestamp:0');
            if SetPEUserVersionSetExplicitely then
              Add('/version:'+tostr(peuserversionmajor)+'.'+tostr(peuserversionminor))
            else if dllversion<>'' then
              Add('/version:'+tostr(dllmajor)+'.'+tostr(dllminor));
            if SetPEOSVersionSetExplicitely then
              Add('/osversion:'+tostr(peosversionmajor)+'.'+tostr(peosversionminor))
            else if SetPESubSysVersionSetExplicitely then
              { lld-link otherwise copies an explicit subsystem version into
                the OS version fields as well. }
              Add('/osversion:6.0');
            if ImageBaseSetExplicity then
              Add('/base:0x'+HexStr(imagebase,SizeOf(imagebase)*2));
            StackReserve:=stacksize;
            if MaxStackSizeSetExplicity then
              StackReserve:=maxstacksize;
            if StackReserve<>0 then
              if MinStackSizeSetExplicity then
                Add('/stack:'+tostr(StackReserve)+','+tostr(minstacksize))
              else
                Add('/stack:'+tostr(StackReserve));
            if cs_link_map in current_settings.globalswitches then
              Add('/map:'+MaybeQuoted(ChangeFileExt(OutputFile,'.map')));

            HPath:=TCmdStrListItem(current_module.locallibrarysearchpath.First);
            while assigned(HPath) do
              begin
                Add('/libpath:'+MaybeQuoted(HPath.Str));
                HPath:=TCmdStrListItem(HPath.Next);
              end;
            HPath:=TCmdStrListItem(LibrarySearchPath.First);
            while assigned(HPath) do
              begin
                Add('/libpath:'+MaybeQuoted(HPath.Str));
                HPath:=TCmdStrListItem(HPath.Next);
              end;

            while not ObjectFiles.Empty do
              begin
                S:=ObjectFiles.GetFirst;
                if S<>'' then
                  AddFileName(MaybeQuoted(S));
              end;
            while not StaticLibFiles.Empty do
              begin
                S:=StaticLibFiles.GetFirst;
                if S<>'' then
                  AddFileName(MaybeQuoted(S));
              end;
            while not SharedLibFiles.Empty do
              begin
                S:=SharedLibFiles.GetFirst;
                if FindLibraryFile(S,target_info.staticClibprefix,target_info.staticClibext,S2) then
                  AddFileName(MaybeQuoted(S2))
                else
                  begin
                    if Pos(target_info.sharedlibprefix,S)=1 then
                      Delete(S,1,Length(target_info.sharedlibprefix));
                    I:=Pos(target_info.sharedlibext,S);
                    if I>0 then
                      Delete(S,I,Length(target_info.sharedlibext));
                    AddFileName(MaybeQuoted(target_info.staticClibprefix+S+target_info.staticClibext));
                  end;
              end;
            if not DefFile.Empty then
              begin
                DefFile.WriteFile;
                Add('/def:'+MaybeQuoted(DefFile.FName));
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
        if not(cs_link_nolink in current_settings.globalswitches) then
          Message1(exec_i_linking,OutputFile);
        if not WriteLLDResponseFile(OutputFile,IsDLL) then
          exit(false);
        CmdStr:='@'+MaybeQuoted(outputexedir+Info.ResName);
        DoLLDLink:=DoExec(FindUtil('lld-link'),CmdStr,true,false);
        if DoLLDLink and
           not(cs_link_nolink in current_settings.globalswitches) then
          DeleteFile(outputexedir+Info.ResName);
      end;


    function TExternalLinkerWin64LLD.MakeExecutable:boolean;
      begin
        MakeExecutable:=DoLLDLink(current_module.exefilename,false);
      end;


    function TExternalLinkerWin64LLD.MakeSharedLibrary:boolean;
      begin
        MakeSharedLibrary:=DoLLDLink(current_module.sharedlibfilename,true);
      end;


    procedure TExternalLinkerWin64LLD.InitSysInitUnitName;
      begin
        GlobalInitSysInitUnitName(self);
      end;
{$endif x86_64 or aarch64}




{****************************************************************************
                            TDLLScannerWin
****************************************************************************}

    procedure TDLLScannerWin.CheckDLLFunc(const dllname,funcname:string);
      var
        i : longint;
        ExtName : string;
      begin
        for i:=0 to current_module.dllscannerinputlist.count-1 do
          begin
            ExtName:=current_module.dllscannerinputlist.NameOfIndex(i);
            if (ExtName=funcname) then
              begin
                current_module.AddExternalImport(dllname,funcname,funcname,0,false,false);
                importfound:=true;
                current_module.dllscannerinputlist.Delete(i);
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
        if FindLibraryFile(binname,target_info.staticClibprefix,target_info.staticClibext,hs) then
          exit;
        { check if we can find the dll }
        hs:=binname;
        if ExtractFileExt(hs)='' then
          hs:=ChangeFileExt(hs,target_info.sharedlibext);
        if not FindDll(hs,dllname) then
          exit;
        importfound:=false;
        ReadDLLImports(dllname,@CheckDLLFunc);
        if importfound then
          current_module.dllscannerinputlist.Pack;
        result:=importfound;
      end;

{*****************************************************************************
                                     Initialize
*****************************************************************************}

initialization
{$if defined(x86_64) or defined(aarch64)}
  RegisterLinker(ld_lld_windows,TExternalLinkerWin64LLD);
{$endif x86_64 or aarch64}
{$ifdef x86_64}
  RegisterImport(system_x86_64_win64,TImportLibWin);
  RegisterExport(system_x86_64_win64,TExportLibWin);
  RegisterDLLScanner(system_x86_64_win64,TDLLScannerWin);
  RegisterRes(res_gnu_windres_info,TWinLikeResourceFile);
  RegisterRes(res_win64_gorc_info,TWinLikeResourceFile);
  RegisterTarget(system_x64_win64_info);
{$endif x86_64}
{$ifdef aarch64}
  RegisterImport(system_aarch64_win64,TImportLibWin);
  RegisterExport(system_aarch64_win64,TExportLibWin);
  RegisterDLLScanner(system_aarch64_win64,TDLLScannerWin);
  // ToDo?
  RegisterRes(res_gnu_windres_info,TWinLikeResourceFile);
  RegisterTarget(system_aarch64_win64_info);
{$endif aarch64}
end.
