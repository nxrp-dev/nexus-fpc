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

uses FModule;

{$ifdef PREPROCWRITE}
    procedure preprocess(const FileName:string);
{$endif PREPROCWRITE}
    function compile_module(module : TModule) : boolean;
    procedure parsing_done(module : TModule);
    procedure initparser;
    procedure doneparser;

implementation

    uses
{$IFNDEF USE_FAKE_SYSUTILS}
      SysUtils,
{$ELSE}
      FKSysUtl,
{$ENDIF}
      CClasses,
      GlobType,tokens,Systems,Globals,Verbose,GlobStat,
      SymBase,SymTable,symdef,
      FinPut,fppu,
      AAsmData,
      CScript,gendef,
      CompHook,
      Scanner,ScanDir,
      pbase,psystem,pmodules,psub,ncgrtti,
      CPUInfo,ProcInfo,assemble;

    procedure parsing_done(module: TModule);

    var
       hp,hp2 :  TModule;

    begin
       if module.IsInitial then
         DrainClangAssemblerQueue;

       if (module.IsInitial) and
          (status.ErrorCount=0) then
         { Write Browser Collections }
         Do_ExtractSymbolInfo;

       module.end_of_parsing;

       { Restore all locally modified warning messages }
       RestoreLocalVerbosity(CurrentSettings.PMessage);
       Current_ExceptBlock:=0;
       ExceptBlockCounter:=0;

       { Shut down things when the last file is compiled successful }
       if (module.IsInitial) and (module.state=ms_compiled) and
           (status.ErrorCount=0) then
         begin
           Parser_Current_File:='';
           { Close script }
           if (not AsmRes.Empty) then
           begin
             Message1(exec_i_closing_script,AsmRes.Fn);
             AsmRes.WriteToDisk;
           end;
         end;

     { free now what we did not free earlier in
       proc_program PM }
     if (module.IsInitial) and (module.state=ms_compiled) and NeedSymbolInfo then
       begin
         hp:=TModule(loaded_units.first);
         while Assigned(hp) do
          begin
            hp2:=TModule(hp.next);
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

      FreeLocalVerbosity(CurrentSettings.PMessage);

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
         CurrentSettings.GlobalSwitches:=InitSettings.GlobalSwitches;

         CurrentSettings.SourceCodePage:=InitSettings.SourceCodePage;

         { initialize scanner }
         InitScanner;
         InitScannerDirectives;

         { scanner }
         Set_Current_Scanner(nil);
         SwitchesStateStackPos:=0;

         { register all nodes and tais }
         registernodes;
         registertais;

         { memory sizes }
         if StackSize=0 then
           StackSize:=TargetInfo.StackSize;

         { RTTI writer }
         RTTIWriter:=TRTTIWriter.Create;

         { open assembler response }
         if cs_link_on_target in CurrentSettings.GlobalSwitches then
           GenerateAsmRes(OutputExeDir+ChangeFileExt(InputFileName,'_ppas'))
         else
           GenerateAsmRes(OutputExeDir+'ppas');

         { open deffile }
         DefFile:=TDefFile.Create(OutputExeDir+ChangeFileExt(InputFileName,TargetInfo.defext));

         { list of generated .o files, so the linker can remove them }
         SmartLinkOFiles:=TCmdStrList.Create;

         { codegen }
         if ParaPrintNodeTree<>0 then
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
         if Assigned(loaded_units) then
           begin
             loaded_units.free;
             loaded_units:=nil;
           end;
         if Assigned(usedunits) then
           begin
             usedunits.free;
             usedunits:=nil;
           end;
         if Assigned(unloaded_units) then
           begin
             unloaded_units.free;
             unloaded_units:=nil;
           end;
         { Set default types to nil. At this point they are not valid class pointers. }
         reset_all_default_types;

         { if there was an error in the scanner, the scanner is
           still assigned }
         if Assigned(CurrentScanner) then
          begin
            CurrentScanner.free; // no nil needed
            Set_Current_Scanner(nil);
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
    procedure preprocess(const FileName:string);
      var
        i : LongInt;
      begin
         preprocfile:=TPreProcFile.create('pre_'+FileName);
       { initialize a module }
         SetCurrentModule(TPPUModule.create(nil,'',FileName,false));
         MacroSymTableStack:=TSymTableStack.create;


         Set_Current_Scanner(TScannerFile.Create(FileName));
         CurrentScanner.firstfile;
         CurrentModule.Scanner:=CurrentScanner;

         { init macros before anything in the file is parsed.}
         CurrentModule.localmacrosymtable:= TMacroSymTable.create(false);
         MacroSymTableStack.push(initialmacrosymtable);
         MacroSymTableStack.push(CurrentModule.localmacrosymtable);

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
         Set_Current_Scanner(nil);
       { close }
         preprocfile.free;
         preprocfile := nil;
      end;
{$endif PREPROCWRITE}


{*****************************************************************************
                             Compile a source file
*****************************************************************************}

    function compile_module(module : TModule) : boolean;

      var
         finished : boolean;
         sc : TScannerFile;

       begin
         Result:=True;

         { parsing a procedure or declaration should be finished }
         if Assigned(CurrentProcInfo) then
           InternalError(200811121);
         if Assigned(CurrentStructDef) then
           InternalError(200811122);
         inc(module.compilecount);
         Parser_Current_File:=module.MainSource;

       { reset parser, a previous fatal error could have left these variables in an unreliable state, this is
         important for the IDE }
         afterassignment:=false;
         in_args:=false;
         named_args_allowed:=false;
         got_addrn:=false;
         getprocvardef:=nil;
         getfuncrefdef:=nil;

       { show info }
         Message1(parser_i_compiling,module.MainSource);

       { reset symtable }
         SymTableStack:=TDefAwareSymTableStack.create;
         MacroSymTableStack:=TSymTableStack.create;
         systemunit:=nil;
         CurrentSettings.DefProcCall:=InitSettings.DefProcCall;
         Current_ExceptBlock:=0;
         ExceptBlockCounter:=0;
         CurrentSettings.MaxFPURegisters:=-1;
         CurrentSettings.PMessage:=nil;

         { Load current state from the init values }
         CurrentSettings:=InitSettings;

         SetCurrentModule(module);
         if not (module.state in [ms_compile]) then
           InternalError(200212281);

         { load current asmdata from current_module }
         CurrentAsmData:=TAsmData(module.asmdata);

         { startup scanner and load the first file }
         sc:=TScannerFile.Create(module.MainSource);
         sc.firstfile;
         module.Scanner:=sc;
         module.mainscanner:=sc;
         Set_Current_Scanner(sc);

         { init macros before anything in the file is parsed.}
         module.localmacrosymtable:= TMacroSymTable.create(false);
         MacroSymTableStack.push(initialmacrosymtable);
         MacroSymTableStack.push(module.localmacrosymtable);

         { read the first token }
         CurrentScanner.readtoken(false);

         { this is set to false if a unit needs to wait for other units }
         finished:=true;

         { If the compile level > 1 we get a nice "unit expected" error
           message if we are trying to use a program as unit.}
         try
           if (CurrentScanner.token=_UNIT) or (not module.IsInitial) then
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
               if not Exception_Raised then
                 begin
                   Exception_Raised:=true;
                   Message(general_e_exception_raised);
                 end;
               raise;
             end;
         end;
         Result:=Finished;
    end;

end.
