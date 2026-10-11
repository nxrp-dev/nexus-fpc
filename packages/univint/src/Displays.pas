{
     File:       QD/Displays.h

     Contains:   Display Manager Interfaces.

     Version:    Quickdraw-262~1

     Copyright:  © 1993-2008 by Apple Inc. all rights reserved.

     Bugs?:      For bug reports, consult the following page on
                 the World Wide Web:

                     http://bugs.freepascal.org

}
{   Pascal Translation Updated:  Jonas Maebe, <jonas@freepascal.org>, October 2009 }
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
unit Displays;
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
uses MacOsApi.MacTypes,MacOsApi.QuickdrawTypes,MacOsApi.ColorSyncDeprecated,MacOsApi.AEDataModel,MacOsApi.ConditionalMacros,MacOsApi.Components,MacOsApi.Video,MacOsApi.AppleEvents,MacOsApi.Events,MacOsApi.Processes,MacOsApi.Dialogs;
{$ELSE FPC_DOTTEDUNITS}
uses MacTypes,QuickdrawTypes,ColorSyncDeprecated,AEDataModel,ConditionalMacros,Components,Video,AppleEvents,Events,Processes,Dialogs;
{$ENDIF FPC_DOTTEDUNITS}
{$endc} {not MACOSALLINCLUDE}


{$ifc TARGET_OS_MAC}

{$ALIGN MAC68K}

{******************* DEPRECATION NOTICE *********************
 *
 * The DisplayMgr API is being deprecated, and should be replaced
 * by the CGDirectDisplay API in the CoreGraphics framework in
 * ApplicationServices.framework.
 *
 ************************************************************}

type
	DMProcessInfoPtr = UnivPtr;
	DMModalFilterUPP = UnivPtr;
const
{ AppleEvents Core Suite }
	kAESystemConfigNotice = FourCharCode('cnfg'); { Core Suite types }
	kAEDisplayNotice = FourCharCode('dspl');
	kAEDisplaySummary = FourCharCode('dsum');
	keyDMConfigVersion = FourCharCode('dmcv');
	keyDMConfigFlags = FourCharCode('dmcf');
	keyDMConfigReserved = FourCharCode('dmcr');
	keyDisplayID = FourCharCode('dmid');
	keyDisplayComponent = FourCharCode('dmdc');
	keyDisplayDevice = FourCharCode('dmdd');
	keyDisplayFlags = FourCharCode('dmdf');
	keyDisplayMode = FourCharCode('dmdm');
	keyDisplayModeReserved = FourCharCode('dmmr');
	keyDisplayReserved = FourCharCode('dmdr');
	keyDisplayMirroredId = FourCharCode('dmmi');
	keyDeviceFlags = FourCharCode('dddf');
	keyDeviceDepthMode = FourCharCode('dddm');
	keyDeviceRect = FourCharCode('dddr');
	keyPixMapRect = FourCharCode('dpdr');
	keyPixMapHResolution = FourCharCode('dphr');
	keyPixMapVResolution = FourCharCode('dpvr');
	keyPixMapPixelType = FourCharCode('dppt');
	keyPixMapPixelSize = FourCharCode('dpps');
	keyPixMapCmpCount = FourCharCode('dpcc');
	keyPixMapCmpSize = FourCharCode('dpcs');
	keyPixMapAlignment = FourCharCode('dppa');
	keyPixMapResReserved = FourCharCode('dprr');
	keyPixMapReserved = FourCharCode('dppr');
	keyPixMapColorTableSeed = FourCharCode('dpct');
	keySummaryMenubar = FourCharCode('dsmb');
	keySummaryChanges = FourCharCode('dsch');
	keyDisplayOldConfig = FourCharCode('dold');
	keyDisplayNewConfig = FourCharCode('dnew');

const
	dmOnlyActiveDisplays = true;
	dmAllDisplays = false;


const
{ DMSendDependentNotification notifyClass }
	kDependentNotifyClassShowCursor = FourCharCode('shcr'); { When display mgr shows a hidden cursor during an unmirror }
	kDependentNotifyClassDriverOverride = FourCharCode('ndrv'); { When a driver is overridden }
	kDependentNotifyClassDisplayMgrOverride = FourCharCode('dmgr'); { When display manager is upgraded }
	kDependentNotifyClassProfileChanged = FourCharCode('prof'); { When DMSetProfileByAVID is called }


