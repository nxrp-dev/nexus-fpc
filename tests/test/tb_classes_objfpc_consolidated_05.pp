{ Consolidated classes regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}
uses typinfo;

{ Case texrtti18.pp }
{$push}




{ Check that the class RTTI does not have information about array properties }

type
  {$RTTI EXPLICIT
    FIELDS([vcPublic])
    PROPERTIES([vcPublic,vcPublished])
    METHODS([vcPublic,vcPublished])
  }
  texrtti18_TTestClass = class
  public
    fa:integer;
    function MyMethod(const arg1: Integer): Integer;
    property TestIProp[const i: Longint]: Integer read MyMethod;
  published
    property TestProp: Integer read fa;
  end;

function texrtti18_TTestClass.MyMethod(const arg1: Integer): Integer;
begin
  Result := arg1;
end;

var
  texrtti18_pcd: PClassData;

{$pop}

{ Case texrtti19.pp }
{$push}




{ Check that extended RTTI has information about array properties }

type
  {$RTTI EXPLICIT
    FIELDS([vcPublic])
    PROPERTIES([vcPublic,vcPublished])
    METHODS([vcPublic,vcPublished])
  }
  texrtti19_TTestClass = class
  public
    fa:integer;
    function MyMethod(const arg1: Integer): Integer;
    property TestIProp[const i: Longint]: Integer read MyMethod;
    property TestProp: Integer read fa;
  end;

function texrtti19_TTestClass.MyMethod(const arg1: Integer): Integer;
begin
  Result := arg1;
end;

var
  texrtti19_pcd: PClassData;

{$pop}

{ Case texrtti20.pp }
{$push}



type
{$RTTI EXPLICIT
FIELDS([vcPublic])
PROPERTIES([vcPublic,vcPublished])
METHODS([vcPublic,vcPublished])}
  texrtti20_TPropClass=class
    private
      FValue: Integer;
      class var
        FClassValue: Integer;
    public
      property InstanceProp: Integer read FValue;
      class property ClassProp: Integer read FClassValue;
  end;

var
  texrtti20_cd:PClassData;

{$pop}

{ Case trtti26.pp }
{$push}


{$H+}



type
  {$M+}
  trtti26_TTest = class
  published
    procedure Test(aArg1: LongInt);
    procedure Test2(aArg1: String);
  end;

procedure trtti26_TTest.Test(aArg1: LongInt);
begin

end;

procedure trtti26_TTest.Test2(aArg1: String);
begin

end;

var
  trtti26_vmt: PVmt;
  trtti26_mt: PVmtMethodTable;
  trtti26_me: PVmtMethodEntry;
  trtti26_m: TMethod;
  trtti26_t: trtti26_TTest;

{$pop}

begin

{ Case texrtti18.pp }
{$push}

{$RTTI EXPLICIT
    FIELDS([vcPublic])
    PROPERTIES([vcPublic,vcPublished])
    METHODS([vcPublic,vcPublished])
  }
begin
  texrtti18_pcd:=PClassData(GetTypeData(TypeInfo(texrtti18_TTestClass)));
  WriteLn(texrtti18_pcd^.PropertyTable^.PropCount);
  if texrtti18_pcd^.PropertyTable^.PropCount <> 1 then
    Halt(1);
  if assigned(texrtti18_pcd^.PropertyTable^.Prop[0]^.PropParams) then
    Halt(2);
  WriteLn('Ok');
end;
{$pop}

{ Case texrtti19.pp }
{$push}

{$RTTI EXPLICIT
    FIELDS([vcPublic])
    PROPERTIES([vcPublic,vcPublished])
    METHODS([vcPublic,vcPublished])
  }
begin
  texrtti19_pcd:=PClassData(GetTypeData(TypeInfo(texrtti19_TTestClass)));
  if texrtti19_pcd^.ExRTTITable^.PropCount <> 2 then
    Halt(1);
  if not assigned(texrtti19_pcd^.ExRTTITable^.Prop[0]^.Info^.PropParams) then
    Halt(2);
  if texrtti19_pcd^.ExRTTITable^.Prop[0]^.Info^.PropParams^.Count<>1 then
    Halt(3);
  if texrtti19_pcd^.ExRTTITable^.Prop[0]^.Info^.PropParams^.Params[0].Name<>'i' then
    Halt(4);
  if not (pfconst in texrtti19_pcd^.ExRTTITable^.Prop[0]^.Info^.PropParams^.Params[0].flags) then
    Halt(5);
  if texrtti19_pcd^.ExRTTITable^.Prop[0]^.Info^.PropParams^.Params[0].ParamType^^.Name<>'LongInt' then
    Halt(6);
  if assigned(texrtti19_pcd^.ExRTTITable^.Prop[1]^.Info^.PropParams) then
    Halt(7);
  WriteLn('Ok');
end;
{$pop}

{ Case texrtti20.pp }
{$push}

{$RTTI EXPLICIT
FIELDS([vcPublic])
PROPERTIES([vcPublic,vcPublished])
METHODS([vcPublic,vcPublished])}
begin
  texrtti20_cd:=PClassData(GetTypeData(TypeInfo(texrtti20_TPropClass)));
  if not assigned(texrtti20_cd^.ExRTTITable) then
    Halt(1);
  if texrtti20_cd^.ExRTTITable^.PropCount<>2 then
    Halt(2);
  if (texrtti20_cd^.ExRTTITable^.Prop[0]^.Info^.Name<>'InstanceProp') or
     (texrtti20_cd^.ExRTTITable^.Prop[0]^.Info^.IsStatic<>False) then
    Halt(3);
  if (texrtti20_cd^.ExRTTITable^.Prop[1]^.Info^.Name<>'ClassProp') or
     (texrtti20_cd^.ExRTTITable^.Prop[1]^.Info^.IsStatic<>True) then
    Halt(3);
  WriteLn('ok');
end;
{$pop}

{ Case trtti26.pp }
{$push}

{$H+}
{$M+}
begin
  trtti26_t := trtti26_TTest.Create;
  trtti26_vmt := PVmt(trtti26_TTest);
  trtti26_mt := PVmtMethodTable(trtti26_vmt^.vMethodTable);
  if trtti26_mt^.Count <> 2 then
    Halt(1);
  trtti26_me := trtti26_mt^.Entry[0];
  if trtti26_me^.Name^ <> 'Test' then
    Halt(2);
  trtti26_m := TMethod(@trtti26_t.Test);
  if trtti26_me^.CodeAddress <> trtti26_m.Code then
    Halt(3);
  if trtti26_t.MethodAddress('Test') <> trtti26_m.Code then
    Halt(4);
  trtti26_me := trtti26_mt^.Entry[1];
  if trtti26_me^.Name^ <> 'Test2' then
    Halt(5);
  trtti26_m := TMethod(@trtti26_t.Test2);
  if trtti26_me^.CodeAddress <> trtti26_m.Code then
    Halt(6);
  if trtti26_t.MethodAddress('Test2') <> trtti26_m.Code then
    Halt(7);
end;
{$pop}

end.
