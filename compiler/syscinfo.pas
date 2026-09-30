{
    Copyright (c) 2016 by Karoly Balogh

    Contains information on syscalls

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

 ****************************************************************************
}
unit syscinfo;

{$i fpcdefs.inc}

interface

uses
  systems, tokens, symconst;

type
  tsyscallinfo = record
    token: ttoken;
    procoption: tprocoption;
    validon: set of TSystem;
  end;
  psyscallinfo = ^tsyscallinfo;

const
  syscall_conventions: array[1..1] of tsyscallinfo = (
      ( token: NOTOKEN;    procoption: po_syscall;           validon: [] ));

function get_syscall_by_token(const token: ttoken): psyscallinfo;
function get_syscall_by_name(const name: string): psyscallinfo;
function get_default_syscall: tprocoption;
procedure set_default_syscall(sc: tprocoption);

implementation

uses
  verbose;

const
  syscall_conventions_po = [ po_syscall, po_syscall_legacy, po_syscall_basenone,
                             po_syscall_baselast, po_syscall_basefirst, po_syscall_basereg ];

var
  default_syscall_convention: tprocoption = po_none;

function get_syscall_by_token(const token: ttoken): psyscallinfo;
var
  i: longint;
begin
  result:=nil;
  for i:=low(syscall_conventions) to high(syscall_conventions) do
    if syscall_conventions[i].token = token then
      begin
        result:=@syscall_conventions[i];
        break;
      end;
end;

function get_syscall_by_name(const name: string): psyscallinfo;
var
  i: longint;
begin
  result:=nil;
  for i:=low(syscall_conventions) to high(syscall_conventions) do
    if arraytokeninfo[syscall_conventions[i].token].str = name then
      begin
        result:=@syscall_conventions[i];
        break;
      end;
end;

function get_default_syscall: tprocoption;
begin
  if not (default_syscall_convention in syscall_conventions_po) then
    internalerror(2016090302);

  result:=default_syscall_convention;
end;

procedure set_default_syscall(sc: tprocoption);
begin
  if not (sc in syscall_conventions_po) then
    internalerror(2016090301);

  default_syscall_convention:=sc;
end;

end.
