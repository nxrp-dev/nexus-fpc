unit upackagebase;

{$mode objfpc}{$H+}

interface

type
  TPackageClass = class
    Value: LongInt;
    function ReadValue: LongInt; virtual;
  end;
  TPackageEnum = (peFirst, peSecond);
  TPackageRecord = record
    Text: AnsiString;
  end;

var
  PackageCounter: LongInt = 7;

resourcestring
  PackageText = 'package symbol probe';

function Add(Value: LongInt): LongInt;
function InlineValue(Value: LongInt): LongInt; inline;
function BaseCounter: Pointer; cdecl; public name 'NX_BaseCounter';
function BaseClass: Pointer; cdecl; public name 'NX_BaseClass';
function BaseRTTI: Pointer; cdecl; public name 'NX_BaseRTTI';
function BaseEnumRTTI: Pointer; cdecl; public name 'NX_BaseEnumRTTI';
function BaseRecordRTTI: Pointer; cdecl; public name 'NX_BaseRecordRTTI';
function BaseProc: Pointer; cdecl; public name 'NX_BaseProc';
function BaseResource: Pointer; cdecl; public name 'NX_BaseResource';

implementation

function HiddenHelper(Value: LongInt): LongInt;
begin
  Result:=Value+1000;
end;

function InlineValue(Value: LongInt): LongInt;
begin
  Result:=HiddenHelper(Value);
end;

function TPackageClass.ReadValue: LongInt;
begin
  Result:=Value+10;
end;

function Add(Value: LongInt): LongInt;
begin
  Inc(PackageCounter,Value);
  Result:=PackageCounter;
end;

function BaseCounter: Pointer; cdecl;
begin
  Result:=@PackageCounter;
end;

function BaseClass: Pointer; cdecl;
begin
  Result:=Pointer(TPackageClass);
end;

function BaseRTTI: Pointer; cdecl;
begin
  Result:=TypeInfo(TPackageClass);
end;

function BaseEnumRTTI: Pointer; cdecl;
begin
  Result:=TypeInfo(TPackageEnum);
end;

function BaseRecordRTTI: Pointer; cdecl;
begin
  Result:=TypeInfo(TPackageRecord);
end;

function BaseProc: Pointer; cdecl;
begin
  Result:=@Add;
end;

function BaseResource: Pointer; cdecl;
begin
  Result:=@PackageText;
end;

end.
