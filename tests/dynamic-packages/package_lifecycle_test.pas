program package_lifecycle_test;
{$mode objfpc}{$H+}
uses SysUtils, FPCPackage;

type
  TEntry = record Init, Fini: TProcedure; Name: PShortString; end;
  TTable = record Count, LegacyCount: SizeUInt; Entries: array[0..1] of TEntry; end;
var
  D: array[0..5] of TPackageDescriptor;
  C: array[0..5] of TPackageContext;
  N: array[0..5] of ShortString = ('BASE','LEFT','RIGHT','ROOT','FAIL','CHILD');
  H: array[0..5] of SizeUInt = (100,101,102,103,104,105);
  T: array[0..5] of TTable;
  Dep: array[0..5,0..1] of PPPackageDescriptor;
  Ref: array[0..5] of PPackageDescriptor;
  Bad: TPackageDescriptor;
  BadContext: TPackageContext;
  BadName: ShortString = 'BAD';
  Cycle: array[0..1] of TPackageDescriptor;
  CycleContext: array[0..1] of TPackageContext;
  CycleRef: array[0..1] of PPackageDescriptor;
  CycleDep: array[0..1] of PPPackageDescriptor;
  FailFinalization: Boolean;
  Trace: string;
  I: Integer;

procedure Check(B: Boolean; const S: string);
begin
  if not B then raise Exception.Create(S+': '+Trace);
end;
procedure Init0; begin Trace:=Trace+'B'; end;
procedure Fini0; begin Trace:=Trace+'b'; end;
procedure Init1; begin Trace:=Trace+'L'; end;
procedure Fini1;
begin
  Trace:=Trace+'l';
  if FailFinalization then raise Exception.Create('finalization failure');
end;
procedure Init2; begin Trace:=Trace+'R'; end;
procedure Fini2; begin Trace:=Trace+'r'; end;
procedure Init3; begin Trace:=Trace+'H'; end;
procedure Fini3; begin Trace:=Trace+'h'; end;
procedure Init4; begin Trace:=Trace+'F'; end;
procedure Fini4; begin Trace:=Trace+'f'; end;
procedure Fail; begin Trace:=Trace+'!'; raise Exception.Create('injected'); end;
procedure Init5; begin Trace:=Trace+'C'; end;
procedure Fini5;
begin
  Trace:=Trace+'c';
  raise Exception.Create('rollback finalization failure');
end;

procedure Reject(Descriptor: PPackageDescriptor; const Expected: string);
begin
  try
    RegisterPackage(Descriptor);
    Check(false,'accepted invalid descriptor: '+Expected);
  except
    on E: EPackageError do Check(Pos(Expected,E.Message)>0,'wrong rejection: '+E.Message);
  end;
  Check(Descriptor^.Context^.State=psUnregistered,'failed registration changed state');
  Check(Trace='','rejected descriptor ran initialization');
end;

procedure ResetBad;
begin
  Bad:=D[0];
  Bad.Name:=@BadName;
  Bad.Context:=@BadContext;
  Bad.UnitCount:=0;
  Bad.UnitNames:=nil;
end;

