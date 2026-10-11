{ Consolidated interfaces regressions; original case IDs and assertions are retained. }
{ %NORUN }
program nexus_consolidated_tests;
{$mode delphi}

{ Case tw26481.pp }
{$push}






type
  tw26481_IComparer<T> = interface
    function Compare(constref Left, Right: T): Integer; overload;
  end;

  tw26481_TOrdinalComparer<T, THashFactory> = class(TInterfacedObject, tw26481_IComparer<T>)
  protected class var
    FComparer: tw26481_IComparer<T>;
    FTest: TClass;
  public
    function Compare(constref Left, Right: T): Integer; virtual; abstract;
  end;

  tw26481_TGOrdinalStringComparer<T, THashFactory> = class(tw26481_TOrdinalComparer<T, THashFactory>)
  public
    function Compare(constref ALeft, ARight: T): Integer; override;
  end;

function tw26481_TGOrdinalStringComparer<T, THashFactory>.Compare(constref ALeft,
  ARight: T): Integer;
begin
  Result := FComparer.Compare(ALeft, ARight);
end;


{$pop}

{ Case tw8140b.pp }
{$push}


{$ifdef fpc}

{$endif}

type
 tw8140b_inullinterface = interface
  //no referencecount, only for fpc, not available in delphi
 end;

 tw8140b_locateresultty = (tw8140b_loc_timeout,tw8140b_loc_notfound,tw8140b_loc_ok);

 tw8140b_tfield = class
 end;

 tw8140b_locateoptionty = (tw8140b_loo_caseinsensitive,tw8140b_loo_partialkey,
                        tw8140b_loo_noforeward,tw8140b_loo_nobackward);
 tw8140b_locateoptionsty  = set of tw8140b_locateoptionty;

 tw8140b_imselocate = interface(tw8140b_inullinterface)['{2680958F-F954-DA11-9015-00C0CA1308FF}']
   function locate(const key: integer; const field: tw8140b_tfield;
                     const options: tw8140b_locateoptionsty = []): tw8140b_locateresultty;
 end;

 tw8140b_imselocate2 = interface(tw8140b_imselocate)['{2680958F-F954-DA11-9015-00C0CA130801}']
   function locate(const key: string; const field: tw8140b_tfield;
                 const options: tw8140b_locateoptionsty = []): tw8140b_locateresultty;
 end;


{$pop}

{ Case tw8140f.pp }
{$push}


{$ifdef fpc}

{$endif}

type
 tw8140f_inullinterface = interface
  //no referencecount, only for fpc, not available in delphi
 end;

 tw8140f_locateresultty = (tw8140f_loc_timeout,tw8140f_loc_notfound,tw8140f_loc_ok);

 tw8140f_tfield = class
 end;

 tw8140f_locateoptionty = (tw8140f_loo_caseinsensitive,tw8140f_loo_partialkey,
                        tw8140f_loo_noforeward,tw8140f_loo_nobackward);
 tw8140f_locateoptionsty  = set of tw8140f_locateoptionty;

 tw8140f_imselocate = interface(tw8140f_inullinterface)['{2680958F-F954-DA11-9015-00C0CA1308FF}']
   function locate(const key: integer; const field: tw8140f_tfield;
                     const options: tw8140f_locateoptionsty = []): tw8140f_locateresultty; overload;
 end;

 tw8140f_imselocate2 = interface(tw8140f_imselocate)['{2680958F-F954-DA11-9015-00C0CA130801}']
   function locate(const key: string; const field: tw8140f_tfield;
                 const options: tw8140f_locateoptionsty = []): tw8140f_locateresultty; overload;
 end;

 tw8140f_tc = class(tinterfacedobject,tw8140f_imselocate2)
   function locate(const key: integer; const field: tw8140f_tfield;
                     const options: tw8140f_locateoptionsty = []): tw8140f_locateresultty;overload;
   function locate(const key: string; const field: tw8140f_tfield;
                     const options: tw8140f_locateoptionsty = []): tw8140f_locateresultty;overload;
 end;

 function tw8140f_tc.locate(const key: integer; const field: tw8140f_tfield;
                     const options: tw8140f_locateoptionsty = []): tw8140f_locateresultty;
   begin
   end;

 function tw8140f_tc.locate(const key: string; const field: tw8140f_tfield;
                     const options: tw8140f_locateoptionsty = []): tw8140f_locateresultty;
   begin
   end;



{$pop}

begin

{ Case tw26481.pp }
{$push}

begin
end;
{$pop}

{ Case tw8140b.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
end;
{$pop}

{ Case tw8140f.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
end;
{$pop}

end.
