{
    Copyright (c) 2013-2016 by Free Pascal development team

    Routines to read/write pcp files

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
unit pcp;

{$i fpcdefs.inc}

{$H+}

interface

  uses
    CStreams,EntFile,NXArtifactID;

  const
    { Nexus-owned revision within the NXP family. }
    CurrentPCPVersion=4;

    { unit flags }
    PfEndianMask         = $001004; { Includes the retired byte-order flag. }
    //uf_in_library          = $000020; { is the file in another file than <ppufile>.* ? }
    //uf_smart_linked        = $000040; { the ppu can be smartlinked }
    //uf_static_linked       = $000080; { the ppu can be linked static }
    //uf_shared_linked       = $000100; { the ppu can be linked shared }
    //uf_no_link             = $000400; { unit has no .o generated, but can still have external linking! }
    PfLittleEndian       = $001000;


  type
    TPCPHeader=record
      Common   : TEntryHeader;
      Checksum : Cardinal; { checksum for this pcpfile }
      RequiredListSize, { number of entries for required packages }
      PPUListSize : LongInt; { number of entries for contained PPUs }
    end;

    TPCPFile=class(TEntryFile)
    private
      HeaderRead : Boolean;
    public
      Header : TPCPHeader;
      { crc for the entire package }
      CRC : Cardinal;
      DoCRC : Boolean;
    protected
      function GetHeaderSize:LongInt;override;
      function GetHeaderAddr:PEntryHeader;override;
      procedure NewHeader;override;
      function ReadHeader:LongInt;override;
      procedure ResetFile;override;
      procedure RaiseAssertion(Code: LongInt); override;
    public
      procedure WriteHeader;override;
      function CheckPCPID:Boolean;
      function ReadPackageEntry(Expected:Byte):Boolean;
      function PackageEntryDone:Boolean;
      function MetadataEnd:LongInt;
      function MetadataDone:Boolean;
      procedure PutData(const B;Len:Integer);override;
    end;

implementation

uses
  CRC32;

  { tpcpfile }

  function TPCPFile.GetHeaderSize: LongInt;
    begin
      Result:=SizeOf(TPCPHeader);
    end;

  function TPCPFile.GetHeaderAddr: PEntryHeader;
    begin
      Result:=@Header;
    end;

  procedure TPCPFile.RaiseAssertion(Code: LongInt);
    begin
      // InternalError(nb);
      inherited RaiseAssertion(Code);
    end;

  procedure TPCPFile.NewHeader;
    var
      S : string;
    begin
      FillChar(Header,SizeOf(TPCPHeader),0);
      Str(CurrentPCPVersion,S);
      while Length(S)<3 do
        S:='0'+S;
      with Header.Common do
        begin
          ID[1]:=NexusPCPSignature[1];
          ID[2]:=NexusPCPSignature[2];
          ID[3]:=NexusPCPSignature[3];
          Ver[1]:=S[1];
          Ver[2]:=S[2];
          Ver[3]:=S[3];
        end;
    end;

  function TPCPFile.ReadHeader: LongInt;
    begin
      HeaderRead:=False;
      CRC:=0;
      if FSize<SizeOf(TPCPHeader) then
        Exit(0);
      Result:=F.Read(Header,SizeOf(TPCPHeader));
      if Result<>SizeOf(TPCPHeader) then
        Exit;
      HeaderRead:=True;
    end;

  procedure TPCPFile.ResetFile;
    begin
      CRC:=0;
      DoCRC:=True;
    end;


  procedure TPCPFile.WriteHeader;
    var
      OPos : Integer;
    begin
      { flush buffer }
      WriteBuf;
      { update size (w/o header!) in the header }
      Header.Common.Size:=BufStart-SizeOf(TPCPHeader);
      { set the endian flag }
      Header.Common.Flags:=Header.Common.Flags or PfLittleEndian;
    { write header and restore filepos after it }
      OPos:=F.Position;
      F.Position:=0;
      F.Write(Header,SizeOf(TPCPHeader));
      F.Position:=OPos;
  end;


  function TPCPFile.CheckPCPID:Boolean;
    begin
      Result:=HeaderRead and
               (Header.Common.Size<=DWORD(FSize-SizeOf(TPCPHeader))) and
               (Header.RequiredListSize>=0) and (Header.PPUListSize>=0) and
               ((Header.Common.Flags and PfEndianMask)=PfLittleEndian) and
               ((Header.Common.ID[1]=NexusPCPSignature[1]) and
                (Header.Common.ID[2]=NexusPCPSignature[2]) and
                (Header.Common.ID[3]=NexusPCPSignature[3]));
    end;


  function TPCPFile.MetadataEnd:LongInt;
    begin
      { Version 3 stores the metadata size, excluding embedded PPU data. }
      Result:=SizeOf(TPCPHeader)+LongInt(Header.Common.Size);
    end;


  function TPCPFile.PackageEntryDone:Boolean;
    begin
      Result:=not Error and (EntryLeft=0);
    end;


  function TPCPFile.ReadPackageEntry(Expected:Byte):Boolean;
    var
      SavedPos,Left,Count : LongInt;
      Buffer : array[0..4095] of Byte;
    begin
      Result:=False;
      { Do not allow readentry to skip unread fields or read a partial header.
        Keep these stricter checks local to PCP consumers. }
      if not PackageEntryDone or
         (BufferedPosition>MetadataEnd-SizeOf(TEntry)) then
        Exit;
      if (ReadEntry<>Expected) or (Entry.ID<>MainEntryID) or
         (Entry.Size<0) or (Entry.Size>MetadataEnd-BufferedPosition) then
        Exit;
      { The existing checksum covers metadata payloads, not entry headers,
        the PPU offset table, or embedded PPUs. Preserve that definition. }
      if not (Expected in [IBPPUTable,IBEnd]) then
        begin
          SavedPos:=F.Position;
          try
            F.Position:=BufferedPosition;
            Left:=Entry.Size;
            while Left>0 do
              begin
                Count:=Left;
                if Count>SizeOf(Buffer) then
                  Count:=SizeOf(Buffer);
                if F.Read(Buffer,Count)<>Count then
                  Exit;
                CRC:=UpdateCRC32(CRC,Buffer,Count);
                Dec(Left,Count);
              end;
          finally
            F.Position:=SavedPos;
          end;
        end;
      Result:=True;
    end;


  function TPCPFile.MetadataDone:Boolean;
    begin
      Result:=PackageEntryDone and (Entry.NR=IBEnd) and
        (BufferedPosition=MetadataEnd) and (CRC=Header.Checksum);
    end;


  procedure TPCPFile.PutData(const B;Len:Integer);
    begin
      if DoCRC then
        begin
          CRC:=UpdateCRC32(CRC,B,Len);
        end;
      inherited PutData(B, Len);
    end;


end.

