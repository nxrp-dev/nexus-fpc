{
     File:       OSServices/Power.h

     Contains:   *** DEPRECATED *** Power Manager Interfaces.

     Copyright:  (c) 1990-2012 Apple Inc. All rights reserved.

     Bugs?:      For bug reports, consult the following page on
                 the World Wide Web:

                     http://bugs.freepascal.org

}
{
    Modified for use with Free Pascal
    Version 308
    Please report any bugs to <gpc@microbizz.nl>
}

{$ifc not defined MACOSALLINCLUDE or not MACOSALLINCLUDE}
{$mode macpas}
{$modeswitch cblocks}
{$packenum 1}
{$macro on}
{$inline on}
{$calling mwpascal}

{$IFNDEF FPC_DOTTEDUNITS}
unit Power;
{$ENDIF FPC_DOTTEDUNITS}
interface
{$setc UNIVERSAL_INTERFACES_VERSION := $0400}
{$setc GAP_INTERFACES_VERSION := $0308}

{$ifc not defined USE_CFSTR_CONSTANT_MACROS}
    {$setc USE_CFSTR_CONSTANT_MACROS := TRUE}
{$endc}

{$ifc defined FPC_BIG_ENDIAN and defined FPC_LITTLE_ENDIAN}
	{$error Conflicting initial definitions for FPC_BIG_ENDIAN and FPC_LITTLE_ENDIAN}
{$endc}

	{$setc __ppc__ := 0}
{$ifc not defined __ppc64__ and defined CPUPOWERPC64}
	{$setc __ppc64__ := 1}
{$elsec}
	{$setc __ppc64__ := 0}
{$endc}
	{$setc __i386__ := 0}
{$ifc not defined __x86_64__ and defined CPUX86_64}
	{$setc __x86_64__ := 1}
{$elsec}
	{$setc __x86_64__ := 0}
{$endc}
{$setc __arm__ := 0}
{$ifc not defined __arm64__ and defined CPUAARCH64}
  {$setc __arm64__ := 1}
{$elsec}
  {$setc __arm64__ := 0}
{$endc}

  {$setc __LP64__ := 1}



{$ifc defined __ppc64__ and __ppc64__}
	{$setc TARGET_CPU_PPC := FALSE}
	{$setc TARGET_CPU_PPC64 := TRUE}
	{$setc TARGET_CPU_X86 := FALSE}
	{$setc TARGET_CPU_X86_64 := FALSE}
	{$setc TARGET_CPU_ARM := FALSE}
	{$setc TARGET_CPU_ARM64 := FALSE}
	{$setc TARGET_OS_MAC := TRUE}
	{$setc TARGET_OS_IPHONE := FALSE}
	{$setc TARGET_IPHONE_SIMULATOR := FALSE}
	{$setc TARGET_OS_EMBEDDED := FALSE}
{$elifc defined __x86_64__ and __x86_64__}
	{$setc TARGET_CPU_PPC := FALSE}
	{$setc TARGET_CPU_PPC64 := FALSE}
	{$setc TARGET_CPU_X86 := FALSE}
	{$setc TARGET_CPU_X86_64 := TRUE}
	{$setc TARGET_CPU_ARM := FALSE}
	{$setc TARGET_CPU_ARM64 := FALSE}
{$ifc defined iphonesim}
 	{$setc TARGET_OS_MAC := FALSE}
	{$setc TARGET_OS_IPHONE := TRUE}
	{$setc TARGET_IPHONE_SIMULATOR := TRUE}
{$elsec}
	{$setc TARGET_OS_MAC := TRUE}
	{$setc TARGET_OS_IPHONE := FALSE}
	{$setc TARGET_IPHONE_SIMULATOR := FALSE}
{$endc}
	{$setc TARGET_OS_EMBEDDED := FALSE}
{$elifc defined __arm64__ and __arm64__}
	{$setc TARGET_CPU_PPC := FALSE}
	{$setc TARGET_CPU_PPC64 := FALSE}
	{$setc TARGET_CPU_X86 := FALSE}
	{$setc TARGET_CPU_X86_64 := FALSE}
	{$setc TARGET_CPU_ARM := FALSE}
	{$setc TARGET_CPU_ARM64 := TRUE}
{$ifc defined ios}
	{$setc TARGET_OS_MAC := FALSE}
	{$setc TARGET_OS_IPHONE := TRUE}
	{$setc TARGET_OS_EMBEDDED := TRUE}
{$elsec}
	{$setc TARGET_OS_MAC := TRUE}
	{$setc TARGET_OS_IPHONE := FALSE}
	{$setc TARGET_OS_EMBEDDED := FALSE}
{$endc}
	{$setc TARGET_IPHONE_SIMULATOR := FALSE}
{$elsec}
	{$error __ppc__ nor __ppc64__ nor __i386__ nor __x86_64__ nor __arm__ nor __arm64__ is defined.}
{$endc}

  {$setc TARGET_CPU_64 := TRUE}

