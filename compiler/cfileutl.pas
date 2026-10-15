{
    Copyright (c) 1998-2002 by Florian Klaempfl and Peter Vreman

    This module provides some basic file/dir handling utils and classes

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
unit cfileutl;

{$i fpcdefs.inc}

{$define usedircache}

interface

    uses
{$ifdef hasunix}
      BaseUnix,Unix,
{$endif hasunix}
{$ifdef win32}
      Windows,
{$endif win32}
{$IFNDEF USE_FAKE_SYSUTILS}
      SysUtils,
{$ELSE}
      FKSysUtl,
{$ENDIF}
      GlobType,
      CUtils,CClasses,
      Systems;

    type
      TCachedDirectory = class(TFPHashObject)
      private
        FDirectoryEntries : TFPHashList;
        FCached : Boolean;
        procedure FreeDirectoryEntries;
        function GetItemAttr(const AName: TCmdStr): LongInt;
        function TryUseCache: Boolean;
        procedure ForceUseCache;
        procedure Reload;
      public
        constructor Create(AList:TFPHashObjectList;const AName:TCmdStr);
        destructor  Destroy;override;
        function FileExists(const AName:TCmdStr):Boolean;
        function FileExistsCaseAware(const Path, FN: TCmdStr; out FoundName: TCmdStr):Boolean;
        function DirectoryExists(const AName:TCmdStr):Boolean;
        property DirectoryEntries:TFPHashList read FDirectoryEntries;
      end;

      TCachedSearchRec = record
        Name       : TCmdStr;
        Attr       : LongInt;
        Pattern    : TCmdStr;
        CachedDir  : TCachedDirectory;
        EntryIndex : LongInt;
      end;

      PCachedDirectoryEntry =  ^TCachedDirectoryEntry;
      TCachedDirectoryEntry = record
        RealName: TCmdStr;
        Attr    : LongInt;
      end;

      TDirectoryCache = class
      private
        FDirectories : TFPHashObjectList;
        function GetDirectory(const ADir:TCmdStr):TCachedDirectory;
      public
        constructor Create;
        destructor  Destroy;override;
        function FileExists(const AName:TCmdStr):Boolean;
        function FileExistsCaseAware(const Path, FN: TCmdStr; out FoundName: TCmdStr):Boolean;
        function DirectoryExists(const AName:TCmdStr):Boolean;
        function FindFirst(const APattern:TCmdStr;var Res:TCachedSearchRec):Boolean;
        function FindNext(var Res:TCachedSearchRec):Boolean;
        function FindClose(var Res:TCachedSearchRec):Boolean;
      end;

      TSearchPathList = class(TCmdStrList)
        procedure AddPath(S:TCmdStr;AddFirst:Boolean);overload;
        procedure AddLibraryPath(const SysRoot: TCmdStr; S:TCmdStr;AddFirst:Boolean);overload;
        procedure AddList(List:TSearchPathList;AddFirst:Boolean);
        function  FindFile(const F : TCmdStr;AllowCache:Boolean;var FoundFile:TCmdStr):Boolean;
      end;

    function  BSToSlash(const S : TCmdStr) : TCmdStr;
    {Gives the absolute path to the current directory}
    function  GetCurrentDir:TCmdStr;
    {Gives the relative path to the current directory,
     with a trailing dir separator. E. g. on unix ./ }
    function CurDirRelPath(SystemInfo: TSystemInfo): TCmdStr;
    function  Path_Absolute(const S : TCmdStr) : Boolean;
    Function  PathExists (const F : TCmdStr;AllowCache:Boolean) : Boolean;
    Function  FileExists (const F : TCmdStr;AllowCache:Boolean) : Boolean;
    function  FileExistsNonCase(const Path,FN:TCmdStr;AllowCache:Boolean;var FoundFile:TCmdStr):Boolean;
    Function  RemoveDir(D:TCmdStr):Boolean;
    Function  FixPath(const S:TCmdStr;AllowDot:Boolean):TCmdStr;
    function  FixFileName(const S:TCmdStr):TCmdStr;
    function  TargetFixPath(S:TCmdStr;AllowDot:Boolean):TCmdStr;
    function  TargetFixFileName(const S:TCmdStr):TCmdStr;
    procedure SplitBinCmd(const S:TCmdStr;var BStr: TCmdStr;var CStr:TCmdStr);
    function  FindFile(const F : TCmdStr; const Path : TCmdStr;AllowCache:Boolean;var FoundFile:TCmdStr):Boolean;
{    function  FindFilePchar(const f : TCmdStr;path : pchar;allowcache:boolean;var foundfile:TCmdStr):boolean;}
    function  FindFileInExeLocations(const Bin:TCmdStr;AllowCache:Boolean;var FoundFile:TCmdStr):Boolean;
    function  FindExe(const Bin:TCmdStr;AllowCache:Boolean;var FoundFile:TCmdStr):Boolean;
    function  GetShortName(const N:TCmdStr):TCmdStr;
    function MaybeQuoted(const S:ShortString):ShortString;
    function MaybeQuoted(const S:AnsiString):AnsiString;
    function MaybeQuoted_For_Script(const S:AnsiString; QuoteScript: TScriptType):AnsiString;

    procedure InitFileUtils;
    procedure DoneFileUtils;

    function UnixRequoteWithDoubleQuotes(const QuotedStr: TCmdStr): TCmdStr;
    function RequotedExecuteProcess(const Path: AnsiString; const ComLine: AnsiString; Flags: TExecuteFlags = []): LongInt;
    function RequotedExecuteProcess(const Path: AnsiString; const ComLine: array of AnsiString; Flags: TExecuteFlags = []): LongInt;
    function Shell(const Command:AnsiString): LongInt;

  { hide Sysutils.ExecuteProcess in units using this one after SysUtils}
  const
    ExecuteProcess = 'Do not use' deprecated 'Use cfileutil.RequotedExecuteProcess instead, ExecuteProcess cannot deal with single quotes as used by Unix command lines';

function Unix2AmigaPath(Path: String): String;

implementation

    uses
      CompHook,
      Globals;

    var
      DirCache : TDirectoryCache;


function Unix2AmigaPath(Path: String): String;
begin
  Unix2AmigaPath:=Path;
end;



{****************************************************************************
                           TCachedDirectory
****************************************************************************}

    constructor TCachedDirectory.Create(AList:TFPHashObjectList;const AName:TCmdStr);
      begin
        inherited Create(AList,AName);
        FDirectoryEntries:=TFPHashList.Create;
        FCached:=False;
      end;


    destructor TCachedDirectory.Destroy;
      begin
        FreeDirectoryEntries;
        FDirectoryEntries.Free;
        FDirectoryEntries := nil;
        inherited Destroy;
      end;


    function TCachedDirectory.TryUseCache:Boolean;
      begin
        Result:=True;
        if FCached then
          Exit;
        if not CurrentSettings.DisableDirCache then
          ForceUseCache
        else
          Result:=False;
      end;


    procedure TCachedDirectory.ForceUseCache;
      begin
        if not FCached then
          begin
            FCached:=True;
            Reload;
          end;
      end;


    procedure TCachedDirectory.FreeDirectoryEntries;
      var
        I: Integer;
      begin
        if not(tf_files_case_aware in SourceInfo.Flags) then
          Exit;
        for I := 0 to DirectoryEntries.Count-1 do
          Dispose(PCachedDirectoryEntry(DirectoryEntries[I]));
      end;


    function TCachedDirectory.GetItemAttr(const AName: TCmdStr): LongInt;
      var
        Entry: PCachedDirectoryEntry;
      begin
        if not(tf_files_case_sensitive in SourceInfo.Flags) then
          if (tf_files_case_aware in SourceInfo.Flags) then
            begin
              Entry:=PCachedDirectoryEntry(DirectoryEntries.Find(Lower(AName)));
              if Assigned(Entry) then
                Result:=Entry^.Attr
              else
                Result:=0;
            end
          else
            Result:=PtrUInt(DirectoryEntries.Find(Lower(AName)))
        else
          Result:=PtrUInt(DirectoryEntries.Find(AName));
      end;


    procedure TCachedDirectory.Reload;
      var
        Dir   : TRawByteSearchRec;
        Entry : PCachedDirectoryEntry;
      begin
        FreeDirectoryEntries;
        DirectoryEntries.Clear;
        if FindFirst(IncludeTrailingPathDelimiter(Name)+AllFilesMask,faAnyFile or faDirectory,Dir) = 0 then
          begin
            repeat
              if ((Dir.Attr and faDirectory)<>faDirectory) or
                 ((Dir.Name<>'.') and
                  (Dir.Name<>'..')) then
                begin
                  { Force Archive bit so the attribute always has a value. This is needed
                    to be able to see the difference in the directoryentries lookup if a file
                    exists or not }
                  Dir.Attr:=Dir.Attr or faArchive;
                  if not(tf_files_case_sensitive in SourceInfo.Flags) then
                    if (tf_files_case_aware in SourceInfo.Flags) then
                      begin
                        New(Entry);
                        Entry^.RealName:=Dir.Name;
                        Entry^.Attr:=Dir.Attr;
                        DirectoryEntries.Add(Lower(Dir.Name),Entry)
                      end
                    else
                      DirectoryEntries.Add(Lower(Dir.Name),Pointer(PtrInt(Dir.Attr)))
                  else
                    DirectoryEntries.Add(Dir.Name,Pointer(PtrInt(Dir.Attr)));
                end;
            until FindNext(Dir) <> 0;
            FindClose(Dir);
          end;
      end;


    function TCachedDirectory.FileExists(const AName:TCmdStr):Boolean;
      var
        Attr : LongInt;
      begin
        if not TryUseCache then
          begin
            { prepend directory name again }
            Result:=CFileUtl.FileExists(Name+AName,False);
            Exit;
          end;
        Attr:=GetItemAttr(AName);
        if Attr<>0 then
          Result:=((Attr and faDirectory)=0)
        else
          Result:=False;
      end;


    function TCachedDirectory.FileExistsCaseAware(const Path, FN: TCmdStr; out FoundName: TCmdStr):Boolean;
      var
        Entry : PCachedDirectoryEntry;
      begin
        if (tf_files_case_aware in SourceInfo.Flags) then
          begin
            if not TryUseCache then
              begin
                Result:=FileExistsNonCase(Path,FN,False,FoundName);
                Exit;
              end;
            Entry:=PCachedDirectoryEntry(DirectoryEntries.Find(Lower(ExtractFileName(FN))));
            if Assigned(Entry) and
               (Entry^.Attr<>0) and
               ((Entry^.Attr and faDirectory) = 0) then
              begin
                 FoundName:=ExtractFilePath(Path+FN)+Entry^.RealName;
                 Result:=True
              end
            else
              Result:=False;
          end
        else
          { should not be called in this case, use plain FileExists }
          Result:=False;
      end;


    function TCachedDirectory.DirectoryExists(const AName:TCmdStr):Boolean;
      var
        Attr : LongInt;
      begin
        if not TryUseCache then
          begin
            Result:=PathExists(Name+AName,False);
            Exit;
          end;
        Attr:=GetItemAttr(AName);
        if Attr<>0 then
          Result:=((Attr and faDirectory)=faDirectory)
        else
          Result:=False;
      end;


{****************************************************************************
                           TDirectoryCache
****************************************************************************}

    constructor TDirectoryCache.Create;
      begin
        inherited Create;
        FDirectories:=TFPHashObjectList.Create(True);
      end;


    destructor TDirectoryCache.Destroy;
      begin
        FDirectories.Free;
        FDirectories := nil;
        inherited Destroy;
      end;


    function TDirectoryCache.GetDirectory(const ADir:TCmdStr):TCachedDirectory;
      var
        CachedDir : TCachedDirectory;
        DirName   : TCmdStr;
      begin
        if ADir='' then
          DirName:='.'+SourceInfo.DirSep
        else
          DirName:=ADir;
        CachedDir:=TCachedDirectory(FDirectories.Find(DirName));
        if not Assigned(CachedDir) then
          CachedDir:=TCachedDirectory.Create(FDirectories,DirName);
        Result:=CachedDir;
      end;


    function TDirectoryCache.FileExists(const AName:TCmdStr):Boolean;
      var
        CachedDir : TCachedDirectory;
      begin
        Result:=False;
        CachedDir:=GetDirectory(ExtractFilePath(AName));
        if Assigned(CachedDir) then
          Result:=CachedDir.FileExists(ExtractFileName(AName));
      end;


    function TDirectoryCache.FileExistsCaseAware(const Path, FN: TCmdStr; out FoundName: TCmdStr):Boolean;
      var
        CachedDir : TCachedDirectory;
      begin
        Result:=False;
        CachedDir:=GetDirectory(ExtractFilePath(Path+FN));
        if Assigned(CachedDir) then
          Result:=CachedDir.FileExistsCaseAware(Path,FN,FoundName);
      end;


    function TDirectoryCache.DirectoryExists(const AName:TCmdStr):Boolean;
      var
        CachedDir : TCachedDirectory;
      begin
        Result:=False;
        CachedDir:=GetDirectory(ExtractFilePath(AName));
        if Assigned(CachedDir) then
          Result:=CachedDir.DirectoryExists(ExtractFileName(AName));
      end;


    function TDirectoryCache.FindFirst(const APattern:TCmdStr;var Res:TCachedSearchRec):Boolean;
      begin
        Res.Pattern:=ExtractFileName(APattern);
        Res.CachedDir:=GetDirectory(ExtractFilePath(APattern));
        Res.CachedDir.ForceUseCache;
        Res.EntryIndex:=0;
        if Assigned(Res.CachedDir) then
          Result:=FindNext(Res)
        else
          Result:=False;
      end;


    function TDirectoryCache.FindNext(var Res:TCachedSearchRec):Boolean;
      var
        Entry: PCachedDirectoryEntry;
      begin
        if Res.EntryIndex<Res.CachedDir.DirectoryEntries.Count then
          begin
            if (tf_files_case_aware in SourceInfo.Flags) then
              begin
                Entry:=Res.CachedDir.DirectoryEntries[Res.EntryIndex];
                Res.Name:=Entry^.RealName;
                Res.Attr:=Entry^.Attr;
              end
            else
              begin
                Res.Name:=Res.CachedDir.DirectoryEntries.NameOfIndex(Res.EntryIndex);
                Res.Attr:=PtrUInt(Res.CachedDir.DirectoryEntries[Res.EntryIndex]);
              end;
            Inc(Res.EntryIndex);
            Result:=True;
          end
        else
          Result:=False;
      end;


    function TDirectoryCache.FindClose(var Res:TCachedSearchRec):Boolean;
      begin
        { nothing todo }
        Result:=True;
      end;


{****************************************************************************
                                   Utils
****************************************************************************}

    function BSToSlash(const S : TCmdStr) : TCmdStr;
    {
      return TCmdStr s with all \ changed into /
    }
      var
         I : SizeInt;
      begin
        BSToSlash:=S;
        for I:=1 to Length(S) do
         if S[I]='\' then
          BSToSlash[I]:='/';
      end;


   {Gives the absolute path to the current directory}
     var
       CachedCurrentDir : TCmdStr;
   function GetCurrentDir:TCmdStr;
     begin
       if CachedCurrentDir='' then
         begin
           GetDir(0,CachedCurrentDir);
           CachedCurrentDir:=FixPath(CachedCurrentDir,False);
         end;
       Result:=CachedCurrentDir;
     end;

   {Gives the relative path to the current directory,
    with a trailing dir separator. E. g. on unix ./ }
   function CurDirRelPath(SystemInfo: TSystemInfo): TCmdStr;

   begin
     CurDirRelPath:= '.'+SystemInfo.DirSep
   end;


   function Path_Absolute(const S : TCmdStr) : Boolean;
   {
     is path s an absolute path?
   }
     begin
        Result:=False;
{$if defined(unix)}
        if (Length(S)>0) and (S[1] in AllowDirectorySeparators) then
          Result:=True;
{$elseif defined(win32) or defined(win64)}
        if ((Length(S)>0) and (S[1] in AllowDirectorySeparators)) or
(* The following check for non-empty AllowDriveSeparators assumes that all
   other platforms supporting drives and not handled as exceptions above
   should work with DOS-like paths, i.e. use absolute paths with one letter
   for drive followed by path separator *)
           ((Length(S)>2) and (S[2] in AllowDriveSeparators) and (S[3] in AllowDirectorySeparators)) then
          Result:=True;
{$else}
        if ((Length(S)>0) and (S[1] in AllowDirectorySeparators)) or
(* The following check for non-empty AllowDriveSeparators assumes that all
   other platforms supporting drives and not handled as exceptions above
   should work with DOS-like paths, i.e. use absolute paths with one letter
   for drive followed by path separator *)
           ((AllowDriveSeparators <> []) and (Length(S)>2) and (S[2] in AllowDriveSeparators) and (S[3] in AllowDirectorySeparators)) then
          Result:=True;
{$endif unix}
     end;

    Function FileExists ( Const F : TCmdStr;AllowCache:Boolean) : Boolean;
      begin
{$ifdef usedircache}
        if AllowCache then
          Result:=DirCache.FileExists(F)
        else
{$endif usedircache}
          Result:=SysUtils.FileExists(F);
        if Do_CheckVerbosity(VTried) then
         begin
           if Result then
             Do_Comment(VTried,'Searching file '+F+'... found')
           else
             Do_Comment(VTried,'Searching file '+F+'... not found');
         end;
      end;


    function FileExistsNonCase(const Path,FN:TCmdStr;AllowCache:Boolean;var FoundFile:TCmdStr):Boolean;
      var
        FN2 : TCmdStr;
      begin
        Result:=False;
        if tf_files_case_sensitive in SourceInfo.Flags then
          begin
            {
              Search order for case sensitive systems:
               1. NormalCase
               2. lowercase
               3. UPPERCASE
            }
            FoundFile:=Path+FN;
            If (ftNone in AllowedFilenameTransFormations) and FileExists(FoundFile,AllowCache) then
             begin
               Result:=True;
               Exit;
             end;
            if (ftLowerCase in AllowedFilenameTransFormations) then
              begin
                FN2:=Lower(FN);
                if (FN2<>FN) then
                  begin
                    FoundFile:=Path+FN2;
                    If FileExists(FoundFile,AllowCache) then
                     begin
                       Result:=True;
                       Exit;
                     end;
                  end;
              end;
            if (ftUpperCase in AllowedFilenameTransFormations)  then
              begin
                FN2:=Upper(FN);
                if (FN2<>FN) then
                  begin
                  FoundFile:=Path+FN2;
                  If FileExists(FoundFile,AllowCache) then
                    begin
                      Result:=True;
                      Exit;
                    end;
                  end;
              end;
          end
        else
          if tf_files_case_aware in SourceInfo.Flags then
            begin
              {
                Search order for case aware systems:
                 1. NormalCase
              }
{$ifdef usedircache}
              if AllowCache then
                begin
                  Result:=DirCache.FileExistsCaseAware(Path,FN,FN2);
                  if Result then
                    begin
                      FoundFile:=FN2;
                      Exit;
                    end;
                end
              else
{$endif usedircache}
                begin
                  FoundFile:=Path+FN;
                  If FileExists(FoundFile,AllowCache) then
                    begin
                      { don't know the real name in this case }
                      Result:=True;
                      Exit;
                   end;
                end;
           end
        else
          begin
            { None case sensitive only lowercase }
            FoundFile:=Path+Lower(FN);
            If FileExists(FoundFile,AllowCache) then
             begin
               Result:=True;
               Exit;
             end;
          end;
        { Set foundfile to something useful }
        FoundFile:=FN;
      end;


    Function PathExists (const F : TCmdStr;AllowCache:Boolean) : Boolean;
      Var
        I: LongInt;
        HS : TCmdStr;
      begin
        if F = '' then
          begin
            Result := True;
            Exit;
          end;
        HS := ExpandFileName(F);
        I := Pos (DriveSeparator, HS);
        if (HS [Length (HS)] = DirectorySeparator) and
           (((I = 0) and (Length (HS) > 1)) or (I <> Length (HS) - 1)) then
          Delete (HS, Length (HS), 1);
{$ifdef usedircache}
        if AllowCache then
          Result:=DirCache.DirectoryExists(HS)
        else
{$endif usedircache}
          Result:=SysUtils.DirectoryExists(HS);
      end;


    Function RemoveDir(D:TCmdStr):Boolean;
      begin
        if D[Length(D)]=SourceInfo.DirSep then
         Delete(D,Length(D),1);
        {$push}{$I-}
         RmDir(D);
        {$pop}
        RemoveDir:=(IOResult=0);
      end;


    Function InternalFixPath(const S:TCmdStr;AllowDot:Boolean;const Info:TSystemInfo;const DriveSep:string):TCmdStr;
      var
        I, L : SizeInt;
      begin
        Result := S;
        L := Length(Result);
        if L=0 then
          Exit;
        { Fix separator }
        for I:=1 to L do
          if (Result[I] in ['/','\']) and (Result[I]<>Info.DirSep) then
            Result[I]:=Info.DirSep;
        { Remove . or ./ }
        if (not AllowDot) and (Result[1]='.') and ((L=1) or (L=2) and (Result[2]=Info.DirSep)) then
          Exit('');
        { Fix ending / }
        if (Result[L]<>Info.DirSep) and (Result[L]<>DriveSep) then
          Result:=Result+Info.DirSep;
        { return }
        if not ((tf_files_case_aware in Info.Flags) or
           (tf_files_case_sensitive in Info.Flags)) then
          Result := Lower(Result);
      end;


    Function FixPath(const S:TCmdStr;AllowDot:Boolean):TCmdStr;
      begin
        Result:=InternalFixPath(S,AllowDot,SourceInfo,DriveSeparator);
      end;


   function InternalFixFileName(const S:TCmdStr; const Info:TSystemInfo):TCmdStr;
     var
       I      : SizeInt;
     begin
       if (tf_files_case_aware in Info.Flags) or
          (tf_files_case_sensitive in Info.Flags) then
         Result:=S
       else
         Result:=Lower(S);
       for I:=1 to Length(S) do
        case S[I] of
          '/','\' :
            if S[I]<>Info.DirSep then
              Result[I]:=Info.DirSep;
        end;
     end;


   function FixFileName(const S:TCmdStr):TCmdStr;
     begin
       Result:=InternalFixFileName(S,SourceInfo);
     end;


   Function TargetFixPath(S:TCmdStr;AllowDot:Boolean):TCmdStr;
     begin
       Result:=InternalFixPath(S,AllowDot,TargetInfo,':');
     end;


   function TargetFixFileName(const S:TCmdStr):TCmdStr;
     begin
       Result:=InternalFixFileName(S,TargetInfo);
     end;


   procedure SplitBinCmd(const S:TCmdStr;var BStr:TCmdStr;var CStr:TCmdStr);
     var
       I : LongInt;
     begin
       I:=Pos(' ',S);
       if I>0 then
        begin
          BStr:=Copy(S,1,I-1);
          CStr:=Copy(S,I+1,Length(S)-I);
        end
       else
        begin
          BStr:=S;
          CStr:='';
        end;
     end;


    procedure TSearchPathList.AddPath(S:TCmdStr;AddFirst:Boolean);
      begin
        AddLibraryPath('',S,AddFirst);
      end;


   procedure TSearchPathList.AddLibraryPath(const SysRoot: TCmdStr; S:TCmdStr;AddFirst:Boolean);
     var
       StarIdx,
       I,J      : LongInt;
       Prefix,
       Suffix,
       CurrentDir,
       CurrPath : TCmdStr;
       SubDirFound : Boolean;
{$ifdef usedircache}
       Dir      : TCachedSearchRec;
{$else usedircache}
       Dir      : TSearchRec;
{$endif usedircache}
       HP       : TCmdStrListItem;

       procedure WarnNonExistingPath(const Path : TCmdStr);
       begin
         if Do_CheckVerbosity(VTried) then
           Do_Comment(VTried,'Path "'+Path+'" not found');
       end;

       procedure AddCurrPath;
       begin
         if AddFirst then
          begin
            Remove(CurrPath);
            Insert(CurrPath);
          end
         else
          begin
            { Check if already in path, then we don't add it }
            HP:=Find(CurrPath);
            if not Assigned(HP) then
             Concat(CurrPath);
          end;
       end;

     begin
       if S='' then
        Exit;
     { Support default macro's }
       DefaultReplacements(S);
{$warnings off}
       if PathSeparator <> ';' then
        for I:=1 to Length(S) do
         if S[I]=PathSeparator then
          S[I]:=';';
{$warnings on}
     { get current dir }
       CurrentDir:=GetCurrentDir;
       repeat
         { get currpath }
         if AddFirst then
          begin
            J:=Length(S);
            while (J>0) and (S[J]<>';') do
             Dec(J);
            CurrPath:= TrimSpace(Copy(S,J+1,Length(S)-J));
            if J=0 then
             S:=''
            else
             System.Delete(S,J,Length(S)-J+1);
          end
         else
          begin
            J:=Pos(';',S);
            if J=0 then
             J:=Length(S)+1;
            CurrPath:= TrimSpace(Copy(S,1,J-1));
            System.Delete(S,1,J);
          end;

         { fix pathname }
         DePascalQuote(CurrPath);
         { GNU LD convention: if library search path starts with '=', it's relative to the
           sysroot; otherwise, interpret it as a regular path }
         if (Length(CurrPath) >0) and (CurrPath[1]='=') then
           CurrPath:=SysRoot+FixPath(Copy(CurrPath,2,Length(CurrPath)-1),False);
         if CurrPath='' then
           CurrPath:= CurDirRelPath(SourceInfo)
         else
          begin
            CurrPath:=FixPath(ExpandFileName(CurrPath),False);
            if (CurrentDir<>'') and (Copy(CurrPath,1,Length(CurrentDir))=CurrentDir) then
             begin
               CurrPath:= CurDirRelPath(SourceInfo)+Copy(CurrPath,Length(CurrentDir)+1,Length(CurrPath));
             end;
          end;
         { wildcard adding ? }
         StarIdx:=Pos('*',CurrPath);
         if StarIdx>0 then
          begin
            Prefix:=ExtractFilePath(Copy(CurrPath,1,StarIdx));
            Suffix:=Copy(CurrPath,StarIdx+1,Length(CurrPath));
            SubDirFound:=False;
{$ifdef usedircache}
            if DirCache.FindFirst(Prefix+AllFilesMask,Dir) then
              begin
                repeat
                  if (Dir.Attr and faDirectory)<>0 then
                    begin
                      SubDirFound:=True;
                      CurrPath:=Prefix+Dir.Name+Suffix;
                      if (Suffix='') or PathExists(CurrPath,True) then
                        begin
                          HP:=Find(CurrPath);
                          if not Assigned(HP) then
                            AddCurrPath;
                        end;
                    end;
                until not DirCache.FindNext(Dir);
              end;
            DirCache.FindClose(Dir);
{$else usedircache}
            if FindFirst(Prefix+AllFilesMask,faDirectory,Dir) = 0 then
              begin
                repeat
                  if (Dir.Name<>'.') and
                      (Dir.Name<>'..') and
                      ((Dir.Attr and faDirectory)<>0) then
                    begin
                      SubDirFound:=True;
                      CurrPath:=Prefix+Dir.Name+Suffix;
                      if (Suffix='') or PathExists(CurrPath,False) then
                        begin
                          HP:=Find(CurrPath);
                          if not Assigned(HP) then
                            AddCurrPath;
                        end;
                    end;
                until FindNext(Dir) <> 0;
                FindClose(Dir);
              end;
{$endif usedircache}
            if not SubDirFound then
              WarnNonExistingPath(CurrPath);
          end
         else
          begin
            if PathExists(CurrPath,True) then
             AddCurrPath
            else
             WarnNonExistingPath(CurrPath);
          end;
       until (S='');
     end;


   procedure TSearchPathList.AddList(List:TSearchPathList;AddFirst:Boolean);
     var
       S : TCmdStr;
       HL : TSearchPathList;
       HP,HP2 : TCmdStrListItem;
     begin
       if List.Empty then
        Exit;
       { create temp and reverse the list }
       if AddFirst then
        begin
          HL:=TSearchPathList.Create;
          HP:=TCmdStrListItem(List.First);
          while Assigned(HP) do
           begin
             HL.Insert(HP.Str);
             HP:=TCmdStrListItem(HP.Next);
           end;
          while not HL.Empty do
           begin
             S:=HL.GetFirst;
             Remove(S);
             Insert(S);
           end;
          HL.Free;
          HL := nil;
        end
       else
        begin
          HP:=TCmdStrListItem(List.First);
          while Assigned(HP) do
           begin
             HP2:=Find(HP.Str);
             { Check if already in path, then we don't add it }
             if not Assigned(HP2) then
              Concat(HP.Str);
             HP:=TCmdStrListItem(HP.Next);
           end;
        end;
     end;


   function TSearchPathList.FindFile(const F :TCmdStr;AllowCache:Boolean;var FoundFile:TCmdStr):Boolean;
     Var
       P : TCmdStrListItem;
     begin
       FindFile:=False;
       P:=TCmdStrListItem(First);
       while Assigned(P) do
        begin
          Result:=FileExistsNonCase(P.Str,F,AllowCache,FoundFile);
          if Result then
            Exit;
          P:=TCmdStrListItem(P.Next);
        end;
       { Return original filename if not found }
       FoundFile:=F;
     end;


   function FindFile(const F : TCmdStr; const Path : TCmdStr;AllowCache:Boolean;var FoundFile:TCmdStr):Boolean;
     Var
       StartPos, EndPos, L: LongInt;
     begin
       Result:=False;

       if (Path_Absolute(F)) then
         begin
           Result:=FileExistsNonCase('',F, AllowCache, FoundFile);
           if Result then
             Exit;
         end;

       StartPos := 1;
       L := Length(Path);
       repeat
         EndPos := StartPos;
         while (EndPos <= L) and ((Path[EndPos] <> PathSeparator) and (Path[EndPos] <> ';')) do
           Inc(EndPos);
         Result := FileExistsNonCase(FixPath(Copy(Path, StartPos, EndPos-StartPos), False), F, AllowCache, FoundFile);
         if Result then
           Exit;
         StartPos := EndPos + 1;
       until StartPos > L;
       FoundFile:=F;
     end;

{
   function FindFilePchar(const f : TCmdStr;path : pchar;allowcache:boolean;var foundfile:TCmdStr):boolean;
      Var
        singlepathstring : TCmdStr;
        startpc,pc : pchar;
     begin
       FindFilePchar:=false;
       if Assigned (Path) then
        begin
          pc:=path;
          repeat
             startpc:=pc;
             while (pc^<>PathSeparator) and (pc^<>';') and (pc^<>#0) do
              inc(pc);
             SetLength(singlepathstring, pc-startpc);
             move(startpc^,singlepathstring[1],pc-startpc);
             singlepathstring:=FixPath(ExpandFileName(singlepathstring),false);
             result:=FileExistsNonCase(singlepathstring,f,allowcache,FoundFile);
             if result then
               exit;
             if (pc^=#0) then
               break;
             inc(pc);
          until false;
        end;
       foundfile:=f;
     end;
}

  function  FindFileInExeLocations(const Bin:TCmdStr;AllowCache:Boolean;var FoundFile:TCmdStr):Boolean;
    var
      Path : TCmdStr;
      Found : Boolean;
    begin
       Found:=FindFile(FixFileName(Bin),ExePath,AllowCache,FoundFile);
      if not Found then
       begin
         Path:=GetEnvironmentVariable('PATH');
         Found:=FindFile(FixFileName(Bin),Path,AllowCache,FoundFile);
       end;
      FindFileInExeLocations:=Found;
    end;


   function  FindExe(const Bin:TCmdStr;AllowCache:Boolean;var FoundFile:TCmdStr):Boolean;
     var
       B : TCmdStr;
     begin
       { change extension only on platforms that use an exe extension, otherwise on OpenBSD
         'ld.bfd' gets converted to 'ld' }
       if SourceInfo.ExeExt<>'' then
         B:=ChangeFileExt(Bin,SourceInfo.ExeExt)
       else
         B:=Bin;
       FindExe:=FindFileInExeLocations(B,AllowCache,FoundFile);
     end;


    function GetShortName(const N:TCmdStr):TCmdStr;
{$ifdef win32}
      var
        HS,HS2 : TCmdStr;
        I : LongInt;
{$endif}
      begin
        GetShortName:=N;
{$ifdef win32}
        HS:=N+#0;
        HS2:='';
        { may become longer in case of e.g. ".a" -> "a~1" or so }
        SetLength(HS2,Length(HS)*2);
        I:=Windows.GetShortPathName(@HS[1],@HS2[1],Length(HS)*2);
        if (I>0) and (I<=Length(HS)*2) then
          begin
            SetLength(HS2,StrLen(@HS2[1]));
            GetShortName:=HS2;
          end;
{$endif}
      end;


    function MaybeQuoted(const S:ShortString):ShortString;
    const
      ForbiddenCharsDOS = ['!', '@', '#', '$', '%', '^', '&', '*', '(', ')',
                         '{', '}', '''', '`', '~'];
      ForbiddenCharsOther = ['!', '@', '#', '$', '%', '^', '&', '*', '(', ')',
                         '{', '}', '''', ':', '\', '`', '~'];
    var
      ForbiddenChars: set of Char;
      I  : Integer;
      QuoteScript: TScriptType;
      QuoteChar: AnsiChar;
      Quoted : Boolean;
    begin
      if not(cs_link_on_target in CurrentSettings.GlobalSwitches) then
        QuoteScript:=SourceInfo.Script
      else
        QuoteScript:=TargetInfo.Script;
      if QuoteScript=script_dos then
        ForbiddenChars:=ForbiddenCharsDOS
      else
        begin
          ForbiddenChars:=ForbiddenCharsOther;
          if QuoteScript=script_unix then
            Include(ForbiddenChars,'"');
        end;
      if QuoteScript=script_unix then
        QuoteChar:=''''
      else
        QuoteChar:='"';

      Quoted:=False;
      Result:=QuoteChar;
      for I:=1 to Length(S) do
       begin
         if S[I]=QuoteChar then
           begin
             Quoted:=True;
             Result:=Result+'\'+QuoteChar;
           end
         else case S[I] of
           '\':
             begin
               if QuoteScript=script_unix then
                 begin
                   Result:=Result+'\\';
                   Quoted:=True
                 end
               else
                 Result:=Result+'\';
             end;
           ' ',
           #128..#255 :
             begin
               Quoted:=True;
               Result:=Result+S[I];
             end;
           else begin
             if S[I] in ForbiddenChars then
               Quoted:=True;
             Result:=Result+S[I];
           end;
         end;
       end;
      if Quoted then
        Result:=Result+QuoteChar
      else
        Result:=S;
    end;


    function MaybeQuoted_For_Script(const S:AnsiString; QuoteScript: TScriptType):AnsiString;
      const
        ForbiddenCharsDOS = ['!', '@', '#', '$', '%', '^', '&', '*', '(', ')',
                           '{', '}', '''', '`', '~'];
        ForbiddenCharsOther = ['!', '@', '#', '$', '%', '^', '&', '*', '(', ')',
                           '{', '}', '''', ':', '\', '`', '~'];
      var
        ForbiddenChars: set of Char;
        I  : Integer;
        QuoteChar: AnsiChar;
        Quoted : Boolean;
      begin
        if QuoteScript=script_dos then
          ForbiddenChars:=ForbiddenCharsDOS
        else
          begin
            ForbiddenChars:=ForbiddenCharsOther;
            if QuoteScript=script_unix then
              Include(ForbiddenChars,'"');
          end;
        if QuoteScript=script_unix then
          QuoteChar:=''''
        else
          QuoteChar:='"';

        Quoted:=False;
        Result:=QuoteChar;
        for I:=1 to Length(S) do
         begin
           if S[I]=QuoteChar then
             begin
               Quoted:=True;
               Result:=Result+'\'+QuoteChar;
             end
           else case S[I] of
             '\':
               begin
                 if QuoteScript=script_unix then
                   begin
                     Result:=Result+'\\';
                     Quoted:=True
                   end
                 else
                   Result:=Result+'\';
               end;
             ' ',
             #128..#255 :
               begin
                 Quoted:=True;
                 Result:=Result+S[I];
               end;
             else begin
               if S[I] in ForbiddenChars then
                 Quoted:=True;
               Result:=Result+S[I];
             end;
           end;
         end;
        if Quoted then
          Result:=Result+QuoteChar
        else
          Result:=S;
      end;


    function MaybeQuoted(const S:AnsiString):AnsiString;
      var
        QuoteScript: TScriptType;
      begin
        if not(cs_link_on_target in CurrentSettings.GlobalSwitches) then
          QuoteScript:=SourceInfo.Script
        else
          QuoteScript:=TargetInfo.Script;
        Result:=MaybeQuoted_For_Script(S,QuoteScript);
      end;


    { requotes a string that was quoted for Unix for passing to ExecuteProcess,
      because it only supports Windows-style quoting; this routine assumes that
      everything that has to be quoted for Windows, was also quoted (but
      differently for Unix) -- which is the case }
    function UnixRequoteWithDoubleQuotes(const QuotedStr: TCmdStr): TCmdStr;
      var
        I: LongInt;
        Temp: TCmdStr;
        InQuotes: Boolean;
      begin
        if QuotedStr='' then
          begin
            Result:='';
            Exit;
          end;
        InQuotes:=False;
        Result:='';
        I:=1;
        Temp:='';
        while I<=Length(QuotedStr) do
          begin
            case QuotedStr[I] of
              '''':
                begin
                  if not(InQuotes) then
                    begin
                      InQuotes:=True;
                      Temp:=''
                    end
                  else
                    begin
                      { requote for Windows }
                      Result:=Result+MaybeQuoted_For_Script(Temp,script_dos);
                      InQuotes:=False;
                    end;
                end;
              '\':
                begin
                  if InQuotes then
                    Temp:=Temp+QuotedStr[I+1]
                  else
                    Result:=Result+QuotedStr[I+1];
                  Inc(I);
                end;
              else
                begin
                  if InQuotes then
                    Temp:=Temp+QuotedStr[I]
                  else
                    Result:=Result+QuotedStr[I];
                end;
            end;
            Inc(I);
          end;
      end;


    function RequotedExecuteProcess(const Path: AnsiString; const ComLine: AnsiString; Flags: TExecuteFlags): LongInt;
      var
        QuoteScript: TScriptType;
      begin

        if Do_CheckVerbosity(VExecutable) then
          Do_Comment(VExecutable,'Executing "'+Path+'" with command line "'+
            ComLine+'"');
        if (cs_link_on_target in CurrentSettings.GlobalSwitches) then
          QuoteScript:=TargetInfo.Script
        else
          QuoteScript:=SourceInfo.Script;
        if QuoteScript=script_unix then
          Result:=SysUtils.ExecuteProcess(Path,UnixRequoteWithDoubleQuotes(ComLine),Flags)
        else
          Result:=SysUtils.ExecuteProcess(Path,ComLine,Flags)
      end;


    function RequotedExecuteProcess(const Path: AnsiString; const ComLine: array of AnsiString; Flags: TExecuteFlags): LongInt;
      var
        I : LongInt;
        ST : string;
      begin
        if Do_CheckVerbosity(VExecutable) then
          begin
            if High(ComLine)=0 then
              ST:=''
            else
              ST:=ComLine[1];
            for I:=2 to High(ComLine) do
              ST:=ST+' '+ComLine[I];
            Do_Comment(VExecutable,'Executing "'+Path+'" with command line "'+
              ST+'"');
          end;
        Result:=SysUtils.ExecuteProcess(Path,ComLine,Flags);
      end;


    function Shell(const Command:AnsiString): LongInt;
      { This is already defined in the linux.nxu for linux, need for the *
        expansion under linux }
{$ifdef hasunix}
      begin
        Do_Comment(VExecutable,'Executing "'+Command+'" with fpSystem call');
        Result := Unix.FpSystem(Command);
      end;
{$else hasunix}
      var
        ComSpec : string;
      begin
        ComSpec:=GetEnvironmentVariable('COMSPEC');
        Do_Comment(VExecutable,'Executing "'+Command+'" using comspec "'
            +ComSpec+'"');
        Result := RequotedExecuteProcess(ComSpec,' /C '+Command);
      end;
{$endif hasunix}



{****************************************************************************
                           Init / Done
****************************************************************************}

    procedure InitFileUtils;
      begin
        CachedCurrentDir:='';
        DirCache:=TDirectoryCache.Create;
      end;


    procedure DoneFileUtils;
      begin
        DirCache.Free;
        DirCache := nil;
      end;

end.