const
{ Switch Flags }
	kNoSwitchConfirmBit = 0;    { Flag indicating that there is no need to confirm a switch to this mode }
	kDepthNotAvailableBit = 1;    { Current depth not available in new mode }
	kShowModeBit = 3;    { Show this mode even though it requires a confirm. }
	kModeNotResizeBit = 4;    { Do not use this mode to resize display (for cards that mode drives a different connector). }
	kNeverShowModeBit = 5;     { This mode should not be shown in the user interface. }

{    Summary Change Flags (sticky bits indicating an operation was performed)
    For example, moving a display then moving it back will still set the kMovedDisplayBit.
}
const
	kBeginEndConfigureBit = 0;
	kMovedDisplayBit = 1;
	kSetMainDisplayBit = 2;
	kSetDisplayModeBit = 3;
	kAddDisplayBit = 4;
	kRemoveDisplayBit = 5;
	kNewDisplayBit = 6;
	kDisposeDisplayBit = 7;
	kEnabledDisplayBit = 8;
	kDisabledDisplayBit = 9;
	kMirrorDisplayBit = 10;
	kUnMirrorDisplayBit = 11;


const
{ Notification Messages for extended call back routines }
	kDMNotifyRequestConnectionProbe = 0;  { Like kDMNotifyRequestDisplayProbe only not for smart displays (used in wake before all busses are awake) }
	kDMNotifyInstalled = 1;    { At install time }
	kDMNotifyEvent = 2;    { Post change time }
	kDMNotifyRemoved = 3;    { At remove time }
	kDMNotifyPrep = 4;    { Pre change time }
	kDMNotifyExtendEvent = 5;    { Allow registrees to extend apple event before it is sent }
	kDMNotifyDependents = 6;    { Minor notification check without full update }
	kDMNotifySuspendConfigure = 7;    { Temporary end of configuration }
	kDMNotifyResumeConfigure = 8;    { Resume configuration }
	kDMNotifyRequestDisplayProbe = 9;    { Request smart displays re-probe (used in sleep and hot plugging) }
	kDMNotifyDisplayWillSleep = 10;   { Mac OS X only }
	kDMNotifyDisplayDidWake = 11;   { Mac OS X only }
                                        { Notification Flags }
	kExtendedNotificationProc = 1 shl 16;


{ types for notifyType }
const
	kFullNotify = 0;    { This is the appleevent whole nine yards notify }
	kFullDependencyNotify = 1;     { Only sends to those who want to know about interrelated functionality (used for updating UI) }

{ DisplayID/DeviceID constants }
const
	kDummyDeviceID = $00FF; { This is the ID of the dummy display, used when the last ÒrealÓ display is disabled.}
	kInvalidDisplayID = $0000; { This is the invalid ID}
	kFirstDisplayID = $0100;

const
{ bits for panelListFlags }
	kAllowDuplicatesBit = 0;

const
{ bits for nameFlags }
	kSuppressNumberBit = 0;
	kSuppressNumberMask = 1;
	kForceNumberBit = 1;
	kForceNumberMask = 2;
	kSuppressNameBit = 2;
	kSuppressNameMask = 4;

{ DMGetNameByAVID masks}
const
	kDMSupressNumbersMask = 1 shl 0; { Supress the numbers and return only names}
	kDMForceNumbersMask = 1 shl 1; { Force numbers to always be shown (even on single display configs)}
	kDMSupressNameMask = 1 shl 2; { Supress the names and return only numbers.}


