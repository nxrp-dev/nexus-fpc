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
    constructor Create(AForMethod: TNode);
    function Pass_TypeCheck: TNode;override;
    function Pass_1: TNode;override;
  end;
  TObjCSelectorNodeClass = class of TObjCSelectorNode;

  TObjCProtocolNode = class(TUnaryNode)
   public
    constructor Create(AForProtocol: TNode);
    function Pass_TypeCheck: TNode;override;
    function Pass_1: TNode;override;
  end;
  TObjCProtocolNodeClass = class of TObjCProtocolNode;

var
  CObjCSelectorNode : TObjCSelectorNodeClass;
  CObjCProtocolNode : TObjCProtocolNodeClass;

implementation

uses
  GlobType,Globals,
  Verbose,Pass_1,
  symdef,symconst,
  ncon,ncal,
  objcutil,
  cgbase;


{*****************************************************************************
                            TOBJCSELECTORNODE
*****************************************************************************}

constructor TObjCSelectorNode.Create(AForMethod: TNode);
  begin
    inherited Create(objcselectorn,AForMethod);
  end;


function TObjCSelectorNode.Pass_TypeCheck: TNode;
  var
    lLength: LongInt;
    lString: ShortString;
  begin
    lString:='';
    if not(m_objectivec1 in CurrentSettings.ModeSwitches) then
      Message(parser_f_modeswitch_objc_required);
    Result:=nil;
    TypeCheckPass(Left);
    { argument can be
       a) an objc method
       b) a pchar, zero-based chararray or ansistring
    }
    case Left.NodeType of
      loadn:
        begin
          if (Left.ResultDef.typ=procdef) and
             (po_objc in TProcDef(Left.ResultDef).ProcOptions) then
            begin
              { ok }
            end
          else
            CGMessage1(type_e_expected_objc_method_but_got,Left.ResultDef.TypeName);
        end;
      stringconstn:
        begin
          if not ObjCValidSelectorName(TStringConstNode(Left).AsConstPChar,
                                       TStringConstNode(Left).len) then
            begin
              lLength:=TStringConstNode(Left).len;
              if (lLength>255) then
                lLength:=255;
              SetLength(lString,lLength);
              if lLength>0 then
                move(TStringConstNode(Left).ValueAS[0],lString[1],lLength);
              CGMessage1(type_e_invalid_objc_selector_name,lString);
              exit;
            end;
        end
      else
        CGMessage(type_e_expected_objc_method);
    end;
    ResultDef:=ObjC_SelType;
  end;


function TObjCSelectorNode.Pass_1: TNode;
  begin
    Result:=nil;
    ExpectLoc:=LOC_CREFERENCE;
  end;


{*****************************************************************************
                            TOBJPROTOCOLNODE
*****************************************************************************}

constructor TObjCProtocolNode.Create(AForProtocol: TNode);
  begin
    inherited Create(objcprotocoln,AForProtocol);
  end;


function TObjCProtocolNode.Pass_TypeCheck: TNode;
  begin
    if not(m_objectivec1 in CurrentSettings.ModeSwitches) then
      Message(parser_f_modeswitch_objc_required);
    Result:=nil;
    TypeCheckPass(Left);
    if (Left.NodeType<>typen) then
      MessagePos(Left.FileInfo,type_e_type_id_expected)
    else if not Is_ObjCProtocol(Left.ResultDef) then
      MessagePos2(Left.FileInfo,type_e_incompatible_types,Left.ResultDef.TypeName,'ObjCProtocol');
    ResultDef:=ObjC_ProtocolType;
  end;


function TObjCProtocolNode.Pass_1: TNode;
  begin
    Result:=CCallNode.CreateInternResFromUnit('OBJC','OBJC_GETPROTOCOL',
      CCallParaNode.Create(CStringConstNode.CreateStr(TObjectDef(Left.ResultDef).ObjExtName^),nil),
      ResultDef
    );
    TypeCheckPass(Result);
  end;


end.

