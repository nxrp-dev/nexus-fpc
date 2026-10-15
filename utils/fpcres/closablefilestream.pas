{

    FPCRes - Free Pascal Resource Converter
    Part of the Free Pascal distribution
    Copyright (C) 2008-2010 by Giulio Bernardi

    Support for file streams that can be temporarily closed

    See the file COPYING, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
}

unit ClosableFileStream;

{$MODE OBJFPC} {$H+}

interface

uses
  Classes, SysUtils;

type
  TClosableFileNotifier = class;

  { TClosableFileStream }

  TClosableFileStream = class(TStream)
  private
    FStream : TFileStream;
    FFileName : string;
    FMode : Word;
    FListener : TClosableFileNotifier;
    FPosition : Int64;
    procedure EnsureHandleOpen;
  protected
    procedure SetSize(const NewSize: Int64); override;
    function RetryOpen : Boolean;
  public
    constructor Create(const AFileName: String; Mode: Word);
    destructor Destroy; override;
    function Read(var Buffer; Count: LongInt): LongInt; override;
    function Write(const Buffer; Count: LongInt): LongInt; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
    procedure CloseHandle;
end;

TClosableFileNotifier = class
protected
  procedure NotifyFileOpened(AStream : TClosableFileStream); virtual; abstract;
  function NotifyOpenFailed(AStream: TClosableFileStream) : Boolean;
    virtual; abstract;
end;


implementation

type
  PQueueItem = ^TQueueItem;
  TQueueItem = record
    Prev : PQueueItem;
    Next : PQueueItem;
    Data : Pointer;
  end;

  { TFIFOQueue }

  TFIFOQueue = class
  private
    FHead : PQueueItem;
    FTail : PQueueItem;
    FCount : Integer;
  protected
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(P : Pointer);
    function Remove : Pointer;
    property Count : Integer Read FCount;
  end;


  { TFileKeeper }

  TFileKeeper = class(TClosableFileNotifier)
  private
    FOpenFiles : TFIFOQueue;
    FMaxOpen : LongInt;
  private
    procedure CloseFiles(const Count : Integer);
  protected
    procedure NotifyFileOpened(AStream : TClosableFileStream);  override;
    function NotifyOpenFailed(AStream: TClosableFileStream) : Boolean; override;
  public
    constructor Create;
    destructor Destroy; override;
  end;

{ TFIFOQueue }

constructor TFIFOQueue.Create;
begin
  FHead:=nil;
  FTail:=nil;
  FCount:=0;
end;

destructor TFIFOQueue.Destroy;
var
  El : PQueueItem;
begin
  while FHead<>nil do
  begin
    El:=FHead;
    FHead:=FHead^.Next;
    FreeMem(El);
  end;
end;

procedure TFIFOQueue.Add(P: Pointer);
var
  El : PQueueItem;
begin
  El:=GetMem(SizeOf(TQueueItem));
  El^.Data:=P;
  El^.Prev:=nil;
  El^.Next:=FHead;
  if FHead<>nil then
    FHead^.Prev:=El;
  FHead:=El;
  if FTail=nil then
    FTail:=FHead;
  Inc(FCount);
end;

function TFIFOQueue.Remove: Pointer;
var
  El : PQueueItem;
begin
  if FCount=0 then
  begin
    Result:=nil;
    exit;
  end;
  Result:=FTail^.Data;
  El:=FTail;
  FTail:=FTail^.Prev;
  if FTail=nil then
    FHead:=nil
  else
    FTail^.Next:=nil;
  FreeMem(El);
  Dec(FCount);
end;

{ TFileKeeper }

procedure TFileKeeper.CloseFiles(const Count: Integer);
var
  I,Max : Integer;
  Tmp : TClosableFileStream;
begin
  Max:=Count;
  if FOpenFiles.Count<Max then
    Max:=FOpenFiles.Count;
  for I:=0 to Max-1 do
  begin
    Tmp:=TClosableFileStream(FOpenFiles.Remove);
    Tmp.CloseHandle;
  end;
end;

procedure TFileKeeper.NotifyFileOpened(AStream: TClosableFileStream);
begin
   FOpenFiles.Add(AStream);
   if (FOpenFiles.Count>=FMaxOpen) then
     CloseFiles(1);
end;

function TFileKeeper.NotifyOpenFailed(AStream: TClosableFileStream) : Boolean;
var
  Decrement : LongInt;
begin
  Result:=False;
  Decrement:=Round(0.1*FOpenFiles.Count);
  if Decrement<=0 then exit;
  CloseFiles(Decrement);
  Result:=AStream.RetryOpen;
  if Result then
    FMaxOpen:=FOpenFiles.Count+1;
end;

constructor TFileKeeper.Create;
begin
  FOpenFiles:=TFIFOQueue.Create;
  FMaxOpen:=High(LongInt);
end;

destructor TFileKeeper.Destroy;
begin
  FOpenFiles.Free;
end;

var
  FileKeeper : TFileKeeper;

{ TClosableFileStream }

procedure TClosableFileStream.EnsureHandleOpen;
begin
  if FStream<>nil then
    exit;
  try
    FStream:=TFileStream.Create(FFileName,FMode);
  except
    if not FListener.NotifyOpenFailed(Self) then
      raise;
  end;
  FStream.Position:=FPosition;
  FListener.NotifyFileOpened(Self);
end;

procedure TClosableFileStream.SetSize(const NewSize: Int64);
begin
  EnsureHandleOpen;
  FStream.Size:=NewSize;
end;

function TClosableFileStream.RetryOpen: Boolean;
begin
  try
    FStream:=TFileStream.Create(FFileName,FMode);
  except
    Result:=False;
    exit;
  end;
  Result:=True;
end;

constructor TClosableFileStream.Create(const AFileName: String; Mode: Word);
begin
  FListener:=FileKeeper;
  FFileName:=AFileName;
  FMode:=Mode;
  FPosition:=0;
  FStream:=nil;
  EnsureHandleOpen;
  //if the file has been created, ensure that further openings don't recreate
  //it again!
  if FMode=fmCreate then
    FMode:=fmOpenReadWrite;
end;

destructor TClosableFileStream.Destroy;
begin
  if FStream<>nil then
    CloseHandle;
end;

function TClosableFileStream.Read(var Buffer; Count: LongInt): LongInt;
begin
  EnsureHandleOpen;
  Result:=FStream.Read(Buffer,Count);
end;

function TClosableFileStream.Write(const Buffer; Count: LongInt): LongInt;
begin
  EnsureHandleOpen;
  Result:=FStream.Write(Buffer,Count);
end;

function TClosableFileStream.Seek(const Offset: Int64; Origin: TSeekOrigin
  ): Int64;
begin
  EnsureHandleOpen;
  Result:=FStream.Seek(Offset,Origin);
end;

procedure TClosableFileStream.CloseHandle;
begin
  FPosition:=FStream.Position;
  FStream.Free;
  FStream:=nil;
end;

initialization
  FileKeeper:=TFileKeeper.Create;

finalization
  FileKeeper.Destroy;

end.