{$ifc defined FPC_BIG_ENDIAN}
	{$setc TARGET_RT_BIG_ENDIAN := TRUE}
	{$setc TARGET_RT_LITTLE_ENDIAN := FALSE}
{$elifc defined FPC_LITTLE_ENDIAN}
	{$setc TARGET_RT_BIG_ENDIAN := FALSE}
	{$setc TARGET_RT_LITTLE_ENDIAN := TRUE}
{$elsec}
	{$error Neither FPC_BIG_ENDIAN nor FPC_LITTLE_ENDIAN are defined.}
{$endc}
{$setc ACCESSOR_CALLS_ARE_FUNCTIONS := TRUE}
{$setc CALL_NOT_IN_CARBON := FALSE}
{$setc OLDROUTINENAMES := FALSE}
{$setc OPAQUE_TOOLBOX_STRUCTS := TRUE}
{$setc OPAQUE_UPP_TYPES := TRUE}
{$setc OTCARBONAPPLICATION := TRUE}
{$setc OTKERNEL := FALSE}
{$setc PM_USE_SESSION_APIS := TRUE}
{$setc TARGET_API_MAC_CARBON := TRUE}
{$setc TARGET_API_MAC_OS8 := FALSE}
{$setc TARGET_API_MAC_OSX := TRUE}
{$setc TARGET_CARBON := TRUE}
{$setc TARGET_CPU_68K := FALSE}
{$setc TARGET_CPU_MIPS := FALSE}
{$setc TARGET_CPU_SPARC := FALSE}
{$setc TARGET_OS_UNIX := FALSE}
{$setc TARGET_OS_WIN32 := FALSE}
{$setc TARGET_RT_MAC_68881 := FALSE}
{$setc TARGET_RT_MAC_CFM := FALSE}
{$setc TARGET_RT_MAC_MACHO := TRUE}
{$setc TYPED_FUNCTION_POINTERS := TRUE}
{$setc TYPE_BOOL := FALSE}
{$setc TYPE_EXTENDED := FALSE}
{$setc TYPE_LONGLONG := TRUE}
{$IFDEF FPC_DOTTEDUNITS}
uses MacOsApi.MacTypes,MacOsApi.Multiprocessing,MacOsApi.MacErrors;
{$ELSE FPC_DOTTEDUNITS}
uses MacTypes,Multiprocessing,MacErrors;
{$ENDIF FPC_DOTTEDUNITS}
{$endc} {not MACOSALLINCLUDE}


{$ifc TARGET_OS_MAC}

{$ALIGN MAC68K}

const
{ commands to SleepQRec sleepQProc }
	kSleepRequest = 1;
	kSleepDemand = 2;
	kSleepWakeUp = 3;
	kSleepRevoke = 4;
	kSleepUnlock = 4;
	kSleepDeny = 5;    { A non-zero value clients can use to deny requests}
	kSleepNow = 6;
	kDozeDemand = 7;
	kDozeWakeUp = 8;
	kDozeRequest = 9;    { additional messages for Power Mgr 2.0}
	kEnterStandby = 10;   { Idle Queue Only}
	kEnterRun = 11;   { Idle Queue Only}
	kSuspendRequest = 12;
	kSuspendDemand = 13;
	kSuspendRevoke = 14;
	kSuspendWakeUp = 15;
	kGetPowerLevel = 16;
	kSetPowerLevel = 17;
	kDeviceInitiatedWake = 18;
	kWakeToDoze = 19;
	kDozeToFullWakeUp = 20;
	kGetPowerInfo = 21;
	kGetWakeOnNetInfo = 22;
	kSuspendWakeToDoze = 23;
	kEnterIdle = 24;   { Idle Queue Only}
	kStillIdle = 25;   { Idle Queue Only}
	kExitIdle = 26;    { Idle Queue Only}

const
{ SleepQRec.sleepQFlags }
	noCalls = 1;
	noRequest = 2;
	slpQType = 16;
	sleepQType = 16;

