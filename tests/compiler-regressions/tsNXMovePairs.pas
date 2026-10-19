(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit tsNXMovePairs;

{$mode objfpc}{$H+}

interface

uses
  obNXTestRegistry;

procedure RegisterMovePairTests(ARegistry: TNXTestRegistry);

implementation

uses
  obNXTestContext;

{$IFDEF CPUX86_64}

type
  PValue = ^PtrUInt;
  PPValue = ^PValue;

var
  Values: array[0..1] of PtrUInt;
  References: array[0..2] of PValue = (nil, @Values[0], @Values[1]);
  AddressSlots: array[0..1] of PPValue;
  ValueSlots: array[0..1] of PValue;

{ Keep these two stores adjacent: with peephole optimization enabled, symbolic
  address constants must not be treated as adjacent memory loads for MOVDQU. }
procedure AddressForward(AContext: TNXTestContext);
begin
  FillChar(AddressSlots, SizeOf(AddressSlots), 0);

  AddressSlots[0] := @References[1];
  AddressSlots[1] := @References[2];

  AContext.AssertTrue(AddressSlots[0] = @References[1], 'First reference address');
  AContext.AssertTrue(AddressSlots[1] = @References[2], 'Second reference address');
end;

procedure AddressReverse(AContext: TNXTestContext);
begin
  FillChar(AddressSlots, SizeOf(AddressSlots), 0);

  AddressSlots[1] := @References[2];
  AddressSlots[0] := @References[1];

  AContext.AssertTrue(AddressSlots[0] = @References[1],
    'First reference address after descending stores');
  AContext.AssertTrue(AddressSlots[1] = @References[2],
    'Second reference address after descending stores');
end;

{ These copy pointer values from memory. They exercise the valid SIMD-copy
  pattern with the same offsets, separately from address formation above. }
procedure MemoryForward(AContext: TNXTestContext);
begin
  FillChar(ValueSlots, SizeOf(ValueSlots), 0);

  ValueSlots[0] := References[1];
  ValueSlots[1] := References[2];

  AContext.AssertTrue(ValueSlots[0] = @Values[0], 'First pointer value copied');
  AContext.AssertTrue(ValueSlots[1] = @Values[1], 'Second pointer value copied');
end;

procedure MemoryReverse(AContext: TNXTestContext);
begin
  FillChar(ValueSlots, SizeOf(ValueSlots), 0);

  ValueSlots[1] := References[2];
  ValueSlots[0] := References[1];

  AContext.AssertTrue(ValueSlots[0] = @Values[0],
    'First pointer value after descending copies');
  AContext.AssertTrue(ValueSlots[1] = @Values[1],
    'Second pointer value after descending copies');
end;

{$ENDIF}

procedure RegisterMovePairTests(ARegistry: TNXTestRegistry);
begin
  {$IFDEF CPUX86_64}
  with ARegistry.AddSuite('Compiler.X86.MovePairs') do
  begin
    AddTest('AddressForward', @AddressForward, 'compiler-codegen');
    AddTest('AddressReverse', @AddressReverse, 'compiler-codegen');
    AddTest('MemoryForward', @MemoryForward, 'compiler-codegen');
    AddTest('MemoryReverse', @MemoryReverse, 'compiler-codegen');
  end;
  {$ENDIF}
end;

end.
