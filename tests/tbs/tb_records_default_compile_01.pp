{ Records regression cases; original case IDs are retained below. }
{ %NORUN }

{ Case tb0589.pp }
{$push}
type
  tb0589_ttest = record
    tb0589_f: array of tb0589_ttest;
  end;
{$pop}

{ Case tw15592.pp }
{$push}
TYPE
  tw15592_trtime = Record
    tw15592_rtday : Integer;
  end;
  tw15592_ttimerange = Record
    tw15592_trflags : Integer;
    tw15592_trtime : tw15592_trtime;
    case trType : Integer of
     0 : (trTime2 : tw15592_trtime);
     1 : (trMinutes : Integer);
  end;
{$pop}

{ Case tw37779.pp }
{$push}
type
  tw37779_complex = record
    tw37779_re : Double;
    tw37779_im : Double;
  end;
  tw37779_tcomplexarray = array of tw37779_complex;
  tw37779_tcomplexarrayarray = array of tw37779_tcomplexarray;

var
  tw37779_mc: array of array of array of array of tw37779_tcomplexarrayarray;
{$pop}

begin
  { Case tw37779.pp }
  {$push}

  begin
tw37779_mc := nil;
  tw37779_mc := Copy(tw37779_mc);
  end;
  {$pop}

end.
