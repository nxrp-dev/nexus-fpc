{
    Copyright (c) 1998-2008 by Peter Vreman

    This unit implements support import,export,link routines
    for the (i386) Linux target

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
unit t_linux;

{$i fpcdefs.inc}

interface

  uses
    AAsmData,
    SymSym,
    import,export,expunix,link;

  type
    TImportLibLinux=class(TImportLib)
      procedure generatelib;override;
    end;

    TExportLibLinux=class(TExportLibUnix)
      procedure generatelib; override;
      procedure setfininame(list: TAsmList; const s: string); override;
    end;

    TLibcType=(libc5,glibc2,glibc21,uclibc);

    TLinkerLinux=class(TExternalLinker)
    private
      libctype: TLibcType;
      prtobj  : string[80];
      reorder : boolean;
      linklibc: boolean;
      Function  WriteResponseFile(isdll:boolean) : Boolean;
      function postprocessexecutable(const fn: string; isdll: boolean): boolean;
    public
      constructor Create;override;
      procedure SetDefaultInfo;override;
      procedure InitSysInitUnitName;override;
      function  MakeExecutable:boolean;override;
      function  MakeSharedLibrary:boolean;override;
      procedure LoadPredefinedLibraryOrder; override;
    end;


implementation

  uses
    SysUtils,
    CUtils,CFileUtl,CClasses,
    Verbose,Systems,GlobType,Globals,
    CScript,
    FModule,
    aasmbase,aasmtai,aasmcpu,cpubase,
    cgbase,ogbase,
    CompRsrc,NXPackageFile,
    ogelf,owar,
    i_linux
    ;

{*****************************************************************************
                               TIMPORTLIBLINUX
*****************************************************************************}

    procedure TImportLibLinux.generatelib;
      var
        i : LongInt;
        ImportLibrary : TImportLibrary;
      begin
        for i:=0 to CurrentModule.ImportLibraryList.Count-1 do
          begin
            ImportLibrary:=TImportLibrary(CurrentModule.ImportLibraryList[i]);
            CurrentModule.LinkOtherSharedLibs.add(ImportLibrary.Name,link_always);
          end;
      end;


{*****************************************************************************
                               TEXPORTLIBLINUX
*****************************************************************************}

    procedure TExportLibLinux.generatelib;
      var
        hp : TExportedItem;
        unitmodule : TModule;
        asmsym : TAsmSymbol;

      procedure retainexport(hp : TExportedItem);
        begin
          { The linker script keeps .fpc.n_links. References here retain
            otherwise unused smartlink exports. }
          new_section(CurrentAsmData.asmlists[al_globals],sec_fpc,'links',0);
          if hp.is_var then
            CurrentAsmData.asmlists[al_globals].concat(TAIConst.Createname(hp.name^,AT_DATA,0))
          else
            CurrentAsmData.asmlists[al_globals].concat(TAIConst.Createname(hp.name^,AT_FUNCTION,0));
        end;

      begin
        hp:=TExportedItem(CurrentModule.ExportList.first);
        while Assigned(hp) do
          begin
            asmsym:=CurrentAsmData.GetAsmSymbol(hp.name^);
            if Assigned(asmsym) and (asmsym.bind=AB_PRIVATE_EXTERN) then
              begin
                { A version script cannot export an ELF HIDDEN symbol.
                  This includes procedures exported under their own name. }
                asmsym.bind:=AB_GLOBAL;
                CurrentModule.Add_Public_AsmSym(asmsym);
              end;
            hp:=TExportedItem(hp.next);
          end;
        inherited generatelib;
        if CurrentModule.IsUnit then
          begin
            hp:=TExportedItem(CurrentModule.ExportList.first);
            while Assigned(hp) do
              begin
                { The alias now lives in the unit object. Only its name is
                  needed by subsequent links and by the PPU cache. }
                hp.internalname:=hp.name^;
                hp.sym:=nil;
                hp:=TExportedItem(hp.next);
              end;
            exit;
          end;

        hp:=TExportedItem(CurrentModule.ExportList.first);
        while Assigned(hp) do
          begin
            retainexport(hp);
            hp:=TExportedItem(hp.next);
          end;

        unitmodule:=TModule(Loaded_Units.first);
        while Assigned(unitmodule) do
          begin
            if unitmodule.IsUnit and not Assigned(unitmodule.package) then
              begin
                hp:=TExportedItem(unitmodule.ExportList.first);
                while Assigned(hp) do
                  begin
                    if Assigned(exportedsymnames.FindCase(hp.name^)) and
                       not CurrentModule.IsPackage then
                      duplicatesymbol(hp.name^)
                    else
                      begin
                        exportedsymnames.insert(hp.name^);
                        retainexport(hp);
                      end;
                    hp:=TExportedItem(hp.next);
                  end;
              end;
            unitmodule:=TModule(unitmodule.next);
          end;
      end;


    procedure TExportLibLinux.setfininame(list: TAsmList; const s: string);
      begin
        { the problem with not having a .fini section is that a finalization
          routine in regular code can get "smart" linked away -> reference it
          just like the debug info }
        new_section(list,sec_fpc,'links',0);
        list.concat(TAIConst.Createname(s,0));
        inherited setfininame(list,s);
      end;

{*****************************************************************************
                                  TLINKERLINUX
*****************************************************************************}

procedure SetupLibrarySearchPath;
begin
  if not DontLinkStdlibPath Then
    begin
{$ifdef x86_64}
      { some linuxes might not have the lib64 variants (Arch, LFS }
      { don't use PathExists checks, as we need to take sysroots and
        cross-compiling into account }
      LibrarySearchPath.AddLibraryPath(SysRootPath,'=/usr/X11R6/lib',true);
      LibrarySearchPath.AddLibraryPath(SysRootPath,'=/usr/X11R6/lib64',true);
      LibrarySearchPath.AddLibraryPath(SysRootPath,'=/usr/lib',true);
      LibrarySearchPath.AddLibraryPath(SysRootPath,'=/usr/lib64',true);
      { /lib64 should be the really first, so add it before everything else }
      LibrarySearchPath.AddLibraryPath(SysRootPath,'=/lib',true);
      LibrarySearchPath.AddLibraryPath(SysRootPath,'=/lib64',true);
{$else}
      LibrarySearchPath.AddLibraryPath(SysRootPath,'=/lib;=/usr/lib;=/usr/X11R6/lib',true);
{$endif x86_64}

{$ifdef x86_64}
      LibrarySearchPath.AddLibraryPath(SysRootPath,'=/usr/lib/x86_64-linux-gnu',true);
      LibrarySearchPath.AddLibraryPath(SysRootPath,'=/lib/x86_64-linux-gnu',true);
{$endif x86_64}
{$ifdef i386}
      LibrarySearchPath.AddLibraryPath(SysRootPath,'=/usr/lib/i386-linux-gnu',true);
      LibrarySearchPath.AddLibraryPath(SysRootPath,'=/lib/i386-linux-gnu',true);
{$endif i386}
{$ifdef aarch64}
      LibrarySearchPath.AddLibraryPath(SysRootPath,'=/usr/lib64',true);
      LibrarySearchPath.AddLibraryPath(SysRootPath,'=/usr/lib/aarch64-linux-gnu',true);
      LibrarySearchPath.AddLibraryPath(SysRootPath,'=/lib/aarch64-linux-gnu',true);
{$endif aarch64}
    end;
end;


{$ifdef i386}
  const defdynlinker='/lib/ld-linux.so.2';
{$endif}

{$ifdef x86_64}
  const defdynlinker='/lib64/ld-linux-x86-64.so.2';
{$endif x86_64}





{$ifdef aarch64}
const defdynlinker='/lib/ld-linux-aarch64.so.1';
{$endif aarch64}






procedure SetupDynlinker(out DynamicLinker:ShortString;out libctype:TLibcType);
begin
  {
    Search order:
    glibc 2.1+
    uclibc
    glibc 2.0
    If none is found (e.g. when cross compiling) glibc21 is assumed
  }
  if fileexists(SysRootPath+defdynlinker,false) then
    begin
      DynamicLinker:=defdynlinker;
{$ifdef i386}
      libctype:=glibc21;
{$else i386}
      libctype:=glibc2;
{$endif i386}
    end
  else if fileexists(SysRootPath+'/lib/ld-uClibc.so.0',false) then
    begin
      DynamicLinker:='/lib/ld-uClibc.so.0';
      libctype:=uclibc;
    end
{$ifdef i386}
  else if FileExists(SysRootPath+'/lib/ld-linux.so.1',false) then
    begin
      DynamicLinker:='/lib/ld-linux.so.1';
      libctype:=glibc2;
    end
{$endif i386}
  else
    begin
      { when no dyn. linker is found, we are probably
        cross compiling, so use the default dyn. linker }
      DynamicLinker:=defdynlinker;
      {
        the default c startup script is gcrt0.as on all platforms
        except i386
      }
{$ifdef i386}
      libctype:=glibc21;
{$else i386}
      libctype:=glibc2;
{$endif i386}
    end;
end;

function ModulesLinkToLibc:boolean;
var
  hp: TModule;
begin
  result:=false;
  { This is called very early, ImportLibraryList is not yet merged into linkothersharedlibs.
    The former contains library names qualified with prefix and suffix (coming from
    "external 'c' name 'foo' declarations), the latter contains raw names (from "$linklib c"
    directives). }
  hp:=TModule(Loaded_Units.first);
  while Assigned(hp) do
    begin
      result:=Assigned(hp.ImportLibraryList.find(TargetInfo.sharedClibprefix+'c'+TargetInfo.sharedClibext));
      if result then break;
      result:=hp.LinkOtherSharedLibs.find(TargetInfo.sharedClibprefix+'c'+TargetInfo.sharedClibext);
      if result then break;
      result:=hp.LinkOtherSharedLibs.find('c');
      if result then break;
      hp:=TModule(hp.next);
    end;
end;

Constructor TLinkerLinux.Create;
begin
  Inherited Create;
  SetupLibrarySearchPath;
end;

procedure TLinkerLinux.SetDefaultInfo;
{
  This will also detect which libc version will be used
}
var
  target_opt: string;
  emulation_opt: string;
  platformopt: string;
  LdProgram: string;
begin
  target_opt:='';
  emulation_opt:='';
  platformopt:='';
  LdProgram:='';
{$ifdef i386}
  target_opt:=' -b elf32-i386';
  emulation_opt:=' -m elf_i386';
{$endif}
{$ifdef x86_64}
  target_opt:=' -b elf64-x86-64';
  emulation_opt:=' -m elf_x86_64';
{$endif}
 {unknown :( }
{$ifdef aarch64}   target_opt:='';{$endif} {unknown :( }

  if cs_link_lld in CurrentSettings.GlobalSwitches then
    begin
      LdProgram:='ld.lld';
      target_opt:=' -b elf';
    end
  else
    LdProgram:='ld';

  with Info do
   begin
     ExeCmd[1]:=LdProgram+target_opt+emulation_opt+platformopt+' $OPT $DYNLINK $STATIC $GCSECTIONS $STRIP $MAP $LTO $RPATH -L. -o $EXE';
     DllCmd[1]:=LdProgram+target_opt+emulation_opt+platformopt+' $OPT $INIT $FINI $SONAME $MAP $LTO $RPATH -shared $GCSECTIONS -L. -o $EXE';
     { when we want to cross-link we need to override default library paths;
       when targeting binutils 2.19 or later, we use the "INSERT" command to
       augment the default linkerscript, which also requires -T (normally that
       option means "completely replace the default linkerscript) }
     if not(cs_link_pre_binutils_2_19 in CurrentSettings.GlobalSwitches) or
       (length(SysRootPath)>0) then
       begin
         ExeCmd[1]:=ExeCmd[1]+' -T';
         DllCmd[1]:=DllCmd[1]+' -T';
       end;
     ExeCmd[1]:=ExeCmd[1]+' $RES';
     DllCmd[1]:=DllCmd[1]+' $RES';
     DllCmd[2]:='strip --strip-unneeded $EXE';
     ExtDbgCmd[1]:='objcopy --only-keep-debug $EXE $DBG';
     ExtDbgCmd[2]:='objcopy "--add-gnu-debuglink=$DBGX" $EXE';
     ExtDbgCmd[3]:='strip --strip-unneeded $EXE';

     SetupDynlinker(DynamicLinker,libctype);
   end;
end;


procedure TLinkerLinux.LoadPredefinedLibraryOrder;
// put your linkorder/linkalias overrides here.
// Note: assumes only called when reordering/aliasing is used.
Begin
   if not (cs_link_no_default_lib_order in  CurrentSettings.GlobalSwitches) Then
        Begin
          LinkLibraryOrder.add('gcc','',15);
          LinkLibraryOrder.add('c','',100);
          LinkLibraryOrder.add('dl','',140);
          LinkLibraryOrder.add('pthread','',160);
         end;
End;

type
  TLibCNames=array [TLibcType] of string[8];

const                     { libc5    glibc2   glibc21   uclibc }
  cprtnames: TLibCNames = ('cprt0', 'cprt0', 'cprt21', 'ucprt0');
  csinames: TLibCNames  = ('si_c',  'si_c',  'si_c21', 'si_uc');

  defprtnames: array[boolean] of string[8] = ('prt0',  'dllprt0');
  defsinames: array[boolean] of string[8]  = ('si_prc','si_dll');

Procedure TLinkerLinux.InitSysInitUnitName;
begin
  linklibc:=ModulesLinkToLibc;
  reorder:=linklibc and ReOrderEntries;
  sysinitunit:=defsinames[CurrentModule.IsLibrary];
  prtobj:=defprtnames[CurrentModule.IsLibrary];

  if CurrentModule.IsLibrary then
    exit;
  if linklibc then
    begin
      prtobj:=cprtnames[libctype];
      sysinitunit:=csinames[libctype];
    end;
end;

Function TLinkerLinux.WriteResponseFile(isdll:boolean) : Boolean;
Var
  linkres      : TLinkRes;
  i            : LongInt;
  HPath        : TCmdStrListItem;
  s,s1,s2      : TCmdStr;
  found1,
  found2       : boolean;
  linksToSharedLibFiles, libraryadded: boolean;
begin
  result:=False;
  { Open link.res file }
  LinkRes:=TLinkRes.Create(OutputExeDir+Info.ResName,true);
  with linkres do
    begin
      { Write path to search libraries }
      HPath:=TCmdStrListItem(CurrentModule.LocalLibrarySearchPath.First);
      while Assigned(HPath) do
       begin
         Add('SEARCH_DIR("'+HPath.Str+'")');
         HPath:=TCmdStrListItem(HPath.Next);
       end;
      HPath:=TCmdStrListItem(LibrarySearchPath.First);
      while Assigned(HPath) do
       begin
         Add('SEARCH_DIR("'+HPath.Str+'")');
         HPath:=TCmdStrListItem(HPath.Next);
       end;

      { force local symbol resolution (i.e., inside the shared }
      { library itself) for all non-exported symbols, otherwise}
      { several RTL symbols of FPC-compiled shared libraries   }
      { will be bound to those of a single shared library or   }
      { to the main program                                    }
      if (isdll) then
        begin
          add('VERSION');
          add('{');
          add('  {');
          if not TExportLibUnix(exportlib).exportedsymnames.empty then
            begin
              add('    global:');
              repeat
                add('      '+TExportLibUnix(exportlib).exportedsymnames.GetFirst+';');
              until TExportLibUnix(exportlib).exportedsymnames.empty;
            end;
          add('    local:');
          add('      *;');
          add('  };');
          add('}');
        end;

      StartSection('INPUT(');
      { add objectfiles, start with prt0 always }
      if not (TargetInfo.system in systems_internal_sysinit) and (prtobj<>'') then
       AddFileName(MaybeQuoted(FindObjectFile(prtobj,'',false)));
      { try to add crti and crtbegin if linking to C }
      if linklibc and (libctype<>uclibc) then
       begin
         { crti.o must come first }
         if LibrarySearchPath.FindFile('crti.o',false,s) then
           AddFileName(s)
         else
           Message1(exec_w_init_file_not_found,'crti.o');

         { then the crtbegin* }
         if (cs_create_pic in CurrentSettings.ModuleSwitches)
         then
           begin
             if LibrarySearchPath.FindFile('crtbeginS.o',false,s) then
               AddFileName(s)
             else
               Message1(exec_w_init_file_not_found,'crtbeginS.o');
           end
         else
           if (cs_link_staticflag in CurrentSettings.GlobalSwitches) then
             begin
               if LibrarySearchPath.FindFile('crtbeginT.o',false,s) then
                 AddFileName(s)
               else
                 Message1(exec_w_init_file_not_found,'crtbeginT.o');
             end
           else if LibrarySearchPath.FindFile('crtbegin.o',false,s) then
             AddFileName(s)
           else
             Message1(exec_w_init_file_not_found,'crtbegin.o');
       end;
      { main objectfiles }
      while not ObjectFiles.Empty do
       begin
         s:=ObjectFiles.GetFirst;
         if s<>'' then
          AddFileName(MaybeQuoted(s));
       end;
      EndSection(')');

      { Write staticlibraries }
      if not StaticLibFiles.Empty then
       begin
         Add('GROUP(');
         While not StaticLibFiles.Empty do
          begin
            S:=StaticLibFiles.GetFirst;
            AddFileName(MaybeQuoted(s))
          end;
         Add(')');
       end;

      // we must reorder here because the result could empty sharedlibfiles
      if reorder Then
        ExpandAndApplyOrder(SharedLibFiles);
      // after this point addition of shared libs not allowed.

      { Write sharedlibraries like -l<lib>, also add the needed dynamic linker
        here to be sure that it gets linked this is needed for glibc2 systems (PFV) }
      if isdll and not linklibc then
       begin
         Add('INPUT(');
         Add(SysRootPath+info.DynamicLinker);
         Add(')');
       end;
      linksToSharedLibFiles := not SharedLibFiles.Empty;

      if not SharedLibFiles.Empty then
       begin

         if (SharedLibFiles.Count<>1) or
            (TCmdStrListItem(SharedLibFiles.First).Str<>'c') or
            reorder then
           begin
             libraryadded:=false;
             Add('INPUT(');
             While not SharedLibFiles.Empty do
               begin
                 S:=SharedLibFiles.GetFirst;
                 if (s<>'c') or reorder then
                  begin
                    if ExtractFileExt(S)=NexusPackageLibraryExtension then
                      begin
                        if S[1]<>':' then S:=':'+S;
                        Add('-l'+S);
                      end
                    else
                      begin
                        i:=Pos(TargetInfo.sharedlibext,S);
                        if i>0 then
                          Delete(S,i,255);
                        Add('-l'+S);
                      end;
                    libraryadded:=true;
                  end
                 else
                   linklibc:=true;
               end;
             { link explicitly against the dyn. linker in case we are using section threadvars and
               if we link against any other library. We need __tls_get_addr from the dyn. linker in this case.
               This does not hurt as in case we use a dyn. library we depend on the dyn. linker anyways.

               All this does not apply if we link anyways against libc }
             if libraryadded and not(linklibc) and not(isdll) and (tf_section_threadvars in TargetInfo.flags) then
               Add('-l:'+ExtractFileName(defdynlinker));
             Add(')');
           end
         else
           linklibc:=true;
         if (cs_link_staticflag in CurrentSettings.GlobalSwitches) or
            (linklibc and not reorder) then
           begin
             Add('GROUP(');
             { when we have -static for the linker the we also need libgcc }
             if (cs_link_staticflag in CurrentSettings.GlobalSwitches) then
               begin
                 Add('-lgcc');
                 if LibrarySearchPath.FindFile('libgcc_eh.a',false,s1) then
                   Add('-lgcc_eh');
               end;
             { be sure that libc is the last lib }
             if linklibc and not reorder then
               Add('-lc');
             Add(')');
           end;
       end;

      { objects which must be at the end }
      if linklibc and (libctype<>uclibc) then
       begin
         if (cs_create_pic in CurrentSettings.ModuleSwitches)
         then
           begin
             found1:=LibrarySearchPath.FindFile('crtendS.o',false,s1);
             if not(found1) then
               Message1(exec_w_init_file_not_found,'crtendS.o');
           end
         else
           begin
             found1:=LibrarySearchPath.FindFile('crtend.o',false,s1);
             if not(found1) then
               Message1(exec_w_init_file_not_found,'crtend.o');
           end;

         found2:=LibrarySearchPath.FindFile('crtn.o',false,s2);
         if not(found2) then
           Message1(exec_w_init_file_not_found,'crtn.o');
         if found1 or found2 then
          begin
            Add('INPUT(');
            if found1 then
             AddFileName(s1);
            if found2 then
             AddFileName(s2);
            Add(')');
          end;
       end;

      { Entry point. Only needed for executables, as for shared libraries we use
        the -init command line option instead

       The "ENTRY" linkerscript command does not have any effect when augmenting
       a linker script, so use the command line parameter instead }
      if (not isdll) then
        if (linksToSharedLibFiles and not linklibc) then
          info.ExeCmd[1]:=info.ExeCmd[1]+' -e _dynamic_start'
        else
          info.ExeCmd[1]:=info.ExeCmd[1]+' -e _start';

      add('SECTIONS');
      add('{');
      if not(cs_link_pre_binutils_2_19 in CurrentSettings.GlobalSwitches) then
        { we can't use ".data", as that would hide the .data from the
          original linker script in combination with the INSERT at the end }
        add('  .fpcdata           :')
      else
        add('  .data           :');
      add('  {');
      add('    KEEP (*(.fpc .fpc.n_version .fpc.n_links))');
      add('  }');
      if not(cs_debuginfo in CurrentSettings.ModuleSwitches) and
         not(tf_use_psabieh in TargetInfo.flags) then
        add('  /DISCARD/ : {*(.debug_frame)}');
      add('  .threadvar : { *(.threadvar .threadvar.* .gnu.linkonce.tv.*) }');
      add('}');
      { this "INSERT" means "merge into the original linker script, even if
        -T is used" }
      if not(cs_link_pre_binutils_2_19 in CurrentSettings.GlobalSwitches) then
        add('INSERT AFTER .data;');
      { Write and Close response }
      writetodisk;
      Free;
    end;

  WriteResponseFile:=True;
end;


function TLinkerLinux.MakeExecutable:boolean;
var
  i : LongInt;
  binstr,
  cmdstr,
  mapstr,
  ltostr,
  rpathstr,
  sanitizerLibraryDir, s: TCmdStr;
  success : boolean;
  DynLinkStr : AnsiString;
  GCSectionsStr,
  StaticStr,
  StripStr   : string[40];
begin
  if not(cs_link_nolink in CurrentSettings.GlobalSwitches) then
   Message1(exec_i_linking,CurrentModule.ExeFileName);

{ Create some replacements }
  StaticStr:='';
  StripStr:='';
  GCSectionsStr:='';
  DynLinkStr:='';
  mapstr:='';
  ltostr:='';
  rpathstr:='';
  if (cs_link_staticflag in CurrentSettings.GlobalSwitches) then
   StaticStr:='-static';
  if (cs_link_strip in CurrentSettings.GlobalSwitches) and
     not(cs_link_separate_dbg_file in CurrentSettings.GlobalSwitches) then
   StripStr:='-s';
  if (cs_link_map in CurrentSettings.GlobalSwitches) then
   mapstr:='-Map '+MaybeQuoted(ChangeFileExt(CurrentModule.ExeFileName,'.map'));
  if (cs_link_smart in CurrentSettings.GlobalSwitches) and
     create_smartlink_sections then
   GCSectionsStr:='--gc-sections';
  If (Info.DynamicLinker<>'') and (not SharedLibFiles.Empty) then
   begin
     DynLinkStr:='--dynamic-linker='+Info.DynamicLinker;
     if CShared then
       DynLinkStr:=DynLinkStr+' --shared ';
     if RLinkPath<>'' then
       DynLinkStr:=DynLinkStr+' --rpath-link '+RLinkPath;
   End;

  { add custom LTO library if using custom clang }
  if (cs_lto in CurrentSettings.ModuleSwitches) and
     not(cs_link_on_target in CurrentSettings.GlobalSwitches) and
     (UtilsDirectory<>'') and
     FileExists(UtilsDirectory+'/../lib/LLVMgold.so',true) then
    begin
      ltostr:='-plugin '+MaybeQuoted(UtilsDirectory+'/../lib/LLVMgold.so ');
    end;

  if AddSanitizerLibrariesAndGetSearchDir('linux',sanitizerLibraryDir) then
    begin
      rpathstr:='-rpath '+MaybeQuoted(sanitizerLibraryDir);
    end;

{ Write used files and libraries }
  WriteResponseFile(false);

{ Call linker }
  SplitBinCmd(Info.ExeCmd[1],binstr,cmdstr);
  Replace(cmdstr,'$EXE',MaybeQuoted(CurrentModule.ExeFileName));
  Replace(cmdstr,'$OPT',Info.ExtraOptions);
  Replace(cmdstr,'$RES',MaybeQuoted(OutputExeDir+Info.ResName));
  Replace(cmdstr,'$STATIC',StaticStr);
  Replace(cmdstr,'$STRIP',StripStr);
  Replace(cmdstr,'$GCSECTIONS',GCSectionsStr);
  Replace(cmdstr,'$DYNLINK',DynLinkStr);
  Replace(cmdstr,'$MAP',mapstr);
  Replace(cmdstr,'$LTO',ltostr);
  Replace(cmdstr,'$RPATH',rpathstr);

  { create dynamic symbol table? }
  if HasExports then
    cmdstr:=cmdstr+' -E';

  { create eh_frame_hdr section? }
  if tf_use_psabieh in TargetInfo.flags then
    cmdstr:=cmdstr+ ' --eh-frame-hdr';

  if cs_large in CurrentSettings.GlobalSwitches then
    cmdstr:=cmdstr+' --no-relax';

  s:=FindUtil(UtilsPrefix+BinStr+'.bfd',false);
  if FileExists(s, True) then
    binstr:=s
  else
    { fallback to ld for very old or custom binutils }
    binstr:=FindUtil(UtilsPrefix+BinStr);

  success:=DoExec(binstr,CmdStr,true,false);

  { Create external .dbg file with debuginfo }
  if success and (cs_link_separate_dbg_file in CurrentSettings.GlobalSwitches) then
    begin
      for i:=1 to 3 do
        begin
          SplitBinCmd(Info.ExtDbgCmd[i],binstr,cmdstr);
          Replace(cmdstr,'$EXE',MaybeQuoted(CurrentModule.ExeFileName));
          Replace(cmdstr,'$DBGFN',MaybeQuoted(extractfilename(CurrentModule.DbgFileName)));
          Replace(cmdstr,'$DBGX',CurrentModule.DbgFileName);
          Replace(cmdstr,'$DBG',MaybeQuoted(CurrentModule.DbgFileName));
          success:=DoExec(FindUtil(UtilsPrefix+BinStr),CmdStr,true,false);
          if not success then
            break;
        end;
    end;

  { Remove ResponseFile }
  if (success) and not(cs_link_nolink in CurrentSettings.GlobalSwitches) then
   DeleteFile(OutputExeDir+Info.ResName);

  { Post process,
    as it only writes sections sizes so far, do this only if V_Info is set }
  if success and CheckVerbosity(VInfo) and not(cs_link_nolink in CurrentSettings.GlobalSwitches) then
    { do not change success here as we are only writing some info, so if this fails, it does not matter }
    { success:= }PostProcessExecutable(CurrentModule.ExeFileName,false);

  MakeExecutable:=success;   { otherwise a recursive call to link method }
end;


Function TLinkerLinux.MakeSharedLibrary:boolean;
var
  InitStr,
  FiniStr,
  GCSectionsStr,
  SoNameStr : string[80];
  binstr,
  cmdstr,
  mapstr,
  ltostr,
  rpathstr,
  sanitizerLibraryDir: TCmdStr;
  success : boolean;
begin
  MakeSharedLibrary:=false;
  mapstr:='';
  ltostr:='';
  rpathstr:='';
  if not(cs_link_nolink in CurrentSettings.GlobalSwitches) then
   Message1(exec_i_linking,CurrentModule.SharedLibFileName);
  if (cs_link_smart in CurrentSettings.GlobalSwitches) and
     create_smartlink_sections then
   GCSectionsStr:='--gc-sections'
  else
    GCSectionsStr:='';

{ Write used files and libraries }
  WriteResponseFile(true);

 { Create some replacements }
 { note: linux does not use exportlib.initname/fininame due to the custom startup code }
  if CurrentModule.IsPackage then
    begin
      { Pascal package lifecycle belongs to the shared manager, not ld.so. }
      InitStr:='';
      FiniStr:='';
    end
  else
    begin
      InitStr:='-init FPC_SHARED_LIB_START';
      FiniStr:='-fini FPC_LIB_EXIT';
    end;
  SoNameStr:='-soname '+ExtractFileName(CurrentModule.SharedLibFileName);
  if (cs_link_map in CurrentSettings.GlobalSwitches) then
     mapstr:='-Map '+MaybeQuoted(ChangeFileExt(CurrentModule.SharedLibFileName,'.map'));

  { add custom LTO library if using custom clang }
  if (cs_lto in CurrentSettings.ModuleSwitches) and
     not(cs_link_on_target in CurrentSettings.GlobalSwitches) and
     (UtilsDirectory<>'') and
     FileExists(UtilsDirectory+'/../lib/LLVMgold.so',true) then
    begin
      ltostr:='-plugin '+MaybeQuoted(UtilsDirectory+'/../lib/LLVMgold.so ');
    end;

  if AddSanitizerLibrariesAndGetSearchDir('linux',sanitizerLibraryDir) then
    begin
      rpathstr:='-rpath '+MaybeQuoted(sanitizerLibraryDir)
    end;

 { Call linker }
  SplitBinCmd(Info.DllCmd[1],binstr,cmdstr);
  Replace(cmdstr,'$EXE',MaybeQuoted(CurrentModule.SharedLibFileName));
  Replace(cmdstr,'$OPT',Info.ExtraOptions);
  Replace(cmdstr,'$RES',MaybeQuoted(OutputExeDir+Info.ResName));
  Replace(cmdstr,'$INIT',InitStr);
  Replace(cmdstr,'$FINI',FiniStr);
  Replace(cmdstr,'$SONAME',SoNameStr);
  Replace(cmdstr,'$MAP',mapstr);
  Replace(cmdstr,'$LTO',ltostr);
  Replace(cmdstr,'$RPATH',rpathstr);
  Replace(cmdstr,'$GCSECTIONS',GCSectionsStr);
  if CurrentModule.IsPackage then
    { Owned definitions have one canonical address and per-image tables must
      not be preempted by equally named tables in a dependency. }
    cmdstr:=cmdstr+' -Bsymbolic -z defs -z text -z relro -z now';
  success:=DoExec(FindUtil(UtilsPrefix+binstr),cmdstr,true,false);

{ Strip the library ? }
  if success and (cs_link_strip in CurrentSettings.GlobalSwitches) then
   begin
     { only remove non global symbols and debugging info for a library }
     Info.DllCmd[2]:='strip --discard-all --strip-debug $EXE';
     SplitBinCmd(Info.DllCmd[2],binstr,cmdstr);
     Replace(cmdstr,'$EXE',MaybeQuoted(CurrentModule.SharedLibFileName));
     success:=DoExec(FindUtil(UtilsPrefix+binstr),cmdstr,true,false);
   end;

{ Remove ResponseFile }
  if (success) and not(cs_link_nolink in CurrentSettings.GlobalSwitches) then
   DeleteFile(OutputExeDir+Info.ResName);

  MakeSharedLibrary:=success;   { otherwise a recursive call to link method }
end;


function TLinkerLinux.postprocessexecutable(const fn : string;isdll:boolean):boolean;
  begin
    Result:=PostProcessELFExecutable(fn,isdll);
  end;


{*****************************************************************************
                                  Initialize
*****************************************************************************}

initialization
  RegisterLinker(ld_linux,TLinkerLinux);
{$ifdef i386}
  RegisterImport(system_i386_linux,TImportLibLinux);
  RegisterExport(system_i386_linux,TExportLibLinux);
  RegisterTarget(system_i386_linux_info);
{$endif i386}
{$ifdef x86_64}
  RegisterImport(system_x86_64_linux,TImportLibLinux);
  RegisterExport(system_x86_64_linux,TExportLibLinux);
  RegisterTarget(system_x86_64_linux_info);
{$endif x86_64}
{$ifdef aarch64}
  RegisterImport(system_aarch64_linux,TImportLibLinux);
  RegisterExport(system_aarch64_linux,TExportLibLinux);
  RegisterTarget(system_aarch64_linux_info);
{$endif aarch64}
end.
