(******************************************************************************
 *                                                                            *
 *  (c) 2007 Hexis BV                                                         *
 *                                                                            *
 *  File:        Base64DecodingTestCase.pas                                   *
 *  Author:      Bram Kuijvenhoven (bkuijvenhoven@hexis.nl)                   *
 *  Description: FPCUnit tests for Base64.TBase64DecodingStream               *
 *                                                                            *
 ******************************************************************************)

unit Base64DecodingTestCase;

{$mode objfpc}{$H+}

interface

uses
  obNXTestContext, obNXTestRegistry, obNXTestSuite, Classes, SysUtils, base64;

type

  { TBase64DecodingStreamTestCase }

  TBase64DecodingStreamTestCase = class(TObject)
  private
    FContext: TNXTestContext;
    FCaseName: string;
  protected
    property TestContext: TNXTestContext read FContext;
    property CaseName: string read FCaseName;
  public
    constructor Create(AContext: TNXTestContext; const ACaseName: string);
  private
    Base64Stream: TBase64DecodingStream;
    SourceStream: TStream;
  protected
    procedure SetUp; virtual;
    procedure TearDown; virtual;
    // utility
    procedure WriteToSourceStream(s:AnsiString);
    function NoiseCharString:ansistring; // all non-base64 alphabet characters
    function RandomNoise(l:integer):ansistring; // l random non-base64 alphabet characters
    // test templates
    procedure TestGetSize(mode:TBase64DecodingMode; s:AnsiString; expectedSize:Int64);
    procedure TestDecode (mode:TBase64DecodingMode; s, expected: AnsiString);
    procedure TestReset  (mode:TBase64DecodingMode; s:AnsiString; start:array of Int64; expected:array of ansistring);
  public
    procedure TestGetSizeStrict1;
    procedure TestGetSizeStrict2;
    procedure TestGetSizeStrict3;
    procedure TestGetSizeStrict4;
    procedure TestGetSizeStrict5;
    procedure TestGetSizeMIME01;
    procedure TestGetSizeMIME02;
    procedure TestGetSizeMIME03;
    procedure TestGetSizeMIME04;
    procedure TestGetSizeMIME05;
    procedure TestGetSizeMIME06;
    procedure TestGetSizeMIME07;
    procedure TestGetSizeMIME08;
    procedure TestGetSizeMIME09;
    procedure TestGetSizeMIME10;
    procedure TestGetSizeMIME11;
    procedure TestGetSizeMIME12;
    procedure TestGetSizeMIME13;
    procedure TestGetSizeMIME14;
    procedure TestGetSizeMIME15;
    procedure TestGetSizeMIME16;
    procedure TestGetSizeMIME17;
    procedure TestGetSizeMIME18;
    procedure TestGetSizeMIME19;
    procedure TestGetSizeMIME20;
    procedure TestGetSizeMIME21;
    procedure TestGetSizeMIME22;
    procedure TestDecodeStrict01;
    procedure TestDecodeStrict02;
    procedure TestDecodeStrict03;
    procedure TestDecodeStrict04;
    procedure TestDecodeStrict05;
    procedure TestDecodeStrict06;
    procedure TestDecodeStrict07;
    procedure TestDecodeStrict08;
    procedure TestDecodeStrict09;
    procedure TestDecodeStrict10;
    procedure TestDecodeMIME1;
    procedure TestDecodeMIME2;
    procedure TestDecodeMIME3;
    procedure TestDecodeMIME4;
    procedure TestDecodeMIME5;
    procedure TestDecodeMIME6;
    procedure TestDecodeMIME7;
    procedure TestDecodeMIME8;
    procedure TestDecodeMIME9;
    procedure TestResetStrict1;
    procedure TestResetStrict2;
    procedure TestResetStrict3;
    procedure TestResetMIME1;
    procedure TestResetMIME2;
    procedure TestResetMIME3;
  end;

procedure RegisterBase64DecodingTestCaseTests(ARegistry: TNXTestRegistry);

implementation

uses
  Math;

// utility routines
type
  TChars = set of AnsiChar;

function SetToString(chars:TChars):ansistring;
var
  pos: Integer;
  c: AnsiChar;
begin
  pos:=0;
  SetLength(Result,256);
  for c:=#0 to #255 do
    if c in chars then begin
      Inc(pos);
      Result[pos]:=c;
    end;
  SetLength(Result,pos);
end;

function Shuffle(s: ansistring): ansistring;
var
  i: Integer;
  randomPos: Integer;
  c: AnsiChar;
begin
  UniqueString(s);
  for i:=1 to Length(s) do begin
    randomPos:=Random(Length(s))+1;
    c:=s[randomPos];
    s[randomPos]:=s[i];
    s[i]:=c;
  end;
  Result:=s;
end;

// order preserving shuffle
function Merge(s,t: ansistring): ansistring;
var
  si: Integer;
  ti: Integer;
  sLeft: Integer;
  tLeft: Integer;
  chooseS: Boolean;
  ri: Integer;
  count: LongInt;
  i: Integer;
