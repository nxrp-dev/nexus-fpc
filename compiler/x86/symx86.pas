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
  GlobType, CClasses,
  symconst, symtype,symdef,SymSym;

type
  TX86PointerDef = class(TPointerDef)
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
  TX86PointerDefClass = class of TX86PointerDef;

  TX86ProcVarDef = class(TProcVarDef)
    function compatible_with_pointerdef_size(ptr: TPointerDef): boolean; override;
  end;
  TX86ProcVarDefClass = class of TX86ProcVarDef;

  TX86ProcDef = class(TProcDef)
    function compatible_with_pointerdef_size(ptr: TPointerDef): boolean; override;
  end;
  TX86ProcDefClass = class of TX86ProcDef;


implementation

  uses
    Globals, Verbose,
    SymBase, FModule;


{****************************************************************************
                             tx86pointerdef
****************************************************************************}

  procedure TX86PointerDef.PPULoadPlatform(ppufile: TCompilerPPUFile);
    begin
      inherited;
      x86pointertyp:=TX86PointerTyp(ppufile.GetByte);
    end;


  procedure TX86PointerDef.PPUWritePlatform(ppufile: TCompilerPPUFile);
    begin
      inherited;
      ppufile.PutByte(byte(x86pointertyp));
    end;


  constructor TX86PointerDef.create(def: TDef);
    begin
      inherited create(def);
      x86pointertyp := default_x86_data_pointer_type;
    end;


  class function TX86PointerDef.getreusable(def: TDef): TPointerDef;
    begin
      result:=getreusablex86(def,default_x86_data_pointer_type);
    end;


  class function TX86PointerDef.getreusablex86(def: TDef; x86typ: TX86PointerTyp): TPointerDef;
    type
      tx86PtrDefKey = packed record
        def: TDef;
        x86typ:TX86PointerTyp;
      end;
    var
      res: PHashSetItem;
      OldSymTableStack: TSymTableStack;
      key: tx86PtrDefKey;
    begin
      if not Assigned(CurrentModule) then
        InternalError(2011071102);
      key.def:=def;
      key.x86typ:=x86typ;
      res:=CurrentModule.ptrdefs.FindOrAdd(@key,sizeof(key));
      if not Assigned(res^.Data) then
        begin
          { since these pointerdefs can be reused anywhere in the current
            unit, add them to the global/staticsymtable (or local symtable
            if they're a local def, because otherwise they'll be saved
            to the ppu referencing a local symtable entry that doesn't
            exist in the ppu) }
          OldSymTableStack:=SymTableStack;
          { do not simply push/pop current_module.localsymtable, because
            that can have side-effects (e.g., it removes helpers) }
          SymTableStack:=nil;
          result:=TX86PointerDefClass(CPointerDef).createx86(def,x86typ);
          SetupReusableDef(def,result,res,OldSymTableStack);
          { res^.Data may still be nil -> don't overwrite result }
          exit;
        end;
      result:=TPointerDef(res^.Data);
    end;


  constructor TX86PointerDef.createx86(def: TDef; x86typ: TX86PointerTyp);
    begin
      inherited create(def);
      x86pointertyp:=x86typ;
    end;


  function TX86PointerDef.size: asizeint;
    begin
      if x86pointertyp in [x86pt_far,x86pt_huge] then
        result:=sizeof(PInt)+2
      else
        result:=inherited;
    end;


  function TX86PointerDef.getcopy: TStoredDef;
    begin
      result:=inherited;
      TX86PointerDef(result).x86pointertyp:=x86pointertyp;
    end;


  function TX86PointerDef.GetTypeName: string;
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


  class function TX86PointerDef.default_x86_data_pointer_type: TX86PointerTyp;
    begin
      result:=x86pt_near;
    end;


  function TX86PointerDef.compatible_with_pointerdef_size(ptr: TPointerDef): boolean;
    begin
      result:=
        inherited and
        (x86pointertyp=TX86PointerDef(ptr).x86pointertyp);
    end;


{****************************************************************************
                           tx86procvardef
****************************************************************************}


  function TX86ProcVarDef.compatible_with_pointerdef_size(ptr: TPointerDef): boolean;
    begin
      result:=
        inherited and
        (TX86PointerDef(address_type).x86pointertyp=TX86PointerDef(ptr).x86pointertyp);
    end;


  {****************************************************************************
                             tx86procdef
  ****************************************************************************}


    function TX86ProcDef.compatible_with_pointerdef_size(ptr: TPointerDef): boolean;
      begin
        result:=
          inherited and
          (TX86PointerDef(address_type).x86pointertyp=TX86PointerDef(ptr).x86pointertyp);
      end;


end.

