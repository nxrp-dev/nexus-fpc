{ Codepage-aware literal and numeric WideChar casts. }
{ Original case IDs and variable scopes are retained below. }

{$mode fpc}

{ Case tb0397.pp }
{$push}
{$codepage cp850}
{$pop}

{ Case tb0398.pp }
{$push}
{$codepage cp850}
{$pop}

begin
  { Case tb0397.pp }
  {$push}
begin
   if ord(widechar('Ž'))<>196 then
     halt(1);
   halt(0);
end;
  {$pop}

  { Case tb0398.pp }
  {$push}
begin
   if ord(widechar(#196))<>9472 then
     halt(1);
   if ord(#0196)<>196 then
     halt(1);
   if ord(widechar(#$a6))<>170 then
     halt(1);
   if ord(#$0a6)<>166 then
     halt(1);
   halt(0);
end;
  {$pop}

end.
