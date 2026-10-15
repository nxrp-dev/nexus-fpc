{

    FPCRes - Free Pascal Resource Converter
    Part of the Free Pascal distribution
    Copyright (C) 2008 by Giulio Bernardi

    Target selection and definitions

    See the file COPYING, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
}

unit Target;

{$MODE OBJFPC}

interface

type
  TMachineType = (mtNone, mtI386,mtX8664,mtPPC,mtPPC64,mtARM,mtARMEB,mtM68K,
                  mtSPARC,mtAlpha,mtIA64,mtMIPS,mtMIPSEL,mtAArch64,mtPPC64LE,
                  mtRISCV32,mtRISCV64,mtLoongArch64,mtSPARC64,
                  mtBigEndian,mtLittleEndian);
  TMachineTypes = set of TMachineType;

  TSubMachineTypeArm = (smtARMAll,smtARMV4T,smtARMV6,smtARMV5TEJ,smtARMXScale,smtARMV7);
  TSubMachineTypeGeneric = (smtGenAll);

  TSubMachineType = record
    case TMachineType of
      mtARM,mtARMEB:
        (SubArm: TSubMachineTypeArm);
      mtNone, mtI386,mtX8664,mtPPC,mtPPC64,mtM68K,
      mtSPARC,mtAlpha,mtIA64,mtMIPS,mtMIPSEL,mtAArch64,mtPPC64LE,
      mtRISCV32,mtRISCV64,mtLoongArch64,mtSPARC64,
      mtBigEndian,mtLittleEndian:
        (SubGen: TSubMachineTypeGeneric);
  end;

  TObjFormat = (ofNone, ofRes, ofElf, ofCoff, ofXCoff, ofMachO, ofExt);
  TObjFormats = set of TObjFormat;


  TMachineInfo = record
    Name : string;
    Formats : TObjFormats;
    Alias : string;
  end;

  TFormatInfo = record
    Name : string;
    Ext : string;
    Machines : TMachineTypes;
  end;

  TResTarget = record
    Machine : TMachineType;
    SubMachine : TSubMachineType;
    ObjFormat : TObjFormat;
  end;

function GetDefaultMachineForFormat(AFormat : TObjFormat) : TMachineType;
function GetDefaultSubMachineForMachine(AMachine: TMachineType) : TSubMachineType;
function TargetToStr(const ATarget : TResTarget) : string;
function MachineToStr(const AMachine : TMachineType) : string;
function ObjFormatToStr(const AFormat : TObjFormat) : string;

