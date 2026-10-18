{$IFNDEF FPC_DOTTEDUNITS}
unit PasZLibIO;
{$ENDIF}

{ Nexus RTL consolidation, 2026, Kevin Collins.
  Authoritative source consolidated from FPC PasZLib. Algorithms and original
  notices retained below; see ../../packages/paszlib/README.md and the central
  Nexus ATTRIBUTIONS.md. This is an altered source distribution. }
{$mode objfpc}{$H-}{$inline on}{$goto on}{$T-}
{ -------------------------------------------------------------------- }

{$DEFINE MAX_MATCH_IS_258}

{ Compile with -DMAXSEG_64K if the alloc function cannot allocate more
  than 64k bytes at a time (needed on systems with 16-bit int). }

{- $DEFINE MAXSEG_64K}
{$IFDEF VER70}
  {$DEFINE TP}
  {$DEFINE MAXSEG_64K}
{$ENDIF}
{$IFNDEF WIN32}
  {$DEFINE UNALIGNED_OK}  { requires SizeOf(ush) = 2 ! }
{$ENDIF}

{$UNDEF DYNAMIC_CRC_TABLE}
{$UNDEF FASTEST}
{$define patch112}        { apply patch from the zlib home page }
{ -------------------------------------------------------------------- }
{$IFDEF WIN32}
  {$DEFINE Delphi32}
  {- $DEFINE Delphi5}  { keep compiler quiet }
{$ENDIF}


{$IFDEF FPC}
 {$DEFINE Use32}
 {$DEFINE pointer_arith}
 {$UNDEF UNALIGNED_OK}  { requires SizeOf(ush) = 2 ! }
 {$UNDEF MAXSEG_64K}
 {$UNDEF Delphi32}
{$ENDIF}

{- $DEFINE ZLIB_DEBUG}

{$IFDEF ZLIB_DEBUG}
  {$ASSERTIONS ON}
{$ENDIF}

interface

{$IFDEF FPC_DOTTEDUNITS}
uses
  {$ifdef UNIX}UnixApi.Base{$else}TP.DOS{$endif},
  System.Classes, System.SysUtils, System.ZLib.PasZLib, System.CRC32;
{$ELSE}
uses
  {$ifdef UNIX}BaseUnix{$else}Dos{$endif},
  Classes, SysUtils, PasZLib, CRC32;
{$ENDIF}

{ gzio declarations }
{$push}{$H-}



{
  Pascal unit based on gzio.c -- IO on .gz files
  Copyright (C) 1995-1998 Jean-loup Gailly.

  Define NO_DEFLATE to compile this file without the compression code

  Pascal translation based on code contributed by Francisco Javier Crespo
  Copyright (C) 1998 by Jacques Nomssi Nzali
  For conditions of distribution and use, see copyright notice in readme.txt
}









type gzFile = pointer;
type z_off_t = int64;

function gzopen  (path:string; mode:string) : gzFile;
function gzread  (f:gzFile; buf:pointer; len:cardinal) : integer;
function gzgetc  (f:gzfile) : integer;
function gzgets  (f:gzfile; buf:PAnsiChar; len:integer) : PAnsiChar;

