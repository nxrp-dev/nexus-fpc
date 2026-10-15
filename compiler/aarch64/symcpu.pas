{
    Copyright (c) 2014 by Florian Klaempfl

    Symbol table overrides for AARCH64

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
unit symcpu;

{$i fpcdefs.inc}

interface

uses
  symtype,symdef,SymSym;

type
  { defs }
  TCPUFileDef = class(TFileDef)
  end;

  TCPUVariantDef = class(TVariantDef)
  end;

  TCPUFormalDef = class(TFormalDef)
  end;

  TCPUForwardDef = class(TForwardDef)
  end;

  TCPUUndefinedDef = class(TUndefinedDef)
  end;

  TCPUErrorDef = class(TErrorDef)
  end;

  TCPUPointerDef = class(TPointerDef)
  end;

  TCPURecordDef = class(TRecordDef)
  end;

  TCPUImplementedInterface = class(TImplementedInterface)
  end;

  TCPUObjectDef = class(TObjectDef)
  end;

  TCPUClassRefDef = class(TClassRefDef)
  end;

  TCPUArrayDef = class(TArrayDef)
  end;

  TCPUOrdDef = class(TOrdDef)
  end;

  TCPUFloatDef = class(TFloatDef)
  end;

  TCPUProcVarDef = class(TProcVarDef)
  end;

  TCPUProcDef = class(TProcDef)
  end;

  TCPUStringDef = class(TStringDef)
  end;

  TCPUEnumDef = class(TEnumDef)
  end;

  TCPUSetDef = class(TSetDef)
  end;

  { syms }
  TCPULabelSym = class(TLabelSym)
  end;

  TCPUUnitSym = class(TUnitSym)
  end;

  TCPUProgramParaSym = class(TProgramParaSym)
  end;

  TCPUNamespaceSym = class(TNamespaceSym)
  end;

  TCPUProcSym = class(TProcSym)
  end;

  TCPUTypeSym = class(TTypeSym)
  end;

  TCPUFieldVarSym = class(TFieldVarSym)
  end;

  TCPULocalVarSym = class(TLocalVarSym)
  end;

  TCPUParaVarSym = class(TParaVarSym)
  end;

  TCPUStaticVarSym = class(TStaticVarSym)
  end;

  TCPUAbsoluteVarSym = class(TAbsoluteVarSym)
  end;

  TCPUPropertySym = class(TPropertySym)
  end;

  TCPUConstSym = class(TConstSym)
  end;

  TCPUEnumSym = class(TEnumSym)
  end;

  TCPUSysSym = class(TSysSym)
  end;


var
  pbestrealtype : ^TDef = @S64FloatType;


implementation

begin
  { used tdef classes }
  CFileDef:=TCPUFileDef;
  CVariantDef:=TCPUVariantDef;
  CFormalDef:=TCPUFormalDef;
  CForwardDef:=TCPUForwardDef;
  CUndefinedDef:=TCPUUndefinedDef;
  CErrorDef:=TCPUErrorDef;
  CPointerDef:=TCPUPointerDef;
  CRecordDef:=TCPURecordDef;
  CImplementedInterface:=TCPUImplementedInterface;
  CObjectDef:=TCPUObjectDef;
  CClassRefDef:=TCPUClassRefDef;
  CArrayDef:=TCPUArrayDef;
  COrdDef:=TCPUOrdDef;
  CFloatDef:=TCPUFloatDef;
  CProcVarDef:=TCPUProcVarDef;
  CProcDef:=TCPUProcDef;
  CStringDef:=TCPUStringDef;
  CEnumDef:=TCPUEnumDef;
  CSetDef:=TCPUSetDef;

  { used tsym classes }
  CLabelSym:=TCPULabelSym;
  CUnitSym:=TCPUUnitSym;
  CProgramParaSym:=TCPUProgramParaSym;
  CNamespaceSym:=TCPUNamespaceSym;
  CProcSym:=TCPUProcSym;
  CTypeSym:=TCPUTypeSym;
  CFieldVarSym:=TCPUFieldVarSym;
  CLocalVarSym:=TCPULocalVarSym;
  CParaVarSym:=TCPUParaVarSym;
  CStaticVarSym:=TCPUStaticVarSym;
  CAbsoluteVarSym:=TCPUAbsoluteVarSym;
  CPropertySym:=TCPUPropertySym;
  CConstSym:=TCPUConstSym;
  CEnumSym:=TCPUEnumSym;
  CSysSym:=TCPUSysSym;
end.

