{ Copyright (c) 2026 Kevin Collins.

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at https://mozilla.org/MPL/2.0/.

This Source Code Form is "Incompatible With Secondary Licenses",
as defined by the Mozilla Public License, v. 2.0.

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
