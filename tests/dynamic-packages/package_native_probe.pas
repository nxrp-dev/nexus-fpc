{ Copyright (c) 2026 Kevin Collins. SPDX-License-Identifier: GPL-2.0-or-later }
program PackageNativeProbe;
{$mode objfpc}{$H+}
uses Windows, SysUtils;
type
  TPointerFunction = function: Pointer; cdecl;
  TIntFunction = function: LongInt; cdecl;
  TAddFunction = function(AValue: LongInt): LongInt; cdecl;
  TDescriptor = array[0..20] of QWord;
  PDescriptor = ^TDescriptor;
  THandles = array[0..4] of HMODULE;
  TDescriptors = array[0..4] of PDescriptor;
procedure Check(AValue: Boolean; const AMessage: string);
begin
  if not AValue then raise Exception.Create(AMessage);
end;
function Load(const AName: string): HMODULE;
begin
  Result:=LoadLibrary(PChar(IncludeTrailingPathDelimiter(ParamStr(2))+AName+'.dll'));
  Check(Result<>0,'LoadLibrary '+AName+': '+IntToStr(GetLastError));
end;
function Symbol(ALibrary: HMODULE; const AName: string): Pointer;
begin
  Result:=GetProcAddress(ALibrary,PChar(AName));
  Check(Result<>nil,'Missing symbol '+AName);
end;
function Address(ALibrary: HMODULE; const AName: string): Pointer;
begin
  Result:=TPointerFunction(Symbol(ALibrary,AName))();
end;
procedure LinkProbe;
const
  Names: array[0..5] of string = ('Counter','Class','RTTI','EnumRTTI','RecordRTTI','Resource');
  IntegerNames: array[0..3] of string = ('Inherits','Virtual','Managed','Inline');
  Values: array[0..3] of LongInt = (1,133,1,1017);
var
  lBase,lConsumer: HMODULE;
  lPointer: Pointer;
  lCounter: PLongInt;
  lAdd: TAddFunction;
  lIndex: Integer;
begin
  lBase:=Load('pkgbase'); lConsumer:=Load('pkgconsumer');
  for lIndex:=Low(Names) to High(Names) do begin
    lPointer:=Address(lBase,'NX_Base'+Names[lIndex]);
    Check((lPointer<>nil) and (lPointer=Address(lConsumer,'NX_Consumer'+Names[lIndex])),Names[lIndex]+' identity');
  end;
  lCounter:=Address(lBase,'NX_BaseCounter');
  Check(Address(lConsumer,'NX_ConsumerAlias')=lCounter,'Counter alias');
  Check(lCounter^=7,'Initial counter');
  lAdd:=TAddFunction(Symbol(lConsumer,'NX_ConsumerAdd'));
  Check((lAdd(5)=12) and (lCounter^=12),'Add 5');
  lCounter^:=30;
  Check((lAdd(2)=32) and (lCounter^=32),'Add 2');
  lAdd:=TAddFunction(Address(lBase,'NX_BaseProc'));
  Check(lAdd(1)=33,'Provider procedure');
  lAdd:=TAddFunction(Address(lConsumer,'NX_ConsumerProc'));
  Check((lAdd(1)=34) and (lCounter^=34),'Consumer procedure');
  Check(Address(lConsumer,'NX_ConsumerParent')=Address(lBase,'NX_BaseClass'),'Parent identity');
  for lIndex:=Low(Values) to High(Values) do
    Check(TIntFunction(Symbol(lConsumer,'NX_Consumer'+IntegerNames[lIndex]))()=Values[lIndex],IntegerNames[lIndex]);
  WriteLn('PASS runtime symbols');
end;
procedure DescriptorProbe;
const Names: array[0..4] of string = ('nxrtl','pkgshared','pkgleft','pkgright','pkgfail');
var
  lHandles: THandles;
  lDescriptors: TDescriptors;
  lDescriptor,lDependency: PDescriptor;
  lCompiler: QWord;
  lUnits,lDependencies: string;
  lIndex,lDependencyIndex: Integer;
begin
  lCompiler:=StrToQWord(ParamStr(3));
  for lIndex:=0 to 4 do begin
    lHandles[lIndex]:=Load(Names[lIndex]);
    lDescriptor:=Symbol(lHandles[lIndex],'FPC_PACKAGE_'+UpperCase(Names[lIndex]));
    lDescriptors[lIndex]:=lDescriptor;
    Check((lDescriptor^[0]=$4e58504b) and (lDescriptor^[1]=4) and
      (lDescriptor^[2]=SizeOf(TDescriptor)),'Descriptor ABI');
    Check(lDescriptor^[3]=lCompiler,'Compiler identity');
    Check((lDescriptor^[4]=lDescriptors[0]^[4]) and
      (lDescriptor^[5]<>0) and (lDescriptor^[5]=lDescriptors[0]^[5]),'Shared RTL identity');
    Check(PShortString(lDescriptor^[6])^=UpperCase(Names[lIndex]),'Descriptor name');
    for lDependencyIndex:=0 to 5 do Check(PQWord(lDescriptor^[16]+QWord(lDependencyIndex)*8)^=0,'Activated during native load');
    Check(PQWord(lDescriptor^[17])^=QWord(lHandles[lIndex]),'Module handle');
  end;
  lUnits:=''; lDescriptor:=lDescriptors[1];
  for lDependencyIndex:=0 to lDescriptor^[7]-1 do
    lUnits:=lUnits+PShortString(PQWord(lDescriptor^[8]+QWord(lDependencyIndex)*8)^)^+';';
  Check((lUnits='UPACKAGERUNTIME;UUNUSED;') or (lUnits='UUNUSED;UPACKAGERUNTIME;'),'Owned units');
  for lIndex:=2 to 3 do begin
    lDescriptor:=lDescriptors[lIndex]; lDependencies:='';
    Check(lDescriptor^[9]=2,'Dependency count');
    for lDependencyIndex:=0 to lDescriptor^[9]-1 do begin
      lDependency:=PPointer(PQWord(lDescriptor^[10]+QWord(lDependencyIndex)*8)^)^;
      lDependencies:=lDependencies+PShortString(lDependency^[6])^+';';
    end;
    Check((lDependencies='NXRTL;PKGSHARED;') or (lDependencies='PKGSHARED;NXRTL;'),'Dependencies');
  end;
  Check(TIntFunction(Symbol(lHandles[1],'NX_RuntimeInitializations'))()=0,'Premature initialization');
  WriteLn('PASS descriptors remain inactive until explicit startup');
end;
begin
  try
    if ParamStr(1)='link' then LinkProbe
    else if ParamStr(1)='descriptor' then DescriptorProbe
    else raise Exception.Create('Expected link or descriptor');
  except
    on E: Exception do begin WriteLn(E.Message); Halt(1); end;
  end;
end.
