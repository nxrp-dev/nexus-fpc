{
    Copyright (c) 1998-2002 by the Free Pascal development team

    Basic Processor information for the Generic CPU
    This file is used by PPUDump program from utils subdirectory.

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

Unit CPUInfo;

{$i fpcdefs.inc}

Interface

  uses
    GlobType;

Type



   { possible supported processors for this target }
   TCPUType =
      (cpu_none
      );

   { copied from arm/cpuinfo unit for arm specific
     TSettings field }
   TInstructionSet = (is_thumb,is_arm);


Type
   TFPUType =
     (fpu_none
     );


Const


   CPUTypeStr : array[TCPUType] of string[8] = ('none');
   FPUTypeStr : array[TFPUType] of string[6] = ('');

Implementation

end.
