unit upackageconsumer;

{$mode objfpc}{$H+}

interface

uses upackagebase;

type
  TPackageDerived = class(TPackageClass)
    function ReadValue: LongInt; override;
  end;

function ConsumerAdd(Value: LongInt): LongInt; cdecl; public name 'NX_ConsumerAdd';
function ConsumerCounter: Pointer; cdecl; public name 'NX_ConsumerCounter';
function ConsumerClass: Pointer; cdecl; public name 'NX_ConsumerClass';
function ConsumerRTTI: Pointer; cdecl; public name 'NX_ConsumerRTTI';
function ConsumerEnumRTTI: Pointer; cdecl; public name 'NX_ConsumerEnumRTTI';
function ConsumerRecordRTTI: Pointer; cdecl; public name 'NX_ConsumerRecordRTTI';
function ConsumerProc: Pointer; cdecl; public name 'NX_ConsumerProc';
function ConsumerParent: Pointer; cdecl; public name 'NX_ConsumerParent';
function ConsumerInherits: LongInt; cdecl; public name 'NX_ConsumerInherits';
function ConsumerVirtual: LongInt; cdecl; public name 'NX_ConsumerVirtual';
function ConsumerManaged: LongInt; cdecl; public name 'NX_ConsumerManaged';
function ConsumerAlias: Pointer; cdecl; public name 'NX_ConsumerAlias';
function ConsumerResource: Pointer; cdecl; public name 'NX_ConsumerResource';
function ConsumerInline: LongInt; cdecl; public name 'NX_ConsumerInline';

implementation

function ConsumerAlias: Pointer; cdecl;
begin
  Result:=BaseCounter;
end;

function ConsumerResource: Pointer; cdecl;
begin
  Result:=@PackageText;
end;

function ConsumerInline: LongInt; cdecl;
begin
  Result:=InlineValue(17);
end;

function TPackageDerived.ReadValue: LongInt;
begin
  Result:=inherited ReadValue+100;
end;

function ConsumerAdd(Value: LongInt): LongInt; cdecl;
begin
  Result:=Add(Value);
end;

function ConsumerCounter: Pointer; cdecl;
begin
  Result:=@PackageCounter;
end;

function ConsumerClass: Pointer; cdecl;
begin
  Result:=Pointer(TPackageClass);
end;

function ConsumerRTTI: Pointer; cdecl;
begin
  Result:=TypeInfo(TPackageClass);
end;

function ConsumerEnumRTTI: Pointer; cdecl;
begin
  Result:=TypeInfo(TPackageEnum);
end;

function ConsumerRecordRTTI: Pointer; cdecl;
begin
  Result:=TypeInfo(TPackageRecord);
end;

function ConsumerProc: Pointer; cdecl;
begin
  Result:=@Add;
end;

function ConsumerParent: Pointer; cdecl;
begin
  Result:=Pointer(TPackageDerived.ClassParent);
end;

function ConsumerInherits: LongInt; cdecl;
begin
  Result:=Ord(TPackageDerived.InheritsFrom(TPackageClass));
end;

function ConsumerVirtual: LongInt; cdecl;
var
  { Exercise VMT dispatch without allocating an object or initializing the RTL. }
  Storage: array[0..63] of Pointer;
begin
  if TPackageDerived.InstanceSize>SizeOf(Storage) then
    Exit(-1);
  FillChar(Storage,SizeOf(Storage),0);
  Storage[0]:=Pointer(TPackageDerived);
  TPackageDerived(@Storage).Value:=23;
  Result:=TPackageClass(@Storage).ReadValue;
end;

function ConsumerManaged: LongInt; cdecl;
var
  Storage: TPackageRecord;
begin
  Initialize(Storage);
  Result:=Ord(Pointer(Storage.Text)=nil);
  Finalize(Storage);
end;

end.
