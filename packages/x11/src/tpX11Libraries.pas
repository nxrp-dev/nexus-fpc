// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
{$IFNDEF FPC_DOTTEDUNITS}
unit tpX11Libraries;
{$ENDIF}
{$mode objfpc}
interface
const
  {$IFDEF LINUX}
  libX11 = 'libX11.so.6';
  libXext = 'libXext.so.6';
  libXft = 'libXft.so.2';
  libXrender = 'libXrender.so.1';
  {$ELSE}
  libX11 = 'X11';
  libXext = 'Xext';
  libXrender = 'Xrender';
    {$IFDEF DARWIN}
  libXft = 'libXft.dylib';
    {$ELSE}
  libXft = 'libXft.so';
    {$ENDIF}
  {$ENDIF}
implementation
end.
