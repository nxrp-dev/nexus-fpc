{
    Copyright (c) 1998-2002 by Peter Vreman

    Contains the base stuff for writing for object files to disk

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
unit owbase;

{$i fpcdefs.inc}

interface

uses
  GlobType,
  CStreams,
  CClasses;

type
  TObjectWriter=class
  private
    f      : TCCustomFileStream;
    opened : boolean;
    buf    : TAnsiCharDynArray;
    bufidx : LongWord;
    procedure WriteBuf;
  protected
    fsize,
    fobjsize  : LongWord;
  public
    constructor create;
    constructor createAr(const Aarfn:string);virtual;
    destructor  Destroy;override;
    function  CreateFile(const fn:string):boolean;virtual;
    procedure CloseFile;virtual;
    procedure writesym(const sym:string);virtual;
    procedure write(const b;len:LongWord);virtual;
    procedure WriteZeros(l:LongWord);
    procedure writearray(a:TDynamicArray);
    property Size:LongWord read FSize;
    property ObjSize:LongWord read FObjSize;
  end;

  TObjectWriterClass = class of TObjectWriter;

  { tobjectreader }

  TObjectReader=class
  private
    f      : TCCustomFileStream;
    opened : boolean;
    buf    : TAnsiCharDynArray;
    ffilename : string;
    bufidx,
    bufmax : LongInt;
    function ReadBuf:boolean;
  protected
    function getfilename : string;virtual;
    function GetSize: LongInt;virtual;
    function GetPos: LongInt;virtual;
    function GetIsArchive: boolean;virtual;
  public
    constructor create;
    constructor createAr(const Aarfn:string;allow_nonar:boolean=false);virtual;
    destructor  Destroy;override;
    function  openfile(const fn:string):boolean;virtual;
    procedure CloseFile;virtual;
    procedure seek(len:LongInt);virtual;
    function  read(out b;len:LongInt):boolean;virtual;
    function  readarray(a:TDynamicArray;len:LongInt):boolean;
    property FileName : string read getfilename;
    property size:LongInt read GetSize;
    property Pos:LongInt read GetPos;
    property IsArchive: boolean read GetIsArchive;
  end;

  TObjectReaderClass = class of TObjectReader;

implementation

uses
   SysUtils,
   Verbose, Globals;

const
  BufSize = 32768;


{****************************************************************************
                              TObjectWriter
****************************************************************************}

constructor TObjectWriter.create;
begin
  SetLength(buf,BufSize);
  bufidx:=0;
  opened:=false;
  fsize:=0;
end;


destructor TObjectWriter.Destroy;
begin
  if opened then
   CloseFile;
  buf:=nil;
end;

constructor TObjectWriter.createAr(const Aarfn:string);
begin
  InternalError(2015041901);
end;


function TObjectWriter.CreateFile(const fn:string):boolean;
begin
  CreateFile:=false;
  f:=CFileStreamClass.Create(fn,fmCreate);
  if CStreamError<>0 then
    begin
       Message2(exec_e_cant_create_objectfile,fn,IntToStr(CStreamError));
       exit;
    end;
  bufidx:=0;
  fsize:=0;
  fobjsize:=0;
  opened:=true;
  CreateFile:=true;
end;


procedure TObjectWriter.CloseFile;
var
  fn : string;
begin
  if bufidx>0 then
   WriteBuf;
  fn:=f.FileName;
  f.free;
  f := nil;
{ Remove if size is 0 }
  if size=0 then
   DeleteFile(fn);
  opened:=false;
  fsize:=0;
  fobjsize:=0;
end;


procedure TObjectWriter.WriteBuf;
begin
  f.write(buf[0],bufidx);
  bufidx:=0;
end;


procedure TObjectWriter.writesym(const sym:string);
begin
end;


procedure TObjectWriter.write(const b;len:LongWord);
var
  p   : pchar;
  bufleft,
  idx : LongWord;
begin
  inc(fsize,len);
  inc(fobjsize,len);
  p:=pchar(@b);
  idx:=0;
  while len>0 do
   begin
     bufleft:=BufSize-bufidx;
     if bufleft=0 then
       WriteBuf;
     if len>bufleft then
      begin
        move(p[idx],buf[bufidx],bufleft);
        dec(len,bufleft);
        inc(idx,bufleft);
        inc(bufidx,bufleft);
        WriteBuf;
      end
     else
      begin
        move(p[idx],buf[bufidx],len);
        inc(bufidx,len);
        exit;
      end;
   end;
end;


procedure TObjectWriter.WriteZeros(l:LongWord);
var
  empty : array[0..1023] of byte;
begin
  if l>sizeof(empty) then
    begin
      fillchar(empty,sizeof(empty),0);
      while l>sizeof(empty) do
        begin
          Write(empty,sizeof(empty));
          Dec(l,sizeof(empty));
        end;
      if l>0 then
        Write(empty,l);
    end
  else if l>0 then
    begin
      fillchar(empty,l,0);
      Write(empty,l);
    end;
end;


procedure TObjectWriter.writearray(a:TDynamicArray);
var
  hp : PDynamicBlock;
begin
  hp:=a.firstblock;
  while Assigned(hp) do
    begin
      write(hp^.data,hp^.used);
      hp:=hp^.next;
    end;
end;


{****************************************************************************
                              TObjectReader
****************************************************************************}

constructor TObjectReader.create;
begin
  buf:=nil;
  bufidx:=0;
  bufmax:=0;
  ffilename:='';
  opened:=false;
end;


destructor TObjectReader.Destroy;
begin
  if opened then
    CloseFile;
end;


constructor TObjectReader.createAr(const Aarfn:string;allow_nonar:boolean=false);
begin
  InternalError(2015081401);
end;


function TObjectReader.openfile(const fn:string):boolean;
begin
  openfile:=false;
  f:=CFileStreamClass.Create(fn,fmOpenRead);
  if CStreamError<>0 then
    begin
       Comment(VError,'Can''t open object file: '+fn);
       exit;
    end;
  ffilename:=fn;
  bufmax:=f.Size;
  SetLength(buf,bufmax);
  f.read(buf[0],bufmax);
  f.free;
  f := nil;
  bufidx:=0;
  opened:=true;
  openfile:=true;
end;


procedure TObjectReader.CloseFile;
begin
  opened:=false;
  bufidx:=0;
  bufmax:=0;
  buf:=Nil;
end;


function TObjectReader.ReadBuf:boolean;
begin
  result:=bufidx<bufmax;
end;


procedure TObjectReader.seek(len:LongInt);
begin
  bufidx:=len;
end;


function TObjectReader.read(out b;len:LongInt):boolean;
begin
  result:=true;
  if bufidx+len>bufmax then
    begin
      result:=false;
      len:=bufmax-bufidx;
    end;
  move(buf[bufidx],b,len);
  inc(bufidx,len);
end;


function TObjectReader.readarray(a:TDynamicArray;len:LongInt):boolean;
begin
  result:=true;
  if bufidx+len>bufmax then
    begin
      result:=false;
      len:=bufmax-bufidx;
    end;
  a.write(buf[bufidx],len);
  inc(bufidx,len);
end;

function TObjectReader.getfilename : string;
  begin
    result:=ffilename;
  end;

function TObjectReader.GetSize: LongInt;
  begin
    result:=bufmax;
  end;

function TObjectReader.GetPos: LongInt;
  begin
    Result:=bufidx;
  end;


function TObjectReader.GetIsArchive: boolean;
  begin
    Result:=false;
  end;

end.
