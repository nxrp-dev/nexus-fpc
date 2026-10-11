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

{ Case tb0404.pp }
{$push}
type
  tb0404_g = object
    public
      tb0404_b:procedure;
    { the 1.1 compiler parses the next "public" as a procdirective of the preceding procedure }
    public
      constructor tb0404_init;
  end;

  constructor tb0404_g.tb0404_init;
    begin
      tb0404_b:=nil;
    end;
{$pop}

{ Case tb0458.pp }
{$push}
type tb0458_smallword=word;

Type  tb0458_localheader     = Record
        Time          : Longint;
      End;

Type tb0458_pkzipobject = Object
       Buf         : longint;

       Constructor ZIPInit;
       Procedure FindFirstEntry;   Virtual;
     End; {PkzipObject}

     tb0458_pkzipptr = ^tb0458_pkzipobject;


Constructor tb0458_pkzipobject.ZIPInit;
Begin
End;


Procedure tb0458_pkzipobject.FindFirstEntry;
var tb0458_localheaderbuf: tb0458_localheader ABSOLUTE buf;
Begin
  tb0458_localheaderbuf.Time:=12341234;
End;

var
  tb0458_o : tb0458_pkzipobject;
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

  { Case tb0404.pp }
  {$push}
begin
end;
  {$pop}

  { Case tb0458.pp }
  {$push}
begin
  tb0458_o.ZIPInit;
  tb0458_o.FindFirstEntry;
  if tb0458_o.Buf<>12341234 then
    begin
      writeln('error');
      halt(1);
    end;
End;
  {$pop}

end.
