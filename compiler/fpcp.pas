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
    pcp,FinPut,fpkg,nxartifactid;

  type
    TPCPPackage=class(TPackage)
    private
      loaded : boolean;
      pcpfile : TPCPFile;
      metadatastream : TCMemoryStream;
    private
      function openpcp:boolean;
      function search_package(ashortname:boolean):boolean;
      function search_package_file:boolean;
      procedure setfilename(const fn:string;allowoutput:boolean);
      procedure writecontainernames;
      procedure writecontainedunits;
      procedure writerequiredpackages;
      procedure writepputable;
      procedure writeppudata;
      procedure readcontainernames;
      procedure readcontainedunits;
      procedure readrequiredpackages;
      procedure readpputable;
      procedure invalidpcp(const reason:AnsiString);
      procedure readentry(expected:byte);
      procedure endentry;
      procedure checkppudata;
    public
      constructor create(const pn:string);
      destructor Destroy; override;
      procedure loadpcp;
      procedure savepcp;
      function getmodulestream(module:TModuleBase):TCStream;
      procedure initmoduleinfo(module:TModuleBase);
      procedure addunit(module:TModuleBase);
      procedure add_required_package(pkg:TPackage);
    end;

implementation

  uses
    SysUtils,
    CFileUtl,CUtils,
    Systems,Globals,version,
    Verbose,
    entfile,ppu,pkgutil,nxpackagefile,
    aasmbase,aasmtai,AAsmData;

