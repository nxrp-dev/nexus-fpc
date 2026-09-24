Procedure ApplyLinuxTargets(Installer : TInstaller);

Var
  C : String;

  Procedure AddLoader (Loader : String);

  Const
    asbin = 'as';
    asopt = '-o $(OUTPUTDIR)/$(DEST) $(SOURCE)';

  begin
    With Installer.DefaultPackage.Commands do
      AddCommand(asbin,asopt,loader+'.o',c+loader+'.as');
  end;

begin
  ApplyUnixTargets(Installer);
  with Installer do
    begin
    DefaultPackage.Options:=DefaultPackage.Options+' -Filinux/'+CurrentCPU;
    ExcludeCurrentOS(Targets['utf8bidi']);
    end;
  C:=IncludeTrailingPathDelimiter('linux/'+CPUToString(Defaults.CPU));
  AddLoader('prt0');
  If (Defaults.CPU<>m68k) then
    begin
    AddLoader('cprt0');
    AddLoader('dllprt0');
    end
  else
    AddLoader('prt1');
  If (Defaults.CPU=i386) Then
    AddLoader('cprt21');
end;
