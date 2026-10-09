{ Generics regression cases; original case IDs are retained below. }

{ Case tb0652.pp }
{$push}
const
  tb0652_w : dword = 123;
{$pop}

{ Case tw34385.pp }
{$push}
const
  tw34385_w : dword = 123;
  tw34385_n : dword = 48;
{$pop}

begin
  { Case tb0652.pp }
  {$push}

  begin
if (tb0652_w<=1) and (tb0652_w>=10) then
    halt(1);
  if (tb0652_w>=1) and (tb0652_w<=1000) then
    writeln('ok')
  else
    halt(1);
  end;
  {$pop}

  { Case tw34385.pp }
  {$push}

  begin
if (tw34385_w<=1) and (tw34385_w>=10) then
    begin
      writeln('error 1-10');
      halt(1);
    end;
  if (tw34385_w>=1) and (tw34385_w<=1000) then
    writeln('ok')
  else
    begin
      writeln('error 1-1000');
      halt(2);
    end;
  if (tw34385_n>44)and(tw34385_n<48) then
    begin
      writeln('error 48');
      halt(3);
    end;
  end;
  {$pop}

end.
