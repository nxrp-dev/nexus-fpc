{ Consolidated records regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode macpas}

{ Case tw13187.pas }
{$push}
{$ifdef FPC}

{$endif}
{$align power}

type
    tw13187_StrRec =
      record
        s1: string[ 10];
        s2: string[ 10];
      end;

{$pop}

{ Case tw15812.pas }
{$push}



type
  tw15812_Rec1Ptr = ^tw15812_Rec1;
  tw15812_Rec1 =
    record
      case boolean of
        False : ( f1: Integer);
        True : ( case boolean of
                    False: ( f2: Integer);
                    True : ( f3: Integer))
    end;
  tw15812_Rec2 =
    record
      case boolean of
        False : ( p1: tw15812_Rec1Ptr);
        True : ( p2: Pointer)
    end;

procedure tw15812_PP( theRec2: tw15812_Rec2; var theRec1: tw15812_Rec1);
  begin
    theRec1 := theRec2.p1^
  end;


{$pop}

{ Case tw7372.pas }
{$push}


var tw7372_r: record field: packed array [0..1] of byte; b:  byte; end;
procedure tw7372_p(a: pointer); begin end;

{$pop}

{ Case tw7568.pas }
{$push}



type
	tw7568_Point = record
		v: integer;
		h: integer;
	end;

procedure tw7568_Test
(
	arg1	: longint;
	arg2	: integer;
	arg3	: boolean;
	arg4	: longint;
	arg5	: longint;
	arg6	: longint;
	arg7	: longint;
	arg8	: longint;
	arg9	: longint;
	arg10: longint
);

label
	ErrExit;

var
	i, n: integer;
	p1, p2, unused1: tw7568_Point;
	dx, dy: Single;
	unused2, unused3: integer;
	unused4: longint;
begin
	arg4:= 1;
	n:= 0;
	dx:= 1.0;
	dy:= 1.0;
	p2.h:= 1;
	p2.v:= 2;

	for i:=0 TO arg4-1 do begin
		p1.h:=p2.h + round(3*dx);
		p1.v:=p2.v + round(3*dy);
		writeln('p1.h=', p1.h, ', p1.v=', p1.v);
                if (p1.h <> 4) then
                  halt(1);
	end;

	if n<>0 then goto ErrExit;

	ErrExit:
end;



{$pop}

{ Case tw9174.pas }
{$push}




type
	tw9174_SInt16 = integer;
	tw9174_Point = record
		case tw9174_SInt16 of
		0: (
			v: tw9174_SInt16;
			h: tw9174_SInt16;
		   );
		1: (
			vh: array [0..1] of tw9174_SInt16;
			);
	end;
	tw9174_PointPtr = ^tw9174_Point;
	tw9174_Rect = record
		case tw9174_SInt16 of
		0: (
			top: tw9174_SInt16;
			left: tw9174_SInt16;
			bottom: tw9174_SInt16;
			right: tw9174_SInt16;
		   );
		1: (
			topLeft: tw9174_Point;
			botRight: tw9174_Point;
		   );
	end;
	tw9174_RectPtr = ^tw9174_Rect;

var
	tw9174_gMeasStrs: packed array[1..64] of string[4];
	tw9174_gMeasStrRects: array[1..64] of tw9174_Rect;

var
  tw9174_i,tw9174_j,tw9174_k: longint;

{$pop}

begin

{ Case tw13187.pas }
{$push}
{$ifdef FPC}

{$endif}
{$align power}
begin
  writeln( 'SizeOf( StrRec) = ', SizeOf( tw13187_StrRec));
  if (sizeof(tw13187_strrec)<>24) then
    halt(1);
end;
{$pop}

{ Case tw15812.pas }
{$push}

begin
end;
{$pop}

{ Case tw7372.pas }
{$push}

begin tw7372_p(@tw7372_r.field[0]);
end;
{$pop}

{ Case tw7568.pas }
{$push}

begin
	tw7568_Test(0, 0, false, 1, 0, 0, 0, 0, 0, 0);
end;
{$pop}

{ Case tw9174.pas }
{$push}

begin
	writeln( 'SizeOf gMeasStrs)        = ', SizeOf( tw9174_gMeasStrs));
	writeln( 'SizeOf gMeasStrRects)    = ', SizeOf( tw9174_gMeasStrRects));
	writeln( 'Offset gMeasStrs[  1   ] = ', ptruint( @tw9174_gMeasStrs[      1]) -ptruint( @tw9174_gMeasStrs));
	writeln( 'Offset gMeasStrs[ 64, 4] = ', ptruint( @tw9174_gMeasStrs[ 64,  4]) - ptruint( @tw9174_gMeasStrs));
	writeln( 'Offset gMeasStrRects     = ', ptruint( @tw9174_gMeasStrRects)      - ptruint( @tw9174_gMeasStrs));
        tw9174_i:=1;
        tw9174_j:=64;
        tw9174_k:=4;
        if (SizeOf( tw9174_gMeasStrs) <> 320) or
           (SizeOf( tw9174_gMeasStrRects) <> 512) or
           (ptruint( @tw9174_gMeasStrs[      1]) - ptruint( @tw9174_gMeasStrs) <> 0) or
           (ptruint( @tw9174_gMeasStrs[ 64,  4])- ptruint( @tw9174_gMeasStrs)<>319) or
           (ptruint( @tw9174_gMeasStrs[      tw9174_i]) - ptruint( @tw9174_gMeasStrs) <> 0) or
           (ptruint( @tw9174_gMeasStrs[ tw9174_j,  tw9174_k])- ptruint( @tw9174_gMeasStrs)<>319) then
          halt(1);
end;
{$pop}

end.
