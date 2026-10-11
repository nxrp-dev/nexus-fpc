{
     File:       HIToolbox/MacHelp.h

     Contains:   Carbon Help Manager Interfaces.

     Version:    HIToolbox-624~3

     Copyright:  © 1998-2008 by Apple Computer, Inc., all rights reserved

     Bugs?:      For bug reports, consult the following page on
                 the World Wide Web:

                     http://bugs.freepascal.org

}
{       Pascal Translation Updated:  Peter N Lewis, <peter@stairways.com.au>, August 2005 }
{       Pascal Translation Updated:  Jonas Maebe, <jonas@freepascal.org>, October 2009 }
{       Pascal Translation Updated:  Jonas Maebe, <jonas@freepascal.org>, October 2012 }
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
unit MacHelp;
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
uses MacOsApi.MacTypes,MacOsApi.CFBase,MacOsApi.QuickdrawTypes,MacOsApi.TextEdit,MacOsApi.Controls,MacOsApi.Dialogs,MacOsApi.Events,MacOsApi.MacWindows,MacOsApi.Menus,MacOsApi.HIObject,MacOsApi.HIView;
{$ELSE FPC_DOTTEDUNITS}
uses MacTypes,CFBase,QuickdrawTypes,TextEdit,Controls,Dialogs,Events,MacWindows,Menus,HIObject,HIView;
{$ENDIF FPC_DOTTEDUNITS}
{$endc} {not MACOSALLINCLUDE}


{$ifc TARGET_OS_MAC}

{$ALIGN MAC68K}

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{ Help Manager constants, etc.                                                     }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
const
	kMacHelpVersion = $0003;

const
	kHMHelpMenuID = -16490; { Resource ID and menu ID of help menu }

type
	HMContentRequest = SInt16;
const
	kHMSupplyContent = 0;
	kHMDisposeContent = 1;


{
 *  HMContentType
 *
 *  Summary:
 *    These constants should be used in the contentType field of the
 *    HMHelpContent structure.
 }
type
	HMContentType = UInt32;
const
{
   * No help content is provided.
   }
	kHMNoContent = FourCharCode('none');

  {
   * Help content is a CFStringRef in the HMHelpContent.u.tagCFString
   * field.
   *
   * The string is automatically retained by the Help Manager when
   * provided to the HMSetControl/Window/MenuItemHelpContent APIs, and
   * automatically released when the control/window/menu is destroyed.
   * When this type of help content is provided by a
   * control/window/menu title/menu item help content proc, then the
   * string is not automatically released, but the content proc will be
   * called again later with the kHMDisposeContent message to allow
   * your application to release the string, if appropriate.
   }
	kHMCFStringContent = FourCharCode('cfst');

  {
   * Help content is a localized string loaded automatically by the
   * Help Manager using CFCopyLocalizedString. The key that identifies
   * the localized string should be placed in the
   * HMHelpContent.u.tagCFString field.
   *
   * The string is automatically retained by the Help Manager when
   * provided to the HMSetControl/Window/MenuItemHelpContent APIs, and
   * automatically released when the control/window/menu is destroyed.
   * When this type of help content is provided by a
   * control/window/menu title/menu item help content proc, then the
   * string is not automatically released, but the content proc will be
   * called again later with the kHMDisposeContent message to allow
   * your application to release the string, if appropriate.
   }
	kHMCFStringLocalizedContent = FourCharCode('cfsl');

  {
   * Help content is a Pascal string in the application's text encoding
   * in the HMHelpContent.u.tagString field.
   }
	kHMPascalStrContent = FourCharCode('pstr');

  {
   * Help content is text in the application's text encoding loaded
   * from a 'TEXT' resource. The 'TEXT' resource ID should be placed in
   * the HMHelpContent.u.tagTextRes field. This help content type is
   * available in Mac OS X 10.2 and later.
   }
	kHMTextResContent = FourCharCode('text');

  {
   * Help content is a TEHandle in the HMHelpContent.u.tagTEHandle.
   * Note that Mac OS X ignores all style information contained in the
   * TEHandle and only uses the text. This help content type is
   * available in Mac OS X 10.2 and later. It is not supported in
   * 64-bit mode.
   *
   * When this type of help content is provided to the
   * HMSetControl/Window/MenuItemHelpContent APIs, the TEHandle is
   * _not_ released when the control/window/menu is destroyed. When
   * this type of help content is provided by a control/window/menu
   * title/menu item help content proc, then the content proc will be
   * called again later with the kHMDisposeContent message to allow
   * your application to release the TEHandle, if appropriate.
   }
	kHMTEHandleContent = FourCharCode('txth');

  {
   * Help content is a Pascal string in the application's text encoding
   * loaded from a 'STR#' resource. The 'STR#' resource ID and string
   * index should be placed in the HMHelpContent.u.tagStringRes field.
   * This help content type is not supported in 64-bit mode.
   }
	kHMStringResContent = FourCharCode('str#');

  {
   * Help content is a Pascal string in the application's text encoding
   * loaded from a 'STR ' resource. The 'STR ' resource ID should be
   * placed in the HMHelpContent.u.tagStrRes field. This help content
   * type is not supported in 64-bit mode.
   }
	kHMStrResContent = FourCharCode('str ');


