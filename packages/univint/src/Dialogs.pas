{
     File:       HIToolbox/Dialogs.h

     Contains:   Dialog Manager interfaces.

     Version:    HIToolbox-624~3

     Copyright:  © 1985-2008 by Apple Computer, Inc., all rights reserved

     Bugs?:      For bug reports, consult the following page on
                 the World Wide Web:

                     http://bugs.freepascal.org

}
{       Pascal Translation Updated:  Peter N Lewis, <peter@stairways.com.au>, August 2005 }
{       Pascal Translation Updated:  Jonas Maebe, <jonas@freepascal.org>, October 2009 }
{       Pascal Translation Updated:  Gorazd Krosl, <gorazd_1957@yahoo.ca>, October 2009 }
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
unit Dialogs;
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
uses MacOsApi.MacTypes,MacOsApi.CFBase,MacOsApi.CarbonEventsCore,MacOsApi.QuickdrawTypes,MacOsApi.Events,MacOsApi.IconsCore,MacOsApi.TextEdit,MacOsApi.HIObject;
{$ELSE FPC_DOTTEDUNITS}
uses MacTypes,CFBase,CarbonEventsCore,QuickdrawTypes,Events,IconsCore,TextEdit,HIObject;
{$ENDIF FPC_DOTTEDUNITS}
{$endc} {not MACOSALLINCLUDE}


{$ifc TARGET_OS_MAC}

{$ALIGN MAC68K}

const
{ new, more standard names for dialog item types}
	kControlDialogItem = 4;
	kButtonDialogItem = kControlDialogItem or 0;
	kCheckBoxDialogItem = kControlDialogItem or 1;
	kRadioButtonDialogItem = kControlDialogItem or 2;
	kResourceControlDialogItem = kControlDialogItem or 3;
	kStaticTextDialogItem = 8;
	kEditTextDialogItem = 16;
	kIconDialogItem = 32;
	kPictureDialogItem = 64;
	kUserDialogItem = 0;
	kHelpDialogItem = 1;
	kItemDisableBit = 128;

const
{ old names for dialog item types}
	ctrlItem = 4;
	btnCtrl = 0;
	chkCtrl = 1;
	radCtrl = 2;
	resCtrl = 3;
	statText = 8;
	editText = 16;
	iconItem = 32;
	picItem = 64;
	userItem = 0;
	itemDisable = 128;

const
{ standard dialog item numbers}
	kStdOkItemIndex = 1;
	kStdCancelItemIndex = 2;    { old names}
	ok = kStdOkItemIndex;
	cancel = kStdCancelItemIndex;

