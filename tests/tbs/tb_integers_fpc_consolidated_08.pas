{ Consolidated integers regressions; original case IDs and assertions are retained. }
{ %NORUN }
program nexus_consolidated_tests;
{$mode fpc}

{ Case tb_integers_fpc_consolidated_06.pas }
{$push}
{ Consolidated integers regressions; original case IDs and assertions are retained. }




{ Case tb0676.pas }
{$push}




{$warn 4110 error}


{$pop}

{ Case tb0706.pas }
{$push}


var
  tb0706_l: longint;

{$pop}

{ Case tw11619.pas }
{$push}


{$inline on}

{$EXTENDEDSYNTAX OFF}
VAR
   tw11619_IO: WORD; { or LONGINT if wanted }

function tw11619_test: word; inline;
begin
  tw11619_test:=1;
  writeln(tw11619_io);
end;


{$pop}

{ Case tw12685.pas }
{$push}



const
tw12685_SE_SysEvtMask = $144;
tw12685_SE_SysEvtMask2 = $14422241;

type
tw12685_intPtr = ^integer;

function tw12685_GetSystemEventMask: INTEGER;
    begin
        tw12685_GetSystemEventMask := tw12685_intPtr(tw12685_SE_SysEvtMask)^;
        tw12685_GetSystemEventMask := tw12685_intPtr(tw12685_SE_SysEvtMask2)^;
    end;
procedure tw12685_StoreSystemEventMask (theMask: INTEGER);
    begin
        tw12685_intPtr(tw12685_SE_SysEvtMask)^ := theMask;
        tw12685_intPtr(tw12685_SE_SysEvtMask2)^ := theMask;
    end;


{$pop}

{ Case tw18512.pas }
{$push}


{$TypedAddress on}
var
    tw18512_p: ^integer;
    tw18512_c: char;

{$pop}

{ Case tw27811.pas }
{$push}


{$optimization regvar on}
procedure tw27811_test;
var m,n: integer;
begin
  for m := 100 downto 0 do begin
    prefetch (m);
  end;
end;


{$pop}

{ Case tw31596.pas }
{$push}

var

 tw31596_offset : Integer;
 tw31596_o      : TObject;


{$pop}


{$pop}

{ Case tpointermath3.pas }
{$push}




type
  tpointermath3_PByte = ^Byte;
var
  tpointermath3_PB: tpointermath3_PByte;

{$pop}

{ Case tthlp20.pas }
{$push}


{ test that "type helper" is parsed as "type alias" + "type name" if modeswitch typehelpers is not set }



type
  tthlp20_helper = LongInt;

  tthlp20_TTest = type tthlp20_helper;


{$pop}

begin

{ Case tb_integers_fpc_consolidated_06.pas }
{$push}

{$push}
{$warn 4110 error}
{$pop}
{$push}
{$pop}
{$push}
{$inline on}
{$EXTENDEDSYNTAX OFF}
{$pop}
{$push}
{$pop}
{$push}
{$TypedAddress on}
{$pop}
{$push}
{$optimization regvar on}
{$pop}
{$push}
{$pop}
begin

{ Case tb0676.pas }
{$push}
{$warn 4110 error}
begin
  SwapEndian(UInt16($1234));
  SwapEndian(Int16($8765));
  SwapEndian(UInt32($12345678));
  SwapEndian(Int32($87654321));
  SwapEndian(UInt64($1234567887654321));
  SwapEndian(Int64($8765432112345678));
end;
{$pop}

{ Case tb0706.pas }
{$push}

begin
  volatile(tb0706_l) := 1;
end;
{$pop}

{ Case tw11619.pas }
{$push}
{$inline on}
{$EXTENDEDSYNTAX OFF}
BEGIN
   tw11619_IO:=tw11619_test;
END;
{$pop}

{ Case tw12685.pas }
{$push}

begin
end;
{$pop}

{ Case tw18512.pas }
{$push}
{$TypedAddress on}
begin
    // test that addr return untyped pointer in spite of $TypedAddress directive
    tw18512_p := addr(tw18512_c)
end;
{$pop}

{ Case tw27811.pas }
{$push}
{$optimization regvar on}
begin
end;
{$pop}

{ Case tw31596.pas }
{$push}

begin

 // OK
 tw31596_o := TObject(1);

 tw31596_offset := PtrInt(IInterface(TInterfacedObject(tw31596_o))) - 1;
 //

 // project1.lpr(17,19) Error: Internal error 121120001
 tw31596_offset := PtrInt(IInterface(TInterfacedObject(1))) - 1;
end;
{$pop}

end;
{$pop}

{ Case tpointermath3.pas }
{$push}

begin
  // in FPC/ObjFPC mode pointer math is ON by default
  tpointermath3_PB := tpointermath3_PB + 1;
  WriteLn(tpointermath3_PB[1]);
end;
{$pop}

{ Case tthlp20.pas }
{$push}

begin

end;
{$pop}

end.
