program package_loader_failures;
{$mode objfpc}{$H+}
uses SysUtils, Classes, Windows, PkgContracts;
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
      Reject('failinit.dll','init-marker');
      Check(Trace='CF!Df','exception lifetime and completed-prefix rollback');
      Check(GetClass('FailedAlias')=nil,'failed initialization left class registration');
      Check(Windows.GetModuleHandleA('failinit.dll')=0,'failed initialization retained clean image');
      Reject('failinit.dll','init-marker');
      Check(Trace='CF!DfF!Df','retry used stale registration or state');
    end
  else if Mode='new-dependency' then
    begin
      Reject('faildependency.dll','init-marker');
      Check(Trace='CB!Db','new dependency rollback order');
      Check((Windows.GetModuleHandleA('pluginbase.dll')=0) and
        (Windows.GetModuleHandleA('faildependency.dll')=0),'new dependency retained after clean rollback');
      Check(GetClass('LatePluginAlias')=nil,'new dependency registrations survived rollback');
    end
  else if Mode='live-dependency' then
    begin
      Handle:=LoadPackage('pluginleft.dll');
      Base:=Windows.GetModuleHandleA('pluginbase.dll');
      Reject('faildependency.dll','init-marker');
      Check((Trace='CBL!D') and (Windows.GetModuleHandleA('pluginbase.dll')=Base),
        'rollback damaged active dependency');
      Check(GetClass('LatePluginAlias')<>nil,'rollback removed another owner registration');
      UnloadPackage(Handle);
      Check(Trace='CBL!Dlb','dependency references leaked after rollback');
    end
  else if Mode='cleanup' then
    begin
      Reject('cleanupfail.dll','init-marker');
      Check(Pos('cleanup-marker',MessageText)>0,'cleanup diagnostic missing');
      Check(Trace='CBX!Dxb','rollback cleanup progress');
      Check(Windows.GetModuleHandleA('cleanupfail.dll')<>0,'unsafe cleanup image release');
      Reject('cleanupfail.dll','unavailable');
      Check(Windows.GetModuleHandleA('pluginbase.dll')<>0,'failed cleanup released dependency');
      Reject('pluginleft.dll','cannot be initialized');
      Check(Trace='CBX!Dxb','failed image or dependency reinitialized');
    end
  else if Mode='finalization' then
    begin
      Handle:=LoadPackage('failfini.dll');
      Caught:=false;
      try UnloadPackage(Handle);
      except on E: EPackageError do Caught:=Pos('finalization-marker',E.Message)>0; end;
      Check(Caught and (Trace='CZzD'),'finalization exception lifetime');
      Check(Windows.GetModuleHandleA('failfini.dll')=Handle,'failed finalization image released');
      Reject('failfini.dll','unavailable');
      Check(Trace='CZzD','failed finalization image reused');
    end
  else if Mode='callback' then
    begin
      Handle:=LoadPackage('callbackfail.dll');
      Caught:=false;
      try UnloadPackage(Handle);
      except on E: EPackageError do Caught:=Pos('callback-marker',E.Message)>0; end;
      Check(Caught and (Trace='CYKDy'),'cleanup callback exception or finalization order');
      Check(Windows.GetModuleHandleA('callbackfail.dll')=Handle,'failed callback image released');
      Reject('callbackfail.dll','unavailable');
    end
  else if Mode='tls' then
    begin
      Reject('newtls.dll','threadvar storage');
      Check(Trace='C','TLS rejection initialized the package');
      Check(Windows.GetModuleHandleA('newtls.dll')=0,'TLS rejection leaked mapping');
    end
  else if Mode='nested-load' then
    begin
      Reject('nestedload.dll','Nested package lifecycle');
      Check(Trace='CQ','nested loading initialized another image');
      Check(Windows.GetModuleHandleA('nestedload.dll')=0,'nested failure retained clean image');
    end
  else if Mode='nested-unload' then
    begin
      Handle:=LoadPackage('nestedunload.dll');
      Caught:=false;
      try UnloadPackage(Handle);
      except on E: EPackageError do Caught:=Pos('Nested package lifecycle',E.Message)>0; end;
      Check(Caught and (Trace='CUu'),'nested unload was accepted');
      Check(Windows.GetModuleHandleA('nestedunload.dll')=Handle,'nested unload failure released image');
    end
  else if Mode='non-exception' then
    begin
      Reject('nonexception.dll','Non-Exception');
      Check(Trace='CND','non-Exception object not released while mapped');
      Check(Windows.GetModuleHandleA('nonexception.dll')=0,'non-Exception failure retained clean image');
    end
  else if Mode='duplicate' then
    begin
      Handle:=LoadPackage('pluginleft.dll');
      Reject('duplicate.dll','Duplicate package image');
      Check(Trace='CBL','duplicate image initialized');
      Check(Windows.GetModuleHandleA('duplicate.dll')=0,'duplicate mapping leaked');
      UnloadPackage(Handle);
      Check(Trace='CBLlb','duplicate failure damaged original owner');
    end
  else if Mode='sdk' then
    begin
      Reject('bad.dll','Incompatible package SDK');
      Check(Trace='C','SDK mismatch initialized units');
    end
  else if Mode='abi' then
    begin
      Reject('bad.dll','Unsupported package descriptor');
      Check(Trace='C','descriptor mismatch initialized units');
    end
  else if Mode='dependency' then
    begin
      Reject('pluginleft.dll','Package dependency build differs');
      Check(Trace='C','dependency mismatch initialized units');
      Check(Windows.GetModuleHandleA('pluginbase.dll')=0,'dependency validation leaked registration or mapping');
    end
  else if Mode='missing' then
    begin
      Reject('missing-package.dll','Cannot load package');
      Check(Trace='C','missing file changed lifecycle');
    end
  else if Mode='not-package' then
    begin
      Reject(ParamStr(2),'Missing package descriptor');
      Check(Trace='C','non-package changed registry');
    end
  else raise Exception.Create('Unknown failure case: '+Mode);
  { A failed transaction must not poison a subsequent independent load. }
  Handle:=LoadPackage('democontracts.dll');
  UnloadPackage(Handle);
  WriteLn('PASS ',Mode,': ',Trace);
end.
