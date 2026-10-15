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
    function objcvalidselectorname(value_str: pchar; len: LongInt): boolean;

    { Generate a node loading the superclass structure necessary to call
      an inherited Objective-C method.  }
    function objcsuperclassnode(def: TDef): TNode;

    { Encode a method's parameters and result type into the format used by the
      run time (for generating protocol and class rtti).  }
    function objcencodemethod(pd: TAbstractProcDef): AnsiString;

    { Exports all assembler symbols related to the obj-c class }
    procedure exportobjcclass(def: TObjectDef);

    { loads a field of an Objective-C root class (such as ISA) }
    function objcloadbasefield(n: TNode; const fieldname: string): TNode;


implementation

    uses
      GlobType,Globals,VersionCmp,
      CUtils,
      pass_1,
      Verbose,Systems,
      symconst,SymSym,
      objcdef,
      defutil,paramgr,
      nmem,ncal,nld,ncon,ncnv,
      export;


{******************************************************************
                       validselectorname
*******************************************************************}

function objcvalidselectorname(value_str: pchar; len: LongInt): boolean;
  var
    i         : LongInt;
    gotcolon  : boolean;
begin
  result:=false;
  { empty name is not allowed }
  if (len=0) then
    exit;

  gotcolon:=false;

  { if the first character is a colon, all of them must be colons }
  if (value_str[0] = ':') then
    begin
      for i:=1 to len-1 do
        if (value_str[i]<>':') then
          exit;
    end
  else
    begin
      { no special characters other than ':'
      }
      for i:=0 to len-1 do
        if (value_str[i] = ':') then
          gotcolon:=true
        else if not(value_str[i] in ['_','A'..'Z','a'..'z','0'..'9',':']) then
          exit;

      { if there is at least one colon, the final character must
        also be a colon (in case it's only one character that is
        a colon, this was already checked before the above loop)
      }
      if gotcolon and
         (value_str[len-1] <> ':') then
        exit;
    end;

  result:=true;
end;

