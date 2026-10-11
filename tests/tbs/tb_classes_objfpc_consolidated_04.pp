{ Consolidated classes regressions; original case IDs and assertions are retained. }
{ %NORUN }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case tw15693.pp }
{$push}



{$h+}

type
  tw15693_TMyClass = class
    function ToString: String; override;
  end;

function tw15693_TMyClass.ToString: String;
begin
  Result:=inherited;
end;


{$pop}

{ Case tw18127.pp }
{$push}



{$H+}

type
  tw18127_TBar = class
  public
    type
      TSomeInt = integer;
  end;

  tw18127_TFoo1 = class(tw18127_TBar)
  public
    const
      one = 1;
    type
      TFoo2 = TSomeInt; // was error: Identifier not found "TSomeInt"
      TFoo3 = class
        function Func: TFoo2;
      end;
  end;

  function tw18127_TFoo1.TFoo3.Func: TFoo2; // was error: Identifier not found "TFoo2"
  begin
    Result := one; // was error: Identifier not found "one"
  end;


{$pop}

{ Case tw19452.pp }
{$push}



type
  tw19452_TMyObject = class
  public
    constructor Create(ar: array of tw19452_TMyObject);
  end;

constructor tw19452_TMyObject.Create(ar: array of tw19452_TMyObject);
begin
end;


{$pop}

{ Case tw19452a.pp }
{$push}



type
  tw19452a_TMyObject = class;
  tw19452a_TArr = array of tw19452a_TMyObject;
  tw19452a_TMyObject = class
  public
    constructor Create(ar: array of tw19452a_TMyObject); overload;
    constructor Create(ar: tw19452a_TArr); overload;
  end;

constructor tw19452a_TMyObject.Create(ar: array of tw19452a_TMyObject);
begin
end;

constructor tw19452a_TMyObject.Create(ar: tw19452a_Tarr);
begin
end;


{$pop}

{ Case tw21941.pp }
{$push}



{$H+}

type
  tw21941_TACLInfo = record
    Name: string;
  end;
  tw21941_PACLInfo = ^tw21941_TACLInfo;

  tw21941_TCLSInfo = record
    Name: string;
  end;
  tw21941_PCLSInfo = ^tw21941_TCLSInfo;

  tw21941_TCoreObjectInfo = record
    CLSInfo: tw21941_PCLSInfo;
    ACLInfo: tw21941_PACLInfo;
  end;

type
  tw21941_Root = class
  type
    Test = class
    const
      ACLInfo: tw21941_TACLInfo = (
        Name: 'Admin';
      );
      CLSInfo: tw21941_TCLSInfo = (
        Name: 'TAdminCore';
      );
      Header: tw21941_TCoreObjectInfo = (
        CLSInfo: @CLSInfo;
        ACLInfo: @ACLInfo;
      );
    end;
  end;

{$pop}

{ Case tw22225.pp }
{$push}





type
  tw22225_TT = class
  public
    type
      TErr = class
      end;
  end;

{$pop}

{ Case tw22705.pp }
{$push}






type
  tw22705_tMyClass=class
   end;
  tw22705_tMyFormType= class of tw22705_tMyClass;

  tw22705_prec = ^tw22705_trec;
  tw22705_trec = record
  end;

  tw22705_TForm1 = class
  public
    procedure myFNC(obj:tw22705_tMyFormType);  overload;
    procedure myFNC(obj:tClass);       overload;
    procedure myFNC2(obj:tw22705_prec);       overload;
    procedure myFNC2(obj:pchar);       overload;
  end;

  tw22705_TForm2 = class
  public
    procedure myFNC(obj:tClass);       overload;
    procedure myFNC(obj:tw22705_tMyFormType);  overload;
    procedure myFNC2(obj:pchar);       overload;
    procedure myFNC2(obj:tw22705_prec);       overload;
  end;

procedure tw22705_TForm1.myFNC(obj:tClass);
begin
end;

procedure tw22705_TForm1.myFNC(obj:tw22705_tMyFormType);
begin
end;

