unit tsNXArtifactIdentity;
{$mode objfpc}{$H+}
interface
uses obNXTestRegistry;
procedure RegisterArtifactIdentityTests(ARegistry: TNXTestRegistry);
implementation
uses nxartifactid, obNXTestContext;

procedure EncodingBoundaries(AContext: TNXTestContext);
begin
  AContext.AssertTrue(NexusCompilerIdentity(208,$c181,34)=$00d0c18100000022, 'Known packed identity');
  AContext.AssertTrue(NexusCompilerIdentity(208,$c181,$ffffffff)=$00d0c181ffffffff, 'Full-width unit revision');
  AContext.AssertTrue(NexusCompilerIdentity(255,$ffff,$ffffffff)=$00ffffffffffffff, 'Maximum fields; reserved high byte');
  AContext.AssertTrue(NexusCompilerIdentity(0,0,0)=0, 'Zero identity');
end;

procedure IndependentFields(AContext: TNXTestContext);
begin
  AContext.AssertTrue(NexusCompilerIdentity(208,$100,256)<>NexusCompilerIdentity(208,$101,0), 'Old overlapping-shift collision');
  AContext.AssertTrue(NexusCompilerIdentity(208,$c181,255)<>NexusCompilerIdentity(208,$c181,256), 'Revision crosses byte boundary');
  AContext.AssertTrue(NexusCompilerIdentity(208,$c181,256)<>NexusCompilerIdentity(208,$c181,257), 'Revision low bit remains significant');
  AContext.AssertTrue(NexusCompilerIdentity(1,0,0)<>NexusCompilerIdentity(0,$ffff,$ffffffff), 'Header cannot overlap compiler/revision');
  AContext.AssertTrue(NexusCompilerIdentity(0,1,0)<>NexusCompilerIdentity(0,0,$ffffffff), 'Compiler cannot overlap revision');
end;

procedure RegisterArtifactIdentityTests(ARegistry: TNXTestRegistry);
begin
  with ARegistry.AddSuite('Compiler.ArtifactIdentity') do
  begin
    AddTest('EncodingBoundaries', @EncodingBoundaries, 'artifact-identity');
    AddTest('IndependentFields', @IndependentFields, 'artifact-identity');
  end;
end;
end.
