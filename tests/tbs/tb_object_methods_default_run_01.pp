{ Object method addresses, nested Self references and private virtual methods. }
{ Original case IDs and variable scopes are retained below. }

{ Case tb0018.pp }
{$push}
{ Old file: tbs0022.pp }
{  tests getting the address of a method               OK 0.9.3 }

type
   tb0018_tobject = object
      procedure tb0018_x;
      constructor tb0018_c;
   end;

procedure tb0018_a;

  begin
  end;

procedure tb0018_tobject.tb0018_x;

  begin
  end;

constructor tb0018_tobject.tb0018_c;

  begin
  end;

var
   tb0018_p : codepointer;
{$pop}

{ Case tb0019.pp }
{$push}
{ Old file: tbs0023.pp }
{  tests handling of self pointer in nested methods    OK 0.9.3 }

type
   tb0019_tobject = object
      tb0019_a : longint;
      procedure tb0019_t1;
      procedure tb0019_t2;virtual;
      constructor tb0019_init;
   end;

procedure tb0019_tobject.tb0019_t1;

  procedure tb0019_nested1;

    begin
       writeln;
       tb0019_a:=1;
    end;

  begin
  end;

procedure tb0019_tobject.tb0019_t2;

  procedure tb0019_nested1;

    begin
       writeln;
       tb0019_a:=1;
    end;

  begin
  end;

constructor tb0019_tobject.tb0019_init;

  procedure tb0019_nested1;

    begin
       writeln;
       tb0019_a:=1;
    end;

  begin
  end;
{$pop}

{ Case tb0040.pp }
{$push}
{ Old file: tbs0045.pp }
{  shows problem with virtual private methods (might not be a true bugs but more of an incompatibility?) the compiler warns now if there is a private and virtual method }


TYPE
  tb0040_tmyexample =object
  public
   constructor tb0040_init;
   destructor tb0040_done; virtual;
  private
   procedure tb0040_mytest;virtual;       { syntax error --> should give only a
warning ? }
  end;

  constructor tb0040_tmyexample.tb0040_init;
  begin
  end;

  destructor tb0040_tmyexample.tb0040_done;
  Begin
  end;

  procedure tb0040_tmyexample.tb0040_mytest;
  begin
  end;
{$pop}

begin
  { Case tb0018.pp }
  {$push}
begin
   tb0018_p:=@tb0018_a;
   tb0018_p:=@tb0018_tobject.tb0018_x;
   tb0018_p:=@tb0018_tobject.tb0018_c;
end;
  {$pop}

  { Case tb0019.pp }
  {$push}
begin
end;
  {$pop}

  { Case tb0040.pp }
  {$push}
Begin
end;
  {$pop}

end.
