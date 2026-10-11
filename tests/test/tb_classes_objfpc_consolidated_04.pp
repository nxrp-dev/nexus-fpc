{ Consolidated classes regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}
{$modeswitch prefixedattributes}
uses typinfo;

{ Case tcustomattr1.pp }
{$push}


{$H+}
{$modeswitch prefixedattributes}



type

  { tmyt }

  tcustomattr1_tmyt = class(TCustomAttribute)
    constructor create;
  end;

type
  [tcustomattr1_Tmyt]
  tcustomattr1_TMyObject = class(TObject)
  end;

var
  tcustomattr1_at: PAttributeTable;
  tcustomattr1_AClassAttribute: TCustomAttribute;

{ tmyt }

constructor tcustomattr1_tmyt.create;
begin
  //
end;


{$pop}

{ Case tcustomattr11.pp }
{$push}



{$modeswitch prefixedattributes}



type
  tcustomattr11_TTest = class(TCustomAttribute)
    constructor Create;
  end;

  tcustomattr11_TTestAttribute = class(TCustomAttribute)
    constructor Create;
  end;

  { the attribute with the Attribute suffix is preferred }
  [tcustomattr11_TTest]
  tcustomattr11_TTestObj = class

  end;

constructor tcustomattr11_TTestAttribute.Create;
begin

end;

constructor tcustomattr11_TTest.Create;
begin

end;

var
  tcustomattr11_at: PAttributeTable;
  tcustomattr11_attr: TCustomAttribute;


{$pop}

{ Case tcustomattr6.pp }
{$push}


{$H+}
{$modeswitch prefixedattributes}



type

  { tmyt }

  tcustomattr6_TMyt = class(TCustomAttribute)
    constructor create;
  end;

type

  { TMyObject }

  tcustomattr6_TMyObject = class(TObject)
  private
    FInt: integer;
  published
    [tcustomattr6_TMyt]
    property PublicInt: integer read FInt;
  end;

constructor tcustomattr6_TMyt.create;
begin

end;


var
  tcustomattr6_pi: PPropInfo;
  tcustomattr6_AClassAttribute: TCustomAttribute;

{$pop}

begin

{ Case tcustomattr1.pp }
{$push}

{$H+}
{$modeswitch prefixedattributes}
begin
  tcustomattr1_at := GetAttributeTable(tcustomattr1_TMyObject.ClassInfo);
  if not assigned(tcustomattr1_at) then
    halt(1);
  if tcustomattr1_at^.AttributeCount<>1 then
    halt(2);

  tcustomattr1_AClassAttribute := GetAttribute(tcustomattr1_at,0);
  if tcustomattr1_AClassAttribute = nil then
    halt(3);
  writeln('ok');
end;
{$pop}

{ Case tcustomattr11.pp }
{$push}

{$modeswitch prefixedattributes}
begin
  tcustomattr11_at := GetAttributeTable(TypeInfo(tcustomattr11_TTestObj));
  if not Assigned(tcustomattr11_at) then
    Halt(1);
  if tcustomattr11_at^.AttributeCount <> 1 then
    Halt(2);

  tcustomattr11_attr := GetAttribute(tcustomattr11_at, 0);
  if not Assigned(tcustomattr11_attr) then
    Halt(3);
  if not (tcustomattr11_attr is tcustomattr11_TTestAttribute) then
    Halt(4);
  Writeln('ok');
end;
{$pop}

{ Case tcustomattr6.pp }
{$push}

{$H+}
{$modeswitch prefixedattributes}
begin
  tcustomattr6_pi := GetPropInfo(tcustomattr6_TMyObject.ClassInfo,'PublicInt');
  if not Assigned(tcustomattr6_pi^.AttributeTable) then
    Halt(1);
  if tcustomattr6_pi^.AttributeTable^.AttributeCount <> 1 then
    Halt(2);

  tcustomattr6_AClassAttribute := GetPropAttribute(tcustomattr6_pi,0) as TCustomAttribute;
  if tcustomattr6_AClassAttribute = nil then
    halt(3);

  writeln('ok');

end;
{$pop}

end.
