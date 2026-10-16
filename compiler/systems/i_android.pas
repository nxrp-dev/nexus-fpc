{
    Copyright (c) 1998-2012 by Peter Vreman

    This unit implements support information structures for Android

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
{ This unit implements support information structures for android. }
unit i_android;

{$i fpcdefs.inc}

  interface

    uses
       Systems,NXArtifactID;

    const

        system_aarch64_android_info  : TSystemInfo =
           (
             system       : system_aarch64_android;
             name         : 'Android for AArch64';
             shortname    : 'Android';
             flags        : [tf_needs_symbol_size,tf_needs_symbol_type,tf_files_case_sensitive,
                             tf_requires_proper_alignment, tf_safecall_exceptions,
                             tf_pic_uses_got, tf_pic_default,
                             tf_smartlink_sections,tf_has_winlike_resources,tf_supports_hidden_symbols];
             cpu          : cpu_aarch64;
             unit_env     : 'ANDROIDUNITS';
             extradefines : 'UNIX;HASUNIX';
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
             assem        : as_clang_gas;
             assemextern  : as_clang_gas;
             linkextern   : ld_android;
             ar           : ar_gnu_ar;
             res          : res_elf;
             dbg          : dbg_dwarf3;
             script       : script_unix;
             endian       : endian_little;
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
             StackSize    : 8*1024*1024;
             stackalign   : 16;
             abi : abi_default;
           );

        system_x86_64_android_info : TSystemInfo =
           (
             system       : system_x86_64_android;
             name         : 'Android for x86-64';
             shortname    : 'Android';
             flags        : [tf_needs_symbol_size,tf_needs_symbol_type,tf_files_case_sensitive,
                             tf_needs_dwarf_cfi,tf_has_winlike_resources,
                             {tf_pic_uses_got,} tf_pic_default, tf_smartlink_sections,
                             tf_safecall_exceptions, tf_safecall_clearstack,tf_supports_hidden_symbols];
             cpu          : cpu_x86_64;
             unit_env     : 'ANDROIDUNITS';
             extradefines : 'UNIX;HASUNIX';
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
             assem        : as_clang_gas;
             assemextern  : as_clang_gas;
             linkextern   : ld_android;
             ar           : ar_gnu_ar;
             res          : res_elf;
             dbg          : dbg_dwarf3;
             script       : script_unix;
             endian       : endian_little;
             alignment    :
               (
                 ProcAlign       : 16;
                 LoopAlign       : 8;
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
             StackSize    : 8*1024*1024;
             stackalign   : 16;
             abi : abi_default;
           );


implementation

initialization
{$ifdef CPUX86_64}
  {$ifdef android}
    SetSourceInfo(system_x86_64_android_info);
  {$endif}
{$endif CPUX86_64}
{$ifdef CPUAARCH64}
  {$ifdef android}
    SetSourceInfo(system_aarch64_android_info);
  {$endif android}
{$endif CPUAARCH64}
end.
