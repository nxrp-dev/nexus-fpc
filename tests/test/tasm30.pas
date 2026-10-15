{ %NORUN }
{ %CPU=x86_64}

program tasm30;

begin
  asm
    enter $5,$1234
  end;
end.
