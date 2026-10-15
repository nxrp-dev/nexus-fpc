{
    Copyright (c) 1998-2002 by Michael van Canneyt

    Handles resourcestrings

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
unit cresstr;

{$i fpcdefs.inc}

interface

    Procedure GenerateResourceStrings;


implementation

uses
   SysUtils,
   CClasses,WideStr,
   CUtils,GlobType,Globals,Systems,
   SymBase,SymConst,SymType,DefUtil, SymDef,SymSym,SymTable,
   Verbose,FModule,PPU,
   AAsmTai,AAsmData,AAsmCnst,
   AAsmCPU;

    Type
      { These are used to form a singly-linked list, ordered by hash value }
      TResourceStringItem = class(TLinkedListItem)
        Sym   : TConstSym;
        Name  : String;
        AValue : TAnsiCharDynArray;
        WValue : TCompilerWideString; // just a reference, do not free.
        Len   : LongInt; // in bytes, not characters
        Hash  : Cardinal;
        IsUnicode : Boolean;
        constructor Create(ASym:TConstSym);
        destructor  Destroy;override;
        procedure CalcHash;
      end;

      Tresourcestrings=class
      private
        List : TLinkedList;
        procedure ConstSymRegister(P:TObject;Arg:Pointer);
      public
        constructor Create;
        destructor  Destroy;override;
        procedure CreateResourceStringData;
        procedure WriteRSJFile;
        procedure RegisterResourceStrings;
      end;



{ ---------------------------------------------------------------------
                          TRESOURCESTRING_ITEM
  ---------------------------------------------------------------------}

    constructor TResourceStringItem.Create(ASym:TConstSym);

    var
      PW : TCompilerWideString;
      T : TDef;

      begin
        inherited Create;
        Sym:=ASym;
        Name:=Lower(ASym.Owner.Name^+'.'+ASym.Name);
        IsUnicode:=is_systemunit_unicode;
        if IsUnicode then
          begin
          T:=ASym.ConstDef;
          WValue:=ASym.Value.ValueWS;
          Len:=WValue.Len*SizeOf(TCompilerWideChar);
          end
        else
          begin
          Len:=ASym.Value.Len;
          SetLength(AValue,Len);
          if Len>0 then
            Move(ASym.Value.ValuePtr^,AValue[0],Len);
          end;
        CalcHash;
      end;


    destructor TResourceStringItem.Destroy;
      begin
        AValue:=nil;
      end;


    procedure TResourceStringItem.CalcHash;
      Var
        G : Cardinal;
        LLen,WLen,I : LongInt;
        P : PByte;
        PC : PAnsiChar;

      begin
        PC:=nil;
        Hash:=0;
        if IsUnicode then
          begin
          // Need to calculate hash on UTF8 encoded string, GNU gettext.
          LLen:=UnicodeToUtf8(nil,0,PUnicodeChar(WValue.Data),WValue.Len);
          GetMem(PC,LLen);
          UnicodeToUtf8(PC,LLen,WValue.AsConstPUnicodeChar,Len);
          P:=PByte(PC);
          LLen:=LLen-1; // Take of terminating #0
          end
        else
          begin
          LLen:=Len;
          P:=PByte(AValue);
          end;
        For I:=0 to LLen-1 do { 0 terminated }
         begin
           Hash:=Hash shl 4;
           Inc(Hash,P[I]);
           G:=Hash and ($f shl 28);
           if G<>0 then
            begin
              Hash:=Hash xor (G shr 24);
              Hash:=Hash xor G;
            end;
         end;
        if Assigned(PC) then
          FreeMem(PC);
        If Hash=0 then
          Hash:=$ffffffff;
      end;


{ ---------------------------------------------------------------------
                          Tresourcestrings
  ---------------------------------------------------------------------}

    Constructor TResourceStrings.Create;
      begin
        List:=TAsmList.Create;
      end;


    Destructor TResourceStrings.Destroy;
      begin
        List.Free;
        List := nil;
      end;


    procedure TResourceStrings.CreateResourceStringData;
      Var
        NameLab,
        ValueLab : TAsmLabOfs;
        R : TResourceStringItem;
        ResStrDef: TDef;
        TCB : TTAITypedConstBuilder;
        Enc : TStringEncoding;
        CharLen : LongInt;
        ST : TStringType;
        StrCharPointerType: TDef;

      begin
        ResStrDef:=Search_System_Type('TRESOURCESTRINGRECORD').TypeDef;

        TCB:=CTAITypedConstBuilder.Create([tcalo_vectorized_dead_strip_start,tcalo_data_force_indirect,tcalo_is_public_asm]);
        { Write unitname entry }
        TCB.maybe_begin_aggregate(ResStrDef);
        NameLab:=TCB.emit_ansistring_const(CurrentAsmData.AsmLists[al_const],@CurrentModule.LocalSymTable.Name^[1],Length(CurrentModule.LocalSymTable.Name^),GetAnsiStringCodePage);
        TCB.emit_string_offset(NameLab,Length(CurrentModule.LocalSymTable.Name^),st_ansistring,False,CharPointerType);
        TCB.emit_tai(TAIConst.create_nil_dataptr,CAnsiStringType);
        TCB.emit_tai(TAIConst.create_nil_dataptr,CAnsiStringType);
        TCB.emit_ord_const(0,U32IntType);
        TCB.maybe_end_aggregate(ResStrDef);
        CurrentAsmData.AsmLists[al_resourcestrings].ConcatList(
          TCB.get_final_asmlist_vectorized_dead_strip(
            nil,ResStrDef,'RESSTR','',CurrentModule.LocalSymTable,SizeOf(PInt)
          )
        );
        TCB.Free;

        { Add entries }
        R:=TResourceStringItem(List.First);
        while Assigned(R) do
          begin
            TCB:=CTAITypedConstBuilder.Create([tcalo_vectorized_dead_strip_item,tcalo_data_force_indirect]);
            ValueLab.Lab:=nil;
            ValueLab.Ofs:=0;
            CharLen:=R.Len;
            ST:=st_ansistring;
            StrCharPointerType:=CharPointerType;;
            if (R.Len<>0) then
              begin
              if R.IsUnicode and Assigned(R.WValue) then
                begin
                  Enc:=TStringDef(CUnicodeStringType).Encoding;
                  ValueLab:=TCB.emit_unicodestring_const(CurrentAsmData.AsmLists[al_const],R.WValue,Enc,False);
                  CharLen:=GetLengthWideString(R.WValue);
                  ST:=st_unicodestring;
                  StrCharPointerType:=WideCharPointerType;;
                end
              else
                begin
                  if Assigned(R.AValue) then
                    ValueLab:=TCB.emit_ansistring_const(CurrentAsmData.AsmLists[al_const],PAnsiChar(R.AValue),R.Len,GetAnsiStringCodePage);
                end;
              end;
            CurrentAsmData.AsmLists[al_const].Concat(CAIAlign.Create(SizeOf(PInt)));
            NameLab:=TCB.emit_ansistring_const(CurrentAsmData.AsmLists[al_const],@R.Name[1],Length(R.Name),GetAnsiStringCodePage);
            {
              Resourcestring index:
                  TResourceStringRecord = Packed Record
                     Name: AnsiString;
                     CurrentValue,
                     DefaultValue : AnsiString/Widestring;
                     HashValue    : LongWord;
                   end;
            }
            TCB.maybe_begin_aggregate(ResStrDef);
            TCB.emit_string_offset(NameLab,Length(R.Name),st_ansistring,False,CharPointerType);
            TCB.emit_string_offset(ValueLab,CharLen,ST,False,StrCharPointerType);
            TCB.emit_string_offset(ValueLab,CharLen,ST,False,StrCharPointerType);
            TCB.emit_ord_const(R.Hash,U32IntType);
            TCB.maybe_end_aggregate(ResStrDef);
            CurrentAsmData.AsmLists[al_resourcestrings].ConcatList(
              TCB.get_final_asmlist_vectorized_dead_strip(
                R.Sym,ResStrDef,'RESSTR',R.Sym.Name,R.Sym.Owner,SizeOf(PInt))
            );
            R:=TResourceStringItem(R.Next);
            TCB.Free;
            TCB := nil;
          end;
        TCB:=CTAITypedConstBuilder.Create([tcalo_vectorized_dead_strip_end,tcalo_data_force_indirect,tcalo_is_public_asm]);
        TCB.begin_anonymous_record(InternalTypePrefixName[itp_emptyrec],
          Default_Settings.PackRecords,SizeOf(PInt),
          TargetInfos[Ord(TargetInfo.System)]^.Alignment.RecordAlignMin);
        CurrentAsmData.AsmLists[al_resourcestrings].ConcatList(
          TCB.get_final_asmlist_vectorized_dead_strip(
            nil,TCB.end_anonymous_record,'RESSTR','',CurrentModule.LocalSymTable,SizeOf(PInt)
          )
        );
        TCB.Free;
        TCB := nil;
      end;

    procedure TResourceStrings.WriteRSJFile;
      Var
        F: Text;
        R: TResourceStringItem;
        ResFileName: string;
        I,Len: Integer;
        C: TCompilerWideChar;
        W: TCompilerWideString;
        P : PByte;

      begin
        ResFileName:=ChangeFileExt(CurrentModule.PPUFileName,'.rsj');
        Message1 (general_i_writingresourcefile,ExtractFileName(ResFileName));
        Assign(F,ResFileName);
        {$push}{$i-}
        Rewrite(F);
        {$pop}
        if IOResult<>0 then
          begin
            Message1(general_e_errorwritingresourcefile,ResFileName);
            Exit;
          end;
        { write the data in two formats:
           a) backward compatible: the plain bytes from the source file
           b) portable: converted to utf-16
        }
        WriteLn(F,'{"version":1,"strings":[');
        R:=TResourceStringItem(List.First);
        while Assigned(R) do
          begin
            Write(F, '{"hash":',R.Hash,',"name":"',R.Name,'","sourcebytes":[');
            if R.IsUnicode then
              P:=PByte(R.WValue.AsConstPUnicodeChar)
            else
              P:=PByte(R.AValue);
            for I:=0 to R.Len-1 do
              begin
                Write(F,P[I]);
                if I<>R.Len-1 then
                  Write(F,',');
              end;
            Write(F,'],"value":"');
            if Not R.IsUnicode then
              begin
              InitWideString(W);
              ASCII2Unicode(PAnsiChar(R.AValue),R.Len,CurrentSettings.SourceCodePage,W);
              end
            else
              begin
              W:=R.WValue;
              end;
            for I := 0 to W.Len - 1 do
              begin
                C := W.Data[I];
                case C of
                  Ord('"'), Ord('\'), Ord('/'):
                    Write(F, '\', Chr(C));
                  8:
                    Write(F, '\b');
                  9:
                    Write(F, '\t');
                  10:
                    Write(F, '\n');
                  13:
                    Write(F, '\r');
                  12:
                    Write(F, '\f');
                  else
                  if (C < 32) or (C > 127) then
                    Write(F,'\u',HexStr(LongInt(C), 4))
                  else
                    Write(F,Chr(C));
                end;
              end;
            if W<>R.WValue then
              DoneWideString(W);
            Write(F,'"}');
            R:=TResourceStringItem(R.Next);
            if Assigned(R) then
              WriteLn(F,',')
            else
              WriteLn(F);
          end;
        WriteLn(F,']}');
        Close(F);
      end;

    procedure TResourceStrings.ConstSymRegister(P:TObject;Arg:Pointer);
      begin
        if (TSym(P).Typ=ConstSym) and
           (TConstSym(P).ConstTyp in [ConstResourceString,ConstWResourceString]) then
          List.Concat(TResourceStringItem.Create(TConstSym(P)));
      end;


    procedure TResourceStrings.RegisterResourceStrings;
      begin
        if Assigned(CurrentModule.GlobalSymTable) then
          CurrentModule.GlobalSymTable.SymList.ForEachCall(@ConstSymRegister,nil);
        CurrentModule.LocalSymTable.SymList.ForEachCall(@ConstSymRegister,nil);
      end;


    Procedure GenerateResourceStrings;
      var
        ResStrs : TResourceStrings;
      begin
        { needed for the typed constant defs that get generated/looked up }
        if Assigned(CurrentModule.GlobalSymTable) then
          SymTableStack.Push(CurrentModule.GlobalSymTable);
        SymTableStack.Push(CurrentModule.LocalSymTable);
        ResStrs:=TResourceStrings.Create;
        ResStrs.RegisterResourceStrings;
        if not ResStrs.List.Empty then
          begin
            Include(CurrentModule.ModuleFlags,mf_has_resourcestrings);
            ResStrs.CreateResourceStringData;
            ResStrs.WriteRSJFile;
          end;
        ResStrs.Free;
        ResStrs := nil;
        SymTableStack.Pop(CurrentModule.LocalSymTable);
        if Assigned(CurrentModule.GlobalSymTable) then
          SymTableStack.Pop(CurrentModule.GlobalSymTable);
      end;

end.