{$ifndef NO_DEFLATE}
function gzwrite (f:gzFile; buf:pointer; len:cardinal) : integer;
function gzputc  (f:gzfile; c:AnsiChar) : integer;
function gzputs  (f:gzfile; s:PAnsiChar) : integer;
function gzflush (f:gzFile; flush:integer)           : integer;
  {$ifdef GZ_FORMAT_STRING}
  function gzprintf (zfile : gzFile;
                     const format : string;
                     a : array of integer);    { doesn't compile }
  {$endif}
{$endif}

function gzseek  (f:gzfile; offset:z_off_t; whence:integer) : z_off_t;
function gztell  (f:gzfile) : z_off_t;
function gzclose (f:gzFile)                      : integer;
function gzerror (f:gzFile; var errnum:smallint)      : string;
function gzsetparams (f:gzfile; level:integer; strategy:integer) : integer;
function gzrewind (f:gzFile) : integer;
function gzeof (f:gzfile) : boolean;

const
  SEEK_SET {: z_off_t} = 0; { seek from beginning of file }
  SEEK_CUR {: z_off_t} = 1; { seek from current position }
  SEEK_END {: z_off_t} = 2;


{$pop}

{ zstream declarations }
{$push}{$H-}



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



{***************************************************************************}

{***************************************************************************}





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

{$pop}

{ ziputils declarations }
{$push}{$H-}



{ ziputils.pas - IO on .zip files using zlib
  - definitions, declarations and routines used by both
    zip.pas and unzip.pas
    The file IO is implemented here.

  based on work by Gilles Vollant

  March 23th, 2000,
  Copyright (C) 2000 Jacques Nomssi Nzali }



{$undef UseStream}

{$ifdef WIN32}
  {$define Delphi}
  {$ifdef UseStream}
    {$define Streams}
  {$endif}
{$endif}

//uses  Classes, SysUtils;

{ -------------------------------------------------------------- }
{$ifdef Streams}
type
  FILEptr = TFileStream;
{$else}
type
  FILEptr = ^file;
{$endif}

type
  seek_mode = (ZipSeekSet, ZipSeekCur, ZipSeekEnd);
  open_mode = (fopenread, fopenwrite, fappendwrite);

function fopen(filename: PAnsiChar; mode: open_mode): FILEptr;

procedure fclose(fp: FILEptr);

function fseek(fp: FILEptr; recPos: longint; mode: seek_mode): longint;

function fread(buf: pointer; recSize: longint; recCount: longint; fp: FILEptr): longint;

function fwrite(buf: pointer; recSize: longint; recCount: longint; fp: FILEptr): longint;

function ftell(fp: FILEptr): longint;  { ZIP }

function feof(fp: FILEptr): longint;   { MiniZIP }

{ ------------------------------------------------------------------- }

type
  zipFile = pointer;
  unzFile = pointer;

type
  ZipOffset = longint;

{ tm_zip contain date/time info }
type
  tm_zip = record
    tm_sec:  longint;            { seconds after the minute - [0,59] }
    tm_min:  longint;            { minutes after the hour - [0,59] }
    tm_hour: longint;            { hours since midnight - [0,23] }
    tm_mday: longint;            { day of the month - [1,31] }
    tm_mon:  longint;            { months since January - [0,11] }
    tm_year: longint;            { years - [1980..2044] }
  end;

  tm_unz = tm_zip;

const
  Z_BUFSIZE = (16384);
  Z_MAXFILENAMEINZIP = (256);

const
  CENTRALHEADERMAGIC = $02014b50;

const
  SIZECENTRALDIRITEM = $2e;
  SIZEZIPLOCALHEADER = $1e;

const
  Paszip_copyright: PAnsiChar = ' Paszip Copyright 2000 Jacques Nomssi Nzali ';


{$pop}

{ zip declarations }
{$push}{$H-}



{ zip.c -- IO on .zip files using zlib
  zip.h -- IO for compress .zip files using zlib
   Version 0.15 alpha, Mar 19th, 1998,

   Copyright (C) 1998 Gilles Vollant

   This package allows to create .ZIP file, compatible with PKZip 2.04g
     WinZip, InfoZip tools and compatible.
   Encryption and multi volume ZipFile (span) are not supported.
   Old compressions used by old PKZip 1.x are not supported

  For decompression of .zip files, look at unzip.pas

  Pascal translation
  Copyright (C) 2000 by Jacques Nomssi Nzali
  For conditions of distribution and use, see copyright notice in readme.txt }




{$ifdef WIN32}
  {$define Delphi}
{$endif}





const
  ZIP_OK    = (0);
  ZIP_ERRNO = (Z_ERRNO);
  ZIP_PARAMERROR = (-102);
  ZIP_INTERNALERROR = (-104);
  Z_DEFAULT_COMPRESSION = -(1);
  Z_DEFLATED = 8;

(*
{ tm_zip contain date/time info }
type
  tm_zip = record
     tm_sec : integer;            { seconds after the minute - [0,59] }
     tm_min : integer;            { minutes after the hour - [0,59] }
     tm_hour : integer;           { hours since midnight - [0,23] }
     tm_mday : integer;           { day of the month - [1,31] }
     tm_mon : integer;            { months since January - [0,11] }
     tm_year : integer;           { years - [1980..2044] }
  end;
*)
type
  zip_fileinfo = record
    tmz_date: tm_zip;        { date in understandable format           }
    dosDate:  longword;         { if dos_date = 0, tmu_date is used       }
    {   flag : longint;       }{ general purpose bit flag        2 bytes }

    internal_fa: longint;    { internal file attributes        2 bytes }
    external_fa: longint;    { external file attributes        4 bytes }
  end;
  zip_fileinfo_ptr = ^zip_fileinfo;

function zipOpen(const pathname: PAnsiChar; append: longint): zipFile; {ZEXPORT}
{ Create a zipfile.
  pathname contain on Windows NT a filename like "c:\\zlib\\zlib111.zip" or on
  an Unix computer "zlib/zlib111.zip".
  if the file pathname exist and append=1, the zip will be created at the end
  of the file. (useful if the file contain a self extractor code)
  If the zipfile cannot be opened, the return value is NIL.
  Else, the return value is a zipFile Handle, usable with other function
  of this zip package. }

function zipOpenNewFileInZip(afile: zipFile;
  {const} filename: PAnsiChar; const zipfi: zip_fileinfo_ptr; const extrafield_local: pointer; size_extrafield_local: integer; const extrafield_global: pointer; size_extrafield_global: integer; const comment: PAnsiChar; method: longint; level: longint): longint; {ZEXPORT}
{ Open a file in the ZIP for writing.
  filename : the filename in zip (if NIL, '-' without quote will be used
  zipfi^ contain supplemental information
  if extrafield_local<>NIL and size_extrafield_local>0, extrafield_local
    contains the extrafield data the the local header
  if extrafield_global<>NIL and size_extrafield_global>0, extrafield_global
    contains the extrafield data the the local header
  if comment <> NIL, comment contain the comment string
  method contain the compression method (0 for store, Z_DEFLATED for deflate)
  level contain the level of compression (can be Z_DEFAULT_COMPRESSION) }

function zipWriteInFileInZip(afile: zipFile; const buf: pointer; len: cardinal): longint; {ZEXPORT}
{ Write data in the zipfile }

function zipCloseFileInZip(afile: zipFile): longint; {ZEXPORT}
 { Close the current file in the zipfile }

function zipClose(afile: zipFile; const global_comment: PAnsiChar): longint; {ZEXPORT}
 { Close the zipfile }


{$pop}

{ unzip declarations }
{$push}{$H-}





{ ----------------------------------------------------------------- }
{ unzip.c -- IO on .zip files using zlib
   Version 0.15 beta, Mar 19th, 1998,
  unzip.h -- IO for uncompress .zip files using zlib
  Version 0.15 beta, Mar 19th, 1998,

  Copyright (C) 1998 Gilles Vollant <info@winimage.com>
  http://www.winimage.com/zLibDll/zip.htm

   This unzip package allow extract file from .ZIP file, compatible
   with PKZip 2.04g, WinZip, InfoZip tools and compatible.
   Encryption and multi volume ZipFile (span) are not supported.
   Old compressions used by old PKZip 1.x are not supported

  Pascal translation
  Copyright (C) 2000 by Jacques Nomssi Nzali
  For conditions of distribution and use, see copyright notice in readme.txt }




{$ifdef WIN32}
  {$define Delphi}
{$endif}





const
  UNZ_OK    = (0);
  UNZ_END_OF_LIST_OF_FILE = (-100);
   UNZ_ERRNO = (Z_ERRNO);
  UNZ_EOF   = (0);
  UNZ_PARAMERROR = (-102);
  UNZ_BADZIPFILE = (-103);
  UNZ_INTERNALERROR = (-104);
  UNZ_CRCERROR = (-105);
(*
{ tm_unz contain date/time info }
type
 tm_unz = record
   tm_sec : integer;       { seconds after the minute - [0,59] }
   tm_min : integer;       { minutes after the hour - [0,59] }
   tm_hour : integer;      { hours since midnight - [0,23] }
   tm_mday : integer;      { day of the month - [1,31] }
   tm_mon : integer;       { months since January - [0,11] }
   tm_year : integer;      { years - [1980..2044] }
  end;
*)
{ unz_global_info structure contain global data about the ZIPfile
  These data comes from the end of central dir }
type
  unz_global_info = record
    number_entry: longint;   { total number of entries in
                              the central dir on this disk }
    size_comment: longint;   { size of the global comment of the zipfile }
  end;


{ unz_file_info contain information about a file in the zipfile }
type
  unz_file_info = record
    version: longint;                  { version made by                 2 bytes }
    version_needed: longint;           { version needed to extract       2 bytes }
    flag:    longint;                  { general purpose bit flag        2 bytes }
    compression_method: longint;       { compression method              2 bytes }
    dosDate: longint;                  { last mod file date in Dos fmt   4 bytes }
    crc:     cardinal;                 { crc-32                          4 bytes }
    compressed_size: longint;          { compressed size                 4 bytes }
    uncompressed_size: longint;        { uncompressed size               4 bytes }
    size_filename: longint;            { filename length                 2 bytes }
    size_file_extra: longint;          { extra field length              2 bytes }
    size_file_comment: longint;        { file comment length             2 bytes }

    disk_num_start: longint;          { disk number start               2 bytes }
    internal_fa:    longint;          { internal file attributes        2 bytes }
    external_fa:    longint;          { external file attributes        4 bytes }

    tmu_date: tm_unz;
  end;
  unz_file_info_ptr = ^unz_file_info;


function unzStringFileNameCompare(const fileName1: PAnsiChar; const fileName2: PAnsiChar; iCaseSensitivity: longint): longint;
{ Compare two filename (fileName1,fileName2).
  If iCaseSensitivity = 1 (1=true),
    comparison is case sensitive (like strcmp)
  If iCaseSensitivity = 2 (0=false),
    comparison is not case sensitive (like strcmpi or strcasecmp)
  If iCaseSensitivity = 0, case sensitivity is default of your
    operating system like 1 on Unix, 2 on Windows)
}


function unzOpen(const path: PAnsiChar): unzFile;

{ Open a Zip file. path contain the full pathname (by example,
  on a Windows NT computer "c:\\zlib\\zlib111.zip" or on an Unix computer
  "zlib/zlib111.zip".
  If the zipfile cannot be opened (file don't exist or in not valid), the
  return value is NIL.
  Else, the return value is a unzFile Handle, usable with other function
     of this unzip package.
}

function unzClose(afile: unzFile): longint;

{ Close a ZipFile opened with unzipOpen.
  If there are files inside the .Zip opened with unzOpenCurrentFile()
  (see later), these files MUST be closed with unzipCloseCurrentFile()
  before a call unzipClose.
  return UNZ_OK if there is no problem. }

function unzGetGlobalInfo(afile: unzFile; var pglobal_info: unz_global_info): longint;

{ Write info about the ZipFile in the *pglobal_info structure.
  No preparation of the structure is needed
  return UNZ_OK if there is no problem. }

function unzGetGlobalComment(afile: unzFile; szComment: PAnsiChar; uSizeBuf: longint): longint;

{ Get the global comment string of the ZipFile, in the szComment buffer.
  uSizeBuf is the size of the szComment buffer.
  return the number of byte copied or an error code <0 }

 {***************************************************************************}
 { Unzip package allow you browse the directory of the zipfile }

function unzGoToFirstFile(afile: unzFile): longint;

{ Set the current file of the zipfile to the first file.
  return UNZ_OK if there is no problem }

function unzGoToNextFile(afile: unzFile): longint;

{ Set the current file of the zipfile to the next file.
  return UNZ_OK if there is no problem
  return UNZ_END_OF_LIST_OF_FILE if the actual file was the latest. }


function unzLocateFile(afile: unzFile; const szFileName: PAnsiChar; iCaseSensitivity: longint): longint; { ZEXPORT }

{ Try locate the file szFileName in the zipfile.
  For the iCaseSensitivity signification, see unzStringFileNameCompare

  return value :
  UNZ_OK if the file is found. It becomes the current file.
  UNZ_END_OF_LIST_OF_FILE if the file is not found }


function unzGetCurrentFileInfo(afile: unzFile; pfile_info: unz_file_info_ptr; szFileName: PAnsiChar; fileNameBufferSize: longint; extraField: pointer; extraFieldBufferSize: longint; szComment: PAnsiChar; commentBufferSize: longint): longint; { ZEXPORT }

{ Get Info about the current file
  if pfile_info<>NIL, the pfile_info^ structure will contain some
  info about the current file
  if szFileName<>NIL, the filemane string will be copied in szFileName
      (fileNameBufferSize is the size of the buffer)
  if extraField<>NIL, the extra field information will be copied in
    extraField  (extraFieldBufferSize is the size of the buffer).
    This is the Central-header version of the extra field
  if szComment<>NIL, the comment string of the file will be copied in
    szComment (commentBufferSize is the size of the buffer) }


{***************************************************************************}
{* for reading the content of the current zipfile, you can open it, read data
   from it, and close it (you can close it before reading all the file) }


function unzOpenCurrentFile(afile: unzFile): longint; { ZEXPORT }

{ Open for reading data the current file in the zipfile.
  If there is no error, the return value is UNZ_OK. }


function unzCloseCurrentFile(afile: unzFile): longint; { ZEXPORT }

{ Close the file in zip opened with unzOpenCurrentFile
  Return UNZ_CRCERROR if all the file was read but the CRC is not good }


function unzReadCurrentFile(afile: unzFile; buf: pointer; len: cardinal): longint; { ZEXPORT }

{ Read bytes from the current file (opened by unzOpenCurrentFile)
  buf contain buffer where data must be copied
  len the size of buf.

  return the number of byte copied if some bytes are copied
  return 0 if the end of file was reached
  return <0 with error code if there is an error
    (UNZ_ERRNO for IO error, or zLib error for uncompress error) }

function unztell(afile: unzFile): ZipOffset;

{ Give the current position in uncompressed data }

function unzeof(afile: unzFile): longint;

{ return 1 if the end of file was reached, 0 elsewhere
  ! checks for valid params }

function unzGetLocalExtrafield(afile: unzFile; buf: pointer; len: cardinal): longint;
{ Read extra field from the current file (opened by unzOpenCurrentFile)
  This is the local-header version of the extra field (sometimes, there is
    more info in the local-header version than in the central-header)

  if buf=NIL, it return the size of the local extra field

  if buf<>NIL, len is the size of the buffer, the extra header is copied in
  buf.
  the return value is the number of bytes copied in buf, or (if <0)
  the error code }


{ ----------------------------------------------------------------- }


{$pop}

{ zipper declarations }
{$push}{$H+}
{
    $Id: header,v 1.3 2013/05/26 06:33:45 michael Exp $
    This file is part of the Free Component Library (FCL)
    Copyright (c) 1999-2014 by the Free Pascal development team

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

{$h+}










Const
  { Signatures }
  END_OF_CENTRAL_DIR_SIGNATURE               = $06054B50;
  ZIP64_END_OF_CENTRAL_DIR_SIGNATURE         = $06064B50;
  ZIP64_END_OF_CENTRAL_DIR_LOCATOR_SIGNATURE = $07064B50;
  LOCAL_FILE_HEADER_SIGNATURE                = $04034B50;
  CENTRAL_FILE_HEADER_SIGNATURE              = $02014B50;
  ZIP64_HEADER_ID                            = $0001;
  // infozip unicode path
  INFOZIP_UNICODE_PATH_ID                    = $7075;
  EFS_LANGUAGE_ENCODING_FLAG                 = $800;

const
  OS_FAT  = 0; //MS-DOS and OS/2 (FAT/VFAT/FAT32)
  OS_UNIX = 3;
  OS_OS2  = 6; //OS/2 HPFS
  OS_NTFS = 10;
  OS_VFAT = 14;
  OS_OSX  = 19;

  UNIX_MASK = $F000;
  UNIX_FIFO = $1000;
  UNIX_CHAR = $2000;
  UNIX_DIR  = $4000;
  UNIX_BLK  = $6000;
  UNIX_FILE = $8000;
  UNIX_LINK = $A000;
  UNIX_SOCK = $C000;


  UNIX_RUSR = $0100;
  UNIX_WUSR = $0080;
  UNIX_XUSR = $0040;

  UNIX_RGRP = $0020;
  UNIX_WGRP = $0010;
  UNIX_XGRP = $0008;

  UNIX_ROTH = $0004;
  UNIX_WOTH = $0002;
  UNIX_XOTH = $0001;

  UNIX_DEFAULT = UNIX_RUSR or UNIX_WUSR or UNIX_XUSR or UNIX_RGRP or UNIX_ROTH;

Type
   Local_File_Header_Type = Packed Record //1 per zipped file
     Signature              :  LongInt; //4 bytes
     Extract_Version_Reqd   :  Word; //if zip64: >= 45
     Bit_Flag               :  Word; //"General purpose bit flag in PKZip appnote
     Compress_Method        :  Word;
     Last_Mod_Time          :  Word;
     Last_Mod_Date          :  Word;
     Crc32                  :  LongWord;
     Compressed_Size        :  LongWord;
     Uncompressed_Size      :  LongWord;
     Filename_Length        :  Word;
     Extra_Field_Length     :  Word; //refers to Extensible data field size
   end;

   Extensible_Data_Field_Header_Type = Packed Record
     // Beginning of extra field
     // after local file header
     // after central directory header
     Header_ID              :  Word;
     //e.g. $0001 (ZIP64_HEADER_ID) Zip64 extended information extra field
     //     $0009 OS/2: extended attributes
     //     $000a NTFS: (Win32 really)
     //     $000d UNIX: uid, gid etc
     Data_Size              :  Word; //size of following field data
     //... field data should follow...
   end;

   Zip64_Extended_Info_Field_Type = Packed Record //goes after Extensible_Data_Field_Header_Type
     // overrides Local and Central Directory data
     // stored in extra field
     Original_Size          :  QWord; //Uncompressed file
     Compressed_Size        :  QWord; //Compressed data
     Relative_Hdr_Offset    :  QWord; //Offset that leads to local header record
     Disk_Start_Number      :  LongWord; //on which disk this file starts
   end;

  { Define the Central Directory record types }

  Central_File_Header_Type = Packed Record
    Signature            :  LongInt; //4 bytes
    MadeBy_Version       :  Word; //if zip64: lower byte >= 45
    Extract_Version_Reqd :  Word; //if zip64: >=45
    Bit_Flag             :  Word; //General purpose bit flag in PKZip appnote
    Compress_Method      :  Word;
    Last_Mod_Time        :  Word;
    Last_Mod_Date        :  Word;
    Crc32                :  LongWord;
    Compressed_Size      :  LongWord;
    Uncompressed_Size    :  LongWord;
    Filename_Length      :  Word;
    Extra_Field_Length   :  Word;
    File_Comment_Length  :  Word;
    Starting_Disk_Num    :  Word;
    Internal_Attributes  :  Word;
    External_Attributes  :  LongWord;
    Local_Header_Offset  :  LongWord; // if zip64: 0xFFFFFFFF
  End;

  End_of_Central_Dir_Type =  Packed Record //End of central directory record
    //1 per zip file, near end, before comment
    Signature               :  LongInt; //4 bytes
    Disk_Number             :  Word;
    Central_Dir_Start_Disk  :  Word;
    Entries_This_Disk       :  Word;
    Total_Entries           :  Word;
    Central_Dir_Size        :  LongWord;
    Start_Disk_Offset       :  LongWord;
    ZipFile_Comment_Length  :  Word;
  end;

  Zip64_End_of_Central_Dir_type = Packed Record
    Signature                 : LongInt;
    Record_Size               : QWord;
    Version_Made_By           : Word; //lower byte >= 45
    Extract_Version_Reqd      : Word; //version >= 45
    Disk_Number               : LongWord;
    Central_Dir_Start_Disk    : LongWord;
    Entries_This_Disk         : QWord;
    Total_Entries             : QWord;
    Central_Dir_Size          : QWord;
    Start_Disk_Offset         : QWord;
  end;

  Zip64_End_of_Central_Dir_Locator_type = Packed Record //comes after Zip64_End_of_Central_Dir_type
    Signature                           : LongInt;
    Zip64_EOCD_Start_Disk               : LongWord; //Starting disk for Zip64 End of Central Directory record
    Central_Dir_Zip64_EOCD_Offset       : QWord; //offset of Zip64 End of Central Directory record
    Total_Disks                         : LongWord; //total number of disks (contained in zip)
  end;

Type

  TProgressEvent = Procedure(Sender : TObject; Const Pct : Double) of object;
  TProgressEventEx = Procedure(Sender : TObject; Const ATotPos, ATotSize: Int64) of object;
  TOnEndOfFileEvent = Procedure(Sender : TObject; Const Ratio : Double) of object;
  TOnStartFileEvent = Procedure(Sender : TObject; Const AFileName : AnsiString) of object;

Type

  { TCompressor }
  TCompressor = Class(TObject)
  private
    FTerminated: Boolean;
  Protected
    FInFile     : TStream;        { I/O file variables                         }
    FOutFile    : TStream;
    FCrc32Val   : LongWord;       { CRC calculation variable                   }
    FBufferSize : LongWord;
    FOnPercent  : Integer;
    FOnProgress : TProgressEvent;
    Procedure UpdC32(Octet: Byte);
  Public
    Constructor Create(AInFile, AOutFile : TStream; ABufSize : LongWord); virtual;
    Procedure Compress; Virtual; Abstract;
    Class Function ZipID : Word; virtual; Abstract;
    Class Function ZipVersionReqd: Word; virtual; Abstract;
    Function ZipBitFlag: Word; virtual; Abstract;
    Procedure Terminate;
    Property BufferSize : LongWord read FBufferSize;
    Property OnPercent : Integer Read FOnPercent Write FOnPercent;
    Property OnProgress : TProgressEvent Read FOnProgress Write FOnProgress;
    Property Crc32Val : LongWord Read FCrc32Val Write FCrc32Val;
    Property Terminated : Boolean Read FTerminated;
  end;

  { TDeCompressor }
  TDeCompressor = Class(TObject)
  Protected
    FInFile     : TStream;        { I/O file variables                         }
    FOutFile    : TStream;
    FCrc32Val   : LongWord;       { CRC calculation variable                   }
    FBufferSize : LongWord;
    FOnPercent  : Integer;
    FOnProgress : TProgressEvent;
    FOnProgressEx: TProgressEventEx;
    FTotPos      : Int64;
    FTotSize     : Int64;
    FTerminated : Boolean;
    Procedure UpdC32(Octet: Byte);
  Public
    Constructor Create(AInFile, AOutFile : TStream; ABufSize : LongWord); virtual;
    Procedure DeCompress; Virtual; Abstract;
    Procedure Terminate;
    Class Function ZipID : Word; virtual; Abstract;
    Property BufferSize : LongWord read FBufferSize;
    Property OnPercent : Integer Read FOnPercent Write FOnPercent;
    Property OnProgress : TProgressEvent Read FOnProgress Write FOnProgress;
    Property OnProgressEx : TProgressEventEx Read FOnProgressEx Write FOnProgressEx;
    Property Crc32Val : LongWord Read FCrc32Val Write FCrc32Val;
    Property Terminated : Boolean Read FTerminated;
  end;

  { TShrinker }

Const
   TABLESIZE   =   8191;
   FIRSTENTRY  =    257;

Type
  CodeRec =  Packed Record
    Child   : Smallint;
    Sibling : Smallint;
    Suffix  : Byte;
  end;
  CodeArray   =  Array[0..TABLESIZE] of CodeRec;
  TablePtr    =  ^CodeArray;

  FreeListPtr    =  ^FreeListArray;
  FreeListArray  =  Array[FIRSTENTRY..TABLESIZE] of Word;

  BufPtr      =  PByte;

  TShrinker = Class(TCompressor)
  Private
    FBufSize    : LongWord;
    MaxInBufIdx :  LongWord;      { Count of valid chars in input buffer       }
    InputEof    :  Boolean;       { End of file indicator                      }
    CodeTable   :  TablePtr;      { Points to code table for LZW compression   }
    FreeList    :  FreeListPtr;   { Table of free code table entries           }
    NextFree    :  Word;          { Index into free list table                 }

    ClearList   :  Array[0..1023] of Byte;  { Bit mapped structure used in     }
                                            {    during adaptive resets        }
    CodeSize    :  Byte;     { Size of codes (in bits) currently being written }
    MaxCode     :  Word;   { Largest code that can be written in CodeSize bits }
    InBufIdx,                     { Points to next AnsiChar in buffer to be read   }
    OutBufIdx   :  LongWord;      { Points to next free space in output buffer }
    InBuf,                        { I/O buffers                                }
    OutBuf      :  BufPtr;
    FirstCh     :  Boolean;  { Flag indicating the START of a shrink operation }
    TableFull   :  Boolean;  { Flag indicating a full symbol table             }
    SaveByte    :  Byte;     { Output code buffer                              }
    BitsUsed    :  Byte;     { Index into output code buffer                   }
    BytesIn     :  LongWord;  { Count of input file bytes processed             }
    BytesOut    :  LongWord;  { Count of output bytes                           }
    FOnBytes    :  LongWord;
    Procedure FillInputBuffer;
    Procedure WriteOutputBuffer;
    Procedure FlushOutput;
    Procedure PutChar(B : Byte);
    procedure PutCode(Code : Smallint);
    Procedure InitializeCodeTable;
    Procedure Prune(Parent : Word);
    Procedure Clear_Table;
    Procedure Table_Add(Prefix : Word; Suffix : Byte);
    function  Table_Lookup(TargetPrefix : Smallint;
                           TargetSuffix : Byte;
                           Out FoundAt  : Smallint) : Boolean;
    Procedure Shrink(Suffix : Smallint);
    Procedure ProcessLine(Const Source : AnsiString);
    Procedure DoOnProgress(Const Pct : Double); Virtual;
  Public
    Constructor Create(AInFile, AOutFile : TStream; ABufSize : LongWord); override;
    Destructor Destroy; override;
    Procedure Compress; override;
    Class Function ZipID : Word; override;
    Class Function ZipVersionReqd : Word; override;
    Function ZipBitFlag : Word; override;
  end;

  { TDeflater }

  TDeflater = Class(TCompressor)
  private
    FCompressionLevel: TCompressionlevel;
  Public
    Constructor Create(AInFile, AOutFile : TStream; ABufSize : LongWord);override;
    Procedure Compress; override;
    Class Function ZipID : Word; override;
    Class Function ZipVersionReqd : Word; override;
    Function ZipBitFlag : Word; override;
    Property CompressionLevel : TCompressionlevel Read FCompressionLevel Write FCompressionLevel;
  end;

  { TInflater }

  TInflater = Class(TDeCompressor)
  Public
    Constructor Create(AInFile, AOutFile : TStream; ABufSize : LongWord);override;
    Procedure DeCompress; override;
    Class Function ZipID : Word; override;
  end;

  { TZipFileEntry }

  TZipFileEntry = Class(TCollectionItem)
  private
    FArchiveFileName: AnsiString; //Name of the file as it appears in the zip file list
    FUTF8FileName : UTF8String;
    FUTF8DiskFileName : UTF8String;
    FAttributes: LongWord;
    FDateTime: TDateTime;
    FDiskFileName: AnsiString; {Name of the file on disk (i.e. uncompressed. Can be empty if based on a stream.);
    uses local OS/filesystem directory separators}
    FHeaderPos: int64;
    FNeedsZip64: Boolean; //flags whether filesize is big enough so we need a zip64 entry
    FOS: Byte;
    FSize: Int64;
    FStream: TStream;
    FCompressionLevel: TCompressionlevel;
    function GetArchiveFileName: AnsiString;
    function GetUTF8ArchiveFileName: UTF8String;
    function GetUTF8DiskFileName: UTF8String;
    procedure SetArchiveFileName(Const AValue: AnsiString);
    procedure SetDiskFileName(Const AValue: AnsiString);
    procedure SetUTF8ArchiveFileName(AValue: UTF8String);
    procedure SetUTF8DiskFileName(AValue: UTF8String);
  Protected
    // For multi-disk support, a disk number property could be added here.
    Property HdrPos : int64 Read FHeaderPos Write FheaderPos;
    Property NeedsZip64 : boolean Read FNeedsZip64 Write FNeedsZip64;
  Public
    constructor Create(ACollection: TCollection); override;
    function IsDirectory: Boolean;
    function IsLink: Boolean;
    Procedure Assign(Source : TPersistent); override;
    Property Stream : TStream Read FStream Write FStream;
  Published
    Property ArchiveFileName : AnsiString Read GetArchiveFileName Write SetArchiveFileName;
    Property UTF8ArchiveFileName : UTF8String Read GetUTF8ArchiveFileName Write SetUTF8ArchiveFileName;
    Property DiskFileName : AnsiString Read FDiskFileName Write SetDiskFileName;
    Property UTF8DiskFileName : UTF8String Read GetUTF8DiskFileName Write SetUTF8DiskFileName;
    Property Size : Int64 Read FSize Write FSize;
    Property DateTime : TDateTime Read FDateTime Write FDateTime;
    property OS: Byte read FOS write FOS;
    property Attributes: LongWord read FAttributes write FAttributes;
    Property CompressionLevel: TCompressionlevel read FCompressionLevel write FCompressionLevel;
  end;

  { TZipFileEntries }

  TZipFileEntries = Class(TCollection)
  private
    function GetZ(AIndex : Integer): TZipFileEntry;
    procedure SetZ(AIndex : Integer; const AValue: TZipFileEntry);
  Public
    Function AddFileEntry(Const ADiskFileName : AnsiString): TZipFileEntry;
    Function AddFileEntry(Const ADiskFileName, AArchiveFileName : AnsiString): TZipFileEntry;
    Function AddFileEntry(Const AStream : TSTream; Const AArchiveFileName : AnsiString): TZipFileEntry;
    Procedure AddFileEntries(Const List : TStrings);
    Property Entries[AIndex : Integer] : TZipFileEntry Read GetZ Write SetZ; default;
  end;

  { TZipper }

  TZipper = Class(TObject)
  Private
    FEntries        : TZipFileEntries;
    FTerminated: Boolean;
    FZipping        : Boolean;
    FBufSize        : LongWord;
    FFileName       : RawByteString;         { Name of resulting Zip file                 }
    FFileComment    : AnsiString;
    FFiles          : TStrings;
    FInMemSize      : Int64;
    FZipFileNeedsZip64 : Boolean; //flags whether at least one file is big enough to require a zip64 record
    FOutStream      : TStream;
    FInFile         : TStream;     { I/O file variables                         }
    LocalHdr        : Local_File_Header_Type;
    LocalZip64ExtHdr: Extensible_Data_Field_Header_Type; //Extra field header fixed to zip64 (i.e. .ID=1)
    LocalZip64Fld   : Zip64_Extended_Info_Field_Type; //header is in LocalZip64ExtHdr
    CentralHdr      : Central_File_Header_Type;
    EndHdr          : End_of_Central_Dir_Type;
    FOnPercent      : LongInt;
    FOnProgress     : TProgressEvent;
    FOnEndOfFile    : TOnEndOfFileEvent;
    FOnStartFile    : TOnStartFileEvent;
    FCurrentCompressor : TCompressor;
    FUseLanguageEncoding: Boolean;
    function CheckEntries: Integer;
    procedure SetEntries(const AValue: TZipFileEntries);
  Protected
    Procedure CloseInput(Item : TZipFileEntry);
    Procedure StartZipFile(Item : TZipFileEntry);
    Function  UpdateZipHeader(Item : TZipFileEntry; FZip : TStream; ACRC : LongWord;AMethod : Word; AZipVersionReqd : Word; AZipBitFlag : Word) : Boolean;
    Procedure BuildZipDirectory; //Builds central directory based on local headers
    Procedure DoEndOfFile;
    Procedure ZipOneFile(Item : TZipFileEntry); virtual;
    Function  OpenInput(Item : TZipFileEntry) : Boolean;
    Procedure GetFileInfo;
    Procedure SetBufSize(Value : LongWord);
    Procedure SetFileName(Value : RawByteString);
    Function CreateCompressor(Item : TZipFileEntry; AinFile,AZipStream : TStream) : TCompressor; virtual;
    Property NeedsZip64 : boolean Read FZipFileNeedsZip64 Write FZipFileNeedsZip64;
  Public
    Constructor Create;
    Destructor Destroy;override;
    Procedure ZipAllFiles; virtual;
    // Saves zip to file and changes FileName
    Procedure SaveToFile(const AFileName: RawByteString);
    // Saves zip to stream
    Procedure SaveToStream(AStream: TStream);
    // Zips specified files into a zip with name AFileName
    Procedure ZipFile(const aFileToBeZipped : RawByteString);
    Procedure ZipFile(const AZipFileName,aFileToBeZipped : RawByteString);
    Procedure ZipFiles(const AZipFileName : RawByteString; FileList : TStrings);
    Procedure ZipFiles(const AZipFileName : RawByteString; const FileList : Array of RawbyteString);
    Procedure ZipFiles(const aFileList : Array of RawbyteString);
    Procedure ZipFiles(FileList : TStrings);
    // Zips specified entries into a zip with name AFileName
    Procedure ZipFiles(const AZipFileName : RawByteString; Entries : TZipFileEntries);
    Procedure ZipFiles(Entries : TZipFileEntries);
    // Easy access method
    // Zip single file
    Class Procedure Zip(const AZipFileName : RawByteString; const aFileToBeZipped: RawByteString);
    // Zip multiple file
    Class Procedure Zip(const AZipFileName : RawByteString; aFileList : Array of RawByteString);
    Class Procedure Zip(const AZipFileName : RawByteString; aFileList : TStrings);
    Procedure Clear;
    Procedure Terminate;
  Public
    Property BufferSize : LongWord Read FBufSize Write SetBufSize;
    Property OnPercent : Integer Read FOnPercent Write FOnPercent;
    Property OnProgress : TProgressEvent Read FOnProgress Write FOnProgress;
    Property OnStartFile : TOnStartFileEvent Read FOnStartFile Write FOnStartFile;
    Property OnEndFile : TOnEndOfFileEvent Read FOnEndOfFile Write FOnEndOfFile;
    Property FileName : RawByteString Read FFileName Write SetFileName;
    Property FileComment: AnsiString Read FFileComment Write FFileComment;
    // Deprecated. Use Entries.AddFileEntry(FileName) or Entries.AddFileEntries(List) instead.
    Property Files : TStrings Read FFiles; deprecated;
    Property InMemSize : Int64 Read FInMemSize Write FInMemSize;
    Property Entries : TZipFileEntries Read FEntries Write SetEntries;
    Property Terminated : Boolean Read FTerminated;
    // EFS/language encoding using UTF-8
    Property UseLanguageEncoding : Boolean Read FUseLanguageEncoding Write FUseLanguageEncoding;
  end;

  { TFullZipFileEntry }

  TFullZipFileEntry = Class(TZipFileEntry)
  private
    FBitFlags: Word;
    FCompressedSize: QWord;
    FCompressMethod: Word;
    FCRC32: LongWord;
  Public
    Property BitFlags : Word Read FBitFlags;
    Property CompressMethod : Word Read FCompressMethod;
    Property CompressedSize : QWord Read FCompressedSize;
    property CRC32: LongWord read FCRC32 write FCRC32;
  end;

  TOnCustomStreamEvent = Procedure(Sender : TObject; var AStream : TStream; AItem : TFullZipFileEntry) of object;
  TCustomInputStreamEvent = Procedure(Sender: TObject; var AStream: TStream) of object;

  { TFullZipFileEntries }

  TFullZipFileEntries = Class(TZipFileEntries)
  private
    function GetFZ(AIndex : Integer): TFullZipFileEntry;
    procedure SetFZ(AIndex : Integer; const AValue: TFullZipFileEntry);
  Public
    Property FullEntries[AIndex : Integer] : TFullZipFileEntry Read GetFZ Write SetFZ; default;
  end;

  { TUnZipper }

  TUnZipper = Class(TObject)
  Private
    FOnCloseInputStream: TCustomInputStreamEvent;
    FOnCreateStream: TOnCustomStreamEvent;
    FOnDoneStream: TOnCustomStreamEvent;
    FOnOpenInputStream: TCustomInputStreamEvent;
    FUnZipping  : Boolean;
    FBufSize    : LongWord;
    FFileName   : RawByteString;         { Name of resulting Zip file                 }
    FOutputPath : RawByteString;
    FFileComment: AnsiString;
    FEntries    : TFullZipFileEntries;
    FFiles      : TStrings;
    FUseUTF8    : Boolean;
    FFlat       : Boolean;
    FZipStream  : TStream;     { I/O file variables                         }
    LocalHdr    : Local_File_Header_Type; //Local header, before compressed file data
    LocalZip64Fld   : Zip64_Extended_Info_Field_Type; //header is in LocalZip64ExtHdr
    CentralHdr  : Central_File_Header_Type;
    FTotPos     : Int64;
    FTotSize    : Int64;
    FTerminated: Boolean;
    FOnPercent  : LongInt;
    FOnProgress : TProgressEvent;
    FOnProgressEx : TProgressEventEx;
    FOnEndOfFile : TOnEndOfFileEvent;
    FOnStartFile : TOnStartFileEvent;
    FCurrentDecompressor: TDecompressor;
    function CalcTotalSize(AllFiles: Boolean): Int64;
    function IsMatch(I: TFullZipFileEntry): Boolean;
  Protected
    Procedure OpenInput;
    Procedure CloseOutput(Item : TFullZipFileEntry; var OutStream: TStream);
    Procedure CloseInput;
    Procedure FindEndHeaders(
      out AEndHdr: End_of_Central_Dir_Type;
      out AEndHdrPos: Int64;
      out AEndZip64Hdr: Zip64_End_of_Central_Dir_type;
      out AEndZip64HdrPos: Int64);
    Procedure ReadZipDirectory;
    Procedure ReadZipHeader(Item : TFullZipFileEntry; out AMethod : Word);
    Procedure DoEndOfFile;
    Function  OpenOutput(OutFileName : RawByteString; Out OutStream: TStream; Item : TFullZipFileEntry) : Boolean;
    Procedure SetBufSize(Value : LongWord);
    Procedure SetFileName(Value : RawByteString);
    Procedure SetOutputPath(Value: RawByteString);
    Function CreateDeCompressor(Item : TZipFileEntry; AMethod : Word;AZipFile,AOutFile : TStream) : TDeCompressor; virtual;
  Public
    Constructor Create;
    Destructor Destroy;override;
    Procedure UnZipOneFile(Item : TFullZipFileEntry); virtual;
    Procedure UnZipAllFiles; virtual;
    Procedure UnZipFile(const aExtractFileName: RawByteString);
    Procedure UnZipFile(const AZipFileName, aExtractFileName: RawByteString);
    Procedure UnZipFiles(const AZipFileName : RawByteString; FileList : TStrings);
    Procedure UnZipFiles(const AZipFileName : RawByteString; aFileList : Array of RawBytestring);
    Procedure UnZipFiles(aFileList : TStrings);
    Procedure UnZipAllFiles(const AZipFileName : RawByteString);
    // Easy access methods. No instance needed, uses default options.
    // Unzip all files
    Class Procedure Unzip(const AZipFileName : RawByteString);
    // Unzip a single file.
    Class Procedure Unzip(const AZipFileName : RawByteString;aExtractFileName : RawByteString);
    Class Procedure UnZip(const AZipFileName, aExtractFileName: RawByteString; aOutputFileName : AnsiString);
    // Unzip several files
    Class Procedure Unzip(const AZipFileName : RawByteString; aFileList : Array of RawByteString);
    Class Procedure Unzip(const AZipFileName : RawByteString; aFileList : TStrings);
    Class Procedure Unzip(const AZipFileName : RawByteString; aFileList : Array of RawByteString; aOutputDir : RawByteString; aFlat : Boolean = false);
    Class Procedure Unzip(const AZipFileName : RawByteString; aFileList : TStrings; aOutputDir : RawByteString; aFlat : Boolean = false);
    Procedure Clear;
    Procedure Examine;
    Procedure Terminate;
  Public
    Property BufferSize : LongWord Read FBufSize Write SetBufSize;
    Property OnOpenInputStream: TCustomInputStreamEvent read FOnOpenInputStream write FOnOpenInputStream;
    Property OnCloseInputStream: TCustomInputStreamEvent read FOnCloseInputStream write FOnCloseInputStream;
    Property OnCreateStream : TOnCustomStreamEvent Read FOnCreateStream Write FOnCreateStream;
    Property OnDoneStream : TOnCustomStreamEvent Read FOnDoneStream Write FOnDoneStream;
    Property OnPercent : Integer Read FOnPercent Write FOnPercent;
    Property OnProgress : TProgressEvent Read FOnProgress Write FOnProgress;
    Property OnProgressEx : TProgressEventEx Read FOnProgressEx Write FOnProgressEx;
    Property OnStartFile : TOnStartFileEvent Read FOnStartFile Write FOnStartFile;
    Property OnEndFile : TOnEndOfFileEvent Read FOnEndOfFile Write FOnEndOfFile;
    Property FileName : RawByteString Read FFileName Write SetFileName;
    Property OutputPath : RawByteString Read FOutputPath Write SetOutputPath;
    Property FileComment: AnsiString Read FFileComment;
    Property Files : TStrings Read FFiles;
    Property Entries : TFullZipFileEntries Read FEntries;
    Property UseUTF8 : Boolean Read FUseUTF8 Write FUseUTF8;
    Property Flat : Boolean Read FFlat Write FFlat; // enable flat extraction, like -j when using unzip
    Property Terminated : Boolean Read FTerminated;
  end;

  EZipError = Class(Exception);


{$pop}

implementation

{$IFDEF FPC_DOTTEDUNITS}
uses System.RtlConsts, System.Strings;
{$ELSE}
uses RtlConsts, Strings;
{$ENDIF}

{ gzio implementation }
{$push}{$H-}


const
  Z_EOF = -1;         { same value as in STDIO.H }
  GZipBufferSize = 16384;
  { Z_PRINTF_BUFSIZE = 4096; }


  gz_magic : array[0..1] of byte = ($1F, $8B); { gzip magic header }

  { gzip flag byte }

  ASCII_FLAG  = $01; { bit 0 set: file probably ascii text }
  HEAD_CRC    = $02; { bit 1 set: header CRC present }
  EXTRA_FIELD = $04; { bit 2 set: extra field present }
  ORIG_NAME   = $08; { bit 3 set: original file name present }
  COMMENT     = $10; { bit 4 set: file comment present }
  RESERVED    = $E0; { bits 5..7: reserved }

type gz_stream = record
  FileOpened  : Boolean;
  stream      : z_stream;
  z_err       : integer;      { error code for last stream operation }
  z_eof       : boolean;  { set if end of input file }
  gzfile      : file;     { .gz file }
  inbuf       : Pbyte;   { input buffer }
  outbuf      : Pbyte;   { output buffer }
  crc         : cardinal;    { crc32 of uncompressed data }
  msg,                    { error message - limit 79 chars }
  path        : string[79];   { path name for debugging only - limit 79 chars }
  transparent : boolean;  { true if input file is not a .gz file }
  mode        : AnsiChar;     { 'w' or 'r' }
  startpos    : longint;     { start of compressed data in file (header skipped) }
  total_out : cardinal;  { Total read, over blocks }
end;

type gz_streamp = ^gz_stream;

function destroy (var s:gz_streamp) : integer; forward;
procedure check_header(s:gz_streamp); forward;


{ GZOPEN ====================================================================

  Opens a gzip (.gz) file for reading or writing. As Pascal does not use
  file descriptors, the code has been changed to accept only path names.

  The mode parameter defaults to BINARY read or write operations ('r' or 'w')
  but can also include a compression level ('w9') or a strategy: Z_FILTERED
  as in 'w6f' or Z_HUFFMAN_ONLY as in 'w1h'. (See the description of
  deflateInit2 for more information about the strategy parameter.)

  gzopen can be used to open a file which is not in gzip format; in this
  case, gzread will directly read from the file without decompression.

  gzopen returns nil if the file could not be opened (non-zero IOResult)
  or if there was insufficient memory to allocate the (de)compression state
  (zlib error is Z_MEM_ERROR).

============================================================================}

function gzopen (path:string; mode:string) : gzFile;

var

  i        : cardinal;
  err      : integer;
  level    : integer;        { compression level }
  strategy : integer;        { compression strategy }
  s        : gz_streamp;
{$ifdef UNIX}
  info:      stat;
{$else}
  attr:      word;
{$endif}

{$IFNDEF NO_DEFLATE}
  gzheader : array [0..9] of byte;
{$ENDIF}
  doseek,
  exists,
  writing : boolean;
  old_file_mode: byte;
begin

  if (path='') or (mode='') then begin
    gzopen := nil;
    exit;
  end;

  GetMem (s,sizeof(gz_stream));
  if not Assigned (s) then begin
    gzopen := nil;
    exit;
  end;

  level := Z_DEFAULT_COMPRESSION;
  strategy := Z_DEFAULT_STRATEGY;

  s^.FileOpened := False;
  s^.stream.state := nil;
  s^.stream.next_in := nil;
  s^.stream.next_out := nil;
  s^.stream.avail_in := 0;
  s^.stream.avail_out := 0;
  s^.z_err := Z_OK;
  s^.z_eof := false;
  s^.inbuf := nil;
  s^.outbuf := nil;
  s^.crc := CRC32Buffer(0, nil, 0);
  s^.msg := '';
  s^.transparent := false;
  s^.total_out:=0;

  s^.path := path; { limit to 255 chars }

  s^.mode := #0;
  for i:=1 to Length(mode) do begin
    case mode[i] of
      'r'      : s^.mode := 'r';
      'w'      : s^.mode := 'w';
      'a'      : s^.mode := 'a';
      '0'..'9' : level := Ord(mode[i])-Ord('0');
      'f'      : strategy := Z_FILTERED;
      'h'      : strategy := Z_HUFFMAN_ONLY;
    end;
  end;
  if s^.mode=#0 then begin
    destroy(s);
    gzopen := nil;
    exit;
  end;

  writing:=( s^.mode='a') or (s^.mode='w');

  if writing then begin
{$IFDEF NO_DEFLATE}
    err := Z_STREAM_ERROR;
{$ELSE}
    err := deflateInit2 (s^.stream, level, Z_DEFLATED, -MAX_WBITS,
                         DEF_MEM_LEVEL, strategy);
        { windowBits is passed < 0 to suppress zlib header }

    GetMem (s^.outbuf, GZipBufferSize);
    s^.stream.next_out := s^.outbuf;
{$ENDIF}
    if (err <> Z_OK) or (s^.outbuf = nil) then begin
      destroy(s);
      gzopen := gzFile(nil);
      exit;
    end;
  end

  else begin
    GetMem (s^.inbuf, GZipBufferSize);
    s^.stream.next_in := s^.inbuf;

    err := inflateInit2_ (s^.stream, -MAX_WBITS, ZLIB_VERSION, sizeof(z_stream));
        { windowBits is passed < 0 to tell that there is no zlib header }

    if (err <> Z_OK) or (s^.inbuf = nil) then begin
      destroy(s);
      gzopen := gzFile(nil);
      exit;
    end;
  end;

  s^.stream.avail_out := GZipBufferSize;

  {$PUSH} {$I-}
  Assign (s^.gzfile, path);
  {$ifdef unix}
    exists:=not (fpstat(path,info)<0);
  {$else}
    GetFAttr(s^.gzfile, Attr);
    exists:=(DosError= 0);
  {$endif}

  doseek:=false;
  if ((s^.mode='a') and not exists) or (s^.mode='w') then
    begin
    ReWrite (s^.gzfile,1)
    end
  else
    begin
      old_file_mode := FileMode;
      FileMode := 0;
      Reset (s^.gzfile,1);
      FileMode := old_file_mode;
      if s^.mode='a' then
        doseek:=true;      // seek AFTER I/O check.
    end;

  {$POP}
  if (IOResult <> 0) then begin
    destroy(s);
    gzopen := gzFile(nil);
    exit;
  end;
  s^.FileOpened := True;
  // append binary file.
  if doseek then
     seek(s^.gzfile,filesize(s^.gzfile));

  if s^.mode='a' then
    s^.mode:='w';   // difference append<->write doesn't matter anymore
  if writing then begin { Write a very simple .gz header }
{$IFNDEF NO_DEFLATE}
    gzheader [0] := gz_magic [0];
    gzheader [1] := gz_magic [1];
    gzheader [2] := Z_DEFLATED;   { method }
    gzheader [3] := 0;            { flags }
    gzheader [4] := 0;            { time[0] }
    gzheader [5] := 0;            { time[1] }
    gzheader [6] := 0;            { time[2] }
    gzheader [7] := 0;            { time[3] }
    gzheader [8] := 0;            { xflags }
    gzheader [9] := 0;            { OS code = MS-DOS }
    blockwrite (s^.gzfile, gzheader, 10);
    s^.startpos := longint(10);
{$ENDIF}
  end
  else begin
    check_header(s); { skip the .gz header }
    s^.startpos := FilePos(s^.gzfile) - s^.stream.avail_in;
  end;

  gzopen := gzFile(s);
end;


{ GZSETPARAMS ===============================================================

  Update the compression level and strategy.

============================================================================}

function gzsetparams (f:gzfile; level:integer; strategy:integer) : integer;

var

  s : gz_streamp;
  written: integer;

begin

  s := gz_streamp(f);

  if (s = nil) or (s^.mode <> 'w') then begin
    gzsetparams := Z_STREAM_ERROR;
    exit;
  end;

  { Make room to allow flushing }
  if (s^.stream.avail_out = 0) then begin
    s^.stream.next_out := s^.outbuf;
    blockwrite(s^.gzfile, s^.outbuf^, GZipBufferSize, written);
    if (written <> GZipBufferSize) then s^.z_err := Z_ERRNO;
    s^.stream.avail_out := GZipBufferSize;
  end;

  gzsetparams := deflateParams (s^.stream, level, strategy);
end;


{ GET_BYTE ==================================================================

  Read a byte from a gz_stream. Updates next_in and avail_in.
  Returns EOF for end of file.
  IN assertion: the stream s has been successfully opened for reading.

============================================================================}

function get_byte (s:gz_streamp) : integer;

begin
  if s^.z_eof then begin
    get_byte := Z_EOF;
    exit;
  end;

  if s^.stream.avail_in=0 then begin
    {$push}{$I-}
    blockread (s^.gzfile, s^.inbuf^, GZipBufferSize, s^.stream.avail_in);
    {$pop}
    if s^.stream.avail_in=0 then begin
      s^.z_eof := true;
      if (IOResult <> 0) then s^.z_err := Z_ERRNO;
      get_byte := Z_EOF;
      exit;
    end;
    s^.stream.next_in := s^.inbuf;
  end;

  Dec(s^.stream.avail_in);
  get_byte := s^.stream.next_in^;
  Inc(s^.stream.next_in);
end;


{ GETLONG ===================================================================

   Reads a Longint in LSB order from the given gz_stream.

============================================================================}
{
function getLong (s:gz_streamp) : cardinal;
var
  x  : array [0..3] of byte;
  i  : byte;
  c  : integer;
  n1 : longint;
  n2 : longint;
begin

  for i:=0 to 3 do begin
    c := get_byte(s);
    if (c = Z_EOF) then s^.z_err := Z_DATA_ERROR;
    x[i] := (c and $FF)
  end;
  n1 := (ush(x[3] shl 8)) or x[2];
  n2 := (ush(x[1] shl 8)) or x[0];
  getlong := (n1 shl 16) or n2;
end;
}
function getLong(s : gz_streamp) : cardinal;
var
  x : packed array [0..3] of byte;
  c : integer;
begin
  { x := cardinal(get_byte(s));  - you can't do this with TP, no unsigned longint }
  x[0] := Byte(get_byte(s));
  x[1] := Byte(get_byte(s));
  x[2] := Byte(get_byte(s));
  c := get_byte(s);
  x[3] := Byte(c);
  if (c = Z_EOF) then
    s^.z_err := Z_DATA_ERROR;
  GetLong := cardinal(x);
end;


{ CHECK_HEADER ==============================================================

  Check the gzip header of a gz_stream opened for reading.
  Set the stream mode to transparent if the gzip magic header is not present.
  Set s^.err  to Z_DATA_ERROR if the magic header is present but the rest of
  the header is incorrect.

  IN assertion: the stream s has already been created successfully;
  s^.stream.avail_in is zero for the first time, but may be non-zero
  for concatenated .gz files

============================================================================}

procedure check_header (s:gz_streamp);

var

  method : integer;  { method byte }
  flags  : integer;  { flags byte }
  len    : cardinal;
  c      : integer;

begin

  { Check the gzip magic header }
  for len := 0 to 1 do begin
    c := get_byte(s);
    if (c <> gz_magic[len]) then begin
      if (len <> 0) then begin
        Inc(s^.stream.avail_in);
        Dec(s^.stream.next_in);
      end;
      if (c <> Z_EOF) then begin
        Inc(s^.stream.avail_in);
        Dec(s^.stream.next_in);
	s^.transparent := TRUE;
      end;
      if (s^.stream.avail_in <> 0) then s^.z_err := Z_OK
      else s^.z_err := Z_STREAM_END;
      exit;
    end;
  end;

  method := get_byte(s);
  flags := get_byte(s);
  if (method <> Z_DEFLATED) or ((flags and RESERVED) <> 0) then begin
    s^.z_err := Z_DATA_ERROR;
    exit;
  end;

  for len := 0 to 5 do get_byte(s); { Discard time, xflags and OS code }

  if ((flags and EXTRA_FIELD) <> 0) then begin { skip the extra field }
    len := cardinal(get_byte(s));
    len := len + (cardinal(get_byte(s)) shl 8);
    { len is garbage if EOF but the loop below will quit anyway }
    while (len <> 0) and (get_byte(s) <> Z_EOF) do Dec(len);
  end;

  if ((flags and ORIG_NAME) <> 0) then begin { skip the original file name }
    repeat
      c := get_byte(s);
    until (c = 0) or (c = Z_EOF);
  end;

  if ((flags and COMMENT) <> 0) then begin { skip the .gz file comment }
    repeat
      c := get_byte(s);
    until (c = 0) or (c = Z_EOF);
  end;

  if ((flags and HEAD_CRC) <> 0) then begin { skip the header crc }
    get_byte(s);
    get_byte(s);
  end;

  if (s^.z_eof = true) then
    s^.z_err := Z_DATA_ERROR
  else
    s^.z_err := Z_OK;

end;


{ DESTROY ===================================================================

  Cleanup then free the given gz_stream. Return a zlib error code.
  Try freeing in the reverse order of allocations.

============================================================================}

function destroy (var s:gz_streamp) : integer;

begin

  destroy := Z_OK;

  if not Assigned (s) then begin
    destroy := Z_STREAM_ERROR;
    exit;
  end;

  if (s^.stream.state <> nil) then begin
    if (s^.mode = 'w') then begin
{$IFDEF NO_DEFLATE}
      destroy := Z_STREAM_ERROR;
{$ELSE}
      destroy := deflateEnd(s^.stream);
{$ENDIF}
    end
    else if (s^.mode = 'r') then begin
      destroy := inflateEnd(s^.stream);
    end;
  end;

  if s^.FileOpened then begin
    {$push}{$I-}
    close(s^.gzfile);
    {$pop}
    if (IOResult <> 0) then destroy := Z_ERRNO;
  end;

  if (s^.z_err < 0) then destroy := s^.z_err;

  if Assigned (s^.inbuf) then
    FreeMem(s^.inbuf, GZipBufferSize);
  if Assigned (s^.outbuf) then
    FreeMem(s^.outbuf, GZipBufferSize);
  FreeMem(s, sizeof(gz_stream));
  s := nil;

end;


{ GZREAD ====================================================================

  Reads the given number of uncompressed bytes from the compressed file.
  If the input file was not in gzip format, gzread copies the given number
  of bytes into the buffer.

  gzread returns the number of uncompressed bytes actually read
  (0 for end of file, -1 for error).

============================================================================}

function gzread (f:gzFile; buf:pointer; len:cardinal) : integer;

var

  s         : gz_streamp;
  start     : Pbyte;
  n         : cardinal;
  crclen    : cardinal;  { Buffer length to update CRC32 }
  filecrc   : cardinal; { CRC32 stored in GZIP'ed file }
  filelen   : cardinal; { Total lenght of uncompressed file }
  bytes     : integer;  { bytes actually read in I/O blockread }
  total_in  : Qword;
  total_out : Qword;
{$ifndef pointer_arith}
  next_out  : Pbyte;
{$endif}

begin
  filelen := 0;
  s := gz_streamp(f);
  start := Pbyte(buf); { starting point for crc computation }

  if (s = nil) or (s^.mode <> 'r') then begin
    gzread := Z_STREAM_ERROR;
    exit;
  end;

  if (s^.z_err = Z_DATA_ERROR) or (s^.z_err = Z_ERRNO) then begin
    gzread := -1;
    exit;
  end;

  if (s^.z_err = Z_STREAM_END) then begin
    gzread := 0;  { EOF }
    exit;
  end;

  s^.stream.next_out := Pbyte(buf);
  s^.stream.avail_out := len;

  while (s^.stream.avail_out <> 0) do begin

    if (s^.transparent = true) then begin
      { Copy first the lookahead bytes: }
      n := s^.stream.avail_in;
      if (n > s^.stream.avail_out) then n := s^.stream.avail_out;
      if (n > 0) then begin
        move(s^.stream.next_in^,s^.stream.next_out^,n);
        inc (s^.stream.next_out, n);
        inc (s^.stream.next_in, n);
        dec (s^.stream.avail_out, n);
        dec (s^.stream.avail_in, n);
      end;
      if (s^.stream.avail_out > 0) then begin
        blockread (s^.gzfile, s^.stream.next_out^, s^.stream.avail_out, bytes);
        dec (s^.stream.avail_out, cardinal(bytes));
      end;
      dec (len, s^.stream.avail_out);
      inc (s^.stream.total_in, cardinal(len));
      inc (s^.stream.total_out, cardinal(len));
      gzread := integer(len);
      exit;
    end; { IF transparent }

    if (s^.stream.avail_in = 0) and (s^.z_eof = false) then begin
      {$push}{$I-}
      blockread (s^.gzfile, s^.inbuf^, GZipBufferSize, s^.stream.avail_in);
      {$pop}
      if (s^.stream.avail_in = 0) then begin
        s^.z_eof := true;
	if (IOResult <> 0) then begin
	  s^.z_err := Z_ERRNO;
	  break;
        end;
      end;
      s^.stream.next_in := s^.inbuf;
    end;

    s^.z_err := inflate(s^.stream, Z_NO_FLUSH);

    if (s^.z_err = Z_STREAM_END) then begin
    {$ifdef pointer_arith}
      crclen := 0;
      crclen:=s^.stream.next_out-start;
    {$else}
      next_out := s^.stream.next_out;
      while (next_out <> start ) do begin
        dec (next_out);
        inc (crclen);   { Hack because Pascal cannot subtract pointers }
      end;
    {$endif}
      { Check CRC and original size }
      s^.crc := CRC32Buffer(s^.crc, start, crclen);
      start := s^.stream.next_out;

      filecrc := getLong (s);
      filelen := getLong (s);

      if (s^.crc <> filecrc) or (s^.stream.total_out-s^.total_out <> filelen)
        then s^.z_err := Z_DATA_ERROR
	else begin
	  { Check for concatenated .gz files: }
	  check_header(s);
	  if (s^.z_err = Z_OK) then begin
            total_in := s^.stream.total_in;
            total_out := s^.stream.total_out;
            s^.total_out:=total_out;

	    inflateReset (s^.stream);
	    s^.stream.total_in := total_in;
	    s^.stream.total_out := total_out;
	    s^.crc := CRC32Buffer(0, nil, 0);
	  end;
      end; {IF-THEN-ELSE}
    end;

    if (s^.z_err <> Z_OK) or (s^.z_eof = true) then break;

  end; {WHILE}

{$ifdef pointer_arith}
  crclen:=s^.stream.next_out-start;
{$else}
  crclen := 0;
  next_out := s^.stream.next_out;
  while (next_out <> start ) do begin
    dec (next_out);
    inc (crclen);   { Hack because Pascal cannot subtract pointers }
  end;
{$endif}
  s^.crc := CRC32Buffer(s^.crc, start, crclen);
  gzread := integer(len - s^.stream.avail_out);

end;


{ GZGETC ====================================================================

  Reads one byte from the compressed file.
  gzgetc returns this byte or -1 in case of end of file or error.

============================================================================}

function gzgetc (f:gzfile) : integer;

var c:byte;

begin

  if (gzread (f,@c,1) = 1) then gzgetc := c else gzgetc := -1;

end;


{ GZGETS ====================================================================

  Reads bytes from the compressed file until len-1 characters are read,
  or a newline character is read and transferred to buf, or an end-of-file
  condition is encountered. The string is then Null-terminated.

  gzgets returns buf, or nil in case of error.
  The current implementation is not optimized at all.

============================================================================}

function gzgets (f:gzfile; buf:PAnsiChar; len:integer) : PAnsiChar;

var

  b      : PAnsiChar; { start of buffer }
  bytes  : integer;   { number of bytes read by gzread }
  gzchar : AnsiChar;  { AnsiChar read by gzread }

begin

    if (buf = nil) or (len <= 0) then begin
      gzgets := nil;
      exit;
    end;

    b := buf;
    repeat
      dec (len);
      bytes := gzread (f, buf, 1);
      gzchar := buf^;
      inc (buf);
    until (len = 0) or (bytes <> 1) or (gzchar = Chr(13));

    buf^ := #0;
    if (b = buf) and (len > 0) then gzgets := nil else gzgets := b;

end;


{$IFNDEF NO_DEFLATE}

{ GZWRITE ===================================================================

  Writes the given number of uncompressed bytes into the compressed file.
  gzwrite returns the number of uncompressed bytes actually written
  (0 in case of error).

============================================================================}

function gzwrite (f:gzfile; buf:pointer; len:cardinal) : integer;

var

  s : gz_streamp;
  written : integer;

begin

    s := gz_streamp(f);

    if (s = nil) or (s^.mode <> 'w') then begin
      gzwrite := Z_STREAM_ERROR;
      exit;
    end;

    s^.stream.next_in := Pbyte(buf);
    s^.stream.avail_in := len;

    while (s^.stream.avail_in <> 0) do begin

      if (s^.stream.avail_out = 0) then begin
        s^.stream.next_out := s^.outbuf;
        blockwrite (s^.gzfile, s^.outbuf^, GZipBufferSize, written);
        if (written <> GZipBufferSize) then begin
          s^.z_err := Z_ERRNO;
          break;
        end;
        s^.stream.avail_out := GZipBufferSize;
      end;

      s^.z_err := deflate(s^.stream, Z_NO_FLUSH);
      if (s^.z_err <> Z_OK) then break;

    end; {WHILE}

    s^.crc := CRC32Buffer(s^.crc, buf, len);
    gzwrite := integer(len - s^.stream.avail_in);

end;


{ ===========================================================================
   Converts, formats, and writes the args to the compressed file under
   control of the format string, as in fprintf. gzprintf returns the number of
   uncompressed bytes actually written (0 in case of error).
}

{$IFDEF GZ_FORMAT_STRING}
function gzprintf (zfile : gzFile;
                   const format : string;
                   a : array of integer) : integer;
var
  buf : array[0..Z_PRINTF_BUFSIZE-1] of AnsiChar;
  len : integer;
begin
{$ifdef HAS_snprintf}
    snprintf(buf, sizeof(buf), format, a1, a2, a3, a4, a5, a6, a7, a8,
	     a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20);
{$else}
    sprintf(buf, format, a1, a2, a3, a4, a5, a6, a7, a8,
	    a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20);
{$endif}
    len := strlen(buf); { old sprintf doesn't return the nb of bytes written }
    if (len <= 0) return 0;

    gzprintf := gzwrite(file, buf, len);
end;
{$ENDIF}


{ GZPUTC ====================================================================

  Writes c, converted to an unsigned AnsiChar, into the compressed file.
  gzputc returns the value that was written, or -1 in case of error.

============================================================================}

function gzputc (f:gzfile; c:AnsiChar) : integer;
begin
  if (gzwrite (f,@c,1) = 1) then
  {$IFDEF FPC}
    gzputc := integer(ord(c))
  {$ELSE}
    gzputc := integer(c)
  {$ENDIF}
  else
    gzputc := -1;
end;


{ GZPUTS ====================================================================

  Writes the given null-terminated string to the compressed file, excluding
  the terminating null character.
  gzputs returns the number of characters written, or -1 in case of error.

============================================================================}

function gzputs (f:gzfile; s:PAnsiChar) : integer;
begin
  gzputs := gzwrite (f, pointer(s), strlen(s));
end;


{ DO_FLUSH ==================================================================

  Flushes all pending output into the compressed file.
  The parameter flush is as in the zdeflate() function.

============================================================================}

function do_flush (f:gzfile; flush:integer) : integer;
var
  len     : cardinal;
  done    : boolean;
  s       : gz_streamp;
  written : integer;
begin
  done := false;
  s := gz_streamp(f);

  if (s = nil) or (s^.mode <> 'w') then begin
    do_flush := Z_STREAM_ERROR;
    exit;
  end;

  s^.stream.avail_in := 0; { should be zero already anyway }

  while true do begin

    len := GZipBufferSize - s^.stream.avail_out;

    if (len <> 0) then begin
      {$push}{$I-}
      blockwrite(s^.gzfile, s^.outbuf^, len, written);
      {$pop}
      if (written <> len) then begin
        s^.z_err := Z_ERRNO;
        do_flush := Z_ERRNO;
        exit;
      end;
      s^.stream.next_out := s^.outbuf;
      s^.stream.avail_out := GZipBufferSize;
    end;

    if (done = true) then break;
    s^.z_err := deflate(s^.stream, flush);

    { Ignore the second of two consecutive flushes: }
    if (len = 0) and (s^.z_err = Z_BUF_ERROR) then s^.z_err := Z_OK;

    { deflate has finished flushing only when it hasn't used up
      all the available space in the output buffer: }

    done := (s^.stream.avail_out <> 0) or (s^.z_err = Z_STREAM_END);
    if (s^.z_err <> Z_OK) and (s^.z_err <> Z_STREAM_END) then break;

  end; {WHILE}

  if (s^.z_err = Z_STREAM_END) then do_flush:=Z_OK else do_flush:=s^.z_err;
end;

{ GZFLUSH ===================================================================

  Flushes all pending output into the compressed file.
  The parameter flush is as in the zdeflate() function.

  The return value is the zlib error number (see function gzerror below).
  gzflush returns Z_OK if the flush parameter is Z_FINISH and all output
  could be flushed.

  gzflush should be called only when strictly necessary because it can
  degrade compression.

============================================================================}

function gzflush (f:gzfile; flush:integer) : integer;
var
  err : integer;
  s   : gz_streamp;
begin
  s := gz_streamp(f);
  err := do_flush (f, flush);

  if (err <> 0) then begin
    gzflush := err;
    exit;
  end;

  if (s^.z_err = Z_STREAM_END) then gzflush := Z_OK else gzflush := s^.z_err;
end;

{$ENDIF} (* NO DEFLATE *)


{ GZREWIND ==================================================================

  Rewinds input file.

============================================================================}

function gzrewind (f:gzFile) : integer;
var
  s:gz_streamp;
begin
  s := gz_streamp(f);

  if (s = nil) or (s^.mode <> 'r') then begin
    gzrewind := -1;
    exit;
  end;

  s^.z_err := Z_OK;
  s^.z_eof := false;
  s^.stream.avail_in := 0;
  s^.stream.next_in := s^.inbuf;

  if (s^.startpos = 0) then begin { not a compressed file }
    {$push}{$I-}
    seek (s^.gzfile, 0);
    {$pop}
    gzrewind := 0;
    exit;
  end;

  inflateReset(s^.stream);
  {$push}{$I-}
  seek (s^.gzfile, s^.startpos);
  {$pop}
  gzrewind := integer(IOResult);
  exit;
end;


{ GZSEEK ====================================================================

  Sets the starting position for the next gzread or gzwrite on the given
  compressed file. The offset represents a number of bytes from the beginning
  of the uncompressed stream.

  gzseek returns the resulting offset, or -1 in case of error.
  SEEK_END is not implemented, returns error.
  In this version of the library, gzseek can be extremely slow.

============================================================================}

function gzseek (f:gzfile; offset:z_off_t; whence:integer) : z_off_t;
var
  s : gz_streamp;
  size : cardinal;
begin
  s := gz_streamp(f);

  if (s = nil) or (whence = SEEK_END) or (s^.z_err = Z_ERRNO)
  or (s^.z_err = Z_DATA_ERROR) then begin
    gzseek := z_off_t(-1);
    exit;
  end;

  if (s^.mode = 'w') then begin
{$IFDEF NO_DEFLATE}
    gzseek := z_off_t(-1);
    exit;
{$ELSE}
    if (whence = SEEK_SET) then dec(offset, s^.stream.total_out);
    if (offset < 0) then begin;
      gzseek := z_off_t(-1);
      exit;
    end;

    { At this point, offset is the number of zero bytes to write. }
    if s^.inbuf=nil then begin
      getmem(s^.inbuf,GZipBufferSize);
      fillchar(s^.inbuf^,GZipBufferSize,0);
    end;

    while (offset > 0) do begin
      size := GZipBufferSize;
      if (offset < GZipBufferSize) then size := cardinal(offset);

      size := gzwrite(f, s^.inbuf, size);
      if (size = 0) then begin
        gzseek := z_off_t(-1);
        exit;
      end;

      dec (offset,size);
    end;

    gzseek := z_off_t(s^.stream.total_in);
    exit;
{$ENDIF}
  end;
  { Rest of function is for reading only }

  { compute absolute position }
  if (whence = SEEK_CUR) then inc (offset, s^.stream.total_out);
  if (offset < 0) then begin
    gzseek := z_off_t(-1);
    exit;
  end;

  if (s^.transparent = true) then begin
    s^.stream.avail_in := 0;
    s^.stream.next_in := s^.inbuf;
    {$push}{$I-}
    seek (s^.gzfile, offset);
    {$pop}
    if (IOResult <> 0) then begin
      gzseek := z_off_t(-1);
      exit;
    end;

    s^.stream.total_in := offset;
    s^.stream.total_out := offset;
    gzseek := offset;
    exit;
  end;

  { For a negative seek, rewind and use positive seek }
  if (cardinal(offset) >= s^.stream.total_out)
    then dec (offset, s^.stream.total_out)
    else if (gzrewind(f) <> 0) then begin
      gzseek := z_off_t(-1);
      exit;
  end;
  { offset is now the number of bytes to skip. }

  if (offset <> 0) and (s^.outbuf = nil)
  then GetMem (s^.outbuf, GZipBufferSize);

  while (offset > 0) do begin
    size := GZipBufferSize;
    if (offset < GZipBufferSize) then size := integer(offset);

    size := gzread (f, s^.outbuf, size);
    if (size <= 0) then begin
      gzseek := z_off_t(-1);
      exit;
    end;
    dec(offset, size);
  end;

  gzseek := z_off_t(s^.stream.total_out);
end;


{ GZTELL ====================================================================

  Returns the starting position for the next gzread or gzwrite on the
  given compressed file. This position represents a number of bytes in the
  uncompressed data stream.

============================================================================}

function gztell (f:gzfile) : z_off_t;
begin
  gztell := gzseek (f, 0, SEEK_CUR);
end;


{ GZEOF =====================================================================

  Returns TRUE when EOF has previously been detected reading the given
  input stream, otherwise FALSE.

============================================================================}

function gzeof (f:gzfile) : boolean;
var
  s:gz_streamp;
begin
  s := gz_streamp(f);

  if (s=nil) or (s^.mode<>'r') then
    gzeof := false
  else
    gzeof := s^.z_eof;
end;


{ PUTLONG ===================================================================

  Outputs a Longint in LSB order to the given file

============================================================================}

procedure putLong (var f:file; x:cardinal);
var
  n : integer;
  c : byte;
begin
  for n:=0 to 3 do begin
    c := x and $FF;
    blockwrite (f, c, 1);
    x := x shr 8;
  end;
end;


{ GZCLOSE ===================================================================

  Flushes all pending output if necessary, closes the compressed file
  and deallocates all the (de)compression state.

  The return value is the zlib error number (see function gzerror below).

============================================================================}

function gzclose (f:gzFile) : integer;
var
  err : integer;
  s   : gz_streamp;
begin
  s := gz_streamp(f);
  if (s = nil) then begin
    gzclose := Z_STREAM_ERROR;
    exit;
  end;

  if (s^.mode = 'w') then begin
{$IFDEF NO_DEFLATE}
    gzclose := Z_STREAM_ERROR;
    exit;
{$ELSE}
  err := do_flush (f, Z_FINISH);
    if (err <> Z_OK) then begin
      gzclose := destroy (gz_streamp(f));
      exit;
    end;

    putLong (s^.gzfile, s^.crc);
    putLong (s^.gzfile, s^.stream.total_in and $FFFFFFFF);
{$ENDIF}
  end;

  gzclose := destroy (gz_streamp(f));
end;


{ GZERROR ===================================================================

  Returns the error message for the last error which occurred on the
   given compressed file. errnum is set to zlib error number. If an
   error occurred in the file system and not in the compression library,
   errnum is set to Z_ERRNO and the application may consult errno
   to get the exact error code.

============================================================================}

function gzerror (f:gzfile; var errnum:smallint) : string;
var
 m : string;
 s : gz_streamp;
begin
  s := gz_streamp(f);
  if (s = nil) then begin
    errnum := Z_STREAM_ERROR;
    gzerror := zError(Z_STREAM_ERROR);
    end;

  errnum := s^.z_err;
  if (errnum = Z_OK) then begin
    gzerror := zError(Z_OK);
    exit;
  end;

  m := s^.stream.msg;
  if (errnum = Z_ERRNO) then m := '';
  if (m = '') then m := zError(s^.z_err);

  s^.msg := s^.path+': '+m;
  gzerror := s^.msg;
end;


{$pop}

{ zstream implementation }
{$push}{$H-}

{***************************************************************************}





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
{$IFDEF NO_DEFLATE}
  raise Egzfileerror.create(Sgz_write_only);
{$ELSE}
  Result:=gzwrite(Fgzfile,@buffer,count);
{$ENDIF}
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
  FCrc32Val := CRC32Buffer(FCrc32Val, @Buffer, Count);
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
  FCrc32Val := CRC32Buffer(FCrc32Val, @Buffer, Result);

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


{$pop}

{ ziputils implementation }
{$push}{$H-}


{$ifdef Streams}
{ ---------------------------------------------------------------- }

function fopen(filename: PAnsiChar; mode: open_mode): FILEptr;
var
  fp: FILEptr;
begin
  fp := nil;
  try
    case mode of
      fopenread: fp  := TFileStream.Create(strpas(filename), fmOpenRead or fmShareDenyWrite);
      fopenwrite: fp := TFileStream.Create(strpas(filename), fmCreate);
      fappendwrite:
      begin
        fp := TFileStream.Create(strpas(filename), fmOpenReadWrite);
        fp.Seek(soFromEnd, 0);
      end;
    end;
  except
    on EFOpenError do
      fp := nil;
  end;
  fopen := fp;
end;

procedure fclose(fp: FILEptr);
begin
  fp.Free;
end;

function fread(buf: pointer; recSize: longint; recCount: longint; fp: FILEptr): longint;
var
  totalSize, readcount: longint;
begin
  if Assigned(buf) then
  begin
    totalSize := recCount * longint(recSize);
    readCount := fp.Read(buf^, totalSize);
    if (readcount <> totalSize) then
      fread := readcount div recSize
    else
      fread := recCount;
  end
  else
    fread := 0;
end;

function fwrite(buf: pointer; recSize: longint; recCount: longint; fp: FILEptr): longint;
var
  totalSize, written: longint;
begin
  if Assigned(buf) then
  begin
    totalSize := recCount * longint(recSize);
    written   := fp.Write(buf^, totalSize);
    if (written <> totalSize) then
      fwrite := written div recSize
    else
      fwrite := recCount;
  end
  else
    fwrite := 0;
end;

function fseek(fp: FILEptr; recPos: longint; mode: seek_mode): int;
const
  fsmode: array[seek_mode] of word = (soFromBeginning, soFromCurrent, soFromEnd);
begin
  fp.Seek(recPos, fsmode[mode]);
  fseek := 0; { = 0 for success }
end;

function ftell(fp: FILEptr): longint;
begin
  ftell := fp.Position;
end;

function feof(fp: FILEptr): longint;
begin
  feof := 0;
  if Assigned(fp) then
    if fp.Position = fp.Size then
      feof := 1
    else
      feof := 0;
end;

{$else}
{ ---------------------------------------------------------------- }

function fopen(filename : PAnsiChar; mode : open_mode) : FILEptr;
var
  fp : FILEptr;
  OldFileMode : byte;
begin
  fp := NIL;
  OldFileMode := FileMode;

  GetMem(fp, SizeOf(file));
  Assign(fp^, strpas(filename));
  {$push}{$i-}
  Case mode of
  fopenread:
    begin
      FileMode := 0;
      Reset(fp^, 1);
    end;
  fopenwrite:
    begin
      FileMode := 1;
      ReWrite(fp^, 1);
    end;
  fappendwrite :
    begin
      FileMode := 2;
      Reset(fp^, 1);
      Seek(fp^, FileSize(fp^));
    end;
  end;
  FileMode := OldFileMode;
  {$pop}
  if IOresult<>0 then
  begin
    FreeMem(fp, SizeOf(file));
    fp := NIL;
  end;

  fopen := fp;
end;

procedure fclose(fp : FILEptr);
begin
  if Assigned(fp) then
  begin
    {$push}{$i-}
    system.close(fp^);
    {$pop}
    if IOresult=0 then;
    FreeMem(fp, SizeOf(file));
  end;
end;

function fread(buf : pointer;
               recSize : LongInt;
               recCount : LongInt;
               fp : FILEptr) : LongInt;
var
  totalSize, readcount : LongInt;
begin
  if Assigned(buf) then
  begin
    totalSize := recCount * LongInt(recSize);
    {$push}{$i-}
    system.BlockRead(fp^, buf^, totalSize, readcount);
    if (readcount <> totalSize) then
      fread := readcount div recSize
    else
      fread := recCount;
    {$pop}
  end
  else
    fread := 0;
end;

function fwrite(buf : pointer;
                recSize : LongInt;
                recCount : LongInt;
                fp : FILEptr) : LongInt;
var
  totalSize, written : LongInt;
begin
  if Assigned(buf) then
  begin
    totalSize := recCount * LongInt(recSize);
    {$push}{$i-}
    system.BlockWrite(fp^, buf^, totalSize, written);
    if (written <> totalSize) then
      fwrite := written div recSize
    else
      fwrite := recCount;
    {$pop}
  end
  else
    fwrite := 0;
end;

function fseek(fp : FILEptr;
               recPos : LongInt;
               mode : seek_mode) : longint;
begin
  {$push}{$i-}
  case mode of
    ZipSeekSet : system.Seek(fp^, recPos);
    ZipSeekCur : system.Seek(fp^, FilePos(fp^)+recPos);
    ZipSeekEnd : system.Seek(fp^, FileSize(fp^)-1-recPos); { ?? check }
  end;
  {$pop}
  fseek := IOresult; { = 0 for success }
end;

function ftell(fp : FILEptr) : LongInt;
begin
  ftell := FilePos(fp^);
end;

function feof(fp : FILEptr) : LongInt;
begin
  feof := 0;
  if Assigned(fp) then
    if eof(fp^) then
      feof := 1
    else
      feof := 0;
end;

{$endif}
{ ---------------------------------------------------------------- }


{$pop}

{ zip implementation }
{$push}{$H-}






const
  VERSIONMADEBY = ($0); { platform dependent }

const
  zip_copyright: PAnsiChar = ' zip 0.15 Copyright 1998 Gilles Vollant ';


const
  SIZEDATA_INDATABLOCK = (4096 - (4 * 4));

  LOCALHEADERMAGIC = $04034b50;
  {CENTRALHEADERMAGIC = $02014b50;}
  ENDHEADERMAGIC   = $06054b50;

  FLAG_LOCALHEADER_OFFSET = $06;
  CRC_LOCALHEADER_OFFSET  = $0e;

  SIZECENTRALHEADER = $2e; { 46 }

type
  linkedlist_datablock_internal_ptr = ^linkedlist_datablock_internal;

  linkedlist_datablock_internal = record
    next_datablock: linkedlist_datablock_internal_ptr;
    avail_in_this_block: longint;
    filled_in_this_block: longint;
    unused: longint; { for future use and alignment }
    Data:   array[0..SIZEDATA_INDATABLOCK - 1] of byte;
  end;

type
  linkedlist_data = record
    first_block: linkedlist_datablock_internal_ptr;
    last_block:  linkedlist_datablock_internal_ptr;
  end;
  linkedlist_data_ptr = ^linkedlist_data;

type
  curfile_info = record
    stream: z_stream;            { zLib stream structure for inflate }
    stream_initialised: boolean; { TRUE is stream is initialised }
    pos_in_buffered_data: integer;  { last written byte in buffered_data }

    pos_local_header: longint;     { offset of the local header of the file
                                    currently writing }
    central_header: PAnsiChar;       { central header data for the current file }
    size_centralheader: longint;   { size of the central header for cur file }
    flag: longint;                 { flag of the file currently writing }

    method:  longint;                { compression method of file currently wr.}
    buffered_data: array[0..Z_BUFSIZE - 1] of byte;{ buffer contain compressed data to be written}
    dosDate: longint;
    crc32:   cardinal;
  end;

type
  zip_internal = record
    filezip: FILEptr;
    central_dir: linkedlist_data;  { datablock with central dir in construction}
    in_opened_file_inzip: boolean; { TRUE if a file in the zip is currently writ.}
    ci: curfile_info;              { info on the file currently writing }

    begin_pos:    longint;            { position of the beginning of the zipfile }
    number_entry: longint;
  end;
  zip_internal_ptr = ^zip_internal;

function allocate_new_datablock: linkedlist_datablock_internal_ptr;
var
  ldi: linkedlist_datablock_internal_ptr;
begin
  ldi := linkedlist_datablock_internal_ptr(GetMem(sizeof(linkedlist_datablock_internal)));
  if (ldi <> nil) then
  begin
    ldi^.next_datablock      := nil;
    ldi^.filled_in_this_block := 0;
    ldi^.avail_in_this_block := SIZEDATA_INDATABLOCK;
  end;
  allocate_new_datablock := ldi;
end;

procedure free_datablock(var ldi: linkedlist_datablock_internal_ptr);
var
  ldinext: linkedlist_datablock_internal_ptr;
begin
  while (ldi <> nil) do
  begin
    ldinext := ldi^.next_datablock;
    FreeMem(ldi);
    ldi := ldinext;
  end;
end;

procedure init_linkedlist(var ll: linkedlist_data);
begin
  ll.last_block  := nil;
  ll.first_block := nil;
end;

procedure free_linkedlist(var ll: linkedlist_data);
begin
  free_datablock(ll.first_block);
  ll.last_block  := nil;
  ll.first_block := nil;
end;

function add_data_in_datablock(ll: linkedlist_data_ptr; const buf: pointer; len: longint): longint;
var
  ldi: linkedlist_datablock_internal_ptr;
  from_copy: {const} Pbyte;
var
  copy_this: integer;
  i:   integer;
  to_copy: Pbyte;
begin
  if (ll = nil) then
  begin
    add_data_in_datablock := ZIP_INTERNALERROR;
    exit;
  end;

  if (ll^.last_block = nil) then
  begin
    ll^.last_block  := allocate_new_datablock;
    ll^.first_block := ll^.last_block;
    if (ll^.first_block = nil) then
    begin
      add_data_in_datablock := ZIP_INTERNALERROR;
      exit;
    end;
  end;

  ldi := ll^.last_block;
  from_copy := Pbyte(buf);

  while (len > 0) do
  begin
    if (ldi^.avail_in_this_block = 0) then
    begin
      ldi^.next_datablock := allocate_new_datablock;
      if (ldi^.next_datablock = nil) then
      begin
        add_data_in_datablock := ZIP_INTERNALERROR;
        exit;
      end;
      ldi := ldi^.next_datablock;
      ll^.last_block := ldi;
    end;

    if (ldi^.avail_in_this_block < len) then
      copy_this := integer(ldi^.avail_in_this_block)
    else
      copy_this := integer(len);

    to_copy := @(ldi^.Data[ldi^.filled_in_this_block]);

    for i := 0 to copy_this - 1 do
      Pbytearray(to_copy)^[i] := Pbytearray(from_copy)^[i];

    Inc(ldi^.filled_in_this_block, copy_this);
    Dec(ldi^.avail_in_this_block, copy_this);
    Inc(from_copy, copy_this);
    Dec(len, copy_this);
  end;
  add_data_in_datablock := ZIP_OK;
end;


function write_datablock(fout: FILEptr; ll: linkedlist_data_ptr): longint;
var
  ldi: linkedlist_datablock_internal_ptr;
begin
  ldi := ll^.first_block;
  while (ldi <> nil) do
  begin
    if (ldi^.filled_in_this_block > 0) then
      if (fwrite(@ldi^.Data, integer(ldi^.filled_in_this_block), 1, fout) <> 1) then
      begin
        write_datablock := ZIP_ERRNO;
        exit;
      end;
    ldi := ldi^.next_datablock;
  end;
  write_datablock := ZIP_OK;
end;

{**************************************************************************}

{ ===========================================================================
   Outputs a long in LSB order to the given file
   nbByte = 1, 2 or 4 (byte, short or long)  }

function ziplocal_putValue(afile: FILEptr; x: longint; nbByte: longint): longint;
var
  buf: array[0..4 - 1] of byte;
  n:   longint;
begin
  for n := 0 to nbByte - 1 do
  begin
    buf[n] := byte(x and $ff);
    x      := x shr 8;
  end;
  if (fwrite(@buf, nbByte, 1, afile) <> 1) then
    ziplocal_putValue := ZIP_ERRNO
  else
    ziplocal_putValue := ZIP_OK;
end;

procedure ziplocal_putValue_inmemory(dest: pointer; x: longint; nbByte: longint);
var
  buf: Pbytearray;
  n:   longint;
begin
  buf := Pbytearray(dest);
  for n := 0 to nbByte - 1 do
  begin
    buf^[n] := Byte(x and $ff);
    x := x shr 8;
  end;
end;

{**************************************************************************}


function ziplocal_TmzDateToDosDate(var ptm: tm_zip; dosDate: longint): longint;
var
  year: longint;
begin
  year := longint(ptm.tm_year);
  if (year > 1980) then
    Dec(year, 1980)
  else
  if (year > 80) then
    Dec(year, 80);
  ziplocal_TmzDateToDosDate := longint(
    ((ptm.tm_mday) + (32 * (ptm.tm_mon + 1)) + (512 * year)) shl 16) or
    ((ptm.tm_sec div 2) + (32 * ptm.tm_min) + (2048 * longint(ptm.tm_hour)));
end;


{**************************************************************************}

function zipOpen(const pathname: PAnsiChar; append: longint): zipFile; {ZEXPORT}
var
  ziinit: zip_internal;
  zi:     zip_internal_ptr;
begin
  if (append = 0) then
    ziinit.filezip := fopen(pathname, fopenwrite)
  else
    ziinit.filezip := fopen(pathname, fappendwrite);

  if (ziinit.filezip = nil) then
  begin
    zipOpen := nil;
    exit;
  end;
  ziinit.begin_pos    := ftell(ziinit.filezip);
  ziinit.in_opened_file_inzip := False;
  ziinit.ci.stream_initialised := False;
  ziinit.number_entry := 0;
  init_linkedlist(ziinit.central_dir);

  zi := zip_internal_ptr(AllocMem(sizeof(zip_internal)));
  if (zi = nil) then
  begin
    fclose(ziinit.filezip);
    zipOpen := nil;
    exit;
  end;

  zi^     := ziinit;
  zipOpen := zipFile(zi);
end;

function zipOpenNewFileInZip(afile: zipFile;
  {const} filename: PAnsiChar; const zipfi: zip_fileinfo_ptr; const extrafield_local: pointer; size_extrafield_local: integer; const extrafield_global: pointer; size_extrafield_global: integer; const comment: PAnsiChar; method: longint; level: longint): longint; {ZEXPORT}
var
  zi:  zip_internal_ptr;
  size_filename: integer;
  size_comment: integer;
  i:   integer;
  err: longint;
begin
  err := ZIP_OK;
  if (afile = nil) then
  begin
    zipOpenNewFileInZip := ZIP_PARAMERROR;
    exit;
  end;
  if ((method <> 0) and (method <> Z_DEFLATED)) then
  begin
    zipOpenNewFileInZip := ZIP_PARAMERROR;
    exit;
  end;

  zi := zip_internal_ptr(afile);

  if (zi^.in_opened_file_inzip = True) then
  begin
    err := zipCloseFileInZip(afile);
    if (err <> ZIP_OK) then
    begin
      zipOpenNewFileInZip := err;
      exit;
    end;
  end;

  if (filename = nil) then
    filename := '-';

  if (comment = nil) then
    size_comment := 0
  else
    size_comment := strlen(comment);

  size_filename := strlen(filename);

  if (zipfi = nil) then
    zi^.ci.dosDate := 0
  else
  if (zipfi^.dosDate <> 0) then
    zi^.ci.dosDate := zipfi^.dosDate
  else
    zi^.ci.dosDate := ziplocal_TmzDateToDosDate(zipfi^.tmz_date, zipfi^.dosDate);
  zi^.ci.flag := 0;
  if ((level = 8) or (level = 9)) then
    zi^.ci.flag := zi^.ci.flag or 2;
  if ((level = 2)) then
    zi^.ci.flag := zi^.ci.flag or 4;
  if ((level = 1)) then
    zi^.ci.flag := zi^.ci.flag or 6;

  zi^.ci.crc32  := 0;
  zi^.ci.method := method;
  zi^.ci.stream_initialised := False;
  zi^.ci.pos_in_buffered_data := 0;
  zi^.ci.pos_local_header := ftell(zi^.filezip);
  zi^.ci.size_centralheader := SIZECENTRALHEADER + size_filename +
    size_extrafield_global + size_comment;
  zi^.ci.central_header := PAnsiChar(AllocMem(integer(zi^.ci.size_centralheader)));

  ziplocal_putValue_inmemory(zi^.ci.central_header, longint(CENTRALHEADERMAGIC), 4);
  { version info }
  ziplocal_putValue_inmemory(zi^.ci.central_header + 4, longint(VERSIONMADEBY), 2);
  ziplocal_putValue_inmemory(zi^.ci.central_header + 6, longint(20), 2);
  ziplocal_putValue_inmemory(zi^.ci.central_header + 8, longint(zi^.ci.flag), 2);
  ziplocal_putValue_inmemory(zi^.ci.central_header + 10, longint(zi^.ci.method), 2);
  ziplocal_putValue_inmemory(zi^.ci.central_header + 12, longint(zi^.ci.dosDate), 4);
  ziplocal_putValue_inmemory(zi^.ci.central_header + 16, longint(0), 4); {crc}
  ziplocal_putValue_inmemory(zi^.ci.central_header + 20, longint(0), 4); {compr size}
  ziplocal_putValue_inmemory(zi^.ci.central_header + 24, longint(0), 4); {uncompr size}
  ziplocal_putValue_inmemory(zi^.ci.central_header + 28, longint(size_filename), 2);
  ziplocal_putValue_inmemory(zi^.ci.central_header + 30, longint(size_extrafield_global), 2);
  ziplocal_putValue_inmemory(zi^.ci.central_header + 32, longint(size_comment), 2);
  ziplocal_putValue_inmemory(zi^.ci.central_header + 34, longint(0), 2); {disk nm start}

  if (zipfi = nil) then
    ziplocal_putValue_inmemory(zi^.ci.central_header + 36, longint(0), 2)
  else
    ziplocal_putValue_inmemory(zi^.ci.central_header + 36, longint(zipfi^.internal_fa), 2);

  if (zipfi = nil) then
    ziplocal_putValue_inmemory(zi^.ci.central_header + 38, longint(0), 4)
  else
    ziplocal_putValue_inmemory(zi^.ci.central_header + 38, longint(zipfi^.external_fa), 4);

  ziplocal_putValue_inmemory(zi^.ci.central_header + 42, longint(zi^.ci.pos_local_header), 4);

  i := 0;
  while (i < size_filename) do
  begin
    (zi^.ci.central_header +SIZECENTRALHEADER + i)^ := (filename + i)^;
    Inc(i);
  end;

  i := 0;
  while (i < size_extrafield_global) do
  begin
    (zi^.ci.central_header +SIZECENTRALHEADER + size_filename + i)^ :=
      ({const} PAnsiChar(extrafield_global) + i)^;
    Inc(i);
  end;

  i := 0;
  while (i < size_comment) do
  begin
    (zi^.ci.central_header +SIZECENTRALHEADER + size_filename + size_extrafield_global + i)^ := (filename + i)^;
    Inc(i);
  end;
  if (zi^.ci.central_header = nil) then
  begin
    zipOpenNewFileInZip := ZIP_INTERNALERROR;
    exit;
  end;

  { write the local header }
  err := ziplocal_putValue(zi^.filezip, longint(LOCALHEADERMAGIC), 4);

  if (err = ZIP_OK) then
    err := ziplocal_putValue(zi^.filezip, longint(20), 2); { version needed to extract }
  if (err = ZIP_OK) then
    err := ziplocal_putValue(zi^.filezip, longint(zi^.ci.flag), 2);

  if (err = ZIP_OK) then
    err := ziplocal_putValue(zi^.filezip, longint(zi^.ci.method), 2);

  if (err = ZIP_OK) then
    err := ziplocal_putValue(zi^.filezip, longint(zi^.ci.dosDate), 4);

  if (err = ZIP_OK) then
    err := ziplocal_putValue(zi^.filezip, longint(0), 4); { crc 32, unknown }
  if (err = ZIP_OK) then
    err := ziplocal_putValue(zi^.filezip, longint(0), 4); { compressed size, unknown }
  if (err = ZIP_OK) then
    err := ziplocal_putValue(zi^.filezip, longint(0), 4); { uncompressed size, unknown }

  if (err = ZIP_OK) then
    err := ziplocal_putValue(zi^.filezip, longint(size_filename), 2);

  if (err = ZIP_OK) then
    err := ziplocal_putValue(zi^.filezip, longint(size_extrafield_local), 2);

  if ((err = ZIP_OK) and (size_filename > 0)) then
    if (fwrite(filename, integer(size_filename), 1, zi^.filezip) <> 1) then
      err := ZIP_ERRNO;

  if ((err = ZIP_OK) and (size_extrafield_local > 0)) then
    if (fwrite(extrafield_local, integer(size_extrafield_local), 1, zi^.filezip) <> 1) then
      err := ZIP_ERRNO;

  zi^.ci.stream.avail_in  := integer(0);
  zi^.ci.stream.avail_out := integer(Z_BUFSIZE);
  zi^.ci.stream.next_out  := Pbyte(@zi^.ci.buffered_data);
  zi^.ci.stream.total_in  := 0;
  zi^.ci.stream.total_out := 0;

  if ((err = ZIP_OK) and (zi^.ci.method = Z_DEFLATED)) then
  begin
    err := deflateInit2(zi^.ci.stream, level,
      Z_DEFLATED, -MAX_WBITS, DEF_MEM_LEVEL, 0);

    if (err = Z_OK) then
      zi^.ci.stream_initialised := True;
  end;

  if (err = Z_OK) then
    zi^.in_opened_file_inzip := True;
  zipOpenNewFileInZip := err;
end;

function zipWriteInFileInZip(afile: zipFile; const buf: pointer; len: cardinal): longint; {ZEXPORT}
var
  zi:  zip_internal_ptr;
  err: longint;
var
  uTotalOutBefore: longint;
var
  copy_this, i: integer;
begin
  err := ZIP_OK;

  if (afile = nil) then
  begin
    zipWriteInFileInZip := ZIP_PARAMERROR;
    exit;
  end;
  zi := zip_internal_ptr(afile);

  if (zi^.in_opened_file_inzip = False) then
  begin
    zipWriteInFileInZip := ZIP_PARAMERROR;
    exit;
  end;

  zi^.ci.stream.next_in := buf;
  zi^.ci.stream.avail_in := len;
  zi^.ci.crc32 := CRC32Buffer(zi^.ci.crc32, buf, len);

  while ((err = ZIP_OK) and (zi^.ci.stream.avail_in > 0)) do
  begin
    if (zi^.ci.stream.avail_out = 0) then
    begin
      if fwrite(@zi^.ci.buffered_data, integer(zi^.ci.pos_in_buffered_data), 1, zi^.filezip) <> 1 then
        err := ZIP_ERRNO;
      zi^.ci.pos_in_buffered_data := 0;
      zi^.ci.stream.avail_out := integer(Z_BUFSIZE);
      zi^.ci.stream.next_out  := Pbyte(@zi^.ci.buffered_data);
    end;

    if (zi^.ci.method = Z_DEFLATED) then
    begin
      uTotalOutBefore := zi^.ci.stream.total_out;
      err := deflate(zi^.ci.stream, Z_NO_FLUSH);
      Inc(zi^.ci.pos_in_buffered_data, integer(zi^.ci.stream.total_out - uTotalOutBefore));
    end
    else
    begin
      if (zi^.ci.stream.avail_in < zi^.ci.stream.avail_out) then
        copy_this := zi^.ci.stream.avail_in
      else
        copy_this := zi^.ci.stream.avail_out;

      for i := 0 to copy_this - 1 do
        (PAnsiChar(zi^.ci.stream.next_out) +i)^ :=
          ( {const} PAnsiChar(zi^.ci.stream.next_in) + i)^;


      Dec(zi^.ci.stream.avail_in, copy_this);
      Dec(zi^.ci.stream.avail_out, copy_this);
      Inc(zi^.ci.stream.next_in, copy_this);
      Inc(zi^.ci.stream.next_out, copy_this);
      Inc(zi^.ci.stream.total_in, copy_this);
      Inc(zi^.ci.stream.total_out, copy_this);
      Inc(zi^.ci.pos_in_buffered_data, copy_this);
    end;
  end;

  zipWriteInFileInZip := 0;
end;

function zipCloseFileInZip(afile: zipFile): longint; {ZEXPORT}
var
  zi:  zip_internal_ptr;
  err: longint;
var
  uTotalOutBefore: longint;
var
  cur_pos_inzip: longint;
begin
  err := ZIP_OK;

  if (afile = nil) then
  begin
    zipCloseFileInZip := ZIP_PARAMERROR;
    exit;
  end;
  zi := zip_internal_ptr(afile);

  if (zi^.in_opened_file_inzip = False) then
  begin
    zipCloseFileInZip := ZIP_PARAMERROR;
    exit;
  end;
  zi^.ci.stream.avail_in := 0;

  if (zi^.ci.method = Z_DEFLATED) then
    while (err = ZIP_OK) do
    begin
      if (zi^.ci.stream.avail_out = 0) then
      begin
        if fwrite(@zi^.ci.buffered_data, integer(zi^.ci.pos_in_buffered_data), 1, zi^.filezip) <> 1 then
          err := ZIP_ERRNO;
        zi^.ci.pos_in_buffered_data := 0;
        zi^.ci.stream.avail_out := integer(Z_BUFSIZE);
        zi^.ci.stream.next_out  := Pbyte(@zi^.ci.buffered_data);
      end;
      uTotalOutBefore := zi^.ci.stream.total_out;
      err := deflate(zi^.ci.stream, Z_FINISH);
      Inc(zi^.ci.pos_in_buffered_data, integer(zi^.ci.stream.total_out - uTotalOutBefore));
    end;

  if (err = Z_STREAM_END) then
    err := ZIP_OK; { this is normal }

  if (zi^.ci.pos_in_buffered_data > 0) and (err = ZIP_OK) then
    if fwrite(@zi^.ci.buffered_data, integer(zi^.ci.pos_in_buffered_data), 1, zi^.filezip) <> 1 then
      err := ZIP_ERRNO;

  if ((zi^.ci.method = Z_DEFLATED) and (err = ZIP_OK)) then
  begin
    err := deflateEnd(zi^.ci.stream);
    zi^.ci.stream_initialised := False;
  end;

  ziplocal_putValue_inmemory(zi^.ci.central_header + 16, longint(zi^.ci.crc32), 4); {crc}
  ziplocal_putValue_inmemory(zi^.ci.central_header + 20, longint(zi^.ci.stream.total_out), 4); {compr size}
  ziplocal_putValue_inmemory(zi^.ci.central_header + 24, longint(zi^.ci.stream.total_in), 4); {uncompr size}

  if (err = ZIP_OK) then
    err := add_data_in_datablock(@zi^.central_dir, zi^.ci.central_header, longint(zi^.ci.size_centralheader));

  FreeMem(zi^.ci.central_header);
  zi^.ci.central_header := nil;

  if (err = ZIP_OK) then
  begin
    cur_pos_inzip := ftell(zi^.filezip);
    if fseek(zi^.filezip, zi^.ci.pos_local_header + 14, ZipSeekSet) <> 0 then
      err := ZIP_ERRNO;

    if (err = ZIP_OK) then
      err := ziplocal_putValue(zi^.filezip, longint(zi^.ci.crc32), 4); { crc 32, unknown }

    if (err = ZIP_OK) then { compressed size, unknown }
      err := ziplocal_putValue(zi^.filezip, longint(zi^.ci.stream.total_out), 4);

    if (err = ZIP_OK) then { uncompressed size, unknown }
      err := ziplocal_putValue(zi^.filezip, longint(zi^.ci.stream.total_in), 4);

    if fseek(zi^.filezip, cur_pos_inzip, ZipSeekSet) <> 0 then
      err := ZIP_ERRNO;
  end;

  Inc(zi^.number_entry);
  zi^.in_opened_file_inzip := False;

  zipCloseFileInZip := err;
end;

function zipClose(afile: zipFile; const global_comment: PAnsiChar): longint; {ZEXPORT}
var
  zi:  zip_internal_ptr;
  err: longint;
  size_centraldir: longint;
  centraldir_pos_inzip: longint;
  size_global_comment: integer;
var
  ldi: linkedlist_datablock_internal_ptr;
begin
  err := 0;
  size_centraldir := 0;
  if (afile = nil) then
  begin
    zipClose := ZIP_PARAMERROR;
    exit;
  end;
  zi := zip_internal_ptr(afile);

  if (zi^.in_opened_file_inzip = True) then
    err := zipCloseFileInZip(afile);

  if (global_comment = nil) then
    size_global_comment := 0
  else
    size_global_comment := strlen(global_comment);

  centraldir_pos_inzip := ftell(zi^.filezip);
  if (err = ZIP_OK) then
  begin
    ldi := zi^.central_dir.first_block;
    while (ldi <> nil) do
    begin
      if ((err = ZIP_OK) and (ldi^.filled_in_this_block > 0)) then
        if fwrite(@ldi^.Data, integer(ldi^.filled_in_this_block), 1, zi^.filezip) <> 1 then
          err := ZIP_ERRNO;

      Inc(size_centraldir, ldi^.filled_in_this_block);
      ldi := ldi^.next_datablock;
    end;
  end;
  free_datablock(zi^.central_dir.first_block);

  if (err = ZIP_OK) then { Magic End }
    err := ziplocal_putValue(zi^.filezip, longint(ENDHEADERMAGIC), 4);

  if (err = ZIP_OK) then { number of this disk }
    err := ziplocal_putValue(zi^.filezip, longint(0), 2);

  if (err = ZIP_OK) then { number of the disk with the start of the central directory }
    err := ziplocal_putValue(zi^.filezip, longint(0), 2);

  if (err = ZIP_OK) then { total number of entries in the central dir on this disk }
    err := ziplocal_putValue(zi^.filezip, longint(zi^.number_entry), 2);

  if (err = ZIP_OK) then { total number of entries in the central dir }
    err := ziplocal_putValue(zi^.filezip, longint(zi^.number_entry), 2);

  if (err = ZIP_OK) then { size of the central directory }
    err := ziplocal_putValue(zi^.filezip, longint(size_centraldir), 4);

  if (err = ZIP_OK) then { offset of start of central directory with respect to the
                          starting disk number }
    err := ziplocal_putValue(zi^.filezip, longint(centraldir_pos_inzip), 4);

  if (err = ZIP_OK) then { zipfile comment length }
    err := ziplocal_putValue(zi^.filezip, longint(size_global_comment), 2);

  if ((err = ZIP_OK) and (size_global_comment > 0)) then
    if fwrite(global_comment, integer(size_global_comment), 1, zi^.filezip) <> 1 then
      err := ZIP_ERRNO;
  fclose(zi^.filezip);
  FreeMem(zi);

  zipClose := err;
end;


{$pop}

{ unzip implementation }
{$push}{$H-}






{$ifdef unix and not def (CASESENSITIVITYDEFAULT_YES) and \
                      !defined(CASESENSITIVITYDEFAULT_NO)}
{$define CASESENSITIVITYDEFAULT_NO}
{$endif}


const
  UNZ_BUFSIZE = Z_BUFSIZE;
  UNZ_MAXFILENAMEINZIP = Z_MAXFILENAMEINZIP;

const
  unz_copyright: PAnsiChar = ' unzip 0.15 Copyright 1998 Gilles Vollant ';

{ unz_file_info_internal contain internal info about a file in zipfile }
type
  unz_file_info_internal = record
    offset_curfile: longint; { relative offset of local header 4 bytes }
  end;
  unz_file_info_internal_ptr = ^unz_file_info_internal;


{ file_in_zip_read_info_s contain internal information about a file
  in zipfile, when reading and decompress it }
type
  file_in_zip_read_info_s = record
    read_buffer: PAnsiChar;       { internal buffer for compressed data }
    stream:      z_stream;    { zLib stream structure for inflate }

    pos_in_zipfile:     longint;       { position in byte on the zipfile, for fseek}
    stream_initialised: boolean;     { flag set if stream structure is initialised}

    offset_local_extrafield: longint;   { offset of the local extra field }
    size_local_extrafield:   smallint;    { size of the local extra field }
    pos_local_extrafield:    longint;   { position in the local extra field in read}

    crc32:      cardinal;               { crc32 of all data uncompressed }
    crc32_wait: cardinal;               { crc32 we must obtain after decompress all }
    rest_read_compressed: longint;      { number of byte to be decompressed }
    rest_read_uncompressed: longint;    {number of byte to be obtained after decomp}
    afile:      FILEptr;              { io structure of the zipfile }
    compression_method: longint;        { compression method (0=store) }
    byte_before_the_zipfile: longint;   { byte before the zipfile, (>0 for sfx) }
  end;
  file_in_zip_read_info_s_ptr = ^file_in_zip_read_info_s;


{ unz_s contain internal information about the zipfile }
type
  unz_s = record
    afile: FILEptr;                 { io structure of the zipfile }
    gi:    unz_global_info;         { public global information }
    byte_before_the_zipfile: longint; { byte before the zipfile, (>0 for sfx)}
    num_file: longint;                { number of the current file in the zipfile}
    pos_in_central_dir: longint;      { pos of the current file in the central dir}
    current_file_ok: boolean;       { flag about the usability of the current file}
    central_pos: longint;             { position of the beginning of the central dir}

    size_central_dir:   longint;     { size of the central directory  }
    offset_central_dir: longint;   { offset of start of central directory with
                                   respect to the starting disk number }

    cur_file_info:     unz_file_info; { public info about the current file in zip}
    cur_file_info_internal: unz_file_info_internal; { private info about it}
    pfile_in_zip_read: file_in_zip_read_info_s_ptr; { structure about the current
                                      file if we are decompressing it }
  end;
  unz_s_ptr = ^unz_s;


{ ===========================================================================
  Read a byte from a gz_stream; update next_in and avail_in. Return EOF
  for end of file.
  IN assertion: the stream s has been successfully opened for reading. }


function unzlocal_getByte(fin: FILEptr; var pi: longint): longint;
var
  c:   byte;
  err: longint;
begin
  err := fread(@c, 1, 1, fin);

  if (err = 1) then
  begin
    pi := longint(c);
    unzlocal_getByte := UNZ_OK;
    {exit;}
  end
  else
  if feof(fin) = 1 then    {if ferror(fin) then}
    unzlocal_getByte := UNZ_ERRNO
  else
    unzlocal_getByte := UNZ_EOF{exit;};
end;


{ ===========================================================================
   Reads a long in LSB order from the given gz_stream. Sets }

function unzlocal_getShort(fin: FILEptr; var pX: longint): longint;
var
  x:   longint;
  i:   longint;
  err: longint;
begin
  err := unzlocal_getByte(fin, i);
  x   := longint(i);

  if (err = UNZ_OK) then
    err := unzlocal_getByte(fin, i);
  Inc(x, longint(i) shl 8);

  if (err = UNZ_OK) then
    pX := x
  else
    pX := 0;
  unzlocal_getShort := err;
end;

function unzlocal_getLong(fin: FILEptr; var pX: longint): longint;
var
  x:   longint;
  i:   longint;
  err: longint;
begin
  err := unzlocal_getByte(fin, i);
  x   := longint(i);

  if (err = UNZ_OK) then
    err := unzlocal_getByte(fin, i);
  Inc(x, longint(i) shl 8);

  if (err = UNZ_OK) then
    err := unzlocal_getByte(fin, i);
  Inc(x, longint(i) shl 16);

  if (err = UNZ_OK) then
    err := unzlocal_getByte(fin, i);
  Inc(x, longint(i) shl 24);

  if (err = UNZ_OK) then
    pX := x
  else
    pX := 0;
  unzlocal_getLong := err;
end;


{ My own strcmpi / strcasecmp }
function strcmpcasenosensitive_internal(fileName1: PAnsiChar; fileName2: PAnsiChar): longint;
var
  c1, c2: AnsiChar;
begin
  repeat
    c1 := fileName1^;
    Inc(fileName1);
    c2 := fileName2^;
    Inc(fileName2);
    if (c1 >= 'a') and (c1 <= 'z') then
      Dec(c1, $20);
    if (c2 >= 'a') and (c2 <= 'z') then
      Dec(c2, $20);
    if (c1 = #0) then
    begin
      if c2 = #0 then
        strcmpcasenosensitive_internal := 0
      else
        strcmpcasenosensitive_internal := -1;
      exit;
    end;
    if (c2 = #0) then
    begin
      strcmpcasenosensitive_internal := 1;
      exit;
    end;
    if (c1 < c2) then
    begin
      strcmpcasenosensitive_internal := -1;
      exit;
    end;
    if (c1 > c2) then
    begin
      strcmpcasenosensitive_internal := 1;
      exit;
    end;
  until False;
end;


const
  CASESENSITIVITYDEFAULTVALUE = 2;

function unzStringFileNameCompare(const fileName1: PAnsiChar; const fileName2: PAnsiChar; iCaseSensitivity: longint): longint; { ZEXPORT }
{ Compare two filename (fileName1,fileName2).
  If iCaseSensitivity = 1 (1=true),
    comparison is case sensitive (like strcmp)
  If iCaseSensitivity = 2 (0=false),
    comparison is not case sensitive (like strcmpi or strcasecmp)
  If iCaseSensitivity = 0, case sensitivity is default of your
    operating system like 1 on Unix, 2 on Windows)
}
begin
  if (iCaseSensitivity = 0) then
    iCaseSensitivity := CASESENSITIVITYDEFAULTVALUE;

  if (iCaseSensitivity = 1) then
  begin
    unzStringFileNameCompare := strComp(fileName1, fileName2);
    exit;
  end;

  unzStringFileNameCompare := strcmpcasenosensitive_internal(fileName1, fileName2);
end;

const
  BUFREADCOMMENT = $400;

{ Locate the Central directory of a zipfile (at the end, just before
  the global comment) }

function unzlocal_SearchCentralDir(fin: FILEptr): longint;
var
  buf: Pbytearray;
  uSizeFile: longint;
  uBackRead: longint;
  uMaxBack: longint;
  uPosFound: longint;
var
  uReadSize, uReadPos: longint;
  i: longint;
begin
  uMaxBack  := $ffff; { maximum size of global comment }
  uPosFound := 0;

  if (fseek(fin, 0, ZipSeekEnd) <> 0) then
  begin
    unzlocal_SearchCentralDir := 0;
    exit;
  end;

  uSizeFile := ftell(fin);

  if (uMaxBack > uSizeFile) then
    uMaxBack := uSizeFile;

  buf := Pbytearray(AllocMem(BUFREADCOMMENT + 4));
  if (buf = nil) then
  begin
    unzlocal_SearchCentralDir := 0;
    exit;
  end;

  uBackRead := 4;
  while (uBackRead < uMaxBack) do
  begin

    if (uBackRead + BUFREADCOMMENT > uMaxBack) then
      uBackRead := uMaxBack
    else
      Inc(uBackRead, BUFREADCOMMENT);
    uReadPos := uSizeFile - uBackRead;

    if ((BUFREADCOMMENT + 4) < (uSizeFile - uReadPos)) then
      uReadSize := (BUFREADCOMMENT + 4)
    else
      uReadSize := (uSizeFile - uReadPos);

    if fseek(fin, uReadPos, ZipSeekSet) <> 0 then
      break;

    if fread(buf, uReadSize, 1, fin) <> 1 then
      break;

    i := uReadSize - 3;
    while (i > 0) do
    begin
      Dec(i);
      if (buf^[i] = $50) and (buf^[i + 1] = $4b) and    { ENDHEADERMAGIC }
        (buf^[i + 2] = $05) and (buf^[i + 3] = $06) then
      begin
        uPosFound := uReadPos + i;
        break;
      end;
    end;

    if (uPosFound <> 0) then
      break;
  end;
  FreeMem(buf);
  unzlocal_SearchCentralDir := uPosFound;
end;


{ Open a Zip file. path contain the full pathname (by example,
  on a Windows NT computer "c:\\zlib\\zlib111.zip" or on an Unix computer
  "zlib/zlib111.zip".
  If the zipfile cannot be opened (file don't exist or in not valid), the
  return value is NIL.
  Else, the return value is a unzFile Handle, usable with other function
     of this unzip package.
}

function unzOpen(const path: PAnsiChar): unzFile; { ZEXPORT }
var
  us:  unz_s;
  s:   unz_s_ptr;
  central_pos, uL: longint;
  fin: FILEptr;

  number_disk:     longint; { number of the current dist, used for spanning ZIP,
                         unsupported, always 0 }
  number_disk_with_CD: longint; { number the the disk with central dir,
                        used for spanning ZIP, unsupported, always 0 }
  number_entry_CD: longint; { total number of entries in the central dir
                                 (same than number_entry on nospan) }

  err: longint;
begin
  err := UNZ_OK;

  if (unz_copyright[0] <> ' ') then
  begin
    unzOpen := nil;
    exit;
  end;

  fin := fopen(path, fopenread);
  if (fin = nil) then
  begin
    unzOpen := nil;
    exit;
  end;

  central_pos := unzlocal_SearchCentralDir(fin);
  if (central_pos = 0) then
    err := UNZ_ERRNO;

  if (fseek(fin, central_pos, ZipSeekSet) <> 0) then
    err := UNZ_ERRNO;

  { the signature, already checked }
  if (unzlocal_getLong(fin, uL) <> UNZ_OK) then
    err := UNZ_ERRNO;

  { number of this disk }
  if (unzlocal_getShort(fin, number_disk) <> UNZ_OK) then
    err := UNZ_ERRNO;

  { number of the disk with the start of the central directory }
  if (unzlocal_getShort(fin, number_disk_with_CD) <> UNZ_OK) then
    err := UNZ_ERRNO;

  { total number of entries in the central dir on this disk }
  if (unzlocal_getShort(fin, us.gi.number_entry) <> UNZ_OK) then
    err := UNZ_ERRNO;

  { total number of entries in the central dir }
  if (unzlocal_getShort(fin, number_entry_CD) <> UNZ_OK) then
    err := UNZ_ERRNO;

  if ((number_entry_CD <> us.gi.number_entry) or
    (number_disk_with_CD <> 0) or
    (number_disk <> 0)) then
    err := UNZ_BADZIPFILE;

  { size of the central directory }
  if (unzlocal_getLong(fin, us.size_central_dir) <> UNZ_OK) then
    err := UNZ_ERRNO;

  { offset of start of central directory with respect to the
        starting disk number }
  if (unzlocal_getLong(fin, us.offset_central_dir) <> UNZ_OK) then
    err := UNZ_ERRNO;

  { zipfile comment length }
  if (unzlocal_getShort(fin, us.gi.size_comment) <> UNZ_OK) then
    err := UNZ_ERRNO;

  if ((central_pos < us.offset_central_dir + us.size_central_dir) and
    (err = UNZ_OK)) then
    err := UNZ_BADZIPFILE;

  if (err <> UNZ_OK) then
  begin
    fclose(fin);
    unzOpen := nil;
    exit;
  end;

  us.afile := fin;
  us.byte_before_the_zipfile := central_pos -
    (us.offset_central_dir + us.size_central_dir);
  us.central_pos := central_pos;
  us.pfile_in_zip_read := nil;

  s  := unz_s_ptr(AllocMem(sizeof(unz_s)));
  s^ := us;
  unzGoToFirstFile(unzFile(s));
  unzOpen := unzFile(s);
end;


{ Close a ZipFile opened with unzipOpen.
  If there are files inside the .Zip opened with unzOpenCurrentFile()
  (see later), these files MUST be closed with unzipCloseCurrentFile()
  before a call unzipClose.
  return UNZ_OK if there is no problem. }

function unzClose(afile: unzFile): longint; { ZEXPORT }
var
  s: unz_s_ptr;
begin
  if (afile = nil) then
  begin
    unzClose := UNZ_PARAMERROR;
    exit;
  end;
  s := unz_s_ptr(afile);

  if (s^.pfile_in_zip_read <> nil) then
    unzCloseCurrentFile(afile);

  fclose(s^.afile);
  FreeMem(s);
  unzClose := UNZ_OK;
end;

{ Write info about the ZipFile in the pglobal_info structure.
  No preparation of the structure is needed
  return UNZ_OK if there is no problem. }

function unzGetGlobalInfo(afile: unzFile; var pglobal_info: unz_global_info): longint; { ZEXPORT }
var
  s: unz_s_ptr;
begin
  if (afile = nil) then
  begin
    unzGetGlobalInfo := UNZ_PARAMERROR;
    exit;
  end;
  s := unz_s_ptr(afile);
  pglobal_info := s^.gi;
  unzGetGlobalInfo := UNZ_OK;
end;


{ Translate date/time from Dos format to tm_unz (more easily readable) }
procedure unzlocal_DosDateToTmuDate(ulDosDate: longint; var ptm: tm_unz);
var
  uDate: longint;
begin
  uDate      := longint(ulDosDate shr 16);
  ptm.tm_mday := integer(uDate and $1f);
  ptm.tm_mon := integer((((uDate) and $1E0) div $20) - 1);
  ptm.tm_year := integer(((uDate and $0FE00) div $0200) + 1980);

  ptm.tm_hour := integer((ulDosDate and $F800) div $800);
  ptm.tm_min  := integer((ulDosDate and $7E0) div $20);
  ptm.tm_sec  := integer(2 * (ulDosDate and $1f));
end;

{ Get Info about the current file in the zipfile, with internal only info }
function unzlocal_GetCurrentFileInfoInternal(afile: unzFile; pfile_info: unz_file_info_ptr; pfile_info_internal: unz_file_info_internal_ptr; szFileName: PAnsiChar; fileNameBufferSize: longint; extraField: pointer; extraFieldBufferSize: longint; szComment: PAnsiChar; commentBufferSize: longint): longint;
var
  lCRCBytes: LongInt;
  s:      unz_s_ptr;
  file_info: unz_file_info;
  file_info_internal: unz_file_info_internal;
  err:    longint;
  uMagic: longint;
  lSeek:  longint;
var
  uSizeRead: longint;
begin
  err   := UNZ_OK;
  lSeek := 0;
  if (afile = nil) then
  begin
    unzlocal_GetCurrentFileInfoInternal := UNZ_PARAMERROR;
    exit;
  end;
  s := unz_s_ptr(afile);

  if (fseek(s^.afile,
    s^.pos_in_central_dir + s^.byte_before_the_zipfile, ZipSeekSet) <> 0) then
    err := UNZ_ERRNO;

  { we check the magic }
  if (err = UNZ_OK) then
    if (unzlocal_getLong(s^.afile, uMagic) <> UNZ_OK) then
      err := UNZ_ERRNO
    else
    if (uMagic <> CENTRALHEADERMAGIC) then
      err := UNZ_BADZIPFILE;

  if (unzlocal_getShort(s^.afile, file_info.version) <> UNZ_OK) then
    err := UNZ_ERRNO;

  if (unzlocal_getShort(s^.afile, file_info.version_needed) <> UNZ_OK) then
    err := UNZ_ERRNO;

  if (unzlocal_getShort(s^.afile, file_info.flag) <> UNZ_OK) then
    err := UNZ_ERRNO;

  if (unzlocal_getShort(s^.afile, file_info.compression_method) <> UNZ_OK) then
    err := UNZ_ERRNO;

  if (unzlocal_getLong(s^.afile, file_info.dosDate) <> UNZ_OK) then
    err := UNZ_ERRNO;

  unzlocal_DosDateToTmuDate(file_info.dosDate, file_info.tmu_date);

  if (unzlocal_getLong(s^.afile, lCRCBytes) <> UNZ_OK) then
    err := UNZ_ERRNO;
  Move(lCRCBytes, file_info.crc, SizeOf(file_info.crc));

  if (unzlocal_getLong(s^.afile, file_info.compressed_size) <> UNZ_OK) then
    err := UNZ_ERRNO;

  if (unzlocal_getLong(s^.afile, file_info.uncompressed_size) <> UNZ_OK) then
    err := UNZ_ERRNO;

  if (unzlocal_getShort(s^.afile, file_info.size_filename) <> UNZ_OK) then
    err := UNZ_ERRNO;

  if (unzlocal_getShort(s^.afile, file_info.size_file_extra) <> UNZ_OK) then
    err := UNZ_ERRNO;

  if (unzlocal_getShort(s^.afile, file_info.size_file_comment) <> UNZ_OK) then
    err := UNZ_ERRNO;

  if (unzlocal_getShort(s^.afile, file_info.disk_num_start) <> UNZ_OK) then
    err := UNZ_ERRNO;

  if (unzlocal_getShort(s^.afile, file_info.internal_fa) <> UNZ_OK) then
    err := UNZ_ERRNO;

  if (unzlocal_getLong(s^.afile, file_info.external_fa) <> UNZ_OK) then
    err := UNZ_ERRNO;

  if (unzlocal_getLong(s^.afile, file_info_internal.offset_curfile) <> UNZ_OK) then
    err := UNZ_ERRNO;

  Inc(lSeek, file_info.size_filename);
  if ((err = UNZ_OK) and (szFileName <> nil)) then
  begin
    if (file_info.size_filename < fileNameBufferSize) then
    begin
      (szFileName +file_info.size_filename)^ := #0;
      uSizeRead := file_info.size_filename;
    end
    else
      uSizeRead := fileNameBufferSize;

    if (file_info.size_filename > 0) and (fileNameBufferSize > 0) then
      if fread(szFileName, uSizeRead, 1, s^.afile) <> 1 then
        err := UNZ_ERRNO;
    Dec(lSeek, uSizeRead);
  end;

  if ((err = UNZ_OK) and (extraField <> nil)) then
  begin
    if (file_info.size_file_extra < extraFieldBufferSize) then
      uSizeRead := file_info.size_file_extra
    else
      uSizeRead := extraFieldBufferSize;

    if (lSeek <> 0) then
      if (fseek(s^.afile, lSeek, ZipSeekCur) = 0) then
        lSeek := 0
      else
        err   := UNZ_ERRNO;

    if ((file_info.size_file_extra > 0) and (extraFieldBufferSize > 0)) then
      if fread(extraField, uSizeRead, 1, s^.afile) <> 1 then
        err := UNZ_ERRNO;
    Inc(lSeek, file_info.size_file_extra - uSizeRead);
  end
  else
    Inc(lSeek, file_info.size_file_extra);

  if ((err = UNZ_OK) and (szComment <> nil)) then
  begin
    if (file_info.size_file_comment < commentBufferSize) then
    begin
      (szComment +file_info.size_file_comment)^ := #0;
      uSizeRead := file_info.size_file_comment;
    end
    else
      uSizeRead := commentBufferSize;

    if (lSeek <> 0) then
      if (fseek(s^.afile, lSeek, ZipSeekCur) = 0) then
        lSeek := 0
      else
        err   := UNZ_ERRNO;
    if ((file_info.size_file_comment > 0) and (commentBufferSize > 0)) then
      if fread(szComment, uSizeRead, 1, s^.afile) <> 1 then
        err := UNZ_ERRNO;
    Inc(lSeek, file_info.size_file_comment - uSizeRead);
  end
  else
    Inc(lSeek, file_info.size_file_comment);

  if ((err = UNZ_OK) and (pfile_info <> nil)) then
    pfile_info^ := file_info;

  if ((err = UNZ_OK) and (pfile_info_internal <> nil)) then
    pfile_info_internal^ := file_info_internal;

  unzlocal_GetCurrentFileInfoInternal := err;
end;


{ Write info about the ZipFile in the *pglobal_info structure.
  No preparation of the structure is needed
  return UNZ_OK if there is no problem. }

function unzGetCurrentFileInfo(afile: unzFile; pfile_info: unz_file_info_ptr; szFileName: PAnsiChar; fileNameBufferSize: longint; extraField: pointer; extraFieldBufferSize: longint; szComment: PAnsiChar; commentBufferSize: longint): longint; { ZEXPORT }

{ Get Info about the current file
  if pfile_info<>NIL, the pfile_info^ structure will contain some
  info about the current file
  if szFileName<>NIL, the filemane string will be copied in szFileName
      (fileNameBufferSize is the size of the buffer)
  if extraField<>NIL, the extra field information will be copied in
    extraField  (extraFieldBufferSize is the size of the buffer).
    This is the Central-header version of the extra field
  if szComment<>NIL, the comment string of the file will be copied in
    szComment (commentBufferSize is the size of the buffer) }

begin
  unzGetCurrentFileInfo := unzlocal_GetCurrentFileInfoInternal(afile,
    pfile_info, nil, szFileName, fileNameBufferSize, extraField,
    extraFieldBufferSize, szComment, commentBufferSize);
end;


{ Set the current file of the zipfile to the first file.
  return UNZ_OK if there is no problem }

function unzGoToFirstFile(afile: unzFile): longint;  { ZEXPORT }
var
  err: longint;
  s:   unz_s_ptr;
begin
  if (afile = nil) then
  begin
    unzGoToFirstFile := UNZ_PARAMERROR;
    exit;
  end;
  s   := unz_s_ptr(afile);
  s^.pos_in_central_dir := s^.offset_central_dir;
  s^.num_file := 0;
  err := unzlocal_GetCurrentFileInfoInternal(afile, @s^.cur_file_info, @s^.cur_file_info_internal, nil, 0, nil, 0, nil, 0);
  s^.current_file_ok := (err = UNZ_OK);
  unzGoToFirstFile := err;
end;


{ Set the current file of the zipfile to the next file.
  return UNZ_OK if there is no problem
  return UNZ_END_OF_LIST_OF_FILE if the actual file was the latest. }

function unzGoToNextFile(afile: unzFile): longint; { ZEXPORT }
var
  s:   unz_s_ptr;
  err: longint;
begin
  if (afile = nil) then
  begin
    unzGoToNextFile := UNZ_PARAMERROR;
    exit;
  end;
  s := unz_s_ptr(afile);
  if not s^.current_file_ok then
  begin
    unzGoToNextFile := UNZ_END_OF_LIST_OF_FILE;
    exit;
  end;
  if (s^.num_file + 1 = s^.gi.number_entry) then
  begin
    unzGoToNextFile := UNZ_END_OF_LIST_OF_FILE;
    exit;
  end;

  Inc(s^.pos_in_central_dir,
    SIZECENTRALDIRITEM + s^.cur_file_info.size_filename +
    s^.cur_file_info.size_file_extra + s^.cur_file_info.size_file_comment);
  Inc(s^.num_file);
  err := unzlocal_GetCurrentFileInfoInternal(afile, @s^.cur_file_info, @s^.cur_file_info_internal, nil, 0, nil, 0, nil, 0);
  s^.current_file_ok := (err = UNZ_OK);
  unzGoToNextFile := err;
end;


{ Try locate the file szFileName in the zipfile.
  For the iCaseSensitivity signification, see unzStringFileNameCompare

  return value :
  UNZ_OK if the file is found. It becomes the current file.
  UNZ_END_OF_LIST_OF_FILE if the file is not found }

function unzLocateFile(afile: unzFile; const szFileName: PAnsiChar; iCaseSensitivity: longint): longint; { ZEXPORT }
var
  s:   unz_s_ptr;
  err: longint;
  num_fileSaved: longint;
  pos_in_central_dirSaved: longint;
var
  szCurrentFileName: array[0..UNZ_MAXFILENAMEINZIP + 1 - 1] of AnsiChar;
begin
  if (afile = nil) then
  begin
    unzLocateFile := UNZ_PARAMERROR;
    exit;
  end;

  if (strlen(szFileName) >= UNZ_MAXFILENAMEINZIP) then
  begin
    unzLocateFile := UNZ_PARAMERROR;
    exit;
  end;

  s := unz_s_ptr(afile);
  if (not s^.current_file_ok) then
  begin
    unzLocateFile := UNZ_END_OF_LIST_OF_FILE;
    exit;
  end;
  num_fileSaved := s^.num_file;
  pos_in_central_dirSaved := s^.pos_in_central_dir;

  err := unzGoToFirstFile(afile);

  while (err = UNZ_OK) do
  begin
    unzGetCurrentFileInfo(afile, nil,
      szCurrentFileName, sizeof(szCurrentFileName) - 1, nil, 0, nil, 0);
    if (unzStringFileNameCompare(szCurrentFileName,
      szFileName, iCaseSensitivity) = 0) then
    begin
      unzLocateFile := UNZ_OK;
      exit;
    end;
    err := unzGoToNextFile(afile);
  end;

  s^.num_file   := num_fileSaved;
  s^.pos_in_central_dir := pos_in_central_dirSaved;
  unzLocateFile := err;
end;


{ Read the local header of the current zipfile
  Check the coherency of the local header and info in the end of central
        directory about this file
  store in *piSizeVar the size of extra info in local header
        (filename and size of extra field data) }

function unzlocal_CheckCurrentFileCoherencyHeader(s: unz_s_ptr; var piSizeVar: longint; var poffset_local_extrafield: longint; var psize_local_extrafield: smallint): longint;
var
  lCRC: Cardinal;
  uMagic, uData, uFlags: longint;
  size_filename: longint;
  size_extra_field: longint;
  err: longint;
begin
  err := UNZ_OK;

  piSizeVar := 0;
  poffset_local_extrafield := 0;
  psize_local_extrafield := 0;

  if (fseek(s^.afile, s^.cur_file_info_internal.offset_curfile +
    s^.byte_before_the_zipfile, ZipSeekSet) <> 0) then
  begin
    unzlocal_CheckCurrentFileCoherencyHeader := UNZ_ERRNO;
    exit;
  end;

  if (err = UNZ_OK) then
    if (unzlocal_getLong(s^.afile, uMagic) <> UNZ_OK) then
      err := UNZ_ERRNO
    else
    if (uMagic <> $04034b50) then
      err := UNZ_BADZIPFILE;

  if (unzlocal_getShort(s^.afile, uData) <> UNZ_OK) then
    err := UNZ_ERRNO;
{
  else
    if ((err=UNZ_OK) and (uData<>s^.cur_file_info.wVersion)) then
      err := UNZ_BADZIPFILE;
}
  if (unzlocal_getShort(s^.afile, uFlags) <> UNZ_OK) then
    err := UNZ_ERRNO;

  if (unzlocal_getShort(s^.afile, uData) <> UNZ_OK) then
    err := UNZ_ERRNO
  else
  if ((err = UNZ_OK) and (uData <> s^.cur_file_info.compression_method)) then
    err := UNZ_BADZIPFILE;

  if ((err = UNZ_OK) and (s^.cur_file_info.compression_method <> 0) and
    (s^.cur_file_info.compression_method <> Z_DEFLATED)) then
    err := UNZ_BADZIPFILE;

  if (unzlocal_getLong(s^.afile, uData) <> UNZ_OK) then { date/time }
    err := UNZ_ERRNO;

  if (unzlocal_getLong(s^.afile, uData) <> UNZ_OK) then { crc }
    err := UNZ_ERRNO
  else
  begin
    Move(uData, lCRC, SizeOf(lCRC));
    if ((err = UNZ_OK) and (lCRC <> s^.cur_file_info.crc) and
      ((uFlags and 8) = 0)) then
      err := UNZ_BADZIPFILE;
  end;

  if (unzlocal_getLong(s^.afile, uData) <> UNZ_OK) then { size compr }
    err := UNZ_ERRNO
  else
  if ((err = UNZ_OK) and (uData <> s^.cur_file_info.compressed_size) and
    ((uFlags and 8) = 0)) then
    err := UNZ_BADZIPFILE;

  if (unzlocal_getLong(s^.afile, uData) <> UNZ_OK) then { size uncompr }
    err := UNZ_ERRNO
  else
  if ((err = UNZ_OK) and (uData <> s^.cur_file_info.uncompressed_size) and
    ((uFlags and 8) = 0)) then
    err := UNZ_BADZIPFILE;


  if (unzlocal_getShort(s^.afile, size_filename) <> UNZ_OK) then
    err := UNZ_ERRNO
  else
  if ((err = UNZ_OK) and (size_filename <> s^.cur_file_info.size_filename)) then
    err := UNZ_BADZIPFILE;

  Inc(piSizeVar, smallint(size_filename));

  if (unzlocal_getShort(s^.afile, size_extra_field) <> UNZ_OK) then
    err := UNZ_ERRNO;
  poffset_local_extrafield := s^.cur_file_info_internal.offset_curfile +
    SIZEZIPLOCALHEADER + size_filename;
  psize_local_extrafield := smallint(size_extra_field);

  Inc(piSizeVar, smallint(size_extra_field));

  unzlocal_CheckCurrentFileCoherencyHeader := err;
end;

{ Open for reading data the current file in the zipfile.
  If there is no error, the return value is UNZ_OK. }

function unzOpenCurrentFile(afile: unzFile): longint; { ZEXPORT }
var
  err: longint;
  Store: boolean;
  iSizeVar: longint;
  s: unz_s_ptr;
  pfile_in_zip_read_info: file_in_zip_read_info_s_ptr;
  offset_local_extrafield: longint;  { offset of the local extra field }
  size_local_extrafield: smallint;     { size of the local extra field }
begin
  err := UNZ_OK;

  if (afile = nil) then
  begin
    unzOpenCurrentFile := UNZ_PARAMERROR;
    exit;
  end;
  s := unz_s_ptr(afile);
  if not s^.current_file_ok then
  begin
    unzOpenCurrentFile := UNZ_PARAMERROR;
    exit;
  end;

  if (s^.pfile_in_zip_read <> nil) then
    unzCloseCurrentFile(afile);

  if (unzlocal_CheckCurrentFileCoherencyHeader(s, iSizeVar,
    offset_local_extrafield, size_local_extrafield) <> UNZ_OK) then
  begin
    unzOpenCurrentFile := UNZ_BADZIPFILE;
    exit;
  end;

  pfile_in_zip_read_info := file_in_zip_read_info_s_ptr(
    AllocMem(sizeof(file_in_zip_read_info_s)));
  if (pfile_in_zip_read_info = nil) then
  begin
    unzOpenCurrentFile := UNZ_INTERNALERROR;
    exit;
  end;

  pfile_in_zip_read_info^.read_buffer := PAnsiChar(AllocMem(UNZ_BUFSIZE));
  pfile_in_zip_read_info^.offset_local_extrafield := offset_local_extrafield;
  pfile_in_zip_read_info^.size_local_extrafield := size_local_extrafield;
  pfile_in_zip_read_info^.pos_local_extrafield := 0;

  if (pfile_in_zip_read_info^.read_buffer = nil) then
  begin
    FreeMem(pfile_in_zip_read_info);
    unzOpenCurrentFile := UNZ_INTERNALERROR;
    exit;
  end;

  pfile_in_zip_read_info^.stream_initialised := False;

  if ((s^.cur_file_info.compression_method <> 0) and
    (s^.cur_file_info.compression_method <> Z_DEFLATED)) then
    err := UNZ_BADZIPFILE;
  Store := s^.cur_file_info.compression_method = 0;

  pfile_in_zip_read_info^.crc32_wait := s^.cur_file_info.crc;
  pfile_in_zip_read_info^.crc32      := 0;
  pfile_in_zip_read_info^.compression_method := s^.cur_file_info.compression_method;
  pfile_in_zip_read_info^.afile      := s^.afile;
  pfile_in_zip_read_info^.byte_before_the_zipfile := s^.byte_before_the_zipfile;

  pfile_in_zip_read_info^.stream.total_out := 0;

  if (not Store) then
  begin
    err := inflateInit2(pfile_in_zip_read_info^.stream, -MAX_WBITS);

    if (err = Z_OK) then
      pfile_in_zip_read_info^.stream_initialised := True;
        { windowBits is passed < 0 to tell that there is no zlib header.
          Note that in this case inflate *requires* an extra "dummy" byte
          after the compressed stream in order to complete decompression and
          return Z_STREAM_END.
          In unzip, i don't wait absolutely Z_STREAM_END because I known the
          size of both compressed and uncompressed data }
  end;
  pfile_in_zip_read_info^.rest_read_compressed   := s^.cur_file_info.compressed_size;
  pfile_in_zip_read_info^.rest_read_uncompressed := s^.cur_file_info.uncompressed_size;


  pfile_in_zip_read_info^.pos_in_zipfile :=
    s^.cur_file_info_internal.offset_curfile + SIZEZIPLOCALHEADER + iSizeVar;

  pfile_in_zip_read_info^.stream.avail_in := 0;


  s^.pfile_in_zip_read := pfile_in_zip_read_info;
  unzOpenCurrentFile   := UNZ_OK;
end;


{ Read bytes from the current file (opened by unzOpenCurrentFile)
  buf contain buffer where data must be copied
  len the size of buf.

  return the number of byte copied if some bytes are copied
  return 0 if the end of file was reached
  return <0 with error code if there is an error
    (UNZ_ERRNO for IO error, or zLib error for uncompress error) }

function unzReadCurrentFile(afile: unzFile; buf: pointer; len: cardinal): longint; { ZEXPORT }

var
  err:   longint;
  iRead: Longint;
  s:     unz_s_ptr;
  pfile_in_zip_read_info: file_in_zip_read_info_s_ptr;
var
  uReadThis: longint;
var
  uDoCopy, i: longint;
var
  uTotalOutBefore, uTotalOutAfter: longint;
  bufBefore: pbyte;
  uOutThis: longint;
  flush: longint;
begin
  err   := UNZ_OK;
  iRead := 0;
  if (afile = nil) then
  begin
    unzReadCurrentFile := UNZ_PARAMERROR;
    exit;
  end;
  s := unz_s_ptr(afile);
  pfile_in_zip_read_info := s^.pfile_in_zip_read;

  if (pfile_in_zip_read_info = nil) then
  begin
    unzReadCurrentFile := UNZ_PARAMERROR;
    exit;
  end;

  if ((pfile_in_zip_read_info^.read_buffer = nil)) then
  begin
    unzReadCurrentFile := UNZ_END_OF_LIST_OF_FILE;
    exit;
  end;

  if (len = 0) then
  begin
    unzReadCurrentFile := 0;
    exit;
  end;

  pfile_in_zip_read_info^.stream.next_out := pbyte(buf);

  pfile_in_zip_read_info^.stream.avail_out := len;

  if (len > pfile_in_zip_read_info^.rest_read_uncompressed) then
    pfile_in_zip_read_info^.stream.avail_out :=
      pfile_in_zip_read_info^.rest_read_uncompressed;

  while (pfile_in_zip_read_info^.stream.avail_out > 0) do
  begin
    if ((pfile_in_zip_read_info^.stream.avail_in = 0) and
      (pfile_in_zip_read_info^.rest_read_compressed > 0)) then
    begin
      uReadThis := UNZ_BUFSIZE;
      if (pfile_in_zip_read_info^.rest_read_compressed < uReadThis) then
        uReadThis := pfile_in_zip_read_info^.rest_read_compressed;
      if (uReadThis = 0) then
      begin
        unzReadCurrentFile := UNZ_EOF;
        exit;
      end;
      if (fseek(pfile_in_zip_read_info^.afile,
        pfile_in_zip_read_info^.pos_in_zipfile +
        pfile_in_zip_read_info^.byte_before_the_zipfile, ZipSeekSet) <> 0) then
      begin
        unzReadCurrentFile := UNZ_ERRNO;
        exit;
      end;
      if fread(pfile_in_zip_read_info^.read_buffer, uReadThis, 1,
        pfile_in_zip_read_info^.afile) <> 1 then
      begin
        unzReadCurrentFile := UNZ_ERRNO;
        exit;
      end;
      Inc(pfile_in_zip_read_info^.pos_in_zipfile, uReadThis);

      Dec(pfile_in_zip_read_info^.rest_read_compressed, uReadThis);

      pfile_in_zip_read_info^.stream.next_in  :=
        pbyte(pfile_in_zip_read_info^.read_buffer);
      pfile_in_zip_read_info^.stream.avail_in := uReadThis;
    end;

    if (pfile_in_zip_read_info^.compression_method = 0) then
    begin
      if (pfile_in_zip_read_info^.stream.avail_out <
        pfile_in_zip_read_info^.stream.avail_in) then
        uDoCopy := pfile_in_zip_read_info^.stream.avail_out
      else
        uDoCopy := pfile_in_zip_read_info^.stream.avail_in;

      for i := 0 to uDoCopy - 1 do
        Pbytearray(pfile_in_zip_read_info^.stream.next_out)^[i] :=
          Pbytearray(pfile_in_zip_read_info^.stream.next_in)^[i];

      pfile_in_zip_read_info^.crc32 := CRC32Buffer(pfile_in_zip_read_info^.crc32,
        pfile_in_zip_read_info^.stream.next_out, uDoCopy);
      Dec(pfile_in_zip_read_info^.rest_read_uncompressed, uDoCopy);
      Dec(pfile_in_zip_read_info^.stream.avail_in, uDoCopy);
      Dec(pfile_in_zip_read_info^.stream.avail_out, uDoCopy);
      Inc(pfile_in_zip_read_info^.stream.next_out, uDoCopy);
      Inc(pfile_in_zip_read_info^.stream.next_in, uDoCopy);
      Inc(pfile_in_zip_read_info^.stream.total_out, uDoCopy);
      Inc(iRead, uDoCopy);
    end
    else
    begin
      flush := Z_SYNC_FLUSH;

      uTotalOutBefore := pfile_in_zip_read_info^.stream.total_out;
      bufBefore := pfile_in_zip_read_info^.stream.next_out;

      {
      if ((pfile_in_zip_read_info^.rest_read_uncompressed =
     pfile_in_zip_read_info^.stream.avail_out) and
    (pfile_in_zip_read_info^.rest_read_compressed = 0)) then
        flush := Z_FINISH;
      }
      err := inflate(pfile_in_zip_read_info^.stream, flush);

      uTotalOutAfter := pfile_in_zip_read_info^.stream.total_out;
      uOutThis := uTotalOutAfter - uTotalOutBefore;

      pfile_in_zip_read_info^.crc32 :=
        CRC32Buffer(pfile_in_zip_read_info^.crc32, bufBefore, uOutThis);

      Dec(pfile_in_zip_read_info^.rest_read_uncompressed, uOutThis);

      Inc(iRead, uTotalOutAfter - uTotalOutBefore);

      if (err = Z_STREAM_END) then
      begin
        if iRead = 0 then
          unzReadCurrentFile := UNZ_EOF
        else
          unzReadCurrentFile := iRead;
        exit;
      end;
      if (err <> Z_OK) then
        break;
    end;
  end; { while }

  if (err = Z_OK) then
  begin
    unzReadCurrentFile := iRead;
    exit;
  end;
  unzReadCurrentFile := err;
end;

{ Give the current position in uncompressed data }

function unztell(afile: unzFile): ZipOffset; { ZEXPORT }
var
  s: unz_s_ptr;
  pfile_in_zip_read_info: file_in_zip_read_info_s_ptr;
begin
  if (afile = nil) then
  begin
    unztell := UNZ_PARAMERROR;
    exit;
  end;

  s := unz_s_ptr(afile);
  pfile_in_zip_read_info := s^.pfile_in_zip_read;

  if (pfile_in_zip_read_info = nil) then
  begin
    unztell := UNZ_PARAMERROR;
    exit;
  end;

  unztell := ZipOffset(pfile_in_zip_read_info^.stream.total_out);
end;


{ return 1 (TRUE) if the end of file was reached, 0 elsewhere }

function unzeof(afile: unzFile): longint;
var
  s: unz_s_ptr;
  pfile_in_zip_read_info: file_in_zip_read_info_s_ptr;
begin
  if (afile = nil) then
  begin
    unzeof := UNZ_PARAMERROR;
    exit;
  end;

  s := unz_s_ptr(afile);
  pfile_in_zip_read_info := s^.pfile_in_zip_read;

  if (pfile_in_zip_read_info = nil) then
  begin
    unzeof := UNZ_PARAMERROR;
    exit;
  end;

  if (pfile_in_zip_read_info^.rest_read_uncompressed = 0) then
    unzeof := 1
  else
    unzeof := 0;
end;


{ Read extra field from the current file (opened by unzOpenCurrentFile)
  This is the local-header version of the extra field (sometimes, there is
    more info in the local-header version than in the central-header)

  if buf=NIL, it return the size of the local extra field

  if buf<>NIL, len is the size of the buffer, the extra header is copied in
  buf.
  the return value is the number of bytes copied in buf, or (if <0)
  the error code }

function unzGetLocalExtrafield(afile: unzFile; buf: pointer; len: cardinal): longint;
var
  s: unz_s_ptr;
  pfile_in_zip_read_info: file_in_zip_read_info_s_ptr;
  read_now: longint;
  size_to_read: longint;
begin
  if (afile = nil) then
  begin
    unzGetLocalExtrafield := UNZ_PARAMERROR;
    exit;
  end;

  s := unz_s_ptr(afile);
  pfile_in_zip_read_info := s^.pfile_in_zip_read;

  if (pfile_in_zip_read_info = nil) then
  begin
    unzGetLocalExtrafield := UNZ_PARAMERROR;
    exit;
  end;

  size_to_read := (pfile_in_zip_read_info^.size_local_extrafield -
    pfile_in_zip_read_info^.pos_local_extrafield);

  if (buf = nil) then
  begin
    unzGetLocalExtrafield := longint(size_to_read);
    exit;
  end;

  if (len > size_to_read) then
    read_now := size_to_read
  else
    read_now := len;

  if (read_now = 0) then
  begin
    unzGetLocalExtrafield := 0;
    exit;
  end;

  if (fseek(pfile_in_zip_read_info^.afile,
    pfile_in_zip_read_info^.offset_local_extrafield +
    pfile_in_zip_read_info^.pos_local_extrafield, ZipSeekSet) <> 0) then
  begin
    unzGetLocalExtrafield := UNZ_ERRNO;
    exit;
  end;

  if fread(buf, size_to_read, 1, pfile_in_zip_read_info^.afile) <> 1 then
  begin
    unzGetLocalExtrafield := UNZ_ERRNO;
    exit;
  end;

  unzGetLocalExtrafield := longint(read_now);
end;

{ Close the file in zip opened with unzOpenCurrentFile
  Return UNZ_CRCERROR if all the file was read but the CRC is not good }

function unzCloseCurrentFile(afile: unzFile): longint; { ZEXPORT }
var
  err: longint;
  s:   unz_s_ptr;
  pfile_in_zip_read_info: file_in_zip_read_info_s_ptr;
begin
  err := UNZ_OK;

  if (afile = nil) then
  begin
    unzCloseCurrentFile := UNZ_PARAMERROR;
    exit;
  end;
  s := unz_s_ptr(afile);
  pfile_in_zip_read_info := s^.pfile_in_zip_read;

  if (pfile_in_zip_read_info = nil) then
  begin
    unzCloseCurrentFile := UNZ_PARAMERROR;
    exit;
  end;


  if (pfile_in_zip_read_info^.rest_read_uncompressed = 0) then
    if (pfile_in_zip_read_info^.crc32 <> pfile_in_zip_read_info^.crc32_wait) then
      err := UNZ_CRCERROR;


  FreeMem(pfile_in_zip_read_info^.read_buffer);
  pfile_in_zip_read_info^.read_buffer := nil;
  if (pfile_in_zip_read_info^.stream_initialised) then
    inflateEnd(pfile_in_zip_read_info^.stream);

  pfile_in_zip_read_info^.stream_initialised := False;
  FreeMem(pfile_in_zip_read_info);

  s^.pfile_in_zip_read := nil;

  unzCloseCurrentFile := err;
end;


{ Get the global comment string of the ZipFile, in the szComment buffer.
  uSizeBuf is the size of the szComment buffer.
  return the number of byte copied or an error code <0 }

function unzGetGlobalComment(afile: unzFile; szComment: PAnsiChar; uSizeBuf: longint): longint; { ZEXPORT }

var
  s: unz_s_ptr;
  uReadThis: longint;
begin
  if (afile = nil) then
  begin
    unzGetGlobalComment := UNZ_PARAMERROR;
    exit;
  end;
  s := unz_s_ptr(afile);

  uReadThis := uSizeBuf;
  if (uReadThis > s^.gi.size_comment) then
    uReadThis := s^.gi.size_comment;

  if (fseek(s^.afile, s^.central_pos + 22, ZipSeekSet) <> 0) then
  begin
    unzGetGlobalComment := UNZ_ERRNO;
    exit;
  end;

  if (uReadThis > 0) then
  begin
    szComment^ := #0;
    if fread(szComment, uReadThis, 1, s^.afile) <> 1 then
    begin
      unzGetGlobalComment := UNZ_ERRNO;
      exit;
    end;
  end;

  if ((szComment <> nil) and (uSizeBuf > s^.gi.size_comment)) then
    (szComment +s^.gi.size_comment)^ := #0;

  unzGetGlobalComment := longint(uReadThis);
end;


{$pop}

{ zipper implementation }
{$push}{$H+}






ResourceString
  SErrBufsizeChange = 'Changing buffer size is not allowed while (un)zipping.';
  SErrFileChange = 'Changing output file name is not allowed while (un)zipping.';
  SErrInvalidCRC = 'Invalid CRC checksum while unzipping %s.';
  SErrCorruptZIP = 'Corrupt ZIP file %s.';
  SErrUnsupportedCompressionFormat = 'Unsupported compression format %d.';
  SErrUnsupportedMultipleDisksCD = 'A central directory split over multiple disks is unsupported.';
  SErrMaxEntries = 'Encountered %d file entries; maximum supported is %d.';
  SErrMissingFileName = 'Missing filename in entry %d.';
  SErrMissingArchiveName = 'Missing archive filename in streamed entry %d.';
  SErrFileDoesNotExist = 'File "%s" does not exist.';
  SErrPosTooLarge = 'Position/offset %d is larger than maximum supported %d.';
  SErrNoFileName = 'No archive filename for examine operation.';
  SErrNoStream = 'No stream is opened.';
  SErrEncryptionNotSupported = 'Cannot unzip item "%s": encryption is not supported.';
  SErrPatchSetNotSupported = 'Cannot unzip item "%s": patch sets are not supported.';

const
  ZIPBITFLAG_ENCRYPTION       = 1;
  ZIPBITFLAG_SIZE_IN_DATADESC = 1 shl 3;
  ZIPBITFLAG_PATCH_SET        = 1 shl 5;

{ ---------------------------------------------------------------------
    Auxiliary
  ---------------------------------------------------------------------}
Type
  // A local version of TFileStream which uses rawbytestring. It
  TFileStream = class(THandleStream)
  Private
    FFileName : RawBytestring;
  public
    constructor Create(const AFileName: RawBytestring; Mode: Word);
    constructor Create(const AFileName: RawBytestring; Mode: Word; Rights: Cardinal);
    destructor Destroy; override;
    property FileName : RawBytestring Read FFilename;
  end;
  constructor TFileStream.Create(const AFileName: rawbytestring; Mode: Word);

  begin
    Create(AFileName,Mode,438);
  end;


  constructor TFileStream.Create(const AFileName: rawbytestring; Mode: Word; Rights: Cardinal);
    {$ifdef Windows}
    function FixLongFilename(const Fn: RawByteString): RawByteString;
    begin
      Result := Fn;
      if (Length(Fn)>MAX_PATH) and not ((Pos('\\?\', Fn)=1) or (Pos('\\.\', Fn)=1) or (Pos('\\?\UNC\', Fn)=1)) then
        begin
          if (Pos('\\', Fn)=1) and (length(FN)>2) then
            Insert('?\UNC\',Result,3)
          else
            Result:='\\?\'+Fn;
        end;
    end;
    {$endif}

  Var
    H : Thandle;

  begin
    {$ifdef Windows}
    FFileName:=FixLongFilename(AFileName);
    {$else}
    FFileName:=AFileName;
    {$endif}
    If (Mode and fmCreate) > 0 then
      H:=FileCreate(FFileName,Mode,Rights)
    else
      H:=FileOpen(FFileName,Mode);

    If (THandle(H)=feInvalidHandle) then
      If Mode=fmcreate then
        raise EFCreateError.createfmt(SFCreateError,[AFileName])
      else
        raise EFOpenError.Createfmt(SFOpenError,[AFilename]);
    Inherited Create(H);
  end;


  destructor TFileStream.Destroy;

  begin
    FileClose(Handle);
  end;


Procedure DateTimeToZipDateTime(DT : TDateTime; out ZD,ZT : Word);

Var
  Y,M,D,H,N,S,MS : Word;

begin
  DecodeDate(DT,Y,M,D);
  DecodeTime(DT,H,N,S,MS);
  if Y<1980 then
  begin
    // Invalid date/time; set to earliest possible
    Y:=0;
    M:=1;
    D:=1;
    H:=0;
    N:=0;
    S:=0;
    MS:=0;
  end
  else
  begin
    Y:=Y-1980;
  end;
  ZD:=d+(32*M)+(512*Y);
  ZT:=(S div 2)+(32*N)+(2048*h);
end;

Procedure ZipDateTimeToDateTime(ZD,ZT : Word;out DT : TDateTime);

Var
  Y,M,D,H,N,S,MS : Word;
  aDate,aTime : TDateTime;

begin
  MS:=0;
  S:=(ZT and 31) shl 1;
  N:=(ZT shr 5) and 63;
  H:=ZT shr 11;
  D:=ZD and 31;
  M:=(ZD shr 5) and 15;
  Y:=((ZD shr 9) and 127)+1980;
  // Some corrections
  if M < 1 then M := 1;
  if M > 12 then M:=12;
  if D < 1 then D := 1;
  if D>MonthDays[IsLeapYear(Y)][M] then
    D:=MonthDays[IsLeapYear(Y)][M];
  // Try to encode the result, fall back on today if it fails
  if Not TryEncodeDate(Y,M,D,aDate) then
    aDate:=Date;
  if not TryEncodeTime(H,N,S,MS,aTime) then
    aTime:=Time;
  // Return result
  DT:=ComposeDateTime(aDate,ATime);
end;



function ZipUnixAttrsToFatAttrs(const Name: AnsiString; Attrs: Longint): Longint;
begin
  Result := faArchive;

  if (Pos('.', Name) = 1) and (Name <> '.') and (Name <> '..') then
    Result := Result + faHidden;
  case (Attrs and UNIX_MASK) of
    UNIX_DIR:  Result := Result + faDirectory;
    UNIX_LINK: Result := Result + faSymLink;
    UNIX_FIFO, UNIX_CHAR, UNIX_BLK, UNIX_SOCK:
               Result := Result + faSysFile;
  end;

  if (Attrs and UNIX_WUSR) = 0 then
    Result := Result + faReadOnly;
end;

function ZipFatAttrsToUnixAttrs(Attrs: Longint): Longint;
begin
  Result := UNIX_DEFAULT;
  if (faReadOnly and Attrs) > 0 then
    Result := Result and not (UNIX_WUSR);

  if (faSymLink and Attrs) > 0 then
    Result := Result or UNIX_LINK
  else
    if (faDirectory and Attrs) > 0 then
      Result := Result or UNIX_DIR
    else
      Result := Result or UNIX_FILE;
end;

function CRC32Str(const s:AnsiString):DWord;
var
  i:Integer;
begin
  Result:=$FFFFFFFF;
  if Length(S)>0 then
    for i:=1 to Length(s) do
      Result:=CRC32Byte(Result, Ord(s[i]));
  Result:=not Result;
end;

{ ---------------------------------------------------------------------
    TDeCompressor
  ---------------------------------------------------------------------}


Procedure TDeCompressor.UpdC32(Octet: Byte);

Begin
  FCrc32Val := CRC32Byte(FCrc32Val, Octet);
end;

constructor TDeCompressor.Create(AInFile, AOutFile: TStream; ABufSize: LongWord);
begin
  FinFile:=AInFile;
  FoutFile:=AOutFile;
  FBufferSize:=ABufSize;
  CRC32Val:=$FFFFFFFF;
end;

procedure TDeCompressor.Terminate;
begin
  FTerminated:=True;
end;


{ ---------------------------------------------------------------------
    TCompressor
  ---------------------------------------------------------------------}


Procedure TCompressor.UpdC32(Octet: Byte);

Begin
  FCrc32Val := CRC32Byte(FCrc32Val, Octet);
end;

constructor TCompressor.Create(AInFile, AOutFile: TStream; ABufSize: LongWord);
begin
  FinFile:=AInFile;
  FoutFile:=AOutFile;
  FBufferSize:=ABufSize;
  CRC32Val:=$FFFFFFFF;
end;

procedure TCompressor.Terminate;
begin
  FTerminated:=True;
end;


{ ---------------------------------------------------------------------
    TDeflater
  ---------------------------------------------------------------------}

constructor TDeflater.Create(AInFile, AOutFile: TStream; ABufSize: LongWord);
begin
  Inherited;
  FCompressionLevel:=clDefault;
end;


procedure TDeflater.Compress;
Var
  Buf : PByte;
  I,Count : integer;
  C : TCompressionStream;
  BytesNow : Int64;
  NextMark : Int64;
  OnBytes : Int64;
  FSize : Int64;
begin
  CRC32Val:=$FFFFFFFF;
  Buf:=GetMem(FBufferSize);
  if FOnPercent = 0 then
    FOnPercent := 1;
  OnBytes:=Round((FInFile.Size * FOnPercent) / 100);
  BytesNow:=0;
  NextMark := OnBytes;
  FSize:=FInfile.Size;
  Try
    C:=TCompressionStream.Create(FCompressionLevel,FOutFile,True);
    Try
      if assigned(FOnProgress) then
        fOnProgress(self,0);
      Repeat
        Count:=FInFile.Read(Buf^,FBufferSize);
        For I:=0 to Count-1 do
          UpdC32(Buf[i]);
        // Writebuffer will loop
        C.WriteBuffer(Buf^,Count);
        inc(BytesNow,Count);
        if BytesNow>NextMark Then
          begin
            if (FSize>0) and assigned(FOnProgress) Then
              FOnProgress(self,100 * ( BytesNow / FSize));
            inc(NextMark,OnBytes);
          end;
      Until (Count=0) or Terminated;
    Finally
      C.Free;
    end;
  Finally
    FreeMem(Buf);
  end;
  if assigned(FOnProgress) then
    fOnProgress(self,100.0);
  Crc32Val:=NOT Crc32Val;
end;

class function TDeflater.ZipID: Word;
begin
  Result:=8;
end;

class function TDeflater.ZipVersionReqd: Word;
begin
  Result:=20;
end;

function TDeflater.ZipBitFlag: Word;
begin
  case CompressionLevel of
    clnone: Result := %110;
    clfastest: Result := %100;
    cldefault: Result := %000;
    clmax: Result := %010;
    else
      Result := 0;
  end;
end;

{ ---------------------------------------------------------------------
    TInflater
  ---------------------------------------------------------------------}

constructor TInflater.Create(AInFile, AOutFile: TStream; ABufSize: LongWord);
begin
  Inherited;
end;


procedure TInflater.DeCompress;

Var
  Buf : PByte;
  I,Count : Integer;
  C : TDeCompressionStream;
  BytesNow : Integer;
  NextMark : Integer;
  OnBytes  : Integer;
  FSize    : Integer;

begin
  CRC32Val:=$FFFFFFFF;
  if FOnPercent = 0 then
    FOnPercent := 1;
  OnBytes:=Round((FInFile.Size * FOnPercent) / 100);
  BytesNow:=0; NextMark := OnBytes;
  FSize:=FInfile.Size;

  If Assigned(FOnProgress) then
    fOnProgress(self,0);

  Buf:=GetMem(FBufferSize);
  Try
    C:=TDeCompressionStream.Create(FInFile,True);
    Try
      Repeat
        Count:=C.Read(Buf^,FBufferSize);
        For I:=0 to Count-1 do
          UpdC32(Buf[i]);
        FOutFile.WriteBuffer(Buf^,Count);
        inc(BytesNow,Count);
        if BytesNow>NextMark Then
           begin
             if (FSize>0) and assigned(FOnProgress) Then
               FOnProgress(self,100 * ( BytesNow / FSize));
             if assigned(FOnProgressEx) Then
               FOnProgressEx(Self, FTotPos + BytesNow, FTotSize);
             inc(NextMark,OnBytes);
           end;
      Until (Count=0) or Terminated;
      FTotPos := FTotPos + FOutFile.Size;
    Finally
      C.Free;
    end;
  Finally
    FreeMem(Buf);
  end;
 if assigned(FOnProgress) then
   fOnProgress(self,100.0);
 if assigned(FOnProgressEx) then
   FOnProgressEx(Self, FTotPos, FTotSize);
  Crc32Val:=NOT Crc32Val;
end;

class function TInflater.ZipID: Word;
begin
  Result:=8;
end;


{ ---------------------------------------------------------------------
    TShrinker
  ---------------------------------------------------------------------}

Const
   DefaultInMemSize = 256*1024; { Files larger than 256k are processed on disk   }
   DefaultBufSize =  16384;     { Use 16K file buffers                             }
   MINBITS     =      9;        { Starting code size of 9 bits                     }
   MAXBITS     =     13;        { Maximum code size of 13 bits                     }
   SPECIAL     =    256;        { Special function code                            }
   INCSIZE     =      1;        { Code indicating a jump in code size              }
   CLEARCODE   =      2;        { Code indicating code table has been cleared      }
   STDATTR     =    faAnyFile;  { Standard file attribute for DOS Find First/Next  }

constructor TShrinker.Create(AInFile, AOutFile : TStream; ABufSize : LongWord);
begin
  Inherited;
  FBufSize:=ABufSize;
  InBuf:=GetMem(FBUFSIZE);
  OutBuf:=GetMem(FBUFSIZE);
  CodeTable:=GetMem(SizeOf(CodeTable^));
  FreeList:=GetMem(SizeOf(FreeList^));
end;

destructor TShrinker.Destroy;
begin
  FreeMem(CodeTable);
  FreeMem(FreeList);
  FreeMem(InBuf);
  FreeMem(OutBuf);
  inherited Destroy;
end;

Procedure TShrinker.Compress;

Var
   OneString : AnsiString;
   Remaining : Word;

begin
  BytesIn := 1;
  BytesOut := 1;
  InitializeCodeTable;
  FillInputBuffer;
  FirstCh:= TRUE;
  Crc32Val:=$FFFFFFFF;
  FOnBytes:=Round((FInFile.Size * FOnPercent) / 100);
  While Not InputEof do
    begin
    Remaining:=Succ(MaxInBufIdx - InBufIdx);
    If Remaining>255 then
      Remaining:=255;
    If Remaining=0 then
      FillInputBuffer
    else
      begin
      SetLength(OneString,Remaining);
      Move(InBuf[InBufIdx], OneString[1], Remaining);
      Inc(InBufIdx, Remaining);
      ProcessLine(OneString);
      end;
    end;
   Crc32Val := Not Crc32Val;
   ProcessLine('');
end;

class function TShrinker.ZipID: Word;
begin
  Result:=1;
end;

class function TShrinker.ZipVersionReqd: Word;
begin
  Result:=10;
end;

function TShrinker.ZipBitFlag: Word;
begin
  Result:=0;
end;


Procedure TShrinker.DoOnProgress(Const Pct: Double);

begin
  If Assigned(FOnProgress) then
    FOnProgress(Self,Pct);
end;


Procedure TShrinker.FillInputBuffer;

Begin
   MaxInbufIDx:=FInfile.Read(InBuf[0], FBufSize);
   If MaxInbufIDx=0 then
      InputEof := TRUE
   else
      InputEOF := FALSE;
   InBufIdx := 0;
end;


Procedure TShrinker.WriteOutputBuffer;
Begin
  FOutFile.WriteBuffer(OutBuf[0], OutBufIdx);
  OutBufIdx := 0;
end;


Procedure TShrinker.PutChar(B : Byte);

Begin
  OutBuf[OutBufIdx] := B;
  Inc(OutBufIdx);
  If OutBufIdx>=FBufSize then
    WriteOutputBuffer;
  Inc(BytesOut);
end;

Procedure TShrinker.FlushOutput;
Begin
  If OutBufIdx>0 then
    WriteOutputBuffer;
End;


procedure TShrinker.PutCode(Code : Smallint);

var
  ACode : LongInt;
  XSize : Smallint;

begin
  if (Code=-1) then
    begin
    if BitsUsed>0 then
      PutChar(SaveByte);
    end
  else
    begin
    ACode := Longint(Code);
    XSize := CodeSize+BitsUsed;
    ACode := (ACode shl BitsUsed) or SaveByte;
    while (XSize div 8) > 0 do
      begin
      PutChar(Lo(ACode));
      ACode := ACode shr 8;
      Dec(XSize,8);
      end;
    BitsUsed := XSize;
    SaveByte := Lo(ACode);
    end;
end;


Procedure TShrinker.InitializeCodeTable;

Var
   I  :  Word;
Begin
   For I := 0 to TableSize do
     begin
     With CodeTable^[I] do
       begin
       Child := -1;
       Sibling := -1;
       If (I<=255) then
         Suffix := I;
       end;
     If (I>=257) then
       FreeList^[I] := I;
     end;
   NextFree  := FIRSTENTRY;
   TableFull := FALSE;
end;


Procedure TShrinker.Prune(Parent : Word);

Var
   CurrChild   : Smallint;
   NextSibling : Smallint;
Begin
  CurrChild := CodeTable^[Parent].Child;
  { Find first Child that has descendants .. clear any that don't }
  While (CurrChild <> -1) and (CodeTable^[CurrChild].Child = -1) do
    begin
    CodeTable^[Parent].Child := CodeTable^[CurrChild].Sibling;
    CodeTable^[CurrChild].Sibling := -1;
     { Turn on ClearList bit to indicate a cleared entry }
    ClearList[CurrChild DIV 8] := (ClearList[CurrChild DIV 8] OR (1 SHL (CurrChild MOD 8)));
    CurrChild := CodeTable^[Parent].Child;
    end;
  If CurrChild <> -1 then
    begin   { If there are any children left ...}
    Prune(CurrChild);
    NextSibling := CodeTable^[CurrChild].Sibling;
    While NextSibling <> -1 do
      begin
      If CodeTable^[NextSibling].Child = -1 then
        begin
        CodeTable^[CurrChild].Sibling := CodeTable^[NextSibling].Sibling;
        CodeTable^[NextSibling].Sibling := -1;
        { Turn on ClearList bit to indicate a cleared entry }
        ClearList[NextSibling DIV 8] := (ClearList[NextSibling DIV 8] OR (1 SHL (NextSibling MOD 8)));
        NextSibling := CodeTable^[CurrChild].Sibling;
        end
      else
        begin
        CurrChild := NextSibling;
        Prune(CurrChild);
        NextSibling := CodeTable^[CurrChild].Sibling;
        end;
      end;
    end;
end;


Procedure TShrinker.Clear_Table;
Var
   Node : Word;
Begin
   FillChar(ClearList, SizeOf(ClearList), $00);
   For Node := 0 to 255 do
     Prune(Node);
   NextFree := Succ(TABLESIZE);
   For Node := TABLESIZE downto FIRSTENTRY do
     begin
     If (ClearList[Node DIV 8] AND (1 SHL (Node MOD 8))) <> 0 then
       begin
       Dec(NextFree);
       FreeList^[NextFree] := Node;
       end;
     end;
   If NextFree <= TABLESIZE then
     TableFull := FALSE;
end;


Procedure TShrinker.Table_Add(Prefix : Word; Suffix : Byte);
Var
   FreeNode : Word;
Begin
  If NextFree <= TABLESIZE then
    begin
    FreeNode := FreeList^[NextFree];
    Inc(NextFree);
    CodeTable^[FreeNode].Child := -1;
    CodeTable^[FreeNode].Sibling := -1;
    CodeTable^[FreeNode].Suffix := Suffix;
    If CodeTable^[Prefix].Child  = -1 then
      CodeTable^[Prefix].Child := FreeNode
    else
      begin
      Prefix := CodeTable^[Prefix].Child;
      While CodeTable^[Prefix].Sibling <> -1 do
        Prefix := CodeTable^[Prefix].Sibling;
      CodeTable^[Prefix].Sibling := FreeNode;
      end;
    end;
  if NextFree > TABLESIZE then
    TableFull := TRUE;
end;

function TShrinker.Table_Lookup(    TargetPrefix : Smallint;
                          TargetSuffix : Byte;
                      Out FoundAt      : Smallint   ) : Boolean;

var TempPrefix : Smallint;

begin
  TempPrefix := TargetPrefix;
  Table_lookup := False;
  if CodeTable^[TempPrefix].Child <> -1 then
    begin
    TempPrefix := CodeTable^[TempPrefix].Child;
    repeat
      if CodeTable^[TempPrefix].Suffix = TargetSuffix then
        begin
        Table_lookup := True;
        break;
        end;
      if CodeTable^[TempPrefix].Sibling = -1 then
        break;
      TempPrefix := CodeTable^[TempPrefix].Sibling;
    until False;
  end;
  if Table_Lookup then
    FoundAt := TempPrefix
  else
    FoundAt := -1;
end;

Procedure TShrinker.Shrink(Suffix : Smallint);

Const
  LastCode : Smallint = 0;

Var
  WhereFound : Smallint;

Begin
  If FirstCh then
    begin
    SaveByte := $00;
    BitsUsed := 0;
    CodeSize := MINBITS;
    MaxCode  := (1 SHL CodeSize) - 1;
    LastCode := Suffix;
    FirstCh  := FALSE;
    end
  else
    begin
    If Suffix <> -1 then
      begin
      If TableFull then
        begin
        Putcode(LastCode);
        PutCode(SPECIAL);
        Putcode(CLEARCODE);
        Clear_Table;
        Table_Add(LastCode, Suffix);
        LastCode := Suffix;
        end
      else
        begin
        If Table_Lookup(LastCode, Suffix, WhereFound) then
          begin
          LastCode  := WhereFound;
          end
        else
          begin
          PutCode(LastCode);
          Table_Add(LastCode, Suffix);
          LastCode := Suffix;
          If (FreeList^[NextFree] > MaxCode) and (CodeSize < MaxBits) then
            begin
            PutCode(SPECIAL);
            PutCode(INCSIZE);
            Inc(CodeSize);
            MaxCode := (1 SHL CodeSize) -1;
            end;
          end;
        end;
      end
    else
      begin
      PutCode(LastCode);
      PutCode(-1);
      FlushOutput;
      end;
    end;
end;

Procedure TShrinker.ProcessLine(Const Source : AnsiString);

Var
  I : Word;

Begin
  If Source = '' then
    Shrink(-1)
  else
    For I := 1 to Length(Source) do
      begin
      Inc(BytesIn);
      If (Pred(BytesIn) MOD FOnBytes) = 0 then
        DoOnProgress(100 * ( BytesIn / FInFile.Size));
      UpdC32(Ord(Source[I]));
      Shrink(Ord(Source[I]));
      end;
end;

{ ---------------------------------------------------------------------
    TZipper
  ---------------------------------------------------------------------}


Procedure TZipper.GetFileInfo;

Var
  F    : TZipFileEntry;
  Info : TSearchRec;
  I    : integer; //zip spec allows QWord but FEntries.Count does not support it
{$IFDEF UNIX}
  UnixInfo: Stat;
{$ENDIF}
Begin
  For I := 0 to FEntries.Count-1 do
    begin
    F:=FEntries[i];
    If F.Stream=Nil then
      begin
      If (F.DiskFileName='') then
        Raise EZipError.CreateFmt(SErrMissingFileName,[I]);
      If FindFirst(F.DiskFileName, STDATTR, Info)=0 then
        try
          if Info.Attr and faDirectory <> 0 then //in Linux directory Size <> 0
            F.Size := 0
          else
            F.Size:=Info.Size;
          F.DateTime:=FileDateToDateTime(Info.Time);
        {$IFDEF UNIX}
          if fplstat(F.DiskFileName, @UnixInfo) = 0 then
            F.Attributes := UnixInfo.st_mode;
        {$ELSE}
          F.Attributes := Info.Attr;
        {$ENDIF}
        finally
          FindClose(Info);
        end
      else
        Raise EZipError.CreateFmt(SErrFileDoesNotExist,[F.DiskFileName]);
      end
    else
    begin
      If (F.ArchiveFileName='') then
        Raise EZipError.CreateFmt(SErrMissingArchiveName,[I]);
      F.Size:=F.Stream.Size;
      if (F.Attributes = 0) then
      begin
      {$IFDEF UNIX}
        F.Attributes := UNIX_FILE or UNIX_DEFAULT;
      {$ELSE}
        F.Attributes := faArchive;
      {$ENDIF}
      end;
    end;
  end;
end;


procedure TZipper.SetEntries(const AValue: TZipFileEntries);
begin
  if FEntries=AValue then exit;
  FEntries.Assign(AValue);
end;

Function TZipper.OpenInput(Item : TZipFileEntry) : Boolean;

Begin
  If (Item.Stream<>nil) then
    FInFile:=Item.Stream
  else
    if Item.IsDirectory then
      FInFile := TStringStream.Create('')
    else
      FInFile:=TFileStream.Create(Item.DiskFileName,fmOpenRead);
  Result:=True;
  If Assigned(FOnStartFile) then
    FOnStartFile(Self,Item.ArchiveFileName);
End;


Procedure TZipper.CloseInput(Item : TZipFileEntry);

Begin
  If (FInFile<>Item.Stream) then
    FreeAndNil(FInFile)
  else
    FinFile:=Nil;
  DoEndOfFile;
end;


Procedure TZipper.StartZipFile(Item : TZipFileEntry);

Begin
  FillChar(LocalHdr,SizeOf(LocalHdr),0);
  FillChar(LocalZip64Fld,SizeOf(LocalZip64Fld),0);
  With LocalHdr do
    begin
    Signature := LOCAL_FILE_HEADER_SIGNATURE;
    Extract_Version_Reqd := 20; //default value, v2.0
    Bit_Flag := 0;
    Compress_Method := 1;
    DateTimeToZipDateTime(Item.DateTime,Last_Mod_Date,Last_Mod_Time);
    Crc32 := 0;
    Compressed_Size := 0;
    LocalZip64Fld.Compressed_Size := 0;
    if Item.Size >= $FFFFFFFF then
      begin
      Uncompressed_Size := $FFFFFFFF;
      LocalZip64Fld.Original_Size := Item.Size;
      end
    else
      begin
      Uncompressed_Size := Item.Size;
      LocalZip64Fld.Original_Size := 0;
      end;
    FileName_Length := 0;
    if (LocalZip64Fld.Original_Size>0) or
      (LocalZip64Fld.Compressed_Size>0) or
      (LocalZip64Fld.Disk_Start_Number>0) or
      (LocalZip64Fld.Relative_Hdr_Offset>0) then
      Extra_Field_Length := SizeOf(LocalZip64ExtHdr) + SizeOf(LocalZip64Fld)
    else
      Extra_Field_Length := 0;
  end;
End;


function TZipper.UpdateZipHeader(Item: TZipFileEntry; FZip: TStream;
  ACRC: LongWord; AMethod: Word; AZipVersionReqd: Word; AZipBitFlag: Word
  ): Boolean;
  // Update header for a single zip file (local header)
var
  IsZip64           : boolean; //Must the local header be in zip64 format?
  // Separate from zip64 status of entire zip file.
  ZFileName         : RawByteString;
Begin
  ZFileName := Item.ArchiveFileName;
  IsZip64 := false;
  With LocalHdr do
    begin
    if FUseLanguageEncoding then begin
      SetCodePage(ZFileName, CP_UTF8, True);
      Bit_Flag := Bit_Flag or EFS_LANGUAGE_ENCODING_FLAG;
    end;
    FileName_Length := Length(ZFileName);
    Crc32 := ACRC;
    if LocalZip64Fld.Original_Size > 0 then
      Result := Not (FZip.Size >= LocalZip64Fld.Original_Size)
    else
      Result := Not (Compressed_Size >= Uncompressed_Size);
    if Item.CompressionLevel=clNone
      then Result:=false; //user wishes override or invalid compression
    If Not Result then
      begin
      Compress_Method := 0; // No use for compression: change storage type & compression size...
      if LocalZip64Fld.Original_Size>0 then
        begin
        IsZip64 := true;
        Compressed_Size := $FFFFFFFF;
        LocalZip64Fld.Compressed_Size := LocalZip64Fld.Original_Size;
        end
      else
        begin
        Compressed_Size := Uncompressed_Size;
        LocalZip64Fld.Compressed_Size := 0;
        end;
      end
    else { Using compression }
      begin
      Compress_method := AMethod;
      Bit_Flag := Bit_Flag or AZipBitFlag;
      if FZip.Size >= $FFFFFFFF then
      begin
        IsZip64 := true;
        Compressed_Size := $FFFFFFFF;
        LocalZip64Fld.Compressed_Size := FZip.Size;
      end
      else
      begin
        Compressed_Size := FZip.Size;
        LocalZip64Fld.Compressed_Size := 0;
        if LocalZip64Fld.Original_Size > 0 then
          IsZip64 := true;
      end;
      if AZipVersionReqd > Extract_Version_Reqd then
        Extract_Version_Reqd := AZipVersionReqd;
      end;
    if (IsZip64) and (Extract_Version_Reqd<45) then
      Extract_Version_Reqd := 45;
    end;
  if IsZip64 then
    LocalHdr.Extra_Field_Length:=SizeOf(LocalZip64ExtHdr)+SizeOf(LocalZip64Fld);
  FOutStream.WriteBuffer((LocalHdr),SizeOf(LocalHdr));
  // Append extensible field header+zip64 extensible field if needed:
  FOutStream.WriteBuffer(ZFileName[1],Length(ZFileName));
  if IsZip64 then
  begin
    FOutStream.WriteBuffer((LocalZip64ExtHdr),SizeOf(LocalZip64ExtHdr));
    FOutStream.WriteBuffer((LocalZip64Fld),SizeOf(LocalZip64Fld));
  end;
End;


Procedure TZipper.BuildZipDirectory;
// Write out all central file headers using info from local headers
Var
  SavePos   : Int64;
  HdrPos    : Int64; //offset from disk where file begins to local header
  CenDirPos : Int64;
  ACount    : QWord; //entry counter
  ZFileName : AnsiString; //archive filename
  IsZip64   : boolean; //local header=zip64 format?
  MinReqdVersion: word; //minimum needed to extract
  ExtInfoHeader : Extensible_Data_Field_Header_Type;
  Zip64ECD  : Zip64_End_of_Central_Dir_type;
  Zip64ECDL : Zip64_End_of_Central_Dir_Locator_type;
Begin
  ACount := 0;
  MinReqdVersion:=0;
  CenDirPos := FOutStream.Position;
  FOutStream.Seek(0,soBeginning);             { Rewind output file }
  HdrPos := FOutStream.Position;
  FOutStream.ReadBuffer(LocalHdr, SizeOf(LocalHdr));
  Repeat
    SetLength(ZFileName,LocalHdr.FileName_Length);
    FOutStream.ReadBuffer(ZFileName[1], LocalHdr.FileName_Length);
    IsZip64:=(LocalHdr.Compressed_Size=$FFFFFFFF) or (LocalHdr.Uncompressed_Size=$FFFFFFFF) or (HdrPos>=$FFFFFFFF);
    FillChar(LocalZip64Fld,SizeOf(LocalZip64Fld),0); // easier to check compressed length
    if LocalHdr.Extra_Field_Length>0 then
      begin
      SavePos := FOutStream.Position;
      if (IsZip64 and (LocalHdr.Extra_Field_Length>=SizeOf(LocalZip64ExtHdr)+SizeOf(LocalZip64Fld))) then
        while FOutStream.Position<SavePos+LocalHdr.Extra_Field_Length do
          begin
          FOutStream.ReadBuffer(ExtInfoHeader, SizeOf(ExtInfoHeader));
          if ExtInfoHeader.Header_ID=ZIP64_HEADER_ID then
            begin
            FOutStream.ReadBuffer(LocalZip64Fld, SizeOf(LocalZip64Fld));
            end
          else
            begin
            // Read past non-zip64 extra field
            FOutStream.Seek(ExtInfoHeader.Data_Size,soFromCurrent);
            end;
          end;
      // Move past extra fields
      //FOutStream.Seek(SavePos+LocalHdr.Extra_Field_Length,soFromBeginning);
      end;
    SavePos := FOutStream.Position;
    FillChar(CentralHdr,SizeOf(CentralHdr),0);
    With CentralHdr do
      begin
      Signature := CENTRAL_FILE_HEADER_SIGNATURE;
      MadeBy_Version := LocalHdr.Extract_Version_Reqd;
      if (IsZip64) and (MadeBy_Version<45) then
        MadeBy_Version := 45;
    {$IFDEF UNIX}
      {$IFDEF DARWIN} //OSX
      MadeBy_Version := MadeBy_Version or (OS_OSX shl 8);
      {$ELSE}
      MadeBy_Version := MadeBy_Version or (OS_UNIX shl 8);
      {$ENDIF}
    {$ENDIF}
      {$warning TODO: find a way to recognize VFAT and NTFS}
      // Copy over extract_version_reqd..extra_field_length
      Move(LocalHdr.Extract_Version_Reqd, Extract_Version_Reqd, 26);
      if (IsZip64) and (Extract_Version_Reqd<45) then
        Extract_Version_Reqd := 45;
      // Keep track of the minimum version required to extract
      // zip file as a whole
      if Extract_Version_Reqd>MinReqdVersion then
        MinReqdVersion:=Extract_Version_Reqd;
      Last_Mod_Time:=localHdr.Last_Mod_Time;
      Last_Mod_Date:=localHdr.Last_Mod_Date;
      File_Comment_Length := 0;
      Starting_Disk_Num := 0;
      Internal_Attributes := 0;
    {$IFDEF UNIX}
      External_Attributes := Entries[ACount].Attributes shl 16;
    {$ELSE}
      External_Attributes := Entries[ACount].Attributes;
    {$ENDIF}
      if HdrPos>=$FFFFFFFF then
      begin
        FZipFileNeedsZip64:=true;
        IsZip64:=true;
        Local_Header_offset := $FFFFFFFF;
        // LocalZip64Fld will be written out as central dir extra field later
        LocalZip64Fld.Relative_Hdr_Offset := HdrPos;
      end
      else
        Local_Header_Offset := HdrPos;
      end;

      if IsZip64 then
      begin
          CentralHdr.Extra_Field_Length:=SizeOf(LocalZip64ExtHdr)+SizeOf(LocalZip64Fld);
      end else CentralHdr.Extra_Field_Length :=0;

    FOutStream.Seek(0,soEnd);
    FOutStream.WriteBuffer((CentralHdr),SizeOf(CentralHdr));
    FOutStream.WriteBuffer(ZFileName[1],Length(ZFileName));

    if IsZip64 then
      begin
      FOutStream.Seek(0,soEnd);
      FOutStream.WriteBuffer((LocalZip64ExtHdr),SizeOf(LocalZip64ExtHdr));
      FOutStream.WriteBuffer((LocalZip64Fld),SizeOf(LocalZip64Fld));
      end;

    Inc(ACount);
    // Move past compressed file data to next header:
    if LocalZip64Fld.Compressed_Size > 0 then
      FOutStream.Seek(SavePos + LocalZip64Fld.Compressed_Size,soBeginning)
    else
      FOutStream.Seek(SavePos + LocalHdr.Compressed_Size,soBeginning);
    HdrPos:=FOutStream.Position;
    FOutStream.ReadBuffer(LocalHdr, SizeOf(LocalHdr));
  Until LocalHdr.Signature = CENTRAL_FILE_HEADER_SIGNATURE ;

  FOutStream.Seek(0,soEnd);
  FillChar(EndHdr,SizeOf(EndHdr),0);

  // Write end of central directory record
  // We'll use the zip64 variants to store counts etc
  // and copy to the old record variables if possible
  // This seems to match expected behaviour of unzippers like
  // unrar that only look at the zip64 record
  FillChar(Zip64ECD, SizeOf(Zip64ECD), 0);
  Zip64ECD.Signature:=ZIP64_END_OF_CENTRAL_DIR_SIGNATURE;
  FillChar(Zip64ECDL, SizeOf(Zip64ECDL), 0);
  Zip64ECDL.Signature:=ZIP64_END_OF_CENTRAL_DIR_LOCATOR_SIGNATURE;
  Zip64ECDL.Total_Disks:=1; //default and no support for multi disks yet anyway
  With EndHdr do
    begin
    Signature := END_OF_CENTRAL_DIR_SIGNATURE;
    Disk_Number := 0;
    Central_Dir_Start_Disk := 0;

    Zip64ECD.Entries_This_Disk:=ACount;
    Zip64ECD.Total_Entries:=Acount;
    if ACount>$FFFF then
      begin
      FZipFileNeedsZip64 := true;
      Entries_This_Disk := $FFFF;
      Total_Entries := $FFFF;
      end
    else
      begin
      Entries_This_Disk := Zip64ECD.Entries_This_Disk;
      Total_Entries := Zip64ECD.Total_Entries;
      end;

    Zip64ECD.Central_Dir_Size := FOutStream.Size-CenDirPos;
    if (Zip64ECD.Central_Dir_Size)>$FFFFFFFF then
      begin
      FZipFileNeedsZip64 := true;
      Central_Dir_Size := $FFFFFFFF;
      end
    else
      begin
      Central_Dir_Size := Zip64ECD.Central_Dir_Size;
      end;

    Zip64ECD.Start_Disk_Offset := CenDirPos;
    if Zip64ECD.Start_Disk_Offset>$FFFFFFFF then
      begin
      FZipFileNeedsZip64 := true;
      Start_Disk_Offset := $FFFFFFFF;
      end
    else
      begin
      Start_Disk_Offset := Zip64ECD.Start_Disk_Offset;
      end;

    ZipFile_Comment_Length := Length(FFileComment);

    if FZipFileNeedsZip64 then
    begin
      //Write zip64 end of central directory record if needed
      if MinReqdVersion<45 then
        MinReqdVersion := 45;
      Zip64ECD.Extract_Version_Reqd := MinReqdVersion;
      Zip64ECD.Version_Made_By := MinReqdVersion;
      Zip64ECD.Record_Size := SizeOf(Zip64ECD)-12; //Assumes no variable length field following
      Zip64ECDL.Central_Dir_Zip64_EOCD_Offset := FOutStream.Position;
      Zip64ECDL.Zip64_EOCD_Start_Disk := 0;
      FOutStream.WriteBuffer((Zip64ECD), SizeOf(Zip64ECD));

      //Write zip64 end of central directory locator if needed
      FOutStream.WriteBuffer((Zip64ECDL), SizeOf(Zip64ECDL));
    end;

    FOutStream.WriteBuffer((EndHdr), SizeOf(EndHdr));
    if Length(FFileComment) > 0 then
      FOutStream.WriteBuffer(FFileComment[1],Length(FFileComment));
    end;
end;

Function TZipper.CreateCompressor(Item : TZipFileEntry; AInFile,AZipStream : TStream) : TCompressor;

begin
  Result:=TDeflater.Create(AinFile,AZipStream,FBufSize);
  (Result as TDeflater).CompressionLevel:=Item.CompressionLevel;
  FCurrentCompressor:=Result;
end;

Procedure TZipper.ZipOneFile(Item : TZipFileEntry);

Var
  CRC : LongWord;
  ZMethod : Word;
  ZVersionReqd : Word;
  ZBitFlag : Word;
  ZipStream : TStream;
  TmpFileName, Start : AnsiString;
  I : Integer;

Begin
  OpenInput(Item);
  Try
    StartZipFile(Item);
    If (FInfile.Size<=FInMemSize) then
      ZipStream:=TMemoryStream.Create
    else
      begin
      Start := ChangeFileExt(FFileName, '');
      I := 0;
      repeat
        TmpFileName := Format('%s%.5d.tmp', [Start, I]);
        Inc(I);
      until not FileExists(TmpFileName);
      ZipStream:=TFileStream.Create(TmpFileName,fmCreate);
      end;
    Try
      With CreateCompressor(Item, FinFile,ZipStream) do
        Try
          OnProgress:=Self.OnProgress;
          OnPercent:=Self.OnPercent;
          Compress;
          CRC:=Crc32Val;
          ZMethod:=ZipID;
          ZVersionReqd:=ZipVersionReqd;
          ZBitFlag:=ZipBitFlag;
        Finally
          FCurrentCompressor:=Nil;
          Free;
        end;
      If UpdateZipHeader(Item,ZipStream,CRC,ZMethod,ZVersionReqd,ZBitFlag) then
        // Compressed file smaller than original file.
        FOutStream.CopyFrom(ZipStream,0)
      else
        begin
        // Original file smaller than compressed file.
        FInfile.Seek(0,soBeginning);
        FOutStream.CopyFrom(FInFile,0);
        end;
    finally
      ZipStream.Free;
      If (TmpFileName<>'') then
        DeleteFile(TmpFileName);
    end;
  Finally
    CloseInput(Item);
  end;
end;

// Just like SaveToFile, but uses the FileName property
Procedure TZipper.ZipAllFiles;
begin
  SaveToFile(FileName);
end;

procedure TZipper.SaveToFile(const AFileName: RawByteString);
var
  lStream: TFileStream;
begin
  FFileName:=AFileName;
  lStream:=TFileStream.Create(FFileName,fmCreate);
  try
    SaveToStream(lStream);
  finally
    FreeAndNil(lStream);
  end;
end;

procedure TZipper.SaveToStream(AStream: TStream);
Var
  I : integer; //could be qword but limited by FEntries.Count
begin
  FTerminated:=False;
  FOutStream := AStream;
  If CheckEntries=0 then
    Exit;
  FZipping:=True;
  Try
    GetFileInfo; //get info on file entries in zip
    I:=0;
    While (I<FEntries.Count) and not Terminated do
      begin
      ZipOneFile(FEntries[i]);
      Inc(I);
      end;
    if (FEntries.Count>0) and not Terminated then
      BuildZipDirectory;
  finally
    FZipping:=False;
    // Remove entries that have been added by CheckEntries from Files.
    for I:=0 to FFiles.Count-1 do
      FEntries.Delete(FEntries.Count-1);
  end;
end;

procedure TZipper.ZipFile(const aFileToBeZipped: RawByteString);
begin
  ZipFiles([aFileToBeZipped]);
end;

procedure TZipper.ZipFile(const AZipFileName, aFileToBeZipped: RawByteString);
begin
  FileName:=aZipFileName;
  ZipFile(aFileToBeZipped);
end;


Procedure TZipper.SetBufSize(Value : LongWord);

begin
  If FZipping then
    Raise EZipError.Create(SErrBufsizeChange);
  If Value>=DefaultBufSize then
    FBufSize:=Value;
end;

Procedure TZipper.SetFileName(Value : RawByteString);

begin
  If FZipping then
    Raise EZipError.Create(SErrFileChange);
  FFileName:=Value;
end;

Procedure TZipper.ZipFiles(Const AZipFileName : RawByteString; FileList : TStrings);

begin
  FFileName:=AZipFileName;
  ZipFiles(FileList);
end;

procedure TZipper.ZipFiles(const AZipFileName: RawByteString; const FileList: array of RawbyteString);

begin
  FileName:=aZipFileName;
  ZipFiles(FileList);
end;

procedure TZipper.ZipFiles(const aFileList: array of RawbyteString);
Var
  L : TStringList;
  S : RawByteString;
begin
  L:=TStringList.Create;
  try
    L.Capacity:=Length(aFileList);
    for S in aFileList do
      L.Add(S);
    ZipFiles(L);
  finally
    L.Free;
  end;
end;

procedure TZipper.ZipFiles(FileList: TStrings);
begin
  FFiles.Assign(FileList);
  ZipAllFiles;
end;

procedure TZipper.ZipFiles(const AZipFileName: RawByteString; Entries: TZipFileEntries);
begin
  FFileName:=AZipFileName;
  ZipFiles(Entries);
end;

procedure TZipper.ZipFiles(Entries: TZipFileEntries);
begin
  FEntries.Assign(Entries);
  ZipAllFiles;
end;

class procedure TZipper.Zip(const AZipFileName: RawByteString; const aFileToBeZipped: RawByteString);
begin
  With Self.Create do
    try
      ZipFile(aZipFileName,aFileToBeZipped);
    finally
      Free;
    end;
end;

class procedure TZipper.Zip(const AZipFileName: RawByteString; aFileList: array of RawByteString);
begin
  With Self.Create do
    try
      ZipFiles(aZipFileName,aFileList);
    finally
      Free;
    end;
end;

class procedure TZipper.Zip(const AZipFileName: RawByteString; aFileList: TStrings);
begin
  With Self.Create do
    try
      ZipFiles(aZipFileName,aFileList);
    finally
      Free;
    end;
end;

Procedure TZipper.DoEndOfFile;

Var
  ComprPct : Double;

begin
  if (FZipFileNeedsZip64) and (LocalZip64Fld.Original_Size>0) then
    ComprPct := (100.0 * (LocalZip64Fld.Original_size - LocalZip64Fld.Compressed_Size)) / LocalZip64Fld.Original_Size
  else if (LocalHdr.Uncompressed_Size>0) then
    ComprPct := (100.0 * (LocalHdr.Uncompressed_Size - LocalHdr.Compressed_Size)) / LocalHdr.Uncompressed_Size
  else
    ComprPct := 0;
  If Assigned(FOnEndOfFile) then
    FOnEndOfFile(Self,ComprPct);
end;

Constructor TZipper.Create;

begin
  FBufSize:=DefaultBufSize;
  FInMemSize:=DefaultInMemSize;
  FFiles:=TStringList.Create;
  FEntries:=TZipFileEntries.Create(TZipFileEntry);
  FOnPercent:=1;
  FZipFileNeedsZip64:=false;
  LocalZip64ExtHdr.Header_ID:=ZIP64_HEADER_ID;
  LocalZip64ExtHdr.Data_Size:=SizeOf(Zip64_Extended_Info_Field_Type);
end;

Function TZipper.CheckEntries : Integer;

Var
  I : integer; //Could be QWord but limited by FFiles.Count

begin
  for I:=0 to FFiles.Count-1 do
    FEntries.AddFileEntry(FFiles[i]);

  // Use zip64 when number of file entries
  // or individual (un)compressed sizes
  // require it.
  if FEntries.Count >= $FFFF then
    FZipFileNeedsZip64:=true;

  if not(FZipFileNeedsZip64) then
    begin
    for I:=0 to FFiles.Count-1 do
      begin
      if FEntries[i].FNeedsZip64 then
        begin
        FZipFileNeedsZip64:=true;
        break;
        end;
      end;
    end;

  Result:=FEntries.Count;
end;


Procedure TZipper.Clear;

begin
  FEntries.Clear;
  FFiles.Clear;
end;

procedure TZipper.Terminate;
begin
  FTerminated:=True;
  if Assigned(FCurrentCompressor) then
    FCurrentCompressor.Terminate;
end;

Destructor TZipper.Destroy;

begin
  Clear;
  FreeAndNil(FEntries);
  FreeAndNil(FFiles);
  Inherited;
end;

{ ---------------------------------------------------------------------
    TUnZipper
  ---------------------------------------------------------------------}

procedure TUnZipper.OpenInput;

Begin
  if Assigned(FOnOpenInputStream) then
    FOnOpenInputStream(Self, FZipStream);
  if FZipStream = nil then
    FZipStream:=TFileStream.Create(FFileName,fmOpenRead or fmShareDenyWrite);
End;


function TUnZipper.OpenOutput(OutFileName: RawByteString;
  out OutStream: TStream; Item: TFullZipFileEntry): Boolean;
Var
  Path: RawByteString;
  OldDirectorySeparators: set of AnsiChar;

Begin
  { the default RTL behavior is broken on Unix platforms
    for Windows compatibility: it allows both '/' and '\'
    as directory separator. We don't want that behavior
    here, since 'abc\' is a valid file name under Unix.

    The zip standard appnote.txt says zip files must have '/' as path
    separator, even on Windows: 4.4.17.1:
    "The path stored MUST not contain a drive or device letter, or a leading
    slash. All slashes MUST be forward slashes '/' as opposed to backwards
    slashes '\'" See also mantis issue #15836
    However, old versions of FPC on Windows (and possibly other utilities)
    created incorrect zip files with \ separator, so accept these as well as
    they're not valid in Windows file names anyway.
  }
  OldDirectorySeparators:=AllowDirectorySeparators;
  {$ifdef Windows}
  // Explicitly allow / and \ regardless of what Windows supports
  AllowDirectorySeparators:=['\','/'];
  {$else}
  // Follow the standard: only allow / regardless of actual separator on OS
  AllowDirectorySeparators:=['/'];
  {$endif}
  Path:=ExtractFilePath(OutFileName);
  OutStream:=Nil;
  If Assigned(FOnCreateStream) then
    FOnCreateStream(Self, OutStream, Item);
  // If FOnCreateStream didn't create one, we create one now.
  If (OutStream=Nil) and (not Item.IsDirectory) then
    begin
    if (Path<>'') then
      ForceDirectories(Path);
    AllowDirectorySeparators:=OldDirectorySeparators;
    OutStream:=TFileStream.Create(OutFileName,fmCreate);

    end;

  AllowDirectorySeparators:=OldDirectorySeparators;
  Result:=True;
  If Assigned(FOnStartFile) then
    FOnStartFile(Self,OutFileName);
End;


procedure TUnZipper.CloseOutput(Item: TFullZipFileEntry; var OutStream: TStream
  );

Begin
  if Assigned(FOnDoneStream) then
  begin
    FOnDoneStream(Self, OutStream, Item);
    OutStream := nil;
  end
  else
    if Assigned(OutStream) then
      FreeAndNil(OutStream);
  DoEndOfFile;
end;


procedure TUnZipper.CloseInput;

Begin
  if Assigned(FOnCloseInputStream) then
    FOnCloseInputStream(Self, FZipStream);
  FreeAndNil(FZipStream);
end;


procedure TUnZipper.ReadZipHeader(Item: TFullZipFileEntry; out AMethod: Word);
Var
  S : RawByteString;
  U : UTF8String;
  D : TDateTime;
  ExtraFieldHdr: Extensible_Data_Field_Header_Type;
  SavePos: int64; //could be qword but limited by stream
  // Infozip unicode path
  Infozip_Unicode_Path_Ver:Byte;
  Infozip_Unicode_Path_CRC32:DWord;
Begin
  FZipStream.Seek(Item.HdrPos,soBeginning);
  FZipStream.ReadBuffer(LocalHdr,SizeOf(LocalHdr));
  FillChar(LocalZip64Fld,SizeOf(LocalZip64Fld),0); //ensure no erroneous info
  With LocalHdr do
    begin
      Item.FBitFlags:=Bit_Flag;
      // If bit 3 is set in the BitFlags, file size and CRC should be read from
      // the DataDescriptor record. For simplicity, however, we copy them from
      // the same fields of the zipfile entry.
      if Item.FBitFlags and ZIPBITFLAG_SIZE_IN_DATADESC <> 0 then
      begin
        Uncompressed_Size := Item.Size;
        Compressed_Size := Item.CompressedSize;
        CRC32 := Item.CRC32;
      end;
      SetLength(S,Filename_Length);
      FZipStream.ReadBuffer(S[1],Filename_Length);
      if Bit_Flag and EFS_LANGUAGE_ENCODING_FLAG <> 0 then
        SetCodePage(S, CP_UTF8, False);
      Item.ArchiveFileName:=S;
      Item.DiskFileName:=S;
      SavePos:=FZipStream.Position; //after filename, before extra fields
      if Extra_Field_Length>0 then
        begin
        SavePos := FZipStream.Position;
        if (LocalHdr.Extra_Field_Length>=SizeOf(ExtraFieldHdr)) then
          while FZipStream.Position<SavePos+LocalHdr.Extra_Field_Length do
            begin
            FZipStream.ReadBuffer(ExtraFieldHdr, SizeOf(ExtraFieldHdr));
            if ExtraFieldHdr.Header_ID=ZIP64_HEADER_ID then
              begin
              FZipStream.ReadBuffer(LocalZip64Fld, SizeOf(LocalZip64Fld));
              end
            // Infozip unicode path
            else if ExtraFieldHdr.Header_ID=INFOZIP_UNICODE_PATH_ID then
              begin
              FZipStream.ReadBuffer(Infozip_Unicode_Path_Ver,1);
              if Infozip_Unicode_Path_Ver=1 then
                begin
                FZipStream.ReadBuffer(Infozip_Unicode_Path_CRC32,sizeof(Infozip_Unicode_Path_CRC32));
                if CRC32Str(S)=Infozip_Unicode_Path_CRC32 then
                  begin
                  SetLength(U,ExtraFieldHdr.Data_Size-5);
                  FZipStream.ReadBuffer(U[1],Length(U));
                  Item.UTF8ArchiveFileName:=U;
                  Item.UTF8DiskFileName:=U;
                  end
                else
                  FZipStream.Seek(ExtraFieldHdr.Data_Size-5,soFromCurrent);
                end
              else
                FZipStream.Seek(ExtraFieldHdr.Data_Size-1,soFromCurrent);
              end
            else
              FZipStream.Seek(ExtraFieldHdr.Data_Size,soFromCurrent);
            end;
        // Move past extra fields
        FZipStream.Seek(SavePos+Extra_Field_Length,soFromBeginning);
        end;
      Item.Size:=Uncompressed_Size;
      ZipDateTimeToDateTime(Last_Mod_Date,Last_Mod_Time,D);
      Item.DateTime:=D;
      if Crc32 <> 0 then
        Item.CRC32 := Crc32;
      AMethod:=Compress_method;
    end;
End;

procedure TUnZipper.FindEndHeaders(
  out AEndHdr: End_of_Central_Dir_Type;
  out AEndHdrPos: Int64;
  out AEndZip64Hdr: Zip64_End_of_Central_Dir_type;
  out AEndZip64HdrPos: Int64);
// Reads backwords from the end of the zip file,
// following end of central directory, and, if present
// zip64 end of central directory locator and
// zip64 end of central directory record

// If valid regular end of directory found, AEndHdrPos>0
// If valid zip64 end of directory found, AEndZip64HdrPos>0
var
  EndZip64Locator: Zip64_End_of_Central_Dir_Locator_type;
  procedure SearchForSignature;
  // Search for end of central directory record signature
  // If failed, set AEndHdrPos to 0
  var
    I: Integer;
    Buf: PByte;
    BufSize: Integer;
    result: boolean;
  begin
    result:=false;
    // scan the last (64k + something) bytes for the END_OF_CENTRAL_DIR_SIGNATURE
    // (zip file comments are 64k max).
    BufSize := 65536 + SizeOf(AEndHdr) + 128;
    if FZipStream.Size < BufSize then
      BufSize := FZipStream.Size;

    Buf := GetMem(BufSize);
    try
      FZipStream.Seek(FZipStream.Size - BufSize, soBeginning);
      FZipStream.ReadBuffer(Buf^, BufSize);

      for I := BufSize - SizeOf(AEndHdr) downto 0 do
      begin
        if (Buf[I] or (Buf[I + 1] shl 8) or (Buf[I + 2] shl 16) or (Buf[I + 3] shl 24)) = END_OF_CENTRAL_DIR_SIGNATURE then
        begin
          Move(Buf[I], AEndHdr, SizeOf(AEndHdr));
          if (AEndHdr.Signature = END_OF_CENTRAL_DIR_SIGNATURE) and
             (I + SizeOf(AEndHdr) + AEndHdr.ZipFile_Comment_Length <= BufSize) then
          begin
            AEndHdrPos := FZipStream.Size - BufSize + I;
            FZipStream.Seek(AEndHdrPos + SizeOf(AEndHdr), soBeginning);
            SetLength(FFileComment, AEndHdr.ZipFile_Comment_Length);
            FZipStream.ReadBuffer(FFileComment[1], Length(FFileComment));
            result:=true; //found it
            break;
          end;
        end;
      end;
    finally
      FreeMem(Buf);
    end;
    if not(result) then
    begin
      AEndHdrPos := 0;
      FillChar(AEndHdr, SizeOf(AEndHdr), 0);
    end;
  end;

  procedure ZeroData;
  begin
    AEndHdrPos := 0;
    FillChar(AEndHdr, SizeOf(AEndHdr), 0);
    AEndZip64HdrPos:=0;
    FillChar(AEndZip64Hdr, SizeOf(AEndZip64Hdr), 0);
  end;

begin
  // Zip64 records may not exist, so fill out default values
  FillChar(AEndZip64Hdr,SizeOf(AEndZip64Hdr), 0);
  AEndZip64HdrPos:=0;
  // Look for end of central directory record from
  // back of file based on signature (only way due to
  // variable length zip comment etc)
  FFileComment := '';
  // Zip file requires end of central dir header so
  // is corrupt if it is smaller than that
  if FZipStream.Size < SizeOf(AEndHdr) then
  begin
    ZeroData;
    exit;
  end;

  AEndHdrPos := FZipStream.Size - SizeOf(AEndHdr);
  FZipStream.Seek(AEndHdrPos, soBeginning);
  FZipStream.ReadBuffer(AEndHdr, SizeOf(AEndHdr));
  // Search unless record is right at the end of the file:
  if (AEndHdr.Signature <> END_OF_CENTRAL_DIR_SIGNATURE) or
     (AEndHdr.ZipFile_Comment_Length <> 0) then
    SearchForSignature;
  if AEndHdrPos=0 then
  begin
    ZeroData;
    exit;
  end;

  // With a valid end of dir record, see if there's zip64
  // fields:
  FZipStream.Seek(AEndHdrPos-SizeOf(Zip64_End_of_Central_Dir_Locator_type),soBeginning);
  FZipStream.ReadBuffer(EndZip64Locator, SizeOf(EndZip64Locator));
  if EndZip64Locator.Signature=ZIP64_END_OF_CENTRAL_DIR_LOCATOR_SIGNATURE then
  begin
    //Read EndZip64Locator.Total_Disks when implementing multiple disks support
    if EndZip64Locator.Central_Dir_Zip64_EOCD_Offset>High(Int64) then
      raise EZipError.CreateFmt(SErrPosTooLarge,[EndZip64Locator.Central_Dir_Zip64_EOCD_Offset,High(Int64)]);
    AEndZip64HdrPos:=EndZip64Locator.Central_Dir_Zip64_EOCD_Offset;
    FZipStream.Seek(AEndZip64HdrPos, soBeginning);
    FZipStream.ReadBuffer(AEndZip64Hdr, SizeOf(AEndZip64Hdr));
    if AEndZip64Hdr.Signature<>ZIP64_END_OF_CENTRAL_DIR_SIGNATURE then
    begin
      //Corrupt header
      ZeroData;
      Exit;
    end;
  end
  else
  begin
    // No zip64 data, so follow the offset in the end of central directory record
    AEndZip64HdrPos:=0;
    FillChar(AEndZip64Hdr, SizeOf(AEndZip64Hdr), 0);
  end;
end;

procedure TUnZipper.ReadZipDirectory;

Var
  EndHdr      : End_of_Central_Dir_Type;
  EndZip64Hdr : Zip64_End_of_Central_Dir_type;
  i : integer; //could be Qword but limited to number of items in collection
  EndHdrPos,
  EndZip64HdrPos,
  CenDirPos,
  SavePos   : Int64; //could be QWord but limited to stream maximums
  ExtraFieldHeader : Extensible_Data_Field_Header_Type;
  EntriesThisDisk : QWord;
  Zip64Field: Zip64_Extended_Info_Field_Type;
  NewNode   : TFullZipFileEntry;
  D : TDateTime;
  S : RawByteString;
  U : UTF8String;
  // infozip unicode path
  Infozip_unicode_path_ver : byte; // always 1
  Infozip_unicode_path_crc32 : DWord;
Begin
  FindEndHeaders(EndHdr, EndHdrPos,
    EndZip64Hdr, EndZip64HdrPos);
  if EndHdrPos=0 then
    raise EZipError.CreateFmt(SErrCorruptZIP,[FileName]);
  if (EndZip64HdrPos>0) and (EndZip64Hdr.Start_Disk_Offset>0) then
    begin
    if EndZip64Hdr.Start_Disk_Offset>High(Int64) then
      raise EZipError.CreateFmt(SErrPosTooLarge,[EndZip64Hdr.Start_Disk_Offset,High(Int64)]);
    CenDirPos := EndZip64Hdr.Start_Disk_Offset;
    end
  else
    CenDirPos := EndHdr.Start_Disk_Offset;
  FZipStream.Seek(CenDirPos,soBeginning);
  FEntries.Clear;
  if (EndZip64HdrPos>0) and (EndZip64Hdr.Entries_This_Disk>0) then
  begin
    EntriesThisDisk := EndZip64Hdr.Entries_This_Disk;
    if EntriesThisDisk<>EndZip64Hdr.Total_Entries then
      raise EZipError.Create(SErrUnsupportedMultipleDisksCD);
  end
  else
  begin
    EntriesThisDisk :=EndHdr.Entries_This_Disk;
    if EntriesThisDisk<>EndHdr.Total_Entries then
      raise EZipError.Create(SErrUnsupportedMultipleDisksCD);
  end;

  // Entries are added to a collection. The max number of items
  // in a collection limits the entries we can process.
  if EntriesThisDisk>MaxInt then
    raise EZipError.CreateFmt(SErrMaxEntries,[EntriesThisDisk,MaxInt]);

  // Using while instead of for loop so qword can be used on 32 bit as well.
  for i:=0 to EntriesThisDisk-1 do
    begin
    FZipStream.ReadBuffer(CentralHdr, SizeOf(CentralHdr));
    With CentralHdr do
      begin
      if Signature<>CENTRAL_FILE_HEADER_SIGNATURE then
        raise EZipError.CreateFmt(SErrCorruptZIP,[FileName]);
      NewNode:=FEntries.Add as TFullZipFileEntry;
      // Header position will be corrected later with zip64 version, if needed..
      NewNode.HdrPos := Local_Header_Offset;
      NewNode.FBitFlags:=Bit_Flag;
      NewNode.FCompressMethod := Compress_Method;
      SetLength(S,Filename_Length);
      FZipStream.ReadBuffer(S[1],Filename_Length);
      if Bit_Flag and EFS_LANGUAGE_ENCODING_FLAG <> 0 then
        SetCodePage(S, CP_UTF8, False);
      SavePos:=FZipStream.Position; //After fixed part of central directory...
      // and the filename; before any extra field(s)
      NewNode.ArchiveFileName:=S;
      // Size/compressed size will be adjusted by zip64 entries if needed...
      NewNode.Size:=Uncompressed_Size;
      NewNode.FCompressedSize:=Compressed_Size;
      NewNode.CRC32:=CRC32;
      NewNode.OS := MadeBy_Version shr 8;
      if NewNode.OS = OS_UNIX then
        NewNode.Attributes := External_Attributes shr 16
      else
        NewNode.Attributes := External_Attributes;
      ZipDateTimeToDateTime(Last_Mod_Date,Last_Mod_Time,D);
      NewNode.DateTime:=D;

      // Go through any extra fields and extract any zip64 info
      if Extra_Field_Length>0 then
        begin
        while (FZipStream.Position<SavePos+Extra_Field_Length) do
          begin
          FZipStream.ReadBuffer(ExtraFieldHeader, SizeOf(ExtraFieldHeader));
          if ExtraFieldHeader.Header_ID = ZIP64_HEADER_ID then
            begin
            FZipStream.ReadBuffer(Zip64Field, SizeOf(Zip64Field));
            if Zip64Field.Compressed_Size > 0 then
              NewNode.FCompressedSize := Zip64Field.Compressed_Size;
            if Zip64Field.Original_Size>0 then
              NewNode.Size := Zip64Field.Original_Size;
            if Zip64Field.Relative_Hdr_Offset<>0 then
              begin
              if Zip64Field.Relative_Hdr_Offset>High(Int64) then
                raise EZipError.CreateFmt(SErrPosTooLarge,[Zip64Field.Relative_Hdr_Offset,High(Int64)]);
              NewNode.HdrPos := Zip64Field.Relative_Hdr_Offset;
              end;
            end
            // infozip unicode path extra field
          else if ExtraFieldHeader.Header_ID = INFOZIP_UNICODE_PATH_ID then
            begin
            FZipStream.ReadBuffer(Infozip_unicode_path_ver,1);
            if Infozip_unicode_path_ver=1 then
              begin
              FZipStream.ReadBuffer(Infozip_unicode_path_crc32,sizeof(Infozip_unicode_path_crc32));
              if CRC32Str(S)=Infozip_unicode_path_crc32 then
                begin
                SetLength(U,ExtraFieldHeader.Data_Size-5);
				FZipStream.ReadBuffer(U[1],Length(U));
                NewNode.UTF8ArchiveFileName:=U;
                end
              else
                FZipStream.Seek(ExtraFieldHeader.Data_Size-5,soFromCurrent);
              end
            else
              FZipStream.Seek(ExtraFieldHeader.Data_Size-1,soFromCurrent);
            end
          else
            begin
              // Read past non-Zip64 extra field
              FZipStream.Seek(ExtraFieldHeader.Data_Size,soFromCurrent);
            end;
          end;
        end;
      // Move past extra fields and file comment to next header
      if File_Comment_Length > 0 then
          FZipStream.Seek(File_Comment_Length,soFromCurrent);
      // this doesn't work properly when zip file size is over 4Gb, so commented off
      //FZipStream.Seek(SavePos+Extra_Field_Length+File_Comment_Length,soFromBeginning);
      end;
    end;
end;

function TUnZipper.CreateDeCompressor(Item: TZipFileEntry; AMethod: Word;
  AZipFile, AOutFile: TStream): TDeCompressor;
begin
  case AMethod of
    8 :
      Result:=TInflater.Create(AZipFile,AOutFile,FBufSize);
  else
    raise EZipError.CreateFmt(SErrUnsupportedCompressionFormat,[AMethod]);
  end;
  FCurrentDecompressor:=Result;
end;

procedure TUnZipper.UnZipOneFile(Item: TFullZipFileEntry);

Var
  ZMethod : Word;
{$ifdef unix}
  LinkTargetStream: TStringStream;
{$endif}
  OutputFileName: RawByteString;
  FOutStream: TStream;
  IsLink: Boolean;
  IsCustomStream: Boolean;
  IsOpenedHere: Boolean;
  U : UnicodeString;

  Procedure SetAttributes;
  Var
    Attrs : Longint;
  begin
    // set attributes
    FileSetDate(OutputFileName, DateTimeToFileDate(Item.DateTime));
    if (Item.Attributes <> 0) then
      begin
      Attrs := 0;
      {$IFDEF UNIX}
      if (Item.OS in [OS_UNIX,OS_OSX]) then Attrs := Item.Attributes;
      if (Item.OS in [OS_FAT,OS_NTFS,OS_OS2,OS_VFAT]) then
        Attrs := ZipFatAttrsToUnixAttrs(Item.Attributes);
      {$ELSE}
      if (Item.OS in [OS_FAT,OS_NTFS,OS_OS2,OS_VFAT]) then Attrs := Item.Attributes;
      if (Item.OS in [OS_UNIX,OS_OSX]) then
        Attrs := ZipUnixAttrsToFatAttrs(ExtractFileName(Item.ArchiveFileName), Item.Attributes);
      {$ENDIF}
      if Attrs <> 0 then
        begin
        {$IFDEF UNIX}
        FpChmod(OutputFileName, Attrs);
        {$ELSE}
        FileSetAttr(OutputFileName, Attrs);
        {$ENDIF}
        end;
      end;
  end;

  procedure DoUnzip(const Dest: TStream);

  begin
    if ZMethod=0 then
      begin
      if (LocalHdr.Compressed_Size<>0) then
        begin
        if LocalZip64Fld.Compressed_Size>0 then
          Dest.CopyFrom(FZipStream,LocalZip64Fld.Compressed_Size)
        else
          Dest.CopyFrom(FZipStream,LocalHdr.Compressed_Size);
        {$warning TODO: Implement CRC Check}
        end;
      end
    else
      With CreateDecompressor(Item, ZMethod, FZipStream, Dest) do
        Try
          FTotPos := Self.FTotPos;
          FTotSize := Self.FTotSize;
          OnProgress:=Self.OnProgress;
          OnProgressEx := Self.OnProgressEx;
          OnPercent:=Self.OnPercent;
          OnProgress:=Self.OnProgress;
          OnPercent:=Self.OnPercent;
          DeCompress;
          Self.FTotPos := FTotPos;
          if Item.CRC32 <> Crc32Val then
            raise EZipError.CreateFmt(SErrInvalidCRC,[Item.ArchiveFileName]);
        Finally
          FCurrentDecompressor:=Nil;
          Free;
        end;
  end;

  Procedure GetOutputFileName;

  Var
    I : Integer;

  begin
    if Not UseUTF8 then
      OutputFileName:=StringReplace(Item.DiskFileName,'/',DirectorySeparator,[rfReplaceAll])
    else
      begin
      // Sets codepage.
      OutputFileName:=Item.UTF8DiskFileName;
      U:=UTF8Decode(OutputFileName);
      // Do not use stringreplace, it will mess up the codepage.
      if '/'<>DirectorySeparator then
        For I:=1 to Length(U) do
          if U[i]='/' then
            U[i]:=DirectorySeparator;
      OutputFileName:=UTF8Encode(U);
      end;
    if (Not IsCustomStream) then
      begin
      if Flat then
        OutputFileName:=ExtractFileName(OutputFileName);
      if (FOutputPath<>'') then
        begin
        // Do not use IncludeTrailingPathdelimiter
        OutputFileName:=FOutputPath+OutputFileName;
        end;
      end;
  end;

Begin
  IsOpenedHere:=FZipStream = nil;
  if IsOpenedHere then
    OpenInput;

  ReadZipHeader(Item, ZMethod);
  if (Item.BitFlags and ZIPBITFLAG_ENCRYPTION)<>0 then
    Raise EZipError.CreateFmt(SErrEncryptionNotSupported,[Item.ArchiveFileName]);
  if (Item.BitFlags and ZIPBITFLAG_PATCH_SET)<>0 then
    Raise EZipError.CreateFmt(SErrPatchSetNotSupported,[Item.ArchiveFileName]);
  // Normalize output filename to conventions of target platform.
  // Zip file always has / path separators
  IsCustomStream := Assigned(FOnCreateStream);
  GetOutputFileName;
  IsLink := Item.IsLink;
{$IFNDEF UNIX}
  if IsLink and Not IsCustomStream then
    begin
    {$warning TODO: Implement symbolic link creation for non-unix, e.g.
    Windows NTFS}
    IsLink := False;
    end;
{$ENDIF}
  if IsCustomStream then
    begin
    try
      OpenOutput(OutputFileName, FOutStream, Item);
      if (IsLink = False) and (Item.IsDirectory = False) then
        DoUnzip(FOutStream);
    Finally
      CloseOutput(Item, FOutStream);
    end;
    end
  else
    begin
    if IsLink then
      begin
      {$IFDEF UNIX}
        LinkTargetStream := TStringStream.Create('');
        try
          DoUnzip(LinkTargetStream);
          fpSymlink(PAnsiChar(LinkTargetStream.DataString), PAnsiChar(OutputFileName));
        finally
          LinkTargetStream.Free;
        end;
      {$ENDIF}
      end
    else if Item.IsDirectory then
      begin
        if (NOT Flat) then ForceDirectories(OutputFileName);
      end
    else
      begin
      try
        OpenOutput(OutputFileName, FOutStream, Item);
        DoUnzip(FOutStream);
      Finally
        CloseOutput(Item, FOutStream);
      end;
      end;
    SetAttributes;
    end;

  if IsOpenedHere then
    CloseInput;
end;

Function TUnZipper.IsMatch(I : TFullZipFileEntry) : Boolean;

begin
  if UseUTF8 then
    Result:=(FFiles.IndexOf(I.UTF8ArchiveFileName)<>-1)
  else
    Result:=(FFiles.IndexOf(I.ArchiveFileName)<>-1)
end;

Function TUnZipper.CalcTotalSize(AllFiles : Boolean) : Int64;

Var
  I,cnt : Integer;
  Item : TFullZipFileEntry;

begin
  Result:=0;
  cnt:=FFiles.Count;
  if cnt=0 then cnt:=FEntries.Count;
  for i:=0 to FEntries.Count-1 do
    begin
    Item := FEntries[i];
    if AllFiles or IsMatch(Item) then
      begin
        Result := Result + TZipFileEntry(Item).Size;
        dec(cnt);
        if cnt=0 then break;
      end;
    end;
end;

procedure TUnZipper.UnZipAllFiles;


Var
  Item : TFullZipFileEntry;
  I, cnt : integer;
  AllFiles : Boolean;

Begin
  FTerminated:=False;
  FUnZipping:=True;
  Try
    AllFiles:=(FFiles.Count=0);
    OpenInput;
    Try
      if FEntries.Count=0 then
      ReadZipDirectory;
      FTotPos := 0;
      if Assigned(FOnProgressEx) and not Terminated then
        FTotSize := CalcTotalSize(AllFiles);
      i:=0;
      cnt:=FFiles.Count;
      if cnt=0 then cnt:=FEntries.Count;
      While (I<FEntries.Count) and not Terminated do
        begin
        Item:=FEntries[i];
        if AllFiles or IsMatch(Item) then
        begin
          UnZipOneFile(Item);
          dec(cnt);
          if cnt=0 then break;
        end;
        inc(I);
        end;
      if Assigned(FOnProgressEx) and not Terminated then
        FOnProgressEx(Self, FTotPos, FTotSize);
    Finally
      CloseInput;
    end;
  finally
    FUnZipping:=False;
  end;
end;


procedure TUnZipper.UnZipFile(const AZipFileName, aExtractFileName: RawByteString);
var
  I : integer;
begin
  FileName:=AZipFileName;

  FTerminated:=False;
  FUnZipping:=True;
  Try
    OpenInput;
    Try
      if FEntries.Count=0 then
        ReadZipDirectory;

      i:=0;
      if UseUTF8 then
      begin
        While I<FEntries.Count do
        begin
          if CompareText(FEntries[I].UTF8ArchiveFileName,aExtractFileName)=0 then break;
          inc(I);
        end;
      end
      else
      begin
        While I<FEntries.Count do
        begin
          if CompareText(FEntries[I].ArchiveFileName,aExtractFileName)=0 then break;
          inc(I);
        end;
      end;

      if I<FEntries.Count then
        UnZipOneFile(FEntries[I]);

    Finally
      CloseInput;
    end;
  finally
    FUnZipping:=False;
  end;
end;

procedure TUnZipper.SetBufSize(Value: LongWord);

begin
  If FUnZipping then
    Raise EZipError.Create(SErrBufsizeChange);
  If Value>=DefaultBufSize then
    FBufSize:=Value;
end;

procedure TUnZipper.SetFileName(Value: RawByteString);

begin
  If FUnZipping then
    Raise EZipError.Create(SErrFileChange);
  if CompareText(FFileName,Value)<>0 then
  begin
    FFileName:=Value;
    FEntries.Clear;
  end;
end;

procedure TUnZipper.SetOutputPath(Value: RawByteString);

Var
  DS : RawByteString;

begin
  If FUnZipping then
    Raise EZipError.Create(SErrFileChange);
  FOutputPath:=Value;
  If (FOutputPath<>'') and (FoutputPath[Length(FoutputPath)]<>DirectorySeparator) then
    begin
    // Preserve codepage of outputpath
    DS:=DirectorySeparator;
    SetCodePage(DS,StringCodePage(FoutputPath),False);
    FOutputPath:=FoutputPath+DS;
    end;
end;

procedure TUnZipper.UnZipFile(const aExtractFileName: RawByteString);
begin
  UnzipFile(FFileName, aExtractFileName);
end;

procedure TUnZipper.UnZipFiles(const AZipFileName: RawByteString; FileList: TStrings);

begin
  FFileName:=AZipFileName;
  UnZipFiles(FileList);
end;

procedure TUnZipper.UnZipFiles(const AZipFileName: RawByteString; aFileList: array of RawBytestring);

Var
  L : TStringList;
  S : RawByteString;

begin
  L:=TStringList.Create;
  try
    L.Capacity:=Length(aFileList);
    for S in aFileList do
      L.Add(S);
    UnZipFiles(aZipFileName,L);
  finally
    L.Free;
  end;
end;

procedure TUnZipper.UnZipFiles(aFileList: TStrings);
begin
  FFiles.Assign(aFileList);
  UnZipAllFiles;
end;

procedure TUnZipper.UnZipAllFiles(const AZipFileName: RawByteString);

begin
  FFileName:=AZipFileName;
  UnZipAllFiles;
end;

class procedure TUnZipper.Unzip(const AZipFileName: RawByteString);

begin
  With Self.Create do
    try
      FileName:=aZipFileName;
      UnZipAllFiles;
    finally
      Free;
    end;
end;

class procedure TUnZipper.Unzip(const AZipFileName: RawByteString; aExtractFileName: RawByteString);

begin
  With Self.Create do
    try
      UnZipFile(aZipFileName,aExtractFileName);
    finally
      Free;
    end;
end;

Type

  { TCustomExtractor }

  TCustomExtractor = Class(TObject)
  Private
    FStream : TStream;
    FunZipper  : TUnzipper;
    procedure DoCreateStream(Sender: TObject; var AStream: TStream; AItem: TFullZipFileEntry);
  Public
    Constructor Create(aUnZipper : TUnzipper);
    Destructor Destroy; override;
    Procedure UnZip(const AZipFileName, aExtractFileName: RawByteString; aOutputFileName: AnsiString);
  end;

{ TCustomExtractor }

procedure TCustomExtractor.DoCreateStream(Sender: TObject; var AStream: TStream; AItem: TFullZipFileEntry);
begin
  aStream:=FStream;
  FStream:=Nil;
end;

constructor TCustomExtractor.Create(aUnZipper: TUnzipper);
begin
  FStream:=Nil;
  FUnzipper:=aUnzipper;
end;

destructor TCustomExtractor.Destroy;
begin
  FreeAndNil(FUnZipper);
  FreeAndNil(FStream);
  Inherited;
end;

procedure TCustomExtractor.UnZip(const AZipFileName, aExtractFileName: RawByteString; aOutputFileName: AnsiString);
begin
  FStream:=TFileStream.Create(aOutputFileName,fmCreate);
  FUnZipper.OnCreateStream:=@DoCreateStream;
  FUnzipper.UnzipFile(aZipFileName,aExtractFileName);
end;

class procedure TUnZipper.UnZip(const AZipFileName, aExtractFileName: RawByteString; aOutputFileName: AnsiString);



begin
  With TCustomExtractor.Create(Self.Create) do
    try
      Unzip(aZipFileName,aExtractFileName,aOutputFileName);
    Finally
      Free;
    end;
end;

class procedure TUnZipper.Unzip(const AZipFileName: RawByteString; aFileList: array of RawByteString);
begin
  With Self.Create do
    try
      UnZipFiles(aZipFileName,aFileList);
    finally
      Free;
    end;
end;

class procedure TUnZipper.Unzip(const AZipFileName: RawByteString; aFileList: TStrings);
begin
  With Self.Create do
    try
      UnZipFiles(aZipFileName,aFileList);
    finally
      Free;
    end;
end;

class procedure TUnZipper.Unzip(const AZipFileName: RawByteString; aFileList: array of RawByteString; aOutputDir: RawByteString;
  aFlat: Boolean);
begin
  With Self.Create do
    try
      Flat:=aFlat;
      OutputPath:=aOutputDir;
      UnZipFiles(aZipFileName,aFileList);
    finally
      Free;
    end;
end;

class procedure TUnZipper.Unzip(const AZipFileName: RawByteString; aFileList: TStrings; aOutputDir: RawByteString; aFlat: Boolean);
begin
  With Self.Create do
    try
      Flat:=aFlat;
      OutputPath:=aOutputDir;
      UnZipFiles(aZipFileName,aFileList);
    finally
      Free;
    end;
end;

procedure TUnZipper.DoEndOfFile;

Var
  ComprPct : Double;
  Uncompressed: QWord;
  Compressed: QWord;
begin
  If LocalZip64Fld.Original_Size > 0 then
    Uncompressed := LocalZip64Fld.Original_Size
  else
    Uncompressed := LocalHdr.Uncompressed_Size;

  If LocalZip64Fld.Compressed_Size > 0 then
    Compressed := LocalZip64Fld.Compressed_Size
  else
    Compressed := LocalHdr.Compressed_Size;

  If (Compressed>0) and (Uncompressed>0) then
    if (Compressed>Uncompressed) then
      ComprPct := (-100.0 * (Compressed - Uncompressed)) / Uncompressed
    else
      ComprPct := (100.0 * (Uncompressed - Compressed)) / Uncompressed
  else
    ComprPct := 0;
  If Assigned(FOnEndOfFile) then
    FOnEndOfFile(Self,ComprPct);
end;

constructor TUnZipper.Create;

begin
  FBufSize:=DefaultBufSize;
  FFiles:=TStringList.Create;
  TStringlist(FFiles).Sorted:=True;
  FEntries:=TFullZipFileEntries.Create(TFullZipFileEntry);
  FOnPercent:=1;
end;

procedure TUnZipper.Clear;

begin
  FFiles.Clear;
  FEntries.Clear;
end;

procedure TUnZipper.Examine;
begin
  if (FOnOpenInputStream = nil) and (FFileName='') then
    Raise EZipError.Create(SErrNoFileName);
  OpenInput;
  If (FZipStream=nil) then
    Raise EZipError.Create(SErrNoStream);
  Try
    ReadZipDirectory;
  Finally
    CloseInput;
  end;
end;

procedure TUnZipper.Terminate;
begin
  FTerminated:=True;
  if Assigned(FCurrentDecompressor) then
    FCurrentDecompressor.Terminate;
end;

destructor TUnZipper.Destroy;

begin
  Clear;
  FreeAndNil(FFiles);
  FreeAndNil(FEntries);
  Inherited;
end;

{ TZipFileEntry }

function TZipFileEntry.GetArchiveFileName: AnsiString;
begin
  Result:=FArchiveFileName;
  If (Result='') then
    Result:=FDiskFileName;
end;

function TZipFileEntry.GetUTF8ArchiveFileName: UTF8String;
begin
  Result:=FUTF8FileName;
  If Result='' then
    Result:=ArchiveFileName;
end;

function TZipFileEntry.GetUTF8DiskFileName: UTF8String;
begin
  Result:=FUTF8DiskFileName;
  If Result='' then
    Result:=DiskFileName;
end;

constructor TZipFileEntry.Create(ACollection: TCollection);

begin
{$IFDEF UNIX}
  FOS := OS_UNIX;
{$ELSE}
  FOS := OS_FAT;
{$ENDIF}
  FCompressionLevel:=cldefault;
  FDateTime:=now;
  FNeedsZip64:=false;
  FAttributes:=0;

  inherited create(ACollection);
end;

function TZipFileEntry.IsDirectory: Boolean;
begin
  Result := (DiskFileName <> '') and (DiskFileName[Length(DiskFileName)] = DirectorySeparator);
  if Attributes <> 0 then
  begin
    case OS of
      OS_FAT: Result := (faDirectory and Attributes) > 0;
      OS_UNIX: Result := (Attributes and UNIX_MASK) = UNIX_DIR;
    end;
  end;
end;

function TZipFileEntry.IsLink: Boolean;
begin
  Result := False;
  if Attributes <> 0 then
  begin
    case OS of
      OS_FAT: Result := (faSymLink and Attributes) > 0;
      OS_UNIX: Result := (Attributes and UNIX_MASK) = UNIX_LINK;
    end;
  end;
end;

procedure TZipFileEntry.SetArchiveFileName(const AValue: AnsiString);

begin
  if FArchiveFileName=AValue then Exit;
  // Zip standard: filenames inside the zip archive have / path separator
  if DirectorySeparator='/' then
    FArchiveFileName:=AValue
  else
    FArchiveFileName:=StringReplace(AValue, DirectorySeparator, '/', [rfReplaceAll]);
end;

procedure TZipFileEntry.SetDiskFileName(const AValue: AnsiString);
begin
  if FDiskFileName=AValue then Exit;
  // Zip file uses / as directory separator on all platforms
  // so convert to separator used on current OS
  if DirectorySeparator='/' then
    FDiskFileName:=AValue
  else
    FDiskFileName:=StringReplace(AValue,'/',DirectorySeparator,[rfReplaceAll]);
end;

procedure TZipFileEntry.SetUTF8ArchiveFileName(AValue: UTF8String);
begin
  FUTF8FileName:=AValue;
  If ArchiveFileName='' then
    if DefaultSystemCodePage<>CP_UTF8 then
      ArchiveFileName:=Utf8ToAnsi(AValue)
    else
      ArchiveFileName:=AValue;
end;

procedure TZipFileEntry.SetUTF8DiskFileName(AValue: UTF8String);
begin
  FUTF8DiskFileName:=AValue;
  If DiskFileName='' then
    if DefaultRTLFileSystemCodePage<>CP_UTF8 then
      DiskFileName:=Utf8ToAnsi(AValue)
    else
      DiskFileName:=AValue;
end;


procedure TZipFileEntry.Assign(Source: TPersistent);

Var
  Z : TZipFileEntry;

begin
  if Source is TZipFileEntry then
    begin
    Z:=Source as TZipFileEntry;
    FArchiveFileName:=Z.FArchiveFileName;
    FDiskFileName:=Z.FDiskFileName;
    FSize:=Z.FSize;
    FDateTime:=Z.FDateTime;
    FStream:=Z.FStream;
    FOS:=Z.OS;
    FAttributes:=Z.Attributes;
    end
  else
    inherited Assign(Source);
end;

{ TZipFileEntries }

function TZipFileEntries.GetZ(AIndex : Integer): TZipFileEntry;
begin
  Result:=TZipFileEntry(Items[AIndex]);
end;

procedure TZipFileEntries.SetZ(AIndex : Integer; const AValue: TZipFileEntry);
begin
  Items[AIndex]:=AValue;
end;

function TZipFileEntries.AddFileEntry(const ADiskFileName: AnsiString): TZipFileEntry;
begin
  Result:=Add as TZipFileEntry;
  Result.DiskFileName:=ADiskFileName;
end;

function TZipFileEntries.AddFileEntry(const ADiskFileName,
  AArchiveFileName: AnsiString): TZipFileEntry;
begin
  Result:=AddFileEntry(ADiskFileName);
  Result.ArchiveFileName:=AArchiveFileName;
end;

function TZipFileEntries.AddFileEntry(const AStream: TSTream;
  const AArchiveFileName: AnsiString): TZipFileEntry;
begin
  Result:=Add as TZipFileEntry;
  Result.Stream:=AStream;
  Result.ArchiveFileName:=AArchiveFileName;
end;

Procedure TZipFileEntries.AddFileEntries(Const List : TStrings);

Var
  I : integer;

begin
  For I:=0 to List.Count-1 do
    AddFileEntry(List[i]);
end;

{ TFullZipFileEntries }

function TFullZipFileEntries.GetFZ(AIndex : Integer): TFullZipFileEntry;
begin
  Result:=TFullZipFileEntry(Items[AIndex]);
end;

procedure TFullZipFileEntries.SetFZ(AIndex : Integer;
  const AValue: TFullZipFileEntry);
begin
  Items[AIndex]:=AValue;
end;


{$pop}

end.
