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
    CStreams,entfile,nxartifactid;

  const
    { Nexus-owned revision within the NXP family. }
    CurrentPCPVersion=4;

    { unit flags }
    pf_big_endian          = $000004;
    //uf_in_library          = $000020; { is the file in another file than <ppufile>.* ? }
    //uf_smart_linked        = $000040; { the ppu can be smartlinked }
    //uf_static_linked       = $000080; { the ppu can be linked static }
    //uf_shared_linked       = $000100; { the ppu can be linked shared }
    //uf_no_link             = $000400; { unit has no .o generated, but can still have external linking! }
    pf_little_endian       = $001000;


  type
    TPCPHeader=record
      common   : TEntryHeader;
      checksum : cardinal; { checksum for this pcpfile }
      requiredlistsize, { number of entries for required packages }
      ppulistsize : LongInt; { number of entries for contained PPUs }
    end;

    TPCPFile=class(TEntryFile)
    private
      headerread : boolean;
    public
      header : TPCPHeader;
      { crc for the entire package }
      crc : cardinal;
      do_crc : boolean;
    protected
      function getheadersize:LongInt;override;
      function getheaderaddr:PEntryHeader;override;
      procedure newheader;override;
      function readheader:LongInt;override;
      procedure resetfile;override;
      procedure RaiseAssertion(Code: LongInt); override;
    public
      procedure writeheader;override;
      function checkpcpid:boolean;
      function readpackageentry(expected:byte):boolean;
      function packageentrydone:boolean;
      function metadataend:LongInt;
      function metadatadone:boolean;
      procedure putdata(const b;len:integer);override;
    end;

implementation

