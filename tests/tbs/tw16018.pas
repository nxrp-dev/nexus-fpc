program testbug;
{$APPTYPE CONSOLE}
{$ifdef fpc}
 {$mode delphi}
 {$ifdef cpui386}
  {$define cpu386}
 {$endif}
 {$ifdef cpu386}
  {$asmmode intel}
 {$endif}
 {$define caninline}
{$else}
 {$ifndef cpu64}
  {$define cpu32}
 {$endif}
{$endif}
{$ifdef win32}
 {$define windows}
{$endif}
{$ifdef win64}
 {$define windows}
{$endif}
{$ifdef wince}
 {$define windows}
{$endif}
{$rangechecks off}
{$extendedsyntax on}
{$hints off}
{$j+}

uses SysUtils,Math;

type TBesenNumber=double;

     PBesenDoubleBytes=^TBesenDoubleBytes;
     TBesenDoubleBytes=array[0..sizeof(double)-1] of byte;

const BesenDoubleZero:TBesenNumber=0.0;
      BesenDoubleNaN:TBesenDoubleBytes=($ff,$ff,$ff,$ff,$ff,$ff,$ff,$7f);
      BesenDoubleInfPos:TBesenDoubleBytes=($00,$00,$00,$00,$00,$00,$f0,$7f);
      BesenDoubleInfNeg:TBesenDoubleBytes=($00,$00,$00,$00,$00,$00,$f0,$ff);
      BesenDoubleMax:TBesenDoubleBytes=($ff,$ff,$ff,$ff,$ff,$ff,$ef,$7f);
      BesenDoubleMin:TBesenDoubleBytes=($01,$00,$00,$00,$00,$00,$00,$00);

function BesenIsNaN(const AValue:TBesenNumber):boolean; {$ifdef caninline}inline;{$endif}
begin
 result:=(int64(pointer(@AValue)^)=int64(pointer(@BesenDoubleNaN)^)) or IsNaN(AValue);
end;

function BesenIsInfinite(const AValue:TBesenNumber):boolean; {$ifdef caninline}inline;{$endif}
begin
 result:=(int64(pointer(@AValue)^)=int64(pointer(@BesenDoubleInfPos)^)) or (int64(pointer(@AValue)^)=int64(pointer(@BesenDoubleInfNeg)^)) or IsInfinite(AValue);
end;

function BesenIsFinite(const AValue:TBesenNumber):boolean; {$ifdef caninline}inline;{$endif}
begin
 result:=not (BesenIsNaN(AValue) or BesenIsInfinite(AValue));
end;

procedure BesenTestProc;
var x:double;
begin
 x:=8;
 if BesenIsFinite(x) then begin // Here will raise the "Internal error 2006111510" at positon with BesenIsFinite (on every other positon in the real big source code of my EcmaScript 5th edition implementation, where BesenIsFinite is used)
 end
 else
   halt(1);
end;

begin
 BesenTestProc;
end.