{ tpcppackage }

  procedure TPCPPackage.invalidpcp(const reason:AnsiString);
    begin
      Comment(VFatal,'Invalid PCP file '+pcpfilename+': '+reason);
    end;

  procedure TPCPPackage.readentry(expected:byte);
    begin
      if not pcpfile.readpackageentry(expected) then
        invalidpcp('invalid or truncated metadata entry '+ToStr(expected));
    end;

  procedure TPCPPackage.endentry;
    begin
      if not pcpfile.packageentrydone then
        invalidpcp('invalid metadata entry length');
    end;

  function TPCPPackage.openpcp: boolean;
    var
      pcpfiletime : LongInt;
      lData: TBytes;
    begin
      result:=false;
      Message1(package_t_pcp_loading,pcpfilename);
      { Get pcpfile time (also check if the file exists) }
      pcpfiletime:=getnamedfiletime(pcpfilename);
      if pcpfiletime=-1 then
       exit;
    { Open the pcpfile }
      Message1(package_u_pcp_name,pcpfilename);
      metadatastream.Free;
      metadatastream:=nil;
      pcpfile:=TPCPFile.create(pcpfilename);
      try
        lData:=ReadPackageMetadata(pcpfilename);
      except
        on E: Exception do invalidpcp(E.Message);
      end;
      metadatastream:=TCMemoryStream.Create;
      metadatastream.WriteBuffer(lData[0],Length(lData));
      metadatastream.Position:=0;
      if not pcpfile.openstream(metadatastream) then
       begin
         pcpfile.free;
         pcpfile:=nil;
         Message(package_u_pcp_file_too_short);
         exit;
       end;
    { Check the Nexus family before interpreting package metadata. }
      if not pcpfile.checkpcpid then
       begin
         pcpfile.free;
         pcpfile:=nil;
         Comment(VNormal,'Invalid NexusFPC package header in '+pcpfilename+
           ' (expected NXP signature and current header layout); rebuild with NexusFPC');
         exit;
       end;
    { check for allowed PCP versions }
      if not (pcpfile.getversion=CurrentPCPVersion) then
       begin
         Message1(package_u_pcp_invalid_version,ToStr(pcpfile.getversion));
         pcpfile.free;
         pcpfile:=nil;
         exit;
       end;
    { check the target processor }
      if TSystemCPU(pcpfile.header.common.cpu)<>TargetCPU then
       begin
         pcpfile.free;
         pcpfile:=nil;
         Message(package_u_pcp_invalid_processor);
         exit;
       end;
    { check target }
      if TSystem(pcpfile.header.common.target)<>TargetInfo.system then
       begin
         pcpfile.free;
         pcpfile:=nil;
         Message(package_u_pcp_invalid_target);
         exit;
       end;
    { Show Debug info }
      Message1(package_u_pcp_time,FileTimeString(pcpfiletime));
      Message1(package_u_pcp_flags,ToStr(pcpfile.header.common.flags{flags}));
      Message1(package_u_pcp_crc,HexStr(pcpfile.header.checksum,8));
      (*Message1(package_u_pcp_crc,hexstr(ppufile.header.interface_checksum,8)+' (intfc)');
      Message1(package_u_pcp_crc,hexstr(ppufile.header.indirect_checksum,8)+' (indc)');
      Comment(V_used,'Number of definitions: '+tostr(ppufile.header.deflistsize));
      Comment(V_used,'Number of symbols: '+tostr(ppufile.header.symlistsize));
      do_compile:=false;*)
      result:=true;
    end;

  function TPCPPackage.search_package(ashortname:boolean):boolean;
    var
      singlepathstring,
      FileName : TCmdStr;

    function package_exists(const ext:string;var foundfile:TCmdStr):boolean;
      begin
        if CheckVerbosity(VTried) then
          Message1(package_t_packagesearch,Singlepathstring+FileName+ext);
        result:=FindFile(FileName+ext,singlepathstring,true,foundfile);
      end;

    function package_search_path(const s:TCmdStr):boolean;
      var
        found : boolean;
        hs    : TCmdStr;
      begin
        found:=false;
        singlepathstring:=FixPath(s,false);
        { The native image identifies its embedded payload or matching sidecar. }
        found:=package_exists(NexusPackageLibraryExtension,hs);
        if found then
          begin
            setfilename(hs,false);
            found:=openpcp;
          end;
        result:=found;
      end;

    function search_path_list(list:TSearchPathList):boolean;
      var
        hp : TCmdStrListItem;
        found : boolean;
      begin
        found:=false;
        hp:=TCmdStrListItem(list.First);
        while Assigned(hp) do
         begin
           found:=package_search_path(hp.Str);
           if found then
            break;
           hp:=TCmdStrListItem(hp.next);
         end;
        result:=found;
      end;

    begin
      FileName:=realpackagename^;
      result:=search_path_list(PackageSearchPath);
    end;

  function TPCPPackage.search_package_file: boolean;
    var
      found : boolean;
    begin
      found:=false;
      if search_package(false) then
        found:=true;
      if not found and
          (length(packagename^)>8) and
         search_package(true) then
        found:=true;
      result:=found;
    end;

  procedure TPCPPackage.setfilename(const fn:string;allowoutput:boolean);
    var
      p,n : TPathStr;
    begin
      p:=FixPath(ExtractFilePath(fn),false);
      n:=FixFileName(ChangeFileExt(ExtractFileName(fn),''));
      { pcp name }
      if allowoutput then
        if (OutputUnitDir<>'') then
          p:=OutputUnitDir
        else
          if (OutputExeDir<>'') then
            p:=OutputExeDir;
      pcpfilename:=p+n+NexusPackageExtension;
      if not allowoutput then
        pcpfilename:=fn;
    end;

  procedure TPCPPackage.writecontainernames;
    begin
      pcpfile.putstring(pplfilename);
      pcpfile.putstring(sdkidentity);
      pcpfile.putstring(buildidentity);
      //pcpfile.putstring(ppafilename);
      pcpfile.writeentry(ibpackagefiles);
    end;

  procedure TPCPPackage.writecontainedunits;
    var
      p : PContainedUnit;
      i : LongInt;
    begin
      pcpfile.putlongint(containedmodules.count);
      pcpfile.writeentry(ibstartcontained);
      { for now we write the unit name and the ppu file name }
      for i:=0 to containedmodules.count-1 do
        begin
          p:=PContainedUnit(containedmodules.items[i]);
          pcpfile.putstring(p^.module.ModuleName^);
          pcpfile.putstring(p^.ppufile);
        end;
      pcpfile.writeentry(ibendcontained);
    end;

  procedure TPCPPackage.writerequiredpackages;
    var
      i : LongInt;
    begin
      pcpfile.putlongint(requiredpackages.count);
      pcpfile.writeentry(ibstartrequireds);
      for i:=0 to requiredpackages.count-1 do
        begin
          pcpfile.putstring(requiredpackages.NameOfIndex(i));
          pcpfile.putstring(TPackage(requiredpackages[i]).buildidentity);
        end;
      pcpfile.writeentry(ibendrequireds);
    end;

  procedure TPCPPackage.writepputable;
    var
      module : PContainedUnit;
      i : LongInt;
    begin
      { no need to write the count again; it's the same as for the contained units }
      for i:=0 to containedmodules.count-1 do
        begin
          module:=PContainedUnit(containedmodules[i]);
          pcpfile.putlongint(module^.offset);
          pcpfile.putlongint(module^.size);
        end;
      pcpfile.writeentry(ibpputable);
    end;

  procedure TPCPPackage.writeppudata;
    const
      align: array[0..15] of byte = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
    var
      i,
      pos,
      rem : LongInt;
      module : PContainedUnit;
      stream : TCMemoryStream;
    begin
      pcpfile.flush;

      for i:=0 to containedmodules.count-1 do
        begin
          module:=PContainedUnit(containedmodules[i]);

          pos:=pcpfile.position;
          { align to 16 byte so that it can be nicely viewed in hex editors;
            maybe we could also use 512 byte alignment instead }
          rem:=$f-(pos and $f);
          pcpfile.stream.write(align[0],rem+1);
          pcpfile.flush;
          module^.offset:=pcpfile.position;

          { Rewrite into an independent stream: the entry writer must not
            share buffered state with direct writes to the PCP stream. }
          stream:=TCMemoryStream.Create;
          try
            if not rewriteppu(module^.module.PPUFileName,stream) then
              Comment(VFatal,'Failed to package unit '+module^.module.ModuleName^);
            module^.size:=stream.Size;
            stream.Position:=0;
            if pcpfile.stream.CopyFrom(stream,stream.Size)<>stream.Size then
              Message(package_f_pcp_cannot_write);
          finally
            stream.Free;
          end;
        end;

      pos:=pcpfile.position;
      { align to 16 byte so that it can be nicely viewed in hex editors;
        maybe we could also use 512 byte alignment instead }
      rem:=$f-(pos and $f);
      pcpfile.stream.write(align[0],rem+1);
    end;

  procedure TPCPPackage.readcontainernames;
    begin
      readentry(ibpackagefiles);
      pplfilename:=pcpfile.getstring;
      sdkidentity:=pcpfile.getstring;
      buildidentity:=pcpfile.getstring;
      endentry;
      if pplfilename='' then
        invalidpcp('empty library filename');
      if (length(sdkidentity)>64) or (length(buildidentity)>64) then
        invalidpcp('invalid build identity');
      if sdkidentity<>Package_SDK_Identity then
        invalidpcp('package SDK identity differs from compiler invocation');

      message1(package_u_ppl_filename,pplfilename);
    end;

  procedure TPCPPackage.readcontainedunits;
    var
      cnt,i : LongInt;
      name,path : string;
      p : PContainedUnit;
    begin
      readentry(ibstartcontained);
      cnt:=pcpfile.getlongint;
      endentry;
      if (cnt<0) or (cnt<>pcpfile.header.ppulistsize) then
        invalidpcp('contained-unit count does not match header');
      readentry(ibendcontained);
      if cnt>pcpfile.entrysize div 2 then
        invalidpcp('contained-unit count exceeds entry size');
      for i:=0 to cnt-1 do
        begin
          name:=pcpfile.getstring;
          path:=pcpfile.getstring;
          if pcpfile.error or (name='') or (path='') then
            invalidpcp('invalid contained-unit name or filename');
          name:=upper(name);
          if containedmodules.FindIndexOf(name)>=0 then
            invalidpcp('duplicate contained unit '+name);
          new(p);
          p^.module:=nil;
          p^.ppufile:=path;
          p^.offset:=0;
          p^.size:=0;
          containedmodules.add(name,p);
          message1(package_u_contained_unit,name);
        end;
      endentry;
    end;

  procedure TPCPPackage.readrequiredpackages;
    var
      cnt,i : LongInt;
      name : string;
      names : TFPHashList;
    begin
      readentry(ibstartrequireds);
      cnt:=pcpfile.getlongint;
      endentry;
      if (cnt<0) or (cnt<>pcpfile.header.requiredlistsize) then
        invalidpcp('required-package count does not match header');
      readentry(ibendrequireds);
      if cnt>pcpfile.entrysize then
        invalidpcp('required-package count exceeds entry size');
      names:=TFPHashList.Create;
      try
        for i:=0 to cnt-1 do
          begin
            name:=pcpfile.getstring;
            if pcpfile.error or (name='') then
              invalidpcp('invalid required-package name');
            { Keep the spelling for filesystem lookup and diagnostics. }
            if names.FindIndexOf(upper(name))>=0 then
              invalidpcp('duplicate required package '+name);
            { Hash lookup ignores entries with nil data. }
            names.Add(upper(name),self);
            requiredpackages.add(name,nil);
            requiredidentities.Add(upper(name),StringDup(pcpfile.getstring));
            message1(package_u_required_package,name);
          end;
      finally
        names.Free;
      end;
      endentry;
    end;

  procedure TPCPPackage.readpputable;
    var
      module : PContainedUnit;
      i : LongInt;
    begin
      readentry(ibpputable);
      if (pcpfile.entrysize mod (2*sizeof(LongInt))<>0) or
         (pcpfile.entrysize div (2*sizeof(LongInt))<>containedmodules.count) then
        invalidpcp('invalid PPU table size');
      for i:=0 to containedmodules.count-1 do
        begin
          module:=PContainedUnit(containedmodules[i]);
          module^.offset:=pcpfile.getlongint;
          module^.size:=pcpfile.getlongint;
        end;
      endentry;
    end;

  function compareppuoffsets(p1,p2:pointer):LongInt;
    begin
      if PContainedUnit(p1)^.offset<PContainedUnit(p2)^.offset then
        result:=-1
      else if PContainedUnit(p1)^.offset>PContainedUnit(p2)^.offset then
        result:=1
      else
        result:=0;
    end;

  procedure TPCPPackage.checkppudata;
    var
      ranges : TFPList;
      i,lastend,filesize : LongInt;
      module : PContainedUnit;
      data : TCMemoryStream;
      ppufile : TPPUFile;
    begin
      ranges:=TFPList.Create;
      try
        filesize:=pcpfile.stream.Size;
        for i:=0 to containedmodules.count-1 do
          ranges.Add(containedmodules[i]);
        ranges.Sort(@compareppuoffsets);
        lastend:=pcpfile.metadataend;
        for i:=0 to ranges.count-1 do
          begin
            module:=PContainedUnit(ranges[i]);
            if (module^.offset<lastend) or (module^.offset>filesize) or
               (module^.size<sizeof(TPPUHeader)) or
               (module^.size>filesize-module^.offset) then
              invalidpcp('overlapping or out-of-bounds embedded PPU');
            lastend:=module^.offset+module^.size;
            data:=TCMemoryStream.Create;
            ppufile:=TPPUFile.Create('');
            try
              pcpfile.stream.Position:=module^.offset;
              if data.CopyFrom(pcpfile.stream,sizeof(TPPUHeader))<>sizeof(TPPUHeader) then
                invalidpcp('truncated embedded PPU header');
              data.Position:=0;
              if not ppufile.openstream(data) then
                invalidpcp('truncated embedded PPU header');
              if not ppufile.CheckPPUId then
                invalidpcp('embedded unit requires NexusFPC NXU signature; rebuild with NexusFPC');
              if (ppufile.getversion<>CurrentPPUVersion) or
                 (ppufile.header.common.cpu<>pcpfile.header.common.cpu) or
                 (ppufile.header.common.target<>pcpfile.header.common.target) or
                 (ppufile.header.common.size<>dword(module^.size-sizeof(TPPUHeader))) then
                invalidpcp('incompatible or inconsistent embedded PPU header');
            finally
              ppufile.Free;
              data.Free;
            end;
          end;
      finally
        ranges.Free;
      end;
    end;

    constructor TPCPPackage.create(const pn: string);
    begin
      inherited create(pn);

      setfilename(pn+'.nxpk',true);
    end;

  destructor TPCPPackage.Destroy;
    begin
      pcpfile.free;
      pcpfile := nil;
      metadatastream.Free;
      inherited Destroy;
    end;

  procedure TPCPPackage.loadpcp;
    var
      newpackagename : string;
    begin
      if loaded then
        exit;

      if not search_package_file then
        begin
          Message1(package_f_cant_find_pcp,realpackagename^);
          exit;
        end
      else
        Message1(package_u_pcp_found,realpackagename^);

      if not Assigned(pcpfile) then
        InternalError(2013053101);

      readentry(ibpackagename);
      newpackagename:=pcpfile.getstring;
      endentry;
      if upper(newpackagename)<>packagename^ then
        invalidpcp('package name does not match '+realpackagename^);

      readcontainernames;

      readrequiredpackages;

      readcontainedunits;

      readpputable;
      readentry(ibend);
      if not pcpfile.metadatadone then
        invalidpcp('invalid metadata size or checksum');
      checkppudata;
      loaded:=true;
    end;

  procedure TPCPPackage.savepcp;
    var
      tablepos,
      oldpos,i : LongInt;
      module : PContainedUnit;
      lRaw, lEncoded: TBytes;
      lSection: TAISection;
    begin
      { create new ppufile }
      sdkidentity:=Package_SDK_Identity;
      buildidentity:=current_package_build_identity;
      metadatastream.Free;
      metadatastream:=nil;
      pcpfile:=TPCPFile.create(pcpfilename);
      metadatastream:=TCMemoryStream.Create;
      if not pcpfile.createstream(metadatastream) then
        Message2(package_f_cant_create_pcp,realpackagename^,pcpfilename);
      try
        pcpfile.putstring(realpackagename^);
        pcpfile.writeentry(ibpackagename);

        writecontainernames;

        writerequiredpackages;

        writecontainedunits;

        { the offsets and the contents of the ppus are not crc'd }
        pcpfile.do_crc:=false;

        pcpfile.flush;
        tablepos:=pcpfile.position;

        { this will write a table with empty entries }
        writepputable;

        pcpfile.do_crc:=true;

        { the last entry ibend is written automatically }

        { flush to be sure }
        pcpfile.flush;
        { create and write header }
        pcpfile.header.common.size:=pcpfile.size;
        pcpfile.header.checksum:=pcpfile.crc;
        pcpfile.header.common.compiler:=WordVersion;
        pcpfile.header.common.cpu:=word(TargetCPU);
        pcpfile.header.common.target:=word(TargetInfo.system);
        //pcpfile.header.flags:=flags;
        pcpfile.header.ppulistsize:=containedmodules.count;
        pcpfile.header.requiredlistsize:=requiredpackages.count;
        pcpfile.writeheader;

        { write the ppu table which will also fill the offsets/sizes }
        writeppudata;

        pcpfile.flush;
        oldpos:=pcpfile.position;

        { tablepos is the payload position, after the preallocated entry header.
          All buffers are flushed; patch only the fixed-size payload directly. }
        pcpfile.stream.Position:=tablepos;
        for i:=0 to containedmodules.count-1 do
          begin
            module:=PContainedUnit(containedmodules[i]);
            if (pcpfile.stream.Write(module^.offset,sizeof(LongInt))<>sizeof(LongInt)) or
               (pcpfile.stream.Write(module^.size,sizeof(LongInt))<>sizeof(LongInt)) then
              Message(package_f_pcp_cannot_write);
          end;

        pcpfile.position:=oldpos;

        SetLength(lRaw,metadatastream.Size);
        Move(metadatastream.Memory^,lRaw[0],Length(lRaw));
        lEncoded:=EncodePackageMetadata(lRaw);
        if not Embed_Package_Metadata then
          begin
            WritePackageBytes(pcpfilename,lEncoded);
            lEncoded:=PackageMetadataReference(lEncoded);
          end
        else if SysUtils.FileExists(pcpfilename) and not SysUtils.DeleteFile(pcpfilename) then
          Comment(VFatal,'Cannot remove stale package sidecar '+pcpfilename);
        lSection:=new_section(CurrentAsmData.asmlists[al_rotypedconsts],
          sec_user,NexusPackageMetadataSection,1);
        lSection.secprogbits:=SPB_PROGBITS;
        lSection.secflags:=[];
        CurrentAsmData.asmlists[al_rotypedconsts].concat(
          TAIString.Create_Data(PChar(@lEncoded[0]),Length(lEncoded),false));

        { save crc in current module also }
        //crc:=pcpfile.crc;

      finally
        pcpfile.free;
        pcpfile:=nil;
      end;
    end;

  function TPCPPackage.getmodulestream(module:TModuleBase):TCStream;
    var
      i : LongInt;
      contained : PContainedUnit;
      data : TCMemoryStream;
    begin
      for i:=0 to containedmodules.count-1 do
        begin
          contained:=PContainedUnit(containedmodules[i]);
          if contained^.module=module then
            begin
              { An independent bounded stream cannot read into the next PPU,
                and interleaved unit loads cannot disturb each other's cursor. }
              data:=TCMemoryStream.Create;
              try
                pcpfile.stream.Position:=contained^.offset;
                if data.CopyFrom(pcpfile.stream,contained^.size)<>contained^.size then
                  invalidpcp('truncated embedded PPU');
                data.Position:=0;
              except
                data.Free;
                raise;
              end;
              result:=data;
              exit;
            end;
        end;
      result:=nil;
    end;

  procedure TPCPPackage.initmoduleinfo(module: TModuleBase);
    begin
      pplfilename:=extractfilename(module.SharedLibFileName);
      pcpfilename:=ChangeFileExt(module.SharedLibFileName,NexusPackageExtension);
    end;

  procedure TPCPPackage.addunit(module: TModuleBase);
    var
      containedunit : PContainedUnit;
    begin
      new(containedunit);
      containedunit^.module:=module;
      containedunit^.ppufile:=extractfilename(module.PPUFileName);
      containedunit^.offset:=0;
      containedunit^.size:=0;
      containedmodules.add(module.ModuleName^,containedunit);
    end;


  procedure TPCPPackage.add_required_package(pkg:TPackage);
    var
      p : TPackage;
    begin
      p:=TPackage(requiredpackages.find(pkg.packagename^));
      if not Assigned(p) then
        requiredpackages.Add(pkg.packagename^,pkg)
      else
        if p<>pkg then
          InternalError(2015112302);
    end;


end.

