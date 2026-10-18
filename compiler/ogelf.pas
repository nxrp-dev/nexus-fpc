{
    Copyright (c) 1998-2006 by Peter Vreman

    Contains the binary elf writer

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
unit ogelf;

{$i fpcdefs.inc}

interface

    uses
       { common }
       CClasses,GlobType,
       { target }
       Systems,
       { assembler }
       aasmbase,assemble,
       { ELF definitions }
       elfbase,
       { output }
       ogbase,
       owbase;

    type
{$ifdef cpu64bitaddr}
      TElfsechdr = TELF64SecHdr;
{$else cpu64bitaddr}
      TElfsechdr = TELF32SecHdr;
{$endif cpu64bitaddr}

       TElfObjSection = class(TObjSection)
       public
          shstridx,
          shtype,
          shflags,
          shlink,
          shinfo,
          shentsize : LongInt;
          constructor Create(AList:TFPHashObjectList;const Aname:string;Aalign:LongInt;Aoptions:TObjSectionOptions);override;
          constructor create_ext(aobjdata:TObjData;const Aname:string;Ashtype,Ashflags:LongInt;Aalign:LongInt;Aentsize:LongInt);
          constructor create_reloc(aobjdata:TObjData;const Aname:string;allocflag:boolean);
          procedure writeReloc_internal(aTarget:TObjSection;offset:aword;len:byte;reltype:TObjRelocationType);override;
       end;

       TElfSymtab = class(TElfObjSection)
       public
         fstrsec: TObjSection;
         symidx: LongInt;
         constructor Create(aObjData:TObjData);reintroduce;
         procedure writeSymbol(objsym:TObjSymbol;nameidx:LongWord=0);
         procedure writeInternalSymbol(avalue:aword;astridx:LongWord;ainfo:byte;ashndx:word);
       end;

       TElfObjData = class(TObjData)
       public
         ident: TELFIdent;
         flags: LongWord;
         constructor Create(const n:string);override;
         function  sectionname(atype:TAsmSectiontype;const aname:string;aorder:TAsmSectionOrder):string;override;
         procedure writereloc(data:aint;len:aword;p:TObjSymbol;reltype:TObjRelocationType);override;
       end;

       TElfObjectOutput = class(TObjOutput)
       private
         symtabsect: TElfSymtab;
         shstrtabsect: TElfObjSection;
         procedure createrelocsection(s:TElfObjSection;data:TObjData);
         procedure createshstrtab(data:TObjData);
         procedure createsymtab(data: TObjData);
         procedure writesectionheader(s:TElfObjSection);
         procedure section_write_symbol(p:TObject;arg:pointer);
         procedure section_count_sections(p:TObject;arg:pointer);
         procedure section_create_relocsec(p:TObject;arg:pointer);
         procedure section_write_sechdr(p:TObject;arg:pointer);
       protected
         function WriteData(data:TObjData):boolean;override;
       public
         constructor Create(AWriter:TObjectWriter);override;
       end;

       TElfAssembler = class(TInternalAssembler)
         constructor Create(info: PAsmInfo; smart:boolean);override;
       end;

       PSectionRec=^TSectionRec;
       TSectionRec=record
         sec: TObjSection;
         relocpos: aword;
         relocs: LongInt;
         relentsize: LongInt;
       end;

       TElfsecheaderarray=array of TElfsechdr;
       TObjSymbolClass=class of TObjSymbol;

       TElfObjInput=class(TObjInput)
       private
         FSecTbl: PSectionRec;
         FSymTbl: PPointer;
         FLoaded: PBoolean;
         shdrs: TElfsecheaderarray;
         nsects: LongWord;
         shoffset: aword;
         shstrndx: LongWord;
         symtabndx: LongWord;
         shstrtab: TAnsiCharDynArray;
         strtab: TAnsiCharDynArray;
         shstrtablen: LongWord;
         strtablen: LongWord;
         symtaboffset: aword;
         syms: LongWord;
         localsyms: LongWord;
         symversions: TWordDynArray;
         dynobj: boolean;
         CObjSymbol: TObjSymbolClass;
         verdefs: TFPHashObjectList;
         function LoadHeader(out objdata:TObjData):boolean;
         procedure LoadSection(const shdr:TElfsechdr;index:LongInt;objdata:TObjData);
         procedure LoadRelocations(const secrec:TSectionRec);
         procedure LoadSymbols(objdata:TObjData;count,locals:LongWord);
         procedure LoadDynamic(const shdr:TElfsechdr;objdata:TObjData);
       public
         constructor Create;override;
         destructor Destroy;override;
         function  ReadObjData(AReader:TObjectReader;out objdata:TObjData):boolean;override;
         class function CanReadObjData(AReader:TObjectReader):boolean;override;
         function CreateSection(const shdr:TElfsechdr;index:LongInt;objdata:TObjData;
           out secname:string):TElfObjSection;
         function ReadBytes(offs:LongInt;out buf;len:LongInt):boolean;
       end;

       TElfVersionDef = class(TFPHashObject)
       public
         index: LongWord;
       end;

       TElfDynamicObjData = class(TElfObjData)
       private
         FVersionDefs: TFPHashObjectList;
       public
         soname_strofs: LongWord;
         vernaux_count: LongWord;
         constructor Create(const n:string);override;
         destructor Destroy;override;
         property versiondefs:TFPHashObjectList read FVersionDefs;
       end;

       TVersionedObjSymbol = class(TObjSymbol)
       private
         FVersion: TElfVersionDef;
       public
         property version: TElfVersionDef read FVersion write FVersion;
       end;

       TEncodeRelocProc=function(objrel:TObjRelocation):byte;
       TLoadRelocProc=procedure(objrel:TObjRelocation);
       TLoadSectionProc=function(objinput:TElfObjInput;objdata:TObjData;const shdr:TElfsechdr;shindex:LongInt):boolean;
       TEncodeFlagsProc=function:LongWord;
       TElfTarget=record
         machine_code: word;
         relocs_use_addend: boolean;
         encodereloc: TEncodeRelocProc;
         loadreloc: TLoadRelocProc;
         loadsection: TLoadSectionProc;
         encodeflags: TEncodeFlagsProc;
       end;


     var
       ElfTarget: TElfTarget;

implementation

      uses
        SysUtils,
        Verbose,
        export,expunix,
        CUtils,Globals,FModule,owar;

    const
      symbolresize = 200*18;

{$ifdef cpu64bitaddr}
      const
        ELFCLASS = ELFCLASS64;
      type
        TELFHeader = TELF64Header;
        TELFReloc = TELF64Reloc;
        TELFSymbol = TELF64Symbol;
        TELFProgHdr = TELF64ProgHdr;
        TELFDyn = TELF64Dyn;

      function ELF_R_INFO(sym:LongWord;typ:byte):qword;inline;
        begin
          result:=(qword(sym) shl 32) or typ;
        end;

{$else cpu64bitaddr}
      const
        ELFCLASS = ELFCLASS32;
      type
        TELFHeader = TELF32Header;
        TELFReloc = TELF32Reloc;
        TELFSymbol = TELF32Symbol;
        TELFProgHdr = TELF32ProgHdr;
        TELFDyn = TELF32Dyn;

      function ELF_R_INFO(sym:LongWord;typ:byte):LongWord;inline;
        begin
          result:=(sym shl 8) or typ;
        end;
{$endif cpu64bitaddr}


{****************************************************************************
                                Helpers
****************************************************************************}

    procedure encodesechdrflags(aoptions:TObjSectionOptions;out AshType:LongInt;out Ashflags:LongInt);
      begin
        { Section Type }
        if oso_strings in aoptions then
          AshType:=SHT_STRTAB
        else if not(oso_data in aoptions) then
          AshType:=SHT_NOBITS
        else if oso_note in aoptions then
          AshType:=SHT_NOTE
        else if oso_arm_attributes in aoptions then
          AshType:=SHT_ARM_ATTRIBUTES
        else
          AshType:=SHT_PROGBITS;
        { Section Flags }
        Ashflags:=0;
        if oso_load in aoptions then
          Ashflags:=Ashflags or SHF_ALLOC;
        if oso_executable in aoptions then
          Ashflags:=Ashflags or SHF_EXECINSTR;
        if oso_write in aoptions then
          Ashflags:=Ashflags or SHF_WRITE;
        if oso_threadvar in aoptions then
          Ashflags:=Ashflags or SHF_TLS;
      end;


    procedure decodesechdrflags(AshType:LongInt;Ashflags:LongInt;out aoptions:TObjSectionOptions);
      begin
        aoptions:=[];
        { Section Type }
        if AshType<>SHT_NOBITS then
          include(aoptions,oso_data);
        if AshType=SHT_STRTAB then
          include(aoptions,oso_strings);
        { Section Flags }
        if Ashflags and SHF_ALLOC<>0 then
          include(aoptions,oso_load);
        if Ashflags and SHF_WRITE<>0 then
          include(aoptions,oso_write);
        if Ashflags and SHF_EXECINSTR<>0 then
          include(aoptions,oso_executable);
        if Ashflags and SHF_TLS<>0 then
          include(aoptions,oso_threadvar);
      end;


{****************************************************************************
                               TElfObjSection
****************************************************************************}

    constructor TElfObjSection.Create(AList:TFPHashObjectList;const Aname:string;Aalign:LongInt;Aoptions:TObjSectionOptions);
      begin
        inherited Create(AList,Aname,Aalign,aoptions);
        index:=0;
        shstridx:=0;
        encodesechdrflags(aoptions,shtype,shflags);
        shlink:=0;
        shinfo:=0;
      end;


    constructor TElfObjSection.create_ext(aobjdata:TObjData;const Aname:string;Ashtype,Ashflags:LongInt;Aalign:LongInt;Aentsize:LongInt);
      var
        aoptions : TObjSectionOptions;
      begin
        decodesechdrflags(Ashtype,Ashflags,aoptions);
        inherited Create(aobjdata.ObjSectionList,Aname,Aalign,aoptions);
        objdata:=aobjdata;
        index:=0;
        shstridx:=0;
        shtype:=AshType;
        shflags:=AshFlags;
        shentsize:=Aentsize;
      end;


    const
      relsec_prefix:array[boolean] of string[5] = ('.rel','.rela');
      relsec_shtype:array[boolean] of LongWord = (SHT_REL,SHT_RELA);

    constructor TElfObjSection.create_reloc(aobjdata:TObjData;const Aname:string;allocflag:boolean);
      begin
        create_ext(aobjdata,
          relsec_prefix[ElfTarget.relocs_use_addend]+aname,
          relsec_shtype[ElfTarget.relocs_use_addend],
          SHF_ALLOC*ord(allocflag),
          sizeof(PInt),
          (2+ord(ElfTarget.relocs_use_addend))*sizeof(PInt));
      end;


    procedure TElfObjSection.writeReloc_internal(aTarget:TObjSection;offset:aword;len:byte;reltype:TObjRelocationType);
      var
        reloc: TObjRelocation;
      begin
        reloc:=TObjRelocation.CreateSection(Size,aTarget,reltype);
        reloc.Size:=len;
        ObjRelocations.Add(reloc);
        if reltype=RELOC_RELATIVE then
{ ARM does not require this adjustment, other CPUs must be checked }
{$if defined(i386) or defined(x86_64)}
          dec(offset,len)
{$endif i386 or x86_64}
        else if reltype<>RELOC_ABSOLUTE then
          InternalError(2012062401);
        if ElfTarget.relocs_use_addend then
          begin
            reloc.orgsize:=offset;
            offset:=0;
          end;
        write(offset,len);
      end;


{****************************************************************************
                            TElfObjData
****************************************************************************}

    constructor TElfObjData.Create(const n:string);
      begin
        inherited Create(n);
        CObjSection:=TElfObjSection;
      end;


    function TElfObjData.sectionname(atype:TAsmSectiontype;const aname:string;aorder:TAsmSectionOrder):string;
      const
        secnames : array[TAsmSectiontype] of string[length('__DATA, __datacoal_nt,coalesced')] = ('','',
          '.text','.data',
{$if defined(support_rodata)}
          '.rodata',
{$else defined(support_rodata)}
          '.data',
{$endif defined(support_rodata)}
          '.rodata','.bss','.threadvar',
          '.pdata',
          '.text', { darwin stubs }
          '__DATA,__nl_symbol_ptr',
          '__DATA,__la_symbol_ptr',
          '__DATA,__mod_init_func',
          '__DATA,__mod_term_func',
          '.idata$2','.idata$4','.idata$5','.idata$6','.idata$7','.edata',
          '.eh_frame',
          '.debug_frame','.debug_info','.debug_line','.debug_abbrev','.debug_aranges','.debug_ranges','.debug_loc','.debug_loclists',
          '.fpc',
          '.toc',
          '.init',
          '.fini',
          '.objc_class',
          '.objc_meta_class',
          '.objc_cat_cls_meth',
          '.objc_cat_inst_meth',
          '.objc_protocol',
          '.objc_string_object',
          '.objc_cls_meth',
          '.objc_inst_meth',
          '.objc_cls_refs',
          '.objc_message_refs',
          '.objc_symbols',
          '.objc_category',
          '.objc_class_vars',
          '.objc_instance_vars',
          '.objc_module_info',
          '.objc_class_names',
          '.objc_meth_var_types',
          '.objc_meth_var_names',
          '.objc_selector_strs',
          '.objc_protocol_ext',
          '.objc_class_ext',
          '.objc_property',
          '.objc_image_info',
          '.objc_cstring_object',
          '.objc_sel_fixup',
          '__DATA,__objc_data',
          '__DATA,__objc_const',
          '.objc_superrefs',
          '__DATA, __datacoal_nt,coalesced',
          '.objc_classlist',
          '.objc_nlclasslist',
          '.objc_catlist',
          '.obcj_nlcatlist',
          '.objc_protolist',
          '.stack',
          '.heap',
          '.gcc_except_table',
          '.ARM.attributes',
          '.note'
        );
      var
        sep : string[3];
        secname : string;
      begin
        { section type user gives the user full control on the section name }
        if atype=sec_user then
          result:=aname
        else
          begin
            secname:=secnames[atype];
            if (atype=sec_rodata) and (TargetInfo.system=system_x86_64_linux) and
               (tf_supports_packages in TargetInfo.flags) and
               (cs_create_pic in CurrentSettings.ModuleSwitches) then
              secname:='.data.rel.ro';
            if (atype=sec_fpc) and (Copy(aname,1,3)='res') then
              begin
                result:=secname+'.'+aname;
                exit;
              end;

            if atype=sec_threadvar then
              begin
                if (TargetInfo.system in systems_windows) then
                  secname:='.tls'
                else if (TargetInfo.system in systems_linux) then
                  secname:='.tbss';
              end;

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
                result:=secname+sep+aname
              end
            else
              result:=secname;
          end;
      end;


    procedure TElfObjData.writereloc(data:aint;len:aword;p:TObjSymbol;reltype:TObjRelocationType);
      type
        TRelocData = record
          case integer of
          0 : (ba : array[0..sizeof(aint)-1] of byte);
          1 : (b : byte);
          2 : (w : word);
          4 : (d : dword);
          8 : (q : qword);
        end;

      var
        symaddr : aint;
        ba : TRelocData;
        b : byte;
        objreloc: TObjRelocation;
      begin
        if CurrObjSec=nil then
          InternalError(200403292);
        objreloc:=nil;
        if Assigned(p) then
         begin
           { real address of the symbol }
           symaddr:=p.address;
           { Local ObjSymbols can be resolved already or need a section reloc }
           if (p.bind=AB_LOCAL) and
              (reltype in [RELOC_RELATIVE,RELOC_ABSOLUTE{$ifdef x86_64},RELOC_ABSOLUTE32{$endif x86_64}]) then
             begin
               { For a reltype relocation in the same section the
                 value can be calculated }
               if (p.objsection=CurrObjSec) and
                  (reltype=RELOC_RELATIVE) then
                 inc(data,symaddr-len-CurrObjSec.Size)
               else
                 begin
                   objreloc:=TObjRelocation.CreateSection(CurrObjSec.Size,p.objsection,reltype);
                   CurrObjSec.ObjRelocations.Add(objreloc);
                   inc(data,symaddr);
                 end;
             end
           else
             begin
               objreloc:=TObjRelocation.CreateSymbol(CurrObjSec.Size,p,reltype);
               CurrObjSec.ObjRelocations.Add(objreloc);
               { If target is a local label and it isn't handled above,
                 patch its type in order to get it written to symtable.
                 This may happen e.g. when taking address of Pascal label in PIC mode. }
               if (p.bind=AB_LOCAL) and (p.typ=AT_LABEL) then
                 p.typ:=AT_ADDR;
            end;
         end;
        if Assigned(objreloc) then
          begin
            objreloc.Size:=len;
            { RELOC_GOTPCREL, RELOC_REX_GOTPCRELX, RELOC_GOTPCRELX] need special handling
              this is done in x86/aasmcpu unit }
            if reltype in [RELOC_RELATIVE{$ifdef x86},RELOC_PLT32{$endif}
               {$ifdef x86_64}, RELOC_GOTPCREL, RELOC_REX_GOTPCRELX, RELOC_GOTPCRELX,RELOC_TLSGD{$endif}] then
              dec(data,len);
            if ElfTarget.relocs_use_addend then
              begin
                objreloc.orgsize:=aword(data);
                data:=0;
              end;
          end;
        CurrObjSec.write(data,len);
      end;


