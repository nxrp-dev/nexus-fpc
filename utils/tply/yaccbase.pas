{
  This module collects the basic data types and operations used in the TP
  Yacc program, and other basic stuff that does not belong anywhere else:
  - Yacc input and output files and corresponding bookkeeping information
    used by the parser
  - symbolic character constants
  - dynamically allocated strings
  - integer sets
  - generic quicksort and hash table routines
  - utilities for list-generating
  - other tiny utilities


  Copyright (c) 1990-92  Albert Graef <ag@muwiinfa.geschichte.uni-mainz.de>
  Copyright (C) 1996     Berend de Boer <berend@pobox.com>

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


$Revision: 1.2 $
$Modtime: 96-07-31 15:18 $

$History: YACCBASE.PAS $
 *
 * *****************  Version 2  *****************
 * User: Berend       Date: 96-10-10   Time: 21:16
 * Updated in $/Lex and Yacc/tply
 * Updated for protected mode, windows and Delphi 1.X and 2.X.

}


unit YaccBase;



interface

const

(* symbolic character constants: *)

BS   = #8;      (* backspace character *)
Tab  = #9;      (* tab character *)
NL   = #10;     (* newline character *)
CR   = #13;     (* carriage return *)
FF   = #12;     (* form feed character *)

var

(* Filenames: *)

YFileName     : String;
PasFileName   : String;
LstFileName   : String;
CodFileName   : String;
CodFilePath1,
CodFilePath2  : String; { Under Linux,
                          binary and conf file are never in 1 directory.}

(* Yacc input, output, list and code template file: *)

YYIn, YYOut, YYLst, YYCod : Text;

(* the following values are initialized and updated by the parser: *)

Line      : String;  (* current input line *)
LNo, CNo  : Integer; (* current input position (line/column) *)
TokLeng   : Integer; (* length of current token *)

const

MaxElems  = 150; (* maximum size of integer sets *)

type

(* String pointers: *)

PStr    = ^String;

(* Sorted integer sets: *)

TIntSet    = array [0..MaxElems] of Integer;
              (* word 0 is size *)
PIntSet = ^TIntSet;

(* Operations: *)

(* Strings pointers: *)

function NewStr(Str : String) : PStr;
  (* creates a string pointer (only the space actually needed for the given
     string is allocated) *)

(* Integer sets (set arguments are passed by reference even if they are not
   modified, for greater efficiency): *)

procedure Empty(var M : TIntSet);
  (* initializes M as empty *)
procedure Singleton(var M : TIntSet; I : Integer);
  (* initializes M as a singleton set containing the element i *)
procedure Include(var M : TIntSet; I : Integer);
  (* include i in M *)
procedure Exclude(var M : TIntSet; I : Integer);
  (* exclude i from M *)
procedure SetUnion(var M, N : TIntSet);
  (* adds N to M *)
procedure SetMinus(var M, N : TIntSet);
  (* removes N from M *)
procedure Intersect(var M, N : TIntSet);
  (* removes from M all elements NOT in N *)
function Size(var M : TIntSet) : Integer;
  (* cardinality of set M *)
function Member(I : Integer; var M : TIntSet) : Boolean;
  (* tests for membership of i in M *)
function Isempty(var M : TIntSet) : Boolean;
  (* checks whether M is an empty set *)
function Equal(var M, N : TIntSet) : Boolean;
  (* checks whether M and N are equal *)
function SubsetEq(var M, N : TIntSet) : Boolean;
  (* checks whether M is a subset of N *)
function NewEmptyIntSet : PIntSet;
  (* creates a pointer to an empty integer set *)
function NewIntSet ( var M : TIntSet ) : PIntSet;
  (* creates a dynamic copy of M (only the space actually needed
     is allocated) *)

(* Quicksort: *)

type

TOrderPredicate = function (I, J : Integer) : Boolean;
TSwapProc = procedure (I, J : Integer);

procedure QuickSort(Lo, Hi: Integer;
                    Less : TOrderPredicate;
                    Swap : TSwapProc);
  (* General inplace sorting procedure based on the quicksort algorithm.
     This procedure can be applied to any sequential data structure;
     only the corresponding routines less which compares, and swap which
     swaps two elements i,j of the target data structure, must be
     supplied as appropriate for the target data structure.
     - lo, hi: the lower and higher indices, indicating the elements to
       be sorted
     - less(i, j): should return true if element no. i `is less than'
       element no. j, and false otherwise; any total quasi-ordering may
       be supplied here (if neither less(i, j) nor less(j, i) then elements
       i and j are assumed to be `equal').
     - swap(i, j): should swap the elements with index i and j *)

