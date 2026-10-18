{
    Copyright (c) 2008 by Jonas Maebe

    Optimization information related to dead code removal

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

unit optdead;

{$i fpcdefs.inc}

  interface

    uses
      GlobType,
      CClasses,
      wpobase;

    type

      { twpodeadcodeinfo }

      TWPODeadCodeInfo = class(TWPODeadCodeHandler)
       private
        { hashtable of symbols which are live }
        fsymbols     : TFPHashList;

        procedure documentformat(writer: TWPOSectionWriterIntf);
       public
        constructor Create; override;
        destructor Destroy; override;

        class function  getwpotype: TWPOType; override;
        class function  generatesinfoforwposwitches: TWPOptimizerSwitches; override;
        class function  performswpoforswitches: TWPOptimizerSwitches; override;
        class function  sectionname: shortstring; override;

        class procedure checkoptions; override;

        { information collection }
        procedure storewpofilesection(writer: TWPOSectionWriterIntf); override;

        { information providing }
        procedure loadfromwpofilesection(reader: TWPOSectionReaderIntf); override;
        function  symbolinfinalbinary(const s: shortstring): boolean;override;

      end;

      { tdeadcodeinfofromexternallinker }

      TWPODeadCodeInfoFromExternalLinker = class(TWPODeadCodeInfo)
       private

        fsymtypepos,
        fsymnamepos  : LongInt;
        fsymfile     : text;
        fsymfilename : TCmdStr;
        aixstrings   : TDynStringArray;
        fuseaixextractstrings : boolean;
        function parselinenm(const line: AnsiString): boolean;
        function parselineobjdump(const line: AnsiString): boolean;
       public
        class procedure checkoptions; override;

        { information collection }
        procedure constructfromcompilerstate; override;
        destructor Destroy; override;
      end;


  implementation

  uses
    CUtils,CFileUtl,
    SysUtils,
    Globals,Systems,FModule,
    Verbose;


  const
    SYMBOL_SECTION_NAME = 'live_symbols';

  { twpodeadcodeinfo }

  constructor TWPODeadCodeInfo.Create;
    begin
      inherited Create;
      fsymbols:=TFPHashList.Create;
    end;


  destructor TWPODeadCodeInfo.Destroy;
    begin
      fsymbols.free;
      fsymbols:=nil;
      inherited Destroy;
    end;


  class function TWPODeadCodeInfo.getwpotype: TWPOType;
    begin
      result:=wpo_live_symbol_information;
    end;


  class function TWPODeadCodeInfo.generatesinfoforwposwitches: TWPOptimizerSwitches;
    begin
      result:=[cs_wpo_symbol_liveness];
    end;


  class function TWPODeadCodeInfo.performswpoforswitches: TWPOptimizerSwitches;
    begin
      result:=[cs_wpo_symbol_liveness];
    end;


  class function TWPODeadCodeInfo.sectionname: shortstring;
    begin
      result:=SYMBOL_SECTION_NAME;
    end;


  class procedure TWPODeadCodeInfo.checkoptions;
    begin
      { we don't have access to the symbol info if the linking
        hasn't happened
      }
      if (([cs_link_on_target,cs_link_nolink] * InitSettings.GlobalSwitches) <> []) then
        begin
          CGMessage(wpo_cannot_extract_live_symbol_info_no_link);
          exit;
        end;

      { without dead code stripping/smart linking, this doesn't make sense }
      if not(cs_link_smart in InitSettings.GlobalSwitches) then
        begin
          CGMessage(wpo_symbol_live_info_needs_smart_linking);
          exit;
        end;
    end;


  procedure TWPODeadCodeInfo.documentformat(writer: TWPOSectionWriterIntf);
    begin
      writer.sectionputline('# section format:');
      writer.sectionputline('# symbol1_that_is_live');
      writer.sectionputline('# symbol2_that_is_live');
      writer.sectionputline('# ...');
      writer.sectionputline('#');
    end;


  procedure TWPODeadCodeInfo.storewpofilesection(writer: TWPOSectionWriterIntf);
    var
      i: LongInt;
    begin
      writer.startsection(SYMBOL_SECTION_NAME);
      documentformat(writer);
      for i:=0 to fsymbols.count-1 do
        writer.sectionputline(fsymbols.nameofindex(i));
    end;


  procedure TWPODeadCodeInfo.loadfromwpofilesection(reader: TWPOSectionReaderIntf);
    var
      symname: shortstring;
    begin
      while reader.sectiongetnextline(symname) do
        fsymbols.add(symname,pointer(1));
    end;


  function TWPODeadCodeInfo.symbolinfinalbinary(const s: shortstring): boolean;
    begin
      result:=fsymbols.find(s)<>nil;
    end;


  { twpodeadcodeinfofromexternallinker }

{$ifdef relaxed_objdump_parsing}
const
  objdumpcheckstr='.text';
{$else}
const
  objdumpcheckstr='F .text';
{$endif}
  objdumpsearchstr=' '+objdumpcheckstr;

  class procedure TWPODeadCodeInfoFromExternalLinker.checkoptions;
    begin
      inherited checkoptions;

      { we need symbol information }
      if (cs_link_strip in InitSettings.GlobalSwitches) then
        begin
          CGMessage(wpo_cannot_extract_live_symbol_info_strip);
          exit;
        end;
    end;


  function TWPODeadCodeInfoFromExternalLinker.parselinenm(const line: AnsiString): boolean;
    begin
      if fuseaixextractstrings then
        begin
          result:=true;
          if ExtractStrings([' ',#9],[],pchar(line),aixstrings)>=2 then
            begin
              if (length(aixstrings[1])=1) and
                 (aixstrings[1][1] in ['t','T']) and
                 (aixstrings[0][1]='.') then
                fsymbols.add(copy(aixstrings[0],2,length(aixstrings[0])),pointer(1));
            end;
          SetLength(aixstrings,0);
        end
      else
        begin
          if (length(line) < fsymnamepos) then
            begin
              CGMessage1(wpo_error_reading_symbol_file,'nm');
              close(fsymfile);
              deletefile(fsymfilename);
              result:=false;
              exit;
            end;
          if line[fsymtypepos] in ['T','t'] then
            fsymbols.add(copy(line,fsymnamepos,length(line)),pointer(1));
        end;
      result:=true;
    end;


  function TWPODeadCodeInfoFromExternalLinker.parselineobjdump(const line: AnsiString): boolean;
    begin
      { there are a couple of empty lines at the end }
      if (line='') then
        begin
          result:=true;
          exit;
        end;
      if (length(line) < fsymtypepos) then
        begin
          CGMessage1(wpo_error_reading_symbol_file,'objdump');
          close(fsymfile);
          deletefile(fsymfilename);
          result:=false;
          exit;
        end;
      if (copy(line,fsymtypepos,length(objdumpcheckstr))=objdumpcheckstr) then
        fsymbols.add(copy(line,fsymnamepos,length(line)),pointer(1));
      result:=true;
    end;


  procedure TWPODeadCodeInfoFromExternalLinker.constructfromcompilerstate;

    type
      TParseLineProc = function(const line: AnsiString): boolean of object;

    var
      nmfullname,
      objdumpfullname,
      symbolprogfullpath  : TCmdStr;
      line                : AnsiString;
      parseline           : TParseLineProc;
      exitcode            : LongInt;
      symbolprogfound     : boolean;
      symbolprogisnm      : boolean;


    function findutil(const utilname: string; out fullutilname, fullutilpath: TCmdStr): boolean;
      begin
        result:=false;
        fullutilname:=UtilsPrefix+changefileext(utilname,SourceInfo.ExeExt);
        if UtilsDirectory<>'' then
          result:=findfile(fullutilname,UtilsDirectory,false,fullutilpath);
        if not result then
          result:=findexe(fullutilname,false,fullutilpath);
      end;


    function failiferror(error: boolean): boolean;
      begin
        result:=error;
        if not result then
          exit;
        CGMessage1(wpo_error_reading_symbol_file,symbolprogfullpath);
{$push}{$i-}
        close(fsymfile);
{$pop}
        if fileexists(fsymfilename) then
          deletefile(fsymfilename);
      end;


    function setnminfo: boolean;
      begin
        { expected format:
            0000bce0 T FPC_ABSTRACTERROR
            ...
        }
        result:=false;
        fsymtypepos:=pos(' ',line)+1;
        fsymnamepos:=fsymtypepos+2;
        if failiferror(fsymtypepos<=0) then
          exit;
        { make sure there's room for the name }
        if failiferror(fsymnamepos>length(line)) then
          exit;
        result:=true;
      end;


    function setobjdumpinfo: boolean;
      begin
        { expected format:
            prog:     file format elf32-i386

            SYMBOL TABLE:
            08048080 l    d  .text  00000000 .text
            00000000 l    d  .stabstr       00000000 .stabstr
            00000000 l    df *ABS*  00000000 nest.pas
            08048160 l     F .text  00000068 SYSTEM_INITSYSCALLINTF
            ...
        }
        result:=false;
        while (pos(objdumpsearchstr,line)<=0) do
          begin
            if failiferror(eof(fsymfile)) then
              exit;
            readln(fsymfile,line)
          end;
        fsymtypepos:=pos(objdumpsearchstr,line)+1;
        { find begin of symbol name }
        fsymnamepos:=(pointer(strrscan(pchar(line),' '))-pointer(@line[1]))+2;
        { sanity check }
        if (fsymnamepos <= fsymtypepos+length(objdumpcheckstr)) then
          exit;
        result:=true;
      end;


    begin { twpodeadcodeinfofromexternallinker }
      objdumpfullname:='';
      fuseaixextractstrings:=false;
      { gnu-nm (e.g., on solaris) }
      symbolprogfound:=findutil('gnm',nmfullname,symbolprogfullpath);
      { regular nm }
      if not symbolprogfound then
        symbolprogfound:=findutil('nm',nmfullname,symbolprogfullpath);
      if not symbolprogfound and
         (TargetInfo.system in systems_linux) then
        begin
          { try objdump }
          symbolprogfound:=findutil('objdump',objdumpfullname,symbolprogfullpath);
          symbolprogfullpath:=symbolprogfullpath+' -t ';
          symbolprogisnm:=false;
        end
      else
        begin
          symbolprogfullpath:=symbolprogfullpath+' -p ';
          { GNU nm shows 64 bit addresses when processing 32 bit binaries on
            a 64 bit platform, but only skips 8 spaces for the address in case
            of undefined symbols -> skip undefined symbols }
          if TargetInfo.system in (systems_linux+systems_windows) then
            symbolprogfullpath:=symbolprogfullpath+'--defined-only ';
          symbolprogisnm:=true;
        end;
      if not symbolprogfound then
        begin
          CGMessage2(wpo_cannot_find_symbol_progs,nmfullname,objdumpfullname);
          exit;
        end;

      { upper case to have the least chance of tripping some long file name
        conversion stuff
      }
      fsymfilename:=OutputExeDir+'FPCWPO.SYM';
      { -p gives the same kind of output with Solaris nm as
        with GNU nm, and for GNU nm it simply means "unsorted"
      }
      exitcode:=shell(symbolprogfullpath+MaybeQuoted(CurrentModule.ExeFileName)+' > '+fsymfilename);
      if (exitcode<>0) then
        begin
          CGMessage2(wpo_error_executing_symbol_prog,symbolprogfullpath,ToStr(exitcode));
          if fileexists(fsymfilename) then
            deletefile(fsymfilename);
          exit;
        end;

      assign(fsymfile,fsymfilename);
{$push}{$i-}
      reset(fsymfile);
{$pop}
      if failiferror((IOResult<>0) or eof(fsymfile)) then
        exit;
      readln(fsymfile, line);
      if (symbolprogisnm) then
        begin
          if not setnminfo then
            exit;
          parseline:=@parselinenm
        end
      else
        begin
          if not setobjdumpinfo then
            exit;
          parseline:=@parselineobjdump;
        end;
      if not parseline(line) then
        exit;
      while not eof(fsymfile) do
        begin
          readln(fsymfile,line);
          if not parseline(line) then
            exit;
        end;
      close(fsymfile);
      deletefile(fsymfilename);
    end;


  destructor TWPODeadCodeInfoFromExternalLinker.Destroy;
    begin
      inherited Destroy;
    end;


end.

