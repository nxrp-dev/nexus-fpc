{ Delphi self-references, forward class references and nested class declarations. }

{ tw0738.pp }
{$mode delphi}

type
 (*
 {$IFDEF FPC}
 SomeClass = class; { this line shouldn't be necessary }
 {$ENDIF}
 *)

 SomeClass = class
  SomeMember:SomeClass;
 end;

{ tw0739.pp }
{$mode delphi}

type
(* {$IFDEF FPC}
  y = class; { shouldn't be necessary }
{$ENDIF} *)
  x = class of y;
  y = class
   z:Boolean;
  end;

{ tw17945.pp }
{$mode delphi}
type
  TFoo = class
  public
    type
      TEnumerator = object
      private
        FFoo: TFoo; //Was error: Illegal expression
      end;
  end;

{ tw18086.pp }
{$mode delphi}

type
  TFoo1 = class; //Error: Type "TFoo1" is not completely defined

  TFoo2 = class //it compiles if TFoo2 is removed
  type
    TFoo3 = class
    end;
  end;

  TFoo1 = class
  end;

begin

end.
