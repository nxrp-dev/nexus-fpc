{ Consolidated records regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode macpas}

{ Case tparray20.pas }
{$push}

{$packrecords 4}



   type
     tparray20_String32 = string[ 32];
     tparray20_String80 = string[ 80];
     tparray20_TDS = record
         ZZStyleName: packed array[0..24] of tparray20_String32;
       end;
     tparray20_TDSunp = record
         ZZStyleName: array[0..24] of tparray20_String32;
       end;
     tparray20_PDS = ^tparray20_TDS;

   var
     tparray20_DV: tparray20_PDS;

function tparray20_StyleNameToSongStyleNum (TheSTYName80: tparray20_String80): longint;
   var
     a: Integer;
begin
tparray20_StyleNameToSongStyleNum := 1;
for A := 1 to 24 do
   if Pos(tparray20_DV^.ZZStyleName[a], TheSTYName80) > 0 then
     begin
     tparray20_StyleNameToSongStyleNum := A;
     exit;
     end;
end;

var
 tparray20_i: integer;

{$pop}

{ Case tprec11.pas }
{$push}
{ from gpc testsuite, original name: waldek9b.pas }

{$ifdef fpc}

{$endif}


type tprec11_tr = record end;
     tprec11_tp = packed record
            i : tprec11_tr;
          end;
var tprec11_a : array [0..15] of tprec11_tp;
    tprec11_pa : packed array [0..15] of tprec11_tp;

{$pop}

{ Case tprec12.pas }
{$push}
{ from gpc tests, original name sam9.pas }

{$ifdef fpc}

{$endif}



type
  tprec12_e1 = (
    tprec12_enum000,
    tprec12_enum001,
    tprec12_enum002,
    tprec12_enum003,
    tprec12_enum004,
    tprec12_enum005,
    tprec12_enum006,
    tprec12_enum007,
    tprec12_enum008,
    tprec12_enum009,
    tprec12_enum010,
    tprec12_enum011,
    tprec12_enum012,
    tprec12_enum013,
    tprec12_enum014,
    tprec12_enum015,
    tprec12_enum016,
    tprec12_enum017,
    tprec12_enum018,
    tprec12_enum019,
    tprec12_enum020,
    tprec12_enum021,
    tprec12_enum022,
    tprec12_enum023,
    tprec12_enum024,
    tprec12_enum025,
    tprec12_enum026,
    tprec12_enum027,
    tprec12_enum028,
    tprec12_enum029,
    tprec12_enum030,
    tprec12_enum031,
    tprec12_enum032,
    tprec12_enum033,
    tprec12_enum034,
    tprec12_enum035,
    tprec12_enum036,
    tprec12_enum037,
    tprec12_enum038,
    tprec12_enum039,
    tprec12_enum040,
    tprec12_enum041,
    tprec12_enum042,
    tprec12_enum043,
    tprec12_enum044,
    tprec12_enum045,
    tprec12_enum046,
    tprec12_enum047,
    tprec12_enum048,
    tprec12_enum049,
    tprec12_enum050,
    tprec12_enum051,
    tprec12_enum052,
    tprec12_enum053,
    tprec12_enum054,
    tprec12_enum055,
    tprec12_enum056,
    tprec12_enum057,
    tprec12_enum058,
    tprec12_enum059,
    tprec12_enum060,
    tprec12_enum061,
    tprec12_enum062,
    tprec12_enum063,
    tprec12_enum064,
    tprec12_enum065,
    tprec12_enum066,
    tprec12_enum067,
    tprec12_enum068,
    tprec12_enum069,
    tprec12_enum070,
    tprec12_enum071,
    tprec12_enum072,
    tprec12_enum073,
    tprec12_enum074,
    tprec12_enum075,
    tprec12_enum076,
    tprec12_enum077,
    tprec12_enum078,
    tprec12_enum079,
    tprec12_enum080,
    tprec12_enum081,
    tprec12_enum082,
    tprec12_enum083,
    tprec12_enum084,
    tprec12_enum085,
    tprec12_enum086,
    tprec12_enum087,
    tprec12_enum088,
    tprec12_enum089,
    tprec12_enum090,
    tprec12_enum091,
    tprec12_enum092,
    tprec12_enum093,
    tprec12_enum094,
    tprec12_enum095,
    tprec12_enum096,
    tprec12_enum097,
    tprec12_enum098,
    tprec12_enum099,
    tprec12_enum100,
    tprec12_enum101,
    tprec12_enum102,
    tprec12_enum103,
    tprec12_enum104,
    tprec12_enum105,
    tprec12_enum106,
    tprec12_enum107,
    tprec12_enum108,
    tprec12_enum109,
    tprec12_enum110,
    tprec12_enum111,
    tprec12_enum112,
    tprec12_enum113,
    tprec12_enum114,
    tprec12_enum115,
    tprec12_enum116,
    tprec12_enum117,
    tprec12_enum118,
    tprec12_enum119,
    tprec12_enum120,
    tprec12_enum121,
    tprec12_enum122,
    tprec12_enum123,
    tprec12_enum124,
    tprec12_enum125,
    tprec12_enum126,
    tprec12_enum127,
    tprec12_enum128 { Remove this and it works !}
  );

  tprec12_r1 = 0 .. 128;

  tprec12_t1 = packed record { has to be packed }
    case integer of
        1: (f1: tprec12_e1);
        2: (f2: tprec12_r1);
      end;

var
  tprec12_v1: tprec12_t1;

procedure tprec12_foo;
begin
  tprec12_v1.f1 := tprec12_enum000;
  tprec12_v1.f2 := 127;
  tprec12_v1.f2 := 128;
end;


{$pop}

{ Case ttypedrecord3.pas }
{$push}


type ttypedrecord3_RGB = record red, green, blue:	integer end;
const ttypedrecord3_kRGBBlack: ttypedrecord3_RGB = ( red: 0; green: 0; blue: 0);

{$pop}

{ Case ttypedrecord4.pas }
{$push}

{ Mac Pascal uses commas as separators between record fields in typed constants }

type ttypedrecord4_RGB = record red, green, blue:	integer end;
const ttypedrecord4_kRGBBlack: ttypedrecord4_RGB = ( red: 0, green: 0, blue: 0);

{$pop}

begin

{ Case tparray20.pas }
{$push}

{$packrecords 4}
begin
  new(tparray20_dv);
  for tparray20_i := 1 to 24 do
    tparray20_tdsunp(tparray20_dv^).ZZStyleName[tparray20_i]:='MySong'+chr(tparray20_i+ord('A'));
  if (tparray20_StyleNameToSongStyleNum('MySongF') <> 5) then
    halt(1);
end;
{$pop}

{ Case tprec11.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
  pack (tprec11_a, 0, tprec11_pa);
  if sizeof(tprec11_a) <> 0 then
    halt(1);
  if (sizeof(tprec11_pa) <> 0) then
    halt(2);
  if (sizeof(tprec11_tr) <> 0) then
    halt(3);
  if (sizeof(tprec11_tp) <> 0) then
    halt(4);
  WriteLn ('OK')
end;
{$pop}

{ Case tprec12.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
  tprec12_foo;
  if tprec12_v1.f1 = tprec12_enum128 then
    writeln ( 'OK' )
  else
    begin
      writeln ( 'failed' );
      halt(1)
    end
end;
{$pop}

{ Case ttypedrecord3.pas }
{$push}

begin
end;
{$pop}

{ Case ttypedrecord4.pas }
{$push}

begin
end;
{$pop}

end.
