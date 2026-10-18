
{$ASSERTIONS ON}

uses PasZLibIO, sysutils, classes;

var
  fEncoder : PasZLibIO.Tcompressionstream;
  fDecoder : PasZLibIO.Tdecompressionstream;
  fExpectedString : Shortstring;
  fCompressedStream : TStream;
  fBuffer : array[0..9] of Char;
begin
  fCompressedStream := TMemoryStream.Create();
  fExpectedString := 'test me test me I hope this is compressible test me compressible is test me';
  fEncoder := PasZLibIO.Tcompressionstream.Create(clMax, fCompressedStream);
  fEncoder.Write(fExpectedString[1], Length(fExpectedString));
  FreeAndNil(fEncoder);
  fCompressedStream.Position := 0;
  fDecoder := PasZLibIO.Tdecompressionstream.Create(fCompressedStream);
  fDecoder.Read(fBuffer, 10);
  assert(fDecoder.Position = 10);
end.
