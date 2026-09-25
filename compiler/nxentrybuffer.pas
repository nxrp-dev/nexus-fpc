{
    NexusFPC contiguous storage for entry-based compiler files.

    This program is Free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.
}
unit NXEntryBuffer;

{$I fpcdefs.inc}

interface

uses
  CStreams;

type
  TNXEntryBuffer = class
  private
    FData: Pointer;
    FCapacity: LongInt;
    FSize: LongInt;
    FPosition: LongInt;
    procedure EnsureCapacity(RequiredCapacity: LongInt);
  public
    constructor Create(InitialCapacity: LongInt);
    destructor Destroy; override;
    procedure Reset; inline;
    function Current: Pointer; inline;
    function Remaining: LongInt; inline;
    procedure Advance(Count: LongInt); inline;
    procedure Retreat(Count: LongInt); inline;
    function Read(out Buffer; Count: LongInt): LongInt;
    procedure ReadExact(out Buffer; Count: LongInt); inline;
    procedure Write(const Buffer; Count: LongInt); inline;
    procedure Patch(Offset: LongInt; const Buffer; Count: LongInt); inline;
    function LoadFromStream(Stream: TCStream; Count: LongInt): LongInt;
    procedure SaveToStream(Stream: TCStream);
    property Data: Pointer read FData;
    property Capacity: LongInt read FCapacity;
    property Size: LongInt read FSize;
    property Position: LongInt read FPosition;
  end;

implementation

constructor TNXEntryBuffer.Create(InitialCapacity: LongInt);
begin
  inherited Create;
  FData:=nil;
  FCapacity:=0;
  FSize:=0;
  FPosition:=0;
  if InitialCapacity>0 then
    EnsureCapacity(InitialCapacity);
end;

destructor TNXEntryBuffer.Destroy;
begin
  if Assigned(FData) then
    FreeMem(FData, FCapacity);
  inherited Destroy;
end;

procedure TNXEntryBuffer.EnsureCapacity(RequiredCapacity: LongInt);
var
  NewCapacity: LongInt;
  NewData: Pointer;
begin
  if RequiredCapacity<=FCapacity then
    Exit;
  NewCapacity:=FCapacity;
  if NewCapacity=0 then
    NewCapacity:=16384;
  while NewCapacity<RequiredCapacity do
    NewCapacity:=NewCapacity*2;
  GetMem(NewData, NewCapacity);
  if FSize>0 then
    Move(FData^, NewData^, FSize);
  if Assigned(FData) then
    FreeMem(FData, FCapacity);
  FData:=NewData;
  FCapacity:=NewCapacity;
end;

procedure TNXEntryBuffer.Reset;
begin
  FSize:=0;
  FPosition:=0;
end;

function TNXEntryBuffer.Current: Pointer;
begin
  Result:=Pointer(PtrUInt(FData)+PtrUInt(FPosition));
end;

function TNXEntryBuffer.Remaining: LongInt;
begin
  Result:=FSize-FPosition;
end;

procedure TNXEntryBuffer.Advance(Count: LongInt);
begin
  Inc(FPosition, Count);
end;

procedure TNXEntryBuffer.Retreat(Count: LongInt);
begin
  Dec(FPosition, Count);
end;

function TNXEntryBuffer.Read(out Buffer; Count: LongInt): LongInt;
begin
  Result:=Remaining;
  if Result>Count then
    Result:=Count;
  if Result>0 then
    begin
      Move(Current^, Buffer, Result);
      Inc(FPosition, Result);
    end;
end;

procedure TNXEntryBuffer.ReadExact(out Buffer; Count: LongInt);
begin
  if Count>0 then
    begin
      Move(Current^, Buffer, Count);
      Inc(FPosition, Count);
    end;
end;

procedure TNXEntryBuffer.Write(const Buffer; Count: LongInt);
var
  NewPosition: LongInt;
begin
  if Count<=0 then
    Exit;
  NewPosition:=FPosition+Count;
  if NewPosition>FCapacity then
    EnsureCapacity(NewPosition);
  Move(Buffer, Current^, Count);
  FPosition:=NewPosition;
  if FPosition>FSize then
    FSize:=FPosition;
end;

procedure TNXEntryBuffer.Patch(Offset: LongInt; const Buffer; Count: LongInt);
begin
  if Count>0 then
    Move(Buffer, Pointer(PtrUInt(FData)+PtrUInt(Offset))^, Count);
end;

function TNXEntryBuffer.LoadFromStream(Stream: TCStream; Count: LongInt): LongInt;
var
  ReadCount: LongInt;
begin
  Reset;
  if Count<=0 then
    Exit(0);
  EnsureCapacity(Count);
  Result:=0;
  repeat
    ReadCount:=Stream.Read(Pointer(PtrUInt(FData)+PtrUInt(Result))^,Count-Result);
    if ReadCount<=0 then
      Break;
    Inc(Result,ReadCount);
  until Result=Count;
  FSize:=Result;
end;

procedure TNXEntryBuffer.SaveToStream(Stream: TCStream);
var
  Written: LongInt;
  WriteCount: LongInt;
begin
  Written:=0;
  while Written<FSize do
    begin
      WriteCount:=Stream.Write(Pointer(PtrUInt(FData)+PtrUInt(Written))^,FSize-Written);
      if WriteCount<=0 then
        Break;
      Inc(Written,WriteCount);
    end;
end;

end.