begin
  si := 1;
  ti := 1;
  ri := 1;
  sLeft := Length(s);
  tLeft := Length(t);
  SetLength(Result, sLeft + tLeft);
  while (sLeft>0) or (tLeft>0) do begin
    chooseS := Random(sLeft + tLeft) < sLeft;
    if chooseS then begin
      count := Min(Random(7)+1, sLeft);
      for i := 0 to count - 1 do
        Result[ri + i] := s[si + i];
      Inc(ri, count);
      Inc(si, count);
      Dec(sLeft, count);
    end else begin
      count := Min(Random(7)+1, tLeft);
      for i := 0 to count - 1 do
        Result[ri + i] := t[ti + i];
      Inc(ri, count);
      Inc(ti, count);
      Dec(tLeft, count);
    end;
  end;
end;

procedure TBase64DecodingStreamTestCase.SetUp;
begin
  SourceStream := TMemoryStream.Create;
  Base64Stream := TBase64DecodingStream.Create(SourceStream);
end;

procedure TBase64DecodingStreamTestCase.TearDown;
begin
  FreeAndNil(Base64Stream);
  FreeAndNil(SourceStream);
end;

procedure TBase64DecodingStreamTestCase.WriteToSourceStream(s: ansistring);
begin
  SourceStream.Write(s[1],Length(s));
  SourceStream.Position:=0;
end;

