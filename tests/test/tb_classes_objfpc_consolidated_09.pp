{ Consolidated classes regressions; original case IDs and assertions are retained. }
{ %NORUN }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case tmshlp1.pp }
{$push}



{$modeswitch multihelpers}



type
	tmshlp1_TMyObject = class
		procedure DoThis_1;
	end;
	tmshlp1_THelper1 = class helper for tmshlp1_TMyObject
		procedure DoThis_2;
	end;
	tmshlp1_THelper2 = class helper for tmshlp1_TMyObject
		procedure DoThis_3;
	end;

procedure tmshlp1_TMyObject.DoThis_1;
begin
end;

procedure tmshlp1_THelper1.DoThis_2;
begin
end;

procedure tmshlp1_THelper2.DoThis_3;
begin
end;

var
	tmshlp1_obj: tmshlp1_TMyObject;

{$pop}

{ Case tmshlp10.pp }
{$push}



{$modeswitch multihelpers}



type
	tmshlp10_TMyObject = class
		procedure DoThis(param: integer); overload;
	end;
	tmshlp10_THelper1 = class helper for tmshlp10_TMyObject
		procedure DoThis(param: string); overload;
	end;
	tmshlp10_THelper2 = class helper for tmshlp10_TMyObject
		procedure DoThis(param: pointer); overload;
	end;

procedure tmshlp10_TMyObject.DoThis(param: integer);
begin
end;

procedure tmshlp10_THelper1.DoThis(param: string);
begin
end;

procedure tmshlp10_THelper2.DoThis(param: pointer);
begin
end;

var
	tmshlp10_obj: tmshlp10_TMyObject;

{$pop}

{ Case tmshlp11.pp }
{$push}



{$modeswitch multihelpers}



type
	tmshlp11_TMyObject = class
		class function Create1: tmshlp11_TMyObject;
	end;
	tmshlp11_THelper1 = class helper for tmshlp11_TMyObject
		class function Create2: tmshlp11_TMyObject;
	end;
	tmshlp11_THelper2 = class helper for tmshlp11_TMyObject
		class function Create3: tmshlp11_TMyObject;
	end;

class function tmshlp11_TMyObject.Create1: tmshlp11_TMyObject;
begin
	result := tmshlp11_TMyObject.Create;
end;

class function tmshlp11_THelper1.Create2: tmshlp11_TMyObject;
begin
	result := tmshlp11_TMyObject.Create;
end;

class function tmshlp11_THelper2.Create3: tmshlp11_TMyObject;
begin
	result := tmshlp11_TMyObject.Create;
end;

var
	tmshlp11_obj: tmshlp11_TMyObject;

{$pop}

{ Case tmshlp13.pp }
{$push}



{$modeswitch multihelpers}



type
	tmshlp13_THelper1 = class helper for TObject
		class var field1: integer;
	end;
	tmshlp13_THelper2 = class helper for TObject
		class var field2: integer;
	end;


{$pop}

{ Case tmshlp14.pp }
{$push}



{$modeswitch multihelpers}



type
	tmshlp14_THelper1 = class helper for TObject
		type TInteger = integer;
	end;
	tmshlp14_THelper2 = class helper for TObject
		type TString = string;
	end;

var
	tmshlp14_obj: TObject;

{$pop}

{ Case tmshlp4.pp }
{$push}



{$modeswitch multihelpers}



type
	tmshlp4_TMyObject = class
		procedure DoThis_1;
	end;
	tmshlp4_THelperBase = class helper for tmshlp4_TMyObject
		procedure DoThis_4;
	end;
	tmshlp4_THelper1 = class helper(tmshlp4_THelperBase) for tmshlp4_TMyObject
		procedure DoThis_2;
	end;
	tmshlp4_THelper2 = class helper(tmshlp4_THelperBase) for tmshlp4_TMyObject
		procedure DoThis_3;
	end;

procedure tmshlp4_THelperBase.DoThis_4;
begin
	writeln('DoThis_4');
end;

procedure tmshlp4_TMyObject.DoThis_1;
begin
	writeln('DoThis_1');
end;

procedure tmshlp4_THelper1.DoThis_2;
begin
	writeln('DoThis_2');
end;

procedure tmshlp4_THelper2.DoThis_3;
begin
	writeln('DoThis_3');
end;

var
	tmshlp4_obj: tmshlp4_TMyObject;

{$pop}

{ Case tmshlp5.pp }
{$push}



{$modeswitch multihelpers}



type
	tmshlp5_TMyObject = class
		constructor Create1;
	end;
	tmshlp5_THelper1 = class helper for tmshlp5_TMyObject
		constructor Create2;
	end;
	tmshlp5_THelper2 = class helper for tmshlp5_TMyObject
		constructor Create3;
	end;

