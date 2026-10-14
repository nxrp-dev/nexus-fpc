{ Consolidated records regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode delphi}
uses typinfo;

{ Case tw26075.pas }
{$push}



{$optimization off}



Type

 tw26075_PTypeInfoRec = Record
  FValue : PTypeInfo;
  Function QualifiedName : String;
 End;

Function tw26075_PTypeInfoRec.QualifiedName : String;
Begin
 Result := '';
End;

function tw26075_Test : Pointer;
Begin
 Result := nil;
End;

Var

 tw26075_p : PTypeInfo;


{$pop}

{ Case trtti10.pas }
{$push}






type
  trtti10_TFoo = record
  end;


{$pop}

{ Case trtti12.pas }
{$push}






type
  trtti12_PFoo = ^trtti12_TFoo;
  trtti12_TFoo = packed record
  public
    B: Byte;
    W: Word;
    L: LongWord;
    S: string;
    I: IInterface;
    A: TArray<byte>;
  end;

var
  trtti12_td: PTypeData;
  trtti12_id: PRecInitData;

{$pop}

begin

{ Case tw26075.pas }
{$push}

{$optimization off}
begin

 tw26075_PTypeInfoRec(tw26075_p).QualifiedName; // OK
 tw26075_PTypeInfoRec(tw26075_Test).QualifiedName; // OK
 tw26075_PTypeInfoRec(TypeInfo(String)).QualifiedName; // Internal error 200304235

end;
{$pop}

{ Case trtti10.pas }
{$push}

begin
  if GetTypeData(TypeInfo(trtti10_TFoo)).RecInitInfo = nil then
    Halt(1);
end;
{$pop}

{ Case trtti12.pas }
{$push}

begin
  trtti12_td := GetTypeData(TypeInfo(trtti12_TFoo));

  trtti12_id := trtti12_td.RecInitData;
  if trtti12_id.Terminator <> nil then
    Halt(1);

  if trtti12_td.TotalFieldCount <> 6 then
    Halt(2);

  if trtti12_id.ManagedFieldCount <> 3 then
    Halt(3);
end;
{$pop}

end.
