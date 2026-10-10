program identity_encoding;
{$mode objfpc}
uses nxartifactid;

procedure Check(Value: Boolean);
begin
  if not Value then Halt(1);
end;

begin
  Check(NexusCompilerIdentity(208,$c181,34)=$00d0c18100000022);
  { These two distinct inputs collide with the old (compiler shl 8) or revision. }
  Check(NexusCompilerIdentity(208,$100,256)<>NexusCompilerIdentity(208,$101,0));
  Check(NexusCompilerIdentity(208,$c181,255)<>NexusCompilerIdentity(208,$c181,256));
  Check(NexusCompilerIdentity(208,$c181,256)<>NexusCompilerIdentity(208,$c181,257));
  Check(NexusCompilerIdentity(208,$c181,$ffffffff)=$00d0c181ffffffff);
  Check(NexusCompilerIdentity(255,$ffff,$ffffffff)=$00ffffffffffffff);
  Check(NexusCompilerIdentity(0,0,0)=0);
  Check(NexusCompilerIdentity(1,0,0)<>NexusCompilerIdentity(0,$ffff,$ffffffff));
  Check(NexusCompilerIdentity(0,1,0)<>NexusCompilerIdentity(0,0,$ffffffff));
  WriteLn('PASS independent identity fields');
end.