{ System Activity Selectors }
{ Notes:  The IdleActivity selector is not available unless the hasAggressiveIdling PMFeatures bit is set.     }
{ Use IdleActivity where you used to use OverallAct if necessary. OverallAct will only delay power cycling     }
{ if it's enabled, and will delay sleep by a small amount when hasAggressiveIdling is set.  Don't use          }
{ IdleActivity unless hasAggressiveIdling is set; when hasAggressiveIdling is not set, the use of IdleActivity }
{ is undefined, and well do different things depending on which Power Manager is currently running.            }
const
	OverallAct = 0;    { Delays idle sleep by small amount                          }
	UsrActivity = 1;    { Delays idle sleep and dimming by timeout time              }
	NetActivity = 2;    { Delays idle sleep and power cycling by small amount        }
	HDActivity = 3;    { Delays hard drive spindown and idle sleep by small amount  }
	IdleActivity = 4;     { Delays idle sleep by timeout time                          }

type
	SleepQRecPtr = ^SleepQRec;
	SleepQProcPtr = function( message: SIGNEDLONG; qRecPtr: SleepQRecPtr ): SIGNEDLONG;
	SleepQUPP = SleepQProcPtr;
	SleepQRec = record
		sleepQLink: SleepQRecPtr;             { pointer to next queue element          }
		sleepQType: SInt16;             { queue element type (must be SleepQType)       }
		sleepQProc: SleepQUPP;             { pointer to sleep universal proc ptr         }
		sleepQFlags: SInt16;            { flags                       }
	end;
{
 *  NewSleepQUPP()   *** DEPRECATED ***
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework [32-bit only] but deprecated in 10.5
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewSleepQUPP( userRoutine: SleepQProcPtr ): SleepQUPP; external name '_NewSleepQUPP';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0,__MAC_10_5,__IPHONE_NA,__IPHONE_NA) *)


{
 *  DisposeSleepQUPP()   *** DEPRECATED ***
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework [32-bit only] but deprecated in 10.5
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeSleepQUPP( userUPP: SleepQUPP ); external name '_DisposeSleepQUPP';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0,__MAC_10_5,__IPHONE_NA,__IPHONE_NA) *)


{
 *  InvokeSleepQUPP()   *** DEPRECATED ***
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework [32-bit only] but deprecated in 10.5
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function InvokeSleepQUPP( message: SIGNEDLONG; qRecPtr: SleepQRecPtr; userUPP: SleepQUPP ): SIGNEDLONG; external name '_InvokeSleepQUPP';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0,__MAC_10_5,__IPHONE_NA,__IPHONE_NA) *)


{
 *  GetCPUSpeed()   *** DEPRECATED ***
 *
 *  Deprecated:
 *    Use sysctlbyname("hw.cpufrequency"). Found in <sys/sysctl.h>.
 *
 *  Discussion:
 *    GetCPUSpeed() returns the current effective clock speed of the
 *    CPU in megahertz.
 *
 *  Result:
 *    the current effective clock speed of the CPU in megahertz.
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework but deprecated in 10.8
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in InterfaceLib 7.1 and later
 }
function GetCPUSpeed: SIGNEDLONG; external name '_GetCPUSpeed';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0,__MAC_10_8,__IPHONE_NA,__IPHONE_NA) *)


{
 *  SleepQInstall()   *** DEPRECATED ***
 *
 *  Deprecated:
 *    Use IORegisterForSystemPower(). Found in <IOKit/pwr_mgt/IOPMLib.h>.
 *
 *  Discussion:
 *    Adds an entry to the sleep queue.
 *
 *  Parameters:
 *
 *    qRecPtr:
 *      A pointer to a sleep queue record to be installed.
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework but deprecated in 10.8
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in InterfaceLib 7.1 and later
 }
procedure SleepQInstall( qRecPtr: SleepQRecPtr ); external name '_SleepQInstall';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0,__MAC_10_8,__IPHONE_NA,__IPHONE_NA) *)


{
 *  SleepQRemove()   *** DEPRECATED ***
 *
 *  Deprecated:
 *    Use IODeregisterForSystemPower(). Found in <IOKit/pwr_mgt/IOPMLib.h>.
 *
 *  Discussion:
 *    Remove an entry from the sleep queue.
 *
 *  Parameters:
 *
 *    qRecPtr:
 *      A pointer to a sleep queue record to be removed.
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework but deprecated in 10.8
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in InterfaceLib 7.1 and later
 }
