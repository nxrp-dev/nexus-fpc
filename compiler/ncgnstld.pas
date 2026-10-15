{
    Copyright (c) 2011 by Jonas Maebe

    Support for load nodes on targets that have to group all local variables
    and parameters accessed by nested routines into structs (and then pass the
    address of these structs to nested routines rather than the frame pointer,
    and access the local variables as fields thereof)

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
unit ncgnstld;

{$i fpcdefs.inc}

interface

    uses
       node,
       symtype,
       nld,
       ncgld;

    type
       TCGNestLoadNode = class(TCGLoadNode)
        protected
         nestsym: TSym;
         nestsymderef: TDeref;
         procedure generate_nested_access(vs: TSym);override;
         function  keep_param_address_in_nested_struct: boolean; virtual;
        public
         function  pass_typecheck: TNode; override;
         function  pass_1:TNode;override;
         function  dogetcopy: TNode; override;
         function  docompare(p: TNode): boolean; override;
         constructor ppuload(t: TNodeType; ppufile: TCompilerPPUFile); override;
         procedure ppuwrite(ppufile: TCompilerPPUFile); override;
         procedure BuildDerefImpl; override;
         procedure derefimpl; override;
       end;

implementation

    uses
      CUtils,Verbose,GlobType,Globals,Systems,ConstExp,
      defutil,defcmp,
      htypechk,pass_1,ProcInfo,paramgr,
      CPUInfo,
      symconst,SymBase,SymSym,symdef,SymTable,pparautl,symcreat,
      ncon,ninl,ncnv,nmem,ncal,nutils,nbas,
      pass_2,cgbase
      ;

{*****************************************************************************
                          TCGNESTLOADNODE
*****************************************************************************}

    procedure TCGNestLoadNode.generate_nested_access(vs: TSym);
      begin
        { left has been transformed into a string of accesses that result in
          the location of the original variable's copy in the appropriate
          parentfpstruct (via tcgnestloadparentfpnode.pass_1). In case it is a
          var/out/constref parameter, that "copy" will have been a copy of the
          address so the normal handling of such parameters in ncgld is ok) }
        SecondPass(left);
        location:=left.location;
      end;


    function TCGNestLoadNode.keep_param_address_in_nested_struct: boolean;
      begin
        result:=is_addr_param_load;
      end;


    function TCGNestLoadNode.pass_typecheck: TNode;
      var
        nestedvars: TSym;
      begin
        result:=inherited pass_typecheck;
        if Assigned(result) or
           (Assigned(CurrentProcInfo) and
            (df_generic in CurrentProcInfo.procdef.DefOptions)) then
          exit;
        case symtableentry.typ of
          paravarsym,
          localvarsym :
            begin
              { Nested variable? Then we have to move it to a structure that
                can be passed by reference to nested routines }
              if Assigned(CurrentProcInfo) and
                 (SymTable.SymTableType in [LocalSymTable,parasymtable]) and
                 ((SymTable.SymTableLevel<>CurrentProcInfo.procdef.ParaST.SymTableLevel) or
                  { also redirect loads of locals/paras that have been moved to
                     the parentfpstruct inside the routine in which they were
                     originally declared, except in the initialisation code for
                     the parentfpstruct (nf_internal flag) }
                  TAbstractNormalVarSym(symtableentry).InParentFPStruct) and
                   not(nf_internal in flags) then
                begin
                  { get struct holding all locals accessed by nested routines }
                  nestedvars:=TProcDef(SymTable.DefOwner).ParentFPStruct;
                  { don't add the parentfpstruct to itself! }
                  if nestedvars=symtableentry then
                    exit;
                  if not Assigned(nestedvars) then
                    begin
                      { create this struct }
                      build_parentfpstruct(TProcDef(SymTable.DefOwner));
                      nestedvars:=TProcDef(SymTable.DefOwner).ParentFPStruct;
                    end;
                  {  store result for use in pass_1 }
                  nestsym:=Maybe_Add_Sym_To_ParentFPStruct(TProcDef(symtableentry.owner.DefOwner),symtableentry,resultdef,keep_param_address_in_nested_struct);
                  { left normally holds the parentfp node. If it's not assigned,
                    this is an access to a local variable/para from the routine
                    in which it was actually declared -> redirect to its
                    equivalent in the parentfp struct }
                  if not Assigned(left) then
                    begin
                      left:=CAddrNode.Create_Internal(CLoadNode.create(TProcDef(symtableentry.owner.DefOwner).ParentFPStruct,TProcDef(symtableentry.owner.DefOwner).ParentFPStruct.owner));
                      include(TAddrNode(left).addrnodeflags,anf_typedaddr);
                    end;
                  TypeCheckPass(left);
                end;
            end;
          else
            ;
        end;
      end;


    function TCGNestLoadNode.pass_1:TNode;
      var
        thissym,
        nestedvars: TSym;
      begin
        result:=inherited;
        if Assigned(result) then
          exit;
        case symtableentry.typ of
          paravarsym,
          localvarsym :
            begin
              { Nested variable? Then we have to move it to a structure that
                can be passed by reference to nested routines }
              if Assigned(left) and
                 not(nf_internal in flags) then
                begin
                  { get struct holding all locals accessed by nested routines }
                  nestedvars:=TProcDef(SymTable.DefOwner).ParentFPStruct;
                  if not Assigned(nestedvars) then
                    begin
                      { create this struct }
                      build_parentfpstruct(TProcDef(SymTable.DefOwner));
                      nestedvars:=TProcDef(SymTable.DefOwner).ParentFPStruct;
                    end;
                  if nestedvars<>symtableentry then
                    thissym:=nestsym
                  else
                    thissym:=Find_Sym_In_ParentFPStruct(TProcDef(symtableentry.owner.DefOwner),symtableentry);
                  if not Assigned(thissym) then
                    InternalError(2011060406);
                  { firstpass the parentfpnode. This will transform it into
                    a load of the appropriate parentfpstruct }
                  if not Assigned(left) then
                    InternalError(2011060104);
                  FirstPass(left);
                  if left.resultdef.typ<>pointerdef then
                    InternalError(2015122801);
                  { subscript it to get the variable }
                  left:=CSubscriptNode.create(thissym,CDerefNode.create(left));
                  FirstPass(left);
                  include(flags,nf_internal);
                end;
            end;
          else
            ;
        end;
      end;


    function TCGNestLoadNode.dogetcopy: TNode;
      begin
        result:=inherited dogetcopy;
        TCGNestLoadNode(result).nestsym:=nestsym;
      end;


    function TCGNestLoadNode.docompare(p: TNode): boolean;
      begin
        result:=
          inherited docompare(p) and
          (TCGNestLoadNode(p).nestsym=nestsym);
      end;


    constructor TCGNestLoadNode.ppuload(t: TNodeType; ppufile: TCompilerPPUFile);
      begin
        inherited ppuload(t, ppufile);
        ppufile.GetDeref(nestsymderef);
      end;


    procedure TCGNestLoadNode.ppuwrite(ppufile: TCompilerPPUFile);
      begin
        inherited ppuwrite(ppufile);
        ppufile.PutDeref(nestsymderef);
      end;


    procedure TCGNestLoadNode.BuildDerefImpl;
      begin
        inherited BuildDerefImpl;
        nestsymderef.build(nestsym);
      end;


    procedure TCGNestLoadNode.derefimpl;
      begin
        inherited derefimpl;
        nestsym:=TSym(nestsymderef.resolve);
      end;


begin
  CLoadNode:=TCGNestLoadNode;
end.
