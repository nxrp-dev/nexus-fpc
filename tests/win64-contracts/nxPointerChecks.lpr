{ Copyright (c) 2026 Kevin Collins.
SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
}
program nxPointerChecks;
{$mode objfpc}{$H+}
uses SysUtils, utNXImagePointers;
var
  lCase: LongInt;
begin
  if ParamStr(1) = 'valid' then
  begin
    if not ValidateImagePointers(nil) then Halt(1);
    WriteLn('PASS valid image data, section edges, stack, TLS and tracked heap');
  end
  else
  begin
    lCase := StrToInt(ParamStr(1));
    RejectImagePointer(lCase);
    Halt(2); { Unexpected return: setup failed or the invalid pointer was accepted. }
  end;
end.