{****************************************************************************
                            TElfDynamicObjData
****************************************************************************}

    constructor TElfDynamicObjData.Create(const n:string);
      begin
        inherited Create(n);
        FVersionDefs:=TFPHashObjectList.Create(true);
        { Default symversions with indices 0 and 1 }
        TElfVersionDef.Create(FVersionDefs,'*local*');
        TElfVersionDef.Create(FVersionDefs,'*global*');
      end;


    destructor TElfDynamicObjData.Destroy;
      begin
        FVersionDefs.free;
        FVersionDefs := nil;
        inherited Destroy;
      end;


{****************************************************************************
                            TElfSymtab
****************************************************************************}

    const
      symsectypes: array[boolean] of LongWord = (SHT_SYMTAB,SHT_DYNSYM);

    constructor TElfSymtab.Create(aObjData:TObjData);
      begin
        create_ext(aObjData,'.symtab',SHT_SYMTAB,0,sizeof(PInt),sizeof(TELFSymbol));
        fstrsec:=TElfObjSection.create_ext(aObjData,'.strtab',SHT_STRTAB,0,1,0);
        fstrsec.writezeros(1);
        writezeros(sizeof(TELFSymbol));
        symidx:=1;
        shinfo:=1;
      end;

    procedure TElfSymtab.writeInternalSymbol(avalue:aword;astridx:LongWord;ainfo:byte;ashndx:word);
      var
        elfsym:TELFSymbol;
      begin
        fillchar(elfsym,sizeof(elfsym),0);
        elfsym.st_value:=avalue;
        elfsym.st_name:=astridx;
        elfsym.st_info:=ainfo;
        elfsym.st_shndx:=ashndx;
        inc(symidx);
        inc(shinfo);
        write(elfsym,sizeof(elfsym));
      end;

    procedure TElfSymtab.writeSymbol(objsym:TObjSymbol;nameidx:LongWord);
      var
        elfsym:TELFSymbol;
      begin
        fillchar(elfsym,sizeof(elfsym),0);
        if nameidx=0 then
          elfsym.st_name:=fstrsec.WriteStr(objsym.name)
        else
          elfsym.st_name:=nameidx;
        elfsym.st_size:=objsym.Size;
        elfsym.st_value:=objsym.address;

        case objsym.bind of
          AB_LOCAL :
            begin
              elfsym.st_info:=STB_LOCAL shl 4;
              inc(shinfo);
            end;
          AB_COMMON :
            begin
              elfsym.st_value:=Size_2_Align(objsym.Size);
              elfsym.st_info:=STB_GLOBAL shl 4;
              elfsym.st_shndx:=SHN_COMMON;
            end;
          AB_EXTERNAL :
            elfsym.st_info:=STB_GLOBAL shl 4;
          AB_WEAK_EXTERNAL :
            elfsym.st_info:=STB_WEAK shl 4;
          AB_GLOBAL :
            elfsym.st_info:=STB_GLOBAL shl 4;
          AB_PRIVATE_EXTERN :
            begin
              elfsym.st_info:=STB_GLOBAL shl 4;
              SetElfSymbolVisibility(elfsym.st_other,STV_HIDDEN);
            end
        else
          InternalError(2012111801);
        end;
        { External symbols must be NOTYPE in relocatable files except if they are TLS symbols }
        if (objsym.bind<>AB_EXTERNAL) or (objsym.typ=AT_TLS) then
          begin
            case objsym.typ of
              AT_FUNCTION :
                elfsym.st_info:=elfsym.st_info or STT_FUNC;
              AT_DATA,
              AT_METADATA:
                elfsym.st_info:=elfsym.st_info or STT_OBJECT;
              AT_TLS:
                elfsym.st_info:=elfsym.st_info or STT_TLS;
              AT_GNU_IFUNC:
                elfsym.st_info:=elfsym.st_info or STT_GNU_IFUNC;
              { other types are implicitly mapped to STT_NOTYPE }
              else
                ;
            end;
          end;
        if objsym.bind<>AB_COMMON then
          begin
            if Assigned(objsym.objsection) then
              elfsym.st_shndx:=objsym.objsection.Index
            else
              elfsym.st_shndx:=SHN_UNDEF;
            objsym.symidx:=symidx;
          end;
        inc(symidx);
        write(elfsym,sizeof(TELFSymbol));
      end;