{
 *  HMTagDisplaySide
 *
 *  Discussion:
 *    Help tag display locations relative to absolute hot rect
 }
type
	HMTagDisplaySide = SInt16;
const
{
   * System default location
   }
	kHMDefaultSide = 0;

  {
   * Above, aligned with left or right depending on system script
   }
	kHMOutsideTopScriptAligned = 1;

  {
   * To the left, centered vertically
   }
	kHMOutsideLeftCenterAligned = 2;

  {
   * Below, aligned with left or right depending on system script
   }
	kHMOutsideBottomScriptAligned = 3;

  {
   * To the right, centered vertically
   }
	kHMOutsideRightCenterAligned = 4;

  {
   * Above, aligned with left
   }
	kHMOutsideTopLeftAligned = 5;

  {
   * Above, aligned with right
   }
	kHMOutsideTopRightAligned = 6;

  {
   * To the left, aligned with top
   }
	kHMOutsideLeftTopAligned = 7;

  {
   * To the left, aligned with bottom
   }
	kHMOutsideLeftBottomAligned = 8;

  {
   * Below, aligned with left
   }
	kHMOutsideBottomLeftAligned = 9;

  {
   * Below, aligned with right
   }
	kHMOutsideBottomRightAligned = 10;

  {
   * To the right, aligned with top
   }
	kHMOutsideRightTopAligned = 11;

  {
   * To the right, aligned with bottom
   }
	kHMOutsideRightBottomAligned = 12;

  {
   * Above, centered horizontally
   }
	kHMOutsideTopCenterAligned = 13;

  {
   * Below, centered horizontally
   }
	kHMOutsideBottomCenterAligned = 14;

  {
   * Inside, aligned with right, centered vertically
   }
	kHMInsideRightCenterAligned = 15;

  {
   * Inside, aligned with left, centered vertically
   }
	kHMInsideLeftCenterAligned = 16;

  {
   * Inside, aligned with bottom, centered horizontally
   }
	kHMInsideBottomCenterAligned = 17;

  {
   * Inside, aligned with top, centered horizontally
   }
	kHMInsideTopCenterAligned = 18;

  {
   * Inside, aligned with top and left
   }
	kHMInsideTopLeftCorner = 19;

  {
   * Inside, aligned with top and right
   }
	kHMInsideTopRightCorner = 20;

  {
   * Inside, aligned with bottom and left
   }
	kHMInsideBottomLeftCorner = 21;

  {
   * Inside, aligned with bottom and right
   }
	kHMInsideBottomRightCorner = 22;

  {
   * Centered vertically and horizontally
   }
	kHMAbsoluteCenterAligned = 23;

