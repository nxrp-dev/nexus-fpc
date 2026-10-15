{
  TP Lex - A lexical analyzer generator for Turbo Pascal


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


$Revision: 1.4 $
$Modtime: 96-08-01 10:22 $

$History: LEX.PAS $
 *
 * *****************  Version 2  *****************
 * User: Berend       Date: 96-10-10   Time: 21:16
 * Updated in $/Lex and Yacc/tply
 * Updated for protected mode, windows and Delphi 1.X and 2.X.


------------------------- Synopsis ------------------------

   Synopsis   lex [options] lex-file[.l] [output-file[.pas]]

   Options

   -v  "Verbose:" Lex generates a readable description of the generated
       lexical analyzer, written to lex-file with new extension .LST.

   -o  "Optimize:" Lex optimizes DFA tables to produce a minimal DFA

   Description

   This is a reimplementation of the popular UNIX lexical analyzer generator
   Lex for MS-DOS and Turbo Pascal.

   Differences from UNIX Lex:

   - Produces output code for Turbo Pascal, rather than for C.

   - Character tables (%T) are not supported; neither are any directives
     to determine internal table sizes (%p, %n, etc.).

------------------------- Synopsis ------------------------

}

{$I-}
program Lex;

uses
  LexBase, LexTable, LexPos, LexDFA, LexOpt, LexList, LexRules, LexMsgs, SysUtils;


procedure GetLine;
  (* obtain line from source file *)
  begin
    ReadLn(YYIn, Line);
    Inc(LNo);
  end(*get_line*);

procedure NextSection;
  (* find next section mark (%%) in code template *)
  var Line : String;
  begin
    while not EOF(YYCod) do
      begin
        ReadLn(YYCod, Line);
        if Line='%%' then Exit;
        WriteLn(YYOut, Line);
      end;
  end(*next_section*);

(* Semantic routines: *)

var NRules : Integer; (* current number of rules *)

procedure DefineStartState ( Symbol : String; POS : Integer; Excl : Boolean );
  (* process start state definition *)
  begin
{$ifdef fpc}
    with SymTable^[Key(Symbol, MaxKeys, @Lookup, @Entry)] do
{$else}
    with SymTable^[Key(Symbol, MaxKeys, Lookup, Entry)] do
{$endif}
      if SymType=NoneSym then
        begin
          Inc(NStartStates);
          if NStartStates>MaxStartStates then
            Fatal(StateTableOverflow);
          SymType    := StartStateSym;
          StartState := NStartStates;
          WriteLn(YYOut, 'const ', Symbol, ' = ', 2*StartState, ';');
          FirstPosTable^[2*StartState] := NewIntSet;
          FirstPosTable^[2*StartState+1] := NewIntSet;
          StartExcl^[StartState] := Excl;
        end
      else
        Error(SymbolAlreadyDefined, POS)
  end(*define_start_state*);

procedure DefineMacro ( Symbol, Replacement : String );
  (* process macro definition *)
  begin
{$ifdef fpc}
    with SymTable^[Key('{'+Symbol+'}', MaxKeys, @Lookup, @Entry)] do
{$else}
    with SymTable^[Key('{'+Symbol+'}', MaxKeys, Lookup, Entry)] do
{$endif}
      if SymType=NoneSym then
        begin
          SymType := MacroSym;
          Subst    := NewStr(Strip(Replacement));
        end
      else
        Error(SymbolAlreadyDefined, 1)
  end(*define_macro*);

procedure AddRule;
  (* process rule *)
  var I : Integer;
      First : TIntSet;
  begin
    AddExpr(R, First);
    if NSt=0 then
      if Cf then
        SetUnion(FirstPosTable^[1]^, First)
      else
        begin
          SetUnion(FirstPosTable^[0]^, First);
          SetUnion(FirstPosTable^[1]^, First);
        end
    else
      if Cf then
        for I := 1 to NSt do
          SetUnion(FirstPosTable^[2*St[I]+1]^, First)
      else
        for I := 1 to NSt do
          begin
            SetUnion(FirstPosTable^[2*St[I]]^, First);
            SetUnion(FirstPosTable^[2*St[I]+1]^, First);
          end
  end(*add_rule*);