(* Generic hash table routines (based on quadratic rehashing; hence the
   table size must be a prime number): *)

type

TTableLookupProc = function(K : Integer) : String;
TTableEntryProc  = procedure(K : Integer; Symbol : String);

function Key(Symbol : String;
             TableSize : Integer;
             Lookup : TTableLookupProc;
             Entry  : TTableEntryProc) : Integer;
  (* returns a hash table key for symbol; inserts the symbol into the
     table if necessary
     - table_size is the symbol table size and must be a fixed prime number
     - lookup is the table lookup procedure which should return the string
       at key k in the table ('' if entry is empty)
     - entry is the table entry procedure which is assumed to store the
       given symbol at the given location *)

function DefinedKey(Symbol : String;
                    TableSize : Integer;
                    Lookup : TTableLookupProc) : Boolean;
  (* checks the table to see if symbol is in the table *)

(* Utility routines: *)

function Min(I, J : Integer) : Integer;
function Max(I, J : Integer) : Integer;
  (* minimum and maximum of two integers *)
function Upper(Str : String) : String;
  (* returns str converted to uppercase *)
function Strip(Str : String) : String;
  (* returns str with leading and trailing blanks stripped off *)
function BlankStr(Str : String) : String;
  (* returns string of same length as str, with all non-whitespace characters
     replaced by blanks *)
function IntStr(I : Integer) : String;
  (* returns the string representation of i *)
function IsInt(Str : String; var I : Integer) : Boolean;
  (* checks whether str represents an integer; if so, returns the
     value of it in i *)
function Path(FileName : String) : String;
  (* returns the path in filename *)
function Root(FileName : String) : String;
  (* returns root (i.e. extension stripped from filename) of
     filename *)
function AddExt(FileName, Ext : String) : String;
  (* if filename has no extension and last filename character is not '.',
     add extension ext to filename *)
function GetFileSize(FileName : String) : LongInt;
  (* determines file size in bytes *)

(* Utility functions for list generating routines: *)

type TCharSet = set of Char;

