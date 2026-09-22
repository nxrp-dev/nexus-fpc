{$ifndef ALLPACKAGES}
{$mode objfpc}{$H+}
program fpmake;

uses {$ifdef unix}cthreads,{$endif} fpmkunit;
{$endif ALLPACKAGES}

procedure add_rtl_extra(const ADirectory: string);

Const
  UnixLikes = AllUnixOSes;

  ClocaleOSes   = UnixLikes -[android];
  CLocaleIncOSes= [Aix,darwin,iphonesim,ios];

  IPCOSes       = UnixLikes-[aix,android];
  IPCBSDs       = [Darwin,iphonesim,ios];
//  IPCcdeclOSes  = [Darwin,iphonesim,ios];

  PrinterOSes   = [win32,win64,atari]+unixlikes;
  SerialOSes    = [android,linux,win32,win64];
  UComplexOSes  = [atari,sinclairql,human68k,win32,win64,wasip1,wasip1threads]+UnixLikes;
  MatrixOSes    = [atari,sinclairql,human68k,win32,win64,wasip1,wasip1threads]+UnixLikes;
  ObjectsOSes   = [atari,sinclairql,human68k,win32,win64,wasip1,wasip1threads]+UnixLikes;
  WinsockOSes   = [win32,win64];
  WinSock2OSes  = [win32,win64];
  SocketsOSes   = UnixLikes+[win32,win64];
  gpmOSes = [Linux,Android];
  AllTargetsextra = ObjectsOSes + UComplexOSes + MatrixOSes+
                      SerialOSes +PrinterOSes+SocketsOSes+gpmOSes;

Var
  P : TPackage;
  T : TTarget;
  Socksyscall, Socklibc : set of Tos;

begin
  With Installer do
    begin
    P:=AddPackage('rtl-extra');
    P.ShortName:='rtle';
    P.Directory:=ADirectory;
    P.Version:='3.3.1';
    P.Author := 'FPC core team';
    P.License := 'LGPL with modification, ';
    P.HomepageURL := 'www.freepascal.org';
    P.OSes:=AllTargetsextra;
    if Defaults.CPU=jvm then
      P.OSes := P.OSes - [java,android];

    Socksyscall := [linux];
    Socklibc  := unixlikes-socksyscall;
    P.Email := '';
    P.Description := 'Rtl-extra, RTL not needed for bootstrapping';
    P.NeedLibC:= false;

    P.SourcePath.Add('src/inc');
    P.SourcePath.Add('src/$(OS)');
    P.SourcePath.Add('src/darwin',[iphonesim,ios]);
    P.SourcePath.Add('src/unix',AllUnixOSes);
    P.SourcePath.Add('src/bsd',AllBSDOSes);
    P.SourcePath.Add('src/win',[win32,win64]);

    P.IncludePath.Add('src/bsd',AllBSDOSes);
    P.IncludePath.Add('src/inc');
    P.IncludePath.Add('src/unix',AllUnixOSes);
    P.IncludePath.Add('src/$(OS)');
    P.IncludePath.Add('src/darwin',[iphonesim,ios]);
    P.IncludePath.Add('src/win',AllWindowsOSes);

    // Add clocale for Android first in order to compile the source file
    // from the 'android' dir, not the 'unix' dir.
    T:=P.Targets.AddUnit('real48utils.pp',AllTargetsextra-[msdos]  { msdos excluded temporarily, until bitpacked records containing longints on 16-bit targets are fixed }
                                                         -[wasip1,wasip1threads] { internal error on the WebAssembly target }
                                                         -[embedded]);
    if Defaults.CPU<>jvm then
      T:=P.Targets.AddUnit('clocale.pp',[android]);

    { Ideally, we should check if rtl contains math unit,
      I do know how that can be checked. PM 2019/11/27 }
    if (Defaults.CPU<>i8086)
       or (Defaults.OS<>embedded) then
      begin
        T:=P.Targets.AddUnit('ucomplex.pp',UComplexOSes);
        T:=P.Targets.AddUnit('matrix.pp',MatrixOSes);
        with T.Dependencies do
          begin
            AddInclude('mvecimp.inc');
            AddInclude('mmatimp.inc');
          end;
      end;

    T:=P.Targets.AddUnit('objects.pp',ObjectsOSes);

    T:=P.Targets.AddUnit('printer.pp',PrinterOSes);
    T.Dependencies.AddInclude('printerh.inc',PrinterOSes);
    T.Dependencies.AddInclude('printer.inc',PrinterOSes);

    T:=P.Targets.AddUnit('winsock.pp',WinSockOSes);
    with T.Dependencies do
     begin
     end;
    T:=P.Targets.AddUnit('winsock2.pp',WinSock2OSes);
    T:=P.Targets.AddUnit('gpm.pp',gpmOSes);
    with T.Dependencies do
      AddUnit('sockets');

    T:=P.Targets.AddUnit('serial.pp',SerialOSes);
    T:=P.Targets.AddUnit('sockets.pp',SocketsOSes);
    with T.Dependencies do
     begin
       addinclude('osdefs.inc',AllUnixOSes);
       addinclude('socketsh.inc');
       addinclude('fpwinsockh.inc',AllWindowsOSes);
       addinclude('sockets.inc');
       addinclude('sockovl.inc');
       addinclude('unxsockh.inc',UnixLikes);
       addinclude('stdsock.inc',socklibc);
       addinclude('unixsock.inc',socksyscall);
     end;
    T:=P.Targets.AddUnit('unixsockets.pp',[linux]);

    T:=P.Targets.AddUnit('ipc.pp',IPCOSes);
    with T.Dependencies do
     begin
       addinclude('osdefs.inc');
       addinclude('ipcbsd.inc',IPCBSDs);
       addinclude('ipcsys.inc',[Linux]);
       addinclude('ipccall.inc',[Linux]);
//       addinclude('ipccdecl.inc',IPCcdeclOSes); // not used?
     end;
    T:=P.Targets.AddUnit('src/unix/clocale.pp',CLocaleOSes);
    with T.Dependencies do
     begin
       addinclude('clocale.inc',clocaleincOSes);
     end;
    T:=P.Targets.AddUnit('sortalgs.pp',AllCPUs, AllTargetsextra);

    P.NamespaceMap:='namespaces.lst';

  end;
end;

{$ifndef ALLPACKAGES}
begin
  add_rtl_extra('');
  Installer.Run;
end.
{$endif ALLPACKAGES}

