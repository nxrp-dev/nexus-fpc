{
    Copyright (c) 2013-2016 by Free Pascal development team

    This unit implements the loading and searching of package files

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
unit fpcp;

{$i fpcdefs.inc}

interface

  uses
    CClasses,CStreams,
    GlobType,
    PCP,FinPut,FPkg,NXArtifactID;

  type
    TPCPPackage=class(TPackage)
    private
      Loaded : Boolean;
      PCPFile : TPCPFile;
      MetadataStream : TCMemoryStream;
    private
      function OpenPCP:Boolean;
      function SearchPackage(AShortName:Boolean):Boolean;
      function SearchPackageFile:Boolean;
      procedure SetFileName(const FN:string;AllowOutput:Boolean);
      procedure WriteContainerNames;
      procedure WriteContainedUnits;
      procedure WriteRequiredPackages;
      procedure WritePPUTable;
      procedure WritePPUData;
      procedure ReadContainerNames;
      procedure ReadContainedUnits;
      procedure ReadRequiredPackages;
      procedure ReadPPUTable;
      procedure InvalidPCP(const Reason:AnsiString);
      procedure ReadEntry(Expected:Byte);
      procedure EndEntry;
      procedure CheckPPUData;
    public
      constructor Create(const PN:string);
      destructor Destroy; override;
      procedure LoadPCP;
      procedure SavePCP;
      function GetModuleStream(Module:TModuleBase):TCStream;
      procedure InitModuleInfo(Module:TModuleBase);
      procedure AddUnit(Module:TModuleBase);
      procedure Add_Required_Package(Pkg:TPackage);
    end;

implementation

  uses
    SysUtils,
    CFileUtl,CUtils,
    Systems,Globals,Version,
    Verbose,
    EntFile,PPU,PkgUtil,NXPackageFile,
    AAsmBase,AAsmTai,AAsmData;

{ tpcppackage }

  procedure TPCPPackage.InvalidPCP(const Reason:AnsiString);
    begin
      Comment(VFatal,'Invalid PCP file '+PCPFileName+': '+Reason);
    end;

  procedure TPCPPackage.ReadEntry(Expected:Byte);
    begin
      if not PCPFile.ReadPackageEntry(Expected) then
        InvalidPCP('invalid or truncated metadata entry '+ToStr(Expected));
    end;

  procedure TPCPPackage.EndEntry;
    begin
      if not PCPFile.PackageEntryDone then
        InvalidPCP('invalid metadata entry length');
    end;

  function TPCPPackage.OpenPCP: Boolean;
    var
      PCPFileTime : LongInt;
      LData: TBytes;
    begin
      Result:=False;
      Message1(package_t_pcp_loading,PCPFileName);
      { Get pcpfile time (also check if the file exists) }
      PCPFileTime:=GetNamedFileTime(PCPFileName);
      if PCPFileTime=-1 then
       Exit;
    { Open the pcpfile }
      Message1(package_u_pcp_name,PCPFileName);
      MetadataStream.Free;
      MetadataStream:=nil;
      PCPFile:=TPCPFile.Create(PCPFileName);
      try
        LData:=ReadPackageMetadata(PCPFileName);
      except
        on E: Exception do InvalidPCP(E.Message);
      end;
      MetadataStream:=TCMemoryStream.Create;
      MetadataStream.WriteBuffer(LData[0],Length(LData));
      MetadataStream.Position:=0;
      if not PCPFile.OpenStream(MetadataStream) then
       begin
         PCPFile.Free;
         PCPFile:=nil;
         Message(package_u_pcp_file_too_short);
         Exit;
       end;
    { Check the Nexus family before interpreting package metadata. }
      if not PCPFile.CheckPCPID then
       begin
         PCPFile.Free;
         PCPFile:=nil;
         Comment(VNormal,'Invalid NexusFPC package header in '+PCPFileName+
           ' (expected NXP signature and current header layout); rebuild with NexusFPC');
         Exit;
       end;
    { check for allowed PCP versions }
      if not (PCPFile.GetVersion=CurrentPCPVersion) then
       begin
         Message1(package_u_pcp_invalid_version,ToStr(PCPFile.GetVersion));
         PCPFile.Free;
         PCPFile:=nil;
         Exit;
       end;
    { check the target processor }
      if TSystemCPU(PCPFile.Header.Common.CPU)<>TargetCPU then
       begin
         PCPFile.Free;
         PCPFile:=nil;
         Message(package_u_pcp_invalid_processor);
         Exit;
       end;
    { check target }
      if TSystem(PCPFile.Header.Common.Target)<>TargetInfo.System then
       begin
         PCPFile.Free;
         PCPFile:=nil;
         Message(package_u_pcp_invalid_target);
         Exit;
       end;
    { Show Debug info }
      Message1(package_u_pcp_time,FileTimeString(PCPFileTime));
      Message1(package_u_pcp_flags,ToStr(PCPFile.Header.Common.Flags{flags}));
      Message1(package_u_pcp_crc,HexStr(PCPFile.Header.Checksum,8));
      (*Message1(package_u_pcp_crc,hexstr(ppufile.header.interface_checksum,8)+' (intfc)');
      Message1(package_u_pcp_crc,hexstr(ppufile.header.indirect_checksum,8)+' (indc)');
      Comment(V_used,'Number of definitions: '+tostr(ppufile.header.deflistsize));
      Comment(V_used,'Number of symbols: '+tostr(ppufile.header.symlistsize));
      do_compile:=false;*)
      Result:=True;
    end;

  function TPCPPackage.SearchPackage(AShortName:Boolean):Boolean;
    var
      SinglePathString,
      FileName : TCmdStr;

    function PackageExists(const Ext:string;var FoundFile:TCmdStr):Boolean;
      begin
        if CheckVerbosity(VTried) then
          Message1(package_t_packagesearch,SinglePathString+FileName+Ext);
        Result:=FindFile(FileName+Ext,SinglePathString,True,FoundFile);
      end;

    function SearchPackagePath(const S:TCmdStr):Boolean;
      var
        Found : Boolean;
        HS    : TCmdStr;
      begin
        Found:=False;
        SinglePathString:=FixPath(S,False);
        { The native image identifies its embedded payload or matching sidecar. }
        Found:=PackageExists(NexusPackageLibraryExtension,HS);
        if Found then
          begin
            SetFileName(HS,False);
            Found:=OpenPCP;
          end;
        Result:=Found;
      end;

    function SearchPathList(List:TSearchPathList):Boolean;
      var
        HP : TCmdStrListItem;
        Found : Boolean;
      begin
        Found:=False;
        HP:=TCmdStrListItem(List.First);
        while Assigned(HP) do
         begin
           Found:=SearchPackagePath(HP.Str);
           if Found then
            Break;
           HP:=TCmdStrListItem(HP.Next);
         end;
        Result:=Found;
      end;

    begin
      FileName:=RealPackageName^;
      Result:=SearchPathList(PackageSearchPath);
    end;

  function TPCPPackage.SearchPackageFile: Boolean;
    var
      Found : Boolean;
    begin
      Found:=False;
      if SearchPackage(False) then
        Found:=True;
      if not Found and
          (Length(PackageName^)>8) and
         SearchPackage(True) then
        Found:=True;
      Result:=Found;
    end;

  procedure TPCPPackage.SetFileName(const FN:string;AllowOutput:Boolean);
    var
      P,N : TPathStr;
    begin
      P:=FixPath(ExtractFilePath(FN),False);
      N:=FixFileName(ChangeFileExt(ExtractFileName(FN),''));
      { pcp name }
      if AllowOutput then
        if (OutputUnitDir<>'') then
          P:=OutputUnitDir
        else
          if (OutputExeDir<>'') then
            P:=OutputExeDir;
      PCPFileName:=P+N+NexusPackageExtension;
      if not AllowOutput then
        PCPFileName:=FN;
    end;

  procedure TPCPPackage.WriteContainerNames;
    begin
      PCPFile.PutString(PPLFileName);
      PCPFile.PutString(SDKIdentity);
      PCPFile.PutString(BuildIdentity);
      //pcpfile.putstring(ppafilename);
      PCPFile.WriteEntry(IBPackageFiles);
    end;

  procedure TPCPPackage.WriteContainedUnits;
    var
      P : PContainedUnit;
      I : LongInt;
    begin
      PCPFile.PutLongInt(ContainedModules.Count);
      PCPFile.WriteEntry(IBStartContained);
      { for now we write the unit name and the ppu file name }
      for I:=0 to ContainedModules.Count-1 do
        begin
          P:=PContainedUnit(ContainedModules.Items[I]);
          PCPFile.PutString(P^.Module.ModuleName^);
          PCPFile.PutString(P^.PPUFile);
        end;
      PCPFile.WriteEntry(IBEndContained);
    end;

  procedure TPCPPackage.WriteRequiredPackages;
    var
      I : LongInt;
    begin
      PCPFile.PutLongInt(RequiredPackages.Count);
      PCPFile.WriteEntry(IBStartRequireds);
      for I:=0 to RequiredPackages.Count-1 do
        begin
          PCPFile.PutString(RequiredPackages.NameOfIndex(I));
          PCPFile.PutString(TPackage(RequiredPackages[I]).BuildIdentity);
        end;
      PCPFile.WriteEntry(IBEndRequireds);
    end;

  procedure TPCPPackage.WritePPUTable;
    var
      Module : PContainedUnit;
      I : LongInt;
    begin
      { no need to write the count again; it's the same as for the contained units }
      for I:=0 to ContainedModules.Count-1 do
        begin
          Module:=PContainedUnit(ContainedModules[I]);
          PCPFile.PutLongInt(Module^.Offset);
          PCPFile.PutLongInt(Module^.Size);
        end;
      PCPFile.WriteEntry(IBPPUTable);
    end;

  procedure TPCPPackage.WritePPUData;
    const
      Align: array[0..15] of Byte = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
    var
      I,
      Pos,
      Rem : LongInt;
      Module : PContainedUnit;
      Stream : TCMemoryStream;
    begin
      PCPFile.Flush;

      for I:=0 to ContainedModules.Count-1 do
        begin
          Module:=PContainedUnit(ContainedModules[I]);

          Pos:=PCPFile.Position;
          { align to 16 byte so that it can be nicely viewed in hex editors;
            maybe we could also use 512 byte alignment instead }
          Rem:=$f-(Pos and $f);
          PCPFile.Stream.Write(Align[0],Rem+1);
          PCPFile.Flush;
          Module^.Offset:=PCPFile.Position;

          { Rewrite into an independent stream: the entry writer must not
            share buffered state with direct writes to the PCP stream. }
          Stream:=TCMemoryStream.Create;
          try
            if not RewritePPU(Module^.Module.PPUFileName,Stream) then
              Comment(VFatal,'Failed to package unit '+Module^.Module.ModuleName^);
            Module^.Size:=Stream.Size;
            Stream.Position:=0;
            if PCPFile.Stream.CopyFrom(Stream,Stream.Size)<>Stream.Size then
              Message(package_f_pcp_cannot_write);
          finally
            Stream.Free;
          end;
        end;

      Pos:=PCPFile.Position;
      { align to 16 byte so that it can be nicely viewed in hex editors;
        maybe we could also use 512 byte alignment instead }
      Rem:=$f-(Pos and $f);
      PCPFile.Stream.Write(Align[0],Rem+1);
    end;

  procedure TPCPPackage.ReadContainerNames;
    begin
      ReadEntry(IBPackageFiles);
      PPLFileName:=PCPFile.GetString;
      SDKIdentity:=PCPFile.GetString;
      BuildIdentity:=PCPFile.GetString;
      EndEntry;
      if PPLFileName='' then
        InvalidPCP('empty library filename');
      if (Length(SDKIdentity)>64) or (Length(BuildIdentity)>64) then
        InvalidPCP('invalid build identity');
      if SDKIdentity<>Package_SDK_Identity then
        InvalidPCP('package SDK identity differs from compiler invocation');

      Message1(package_u_ppl_filename,PPLFileName);
    end;

  procedure TPCPPackage.ReadContainedUnits;
    var
      Cnt,I : LongInt;
      Name,Path : string;
      P : PContainedUnit;
    begin
      ReadEntry(IBStartContained);
      Cnt:=PCPFile.GetLongInt;
      EndEntry;
      if (Cnt<0) or (Cnt<>PCPFile.Header.PPUListSize) then
        InvalidPCP('contained-unit count does not match header');
      ReadEntry(IBEndContained);
      if Cnt>PCPFile.EntrySize div 2 then
        InvalidPCP('contained-unit count exceeds entry size');
      for I:=0 to Cnt-1 do
        begin
          Name:=PCPFile.GetString;
          Path:=PCPFile.GetString;
          if PCPFile.Error or (Name='') or (Path='') then
            InvalidPCP('invalid contained-unit name or filename');
          Name:=Upper(Name);
          if ContainedModules.FindIndexOf(Name)>=0 then
            InvalidPCP('duplicate contained unit '+Name);
          New(P);
          P^.Module:=nil;
          P^.PPUFile:=Path;
          P^.Offset:=0;
          P^.Size:=0;
          ContainedModules.Add(Name,P);
          Message1(package_u_contained_unit,Name);
        end;
      EndEntry;
    end;

  procedure TPCPPackage.ReadRequiredPackages;
    var
      Cnt,I : LongInt;
      Name : string;
      Names : TFPHashList;
    begin
      ReadEntry(IBStartRequireds);
      Cnt:=PCPFile.GetLongInt;
      EndEntry;
      if (Cnt<0) or (Cnt<>PCPFile.Header.RequiredListSize) then
        InvalidPCP('required-package count does not match header');
      ReadEntry(IBEndRequireds);
      if Cnt>PCPFile.EntrySize then
        InvalidPCP('required-package count exceeds entry size');
      Names:=TFPHashList.Create;
      try
        for I:=0 to Cnt-1 do
          begin
            Name:=PCPFile.GetString;
            if PCPFile.Error or (Name='') then
              InvalidPCP('invalid required-package name');
            { Keep the spelling for filesystem lookup and diagnostics. }
            if Names.FindIndexOf(Upper(Name))>=0 then
              InvalidPCP('duplicate required package '+Name);
            { Hash lookup ignores entries with nil data. }
            Names.Add(Upper(Name),Self);
            RequiredPackages.Add(Name,nil);
            RequiredIdentities.Add(Upper(Name),StringDup(PCPFile.GetString));
            Message1(package_u_required_package,Name);
          end;
      finally
        Names.Free;
      end;
      EndEntry;
    end;

  procedure TPCPPackage.ReadPPUTable;
    var
      Module : PContainedUnit;
      I : LongInt;
    begin
      ReadEntry(IBPPUTable);
      if (PCPFile.EntrySize mod (2*SizeOf(LongInt))<>0) or
         (PCPFile.EntrySize div (2*SizeOf(LongInt))<>ContainedModules.Count) then
        InvalidPCP('invalid PPU table size');
      for I:=0 to ContainedModules.Count-1 do
        begin
          Module:=PContainedUnit(ContainedModules[I]);
          Module^.Offset:=PCPFile.GetLongInt;
          Module^.Size:=PCPFile.GetLongInt;
        end;
      EndEntry;
    end;

  function ComparePPUOffsets(P1,P2:Pointer):LongInt;
    begin
      if PContainedUnit(P1)^.Offset<PContainedUnit(P2)^.Offset then
        Result:=-1
      else if PContainedUnit(P1)^.Offset>PContainedUnit(P2)^.Offset then
        Result:=1
      else
        Result:=0;
    end;

  procedure TPCPPackage.CheckPPUData;
    var
      Ranges : TFPList;
      I,LastEnd,FileSize : LongInt;
      Module : PContainedUnit;
      Data : TCMemoryStream;
      PPUFile : TPPUFile;
    begin
      Ranges:=TFPList.Create;
      try
        FileSize:=PCPFile.Stream.Size;
        for I:=0 to ContainedModules.Count-1 do
          Ranges.Add(ContainedModules[I]);
        Ranges.Sort(@ComparePPUOffsets);
        LastEnd:=PCPFile.MetadataEnd;
        for I:=0 to Ranges.Count-1 do
          begin
            Module:=PContainedUnit(Ranges[I]);
            if (Module^.Offset<LastEnd) or (Module^.Offset>FileSize) or
               (Module^.Size<SizeOf(TPPUHeader)) or
               (Module^.Size>FileSize-Module^.Offset) then
              InvalidPCP('overlapping or out-of-bounds embedded PPU');
            LastEnd:=Module^.Offset+Module^.Size;
            Data:=TCMemoryStream.Create;
            PPUFile:=TPPUFile.Create('');
            try
              PCPFile.Stream.Position:=Module^.Offset;
              if Data.CopyFrom(PCPFile.Stream,SizeOf(TPPUHeader))<>SizeOf(TPPUHeader) then
                InvalidPCP('truncated embedded PPU header');
              Data.Position:=0;
              if not PPUFile.OpenStream(Data) then
                InvalidPCP('truncated embedded PPU header');
              if not PPUFile.CheckPPUId then
                InvalidPCP('embedded unit requires NexusFPC NXU signature; rebuild with NexusFPC');
              if (PPUFile.GetVersion<>CurrentPPUVersion) or
                 (PPUFile.Header.Common.CPU<>PCPFile.Header.Common.CPU) or
                 (PPUFile.Header.Common.Target<>PCPFile.Header.Common.Target) or
                 (PPUFile.Header.Common.Size<>DWORD(Module^.Size-SizeOf(TPPUHeader))) then
                InvalidPCP('incompatible or inconsistent embedded PPU header');
            finally
              PPUFile.Free;
              Data.Free;
            end;
          end;
      finally
        Ranges.Free;
      end;
    end;

    constructor TPCPPackage.Create(const PN: string);
    begin
      inherited Create(PN);

      SetFileName(PN+'.nxpk',True);
    end;

  destructor TPCPPackage.Destroy;
    begin
      PCPFile.Free;
      PCPFile := nil;
      MetadataStream.Free;
      inherited Destroy;
    end;

  procedure TPCPPackage.LoadPCP;
    var
      NewPackageName : string;
    begin
      if Loaded then
        Exit;

      if not SearchPackageFile then
        begin
          Message1(package_f_cant_find_pcp,RealPackageName^);
          Exit;
        end
      else
        Message1(package_u_pcp_found,RealPackageName^);

      if not Assigned(PCPFile) then
        InternalError(2013053101);

      ReadEntry(IBPackageName);
      NewPackageName:=PCPFile.GetString;
      EndEntry;
      if Upper(NewPackageName)<>PackageName^ then
        InvalidPCP('package name does not match '+RealPackageName^);

      ReadContainerNames;

      ReadRequiredPackages;

      ReadContainedUnits;

      ReadPPUTable;
      ReadEntry(IBEnd);
      if not PCPFile.MetadataDone then
        InvalidPCP('invalid metadata size or checksum');
      CheckPPUData;
      Loaded:=True;
    end;

  procedure TPCPPackage.SavePCP;
    var
      TablePos,
      OldPos,I : LongInt;
      Module : PContainedUnit;
      LRaw, LEncoded: TBytes;
      LSection: TAISection;
    begin
      { create new ppufile }
      SDKIdentity:=Package_SDK_Identity;
      BuildIdentity:=Current_Package_Build_Identity;
      MetadataStream.Free;
      MetadataStream:=nil;
      PCPFile:=TPCPFile.Create(PCPFileName);
      MetadataStream:=TCMemoryStream.Create;
      if not PCPFile.CreateStream(MetadataStream) then
        Message2(package_f_cant_create_pcp,RealPackageName^,PCPFileName);
      try
        PCPFile.PutString(RealPackageName^);
        PCPFile.WriteEntry(IBPackageName);

        WriteContainerNames;

        WriteRequiredPackages;

        WriteContainedUnits;

        { the offsets and the contents of the ppus are not crc'd }
        PCPFile.DoCRC:=False;

        PCPFile.Flush;
        TablePos:=PCPFile.Position;

        { this will write a table with empty entries }
        WritePPUTable;

        PCPFile.DoCRC:=True;

        { the last entry ibend is written automatically }

        { flush to be sure }
        PCPFile.Flush;
        { create and write header }
        PCPFile.Header.Common.Size:=PCPFile.Size;
        PCPFile.Header.Checksum:=PCPFile.CRC;
        PCPFile.Header.Common.Compiler:=WordVersion;
        PCPFile.Header.Common.CPU:=Word(TargetCPU);
        PCPFile.Header.Common.Target:=Word(TargetInfo.System);
        //pcpfile.header.flags:=flags;
        PCPFile.Header.PPUListSize:=ContainedModules.Count;
        PCPFile.Header.RequiredListSize:=RequiredPackages.Count;
        PCPFile.WriteHeader;

        { write the ppu table which will also fill the offsets/sizes }
        WritePPUData;

        PCPFile.Flush;
        OldPos:=PCPFile.Position;

        { tablepos is the payload position, after the preallocated entry header.
          All buffers are flushed; patch only the fixed-size payload directly. }
        PCPFile.Stream.Position:=TablePos;
        for I:=0 to ContainedModules.Count-1 do
          begin
            Module:=PContainedUnit(ContainedModules[I]);
            if (PCPFile.Stream.Write(Module^.Offset,SizeOf(LongInt))<>SizeOf(LongInt)) or
               (PCPFile.Stream.Write(Module^.Size,SizeOf(LongInt))<>SizeOf(LongInt)) then
              Message(package_f_pcp_cannot_write);
          end;

        PCPFile.Position:=OldPos;

        SetLength(LRaw,MetadataStream.Size);
        Move(MetadataStream.Memory^,LRaw[0],Length(LRaw));
        LEncoded:=EncodePackageMetadata(LRaw);
        if not Embed_Package_Metadata then
          begin
            WritePackageBytes(PCPFileName,LEncoded);
            LEncoded:=PackageMetadataReference(LEncoded);
          end
        else if SysUtils.FileExists(PCPFileName) and not SysUtils.DeleteFile(PCPFileName) then
          Comment(VFatal,'Cannot remove stale package sidecar '+PCPFileName);
        LSection:=new_section(CurrentAsmData.AsmLists[al_rotypedconsts],
          sec_user,NexusPackageMetadataSection,1);
        LSection.SecProgBits:=SPB_PROGBITS;
        LSection.SecFlags:=[];
        CurrentAsmData.AsmLists[al_rotypedconsts].Concat(
          TAIString.Create_Data(PChar(@LEncoded[0]),Length(LEncoded),False));

        { save crc in current module also }
        //crc:=pcpfile.crc;

      finally
        PCPFile.Free;
        PCPFile:=nil;
      end;
    end;

  function TPCPPackage.GetModuleStream(Module:TModuleBase):TCStream;
    var
      I : LongInt;
      Contained : PContainedUnit;
      Data : TCMemoryStream;
    begin
      for I:=0 to ContainedModules.Count-1 do
        begin
          Contained:=PContainedUnit(ContainedModules[I]);
          if Contained^.Module=Module then
            begin
              { An independent bounded stream cannot read into the next PPU,
                and interleaved unit loads cannot disturb each other's cursor. }
              Data:=TCMemoryStream.Create;
              try
                PCPFile.Stream.Position:=Contained^.Offset;
                if Data.CopyFrom(PCPFile.Stream,Contained^.Size)<>Contained^.Size then
                  InvalidPCP('truncated embedded PPU');
                Data.Position:=0;
              except
                Data.Free;
                raise;
              end;
              Result:=Data;
              Exit;
            end;
        end;
      Result:=nil;
    end;

  procedure TPCPPackage.InitModuleInfo(Module: TModuleBase);
    begin
      PPLFileName:=ExtractFileName(Module.SharedLibFileName);
      PCPFileName:=ChangeFileExt(Module.SharedLibFileName,NexusPackageExtension);
    end;

  procedure TPCPPackage.AddUnit(Module: TModuleBase);
    var
      ContainedUnit : PContainedUnit;
    begin
      New(ContainedUnit);
      ContainedUnit^.Module:=Module;
      ContainedUnit^.PPUFile:=ExtractFileName(Module.PPUFileName);
      ContainedUnit^.Offset:=0;
      ContainedUnit^.Size:=0;
      ContainedModules.Add(Module.ModuleName^,ContainedUnit);
    end;


  procedure TPCPPackage.Add_Required_Package(Pkg:TPackage);
    var
      P : TPackage;
    begin
      P:=TPackage(RequiredPackages.Find(Pkg.PackageName^));
      if not Assigned(P) then
        RequiredPackages.Add(Pkg.PackageName^,Pkg)
      else
        if P<>Pkg then
          InternalError(2015112302);
    end;


end.

