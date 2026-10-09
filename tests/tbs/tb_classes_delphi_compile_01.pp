{ Classes regression cases; original case IDs are retained below. }
{ %NORUN }

{ Case tw16980.pp }
{$push}
{$mode delphi}
{$packset 4}
type
  tw16980_tcolorcomponent = (ccRed, ccGreen, ccBlue, ccAlpha);
  tw16980_tcolormask = set of tw16980_tcolorcomponent;

  tw16980_tglstatecache = class
  private
    tw16980_fcolorwritemask: array[0..15] of tw16980_tcolormask;
    procedure tw16980_setcolorwritemask(Index: Integer; const tw16980_value: tw16980_tcolormask);
  end;
  tw16980_tgluint = cardinal;
  tw16980_tglboolean = boolean;

var
  tw16980_glcolormaski: procedure(index: tw16980_tgluint; tw16980_r: tw16980_tglboolean; tw16980_g: tw16980_tglboolean;
                            tw16980_b: tw16980_tglboolean; tw16980_a: tw16980_tglboolean);{$IFDEF MSWINDOWS} stdcall; {$ENDIF} {$IFDEF UNIX} cdecl; {$ENDIF}

procedure tw16980_tglstatecache.tw16980_setcolorwritemask(Index: Integer;
  const tw16980_value: tw16980_tcolormask);
begin
//  if FColorWriteMask[Index]<>Value then
  begin
    tw16980_fcolorwritemask[Index] := tw16980_value;
    tw16980_glcolormaski(Index, ccRed in tw16980_value, ccGreen in tw16980_value, ccBlue in tw16980_value,
                 ccAlpha in tw16980_value);
  end;
end;
{$pop}

{ Case tw24486.pp }
{$push}
{$mode delphi}

type
  tw24486_tproc1 = procedure(a: integer);

var
  tw24486_proc1: tw24486_tproc1;

type
  tw24486_tclass1 = class
    class procedure tw24486_p1(a: integer); static;
  end;

{ tclass1 }

class procedure tw24486_tclass1.tw24486_p1(a: integer);
begin
end;
{$pop}

{ Case tw27349.pp }
{$push}
{$mode delphi}
{.$mode objfpc}
{.$modeswitch advancedrecords}

type

  tw27349_c = class

   type

    tw27349_tmyintf = class(TInterfacedObject, iinterface)
     function _AddRef : longint; {$IFNDEF WINDOWS}cdecl{$ELSE}stdcall{$ENDIF};
    end;

  end;

  tw27349_r = record

   type

    tw27349_tmyintf = class(TInterfacedObject, iinterface)
     function _AddRef : longint; {$IFNDEF WINDOWS}cdecl{$ELSE}stdcall{$ENDIF};
    end;

  end;

function tw27349_c.tw27349_tmyintf._AddRef: longint; {$IFNDEF WINDOWS}cdecl{$ELSE}stdcall{$ENDIF};
begin
 result := inherited _AddRef; // OK
end;

function tw27349_r.tw27349_tmyintf._AddRef: longint; {$IFNDEF WINDOWS}cdecl{$ELSE}stdcall{$ENDIF};
begin
 result := inherited _AddRef; // FAIL
end;
{$pop}

{ Case tw30179.pp }
{$push}
{$MODE DELPHI}

type
  tw30179_ttest1 = record
    class function tw30179_add<T>(const A, B: T): T; static; inline;
  end;

class function tw30179_ttest1.tw30179_add<T>(const A, B: T): T;
begin
  Result := A + B;
end;

procedure tw30179_main();
var
  tw30179_i: Integer;
begin
  tw30179_i := tw30179_ttest1.tw30179_add<Integer>(1, 2); // project1.lpr(14,26) Error: Identifier not found "Add$1"
end;
{$pop}

begin
  { Case tw24486.pp }
  {$push}

  begin
tw24486_proc1 := tw24486_tclass1.tw24486_p1;
  end;
  {$pop}

  { Case tw30179.pp }
  {$push}

  begin
tw30179_main();
  end;
  {$pop}

end.
