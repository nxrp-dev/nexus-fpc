{ Unsigned Val must honor destination width for every string representation. }
{$Q-}
{$R-}

procedure Check(const Kind, Input: ShortString; Actual: QWord;
  Code: Integer; Expected: QWord; Valid: Boolean);
begin
  if (Valid and ((Code<>0) or (Actual<>Expected))) or
     ((not Valid) and (Code=0)) then
    begin
      writeln(Kind, ' input="', Input, '" code=', Code, ' value=', Actual);
      halt(1);
    end;
end;

procedure TestByte(const Input: ShortString; Expected: QWord; Valid: Boolean);
var
  A: AnsiString;
  W: WideString;
  U: UnicodeString;
  Value: Byte;
  Code: Integer;
begin
  A:=Input;
  W:=Input;
  U:=Input;
  Val(Input,Value,Code);
  Check('ShortString/Byte',Input,Value,Code,Expected,Valid);
  Val(A,Value,Code);
  Check('AnsiString/Byte',Input,Value,Code,Expected,Valid);
  Val(W,Value,Code);
  Check('WideString/Byte',Input,Value,Code,Expected,Valid);
  Val(U,Value,Code);
  Check('UnicodeString/Byte',Input,Value,Code,Expected,Valid);
end;

procedure TestWord(const Input: ShortString; Expected: QWord; Valid: Boolean);
var
  A: AnsiString;
  W: WideString;
  U: UnicodeString;
  Value: Word;
  Code: Integer;
begin
  A:=Input;
  W:=Input;
  U:=Input;
  Val(Input,Value,Code);
  Check('ShortString/Word',Input,Value,Code,Expected,Valid);
  Val(A,Value,Code);
  Check('AnsiString/Word',Input,Value,Code,Expected,Valid);
  Val(W,Value,Code);
  Check('WideString/Word',Input,Value,Code,Expected,Valid);
  Val(U,Value,Code);
  Check('UnicodeString/Word',Input,Value,Code,Expected,Valid);
end;

procedure TestDWord(const Input: ShortString; Expected: QWord; Valid: Boolean);
var
  A: AnsiString;
  W: WideString;
  U: UnicodeString;
  Value: DWord;
  Code: Integer;
begin
  A:=Input;
  W:=Input;
  U:=Input;
  Val(Input,Value,Code);
  Check('ShortString/DWord',Input,Value,Code,Expected,Valid);
  Val(A,Value,Code);
  Check('AnsiString/DWord',Input,Value,Code,Expected,Valid);
  Val(W,Value,Code);
  Check('WideString/DWord',Input,Value,Code,Expected,Valid);
  Val(U,Value,Code);
  Check('UnicodeString/DWord',Input,Value,Code,Expected,Valid);
end;

procedure TestQWord(const Input: ShortString; Expected: QWord; Valid: Boolean);
var
  A: AnsiString;
  W: WideString;
  U: UnicodeString;
  Value: QWord;
  Code: Integer;
begin
  A:=Input;
  W:=Input;
  U:=Input;
  Val(Input,Value,Code);
  Check('ShortString/QWord',Input,Value,Code,Expected,Valid);
  Val(A,Value,Code);
  Check('AnsiString/QWord',Input,Value,Code,Expected,Valid);
  Val(W,Value,Code);
  Check('WideString/QWord',Input,Value,Code,Expected,Valid);
  Val(U,Value,Code);
  Check('UnicodeString/QWord',Input,Value,Code,Expected,Valid);
end;

begin
  TestByte('0',0,true);
  TestByte('255',High(Byte),true);
  TestByte('256',0,false);
  TestByte('$FF',High(Byte),true);
  TestByte('$100',0,false);
  TestByte('&377',High(Byte),true);
  TestByte('&400',0,false);
  TestByte('%11111111',High(Byte),true);
  TestByte('%100000000',0,false);
  TestByte('+255',High(Byte),true);
  TestByte('-1',0,false);
  TestByte('',0,false);
  TestByte('12z',0,false);
  TestWord('0',0,true);
  TestWord('65535',High(Word),true);
  TestWord('65536',0,false);
  TestWord('$FFFF',High(Word),true);
  TestWord('$10000',0,false);
  TestWord('&177777',High(Word),true);
  TestWord('&200000',0,false);
  TestWord('%1111111111111111',High(Word),true);
  TestWord('%10000000000000000',0,false);
  TestWord('+65535',High(Word),true);
  TestWord('-1',0,false);
  TestWord('',0,false);
  TestWord('12z',0,false);
  TestDWord('0',0,true);
  TestDWord('4294967295',High(DWord),true);
  TestDWord('4294967296',0,false);
  TestDWord('$FFFFFFFF',High(DWord),true);
  TestDWord('$100000000',0,false);
  TestDWord('&37777777777',High(DWord),true);
  TestDWord('&40000000000',0,false);
  TestDWord('%11111111111111111111111111111111',High(DWord),true);
  TestDWord('%100000000000000000000000000000000',0,false);
  TestDWord('+4294967295',High(DWord),true);
  TestDWord('-1',0,false);
  TestDWord('',0,false);
  TestDWord('12z',0,false);
  TestQWord('0',0,true);
  TestQWord('18446744073709551615',High(QWord),true);
  TestQWord('18446744073709551616',0,false);
  TestQWord('$FFFFFFFFFFFFFFFF',High(QWord),true);
  TestQWord('$10000000000000000',0,false);
  TestQWord('&1777777777777777777777',High(QWord),true);
  TestQWord('&2000000000000000000000',0,false);
  TestQWord('%1111111111111111111111111111111111111111111111111111111111111111',High(QWord),true);
  TestQWord('%10000000000000000000000000000000000000000000000000000000000000000',0,false);
  TestQWord('+18446744073709551615',High(QWord),true);
  TestQWord('-1',0,false);
  TestQWord('',0,false);
  TestQWord('12z',0,false);
end.
