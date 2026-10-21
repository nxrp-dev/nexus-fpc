{
    Copyright (c) 1998-2002 by Florian Klaempfl

    This unit implements an extended file management

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
unit finput;

{$i fpcdefs.inc}

interface

    uses
      CUtils,GlobType,CClasses,CStreams;

    const
       InputFileBufSize=32*1024+1;
       LineBufIncrease=512;

    type
       TLongIntArr = array of LongInt;

       TInputFile = class
         Path,Name : TPathStr;       { path and filename }
         IncPath  : TPathStr;       { path if file was included with $I directive }
         Next      : TInputFile;    { next file for reading }

         Buf          : TAnsiCharDynArray;      { buffer }
         BufStart,                  { buffer start position in the file }
         BufSize,                   { amount of bytes in the buffer }
         MaxBufSize   : LongInt;    { size in memory for the buffer }

         SaveInputPointer : PChar;  { save fields for scanner variables }
         SaveLastLinePos,
         SaveLineNo      : LongInt;

         LineBuf    : TLongIntArr;  { line buffer to retrieve lines }
         MaxLineBuf : LongInt;

         RefIndex  : LongInt;

         IsMacro,
         EndOfFile,                 { still bytes left to read }
         Closed       : Boolean;    { is the file closed }

         { this file represents an internally generated macro. Enables
           certain escape sequences }
         InternallyGeneratedMacro: Boolean;

         constructor Create(const FN:TPathStr);
         destructor  Destroy;override;
         procedure SetPos(L:LongInt);
         procedure SeekBuf(FPos:LongInt);
         procedure ReadBuf;
         function  Open:Boolean;
         procedure Close;
         procedure TempClose;
         function  TempOpen:Boolean;
         procedure SetMacro(P:PChar;Len:LongInt);
         procedure SetLine(Line,LinePos:LongInt);
         function  GetLineStr(L:LongInt):ShortString;
         function  GetFileTime:LongInt;
       protected
         FileTime  : LongInt;
         function FileOpen(const FileName: TPathStr): Boolean; virtual; abstract;
         function FileSeek(Pos: LongInt): Boolean; virtual; abstract;
         function FileRead(var DataBuf; MaxSize: LongInt): LongInt; virtual; abstract;
         function FileEOF: Boolean; virtual; abstract;
         function FileClose: Boolean; virtual; abstract;
         procedure FileGetTime; virtual; abstract;
       end;
       PInputFile = ^TInputFile;

       TDOSInputFile = class(TInputFile)
       protected
         function FileOpen(const FileName: TPathStr): Boolean; override;
         function FileSeek(Pos: LongInt): Boolean; override;
         function FileRead(var DataBuf; MaxSize: LongInt): LongInt; override;
         function FileEOF: Boolean; override;
         function FileClose: Boolean; override;
         procedure FileGetTime; override;
       private
         F            : TCCustomFileStream;       { current file handle }
       end;

       TInputFileManager = class
          Files : PInputFile;
          NFiles,AFiles : SizeInt;
          constructor Create;
          destructor Destroy;override;
          procedure Register_File(F : TInputFile);
          function  Get_File(L:LongInt) : TInputFile;
          function  Get_File_Name(L :LongInt):TPathStr;
          function  Get_File_Path(L :LongInt):TPathStr;
       end;

{****************************************************************************
                                TModuleBase
 ****************************************************************************}

     type
        TModuleState = (ms_unknown,
          ms_registered, { tmodule created }
          ms_load,
          ms_compile,    { parsing and compiling }
          ms_compiling_waitheader, { waiting for dependencies needed to finish the header }
          ms_compiling_waitdefaults, { waiting for implicit declarations before the uses clause }
          ms_compiling_wait,      { waiting for used units of program/library/package }
          ms_compiling_waitintf,  { waiting for used units of interface section }
          ms_compiling_waitimpl,  { waiting for used units of implementation section }
          ms_compiling_waitfinish,{ after impl section parsed, waiting for other impl sections needed by specializations }
          ms_compiling_waitemit, { parsed and generated bodies, waiting for final dependencies }
          ms_compiled_waitcrc,   { after computing own CRC, waiting for used units' CRCs }
          ms_compiled,   { compiling complete, ppu written }
          ms_processed,   { task complete }
          ms_moduleerror
        );
        TModuleStates = set of TModuleState;

     const
        ModuleStateStr : array[TModuleState] of string[32] = (
          'Unknown',
          'Registered',
          'Load',
          'Compile',
          'Compiling_Waiting_header',
          'Compiling_Waiting_defaults',
          'Compiling_Waiting',
          'Compiling_Waiting_interface',
          'Compiling_Waiting_implementation',
          'Compiling_Waiting_finish',
          'Compiling_Waiting_emission',
          'Compiled_Waiting_crc',
          'Compiled',
          'Processed',
          'Error'
        );

     type
        TModuleBase = class(TLinkedListItem)
          { index }
          ModuleID      : LongInt;  { global counter for browser }
          { status }
          State            : TModuleState;
          { sources }
          SourceFiles      : TInputFileManager;
          { paths and filenames }
          ParamAllowOutput : Boolean;  { original allowoutput parameter }
          ModuleName,               { name of the module in uppercase }
          RealModuleName: PShortString; { name of the module in the original case }
          ParamFN,                  { original filename }
          MainSource,               { name of the main sourcefile }
          ObjFileName,              { fullname of the objectfile }
          AsmFileName,              { fullname of the assemblerfile }
          PPUFileName,              { fullname of the ppufile }
          ImportLibFileName,        { fullname of the import libraryfile }
          StaticLibFileName,        { fullname of the static libraryfile }
          SharedLibFileName,        { fullname of the shared libraryfile }
          ExportFileName,           { fullname of the export file }
          MapFileName,              { fullname of the mapfile }
          ExeFileName,              { fullname of the exefile }
          DbgFileName,              { fullname of the debug info file }
          Path,                     { path where the module is find/created }
          OutputPath   : TPathStr;  { path where the .s / .o / exe are created }
          IsInitial : Boolean;     { is this the initial module, i.e. the one specified on the command-line ?}
          constructor Create(const S:string);
          destructor Destroy;override;
          procedure SetFileName(const FN:TPathStr;AllowOutput:Boolean);
       end;


     Function GetNamedFileTime (Const F : TPathStr) : LongInt;


implementation

uses
  SysUtils,
  CompHook,
{$ifndef GENERIC_CPU}
{$ifdef heaptrc}
  FModule,
  PPHeap,
{$endif heaptrc}
{$endif not GENERIC_CPU}
  CFileUtl,
  Globals,Systems
  ;


{****************************************************************************
                                  Utils
 ****************************************************************************}

   Function GetNamedFileTime (Const F : TPathStr) : LongInt;
     begin
       GetNamedFileTime:=Do_GetNamedFileTime(F);
     end;


{****************************************************************************
                                  TINPUTFILE
 ****************************************************************************}

    constructor TInputFile.Create(const FN:TPathStr);
      begin
        Name:=ExtractFileName(FN);
        Path:=ExtractFilePath(FN);
        IncPath:='';
        Next:=nil;
        FileTime:=-1;
        Buf:=nil;
        BufStart:=0;
        BufSize:=0;
        MaxBufSize:=InputFileBufSize;
      { save fields }
        SaveInputPointer:=nil;
        SaveLineNo:=0;
        SaveLastLinePos:=0;
      { indexing refs }
        RefIndex:=0;
      { line buffer }
        LineBuf:=nil;
        MaxLineBuf:=0;
      { file info }
        IsMacro:=False;
        EndOfFile:=False;
        Closed:=True;
        InternallyGeneratedMacro:=False;
      end;


    destructor TInputFile.Destroy;
      begin
        if not Closed then
         Close;
        LineBuf:=Nil;
      end;


    procedure TInputFile.SetPos(L:LongInt);
      begin
        BufStart:=L;
      end;


    procedure TInputFile.SeekBuf(FPos:LongInt);
      begin
        if Closed then
         Exit;
        FileSeek(FPos);
        BufStart:=FPos;
        BufSize:=0;
      end;


    procedure TInputFile.ReadBuf;
      begin
        if IsMacro then
         EndOfFile:=True;
        if Closed then
         Exit;
        Inc(BufStart,BufSize);
        BufSize:=FileRead(Buf[0],MaxBufSize-1);
        Buf[BufSize]:=#0;
        EndOfFile:=FileEOF;
      end;


    function TInputFile.Open:Boolean;
      begin
        Open:=False;
        if not Closed then
         Close;
        if not FileOpen(Path+Name) then
         Exit;
      { file }
        EndOfFile:=False;
        Closed:=False;
        SetLength(Buf,MaxBufSize);
        Buf[0]:=#0;
        BufStart:=0;
        BufSize:=0;
        Open:=True;
      end;


    procedure TInputFile.Close;
      begin
        if IsMacro then
         begin
           Buf:=nil;
           Name:='';
           Path:='';
           Closed:=True;
           Exit;
         end;
        if not Closed then
         begin
           FileClose;
           Closed:=True;
         end;
        if Assigned(Buf) then
          Buf:=nil;
        BufStart:=0;
      end;


    procedure TInputFile.TempClose;
      begin
        if IsMacro then
         Exit;
        if not Closed then
         begin
           FileClose;
           Buf:=nil;
           Closed:=True;
         end;
      end;


    function TInputFile.TempOpen:Boolean;
      begin
        TempOpen:=False;
        if IsMacro then
         begin
           { seek buffer position to bufstart }
           if BufStart>0 then
            begin
              Move(Buf[BufStart],Buf[0],BufSize-BufStart+1);
              BufStart:=0;
            end;
           TempOpen:=True;
           Exit;
         end;
        if not Closed then
         Exit;
        if not FileOpen(Path+Name) then
         Exit;
        Closed:=False;
      { get new mem }
        SetLength(Buf,MaxBufSize);
      { restore state }
        FileSeek(BufStart);
        BufSize:=0;
        ReadBuf;
        TempOpen:=True;
      end;


    procedure TInputFile.SetMacro(P:PChar;Len:LongInt);
      begin
      { create new buffer }
        SetLength(Buf,Len+1);
        if Len>0 then
          Move(P^,Buf[0],Len);
        Buf[Len]:=#0;
      { reset }
        BufStart:=0;
        BufSize:=Len;
        MaxBufSize:=Len+1;
        IsMacro:=True;
        EndOfFile:=True;
        Closed:=True;
      end;


    procedure TInputFile.SetLine(Line,LinePos:LongInt);
      begin
        if Line<1 then
         Exit;
        while (Line>=MaxLineBuf) do
          begin
            { create new linebuf and move old info }
            SetLength(LineBuf,(MaxLineBuf+LineBufIncrease));
            Inc(MaxLineBuf,LineBufIncrease);
          end;
        LineBuf[Line]:=LinePos;
      end;


    function TInputFile.GetLineStr(L:LongInt):ShortString;
      var
        C    : Char;
        I,
        FPos : LongInt;
        P    : PChar;
      begin
        GetLineStr:='';
        if L<MaxLineBuf then
         begin
           FPos:=LineBuf[L];
           { fpos is set negativ if the line was already written }
           { but we still know the correct value                 }
           if FPos<0 then
             FPos:=-FPos+1;
           if Closed then
            Open;
         { in current buf ? }
           if (FPos<BufStart) or (FPos>BufStart+BufSize) then
            begin
              SeekBuf(FPos);
              ReadBuf;
            end;
         { the begin is in the buf now simply read until #13,#10 }
           I:=0;
           P:=@Buf[FPos-BufStart];
           repeat
             C:=P^;
             if C=#0 then
              begin
                if EndOfFile then
                 Break;
                ReadBuf;
                P:=@Buf[0];
                C:=P^;
              end;
             if C in [#10,#13] then
              Break;
             Inc(I);
             GetLineStr[I]:=C;
             Inc(P);
           until (I=255);
           GetLineStr[0]:=Chr(I);
         end;
      end;


    function TInputFile.GetFileTime:LongInt;
      begin
        if FileTime=-1 then
         FileGetTime;
        GetFileTime:=FileTime;
      end;


{****************************************************************************
                                TDOSINPUTFILE
 ****************************************************************************}

    function TDOSInputFile.FileOpen(const FileName: TPathStr): Boolean;
      begin
        { Check if file exists, this will also check if it is
          a real file and not a directory }
        if not FileExists(FileName,False) then
          begin
            Result:=False;
            Exit;
          end;
        { Open file }
        FileOpen:=False;
        try
          F:=CFileStreamClass.Create(FileName,fmOpenRead);
          FileOpen:=CStreamError=0;
        except
        end;
      end;


    function TDOSInputFile.FileSeek(Pos: LongInt): Boolean;
      begin
        FileSeek:=False;
        try
          F.Position:=Pos;
          FileSeek:=True;
        except
        end;
      end;


    function TDOSInputFile.FileRead(var DataBuf; MaxSize: LongInt): LongInt;
      begin
        FileRead:=F.Read(DataBuf,MaxSize);
      end;


    function TDOSInputFile.FileEOF: Boolean;
      begin
        FileEOF:=F.EOF();
      end;


    function TDOSInputFile.FileClose: Boolean;
      begin
        FileClose:=False;
        try
          F.Free;
          F := nil;
          FileClose:=True;
        except
        end;
      end;


    procedure TDOSInputFile.FileGetTime;
      begin
        FileTime:=GetNamedFileTime(Path+Name);
      end;


{****************************************************************************
                                Tinputfilemanager
 ****************************************************************************}

    constructor TInputFileManager.Create;
      begin
      end;


    destructor TInputFileManager.Destroy;
      var
         IFile : SizeInt;
      begin
         for IFile:=0 to NFiles-1 do
          FreeAndNil(Files[IFile]);
         FreeMem(Files);
      end;


    procedure TInputFileManager.Register_File(F : TInputFile);
      begin
         { don't register macro's }
         if F.IsMacro then
          Exit;

         if NFiles=AFiles then
          begin
            AFiles:=AFiles+4+SizeUInt(AFiles) div 4+SizeUInt(AFiles) div 8;
            ReallocMem(Files,AFiles*SizeOf(Files[0]));
          end;
         F.RefIndex:=1+NFiles;
         Files[NFiles]:=F;
         Inc(NFiles);

{$ifndef GENERIC_CPU}
{$ifdef heaptrc}
         ppheap_register_file(F.Path+F.Name,CurrentModule.ModuleID*100000+F.RefIndex);
{$endif heaptrc}
{$endif not GENERIC_CPU}
      end;


   function TInputFileManager.Get_File(L :LongInt) : TInputFile;
     begin
       if not ((L>=1) and (L<=NFiles)) then
         Exit(nil);
       Result:=Files[L-1];
     end;


   function TInputFileManager.Get_File_Name(L :LongInt):TPathStr;
     var
       HP : TInputFile;
     begin
       HP:=Get_File(L);
       if Assigned(HP) then
        Get_File_Name:=HP.Name
       else
        Get_File_Name:='';
     end;


   function TInputFileManager.Get_File_Path(L :LongInt):TPathStr;
     var
       HP : TInputFile;
     begin
       HP:=Get_File(L);
       if Assigned(HP) then
        Get_File_Path:=HP.Path
       else
        Get_File_Path:='';
     end;


{****************************************************************************
                                TModuleBase
 ****************************************************************************}

    procedure TModuleBase.SetFileName(const FN:TPathStr;AllowOutput:Boolean);
      var
        P, N,
        Prefix,
        Suffix : TPathStr;
      begin
         { Create names }
         ParamFN := FN;
         ParamAllowOutput := AllowOutput;
         P := FixPath(ExtractFilePath(FN),False);
         N := FixFileName(ChangeFileExt(ExtractFileName(FN),''));
         { set path }
         Path:=P;
         { obj,asm,ppu names }
         if AllowOutput then
           begin
             if (OutputUnitDir<>'') then
               P:=OutputUnitDir
             else
               if (OutputExeDir<>'') then
                 P:=OutputExeDir;
           end;
         OutputPath:=P;
         AsmFileName:=P+N+TargetInfo.ASMExt;
         ObjFileName:=P+N+TargetInfo.ObjExt;
         PPUFileName:=P+N+TargetInfo.UnitExt;
         ImportLibFileName:=P+TargetInfo.ImportLibPrefix+N+TargetInfo.ImportLibExt;
         StaticLibFileName:=P+TargetInfo.StaticLibPrefix+N+TargetInfo.StaticLibExt;
         ExportFileName:=P+'exp'+N+TargetInfo.ObjExt;

         { output dir of exe can be specified separately }
         if AllowOutput and (OutputExeDir<>'') then
           P:=OutputExeDir
         else
           P:=Path;

         { lib and exe could be loaded with a file specified with -o }
         if AllowOutput and IsInitial and
            (OutputFileName<>'')then
           begin
             ExeFileName:=P+OutputFileName;
             SharedLibFileName:=P+OutputFileName;
             N:=ChangeFileExt(OutputFileName,''); { for mapfilename and dbgfilename }
           end
         else
           begin
             ExeFileName:=P+N+TargetInfo.ExeExt;
             if Assigned(OutputPrefix) then
               Prefix := OutputPrefix^
             else
               Prefix := TargetInfo.SharedLibPrefix;
             if Assigned(OutputSuffix) then
               Suffix := OutputSuffix^
             else
               Suffix := '';
             SharedLibFileName:=P+Prefix+N+Suffix+TargetInfo.SharedLibExt;
           end;
         MapFileName:=P+N+'.map';
         DbgFileName:=P+N+'.dbg';
      end;


    constructor TModuleBase.Create(const S:string);
      begin
        ModuleName:=StringDup(Upper(S));
        RealModuleName:=StringDup(S);
        MainSource:='';
        PPUFileName:='';
        ObjFileName:='';
        AsmFileName:='';
        ImportLibFileName:='';
        StaticLibFileName:='';
        SharedLibFileName:='';
        ExeFileName:='';
        DbgFileName:='';
        MapFileName:='';
        OutputPath:='';
        ParamFN:='';
        Path:='';
        { status }
        State:=ms_registered;
        { unit index }
        Inc(Global_Unit_Count);
        ModuleID:=Global_Unit_Count;
        { sources }
        SourceFiles:=TInputFileManager.Create;
      end;


    destructor TModuleBase.Destroy;
      begin
        if Assigned(SourceFiles) then
         SourceFiles.Free;
        SourceFiles:=nil;
        StringDispose(ModuleName);
        StringDispose(RealModuleName);
        inherited Destroy;
      end;

end.