procedure GenerateTable;

  (* write the DFA table to the output file

     Tables are represented as a collection of typed array constants:

     type YYTRec = record
                     cc : set of Char; { characters }
                     s  : Integer;     { next state }
                   end;

     const

     { table sizes: }

     yynmarks   = ...;
     yynmatches = ...;
     yyntrans   = ...;
     yynstates  = ...;

     { rules of mark positions for each state: }

     yyk : array [1..yynmarks] of Integer = ...;

     { rules of matches for each state: }

     yym : array [1..yynmatches] of Integer = ...;

     { transition table: }

     yyt : array [1..yyntrans] of YYTRec = ...;

     { offsets into the marks, matches and transition tables: }

     yykl, yykh,
     yyml, yymh,
     yytl, yyth : array [0..yynstates-1] of Integer = ...;

  *)

  var YYNMarks, YYNMatches, YYNTrans, YYNStates : Integer;
      YYKL, YYKH,
      YYML, YYMH,
      YYTL, YYTH : array [0..MaxStates-1] of Integer;

  procedure Counters;
    (* compute counters and offsets *)
    var S, I : Integer;
    begin
      YYNStates := NStates; YYNTrans   := NTrans;
      YYNMarks  := 0;        YYNMatches := 0;
      for S := 0 to NStates-1 do with StateTable^[S] do
        begin
          YYTL[S] := TransLo;   YYTH[S] := TransHi;
          YYKL[S] := YYNMarks+1; YYML[S] := YYNMatches+1;
          for I := 1 to Size(StatePos^) do
            with PosTable^[StatePos^[I]] do
              if PosType=MarkPos then
                if POS=0 then
                  Inc(YYNMatches)
                else if POS=1 then
                  Inc(YYNMarks);
          YYKH[S] := YYNMarks; YYMH[S] := YYNMatches;
        end;
    end(*counters*);

  procedure WriteCC(var F : Text; CC : TCClass);
    (* print the given character class *)
    function CharStr(C : Char) : String;
      begin
        case C of
          #0..#31,     (* nonprintable characters *)
          #127..#255 : CharStr := '#'+IntStr(Ord(C));
          ''''       : CharStr := '''''''''';
          else         CharStr := ''''+C+'''';
        end;
      end(*charStr*);
    const
      MaxChar = #255;
    var
      C1, C2 : Char;
      Col : Integer;
      Tag : String;
      Quit: Boolean;
    begin
      Write(F, '[ ');
      Col := 0;
      C1 := Chr(0);
      Quit := False;
      while not Quit do begin
        if C1 in CC then  begin
          if Col>0 then
            begin
              Write(F, ',');
              Inc(Col);
            end;
          if Col>40 then
            { insert line break }
            begin
              WriteLn(F);
              Write(F, ' ':12);
              Col := 0;
            end;
          C2 := C1;
          while (C2<MaxChar) and (Succ(C2) in CC) do
            C2 := Succ(C2);
          if C1=C2 then
            Tag := CharStr(C1)
          else if C2=Succ(C1) then
            Tag := CharStr(C1)+','+CharStr(C2)
          else
            Tag := CharStr(C1)+'..'+CharStr(C2);
          Write(F, Tag);
          Col := Col + Length(Tag);
          C1 := C2;
        end;
        Quit := C1 = MaxChar;
        if not Quit then
          C1 := Succ(C1);
      end; { of while }
      Write(F, ' ]');
    end(*writecc*);

  procedure Tables;
    (* print tables *)
    var S, I, Count : Integer;
    begin
      WriteLn(YYOut);
      WriteLn(YYOut, 'type TYYTRec = record');
      WriteLn(YYOut, '                CC : set of Char;');
      WriteLn(YYOut, '                S  : Integer;');
      WriteLn(YYOut, '              end;');
      WriteLn(YYOut);
      WriteLn(YYOut, 'const');
      (* table sizes: *)
      WriteLn(YYOut);
      WriteLn(YYOut, 'YYNMarks   = ', YYNMarks, ';');
      WriteLn(YYOut, 'YYNMatches = ', YYNMatches, ';');
      WriteLn(YYOut, 'YYNTrans   = ', YYNTrans, ';');
      WriteLn(YYOut, 'YYNStates  = ', YYNStates, ';');
      (* mark table: *)
      WriteLn(YYOut);
      WriteLn(YYOut, 'YYK : array [1..YYNMarks] of Integer = (');
      Count := 0;
      for S := 0 to NStates-1 do with StateTable^[S] do
        begin
          WriteLn(YYOut, '  { ', S, ': }');
          for I := 1 to Size(StatePos^) do
            with PosTable^[StatePos^[I]] do
              if (PosType=MarkPos) and (POS=1) then
                begin
                  Write(YYOut, '  ', Rule); Inc(Count);
                  if Count<YYNMarks then Write(YYOut, ',');
                  WriteLn(YYOut);
                end;
        end;
      WriteLn(YYOut, ');');
      (* match table: *)
      WriteLn(YYOut);
      WriteLn(YYOut, 'YYM : array [1..YYNMatches] of Integer = (');
      Count := 0;
      for S := 0 to NStates-1 do with StateTable^[S] do
        begin
          WriteLn(YYOut, '{ ', S, ': }');
          for I := 1 to Size(StatePos^) do
            with PosTable^[StatePos^[I]] do
              if (PosType=MarkPos) and (POS=0) then
                begin
                  Write(YYOut, '  ', Rule); Inc(Count);
                  if Count<YYNMatches then Write(YYOut, ',');
                  WriteLn(YYOut);
                end;
        end;
      WriteLn(YYOut, ');');
      (* transition table: *)
      WriteLn(YYOut);
      WriteLn(YYOut, 'YYT : array [1..YYNTrans] of TYYTRec = (');
      Count := 0;
      for S := 0 to NStates-1 do with StateTable^[S] do
        begin
          WriteLn(YYOut, '{ ', S, ': }');
          for I := TransLo to TransHi do
            with TransTable^[I] do
              begin
                Write(YYOut, '  ( CC: ');
                WriteCC(YYOut, CC^);
                Write(YYOut, '; S: ');
                Write(YYOut, NextState, ')');
                Inc(Count);
                if Count<YYNTrans then Write(YYOut, ',');
                WriteLn(YYOut);
              end;
        end;
      WriteLn(YYOut, ');');
      (* offset tables: *)
      WriteLn(YYOut);
      WriteLn(YYOut, 'YYKL : array [0..YYNStates-1] of Integer = (');
      for S := 0 to NStates-1 do
        begin
          Write(YYOut, '{ ', S, ': } ', YYKL[S]);
          if S<NStates-1 then Write(YYOut, ',');
          WriteLn(YYOut);
        end;
      WriteLn(YYOut, ');');
      WriteLn(YYOut);
      WriteLn(YYOut, 'YYKH : array [0..YYNStates-1] of Integer = (');
      for S := 0 to NStates-1 do
        begin
          Write(YYOut, '{ ', S, ': } ', YYKH[S]);
          if S<NStates-1 then Write(YYOut, ',');
          WriteLn(YYOut);
        end;
      WriteLn(YYOut, ');');
      WriteLn(YYOut);
      WriteLn(YYOut, 'YYML : array [0..YYNStates-1] of Integer = (');
      for S := 0 to NStates-1 do
        begin
          Write(YYOut, '{ ', S, ': } ', YYML[S]);
          if S<NStates-1 then Write(YYOut, ',');
          WriteLn(YYOut);
        end;
      WriteLn(YYOut, ');');
      WriteLn(YYOut);
      WriteLn(YYOut, 'YYMH : array [0..YYNStates-1] of Integer = (');
      for S := 0 to NStates-1 do
        begin
          Write(YYOut, '{ ', S, ': } ', YYMH[S]);
          if S<NStates-1 then Write(YYOut, ',');
          WriteLn(YYOut);
        end;
      WriteLn(YYOut, ');');
      WriteLn(YYOut);
      WriteLn(YYOut, 'YYTL : array [0..YYNStates-1] of Integer = (');
      for S := 0 to NStates-1 do
        begin
          Write(YYOut, '{ ', S, ': } ', YYTL[S]);
          if S<NStates-1 then Write(YYOut, ',');
          WriteLn(YYOut);
        end;
      WriteLn(YYOut, ');');
      WriteLn(YYOut);
      WriteLn(YYOut, 'YYTH : array [0..YYNStates-1] of Integer = (');
      for S := 0 to NStates-1 do
        begin
          Write(YYOut, '{ ', S, ': } ', YYTH[S]);
          if S<NStates-1 then Write(YYOut, ',');
          WriteLn(YYOut);
        end;
      WriteLn(YYOut, ');');
      WriteLn(YYOut);
    end(*tables*);

  begin
    Counters; Tables;
  end(*generate_table*);

