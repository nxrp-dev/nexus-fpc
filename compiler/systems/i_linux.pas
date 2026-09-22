{
    Copyright (c) 1998-2008 by Peter Vreman

    This unit implements support information structures for linux

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
{ This unit implements support information structures for linux. }
unit i_linux;

{$i fpcdefs.inc}

  interface

    uses
       systems;

    const

       system_x86_6432_linux_info : tsysteminfo =
          (
            system       : system_x86_6432_LINUX;
            name         : 'Linux for x64_6432';
            shortname    : 'Linux6432';
            flags        : [tf_needs_symbol_size,tf_needs_symbol_type,tf_files_case_sensitive,
                            tf_pic_uses_got,tf_smartlink_sections,
                            tf_has_winlike_resources,tf_supports_hidden_symbols];
            cpu          : cpu_x86_64;
            unit_env     : 'LINUXUNITS';
            extradefines : 'UNIX;HASUNIX';
            exeext       : '';
            defext       : '.def';
            scriptext    : '.sh';
            smartext     : '.sl';
            unitext      : '.ppu';
            unitlibext   : '.ppl';
            asmext       : '.s';
            objext       : '.o';
            resext       : '.res';
            resobjext    : '.or';
            sharedlibext : '.so';
            staticlibext : '.a';
            staticlibprefix : 'libp';
            sharedlibprefix : 'lib';
            sharedClibext : '.so';
            staticClibext : '.a';
            staticClibprefix : 'lib';
            sharedClibprefix : 'lib';
            importlibprefix : 'libimp';
            importlibext : '.a';
            Cprefix      : '';
            newline      : #10;
            dirsep       : '/';
            assem        : as_i386_elf32;
            assemextern  : as_gas;
            link         : ld_none;
            linkextern   : ld_linux;
            ar           : ar_gnu_ar;
            res          : res_elf;
            dbg          : dbg_dwarf3;
            script       : script_unix;
            endian       : endian_little;
            alignment    :
              (
                procalign       : 16;
                loopalign       : 4;
                jumpalign       : 0;
                jumpalignskipmax    : 0;
                coalescealign   : 0;
                coalescealignskipmax: 0;
                constalignmin   : 0;
                constalignmax   : 16;
                varalignmin     : 0;
                varalignmax     : 16;
                localalignmin   : 4;
                localalignmax   : 8;
                recordalignmin  : 0;
                recordalignmax  : 16;
                maxCrecordalign : 4
              );
            first_parm_offset : 8;
            stacksize    : 8*1024*1024;
            stackalign   : 16;
            abi : abi_default;
            llvmdatalayout : 'todo';
          );



    const
       system_x86_64_linux_info : tsysteminfo =
          (
            system       : system_x86_64_LINUX;
            name         : 'Linux for x86-64';
            shortname    : 'Linux';
            flags        : [tf_smartlink_sections,tf_needs_symbol_size,tf_needs_dwarf_cfi,
{$ifdef tls_threadvars}
                            tf_section_threadvars,
{$endif tls_threadvars}
                            tf_library_needs_pic,tf_needs_symbol_type,tf_files_case_sensitive,
                            tf_has_winlike_resources,tf_safecall_exceptions,tf_safecall_clearstack
                            {$ifdef llvm},tf_use_psabieh{$endif}
{$ifdef psabieh}
                            ,tf_use_psabieh
{$endif psabieh}
                            ,tf_supports_hidden_symbols
                            ];
            cpu          : cpu_x86_64;
            unit_env     : 'LINUXUNITS';
            extradefines : 'UNIX;HASUNIX';
            exeext       : '';
            defext       : '.def';
            scriptext    : '.sh';
            smartext     : '.sl';
            unitext      : '.ppu';
            unitlibext   : '.ppl';
            asmext       : '.s';
            objext       : '.o';
            resext       : '.res';
            resobjext    : '.or';
            sharedlibext : '.so';
            staticlibext : '.a';
            staticlibprefix : 'libp';
            sharedlibprefix : 'lib';
            sharedClibext : '.so';
            staticClibext : '.a';
            staticClibprefix : 'lib';
            sharedClibprefix : 'lib';
            importlibprefix : 'libimp';
            importlibext : '.a';
            Cprefix      : '';
            newline      : #10;
            dirsep       : '/';
            assem        : as_x86_64_elf64;
            assemextern  : as_gas;
            link         : ld_none;
            linkextern   : ld_linux;
            ar           : ar_gnu_ar;
            res          : res_elf;
            dbg          : dbg_dwarf3;
            script       : script_unix;
            endian       : endian_little;
            alignment    :
              (
                procalign       : 16;
                loopalign       : 8;
                jumpalign       : 16;
                jumpalignskipmax    : 10;
                coalescealign   : 0;
                coalescealignskipmax: 0;
                constalignmin   : 0;
                constalignmax   : 64;
                varalignmin     : 0;
                varalignmax     : 64;
                localalignmin   : 4;
                localalignmax   : 16;
                recordalignmin  : 0;
                recordalignmax  : 16;
                maxCrecordalign : 16
              );
            first_parm_offset : 16;
            stacksize    : 8*1024*1024;
            stackalign   : 16;
            abi : abi_default;
            llvmdatalayout : 'e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-v64:64:64-v128:128:128-a0:0:64-s0:64:64-f80:128:128-n8:16:32:64-S128';
          );



{$ifdef FPC_ARMHF}
       system_arm_linux_info : tsysteminfo =
          (
            system       : system_arm_Linux;
            name         : 'Linux for ARMHF';
            shortname    : 'Linux';
            flags        : [tf_needs_symbol_size,tf_needs_symbol_type,tf_files_case_sensitive,
                            tf_requires_proper_alignment,tf_safecall_exceptions,
{$ifdef tls_threadvars}
                            tf_section_threadvars,
{$endif tls_threadvars}
{$ifdef llvm}
                            tf_use_psabieh,
{$endif llvm}
                            tf_smartlink_sections,tf_pic_uses_got,
                            tf_has_winlike_resources,tf_supports_hidden_symbols];
            cpu          : cpu_arm;
            unit_env     : 'LINUXUNITS';
            extradefines : 'UNIX;HASUNIX;CPUARMHF';
            exeext       : '';
            defext       : '.def';
            scriptext    : '.sh';
            smartext     : '.sl';
            unitext      : '.ppu';
            unitlibext   : '.ppl';
            asmext       : '.s';
            objext       : '.o';
            resext       : '.res';
            resobjext    : '.or';
            sharedlibext : '.so';
            staticlibext : '.a';
            staticlibprefix : 'libp';
            sharedlibprefix : 'lib';
            sharedClibext : '.so';
            staticClibext : '.a';
            staticClibprefix : 'lib';
            sharedClibprefix : 'lib';
            importlibprefix : 'libimp';
            importlibext : '.a';
            Cprefix      : '';
            newline      : #10;
            dirsep       : '/';
            assem        : as_arm_elf32;
            assemextern  : as_gas;
            link         : ld_none;
            linkextern   : ld_linux;
            ar           : ar_gnu_ar;
            res          : res_elf;
            dbg          : dbg_dwarf2;
            script       : script_unix;
            endian       : endian_little;
            alignment    :
              (
                procalign       : 4;
                loopalign       : 4;
                jumpalign       : 0;
                jumpalignskipmax    : 0;
                coalescealign   : 0;
                coalescealignskipmax: 0;
                constalignmin   : 0;
                constalignmax   : 32;
                varalignmin     : 0;
                varalignmax     : 32;
                localalignmin   : 4;
                localalignmax   : 8;
                recordalignmin  : 0;
                recordalignmax  : 16;
                maxCrecordalign : 16
              );
            first_parm_offset : 8;
            stacksize    : 8*1024*1024;
            stackalign   : 8;
            abi : abi_eabihf;
            llvmdatalayout : 'e-p:32:32:32-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-v64:64:64-v128:64:128-a0:0:64-n32-S64';
          );
{$else FPC_ARMHF}
{$ifdef FPC_ARMEL}
       system_arm_linux_info : tsysteminfo =
          (
            system       : system_arm_Linux;
            name         : 'Linux for ARMEL';
            shortname    : 'Linux';
            flags        : [tf_needs_symbol_size,tf_needs_symbol_type,tf_files_case_sensitive,
                            tf_needs_dwarf_cfi,tf_requires_proper_alignment,tf_safecall_exceptions,
{$ifdef tls_threadvars}
                            tf_section_threadvars,
{$endif tls_threadvars}
                            tf_smartlink_sections,tf_pic_uses_got,
                            tf_has_winlike_resources,tf_supports_hidden_symbols];
            cpu          : cpu_arm;
            unit_env     : 'LINUXUNITS';
            extradefines : 'UNIX;HASUNIX;CPUARMEL';
            exeext       : '';
            defext       : '.def';
            scriptext    : '.sh';
            smartext     : '.sl';
            unitext      : '.ppu';
            unitlibext   : '.ppl';
            asmext       : '.s';
            objext       : '.o';
            resext       : '.res';
            resobjext    : '.or';
            sharedlibext : '.so';
            staticlibext : '.a';
            staticlibprefix : 'libp';
            sharedlibprefix : 'lib';
            sharedClibext : '.so';
            staticClibext : '.a';
            staticClibprefix : 'lib';
            sharedClibprefix : 'lib';
            importlibprefix : 'libimp';
            importlibext : '.a';
            Cprefix      : '';
            newline      : #10;
            dirsep       : '/';
            assem        : as_arm_elf32;
            assemextern  : as_gas;
            link         : ld_none;
            linkextern   : ld_linux;
            ar           : ar_gnu_ar;
            res          : res_elf;
            dbg          : dbg_dwarf2;
            script       : script_unix;
            endian       : endian_little;
            alignment    :
              (
                procalign       : 4;
                loopalign       : 4;
                jumpalign       : 0;
                jumpalignskipmax    : 0;
                coalescealign   : 0;
                coalescealignskipmax: 0;
                constalignmin   : 0;
                constalignmax   : 32;
                varalignmin     : 0;
                varalignmax     : 32;
                localalignmin   : 4;
                localalignmax   : 8;
                recordalignmin  : 0;
                recordalignmax  : 16;
                maxCrecordalign : 16
              );
            first_parm_offset : 8;
            stacksize    : 8*1024*1024;
            stackalign   : 8;
            abi : abi_eabi;
            llvmdatalayout : 'e-p:32:32:32-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-v64:64:64-v128:64:128-a0:0:64-n32-S64';
          );
{$else FPC_ARMEL}
{$ifdef FPC_ARMEB}
       system_arm_linux_info : tsysteminfo =
          (
            system       : system_arm_Linux;
            name         : 'Linux for ARMEB';
            shortname    : 'Linux';
            flags        : [tf_needs_symbol_size,tf_needs_symbol_type,tf_files_case_sensitive,
                            tf_requires_proper_alignment,tf_safecall_exceptions,
                            tf_smartlink_sections,tf_pic_uses_got,
                            tf_has_winlike_resources,tf_supports_hidden_symbols];
            cpu          : cpu_arm;
            unit_env     : 'LINUXUNITS';
            extradefines : 'UNIX;HASUNIX;CPUARMEB';
            exeext       : '';
            defext       : '.def';
            scriptext    : '.sh';
            smartext     : '.sl';
            unitext      : '.ppu';
            unitlibext   : '.ppl';
            asmext       : '.s';
            objext       : '.o';
            resext       : '.res';
            resobjext    : '.or';
            sharedlibext : '.so';
            staticlibext : '.a';
            staticlibprefix : 'libp';
            sharedlibprefix : 'lib';
            sharedClibext : '.so';
            staticClibext : '.a';
            staticClibprefix : 'lib';
            sharedClibprefix : 'lib';
            importlibprefix : 'libimp';
            importlibext : '.a';
            Cprefix      : '';
            newline      : #10;
            dirsep       : '/';
            assem        : as_gas;
            assemextern  : as_gas;
            link         : ld_none;
            linkextern   : ld_linux;
            ar           : ar_gnu_ar;
            res          : res_elf;
            dbg          : dbg_stabs;
            script       : script_unix;
            endian       : endian_big;
            alignment    :
              (
                procalign       : 4;
                loopalign       : 4;
                jumpalign       : 0;
                jumpalignskipmax    : 0;
                coalescealign   : 0;
                coalescealignskipmax: 0;
                constalignmin   : 0;
                constalignmax   : 32;
                varalignmin     : 0;
                varalignmax     : 32;
                localalignmin   : 4;
                localalignmax   : 8;
                recordalignmin  : 0;
                recordalignmax  : 16;
                maxCrecordalign : 4
              );
            first_parm_offset : 8;
            stacksize    : 8*1024*1024;
            stackalign   : 4;
            abi : abi_default;
            llvmdatalayout: 'todo';
          );
{$else FPC_ARMEB}
       system_arm_linux_info : tsysteminfo =
          (
            system       : system_arm_Linux;
            name         : 'Linux for ARM';
            shortname    : 'Linux';
            flags        : [tf_needs_symbol_size,tf_needs_symbol_type,tf_files_case_sensitive,
                            tf_requires_proper_alignment,tf_safecall_exceptions,
                            tf_smartlink_sections,tf_has_winlike_resources,tf_supports_hidden_symbols];
            cpu          : cpu_arm;
            unit_env     : 'LINUXUNITS';
            extradefines : 'UNIX;HASUNIX';
            exeext       : '';
            defext       : '.def';
            scriptext    : '.sh';
            smartext     : '.sl';
            unitext      : '.ppu';
            unitlibext   : '.ppl';
            asmext       : '.s';
            objext       : '.o';
            resext       : '.res';
            resobjext    : '.or';
            sharedlibext : '.so';
            staticlibext : '.a';
            staticlibprefix : 'libp';
            sharedlibprefix : 'lib';
            sharedClibext : '.so';
            staticClibext : '.a';
            staticClibprefix : 'lib';
            sharedClibprefix : 'lib';
            importlibprefix : 'libimp';
            importlibext : '.a';
            Cprefix      : '';
            newline      : #10;
            dirsep       : '/';
            assem        : as_gas;
            assemextern  : as_gas;
            link         : ld_none;
            linkextern   : ld_linux;
            ar           : ar_gnu_ar;
            res          : res_elf;
            dbg          : dbg_dwarf3;
            script       : script_unix;
            endian       : endian_little;
            alignment    :
              (
                procalign       : 4;
                loopalign       : 4;
                jumpalign       : 0;
                jumpalignskipmax    : 0;
                coalescealign   : 0;
                coalescealignskipmax: 0;
                constalignmin   : 0;
                constalignmax   : 32;
                varalignmin     : 0;
                varalignmax     : 32;
                localalignmin   : 4;
                localalignmax   : 4;
                recordalignmin  : 0;
                recordalignmax  : 16;
                maxCrecordalign : 4
              );
            first_parm_offset : 8;
            stacksize    : 8*1024*1024;
            stackalign   : 4;
            abi : abi_default;
            llvmdatalayout: 'e-p:32:32:32-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:32:64-f32:32:32-f64:32:64-v64:32:64-v128:32:128-a0:0:32-n32-S32';
          );
{$endif FPC_ARMEB}
{$endif FPC_ARMEL}
{$endif FPC_ARMHF}

       system_aarch64_linux_info  : tsysteminfo =
          (
            system       : system_aarch64_linux;
            name         : 'Linux for AArch64';
            shortname    : 'Linux';
            flags        : [tf_needs_symbol_size,
                            tf_needs_symbol_type,
                            tf_files_case_sensitive,
                            tf_requires_proper_alignment,tf_safecall_exceptions,
                            tf_smartlink_sections,tf_pic_uses_got,
                            tf_has_winlike_resources
{$ifdef llvm}
                            ,tf_use_psabieh
{$endif llvm}
                            ,tf_supports_hidden_symbols
                            ];
            cpu          : cpu_aarch64;
            unit_env     : 'LINUXUNITS';
            extradefines : 'UNIX;HASUNIX';
            exeext       : '';
            defext       : '.def';
            scriptext    : '.sh';
            smartext     : '.sl';
            unitext      : '.ppu';
            unitlibext   : '.ppl';
            asmext       : '.s';
            objext       : '.o';
            resext       : '.res';
            resobjext    : '.or';
            sharedlibext : '.so';
            staticlibext : '.a';
            staticlibprefix : 'libp';
            sharedlibprefix : 'lib';
            sharedClibext : '.so';
            staticClibext : '.a';
            staticClibprefix : 'lib';
            sharedClibprefix : 'lib';
            importlibprefix : 'libimp';
            importlibext : '.a';
            Cprefix      : '';
            newline      : #10;
            dirsep       : '/';
            assem        : as_gas;
            assemextern  : as_gas;
            link         : ld_none;
            linkextern   : ld_linux;
            ar           : ar_gnu_ar;
            res          : res_elf;
            dbg          : dbg_dwarf2;
            script       : script_unix;
            endian       : endian_little;
            alignment    :
              (
                procalign       : 8;
                loopalign       : 4;
                jumpalign       : 0;
                jumpalignskipmax    : 0;
                coalescealign   : 0;
                coalescealignskipmax: 0;
                constalignmin   : 0;
                constalignmax   : 64;
                varalignmin     : 0;
                varalignmax     : 64;
                localalignmin   : 4;
                localalignmax   : 16;
                recordalignmin  : 0;
                recordalignmax  : 16;
                maxCrecordalign : 16
              );
            first_parm_offset : 16;
            stacksize    : 8*1024*1024;
            stackalign   : 16;
            abi : abi_default;
            llvmdatalayout : 'e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-v64:64:64-v128:128:128-a0:0:64-n32:64-S128'
          );








  implementation

initialization
{$ifdef CPUX86_64}
  {$ifdef linux}
    set_source_info(system_x86_64_linux_info);
  {$endif linux}
{$endif CPUX86_64}
{$ifdef CPUARM}
  {$ifdef linux}
    set_source_info(system_arm_linux_info);
  {$endif linux}
{$endif CPUARM}
{$ifdef cpuaarch64}
  {$ifdef linux}
    set_source_info(system_aarch64_linux_info);
  {$endif linux}
{$endif cpuaarch64}
end.

