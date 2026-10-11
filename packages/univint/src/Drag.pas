{
     File:       HIToolbox/Drag.h

     Contains:   Drag and Drop Interfaces.

     Version:    HIToolbox-624~3

     Copyright:  © 1992-2008 by Apple Computer, Inc., all rights reserved.

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
unit Drag;
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
uses MacOsApi.MacTypes,MacOsApi.AEDataModel,MacOsApi.CGImage,MacOsApi.CGGeometry,MacOsApi.Events,MacOsApi.Files,MacOsApi.AppleEvents,MacOsApi.QuickdrawTypes,MacOsApi.Pasteboard,MacOsApi.HIGeometry;
{$ELSE FPC_DOTTEDUNITS}
uses MacTypes,AEDataModel,CGImage,CGGeometry,Events,Files,AppleEvents,QuickdrawTypes,Pasteboard,HIGeometry;
{$ENDIF FPC_DOTTEDUNITS}
{$endc} {not MACOSALLINCLUDE}


{$ifc TARGET_OS_MAC}

{$ALIGN MAC68K}

{
  _________________________________________________________________________________________________________

   ¥ DRAG MANAGER DATA TYPES
  _________________________________________________________________________________________________________
}
type
	DragRef = ^OpaqueDragRef; { an opaque type }
	OpaqueDragRef = record end;
	DragRefPtr = ^DragRef;  { when a var xx:DragRef parameter can be nil, it is changed to xx: DragRefPtr }
	DragItemRef = URefCon;
	FlavorType = OSType;
{
  _________________________________________________________________________________________________________

   ¥ DRAG ATTRIBUTES
  _________________________________________________________________________________________________________
}
type
	DragAttributes = OptionBits;
const
	kDragHasLeftSenderWindow = 1 shl 0; { drag has left the source window since TrackDrag}
	kDragInsideSenderApplication = 1 shl 1; { drag is occurring within the sender application}
	kDragInsideSenderWindow = 1 shl 2; { drag is occurring within the sender window}

{
  _________________________________________________________________________________________________________

   ¥ DRAG BEHAVIORS
  _________________________________________________________________________________________________________
}

type
	DragBehaviors = OptionBits;
const
	kDragBehaviorNone = 0;
	kDragBehaviorZoomBackAnimation = 1 shl 0; { do zoomback animation for failed drags (normally enabled).}

{
  _________________________________________________________________________________________________________

   ¥ DRAG IMAGE FLAGS
  _________________________________________________________________________________________________________
}


{
 *  DragImageFlags
 *
 *  Summary:
 *    Parameters to SetDragImage and SetDragImageWithCGImage.
 }
type
	DragImageFlags = OptionBits;
const
{
   * Indicates that the outline region passed to TrackDrag should be
   * drawn onscreen, in addition to the translucent drag image. Do not
   * set this flag when passing your own drag reference to
   * HIWindowTrackProxyDrag.
   }
	kDragRegionAndImage = 1 shl 4;

  {
   * Indicates that the image and offset being passed in are already at
   * device resolution, and the image should be drawn as-is. If this
   * option is not specified, the image will be scaled according to the
   * user's current scaling factor. Available in Mac OS X 10.4 and
   * later.
   }
	kDragDoNotScaleImage = 1 shl 5;

{
  _________________________________________________________________________________________________________

   ¥ DRAG IMAGE TRANSLUCENCY LEVELS
  _________________________________________________________________________________________________________
}

const
	kDragStandardTranslucency = 0;    { 65% image translucency (standard)}
	kDragDarkTranslucency = 1;    { 50% image translucency}
	kDragDarkerTranslucency = 2;    { 25% image translucency}
	kDragOpaqueTranslucency = 3;     { 0% image translucency (opaque)}

{
  _________________________________________________________________________________________________________

   ¥ FLAVOR FLAGS
  _________________________________________________________________________________________________________
}

type
	FlavorFlags = UInt32;
const
	flavorSenderOnly = 1 shl 0; { flavor is available to sender only}
	flavorSenderTranslated = 1 shl 1; { flavor is translated by sender}
	flavorNotSaved = 1 shl 2; { flavor should not be saved}
	flavorSystemTranslated = 1 shl 8; { flavor is translated by system}
	flavorDataPromised = 1 shl 9; { flavor data is promised by sender}

{
  _________________________________________________________________________________________________________

   ¥ FLAVORS FOR FINDER 8.0 AND LATER
  _________________________________________________________________________________________________________
}

const
	kFlavorTypeClippingName = FourCharCode('clnm'); { name hint for clipping file (preferred over 'clfn')}
	kFlavorTypeClippingFilename = FourCharCode('clfn'); { name for clipping file}
	kFlavorTypeUnicodeClippingName = FourCharCode('ucln'); { unicode name hint for clipping file (preferred over 'uclf')}
	kFlavorTypeUnicodeClippingFilename = FourCharCode('uclf'); { unicode name for clipping file}
	kFlavorTypeDragToTrashOnly = FourCharCode('fdtt'); { for apps that want to allow dragging private data to the trash}
	kFlavorTypeFinderNoTrackingBehavior = FourCharCode('fntb'); { Finder completely ignores any drag containing this flavor}

{
  _________________________________________________________________________________________________________

   ¥ DRAG ACTIONS
  _________________________________________________________________________________________________________
}

type
	DragActions = OptionBits;

{
 *  Summary:
 *    Drag Action constants
 *
 *  Discussion:
 *    The following constants define, in a general way, what actions a
 *    drag should or has performed.  Some drag actions enforce a mode
 *    of operation while others are flexible suggestions.  These
 *    constants are used in conjunction with the
 *    Get/SetDragAllowableActions() and Get/SetDragDropAction() APIs.
 *    Adopting the Drag Action APIs increases compatibility with the
 *    Cocoa drag operation model.
 }
const
{
   * Suggests nothing should be/was done with the data in a drag.  When
   * set as an allowable action for remote drags, the drag will not be
   * sent to apps other than the sender.
   }
	kDragActionNothing = 0;

  {
   * Suggests the data contained within the drag can be/was copied.
   }
	kDragActionCopy = 1;

  {
   * Suggests the data contained within the drag can be/is shared.
   }
	kDragActionAlias = 1 shl 1;

  {
   * Suggests the drag action is can be defined by the drag destination
   * or was not defined by the drag destination.
   }
	kDragActionGeneric = 1 shl 2;

  {
   * Suggests the drag action should be negotiated privately between
   * the drag source and destination.
   }
	kDragActionPrivate = 1 shl 3;

  {
   * Description forthcoming.
   }
	kDragActionMove = 1 shl 4;

  {
   * Description forthcoming.
   }
	kDragActionDelete = 1 shl 5;

  {
   * All of the above drag actions are allowed.
   }
	kDragActionAll = $FFFFFFFF;

{
  _________________________________________________________________________________________________________

   ¥ PROVIDING CALLBACK PROCEDURES
  _________________________________________________________________________________________________________
}

type
	DragInputProcPtr = function( var mouse: Point; var modifiers: SInt16; dragInputRefCon: UnivPtr; theDrag: DragRef ): OSErr;
	DragInputUPP = DragInputProcPtr;
{
 *  NewDragInputUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewDragInputUPP( userRoutine: DragInputProcPtr ): DragInputUPP; external name '_NewDragInputUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  DisposeDragInputUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeDragInputUPP( userUPP: DragInputUPP ); external name '_DisposeDragInputUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  InvokeDragInputUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function InvokeDragInputUPP( var mouse: Point; var modifiers: SInt16; dragInputRefCon: UnivPtr; theDrag: DragRef; userUPP: DragInputUPP ): OSErr; external name '_InvokeDragInputUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)


const
	kDragFlavorTypeHFS = FourCharCode('hfs '); { flavor type for HFS data}
	kDragFlavorTypePromiseHFS = FourCharCode('phfs'); { flavor type for promised HFS data}
	flavorTypeHFS = kDragFlavorTypeHFS; { old name}
	flavorTypePromiseHFS = kDragFlavorTypePromiseHFS; { old name}

const
	kDragPromisedFlavorFindFile = FourCharCode('rWm1'); { promisedFlavor value for Find File}
	kDragPromisedFlavor = FourCharCode('fssP'); { promisedFlavor value for everything else}

const
	kDragPseudoCreatorVolumeOrDirectory = FourCharCode('MACS'); { "creator code" for volume or directory}
	kDragPseudoFileTypeVolume = FourCharCode('disk'); { "file type" for volume}
	kDragPseudoFileTypeDirectory = FourCharCode('fold'); { "file type" for directory}

{
   The file dragging constants and structures have been deprecated in Leopard. Use kUTTypeFileURL,
   kPasteboardTypeFileURLPromise and kPasteboardTypeFilePromiseContent from UTCoreTypes.h and Pasteboard.h instead.
}

type
	HFSFlavorPtr = ^HFSFlavor;
	HFSFlavor = record
		fileType: OSType;               { file type }
		fileCreator: OSType;            { file creator }
		fdFlags: UInt16;                { Finder flags }
		fileSpec: FSSpec;               { file system specification }
	end;
type
	PromiseHFSFlavorPtr = ^PromiseHFSFlavor;
	PromiseHFSFlavor = record
		fileType: OSType;               { file type }
		fileCreator: OSType;            { file creator }
		fdFlags: UInt16;                { Finder flags }
		promisedFlavor: FlavorType;         { promised flavor containing an FSSpec }
	end;
type
	DragTrackingMessage = SInt16;
const
	kDragTrackingEnterHandler = 1;    { drag has entered handler}
	kDragTrackingEnterWindow = 2;    { drag has entered window}
	kDragTrackingInWindow = 3;    { drag is moving within window}
	kDragTrackingLeaveWindow = 4;    { drag has exited window}
	kDragTrackingLeaveHandler = 5;     { drag has exited handler}


type
	DragRegionMessage = SInt16;
const
	kDragRegionBegin = 1;    { initialize drawing}
	kDragRegionDraw = 2;    { draw drag feedback}
	kDragRegionHide = 3;    { hide drag feedback}
	kDragRegionIdle = 4;    { drag feedback idle time}
	kDragRegionEnd = 5;     { end of drawing}


type
	ZoomAcceleration = SInt16;
const
	kZoomNoAcceleration = 0;    { use linear interpolation}
	kZoomAccelerate = 1;    { ramp up step size}
	kZoomDecelerate = 2;     { ramp down step size}


{
 *  Summary:
 *    Standard Drop Location constants
 *
 *  Discussion:
 *    The following constants define common "meta" drop locations.
 }
const
{
   * The drop location was in the trash.  This is set when a drag is
   * dropped on the trash icon.  Setting this standard drop location
   * sets the traditional drop location to an alias to the trash folder
   * automatically.
   }
	kDragStandardDropLocationTrash = FourCharCode('trsh');

  {
   * The receiver did not specify a drop lcoation. This is the default.
   }
	kDragStandardDropLocationUnknown = FourCharCode('unkn');


type
	StandardDropLocation = OSType;
	DragSendDataProcPtr = function( theType: FlavorType; dragSendRefCon: UnivPtr; theItemRef: DragItemRef; theDrag: DragRef ): OSErr;
	DragTrackingHandlerProcPtr = function( message: DragTrackingMessage; theWindow: WindowRef; handlerRefCon: UnivPtr; theDrag: DragRef ): OSErr;
	DragReceiveHandlerProcPtr = function( theWindow: WindowRef; handlerRefCon: UnivPtr; theDrag: DragRef ): OSErr;
	DragDrawingProcPtr = function( message: DragRegionMessage; showRegion: RgnHandle; showOrigin: Point; hideRegion: RgnHandle; hideOrigin: Point; dragDrawingRefCon: UnivPtr; theDrag: DragRef ): OSErr;
	DragSendDataUPP = DragSendDataProcPtr;
	DragTrackingHandlerUPP = DragTrackingHandlerProcPtr;
	DragReceiveHandlerUPP = DragReceiveHandlerProcPtr;
	DragDrawingUPP = DragDrawingProcPtr;
{
 *  NewDragSendDataUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewDragSendDataUPP( userRoutine: DragSendDataProcPtr ): DragSendDataUPP; external name '_NewDragSendDataUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  NewDragTrackingHandlerUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewDragTrackingHandlerUPP( userRoutine: DragTrackingHandlerProcPtr ): DragTrackingHandlerUPP; external name '_NewDragTrackingHandlerUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  NewDragReceiveHandlerUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewDragReceiveHandlerUPP( userRoutine: DragReceiveHandlerProcPtr ): DragReceiveHandlerUPP; external name '_NewDragReceiveHandlerUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  NewDragDrawingUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewDragDrawingUPP( userRoutine: DragDrawingProcPtr ): DragDrawingUPP; external name '_NewDragDrawingUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  DisposeDragSendDataUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeDragSendDataUPP( userUPP: DragSendDataUPP ); external name '_DisposeDragSendDataUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  DisposeDragTrackingHandlerUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeDragTrackingHandlerUPP( userUPP: DragTrackingHandlerUPP ); external name '_DisposeDragTrackingHandlerUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  DisposeDragReceiveHandlerUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeDragReceiveHandlerUPP( userUPP: DragReceiveHandlerUPP ); external name '_DisposeDragReceiveHandlerUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  DisposeDragDrawingUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeDragDrawingUPP( userUPP: DragDrawingUPP ); external name '_DisposeDragDrawingUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  InvokeDragSendDataUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function InvokeDragSendDataUPP( theType: FlavorType; dragSendRefCon: UnivPtr; theItemRef: DragItemRef; theDrag: DragRef; userUPP: DragSendDataUPP ): OSErr; external name '_InvokeDragSendDataUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  InvokeDragTrackingHandlerUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function InvokeDragTrackingHandlerUPP( message: DragTrackingMessage; theWindow: WindowRef; handlerRefCon: UnivPtr; theDrag: DragRef; userUPP: DragTrackingHandlerUPP ): OSErr; external name '_InvokeDragTrackingHandlerUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  InvokeDragReceiveHandlerUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function InvokeDragReceiveHandlerUPP( theWindow: WindowRef; handlerRefCon: UnivPtr; theDrag: DragRef; userUPP: DragReceiveHandlerUPP ): OSErr; external name '_InvokeDragReceiveHandlerUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  InvokeDragDrawingUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function InvokeDragDrawingUPP( message: DragRegionMessage; showRegion: RgnHandle; showOrigin: Point; hideRegion: RgnHandle; hideOrigin: Point; dragDrawingRefCon: UnivPtr; theDrag: DragRef; userUPP: DragDrawingUPP ): OSErr; external name '_InvokeDragDrawingUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)


type
	DragReference = DragRef;
	ItemReference = DragItemRef;
(*
#if OLDROUTINENAMES
const
	dragHasLeftSenderWindow = kDragHasLeftSenderWindow; { drag has left the source window since TrackDrag }
	dragInsideSenderApplication = kDragInsideSenderApplication; { drag is occurring within the sender application }
	dragInsideSenderWindow = kDragInsideSenderWindow; { drag is occurring within the sender window }

const
	dragTrackingEnterHandler = kDragTrackingEnterHandler; { drag has entered handler }
	dragTrackingEnterWindow = kDragTrackingEnterWindow; { drag has entered window }
	dragTrackingInWindow = kDragTrackingInWindow; { drag is moving within window }
	dragTrackingLeaveWindow = kDragTrackingLeaveWindow; { drag has exited window }
	dragTrackingLeaveHandler = kDragTrackingLeaveHandler; { drag has exited handler }

const
	dragRegionBegin = kDragRegionBegin; { initialize drawing }
	dragRegionDraw = kDragRegionDraw; { draw drag feedback }
	dragRegionHide = kDragRegionHide; { hide drag feedback }
	dragRegionIdle = kDragRegionIdle; { drag feedback idle time }
	dragRegionEnd = kDragRegionEnd; { end of drawing }

const
	zoomNoAcceleration = kZoomNoAcceleration; { use linear interpolation }
	zoomAccelerate = kZoomAccelerate; { ramp up step size }
	zoomDecelerate = kZoomDecelerate; { ramp down step size }

const
	kDragStandardImage = kDragStandardTranslucency; { 65% image translucency (standard)}
	kDragDarkImage = kDragDarkTranslucency; { 50% image translucency}
	kDragDarkerImage = kDragDarkerTranslucency; { 25% image translucency}
	kDragOpaqueImage = kDragOpaqueTranslucency; { 0% image translucency (opaque)}

#endif  { OLDROUTINENAMES }
*)

{$endc} {TARGET_OS_MAC}
{$ifc not defined MACOSALLINCLUDE or not MACOSALLINCLUDE}

end.
{$endc} {not MACOSALLINCLUDE}
