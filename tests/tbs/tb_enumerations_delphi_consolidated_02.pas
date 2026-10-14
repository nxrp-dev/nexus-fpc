{ Consolidated enumerations regressions; original case IDs and assertions are retained. }
{ %NORUN }
program nexus_consolidated_tests;
{$mode delphi}

{ Case tb_enum_boundaries_delphi_compile_01.pas }
{$push}

{ Explicit enumeration sentinel casts with checked and unchecked assignments. }
{ Original case IDs and variable scopes are retained below. }



{ Case tb0693.pas }
{$push}
{$r+}

    type
      tb0693_tlanguages = (
        tb0693_lone,
        tb0693_ltwo,
        tb0693_lthree,
        tb0693_lfour
      );

    const
      tb0693_language_none = tb0693_tlanguages(255);
    var
      tb0693_lang: tb0693_tlanguages;
{$pop}

{ Case tb0693a.pas }
{$push}
{$R-}
type
  tb0693a_tlanguages = (
    tb0693a_lone,
    tb0693a_ltwo,
    tb0693a_lthree,
    tb0693a_lfour
  );

const
  tb0693a_language_none = tb0693a_tlanguages(255);

type
 tb0693a_tlanguage = record
   tb0693a_index : tb0693a_tlanguages;
 end;

var
  tb0693a_lang: tb0693a_tlanguages;
  tb0693a_currentlanguage: tb0693a_tlanguage = (
    tb0693a_index:  tb0693a_language_none
  );
{$pop}


{$pop}

{ Case tw22860.pas }
{$push}




{$ifdef fpc}

{$endif}

type
  tw22860_TZoneID=(
    tw22860_zNone=-1,
    tw22860_zSystem=tw22860_zNone, // LC system parameters
    tw22860_zOven=0, // GC or LC column temperature
    tw22860_zInj=$10000,
    tw22860_zInjA=tw22860_zInj,
    tw22860_zInjB=tw22860_zInj + 1,
    tw22860_zInjC=tw22860_zInj + 2,
    tw22860_zInjD=tw22860_zInj + 3,
    tw22860_zDet=$20000, // GC and LC detectors
    tw22860_zDetA=tw22860_zDet,
    tw22860_zDetB=tw22860_zDet + 1,
    tw22860_zDetC=tw22860_zDet + 2,
    tw22860_zDetD=tw22860_zDet + 3,
    tw22860_zAux=$30000,
    tw22860_zAux1=tw22860_zAux,
    tw22860_zAux2=tw22860_zAux + 1,
    tw22860_zAux3=tw22860_zAux + 2,
    //LC
    tw22860_zPump=tw22860_zInj,
    tw22860_zPumpA=tw22860_zInjA,
    tw22860_zPumpB=tw22860_zInjB,
    tw22860_zPumpC=tw22860_zInjC,
    tw22860_zPumpD=tw22860_zInjD,

    tw22860_zEvents  = $00040000, //events manager zone
    tw22860_zSampler = $00050000,  // autosampler
    tw22860_zDevice  = $40000000,  // the device itself
    tw22860_zBlock   = $20000000  // the block of device
  );


{$pop}

{ Case tw39876a.pas }
{$push}






type
   tw39876a_TInputTypes = (tw39876a_itText, tw39876a_itPassWord, tw39876a_itRadio, tw39876a_itCheckbox, tw39876a_itHidden, tw39876a_itTel,
                 tw39876a_itNumber, tw39876a_itUrl, tw39876a_itEmail, tw39876a_itRrange, tw39876a_itDate, tw39876a_itMonth, tw39876a_itWeek);

var
   tw39876a_ts: string;
   tw39876a_anIT: tw39876a_TInputTypes;


{$pop}

begin

{ Case tb_enum_boundaries_delphi_compile_01.pas }
{$push}

{$push}
{$r+}
{$pop}
{$push}
{$R-}
{$pop}
begin
  { Case tb0693.pas }
  {$push}
{$R+}
begin
     tb0693_lang := tb0693_language_none;  //line 20
    end;
  {$pop}

  { Case tb0693a.pas }
  {$push}
{$R-}
begin
  tb0693a_lang := tb0693a_language_none;
end;
  {$pop}

end;
{$pop}

{ Case tw22860.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
end;
{$pop}

{ Case tw39876a.pas }
{$push}

begin
   tw39876a_ts := 'itradio, tuesday, 3';
   ReadStr(tw39876a_ts, tw39876a_anIT); // <== this is not compiled ...
end;
{$pop}

end.
