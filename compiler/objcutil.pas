{
    Copyright (c) 2009-2010 by Jonas Maebe

    This unit implements some Objective-C helper routines at the node tree
    level.

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

unit objcutil;

interface

    uses
      node,
      symtype,symdef;

    { Check whether a string contains a syntactically valid selector name.  }
    function ObjCValidSelectorName(AValueString: PChar; ALength: LongInt): Boolean;

    { Generate a node loading the superclass structure necessary to call
      an inherited Objective-C method.  }
    function ObjCSuperClassNode(ADef: TDef): TNode;

    { Encode a method's parameters and result type into the format used by the
      run time (for generating protocol and class rtti).  }
    function ObjCEncodeMethod(AProcDef: TAbstractProcDef): AnsiString;

    { Exports all assembler symbols related to the obj-c class }
    procedure ExportObjCClass(ADef: TObjectDef);

    { loads a field of an Objective-C root class (such as ISA) }
    function ObjCLoadBaseField(ANode: TNode; const AFieldName: String): TNode;


implementation

    uses
      GlobType,Globals,VersionCmp,
      CUtils,
      Pass_1,
      Verbose,Systems,
      symconst,SymSym,
      objcdef,
      defutil,paramgr,
      nmem,ncal,nld,ncon,ncnv,
      export;


{******************************************************************
                       validselectorname
*******************************************************************}

function ObjCValidSelectorName(AValueString: PChar; ALength: LongInt): Boolean;
  var
    lIndex         : LongInt;
    lGotColon  : Boolean;
begin
  Result:=false;
  { empty name is not allowed }
  if (ALength=0) then
    exit;

  lGotColon:=false;

  { if the first character is a colon, all of them must be colons }
  if (AValueString[0] = ':') then
    begin
      for lIndex:=1 to ALength-1 do
        if (AValueString[lIndex]<>':') then
          exit;
    end
  else
    begin
      { no special characters other than ':'
      }
      for lIndex:=0 to ALength-1 do
        if (AValueString[lIndex] = ':') then
          lGotColon:=true
        else if not(AValueString[lIndex] in ['_','A'..'Z','a'..'z','0'..'9',':']) then
          exit;

      { if there is at least one colon, the final character must
        also be a colon (in case it's only one character that is
        a colon, this was already checked before the above loop)
      }
      if lGotColon and
         (AValueString[ALength-1] <> ':') then
        exit;
    end;

  Result:=true;
end;

{******************************************************************
                       objcsuperclassnode
*******************************************************************}

    function ObjCLoadBaseField(ANode: TNode; const AFieldName: String): TNode;
      var
        lSym         : TSym;
      begin
        lSym:=TSym(TAbstractRecordDef(ObjC_ObjectType).SymTable.Find(AFieldName));
        if not Assigned(lSym) or
           (lSym.typ<>FieldVarSym) then
          InternalError(200911301);
        if AFieldName='ISA' then
          Result:=CTypeConvNode.Create_Internal(
            CDerefNode.Create(
              CTypeConvNode.Create_Internal(ANode,
                CPointerDef.getreusable(CPointerDef.getreusable(VoidPointerType))
              )
            ),TFieldVarSym(lSym).vardef
          )
        else
          begin
            Result:=CDerefNode.Create(CTypeConvNode.Create_Internal(ANode,ObjC_IDType));
            Result:=CSubscriptNode.Create(lSym,Result);
          end;
      end;


    function ObjCSuperClassNode(ADef: TDef): TNode;
      var
        lPara       : TCallParaNode;
      begin
        { only valid for Objective-C classes and classrefs }
        if not Is_ObjCClass(ADef) and
           not Is_ObjCClassRef(ADef) then
          InternalError(2009090901);
        { Can be done a lot more efficiently with direct symbol accesses, but
          requires extra node types. Maybe later. }
        if Is_ObjCClassRef(ADef) then
          begin
            if (oo_is_classhelper in TObjectDef(TClassRefDef(ADef).PointedDef).ObjectOptions) then
              begin
                { in case we are in a category method, we need the metaclass of the
                  superclass class extended by this category (= metaclass of superclass of superclass)
                  for the fragile abi, and the metaclass of the superclass for the non-fragile ABI }
                { NOTE: those send2 methods are only available on Mac OS X 10.6 and later!
                    (but also on all iPhone SDK revisions we support) }
                if (TargetInfo.system in systems_objc_nfabi) and
                   (not MacOSXVersionMin.IsValid or
                    (MacOSXVersionMin.RelationTo(10,6,0)>=0)) then
                  Result:=CLoadVMTAddrNode.Create(CTypeNode.Create(TObjectDef(TClassRefDef(ADef).PointedDef).ChildOf))
                else
                  Result:=CLoadVMTAddrNode.Create(CTypeNode.Create(TObjectDef(TClassRefDef(ADef).PointedDef).ChildOf.ChildOf));
                TLoadVMTAddrNode(Result).ForCall:=true;
                Result:=CLoadVMTAddrNode.Create(Result);
                TypeCheckPass(Result);
                { we're done }
                exit;
              end
            else
              begin
                { otherwise we need the superclass of the metaclass }
                lPara:=CCallParaNode.Create(CStringConstNode.CreateStr(TObjectDef(TClassRefDef(ADef).PointedDef).ObjExtName^),nil);
                Result:=CCallNode.CreateInternFromUnit('OBJC','OBJC_GETMETACLASS',lPara);
              end
          end
        else
          begin
            if not(oo_is_classhelper in TObjectDef(ADef).ObjectOptions) then
              Result:=CLoadVMTAddrNode.Create(CTypeNode.Create(ADef))
            else
              Result:=CLoadVMTAddrNode.Create(CTypeNode.Create(TObjectDef(ADef).ChildOf));
            TLoadVMTAddrNode(Result).ForCall:=true;
          end;

        { For the non-fragile ABI, the superclass send2 method itself loads the
          superclass. For the fragile ABI, we have to do this ourselves.

          NOTE: those send2 methods are only available on Mac OS X 10.6 and later!
            (but also on all iPhone SDK revisions we support) }
        if not(TargetInfo.system in systems_objc_nfabi) or
           (MacOSXVersionMin.IsValid and
            (MacOSXVersionMin.RelationTo(10,6,0)<0)) then
          Result:=ObjCLoadBaseField(Result,'SUPERCLASS');
        TypeCheckPass(Result);
      end;


{******************************************************************
                          Type encoding
*******************************************************************}

    function ObjCParaSize(AParaSym: TParaVarSym): PtrInt;
      begin
        Result:=AParaSym.ParaLoc[callerside].IntSize;
        { In Objective-C, all ordinal types are widened to at least the
          size of the C "int" type. Assume __LP64__/4 byte ints for now. }
        if Is_Ordinal(AParaSym.vardef) and
           (Result<4) then
          Result:=4;
      end;


    function ObjCEncodeMethod(AProcDef: TAbstractProcDef): AnsiString;
      var
        lParaSize,
        lTotalSize: AInt;
        lSym: TParaVarSym;
        lIndex: LongInt;
        lTempString: AnsiString;
        lFoundError: TDef;
      begin
        Result:='';
        lTotalSize:=0;
        AProcDef.Init_ParaLoc_Info(callerside);
        for lIndex:=0 to AProcDef.paras.count-1 do
          begin
            lSym:=TParaVarSym(AProcDef.paras[lIndex]);
            if (vo_is_funcret in lSym.VarOptions) then
              continue;
            { objcaddencodedtype always assumes a value parameter, so add
              a pointer indirection for var/out parameters.  }
            if not ParaManager.Push_Addr_Param(vs_value,lSym.vardef,pocall_cdecl) and
               (lSym.VarSpez in [vs_var,vs_out,vs_constref]) then
              Result:=Result+'^';
            { Add the parameter type.  }
            if (vo_is_parentfp in lSym.VarOptions) and
               (po_is_block in AProcDef.ProcOptions) then
              { special case: self parameter of block procvars has to be @? }
              Result:=Result+'@?'
            else if not ObjCAddEncodedType(lSym.vardef,ris_initial,false,Result,lFoundError) then
              { should be checked earlier on }
              InternalError(2009081701);
            { And the total size of the parameters coming before this one
              (i.e., the "offset" of this parameter).  }
            Result:=Result+ToStr(lTotalSize);
            { Update the total parameter size }
            lParaSize:=ObjCParaSize(lSym);
            inc(lTotalSize,lParaSize);
          end;
        { Prepend the total parameter size.  }
        Result:=ToStr(lTotalSize)+Result;
        { And the type of the function result (void in case of a procedure).  }
        lTempString:='';
        if not ObjCAddEncodedType(AProcDef.ReturnDef,ris_initial,false,lTempString,lFoundError) then
          InternalError(2009081801);
        Result:=lTempString+Result;
      end;


{******************************************************************
                    ObjC class exporting
*******************************************************************}

    procedure ExportObjCClassFields(AObjCClass: TObjectDef);
    var
      lIndex: LongInt;
      lFieldSym: TFieldVarSym;
      lPrefix: String;
    begin
      lPrefix:=TargetInfo.cprefix+'OBJC_IVAR_$_'+AObjCClass.ObjExtName^+'.';
      for lIndex:=0 to AObjCClass.SymTable.SymList.Count-1 do
        if TSym(AObjCClass.SymTable.SymList[lIndex]).typ=FieldVarSym then
          begin
            lFieldSym:=TFieldVarSym(AObjCClass.SymTable.SymList[lIndex]);
            { TODO: package visibility (private_extern) -- must not be exported
               either}
            if not(lFieldSym.visibility in [vis_private,vis_strictprivate]) then
              exportname(lPrefix+lFieldSym.RealName,[]);
          end;
    end;


    procedure ExportObjCClass(ADef: TObjectDef);
      begin
        if (TargetInfo.system in systems_objc_nfabi) then
          begin
            { export class and metaclass symbols }
            exportname(ADef.RTTIMangledName(objcclassrtti),[]);
            exportname(ADef.RTTIMangledName(objcmetartti),[]);
            { export public/protected instance variable offset symbols }
            ExportObjCClassFields(ADef);
          end
        else
          begin
             { export the class symbol }
             exportname('.objc_class_name_'+ADef.ObjExtName^,[]);
          end;
      end;

end.