(* Parser: *)

const

MaxItems = 255;

var

ItemStr : String;
ItemC   : Integer;
ItemPos,
ItemLen : array [1..MaxItems] of Integer;

procedure Split ( Str : String; Count : Integer );
  (* split str into at most count whitespace-delimited items
     (result in itemstr, itemc, itempos, itemlen) *)
  procedure Scan(var ActPos : Integer);
    (* scan one item *)
    var L : Integer;
    begin
      while (ActPos<=Length(ItemStr)) and
            ((ItemStr[ActPos]=' ') or (ItemStr[ActPos]=Tab)) do
        Inc(ActPos);
      L := 0;
      while (ActPos+L<=Length(ItemStr)) and
            (ItemStr[ActPos+L]<>' ') and (ItemStr[ActPos+L]<>Tab) do
        Inc(L);
      Inc(ItemC);
      ItemPos[ItemC] := ActPos;
      ItemLen[ItemC] := L;
      Inc(ActPos, L+1);
      while (ActPos<=Length(ItemStr)) and
            ((ItemStr[ActPos]=' ') or (ItemStr[ActPos]=Tab)) do
        Inc(ActPos);
    end(*scan*);
  var ActPos : Integer;
  begin
    ItemStr := Str; ActPos := 1;
    ItemC := 0;
    while (ItemC<Count-1) and (ActPos<=Length(ItemStr)) do Scan(ActPos);
    if ActPos<=Length(ItemStr) then
      begin
        Inc(ItemC);
        ItemPos[ItemC] := ActPos;
        ItemLen[ItemC] := Length(ItemStr)-ActPos+1;
      end;
  end(*split*);

