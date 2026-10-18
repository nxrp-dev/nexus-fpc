{
    Copyright (c) 1998-2002 by Jonas Maebe

    This unit implements optimized nodes

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
unit nopt;

{$i fpcdefs.inc}

interface

uses node,nbas,nadd,ConstExp;

type
  TSubNodeType = (
    addsstringcharoptn,  { shorstring + char }
    addsstringcsstringoptn   { shortstring + constant shortstring }
  );

  TAddOptNode = class(TAddNode)
     subnodetype: TSubNodeType;
     constructor Create(ts: TSubNodeType; l,r : TNode); virtual; reintroduce;
     { pass_1 will be overridden by the separate subclasses    }
     { By default, pass_generate_code is the same as for addnode           }
     { Only if there's a processor specific implementation, it }
     { will be overridden.                                     }
     function DoGetCopy: TNode; override;
     function DoCompare(p: TNode): boolean; override;
  end;

  TAddSStringOptNode = class(TAddOptNode)
    { maximum length of the string until now, allows us to skip a compare }
    { sometimes (it's initialized/updated by calling updatecurmaxlen)     }
    curmaxlen: byte;
    { pass_1 must be overridden, otherwise we get an endless loop }
    function Pass_TypeCheck: TNode; override;
    function Pass_1: TNode; override;
    function DoGetCopy: TNode; override;
    function DoCompare(p: TNode): boolean; override;
   protected
    procedure updatecurmaxlen;
  end;

  { add a char to a shortstring }
  TAddSStringCharOptNode = class(TAddSStringOptNode)
    constructor Create(l,r : TNode); virtual; reintroduce;
  end;
  TAddSStringCharOptNodeClass = class of TAddSStringCharOptNode;

  { add a constant string to a short string }
  TAddSStringCSStringOptNode = class(TAddSStringOptNode)
    constructor Create(l,r : TNode); virtual; reintroduce;
    function Pass_1: TNode; override;
  end;
  TAddSStringCSStringOptNodeClass = class of TAddSStringCSStringOptNode;

function canbeaddsstringcharoptnode(p: TAddNode): boolean;
function genaddsstringcharoptnode(p: TAddNode): TNode;
function canbeaddsstringcsstringoptnode(p: TAddNode): boolean;
function genaddsstringcsstringoptnode(p: TAddNode): TNode;
function canbemultistringadd(p: TAddNode): boolean;
function genmultistringadd(p: TAddNode): TNode;
function canbemultidynarrayadd(p: TAddNode): boolean;
function genmultidynarrayadd(p: TAddNode): TNode;


function is_addsstringoptnode(p: TNode): boolean;

var
   CAddSStringCharOptNode: TAddSStringCharOptNodeClass;
   CAddSStringCSStringOptNode: TAddSStringCSStringOptNodeClass;

implementation

uses CUtils, Systems,
     htypechk, defutil, defcmp, GlobType, Globals, cpubase, compinnr,
     ncnv, ncon, ncal, ninl, nld, nmem,
     Verbose, symconst,symdef, cgbase, ProcInfo;


{*****************************************************************************
                             TADDOPTNODE
*****************************************************************************}

constructor TAddOptNode.Create(ts: TSubNodeType; l,r : TNode);
begin
  { we need to keep the addn nodetype, otherwise taddnode.pass_generate_code will be }
  { confused. Comparison for equal nodetypes therefore has to be         }
  { implemented using the classtype() method (JM)                        }
  inherited Create(addn,l,r);
  subnodetype := ts;
end;

function TAddOptNode.DoGetCopy: TNode;
var
  hp: TAddOptNode;
begin
  hp := TAddOptNode(inherited DoGetCopy);
  hp.subnodetype := subnodetype;
  DoGetCopy := hp;
end;

function TAddOptNode.DoCompare(p: TNode): boolean;
begin
  DoCompare :=
    inherited DoCompare(p) and
    (subnodetype = TAddOptNode(p).subnodetype);
end;


{*****************************************************************************
                        TADDSSTRINGOPTNODE
*****************************************************************************}

function TAddSStringOptNode.Pass_TypeCheck: TNode;
begin
  result := nil;
  updatecurmaxlen;
  { left and right are already firstpass'ed by taddnode.pass_1 }
  if not Is_ShortString(left.resultdef) then
   InsertTypeConv(left,CShortStringType);
  if not Is_ShortString(right.resultdef) then
   InsertTypeConv(right,CShortStringType);
  resultdef := left.resultdef;
end;

function TAddSStringOptNode.Pass_1: TNode;
begin
  Pass_1 := nil;
  expectloc:= LOC_REFERENCE;
  { here we call STRCONCAT or STRCMP or STRCOPY }
  include(CurrentProcInfo.flags,pi_do_call);
end;

function TAddSStringOptNode.DoGetCopy: TNode;
var
  hp: TAddSStringOptNode;
begin
  hp := TAddSStringOptNode(inherited DoGetCopy);
  hp.curmaxlen := curmaxlen;
  DoGetCopy := hp;
end;

function TAddSStringOptNode.DoCompare(p: TNode): boolean;
begin
  DoCompare :=
    inherited DoCompare(p) and
    (curmaxlen = TAddSStringCharOptNode(p).curmaxlen);
end;


function is_addsstringoptnode(p: TNode): boolean;
begin
  is_addsstringoptnode :=
    p.inheritsfrom(TAddSStringOptNode);
end;

procedure TAddSStringOptNode.updatecurmaxlen;
begin
  if is_addsstringoptnode(left) then
    begin
      { made it a separate block so no other if's are processed (would be a }
      { simple waste of time) (JM)                                          }
      if (TAddSStringOptNode(left).curmaxlen < 255) then
        case subnodetype of
          addsstringcharoptn:
            curmaxlen := succ(TAddSStringOptNode(left).curmaxlen);
          addsstringcsstringoptn:
            curmaxlen := min(TAddSStringOptNode(left).curmaxlen +
                              TStringConstNode(right).len,255)
        end
      else
        curmaxlen := 255;
    end
  else if (left.nodetype = stringconstn) then
    curmaxlen := min(TStringConstNode(left).len,255)
  else if Is_Char(left.resultdef) then
    curmaxlen := 1
  else if (left.nodetype = typeconvn) then
    begin
      case TTypeConvNode(left).ConvType of
        tc_char_2_string:
          curmaxlen := 1;
{       doesn't work yet, don't know why (JM)
        tc_chararray_2_string:
          curmaxlen :=
            min(ttypeconvnode(left).left.resultdef.size,255); }
        else curmaxlen := 255;
      end;
    end
  else
    curmaxlen := 255;
end;

{*****************************************************************************
                        TADDSSTRINGCHAROPTNODE
*****************************************************************************}


constructor TAddSStringCharOptNode.Create(l,r : TNode);
begin
  inherited Create(addsstringcharoptn,l,r);
end;

{*****************************************************************************
                        TADDSSTRINGCSSTRINGOPTNODE
*****************************************************************************}


constructor TAddSStringCSStringOptNode.Create(l,r : TNode);
begin
  inherited Create(addsstringcsstringoptn,l,r);
end;


function TAddSStringCSStringOptNode.Pass_1: TNode;
begin
  { create the call to the concat routine both strings as arguments }
  result := CCallNode.CreateIntern('fpc_shortstr_append_shortstr',
    CCallParaNode.Create(left,CCallParaNode.Create(right,nil)));
  left:=nil;
  right:=nil;
end;


{*****************************************************************************
                                HELPERS
*****************************************************************************}

function canbeaddsstringcharoptnode(p: TAddNode): boolean;
begin
  canbeaddsstringcharoptnode :=
    (cs_opt_level1 in CurrentSettings.OptimizerSwitches) and

{   the shortstring will be gotten through conversion if necessary (JM)
    is_shortstring(p.left.resultdef) and }
    ((p.nodetype = addn) and
     Is_Char(p.right.resultdef));
end;

function genaddsstringcharoptnode(p: TAddNode): TNode;
var
  hp: TNode;
begin
  hp := CAddSStringCharOptNode.Create(p.left.GetCopy,p.right.GetCopy);
  hp.flags := p.flags;
  genaddsstringcharoptnode := hp;
end;



function canbeaddsstringcsstringoptnode(p: TAddNode): boolean;
begin
  canbeaddsstringcsstringoptnode :=
    (cs_opt_level1 in CurrentSettings.OptimizerSwitches) and

{   the shortstring will be gotten through conversion if necessary (JM)
    is_shortstring(p.left.resultdef) and }
    ((p.nodetype = addn) and
     (p.right.nodetype = stringconstn));
end;

function genaddsstringcsstringoptnode(p: TAddNode): TNode;
var
  hp: TNode;
begin
  hp := CAddSStringCSStringOptNode.Create(p.left.GetCopy,p.right.GetCopy);
  hp.flags := p.flags;
  genaddsstringcsstringoptnode := hp;
end;


function canbemultistringadd(p: TAddNode): boolean;
var
  hp : TNode;
  i  : LongInt;
begin
  result:=false;
  if p.resultdef.typ<>stringdef then
    exit;
  i:=0;
  hp:=p;
  while Assigned(hp) and (hp.nodetype=addn) do
    begin
      inc(i);
      hp:=TAddNode(hp).left;
    end;
  result:=(i>1);
end;


function genmultistringadd(p: TAddNode): TNode;
var
  hp,sn : TNode;
  arrp  : TArrayConstructorNode;
  newstatement : TStatementNode;
  tempnode    : TTempCreateNode;
  is_shortstr : boolean;
  para : TCallParaNode;
begin
  arrp:=nil;
  hp:=p;
  is_shortstr:=Is_ShortString(p.resultdef);
  while Assigned(hp) and (hp.nodetype=addn) do
    begin
      sn:=TAddNode(hp).right.GetCopy;
      if not is_shortstr or not Is_ShortString(sn.resultdef) then
        InsertTypeConv(sn,p.resultdef);
      if is_shortstr then
        begin
          sn:=CAddrNode.Create(sn);
          include(sn.flags,nf_internal);
        end;
      arrp:=CArrayConstructorNode.Create(sn,arrp);
      hp:=TAddNode(hp).left;
    end;
  sn:=hp.GetCopy;
  if not is_shortstr or not Is_ShortString(sn.resultdef) then
    InsertTypeConv(sn,p.resultdef);
  if is_shortstr then
    begin
      sn:=CAddrNode.Create(sn);
      include(sn.flags,nf_internal);
    end;
  arrp:=CArrayConstructorNode.Create(sn,arrp);
  Include(arrp.ArrayConstructorNodeFlags, acnf_allow_array_constructor);
  if Assigned(AktAssignmentNode) and
     (AktAssignmentNode.right=p) and
     (
       (AktAssignmentNode.left.resultdef=p.resultdef) or
       (
         Is_ShortString(AktAssignmentNode.left.resultdef) and
         Is_ShortString(p.resultdef)
       )
     ) and
     valid_for_var(AktAssignmentNode.left,false) then
    begin
      para:=CCallParaNode.Create(
              arrp,
              CCallParaNode.Create(AktAssignmentNode.left.GetCopy,nil)
            );
      if Is_AnsiString(p.resultdef) then
        para:=CCallParaNode.Create(
                COrdConstNode.Create(
                  { don't use getparaencoding(), we have to know
                    when the result is rawbytestring }
                  TStringDef(p.resultdef).encoding,
                  U16IntType,
                  true
                ),
                para
              );
      result:=CCallNode.CreateIntern(
                'fpc_'+TStringDef(p.resultdef).StringTypName+'_concat_multi',
                para
              );
      include(AktAssignmentNode.AssignmentNodeFlags,anf_assign_done_in_right);
    end
  else
    begin
      result:=InternalStatements(newstatement);
      tempnode:=CTempCreateNode.Create(p.resultdef,p.resultdef.Size,tt_persistent ,true);
      AddStatement(newstatement,tempnode);
      para:=CCallParaNode.Create(
              arrp,
              CCallParaNode.Create(CTempRefNode.Create(tempnode),nil)
            );
      if Is_AnsiString(p.resultdef) then
        para:=CCallParaNode.Create(
                COrdConstNode.Create(
                  { don't use getparaencoding(), we have to know
                    when the result is rawbytestring }
                  TStringDef(p.resultdef).encoding,
                  U16IntType,
                  true
                ),
                para
              );
      AddStatement(
        newstatement,
        CCallNode.CreateIntern(
          'fpc_'+TStringDef(p.resultdef).StringTypName+'_concat_multi',
          para
        )
      );
      AddStatement(newstatement,CTempDeleteNode.Create_Normal_Temp(tempnode));
      AddStatement(newstatement,CTempRefNode.Create(tempnode));
    end;
end;


function canbemultidynarrayadd(p: TAddNode): boolean;
var
  hp : TNode;
  i  : LongInt;
begin
  result:=false;
  if not(Is_Dynamic_Array(p.resultdef)) then
    exit;
  i:=0;
  hp:=p;
  while Assigned(hp) and (hp.nodetype=addn) do
    begin
      inc(i);
      hp:=TAddNode(hp).left;
    end;
  result:=(i>1);
end;


function genmultidynarrayadd(p: TAddNode): TNode;
var
  hp    : TNode;
  arrp  : TArrayConstructorNode;
  newstatement : TStatementNode;
  tempnode    : TTempCreateNode;
  para : TCallParaNode;

  { operands read from a variable (possibly through fields/elements/derefs)
    are anchored by that storage: they need no lifetime help and their
    refcount must stay untouched so fpc_dynarray_concat_multi can still
    detect refcount=1 and append to the destination in place }
  function is_stored_operand(n: TNode): boolean;
    begin
      while n.nodetype in [subscriptn,vecn,derefn] do
        n:=TUnaryNode(n).left;
      is_stored_operand:=n.nodetype=loadn;
    end;

  { store any other operand (call result, literal, nested concat) in a
    reference counted persistent temp so it stays alive until the concat
    call, then hand the helper a plain pointer to it }
  function operandref(n: TNode): TNode;
    var
      optemp : TTempCreateNode;
    begin
      if is_stored_operand(n) then
        exit(CTypeConvNode.Create_Internal(n,VoidPointerType));
      if not Is_Array_Constructor(n.resultdef) then
        InsertTypeConv(n,p.resultdef);
      optemp:=CTempCreateNode.Create(p.resultdef,p.resultdef.Size,tt_persistent,true);
      AddStatement(newstatement,optemp);
      AddStatement(newstatement,CAssignmentNode.Create(CTempRefNode.Create(optemp),n));
      AddStatement(newstatement,CTempDeleteNode.Create_Normal_Temp(optemp));
      operandref:=CTypeConvNode.Create_Internal(CTempRefNode.Create(optemp),VoidPointerType);
    end;

begin
  result:=InternalStatements(newstatement);
  arrp:=nil;
  hp:=p;
  while Assigned(hp) and (hp.nodetype=addn) do
    begin
      arrp:=CArrayConstructorNode.Create(operandref(TAddNode(hp).right.GetCopy),arrp);
      hp:=TAddNode(hp).left;
    end;
  arrp:=CArrayConstructorNode.Create(operandref(hp.GetCopy),arrp);
  Include(arrp.ArrayConstructorNodeFlags, acnf_allow_array_constructor);
  if Assigned(AktAssignmentNode) and
     (AktAssignmentNode.right=p) and
     (AktAssignmentNode.left.resultdef=p.resultdef) and
     valid_for_var(AktAssignmentNode.left,false) then
    begin
      para:=CCallParaNode.Create(
              arrp,
            CCallParaNode.Create(
              CAddrNode.Create_Internal(CRTTINode.Create(TStoredDef(p.resultdef),initrtti,rdt_normal)),
            CCallParaNode.Create(
              CTypeConvNode.Create_Internal(AktAssignmentNode.left.GetCopy,VoidPointerType),nil)
          ));
      AddStatement(newstatement,
        CCallNode.CreateIntern(
          'fpc_dynarray_concat_multi',
          para
        )
      );
      include(AktAssignmentNode.AssignmentNodeFlags,anf_assign_done_in_right);
    end
  else
    begin
      tempnode:=CTempCreateNode.Create(p.resultdef,p.resultdef.Size,tt_persistent ,true);
      AddStatement(newstatement,tempnode);
      para:=CCallParaNode.Create(
              arrp,
            CCallParaNode.Create(
              CAddrNode.Create_Internal(CRTTINode.Create(TStoredDef(p.resultdef),initrtti,rdt_normal)),
            CCallParaNode.Create(
              CTypeConvNode.Create_Internal(CTempRefNode.Create(tempnode),VoidPointerType),nil)
          ));
      AddStatement(
        newstatement,
        CCallNode.CreateIntern(
          'fpc_dynarray_concat_multi',
          para
        )
      );
      AddStatement(newstatement,CTempDeleteNode.Create_Normal_Temp(tempnode));
      AddStatement(newstatement,CTempRefNode.Create(tempnode));
    end;
end;

begin
  CAddSStringCharOptNode := TAddSStringCharOptNode;
  CAddSStringCSStringOptNode := TAddSStringCSStringOptNode;
end.
