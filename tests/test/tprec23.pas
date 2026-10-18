// http://lists.freepascal.org/lists/fpc-devel/2008-June/013919.html

uses SysUtils;
{$ASSERTIONS ON}
type
    bit = 0..1;
    t6bit = 0..63;

    ByteBoundary = bitpacked record
        bit0 : bit;
        bit1_8 : byte;
        bit9_15 : t6bit;
    end;

    TestByteBoundary = record
        case boolean of
            false : (AsWord : word);
            true : (AsBits : ByteBoundary);
    end;


procedure TestBits(b0 : bit; b1_8 : byte; b9_15 : t6bit);
var
    Test : TestByteBoundary;
    w : word;
begin
    w :=  b0 + b1_8 shl 1 + b9_15 shl 9;
    with Test, asBits do begin
        bit0 := b0;
        bit1_8 := b1_8;
        bit9_15 := b9_15;
        Writeln('Test : $', b0, ' + $', IntToHex(b1_8,2), ' << 1 + $',IntToHex(b9_15,2),' << 9');
        write('  Expected : $',IntToHex(w,4),' Got : $',IntToHex((AsWord and $7fff),4));
        if w = (Asword and $7fff) then
            writeln(' OK')
        else
          begin
            writeln(' <--- Fail');
            halt(1);
          end;
    end;
end;


procedure testproc;
var
    Test : TestByteBoundary;
begin

   Test.AsBits.bit0 := 0;
   Test.AsBits.bit1_8 := $FF;
   Test.AsBits.bit9_15 := 0;
   writeln(IntToHex(Test.AsWord,4));



   TestBits($1, $80, $00);
   TestBits($1, $FE, $00);
   TestBits($1, $FF, $00);


  // These work
   Test.AsBits.bit0 := 1;
   Test.AsBits.bit1_8 := $80;
   Test.AsBits.bit9_15 := 0;

   assert((Test.AsWord and $7fff) = $0101, 'Is: ' + IntToHex(Test.AsWord,4) + ' Should be $0101');

   Test.AsBits.bit1_8 := $FE;
   assert((Test.AsWord and $7fff) = $01FD, 'Is: ' + IntToHex(Test.AsWord,4) + ' Should be $01FD');

   // DOES NOT WORK ...
   Test.AsBits.bit1_8 := 255;
   assert((Test.AsWord and $7fff) = $01FF, 'Is: ' + IntToHex(Test.AsWord,4) + ' Should be $01FF');

   // Rest OK
   Test.AsWord := 0;
   Test.AsBits.bit9_15 := 1;
   assert((Test.AsWord and $7fff) = $0200, 'Is: ' + IntToHex(Test.AsWord,4) + ' Should be $0200');

   Test.AsBits.bit9_15 := 32;
   assert((Test.AsWord and $7fff) = $4000, 'Is: ' + IntToHex(Test.AsWord,4) + ' Should be $4000');

   Test.AsBits.bit9_15 := 62;
   assert((Test.AsWord and $7fff) = $7C00, 'Is: ' + IntToHex(Test.AsWord,4) + ' Should be $7C00');

   Test.AsBits.bit9_15 := 63;   // Correct
   assert((Test.AsWord and $7fff) = $7E00, 'Is: ' + IntToHex(Test.AsWord,4) + ' Should be $7E00');

   Test.AsBits.bit0 := 1;
   Test.AsBits.bit1_8 := 255;
   Test.AsBits.bit9_15 := 63;
   assert((Test.AsWord and $7fff) = $7FFF, 'Is: ' + IntToHex(Test.AsWord,4) + ' Should be $7FFF');
end;


var
    Test : TestByteBoundary;
begin

    with Test, AsBits do begin



       bit0 := 0;
       bit1_8 := $FF;
       bit9_15 := 0;
       writeln(IntToHex(AsWord,4));



       TestBits($1, $80, $00);
       TestBits($1, $FE, $00);
       TestBits($1, $FF, $00);
       TestBits($0, $00, $01);


      // These work
       bit0 := 1;
       bit1_8 := $80;
       bit9_15 := 0;

       assert((AsWord and $7fff) = $0101, 'Is: ' + IntToHex(Asword,4) + ' Should be $0101');

       bit1_8 := $FE;
       assert((AsWord and $7fff) = $01FD, 'Is: ' + IntToHex(Asword,4) + ' Should be $01FD');

       // DOES NOT WORK ...
       bit1_8 := 255;
       assert((AsWord and $7fff) = $01FF, 'Is: ' + IntToHex(Asword,4) + ' Should be $01FF');

       // Rest OK
       AsWord := 0;
       bit9_15 := 1;
       assert((AsWord and $7fff) = $0200, 'Is: ' + IntToHex(Asword,4) + ' Should be $0200');

       bit9_15 := 32;
       assert((AsWord and $7fff) = $4000, 'Is: ' + IntToHex(Asword,4) + ' Should be $4000');

       bit9_15 := 62;
       assert((AsWord and $7fff) = $7C00, 'Is: ' + IntToHex(Asword,4) + ' Should be $7C00');

       bit9_15 := 63;   // Correct
       assert((AsWord and $7fff) = $7E00, 'Is: ' + IntToHex(Asword,4) + ' Should be $7E00');

       bit0 := 1;
       bit1_8 := 255;
       bit9_15 := 63;
       assert((AsWord and $7fff) = $7FFF, 'Is: ' + IntToHex(Asword,4) + ' Should be $7FFF');

    end;
    testproc;
end.

