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
    GlobType,ConstExp,entfile,nxartifactid;

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
  CurrentPPULongVersion = 39;

{ unit flags }
  uf_big_endian          = $000004;
  uf_in_library          = $000020; { is the file in another file than <ppufile>.* ? }
  uf_smart_linked        = $000040; { the ppu can be smartlinked }
  uf_static_linked       = $000080; { the ppu can be linked static }
  uf_shared_linked       = $000100; { the ppu can be linked shared }
  uf_lto_linked          = $000200; { the ppu can be used with LTO }
  uf_no_link             = $000400; { unit has no .o generated, but can still have external linking! }
  uf_little_endian       = $001000;

type
  { set type aliases. We cast all sets to a corresponding array type so
    that if the set changes size, compilation will fail and we know that
    we have have to increase the ppu version }
  TPPUSet1 = array[0..0] of byte;
  TPPUSet2 = array[0..1] of byte;
  { tppuset3 = array[0..2] of byte; (sets of 3 bytes are rounded up to 4 bytes) }
  TPPUSet4 = array[0..3] of byte;
  TPPUSet5 = array[0..4] of byte;
  TPPUSet6 = array[0..5] of byte;
  TPPUSet7 = array[0..6] of byte;
  TPPUSet8 = array[0..7] of byte;
  TPPUSet9 = array[0..8] of byte;
  TPPUSet10 = array[0..9] of byte;
  TPPUSet11 = array[0..10] of byte;
  TPPUSet12 = array[0..11] of byte;
  TPPUSet13 = array[0..12] of byte;
  TPPUSet14 = array[0..13] of byte;
  TPPUSet15 = array[0..14] of byte;
  TPPUSet16 = array[0..15] of byte;
  TPPUSet17 = array[0..16] of byte;
  TPPUSet18 = array[0..17] of byte;
  TPPUSet19 = array[0..18] of byte;
  TPPUSet20 = array[0..19] of byte;
  TPPUSet21 = array[0..20] of byte;
  TPPUSet22 = array[0..21] of byte;
  TPPUSet23 = array[0..22] of byte;
  TPPUSet24 = array[0..23] of byte;
  TPPUSet25 = array[0..24] of byte;
  TPPUSet26 = array[0..25] of byte;
  TPPUSet27 = array[0..26] of byte;
  TPPUSet28 = array[0..27] of byte;
  TPPUSet29 = array[0..28] of byte;
  TPPUSet30 = array[0..29] of byte;
  TPPUSet31 = array[0..30] of byte;
  TPPUSet32 = array[0..31] of byte;

  TPPUError=(ppuentrytoobig,ppuentryerror);

  TPPUHeader=record
    common   : TEntryHeader;
    checksum : cardinal; { checksum for this ppufile }
    interface_checksum : cardinal;
    deflistsize,
    symlistsize : LongInt;
    indirect_checksum: cardinal;
  end;

  TPPUEntry=TEntry;

  TUnitAsmListType=(ualt_public,ualt_extern);

  TPPUFile=class(TEntryFile)
  protected
    procedure newheader;override;
    function readheader: LongInt;override;
    function outputallowed: boolean;override;
    function getheadersize:LongInt;override;
    function getheaderaddr:PEntryHeader;override;
    procedure resetfile;override;
{$ifdef DEBUG_PPU}
    procedure ppu_log(st :string);override;
{$endif}
{$ifdef DEBUG_GENERATE_INTERFACE_PPU}
  public
    writing_interface_ppu : boolean;
{$endif DEBUG_GENERATE_INTERFACE_PPU}
  public
    header           : TPPUHeader;
    { crc for the entire unit }
    crc,
    { crc for the interface definitions in this unit }
    interface_crc,
    { crc of all object/class definitions in the interface of this unit, xor'ed
      by the crc's of all object/class definitions in the interfaces of units
      used by this unit. Reason: see mantis #13840 }
    indirect_crc     : cardinal;
    do_crc,
    do_interface_crc,
    do_indirect_crc  : boolean;
    crc_only         : boolean;    { used to calculate interface_crc before implementation }
    function  CheckPPUId:boolean;
    procedure putdata(const b;len:integer);override;
    procedure putdata(b : TByteDynArray);
    procedure putdata(b : TAnsiCharDynArray);
    constructor Create(const fn:string);
    destructor Destroy;override;
  {read}
  { nothing special currently }
  {write}
    function  createfile:boolean;override;
    procedure writeheader;override;
  end;

implementation

  uses
    CompHook,
    Globals,
    FPCHash;


{*****************************************************************************
                                  TPPUFile
*****************************************************************************}

constructor TPPUFile.Create(const fn:string);
begin
  inherited Create(fn);
  crc_only:=false;
{$ifdef DEBUG_GENERATE_INTERFACE_PPU}
  writing_interface_ppu:=false;
{$endif}
end;

destructor TPPUFile.Destroy;
begin
  inherited Destroy;
end;

function TPPUFile.CheckPPUId:boolean;
begin
  CheckPPUId:=((Header.common.Id[1]=NexusPPUSignature[1]) and
                (Header.common.Id[2]=NexusPPUSignature[2]) and
                (Header.common.Id[3]=NexusPPUSignature[3]));
end;


procedure TPPUFile.newheader;
var
  s : string;
begin
  fillchar(header,sizeof(TPPUHeader),0);
  str(currentppuversion,s);
  while length(s)<3 do
   s:='0'+s;
  with header.common do
   begin
     Id[1]:=NexusPPUSignature[1];
     Id[2]:=NexusPPUSignature[2];
     Id[3]:=NexusPPUSignature[3];
     Ver[1]:=s[1];
     Ver[2]:=s[2];
     Ver[3]:=s[3];
   end;
end;


function TPPUFile.readheader: LongInt;
var
  is_valid : boolean;
begin
  is_valid:=true;
  result:=fsize;
  if result<sizeof(TPPUHeader) then
    is_valid:=false;
  result:=f.Read(header,sizeof(TPPUHeader));
  if (result<>sizeof(TPPUHeader)) then
    is_valid:=false;
  if not is_valid then
    begin
      fillchar(header,sizeof(TPPUHeader),#0);
      Do_Comment(VError,' Invalid header size '+ToStr(result)+' (expecting '+ToStr(sizeof(TPPUHeader))+')');
      exit(-1);
    end;
  { The header is always stored in little endian order }
  { therefore swap if on a big endian machine          }
{$IFDEF ENDIAN_BIG}
  header.common.compiler := swapendian(header.common.compiler);
  header.common.cpu := swapendian(header.common.cpu);
  header.common.target := swapendian(header.common.target);
  header.common.flags := swapendian(header.common.flags);
  header.common.size := swapendian(header.common.size);
  header.checksum := swapendian(header.checksum);
  header.interface_checksum := swapendian(header.interface_checksum);
  header.indirect_checksum := swapendian(header.indirect_checksum);
  header.deflistsize:=swapendian(header.deflistsize);
  header.symlistsize:=swapendian(header.symlistsize);

  { the PPU DATA is stored in native order }
  change_endian := (header.common.flags and uf_little_endian) = uf_little_endian;
{$ELSE not ENDIAN_BIG}
  change_endian := (header.common.flags and uf_big_endian) = uf_big_endian;
{$ENDIF}
end;

function TPPUFile.outputallowed: boolean;
begin
  result:=not crc_only;
end;

{$ifdef DEBUG_PPU}
procedure TPPUFile.ppu_log(st :string);
begin
  inherited ppu_log(st);
  if flog_open then
    begin
      if do_crc and (ppu_log_idx < BufferedPosition) then
        begin
          write(flog,'New crc : ',HexStr(dword(crc),8));
          WriteLn(flog);
          write(flog,'New interface crc : ',HexStr(dword(interface_crc),8));
          WriteLn(flog);
          write(flog,'New indirect crc : ',HexStr(dword(indirect_crc),8));
          WriteLn(flog);
         end;
    end;
{$ifdef IN_PPUDUMP}
  if update_crc then
    begin
      WriteLn('New crc : ',HexStr(dword(crc),8));
      WriteLn('New interface crc : ',HexStr(dword(interface_crc),8));
      WriteLn('New indirect crc : ',HexStr(dword(indirect_crc),8));
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

function TPPUFile.createfile:boolean;
begin
{$ifdef DEBUG_GENERATE_INTERFACE_PPU}
  if crc_only then
    begin
      fname:=fname+'.intf';
      crc_only:=false;
      writing_interface_ppu:=true;
    end;
{$endif}
  result:=inherited createfile;
end;


procedure TPPUFile.writeheader;
var
  opos : integer;
begin
  if crc_only then
   exit;
  { flush buffer }
  writebuf;
  { update size (w/o header!) in the header }
  header.common.size:=BufStart-sizeof(TPPUHeader);
  { set the endian flag }
{$ifndef FPC_BIG_ENDIAN}
    header.common.flags := header.common.flags or uf_little_endian;
{$else not FPC_BIG_ENDIAN}
    header.common.flags := header.common.flags or uf_big_endian;
    { Now swap the header.common in the correct endian (always little endian) }
    header.common.compiler := swapendian(header.common.compiler);
    header.common.cpu := swapendian(header.common.cpu);
    header.common.target := swapendian(header.common.target);
    header.common.flags := swapendian(header.common.flags);
    header.common.size := swapendian(header.common.size);
    header.checksum := swapendian(header.checksum);
    header.interface_checksum := swapendian(header.interface_checksum);
    header.indirect_checksum := swapendian(header.indirect_checksum);
    header.deflistsize:=swapendian(header.deflistsize);
    header.symlistsize:=swapendian(header.symlistsize);
{$endif not FPC_BIG_ENDIAN}
{ write header and restore filepos after it }
  opos:=f.Position;
  f.Position:=0;
  f.Write(header,sizeof(TPPUHeader));
  f.Position:=opos;
end;


procedure TPPUFile.putdata(const b;len:integer);
begin
  if do_crc then
   begin
     crc:=UpdateCRC32(crc,b,len);
     if do_interface_crc then
       begin
         interface_crc:=UpdateCRC32(interface_crc,b,len);
         { indirect crc must only be calculated for the interface; changes
           to a class in the implementation cannot require another unit to
           be recompiled }
         if do_indirect_crc then
           begin
             indirect_crc:=UpdateCRC32(indirect_crc,b,len);
           end;
       end;
    end;
  inherited putdata(b,len);
  (*if not crc_only then
    writedata(b,len);
  inc(entryidx,len);*)
end;

procedure TPPUFile.putdata(b: TByteDynArray);
begin
  putdata(b[0],length(b));
end;

procedure TPPUFile.putdata(b: TAnsiCharDynArray);
begin
  putdata(b[0],length(b));
end;

function TPPUFile.getheadersize: LongInt;
begin
  result:=sizeof(header);
end;

function TPPUFile.getheaderaddr: PEntryHeader;
begin
  result:=@header;
end;

procedure TPPUFile.resetfile;
begin
  crc:=0;
  interface_crc:=0;
  indirect_crc:=0;
  do_interface_crc:=true;
  do_indirect_crc:=false;
  do_crc:=true;
end;


end.
