{
    This file is part of the Free Pascal run time library.
    Copyright (c) 1999-2000 by Sebastian Guenther
    Added .rc and OS/2 MSG support in 2002 by Yuri Prokushev

    .rst resource string table file converter.

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
{$MODE objfpc}
{$H+}

program RstConv;

uses
{$ifdef unix}
  CWString,
{$endif}
  SysUtils, Classes, JSONParser, FPJSON, CharSet, CPAll;

resourcestring
  Help =
    'rstconv [-h|--help]    Displays this help'+LineEnding+
    'rstconv options        Convert .rsj/.rst file'+LineEnding+LineEnding+
    'Options are:'+LineEnding+
    '  -i file        Use specified file instead of stdin as input .rsj/.rst (OPTIONAL)'+LineEnding+
    '  -o file        Write output to specified file (REQUIRED)'+LineEnding+
    '  -f format      Specifies the output format:'+LineEnding+
    '                 po    GNU gettext .po (portable) format (DEFAULT)'+LineEnding+
    '                 msg   IBM OS/2 MSG file format'+LineEnding+
    '                 rc    Resource compiler .rc format'+LineEnding+LineEnding+
    '.po format only options are:'+LineEnding+
    '  -c char set    Adds a header specifying the given character set (OPTIONAL).'+LineEnding+LineEnding+
    'OS/2 MSG file only options are:'+LineEnding+
    '  -c identifier  Specifies the component identifier (REQUIRED).'+LineEnding+
    '                 Identifier is any three chars in upper case.'+LineEnding+
    '  -n number      Specifies the first message number [1-9999] (OPTIONAL).'+LineEnding+LineEnding+
    'Resource compiler script only options are:'+LineEnding+
    '  -s             Use STRINGTABLE instead of MESSAGETABLE'+LineEnding+
    '  -c identifier  Use identifier as ID base (ID+n) (OPTIONAL)'+LineEnding+
    '  -n number      Specifies the first ID number (OPTIONAL)'+LineEnding+
    '.rsj-input format-only options are:'+LineEnding+
    '  -p codepage    Convert the string data to the specified code page before'+LineEnding+
    '                 writing it to the output file. Possible values:';


  InvalidOption = 'Invalid option - ';
  RequiredOption = 'Required option is absent - ';
  OptionAlreadySpecified = 'Option has already been specified - ';
  NoOutFileName = 'No output filename specified';
  InvalidOutputFormat = 'Invalid output format -';
  MessageNumberTooBig = 'Message number too big';
  InvalidRange = 'Invalid range of the first message number';
  MissingOption = 'Missing option after parameter ';
  UnsupportedOutputCodePage = 'Unsupported output code page specified: ';
  RstNoOutputCodePage = 'It is not possible to specify an output code page when using a .rst file';

type

  TConstItem = class(TCollectionItem)
  public
    ModuleName, ConstName, Value: String;
  end;

var
  InFileName, OutFileName: String;
  ConstItems: TCollection;
  HeaderCharSet: String;
  Identifier: String;
  OutputCodePage: LongInt;
  FirstMessage: Word;
  MessageTable: Boolean;

procedure ReadRSTFile;
var
  F: Text;
  S: String;
  Item: TConstItem;
  DotPos, EqPos, I, J: Integer;
begin
  Assign(F, InFileName);
  Reset(F);

  while not EOF(F) do begin
    ReadLn(F, S);
    If (Length(S)=0) or (S[1]='#') then
      continue;
    Item := TConstItem(ConstItems.Add);

    DotPos := Pos('.', S);
    EqPos := Pos('=', S);
    if DotPos > EqPos then // paranoia checking.
      DotPos := 0;
    Item.ModuleName := Copy(S, 1, DotPos - 1);
    Item.ConstName := Copy(S, DotPos + 1, EqPos - DotPos - 1);

    Item.Value := '';
    I := EqPos + 1;
    while I <= Length(S) do begin
      if S[I] = '''' then begin
        Inc(I);
        J := I;
        while (I <= Length(S)) and (S[I] <> '''') do
          Inc(I);
        Item.Value := Item.Value + Copy(S, J, I - J);
        Inc(I);
      end else if S[I] = '#' then begin
        Inc(I);
        J := I;
        while (I <= Length(S)) and (S[I] in ['0'..'9']) do
          Inc(I);
        Item.Value := Item.Value + Chr(StrToInt(Copy(S, J, I - J)));
      end else if S[I] = '+' then begin
        ReadLn(F, S);
        I := 1;
      end else
        Inc(I);
    end;
  end;

  Close(F);
end;

procedure ReadRSJFile;
var
  Stream: TFileStream;
  Parser: TJSONParser;
  JSONItems,
  RawStringData: TJSONArray;
  JSONData, JSONItem: TJSONObject;
  S: String;
  Item: TConstItem;
  DotPos, I, J: Integer;
begin
  if OutputCodePage<>-1 then
    DefaultSystemCodePage:=OutputCodePage;
  Stream := TFileStream.Create(InFileName, fmOpenRead or fmShareDenyNone);
  Parser := TJSONParser.Create(Stream);
  try
    JSONData := Parser.Parse as TJSONObject;
    try
      JSONItems := JSONData.Arrays['strings'];
      for I := 0 to JSONItems.Count - 1 do
      begin
        Item := TConstItem(ConstItems.Add);
        JSONItem := JSONItems.Items[I] as TJSONObject;
        S := JSONItem.Get('name');
        DotPos := Pos('.', S);
        Item.ModuleName := Copy(S, 1, DotPos - 1);
        Item.ConstName := Copy(S, DotPos + 1, Length(S) - DotPos);
        if OutputCodePage=-1 then
          begin
            RawStringData:=JSONItem.Get('sourcebytes',TJSONArray(nil));
            SetLength(Item.Value, RawStringData.Count);
            for J := 1 to Length(Item.Value) do
              Item.Value[J]:=Char(RawStringData.Integers[J-1]);
          end
        else
          { automatically converts from UTF-16 to the correct code page due
            to the change of DefaultSystemCodePage to OutputCodePage above }
          Item.Value := JSONItem.Get('value');
      end;
    finally
      JSONData.Free;
    end;
  finally
    Parser.Free;
    Stream.Free;
  end;
end;

procedure ConvertToGettextPO;
var
  I, J: Integer;
  F: Text;
  Item: TConstItem;
  S: String;
  C: Char;

begin
  Assign(F, OutFileName);
  Rewrite(F);

  if HeaderCharSet<>'' then begin
    // Write file header  with
    WriteLn(F, 'msgid ""');
    WriteLn(F, 'msgstr ""');
    WriteLn(F, '"MIME-Version: 1.0\n"');
    WriteLn(F, '"Content-Type: text/plain; charset=', HeaderCharSet, '\n"');
    WriteLn(F, '"Content-Transfer-Encoding: 8bit\n"');
    WriteLn(F);
  end;

  for I := 0 to ConstItems.Count - 1 do begin
    Item := TConstItem(ConstItems.Items[I]);

    // Convert string to C-style syntax
    S := '';
    for J := 1 to Length(Item.Value) do begin
      C := Item.Value[J];
      case C of
        #9:  S := S + '\t';
        #10: S := S + '\n';
{$IFNDEF UNIX}
        #13: ;
        #1..#8, #11..#12, #14..#31, #128..#255:
{$ELSE}
        #1..#8, #11..#31, #128..#255:
{$ENDIF}
          S := S + '\' +
            Chr(Ord(C) shr 6 + 48) +
            Chr((Ord(C) shr 3) and 7 + 48) +
            Chr(Ord(C) and 7 + 48);
        '\': S := S + '\\';
        '"': S := S + '\"';
      else S := S + C;
      end;
    end;

    // Write msg entry
    WriteLn(F, '#: ', Item.ModuleName, ':', Item.ConstName);
    J := Pos('\n', S);
    if J > 0 then begin
      WriteLn(F, 'msgid ""');
      while J > 0 do begin
        WriteLn(F, '"',Copy(S, 1, J+1),'"');
        Delete(S, 1, J+1);
        J := Pos('\n', S);
      end;
      if S <> '' then
        WriteLn(F, '"',S,'"');
    end
    else
      WriteLn(F, 'msgid "', S, '"');
    WriteLn(F, 'msgstr ""');
    WriteLn(F);
  end;

  Close(F);
end;

// This routine stores rst file in rc format. Can be written as MESSAGETABLE
// as STRINGTABLE. Beware! OS/2 RC doesn't support lines longer than 255 chars.
procedure ConvertToRC;
var
  I, J: Integer;
  F: Text;
  Item: TConstItem;
  S: String;
  C: Char;

begin
  Assign(F, OutFileName);
  Rewrite(F);

  If MessageTable then
    WriteLn(F, 'MESSAGETABLE')
  else
    WriteLn(F, 'STRINGTABLE');

  WriteLn(F, 'BEGIN');
  If Identifier<>'' then WriteLn(F, '#define ', Identifier);

  for I := 0 to ConstItems.Count - 1 do begin
    Item := TConstItem(ConstItems.Items[I]);

    // Convert string to C-style syntax
    S := '';
    for J := 1 to Length(Item.Value) do begin
      C := Item.Value[J];
      case C of
        #9:  S := S + '\t';
        #10: S := S + '\n"'#13#10'"';
{$IFNDEF UNIX}
        #13: ;
        #1..#8, #11..#12, #14..#31, #128..#255:
{$ELSE}
        #1..#8, #11..#31, #128..#255:
{$ENDIF}
          S := S + '\' +
            Chr(Ord(C) shr 6 + 48) +
            Chr((Ord(C) shr 3) and 7 + 48) +
            Chr(Ord(C) and 7 + 48);
        '\': S := S + '\\';
        '"': S := S + '\"';
      else S := S + C;
      end;
    end;

    // Write msg entry
    WriteLn(F, '/* ', Item.ModuleName, ':', Item.ConstName, '*/');
    WriteLn(F, '/* ', S, ' */');
    If Identifier<>'' then Write(F, Identifier, '+');
    WriteLn(F, I+FirstMessage,' "', S, '"');
    WriteLn(F);
  end;

  WriteLn(F, 'END');
  Close(F);
end;

// This routine stores rst file in OS/2 msg format. This format is preffered
// for help screens, messages, etc.
procedure ConvertToOS2MSG;
var
  I, J: Integer;
  F: Text;
  Item: TConstItem;
  S: String;
begin
  If (ConstItems.Count+FirstMessage-1)>9999 then
  begin
    WriteLn(MessageNumberTooBig);
    Halt(1);
  end;

  Identifier:=Copy(UpperCase(Identifier), 1, 3);

  Assign(F, OutFileName);
  Rewrite(F);

  WriteLn(F, Identifier);

  // Fake entry, because MKMSGF limitation
  WriteLn(F, Format('%s%.4d?: ',[Identifier, FirstMessage-1]));

  for I := 0 to ConstItems.Count - 1 do begin
    Item := TConstItem(ConstItems.Items[I]);

    // Prepare comment string
    // Convert string to C-style syntax
    S := '';
    J:=1;
    while J<=Length(Item.Value) do
    begin
      if Copy(Item.Value, J, 2)=#13#10 then
      begin
        S:=S+#13#10';';
        Inc(J, 2);
      end else begin
        S := S + Item.Value[J];
        Inc(J);
      end;
    end;

    // Write msg entry
    WriteLn(F, ';', Item.ModuleName, '.', Item.ConstName);
    WriteLn(F, Format(';%s%.4dP: %s %%0',[Identifier, I+FirstMessage, S]));
    WriteLn(F, Format('%s%.4dP: %s %%0',[Identifier, I+FirstMessage, Item.Value]));
  end;

  Close(F);
end;

type
  TConversionProc = procedure;
var
  I: Integer;
  ConversionProc: TConversionProc;
  OutputFormat: String;
begin

  if (ParamStr(1) = '-h') or (ParamStr(1) = '--help') then begin
    WriteLn(Help);
    for I:=Low(Word) to High(Word) do
      if MappingAvailable(I) then
        WriteLn('                   ',GetMap(I)^.CPName);
    { UTF-8 is not supported via the CharSet unit }
    WriteLn('                   UTF-8');
    exit;
  end;

  ConversionProc := @ConvertToGettextPO;
  OutputFormat:='';
  HeaderCharSet:='';
  Identifier:='';
  FirstMessage:=0;
  MessageTable:=True;
  OutputCodePage:=-1;

  I := 1;
  while I <= ParamCount do begin
    if ParamStr(I) = '-i' then begin
      if InFileName <> '' then begin
        WriteLn(StdErr, OptionAlreadySpecified, '-i');
        Halt(1);
      end;
      InFileName := ParamStr(I + 1);
      Inc(I, 2);
    end else if ParamStr(I) = '-o' then begin
      if OutFileName <> '' then begin
        WriteLn(StdErr, OptionAlreadySpecified, '-o');
        Halt(1);
      end;
      OutFileName := ParamStr(I + 1);
      Inc(I, 2);
    end else if ParamStr(I) = '-f' then begin
      if OutputFormat <> '' then begin
        WriteLn(StdErr, OptionAlreadySpecified, '-f');
        Halt(1);
      end;
      if ParamStr(I + 1) = 'po' then
        OutputFormat:='po'
      else if ParamStr(I + 1) = 'msg' then begin
        OutputFormat:='msg';
        ConversionProc := @ConvertToOS2MSG;
      end else if ParamStr(I + 1) = 'rc' then begin
        OutputFormat:='rc';
        ConversionProc := @ConvertToRC;
      end else begin
        WriteLn(StdErr, InvalidOutputFormat, ParamStr(I + 1));
        Halt(1);
      end;
      Inc(I, 2);
    end else if ParamStr(I) = '-c' then begin
      if (OutputFormat='') or (OutputFormat='po') then begin
        if HeaderCharSet <> '' then begin
          WriteLn(StdErr, OptionAlreadySpecified, '-c');
          Halt(1);
        end;
        HeaderCharSet:=ParamStr(I+1);
      end else
      begin
        if Identifier <> '' then begin
          WriteLn(StdErr, OptionAlreadySpecified, '-c');
          Halt(1);
        end;
        Identifier:=ParamStr(I+1);
      end;
      Inc(I, 2);
    end else if ParamStr(I) = '-s' then begin
      if not MessageTable then begin
        WriteLn(StdErr, OptionAlreadySpecified, '-s');
        Halt(1);
      end;
      MessageTable:=False;
      Inc(I);
    end else if ParamStr(I) = '-n' then begin
      if FirstMessage <> 0 then begin
        WriteLn(StdErr, OptionAlreadySpecified, '-n');
        Halt(1);
      end;
      try
        FirstMessage := StrToInt(ParamStr(I + 1));
        If (FirstMessage<1) then raise EConvertError.Create(InvalidRange+' '+ParamStr(I+1));
      except
        on EConvertError do
        begin
          WriteLn(StdErr, InvalidOption, ParamStr(I));
          Halt(1);
        end;
      end;
      Inc(I, 2);
    end else if ParamStr(I) = '-p' then
      begin
        if ParamCount=I then
          begin
            WriteLn(StdErr, MissingOption,'-p');
            Halt(1)
          end;
        if UpperCase(ParamStr(I+1))<>'UTF-8' then
          if not MappingAvailable(ParamStr(I+1)) then
            begin
              WriteLn(StdErr, UnsupportedOutputCodePage, ParamStr(I+1));
              Halt(1);
            end
          else
            OutputCodePage:=GetMap(ParamStr(I+1))^.CP
        else
          OutputCodePage:=CP_UTF8;
        Inc(I, 2);
      end
    else begin
      WriteLn(StdErr, InvalidOption, ParamStr(I));
      Halt(1);
    end;
  end;

  If ((OutputFormat<>'') and (OutputFormat<>'po')) and (HeaderCharSet<>'')  then begin
    WriteLn(StdErr, InvalidOption, '');
    Halt(1);
  end;

  If ((OutputFormat<>'msg') and (OutputFormat<>'rc')) and ((Identifier<>'') or (FirstMessage<>0)) then begin
    WriteLn(StdErr, InvalidOption, '');
    Halt(1);
  end;

  If (OutputFormat='msg') and (Identifier='') then begin
    WriteLn(StdErr, RequiredOption, '-c');
    Halt(1);
  end;

  if OutFileName = '' then begin
    WriteLn(StdErr, NoOutFileName);
    Halt(1);
  end;

  ConstItems := TCollection.Create(TConstItem);

  if ExtractFileExt(InFileName) = '.rsj' then
    ReadRSJFile
  else
    begin
      if OutputCodePage<>-1 then
        begin
          WriteLn(StdErr, RstNoOutputCodePage);
          Halt(1);
        end;
      ReadRSTFile;
    end;

  ConversionProc;
end.
