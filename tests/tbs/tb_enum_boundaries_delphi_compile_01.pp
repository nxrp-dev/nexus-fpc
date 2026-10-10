{ %norun }
{ Explicit enumeration sentinel casts with checked and unchecked assignments. }
{ Original case IDs and variable scopes are retained below. }

{$mode delphi}

{ Case tb0693.pp }
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

{ Case tb0693a.pp }
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

begin
  { Case tb0693.pp }
  {$push}
{$R+}
begin
     tb0693_lang := tb0693_language_none;  //line 20
    end;
  {$pop}

  { Case tb0693a.pp }
  {$push}
{$R-}
begin
  tb0693a_lang := tb0693a_language_none;
end;
  {$pop}

end.