const
{ standard icon resource id's    }
	kStopIcon = 0;
	kNoteIcon = 1;
	kCautionIcon = 2;    { old names}
	stopIcon = kStopIcon;
	noteIcon = kNoteIcon;
	cautionIcon = kCautionIcon;


{  Dialog Item List Manipulation Constants }
type
	DITLMethod = SInt16;
const
	overlayDITL = 0;
	appendDITLRight = 1;
	appendDITLBottom = 2;

type
	StageList = SInt16;
{ DialogPtr is obsolete. Use DialogRef instead.}
type
	DialogRef = DialogPtr;

type
	DialogTemplatePtr = ^DialogTemplate;
	DialogTemplate = record
		boundsRect: Rect;
		procID: SInt16;
		visible: Boolean;
		filler1: Boolean;
		goAwayFlag: Boolean;
		filler2: Boolean;
		refCon: SInt32;
		itemsID: SInt16;
		title: Str255;
	end;
type
	DialogTPtr = DialogTemplatePtr;
type
	DialogTHndl = ^DialogTPtr;
type
	AlertTemplatePtr = ^AlertTemplate;
	AlertTemplate = record
		boundsRect: Rect;
		itemsID: SInt16;
		stages: StageList;
	end;
type
	AlertTPtr = AlertTemplatePtr;
type
	AlertTHndl = ^AlertTPtr;
{ new type abstractions for the dialog manager }
type
	DialogItemIndexZeroBased = SInt16;
	DialogItemIndex = SInt16;
	DialogItemIndexPtr = ^DialogItemIndex;
	DialogItemType = SInt16;
	DialogItemTypePtr = ^DialogItemType;
{ dialog manager callbacks }
type
	SoundProcPtr = procedure( soundNumber: SInt16 );
	ModalFilterProcPtr = function( theDialog: DialogRef; var theEvent: EventRecord; var itemHit: DialogItemIndex ): Boolean;
{ ModalFilterYDProcPtr was previously in StandardFile.h }
type
	ModalFilterYDProcPtr = function( theDialog: DialogRef; var theEvent: EventRecord; var itemHit: SInt16; yourDataPtr: UnivPtr ): Boolean;
	UserItemProcPtr = procedure( theDialog: DialogRef; itemNo: DialogItemIndex );
	SoundUPP = SoundProcPtr;
	ModalFilterUPP = ModalFilterProcPtr;
	ModalFilterYDUPP = ModalFilterYDProcPtr;
	UserItemUPP = UserItemProcPtr;
{
 *  NewSoundUPP()
 *
 *  Availability:
 *    Mac OS X:         not available
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   available as macro/inline
 }

{
 *  NewModalFilterUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewModalFilterUPP( userRoutine: ModalFilterProcPtr ): ModalFilterUPP; external name '_NewModalFilterUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  NewModalFilterYDUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0.2 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewModalFilterYDUPP( userRoutine: ModalFilterYDProcPtr ): ModalFilterYDUPP; external name '_NewModalFilterYDUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  NewUserItemUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewUserItemUPP( userRoutine: UserItemProcPtr ): UserItemUPP; external name '_NewUserItemUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  DisposeSoundUPP()
 *
 *  Availability:
 *    Mac OS X:         not available
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   available as macro/inline
 }

{
 *  DisposeModalFilterUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeModalFilterUPP( userUPP: ModalFilterUPP ); external name '_DisposeModalFilterUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  DisposeModalFilterYDUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0.2 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeModalFilterYDUPP( userUPP: ModalFilterYDUPP ); external name '_DisposeModalFilterYDUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  DisposeUserItemUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeUserItemUPP( userUPP: UserItemUPP ); external name '_DisposeUserItemUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  InvokeSoundUPP()
 *
 *  Availability:
 *    Mac OS X:         not available
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   available as macro/inline
 }

{
 *  InvokeModalFilterUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function InvokeModalFilterUPP( theDialog: DialogRef; var theEvent: EventRecord; var itemHit: DialogItemIndex; userUPP: ModalFilterUPP ): Boolean; external name '_InvokeModalFilterUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  InvokeModalFilterYDUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0.2 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function InvokeModalFilterYDUPP( theDialog: DialogRef; var theEvent: EventRecord; var itemHit: SInt16; yourDataPtr: UnivPtr; userUPP: ModalFilterYDUPP ): Boolean; external name '_InvokeModalFilterYDUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  InvokeUserItemUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure InvokeUserItemUPP( theDialog: DialogRef; itemNo: DialogItemIndex; userUPP: UserItemUPP ); external name '_InvokeUserItemUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)


{
  —————————————————————————————————————————————————————————————————————————————————————————————————————————
    • Following types are valid with Appearance 1.0 and later
  —————————————————————————————————————————————————————————————————————————————————————————————————————————
}
const
{ Alert types to pass into StandardAlert }
	kAlertStopAlert = 0;
	kAlertNoteAlert = 1;
	kAlertCautionAlert = 2;
	kAlertPlainAlert = 3;

type
	AlertType = SInt16;
const
	kAlertDefaultOKText = -1;   { "OK"}
	kAlertDefaultCancelText = -1;   { "Cancel"}
	kAlertDefaultOtherText = -1;    { "Don't Save"}

{ StandardAlert alert button numbers }
const
	kAlertStdAlertOKButton = 1;
	kAlertStdAlertCancelButton = 2;
	kAlertStdAlertOtherButton = 3;
	kAlertStdAlertHelpButton = 4;


{
 *  Dialog feature flags
 *
 *  Summary:
 *    These feature flags can be used in a 'dlgx' resource or in the
 *    inFlags parameter to NewFeaturesDialog.
 }
const
{
   * Requests the Dialog Manager to set the dialog box’s background
   * color or pattern, and to use Appearance Manager APIs to draw the
   * dialog frame.
   }
	kDialogFlagsUseThemeBackground = 1 shl 0;

  {
   * Requests the Dialog Manager to create a root control in the dialog
   * window and establish a control embedding hierarchy. Any dialog
   * items become controls once the embedding hierarchy is established.
   }
	kDialogFlagsUseControlHierarchy = 1 shl 1;

  {
   * Requests the Dialog Manager to automatically handle movable modal
   * behavior such as dragging a dialog window by its title bar.
   }
	kDialogFlagsHandleMovableModal = 1 shl 2;

  {
   * On Mac OS 8.x and 9.x, requests the Dialog Manager to create
   * Appearance-compliant controls in the dialog window. Otherwise,
   * push buttons, checkboxes, and radio buttons are displayed in their
   * pre-Appearance forms when systemwide Appearance is off. On Mac OS
   * X, this flag is ignored; dialogs always use controls to implement
   * standard dialog items.
   }
	kDialogFlagsUseThemeControls = 1 shl 3;

  {
   * Requests the Dialog Manager to create a compositing window to
   * contain the dialog items. The window will also use the standard
   * window event handler and will have live resize enabled. Available
   * in Mac OS X 10.5 and later.
   }
	kDialogFlagsUseCompositing = 1 shl 8;


{
 *  Alert feature flags
 *
 *  Summary:
 *    These feature flags can be used in a 'alrx' resource.
 }
const
{ Alert Flags for use in alrx resource }

  {
   * Requests the Dialog Manager to set the alert’s background color or
   * pattern, and to use Appearance Manager APIs to draw the alert
   * frame.
   }
	kAlertFlagsUseThemeBackground = 1 shl 0;

  {
   * Requests the Dialog Manager to create a root control in the alert
   * window and establish a control embedding hierarchy. Any alert
   * items become controls once the embedding hierarchy is established.
   }
	kAlertFlagsUseControlHierarchy = 1 shl 1;

  {
   * Requests the Dialog Manager to make the alert window movable, and
   * to automatically handle dragging the alert by its title bar.
   }
	kAlertFlagsAlertIsMovable = 1 shl 2;

  {
   * On Mac OS 8.x and 9.x, requests the Dialog Manager to create
   * Appearance-compliant controls in the alert window. Otherwise, push
   * buttons, checkboxes, and radio buttons are displayed in their
   * pre-Appearance forms when systemwide Appearance is off. On Mac OS
   * X, this flag is ignored; alerts always use controls to implement
   * standard alert items.
   }
	kAlertFlagsUseThemeControls = 1 shl 3;

  {
   * Requests the Dialog Manager to create a compositing window to
   * contain the alert items. The window will also use the standard
   * window event handler. Available in Mac OS X 10.5 and later.
   }
	kAlertFlagsUseCompositing = 1 shl 8;

{ For dftb resource }
const
	kDialogFontNoFontStyle = 0;
	kDialogFontUseFontMask = $0001;
	kDialogFontUseFaceMask = $0002;
	kDialogFontUseSizeMask = $0004;
	kDialogFontUseForeColorMask = $0008;
	kDialogFontUseBackColorMask = $0010;
	kDialogFontUseModeMask = $0020;
	kDialogFontUseJustMask = $0040;
	kDialogFontUseAllMask = $00FF;
	kDialogFontAddFontSizeMask = $0100;
	kDialogFontUseFontNameMask = $0200;
	kDialogFontAddToMetaFontMask = $0400;

{ Also for dftb resource. This one is available in Mac OS X or later. }
{ It corresponds directly to kControlUseThemeFontIDMask from Controls.h. }
const
	kDialogFontUseThemeFontIDMask = $0080;


{
 *  AlertStdAlertParamRec
 *
 *  Summary:
 *    AlertStdCFStringAlertParamRec is preferred.
 *
 *  Discussion:
 *    As of Mac OS X 10.5, defaultButton can be the same as the
 *    cancelButton. Prior to Mac OS X 10.5, having cancelButton and
 *    defaultButton the same will cause a paramErr.
 }
type
	AlertStdAlertParamRec = record
{
   * Is the alert movable? This parameter is ignored on Mac OS X; all
   * standard alerts are movable.
   }
		movable: Boolean;

  {
   * Is there a help button?
   }
		helpButton: Boolean;

  {
   * The event filter to be used.
   }
		filterProc: ModalFilterUPP;

  {
   * Text for the button in the OK position. kAlertDefaultOKText can be
   * used for the system standard text.
   }
		defaultText: ConstStringPtr;

  {
   * Text for the button in the Cancel position.
   * kAlertDefaultCancelText can be used for the system standard text.
   }
		cancelText: ConstStringPtr;

  {
   * Text for the button in the leftmost position.
   * kAlertDefaultOtherText can be used for the system standard text.
   }
		otherText: ConstStringPtr;

  {
   * Which button is default, i.e. activated by pressing Return. Prior
   * to Mac OS X 10.5, this field must be set to a non-zero value in
   * the range kAlertStdAlertOKButton..kAlertStdAlertOtherButton, and
   * your alert will always have a default button. In Mac OS X 10.5 and
   * later, you may set this field to zero to request no default button.
   }
		defaultButton: SInt16;

  {
   * Which button is default for cancelling, i.e. activated by pressing
   * Escape. May be zero to request no cancel button; otherwise, must
   * be in the range kAlertStdAlertOKButton..kAlertStdAlertOtherButton.
   }
		cancelButton: SInt16;

  {
   * Where to position the alert. kWindowDefaultPosition is the default
   * and is equal to kWindowAlertPositionParentWindowScreen.
   }
		position: UInt16;
	end;
type
	AlertStdAlertParamRecPtr = ^AlertStdAlertParamRec;
const
	kHICommandOther = FourCharCode('othr'); { sent by standard sheet dialogs when the "other" button is pressed }


const
{
   * AlertStdCFStringAlertParamRec version prior to Mac OS X 10.5.
   }
	kStdCFStringAlertVersionOne = 1;

  {
   * AlertStdCFStringAlertParamRec version for Mac OS X 10.5 and later.
   * When using this version, you must set the icon field of the
   * structure to NULL or a valid IconRef.
   }
	kStdCFStringAlertVersionTwo = 2;


{
 *  Summary:
 *    Flags to CreateStandardAlert that are specified in the
 *    AlertStdCFStringAlertParamRec.flags field.
 }
const
{
   * Applies to StandardSheet only. Do not dispose of the sheet window
   * after closing it; allows the sheet to be re-used again in a later
   * call to ShowSheetWindow.
   }
	kStdAlertDoNotDisposeSheet = 1 shl 0;

  {
   * Applies to StandardSheet only. Causes the sheet window to be
   * hidden immediately without animation effects when the default
   * button is chosen by the user.
   }
	kStdAlertDoNotAnimateOnDefault = 1 shl 1;

  {
   * Applies to StandardSheet only. Causes the sheet window to be
   * hidden immediately without animation effects when the cancel
   * button is chosen by the user.
   }
	kStdAlertDoNotAnimateOnCancel = 1 shl 2;

  {
   * Applies to StandardSheet only. Causes the sheet window to be
   * hidden immediately without animation effects when the other button
   * is chosen by the user.
   }
	kStdAlertDoNotAnimateOnOther = 1 shl 3;

  {
   * Allows dialog to stay up even after clicking the Help button.
   * Normally, it would close immediately. It is not necessary to set
   * this option for sheets, as they merely send the HICommandHelp
   * command to the target provided. RunStandardAlert will return with
   * the help button item in the itemHit parameter, but the window will
   * remain up. You can then perform whatever help function you wish
   * and then call RunStandardAlert again. This option is available in
   * Mac OS X 10.4 or later.
   }
	kStdAlertDoNotCloseOnHelp = 1 shl 4;


{
 *  AlertStdCFStringAlertParamRec
 *
 *  Summary:
 *    A CFString variant of AlertStdAlertParamRec. CFStrings are
 *    preferred.
 *
 *  Discussion:
 *    As of Mac OS X 10.5, defaultButton can be the same as the
 *    cancelButton. Prior to Mac OS X 10.5, having cancelButton and
 *    defaultButton the same will cause a paramErr.
 }
type
	AlertStdCFStringAlertParamRec = record
{
   * The version of the structure. Prior to Mac OS X 10.5, you must use
   * kStdCFStringAlertVersionOne. In Mac OS X 10.5 or later, you may
   * use either VersionOne or VersionTwo. If you use VersionTwo, you
   * must set the icon field to NULL or a valid IconRef.
   }
		version: UInt32;

  {
   * Is the alert movable? This parameter is ignored on Mac OS X; all
   * standard alerts are movable.
   }
		movable: Boolean;

  {
   * Is there a help button?
   }
		helpButton: Boolean;

  {
   * Text for the button in the OK position.
   }
		defaultText: CFStringRef;

  {
   * Text for the button in the Cancel position.
   }
		cancelText: CFStringRef;

  {
   * Text for the button in the leftmost/help position.
   }
		otherText: CFStringRef;

  {
   * Which button is default, i.e. activated by pressing Return. Prior
   * to Mac OS X 10.5, this field must be set to a non-zero value in
   * the range kAlertStdAlertOKButton..kAlertStdAlertOtherButton, and
   * your alert will always have a default button. In Mac OS X 10.5 and
   * later, you may set this field to zero to request no default button.
   }
		defaultButton: SInt16;

  {
   * Which button is default for cancelling, i.e. activated by pressing
   * Escape. May be zero to request no cancel button; otherwise, must
   * be in the range kAlertStdAlertOKButton..kAlertStdAlertOtherButton.
   }
		cancelButton: SInt16;

  {
   * Where to position the alert. kWindowDefaultPosition is the default
   * and is equal to kWindowAlertPositionParentWindowScreen.
   }
		position: UInt16;

  {
   * Options for the behavior of the alert or sheet.
   }
		flags: OptionBits;

  {
   * Custom icon for display in the alert. Available on Mac OS X 10.5
   * and later when the version field is set to
   * kStdCFStringAlertVersionTwo.
   }
		icon: IconRef;
	end;
type
	AlertStdCFStringAlertParamPtr = ^AlertStdCFStringAlertParamRec;
{ ——— end Appearance 1.0 or later stuff}







(*
#if OLDROUTINENAMES && !__LP64__
#define DisposDialog(theDialog) DisposeDialog(theDialog)
#define UpdtDialog(theDialog, updateRgn) UpdateDialog(theDialog, updateRgn)
#define GetDItem(theDialog, itemNo, itemType, item, box) GetDialogItem(theDialog, itemNo, itemType, item, box)
#define SetDItem(theDialog, itemNo, itemType, item, box) SetDialogItem(theDialog, itemNo, itemType, item, box)
#define HideDItem(theDialog, itemNo) HideDialogItem(theDialog, itemNo)
#define ShowDItem(theDialog, itemNo) ShowDialogItem(theDialog, itemNo)
#define SelIText(theDialog, itemNo, strtSel, endSel) SelectDialogItemText(theDialog, itemNo, strtSel, endSel)
#define GetIText(item, text) GetDialogItemText(item, text)
#define SetIText(item, text) SetDialogItemText(item, text)
#define FindDItem(theDialog, thePt) FindDialogItem(theDialog, thePt)
#define NewCDialog(dStorage, boundsRect, title, visible, procID, behind, goAwayFlag, refCon, items) \
NewColorDialog(dStorage, boundsRect, title, visible, procID, behind, goAwayFlag, refCon, items)
#define GetAlrtStage() GetAlertStage()
#define ResetAlrtStage() ResetAlertStage()
#define DlgCut(theDialog) DialogCut(theDialog)
#define DlgPaste(theDialog) DialogPaste(theDialog)
#define DlgCopy(theDialog) DialogCopy(theDialog)
#define DlgDelete(theDialog) DialogDelete(theDialog)
#define SetDAFont(fontNum) SetDialogFont(fontNum)
#define SetGrafPortOfDialog(dialog) SetPortDialogPort(dialog)
#endif  { OLDROUTINENAMES }
*)

{$endc} {TARGET_OS_MAC}
{$ifc not defined MACOSALLINCLUDE or not MACOSALLINCLUDE}

end.
{$endc} {not MACOSALLINCLUDE}
