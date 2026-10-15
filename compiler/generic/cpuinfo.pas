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
     (fpu_none,
      fpu_soft
     );

   TControllerType =
     (ct_none
     );

   TControllerDataType = record
      ControllerTypeStr, controllerunitstr: string[20];
      CPUType: TCPUType; FPUType: TFPUType;
      flashbase, flashsize, srambase, sramsize, eeprombase, eepromsize, bootbase, bootsize: dword;
   end;

Const
   { Is there support for dealing with multiple microcontrollers available }
   { for this platform? }
   ControllerSupport = false;

   { We know that there are fields after sramsize
     but we don't care about this warning }
   {$PUSH}
    {$WARN 3177 OFF}
   embedded_controllers : array [TControllerType] of TControllerDataType =
   (
      (ControllerTypeStr:''; controllerunitstr:''; CPUType:cpu_none; FPUType:fpu_none; flashbase:0; flashsize:0; srambase:0; sramsize:0));
   {$POP}

   CPUTypeStr : array[TCPUType] of string[8] = ('none');
   FPUTypeStr : array[TFPUType] of string[6] = ('none','soft');

Implementation

end.
