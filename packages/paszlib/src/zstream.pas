{$IFNDEF FPC_DOTTEDUNITS}
unit ZStream;
{$ENDIF FPC_DOTTEDUNITS}

{**********************************************************************
    This file is part of the Free Pascal free component library.

    Copyright (c) 2007 by Daniel Mantione
      member of the Free Pascal development team

    Implements a Tstream descendents that allow you to read and write
    compressed data according to the Deflate algorithm described in
    RFC1951.

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

{ GZip specs: https://datatracker.ietf.org/doc/html/rfc1952 }

{$mode objfpc}

{***************************************************************************}
                                    interface
{***************************************************************************}

{$IFDEF FPC_DOTTEDUNITS}
uses    System.Classes,System.ZLib.Zbase,System.ZLib.Gzio;
{$ELSE FPC_DOTTEDUNITS}
uses    classes,zbase,gzio;
{$ENDIF FPC_DOTTEDUNITS}

type
        Tcompressionlevel=(
          clnone,                     {Do not use compression, just copy data.}
          clfastest,                  {Use fast (but less) compression.}
          cldefault,                  {Use default compression}
          clmax                       {Use maximum compression}
        );

        Tgzopenmode=(
          gzopenread,                 {Open file for reading.}
          gzopenwrite                 {Open file for writing.}
        );

        Tcustomzlibstream=class(Townerstream)
        protected
          Fstream:z_stream;
          Fbuffer:pointer;
          Fonprogress:Tnotifyevent;
          procedure progress(sender:Tobject);
          property onprogress:Tnotifyevent read Fonprogress write Fonprogress;
        public
          constructor create(stream:Tstream);
          destructor destroy;override;
        end;

        { Tcompressionstream }

        Tcompressionstream=class(Tcustomzlibstream)
        private
          procedure ClearOutBuffer;
        protected
          raw_written,compressed_written: int64;
        public
          constructor create(level:Tcompressionlevel;
                             dest:Tstream;
                             Askipheader:boolean=false);
          destructor destroy;override;
          function write(const buffer;count:longint):longint;override;
          procedure flush;
          function get_compressionrate:single;
          property OnProgress;
        end;

        Tdecompressionstream=class(Tcustomzlibstream)
        protected
          raw_read,compressed_read:int64;
          skipheader:boolean;
          procedure reset;
          function GetPosition() : Int64; override;
        public
          constructor create(Asource:Tstream;Askipheader:boolean=false);
          destructor destroy;override;
          function read(var buffer;count:longint):longint;override;
          function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;  override;
          function get_compressionrate:single;
          property OnProgress;
        end;

        TGZFileStream = Class(TStream)
        protected
          Fgzfile:gzfile;
          Ffilemode:Tgzopenmode;
        public
          constructor create(filename:ansistring;filemode:Tgzopenmode);
          function read(var buffer;count:longint):longint;override;
          function write(const buffer;count:longint):longint;override;
          function seek(offset:longint;origin:word):longint;override;
          destructor destroy;override;
        end;

        TGZipCompressionStream = class(TStream)
        private
          FLevel: TCompressionLevel;
          FCrc32Val: Longword;
          FUncompressedSize: Cardinal;
          FDest: TStream;
          FCompressionStream: TCompressionStream;
          procedure WriteHeader;
          procedure WriteFooter;
        public
          constructor Create(ADest: TStream); overload;
          constructor Create(ALevel: TCompressionLevel; ADest: TStream); overload;
          destructor Destroy; override;
          function Write(const Buffer; Count: Longint): Longint; override;
        end;

        TGZipDecompressionStream = class(TStream)
        private
          FCrc32Val: Longword;
          FUncompressedSize: Cardinal;
          FSource: TStream;
          FDecompressionStream: TDecompressionStream;
          procedure Assert(ACond: Boolean; AMsg: string = '');
          procedure ReadHeader;
          procedure ReadFooter;
        public
          constructor Create(ASource: TStream);
          destructor Destroy; override;
          function Read(var Buffer; Count: Longint): Longint; override;
          function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
        end;

        Ezliberror=class(Estreamerror)
        end;

        Egzfileerror=class(Ezliberror)
        end;

        Ecompressionerror=class(Ezliberror)
        end;

        Edecompressionerror=class(Ezliberror)
        end;

{***************************************************************************}
                                 implementation
{***************************************************************************}

{$IFDEF FPC_DOTTEDUNITS}
uses    System.ZLib.Zdeflate,System.ZLib.Zinflate,System.ZLib.InternalCRC32;
{$ELSE FPC_DOTTEDUNITS}
uses    zdeflate,zinflate,utNXPasZLibCRC32;
{$ENDIF FPC_DOTTEDUNITS}

const   bufsize=16384;     {Size of the buffer used for temporarily storing
                            data from the child stream.}

resourcestring Sgz_open_error='Could not open gzip compressed file %s.';
               Sgz_read_only='Gzip compressed file was opened for reading.';
               Sgz_write_only='Gzip compressed file was opened for writing.';
               Sgz_invalid_header='Invalid GZip header';
               Sgz_invalid_algorithm='Invalid compression algorithm';
               Sgz_invalid_crc32='Invalid crc32 checksum';
               Sgz_invalid_output_size='Invalid output size';
               Sseek_failed='Seek in deflate compressed stream failed.';

constructor Tcustomzlibstream.create(stream:Tstream);

begin
  assert(stream<>nil);
  inherited create(stream);
  getmem(Fbuffer,bufsize);
end;

procedure Tcustomzlibstream.progress(sender:Tobject);

begin
  if Fonprogress<>nil then
    Fonprogress(sender);
end;

destructor Tcustomzlibstream.destroy;

begin
  freemem(Fbuffer);
  inherited destroy;
end;

{***************************************************************************}

constructor Tcompressionstream.create(level:Tcompressionlevel;
                                      dest:Tstream;
                                      Askipheader:boolean=false);

var err,l:smallint;

begin
  inherited create(dest);
  Fstream.next_out:=Fbuffer;
  Fstream.avail_out:=bufsize;

  case level of
    clnone:
      l:=Z_NO_COMPRESSION;
    clfastest:
      l:=Z_BEST_SPEED;
    cldefault:
      l:=Z_DEFAULT_COMPRESSION;
    clmax:
      l:=Z_BEST_COMPRESSION;
  end;

  if Askipheader then
    err:=deflateInit2(Fstream,l,Z_DEFLATED,-MAX_WBITS,DEF_MEM_LEVEL,0)
  else
    err:=deflateInit(Fstream,l);
  if err<>Z_OK then
    raise Ecompressionerror.create(zerror(err));
end;

function Tcompressionstream.write(const buffer;count:longint):longint;

var err:smallint;
    lastavail:longint;

begin
  Fstream.next_in:=@buffer;
  Fstream.avail_in:=count;
  lastavail:=count;
  while Fstream.avail_in<>0 do
    begin
      if Fstream.avail_out=0 then
        ClearOutBuffer;
      inc(raw_written,lastavail-Fstream.avail_in);
      lastavail:=Fstream.avail_in;
      err:=deflate(Fstream,Z_NO_FLUSH);
      if err<>Z_OK then
        raise Ecompressionerror.create(zerror(err));
    end;
  inc(raw_written,lastavail-Fstream.avail_in);
  write:=count;
end;

function Tcompressionstream.get_compressionrate:single;

begin
  get_compressionrate:=100*compressed_written/raw_written;
end;

procedure TCompressionstream.ClearOutBuffer;

begin
  { Flush the buffer to the stream and update progress }
  source.writebuffer(Fbuffer^,bufsize-Fstream.avail_out);
  inc(compressed_written,bufsize-Fstream.avail_out);
  progress(self);
  { reset output buffer }
  Fstream.next_out:=Fbuffer;
  Fstream.avail_out:=bufsize;
end;

procedure Tcompressionstream.flush;

var err:smallint;

begin
  {Compress remaining data still in internal zlib data buffers.}
  repeat
    if Fstream.avail_out=0 then
      ClearOutBuffer;
    err:=deflate(Fstream,Z_FINISH);
    if err=Z_STREAM_END then
      break;
    if (err<>Z_OK) then
      raise Ecompressionerror.create(zerror(err));
  until false;
  if Fstream.avail_out<bufsize then
    ClearOutBuffer;
end;


destructor Tcompressionstream.destroy;

begin
  try
    Flush;
  finally
    deflateEnd(Fstream);
    inherited destroy;
  end;
end;

{***************************************************************************}

constructor Tdecompressionstream.create(Asource:Tstream;Askipheader:boolean=false);

var err:smallint;

begin
  inherited create(Asource);

  skipheader:=Askipheader;
  if Askipheader then
    err:=inflateInit2(Fstream,-MAX_WBITS)
  else
    err:=inflateInit(Fstream);
  if err<>Z_OK then
    raise Edecompressionerror.create(zerror(err));
end;

function Tdecompressionstream.read(var buffer;count:longint):longint;

var err:smallint;
    lastavail:longint;

begin
  Fstream.next_out:=@buffer;
  Fstream.avail_out:=count;
  lastavail:=count;
  while Fstream.avail_out<>0 do
    begin
      if Fstream.avail_in=0 then
        begin
          {Refill the buffer.}
          Fstream.next_in:=Fbuffer;
          Fstream.avail_in:=source.read(Fbuffer^,bufsize);
          inc(compressed_read,Fstream.avail_in);
          inc(raw_read,lastavail-Fstream.avail_out);
          lastavail:=Fstream.avail_out;
          progress(self);
        end;
      err:=inflate(Fstream,Z_NO_FLUSH);
      if err=Z_STREAM_END then
        break;
      if err<>Z_OK then
        raise Edecompressionerror.create(zerror(err));
    end;
  if err=Z_STREAM_END then
    dec(compressed_read,Fstream.avail_in);
  inc(raw_read,lastavail-Fstream.avail_out);
  read:=count-Fstream.avail_out;
end;

procedure Tdecompressionstream.reset;

var err:smallint;

begin
  source.seek(-compressed_read,sofromcurrent);
  raw_read:=0;
  compressed_read:=0;
  inflateEnd(Fstream);
  if skipheader then
    err:=inflateInit2(Fstream,-MAX_WBITS)
  else
    err:=inflateInit(Fstream);
  if err<>Z_OK then
    raise Edecompressionerror.create(zerror(err));
end;

function Tdecompressionstream.GetPosition() : Int64;
begin
  GetPosition := raw_read;
end;

function Tdecompressionstream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;

var c,off: int64;
    buf: array[0..8191] of Byte;

begin
  off:=Offset;

  if origin=soCurrent then
    inc(off,raw_read);
  if (origin=soEnd) or (off<0) then
    raise Edecompressionerror.create(Sseek_failed);

  seek:=off;

  if off<raw_read then
    reset
  else
    dec(off,raw_read);

  while off>0 do
    begin
      c:=off;
      if c>SizeOf(buf) then
        c:=SizeOf(buf);
      if read(buf,c)<>c then
        raise Edecompressionerror.create(Sseek_failed);
      dec(off,c);
    end;
end;

function Tdecompressionstream.get_compressionrate:single;

begin
  get_compressionrate:=100*compressed_read/raw_read;
end;


destructor Tdecompressionstream.destroy;

begin
  inflateEnd(Fstream);
  inherited destroy;
end;


{***************************************************************************}

constructor Tgzfilestream.create(filename:ansistring;filemode:Tgzopenmode);

begin
  if filemode=gzopenread then
    Fgzfile:=gzopen(filename,'rb')
  else
    Fgzfile:=gzopen(filename,'wb');
  Ffilemode:=filemode;
  if Fgzfile=nil then
    raise Egzfileerror.createfmt(Sgz_open_error,[filename]);
end;

function Tgzfilestream.read(var buffer;count:longint):longint;

begin
  if Ffilemode=gzopenwrite then
    raise Egzfileerror.create(Sgz_write_only);
  read:=gzread(Fgzfile,@buffer,count);
end;

function Tgzfilestream.write(const buffer;count:longint):longint;

begin
  if Ffilemode=gzopenread then
    raise Egzfileerror.create(Sgz_write_only);
  write:=gzwrite(Fgzfile,@buffer,count);
end;

function Tgzfilestream.seek(offset:longint;origin:word):longint;

begin
  seek:=gzseek(Fgzfile,offset,origin);
  if seek=-1 then
    raise egzfileerror.create(Sseek_failed);
end;

destructor Tgzfilestream.destroy;

begin
  gzclose(Fgzfile);
  inherited destroy;
end;

{ TGZipCompressionStream }

constructor TGZipCompressionStream.Create(ADest: TStream);
begin
  Create(clDefault, ADest);
end;

constructor TGZipCompressionStream.Create(ALevel: TCompressionLevel; ADest: TStream);
begin
  inherited Create;
  FLevel := ALevel;
  FCrc32Val := 0;
  FUncompressedSize := 0;
  FDest := ADest;
  WriteHeader;
  FCompressionStream := TCompressionStream.Create(FLevel, FDest, True);
end;

destructor TGZipCompressionStream.Destroy;
begin
  FCompressionStream.Flush;
  FCompressionStream.Free;
  WriteFooter;
  inherited;
end;

procedure TGZipCompressionStream.WriteHeader;
begin
  FDest.WriteByte($1f);  // signature 1 of 2
  FDest.WriteByte($8b);  // signature 2 of 2
  FDest.WriteByte($08);  // deflate algorithm
  FDest.WriteByte($00);  // no flags
  FDest.WriteDWord($00); // modification time unknown. Source is stream, not a file
  if FLevel = clmax then // XFL = extra flags = compression level
    FDest.WriteByte($02)
  else if FLevel = clfastest then
    FDest.WriteByte($04)
  else
    FDest.WriteByte($00);
  FDest.WriteByte($ff);  // OS file system unknown. Source is stream, not a file
end;

procedure TGZipCompressionStream.WriteFooter;
var
  i: Integer;
begin
  // write crc32 in 4 bytes, least significant byte first
  for i := 1 to 4 do
  begin
    FDest.WriteByte(FCrc32Val and $ff);
    FCrc32Val := FCrc32Val shr 8;
  end;

  // write uncompressed size in 4 bytes, least significant byte first
  for i := 1 to 4 do
  begin
    FDest.WriteByte(FUncompressedSize and $ff);
    FUncompressedSize := FUncompressedSize shr 8;
  end;
end;

function TGZipCompressionStream.Write(const Buffer; Count: Longint): Longint;
begin
  FCrc32Val := PasZLibCRC32(FCrc32Val, @Buffer, Count);
  Inc(FUncompressedSize, Count);
  Result := FCompressionStream.Write(Buffer, Count);
end;

{ TGZipDecompressionStream }

constructor TGZipDecompressionStream.Create(ASource: TStream);
begin
  inherited Create;
  FSource := ASource;
  FCrc32Val := 0;
  FUncompressedSize := 0;
  ReadHeader;
  FDecompressionStream := TDecompressionStream.Create(FSource, True);
end;

destructor TGZipDecompressionStream.Destroy;
begin
  FDecompressionStream.Free;
  inherited;
end;

procedure TGZipDecompressionStream.Assert(ACond: Boolean; AMsg: string = '');
begin
  if not ACond then
    raise EDecompressionError.Create(AMsg);
end;

procedure TGZipDecompressionStream.ReadHeader;
var
  Flags: Byte;
  XLEN: Cardinal;
begin
  Assert(FSource.ReadByte = $1f, Sgz_invalid_header);
  Assert(FSource.ReadByte = $8b, Sgz_invalid_header);
  Assert(FSource.ReadByte = $08, Sgz_invalid_algorithm);
  Flags := FSource.ReadByte;
  FSource.ReadDWord; // skip modification time. Dest is stream, not a file
  FSource.ReadByte;  // skip compression level, is not needed
  FSource.ReadByte;  // skip OS file system. Dest is stream, not a file

  if (Flags and $4) <> 0 then // FLG.FEXTRA
  begin
    XLEN := FSource.ReadByte + FSource.ReadByte shl 8; // least significant byte first
    while XLEN > 0 do
    begin
      FSource.ReadByte;
      Dec(XLEN);
    end;
  end;

  if (Flags and $8) <> 0 then // FLG.FNAME
  begin
    repeat
    until FSource.ReadByte = 0; // zero-terminated file name
  end;

  if (Flags and $10) <> 0 then // FLG.FCOMMENT
  begin
    repeat
    until FSource.ReadByte = 0; // zero-terminated file comment
  end;

  if (Flags and $2) <> 0 then // FLG.FHCRC
    FSource.ReadWord; // skip CRC16, check not implemented
end;

procedure TGZipDecompressionStream.ReadFooter;
var
  Crc32: Longword;
  OrigSize: Longword;
begin
  // The TDecompressionStream reads in buffers, so the footer
  // may already be skipped. Therefore, we need to Seek to the footer.
  // If FSource is non-seekable, we skip checking Crc32 and OrigSize.
  try
    FSource.Seek(-8, soEnd);
  except
    Exit;  // skip Crc32 and OrigSize checking
  end;

  Crc32 := FSource.ReadByte + FSource.ReadByte shl 8 + FSource.ReadByte shl 16 + FSource.ReadByte shl 24;
  Assert(FCrc32Val = Crc32, Sgz_invalid_crc32);
  OrigSize := FSource.ReadByte + FSource.ReadByte shl 8 + FSource.ReadByte shl 16 + FSource.ReadByte shl 24;
  Assert(FUncompressedSize = OrigSize, Sgz_invalid_output_size);
end;

function TGZipDecompressionStream.Read(var Buffer; Count: Longint): Longint;
begin
  Result := FDecompressionStream.Read(Buffer, Count);
  Inc(FUncompressedSize, Result);
  FCrc32Val := PasZLibCRC32(FCrc32Val, @Buffer, Result);

  if Result < Count then
    ReadFooter;
end;

function TGZipDecompressionStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  // accept Seek(0, soBeginning) if nothing read yet
  // this is needed for the TStream.CopyFrom() method
  if (Offset = 0) and (Origin = TSeekOrigin.soBeginning) and (FUncompressedSize = 0) then
    Result := 0
  else
    Result := inherited Seek(Offset, Origin);
end;

end.
