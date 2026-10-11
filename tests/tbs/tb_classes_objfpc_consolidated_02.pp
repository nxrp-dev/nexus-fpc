{ Consolidated classes regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}
uses classes;

{ Case tb_components_objfpc_run_01.pp }
{$push}
{ Component construction after NewInstance and construction of owned components. }
{ Original case IDs and variable scopes are retained below. }





{ Case tb0280.pp }
{$push}
{ Old file: tbs0332.pp }
{  }

var
  tb0280_o: TComponent;
{$pop}

{ Case tb0285.pp }
{$push}
{ Old file: tbs0337.pp }
{  }

type
  tb0285_tmycomponent = class(TComponent)
    tb0285_aaaaaaaaaa: TComponent;
    tb0285_b: TComponent;
  private
  public
    constructor Create(tb0285_aowner: TComponent); override;
  end;


constructor tb0285_tmycomponent.Create(tb0285_aowner: TComponent);
begin
  inherited Create(tb0285_aowner);
  tb0285_aaaaaaaaaa := TComponent.Create(Self);
end;

var
  tb0285_mycomponent: tb0285_tmycomponent;
{$pop}


{$pop}

{ Case tw2185.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2185 }
{ Submitted by "Andrew Johnson" on  2002-10-16 }
{ e-mail: AJ_Genius@Hotmail.com }


{$H+}
{off $Define InvertOrder}



Type
  tw2185_TMyClass = Class(TPersistent)
  public
    dummy : Longint;
    {$IfNDef InvertOrder}
      procedure Assign(Source : TPersistent); override;
      procedure Assign(const value: integer);
    {$Else InvertOrder}
      procedure Assign(const value: integer);
      procedure Assign(Source : TPersistent); override;
    {$EndIf InvertOrder}

    Constructor Create;
  end;

procedure tw2185_TMyClass.Assign(Source : TPersistent);
begin
  If Source is tw2185_TMyClass then
    Dummy := tw2185_TMyClass(Source).dummy;
end;

procedure tw2185_TMyClass.Assign(const value: integer);
begin
  Dummy := value;
end;

Constructor tw2185_TMyClass.Create;
begin
  Inherited Create;
end;

Const
  tw2185_ConstDummy : Integer = 3;

var
  tw2185_Test1, tw2185_Test2 : tw2185_TMyClass;

{$pop}

{ Case tw2186.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2186 }
{ Submitted by "Andrew Johnson" on  2002-10-16 }
{ e-mail: AJ_Genoius@Hotmail.com }





Type
  tw2186_NewInt = type longint;

  tw2186_TSomeClass = Class(TComponent)
  end;


{$pop}

{ Case tw2196.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2196 }
{ Submitted by "Andrew Johnson" on  2002-10-22 }
{ e-mail: acjgenius@earthlink.net }





type
  tw2196_TSomeClass = Class
  private
    FTestString : AnsiString;
  public
    Property  TestString : AnsiString read FTestString write FTestString;
  end;

var
  tw2196_TestClass : tw2196_TSomeClass;

{$pop}

{ Case tw23962.pp }
{$push}




type

tw23962_TVector3 = packed record
  X, Y, Z: Single;
end;

tw23962_TClassA = class
protected
  fVector: tw23962_TVector3;
public
  procedure SetVector(AVector: tw23962_TVector3); virtual; abstract;
end;

{ TClassB }

tw23962_TClassB = class(tw23962_TClassA)
public
  procedure SetVector(AVector: tw23962_TVector3); override;
end;

{ TClassB }

procedure tw23962_TClassB.SetVector(AVector: tw23962_TVector3);
begin
  writeln('TClassB: ',AVector.X,',',AVector.Y,',',AVector.Z);
  fVector:=AVector;
end;

var
  tw23962_MyVector: tw23962_TVector3;
  tw23962_MyClassB: tw23962_TClassB;

{$pop}

{ Case tw3041.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3041 }
{ Submitted by "C Western" on  2004-04-06 }
{ e-mail: mftq75@dsl.pipex.com }


