{ Consolidated classes regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}
uses classes,sysutils;

{ Case tw12318.pas }
{$push}






type
  tw12318_TGetActionEvent = Procedure (Sender : TObject) of object;
  tw12318_TGetMethodProc=function(): TMethod of object;

type

{ TTestObject }

  tw12318_TTestObject = class(TObject)
    function GetOnGetAction: tw12318_TGetActionEvent;
    procedure DataModuleGetAction(Sender: TObject);
  end;

function tw12318_TTestObject.GetOnGetAction: tw12318_TGetActionEvent;
begin
  Result := @DataModuleGetAction;
end;

procedure tw12318_TTestObject.DataModuleGetAction(Sender: TObject);
begin
  writeln('is');
end;

var tw12318_AMethod : TMethod;
    tw12318_ATestObject : tw12318_TTestObject;


{$pop}

{ Case tw14103.pas }
{$push}


{$H+}



type
  tw14103_TCallback = procedure of object;

  { TTestObject }

  tw14103_TTestObject = class (TObject)
  public
    class procedure Test;
  end;
  tw14103_TTestClass = class of tw14103_TTestObject;

  tw14103_TTestObject2 = class(tw14103_TTestObject)
  end;

{ TTestObject }

var
  tw14103_global: boolean;
  tw14103_compareclass: tw14103_TTestClass;

class procedure tw14103_TTestObject.Test;
begin
  tw14103_global:=true;
  if self <> tw14103_compareclass then
    halt(2);
end;

var
  tw14103_Cls: tw14103_TTestClass;
  tw14103_Callback: tw14103_TCallback;

{$pop}

{ Case tw3197.pas }
{$push}
{ Source provided for Free Pascal Bug Report 3197 }
{ Submitted by "Martin Schreiber" on  2004-07-03 }
{ e-mail:  }
{$ifdef fpc}{$H+}{$endif}



type
 tw3197_ttestclass = class
  public
   teststring: ansistring;
   procedure test(const astring: ansistring);
 end;

{ ttestclass }

procedure tw3197_ttestclass.test(const astring: ansistring);
begin
 teststring:= astring;
end;


var
 tw3197_testclass: tw3197_ttestclass;

{$pop}

{ Case tw3214.pas }
{$push}
{$H+}{$r+}



type
  tw3214_TMyEvent = class(TObject)
  public
    procedure SaveToStream(aStream: TStream); virtual; abstract;
  end;

  tw3214_TMyClass = class
  private
    function GetEvent(aIndex: integer): tw3214_TMyEvent;
    function GetEventCount: integer;
  public
    property EventCount: integer read GetEventCount;
    property Events[aIndex: integer]: tw3214_TMyEvent read GetEvent;
    procedure SaveToStream(aDest: TStream);
  end;

{ TMyClass }

function tw3214_TMyClass.GetEvent(aIndex: integer): tw3214_TMyEvent;
begin
  Result:=nil;
end;

function tw3214_TMyClass.GetEventCount: integer;
begin
  Result:=0;
end;

procedure tw3214_TMyClass.SaveToStream(aDest: TStream);
var
  cEvent: Integer;
  eCnt: Integer;
begin
  eCnt:=EventCount;
  aDest.Write(eCnt, sizeof(eCnt));
  for cEvent := 0 to eCnt -1 do
    Events[cEvent].SaveToStream(aDest);
end;


{$pop}

{ Case tw3241a.pas }
{$push}
{ Source provided for Free Pascal Bug Report 3241 }
{ Submitted by "Mattias Gaertner" on  2004-08-09 }
{ e-mail: mattias@freepascal.org }


{$H+}



type
  tw3241a_TMyParentClass = class
  private
    function GetA1(Index: integer): integer;
  public
    property A1[Index: integer]: integer read GetA1; default;
  end;

  tw3241a_TMyClass = class(tw3241a_TMyParentClass)
  private
    function GetA2(Index: integer): integer;
  public
    property A2[Index: integer]: integer read GetA2; default;
  end;

{ TMyClass }

function tw3241a_TMyParentClass.GetA1(Index: integer): integer;
begin
  Result:=0;
end;

function tw3241a_TMyClass.GetA2(Index: integer): integer;
begin
  Result:=0;
end;


{$pop}

{ Case tw3758.pas }
{$push}
{ Source provided for Free Pascal Bug Report 3758 }
{ Submitted by "Martin Schreiber" on  2005-03-07 }
{ e-mail:  }


{$H+}



type

 tw3758_ttestcomp = class(tcomponent)
  private
   fwstr: widestring;
  published
   property wstr: widestring read fwstr write fwstr;
  end;

var
 tw3758_stream1,tw3758_stream2: tmemorystream;
 tw3758_f: tfilestream;
 tw3758_testcomp1,tw3758_testcomp2: tw3758_ttestcomp;
 tw3758_str1: widestring;


{$pop}

{ Case tw4789.pas }
{$push}
{ Source provided for Free Pascal Bug Report 4789 }
{ Submitted by "Andrew Haines" on  2006-02-09 }
{ e-mail: andrewd207@aol.com }


{$H+}



