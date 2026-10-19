{ Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception }
program X86MovzxMemoryOperand;

{$mode objfpc}{$H+}

uses obNXTestRegistry, obNXTestContext, utNXTestConsole, BaseUnix, CgBase, CgUtils, CPUBase, CPUInfo, Globals,
  AAsmBase, AAsmData, AAsmTai, AAsmCPU, AOptX86;

var TestContext: TNXTestContext;

const
  cMapFixedNoReplace = $100000;
  cMappingSize = 4096;

type
  TProbeOptimizer = class(TX86AsmOptimizer)
  public
    function OptimizeMove(var AInstruction: TAI): Boolean;
  end;

  { The instruction still owns its original allocation. Restore that allocation
    before destruction, including when the faulty optimizer deletes the load. }
  TMappedLoad = class(TAICPU)
  private
    FOriginalReference: PReference;
  public
    procedure UseMappedReference(AReference: PReference);
    destructor Destroy; override;
  end;

var
  lChecks: LongInt;

function TProbeOptimizer.OptimizeMove(var AInstruction: TAI): Boolean;
begin
  Result := OptPass1Movx(AInstruction);
end;

procedure TMappedLoad.UseMappedReference(AReference: PReference);
begin
  FOriginalReference := oper[0]^.ref;
  AReference^ := FOriginalReference^;
  oper[0]^.ref := AReference;
end;

destructor TMappedLoad.Destroy;
begin
  if Assigned(FOriginalReference) then
    oper[0]^.ref := FOriginalReference;
  inherited Destroy;
end;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  Inc(lChecks);
  if not ACondition then
  begin
    TestContext.Fail(AMessage);
  end;
end;

procedure TestMove(ASize: TOpSize; ASourceRegister, ADestination: TRegister;
  AAddress: PtrUInt; const AName: string);
var
  lList: TAsmList;
  lOptimizer: TProbeOptimizer;
  lLoad, lAnd: TAICPU;
  lInstruction, lCursor: TAI;
  lReference: TReference;
  lMappedReference: PReference;
  lChanged, lFound: Boolean;
begin
  lMappedReference := nil;
  lList := TAsmList.Create;
  lOptimizer := TProbeOptimizer.Create(lList);
  try
    if AAddress <> 0 then
    begin
      lMappedReference := fpMMap(Pointer(AAddress), cMappingSize,
        PROT_READ or PROT_WRITE,
        MAP_PRIVATE or MAP_ANONYMOUS or cMapFixedNoReplace, -1, 0);
      if Pointer(lMappedReference) <> Pointer(AAddress) then
      begin
        WriteLn('FAIL: cannot reserve diagnostic address ', HexStr(AAddress, 8));
        TestContext.Fail('Could not reserve the required optimizer probe address');
      end;
      Reference_Reset(lReference, 1, []);
      lReference.Base := NR_EBX;
      lLoad := TMappedLoad.op_ref_reg(A_MOVZX, ASize, lReference, ADestination);
      TMappedLoad(lLoad).UseMappedReference(lMappedReference);
    end
    else
      lLoad := TAICPU.op_reg_reg(A_MOVZX, ASize, ASourceRegister, ADestination);
    lList.Concat(lLoad);
    lAnd := TAICPU.op_const_reg(A_AND, reg2opsize(ADestination), $0F, ADestination);
    lList.Concat(lAnd);
    lList.Concat(TAICPU.op_reg_reg(A_TEST, reg2opsize(ADestination),
      ADestination, ADestination));
    lOptimizer.IncludeRegInUsedRegs(ADestination, lOptimizer.UsedRegs);
    lInstruction := lLoad;
    lChanged := lOptimizer.OptimizeMove(lInstruction);
    lFound := False;
    lCursor := TAI(lList.First);
    while Assigned(lCursor) do
    begin
      if lCursor = lLoad then
        lFound := True;
      lCursor := TAI(lCursor.Next);
    end;
    if AAddress <> 0 then
    begin
      Check(not lChanged and lFound, AName + ': retain memory load');
      if lFound then
        Check((lLoad.opcode = A_MOVZX) and (lLoad.oper[0]^.typ = top_ref) and
          (lLoad.oper[0]^.ref = lMappedReference), AName + ': retain memory operand');
    end
    else if lOptimizer.SuperRegistersEqual(ASourceRegister, ADestination) then
      Check(lChanged and (lAnd.opsize < reg2opsize(ADestination)),
        AName + ': retain register-mask optimization')
    else
      Check(not lChanged and lFound, AName + ': retain distinct-register load');
  finally
    lOptimizer.Free;
    lList.Free;
    if Assigned(lMappedReference) then
      fpMUnMap(lMappedReference, cMappingSize);
  end;
end;

procedure TestSize(ASize: TOpSize; ASource, ADestination, AOther: TRegister;
  const AName: string);
begin
  { These valid descriptor addresses differ only in register-type bits when
    misread through TOper.reg. The first collides with the EAX-family encoding. }
  TestMove(ASize, NR_NO, ADestination, $01040000, AName + ' collision');
  TestMove(ASize, NR_NO, ADestination, $02040000, AName + ' control');
  TestMove(ASize, ASource, ADestination, 0, AName + ' same register');
  TestMove(ASize, ASource, AOther, 0, AName + ' distinct registers');
end;

procedure RunCase(AContext: TNXTestContext);
begin
  TestContext := AContext;
  CurrentSettings := Default_Settings;
  CurrentSettings.OptimizerSwitches := level2optimizerswitches;
  TestSize(S_BL, NR_AL, NR_EAX, NR_EDX, 'byte to dword');
  TestSize(S_WL, NR_AX, NR_EAX, NR_EDX, 'word to dword');
  { The x86-64 generator also uses these dword MOVZX forms for unsigned
    extension to qword: a dword write implicitly clears the upper 32 bits. }
  WriteLn('PASS: ', lChecks, ' memory-load and register-mask checks');
end;
var lRegistry: TNXTestRegistry;
begin
  lRegistry := TNXTestRegistry.Create;
  try
    lRegistry.AddSuite('Compiler.X86Optimizer').AddTest('MemoryOperandsAndRegisterMasks', @RunCase, 'compiler-units');
    ExitCode := RunConsoleTests(lRegistry);
  finally lRegistry.Free; end;
end.
