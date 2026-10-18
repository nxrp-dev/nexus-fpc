{
    Copyright (c) 2009 by Jonas Maebe

    This unit implements code generator support for Objective-C nodes

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

unit ncgobjc;

{$i fpcdefs.inc}

interface

uses
  nobjc;

type
  TCGObjCSelectorNode = class(TObjCSelectorNode)
    procedure Pass_Generate_Code; override;
  end;

  TCGObjCProtocolNode = class(TObjCProtocolNode)
    procedure Pass_Generate_Code; override;
  end;

implementation

uses
    GlobType,CClasses,
    aasmbase,AAsmData,
    cgbase,cgutils,defutil,objcgutl,
    symconst,SymSym,symdef,
    node,nld,ncon,
    Verbose;

{*****************************************************************************
                           TCGOBJCSELECTORNODE
*****************************************************************************}

procedure TCGObjCSelectorNode.Pass_Generate_Code;
  var
    lPool   : THashSet;
    lEntry  : PHashSetItem;
    lName   : PShortString;
  begin
    lPool:=CurrentAsmData.ConstPools[sp_varnamerefs];

    case Left.NodeType of
      loadn:
        begin
          if (TLoadNode(Left).SymTableEntry.typ<>ProcSym) then
            InternalError(2009051602);
          if (TProcSym(TLoadNode(Left).SymTableEntry).procdeflist.count<>1) then
            InternalError(2009051701);
          lName:=TProcDef(TProcSym(TLoadNode(Left).SymTableEntry).procdeflist[0]).MessageInf.str;
          lEntry:=lPool.FindOrAdd(@lName^[1],length(lName^))
        end;
      stringconstn:
        begin
          lEntry:=lPool.FindOrAdd(Pointer(TStringConstNode(Left).ValueAS),TStringConstNode(Left).len);
        end;
      else
        InternalError(2009030701);
    end;

    ObjCFinishStringRefPoolEntry(lEntry,sp_objcvarnames,sec_objc_message_refs,sec_objc_meth_var_names);

    Location_Reset_Ref(Location,LOC_CREFERENCE,Def_CGSize(ResultDef),sizeof(PInt),[]);
    Location.Reference.Symbol:=TAsmLabel(lEntry^.Data);
  end;


{*****************************************************************************
                           TCGOBJCPROTOCOLNODE
*****************************************************************************}

procedure TCGObjCProtocolNode.Pass_Generate_Code;
  begin
    { first needs support for writing class definitions }
    InternalError(2009072601);
  end;


begin
  CObjCSelectorNode:=TCGObjCSelectorNode;
  CObjCProtocolNode:=TCGObjCProtocolNode;
end.
