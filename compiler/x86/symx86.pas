{
    Copyright (c) 2014 by Florian Klaempfl

    Symbol table overrides for x86

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
unit symx86;

{$i fpcdefs.inc}

interface

uses
  globtype, cclasses,
  symconst, symtype,symdef,symsym;

type
  tx86pointerdef = class(TPointerDef)
   protected
    procedure PPULoadPlatform(ppufile: TCompilerPPUFile); override;
    procedure PPUWritePlatform(ppufile: TCompilerPPUFile); override;
   public
    x86pointertyp : TX86PointerTyp;
    constructor create(def: TDef); override;
    class function getreusable(def: TDef): TPointerDef; override;
    class function getreusablex86(def: TDef; x86typ: TX86PointerTyp): TPointerDef;
    constructor createx86(def:TDef;x86typ:TX86PointerTyp);virtual;
    function size: asizeint; override;
    function getcopy: TStoredDef; override;
    function GetTypeName: string; override;
    class function default_x86_data_pointer_type: TX86PointerTyp; virtual;
    function compatible_with_pointerdef_size(ptr: TPointerDef): boolean; override;
  end;
  tx86pointerdefclass = class of tx86pointerdef;

  tx86procvardef = class(TProcVarDef)
    function compatible_with_pointerdef_size(ptr: TPointerDef): boolean; override;
  end;
  tx86procvardefclass = class of tx86procvardef;

  tx86procdef = class(TProcDef)
    function compatible_with_pointerdef_size(ptr: TPointerDef): boolean; override;
  end;
  tx86procdefclass = class of tx86procdef;


implementation

  uses
    globals, verbose,
    symbase, fmodule;


{****************************************************************************
                             tx86pointerdef
****************************************************************************}

  procedure tx86pointerdef.PPULoadPlatform(ppufile: TCompilerPPUFile);
    begin
      inherited;
      x86pointertyp:=TX86PointerTyp(ppufile.getbyte);
    end;


  procedure tx86pointerdef.PPUWritePlatform(ppufile: TCompilerPPUFile);
    begin
      inherited;
      ppufile.putbyte(byte(x86pointertyp));
    end;


  constructor tx86pointerdef.create(def: TDef);
    begin
      inherited create(def);
      x86pointertyp := default_x86_data_pointer_type;
    end;


  class function tx86pointerdef.getreusable(def: TDef): TPointerDef;
    begin
      result:=getreusablex86(def,default_x86_data_pointer_type);
    end;


  class function tx86pointerdef.getreusablex86(def: TDef; x86typ: TX86PointerTyp): TPointerDef;
    type
      tx86PtrDefKey = packed record
        def: TDef;
        x86typ:TX86PointerTyp;
      end;
    var
      res: PHashSetItem;
      oldsymtablestack: TSymTableStack;
      key: tx86PtrDefKey;
    begin
      if not assigned(CurrentModule) then
        internalerror(2011071102);
      key.def:=def;
      key.x86typ:=x86typ;
      res:=CurrentModule.ptrdefs.FindOrAdd(@key,sizeof(key));
      if not assigned(res^.Data) then
        begin
          { since these pointerdefs can be reused anywhere in the current
            unit, add them to the global/staticsymtable (or local symtable
            if they're a local def, because otherwise they'll be saved
            to the ppu referencing a local symtable entry that doesn't
            exist in the ppu) }
          oldsymtablestack:=symtablestack;
          { do not simply push/pop current_module.localsymtable, because
            that can have side-effects (e.g., it removes helpers) }
          symtablestack:=nil;
          result:=tx86pointerdefclass(cpointerdef).createx86(def,x86typ);
          SetupReusableDef(def,result,res,oldsymtablestack);
          { res^.Data may still be nil -> don't overwrite result }
          exit;
        end;
      result:=TPointerDef(res^.Data);
    end;


  constructor tx86pointerdef.createx86(def: TDef; x86typ: TX86PointerTyp);
    begin
      inherited create(def);
      x86pointertyp:=x86typ;
    end;


  function tx86pointerdef.size: asizeint;
    begin
      if x86pointertyp in [x86pt_far,x86pt_huge] then
        result:=sizeof(pint)+2
      else
        result:=inherited;
    end;


  function tx86pointerdef.getcopy: TStoredDef;
    begin
      result:=inherited;
      tx86pointerdef(result).x86pointertyp:=x86pointertyp;
    end;


  function tx86pointerdef.GetTypeName: string;
    begin
      result:=inherited;
      if x86pointertyp<>default_x86_data_pointer_type then
        begin
          case x86pointertyp of
            x86pt_near:
              result:=result+';near';
            x86pt_near_cs:
              result:=result+';near ''CS''';
            x86pt_near_ds:
              result:=result+';near ''DS''';
            x86pt_near_ss:
              result:=result+';near ''SS''';
            x86pt_near_es:
              result:=result+';near ''ES''';
            x86pt_near_fs:
              result:=result+';near ''FS''';
            x86pt_near_gs:
              result:=result+';near ''GS''';
            x86pt_far:
              result:=result+';far';
            x86pt_huge:
              result:=result+';huge';
          end;
        end;
    end;


  class function tx86pointerdef.default_x86_data_pointer_type: TX86PointerTyp;
    begin
      result:=x86pt_near;
    end;


  function tx86pointerdef.compatible_with_pointerdef_size(ptr: TPointerDef): boolean;
    begin
      result:=
        inherited and
        (x86pointertyp=tx86pointerdef(ptr).x86pointertyp);
    end;


{****************************************************************************
                           tx86procvardef
****************************************************************************}


  function tx86procvardef.compatible_with_pointerdef_size(ptr: TPointerDef): boolean;
    begin
      result:=
        inherited and
        (tx86pointerdef(address_type).x86pointertyp=tx86pointerdef(ptr).x86pointertyp);
    end;


  {****************************************************************************
                             tx86procdef
  ****************************************************************************}


    function tx86procdef.compatible_with_pointerdef_size(ptr: TPointerDef): boolean;
      begin
        result:=
          inherited and
          (tx86pointerdef(address_type).x86pointertyp=tx86pointerdef(ptr).x86pointertyp);
      end;


end.

