{ Consolidated routines regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}

{ Case tpara4.pas }
{$push}
{ This test ensures that a "const TVarData" parameter is passed as a reference.
  This is required for Delphi compatibility as implementers of IVarInvokable or
  inheritors of TInvokableVariantType need to modify the variant data by using
  a pointer to the TVarData because it's passed as const and thus not modifiable
  by itself.
  This behavior is documented in so far as the C++ builder documentation shows
  that the same parameter is implemented as "const&". }



var
  tpara4_d: TVarData;

procedure tpara4_Test(const v: TVarData);
begin
  if @tpara4_d <> @v then
    Halt(1);
end;


{$pop}

{ Case tvecsimplify1.pas }
{$push}


const
  tvecsimplify1_SPangram = 'The quick brown fox jumps over the lazy dog';

function tvecsimplify1_GetChar: AnsiChar;
begin
  tvecsimplify1_GetChar := tvecsimplify1_SPangram[39];
end;


{$pop}

{ Case tvecsimplify1a.pas }
{$push}

{$H+}

const
  tvecsimplify1a_SPangram = 'The quick brown fox jumps over the lazy dog';

function tvecsimplify1a_GetChar: AnsiChar;
begin
  tvecsimplify1a_GetChar := tvecsimplify1a_SPangram[39];
end;


{$pop}

{ Case tvecsimplify2a.pas }
{$push}

{$H+}

const
  tvecsimplify2a_SSonnet = 'When forty winters shall besiege thy brow,'#10+
	'And dig deep trenches in thy beauty''s field,'#10+
	'Thy youth''s proud livery, so gazed on now,'#10+
	'Will be a tattered weed of small worth held.'#10+
	'Then being asked where all thy beauty lies,'#10+
	'Where all the treasure of thy lusty days,'#10+
	'To say within thine own deep-sunken eyes'#10+
	'Were an all-eating shame and thriftless praise.'#10+
	'How much more praise deserved thy beauty''s use'#10+
	'If thou couldst answer ''This fair child of mine'#10+
	'Shall sum my count, and make my old excuse'','#10+
	'Proving his beauty by succession thine.'#10+
	'This were to be new made when thou art old,'#10+
	'And see thy blood warm when thou feel''st it cold.';

function tvecsimplify2a_GetChar: AnsiChar;
begin
  tvecsimplify2a_GetChar := tvecsimplify2a_SSonnet[300];
end;


{$pop}

begin

{ Case tpara4.pas }
{$push}

begin
  tpara4_Test(tpara4_d);
end;
{$pop}

{ Case tvecsimplify1.pas }
{$push}

begin
  if tvecsimplify1_GetChar() <> 'y' then
    Halt(1);

  WriteLn('ok');
end;
{$pop}

{ Case tvecsimplify1a.pas }
{$push}
{$H+}
begin
  if tvecsimplify1a_GetChar() <> 'y' then
    Halt(1);

  WriteLn('ok');
end;
{$pop}

{ Case tvecsimplify2a.pas }
{$push}
{$H+}
begin
  if tvecsimplify2a_GetChar() <> 'y' then
    Halt(1);

  WriteLn('ok');
end;
{$pop}

end.
