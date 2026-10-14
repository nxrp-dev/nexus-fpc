{ %norun }
{ Consolidated feature cases; original case IDs and settings are retained below. }
{$mode objfpc}
{$modeswitch advancedrecords}

{ Source group: tb_classes_objfpc_compile_01.pas }
{$push}

{ Case tb0526.pas }
{$push}

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

{ Case tb0649.pas }
{$push}


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

{ Case tw20119.pas }
{$push}

type
  tw20119_t = class
  private
    tw20119_f1: Integer; static;
    tw20119_f2: Integer; static;
  end;
{$pop}

{ Case tw22593.pas }
{$push}
{$ifdef fpc}

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

{ Case tw26976.pas }
{$push}


type
   tw26976_ttest = class end;

procedure tw26976_e(Arg1: array of UTF8String);
begin end;

procedure tw26976_e(Arg1: array of tw26976_ttest);
begin end;
{$pop}

{ Case tw27348.pas }
{$push}


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

{ Case tw41504b.pas }
{$push}


type
  tw41504b_ttest = class
    procedure tw41504b_test; virtual; abstract;
  end;

  tw41504b_ttest2 = type tw41504b_ttest;
{$pop}


{$pop}

{ Source group: tb_assigned_expressions_objfpc_compile_01.pas }
{$push}

{ Case tb0584.pas }
{$push}
type
  tb0584_tsomeobj = class
    function tb0584_test(tb0584_s: String): TObject;
  end;

  tb0584_tsomeotherobj = class
  public
    function GetFoo: String;
  end;

function tb0584_tsomeobj.tb0584_test(tb0584_s: String): TObject;
begin

end;

function tb0584_tsomeotherobj.GetFoo: String;
begin

end;

var
  tb0584_someobj: tb0584_tsomeobj;

procedure tb0584_test;
var
  tb0584_b: Boolean;
  tb0584_obj: tb0584_tsomeotherobj;
begin
  tb0584_b := not Assigned(tb0584_someobj.tb0584_test(tb0584_obj.GetFoo));
end;
{$pop}

{ Case tb0586.pas }
{$push}
procedure tb0586_test;
var
  tb0586_a, tb0586_b: Boolean;
  tb0586_obj: TObject;
begin
  if assigned(tb0586_obj)<>(tb0586_a=tb0586_b) then
    ;
end;
{$pop}


{$pop}

{ Source group: tb_class_declarations_objfpc_compile_01.pas }
{$push}

{ Case tb0585.pas }
{$push}
type
  tb0585_tobjectoptions = set of (tb0585_oo_is_external, tb0585_oo_is_forward, tb0585_oo_is_formal);

  tb0585_tobjectdef = class
    tb0585_objectoptions: tb0585_tobjectoptions;
  end;

procedure tb0585_finalize_class_external_status(tb0585_od: tb0585_tobjectdef);
  begin
    if  [tb0585_oo_is_external,tb0585_oo_is_forward] <= tb0585_od.tb0585_objectoptions then
      begin
        { formal definition: x = objcclass external; }
        exclude(tb0585_od.tb0585_objectoptions,tb0585_oo_is_forward);
        include(tb0585_od.tb0585_objectoptions,tb0585_oo_is_formal);
      end;
  end;
{$pop}

{ Case tb0679.pas }
{$push}
type
  tb0679_ta = class
  public
    class destructor Destroy;
    destructor Destroy; override;
  end;

class destructor tb0679_ta.Destroy;
begin
end;

destructor tb0679_ta.Destroy;
begin
  inherited;
end;

var
  tb0679_a: tb0679_ta;
{$pop}


{$pop}

{ Source group: tb_constref_objfpc_compile_01.pas }
{$push}

{ Case tb0656.pas }
{$push}
procedure tb0656_test1(const tb0656_aarg);
begin
end;

procedure tb0656_test2(const tb0656_aarg);
begin
  tb0656_test1(tb0656_aarg);
end;

procedure tb0656_test3(constref tb0656_aarg);
begin
end;

procedure tb0656_test4(constref tb0656_aarg);
begin
  tb0656_test3(tb0656_aarg);
end;
{$pop}

{ Case tw29992.pas }
{$push}
procedure tw29992_test(constref tw29992_aparam: String = 'def_param');
begin
  writeln(tw29992_aparam);
end;
{$pop}


{$pop}

{ Source group: tb_records_objfpc_compile_01.pas }
{$push}

{ Case tw16163.pas }
{$push}


type
  tw16163_tfcolor = record
    tw16163_b, tw16163_g, tw16163_r : Byte;
    // m : Byte; // uncomment it to avoid InternalError 200301231
  end;

  tw16163_tfcolora = record
    tw16163_c : tw16163_tfcolor;
    tw16163_a : Byte;
    // adding some field here, or changing a type to Word or Integer
    // also fixed the problem.
  end;

function tw16163_fcolortofcolora(tw16163_c : tw16163_tfcolor) : tw16163_tfcolora;
begin
  Result.tw16163_c:=tw16163_c;
  Result.tw16163_a:=255;
end;

var
  tw16163_t : tw16163_tfcolor;
  tw16163_a : tw16163_tfcolor;
{$pop}

{ Case tw39464.pas }
{$push}


type
  tw39464_ttestrec = packed record
    tw39464_empty: packed record end;
  end;

function tw39464_getemptyptr(R: tw39464_ttestrec): Pointer;
begin
  Result := @R.tw39464_empty;
end;
{$pop}


