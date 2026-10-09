{ Copyright (c) 2026 Kevin Collins.

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at https://mozilla.org/MPL/2.0/.

This Source Code Form is "Incompatible With Secondary Licenses",
as defined by the Mozilla Public License, v. 2.0.

SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
}
unit utNXImagePointers;
{$mode objfpc}{$H+}
{ Header inspection intentionally bypasses pointer checking; headers and padding
  are negative cases. Actual classifications call HeapTrc.CheckPointer explicitly. }
{$checkpointer off}
interface
function ValidateImagePointers(AForeignData: Pointer): Boolean;
function RejectImagePointer(ACase: LongInt): Boolean;
implementation
uses Windows, SysUtils, HeapTrc;
{$link pointer_data.obj}
var
  ReadOnlyData: array[0..16] of Byte; external name 'NXReadOnlyData';
  ProtectedData: array[0..4095] of Byte; external name 'NXProtectedData';
  InitializedData: Byte = 42;
  ZeroData: array[0..65535] of Byte;
threadvar
  ThreadData: Byte;

procedure CodeAddress;
begin
  Inc(InitializedData);
end;

function ImageData(AValue: Pointer): Boolean;
begin
  Result := System.IsImageDataPointer(AValue);
  if Result then HeapTrc.CheckPointer(AValue);
end;

function SectionPadding: Pointer;
var
  lBase: PtrUInt;
  lNT: PImageNTHeaders;
  lSection: PImageSectionHeader;
  lIndex: LongInt;
begin
  Result := nil;
  lBase := HInstance;
  lNT := PImageNTHeaders(lBase + PtrUInt(PImageDosHeader(lBase)^._lfanew));
  lSection := IMAGE_FIRST_SECTION(lNT);
  for lIndex := 1 to lNT^.FileHeader.NumberOfSections do
  begin
    if ((lSection^.Characteristics and IMAGE_SCN_CNT_INITIALIZED_DATA) <> 0) and
      ((lSection^.Characteristics and IMAGE_SCN_MEM_EXECUTE) = 0) and
      ((lSection^.Misc.VirtualSize mod lNT^.OptionalHeader.SectionAlignment) <> 0) then
      Exit(Pointer(lBase + lSection^.VirtualAddress + lSection^.Misc.VirtualSize));
    Inc(lSection);
  end;
end;

function ValidateSectionEdges: Boolean;
var
  lBase: PtrUInt;
  lNT: PImageNTHeaders;
  lSection: PImageSectionHeader;
  lIndex, lCount: LongInt;
  lStart, lLast: Pointer;
  lInfo: TMemoryBasicInformation;
begin
  Result := false;
  lBase := HInstance;
  lNT := PImageNTHeaders(lBase + PtrUInt(PImageDosHeader(lBase)^._lfanew));
  lSection := IMAGE_FIRST_SECTION(lNT);
  lCount := 0;
  for lIndex := 1 to lNT^.FileHeader.NumberOfSections do
  begin
    if ((lSection^.Characteristics and (IMAGE_SCN_CNT_INITIALIZED_DATA or
      IMAGE_SCN_CNT_UNINITIALIZED_DATA)) <> 0) and
      ((lSection^.Characteristics and IMAGE_SCN_MEM_EXECUTE) = 0) and
      ((lSection^.Characteristics and IMAGE_SCN_MEM_READ) <> 0) and
      (lSection^.Misc.VirtualSize <> 0) then
    begin
      lStart := Pointer(lBase + lSection^.VirtualAddress);
      lLast := Pointer(PtrUInt(lStart) + lSection^.Misc.VirtualSize - 1);
      if (VirtualQuery(lStart, lInfo, SizeOf(lInfo)) = SizeOf(lInfo)) and
        (lInfo.State = MEM_COMMIT) and ((lInfo.Protect and (PAGE_GUARD or PAGE_NOACCESS)) = 0) then
      begin
        if not ImageData(lStart) or not ImageData(lLast) then Exit;
        Inc(lCount);
      end;
    end;
    Inc(lSection);
  end;
  Result := (lCount >= 3) and (SectionPadding <> nil) and
    not System.IsImageDataPointer(SectionPadding);
end;

