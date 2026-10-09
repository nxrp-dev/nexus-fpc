{ Typed pointer, ordinal, character-array, subrange, set and WideChar constants. }

{ tb0033.pp }
{  tests const ps : ^string = nil;                     OK 0.9.9 (FK) }

CONST ps : ^STRING = nil;

{ tb0053.pp }
{  shows the problem with syntax error with ordinal     OK 0.99.1 (FK) }

Const
 S = ord('J');
 t: byte = ord('J');

{ tb0074.pp }
{  Shows incompatibility with borland's 'array of char'. OK 0.99.1 (FK) }

const
   EOL : array [1..2] of char = #13 + #10;

{ tb0080.pp }
{ The unfixable bugs. Maybe we find a solution one day.  OK 0.99.6 (FK) }

{The unfixable bug. Maybe we get an idea when we keep looking at it.
 Daniel Mantione 5 februari 1998.}

const
        a:1..4=2;               {Crash 1.}
        b:set of 1..4=[2,3];    {Also crashes, but is the same bug.}

{ tb0237.pp }
{ typecasting with const not possible                  OK 0.99.13 (PFV) }

  const test_byte=pchar(1);

{ tb0442.pp }
const
  CUnicodeNormal1  : WideChar = WideChar($FEFF);
  CUnicodeNormal2  : WideChar = #12;

begin
  { tb0080.pp }
  writeln(a);

  { tb0237.pp }
  writeln('Hello world');
end.