{******************************************************************
                       objcsuperclassnode
*******************************************************************}

    function objcloadbasefield(n: TNode; const fieldname: string): TNode;
      var
        vs         : TSym;
      begin
        vs:=TSym(TAbstractRecordDef(objc_objecttype).SymTable.Find(fieldname));
        if not Assigned(vs) or
           (vs.typ<>fieldvarsym) then
          InternalError(200911301);
        if fieldname='ISA' then
          result:=CTypeConvNode.create_internal(
            CDerefNode.create(
              CTypeConvNode.create_internal(n,
                CPointerDef.getreusable(CPointerDef.getreusable(voidpointertype))
              )
            ),TFieldVarSym(vs).vardef
          )
        else
          begin
            result:=CDerefNode.create(CTypeConvNode.create_internal(n,objc_idtype));
            result:=CSubscriptNode.create(vs,result);
          end;
      end;


    function objcsuperclassnode(def: TDef): TNode;
      var
        para       : TCallParaNode;
      begin
        { only valid for Objective-C classes and classrefs }
        if not is_objcclass(def) and
           not is_objcclassref(def) then
          InternalError(2009090901);
        { Can be done a lot more efficiently with direct symbol accesses, but
          requires extra node types. Maybe later. }
        if is_objcclassref(def) then
          begin
            if (oo_is_classhelper in TObjectDef(TClassRefDef(def).pointeddef).objectoptions) then
              begin
                { in case we are in a category method, we need the metaclass of the
                  superclass class extended by this category (= metaclass of superclass of superclass)
                  for the fragile abi, and the metaclass of the superclass for the non-fragile ABI }
                { NOTE: those send2 methods are only available on Mac OS X 10.6 and later!
                    (but also on all iPhone SDK revisions we support) }
                if (TargetInfo.system in systems_objc_nfabi) and
                   (not MacOSXVersionMin.IsValid or
                    (MacOSXVersionMin.RelationTo(10,6,0)>=0)) then
                  result:=CLoadVMTAddrNode.create(CTypeNode.create(TObjectDef(TClassRefDef(def).pointeddef).childof))
                else
                  result:=CLoadVMTAddrNode.create(CTypeNode.create(TObjectDef(TClassRefDef(def).pointeddef).childof.childof));
                TLoadVMTAddrNode(result).forcall:=true;
                result:=CLoadVMTAddrNode.create(result);
                TypeCheckPass(result);
                { we're done }
                exit;
              end
            else
              begin
                { otherwise we need the superclass of the metaclass }
                para:=CCallParaNode.create(CStringConstNode.createstr(TObjectDef(TClassRefDef(def).pointeddef).objextname^),nil);
                result:=CCallNode.createinternfromunit('OBJC','OBJC_GETMETACLASS',para);
              end
          end
        else
          begin
            if not(oo_is_classhelper in TObjectDef(def).objectoptions) then
              result:=CLoadVMTAddrNode.create(CTypeNode.create(def))
            else
              result:=CLoadVMTAddrNode.create(CTypeNode.create(TObjectDef(def).childof));
            TLoadVMTAddrNode(result).forcall:=true;
          end;

        { For the non-fragile ABI, the superclass send2 method itself loads the
          superclass. For the fragile ABI, we have to do this ourselves.

          NOTE: those send2 methods are only available on Mac OS X 10.6 and later!
            (but also on all iPhone SDK revisions we support) }
        if not(TargetInfo.system in systems_objc_nfabi) or
           (MacOSXVersionMin.IsValid and
            (MacOSXVersionMin.RelationTo(10,6,0)<0)) then
          result:=objcloadbasefield(result,'SUPERCLASS');
        TypeCheckPass(result);
      end;


{******************************************************************
                          Type encoding
*******************************************************************}

    function objcparasize(vs: TParaVarSym): ptrint;
      begin
        result:=vs.paraloc[callerside].intsize;
        { In Objective-C, all ordinal types are widened to at least the
          size of the C "int" type. Assume __LP64__/4 byte ints for now. }
        if is_ordinal(vs.vardef) and
           (result<4) then
          result:=4;
      end;


    function objcencodemethod(pd: TAbstractProcDef): AnsiString;
      var
        parasize,
        totalsize: aint;
        vs: TParaVarSym;
        i: LongInt;
        temp: AnsiString;
        founderror: TDef;
      begin
        result:='';
        totalsize:=0;
        pd.init_paraloc_info(callerside);
        for i:=0 to pd.paras.count-1 do
          begin
            vs:=TParaVarSym(pd.paras[i]);
            if (vo_is_funcret in vs.varoptions) then
              continue;
            { objcaddencodedtype always assumes a value parameter, so add
              a pointer indirection for var/out parameters.  }
            if not paramanager.push_addr_param(vs_value,vs.vardef,pocall_cdecl) and
               (vs.varspez in [vs_var,vs_out,vs_constref]) then
              result:=result+'^';
            { Add the parameter type.  }
            if (vo_is_parentfp in vs.varoptions) and
               (po_is_block in pd.procoptions) then
              { special case: self parameter of block procvars has to be @? }
              result:=result+'@?'
            else if not objcaddencodedtype(vs.vardef,ris_initial,false,result,founderror) then
              { should be checked earlier on }
              InternalError(2009081701);
            { And the total size of the parameters coming before this one
              (i.e., the "offset" of this parameter).  }
            result:=result+ToStr(totalsize);
            { Update the total parameter size }
            parasize:=objcparasize(vs);
            inc(totalsize,parasize);
          end;
        { Prepend the total parameter size.  }
        result:=ToStr(totalsize)+result;
        { And the type of the function result (void in case of a procedure).  }
        temp:='';
        if not objcaddencodedtype(pd.returndef,ris_initial,false,temp,founderror) then
          InternalError(2009081801);
        result:=temp+result;
      end;


{******************************************************************
                    ObjC class exporting
*******************************************************************}

    procedure exportobjcclassfields(objccls: TObjectDef);
    var
      i: LongInt;
      vf: TFieldVarSym;
      prefix: string;
    begin
      prefix:=TargetInfo.cprefix+'OBJC_IVAR_$_'+objccls.objextname^+'.';
      for i:=0 to objccls.SymTable.SymList.Count-1 do
        if TSym(objccls.SymTable.SymList[i]).typ=fieldvarsym then
          begin
            vf:=TFieldVarSym(objccls.SymTable.SymList[i]);
            { TODO: package visibility (private_extern) -- must not be exported
               either}
            if not(vf.visibility in [vis_private,vis_strictprivate]) then
              exportname(prefix+vf.RealName,[]);
          end;
    end;


    procedure exportobjcclass(def: TObjectDef);
      begin
        if (TargetInfo.system in systems_objc_nfabi) then
          begin
            { export class and metaclass symbols }
            exportname(def.RTTIMangledName(objcclassrtti),[]);
            exportname(def.RTTIMangledName(objcmetartti),[]);
            { export public/protected instance variable offset symbols }
            exportobjcclassfields(def);
          end
        else
          begin
             { export the class symbol }
             exportname('.objc_class_name_'+def.objextname^,[]);
          end;
      end;

end.
