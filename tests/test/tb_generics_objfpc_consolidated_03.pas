{ Consolidated generics regressions; original case IDs and assertions are retained. }
{ %NORUN }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case tgenconst16.pas }
{$push}


{$modeswitch advancedrecords}
{
  various operator tests
}


type
  tgenconst16_Day = (tgenconst16_mon,tgenconst16_tue,tgenconst16_wed,tgenconst16_thu,tgenconst16_fri,tgenconst16_sat,tgenconst16_sun);
  tgenconst16_Days = set of tgenconst16_Day;
  generic tgenconst16_TSet<const I: tgenconst16_Days> = record
    const
      d0 = I + I;   // Union
      d1 = I - I;   // Difference
      d2 = I * I;   // Intersection
      d3 = I >< I;  // Symmetric difference
      d4 = I <= I;  // Contains
      d5 = tgenconst16_mon in I;
  end;
  generic tgenconst16_TArray<const I: integer> = record
    type
      t0 = array[0..I - 1] of integer;
      t1 = array[0..high(I)] of integer;
      t2 = array[0..low(I)] of integer;
      t3 = array[0..sizeof(I)] of integer;
    public
      d0: array[0..I - 1] of integer;
      d1: array[0..high(I)] of integer;
      d2: array[0..low(I)] of integer;
      d3: array[0..sizeof(I)] of integer;
  end;
  generic tgenconst16_TUnaryOp<const I: integer> = record
    const
      d0 = -I;
      d1 = +I;
      d2 = not I;
  end;
  generic tgenconst16_TBinaryOp<const I: integer> = record
    const
      // Arithmetic operators
      // https://freepascal.org/docs-html/ref/refsu45.html
      d0 = I + I;
      d1 = I - I;
      d2 = I * I;
      d3 = I / I;
      d4 = I div I;
      d5 = I mod I;
      // Boolean operators
      // https://freepascal.org/docs-html/ref/refsu47.html
      d6 = I and I;
      d7 = I or I;
      d8 = I xor I;
      // Logical operators
      // https://freepascal.org/docs-html/ref/refsu46.html
      d9 = I shl I;
      d10 = I shr I;
      d11 = I << I;
      d12 = I >> I;
      // Relational operators
      // https://freepascal.org/docs-html/ref/refsu50.html#x153-17500012.8.6
      d13 = I <> I;
      d14 = I < I;
      d15 = I > I;
      d16 = I <= I;
      d17 = I >= I;
      d18 = I = I;
  end;
  generic tgenconst16_TOther<const I: integer> = record
    procedure DoThis(param: integer = I);
  end;

procedure tgenconst16_TOther.DoThis(param: integer = I);
begin
  writeln(param, ' default:', I);
end;


{$pop}

{ Case tgenconst17.pas }
{$push}


{$modeswitch advancedrecords}
{
  testing range checking for arrays and for-loops
}



type
	generic tgenconst17_TStaticList<T; const tgenconst17_Length: SizeUInt> = record
	  Values: array[0..tgenconst17_Length - 1] of T;
	  procedure Display;
	end;

procedure tgenconst17_TStaticList.Display;
var
	I, n: SizeUInt;
begin
  for I := 0 to tgenconst17_Length - 1 do
  	WriteLn(Values[I]);
end;

var
	tgenconst17_list: specialize tgenconst17_TStaticList<Integer, 20>;

{$pop}

{ Case tgenconst3.pas }
{$push}


{$modeswitch advancedrecords}
{
  test integer constants in static array ranges
}


type
	generic tgenconst3_TList<T;const tgenconst3_U:integer> = record
		const
			max = tgenconst3_U;
		public
			m_list: array[0..max-1] of T;
	end;

var
	tgenconst3_list: specialize tgenconst3_TList<integer,128>;

{$pop}

{ Case tgeneric131.pas }
{$push}





{$modeswitch advancedrecords}

type
  generic tgeneric131_TCurve<T> = record
    Parameters: T;
    function Sample1(Progress: Double): LongInt;
    function Sample2(Progress: Double): LongInt;
  end;

function tgeneric131_TCurve.Sample1(Progress: Double): LongInt;
begin
  Result := Parameters.Evaluate(Progress);
end;

function tgeneric131_TCurve.Sample2(Progress: Double): LongInt;
begin
  Result := Parameters.Evaluate2();
end;


{$pop}

{ Case tgeneric86.pas }
{$push}




{$H+}
{$modeswitch advancedrecords}

type
  generic tgeneric86_TTest<T> = record
  type
    PTest = ^tgeneric86_TTest;
  end;


{$pop}

begin

{ Case tgenconst16.pas }
{$push}

{$modeswitch advancedrecords}
begin
end;
{$pop}

{ Case tgenconst17.pas }
{$push}

{$modeswitch advancedrecords}
begin
end;
{$pop}

{ Case tgenconst3.pas }
{$push}

{$modeswitch advancedrecords}
begin
end;
{$pop}

{ Case tgeneric131.pas }
{$push}

{$modeswitch advancedrecords}
begin
end;
{$pop}

{ Case tgeneric86.pas }
{$push}

{$H+}
{$modeswitch advancedrecords}
begin

end;
{$pop}

end.
