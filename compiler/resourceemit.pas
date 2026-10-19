(*
  Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit ResourceEmit;

{$i fpcdefs.inc}

interface

uses
  ResourceCatalog;

{ Emit the owning image's catalog through the compiler's existing assembly
  items. Target pointer widths come from GlobType, never the compiler host.
  Windows passes normalized RES directly to LLD instead of using this sink. }
procedure EmitCompilerResources(ACatalog: TResourceCatalog);

implementation

uses
  Classes, SysUtils, GlobType, Globals, Systems,
  AAsmBase, AAsmData, AAsmTai, SymDef, ResourceTables;

type
  TCompilerResourceSink = class(TResourceTableSink)
  private
    FList: TAsmList;
    FSymbols: TList; { Symbols belong to CurrentAsmData. }
    FInHandles: Boolean;
    FHandleSymbol: TAsmSymbol;
    function Symbol(ALabel: Integer): TAsmSymbol;
  public
    constructor Create;
    destructor Destroy; override;
    procedure BeginResources(APointerSize: Byte); override;
    procedure BeginHandles(APointerSize: Byte); override;
    procedure EmitLabel(ALabel: Integer); override;
    procedure EmitPointer(ALabel: Integer); override;
    procedure EmitOrdinal(AValue: Word); override;
    procedure EmitDWord(AValue: Cardinal); override;
    procedure EmitBytes(const AData; ACount: LongInt); override;
    procedure EmitAlignment(AAlignment: Byte); override;
    procedure EmitZeroFill(ASize: QWord); override;
    procedure Publish;
  end;

constructor TCompilerResourceSink.Create;
begin
  inherited Create;
  FList := TAsmList.Create;
  FSymbols := TList.Create;
end;

destructor TCompilerResourceSink.Destroy;
begin
  FSymbols.Free;
  FList.Free;
  inherited Destroy;
end;

function TCompilerResourceSink.Symbol(ALabel: Integer): TAsmSymbol;
begin
  while FSymbols.Count <= ALabel do FSymbols.Add(nil);
  Result := TAsmSymbol(FSymbols[ALabel]);
  if Result = nil then
  begin
    if ALabel = CResourceHeaderLabel then
      Result := CurrentAsmData.DefineAsmSymbol('FPC_RESSYMBOL', AB_GLOBAL,
        AT_DATA, VoidPointerType)
    else
      Result := CurrentAsmData.DefineAsmSymbol('FPC_RESOURCE_DATA_' +
        IntToStr(ALabel), AB_LOCAL, AT_DATA, VoidPointerType);
    FSymbols[ALabel] := Result;
  end;
end;

procedure TCompilerResourceSink.BeginResources(APointerSize: Byte);
var
  LSection: TAISection;
begin
  if TargetInfo.System in systems_darwin then
    new_section(FList, sec_user,
      '__DATA,fpc.resources,regular,no_dead_strip', APointerSize)
  else
  begin
    LSection := new_section(FList, sec_user, 'fpc.resources', APointerSize);
    LSection.SecFlags := [SF_A, SF_W];
    LSection.SecProgbits := SPB_PROGBITS;
  end;
end;

procedure TCompilerResourceSink.BeginHandles(APointerSize: Byte);
var
  LSection: TAISection;
begin
  FList.Concat(TAISymbolEnd.Create(Symbol(CResourceHeaderLabel)));
  FInHandles := True;
  if TargetInfo.System in systems_darwin then
    { The existing Darwin data-block writer emits local zero-fill storage. }
    new_section(FList, sec_bss, '', APointerSize)
  else
  begin
    LSection := new_section(FList, sec_user, 'fpc.reshandles', APointerSize);
    LSection.SecFlags := [SF_A, SF_W];
    LSection.SecProgbits := SPB_NOBITS;
  end;
end;

procedure TCompilerResourceSink.EmitLabel(ALabel: Integer);
begin
  if FInHandles then
    FHandleSymbol := Symbol(ALabel)
  else if ALabel = CResourceHeaderLabel then
    FList.Concat(TAISymbol.Create_global(Symbol(ALabel), 0))
  else
    FList.Concat(TAISymbol.Create(Symbol(ALabel), 0));
end;

procedure TCompilerResourceSink.EmitPointer(ALabel: Integer);
begin
  FList.Concat(TAIConst.Create_sym(Symbol(ALabel)));
end;

procedure TCompilerResourceSink.EmitOrdinal(AValue: Word);
begin
  FList.Concat(TAIConst.Create_int_dataptr(AValue));
end;

procedure TCompilerResourceSink.EmitDWord(AValue: Cardinal);
begin
  FList.Concat(TAIConst.Create(aitconst_32bit, Int64(AValue)));
end;

procedure TCompilerResourceSink.EmitBytes(const AData; ACount: LongInt);
begin
  if ACount <> 0 then
    FList.Concat(TAIString.Create_Data(PChar(@AData), ACount, False));
end;

procedure TCompilerResourceSink.EmitAlignment(AAlignment: Byte);
begin
  FList.Concat(CAIAlign.Create(AAlignment));
end;

procedure TCompilerResourceSink.EmitZeroFill(ASize: QWord);
begin
  if (not FInHandles) or (FHandleSymbol = nil) or
     (ASize = 0) or (ASize > QWord(High(ASizeInt))) then
    raise EResourceCatalog.Create('Invalid compiler resource handle storage');
  FList.Concat(TAIDataBlock.Create(FHandleSymbol.Name, ASizeInt(ASize),
    VoidPointerType, AT_DATA));
end;

procedure TCompilerResourceSink.Publish;
begin
  CurrentAsmData.AsmLists[al_resources].ConcatList(FList);
end;

procedure EmitCompilerResources(ACatalog: TResourceCatalog);
var
  LSink: TCompilerResourceSink;
begin
  if not (TargetInfo.System in (systems_linux + systems_android + systems_darwin)) then
    raise EResourceCatalog.Create('FPC resource tables require an ELF or Mach-O target');
  LSink := TCompilerResourceSink.Create;
  try
    EmitResourceTables(ACatalog, SizeOf(PInt), LSink);
    LSink.Publish;
  finally
    LSink.Free;
  end;
end;

end.
