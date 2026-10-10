{ Typed New expressions and object destruction through With. }
{ Original case IDs and variable scopes are retained below. }

{ Case tb0125.pp }
{$push}
{ Old file: tbs0144.pp }
{ problem with 'with object do'                         OK 0.99.7 (PFV) }

type
tb0125_tobject = object
  Constructor tb0125_init;
  Destructor tb0125_done;
end;
tb0125_pobject = ^tb0125_tobject;

Constructor tb0125_tobject.tb0125_init;
begin end;
Destructor tb0125_tobject.tb0125_done;
begin end;

var tb0125_p:tb0125_pobject;
{$pop}

{ Case tb0141.pp }
{$push}
{ Old file: tbs0169.pp }
{ missing new(type) support for not object/class             OK 0.99.9 (PM) }

type
  tb0141_psearchrec=^longint;

Var tb0141_sr : tb0141_psearchrec;
{$pop}

begin
  { Case tb0125.pp }
  {$push}
begin
New(tb0125_p,tb0125_init);
with tb0125_p^ do tb0125_done; { Compiler PANIC here ! }
Dispose(tb0125_p);
end;
  {$pop}

  { Case tb0141.pp }
  {$push}
begin
  tb0141_sr := New(tb0141_psearchrec);
  tb0141_sr^ := 45;
  if tb0141_sr^<>45 then
    Halt(1);
  Dispose(tb0141_sr);
end;
  {$pop}

end.
