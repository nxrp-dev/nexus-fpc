{
    Copyright (c) 2008 by Jonas Maebe

    Whole program optimisation information collection base class

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

unit wpobase;

{$i fpcdefs.inc}

interface

uses
  GlobType,
  CClasses,
  symtype;

type
  { the types of available whole program optimization }
  TWPOType = (wpo_devirtualization_context_insensitive,wpo_live_symbol_information);
const
  wpo2str: array[TWPOType] of string[16] = ('devirtualization','symbol liveness');

type
  { ************************************************************************* }
  { ******************** General base classes/interfaces ******************** }
  { ************************************************************************* }

  { interface to reading a section from a file with wpo info }
  TWPOSectionReaderIntf = interface
    ['{51BE3F89-C9C5-4965-9C83-AE7490C92E3E}']
    function sectiongetnextline(out s: ShortString): boolean;
  end;


  { interface to writing sections to a file with wpoinfo }
  TWPOSectionWriterIntf = interface
    ['{C056F0DD-62B1-4612-86C7-2D39944C4437}']
    procedure startsection(const name: ShortString);
    procedure sectionputline(const s: ShortString);
  end;


  { base class for wpo information stores }

  { twpocomponentbase }

  TWPOComponentBase = class
   public
    constructor create; reintroduce; virtual;

    { type of whole program optimization information collected/provided by
      this class
    }
    class function getwpotype: TWPOType; virtual; abstract;

    { whole program optimizations for which this class generates information }
    class function generatesinfoforwposwitches: TWPOptimizerSwitches; virtual; abstract;

    { whole program optimizations performed by this class }
    class function performswpoforswitches: TWPOptimizerSwitches; virtual; abstract;

    { returns the name of the section parsed by this class }
    class function sectionname: shortstring; virtual; abstract;

    { checks whether the compiler options are compatible with this
      optimization (default: don't check anything)
    }
    class procedure checkoptions; virtual;

    { loads the information pertinent to this whole program optimization from
      the current section being processed by reader
    }
    procedure loadfromwpofilesection(reader: TWPOSectionReaderIntf); virtual; abstract;

    { stores the information of this component to a file in a format that can
      be loaded again using loadfromwpofilesection()
    }
    procedure storewpofilesection(writer: TWPOSectionWriterIntf); virtual; abstract;

    { extracts the information pertinent to this whole program optimization
      from the current compiler state (loaded units, ...)
    }
    procedure constructfromcompilerstate; virtual; abstract;
  end;

  TWPOComponentBaseClass = class of TWPOComponentBase;


  { forward declaration of overall wpo info manager class }

  TWPOInfoManagerBase = class;

  { ************************************************************************* }
  { ** Information created per unit for use during subsequent compilation *** }
  { ************************************************************************* }

  { information about called vmt entries for a class }
  TCalledVMTEntries = class
   protected
    { the class }
    fobjdef: TDef;
    fobjdefderef: TDeref;
    { the vmt entries }
    fcalledentries: TBitSet;
   public
    constructor create(_objdef: TDef; nentries: LongInt);
    constructor ppuload(ppufile: TCompilerPPUFile);
    destructor Destroy; override;
    procedure ppuwrite(ppufile: TCompilerPPUFile);

    procedure buildderef;
    procedure buildderefimpl;
    procedure deref;
    procedure derefimpl;

    property objdef: TDef read fobjdef write fobjdef;
    property objdefderef: TDeref read fobjdefderef write fobjdefderef;
    property calledentries: TBitSet read fcalledentries write fcalledentries;
  end;


  { base class of information collected per unit. Still needs to be
    generalised for different kinds of wpo information, currently specific
    to devirtualization.
  }

  TUnitWPOInfoBase = class
   protected
    { created object types }
    fcreatedobjtypes: TFPObjectList;
    { objectdefs pointed to by created classrefdefs }
    fcreatedclassrefobjtypes: TFPObjectList;
    { objtypes potentially instantiated by fcreatedclassrefobjtypes
      (objdectdefs pointed to by classrefdefs that are
       passed as a regular parameter, loaded in a variable, ...
       so they can end up in a classrefdef var and be instantiated)
    }
    fmaybecreatedbyclassrefdeftypes: TFPObjectList;

    { called virtual methods for all classes (hashed by mangled classname,
      entries bitmaps indicating which vmt entries per class are called --
      tcalledvmtentries)
    }
    fcalledvmtentries: TFPHashList;
   public
    constructor create; reintroduce; virtual;
    destructor Destroy; override;

    property createdobjtypes: TFPObjectList read fcreatedobjtypes;
    property createdclassrefobjtypes: TFPObjectList read fcreatedclassrefobjtypes;
    property maybecreatedbyclassrefdeftypes: TFPObjectList read fmaybecreatedbyclassrefdeftypes;
    property calledvmtentries: TFPHashList read fcalledvmtentries;

    procedure addcreatedobjtype(def: TDef);
    procedure addcreatedobjtypeforclassref(def: TDef);
    procedure addmaybecreatedbyclassref(def: TDef);
    procedure addcalledvmtentry(def: TDef; index: LongInt);

    { resets the "I've been registered with wpo" flags for all defs in the
      above lists }
    procedure resetdefs;
  end;

  { ************************************************************************* }
  { **** Total information created for use during subsequent compilation **** }
  { ************************************************************************* }

  { class to create a file with wpo information }

  { tavailablewpofilewriter }

  TWPOFileWriter = class(tobject,TWPOSectionWriterIntf)
   private
    { array of class *instances* that wish to be written out to the
      whole program optimization feedback file
    }
    fsectioncontents: TFPObjectList;

    ffilename: TCmdStr;
    foutputfile: text;

   public
    constructor create(const fn: TCmdStr);
    destructor Destroy; override;

    procedure writefile;

    { starts a new section with name "name" }
     procedure startsection(const name: ShortString);
    { writes s to the wpo file }
     procedure sectionputline(const s: ShortString);

    { register a component instance that needs to be written
      to the wpo feedback file
    }
    procedure registerwpocomponent(component: TWPOComponentBase);
  end;

  { ************************************************************************* }
  { ************ Information for use during current compilation ************* }
  { ************************************************************************* }

  { class to read a file with wpo information }
  TWPOFileReader = class(tobject,TWPOSectionReaderIntf)
   private
    ffilename: TCmdStr;
    flinenr: LongInt;
    finputfile: text;
     fcurline: ShortString;
    fusecurline: boolean;

    { destination for the read information }
    fdest: TWPOInfoManagerBase;

     function getnextnoncommentline(out s: ShortString): boolean;
   public

     constructor create(const fn: TCmdStr; dest: TWPOInfoManagerBase);
     destructor Destroy; override;

     { processes the wpo info in the file }
     procedure processfile;

     { returns next line of the current section in s, and false if no more
       lines in the current section
     }
      function sectiongetnextline(out s: ShortString): boolean;
  end;


  { ************************************************************************* }
  { ******* Specific kinds of whole program optimization components ********* }
  { ************************************************************************* }

  { method devirtualisation }
  TWPODevirtualisationHandler = class(TWPOComponentBase)
    { checks whether procdef (a procdef for a virtual method) can be replaced with
      a static call when it's called as objdef.procdef, and if so returns the
      mangled name in staticname.
    }
    function staticnameforcallingvirtualmethod(objdef, procdef: TDef; out staticname: TSymStr): boolean; virtual; abstract;
    { checks whether procdef (a procdef for a virtual method) can be replaced with
      a different procname in the vmt of objdef, and if so returns the new
      mangledname in staticname
    }
    function staticnameforvmtentry(objdef, procdef: TDef; out staticname: TSymStr): boolean; virtual; abstract;
  end;

  TWPODeadCodeHandler = class(TWPOComponentBase)
    { checks whether a mangledname was removed as dead code from the final
      binary (WARNING: must *not* be called for functions marked as inline,
      since if all call sites are inlined, it won't appear in the final
      binary but nevertheless is still necessary!)
    }
    function symbolinfinalbinary(const s: shortstring): boolean; virtual; abstract;
  end;


  { ************************************************************************* }
  { ************ Collection of all instances of wpo components ************** }
  { ************************************************************************* }

  { class doing all the bookkeeping for everything  }

  TWPOInfoManagerBase = class
   private
    { array of classrefs of handler classes for the various kinds of whole
      program optimizations that we support
    }
    fwpocomponents: TFPHashList;

    freader: TWPOFileReader;
    fwriter: TWPOFileWriter;
   public
    { instances of the various optimizers/information collectors (for
      information used during this compilation)
    }
    wpoinfouse: array[TWPOType] of TWPOComponentBase;

    { register a whole program optimization class type }
    procedure registerwpocomponentclass(wpocomponent: TWPOComponentBaseClass);

    { get the program optimization class type that can parse the contents
      of the section with name "secname" in the wpo feedback file
    }
     function gethandlerforsection(const secname: ShortString): TWPOComponentBaseClass;

    { tell all instantiated wpo component classes to collect the information
      from the global compiler state that they need (done at the very end of
      the compilation process)
    }
    procedure extractwpoinfofromprogram;

    { set the name of the feedback file from which all whole-program information
      to be used during the current compilation will be read
    }
    procedure setwpoinputfile(const fn: TCmdStr);

    { set the name of the feedback file to which all whole-program information
      collected during the current compilation will be written
    }
    procedure setwpooutputfile(const fn: TCmdStr);

    { check whether the specified wpo options (-FW/-Fw/-OW/-Ow) are complete
      and sensical, and parse the wpo feedback file specified with
      setwpoinputfile
    }
    procedure parseandcheckwpoinfo;

    { routines accessing the optimizer information }
    { 1) devirtualization at the symbol name level }
    function can_be_devirtualized(objdef, procdef: TDef; out name: TSymStr): boolean; virtual; abstract;
    { 2) optimal replacement method name in vmt }
    function optimized_name_for_vmt(objdef, procdef: TDef; out name: TSymStr): boolean; virtual; abstract;
    { 3) does a symbol appear in the final binary (i.e., not removed by dead code stripping/smart linking).
        WARNING: do *not* call for inline functions/procedures/methods/...
    }
    function symbol_live(const name: shortstring): boolean; virtual; abstract;

    function symbol_live_in_currentproc(fordef: TDef): boolean;

    constructor create; reintroduce;
    destructor Destroy; override;
  end;


  var
    wpoinfomanager: TWPOInfoManagerBase;

