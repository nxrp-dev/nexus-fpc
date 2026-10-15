{ utility to avoid the tedious typing of register numbers for AArch64 VFP registers }
var
  i : LongInt;

begin
  for i:=0 to 31 do
    begin
      WriteLn('B',i,',$04,$01,$',HexStr(i,2),',b',i,',',i+64,',',i+64);
      WriteLn('H',i,',$04,$03,$',HexStr(i,2),',h',i,',',i+64,',',i+64);
      WriteLn('S',i,',$04,$09,$',HexStr(i,2),',s',i,',',i+64,',',i+64);
      WriteLn('D',i,',$04,$0a,$',HexStr(i,2),',d',i,',',i+64,',',i+64);
      WriteLn('Q',i,',$04,$0b,$',HexStr(i,2),',q',i,',',i+64,',',i+64);
      // SUBNONE, to be able to parse shorthand notations like "add.4h v0, v1, v2"
      WriteLn('V',i,',$04,$00,$',HexStr(i,2),',v',i,',',i+64,',',i+64);
      WriteLn('V',i,'_B,$04,$20,$',HexStr(i,2),',v',i,'.b,',i+64,',',i+64);
      WriteLn('V',i,'_H,$04,$21,$',HexStr(i,2),',v',i,'.h,',i+64,',',i+64);
      WriteLn('V',i,'_S,$04,$22,$',HexStr(i,2),',v',i,'.s,',i+64,',',i+64);
      WriteLn('V',i,'_D,$04,$23,$',HexStr(i,2),',v',i,'.d,',i+64,',',i+64);
      WriteLn('V',i,'_8B,$04,$18,$',HexStr(i,2),',v',i,'.8b,',i+64,',',i+64);
      WriteLn('V',i,'_16B,$04,$19,$',HexStr(i,2),',v',i,'.16b,',i+64,',',i+64);
      WriteLn('V',i,'_4H,$04,$1a,$',HexStr(i,2),',v',i,'.4h,',i+64,',',i+64);
      WriteLn('V',i,'_8H,$04,$1b,$',HexStr(i,2),',v',i,'.8h,',i+64,',',i+64);
      WriteLn('V',i,'_2S,$04,$1c,$',HexStr(i,2),',v',i,'.2s,',i+64,',',i+64);
      WriteLn('V',i,'_4S,$04,$1d,$',HexStr(i,2),',v',i,'.4s,',i+64,',',i+64);
      WriteLn('V',i,'_1D,$04,$1e,$',HexStr(i,2),',v',i,'.1d,',i+64,',',i+64);
      WriteLn('V',i,'_2D,$04,$1f,$',HexStr(i,2),',v',i,'.2d,',i+64,',',i+64);
    end;
end.