procedure SleepQRemove( qRecPtr: SleepQRecPtr ); external name '_SleepQRemove';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0,__MAC_10_8,__IPHONE_NA,__IPHONE_NA) *)


{
 *  MaximumProcessorSpeed()   *** DEPRECATED ***
 *
 *  Deprecated:
 *    Use sysctlbyname("hw.cpufrequency_max"). Found in <sys/sysctl.h>.
 *
 *  Discussion:
 *    MaximumProcessorSpeed() returns the maximum effective clock speed
 *    of the CPU in megahertz.
 *
 *  Result:
 *    the maximum effective clock speed of the CPU in megahertz.
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework but deprecated in 10.8
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in PowerMgrLib 1.0 and later
 }
function MaximumProcessorSpeed: SInt16; external name '_MaximumProcessorSpeed';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0,__MAC_10_8,__IPHONE_NA,__IPHONE_NA) *)


{
 *  MinimumProcessorSpeed()   *** DEPRECATED ***
 *
 *  Deprecated:
 *    Use sysctlbyname("hw.cpufrequency_min"). Found in <sys/sysctl.h>.
 *
 *  Discussion:
 *    MinimumProcessorSpeed() returns the minimum effective clock speed
 *    of the CPU in megahertz. Before Mac OS X 10.4, this function
 *    always returns the maximum cpu speed, not the minimum as expected.
 *
 *  Result:
 *    the minimum effective clock speed of the CPU in megahertz.
 *
 *  Availability:
 *    Mac OS X:         in version 10.1 and later in CoreServices.framework but deprecated in 10.8
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in PowerMgrLib 1.0 and later
 }
function MinimumProcessorSpeed: SInt16; external name '_MinimumProcessorSpeed';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_1,__MAC_10_8,__IPHONE_NA,__IPHONE_NA) *)


{
 *  CurrentProcessorSpeed()   *** DEPRECATED ***
 *
 *  Deprecated:
 *    Use sysctlbyname("hw.cpufrequency"). Found in <sys/sysctl.h>.
 *
 *  Discussion:
 *    CurrentProcessorSpeed() returns the current effective clock speed
 *    of the CPU in megahertz. Before Mac OS X 10.4, this function
 *    always returns the maximum cpu speed, not the actual current
 *    speed the processor is running at.  One MHz represents one
 *    million cycles per second.
 *
 *  Result:
 *    the current effective clock speed of the CPU in megahertz.
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework but deprecated in 10.8
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in PowerMgrLib 1.0 and later
 }
function CurrentProcessorSpeed: SInt16; external name '_CurrentProcessorSpeed';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0,__MAC_10_8,__IPHONE_NA,__IPHONE_NA) *)


{
 *  BatteryCount()   *** DEPRECATED ***
 *
 *  Deprecated:
 *    Use IOPowerSources API. Found in <IOKit/ps/IOPowerSources.h>.
 *
 *  Summary:
 *    Return the count of batteries installed on this computer.
 *
 *  Result:
 *    the count of batteries installed.
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework but deprecated in 10.8
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in PowerMgrLib 1.0 and later
 }
function BatteryCount: SInt16; external name '_BatteryCount';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0,__MAC_10_8,__IPHONE_NA,__IPHONE_NA) *)


{
 *  UpdateSystemActivity()   *** DEPRECATED ***
 *
 *  Deprecated:
 *    Use IOPMAssertionCreateWithName(). Found in <IOKit/pwr_mgt/IOPMLib.h>.
 *
 *  Summary:
 *    You can use the UpdateSystemActivity function to notify the Power
 *    Manager that activity has taken place.
 *
 *  Discussion:
 *    The UpdateSystemActivity function is used to notify the Power
 *    Manager that activity has taken place and the timers used to
 *    measure idle time should be updated to the time of this call.
 *    This function can be used by device drivers to prevent the
 *    computer from entering a low-power mode while critical activity
 *    is taking place on a particular device. The function is passed a
 *    parameter indicating the type of activity that has
 *    occurred.
 *
 *    This function is slightly different from DelaySystemIdle, which
 *    should be used to prevent sleep or idle during a critical
 *    section. UpdateSystemActivity simply updates the tick count for
 *    the activity type selected. Conversely, DelaySystemIdle actually
 *    moves the counter to some number of ticks into the future, which
 *    allows the caller to go off and do somethingwithout fear of
 *    idling.
 *
 *    The valid types of activity are:
 *    Value Name       Value        Description
 *    OverallAct       0            general type of activity
 *    UsrActivity      1            user activity (i.e.keyboard or mouse)
 *    NetActivity      2            interaction with network(s)
 *    HDActivity       3            hard disk or storage device in use
 *
 *  Parameters:
 *
 *    activity:
 *      The type of activity which has occurred.
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework but deprecated in 10.8
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in PowerMgrLib 1.0 and later
 }