{ Constants for fidelity checks }
const
	kNoFidelity = 0;
	kMinimumFidelity = 1;
	kDefaultFidelity = 500;  { I'm just picking a number for Apple default panels and engines}
	kDefaultManufacturerFidelity = 1000;  { I'm just picking a number for Manufacturer's panels and engines (overrides apple defaults)}

const
	kAnyPanelType = 0;    { Pass to DMNewEngineList for list of all panels (as opposed to specific types)}
	kAnyEngineType = 0;    { Pass to DMNewEngineList for list of all engines}
	kAnyDeviceType = 0;    { Pass to DMNewDeviceList for list of all devices}
	kAnyPortType = 0;     { Pass to DMNewDevicePortList for list of all devices}

{ portListFlags for DM_NewDevicePortList }
const
{ Should offline devices be put into the port list (such as dummy display) }
	kPLIncludeOfflineDevicesBit = 0;


{ confirmFlags for DMConfirmConfiguration }
const
	kForceConfirmBit = 0;    { Force a confirm dialog }
	kForceConfirmMask = 1 shl kForceConfirmBit;


{ Flags for displayModeFlags }
const
	kDisplayModeListNotPreferredBit = 0;
	kDisplayModeListNotPreferredMask = 1 shl kDisplayModeListNotPreferredBit;


{ Flags for itemFlags }
const
	kComponentListNotPreferredBit = 0;
	kComponentListNotPreferredMask = 1 shl kComponentListNotPreferredBit;

const
	kDisplayTimingInfoVersionZero = 1;
	kDisplayTimingInfoReservedCountVersionZero = 16;
	kDisplayModeEntryVersionZero = 0;    { displayModeVersion - original version}
	kDisplayModeEntryVersionOne = 1;     { displayModeVersion - added displayModeOverrideInfo}


const
	kMakeAndModelReservedCount = 4;     { Number of reserved fields}


{ Display Gestalt for DMDisplayGestalt}
const
	kDisplayGestaltDisplayCommunicationAttr = FourCharCode('comm');
	kDisplayGestaltForbidI2CMask = 1 shl 0; { Some displays have firmware problems if they get I2C communication.  If this bit is set, then I2C communication is forbidden}
	kDisplayGestaltUseI2CPowerMask = 1 shl 1; { Some displays require I2C power settings (most use DPMS).}
	kDisplayGestaltCalibratorAttr = FourCharCode('cali');
	kDisplayGestaltBrightnessAffectsGammaMask = 1 shl 0; { Used by default calibrator (should we show brightness panel) }
	kDisplayGestaltViewAngleAffectsGammaMask = 1 shl 1; { Currently not used by color sync}


type
	DMFidelityType = UInt32;
{
   AVID is an ID for ports and devices the old DisplayID type
    is carried on for compatibility
}


type
	DMListType = UnivPtr;
	DMListIndexType = UInt32;
	AVPowerStateRec = VDPowerStateRec;
	AVPowerStateRecPtr = ^AVPowerStateRec;
	AVPowerStatePtr = VDPowerStateRecPtr;
	DMDisplayTimingInfoRecPtr = ^DMDisplayTimingInfoRec;
	DMDisplayTimingInfoRec = record
		timingInfoVersion: UInt32;
		timingInfoAttributes: UInt32;   { Flags }
		timingInfoRelativeQuality: SInt32; { quality of the timing }
		timingInfoRelativeDefault: SInt32; { relative default of the timing }

		timingInfoReserved: array [0..15] of UInt32;
	end;
type
	DMDisplayTimingInfoPtr = ^DMDisplayTimingInfoRec;

type
	DMComponentListEntryRecPtr = ^DMComponentListEntryRec;
	DMComponentListEntryRec = record
		itemID: DisplayIDType;                 { DisplayID Manager}
		itemComponent: Component;          { Component Manager}
		itemDescription: ComponentDescription;      { We can always construct this if we use something beyond the component mgr.}

		itemClass: ResType;              { Class of group to put this panel (eg geometry/color/etc for panels, brightness/contrast for engines, video out/sound/etc for devices)}
		itemFidelity: DMFidelityType;           { How good is this item for the specified search?}
		itemSubClass: ResType;           { Subclass of group to put this panel.  Can use to do sub-grouping (eg volume for volume panel and mute panel)}
		itemSort: Point;               { Set to 0 - future to sort the items in a sub group.}

		itemFlags: UInt32;              { Set to 0 (future expansion)}
		itemReserved: ResType;           { What kind of code does the itemReference point to  (right now - kPanelEntryTypeComponentMgr only)}
		itemFuture1: UInt32;            { Set to 0 (future expansion - probably an alternate code style)}
		itemFuture2: UInt32;            { Set to 0 (future expansion - probably an alternate code style)}
		itemFuture3: UInt32;            { Set to 0 (future expansion - probably an alternate code style)}
		itemFuture4: UInt32;            { Set to 0 (future expansion - probably an alternate code style)}
	end;
type
	DMComponentListEntryPtr = DMComponentListEntryRecPtr;
{ ¥¥¥ Move AVLocationRec to AVComponents.i AFTER AVComponents.i is created}
type
	AVLocationRecPtr = ^AVLocationRec;
	AVLocationRec = record
		locationConstant: UInt32;       { Set to 0 (future expansion - probably an alternate code style)}
	end;
type
	AVLocationPtr = AVLocationRecPtr;
	DMDepthInfoRecPtr = ^DMDepthInfoRec;
	DMDepthInfoRec = record
		depthSwitchInfo: VDSwitchInfoPtr;        { This is the switch mode to choose this timing/depth }
		depthVPBlock: VPBlockPtr;           { VPBlock (including size, depth and format) }
		depthFlags: UInt32;             { VDVideoParametersInfoRec.csDepthFlags  }
		depthReserved1: UInt32;         { Reserved }
		depthReserved2: UInt32;         { Reserved }
	end;
type
	DMDepthInfoPtr = DMDepthInfoRecPtr;
	DMDepthInfoBlockRecPtr = ^DMDepthInfoBlockRec;
	DMDepthInfoBlockRec = record
		depthBlockCount: UInt32;        { How many depths are there? }
		depthVPBlock: DMDepthInfoPtr;           { Array of DMDepthInfoRec }
		depthBlockFlags: UInt32;        { Reserved }
		depthBlockReserved1: UInt32;    { Reserved }
		depthBlockReserved2: UInt32;    { Reserved }
	end;
type
	DMDepthInfoBlockPtr = DMDepthInfoBlockRecPtr;
	DMDisplayModeListEntryRecPtr = ^DMDisplayModeListEntryRec;
	DMDisplayModeListEntryRec = record
		displayModeFlags: UInt32;
		displayModeSwitchInfo: VDSwitchInfoPtr;
		displayModeResolutionInfo: VDResolutionInfoPtr;
		displayModeTimingInfo: VDTimingInfoPtr;
		displayModeDepthBlockInfo: DMDepthInfoBlockPtr; { Information about all the depths}
		displayModeVersion: UInt32;     { What version is this record (now kDisplayModeEntryVersionOne)}
		displayModeName: StringPtr;        { Name of the timing mode}
		displayModeDisplayInfo: DMDisplayTimingInfoPtr; { Information from the display.}
	end;
type
	DMDisplayModeListEntryPtr = DMDisplayModeListEntryRecPtr;

type
	DependentNotifyRecPtr = ^DependentNotifyRec;
	DependentNotifyRec = record
		notifyType: ResType;             { What type was the engine that made the change (may be zero)}
		notifyClass: ResType;            { What class was the change (eg geometry, color etc)}
		notifyPortID: DisplayIDType;           { Which device was touched (kInvalidDisplayID -> all or none)}
		notifyComponent: ComponentInstance;        { What engine did it (may be 0)?}

		notifyVersion: UInt32;          { Set to 0 (future expansion)}
		notifyFlags: UInt32;            { Set to 0 (future expansion)}
		notifyReserved: UInt32;         { Set to 0 (future expansion)}
		notifyFuture: UInt32;           { Set to 0 (future expansion)}
	end;
type
	DependentNotifyPtr = DependentNotifyRecPtr;

type
	DMMakeAndModelRecPtr = ^DMMakeAndModelRec;
	DMMakeAndModelRec = record
		manufacturer: ResType;
		model: UInt32;
		serialNumber: UInt32;
		manufactureDate: UInt32;

		makeReserved: array [0..3] of UInt32;
	end;
type
	DMMakeAndModelPtr = DMMakeAndModelRecPtr;
{ DMNewDisplayList displayListIncludeFlags}
const
	kIncludeOnlineActiveDisplaysMask = 1 shl 0;
	kIncludeOnlineDisabledDisplaysMask = 1 shl 1;
	kIncludeOfflineDisplaysMask = 1 shl 2;
	kIncludeOfflineDummyDisplaysMask = 1 shl 3;
	kIncludeHardwareMirroredDisplaysMask = 1 shl 4;


const
{ modeListFlags for DMNewDisplayModeList }
	kDMModeListIncludeAllModesMask = 1 shl 0; { Include all timing modes not _explicitly_ excluded (see other bits)}
	kDMModeListIncludeOfflineModesMask = 1 shl 1;
	kDMModeListExcludeDriverModesMask = 1 shl 2; { Exclude old-style timing modes (cscGetNextResolution/kDisplayModeIDFindFirstResolution modes)}
	kDMModeListExcludeDisplayModesMask = 1 shl 3; { Exclude timing modes that come from the display (always arbitrary timing modes)}
	kDMModeListExcludeCustomModesMask = 1 shl 4; { Exclude custom modes that came neither from the driver or display (need a better name)}
	kDMModeListPreferStretchedModesMask = 1 shl 5; { Prefer modes that are stretched over modes that are letterboxed when setting kDisplayModeListNotPreferredBit}
	kDMModeListPreferSafeModesMask = 1 shl 6; { Prefer modes that are safe over modes that are not when setting kDisplayModeListNotPreferredBit}


{ DMNewDisplayList displayListFlags}
type
	DisplayListEntryRecPtr = ^DisplayListEntryRec;
	DisplayListEntryRec = record
		displayListEntryGDevice: GDHandle;
		displayListEntryDisplayID: DisplayIDType;
		displayListEntryIncludeFlags: UInt32; { Reason this entry was included}
		displayListEntryReserved1: UInt32;

		displayListEntryReserved2: UInt32; { Zero}
		displayListEntryReserved3: UInt32; { Zero}
		displayListEntryReserved4: UInt32; { Zero}
		displayListEntryReserved5: UInt32; { Zero}
	end;
type
	DisplayListEntryPtr = DisplayListEntryRecPtr;
	DMProfileListEntryRecPtr = ^DMProfileListEntryRec;
	DMProfileListEntryRec = record
		profileRef: UnivPtr;             { was CMProfileRef}
		profileReserved1: Ptr;       { Reserved}
		profileReserved2: Ptr;       { Reserved}
		profileReserved3: Ptr;       { Reserved}
	end;
type
	DMProfileListEntryPtr = DMProfileListEntryRecPtr;
	DMNotificationProcPtr = procedure( var theEvent: AppleEvent );
	DMExtendedNotificationProcPtr = procedure( userData: UnivPtr; theMessage: SInt16; notifyData: UnivPtr );
	DMComponentListIteratorProcPtr = procedure( userData: UnivPtr; itemIndex: DMListIndexType; componentInfo: DMComponentListEntryPtr );
	DMDisplayModeListIteratorProcPtr = procedure( userData: UnivPtr; itemIndex: DMListIndexType; displaymodeInfo: DMDisplayModeListEntryPtr );
	DMProfileListIteratorProcPtr = procedure( userData: UnivPtr; itemIndex: DMListIndexType; profileInfo: DMProfileListEntryPtr );
	DMDisplayListIteratorProcPtr = procedure( userData: UnivPtr; itemIndex: DMListIndexType; displaymodeInfo: DisplayListEntryPtr );
	DMNotificationUPP = DMNotificationProcPtr;
	DMExtendedNotificationUPP = DMExtendedNotificationProcPtr;
	DMComponentListIteratorUPP = DMComponentListIteratorProcPtr;
	DMDisplayModeListIteratorUPP = DMDisplayModeListIteratorProcPtr;
	DMProfileListIteratorUPP = DMProfileListIteratorProcPtr;
	DMDisplayListIteratorUPP = DMDisplayListIteratorProcPtr;
{
 *  NewDMNotificationUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewDMNotificationUPP( userRoutine: DMNotificationProcPtr ): DMNotificationUPP; external name '_NewDMNotificationUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_4 *)

{
 *  NewDMExtendedNotificationUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewDMExtendedNotificationUPP( userRoutine: DMExtendedNotificationProcPtr ): DMExtendedNotificationUPP; external name '_NewDMExtendedNotificationUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_4 *)

{
 *  NewDMComponentListIteratorUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewDMComponentListIteratorUPP( userRoutine: DMComponentListIteratorProcPtr ): DMComponentListIteratorUPP; external name '_NewDMComponentListIteratorUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_4 *)

{
 *  NewDMDisplayModeListIteratorUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewDMDisplayModeListIteratorUPP( userRoutine: DMDisplayModeListIteratorProcPtr ): DMDisplayModeListIteratorUPP; external name '_NewDMDisplayModeListIteratorUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_4 *)

{
 *  NewDMProfileListIteratorUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewDMProfileListIteratorUPP( userRoutine: DMProfileListIteratorProcPtr ): DMProfileListIteratorUPP; external name '_NewDMProfileListIteratorUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_4 *)

{
 *  NewDMDisplayListIteratorUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewDMDisplayListIteratorUPP( userRoutine: DMDisplayListIteratorProcPtr ): DMDisplayListIteratorUPP; external name '_NewDMDisplayListIteratorUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_4 *)

{
 *  DisposeDMNotificationUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeDMNotificationUPP( userUPP: DMNotificationUPP ); external name '_DisposeDMNotificationUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_4 *)

{
 *  DisposeDMExtendedNotificationUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeDMExtendedNotificationUPP( userUPP: DMExtendedNotificationUPP ); external name '_DisposeDMExtendedNotificationUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_4 *)

{
 *  DisposeDMComponentListIteratorUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeDMComponentListIteratorUPP( userUPP: DMComponentListIteratorUPP ); external name '_DisposeDMComponentListIteratorUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_4 *)

{
 *  DisposeDMDisplayModeListIteratorUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeDMDisplayModeListIteratorUPP( userUPP: DMDisplayModeListIteratorUPP ); external name '_DisposeDMDisplayModeListIteratorUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_4 *)

{
 *  DisposeDMProfileListIteratorUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeDMProfileListIteratorUPP( userUPP: DMProfileListIteratorUPP ); external name '_DisposeDMProfileListIteratorUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_4 *)

{
 *  DisposeDMDisplayListIteratorUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeDMDisplayListIteratorUPP( userUPP: DMDisplayListIteratorUPP ); external name '_DisposeDMDisplayListIteratorUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_4 *)

{
 *  InvokeDMNotificationUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure InvokeDMNotificationUPP( var theEvent: AppleEvent; userUPP: DMNotificationUPP ); external name '_InvokeDMNotificationUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_4 *)

{
 *  InvokeDMExtendedNotificationUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure InvokeDMExtendedNotificationUPP( userData: UnivPtr; theMessage: SInt16; notifyData: UnivPtr; userUPP: DMExtendedNotificationUPP ); external name '_InvokeDMExtendedNotificationUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_4 *)

{
 *  InvokeDMComponentListIteratorUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure InvokeDMComponentListIteratorUPP( userData: UnivPtr; itemIndex: DMListIndexType; componentInfo: DMComponentListEntryPtr; userUPP: DMComponentListIteratorUPP ); external name '_InvokeDMComponentListIteratorUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_4 *)

{
 *  InvokeDMDisplayModeListIteratorUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure InvokeDMDisplayModeListIteratorUPP( userData: UnivPtr; itemIndex: DMListIndexType; displaymodeInfo: DMDisplayModeListEntryPtr; userUPP: DMDisplayModeListIteratorUPP ); external name '_InvokeDMDisplayModeListIteratorUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_4 *)

{
 *  InvokeDMProfileListIteratorUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure InvokeDMProfileListIteratorUPP( userData: UnivPtr; itemIndex: DMListIndexType; profileInfo: DMProfileListEntryPtr; userUPP: DMProfileListIteratorUPP ); external name '_InvokeDMProfileListIteratorUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_4 *)

{
 *  InvokeDMDisplayListIteratorUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure InvokeDMDisplayListIteratorUPP( userData: UnivPtr; itemIndex: DMListIndexType; displaymodeInfo: DisplayListEntryPtr; userUPP: DMDisplayListIteratorUPP ); external name '_InvokeDMDisplayListIteratorUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_4 *)


{$endc} {TARGET_OS_MAC}
{$ifc not defined MACOSALLINCLUDE or not MACOSALLINCLUDE}

end.
{$endc} {not MACOSALLINCLUDE}
