{
    Copyright (c) 2015 by Sven Barth

    Contains different types that are used in the context of parsing generics.

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
unit pgentype;

{$i fpcdefs.inc}

interface

uses
  CClasses,
  tokens,
  GlobType,
  symtype,SymBase;

const
  inline_specialization_block_types = [bt_type,bt_var_type,bt_const_type,bt_body,bt_except];

type
  PSpecializationState = ^TSpecializationState;
  TSpecializationState = record
    OldSymTableStack      : TSymTableStack;
    oldextendeddefs       : TFPHashObjectList;
    oldgenericdummysyms   : TFPHashObjectList;
    oldspecializestate    : PSpecializationState;
    oldcurrent_genericdef : TDef;
    oldoptoken            : TToken;
  end;

  TSpecializationContext=class
  public
    paramlist : TFPObjectList;
    poslist : TFPList;
    prettyname : AnsiString;
    specializename : AnsiString;
    genname : AnsiString;
    sym : TSym;
    SymTable : TSymTable;
    forwarddef : TDef;
    constructor create;
    destructor Destroy;override;
    function getcopy:TSpecializationContext;
  end;


implementation

constructor TSpecializationContext.create;
begin
  paramlist:=TFPObjectList.create(false);
  poslist:=TFPList.create;
end;

destructor TSpecializationContext.Destroy;
begin
  paramlist.free;
  paramlist := nil;
  TFPList.FreeAndNilDisposing(poslist,TypeInfo(TFilePosInfo));
  inherited Destroy;
end;

function TSpecializationContext.getcopy:TSpecializationContext;
var
  posinfo : PFilePosInfo;
  i : LongInt;
begin
  result:=TSpecializationContext.create;
  result.paramlist.capacity:=paramlist.count;
  for i:=0 to paramlist.count-1 do
    begin
      result.paramlist.add(paramlist[i]);
    end;
  result.poslist.capacity:=poslist.count;
  for i:=0 to poslist.count-1 do
    begin
      new(posinfo);
      posinfo^:=PFilePosInfo(poslist[i])^;
      result.poslist.add(posinfo);
    end;
  result.prettyname:=prettyname;
  result.specializename:=specializename;
  result.genname:=genname;
  result.sym:=sym;
  result.SymTable:=SymTable;
  result.forwarddef:=forwarddef;
end;

end.

