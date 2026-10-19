{ Copyright (c) 2026 Kevin Collins.
SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
}
library nxPointerLibrary;
{$mode objfpc}{$H+}
uses utNXImagePointers;
function ValidatePointers(AForeignData: Pointer): LongInt; cdecl;
begin
  Result := Ord(ValidateImagePointers(AForeignData));
end;
function RejectPointer(ACase: LongInt): LongInt; cdecl;
begin
  Result := Ord(RejectImagePointer(ACase));
end;
exports ValidatePointers, RejectPointer;
begin
end.
