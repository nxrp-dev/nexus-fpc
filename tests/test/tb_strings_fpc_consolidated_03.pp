{ Consolidated strings regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}

{ Case tmultilinestring2.pp }
{$push}


{$modeswitch MultiLineStrings}

var tmultilinestring2_MyStringV: AnsiString =
`
Hey
Hey
Hey
`;

const tmultilinestring2_MyStringC: AnsiString =
`
Hey
Hey
Hey
`;


{$pop}

{ Case tmultilinestring3.pp }
{$push}


{$modeswitch MultiLineStrings}

var tmultilinestring3_MyStringV: ShortString =
`
Hey
Hey
Hey
`;

const tmultilinestring3_MyStringC: ShortString =
`
Hey
Hey
Hey
`;


{$pop}

{ Case tmultilinestring37.pp }
{$push}

// Test corner case backtick
{$modeswitch multilinestrings}
var
  tmultilinestring37_s:string;

{$pop}

{ Case tmultilinestring4.pp }
{$push}


{$modeswitch MultiLineStrings}

var tmultilinestring4_MyStringV: WideString =
`
Hey
Hey
Hey
`;

const tmultilinestring4_MyStringC: WideString =
`
Hey
Hey
Hey
`;


{$pop}

{ Case tmultilinestring5.pp }
{$push}


{$modeswitch MultiLineStrings}

var tmultilinestring5_MyStringV: UnicodeString =
`
Hey
Hey
Hey
`;

const tmultilinestring5_MyStringC: UnicodeString =
`
Hey
Hey
Hey
`;


{$pop}

begin

{ Case tmultilinestring2.pp }
{$push}
{$modeswitch MultiLineStrings}
begin
  Write(tmultilinestring2_MyStringV);
  Write(tmultilinestring2_MyStringC);
end;
{$pop}

{ Case tmultilinestring3.pp }
{$push}
{$modeswitch MultiLineStrings}
begin
  Write(tmultilinestring3_MyStringV);
  Write(tmultilinestring3_MyStringC);
end;
{$pop}

{ Case tmultilinestring37.pp }
{$push}
{$modeswitch multilinestrings}
begin
  tmultilinestring37_s:=
'''
`
'''
;
  writeln('>>>',tmultilinestring37_s,'<<<');
end;
{$pop}

{ Case tmultilinestring4.pp }
{$push}
{$modeswitch MultiLineStrings}
begin
  Write(tmultilinestring4_MyStringV);
  Write(tmultilinestring4_MyStringC);
end;
{$pop}

{ Case tmultilinestring5.pp }
{$push}
{$modeswitch MultiLineStrings}
begin
  Write(tmultilinestring5_MyStringV);
  Write(tmultilinestring5_MyStringC);
end;
{$pop}

end.
