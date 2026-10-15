{ %norun }
{ Consolidated feature cases; original case IDs and settings are retained below. }
{$mode fpc}


{ Source group: tb_arrays_default_compile_01.pas }
{$push}

{ Case tw38051.pas }
{$push}
const tw38051_cchr = chr(12); { Ok }

type tw38051_tcha = ord(3)..ord(12); { Ok }
type tw38051_tchz = #3..#12; { Ok }
type tw38051_tcho = char(3)..char(12);{ Ok }
type tw38051_tchr = chr(3)..chr(12); { Error: Identifier not found "chr" }

type tw38051_tarrchr = array [chr(3)..chr(12)] of char; { Ok }

var tw38051_cz : #3..#12; { Ok }
var tw38051_ch : chr(3)..chr(12); { Error: Identifier not found "chr" }

var tw38051_c : char;
{$pop}

{ Case tw38054.pas }
{$push}
const
   tw38054_l = high(ptrint);	//   2000  <-->  2100
type
   tw38054_t = array[ 1..tw38054_l ]of int8;	//   1.95  <-->  2.05  GiBy
var
   tw38054_p: ^tw38054_t;
{$pop}


{$pop}

{ Source group: tb_records_default_compile_01.pas }
{$push}

{ Case tb0589.pas }
{$push}
type
  tb0589_ttest = record
    tb0589_f: array of tb0589_ttest;
  end;
{$pop}

{ Case tw15592.pas }
{$push}
TYPE
  tw15592_trtime = Record
    tw15592_rtday : Integer;
  end;
  tw15592_ttimerange = Record
    tw15592_trflags : Integer;
    tw15592_trtime : tw15592_trtime;
    case trType : Integer of
     0 : (trTime2 : tw15592_trtime);
     1 : (trMinutes : Integer);
  end;
{$pop}

{ Case tw37779.pas }
{$push}
type
  tw37779_complex = record
    tw37779_re : Double;
    tw37779_im : Double;
  end;
  tw37779_tcomplexarray = array of tw37779_complex;
  tw37779_tcomplexarrayarray = array of tw37779_tcomplexarray;

var
  tw37779_mc: array of array of array of array of tw37779_tcomplexarrayarray;
{$pop}


{$pop}

{ Source group: tb_range_expressions_default_compile_01.pas }
{$push}

{ Case tw11349.pas }
{$push}
{$R+,Q+}

const
  tw11349_ws_border = DWORD($800000);

var
  tw11349_style: Cardinal;
{$pop}

{ Case tw34543.pas }
{$push}
{$r+}
procedure tw34543_range_check_fail;
var tw34543_v : word;
    tw34543_vto : word;
    tw34543_vno : word;
begin
     tw34543_vto:=3;
     tw34543_vno:=0;
     for tw34543_v:=tw34543_vno to tw34543_vto do {Error: range check error while evaluating constants (-1 must be between 0 and 65535)}
     begin
     end;
end;
{$pop}


{$pop}

begin
  { Source group: tb_arrays_default_compile_01.pas }
  {$push}


begin
  { Case tw38051.pas }
  {$push}

  begin
tw38051_c:=chr(12); { Ok }
  end;
  {$pop}

  { Case tw38054.pas }
  {$push}

  begin
new(tw38054_p);
   writeln( sizeof(tw38054_p^) );
   tw38054_p^[tw38054_l]:=0;  writeln(tw38054_p^[tw38054_l])
  end;
  {$pop}


end;
  {$pop}

  { Source group: tb_records_default_compile_01.pas }
  {$push}


begin
  { Case tw37779.pas }
  {$push}

  begin
tw37779_mc := nil;
  tw37779_mc := Copy(tw37779_mc);
  end;
  {$pop}


end;
  {$pop}

  { Source group: tb_range_expressions_default_compile_01.pas }
  {$push}


begin
  { Case tw11349.pas }
  {$push}
{$R+,Q+}
begin
  tw11349_style := 0;
  tw11349_style := tw11349_style and not tw11349_ws_border;
end;
  {$pop}

  { Case tw34543.pas }
  {$push}
{$R+}
begin
end;
  {$pop}


end;
  {$pop}

end.