{$H+}


type
  tw3041_TMyCollectionItem = class(TCollectionItem)
    public
      procedure Assign(Source: TPersistent); override;
  end;

procedure tw3041_TMyCollectionItem.Assign(Source: TPersistent);
begin
end;

var
  tw3041_A, tw3041_B: TCollection;
  tw3041_C: tw3041_TMyCollectionItem;

{$pop}

{ Case tw3101.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3101 }
{ Submitted by "Martin Schreiber" on  2004-05-15 }
{ e-mail:  }

{$ifdef fpc}{$H+}{$endif}



type
 tw3101_ttestobj = class
  public
   constructor create1;
   constructor create2;
   destructor destroy; override;
   procedure afterconstruction; override;
   procedure beforedestruction; override;
 end;

var
 tw3101_testobj: tw3101_ttestobj;
 tw3101_i : integer;
 tw3101_err : boolean;

procedure tw3101_ttestobj.afterconstruction;
begin
 writeln('afterconstruction');
 if tw3101_i<>3 then
   tw3101_err:=true;
 inc(tw3101_i);
end;

procedure tw3101_ttestobj.beforedestruction;
begin
 writeln('beforedestruction');
 if tw3101_i<>4 then
   tw3101_err:=true;
 inc(tw3101_i);
end;

constructor tw3101_ttestobj.create1;
begin
 writeln('create1');
 if tw3101_i<>1 then
   tw3101_err:=true;
 inc(tw3101_i);
 self.create2;
end;

constructor tw3101_ttestobj.create2;
begin
 writeln('create2');
 if tw3101_i<>2 then
   tw3101_err:=true;
 inc(tw3101_i);
end;

destructor tw3101_ttestobj.destroy;
begin
 writeln('destroy');
 inherited;
 if tw3101_i<>5 then
   tw3101_err:=true;
 inc(tw3101_i);
end;


{$pop}

{ Case tw3216.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3216 }
{ Submitted by "Mark Honman" on  2004-07-17 }
{ e-mail: wania_mark@yahoo.co.uk }


{$H+}



type tw3216_TShowProblem = class
    function GetValue(Index : integer) : OleVariant; stdcall;
    property IWontCompile[Index : integer] : OleVariant read GetValue;
  end;

{ Note :
  if any of the following is changed, the problem disappears
    * make it a scalar (non-indexed) property
    * remove the stdcall directive
    * change the type of the property to something else
  although quite obscure, it would be very useful to have this fixed as it will
  greatly assist in interfacing to external OLE objects - in this case the ADO
  library for access to MS SQL Server.

  Identified with FPC 1.9.3 on Windows ME.
}

function tw3216_TShowProblem.GetValue(Index : integer) : OleVariant; stdcall;
begin
end;


{$pop}

{ Case tw3589.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3589 }
{ Submitted by "Michalis Kamburelis" on  2005-01-23 }
{ e-mail: michalis@camelot.homedns.org }
{$ifdef FPC}  {$endif}
{$assertions on}



type
  tw3589_TBoxedInt = class(TCollectionItem)
  public
    Value: Integer;
  end;

var
  tw3589_C: TCollection;

{$pop}

{ Case tw4519.pp }
{$push}
{ Source provided for Free Pascal Bug Report 4519 }
{ Submitted by "Martin Schreiber" on  2005-11-17 }
{ e-mail:  }

{$h+}


type
 tw4519_ttestcomp = class(tcomponent)
  private
   fstringvar: string;
   procedure readstringvar(reader: treader);
   procedure writestringvar(writer: twriter);
  protected
   procedure defineproperties(filer: tfiler); override;
 end;

{ ttestcomp }

procedure tw4519_ttestcomp.readstringvar(reader: treader);
begin
 fstringvar:= reader.readstring;
end;

procedure tw4519_ttestcomp.writestringvar(writer: twriter);
begin
 writer.writestring(fstringvar);
end;

procedure tw4519_ttestcomp.defineproperties(filer: tfiler);
begin
 filer.defineproperty('stringvar',@readstringvar,@writestringvar,true);
