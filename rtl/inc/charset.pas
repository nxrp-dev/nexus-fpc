{
    This file is part of the Free Pascal run time library.
    Copyright (c) 2000 by Florian Klaempfl
    member of the Free Pascal development team.

    This unit implements several classes for charset conversions

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
{$mode objfpc}
{$pointermath on}
{$PACKENUM 1}
{$IFNDEF FPC_DOTTEDUNITS}
unit charset;
{$ENDIF FPC_DOTTEDUNITS}

  interface

    type
       TUnicodeChar = Word;
       tunicodestring = ^TUnicodeChar;

       tunicodecharmappingflag = (umf_noinfo,umf_leadbyte,umf_undefined,
         umf_unused);

       punicodecharmapping = ^TUnicodeCharMapping;
       tunicodecharmapping = packed record
          Unicode : TUnicodeChar;
          Flag : TUnicodeCharMappingFlag;
          Reserved : Byte;
       end;

       preversecharmapping = ^TReverseCharMapping;
       treversecharmapping = packed record
          Unicode : TUnicodeChar;
          Char1   : Byte;
          Char2   : Byte;
       end;

       punicodemap = ^TUnicodeMap;
       tunicodemap = record
          CPName : string[20];
          CP : Word;
          Map : PUnicodeCharMapping;
          LastChar : LongInt;
          ReverseMap : PReverseCharMapping;
          ReverseMapLength : LongInt;
          Next : PUnicodeMap;
          InternalMap : Boolean;
       end;

       TSerializedMapHeader = packed record
          CPName           : string[20];
          CP               : UInt16;
          MapLength        : UInt32;
          LastChar         : Int32;
          ReverseMapLength : UInt32;
       end;

    const
      BinaryMappingFileExt = '.bcm';

    function LoadUnicodeMapping(const CPName,F : string; CP :Word) : PUnicodeMap;
    function LoadBinaryUnicodeMapping(const Directory,CPName : string) : PUnicodeMap;overload;
    function LoadBinaryUnicodeMapping(const FileName : string) : PUnicodeMap;overload;
    function LoadBinaryUnicodeMapping(
      const AData       : Pointer;
      const ADataLength : Integer
    ) : PUnicodeMap;overload;
    procedure RegisterMapping(P : PUnicodeMap);
    function RegisterBinaryMapping(const Directory,CPName : string):Boolean;
    function GetMap(const S : string) : PUnicodeMap;
    function GetMap(CP : Word) : PUnicodeMap;
    function MappingAvailable(const S : string) : Boolean;inline;
    function MappingAvailable(CP :Word) : Boolean;inline;
    function GetUnicode(C : AnsiChar;P : PUnicodeMap) : TUnicodeChar;inline;
    function GetUnicode(
      AAnsiStr : PAnsiChar;
      AAnsiLen : LongInt;
      AMap     : PUnicodeMap;
      ADest    : TUnicodeString
    ) : LongInt;
    function GetASCII(C : TUnicodeChar;P : PUnicodeMap) : AnsiString;
    function GetASCII(C : TUnicodeChar;P : PUnicodeMap; ABuffer : PAnsiChar; ABufferLen : LongInt) : LongInt;

  implementation

    const
      UnknownCharA = AnsiChar(63);
      UnknownCharW = TUnicodeChar(63);
    var
       Mappings : PUnicodeMap;


    procedure QuickSort(AList: PReverseCharMapping; L, R : LongInt);
    var
      I, J : LongInt;
      P, Q : TReverseCharMapping;
    begin
      repeat
        I:=L;
        J:=R;
        P:=AList[(L + R) div 2];
        repeat
          while (P.Unicode-AList[I].Unicode) > 0 do
            I:=I+1;
          while (P.Unicode-AList[J].Unicode) < 0 do
            J:=J-1;
          if I<=J then
            begin
              Q:=AList[I];
              AList[I]:=AList[J];
              AList[J]:=Q;
              I:=I+1;
              J:=J-1;
            end;
        until I > J;
        if J-L < R-I then
          begin
            if L<J then
              QuickSort(AList, L, J);
            L:=I;
          end
        else
          begin
            if I < R then
              QuickSort(AList, I, R);
            R:=J;
          end;
      until L>=R;
    end;

    function Find(
      const C     : TUnicodeChar;
      const AData : PReverseCharMapping;
      const ALen  : LongInt
    ) : PReverseCharMapping;overload;
    var
       L, H, M : LongInt;
       R:PReverseCharMapping;
    begin
      if ALen=0 then
        Exit(nil);
      R:=AData;
      L:=0;
      H:=ALen-1;
      while L<H do begin
        M:=(L+H) div 2;
        if R[M].Unicode<C then
          L:=M+1
        else
          H:=M;
      end;
      if (L=H) and (R[L].Unicode=C) then
        Result:=@R[L]
      else
        Result:=nil;
    end;

    function Find(
      const C : TUnicodeChar;
      const P : PUnicodeMap
    ) : PReverseCharMapping;overload;inline;
    begin
      Result:=Find(C,P^.ReverseMap,P^.ReverseMapLength);
    end;

    function RemoveDuplicates(
      const AData      : PReverseCharMapping;
      const ALen       : LongInt;
      out   AResultLen : LongInt
    ) : PReverseCharMapping;
    var
      R0, R, P, T : PReverseCharMapping;
      I, C, ActualCount : LongInt;
    begin
      C:=ALen;
      GetMem(R0,C*SizeOf(TReverseCharMapping));
      R:=R0;
      P:=AData;
      ActualCount:=0;
      I:=0;
      while I<C do
        begin
          T:=Find(P^.Unicode,R0,ActualCount);
          if T=nil then
            begin
              R^:=P^;
              ActualCount:=ActualCount+1;
              Inc(R);
            end
          else
            begin
              if (P^.Char1<T^.Char1) or
                 ((P^.Char1=T^.Char1) and (P^.Char2<T^.Char2))
              then
                T^:=P^;//keep the first mapping
            end;
          I:=I+1;
          Inc(P);
        end;
      if C<>ActualCount then
        ReAllocMem(R0,ActualCount*SizeOf(TReverseCharMapping));
      AResultLen:=ActualCount;
      Result:=R0;
    end;

    function BuildReverseMap(
      const AMapping   : PUnicodeCharMapping;
      const ALen       : LongInt;
      out   AResultLen : LongInt
    ) : PReverseCharMapping;
    var
      R0, R, T : PReverseCharMapping;
      I, C, ActualCount, TI : LongInt;
      P : PUnicodeCharMapping;
    begin
      if (ALen<1) then
        Exit(nil);
      P:=AMapping;
      C:=ALen;
      GetMem(R0,C*SizeOf(TReverseCharMapping));
      R:=R0;
      ActualCount:=0;
      I:=0;
      while I<C do
        begin
          if (P^.Flag=umf_noinfo) then
            begin
              R^.Unicode:=P^.Unicode;
              if I<=High(Byte) then
                begin
                  R^.Char1:=I;
                  R^.Char2:=0;
                end
              else
                begin
                  R^.Char1:=I div 256;
                  R^.Char2:=I mod 256;
                end;
              ActualCount:=ActualCount+1;
              Inc(R);
            end;
          Inc(P);
          I:=I+1;
        end;
      if C<>ActualCount then
        ReAllocMem(R0,ActualCount*SizeOf(TReverseCharMapping));
      if ActualCount>1 then
        begin
          QuickSort(R0,0,(ActualCount-1));
          T:=RemoveDuplicates(R0,ActualCount,TI);
          FreeMem(R0,ActualCount*SizeOf(TReverseCharMapping));
          R0:=T;
          ActualCount:=TI;
        end;
      AResultLen:=ActualCount;
      Result:=R0;
    end;

    procedure InitItems(const P : PUnicodeCharMapping; const ALen : LongInt);
    const
      InitItem : TUnicodeCharMapping = (Unicode:0; Flag:umf_unused; Reserved:0);
    var
      X : PUnicodeCharMapping;
      I : LongInt;
    begin
      X:=P;
      for I:=0 to ALen-1 do
        begin
          X^:=InitItem;
          Inc(X);
        end;
    end;

    function LoadUnicodeMapping(const CPName,F : string; CP :Word) : PUnicodeMap;

      var
         Data : PUnicodeCharMapping;
         DataSize : LongInt;
         T : Text;
         S,HS : string;
         ScanPos,CharPos,UnicodeValue : LongInt;
         Code : Word;
         Flag : TUnicodeCharMappingFlag;
         P : PUnicodeMap;
         LastChar, I : LongInt;

      begin
         LastChar:=-1;
         LoadUnicodeMapping:=nil;
         DataSize:=256;
         GetMem(Data,SizeOf(TUnicodeCharMapping)*DataSize);
         InitItems(Data,DataSize);
         Assign(T,F);
         {$I-}
         Reset(T);
         {$I+}
         if IOResult<>0 then
           begin
              FreeMem(Data,SizeOf(TUnicodeCharMapping)*DataSize);
              Exit;
           end;
         while not(EOF(T)) do
           begin
              ReadLn(T,S);
              if (S[1]='0') and (S[2]='x') then
                begin
                   Flag:=umf_unused;
                   ScanPos:=3;
                   HS:='$';
                   while S[ScanPos] in ['0'..'9','A'..'F','a'..'f'] do
                     begin
                        HS:=HS+S[ScanPos];
                        Inc(ScanPos);
                     end;
                   Val(HS,CharPos,Code);
                   if Code<>0 then
                     begin
                        FreeMem(Data,SizeOf(TUnicodeCharMapping)*DataSize);
                        Close(T);
                        Exit;
                     end;
                   while not(S[ScanPos] in ['0','#']) do
                     Inc(ScanPos);
                   if S[ScanPos]='#' then
                     begin
                        { special char }
                        UnicodeValue:=$ffff;
                        HS:=Copy(S,ScanPos,Length(S)-ScanPos+1);
                        if HS='#DBCS LEAD BYTE' then
                          Flag:=umf_leadbyte;
                     end
                   else
                     begin
                        { C hex prefix }
                        Inc(ScanPos,2);
                        HS:='$';
                        while S[ScanPos] in ['0'..'9','A'..'F','a'..'f'] do
                          begin
                             HS:=HS+S[ScanPos];
                             Inc(ScanPos);
                          end;
                        Val(HS,UnicodeValue,Code);
                        if Code<>0 then
                          begin
                             FreeMem(Data,SizeOf(TUnicodeCharMapping)*DataSize);
                             Close(T);
                             Exit;
                          end;
                        if CharPos>DataSize then
                          begin
                             { allocate 1024 bytes more because         }
                             { if we need more than 256 entries it's    }
                             { probably a mbcs with a lot of            }
                             { entries                                  }
                             I:=DataSize;
                             DataSize:=CharPos+8*1024;
                             ReAllocMem(Data,SizeOf(TUnicodeCharMapping)*DataSize);
                             InitItems(@Data[I],(DataSize-I));
                          end;
                        Flag:=umf_noinfo;
                     end;
                   Data[CharPos].Flag:=Flag;
                   Data[CharPos].Unicode:=UnicodeValue;
                   if CharPos>LastChar then
                     LastChar:=CharPos;
                end;
           end;
         Close(T);
         New(P);
         P^.LastChar:=LastChar;
         P^.CPName:=CPName;
         P^.CP:=CP;
         P^.InternalMap:=False;
         P^.Next:=nil;
         P^.Map:=Data;
         P^.ReverseMap:=BuildReverseMap(P^.Map,(P^.LastChar+1),P^.ReverseMapLength);
         LoadUnicodeMapping:=P;
      end;


    function LoadBinaryUnicodeMapping(const Directory, CPName : string) : PUnicodeMap;
      const
        {$IFDEF ENDIAN_LITTLE}
          EndianSuffix = 'le';
        {$ENDIF ENDIAN_LITTLE}
        {$IFDEF ENDIAN_BIG}
          EndianSuffix = 'be';
        {$ENDIF ENDIAN_BIG}
      var
        FileName : string;
      begin
        FileName := Directory;
        if (FileName <> '') then begin
          if (FileName[Length(FileName)] <> DirectorySeparator) then
            FileName := FileName + DirectorySeparator;
        end;
        FileName := FileName + CPName + '_' + EndianSuffix + BinaryMappingFileExt;
        Result := LoadBinaryUnicodeMapping(FileName);
      end;

    {$PUSH}
      {$I-}
    function LoadBinaryUnicodeMapping(const FileName : string) : PUnicodeMap;
      const
        BlockSize = 16*1024;
      var
        F : File of Byte;
        LocSize, LocReaded, C : LongInt;
        LocBuffer : PByte;
        LocBlockSize : LongInt;
      begin
        Result := nil;
        if (FileName='') then
          Exit;
        Assign(F,FileName);
        Reset(F);
        if (IOResult<>0) then
          Exit;
        LocSize:=FileSize(F);
        if (LocSize<SizeOf(TSerializedMapHeader)) then
          begin
            Close(F);
            Exit;
          end;
        LocBuffer:=GetMem(LocSize);
        LocBlockSize:=BlockSize;
        LocReaded:=0;
        C := 0;
        while (LocReaded<LocSize) do
          begin
            if (LocBlockSize>(LocSize-LocReaded)) then
              LocBlockSize:=LocSize-LocReaded;
            BlockRead(F,LocBuffer[LocReaded],LocBlockSize,C);
            if (IOResult<>0) or (C<=0) then
              begin
                FreeMem(LocBuffer,LocSize);
                Close(F);
                Exit;
              end;
            LocReaded:=LocReaded+C;
          end;
        Result:=LoadBinaryUnicodeMapping(LocBuffer,LocSize);
        FreeMem(LocBuffer,LocSize);
        Close(F);
      end;
    {$POP}

    procedure FreeMapping(AMapping : PUnicodeMap);
      begin
        if (AMapping = nil) then
          Exit;
        if (AMapping^.Map <> nil) then
          FreeMem(AMapping^.Map);
        if (AMapping^.ReverseMap <> nil) then
          FreeMem(AMapping^.ReverseMap);
        Dispose(AMapping);
      end;

    function LoadBinaryUnicodeMapping(
      const AData       : Pointer;
      const ADataLength : Integer
    ) : PUnicodeMap;
      var
        DataPointer : PByte;
        ReadedLength : LongInt;

        function ReadBuffer(ADest : Pointer; ALength : LongInt) : Boolean;
          begin
            Result := (ReadedLength + ALength) <= ADataLength;
            if not Result then
              Exit;
            Move(DataPointer^,ADest^,ALength);
            Inc(DataPointer,ALength);
            ReadedLength := ReadedLength + ALength;
          end;

      var
        H : TSerializedMapHeader;
        R : PUnicodeMap;
      begin
        Result := nil;
        ReadedLength := 0;
        DataPointer := AData;
        if not ReadBuffer(@H,SizeOf(H)) then
          Exit;
        New(R);
        FillChar(R^,SizeOf(TUnicodeMap),0);
        R^.CPName := H.CPName;
        R^.CP := H.CP;
        R^.Map := AllocMem(H.MapLength);
        if not ReadBuffer(R^.Map,H.MapLength) then
          begin
            FreeMapping(R);
            Exit;
          end;
        R^.LastChar := H.LastChar;
        R^.ReverseMap := AllocMem(H.ReverseMapLength);
        if not ReadBuffer(R^.ReverseMap,H.ReverseMapLength) then
          begin
            FreeMapping(R);
            Exit;
          end;
        R^.ReverseMapLength := (H.ReverseMapLength div SizeOf(TReverseCharMapping));
        Result := R;
      end;

    procedure RegisterMapping(P : PUnicodeMap);

      begin
         P^.Next:=Mappings;
         Mappings:=P;
      end;

    {$ifdef FPC_HAS_FEATURE_THREADING}
    threadvar
    {$else FPC_HAS_FEATURE_THREADING}
    var
    {$endif FPC_HAS_FEATURE_THREADING}
      StrMapCache : string;
      StrMapCacheP : PUnicodeMap;

    function RegisterBinaryMapping(const Directory, CPName : string) : Boolean;
      var
        P : PUnicodeMap;
      begin
        Result := False;
        P := LoadBinaryUnicodeMapping(Directory,CPName);
        if (P = nil) then
          Exit;
        RegisterMapping(P);
        Result := True;
      end;

    function GetMap(const S : string) : PUnicodeMap;

      var
         HP : PUnicodeMap;

      begin
         if (StrMapCache=S) and Assigned(StrMapCacheP) and (StrMapCacheP^.CPName=S) then
           begin
              GetMap:=StrMapCacheP;
              Exit;
           end;
         HP:=Mappings;
         while Assigned(HP) do
           begin
              if HP^.CPName=S then
                begin
                   GetMap:=HP;
                   StrMapCache:=S;
                   StrMapCacheP:=HP;
                   Exit;
                end;
              HP:=HP^.Next;
           end;
         GetMap:=nil;
      end;////////


    {$ifdef FPC_HAS_FEATURE_THREADING}
    threadvar
    {$else FPC_HAS_FEATURE_THREADING}
    var
    {$endif FPC_HAS_FEATURE_THREADING}
      IntMapCache : Word;
      IntMapCacheP : PUnicodeMap;
    function GetMap(CP : Word) : PUnicodeMap;

      var
         HP : PUnicodeMap;

      begin
         if (IntMapCache=CP) and Assigned(IntMapCacheP) and (IntMapCacheP^.CP=CP) then
           begin
              GetMap:=IntMapCacheP;
              Exit;
           end;
         HP:=Mappings;
         while Assigned(HP) do
           begin
              if HP^.CP=CP then
                begin
                   GetMap:=HP;
                   IntMapCache:=CP;
                   IntMapCacheP:=HP;
                   Exit;
                end;
              HP:=HP^.Next;
           end;
         GetMap:=nil;
      end;

    function MappingAvailable(const S : string) : Boolean;

      begin
         MappingAvailable:=GetMap(S)<>nil;
      end;

    function MappingAvailable(CP : Word) : Boolean;

      begin
         MappingAvailable:=GetMap(CP)<>nil;
      end;

    function GetUnicode(C : AnsiChar;P : PUnicodeMap) : TUnicodeChar;

      begin
         if Ord(C)<=P^.LastChar then
           GetUnicode:=P^.Map[Ord(C)].Unicode
         else
           GetUnicode:=0;
      end;

    function GetUnicode(
      AAnsiStr : PAnsiChar;
      AAnsiLen : LongInt;
      AMap     : PUnicodeMap;
      ADest    : TUnicodeString
    ) : LongInt;

      var
         I, C, K, DestLen : LongInt;
         PS : PAnsiChar;
         PD : ^TUnicodeChar;

      begin
        if (AAnsiStr=nil) or (AAnsiLen<=0) then
          Exit(0);
        PS:=AAnsiStr;
        if (ADest=nil) then
          begin
            C:=AAnsiLen-1;
            DestLen:=0;
            I:=0;
            while (I<=C) do
              begin
                if (Ord(PS^)<=AMap^.LastChar) then
                  begin
                    if (AMap^.Map[Ord(PS^)].Flag=umf_leadbyte) and (I<C) then
                      begin
                        Inc(PS);
                        I:=I+1;
                      end;
                  end;
                I:=I+1;
                Inc(PS);
                DestLen:=DestLen+1;
              end;
            Exit(DestLen);
          end;

        PD:=ADest;
        C:=AAnsiLen-1;
        I:=0;
        while (I<=C) do
          begin
            if (Ord(PS^)<=AMap^.LastChar) then
              begin
                if (AMap^.Map[Ord(PS^)].Flag=umf_leadbyte) then
                  begin
                    if (I<C) then
                      begin
                        K:=(Ord(PS^)*256);
                        Inc(PS);
                        I:=I+1;
                        K:=K+Ord(PS^);
                        if (K<=AMap^.LastChar) then
                          PD^:=AMap^.Map[K].Unicode
                        else
                          PD^:=UnknownCharW;
                      end
                    else
                      PD^:=UnknownCharW;
                  end
                else
                  PD^:=AMap^.Map[Ord(PS^)].Unicode
              end
            else
              PD^:=UnknownCharW;
            I:=I+1;
            Inc(PS);
            Inc(PD);
          end;
        Result:=((PtrUInt(PD)-PtrUInt(ADest)) div SizeOf(TUnicodeChar));
      end;

    function GetASCII(C : TUnicodeChar;P : PUnicodeMap) : AnsiString;
      var
         RM : PReverseCharMapping;
      begin
        RM:=Find(C,P);
        if RM<>nil then
          begin
            if RM^.Char2=0 then
              begin
                SetLength(Result,1);
                Byte(Result[1]):=RM^.Char1;
              end
            else
              begin
                SetLength(Result,2);
                Byte(Result[1]):=RM^.Char1;
                Byte(Result[2]):=RM^.Char2;
              end;
          end
        else
          Result:=UnknownCharA;
      end;

    function GetASCII(C : TUnicodeChar;P : PUnicodeMap; ABuffer : PAnsiChar; ABufferLen : LongInt) : LongInt;
      var
         RM : PReverseCharMapping;
      begin
         if (ABuffer<>nil) and (ABufferLen<=0) then
           Exit(-1);
        RM:=Find(C,P);
        if RM<>nil then
          begin
            if (ABuffer=nil) then
              begin
                if RM^.Char2=0 then
                  Result:=1
                else
                  Result:=2;
              end
            else
              begin
                if RM^.Char2=0 then
                  begin
                    Byte(ABuffer^):=RM^.Char1;
                    Result:=1;
                  end
                else
                  begin
                    if (ABufferLen<2) then
                      Result:=-1
                    else
                      begin
                        Byte(ABuffer^):=RM^.Char1;
                        Byte((ABuffer+1)^):=RM^.Char2;
                        Result:=2;
                      end
                  end;
              end;
          end
        else
          begin
            ABuffer^:=UnknownCharA;
            Result:=1;
          end;
      end;

  var
     HP : PUnicodeMap;

initialization
  Mappings:=nil;
finalization
  while Assigned(Mappings) do
    begin
       HP:=Mappings^.Next;
       if not(Mappings^.InternalMap) then
         begin
            FreeMem(Mappings^.Map);
            FreeMem(Mappings^.ReverseMap);
            Dispose(Mappings);
         end;
       Mappings:=HP;
    end;
end.
