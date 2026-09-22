{
    Copyright (c) 2005-2017 by Free Pascal Compiler team

    This unit implements support import, export, link routines
    for the FreeRTOS Target

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
unit t_freertos;

{$i fpcdefs.inc}

interface


implementation

    uses
       SysUtils,
       cutils,cfileutl,cclasses,
       globtype,globals,systems,verbose,comphook,cscript,fmodule,i_freertos,link,
       cpuinfo;

    type
       TlinkerFreeRTOS=class(texternallinker)
       private
          Function  WriteResponseFile: Boolean;
{$ifdef RISCV32}
          procedure GenerateDefaultLinkerScripts(var memory_filename,sections_filename: AnsiString);
{$endif RISCV32}
       public
          constructor Create; override;
          procedure SetDefaultInfo; override;
          function  MakeExecutable:boolean; override;
          function postprocessexecutable(const fn : string;isdll:boolean):boolean;
       end;


{*****************************************************************************
                                  TlinkerEmbedded
*****************************************************************************}

constructor TlinkerFreeRTOS.Create;
begin
  Inherited Create;
  SharedLibFiles.doubles:=true;
  StaticLibFiles.doubles:=true;
end;


procedure TlinkerFreeRTOS.SetDefaultInfo;
const
{$ifdef mips}
  {$ifdef mipsel}
    platform_select='-EL';
  {$else}
    platform_select='-EB';
  {$endif}
{$else}
  platform_select='';
{$endif}
var
  platformopt : string;
begin
  platformopt:='';
  Info.ExeCmd[1]:='ld -g '+platform_select+platformopt+' $OPT $DYNLINK $STATIC $GCSECTIONS $STRIP $MAP -L. -o $EXE -T $RES';
end;

function TlinkerFreeRTOS.WriteResponseFile: Boolean;
Var
  linkres  : TLinkRes;
  i        : longint;
  HPath    : TCmdStrListItem;
  s,s1,s2  : TCmdStr;
  prtobj   : string[80];
  linklibc : boolean;
  found1,
  found2   : boolean;
{$if defined(ARM)}
  LinkStr  : string;
{$endif}
begin
  WriteResponseFile:=False;
  linklibc:=(SharedLibFiles.Find('c')<>nil);
{$if defined(ARM) or defined(i386) or defined(x86_64) or defined(MIPSEL) or defined(RISCV32)}
  prtobj:='';
{$else}
  prtobj:='prt0';
  if linklibc then
    prtobj:='cprt0';
{$endif}

  { Open link.res file }
  LinkRes:=TLinkRes.Create(outputexedir+Info.ResName,true);

  { Write path to search libraries }
  HPath:=TCmdStrListItem(current_module.locallibrarysearchpath.First);
  while assigned(HPath) do
   begin
    s:=HPath.Str;
    if (cs_link_on_target in current_settings.globalswitches) then
     s:=ScriptFixFileName(s);
    LinkRes.Add('-L'+s);
    HPath:=TCmdStrListItem(HPath.Next);
   end;
  HPath:=TCmdStrListItem(LibrarySearchPath.First);
  while assigned(HPath) do
   begin
    s:=HPath.Str;
    if s<>'' then
     LinkRes.Add('SEARCH_DIR("'+s+'")');
    HPath:=TCmdStrListItem(HPath.Next);
   end;

  LinkRes.Add('INPUT (');
  { add objectfiles, start with prt0 always }
  //s:=FindObjectFile('prt0','',false);
  if prtobj<>'' then
    begin
      s:=FindObjectFile(prtobj,'',false);
      LinkRes.AddFileName(s);
    end;

      { try to add crti and crtbegin if linking to C }
      if linklibc then
       begin
         if librarysearchpath.FindFile('crtbegin.o',false,s) then
          LinkRes.AddFileName(s);
         if librarysearchpath.FindFile('crti.o',false,s) then
          LinkRes.AddFileName(s);
       end;

  while not ObjectFiles.Empty do
   begin
    s:=ObjectFiles.GetFirst;
    if s<>'' then
     begin
      { vlink doesn't use SEARCH_DIR for object files }
      if not(cs_link_on_target in current_settings.globalswitches) then
       s:=FindObjectFile(s,'',false);
      if (idf_version>=50200) then
        LinkRes.AddFileName(ExtractFileName(maybequoted(s)))
      else
        LinkRes.AddFileName((maybequoted(s)));
     end;
   end;

  { Write staticlibraries }
  if not(StaticLibFiles.Empty) then
    begin
      LinkRes.Add(')');
      LinkRes.Add('GROUP(');
      while not StaticLibFiles.Empty do
        begin
          S:=StaticLibFiles.GetFirst;
          if (idf_version>=50200) then
            LinkRes.AddFileName(ExtractFileName(maybequoted(s)))
          else
            LinkRes.AddFileName((maybequoted(s)));
        end;
    end;

     { Write sharedlibraries like -l<lib>, also add the needed dynamic linker
       here to be sure that it gets linked this is needed for glibc2 systems (PFV) }
     linklibc:=false;
     while not SharedLibFiles.Empty do
      begin
       S:=SharedLibFiles.GetFirst;
       if s<>'c' then
        begin
         i:=Pos(target_info.sharedlibext,S);
         if i>0 then
          Delete(S,i,255);
         LinkRes.Add('-l'+s);
        end
       else
        begin
         LinkRes.Add('-l'+s);
         linklibc:=true;
        end;
      end;
     { be sure that libc&libgcc is the last lib }
     if linklibc then
      begin
       LinkRes.Add('-lc');
       LinkRes.Add('-lgcc');
      end;

  LinkRes.Add(')');

      { objects which must be at the end }
      if linklibc then
       begin
         found1:=librarysearchpath.FindFile('crtend.o',false,s1);
         found2:=librarysearchpath.FindFile('crtn.o',false,s2);
         if found1 or found2 then
          begin
            LinkRes.Add('INPUT(');
            if found1 then
             LinkRes.AddFileName(s1);
            if found2 then
             LinkRes.AddFileName(s2);
            LinkRes.Add(')');
          end;
       end;

{$ifdef ARM}
  with embedded_controllers[current_settings.controllertype] do
    with linkres do
      begin
        Add('ENTRY(_START)');
        Add('MEMORY');
        Add('{');
        if flashsize<>0 then
          begin
            LinkStr := '    flash : ORIGIN = 0x' + IntToHex(flashbase,8)
              + ', LENGTH = 0x' + IntToHex(flashsize,8);
            Add(LinkStr);
          end;

        LinkStr := '    ram : ORIGIN = 0x' + IntToHex(srambase,8)
          + ', LENGTH = 0x' + IntToHex(sramsize,8);
        Add(LinkStr);

        Add('}');
        Add('_stack_top = 0x' + IntToHex(sramsize+srambase,8) + ';');
        Add('SECTIONS');
        Add('{');
        Add('    .text :');
        Add('    {');
        Add('    _text_start = .;');
        Add('    KEEP(*(.init .init.*))');
        Add('    *(.text .text.*)');
        Add('    *(.strings)');
        Add('    *(.rodata .rodata.*)');
        Add('    *(.comment)');
        Add('    . = ALIGN(4);');
        Add('    _etext = .;');
        if flashsize<>0 then
          begin
            Add('    } >flash');
            Add('    .note.gnu.build-id : { *(.note.gnu.build-id) } >flash ');
          end
        else
          begin
            Add('    } >ram');
            Add('    .note.gnu.build-id : { *(.note.gnu.build-id) } >ram ');
          end;

        Add('    .data :');
        Add('    {');
        Add('    _data = .;');
        Add('    *(.data .data.*)');
        Add('    KEEP (*(.fpc .fpc.n_version .fpc.n_links))');
        Add('    _edata = .;');
      if flashsize<>0 then
        begin
          Add('    } >ram AT >flash');
        end
      else
        begin
          Add('    } >ram');
        end;
      Add('    .bss :');
      Add('    {');
      Add('    _bss_start = .;');
      Add('    *(.bss .bss.*)');
      Add('    *(COMMON)');
      Add('    } >ram');
      Add('    . = ALIGN(4);');
      Add('    _bss_end = . ;');
      Add('}');
      Add('_end = .;');
    end;
{$endif ARM}

{$ifdef i386}
  with linkres do
    begin
      Add('ENTRY(_START)');
      Add('SECTIONS');
      Add('{');
      Add('     . = 0x100000;');
      Add('     .text ALIGN (0x1000) :');
      Add('    {');
      Add('    _text = .;');
      Add('    KEEP(*(.init .init.*))');
      Add('    *(.text .text.*)');
      Add('    *(.strings)');
      Add('    *(.rodata .rodata.*)');
      Add('    *(.comment)');
      Add('    _etext = .;');
      Add('    }');
      Add('    .data ALIGN (0x1000) :');
      Add('    {');
      Add('    _data = .;');
      Add('    *(.data .data.*)');
      Add('    KEEP (*(.fpc .fpc.n_version .fpc.n_links))');
      Add('    _edata = .;');
      Add('    }');
      Add('    . = ALIGN(4);');
      Add('    .bss :');
      Add('    {');
      Add('    _bss_start = .;');
      Add('    *(.bss .bss.*)');
      Add('    *(COMMON)');
      Add('    }');
      Add('_bss_end = . ;');
      Add('}');
      Add('_end = .;');
    end;
{$endif i386}

{$ifdef x86_64}
  with linkres do
    begin
      Add('ENTRY(_START)');
      Add('SECTIONS');
      Add('{');
      Add('     . = 0x100000;');
      Add('     .text ALIGN (0x1000) :');
      Add('    {');
      Add('    _text = .;');
      Add('    KEEP(*(.init .init.*))');
      Add('    *(.text .text.*)');
      Add('    *(.strings)');
      Add('    *(.rodata .rodata.*)');
      Add('    *(.comment)');
      Add('    _etext = .;');
      Add('    }');
      Add('    .data ALIGN (0x1000) :');
      Add('    {');
      Add('    _data = .;');
      Add('    *(.data .data.*)');
      Add('    KEEP (*(.fpc .fpc.n_version .fpc.n_links))');
      Add('    _edata = .;');
      Add('    }');
      Add('    . = ALIGN(4);');
      Add('    .bss :');
      Add('    {');
      Add('    _bss_start = .;');
      Add('    *(.bss .bss.*)');
      Add('    *(COMMON)');
      Add('    }');
      Add('_bss_end = . ;');
      Add('}');
      Add('_end = .;');
    end;
{$endif x86_64}


{$ifdef MIPSEL}
  case current_settings.controllertype of
      ct_none:
           begin
           end;
      ct_pic32mx110f016b,
      ct_pic32mx110f016c,
      ct_pic32mx110f016d,
      ct_pic32mx120f032b,
      ct_pic32mx120f032c,
      ct_pic32mx120f032d,
      ct_pic32mx130f064b,
      ct_pic32mx130f064c,
      ct_pic32mx130f064d,
      ct_pic32mx150f128b,
      ct_pic32mx150f128c,
      ct_pic32mx150f128d,
      ct_pic32mx210f016b,
      ct_pic32mx210f016c,
      ct_pic32mx210f016d,
      ct_pic32mx220f032b,
      ct_pic32mx220f032c,
      ct_pic32mx220f032d,
      ct_pic32mx230f064b,
      ct_pic32mx230f064c,
      ct_pic32mx230f064d,
      ct_pic32mx250f128b,
      ct_pic32mx250f128c,
      ct_pic32mx250f128d,
      ct_pic32mx775f256h,
      ct_pic32mx775f256l,
      ct_pic32mx775f512h,
      ct_pic32mx775f512l,
      ct_pic32mx795f512h,
      ct_pic32mx795f512l:
        begin
         with embedded_controllers[current_settings.controllertype] do
          with linkres do
            begin
              Add('OUTPUT_FORMAT("elf32-tradlittlemips")');
              Add('OUTPUT_ARCH(pic32mx)');
              Add('ENTRY(_reset)');
              Add('PROVIDE(_vector_spacing = 0x00000001);');
              Add('_ebase_address = 0x'+IntToHex(flashbase,8)+';');
              Add('_RESET_ADDR              = 0xBFC00000;');
              Add('_BEV_EXCPT_ADDR          = 0xBFC00380;');
              Add('_DBG_EXCPT_ADDR          = 0xBFC00480;');
              Add('_GEN_EXCPT_ADDR          = _ebase_address + 0x180;');
              Add('MEMORY');
              Add('{');
              if flashsize<>0 then
                begin
                  Add('  kseg0_program_mem          : ORIGIN = 0x'+IntToHex(flashbase,8)+', LENGTH = 0x'+IntToHex(flashsize,8));
                  //TODO This should better be placed into the controllertype records
                  Add('  kseg1_boot_mem             : ORIGIN = 0xBFC00000, LENGTH = 0xbef');
                  Add('  config3                    : ORIGIN = 0xBFC00BF0, LENGTH = 0x4');
                  Add('  config2                    : ORIGIN = 0xBFC00BF4, LENGTH = 0x4');
                  Add('  config1                    : ORIGIN = 0xBFC00BF8, LENGTH = 0x4');
                  Add('  config0                    : ORIGIN = 0xBFC00BFC, LENGTH = 0x4');
                end;

              Add('  ram                        : ORIGIN = 0x' + IntToHex(srambase,8)
              	+ ', LENGTH = 0x' + IntToHex(sramsize,8));

              Add('}');
              Add('_stack_top = 0x' + IntToHex(sramsize+srambase,8) + ';');
            end;
        end
  end;

  with linkres do
    begin
      Add('SECTIONS');
      Add('{');
      Add('    .reset _RESET_ADDR :');
      Add('    {');
      Add('      KEEP(*(.reset .reset.*))');
      Add('      KEEP(*(.startup .startup.*))');
      Add('    } > kseg1_boot_mem');
      Add('    .bev_excpt _BEV_EXCPT_ADDR :');
      Add('    {');
      Add('      KEEP(*(.bev_handler))');
      Add('    } > kseg1_boot_mem');

      Add('    .text :');
      Add('    {');
      Add('    _text_start = .;');
      Add('    . = _text_start + 0x180;');
      Add('    KEEP(*(.gen_handler))');
      Add('    . = _text_start + 0x200;');
      Add('    KEEP(*(.init .init.*))');
      Add('    *(.text .text.*)');
      Add('    *(.strings)');
      Add('    *(.rodata .rodata.*)');
      Add('    *(.comment)');
      Add('    _etext = .;');
      if embedded_controllers[current_settings.controllertype].flashsize<>0 then
        begin
          Add('    } >kseg0_program_mem');
        end
      else
        begin
          Add('    } >ram');
        end;
      Add('    .note.gnu.build-id : { *(.note.gnu.build-id) }');

      Add('    .data :');
      Add('    {');
      Add('    _data = .;');
      Add('    *(.data .data.*)');
      Add('    KEEP (*(.fpc .fpc.n_version .fpc.n_links))');
      Add('    . = .;');
      Add('    _gp = ALIGN(16) + 0x7ff0;');
      Add('    _edata = .;');
      if embedded_controllers[current_settings.controllertype].flashsize<>0 then
        begin
          Add('    } >ram AT >kseg0_program_mem');
        end
      else
        begin
          Add('    } >ram');
        end;
      Add('  .config_BFC00BF0 : {');
      Add('    KEEP(*(.config_BFC00BF0))');
      Add('  } > config3');
      Add('  .config_BFC00BF4 : {');
      Add('    KEEP(*(.config_BFC00BF4))');
      Add('  } > config2');
      Add('  .config_BFC00BF8 : {');
      Add('    KEEP(*(.config_BFC00BF8))');
      Add('  } > config1');
      Add('  .config_BFC00BFC : {');
      Add('    KEEP(*(.config_BFC00BFC))');
      Add('  } > config0');
      Add('    .bss :');
      Add('    {');
      Add('    _bss_start = .;');
      Add('    *(.bss .bss.*)');
      Add('    *(COMMON)');
      Add('    } >ram');
      Add('. = ALIGN(4);');
      Add('_bss_end = . ;');
      Add('  .comment       0 : { *(.comment) }');
      Add('  /* DWARF debug sections.');
      Add('     Symbols in the DWARF debugging sections are relative to the beginning');
      Add('     of the section so we begin them at 0.  */');
      Add('  /* DWARF 1 */');
      Add('  .debug          0 : { *(.debug) }');
      Add('  .line           0 : { *(.line) }');
      Add('  /* GNU DWARF 1 extensions */');
      Add('  .debug_srcinfo  0 : { *(.debug_srcinfo) }');
      Add('  .debug_sfnames  0 : { *(.debug_sfnames) }');
      Add('  /* DWARF 1.1 and DWARF 2 */');
      Add('  .debug_aranges  0 : { *(.debug_aranges) }');
      Add('  .debug_pubnames 0 : { *(.debug_pubnames) }');
      Add('  /* DWARF 2 */');
      Add('  .debug_info     0 : { *(.debug_info .gnu.linkonce.wi.*) }');
      Add('  .debug_abbrev   0 : { *(.debug_abbrev) }');
      Add('  /DISCARD/         : { *(.debug_line) }');
      Add('  .debug_frame    0 : { *(.debug_frame) }');
      Add('  .debug_str      0 : { *(.debug_str) }');
      Add('  /DISCARD/         : { *(.debug_loc) }');
      Add('  .debug_macinfo  0 : { *(.debug_macinfo) }');
      Add('  /* SGI/MIPS DWARF 2 extensions */');
      Add('  .debug_weaknames 0 : { *(.debug_weaknames) }');
      Add('  .debug_funcnames 0 : { *(.debug_funcnames) }');
      Add('  .debug_typenames 0 : { *(.debug_typenames) }');
      Add('  .debug_varnames  0 : { *(.debug_varnames) }');
      Add('  /* DWARF 3 */');
      Add('  .debug_pubtypes 0 : { *(.debug_pubtypes) }');
      Add('  .debug_ranges   0 : { *(.debug_ranges) }');
      Add('  .gnu.attributes 0 : { KEEP (*(.gnu.attributes)) }');
      Add('  .gptab.sdata : { *(.gptab.data) *(.gptab.sdata) }');
      Add('  .gptab.sbss : { *(.gptab.bss) *(.gptab.sbss) }');
      Add('  .mdebug.abi32 : { KEEP(*(.mdebug.abi32)) }');
      Add('  .mdebug.abiN32 : { KEEP(*(.mdebug.abiN32)) }');
      Add('  .mdebug.abi64 : { KEEP(*(.mdebug.abi64)) }');
      Add('  .mdebug.abiO64 : { KEEP(*(.mdebug.abiO64)) }');
      Add('  .mdebug.eabi32 : { KEEP(*(.mdebug.eabi32)) }');
      Add('  .mdebug.eabi64 : { KEEP(*(.mdebug.eabi64)) }');
      Add('  /DISCARD/ : { *(.rel.dyn) }');
      Add('  /DISCARD/ : { *(.note.GNU-stack) *(.gnu_debuglink) *(.gnu.lto_*) }');
      Add('}');
      Add('_end = .;');
    end;
{$endif MIPSEL}

{$ifdef RISCV32}
  with linkres do
    begin
      Add('SECTIONS');
      Add('{');
      Add('  .data :');
      Add('  {');
      Add('    KEEP (*(.fpc .fpc.n_version .fpc.n_links))');
      Add('  }');
      Add('}');
    end;
{$endif RISCV32}

  { Write and Close response }
  linkres.writetodisk;
  linkres.free;

  WriteResponseFile:=True;

end;


{$ifdef RISCV32}
{ If espX.project.ld or espX_out.ld scripts cannot be located, generate
  default scripts so that linking can proceed.  Note: the generated
  scripts may not match the actual options chosen when the libraries
  were built. }
procedure TlinkerFreeRTOS.GenerateDefaultLinkerScripts(var memory_filename,
  sections_filename: AnsiString);
type
  Tesp_idf_index=(esp32c3_v5_0=0);
const
  esp_fragment_list: array[esp32c3_v5_0..esp32c3_v5_0] of array of string=(
    ('riscv/linker',
     'esp_ringbuf/linker',
     'driver/linker',
     'esp_pm/linker',
     'esp_mm/linker',
     'spi_flash/linker',
     'esp_system/linker',
     'esp_system/app',
     'esp_rom/linker',
     'hal/linker',
     'log/linker',
     'heap/linker',
     'soc/linker',
     'esp_hw_support/linker',
     'freertos/linker',
     'freertos/linker_common',
     'newlib/newlib',
     'newlib/system_libs',
     'esp_common/common',
     'esp_common/soc',
     'app_trace/linker',
     'esp_event/linker',
     'esp_phy/linker',
     'lwip/linker',
     'esp_netif/linker',
     'esp_wifi/linker',
     'bt/linker',
     'esp_adc/linker',
     'esp_gdbstub/linker',
     'esp_lcd/linker',
     'esp_psram/linker',
     'espcoredump/linker'));

var
  S: Ansistring;
  t: Text;
  hp: TCmdStrListItem;
  filepath: TCmdStr = '';
  i,j: integer;
  idf_index: Tesp_idf_index;
  lib,
  binstr,
  cmdstr: AnsiString;
  success: boolean;
begin
  { generate a sdkconfig.h if none is provided,
    only a few fields are provided to far.
    Assume that if linker scripts are not located,
    sdkconfig.h is also missing }
  Assign(t,outputexedir+'/sdkconfig.h');
  {$push}{$I-}
  Rewrite(t);
  if ioresult<>0 then
    exit;

  if (current_settings.controllertype = ct_esp32c3) then
    begin
      writeln(t,'#pragma once');
      writeln(t,'#define CONFIG_APP_BUILD_USE_FLASH_SECTIONS 1');
    end;

  Close(t);
  if ioresult<>0 then
    exit;
  {$pop}

  { generate an sdkconfig if none is provided,
    this is a dummy so far }
  if not(Sysutils.FileExists(outputexedir+'/sdkconfig')) then
    begin
      Assign(t,outputexedir+'/sdkconfig');
      {$push}{$I-}
      Rewrite(t);
      if ioresult<>0 then
        exit;

      writeln(t);

      Close(t);
      if ioresult<>0 then
        exit;
      {$pop}
    end;

  { generate an Kconfig if none is provided,
    this is a dummy so far }
  if not(Sysutils.FileExists(outputexedir+'/Kconfig')) then
    begin
      Assign(t,outputexedir+'/Kconfig');
      {$push}{$I-}
      Rewrite(t);
      if ioresult<>0 then
        exit;

      writeln(t);

      Close(t);
      if ioresult<>0 then
        exit;
      {$pop}
    end;

  { generate an Kconfig.projbuild if none is provided,
    this is a dummy so far }
  if not(Sysutils.FileExists(outputexedir+'/Kconfig.projbuild')) then
    begin
      Assign(t,outputexedir+'/Kconfig.projbuild');
      {$push}{$I-}
      Rewrite(t);
      if ioresult<>0 then
        exit;

      writeln(t);

      Close(t);
      if ioresult<>0 then
        exit;
      {$pop}
    end;

  { generate an kconfigs.in if none is provided,
    this is a dummy so far }
  if not(Sysutils.FileExists(outputexedir+'/kconfigs.in')) then
    begin
      Assign(t,outputexedir+'/kconfigs.in');
      {$push}{$I-}
      Rewrite(t);
      if ioresult<>0 then
        exit;

      writeln(t);

      Close(t);
      if ioresult<>0 then
        exit;
      {$pop}
    end;

  { generate an kconfigs_projbuild.in if none is provided,
    this is a dummy so far }
  if not(Sysutils.FileExists(outputexedir+'/kconfigs_projbuild.in')) then
    begin
      Assign(t,outputexedir+'/kconfigs_projbuild.in');
      {$push}{$I-}
      Rewrite(t);
      if ioresult<>0 then
        exit;

      writeln(t);

      Close(t);
      if ioresult<>0 then
        exit;
      {$pop}
    end;

  { generate a config.env if none is provided,
    COMPONENT_KCONFIGS and COMPONENT_KCONFIGS_PROJBUILD are dummy fields and might
    be needed to be filed properly }
  Assign(t,outputexedir+'/config.env');
  {$push}{$I-}
  Rewrite(t);
  if ioresult<>0 then
    exit;

  writeln(t,'{');
  if (current_settings.controllertype = ct_esp32c3) then
    begin
      writeln(t,'    "COMPONENT_KCONFIGS": "Kconfig",');
      writeln(t,'    "COMPONENT_KCONFIGS_PROJBUILD": "Kconfig.projbuild",');
      writeln(t,'    "IDF_CMAKE": "y",');
      writeln(t,'    "IDF_TARGET": "esp32c3",');
      writeln(t,'    "IDF_ENV_FPGA": "",');
      writeln(t,'    "IDF_PATH": "'+TargetFixPath(idfpath,false)+'",');
      writeln(t,'    "COMPONENT_KCONFIGS_SOURCE_FILE": "'+outputexedir+'/kconfigs.in",');
      writeln(t,'    "COMPONENT_KCONFIGS_PROJBUILD_SOURCE_FILE": "'+outputexedir+'/kconfigs_projbuild.in"');
    end;
  writeln(t,'}');

  Close(t);
  if ioresult<>0 then
    exit;
  {$pop}

  { generate ldgen_libraries }
  Assign(t,outputexedir+'/ldgen_libraries');
  {$push}{$I-}
  Rewrite(t);
  if ioresult<>0 then
    exit;

  { extract libraries from linker options and add to static libraries list }
  Info.ExtraOptions:=trim(Info.ExtraOptions);
  i := pos('-l', Info.ExtraOptions);
  while i > 0 do
   begin
     j:=pos(' ',Info.ExtraOptions);
     if j=0 then
       j:=length(Info.ExtraOptions)+1;
     lib:=copy(Info.ExtraOptions,i+2,j-i-2);
     AddStaticCLibrary(lib);
     delete(Info.ExtraOptions,i,j);
     trim(Info.ExtraOptions);
     i := pos('-l', Info.ExtraOptions);
   end;
  hp:=TCmdStrListItem(StaticLibFiles.First);
  while assigned(hp) do
    begin
      FindLibraryFile(hp.Str,target_info.staticClibprefix,target_info.staticClibext,filepath);
      writeln(t,filepath);
      hp:=TCmdStrListItem(hp.Next);
    end;

  Close(t);
  if ioresult<>0 then
    exit;
  {$pop}

  memory_filename:=IncludeTrailingPathDelimiter(outputexedir)+memory_filename;
  cmdstr:='-C -P -x c -E -o '+memory_filename+' -I $OUTPUT ';
  binstr:='gcc';
  if current_settings.controllertype = ct_none then
    Message(exec_f_controllertype_expected)
  else if current_settings.controllertype = ct_esp32c3 then
    begin
      if idf_version>=40400 then
        cmdstr:=cmdstr+'-I $IDF_PATH/components/esp_system/ld $IDF_PATH/components/esp_system/ld/esp32c3/memory.ld.in'
      else
        cmdstr:=cmdstr+'$IDF_PATH/components/esp32c3/ld/esp32c3.ld';
    end;
  Replace(cmdstr,'$IDF_PATH',idfpath);
  Replace(cmdstr,'$OUTPUT',outputexedir);
  success:=DoExec(FindUtil(utilsprefix+binstr),cmdstr,true,true);

  { generate linker maps }
{$ifdef UNIX}
  binstr:=TargetFixPath(idfpath,false)+'/tools/ldgen/ldgen.py';
{$else}
  binstr:='python';
{$endif UNIX}
  if source_info.exeext<>'' then
    binstr:=binstr+source_info.exeext;

  sections_filename:=IncludeTrailingPathDelimiter(outputexedir)+sections_filename;

  cmdstr:={$ifndef UNIX}'$IDF_PATH/tools/ldgen/ldgen.py '+{$endif UNIX}
          '--config $OUTPUT/sdkconfig --fragments';

  { Pick corresponding linker fragments list for SDK version }
  idf_index:=esp32c3_v5_0;

  for S in esp_fragment_list[idf_index] do
    cmdstr:=cmdstr+' $IDF_PATH/components/'+S+'.lf';

  if (current_settings.controllertype = ct_esp32c3) then
    begin
     if idf_version>=40400 then
       cmdstr:=cmdstr+' --input $IDF_PATH/components/esp_system/ld/esp32c3/sections.ld.in'
     else
       cmdstr:=cmdstr+' --input $IDF_PATH/components/esp32/ld/esp32c3.project.ld.in';
    end
  else;

  S:=FindUtil(utilsprefix+'objdump');
  cmdstr:=cmdstr+' --output '+sections_filename+
          ' --kconfig $IDF_PATH/Kconfig'+
          ' --env-file $OUTPUT/config.env'+
          ' --libraries-file $OUTPUT/ldgen_libraries'+
          ' --objdump '+S;

  Replace(cmdstr,'$IDF_PATH',idfpath);
  Replace(cmdstr,'$OUTPUT',outputexedir);
  if success then
    success:=DoExec(binstr,cmdstr,true,false);
end;
{$endif RISCV32}


function TlinkerFreeRTOS.MakeExecutable:boolean;
var
  StaticStr,
  binstr,
  cmdstr,
  mapstr: Ansistring;
  success : boolean;
  GCSectionsStr,
  DynLinkStr,
  StripStr,
  FixedExeFileName: string;
  {$if defined(RISCV32) or defined(ARM)}
  memory_script,
  sections_script,
  cntrlr,
  extraopts: AnsiString;
  {$endif defined(RISCV32) or defined(ARM)}
begin
  { for future use }
  StaticStr:='';
  StripStr:='';
  mapstr:='';
  DynLinkStr:='';
  success:=true;
  Result:=false;
  extraopts:='';

{$ifdef RISCV32}
  { idfpath can be set by -Ff, else default to environment value of IDF_PATH }
  if idfpath='' then
    idfpath := trim(GetEnvironmentVariable('IDF_PATH'));
  idfpath:=ExcludeTrailingBackslash(idfpath);
{$ifdef RISCV32}
  case current_settings.controllertype of
    ct_esp32c2: cntrlr:='esp32c2';
    ct_esp32c3: cntrlr:='esp32c3';
    ct_esp32c6:
      begin
        cntrlr:='esp32c6';
        { Extra option required to generate bin file }
        extraopts:=' --flash-mmu-page-size 32KB ';
      end
    else
      cntrlr:='';
    end;
{$endif RISCV32}

  { Locate linker scripts.  If not found, generate defaults. }
  { Cater for different script names in different esp-idf versions }
  if idf_version >= 40400 then
    begin
      memory_script := 'memory.ld';
      sections_script := 'sections.ld';
    end
  else
  begin
    memory_script := cntrlr+'_out.ld';
    sections_script := cntrlr+'.project.ld';
  end;

  if not (FindLibraryFile(memory_script,'','',memory_script) and
         FindLibraryFile(sections_script,'','',sections_script)) then
    GenerateDefaultLinkerScripts(memory_script,sections_script);
    begin
      Info.ExeCmd[1]:=Info.ExeCmd[1]+' -u call_user_start_cpu0 -u ld_include_panic_highint_hdl -u esp_app_desc -u vfs_include_syscalls_impl -u pthread_include_pthread_impl -u pthread_include_pthread_cond_impl -u pthread_include_pthread_local_storage_impl -u newlib_include_locks_impl '+
       '-u newlib_include_heap_impl -u newlib_include_syscalls_impl -u newlib_include_pthread_impl -u app_main -u uxTopUsedPriority '+
       '-L $IDF_PATH/components/esp_rom/'+cntrlr+'/ld ';
      if idf_version<40400 then
        Info.ExeCmd[1]:=Info.ExeCmd[1]+' -L $IDF_PATH/components/'+cntrlr+'/ld'
      else
        Info.ExeCmd[1]:=Info.ExeCmd[1]+' -L $IDF_PATH/components/soc/'+cntrlr+'/ld';

      Info.ExeCmd[1]:=Info.ExeCmd[1]+' -T '+memory_script+' -T '+sections_script;
      Info.ExeCmd[1]:=Info.ExeCmd[1]+' -T '+cntrlr+'.rom.ld -T '+cntrlr+'.rom.api.ld';
  {$ifdef RISCV32}
      if idf_version>=50300 then
        begin
          Info.ExeCmd[1]:=Info.ExeCmd[1]+' -L $IDF_PATH/components/riscv/ld';
          Info.ExeCmd[1]:=Info.ExeCmd[1]+' -T '+'rom.api.ld';
       end;

      if current_settings.controllertype=ct_esp32c2 then
        if idf_version>=50200 then
          Info.ExeCmd[1]:=Info.ExeCmd[1]+' -T '+cntrlr+'.rom.rvfp.ld -T '+cntrlr+'.rom.newlib.ld -T '+cntrlr+'.rom.version.ld -T '+cntrlr+'.rom.newlib-nano.ld -T '+cntrlr+'.rom.heap.ld'
        else if idf_version>=50000 then
          Info.ExeCmd[1]:=Info.ExeCmd[1]+' -T '+cntrlr+'.rom.rvfp.ld -T '+cntrlr+'.rom.newlib.ld -T '+cntrlr+'.rom.version.ld -T '+cntrlr+'.rom.newlib-time.ld -T '+cntrlr+'.rom.newlib-nano.ld -T '+cntrlr+'.rom.heap.ld'
        else
          Comment(V_Error,'Unsupported esp-idf version specified');

      if current_settings.controllertype=ct_esp32c3 then
        begin
         Info.ExeCmd[1]:=Info.ExeCmd[1]+' -T '+cntrlr+'.rom.libgcc.ld -T '+cntrlr+'.rom.newlib.ld  -T '+cntrlr+'.rom.version.ld -T '+cntrlr+'.rom.eco3.ld';
         if idf_version<50000 then
           Info.ExeCmd[1]:=Info.ExeCmd[1]+' -T '+cntrlr+'.rom.newlib-time.ld';
         if idf_version>=50000 then
           Info.ExeCmd[1]:=Info.ExeCmd[1]+' -T '+cntrlr+'.rom.eco3_bt_funcs.ld';
         if idf_version>=50300 then
           Info.ExeCmd[1]:=Info.ExeCmd[1]+' --allow-multiple -T'+cntrlr+'.rom.bt_funcs.ld -T '+cntrlr+'.rom.ble_master.ld -T '+cntrlr+'.rom.ble_50.ld -T '+cntrlr+'.rom.ble_smp.ld -T '+
             cntrlr+'.rom.ble_dtm.ld -T '+cntrlr+'.rom.ble_test.ld -T '+cntrlr+'.rom.ble_scan.ld';
         if idf_version>=50500 then
           Info.ExeCmd[1]:=Info.ExeCmd[1]+' -T '+cntrlr+'.rom.libc.ld';
        end
        else
          Comment(V_Error,'Unsupported esp-idf version specified');

      if current_settings.controllertype=ct_esp32c6 then
        if idf_version>=50200 then
          Info.ExeCmd[1]:=Info.ExeCmd[1]+' -T '+cntrlr+'.rom.rvfp.ld -T '+cntrlr+'.rom.newlib.ld -T '+cntrlr+'.rom.version.ld -T '+cntrlr+'.rom.phy.ld -T '+cntrlr+'.rom.coexist.ld -T '+cntrlr+'.rom.net80211.ld -T '+cntrlr+'.rom.pp.ld -T '+cntrlr+'.rom.wdt.ld -T '+cntrlr+'.rom.systimer.ld -T '+cntrlr+'.rom.newlib-normal.ld -T '+cntrlr+'.rom.heap.ld'
        else
         Comment(V_Error,'Unsupported esp-idf version specified');
  {$endif RISCV32}
      Info.ExeCmd[1]:=Info.ExeCmd[1]+' -T '+cntrlr+'.peripherals.ld'
    end;
  Replace(Info.ExeCmd[1],'$IDF_PATH',idfpath);
{$endif RISCV32}

  FixedExeFileName:=maybequoted(ScriptFixFileName(ChangeFileExt(current_module.exefilename,'.elf')));

  GCSectionsStr:='--gc-sections';
  if not(cs_link_nolink in current_settings.globalswitches) then
   Message1(exec_i_linking,current_module.exefilename);

  if (cs_link_map in current_settings.globalswitches) then
    mapstr:='-Map '+maybequoted(ChangeFileExt(current_module.exefilename,'.map'));

{ Write used files and libraries }
  WriteResponseFile();

{ Call linker }
  SplitBinCmd(Info.ExeCmd[1],binstr,cmdstr);
  Replace(cmdstr,'$OPT',Info.ExtraOptions);
  if not(cs_link_on_target in current_settings.globalswitches) then
   begin
    Replace(cmdstr,'$EXE',FixedExeFileName);
    Replace(cmdstr,'$RES',(maybequoted(ScriptFixFileName(outputexedir+Info.ResName))));
    Replace(cmdstr,'$STATIC',StaticStr);
    Replace(cmdstr,'$STRIP',StripStr);
    Replace(cmdstr,'$MAP',mapstr);
    Replace(cmdstr,'$GCSECTIONS',GCSectionsStr);
    Replace(cmdstr,'$DYNLINK',DynLinkStr);
   end
  else
   begin
    Replace(cmdstr,'$EXE',FixedExeFileName);
    Replace(cmdstr,'$RES',maybequoted(ScriptFixFileName(outputexedir+Info.ResName)));
    Replace(cmdstr,'$STATIC',StaticStr);
    Replace(cmdstr,'$STRIP',StripStr);
    Replace(cmdstr,'$MAP',mapstr);
    Replace(cmdstr,'$GCSECTIONS',GCSectionsStr);
    Replace(cmdstr,'$DYNLINK',DynLinkStr);
   end;
   success:=DoExec(FindUtil(utilsprefix+BinStr),cmdstr,true,false);

{ Remove ResponseFile }
  if success and not(cs_link_nolink in current_settings.globalswitches) then
   DeleteFile(outputexedir+Info.ResName);

{ Post process }
  if success and not(cs_link_nolink in current_settings.globalswitches) then
    success:=PostProcessExecutable(FixedExeFileName,false);

{$ifdef RISCV32}
  if success then
    begin
{$if defined(DARWIN)}
      success:=FindFileInExeLocations('python',true,binstr);
      cmdstr:=idfpath+'/components/esptool_py/esptool/esptool.py ';
{$elseif defined(UNIX)}
      binstr:=TargetFixPath(idfpath,false)+'/components/esptool_py/esptool/esptool.py';
      cmdstr:='';
{$else}
      binstr:='python';
      cmdstr:=idfpath+'/components/esptool_py/esptool/esptool.py ';
{$endif UNIX}
        begin
          success:=DoExec(binstr,cmdstr+'--chip '+cntrlr+' elf2image '+
            '--flash_size '+tostr(embedded_controllers[current_settings.controllertype].flashsize div (1024*1024))+'MB '+
            '--elf-sha256-offset 0xb0 '+extraopts+
            '-o '+maybequoted(ScriptFixFileName(ChangeFileExt(current_module.exefilename,'.bin')))+' '+
            FixedExeFileName,
            true,false);
        end;
    end;
{$else}
  if success then
    success:=DoExec(FindUtil(utilsprefix+'objcopy'),'-O binary '+
      FixedExeFileName+' '+
      maybequoted(ScriptFixFileName(ChangeFileExt(current_module.exefilename,'.bin'))),true,false);
{$endif RISCV32}

  MakeExecutable:=success;   { otherwise a recursive call to link method }
end;


function TlinkerFreeRTOS.postprocessexecutable(const fn : string;isdll:boolean):boolean;
  type
    TElf32header=packed record
      magic0123         : longint;
      file_class        : byte;
      data_encoding     : byte;
      file_version      : byte;
      padding           : array[$07..$0f] of byte;

      e_type            : word;
      e_machine         : word;
      e_version         : longint;
      e_entry           : longint;          { entrypoint }
      e_phoff           : longint;          { program header offset }

      e_shoff           : longint;          { sections header offset }
      e_flags           : longint;
      e_ehsize          : word;             { elf header size in bytes }
      e_phentsize       : word;             { size of an entry in the program header array }
      e_phnum           : word;             { 0..e_phnum-1 of entrys }
      e_shentsize       : word;             { size of an entry in sections header array }
      e_shnum           : word;             { 0..e_shnum-1 of entrys }
      e_shstrndx        : word;             { index of string section header }
    end;
    TElf32sechdr=packed record
      sh_name           : longint;
      sh_type           : longint;
      sh_flags          : longint;
      sh_addr           : longint;

      sh_offset         : longint;
      sh_size           : longint;
      sh_link           : longint;
      sh_info           : longint;

      sh_addralign      : longint;
      sh_entsize        : longint;
    end;

  function MayBeSwapHeader(h : telf32header) : telf32header;
    begin
      result:=h;
      if source_info.endian<>target_info.endian then
        with h do
          begin
            result.e_type:=swapendian(e_type);
            result.e_machine:=swapendian(e_machine);
            result.e_version:=swapendian(e_version);
            result.e_entry:=swapendian(e_entry);
            result.e_phoff:=swapendian(e_phoff);
            result.e_shoff:=swapendian(e_shoff);
            result.e_flags:=swapendian(e_flags);
            result.e_ehsize:=swapendian(e_ehsize);
            result.e_phentsize:=swapendian(e_phentsize);
            result.e_phnum:=swapendian(e_phnum);
            result.e_shentsize:=swapendian(e_shentsize);
            result.e_shnum:=swapendian(e_shnum);
            result.e_shstrndx:=swapendian(e_shstrndx);
          end;
    end;

  function MaybeSwapSecHeader(h : telf32sechdr) : telf32sechdr;
    begin
      result:=h;
      if source_info.endian<>target_info.endian then
        with h do
          begin
            result.sh_name:=swapendian(sh_name);
            result.sh_type:=swapendian(sh_type);
            result.sh_flags:=swapendian(sh_flags);
            result.sh_addr:=swapendian(sh_addr);
            result.sh_offset:=swapendian(sh_offset);
            result.sh_size:=swapendian(sh_size);
            result.sh_link:=swapendian(sh_link);
            result.sh_info:=swapendian(sh_info);
            result.sh_addralign:=swapendian(sh_addralign);
            result.sh_entsize:=swapendian(sh_entsize);
          end;
    end;

  var
    f : file;

  function ReadSectionName(pos : longint) : String;
    var
      oldpos : longint;
      c : char;
    begin
      oldpos:=filepos(f);
      seek(f,pos);
      Result:='';
      while true do
        begin
          blockread(f,c,1);
          if c=#0 then
            break;
          Result:=Result+c;
        end;
      seek(f,oldpos);
    end;

  var
    elfheader : TElf32header;
    secheader : TElf32sechdr;
    i : longint;
    stringoffset : longint;
    secname : string;
  begin
    postprocessexecutable:=false;
    { open file }
    assign(f,fn);
    {$push}{$I-}
    reset(f,1);
    if ioresult<>0 then
      Message1(execinfo_f_cant_open_executable,fn);
    { read header }
    blockread(f,elfheader,sizeof(tElf32header));
    elfheader:=MayBeSwapHeader(elfheader);
    seek(f,elfheader.e_shoff);
    { read string section header }
    seek(f,elfheader.e_shoff+sizeof(TElf32sechdr)*elfheader.e_shstrndx);
    blockread(f,secheader,sizeof(secheader));
    secheader:=MaybeSwapSecHeader(secheader);
    stringoffset:=secheader.sh_offset;

    seek(f,elfheader.e_shoff);
    status.codesize:=0;
    status.datasize:=0;
    for i:=0 to elfheader.e_shnum-1 do
      begin
        blockread(f,secheader,sizeof(secheader));
        secheader:=MaybeSwapSecHeader(secheader);
        secname:=ReadSectionName(stringoffset+secheader.sh_name);
        if pos('.text',secname)<>0 then
          begin
            Message1(execinfo_x_codesize,tostr(secheader.sh_size));
            status.codesize:=secheader.sh_size;
          end
        else if secname='.data' then
          begin
            Message1(execinfo_x_initdatasize,tostr(secheader.sh_size));
            inc(status.datasize,secheader.sh_size);
          end
        else if secname='.bss' then
          begin
            Message1(execinfo_x_uninitdatasize,tostr(secheader.sh_size));
            inc(status.datasize,secheader.sh_size);
          end;
      end;
    close(f);
    {$pop}
    if ioresult<>0 then
      ;
    postprocessexecutable:=true;
  end;


{*****************************************************************************
                                     Initialize
*****************************************************************************}

initialization
{$ifdef arm}
  RegisterLinker(ld_freertos,TlinkerFreeRTOS);
  RegisterTarget(system_arm_freertos_info);
{$endif arm}

{$ifdef i386}
  RegisterLinker(ld_freertos,TlinkerFreeRTOS);
  RegisterTarget(system_i386_embedded_info);
{$endif i386}

{$ifdef x86_64}
  RegisterLinker(ld_freertos,TlinkerFreeRTOS);
  RegisterTarget(system_x86_64_embedded_info);
{$endif x86_64}

{$ifdef mipsel}
  RegisterLinker(ld_freertos,TlinkerFreeRTOS);
  RegisterTarget(system_mipsel_embedded_info);
{$endif mipsel}


{$ifdef riscv32}
  RegisterLinker(ld_freertos,TlinkerFreeRTOS);
  RegisterTarget(system_riscv32_freertos_info);
{$endif riscv32}

{$ifdef riscv64}
  RegisterLinker(ld_freertos,TlinkerFreeRTOS);
  RegisterTarget(system_riscv64_embedded_info);
{$endif riscv64}

end.
