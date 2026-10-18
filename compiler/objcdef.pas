{
    Copyright (c) 2010 by Jonas Maebe

    This unit implements some Objective-C type helper routines (minimal
    unit dependencies, usable in symdef).

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

{$i fpcdefs.inc}

unit objcdef;

interface

    uses
      symtype;

    { The internals of Objective-C's @encode() functionality: encode a
      type into the internal format used by the run time. Returns false
      if a type is not representable by the Objective-C run time, and in
      that case also the failing definition.  }
    function ObjCTryEncodeType(ADef: TDef; out AEncodedType: AnsiString; out AFoundError: TDef): Boolean;

    { Check whether a type can be used in an Objective-C method
      signature or field declaration.  }
    function ObjCCheckType(ADef: TDef; out AFoundError: TDef): Boolean;

    { add type info for def at the end of encodedstr. recordinfostate influences
      whether a record-style type will be fully encoded, or just using its
      type name. bpacked indicates whether a record/array is bitpacked.
      On error, founderror contains the type that triggered the error. }
    type
      TRecordInfoState = (ris_initial, ris_afterpointer, ris_dontprint);

    function ObjCAddEncodedType(ADef: TDef; ARecordInfoState: TRecordInfoState; ABitPacked: Boolean; var AEncodedString: AnsiString; out AFoundError: TDef): Boolean;

implementation

  uses
    GlobType,
    CUtils,CClasses,
    Verbose,
    SymTable,symconst,SymSym,symdef,
    defutil,paramgr;

{******************************************************************
                          Type encoding
*******************************************************************}

    function EncodeRecST(const ARecordName: AnsiString; ARecordST: TAbstractRecordSymTable; var AEncodedString: AnsiString; out AFoundError: TDef): Boolean;
      var
        lVariantStarts: TFPList;
        lIndex, lVariantIndex: LongInt;
        lFieldSym,
        lFirstField: TFieldVarSym;
        lFirstFieldVariant,
        lBitPacked: Boolean;
      begin
        Result:=false;
        lBitPacked:=ARecordST.FieldAlignment=BitAlignment;
        { Is the first field already the start of a variant?  }
        lFirstField:=nil;
        lFirstFieldVariant:=false;
        for lIndex:=0 to ARecordST.SymList.count-1 do
          begin
            if (TSym(ARecordST.SymList[lIndex]).typ<>FieldVarSym) then
              continue;
            lFieldSym:=TFieldVarSym(ARecordST.SymList[lIndex]);
            if not Assigned(lFirstField) then
              lFirstField:=lFieldSym
            else if (vo_is_first_field in lFieldSym.VarOptions) then
              begin
                if (lFieldSym.FieldOffset=lFirstField.FieldOffset) then
                  lFirstFieldVariant:=true;
              end;
          end;
        lVariantStarts:=TFPList.Create;
        AEncodedString:=AEncodedString+'{'+ARecordName+'=';
        for lIndex:=0 to ARecordST.SymList.count-1 do
          begin
            if (TSym(ARecordST.SymList[lIndex]).typ<>FieldVarSym) then
              continue;

            lFieldSym:=TFieldVarSym(ARecordST.SymList[lIndex]);
            { start of a variant part? }
            if ((lFieldSym=lFirstField) and
                lFirstFieldVariant) or
               ((lFieldSym<>lFirstField) and
                (vo_is_first_field in lFieldSym.VarOptions)) then
              begin
                lVariantIndex:=lVariantStarts.count-1;
                if (lVariantIndex=-1) or
                   (TFieldVarSym(lVariantStarts[lVariantIndex]).FieldOffset<lFieldSym.FieldOffset) then
                  begin
                    { new, more deeply nested variant }
                    AEncodedString:=AEncodedString+'(?={?=';
                    lVariantStarts.add(lFieldSym);
                  end
                else
                  begin
                    { close existing nested variants if any }
                    while (lVariantIndex>=0) and
                          (TFieldVarSym(lVariantStarts[lVariantIndex]).FieldOffset>lFieldSym.FieldOffset) do
                      begin
                        { close more deeply nested variants }
                        AEncodedString:=AEncodedString+'})';
                        dec(lVariantIndex);
                      end;
                    if (lVariantIndex<0) then
                      InternalError(2009081805);

                    { variant at the same level as a previous one }
                    lVariantStarts.count:=lVariantIndex+1;
                    { No need to add this field, it has the same offset as the
                      previous one at this position.  }
                    if TFieldVarSym(lVariantStarts[lVariantIndex]).FieldOffset<>lFieldSym.FieldOffset then
                      InternalError(2009081601);
                    { close previous variant sub-part and start new one }
                    AEncodedString:=AEncodedString+'}{?=';
                  end
              end;
            if not ObjCAddEncodedType(lFieldSym.vardef,ris_afterpointer,lBitPacked,AEncodedString,AFoundError) then
              exit;
          end;
        for lIndex:=0 to lVariantStarts.count-1 do
          AEncodedString:=AEncodedString+'})';
        lVariantStarts.free;
        lVariantStarts := nil;
        AEncodedString:=AEncodedString+'}';
        Result:=true
      end;


    function ObjCAddEncodedType(ADef: TDef; ARecordInfoState: TRecordInfoState; ABitPacked: Boolean; var AEncodedString: AnsiString; out AFoundError: TDef): Boolean;
      var
        lRecordName: AnsiString;
        lRecordDef: TRecordDef;
        lObjectDef: TObjectDef;
        lLength: AInt;
        lChar: char;
        lNewState: TRecordInfoState;
        lAddrPara: Boolean;
      begin
        Result:=true;
        case ADef.typ of
          stringdef :
            begin
              case TStringDef(ADef).StringType of
                st_shortstring:
                  { include length byte }
                  AEncodedString:=AEncodedString+'['+ToStr(TStringDef(ADef).len+1)+'C]';
                else
                  { While we could handle refcounted Pascal strings correctly
                    when such methods are called from Pascal code, things would
                    completely break down if they were called from Objective-C
                    code/reflection since the necessary refcount helper calls
                    would be missing on the caller side (unless we'd
                    automatically generate wrappers).  }
                  Result:=false;
              end;
            end;
          enumdef,
          orddef :
            begin
              if ABitPacked and
                 not Is_Void(ADef) then
                AEncodedString:=AEncodedString+'b'+ToStr(ADef.PackedBitSize)
              else
                begin
                  if Is_Void(ADef) then
                    lChar:='v'
                  { in gcc, sizeof(_Bool) = sizeof(char) }
                  else if Is_Boolean(ADef) and
                          (ADef.Size=1) then
                    lChar:='B'
                  else
                    begin
                      case ADef.Size of
                        1:
                          lChar:='c';
                        2:
                          lChar:='s';
                        4:
                          lChar:='i';
                        8:
                          lChar:='q';
                        else
                          InternalError(2009081502);
                      end;
                      if not Is_Signed(ADef) then
                        lChar:=upcase(lChar);
                    end;
                  AEncodedString:=AEncodedString+lChar;
                end;
            end;
          pointerdef :
            begin
              if Is_PChar(ADef) then
                AEncodedString:=AEncodedString+'*'
              else if (ADef=ObjC_IDType) then
                AEncodedString:=AEncodedString+'@'
              else if (ADef=ObjC_SelType) then
                AEncodedString:=AEncodedString+':'
              else if (ADef=ObjC_MetaClassType) then
                AEncodedString:=AEncodedString+'#'
              else
                begin
                  AEncodedString:=AEncodedString+'^';
                  lNewState:=ARecordInfoState;
                  if (ARecordInfoState<ris_dontprint) then
                    lNewState:=succ(lNewState);
                  if not ObjCAddEncodedType(TPointerDef(ADef).PointedDef,lNewState,false,AEncodedString,AFoundError) then
                    begin
                      Result:=false;
                      { report the exact (nested) error definition }
                      exit;
                    end;
                end;
            end;
          floatdef :
            begin
              case TFloatDef(ADef).FloatType of
                S32Real:
                  lChar:='f';
                S64Real:
                  lChar:='d';
                else
                  begin
                    lChar:='!';
                    Result:=false;
                  end;
              end;
              AEncodedString:=AEncodedString+lChar;
            end;
          filedef :
            Result:=false;
          recorddef :
            begin
              if Assigned(ADef.TypeSym) then
                lRecordName:=ADef.TypeName
              else
                lRecordName:='?';

              if (ARecordInfoState<>ris_dontprint) then
                begin
                  if not EncodeRecST(lRecordName,TAbstractRecordSymTable(TRecordDef(ADef).SymTable),AEncodedString,AFoundError) then
                    begin
                      Result:=false;
                      { report the exact (nested) error definition }
                      exit;
                    end
                end
              else
                AEncodedString:=AEncodedString+'{'+lRecordName+'}'
            end;
          variantdef :
            begin
              lRecordDef:=TRecordDef(Search_System_Type('TVARDATA').TypeDef);
              if (ARecordInfoState<>ris_dontprint) then
                begin
                  if not EncodeRecST(lRecordDef.TypeName,TAbstractRecordSymTable(lRecordDef.SymTable),AEncodedString,AFoundError) then
                    begin
                      Result:=false;
                      { report the exact (nested) error definition }
                      exit;
                    end
                end
              else
                AEncodedString:=AEncodedString+'{'+lRecordDef.TypeName+'}';
            end;
          classrefdef :
            begin
              AEncodedString:=AEncodedString+'^';
              lNewState:=ARecordInfoState;
              if (ARecordInfoState<>ris_dontprint) then
                lNewState:=succ(lNewState);
              if Is_ObjCClassRef(ADef) then
                begin
                  lObjectDef:=TObjectDef(TClassRefDef(ADef).PointedDef);
                  if (lNewState<>ris_dontprint) then
                    { anonymous (objc)class definitions do not exist }
                    begin
                      if not EncodeRecST(lObjectDef.ObjExtName^,TAbstractRecordSymTable(lObjectDef.SymTable),AEncodedString,AFoundError) then
                        { The fields of an Objective-C class should always be
                          encodeable.  }
                        InternalError(2009081702);
                    end
                  else
                    AEncodedString:=AEncodedString+'{'+lObjectDef.ObjExtName^+'}'
                end
              { Object Pascal classrefdefs point to a vmt, not really useful
                to completely write those here.  I'm not even sure what the
                Objective-C run time uses this information for, since in C you
                can have forward struct definitions so not all structs passed
                to functions can be written out here either -> treat
                classrefdefs the same as such forward-defined structs.  }
              else
                begin
                  if Assigned(ADef.TypeSym) then
                    lRecordName:=ADef.TypeName
                  else
                    lRecordName:='?';
                  AEncodedString:=AEncodedString+'{'+lRecordName;
                  if (lNewState<>ris_dontprint) then
                    AEncodedString:=AEncodedString+'=';
                  AEncodedString:=AEncodedString+'}'
                end;
            end;
          setdef :
            begin
              lAddrPara:=ParaManager.Push_Addr_Param(vs_value,ADef,pocall_cdecl);
              if not lAddrPara then
                { encode as an record, they are always passed by value in C.  }
                AEncodedString:=AEncodedString+'{?=';
              { Encode the set itself as an array. Without an encompassing
                record, these are always passed by reference in C.  }
              AEncodedString:=AEncodedString+'['+ToStr(ADef.Size)+'C]';
              if not lAddrPara then
                AEncodedString:=AEncodedString+'}';
            end;
          formaldef :
            begin
              AEncodedString:=AEncodedString+'^v';
            end;
          arraydef :
            begin
              if Is_Array_Of_Const(ADef) then
                { do nothing, varargs are ignored in signatures }
              else if Is_Special_Array(ADef) then
                Result:=false
              else
                begin
                  lLength:=TArrayDef(ADef).HighRange-TArrayDef(ADef).LowRange+1;
                  if Is_Packed_Array(ADef) then
                    begin
                      { convert from bits to bytes for bitpacked arrays }
                      lLength:=(lLength+7) div 8;
                      { and encode as plain array of bytes }
                      AEncodedString:=AEncodedString+'['+ToStr(lLength)+'C]';
                    end
                  else
                    begin
                      AEncodedString:=AEncodedString+'['+ToStr(lLength);
                      { Embedded structured types in the array are printed
                        in full regardless of the current recordinfostate.  }
                      if not ObjCAddEncodedType(TArrayDef(ADef).ElementDef,ris_initial,false,AEncodedString,AFoundError) then
                        begin
                          Result:=false;
                          { report the exact (nested) error definition }
                          exit;
                        end;
                      AEncodedString:=AEncodedString+']';
                    end;
                end;
            end;
          procvardef :
            if not(po_is_block in TProcVarDef(ADef).ProcOptions) then
              AEncodedString:=AEncodedString+'^?'
            else
              AEncodedString:=AEncodedString+'@?';
          objectdef :
            case TObjectDef(ADef).ObjectType of
              odt_helper,
              odt_class,
              odt_object,
              odt_cppclass:
                begin
                  lNewState:=ARecordInfoState;
                  { implicit pointer for classes }
                  if (TObjectDef(ADef).ObjectType in [odt_class,odt_helper]) then
                    begin
                      AEncodedString:=AEncodedString+'^';
                      { make all classes opaque, so even if they contain a
                        reference-counted field there is no problem. Since a
                        "dereferenced class" object does not exist, this should
                        not cause problems }
                      lNewState:=ris_dontprint;
                    end;
                  if lNewState<>ris_dontprint then
                    begin
                      if not EncodeRecST(ADef.TypeName,TAbstractRecordSymTable(TObjectDef(ADef).SymTable),AEncodedString,AFoundError) then
                        begin
                          Result:=false;
                          { report the exact (nested) error definition }
                          exit;
                        end
                    end
                  else
                    AEncodedString:=AEncodedString+'{'+ADef.TypeName+'}'
                end;
              odt_interfacecom,
              odt_interfacecom_property,
              odt_interfacecom_function,
              odt_dispinterface:
                Result:=false;
              odt_interfacecorba:
                AEncodedString:=AEncodedString+'^{'+ADef.TypeName+'=}';
              { In Objective-C, the actual types of class instances are
                NSObject* etc, and those are encoded as "@". In FPC, to keep
                the similarity with Delphi-style Object Pascal, the type is
                NSObject and the pointer is implicit. Objective-C's "NSObject"
                has "class of NSObject" as equivalent here.  }
              odt_objcclass,
              odt_objcprotocol:
                AEncodedString:=AEncodedString+'@';
              else
                InternalError(2009081509);
            end;
          undefineddef,
          errordef :
            Result:=false;
          procdef :
            { must be done via objcencodemethod() }
            InternalError(2009081511);
        else
          InternalError(2009150812);
        end;
        if not Result then
          AFoundError:=ADef;
      end;


    function ObjCTryEncodeType(ADef: TDef; out AEncodedType: AnsiString; out AFoundError: TDef): Boolean;
      begin
        Result:=ObjCAddEncodedType(ADef,ris_initial,false,AEncodedType,AFoundError);
      end;


{******************************************************************
                    ObjC type validity checking
*******************************************************************}

    function ObjCDoCheckType(ADef: TDef; ARecordInfoState: TRecordInfoState; out AFoundError: TDef): Boolean; forward;

    function CheckRecSTType(ARecordST: TAbstractRecordSymTable; ARecordInfoState: TRecordInfoState; out AFoundError: TDef): Boolean;
      var
        lIndex: LongInt;
        lFieldSym: TFieldVarSym;
        lNewState: TRecordInfoState;
      begin
        Result:=false;
        lNewState:=ARecordInfoState;
        { Although we never have to print the type info for nested
          records, check them anyway in case we're not after a pointer
          since if such records contain refcounted types then they
          can cause just as much trouble as if they were a simple
          refcounted field.  }
        if (lNewState=ris_afterpointer) then
          lNewState:=ris_dontprint;
        for lIndex:=0 to ARecordST.SymList.count-1 do
          begin
            if (TSym(ARecordST.SymList[lIndex]).typ<>FieldVarSym) then
              continue;

            lFieldSym:=TFieldVarSym(ARecordST.SymList[lIndex]);
            if not ObjCDoCheckType(lFieldSym.vardef,lNewState,AFoundError) then
              exit;
          end;
        Result:=true
      end;


    function ObjCDoCheckType(ADef: TDef; ARecordInfoState: TRecordInfoState; out AFoundError: TDef): Boolean;
      var
        lRecordDef: TRecordDef;
        lObjectDef: TObjectDef;
        lNewState: TRecordInfoState;
      begin
        Result:=true;
        case ADef.typ of
          stringdef :
            begin
              case TStringDef(ADef).StringType of
                st_shortstring:
                  ;
                else
                  { While we could handle refcounted Pascal strings correctly
                    when such methods are called from Pascal code, things would
                    completely break down if they were called from Objective-C
                    code/reflection since the necessary refcount helper calls
                    would be missing on the caller side (unless we'd
                    automatically generate wrappers).  }
                  Result:=false;
              end;
            end;
          enumdef,
          orddef :
            ;
          pointerdef :
            begin
              lNewState:=ARecordInfoState;
              if (ARecordInfoState<ris_dontprint) then
                lNewState:=succ(lNewState);
              if not ObjCDoCheckType(TPointerDef(ADef).PointedDef,lNewState,AFoundError) then
                begin
                  Result:=false;
                  { report the exact (nested) error definition }
                  exit;
                end;
            end;
          floatdef :
            begin
              case TFloatDef(ADef).FloatType of
                S32Real,
                S64Real:
                  ;
                else
                  Result:=false;
              end;
            end;
          filedef :
            Result:=false;
          recorddef :
            begin
              if (ARecordInfoState<>ris_dontprint) then
                begin
                  if not CheckRecSTType(TAbstractRecordSymTable(TRecordDef(ADef).SymTable),ARecordInfoState,AFoundError) then
                    begin
                      Result:=false;
                      { report the exact (nested) error definition }
                      exit;
                    end
                end
            end;
          variantdef :
            begin
              lRecordDef:=TRecordDef(Search_System_Type('TVARDATA').TypeDef);
              if (ARecordInfoState<>ris_dontprint) then
                begin
                  if not CheckRecSTType(TAbstractRecordSymTable(lRecordDef.SymTable),ARecordInfoState,AFoundError) then
                    begin
                      Result:=false;
                      { report the exact (nested) error definition }
                      exit;
                    end
                end;
            end;
          classrefdef:
            begin
              if Is_ObjCClassRef(ADef) then
                begin
                  lObjectDef:=TObjectDef(TClassRefDef(ADef).PointedDef);
                  lNewState:=ARecordInfoState;
                  if (ARecordInfoState<ris_dontprint) then
                    lNewState:=succ(lNewState);
                  if (lNewState<>ris_dontprint) then
                    begin
                      if not CheckRecSTType(TAbstractRecordSymTable(lObjectDef.SymTable),ARecordInfoState,AFoundError) then
                        begin
                          Result:=false;
                          { report the exact (nested) error definition }
                          exit;
                        end
                    end
                end
            end;
          setdef,
          formaldef :
            ;
          arraydef :
            begin
              if Is_Array_Of_Const(ADef) then
                { ok, varargs are ignored in signatures }
              else if Is_Special_Array(ADef) then
                Result:=false
              else
                begin
                  if not Is_Packed_Array(ADef) then
                    begin
                      if not ObjCDoCheckType(TArrayDef(ADef).ElementDef,ris_initial,AFoundError) then
                        begin
                          Result:=false;
                          { report the exact (nested) error definition }
                          exit;
                        end;
                    end;
                end;
            end;
          procvardef :
            ;
          objectdef :
            case TObjectDef(ADef).ObjectType of
              odt_helper,
              odt_class,
              odt_object,
              odt_cppclass:
                begin
                  lNewState:=ARecordInfoState;
                  { implicit pointer for classes }
                  if (TObjectDef(ADef).ObjectType in [odt_class,odt_helper]) then
                    begin
                      { make all classes opaque, so even if they contain a
                        reference-counted field there is no problem. Since a
                        "dereferenced class" object does not exist, this should
                        not cause problems }
                      lNewState:=ris_dontprint;
                    end;
                  if lNewState<>ris_dontprint then
                    begin
                      if not CheckRecSTType(TAbstractRecordSymTable(TObjectDef(ADef).SymTable),lNewState,AFoundError) then
                        begin
                          Result:=false;
                          { report the exact (nested) error definition }
                          exit;
                        end
                    end
                end;
              odt_interfacecom,
              odt_interfacecom_property,
              odt_interfacecom_function,
              odt_dispinterface:
                Result:=false;
              odt_interfacecorba,
              odt_objcclass,
              odt_objcprotocol:
                ;
              else
                InternalError(2009081709);
            end;
          undefineddef,
          errordef :
            Result:=false;
          procdef :
            Result:=false;
        else
          InternalError(2009170812);
        end;
        if not Result then
          AFoundError:=ADef;
      end;


    function ObjCCheckType(ADef: TDef; out AFoundError: TDef): Boolean;
      begin
        Result:=ObjCDoCheckType(ADef,ris_initial,AFoundError);
      end;


end.