uses
  FPCHash;

  { tpcpfile }

  function TPCPFile.getheadersize: LongInt;
    begin
      result:=sizeof(TPCPHeader);
    end;

  function TPCPFile.getheaderaddr: PEntryHeader;
    begin
      result:=@header;
    end;

  procedure TPCPFile.RaiseAssertion(Code: LongInt);
    begin
      // InternalError(nb);
      inherited RaiseAssertion(Code);
    end;

  procedure TPCPFile.newheader;
    var
      s : string;
    begin
      fillchar(header,sizeof(TPCPHeader),0);
      str(CurrentPCPVersion,s);
      while length(s)<3 do
        s:='0'+s;
      with header.common do
        begin
          id[1]:=NexusPCPSignature[1];
          id[2]:=NexusPCPSignature[2];
          id[3]:=NexusPCPSignature[3];
          ver[1]:=s[1];
          ver[2]:=s[2];
          ver[3]:=s[3];
        end;
    end;

  function TPCPFile.readheader: LongInt;
    begin
      headerread:=false;
      crc:=0;
      if fsize<sizeof(TPCPHeader) then
        exit(0);
      result:=f.Read(header,sizeof(TPCPHeader));
      if result<>sizeof(TPCPHeader) then
        exit;
      headerread:=true;
      { The header is always stored in little endian order }
      { therefore swap if on a big endian machine          }
    {$IFDEF ENDIAN_BIG}
      header.common.compiler := swapendian(header.common.compiler);
      header.common.cpu := swapendian(header.common.cpu);
      header.common.target := swapendian(header.common.target);
      header.common.flags := swapendian(header.common.flags);
      header.common.size := swapendian(header.common.size);
      header.checksum := swapendian(header.checksum);
      header.requiredlistsize:=swapendian(header.requiredlistsize);
      header.ppulistsize:=swapendian(header.ppulistsize);
    {$ENDIF}
      { the PPU DATA is stored in native order }
      if (header.common.flags and pf_big_endian) = pf_big_endian then
       Begin
    {$IFDEF ENDIAN_LITTLE}
         change_endian := TRUE;
    {$ELSE}
         change_endian := FALSE;
    {$ENDIF}
       End
      else if (header.common.flags and pf_little_endian) = pf_little_endian then
       Begin
    {$IFDEF ENDIAN_BIG}
         change_endian := TRUE;
    {$ELSE}
         change_endian := FALSE;
    {$ENDIF}
       End;
    end;

  procedure TPCPFile.resetfile;
    begin
      crc:=0;
      do_crc:=true;
    end;


  procedure TPCPFile.writeheader;
    var
      opos : integer;
    begin
      { flush buffer }
      writebuf;
      { update size (w/o header!) in the header }
      header.common.size:=BufStart-sizeof(TPCPHeader);
      { set the endian flag }
{$ifndef FPC_BIG_ENDIAN}
      header.common.flags:=header.common.flags or pf_little_endian;
{$else not FPC_BIG_ENDIAN}
      header.common.flags:=header.common.flags or pf_big_endian;
      { Now swap the header in the correct endian (always little endian) }
      header.common.compiler:=swapendian(header.common.compiler);
      header.common.cpu:=swapendian(header.common.cpu);
      header.common.target:=swapendian(header.common.target);
      header.common.flags:=swapendian(header.common.flags);
      header.common.size:=swapendian(header.common.size);
      header.checksum:=swapendian(header.checksum);
      header.requiredlistsize:=swapendian(header.requiredlistsize);
      header.ppulistsize:=swapendian(header.ppulistsize);
{$endif not FPC_BIG_ENDIAN}
    { write header and restore filepos after it }
      opos:=f.Position;
      f.Position:=0;
      f.Write(header,sizeof(TPCPHeader));
      f.Position:=opos;
  end;


  function TPCPFile.checkpcpid:boolean;
    begin
      result:=headerread and
               (header.common.size<=dword(fsize-sizeof(TPCPHeader))) and
               (header.requiredlistsize>=0) and (header.ppulistsize>=0) and
               (((header.common.flags and (pf_big_endian or pf_little_endian))=pf_big_endian) or
                ((header.common.flags and (pf_big_endian or pf_little_endian))=pf_little_endian)) and
               ((Header.common.Id[1]=NexusPCPSignature[1]) and
                (Header.common.Id[2]=NexusPCPSignature[2]) and
                (Header.common.Id[3]=NexusPCPSignature[3]));
    end;


  function TPCPFile.metadataend:LongInt;
    begin
      { Version 3 stores the metadata size, excluding embedded PPU data. }
      result:=sizeof(TPCPHeader)+LongInt(header.common.size);
    end;


  function TPCPFile.packageentrydone:boolean;
    begin
      result:=not error and (entryleft=0);
    end;


  function TPCPFile.readpackageentry(expected:byte):boolean;
    var
      savedpos,left,count : LongInt;
      buffer : array[0..4095] of byte;
    begin
      result:=false;
      { Do not allow readentry to skip unread fields or read a partial header.
        Keep these stricter checks local to PCP consumers. }
      if not packageentrydone or
         (BufferedPosition>metadataend-sizeof(TEntry)) then
        exit;
      if (readentry<>expected) or (entry.id<>mainentryid) or
         (entry.size<0) or (entry.size>metadataend-BufferedPosition) then
        exit;
      { The existing checksum covers metadata payloads, not entry headers,
        the PPU offset table, or embedded PPUs. Preserve that definition. }
      if not (expected in [ibpputable,ibend]) then
        begin
          savedpos:=f.Position;
          try
            f.Position:=BufferedPosition;
            left:=entry.size;
            while left>0 do
              begin
                count:=left;
                if count>sizeof(buffer) then
                  count:=sizeof(buffer);
                if f.Read(buffer,count)<>count then
                  exit;
                crc:=UpdateCRC32(crc,buffer,count);
                dec(left,count);
              end;
          finally
            f.Position:=savedpos;
          end;
        end;
      result:=true;
    end;


  function TPCPFile.metadatadone:boolean;
    begin
      result:=packageentrydone and (entry.nr=ibend) and
        (BufferedPosition=metadataend) and (crc=header.checksum);
    end;


  procedure TPCPFile.putdata(const b;len:integer);
    begin
      if do_crc then
        begin
          crc:=UpdateCRC32(crc,b,len);
        end;
      inherited putdata(b, len);
    end;


end.

