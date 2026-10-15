{
    Copyright (c) 1998-2002 by Florian Klaempfl


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
unit ncgnstmm;

{$i fpcdefs.inc}

interface

    uses
      GlobType,cgbase,CPUInfo,cpubase,
      node,ncgmem;

    type
       TCGNestLoadParentFPNode = class(TCGLoadParentFPNode)
          function pass_typecheck: TNode; override;
          function pass_1: TNode; override;
          procedure pass_generate_code;override;
       end;

implementation

    uses
      Systems,
      CUtils,CClasses,Verbose,Globals,ConstExp,
      symconst,symdef,SymSym,SymTable,defutil,procdefutil,pparautl,symcreat,
      aasmbase,aasmtai,AAsmData,
      ProcInfo,pass_2,parabase,paramgr,
      pass_1,ncnv,nmem,nld,ncon,nadd,nutils,
      cgutils,cgobj,hlcgobj,
      tgobj,ncgutil,objcgutl
      ;


{*****************************************************************************
                        TCGLOADPARENTFPNODE
*****************************************************************************}

    function TCGNestLoadParentFPNode.pass_typecheck: TNode;
      var
        hsym        : TParaVarSym;
        currpi,
        nextpi      : TProcInfo;
      begin
        result:=inherited;
        if Assigned(result) or
           (Assigned(CurrentProcInfo) and
            (df_generic in CurrentProcInfo.procdef.defoptions)) then
          exit;
        currpi:=CurrentProcInfo.parent;
        { current_procinfo.parent is not assigned for specialised generic routines in the
          top-level scope }
        while Assigned(currpi) and
              (currpi.procdef.parast.symtablelevel>=parentpd.parast.symtablelevel) do
          begin
            if not Assigned(currpi.procdef.parentfpstruct) then
              build_parentfpstruct(currpi.procdef);
            currpi:=currpi.parent;
          end;
        { mark all parent parentfp parameters for inclusion in the struct that
          holds all locals accessed from nested routines }
        currpi:=CurrentProcInfo.parent;
        if Assigned(currpi) then
          begin
            nextpi:=currpi.parent;
            while Assigned(currpi) and
                  (currpi.procdef.parast.symtablelevel>parentpd.parast.symtablelevel) do
              begin
                hsym:=TParaVarSym(currpi.procdef.parentfpsym);
                maybe_add_sym_to_parentfpstruct(currpi.procdef,hsym,nextpi.procdef.parentfpstructptrtype,false);
                currpi:=nextpi;
                nextpi:=nextpi.parent;
              end;
          end;
      end;


    function TCGNestLoadParentFPNode.pass_1: TNode;
      var
        fsym        : TFieldVarSym;
        hsym        : TParaVarSym;
        currpi      : TProcInfo;
        useparentfppara :  boolean;
      begin
        result:=nil;
        { if the current routine does not call a nested routine, or if that
          nested routine does nothing for which it needs the nestedfp pointer
          of the current routine (and hence it has not been moved into the
          nestedfp struct), get the original nestedfp parameter }
        useparentfppara:=not Assigned(CurrentProcInfo.procdef.parentfpstruct);
        hsym:=TParaVarSym(CurrentProcInfo.procdef.parast.Find('parentfp'));
        if CurrentProcInfo.procdef.parast.symtablelevel>parentpd.parast.symtablelevel then
          useparentfppara:=
            useparentfppara or
            (find_sym_in_parentfpstruct(CurrentProcInfo.procdef,hsym)=nil);
        if useparentfppara then
          begin
            result:=CLoadNode.create(hsym,hsym.owner);
            currpi:=CurrentProcInfo.parent;
          end
        else
          begin
            result:=CAddrNode.create_internal(CLoadNode.create(CurrentProcInfo.procdef.parentfpstruct,CurrentProcInfo.procdef.parentfpstruct.owner));
            include(TAddrNode(result).addrnodeflags,anf_typedaddr);
            currpi:=CurrentProcInfo;
          end;
        { follow the chain of parentfpstructs until we arrive at the one we
          need }
        while (currpi.procdef.parast.symtablelevel>parentpd.parast.symtablelevel) do
          begin
            hsym:=TParaVarSym(currpi.procdef.parentfpsym);
            fsym:=TFieldVarSym(find_sym_in_parentfpstruct(currpi.procdef,hsym));
            if not Assigned(fsym) then
              InternalError(2011060405);
            result:=CSubscriptNode.create(fsym,CDerefNode.create(result));
            currpi:=currpi.parent;
          end;
      end;


    procedure TCGNestLoadParentFPNode.pass_generate_code;
      begin
        { should be handled in pass 1 }
        InternalError(2011060202);
      end;


begin
   CLoadParentFPNode:=TCGNestLoadParentFPNode;
end.
