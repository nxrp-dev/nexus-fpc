{
    Copyright (c) 1998-2002 by Florian Klaempfl

    This unit implements an uniform export object

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
unit export;

{$i fpcdefs.inc}

interface

uses
  CUtils,CClasses,
  Systems,
  symtype,symdef,SymSym,
  AAsmData;

type
   { export options }
   TExportOption=(eo_none,
     eo_resident,
     eo_index,
     eo_name,
     eo_no_sym_name, { don't try to use another mangled name if symbol is known }
     eo_promising_first,
     eo_promising_last
   );
   TExportOptions=set of TExportOption;

   TExportedItem = class(TLinkedListItem)
      sym : TSym;
      index : LongInt;
      name : PShortString;
      { Stable assembler name for exports that outlive the unit's symbols. }
      internalname : string;
      options : TExportOptions;
      is_var : boolean;
      constructor create;
      destructor Destroy;override;
   end;

   TExportLib=class
   private
      notsupmsg : boolean;
      fignoreduplicates : boolean;
      finitname,
      ffininame  : string;
      procedure NotSupported;
   protected
      procedure duplicatesymbol(const s:string);
   public
      constructor Create;virtual;
      destructor Destroy;override;
      procedure preparelib(const s : string);virtual;
      procedure exportprocedure(hp : TExportedItem);virtual;
      procedure exportvar(hp : TExportedItem);virtual;
      procedure generatelib;virtual;
      procedure setinitname(list: TAsmList; const s: string); virtual;
      procedure setfininame(list: TAsmList; const s: string); virtual;

      property initname: string read finitname;
      property fininame: string read ffininame;
      property ignoreduplicates : boolean read fignoreduplicates write fignoreduplicates;
   end;

   TExportLibClass=class of TExportLib;


  procedure exportprocsym(sym: TSym; const s : string; index: LongInt; options: TExportOptions);
  procedure exportvarsym(sym: TSym; const s : string; index: LongInt; options: TExportOptions);
  { to export symbols not directly related to a tsym (e.g., the Objective-C
    rtti) }
  procedure exportname(const s : string; options: TExportOptions);

  procedure exportallprocdefnames(sym: TProcSym; pd: TProcDef; options: TExportOptions);
  procedure exportallprocsymnames(ps: TProcSym; options: TExportOptions);


var
  CExportLib : array[0..MaxStoredSystemId] of TExportLibClass;
  ExportLib  : TExportLib;

procedure RegisterExport(t:TSystem;c:TExportLibClass);
procedure InitExport;
procedure DoneExport;

implementation

uses
  Verbose,Globals;

{****************************************************************************
                           TExported_procedure
****************************************************************************}

procedure exportprocsym(sym: TSym; const s : string; index: LongInt; options: TExportOptions);
  var
    hp : TExportedItem;
  begin
    hp:=TExportedItem.create;
    hp.name:=StringDup(s);
    hp.sym:=sym;
    hp.options:=options+[eo_name];
    hp.Index:=index;
    exportlib.exportprocedure(hp);
  end;


procedure exportvarsym(sym: TSym; const s : string; index: LongInt; options: TExportOptions);
  var
    hp : TExportedItem;
  begin
    hp:=TExportedItem.create;
    hp.name:=StringDup(s);
    hp.sym:=sym;
    hp.is_var:=true;
    hp.options:=options+[eo_name];
    hp.Index:=index;
    exportlib.exportvar(hp);
  end;


procedure exportname(const s : string; options: TExportOptions);
  begin
    exportvarsym(nil,s,0,options);
  end;


  procedure exportallprocdefnames(sym: TProcSym; pd: TProcDef; options: TExportOptions);
    var
      item: TCmdStrListItem;
    begin
      exportprocsym(sym,pd.MangledName,0,options);
      { walk through all aliases }
      item:=TCmdStrListItem(pd.AliasNames.first);
      while Assigned(item) do
        begin
          { avoid duplicate entries, sometimes aliasnames contains the mangledname }
          if item.str<>pd.MangledName then
            exportprocsym(sym,item.str,0,options);
          item:=TCmdStrListItem(item.next);
        end;
    end;


  procedure exportallprocsymnames(ps: TProcSym; options: TExportOptions);
    var
      i: LongInt;
    begin
      for i:= 0 to ps.ProcdefList.Count-1 do
        exportallprocdefnames(ps,TProcDef(ps.ProcdefList[i]),options);
    end;


{****************************************************************************
                           TExported_procedure
****************************************************************************}

constructor TExportedItem.Create;
begin
  inherited Create;
  sym:=nil;
  index:=-1;
  name:=nil;
  internalname:='';
  options:=[];
  is_var:=false;
end;


destructor TExportedItem.Destroy;
begin
  StringDispose(name);
  inherited Destroy;
end;


{****************************************************************************
                              TExportLib
****************************************************************************}

constructor TExportLib.Create;
begin
  notsupmsg:=false;
  fignoreduplicates:=false;
end;


destructor TExportLib.Destroy;
begin
end;


procedure TExportLib.NotSupported;
begin
  { show the message only once }
  if not notsupmsg then
   begin
     Message(exec_e_dll_not_supported);
     notsupmsg:=true;
   end;
end;


procedure TExportLib.duplicatesymbol(const s: string);
begin
  { only generate an error if the caller is not aware that it could generate
    duplicates (e.g. exporting from a package) }
  if not ignoreduplicates then
    Message1(parser_e_export_name_double,s);
end;


procedure TExportLib.preparelib(const s:string);
begin
  NotSupported;
end;


procedure TExportLib.exportprocedure(hp : TExportedItem);
begin
  NotSupported;
end;


procedure TExportLib.exportvar(hp : TExportedItem);
begin
  NotSupported;
end;


procedure TExportLib.generatelib;
begin
  NotSupported;
end;


procedure TExportLib.setinitname(list: TAsmList; const s: string);
begin
  finitname:=s;
end;


procedure TExportLib.setfininame(list: TAsmList; const s: string);
begin
  ffininame:=s;
end;

{*****************************************************************************
                                 Init/Done
*****************************************************************************}

procedure RegisterExport(t:TSystem;c:TExportLibClass);
begin
  CExportLib[Ord(t)]:=c;
end;


procedure InitExport;
begin
  if Assigned(CExportLib[Ord(TargetInfo.system)]) then
   exportlib:=CExportLib[Ord(TargetInfo.system)].Create
  else
   exportlib:=TExportLib.Create;
end;


procedure DoneExport;
begin
  if Assigned(Exportlib) then
    Exportlib.free;
    Exportlib := nil;
end;


end.
