{
    Copyright (c) 1999-2000 by Peter Vreman (msg2inc) and
                          Marco van de Voort (data2inc)
    Placed under LGPL (See the file COPYING.FPC, included in this
    distribution, for details about the copyright)

    E-Mail Marco : Marcov@stack.nl
    Homepage Marco: www.stack.nl/~marcov/xtdlib.htm

    Data2Inc is a heavily modified version of msg2inc.pas which compiles the
     inputfile to include files containing array of char( or byte) typed
     constants.

     (e.g. CONST xxx : ARRAY[0..xxx] OF CHAR =( aa,bb,cc,dd,ee); ,
     or the same but ARRAY OF BYTE )

    Two types of input file are allowed:

    1 A special kind of textfile. Records start with '!'name and all following
       non empty and non comment (starting with '#',':' or '%') lines until
       the next line starting with '!' or EOF are the data. Data are either
       plain text (with \xxx ordinal constants) lines or a kinbd of
       Basic DATA command (these lines start with DATA).
       See demo.txt included with this package for a commented example.

    2  (special parameter -b)
       An arbitrary binary file can get converted to constants. In this mode
        only one constant per include file is possible.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
program Data2Inc;
uses Strings;

CONST
  Version='1.00';

  MaxBufSize = 1024*1024;  { 1 mb buffer }

type
  TOutputMode=(OutByte,OutChar,OutString);


{*****************************************************************************
            Simple service routines. These are copied from EPasStr.
*****************************************************************************}

TYPE TCharSet=SET OF AnsiChar;

FUNCTION NextCharPos(CONST S : AnsiString;C:AnsiChar;Count:LongInt):LongInt;

VAR I,J:LongInt;

BEGIN
 I:=Length(S);
 IF I=0 THEN
  J:=0
 ELSE
  BEGIN
   J:=Count;
  IF J>I THEN
   BEGIN
    NextCharPos:=0;
    EXIT
   END;
  WHILE (S[J]<>C) AND (J<=I) DO Inc(J);
   IF (J>I) THEN
    J:=0;
  END;
 NextCharPos:=J;
END;

FUNCTION NextCharPosSet(CONST S : AnsiString;CONST C:TCharSet;Count:LongInt):LongInt;

VAR I,J:LongInt;

BEGIN
   I:=Length(S);
   IF I=0 THEN
    J:=0
   ELSE
    BEGIN
   J:=Count;
   IF J>I THEN
    BEGIN
     NextCharPosSet:=0;
     EXIT;
    END;
   WHILE (J<=I) AND (NOT (S[J] IN C)) DO Inc(J);
   IF (J>I) THEN
    J:=0;                                        // NOT found.
   END;
 NextCharPosSet:=J;
END;


PROCEDURE RTrim(VAR P : AnsiString;Ch:AnsiChar);

VAR I,J : LongInt;

BEGIN
 I:=Length(P);      { Keeping length in local data eases optimizations}
 IF (I>0) THEN
  BEGIN
   J:=I;
   WHILE (P[J]=Ch) AND (J>0) DO Dec(J);
   IF J<>I THEN
    Delete(P,J+1,I-J+1);
   END;
END;

PROCEDURE UpperCase(VAR S : AnsiString);

VAR L,I : LongInt;

BEGIN
 L:=Length(S);
 IF L>0 THEN
  FOR I:=1 TO L DO
   IF (S[I]>Chr(96)) AND (S[I]<Chr(123)) THEN
    S[I]:=Chr(Ord(S[I])-32);
END;

PROCEDURE LTrim(VAR P : AnsiString;Ch:AnsiChar);

VAR I,J : LongInt;

BEGIN
 I:=Length(P);      { Keeping length in local data eases optimizations}
 IF (I>0) THEN
  BEGIN
   J:=1;
   WHILE (P[J]=Ch) AND (J<=I) DO Inc(J);
   IF J>1 THEN
    Delete(P,1,J-1);
   END;
END;


{*****************************************************************************
                              Parsing helpers
*****************************************************************************}

FUNCTION XlatString(Var S : AnsiString):Boolean;
{replaces \xxx in string S with #x, and \\ with \ (escaped)
 which can reduce size of string.

Returns false when an error in the line exists}


Function GetNumber(Position:LongInt):LongInt;

VAR C,
    Value,
    I : LongInt;

BEGIN
 I:=0; Value:=0;
 WHILE I<3 DO
  BEGIN
   C:=Ord(S[Position+I]);
   IF (C>47) AND (C<56) THEN
    C:=C-48
   ELSE
    BEGIN
     GetNumber:=-1;
     EXIT;
    END;
   IF I=0 THEN
    C:=C SHL 6;
   IF I=1 THEN
    C:=C SHL 3;
   Value:=Value + C;
   Inc(I);
   END;
 GetNumber:=Value;
END;

VAR S2:AnsiString;
    A,B : LongInt;
    Value : LongInt;

BEGIN
 A:=1; B:=1;
 WHILE A<=Length(S) DO
  BEGIN
   IF S[A]='\' THEN
    IF S[A+1]='\' THEN
     BEGIN
      S2[B]:='\';
      Inc (A,2); Inc(B);
     END
    ELSE
     BEGIN
      Value:=GetNumber(A+1);
      IF Value=-1 THEN
       BEGIN
        XlatString:=False;
        EXIT;
       END;
      S2[B]:=Chr(Value);
      Inc(B); Inc(A,4);
     END
   ELSE
    BEGIN
     S2[B]:=S[A];
     Inc (A);
     Inc (B);
    END;
  END;
 SetLength(S2,B-1);
 S:=S2;
 XlatString:=True;
END;

{Global equates}

VAR
  InName,                     { Name of input file }
  OutName,                    { Name of output (.inc) file }
  BinConstName : AnsiString;  { (-b only) commandline name of constant }
  OutputMode   : TOutputMode; { Output mode (char,byte,string) }
  IBinary     : Boolean;     { TRUE is binary input, FALSE textual }
  MsgTxt       : PAnsiChar;   { Temporary storage of data }
  MsgSize      : LongInt;     { Bytes used in MsgTxt }
  C            : AnsiChar;


{*****************************************************************************
                               WriteCharFile
*****************************************************************************}

{Dump the contents of MsgTxt (msgsize bytes) to file T (which has been opened),
using CONSTNAME as the name of the ARRAY OF CHAR constant}
procedure WriteCharFile(var T:Text;ConstName:AnsiString);

  function CreateConst(B:Byte):string;
  {decides whether to use the #xxx code or 'c' style for each char}
  begin
    if (B in [32..127]) and (B<>39) then
     CreateConst:=''''+Chr(B)+''''
    else
     CreateConst:='#'+Chr(B div 100+48)+Chr((B mod 100) div 10+48)+Chr(B mod 10+48)
  end;

var
  CIdx,I  : LongInt;
  P       : PAnsiChar;
begin
  WriteLn('Writing constant: ',ConstName,' to file '#39,OutName,#39);
{Open textfile}
  Write(T,'const ',ConstName,' : array[0..'); WriteLn(T,MsgSize-1,'] of char=(');
  P:=MsgTxt;
  CIdx:=0;
  for I:=0 to MsgSize-1 do
   begin
     if CIdx=15 then
      begin
        if CIdx>0 then
         WriteLn(T,',')
        else
         WriteLn(T,'');
        Write(T,'  ');
        CIdx:=0;
      end
     else
       IF CIdx>0 THEN
        Write(T,',')
       ELSE
        Write(T,'  ');
     Write(T,CreateConst(Ord(P^)));
     Inc(CIdx);
     Inc(P);
   end;
  WriteLn(T,');');
  WriteLn(T);
end;


{*****************************************************************************
                               WriteByteFile
*****************************************************************************}

{Dump the contents of MsgTxt (msgsize bytes) to file T (which has been opened),
using CONSTNAME as the name of the ARRAY OF BYTE constant}
procedure WriteByteFile(var T:Text;ConstName:AnsiString);

  function CreateConst(B:Byte):AnsiString;
  {Translates byte B to a $xx hex constant}
  VAR L : Byte;
  begin
   CreateConst[1]:='$'; SetLength(CreateConst,3);
   L:=Ord(B SHR 4) +48;
   IF L>57 THEN
    L:=L+7;
   CreateConst[2]:=Chr(L);
   L:=Ord(B and 15) +48;
   IF L>57 THEN
    Inc(L,7);
   CreateConst[3]:=Chr(L);
  end;

var
  CIdx,I  : LongInt;
  P       : PAnsiChar;
begin
  WriteLn('Writing constant: ',ConstName,' to file '#39,OutName,#39);
{Open textfile}
  Write(T,'const ',ConstName,' : array[0..'); WriteLn(T,MsgSize-1,'] of byte=(');
  P:=MsgTxt;
  CIdx:=0;
  for I:=0 to MsgSize-1 do
   begin
     if CIdx=15 then
      begin
        if CIdx>0 then
         WriteLn(T,',')
        else
         WriteLn(T,'');
        Write(T,'  ');
        CIdx:=0;
      end
     else
       IF CIdx>0 THEN
        Write(T,',')
       ELSE
        Write(T,'  ');
     Write(T,CreateConst(Ord(P^)));
     Inc(CIdx);
     Inc(P);
   end;
  WriteLn(T,');');
  WriteLn(T);
end;


{*****************************************************************************
                               WriteStringFile
*****************************************************************************}

procedure WriteStringFile(var T:Text;ConstName:AnsiString);
const
  MaxSLen=240; { to overcome aligning problems }

  function L0(L:LongInt):AnsiString;
  var
    S : string[16];
  begin
    Str(L,S);
    while (Length(S)<5) do
     S:='0'+S;
    L0:=S;
  end;

var
  SLen,
  Len,I  : LongInt;
  P      : PAnsiChar;
  Start,
  Quote  : Boolean;
begin
  WriteLn('Writing constant: ',ConstName,' to file '#39,OutName,#39);
{Open textfile}
  WriteLn(T,'{$ifdef Delphi}');
  WriteLn(T,'const '+ConstName+' : array[0..',(MsgSize-1) div MaxSLen,'] of string[',MaxSLen,']=(');
  WriteLn(T,'{$else Delphi}');
  WriteLn(T,'const '+ConstName+' : array[0..',(MsgSize-1) div MaxSLen,',1..',MaxSLen,'] of char=(');
  Write(T,'{$endif Delphi}');
{Parse buffer in msgbuf and create indexs}
  P:=MsgTxt;
  SLen:=0;
  Len:=0;
  Quote:=False;
  Start:=True;
  for I:=1 to MsgSize do
   begin
     if SLen>=MaxSLen then
      begin
        if Quote then
         begin
           Write(T,'''');
           Quote:=False;
         end;
        Write(T,',');
        SLen:=0;
        Inc(Len);
      end;
     if (Len>70) or (Start) then
      begin
        if Quote then
         begin
           Write(T,'''');
           Quote:=False;
         end;
        if SLen>0 then
          WriteLn(T,'+')
        else
          WriteLn(T);
        Len:=0;
        Start:=False;
      end;
     if (Len=0) then
      Write(T,'  ');
     if (Ord(P^)>=32) and (P^<>#39) then
      begin
        if not Quote then
         begin
           Write(T,'''');
           Quote:=True;
           Inc(Len);
         end;
        Write(T,P^);
        Inc(Len);
      end
     else
      begin
        if Quote then
         begin
           Write(T,'''');
           Inc(Len);
           Quote:=False;
         end;
        Write(T,'#'+Chr(Ord(P^) div 100+48)+Chr((Ord(P^) mod 100) div 10+48)+Chr(Ord(P^) mod 10+48));
        Inc(Len,3);
      end;
     { start a new line when a #0 or #10 is found }
     if P^ in [#0,#10] then
      Start:=True;
     Inc(SLen);
     Inc(P);
   end;
  if Quote then
   Write(T,'''');
  WriteLn(T,'');
  WriteLn(T,');');
end;


{*****************************************************************************
                                   Parser
*****************************************************************************}

FUNCTION SpecialItem(S : AnsiString):LongInt;
{ This procedure finds the next comma, (or the end of the string)
    but comma's within single or double quotes should be ignored.
    Single quotes within double quotes and vice versa are also ignored.}

VAR DataItem : LongInt;

CONST XFcl : TCharSet = [',',#39,'"'];

BEGIN

    DataItem:=0;
    REPEAT
     DataItem:=NextCharPosSet(S,XFcl,DataItem+1);   {Find first " ' or ,}
      IF (DataItem<>0) AND ((S[DataItem]='"') OR (S[DataItem]=#39)) THEN { (double)Quote found?}
       DataItem:=NextCharPos(S,S[DataItem],DataItem+1);  { then find other one}
     UNTIL (DataItem=0) OR (S[DataItem]=',');
     IF DataItem=0 THEN     {Last data field of this line?}
      DataItem:=Length(S);
    SpecialItem:=DataItem;
END;


{ Handles reading and processing of a textual file}
procedure DoFile;
var
  InFile,
  OutFile : Text;       {in and output textfiles}
  Line, DataItem,       {line number, position in DATA line}
  I1,I2,                {4 temporary counters}
  I3,I4  : LongInt;
  S,S1    : AnsiString;     {S is string after reading, S1 is temporary string or
                          current DATA-item being processed }
  VarName : AnsiString;     { Variable name of constant to be written}

  PROCEDURE ParseError;
  {Extremely simple errorhandler}
  BEGIN
   WriteLn('Error in line : ',Line, ' Somewhere near :',#39,S1,#39);
   Close(InFile); Close(OutFile);
   Halt;
  END;

  PROCEDURE FixDec;
  { Reads decimal value starting at S1[1].
       Value in I3, number of digits found in I1}
       var I1,I2,I3 : LongInt;

  BEGIN
   I1:=1;
   WHILE ((S1[I1]>#47) AND (S1[I1]<#58)) AND (I1<=Length(S1)) DO
    Inc(I1);
   Dec(I1);
   IF I1=0 THEN
    ParseError;
   I3:=0;
   FOR I2:=1 TO I1 DO
    I3:=(I3*10)+ Ord(S1[I2])-48;
  {Calc no of bytes(1,2 or 4) required from no of digits found}
   IF (I1<3) THEN
    I2:=1
   ELSE
    IF (I1=3) AND (I3<256) THEN
     I2:=1
    ELSE
     BEGIN
      IF I1<5 THEN
       I2:=2
       ELSE
        IF (I1=5) AND (I3<65536) THEN
         I2:=2
        ELSE
         I2:=4;
     END;
  END;

  PROCEDURE DoChar;
  { Reads a #xxx constant at S1[1], and puts it in msgtxt array.
      Deletes #xxx constant from S1}
  BEGIN
   Delete(S1,1,1);
   FixDec;
   MsgTxt[MsgSize]:=Chr(I3);
   Inc(MsgSize);
   Delete(S1,1,I1);
  END;

  PROCEDURE DoQuote;
  { Reads a quoted text-string ('xxx' or "xxx"). Quotechar is in S1[1]
    (always ' or "), any char except the quotechar is allowed between two
    quotechars.
      Deletes quoted textstring incl quotes from S1}
  VAR
    C : AnsiChar;
  BEGIN
    C:=S1[1];
    Delete(S1,1,1);
    I1:=Pos(C,S1);                       {Find other quote}
    IF I1=0 THEN
     ParseError;                    {Quotes have to be matched}
    Dec(I1);
    IF I1<>0 THEN
     BEGIN
      Move(S1[1],MsgTxt[MsgSize],I1);
      Inc(MsgSize,I1);
     END;
    Delete(S1,1,I1+1);
    LTrim(S1,' ');
  END;

  PROCEDURE FixHex(Base2:LongInt);
  { Reads a base 2,8 or 16 constant from S1.
    Parameter = 2Log of base (1,3 or 4 corresponding to base 2,8 and 16)
    Constant is processed, the number of digits estimated (1,2 or 4 bytes) and
    the value is appended to msgtxt accordingly}
  BEGIN
    I3:=0;
    I2:=1;
    WHILE (S1[I2] IN ['0'..'9','A'..'F','a'..'f']) AND (I2<=Length(S1)) DO
     BEGIN
      IF (S1[I2]>#47) AND (S1[I2]<#58) THEN
       I3:=(I3 SHL Base2)+ Ord(S1[I2])-48
      ELSE
       IF (S1[I2]>#64) AND (S1[I2]<#71) THEN
        I3:=(I3 SHL Base2)+ Ord(S1[I2])-55
       ELSE
        IF (S1[I2]>#96) AND (S1[I2]<#103) THEN
         I3:=(I3 SHL Base2)+ Ord(S1[I2])-87
       ELSE
        ParseError;
       Inc(I2);
     END;
    Dec(I2);
    CASE Base2 OF
     4 :   BEGIN
           I4:=(I2 SHR 1);
           IF Odd(I2) THEN
            Inc(I4);
           IF I4=3 THEN I4:=4
          END;
     3 :   I4:=(I2*3 DIV 8)+1;
     1 :   BEGIN
            IF I2<9 THEN
             I4:=1
            ELSE
             IF I2<17 THEN
              I4:=2
             ELSE
             I4:=4;
           END;
      ELSE
       BEGIN
        WriteLn(' severe internal error ');
        ParseError;
       END; {else}
    END; {Case}
    Move(I3,MsgTxt[MsgSize],I4);
    Inc(MsgSize,I4);
  END;

  PROCEDURE DoTextual;
  { processes aggregates of textual data like 'xxx'+#39"2143124"+'1234'#123}

  BEGIN
   REPEAT
    CASE S1[1] OF
     '#' : DoChar;
     '"',#39 : DoQuote;           {Should I support octal codes here?}
    ELSE
     ParseError;
     END;
    LTrim(S1,' ');
    IF (S1[1]='+') THEN
     Delete(S1,1,1);
    LTrim(S1,' ');
   UNTIL Length(S1)=0;
  END;

  PROCEDURE FlushMsgTxt;            {Flush MsgTxt array}
  BEGIN
   IF MsgSize>0 THEN          {In memory? Then flush}
    BEGIN
      case OutputMode of
        OutByte :
          WriteByteFile(OutFile,VarName);
        OutChar :
          WriteCharFile(OutFile,VarName);
        OutString :
          WriteStringFile(OutFile,VarName);
      end;
     MsgSize:=0;
    END;
  END;

{Actual DoFile}
begin
  GetMem(MsgTxt,MaxBufSize);
  WriteLn('processing file : ',InName);
{Read the message file}
  Assign(InFile,InName);
  {$I-}
   Reset(InFile);
  {$I+}
  if IOResult<>0 then
   begin
     WriteLn('file '+InName+' not found');
     exit;
   end;
{Create output file}
  Assign (OutFile,OutName);
  Rewrite(OutFile);
  MsgSize:=0;
  Line:=0;
  while not EOF(InFile) do
   begin
    ReadLn(InFile,S);      {Read a line}
    Inc(Line);
    S1:=Copy(S,1,5);
    UpperCase(S1);
    IF S1='DATA ' THEN   {DATA keyword?}
     BEGIN
      Delete(S,1,5);
      REPEAT
       DataItem:=SpecialItem(S);  {Yes. Determine size of DATA field.}
       IF DataItem<>0 THEN
        BEGIN
         I1:=DataItem;
         IF DataItem=Length(S) THEN
          Inc(I1);        {DataItem fix for last field}
         S1:=Copy(S,1,I1-1);    { copy field to S1}
         Delete(S,1,I1);        {Delete field from S}
         LTrim(S1,' ');
         RTrim(S1,' ');
         LTrim(S,' ');
         CASE S1[1] OF        {Select field type}
          #39,'"','#' : DoTextual; { handles textual aggregates
                                     e.g. #124"142"#123'sdgf''ads'}
          '$' : BEGIN         {Handle $xxxx hex codes}
                 Delete(S1,1,1);
                 RTrim(S1,' ');
                 IF Length(S1)>0 THEN
                  FixHex(4)
                 ELSE
                  ParseError;
                 END;
    '0'..'9'  : BEGIN    { handles 0x124,124124,124124H,234h,666o,353d,24b}
                 IF (Length(S1)>1) AND (S1[2]='x') THEN {C style 0xABCD hex}
                  BEGIN
                   Delete(S1,1,2);
                   FixHex(4);
                  END
                 ELSE {other types (HP notation suffix h,o,d and b (and upcase versions,
                                                       and no suffix) }
                  BEGIN
                   CASE S1[Length(S1)] OF
                    'H','h' : FixHex(4);      {Hex}
                    'o','O' : FixHex(3);      {octal}
                        'B','b' : BEGIN       {Binary}
                                   SetLength(S1,Length(S1)-1); {avoid 'b' char being treated as hex B }
                                   FixHex(1);
                                  END;
               '0'..'9','d','D' : BEGIN      {decimal versions}
                                   FixDec;   {Fixdec is safe for trailing chars}
                                   {I1 =no of digits, I3=value, I2= no bytes needed}
                                   Move(I3,MsgTxt[MsgSize],I2);
                                   Inc(MsgSize,I2)
                                  END
                             ELSE
                              ParseError; {otherwise wrong suffix}
                           END {Nested case}
                       END; { IF S1[2]='x'}
                      END; { '0'..'9'}
              '%'   : BEGIN          {%101010 binary constants}
                       Delete(S1,1,1);
                       FixHex(1);
                      END;
              '\'   : BEGIN          {\xxx octal constants}
                       Delete(S1,1,1);
                       FixHex(3);
                      END;
          END; {Case}
         END; {IF <>0}
        UNTIL {(DataItem:=Length(S)) OR} (DataItem=0); {parse until String is empty}
      END {S1='DATA'}
     ELSE
      BEGIN                          {Non DATA line}
       IF (Length(S)<>0) AND NOT (S[1] IN ['#',';','%']) THEN
        BEGIN
         C:=S[1];
         IF NOT XlatString(S) THEN  {Expand \xxx octal constants}
          BEGIN
           WriteLn('Some error with a \xxx constant or a stale (unescaped) backslash');
           ParseError;
          END;
         IF C='!' THEN         { New variable}
          BEGIN
           FlushMsgTxt;
           I1:=1;
           OutputMode:=OutChar;
           IF S[2]='$' THEN      {Flag for ARRAY OF BYTE?}
            BEGIN
             Inc(I1);
             OutputMode:=OutByte;
            END;
           Delete(S,1,I1);
           VarName:=S;
          END
         ELSE
          BEGIN {Normal line}
           I1:=Length(S);
           Move(S[1],MsgTxt[MsgSize],I1);
           Inc(MsgSize,I1);
          END;
      END;
    END;
   end;
  Close(InFile);
  FlushMsgTxt;                    {Flush variable if msgtxt is occupied}
  Close(OutFile);
end;


{*****************************************************************************
                                    Binary File
*****************************************************************************}

procedure DoBinary;
var
  InFile  : File;
  OutFile : Text;
  I       : LongInt;
begin
  WriteLn('processing file : ',InName);
{ Read the file }
  Assign(InFile,InName);
  {$I-}
   Reset(InFile,1);
  {$I+}
  if IOResult<>0 then
   begin
     WriteLn('file '+InName+' not found');
     exit;
   end;
{ First parse the file and count bytes needed }
  MsgSize:=FileSize(InFile);
  GetMem(MsgTxt,MsgSize);
  BlockRead(InFile,MsgTxt[0],MsgSize,I);
  Close(InFile);
  IF I<>MsgSize THEN
   BEGIN
     WriteLn('Error while reading file',InName);
     Halt(1);
   END;
{ Output }
  Assign (OutFile,OutName);
  Rewrite(OutFile);
  case OutputMode of
    OutByte :
      WriteByteFile(OutFile,BinConstName);
    OutChar :
      WriteCharFile(OutFile,BinConstName);
    OutString :
      WriteStringFile(OutFile,BinConstName);
  end;
  Close(OutFile);
end;


{*****************************************************************************
                                Main Program
*****************************************************************************}

procedure GetPara;
var
  Ch      : Char;
  Para    : string;
  Files,I : Word;

  procedure HelpScreen;
  begin
    WriteLn('usage : data2inc [Options] <msgfile> [incfile] [constname]');
    WriteLn('  The constname parameter is only valid in combination');
    WriteLn('  with -b, otherwise the constname must be specified in the inputfile');
    WriteLn;
    WriteLn('<Options> can be :');
    WriteLn('              -B     File to read is binary.');
    WriteLn('              -A     array of byte output (default is array of char)');
    WriteLn('              -S     array of string output');
    WriteLn('              -V     Show version');
    WriteLn('        -? or -H     This HelpScreen');
    WriteLn;
    WriteLn(' See data2inc.exm for a demonstration source');
    Halt(1);
  end;


begin
  IBinary:=False;
  OutputMode:=OutChar;
  Files:=0;
  for I:=1to ParamCount do
   begin
     Para:=ParamStr(I);
     if (Para[1]='-') then
      begin
        Ch:=UpCase(Para[2]);
        Delete(Para,1,2);
        case Ch of
         'B' : IBinary:=True;
         'A' : OutputMode:=OutByte;
         'S' : OutputMode:=OutString;
         'V' : begin
                 WriteLn('Data2Inc ',Version,' (C) 1999 Peter Vreman and Marco van de Voort');
                 WriteLn;
                 Halt;
               end;
     '?','H' : HelpScreen;

        end;
     end
    else
     begin
       Inc(Files);
       if Files>3 then
        HelpScreen;
       case Files of
        1 : InName:=Para;
        2 : OutName:=Para;
        3 : BinConstName:=Para;
       end;
     end;
    END;
   if (Files<3) AND IBinary then
     HelpScreen;
   IF Files<2 THEN
    HelpScreen;
end;

begin
  GetPara;
  IF IBinary THEN
   DoBinary
  ELSE
   DoFile;
end.
