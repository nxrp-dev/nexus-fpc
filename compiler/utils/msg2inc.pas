{
    This program is part of the Free Pascal run time library.
    Copyright (c) 1998-2002 by Peter Vreman

    Convert a .msg file to an .inc file with a const array of char
    And for the lazy docwriters it can also generate some TeX output

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
{$H+}
program msg2inc;

{$ifdef unix}
  {$define EOL_ONE_CHAR}
{$endif unix}
{$ifdef wasi}
  {$define EOL_ONE_CHAR}
{$endif}

const
  cVersion='1.00';
{$ifdef EOL_ONE_CHAR}
  cEOLLength=1;
{$else}
  cEOLLength=2;
{$endif}
  cMsgParts = 20;

type
  TMode=(ModeChar,ModeTex,ModeIntel,ModeString,ModeRenumber);
var
  InFile,
  OutFile,
  OutName    : String;
  Mode       : TMode;
  TexHeader  : Boolean;

  MsgTxt     : PChar;
  EnumTxt    : PChar;
  EnumSize,
  MsgSize    : LongInt;

  MsgIdxMax  : array[1..cMsgParts] of LongInt;
  Messages       : array[0..cMsgParts,0..999] of Boolean;
  MsgCodePage: TSystemCodePage;

procedure LoadMsgFile(const AFileName:String);
var
  lFile       : Text;
  lError,
  lMultiLine : Boolean;
  lCode : Word;
  lNumberPart,lNumberIndex,
  lLine,lIndex,lIndexJ,lNumber  : LongInt;
  lTextCursor,
  lEnumCursor   : PChar;
  lNumberText,
  lText,lText1    : String;

  procedure Err(const AMessage:String);
  begin
    WriteLn('error in line ',lLine,': ',AMessage);
    lError:=true;
  end;

begin
  WriteLn('Loading messagefile ',AFileName);
  MsgCodePage:=CP_ACP;
{Read the message file}
  assign(lFile,AFileName);
  {$push} {$I-}
   reset(lFile);
  {$pop}
  if IOResult<>0 then
   begin
     WriteLn('fatal error: '+AFileName+' not found');
     halt(1);
   end;
{ First parse the file and count bytes needed }
  fillchar(MsgIdxMax,sizeof(MsgIdxMax),0);
  fillchar(Messages,sizeof(Messages),0);
  lError:=false;
  lLine:=0;
  lMultiLine:=false;
  MsgSize:=0;
  while not eof(lFile) do
   begin
     readln(lFile,lText);
     inc(lLine);
     if lMultiLine then
      begin
        if lText=']' then
         lMultiLine:=false
        else if (lText='') or (lText[1] <> '#') then
         inc(MsgSize,length(lText)+1); { +1 for linebreak }
      end
     else
      begin
        if (lText<>'') and not(lText[1] in ['#',';','%']) then
         begin
           lIndex:=pos('=',lText);
           if lIndex>0 then
            begin
              lIndexJ:=lIndex+1;
              if not(lText[lIndexJ] in ['0'..'9']) then
               Err('no number found')
              else
               begin
                 while (lText[lIndexJ] in ['0'..'9']) do
                  inc(lIndexJ);
               end;
              if lIndexJ-lIndex-1<>5 then
               Err('number length is not 5');
              lNumberText:=Copy(lText,lIndex+1,lIndexJ-lIndex-1);
              { update the max index }
              val(lNumberText,lNumber,lCode);
              lNumberPart:=lNumber div 1000;
              if lNumberPart=0 then
               Err('number should be > 1000');
              if lCode<>0 then
               Err('illegal number: '+lText);
              lNumberIndex:=lNumber mod 1000;
              { duplicate ? }
              if Messages[lNumberPart,lNumberIndex] then
               Err('duplicate number found');
              Messages[lNumberPart,lNumberIndex]:=true;
              { check range }
              if lNumberPart > cMsgParts then
               Err('number is to large')
              else
               if lNumberIndex > MsgIdxMax[lNumberPart] then
                MsgIdxMax[lNumberPart]:=lNumberIndex;
              if lText[lIndexJ+1]='[' then
               begin
                 inc(MsgSize,lIndexJ-lIndex);
                 lMultiLine:=true
               end
              else
               inc(MsgSize,length(lText)-lIndex+1);
              inc(EnumSize,lIndexJ);
            end
           else
            Err('no = found');
         end
        else if (Length(lText)>11) and (Copy(lText,1,11)='# CodePage ') then
         begin
           val(Copy(lText,12,Length(lText)-11),MsgCodePage,lCode);
           if lCode<>0 then
             Err('illegal code page number: '+lText);
         end;
      end;
   end;
  if lMultiLine then
   Err('still in multiline mode');
  if lError then
   begin
     close(lFile);
     WriteLn('aborting');
     halt(1);
   end;
{ alloc memory }
  GetMem(MsgTxt,MsgSize);
{ no linebreak after last entry }
  dec(MsgSize);
  lTextCursor:=MsgTxt;
  GetMem(EnumTxt,EnumSize);
  lEnumCursor:=EnumTxt;
{ now read the buffer in mem }
  reset(lFile);
  while not eof(lFile) do
   begin
     readln(lFile,lText);
     if lMultiLine then
      begin
        if lText=']' then
         begin
           lMultiLine:=false;
           { overwrite last eol }
           dec(lTextCursor);
           lTextCursor^:=#0;
           inc(lTextCursor);
         end
        else if (lText='') or (lText[1] <> '#') then
         begin
           if length(lText)>0 then
             begin
               move(lText[1],lTextCursor^,length(lText));
               inc(lTextCursor,length(lText));
             end;
           lTextCursor^:=#10;
           inc(lTextCursor);
         end;
      end
     else
      begin
        if (lText<>'') and not(lText[1] in ['#',';','%']) then
         begin
           lIndex:=pos('=',lText);
           if lIndex>0 then
            begin
              lIndexJ:=lIndex+1;
              while (lText[lIndexJ] in ['0'..'9']) do
               inc(lIndexJ);
              {enum}
              move(lText[1],lEnumCursor^,lIndex-1);
              inc(lEnumCursor,lIndex-1);
              lEnumCursor^:='=';
              inc(lEnumCursor);
              lNumberText:=Copy(lText,lIndex+1,lIndexJ-lIndex-1);
              move(lNumberText[1],lEnumCursor^,length(lNumberText));
              inc(lEnumCursor,length(lNumberText));
              lEnumCursor^:=#0;
              inc(lEnumCursor);
              { multiline start then no txt }
              if lText[lIndexJ+1]='[' then
               begin
                 lText1:=Copy(lText,lIndex+1,lIndexJ-lIndex);
                 move(lText1[1],lTextCursor^,length(lText1));
                 inc(lTextCursor,length(lText1));
                 lMultiLine:=true;
               end
              else
               begin
                 { txt including number }
                 lText1:=Copy(lText,lIndex+1,255);
                 move(lText1[1],lTextCursor^,length(lText1));
                 inc(lTextCursor,length(lText1));
                 lTextCursor^:=#0;
                 inc(lTextCursor);
               end;
            end;
         end;
      end;
   end;
  close(lFile);
end;


{*****************************************************************************
                               WriteEnumFile
*****************************************************************************}

procedure WriteEnumFile(const AFileName:String);
var
  lOutputFile : Text;
  lIndex : LongInt;
  lCursor : PChar;
  lStart : Boolean;
begin
  WriteLn('Writing enumfile '+AFileName);
{Open textfile}
  assign(lOutputFile,AFileName);
  rewrite(lOutputFile);
  WriteLn(lOutputFile,'const');
{Parse buffer in msgbuf and create indexs}
  lCursor:=EnumTxt;
  lStart:=true;
  for lIndex:=1 to EnumSize do
   begin
     if lStart then
      begin
        write(lOutputFile,'  ');
        lStart:=false;
      end;
     if lCursor^=#0 then
      begin
        WriteLn(lOutputFile,';');
        lStart:=true;
      end
     else
      begin
        write(lOutputFile,lCursor^);
      end;
     inc(lCursor);
   end;
  WriteLn(lOutputFile,'');
  { msgtxt size }
  WriteLn(lOutputFile,'  MsgTxtSize = ',MsgSize,';');
  WriteLn(lOutputFile,'');
  { max msg idx table }
  WriteLn(lOutputFile,'  MsgIdxMax : array[1..20] of LongInt=(');
  write(lOutputFile,'    ');
  for lIndex:=1 to 20 do
   begin
     write(lOutputFile,MsgIdxMax[lIndex]+1);
     if lIndex<20 then
      write(lOutputFile,',');
     if lIndex=10 then
      begin
        WriteLn(lOutputFile,'');
        write(lOutputFile,'    ');
      end;
   end;
  WriteLn(lOutputFile,'');
  WriteLn(lOutputFile,'  );');
  close(lOutputFile);
end;


{*****************************************************************************
                               WriteStringFile
*****************************************************************************}

procedure WriteStringFile(const AFileName,AConstName:String);
const
  cMaxStringLength=240; { to overcome aligning problems }

  function PadNumber(AValue:LongInt):String;
  var
    lText : String[16];
  begin
    str(AValue,lText);
    while (length(lText)<5) do
     lText:='0'+lText;
    PadNumber:=lText;
  end;

var
  lOutputFile      : Text;
  lFile      : file;
  lStringLength,
  lLineLength,lIndex  : LongInt;
  lCursor      : PChar;
  lText      : String;
  lStart,
  lQuote  : Boolean;
begin
  WriteLn('Writing stringfile ',AFileName);
{Open textfile}
  assign(lOutputFile,AFileName);
  rewrite(lOutputFile);
  WriteLn(lOutputFile,'const '+AConstName+'_codepage=',MsgCodePage:5,';');
  WriteLn(lOutputFile,'{$ifdef Delphi}');
  WriteLn(lOutputFile,'const '+AConstName+' : array[0..000000] of string[',cMaxStringLength,']=(');
  WriteLn(lOutputFile,'{$else Delphi}');
  WriteLn(lOutputFile,'const '+AConstName+' : array[0..000000,1..',cMaxStringLength,'] of char=(');
  write(lOutputFile,'{$endif Delphi}');
{Parse buffer in msgbuf and create indexs}
  lCursor:=MsgTxt;
  lStringLength:=0;
  lLineLength:=0;
  lQuote:=false;
  lStart:=true;
  for lIndex:=1 to MsgSize do
   begin
     if lStringLength>=cMaxStringLength then
      begin
        if lQuote then
         begin
           write(lOutputFile,'''');
           lQuote:=false;
         end;
        write(lOutputFile,',');
        lStringLength:=0;
        inc(lLineLength);
      end;
     if (lLineLength>70) or (lStart) then
      begin
        if lQuote then
         begin
           write(lOutputFile,'''');
           lQuote:=false;
         end;
        if lStringLength>0 then
          WriteLn(lOutputFile,'+')
        else
          WriteLn(lOutputFile);
        lLineLength:=0;
        lStart:=false;
      end;
     if (lLineLength=0) then
      write(lOutputFile,'  ');
     if (ord(lCursor^)>=32) and (lCursor^<>#39) then
      begin
        if not lQuote then
         begin
           write(lOutputFile,'''');
           lQuote:=true;
           inc(lLineLength);
         end;
        write(lOutputFile,lCursor^);
        inc(lLineLength);
      end
     else
      begin
        if lQuote then
         begin
           write(lOutputFile,'''');
           inc(lLineLength);
           lQuote:=false;
         end;
        write(lOutputFile,'#'+chr(ord(lCursor^) div 100+48)+chr((ord(lCursor^) mod 100) div 10+48)+chr(ord(lCursor^) mod 10+48));
        inc(lLineLength,3);
      end;
     if lCursor^ in [#0,#10] then
      lStart:=true;
     inc(lStringLength);
     inc(lCursor);
   end;
  if lQuote then
   write(lOutputFile,'''');
  WriteLn(lOutputFile,'');
  WriteLn(lOutputFile,');');
  close(lOutputFile);
{update arraysize}
  lText:=PadNumber((MsgSize-1) div cMaxStringLength); { we start with 0 }
  assign(lFile,AFileName);
  reset(lFile,1);
  seek(lFile,22+34+2*cEOLLength+2*length(AConstName));
  blockwrite(lFile,lText[1],5);
  seek(lFile,22+90+4*cEOLLength+3*length(AConstName));
  blockwrite(lFile,lText[1],5);
  close(lFile);
end;


{*****************************************************************************
                               WriteCharFile
*****************************************************************************}

procedure WriteCharFile(const AFileName,AConstName:String);

  function PadNumber(AValue:LongInt):String;
  var
    lText : String[16];
  begin
    str(AValue,lText);
    while (length(lText)<5) do
     lText:='0'+lText;
    PadNumber:=lText;
  end;

  function CreateConst(AValue:Byte):String;
  begin
    if (AValue in [32..127]) and (AValue<>39) then
     CreateConst:=''''+chr(AValue)+''''
    else
     CreateConst:='#'+chr(AValue div 100+48)+chr((AValue mod 100) div 10+48)+chr(AValue mod 10+48)
  end;

var
  lOutputFile       : Text;
  lFile       : file;
  lColumnIndex,lIndex  : LongInt;
  lCursor       : PChar;
  lText       : String;
begin
  WriteLn('Writing charfile '+AFileName);
{Open textfile}
  assign(lOutputFile,AFileName);
  rewrite(lOutputFile);
  WriteLn(lOutputFile,'const ',AConstName,' : array[1..00000] of char=(');
{Parse buffer in msgbuf and create indexs}
  lCursor:=MsgTxt;
  lColumnIndex:=0;
  for lIndex:=1to MsgSize do
   begin
     if lColumnIndex=15 then
      begin
        if lColumnIndex>0 then
         WriteLn(lOutputFile,',')
        else
         WriteLn(lOutputFile,'');
        write(lOutputFile,'  ');
        lColumnIndex:=0;
      end
     else
      if lColumnIndex>0 then
        write(lOutputFile,',')
      else
        write(lOutputFile,'  ');
     write(lOutputFile,CreateConst(ord(lCursor^)));
     inc(lColumnIndex);
     inc(lCursor);
   end;
  WriteLn(lOutputFile,');');
  close(lOutputFile);
{update arraysize}
  lText:=PadNumber(MsgSize);
  assign(lFile,AFileName);
  reset(lFile,1);
  seek(lFile,18+length(AConstName));
  blockwrite(lFile,lText[1],5);
  close(lFile);
end;


{*****************************************************************************
                               WriteIntelFile
*****************************************************************************}

procedure WriteIntelFile(const AFileName,AConstName:String);
var
  lOutputFile      : Text;
  lLineLength,lIndex  : LongInt;
  lCursor      : PChar;
  lStart,
  lQuote  : Boolean;
begin
  WriteLn('Writing Intelfile ',AFileName);
{Open textfile}
  assign(lOutputFile,AFileName);
  rewrite(lOutputFile);
  WriteLn(lOutputFile,'procedure '+AConstName+';assembler;');
  WriteLn(lOutputFile,'asm');
{Parse buffer in msgbuf and create indexs}
  lCursor:=MsgTxt;
  lLineLength:=0;
  lStart:=true;
  lQuote:=false;
  for lIndex:=1to MsgSize do
   begin
     if lLineLength>70 then
      begin
        if lQuote then
         begin
           write(lOutputFile,'''');
           lQuote:=false;
         end;
        WriteLn(lOutputFile,'');
        lStart:=true;
      end;
     if lStart then
      begin
        write(lOutputFile,'  db ''');
        lLineLength:=0;
        lQuote:=true;
      end;
     if (ord(lCursor^)>=32) and (lCursor^<>#39) then
      begin
        if not lQuote then
         begin
           write(lOutputFile,',''');
           lQuote:=true;
           inc(lLineLength);
         end;
        write(lOutputFile,lCursor^);
        inc(lLineLength);
      end
     else
      begin
        if lQuote then
         begin
           write(lOutputFile,'''');
           inc(lLineLength);
           lQuote:=false;
         end;
        write(lOutputFile,','+chr(ord(lCursor^) div 100+48)+chr((ord(lCursor^) mod 100) div 10+48)+chr(ord(lCursor^) mod 10+48));
        inc(lLineLength,4);
      end;
     inc(lCursor);
   end;
  if lQuote then
   write(lOutputFile,'''');
  WriteLn(lOutputFile,'');
  WriteLn(lOutputFile,'end;');
  close(lOutputFile);
end;


{*****************************************************************************
                                RenumberFile
*****************************************************************************}

procedure RenumberFile(const AFileName,AName:String);
var
  lFile,lOutputFile  : Text;
  lIndex    : LongInt;
  lText,lText1 : String;
begin
  WriteLn('Renumbering ',AFileName);
{Read the message file}
  assign(lFile,AFileName);
  {$push} {$I-}
   reset(lFile);
  {$pop}
  if IOResult<>0 then
   begin
     WriteLn('*** message file '+AFileName+' not found ***');
     exit;
   end;
  assign(lOutputFile,'msg2inc.$$$');
  rewrite(lOutputFile);
  lIndex:=0;
  while not eof(lFile) do
   begin
     readln(lFile,lText);
     if (copy(lText,1,length(AName))=AName) and (lText[3] in ['0'..'9']) then
      begin
        inc(lIndex);
        str(lIndex,lText1);
        while length(lText1)<3 do
         lText1:='0'+lText1;
        WriteLn(lOutputFile,AName+lText1+Copy(lText,6,255));
      end
     else
      WriteLn(lOutputFile,lText);
   end;
  close(lOutputFile);
  close(lFile);
{ rename new file }
  erase(lFile);
  rename(lOutputFile,AFileName);
end;


{*****************************************************************************
                                WriteTexFile
*****************************************************************************}

Function EscapeString (Const AText : String) : String;
Var
  lIndex  : LongInt;
  lEscapedText : String;
begin
  lEscapedText:='';
  lIndex:=1;
  while lIndex<=length(AText) do
    begin
      case AText[lIndex] of
        '$' :
          if (AText[lIndex+1] in ['0'..'9']) then
            begin
              lEscapedText:=lEscapedText+'\textlangle arg. '+AText[lIndex+1]+'\textrangle{}';
              inc(lIndex);
            end
          else
            lEscapedText:=lEscapedText+'\$';
        '&','{','}','#','_','%':            // Escape these characters
          lEscapedText := lEscapedText + '\' + AText[lIndex];
        '~','^':
          lEscapedText := lEscapedText + '\'+AText[lIndex]+' ';
        '\':
          lEscapedText:=lEscapedText+'$\backslash$'
      else
        lEscapedText := lEscapedText + AText[lIndex];
      end;
      inc(lIndex);
    end;
  EscapeString:=lEscapedText;
end;

procedure WriteTexFile(const AInputFileName,AOutputFileName:String);
var
  lOutputFile,lFile   : Text;
  lLine,
  lIndex,lIndexK   : LongInt;
  lNumberText,
  lText,lText1  : String;
  lTexOutput : Boolean;
begin
  WriteLn('Loading messagefile ',AInputFileName);
  WriteLn('Writing TeXfile ',AOutputFileName);
{ Open infile }
  assign(lFile,AInputFileName);
  {$push} {$I-}
   reset(lFile);
  {$pop}
  if IOResult<>0 then
   begin
     WriteLn('*** message file '+AInputFileName+' not found ***');
     exit;
   end;
{ Open outfile }
  assign(lOutputFile,AOutputFileName);
  rewrite(lOutputFile);
  If TexHeader then
    begin
    WriteLn (lOutputFile,'\documentclass{article}');
    WriteLn (lOutputFile,'\usepackage{html}');
    WriteLn (lOutputFile,'\usepackage{fpc}');
    WriteLn (lOutputFile,'\begin{document}');
    end;
{ Parse }
  lLine:=0;
  lTexOutput:=False;
  while not eof(lFile) do
   begin
     readln(lFile,lText);
     inc(lLine);
     If Pos ('# BeginOfTeX',lText)=1 then
       lTexOutput:=True
     else if pos ('# EndOfTeX',lText)=1 then
       lTexOutput:=False;
     if (lText<>'') and not(lText[1] in ['#',';']) and lTexOutput then
      begin
        if lText[1]='%' then
         begin
           Delete(lText,1,1);
           WriteLn(lOutputFile,lText);
         end
        else
         begin
           lIndex:=pos('=',lText);
           if lIndex>0 then
            begin
              inc(lIndex);
              lNumberText:='';
              while lText[lIndex] in ['0'..'9'] do
               begin
                 lNumberText:=lNumberText+lText[lIndex];
                 inc(lIndex);
               end;
              { strip leading zeros }
              while lNumberText[1]='0' do
                Delete(lNumberText,1,1);
              inc(lIndex);
              lText1:='';
              lIndexK:=0;
              while (lIndexK<5) and (lText[lIndex+lIndexK]<>'_') do
               begin
                 case lText[lIndex+lIndexK] of
                  'W' : lText1:='Warning '+lNumberText+': ';
                  'E' : lText1:='Error '+lNumberText+': ';
                  'F' : lText1:='Fatal error '+lNumberText+': ';
                  'N' : lText1:='Note '+lNumberText+': ';
                  'I' : lText1:='Info '+lNumberText+': ';
                  'H' : lText1:='Hint '+lNumberText+': ';
                 end;
                 inc(lIndexK);
               end;
              if lText[lIndex+lIndexK]='_' then
               inc(lIndex,lIndexK+1);
              if lNumberText<>'' then
                WriteLn(lOutputFile,'\index[msgnr]{',lNumberText,'}');
              WriteLn(lOutputFile,'\index[msgtxt]{',EscapeString(Copy(lText,lIndex,255)),'}');
              WriteLn(lOutputFile,'\item ['+lText1+EscapeString(Copy(lText,lIndex,255))+'] \hfill \\');
            end
           else
            WriteLn('error in line: ',lLine,' skipping');
         end;
      end;
   end;
  If TexHeader then
    WriteLn (lOutputFile,'\end{document}');
  close(lOutputFile);
  close(lFile);
end;


{*****************************************************************************
                                Main Program
*****************************************************************************}

procedure GetPara;
var
  lChar      : Char;
  lArgument    : String;
  lFileCount,lIndex : Word;

  procedure HelpScreen;
  begin
    WriteLn('usage : msg2inc [Options] <msgfile> <incfile> <constname>');
    WriteLn('<Options> can be : -T     Create .doc TeX file');
    WriteLn('                   -TS    Create .doc TeX file (stand-alone)');
    WriteLn('                   -I     Intel style asm output');
    WriteLn('                   -S     array of string');
    WriteLn('                   -C     array of char');
    WriteLn('                   -R     renumber section <incfile>');
    WriteLn('                   -V     Show version');
    WriteLn('             -? or -H     This HelpScreen');
    halt(1);
  end;

begin
  lFileCount:=0;
  for lIndex:=1 to paramcount do
   begin
     lArgument:=ParamStr(lIndex);
     if (lArgument[1]='-') then
      begin
        lChar:=upcase(lArgument[2]);
        delete(lArgument,1,2);
        case lChar of
         'T' : begin
                 case upcase(lArgument[1]) of
                  'S' : TexHeader:=True;
                 end;
                 Mode:=ModeTex;
               end;
         'I' : Mode:=ModeIntel;
         'S' : Mode:=ModeString;
         'C' : Mode:=ModeChar;
         'R' : Mode:=ModeRenumber;
         'V' : begin
                 WriteLn('Msg2Inc ',cVersion,' for Free Pascal (C) 1998-2002 Peter Vreman');
                 WriteLn;
                 Halt;
               end;
     '?','H' : HelpScreen;
        end;
     end
    else
     begin
       inc(lFileCount);
       if lFileCount>3 then
        HelpScreen;
       case lFileCount of
        1 : InFile:=lArgument;
        2 : OutFile:=lArgument;
        3 : OutName:=lArgument;
       end;
     end;
   end;
  case Mode of
   ModeRenumber,
        ModeTex : if lFileCount<2 then
                 HelpScreen;
  else
   if lFileCount<3 then
    HelpScreen;
  end;
end;


begin
  Mode:=ModeString;
  OutFile:='';
  InFile:='';
  OutName:='';
  GetPara;
  case Mode of
   ModeRenumber : begin
                  RenumberFile(InFile,OutFile);
                end;
        ModeTex : begin
                  WriteTexFile(InFile,OutFile);
                end;
      ModeIntel : begin
                  LoadMsgFile(InFile);
                  WriteEnumFile(OutFile+'idx.inc');
                  WriteIntelFile(OutFile+'txt.inc',OutName+'txt');
                end;
     ModeString : begin
                  LoadMsgFile(InFile);
                  WriteEnumFile(OutFile+'idx.inc');
                  WriteStringFile(OutFile+'txt.inc',OutName+'txt');
                end;
       ModeChar : begin
                  LoadMsgFile(InFile);
                  WriteEnumFile(OutFile+'idx.inc');
                  WriteCharFile(OutFile+'txt.inc',OutName+'txt');
                end;
  end;
end.
