{
    Copyright (c) 1998-2004 by Peter Vreman

    This unit handles the assemblerfile write and assembler calls of FPC

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
{# @abstract(This unit handles the assembler file write and assembler calls of FPC)
   Handles the calls to the actual external assemblers, as well as the generation
   of object files for smart linking. Also contains the base class for writing
   the assembler statements to file.
}
unit assemble;

{$i fpcdefs.inc}

interface


    uses
      TPCompilerReal,
      SysUtils,
      Systems,GlobType,Globals,aasmbase,aasmtai,AAsmData,ogbase,owbase,FinPut;

    const
       { maximum of aasmoutput lists there will be }
       maxoutputlists = ord(high(TAsmListType))+1;
       { buffer size for writing the .s file }
       AsmOutSize=32768*4;

    type
      TAssembler=class(TObject)
      public
      {assembler info}
        asminfo     : PAsmInfo;
      {filenames}
        path        : TPathStr;
        name        : string;
        AsmFileName,         { current .s and .o file }
        ObjFileName,
        PPUFileName  : TPathStr;
        asmprefix    : string;
        SmartAsm     : boolean;
        SmartFilesCount,
        SmartHeaderCount : LongInt;
        Constructor Create(info: PAsmInfo; smart:boolean);virtual;
        Destructor Destroy;override;
        procedure NextSmartName(place:TCutPlace);
        procedure MakeObject;virtual;abstract;
      end;

      TExternalAssembler = class;

      IExternalAssemblerOutputFileDecorator=interface
        function LinePrefix: AnsiString;
        function LinePostfix: AnsiString;
        function LineFilter(const s: AnsiString): AnsiString;
        function LineEnding(const deflineending: ShortString): ShortString;
      end;

      TExternalAssemblerOutputFile=class
      private
        fdecorator: IExternalAssemblerOutputFileDecorator;
      protected
        owner: TExternalAssembler;
      {outfile}
        AsmSize,
        AsmStartSize,
        outcnt   : LongInt;
        outbuf   : array[0..AsmOutSize-1] of char;
        outfile  : file;
        fioerror : boolean;
        linestart: boolean;

        Procedure AsmClear;
        Procedure MaybeAddLinePrefix;
        Procedure MaybeAddLinePostfix;

        Procedure AsmWriteAnsiStringUnfiltered(const s: AnsiString);
      public
        Constructor Create(_owner: TExternalAssembler);

        Procedure RemoveAsm;virtual;
        Procedure AsmFlush;

        { mark the current output as the "empty" state (i.e., it only contains
          headers/directives etc }
        Procedure MarkEmpty;
        { clears the assembler output if nothing was added since it was marked
          as empty, and returns whether it was empty }
        function ClearIfEmpty: boolean;
        { these routines will write the filtered version of their argument
          according to the current decorator }
        procedure AsmWriteFiltered(const c:char);
        procedure AsmWriteFiltered(const s:ShortString);
        procedure AsmWriteFiltered(const s:AnsiString);
        procedure AsmWriteFiltered(p:pchar; len: LongInt);

        {# Write a string to the assembler file }
        Procedure AsmWrite(const c:char);
        Procedure AsmWrite(const s:ShortString);
        Procedure AsmWrite(const s:AnsiString);

        {# Write a string to the assembler file }
        Procedure AsmWritePChar(p:pchar);

        {# Write a string to the assembler file followed by a new line }
        Procedure AsmWriteLn(const c:char);
        Procedure AsmWriteLn(const s:ShortString);
        Procedure AsmWriteLn(const s:AnsiString);

        {# Write a new line to the assembler file }
        Procedure AsmLn; virtual;

        procedure AsmCreate(Aplace:TCutPlace);
        procedure AsmClose;

        property ioerror: boolean read fioerror;
        property decorator: IExternalAssemblerOutputFileDecorator read fdecorator write fdecorator;
      end;

      {# This is the base class which should be overridden for each each
         assembler writer. It is used to actually assembler a file,
         and write the output to the assembler file.
      }
      TExternalAssembler=class(TAssembler)
      private
       { output writer }
        fwriter: TExternalAssemblerOutputFile;
        ffreewriter: boolean;

        procedure CreateSmartLinkPath(const s:TPathStr);
      protected
      {input source info}
        lastfileinfo : TFilePosInfo;
        infile,
        lastinfile   : TInputFile;
      {last section type written}
        lastsectype : TAsmSectiontype;
        procedure ResetSourceLines;
        procedure WriteSourceLine(hp: TAILineInfo);
        procedure WriteTempalloc(hp: TAITempAlloc);
        procedure WriteRealConstAsBytes(hp: TAIRealConst; const dbdir: string; do_line: boolean);
        function WriteComments(var hp: TAI): boolean;
        function single2str(d : single) : string; virtual;
        function double2str(d : double) : string; virtual;
        function sleb128tostr(a : int64) : string;
        function uleb128tostr(a : qword) : string;
        Function DoPipe:boolean; virtual;

        function CreateNewAsmWriter: TExternalAssemblerOutputFile; virtual;

        {# Return true if the external assembler should run again }
        function RerunAssembler: boolean; virtual;
      public

        {# Returns the complete path and executable name of the assembler
           program.

           It first tries looking in the UTIL directory if specified,
           otherwise it searches in the free pascal binary directory, in
           the current working directory and then in the  directories
           in the $PATH environment.}
        Function  FindAssembler:string;

        {# Actually does the call to the assembler file. Returns false
           if the assembling of the file failed.}
        Function  CallAssembler(const command:string; const para:TCmdStr):Boolean;

        Function  DoAssemble:boolean;virtual;

        {# This routine should be overridden for each assembler, it is used
           to actually write the abstract assembler stream to file.}
        procedure WriteTree(p:TAsmList);virtual;

        {# This routine should be overridden for each assembler, it is used
           to actually write all the different abstract assembler streams
           by calling for each stream type, the @var(WriteTree) method.}
        procedure WriteAsmList;virtual;

        {# Constructs the command line for calling the assembler }
        function MakeCmdLine: TCmdStr; virtual;
      public
        Constructor Create(info: PAsmInfo; smart: boolean); override; final;
        Constructor CreateWithWriter(info: PAsmInfo; wr: TExternalAssemblerOutputFile; freewriter, smart: boolean); virtual;
        procedure MakeObject;override;
        destructor Destroy; override;

        property writer: TExternalAssemblerOutputFile read fwriter;
      end;
      TExternalAssemblerClass = class of TExternalAssembler;

      { TInternalAssembler }

      TInternalAssembler=class(TAssembler)
      private
        FCObjOutput : TObjOutputClass;
        FCInternalAr : TObjectWriterClass;
        { the aasmoutput lists that need to be processed }
        lists        : byte;
        list         : array[1..maxoutputlists] of TAsmList;
        { current processing }
        currlistidx  : byte;
        currlist     : TAsmList;
        function  MaybeNextList(var hp:TAI):boolean;
        function  SetIndirectToSymbol(hp: TAI; const indirectname: string): Boolean;
        function  TreePass0(hp:TAI):TAI;
        function  TreePass1(hp:TAI):TAI;
        function  TreePass2(hp:TAI):TAI;
        procedure writetree;
        procedure writetreesmart;
      protected
        ObjData   : TObjData;
        ObjOutput : TObjOutput;
        property CObjOutput:TObjOutputClass read FCObjOutput write FCObjOutput;
        property CInternalAr : TObjectWriterClass read FCInternalAr write FCInternalAr;
      public
        constructor Create(info: PAsmInfo; smart: boolean);override;
        destructor  Destroy;override;
        procedure MakeObject;override;
      end;

    TAssemblerClass = class of TAssembler;

    Procedure GenerateAsm(smart:boolean);

    { get an instance of an external GNU-style assembler that is compatible
      with the current target, reusing an existing writer. Used by the LLVM
      target to write inline assembler }
    function GetExternalGnuAssemblerWithAsmInfoWriter(info: PAsmInfo; wr: TExternalAssemblerOutputFile): TExternalAssembler;

    function DrainClangAssemblerQueue: Boolean;

    procedure RegisterAssembler(const r:TAsmInfo;c:TAssemblerClass);


Implementation

    uses
{$ifdef hasunix}
      unix,
{$endif}
      CUtils,CFileUtl,CompHook,nxclangassembler,
{$ifdef memdebug}
      CClasses,
{$endif memdebug}

      CScript,FModule,Verbose,
      cpubase,CPUInfo,Triplet,
      aasmcpu;

    var
      CAssembler : array[TAsm] of TAssemblerClass;
      ClangAssemblerFailureReported: Boolean;

    function fixline(const s:string):string;
     {
       return s with all leading and ending spaces and tabs removed
     }
      var
        i,j,k : integer;
      begin
        i:=length(s);
        while (i>0) and (s[i] in [#9,' ']) do
          dec(i);
        j:=1;
        while (j<i) and (s[j] in [#9,' ']) do
          inc(j);
        result := Copy(s, j, i - j + 1);
        for k:=1 to length(result) do
          if result[k] in [#0..#31,#127..#255] then
            result[k]:='.';
      end;

{*****************************************************************************
                                   TAssembler
*****************************************************************************}

    Constructor TAssembler.Create(info: PAsmInfo; smart: boolean);
      begin
        asminfo:=info;
      { load start values }
        AsmFileName:=CurrentModule.AsmFileName;
        ObjFileName:=CurrentModule.ObjFileName;
        name:=Lower(CurrentModule.ModuleName^);
        path:=CurrentModule.OutputPath;
        asmprefix := CurrentModule.asmprefix^;
        if CurrentModule.OutputPath = '' then
          PPUFileName := ''
        else
          PPUFileName := CurrentModule.PPUFileName;
        SmartAsm:=smart;
        SmartFilesCount:=0;
        SmartHeaderCount:=0;
        SmartLinkOFiles.Clear;
      end;


    Destructor TAssembler.Destroy;
      begin
      end;


    procedure TAssembler.NextSmartName(place:TCutPlace);
      var
        s : string;
      begin
        inc(SmartFilesCount);
        if SmartFilesCount>999999 then
         Message(asmw_f_too_many_asm_files);
        case place of
          cut_begin :
            begin
              inc(SmartHeaderCount);
              s:=asmprefix+ToStr(SmartHeaderCount)+'h';
            end;
          cut_normal :
            s:=asmprefix+ToStr(SmartHeaderCount)+'s';
          cut_end :
            s:=asmprefix+ToStr(SmartHeaderCount)+'t';
        end;
        AsmFileName:=Path+FixFileName(s+ToStr(SmartFilesCount)+TargetInfo.asmext);
        ObjFileName:=Path+FixFileName(s+ToStr(SmartFilesCount)+TargetInfo.objext);
        { insert in container so it can be cleared after the linking }
        SmartLinkOFiles.Insert(ObjFileName);
      end;




{*****************************************************************************
                                 TAssemblerOutputFile
*****************************************************************************}

    procedure TExternalAssemblerOutputFile.RemoveAsm;
      var
        g : file;
      begin
        if cs_asm_leave in CurrentSettings.GlobalSwitches then
         exit;
        if cs_asm_extern in CurrentSettings.GlobalSwitches then
         AsmRes.AddDeleteCommand(owner.AsmFileName)
        else
         begin
           assign(g,owner.AsmFileName);
           {$push} {$I-}
            erase(g);
           {$pop}
           if IOResult<>0 then;
         end;
      end;


    Procedure TExternalAssemblerOutputFile.AsmFlush;
      begin
        if outcnt>0 then
         begin
           { suppress i/o error }
           {$push} {$I-}
           BlockWrite(outfile,outbuf,outcnt);
           {$pop}
           fioerror:=fioerror or (IOResult<>0);
           outcnt:=0;
         end;
      end;

    procedure TExternalAssemblerOutputFile.MarkEmpty;
      begin
        AsmStartSize:=AsmSize
      end;


    function TExternalAssemblerOutputFile.ClearIfEmpty: boolean;
      begin
        result:=AsmSize=AsmStartSize;
        if result then
         AsmClear;
      end;


    procedure TExternalAssemblerOutputFile.AsmWriteFiltered(const c: char);
      begin
        MaybeAddLinePrefix;
        AsmWriteAnsiStringUnfiltered(decorator.LineFilter(c));
      end;


    procedure TExternalAssemblerOutputFile.AsmWriteFiltered(const s: ShortString);
      begin
        MaybeAddLinePrefix;
        AsmWriteAnsiStringUnfiltered(decorator.LineFilter(s));
      end;


    procedure TExternalAssemblerOutputFile.AsmWriteFiltered(const s: AnsiString);
      begin
        MaybeAddLinePrefix;
        AsmWriteAnsiStringUnfiltered(decorator.LineFilter(s));
      end;


    procedure TExternalAssemblerOutputFile.AsmWriteFiltered(p: pchar; len: LongInt);
      var
        s: AnsiString;
      begin
        MaybeAddLinePrefix;
        s:='';
        SetLength(s,len);
        move(p^,s[1],len);
        AsmWriteAnsiStringUnfiltered(decorator.LineFilter(s));
      end;


    Procedure TExternalAssemblerOutputFile.AsmClear;
      begin
        outcnt:=0;
      end;


    procedure TExternalAssemblerOutputFile.MaybeAddLinePrefix;
      begin
        if Assigned(decorator) and
           linestart then
          begin
            AsmWriteAnsiStringUnfiltered(decorator.LinePrefix);
            linestart:=false;
          end;
      end;


    procedure TExternalAssemblerOutputFile.MaybeAddLinePostfix;
      begin
        if Assigned(decorator) and
           not linestart then
          begin
            AsmWriteAnsiStringUnfiltered(decorator.LinePostfix);
            linestart:=true;
          end;
      end;


    procedure TExternalAssemblerOutputFile.AsmWriteAnsiStringUnfiltered(const s: AnsiString);
      var
        StartIndex, ToWrite: LongInt;
      begin
        if s='' then
          exit;
        if OutCnt+length(s)>=AsmOutSize then
         AsmFlush;
        StartIndex:=1;
        ToWrite:=length(s);
        while ToWrite>AsmOutSize do
          begin
            Move(s[StartIndex],OutBuf[OutCnt],AsmOutSize);
            inc(OutCnt,AsmOutSize);
            inc(AsmSize,AsmOutSize);
            AsmFlush;
            inc(StartIndex,AsmOutSize);
            dec(ToWrite,AsmOutSize);
          end;
        Move(s[StartIndex],OutBuf[OutCnt],ToWrite);
        inc(OutCnt,ToWrite);
        inc(AsmSize,ToWrite);
      end;


    constructor TExternalAssemblerOutputFile.Create(_owner: TExternalAssembler);
      begin
        owner:=_owner;
        linestart:=true;
      end;


    Procedure TExternalAssemblerOutputFile.AsmWrite(const c: char);
      begin
        if Assigned(decorator) then
          AsmWriteFiltered(c)
        else
          begin
            if OutCnt+1>=AsmOutSize then
             AsmFlush;
            OutBuf[OutCnt]:=c;
            inc(OutCnt);
            inc(AsmSize);
          end;
      end;


    Procedure TExternalAssemblerOutputFile.AsmWrite(const s:ShortString);
      begin
        if s='' then
          exit;
        if Assigned(decorator) then
          AsmWriteFiltered(s)
        else
          begin
            if OutCnt+length(s)>=AsmOutSize then
             AsmFlush;
            Move(s[1],OutBuf[OutCnt],length(s));
            inc(OutCnt,length(s));
            inc(AsmSize,length(s));
          end;
      end;


    Procedure TExternalAssemblerOutputFile.AsmWrite(const s:AnsiString);
      begin
        if s='' then
          exit;
        if Assigned(decorator) then
          AsmWriteFiltered(s)
        else
         AsmWriteAnsiStringUnfiltered(s);
      end;


    procedure TExternalAssemblerOutputFile.AsmWriteLn(const c: char);
      begin
        AsmWrite(c);
        AsmLn;
      end;


    Procedure TExternalAssemblerOutputFile.AsmWriteLn(const s:ShortString);
      begin
        AsmWrite(s);
        AsmLn;
      end;


    Procedure TExternalAssemblerOutputFile.AsmWriteLn(const s: AnsiString);
      begin
        AsmWrite(s);
        AsmLn;
      end;


    Procedure TExternalAssemblerOutputFile.AsmWritePChar(p:pchar);
      var
        i,j : LongInt;
      begin
        i:=StrLen(p);
        if i=0 then
          exit;
        if Assigned(decorator) then
          AsmWriteFiltered(p,i)
        else
          begin
            j:=i;
            while j>0 do
             begin
               i:=min(j,AsmOutSize);
               if OutCnt+i>=AsmOutSize then
                AsmFlush;
               Move(p[0],OutBuf[OutCnt],i);
               inc(OutCnt,i);
               inc(AsmSize,i);
               dec(j,i);
               p:=pchar(@p[i]);
             end;
          end;
      end;


    Procedure TExternalAssemblerOutputFile.AsmLn;
      var
        newline: PShortString;
        newlineres: shortstring;
        index: LongInt;
      begin
        MaybeAddLinePostfix;
        if (cs_assemble_on_target in CurrentSettings.GlobalSwitches) then
          newline:=@TargetInfo.newline
        else
          newline:=@SourceInfo.newline;
        if Assigned(decorator) then
          begin
            newlineres:=decorator.LineEnding(newline^);
            newline:=@newlineres;
          end;
        if OutCnt>=AsmOutSize-length(newline^) then
         AsmFlush;
        index:=1;
        repeat
          OutBuf[OutCnt]:=newline^[index];
          inc(OutCnt);
          inc(AsmSize);
          inc(index);
        until index>length(newline^);
      end;


    procedure TExternalAssemblerOutputFile.AsmCreate(Aplace:TCutPlace);
      begin
        if owner.SmartAsm then
         owner.NextSmartName(Aplace);
{$ifdef hasunix}
        if owner.DoPipe then
         begin
           if owner.SmartAsm then
            begin
              if (owner.SmartFilesCount<=1) then
               Message1(exec_i_assembling_smart,owner.name);
            end
           else
             Message1(exec_i_assembling_pipe,owner.AsmFileName);
           if checkverbosity(VExecutable) then
             comment(VExecutable,'Executing "'+MaybeQuoted(owner.FindAssembler)+'" with command line "'+
               owner.MakeCmdLine+'"');
           POpen(outfile,MaybeQuoted(owner.FindAssembler)+' '+owner.MakeCmdLine,'W');
         end
        else
{$endif}
         begin
           Assign(outfile,owner.AsmFileName);
           {$push} {$I-}
           Rewrite(outfile,1);
           {$pop}
           if IOResult<>0 then
             begin
               fioerror:=true;
               Message1(exec_d_cant_create_asmfile,owner.AsmFileName);
             end;
         end;
        outcnt:=0;
        AsmSize:=0;
        AsmStartSize:=0;
      end;


    procedure TExternalAssemblerOutputFile.AsmClose;
      var
        f : file;
        FileAge : LongInt;
      begin
        AsmFlush;
{$ifdef hasunix}
        if owner.DoPipe then
          begin
            if PClose(outfile) <> 0 then
              GenerateError;
          end
        else
{$endif}
         begin
         {Touch Assembler time to ppu time is there is a ppufilename}
           if owner.PPUFileName<>'' then
            begin
              Assign(f,owner.PPUFileName);
              {$push} {$I-}
              reset(f,1);
              {$pop}
              if IOResult=0 then
               begin
                 FileAge := FileGetDate(GetFileHandle(f));
                 close(f);
                 reset(outfile,1);
                 FileSetDate(GetFileHandle(outFile),FileAge);
               end;
            end;
           close(outfile);
         end;
      end;

{*****************************************************************************
                                 TExternalAssembler
*****************************************************************************}


    function TExternalAssembler.single2str(d : single) : string;
      var
         hs : string;
      begin
         str(d,hs);
      { replace space with + }
         if hs[1]=' ' then
          hs[1]:='+';
         single2str:='0d'+hs
      end;

    function TExternalAssembler.double2str(d : double) : string;
      var
         hs : string;
      begin
         str(d,hs);
      { replace space with + }
         if hs[1]=' ' then
          hs[1]:='+';
         double2str:='0d'+hs
      end;


    function TExternalAssembler.sleb128tostr(a: int64): string;
      var
        i,len : LongInt;
        buf   : array[0..31] of byte;
      begin
        result:='';
        len:=EncodeSLEB128(a,buf,0);
        for i:=0 to len-1 do
          begin
            if (i > 0) then
              result:=result+',';
            result:=result+ToStr(buf[i]);
          end;
      end;

    function TExternalAssembler.uleb128tostr(a: qword): string;
    var
      i,len : LongInt;
      buf   : array[0..31] of byte;
    begin
      result:='';
      len:=EncodeULEB128(a,buf,0);
      for i:=0 to len-1 do
        begin
          if (i > 0) then
            result:=result+',';
          result:=result+ToStr(buf[i]);
        end;
    end;


    Function TExternalAssembler.DoPipe:boolean;
      begin
{$ifdef hasunix}
        DoPipe:=(cs_asm_pipe in CurrentSettings.GlobalSwitches) and
                (([cs_asm_extern,cs_asm_leave,cs_assemble_on_target] * CurrentSettings.GlobalSwitches) = []) and
                ((asminfo^.id in [as_clang_gas,as_clang_asdarwin]));
{$else hasunix}
        DoPipe:=false;
{$endif}
      end;


    function TExternalAssembler.CreateNewAsmWriter: TExternalAssemblerOutputFile;
      begin
        result:=TExternalAssemblerOutputFile.Create(self);
      end;


    Constructor TExternalAssembler.Create(info: PAsmInfo; smart: boolean);
      begin
        CreateWithWriter(info,CreateNewAsmWriter,true,smart);
      end;


    constructor TExternalAssembler.CreateWithWriter(info: PAsmInfo; wr: TExternalAssemblerOutputFile; freewriter,smart: boolean);
      begin
        inherited Create(info,smart);
        fwriter:=wr;
        ffreewriter:=freewriter;
        if SmartAsm then
          begin
            path:=FixPath(ChangeFileExt(AsmFileName,TargetInfo.smartext),false);
            CreateSmartLinkPath(path);
          end;
      end;


    procedure TExternalAssembler.CreateSmartLinkPath(const s:TPathStr);

        procedure DeleteFilesWithExt(const AExt:string);
        var
          dir : TRawByteSearchRec;
        begin
          if findfirst(FixPath(s,false)+'*'+AExt,faAnyFile,dir) = 0 then
            begin
              repeat
                DeleteFile(s+SourceInfo.dirsep+dir.name);
              until findnext(dir) <> 0;
            end;
          findclose(dir);
        end;

      var
        hs  : TPathStr;
      begin
        if PathExists(s,false) then
         begin
           { the path exists, now we clean only all the .o and .s files }
           DeleteFilesWithExt(TargetInfo.objext);
           DeleteFilesWithExt(TargetInfo.asmext);
         end
        else
         begin
           hs:=s;
           if hs[length(hs)] in ['/','\'] then
            delete(hs,length(hs),1);
           {$push} {$I-}
            mkdir(hs);
           {$pop}
           if IOResult<>0 then;
         end;
      end;


    var
      lastas  : byte=255;
      LastASBin : TCmdStr;
    Function TExternalAssembler.FindAssembler:string;
      var
        asfound : boolean;
        UtilExe  : string;
        asmbin : TCmdStr;
      begin
        asfound:=false;
        asmbin:=asminfo^.asmbin;
        if (af_llvm in asminfo^.flags) then
          asmbin:=asmbin+LLVMUtilsSuffix;
        if cs_assemble_on_target in CurrentSettings.GlobalSwitches then
         begin
           { If assembling on target, don't add any path PM }
           FindAssembler:=UtilsPrefix+ChangeFileExt(asmbin,TargetInfo.ExeExt);
           exit;
         end
        else
         UtilExe:=UtilsPrefix+ChangeFileExt(asmbin,SourceInfo.ExeExt);
        if lastas<>ord(asminfo^.id) then
         begin
           lastas:=ord(asminfo^.id);
           { is an assembler passed ? }
           if UtilsDirectory<>'' then
             asfound:=FindFile(UtilExe,UtilsDirectory,false,LastASBin);
           if not AsFound then
             asfound:=FindExe(UtilExe,false,LastASBin);
           if (not asfound) and not(cs_asm_extern in CurrentSettings.GlobalSwitches) then
            begin
              Message1(exec_e_assembler_not_found,LastASBin);
              CurrentSettings.GlobalSwitches:=CurrentSettings.GlobalSwitches+[cs_asm_extern];
            end;
           if asfound then
            Message1(exec_t_using_assembler,LastASBin);
         end;
        FindAssembler:=LastASBin;
      end;


    Function TExternalAssembler.CallAssembler(const command:string; const para:TCmdStr):Boolean;
      var
        DosExitCode : Integer;
      begin
        result:=true;
        if (cs_asm_extern in CurrentSettings.GlobalSwitches) then
          begin
            if SmartAsm then
              AsmRes.AddAsmCommand(command,para,Name+'('+ToStr(SmartFilesCount)+')')
            else
              AsmRes.AddAsmCommand(command,para,name);
            exit;
          end;
        try
          FlushOutput;
          DosExitCode:=RequotedExecuteProcess(command,para);
          if DosExitCode<>0
          then begin
            Message1(exec_e_error_while_assembling,ToStr(dosexitcode));
            result:=false;
          end;
        except on E:EOSError do
          begin
            Message1(exec_e_cant_call_assembler,ToStr(E.ErrorCode));
            CurrentSettings.GlobalSwitches:=CurrentSettings.GlobalSwitches+[cs_asm_extern];
            result:=false;
          end;
        end;
      end;


    Function TExternalAssembler.DoAssemble:boolean;
      var
        command: TCmdStr;
        para: TCmdStr;
      begin
        result:=true;
        if DoPipe then
         exit;
        if not(cs_asm_extern in CurrentSettings.GlobalSwitches) then
         begin
           if SmartAsm then
            begin
              if (SmartFilesCount<=1) then
               Message1(exec_i_assembling_smart,name);
            end
           else
           Message1(exec_i_assembling,name);
         end;

        if (asminfo^.id in [as_clang_gas,as_clang_asdarwin]) and
           not(cs_asm_extern in CurrentSettings.GlobalSwitches) and
           not(cs_assemble_on_target in CurrentSettings.GlobalSwitches) then
          begin
            command:=FindAssembler;
            para:=MakeCmdLine;
            if Do_CheckVerbosity(VExecutable) then
              Do_Comment(VExecutable,'Executing "'+command+
                '" with command line "'+para+'"');
            FlushOutput;
            try
              result:=NXQueueClangAssembly(command,para,AsmFileName,
                not(cs_asm_leave in CurrentSettings.GlobalSwitches));
              if not result and not ClangAssemblerFailureReported then
                Message1(exec_e_error_while_assembling,
                  ToStr(NXClangAssemblyExitCode));
            except
              on E:EOSError do
                begin
                  Message1(exec_e_cant_call_assembler,ToStr(E.ErrorCode));
                  result:=false;
                end;
            end;
            if not result and not ClangAssemblerFailureReported then
              begin
                ClangAssemblerFailureReported:=true;
                GenerateError;
              end;
            exit;
          end;

        repeat
          result:=CallAssembler(FindAssembler,MakeCmdLine)
        until not(result) or not RerunAssembler;
        if result then
          writer.RemoveAsm
        else
          GenerateError;
      end;


    function DrainClangAssemblerQueue: Boolean;
      begin
        result:=NXDrainClangAssemblies;
        if not result and not ClangAssemblerFailureReported then
          begin
            ClangAssemblerFailureReported:=true;
            Message1(exec_e_error_while_assembling,
              ToStr(NXClangAssemblyExitCode));
            GenerateError;
          end;
      end;


    function TExternalAssembler.MakeCmdLine: TCmdStr;

      function section_high_bound:LongInt;
        var
          alt : TAsmListType;
        begin
          result:=0;
          for alt:=low(TAsmListType) to high(TAsmListType) do
            result:=result+CurrentAsmData.asmlists[alt].section_count;
        end;

      const
        min_big_obj_section_count = $7fff;

      begin
        result:=asminfo^.asmcmd;
        if af_llvm in TargetAsm.flags then
          Replace(result,'$TRIPLET',TargetTriplet(triplet_llvm));
        if (cs_assemble_on_target in CurrentSettings.GlobalSwitches) then
         begin
           Replace(result,'$ASM',MaybeQuoted(ScriptFixFileName(AsmFileName)));
           Replace(result,'$OBJ',MaybeQuoted(ScriptFixFileName(ObjFileName)));
         end
        else
         begin
{$ifdef hasunix}
          if DoPipe then
            if not(asminfo^.id in [as_clang_gas,as_clang_asdarwin]) then
              Replace(result,'$ASM','')
            else
              Replace(result,'$ASM','-')
          else
{$endif}
             Replace(result,'$ASM',MaybeQuoted(AsmFileName));
           Replace(result,'$OBJ',MaybeQuoted(ObjFileName));
         end;

         if (cs_create_pic in CurrentSettings.ModuleSwitches) then
           Replace(result,'$PIC','-KPIC')
         else
           Replace(result,'$PIC','');

         if (cs_asm_source in CurrentSettings.GlobalSwitches) then
           Replace(result,'$NOWARN','')
         else
           Replace(result,'$NOWARN','-W');

         if TargetInfo.endian=endian_little then
           Replace(result,'$ENDIAN','-mlittle')
         else
           Replace(result,'$ENDIAN','-mbig');

         { as we don't keep track of the amount of sections we created we simply
           enable Big Obj COFF files always for targets that need them }
         if not (TargetInfo.system in systems_all_windows) or
            (section_high_bound<min_big_obj_section_count) then
           Replace(result,'$BIGOBJ','')
         else
           Replace(result,'$BIGOBJ','-mbig-obj');

         Replace(result,'$EXTRAOPT',AsmExtraOpt);
      end;


    function TExternalAssembler.RerunAssembler: boolean;
      begin
        result:=false;
      end;


    procedure TExternalAssembler.ResetSourceLines;

      procedure DoReset(f:TInputFile);
        var
          i : LongInt;
        begin
          if not Assigned(f) then
            exit;
          for i:=0 to f.MaxLineBuf-1 do
            if f.LineBuf[i]<0 then
              f.LineBuf[i]:=-f.LineBuf[i]-1;
        end;

      begin
        DoReset(infile);
        DoReset(lastinfile);
      end;


    procedure TExternalAssembler.WriteSourceLine(hp: TAILineInfo);
      var
        module : TModule;
      begin
        { load infile }
        if (lastfileinfo.moduleindex<>hp.fileinfo.moduleindex) or
            (lastfileinfo.fileindex<>hp.fileinfo.fileindex) then
          begin
            { in case of a generic the module can be different }
            if CurrentModule.ModuleID=hp.fileinfo.moduleindex then
              module:=CurrentModule
            else
              module:=Get_Module(hp.fileinfo.moduleindex);
            { during the compilation of the system unit there are cases when
              the fileinfo contains just zeros => invalid }
            if Assigned(module) then
              infile:=module.SourceFiles.Get_File(hp.fileinfo.fileindex)
            else
              infile:=nil;
            if Assigned(infile) then
              begin
                { open only if needed !! }
                if (cs_asm_source in CurrentSettings.GlobalSwitches) then
                  infile.open;
              end;
            { avoid unnecessary reopens of the same file !! }
            lastfileinfo.fileindex:=hp.fileinfo.fileindex;
            lastfileinfo.moduleindex:=hp.fileinfo.moduleindex;
            { be sure to change line !! }
            lastfileinfo.line:=-1;
          end;
        { write source }
        if (cs_asm_source in CurrentSettings.GlobalSwitches) and
          Assigned(infile) then
          begin
            if (infile<>lastinfile) then
              begin
                writer.AsmWriteLn(asminfo^.comment+'['+infile.name+']');
                if Assigned(lastinfile) then
                  lastinfile.close;
              end;
            if (hp.fileinfo.line<>lastfileinfo.line) and
              (hp.fileinfo.line<infile.MaxLineBuf) then
              begin
                if (hp.fileinfo.line<>0) and
                  (infile.LineBuf[hp.fileinfo.line]>=0) then
                  writer.AsmWriteLn(asminfo^.comment+'['+ToStr(hp.fileinfo.line)+'] '+
                  fixline(infile.GetLineStr(hp.fileinfo.line)));
                { set it to a negative value !
                  to make that is has been read already !! PM }
                if (infile.LineBuf[hp.fileinfo.line]>=0) then
                  infile.LineBuf[hp.fileinfo.line]:=-infile.LineBuf[hp.fileinfo.line]-1;
              end;
          end;
        lastfileinfo:=hp.fileinfo;
        lastinfile:=infile;
      end;

    procedure TExternalAssembler.WriteTempalloc(hp: TAITempAlloc);
      begin
{$ifdef EXTDEBUG}
        if Assigned(hp.problem) then
          writer.AsmWriteLn(asminfo^.comment+'Temp '+ToStr(hp.temppos)+','+
          ToStr(hp.tempsize)+' '+hp.problem^)
        else
{$endif EXTDEBUG}
          writer.AsmWriteLn(asminfo^.comment+'Temp '+ToStr(hp.temppos)+','+
            ToStr(hp.tempsize)+' '+tempallocstr[hp.allocation]);
      end;


    procedure TExternalAssembler.WriteRealConstAsBytes(hp: TAIRealConst; const dbdir: string; do_line: boolean);
      var
        pdata: PByte;
        index, step, real_byte_count: LongInt;
        ssingle: single;
        ddouble: double;
        ccomp: int64;
        eextended: BestReal;
      begin

        if do_line then
          begin
            case TAIRealConst(hp).realtyp of
              aitrealconst_s32bit:
                writer.AsmWriteLn(asminfo^.comment+'s32bit real value: '+single2str(TAIRealConst(hp).value.s32val));
              aitrealconst_s64bit:
                writer.AsmWriteLn(asminfo^.comment+'s64bit real value: '+double2str(TAIRealConst(hp).value.s64val));
              aitrealconst_s80bit:
                writer.AsmWriteLn(asminfo^.comment+'s80bit real value: '+RealToStr(TAIRealConst(hp).value.s80val));
              aitrealconst_s64comp:
                begin
                  writer.AsmWriteLn(asminfo^.comment+'s64comp real value: '+ToStr(TAIRealConst(hp).value.s64compval));
                end
            end;
          end;
        writer.AsmWrite(dbdir);
        { Write the exact stored representation, including binary80 and Comp. }
        case TAIRealConst(hp).realtyp of
          aitrealconst_s32bit:
            begin
              ssingle:=single(TAIRealConst(hp).value.s32val);
              pdata:=@ssingle;
            end;
          aitrealconst_s64bit:
            begin
              ddouble:=double(TAIRealConst(hp).value.s64val);
              pdata:=@ddouble;
            end;
          aitrealconst_s80bit:
            begin
              eextended:=TAIRealConst(hp).value.s80val;
              pdata:=@eextended;
            end;
          aitrealconst_s64comp:
            begin
              ccomp:=TAIRealConst(hp).value.s64compval;
              pdata:=@ccomp;
            end;
        end;
        real_byte_count:=TAIRealConst(hp).DataSize;
        { write bytes in inverse order if source and target endianess don't
          match }
        if SourceInfo.endian<>TargetInfo.endian then
          begin
            { go from back to front }

              index:=real_byte_count-1;
            step:=-1;
          end
        else
          begin
            index:=0;
            step:=1;
          end;
        repeat

          writer.AsmWrite(ToStr(pdata[index]));
          inc(index,step);
          dec(real_byte_count);
          if real_byte_count<>0 then
            writer.AsmWrite(',');
        until real_byte_count=0;
        { padding }
        for real_byte_count:=TAIRealConst(hp).DataSize+1 to TAIRealConst(hp).savesize do
          writer.AsmWrite(',0');
        writer.AsmLn;
      end;


    function TExternalAssembler.WriteComments(var hp: TAI): boolean;
      begin
        result:=true;
        case hp.typ of
          ait_comment :
            Begin
              writer.AsmWrite(asminfo^.comment);
              writer.AsmWritePChar(TAIComment(hp).str);
              writer.AsmLn;
            End;

          ait_regalloc :
            begin
              if (cs_asm_regalloc in CurrentSettings.GlobalSwitches) then
                begin
                  writer.AsmWrite(#9+asminfo^.comment+'Register ');
                  repeat
                    writer.AsmWrite(std_regname(TAIRegAlloc(hp).reg));
                    if (hp.next=nil) or
                       (TAI(hp.next).typ<>ait_regalloc) or
                       (TAIRegAlloc(hp.next).ratype<>TAIRegAlloc(hp).ratype) then
                      break;
                    hp:=TAI(hp.next);
                    writer.AsmWrite(',');
                  until false;
                  writer.AsmWrite(' ');
                  writer.AsmWriteLn(regallocstr[TAIRegAlloc(hp).ratype]);
                end;
            end;

          ait_tempalloc :
            begin
              if (cs_asm_tempalloc in CurrentSettings.GlobalSwitches) then
                WriteTempalloc(TAITempAlloc(hp));
            end;

          ait_varloc:
            begin
              { ait_varloc is present here only when register allocation is not done ( -sr option ) }
              if TAIVarLoc(hp).newlocationhi<>NR_NO then
                writer.AsmWriteLn(asminfo^.comment+'Var '+TAIVarLoc(hp).varsym.realname+' located in register '+
                  std_regname(TAIVarLoc(hp).newlocationhi)+':'+std_regname(TAIVarLoc(hp).newlocation))
              else
                writer.AsmWriteLn(asminfo^.comment+'Var '+TAIVarLoc(hp).varsym.realname+' located in register '+
                  std_regname(TAIVarLoc(hp).newlocation));
            end;
          else
            result:=false;
        end;
      end;


    procedure TExternalAssembler.WriteTree(p:TAsmList);
      begin
      end;


    procedure TExternalAssembler.WriteAsmList;
      begin
      end;


    procedure TExternalAssembler.MakeObject;
      begin
        writer.AsmCreate(cut_normal);
        FillChar(lastfileinfo, sizeof(lastfileinfo), 0);
        lastfileinfo.line := -1;
        lastinfile := nil;
        lastsectype := sec_none;
        WriteAsmList;
        writer.AsmClose;
        if not(writer.ioerror) then
          DoAssemble;
      end;


    destructor TExternalAssembler.Destroy;
      begin
        if ffreewriter then
          writer.Free; // no nil needed
        inherited;
      end;


{*****************************************************************************
                                  TInternalAssembler
*****************************************************************************}

    constructor TInternalAssembler.Create(info: PAsmInfo; smart: boolean);
      begin
        inherited;
        ObjOutput:=nil;
        ObjData:=nil;
        SmartAsm:=smart;
      end;


   destructor TInternalAssembler.Destroy;
      begin
        if Assigned(ObjData) then
          ObjData.free;
          ObjData := nil;
        if Assigned(ObjOutput) then
          ObjOutput.free;
          ObjOutput := nil;
      end;


    function TInternalAssembler.MaybeNextList(var hp:TAI):boolean;
      begin
        { maybe end of list }
        while not Assigned(hp) do
         begin
           if currlistidx<lists then
            begin
              inc(currlistidx);
              currlist:=list[currlistidx];
              hp:=TAI(currList.first);
            end
           else
            begin
              MaybeNextList:=false;
              exit;
            end;
         end;
        MaybeNextList:=true;
      end;


    function TInternalAssembler.SetIndirectToSymbol(hp: TAI; const indirectname: string): Boolean;
      var
        objsym  : TObjSymbol;
        indsym  : TObjSymbol;
      begin
        Result:=
          Assigned(hp) and
          (hp.typ=ait_symbol);
        if not Result then
          Exit;
        objsym:=Objdata.SymbolRef(TAISymbol(hp).sym);
        objsym.size:=0;

        indsym := TObjSymbol(ObjData.ObjSymbolList.Find(indirectname));
        if not Assigned(indsym) then
          begin
            { it's possible that indirect symbol is not present in the list,
              so we must create it as undefined }
            indsym:=ObjData.CObjSymbol.Create(ObjData.ObjSymbolList, indirectname);
            indsym.typ:=AT_NONE;
            indsym.bind:=AB_NONE;
          end;
        objsym.indsymbol:=indsym;
        Result:=true;
      end;


    function TInternalAssembler.TreePass0(hp:TAI):TAI;
      var
        objsym,
        objsymend : TObjSymbol;
        cpu: TCPUType;
        eabi_section, TmpSection: TObjSection;
      begin
        while Assigned(hp) do
         begin
{$ifdef DEBUG}
           if not(hp.typ in SkipLineInfo) then
             CurrentFilePos:=TAILineInfo(hp).fileinfo;
{$endif DEBUG}
            case hp.typ of
             ait_align :
               begin
                 if TAIAlignAbstract(hp).aligntype>1 then
                   begin
                     { always use the maximum fillsize in this pass to avoid possible
                       short jumps to become out of range }
                     TAIAlignAbstract(hp).fillsize:=TAIAlignAbstract(hp).aligntype;
                     ObjData.alloc(TAIAlignAbstract(hp).fillsize);
                     { may need to increase alignment of section }
                     if TAIAlignAbstract(hp).aligntype>ObjData.CurrObjSec.secalign then
                       ObjData.CurrObjSec.secalign:=TAIAlignAbstract(hp).aligntype;
                   end
                 else
                   TAIAlignAbstract(hp).fillsize:=0;
               end;
             ait_datablock :
               begin
{$ifdef USE_COMM_IN_BSS}
                 if writingpackages and
                    TAIDataBlock(hp).is_global then
                   ObjData.SymbolDefine(TAIDataBlock(hp).sym)
                 else
{$endif USE_COMM_IN_BSS}
                   begin
                     ObjData.allocalign(Used_Align(Size_2_Align(TAIDataBlock(hp).size),0,ObjData.CurrObjSec.secalign));
                     ObjData.SymbolDefine(TAIDataBlock(hp).sym);
                     ObjData.alloc(TAIDataBlock(hp).size);
                   end;
               end;
             ait_realconst:
               ObjData.alloc(TAIRealConst(hp).savesize);
             ait_const:
               begin
                 { if symbols are provided we can calculate the value for relative symbols.
                   This is required for length calculation of leb128 constants }
                 if Assigned(TAIConst(hp).sym) then
                   begin
                     objsym:=Objdata.SymbolRef(TAIConst(hp).sym);
                     { objsym already defined and there is endsym? }
                     if Assigned(objsym.objsection) and Assigned(TAIConst(hp).endsym) then
                       begin
                         objsymend:=Objdata.SymbolRef(TAIConst(hp).endsym);
                         { objsymend already defined? }
                         if Assigned(objsymend.objsection) then
                           begin
                             if objsymend.objsection<>objsym.objsection then
                               begin
                                 { leb128 relative constants are not relocatable, but other types are,
                                   given that objsym belongs to the current section. }
                                 if (TAIConst(hp).consttype in [aitconst_uleb128bit,aitconst_sleb128bit]) or
                                    (objsym.objsection<>ObjData.CurrObjSec) then
                                   InternalError(200404124);
                               end
{$push} {$R-}{$Q-}
                             else
                               TAIConst(hp).value:=objsymend.address-objsym.address+TAIConst(hp).symofs;
                           end;
{$pop}
                       end;
                   end;
                 ObjData.alloc(TAIConst(hp).size);
               end;
             ait_directive:
               begin
                 case TAIDirective(hp).directive of
                   asd_indirect_symbol:
                     { handled in TreePass1 }
                     ;
                   asd_lazy_reference:
                     begin
                       if TAIDirective(hp).name='' then
                         InternalError(2009112101);
                       objsym:=ObjData.symbolref(TAIDirective(hp).name);
                       objsym.bind:=AB_LAZY;
                     end;
                   asd_reference:
                     { ignore for now, but should be added}
                     ;
                   asd_cpu:
                     begin
                       ObjData.CPUType:=cpu_none;
                       for cpu:=low(TCPUType) to high(TCPUType) do
                         if CPUTypeStr[cpu]=TAIDirective(hp).name then
                           begin
                             ObjData.CPUType:=cpu;
                             break;
                           end;
                     end;
                   asd_weak_definition:
                     begin
                       if TAIDirective(hp).name='' then
                         InternalError(2022040901);
                       objsym:=ObjData.symbolref(TAIDirective(hp).name);
                       objsym.bind:=AB_WEAK;
                     end;
                   else
                     InternalError(2010011101);
                 end;
               end;
             ait_section:
               begin
                 if TAISection(hp).sectype=sec_user then
                   ObjData.CreateSection(TAISection(hp).sectype,TAISection(hp).secflags,TAISection(hp).secprogbits,TAISection(hp).name^,TAISection(hp).secorder)
                 else
                   ObjData.CreateSection(TAISection(hp).sectype,TAISection(hp).name^,TAISection(hp).secorder);
                 TAISection(hp).sec:=ObjData.CurrObjSec;
               end;
             ait_symbol :
               begin
                 { needs extra support in the internal assembler }
                 { the value is just ignored }
                 {if tai_symbol(hp).has_value then
                      internalerror(2009090804); ;}
                 ObjData.SymbolDefine(TAISymbol(hp).sym);
               end;
             ait_symbolpair :
               with TAISymbolPair(hp) do
                 ObjData.SymbolPairDefine(kind,sym^,value^);
             ait_label :
               ObjData.SymbolDefine(TAILabel(hp).labsym);
             ait_string :
               ObjData.alloc(TAIString(hp).len);
             ait_instruction :
               begin
                 { reset instructions which could change in pass 2 }
                 TAICPU(hp).resetpass2;
                 ObjData.alloc(TAICPU(hp).Pass1(ObjData));
               end;
             ait_cutobject :
               if SmartAsm then
                break;
             ait_eabi_attribute :
               begin
                 eabi_section:=ObjData.findsection('.ARM.attributes');
                 if not(Assigned(eabi_section)) then
                   begin
                     TmpSection:=ObjData.CurrObjSec;
                     ObjData.CreateSection(sec_arm_attribute,[],SPB_ARM_ATTRIBUTES,'',secorder_default);
                     eabi_section:=ObjData.CurrObjSec;
                     ObjData.setsection(TmpSection);
                   end;
                 if eabi_section.Size=0 then
                   eabi_section.alloc(16);
                 eabi_section.alloc(LengthULEB128(TAIAttribute(hp).tag));
                 case TAIAttribute(hp).eattr_typ of
                   eattrtype_dword:
                     eabi_section.alloc(LengthULEB128(TAIAttribute(hp).value));
                   eattrtype_ntbs:
                     if Assigned(TAIAttribute(hp).valuestr) then
                       eabi_section.alloc(Length(TAIAttribute(hp).valuestr^)+1)
                     else
                       eabi_section.alloc(1);
                   else
                     InternalError(2019100701);
                 end;
               end;
             else
               ;
           end;
           hp:=TAI(hp.next);
         end;
        TreePass0:=hp;
      end;


    function TInternalAssembler.TreePass1(hp:TAI):TAI;
      var
        objsym,
        objsymend : TObjSymbol;
        cpu: TCPUType;
        eabi_section: TObjSection;
      begin
        while Assigned(hp) do
         begin
{$ifdef DEBUG}
           if not(hp.typ in SkipLineInfo) then
             CurrentFilePos:=TAILineInfo(hp).fileinfo;
{$endif DEBUG}
           case hp.typ of
             ait_align :
               begin
                 if TAIAlignAbstract(hp).aligntype>1 then
                   begin
                     { here we must determine the fillsize which is used in pass2 }
                     TAIAlignAbstract(hp).fillsize:=align(ObjData.CurrObjSec.Size,TAIAlignAbstract(hp).aligntype)-
                       ObjData.CurrObjSec.Size;

                     { maximum number of bytes for alignment exceeded? }
                     if (TAIAlignAbstract(hp).aligntype<>TAIAlignAbstract(hp).maxbytes) and
                       (TAIAlignAbstract(hp).fillsize>TAIAlignAbstract(hp).maxbytes) then
                       TAIAlignAbstract(hp).fillsize:=align(ObjData.CurrObjSec.Size,Byte(TAIAlignAbstract(hp).aligntype div 2))-
                         ObjData.CurrObjSec.Size;

                     ObjData.alloc(TAIAlignAbstract(hp).fillsize);
                   end;
               end;
             ait_datablock :
               begin
                 if oso_data in ObjData.CurrObjSec.secoptions then
                   Message(asmw_e_alloc_data_only_in_bss);
{$ifdef USE_COMM_IN_BSS}
                 if writingpackages and
                    TAIDataBlock(hp).is_global then
                   begin
                     objsym:=ObjData.SymbolDefine(TAIDataBlock(hp).sym);
                     objsym.size:=TAIDataBlock(hp).size;
                     objsym.bind:=AB_COMMON;
                     objsym.alignment:=needtowritealignmentalsoforELF;
                   end
                 else
{$endif USE_COMM_IN_BSS}
                   begin
                     ObjData.allocalign(Used_Align(Size_2_Align(TAIDataBlock(hp).size),0,ObjData.CurrObjSec.secalign));
                     objsym:=ObjData.SymbolDefine(TAIDataBlock(hp).sym);
                     objsym.size:=TAIDataBlock(hp).size;
                     ObjData.alloc(TAIDataBlock(hp).size);
                   end;
               end;
             ait_realconst:
               ObjData.alloc(TAIRealConst(hp).savesize);
             ait_const:
               begin
                 { Recalculate relative symbols }
                 if Assigned(TAIConst(hp).sym) and
                    Assigned(TAIConst(hp).endsym) then
                   begin
                     objsym:=Objdata.SymbolRef(TAIConst(hp).sym);
                     objsymend:=Objdata.SymbolRef(TAIConst(hp).endsym);
                     if TAIConst(hp).consttype in [aitconst_gottpoff,aitconst_tlsgd,aitconst_tlsdesc] then
                       begin
                         if objsymend.objsection<>ObjData.CurrObjSec then
                           InternalError(2019092801);
                         TAIConst(hp).value:=objsymend.address-ObjData.CurrObjSec.Size+TAIConst(hp).symofs;
                       end
                     else if objsymend.objsection<>objsym.objsection then
                       begin
                         if (TAIConst(hp).consttype in [aitconst_uleb128bit,aitconst_sleb128bit]) or
                            (objsym.objsection<>ObjData.CurrObjSec) then
                           InternalError(200905042);
                       end
{$push} {$R-}{$Q-}
                     else
                       TAIConst(hp).value:=objsymend.address-objsym.address+TAIConst(hp).symofs;
                   end;
{$pop}
                 if (TAIConst(hp).consttype in [aitconst_uleb128bit,aitconst_sleb128bit]) then
                   TAIConst(hp).fixsize;
                 ObjData.alloc(TAIConst(hp).size);
               end;
             ait_section:
               begin
                 { use cached value }
                 ObjData.setsection(TAISection(hp).sec);
               end;
             ait_symbol :
               ObjData.SymbolDefine(TAISymbol(hp).sym);
             ait_symbol_end :
               begin
                 objsym:=ObjData.SymbolRef(TAISymbolEnd(hp).sym);
                 objsym.size:=ObjData.CurrObjSec.Size-objsym.offset;
               end;
             ait_symbolpair:
               with TAISymbolPair(hp) do
                 ObjData.SymbolPairDefine(kind,sym^,value^);
             ait_label :
               ObjData.SymbolDefine(TAILabel(hp).labsym);
             ait_string :
               ObjData.alloc(TAIString(hp).len);
             ait_instruction :
               ObjData.alloc(TAICPU(hp).Pass1(ObjData));
             ait_cutobject :
               if SmartAsm then
                break;
             ait_directive :
               begin
                 case TAIDirective(hp).directive of
                   asd_indirect_symbol:
                     if TAIDirective(hp).name='' then
                       InternalError(2009101103)
                     else if not SetIndirectToSymbol(TAI(hp.Previous), TAIDirective(hp).name) then
                       InternalError(2009101102);
                   asd_lazy_reference:
                     { handled in TreePass0 }
                     ;
                   asd_reference:
                     { ignore for now, but should be added}
                     ;
                   asd_thumb_func:
                     { ignore for now, but should be added}
                     ;
                   asd_force_thumb:
                     { ignore for now, but should be added}
                     ;
                   asd_code:
                     { ignore for now, but should be added}
                     ;
                   asd_option:
                     { ignore for now, but should be added}
                     ;
                   asd_weak_definition:
                     { ignore for now, but should be added}
                     ;
                   asd_cpu:
                     begin
                       ObjData.CPUType:=cpu_none;
                       for cpu:=low(TCPUType) to high(TCPUType) do
                         if CPUTypeStr[cpu]=TAIDirective(hp).name then
                           begin
                             ObjData.CPUType:=cpu;
                             break;
                           end;
                     end;
                   else
                     InternalError(2010011102);
                 end;
               end;
             ait_eabi_attribute :
               begin
                 eabi_section:=ObjData.findsection('.ARM.attributes');
                 if not(Assigned(eabi_section)) then
                   InternalError(2019100702);
                 if eabi_section.Size=0 then
                   eabi_section.alloc(16);
                 eabi_section.alloc(LengthULEB128(TAIAttribute(hp).tag));
                 case TAIAttribute(hp).eattr_typ of
                   eattrtype_dword:
                     eabi_section.alloc(LengthULEB128(TAIAttribute(hp).value));
                   eattrtype_ntbs:
                     if Assigned(TAIAttribute(hp).valuestr) then
                       eabi_section.alloc(Length(TAIAttribute(hp).valuestr^)+1)
                     else
                       eabi_section.alloc(1);
                   else
                     InternalError(2019100703);
                 end;
               end;
             else
               ;
           end;
           hp:=TAI(hp.next);
         end;
        TreePass1:=hp;
      end;


    function TInternalAssembler.TreePass2(hp:TAI):TAI;
      var
        fillbuffer : TFillBuffer;
        leblen : byte;
        lebbuf : array[0..63] of byte;
        objsym,
        ref,
        objsymend : TObjSymbol;
        zerobuf : array[0..63] of byte;
        relative_reloc: boolean;
        pdata : pointer;
	real_byte_count, index : LongInt;
        ssingle : single;
        ddouble : double;
        eextended: BestReal;
        ccomp: Int64;
        tmp    : word;
        cpu: TCPUType;
        ddword : dword;
        b : byte;
        w : word;
        d : dword;
        q : qword;
        eabi_section: TObjSection;
        s: String;
        TmpDataPos: TObjSectionOfs;
      begin
        fillchar(zerobuf,sizeof(zerobuf),0);
        fillchar(objsym,sizeof(objsym),0);
        fillchar(objsymend,sizeof(objsymend),0);

        { main loop }
        while Assigned(hp) do
         begin
{$ifdef DEBUG}
           if not(hp.typ in SkipLineInfo) then
             CurrentFilePos:=TAILineInfo(hp).fileinfo;
{$endif DEBUG}
           case hp.typ of
             ait_align :
               begin
                 if TAIAlignAbstract(hp).aligntype>ObjData.CurrObjSec.secalign then
                   InternalError(2012072301);
                 if oso_data in ObjData.CurrObjSec.secoptions then
                   ObjData.writebytes(TAIAlignAbstract(hp).calculatefillbuf(fillbuffer,oso_executable in ObjData.CurrObjSec.secoptions)^,
                     TAIAlignAbstract(hp).fillsize)
                 else
                   ObjData.alloc(TAIAlignAbstract(hp).fillsize);
               end;
             ait_section :
               begin
                 { use cached value }
                 ObjData.setsection(TAISection(hp).sec);
               end;
             ait_symbol :
               begin
                 ObjOutput.exportsymbol(ObjData.SymbolRef(TAISymbol(hp).sym));
               end;
            ait_symbol_end :
               begin
                 { recalculate size, as some preceding instructions
                   could have been changed to smaller size }
                 objsym:=ObjData.SymbolRef(TAISymbolEnd(hp).sym);
                 objsym.size:=ObjData.CurrObjSec.Size-objsym.offset;
               end;
             ait_datablock :
               begin
                 ObjOutput.exportsymbol(ObjData.SymbolRef(TAIDataBlock(hp).sym));
{$ifdef USE_COMM_IN_BSS}
                 if not(writingpackages and
                        TAIDataBlock(hp).is_global) then
{$endif USE_COMM_IN_BSS}
                   begin
                     ObjData.allocalign(Used_Align(Size_2_Align(TAIDataBlock(hp).size),0,ObjData.CurrObjSec.secalign));
                     ObjData.alloc(TAIDataBlock(hp).size);
                   end;
               end;
             ait_realconst:
               begin
                 real_byte_count:=TAIRealConst(hp).DataSize;
                 case TAIRealConst(hp).realtyp of
                   aitrealconst_s32bit:
                     begin
                       ssingle:=TAIRealConst(hp).value.s32val;
                       pdata:=@ssingle;
                     end;
                   aitrealconst_s64bit:
                     begin
                       ddouble:=TAIRealConst(hp).value.s64val;
                       pdata:=@ddouble;
                     end;
                   aitrealconst_s80bit:
                     begin
                       eextended:=TAIRealConst(hp).value.s80val;
                       pdata:=@eextended;
                     end;
                   aitrealconst_s64comp:
                     begin
                       ccomp:=TAIRealConst(hp).value.s64compval;
                       pdata:=@ccomp;
                     end;
                 end;
                 if SourceInfo.endian<>TargetInfo.endian then
                   begin
                     for index:=0 to real_byte_count-1 do
                       lebbuf[index]:=PByte(pdata)[real_byte_count-1-index];
                     pdata:=@lebbuf;
                   end;
                 ObjData.writebytes(pdata^,real_byte_count);
                 ObjData.writebytes(zerobuf,TAIRealConst(hp).savesize-real_byte_count);
               end;
             ait_string :
               ObjData.writebytes(TAIString(hp).str,TAIString(hp).len);
             ait_const :
               begin
                 { Recalculate relative symbols, addresses of forward references
                   can be changed in treepass1 }
                 relative_reloc:=false;
                 if Assigned(TAIConst(hp).sym) and
                    Assigned(TAIConst(hp).endsym) then
                   begin
                     objsym:=Objdata.SymbolRef(TAIConst(hp).sym);
                     objsymend:=Objdata.SymbolRef(TAIConst(hp).endsym);
                     relative_reloc:=(objsym.objsection<>objsymend.objsection);
                     if TAIConst(hp).consttype in [aitconst_gottpoff] then
                       begin
                         if objsymend.objsection<>ObjData.CurrObjSec then
                           InternalError(2019092802);
                         TAIConst(hp).value:=objsymend.address-ObjData.CurrObjSec.Size+TAIConst(hp).symofs;
                       end
                     else if TAIConst(hp).consttype in [aitconst_tlsgd,aitconst_tlsdesc] then
                       begin
                         if objsymend.objsection<>ObjData.CurrObjSec then
                           InternalError(2019092803);
                         TAIConst(hp).value:=ObjData.CurrObjSec.Size-objsymend.address+TAIConst(hp).symofs;
                       end
                     else if objsymend.objsection<>objsym.objsection then
                       begin
                         if (TAIConst(hp).consttype in [aitconst_uleb128bit,aitconst_sleb128bit]) or
                            (objsym.objsection<>ObjData.CurrObjSec) then
                           InternalError(2019010301);
                       end
                     else
{$push} {$R-}{$Q-}
                       TAIConst(hp).value:=objsymend.address-objsym.address+TAIConst(hp).symofs;
                   end;
{$pop}
                 case TAIConst(hp).consttype of
                   aitconst_64bit,
                   aitconst_32bit,
                   aitconst_16bit,
                   aitconst_64bit_unaligned,
                   aitconst_32bit_unaligned,
                   aitconst_16bit_unaligned,
                   aitconst_8bit :
                     begin
                       if Assigned(TAIConst(hp).sym) and
                          not Assigned(TAIConst(hp).endsym) then
                         ObjData.writereloc(TAIConst(hp).symofs,TAIConst(hp).size,Objdata.SymbolRef(TAIConst(hp).sym),RELOC_ABSOLUTE)
                       else if relative_reloc then
                         ObjData.writereloc(ObjData.CurrObjSec.size+TAIConst(hp).size-objsym.address+TAIConst(hp).symofs,TAIConst(hp).size,objsymend,RELOC_RELATIVE)
                       else
                         if SourceInfo.endian<>TargetInfo.endian then
                           begin
                             case TAIConst(hp).size of
                                1 : begin
                                      b:=byte(TAIConst(hp).value);
                                      ObjData.writebytes(b,1);
                                    end;
                                2 : begin
                                      w:=word(TAIConst(hp).value);
                                      w:=swapendian(w);
                                      ObjData.writebytes(w,2);
                                    end;
                                4 : begin
                                      d:=dword(TAIConst(hp).value);
                                      d:=swapendian(d);
                                      ObjData.writebytes(d,4);
                                    end;
                                8 : begin
                                      q:=qword(TAIConst(hp).value);
                                      q:=swapendian(q);
                                      ObjData.writebytes(q,8);
                                    end;
                             else
                               InternalError(2024012502);
                             end;
                           end
                         else
                           ObjData.writebytes(TAIConst(hp).value,TAIConst(hp).size);
                     end;
                   aitconst_rva_symbol :
                     begin
                       { PE32+? }
                       if TargetInfo.system in systems_peoptplus then
                         ObjData.writereloc(TAIConst(hp).symofs,sizeof(LongInt),Objdata.SymbolRef(TAIConst(hp).sym),RELOC_RVA)
                       else
                         ObjData.writereloc(TAIConst(hp).symofs,sizeof(PInt),Objdata.SymbolRef(TAIConst(hp).sym),RELOC_RVA);
                     end;
                   aitconst_secrel32_symbol :
                     begin
                       { Required for DWARF debug information under Windows }
                       ObjData.writereloc(TAIConst(hp).symofs,sizeof(LongInt),Objdata.SymbolRef(TAIConst(hp).sym),RELOC_SECREL32);
                     end;

                   aitconst_dtpoff:
                     { so far, the size of dtpoff is fixed to 4 bytes }
                     ObjData.writereloc(TAIConst(hp).symofs,4,Objdata.SymbolRef(TAIConst(hp).sym),RELOC_DTPOFF);
                   aitconst_gotoff_symbol:
                     ObjData.writereloc(TAIConst(hp).symofs,sizeof(LongInt),Objdata.SymbolRef(TAIConst(hp).sym),RELOC_GOTOFF);
                   aitconst_uleb128bit,
                   aitconst_sleb128bit :
                     begin
                       if TAIConst(hp).fixed_size=0 then
                         InternalError(2019030302);
                       if TAIConst(hp).consttype=aitconst_uleb128bit then
                         leblen:=EncodeULEB128(qword(TAIConst(hp).value),lebbuf,TAIConst(hp).fixed_size)
                       else
                         leblen:=EncodeSLEB128(TAIConst(hp).value,lebbuf,TAIConst(hp).fixed_size);
                       if leblen<>TAIConst(hp).fixed_size then
                         InternalError(200709271);
                       ObjData.writebytes(lebbuf,leblen);
                     end;
                   aitconst_darwin_dwarf_delta32,
                   aitconst_darwin_dwarf_delta64:
                     ObjData.writebytes(TAIConst(hp).value,TAIConst(hp).size);
                   aitconst_half16bit,
                   aitconst_gs:
                     begin
                       tmp:=TAIConst(hp).value div 2;
                       ObjData.writebytes(tmp,2);
                     end;
                   else
                     InternalError(200603254);
                 end;
               end;
             ait_label :
               begin
                 { exporting shouldn't be necessary as labels are local,
                   but it's better to be on the safe side (PFV) }
                 ObjOutput.exportsymbol(ObjData.SymbolRef(TAILabel(hp).labsym));
               end;
             ait_instruction :
               TAICPU(hp).Pass2(ObjData);
             ait_function_name,
             ait_force_line : ;
             ait_cutobject :
               if SmartAsm then
                break;
             ait_directive :
               begin
                 case TAIDirective(hp).directive of
                   asd_weak_definition,
                   asd_weak_reference:
                     begin
                       objsym:=ObjData.symbolref(TAIDirective(hp).name);
                       if objsym.bind in [AB_EXTERNAL,AB_WEAK_EXTERNAL] then
                         objsym.bind:=AB_WEAK_EXTERNAL
                       else
                         { TODO: should become a weak definition; for now, do
                             the same as what was done for ait_weak }
                         objsym.bind:=AB_WEAK_EXTERNAL;
                     end;
                   asd_cpu:
                     begin
                       ObjData.CPUType:=cpu_none;
                       for cpu:=low(TCPUType) to high(TCPUType) do
                         if CPUTypeStr[cpu]=TAIDirective(hp).name then
                           begin
                             ObjData.CPUType:=cpu;
                             break;
                           end;
                     end;
                   else
                     ;
                 end
               end;
             ait_symbolpair:
               begin
                 if TAISymbolPair(hp).kind=spk_set then
                   begin
                     objsym:=ObjData.symbolref(TAISymbolPair(hp).sym^);
                     ref:=objdata.symbolref(TAISymbolPair(hp).value^);

                     objsym.offset:=ref.offset;
                     objsym.objsection:=ref.objsection;
                   end;
               end;
{$ifndef DISABLE_WIN64_SEH}
             ait_seh_directive :
               TAISEHDirective(hp).generate_code(objdata);
{$endif DISABLE_WIN64_SEH}
             ait_eabi_attribute :
               begin
                 eabi_section:=ObjData.findsection('.ARM.attributes');
                 if not(Assigned(eabi_section)) then
                   InternalError(2019100704);
                 if eabi_section.Size=0 then
                   begin
                     s:='A';
                     eabi_section.write(s[1],1);
                     ddword:=eabi_section.Size-1;
                     if SourceInfo.endian<>TargetInfo.endian then
                       ddword:=SwapEndian(ddword);
                     eabi_section.write(ddword,4);
                     s:='aeabi'#0;
                     eabi_section.write(s[1],6);
                     s:=#1;
                     eabi_section.write(s[1],1);
                     ddword:=eabi_section.Size-1-4-6-1;
                     if SourceInfo.endian<>TargetInfo.endian then
                       ddword:=SwapEndian(ddword);
                     eabi_section.write(ddword,4);
                   end;
                 leblen:=EncodeULEB128(TAIAttribute(hp).tag,lebbuf,0);
                 eabi_section.write(lebbuf,leblen);

                 case TAIAttribute(hp).eattr_typ of
                   eattrtype_dword:
                     begin
                       leblen:=EncodeULEB128(TAIAttribute(hp).value,lebbuf,0);
                       eabi_section.write(lebbuf,leblen);
                     end;
                   eattrtype_ntbs:
                     begin
                       if Assigned(TAIAttribute(hp).valuestr) then
                         s:=TAIAttribute(hp).valuestr^+#0
                       else
                         s:=#0;
                       eabi_section.write(s[1],Length(s));
                     end
                   else
                     InternalError(2019100705);
                 end;
                 { update size of attributes section, write directly to the dyn. arrays as
                   we do not increase the size of section }
                 TmpDataPos:=eabi_section.Data.Pos;
                 eabi_section.Data.seek(1);
                 ddword:=eabi_section.Size-1;
                 if SourceInfo.endian<>TargetInfo.endian then
                   ddword:=SwapEndian(ddword);
                 eabi_section.Data.write(ddword,4);
                 eabi_section.Data.seek(12);
                 ddword:=eabi_section.Size-1-4-6;
                 if SourceInfo.endian<>TargetInfo.endian then
                   ddword:=SwapEndian(ddword);
                 eabi_section.Data.write(ddword,4);
                 eabi_section.Data.Seek(TmpDataPos);
               end;
             else
               ;
           end;
           hp:=TAI(hp.next);
         end;
        TreePass2:=hp;
      end;


    procedure TInternalAssembler.writetree;
      label
        doexit;
      var
        hp : TAI;
        ObjWriter : TObjectWriter;
      begin
        ObjWriter:=TObjectWriter.create;
        ObjOutput:=CObjOutput.Create(ObjWriter);
        ObjData:=ObjOutput.newObjData(ObjFileName);

        { Pass 0 }
        ObjData.currpass:=0;
        ObjData.createsection(sec_code);
        ObjData.beforealloc;
        { start with list 1 }
        currlistidx:=1;
        currlist:=list[currlistidx];
        hp:=TAI(currList.first);
        while Assigned(hp) do
         begin
           hp:=TreePass0(hp);
           MaybeNextList(hp);
         end;
        ObjData.afteralloc;
        { leave if errors have occurred }
        if ErrorCount>0 then
         goto doexit;

        { Pass 1 }
        ObjData.currpass:=1;
        ObjData.resetsections;
        ObjData.beforealloc;
        ObjData.createsection(sec_code);
        { start with list 1 }
        currlistidx:=1;
        currlist:=list[currlistidx];
        hp:=TAI(currList.first);
        while Assigned(hp) do
         begin
           hp:=TreePass1(hp);
           MaybeNextList(hp);
         end;
        ObjData.createsection(sec_code);
        ObjData.afteralloc;

        { leave if errors have occurred }
        if ErrorCount>0 then
         goto doexit;

        { Pass 2 }
        ObjData.currpass:=2;
        ObjData.resetsections;
        ObjData.beforewrite;
        ObjData.createsection(sec_code);
        { start with list 1 }
        currlistidx:=1;
        currlist:=list[currlistidx];
        hp:=TAI(currList.first);
        while Assigned(hp) do
         begin
           hp:=TreePass2(hp);
           MaybeNextList(hp);
         end;
        ObjData.createsection(sec_code);
        ObjData.afterwrite;

        { don't write the .o file if errors have occurred }
        if ErrorCount=0 then
         begin
           { write objectfile }
           ObjOutput.startobjectfile(ObjFileName);
           ObjOutput.writeobjectfile(ObjData);
         end;

      doexit:
        { Cleanup }
        ObjData.free;
        ObjData:=nil;
        ObjWriter.free;
        ObjWriter := nil;
      end;


    procedure TInternalAssembler.writetreesmart;
      var
        hp : TAI;
        startsectype : TAsmSectiontype;
        place: TCutPlace;
        ObjWriter : TObjectWriter;
        startsecname: String;
        startsecorder: TAsmSectionOrder;
      begin
        if not(cs_asm_leave in CurrentSettings.GlobalSwitches) and
           not(af_needar in asminfo^.flags) then
          ObjWriter:=CInternalAr.CreateAr(CurrentModule.StaticLibFileName)
        else
          ObjWriter:=TObjectWriter.create;

        NextSmartName(cut_normal);
        ObjOutput:=CObjOutput.Create(ObjWriter);
        startsectype:=sec_none;
        startsecname:='';
        startsecorder:=secorder_default;

        { start with list 1 }
        currlistidx:=1;
        currlist:=list[currlistidx];
        hp:=TAI(currList.first);
        while Assigned(hp) do
         begin
           ObjData:=ObjOutput.newObjData(ObjFileName);

           { Pass 0 }
           ObjData.currpass:=0;
           ObjData.resetsections;
           ObjData.beforealloc;
           if startsectype<>sec_none then
             ObjData.CreateSection(startsectype,startsecname,startsecorder);
           TreePass0(hp);
           ObjData.afteralloc;
           { leave if errors have occurred }
           if ErrorCount>0 then
             break;

           { Pass 1 }
           ObjData.currpass:=1;
           ObjData.resetsections;
           ObjData.beforealloc;
           if startsectype<>sec_none then
             ObjData.CreateSection(startsectype,startsecname,startsecorder);
           TreePass1(hp);
           ObjData.afteralloc;

           { leave if errors have occurred }
           if ErrorCount>0 then
             break;

           { Pass 2 }
           ObjData.currpass:=2;
           ObjOutput.startobjectfile(ObjFileName);
           ObjData.resetsections;
           ObjData.beforewrite;
           if startsectype<>sec_none then
             ObjData.CreateSection(startsectype,startsecname,startsecorder);
           hp:=TreePass2(hp);
           ObjData.afterwrite;

           { leave if errors have occurred }
           if ErrorCount>0 then
             break;

           { write the current objectfile }
           ObjOutput.writeobjectfile(ObjData);
           ObjData.free;
           ObjData:=nil;

           { end of lists? }
           if not MaybeNextList(hp) then
             break;

           { we will start a new objectfile so reset everything }
           { The place can still change in the next while loop, so don't init }
           { the writer yet (JM)                                              }
           if (hp.typ=ait_cutobject) then
             place := TAICutObject(hp).place
           else
             place := cut_normal;

           { avoid empty files }
           startsectype:=sec_none;
           startsecname:='';
           startsecorder:=secorder_default;
           while Assigned(hp) and
                 (TAI(hp).typ in [ait_marker,ait_comment,ait_section,ait_cutobject]) do
            begin
              if TAI(hp).typ=ait_section then
                begin
                  startsectype:=TAISection(hp).sectype;
                  startsecname:=TAISection(hp).name^;
                  startsecorder:=TAISection(hp).secorder;
                end;
              if (TAI(hp).typ=ait_cutobject) then
                place:=TAICutObject(hp).place;
              hp:=TAI(hp.next);
            end;

           if not MaybeNextList(hp) then
             break;

           { start next objectfile }
           NextSmartName(place);
         end;
        ObjData.free;
        ObjData:=nil;
        ObjWriter.free;
        ObjWriter := nil;
      end;


    procedure TInternalAssembler.MakeObject;

    var to_do:set of TAsmListType;
        i:TAsmListType;

        procedure addlist(p:TAsmList);
        begin
          inc(lists);
          list[lists]:=p;
        end;

      begin
        to_do:=[low(TAsmListType)..high(TAsmListType)];
        if UseDefFileForExports then
          exclude(to_do,al_exports);
        if not(tf_section_threadvars in TargetInfo.flags) then
          exclude(to_do,al_threadvars);
        for i:=low(TAsmListType) to high(TAsmListType) do
          if (i in to_do) and (CurrentAsmData.asmlists[i]<>nil) and
             (not CurrentAsmData.asmlists[i].empty) then
            addlist(CurrentAsmData.asmlists[i]);

        if SmartAsm then
          writetreesmart
        else
          writetree;
      end;


{*****************************************************************************
                     Generate Assembler Files Main Procedure
*****************************************************************************}

    Procedure GenerateAsm(smart:boolean);
      var
        a : TAssembler;
      begin
        if not Assigned(CAssembler[TargetAsm.id]) then
          Message(asmw_f_assembler_output_not_supported);
        a:=CAssembler[TargetAsm.id].Create(@TargetAsm,smart);
        a.MakeObject;
        a.Free;
        a := nil;
      end;


    function GetExternalGnuAssemblerWithAsmInfoWriter(info: PAsmInfo; wr: TExternalAssemblerOutputFile): TExternalAssembler;
      var
        asmkind: TAsm;
      begin
        for asmkind in [as_clang_gas,as_clang_asdarwin] do
          if Assigned(asminfos[asmkind]) and
             (TargetInfo.system in asminfos[asmkind]^.supported_targets) then
            begin
              result:=TExternalAssemblerClass(CAssembler[asmkind]).CreateWithWriter(asminfos[asmkind],wr,false,false);
              exit;
            end;
        InternalError(2015090604);
      end;

{*****************************************************************************
                                 Init/Done
*****************************************************************************}

    procedure RegisterAssembler(const r:TAsmInfo;c:TAssemblerClass);
      var
        t : TAsm;
      begin
        t:=r.id;
        if Assigned(asminfos[t]) then
          WriteLn('Warning: Assembler is already registered!')
        else
          new(asminfos[t]);
        asminfos[t]^:=r;
        CAssembler[t]:=c;
      end;

end.