type

  { TSimpleObj }
  tw4789_TSimpleSet = (tw4789_ssOne, tw4789_ssTwo, tw4789_ssThree);

  tw4789_TSimpleObj = class(TObject)
  private
    procedure SetTestVal(const AIndex: Integer; const AIsSet: Boolean);
    function GetTestVal(const AIndex: Integer): Boolean;
  public
    Property TestVal: Boolean index Ord(tw4789_ssOne) read GetTestVal write SetTestVal;
  end;

{ TSimpleObj }

procedure tw4789_TSimpleObj.SetTestVal(const AIndex: Integer; const AIsSet: Boolean);
begin

end;

function tw4789_TSimpleObj.GetTestVal(const AIndex: Integer): Boolean;
begin

end;


{$pop}

{ Case tw8861.pas }
{$push}
{$H+}



type
  tw8861_TNotifyEventExt = procedure(ASender: TObject; ANotifyType: integer) of
object;

  tw8861_TNotify = class
  strict private
    FOnNotify: tw8861_TNotifyEventExt;
  strict  protected
    procedure test;
  public
    constructor Create;
  end;


constructor tw8861_TNotify.Create;
begin
  inherited Create;
  FOnNotify := nil;
end;

procedure tw8861_TNotify.test;
begin
   FOnNotify(nil, 0); //project1.pas(30,13) Fatal: Syntax error, ";" expected but "(" found
end;


{$pop}

begin

{ Case tw12318.pas }
{$push}

begin
  tw12318_ATestObject := tw12318_TTestObject.create;

// uncomment the next line and the exception will occur on the line after the 'this' writeln,
// else the crash will occur in TTestObject.GetOnGetAction
  tw12318_ATestObject.GetOnGetAction;

  tw12318_AMethod := tw12318_TGetMethodProc(@tw12318_ATestObject.GetOnGetAction)();
  WriteLn('this');
  tw12318_TGetActionEvent(tw12318_AMethod)(nil);
  WriteLn('a test');

  tw12318_ATestObject.Free;
end;
{$pop}

{ Case tw14103.pas }
{$push}

{$H+}
begin
  // Doesn't work
  tw14103_global:=false;
  tw14103_Callback := @tw14103_TTestObject.Test;
  tw14103_compareclass:=tw14103_TTestObject;
  tw14103_Callback();
  if not tw14103_global then
    halt(1);

  tw14103_global:=false;
  tw14103_Callback := @tw14103_TTestObject2.Test;
  tw14103_compareclass:=tw14103_TTestObject2;
  tw14103_Callback();
  if not tw14103_global then
    halt(1);
end;
{$pop}

{ Case tw3197.pas }
{$push}
{$ifdef fpc}

{$H+}
{$endif}
begin
 tw3197_testclass:= tw3197_ttestclass.create;
 tw3197_testclass.teststring:= 'abc';
 tw3197_testclass.teststring:= tw3197_testclass.teststring + '123'; //refcount 1
 tw3197_testclass.test(tw3197_testclass.teststring);
 if tw3197_testclass.teststring = 'abc123' then begin
  writeln('ok');
 end
 else begin
  writeln('error');
  halt(1);
 end;
 tw3197_testclass.free;
end;
{$pop}

{ Case tw3214.pas }
{$push}

{$H+}
{$r+}
begin
end;
{$pop}

{ Case tw3241a.pas }
{$push}

{$H+}
begin
end;
{$pop}

{ Case tw3758.pas }
{$push}

{$H+}
begin
 setlength(tw3758_str1,2);
 tw3758_str1[1]:= widechar($1f00);
 tw3758_str1[2]:= widechar($203);
 tw3758_stream1:= tmemorystream.create;
 tw3758_stream2:= tmemorystream.create;
 tw3758_testcomp1:= tw3758_ttestcomp.create(nil);
 tw3758_testcomp2:= tw3758_ttestcomp.create(nil);
 try
  tw3758_testcomp1.wstr:= tw3758_str1;
  tw3758_stream1.writecomponent(tw3758_testcomp1);
  tw3758_stream1.position:= 0;
  objectbinarytotext(tw3758_stream1,tw3758_stream2);
  tw3758_stream1.clear;
  tw3758_stream2.position:= 0;
  tw3758_f:= tfilestream.create('test.txt',fmcreate);
  tw3758_f.copyfrom(tw3758_stream2,0);
  tw3758_f.free;
  tw3758_stream2.position:= 0;
  objecttexttobinary(tw3758_stream2,tw3758_stream1);
  tw3758_stream1.position:= 0;
  tw3758_stream1.readcomponent(tw3758_testcomp2);
  if tw3758_testcomp2.wstr = tw3758_str1 then begin
   writeln('OK');
  end
  else begin
   writeln('Error');
  end;
 finally
  tw3758_stream1.free;
  tw3758_stream2.free;
  tw3758_testcomp1.free;
  tw3758_testcomp2.free;
  deletefile('test.txt');
 end;
end;
{$pop}

{ Case tw4789.pas }
{$push}

{$H+}
begin
end;
{$pop}

{ Case tw8861.pas }
{$push}

{$H+}
begin
end;
{$pop}

end.