{****************************************************************************
                            TElfObjectOutput
****************************************************************************}

    constructor TElfObjectOutput.Create(AWriter:TObjectWriter);
      begin
        inherited Create(AWriter);
        CObjData:=TElfObjData;
      end;


    procedure TElfObjectOutput.createrelocsection(s:TElfObjSection;data:TObjData);
      var
        i    : LongInt;
        rel  : TELFReloc;
        objreloc : TObjRelocation;
        relsym   : LongInt;
        relocsect : TElfObjSection;
      begin
        { create the reloc section }
        relocsect:=TElfObjSection.create_reloc(data,s.name,false);
        relocsect.shlink:=symtabsect.Index;
        relocsect.shinfo:=s.Index;
        { add the relocations }
        for i:=0 to s.Objrelocations.count-1 do
          begin
            objreloc:=TObjRelocation(s.Objrelocations[i]);

            { Symbol }
            if Assigned(objreloc.Symbol) then
              begin
                if objreloc.Symbol.symidx=-1 then
                  begin
                    WriteLn(objreloc.Symbol.Name);
                    InternalError(200603012);
                  end;
                relsym:=objreloc.Symbol.symidx;
              end
            else
              begin
                if objreloc.objsection<>nil then
                  relsym:=objreloc.objsection.secsymidx
                else
                  relsym:=SHN_UNDEF;
              end;

            rel.address:=objreloc.dataoffset;
            rel.info:=ELF_R_INFO(relsym,ElfTarget.encodereloc(objreloc));
{$push}{$r-}
            rel.addend:=objreloc.orgsize;
{$pop}

            { write reloc }
            { ElfXX_Rel is essentially ElfXX_Rela without the addend field. }
            relocsect.write(rel,relocsect.shentsize);
          end;
      end;


    procedure TElfObjectOutput.section_write_symbol(p:TObject;arg:pointer);
      begin
        { Must not write symbols for internal sections like .symtab }
        { TODO: maybe use inclusive list of section types instead }
        if (TElfObjSection(p).shtype in [SHT_SYMTAB,SHT_STRTAB,SHT_REL,SHT_RELA]) then
          exit;
        TObjSection(p).secsymidx:=symtabsect.symidx;
        symtabsect.writeInternalSymbol(0,0,STT_SECTION,TObjSection(p).Index);
      end;


    procedure TElfObjectOutput.createsymtab(data: TObjData);
      var
        i      : LongInt;
        objsym : TObjSymbol;
      begin
        with data do
         begin
           { section symbols }
           ObjSectionList.ForEachCall(@section_write_symbol,nil);
           { First the Local Symbols, this is required by ELF. The localsyms
             count stored in shinfo is used to skip the local symbols
             when traversing the symtab }
           for i:=0 to ObjSymbolList.Count-1 do
             begin
               objsym:=TObjSymbol(ObjSymbolList[i]);
               if (objsym.bind=AB_LOCAL) and (objsym.typ<>AT_LABEL) then
                 symtabsect.WriteSymbol(objsym);
             end;
           { Global Symbols }
           for i:=0 to ObjSymbolList.Count-1 do
             begin
               objsym:=TObjSymbol(ObjSymbolList[i]);
               if (objsym.bind<>AB_LOCAL) then
                 symtabsect.WriteSymbol(objsym);
             end;
           { update the .symtab section header }
           symtabsect.shlink:=symtabsect.fstrsec.Index;
         end;
      end;


    procedure TElfObjectOutput.createshstrtab(data: TObjData);
      var
        i,prefixlen:LongInt;
        objsec,target:TElfObjSection;
      begin
        shstrtabsect.writezeros(1);
        prefixlen:=length('.rel')+ord(ElfTarget.relocs_use_addend);
        for i:=0 to data.ObjSectionList.Count-1 do
          begin
            objsec:=TElfObjSection(data.ObjSectionList[i]);
            { Alias section names into names of corresponding reloc sections,
              this is allowed by ELF specs and saves good half of .shstrtab space. }
            if objsec.shtype=relsec_shtype[ElfTarget.relocs_use_addend] then
              begin
                target:=TElfObjSection(data.ObjSectionList[objsec.shinfo-1]);
                if (target.ObjRelocations.Count=0) or
                   (target.shstridx<prefixlen) then
                  InternalError(2012101204);
                objsec.shstridx:=target.shstridx-prefixlen;
              end
            else
              begin
                if objsec.ObjRelocations.Count<>0 then
                  shstrtabsect.write(relsec_prefix[true][1],prefixlen);
                objsec.shstridx:=shstrtabsect.WriteStr(objsec.name);
              end;
          end;
      end;


    procedure TElfObjectOutput.writesectionheader(s:TElfObjSection);
      var
        sechdr : TElfsechdr;
      begin
        fillchar(sechdr,sizeof(sechdr),0);
        sechdr.sh_name:=s.shstridx;
        sechdr.sh_type:=s.shtype;
        sechdr.sh_flags:=s.shflags;
        sechdr.sh_offset:=s.datapos;
        sechdr.sh_size:=s.Size;
        sechdr.sh_link:=s.shlink;
        sechdr.sh_info:=s.shinfo;
        sechdr.sh_addralign:=s.secalign;
        sechdr.sh_entsize:=s.shentsize;
        writer.write(sechdr,sizeof(sechdr));
      end;


    procedure TElfObjectOutput.section_count_sections(p:TObject;arg:pointer);
      begin
        TElfObjSection(p).Index:=PWord(arg)^;
        inc(PWord(arg)^);
      end;


    procedure TElfObjectOutput.section_create_relocsec(p:TObject;arg:pointer);
      begin
        if (TElfObjSection(p).ObjRelocations.count>0) then
          createrelocsection(TElfObjSection(p),TObjData(arg));
      end;


    procedure TElfObjectOutput.section_write_sechdr(p:TObject;arg:pointer);
      begin
        writesectionheader(TElfObjSection(p));
      end;


    function TElfObjectOutput.WriteData(data:TObjData):boolean;
      var
        header : TELFHeader;
        shoffset,
        datapos   : aword;
        nsections : word;
      begin
        result:=false;
        with data do
         begin
           { default sections }
           symtabsect:=TElfSymtab.Create(data);
           shstrtabsect:=TElfObjSection.create_ext(data,'.shstrtab',SHT_STRTAB,0,1,0);
           { "no executable stack" marker }
           { TODO: used by OpenBSD/NetBSD as well? }
           if (TargetInfo.system in (systems_linux + systems_android)) and
              not(cs_executable_stack in CurrentSettings.ModuleSwitches) then
             TElfObjSection.create_ext(data,'.note.GNU-stack',SHT_PROGBITS,0,1,0);
           { symbol for filename }
           symtabsect.fstrsec.WriteStr(ExtractFileName(CurrentModule.MainSource));
           symtabsect.writeInternalSymbol(0,1,STT_FILE,SHN_ABS);
           { calc amount of sections we have }
           nsections:=1;
           { also create the index in the section header table }
           ObjSectionList.ForEachCall(@section_count_sections,@nsections);
           { create .symtab and .strtab }
           createsymtab(data);
           { Create the relocation sections, this needs valid secidx and symidx }
           ObjSectionList.ForEachCall(@section_create_relocsec,data);
           { recalc nsections to include the reloc sections }
           nsections:=1;
           ObjSectionList.ForEachCall(@section_count_sections,@nsections);
           { create .shstrtab }
           createshstrtab(data);

           { Calculate the filepositions }
           datapos:=$40; { elfheader + alignment }
           { section data }
           layoutsections(datapos);
           { section headers }
           shoffset:=align(datapos,dword(Sizeof(AInt)));
           inc(datapos,(nsections+1)*sizeof(TElfsechdr));

           { Write ELF Header }
           fillchar(header,sizeof(header),0);
           header.e_ident[EI_MAG0]:=ELFMAG0; { = #127'ELF' }
           header.e_ident[EI_MAG1]:=ELFMAG1;
           header.e_ident[EI_MAG2]:=ELFMAG2;
           header.e_ident[EI_MAG3]:=ELFMAG3;
           header.e_ident[EI_CLASS]:=ELFCLASS;
           header.e_ident[EI_DATA]:=ELFDATA2LSB;

           header.e_ident[EI_VERSION]:=1;
           header.e_type:=ET_REL;
           header.e_machine:=ElfTarget.machine_code;
           header.e_version:=1;
           header.e_shoff:=shoffset;
           header.e_shstrndx:=shstrtabsect.Index;

           header.e_shnum:=nsections;
           header.e_ehsize:=sizeof(TELFHeader);
           header.e_shentsize:=sizeof(TElfsechdr);
           if Assigned(ElfTarget.encodeflags) then
             header.e_flags:=ElfTarget.encodeflags();
           writer.write(header,sizeof(header));
           writer.writezeros($40-sizeof(header)); { align }
           { Sections }
           WriteSectionContent(data);

           { Align header }
           Writer.Writezeros(Align(Writer.Size,Sizeof(AInt))-Writer.Size);
           { section headers, start with an empty header for sh_undef }
           writer.writezeros(sizeof(TElfsechdr));
           ObjSectionList.ForEachCall(@section_write_sechdr,nil);
         end;
        result:=true;
      end;


{****************************************************************************
                               TELFAssembler
****************************************************************************}

    constructor TElfAssembler.Create(info: PAsmInfo; smart:boolean);
      begin
        inherited;
        CObjOutput:=TElfObjectOutput;
        CInternalAr:=TArObjectWriter;
      end;


{****************************************************************************
                               TELFObjectInput
****************************************************************************}

    constructor TElfObjInput.Create;
      begin
        inherited Create;
        CObjData:=TElfObjData;
        CObjSymbol:=TObjSymbol;
      end;


    destructor TElfObjInput.Destroy;
      begin
        if Assigned(FSymTbl) then
          FreeMem(FSymTbl);
        if Assigned(FSecTbl) then
          FreeMem(FSecTbl);
        strtab:=nil;
        shstrtab:=nil;
        symversions:=nil;
        inherited Destroy;
      end;


    procedure TElfObjInput.LoadRelocations(const secrec:TSectionRec);
      var
        i: LongInt;
        rel: TELFReloc;
        reltyp: byte;
        relsym: LongInt;
        objrel: TObjRelocation;
        p: TObjSymbol;
      begin
        FReader.Seek(secrec.relocpos);
        if secrec.sec=nil then
          InternalError(2012060203);
        if (secrec.relentsize=3*sizeof(PInt)) then
          with secrec.sec do SecOptions:=SecOptions+[oso_rela_relocs];
        for i:=0 to secrec.relocs-1 do
          begin
            FReader.Read(rel,secrec.relentsize);
            reltyp:=rel.info and $FF;
{$ifdef cpu64bitaddr}
            relsym:=rel.info shr 32;
{$else cpu64bitaddr}
            relsym:=(rel.info shr 8) and $FFFFFF;
{$endif cpu64bitaddr}
            if relsym>=syms then
              InternalError(2012060204);
            p:=TObjSymbol(FSymTbl[relsym]);
            { Some relocations (e.g. R_ARM_V4BX) don't use a symbol at all }
            if Assigned(p) or (relsym=0) then
              begin
                objrel:=TObjRelocation.CreateRaw(rel.address-secrec.sec.mempos,p,reltyp);
                if (secrec.relentsize=3*sizeof(PInt)) then
                  objrel.orgsize:=rel.addend;
                { perform target-specific actions }
                if Assigned(ElfTarget.loadreloc) then
                  ElfTarget.loadreloc(objrel);
                secrec.sec.ObjRelocations.add(objrel);
              end
            else
              begin
                InputError('Unable to resolve symbol of relocation');
                exit;
              end;
          end;
      end;


    procedure TElfObjInput.LoadSymbols(objdata:TObjData;count,locals:LongWord);
      var
        i: LongInt;
        sym: TELFSymbol;
        bind: TAsmsymbind;
        typ: TAsmsymtype;
        objsym: TObjSymbol;
        ver: word;
      begin
        FSymTbl:=AllocMem(count*sizeof(Pointer));
        for i:=1 to count-1 do
          begin
            FReader.Read(sym,sizeof(TELFSymbol));
            if sym.st_name>=strtablen then
              InternalError(2012060205);

            if sym.st_shndx=SHN_ABS then    { ignore absolute symbols (should we really do it???) }
              Continue
            else if sym.st_shndx=SHN_COMMON then
              bind:=AB_COMMON
            else if (sym.st_shndx>=nsects) then
              InternalError(2012060206)
            else
              case (sym.st_info shr 4) of
                STB_LOCAL:
                  bind:=AB_LOCAL;
                STB_GLOBAL:
                  if sym.st_shndx=SHN_UNDEF then
                    bind:=AB_EXTERNAL
                  else if GetElfSymbolVisibility(sym.st_other)=STV_HIDDEN then
                    bind:=AB_PRIVATE_EXTERN
                  else
                    bind:=AB_GLOBAL;
                STB_WEAK:
                  bind:=AB_WEAK_EXTERNAL;
              else
                InternalError(2012060207);
              end;

            { Ignore section symbol if we didn't create the corresponding objsection
              (examples are SHT_GROUP or .note.GNU-stack sections). }
            if (sym.st_shndx>0) and (sym.st_shndx<SHN_LORESERVE) and
              (FSecTbl[sym.st_shndx].sec=nil) and
              (not dynobj) then
              if ((sym.st_info and $0F)=STT_SECTION) then
                Continue
              else
                begin
                  WriteLn(objdata.name,' ',i);
                  InternalError(2012110701)
                end;

            case (sym.st_info and $0F) of
              STT_NOTYPE:
                typ:=AT_NONE;
              STT_OBJECT:
                typ:=AT_DATA;
              STT_FUNC:
                typ:=AT_FUNCTION;
              STT_SECTION:
                typ:=AT_SECTION;
              STT_FILE:
                continue;
              STT_TLS:
                typ:=AT_TLS;
              STT_GNU_IFUNC:
                typ:=AT_GNU_IFUNC;
            else
              WriteLn(objdata.name,' ',sym.st_info and $0F);
              InternalError(2012060208);
            end;
            { If reading DSO, we're interested only in global symbols defined there.
              Symbols with non-current version should also be ignored. }
            ver:=0;
            if dynobj then
              begin
                if Assigned(symversions) then
                  begin
                    ver:=symversions[i];
                    if (ver=VER_NDX_LOCAL) or (ver>VERSYM_VERSION) then
                      continue;
                  end;
                if (bind=AB_LOCAL) or (sym.st_shndx=SHN_UNDEF) then
                  continue;
                if ver>=verdefs.count then
                  InternalError(2012120505);
              end;
            { validity of name and objsection has been checked above }
            { !! all AT_SECTION symbols have duplicate (null) name,
              therefore TObjSection.CreateSymbol cannot be used here }
            objsym:=CObjSymbol.Create(objdata.ObjSymbolList,string(PChar(@strtab[sym.st_name])));
            objsym.bind:=bind;
            objsym.typ:=typ;
            if bind<>AB_COMMON then
              objsym.objsection:=FSecTbl[sym.st_shndx].sec;
            objsym.Offset:=sym.st_value;
            objsym.Size:=sym.st_size;
            FSymTbl[i]:=objsym;
            if (ver>VER_NDX_GLOBAL) then
              TVersionedObjSymbol(objsym).version:=TElfVersionDef(verdefs[ver]);
          end;
      end;


    function TElfObjInput.CreateSection(const shdr:TElfsechdr;index:LongInt;objdata:TObjData;
        out secname:string):TElfObjSection;
      begin
        secname:=string(PChar(@shstrtab[shdr.sh_name]));

        result:=TElfObjSection.create_ext(objdata,secname,
          shdr.sh_type,shdr.sh_flags,shdr.sh_addralign,shdr.sh_entsize);

        result.Index:=index;
        result.DataPos:=shdr.sh_offset;
        result.MemPos:=shdr.sh_addr;
        result.Size:=shdr.sh_size;
        FSecTbl[index].sec:=result;
      end;


    function TElfObjInput.ReadBytes(offs:LongInt;out buf;len:LongInt):boolean;
      begin
        FReader.Seek(offs);
        result:=FReader.Read(buf,len);
      end;


    procedure TElfObjInput.LoadSection(const shdr:TElfsechdr;index:LongInt;objdata:TObjData);
      var
        sec: TElfObjSection;
        sym: TELFSymbol;
        secname: string;
      begin
        if shdr.sh_name>=shstrtablen then
          InternalError(2012060210);

        case shdr.sh_type of
          SHT_NULL:
            {ignore};

          { SHT_STRTAB may appear for .stabstr and other debug sections.
            .shstrtab and .strtab are processed separately and don't appear here. }
          SHT_PROGBITS,SHT_NOBITS,SHT_NOTE,SHT_STRTAB,
          SHT_INIT_ARRAY,SHT_FINI_ARRAY,SHT_PREINIT_ARRAY:
            begin
              sec:=CreateSection(shdr,index,objdata,secname);

              if (Length(secname)>3) and (secname[2] in ['d','f','n','s']) then
                begin
                  if (Pos('.stub',secname)=1) or
                    (Pos('.fpc',secname)=1) then
                    sec.SecOptions:=[oso_keep]
                  { ELF does not have any flags specific to debug sections,
                    but reserves names starting with '.debug' for this purpose }
                  else if (Pos('.debug',secname)=1) or
                    (secname='.stab') or
                    (secname='.stabstr') then
                    sec.SecOptions:=[oso_debug]
                  else if (secname='.note.GNU-stack') and (shdr.sh_type=SHT_PROGBITS) then
                    begin
                      if (shdr.sh_flags and SHF_EXECINSTR)=0 then
                        objdata.ExecStack:=False;
                    end;
                end;

              if (shdr.sh_type=SHT_NOTE) and (shdr.sh_size<>0) then
                sec.SecOptions:=[oso_keep];
            end;

          SHT_REL,SHT_RELA:
            begin
              if shdr.sh_info>=nsects then
                InternalError(2012060211);
              if shdr.sh_entsize<>LongWord((2+ord(shdr.sh_type=SHT_RELA))*sizeof(PInt)) then
                InternalError(2012060212);

              with FSecTbl[shdr.sh_info] do
                begin
                  relocpos:=shdr.sh_offset;
                  relocs:=shdr.sh_size div shdr.sh_entsize;
                  relentsize:=shdr.sh_entsize;
                end;
            end;

          SHT_GROUP:
            if (shdr.sh_size>=2*sizeof(LongWord)) and
              (shdr.sh_entsize=sizeof(LongWord)) and
              ((shdr.sh_size mod shdr.sh_entsize)=0) then
              begin
                { Groups are identified by name of symbol pointed to by
                  sh_link and sh_info, not by sh_name. This symbol
                  may as well be STT_SECTION symbol of this section,
                  in which case we end up using sh_name. }
                if dynobj then
                  InternalError(2012110801);
                if (shdr.sh_link<>symtabndx) then
                  InternalError(2012110703);
                if (shdr.sh_info>=syms) then
                  InternalError(2012110704);

                FReader.Seek(symtaboffset+shdr.sh_info*sizeof(TELFSymbol));
                FReader.Read(sym,sizeof(TELFSymbol));
                if sym.st_name>=strtablen then
                  InternalError(2012110705);
                if (sym.st_shndx=index) and (sym.st_info=((STB_LOCAL shl 4) or STT_SECTION)) then
                  secname:=string(PChar(@shstrtab[shdr.sh_name]))
                else
                  secname:=string(PChar(@strtab[sym.st_name]));

                { Postpone further processing until all sections are loaded,
                  we'll need to access correct section header.
                  Since ABI requires SHT_GROUP sections to come first in the file,
                  we assume that group number x has header index x+1.
                  If we ever encounter files where this is not true, we'll have
                  to maintain a separate index. }
                objdata.CreateSectionGroup(secname);
                if (index<>objdata.GroupsList.Count) then
                  InternalError(2012110802);
              end
            else
              InternalError(2012110706);

          SHT_GNU_ATTRIBUTES:
            { TODO: must not be ignored };
        else
          if not (Assigned(ElfTarget.loadsection) and
            ElfTarget.loadsection(self,objdata,shdr,index)) then
            InternalError(2012072603);
        end;
        FLoaded[index]:=True;
      end;


    function TElfObjInput.LoadHeader(out objdata:TObjData):boolean;
      var
        header:TELFHeader;
      begin
        result:=false;
        if not FReader.read(header,sizeof(header)) then
          begin
            InputError('Can''t read ELF header');
            exit;
          end;
        if (header.e_ident[EI_MAG0]<>ELFMAG0) or (header.e_ident[EI_MAG1]<>ELFMAG1) or
           (header.e_ident[EI_MAG2]<>ELFMAG2) or (header.e_ident[EI_MAG3]<>ELFMAG3) then
          begin
            InputError('Illegal ELF magic');
            exit;
          end;
        if (header.e_ident[EI_VERSION]<>1) then
          begin
            InputError('Unknown ELF file version');
            exit;
          end;
        if (header.e_ident[EI_CLASS]<>ELFCLASS) then
          begin
            InputError('Wrong ELF file class (32/64 bit mismatch)');
            exit;
          end;
        if header.e_ident[EI_DATA]<>ELFDATA2LSB then
          begin
            InputError('ELF endianness does not match target');
            exit;
          end;
        if (header.e_version<>1) then
          begin
            InputError('Unknown ELF data version');
            exit;
          end;
        if (header.e_machine<>ElfTarget.machine_code) then
          begin
            InputError('ELF file is for different CPU');
            exit;
          end;
        if (header.e_type<>ET_REL) and (header.e_type<>ET_DYN) then
          begin
            InputError('Not a relocatable or dynamic ELF file');
            exit;
          end;
        if header.e_shentsize<>sizeof(TElfsechdr) then
          InternalError(2012062701);

        nsects:=header.e_shnum;
        dynobj:=(header.e_type=ET_DYN);
        shoffset:=header.e_shoff;
        shstrndx:=header.e_shstrndx;

        if dynobj then
          begin
            objdata:=TElfDynamicObjData.Create(InputFileName);
            verdefs:=TElfDynamicObjData(objdata).versiondefs;
            CObjSymbol:=TVersionedObjSymbol;
          end
        else
          objdata:=CObjData.Create(InputFileName);

        TElfObjData(objdata).ident:=header.e_ident;
        TElfObjData(objdata).flags:=header.e_flags;
        result:=true;
      end;


    procedure TElfObjInput.LoadDynamic(const shdr:TElfsechdr;objdata:TObjData);
      var
        dt: TELFDyn;
        i: LongInt;
      begin
        if (shdr.sh_entsize<>sizeof(TELFDyn)) then
          InternalError(2012071403);

        FReader.Seek(shdr.sh_offset);
        for i:=0 to (shdr.sh_size div shdr.sh_entsize)-1 do
          begin
            FReader.Read(dt,sizeof(TELFDyn));
            case dt.d_tag of
              DT_NULL:
                break;
              DT_SONAME:
                TElfObjData(objdata).FName:=string(PChar(@strtab[dt.d_ptr]));
              DT_NEEDED:
                ;
            end;
          end;
      end;


    function TElfObjInput.ReadObjData(AReader:TObjectReader;out objdata:TObjData):boolean;
      var
        i,j,strndx,dynndx,
        versymndx,verdefndx,verneedndx: LongInt;
        objsec: TObjSection;
        grp: TObjSectionGroup;
        tmp: LongWord;
        count: LongInt;
        vd: TELFVerDef;
        vda: TELFVerDAux;
        vdoffset: aword;
      begin
        FReader:=AReader;
        InputFileName:=AReader.FileName;
        result:=false;
        strndx:=0;

        if not LoadHeader(objData) then
          exit;

        FSecTbl:=AllocMem(nsects*sizeof(TSectionRec));
        FLoaded:=AllocMem(nsects*sizeof(boolean));
        SetLength(shdrs,nsects);

        FReader.Seek(shoffset);
        if not FReader.Read(shdrs[0],nsects*sizeof(TElfsechdr)) then
          begin
            InputError('Can''t read ELF section headers');
            exit;
          end;

        { First, load the .shstrtab section }
        if shstrndx>=nsects then
          InternalError(2012060201);
        if shdrs[shstrndx].sh_type<>SHT_STRTAB then
          InternalError(2012060202);
        shstrtablen:=shdrs[shstrndx].sh_size;
        SetLength(shstrtab,shstrtablen);
        FReader.seek(shdrs[shstrndx].sh_offset);
        FReader.read(shstrtab[0],shstrtablen);
        FLoaded[shstrndx]:=True;

        { Locate the symtable, it is typically at the end so loop backwards.
          Load the strings, postpone symtable itself until done with sections.
          Note that is is legal to have no symtable.
          For DSO, locate .dynsym instead, this one is near the beginning, but
          overall number of sections won't be big. }
        symtabndx:=0;
        for i:=nsects-1 downto 1 do
          begin
            if (shdrs[i].sh_type<>symsectypes[dynobj]) then
              continue;
            if (shdrs[i].sh_entsize<>sizeof(TELFSymbol)) then
              InternalError(2012060213);
            if shdrs[i].sh_link>=nsects then
              InternalError(2012062702);
            strndx:=shdrs[i].sh_link;
            if shdrs[strndx].sh_type<>SHT_STRTAB then
              InternalError(2012062703);
            strtablen:=shdrs[strndx].sh_size;
            SetLength(strtab,strtablen);
            FReader.seek(shdrs[strndx].sh_offset);
            FReader.read(strtab[0],strtablen);

            symtaboffset:=shdrs[i].sh_offset;
            syms:=shdrs[i].sh_size div sizeof(TELFSymbol);
            localsyms:=shdrs[i].sh_info;
            FLoaded[i]:=True;
            FLoaded[strndx]:=True;
            symtabndx:=i;
            break;
          end;

        if dynobj then
          begin
            if symtabndx=0 then
              InternalError(2012110707);
            { Locate .dynamic and version sections. Expect a single one of a kind. }
            dynndx:=0;
            versymndx:=0;
            verdefndx:=0;
            verneedndx:=0;
            for i:=nsects-1 downto 0 do
              begin
                case shdrs[i].sh_type of
                  SHT_DYNAMIC:
                    begin
                      if dynndx<>0 then
                        InternalError(2012102001);
                      dynndx:=i;
                      if (shdrs[dynndx].sh_link<>strndx) then
                        InternalError(2012071402);
                      LoadDynamic(shdrs[dynndx],objdata);
                    end;

                  SHT_GNU_versym:
                    begin
                      if versymndx<>0 then
                        InternalError(2012102002);
                      versymndx:=i;
                      if shdrs[i].sh_entsize<>sizeof(word) then
                        InternalError(2012102003);
                      if shdrs[i].sh_link<>symtabndx then
                        InternalError(2012102004);
                      if shdrs[i].sh_size<>syms*sizeof(word) then
                        InternalError(2012102005);
                      SetLength(symversions,shdrs[i].sh_size);
                      FReader.seek(shdrs[i].sh_offset);
                      FReader.read(symversions[0],shdrs[i].sh_size);
                    end;

                  SHT_GNU_verdef:
                    begin
                      if verdefndx<>0 then
                        InternalError(2012102006);
                      verdefndx:=i;
                      if shdrs[i].sh_link<>strndx then
                        InternalError(2012120501);
                      vdoffset:=shdrs[i].sh_offset;
                      { TODO: can we rely on sh_info, or must read until vd_next=0? }
                      for j:=1 to shdrs[i].sh_info do
                        begin
                          FReader.seek(vdoffset);
                          FReader.Read(vd,sizeof(TELFVerDef));
                          if vd.vd_version<>VER_DEF_CURRENT then
                            InternalError(2012120502);
                          FReader.seek(vdoffset+vd.vd_aux);
                          vdoffset:=vdoffset+vd.vd_next;
                          { First verdaux entry holds name of version (unless VER_FLG_BASE flag is set),
                            subsequent one(s) point to parent(s). For our purposes, version hierarchy
                            looks irrelevant. }
                          FReader.Read(vda,sizeof(TELFVerDAux));
                          if vda.vda_name>=strtablen then
                            InternalError(2012120503);
                          if (vd.vd_flags and VER_FLG_BASE)<>0 then
                            continue;
                          { Assuming verdef indices assigned continuously starting from 2,
                            at least BFD produces files that way. }
                          if verdefs.count<>vd.vd_ndx then
                            InternalError(2012120504);
                          TElfVersionDef.Create(verdefs,string(PChar(@strtab[vda.vda_name])));
                        end;
                    end;

                  SHT_GNU_verneed:
                    begin
                      if verneedndx<>0 then
                        InternalError(2012102007);
                      verneedndx:=i;
                      //sh_link->.dynstr
                      //sh_info->number of entries
                    end;
                end;
             end;

            if dynndx=0 then
              InternalError(2012071401);

            { load the symtable }
            FReader.Seek(symtaboffset+sizeof(TELFSymbol));
            LoadSymbols(objdata,syms,localsyms);

            result:=True;
            exit;
          end;

        { assume stack is executable until proven otherwise }
        objdata.ExecStack:=True;

        { Process section headers }
        for i:=1 to nsects-1 do
          if not FLoaded[i] then
            LoadSection(shdrs[i],i,objdata);

        { load the content }
        ReadSectionContent(objdata);

        { load the symtable }
        FReader.Seek(symtaboffset+sizeof(TELFSymbol));
        LoadSymbols(objdata,syms,localsyms);

        { finish relocations }
        for i:=0 to objdata.ObjSectionList.Count-1 do
          begin
            objsec:=TObjSection(objdata.ObjsectionList[i]);
            { skip debug sections }
            if (oso_debug in objsec.SecOptions) and
               (cs_link_strip in CurrentSettings.GlobalSwitches) and
               not(cs_link_separate_dbg_file in CurrentSettings.GlobalSwitches) then
              continue;

            if FSecTbl[objsec.Index].relocpos>0 then
              LoadRelocations(FSecTbl[objsec.Index]);
          end;

        { finish processing section groups, if any }
        if Assigned(objdata.GroupsList) then
          begin
            for i:=0 to objdata.GroupsList.Count-1 do
              begin
                grp:=TObjSectionGroup(objData.GroupsList[i]);
                FReader.Seek(shdrs[i+1].sh_offset);
                { first dword is flags }
                FReader.Read(tmp,sizeof(LongWord));
                if (tmp and GRP_COMDAT)<>0 then
                  grp.IsComdat:=true;

                count:=(shdrs[i+1].sh_size div sizeof(LongWord))-1;
                SetLength(grp.members,count);
                for j:=0 to count-1 do
                  begin
                    FReader.Read(tmp,sizeof(LongWord));
                    if (tmp>=nsects) then
                      InternalError(2012110805);
                    objsec:=FSecTbl[tmp].sec;
                    if (objsec=nil) then
                      InternalError(2012110806);
                    if (TElfObjSection(objsec).shflags and SHF_GROUP)=0 then
                      InternalError(2012110807);
                    grp.members[j]:=objsec;
                    objsec.Group:=grp;
                  end;
              end;
          end;

        result:=True;
      end;


    class function TElfObjInput.CanReadObjData(AReader:TObjectReader):boolean;
      var
        header: TELFHeader;
      begin
        result:=false;
        if AReader.Read(header,sizeof(header)) then
          begin;
            if (header.e_ident[EI_MAG0]=ELFMAG0) and (header.e_ident[EI_MAG1]=ELFMAG1) and
               (header.e_ident[EI_MAG2]=ELFMAG2) and (header.e_ident[EI_MAG3]=ELFMAG3) then
            { TODO: check additional fields }
              result:=true;
          end;
        AReader.Seek(0);
      end;

end.
