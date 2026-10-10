program package_loader_failures;
{$mode objfpc}{$H+}
uses SysUtils, Classes, PackageNative, PkgContracts;
var Mode,MessageText: string; Handle,Base: HMODULE; Caught: Boolean;
procedure Check(Value: Boolean; const Message: string);
begin if not Value then raise Exception.Create(Message+': '+Trace); end;
procedure Reject(const Name,Marker: string);
begin
  Caught:=false;
  try LoadPackage(Name);
  except
    on E: EPackageError do
      begin MessageText:=E.Message; Caught:=Pos(Marker,MessageText)>0; end;
  end;
  Check(Caught,'wrong load failure: '+MessageText);
end;
begin
  Mode:=ParamStr(1);
  Check(Trace='C','unexpected startup package');
  if Mode='init' then
    begin
      Reject(PackageFileName('failinit'),'init-marker');
      Check(Trace='CF!Df','exception lifetime and completed-prefix rollback');
      Check(GetClass('FailedAlias')=nil,'failed initialization left class registration');
      Check(NativePackageHandle(PackageFileName('failinit'))=0,'failed initialization retained clean image');
      Reject(PackageFileName('failinit'),'init-marker');
      Check(Trace='CF!DfF!Df','retry used stale registration or state');
    end
  else if Mode='new-dependency' then
    begin
      Reject(PackageFileName('faildependency'),'init-marker');
      Check(Trace='CB!Db','new dependency rollback order');
      Check((NativePackageHandle(PackageFileName('pluginbase'))=0) and
        (NativePackageHandle(PackageFileName('faildependency'))=0),'new dependency retained after clean rollback');
      Check(GetClass('LatePluginAlias')=nil,'new dependency registrations survived rollback');
    end
  else if Mode='live-dependency' then
    begin
      Handle:=LoadPackage(PackageFileName('pluginleft'));
      Base:=NativePackageHandle(PackageFileName('pluginbase'));
      Reject(PackageFileName('faildependency'),'init-marker');
      Check((Trace='CBL!D') and (NativePackageHandle(PackageFileName('pluginbase'))=Base),
        'rollback damaged active dependency');
      Check(GetClass('LatePluginAlias')<>nil,'rollback removed another owner registration');
      UnloadPackage(Handle);
      Check(Trace='CBL!Dlb','dependency references leaked after rollback');
    end
  else if Mode='cleanup' then
    begin
      Reject(PackageFileName('cleanupfail'),'init-marker');
      Check(Pos('cleanup-marker',MessageText)>0,'cleanup diagnostic missing');
      Check(Trace='CBX!Dxb','rollback cleanup progress');
      Check(NativePackageHandle(PackageFileName('cleanupfail'))<>0,'unsafe cleanup image release');
      Reject(PackageFileName('cleanupfail'),'unavailable');
      Check(NativePackageHandle(PackageFileName('pluginbase'))<>0,'failed cleanup released dependency');
      Reject(PackageFileName('pluginleft'),'cannot be initialized');
      Check(Trace='CBX!Dxb','failed image or dependency reinitialized');
    end
  else if Mode='finalization' then
    begin
      Handle:=LoadPackage(PackageFileName('failfini'));
      Caught:=false;
      try UnloadPackage(Handle);
      except on E: EPackageError do Caught:=Pos('finalization-marker',E.Message)>0; end;
      Check(Caught and (Trace='CZzD'),'finalization exception lifetime');
      Check(NativePackageHandle(PackageFileName('failfini'))=Handle,'failed finalization image released');
      Reject(PackageFileName('failfini'),'unavailable');
      Check(Trace='CZzD','failed finalization image reused');
    end
  else if Mode='callback' then
    begin
      Handle:=LoadPackage(PackageFileName('callbackfail'));
      Caught:=false;
      try UnloadPackage(Handle);
      except on E: EPackageError do Caught:=Pos('callback-marker',E.Message)>0; end;
      Check(Caught and (Trace='CYKDy'),'cleanup callback exception or finalization order');
      Check(NativePackageHandle(PackageFileName('callbackfail'))=Handle,'failed callback image released');
      Reject(PackageFileName('callbackfail'),'unavailable');
    end
  else if Mode='tls' then
    begin
      Reject(PackageFileName('newtls'),'threadvar storage');
      Check(Trace='C','TLS rejection initialized the package');
      Check(NativePackageHandle(PackageFileName('newtls'))=0,'TLS rejection leaked mapping');
    end
  else if Mode='nested-load' then
    begin
      Reject(PackageFileName('nestedload'),'Nested package lifecycle');
      Check(Trace='CQ','nested loading initialized another image');
      Check(NativePackageHandle(PackageFileName('nestedload'))=0,'nested failure retained clean image');
    end
  else if Mode='nested-unload' then
    begin
      Handle:=LoadPackage(PackageFileName('nestedunload'));
      Caught:=false;
      try UnloadPackage(Handle);
      except on E: EPackageError do Caught:=Pos('Nested package lifecycle',E.Message)>0; end;
      Check(Caught and (Trace='CUu'),'nested unload was accepted');
      Check(NativePackageHandle(PackageFileName('nestedunload'))=Handle,'nested unload failure released image');
    end
  else if Mode='non-exception' then
    begin
      Reject(PackageFileName('nonexception'),'Non-Exception');
      Check(Trace='CND','non-Exception object not released while mapped');
      Check(NativePackageHandle(PackageFileName('nonexception'))=0,'non-Exception failure retained clean image');
    end
  else if Mode='duplicate' then
    begin
      Handle:=LoadPackage(PackageFileName('pluginleft'));
      Reject(PackageFileName('duplicate'),'Duplicate package image');
      Check(Trace='CBL','duplicate image initialized');
      Check(NativePackageHandle(PackageFileName('duplicate'))=0,'duplicate mapping leaked');
      UnloadPackage(Handle);
      Check(Trace='CBLlb','duplicate failure damaged original owner');
    end
  else if Mode='sdk' then
    begin
      Reject(PackageFileName('bad'),'Incompatible package SDK');
      Check(Trace='C','SDK mismatch initialized units');
    end
  else if Mode='abi' then
    begin
      Reject(PackageFileName('bad'),'Unsupported package descriptor');
      Check(Trace='C','descriptor mismatch initialized units');
    end
  else if Mode='dependency' then
    begin
      Reject(PackageFileName('pluginleft'),'Package dependency build differs');
      Check(Trace='C','dependency mismatch initialized units');
      Check(NativePackageHandle(PackageFileName('pluginbase'))=0,'dependency validation leaked registration or mapping');
    end
  else if Mode='missing' then
    begin
      Reject(PackageFileName('missing-package'),'Cannot load package');
      Check(Trace='C','missing file changed lifecycle');
    end
  else if Mode='not-package' then
    begin
      Reject(ParamStr(2),'Missing package descriptor');
      Check(Trace='C','non-package changed registry');
    end
  else raise Exception.Create('Unknown failure case: '+Mode);
  { A failed transaction must not poison a subsequent independent load. }
  Handle:=LoadPackage(PackageFileName('democontracts'));
  UnloadPackage(Handle);
  WriteLn('PASS ',Mode,': ',Trace);
end.
