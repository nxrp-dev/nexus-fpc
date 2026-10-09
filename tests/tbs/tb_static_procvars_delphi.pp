{ Delphi static class method assignments from instance and global scopes. }

{ tw30936a.pp }
{$MODE DELPHI}

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
  aProc := MyProc;
  aProc;
end;

class procedure TImplicitStaticProc.MyProc;
begin
  Writeln('OK');
end;

{ tw30936c.pp }
{$MODE DELPHI}

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
  { tw30936a.pp }
  TImplicitStaticProc.Create;
  ;

  { tw30936c.pp }
  aProc := TExplicitStaticProc.MyProc;
    aProc;
  ;
end.
