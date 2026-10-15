{
    Copyright (c) 2000-2002 by Florian Klaempfl

    This unit contains basic functions for unicode support in the
    compiler, this unit is mainly necessary to bootstrap widestring
    support ...

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

 ****************************************************************************
}
unit widestr;

{$i fpcdefs.inc}

  interface

    uses
      CharSet,GlobType;


    type
       TCompilerWideChar = Word;
       TCompilerWideCharPtr = ^TCompilerWideChar;
       PCompilerWideChar = ^TCompilerWideChar;
       TCompilerWideCharArray = array of TCompilerWideChar;

       TCompilerWideString = class
          Data : TCompilerWideCharArray;
          MaxLen,Len : SizeInt;
          function AsConstPUnicodeChar : PUnicodeChar;
       end;

    procedure InitWideString(out R : TCompilerWideString);
    procedure DoneWideString(var R : TCompilerWideString);
    procedure SetLengthWideString(R : TCompilerWideString;L : SizeInt);
    function GetLengthWideString(R : TCompilerWideString) : SizeInt;
    procedure ConcatWideStringChar(R : TCompilerWideString;C : TCompilerWideChar);
    procedure ConcatWideStrings(S1,S2 : TCompilerWideString);
    function CompareWideStrings(S1,S2 : TCompilerWideString) : SizeInt;
    procedure CopyWideString(S,D : TCompilerWideString);
    function ASCIIChar2Unicode(C : Char) : TCompilerWideChar;
    function Unicode2ASCIIChar(C : TCompilerWideChar) : Char;
    procedure ASCII2Unicode(P : PChar;L : SizeInt;CP : TStringEncoding;R : TCompilerWideString;CodePageTranslation : Boolean = True);
    procedure Unicode2ASCII(R : TCompilerWideString;P : PChar;CP : TStringEncoding);
    procedure Unicode2ASCII(R : TCompilerWideString;Arr:TAnsiCharDynArray;CP : TStringEncoding);
    function HasNonASCIIChars(const P: TCompilerWideString): Boolean;
    function GetCharWideString(R : TCompilerWideString;L : SizeInt) : TCompilerWideChar;
    function CPAvailable(const S: string) : Boolean;
    function CPAvailable(CP: Word) : Boolean;
    procedure ChangeCodePage(
      S : PChar; L : SizeInt; SCP : TStringEncoding;
      D : PChar; DCP : TStringEncoding
    );
    function CodePageByName(const S : string) : TStringEncoding;
    function CharLength(P: PChar; Len: SizeInt): SizeInt;
    function CharLength(const S: string): SizeInt;

  implementation

    uses
      { use only small codepage maps, others will be }
      { loaded on demand from -FM path               }

      { cyrillic code pages }
      CP1251,CP866,CP8859_5,
      { greek code page }
      CP1253,
      { other code pages }
      CP8859_1,CP850,CP437,CP1252,CP646,
      CP874, CP856,CP852,CP8859_2,
      CP1250,CP1254,CP1255,CP1256,CP1257,CP1258,
      Globals,CUtils;


    procedure InitWideString(out R : TCompilerWideString);

      begin
         R:=TCompilerWideString.Create;
         R.Data:=nil;
         R.Len:=0;
         R.MaxLen:=0;
      end;

    procedure DoneWideString(var R : TCompilerWideString);

      begin
         R.Free;
         R:=nil;
      end;

    function GetCharWideString(R : TCompilerWideString;L : SizeInt) : TCompilerWideChar;

      begin
         GetCharWideString:=R.Data[L];
      end;

    function GetLengthWideString(R : TCompilerWideString) : SizeInt;

      begin
         GetLengthWideString:=R.Len;
      end;

    procedure GrowWideString(R : TCompilerWideString;L : SizeInt);

      begin
         if R.MaxLen>=L then
           Exit;
         SetLength(R.Data,L);
         R.MaxLen:=L;
      end;

    procedure SetLengthWideString(R : TCompilerWideString;L : SizeInt);

      begin
         R.Len:=L;
         if L>R.MaxLen then
           GrowWideString(R,L);
      end;

    procedure ConcatWideStringChar(R : TCompilerWideString;C : TCompilerWideChar);

      begin
         if R.Len>=R.MaxLen then
           GrowWideString(R,R.Len+16);
         R.Data[R.Len]:=C;
         Inc(R.Len);
      end;

    procedure ConcatWideStrings(S1,S2 : TCompilerWideString);
      begin
         GrowWideString(S1,S1.Len+S2.Len);
         if S2.Len>0 then
           Move(S2.Data[0],S1.Data[S1.Len],S2.Len*SizeOf(TCompilerWideChar));
         Inc(S1.Len,S2.Len);
      end;

    procedure CopyWideString(S,D : TCompilerWideString);

      begin
         SetLengthWideString(D,S.Len);
         if S.Len>0 then
           Move(S.Data[0],D.Data[0],S.Len*SizeOf(TCompilerWideChar));
      end;

    function CompareWideStrings(S1,S2 : TCompilerWideString) : SizeInt;
      var
         Maxi,Temp : SizeInt;
      begin
         if Pointer(S1)=Pointer(S2) then
           begin
              CompareWideStrings:=0;
              Exit;
           end;
         Maxi:=S1.Len;
         Temp:=S2.Len;
         if Maxi>Temp then
           Maxi:=Temp;
         if Maxi>0 then
           Temp:=CompareWord(S1.Data[0],S2.Data[0],Maxi)
         else
           Temp:=0;
         if Temp=0 then
           Temp:=S1.Len-S2.Len;
         CompareWideStrings:=Temp;
      end;

    function ASCIIChar2Unicode(C : Char) : TCompilerWideChar;
      var
         M : PUnicodeMap;
      begin
         if (CurrentSettings.SourceCodePage <> CP_UTF8) then
           begin
             M:=GetMap(CurrentSettings.SourceCodePage);
             ASCIIChar2Unicode:=GetUnicode(C,M);
           end
         else
           Result:=TCompilerWideChar(C);
      end;

    function Unicode2ASCIIChar(C : TCompilerWideChar) : Char;
      {begin
        if word(c)<128 then
          unicode2asciichar:=char(word(c))
         else
          unicode2asciichar:='?';
      end;}
      begin
         Result := GetASCII(C,GetMap(CurrentSettings.SourceCodePage))[1];
      end;


    procedure ASCII2Unicode(P : PChar;L : SizeInt;CP : TStringEncoding;R : TCompilerWideString;CodePageTranslation : Boolean = True);
      var
         Source : PChar;
         Dest   : TCompilerWideCharPtr;
         I      : SizeInt;
         M      : PUnicodeMap;
      begin
         M:=GetMap(CP);
         SetLengthWideString(R,L);
         Source:=P;
         Dest:=TCompilerWideCharPtr(R.Data);
         if CodePageTranslation then
           begin
             if CP<>CP_UTF8 then
               begin
                 for I:=1 to L do
                    begin
                      Dest^:=GetUnicode(Source^,M);
                      Inc(Dest);
                      Inc(Source);
                    end;
               end
             else
               begin
                 R.Len:=UTF8ToUnicode(PUnicodeChar(R.Data),R.MaxLen,P,L);
                 { -1, because utf8tounicode includes room for a terminating 0 in
                   its result count }
                 if R.Len>0 then
                   Dec(R.Len);
               end;
           end
         else
           begin
             for I:=1 to L do
                begin
                  Dest^:=TCompilerWideChar(Source^);
                  Inc(Dest);
                  Inc(Source);
                end;
           end;
      end;


    procedure Unicode2ASCII(R : TCompilerWideString;Arr:TAnsiCharDynArray;CP : TStringEncoding);
    begin
      if (R.Len=0) or (Length(Arr)=0) then
        Exit;
      Unicode2ASCII(R,PChar(@Arr[0]),CP);
    end;

    procedure Unicode2ASCII(R : TCompilerWideString;P:PChar;CP : TStringEncoding);
      var
        M : PUnicodeMap;
        Source : TCompilerWideCharPtr;
        Dest   : PChar;
        I      : LongInt;
      begin
        { can't implement that here, because the memory size for p() cannot
          be changed here, and we may need more bytes than have been allocated }
        if CP=CP_UTF8 then
          InternalErrorProc(2015092701);

        if (CP = 0) or (CP=CP_NONE) then
          M:=GetMap(CurrentSettings.SourceCodePage)
        else
          M:=GetMap(CP);
        Source:=TCompilerWideCharPtr(R.Data);
        Dest:=P;
        for I:=1 to R.Len do
         begin
           Dest^ := GetASCII(Source^,M)[1];
           Inc(Dest);
           Inc(Source);
         end;
      end;


    function HasNonASCIIChars(const P: TCompilerWideString): Boolean;
      var
        Source : TCompilerWideCharPtr;
        I      : LongInt;
      begin
        Source:=TCompilerWideCharPtr(P.Data);
        Result:=True;
        for I:=1 to P.Len do
          begin
            if Word(Source^)>=128 then
              Exit;
            Inc(Source);
          end;
        Result:=False;
      end;


    function CPAvailable(const S: string): Boolean;
      begin
        Result:=MappingAvailable(Lower(S));
        if not Result then
          Result:=(UnicodePath<>'')and(RegisterBinaryMapping(UnicodePath+'charset',Lower(S)));
      end;

    function CPAvailable(CP: Word): Boolean;
      begin
        Result:=MappingAvailable(CP);
        if not Result then
          Result:=(UnicodePath<>'')and(RegisterBinaryMapping(UnicodePath+'charset','cp'+ToStr(CP)));
      end;

    procedure ChangeCodePage(
      S : PChar; L : SizeInt; SCP : TStringEncoding;
      D : PChar; DCP : TStringEncoding
    );
      var
        MS, MD : PUnicodeMap;
        Source : PChar;
        Dest   : PChar;
        I      : LongInt;
      begin
        MS:=GetMap(SCP);
        MD:=GetMap(DCP);
        Source:=S;
        Dest:=D;
        for I:=1 to L do
         begin
           Dest^ := GetASCII(GetUnicode(Source^,MS),MD)[1];
           Inc(Dest);
           Inc(Source);
         end;
      end;

    function CodePageByName(const S : string) : TStringEncoding;
      var
        P : PUnicodeMap;
      begin
        Result:=0;
        P:=GetMap(Lower(S));
        if (P<>nil) then
          Result:=P^.CP;
      end;


    function CharLength(P: PChar; Len: SizeInt): SizeInt;
      var
        P2: PChar;
        I, Chars, CodePointLen: SizeInt;
      begin
        if Len=0 then
          begin
            Result:=0;
            Exit;
          end;
{ Length of the string converted to a SBCS codepage (e.g. ISO 8859-1)
  should be equal to the amount of characters in the source string. }
        if DefaultSystemCodePage=CP_UTF8 then
{ ChangeCodePage does not work for UTF-8 apparently... :-( }
          begin
            I:=1;
            Chars:=0;
            while I<=Len do
              begin
                CodePointLen:=UTF8CodePointLen(P,Len-I+1,True);
                Inc(I,CodePointLen);
                Inc(P,CodePointLen);
                Inc(Chars);
              end;
            Result:=Chars;
          end
        else if CPAvailable(DefaultSystemCodePage) then
          begin
            GetMem(P2,Succ(Len));
            FillChar(P2^,Succ(Len),0);
            ChangeCodePage(P,Len,DefaultSystemCodePage,P2,28591);
            Result:=StrLen(P2);
            FreeMem(P2,Succ(Len));
          end
        else
          Result:=Len;
      end;

    function CharLength(const S: string): SizeInt;
      begin
        Result:=CharLength(@S[1],Length(S));
      end;

    { tcompilerwidestring }
    const
      CEmptyUnicodeChar : UnicodeChar = #0;

    function TCompilerWideString.AsConstPUnicodeChar: PUnicodeChar;
      begin
        if Length(Data)>0 then
          Result:=@Data[0]
        else
          Result:=@CEmptyUnicodeChar;
      end;

end.