constructor tmshlp5_TMyObject.Create1;
begin
end;

constructor tmshlp5_THelper1.Create2;
begin
end;

constructor tmshlp5_THelper2.Create3;
begin
end;

var
	tmshlp5_obj: tmshlp5_TMyObject;

{$pop}

{ Case tmshlp6.pp }
{$push}



{$modeswitch multihelpers}



type
	tmshlp6_TMyObject = class
		m_num: integer;
		property num1: integer read m_num;
	end;
	tmshlp6_THelperBase = class helper for tmshlp6_TMyObject
		function GetNum: integer;
	end;
	tmshlp6_THelper1 = class helper(tmshlp6_THelperBase) for tmshlp6_TMyObject
		property num2: integer read GetNum;
	end;
	tmshlp6_THelper2 = class helper(tmshlp6_THelperBase) for tmshlp6_TMyObject
		property num3: integer read GetNum;
	end;

function tmshlp6_THelperBase.GetNum: integer;
begin
	result := m_num;
end;

var
	tmshlp6_obj: tmshlp6_TMyObject;
	tmshlp6_num: integer;

{$pop}

{ Case tmshlp9.pp }
{$push}



{$modeswitch multihelpers}



type
	tmshlp9_TMyObject = class
		procedure DoThis_1;
	end;
	tmshlp9_THelper1 = class helper for tmshlp9_TMyObject
		procedure DoThis_2;
	end;
	tmshlp9_THelper2 = class helper for tmshlp9_TMyObject
		procedure DoThis_3;
	end;

procedure tmshlp9_TMyObject.DoThis_1;
begin
end;

procedure tmshlp9_THelper1.DoThis_2;
begin
	DoThis_1;
end;

procedure tmshlp9_THelper2.DoThis_3;
begin
	DoThis_2;
end;

var
	tmshlp9_obj: tmshlp9_TMyObject;

{$pop}

begin

{ Case tmshlp1.pp }
{$push}

{$modeswitch multihelpers}
begin
	tmshlp1_obj := tmshlp1_TMyObject.Create;
	tmshlp1_obj.DoThis_1;
	tmshlp1_obj.DoThis_2;
	tmshlp1_obj.DoThis_3;
end;
{$pop}

{ Case tmshlp10.pp }
{$push}

{$modeswitch multihelpers}
begin
	tmshlp10_obj := tmshlp10_TMyObject.Create;
	tmshlp10_obj.DoThis(1);
	tmshlp10_obj.DoThis('string');
	tmshlp10_obj.DoThis(nil);
end;
{$pop}

{ Case tmshlp11.pp }
{$push}

{$modeswitch multihelpers}
begin
	tmshlp11_obj := tmshlp11_TMyObject.Create1;
	tmshlp11_obj := tmshlp11_TMyObject.Create2;
	tmshlp11_obj := tmshlp11_TMyObject.Create3;
end;
{$pop}

{ Case tmshlp13.pp }
{$push}

{$modeswitch multihelpers}
begin
	TObject.field1 := 1;
	TObject.field2 := 2;
end;
{$pop}

{ Case tmshlp14.pp }
{$push}

{$modeswitch multihelpers}
begin
	writeln(sizeof(TObject.TInteger));
	writeln(sizeof(TObject.TString));
end;
{$pop}

{ Case tmshlp4.pp }
{$push}

{$modeswitch multihelpers}
begin
	tmshlp4_obj := tmshlp4_TMyObject.Create;
	tmshlp4_obj.DoThis_1;
	tmshlp4_obj.DoThis_2;
	tmshlp4_obj.DoThis_3;
	tmshlp4_obj.DoThis_4;
end;
{$pop}

{ Case tmshlp5.pp }
{$push}

{$modeswitch multihelpers}
begin
	tmshlp5_obj := tmshlp5_TMyObject.Create1;
	tmshlp5_obj := tmshlp5_TMyObject.Create2;
	tmshlp5_obj := tmshlp5_TMyObject.Create3;
end;
{$pop}

{ Case tmshlp6.pp }
{$push}

{$modeswitch multihelpers}
begin
	tmshlp6_obj := tmshlp6_TMyObject.Create;
	// 2^3
	tmshlp6_obj.m_num := 2;
	tmshlp6_num := tmshlp6_obj.num1 * tmshlp6_obj.num2 * tmshlp6_obj.num3;
	writeln(tmshlp6_num);
end;
{$pop}

{ Case tmshlp9.pp }
{$push}

{$modeswitch multihelpers}
begin
	tmshlp9_obj := tmshlp9_TMyObject.Create;
	tmshlp9_obj.DoThis_3;
end;
{$pop}

end.
