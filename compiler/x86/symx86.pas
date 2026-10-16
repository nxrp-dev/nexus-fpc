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
  SymConst, SymType,SymDef,SymSym;

type
  TX86PointerDef = class(TPointerDef)
   protected
    procedure PPULoadPlatform(PPUFile: TCompilerPPUFile); override;
    procedure PPUWritePlatform(PPUFile: TCompilerPPUFile); override;
   public
    X86PointerTyp : TX86PointerTyp;
    constructor Create(Def: TDef); override;
    class function GetReusable(Def: TDef): TPointerDef; override;
    class function GetReusableX86(Def: TDef; X86Typ: TX86PointerTyp): TPointerDef;
    constructor CreateX86(Def:TDef;X86Typ:TX86PointerTyp);virtual;
    function Size: ASizeInt; override;
    function GetCopy: TStoredDef; override;
    function GetTypeName: string; override;
    class function Default_X86_Data_Pointer_Type: TX86PointerTyp; virtual;
    function Compatible_With_PointerDef_Size(Ptr: TPointerDef): Boolean; override;
  end;
  TX86PointerDefClass = class of TX86PointerDef;

  TX86ProcVarDef = class(TProcVarDef)
    function Compatible_With_PointerDef_Size(Ptr: TPointerDef): Boolean; override;
  end;
  TX86ProcVarDefClass = class of TX86ProcVarDef;

  TX86ProcDef = class(TProcDef)
    function Compatible_With_PointerDef_Size(Ptr: TPointerDef): Boolean; override;
  end;
  TX86ProcDefClass = class of TX86ProcDef;


implementation

  uses
    Globals, Verbose,
    SymBase, FModule;


{****************************************************************************
                             tx86pointerdef
****************************************************************************}

  procedure TX86PointerDef.PPULoadPlatform(PPUFile: TCompilerPPUFile);
    begin
      inherited;
      X86PointerTyp:=TX86PointerTyp(PPUFile.GetByte);
    end;


  procedure TX86PointerDef.PPUWritePlatform(PPUFile: TCompilerPPUFile);
    begin
      inherited;
      PPUFile.PutByte(Byte(X86PointerTyp));
    end;


  constructor TX86PointerDef.Create(Def: TDef);
    begin
      inherited Create(Def);
      X86PointerTyp := Default_X86_Data_Pointer_Type;
    end;


  class function TX86PointerDef.GetReusable(Def: TDef): TPointerDef;
    begin
      Result:=GetReusableX86(Def,Default_X86_Data_Pointer_Type);
    end;


  class function TX86PointerDef.GetReusableX86(Def: TDef; X86Typ: TX86PointerTyp): TPointerDef;
    type
      TX86PtrDefKey = packed record
        Def: TDef;
        X86Typ:TX86PointerTyp;
      end;
    var
      Res: PHashSetItem;
      OldSymTableStack: TSymTableStack;
      Key: TX86PtrDefKey;
    begin
      if not Assigned(CurrentModule) then
        InternalError(2011071102);
      Key.Def:=Def;
      Key.X86Typ:=X86Typ;
      Res:=CurrentModule.PtrDefs.FindOrAdd(@Key,SizeOf(Key));
      if not Assigned(Res^.Data) then
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
          Result:=TX86PointerDefClass(CPointerDef).CreateX86(Def,X86Typ);
          SetupReusableDef(Def,Result,Res,OldSymTableStack);
          { res^.Data may still be nil -> don't overwrite result }
          Exit;
        end;
      Result:=TPointerDef(Res^.Data);
    end;


  constructor TX86PointerDef.CreateX86(Def: TDef; X86Typ: TX86PointerTyp);
    begin
      inherited Create(Def);
      X86PointerTyp:=X86Typ;
    end;


  function TX86PointerDef.Size: ASizeInt;
    begin
      if X86PointerTyp in [x86pt_far,x86pt_huge] then
        Result:=SizeOf(PInt)+2
      else
        Result:=inherited;
    end;


  function TX86PointerDef.GetCopy: TStoredDef;
    begin
      Result:=inherited;
      TX86PointerDef(Result).X86PointerTyp:=X86PointerTyp;
    end;


  function TX86PointerDef.GetTypeName: string;
    begin
      Result:=inherited;
      if X86PointerTyp<>Default_X86_Data_Pointer_Type then
        begin
          case X86PointerTyp of
            x86pt_near:
              Result:=Result+';near';
            x86pt_near_cs:
              Result:=Result+';near ''CS''';
            x86pt_near_ds:
              Result:=Result+';near ''DS''';
            x86pt_near_ss:
              Result:=Result+';near ''SS''';
            x86pt_near_es:
              Result:=Result+';near ''ES''';
            x86pt_near_fs:
              Result:=Result+';near ''FS''';
            x86pt_near_gs:
              Result:=Result+';near ''GS''';
            x86pt_far:
              Result:=Result+';far';
            x86pt_huge:
              Result:=Result+';huge';
          end;
        end;
    end;


  class function TX86PointerDef.Default_X86_Data_Pointer_Type: TX86PointerTyp;
    begin
      Result:=x86pt_near;
    end;


  function TX86PointerDef.Compatible_With_PointerDef_Size(Ptr: TPointerDef): Boolean;
    begin
      Result:=
        inherited and
        (X86PointerTyp=TX86PointerDef(Ptr).X86PointerTyp);
    end;


{****************************************************************************
                           tx86procvardef
****************************************************************************}


  function TX86ProcVarDef.Compatible_With_PointerDef_Size(Ptr: TPointerDef): Boolean;
    begin
      Result:=
        inherited and
        (TX86PointerDef(Address_Type).X86PointerTyp=TX86PointerDef(Ptr).X86PointerTyp);
    end;


  {****************************************************************************
                             tx86procdef
  ****************************************************************************}


    function TX86ProcDef.Compatible_With_PointerDef_Size(Ptr: TPointerDef): Boolean;
      begin
        Result:=
          inherited and
          (TX86PointerDef(Address_Type).X86PointerTyp=TX86PointerDef(Ptr).X86PointerTyp);
      end;


end.

