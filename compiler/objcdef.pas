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
    function objctryencodetype(def: TDef; out encodedtype: AnsiString; out founderror: TDef): boolean;

    { Check whether a type can be used in an Objective-C method
      signature or field declaration.  }
    function objcchecktype(def: TDef; out founderror: TDef): boolean;

    { add type info for def at the end of encodedstr. recordinfostate influences
      whether a record-style type will be fully encoded, or just using its
      type name. bpacked indicates whether a record/array is bitpacked.
      On error, founderror contains the type that triggered the error. }
    type
      TRecordInfoState = (ris_initial, ris_afterpointer, ris_dontprint);

    function objcaddencodedtype(def: TDef; recordinfostate: TRecordInfoState; bpacked: boolean; var encodedstr: AnsiString; out founderror: TDef): boolean;

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

    function encoderecst(const recname: AnsiString; recst: TAbstractRecordSymTable; var encodedstr: AnsiString; out founderror: TDef): boolean;
      var
        variantstarts: TFPList;
        i, varindex: LongInt;
        field,
        firstfield: TFieldVarSym;
        firstfieldvariant,
        bpacked: boolean;
      begin
        result:=false;
        bpacked:=recst.FieldAlignment=bit_alignment;
        { Is the first field already the start of a variant?  }
        firstfield:=nil;
        firstfieldvariant:=false;
        for i:=0 to recst.SymList.count-1 do
          begin
            if (TSym(recst.SymList[i]).typ<>FieldVarSym) then
              continue;
            field:=TFieldVarSym(recst.SymList[i]);
            if not Assigned(firstfield) then
              firstfield:=field
            else if (vo_is_first_field in field.VarOptions) then
              begin
                if (field.FieldOffset=firstfield.FieldOffset) then
                  firstfieldvariant:=true;
              end;
          end;
        variantstarts:=TFPList.create;
        encodedstr:=encodedstr+'{'+recname+'=';
        for i:=0 to recst.SymList.count-1 do
          begin
            if (TSym(recst.SymList[i]).typ<>FieldVarSym) then
              continue;

            field:=TFieldVarSym(recst.SymList[i]);
            { start of a variant part? }
            if ((field=firstfield) and
                firstfieldvariant) or
               ((field<>firstfield) and
                (vo_is_first_field in field.VarOptions)) then
              begin
                varindex:=variantstarts.count-1;
                if (varindex=-1) or
                   (TFieldVarSym(variantstarts[varindex]).FieldOffset<field.FieldOffset) then
                  begin
                    { new, more deeply nested variant }
                    encodedstr:=encodedstr+'(?={?=';
                    variantstarts.add(field);
                  end
                else
                  begin
                    { close existing nested variants if any }
                    while (varindex>=0) and
                          (TFieldVarSym(variantstarts[varindex]).FieldOffset>field.FieldOffset) do
                      begin
                        { close more deeply nested variants }
                        encodedstr:=encodedstr+'})';
                        dec(varindex);
                      end;
                    if (varindex<0) then
                      InternalError(2009081805);

                    { variant at the same level as a previous one }
                    variantstarts.count:=varindex+1;
                    { No need to add this field, it has the same offset as the
                      previous one at this position.  }
                    if TFieldVarSym(variantstarts[varindex]).FieldOffset<>field.FieldOffset then
                      InternalError(2009081601);
                    { close previous variant sub-part and start new one }
                    encodedstr:=encodedstr+'}{?=';
                  end
              end;
            if not objcaddencodedtype(field.vardef,ris_afterpointer,bpacked,encodedstr,founderror) then
              exit;
          end;
        for i:=0 to variantstarts.count-1 do
          encodedstr:=encodedstr+'})';
        variantstarts.free;
        variantstarts := nil;
        encodedstr:=encodedstr+'}';
        result:=true
      end;


    function objcaddencodedtype(def: TDef; recordinfostate: TRecordInfoState; bpacked: boolean; var encodedstr: AnsiString; out founderror: TDef): boolean;
      var
        recname: AnsiString;
        recdef: TRecordDef;
        objdef: TObjectDef;
        len: aint;
        c: char;
        newstate: TRecordInfoState;
        addrpara: boolean;
      begin
        result:=true;
        case def.typ of
          stringdef :
            begin
              case TStringDef(def).StringType of
                st_shortstring:
                  { include length byte }
                  encodedstr:=encodedstr+'['+ToStr(TStringDef(def).len+1)+'C]';
                else
                  { While we could handle refcounted Pascal strings correctly
                    when such methods are called from Pascal code, things would
                    completely break down if they were called from Objective-C
                    code/reflection since the necessary refcount helper calls
                    would be missing on the caller side (unless we'd
                    automatically generate wrappers).  }
                  result:=false;
              end;
            end;
          enumdef,
          orddef :
            begin
              if bpacked and
                 not is_void(def) then
                encodedstr:=encodedstr+'b'+ToStr(def.PackedBitSize)
              else
                begin
                  if is_void(def) then
                    c:='v'
                  { in gcc, sizeof(_Bool) = sizeof(char) }
                  else if is_boolean(def) and
                          (def.size=1) then
                    c:='B'
                  else
                    begin
                      case def.size of
                        1:
                          c:='c';
                        2:
                          c:='s';
                        4:
                          c:='i';
                        8:
                          c:='q';
                        else
                          InternalError(2009081502);
                      end;
                      if not is_signed(def) then
                        c:=upcase(c);
                    end;
                  encodedstr:=encodedstr+c;
                end;
            end;
          pointerdef :
            begin
              if is_pchar(def) then
                encodedstr:=encodedstr+'*'
              else if (def=ObjC_IDType) then
                encodedstr:=encodedstr+'@'
              else if (def=ObjC_SelType) then
                encodedstr:=encodedstr+':'
              else if (def=ObjC_MetaClassType) then
                encodedstr:=encodedstr+'#'
              else
                begin
                  encodedstr:=encodedstr+'^';
                  newstate:=recordinfostate;
                  if (recordinfostate<ris_dontprint) then
                    newstate:=succ(newstate);
                  if not objcaddencodedtype(TPointerDef(def).PointedDef,newstate,false,encodedstr,founderror) then
                    begin
                      result:=false;
                      { report the exact (nested) error definition }
                      exit;
                    end;
                end;
            end;
          floatdef :
            begin
              case TFloatDef(def).FloatType of
                S32Real:
                  c:='f';
                S64Real:
                  c:='d';
                else
                  begin
                    c:='!';
                    result:=false;
                  end;
              end;
              encodedstr:=encodedstr+c;
            end;
          filedef :
            result:=false;
          recorddef :
            begin
              if Assigned(def.TypeSym) then
                recname:=def.TypeName
              else
                recname:='?';

              if (recordinfostate<>ris_dontprint) then
                begin
                  if not encoderecst(recname,TAbstractRecordSymTable(TRecordDef(def).SymTable),encodedstr,founderror) then
                    begin
                      result:=false;
                      { report the exact (nested) error definition }
                      exit;
                    end
                end
              else
                encodedstr:=encodedstr+'{'+recname+'}'
            end;
          variantdef :
            begin
              recdef:=TRecordDef(Search_System_Type('TVARDATA').typedef);
              if (recordinfostate<>ris_dontprint) then
                begin
                  if not encoderecst(recdef.TypeName,TAbstractRecordSymTable(recdef.SymTable),encodedstr,founderror) then
                    begin
                      result:=false;
                      { report the exact (nested) error definition }
                      exit;
                    end
                end
              else
                encodedstr:=encodedstr+'{'+recdef.TypeName+'}';
            end;
          classrefdef :
            begin
              encodedstr:=encodedstr+'^';
              newstate:=recordinfostate;
              if (recordinfostate<>ris_dontprint) then
                newstate:=succ(newstate);
              if Is_ObjCClassRef(def) then
                begin
                  objdef:=TObjectDef(TClassRefDef(def).PointedDef);
                  if (newstate<>ris_dontprint) then
                    { anonymous (objc)class definitions do not exist }
                    begin
                      if not encoderecst(objdef.ObjExtName^,TAbstractRecordSymTable(objdef.SymTable),encodedstr,founderror) then
                        { The fields of an Objective-C class should always be
                          encodeable.  }
                        InternalError(2009081702);
                    end
                  else
                    encodedstr:=encodedstr+'{'+objdef.ObjExtName^+'}'
                end
              { Object Pascal classrefdefs point to a vmt, not really useful
                to completely write those here.  I'm not even sure what the
                Objective-C run time uses this information for, since in C you
                can have forward struct definitions so not all structs passed
                to functions can be written out here either -> treat
                classrefdefs the same as such forward-defined structs.  }
              else
                begin
                  if Assigned(def.TypeSym) then
                    recname:=def.TypeName
                  else
                    recname:='?';
                  encodedstr:=encodedstr+'{'+recname;
                  if (newstate<>ris_dontprint) then
                    encodedstr:=encodedstr+'=';
                  encodedstr:=encodedstr+'}'
                end;
            end;
          setdef :
            begin
              addrpara:=paramanager.push_addr_param(vs_value,def,pocall_cdecl);
              if not addrpara then
                { encode as an record, they are always passed by value in C.  }
                encodedstr:=encodedstr+'{?=';
              { Encode the set itself as an array. Without an encompassing
                record, these are always passed by reference in C.  }
              encodedstr:=encodedstr+'['+ToStr(def.size)+'C]';
              if not addrpara then
                encodedstr:=encodedstr+'}';
            end;
          formaldef :
            begin
              encodedstr:=encodedstr+'^v';
            end;
          arraydef :
            begin
              if is_array_of_const(def) then
                { do nothing, varargs are ignored in signatures }
              else if is_special_array(def) then
                result:=false
              else
                begin
                  len:=TArrayDef(def).HighRange-TArrayDef(def).LowRange+1;
                  if is_packed_array(def) then
                    begin
                      { convert from bits to bytes for bitpacked arrays }
                      len:=(len+7) div 8;
                      { and encode as plain array of bytes }
                      encodedstr:=encodedstr+'['+ToStr(len)+'C]';
                    end
                  else
                    begin
                      encodedstr:=encodedstr+'['+ToStr(len);
                      { Embedded structured types in the array are printed
                        in full regardless of the current recordinfostate.  }
                      if not objcaddencodedtype(TArrayDef(def).ElementDef,ris_initial,false,encodedstr,founderror) then
                        begin
                          result:=false;
                          { report the exact (nested) error definition }
                          exit;
                        end;
                      encodedstr:=encodedstr+']';
                    end;
                end;
            end;
          procvardef :
            if not(po_is_block in TProcVarDef(def).ProcOptions) then
              encodedstr:=encodedstr+'^?'
            else
              encodedstr:=encodedstr+'@?';
          objectdef :
            case TObjectDef(def).ObjectType of
              odt_helper,
              odt_class,
              odt_object,
              odt_cppclass:
                begin
                  newstate:=recordinfostate;
                  { implicit pointer for classes }
                  if (TObjectDef(def).ObjectType in [odt_class,odt_helper]) then
                    begin
                      encodedstr:=encodedstr+'^';
                      { make all classes opaque, so even if they contain a
                        reference-counted field there is no problem. Since a
                        "dereferenced class" object does not exist, this should
                        not cause problems }
                      newstate:=ris_dontprint;
                    end;
                  if newstate<>ris_dontprint then
                    begin
                      if not encoderecst(def.TypeName,TAbstractRecordSymTable(TObjectDef(def).SymTable),encodedstr,founderror) then
                        begin
                          result:=false;
                          { report the exact (nested) error definition }
                          exit;
                        end
                    end
                  else
                    encodedstr:=encodedstr+'{'+def.TypeName+'}'
                end;
              odt_interfacecom,
              odt_interfacecom_property,
              odt_interfacecom_function,
              odt_dispinterface:
                result:=false;
              odt_interfacecorba:
                encodedstr:=encodedstr+'^{'+def.TypeName+'=}';
              { In Objective-C, the actual types of class instances are
                NSObject* etc, and those are encoded as "@". In FPC, to keep
                the similarity with Delphi-style Object Pascal, the type is
                NSObject and the pointer is implicit. Objective-C's "NSObject"
                has "class of NSObject" as equivalent here.  }
              odt_objcclass,
              odt_objcprotocol:
                encodedstr:=encodedstr+'@';
              else
                InternalError(2009081509);
            end;
          undefineddef,
          errordef :
            result:=false;
          procdef :
            { must be done via objcencodemethod() }
            InternalError(2009081511);
        else
          InternalError(2009150812);
        end;
        if not result then
          founderror:=def;
      end;


    function objctryencodetype(def: TDef; out encodedtype: AnsiString; out founderror: TDef): boolean;
      begin
        result:=objcaddencodedtype(def,ris_initial,false,encodedtype,founderror);
      end;


