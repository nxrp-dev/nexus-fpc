{
    Copyright (c) 1998-2002 by Florian Klaempfl and Peter Vreman

    This module provides some basic classes

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
unit cclasses;

{$i fpcdefs.inc}

{$define CCLASSESINLINE}

interface

    uses
      SysUtils,
      GlobType,
      CUtils,CStreams;

{********************************************
                TMemDebug
********************************************}

    type
       TMemDebug = class
       private
          TotalMem,
          StartMem : Int64;
          InfoStr  : string[40];
       public
          constructor Create(const S:string);
          destructor  Destroy;override;
          procedure Show;
          procedure Start;
          procedure Stop;
       end;

{*******************************************************
      TFPList (From rtl/objpas/classes/classesh.inc)
********************************************************}

const
   SListIndexError = 'List index exceeds bounds (%d)';
   SListCapacityError = 'The maximum list capacity is reached (%d)';
   SListCapacityPower2Error = 'The capacity has to be a power of 2, but is set to %d';
   SListCountError = 'List count too large (%d)';
type
   EListError = class(Exception);

const
  MaxListSize = MaxInt div 16;
type
  TListSortCompare = function (Item1, Item2: Pointer): Integer;
  TListCallback = procedure(data,arg:Pointer) of object;
  TListStaticCallback = procedure(data,arg:Pointer);
  TDynStringArray = Array Of String;
  TDirection = (FromBeginning,FromEnd);
  TFPList = class(TObject)
  private
    FList: PPointer;
    FCount: Integer;
    FCapacity: Integer;
  protected
    function Get(Index: Integer): Pointer; inline;
    procedure Put(Index: Integer; Item: Pointer); inline;
    procedure SetCapacity(NewCapacity: Integer);
    procedure SetCount(NewCount: Integer);
    Procedure RaiseIndexError(Index : Integer);
    property List: PPointer read FList;
  public
    destructor Destroy; override;
    function Add(Item: Pointer): Integer;
    procedure Clear;
    procedure Delete(Index: Integer);
    class procedure Error(const Msg: string; Data: PtrInt);
    procedure Exchange(Index1, Index2: Integer);
    function Expand: TFPList;
    function Extract(Item: Pointer): Pointer;
    function First: Pointer;
    function IndexOf(Item: Pointer): Integer;
    function IndexOfItem(Item: Pointer; Direction: TDirection): Integer;
    procedure Insert(Index: Integer; Item: Pointer);
    function Last: Pointer;
    procedure Move(CurIndex, NewIndex: Integer);
    procedure Assign(Obj:TFPList);
    function Remove(Item: Pointer): Integer;
    procedure Pack;
    procedure Sort(Compare: TListSortCompare);
    procedure ForEachCall(Proc2Call:TListCallback;Arg:Pointer);
    procedure ForEachCall(Proc2Call:TListStaticCallback;Arg:Pointer);
    property Capacity: Integer read FCapacity write SetCapacity;
    property Count: Integer read FCount write SetCount;
    property Items[Index: Integer]: Pointer read Get write Put; default;

    { Add to list, creating it if required. }
    class procedure AddOnDemand(var Lst: TFPList; Item: Pointer); static;

    { FreeAndNil the list, and its items as TObjects. }
    class procedure FreeAndNilObjects(var Lst: TFPList); static;

    { FreeAndNil the list, and dispose() its items. 'ItemType' is TypeInfo() of items. }
    class procedure FreeAndNilDisposing(var Lst: TFPList; ItemType: Pointer); static;
  end;


{*******************************************************
        TFPObjectList (From fcl/inc/contnrs.pas)
********************************************************}

  TObjectListCallback = procedure(data:TObject;arg:Pointer) of object;
  TObjectListStaticCallback = procedure(data:TObject;arg:Pointer);

  TFPObjectList = class(TObject)
  private
    FFreeObjects : Boolean;
    FList: TFPList;
    function GetCount: Integer; {$ifdef CCLASSESINLINE}inline;{$endif}
    procedure SetCount(const AValue: Integer);
  protected
    function GetItem(Index: Integer): TObject; {$ifdef CCLASSESINLINE}inline;{$endif}
    procedure SetItem(Index: Integer; AObject: TObject);
    procedure SetCapacity(NewCapacity: Integer); {$ifdef CCLASSESINLINE}inline;{$endif}
    function GetCapacity: Integer; {$ifdef CCLASSESINLINE}inline;{$endif}
  public
    constructor Create;
    constructor Create(FreeObjects : Boolean);
    destructor Destroy; override;
    procedure Clear;
    function Add(AObject: TObject): Integer; {$ifdef CCLASSESINLINE}inline;{$endif}
    procedure Delete(Index: Integer);
    procedure Exchange(Index1, Index2: Integer); {$ifdef CCLASSESINLINE}inline;{$endif}
    function Expand: TFPObjectList;{$ifdef CCLASSESINLINE}inline;{$endif}
    function Extract(Item: TObject): TObject; {$ifdef CCLASSESINLINE}inline;{$endif}
    function Remove(AObject: TObject): Integer;
    function IndexOf(AObject: TObject): Integer; {$ifdef CCLASSESINLINE}inline;{$endif}
    function IndexOfItem(AObject: TObject; Direction: TDirection): Integer; {$ifdef CCLASSESINLINE}inline;{$endif}
    function FindInstanceOf(AClass: TClass; AExact: Boolean; AStartAt: Integer): Integer;
    procedure Insert(Index: Integer; AObject: TObject); {$ifdef CCLASSESINLINE}inline;{$endif}
    function First: TObject; {$ifdef CCLASSESINLINE}inline;{$endif}
    function Last: TObject; {$ifdef CCLASSESINLINE}inline;{$endif}
    procedure Move(CurIndex, NewIndex: Integer); {$ifdef CCLASSESINLINE}inline;{$endif}
    procedure Assign(Obj:TFPObjectList);
    procedure ConcatListCopy(Obj:TFPObjectList);
    procedure Pack; {$ifdef CCLASSESINLINE}inline;{$endif}
    procedure Sort(Compare: TListSortCompare); {$ifdef CCLASSESINLINE}inline;{$endif}
    procedure ForEachCall(Proc2Call:TObjectListCallback;Arg:Pointer); {$ifdef CCLASSESINLINE}inline;{$endif}
    procedure ForEachCall(Proc2Call:TObjectListStaticCallback;Arg:Pointer); {$ifdef CCLASSESINLINE}inline;{$endif}
    property Capacity: Integer read GetCapacity write SetCapacity;
    property Count: Integer read GetCount write SetCount;
    property OwnsObjects: Boolean read FFreeObjects write FFreeObjects;
    property Items[Index: Integer]: TObject read GetItem write SetItem; default;
    property List: TFPList read FList;
  end;

{ Memory region that allocates chunks with .Push and frees them all at once with .Done, useful for storing shortstrings.
  Alignment of the sizes is the user's responsibility, but shortstrings are composed of bytes and unaffected,
  and, in general, objects of the same nature will have same alignment and be sized as its multiple,
  not to mention using such a region exclusively for arrays of the same type, for example. }

  PMemoryRegionNode = ^TMemoryRegionNode;
  TMemoryRegionNode = record
    N, Alloc: UInt32;
    Next: PMemoryRegionNode;
    Data: array[0 .. 0] of Byte; { variable-sized; and aligned to pointer. }
  end;

const
  MinMemoryRegionNodeSize=64;

type
  TMemoryRegion = object
    procedure Init(PreAllocate: SizeUInt=0);
    procedure Done; {$ifdef CCLASSESINLINE}inline;{$endif}
    function Push(N: SizeUInt): Pointer;
    procedure Clear;
    function CalcSumSize: SizeUInt; { don't want to store it as its retrieval is logarithmic. }
  private
    FTop: PMemoryRegionNode;
    class function AllocateNode(N, Alloc: SizeUInt): PMemoryRegionNode; static;
    function PushNewNode(N: SizeUInt): Pointer;
  end;

{ "Vi" stands for variable-sized indices.
  Variable-sized indices use less space and reduce the size of a region with potentially chaotic accesses (FHash).

  Indices are bitpacked. For speed and simplicity, bitfield base type is the same as index type (SizeUint),
  and maximum bit size is bitsizeof(SizeUint) - 1, to allow unconditional masking with "1 shl bitsPerIndex - 1", etc. }

  function ViGet(Data: PSizeUInt; Index, BitsPerIndex: SizeUInt): SizeUInt;
  procedure ViSet(Data: PSizeUInt; Index, BitsPerIndex, Value: SizeUInt);
  function ViDataSize(N, BitsPerIndex: SizeUInt): SizeUInt;

const
  ViEmpty = 0;
  ViRealIndexOffset = 1;

type
  PViHashListItem = ^TViHashListItem;
  TViHashListItem = record
    HashValue: UInt32;
    Next: Int32;
    Str: {$ifdef symansistr} TSymStr {$else} PSymStr {$endif};
    Data: Pointer;
  end;

  TViRehashMode = (vi_Auto, vi_Tight, vi_Pack);

  TViHashList = class(TObject)
  private
    { When not special "empty list", that is, when Assigned(FItems), FHash is a memory region containing FHash + FItems. }
    FHash: PSizeUInt; { Bitpacked hash table. ViEmpty means empty cell, ViRealIndexOffset+i references FItems[i]. }
    FItems: PViHashListItem;
    FBitsPerIndex: UInt8; { Size of indices in FHash. }
    FHashMask: UInt32; { Count of indices in FHash is always "FHashMask + 1" and is always a power of two. }
    FCount: Int32;
    FCapacity: UInt32; { Allocation size of FItems. Generally speaking, can be arbitrary, without any relation to "FHashMask + 1". }
{$ifndef symansistr}
    FShortStringRegion: TMemoryRegion;
{$endif}
    function Get(Index: SizeInt): Pointer;
    procedure Put(Index: SizeInt; Item: Pointer);
    class procedure RaiseIndexError(Index: SizeInt); static;
    procedure SetupEmptyTable;
    procedure Rehash(ForItems: SizeUInt; Mode: TViRehashMode=vi_Auto);
{$ifndef symansistr}
    function AddStrToRegion(const S: TSymStr): PSymStr;
{$endif}
    procedure Shrink;
    procedure AddToHashTable(Item: PViHashListItem; Index: SizeUInt);
    function InternalFind(AHash:LongWord;const AName:TSymStr;out PrevIndex:SizeInt):SizeInt;
    procedure RemoveFromHashTable(AHash:LongWord;Index, PrevIndex: SizeInt);
    procedure SetCapacity(NewCapacity: UInt32);
  public
    constructor Create;
    destructor Destroy; override;
    function Add(const AName:TSymStr;Item: Pointer): SizeInt;
    function AddWithHash(const AName: TSymStr; AHash: LongWord; Item: Pointer): SizeInt;
    procedure Clear;
    function NameOfIndex(Index: SizeInt): TSymStr;
    function HashOfIndex(Index: SizeInt): LongWord;
    function GetNextCollision(Index: SizeInt): SizeInt; {$ifdef CCLASSESINLINE}inline;{$endif}
    procedure Delete(Index: SizeInt);
    function Extract(Item: Pointer): Pointer;
    function IndexOf(Item: Pointer): SizeInt;
    function Find(const AName:TSymStr): Pointer; {$ifdef CCLASSESINLINE}inline;{$endif}
    function FindIndexOf(const AName:TSymStr): SizeInt; {$ifdef CCLASSESINLINE}inline;{$endif}
    function FindWithHash(const AName:TSymStr;AHash:LongWord): Pointer;
    function Rename(const AOldName,ANewName:TSymStr): SizeInt;
    function Remove(Item: Pointer): SizeInt;
    procedure Pack;
    procedure ShowStatistics;
    procedure ForEachCall(Proc2Call:TListCallback;Arg:Pointer);
    procedure ForEachCall(Proc2Call:TListStaticCallback;Arg:Pointer);
    property Count: Int32 read FCount;
    property Capacity: UInt32 read FCapacity write SetCapacity;
    property Items[Index: SizeInt]: Pointer read Get write Put; default;
    property List: PViHashListItem read FItems;
  end;

  TFPHashList=TViHashList;

const
  MaxHashListSize = MaxInt div 16;


{*******************************************************
        TFPHashObjectList (From fcl/inc/contnrs.pas)
********************************************************}

type
  TFPHashObjectList = class;

  { TFPHashObject }

  TFPHashObject = class
  private
    FOwner     : TFPHashObjectList;
    FStr       : {$ifdef symansistr} TSymStr {$else} PSymStr {$endif};
    FHash      : LongWord;
    procedure InternalChangeOwner(HashObjectList:TFPHashObjectList;const S:TSymStr);
    procedure InternalChangeOwnerWithHash(HashObjectList: TFPHashObjectList;
      const S: TSymStr; AHash: LongWord);
  protected
    function GetName:TSymStr;virtual;
    function GetHash:LongWord;virtual;
  public
    constructor CreateNotOwned;
    constructor Create(HashObjectList:TFPHashObjectList;const S:TSymStr);
    procedure ChangeOwner(HashObjectList:TFPHashObjectList);
    procedure ChangeOwnerAndName(HashObjectList:TFPHashObjectList;const S:TSymStr); {$ifdef CCLASSESINLINE}inline;{$endif}
    procedure ChangeOwnerAndNameWithHash(HashObjectList: TFPHashObjectList;
      const S: TSymStr; AHash: LongWord); {$ifdef CCLASSESINLINE}inline;{$endif}
    procedure Rename(const ANewName:TSymStr);
    property Name:TSymStr read GetName;
    property Hash:LongWord read GetHash;
    property OwnerList: TFPHashObjectList read FOwner;
  end;

  TFPHashObjectList = class(TObject)
  private
    FFreeObjects : Boolean;
    FHashList: TFPHashList;
    function GetCount: Integer; {$ifdef CCLASSESINLINE}inline;{$endif}
  protected
    function GetItem(Index: Integer): TObject; {$ifdef CCLASSESINLINE}inline;{$endif}
    procedure SetItem(Index: Integer; AObject: TObject);
    procedure SetCapacity(NewCapacity: Integer); {$ifdef CCLASSESINLINE}inline;{$endif}
    function GetCapacity: Integer; {$ifdef CCLASSESINLINE}inline;{$endif}
  public
    constructor Create(FreeObjects : Boolean = True);
    destructor Destroy; override;
    procedure Clear;
    function Add(const AName:TSymStr;AObject: TObject): Integer; {$ifdef CCLASSESINLINE}inline;{$endif}
    function AddWithHash(const AName: TSymStr; AHash: LongWord; AObject: TObject): Integer; {$ifdef CCLASSESINLINE}inline;{$endif}
    function NameOfIndex(Index: Integer): TSymStr; {$ifdef CCLASSESINLINE}inline;{$endif}
    function HashOfIndex(Index: Integer): LongWord; {$ifdef CCLASSESINLINE}inline;{$endif}
    function GetNextCollision(Index: Integer): Integer; {$ifdef CCLASSESINLINE}inline;{$endif}
    procedure Delete(Index: Integer);
    function Extract(Item: TObject): TObject; {$ifdef CCLASSESINLINE}inline;{$endif}
    function Remove(AObject: TObject): Integer;
    function IndexOf(AObject: TObject): Integer; {$ifdef CCLASSESINLINE}inline;{$endif}
    function Find(const S:TSymStr): TObject; {$ifdef CCLASSESINLINE}inline;{$endif}
    function FindIndexOf(const S:TSymStr): Integer; {$ifdef CCLASSESINLINE}inline;{$endif}
    function FindWithHash(const AName:TSymStr;AHash:LongWord): Pointer; {$ifdef CCLASSESINLINE}inline;{$endif}
    function Rename(const AOldName,ANewName:TSymStr): Integer; {$ifdef CCLASSESINLINE}inline;{$endif}
    function FindInstanceOf(AClass: TClass; AExact: Boolean; AStartAt: Integer): Integer;
    procedure Pack; {$ifdef CCLASSESINLINE}inline;{$endif}
    procedure ShowStatistics; {$ifdef CCLASSESINLINE}inline;{$endif}
    procedure ForEachCall(Proc2Call:TObjectListCallback;Arg:Pointer); {$ifdef CCLASSESINLINE}inline;{$endif}
    procedure ForEachCall(Proc2Call:TObjectListStaticCallback;Arg:Pointer); {$ifdef CCLASSESINLINE}inline;{$endif}
    property Capacity: Integer read GetCapacity write SetCapacity;
    property Count: Integer read GetCount;
    property OwnsObjects: Boolean read FFreeObjects write FFreeObjects;
    property Items[Index: Integer]: TObject read GetItem write SetItem; default;
    property List: TFPHashList read FHashList;
  end;


{********************************************
                TLinkedList
********************************************}

    type
       TLinkedListItem = class
       public
          Previous,
          Next : TLinkedListItem;
          Constructor Create;
          Destructor Destroy;override;
          Function GetCopy:TLinkedListItem;virtual;
       end;

       TLinkedListItemClass = class of TLinkedListItem;

       TLinkedList = class
       private
          FCount : Integer;
          FFirst,
          FLast  : TLinkedListItem;
          FNoClear : Boolean;
       public
          constructor Create;
          destructor  Destroy;override;
          { true when the List is empty }
          function  Empty:Boolean; {$ifdef CCLASSESINLINE}inline;{$endif}
          { deletes all Items }
          procedure Clear;
          { inserts an Item }
          procedure Insert(Item:TLinkedListItem);
          { inserts an Item before Loc }
          procedure InsertBefore(Item,Loc : TLinkedListItem);
          { inserts an Item after Loc }
          procedure InsertAfter(Item,Loc : TLinkedListItem);virtual;
          { concatenate an Item }
          procedure Concat(Item:TLinkedListItem);
          { deletes an Item }
          procedure Remove(Item:TLinkedListItem);
          { Gets First Item }
          function  GetFirst:TLinkedListItem;
          { Gets last Item }
          function  GetLast:TLinkedListItem;
          { inserts another List at the begin and make this List empty }
          procedure InsertList(P : TLinkedList); virtual;
          { inserts another List before the provided item and make this List empty }
          procedure InsertListBefore(Item:TLinkedListItem;P : TLinkedList); virtual;
          { inserts another List after the provided item and make this List empty }
          procedure InsertListAfter(Item:TLinkedListItem;P : TLinkedList); virtual;
          { concatenate another List at the end and make this List empty }
          procedure ConcatList(P : TLinkedList); virtual;
          { concatenate another List at the start and makes a copy
            the list is ordered in reverse.
          }
          procedure InsertListCopy(P : TLinkedList); virtual;
          { concatenate another List at the end and makes a copy }
          procedure ConcatListCopy(P : TLinkedList); virtual;
          { removes all items from the list, the items are not freed }
          procedure RemoveAll; virtual;
          property First:TLinkedListItem read FFirst;
          property Last:TLinkedListItem read FLast;
          property Count:Integer read FCount;
          property NoClear:Boolean write FNoClear;
       end;

{********************************************
                TCmdStrList
********************************************}

       { string containerItem }
       TCmdStrListItem = class(TLinkedListItem)
          FPStr : TCmdStr;
       public
          constructor Create(const S:TCmdStr);
          destructor  Destroy;override;
          function GetCopy:TLinkedListItem;override;
          property Str: TCmdStr read FPStr;
       end;

       { string container }
       TCmdStrList = class(TLinkedList)
       private
          FDoubles : Boolean;  { if this is set to true, doubles (case insensitive!) are allowed }
       public
          constructor Create;
          constructor Create_No_Double;
          { inserts an Item }
          procedure Insert(const S:TCmdStr);
          { concatenate an Item }
          procedure Concat(const S:TCmdStr);
          { deletes an Item }
          procedure Remove(const S:TCmdStr);
          { Gets First Item }
          function  GetFirst:TCmdStr;
          { Gets last Item }
          function  GetLast:TCmdStr;
          { true if string is in the container, compare case sensitive }
          function FindCase(const S:TCmdStr):TCmdStrListItem;
          { true if string is in the container }
          function Find(const S:TCmdStr):TCmdStrListItem;
          { inserts an item }
          procedure InsertItem(Item:TCmdStrListItem);
          { concatenate an item }
          procedure ConcatItem(Item:TCmdStrListItem);
          property Doubles:Boolean read FDoubles write FDoubles;
       end;


{********************************************
              DynamicArray
********************************************}

     type
       { can't use sizeof(integer) because it crashes gdb }
       TDynamicBlockData=array[0..1024*1024-1] of Byte;

       PDynamicBlock = ^TDynamicBlock;
       TDynamicBlock = record
         Pos,
         Size,
         Used : LongWord;
         Next : PDynamicBlock;
         Data : TDynamicBlockData;
       end;
       TDynamicBlockArray = array of TDynamicBlock;

     const
       DynamicBlockBaseSize = SizeOf(TDynamicBlock)-SizeOf(TDynamicBlockData);
       MinDynamicBlockSize = 8*SizeOf(Pointer);

     type
       TDynamicArray = class
       private
         FPosn       : LongWord;
         FPosnBlock  : PDynamicBlock;
         FCurrBlockSize,
         FMaxBlockSize  : LongWord;
         FFirstBlock,
         FLastBlock  : PDynamicBlock;
         procedure Grow;
       public
         constructor Create(ABlockSize:LongWord);
         destructor  Destroy;override;
         procedure Reset;
         function  Size:LongWord; {$ifdef CCLASSESINLINE}inline;{$endif}
         procedure Align(I:LongWord);
         procedure Seek(I:LongWord);
         function  Read(var D;Len:LongWord):LongWord;
         procedure Write(const D;Len:LongWord);
         procedure WriteStr(const S:string); {$ifdef CCLASSESINLINE}inline;{$endif}
         procedure ReadStream(F:TCStream;MaxLen:LongWord);
         procedure WriteStream(F:TCStream);
         function  Equal(Other:TDynamicArray):Boolean;
         property  CurrBlockSize : LongWord read FCurrBlockSize;
         property  FirstBlock : PDynamicBlock read FFirstBlock;
         property  Pos : LongWord read FPosn;
       end;


{******************************************************************
   THashSet (keys not limited to ShortString, no indexed access)
*******************************************************************}

       PPHashSetItem = ^PHashSetItem;
       PHashSetItem = ^THashSetItem;
       THashSetItem = record
         Next: PHashSetItem;
         Key: Pointer; { With FOwnKeys, item and its key are allocated at once, and Key points inside. }
         KeyLength: Integer;
         HashValue: LongWord;
         Data: TObject;
       end;

       THashSet = class(TObject)
       private
         FCount: LongWord;
         FOwnsObjects: Boolean;
         FOwnsKeys: Boolean;
         function Lookup(Key: Pointer; KeyLen: Integer; var Found: Boolean;
           CanCreate: Boolean): PHashSetItem;
         procedure Resize(NewCapacity: LongWord);
       protected
         FBucket: PPHashSetItem;
         FBucketCount: LongWord;
         class procedure FreeItem(Item:PHashSetItem); virtual;
         class function SizeOfItem: Integer; virtual;
         function CreateItem(Key: Pointer; KeyLen: Integer; HashValue: LongWord): PHashSetItem;
       public
         constructor Create(InitSize: Integer; OwnKeys, OwnObjects: Boolean);
         destructor Destroy; override;
         procedure Clear;
         { finds an entry by key }
         function Find(Key: Pointer; KeyLen: Integer): PHashSetItem;virtual;
         { finds an entry, creates one if not exists }
         function FindOrAdd(Key: Pointer; KeyLen: Integer;
           var Found: Boolean): PHashSetItem;virtual;
         { finds an entry, creates one if not exists }
         function FindOrAdd(Key: Pointer; KeyLen: Integer): PHashSetItem;virtual;
         { returns Data by given Key }
         function Get(Key: Pointer; KeyLen: Integer): TObject;virtual;
         { removes an entry, returns False if entry wasn't there }
         function Remove(Entry: PHashSetItem): Boolean;
         property Count: LongWord read FCount;
       end;

{******************************************************************
                             TTagHasSet
*******************************************************************}
       PPTagHashSetItem = ^PTagHashSetItem;
       PTagHashSetItem = ^TTagHashSetItem;
       TTagHashSetItem = record
         Item: THashSetItem;
         Tag: LongWord;
       end;

       TTagHashSet = class(THashSet)
       private
         function Lookup(Key: Pointer; KeyLen: Integer; Tag: LongWord; var Found: Boolean;
           CanCreate: Boolean): PTagHashSetItem;
       protected
         class function SizeOfItem: Integer; override;
       public
         { finds an entry by key }
         function Find(Key: Pointer; KeyLen: Integer; Tag: LongWord): PTagHashSetItem; reintroduce;
         { finds an entry, creates one if not exists }
         function FindOrAdd(Key: Pointer; KeyLen: Integer; Tag: LongWord;
           var Found: Boolean): PTagHashSetItem; reintroduce;
         { finds an entry, creates one if not exists }
         function FindOrAdd(Key: Pointer; KeyLen: Integer; Tag: LongWord): PTagHashSetItem; reintroduce;
         { returns Data by given Key }
         function Get(Key: Pointer; KeyLen: Integer; Tag: LongWord): TObject; reintroduce;
       end;


{******************************************************************
                             tbitset
*******************************************************************}

       { tbitset }

       TBitSet = class
       private
         FData: TByteDynArray;
         function GetDataSize: LongInt;
       public
         constructor Create(InitSize: LongInt);
         constructor Create_ByteSize(ByteSize: LongInt);
         destructor Destroy; override;
         procedure Clear; {$ifdef CCLASSESINLINE}inline;{$endif}
         procedure Grow(NSize: LongInt);
         { sets a bit }
         procedure Include(Index: LongInt);
         { clears a bit }
         procedure Exclude(Index: LongInt);
         { finds an entry, creates one if not exists }
         function IsSet(Index: LongInt): Boolean;

         procedure AddSet(ASet: TBitSet);
         procedure Subset(ASet: TBitSet);

         property Data: TByteDynArray read FData;
         property DataSize: LongInt read GetDataSize;
      end;


    function FPHash(P: PChar; Len: Integer; Tag: LongWord): LongWord;
    function FPHash(P: PChar; Len: Integer): LongWord; inline;
    function FPHash(const S:ShortString):LongWord; inline;
    function FPHash(const A:AnsiString):LongWord; inline;

    function ExtractStrings(Separators, WhiteSpace: TSysCharSet; Content: PChar; var Strings: TDynStringArray; AddEmptyStrings : Boolean = False): Integer;

implementation


{*****************************************************************************
                                    Memory debug
*****************************************************************************}
    function ExtractStrings(Separators, WhiteSpace: TSysCharSet; Content: PChar; var Strings: TDynStringArray; AddEmptyStrings : Boolean = False): Integer;
    var
      B, C : PChar;

      procedure SkipWhitespace;
        begin
          while (C^ in WhiteSpace) do
            Inc (C);
        end;

      procedure AddString;
        var
          L : Integer;
          S : string;
        begin
          L := C-B;
          S:='';
          if (L > 0) or AddEmptyStrings then
            begin
              SetLength(S, L);
              if L>0 then
                Move (B^, S[1],L*SizeOf(Char));
              L:=Length(Strings);
              SetLength(Strings,L+1);
              Strings[L]:=S;
              Inc (Result);
            end;
        end;

    var
      Quoted : Char;
    begin
      Result := 0;
      C := Content;
      Quoted := #0;
      Separators := Separators + [#13, #10] - ['''','"'];
      SkipWhitespace;
      B := C;
      while (C^ <> #0) do
        begin
          if (C^ = Quoted) then
            begin
              if ((C+1)^ = Quoted) then
                Inc (C)
              else
                Quoted := #0
            end
          else if (Quoted = #0) and (C^ in ['''','"']) then
            Quoted := C^;
          if (Quoted = #0) and (C^ in Separators) then
            begin
              AddString;
              Inc (C);
              SkipWhitespace;
              B := C;
            end
          else
            Inc (C);
        end;
      if (C <> B) then
        AddString;
    end;

    constructor TMemDebug.Create(const S:string);
      begin
        InfoStr:=S;
        TotalMem:=0;
        Start;
      end;


    procedure TMemDebug.Start;

      var
        Status : TFPCHeapStatus;

      begin
        Status:=GetFPCHeapStatus;
        StartMem:=Status.CurrHeapUsed;
      end;


    procedure TMemDebug.Stop;
      var
        Status : TFPCHeapStatus;
      begin
        if StartMem<>0 then
         begin
           Status:=GetFPCHeapStatus;
           Inc(TotalMem,StartMem-Status.CurrHeapUsed);
           StartMem:=0;
         end;
      end;


    destructor TMemDebug.Destroy;
      begin
        Stop;
        Show;
      end;


    procedure TMemDebug.Show;
      begin
        Write('memory [',InfoStr,'] ');
        if TotalMem>0 then
         WriteLn(DStr(TotalMem shr 10),' Kb released')
        else
         WriteLn(DStr((-TotalMem) shr 10),' Kb allocated');
      end;


{*****************************************************************************
               TFPObjectList (Copied from rtl/objpas/classes/lists.inc)
*****************************************************************************}

procedure TFPList.RaiseIndexError(Index : Integer);
begin
  Error(SListIndexError, Index);
end;

function TFPList.Get(Index: Integer): Pointer;
begin
  If (Index < 0) or (Index >= FCount) then
    RaiseIndexError(Index);
  Result:=FList[Index];
end;

procedure TFPList.Put(Index: Integer; Item: Pointer);
begin
  if (Index < 0) or (Index >= FCount) then
    RaiseIndexError(Index);
  FList[Index] := Item;
end;

function TFPList.Extract(Item: Pointer): Pointer;
var
  I : Integer;
begin
  Result := nil;
  I := IndexOf(Item);
  if I >= 0 then
   begin
     Result := Item;
     FList[I] := nil;
     Delete(I);
   end;
end;

procedure TFPList.SetCapacity(NewCapacity: Integer);
begin
  If (NewCapacity < FCount) or (NewCapacity > MaxListSize) then
     Error (SListCapacityError, NewCapacity);
  if NewCapacity = FCapacity then
    Exit;
  ReAllocMem(FList, SizeOf(Pointer)*NewCapacity);
  FCapacity := NewCapacity;
end;

procedure TFPList.SetCount(NewCount: Integer);
begin
  if (NewCount < 0) or (NewCount > MaxListSize)then
    Error(SListCountError, NewCount);
  If NewCount > FCount then
    begin
    If NewCount > FCapacity then
      SetCapacity(NewCount);
    If FCount < NewCount then
      FillChar(FList[FCount], (NewCount-FCount) *  SizeOf(Pointer), 0);
    end;
  FCount := NewCount;
end;

destructor TFPList.Destroy;
begin
  Self.Clear;
  inherited Destroy;
end;

function TFPList.Add(Item: Pointer): Integer;
begin
  if FCount = FCapacity then
    Self.Expand;
  FList[FCount] := Item;
  Result := FCount;
  Inc(FCount);
end;

procedure TFPList.Clear;
begin
  if Assigned(FList) then
  begin
    SetCount(0);
    SetCapacity(0);
    FList := nil;
  end;
end;

procedure TFPList.Delete(Index: Integer);
begin
  If (Index<0) or (Index>=FCount) then
    Error (SListIndexError, Index);
  Dec(FCount);
  System.Move (FList[Index+1], FList[Index], (FCount - Index) * SizeOf(Pointer));
  { Shrink the list if appropriate }
  if (FCapacity > 256) and (FCount < FCapacity shr 2) then
  begin
    FCapacity := FCapacity shr 1;
    ReAllocMem(FList, SizeOf(Pointer) * FCapacity);
  end;
end;

class procedure TFPList.Error(const Msg: string; Data: PtrInt);
begin
  Raise EListError.CreateFmt(Msg,[Data]) at get_caller_addr(Get_Frame), Get_Caller_Frame(Get_Frame);
end;

procedure TFPList.Exchange(Index1, Index2: Integer);
var
  Temp : Pointer;
begin
  If ((Index1 >= FCount) or (Index1 < 0)) then
    Error(SListIndexError, Index1);
  If ((Index2 >= FCount) or (Index2 < 0)) then
    Error(SListIndexError, Index2);
  Temp := FList[Index1];
  FList[Index1] := FList[Index2];
  FList[Index2] := Temp;
end;

function TFPList.Expand: TFPList;
var
  IncSize : LongInt;
begin
  Result := Self;
  if FCount < FCapacity then
    Exit;
  IncSize := SizeOf(PtrInt)*2;
  if FCapacity > 127 then
    Inc(IncSize, FCapacity shr 2)
  else if FCapacity > SizeOf(PtrInt)*4 then
    Inc(IncSize, FCapacity shr 1)
  else if FCapacity >= SizeOf(PtrInt) then
    Inc(IncSize,SizeOf(PtrInt));
  SetCapacity(FCapacity + IncSize);
end;

function TFPList.First: Pointer;
begin
  If FCount<>0 then
    Result := Items[0]
  else
    Result := Nil;
end;

function TFPList.IndexOf(Item: Pointer): Integer;
begin
  Result:=
{$if defined(CPU32)}
    IndexDWord
{$elseif defined(CPU64)}
    IndexQWord
{$else}
  {$error unknown pointer size}
{$endif}
      (FList^, FCount, PtrUInt(Item));
end;

function TFPList.IndexOfItem(Item: Pointer; Direction: TDirection): Integer;
var
  PSrc  : PPointer;
  Index : Integer;
begin
  if Direction=FromBeginning then
    Result:=IndexOf(Item)
  else
    begin
      Result:=-1;
      if FCount>0 then
        begin
          PSrc:=@FList[FCount-1];
          For Index:=FCount-1 downto 0 Do
            begin
              if PSrc^=Item then
                begin
                  Result:=Index;
                  Exit;
                end;
              Dec(PSrc);
            end;
        end;
    end;
end;

procedure TFPList.Insert(Index: Integer; Item: Pointer);
begin
  if (Index < 0) or (Index > FCount )then
    Error(SListIndexError, Index);
  iF FCount = FCapacity then Self.Expand;
  if Index<FCount then
    System.Move(FList[Index], FList[Index+1], (FCount - Index) * SizeOf(Pointer));
  FList[Index] := Item;
  FCount := FCount + 1;
end;

function TFPList.Last: Pointer;
begin
  If FCount<>0 then
    Result := Items[FCount - 1]
  else
    Result := nil
end;

procedure TFPList.Move(CurIndex, NewIndex: Integer);
var
  Temp : Pointer;
begin
  if ((CurIndex < 0) or (CurIndex > Count - 1)) then
    Error(SListIndexError, CurIndex);
  if (NewIndex < 0) then
    Error(SListIndexError, NewIndex);
  Temp := FList[CurIndex];
  FList[CurIndex] := nil;
  Self.Delete(CurIndex);
  Self.Insert(NewIndex, nil);
  FList[NewIndex] := Temp;
end;

function TFPList.Remove(Item: Pointer): Integer;
begin
  Result := IndexOf(Item);
  If Result <> -1 then
    Self.Delete(Result);
end;

procedure TFPList.Pack;
var
  NewCount,
  I : Integer;
  PDest,
  PSrc : PPointer;
begin
  NewCount:=0;
  PSrc:=@FList[0];
  PDest:=PSrc;
  For I:=0 To FCount-1 Do
    begin
      if Assigned(PSrc^) then
        begin
          PDest^:=PSrc^;
          Inc(PDest);
          Inc(NewCount);
        end;
      Inc(PSrc);
    end;
  FCount:=NewCount;
end;


Procedure QuickSort(FList: PPointer; L, R : LongInt;Compare: TListSortCompare);
var
  I, J, P: LongInt;
  PItem, Q : Pointer;
begin
 repeat
   I := L;
   J := R;
   P := (L + R) div 2;
   repeat
     PItem := FList[P];
     while Compare(PItem, FList[I]) > 0 do
       I := I + 1;
     while Compare(PItem, FList[J]) < 0 do
       J := J - 1;
     If I <= J then
     begin
       Q := FList[I];
       FList[I] := FList[J];
       FList[J] := Q;
       if P = I then
        P := J
       else if P = J then
        P := I;
       I := I + 1;
       J := J - 1;
     end;
   until I > J;
   if L < J then
     QuickSort(FList, L, J, Compare);
   L := I;
 until I >= R;
end;

procedure TFPList.Sort(Compare: TListSortCompare);
begin
  if Not Assigned(FList) or (FCount < 2) then Exit;
  QuickSort(FList, 0, FCount-1, Compare);
end;

procedure TFPList.Assign(Obj: TFPList);
var
  I: Integer;
begin
  Clear;
  for I := 0 to Obj.Count - 1 do
    Add(Obj[I]);
end;


procedure TFPList.ForEachCall(Proc2Call:TListCallback;Arg:Pointer);
var
  I : Integer;
  P : Pointer;
begin
  For I:=0 To Count-1 Do
    begin
      P:=FList[I];
      if Assigned(P) then
        Proc2Call(P,Arg);
    end;
end;


procedure TFPList.ForEachCall(Proc2Call:TListStaticCallback;Arg:Pointer);
var
  I : Integer;
  P : Pointer;
begin
  For I:=0 To Count-1 Do
    begin
      P:=FList[I];
      if Assigned(P) then
        Proc2Call(P,Arg);
    end;
end;

class procedure TFPList.AddOnDemand(var Lst: TFPList; Item: Pointer);
begin
  if not Assigned(Lst) then
      Lst := TFPList.Create;
  Lst.Add(Item);
end;

class procedure TFPList.FreeAndNilObjects(var Lst: TFPList);
var
  Lp: PPointer;
  I: SizeInt;
begin
  if not Assigned(Lst) then
    Exit;
  Lp := Lst.FList;
  for I := 0 to Lst.Count-1 do
    TObject(Lp[I]).Free; // no nil needed
  Lst.Free;
  Lst := nil;
end;

procedure fpc_finalize(Data, TypeInfo: Pointer); external;

class procedure TFPList.FreeAndNilDisposing(var Lst: TFPList; ItemType: Pointer);
var
  Lp: PPointer;
  I: SizeInt;
begin
  if not Assigned(Lst) then
    Exit;
  Lp := Lst.FList;
  for I := 0 to Lst.Count-1 do
    if Assigned(Lp[I]) then
      begin
        fpc_finalize(Lp[I],ItemType);
        FreeMem(Lp[I]);
      end;
  Lst.Free;
  Lst := nil;
end;


{*****************************************************************************
            TFPObjectList (Copied from rtl/objpas/classes/lists.inc)
*****************************************************************************}

constructor TFPObjectList.Create(FreeObjects : Boolean);
begin
  Create;
  FFreeObjects := FreeObjects;
end;

destructor TFPObjectList.Destroy;
begin
  if (FList <> nil) then
  begin
    Clear;
    FList.Destroy;
    FList:=nil;
  end;
  inherited Destroy;
end;

procedure TFPObjectList.Clear;
var
  I: Integer;
begin
  if FFreeObjects then
    for I := 0 to FList.Count - 1 do
      TObject(FList[I]).Free; // no nil needed
  FList.Clear;
end;

constructor TFPObjectList.Create;
begin
  inherited Create;
  FList := TFPList.Create;
  FFreeObjects := True;
end;

function TFPObjectList.IndexOf(AObject: TObject): Integer;
begin
  Result := FList.IndexOf(Pointer(AObject));
end;

function TFPObjectList.IndexOfItem(AObject: TObject; Direction: TDirection): Integer; {$ifdef CCLASSESINLINE}inline;{$endif}
begin
  Result := FList.IndexOfItem(Pointer(AObject),Direction);
end;

function TFPObjectList.GetCount: Integer;
begin
  Result := FList.Count;
end;

procedure TFPObjectList.SetCount(const AValue: Integer);
begin
  if FList.Count <> AValue then
    FList.Count := AValue;
end;

function TFPObjectList.GetItem(Index: Integer): TObject;
begin
  Result := TObject(FList[Index]);
end;

procedure TFPObjectList.SetItem(Index: Integer; AObject: TObject);
begin
  if OwnsObjects then
    TObject(FList[Index]).Free; // no nil needed
  FList[Index] := AObject;
end;

procedure TFPObjectList.SetCapacity(NewCapacity: Integer);
begin
  FList.Capacity := NewCapacity;
end;

function TFPObjectList.GetCapacity: Integer;
begin
  Result := FList.Capacity;
end;

function TFPObjectList.Add(AObject: TObject): Integer;
begin
  Result := FList.Add(AObject);
end;

procedure TFPObjectList.Delete(Index: Integer);
begin
  if OwnsObjects then
    TObject(FList[Index]).Free; // no nil needed
  FList.Delete(Index);
end;

procedure TFPObjectList.Exchange(Index1, Index2: Integer);
begin
  FList.Exchange(Index1, Index2);
end;

function TFPObjectList.Expand: TFPObjectList;
begin
  FList.Expand;
  Result := Self;
end;

function TFPObjectList.Extract(Item: TObject): TObject;
begin
  Result := TObject(FList.Extract(Item));
end;

function TFPObjectList.Remove(AObject: TObject): Integer;
begin
  Result := IndexOf(AObject);
  if (Result <> -1) then
  begin
    if OwnsObjects then
      TObject(FList[Result]).Free; // no nil needed
    FList.Delete(Result);
  end;
end;

function TFPObjectList.FindInstanceOf(AClass: TClass; AExact: Boolean; AStartAt : Integer): Integer;
var
  I : Integer;
begin
  I:=AStartAt;
  Result:=-1;
  If AExact then
    while (I<Count) and (Result=-1) do
      If Items[I].ClassType=AClass then
        Result:=I
      else
        Inc(I)
  else
    while (I<Count) and (Result=-1) do
      If Items[I].InheritsFrom(AClass) then
        Result:=I
      else
        Inc(I);
end;

procedure TFPObjectList.Insert(Index: Integer; AObject: TObject);
begin
  FList.Insert(Index, Pointer(AObject));
end;

procedure TFPObjectList.Move(CurIndex, NewIndex: Integer);
begin
  FList.Move(CurIndex, NewIndex);
end;

procedure TFPObjectList.Assign(Obj: TFPObjectList);
begin
  Clear;
  ConcatListCopy(Obj);
end;

procedure TFPObjectList.ConcatListCopy(Obj: TFPObjectList);
var
  I: Integer;
begin
  for I := 0 to Obj.Count - 1 do
    Add(Obj[I]);
end;

procedure TFPObjectList.Pack;
begin
  FList.Pack;
end;

procedure TFPObjectList.Sort(Compare: TListSortCompare);
begin
  FList.Sort(Compare);
end;

function TFPObjectList.First: TObject;
begin
  Result := TObject(FList.First);
end;

function TFPObjectList.Last: TObject;
begin
  Result := TObject(FList.Last);
end;

procedure TFPObjectList.ForEachCall(Proc2Call:TObjectListCallback;Arg:Pointer);
begin
  FList.ForEachCall(TListCallback(Proc2Call),Arg);
end;

procedure TFPObjectList.ForEachCall(Proc2Call:TObjectListStaticCallback;Arg:Pointer);
begin
  FList.ForEachCall(TListStaticCallback(Proc2Call),Arg);
end;


{*****************************************************************************
                            TFPHashList
*****************************************************************************}

// MurmurHash3_32
function FPHash(P: PChar; Len: Integer; Tag: LongWord): LongWord;
const
  C1 = UInt32($cc9e2d51);
  C2 = UInt32($1b873593);
var
  H, Tail: UInt32;
  E4: PChar;
  Len4, NTail: SizeUInt;
begin
{$push}
{$q-,r-}
  H := Tag;

  Len4 := Len and not Integer(SizeOf(UInt32) - 1); { len div sizeof(uint32) * sizeof(uint32) }
  E4 := P + Len4;
  NTail := Len - Len4;
  while P < E4 do
    begin
      { If independence on endianness is desired, unaligned(pUint32(p)^) can be replaced with LEtoN(unaligned(pUint32(p)^)). }
      H := RolDWord(H xor (RolDWord(unaligned(PUInt32(P)^) * C1, 15) * C2), 13) * 5 + $e6546b64;
      P := P + SizeOf(UInt32);
    end;

  if NTail > 0 then
    begin
      { tail is 1 to 3 bytes }
      case NTail of
        3: Tail := unaligned(PUInt16(P)^) or UInt32(P[2]) shl 16; { unaligned(pUint16(p^)) can be LEtoNed for portability }
        2: Tail := unaligned(PUInt16(P)^); { unaligned(pUint16(p^)) can be LEtoNed for portability }
        {1:} else Tail := UInt32(P^);
      end;
      H := H xor (RolDWord(Tail * C1, 15) * C2);
    end;

  H := H xor UInt32(Len);
  H := (H xor (H shr 16)) * $85ebca6b;
  H := (H xor (H shr 13)) * $c2b2ae35;
  Result := H xor (H shr 16);
{$pop}
end;

function FPHash(P: PChar; Len: Integer): LongWord; inline;
begin
  Result:=FPHash(P,Len, 0);
end;


function FPHash(const S: ShortString): LongWord; inline;
begin
  Result:=FPHash(PChar(@S[1]),Length(S));
end;


function FPHash(const A: AnsiString): LongWord; inline;
begin
  Result:=FPHash(PChar(A),Length(A));
end;


procedure TMemoryRegion.Init(PreAllocate: SizeUInt=0);
begin
  FTop:=nil;
  if PreAllocate>MinMemoryRegionNodeSize then
    FTop:=AllocateNode(0, PreAllocate);
end;


procedure TMemoryRegion.Done;
begin
  Clear;
end;


function TMemoryRegion.Push(N: SizeUInt): Pointer;
var
  Top: PMemoryRegionNode;
  Start: SizeUInt;
begin
  Top:=FTop;
  if Assigned(Top) then
    begin
      Start:=Top^.N;
      if N<=SizeUInt(Top^.Alloc-Start) then
        begin
          Top^.N:=Start+N;
          Exit(PByte(Top^.Data)+Start);
        end;
     end;
  Result:=PushNewNode(N);
end;


procedure TMemoryRegion.Clear;
var
  Cur, Next: PMemoryRegionNode;
begin
  Cur:=FTop;
  FTop:=nil;
  while Assigned(Cur) do
    begin
      Next:=Cur^.Next;
      FreeMem(Cur);
      Cur:=Next;
    end;
end;


function TMemoryRegion.CalcSumSize: SizeUInt;
var
  N: PMemoryRegionNode;
begin
  Result:=0;
  N:=FTop;
  while Assigned(N) do
    begin
      Result:=Result+N^.N;
      N:=N^.Next;
    end;
end;


class function TMemoryRegion.AllocateNode(N, Alloc: SizeUInt): PMemoryRegionNode;
begin
  Result:=GetMem(PtrUInt(@PMemoryRegionNode(nil)^.Data)+Alloc);
  Result^.N:=N;
  Result^.Alloc:=Alloc;
  Result^.Next:=nil;
end;


function TMemoryRegion.PushNewNode(N: SizeUInt): Pointer;
var
  Alloc, SumSize: SizeUInt;
  NewNode: PMemoryRegionNode;
begin
  { The absolute minimum to allocate is the required contiguous n. }
  SumSize:=CalcSumSize;
  Alloc:=MinMemoryRegionNodeSize+N+SumSize div 4; { const+n+25%. }

  NewNode:=AllocateNode(N, Alloc);
  NewNode^.Next:=FTop;
  FTop:=NewNode;
  Result:=PByte(NewNode^.Data);
end;


function ViGet(Data: PSizeUInt; Index, BitsPerIndex: SizeUInt): SizeUInt;
begin
  Index:=Index*BitsPerIndex;
  Data:=Data+Index div BitSizeOf(SizeUInt);
  Index:=Index mod BitSizeOf(SizeUInt);
  Result:=Data^ shr Index;
  Index:=BitSizeOf(Data^)-Index;
  if BitsPerIndex<=Index then
    Result:=Result and (SizeUInt(1) shl BitsPerIndex-1)
  else
    Result:=Result or Data[1] shl Index and (SizeUInt(1) shl BitsPerIndex-1);
end;


procedure ViSet(Data: PSizeUInt; Index, BitsPerIndex, Value: SizeUInt);
begin
  Index:=Index*BitsPerIndex;
  Data:=Data+Index div BitSizeOf(SizeUInt);
  Index:=Index mod BitSizeOf(SizeUInt);
  if Index+BitsPerIndex<=BitSizeOf(Data^) then
    Data^:=Data^ and not ((SizeUInt(1) shl BitsPerIndex-1) shl Index) or Value shl Index
  else
  begin
    Data^:=SizeUInt(Data^ and (SizeUInt(1) shl Index - 1) or Value shl Index);
    Index:=BitSizeOf(Data^)-Index;
    Value:=Value shr Index;
    Index:=BitsPerIndex-Index;
    Data[1]:=Data[1] shr Index shl Index or Value;
  end;
end;


function ViDataSize(N, BitsPerIndex: SizeUInt): SizeUInt;
begin
  Result:=(N*BitsPerIndex+(BitSizeOf(SizeUInt)-1)) div BitSizeOf(SizeUInt)*SizeOf(SizeUInt);
end;


function TViHashList.Get(Index: SizeInt): Pointer;
begin
  If SizeUInt(Index)>=SizeUInt(FCount) then
    RaiseIndexError(Index);
  Result:=FItems[Index].Data;
end;


procedure TViHashList.Put(Index: SizeInt; Item: Pointer);
begin
  If SizeUInt(Index)>=SizeUInt(FCount) then
    RaiseIndexError(Index);
  FItems[Index].Data:=Item;
end;


class procedure TViHashList.RaiseIndexError(Index: SizeInt);
begin
  TFPList.Error(SListIndexError, Index);
end;


procedure TViHashList.SetupEmptyTable;
const
  { 1-element FHash array containing one zero, which is ViEmpty.
    Any searches will answer "not found", and any additions will instantly rehash. }
  EmptyFHash: SizeUInt = 0;
begin
  FHash:=@EmptyFHash;
  FItems:=nil;
  FBitsPerIndex:=1;
  FHashMask:=0;
  FCapacity:=0;
end;


procedure TViHashList.Rehash(ForItems: SizeUInt; Mode: TViRehashMode=vi_Auto);
var
  NewCapacity, NewHashMask, NewBitsPerIndex, ItemsOffset, RegionSize: SizeUInt;
  I: SizeInt;
  NewHash: PSizeUInt;
  NewItems: PViHashListItem;
  ShortcutReAdd: Boolean;
begin
  if ForItems=0 then
    begin
      Clear;
      Exit;
    end;
  if ForItems>MaxHashListSize then
    TFPList.Error(SListCapacityError, ForItems);

  { Can be something like "137.5% ForItems", but with bitwise indices, better to just derive the capacity later from chosen index type limit,
    which will be 200% at most -
    this way, both capacity and hash mask size become beautiful powers of two,
    saving on rehashes ("shortcutReAdd" branch, while still required for degenerate scenarios, becomes de facto unreachable),
    and often even on memory (though the reason for the latter is unclear to me; maybe "137.5%" in conjunction with "UpToPow2" introduces extra breakpoints). }
  NewCapacity:=ForItems;

  { Max index for "capacity" items is "ViRealIndexOffset + (capacity - 1)", which can be rewritten as "capacity + (ViRealIndexOffset - 1)". }
  NewBitsPerIndex:=1+BsrDWord(NewCapacity+(ViRealIndexOffset-1));
  if not ((NewBitsPerIndex>=1) and (NewBitsPerIndex<=BitSizeOf(SizeUInt)-1)) then
    InternalErrorProc(2022120701);

  { In place of explicit over-allocation, increase capacity to index type limit. }
  if Mode<>vi_Tight then
    NewCapacity:=(SizeUInt(1) shl NewBitsPerIndex-1)-(ViRealIndexOffset-1);

  { Take item list capacity rounded up to power of two. This can give 50% to 100% load factor.
    If it gives more than 3/4, double the hash capacity again. After that, possible load factors will range from 37.5% to 75%.
    Even load factors greater than 100% will work though. Low factors are just slightly faster, at the expense of memory. }
  NewHashMask:=SizeUInt(1) shl (1+BsrDWord((NewCapacity-1) or 1))-1; { UpToPow2(newCapacity)-1 }
  if NewHashMask div 4*3<NewCapacity then
    NewHashMask:=NewHashMask*2+1;

  { Allocating and marking up the region for FHash + FItems. }
  ItemsOffset:=Align(ViDataSize(NewHashMask+1,NewBitsPerIndex), SizeUInt(SizeOf(Pointer)));
  RegionSize:=ItemsOffset+SizeOf(TViHashListItem)*NewCapacity;
  NewHash:=GetMem(RegionSize);
  NewItems:=Pointer(NewHash)+ItemsOffset;

  { If hash mask hasn't changed (this is possible because of arbitrariness of FCapacity),
    items re-adding can be, and is, shortcutted.
    .Pack corrupts indices and expects from .Rehash to recalculate them, so is incompatible with this. }
  ShortcutReAdd:=(FHashMask=NewHashMask) and (Mode<>vi_Pack);
  if ShortcutReAdd then
    begin
      { If even index type hasn't changed, just copy FHash. Else convert. }
      if NewBitsPerIndex=FBitsPerIndex then
        Move(FHash^, NewHash^, ViDataSize(NewHashMask+1,NewBitsPerIndex))
      else
        for I:=0 to NewHashMask do
          ViSet(NewHash, I, NewBitsPerIndex, ViGet(FHash, I, FBitsPerIndex));
    end
  else
    { Otherwise set all indices to ViEmpty. }
    FillChar(NewHash^, ViDataSize(NewHashMask+1,NewBitsPerIndex), 0);

  { Move items as raw memory, even managed (old area is then deallocated without finalizing). }
  Move(FItems^, NewItems^, FCount*SizeOf(TViHashListItem));

  { Free the old table. "Assigned(FItems)" means that the table was not the fake table set up by SetupEmptyTable.
    Items were just moved into a new place so shouldn't be finalized. }
  if Assigned(FItems) then
    FreeMem(FHash);

  FHash:=NewHash;
  FItems:=NewItems;
  FBitsPerIndex:=NewBitsPerIndex;
  FHashMask:=NewHashMask;
  FCapacity:=NewCapacity;

  { Re-add items if re-adding was not shortcutted before. }
  if not ShortcutReAdd then
    for I:=0 to FCount-1 do
      AddToHashTable(FItems+I, I);
end;


{$ifndef symansistr}
function TViHashList.AddStrToRegion(const S: TSymStr): PSymStr;
var
  Size: SizeUInt;
begin
  Size:=1+Length(S);
  Result:=FShortStringRegion.Push(Size);
  System.Move(S[0],Result^,Size);
end;
{$endif}


procedure TViHashList.Shrink;
begin
  if (FCapacity >= 64) and (UInt32(FCount) < FCapacity div 4) then
    Rehash(UInt32(FCount)+UInt32(FCount) div 4);
end;


procedure TViHashList.AddToHashTable(Item: PViHashListItem; Index: SizeUInt);
var
  HashIndex: SizeUInt;
begin
  if not Assigned(Item^.Data) then
    Exit;
  HashIndex:=Item^.HashValue and FHashMask;
  FItems[Index].Next:=SizeInt(ViGet(FHash, HashIndex, FBitsPerIndex))-ViRealIndexOffset;
  ViSet(FHash, HashIndex, FBitsPerIndex, ViRealIndexOffset+Index);
end;


function TViHashList.InternalFind(AHash:LongWord;const AName:TSymStr;out PrevIndex:SizeInt):SizeInt;
var
  It: PViHashListItem;
begin
  Result:=SizeInt(ViGet(FHash, AHash and FHashMask, FBitsPerIndex))-ViRealIndexOffset;
  PrevIndex:=-1;
  repeat
    if Result<0 then
      Exit;
    It:=FItems+Result;
    if Assigned(It^.Data) and (AHash=It^.HashValue) and (AName=It^.Str {$ifndef symansistr} ^ {$endif}) then
      Exit;
    PrevIndex:=Result;
    Result:=FItems[Result].Next;
  until False;
end;


procedure TViHashList.RemoveFromHashTable(AHash:LongWord;Index, PrevIndex: SizeInt);
var
  Next: SizeInt;
begin
  Next:=SizeInt(FItems[Index].Next);
  if PrevIndex<0 then
    ViSet(FHash, AHash and FHashMask, FBitsPerIndex, ViRealIndexOffset+Next)
  else
    FItems[PrevIndex].Next:=Next;
end;


procedure TViHashList.SetCapacity(NewCapacity: UInt32);
begin
  if NewCapacity < UInt32(FCount) then InternalErrorProc(2021122605);
  Rehash(NewCapacity, vi_Tight);
end;


constructor TViHashList.Create;
begin
  inherited Create;
{$ifndef symansistr}
  FShortStringRegion.Init;
{$endif}
  SetupEmptyTable;
end;


destructor TViHashList.Destroy;
begin
  Clear;
{$ifndef symansistr}
  FShortStringRegion.Done;
{$endif}
  inherited Destroy;
end;


function TViHashList.Add(const AName:TSymStr;Item: Pointer): SizeInt;
begin
  Result:=AddWithHash(AName, FPHash(AName), Item);
end;


function TViHashList.AddWithHash(const AName: TSymStr; AHash: LongWord;
  Item: Pointer): SizeInt;
var
  It: PViHashListItem;
begin
  Result:=FCount;
  if UInt32(Result)=FCapacity then
    Rehash(Result+1);

  It:=FItems+Result;
  Initialize(It^);
  It^.HashValue:=AHash;
  It^.Data:=Item;
{$ifdef symansistr}
  It^.Str:=AName;
{$else}
  It^.Str:=AddStrToRegion(AName);
{$endif}

  AddToHashTable(It, Result);
  FCount:=Result+1;
end;


procedure TViHashList.Clear;
begin
  if Assigned(FItems) then
    begin
      Finalize(FItems^, FCount);
      FreeMem(FHash);
      SetupEmptyTable;
      FCount:=0;
{$ifndef symansistr}
      FShortStringRegion.Clear;
{$endif}
    end;
end;


function TViHashList.NameOfIndex(Index: SizeInt): TSymStr;
begin
  if SizeUInt(Index)>=SizeUInt(FCount) then
    RaiseIndexError(Index);
  Result:=FItems[Index].Str {$ifndef symansistr} ^ {$endif};
end;


function TViHashList.HashOfIndex(Index: SizeInt): LongWord;
begin
  if SizeUInt(Index)>=SizeUInt(FCount) then
    RaiseIndexError(Index);
  Result:=FItems[Index].HashValue;
end;


function TViHashList.GetNextCollision(Index: SizeInt): SizeInt;
begin
  Result:=FItems[Index].Next;
end;


procedure TViHashList.Delete(Index: SizeInt);
var
  I: SizeInt;
begin
  If SizeUInt(Index)>=SizeUInt(FCount) then
    RaiseIndexError(Index);

  { Remove from array, shifting items above. }
  Finalize(FItems[Index]);
  Move(FItems[Index+1], FItems[Index], (FCount-Index-1)*SizeOf(TViHashListItem));
  Dec(FCount);

  { Rebuild the table. This is much faster than trying to fix up indices. :( }
  FillChar(FHash^, ViDataSize(FHashMask+1, FBitsPerIndex), 0);
  for I:=0 to FCount-1 do
    AddToHashTable(FItems+I, I);
  Shrink;
end;


function TViHashList.Extract(Item: Pointer): Pointer;
var
  I : SizeInt;
begin
  Result:=nil;
  I:=IndexOf(Item);
  if I>=0 then
   begin
     Result:=Item;
     Delete(I);
   end;
end;


function TViHashList.IndexOf(Item: Pointer): SizeInt;
var
  ItemP, ItemE: PViHashListItem;
begin
  Result:=0;
  ItemP:=FItems;
  ItemE:=ItemP+FCount;
  while ItemP<ItemE do
    begin
      if ItemP^.Data=Item then
        Exit;
      Inc(ItemP);
      Inc(Result);
    end;
  Result:=-1;
end;


function TViHashList.Find(const AName:TSymStr): Pointer;
begin
  Result:=FindWithHash(AName, FPHash(AName));
end;


function TViHashList.FindIndexOf(const AName:TSymStr): SizeInt;
var
  PrevIndex : SizeInt;
begin
  Result:=InternalFind(FPHash(AName),AName,PrevIndex);
end;


function TViHashList.FindWithHash(const AName:TSymStr;AHash:LongWord): Pointer;
var
  Index,
  PrevIndex : SizeInt;
begin
  Result:=nil;
  Index:=InternalFind(AHash,AName,PrevIndex);
  if Index>=0 then
    Result:=FItems[Index].Data;
end;


function TViHashList.Rename(const AOldName,ANewName:TSymStr): SizeInt;
var
  PrevIndex : SizeInt;
  OldHash : LongWord;
  It: PViHashListItem;
begin
  OldHash:=FPHash(AOldName);
  Result:=InternalFind(OldHash,AOldName,PrevIndex);
  if Result<0 then
    Exit;
  RemoveFromHashTable(OldHash, Result, PrevIndex);
  It:=FItems+Result;
  It^.HashValue:=FPHash(ANewName);
{$ifdef symansistr}
  It^.Str:=ANewName;
{$else}
  It^.Str:=AddStrToRegion(ANewName);
{$endif}
  AddToHashTable(It, Result);
end;


function TViHashList.Remove(Item: Pointer): SizeInt;
begin
  Result:=IndexOf(Item);
  if Result>=0 then
    Delete(Result);
end;


procedure TViHashList.Pack;
var
  ItemP, ItemE, Target: PViHashListItem;
  Removed: SizeUInt;
begin
  ItemP:=FItems;
  ItemE:=ItemP+FCount;
  while ItemP<ItemE do
    if Assigned(ItemP^.Data) then
      Inc(ItemP)
    else
      Break;
  if ItemP<ItemE then
    begin
      Target:=ItemP;
      Inc(ItemP);
      while ItemP<ItemE do
        begin
          if Assigned(ItemP^.Data) then
            begin
              Target^:=ItemP^;
              Inc(Target);
            end;
          Inc(ItemP);
        end;
      Removed:=SizeUInt(Pointer(ItemE)-Pointer(Target)) div SizeOf(TViHashListItem);
      Finalize(Target^, Removed);
      FCount:=FCount-Removed;
    end;
  if UInt32(FCount)<>FCapacity then
    Rehash(FCount, vi_Pack);
end;


procedure TViHashList.ShowStatistics;
var
  HashMean,
  HashStdDev : Double;
  Index,
  I,J : SizeInt;
begin
  { Calculate Mean and StdDev }
  HashMean:=0;
  HashStdDev:=0;
  for I:=0 to FHashMask do
    begin
      J:=0;
      Index:=SizeInt(ViGet(FHash, I, FBitsPerIndex))-ViRealIndexOffset;
      while Index>=0 do
        begin
          Inc(J);
          Index:=FItems[Index].Next;
        end;
      HashMean:=HashMean+J;
      HashStdDev:=HashStdDev+Sqr(J);
    end;
  HashMean:=HashMean/(FHashMask+1);
  HashStdDev:=(HashStdDev-(FHashMask+1)*Sqr(HashMean));
  If FHashMask>0 then
    HashStdDev:=Sqrt(HashStdDev/FHashMask)
  else
    HashStdDev:=0;
  { Print info to stdout }
  WriteLn('HashSize   : ',FHashMask+1);
  WriteLn('HashMean   : ',HashMean:1:4);
  WriteLn('HashStdDev : ',HashStdDev:1:4);
  WriteLn('ListSize   : ',FCount,'/',FCapacity);
{$ifndef symansistr}
  WriteLn('StringSize : ',FShortStringRegion.CalcSumSize);
{$endif}
end;


procedure TViHashList.ForEachCall(Proc2Call:TListCallback;Arg:Pointer);
var
  I: SizeInt;
  P: Pointer;
begin
  for I:=0 to FCount-1 do
    begin
      P:=FItems[I].Data;
      if Assigned(P) then
        Proc2Call(P,Arg);
    end;
end;


procedure TViHashList.ForEachCall(Proc2Call:TListStaticCallback;Arg:Pointer);
var
  I: SizeInt;
  P: Pointer;
begin
  for I:=0 to FCount-1 do
    begin
      P:=FItems[I].Data;
      if Assigned(P) then
        Proc2Call(P,Arg);
    end;
end;


{*****************************************************************************
            TFPHashObjectList (Copied from rtl/objpas/classes/lists.inc)
*****************************************************************************}

constructor TFPHashObjectList.Create(FreeObjects : Boolean = True);
begin
  inherited Create;
  FHashList := TFPHashList.Create;
  FFreeObjects := FreeObjects;
end;

destructor TFPHashObjectList.Destroy;
begin
  if (FHashList <> nil) then
    begin
      Clear;
      FHashList.Destroy;
      FHashList:=nil;
    end;
  inherited Destroy;
end;

procedure TFPHashObjectList.Clear;
var
  I: Integer;
begin
  if FFreeObjects then
    for I := 0 to FHashList.Count - 1 do
      TObject(FHashList[I]).Free; // no nil needed
  FHashList.Clear;
end;

function TFPHashObjectList.IndexOf(AObject: TObject): Integer;
begin
  Result := FHashList.IndexOf(Pointer(AObject));
end;

function TFPHashObjectList.GetCount: Integer;
begin
  Result := FHashList.Count;
end;

function TFPHashObjectList.GetItem(Index: Integer): TObject;
begin
  Result := TObject(FHashList[Index]);
end;

procedure TFPHashObjectList.SetItem(Index: Integer; AObject: TObject);
begin
  if OwnsObjects then
    TObject(FHashList[Index]).Free; // no nil needed
  FHashList[Index] := AObject;
end;

procedure TFPHashObjectList.SetCapacity(NewCapacity: Integer);
begin
  FHashList.Capacity := NewCapacity;
end;

function TFPHashObjectList.GetCapacity: Integer;
begin
  Result := FHashList.Capacity;
end;

function TFPHashObjectList.Add(const AName:TSymStr;AObject: TObject): Integer;
begin
  Result := FHashList.Add(AName,AObject);
end;


function TFPHashObjectList.AddWithHash(const AName: TSymStr; AHash: LongWord;
  AObject: TObject): Integer;
begin
  Result:=FHashList.AddWithHash(AName, AHash, AObject);
end;

function TFPHashObjectList.NameOfIndex(Index: Integer): TSymStr;
begin
  Result := FHashList.NameOfIndex(Index);
end;

function TFPHashObjectList.HashOfIndex(Index: Integer): LongWord;
begin
  Result := FHashList.HashOfIndex(Index);
end;

function TFPHashObjectList.GetNextCollision(Index: Integer): Integer;
begin
  Result := FHashList.GetNextCollision(Index);
end;

procedure TFPHashObjectList.Delete(Index: Integer);
begin
  if OwnsObjects then
    TObject(FHashList[Index]).Free; // no nil needed
  FHashList.Delete(Index);
end;

function TFPHashObjectList.Extract(Item: TObject): TObject;
begin
  Result := TObject(FHashList.Extract(Item));
end;

function TFPHashObjectList.Remove(AObject: TObject): Integer;
begin
  Result := IndexOf(AObject);
  if (Result <> -1) then
    begin
      if OwnsObjects then
        TObject(FHashList[Result]).Free; // no nil needed
      FHashList.Delete(Result);
    end;
end;

function TFPHashObjectList.Find(const S:TSymStr): TObject;
begin
  Result:=TObject(FHashList.Find(S));
end;


function TFPHashObjectList.FindIndexOf(const S:TSymStr): Integer;
begin
  Result:=FHashList.FindIndexOf(S);
end;


function TFPHashObjectList.FindWithHash(const AName:TSymStr;AHash:LongWord): Pointer;
begin
  Result:=TObject(FHashList.FindWithHash(AName,AHash));
end;


function TFPHashObjectList.Rename(const AOldName,ANewName:TSymStr): Integer;
begin
  Result:=FHashList.Rename(AOldName,ANewName);
end;


function TFPHashObjectList.FindInstanceOf(AClass: TClass; AExact: Boolean; AStartAt : Integer): Integer;
var
  I : Integer;
begin
  I:=AStartAt;
  Result:=-1;
  If AExact then
    while (I<Count) and (Result=-1) do
      If Items[I].ClassType=AClass then
        Result:=I
      else
        Inc(I)
  else
    while (I<Count) and (Result=-1) do
      If Items[I].InheritsFrom(AClass) then
        Result:=I
      else
        Inc(I);
end;


procedure TFPHashObjectList.Pack;
begin
  FHashList.Pack;
end;


procedure TFPHashObjectList.ShowStatistics;
begin
  FHashList.ShowStatistics;
end;


procedure TFPHashObjectList.ForEachCall(Proc2Call:TObjectListCallback;Arg:Pointer);
begin
  FHashList.ForEachCall(TListCallback(Proc2Call),Arg);
end;


procedure TFPHashObjectList.ForEachCall(Proc2Call:TObjectListStaticCallback;Arg:Pointer);
begin
  FHashList.ForEachCall(TListStaticCallback(Proc2Call),Arg);
end;


{*****************************************************************************
                               TFPHashObject
*****************************************************************************}

procedure TFPHashObject.InternalChangeOwner(HashObjectList:TFPHashObjectList;const S:TSymStr);
begin
  InternalChangeOwnerWithHash(HashObjectList, S, FPHash(S));
end;


procedure TFPHashObject.InternalChangeOwnerWithHash(
  HashObjectList: TFPHashObjectList; const S: TSymStr; AHash: LongWord);
var
  Index : SizeInt;
  It : PViHashListItem;
begin
  FOwner:=HashObjectList;
  Index:=HashObjectList.AddWithHash(S, AHash, Self);
  It:=HashObjectList.List.List+Index;
{$ifdef symansistr}
  FStr:=S;
{$else}
  FStr:=It^.Str;
{$endif}
  FHash:=It^.HashValue;
end;


constructor TFPHashObject.CreateNotOwned;
{$ifndef symansistr}
const
  EmptyString: string[1] = '';
{$endif}
begin
{$ifdef symansistr}
  FStr:='';
{$else}
  FStr:=@EmptyString;
{$endif}
  Int32(FHash):=-1;
end;


constructor TFPHashObject.Create(HashObjectList:TFPHashObjectList;const S:TSymStr);
begin
  InternalChangeOwner(HashObjectList,S);
end;


procedure TFPHashObject.ChangeOwner(HashObjectList:TFPHashObjectList);
begin
  InternalChangeOwner(HashObjectList, FStr {$ifndef symansistr} ^ {$endif});
end;


procedure TFPHashObject.ChangeOwnerAndName(HashObjectList:TFPHashObjectList;const S:TSymStr);
begin
  InternalChangeOwner(HashObjectList,S);
end;


procedure TFPHashObject.ChangeOwnerAndNameWithHash(
  HashObjectList: TFPHashObjectList; const S: TSymStr; AHash: LongWord);
begin
  InternalChangeOwnerWithHash(HashObjectList, S, AHash);
end;


procedure TFPHashObject.Rename(const ANewName:TSymStr);
var
  Index : Integer;
  It : PViHashListItem;
begin
  Index:=FOwner.Rename(FStr {$ifndef symansistr} ^ {$endif},ANewName);
  if Index>=0 then
    begin
      It:=FOwner.List.List+Index;
{$ifdef symansistr}
      FStr:=ANewName;
{$else}
      FStr:=It^.Str;
{$endif}
      FHash:=It^.HashValue;
    end;
end;


function TFPHashObject.GetName:TSymStr;
begin
  Result:=FStr {$ifndef symansistr} ^ {$endif};
end;


function TFPHashObject.GetHash:LongWord;
begin
  Result:=FHash;
end;


{****************************************************************************
                             TLinkedListItem
 ****************************************************************************}

    constructor TLinkedListItem.Create;
      begin
        Previous:=nil;
        Next:=nil;
      end;


    destructor TLinkedListItem.Destroy;
      begin
      end;


    function TLinkedListItem.GetCopy:TLinkedListItem;
      var
        P : TLinkedListItem;
        L : Integer;
      begin
        P:=TLinkedListItemClass(ClassType).Create;
        L:=InstanceSize;
        Move(Pointer(Self)^,Pointer(P)^,L);
        Result:=P;
      end;


{****************************************************************************
                                   TLinkedList
 ****************************************************************************}

    constructor TLinkedList.Create;
      begin
        FFirst:=nil;
        FLast:=nil;
        FCount:=0;
        FNoClear:=False;
      end;


    destructor TLinkedList.Destroy;
      begin
        if not FNoClear then
         Clear;
      end;


    function TLinkedList.Empty:Boolean;
      begin
        Empty:=(FFirst=nil);
      end;


    procedure TLinkedList.Insert(Item:TLinkedListItem);
      begin
        if FFirst=nil then
         begin
           FLast:=Item;
           Item.Previous:=nil;
           Item.Next:=nil;
         end
        else
         begin
           FFirst.Previous:=Item;
           Item.Previous:=nil;
           Item.Next:=FFirst;
         end;
        FFirst:=Item;
        Inc(FCount);
      end;


    procedure TLinkedList.InsertBefore(Item,Loc : TLinkedListItem);
      begin
         Item.Previous:=Loc.Previous;
         Item.Next:=Loc;
         Loc.Previous:=Item;
         if Assigned(Item.Previous) then
           Item.Previous.Next:=Item
         else
           { if we've no next item, we've to adjust FFist }
           FFirst:=Item;
         Inc(FCount);
      end;


    procedure TLinkedList.InsertAfter(Item,Loc : TLinkedListItem);
      begin
         Item.Next:=Loc.Next;
         Loc.Next:=Item;
         Item.Previous:=Loc;
         if Assigned(Item.Next) then
           Item.Next.Previous:=Item
         else
           { if we've no next item, we've to adjust FLast }
           FLast:=Item;
         Inc(FCount);
      end;


    procedure TLinkedList.Concat(Item:TLinkedListItem);
      begin
        if FFirst=nil then
         begin
           FFirst:=Item;
           Item.Previous:=nil;
           Item.Next:=nil;
         end
        else
         begin
           FLast.Next:=Item;
           Item.Previous:=FLast;
           Item.Next:=nil;
         end;
        FLast:=Item;
        Inc(FCount);
      end;


    procedure TLinkedList.Remove(Item:TLinkedListItem);
      begin
         if Item=nil then
           Exit;
         if (FFirst=Item) and (FLast=Item) then
           begin
              FFirst:=nil;
              FLast:=nil;
           end
         else if FFirst=Item then
           begin
              FFirst:=Item.Next;
              if Assigned(FFirst) then
                FFirst.Previous:=nil;
           end
         else if FLast=Item then
           begin
              FLast:=FLast.Previous;
              if Assigned(FLast) then
                FLast.Next:=nil;
           end
         else
           begin
              Item.Previous.Next:=Item.Next;
              Item.Next.Previous:=Item.Previous;
           end;
         Item.Next:=nil;
         Item.Previous:=nil;
         Dec(FCount);
      end;


    procedure TLinkedList.Clear;
      var
        NewNode, Next : TLinkedListItem;
      begin
        NewNode:=FFirst;
        while Assigned(NewNode) do
         begin
           Next:=NewNode.Next;
           Prefetch(Pointer(Next)^);
           NewNode.Free;
           NewNode:=Next;
          end;
        FLast:=nil;
        FFirst:=nil;
        FCount:=0;
      end;


    function TLinkedList.GetFirst:TLinkedListItem;
      begin
         if FFirst=nil then
          GetFirst:=nil
         else
          begin
            GetFirst:=FFirst;
            if FFirst=FLast then
             FLast:=nil;
            FFirst:=FFirst.Next;
            Dec(FCount);
          end;
      end;


    function TLinkedList.GetLast:TLinkedListItem;
      begin
         if FLast=nil then
          GetLast:=nil
         else
          begin
            GetLast:=FLast;
            if FLast=FFirst then
             FFirst:=nil;
            FLast:=FLast.Previous;
            Dec(FCount);
          end;
      end;


    procedure TLinkedList.InsertList(P : TLinkedList);
      begin
         { empty List ? }
         if (P.FFirst=nil) then
           Exit;
         P.FLast.Next:=FFirst;
         { we have a double Linked List }
         if Assigned(FFirst) then
           FFirst.Previous:=P.FLast;
         FFirst:=P.FFirst;
         if (FLast=nil) then
           FLast:=P.FLast;
         Inc(FCount,P.FCount);
         { p becomes empty }
         P.FFirst:=nil;
         P.FLast:=nil;
         P.FCount:=0;
      end;


    procedure TLinkedList.InsertListBefore(Item:TLinkedListItem;P : TLinkedList);
      begin
         { empty List ? }
         if (P.FFirst=nil) then
           Exit;
         if (Item=nil) then
           begin
             { Insert at begin }
             InsertList(P);
             Exit;
           end
         else
           begin
             P.FLast.Next:=Item;
             P.FFirst.Previous:=Item.Previous;
             if Assigned(Item.Previous) then
               Item.Previous.Next:=P.FFirst
             else
               FFirst:=P.FFirst;
             Item.Previous:=P.FLast;
             Inc(FCount,P.FCount);
           end;
         { p becomes empty }
         P.FFirst:=nil;
         P.FLast:=nil;
         P.FCount:=0;
      end;


    procedure TLinkedList.InsertListAfter(Item:TLinkedListItem;P : TLinkedList);
      begin
         { empty List ? }
         if (P.FFirst=nil) then
           Exit;
         if (Item=nil) then
           begin
             { Insert at begin }
             InsertList(P);
             Exit;
           end
         else
           begin
             P.FFirst.Previous:=Item;
             P.FLast.Next:=Item.Next;
             if Assigned(Item.Next) then
               Item.Next.Previous:=P.FLast
             else
               FLast:=P.FLast;
             Item.Next:=P.FFirst;
             Inc(FCount,P.FCount);
           end;
         { p becomes empty }
         P.FFirst:=nil;
         P.FLast:=nil;
         P.FCount:=0;
      end;


    procedure TLinkedList.ConcatList(P : TLinkedList);
      begin
        if (P.FFirst=nil) then
         Exit;
        if FFirst=nil then
         FFirst:=P.FFirst
        else
         begin
           FLast.Next:=P.FFirst;
           P.FFirst.Previous:=FLast;
         end;
        FLast:=P.FLast;
        Inc(FCount,P.FCount);
        { make p empty }
        P.FLast:=nil;
        P.FFirst:=nil;
        P.FCount:=0;
      end;


    procedure TLinkedList.InsertListCopy(P : TLinkedList);
      var
        NewNode,NewNode2 : TLinkedListItem;
      begin
        NewNode:=P.Last;
        while Assigned(NewNode) do
         begin
           NewNode2:=NewNode.GetCopy;
           if Assigned(NewNode2) then
            Insert(NewNode2);
           NewNode:=NewNode.Previous;
         end;
      end;


    procedure TLinkedList.ConcatListCopy(P : TLinkedList);
      var
        NewNode,NewNode2 : TLinkedListItem;
      begin
        NewNode:=P.First;
        while Assigned(NewNode) do
         begin
           NewNode2:=NewNode.GetCopy;
           if Assigned(NewNode2) then
            Concat(NewNode2);
           NewNode:=NewNode.Next;
         end;
      end;


    procedure TLinkedList.RemoveAll;
      begin
        FFirst:=nil;
        FLast:=nil;
        FCount:=0;
      end;


{****************************************************************************
                             TCmdStrListItem
 ****************************************************************************}

    constructor TCmdStrListItem.Create(const S:TCmdStr);
      begin
        inherited Create;
        FPStr:=S;
      end;


    destructor TCmdStrListItem.Destroy;
      begin
        FPStr:='';
      end;


    function TCmdStrListItem.GetCopy:TLinkedListItem;
      begin
        Result:=(inherited GetCopy);
        { TLinkedListItem.GetCopy performs a "move" to copy all data -> reinit
          the ansistring, so the refcount is properly increased }
        Initialize(TCmdStrListItem(Result).FPStr);
        TCmdStrListItem(Result).FPStr:=FPStr;
      end;


{****************************************************************************
                           TCmdStrList
 ****************************************************************************}

    constructor TCmdStrList.Create;
      begin
         inherited Create;
         FDoubles:=True;
      end;


    constructor TCmdStrList.Create_No_Double;
      begin
         inherited Create;
         FDoubles:=False;
      end;


    procedure TCmdStrList.Insert(const S : TCmdStr);
      begin
         if (S='') or
            ((not FDoubles) and (FindCase(S)<>nil)) then
          Exit;
         inherited Insert(TCmdStrListItem.Create(S));
      end;


    procedure TCmdStrList.Concat(const S : TCmdStr);
      begin
         if (S='') or
            ((not FDoubles) and (FindCase(S)<>nil)) then
          Exit;
         inherited Concat(TCmdStrListItem.Create(S));
      end;


    procedure TCmdStrList.Remove(const S : TCmdStr);
      var
        P : TCmdStrListItem;
      begin
        if S='' then
         Exit;
        P:=FindCase(S);
        if Assigned(P) then
         begin
           inherited Remove(P);
           P.Free;
           P := nil;
         end;
      end;


    function TCmdStrList.GetFirst : TCmdStr;
      var
         P : TCmdStrListItem;
      begin
         P:=TCmdStrListItem(inherited GetFirst);
         if P=nil then
          GetFirst:=''
         else
          begin
            GetFirst:=P.FPStr;
            P.Free;
            P := nil;
          end;
      end;


    function TCmdStrList.GetLast : TCmdStr;
      var
         P : TCmdStrListItem;
      begin
         P:=TCmdStrListItem(inherited GetLast);
         if P=nil then
          GetLast:=''
         else
          begin
            GetLast:=P.FPStr;
            P.Free;
            P := nil;
          end;
      end;


    function TCmdStrList.FindCase(const S:TCmdStr):TCmdStrListItem;
      var
        NewNode : TCmdStrListItem;
      begin
        Result:=nil;
        if S='' then
         Exit;
        NewNode:=TCmdStrListItem(FFirst);
        while Assigned(NewNode) do
         begin
           if NewNode.FPStr=S then
            begin
              Result:=NewNode;
              Exit;
            end;
           NewNode:=TCmdStrListItem(NewNode.Next);
         end;
      end;


    function TCmdStrList.Find(const S:TCmdStr):TCmdStrListItem;
      var
        NewNode : TCmdStrListItem;
      begin
        Result:=nil;
        if S='' then
         Exit;
        NewNode:=TCmdStrListItem(FFirst);
        while Assigned(NewNode) do
         begin
           if SysUtils.CompareText(S, NewNode.FPStr)=0 then
            begin
              Result:=NewNode;
              Exit;
            end;
           NewNode:=TCmdStrListItem(NewNode.Next);
         end;
      end;


    procedure TCmdStrList.InsertItem(Item:TCmdStrListItem);
      begin
        inherited Insert(Item);
      end;


    procedure TCmdStrList.ConcatItem(Item:TCmdStrListItem);
      begin
        inherited Concat(Item);
      end;


{****************************************************************************
                                tdynamicarray
****************************************************************************}

    constructor TDynamicArray.Create(ABlockSize:LongWord);
      begin
        FPosn:=0;
        FPosnBlock:=nil;
        FFirstBlock:=nil;
        FLastBlock:=nil;
        FCurrBlockSize:=0;
        { Every block needs at least a header and alignment slack,
          therefore its size cannot be arbitrarily small. However,
          the blocksize argument is often confused with data size.
          See e.g. Mantis #20929. }
        if ABlockSize<MinDynamicBlockSize then
          ABlockSize:=MinDynamicBlockSize;
        FMaxBlockSize:=ABlockSize;
        Grow;
      end;


    destructor TDynamicArray.Destroy;
      var
        HP : PDynamicBlock;
      begin
        while Assigned(FFirstBlock) do
         begin
           HP:=FFirstBlock;
           FFirstBlock:=FFirstBlock^.Next;
           FreeMem(HP);
         end;
      end;


    function  TDynamicArray.Size:LongWord;
      begin
        if Assigned(FLastBlock) then
         Size:=FLastBlock^.Pos+FLastBlock^.Used
        else
         Size:=0;
      end;


    procedure TDynamicArray.Reset;
      var
        HP : PDynamicBlock;
      begin
        while Assigned(FFirstBlock) do
         begin
           HP:=FFirstBlock;
           FFirstBlock:=FFirstBlock^.Next;
           FreeMem(HP);
         end;
        FPosn:=0;
        FPosnBlock:=nil;
        FFirstBlock:=nil;
        FLastBlock:=nil;
        Grow;
      end;


    procedure TDynamicArray.Grow;
      var
        NBlock  : PDynamicBlock;
        OptBlockSize,
        IncSize : Integer;
      begin
        if CurrBlockSize<FMaxBlockSize then
          begin
            IncSize := MinDynamicBlockSize;
            if FCurrBlockSize > 255 then
              Inc(IncSize, FCurrBlockSize shr 2);
            Inc(FCurrBlockSize,IncSize);
          end;
        if CurrBlockSize>FMaxBlockSize then
          FCurrBlockSize:=FMaxBlockSize;
        { Calculate the most optimal size so there is no alignment overhead
          lost in the heap manager }
        OptBlockSize:=CUtils.Align(CurrBlockSize+DynamicBlockBaseSize,16)-DynamicBlockBaseSize-SizeOf(PtrInt);
        GetMem(NBlock,OptBlockSize+DynamicBlockBaseSize);
        if not Assigned(FFirstBlock) then
         begin
           FFirstBlock:=NBlock;
           FPosnBlock:=NBlock;
           NBlock^.Pos:=0;
         end
        else
         begin
           FLastBlock^.Next:=NBlock;
           NBlock^.Pos:=FLastBlock^.Pos+FLastBlock^.Size;
         end;
        NBlock^.Used:=0;
        NBlock^.Size:=OptBlockSize;
        NBlock^.Next:=nil;
        FillChar(NBlock^.Data,NBlock^.Size,0);
        FLastBlock:=NBlock;
      end;


    procedure TDynamicArray.Align(I:LongWord);
      var
        J : LongWord;
      begin
        J:=(FPosn mod I);
        if J<>0 then
         begin
           J:=I-J;
           if FPosnBlock^.Used+J>FPosnBlock^.Size then
            begin
              Dec(J,FPosnBlock^.Size-FPosnBlock^.Used);
              FPosnBlock^.Used:=FPosnBlock^.Size;
              Grow;
              FPosnBlock:=FLastBlock;
            end;
           Inc(FPosnBlock^.Used,J);
           Inc(FPosn,J);
         end;
      end;


    procedure TDynamicArray.Seek(I:LongWord);
      begin
        if (I<FPosnBlock^.Pos) or (I>=FPosnBlock^.Pos+FPosnBlock^.Size) then
         begin
           { set FPosnblock correct if the size is bigger then
             the current block }
           if FPosnBlock^.Pos>I then
            FPosnBlock:=FFirstBlock;
           while Assigned(FPosnBlock) do
            begin
              if FPosnBlock^.Pos+FPosnBlock^.Size>I then
               Break;
              FPosnBlock:=FPosnBlock^.Next;
            end;
           { not found ? then increase blocks }
           if not Assigned(FPosnBlock) then
            begin
              repeat
                { the current FLastblock is now also fully used }
                FLastBlock^.Used:=FLastBlock^.Size;
                Grow;
                FPosnBlock:=FLastBlock;
              until FPosnBlock^.Pos+FPosnBlock^.Size>=I;
            end;
         end;
        FPosn:=I;
        if FPosn-FPosnBlock^.Pos>FPosnBlock^.Used then
         FPosnBlock^.Used:=FPosn-FPosnBlock^.Pos;
      end;


    procedure TDynamicArray.Write(const D;Len:LongWord);
      var
        P : PChar;
        I,J : LongWord;
      begin
        P:=PChar(@D);
        while (Len>0) do
         begin
           I:=FPosn-FPosnBlock^.Pos;
           if I+Len>=FPosnBlock^.Size then
            begin
              J:=FPosnBlock^.Size-I;
              Move(P^,FPosnBlock^.Data[I],J);
              Inc(P,J);
              Inc(FPosn,J);
              Dec(Len,J);
              FPosnBlock^.Used:=FPosnBlock^.Size;
              if Assigned(FPosnBlock^.Next) then
               FPosnBlock:=FPosnBlock^.Next
              else
               begin
                 Grow;
                 FPosnBlock:=FLastBlock;
               end;
            end
           else
            begin
              Move(P^,FPosnBlock^.Data[I],Len);
              Inc(P,Len);
              Inc(FPosn,Len);
              I:=FPosn-FPosnBlock^.Pos;
              if I>FPosnBlock^.Used then
               FPosnBlock^.Used:=I;
              Len:=0;
            end;
         end;
      end;


    procedure TDynamicArray.WriteStr(const S:string);
      begin
        Write(S[1],Length(S));
      end;


    function TDynamicArray.Read(var D;Len:LongWord):LongWord;
      var
        P : PChar;
        I,J,Res : LongWord;
      begin
        Res:=0;
        P:=PChar(@D);
        while (Len>0) do
         begin
           I:=FPosn-FPosnBlock^.Pos;
           if I+Len>=FPosnBlock^.Used then
            begin
              J:=FPosnBlock^.Used-I;
              Move(FPosnBlock^.Data[I],P^,J);
              Inc(P,J);
              Inc(FPosn,J);
              Inc(Res,J);
              Dec(Len,J);
              if Assigned(FPosnBlock^.Next) then
               FPosnBlock:=FPosnBlock^.Next
              else
               Break;
            end
           else
            begin
              Move(FPosnBlock^.Data[I],P^,Len);
              Inc(P,Len);
              Inc(FPosn,Len);
              Inc(Res,Len);
              Len:=0;
            end;
         end;
        Read:=Res;
      end;


    procedure TDynamicArray.ReadStream(F:TCStream;MaxLen:LongWord);
      var
        I,Left : LongWord;
      begin
        repeat
          Left:=FPosnBlock^.Size-FPosnBlock^.Used;
          if Left>MaxLen then
           Left:=MaxLen;
          I:=F.Read(FPosnBlock^.Data[FPosnBlock^.Used],Left);
          Dec(MaxLen,I);
          Inc(FPosnBlock^.Used,I);
          if FPosnBlock^.Used=FPosnBlock^.Size then
           begin
             if Assigned(FPosnBlock^.Next) then
              FPosnBlock:=FPosnBlock^.Next
             else
              begin
                Grow;
                FPosnBlock:=FLastBlock;
              end;
           end;
        until (I<Left) or (MaxLen=0);
      end;


    procedure TDynamicArray.WriteStream(F:TCStream);
      var
        HP : PDynamicBlock;
      begin
        HP:=FFirstBlock;
        while Assigned(HP) do
         begin
           F.Write(HP^.Data,HP^.Used);
           HP:=HP^.Next;
         end;
      end;


    function TDynamicArray.Equal(Other:TDynamicArray):Boolean;
      var
        OfsThis,
        OfsOther,
        RemThis,
        RemOther,
        Len : SizeInt;
        BlockThis,
        BlockOther : PDynamicBlock;
      begin
        if not Assigned(Other) then
          Exit(False);
        if Size<>Other.Size then
          Exit(False);
        BlockThis:=FirstBlock;
        BlockOther:=Other.FirstBlock;
        OfsThis:=0;
        OfsOther:=0;

        while Assigned(BlockThis) and Assigned(BlockOther) do
          begin
            RemThis:=BlockThis^.Used-OfsThis;
            RemOther:=BlockOther^.Used-OfsOther;
            Len:=Min(RemThis,RemOther);
            if not CompareMem(@BlockThis^.Data[OfsThis],@BlockOther^.Data[OfsOther],Len) then
              Exit(False);
            Inc(OfsThis,Len);
            Inc(OfsOther,Len);
            if OfsThis=BlockThis^.Used then
              begin
                BlockThis:=BlockThis^.Next;
                OfsThis:=0;
              end;
            if OfsOther=BlockOther^.Used then
              begin
                BlockOther:=BlockOther^.Next;
                OfsOther:=0;
              end;
          end;

        if Assigned(BlockThis) and not Assigned(BlockOther) then
          Result:=BlockThis^.Used=0
        else if Assigned(BlockOther) and not Assigned(BlockThis) then
          Result:=BlockOther^.Used=0
        else
          Result:=True;
      end;


{****************************************************************************
                                thashset
****************************************************************************}

    constructor THashSet.Create(InitSize: Integer; OwnKeys, OwnObjects: Boolean);
      var
        I: Integer;
      begin
        inherited Create;
        FOwnsObjects := OwnObjects;
        FOwnsKeys := OwnKeys;
        I := 64;
        while I < InitSize do I := I shl 1;
        FBucketCount := I;
        FBucket := AllocMem(I * SizeOf(PHashSetItem));
      end;


    destructor THashSet.Destroy;
      begin
        Clear;
        FreeMem(FBucket);
        inherited Destroy;
      end;


    procedure THashSet.Clear;
      var
        I: Integer;
        Item, Next: PHashSetItem;
      begin
        for I := 0 to FBucketCount-1 do
        begin
          Item := FBucket[I];
          while Assigned(Item) do
          begin
            Next := Item^.Next;
            if FOwnsObjects then
              FreeAndNil(Item^.Data);
            FreeItem(Item);
            Item := Next;
          end;
        end;
        FillChar(FBucket^, FBucketCount * SizeOf(PHashSetItem), 0);
      end;


    function THashSet.Find(Key: Pointer; KeyLen: Integer): PHashSetItem;
      var
        Dummy: Boolean;
      begin
        Result := Lookup(Key, KeyLen, Dummy, False);
      end;


    function THashSet.FindOrAdd(Key: Pointer; KeyLen: Integer;
        var Found: Boolean): PHashSetItem;
      begin
        Result := Lookup(Key, KeyLen, Found, True);
      end;


    function THashSet.FindOrAdd(Key: Pointer; KeyLen: Integer): PHashSetItem;
      var
        Dummy: Boolean;
      begin
        Result := Lookup(Key, KeyLen, Dummy, True);
      end;


    function THashSet.Get(Key: Pointer; KeyLen: Integer): TObject;
      var
        E: PHashSetItem;
        Dummy: Boolean;
      begin
        E := Lookup(Key, KeyLen, Dummy, False);
        if Assigned(E) then
          Result := E^.Data
        else
          Result := nil;
      end;


    function THashSet.Lookup(Key: Pointer; KeyLen: Integer;
      var Found: Boolean; CanCreate: Boolean): PHashSetItem;
      var
        EntryPtr: PPHashSetItem;
        Entry: PHashSetItem;
        H: LongWord;
      begin
        H := FPHash(Key, KeyLen);
        EntryPtr := @FBucket[H and (FBucketCount-1)];
        Entry := EntryPtr^;
        while Assigned(Entry) and
          not ((Entry^.HashValue = H) and (Entry^.KeyLength = KeyLen) and
            (CompareByte(Entry^.Key^, Key^, KeyLen) = 0)) do
              begin
                EntryPtr := @Entry^.Next;
                Entry := EntryPtr^;
              end;
        Found := Assigned(Entry);
        if Found or (not CanCreate) then
          begin
            Result := Entry;
            Exit;
          end;
        if FCount > FBucketCount then  { arbitrary limit, probably too high }
          begin
            { rehash and repeat search }
            Resize(FBucketCount * 2);
            Result := Lookup(Key, KeyLen, Found, CanCreate);
          end
        else
          begin
            Result := CreateItem(Key, KeyLen, H);
            Inc(FCount);
            EntryPtr^ := Result;
          end;
        end;


    procedure THashSet.Resize(NewCapacity: LongWord);
      var
        P, Chain: PPHashSetItem;
        I: Integer;
        E, N: PHashSetItem;
      begin
        P := AllocMem(NewCapacity * SizeOf(PHashSetItem));
        for I := 0 to FBucketCount-1 do
          begin
            E := FBucket[I];
            while Assigned(E) do
            begin
              Chain := @P[E^.HashValue and (NewCapacity-1)];
              N := E^.Next;
              E^.Next := Chain^;
              Chain^ := E;
              E := N;
            end;
          end;
        FBucketCount := NewCapacity;
        FreeMem(FBucket);
        FBucket := P;
      end;

    class procedure THashSet.FreeItem(Item: PHashSetItem);
      begin
        Dispose(Item);
      end;

    class function THashSet.SizeOfItem: Integer;
      begin
        Result := SizeOf(THashSetItem);
      end;

    function THashSet.CreateItem(Key: Pointer; KeyLen: Integer; HashValue: LongWord): PHashSetItem;
      var
        ItemSize, KeyOfs: SizeUInt;
      begin
        ItemSize := SizeOfItem;
        if FOwnsKeys then
          begin
            KeyOfs := ItemSize;
            Result := GetMem(KeyOfs + SizeUInt(KeyLen));
            Result^.Key := Pointer(Result) + KeyOfs;
            Move(Key^, Result^.Key^, KeyLen);
          end
        else
          begin
            Result := GetMem(ItemSize);
            Result^.Key := Key;
          end;
        Result^.Next := nil;
        Result^.KeyLength := KeyLen;
        Result^.HashValue := HashValue;
        Result^.Data := nil;
      end;

    function THashSet.Remove(Entry: PHashSetItem): Boolean;
      var
        Chain: PPHashSetItem;
      begin
        Chain := @FBucket[Entry^.HashValue mod FBucketCount];
        while Assigned(Chain^) do
          begin
            if Chain^ = Entry then
              begin
                Chain^ := Entry^.Next;
                if FOwnsObjects then
                  FreeAndNil(Entry^.Data);
                FreeItem(Entry);
                Dec(FCount);
                Result := True;
                Exit;
              end;
            Chain := @Chain^^.Next;
          end;
        Result := False;
      end;


{****************************************************************************
                                ttaghashset
****************************************************************************}

    function TTagHashSet.Lookup(Key: Pointer; KeyLen: Integer;
      Tag: LongWord; var Found: Boolean; CanCreate: Boolean): PTagHashSetItem;
      var
        EntryPtr: PPTagHashSetItem;
        Entry: PTagHashSetItem;
        H: LongWord;
      begin
        H := FPHash(Key, KeyLen, Tag);
        EntryPtr := @PPTagHashSetItem(FBucket)[H and (FBucketCount-1)];
        Entry := EntryPtr^;
        while Assigned(Entry) and
          not ((Entry^.Item.HashValue = H) and (Entry^.Item.KeyLength = KeyLen) and
            (Entry^.Tag = Tag) and (CompareByte(Entry^.Item.Key^, Key^, KeyLen) = 0)) do
              begin
                EntryPtr := @Entry^.Item.Next;
                Entry := EntryPtr^;
              end;
        Found := Assigned(Entry);
        if Found or (not CanCreate) then
          begin
            Result := Entry;
            Exit;
          end;
        if FCount > FBucketCount then  { arbitrary limit, probably too high }
          begin
            { rehash and repeat search }
            Resize(FBucketCount * 2);
            Result := Lookup(Key, KeyLen, Tag, Found, CanCreate);
          end
        else
          begin
            Result := PTagHashSetItem(CreateItem(Key, KeyLen, H));
            Result^.Tag := Tag;
            Inc(FCount);
            EntryPtr^ := Result;
          end;
      end;

    class function TTagHashSet.SizeOfItem: Integer;
      begin
        Result := SizeOf(TTagHashSetItem);
      end;

    function TTagHashSet.Find(Key: Pointer; KeyLen: Integer; Tag: LongWord): PTagHashSetItem;
      var
        Dummy: Boolean;
      begin
        Result := Lookup(Key, KeyLen, Tag, Dummy, False);
      end;

    function TTagHashSet.FindOrAdd(Key: Pointer; KeyLen: Integer; Tag: LongWord;
      var Found: Boolean): PTagHashSetItem;
      begin
        Result := Lookup(Key, KeyLen, Tag, Found, True);
      end;

    function TTagHashSet.FindOrAdd(Key: Pointer; KeyLen: Integer; Tag: LongWord): PTagHashSetItem;
      var
        Dummy: Boolean;
      begin
        Result := Lookup(Key, KeyLen, Tag, Dummy, True);
      end;

    function TTagHashSet.Get(Key: Pointer; KeyLen: Integer; Tag: LongWord): TObject;
      var
        E: PTagHashSetItem;
        Dummy: Boolean;
      begin
        E := Lookup(Key, KeyLen, Tag, Dummy, False);
        if Assigned(E) then
          Result := E^.Item.Data
        else
          Result := nil;
      end;

{****************************************************************************
                                tbitset
****************************************************************************}

    function TBitSet.GetDataSize: LongInt;
      begin
        Result:=Length(FData);
      end;

    constructor TBitSet.Create(InitSize: LongInt);
      begin
        Create_ByteSize((InitSize+7) div 8);
      end;


    constructor TBitSet.Create_ByteSize(ByteSize: LongInt);
      begin
        SetLength(FData,ByteSize);
        Clear;
      end;


    destructor TBitSet.Destroy;
      begin
        FData:=Nil;
        inherited Destroy;
      end;


    procedure TBitSet.Clear;
      begin
        if Assigned(FData) then
          FillChar(FData[0],Length(FData),0);
      end;


    procedure TBitSet.Grow(NSize: LongInt);
      begin
        SetLength(FData,NSize);
      end;


    procedure TBitSet.Include(Index: LongInt);
      var
        DataIndex: LongInt;
      begin
        { don't use bitpacked array, not endian-safe }
        DataIndex:=Index shr 3;
        if (DataIndex>=DataSize) then
          Grow(DataIndex+16);
        FData[DataIndex]:=FData[DataIndex] or (1 shl (Index and 7));
      end;


    procedure TBitSet.Exclude(Index: LongInt);
      var
        DataIndex: LongInt;
      begin
        DataIndex:=Index shr 3;
        if (DataIndex>=DataSize) then
          Exit;
        FData[DataIndex]:=FData[DataIndex] and not(1 shl (Index and 7));
      end;


    function TBitSet.IsSet(Index: LongInt): Boolean;
      var
        DataIndex: LongInt;
      begin
        DataIndex:=Index shr 3;
        Result:=
          (DataIndex<DataSize) and
          (((FData[DataIndex] shr (Index and 7)) and 1)<>0);
      end;


    procedure TBitSet.AddSet(ASet: TBitSet);
      var
        I: LongInt;
      begin
        if (ASet.DataSize>DataSize) then
          Grow(ASet.DataSize);
        for I:=0 to ASet.DataSize-1 do
          FData[I]:=FData[I] or ASet.Data[I];
      end;


    procedure TBitSet.Subset(ASet: TBitSet);
      var
        I: LongInt;
      begin
        for I:=0 to Min(DataSize,ASet.DataSize)-1 do
          FData[I]:=FData[I] and not(ASet.Data[I]);
      end;


end.