{$pop}

{ Source group: tb_objects_objfpc_compile_01.pas }
{$push}

{ Case tb0626.pas }
{$push}


type
  tb0626_tnonmanagedobj = object
    tb0626_d: double;
  end;

var
  tb0626_p: Pointer;
{$pop}

{ Case tw35149.pas }
{$push}

type
  tw35149_testobject = object
  var
    tw35149_testnested: Integer;
  end;
{$pop}


{$pop}

{ Source group: tb_advanced_records_objfpc_compile_01.pas }
{$push}
{$modeswitch advancedrecords}
{ Case tb0623.pas }
{$push}
type
  generic tb0623_ttest<T> = record
  public type
    PSelf = ^specialize tb0623_ttest<T>;
  public
    Next: PSelf;
  end;

  generic tb0623_ttest2<T> = record
    Next: ^specialize tb0623_ttest2<T>;
  end;

  tb0623_ttestlongint = specialize tb0623_ttest<LongInt>;
  tb0623_tteststring = specialize tb0623_ttest<String>;

  tb0623_ttest2longint = specialize tb0623_ttest2<LongInt>;
  tb0623_ttest2string = specialize tb0623_ttest2<String>;
{$pop}

{ Case tb0680.pas }
{$push}
{$H+}
type
  tb0680_ttest = record
    class operator + (aLeft, aRight: tb0680_ttest): tb0680_ttest;
    function Plus(aLeft, aRight: tb0680_ttest): tb0680_ttest;
  end;

class operator tb0680_ttest.+(aLeft, aRight: tb0680_ttest): tb0680_ttest;
begin

end;

function tb0680_ttest.Plus(aLeft, aRight: tb0680_ttest): tb0680_ttest;
begin

end;
{$pop}

{ Case tw27750b.pas }
{$push}
{$modeswitch advancedrecords}

type

  { TGeneric }

  generic tw27750b_tgeneric<tw27750b_foo, tw27750b_bar> = record
  public type
    tw27750b_tgfb = specialize tw27750b_tgeneric<tw27750b_foo, tw27750b_bar>;
  public
    class operator :=(tw27750b_afoo : tw27750b_foo) : tw27750b_tgfb;
    class operator :=(tw27750b_abar : tw27750b_bar) : tw27750b_tgfb;
  end;

{ TGeneric }

class operator tw27750b_tgeneric.:=(tw27750b_afoo: tw27750b_foo): tw27750b_tgfb;
begin

end;

class operator tw27750b_tgeneric.:=(tw27750b_abar: tw27750b_bar): tw27750b_tgfb;
begin

end;
{$pop}


{$pop}

begin
  { Source group: tb_classes_objfpc_compile_01.pas }
  {$push}


begin
  { Case tb0649.pas }
  {$push}

  begin
tb0649_t := tb0649_t + [1, 2, 3];
  tb0649_t := tb0649_t + [eOne, eTwo];
  end;
  {$pop}

  { Case tw26976.pas }
  {$push}

  begin
tw26976_e(['aa']); // Incompatible types: got "Constant String" expected "TTest"
  end;
  {$pop}


end;
  {$pop}

  { Source group: tb_assigned_expressions_objfpc_compile_01.pas }
  {$push}


begin
  { Case tb0584.pas }
  {$push}
begin

end;
  {$pop}

  { Case tb0586.pas }
  {$push}
begin

end;
  {$pop}


end;
  {$pop}

  { Source group: tb_class_declarations_objfpc_compile_01.pas }
  {$push}


begin
  { Case tb0585.pas }
  {$push}
begin

end;
  {$pop}

  { Case tb0679.pas }
  {$push}
begin
  tb0679_a := tb0679_ta.Create;
  tb0679_a.Free;
end;
  {$pop}


end;
  {$pop}

  { Source group: tb_constref_objfpc_compile_01.pas }
  {$push}


begin
  { Case tb0656.pas }
  {$push}
begin

end;
  {$pop}

  { Case tw29992.pas }
  {$push}
begin
end;
  {$pop}


end;
  {$pop}

  { Source group: tb_records_objfpc_compile_01.pas }
  {$push}


begin
  { Case tw16163.pas }
  {$push}

  begin
FillChar(tw16163_a, sizeof(tw16163_a), $55);
  tw16163_t:=tw16163_fcolortofcolora(tw16163_a).tw16163_c; // IE 200301231 why?
  if (tw16163_t.tw16163_b<>$55) or
     (tw16163_t.tw16163_r<>$55) or
     (tw16163_t.tw16163_g<>$55) then
    halt(1);
  end;
  {$pop}


end;
  {$pop}

  { Source group: tb_objects_objfpc_compile_01.pas }
  {$push}


begin
  { Case tb0626.pas }
  {$push}

  begin
tb0626_p := TypeInfo(tb0626_tnonmanagedobj);
  end;
  {$pop}

  { Case tw35149.pas }
  {$push}

  begin
writeln(SizeOf(tw35149_testobject.tw35149_testnested));
  end;
  {$pop}


end;
  {$pop}

  { Source group: tb_advanced_records_objfpc_compile_01.pas }
  {$push}
{$modeswitch advancedrecords}
{$modeswitch advancedrecords}
begin
  { Case tb0623.pas }
  {$push}
begin

end;
  {$pop}

  { Case tb0680.pas }
  {$push}
begin

end;
  {$pop}

  { Case tw27750b.pas }
  {$push}
begin
end;
  {$pop}


end;
  {$pop}

end.
