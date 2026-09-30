program NXClangRegistration;

{$mode objfpc}{$H+}

uses
  GlobType, Systems, Triplet, I_Android, AGX86ATT;

procedure CheckTarget(const AInfo: TSystemInfo; const ATriple: AnsiString);
begin
  Target_Info := AInfo;
  if not Set_Target_Asm(Target_Info.Assem) then
    Halt(1);
  if (Target_Asm.Id <> As_Clang_Gas) or (Target_Asm.AsmBin <> 'clang') then
    Halt(2);
  if TargetTriplet(Triplet_LLVM) <> ATriple then
    Halt(3);
  WriteLn(Target_Info.ShortName, ': ', TargetTriplet(Triplet_LLVM), ' -> ', Target_Asm.AsmBin);
end;

begin
  CheckTarget(System_X86_64_Android_Info, 'x86_64-unknown-linux-android');
end.