end;

var
 tw4519_testcomp: tw4519_ttestcomp;
 tw4519_stream1,tw4519_stream2: tmemorystream;


{$pop}

{ Case tw4529.pp }
{$push}
{ Source provided for Free Pascal Bug Report 4529 }
{ Submitted by "Vincent Snijders" on  2005-11-20 }
{ e-mail: vsnijders@quicknet.nl }


{$H+}



type
  tw4529_MyClass = class(TComponent)
  //private
  public
    FClassVar: integer; static;
  end;


{$pop}

{ Case tw8847.pp }
{$push}
{$ifdef fpc}{$h+}{$endif}



type
  tw8847_tbase = class(tobject)
  public
    function add: tobject; overload;
    function add(aitem: tobject): integer; overload;
  end;

  tw8847_timpl = class(tw8847_tbase)
  public
    function add: tpersistent; overload;
    function add(aitem: tpersistent): integer; overload;
  end;

var
  tw8847_err : boolean;

function tw8847_tbase.add: tobject;
begin
  writeln('tbase.add:tobject');
  result := nil;
end;

function tw8847_tbase.add(aitem: tobject): integer;
begin
  writeln('tbase.add(aitem: tobject)');
  result := -1;
end;

function tw8847_timpl.add: tpersistent;
begin
  writeln('timpl.add:tpersistent');
  result := nil;
end;

function tw8847_timpl.add(aitem: tpersistent): integer;
begin
  writeln('timpl.add(aitem: tpersistent)');
	tw8847_err:=false;
  result := -1
end;

var
  tw8847_vimpl: tw8847_timpl;


{$pop}

begin

{ Case tb_components_objfpc_run_01.pp }
{$push}

{$push}
{$pop}
{$push}
{$pop}
begin
  { Case tb0280.pp }
  {$push}
begin
    tb0280_o := TComponent(TComponent.NewInstance);
    tb0280_o.Create(nil);
    tb0280_o.Free;
  end;
  {$pop}

  { Case tb0285.pp }
  {$push}
begin
  tb0285_mycomponent := tb0285_tmycomponent.Create(nil);
end;
  {$pop}

end;
{$pop}

{ Case tw2185.pp }
{$push}

{$H+}
{$IfNDef InvertOrder}
{$Else InvertOrder}
{$EndIf InvertOrder}
begin
  tw2185_Test1 := tw2185_TMyClass.Create;
  tw2185_Test2 := tw2185_TMyClass.Create;
  tw2185_Test1.Dummy := 2;
  tw2185_Test2.Dummy := 1;
  Writeln(tw2185_Test2.Dummy);
  tw2185_Test2.Assign(tw2185_Test1);
  Writeln(tw2185_Test2.Dummy);
  tw2185_Test2.Assign(tw2185_ConstDummy);
  Writeln(tw2185_Test2.Dummy);
  tw2185_Test1.Destroy;
  tw2185_Test2.Destroy;
end;
{$pop}

{ Case tw2186.pp }
{$push}

begin

end;
{$pop}

{ Case tw2196.pp }
{$push}

begin
  tw2196_TestClass := tw2196_TSomeClass.Create;
  tw2196_TestClass.TestString :=  tw2196_TestClass.TestString + 'Whatever';
  writeln(tw2196_TestClass.TestString);
  if tw2196_TestClass.TestString<>'Whatever' then
   begin
     writeln('Error!');
     halt(1);
   end;
  tw2196_TestClass.Free;
end;
{$pop}

{ Case tw23962.pp }
{$push}

begin
  tw23962_MyVector.X:=0;
  tw23962_MyVector.Y:=0;
  tw23962_MyVector.Z:=3;
  tw23962_MyClassB:=tw23962_TClassB.Create;
  tw23962_MyClassB.SetVector(tw23962_MyVector);
  if (tw23962_MyClassB.fvector.x<>0) or
     (tw23962_MyClassB.fvector.y<>0) or
     (tw23962_MyClassB.fvector.z<>3) then
    halt(1);
