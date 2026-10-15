unit NXInlineAssemblerUnit;

{$mode objfpc}

interface

function IntelAnswer: LongInt;
function ATTAnswer: LongInt;

implementation

{$asmmode intel}
function IntelAnswer: LongInt; assembler; nostackframe;
asm
  mov eax, 42
end;

{$asmmode att}
function ATTAnswer: LongInt; assembler; nostackframe;
asm
  movl $42, %eax
end;

end.
