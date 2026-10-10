program Threadvar_Package_Host;
{$mode objfpc}{$H+}
uses SysUtils, Threadvar_Contracts;
threadvar HostValue: LongInt;
var
  Handles: array[0..23] of HMODULE;
  Addresses: array[0..23] of Pointer;
  I, Round: LongInt;
  Shared, Host: Pointer;
  Caught: Boolean;
  NativeHold: TLibHandle;
function Image(const Name: string): string;
begin
{$ifdef windows}
  Result:=Name+'.dll';
{$else}
  Result:='lib'+Name+'.so';
{$endif}
end;
procedure Check(Value: Boolean; const Message: string);
begin
  if not Value then raise Exception.Create(Message);
end;
begin
  Shared:=@SharedValue; Host:=@HostValue; HostValue:=97;
  Check(Probes[24].Address<>nil,'startup owner did not initialize');
  Check(Probes[24].SharedAddress()=Shared,'startup import identity');
  Probes[24].Check();
{$ifdef windows}
  { Exercise the conservative guard without introducing worker threads. The
    Windows RTL already has its real thread manager installed. }
  IsMultiThread:=true;
  Caught:=false;
  try
    try LoadPackage(Image('tv0'));
    except on E: EPackageError do Caught:=Pos('single-threaded runtime',E.Message)>0; end;
  finally IsMultiThread:=false; end;
  Check(Caught and (Probes[0].Address=nil),'blocked load changed package state');
{$endif}
  Handles[0]:=LoadPackage(Image('tv0'));
{$ifdef windows}
  IsMultiThread:=true;
  Caught:=false;
  try
    try UnloadPackage(Handles[0]);
    except on E: EPackageError do Caught:=Pos('single-threaded runtime',E.Message)>0; end;
  finally IsMultiThread:=false; end;
  Check(Caught,'multithreaded unload was accepted');
  Probes[0].Check();
{$endif}
  NativeHold:=System.LoadLibrary(ExtractFilePath(ParamStr(0))+Image('tv0'));
  Check(NativeHold<>0,'cannot take independent native reference');
  UnloadPackage(Handles[0]);
  Handles[0]:=LoadPackage(Image('tv0'));
  Probes[0].Check();
  UnloadPackage(Handles[0]);
  Check(System.UnloadLibrary(NativeHold),'cannot release native reference');
  for Round:=1 to 2 do
    begin
      for I:=0 to High(Handles) do
        begin
          Handles[I]:=LoadPackage(Image('tv'+IntToStr(I)));
          Check(Probes[I].Address<>nil,'late probe not registered');
          Addresses[I]:=Probes[I].Address();
          Check(Probes[I].SharedAddress()=Shared,'late import identity');
          Probes[I].Check();
        end;
      for I:=0 to High(Handles) do
        begin
          Check(Probes[I].Address()=Addresses[I],'directory growth moved storage');
          Probes[I].Check();
        end;
      Check((Shared=@SharedValue) and (SharedValue=$123456789ABC),'shared RTL startup storage moved');
      Check((Host=@HostValue) and (HostValue=97),'host storage moved');
      for I:=High(Handles) downto 0 do
        begin
          UnloadPackage(Handles[I]);
          Check(Probes[I].Address=nil,'finalization callback remained');
        end;
    end;
  for Round:=1 to 2 do
    begin
      Caught:=false;
      try LoadPackage(Image('tvfail'));
      except on E: EPackageError do Caught:=Pos('threadvar-init-failure',E.Message)>0; end;
      Check(Caught,'wrong initialization failure');
      Check(Probes[25].Address=nil,'rollback did not finalize completed TLS owner');
    end;
  Check(Initializations=53,'unexpected initialization count');
  Check(Finalizations=52,'unexpected finalization count');
  Probes[24].Check();
  WriteLn('PASS unified package threadvars: startup, 24 late owners, growth, imports, alignment, rollback, reload');
end.
