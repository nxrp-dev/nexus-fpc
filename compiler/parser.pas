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

    function CompileModule(AModule : TModule) : Boolean;
    procedure ParsingDone(AModule : TModule);
    procedure InitParser;
    procedure DoneParser;

implementation

    uses
      SysUtils,
      CClasses,
      GlobType,tokens,Systems,Globals,Verbose,GlobStat,
      SymBase,SymTable,symdef,
      FinPut,FPPU,
      AAsmData,
      CScript,gendef,
      CompHook,
      Scanner,ScanDir,
      pbase,psystem,pmodules,psub,ncgrtti,
      CPUInfo,ProcInfo;

    procedure ParsingDone(AModule: TModule);

    var
       lModule,lNextModule :  TModule;

    begin
       if (AModule.IsInitial) and
          (status.ErrorCount=0) then
         { Write Browser Collections }
         Do_ExtractSymbolInfo;

       AModule.End_Of_Parsing;

       { Restore all locally modified warning messages }
       RestoreLocalVerbosity(CurrentSettings.PMessage);
       Current_ExceptBlock:=0;
       ExceptBlockCounter:=0;

       { Shut down things when the last file is compiled successful }
       if (AModule.IsInitial) and (AModule.state=ms_compiled) and
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
     if (AModule.IsInitial) and (AModule.state=ms_compiled) and NeedSymbolInfo then
       begin
         lModule:=TModule(Loaded_Units.first);
         while Assigned(lModule) do
          begin
            lNextModule:=TModule(lModule.next);
            if (lModule<>AModule) then
              begin
                Loaded_Units.remove(lModule);
                lModule.free;
                lModule := nil;
              end;
            lModule:=lNextModule;
          end;
         { free also unneeded units we didn't free before }
         Unloaded_Units.Clear;
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

    procedure InitParser;
      begin
         { Current compiled module/proc }
         SetCurrentModule(nil);
         CurrentAsmData:=nil;
         CurrentProcInfo:=nil;
         CurrentStructDef:=nil;
         CurrentGenericDef:=nil;
         CurrentSpecializeDef:=nil;

         Loaded_Units:=TLinkedList.Create;

         UsedUnits:=TLinkedList.Create;

         Unloaded_Units:=TLinkedList.Create;

         { global switches }
         CurrentSettings.GlobalSwitches:=InitSettings.GlobalSwitches;

         CurrentSettings.SourceCodePage:=InitSettings.SourceCodePage;

         { initialize scanner }
         InitScanner;
         InitScannerDirectives;

         { scanner }
         SetCurrentScanner(nil);
         SwitchesStateStackPos:=0;

         { register all nodes and tais }
         RegisterNodes;
         RegisterTAIs;

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
           PrintNode_Reset;

      end;


    procedure DoneParser;
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
         if Assigned(Loaded_Units) then
           begin
             Loaded_Units.free;
             Loaded_Units:=nil;
           end;
         if Assigned(UsedUnits) then
           begin
             UsedUnits.free;
             UsedUnits:=nil;
           end;
         if Assigned(Unloaded_Units) then
           begin
             Unloaded_Units.free;
             Unloaded_Units:=nil;
           end;
         { Set default types to nil. At this point they are not valid class pointers. }
         Reset_All_Default_Types;

         { if there was an error in the scanner, the scanner is
           still assigned }
         if Assigned(CurrentScanner) then
          begin
            CurrentScanner.free; // no nil needed
            SetCurrentScanner(nil);
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


{*****************************************************************************
                             Compile a source file
*****************************************************************************}

    function CompileModule(AModule : TModule) : Boolean;

      var
         lFinished : Boolean;
         lScanner : TScannerFile;

       begin
         Result:=True;

         { parsing a procedure or declaration should be finished }
         if Assigned(CurrentProcInfo) then
           InternalError(200811121);
         if Assigned(CurrentStructDef) then
           InternalError(200811122);
         inc(AModule.CompileCount);
         Parser_Current_File:=AModule.MainSource;

       { reset parser, a previous fatal error could have left these variables in an unreliable state, this is
         important for the IDE }
         AfterAssignment:=false;
         InArgs:=false;
         NamedArgsAllowed:=false;
         GotAddrN:=false;
         GetProcVarDef:=nil;
         GetFuncRefDef:=nil;

       { show info }
         Message1(parser_i_compiling,AModule.MainSource);

       { reset symtable }
         SymTableStack:=TDefAwareSymTableStack.Create;
         MacroSymTableStack:=TSymTableStack.Create;
         SystemUnit:=nil;
         CurrentSettings.DefProcCall:=InitSettings.DefProcCall;
         Current_ExceptBlock:=0;
         ExceptBlockCounter:=0;
         CurrentSettings.MaxFPURegisters:=-1;
         CurrentSettings.PMessage:=nil;

         { Load current state from the init values }
         CurrentSettings:=InitSettings;

         SetCurrentModule(AModule);
         if not (AModule.state in [ms_compile]) then
           InternalError(200212281);

         { load current asmdata from current_module }
         CurrentAsmData:=TAsmData(AModule.AsmData);

         { startup scanner and load the first file }
         lScanner:=TScannerFile.Create(AModule.MainSource);
         lScanner.FirstFile;
         AModule.Scanner:=lScanner;
         AModule.MainScanner:=lScanner;
         SetCurrentScanner(lScanner);

         { init macros before anything in the file is parsed.}
         AModule.LocalMacroSymTable:= TMacroSymTable.Create(false);
         MacroSymTableStack.push(InitialMacroSymTable);
         MacroSymTableStack.push(AModule.LocalMacroSymTable);

         { read the first token }
         CurrentScanner.ReadToken(false);

         { this is set to false if a unit needs to wait for other units }
         lFinished:=true;

         { If the compile level > 1 we get a nice "unit expected" error
           message if we are trying to use a program as unit.}
         try
           if (CurrentScanner.FToken=_UNIT) or (not AModule.IsInitial) then
             begin
               AModule.IsUnit:=true;
               lFinished:=ProcUnit(AModule);
             end
           else if (CurrentScanner.FToken=_ID) and (CurrentScanner.FIDToken=_PACKAGE) then
             begin
               AModule.IsPackage:=true;
               lFinished:=ProcPackage(AModule);
             end
           else
             lFinished:=ProcProgram(AModule,CurrentScanner.FToken=_LIBRARY);
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
         Result:=lFinished;
    end;

end.
