{
    Copyright (c) 1998-2008 by Peter Vreman

    This unit implements support information structures for Darwin
    (Mac OS X/OS X/macOS/iOS/iPhoneSimulator/...)

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
unit i_darwin;

{$i fpcdefs.inc}

interface

uses
   Systems,nxartifactid;

const
   res_macho_info : TResInfo =
       (
         id     : res_macho;
         resbin : 'fpcres';
         rescmd : '-o $OBJ -a $ARCH -s $SUBARCH -of mach-o $DBG';
         rcbin  : 'windres';
         rccmd  : '--include $INC -O res -D FPC -o $RES $RC';
         resourcefileclass : nil;
         resflags : [];
       );
   res_macosx_ext_info : TResInfo =
      (
         id     : res_ext;
         resbin : 'fpcres';
         rescmd : '-o $OBJ -a $ENDIAN -of external $DBG';
         rcbin  : 'windres';
         rccmd  : '--include $INC -O res -D FPC -o $RES $RC';
         resourcefileclass : nil;
         resflags : [res_external_file,res_arch_in_file_name];
      );






   system_x86_64_darwin_info  : TSystemInfo =
      (
        system       : system_x86_64_darwin;
        name         : 'Darwin for x86_64';
        shortname    : 'Darwin';
        flags        : [tf_p_ext_support,tf_files_case_sensitive,tf_smartlink_sections,tf_dwarf_relative_addresses,tf_dwarf_only_local_labels,tf_pic_default,tf_has_winlike_resources,tf_use_hlcfi
                        ,tf_supports_symbolorderfile,tf_supports_hidden_symbols];
        cpu          : cpu_x86_64;
        unit_env     : 'BSDUNITS';
        extradefines : 'UNIX;BSD;HASUNIX';
        ExeExt       : '';
        defext       : '.def';
        scriptext    : '.sh';
        smartext     : '.sl';
        unitext      : NexusUnitExtension;
        unitlibext   : '.ppl';
        asmext       : '.s';
        objext       : '.o';
        resext       : '.res';
        resobjext    : '.or';
        sharedlibext : '.dylib';
        staticlibext : '.a';
        staticlibprefix : 'libp';
        sharedlibprefix : 'lib';
        sharedClibext : '.dylib';
        staticClibext : '.a';
        staticClibprefix : 'lib';
        sharedClibprefix : 'lib';
        importlibprefix : 'libimp';
        importlibext : '.a';
        Cprefix      : '_';
        newline      : #10;
        dirsep       : '/';
        assem        : as_clang_asdarwin;
        assemextern  : as_clang_asdarwin;
        link         : ld_none;
        linkextern   : ld_darwin;
        ar           : ar_gnu_ar;
        res          : res_macho;
        dbg          : dbg_dwarf3;
        script       : script_unix;
        endian       : endian_little;
        alignment    :
          (
            ProcAlign       : 16;
            LoopAlign       : 8;
            JumpAlign       : 16;
            JumpAlignSkipMax    : 10;
            CoalesceAlign   : 0;
            CoalesceAlignSkipMax: 0;
            ConstAlignMin   : 0;
            ConstAlignMax   : 64;
            VarAlignMin     : 0;
            VarAlignMax     : 64;
            LocalAlignMin   : 4;
            LocalAlignMax   : 16;
            RecordAlignMin  : 0;
            RecordAlignMax  : 16;
            MaxCRecordAlign : 16
          );
        first_parm_offset : 16;
        StackSize   : 262144;
        stackalign   : 16;
        abi : abi_default;
      );


   system_x86_64_iphonesim_info  : TSystemInfo =
      (
        system       : system_x86_64_iphonesim;
        name         : 'Darwin/iPhoneSim for x86_64';
        shortname    : 'iPhoneSim';
        flags        : [tf_p_ext_support,tf_files_case_sensitive,tf_smartlink_sections,tf_dwarf_relative_addresses,tf_dwarf_only_local_labels,
                        tf_pic_default,tf_has_winlike_resources,tf_use_hlcfi,tf_supports_symbolorderfile,tf_supports_hidden_symbols
                        ,tf_requires_proper_alignment];
        cpu          : cpu_x86_64;
        unit_env     : 'BSDUNITS';
        extradefines : 'UNIX;BSD;HASUNIX;DARWIN'; // also define darwin for code compatibility
        ExeExt       : '';
        defext       : '.def';
        scriptext    : '.sh';
        smartext     : '.sl';
        unitext      : NexusUnitExtension;
        unitlibext   : '.ppl';
        asmext       : '.s';
        objext       : '.o';
        resext       : '.res';
        resobjext    : '.or';
        sharedlibext : '.dylib';
        staticlibext : '.a';
        staticlibprefix : 'libp';
        sharedlibprefix : 'lib';
        sharedClibext : '.dylib';
        staticClibext : '.a';
        staticClibprefix : 'lib';
        sharedClibprefix : 'lib';
        importlibprefix : 'libimp';
        importlibext : '.a';
        Cprefix      : '_';
        newline      : #10;
        dirsep       : '/';
        assem        : as_clang_asdarwin;
        assemextern  : as_clang_asdarwin;
        link         : ld_none;
        linkextern   : ld_darwin;
        ar           : ar_gnu_ar;
        res          : res_macho;
        dbg          : dbg_dwarf3;
        script       : script_unix;
        endian       : endian_little;
        alignment    :
          (
            ProcAlign       : 16;
            LoopAlign       : 8;
            JumpAlign       : 16;
            JumpAlignSkipMax    : 10;
            CoalesceAlign   : 0;
            CoalesceAlignSkipMax: 0;
            ConstAlignMin   : 0;
            ConstAlignMax   : 64;
            VarAlignMin     : 0;
            VarAlignMax     : 64;
            LocalAlignMin   : 4;
            LocalAlignMax   : 16;
            RecordAlignMin  : 0;
            RecordAlignMax  : 16;
            MaxCRecordAlign : 16
          );
        first_parm_offset : 16;
        StackSize   : 262144;
        stackalign   : 16;
        abi : abi_default;
      );




   system_aarch64_ios_info  : TSystemInfo =
      (
        system       : system_aarch64_ios;
        name         : 'iOS for AArch64';
        shortname    : 'iOS';
        flags        : [tf_p_ext_support,tf_requires_proper_alignment,tf_files_case_sensitive,tf_smartlink_sections,tf_dwarf_relative_addresses,
                        tf_dwarf_only_local_labels,tf_pic_default,tf_has_winlike_resources,tf_supports_symbolorderfile,tf_supports_hidden_symbols
                        ];
        cpu          : cpu_aarch64;
        unit_env     : 'BSDUNITS';
        extradefines : 'UNIX;BSD;HASUNIX;DARWIN';
        ExeExt       : '';
        defext       : '.def';
        scriptext    : '.sh';
        smartext     : '.sl';
        unitext      : NexusUnitExtension;
        unitlibext   : '.ppl';
        asmext       : '.s';
        objext       : '.o';
        resext       : '.res';
        resobjext    : '.or';
        sharedlibext : '.dylib';
        staticlibext : '.a';
        staticlibprefix : 'libp';
        sharedlibprefix : 'lib';
        sharedClibext : '.dylib';
        staticClibext : '.a';
        staticClibprefix : 'lib';
        sharedClibprefix : 'lib';
        importlibprefix : 'libimp';
        importlibext : '.a';
        Cprefix      : '_';
        newline      : #10;
        dirsep       : '/';
        assem        : as_clang_asdarwin;
        assemextern  : as_clang_asdarwin;
        link         : ld_none;
        linkextern   : ld_darwin;
        ar           : ar_gnu_ar;
        res          : res_macho;
        dbg          : dbg_dwarf3;
        script       : script_unix;
        endian       : endian_little;
        alignment    :
          (
            ProcAlign       : 16;
            LoopAlign       : 4;
            JumpAlign       : 0;
            JumpAlignSkipMax    : 0;
            CoalesceAlign   : 0;
            CoalesceAlignSkipMax: 0;
            ConstAlignMin   : 0;
            ConstAlignMax   : 64;
            VarAlignMin     : 0;
            VarAlignMax     : 16;
            LocalAlignMin   : 4;
            LocalAlignMax   : 16;
            RecordAlignMin  : 0;
            RecordAlignMax  : 16;
            MaxCRecordAlign : 16
          );
        first_parm_offset : 16;
        StackSize   : 8*1024*1024;
        stackalign   : 16;
        abi : abi_aarch64_darwin;
      );

   system_aarch64_darwin_info  : TSystemInfo =
      (
        system       : system_aarch64_darwin;
        name         : 'Darwin for AArch64';
        shortname    : 'Darwin';
        flags        : [tf_p_ext_support,tf_requires_proper_alignment,tf_files_case_sensitive,tf_smartlink_sections,tf_dwarf_relative_addresses,
                        tf_dwarf_only_local_labels,tf_pic_default,tf_has_winlike_resources,tf_supports_symbolorderfile,tf_supports_hidden_symbols
                        ];
        cpu          : cpu_aarch64;
        unit_env     : 'BSDUNITS';
        extradefines : 'UNIX;BSD;HASUNIX';
        ExeExt       : '';
        defext       : '.def';
        scriptext    : '.sh';
        smartext     : '.sl';
        unitext      : NexusUnitExtension;
        unitlibext   : '.ppl';
        asmext       : '.s';
        objext       : '.o';
        resext       : '.res';
        resobjext    : '.or';
        sharedlibext : '.dylib';
        staticlibext : '.a';
        staticlibprefix : 'libp';
        sharedlibprefix : 'lib';
        sharedClibext : '.dylib';
        staticClibext : '.a';
        staticClibprefix : 'lib';
        sharedClibprefix : 'lib';
        importlibprefix : 'libimp';
        importlibext : '.a';
        Cprefix      : '_';
        newline      : #10;
        dirsep       : '/';
        assem        : as_clang_asdarwin;
        assemextern  : as_clang_asdarwin;
        link         : ld_none;
        linkextern   : ld_darwin;
        ar           : ar_gnu_ar;
        res          : res_macho;
        dbg          : dbg_dwarf3;
        script       : script_unix;
        endian       : endian_little;
        alignment    :
          (
            ProcAlign       : 16;
            LoopAlign       : 4;
            JumpAlign       : 0;
            JumpAlignSkipMax    : 0;
            CoalesceAlign   : 0;
            CoalesceAlignSkipMax: 0;
            ConstAlignMin   : 0;
            ConstAlignMax   : 64;
            VarAlignMin     : 0;
            VarAlignMax     : 64;
            LocalAlignMin   : 4;
            LocalAlignMax   : 16;
            RecordAlignMin  : 0;
            RecordAlignMax  : 16;
            MaxCRecordAlign : 16
          );
        first_parm_offset : 16;
        StackSize   : 8*1024*1024;
        stackalign   : 16;
        abi : abi_aarch64_darwin;
      );


   system_aarch64_iphonesim_info  : TSystemInfo =
      (
        system       : system_aarch64_iphonesim;
        name         : 'Darwin/iPhoneSim for AArch64';
        shortname    : 'iPhoneSim';
        flags        : [tf_p_ext_support,tf_requires_proper_alignment,tf_files_case_sensitive,tf_smartlink_sections,tf_dwarf_relative_addresses,
                        tf_dwarf_only_local_labels,tf_pic_default,tf_has_winlike_resources,tf_supports_symbolorderfile,tf_supports_hidden_symbols
                        ];
        cpu          : cpu_aarch64;
        unit_env     : 'BSDUNITS';
        extradefines : 'UNIX;BSD;HASUNIX;DARWIN'; // also define darwin for code compatibility
        ExeExt       : '';
        defext       : '.def';
        scriptext    : '.sh';
        smartext     : '.sl';
        unitext      : NexusUnitExtension;
        unitlibext   : '.ppl';
        asmext       : '.s';
        objext       : '.o';
        resext       : '.res';
        resobjext    : '.or';
        sharedlibext : '.dylib';
        staticlibext : '.a';
        staticlibprefix : 'libp';
        sharedlibprefix : 'lib';
        sharedClibext : '.dylib';
        staticClibext : '.a';
        staticClibprefix : 'lib';
        sharedClibprefix : 'lib';
        importlibprefix : 'libimp';
        importlibext : '.a';
        Cprefix      : '_';
        newline      : #10;
        dirsep       : '/';
        assem        : as_clang_asdarwin;
        assemextern  : as_clang_asdarwin;
        link         : ld_none;
        linkextern   : ld_darwin;
        ar           : ar_gnu_ar;
        res          : res_macho;
        dbg          : dbg_dwarf3;
        script       : script_unix;
        endian       : endian_little;
        alignment    :
          (
            ProcAlign       : 16;
            LoopAlign       : 4;
            JumpAlign       : 0;
            JumpAlignSkipMax    : 0;
            CoalesceAlign   : 0;
            CoalesceAlignSkipMax: 0;
            ConstAlignMin   : 0;
            ConstAlignMax   : 64;
            VarAlignMin     : 0;
            VarAlignMax     : 16;
            LocalAlignMin   : 4;
            LocalAlignMax   : 16;
            RecordAlignMin  : 0;
            RecordAlignMax  : 16;
            MaxCRecordAlign : 16
          );
        first_parm_offset : 16;
        StackSize   : 8*1024*1024;
        stackalign   : 16;
        abi : abi_aarch64_darwin;
      );

implementation

initialization
  {$ifdef cpux86_64}
    {$ifdef Darwin}
      SetSourceInfo(system_x86_64_darwin_info);
    {$endif}
  {$endif cpux86_64}
  {$ifdef cpuaarch64}
    {$ifdef Darwin}
      {$ifdef ios}
        SetSourceInfo(system_aarch64_ios_info);
      {$else}
        SetSourceInfo(system_aarch64_darwin_info);
      {$endif}
    {$endif Darwin}
  {$endif cpuaarch64}

end.
