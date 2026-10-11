{ Consolidated integers regressions; original case IDs and assertions are retained. }
{ %NORUN }
program nexus_consolidated_tests;
{$mode fpc}

{ Case tb0676.pp }
{$push}




{$warn 4110 error}


{$pop}

{ Case tb0706.pp }
{$push}


var
  tb0706_l: longint;

{$pop}

{ Case tw11619.pp }
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

{ Case tw12685.pp }
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

{ Case tw18512.pp }
{$push}


{$TypedAddress on}
var
    tw18512_p: ^integer;
    tw18512_c: char;

{$pop}

{ Case tw27811.pp }
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

{ Case tw31596.pp }
{$push}

var

 tw31596_offset : Integer;
 tw31596_o      : TObject;


{$pop}

begin

{ Case tb0676.pp }
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

{ Case tb0706.pp }
{$push}

begin
  volatile(tb0706_l) := 1;
end;
{$pop}

{ Case tw11619.pp }
{$push}
{$inline on}
{$EXTENDEDSYNTAX OFF}
BEGIN
   tw11619_IO:=tw11619_test;
END;
{$pop}

{ Case tw12685.pp }
{$push}

begin
end;
{$pop}

{ Case tw18512.pp }
{$push}
{$TypedAddress on}
begin
    // test that addr return untyped pointer in spite of $TypedAddress directive
    tw18512_p := addr(tw18512_c)
end;
{$pop}

{ Case tw27811.pp }
{$push}
{$optimization regvar on}
begin
end;
{$pop}

{ Case tw31596.pp }
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

end.