function ValidateImagePointers(AForeignData: Pointer): Boolean;
var
  lHeap: Pointer;
  lStack: Byte;
  lInfo: TMemoryBasicInformation;
  lError: DWord;
begin
  Result := false;
  if not ImageData(@InitializedData) or not ImageData(@ZeroData[0]) or
    not ImageData(@ZeroData[High(ZeroData)]) or not ImageData(@ReadOnlyData[0]) or
    not ImageData(@ReadOnlyData[High(ReadOnlyData)]) or not ImageData(@ProtectedData[0]) then Exit;
  if AForeignData <> nil then
    if not ImageData(AForeignData) then Exit;
  if (VirtualQuery(@ReadOnlyData[0], lInfo, SizeOf(lInfo)) <> SizeOf(lInfo)) or
    (lInfo.Protect <> PAGE_READONLY) then Exit;
  if (InitializedData <> 42) or (ZeroData[High(ZeroData)] <> 0) or
    (ReadOnlyData[High(ReadOnlyData)] <> 99) then Exit;
  if not ValidateSectionEdges then Exit;
  ThreadData := 9;
  lStack := 10;
  if System.IsImageDataPointer(@lStack) or System.IsImageDataPointer(@ThreadData) then Exit;
  HeapTrc.CheckPointer(@lStack);
  HeapTrc.CheckPointer(@ThreadData);
  GetMem(lHeap, 32);
  try
    if System.IsImageDataPointer(lHeap) then Exit;
    HeapTrc.CheckPointer(lHeap);
    HeapTrc.CheckPointer(Pointer(PtrUInt(lHeap) + 31));
  finally
    FreeMem(lHeap);
  end;
  SetLastError(12345);
  Result := System.IsImageDataPointer(@InitializedData);
  lError := GetLastError;
  Result := Result and (lError = 12345);
  SetLastError(23456);
  if System.IsImageDataPointer(Pointer(1)) then Result := false;
  if GetLastError <> 23456 then Result := false;
end;

function RejectImagePointer(ACase: LongInt): Boolean;
var
  lPointer, lAllocated: Pointer;
  lProtection, lIgnored: DWord;
  lProtected: Boolean;
begin
  Result := false;
  lAllocated := nil;
  lProtected := false;
  case ACase of
    1: lPointer := nil;
    2: lPointer := Pointer(1);
    3: lPointer := @CodeAddress;
    4: lPointer := Pointer(HInstance);
    5: lPointer := SectionPadding;
    6, 7, 10:
      begin
        lProtection := PAGE_READWRITE;
        if ACase = 7 then lProtection := PAGE_NOACCESS;
        lAllocated := VirtualAlloc(nil, 4096, MEM_RESERVE or MEM_COMMIT, lProtection);
        if lAllocated = nil then Exit;
        lPointer := lAllocated;
        if ACase = 6 then
        begin
          { Readable private memory with a forged PE signature is not an image. }
          PWord(lPointer)^ := $5a4d;
          PDWord(PtrUInt(lPointer) + $3c)^ := $80;
          PDWord(PtrUInt(lPointer) + $80)^ := $4550;
        end;
        if ACase = 10 then
        begin
          if not VirtualFree(lAllocated, 0, MEM_RELEASE) then Exit;
          lAllocated := nil;
        end;
      end;
    8, 9:
      begin
        lPointer := @ProtectedData[0];
        lProtection := PAGE_READWRITE or PAGE_GUARD;
        if ACase = 9 then lProtection := PAGE_NOACCESS;
        lProtected := VirtualProtect(lPointer, 4096, lProtection, lIgnored);
        if not lProtected then Exit;
        lProtection := lIgnored;
      end;
    else Exit;
  end;
  try
    if (ACase = 5) and (lPointer = nil) then Exit;
    if System.IsImageDataPointer(lPointer) then Exit;
    { CheckPointer calls System.RunError: rejection terminates this child. }
    WriteLn('CHECK invalid pointer case ', ACase);
    Flush(Output);
    HeapTrc.CheckPointer(lPointer);
  finally
    if lProtected then
      if not VirtualProtect(lPointer, 4096, lProtection, lIgnored) then Result := false;
    if lAllocated <> nil then
      if not VirtualFree(lAllocated, 0, MEM_RELEASE) then Result := false;
  end;
end;
end.