function UpdateSystemActivity( activity: UInt8 ): OSErr; external name '_UpdateSystemActivity';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0,__MAC_10_8,__IPHONE_NA,__IPHONE_NA) *)


{*********************************************************************************************
 *
 *  Everything below this point in this file is deprecated and should not be used
 *  in new code on Mac OS X.  Existing clients should move to non-deprecated
 *  where possible.
 *
 *********************************************************************************************}
type
	RegEntryID = UNSIGNEDLONG;
	PowerHandlerProcPtr = function( message: UInt32; param: UnivPtr; refCon: UInt32; var regEntryID_: RegEntryID ): OSStatus;
	PowerHandlerUPP = PowerHandlerProcPtr;
{
 *  NewPowerHandlerUPP()
 *
 *  Availability:
 *    Mac OS X:         not available
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   available as macro/inline
 }

{
 *  DisposePowerHandlerUPP()
 *
 *  Availability:
 *    Mac OS X:         not available
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   available as macro/inline
 }

{
 *  InvokePowerHandlerUPP()
 *
 *  Availability:
 *    Mac OS X:         not available
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   available as macro/inline
 }

type
	HDQueueElementPtr = ^HDQueueElement;
	PMgrQueueElementPtr = ^PMgrQueueElement;
	HDSpindownProcPtr = procedure( theElement: HDQueueElementPtr );
	PMgrStateChangeProcPtr = procedure( theElement: PMgrQueueElementPtr; stateBits: SIGNEDLONG );
	HDSpindownUPP = HDSpindownProcPtr;
	PMgrStateChangeUPP = PMgrStateChangeProcPtr;
	HDQueueElement = record end;
	PMgrQueueElement = record end;

{
 *  NewHDSpindownUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewHDSpindownUPP( userRoutine: HDSpindownProcPtr ): HDSpindownUPP; external name '_NewHDSpindownUPP';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0,__MAC_10_5,__IPHONE_NA,__IPHONE_NA) *)


{
 *  NewPMgrStateChangeUPP()   *** DEPRECATED ***
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework [32-bit only] but deprecated in 10.5
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewPMgrStateChangeUPP( userRoutine: PMgrStateChangeProcPtr ): PMgrStateChangeUPP; external name '_NewPMgrStateChangeUPP';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0,__MAC_10_5,__IPHONE_NA,__IPHONE_NA) *)


{
 *  DisposeHDSpindownUPP()   *** DEPRECATED ***
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework [32-bit only] but deprecated in 10.5
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeHDSpindownUPP( userUPP: HDSpindownUPP ); external name '_DisposeHDSpindownUPP';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0,__MAC_10_5,__IPHONE_NA,__IPHONE_NA) *)


{
 *  DisposePMgrStateChangeUPP()   *** DEPRECATED ***
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework [32-bit only] but deprecated in 10.5
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposePMgrStateChangeUPP( userUPP: PMgrStateChangeUPP ); external name '_DisposePMgrStateChangeUPP';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0,__MAC_10_5,__IPHONE_NA,__IPHONE_NA) *)


{
 *  InvokeHDSpindownUPP()   *** DEPRECATED ***
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework [32-bit only] but deprecated in 10.5
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure InvokeHDSpindownUPP( var theElement: HDQueueElement; userUPP: HDSpindownUPP ); external name '_InvokeHDSpindownUPP';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0,__MAC_10_5,__IPHONE_NA,__IPHONE_NA) *)


{
 *  InvokePMgrStateChangeUPP()   *** DEPRECATED ***
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework [32-bit only] but deprecated in 10.5
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure InvokePMgrStateChangeUPP( var theElement: PMgrQueueElement; stateBits: SIGNEDLONG; userUPP: PMgrStateChangeUPP ); external name '_InvokePMgrStateChangeUPP';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0,__MAC_10_5,__IPHONE_NA,__IPHONE_NA) *)

{$endc} {TARGET_OS_MAC}
{$ifc not defined MACOSALLINCLUDE or not MACOSALLINCLUDE}

end.
{$endc} {not MACOSALLINCLUDE}