function ItemV ( I : Integer ) : String;
  (* return ith item in split string (whole string for i=0) *)
  begin
    if I=0 then
      ItemV := ItemStr
    else if (I<0) or (I>ItemC) then
      ItemV := ''
    else
      ItemV := Copy(ItemStr, ItemPos[I], ItemLen[I])
  end(*itemv*);

procedure Code;
  begin
    while not EOF(YYIn) do
      begin
        GetLine;
        if Line='%}' then
          Exit
        else
          WriteLn(YYOut, Line);
      end;
    Error(UnmatchedLBrace, Length(Line)+1);
  end(*code*);

procedure Definitions;
  procedure Definition;
    function CheckId ( Symbol : String ) : Boolean;
      var I : Integer;
      begin
        if (Symbol='') or not (Symbol[1] in Letters) then
          CheckId := False
        else
          begin
            for I := 2 to Length(Symbol) do
              if not (Symbol[I] in Alphanums) then
                begin
                  CheckId := False;
                  Exit;
                end;
            CheckId := True
          end
      end(*check_id*);
    var I : Integer;
        Com : String;
    begin
      Split(Line, 2);
      Com := Upper(ItemV(1));
      if (Com='%S') or (Com='%START') or (Com='%X') then
        begin
          Split(Line, MaxItems);
          for I := 2 to ItemC do
            if CheckId(ItemV(I)) then
              DefineStartState(ItemV(I), ItemPos[I], Com='%X')
            else
              Error(SyntaxError, ItemPos[I]);
        end
      else if CheckId(ItemV(1)) then
        DefineMacro(ItemV(1), ItemV(2))
      else
        Error(SyntaxError, 1);
    end(*definition*);
  begin
    while not EOF(YYIn) do
      begin
        GetLine;
        if Line='' then
          WriteLn(YYOut)
        else if Line='%%' then
          Exit
        else if Line='%{' then
          Code
        else if (Line[1]='%') or (Line[1] in Letters) then
          Definition
        else
          WriteLn(YYOut, Line)
      end;
  end(*definitions*);

procedure Rules;
  begin
    NextSection;
    if Line='%%' then
      while not EOF(YYIn) do
        begin
          GetLine;
          if Line='' then
            WriteLn(YYOut)
          else if Line='%%' then
            begin
              NextSection;
              Exit;
            end
          else if Line='%{' then
            Code
          else if (Line[1]<>' ') and (Line[1]<>Tab) then
            begin
              if NRules=0 then NextSection;
              Inc(NRules);
              ParseRule(NRules);
              if Errors=0 then
                begin
                  AddRule;
                  Write(YYOut, '  ', NRules);
                  if Strip(Stmt)='|' then
                    WriteLn(YYOut, ',')
                  else
                    begin
                      WriteLn(YYOut, ':');
                      WriteLn(YYOut, BlankStr(Expr), Stmt);
                    end;
                end
            end
          else
            WriteLn(YYOut, Line)
        end
    else
      Error(UnexpectedEOF, Length(Line)+1);
    NextSection;
  end(*rules*);

procedure AuxiliaryProcs;
  begin
    if Line='%%' then
      begin
        WriteLn(YYOut);
        while not EOF(YYIn) do
          begin
            GetLine;
            WriteLn(YYOut, Line);
          end;
      end;
  end(*auxiliary_procs*);

(* Main program: *)

var I : Integer;

