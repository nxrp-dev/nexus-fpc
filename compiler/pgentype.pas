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
  cInlineSpecializationBlockTypes = [bt_type,bt_var_type,bt_const_type,bt_body,bt_except];

type
  PSpecializationState = ^TSpecializationState;
  TSpecializationState = record
    OldSymTableStack      : TSymTableStack;
    OldExtendedDefs       : TFPHashObjectList;
    OldGenericDummySyms   : TFPHashObjectList;
    OldSpecializeState    : PSpecializationState;
    OldCurrentGenericDef : TDef;
    OldOpToken            : TToken;
  end;

  TSpecializationContext=class
  public
    FParamList : TFPObjectList;
    FPosList : TFPList;
    FPrettyName : AnsiString;
    FSpecializeName : AnsiString;
    FGenName : AnsiString;
    FSym : TSym;
    FSymTable : TSymTable;
    FForwardDef : TDef;
    constructor Create;
    destructor Destroy;override;
    function GetCopy:TSpecializationContext;
  end;


implementation

constructor TSpecializationContext.Create;
begin
  FParamList:=TFPObjectList.Create(false);
  FPosList:=TFPList.Create;
end;

destructor TSpecializationContext.Destroy;
begin
  FParamList.free;
  FParamList := nil;
  TFPList.FreeAndNilDisposing(FPosList,TypeInfo(TFilePosInfo));
  inherited Destroy;
end;

function TSpecializationContext.GetCopy:TSpecializationContext;
var
  lPosInfo : PFilePosInfo;
  lIndex : LongInt;
begin
  Result:=TSpecializationContext.Create;
  Result.FParamList.capacity:=FParamList.count;
  for lIndex:=0 to FParamList.count-1 do
    begin
      Result.FParamList.add(FParamList[lIndex]);
    end;
  Result.FPosList.capacity:=FPosList.count;
  for lIndex:=0 to FPosList.count-1 do
    begin
      new(lPosInfo);
      lPosInfo^:=PFilePosInfo(FPosList[lIndex])^;
      Result.FPosList.add(lPosInfo);
    end;
  Result.FPrettyName:=FPrettyName;
  Result.FSpecializeName:=FSpecializeName;
  Result.FGenName:=FGenName;
  Result.FSym:=FSym;
  Result.FSymTable:=FSymTable;
  Result.FForwardDef:=FForwardDef;
end;

end.

