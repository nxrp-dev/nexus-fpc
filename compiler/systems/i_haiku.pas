{
    Copyright (c) 1998-2002 by Peter Vreman
    Copyright (c) 2008-2008 by Olivier Coursière

    This unit implements support information structures for Haiku

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
{ This unit implements support information structures for Haiku. }
unit i_haiku;

{$i fpcdefs.inc}

  interface

    uses
       systems;

    const
       system_x86_64_haiku_info : tsysteminfo =
          (
            system       : system_x86_64_Haiku;
            name         : 'Haiku for x86_64';
            shortname    : 'Haiku';
            flags        : [tf_under_development,tf_needs_symbol_size,tf_files_case_sensitive,
                            tf_pic_default,tf_library_needs_pic,tf_smartlink_sections,
                            tf_has_winlike_resources,tf_supports_hidden_symbols];
            cpu          : cpu_x86_64;
            unit_env     : 'HAIKUUNITS';
            extradefines : 'BEOS;UNIX;HASUNIX';
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
            linkextern   : ld_haiku;
            ar           : ar_gnu_ar;
            res          : res_elf;
            dbg          : dbg_dwarf2;
            script       : script_unix;
            endian       : endian_little;
            { FIXME: stuff below is copied from Linux/x64 now, could be incorrect for Haiku (KB) }
            alignment    :
              (
                procalign       : 16;
                loopalign       : 8;
                jumpalign       : 16;
                jumpalignskipmax    : 10;
                coalescealign   : 0;
                coalescealignskipmax: 0;
                constalignmin   : 0;
                constalignmax   : 16;
                varalignmin     : 0;
                varalignmax     : 16;
                localalignmin   : 4;
                localalignmax   : 16;
                recordalignmin  : 0;
                recordalignmax  : 16;
                maxCrecordalign : 16
              );
            first_parm_offset : 16;
            stacksize    : 16 * 1024 * 1024;
            stackalign   : 16;
            abi : abi_default;
            llvmdatalayout : 'e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-v64:64:64-v128:128:128-a0:0:64-s0:64:64-f80:128:128-n8:16:32:64-S128';
          );

  implementation

initialization
{$ifdef cpux86_64}
  {$ifdef haiku}
    set_source_info(system_x86_64_haiku_info);
  {$endif haiku}
{$endif cpux86_64}
end.