begin
{$ifdef Unix}
  CodFilePath1:=Path(ParamStr(0));
  if (CodFilePath1<>'') then
    CodFilePath1:=CodFilePath1+'../lib/fpc/lexyacc/'
  else
    CodFilePath1:='/usr/local/lib/fpc/lexyacc/';
  CodFilePath2:='/usr/lib/fpc/lexyacc/';
{$else}
  CodFilePath1:=Path(ParamStr(0));
  CodFilePath2:='';
{$endif}


  (* sign-on: *)

  WriteLn(SignOn);

  (* parse command line: *)

  if ParamCount=0 then
    begin
      WriteLn(Usage);
      WriteLn(Options);
      Halt(0);
    end;

  LFileName := '';
  PasFileName := '';

  for I := 1 to ParamCount do
    if Copy(ParamStr(I), 1, 1)='-' then
      if Upper(ParamStr(I))='-V' then
        Verbose := True
      else if Upper(ParamStr(I))='-O' then
        Optimize := True
      else
        begin
          WriteLn(InvalidOption, ParamStr(I));
          Halt(1);
        end
    else if LFileName='' then
      LFileName := AddExt(ParamStr(I), 'l')
    else if PasFileName='' then
      PasFileName := AddExt(ParamStr(I), 'pas')
    else
      begin
        WriteLn(IllegalNoArgs);
        Halt(1);
      end;

  if LFileName='' then
    begin
      WriteLn(IllegalNoArgs);
      Halt(1);
    end;

  if PasFileName='' then PasFileName := Root(LFileName)+'.pas';
  LstFileName := Root(LFileName)+'.lst';

  (* open files: *)

  Assign(YYIn, LFileName);
  Assign(YYOut, PasFileName);
  Assign(YYLst, LstFileName);

  Reset(YYIn);    if IOResult<>0 then Fatal(CannotOpenFile+LFileName);
  Rewrite(YYOut); if IOResult<>0 then Fatal(CannotOpenFile+PasFileName);
  Rewrite(YYLst); if IOResult<>0 then Fatal(CannotOpenFile+LstFileName);

  (* search code template *)
  CodFileName := 'yylex.cod';
  Assign(YYCod, CodFileName);
  Reset(YYCod);
  if IOResult<>0 then
    begin
      CodFileName := IncludeTrailingPathDelimiter(GetEnvironmentVariable('FPCDIR'))+'lexyacc'+DirectorySeparator+'yylex.cod';
      Assign(YYCod, CodFileName);
      Reset(YYCod);
      if IOResult<>0 then
        begin
          CodFileName := CodFilePath1+'yylex.cod';
          Assign(YYCod, CodFileName);
          Reset(YYCod);
          if (CodFilePath2<>'') and (IOResult<>0) then
            begin
              CodFileName := CodFilePath2+'yylex.cod';
              Assign(YYCod, CodFileName);
              Reset(YYCod);
              if IOResult<>0 then
                Fatal(CannotOpenFile+CodFileName);
            end;
        end;
    end;

  (* parse source grammar: *)

  Write('parse ... ');
  LNo := 0; NRules := 0; NextSection;
  FirstPosTable^[0] := NewIntSet;
  FirstPosTable^[1] := NewIntSet;
  Definitions;
  Rules;
  if NRules=0 then Error(EmptyGrammar, Length(Line)+1);
  if Errors=0 then
    begin
      (* generate DFA table and listings and write output code: *)
      Write('DFA construction ... ');
      MakeDFATable;
      if Optimize then
        begin
          Write('DFA optimization ... ');
          OptimizeDFATable;
        end;
      Write('code generation ... ');
      if Verbose then ListDFATable;
      GenerateTable; NextSection;
    end;
  AuxiliaryProcs;
  if Errors=0 then WriteLn('DONE');

  (* close files: *)

  Close(YYIn); Close(YYOut); Close(YYLst); Close(YYCod);

  (* print statistics: *)

  if Errors>0 then
    WriteLn( LNo, ' lines, ',
             Errors, ' errors found.' )
  else
    WriteLn( LNo, ' lines, ',
             NRules, ' rules, ',
             NPos, '/', MaxPos, ' p, ',
             NStates, '/', MaxStates, ' s, ',
             NTrans, '/', MaxTrans, ' t.');

  if Warnings>0 then WriteLn(Warnings, ' warnings.');

  (* terminate: *)

  if Errors>0 then Erase(YYOut);
  if GetFileSize(LstFileName)=0 then
    Erase(YYLst)
  else
    WriteLn('(see ', LstFileName, ' for more information)');

  Halt(Errors);

end(*Lex*).
