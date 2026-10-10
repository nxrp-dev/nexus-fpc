{ NexusFPC artifact identities. SPDX-License-Identifier: GPL-2.0-or-later }
unit nxartifactid;

{$mode objfpc}

interface

const
  NexusPPUSignature = 'NXU';
  NexusPCPSignature = 'NXP';

{ Package targets currently have 64-bit descriptor fields. Keep all 32 bits of
  the unit compatibility revision distinct from the compiler and header versions.
  The high byte is reserved; the runtime descriptor's NXPK magic names the family. }
function NexusCompilerIdentity(HeaderVersion: Byte; CompilerVersion: Word;
  UnitRevision: Cardinal): QWord;

implementation

function NexusCompilerIdentity(HeaderVersion: Byte; CompilerVersion: Word;
  UnitRevision: Cardinal): QWord;
begin
  Result:=(QWord(HeaderVersion) shl 48) or
          (QWord(CompilerVersion) shl 32) or QWord(UnitRevision);
end;

end.
