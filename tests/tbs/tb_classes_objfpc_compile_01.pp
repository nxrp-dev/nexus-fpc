{ Classes regression cases; original case IDs are retained below. }
{ %NORUN }

{ Case tb0526.pp }
{$push}
{$mode objfpc}
type
  tb0526_tmyclass = class
  protected
    tb0526_field1 {$IFDEF DUMMY}, tb0526_field2 {$ENDIF} : Boolean;
    procedure tb0526_proc;
  end;

procedure tb0526_tmyclass.tb0526_proc;
begin
  tb0526_field1:=True;
end;
{$pop}

{ Case tb0649.pp }
{$push}
{$mode objfpc}

type
  tb0649_tenum = (
    eOne,
    eTwo,
    eThree
  );

  tb0649_tenumset = set of tb0649_tenum;

  tb0649_tbyteset = set of Byte;

  tb0649_ttest = class
  end;

operator + (aLeft: tb0649_ttest; tb0649_aright: array of Byte): tb0649_ttest;
begin
  Writeln('Array of Byte');
  Result := aLeft;
end;

operator + (aLeft: tb0649_ttest; tb0649_aright: tb0649_tbyteset): tb0649_ttest;
begin
  Writeln('Set of Byte');
  Result := aLeft;
end;

operator + (aLeft: tb0649_ttest; tb0649_aright: array of tb0649_tenum): tb0649_ttest;
begin
  Writeln('Array of TEnum');
  Result := aLeft;
end;

operator + (aLeft: tb0649_ttest; tb0649_aright: tb0649_tenumset): tb0649_ttest;
begin
  Writeln('Set of TEnum');
  Result := aLeft;
end;

var
  tb0649_t: tb0649_ttest;
{$pop}

{ Case tw20119.pp }
{$push}
{$mode objfpc}
type
  tw20119_t = class
  private
    tw20119_f1: Integer; static;
    tw20119_f2: Integer; static;
  end;
{$pop}

{ Case tw22593.pp }
{$push}
{$ifdef fpc}
{$mode objfpc}
{$endif}

type
  tw22593_tc = class
  end;
  tw22593_tcc = class of tw22593_tc;
  tw22593_tc3 = class;

  tw22593_tprec = ^tw22593_trec;

  tw22593_tc2 = class
    constructor create(c: tw22593_tcc = nil; tw22593_c3: tw22593_tc3 = nil; tw22593_r: tw22593_tprec = nil);
  end;

  tw22593_trec = record
  end;

  tw22593_tc3 = class
  end;

constructor tw22593_tc2.create(c: tw22593_tcc = nil; tw22593_c3: tw22593_tc3 = nil; tw22593_r: tw22593_tprec = nil);
begin
end;
{$pop}

{ Case tw26976.pp }
{$push}
{$MODE OBJFPC}

type
   tw26976_ttest = class end;

procedure tw26976_e(Arg1: array of UTF8String);
begin end;

procedure tw26976_e(Arg1: array of tw26976_ttest);
begin end;
{$pop}

{ Case tw27348.pp }
{$push}
{$mode objfpc}

type
  tw27348_trect = record
    tw27348_xyz: LongInt;
  end;

  tw27348_tcontrol = class
  end;

  tw27348_twincontrol = class(tw27348_tcontrol)
    procedure tw27348_aligncontrols(AControl: tw27348_tcontrol; var tw27348_remainingclientrect: tw27348_trect);
  end;

  tw27348_talign = (
    alNone
  );

{ TWinControl }

procedure tw27348_twincontrol.tw27348_aligncontrols(AControl: tw27348_tcontrol;
  var tw27348_remainingclientrect: tw27348_trect);

  procedure tw27348_doposition(Control: tw27348_tcontrol; tw27348_aalign: tw27348_talign; tw27348_acontrolindex: Integer);

    function tw27348_constraintheight(NewHeight: integer): Integer;
    begin
      Result:=NewHeight;
    end;

    procedure tw27348_constraintheight(var NewTop, NewHeight: integer);
    begin
      NewHeight:=tw27348_constraintheight(NewHeight);
    end;

  begin

  end;

begin

end;
{$pop}

{ Case tw41504b.pp }
{$push}
{$mode objfpc}

type
  tw41504b_ttest = class
    procedure tw41504b_test; virtual; abstract;
  end;

  tw41504b_ttest2 = type tw41504b_ttest;
{$pop}

begin
  { Case tb0649.pp }
  {$push}

  begin
tb0649_t := tb0649_t + [1, 2, 3];
  tb0649_t := tb0649_t + [eOne, eTwo];
  end;
  {$pop}

  { Case tw26976.pp }
  {$push}

  begin
tw26976_e(['aa']); // Incompatible types: got "Constant String" expected "TTest"
  end;
  {$pop}

end.
