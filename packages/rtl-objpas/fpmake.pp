{$ifndef ALLPACKAGES}
{$mode objfpc}{$H+}
program fpmake;

uses {$ifdef unix}cthreads,{$endif} fpmkunit;
{$endif ALLPACKAGES}

procedure add_rtl_objpas(const ADirectory: string);

Const
  // All Unixes have full set of KVM+Crt in unix/ except QNX which is not
  // in workable state atm.
  UnixLikes = AllUnixOSes -[QNX]; // qnx never was active in 2.x afaik

//  AllUnixOSes  = [Linux,FreeBSD,NetBSD,OpenBSD,Darwin,QNX,BeOS,Solaris,Haiku,iphonesim,ios,aix,Android];
//    unixlikes-[beos];
//
  StrUtilsOSes  = [atari,gba,macosclassic,nds,sinclairql,human68k,wii,win32,win64]+UnixLikes+AllWebAssemblyOSes;
  VarUtilsOSes  = [atari,gba,macosclassic,nds,sinclairql,human68k,wii,win32,win64]+UnixLikes+AllWebAssemblyOSes;
  ConvUtilsOSes = [macosclassic,sinclairql,human68k,win32,win64]+UnixLikes-[BeOS]+AllWebAssemblyOSes;
  ConvUtilOSes  = [atari];
  DateUtilsOSes = [gba,nds,macosclassic,sinclairql,human68k,wii,win32,win64]+UnixLikes+AllWebAssemblyOSes;
  DateUtilOSes  = [atari];
  StdConvsOSes  = [win32,win64]+UnixLikes-[BeOS]+AllWebAssemblyOSes;
  FmtBCDOSes    = [atari,gba,nds,sinclairql,human68k,wii,win32,win64]+UnixLikes+AllWebAssemblyOSes;
  VariantsOSes  = [atari,gba,nds,sinclairql,human68k,wii,win32,win64]+UnixLikes+AllWebAssemblyOSes;
  RttiOSes      = [atari,gba,nds,sinclairql,human68k,wii,win32,win64]+UnixLikes+AllWebAssemblyOSes;
  UItypesOSes   = [atari,gba,nds,sinclairql,human68k,wii,win32,win64]+UnixLikes+AllWebAssemblyOSes;
  AllTargetsObjPas = DateUtilsOses +DateUtilOSes+
                  VarutilsOses + ConvutilsOSes + ConvutilOSes + StdConvsOSes+
                  FmtBCDOSes + StrUtilsOSes + UITypesOSes;
  MonitorOSes   = [Win32,win64]+UnixLikes-[BeOS,Haiku]+[wasip1,wasip1threads];

Var
  P : TPackage;
  T : TTarget;

begin
  With Installer do
    begin
    P:=AddPackage('rtl-objpas');
    P.ShortName:='rtlo';
    P.Directory:=ADirectory;
    P.Version:='3.3.1';
    P.Author := 'FPC core team';
    P.License := 'LGPL with modification, ';
    P.HomepageURL := 'www.freepascal.org';
    P.OSes:=AllTargetsObjPas;
    if Defaults.CPU=jvm then
      P.OSes := P.OSes - [java,android];

    P.Email := '';
    P.Description := 'Rtl-objpas, aux. Delphi compat units';
    P.NeedLibC:= false;

    P.SourcePath.Add('src/inc');
    P.SourcePath.Add('src/$(OS)');
    P.SourcePath.Add('src/win',[win32,win64]);

    P.IncludePath.Add('src/inc');
    P.IncludePath.Add('src/$(OS)');
    P.IncludePath.Add('src/$(CPU)');
    P.IncludePath.Add('src/win',[win32,win64]);

    T:=P.Targets.AddUnit('system.uitypes.pp',uitypesOses);
    T:=P.Targets.AddUnit('system.uiconsts.pp',uitypesOses);
      T.Dependencies.AddUnit('system.uitypes');
    T:=P.Targets.AddUnit('system.timespan.pp',uitypesOses);

    T:=P.Targets.AddUnit('system.actions.pp',UItypesOSes);
      T.Dependencies.AddUnit('system.uitypes');
    T:=P.Targets.AddUnit('system.math.vectors.pp',UItypesOSes);
      T.Dependencies.AddUnit('system.uitypes');

    T:=P.Targets.AddUnit('tuples.pp');
    T:=P.Targets.AddUnit('strutils.pp',StrUtilsOses);
      T.ResourceStrings:=true;
    T:=P.Targets.AddUnit('syshelpers.pp',StrUtilsOses);
    T:=P.Targets.AddUnit('widestrutils.pp',StrUtilsOses-ConvUtilOSes);
    T:=P.Targets.AddUnit('varutils.pp',VarUtilsOses);
    with T.Dependencies do
      begin
        AddInclude('varutilh.inc');
        AddInclude('varerror.inc');
        AddInclude('varutils.inc',VarUtilsOSes-[win32,win64]);
        AddInclude('wvarutil.inc',[win32,win64]);
        AddInclude('cvarutil.inc');
      end;

    // 8.3
    T:=P.Targets.AddUnit('convutil.pp',ConvutilOSes);
    with T.Dependencies do
     begin
       AddInclude('convutil.inc');
     end;

    // normal
    T:=P.Targets.AddUnit('convutils.pp',ConvutilsOSes);
    with T.Dependencies do
     begin
       AddInclude('convutil.inc');
     end;

    // 8.3
    T:=P.Targets.AddUnit('dateutil.pp',dateutilOSes);
    with T.Dependencies do
     begin
       AddInclude('dateutil.inc');
     end;

    // normal
    T:=P.Targets.AddUnit('dateutils.pp',dateutilsOSes);
    with T.Dependencies do
     begin
       AddInclude('dateutil.inc');
     end;

    T:=P.Targets.AddUnit('stdconvs.pp',StdConvsOSes);
    T.ResourceStrings:=true;
    with T.Dependencies do
     begin
      AddUnit('convutils',ConvUtilsOSes);
      AddUnit('convutil',ConvUtilOSes);
     end;

    T:=P.Targets.AddUnit('fmtbcd.pp',FmtBCDOSes);
    with T.Dependencies do
      AddUnit('variants');

    T:=P.Targets.AddUnit('variants.pp',VariantsOSes);
    T.ResourceStrings:=true;
    with T.Dependencies do
     begin
       AddUnit('varutils');
       // AddUnit('Math');
     end;

    T:=P.Targets.AddUnit('nullable.pp',VariantsOSes);
    T:=P.Targets.AddUnit('rtti.pp',RttiOSes);
    with T.Dependencies do
       begin
         AddInclude('invoke.inc',[x86_64],RttiOSes);
         AddUnit('variants');
       end;
    T.ResourceStrings:=true;
    T:=P.Targets.AddUnit('fpmonitor.pp',MonitorOSes);
    T:=P.Targets.AddUnit('fpwinmonitor.pp',[Win32,win64]);
      T.Dependencies.AddUnit('fpmonitor');

    P.NamespaceMap:='namespaces.lst';

  end
end;

{$ifndef ALLPACKAGES}
begin
  add_rtl_objpas('');
  Installer.Run;
end.
{$endif ALLPACKAGES}