function TBase64DecodingStreamTestCase.NoiseCharString: ansistring;
begin
  Result:=SetToString([#0..#255]-['a'..'z','A'..'Z','0'..'9','+','/','=']);
end;

function TBase64DecodingStreamTestCase.RandomNoise(l: integer): ansistring;
var
  i: Integer;
  noiseChars: ansistring;
begin
  noiseChars:=NoiseCharString; // our pool
  SetLength(Result,l);
  for i:=1 to l do
    Result[i]:=noiseChars[Random(Length(noiseChars))+1];
end;

procedure TBase64DecodingStreamTestCase.TestGetSize(mode:TBase64DecodingMode; s: ansistring; expectedSize: Int64);
var
  Size: Int64;
begin
  Base64Stream.Mode := mode;
  WriteToSourceStream(s);
  Size := Base64Stream.Size;
  TestContext.AssertTrue((Size)=(expectedSize), 'Correct size calculated by Size getter');
end;

procedure TBase64DecodingStreamTestCase.TestDecode(mode: TBase64DecodingMode; s, expected: AnsiString);
var
  Buf: array[0..63] of AnsiChar;
  si: Integer;
  i: Integer;
  count: LongInt;
begin
  writeln(Length(s),'->',Length(expected));
  Base64Stream.Mode := mode;
  WriteToSourceStream(s);
  si := 1;  // index into expected
  repeat
    count := Base64Stream.Read(Buf, Random(SizeOf(Buf))+1);
    TestContext.AssertTrue(si + count - 1 <= Length(expected), 'Not too many bytes decoded');
    for i := 0 to count-1 do
      TestContext.AssertTrue((expected[si + i])=(Buf[i]), 'Correctly decoded byte');
    Inc(si, count);
    TestContext.AssertTrue((Length(expected))=(Base64Stream.Size), 'Returned size is correct');
  until Base64Stream.EOF;
  TestContext.AssertTrue((Length(expected))=(si-1), 'Correct decoded length');
end;

procedure TBase64DecodingStreamTestCase.TestReset(mode: TBase64DecodingMode; s: ansistring; start: array of Int64; expected: array of ansistring);
var
  Buf: array[0..63] of AnsiChar;
  len: Integer;
  i: Integer;
  count: LongInt;
  startI: Integer;
begin
  Base64Stream.Mode := mode;
  WriteToSourceStream(s);
  TestContext.AssertTrue((Length(start))=(Length(expected)), 'start and expected arrays have same length');
  for startI := 0 to High(start) do begin
    SourceStream.Position := start[startI];
    Base64Stream.Reset;
    // test decoding
    len := 0;
    repeat
      count := Base64Stream.Read(Buf, Random(SizeOf(Buf))+1);
      TestContext.AssertTrue(len + count <= Length(expected[startI]), 'Not too many bytes decoded');
      for i := 0 to count-1 do
        TestContext.AssertTrue((expected[startI][len + i + 1])=(Buf[i]), Format('Correctly decoded byte at %d',[len+i]));
      Inc(len, count);
      TestContext.AssertTrue((Length(expected[startI]))=(Base64Stream.Size), 'Returned size is correct');
    until Base64Stream.EOF;
    TestContext.AssertTrue((Length(expected[startI]))=(len), 'Correct decoded length');
  end;
end;

procedure TBase64DecodingStreamTestCase.TestGetSizeStrict1; begin TestGetSize(bdmStrict,'',0); end;
procedure TBase64DecodingStreamTestCase.TestGetSizeStrict2; begin TestGetSize(bdmStrict,'aAzZ09+/',6); end;
procedure TBase64DecodingStreamTestCase.TestGetSizeStrict3; begin TestGetSize(bdmStrict,'aAzZ09+=',5); end;
procedure TBase64DecodingStreamTestCase.TestGetSizeStrict4; begin TestGetSize(bdmStrict,'aAzZ09==',4); end;
procedure TBase64DecodingStreamTestCase.TestGetSizeStrict5; begin TestGetSize(bdmStrict,'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789+/',48); end;
procedure TBase64DecodingStreamTestCase.TestGetSizeMIME01; begin TestGetSize(bdmMIME,'',0); end;
procedure TBase64DecodingStreamTestCase.TestGetSizeMIME02; begin TestGetSize(bdmMIME,NoiseCharString,0); end;
procedure TBase64DecodingStreamTestCase.TestGetSizeMIME03; begin TestGetSize(bdmMIME,Shuffle(NoiseCharString),0); end;
procedure TBase64DecodingStreamTestCase.TestGetSizeMIME04; begin TestGetSize(bdmMIME,Shuffle(RandomNoise(12))+'=',0); end;
procedure TBase64DecodingStreamTestCase.TestGetSizeMIME05; begin TestGetSize(bdmMIME,Shuffle(NoiseCharString)+'==',0); end;
procedure TBase64DecodingStreamTestCase.TestGetSizeMIME06; begin TestGetSize(bdmMIME,Shuffle(RandomNoise(13))+'===',0); end;
procedure TBase64DecodingStreamTestCase.TestGetSizeMIME07; begin TestGetSize(bdmMIME,Shuffle(NoiseCharString)+'====',0); end;
procedure TBase64DecodingStreamTestCase.TestGetSizeMIME08; begin TestGetSize(bdmMIME,Shuffle(RandomNoise(14))+'a=',0); end;
procedure TBase64DecodingStreamTestCase.TestGetSizeMIME09; begin TestGetSize(bdmMIME,Shuffle(NoiseCharString)+'ab==',1); end;
procedure TBase64DecodingStreamTestCase.TestGetSizeMIME10; begin TestGetSize(bdmMIME,Shuffle(RandomNoise(15))+'abc=',2); end;
procedure TBase64DecodingStreamTestCase.TestGetSizeMIME11; begin TestGetSize(bdmMIME,Shuffle(NoiseCharString)+'abcd',3); end;
procedure TBase64DecodingStreamTestCase.TestGetSizeMIME12; begin TestGetSize(bdmMIME,Shuffle(RandomNoise(16)+'abcd'),3); end;
procedure TBase64DecodingStreamTestCase.TestGetSizeMIME13; begin TestGetSize(bdmMIME,Shuffle(NoiseCharString+'abcd')+'=',3); end;
procedure TBase64DecodingStreamTestCase.TestGetSizeMIME14; begin TestGetSize(bdmMIME,Shuffle(RandomNoise(17)+'abcd')+'01=',4); end;
procedure TBase64DecodingStreamTestCase.TestGetSizeMIME15; begin TestGetSize(bdmMIME,Shuffle(NoiseCharString+'abcd')+'01==',4); end;
procedure TBase64DecodingStreamTestCase.TestGetSizeMIME16; begin TestGetSize(bdmMIME,Shuffle(RandomNoise(18)+'abcd')+'012==',5); end;
procedure TBase64DecodingStreamTestCase.TestGetSizeMIME17; begin TestGetSize(bdmMIME,Shuffle(NoiseCharString+'abcd')+'0123=',6); end;
procedure TBase64DecodingStreamTestCase.TestGetSizeMIME18; begin TestGetSize(bdmMIME,Shuffle(RandomNoise(19)+'abcd')+'012345=',7); end;
procedure TBase64DecodingStreamTestCase.TestGetSizeMIME19; begin TestGetSize(bdmMIME,Shuffle(NoiseCharString+'abcd')+'=01234=',3); end;
procedure TBase64DecodingStreamTestCase.TestGetSizeMIME20; begin TestGetSize(bdmMIME,Shuffle(RandomNoise(20)+'abcd')+'0=1234=',3); end;
procedure TBase64DecodingStreamTestCase.TestGetSizeMIME21; begin TestGetSize(bdmMIME,Shuffle(NoiseCharString+'abcd')+'01=234=',4); end;
procedure TBase64DecodingStreamTestCase.TestGetSizeMIME22; begin TestGetSize(bdmMIME,Shuffle(RandomNoise(99)+'abcd')+'012=34=',5); end;

procedure TBase64DecodingStreamTestCase.TestDecodeStrict01; begin TestDecode(bdmStrict,'',''); end;
procedure TBase64DecodingStreamTestCase.TestDecodeStrict02; begin TestDecode(bdmStrict,'AA==',#0); end;
procedure TBase64DecodingStreamTestCase.TestDecodeStrict03; begin TestDecode(bdmStrict,'AAA=',#0#0); end;
procedure TBase64DecodingStreamTestCase.TestDecodeStrict04; begin TestDecode(bdmStrict,'AAAA',#0#0#0); end;
procedure TBase64DecodingStreamTestCase.TestDecodeStrict05; begin TestDecode(bdmStrict,'AAAAAA==',#0#0#0#0); end;
procedure TBase64DecodingStreamTestCase.TestDecodeStrict06; begin TestDecode(bdmStrict,'AAAAAAA=',#0#0#0#0#0); end;
procedure TBase64DecodingStreamTestCase.TestDecodeStrict07; begin TestDecode(bdmStrict,'AAAAAAAA',#0#0#0#0#0#0); end;
procedure TBase64DecodingStreamTestCase.TestDecodeStrict08; begin TestDecode(bdmStrict,'AAAAAAAA',#0#0#0#0#0#0); end;
procedure TBase64DecodingStreamTestCase.TestDecodeStrict09; begin TestDecode(bdmStrict, 'TG9yZW0gaXBzdW0gZG9sb3Igc2l0IGFtZXQsIGNvbnNlY3RldHVyIGFkaXBpc2ljaW5nIGVsaXQsIHNlZCBkbyBlaXVzbW9kIHRlbXBvciBpbmNpZGlkdW50IHV0IGxhYm9yZSBldCBkb2xvcmUgbWFnbmEgYWxpcXVhLiBVdCBlbmltIGFkIG1pbmltIHZlbmlhbSwgcXVpcyBub3N0cnVkIGV4ZXJjaXRhdGlvbiB1bGxhbWNvIGxhYm9yaXM'+'gbmlzaSB1dCBhbGlxdWlwIGV4IGVhIGNvbW1vZG8gY29uc2VxdWF0LiBEdWlzIGF1dGUgaXJ1cmUgZG9sb3IgaW4gcmVwcmVoZW5kZXJpdCBpbiB2b2x1cHRhdGUgdmVsaXQgZXNzZSBjaWxsdW0gZG9sb3JlIGV1IGZ1Z2lhdCBudWxsYSBwYXJpYXR1ci4gRXhjZXB0ZXVyIHNpbnQgb2NjYWVjYXQgY3VwaWRhdGF0IG5vbiBwcm9pZGVudC'+'wgc3VudCBpbiBjdWxwYSBxdWkgb2ZmaWNpYSBkZXNlcnVudCBtb2xsaXQgYW5pbSBpZCBlc3QgbGFib3J1bS4K',
                                                                                        'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor '+'in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.'#10); end;
procedure TBase64DecodingStreamTestCase.TestDecodeStrict10; begin TestDecode(bdmStrict, 'QmFzZTY0IERlY29kaW5nIFN1Y2NlZWRlZCE=','Base64 Decoding Succeeded!'); end;
procedure TBase64DecodingStreamTestCase.TestDecodeMIME1; begin TestDecode(bdmMIME,Merge('QmFzZTY0IERlY29kaW5nIFN1Y2NlZWRlZCE=',RandomNoise(12  )),'Base64 Decoding Succeeded!'); end;
procedure TBase64DecodingStreamTestCase.TestDecodeMIME2; begin TestDecode(bdmMIME,Merge('QmFzZTY0IERlY29kaW5nIFN1Y2NlZWRlZCE=',RandomNoise(1200)),'Base64 Decoding Succeeded!'); end;
procedure TBase64DecodingStreamTestCase.TestDecodeMIME3; begin TestDecode(bdmMIME,      'QmFzZTY0'                   ,'Base64'); end;
procedure TBase64DecodingStreamTestCase.TestDecodeMIME4; begin TestDecode(bdmMIME,      'QmFzZTY0X='                 ,'Base64'); end;
procedure TBase64DecodingStreamTestCase.TestDecodeMIME5; begin TestDecode(bdmMIME,Merge('QmFzZTY0',RandomNoise(1200)),'Base64'); end;
procedure TBase64DecodingStreamTestCase.TestDecodeMIME6; begin TestDecode(bdmMIME,      'TG9yZW0gaXBzdW0gZG9sb3Igc2l0IGFtZXQsIGNvbnNlY3RldHVyIGFkaXBpc2ljaW5nIGVsaXQsIHNlZCBkbyBlaXVzbW9kIHRlbXBvciBpbmNpZGlkdW50IHV0IGxhYm9yZSBldCBkb2xvcmUgbWFnbmEgYWxpcXVhLiBVdCBlbmltIGFkIG1pbmltIHZlbmlhbSwgcXVpcyBub3N0cnVkIGV4ZXJjaXRhdGlvbiB1bGxhbWNvIGxhYm9yaXM'+'gbmlzaSB1dCBhbGlxdWlwIGV4IGVhIGNvbW1vZG8gY29uc2VxdWF0LiBEdWlzIGF1dGUgaXJ1cmUgZG9sb3IgaW4gcmVwcmVoZW5kZXJpdCBpbiB2b2x1cHRhdGUgdmVsaXQgZXNzZSBjaWxsdW0gZG9sb3JlIGV1IGZ1Z2lhdCBudWxsYSBwYXJpYXR1ci4gRXhjZXB0ZXVyIHNpbnQgb2NjYWVjYXQgY3VwaWRhdGF0IG5vbiBwcm9pZGVudC'+'wgc3VudCBpbiBjdWxwYSBxdWkgb2ZmaWNpYSBkZXNlcnVudCBtb2xsaXQgYW5pbSBpZCBlc3QgbGFib3J1bS4K',
                                                                                        'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor '+'in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.'#10); end;
procedure TBase64DecodingStreamTestCase.TestDecodeMIME7; begin TestDecode(bdmMIME,Merge('TG9yZW0gaXBzdW0gZG9sb3Igc2l0IGFtZXQsIGNvbnNlY3RldHVyIGFkaXBpc2ljaW5nIGVsaXQsIHNlZCBkbyBlaXVzbW9kIHRlbXBvciBpbmNpZGlkdW50IHV0IGxhYm9yZSBldCBkb2xvcmUgbWFnbmEgYWxpcXVhLiBVdCBlbmltIGFkIG1pbmltIHZlbmlhbSwgcXVpcyBub3N0cnVkIGV4ZXJjaXRhdGlvbiB1bGxhbWNvIGxhYm9yaXM'+'gbmlzaSB1dCBhbGlxdWlwIGV4IGVhIGNvbW1vZG8gY29uc2VxdWF0LiBEdWlzIGF1dGUgaXJ1cmUgZG9sb3IgaW4gcmVwcmVoZW5kZXJpdCBpbiB2b2x1cHRhdGUgdmVsaXQgZXNzZSBjaWxsdW0gZG9sb3JlIGV1IGZ1Z2lhdCBudWxsYSBwYXJpYXR1ci4gRXhjZXB0ZXVyIHNpbnQgb2NjYWVjYXQgY3VwaWRhdGF0IG5vbiBwcm9pZGVudC'+'wgc3VudCBpbiBjdWxwYSBxdWkgb2ZmaWNpYSBkZXNlcnVudCBtb2xsaXQgYW5pbSBpZCBlc3QgbGFib3J1bS4K',RandomNoise(1200)),
                                                                                        'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor '+'in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.'#10); end;
procedure TBase64DecodingStreamTestCase.TestDecodeMIME8; begin TestDecode(bdmMIME,Merge('TG9yZW0gaXBzdW0gZG9sb3Igc2l0IGFtZXQsIGNvbnNlY3RldHVyIGFkaXBpc2ljaW5nIGVsaXQsIHNlZCBkbyBlaXVzbW9kIHRlbXBvciBpbmNpZGlkdW50IHV0IGxhYm9yZSBldCBkb2xvcmUgbWFnbmEgYWxpcXVhLiBVdCBlbmltIGFkIG1pbmltIHZlbmlhbSwgcXVpcyBub3N0cnVkIGV4ZXJjaXRhdGlvbiB1bGxhbWNvIGxhYm9yaXM'+'gbmlzaSB1dCBhbGlxdWlwIGV4IGVhIGNvbW1vZG8gY29uc2VxdWF0LiBEdWlzIGF1dGUgaXJ1cmUgZG9sb3IgaW4gcmVwcmVoZW5kZXJpdCBpbiB2b2x1cHRhdGUgdmVsaXQgZXNzZSBjaWxsdW0gZG9sb3JlIGV1IGZ1Z2lhdCBudWxsYSBwYXJpYXR1ci4gRXhjZXB0ZXVyIHNpbnQgb2NjYWVjYXQgY3VwaWRhdGF0IG5vbiBwcm9pZGVudC'+'wgc3VudCBpbiBjdWxwYSBxdWkgb2ZmaWNpYSBkZXNlcnVudCBtb2xsaXQgYW5pbSBpZCBlc3QgbGFib3J1bS4K=',RandomNoise(1200)),
                                                                                        'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor '+'in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.'#10); end;
procedure TBase64DecodingStreamTestCase.TestDecodeMIME9; begin TestDecode(bdmMIME,Merge('TG9yZW0gaXBzdW0gZG9sb3Igc2l0IGFtZXQsIGNvbnNlY3RldHVyIGFkaXBpc2ljaW5nIGVsaXQsIHNlZCBkbyBlaXVzbW9kIHRlbXBvciBpbmNpZGlkdW50IHV0IGxhYm9yZSBldCBkb2xvcmUgbWFnbmEgYWxpcXVhLiBVdCBlbmltIGFkIG1pbmltIHZlbmlhbSwgcXVpcyBub3N0cnVkIGV4ZXJjaXRhdGlvbiB1bGxhbWNvIGxhYm9yaXM'+'gbmlzaSB1dCBhbGlxdWlwIGV4IGVhIGNvbW1vZG8gY29uc2VxdWF0LiBEdWlzIGF1dGUgaXJ1cmUgZG9sb3IgaW4gcmVwcmVoZW5kZXJpdCBpbiB2b2x1cHRhdGUgdmVsaXQgZXNzZSBjaWxsdW0gZG9sb3JlIGV1IGZ1Z2lhdCBudWxsYSBwYXJpYXR1ci4gRXhjZXB0ZXVyIHNpbnQgb2NjYWVjYXQgY3VwaWRhdGF0IG5vbiBwcm9pZGVudC'+'wgc3VudCBpbiBjdWxwYSBxdWkgb2ZmaWNpYSBkZXNlcnVudCBtb2xsaXQgYW5pbSBpZCBlc3QgbGFib3J1bS4KX=',RandomNoise(1200)),
                                                                                        'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor '+'in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.'#10); end;

procedure TBase64DecodingStreamTestCase.TestResetStrict1; begin TestReset(bdmStrict,'',[0],['']); end;
procedure TBase64DecodingStreamTestCase.TestResetStrict2; begin TestReset(bdmStrict,'AA==',[0,4],[#0,'']); end;
procedure TBase64DecodingStreamTestCase.TestResetStrict3; begin TestReset(bdmStrict,'AAAAAAA=',[0,4,8],[#0#0#0#0#0,#0#0,'']); end;
procedure TBase64DecodingStreamTestCase.TestResetMIME1; begin TestReset(bdmMIME,'QmFzZTY0IERlY29kaW5nIFN1Y2NlZWRlZCE=',[0],['Base64 Decoding Succeeded!']); end;
procedure TBase64DecodingStreamTestCase.TestResetMIME2; begin TestReset(bdmMIME,'QmFzZTY0IERlY29kaW5nIFN1Y2NlZWRlZCE=',[0,4,8],['Base64 Decoding Succeeded!','e64 Decoding Succeeded!',' Decoding Succeeded!']); end;
procedure TBase64DecodingStreamTestCase.TestResetMIME3; begin TestReset(bdmMIME,'Qm!@#$%^&*()F!@#$%^&*()z!@#$%^&*()ZTY0IERlY29kaW5nIFN1Y2NlZWRlZCE=',[0,24,34,38,62,66],['Base64 Decoding Succeeded!','e64 Decoding Succeeded!','e64 Decoding Succeeded!',' Decoding Succeeded!','d!','']); end;


constructor TBase64DecodingStreamTestCase.Create(AContext: TNXTestContext; const ACaseName: string);
begin
  inherited Create;
  FContext:=AContext;
  FCaseName:=ACaseName;
end;

procedure RunTBase64DecodingStreamTestCaseTestGetSizeStrict1(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestGetSizeStrict1');
  try
    lFixture.SetUp;
    try lFixture.TestGetSizeStrict1; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestGetSizeStrict2(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestGetSizeStrict2');
  try
    lFixture.SetUp;
    try lFixture.TestGetSizeStrict2; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestGetSizeStrict3(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestGetSizeStrict3');
  try
    lFixture.SetUp;
    try lFixture.TestGetSizeStrict3; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestGetSizeStrict4(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestGetSizeStrict4');
  try
    lFixture.SetUp;
    try lFixture.TestGetSizeStrict4; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestGetSizeStrict5(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestGetSizeStrict5');
  try
    lFixture.SetUp;
    try lFixture.TestGetSizeStrict5; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestGetSizeMIME01(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestGetSizeMIME01');
  try
    lFixture.SetUp;
    try lFixture.TestGetSizeMIME01; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestGetSizeMIME02(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestGetSizeMIME02');
  try
    lFixture.SetUp;
    try lFixture.TestGetSizeMIME02; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestGetSizeMIME03(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestGetSizeMIME03');
  try
    lFixture.SetUp;
    try lFixture.TestGetSizeMIME03; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestGetSizeMIME04(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestGetSizeMIME04');
  try
    lFixture.SetUp;
    try lFixture.TestGetSizeMIME04; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestGetSizeMIME05(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestGetSizeMIME05');
  try
    lFixture.SetUp;
    try lFixture.TestGetSizeMIME05; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestGetSizeMIME06(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestGetSizeMIME06');
  try
    lFixture.SetUp;
    try lFixture.TestGetSizeMIME06; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestGetSizeMIME07(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestGetSizeMIME07');
  try
    lFixture.SetUp;
    try lFixture.TestGetSizeMIME07; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestGetSizeMIME08(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestGetSizeMIME08');
  try
    lFixture.SetUp;
    try lFixture.TestGetSizeMIME08; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestGetSizeMIME09(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestGetSizeMIME09');
  try
    lFixture.SetUp;
    try lFixture.TestGetSizeMIME09; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestGetSizeMIME10(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestGetSizeMIME10');
  try
    lFixture.SetUp;
    try lFixture.TestGetSizeMIME10; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestGetSizeMIME11(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestGetSizeMIME11');
  try
    lFixture.SetUp;
    try lFixture.TestGetSizeMIME11; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestGetSizeMIME12(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestGetSizeMIME12');
  try
    lFixture.SetUp;
    try lFixture.TestGetSizeMIME12; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestGetSizeMIME13(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestGetSizeMIME13');
  try
    lFixture.SetUp;
    try lFixture.TestGetSizeMIME13; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestGetSizeMIME14(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestGetSizeMIME14');
  try
    lFixture.SetUp;
    try lFixture.TestGetSizeMIME14; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestGetSizeMIME15(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestGetSizeMIME15');
  try
    lFixture.SetUp;
    try lFixture.TestGetSizeMIME15; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestGetSizeMIME16(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestGetSizeMIME16');
  try
    lFixture.SetUp;
    try lFixture.TestGetSizeMIME16; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestGetSizeMIME17(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestGetSizeMIME17');
  try
    lFixture.SetUp;
    try lFixture.TestGetSizeMIME17; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestGetSizeMIME18(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestGetSizeMIME18');
  try
    lFixture.SetUp;
    try lFixture.TestGetSizeMIME18; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestGetSizeMIME19(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestGetSizeMIME19');
  try
    lFixture.SetUp;
    try lFixture.TestGetSizeMIME19; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestGetSizeMIME20(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestGetSizeMIME20');
  try
    lFixture.SetUp;
    try lFixture.TestGetSizeMIME20; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestGetSizeMIME21(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestGetSizeMIME21');
  try
    lFixture.SetUp;
    try lFixture.TestGetSizeMIME21; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestGetSizeMIME22(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestGetSizeMIME22');
  try
    lFixture.SetUp;
    try lFixture.TestGetSizeMIME22; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestDecodeStrict01(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestDecodeStrict01');
  try
    lFixture.SetUp;
    try lFixture.TestDecodeStrict01; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestDecodeStrict02(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestDecodeStrict02');
  try
    lFixture.SetUp;
    try lFixture.TestDecodeStrict02; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestDecodeStrict03(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestDecodeStrict03');
  try
    lFixture.SetUp;
    try lFixture.TestDecodeStrict03; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestDecodeStrict04(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestDecodeStrict04');
  try
    lFixture.SetUp;
    try lFixture.TestDecodeStrict04; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestDecodeStrict05(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestDecodeStrict05');
  try
    lFixture.SetUp;
    try lFixture.TestDecodeStrict05; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestDecodeStrict06(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestDecodeStrict06');
  try
    lFixture.SetUp;
    try lFixture.TestDecodeStrict06; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestDecodeStrict07(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestDecodeStrict07');
  try
    lFixture.SetUp;
    try lFixture.TestDecodeStrict07; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestDecodeStrict08(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestDecodeStrict08');
  try
    lFixture.SetUp;
    try lFixture.TestDecodeStrict08; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestDecodeStrict09(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestDecodeStrict09');
  try
    lFixture.SetUp;
    try lFixture.TestDecodeStrict09; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestDecodeStrict10(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestDecodeStrict10');
  try
    lFixture.SetUp;
    try lFixture.TestDecodeStrict10; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestDecodeMIME1(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestDecodeMIME1');
  try
    lFixture.SetUp;
    try lFixture.TestDecodeMIME1; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestDecodeMIME2(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestDecodeMIME2');
  try
    lFixture.SetUp;
    try lFixture.TestDecodeMIME2; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestDecodeMIME3(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestDecodeMIME3');
  try
    lFixture.SetUp;
    try lFixture.TestDecodeMIME3; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestDecodeMIME4(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestDecodeMIME4');
  try
    lFixture.SetUp;
    try lFixture.TestDecodeMIME4; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestDecodeMIME5(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestDecodeMIME5');
  try
    lFixture.SetUp;
    try lFixture.TestDecodeMIME5; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestDecodeMIME6(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestDecodeMIME6');
  try
    lFixture.SetUp;
    try lFixture.TestDecodeMIME6; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestDecodeMIME7(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestDecodeMIME7');
  try
    lFixture.SetUp;
    try lFixture.TestDecodeMIME7; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestDecodeMIME8(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestDecodeMIME8');
  try
    lFixture.SetUp;
    try lFixture.TestDecodeMIME8; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestDecodeMIME9(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestDecodeMIME9');
  try
    lFixture.SetUp;
    try lFixture.TestDecodeMIME9; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestResetStrict1(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestResetStrict1');
  try
    lFixture.SetUp;
    try lFixture.TestResetStrict1; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestResetStrict2(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestResetStrict2');
  try
    lFixture.SetUp;
    try lFixture.TestResetStrict2; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestResetStrict3(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestResetStrict3');
  try
    lFixture.SetUp;
    try lFixture.TestResetStrict3; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestResetMIME1(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestResetMIME1');
  try
    lFixture.SetUp;
    try lFixture.TestResetMIME1; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestResetMIME2(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestResetMIME2');
  try
    lFixture.SetUp;
    try lFixture.TestResetMIME2; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTBase64DecodingStreamTestCaseTestResetMIME3(AContext: TNXTestContext);
var lFixture: TBase64DecodingStreamTestCase;
begin
  lFixture:=TBase64DecodingStreamTestCase.Create(AContext, 'TestResetMIME3');
  try
    lFixture.SetUp;
    try lFixture.TestResetMIME3; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RegisterBase64DecodingTestCaseTests(ARegistry: TNXTestRegistry);
var lSuite: TNXTestSuite;
begin
  lSuite:=ARegistry.AddSuite('Base64DecodingTestCase.TBase64DecodingStreamTestCase');
  lSuite.AddTest('TestGetSizeStrict1', @RunTBase64DecodingStreamTestCaseTestGetSizeStrict1);
  lSuite.AddTest('TestGetSizeStrict2', @RunTBase64DecodingStreamTestCaseTestGetSizeStrict2);
  lSuite.AddTest('TestGetSizeStrict3', @RunTBase64DecodingStreamTestCaseTestGetSizeStrict3);
  lSuite.AddTest('TestGetSizeStrict4', @RunTBase64DecodingStreamTestCaseTestGetSizeStrict4);
  lSuite.AddTest('TestGetSizeStrict5', @RunTBase64DecodingStreamTestCaseTestGetSizeStrict5);
  lSuite.AddTest('TestGetSizeMIME01', @RunTBase64DecodingStreamTestCaseTestGetSizeMIME01);
  lSuite.AddTest('TestGetSizeMIME02', @RunTBase64DecodingStreamTestCaseTestGetSizeMIME02);
  lSuite.AddTest('TestGetSizeMIME03', @RunTBase64DecodingStreamTestCaseTestGetSizeMIME03);
  lSuite.AddTest('TestGetSizeMIME04', @RunTBase64DecodingStreamTestCaseTestGetSizeMIME04);
  lSuite.AddTest('TestGetSizeMIME05', @RunTBase64DecodingStreamTestCaseTestGetSizeMIME05);
  lSuite.AddTest('TestGetSizeMIME06', @RunTBase64DecodingStreamTestCaseTestGetSizeMIME06);
  lSuite.AddTest('TestGetSizeMIME07', @RunTBase64DecodingStreamTestCaseTestGetSizeMIME07);
  lSuite.AddTest('TestGetSizeMIME08', @RunTBase64DecodingStreamTestCaseTestGetSizeMIME08);
  lSuite.AddTest('TestGetSizeMIME09', @RunTBase64DecodingStreamTestCaseTestGetSizeMIME09);
  lSuite.AddTest('TestGetSizeMIME10', @RunTBase64DecodingStreamTestCaseTestGetSizeMIME10);
  lSuite.AddTest('TestGetSizeMIME11', @RunTBase64DecodingStreamTestCaseTestGetSizeMIME11);
  lSuite.AddTest('TestGetSizeMIME12', @RunTBase64DecodingStreamTestCaseTestGetSizeMIME12);
  lSuite.AddTest('TestGetSizeMIME13', @RunTBase64DecodingStreamTestCaseTestGetSizeMIME13);
  lSuite.AddTest('TestGetSizeMIME14', @RunTBase64DecodingStreamTestCaseTestGetSizeMIME14);
  lSuite.AddTest('TestGetSizeMIME15', @RunTBase64DecodingStreamTestCaseTestGetSizeMIME15);
  lSuite.AddTest('TestGetSizeMIME16', @RunTBase64DecodingStreamTestCaseTestGetSizeMIME16);
  lSuite.AddTest('TestGetSizeMIME17', @RunTBase64DecodingStreamTestCaseTestGetSizeMIME17);
  lSuite.AddTest('TestGetSizeMIME18', @RunTBase64DecodingStreamTestCaseTestGetSizeMIME18);
  lSuite.AddTest('TestGetSizeMIME19', @RunTBase64DecodingStreamTestCaseTestGetSizeMIME19);
  lSuite.AddTest('TestGetSizeMIME20', @RunTBase64DecodingStreamTestCaseTestGetSizeMIME20);
  lSuite.AddTest('TestGetSizeMIME21', @RunTBase64DecodingStreamTestCaseTestGetSizeMIME21);
  lSuite.AddTest('TestGetSizeMIME22', @RunTBase64DecodingStreamTestCaseTestGetSizeMIME22);
  lSuite.AddTest('TestDecodeStrict01', @RunTBase64DecodingStreamTestCaseTestDecodeStrict01);
  lSuite.AddTest('TestDecodeStrict02', @RunTBase64DecodingStreamTestCaseTestDecodeStrict02);
  lSuite.AddTest('TestDecodeStrict03', @RunTBase64DecodingStreamTestCaseTestDecodeStrict03);
  lSuite.AddTest('TestDecodeStrict04', @RunTBase64DecodingStreamTestCaseTestDecodeStrict04);
  lSuite.AddTest('TestDecodeStrict05', @RunTBase64DecodingStreamTestCaseTestDecodeStrict05);
  lSuite.AddTest('TestDecodeStrict06', @RunTBase64DecodingStreamTestCaseTestDecodeStrict06);
  lSuite.AddTest('TestDecodeStrict07', @RunTBase64DecodingStreamTestCaseTestDecodeStrict07);
  lSuite.AddTest('TestDecodeStrict08', @RunTBase64DecodingStreamTestCaseTestDecodeStrict08);
  lSuite.AddTest('TestDecodeStrict09', @RunTBase64DecodingStreamTestCaseTestDecodeStrict09);
  lSuite.AddTest('TestDecodeStrict10', @RunTBase64DecodingStreamTestCaseTestDecodeStrict10);
  lSuite.AddTest('TestDecodeMIME1', @RunTBase64DecodingStreamTestCaseTestDecodeMIME1);
  lSuite.AddTest('TestDecodeMIME2', @RunTBase64DecodingStreamTestCaseTestDecodeMIME2);
  lSuite.AddTest('TestDecodeMIME3', @RunTBase64DecodingStreamTestCaseTestDecodeMIME3);
  lSuite.AddTest('TestDecodeMIME4', @RunTBase64DecodingStreamTestCaseTestDecodeMIME4);
  lSuite.AddTest('TestDecodeMIME5', @RunTBase64DecodingStreamTestCaseTestDecodeMIME5);
  lSuite.AddTest('TestDecodeMIME6', @RunTBase64DecodingStreamTestCaseTestDecodeMIME6);
  lSuite.AddTest('TestDecodeMIME7', @RunTBase64DecodingStreamTestCaseTestDecodeMIME7);
  lSuite.AddTest('TestDecodeMIME8', @RunTBase64DecodingStreamTestCaseTestDecodeMIME8);
  lSuite.AddTest('TestDecodeMIME9', @RunTBase64DecodingStreamTestCaseTestDecodeMIME9);
  lSuite.AddTest('TestResetStrict1', @RunTBase64DecodingStreamTestCaseTestResetStrict1);
  lSuite.AddTest('TestResetStrict2', @RunTBase64DecodingStreamTestCaseTestResetStrict2);
  lSuite.AddTest('TestResetStrict3', @RunTBase64DecodingStreamTestCaseTestResetStrict3);
  lSuite.AddTest('TestResetMIME1', @RunTBase64DecodingStreamTestCaseTestResetMIME1);
  lSuite.AddTest('TestResetMIME2', @RunTBase64DecodingStreamTestCaseTestResetMIME2);
  lSuite.AddTest('TestResetMIME3', @RunTBase64DecodingStreamTestCaseTestResetMIME3);
end;

end.