implementation

  uses
    Globals,
    CUtils,
    SysUtils,
    symconst,symdef,
    ProcInfo,
    Verbose;


  { tcreatedwpoinfobase }

  constructor TUnitWPOInfoBase.create;
    begin
      fcreatedobjtypes:=TFPObjectList.create(false);
      fcreatedclassrefobjtypes:=TFPObjectList.create(false);
      fmaybecreatedbyclassrefdeftypes:=TFPObjectList.create(false);
      fcalledvmtentries:=TFPHashList.create;
    end;


  destructor TUnitWPOInfoBase.Destroy;
    var
      i: LongInt;
    begin
      { don't call resetdefs here, because the defs may have been freed
        already }
      fcreatedobjtypes.free;
      fcreatedobjtypes:=nil;
      fcreatedclassrefobjtypes.free;
      fcreatedclassrefobjtypes:=nil;
      fmaybecreatedbyclassrefdeftypes.free;
      fmaybecreatedbyclassrefdeftypes:=nil;

      { may not be assigned in case the info was loaded from a ppu and we
        are not generating a wpo feedback file (see tunitwpoinfo.ppuload)
      }
      if Assigned(fcalledvmtentries) then
        begin
          for i:=0 to fcalledvmtentries.count-1 do
            TCalledVMTEntries(fcalledvmtentries[i]).free; // no nil needed
          fcalledvmtentries.free;
          fcalledvmtentries:=nil;
        end;

      inherited Destroy;
    end;


  procedure TUnitWPOInfoBase.resetdefs;
    var
      i: ptrint;
    begin
      if Assigned(fcreatedobjtypes) then
        for i:=0 to fcreatedobjtypes.count-1 do
          TObjectDef(fcreatedobjtypes[i]).created_in_current_module:=false;
      if Assigned(fcreatedclassrefobjtypes) then
        for i:=0 to fcreatedclassrefobjtypes.count-1 do
          TObjectDef(fcreatedclassrefobjtypes[i]).classref_created_in_current_module:=false;
      if Assigned(fmaybecreatedbyclassrefdeftypes) then
        for i:=0 to fmaybecreatedbyclassrefdeftypes.count-1 do
          TObjectDef(fmaybecreatedbyclassrefdeftypes[i]).maybe_created_in_current_module:=false;
    end;


  procedure TUnitWPOInfoBase.addcreatedobjtype(def: TDef);
    begin
      fcreatedobjtypes.add(def);
    end;


  procedure TUnitWPOInfoBase.addcreatedobjtypeforclassref(def: TDef);
    begin
      fcreatedclassrefobjtypes.add(def);
    end;


  procedure TUnitWPOInfoBase.addmaybecreatedbyclassref(def: TDef);
    begin
      fmaybecreatedbyclassrefdeftypes.add(def);
    end;


  procedure TUnitWPOInfoBase.addcalledvmtentry(def: TDef; index: LongInt);
    var
      entries: TCalledVMTEntries;
      key: shortstring;
    begin
      key:=TObjectDef(def).vmt_mangledname;
      entries:=TCalledVMTEntries(fcalledvmtentries.find(key));
      if not Assigned(entries) then
        begin
          entries:=TCalledVMTEntries.create(def,TObjectDef(def).vmtentries.count);
          fcalledvmtentries.add(key,entries);
        end;
      entries.calledentries.include(index);
    end;


  { twpofilereader }

  function TWPOFileReader.getnextnoncommentline(out s: ShortString):
    boolean;
    begin
      if (fusecurline) then
        begin
          s:=fcurline;
          fusecurline:=false;
          result:=true;
          exit;
        end;
      repeat
        readln(finputfile,s);
        if (s='') and
           eof(finputfile) then
          begin
            result:=false;
            exit;
          end;
        inc(flinenr);
      until (s='') or
            (s[1]<>'#');
      result:=true;
    end;

  constructor TWPOFileReader.create(const fn: TCmdStr; dest: TWPOInfoManagerBase);
    begin
      if not FileExists(fn) or
         { FileExists also returns true for directories }
         DirectoryExists(fn) then
        begin
          CGMessage1(wpo_cant_find_file,fn);
          exit;
        end;
      assign(finputfile,fn);
      ffilename:=fn;

      fdest:=dest;
    end;

  destructor TWPOFileReader.Destroy;
    begin
      inherited Destroy;
    end;

  procedure TWPOFileReader.processfile;
    var
      sectionhandler: TWPOComponentBaseClass;
      i: LongInt;
      wpotype: TWPOType;
      s,
      sectionname: ShortString;
    begin
      CGMessage1(wpo_begin_processing,ffilename);
      reset(finputfile);
      flinenr:=0;
      while getnextnoncommentline(s) do
        begin
          if (s='') then
            continue;
          { format: "% sectionname" }
          if (s[1]<>'%') then
            begin
              CGMessage2(wpo_expected_section,ToStr(flinenr),s);
              break;
            end;
          i:=2;
          for i:=2 to length(s) do
            if (s[i]<>' ') then
              break;
          sectionname:=copy(s,i,255);

          { find handler for section and process }
          sectionhandler:=fdest.gethandlerforsection(sectionname);
          if Assigned(sectionhandler) then
            begin
              wpotype:=sectionhandler.getwpotype;
              CGMessage2(wpo_found_section,sectionname,wpo2str[wpotype]);
              { do we need this information? }
              if ((sectionhandler.performswpoforswitches * InitSettings.DoWPOptimizerSwitches) <> []) then
                begin
                  { did some other section already generate this type of information? }
                  if Assigned(fdest.wpoinfouse[wpotype]) then
                    begin
                      CGMessage2(wpo_duplicate_wpotype,wpo2str[wpotype],sectionname);
                      FreeAndNil(fdest.wpoinfouse[wpotype]);
                    end;
                  { process the section }
                  fdest.wpoinfouse[wpotype]:=sectionhandler.create;
                  TWPOComponentBase(fdest.wpoinfouse[wpotype]).loadfromwpofilesection(self);
                end
              else
                begin
                  CGMessage1(wpo_skipping_unnecessary_section,sectionname);
                  { skip the current section }
                  while sectiongetnextline(s) do
                    ;
                end;
            end
          else
            begin
              CGMessage1(wpo_no_section_handler,sectionname);
              { skip the current section }
              while sectiongetnextline(s) do
                ;
            end;
        end;
      close(finputfile);
      CGMessage1(wpo_end_processing,ffilename);
    end;

  function TWPOFileReader.sectiongetnextline(out s: ShortString): boolean;
    begin
      result:=getnextnoncommentline(s);
      if not result then
        exit;
      { start of new section? }
      if (s<>'') and
         (s[1]='%') then
        begin
          { keep read line for next call to getnextnoncommentline() }
          fcurline:=s;
          fusecurline:=true;
          result:=false;
        end;
    end;


  { twpocomponentbase }

  constructor TWPOComponentBase.create;
    begin
      { do nothing }
    end;


  class procedure TWPOComponentBase.checkoptions;
    begin
      { do nothing }
    end;

  { twpofilewriter }

  constructor TWPOFileWriter.create(const fn: TCmdStr);
    begin
      assign(foutputfile,fn);
      ffilename:=fn;
      fsectioncontents:=TFPObjectList.create(true);
    end;

  destructor TWPOFileWriter.Destroy;
    begin
      fsectioncontents.free;
      fsectioncontents := nil;
      inherited Destroy;
    end;

  procedure TWPOFileWriter.writefile;
    var
      i: LongInt;
    begin
      {$push}{$i-}
      rewrite(foutputfile);
      {$pop}
      if (IOResult <> 0) then
        begin
          CGMessage1(wpo_cant_create_feedback_file,ffilename);
          exit;
        end;
      for i:=0 to fsectioncontents.count-1 do
        TWPOComponentBase(fsectioncontents[i]).storewpofilesection(self);
      close(foutputfile);
    end;

  procedure TWPOFileWriter.startsection(const name: ShortString);
    begin
      WriteLn(foutputfile,'% ',name);
    end;

  procedure TWPOFileWriter.sectionputline(const s: ShortString);
    begin
      WriteLn(foutputfile,s);
    end;

  procedure TWPOFileWriter.registerwpocomponent(
    component: TWPOComponentBase);
    begin
      fsectioncontents.add(component);
    end;

