{ Class constructor parameters, object fields, const references and interface storage. }

{ tw10454.pp }
{$mode objfpc}

type
  TMyObject = object
    Int: longint;
  end;

  TMyObject2 = object(TMyObject)
  end;

  TMyClass = class
    FByte: byte;
    Obj: TMyObject2;  // instance of this object is not aligned
  end;

var
  myclass: TMyClass;

{ tw0934.pp }
{$mode objfpc}
 Type
      t = class(TObject)
       f1,f2:dword;
       constructor Init(p1, p2:dword);
      end;

 constructor t.Init(p1, p2:dword);
 begin
  f1:=p1; f2:=p2;
 end;
 var ti:t;

{ tw1207.pp }
{$mode objfpc}

type
  aclasstype = class
    prop : integer;
  end;

procedure trychange (const aclass : aclasstype);
begin
  aclass.prop := 5;
end;

var
  aclass : aclasstype;

{ tw10831.pp }
{$mode objfpc}

type
  TForm = class(TInterfacedObject)
    a : array[0..1000000] of byte;
  end;

  TMyForm = class(TForm, IInterface)
  end;

var
  i : IInterface;

begin
  { tw10454.pp }
  myclass:=TMyClass.Create;
    myclass.obj.int:=1; // Crash due to unaligned data access
    myclass.Free;
  ;

  { tw0934.pp }
  ti:=t.Init(1,2);
   writeln(ti.f1, ', ', ti.f2); // prints garbage instead of t2
   if ti.f2<>2 then
     Halt(1);
  ;

  { tw1207.pp }
  aclass := AClassType.Create;
    try
      trychange (aclass)
    finally
      aclass.free;
    end;
  ;

  { tw10831.pp }
  i:=TMyForm.Create;
  ;
end.