begin
  Check(SizeOf(TPackageDescriptor)=21*SizeOf(Pointer),'descriptor layout');
  Check(SizeOf(TPackageContext)=6*SizeOf(Pointer),'context layout');
  for I:=0 to High(D) do
    begin
      D[I].Magic:=FPCPackageMagic; D[I].Version:=FPCPackageVersion;
      D[I].Size:=SizeOf(TPackageDescriptor); D[I].Name:=@N[I];
      D[I].Context:=@C[I]; D[I].ModuleHandle:=@H[I]; D[I].InitFinalTable:=@T[I];
      D[I].UnitCount:=1; D[I].UnitNames:=@D[I].Name;
      T[I].Count:=1; Ref[I]:=@D[I];
    end;
  T[0].Entries[0].Init:=@Init0; T[0].Entries[0].Fini:=@Fini0;
  T[1].Entries[0].Init:=@Init1; T[1].Entries[0].Fini:=@Fini1;
  T[2].Entries[0].Init:=@Init2; T[2].Entries[0].Fini:=@Fini2;
  T[3].Entries[0].Init:=@Init3; T[3].Entries[0].Fini:=@Fini3;
  T[4].Entries[0].Init:=@Init4; T[4].Entries[0].Fini:=@Fini4;
  T[4].Entries[1].Init:=@Fail; T[4].Count:=2;
  T[5].Entries[0].Init:=@Init5; T[5].Entries[0].Fini:=@Fini5;
  for I:=1 to 2 do
    begin
      Dep[I,0]:=@Ref[0]; D[I].Dependencies:=@Dep[I]; D[I].DependencyCount:=1;
    end;
  Dep[3,0]:=@Ref[1]; Dep[3,1]:=@Ref[2]; D[3].Dependencies:=@Dep[3]; D[3].DependencyCount:=2;
  RegisterPackage(@D[3]);
  Check(Trace='','registration executed initialization');
  Check((C[0].ModuleHandle=100) and (C[3].ModuleHandle=103),'distinct handles');
  Check((C[0].Descriptor=@D[0]) and (C[3].Descriptor=@D[3]),'distinct contexts');
  ResetBad; Inc(Bad.Version); Reject(@Bad,'Unsupported package descriptor');
  ResetBad; Dec(Bad.Size); Reject(@Bad,'Unsupported package descriptor');
  ResetBad; Inc(Bad.CompilerIdentity); Reject(@Bad,'Incompatible package build');
  ResetBad; Bad.CompilerIdentity:=Bad.CompilerIdentity xor (QWord(1) shl 32);
  Reject(@Bad,'Incompatible package build');
  ResetBad; Bad.CompilerIdentity:=Bad.CompilerIdentity xor (QWord(1) shl 48);
  Reject(@Bad,'Incompatible package build');
  ResetBad; Inc(Bad.TargetIdentity); Reject(@Bad,'Incompatible package build');
  ResetBad; Inc(Bad.RTLIdentity); Reject(@Bad,'Incompatible package build');
  ResetBad; Bad.Name:=D[0].Name; Reject(@Bad,'Duplicate package image');
  ResetBad; Bad.UnitCount:=1; Bad.UnitNames:=D[0].UnitNames;
  Reject(@Bad,'Duplicate package unit');
  ResetBad; Bad.DependencyCount:=1; Reject(@Bad,'Incomplete package descriptor');
  ResetBad;
  for I:=0 to 1 do
    begin
      Cycle[I]:=Bad; Cycle[I].Context:=@CycleContext[I];
      CycleRef[I]:=@Cycle[I]; CycleDep[I]:=@CycleRef[1-I];
      Cycle[I].Dependencies:=@CycleDep[I]; Cycle[I].DependencyCount:=1;
    end;
  Reject(@Cycle[0],'Package dependency cycle');
  Check(CycleContext[1].State=psUnregistered,'cycle registration rollback');
  InitializePackage(@D[3]); InitializePackage(@D[3]);
  Check(Trace='BLRH','diamond initialized once');
  Dep[5,0]:=@Ref[0]; D[5].Dependencies:=@Dep[5]; D[5].DependencyCount:=1;
  Dep[4,0]:=@Ref[5]; D[4].Dependencies:=@Dep[4]; D[4].DependencyCount:=1;
  try
    InitializePackage(@D[4]);
    Check(false,'missing initialization failure');
  except
    on E: Exception do Check(E.Message='injected','original exception preserved');
  end;
  Check(Trace='BLRHCF!fc','failed attempt rollback');
  Check((C[0].State=psActive) and (C[0].InitCount=1),'existing dependency preserved');
  Check((C[4].InitCount=0) and (C[5].InitCount=0),'rollback progress');
  FailFinalization:=true;
  try
    FinalizePackages;
    Check(false,'missing finalization failure');
  except
    on E: Exception do Check(E.Message='finalization failure','finalization exception');
  end;
  Check(Trace='BLRHCF!fchrl','finalization stopped at failing callback');
  FinalizePackages; FinalizePackages;
  Check(Trace='BLRHCF!fchrlb','reverse finalization exactly once');
  WriteLn('PASS lifecycle: ',Trace);
end.
