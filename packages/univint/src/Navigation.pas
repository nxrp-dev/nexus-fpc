{
     File:       NavigationServices/Navigation.h

     Contains:   Navigation Services Interfaces

     Version:    NavigationServices-200~178

     Copyright:  © 1996-2008 by Apple Computer, Inc., all rights reserved

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
unit Navigation;
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
uses MacOsApi.MacTypes,MacOsApi.AEDataModel,MacOsApi.CFBase,MacOsApi.QuickdrawTypes,MacOsApi.Finder,MacOsApi.Events,MacOsApi.AppleEvents,MacOsApi.Translation,MacOsApi.MacWindows,MacOsApi.CodeFragments,MacOsApi.MacErrors,MacOsApi.CFArray,MacOsApi.CFString;
{$ELSE FPC_DOTTEDUNITS}
uses MacTypes,AEDataModel,CFBase,QuickdrawTypes,Finder,Events,AppleEvents,Translation,MacWindows,CodeFragments,MacErrors,CFArray,CFString;
{$ENDIF FPC_DOTTEDUNITS}
{$endc} {not MACOSALLINCLUDE}


{$ifc TARGET_OS_MAC}

{$ALIGN MAC68K}


{
 *  Navigation Services
 *
 *  Discussion:
 *    In Mac OS X 10.5, Navigation Services has been reimplemented atop
 *    Cocoa's NSSavePanel. A NavDialogRef may be cast to an
 *    NSSavePanel* for put dialogs, an NSOpenPanel* for get and choose
 *    dialogs and an NSAlert* for the various ask save changes dialogs.
 *    Once cast to the appropriate Cocoa object you can call Cocoa APIs
 *    on that object normally. For instance, the custom area of the Nav
 *    dialog may be populated with Cocoa NSViews
 *    [(NSSavePanel*)myNavDialogRef setAccessoryView:myNSView].
 *    Exception: Once a dialog is created via the NavigationServices API
 *    it must be invoked with NavDialogRun. Custom preview support is
 *    no longer available on Mac OS X 10.5. NavPreview procedures are
 *    no longer called, kNavCBAdjustPreview Nav event callback messages
 *    are no longer sent and the NavCBRec previewRect field will always
 *    be empty. Navigation Services now depends on QuickLook for
 *    preview rendering. Clients may write a QuickLook plug-in to
 *    generate custom previews for open dialogs as well as Finder and
 *    Spotlight. Because a NavDialogRef is an Objective-C object
 *    underneath, -release or CFRelease may be called on it instead of
 *    NavDialogDispose.
 }
type
	NavAskSaveChangesAction = UInt32;
const
{ input action codes for NavAskSaveChanges() }
	kNavSaveChangesClosingDocument = 1;
	kNavSaveChangesQuittingApplication = 2;
	kNavSaveChangesOther = 0;


type
	NavAskSaveChangesResult = UInt32;
const
{ result codes for NavAskSaveChanges() }
	kNavAskSaveChangesSave = 1;
	kNavAskSaveChangesCancel = 2;
	kNavAskSaveChangesDontSave = 3;


type
	NavAskDiscardChangesResult = UInt32;
const
{ result codes for NavAskDiscardChanges() }
	kNavAskDiscardChanges = 1;
	kNavAskDiscardChangesCancel = 2;


type
	NavFilterModes = SInt16;
const
{ which elements are being filtered for objects: }
	kNavFilteringBrowserList = 0;
	kNavFilteringFavorites = 1;
	kNavFilteringRecents = 2;
	kNavFilteringShortCutVolumes = 3;
	kNavFilteringLocationPopup = 4;     { for v1.1 or greater }


const
	kNavFileOrFolderVersion = 1;

type
	NavFileOrFolderInfoPtr = ^NavFileOrFolderInfo;
	NavFileOrFolderInfo = record
		version: UInt16;
		isFolder: Boolean;
		visible: Boolean;
		creationDate: UInt32;
		modificationDate: UInt32;
		case SInt16 of
		0: (
			locked: Boolean;             { file is locked }
			resourceOpen: Boolean;       { resource fork is opened }
			dataOpen: Boolean;           { data fork is opened }
			reserved1: Boolean;
			dataSize: ByteCount;           { size of the data fork }
			resourceSize: ByteCount;       { size of the resource fork }
			finderInfo: FInfo;         { more file info: }
			finderXInfo: FXInfo;
		   );
		1: (
			shareable: Boolean;
			sharePoint: Boolean;
			mounted: Boolean;
			readable: Boolean;
			writeable: Boolean;
			reserved2: Boolean;
			numberOfFiles: ItemCount;
			finderDInfo: DInfo;
			finderDXInfo: DXInfo;
			folderType: OSType;         { package type, For struct version >= 1 }
			folderCreator: OSType;      { package creator, For struct version >= 1 }
			reserved3:			packed array [0..205] of AnsiChar;
		   );
	end;

	NavEventDataInfoPtr = ^NavEventDataInfo;
	NavEventDataInfo = record
		case SInt16 of
		0: (
			event: EventRecordPtr;                  { for event processing }
			);
		1: (
			param: UnivPtr;                  { points to event specific data }
			);
	end;
type
	NavEventDataPtr = ^NavEventData;
	NavEventData = record
		eventDataParms: NavEventDataInfo;         { the event data }
		itemHit: SInt16;                { the dialog item number, for v1.1 or greater }
	end;

{
 *  NavDialogRef
 *
 *  Summary:
 *    Opaque Navigation Services dialog identifier
 *
 *  Discussion:
 *    A NavDialogRef is an opaque reference to an instance of a
 *    Navigation Services dialog. A new NavDialogRef is returned from
 *    any of the NavCreate*Dialog functions and is later disposed with
 *    the NavDialogDispose function. NavDialogRef is the new name for
 *    the NavContext type, and thus when a client's event proc is
 *    called, the value of the NavCBRec.context field is the same as
 *    the NavDialogRef returned from the corresponding
 *    NavCreate*Dialog. A NavDialogRef is distinct from, and is not
 *    interchangable with, a Dialog Manager DialogRef.
 }
type
	NavDialogRef = ^__NavDialog; { an opaque type }
	__NavDialog = record end;
	NavDialogRefPtr = ^NavDialogRef;  { when a var xx:NavDialogRef parameter can be nil, it is changed to xx: NavDialogRefPtr }
{$ifc CALL_NOT_IN_CARBON}
	{	 NavContext is the old name for NavDialogRef 	}
	NavContext							= NavDialogRef;
{$endc}  {CALL_NOT_IN_CARBON}


{
 *  NavUserAction
 *
 *  Summary:
 *    Indicates an action taken by the user
 *
 *  Discussion:
 *    When the user clicks a button at the bottom of a Nav Services
 *    dialog (or makes an equivalent mouse or key gesture), a
 *    kNavCBUserAction event is sent to the client's event proc
 *    indicating which action was taken. Often, the action also
 *    dismisses the dialog. User action events are only generated when
 *    using dialogs created from a NavCreate*Dialog function. In the
 *    special case of a modeless GetFile dialog (supported only on Mac
 *    OS X), the user can option-click on the open button to keep the
 *    dialog from being dismissed, but the kNavCBUserAction event is
 *    sent so the client can get the reply record and open the selected
 *    files.
 }
type
	NavUserAction = UInt32;
const
{
   * No action taken. The dialog is still running or was terminated
   * programmatically.
   }
	kNavUserActionNone = 0;

  {
   * The user cancelled the dialog.
   }
	kNavUserActionCancel = 1;

  {
   * The user clicked the Open button in the GetFile dialog.
   }
	kNavUserActionOpen = 2;

  {
   * The user clicked the Save button in the PutFile dialog.
   }
	kNavUserActionSaveAs = 3;

  {
   * The user clicked the Choose button in the ChooseFile,
   * ChooseFolder, ChooseVolume or ChooseObject dialogs.
   }
	kNavUserActionChoose = 4;

  {
   * The user clicked the New Folder button in the New Folder dialog.
   }
	kNavUserActionNewFolder = 5;

  {
   * The user clicked the Save button in an AskSaveChanges dialog.
   }
	kNavUserActionSaveChanges = 6;

  {
   * The user clicked the Don't Save button in an AskSaveChanges dialog.
   }
	kNavUserActionDontSaveChanges = 7;

  {
   * The user clicked the Discard button in the AskDiscardChanges
   * dialog.
   }
	kNavUserActionDiscardChanges = 8;

  {
   * The user clicked the Review Unsaved button in the
   * AskReviewDocuments dialog (used only on Mac OS X).
   }
	kNavUserActionReviewDocuments = 9;

  {
   * The user clicked the Discard Changes button in the
   * AskReviewDocuments dialog (used only on Mac OS X).
   }
	kNavUserActionDiscardDocuments = 10;


const
	kNavCBRecVersion = 1;


{
 *  NavCBRec
 *
 *  Summary:
 *    A structure passed to event and preview callbacks
 *
 *  Discussion:
 *    The NavCBRec structure is passed to the client's event proc or
 *    custom preview proc. It provides information that is specific to
 *    each event type. New for Carbon: the userAction field.
 }
type
	NavCBRec = record
{
   * The version of the struct (currently 1)
   }
		version: UInt16;

  {
   * The NavDialogRef this callback with which this call is associated
   }
		context: NavDialogRef;

  {
   * The dialog's window
   }
		window: WindowRef;

  {
   * The custom control area rectangle (window coordinates)
   }
		customRect: Rect;

  {
   * The custom preview area rectangle (window coordinates)
   }
		previewRect: Rect;

  {
   * The event-specific data, including the EventRecord, if any
   }
		eventData: NavEventData;

  {
   * The action taken by the user that generated a kNavCBUserAction
   * event (Carbon dialogs only)
   }
		userAction: NavUserAction;

  {
   * Reserved for future use
   }
		reserved: array [0..217] of SInt8;
	end;
	NavCBRecPtr = ^NavCBRec;

{
 *  NavEventCallbackMessage
 *
 *  Summary:
 *    Identifies the message type being sent to the client's event proc
 }
type
	NavEventCallbackMessage = SInt32;
const
{
   * An OS event has occurred. A pointer to the EventRecord is in the
   * eventData.eventDataParms.event field of the NavCBRec.
   }
	kNavCBEvent = 0;

  {
   * Negotiate for custom control space. Client can set change the
   * customRect field in the NavCBRec to create space for a custom
   * area. Nav Services will continue to send the kNavCBCustomize
   * message until the client leaves the customRect field unchanged.
   }
	kNavCBCustomize = 1;

  {
   * This message is sent after custom area negotiation, just before
   * the dialog is made visible. Add your custom controls when you
   * receive this message.
   }
	kNavCBStart = 2;

  {
   * This is the last message sent, after the dialog has been hidden.
   }
	kNavCBTerminate = 3;

  {
   * Sent when the dialog has been resized. Check the customRect and or
   * previewRect values to see if any relayout is needed. Nav Services
   * automatically moves controls in the custom area.
   }
	kNavCBAdjustRect = 4;

  {
   * The target folder of the dialog has changed. The
   * NavCBRec.eventData.eventDataParms.param field is an AEDesc*
   * containing an descriptor of the new location (usually an FSSpec
   * or an FSRef).
   }
	kNavCBNewLocation = 5;

  {
   * The target folder has changed to the user's desktop folder.
   }
	kNavCBShowDesktop = 6;

  {
   * The user has selected or deselected a file or folder. The
   * NavCBRec.eventData.eventDataParms.param field is an AEDescList*
   * identifying the currently selected items.
   }
	kNavCBSelectEntry = 7;

  {
   * The value of the Show/Format popup menu has changed. The
   * NavCBRec.eventData.eventDataParms.param is a NavMenuItemSpec*
   * identifying the menu item selected. If the dialog was created
   * using the Carbon-only NavCreate*Dialog APIs, then the menuType
   * field of the NavMenuItemSpec is set to the index into the client's
   * CFArray of popupExtension strings (see NavDialogCreationOptions).
   * In these cases, the menuCreator field of the NavManuItemSpec is
   * set to kNavClientPopupExtensionTag. For system supplied menu items
   * it will be set to 0. A kNavCBPopupMenuSelect message is also sent
   * as the dialog opens to notify the client of the initial menu
   * setting.
   }
	kNavCBPopupMenuSelect = 8;

  {
   * Sent when the user has accepted (Open, Save, etc.).
   }
	kNavCBAccept = 9;

  {
   * Sent when the user has cancelled the dialog.
   }
	kNavCBCancel = 10;

  {
   * ** NOT SENT STARTING IN 10.5 *** The custom preview area state has
   * changed. The NavCBRec.eventData.eventDataParms.param is a Boolean*
   * set to true if the preview area is visible or false if it is not.
   }
	kNavCBAdjustPreview = 11;

  {
   * The user has taken one of the actions described in the
   * NavUserAction definition. The action may or may not dismiss the
   * dialog. The NavCBRec.userAction field indicates which action was
   * taken (Carbon dialogs only).
   }
	kNavCBUserAction = 12;

  {
   * The user has opened a folder or chosen a file. The client can
   * block navigation or dismissal by setting the appropriate action
   * state with the kNavCtlSetActionState NavCustomControl selector.
   }
	kNavCBOpenSelection = $80000000;


type
	NavCallBackUserData = UnivPtr;
{ for events and customization: }
type
	NavEventProcPtr = procedure( callBackSelector: NavEventCallbackMessage; callBackParms: NavCBRecPtr; callBackUD: UnivPtr );
{ for preview support: }
type
	NavPreviewProcPtr = function( callBackParms: NavCBRecPtr; callBackUD: UnivPtr ): Boolean;
{ filtering callback information: }
type
	NavObjectFilterProcPtr = function( var theItem: AEDesc; info: NavFileOrFolderInfoPtr; callBackUD: UnivPtr; filterMode: NavFilterModes ): Boolean;
	NavEventUPP = NavEventProcPtr;
	NavPreviewUPP = NavPreviewProcPtr;
	NavObjectFilterUPP = NavObjectFilterProcPtr;
{
 *  NewNavEventUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewNavEventUPP( userRoutine: NavEventProcPtr ): NavEventUPP; external name '_NewNavEventUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  NewNavPreviewUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewNavPreviewUPP( userRoutine: NavPreviewProcPtr ): NavPreviewUPP; external name '_NewNavPreviewUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  NewNavObjectFilterUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewNavObjectFilterUPP( userRoutine: NavObjectFilterProcPtr ): NavObjectFilterUPP; external name '_NewNavObjectFilterUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  DisposeNavEventUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeNavEventUPP( userUPP: NavEventUPP ); external name '_DisposeNavEventUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  DisposeNavPreviewUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeNavPreviewUPP( userUPP: NavPreviewUPP ); external name '_DisposeNavPreviewUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  DisposeNavObjectFilterUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeNavObjectFilterUPP( userUPP: NavObjectFilterUPP ); external name '_DisposeNavObjectFilterUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  InvokeNavEventUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure InvokeNavEventUPP( callBackSelector: NavEventCallbackMessage; callBackParms: NavCBRecPtr; callBackUD: UnivPtr; userUPP: NavEventUPP ); external name '_InvokeNavEventUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  InvokeNavPreviewUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function InvokeNavPreviewUPP( callBackParms: NavCBRecPtr; callBackUD: UnivPtr; userUPP: NavPreviewUPP ): Boolean; external name '_InvokeNavPreviewUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  InvokeNavObjectFilterUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function InvokeNavObjectFilterUPP( var theItem: AEDesc; info: UnivPtr; callBackUD: UnivPtr; filterMode: NavFilterModes; userUPP: NavObjectFilterUPP ): Boolean; external name '_InvokeNavObjectFilterUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

type
	NavCustomControlMessage = SInt32;
const
	kNavCtlShowDesktop = 0;    {    show desktop,           parms = nil }
	kNavCtlSortBy = 1;    {    sort key field,       parms->NavSortKeyField }
	kNavCtlSortOrder = 2;    {    sort order,              parms->NavSortOrder }
	kNavCtlScrollHome = 3;    {    scroll list home,       parms = nil }
	kNavCtlScrollEnd = 4;    {    scroll list end,      parms = nil }
	kNavCtlPageUp = 5;    {    page list up,          parms = nil }
	kNavCtlPageDown = 6;    {    page list down,          parms = nil }
	kNavCtlGetLocation = 7;    {    get current location,   parms<-AEDesc* }
	kNavCtlSetLocation = 8;    {    set current location,   parms->AEDesc* }
	kNavCtlGetSelection = 9;    {    get current selection,     parms<-AEDescList* }
	kNavCtlSetSelection = 10;   {    set current selection,     parms->AEDescList* }
	kNavCtlShowSelection = 11;   {    make selection visible,       parms = nil }
	kNavCtlOpenSelection = 12;   {    open view of selection,       parms = nil }
	kNavCtlEjectVolume = 13;   {    eject volume,          parms->vRefNum }
	kNavCtlNewFolder = 14;   {    create a new folder,     parms->StringPtr }
	kNavCtlCancel = 15;   {    cancel dialog,          parms = nil }
	kNavCtlAccept = 16;   {    accept dialog default,     parms = nil }
	kNavCtlIsPreviewShowing = 17;   {    query preview status,   parms<-Boolean }
	kNavCtlAddControl = 18;   {  add one control to dialog,    parms->ControlHandle }
	kNavCtlAddControlList = 19;   {    add control list to dialog,    parms->Handle (DITL rsrc) }
	kNavCtlGetFirstControlID = 20;   {    get 1st control ID,         parms<-UInt16 }
	kNavCtlSelectCustomType = 21;   {    select a custom menu item  parms->NavMenuItemSpec* }
	kNavCtlSelectAllType = 22;   {  select an "All" menu item parms->SInt16 }
	kNavCtlGetEditFileName = 23;   {    get save dlog's file name  parms<-StringPtr }
	kNavCtlSetEditFileName = 24;   {    set save dlog's file name  parms->StringPtr }
	kNavCtlSelectEditFileName = 25;   {    select save dlog file name parms->ControlEditTextSelectionRec*, v1.1 or greater }
	kNavCtlBrowserSelectAll = 26;   {  re-scan the browser list  parms = nil, v2.0 or greater }
	kNavCtlGotoParent = 27;   {  navigate to parent         parms = nil, v2.0 or greater }
	kNavCtlSetActionState = 28;   {  restrict navigation      parms->NavActionState (flags), v2.0 or greater }
	kNavCtlBrowserRedraw = 29;   {  rescan browser list      parms = nil, v2.0 or greater }
	kNavCtlTerminate = 30;    {  terminate/dismiss dialog  parms = nil, v2.0 or greater }

type
	NavActionState = UInt32;
const
	kNavNormalState = $00000000; { normal/default state }
	kNavDontOpenState = $00000001; { disallow opening files/folders }
	kNavDontSaveState = $00000002; { disallow saving files }
	kNavDontChooseState = $00000004; { disallow choosing objects }
	kNavDontNewFolderState = $00000010; { disallow creating new folders }

type
	NavPopupMenuItem = UInt16;
const
	kNavAllKnownFiles = 0;
	kNavAllReadableFiles = 1;
	kNavAllFiles = 2;

type
	NavSortKeyField = UInt16;
const
	kNavSortNameField = 0;
	kNavSortDateField = 1;


type
	NavSortOrder = UInt16;
const
	kNavSortAscending = 0;
	kNavSortDescending = 1;


type
	NavDialogOptionFlags = OptionBits;
const
	kNavDefaultNavDlogOptions = $000000E4; { use defaults for all the options }
	kNavNoTypePopup = $00000001; { don't show file type/extension popup on Open/Save }
	kNavDontAutoTranslate = $00000002; { don't automatically translate on Open }
	kNavDontAddTranslateItems = $00000004; { don't add translation choices on Open/Save }
	kNavAllFilesInPopup = $00000010; { "All Files" menu item in the type popup on Open }
	kNavAllowStationery = $00000020; { Deprecated: Not available in Mac OS X }
	kNavAllowPreviews = $00000040; { allow preview to show }
	kNavAllowMultipleFiles = $00000080; { allow multiple items to be selected }
	kNavAllowInvisibleFiles = $00000100; { allow invisible items to be shown }
	kNavDontResolveAliases = $00000200; { don't resolve aliases }
	kNavSelectDefaultLocation = $00000400; { make the default location the browser selection }
	kNavSelectAllReadableItem = $00000800; { make the dialog select "All Readable Documents" on open }
	kNavSupportPackages = $00001000; { recognize file system packages, v2.0 or greater }
	kNavAllowOpenPackages = $00002000; { allow opening of packages, v2.0 or greater }
	kNavDontAddRecents = $00004000; { don't add chosen objects to the recents list, v2.0 or greater }
	kNavDontUseCustomFrame = $00008000; { don't draw the custom area bevel frame, v2.0 or greater }
	kNavDontConfirmReplacement = $00010000; { don't show the "Replace File?" alert on save conflict, v3.0 or greater }
	kNavPreserveSaveFileExtension = $00020000; { extension in default file name is preserved between dialog invocations and initially hidden, v3.1 or greater }


type
	NavTranslationOptions = UInt32;
const
	kNavTranslateInPlace = 0;    {    translate in place, replacing translation source file (default for Save) }
	kNavTranslateCopy = 1;     {    translate to a copy of the source file (default for Open) }


const
	kNavMenuItemSpecVersion = 0;

type
	NavMenuItemSpec = record
		version: UInt16;
		menuCreator: OSType;
		menuType: OSType;
		menuItemName: Str255;
		reserved: packed array [0..244] of AnsiChar;
	end;
type
	NavMenuItemSpecArray = array [0..0] of NavMenuItemSpec;
	NavMenuItemSpecArrayPtr = ^NavMenuItemSpecArray;
	NavMenuItemSpecArrayHandle = ^NavMenuItemSpecArrayPtr;
	NavMenuItemSpecPtr = ^NavMenuItemSpec;
	NavMenuItemSpecHandle = ^NavMenuItemSpecPtr;
const
	kNavGenericSignature = FourCharCode('****');

const
	kNavClientPopupExtensionTag = FourCharCode('extn');

type
	NavTypeList = record
		componentSignature: OSType_fix;
		reserved: SInt16;
		osTypeCount: SInt16;
		osType: array [0..0] of OSType_fix;
	end;
	NavTypeListPtr = ^NavTypeList;
type
	NavTypeListHandle = ^NavTypeListPtr;
const
	kNavReplyRecordVersion = 2;


{
 *  NavReplyRecord
 *
 *  Summary:
 *    A structure describing the results of a Nav Services dialog
 *
 *  Discussion:
 *    A reply record is the result of a Nav Services file dialog. Using
 *    the older API, which is always modal, the client passes the
 *    address of a reply record when invoking the dialog. In the Carbon
 *    API, dialogs may also be window modal or modeless, so the client
 *    requests the reply record by calling NavDialogGetReply when a
 *    kNavCBUserAction event is received. Either way, a reply record
 *    should be disposed of using NavDisposeReply.
 }
type
	NavReplyRecordPtr = ^NavReplyRecord;
	NavReplyRecord = record
{
   * The version of the structure. The first public version of the
   * structure was version 0. Fields added after version 0, starting
   * with the saveFileName field, are noted below.
   }
		version: UInt16;

  {
   * True if the reply contains a non-null selection
   }
		validRecord: Boolean;

  {
   * True if this reply is from a PutFile dialog and the file to be
   * saved already exists and needs to be replaced. The user has
   * already been warned unless the kNavDontConfirmReplacement option
   * flag is used.
   }
		replacing: Boolean;

  {
   * True if this reply is from a PutFile dialog and the user wants to
   * save the file as stationery.
   }
		isStationery: Boolean;

  {
   * True if translation was performed on the file(s) to be opened or
   * if translation will be needed on the file to be saved.
   }
		translationNeeded: Boolean;

  {
   * For GetFile or Choose dialogs, a list of items chosen by the user.
   * For the older NavPutFile dialog, a list containing one item: an
   * FSSpec of the file to be saved. ** IMPORTANT NOTE *** For the new
   * Carbon-only PutFile dialog created with NavCreatePutFileDialog,
   * the selection is a list containing one item: the DIRECTORY where
   * the file is to be saved. The file name is obtained from the
   * saveFileName field. When using the original modal API, each
   * descriptor will contain an FSSpec (typeFSS). When using the new
   * Carbon-only dialogs created via the NavCreate*Dialog functions,
   * each descriptor could contain either an FSSpec (typeFSS, used on
   * Mac OS 8 or 9) or an FSRef (typeFSRef, used on Mac OS X). This
   * divergence is caused by the need to use FSRef (for Unicode/HFS+
   * support) on Mac OS X, while being unable to provide FSRefs on Mac
   * OS 8.6.
   }
		selection: AEDescList;

  {
   * For NavPutFile: the script system associated with the name of the
   * file to be saved.
   }
		keyScript: ScriptCode;

  {
   * A handle to an array of type FileTranslationSpec. Each array entry
   * corresponds to an item in the selection and describes the
   * translation that was performed (GetFile) or needs to be performed
   * (PutFile) on that item.
   }
		fileTranslation: FileTranslationSpecArrayHandle;

  {
   * Reserved for private use.
   }
		reserved1: UInt32;

  {
   * Carbon PutFile dialog only: the name of the file to be saved. This
   * field contains the true file name to saved, even if the extension
   * will be hidden from the user. This field was added in structure
   * version 1.
   }
		saveFileName: CFStringRef;

  {
   * The extension on the name of the saved file should be hidden. Once
   * the file has been saved, the client should call NavCompleteSave.
   * NavCompleteSave will take care of hiding the extension on the
   * file. However, the client needs to know that the extension is
   * hidden so that it can display the document name correctly in the
   * UI, such as in window titles and menus. This field is only used if
   * the client has r requested extension preservation using the
   * kNavPreserveSaveFileExtension dialog option flag. This field was
   * added in structure version 2.
   }
		saveFileExtensionHidden: Boolean;

  {
   * Reserved for future use.
   }
		reserved2: UInt8;

  {
   * Reserved for future use.
   }
		reserved: array [0..224] of SInt8;
	end;

{ Carbon API }
{ Includes support for Unicode and long file names (where available). }

const
	kNavDialogCreationOptionsVersion = 0;


{
 *  NavDialogCreationOptions
 *
 *  Summary:
 *    Options used to control the appearance and operation of a Nav
 *    Services dialog
 *
 *  Discussion:
 *    NavDialogCreationOptions is a preferred replacement for
 *    NavDialogOptions. The new structure uses CFStrings in place of
 *    Pascal strings, and adds fields for setting the dialog modality
 *    and the parent window (for sheet dialogs). A
 *    NavDialogCreationOptions structure can be initialized using
 *    NavGetDefaultDialogCreationOptions. Each of the NavCreate*Dialog
 *    functions accepts a pointer to the client's
 *    NavDialogCreationOptions structure.
 }
type
	NavDialogCreationOptionsPtr = ^NavDialogCreationOptions;
	NavDialogCreationOptions = record
{
   * The version of the structure. Currently, the only valid version is
   * 0, containing all the fields described here.
   }
		version: UInt16;

  {
   * Options for the dialog. See NavDialogOptionFlags for a description
   * of each option.
   }
		optionFlags: NavDialogOptionFlags;

  {
   * The screen position at which to place the upper left corner of the
   * dialog, in global coordinates. Specify (-1, -1) to use the default
   * (persistent) location. Ignored for sheet dialogs.
   }
		location: Point;

  {
   * The user-readable name of the client, usually the name of the
   * current application. This value is used to construct the default
   * window title in the file dialogs, and the message text in the Ask
   * dialogs. On Mac OS 9 and earlier, this value is used as a key to
   * store persistent per-client dialog settings, so it's always a good
   * idea to set this field to a non-NULL value.
   }
		clientName: CFStringRef;

  {
   * The custom title for the dialog window. Specify NULL to use the
   * default title.
   }
		windowTitle: CFStringRef;

  {
   * The custom label for the default (Open/Save/Choose) button.
   * Specify NULL to use the default label.
   }
		actionButtonLabel: CFStringRef;

  {
   * The custom label for the Cancel button. Specify NULL to use the
   * default label.
   }
		cancelButtonLabel: CFStringRef;

  {
   * The initial value appearing in the edit text field for the file
   * name to be saved (PutFile, NavAskSaveChanges only).
   }
		saveFileName: CFStringRef;

  {
   * For the file dialogs, a banner message appearing across the top of
   * the dialog. Specify NULL to provide no banner message. For the Ask
   * alerts, a custom message to replace the default message.
   }
		message: CFStringRef;

  {
   * A key to uniquely identify the dialog's usage context within the
   * application. If an application uses the same class of dialog (e.g.
   * GetFile or ChooseFile) for more than one purpose, set this field
   * to a unique value for each usage in order to give each dialog its
   * own persistent settings (e.g. screen rectangle, starting target
   * folder).
   }
		preferenceKey: UInt32;

  {
   * A CFArray of CFStrings. The strings are added as menu items to the
   * Show or Format popup menus in the GetFile or PutFile dialogs,
   * respectively.
   }
		popupExtension: CFArrayRef;

  {
   * The modality in which to present the dialog. The default modality
   * for all dialogs is kWindowModalityAppModal. If
   * kWindowModalityWindowModal is specified, then a valid parentWindow
   * is required.
   }
		modality: WindowModality;

  {
   * The window to which a window-modal (sheet) dialog is to be
   * attached.
   }
		parentWindow: WindowRef;

  {
   * Reserved for future use.
   }
		reserved:  array [0..15] of SInt8;
	end;

const
	kNavDialogOptionsVersion = 0;

type
	NavDialogOptionsPtr = ^NavDialogOptions;
	NavDialogOptions = record
		version: UInt16;
		dialogOptionFlags: NavDialogOptionFlags;    { option flags for affecting the dialog's behavior }
		location: Point;               { top-left location of the dialog, or (-1,-1) for default position }
		clientName: Str255;
		windowTitle: Str255;
		actionButtonLabel: Str255;      { label of the default button (or null string for default) }
		cancelButtonLabel: Str255;      { label of the cancel button (or null string for default) }
		savedFileName: Str255;          { default name for text box in NavPutFile (or null string for default) }
		message: Str255;                { custom message prompt (or null string for default) }
		preferenceKey: UInt32;          { a key for to managing preferences for using multiple utility dialogs }
		popupExtension: NavMenuItemSpecArrayHandle; { extended popup menu items, an array of NavMenuItemSpecs }
		reserved:  array [0..493] of SInt8;
	end;

{$ifc TARGET_RT_MAC_CFM}
{
        NavServicesAvailable() is a macro available only in C/C++.
        To get the same functionality from pascal or assembly, you need
        to test if NavigationLib functions are not NULL and call NavServicesCanRun()
        which will test if NavServices is properly installed.  For instance:

            gNavServicesAvailable = FALSE;
            IF @NavLibraryVersion <> kUnresolvedCFragSymbolAddress THEN
                gNavServicesAvailable = NavServicesCanRun;
            end

}
{$elsec}
  {$ifc TARGET_RT_MAC_MACHO}
{ Navigation is always available on OS X }
  {$elsec}
{  NavServicesAvailable() is implemented in Navigation.o for classic 68K clients }
  {$ifc CALL_NOT_IN_CARBON}
{ NavServicesAvailable() is implemented in Navigation.o for classic 68K clients}
{
 *  NavServicesAvailable()
 *
 *  Availability:
 *    Mac OS X:         not available
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   not available
 }

  {$endc}  {CALL_NOT_IN_CARBON}
  {$endc} {TARGET_RT_MAC_MACHO}
{$endc} {TARGET_RT_MAC_CFM}


{$endc} {TARGET_OS_MAC}

{$ifc not defined MACOSALLINCLUDE or not MACOSALLINCLUDE}

end.
{$endc} {not MACOSALLINCLUDE}
