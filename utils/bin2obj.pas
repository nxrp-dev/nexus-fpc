program Bin2Obj;
{
    This file is part of the Free Pascal run time library.
    Copyright (c) 1999-2000 by Michael Van Canneyt, member of the
    Free Pascal development team

    Binary file to include file converter.

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

{$mode objfpc}

uses Classes,GetOpts, IOStream,ZStream,IDEA,SysUtils,Dos;

var
  ConstName,
  OutFileName,
  UnitName : String;
  WriteAsciiData,
  CompressData,
  EncodeData,
  CompileUnit,
  WriteHex : Boolean;
  CryptKey : IDEACryptKey;
  InStream,
  MemStream,
  CryptStream,
  CompStream : TStream;

Procedure Usage;

begin
  WriteLn ('Usage: bin2obj [options] -c constname [infile] ');
  WriteLn ('Where options is a combination of : ');
  WriteLn ('   -a        write asciii data instead of bytes');
  WriteLn ('   -x        write numerical values as hexadecimal numbers');
  WriteLn ('   -z        compress data.');
  WriteLn ('   -e key    encrypt data with key (must have 8 characters)');
  WriteLn ('   -o        output filename');
  WriteLn ('   -u [name] make a unit instead of an include file (unit name is outfile)');
  WriteLn ('   -U [name] same as -u, and compile the unit. (requires outfile)');
  Halt(1);
end;

Procedure ProcessCommandLine;

Var C : Char;
    I : LongInt;
    NeedUnitName : Boolean;

begin
  OptErr:=False;
  ConstName:='';
  CompressData:=False;
  EncodeData:=False;
  CompileUnit:=False;
  UnitName:='';
  NeedUnitName:=False;
  WriteAsciiData:=False;
  WriteHex:=False;
  Repeat
    C:=GetOpt('ac:e:o:zhu::U::x');
    Case C of
      'a' : WriteAsciiData:=True;
      'c' : ConstName:=OptArg;
      'h','?' : Usage;
      'z' : CompressData := True;
      'x' : WriteHex := True;
      'e' : begin
            EncodeData:=True;
            If Length(OptArg)<8 then
              Usage;
            For I:=0 to 7 do
              CryptKey[I]:=Ord(OptArg[I+1]);
            end;
      'o' : OutFileName:=OptArg;
      'u','U':
            begin
            UnitName:=OptArg;
            If Length(UnitName)=0 then
              NeedUnitName:=True;
            If C='U' then
              CompileUnit:=True;
            end;
    end;
  until C=EndOfOptions;
  if ConstName='' then
    Usage;
  If NeedUnitName then
    If Length (OutFileName)=0 then
      begin
      WriteLn ('Error : cannot determine unitname from filename');
      Usage;
      end
    else
      UnitName:=ExtractFileName(OutFileName);
  if CompileUnit and (Length(OutFileName)=0) then
    Usage;
end;

Function SetupInput : TStream;

begin
  if OptInd=ParamCount then
    InStream:=TFileStream.Create(ParamStr(OptInd),fmOpenRead)
  else
    InStream:=TIOStream(iosInput);
  Result:=InStream;
end;

Function SetupOutput : TStream;

Var Key : IDEAKey;

begin
  MemStream:=TMemoryStream.Create;
  Result:=MemStream;
  If CompressData then
    begin
    CompStream:=TCompressionStream.Create(clDefault,Result);
    Result:=CompStream;
    end;
  if EncodeData Then
    begin
    EnKeyIDEA(CryptKey,Key);
    CryptStream:=TIDEAEncryptStream.Create(Key,Result);
    Result:=CryptStream;
    end;
end;

Procedure CopyStreams (Ins,Outs : TStream);

Const BufSize = 1024;

Var Buffer : Array[1..BufSize] of Byte;
    Count : LongInt;

begin
  repeat
     Count:=Ins.Read(Buffer,SizeOf(Buffer));
      If Count>0 then
       Outs.Write(Buffer,Count);
  until Count<SizeOf(Buffer);
  {
    freeing these streams will flush their buffers.
    Order is important !!!
  }
  CryptStream.Free;
  CompStream.Free;
  // Now Out stream has all data.
end;

Procedure WriteMemStream;

Var OutStream : TStream;

  Procedure WriteStr(Const St : String);

  begin
    OutStream.Write(St[1],Length(St));
  end;

  Procedure WriteStrLn(Const St : String);

  Const
  {$ifdef unix}
     Eoln : String = #10;
  {$else}
     Eoln : String = #13#10;
  {$endif}

  begin
    OutStream.Write(St[1],Length(St));
    OutStream.Write(Eoln[1],Length(Eoln));
  end;

Const Prefix = '     ';
      MaxLineLength = 72;

Var I,Count  : LongInt;
    B    : Byte;
    Line,ToAdd : String;

begin
  If Length(OutFileName)=0 Then
    OutStream:=TIOStream.Create(iosOutput)
  else
    OutStream:=TFileStream.Create(OutFileName,fmCreate);
  If UnitName<>'' then
    begin
    WriteStrLn(Format('Unit %s;',[UnitName]));
    WriteStrLn('');
    WriteStrLn('Interface');
    WriteStrLn('');
    end;
  WriteStrLn('');
  WriteStrLn('Const');
  MemStream.Seek(0,soFromBeginning);
  Count:=MemStream.Size;
  If WriteAsciiData then
    WriteStrLn(Format('  %s : Array[0..%d] of char = (',[ConstName,Count-1]))
  else
    WriteStrLn(Format('  %s : Array[0..%d] of byte = (',[ConstName,Count-1]));
  Line:=Prefix;
  For I:=1 to Count do
    begin
    MemStream.Read(B,1);
    If Not WriteAsciiData then
       begin
         if WriteHex then
           ToAdd:=Format('$%2.2x',[B])
         else
           ToAdd:=Format('%3d',[B]);
       end
    else
      If (B in [32..127]) and not (B in [10,13,39]) then
        ToAdd:=''''+Chr(B)+''''
      else
//        ToAdd:=Format('''%s''',[Chr(b)]);
        begin
          if WriteHex then
            ToAdd:=Format('#$%x',[B])
          else
            ToAdd:=Format('#%d',[B]);
        end;
    If I<Count then
      ToAdd:=ToAdd+',';
    Line:=Line+ToAdd;
    If Length(Line)>=MaxLineLength Then
      begin
      WriteStrLn(Line);
      Line:=Prefix;
      end;
    end;
  WriteStrLn(Line+');');
  If Length(UnitName)<>0 then
    begin
    WriteStrLn('');
    WriteStrLn('Implementation');
    WriteStrLn('');
    WriteStrLn('end.')
    end;
  MemStream.Free;
end;

Procedure CompileTheUnit;

begin
  Exec('ppc386',' -Un '+UnitName);
end;

begin
  ProcessCommandLine;
  CopyStreams(SetupInput,SetupOutput);
  WriteMemStream;
  If CompileUnit then
    CompileTheUnit;
end.
