{
    Copyright (c) 2014 by Florian Klaempfl

    Symbol table overrides for i386

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
  symconst,symtype,symdef,SymSym,symx86,symi86;

type
  { defs }
  TCPUFileDef = class(TFileDef)
  end;
  TCPUFileDefClass = class of TCPUFileDef;

  TCPUVariantDef = class(TVariantDef)
  end;
  TCPUVariantDefClass = class of TCPUVariantDef;

  TCPUFormalDef = class(TFormalDef)
  end;
  TCPUFormalDefClass = class of TCPUFormalDef;

  TCPUForwardDef = class(TForwardDef)
  end;
  TCPUForwardDefClass = class of TCPUForwardDef;

  TCPUUndefinedDef = class(TUndefinedDef)
  end;
  TCPUUndefinedDefClass = class of TCPUUndefinedDef;

  TCPUErrorDef = class(TErrorDef)
  end;
  TCPUErrorDefClass = class of TCPUErrorDef;

  TCPUPointerDef = class(TX86PointerDef)
  end;
  TCPUPointerDefClass = class of TCPUPointerDef;

  TCPURecordDef = class(TRecordDef)
  end;
  TCPURecordDefClass = class of TCPURecordDef;

  TCPUImplementedInterface = class(TImplementedInterface)
  end;
  TCPUImplementedInterfaceClass = class of TCPUImplementedInterface;

  TCPUObjectDef = class(TObjectDef)
  end;
  TCPUObjectDefClass = class of TCPUObjectDef;

  TCPUClassRefDef = class(TClassRefDef)
  end;
  TCPUClassRefDefClass = class of TCPUClassRefDef;

  TCPUArrayDef = class(TArrayDef)
  end;
  TCPUArrayDefClass = class of TCPUArrayDef;

  TCPUOrdDef = class(TOrdDef)
  end;
  TCPUOrdDefClass = class of TCPUOrdDef;

  TCPUFloatDef = class(TFloatDef)
  end;
  TCPUFloatDefClass = class of TCPUFloatDef;

  TCPUProcVarDef = class(TI86ProcVarDef)
  end;
  TCPUProcVarDefClass = class of TCPUProcVarDef;

  TCPUProcDef = class(TI86ProcDef)
    procedure PPULoadPlatform(ppufile: TCompilerPPUFile); override;
    procedure PPUWritePlatform(ppufile: TCompilerPPUFile); override;
   public
    { library symbol for AROS }
    libsym : TSym;
    libsymderef : TDeref;
    function GetCopyAs(newtyp: TDefTyp; copytyp: TProcCopyTyp; const paraprefix: string;doregister:boolean): TStoredDef; override;
    procedure BuildDeref; override;
    procedure deref; override;
  end;
  TCPUProcDefClass = class of TCPUProcDef;

  TCPUStringDef = class(TStringDef)
  end;
  TCPUStringDefClass = class of TCPUStringDef;

  TCPUEnumDef = class(TEnumDef)
  end;
  TCPUEnumDefClass = class of TCPUEnumDef;

  TCPUSetDef = class(TSetDef)
  end;
  TCPUSetDefClass = class of TCPUSetDef;

  { syms }
  TCPULabelSym = class(TLabelSym)
  end;
  TCPULabelSymClass = class of TCPULabelSym;

  TCPUUnitSym = class(TUnitSym)
  end;
  TCPUUnitSymClass = class of TCPUUnitSym;

  TCPUProgramParaSym = class(TProgramParaSym)
  end;
  TCPUProgramParaSymClass = class(TProgramParaSym);

  TCPUNamespaceSym = class(TNamespaceSym)
  end;
  TCPUNamespaceSymClass = class of TCPUNamespaceSym;

  TCPUProcSym = class(TProcSym)
  end;
  TCPUProcSymClass = class of TCPUProcSym;

  TCPUTypeSym = class(TTypeSym)
  end;
  TCPUTypeSymClass = class of TCPUTypeSym;

  TCPUFieldVarSym = class(TFieldVarSym)
  end;
  TCPUFieldVarSymClass = class of TCPUFieldVarSym;

  TCPULocalVarSym = class(TLocalVarSym)
  end;
  TCPULocalVarSymClass = class of TCPULocalVarSym;

  TCPUParaVarSym = class(TParaVarSym)
  end;
  TCPUParaVarSymClass = class of TCPUParaVarSym;

  TCPUStaticVarSym = class(TStaticVarSym)
  end;
  TCPUStaticVarSymClass = class of TCPUStaticVarSym;

  TCPUAbsoluteVarSym = class(TI86AbsoluteVarSym)
  end;
  TCPUAbsoluteVarSymClass = class of TCPUAbsoluteVarSym;

  TCPUPropertySym = class(TPropertySym)
  end;
  TCPUPropertySymClass = class of TCPUPropertySym;

  TCPUConstSym = class(TConstSym)
  end;
  TCPUConstSymClass = class of TCPUConstSym;

  TCPUEnumSym = class(TEnumSym)
  end;
  TCPUEnumSymClass = class of TCPUEnumSym;

  TCPUSysSym = class(TSysSym)
  end;
  TCPUSysSymClass = class of TCPUSysSym;


var
  pbestrealtype : ^TDef = @S80FloatType;


implementation

{****************************************************************************
                             tcpuprocdef
****************************************************************************}

  procedure TCPUProcDef.PPULoadPlatform(ppufile: TCompilerPPUFile);
    begin
      inherited;
      if po_syscall_has_libsym in ProcOptions then
        ppufile.GetDeref(libsymderef);
    end;


  procedure TCPUProcDef.PPUWritePlatform(ppufile: TCompilerPPUFile);
    begin
      inherited;
      if po_syscall_has_libsym in ProcOptions then
        ppufile.PutDeref(libsymderef);
    end;


  function TCPUProcDef.GetCopyAs(newtyp: TDefTyp; copytyp: TProcCopyTyp; const paraprefix: string;doregister:boolean): TStoredDef;
    begin
      result:=inherited;
      if newtyp=procdef then
        TCPUProcDef(result).libsym:=libsym;
    end;


  procedure TCPUProcDef.BuildDeref;
    begin
      inherited;
      if po_syscall_has_libsym in ProcOptions then
        libsymderef.build(libsym);
    end;


  procedure TCPUProcDef.deref;
    begin
      inherited;
      if po_syscall_has_libsym in ProcOptions then
        libsym:=TSym(libsymderef.resolve)
      else
        libsym:=nil;
    end;


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

