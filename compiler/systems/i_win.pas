{
    Copyright (c) 1998-2008 by Peter Vreman

    This unit implements support information structures for win32

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
{ This unit implements support information structures for win32. }
unit i_win;

{$i fpcdefs.inc}

  interface

    uses
       Systems,NXArtifactID;

    const

       system_i386_win32_info : TSystemInfo =
          (
            system       : system_i386_win32;
            name         : 'Win32 for i386';
            shortname    : 'Win32';
            flags        : [tf_files_case_aware,tf_has_dllscanner,
                            tf_smartlink_sections,tf_winlikewidestring,
                            tf_no_pic_supported,tf_no_generic_stackcheck,
                            tf_has_winlike_resources,tf_dwarf_only_local_labels,
                            tf_safecall_exceptions,tf_no_backquote_support,
                            tf_supports_hidden_symbols];
            cpu          : cpu_i386;
            unit_env     : 'NXPC_WIN32UNITS';
            extradefines : 'MSWINDOWS;WINDOWS';
            ExeExt       : '.exe';
            defext       : '.def';
            scriptext    : '.bat';
            smartext     : '.sl';
            unitext      : NexusUnitExtension;
            unitlibext   : '.ppl';
            asmext       : '.s';
            objext       : '.o';
            resext       : '.res';
            resobjext    : '.or';
            sharedlibext : '.dll';
            staticlibext : '.a';
            staticlibprefix : 'libp';
            sharedlibprefix : '';
            sharedClibext : '.dll';
            staticClibext : '.a';
            staticClibprefix : 'lib';
            sharedClibprefix : '';
            importlibprefix : 'libimp';
            importlibext : '.a';
            Cprefix      : '_';
            newline      : #13#10;
            dirsep       : '\';
            assem        : as_clang_gas;
            assemextern  : as_clang_gas;
            linkextern   : ld_lld_windows;
            ar           : ar_gnu_ar;
            res          : res_coff;
            dbg          : dbg_dwarf3;
            script       : script_dos;
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
                LocalAlignMax   : 8;
                RecordAlignMin  : 0;
                RecordAlignMax  : 4;
                MaxCRecordAlign : 16
              );
            first_parm_offset : 8;
            StackSize    : 16*1024*1024;
            stackalign   : 4;
            abi          : abi_default;
          );

       system_x64_win64_info : TSystemInfo =
          (
            system       : system_x86_64_win64;
            name         : 'Win64 for x64';
            shortname    : 'Win64';
            flags        : [tf_files_case_aware,tf_has_dllscanner,
                            tf_smartlink_sections,
                            tf_winlikewidestring,tf_no_pic_supported,
                            tf_dwarf_only_local_labels,
                            tf_no_generic_stackcheck,tf_has_winlike_resources,
                            tf_safecall_exceptions,tf_no_backquote_support,tf_supports_hidden_symbols,
                            tf_supports_packages];
            cpu          : cpu_x86_64;
            unit_env     : 'NXPC_WIN64UNITS';
            extradefines : 'MSWINDOWS;WINDOWS';
            ExeExt       : '.exe';
            defext       : '.def';
            scriptext    : '.bat';
            smartext     : '.sl';
            unitext      : NexusUnitExtension;
            unitlibext   : '.ppl';
            asmext       : '.s';
            objext       : '.o';
            resext       : '.res';
            resobjext    : '.obj';
            sharedlibext : '.dll';
            staticlibext : '.a';
            staticlibprefix : 'libp';
            sharedlibprefix : '';
            sharedClibext : '.dll';
            staticClibext : '.a';
            staticClibprefix : 'lib';
            sharedClibprefix : '';
            importlibprefix : 'libimp';
            importlibext : '.a';
            Cprefix      : '';
            newline      : #13#10;
            dirsep       : '\';
            assem        : as_clang_gas;
            assemextern  : as_clang_gas;
            linkextern   : ld_lld_windows;
            ar           : ar_gnu_ar;
            res          : res_coff;
            dbg          : dbg_dwarf3;
            script       : script_dos;
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
                RecordAlignMax  : 8;
                MaxCRecordAlign : 16
              );
            first_parm_offset : 16;
            StackSize    : 16*1024*1024;
            stackalign   : 16;
            abi          : abi_default;
          );


       system_aarch64_win64_info : TSystemInfo =
          (
            system       : system_aarch64_win64;
            name         : 'Win64 for Aarch64';
            shortname    : 'Win64';
            flags        : [tf_files_case_aware,tf_has_dllscanner,
                            tf_smartlink_sections,
                            tf_winlikewidestring,tf_no_pic_supported,
                            tf_dwarf_only_local_labels,
                            tf_no_generic_stackcheck,tf_has_winlike_resources,
                            tf_safecall_exceptions,tf_no_backquote_support,tf_supports_hidden_symbols];
            cpu          : cpu_aarch64;
            unit_env     : 'NXPC_WIN64UNITS';
            extradefines : 'MSWINDOWS;WINDOWS';
            ExeExt       : '.exe';
            defext       : '.def';
            scriptext    : '.bat';
            smartext     : '.sl';
            unitext      : NexusUnitExtension;
            unitlibext   : '.ppl';
            asmext       : '.s';
            objext       : '.o';
            resext       : '.res';
            resobjext    : '.obj';
            sharedlibext : '.dll';
            staticlibext : '.a';
            staticlibprefix : 'libp';
            sharedlibprefix : '';
            sharedClibext : '.dll';
            staticClibext : '.a';
            staticClibprefix : 'lib';
            sharedClibprefix : '';
            importlibprefix : 'libimp';
            importlibext : '.a';
            Cprefix      : '';
            newline      : #13#10;
            dirsep       : '\';
            assem        : as_clang_gas;
            assemextern  : as_clang_gas;
            linkextern   : ld_lld_windows;
            ar           : ar_gnu_ar;
            res          : res_coff;
            dbg          : dbg_dwarf3;
            script       : script_dos;
            alignment    :
              (
                ProcAlign       : 8;
                LoopAlign       : 4;
                JumpAlign       : 0;
                JumpAlignSkipMax    : 0;
                CoalesceAlign   : 0;
                CoalesceAlignSkipMax: 0;
                ConstAlignMin   : 0;
                ConstAlignMax   : 16;
                VarAlignMin     : 0;
                VarAlignMax     : 16;
                LocalAlignMin   : 4;
                LocalAlignMax   : 16;
                RecordAlignMin  : 0;
                RecordAlignMax  : 16;
                MaxCRecordAlign : 16
              );
            first_parm_offset : 16;
            StackSize    : 16*1024*1024;
            stackalign   : 16;
            abi          : abi_default;
          );


  implementation

initialization

{$ifdef CPUI386}
  {$ifdef WIN32}
    SetSourceInfo(system_i386_win32_info);
  {$endif WIN32}
{$endif CPUI386}

{$ifdef CPUX86_64}
  {$ifdef WIN64}
      SetSourceInfo(system_x64_win64_info);
  {$endif WIN64}
{$endif CPUX86_64}


{$ifdef CPUAARCH64}
  {$ifdef WIN64}
    SetSourceInfo(system_aarch64_win64_info);
  {$endif WIN64}
{$endif CPUAARCH64}
end.
