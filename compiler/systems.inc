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
       tendian = (endian_little,endian_big);

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

       tasmmode= (asmmode_none
            { standard assembler (cpu dependant) with full parsing }
            ,asmmode_standard
            ,asmmode_i386_att
            ,asmmode_i386_intel
            ,asmmode_ppc_gas
            ,asmmode_ppc_motorola
            ,asmmode_arm_gas
            ,asmmode_sparc_gas
            ,asmmode_x86_64_gas
            ,asmmode_m68k_mot
            ,asmmode_x86_64_intel
            ,asmmode_x86_64_att
            ,asmmode_avr_gas
            ,asmmode_i8086_intel
            ,asmmode_i8086_att
            ,asmmode_arm_gas_unified
            ,asmmode_xtensa_gas
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
       tasm = (as_none
             ,as_default
             ,as_gas                   { standard gnu assembler }
             ,as_i386_pecoff
             ,as_darwin
             ,as_x86_64_masm
             ,as_x86_64_pecoff
             ,as_x86_64_elf64
             ,as_yasm
             ,as_i386_nasm
             ,as_x86_64_nasm
             ,as_x86_64_nasmwin64
             ,as_x86_64_nasmelf
             ,as_x86_64_nasmdarwin
             ,as_clang_asdarwin        { machine code assembler in Darwin as style assembled by clang }
             ,as_clang_llvm
             ,as_clang_gas             { machine code assembler in gas style assembled by clang }
             ,as_clang_llvm_darwin
             ,as_win64_gas
       );

       tlink = (ld_none,
             ld_android,
             ld_darwin,
             ld_linux,
             ld_lld_windows
        );

       tar = (ar_none
            ,ar_gnu_ar
            ,ar_mpw_ar
            ,ar_gnu_ar_scripted
            ,ar_gnu_gar
            ,ar_watcom_wlib_omf
            ,ar_watcom_wlib_omf_scripted
            ,ar_sdcc_sdar
            ,ar_sdcc_sdar_scripted
       );

       tres = (res_none
            ,res_gnu_windres,res_watcom_wrc_os2
            ,res_m68k_palmos,res_m68k_mpw
            ,res_powerpc_mpw,res_elf,res_xcoff
            ,res_win64_gorc, res_macho, res_ext
            ,res_jvm_raw,res_wasm
       );

       tresinfoflags = (res_external_file,res_arch_in_file_name
            ,res_single_file,res_no_compile);

       tdbg = (dbg_none
            ,dbg_stabs,dbg_stabx,dbg_dwarf3,dbg_dwarf4,dbg_dwarf5,dbg_jasmin
            ,dbg_codeview,dbg_llvm
       );

       tscripttype = (script_none
            ,script_dos,script_unix,
            script_mpw,
            script_fpcres
       );

       tabi = (abi_default
            ,abi_powerpc_sysv,abi_powerpc_aix,abi_powerpc_darwin,abi_powerpc_elfv2
            ,abi_eabi,abi_armeb,abi_eabihf
            ,abi_old_win32_gnu
            ,abi_aarch64_darwin
            ,abi_riscv_ilp32
            ,abi_riscv_ilp32f
            ,abi_riscv_ilp32d
            ,abi_riscv_ilp32e
            ,abi_riscv_lp64
            ,abi_riscv_lp64f
            ,abi_riscv_lp64d
            ,abi_riscv_lp64q
            { stack is aligned and all room for parameters is reserved on
              entry, but depending on the calling convention, the parameters
              may still be removed by the callee (and then the stack needs to
              be restored by the caller) }
            ,abi_i386_dynalignedstack
            ,abi_xtensa_windowed
            ,abi_xtensa_call0
            ,abi_mips_o32
            ,abi_mips_n32
            ,abi_mips_o64
            ,abi_mips_n64
            ,abi_loongarch_lp64s
            ,abi_loongarch_lp64f
            ,abi_loongarch_lp64d
            ,abi_loongarch_lp32s
            ,abi_loongarch_lp32f
            ,abi_loongarch_lp32d
       );

       tcgbackend = (
           { default FPC code generator }
             cg_fpc
           { LLVM code generator }
           , cg_llvm
       );

     const
       abi_powerpc_elfv1 = abi_powerpc_sysv;


