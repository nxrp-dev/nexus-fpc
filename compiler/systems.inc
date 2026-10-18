{
    Copyright (c) 1998-2008 by Florian Klaempfl

    This include contains the enumeration
    information about the target systems supported
    (these are not processor specific)

    This program is free software; you can redistribute it and/or modify
    iu under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 675 Mass Ave, Cambridge- MA 02139, USA.

 ****************************************************************************
}
   type

     (*
       IMPORTANT NOTE:
       The value of this enumeration is stored in PPU files.
       Therefore adding new CPU targets should not change the
       explicitly assigned values of the pre-existing targets. (CEC)
       Never reuse an identifier belonging to a removed CPU target.
       FURTHERMORE : Make sure that this branch values, are
       consistent with the main branch version always.
     *)
       TSystemCPU =
       (
             cpu_no = 0,
             cpu_i386 = 1,
             cpu_x86_64 = 8,
             cpu_aarch64 = 16
       );

   const
       { Numeric PPU lookup tables still cover retired CPU identifiers. }
       MaxStoredCPUId = 25;

   type

       { Preserve assembler-mode values stored in generic token streams. }
       TAsmMode= (asmmode_none
            { standard assembler (cpu dependant) with full parsing }
            ,asmmode_standard
            ,asmmode_i386_att
            ,asmmode_i386_intel
            ,asmmode_arm_gas = 6
            ,asmmode_x86_64_gas = 8
            ,asmmode_x86_64_intel = 10
            ,asmmode_x86_64_att
       );

     (* IMPORTANT NOTE:
       the integer value of this enum is stored in PPU
       files to recognize the target. Keep every explicit value fixed;
       assign new targets unused values and never reuse removed IDs.
       FURTHERMORE : Make sure that this branch values are
       consistent with the main branch version always. (CEC)
       *)
     type
       TSystem =
       (
             system_none = 0,
             system_i386_linux = 3,
             system_i386_Win32 = 5,
             system_x86_64_linux = 26,
             system_x86_64_win64 = 37,
             system_i386_darwin = 44,
             system_x86_64_darwin = 61,
             system_i386_nativent = 68,
             system_i386_iphonesim = 69,
             system_i386_android = 78,
             system_aarch64_ios = 86,
             system_x86_64_iphonesim = 87,
             system_aarch64_linux = 88,
             system_aarch64_android = 100,
             system_x86_64_android = 101,
             system_aarch64_win64 = 107,
             system_aarch64_darwin = 111,
             system_aarch64_iphonesim = 121
       );

     const
       { Numeric PPU lookup tables still cover retired system identifiers. }
       MaxStoredSystemId = 126;

     type
       TAsm = (as_none
             ,as_default
             ,as_i386_pecoff
             ,as_i386_elf32
             ,as_x86_64_pecoff
             ,as_x86_64_elf64
             ,as_clang_asdarwin        { machine code assembler in Darwin as style assembled by clang }
             ,as_clang_gas             { machine code assembler in gas style assembled by clang }
       );

       TLink = (ld_none,
             ld_android,
             ld_darwin,
             ld_linux,
             ld_lld_windows
        );

       TAr = (ar_none
            ,ar_gnu_ar
            ,ar_gnu_ar_scripted
            ,ar_gnu_gar
       );

       TRes = (res_none,res_coff,res_elf,res_macho);

       TDbg = (dbg_none
            ,dbg_dwarf3,dbg_dwarf4,dbg_dwarf5
       );

       TScriptType = (script_none
            ,script_dos,script_unix
       );

       TABI = (abi_default
            ,abi_old_win32_gnu
            ,abi_aarch64_darwin
            { stack is aligned and all room for parameters is reserved on
              entry, but depending on the calling convention, the parameters
              may still be removed by the callee (and then the stack needs to
              be restored by the caller) }
            ,abi_i386_dynalignedstack
       );

       TCGBackend = (
           { default FPC code generator }
             cg_fpc
       );


