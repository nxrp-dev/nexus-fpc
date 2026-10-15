{
    Copyright (c) 2009 by Jonas Maebe

    This unit implements Objective-C nodes

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
{ @abstract(This unit implements Objective-C nodes)
  This unit contains various nodes to implement Objective-Pascal and to
  interface with the Objective-C runtime.
}

unit nobjc;

{$i fpcdefs.inc}

interface

uses
  node;

type
  TObjCSelectorNode = class(TUnaryNode)
   public
    constructor create(formethod: TNode);
    function pass_typecheck: TNode;override;
    function pass_1: TNode;override;
  end;
  TObjCSelectorNodeClass = class of TObjCSelectorNode;

  TObjCProtocolNode = class(TUnaryNode)
   public
    constructor create(forprotocol: TNode);
    function pass_typecheck: TNode;override;
    function pass_1: TNode;override;
  end;
  TObjCProtocolNodeClass = class of TObjCProtocolNode;

var
  CObjCSelectorNode : TObjCSelectorNodeClass;
  CObjCProtocolNode : TObjCProtocolNodeClass;

implementation

uses
  GlobType,Globals,
  Verbose,pass_1,
  symdef,symconst,
  ncon,ncal,
  objcutil,
  cgbase;


{*****************************************************************************
                            TOBJCSELECTORNODE
*****************************************************************************}

constructor TObjCSelectorNode.create(formethod: TNode);
  begin
    inherited create(objcselectorn,formethod);
  end;


function TObjCSelectorNode.pass_typecheck: TNode;
  var
    len: LongInt;
    s: shortstring;
  begin
    s:='';
    if not(m_objectivec1 in CurrentSettings.ModeSwitches) then
      Message(parser_f_modeswitch_objc_required);
    result:=nil;
    TypeCheckPass(left);
    { argument can be
       a) an objc method
       b) a pchar, zero-based chararray or ansistring
    }
    case left.nodetype of
      loadn:
        begin
          if (left.resultdef.typ=procdef) and
             (po_objc in TProcDef(left.resultdef).ProcOptions) then
            begin
              { ok }
            end
          else
            CGMessage1(type_e_expected_objc_method_but_got,left.resultdef.TypeName);
        end;
      stringconstn:
        begin
          if not objcvalidselectorname(TStringConstNode(left).asconstpchar,
                                       TStringConstNode(left).len) then
            begin
              len:=TStringConstNode(left).len;
              if (len>255) then
                len:=255;
              SetLength(s,len);
              if len>0 then
                move(TStringConstNode(left).valueas[0],s[1],len);
              CGMessage1(type_e_invalid_objc_selector_name,s);
              exit;
            end;
        end
      else
        CGMessage(type_e_expected_objc_method);
    end;
    resultdef:=ObjC_SelType;
  end;


function TObjCSelectorNode.pass_1: TNode;
  begin
    result:=nil;
    expectloc:=LOC_CREFERENCE;
  end;


{*****************************************************************************
                            TOBJPROTOCOLNODE
*****************************************************************************}

constructor TObjCProtocolNode.create(forprotocol: TNode);
  begin
    inherited create(objcprotocoln,forprotocol);
  end;


function TObjCProtocolNode.pass_typecheck: TNode;
  begin
    if not(m_objectivec1 in CurrentSettings.ModeSwitches) then
      Message(parser_f_modeswitch_objc_required);
    result:=nil;
    TypeCheckPass(left);
    if (left.nodetype<>typen) then
      MessagePos(left.fileinfo,type_e_type_id_expected)
    else if not Is_ObjCProtocol(left.resultdef) then
      MessagePos2(left.fileinfo,type_e_incompatible_types,left.resultdef.TypeName,'ObjCProtocol');
    resultdef:=ObjC_ProtocolType;
  end;


function TObjCProtocolNode.pass_1: TNode;
  begin
    result:=CCallNode.createinternresfromunit('OBJC','OBJC_GETPROTOCOL',
      CCallParaNode.create(CStringConstNode.createstr(TObjectDef(left.resultdef).ObjExtName^),nil),
      resultdef
    );
    TypeCheckPass(result);
  end;


end.

