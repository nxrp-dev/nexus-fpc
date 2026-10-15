{ Consolidated control flow regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}

{ Case tconstprop1.pas }
{$push}
const
  tconstprop1_l = 1 shl 63;


{$pop}

{ Case tcstring1.pas }
{$push}
{$H+}
const
  tcstring1_s = 'asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3asdfvkh4vk347vhjvkh7j3';


{$pop}

{ Case tendian1.pas }
{$push}
var
  tendian1_l : dword;

{$pop}

begin

{ Case tconstprop1.pas }
{$push}

begin
  if tconstprop1_l<>$8000000000000000 then
    halt(1);
end;
{$pop}

{ Case tcstring1.pas }
{$push}
{$H+}
begin
  if length(tcstring1_s)<>1804 then
    halt(1);
  writeln('ok');
end;
{$pop}

{ Case tendian1.pas }
{$push}

begin
  tendian1_l:=$deadbeef;
  if SwapEndian(tendian1_l)=tendian1_l then
    halt(1);
  if SwapEndian(SwapEndian(tendian1_l))<>tendian1_l then
    halt(1);
  writeln('ok');
end;
{$pop}

end.
