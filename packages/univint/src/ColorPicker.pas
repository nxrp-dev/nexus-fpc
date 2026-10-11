{
     File:       CommonPanels/ColorPicker.h

     Contains:   Color Picker package Interfaces.

     Version:    CommonPanels-94~602

     Copyright:  © 1987-2008 by Apple Computer, Inc., all rights reserved

     Bugs?:      For bug reports, consult the following page on
                 the World Wide Web:

                     http://bugs.freepascal.org

}
{  Pascal Translation Updated:  Jonas Maebe, <jonas@freepascal.org>, October 2009 }
{  Pascal Translation Updated:  Jonas Maebe, <jonas@freepascal.org>, October 2012 }
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
unit ColorPicker;
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



{$ifc defined __x86_64__ and __x86_64__}
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
	{$error Neither __x86_64__ nor __arm64__ is defined.}
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
uses MacOsApi.MacTypes,MacOsApi.ColorSyncDeprecated,MacOsApi.MixedMode,MacOsApi.QuickdrawTypes,MacOsApi.Events;
{$ELSE FPC_DOTTEDUNITS}
uses MacTypes,ColorSyncDeprecated,MixedMode,QuickdrawTypes,Events;
{$ENDIF FPC_DOTTEDUNITS}
{$endc} {not MACOSALLINCLUDE}


{$ifc TARGET_OS_MAC}

{$ALIGN MAC68K}


{ These are legacy constants. The Color Picker on OS X uses the Cocoa NSColorPanel. }
const
	kDefaultColorPickerWidth = 383;
	kDefaultColorPickerHeight = 238;

type
	DialogPlacementSpec = SInt16;
const
	kAtSpecifiedOrigin = 0;
	kDeepestColorScreen = 1;
	kCenterOnMainScreen = 2;

{ Since OS X uses the Cocoa NSColorPanel, the flags below are no longer used. }
const
	kColorPickerDialogIsMoveable = 1;
	kColorPickerDialogIsModal = 2;
	kColorPickerCanModifyPalette = 4;
	kColorPickerCanAnimatePalette = 8;
	kColorPickerAppIsColorSyncAware = 16;
	kColorPickerInSystemDialog = 32;
	kColorPickerInApplicationDialog = 64;
	kColorPickerInPickerDialog = 128;
	kColorPickerDetachedFromChoices = 256;
	kColorPickerCallColorProcLive = 512;

{$ifc OLDROUTINENAMES}

const
	kDefaultWidth = 383;
	kDefaultHeight = 238;

{ Since OS X uses the Cocoa NSColorPanel, the flags below are no longer used. }
const
	DialogIsMoveable = 1;
	DialogIsModal = 2;
	CanModifyPalette = 4;
	CanAnimatePalette = 8;
	AppIsColorSyncAware = 16;
	InSystemDialog = 32;
	InApplicationDialog = 64;
	InPickerDialog = 128;
	DetachedFromChoices = 256;
	CallColorProcLive = 512;

{$endc} {OLDROUTINENAMES}


type
	NPMColor = record
		profile: CMProfileRef;
		color: CMColor;
	end;
	NPMColorPtr = ^NPMColor;
type
	Picker = ^OpaquePicker; { an opaque type }
	OpaquePicker = record end;
	PickerPtr = ^Picker;  { when a var xx:Picker parameter can be nil, it is changed to xx: PickerPtr }
{ Since OS X uses the Cocoa NSColorPanel, the struct below is no longer used. }
type
	PickerMenuItemInfoPtr = ^PickerMenuItemInfo;
	PickerMenuItemInfo = record
		editMenuID: SInt16;
		cutItem: SInt16;
		copyItem: SInt16;
		pasteItem: SInt16;
		clearItem: SInt16;
		undoItem: SInt16;
	end;
{ The following proc ptr is the only supported way to communicate with the Cocoa NSColorPanel on OS X. }
type
	NColorChangedProcPtr = procedure( userData: SRefCon; var newColor: NPMColor );
	NColorChangedUPP = NColorChangedProcPtr;
{
 *  NewNColorChangedUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewNColorChangedUPP( userRoutine: NColorChangedProcPtr ): NColorChangedUPP; external name '_NewNColorChangedUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  DisposeNColorChangedUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeNColorChangedUPP( userUPP: NColorChangedUPP ); external name '_DisposeNColorChangedUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  InvokeNColorChangedUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure InvokeNColorChangedUPP( userData: SRefCon; var newColor: NPMColor; userUPP: NColorChangedUPP ); external name '_InvokeNColorChangedUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)


type
	ColorChangedUPP = UnivPtr;
	UserEventUPP = UnivPtr;


type
	NColorPickerInfo = record
		theColor: NPMColor;
		dstProfile: CMProfileRef;             { Currently ignored }
		flags: UInt32;                  { Currently ignored }
		placeWhere: DialogPlacementSpec;            { Currently ignored }
		dialogOrigin: Point;           { Currently ignored }
		pickerType: OSType;             { Currently ignored }

		colorProc: NColorChangedUPP;
		colorProcData: URefCon;
		prompt: Str255;                 { Currently ignored }
		mInfo: PickerMenuItemInfo;                  { Ignored }
		newColorChosen: Boolean;
		reserved: UInt8;               { Must be 0 }
	end;


{
 *  GetColor()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in InterfaceLib 7.1 and later
 }
function GetColor( where: Point; const (*var*) prompt: Str255; const (*var*) inColor: RGBColor; var outColor: RGBColor ): Boolean; external name '_GetColor';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)



{
 *  NPickColor()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in ColorPickerLib 2.1 and later
 }
function NPickColor( var theColorInfo: NColorPickerInfo ): OSErr; external name '_NPickColor';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)


{$endc} {TARGET_OS_MAC}

{$ifc not defined MACOSALLINCLUDE or not MACOSALLINCLUDE}

end.
{$endc} {not MACOSALLINCLUDE}