procedure tw22705_TForm1.myFNC2(obj:tw22705_prec);
begin
end;

procedure tw22705_TForm1.myFNC2(obj:pchar);
begin
end;


procedure tw22705_TForm2.myFNC(obj:tClass);
begin
end;

procedure tw22705_TForm2.myFNC(obj:tw22705_tMyFormType);
begin
end;

procedure tw22705_TForm2.myFNC2(obj:tw22705_prec);
begin
end;

procedure tw22705_TForm2.myFNC2(obj:pchar);
begin
end;



{$pop}

{ Case tw22979.pp }
{$push}



type
  tw22979_TMyRecord = record
    Data: pointer;
  end;

  tw22979_TMyClass = class
  private
    FRef: tw22979_TMyRecord;
  public
    property Ref: tw22979_TMyRecord read FRef write FRef;
  end;

var
  tw22979_MyClass1, tw22979_MyClass2: tw22979_TMyClass;

procedure tw22979_test;
begin
  Move(tw22979_MyClass1.Ref.Data^, tw22979_MyClass2.Ref.Data^, 1);
end;



{$pop}

{ Case tw27120.pp }
{$push}






type
  tw27120_TFoo = class
  end;

  tw27120_TBar = class helper for tw27120_TFoo
  private class var
    FFoo: tw27120_TFoo;
  end;


{$pop}

{ Case tw30761.pp }
{$push}






type
  tw30761_Ta = class
    public
      procedure Test;
  end;

  tw30761_Tb = class(tw30761_Ta)
  end;

  tw30761_TbHelper = class helper for tw30761_Tb
    public
      procedure Test(i: integer); overload;
  end;

procedure tw30761_Ta.Test;
begin
end;

procedure tw30761_TbHelper.Test(i: integer);
begin
  //Self.Test;
end;

var
  tw30761_b: tw30761_Tb;


{$pop}

{ Case tw39401.pp }
{$push}


type
	tw39401_Collide29685295 = type uint32;
	tw39401_Collide32060020 = type uint32;

	tw39401_SomeType = class
	type
		SomeNestedType = class
		type
			YetAnotherNestedType = class
				class procedure Hello(arg: YetAnotherNestedType; arg2: tw39401_Collide29685295); static;
				class procedure Hello(arg: YetAnotherNestedType; arg2: tw39401_Collide32060020); static;
			end;
		end;
	end;

	class procedure tw39401_SomeType.SomeNestedType.YetAnotherNestedType.Hello(arg: YetAnotherNestedType; arg2: tw39401_Collide29685295);
	begin
	end;

	class procedure tw39401_SomeType.SomeNestedType.YetAnotherNestedType.Hello(arg: YetAnotherNestedType; arg2: tw39401_Collide32060020);
	begin
	end;


{$pop}

begin

{ Case tw15693.pp }
{$push}

{$h+}
begin
end;
{$pop}

{ Case tw18127.pp }
{$push}

{$H+}
begin
end;
{$pop}

{ Case tw19452.pp }
{$push}

begin
  tw19452_TMyObject.Create([nil]);
end;
{$pop}

{ Case tw19452a.pp }
{$push}

begin
  tw19452a_TMyObject.Create([nil]);
end;
{$pop}

{ Case tw21941.pp }
{$push}

{$H+}
begin
end;
{$pop}

{ Case tw22225.pp }
{$push}

begin
  try
  except on tw22225_TT.TErr do;
  end;
end;
{$pop}

{ Case tw22705.pp }
{$push}

begin
end;
{$pop}

{ Case tw22979.pp }
{$push}

begin
end;
{$pop}

{ Case tw27120.pp }
{$push}

begin

end;
{$pop}

{ Case tw30761.pp }
{$push}

begin
  tw30761_b:=tw30761_Tb.Create;
  tw30761_b.Test(1); // Error: Wrong number of parameters specified for call to "Test"
  tw30761_b.Test;
end;
{$pop}

{ Case tw39401.pp }
{$push}

begin
end;
{$pop}

end.
