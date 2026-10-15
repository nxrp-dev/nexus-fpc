{ Consolidated enumerations regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode delphi}

{ Case tb_enum_constants_delphi_run_01.pas }
{$push}
{ Enumeration aliases and constant ordinal casts in Delphi mode. }
{ Original case IDs and variable scopes are retained below. }



{ Case tb0360.pas }
{$push}
type
  tb0360_e = (
    tb0360_ptrace_singlestep = 9,
    tb0360_pt_step = tb0360_ptrace_singlestep
  );
{$pop}

{ Case tb0370.pas }
{$push}
type
   tb0370_tenum = (tb0370_e1,tb0370_e2,tb0370_e3);

const
   tb0370_e256 = tb0370_tenum(256);
{$pop}


{$pop}

{ Case tw10890.pas }
{$push}




type tw10890_TXMLElemKind = (
 tw10890_elErrorFrm,
 tw10890_elInvolutiveness,
 tw10890_elIrreflexivity,
 tw10890_elIs,
 tw10890_elIt,
 tw10890_elIterEquality,
 tw10890_elIterStep,
 tw10890_elJustifiedProperty,
 tw10890_elJustifiedTheorem,
 tw10890_elLambdaVar,
 tw10890_elLet,
 tw10890_elLocusVar,
 tw10890_elMonomial,
 tw10890_elNot,
 tw10890_elPoweredVar,
 tw10890_elPred,
 tw10890_elPredInstance,
 tw10890_elPriority,
 tw10890_elPrivFunc,
 tw10890_elPrivPred,
 tw10890_elProjectivity,
 tw10890_elProof,
 tw10890_elTakeAsVar,
 tw10890_elTheorem,
 tw10890_elTheorems,
 tw10890_elThesis,
 tw10890_elThesisExpansions,
 tw10890_elTransitivity,
 tw10890_elTyp,
 tw10890_elUnexpectedProp,
 tw10890_elUniqueness,
 tw10890_elUnknownCorrCond,
 tw10890_elVar,
 tw10890_elVerum
 );

const tw10890_TermElKinds = [
 tw10890_elVar
 ];

const tw10890_FrmElKinds = [
 tw10890_elErrorFrm,
 tw10890_elIs,
 tw10890_elNot,
 tw10890_elPred,
 tw10890_elPrivPred,
 tw10890_elVerum
 ];

var tw10890_a:tw10890_TXMLElemKind;


{$pop}

{ Case tw34633a.pas }
{$push}

type tw34633a_tenum = (tw34633a_b0, tw34633a_b1, tw34633a_b2, tw34633a_bMax = high(dword));


{$pop}

{ Case tw4557.pas }
{$push}
{ Source provided for Free Pascal Bug Report 4557 }
{ Submitted by "Marek Mauder" on  2005-11-29 }
{ e-mail: pentar@seznam.cz }

{$IFDEF FPC}{$ENDIF}
type
  tw4557_TEnum = (tw4557_Item1 = 5, tw4557_Item2 = 10, tw4557_Item3 = 20);
var
  tw4557_Enum: tw4557_TEnum = tw4557_Item1;

{$pop}

begin

{ Case tb_enum_constants_delphi_run_01.pas }
{$push}

{$push}
{$pop}
{$push}
{$pop}
begin
  { Case tb0360.pas }
  {$push}
begin
end;
  {$pop}

  { Case tb0370.pas }
  {$push}
begin
end;
  {$pop}

end;
{$pop}

{ Case tw10890.pas }
{$push}

begin
  tw10890_a:=tw10890_elVerum;
  if not(tw10890_a in (tw10890_FrmElKinds + tw10890_TermElKinds)) then
    halt(1);
end;
{$pop}

{ Case tw34633a.pas }
{$push}

begin
  writeln(sizeof(tw34633a_tenum));
end;
{$pop}

{ Case tw4557.pas }
{$push}
{$IFDEF FPC}

{$ENDIF}
begin
  tw4557_Enum := Succ(tw4557_Enum);
end;
{$pop}

end.
