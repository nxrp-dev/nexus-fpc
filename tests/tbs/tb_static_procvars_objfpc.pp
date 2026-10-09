{ ObjFPC static class method addresses from instance and global scopes. }

{ tw30936.pp }
{$MODE OBJFPC}

type
  TImplicitStaticProc = class
  public type
    TProcedure = procedure;
  private
    class procedure MyProc; static;
  public
    constructor Create;
  end;

{ TTest }

constructor TImplicitStaticProc.Create;
var
  aProc: TProcedure;
begin
  aProc := @MyProc;
  aProc;
end;

class procedure TImplicitStaticProc.MyProc;
begin
  Writeln('OK');
end;

{ tw30936b.pp }
{$MODE OBJFPC}

type
  TExplicitStaticProc = class
  public type
    TProcedure = procedure;
  private
    class procedure MyProc; static;
  public
    constructor Create;
  end;

{ TTest }

constructor TExplicitStaticProc.Create;
begin
end;

class procedure TExplicitStaticProc.MyProc;
begin
  Writeln('OK');
end;

var
  aProc: TProcedure;

begin
  { tw30936.pp }
  TImplicitStaticProc.Create;
  ;

  { tw30936b.pp }
  aProc := @TExplicitStaticProc.MyProc;
    aProc;
  ;
end.
