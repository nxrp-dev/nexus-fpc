{
    Copyright (c) 1998-2002 by Florian Klaempfl and Peter Vreman

    This module provides stream classes

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
unit cstreams;

{$i fpcdefs.inc}

interface

   uses
     CUtils;


{****************************************************************************
                                  TCStream
****************************************************************************}

    {
      TCStream is copied directly from classesh.inc from the FCL so
      it's compatible with the normal Classes.TStream.

      TCFileStream is a merge of THandleStream and TFileStream and updated
      to have a 'file' type instead of Handle.

      TCCustomMemoryStream and TCMemoryStream are direct copies.
    }
    const
       { TCStream seek origins }
       soFromBeginning = 0;
       soFromCurrent = 1;
       soFromEnd = 2;

       { TCFileStream create mode }
       fmCreate        = $FFFF;
       fmOpenRead      = 0;
       fmOpenWrite     = 1;
       fmOpenReadWrite = 2;

var
{ Used for Error reporting instead of exceptions }
  CStreamError : LongInt;

type
{ Fake TComponent class, it isn't used any further }
  TCComponent = class(TObject)
  end;

{ TCStream abstract class }

  TCStream = class(TObject)
  private
    function GetPosition: LongInt; {$ifdef USEINLINE}inline;{$endif}
    procedure SetPosition(Pos: LongInt); {$ifdef USEINLINE}inline;{$endif}
    function GetSize: LongInt;
  protected
    procedure SetSize(NewSize: LongInt); virtual;
  public
    function Read(var Buffer; Count: LongInt): LongInt; virtual; abstract;
    function Write(const Buffer; Count: LongInt): LongInt; virtual; abstract;
    function Seek(Offset: LongInt; Origin: Word): LongInt; virtual; abstract;
    procedure ReadBuffer(var Buffer; Count: LongInt);
    procedure WriteBuffer(const Buffer; Count: LongInt);
    function CopyFrom(Source: TCStream; Count: LongInt): LongInt;
    function ReadComponent(Instance: TCComponent): TCComponent; {$ifdef USEINLINE}inline;{$endif}
    function ReadComponentRes(Instance: TCComponent): TCComponent; {$ifdef USEINLINE}inline;{$endif}
    procedure WriteComponent(Instance: TCComponent); {$ifdef USEINLINE}inline;{$endif}
    procedure WriteComponentRes(const ResName: string; Instance: TCComponent); {$ifdef USEINLINE}inline;{$endif}
    procedure WriteDescendent(Instance, Ancestor: TCComponent); {$ifdef USEINLINE}inline;{$endif}
    procedure WriteDescendentRes(const ResName: string; Instance, Ancestor: TCComponent); {$ifdef USEINLINE}inline;{$endif}
    procedure WriteResourceHeader(const ResName: string; {!!!:out} var FixupInfo: Integer); {$ifdef USEINLINE}inline;{$endif}
    procedure FixupResourceHeader(FixupInfo: Integer); {$ifdef USEINLINE}inline;{$endif}
    procedure ReadResHeader; {$ifdef USEINLINE}inline;{$endif}
    function ReadByte : Byte; {$ifdef USEINLINE}inline;{$endif}
    function ReadWord : Word; {$ifdef USEINLINE}inline;{$endif}
    function ReadDWord : Cardinal; {$ifdef USEINLINE}inline;{$endif}
    function ReadAnsiString : AnsiString;
    procedure WriteByte(B : Byte); {$ifdef USEINLINE}inline;{$endif}
    procedure WriteWord(W : Word); {$ifdef USEINLINE}inline;{$endif}
    procedure WriteDWord(D : Cardinal); {$ifdef USEINLINE}inline;{$endif}
    Procedure WriteAnsiString (const S : AnsiString);
    property Position: LongInt read GetPosition write SetPosition;
    property Size: LongInt read GetSize write SetSize;
  end;

{ TCCustomFileStream class }

  TCCustomFileStream = class(TCStream)
  protected
    FFileName : AnsiString;
  public
    constructor Create(const AFileName: AnsiString; Mode: Word); virtual; abstract;
    function EOF: Boolean; virtual; abstract;
    property FileName : AnsiString Read FFileName;
  end;

{ TFileStream class }

  TCFileStream = class(TCCustomFileStream)
  Private
    FHandle: File;
  protected
    procedure SetSize(NewSize: LongInt); override;
  public
    constructor Create(const AFileName: AnsiString; Mode: Word); override;
    destructor Destroy; override;
    function Read(var Buffer; Count: LongInt): LongInt; override;
    function Write(const Buffer; Count: LongInt): LongInt; override;
    function Seek(Offset: LongInt; Origin: Word): LongInt; override;
    function EOF: Boolean; override;
  end;

  TCFileStreamClass = class of TCCustomFileStream;
var
  CFileStreamClass: TCFileStreamClass = TCFileStream;

type
  TCRangeStream = class(TCStream)
  private
    FBase: TCStream;
    FOffset: LongInt;
    FMaxOffset: LongInt;
    FSize: LongInt;
    FPosition: LongInt;
  public
    constructor Create(ABase: TCStream; AOffset, ASize: LongInt);
    function Read(var Buffer; Count: LongInt): LongInt; override;
    function Write(const Buffer; Count: LongInt): LongInt; override;
    function Seek(Offset: LongInt; Origin: Word): LongInt; override;
  end;

{ TCustomMemoryStream abstract class }

  TCCustomMemoryStream = class(TCStream)
  private
    FMemory: Pointer;
    FSize, FPosition: LongInt;
  protected
    procedure SetPointer(Ptr: Pointer; ASize: LongInt); {$ifdef USEINLINE}inline;{$endif}
  public
    function Read(var Buffer; Count: LongInt): LongInt; override;
    function Seek(Offset: LongInt; Origin: Word): LongInt; override;
    procedure SaveToStream(Stream: TCStream); {$ifdef USEINLINE}inline;{$endif}
    procedure SaveToFile(const FileName: string);
    property Memory: Pointer read FMemory;
  end;

{ TCMemoryStream }

  TCMemoryStream = class(TCCustomMemoryStream)
  private
    FCapacity: LongInt;
    procedure SetCapacity(NewCapacity: LongInt);
  protected
    function Realloc(var NewCapacity: LongInt): Pointer; virtual;
    property Capacity: LongInt read FCapacity write SetCapacity;
  public
    destructor Destroy; override;
    procedure Clear;
    procedure LoadFromStream(Stream: TCStream);
    procedure LoadFromFile(const FileName: string);
    procedure SetSize(NewSize: LongInt); override;
    function Write(const Buffer; Count: LongInt): LongInt; override;
  end;


implementation

  Type
    PByte = ^Byte;

{*****************************************************************************
                                   TCStream
*****************************************************************************}

  function TCStream.GetPosition: LongInt;

    begin
       Result:=Seek(0,soFromCurrent);
    end;

  procedure TCStream.SetPosition(Pos: LongInt);

    begin
       Seek(Pos,soFromBeginning);
    end;

  function TCStream.GetSize: LongInt;

    var
       P : LongInt;

    begin
       P:=GetPosition;
       GetSize:=Seek(0,soFromEnd);
       Seek(P,soFromBeginning);
    end;

  procedure TCStream.SetSize(NewSize: LongInt);

    begin
    // We do nothing. Pipe streams don't support this
    // As well as possible read-only streams !!
    end;

  procedure TCStream.ReadBuffer(var Buffer; Count: LongInt);

    begin
       CStreamError:=0;
       if Read(Buffer,Count)<Count then
         CStreamError:=102;
    end;

  procedure TCStream.WriteBuffer(const Buffer; Count: LongInt);

    begin
       CStreamError:=0;
       if Write(Buffer,Count)<Count then
         CStreamError:=103;
    end;

  function TCStream.CopyFrom(Source: TCStream; Count: LongInt): LongInt;

    var
       I : LongInt;
       Buffer : array[0..1023] of Byte;

    begin
       CStreamError:=0;
       Result:=0;
       while Count>0 do
         begin
            if (Count>SizeOf(Buffer)) then
              I:=SizeOf(Buffer)
            else
              I:=Count;
            I:=Source.Read(Buffer,I);
            I:=Write(Buffer,I);
            Dec(Count,I);
            Inc(Result,I);
            if I=0 then
              Exit;
         end;
    end;

  function TCStream.ReadComponent(Instance: TCComponent): TCComponent;
    begin
      Result:=nil;
    end;

  function TCStream.ReadComponentRes(Instance: TCComponent): TCComponent;
    begin
      Result:=nil;
    end;

  procedure TCStream.WriteComponent(Instance: TCComponent);
    begin
    end;

  procedure TCStream.WriteComponentRes(const ResName: string; Instance: TCComponent);
    begin
    end;

  procedure TCStream.WriteDescendent(Instance, Ancestor: TCComponent);
    begin
    end;

  procedure TCStream.WriteDescendentRes(const ResName: string; Instance, Ancestor: TCComponent);
    begin
    end;

  procedure TCStream.WriteResourceHeader(const ResName: string; {!!!: out} var FixupInfo: Integer);
    begin
    end;

  procedure TCStream.FixupResourceHeader(FixupInfo: Integer);
    begin
    end;

  procedure TCStream.ReadResHeader;
    begin
    end;

  function TCStream.ReadByte : Byte;

    var
       B : Byte;

    begin
       ReadBuffer(B,1);
       ReadByte:=B;
    end;

  function TCStream.ReadWord : Word;

    var
       W : Word;

    begin
       ReadBuffer(W,2);
       ReadWord:=W;
    end;

  function TCStream.ReadDWord : Cardinal;

    var
       D : Cardinal;

    begin
       ReadBuffer(D,4);
       ReadDWord:=D;
    end;

  Function TCStream.ReadAnsiString : AnsiString;
  Var
    TheSize : LongInt;
    P : PByte ;
  begin
    Result:='';
    ReadBuffer (TheSize,SizeOf(TheSize));
    SetLength(Result,TheSize);
    // Illegal typecast if no AnsiStrings defined.
    if TheSize>0 then
     begin
       ReadBuffer (Pointer(Result)^,TheSize);
       P:=PByte(PtrInt(Result)+TheSize);
       P^:=0;
     end;
   end;

  Procedure TCStream.WriteAnsiString (const S : AnsiString);

  Var L : LongInt;

  begin
    L:=Length(S);
    WriteBuffer (L,SizeOf(L));
    WriteBuffer (Pointer(S)^,L);
  end;

  procedure TCStream.WriteByte(B : Byte);

    begin
       WriteBuffer(B,1);
    end;

  procedure TCStream.WriteWord(W : Word);

    begin
       WriteBuffer(W,2);
    end;

  procedure TCStream.WriteDWord(D : Cardinal);

    begin
       WriteBuffer(D,4);
    end;


{****************************************************************************}
{*                             TCFileStream                                  *}
{****************************************************************************}

constructor TCFileStream.Create(const AFileName: AnsiString; Mode: Word);
var
  OldFileMode : Byte;
begin
  FFileName:=AFileName;
  If Mode=fmCreate then
    begin
      System.Assign(FHandle,AFileName);
      {$push} {$I-}
       System.Rewrite(FHandle,1);
      {$pop}
      CStreamError:=IOResult;
    end
  else
    begin
      OldFileMode:=FileMode;
      FileMode:=$40 or Mode;
      System.Assign(FHandle,AFileName);
      {$push} {$I-}
       System.Reset(FHandle,1);
      {$pop}
      CStreamError:=IOResult;
      FileMode:=OldFileMode;
    end;
end;


destructor TCFileStream.Destroy;
begin
  {$push} {$I-}
   System.Close(FHandle);
  {$pop}
  CStreamError:=IOResult;
end;


function TCFileStream.Read(var Buffer; Count: LongInt): LongInt;
begin
  CStreamError:=0;
  Result:=0;
  BlockRead(FHandle,Buffer,Count,Result);
  If Result=-1 then Result:=0;
end;


function TCFileStream.Write(const Buffer; Count: LongInt): LongInt;
begin
  CStreamError:=0;
  Result:=0;
  BlockWrite (FHandle,(@Buffer)^,Count,Result);
  If Result=-1 then Result:=0;
end;


Procedure TCFileStream.SetSize(NewSize: LongInt);
begin
  {$push} {$I-}
   System.Seek(FHandle,NewSize);
   System.Truncate(FHandle);
  {$pop}
  CStreamError:=IOResult;
end;


function TCFileStream.Seek(Offset: LongInt; Origin: Word): LongInt;
var
  L : LongInt;
begin
  {$push} {$I-}
   case Origin of
     soFromBeginning :
       begin
         System.Seek(FHandle,Offset);
         L:=Offset;
       end;
     soFromCurrent :
       begin
         L:=System.FilePos(FHandle);
         Inc(L,Offset);
         System.Seek(FHandle,L);
       end;
     soFromEnd :
       begin
         L:=System.FileSize(FHandle);
         Dec(L,Offset);
         if L<0 then
          L:=0;
         System.Seek(FHandle,L);
       end;
     else
       begin
         CStreamError:=103;
         L:=Offset;
       end;
   end;
  {$pop}
  CStreamError:=IOResult;
  Result:=L;
end;

function TCFileStream.EOF: Boolean;
begin
  EOF:=System.EOF(FHandle);
end;


{****************************************************************************}
{*                             TCRangeStream                                *}
{****************************************************************************}


constructor TCRangeStream.Create(ABase: TCStream; AOffset, ASize: LongInt);
begin
  if not Assigned(ABase) then
    CStreamError:=155
  else
    { we allow to be positioned directly at the end for appending }
    if (AOffset<0) or (AOffset>ABase.Size) then
      CStreamError:=156
    else
      begin
        FBase:=ABase;
        FOffset:=AOffset;
        if ASize<0 then
          FSize:=MaxLongInt-FOffset
        else
          FSize:=ASize;
        FMaxOffset:=FOffset+FSize-1;
      end;
end;


function TCRangeStream.Read(var Buffer; Count: LongInt): LongInt;
begin
  Count:=Min(Count,FMaxOffset-FPosition+1);
  if Count>0 then
    begin
      FBase.Seek(FOffset+FPosition,soFromBeginning);
      Result:=FBase.Read(Buffer,Count);
    end
  else
    Result:=0;
  FPosition:=FPosition+Result;
end;


function TCRangeStream.Write(const Buffer; Count: LongInt): LongInt;
begin
  Count:=Min(Count,FMaxOffset-FPosition+1);
  if Count>0 then
    begin
      FBase.Seek(FOffset+FPosition,soFromBeginning);
      Result:=FBase.Write(Buffer,Count);
    end
  else
    Result:=0;
  FPosition:=FPosition+Result;
end;


function TCRangeStream.Seek(Offset: LongInt; Origin: Word): LongInt;
begin
  case Origin of
    soFromBeginning:
      begin
        if Offset>FMaxOffset then
          CStreamError:=156
        else
          FPosition:=FBase.Seek(FOffset+Offset,soFromBeginning)-FOffset;
      end;
    soFromCurrent:
      begin
        if Offset>FMaxOffset then
          CStreamError:=156
        else
          FPosition:=FBase.Seek(FOffset+FPosition+Offset,soFromBeginning)-FOffset;
      end;
    soFromEnd:
      begin
        if Offset>FSize-1 then
          CStreamError:=156
        else
          FPosition:=FBase.Seek(FMaxOffset-Offset,soFromBeginning)-FOffset;
      end;
    else
      begin
        CStreamError:=156;
      end;
  end;
  Result:=FPosition;
end;

{****************************************************************************}
{*                             TCustomMemoryStream                          *}
{****************************************************************************}

procedure TCCustomMemoryStream.SetPointer(Ptr: Pointer; ASize: LongInt);

begin
  FMemory:=Ptr;
  FSize:=ASize;
end;


function TCCustomMemoryStream.Read(var Buffer; Count: LongInt): LongInt;

begin
  Result:=0;
  If (FSize>0) and (FPosition<FSize) then
    begin
    Result:=FSize-FPosition;
    If Result>Count then Result:=Count;
    Move (Pointer(PtrUInt(FMemory)+PtrUInt(FPosition))^,Buffer,Result);
    FPosition:=FPosition+Result;
    end;
end;


function TCCustomMemoryStream.Seek(Offset: LongInt; Origin: Word): LongInt;

begin
  Case Origin of
    soFromBeginning : FPosition:=Offset;
    soFromEnd       : FPosition:=FSize+Offset;
    soFromCurrent   : FPosition:=FPosition+Offset;
  end;
  Result:=FPosition;
end;


procedure TCCustomMemoryStream.SaveToStream(Stream: TCStream);

begin
  if FSize>0 then Stream.WriteBuffer (FMemory^,FSize);
end;


procedure TCCustomMemoryStream.SaveToFile(const FileName: string);

Var S : TCCustomFileStream;

begin
  Try
    S:=CFileStreamClass.Create (FileName,fmCreate);
    SaveToStream(S);
  finally
    S.Free;
    S := nil;
  end;
end;


{****************************************************************************}
{*                             TCMemoryStream                                *}
{****************************************************************************}


Const TMSGrow = 4096; { Use 4k blocks. }

procedure TCMemoryStream.SetCapacity(NewCapacity: LongInt);

begin
  SetPointer (Realloc(NewCapacity),FSize);
  FCapacity:=NewCapacity;
end;


function TCMemoryStream.Realloc(var NewCapacity: LongInt): Pointer;

Var MoveSize : LongInt;

begin
  CStreamError:=0;
  If NewCapacity>0 Then // round off to block size.
    NewCapacity := (NewCapacity + (TMSGrow-1)) and not (TMSGrow-1);
  // Only now check !
  If NewCapacity=FCapacity then
    Result:=FMemory
  else
    If NewCapacity=0 then
      begin
        FreeMem (FMemory,FCapacity);
        Result:=nil;
      end
    else
      begin
      GetMem (Result,NewCapacity);
      If Result=Nil then
        CStreamError:=204;
      If FCapacity>0 then
        begin
        MoveSize:=FSize;
        If MoveSize>NewCapacity then MoveSize:=NewCapacity;
        Move (FMemory^,Result^,MoveSize);
        FreeMem (FMemory,FCapacity);
        end;
      end;
end;


destructor TCMemoryStream.Destroy;

begin
  Clear;
  Inherited Destroy;
end;


procedure TCMemoryStream.Clear;

begin
  FSize:=0;
  FPosition:=0;
  SetCapacity (0);
end;


procedure TCMemoryStream.LoadFromStream(Stream: TCStream);

begin
  Stream.Position:=0;
  SetSize(Stream.Size);
  If FSize>0 then Stream.ReadBuffer(FMemory^,FSize);
end;


procedure TCMemoryStream.LoadFromFile(const FileName: string);

Var S : TCCustomFileStream;

begin
  Try
    S:=CFileStreamClass.Create (FileName,fmOpenRead);
    LoadFromStream(S);
  finally
    S.Free;
    S := nil;
  end;
end;


procedure TCMemoryStream.SetSize(NewSize: LongInt);

begin
  SetCapacity (NewSize);
  FSize:=NewSize;
  IF FPosition>FSize then
    FPosition:=FSize;
end;


function TCMemoryStream.Write(const Buffer; Count: LongInt): LongInt;

Var NewPos : LongInt;

begin
  If Count=0 then
   begin
     Result:=0;
     Exit;
   end;
  NewPos:=FPosition+Count;
  If NewPos>FSize then
    begin
    IF NewPos>FCapacity then
      SetCapacity (NewPos);
    FSize:=NewPos;
    end;
  System.Move (Buffer,Pointer(PtrUInt(FMemory)+PtrUInt(FPosition))^,Count);
  FPosition:=NewPos;
  Result:=Count;
end;

end.