{ twpoinfomanagerbase }

  procedure TWPOInfoManagerBase.registerwpocomponentclass(wpocomponent: TWPOComponentBaseClass);
    begin
      fwpocomponents.add(wpocomponent.sectionname,wpocomponent);
    end;


  function TWPOInfoManagerBase.gethandlerforsection(const secname: ShortString
      ): TWPOComponentBaseClass;
    begin
      result:=TWPOComponentBaseClass(fwpocomponents.find(secname));
    end;

  procedure TWPOInfoManagerBase.setwpoinputfile(const fn: TCmdStr);
    begin
      freader:=TWPOFileReader.create(fn,self);
    end;

  procedure TWPOInfoManagerBase.setwpooutputfile(const fn: TCmdStr);
    begin
      fwriter:=TWPOFileWriter.create(fn);
    end;

  procedure TWPOInfoManagerBase.parseandcheckwpoinfo;
    var
      i: LongInt;
    begin
      { error if we don't have to optimize yet have an input feedback file }
      if (InitSettings.DoWPOptimizerSwitches=[]) and
         Assigned(freader) then
        begin
          CGMessage(wpo_input_without_info_use);
          exit;
        end;

      { error if we have to optimize yet don't have an input feedback file }
      if (InitSettings.DoWPOptimizerSwitches<>[]) and
         not Assigned(freader) then
        begin
          CGMessage(wpo_no_input_specified);
          exit;
        end;

      { if we have to generate wpo information, check that a file has been
        specified and that we have something to write to it
      }
      if (InitSettings.GenWPOptimizerSwitches<>[]) and
         not Assigned(fwriter) then
        begin
          CGMessage(wpo_no_output_specified);
          exit;
        end;

      if (InitSettings.GenWPOptimizerSwitches=[]) and
         Assigned(fwriter) then
        begin
          CGMessage(wpo_output_without_info_gen);
          exit;
        end;

      { now read the input feedback file }
      if Assigned(freader) then
        begin
          freader.processfile;
          freader.free;
          freader:=nil;
        end;

      { and for each specified optimization check whether the input feedback
        file contained the necessary information
      }
      if (([cs_wpo_devirtualize_calls,cs_wpo_optimize_vmts] * InitSettings.DoWPOptimizerSwitches) <> []) and
         not Assigned(wpoinfouse[wpo_devirtualization_context_insensitive]) then
        begin
          CGMessage1(wpo_not_enough_info,wpo2str[wpo_devirtualization_context_insensitive]);
          exit;
        end;

      if (cs_wpo_symbol_liveness in InitSettings.DoWPOptimizerSwitches) and
         not Assigned(wpoinfouse[wpo_live_symbol_information]) then
        begin
          CGMessage1(wpo_not_enough_info,wpo2str[wpo_live_symbol_information]);
          exit;
        end;

      { perform pre-checking to ensure there are no known incompatibilities between
        the selected optimizations and other switches
      }
      for i:=0 to fwpocomponents.count-1 do
        if (TWPOComponentBaseClass(fwpocomponents[i]).generatesinfoforwposwitches*InitSettings.GenWPOptimizerSwitches)<>[] then
          TWPOComponentBaseClass(fwpocomponents[i]).checkoptions
    end;

  function TWPOInfoManagerBase.symbol_live_in_currentproc(fordef: TDef): boolean;

    function alias_symbol_live: boolean;
      var
        item: TCmdStrListItem;
      begin
        result:=true;
        item:=TCmdStrListItem(CurrentProcInfo.procdef.aliasnames.first);
        while Assigned(item) do
          begin
            if symbol_live(item.Str) then
              exit;
            item:=TCmdStrListItem(item.Next);
          end;
        result:=false;
      end;

    begin
      if Assigned(CurrentProcInfo) and
         not(po_inline in CurrentProcInfo.procdef.procoptions) and
         not symbol_live(CurrentProcInfo.procdef.mangledname) and
         not alias_symbol_live then
        begin
{$ifdef debug_deadcode}
          WriteLn(' NOT adding creation of ',fordef.typename,' because performed in dead stripped proc: ',CurrentProcInfo.procdef.typename);
{$endif debug_deadcode}
          result:=false;
        end
      else
        result:=true;
    end;

  procedure TWPOInfoManagerBase.extractwpoinfofromprogram;
    var
      i: LongInt;
      info: TWPOComponentBase;
    begin
      { if don't have to write anything, fwriter has not been created }
      if not Assigned(fwriter) then
        exit;

      { let all wpo components gather the necessary info from the compiler state }
      for i:=0 to fwpocomponents.count-1 do
        if (TWPOComponentBaseClass(fwpocomponents[i]).generatesinfoforwposwitches*CurrentSettings.GenWPOptimizerSwitches)<>[] then
          begin
            info:=TWPOComponentBaseClass(fwpocomponents[i]).create;
            info.constructfromcompilerstate;
            fwriter.registerwpocomponent(info);
          end;
      { and write their info to disk }
      fwriter.writefile;
      fwriter.free;
      fwriter:=nil;
    end;

  constructor TWPOInfoManagerBase.create;
    begin
      inherited create;
      fwpocomponents:=TFPHashList.create;
    end;

  destructor TWPOInfoManagerBase.Destroy;
    var
      i: TWPOType;
    begin
      freader.free;
      freader:=nil;
      fwriter.free;
      fwriter:=nil;
      fwpocomponents.free;
      fwpocomponents:=nil;
      for i:=low(wpoinfouse) to high(wpoinfouse) do
        if Assigned(wpoinfouse[i]) then
          FreeAndNil(wpoinfouse[i]);
      inherited Destroy;
    end;

  { tcalledvmtentries }

  constructor TCalledVMTEntries.create(_objdef: TDef; nentries: LongInt);
    begin
      objdef:=_objdef;
      calledentries:=TBitSet.create(nentries);
    end;


  constructor TCalledVMTEntries.ppuload(ppufile: TCompilerPPUFile);
    var
      len: LongInt;
    begin
      ppufile.getderef(fobjdefderef);
      len:=ppufile.getlongint;
      calledentries:=TBitSet.Create_ByteSize(len);
      if (len <> calledentries.DataSize) then
        InternalError(2009060301);
      ppufile.readdata(calledentries.data);
    end;


  destructor TCalledVMTEntries.Destroy;
    begin
      fcalledentries.free;
      fcalledentries := nil;
      inherited Destroy;
    end;


  procedure TCalledVMTEntries.ppuwrite(ppufile: TCompilerPPUFile);
    begin
      ppufile.putderef(objdefderef);
      ppufile.putlongint(calledentries.DataSize);
      ppufile.putdata(calledentries.data);
    end;


  procedure TCalledVMTEntries.buildderef;
    begin
      objdefderef.build(objdef);
    end;


  procedure TCalledVMTEntries.buildderefimpl;
    begin
    end;


  procedure TCalledVMTEntries.deref;
    begin
      objdef:=TDef(objdefderef.resolve);
    end;


  procedure TCalledVMTEntries.derefimpl;
    begin
    end;

end.
