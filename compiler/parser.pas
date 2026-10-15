{
    Copyright (c) 1998-2002 by Florian Klaempfl

    This unit does the parsing process

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
unit parser;

{$i fpcdefs.inc}

interface

uses fmodule;

{$ifdef PREPROCWRITE}
    procedure preprocess(const filename:string);
{$endif PREPROCWRITE}
    function compile_module(module : tmodule) : boolean;
    procedure parsing_done(module : tmodule);
    procedure initparser;
    procedure doneparser;

implementation

    uses
{$IFNDEF USE_FAKE_SYSUTILS}
      sysutils,
{$ELSE}
      fksysutl,
{$ENDIF}
      cclasses,
      globtype,tokens,systems,globals,verbose,globstat,
      symbase,symtable,symdef,
      finput,fppu,
      aasmdata,
      cscript,gendef,
      comphook,
      scanner,scandir,
      pbase,psystem,pmodules,psub,ncgrtti,
      cpuinfo,procinfo,assemble;

    procedure parsing_done(module: tmodule);

    var
       hp,hp2 :  tmodule;

    begin
       if module.is_initial then
         DrainClangAssemblerQueue;

       if (module.is_initial) and
          (status.errorcount=0) then
         { Write Browser Collections }
         do_extractsymbolinfo;

       module.end_of_parsing;

       { Restore all locally modified warning messages }
       RestoreLocalVerbosity(CurrentSettings.pmessage);
       current_exceptblock:=0;
       exceptblockcounter:=0;

       { Shut down things when the last file is compiled successful }
       if (module.is_initial) and (module.state=ms_compiled) and
           (status.errorcount=0) then
         begin
           parser_current_file:='';
           { Close script }
           if (not AsmRes.Empty) then
           begin
             Message1(exec_i_closing_script,AsmRes.Fn);
             AsmRes.WriteToDisk;
           end;
         end;

     { free now what we did not free earlier in
       proc_program PM }
     if (module.is_initial) and (module.state=ms_compiled) and needsymbolinfo then
       begin
         hp:=tmodule(loaded_units.first);
         while assigned(hp) do
          begin
            hp2:=tmodule(hp.next);
            if (hp<>module) then
              begin
                loaded_units.remove(hp);
                hp.free;
                hp := nil;
              end;
            hp:=hp2;
          end;
         { free also unneeded units we didn't free before }
         unloaded_units.Clear;
        end;

      { If used units are compiled current_module is already the same as
        the stored module. Now if the unit is not finished its scanner is
        not yet freed and thus set_current_module would reopen the scanned
        file which will result in pointing to the wrong position in the
        file. In the normal case current_scanner and current_module.scanner
        would be Nil, thus nothing bad would happen }
{           if olddata.old_current_module<>current_module then
        set_current_module(olddata.old_current_module);}

      FreeLocalVerbosity(CurrentSettings.pmessage);

    end;

    procedure initparser;
      begin
         { Current compiled module/proc }
         SetCurrentModule(nil);
         CurrentAsmData:=nil;
         CurrentProcInfo:=nil;
         CurrentStructDef:=nil;
         CurrentGenericDef:=nil;
         CurrentSpecializeDef:=nil;

         loaded_units:=TLinkedList.Create;

         usedunits:=TLinkedList.Create;

         unloaded_units:=TLinkedList.Create;

         { global switches }
         CurrentSettings.globalswitches:=InitSettings.globalswitches;

         CurrentSettings.sourcecodepage:=InitSettings.sourcecodepage;

         { initialize scanner }
         InitScanner;
         InitScannerDirectives;

         { scanner }
         set_current_scanner(nil);
         switchesstatestackpos:=0;

         { register all nodes and tais }
         registernodes;
         registertais;

         { memory sizes }
         if stacksize=0 then
           stacksize:=TargetInfo.stacksize;

         { RTTI writer }
         RTTIWriter:=TRTTIWriter.Create;

         { open assembler response }
         if cs_link_on_target in CurrentSettings.globalswitches then
           GenerateAsmRes(outputexedir+ChangeFileExt(inputfilename,'_ppas'))
         else
           GenerateAsmRes(outputexedir+'ppas');

         { open deffile }
         DefFile:=TDefFile.Create(outputexedir+ChangeFileExt(inputfilename,TargetInfo.defext));

         { list of generated .o files, so the linker can remove them }
         SmartLinkOFiles:=TCmdStrList.Create;

         { codegen }
         if paraprintnodetree<>0 then
           printnode_reset;

      end;


    procedure doneparser;
      begin
         { Reset current compiling info, so destroy routines can't
           reference the data that might already be destroyed }
         SetCurrentModule(nil);
         CurrentProcInfo:=nil;
         CurrentAsmData:=nil;
         CurrentStructDef:=nil;
         CurrentGenericDef:=nil;
         CurrentSpecializeDef:=nil;

         { unload units }
         if assigned(loaded_units) then
           begin
             loaded_units.free;
             loaded_units:=nil;
           end;
         if assigned(usedunits) then
           begin
             usedunits.free;
             usedunits:=nil;
           end;
         if assigned(unloaded_units) then
           begin
             unloaded_units.free;
             unloaded_units:=nil;
           end;
         { Set default types to nil. At this point they are not valid class pointers. }
         reset_all_default_types;

         { if there was an error in the scanner, the scanner is
           still assigned }
         if assigned(CurrentScanner) then
          begin
            CurrentScanner.free; // no nil needed
            set_current_scanner(nil);
          end;

         { close scanner }
         DoneScanner;

         RTTIWriter.free;
         RTTIWriter := nil;

         { close ppas,deffile }
         asmres.free;
         asmres := nil;
         deffile.free;
         deffile := nil;

         { free list of .o files }
         SmartLinkOFiles.Free;
         SmartLinkOFiles := nil;
      end;




{$ifdef PREPROCWRITE}
    procedure preprocess(const filename:string);
      var
        i : longint;
      begin
         preprocfile:=tpreprocfile.create('pre_'+filename);
       { initialize a module }
         SetCurrentModule(tppumodule.create(nil,'',filename,false));
         macrosymtablestack:=TSymTableStack.create;


         set_current_scanner(tscannerfile.Create(filename));
         CurrentScanner.firstfile;
         CurrentModule.scanner:=CurrentScanner;

         { init macros before anything in the file is parsed.}
         CurrentModule.localmacrosymtable:= TMacroSymTable.create(false);
         macrosymtablestack.push(initialmacrosymtable);
         macrosymtablestack.push(CurrentModule.localmacrosymtable);

         { read the first token }
         // current_scanner.readtoken(false);

         main_module:=CurrentModule;
         repeat
           CurrentScanner.readtoken(true);
           preprocfile.AddSpace;
           case CurrentScanner.token of
             _ID :
               begin
                 preprocfile.Add(CurrentScanner.orgpattern);
               end;
             _REALNUMBER,
             _INTCONST :
               preprocfile.Add(CurrentScanner.pattern);
             _CSTRING :
               begin
                 i:=0;
                 while (i<length(CurrentScanner.cstringpattern)) do
                  begin
                    inc(i);
                    if CurrentScanner.cstringpattern[i]='''' then
                     begin
                       insert('''',CurrentScanner.cstringpattern,i);
                       inc(i);
                     end;
                  end;
                 preprocfile.Add(''''+CurrentScanner.cstringpattern+'''');
               end;
             _CCHAR :
               begin
                 case CurrentScanner.pattern[1] of
                   #39 :
                     CurrentScanner.pattern:='''''''';
                   #0..#31,
                   #128..#255 :
                     begin
                       str(ord(CurrentScanner.pattern[1]),CurrentScanner.pattern);
                       CurrentScanner.pattern:='#'+CurrentScanner.pattern;
                     end;
                   else
                     CurrentScanner.pattern:=''''+CurrentScanner.pattern[1]+'''';
                 end;
                 preprocfile.Add(CurrentScanner.pattern);
               end;
             _EOF :
               break;
             else
               preprocfile.Add(tokeninfo^[CurrentScanner.token].str)
           end;
         until false;
       { free scanner }
         CurrentScanner.free;
         set_current_scanner(nil);
       { close }
         preprocfile.free;
         preprocfile := nil;
      end;
{$endif PREPROCWRITE}


{*****************************************************************************
                             Compile a source file
*****************************************************************************}

    function compile_module(module : tmodule) : boolean;

      var
         finished : boolean;
         sc : tscannerfile;

       begin
         Result:=True;

         { parsing a procedure or declaration should be finished }
         if assigned(CurrentProcInfo) then
           internalerror(200811121);
         if assigned(CurrentStructDef) then
           internalerror(200811122);
         inc(module.compilecount);
         parser_current_file:=module.mainsource;

       { reset parser, a previous fatal error could have left these variables in an unreliable state, this is
         important for the IDE }
         afterassignment:=false;
         in_args:=false;
         named_args_allowed:=false;
         got_addrn:=false;
         getprocvardef:=nil;
         getfuncrefdef:=nil;

       { show info }
         Message1(parser_i_compiling,module.mainsource);

       { reset symtable }
         symtablestack:=TDefAwareSymTableStack.create;
         macrosymtablestack:=TSymTableStack.create;
         systemunit:=nil;
         CurrentSettings.defproccall:=InitSettings.defproccall;
         current_exceptblock:=0;
         exceptblockcounter:=0;
         CurrentSettings.maxfpuregisters:=-1;
         CurrentSettings.pmessage:=nil;

         { Load current state from the init values }
         CurrentSettings:=InitSettings;

         SetCurrentModule(module);
         if not (module.state in [ms_compile]) then
           internalerror(200212281);

         { load current asmdata from current_module }
         CurrentAsmData:=TAsmData(module.asmdata);

         { startup scanner and load the first file }
         sc:=tscannerfile.Create(module.mainsource);
         sc.firstfile;
         module.scanner:=sc;
         module.mainscanner:=sc;
         set_current_scanner(sc);

         { init macros before anything in the file is parsed.}
         module.localmacrosymtable:= TMacroSymTable.create(false);
         macrosymtablestack.push(initialmacrosymtable);
         macrosymtablestack.push(module.localmacrosymtable);

         { read the first token }
         CurrentScanner.readtoken(false);

         { this is set to false if a unit needs to wait for other units }
         finished:=true;

         { If the compile level > 1 we get a nice "unit expected" error
           message if we are trying to use a program as unit.}
         try
           if (CurrentScanner.token=_UNIT) or (not module.is_initial) then
             begin
               module.is_unit:=true;
               finished:=proc_unit(module);
             end
           else if (CurrentScanner.token=_ID) and (CurrentScanner.idtoken=_PACKAGE) then
             begin
               module.IsPackage:=true;
               finished:=proc_package(module);
             end
           else
             finished:=proc_program(module,CurrentScanner.token=_LIBRARY);
         except
           on ECompilerAbort do
             raise;
           on Exception do
             begin
               { Generate exception_raised message,
                 but avoid multiple messages by
                 guarding with exception_raised global variable }
               if not exception_raised then
                 begin
                   exception_raised:=true;
                   Message(general_e_exception_raised);
                 end;
               raise;
             end;
         end;
         Result:=Finished;
    end;

end.
