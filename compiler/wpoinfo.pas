{
    Copyright (c) 2008 by Jonas Maebe

    Whole program optimisation information collection

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

unit wpoinfo;

{$i fpcdefs.inc}

interface

uses
  GlobType,CClasses,
  symtype,
  wpobase;

type
  TDerefArray = array of TDeref;

  TUnitWPOInfo = class(TUnitWPOInfoBase)
   { devirtualisation information -- begin }
   private
    fcreatedobjtypesderefs: TDerefArray;
    fcreatedclassrefobjtypesderefs: TDerefArray;
    fmaybecreatedbyclassrefdeftypesderefs: TDerefArray;
    fcalledvmtentriestemplist: TFPObjectList;
   { devirtualisation information -- end }

    procedure clearderefinfo;
   public

    destructor Destroy; override;

    procedure ppuwrite(ppufile:TCompilerPPUFile);
    constructor ppuload(ppufile:TCompilerPPUFile);

    procedure deref;
    procedure derefimpl;
    procedure buildderef;
    procedure buildderefimpl;
  end;


  { twpoinfomanager }

  TWPOInfoManager = class(TWPOInfoManagerBase)
    function can_be_devirtualized(objdef, procdef: TDef; out name: TSymStr): boolean; override;
    function optimized_name_for_vmt(objdef, procdef: TDef; out name: TSymStr): boolean; override;
    function symbol_live(const name: shortstring): boolean; override;
  end;


implementation

  uses
    Globals,
    symdef,
    Verbose,
    entfile;

  procedure TUnitWPOInfo.clearderefinfo;
    begin
      fcreatedobjtypesderefs:=nil;
      fcreatedclassrefobjtypesderefs:=nil;
      fmaybecreatedbyclassrefdeftypesderefs:=nil;

      fcalledvmtentriestemplist.free;
      fcalledvmtentriestemplist:=nil;
    end;

  destructor TUnitWPOInfo.Destroy;
    begin
      clearderefinfo;
      inherited Destroy;
    end;


  procedure TUnitWPOInfo.ppuwrite(ppufile:TCompilerPPUFile);
    var
      i: LongInt;
    begin
      { write the number of instantiated object types in this module,
        followed by the derefs of those types
      }
      ppufile.putlongint(fcreatedobjtypes.count);
      for i:=0 to fcreatedobjtypes.count-1 do
        ppufile.putderef(fcreatedobjtypesderefs[i]);
      ppufile.putlongint(fcreatedclassrefobjtypes.count);
      for i:=0 to fcreatedclassrefobjtypes.count-1 do
        ppufile.putderef(fcreatedclassrefobjtypesderefs[i]);
      ppufile.putlongint(fmaybecreatedbyclassrefdeftypes.count);
      for i:=0 to fmaybecreatedbyclassrefdeftypes.count-1 do
        ppufile.putderef(fmaybecreatedbyclassrefdeftypesderefs[i]);

      ppufile.putlongint(fcalledvmtentriestemplist.count);
      for i:=0 to fcalledvmtentriestemplist.count-1 do
        TCalledVMTEntries(fcalledvmtentriestemplist[i]).ppuwrite(ppufile);

      ppufile.writeentry(ibcreatedobjtypes);

      { don't free deref arrays immediately after use, as the types may need
        re-resolving in case a unit needs to be reloaded
      }
    end;


  constructor TUnitWPOInfo.ppuload(ppufile:TCompilerPPUFile);
    var
      i, len: LongInt;
    begin
      { load start of definition section, which holds the amount of defs }
      if ppufile.readentry<>ibcreatedobjtypes then
        message(unit_f_ppu_read_error);

      { don't load the wpo info from the units if we are not generating
        a wpo feedback file (that would just take time and memory)
      }
      if (InitSettings.GenWPOptimizerSwitches=[]) then
        ppufile.skipdata(ppufile.entrysize)
      else
        begin
          len:=ppufile.getlongint;
          fcreatedobjtypes:=TFPObjectList.create(false);
          fcreatedobjtypes.count:=len;
          SetLength(fcreatedobjtypesderefs,len);
          for i:=0 to len-1 do
            ppufile.getderef(fcreatedobjtypesderefs[i]);

          len:=ppufile.getlongint;
          fcreatedclassrefobjtypes:=TFPObjectList.create(false);
          fcreatedclassrefobjtypes.count:=len;
          SetLength(fcreatedclassrefobjtypesderefs,len);
          for i:=0 to len-1 do
            ppufile.getderef(fcreatedclassrefobjtypesderefs[i]);

          len:=ppufile.getlongint;
          fmaybecreatedbyclassrefdeftypes:=TFPObjectList.create(false);
          fmaybecreatedbyclassrefdeftypes.count:=len;
          SetLength(fmaybecreatedbyclassrefdeftypesderefs,len);
          for i:=0 to len-1 do
            ppufile.getderef(fmaybecreatedbyclassrefdeftypesderefs[i]);

          len:=ppufile.getlongint;
          fcalledvmtentriestemplist:=TFPObjectList.create(false);
          fcalledvmtentriestemplist.count:=len;
          fcalledvmtentries:=TFPHashList.create;
          for i:=0 to len-1 do
            fcalledvmtentriestemplist[i]:=TCalledVMTEntries.ppuload(ppufile);
        end;
    end;


  procedure TUnitWPOInfo.buildderef;
    var
      i: LongInt;
    begin
      { ppuload may have already been called before -> deref info structures
        may already have been allocated }
      clearderefinfo;

      SetLength(fcreatedobjtypesderefs,fcreatedobjtypes.count);
      for i:=0 to fcreatedobjtypes.count-1 do
        fcreatedobjtypesderefs[i].build(fcreatedobjtypes[i]);

      SetLength(fcreatedclassrefobjtypesderefs,fcreatedclassrefobjtypes.count);
      for i:=0 to fcreatedclassrefobjtypes.count-1 do
        fcreatedclassrefobjtypesderefs[i].build(fcreatedclassrefobjtypes[i]);

      SetLength(fmaybecreatedbyclassrefdeftypesderefs,fmaybecreatedbyclassrefdeftypes.count);
      for i:=0 to fmaybecreatedbyclassrefdeftypes.count-1 do
        fmaybecreatedbyclassrefdeftypesderefs[i].build(fmaybecreatedbyclassrefdeftypes[i]);

      fcalledvmtentriestemplist:=TFPObjectList.create(false);
      fcalledvmtentriestemplist.count:=fcalledvmtentries.count;
      for i:=0 to fcalledvmtentries.count-1 do
        begin
          TCalledVMTEntries(fcalledvmtentries[i]).buildderef;
          { necessary in case we have unit1 loads unit2, unit2 is recompiled,
            then unit1 derefs unit2 -> in this case we have buildderef for unit2
            -> ppuwrite for unit2 -> deref for unit2 (without a load) -> ensure
            that the fcalledvmtentriestemplist, normally constructed by ppuload,
            is created here as well since deref needs it }
          fcalledvmtentriestemplist[i]:=tobject(fcalledvmtentries[i]);
        end;
    end;


  procedure TUnitWPOInfo.buildderefimpl;
    var
      i: LongInt;
    begin
      for i:=0 to fcalledvmtentriestemplist.count-1 do
        begin
          TCalledVMTEntries(fcalledvmtentriestemplist[i]).buildderefimpl;
        end;
    end;


  procedure TUnitWPOInfo.deref;
    var
      i: LongInt;

    begin
      if (InitSettings.GenWPOptimizerSwitches=[]) or
         not Assigned(fcalledvmtentriestemplist) then
        exit;

      { don't free deref arrays immediately after use, as the types may need
        re-resolving in case a unit needs to be reloaded
      }
      for i:=0 to fcreatedobjtypes.count-1 do
        fcreatedobjtypes[i]:=fcreatedobjtypesderefs[i].resolve;

      for i:=0 to fcreatedclassrefobjtypes.count-1 do
        fcreatedclassrefobjtypes[i]:=fcreatedclassrefobjtypesderefs[i].resolve;

      for i:=0 to fmaybecreatedbyclassrefdeftypes.count-1 do
        fmaybecreatedbyclassrefdeftypes[i]:=fmaybecreatedbyclassrefdeftypesderefs[i].resolve;

      { in case we are re-resolving, free previous batch }
      if (fcalledvmtentries.count<>0) then
        fcalledvmtentries.clear;
      { allocate enough internal memory in one go }
      fcalledvmtentries.capacity:=fcalledvmtentriestemplist.count;
      { now resolve all items in the list and add them to the hash table }
      for i:=0 to fcalledvmtentriestemplist.count-1 do
        begin
          with TCalledVMTEntries(fcalledvmtentriestemplist[i]) do
            begin
              deref;
              fcalledvmtentries.add(TObjectDef(objdef).vmt_mangledname,
                fcalledvmtentriestemplist[i]);
            end;
        end;
    end;


  procedure TUnitWPOInfo.derefimpl;
    var
      i: LongInt;
    begin
      if (InitSettings.GenWPOptimizerSwitches=[]) or
         not Assigned(fcalledvmtentriestemplist) then
        exit;

      for i:=0 to fcalledvmtentriestemplist.count-1 do
        begin
          TCalledVMTEntries(fcalledvmtentriestemplist[i]).derefimpl;
        end;
    end;


  { twpoinfomanager }

  { devirtualisation }

  function TWPOInfoManager.can_be_devirtualized(objdef, procdef: TDef; out name: TSymStr): boolean;
    begin
      if not Assigned(wpoinfouse[wpo_devirtualization_context_insensitive]) or
         not(cs_wpo_devirtualize_calls in CurrentSettings.DoWPOptimizerSwitches) then
        begin
          result:=false;
          exit;
        end;
      result:=TWPODevirtualisationHandler(wpoinfouse[wpo_devirtualization_context_insensitive]).staticnameforcallingvirtualmethod(objdef,procdef,name);
    end;


  function TWPOInfoManager.optimized_name_for_vmt(objdef, procdef: TDef; out name: TSymStr): boolean;
    begin
      if not Assigned(wpoinfouse[wpo_devirtualization_context_insensitive]) or
         not(cs_wpo_optimize_vmts in CurrentSettings.DoWPOptimizerSwitches) then
        begin
          result:=false;
          exit;
        end;
      result:=TWPODevirtualisationHandler(wpoinfouse[wpo_devirtualization_context_insensitive]).staticnameforvmtentry(objdef,procdef,name);
    end;


  { symbol liveness }

  function TWPOInfoManager.symbol_live(const name: shortstring): boolean;
    begin
      if not Assigned(wpoinfouse[wpo_live_symbol_information]) or
         not(cs_wpo_symbol_liveness in CurrentSettings.DoWPOptimizerSwitches) then
        begin
          { if we don't know, say that the symbol is live }
          result:=true;
          exit;
        end;
      result:=TWPODeadCodeHandler(wpoinfouse[wpo_live_symbol_information]).symbolinfinalbinary(name);
    end;


end.
