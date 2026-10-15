{
    This program is part of the Free Pascal run time library.
    Copyright (c) 1999-2000 by Peter Vreman
    member of the Free Pascal development team

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

{ Program to create a depend makefile for a program with multiple units }

program PPDep;
uses Dos;

{.$define debug}

const
{$ifdef unix}
  ExeExt='';
{$else}
  ExeExt='.EXE';
{$endif}

type
  PUses=^TUses;
  TUses=record
    Name : string[32];
    Next : PUses;
  end;
  PUnit=^TUnit;
  TUnit=record
    UsesList : PUses;
    PasFn,
    Name     : string[32];
    IsUnit   : Boolean;
    Next     : PUnit;
  end;
  PDefine=^TDefine;
  TDefine = Record
    Name : String[32];
    Next : PDefine;
    end;


var
  UnitList         : PUnit;
  Define           : PDefine;
  ParaFile         : string;
  Verbose          : Boolean;
  AddCall          : Byte;
  CallLine,
  OutFile          : String;
  UnitExt          : String;

{****************************************************************************
                           Handy Routines
****************************************************************************}

function UCase(Const HStr:string):string;
var
  I : LongInt;
begin
  SetLength(UCase,Length(HStr));
  for I:=1to Length(HStr) do
   UCase[I]:=UpCase(HStr[I]);
end;


function FixFn(const S:string):string;
var
  I      : LongInt;
  NoPath : Boolean;
begin
  SetLength(FixFn,Length(S));
  NoPath:=True;
  for I:=Length(S) downto 1 do
   begin
     case S[I] of
 {$ifdef unix}
  '/','\' : begin
              FixFn[I]:='/';
              NoPath:=False; {Skip lowercasing path: 'X11'<>'x11' }
            end;
 'A'..'Z' : if NoPath then
             FixFn[I]:=Char(Byte(S[I])+32)
            else
             FixFn[I]:=S[I];
 {$else}
      '/' : FixFn[I]:='\';
 'A'..'Z' : FixFn[I]:=Char(Byte(S[I])+32); { everything lowercase }
 {$endif}
     else
      FixFn[I]:=S[I];
     end;
   end;
end;


{****************************************************************************
                             Main Program
****************************************************************************}

Function SearchPas(const Fn:string):string;
begin
  SearchPas:=FixFn(Fn+'.PAS');
end;


Function UnitDone(const Fn:string):Boolean;
var
  HP : PUnit;
begin
  HP:=UnitList;
  while not (HP=nil) do
   begin
     if HP^.Name=Fn then
      begin
        UnitDone:=True;
        exit;
      end;
     HP:=HP^.Next;
   end;
  UnitDone:=False;
end;


Function CheckDefine(const S:string):Boolean;
var
  SS : string[32];
  P : PDefine;
begin
  SS:=UCase(S);
  P:=Define;
  while (P<>Nil) do
   begin
     if SS=P^.Name then
      begin
        CheckDefine:=True;
        exit;
      end;
     P:=P^.Next;
   end;
  CheckDefine:=False;
end;

Procedure AddDefine(Const S : String);
Var
  P : PDefine;
begin
  New(P);
  P^.Name:=UCase(S);
  P^.Next:=Define;
  Define:=P;
end;


procedure RemoveSep(var Fn:string);
var
  I : LongInt;
begin
  I:=0;
  while (I<Length(Fn)) and (Fn[I+1] in [',',' ',#9]) do
   Inc(I);
  Delete(Fn,1,I);
end;


function GetName(var Fn:string):string;
var
  I : LongInt;
begin
  I:=0;
  while (I<Length(Fn)) and (Fn[I+1] in ['A'..'Z','0'..'9','_','-']) do
   Inc(I);
  GetName:=Copy(Fn,1,I);
  Delete(Fn,1,I);
end;


procedure ListDepend(const Fn:string);

{$ifndef FPC}
  procedure ReadLn(var T:Text;var S:string);
  var
    C : Char;
    I : LongInt;
  begin
    C:=#0;
    I:=0;
    while (not EOF(T)) and (C<>#10) do
     begin
       Read(T,C);
       if C<>#10 then
        begin
          Inc(I);
          S[I]:=C;
        end;
     end;
    if (I>0) and (S[I]=#13) then
     Dec(I);
    SetLength(S,I);
  end;
{$endif}

const
  MaxLevel=200;
var
  F  : Text;
  HS : ^string;
  CurrUses,LastUses : PUses;
  CurrUnit,LastUnit : PUnit;
  I,J : LongInt;
  UsesDone,
  OldComment,
  Done,Comment,
  InImplementation : Boolean;
  Skip : array[0..MaxLevel] of Boolean;
  Level : Byte;
begin
  if UnitDone(Fn) then
   exit;
  New(HS);
  New(CurrUnit);
  CurrUnit^.Next:=nil;
  CurrUnit^.Name:=Fn;
  CurrUnit^.IsUnit:=True;
  CurrUnit^.PasFn:=SearchPas(Fn);
  CurrUnit^.UsesList:=nil;
  Assign(F,CurrUnit^.PasFn);
  {$I-}
   Reset(F);
  {$I+}
  if IOResult=0 then
   begin
     if Verbose then
      WriteLn('Processing ',CurrUnit^.PasFn);
   {Add to Linked List}
     if UnitList=nil then
      UnitList:=CurrUnit
     else
      begin
        LastUnit:=UnitList;
        while not (LastUnit^.Next=nil) do
         LastUnit:=LastUnit^.Next;
        LastUnit^.Next:=CurrUnit;
      end;
   {Parse file}
     InImplementation:=False;
     Done:=False;
     UsesDone:=True;
     Comment:=False;
     OldComment:=False;
     FillChar(Skip,SizeOf(Skip),0);
     HS^:='';
     Level:=0;
     while (not Done) and (not EOF(F)) do
      begin
        repeat
          if HS^='' then
           begin
             ReadLn(F,HS^);
             HS^:=UCase(HS^);
           end;
          RemoveSep(HS^);
        until (HS^<>'') or EOF(F);
        if Comment then
         begin
           I:=Pos('}',HS^);
           if (I>0) then
            begin
              J:=Pos('{',HS^);
              if (J>0) and (J<I) then
               begin
                 Comment:=True;
                 Delete(HS^,1,J-1);
               end
              else
               begin
                 Comment:=False;
                 Delete(HS^,1,I-1);
               end;
            end
           else
            HS^:='';
         end;
        if (Pos('(*',HS^)>0) or OldComment then
         begin
           I:=Pos('*)',HS^);
           if (I>0) then
            begin
              OldComment:=False;
              Delete(HS^,1,I+1);
            end
           else
            begin
              OldComment:=True;
              HS^:='';
            end;
         end;
        if (HS^<>'') then
         begin
           case HS^[1] of
            '}' : begin
                    Comment:=False;
                    HS^:='';
                  end;
            '{' : begin
                    if (Copy(HS^,2,6)='$IFDEF') then
                     begin
                       Delete(HS^,1,7);
                       RemoveSep(HS^);
                       Inc(Level);
                       if Level>=MaxLevel then
                        begin
                          WriteLn('Too many IF(N)DEFs');
                          Halt(1);
                        end;
                       Skip[Level]:=Skip[Level-1] or (not CheckDefine(GetName(HS^)));
                       HS^:='';
                     end
                    else
                     if (Copy(HS^,2,7)='$IFNDEF') then
                      begin
                        Delete(HS^,1,7);
                        RemoveSep(HS^);
                        Inc(Level);
                        if Level>=MaxLevel then
                         begin
                           WriteLn('Too many IF(N)DEFs');
                           Halt(1);
                         end;
                        Skip[Level]:=Skip[Level-1] or (CheckDefine(GetName(HS^)));
                        HS^:='';
                      end
                    else
                     if (Copy(HS^,2,5)='$ELSE') then
                      begin
                        Skip[Level]:=Skip[Level-1] or (not Skip[Level]);
                        HS^:='';
                      end
                    else
                     if (Copy(HS^,2,6)='$ENDIF') then
                      begin
                        Skip[Level]:=False;
                        if Level=0 then
                         begin
                           WriteLn('Too many ENDIFs');
                           Halt(1);
                         end;
                        Dec(Level);
                        HS^:='';
                      end
                    else
                     if (Copy(HS^,2,6)='$IFOPT') then
                      begin
                        Inc(Level);
                        if Level>=MaxLevel then
                         begin
                           WriteLn('Too many IF(N)DEFs');
                           Halt(1);
                         end;
                        Skip[Level]:=True;
                        HS^:='';
                      end
                    else
                     begin
                       I:=Pos('}',HS^);
                       if I>0 then
                        begin
                          Delete(HS^,1,I);
                          Comment:=False;
                        end
                       else
                        Comment:=True;
                     end;
                  end;
            ';' : begin
                    UsesDone:=True;
                    Done:=(UsesDone and InImplementation);
                    HS^:='';
                  end;
           else
            begin
              if Skip[Level] then
               HS^:=''
              else
               begin
                 if (not UsesDone) then
                  begin
                    New(CurrUses);
                    CurrUses^.Name:=GetName(HS^);
                    CurrUses^.Next:=nil;
                    if CurrUnit^.UsesList=nil then
                     CurrUnit^.UsesList:=CurrUses
                    else
                     begin
                       LastUses:=CurrUnit^.UsesList;
                       while not (LastUses^.Next=nil) do
                        LastUses:=LastUses^.Next;
                       LastUses^.Next:=CurrUses;
                     end;
   {$ifndef debug}
                    ListDepend(CurrUses^.Name);
   {$endif}
                    RemoveSep(HS^);
                  end
                 else
                  begin
                    if (Copy(HS^,1,4)='USES') and ((Length(HS^)=4) or (HS^[5] in [' ',#9])) then
                     begin
                       Delete(HS^,1,4);
                       UsesDone:=False;
                     end
                    else
                     begin
                       if (HS^='IMPLEMENTATION') then
                        InImplementation:=True
                       else
                        if (Copy(HS^,1,7)='PROGRAM') then
                         begin
                           CurrUnit^.IsUnit:=False;
                           InImplementation:=True; {there can be only 1 uses}
                         end
                       else
                         if InImplementation and ((Copy(HS^,1,5)='CONST') or
                            (Copy(HS^,1,3)='VAR') or (Copy(HS^,1,5)='BEGIN')) then
                          Done:=True;
                       HS^:='';
                     end;
                  end;
               end;
            end;
           end;
         end;
      end;
     Close(F);
   end
  else
   Dispose(CurrUnit);
  Dispose(HS);
end;


procedure ShowDepend;
var
  CurrUnit : PUnit;
  CurrUses : PUses;
  T        : Text;
  P        : PDefine;
  First    : Boolean;
begin
  if CallLine='' then
   begin
     CallLine:='ppc386 ';
     P:=Define;
     While P<>Nil do
      begin
        CallLine:=CallLine+' -d'+P^.Name;
        P:=P^.Next;
      end;
   end;
  Assign(T,OutFile);
  Rewrite(T);
  CurrUnit:=UnitList;
  First:=True;
  while not (CurrUnit=nil) do
   begin
     if CurrUnit^.IsUnit then
      Write(T,FixFn(CurrUnit^.Name+'.'+UnitExt)+': '+CurrUnit^.PasFn)
     else
      Write(T,FixFn(CurrUnit^.Name+ExeExt)+': '+CurrUnit^.PasFn);
     CurrUses:=CurrUnit^.UsesList;
     while not (CurrUses=nil) do
      begin
{$ifndef debug}
        if UnitDone(CurrUses^.Name) then
{$endif}
         begin
           WriteLn(T,' \');
           Write(T,#9+FixFn(CurrUses^.Name+'.'+UnitExt));
         end;
        CurrUses:=CurrUses^.Next;
      end;
     WriteLn(T,'');
     If (AddCall=2) or (First and (AddCall=1)) then
      WriteLn(T,#9,CallLine,' ',CurrUnit^.PasFn);
     WriteLn(T,'');
     CurrUnit:=CurrUnit^.Next;
     First:=False;
   end;
  Close(T);
end;


procedure GetPara;
var
  Ch   : Char;
  Para : string[128];
  I    : Word;

  procedure HelpScreen;
  begin
    WriteLn('ppdep [Options] <File>');
    WriteLn;
    WriteLn('Options can be: -D<define>   Define a symbol');
    WriteLn('                -oFile       Write output to file');
    WriteLn('                             (default stdout)');
    WriteLn('                -eext        Set unit extension to ext');
    WriteLn('                             (default ppu)');
    WriteLn('                -V           Be more verbose');
    WriteLn('          -? or -H           This HelpScreen');
    WriteLn('                -A[call]     Add compiler calls to makefile (all files)');
    WriteLn('                -F[call]     Add compiler calls to makefile (only top file)');
    Halt(1);
  end;

begin
  Define:=Nil;
  OutFile:='';
  AddCall:=0;
  Verbose:=False;
{$IFDEF Unix}
  UnitExt:='nxu';
{$ELSE}
  UnitExt:='NXU';
{$endif}
  for I:=1 to ParamCount do
   begin
     Para:=ParamStr(I);
     if (Para[1]='-') then
      begin
        Ch:=UpCase(Para[2]);
        Delete(Para,1,2);
        case Ch of
         'A' : begin
                 AddCall:=2;
                 CallLine:=Para;
               end;
         'F' : begin
                 AddCall:=1;
                 CallLine:=Para;
               end;
         'D' : AddDefine(Para);
         'O' : OutFile:=Para;
         'E' : UnitExt:=Para;
         'V' : Verbose:=True;
     '?','H' : HelpScreen;
        end;
     end
    else
     begin
       ParaFile:=Para;
       if Pos('.',ParaFile)>0 then
        Delete(ParaFile,Pos('.',ParaFile),255);
     end;
    end;
  if (ParaFile='') then
   HelpScreen;
end;


begin
  GetPara;
  ListDepend(ParaFile);
  ShowDepend;
end.