end;
{$pop}

{ Case tw3041.pp }
{$push}

{$H+}
begin
  tw3041_A := TCollection.Create(tw3041_TMyCollectionItem);
  tw3041_B := TCollection.Create(tw3041_TMyCollectionItem);
  tw3041_C := tw3041_TMyCollectionItem.Create(tw3041_A);
  Writeln(tw3041_A.Count);
  tw3041_B.Assign(tw3041_A);
  Writeln(tw3041_B.Count);
  if tw3041_B.Count<>tw3041_A.Count then
    begin
      writeln('Error!');
      halt(1);
    end;
end;
{$pop}

{ Case tw3101.pp }
{$push}
{$ifdef fpc}

{$H+}
{$endif}
begin
 tw3101_i:=1;
 tw3101_testobj:= tw3101_ttestobj(tw3101_ttestobj.newinstance);
 tw3101_testobj.create1;
 tw3101_testobj.free;
 //expected: create,afterconstruction,beforedestruction,destroy
 //actual: create,beforedestruction,destroy
 //kylix shows the expected behavior
  if tw3101_err then
    halt(1);
end;
{$pop}

{ Case tw3216.pp }
{$push}

{$H+}
begin

end;
{$pop}

{ Case tw3589.pp }
{$push}
{$ifdef FPC}

{$endif}
{$assertions on}
begin
 tw3589_C := TCollection.Create(tw3589_TBoxedInt);
 try
  tw3589_TBoxedInt(tw3589_C.Add).Value := 1;
  tw3589_TBoxedInt(tw3589_C.Add).Value := 2;
  tw3589_TBoxedInt(tw3589_C.Add).Value := 3;
  tw3589_TBoxedInt(tw3589_C.Insert(0)).Value := 4; { 4 1 2 3 }
  tw3589_TBoxedInt(tw3589_C.Insert(3)).Value := 5; { 4 1 2 5 3 }
  tw3589_TBoxedInt(tw3589_C.Insert(5)).Value := 6; { 4 1 2 5 3 6 }
{  Writeln(
    TBoxedInt(C.Items[0]).Value, ' ',
    TBoxedInt(C.Items[1]).Value, ' ',
    TBoxedInt(C.Items[2]).Value, ' ',
    TBoxedInt(C.Items[3]).Value, ' ',
    TBoxedInt(C.Items[4]).Value, ' ',
    TBoxedInt(C.Items[5]).Value);}
  Assert(
    (tw3589_TBoxedInt(tw3589_C.Items[0]).Value = 4) and
    (tw3589_TBoxedInt(tw3589_C.Items[1]).Value = 1) and
    (tw3589_TBoxedInt(tw3589_C.Items[2]).Value = 2) and
    (tw3589_TBoxedInt(tw3589_C.Items[3]).Value = 5) and
    (tw3589_TBoxedInt(tw3589_C.Items[4]).Value = 3) and
    (tw3589_TBoxedInt(tw3589_C.Items[5]).Value = 6));
 finally tw3589_C.Free end;
end;
{$pop}

{ Case tw4519.pp }
{$push}

{$h+}
begin
 tw4519_testcomp:= tw4519_ttestcomp.create(nil);
 tw4519_stream1:= tmemorystream.create;
 tw4519_stream1.writecomponent(tw4519_testcomp);
 tw4519_stream1.position:= 0;
 tw4519_stream2:= tmemorystream.create;
 objectbinarytotext(tw4519_stream1,tw4519_stream2); //<- AV
 tw4519_stream1.free;
 tw4519_stream2.free;
end;
{$pop}

{ Case tw4529.pp }
{$push}

{$H+}
begin
end;
{$pop}

{ Case tw8847.pp }
{$push}
{$ifdef fpc}

{$h+}
{$endif}
begin
  tw8847_err:=true;
  tw8847_vimpl := tw8847_timpl.create;
  tw8847_vimpl.add(nil);
  tw8847_vimpl.free;
	if tw8847_err then
	  halt(1);
end;
{$pop}

end.
