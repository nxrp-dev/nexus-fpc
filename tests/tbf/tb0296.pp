{ %cpu=x86_64}
{ %fail }

begin
  asm
    cmov %eax,%ebx
  end;
end.
