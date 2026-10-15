{
    Copyright (c) 2014 by Florian Klaempfl

    Symbol table overrides for <generic>

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
  tcpufiledefclass = class of tcpufiledef;

  tcpuvariantdef = class(TVariantDef)
  end;
  tcpuvariantdefclass = class of tcpuvariantdef;

  tcpuformaldef = class(TFormalDef)
  end;
  tcpuformaldefclass = class of tcpuformaldef;

  tcpuforwarddef = class(TForwardDef)
  end;
  tcpuforwarddefclass = class of tcpuforwarddef;

  tcpuundefineddef = class(TUndefinedDef)
  end;
  tcpuundefineddefclass = class of tcpuundefineddef;

  tcpuerrordef = class(TErrorDef)
  end;
  tcpuerrordefclass = class of tcpuerrordef;

  tcpupointerdef = class(TPointerDef)
  end;
  tcpupointerdefclass = class of tcpupointerdef;

  tcpurecorddef = class(TRecordDef)
  end;
  tcpurecorddefclass = class of tcpurecorddef;

  tcpuimplementedinterface = class(timplementedinterface)
  end;
  tcpuimplementedinterfaceclass = class of tcpuimplementedinterface;

  tcpuobjectdef = class(TObjectDef)
  end;
  tcpuobjectdefclass = class of tcpuobjectdef;

  tcpuclassrefdef = class(TClassRefDef)
  end;
  tcpuclassrefdefclass = class of tcpuclassrefdef;

  tcpuarraydef = class(TArrayDef)
  end;
  tcpuarraydefclass = class of tcpuarraydef;

  tcpuorddef = class(TOrdDef)
  end;
  tcpuorddefclass = class of tcpuorddef;

  tcpufloatdef = class(TFloatDef)
  end;
  tcpufloatdefclass = class of tcpufloatdef;

  tcpuprocvardef = class(TProcVarDef)
  end;
  tcpuprocvardefclass = class of tcpuprocvardef;

  tcpuprocdef = class(TProcDef)
  end;
  tcpuprocdefclass = class of tcpuprocdef;

  tcpustringdef = class(TStringDef)
  end;
  tcpustringdefclass = class of tcpustringdef;

  tcpuenumdef = class(TEnumDef)
  end;
  tcpuenumdefclass = class of tcpuenumdef;

  tcpusetdef = class(TSetDef)
  end;
  tcpusetdefclass = class of tcpusetdef;

  { syms }
  tcpulabelsym = class(TLabelSym)
  end;
  tcpulabelsymclass = class of tcpulabelsym;

  tcpuunitsym = class(TUnitSym)
  end;
  tcpuunitsymclass = class of tcpuunitsym;

  tcpuprogramparasym = class(TProgramParaSym)
  end;
  tcpuprogramparasymclass = class(TProgramParaSym);

  tcpunamespacesym = class(TNamespaceSym)
  end;
  tcpunamespacesymclass = class of tcpunamespacesym;

  tcpuprocsym = class(TProcSym)
  end;
  tcpuprocsymclass = class of tcpuprocsym;

  tcputypesym = class(TTypeSym)
  end;
  tcpuypesymclass = class of tcputypesym;

  tcpufieldvarsym = class(TFieldVarSym)
  end;
  tcpufieldvarsymclass = class of tcpufieldvarsym;

  tcpulocalvarsym = class(TLocalVarSym)
  end;
  tcpulocalvarsymclass = class of tcpulocalvarsym;

  tcpuparavarsym = class(TParaVarSym)
  end;
  tcpuparavarsymclass = class of tcpuparavarsym;

  tcpustaticvarsym = class(TStaticVarSym)
  end;
  tcpustaticvarsymclass = class of tcpustaticvarsym;

  tcpuabsolutevarsym = class(TAbsoluteVarSym)
  end;
  tcpuabsolutevarsymclass = class of tcpuabsolutevarsym;

  tcpupropertysym = class(TPropertySym)
  end;
  tcpupropertysymclass = class of tcpupropertysym;

  tcpuconstsym = class(TConstSym)
  end;
  tcpuconstsymclass = class of tcpuconstsym;

  tcpuenumsym = class(TEnumSym)
  end;
  tcpuenumsymclass = class of tcpuenumsym;

  tcpusyssym = class(TSysSym)
  end;
  tcpusyssymclass = class of tcpusyssym;


const
  pbestrealtype : ^TDef = @<somestandardfloattype>;


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