{ Obsoleted constants HMTagDisplaySides, use the new ones, please }
const
	kHMTopSide = kHMOutsideTopScriptAligned;
	kHMLeftSide = kHMOutsideLeftCenterAligned;
	kHMBottomSide = kHMOutsideBottomScriptAligned;
	kHMRightSide = kHMOutsideRightCenterAligned;
	kHMTopLeftCorner = kHMOutsideTopLeftAligned;
	kHMTopRightCorner = kHMOutsideTopRightAligned;
	kHMLeftTopCorner = kHMOutsideLeftTopAligned;
	kHMLeftBottomCorner = kHMOutsideLeftBottomAligned;
	kHMBottomLeftCorner = kHMOutsideBottomLeftAligned;
	kHMBottomRightCorner = kHMOutsideBottomRightAligned;
	kHMRightTopCorner = kHMOutsideRightTopAligned;
	kHMRightBottomCorner = kHMOutsideRightBottomAligned;

type
	HMContentProvidedType = SInt16;
const
	kHMContentProvided = 0;
	kHMContentNotProvided = 1;
	kHMContentNotProvidedDontPropagate = 2;

const
	kHMMinimumContentIndex = 0;    { first entry in HMHelpContentRec.content is the minimum content }
	kHMMaximumContentIndex = 1;     { second entry in HMHelpContentRec.content is the maximum content }

const
	errHMIllegalContentForMinimumState = -10980; { unrecognized content type for minimum content }
	errHMIllegalContentForMaximumState = -10981; { unrecognized content type for maximum content }

{ obsolete names; will be removed}
const
	kHMIllegalContentForMinimumState = errHMIllegalContentForMinimumState;

const
	kHelpTagEventHandlerTag = FourCharCode('hevt');

type
	HMStringResType = record
		hmmResID: SInt16;
		hmmIndex: SInt16;
	end;
