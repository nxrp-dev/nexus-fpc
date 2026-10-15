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
  symtype,symdef,symsym;

type
  { defs }
  tcpufiledef = class(TFileDef)
  end;

  tcpuvariantdef = class(TVariantDef)
  end;

  tcpuformaldef = class(TFormalDef)
  end;

  tcpuforwarddef = class(TForwardDef)
  end;

  tcpuundefineddef = class(TUndefinedDef)
  end;

  tcpuerrordef = class(TErrorDef)
  end;

  tcpupointerdef = class(TPointerDef)
  end;

  tcpurecorddef = class(TRecordDef)
  end;

  tcpuimplementedinterface = class(timplementedinterface)
  end;

  tcpuobjectdef = class(TObjectDef)
  end;

  tcpuclassrefdef = class(TClassRefDef)
  end;

  tcpuarraydef = class(TArrayDef)
  end;

  tcpuorddef = class(TOrdDef)
  end;

  tcpufloatdef = class(TFloatDef)
  end;

  tcpuprocvardef = class(TProcVarDef)
  end;

  tcpuprocdef = class(TProcDef)
  end;

  tcpustringdef = class(TStringDef)
  end;

  tcpuenumdef = class(TEnumDef)
  end;

  tcpusetdef = class(TSetDef)
  end;

  { syms }
  tcpulabelsym = class(TLabelSym)
  end;

  tcpuunitsym = class(TUnitSym)
  end;

  tcpuprogramparasym = class(TProgramParaSym)
  end;

  tcpunamespacesym = class(TNamespaceSym)
  end;

  tcpuprocsym = class(TProcSym)
  end;

  tcputypesym = class(TTypeSym)
  end;

  tcpufieldvarsym = class(TFieldVarSym)
  end;

  tcpulocalvarsym = class(TLocalVarSym)
  end;

  tcpuparavarsym = class(TParaVarSym)
  end;

  tcpustaticvarsym = class(TStaticVarSym)
  end;

  tcpuabsolutevarsym = class(TAbsoluteVarSym)
  end;

  tcpupropertysym = class(TPropertySym)
  end;

  tcpuconstsym = class(TConstSym)
  end;

  tcpuenumsym = class(TEnumSym)
  end;

  tcpusyssym = class(TSysSym)
  end;


var
  pbestrealtype : ^TDef = @s64floattype;


implementation

begin
  { used tdef classes }
  cfiledef:=tcpufiledef;
  cvariantdef:=tcpuvariantdef;
  cformaldef:=tcpuformaldef;
  cforwarddef:=tcpuforwarddef;
  cundefineddef:=tcpuundefineddef;
  cerrordef:=tcpuerrordef;
  cpointerdef:=tcpupointerdef;
  crecorddef:=tcpurecorddef;
  cimplementedinterface:=tcpuimplementedinterface;
  cobjectdef:=tcpuobjectdef;
  cclassrefdef:=tcpuclassrefdef;
  carraydef:=tcpuarraydef;
  corddef:=tcpuorddef;
  cfloatdef:=tcpufloatdef;
  cprocvardef:=tcpuprocvardef;
  cprocdef:=tcpuprocdef;
  cstringdef:=tcpustringdef;
  cenumdef:=tcpuenumdef;
  csetdef:=tcpusetdef;

  { used tsym classes }
  clabelsym:=tcpulabelsym;
  cunitsym:=tcpuunitsym;
  cprogramparasym:=tcpuprogramparasym;
  cnamespacesym:=tcpunamespacesym;
  cprocsym:=tcpuprocsym;
  ctypesym:=tcputypesym;
  cfieldvarsym:=tcpufieldvarsym;
  clocalvarsym:=tcpulocalvarsym;
  cparavarsym:=tcpuparavarsym;
  cstaticvarsym:=tcpustaticvarsym;
  cabsolutevarsym:=tcpuabsolutevarsym;
  cpropertysym:=tcpupropertysym;
  cconstsym:=tcpuconstsym;
  cenumsym:=tcpuenumsym;
  csyssym:=tcpusyssym;
end.

