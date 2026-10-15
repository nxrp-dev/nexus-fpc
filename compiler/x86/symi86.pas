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
  symtype,symdef,SymSym,symx86;

type

  { ti86procvardef }

  TI86ProcVarDef = class(TX86ProcVarDef)
    function is_pushleftright: boolean; override;
  end;

  { ti86procdef }

  TI86ProcDef = class(TX86ProcDef)
    function is_pushleftright: boolean; override;
  end;

  { ti86absolutevarsym }

  TI86AbsoluteVarSym = class(TAbsoluteVarSym)
   protected
    procedure PPULoadPlatform(ppufile: TCompilerPPUFile); override;
    procedure PPUWritePlatform(ppufile: TCompilerPPUFile); override;
   public
    absseg  : boolean;
  end;

implementation

uses
  symconst;

{ ti86procvardef }

function TI86ProcVarDef.is_pushleftright: boolean;
  begin
    result:=proccalloption in pushleftright_pocalls;
  end;

{ ti86procdef }

function TI86ProcDef.is_pushleftright: boolean;
  begin
    result:=proccalloption in pushleftright_pocalls;
  end;

{ ti86absolutevarsym }

procedure TI86AbsoluteVarSym.PPULoadPlatform(ppufile: TCompilerPPUFile);
  begin
    inherited;
    if abstyp=toaddr then
      absseg:=ppufile.getboolean
    else
      absseg:=false;
  end;


procedure TI86AbsoluteVarSym.PPUWritePlatform(ppufile: TCompilerPPUFile);
  begin
    inherited;
    if abstyp=toaddr then
      ppufile.putboolean(absseg);
  end;

end.

