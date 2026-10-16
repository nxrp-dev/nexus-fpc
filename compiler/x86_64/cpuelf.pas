{
    Copyright (c) 1998-2006 by Peter Vreman

    Includes ELF-related code specific to x86_64

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
unit cpuelf;

{$i fpcdefs.inc}

interface

implementation

  uses
    GlobType,CUtils,CClasses,
    Verbose,elfbase,
    Systems,aasmbase,ogbase,ogelf,assemble;

  const
    { Relocation types }
    R_X86_64_NONE = 0;
    R_X86_64_64 = 1;                 { Direct 64 bit   }
    R_X86_64_PC32 = 2;               { PC relative 32 bit signed  }
    R_X86_64_GOT32 = 3;              { 32 bit GOT entry  }
    R_X86_64_PLT32 = 4;              { 32 bit PLT address  }
    R_X86_64_COPY = 5;               { Copy symbol at runtime  }
    R_X86_64_GLOB_DAT = 6;           { Create GOT entry  }
    R_X86_64_JUMP_SLOT = 7;          { Create PLT entry  }
    R_X86_64_RELATIVE = 8;           { Adjust by program base  }
    R_X86_64_GOTPCREL = 9;           { 32 bit signed PC relative offset to GOT  }
    R_X86_64_32 = 10;                { Direct 32 bit zero extended  }
    R_X86_64_32S = 11;               { Direct 32 bit sign extended  }
    R_X86_64_16 = 12;                { Direct 16 bit zero extended  }
    R_X86_64_PC16 = 13;              { 16 bit sign extended PC relative  }
    R_X86_64_8 = 14;                 { Direct 8 bit sign extended   }
    R_X86_64_PC8 = 15;               { 8 bit sign extended PC relative  }
    R_X86_64_DTPMOD64 = 16;          { ID of module containing symbol  }
    R_X86_64_DTPOFF64 = 17;          { Offset in module's TLS block  }
    R_X86_64_TPOFF64 = 18;           { Offset in initial TLS block  }
    { 32 bit signed PC relative offset to two GOT entries for GD symbol  }
    R_X86_64_TLSGD = 19;
    { 32 bit signed PC relative offset to two GOT entries for LD symbol  }
    R_X86_64_TLSLD = 20;
    R_X86_64_DTPOFF32 = 21;          { Offset in TLS block  }
    { 32 bit signed PC relative offset to GOT entry for IE symbol  }
    R_X86_64_GOTTPOFF = 22;
    R_X86_64_TPOFF32 = 23;           { Offset in initial TLS block  }
    R_X86_64_PC64 = 24;              { PC relative 64-bit signed }
    R_X86_64_GOTOFF64 = 25;          { 64-bit offset from GOT base }
    R_X86_64_GOTPC32 = 26;           { PC-relative offset GOT }
    R_X86_64_GOT64  = 27;            { 64-bit GOT entry offset }
    R_X86_64_GOTPCREL64 = 28;        { 64-bit PC relative offset to GOT entry }
    R_X86_64_GOTPC64 = 29;           { 64-bit PC relative offset to GOT }
    R_X86_64_GOTPLT64 = 30;          { Like GOT64, indicates that PLT entry needed }
    R_X86_64_PLTOFF64 = 31;          { 64-bit GOT relative offset to PLT entry }
    R_X86_64_SIZE32 = 32;
    R_X86_64_SIZE64 = 33;
    R_X86_64_GOTPC32_TLSDESC = 34;
    R_X86_64_TLSDESC_CALL = 35;
    R_X86_64_TLSDESC = 36;
    R_X86_64_IRELATIVE = 37;
    R_X86_64_GOTPCRELX =41;
    R_X86_64_REX_GOTPCRELX =42;
    R_X86_64_GNU_VTINHERIT = 250;    { GNU extension to record C++ vtable hierarchy }
    R_X86_64_GNU_VTENTRY = 251;      { GNU extension to record C++ vtable member usage }

  type
    TRelocProp=record
      name: PChar;
      size: byte;
    end;

  const
    relocprops: array[0..37] of TRelocProp=(
      (name: 'R_X86_64_NONE';  size:0),
      (name: 'R_X86_64_64';    size:8),
      (name: 'R_X86_64_PC32';  size:4),
      (name: 'R_X86_64_GOT32'; size:4),
      (name: 'R_X86_64_PLT32'; size:4),
      (name: 'R_X86_64_COPY';  size:0),
      (name: 'R_X86_64_GLOB_DAT'; size:8),
      (name: 'R_X86_64_JUMP_SLOT';size:8),
      (name: 'R_X86_64_RELATIVE'; size:8),
      (name: 'R_X86_64_GOTPCREL'; size:4),
      (name: 'R_X86_64_32';    size:4),
      (name: 'R_X86_64_32S';   size:4),
      (name: 'R_X86_64_16';    size:2),
      (name: 'R_X86_64_PC16';  size:2),
      (name: 'R_X86_64_8';     size:1),
      (name: 'R_X86_64_PC8';   size:1),
      (name: 'R_X86_64_DTPMOD64'; size:8),
      (name: 'R_X86_64_DTPOFF64'; size:8),
      (name: 'R_X86_64_TPOFF64';  size:8),
      (name: 'R_X86_64_TLSGD';    size:4),
      (name: 'R_X86_64_TLSLD';    size:4),
      (name: 'R_X86_64_DTPOFF32'; size:4),
      (name: 'R_X86_64_GOTTPOFF'; size:4),
      (name: 'R_X86_64_TPOFF32';  size:4),
      (name: 'R_X86_64_PC64';     size:8),
      (name: 'R_X86_64_GOTOFF64'; size:8),
      (name: 'R_X86_64_GOTPC32';  size:4),
      (name: 'R_X86_64_GOT64';    size:8),
      (name: 'R_X86_64_GOTPCREL64'; size:8),
      (name: 'R_X86_64_GOTPC64';  size:8),
      (name: 'R_X86_64_GOTPLT64'; size:8),
      (name: 'R_X86_64_PLTOFF64'; size:8),
      (name: 'R_X86_64_SIZE32';   size:4),
      (name: 'R_X86_64_SIZE64';   size:8),
      (name: 'R_X86_64_GOTPC32_TLSDESC'; size:4),
      (name: 'R_X86_64_TLSDESC_CALL';    size:0),
      (name: 'R_X86_64_TLSDESC';   size:8),
      (name: 'R_X86_64_IRELATIVE'; size:8)
    );


{****************************************************************************
                              ELF Target methods
****************************************************************************}

  function elf_x86_64_encodereloc(objrel:TObjRelocation):byte;
    begin
      case objrel.typ of
        RELOC_NONE :
          result:=R_X86_64_NONE;
      { Note: 8 and 16-bit relocations are known to be non-conformant with
        AMD64 ABI, so they aren't handled. }
        RELOC_RELATIVE :
          if objrel.Size=8 then
            result:=R_X86_64_PC64
          else if objrel.Size=4 then
            result:=R_X86_64_PC32
          else
            InternalError(2012061900);
        RELOC_ABSOLUTE :
          if objrel.Size=8 then
            result:=R_X86_64_64
          else if objrel.Size=4 then
            result:=R_X86_64_32
          else
            InternalError(2012061902);
        RELOC_ABSOLUTE32 :
          result:=R_X86_64_32S;
        RELOC_GOTPCREL :
          result:=R_X86_64_GOTPCREL;
        RELOC_GOTPCRELX :
          result:=R_X86_64_GOTPCRELX;
        RELOC_REX_GOTPCRELX :
          result:=R_X86_64_REX_GOTPCRELX;
        RELOC_PLT32 :
          result:=R_X86_64_PLT32;
        RELOC_TPOFF:
          if objrel.Size=8 then
            result:=R_X86_64_TPOFF64
          else if objrel.Size=4 then
            result:=R_X86_64_TPOFF32
          else
            InternalError(2019091701);
        RELOC_TLSGD:
          result:=R_X86_64_TLSGD;
        RELOC_DTPOFF:
          if objrel.Size=8 then
            result:=R_X86_64_DTPOFF64
          else if objrel.Size=4 then
            result:=R_X86_64_DTPOFF32
          else
            InternalError(2019091702);
        else
          result:=0;
          InternalError(2012082302);
      end;
    end;


  procedure elf_x86_64_loadreloc(objrel:TObjRelocation);
    begin
    end;



  const
    elf_target_x86_64: TElfTarget =
      (
        machine_code:      EM_X86_64;
        relocs_use_addend: true;
        encodereloc:       @elf_x86_64_encodeReloc;
        loadreloc:         @elf_x86_64_loadReloc;
        loadsection:       nil;
        encodeflags:       nil;
      );


    as_x86_64_elf64_info : TAsmInfo =
      (
        id     : as_x86_64_elf64;
        idtxt  : 'ELF';
        asmbin : '';
        asmcmd : '';
        supported_targets : [system_x86_64_linux,system_x86_64_android];
        flags : [af_outputbinary,af_smartlink_sections,af_supports_dwarf];
        labelprefix : '.L';
        labelmaxlen : -1;
        comment : '';
        dollarsign: '$';
      );

initialization
  RegisterAssembler(as_x86_64_elf64_info,TElfAssembler);
  ElfTarget:=elf_target_x86_64;

end.

