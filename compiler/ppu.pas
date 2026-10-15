{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Routines to read/write ppu files

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
unit ppu;

{$i fpcdefs.inc}

interface

  uses
    GlobType,ConstExp,EntFile,NXArtifactID;

{ Also write the ppu if only crc if done, this can be used with ppudump to
  see the differences between the intf and implementation }
{ define DEBUG_GENERATE_INTERFACE_PPU}


const
  { These revisions belong to the NXU family, independently of upstream FPC.
    Also advance the long revision for incompatible compiler/RTL ABI changes. }
  { only update this version if something change in the tppuheader:
     * the unit flags listed below
     * the format of the header itself
    This number cannot become bigger than 255 (it's stored in a byte) }
  CurrentPPUVersion = 208;
  { for any other changes to the ppu format, increase this version number
    (it's a cardinal) }
  CurrentPPULongVersion = 41;

{ unit flags }
  UfBigEndian          = $000004;
  UfInLibrary          = $000020; { is the file in another file than <ppufile>.* ? }
  UfSmartLinked        = $000040; { the ppu can be smartlinked }
  UfStaticLinked       = $000080; { the ppu can be linked static }
  UfSharedLinked       = $000100; { the ppu can be linked shared }
  UfLTOLinked          = $000200; { the ppu can be used with LTO }
  UfNoLink             = $000400; { unit has no .o generated, but can still have external linking! }
  UfLittleEndian       = $001000;

type
  { set type aliases. We cast all sets to a corresponding array type so
    that if the set changes size, compilation will fail and we know that
    we have have to increase the ppu version }
  TPPUSet1 = array[0..0] of Byte;
  TPPUSet2 = array[0..1] of Byte;
  { tppuset3 = array[0..2] of byte; (sets of 3 bytes are rounded up to 4 bytes) }
  TPPUSet4 = array[0..3] of Byte;
  TPPUSet5 = array[0..4] of Byte;
  TPPUSet6 = array[0..5] of Byte;
  TPPUSet7 = array[0..6] of Byte;
  TPPUSet8 = array[0..7] of Byte;
  TPPUSet9 = array[0..8] of Byte;
  TPPUSet10 = array[0..9] of Byte;
  TPPUSet11 = array[0..10] of Byte;
  TPPUSet12 = array[0..11] of Byte;
  TPPUSet13 = array[0..12] of Byte;
  TPPUSet14 = array[0..13] of Byte;
  TPPUSet15 = array[0..14] of Byte;
  TPPUSet16 = array[0..15] of Byte;
  TPPUSet17 = array[0..16] of Byte;
  TPPUSet18 = array[0..17] of Byte;
  TPPUSet19 = array[0..18] of Byte;
  TPPUSet20 = array[0..19] of Byte;
  TPPUSet21 = array[0..20] of Byte;
  TPPUSet22 = array[0..21] of Byte;
  TPPUSet23 = array[0..22] of Byte;
  TPPUSet24 = array[0..23] of Byte;
  TPPUSet25 = array[0..24] of Byte;
  TPPUSet26 = array[0..25] of Byte;
  TPPUSet27 = array[0..26] of Byte;
  TPPUSet28 = array[0..27] of Byte;
  TPPUSet29 = array[0..28] of Byte;
  TPPUSet30 = array[0..29] of Byte;
  TPPUSet31 = array[0..30] of Byte;
  TPPUSet32 = array[0..31] of Byte;

  TPPUError=(ppuentrytoobig,ppuentryerror);

  TPPUHeader=record
    Common   : TEntryHeader;
    Checksum : Cardinal; { checksum for this ppufile }
    InterfaceChecksum : Cardinal;
    DefListSize,
    SymListSize : LongInt;
    IndirectChecksum: Cardinal;
  end;

  TPPUEntry=TEntry;

  TUnitAsmListType=(ualt_public,ualt_extern);

  TPPUFile=class(TEntryFile)
  protected
    procedure NewHeader;override;
    function ReadHeader: LongInt;override;
    function OutputAllowed: Boolean;override;
    function GetHeaderSize:LongInt;override;
    function GetHeaderAddr:PEntryHeader;override;
    procedure ResetFile;override;
{$ifdef DEBUG_PPU}
    procedure PPU_Log(ST :string);override;
{$endif}
{$ifdef DEBUG_GENERATE_INTERFACE_PPU}
  public
    WritingInterfacePPU : Boolean;
{$endif DEBUG_GENERATE_INTERFACE_PPU}
  public
    Header           : TPPUHeader;
    { crc for the entire unit }
    CRC,
    { crc for the interface definitions in this unit }
    InterfaceCRC,
    { crc of all object/class definitions in the interface of this unit, xor'ed
      by the crc's of all object/class definitions in the interfaces of units
      used by this unit. Reason: see mantis #13840 }
    IndirectCRC     : Cardinal;
    DoCRC,
    DoInterfaceCRC,
    DoIndirectCRC  : Boolean;
    CRCOnly         : Boolean;    { used to calculate interface_crc before implementation }
    function  CheckPPUId:Boolean;
    procedure PutData(const B;Len:Integer);override;
    procedure PutData(B : TByteDynArray);
    procedure PutData(B : TAnsiCharDynArray);
    constructor Create(const FN:string);
    destructor Destroy;override;
  {read}
  { nothing special currently }
  {write}
    function  CreateFile:Boolean;override;
    procedure WriteHeader;override;
  end;

implementation

  uses
    CompHook,
    Globals,
    FPCHash;


{*****************************************************************************
                                  TPPUFile
*****************************************************************************}

constructor TPPUFile.Create(const FN:string);
begin
  inherited Create(FN);
  CRCOnly:=False;
{$ifdef DEBUG_GENERATE_INTERFACE_PPU}
  WritingInterfacePPU:=False;
{$endif}
end;

destructor TPPUFile.Destroy;
begin
  inherited Destroy;
end;

function TPPUFile.CheckPPUId:Boolean;
begin
  CheckPPUId:=((Header.Common.ID[1]=NexusPPUSignature[1]) and
                (Header.Common.ID[2]=NexusPPUSignature[2]) and
                (Header.Common.ID[3]=NexusPPUSignature[3]));
end;


procedure TPPUFile.NewHeader;
var
  S : string;
begin
  FillChar(Header,SizeOf(TPPUHeader),0);
  Str(CurrentPPUVersion,S);
  while Length(S)<3 do
   S:='0'+S;
  with Header.Common do
   begin
     ID[1]:=NexusPPUSignature[1];
     ID[2]:=NexusPPUSignature[2];
     ID[3]:=NexusPPUSignature[3];
     Ver[1]:=S[1];
     Ver[2]:=S[2];
     Ver[3]:=S[3];
   end;
end;


function TPPUFile.ReadHeader: LongInt;
var
  IsValid : Boolean;
begin
  IsValid:=True;
  Result:=FSize;
  if Result<SizeOf(TPPUHeader) then
    IsValid:=False;
  Result:=F.Read(Header,SizeOf(TPPUHeader));
  if (Result<>SizeOf(TPPUHeader)) then
    IsValid:=False;
  if not IsValid then
    begin
      FillChar(Header,SizeOf(TPPUHeader),#0);
      Do_Comment(VError,' Invalid header size '+ToStr(Result)+' (expecting '+ToStr(SizeOf(TPPUHeader))+')');
      Exit(-1);
    end;
  { The header is always stored in little endian order }
  { therefore swap if on a big endian machine          }
{$IFDEF ENDIAN_BIG}
  Header.Common.Compiler := SwapEndian(Header.Common.Compiler);
  Header.Common.CPU := SwapEndian(Header.Common.CPU);
  Header.Common.Target := SwapEndian(Header.Common.Target);
  Header.Common.Flags := SwapEndian(Header.Common.Flags);
  Header.Common.Size := SwapEndian(Header.Common.Size);
  Header.Checksum := SwapEndian(Header.Checksum);
  Header.InterfaceChecksum := SwapEndian(Header.InterfaceChecksum);
  Header.IndirectChecksum := SwapEndian(Header.IndirectChecksum);
  Header.DefListSize:=SwapEndian(Header.DefListSize);
  Header.SymListSize:=SwapEndian(Header.SymListSize);

  { the PPU DATA is stored in native order }
  ChangeEndian := (Header.Common.Flags and UfLittleEndian) = UfLittleEndian;
{$ELSE not ENDIAN_BIG}
  ChangeEndian := (Header.Common.Flags and UfBigEndian) = UfBigEndian;
{$ENDIF}
end;

function TPPUFile.OutputAllowed: Boolean;
begin
  Result:=not CRCOnly;
end;

{$ifdef DEBUG_PPU}
procedure TPPUFile.PPU_Log(ST :string);
begin
  inherited PPU_Log(ST);
  if FLogOpen then
    begin
      if DoCRC and (PPULogIdx < BufferedPosition) then
        begin
          Write(FLog,'New crc : ',HexStr(DWord(CRC),8));
          WriteLn(FLog);
          Write(FLog,'New interface crc : ',HexStr(DWord(InterfaceCRC),8));
          WriteLn(FLog);
          Write(FLog,'New indirect crc : ',HexStr(DWord(IndirectCRC),8));
          WriteLn(FLog);
         end;
    end;
{$ifdef IN_PPUDUMP}
  if update_crc then
    begin
      WriteLn('New crc : ',HexStr(DWord(CRC),8));
      WriteLn('New interface crc : ',HexStr(DWord(InterfaceCRC),8));
      WriteLn('New indirect crc : ',HexStr(DWord(IndirectCRC),8));
    end;
{$endif}
end;
{$endif}

{*****************************************************************************
                                TPPUFile Reading
*****************************************************************************}

{ nothing special currently }

{*****************************************************************************
                                TPPUFile Writing
*****************************************************************************}

function TPPUFile.CreateFile:Boolean;
begin
{$ifdef DEBUG_GENERATE_INTERFACE_PPU}
  if CRCOnly then
    begin
      FName:=FName+'.intf';
      CRCOnly:=False;
      WritingInterfacePPU:=True;
    end;
{$endif}
  Result:=inherited CreateFile;
end;


procedure TPPUFile.WriteHeader;
var
  OPos : Integer;
begin
  if CRCOnly then
   Exit;
  { flush buffer }
  WriteBuf;
  { update size (w/o header!) in the header }
  Header.Common.Size:=BufStart-SizeOf(TPPUHeader);
  { set the endian flag }
{$ifndef FPC_BIG_ENDIAN}
    Header.Common.Flags := Header.Common.Flags or UfLittleEndian;
{$else not FPC_BIG_ENDIAN}
    Header.Common.Flags := Header.Common.Flags or UfBigEndian;
    { Now swap the header.common in the correct endian (always little endian) }
    Header.Common.Compiler := SwapEndian(Header.Common.Compiler);
    Header.Common.CPU := SwapEndian(Header.Common.CPU);
    Header.Common.Target := SwapEndian(Header.Common.Target);
    Header.Common.Flags := SwapEndian(Header.Common.Flags);
    Header.Common.Size := SwapEndian(Header.Common.Size);
    Header.Checksum := SwapEndian(Header.Checksum);
    Header.InterfaceChecksum := SwapEndian(Header.InterfaceChecksum);
    Header.IndirectChecksum := SwapEndian(Header.IndirectChecksum);
    Header.DefListSize:=SwapEndian(Header.DefListSize);
    Header.SymListSize:=SwapEndian(Header.SymListSize);
{$endif not FPC_BIG_ENDIAN}
{ write header and restore filepos after it }
  OPos:=F.Position;
  F.Position:=0;
  F.Write(Header,SizeOf(TPPUHeader));
  F.Position:=OPos;
end;


procedure TPPUFile.PutData(const B;Len:Integer);
begin
  if DoCRC then
   begin
     CRC:=UpdateCRC32(CRC,B,Len);
     if DoInterfaceCRC then
       begin
         InterfaceCRC:=UpdateCRC32(InterfaceCRC,B,Len);
         { indirect crc must only be calculated for the interface; changes
           to a class in the implementation cannot require another unit to
           be recompiled }
         if DoIndirectCRC then
           begin
             IndirectCRC:=UpdateCRC32(IndirectCRC,B,Len);
           end;
       end;
    end;
  inherited PutData(B,Len);
  (*if not crc_only then
    writedata(b,len);
  inc(entryidx,len);*)
end;

procedure TPPUFile.PutData(B: TByteDynArray);
begin
  PutData(B[0],Length(B));
end;

procedure TPPUFile.PutData(B: TAnsiCharDynArray);
begin
  PutData(B[0],Length(B));
end;

function TPPUFile.GetHeaderSize: LongInt;
begin
  Result:=SizeOf(Header);
end;

function TPPUFile.GetHeaderAddr: PEntryHeader;
begin
  Result:=@Header;
end;

procedure TPPUFile.ResetFile;
begin
  CRC:=0;
  InterfaceCRC:=0;
  IndirectCRC:=0;
  DoInterfaceCRC:=True;
  DoIndirectCRC:=False;
  DoCRC:=True;
end;


end.
