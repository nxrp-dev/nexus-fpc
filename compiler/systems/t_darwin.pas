{
    Copyright (c) 1998-2002 by Peter Vreman (original Linux)
              (c) 2000      by Marco van de Voort (FreeBSD mods)

    This unit implements support import,export,link routines
    for the (i386)FreeBSD target

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

unit t_darwin;

{$i fpcdefs.inc}

interface

implementation

  uses
    SysUtils,
    CUtils,CFileUtl,CClasses,
    Verbose,Systems,GlobType,Globals,
    symconst,CScript,Triplet,
    FModule,aasmbase,aasmtai,AAsmData,aasmcpu,cpubase,SymSym,symdef,
    import,export,link,CompRsrc,i_darwin,expunix,
    cgutils,cgbase,cgobj,CPUInfo,ogbase;

  type
    TImportLibDarwin=class(TImportLib)
      procedure generatelib;override;
    end;

    TExportLibDarwin=class(TExportLibUnix)
      procedure setinitname(list: TAsmList; const s: string); override;
      procedure setfininame(list: TAsmList; const s: string); override;
    end;

    TLinkerDarwin=class(TExternalLinker)
    private
      LinkSymsFileName   : TCmdStr;
      function WriteFileList: TCmdStr;
      function GetDarwinCrt1ObjName(isdll: boolean): TCmdStr;
      Function GetDarwinPrtobjName(isdll: boolean): TCmdStr;
      function GetLinkArch: TCmdStr;
      function GetLinkVersion: TCmdStr;
      function GetSysroot: TCmdStr;
      function GetLibSearchPath: TCmdStr;
      function GetLibraries: TCmdStr;

    public
      constructor Create;override;
      procedure SetDefaultInfo;override;
      function  MakeExecutable:boolean;override;
      function  MakeSharedLibrary:boolean;override;
      procedure LoadPredefinedLibraryOrder; override;
      procedure InitSysInitUnitName; override;
      function postprocessexecutable(const fn : string;isdll:boolean):boolean;
    end;

{*****************************************************************************
                             TIMPORTLIBDARWIN
*****************************************************************************}

    procedure TImportLibDarwin.generatelib;
      begin
      end;


{*****************************************************************************
                             TEXPORTLIBDARWIN
*****************************************************************************}

    procedure TExportLibDarwin.setinitname(list: TAsmList; const s: string);
      begin
        new_section(list,sec_init_func,'',sizeof(PInt));
        list.concat(TAIConst.Createname(s,0));
      end;


    procedure TExportLibDarwin.setfininame(list: TAsmList; const s: string);
      begin
        new_section(list,sec_term_func,'',sizeof(PInt));
        list.concat(TAIConst.Createname(s,0));
      end;


{*****************************************************************************
                                  TLINKERBSD
*****************************************************************************}

    constructor TLinkerDarwin.Create;
      begin
        inherited;
        if not DontLinkStdlibPath Then
          LibrarySearchPath.AddLibraryPath(SysRootPath,'=/usr/lib',true)
      end;


    procedure TLinkerDarwin.SetDefaultInfo;
      var
        LdProgram : string;
      begin
        if cs_link_lld in CurrentSettings.GlobalSwitches then
          LdProgram:='ld64.lld'
        else
          LdProgram:='ld';

        with Info do
         begin
  {$ifndef cpu64bitaddr}
           { Set the size of the page at address zero to 64kb, so nothing
             is loaded below that address. This avoids problems with the
             strange Windows-compatible resource handling that assumes
             that addresses below 64kb do not exist.

             On 64bit systems, page zero is 4GB by default, so no problems
             there.
           }
           { In case of valgrind, don't do that, because it cannot deal with
             a custom pagezero size -- in general, this should not cause any
             problems because the resources are added at the end and most
             programs with problems that require Valgrind will have more
             than 60KB of data (first 4KB of address space is always invalid)
           }
           ExeCmd[1]:=LdProgram+' $PRTOBJ $TARGET $OPT $STATIC $GCSECTIONS $STRIP $MAP $LTO $ORDERSYMS $RPATH -L. -o $EXE $ARCH $VERSION $SYSROOT $LIBSEARCHPATH $FILELIST $LIBRARIES';
           if not(cs_gdb_valgrind in CurrentSettings.GlobalSwitches) then
             ExeCmd[1]:=ExeCmd[1]+' -pagezero_size 0x10000';
  {$else ndef cpu64bitaddr}
           ExeCmd[1]:=LdProgram+' $PRTOBJ $TARGET $OPT $STATIC $GCSECTIONS $STRIP $MAP $LTO $ORDERSYMS $RPATH -L. -o $EXE $ARCH $VERSION $SYSROOT $LIBSEARCHPATH $FILELIST $LIBRARIES';
  {$endif ndef cpu64bitaddr}
           if (AppType<>app_bundle) then
             DllCmd[1]:=LdProgram+' $PRTOBJ $TARGET $OPT $GCSECTIONS $MAP $LTO $ORDERSYMS $RPATH -dynamic -dylib -L. -o $EXE $ARCH $VERSION $SYSROOT $LIBSEARCHPATH $FILELIST $LIBRARIES'
           else
             DllCmd[1]:=LdProgram+' $PRTOBJ $TARGET $OPT $GCSECTIONS $MAP $LTO $ORDERSYMS $RPATH -dynamic -bundle -L. -o $EXE $ARCH $VERSION $SYRSROOT $LIBSEARCHPATH $FILELIST $LIBRARIES';
           DllCmd[2]:='strip -x $EXE';
           DynamicLinker:='';
         end;
      end;


    procedure TLinkerDarwin.LoadPredefinedLibraryOrder;
      begin
        // put your linkorder/linkalias overrides here.
        // Note: assumes only called when reordering/aliasing is used.
        LinkLibraryOrder.add('gcc','',15);
        LinkLibraryOrder.add('c','',50);
      end;


    procedure TLinkerDarwin.InitSysInitUnitName;
      begin
        SysInitUnit:='sysinit';
      end;


    function TLinkerDarwin.GetDarwinCrt1ObjName(isdll: boolean): TCmdStr;
      begin
        if not isdll then
          begin
            case TargetInfo.system of
                  system_x86_64_darwin:
                    begin
                      { 10.8 and later: no crt1.* }
                      if MacOSXVersionMin.RelationTo(10,8,0)>=0 then
                        exit('');
                      { x86: crt1.10.6.o -> crt1.10.5.o -> crt1.o }
                      if MacOSXVersionMin.RelationTo(10,6,0)>=0 then
                        exit('crt1.10.6.o');
                      if MacOSXVersionMin.RelationTo(10,5,0)>=0 then
                        exit('crt1.10.5.o');
                    end;
                  system_x86_64_iphonesim,
                  system_aarch64_iphonesim:
                    begin
                      { "recent versions" must not use anything (https://github.com/llvm-mirror/clang/commit/e6d04f3d152a22077022cf9287d4c538a0918ab0 )
                        What those recent versions could be, is anyone's guess. It
                        still seems to work with 8.1 and no longer with 8.3, so use
                        8.1 as a cut-off point }
                      if IPhoneOSVersionMin.RelationTo(8,1,0)>0 then
                        exit('');
                    end;
                  system_aarch64_ios,
                  system_aarch64_darwin:
                    { never anything }
                    exit('');
                  else
                    InternalError(2019050709);
            end;
            { nothing special -> default }
            result:='crt1.o';
          end
        else
          begin
            if (AppType=app_bundle) then
              begin
                case TargetInfo.system of
                  system_x86_64_darwin:
                    begin
                      { < 10.6: bundle1.o
                        >= 10.6: nothing }
                      if MacOSXVersionMin.RelationTo(10,6,0)>=0 then
                        exit('');
                    end;
                  system_aarch64_ios:
                    begin
                      { iOS: < 3.1: bundle1.o
                             >= 3.1: nothing }
                      if IPhoneOSVersionMin.RelationTo(3,1,0)>=0 then
                        exit('');
                    end;
                  system_x86_64_iphonesim,
                  system_aarch64_iphonesim:
                    begin
                      { see rule for crt1.o }
                      if IPhoneOSVersionMin.RelationTo(8,1,0)>0 then
                        exit('');
                    end;
                  system_aarch64_darwin:
                    exit('');
                  else
                    InternalError(2019050710);
                end;
                result:='bundle1.o';
              end
            else
              begin
                case TargetInfo.system of
                  system_x86_64_darwin:
                    begin
                      { >= 10.6: nothing
                        = 10.5: dylib1.10.5.o
                        < 10.5: dylib1.o
                      }
                      if MacOSXVersionMin.RelationTo(10,6,0)>=0 then
                        exit('');
                      if MacOSXVersionMin.RelationTo(10,5,0)>=0 then
                        exit('dylib1.10.5.o');
                    end;
                  system_aarch64_ios:
                    begin
                      { iOS: < 3.1: dylib1.o
                             >= 3.1: nothing }
                      if IPhoneOSVersionMin.RelationTo(3,1,0)>=0 then
                        exit('');
                    end;
                  system_x86_64_iphonesim,
                  system_aarch64_iphonesim:
                    begin
                      { see rule for crt1.o }
                      if IPhoneOSVersionMin.RelationTo(8,1,0)>0 then
                        exit('');
                    end;
                  system_aarch64_darwin:
                    exit('');
                  else
                    InternalError(2019050711);
                end;
                result:='dylib1.o';
              end;
          end;
      end;


    function TLinkerDarwin.GetDarwinPrtobjName(isdll: boolean): TCmdStr;
      var
        startupfile: TCmdStr;
      begin
        result:='';

        startupfile:=GetDarwinCrt1ObjName(isdll);
        if startupfile<>'' then
          begin
           if not LibrarySearchPath.FindFile(startupfile,false,result) then
             result:='/usr/lib/'+startupfile;
          end;
        result:=MaybeQuoted(result);
      end;


    function TLinkerDarwin.GetLinkArch: TCmdStr;
      begin
        case TargetInfo.system of
          system_x86_64_darwin,
          system_x86_64_iphonesim:
            result:='-arch x86_64';
          system_aarch64_ios,
          system_aarch64_iphonesim,
          system_aarch64_darwin:
            result:='-arch arm64';
          else
            InternalError(2014121801);
        end;
      end;


    function TLinkerDarwin.GetLinkVersion: TCmdStr;
      begin
        if MacOSXVersionMin.IsValid then
          begin
           { This does not depend on the target version but on the toolchain
             version, but we only know the former and not the latter }
           if MacOSXVersionMin.RelationTo(11,0,0)>=0 then
             result:='-macos_version_min '+MacOSXVersionMin.str
           else
             result:='-macosx_version_min '+MacOSXVersionMin.str;
          end
        else if IPhoneOSVersionMin.IsValid then
          begin
            if TargetInfo.system in [system_x86_64_iphonesim,system_aarch64_iphonesim] then
              result:='-ios_simulator_version_min '+IPhoneOSVersionMin.str
            else
              result:='-iphoneos_version_min '+IPhoneOSVersionMin.str;
          end
        else
          begin
            InternalError(2022090920)
          end;
      end;


    function TLinkerDarwin.GetSysroot: TCmdStr;
      begin
        if SysRootPath<>'' then
          begin
            result:='-syslibroot '+MaybeQuoted(SysRootPath);
          end
        else
          begin
            result:='';
          end;
      end;


    function TLinkerDarwin.GetLibSearchPath: TCmdStr;
      var
        HPath: TCmdStrListItem;
      begin
        result:='';
        HPath:=TCmdStrListItem(CurrentModule.LocalLibrarySearchPath.First);
        while Assigned(HPath) do
         begin
           result:=result+' '+MaybeQuoted('-L'+HPath.Str);
           HPath:=TCmdStrListItem(HPath.Next);
         end;
        HPath:=TCmdStrListItem(LibrarySearchPath.First);
        while Assigned(HPath) do
         begin
           result:=result+' '+MaybeQuoted('-L'+HPath.Str);
           HPath:=TCmdStrListItem(HPath.Next);
         end;

        HPath:=TCmdStrListItem(CurrentModule.LocalFrameworkSearchPath.First);
        while Assigned(HPath) do
         begin
           result:=result+' '+MaybeQuoted('-F'+HPath.Str);
           HPath:=TCmdStrListItem(HPath.Next);
         end;
        HPath:=TCmdStrListItem(FrameworkSearchPath.First);
        while Assigned(HPath) do
         begin
           result:=result+' '+MaybeQuoted('-F'+HPath.Str);
           HPath:=TCmdStrListItem(HPath.Next);
         end;
      end;


    function TLinkerDarwin.GetLibraries: TCmdStr;
      var
        s: TCmdStr;
        i: LongInt;
      begin
        result:='';
        while not SharedLibFiles.Empty do
          begin
            s:=SharedLibFiles.GetFirst;
            if (s<>'c') or ReOrderEntries then
              begin
                i:=Pos(TargetInfo.sharedlibext,s);
                if i>0 then
                  Delete(s,i,length(s));
                result:=result+' '+MaybeQuoted('-l'+s);
              end;
           { be sure that libc is the last lib }
           if not ReOrderEntries then
             begin
               result:=result+' -lc'
             end;
         end;

        while not FrameworkFiles.empty do
          begin
            result:=result+' -framework '+MaybeQuoted(FrameworkFiles.GetFirst);
          end;
      end;


    function TLinkerDarwin.WriteFileList: TCmdStr;
    Var
      FilesList    : TScript;
      s            : TCmdStr;
    begin
      if ReOrderEntries Then
         ExpandAndApplyOrder(SharedLibFiles);

      { main objectfiles and static libraries: in filelist file to avoid overflowing command line limit }
      result:=UniqueName(OutputExeDir+'linkfiles')+'.res';
      FilesList:=TScript.Create(result);
      while not ObjectFiles.Empty do
        begin
          s:=ObjectFiles.GetFirst;
          if s<>'' then
            begin
              s:=TargetFixFileName(s);
              FilesList.Add(s);
            end;
          { Write staticlibraries }
          while not StaticLibFiles.Empty do
            begin
              s:=StaticLibFiles.GetFirst;
              FilesList.Add(s)
            end;
        end;
      FilesList.writetodisk;
      FilesList.Free;
    end;


    function TLinkerDarwin.MakeExecutable:boolean;
    var
      binstr,
      cmdstr,
      mapstr,
      targetstr,
      extdbgbinstr,
      extdbgcmdstr,
      ltostr,
      asanstr,
      ordersymfile,
      linkfiles: TCmdStr;
      GCSectionsStr,
      StaticStr,
      StripStr,
      sanitizerLibraryDir: TCmdStr;
      success : boolean;
    begin
      if not(cs_link_nolink in CurrentSettings.GlobalSwitches) then
       Message1(exec_i_linking,CurrentModule.ExeFileName);

    { Create some replacements }
      StaticStr:='';
      StripStr:='';
      GCSectionsStr:='';
      mapstr:='';
      targetstr:='';
      ltostr:='';

      if (cs_link_map in CurrentSettings.GlobalSwitches) then
        mapstr:='-map '+MaybeQuoted(ChangeFileExt(CurrentModule.ExeFileName,'.map'));

      if (cs_link_staticflag in CurrentSettings.GlobalSwitches) then
        StaticStr:='-static';
      if (cs_link_strip in CurrentSettings.GlobalSwitches) then
        StripStr:='-x';

      if (cs_link_smart in CurrentSettings.GlobalSwitches) then
        GCSectionsStr:='-dead_strip -no_dead_strip_inits_and_terms';

      { add custom LTO library if using custom clang }
      if (cs_lto in CurrentSettings.ModuleSwitches) and
         not(cs_link_on_target in CurrentSettings.GlobalSwitches) and
         (UtilsDirectory<>'') and
         FileExists(UtilsDirectory+'/../lib/libLTO.dylib',false) then
        begin
          ltostr:='-lto_library '+MaybeQuoted(UtilsDirectory+'/../lib/libLTO.dylib');
        end;

      { Write symbol order file }
      ordersymfile:=WriteSymbolOrderFile;

    { Call linker }
      SplitBinCmd(Info.ExeCmd[1],binstr,cmdstr);
      Replace(cmdstr,'$EXE',MaybeQuoted(CurrentModule.ExeFileName));
      Replace(cmdstr,'$OPT',Info.ExtraOptions);
      Replace(cmdstr,'$TARGET',targetstr);
      Replace(cmdstr,'$MAP',mapstr);
      Replace(cmdstr,'$RES',MaybeQuoted(OutputExeDir+Info.ResName));
      Replace(cmdstr,'$LTO',ltostr);
      if ordersymfile<>'' then
        Replace(cmdstr,'$ORDERSYMS','-order_file '+MaybeQuoted(ordersymfile))
      else
        Replace(cmdstr,'$ORDERSYMS','');

      if AddSanitizerLibrariesAndGetSearchDir('darwin',sanitizerLibraryDir) then
        begin
          { also add the executable path as search path in case the asan
            library gets copied into the application bundle }
          Replace(cmdstr,'$RPATH','-rpath @executable_path -rpath '+MaybeQuoted(sanitizerLibraryDir))
        end
      else
        begin
          Replace(cmdstr,'$RPATH','');
        end;

      { Write list of files to link }
      linkfiles:=WriteFileList;

      Replace(cmdstr,'$STATIC',StaticStr);
      Replace(cmdstr,'$STRIP',StripStr);
      Replace(cmdstr,'$GCSECTIONS',GCSectionsStr);
      Replace(cmdstr,'$PRTOBJ',GetDarwinPrtobjName(false));
      Replace(cmdstr,'$ARCH', GetLinkArch);
      Replace(cmdstr,'$VERSION',GetLinkVersion);
      Replace(cmdstr,'$SYSROOT',GetSysroot);
      Replace(cmdstr,'$LIBSEARCHPATH',GetLibSearchPath);
      Replace(cmdstr,'$FILELIST','-filelist '+MaybeQuoted(linkfiles));
      Replace(cmdstr,'$LIBRARIES',GetLibraries);
      BinStr:=FindUtil(UtilsPrefix+BinStr);

      { create dsym file? }
      extdbgbinstr:='';
      extdbgcmdstr:='';
      if (TargetDbg.id in [dbg_dwarf3,dbg_dwarf4,dbg_dwarf5]) and
         (cs_link_separate_dbg_file in CurrentSettings.GlobalSwitches) then
        begin
          extdbgbinstr:=FindUtil(UtilsPrefix+'dsymutil');
          extdbgcmdstr:=MaybeQuoted(CurrentModule.ExeFileName);
        end;

      success:=DoExec(BinStr,CmdStr,true,false);
      if success and
         (extdbgbinstr<>'') then
        success:=DoExec(extdbgbinstr,extdbgcmdstr,false,false);

      { Remove ResponseFile }
      if (success) and not(cs_link_nolink in CurrentSettings.GlobalSwitches) then
       begin
         DeleteFile(OutputExeDir+Info.ResName);
         if ordersymfile<>'' then
           DeleteFile(ordersymfile);
         DeleteFile(linkfiles);
       end;

     { Post process }
     if success and not(cs_link_nolink in CurrentSettings.GlobalSwitches) then
       success:=PostProcessExecutable(CurrentModule.ExeFileName,false);

      MakeExecutable:=success;   { otherwise a recursive call to link method }
    end;


  function TLinkerDarwin.MakeSharedLibrary: boolean;
    var
      InitStr,
      FiniStr,
      binstr,
      cmdstr,
      mapstr,
      ltostr,
      ordersymfile,
      targetstr,
      extdbgbinstr,
      extdbgcmdstr,
      linkfiles,
      GCSectionsStr,
      sanitizerLibraryDir: TCmdStr;
      exportedsyms: text;
      success : boolean;
    begin
      MakeSharedLibrary:=false;
      GCSectionsStr:='';
      mapstr:='';
      ltostr:='';
      if not(cs_link_nolink in CurrentSettings.GlobalSwitches) then
       Message1(exec_i_linking,CurrentModule.SharedLibFileName);

      { Write symbol order file }
      ordersymfile:=WriteSymbolOrderFile;

      if (cs_link_smart in CurrentSettings.GlobalSwitches) then
        GCSectionsStr:='-dead_strip -no_dead_strip_inits_and_terms';

      if (cs_link_map in CurrentSettings.GlobalSwitches) then
        mapstr:='-map '+MaybeQuoted(ChangeFileExt(CurrentModule.SharedLibFileName,'.map'));

      { add custom LTO library if using custom clang }
      if (cs_lto in CurrentSettings.ModuleSwitches) and
         not(cs_link_on_target in CurrentSettings.GlobalSwitches) and
         (UtilsDirectory<>'') and
         FileExists(UtilsDirectory+'/../lib/libLTO.dylib',false) then
        begin
          ltostr:='-lto_library '+MaybeQuoted(UtilsDirectory+'/../lib/libLTO.dylib');
        end;

      targetstr:='';

      InitStr:='-init FPC_LIB_START';
      FiniStr:='-fini FPC_LIB_EXIT';

      { Call linker }
      SplitBinCmd(Info.DllCmd[1],binstr,cmdstr);
      Replace(cmdstr,'$EXE',MaybeQuoted(ExpandFileName(CurrentModule.SharedLibFileName)));
      Replace(cmdstr,'$OPT',Info.ExtraOptions);
      Replace(cmdstr,'$TARGET',targetstr);
      Replace(cmdstr,'$RES',MaybeQuoted(OutputExeDir+Info.ResName));
      Replace(cmdstr,'$INIT',InitStr);
      Replace(cmdstr,'$FINI',FiniStr);
      Replace(cmdstr,'$GCSECTIONS',GCSectionsStr);
      Replace(cmdstr,'$MAP',mapstr);
      Replace(cmdstr,'$LTO',ltostr);
      if ordersymfile<>'' then
        Replace(cmdstr,'$ORDERSYMS','-order_file '+MaybeQuoted(ordersymfile))
      else
        Replace(cmdstr,'$ORDERSYMS','');
      { add asan library if known }
      if AddSanitizerLibrariesAndGetSearchDir('darwin',sanitizerLibraryDir) then
        begin
          { also add the executable path as search path in case the asan
            library gets copied into the application bundle }
          Replace(cmdstr,'$RPATH','-rpath @executable_path -rpath '+MaybeQuoted(sanitizerLibraryDir))
        end
      else
        begin
          Replace(cmdstr,'$RPATH','');
        end;

      { Write list of files to link }
      linkfiles:=WriteFileList;

      Replace(cmdstr,'$PRTOBJ',GetDarwinPrtobjName(true));
      Replace(cmdstr,'$ARCH', GetLinkArch);
      Replace(cmdstr,'$VERSION',GetLinkVersion);
      Replace(cmdstr,'$SYSROOT',GetSysroot);
      Replace(cmdstr,'$LIBSEARCHPATH',GetLibSearchPath);
      Replace(cmdstr,'$FILELIST','-filelist '+MaybeQuoted(linkfiles));
      Replace(cmdstr,'$LIBRARIES',GetLibraries);
      BinStr:=FindUtil(UtilsPrefix+BinStr);

      { create dsym file? }
      extdbgbinstr:='';
      extdbgcmdstr:='';
      if (TargetDbg.id in [dbg_dwarf3,dbg_dwarf4,dbg_dwarf5]) and
         (cs_link_separate_dbg_file in CurrentSettings.GlobalSwitches) then
        begin
          extdbgbinstr:=FindUtil(UtilsPrefix+'dsymutil');
          extdbgcmdstr:=MaybeQuoted(CurrentModule.SharedLibFileName);
        end;

      LinkSymsFileName:='';
      if not TExportLibUnix(exportlib).exportedsymnames.empty then
        begin
          LinkSymsFileName:=UniqueName('linksyms')+'.fpc';
          assign(exportedsyms,OutputExeDir+LinkSymsFileName);
          rewrite(exportedsyms);
          repeat
            WriteLn(exportedsyms,TExportLibUnix(exportlib).exportedsymnames.GetFirst);
          until TExportLibUnix(exportlib).exportedsymnames.empty;
          close(exportedsyms);
          cmdstr:=cmdstr+' -exported_symbols_list '+MaybeQuoted(OutputExeDir+LinkSymsFileName);
        end;

      success:=DoExec(BinStr,cmdstr,true,false);
      if (success and
          (extdbgbinstr<>'') and
          (cs_link_nolink in CurrentSettings.GlobalSwitches)) then
        success:=DoExec(extdbgbinstr,extdbgcmdstr,false,false);

    { Strip the library ? }
      if success and (cs_link_strip in CurrentSettings.GlobalSwitches) then
       begin
         SplitBinCmd(Info.DllCmd[2],binstr,cmdstr);
         Replace(cmdstr,'$EXE',MaybeQuoted(CurrentModule.SharedLibFileName));
         success:=DoExec(FindUtil(UtilsPrefix+binstr),cmdstr,false,false);
       end;

    { Remove temporary files }
      if (success) and not(cs_link_nolink in CurrentSettings.GlobalSwitches) then
        begin
          DeleteFile(OutputExeDir+Info.ResName);
          if ordersymfile<>'' then
            DeleteFile(ordersymfile);
           if LinkSymsFileName<>'' then
             DeleteFile(OutputExeDir+LinkSymsFileName);
           DeleteFile(linkfiles);
        end;

      MakeSharedLibrary:=success;   { otherwise a recursive call to link method }
    end;


  function TLinkerDarwin.postprocessexecutable(const fn : string;isdll:boolean):boolean;
    begin
      Result:=PostProcessMachExecutable(fn,isdll);
    end;

{*****************************************************************************
                                     Initialize
*****************************************************************************}

initialization
  RegisterLinker(ld_darwin,TLinkerDarwin);
{$ifdef x86_64}
  RegisterImport(system_x86_64_darwin,TImportLibDarwin);
  RegisterExport(system_x86_64_darwin,TExportLibDarwin);
  RegisterTarget(system_x86_64_darwin_info);
  RegisterImport(system_x86_64_iphonesim,TImportLibDarwin);
  RegisterExport(system_x86_64_iphonesim,TExportLibDarwin);
  RegisterTarget(system_x86_64_iphonesim_info);
{$endif}
{$ifdef aarch64}
  RegisterImport(system_aarch64_ios,TImportLibDarwin);
  RegisterExport(system_aarch64_ios,TExportLibDarwin);
  RegisterTarget(system_aarch64_ios_info);
  RegisterImport(system_aarch64_darwin,TImportLibDarwin);
  RegisterExport(system_aarch64_darwin,TExportLibDarwin);
  RegisterTarget(system_aarch64_darwin_info);
  RegisterImport(system_aarch64_iphonesim,TImportLibDarwin);
  RegisterExport(system_aarch64_iphonesim,TExportLibDarwin);
  RegisterTarget(system_aarch64_iphonesim_info);
{$endif aarch64}

end.