var
  Machines : array[TMachineType] of TMachineInfo =
  (
    (Name : '';             Formats : [ofRes]),                   //mtnone
    (Name : 'i386';         Formats : [ofElf, ofCoff, ofMachO]),  //mti386
    (Name : 'x86_64';       Formats : [ofElf, ofCoff, ofMachO]),  //mtx86_64
    (Name : 'powerpc';      Formats : [ofElf, ofXCoff, ofMachO]), //mtppc
    (Name : 'powerpc64';    Formats : [ofElf, {ofXCoff,} ofMachO]), //mtppc64
    (Name : 'arm';          Formats : [ofElf, ofCoff, ofMachO]),  //mtarm
    (Name : 'armeb';        Formats : [ofElf]),                   //mtarmeb
    (Name : 'm68k';         Formats : [ofElf]),                   //mtm68k
    (Name : 'sparc';        Formats : [ofElf]),                   //mtsparc
    (Name : 'alpha';        Formats : [ofElf]),                   //mtalpha
    (Name : 'ia64';         Formats : [ofElf]),                   //mtia64
    (Name : 'mips';         Formats : [ofElf]; Alias : 'mipseb'), //mtmips
    (Name : 'mipsel';       Formats : [ofElf]),                   //mtmipsel
    (Name : 'aarch64';      Formats : [ofElf, ofCoff, ofMachO]),  //mtaarch64
    (Name : 'powerpc64le';  Formats : [ofElf]),                   //mtppc64le
    (Name : 'riscv32';      Formats : [ofElf]),                   //mtriscv32
    (Name : 'riscv64';      Formats : [ofElf]),                   //mtriscv64
    (Name : 'loongarch64';  Formats : [ofElf]),                   //mtloongarch64
    (Name : 'sparc64';      Formats : [ofElf]),                   //mtsparc64
    (Name : 'bigendian';    Formats : [ofExt]),                   //mtBigEndian
    (Name : 'littleendian'; Formats : [ofExt])                    //mtLittleEndian
  );

  SubMachinesArm: array[TSubMachineTypeArm] of string[8] =
    ('all','armv4','armv6','armv5tej','xscale','armv7');
  SubMachinesGen: array[TSubMachineTypeGeneric] of string[3] =
    ('all');

  ObjFormats : array[TObjFormat] of TFormatInfo =
  (
    (Name : '';         Ext : '';        Machines : []),
    (Name : 'res';      Ext : '.res';    Machines : [mtNone]),
    (Name : 'elf';      Ext : '.or';     Machines : [mtI386,mtX8664,mtPPC,
                                                     mtPPC64,mtARM,mtARMEB,
                                                     mtM68K,mtSPARC,mtAlpha,
                                                     mtIA64,mtMIPS,mtMIPSEL,
                                                     mtPPC64LE,mtAArch64,
                                                     mtRISCV32,mtRISCV64,
                                                     mtLoongArch64,mtSPARC64]),
    (Name : 'coff';     Ext : '.o';      Machines : [mtI386,mtX8664,mtARM,
                                                     mtAArch64,mtPPC,mtPPC64]),
    (Name : 'xcoff';    Ext : '.o';      Machines : [mtPPC{,mtppc64}]),
    (Name : 'mach-o';   Ext : '.or';     Machines : [mtI386,mtX8664,mtPPC,
                                                     mtPPC64,mtARM,mtAArch64]),
    (Name : 'external'; Ext : '.fpcres'; Machines : [mtBigEndian,mtLittleEndian])
  );


  CurrentTarget : TResTarget =
  (
  {$if defined(CPUI386)}
    Machine : mtI386;
    SubMachine : (SubGen: smtGenAll);
  {$elseif defined(CPUX86_64)}
    Machine : mtX8664;
    SubMachine : (SubGen: smtGenAll);
  {$elseif defined(CPUALPHA)}
    Machine : mtAlpha;
    SubMachine : (SubGen: smtGenAll);
  {$elseif defined(CPUIA64)}
    Machine : mtIA64;
    SubMachine : (SubGen: smtGenAll);
  {$elseif defined(CPUAARCH64)}
    Machine : mtAArch64;
    SubMachine : (SubGen: smtGenAll);
  {$elseif defined(CPULOONGARCH64)}
    Machine : mtLoongArch64;
    SubMachine : (SubGen: smtGenAll);
  {$else}
    Machine : mtI386;  //default i386
    SubMachine : (SubGen: smtGenAll);
  {$endif}

  {$IFDEF WINDOWS}
    ObjFormat : ofCoff;
  {$ELSE}
    {$IF defined(DARWIN)}
      ObjFormat : ofMachO;
    {$else}
      ObjFormat : ofElf;
    {$ENDIF}
  {$ENDIF}
  );


implementation

function GetDefaultMachineForFormat(AFormat : TObjFormat) : TMachineType;
begin
  case AFormat of
    ofNone : Result:=mtNone;
    ofRes  : Result:=mtNone;
    ofElf  : Result:=mtI386;
    ofCoff : Result:=mtI386;
    ofXCoff: Result:=mtPPC;
    ofMachO: Result:=mtI386;
    {$IFDEF ENDIAN_BIG}
    ofExt  : Result:=mtBigEndian;
    {$ELSE}
    ofExt  : Result:=mtLittleEndian;
    {$ENDIF}
  end;
end;

function MachineToStr(const AMachine : TMachineType) : string;
begin
  Result:=Machines[AMachine].Name;
end;

function SubMachineToStr(const AMachine : TMachineType; const ASubMachine : TSubMachineType) : string;
begin
  case AMachine of
    mtARM,mtARMEB:
      Result:=SubMachinesArm[ASubMachine.SubArm];
    else
      // no need to confuse people with the "all" suffix, it doesn't do
      // anything anyway
      Result:='';
  end;
end;

function ObjFormatToStr(const AFormat : TObjFormat) : string;
begin
  Result:=ObjFormats[AFormat].Name;
end;

function GetDefaultSubMachineForMachine(AMachine: TMachineType): TSubMachineType;
begin
  case AMachine of
    mtARM,mtARMEB:
      Result.SubArm:=smtARMAll;
    else
      Result.SubGen:=smtGenAll;
  end;
end;

function TargetToStr(const ATarget : TResTarget) : string;
var S1, S2, S3 : string;
begin
  S1:=MachineToStr(ATarget.Machine);
  S2:=ObjFormatToStr(ATarget.ObjFormat);
  S3:=SubMachineToStr(ATarget.Machine,ATarget.SubMachine);
  if (S1='') or (S2='') then Result:=S1+S2
  else Result:=S1+' - '+S2;
  if S3<>'' then
    Result:=Result+'-'+S3;
end;

end.
