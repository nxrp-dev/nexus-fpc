{
    Copyright (c) 2015 by Nikolay Nikolov

    Contains the binary Relocatable Object Module Format (OMF) reader and writer
    This is the object format used on the i8086-msdos platform.

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
unit ogomf;

{$i fpcdefs.inc}

{$PackSet 1}

interface

    uses
       { common }
       CClasses,GlobType,
       { target }
       Systems,
       { assembler }
       CPUInfo,cpubase,aasmbase,assemble,link,
       { OMF definitions }
       omfbase,
       { output }
       ogbase,
       owbase;

    type

      { TOmfObjSymbol }

      TOmfObjSymbol = class(TObjSymbol)
      public
      end;

      { TOmfRelocation }

      TOmfRelocation = class(TObjRelocation)
      private
        FFrameGroup: string;
        FOmfFixup: TOMFSubRecordFIXUP;
      public
        destructor Destroy; override;

        procedure BuildOmfFixup;

        property FrameGroup: string read FFrameGroup write FFrameGroup;
        property OmfFixup: TOMFSubRecordFIXUP read FOmfFixup;
      end;


      { TOmfObjSection }

      TOmfObjSection = class(TObjSection)
      private
        FClassName: string;
        FOverlayName: string;
        FFirstSym: TObjSymbol;
        FCombination: TOmfSegmentCombination;
        FUse: TOmfSegmentUse;
        FPrimaryGroup: TObjSectionGroup;
        FSortOrder: Integer;
        FLinNumEntries: TOMFSubRecordLINNUMMsLinkLineNumberList;
        function GetOmfAlignment: TOmfSegmentAlignment;
      protected
        function GetAltName: string; override;
      public
        constructor create(AList:TFPHashObjectList;const Aname:string;Aalign:LongInt;Aoptions:TObjSectionOptions);override;
        destructor Destroy;override;
        property ClassName: string read FClassName;
        property OverlayName: string read FOverlayName;
        property OmfAlignment: TOmfSegmentAlignment read GetOmfAlignment;
        property Combination: TOmfSegmentCombination read FCombination;
        property Use: TOmfSegmentUse read FUse;
        property PrimaryGroup: TObjSectionGroup read FPrimaryGroup;
        property SortOrder: Integer read FSortOrder write FSortOrder;
        property LinNumEntries: TOMFSubRecordLINNUMMsLinkLineNumberList read FLinNumEntries;
      end;

      { TOmfObjExportedSymbol }

      TOmfObjExportedSymbol = class(TFPHashObject)
      private
        FExportByOrdinal: Boolean;
        FResidentName: Boolean;
        FNoData: Boolean;
        FParmCount: Integer;
        FExportedName: string;
        FInternalName: string;
        FExportOrdinal: Word;
      public
        property ExportByOrdinal: Boolean read FExportByOrdinal write FExportByOrdinal;
        property ResidentName: Boolean read FResidentName write FResidentName;
        property NoData: Boolean read FNoData write FNoData;
        property ParmCount: Integer read FParmCount write FParmCount;
        property ExportedName: string read FExportedName write FExportedName;
        property InternalName: string read FInternalName write FInternalName;
        property ExportOrdinal: Word read FExportOrdinal write FExportOrdinal;
      end;

      { TOmfObjData }

      TOmfObjData = class(TObjData)
      private
        FMainSource: TPathStr;
        FImportLibraryList:TFPHashObjectList;
        FExportedSymbolList:TFPHashObjectList;
        class function CodeSectionName(const aname:string): string;
      public
        constructor create(const n:string);override;
        destructor Destroy;override;
        function sectiontype2align(atype:TAsmSectiontype):LongInt;override;
        class function sectiontype2class(atype:TAsmSectiontype):string;
        function sectionname(atype:TAsmSectiontype;const aname:string;aorder:TAsmSectionOrder):string;override;
        function createsection(atype:TAsmSectiontype;const aname:string='';aorder:TAsmSectionOrder=secorder_default):TObjSection;override;
        function reffardatasection:TObjSection;
        procedure writeReloc(Data:TRelocDataInt;len:aword;p:TObjSymbol;Reloctype:TObjRelocationType);override;
        procedure AddImportSymbol(const libname,symname,symmangledname:TCmdStr;OrdNr: LongInt;isvar:boolean);
        procedure AddExportSymbol(aExportByOrdinal,aResidentName,aNoData:Boolean;aParmCount:Integer;aExportedName,aInternalName:string;aExportOrdinal:Word);
        property MainSource: TPathStr read FMainSource;
        property ImportLibraryList:TFPHashObjectList read FImportLibraryList;
        property ExportedSymbolList:TFPHashObjectList read FExportedSymbolList;
      end;

      { TOmfObjOutput }

      TOmfObjOutput = class(TObjOutput)
      private
        FLNames: TOmfOrderedNameCollection;
        FSegments: TFPHashObjectList;
        FGroups: TFPHashObjectList;
        procedure AddSegment(const name,segclass,ovlname: string;
          Alignment: TOmfSegmentAlignment; Combination: TOmfSegmentCombination;
          Use: TOmfSegmentUse; Size: TObjSectionOfs);
        procedure AddGroup(group: TObjSectionGroup);
        procedure WriteSections(Data:TObjData);
        procedure WriteSectionContentAndFixups(sec: TObjSection);
        procedure WriteLinNumRecords(sec: TOmfObjSection);

        procedure section_count_sections(p:TObject;arg:pointer);
        procedure group_count_groups(p:TObject;arg:pointer);
        procedure WritePUBDEFs(Data: TObjData);
        procedure WriteEXTDEFs(Data: TObjData);

        property LNames: TOmfOrderedNameCollection read FLNames;
        property Segments: TFPHashObjectList read FSegments;
        property Groups: TFPHashObjectList read FGroups;
      protected
        function WriteData(Data:TObjData):boolean;override;
      public
        constructor create(AWriter:TObjectWriter);override;
        destructor Destroy;override;
        procedure WriteDllImport(const dllname,afuncname,mangledname:string;ordnr:LongInt;isvar:boolean);
      end;

      { TOmfObjInput }

      TOmfObjInput = class(TObjInput)
      private
        FLNames: TOmfOrderedNameCollection;
        FExtDefs: TFPHashObjectList;
        FPubDefs: TFPHashObjectList;
        FFixupThreads: TOmfThreads;
        FRawRecord: TOmfRawRecord;
        FCOMENTRecord: TOMFRecordCOMENT;
        FCaseSensitiveSegments: Boolean;
        FCaseSensitiveSymbols: Boolean;

        function PeekNextRecordType: Byte;

        function ReadLNames(RawRec: TOmfRawRecord): Boolean;
        function ReadSegDef(RawRec: TOmfRawRecord; objdata:TObjData): Boolean;
        function ReadGrpDef(RawRec: TOmfRawRecord; objdata:TObjData): Boolean;
        function ReadExtDef(RawRec: TOmfRawRecord; objdata:TObjData): Boolean;
        function ReadPubDef(RawRec: TOmfRawRecord; objdata:TObjData): Boolean;
        function ReadModEnd(RawRec: TOmfRawRecord; objdata:TObjData): Boolean;
        function ReadLeOrLiDataAndFixups(RawRec: TOmfRawRecord; objdata:TObjData): Boolean;
        function ReadImpDef(Rec: TOMFRecordCOMENT; objdata:TObjData): Boolean;
        function ReadExpDef(Rec: TOMFRecordCOMENT; objdata:TObjData): Boolean;
        function ImportOmfFixup(objdata: TObjData; objsec: TOmfObjSection; Fixup: TOMFSubRecordFIXUP): Boolean;

        property LNames: TOmfOrderedNameCollection read FLNames;
        property ExtDefs: TFPHashObjectList read FExtDefs;
        property PubDefs: TFPHashObjectList read FPubDefs;

        { Specifies whether we're case sensitive in regards to segment, class, overlay and group names. }
        property CaseSensitiveSegments: Boolean read FCaseSensitiveSegments write FCaseSensitiveSegments;
        { Specifies whether symbol names (in EXTDEF and PUBDEF records) are case sensitive. }
        property CaseSensitiveSymbols: Boolean read FCaseSensitiveSymbols write FCaseSensitiveSymbols;
      public
        constructor create;override;
        destructor Destroy;override;
        class function CanReadObjData(AReader:TObjectReader):boolean;override;
        function ReadObjData(AReader:TObjectReader;out objdata:TObjData):boolean;override;
      end;

    type

      TOmfAssembler = class(TInternalAssembler)
        constructor create(info: PAsmInfo; smart:boolean);override;
      end;

    function StripDllExt(const DllName:TSymStr):TSymStr;
    function MaybeAddDllExt(const DllName:TSymStr):TSymStr;

implementation

    uses
       SysUtils,
       CUtils,Verbose,Globals,FPCHash,
       FModule,aasmtai,AAsmData,
       owomflib
       ;


{****************************************************************************
                                TTISTrailer
****************************************************************************}

    destructor TOmfRelocation.Destroy;
      begin
        FOmfFixup.Free;
        FOmfFixup := nil;
        inherited Destroy;
      end;

    procedure TOmfRelocation.BuildOmfFixup;
      begin
        FreeAndNil(FOmfFixup);
        FOmfFixup:=TOMFSubRecordFIXUP.Create;
        if ObjSection<>nil then
          begin
            FOmfFixup.LocationOffset:=DataOffset;
            if typ in [RELOC_ABSOLUTE16,RELOC_RELATIVE16] then
              FOmfFixup.LocationType:=fltOffset
            else if typ in [RELOC_ABSOLUTE32,RELOC_RELATIVE32] then
              FOmfFixup.LocationType:=fltOffset32
            else if typ in [RELOC_SEG,RELOC_SEGREL] then
              FOmfFixup.LocationType:=fltBase
            else
              InternalError(2015041501);
            FOmfFixup.FrameDeterminedByThread:=False;
            FOmfFixup.TargetDeterminedByThread:=False;
            if typ in [RELOC_ABSOLUTE16,RELOC_ABSOLUTE32,RELOC_SEG] then
              FOmfFixup.Mode:=fmSegmentRelative
            else if typ in [RELOC_RELATIVE16,RELOC_RELATIVE32,RELOC_SEGREL] then
              FOmfFixup.Mode:=fmSelfRelative
            else
              InternalError(2015041408);
            if typ in [RELOC_ABSOLUTE16,RELOC_ABSOLUTE32,RELOC_RELATIVE16,RELOC_RELATIVE32] then
              begin
                FOmfFixup.TargetMethod:=ftmSegmentIndexNoDisp;
                FOmfFixup.TargetDatum:=ObjSection.Index;
                if TOmfObjSection(ObjSection).PrimaryGroup<>nil then
                  begin
                    FOmfFixup.FrameMethod:=ffmGroupIndex;
                    FOmfFixup.FrameDatum:=TOmfObjSection(ObjSection).PrimaryGroup.index;
                  end
                else
                  FOmfFixup.FrameMethod:=ffmTarget;
              end
            else
              begin
                FOmfFixup.FrameMethod:=ffmTarget;
                if TOmfObjSection(ObjSection).PrimaryGroup<>nil then
                  begin
                    FOmfFixup.TargetMethod:=ftmGroupIndexNoDisp;
                    FOmfFixup.TargetDatum:=TOmfObjSection(ObjSection).PrimaryGroup.index;
                  end
                else
                  begin
                    FOmfFixup.TargetMethod:=ftmSegmentIndexNoDisp;
                    FOmfFixup.TargetDatum:=ObjSection.Index;
                  end;
              end;
          end
        else if symbol<>nil then
          begin
            FOmfFixup.LocationOffset:=DataOffset;
            if typ in [RELOC_ABSOLUTE16,RELOC_RELATIVE16] then
              FOmfFixup.LocationType:=fltOffset
            else if typ in [RELOC_ABSOLUTE32,RELOC_RELATIVE32] then
              FOmfFixup.LocationType:=fltOffset32
            else if typ in [RELOC_SEG,RELOC_SEGREL] then
              FOmfFixup.LocationType:=fltBase
            else
              InternalError(2015041505);
            FOmfFixup.FrameDeterminedByThread:=False;
            FOmfFixup.TargetDeterminedByThread:=False;
            if typ in [RELOC_ABSOLUTE16,RELOC_ABSOLUTE32,RELOC_SEG] then
              FOmfFixup.Mode:=fmSegmentRelative
            else if typ in [RELOC_RELATIVE16,RELOC_RELATIVE32,RELOC_SEGREL] then
              FOmfFixup.Mode:=fmSelfRelative
            else
              InternalError(2015041409);
            FOmfFixup.TargetMethod:=ftmExternalIndexNoDisp;
            FOmfFixup.TargetDatum:=symbol.symidx;
            FOmfFixup.FrameMethod:=ffmTarget;
          end
        else if group<>nil then
          begin
            FOmfFixup.LocationOffset:=DataOffset;
            if typ in [RELOC_ABSOLUTE16,RELOC_RELATIVE16] then
              FOmfFixup.LocationType:=fltOffset
            else if typ in [RELOC_ABSOLUTE32,RELOC_RELATIVE32] then
              FOmfFixup.LocationType:=fltOffset32
            else if typ in [RELOC_SEG,RELOC_SEGREL] then
              FOmfFixup.LocationType:=fltBase
            else
              InternalError(2015041506);
            FOmfFixup.FrameDeterminedByThread:=False;
            FOmfFixup.TargetDeterminedByThread:=False;
            if typ in [RELOC_ABSOLUTE16,RELOC_ABSOLUTE32,RELOC_SEG] then
              FOmfFixup.Mode:=fmSegmentRelative
            else if typ in [RELOC_RELATIVE16,RELOC_RELATIVE32,RELOC_SEGREL] then
              FOmfFixup.Mode:=fmSelfRelative
            else
              InternalError(2015041410);
            FOmfFixup.FrameMethod:=ffmTarget;
            FOmfFixup.TargetMethod:=ftmGroupIndexNoDisp;
            FOmfFixup.TargetDatum:=group.index;
          end
        else
         InternalError(2015040702);
      end;

{****************************************************************************
                                TOmfObjSection
****************************************************************************}

    function TOmfObjSection.GetOmfAlignment: TOmfSegmentAlignment;
      begin
        case SecAlign of
          1:
            result:=saRelocatableByteAligned;
          2:
            result:=saRelocatableWordAligned;
          4:
            result:=saRelocatableDWordAligned;
          16:
            result:=saRelocatableParaAligned;
          256:
            result:=saRelocatablePageAligned;
          4096:
            result:=saNotSupported;
          else
            InternalError(2015041504);
        end;
      end;

    function TOmfObjSection.GetAltName: string;
      begin
        if FFirstSym<>nil then
          result:='/'+FFirstSym.Name
        else
          result:='';
      end;

    constructor TOmfObjSection.create(AList: TFPHashObjectList;
          const Aname: string; Aalign: LongInt; Aoptions: TObjSectionOptions);
      begin
        inherited create(AList, Aname, Aalign, Aoptions);
        FCombination:=scPublic;
        FUse:=suUse16;
        FLinNumEntries:=TOMFSubRecordLINNUMMsLinkLineNumberList.Create;
      end;

    destructor TOmfObjSection.Destroy;
      begin
        FLinNumEntries.Free;
        FLinNumEntries := nil;
        inherited Destroy;
      end;

    class function TOmfObjData.CodeSectionName(const aname: string): string;
      begin

          result:='_TEXT';
      end;

    constructor TOmfObjData.create(const n: string);
      begin
        inherited create(n);
        CObjSymbol:=TOmfObjSymbol;
        CObjSection:=TOmfObjSection;
        createsectiongroup('DGROUP');
        FMainSource:=CurrentModule.MainSource;
        FImportLibraryList:=TFPHashObjectList.Create(true);
        FExportedSymbolList:=TFPHashObjectList.Create(true);
      end;

    destructor TOmfObjData.Destroy;
      begin
        FExportedSymbolList.Free;
        FExportedSymbolList := nil;
        FImportLibraryList.Free;
        FImportLibraryList := nil;
        inherited Destroy;
      end;

    function TOmfObjData.sectiontype2align(atype: TAsmSectiontype): LongInt;
      begin
        Result:=omf_sectiontype2align(atype);
      end;

    class function TOmfObjData.sectiontype2class(atype: TAsmSectiontype): string;
      begin
        Result:=omf_segclass(atype);
      end;

    function TOmfObjData.sectionname(atype:TAsmSectiontype;const aname:string;aorder:TAsmSectionOrder):string;
      var
        sep : string[3];
        secname : string;
      begin
        if (atype=sec_user) then
          Result:=aname
        else
          begin
            if omf_secnames[atype]=omf_secnames[sec_code] then
              secname:=CodeSectionName(aname)
            else if omf_segclass(atype)='FAR_DATA' then
              secname:=CurrentModule.ModuleName^ + '_DATA'
            else
              secname:=omf_secnames[atype];
            if create_smartlink_sections and (aname<>'') then
              begin
                case aorder of
                  secorder_begin :
                    sep:='.b_';
                  secorder_end :
                    sep:='.z_';
                  else
                    sep:='.n_';
                end;
                result:=UpCase(secname+sep+aname);
              end
            else
              result:=secname;
          end;
      end;

    function TOmfObjData.createsection(atype: TAsmSectiontype; const aname: string; aorder: TAsmSectionOrder): TObjSection;
      var
        is_new: Boolean;
        primary_group: String;
        grp: TObjSectionGroup;
      begin
        is_new:=TObjSection(ObjSectionList.Find(sectionname(atype,aname,aorder)))=nil;
        Result:=inherited createsection(atype, aname, aorder);
        if is_new then
          begin
            TOmfObjSection(Result).FClassName:=sectiontype2class(atype);
            if atype=sec_stack then
              TOmfObjSection(Result).FCombination:=scStack
            else if atype in [sec_debug_frame,sec_debug_info,sec_debug_line,sec_debug_abbrev,sec_debug_aranges,sec_debug_ranges] then
              begin
                TOmfObjSection(Result).FUse:=suUse32;
                TOmfObjSection(Result).SizeLimit:=high(LongWord);
              end;
            primary_group:=omf_section_primary_group(atype,aname);
            if primary_group<>'' then
              begin
                { find the primary group, if it already exists, else create it }
                grp:=nil;
                if GroupsList<>nil then
                  grp:=TObjSectionGroup(GroupsList.Find(primary_group));
                if grp=nil then
                  grp:=createsectiongroup(primary_group);
                { add the current section to the group }
                SetLength(grp.members,Length(grp.members)+1);
                grp.members[High(grp.members)]:=Result;
                TOmfObjSection(Result).FPrimaryGroup:=grp;
              end;
          end;
      end;

    function TOmfObjData.reffardatasection: TObjSection;
      var
        secname: string;
      begin
        secname:=CurrentModule.ModuleName^ + '_DATA';

        result:=TObjSection(ObjSectionList.Find(secname));
        if not Assigned(result) then
          begin
            result:=CObjSection.create(ObjSectionList,secname,2,[oso_Data,oso_load,oso_write]);
            result.ObjData:=self;
            TOmfObjSection(Result).FClassName:='FAR_DATA';
          end;
      end;

    procedure TOmfObjData.writeReloc(Data:TRelocDataInt;len:aword;p:TObjSymbol;Reloctype:TObjRelocationType);
      var
        objreloc: TOmfRelocation;
        symaddr: AWord;
      begin
        { RELOC_FARPTR = RELOC_ABSOLUTE16+RELOC_SEG }
        if Reloctype=RELOC_FARPTR then
          begin
            if len<>4 then
              InternalError(2015041502);
            writeReloc(Data,2,p,RELOC_ABSOLUTE16);
            writeReloc(0,2,p,RELOC_SEG);
            exit;
          end
        { RELOC_FARPTR48 = RELOC_ABSOLUTE16+RELOC_SEG }
        else if Reloctype=RELOC_FARPTR48 then
          begin
            if len<>6 then
              InternalError(2015041507);
            writeReloc(Data,4,p,RELOC_ABSOLUTE32);
            writeReloc(0,2,p,RELOC_SEG);
            exit;
          end;

        if CurrObjSec=nil then
          InternalError(2004030704);
        objreloc:=nil;
        if Reloctype in [RELOC_FARDATASEG,RELOC_FARDATASEGREL] then
          begin
            if Reloctype=RELOC_FARDATASEG then
              objreloc:=TOmfRelocation.CreateSection(CurrObjSec.Size,reffardatasection,RELOC_SEG)
            else
              objreloc:=TOmfRelocation.CreateSection(CurrObjSec.Size,reffardatasection,RELOC_SEGREL);
            CurrObjSec.ObjRelocations.Add(objreloc);
          end
        else if Assigned(p) then
          begin
            { real address of the symbol }
            symaddr:=p.address;

            if p.bind=AB_EXTERNAL then
              begin
                objreloc:=TOmfRelocation.CreateSymbol(CurrObjSec.Size,p,Reloctype);
                CurrObjSec.ObjRelocations.Add(objreloc);
              end
            { relative relocations within the same section can be calculated directly,
              without the need to emit a relocation entry }
            else if (p.objsection=CurrObjSec) and
                    (p.bind<>AB_COMMON) and
                    (Reloctype=RELOC_RELATIVE) then
              begin
                data:=data+symaddr-len-CurrObjSec.Size;
              end
            else
              begin
                objreloc:=TOmfRelocation.CreateSection(CurrObjSec.Size,p.objsection,Reloctype);
                CurrObjSec.ObjRelocations.Add(objreloc);
                if not (Reloctype in [RELOC_SEG,RELOC_SEGREL]) then
                  inc(data,symaddr);
              end;
          end
        else if Reloctype in [RELOC_DGROUP,RELOC_DGROUPREL] then
            begin
              if Reloctype=RELOC_DGROUP then
                objreloc:=TOmfRelocation.CreateGroup(CurrObjSec.Size,TObjSectionGroup(GroupsList.Find('DGROUP')),RELOC_SEG)
              else
                objreloc:=TOmfRelocation.CreateGroup(CurrObjSec.Size,TObjSectionGroup(GroupsList.Find('DGROUP')),RELOC_SEGREL);
              CurrObjSec.ObjRelocations.Add(objreloc);
            end;
        case len of
          1:
            CurrObjSec.write(data,1);
          2:
            CurrObjSec.writeInt16LE(int16(data));
          4:
            CurrObjSec.writeInt32LE(int32(data));
          else
            InternalError(2023110201);
        end;
      end;

    procedure TOmfObjData.AddImportSymbol(const libname, symname,
      symmangledname: TCmdStr; OrdNr: LongInt; isvar: boolean);
      var
        ImportLibrary : TImportLibrary;
        ImportSymbol  : TFPHashObject;
      begin
        ImportLibrary:=TImportLibrary(ImportLibraryList.Find(libname));
        if not Assigned(ImportLibrary) then
          ImportLibrary:=TImportLibrary.Create(ImportLibraryList,libname);
        ImportSymbol:=TFPHashObject(ImportLibrary.ImportSymbolList.Find(symname));
        if not Assigned(ImportSymbol) then
          ImportSymbol:=TImportSymbol.Create(ImportLibrary.ImportSymbolList,symname,symmangledname,OrdNr,isvar);
      end;

    procedure TOmfObjData.AddExportSymbol(aExportByOrdinal, aResidentName,
        aNoData: Boolean; aParmCount: Integer; aExportedName,
        aInternalName: string; aExportOrdinal: Word);
      var
        s: TOmfObjExportedSymbol;
      begin
        s:=TOmfObjExportedSymbol.Create(ExportedSymbolList,aInternalName);
        with s do
          begin
            ExportByOrdinal:=aExportByOrdinal;
            ResidentName:=aResidentName;
            NoData:=aNoData;
            ParmCount:=aParmCount;
            ExportedName:=aExportedName;
            InternalName:=aInternalName;
            ExportOrdinal:=aExportOrdinal;
          end;
      end;

{****************************************************************************
                                TOmfObjOutput
****************************************************************************}

    procedure TOmfObjOutput.AddSegment(const name, segclass, ovlname: string;
        Alignment: TOmfSegmentAlignment; Combination: TOmfSegmentCombination;
        Use: TOmfSegmentUse; Size: TObjSectionOfs);
      var
        s: TOMFRecordSEGDEF;
      begin
        s:=TOMFRecordSEGDEF.Create;
        Segments.Add(name,s);
        s.SegmentNameIndex:=LNames.Add(name);
        s.ClassNameIndex:=LNames.Add(segclass);
        s.OverlayNameIndex:=LNames.Add(ovlname);
        s.Alignment:=Alignment;
        s.Combination:=Combination;
        s.Use:=Use;
        s.SegmentLength:=Size;
      end;

    procedure TOmfObjOutput.AddGroup(group: TObjSectionGroup);
      var
        g: TOMFRecordGRPDEF;
        seglist: TSegmentList;
        I: Integer;
      begin
        seglist:=nil;
        g:=TOMFRecordGRPDEF.Create;
        Groups.Add(group.Name,g);
        g.GroupNameIndex:=LNames.Add(group.Name);
        SetLength(seglist,Length(group.members));
        for I:=Low(group.members) to High(group.members) do
          seglist[I]:=group.members[I].index;
        g.SegmentList:=seglist;
      end;

    procedure TOmfObjOutput.WriteSections(Data: TObjData);
      var
        i:LongInt;
        sec:TObjSection;
      begin
        for i:=0 to Data.ObjSectionList.Count-1 do
          begin
            sec:=TObjSection(Data.ObjSectionList[i]);
            WriteSectionContentAndFixups(sec);
            WriteLinNumRecords(TOmfObjSection(sec));
          end;
      end;

    procedure TOmfObjOutput.WriteSectionContentAndFixups(sec: TObjSection);
      const
        MaxChunkSize=$3fa;
      var
        RawRecord: TOmfRawRecord;
        ChunkStart,ChunkLen: DWord;
        ChunkFixupStart,ChunkFixupEnd: Integer;
        SegIndex: Integer;
        NextOfs: Integer;
        Is32BitLEDATA: Boolean;
        I: Integer;
      begin
        if (oso_data in sec.SecOptions) then
          begin
            if sec.Data=nil then
              InternalError(2004030705);
            for I:=0 to sec.ObjRelocations.Count-1 do
              TOmfRelocation(sec.ObjRelocations[I]).BuildOmfFixup;
            SegIndex:=Segments.FindIndexOf(sec.Name);
            RawRecord:=TOmfRawRecord.Create;
            sec.data.seek(0);
            ChunkFixupStart:=0;
            ChunkFixupEnd:=-1;
            ChunkStart:=0;
            ChunkLen:=Min(MaxChunkSize, sec.Data.size-ChunkStart);
            while ChunkLen>0 do
            begin
              { find last fixup in the chunk }
              while (ChunkFixupEnd<(sec.ObjRelocations.Count-1)) and
                    (TOmfRelocation(sec.ObjRelocations[ChunkFixupEnd+1]).DataOffset<(ChunkStart+ChunkLen)) do
                inc(ChunkFixupEnd);
              { check if last chunk is crossing the chunk boundary, and trim ChunkLen if necessary }
              if (ChunkFixupEnd>=ChunkFixupStart) and
                ((TOmfRelocation(sec.ObjRelocations[ChunkFixupEnd]).DataOffset+
                  TOmfRelocation(sec.ObjRelocations[ChunkFixupEnd]).OmfFixup.LocationSize)>(ChunkStart+ChunkLen)) then
                begin
                  ChunkLen:=TOmfRelocation(sec.ObjRelocations[ChunkFixupEnd]).DataOffset-ChunkStart;
                  Dec(ChunkFixupEnd);
                end;
              { write LEDATA record }
              Is32BitLEDATA:=TOmfObjSection(sec).Use=suUse32;
              if Is32BitLEDATA then
                RawRecord.RecordType:=RT_LEDATA32
              else
                RawRecord.RecordType:=RT_LEDATA;
              NextOfs:=RawRecord.WriteIndexedRef(0,SegIndex);
              if Is32BitLEDATA then
                begin
                  unaligned(PUint32(@RawRecord.RawData[NextOfs{..NextOfs+3}])^):=NtoLE(uint32(ChunkStart));
                  Inc(NextOfs,4);
                end
              else
                begin
                  if ChunkStart>$ffff then
                    InternalError(2018052201);
                  unaligned(PUint16(@RawRecord.RawData[NextOfs{..NextOfs+1}])^):=NtoLE(uint16(ChunkStart));
                  Inc(NextOfs,2);
                end;
              sec.data.read(RawRecord.RawData[NextOfs], ChunkLen);
              Inc(NextOfs, ChunkLen);
              RawRecord.RecordLength:=NextOfs+1;
              RawRecord.CalculateChecksumByte;
              RawRecord.WriteTo(FWriter);
              { write FIXUPP record }
              if ChunkFixupEnd>=ChunkFixupStart then
                begin
                  RawRecord.RecordType:=RT_FIXUPP;
                  NextOfs:=0;
                  for I:=ChunkFixupStart to ChunkFixupEnd do
                    begin
                      TOmfRelocation(sec.ObjRelocations[I]).OmfFixup.DataRecordStartOffset:=ChunkStart;
                      NextOfs:=TOmfRelocation(sec.ObjRelocations[I]).OmfFixup.WriteAt(RawRecord,NextOfs);
                    end;
                  RawRecord.RecordLength:=NextOfs+1;
                  RawRecord.CalculateChecksumByte;
                  RawRecord.WriteTo(FWriter);
                end;
              { prepare next chunk }
              Inc(ChunkStart, ChunkLen);
              ChunkLen:=Min(MaxChunkSize, sec.Data.size-ChunkStart);
              ChunkFixupStart:=ChunkFixupEnd+1;
            end;
            RawRecord.Free;
            RawRecord := nil;
          end;
      end;

    procedure TOmfObjOutput.WriteLinNumRecords(sec: TOmfObjSection);
      var
        SegIndex: Integer;
        RawRecord: TOmfRawRecord;
        LinNumRec: TOMFRecordLINNUMMsLink;
      begin
        if (oso_data in sec.SecOptions) then
          begin
            if sec.Data=nil then
              InternalError(2004030706);
            if sec.LinNumEntries.Count=0 then
              exit;
            SegIndex:=Segments.FindIndexOf(sec.Name);
            RawRecord:=TOmfRawRecord.Create;
            LinNumRec:=TOMFRecordLINNUMMsLink.Create;
            LinNumRec.BaseGroup:=0;
            LinNumRec.BaseSegment:=SegIndex;
            LinNumRec.LineNumberList:=sec.LinNumEntries;

            while LinNumRec.NextIndex<sec.LinNumEntries.Count do
              begin
                LinNumRec.EncodeTo(RawRecord);
                RawRecord.WriteTo(FWriter);
              end;

            LinNumRec.Free;
            LinNumRec := nil;
            RawRecord.Free;
            RawRecord := nil;
          end;
      end;

    procedure TOmfObjOutput.section_count_sections(p: TObject; arg: pointer);
      begin
        TOmfObjSection(p).index:=pinteger(arg)^;
        inc(pinteger(arg)^);
      end;

    procedure TOmfObjOutput.group_count_groups(p: TObject; arg: pointer);
      begin
        TObjSectionGroup(p).index:=pinteger(arg)^;
        inc(pinteger(arg)^);
      end;

    procedure TOmfObjOutput.WritePUBDEFs(Data: TObjData);
      var
        PubNamesForSection: array of TFPHashObjectList;
        i: Integer;
        objsym: TObjSymbol;
        PublicNameElem: TOmfPublicNameElement;
        RawRecord: TOmfRawRecord;
        PubDefRec: TOMFRecordPUBDEF;
      begin
        PubNamesForSection:=nil;
        RawRecord:=TOmfRawRecord.Create;
        SetLength(PubNamesForSection,Data.ObjSectionList.Count);
        for i:=0 to Data.ObjSectionList.Count-1 do
          PubNamesForSection[i]:=TFPHashObjectList.Create;

        for i:=0 to Data.ObjSymbolList.Count-1 do
          begin
            objsym:=TObjSymbol(Data.ObjSymbolList[i]);
            if objsym.bind=AB_GLOBAL then
              begin
                PublicNameElem:=TOmfPublicNameElement.Create(PubNamesForSection[objsym.objsection.index-1],objsym.Name);
                PublicNameElem.PublicOffset:=objsym.offset;
                PublicNameElem.IsLocal:=False;
              end
            else if objsym.bind=AB_LOCAL then
              begin
                PublicNameElem:=TOmfPublicNameElement.Create(PubNamesForSection[objsym.objsection.index-1],objsym.Name);
                PublicNameElem.PublicOffset:=objsym.offset;
                PublicNameElem.IsLocal:=True;
              end
          end;

        for i:=0 to Data.ObjSectionList.Count-1 do
          if PubNamesForSection[i].Count>0 then
            begin
              PubDefRec:=TOMFRecordPUBDEF.Create;
              PubDefRec.BaseSegmentIndex:=i+1;
              if TOmfObjSection(Data.ObjSectionList[i]).PrimaryGroup<>nil then
                PubDefRec.BaseGroupIndex:=Groups.FindIndexOf(TOmfObjSection(Data.ObjSectionList[i]).PrimaryGroup.Name)
              else
                PubDefRec.BaseGroupIndex:=0;
              PubDefRec.PublicNames:=PubNamesForSection[i];
              while PubDefRec.NextIndex<PubDefRec.PublicNames.Count do
                begin
                  PubDefRec.EncodeTo(RawRecord);
                  RawRecord.WriteTo(FWriter);
                end;
              PubDefRec.Free;
              PubDefRec := nil;
            end;

        for i:=0 to Data.ObjSectionList.Count-1 do
          FreeAndNil(PubNamesForSection[i]);
        RawRecord.Free;
        RawRecord := nil;
      end;

    procedure TOmfObjOutput.WriteEXTDEFs(Data: TObjData);
      var
        ExtNames: TFPHashObjectList;
        RawRecord: TOmfRawRecord;
        i,idx: Integer;
        objsym: TObjSymbol;
        ExtDefRec: TOMFRecordEXTDEF;
      begin
        ExtNames:=TFPHashObjectList.Create;
        RawRecord:=TOmfRawRecord.Create;

        idx:=1;
        for i:=0 to Data.ObjSymbolList.Count-1 do
          begin
            objsym:=TObjSymbol(Data.ObjSymbolList[i]);
            if objsym.bind=AB_EXTERNAL then
              begin
                TOmfExternalNameElement.Create(ExtNames,objsym.Name);
                objsym.symidx:=idx;
                Inc(idx);
              end;
          end;

        if ExtNames.Count>0 then
          begin
            ExtDefRec:=TOMFRecordEXTDEF.Create;
            ExtDefRec.ExternalNames:=ExtNames;
            while ExtDefRec.NextIndex<ExtDefRec.ExternalNames.Count do
              begin
                ExtDefRec.EncodeTo(RawRecord);
                RawRecord.WriteTo(FWriter);
              end;
            ExtDefRec.Free;
            ExtDefRec := nil;
          end;

        ExtNames.Free;
        ExtNames := nil;
        RawRecord.Free;
        RawRecord := nil;
      end;

    function TOmfObjOutput.WriteData(Data:TObjData):boolean;
      var
        RawRecord: TOmfRawRecord;
        Header: TOMFRecordTHEADR;
        Translator_COMENT: TOMFRecordCOMENT;
        DebugFormat_COMENT: TOMFRecordCOMENT;
        LinkPassSeparator_COMENT: TOMFRecordCOMENT;
        LNamesRec: TOMFRecordLNAMES;
        ModEnd: TOMFRecordMODEND;
        I: Integer;
        SegDef: TOMFRecordSEGDEF;
        GrpDef: TOMFRecordGRPDEF;
        nsections,ngroups: Integer;
      begin
        { calc amount of sections we have and set their index, starting with 1 }
        nsections:=1;
        data.ObjSectionList.ForEachCall(@section_count_sections,@nsections);
        { calc amount of groups we have and set their index, starting with 1 }
        ngroups:=1;
        data.GroupsList.ForEachCall(@group_count_groups,@ngroups);
        { maximum amount of sections supported in the omf format is $7fff }
        if (nsections-1)>$7fff then
          InternalError(2015040701);
        { maximum amount of groups supported in the omf format is $7fff }
        if (ngroups-1)>$7fff then
          InternalError(2018062101);

        { write header record }
        RawRecord:=TOmfRawRecord.Create;
        Header:=TOMFRecordTHEADR.Create;
        if cs_debuginfo in CurrentSettings.ModuleSwitches then
          Header.ModuleName:=TOmfObjData(Data).MainSource
        else
          Header.ModuleName:=Data.Name;
        Header.EncodeTo(RawRecord);
        RawRecord.WriteTo(FWriter);
        Header.Free;
        Header := nil;

        { write translator COMENT header }
        Translator_COMENT:=TOMFRecordCOMENT.Create;
        Translator_COMENT.CommentClass:=CC_Translator;
        Translator_COMENT.CommentString:='FPC '+Full_Version_String+
        ' ['+DateString+'] for '+TargetCPUString+' - '+TargetInfo.shortname;
        Translator_COMENT.EncodeTo(RawRecord);
        RawRecord.WriteTo(FWriter);
        Translator_COMENT.Free;
        Translator_COMENT := nil;

        if (TargetDbg.id=dbg_codeview) or
           ((ds_dwarf_omf_linnum in CurrentSettings.DebugSwitches) and
            (TargetDbg.id in [dbg_dwarf3,dbg_dwarf4,dbg_dwarf5])) then
          begin
            DebugFormat_COMENT:=TOMFRecordCOMENT.Create;
            DebugFormat_COMENT.CommentClass:=CC_NewOmfExtension;
            DebugFormat_COMENT.CommentString:='';
            DebugFormat_COMENT.EncodeTo(RawRecord);
            RawRecord.WriteTo(FWriter);
            DebugFormat_COMENT.Free;
            DebugFormat_COMENT := nil;
          end;

        LNames.Clear;
        LNames.Add('');  { insert an empty string, which has index 1 }
        FSegments.Clear;
        FSegments.Add('',nil);
        FGroups.Clear;
        FGroups.Add('',nil);

        for i:=0 to Data.GroupsList.Count-1 do
          AddGroup(TObjSectionGroup(Data.GroupsList[I]));
        for i:=0 to Data.ObjSectionList.Count-1 do
          with TOmfObjSection(Data.ObjSectionList[I]) do
            AddSegment(Name,ClassName,OverlayName,OmfAlignment,Combination,Use,Size);

        { write LNAMES record(s) }
        LNamesRec:=TOMFRecordLNAMES.Create;
        LNamesRec.Names:=LNames;
        while LNamesRec.NextIndex<=LNames.Count do
          begin
            LNamesRec.EncodeTo(RawRecord);
            RawRecord.WriteTo(FWriter);
          end;
        LNamesRec.Free;
        LNamesRec := nil;

        { write SEGDEF record(s) }
        for I:=1 to Segments.Count-1 do
          begin
            SegDef:=TOMFRecordSEGDEF(Segments[I]);
            SegDef.EncodeTo(RawRecord);
            RawRecord.WriteTo(FWriter);
          end;

        { write GRPDEF record(s) }
        for I:=1 to Groups.Count-1 do
          begin
            GrpDef:=TOMFRecordGRPDEF(Groups[I]);
            GrpDef.EncodeTo(RawRecord);
            RawRecord.WriteTo(FWriter);
          end;

        { write PUBDEF record(s) }
        WritePUBDEFs(Data);

        { write EXTDEF record(s) }
        WriteEXTDEFs(Data);

        { write link pass separator }
        LinkPassSeparator_COMENT:=TOMFRecordCOMENT.Create;
        LinkPassSeparator_COMENT.CommentClass:=CC_LinkPassSeparator;
        LinkPassSeparator_COMENT.CommentString:=#1;
        LinkPassSeparator_COMENT.NoList:=True;
        LinkPassSeparator_COMENT.EncodeTo(RawRecord);
        RawRecord.WriteTo(FWriter);
        LinkPassSeparator_COMENT.Free;
        LinkPassSeparator_COMENT := nil;

        { write section content, interleaved with fixups }
        WriteSections(Data);

        { write MODEND record }
        ModEnd:=TOMFRecordMODEND.Create;
        ModEnd.EncodeTo(RawRecord);
        RawRecord.WriteTo(FWriter);
        ModEnd.Free;
        ModEnd := nil;

        RawRecord.Free;
        RawRecord := nil;
        result:=true;
      end;

    constructor TOmfObjOutput.create(AWriter:TObjectWriter);
      begin
        inherited create(AWriter);
        cobjdata:=TOmfObjData;
        FLNames:=TOmfOrderedNameCollection.Create(False);
        FSegments:=TFPHashObjectList.Create;
        FSegments.Add('',nil);
        FGroups:=TFPHashObjectList.Create;
        FGroups.Add('',nil);
      end;

    destructor TOmfObjOutput.Destroy;
      begin
        FGroups.Free;
        FGroups := nil;
        FSegments.Free;
        FSegments := nil;
        FLNames.Free;
        FLNames := nil;
        inherited Destroy;
      end;

    procedure TOmfObjOutput.WriteDllImport(const dllname,afuncname,mangledname: string; ordnr: LongInt; isvar: boolean);
      var
        RawRecord: TOmfRawRecord;
        Header: TOMFRecordTHEADR;
        DllImport_COMENT: TOMFRecordCOMENT=nil;
        DllImport_COMENT_IMPDEF: TOMFRecordCOMENTIMPDEF=nil;
        ModEnd: TOMFRecordMODEND;
      begin
        { write header record }
        RawRecord:=TOmfRawRecord.Create;
        Header:=TOMFRecordTHEADR.Create;
        Header.ModuleName:=mangledname;
        Header.EncodeTo(RawRecord);
        RawRecord.WriteTo(FWriter);
        Header.Free;
        Header := nil;

        { write IMPDEF record }
        DllImport_COMENT_IMPDEF:=TOMFRecordCOMENTIMPDEF.Create;
        DllImport_COMENT_IMPDEF.InternalName:=mangledname;
        DllImport_COMENT_IMPDEF.ModuleName:=dllname;
        if ordnr <= 0 then
          begin
            DllImport_COMENT_IMPDEF.ImportByOrdinal:=False;
            DllImport_COMENT_IMPDEF.Name:=afuncname;
          end
        else
          begin
            DllImport_COMENT_IMPDEF.ImportByOrdinal:=True;
            DllImport_COMENT_IMPDEF.Ordinal:=ordnr;
          end;

        DllImport_COMENT:=TOMFRecordCOMENT.Create;
        DllImport_COMENT_IMPDEF.EncodeTo(DllImport_COMENT);
        FreeAndNil(DllImport_COMENT_IMPDEF);
        DllImport_COMENT.EncodeTo(RawRecord);
        FreeAndNil(DllImport_COMENT);
        RawRecord.WriteTo(FWriter);

        { write MODEND record }
        ModEnd:=TOMFRecordMODEND.Create;
        ModEnd.EncodeTo(RawRecord);
        RawRecord.WriteTo(FWriter);
        ModEnd.Free;
        ModEnd := nil;

        RawRecord.Free;
        RawRecord := nil;
      end;

{****************************************************************************
                               TOmfObjInput
****************************************************************************}

    function TOmfObjInput.PeekNextRecordType: Byte;
      var
        OldPos: LongInt;
      begin
        OldPos:=FReader.Pos;
        if not FReader.read(Result, 1) then
          begin
            InputError('Unexpected end of file');
            Result:=0;
            exit;
          end;
        FReader.seek(OldPos);
      end;

    function TOmfObjInput.ReadLNames(RawRec: TOmfRawRecord): Boolean;
      var
        LNamesRec: TOMFRecordLNAMES;
      begin
        Result:=False;
        LNamesRec:=TOMFRecordLNAMES.Create;
        LNamesRec.Names:=LNames;
        LNamesRec.DecodeFrom(RawRec);
        LNamesRec.Free;
        LNamesRec := nil;
        Result:=True;
      end;

    function TOmfObjInput.ReadSegDef(RawRec: TOmfRawRecord; objdata: TObjData): Boolean;
      var
        SegDefRec: TOMFRecordSEGDEF;
        SegmentName,SegClassName,OverlayName: string;
        SecAlign: LongInt;
        secoptions: TObjSectionOptions;
        objsec: TOmfObjSection;
      begin
        Result:=False;
        SegDefRec:=TOMFRecordSEGDEF.Create;
        SegDefRec.DecodeFrom(RawRec);
        if (SegDefRec.SegmentNameIndex<1) or (SegDefRec.SegmentNameIndex>LNames.Count) then
          begin
            InputError('Segment name index out of range');
            SegDefRec.Free;
            SegDefRec := nil;
            exit;
          end;
        SegmentName:=LNames[SegDefRec.SegmentNameIndex];
        if (SegDefRec.ClassNameIndex<1) or (SegDefRec.ClassNameIndex>LNames.Count) then
          begin
            InputError('Segment class name index out of range');
            SegDefRec.Free;
            SegDefRec := nil;
            exit;
          end;
        SegClassName:=LNames[SegDefRec.ClassNameIndex];
        if (SegDefRec.OverlayNameIndex<1) or (SegDefRec.OverlayNameIndex>LNames.Count) then
          begin
            InputError('Segment overlay name index out of range');
            SegDefRec.Free;
            SegDefRec := nil;
            exit;
          end;
        OverlayName:=LNames[SegDefRec.OverlayNameIndex];
        SecAlign:=1; // otherwise warning prohibits compilation
        case SegDefRec.Alignment of
          saRelocatableByteAligned:
            SecAlign:=1;
          saRelocatableWordAligned:
            SecAlign:=2;
          saRelocatableParaAligned:
            SecAlign:=16;
          saRelocatableDWordAligned:
            SecAlign:=4;
          saRelocatablePageAligned:
            SecAlign:=256;
          saNotSupported:
            SecAlign:=4096;
          saAbsolute:
            begin
              InputError('Absolute segment alignment not supported');
              SegDefRec.Free;
              SegDefRec := nil;
              exit;
            end;
          saNotDefined:
            begin
              InputError('Invalid (unsupported/undefined) OMF segment alignment');
              SegDefRec.Free;
              SegDefRec := nil;
              exit;
            end;
        end;
        if not CaseSensitiveSegments then
          begin
            SegmentName:=UpCase(SegmentName);
            SegClassName:=UpCase(SegClassName);
            OverlayName:=UpCase(OverlayName);
          end;
        { hack for supporting object modules, generated by Borland's BINOBJ tool }
        if (SegClassName='') and (SegmentName='CODE') then
          begin
            SegmentName:=InputFileName;
            SegClassName:='CODE';
          end;
        secoptions:=[];
        objsec:=TOmfObjSection(objdata.createsection(SegmentName+'||'+SegClassName,SecAlign,secoptions,false));
        objsec.FClassName:=SegClassName;
        objsec.FOverlayName:=OverlayName;
        objsec.FCombination:=SegDefRec.Combination;
        objsec.FUse:=SegDefRec.Use;
        if SegDefRec.SegmentLength>High(objsec.Size) then
          begin
            InputError('Segment too large');
            SegDefRec.Free;
            SegDefRec := nil;
            exit;
          end;
        objsec.Size:=SegDefRec.SegmentLength;
        if SegClassName='DWARF' then
          objsec.SecOptions:=objsec.SecOptions+[oso_debug];
        if (SegClassName='HEAP') or
           (SegClassName='STACK') or (SegDefRec.Combination=scStack) or
           (SegClassName='BEGDATA') or
           (SegmentName='FPC') then
          objsec.SecOptions:=objsec.SecOptions+[oso_keep];
        SegDefRec.Free;
        SegDefRec := nil;
        Result:=True;
      end;

    function TOmfObjInput.ReadGrpDef(RawRec: TOmfRawRecord; objdata: TObjData): Boolean;
      var
        GrpDefRec: TOMFRecordGRPDEF;
        GroupName: string;
        SecGroup: TObjSectionGroup;
        i,SegIndex: Integer;
      begin
        Result:=False;
        GrpDefRec:=TOMFRecordGRPDEF.Create;
        GrpDefRec.DecodeFrom(RawRec);
        if (GrpDefRec.GroupNameIndex<1) or (GrpDefRec.GroupNameIndex>LNames.Count) then
          begin
            InputError('Group name index out of range');
            GrpDefRec.Free;
            GrpDefRec := nil;
            exit;
          end;
        GroupName:=LNames[GrpDefRec.GroupNameIndex];
        if not CaseSensitiveSegments then
          GroupName:=UpCase(GroupName);
        SecGroup:=objdata.createsectiongroup(GroupName);
        SetLength(SecGroup.members,Length(GrpDefRec.SegmentList));
        for i:=0 to Length(GrpDefRec.SegmentList)-1 do
          begin
            SegIndex:=GrpDefRec.SegmentList[i];
            if (SegIndex<1) or (SegIndex>objdata.ObjSectionList.Count) then
              begin
                InputError('Segment name index out of range in group definition');
                GrpDefRec.Free;
                GrpDefRec := nil;
                exit;
              end;
            SecGroup.members[i]:=TOmfObjSection(objdata.ObjSectionList[SegIndex-1]);
          end;
        GrpDefRec.Free;
        GrpDefRec := nil;
        Result:=True;
      end;

    function TOmfObjInput.ReadExtDef(RawRec: TOmfRawRecord; objdata: TObjData): Boolean;
      var
        ExtDefRec: TOMFRecordEXTDEF;
        ExtDefElem: TOmfExternalNameElement;
        OldCount,NewCount,i: Integer;
        objsym: TObjSymbol;
        symname: TSymStr;
      begin
        Result:=False;
        ExtDefRec:=TOMFRecordEXTDEF.Create;
        ExtDefRec.ExternalNames:=ExtDefs;
        OldCount:=ExtDefs.Count;
        ExtDefRec.DecodeFrom(RawRec);
        NewCount:=ExtDefs.Count;
        for i:=OldCount to NewCount-1 do
          begin
            ExtDefElem:=TOmfExternalNameElement(ExtDefs[i]);
            symname:=ExtDefElem.Name;
            if not CaseSensitiveSymbols then
              symname:=UpCase(symname);
            objsym:=objdata.CreateSymbol(symname);
            objsym.bind:=AB_EXTERNAL;
            objsym.typ:=AT_FUNCTION;
            objsym.objsection:=nil;
            objsym.offset:=0;
            objsym.size:=0;
          end;
        ExtDefRec.Free;
        ExtDefRec := nil;
        Result:=True;
      end;

    function TOmfObjInput.ReadPubDef(RawRec: TOmfRawRecord; objdata:TObjData): Boolean;
      var
        PubDefRec: TOMFRecordPUBDEF;
        PubDefElem: TOmfPublicNameElement;
        OldCount,NewCount,i: Integer;
        basegroup: TObjSectionGroup;
        objsym: TObjSymbol;
        objsec: TOmfObjSection;
        symname: TSymStr;
      begin
        Result:=False;
        PubDefRec:=TOMFRecordPUBDEF.Create;
        PubDefRec.PublicNames:=PubDefs;
        OldCount:=PubDefs.Count;
        PubDefRec.DecodeFrom(RawRec);
        NewCount:=PubDefs.Count;
        if (PubDefRec.BaseGroupIndex<0) or (PubDefRec.BaseGroupIndex>objdata.GroupsList.Count) then
          begin
            InputError('Public symbol''s group name index out of range');
            PubDefRec.Free;
            PubDefRec := nil;
            exit;
          end;
        if PubDefRec.BaseGroupIndex<>0 then
          basegroup:=TObjSectionGroup(objdata.GroupsList[PubDefRec.BaseGroupIndex-1])
        else
          basegroup:=nil;
        if (PubDefRec.BaseSegmentIndex<0) or (PubDefRec.BaseSegmentIndex>objdata.ObjSectionList.Count) then
          begin
            InputError('Public symbol''s segment name index out of range');
            PubDefRec.Free;
            PubDefRec := nil;
            exit;
          end;
        if PubDefRec.BaseSegmentIndex=0 then
          begin
            InputError('Public symbol uses absolute addressing, which is not supported by this linker');
            PubDefRec.Free;
            PubDefRec := nil;
            exit;
          end;
        objsec:=TOmfObjSection(objdata.ObjSectionList[PubDefRec.BaseSegmentIndex-1]);
        for i:=OldCount to NewCount-1 do
          begin
            PubDefElem:=TOmfPublicNameElement(PubDefs[i]);
            symname:=PubDefElem.Name;
            if not CaseSensitiveSymbols then
              symname:=UpCase(symname);
            objsym:=objdata.CreateSymbol(symname);
            if PubDefElem.IsLocal then
              objsym.bind:=AB_LOCAL
            else
              objsym.bind:=AB_GLOBAL;
            objsym.typ:=AT_FUNCTION;
            objsym.group:=basegroup;
            objsym.objsection:=objsec;
            objsym.offset:=PubDefElem.PublicOffset;
            objsym.size:=0;
            if (objsym.bind=AB_GLOBAL) and (objsec.FFirstSym=nil) then
              objsec.FFirstSym:=objsym;
          end;
        PubDefRec.Free;
        PubDefRec := nil;
        Result:=True;
      end;

    function TOmfObjInput.ReadModEnd(RawRec: TOmfRawRecord; objdata:TObjData): Boolean;
      var
        ModEndRec: TOMFRecordMODEND;
        objsym: TObjSymbol;
        objsec: TOmfObjSection;
        basegroup: TObjSectionGroup;
      begin
        Result:=False;
        ModEndRec:=TOMFRecordMODEND.Create;
        ModEndRec.DecodeFrom(RawRec);
        if ModEndRec.HasStartAddress then
          begin
            if not ModEndRec.LogicalStartAddress then
              begin
                InputError('Physical start address not supported');
                ModEndRec.Free;
                ModEndRec := nil;
                exit;
              end;
            if not (ModEndRec.TargetMethod in [ftmSegmentIndex,ftmSegmentIndexNoDisp]) then
              begin
                InputError('Target method for start address other than "Segment Index" is not supported');
                ModEndRec.Free;
                ModEndRec := nil;
                exit;
              end;
            if (ModEndRec.TargetDatum<1) or (ModEndRec.TargetDatum>objdata.ObjSectionList.Count) then
              begin
                InputError('Segment name index for start address out of range');
                ModEndRec.Free;
                ModEndRec := nil;
                exit;
              end;
            case ModEndRec.FrameMethod of
              ffmSegmentIndex:
                begin
                  if (ModEndRec.FrameDatum<1) or (ModEndRec.FrameDatum>objdata.ObjSectionList.Count) then
                    begin
                      InputError('Frame segment name index for start address out of range');
                      ModEndRec.Free;
                      ModEndRec := nil;
                      exit;
                    end;
                  if ModEndRec.FrameDatum<>ModEndRec.TargetDatum then
                    begin
                      InputError('Frame segment different than target segment is not supported supported for start address');
                      ModEndRec.Free;
                      ModEndRec := nil;
                      exit;
                    end;
                  basegroup:=nil;
                end;
              ffmGroupIndex:
                begin
                  if (ModEndRec.FrameDatum<1) or (ModEndRec.FrameDatum>objdata.GroupsList.Count) then
                    begin
                      InputError('Frame group name index for start address out of range');
                      ModEndRec.Free;
                      ModEndRec := nil;
                      exit;
                    end;
                  basegroup:=TObjSectionGroup(objdata.GroupsList[ModEndRec.FrameDatum-1]);
                end;
              else
                begin
                  InputError('Frame method for start address other than "Segment Index" or "Group Index" is not supported');
                  ModEndRec.Free;
                  ModEndRec := nil;
                  exit;
                end;
            end;
            objsec:=TOmfObjSection(objdata.ObjSectionList[ModEndRec.TargetDatum-1]);

            objsym:=objdata.CreateSymbol('..start');
            objsym.bind:=AB_GLOBAL;
            objsym.typ:=AT_FUNCTION;
            objsym.group:=basegroup;
            objsym.objsection:=objsec;
            objsym.offset:=ModEndRec.TargetDisplacement;
            objsym.size:=0;
          end;
        ModEndRec.Free;
        ModEndRec := nil;
        Result:=True;
      end;

    function TOmfObjInput.ReadLeOrLiDataAndFixups(RawRec: TOmfRawRecord; objdata: TObjData): Boolean;
      var
        Is32Bit: Boolean;
        NextOfs: Integer;
        SegmentIndex: Integer;
        EnumeratedDataOffset: DWord;
        BlockLength: Integer;
        objsec: TOmfObjSection;
        FixupRawRec: TOmfRawRecord=nil;
        Fixup: TOMFSubRecordFIXUP;
        Thread: TOMFSubRecordTHREAD;
        FixuppWithoutLeOrLiData: Boolean=False;
      begin
        objsec:=nil;
        EnumeratedDataOffset:=0;
        Result:=False;
        case RawRec.RecordType of
          RT_LEDATA,RT_LEDATA32:
            begin
              Is32Bit:=RawRec.RecordType=RT_LEDATA32;
              NextOfs:=RawRec.ReadIndexedRef(0,SegmentIndex);
              if Is32Bit then
                begin
                  if (NextOfs+3)>=RawRec.RecordLength then
                    InternalError(2015040512);
                  EnumeratedDataOffset := LEtoN(unaligned(PUint32(@RawRec.RawData[NextOfs{..NextOfs+3}])^));
                  Inc(NextOfs,4);
                end
              else
                begin
                  if (NextOfs+1)>=RawRec.RecordLength then
                    InternalError(2015040513);
                  EnumeratedDataOffset := LEtoN(unaligned(PUint16(@RawRec.RawData[NextOfs{..NextOfs+1}])^));
                  Inc(NextOfs,2);
                end;
              BlockLength:=RawRec.RecordLength-NextOfs-1;
              if BlockLength<0 then
                InternalError(2015060501);
              if BlockLength>1024 then
                begin
                  InputError('LEDATA contains more than 1024 bytes of data');
                  exit;
                end;

              if (SegmentIndex<1) or (SegmentIndex>objdata.ObjSectionList.Count) then
                begin
                  InputError('Segment index in LEDATA field is out of range');
                  exit;
                end;
              objsec:=TOmfObjSection(objdata.ObjSectionList[SegmentIndex-1]);

              objsec.SecOptions:=objsec.SecOptions+[oso_Data];
              if (objsec.Data.Size>EnumeratedDataOffset) then
                begin
                  InputError('LEDATA enumerated data offset field out of sequence');
                  exit;
                end;
              if (EnumeratedDataOffset+BlockLength)>objsec.Size then
                begin
                  InputError('LEDATA goes beyond the segment size declared in the SEGDEF record');
                  exit;
                end;
              objsec.Data.seek(EnumeratedDataOffset);
              objsec.Data.write(RawRec.RawData[NextOfs],BlockLength);
            end;
          RT_LIDATA,RT_LIDATA32:
            begin
              InputError('LIDATA records are not supported');
              exit;
            end;
          RT_FIXUPP,RT_FIXUPP32:
            begin
              FixuppWithoutLeOrLiData:=True;
              { a hack, used to indicate, that we must process this record       }
              { (RawRec) first in the FIXUPP record processing loop that follows }
              FixupRawRec:=RawRec;
            end;
          else
            InternalError(2015040316);
        end;

        { also read all the FIXUPP records that may follow;                     }
        { (FixupRawRec=RawRec) indicates that we must process RawRec first, but }
        { without freeing it                                                    }
        while (FixupRawRec=RawRec) or (PeekNextRecordType in [RT_FIXUPP,RT_FIXUPP32]) do
          begin
            if FixupRawRec<>RawRec then
              begin
                FixupRawRec:=TOmfRawRecord.Create;
                FixupRawRec.ReadFrom(FReader);
                if not FRawRecord.VerifyChecksumByte then
                  begin
                    InputError('Invalid checksum in OMF record');
                    FixupRawRec.Free;
                    FixupRawRec := nil;
                    exit;
                  end;
              end;
            NextOfs:=0;
            Thread:=TOMFSubRecordTHREAD.Create;
            Fixup:=TOMFSubRecordFIXUP.Create;
            Fixup.Is32Bit:=FixupRawRec.RecordType=RT_FIXUPP32;
            Fixup.DataRecordStartOffset:=EnumeratedDataOffset;
            while NextOfs<(FixupRawRec.RecordLength-1) do
              begin
                if (FixupRawRec.RawData[NextOfs] and $80)<>0 then
                  begin
                    { FIXUP subrecord }
                    if FixuppWithoutLeOrLiData then
                      begin
                        InputError('FIXUP subrecord without previous LEDATA or LIDATA record');
                        Fixup.Free;
                        Fixup := nil;
                        Thread.Free;
                        Thread := nil;
                        if FixupRawRec<>RawRec then
                          begin
                            FixupRawRec.Free;
                            FixupRawRec := nil;
                          end;
                        exit;
                      end;
                    NextOfs:=Fixup.ReadAt(FixupRawRec,NextOfs);
                    Fixup.ResolveByThread(FFixupThreads);
                    ImportOmfFixup(objdata,objsec,Fixup);
                  end
                else
                  begin
                    { THREAD subrecord }
                    NextOfs:=Thread.ReadAt(FixupRawRec,NextOfs);
                    Thread.ApplyTo(FFixupThreads);
                  end;
              end;
            Fixup.Free;
            Fixup := nil;
            Thread.Free;
            Thread := nil;
            if FixupRawRec<>RawRec then
              FixupRawRec.Free;
            { always set it to null, so that we read the next record on the next }
            { loop iteration (this ensures that FixupRawRec<>RawRec, without     }
            { freeing RawRec)                                                    }
            FixupRawRec:=nil;
          end;
        Result:=True;
      end;

    function TOmfObjInput.ReadImpDef(Rec: TOMFRecordCOMENT; objdata: TObjData): Boolean;
      var
        ImpDefRec: TOMFRecordCOMENTIMPDEF;
        SymName: string;
      begin
        ImpDefRec:=TOMFRecordCOMENTIMPDEF.Create;
        ImpDefRec.DecodeFrom(Rec);
        SymName:=ImpDefRec.InternalName;
        if not CaseSensitiveSymbols then
          SymName:=UpCase(SymName);
        if ImpDefRec.ImportByOrdinal then
          TOmfObjData(objdata).AddImportSymbol(MaybeAddDllExt(ImpDefRec.ModuleName),'',SymName,ImpDefRec.Ordinal,false)
        else
          TOmfObjData(objdata).AddImportSymbol(MaybeAddDllExt(ImpDefRec.ModuleName),ImpDefRec.Name,SymName,0,false);
        Result:=True;
        ImpDefRec.Free;
        ImpDefRec := nil;
      end;

    function TOmfObjInput.ReadExpDef(Rec: TOMFRecordCOMENT; objdata: TObjData): Boolean;
      var
        ExpDefRec: TOMFRecordCOMENTEXPDEF;
        SymName: string;
      begin
        ExpDefRec:=TOMFRecordCOMENTEXPDEF.Create;
        ExpDefRec.DecodeFrom(Rec);
        SymName:=ExpDefRec.InternalName;
        if not CaseSensitiveSymbols then
          SymName:=UpCase(SymName);
        TOmfObjData(objdata).AddExportSymbol(
          ExpDefRec.ExportByOrdinal,
          ExpDefRec.ResidentName,
          ExpDefRec.NoData,
          ExpDefRec.ParmCount,
          ExpDefRec.ExportedName,
          SymName,
          ExpDefRec.ExportOrdinal);
        Result:=True;
        ExpDefRec.Free;
        ExpDefRec := nil;
      end;

    function TOmfObjInput.ImportOmfFixup(objdata: TObjData; objsec: TOmfObjSection; Fixup: TOMFSubRecordFIXUP): Boolean;
      var
        reloc: TOmfRelocation;
        sym: TObjSymbol;
        RelocType: TObjRelocationType;
        target_section: TOmfObjSection;
        target_group: TObjSectionGroup;
      begin
        Result:=False;

        { range check location }
        if (Fixup.LocationOffset+Fixup.LocationSize)>objsec.Size then
          begin
            InputError('Fixup location exceeds the current segment boundary');
            exit;
          end;

        { range check target datum }
        case Fixup.TargetMethod of
          ftmSegmentIndex:
            if (Fixup.TargetDatum<1) or (Fixup.TargetDatum>objdata.ObjSectionList.Count) then
              begin
                InputError('Segment name index in SI(<segment name>),<displacement> fixup target is out of range');
                exit;
              end;
          ftmSegmentIndexNoDisp:
            if (Fixup.TargetDatum<1) or (Fixup.TargetDatum>objdata.ObjSectionList.Count) then
              begin
                InputError('Segment name index in SI(<segment name>) fixup target is out of range');
                exit;
              end;
          ftmGroupIndex:
            if (Fixup.TargetDatum<1) or (Fixup.TargetDatum>objdata.GroupsList.Count) then
              begin
                InputError('Group name index in GI(<group name>),<displacement> fixup target is out of range');
                exit;
              end;
          ftmGroupIndexNoDisp:
            if (Fixup.TargetDatum<1) or (Fixup.TargetDatum>objdata.GroupsList.Count) then
              begin
                InputError('Group name index in GI(<group name>) fixup target is out of range');
                exit;
              end;
          ftmExternalIndex:
            if (Fixup.TargetDatum<1) or (Fixup.TargetDatum>ExtDefs.Count) then
              begin
                InputError('External symbol name index in EI(<symbol name>),<displacement> fixup target is out of range');
                exit;
              end;
          ftmExternalIndexNoDisp:
            begin
              if (Fixup.TargetDatum<1) or (Fixup.TargetDatum>ExtDefs.Count) then
                begin
                  InputError('External symbol name index in EI(<symbol name>) fixup target is out of range');
                  exit;
                end;
            end;
          else
            ;
        end;

        { range check frame datum }
        case Fixup.FrameMethod of
          ffmSegmentIndex:
            if (Fixup.FrameDatum<1) or (Fixup.FrameDatum>objdata.ObjSectionList.Count) then
              begin
                InputError('Segment name index in SI(<segment name>) fixup frame is out of range');
                exit;
              end;
          ffmGroupIndex:
            if (Fixup.FrameDatum<1) or (Fixup.FrameDatum>objdata.GroupsList.Count) then
              begin
                InputError('Group name index in GI(<group name>) fixup frame is out of range');
                exit;
              end;
          ffmExternalIndex:
            if (Fixup.TargetDatum<1) or (Fixup.TargetDatum>ExtDefs.Count) then
              begin
                InputError('External symbol name index in EI(<symbol name>) fixup frame is out of range');
                exit;
              end;
          else
            ;
        end;

        if Fixup.TargetMethod in [ftmExternalIndex,ftmExternalIndexNoDisp] then
          begin
            sym:=objdata.symbolref(TOmfExternalNameElement(ExtDefs[Fixup.TargetDatum-1]).Name);
            RelocType:=RELOC_NONE;
            case Fixup.LocationType of
              fltOffset:
                case Fixup.Mode of
                  fmSegmentRelative:
                    RelocType:=RELOC_ABSOLUTE16;
                  fmSelfRelative:
                    RelocType:=RELOC_RELATIVE16;
                end;
              fltOffset32:
                case Fixup.Mode of
                  fmSegmentRelative:
                    RelocType:=RELOC_ABSOLUTE32;
                  fmSelfRelative:
                    RelocType:=RELOC_RELATIVE32;
                end;
              fltBase:
                case Fixup.Mode of
                  fmSegmentRelative:
                    RelocType:=RELOC_SEG;
                  fmSelfRelative:
                    RelocType:=RELOC_SEGREL;
                end;
              fltFarPointer:
                case Fixup.Mode of
                  fmSegmentRelative:
                    RelocType:=RELOC_FARPTR;
                  fmSelfRelative:
                    RelocType:=RELOC_FARPTR_RELATIVEOFFSET;
                end;
              fltFarPointer48:
                case Fixup.Mode of
                  fmSegmentRelative:
                    RelocType:=RELOC_FARPTR48;
                  fmSelfRelative:
                    RelocType:=RELOC_FARPTR48_RELATIVEOFFSET;
                end;
              else
                ;
            end;
            if RelocType=RELOC_NONE then
              begin
                InputError('Unsupported fixup location type '+ToStr(Ord(Fixup.LocationType))+' with mode '+ToStr(ord(Fixup.Mode))+' in external reference to '+sym.Name);
                exit;
              end;
            reloc:=TOmfRelocation.CreateSymbol(Fixup.LocationOffset,sym,RelocType);
            objsec.ObjRelocations.Add(reloc);
            case Fixup.FrameMethod of
              ffmTarget:
                {nothing};
              ffmGroupIndex:
                reloc.FrameGroup:=TObjSectionGroup(objdata.GroupsList[Fixup.FrameDatum-1]).Name;
              else
                begin
                  InputError('Unsupported frame method '+IntToStr(Ord(Fixup.FrameMethod))+' in external reference to '+sym.Name);
                  exit;
                end;
            end;
            if Fixup.TargetDisplacement<>0 then
              begin
                InputError('Unsupported nonzero target displacement '+IntToStr(Fixup.TargetDisplacement)+' in external reference to '+sym.Name);
                exit;
              end;
          end
        else if Fixup.TargetMethod in [ftmSegmentIndex,ftmSegmentIndexNoDisp] then
          begin
            target_section:=TOmfObjSection(objdata.ObjSectionList[Fixup.TargetDatum-1]);
            RelocType:=RELOC_NONE;
            case Fixup.LocationType of
              fltOffset:
                case Fixup.Mode of
                  fmSegmentRelative:
                    RelocType:=RELOC_ABSOLUTE16;
                  fmSelfRelative:
                    RelocType:=RELOC_RELATIVE16;
                end;
              fltOffset32:
                case Fixup.Mode of
                  fmSegmentRelative:
                    RelocType:=RELOC_ABSOLUTE32;
                  fmSelfRelative:
                    RelocType:=RELOC_RELATIVE32;
                end;
              fltBase:
                case Fixup.Mode of
                  fmSegmentRelative:
                    RelocType:=RELOC_SEG;
                  fmSelfRelative:
                    RelocType:=RELOC_SEGREL;
                end;
              fltFarPointer:
                case Fixup.Mode of
                  fmSegmentRelative:
                    RelocType:=RELOC_FARPTR;
                  fmSelfRelative:
                    RelocType:=RELOC_FARPTR_RELATIVEOFFSET;
                end;
              fltFarPointer48:
                case Fixup.Mode of
                  fmSegmentRelative:
                    RelocType:=RELOC_FARPTR48;
                  fmSelfRelative:
                    RelocType:=RELOC_FARPTR48_RELATIVEOFFSET;
                end;
              else
                ;
            end;
            if RelocType=RELOC_NONE then
              begin
                InputError('Unsupported fixup location type '+ToStr(Ord(Fixup.LocationType))+' with mode '+ToStr(ord(Fixup.Mode)));
                exit;
              end;
            reloc:=TOmfRelocation.CreateSection(Fixup.LocationOffset,target_section,RelocType);
            objsec.ObjRelocations.Add(reloc);
            case Fixup.FrameMethod of
              ffmTarget:
                {nothing};
              ffmGroupIndex:
                reloc.FrameGroup:=TObjSectionGroup(objdata.GroupsList[Fixup.FrameDatum-1]).Name;
              else
                begin
                  InputError('Unsupported frame method '+IntToStr(Ord(Fixup.FrameMethod))+' in reference to segment '+target_section.Name);
                  exit;
                end;
            end;
            if Fixup.TargetDisplacement<>0 then
              begin
                InputError('Unsupported nonzero target displacement '+IntToStr(Fixup.TargetDisplacement)+' in reference to segment '+target_section.Name);
                exit;
              end;
          end
        else if Fixup.TargetMethod in [ftmGroupIndex,ftmGroupIndexNoDisp] then
          begin
            target_group:=TObjSectionGroup(objdata.GroupsList[Fixup.TargetDatum-1]);
            RelocType:=RELOC_NONE;
            case Fixup.LocationType of
              fltOffset:
                case Fixup.Mode of
                  fmSegmentRelative:
                    RelocType:=RELOC_ABSOLUTE16;
                  fmSelfRelative:
                    RelocType:=RELOC_RELATIVE16;
                end;
              fltOffset32:
                case Fixup.Mode of
                  fmSegmentRelative:
                    RelocType:=RELOC_ABSOLUTE32;
                  fmSelfRelative:
                    RelocType:=RELOC_RELATIVE32;
                end;
              fltBase:
                case Fixup.Mode of
                  fmSegmentRelative:
                    RelocType:=RELOC_SEG;
                  fmSelfRelative:
                    RelocType:=RELOC_SEGREL;
                end;
              fltFarPointer:
                case Fixup.Mode of
                  fmSegmentRelative:
                    RelocType:=RELOC_FARPTR;
                  fmSelfRelative:
                    RelocType:=RELOC_FARPTR_RELATIVEOFFSET;
                end;
              fltFarPointer48:
                case Fixup.Mode of
                  fmSegmentRelative:
                    RelocType:=RELOC_FARPTR48;
                  fmSelfRelative:
                    RelocType:=RELOC_FARPTR48_RELATIVEOFFSET;
                end;
              else
                ;
            end;
            if RelocType=RELOC_NONE then
              begin
                InputError('Unsupported fixup location type '+ToStr(Ord(Fixup.LocationType))+' with mode '+ToStr(ord(Fixup.Mode)));
                exit;
              end;
            reloc:=TOmfRelocation.CreateGroup(Fixup.LocationOffset,target_group,RelocType);
            objsec.ObjRelocations.Add(reloc);
            case Fixup.FrameMethod of
              ffmTarget:
                {nothing};
              else
                begin
                  InputError('Unsupported frame method '+IntToStr(Ord(Fixup.FrameMethod))+' in reference to group '+target_group.Name);
                  exit;
                end;
            end;
            if Fixup.TargetDisplacement<>0 then
              begin
                InputError('Unsupported nonzero target displacement '+IntToStr(Fixup.TargetDisplacement)+' in reference to group '+target_group.Name);
                exit;
              end;
          end
        else
          begin
            {todo: convert other fixup types as well }
            InputError('Unsupported fixup target method '+IntToStr(Ord(Fixup.TargetMethod)));
            exit;
          end;

        Result:=True;
      end;

    constructor TOmfObjInput.create;
      begin
        inherited create;
        cobjdata:=TOmfObjData;
        FLNames:=TOmfOrderedNameCollection.Create(True);
        FExtDefs:=TFPHashObjectList.Create;
        FPubDefs:=TFPHashObjectList.Create;
        FFixupThreads:=TOmfThreads.Create;
        FRawRecord:=TOmfRawRecord.Create;
        CaseSensitiveSegments:=False;
        CaseSensitiveSymbols:=True;
      end;

    destructor TOmfObjInput.Destroy;
      begin
        FCOMENTRecord.Free;
        FCOMENTRecord := nil;
        FRawRecord.Free;
        FRawRecord := nil;
        FFixupThreads.Free;
        FFixupThreads := nil;
        FPubDefs.Free;
        FPubDefs := nil;
        FExtDefs.Free;
        FExtDefs := nil;
        FLNames.Free;
        FLNames := nil;
        inherited Destroy;
      end;

    class function TOmfObjInput.CanReadObjData(AReader: TObjectReader): boolean;
      var
        b: Byte;
      begin
        result:=false;
        if AReader.Read(b,sizeof(b)) then
          begin
            if b=RT_THEADR then
            { TODO: check additional fields }
              result:=true;
          end;
        AReader.Seek(0);
      end;

    function TOmfObjInput.ReadObjData(AReader: TObjectReader; out objdata: TObjData): boolean;
      begin
        FReader:=AReader;
        InputFileName:=AReader.FileName;
        objdata:=CObjData.Create(InputFileName);
        result:=false;
        { the TOmfObjData constructor creates a group 'DGROUP', which is to be
          used by the code generator, when writing files. When reading object
          files, however, we need to start with an empty list of groups, so
          let's clear the group list now. }
        objdata.GroupsList.Clear;
        LNames.Clear;
        ExtDefs.Clear;
        FRawRecord.ReadFrom(FReader);
        if not FRawRecord.VerifyChecksumByte then
          begin
            InputError('Invalid checksum in OMF record');
            exit;
          end;
        if FRawRecord.RecordType<>RT_THEADR then
          begin
            InputError('Can''t read OMF header');
            exit;
          end;
        repeat
          FRawRecord.ReadFrom(FReader);
          if not FRawRecord.VerifyChecksumByte then
            begin
              InputError('Invalid checksum in OMF record');
              exit;
            end;
          FreeAndNil(FCOMENTRecord);
          case FRawRecord.RecordType of
            RT_LNAMES:
              if not ReadLNames(FRawRecord) then
                exit;
            RT_SEGDEF,RT_SEGDEF32:
              if not ReadSegDef(FRawRecord,objdata) then
                exit;
            RT_GRPDEF:
              if not ReadGrpDef(FRawRecord,objdata) then
                exit;
            RT_COMENT:
              begin
                FCOMENTRecord:=TOMFRecordCOMENT.Create;
                FCOMENTRecord.DecodeFrom(FRawRecord);
                case FCOMENTRecord.CommentClass of
                  CC_OmfExtension:
                    begin
                      if Length(FCOMENTRecord.CommentString)>=1 then
                        begin
                          case Ord(FCOMENTRecord.CommentString[1]) of
                            CC_OmfExtension_IMPDEF:
                              if not ReadImpDef(FCOMENTRecord,objdata) then
                                exit;
                            CC_OmfExtension_EXPDEF:
                              if not ReadExpDef(FCOMENTRecord,objdata) then
                                exit;
                          end;
                        end;
                    end;
                  CC_LIBMOD:
                    begin
                      {todo: do we need to read the module name here?}
                    end;
                  CC_EXESTR:
                    begin
                      InputError('EXESTR record (Executable String Record) is not supported');
                      exit;
                    end;
                  CC_INCERR:
                    begin
                      InputError('Invalid object file (contains indication of error encountered during incremental compilation)');
                      exit;
                    end;
                  CC_NOPAD:
                    begin
                      InputError('NOPAD (No Segment Padding) record is not supported');
                      exit;
                    end;
                  CC_WKEXT:
                    begin
                      InputError('Weak externals are not supported');
                      exit;
                    end;
                  CC_LZEXT:
                    begin
                      InputError('Lazy externals are not supported');
                      exit;
                    end;
                  else
                    begin
                      {the rest are ignored for now...}
                    end;
                end;
              end;
            RT_EXTDEF:
              if not ReadExtDef(FRawRecord,objdata) then
                exit;
            RT_LPUBDEF,RT_LPUBDEF32,
            RT_PUBDEF,RT_PUBDEF32:
              if not ReadPubDef(FRawRecord,objdata) then
                exit;
            RT_LEDATA,RT_LEDATA32,
            RT_LIDATA,RT_LIDATA32,
            RT_FIXUPP,RT_FIXUPP32:
              if not ReadLeOrLiDataAndFixups(FRawRecord,objdata) then
                exit;
            RT_MODEND,RT_MODEND32:
              if not ReadModEnd(FRawRecord,objdata) then
                exit;
            RT_LINNUM,RT_LINNUM32:
              ;
            else
              begin
                InputError('Unsupported OMF record type $'+HexStr(FRawRecord.RecordType,2));
                exit;
              end;
          end;
        until FRawRecord.RecordType in [RT_MODEND,RT_MODEND32];
        result:=true;
      end;

    constructor TOmfAssembler.Create(info: PAsmInfo; smart:boolean);
      begin
        inherited;
        CObjOutput:=TOmfObjOutput;
        CInternalAr:=TOmfLibObjectWriter;
      end;

{*****************************************************************************
                            Procedures and functions
*****************************************************************************}

    function StripDllExt(const DllName:TSymStr):TSymStr;
      begin
        if UpCase(ExtractFileExt(DllName))='.DLL' then
          Result:=Copy(DllName,1,Length(DllName)-4)
        else
          Result:=DllName;
      end;

    function MaybeAddDllExt(const DllName: TSymStr): TSymStr;
      begin
        if ExtractFileExt(DllName)='' then
          Result:=ChangeFileExt(DllName,'.dll')
        else
          Result:=DllName;
      end;

{*****************************************************************************
                                  Initialize
*****************************************************************************}


initialization

end.
