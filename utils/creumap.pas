{
    This file is part of the Free Pascal run time library.
    Copyright (c) 2000 by Florian Klaempfl

    It creates pascal units from unicode mapping files

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
program CreUMap;

  uses
     CharSet;

  procedure DoError;

    begin
       WriteLn('Usage: creumap <cpname> <cpnumber>');
       WriteLn('cpname : A mapping file called <cpname>.txt must be present');
       WriteLn('cpnumber : the code page number');
       Halt(1);
    end;

type
  TEndianKind = (Little, Big);
const
  EndianSuffix : array[TEndianKind] of string[2] = ('le','be');
  EndianNative     = TEndianKind.Little;
  EndianNonNative = TEndianKind.Big;

  procedure CreateBinaryFile(AMap : PUnicodeMap; const ABaseFile : string);

    var
       Nef, Oef : File of Byte;
       H, TH : TSerializedMapHeader;
       K : LongInt;
       UM : TUnicodeCharMapping;
       PUM : PUnicodeCharMapping;
       RM : TReverseCharMapping;
       PRM : PReverseCharMapping;
    begin
       FillChar(H,SizeOf(H),0);
       H.CPName := AMap^.CPName;
       H.CP := AMap^.CP;
       H.LastChar := AMap^.LastChar;
       H.MapLength := (AMap^.LastChar+1)*SizeOf(TUnicodeCharMapping);
       H.ReverseMapLength := AMap^.ReverseMapLength*SizeOf(TReverseCharMapping);
       Assign(Nef,(ABaseFile+'_'+EndianSuffix[EndianNative]+'.bcm'));
       Rewrite(Nef);
       BlockWrite(Nef,H,SizeOf(H));
       BlockWrite(Nef,AMap^.Map^,H.MapLength);
       BlockWrite(Nef,AMap^.ReverseMap^,H.ReverseMapLength);
       Close(Nef);

       FillChar(TH,SizeOf(TH),0);
       TH.CPName := H.CPName;
       TH.CP := SwapEndian(H.CP);
       TH.MapLength := SwapEndian(H.MapLength);
       TH.LastChar := SwapEndian(H.LastChar);
       TH.ReverseMapLength := SwapEndian(H.ReverseMapLength);
       Assign(Oef,(ABaseFile+'_'+EndianSuffix[EndianNonNative]+'.bcm'));
       Rewrite(Oef);
       BlockWrite(Oef,TH,SizeOf(TH));
       PUM := AMap^.Map;
       FillChar(UM,SizeOf(UM),0);
       for K := 0 to AMap^.LastChar do begin
          UM.Flag := PUM^.Flag;
          UM.Reserved := PUM^.Reserved;
          UM.Unicode := SwapEndian(PUM^.Unicode);
          BlockWrite(Oef,UM,SizeOf(UM));
          Inc(PUM);
       end;
       PRM := AMap^.ReverseMap;
       FillChar(RM,SizeOf(RM),0);
       for K := 0 to AMap^.ReverseMapLength - 1 do begin
         RM.Unicode := SwapEndian(PRM^.Unicode);
         RM.Char1 := PRM^.Char1;
         RM.Char2 := PRM^.Char2;
         BlockWrite(Oef,RM,SizeOf(RM));
         Inc(PRM);
       end;
       Close(Oef);
    end;

  var
     P : PUnicodeMap;
     I : LongInt;
     T : Text;
     E : Word;
     C : LongInt;

begin
   if ParamCount<>2 then
     DoError;
   Val(ParamStr(2),I,E);
   if E<>0 then
     DoError;

   P:=LoadUnicodeMapping(ParamStr(1),ParamStr(1)+'.txt',I);
   if P=nil then
     DoError;
   Assign(T,ParamStr(1)+'.pas');
   Rewrite(T);
   WriteLn(T,'{ This is an automatically created file, so don''t edit it }');
   WriteLn(T,'unit ',P^.CPName,';');
   WriteLn(T);
   WriteLn(T,'  interface');
   WriteLn(T);
   WriteLn(T,'  implementation');
   WriteLn(T);
   WriteLn(T,'  uses');
   WriteLn(T,'     CharSet;');
   WriteLn(T);
   WriteLn(T,'  const');
   WriteLn(T,'     Map : array[0..',P^.LastChar,'] of TUnicodeCharMapping = (');
   for I:=0 to P^.LastChar do
     begin
        Write(T,'       (Unicode : ',P^.Map[I].Unicode,'; Flag : ');
        case P^.Map[I].Flag of
           umf_noinfo : Write(T,'umf_noinfo');
           umf_leadbyte : Write(T,'umf_leadbyte');
           umf_undefined : Write(T,'umf_undefined');
           umf_unused : Write(T,'umf_unused');
        end;
        Write(T,'; Reserved: 0)');
        if I<>P^.LastChar then
          WriteLn(T,',')
        else
          WriteLn(T);
     end;
   WriteLn(T,'     );');
   WriteLn(T);
   C:=P^.ReverseMapLength-1;
   WriteLn(T,'     ReverseMap : array[0..',C,'] of TReverseCharMapping = (');
   for I:=0 to C do
     begin
        Write(T,'       (',
                'Unicode : ',P^.ReverseMap[I].Unicode,
                '; Char1 : ',P^.ReverseMap[I].Char1,
                '; Char2 : ',P^.ReverseMap[I].Char2,
                ')'
        );
        if I<>C then
          WriteLn(T,',')
        else
          WriteLn(T);
     end;
   WriteLn(T,'     );');
   WriteLn(T);
   WriteLn(T,'     UnicodeMap : TUnicodeMap = (');
   WriteLn(T,'       CPName : ''',P^.CPName,''';');
   WriteLn(T,'       CP : ',P^.CP,';');
   WriteLn(T,'       Map : @Map;');
   WriteLn(T,'       LastChar : ',P^.LastChar,';');
   WriteLn(T,'       ReverseMap : @ReverseMap;');
   WriteLn(T,'       ReverseMapLength : ',P^.ReverseMapLength,';');
   WriteLn(T,'       Next : nil;');
   WriteLn(T,'       InternalMap : True');
   WriteLn(T,'     );');
   WriteLn(T);
   WriteLn(T,'  begin');
   WriteLn(T,'     RegisterMapping(@UnicodeMap)');
   WriteLn(T,'  end.');
   Close(T);

   CreateBinaryFile(P,ParamStr(1));
end.