function CharStr(C : Char; Reserved : TCharSet) : String;
  (* returns a print name for character c, using the standard escape
     conventions; reserved is the class of `reserved' special characters
     which should be quoted with \ (\ itself is always quoted) *)
function SingleQuoteStr(Str : String) : String;
  (* returns print name of str enclosed in single quotes, using the
     standard escape conventions *)
function DoubleQuoteStr(Str : String) : String;
  (* returns print name of str enclosed in double quotes, using the
     standard escape conventions *)

implementation

uses YaccMsgs;

(* String pointers: *)

function NewStr(Str : String) : PStr;
  var StrP : PStr;
  begin
    New(StrP);
    StrP^ := Str;
    NewStr := StrP;
  end(*newStr*);

(* Integer sets: *)

procedure Empty(var M : TIntSet);
  begin
    M[0] := 0;
  end(*empty*);

procedure Singleton(var M : TIntSet; I : Integer);
  begin
    M[0] := 1; M[1] := I;
  end(*singleton*);

procedure Include(var M : TIntSet; I : Integer);
  var L, R, K : Integer;
  begin
    (* binary search: *)
    L := 1; R := M[0];
    K := L + (R-L) div 2;
    while (L<R) and (M[K]<>I) do
      begin
        if M[K]<I then
          L := Succ(K)
        else
          R := Pred(K);
        K := L + (R-L) div 2;
      end;
    if (K>M[0]) or (M[K]<>I) then
      begin
        if M[0]>=MaxElems then Fatal(IntsetOverflow);
        if (K<=M[0]) and (M[K]<I) then
          begin
            Move(M[K+1], M[K+2], (M[0]-K)*SizeOf(Integer));
            M[K+1] := I;
          end
        else
          begin
            Move(M[K], M[K+1], (M[0]-K+1)*SizeOf(Integer));
            M[K] := I;
          end;
        Inc(M[0]);
      end;
  end(*include*);

procedure Exclude(var M : TIntSet; I : Integer);
  var L, R, K : Integer;
  begin
    (* binary search: *)
    L := 1; R := M[0];
    K := L + (R-L) div 2;
    while (L<R) and (M[K]<>I) do
      begin
        if M[K]<I then
          L := Succ(K)
        else
          R := Pred(K);
        K := L + (R-L) div 2;
      end;
    if (K<=M[0]) and (M[K]=I) then
      begin
        Move(M[K+1], M[K], (M[0]-K)*SizeOf(Integer));
        Dec(M[0]);
      end;
  end(*exclude*);

procedure SetUnion(var M, N : TIntSet);
  var
    K : TIntSet;
    I, J, IndexM, IndexN : Integer;
  begin
    (* merge sort: *)
    I := 0; IndexM := 1; IndexN := 1;
    while (IndexM<=M[0]) and (IndexN<=N[0]) do
      begin
        Inc(I);
        if I>MaxElems then Fatal(IntsetOverflow);
        if M[IndexM]<N[IndexN] then
          begin
            K[I] := M[IndexM]; Inc(IndexM);
          end
        else if N[IndexN]<M[IndexM] then
          begin
            K[I] := N[IndexN]; Inc(IndexN);
          end
        else
          begin
            K[I] := M[IndexM]; Inc(IndexM); Inc(IndexN);
          end
      end;
    for J := IndexM to M[0] do
      begin
        Inc(I);
        if I>MaxElems then Fatal(IntsetOverflow);
        K[I] := M[J];
      end;
    for J := IndexN to N[0] do
      begin
        Inc(I);
        if I>MaxElems then Fatal(IntsetOverflow);
        K[I] := N[J];
      end;
    K[0] := I;
    Move(K, M, Succ(I)*SizeOf(Integer));
  end(*setunion*);

procedure SetMinus(var M, N : TIntSet);
  var
    K : TIntSet;
    I, IndexM, IndexN : Integer;
  begin
    I := 0; IndexN := 1;
    for IndexM := 1 to M[0] do
      begin
        while (IndexN<=N[0]) and (N[IndexN]<M[IndexM]) do Inc(IndexN);
        if (IndexN>N[0]) or (N[IndexN]>M[IndexM]) then
          begin
            Inc(I);
            K[I] := M[IndexM];
          end
        else
          Inc(IndexN);
      end;
    K[0] := I;
    Move(K, M, Succ(I)*SizeOf(Integer));
  end(*setminus*);

procedure Intersect(var M, N : TIntSet);
  var
    K : TIntSet;
    I, IndexM, IndexN : Integer;
  begin
    I := 0; IndexN := 1;
    for IndexM := 1 to M[0] do
      begin
        while (IndexN<=N[0]) and (N[IndexN]<M[IndexM]) do Inc(IndexN);
        if (IndexN<=N[0]) and (N[IndexN]=M[IndexM]) then
          begin
            Inc(I);
            K[I] := M[IndexM];
            Inc(IndexN);
          end
      end;
    K[0] := I;
    Move(K, M, Succ(I)*SizeOf(Integer));
  end(*intersect*);

function Size(var M : TIntSet) : Integer;
  begin
    Size := M[0]
  end(*size*);

function Member(I : Integer; var M : TIntSet) : Boolean;
  var L, R, K : Integer;
  begin
    (* binary search: *)
    L := 1; R := M[0];
    K := L + (R-L) div 2;
    while (L<R) and (M[K]<>I) do
      begin
        if M[K]<I then
          L := Succ(K)
        else
          R := Pred(K);
        K := L + (R-L) div 2;
      end;
    Member := (K<=M[0]) and (M[K]=I);
  end(*member*);

function Isempty(var M : TIntSet) : Boolean;
  begin
    Isempty := M[0]=0
  end(*isempty*);

function Equal(var M, N : TIntSet) : Boolean;
  var I : Integer;
  begin
    if M[0]<>N[0] then
      Equal := False
    else
      begin
        for I := 1 to M[0] do
          if M[I]<>N[I] then
            begin
              Equal := False;
              Exit
            end;
        Equal := True
      end
  end(*equal*);

function SubsetEq(var M, N : TIntSet) : Boolean;
  var
    IndexM, IndexN : Integer;
  begin
    if M[0]>N[0] then
      SubsetEq := False
    else
      begin
        IndexN := 1;
        for IndexM := 1 to M[0] do
          begin
            while (IndexN<=N[0]) and (N[IndexN]<M[IndexM]) do Inc(IndexN);
            if (IndexN>N[0]) or (N[IndexN]>M[IndexM]) then
              begin
                SubsetEq := False;
                Exit
              end
            else
              Inc(IndexN);
          end;
        SubsetEq := True
      end;
  end(*subseteq*);

function NewIntSet ( var M : TIntSet ) : PIntSet;
  var
    MP : PIntSet;
  begin
    GetMem(MP, (Size(M)+1)*SizeOf(Integer));
    Move(M, MP^, (Size(M)+1)*SizeOf(Integer));
    NewIntSet := MP;
  end(*newIntSet*);

function NewEmptyIntSet : PIntSet;
  var
    MP : PIntSet;
  begin
    GetMem(MP, (MaxElems+1)*SizeOf(Integer));
    MP^[0] := 0;
    NewEmptyIntSet := MP
  end(*newEmptyIntSet*);

(* Quicksort: *)

procedure QuickSort(Lo, Hi: Integer;
                    Less : TOrderPredicate;
                    Swap : TSwapProc);
  (* derived from the quicksort routine in QSORT.PAS in the Turbo Pascal
     distribution *)
  procedure Sort(L, R: Integer);
    var I, J, K : Integer;
    begin
      I := L; J := R; K := (L+R) DIV 2;
      repeat
        while Less(I, K) do Inc(I);
        while Less(K, J) do Dec(J);
        if I<=J then
          begin
            Swap(I, J);
            if K=I then K := J (* pivot element swapped! *)
            else if K=J then K := I;
            Inc(I); Dec(J);
          end;
      until I>J;
      if L<J then Sort(L,J);
      if I<R then Sort(I,R);
    end(*sort*);
  begin
    if Lo<Hi then Sort(Lo,Hi);
  end(*quicksort*);

(* Generic hash table routines: *)

function Hash(Str : String; TableSize : Integer) : Integer;
  (* computes a hash key for str *)
  var I, Key : Integer;
  begin
    Key := 0;
    for I := 1 to Length(Str) do
      Inc(Key, Ord(Str[I]));
    Hash := Key mod TableSize + 1;
  end(*hash*);

procedure NewPos(var POS, Incr, Count : Integer; TableSize : Integer);
  (* computes a new position in the table (quadratic collision strategy)
     - pos: current position (+inc)
     - incr: current increment (+2)
     - count: current number of collisions (+1)
     quadratic collision formula for position of str after n collisions:
       pos(str, n) = (hash(str)+n^2) mod table_size +1
     note that n^2-(n-1)^2 = 2n-1 <=> n^2 = (n-1)^2 + (2n-1) for n>0,
     i.e. the increment inc=2n-1 increments by two in each collision *)
  begin
    Inc(Count);
    Inc(POS, Incr);
    if POS>TableSize then POS := POS mod TableSize + 1;
    Inc(Incr, 2)
  end(*newPos*);

function Key(Symbol : String;
             TableSize : Integer;
             Lookup : TTableLookupProc;
             Entry  : TTableEntryProc) : Integer;
  var POS, Incr, Count : Integer;
  begin
    POS := Hash(Symbol, TableSize);
    Incr := 1;
    Count := 0;
    while Count<=TableSize do
      if Lookup(POS)='' then
        begin
          Entry(POS, Symbol);
          Key := POS;
          Exit
        end
      else if Lookup(POS)=Symbol then
        begin
          Key := POS;
          Exit
        end
      else
        NewPos(POS, Incr, Count, TableSize);
    Fatal(SymTableOverflow)
  end(*key*);

function DefinedKey(Symbol : String;
                    TableSize : Integer;
                    Lookup : TTableLookupProc) : Boolean;
  var POS, Incr, Count : Integer;
  begin
    POS := Hash(Symbol, TableSize);
    Incr := 1;
    Count := 0;
    while Count<=TableSize do
      if Lookup(POS)='' then
        begin
          DefinedKey := False;
          Exit
        end
      else if Lookup(POS)=Symbol then
        begin
          DefinedKey := True;
          Exit
        end
      else
        NewPos(POS, Incr, Count, TableSize);
    DefinedKey := False
  end(*definedKey*);

(* Utility routines: *)

function Min(I, J : Integer) : Integer;
  begin
    if I<J then
      Min := I
    else
      Min := J
  end(*min*);
function Max(I, J : Integer) : Integer;
  begin
    if I>J then
      Max := I
    else
      Max := J
  end(*max*);
function Upper(Str : String) : String;
  var I : Integer;
  begin
    for I := 1 to Length(Str) do
      Str[I] := UpCase(Str[I]);
    Upper := Str
  end(*upper*);
function Strip(Str : String) : String;
  begin
    while (Length(Str)>0) and ((Str[1]=' ') or (Str[1]=Tab)) do
      Delete(Str, 1, 1);
    while (Length(Str)>0) and
          ((Str[Length(Str)]= ' ') or
           (Str[Length(Str)]=Tab)) do
      Delete(Str, Length(Str), 1);
    Strip := Str;
  end(*strip*);
function BlankStr(Str : String) : String;
  var I : Integer;
  begin
    for I := 1 to Length(Str) do
      if Str[I]<>Tab then Str[I] := ' ';
    BlankStr := Str;
  end(*blankStr*);
function IntStr(I : Integer) : String;
  var S : String;
  begin
    Str(I, S);
    IntStr := S
  end(*intStr*);
function IsInt(Str : String; var I : Integer) : Boolean;
  var Res : Integer;
  begin
    Val(Str, I, Res);
    IsInt := Res = 0;
  end(*isInt*);
function Path(FileName : String) : String;
  var I : Integer;
  begin
    I := Length(FileName);
    while (I>0) and (FileName[I]<>DirectorySeparator) and (FileName[I]<>':') do
      Dec(I);
    Path := Copy(FileName, 1, I);
  end(*path*);
function Root(FileName : String) : String;
  var
    I : Integer;
  begin
    Root := FileName;
    for I := Length(FileName) downto 1 do
      case FileName[I] of
        '.' :
          begin
            Root := Copy(FileName, 1, I-1);
            Exit
          end;
        DirectorySeparator: Exit;
        else
      end;
  end(*root*);
function AddExt(FileName, Ext : String) : String;
  (* implemented with goto for maximum efficiency *)
  label X;
  var
    I : Integer;
  begin
    AddExt := FileName;
    for I := Length(FileName) downto 1 do
      case FileName[I] of
        '.' : Exit;
        DirectorySeparator : goto X;
        else
      end;
    X : AddExt := FileName+'.'+Ext
  end(*addExt*);
function GetFileSize(FileName : String) : LongInt;
  var F : File;
  begin
    Assign(F, FileName);
    Reset(F, 1);
    if IOResult=0 then
      GetFileSize := FileSize(F)
    else
      GetFileSize := 0;
    Close(F);
  end(*file_size*);

(* Utility functions for list generating routines: *)

function CharStr(C : Char; Reserved : TCharSet) : String;
  function OctStr(C : Char) : String;
    (* return octal string representation of character c *)
    begin
      OctStr := IntStr(Ord(C) div 64)+IntStr((Ord(C) mod 64) div 8)+
                IntStr(Ord(C) mod 8);
    end(*octStr*);
  begin
    case C of
      BS         : CharStr := '\b';
      Tab        : CharStr := '\t';
      NL         : CharStr := '\n';
      CR         : CharStr := '\c';
      FF         : CharStr := '\f';
      '\'        : CharStr := '\\';
      #0..#7,      (* nonprintable characters *)
      #11,#14..#31,
      #127..#255 : CharStr := '\'+OctStr(C);
      else if C in Reserved then
        CharStr := '\'+C
      else
        CharStr := C
    end
  end(*charStr*);

function SingleQuoteStr(Str : String) : String;
  var
    I : Integer;
    Str1 : String;
  begin
    Str1 := '';
    for I := 1 to Length(Str) do
      Str1 := Str1+CharStr(Str[I], ['''']);
    SingleQuoteStr := ''''+Str1+''''
  end(*singleQuoteStr*);

function DoubleQuoteStr(Str : String) : String;
  var
    I : Integer;
    Str1 : String;
  begin
    Str1 := '';
    for I := 1 to Length(Str) do
      Str1 := Str1+CharStr(Str[I], ['"']);
    DoubleQuoteStr := '"'+Str1+'"'
  end(*doubleQuoteStr*);

end(*YaccBase*).
