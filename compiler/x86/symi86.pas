{
    Copyright (c) 2014 by Florian Klaempfl

    Symbol table overrides for i386 and i8086

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
unit symi86;

{$i fpcdefs.inc}

interface

uses
  SymType,SymDef,SymSym,SymX86;

type

  { ti86procvardef }

  TI86ProcVarDef = class(TX86ProcVarDef)
    function Is_PushLeftRight: Boolean; override;
  end;

  { ti86procdef }

  TI86ProcDef = class(TX86ProcDef)
    function Is_PushLeftRight: Boolean; override;
  end;

  { ti86absolutevarsym }

  TI86AbsoluteVarSym = class(TAbsoluteVarSym)
   protected
    procedure PPULoadPlatform(PPUFile: TCompilerPPUFile); override;
    procedure PPUWritePlatform(PPUFile: TCompilerPPUFile); override;
   public
    AbsSeg  : Boolean;
  end;

implementation

uses
  SymConst;

{ ti86procvardef }

function TI86ProcVarDef.Is_PushLeftRight: Boolean;
  begin
    Result:=ProcCallOption in PushLeftRight_PoCalls;
  end;

{ ti86procdef }

function TI86ProcDef.Is_PushLeftRight: Boolean;
  begin
    Result:=ProcCallOption in PushLeftRight_PoCalls;
  end;

{ ti86absolutevarsym }

procedure TI86AbsoluteVarSym.PPULoadPlatform(PPUFile: TCompilerPPUFile);
  begin
    inherited;
    if AbsTyp=ToAddr then
      AbsSeg:=PPUFile.GetBoolean
    else
      AbsSeg:=False;
  end;


procedure TI86AbsoluteVarSym.PPUWritePlatform(PPUFile: TCompilerPPUFile);
  begin
    inherited;
    if AbsTyp=ToAddr then
      PPUFile.PutBoolean(AbsSeg);
  end;

end.