{******************************************************************
                    ObjC type validity checking
*******************************************************************}

    function objcdochecktype(def: TDef; recordinfostate: TRecordInfoState; out founderror: TDef): boolean; forward;

    function checkrecsttype(recst: TAbstractRecordSymTable; recordinfostate: TRecordInfoState; out founderror: TDef): boolean;
      var
        i: LongInt;
        field: TFieldVarSym;
        newstate: TRecordInfoState;
      begin
        result:=false;
        newstate:=recordinfostate;
        { Although we never have to print the type info for nested
          records, check them anyway in case we're not after a pointer
          since if such records contain refcounted types then they
          can cause just as much trouble as if they were a simple
          refcounted field.  }
        if (newstate=ris_afterpointer) then
          newstate:=ris_dontprint;
        for i:=0 to recst.SymList.count-1 do
          begin
            if (TSym(recst.SymList[i]).typ<>FieldVarSym) then
              continue;

            field:=TFieldVarSym(recst.SymList[i]);
            if not objcdochecktype(field.vardef,newstate,founderror) then
              exit;
          end;
        result:=true
      end;


    function objcdochecktype(def: TDef; recordinfostate: TRecordInfoState; out founderror: TDef): boolean;
      var
        recdef: TRecordDef;
        objdef: TObjectDef;
        newstate: TRecordInfoState;
      begin
        result:=true;
        case def.typ of
          stringdef :
            begin
              case TStringDef(def).StringType of
                st_shortstring:
                  ;
                else
                  { While we could handle refcounted Pascal strings correctly
                    when such methods are called from Pascal code, things would
                    completely break down if they were called from Objective-C
                    code/reflection since the necessary refcount helper calls
                    would be missing on the caller side (unless we'd
                    automatically generate wrappers).  }
                  result:=false;
              end;
            end;
          enumdef,
          orddef :
            ;
          pointerdef :
            begin
              newstate:=recordinfostate;
              if (recordinfostate<ris_dontprint) then
                newstate:=succ(newstate);
              if not objcdochecktype(TPointerDef(def).PointedDef,newstate,founderror) then
                begin
                  result:=false;
                  { report the exact (nested) error definition }
                  exit;
                end;
            end;
          floatdef :
            begin
              case TFloatDef(def).FloatType of
                S32Real,
                S64Real:
                  ;
                else
                  result:=false;
              end;
            end;
          filedef :
            result:=false;
          recorddef :
            begin
              if (recordinfostate<>ris_dontprint) then
                begin
                  if not checkrecsttype(TAbstractRecordSymTable(TRecordDef(def).SymTable),recordinfostate,founderror) then
                    begin
                      result:=false;
                      { report the exact (nested) error definition }
                      exit;
                    end
                end
            end;
          variantdef :
            begin
              recdef:=TRecordDef(Search_System_Type('TVARDATA').typedef);
              if (recordinfostate<>ris_dontprint) then
                begin
                  if not checkrecsttype(TAbstractRecordSymTable(recdef.SymTable),recordinfostate,founderror) then
                    begin
                      result:=false;
                      { report the exact (nested) error definition }
                      exit;
                    end
                end;
            end;
          classrefdef:
            begin
              if Is_ObjCClassRef(def) then
                begin
                  objdef:=TObjectDef(TClassRefDef(def).PointedDef);
                  newstate:=recordinfostate;
                  if (recordinfostate<ris_dontprint) then
                    newstate:=succ(newstate);
                  if (newstate<>ris_dontprint) then
                    begin
                      if not checkrecsttype(TAbstractRecordSymTable(objdef.SymTable),recordinfostate,founderror) then
                        begin
                          result:=false;
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
              if is_array_of_const(def) then
                { ok, varargs are ignored in signatures }
              else if is_special_array(def) then
                result:=false
              else
                begin
                  if not is_packed_array(def) then
                    begin
                      if not objcdochecktype(TArrayDef(def).ElementDef,ris_initial,founderror) then
                        begin
                          result:=false;
                          { report the exact (nested) error definition }
                          exit;
                        end;
                    end;
                end;
            end;
          procvardef :
            ;
          objectdef :
            case TObjectDef(def).ObjectType of
              odt_helper,
              odt_class,
              odt_object,
              odt_cppclass:
                begin
                  newstate:=recordinfostate;
                  { implicit pointer for classes }
                  if (TObjectDef(def).ObjectType in [odt_class,odt_helper]) then
                    begin
                      { make all classes opaque, so even if they contain a
                        reference-counted field there is no problem. Since a
                        "dereferenced class" object does not exist, this should
                        not cause problems }
                      newstate:=ris_dontprint;
                    end;
                  if newstate<>ris_dontprint then
                    begin
                      if not checkrecsttype(TAbstractRecordSymTable(TObjectDef(def).SymTable),newstate,founderror) then
                        begin
                          result:=false;
                          { report the exact (nested) error definition }
                          exit;
                        end
                    end
                end;
              odt_interfacecom,
              odt_interfacecom_property,
              odt_interfacecom_function,
              odt_dispinterface:
                result:=false;
              odt_interfacecorba,
              odt_objcclass,
              odt_objcprotocol:
                ;
              else
                InternalError(2009081709);
            end;
          undefineddef,
          errordef :
            result:=false;
          procdef :
            result:=false;
        else
          InternalError(2009170812);
        end;
        if not result then
          founderror:=def;
      end;


    function objcchecktype(def: TDef; out founderror: TDef): boolean;
      begin
        result:=objcdochecktype(def,ris_initial,founderror);
      end;


end.
