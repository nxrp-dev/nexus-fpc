{ Consolidated classes regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode delphi}
uses typinfo;

{ Case thlp38.pas }
{$push}
{ the parent in the RTTI of a non derived helper is Nil, otherwise it is the
  typeinfo of the parent helper; also the type info of the extended type is
  available through ExtendedInfo }


{$ifdef fpc}
  
{$endif}



type
  thlp38_TTest = class

  end;

  thlp38_TTestHelper = class helper for thlp38_TTest
  end;

  thlp38_TTestHelperSub = class helper(thlp38_TTestHelper) for thlp38_TTest
  end;

var
  thlp38_titest, thlp38_titesthelper, thlp38_titesthelpersub: PTypeInfo;
  thlp38_td: PTypeData;
  thlp38_ti: PTypeInfo;

{$pop}

{ Case tmoperator10.pas }
{$push}






type
  tmoperator10_TFoo = record
  private
    class operator Initialize(var aFoo: tmoperator10_TFoo);
  end;
  tmoperator10_TFooArray = array of tmoperator10_TFoo;

class operator tmoperator10_TFoo.Initialize(var aFoo: tmoperator10_TFoo);
begin
end;


{$pop}

{ Case trtti16.pas }
{$push}






type
  trtti16_TFoo = class
    B: Byte;
    W: Word;
    L: LongWord;
    S: string;
    I: IInterface;
    A: TArray<byte>;
  end;

  trtti16_TBoo = object
    B: Byte;
    W: Word;
    L: LongWord;
    S: string;
    I: IInterface;
    A: TArray<byte>;
  end;

  trtti16_TBoo2 = object(trtti16_TBoo)
    S2: string;
    B2: Byte;
  end;

var
  trtti16_td: PTypeData;
  trtti16_vmt: PVmt;
  trtti16_rid: PRecInitData;

{$pop}

begin

{ Case thlp38.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
  thlp38_titest := TypeInfo(thlp38_TTest);
  thlp38_titesthelper := TypeInfo(thlp38_TTestHelper);
  thlp38_titesthelpersub := TypeInfo(thlp38_TTestHelperSub);

  if thlp38_titesthelper^.Kind <> tkHelper then begin
    Writeln('Type is not a helper');
    Halt(1);
  end;
  if thlp38_titesthelpersub^.Kind <> tkHelper then begin
    Writeln('Type is not a helper');
    Halt(2);
  end;

  thlp38_td := GetTypeData(thlp38_titesthelper);
  if thlp38_td^.ExtendedInfo <> thlp38_titest then begin
    Writeln('Extends wrong type');
    Halt(4);
  end;

  thlp38_td := GetTypeData(thlp38_titesthelpersub);
  if thlp38_td^.ExtendedInfo <> thlp38_titest then begin
    Writeln('Extends wrong type');
    Halt(6);
  end;
  if thlp38_td^.HelperParent <> thlp38_titesthelper then begin
    Writeln('Wrong parent of helper');
    Halt(7);
  end;

  Writeln('ok');
end;
{$pop}

{ Case tmoperator10.pas }
{$push}

begin
  if GetTypeData(TypeInfo(tmoperator10_TFooArray))^.ElType = nil then
    Halt(1);
  if GetTypeData(TypeInfo(tmoperator10_TFooArray))^.ElType2 = nil then
    Halt(2);
end;
{$pop}

{ Case trtti16.pas }
{$push}

begin
  trtti16_td := GetTypeData(TypeInfo(trtti16_TFoo));
  trtti16_vmt := PVmt(trtti16_td^.ClassType);
  trtti16_rid := PRecInitData(GetTypeData(trtti16_vmt.vInitTable));
  if trtti16_rid^.ManagedFieldCount <> 3 then
    Halt(1);

  trtti16_td := GetTypeData(TypeInfo(trtti16_TBoo));
  if trtti16_td^.TotalFieldCount <> 6 then
    Halt(2);

  trtti16_rid := trtti16_td.RecInitData;
  if trtti16_rid^.ManagedFieldCount <> 3 then
    Halt(3);

  trtti16_td := GetTypeData(TypeInfo(trtti16_TBoo2));
  if trtti16_td^.TotalFieldCount <> 3 then
    Halt(4);

  trtti16_rid := trtti16_td.RecInitData;
  if trtti16_rid^.ManagedFieldCount <> 2 then
    Halt(5);
end;
{$pop}

end.
