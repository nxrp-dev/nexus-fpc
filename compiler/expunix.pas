{
    Copyright (c) 2008 by the Free Pascal Compiler team

    This unit implements common support for import,export,link routines
    for unix target

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
unit expunix;

{$i fpcdefs.inc}

interface

uses
  CClasses,
  Systems,
  export,
  symdef,SymSym,
  aasmbase;

type
  TExportLibUnix=class(TExportLib)
   private
     fexportedsymnames: TCmdStrList;
   public
    constructor Create; override;
    destructor Destroy; override;
    procedure preparelib(const s : string);override;
    procedure exportprocedure(hp : TExportedItem);override;
    procedure exportvar(hp : TExportedItem);override;
    procedure generatelib;override;
    property exportedsymnames: TCmdStrList read fexportedsymnames;
  end;

implementation

{****************************************************************************
                              TExportLibUnix
****************************************************************************}

uses
  symconst,
  Globals,
  AAsmData,aasmtai,
  FModule,
  {$ifdef cpuhighleveltarget}
  symcreat,
  {$endif}
  cgbase,
  hlcgobj,hlcgcpu,
  Verbose;


constructor TExportLibUnix.create;
begin
  inherited create;
  fexportedsymnames:=TCmdStrList.Create_No_Double;
end;

destructor TExportLibUnix.Destroy;
begin
  fexportedsymnames.free;
  fexportedsymnames := nil;
  inherited Destroy;
end;



procedure TExportLibUnix.preparelib(const s:string);
begin
end;


procedure TExportLibUnix.exportprocedure(hp : TExportedItem);
var
  hp2 : TExportedItem;
{$ifdef cpuhighleveltarget}
  pd,
  wrapperpd: TProcDef;
  i: LongInt;
  anyhasalias: boolean;
{$endif cpuhighleveltarget}
begin
  { first test the index value }
  if eo_index in hp.options then
   begin
     Message1(parser_e_no_export_with_index_for_target,TargetInfo.shortname);
     exit;
   end;
  { now place in correct order }
  hp2:=TExportedItem(CurrentModule._exports.first);
  while Assigned(hp2) and
     (hp.name^>hp2.name^) do
    hp2:=TExportedItem(hp2.next);
  { insert hp there !! }
  if Assigned(hp2) and (hp2.name^=hp.name^) then
    begin
      { this is not allowed !! }
      duplicatesymbol(hp.name^);
      exit;
    end;
  if hp2=TExportedItem(CurrentModule._exports.first) then
    CurrentModule._exports.concat(hp)
  else if Assigned(hp2) then
    begin
       hp.next:=hp2;
       hp.previous:=hp2.previous;
       if Assigned(hp2.previous) then
         hp2.previous.next:=hp;
       hp2.previous:=hp;
    end
  else
    CurrentModule._exports.concat(hp);
{$ifdef cpuhighleveltarget}
  { in case of a high level target create a stub procedure at the node/def
    level instead of via hlcg.g_external_wrapper() later on, because it's
    hard to manually create a fake procedure there (and it requires a def
    anyway) }

  { in case of eo_name there is no sym, and this routine is also called from
    exportvar() so the sym doesn't have to be a procsym }
  if Assigned(hp.sym) and
     (hp.sym.typ=procsym) then
    begin
      anyhasalias:=false;
      { if the procedure has the exported name as one of its aliases, we don't
        need a separate stub }
      pd:=nil;
      for i:=0 to TProcSym(hp.sym).procdeflist.count-1 do
        begin
          pd:=TProcDef(TProcSym(hp.sym).procdeflist[i]);
          anyhasalias:=pd.has_alias_name(hp.name^);
          if anyhasalias then
            break;
        end;
      if not anyhasalias then
        begin
          { avoid name clashes for the identifier }
          wrapperpd:=create_procdef_alias(pd,'$fpc_exported$'+hp.name^,hp.name^,
            CurrentModule.localsymtable,nil,
            tsk_callthrough,pd);
        end;
    end;
{$endif cpuhighleveltarget}
end;


procedure TExportLibUnix.exportvar(hp : TExportedItem);
begin
  hp.is_var:=true;
  exportprocedure(hp);
end;


procedure TExportLibUnix.generatelib;  // straight t_linux copy for now.
var
  hp2 : TExportedItem;
  pd  : TProcDef;
  anyhasalias : boolean;
  i : LongInt;
begin
  pd:=nil;
  create_hlcodegen(nil);
  new_section(CurrentAsmData.asmlists[al_procedures],sec_code,'',0);
  hp2:=TExportedItem(CurrentModule._exports.first);
  while Assigned(hp2) do
   begin
     if (not hp2.is_var) and
        Assigned(hp2.sym) and
        (hp2.sym.typ=procsym) then
      begin
{$ifndef cpuhighleveltarget}
        { the manglednames can already be the same when the procedure
          is declared with cdecl }
        { note: for "exports" sections we only allow non overloaded procsyms,
                so checking all symbols only matters for packages }
        anyhasalias:=false;
        for i:=0 to TProcSym(hp2.sym).procdeflist.count-1 do
          begin
            pd:=TProcDef(TProcSym(hp2.sym).procdeflist[i]);
            anyhasalias:=pd.has_alias_name(hp2.name^);
            if anyhasalias then
              break;
          end;
        if not anyhasalias then
          hlcg.g_external_wrapper(CurrentAsmData.asmlists[al_procedures],pd,hp2.name^,pd.mangledname,true);
{$endif cpuhighleveltarget}
        if not (CurrentModule.is_unit and (TargetInfo.system in systems_linux)) then
          exportedsymnames.insert(hp2.name^);
      end
     else
       begin
         if Assigned(hp2.sym) and
            (hp2.name^<>hp2.sym.mangledname) then
           Message2(parser_e_cant_export_var_different_name,hp2.sym.realname,hp2.sym.mangledname)
         else if not (CurrentModule.is_unit and (TargetInfo.system in systems_linux)) then
           exportedsymnames.insert(hp2.name^);
       end;
     hp2:=TExportedItem(hp2.next);
   end;
   destroy_hlcodegen;
end;


end.