type
	HMHelpContent = record
		contentType: HMContentType;
		case SInt16 of
		0: (
			tagCFString: CFStringRef;          { CFStringRef}
			);
		1: (
			tagString: Str255;          { Pascal String}
			);
		2: (
			tagStringRes: HMStringResType;          { STR# resource ID and index}
			);
		3: (
			tagTEHandle: TEHandle;          { TextEdit handle (NOT SUPPORTED ON MAC OS X)}
			);
		4: (
			tagTextRes: SInt16;          { TEXT/styl resource ID (NOT SUPPORTED ON MAC OS X)}
			);
		5: (
			tagStrRes: SInt16;          { STR resource ID}
			);
	end;
type
	HMHelpContentRec = record
		version: SInt32;
		absHotRect: Rect;
		tagSide: HMTagDisplaySide;
		content: array [0..1] of HMHelpContent;
	end;
type
	HMHelpContentPtr = ^HMHelpContentRec;

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{ Callback procs                                       }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ }
type
	HMControlContentProcPtr = function( inControl: ControlRef; inGlobalMouse: Point; inRequest: HMContentRequest; var outContentProvided: HMContentProvidedType; ioHelpContent: HMHelpContentPtr ): OSStatus;
	HMWindowContentProcPtr = function( inWindow: WindowRef; inGlobalMouse: Point; inRequest: HMContentRequest; var outContentProvided: HMContentProvidedType; ioHelpContent: HMHelpContentPtr ): OSStatus;
	HMMenuTitleContentProcPtr = function( inMenu: MenuRef; inRequest: HMContentRequest; var outContentProvided: HMContentProvidedType; ioHelpContent: HMHelpContentPtr ): OSStatus;
	HMMenuItemContentProcPtr = function( const (*var*) inTrackingData: MenuTrackingData; inRequest: HMContentRequest; var outContentProvided: HMContentProvidedType; ioHelpContent: HMHelpContentPtr ): OSStatus;
	HMControlContentUPP = HMControlContentProcPtr;
	HMWindowContentUPP = HMWindowContentProcPtr;
	HMMenuTitleContentUPP = HMMenuTitleContentProcPtr;
	HMMenuItemContentUPP = HMMenuItemContentProcPtr;
{
 *  NewHMControlContentUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewHMControlContentUPP( userRoutine: HMControlContentProcPtr ): HMControlContentUPP; external name '_NewHMControlContentUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  NewHMWindowContentUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewHMWindowContentUPP( userRoutine: HMWindowContentProcPtr ): HMWindowContentUPP; external name '_NewHMWindowContentUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  NewHMMenuTitleContentUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewHMMenuTitleContentUPP( userRoutine: HMMenuTitleContentProcPtr ): HMMenuTitleContentUPP; external name '_NewHMMenuTitleContentUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  NewHMMenuItemContentUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewHMMenuItemContentUPP( userRoutine: HMMenuItemContentProcPtr ): HMMenuItemContentUPP; external name '_NewHMMenuItemContentUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  DisposeHMControlContentUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeHMControlContentUPP( userUPP: HMControlContentUPP ); external name '_DisposeHMControlContentUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  DisposeHMWindowContentUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeHMWindowContentUPP( userUPP: HMWindowContentUPP ); external name '_DisposeHMWindowContentUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  DisposeHMMenuTitleContentUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeHMMenuTitleContentUPP( userUPP: HMMenuTitleContentUPP ); external name '_DisposeHMMenuTitleContentUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  DisposeHMMenuItemContentUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeHMMenuItemContentUPP( userUPP: HMMenuItemContentUPP ); external name '_DisposeHMMenuItemContentUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  InvokeHMControlContentUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function InvokeHMControlContentUPP( inControl: ControlRef; inGlobalMouse: Point; inRequest: HMContentRequest; var outContentProvided: HMContentProvidedType; ioHelpContent: HMHelpContentPtr; userUPP: HMControlContentUPP ): OSStatus; external name '_InvokeHMControlContentUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  InvokeHMWindowContentUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function InvokeHMWindowContentUPP( inWindow: WindowRef; inGlobalMouse: Point; inRequest: HMContentRequest; var outContentProvided: HMContentProvidedType; ioHelpContent: HMHelpContentPtr; userUPP: HMWindowContentUPP ): OSStatus; external name '_InvokeHMWindowContentUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  InvokeHMMenuTitleContentUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function InvokeHMMenuTitleContentUPP( inMenu: MenuRef; inRequest: HMContentRequest; var outContentProvided: HMContentProvidedType; ioHelpContent: HMHelpContentPtr; userUPP: HMMenuTitleContentUPP ): OSStatus; external name '_InvokeHMMenuTitleContentUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  InvokeHMMenuItemContentUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function InvokeHMMenuItemContentUPP( const (*var*) inTrackingData: MenuTrackingData; inRequest: HMContentRequest; var outContentProvided: HMContentProvidedType; ioHelpContent: HMHelpContentPtr; userUPP: HMMenuItemContentUPP ): OSStatus; external name '_InvokeHMMenuItemContentUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{ API                                                                                      }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{ Help Menu }


{
 *  Summary:
 *    Values for the inOptions parameter to HMHideTagWithOptions.
 }
const
{
   * Causes the tag to fade out when hidden. If this flag is not
   * specified, the tag is hidden without fading.
   }
	kHMHideTagFade = 1 shl 0;

  {
   * Causes the tag to begin hiding immediately. If this flag is not
   * specified, the tag is hidden after a short delay (currently 0.75
   * second).
   }
	kHMHideTagImmediately = 1 shl 1;


{$endc} {TARGET_OS_MAC}
{$ifc not defined MACOSALLINCLUDE or not MACOSALLINCLUDE}

end.
{$endc} {not MACOSALLINCLUDE}
