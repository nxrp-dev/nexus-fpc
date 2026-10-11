{
     File:       QD/QuickdrawAPI.h

     Contains:   API Prototypes from the former Quickdraw.i

     Version:    Quickdraw-262~1

     Copyright:  © 2005-2008 by Apple Inc. all rights reserved.

     Bugs?:      For bug reports, consult the following page on
                 the World Wide Web:

                     http://bugs.freepascal.org

}
{       Pascal Translation Updated:  Gale R Paeper, <gpaeper@empirenet.com>, 2007 }
{       Pascal Translation Updated:  Jonas Maebe, <jonas@freepascal.org>, October 2009 }
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
unit Quickdraw;
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
uses MacOsApi.MacTypes,MacOsApi.QDCMCommon,MacOsApi.QuickdrawTypes,MacOsApi.ColorSyncDeprecated,MacOsApi.CGDirectDisplay,MacOsApi.Components,MacOsApi.MixedMode,MacOsApi.QuickdrawText,MacOsApi.CGContext;
{$ELSE FPC_DOTTEDUNITS}
uses MacTypes,QDCMCommon,QuickdrawTypes,ColorSyncDeprecated,CGDirectDisplay,Components,MixedMode,QuickdrawText,CGContext;
{$ENDIF FPC_DOTTEDUNITS}
{$endc} {not MACOSALLINCLUDE}


{$ifc TARGET_OS_MAC}

{$ALIGN MAC68K}

{*********************************************************************************
// NOTE: Quickdraw has been deprecated for deployment targets 10.4 and later.
// The replacement API is Quartz (CoreGraphics).
// Because of the fundamental differences in the imaging models and design
// goals between Quickdraw and Quartz, there is no direct correspondence
// possible (or even desirable) between Quickdraw and Quartz APIs and concepts.
// For certain purposes, some Quickdraw functions may even still be needed during
// a transition period; nevertheless, they have all been tagged as deprecated
// to express the overriding goal of eliminating all Quickdraw usage in the future.
 |********************************************************************************}


{
    General comments about thread-safety of Quickdraw
    -------------------------------------------------

    The original design and implementation principles of Quickdraw seriously
    conflict with the goal of making Quickdraw thread-safe. Many Quickdraw
    functions rely on globals instead of explicit parameters. Even though the
    current port (and the current GDevice) are being maintained per-thread,
    a simple call like "MoveTo(x, y)" just doesn't make sense with preemptive threads,
    if two different threads use the same port. Also, as soon as a client replaces
    bottleneck procedures (SetStdCProcs), thread-safety is compromised.
    That's why we maintain by default the "Not thread safe" attribute in Quickdraw APIs,
    even though they may appear to be thread-safe.
}
{ Break a region up into rectangles.}

const
	kQDRegionToRectsMsgInit = 1;
	kQDRegionToRectsMsgParse = 2;
	kQDRegionToRectsMsgTerminate = 3;

const
	kQDParseRegionFromTop = 1 shl 0;
	kQDParseRegionFromBottom = 1 shl 1;
	kQDParseRegionFromLeft = 1 shl 2;
	kQDParseRegionFromRight = 1 shl 3;
	kQDParseRegionFromTopLeft = kQDParseRegionFromTop or kQDParseRegionFromLeft;
	kQDParseRegionFromBottomRight = kQDParseRegionFromBottom or kQDParseRegionFromRight;

type
	QDRegionParseDirection = SInt32;
	RegionToRectsProcPtr = function( message: UInt16; rgn: RgnHandle; const (*var*) rect_: Rect; refCon: UnivPtr ): OSStatus;
	RegionToRectsUPP = RegionToRectsProcPtr;
{
 *  NewRegionToRectsUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewRegionToRectsUPP( userRoutine: RegionToRectsProcPtr ): RegionToRectsUPP; external name '_NewRegionToRectsUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_4 *)

{
 *  DisposeRegionToRectsUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeRegionToRectsUPP( userUPP: RegionToRectsUPP ); external name '_DisposeRegionToRectsUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_4 *)

{
 *  InvokeRegionToRectsUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function InvokeRegionToRectsUPP( message: UInt16; rgn: RgnHandle; const (*var*) rect_: Rect; refCon: UnivPtr; userUPP: RegionToRectsUPP ): OSStatus; external name '_InvokeRegionToRectsUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_4 *)

{
 *  QDRegionToRects()
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   not available
 }
function QDRegionToRects( rgn: RgnHandle; dir: QDRegionParseDirection; proc: RegionToRectsUPP; userData: UnivPtr ): OSStatus; external name '_QDRegionToRects';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)



{$ifc TARGET_OS_WIN32}
{
 *  GetPortHWND()
 *
 *  Availability:
 *    Mac OS X:         not available
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   not available
 }


{
 *  GetHWNDPort()
 *
 *  Availability:
 *    Mac OS X:         not available
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   not available
 }


// #define GetPortHWND(port)  (HWND)GetPortNativeWindow(port)
// #define GetHWNDPort(theHWND) GetNativeWindowPort(theHWND)
{
 *  GetPortHDC()
 *
 *  Availability:
 *    Mac OS X:         not available
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   not available
 }


{
 *  GetPortHBITMAP()
 *
 *  Availability:
 *    Mac OS X:         not available
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   not available
 }


{
 *  GetPortHPALETTE()
 *
 *  Availability:
 *    Mac OS X:         not available
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   not available
 }


{
 *  GetPortHFONT()
 *
 *  Availability:
 *    Mac OS X:         not available
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   not available
 }


{
 *  GetDIBFromPICT()
 *
 *  Availability:
 *    Mac OS X:         not available
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   not available
 }


{
 *  GetPICTFromDIB()
 *
 *  Availability:
 *    Mac OS X:         not available
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   not available
 }


{$endc} {TARGET_OS_WIN32}


{
 *  [Mac]SetRect()
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   not available
 }
procedure MacSetRect( var r: Rect; left: SInt16; top: SInt16; right: SInt16; bottom: SInt16 ); external name '_SetRect';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)
procedure SetRect( var r: Rect; left: SInt16; top: SInt16; right: SInt16; bottom: SInt16 ); external name '_SetRect';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)


{
 *  [Mac]OffsetRect()
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   not available
 }
procedure MacOffsetRect( var r: Rect; dh: SInt16; dv: SInt16 ); external name '_OffsetRect';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)
procedure OffsetRect( var r: Rect; dh: SInt16; dv: SInt16 ); external name '_OffsetRect';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)


{
 *  [Mac]InsetRect()
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   not available
 }
procedure MacInsetRect( var r: Rect; dh: SInt16; dv: SInt16 ); external name '_InsetRect';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)
procedure InsetRect( var r: Rect; dh: SInt16; dv: SInt16 ); external name '_InsetRect';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)


{
 *  SectRect()
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   not available
 }
function SectRect( const (*var*) src1: Rect; const (*var*) src2: Rect; var dstRect: Rect ): Boolean; external name '_SectRect';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)


{
 *  [Mac]UnionRect()
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   not available
 }
procedure MacUnionRect( const (*var*) src1: Rect; const (*var*) src2: Rect; var dstRect: Rect ); external name '_UnionRect';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)
procedure UnionRect( const (*var*) src1: Rect; const (*var*) src2: Rect; var dstRect: Rect ); external name '_UnionRect';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)


{
 *  [Mac]EqualRect()
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   not available
 }
function MacEqualRect( const (*var*) rect1: Rect; const (*var*) rect2: Rect ): Boolean; external name '_EqualRect';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)
function EqualRect( const (*var*) rect1: Rect; const (*var*) rect2: Rect ): Boolean; external name '_EqualRect';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)


{
 *  EmptyRect()
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   not available
 }
function EmptyRect( const (*var*) r: Rect ): Boolean; external name '_EmptyRect';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)





{
 *  SetPt()
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   not available
 }
procedure SetPt( var pt: Point; h: SInt16; v: SInt16 ); external name '_SetPt';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)



{
 *  ScalePt()
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   not available
 }
procedure ScalePt( var pt: Point; const (*var*) srcRect: Rect; const (*var*) dstRect: Rect ); external name '_ScalePt';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)


{
 *  MapPt()
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   not available
 }
procedure MapPt( var pt: Point; const (*var*) srcRect: Rect; const (*var*) dstRect: Rect ); external name '_MapPt';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)


{
 *  MapRect()
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   not available
 }
procedure MapRect( var r: Rect; const (*var*) srcRect: Rect; const (*var*) dstRect: Rect ); external name '_MapRect';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)



{
 *  AddPt()
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   not available
 }
procedure AddPt( src: Point; var dst: Point ); external name '_AddPt';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)


{
 *  EqualPt()
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   not available
 }
function EqualPt( pt1: Point; pt2: Point ): Boolean; external name '_EqualPt';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)


{
 *  [Mac]PtInRect()
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   not available
 }
function MacPtInRect( pt: Point; const (*var*) r: Rect ): Boolean; external name '_PtInRect';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)
function PtInRect( pt: Point; const (*var*) r: Rect ): Boolean; external name '_PtInRect';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)


{
 *  Pt2Rect()
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   not available
 }
procedure Pt2Rect( pt1: Point; pt2: Point; var dstRect: Rect ); external name '_Pt2Rect';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)


{
 *  PtToAngle()
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   not available
 }
procedure PtToAngle( const (*var*) r: Rect; pt: Point; var angle: SInt16 ); external name '_PtToAngle';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)


{
 *  SubPt()
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   not available
 }
procedure SubPt( src: Point; var dst: Point ); external name '_SubPt';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)





{
    From ToolUtils.i
}

const
	colorXorXFer = 52;
	noiseXFer = 53;
	customXFer = 54;

{ Custom XFer flags }
const
	kXFer1PixelAtATime = $00000001; { 1 pixel passed to custom XFer proc}
	kXFerConvertPixelToRGB32 = $00000002; { All color depths converted to 32 bit RGB}

type
	CustomXFerRec = record
		version: UInt32;
		srcPixels: UnivPtr;
		destPixels: UnivPtr;
		resultPixels: UnivPtr;
		refCon: UInt32;
		pixelSize: UInt32;
		pixelCount: UInt32;
		firstPixelHV: Point;
		destBounds: Rect;
	end;
	CustomXFerRecPtr = ^CustomXFerRec;
type
	CustomXFerProcPtr = procedure( info: CustomXFerRecPtr );

const
	kCursorComponentsVersion = $00010001;

const
	kCursorComponentType = FourCharCode('curs');

{ Cursor Component capabilities flags }
const
	cursorDoesAnimate = 1 shl 0;
	cursorDoesHardware = 1 shl 1;
	cursorDoesUnreadableScreenBits = 1 shl 2;

{ Cursor Component output mode flags }
const
	kRenderCursorInHardware = 1 shl 0;
	kRenderCursorInSoftware = 1 shl 1;

{ Cursor Component Info }
type
	CursorInfoPtr = ^CursorInfo;
	CursorInfo = record
		version: SIGNEDLONG;                { use kCursorComponentsVersion }
		capabilities: SIGNEDLONG;
		animateDuration: SIGNEDLONG;        { approximate time between animate tickles }
		bounds: Rect;
		hotspot: Point;
		reserved: SIGNEDLONG;               { must set to zero }
	end;
{ Cursor Component Selectors }
const
	kCursorComponentInit = $0001;
	kCursorComponentGetInfo = $0002;
	kCursorComponentSetOutputMode = $0003;
	kCursorComponentSetData = $0004;
	kCursorComponentReconfigure = $0005;
	kCursorComponentDraw = $0006;
	kCursorComponentErase = $0007;
	kCursorComponentMove = $0008;
	kCursorComponentAnimate = $0009;
	kCursorComponentLastReserved = $0050;




{ GrafPort }
{ Getters }

{ Helpful Carbon-only utilities (finally made public)}


type
	QDRegionBitsRef = ^SInt32; { an opaque type }
	QDRegionBitsRefPtr = ^QDRegionBitsRef;  { when a var xx:QDRegionBitsRef parameter can be nil, it is changed to xx: QDRegionBitsRefPtr }

const
	kQDXArrowCursor = 0;
	kQDXIBeamCursor = 1;
	kQDXIBeamXORCursor = 2;
	kQDXAliasCursor = 3;
	kQDXCopyCursor = 4;
	kQDXMoveCursor = 5;
	kQDXNumberOfSystemCursors = 6;     { Must be last }


type
	QDXSystemCursorID = UInt32;

const
	kQDUseDefaultTextRendering = 0;    { Sets whatever is specified in system defaults.}
                                        { Currently sets kQDUseTrueTypeScalerGlyphs if nothing is specified.}
	kQDUseTrueTypeScalerGlyphs = 1 shl 0; { bit 0}
	kQDUseCGTextRendering = 1 shl 1; { bit 1}
	kQDUseCGTextMetrics = 1 shl 2; { bit 2}
	kQDSupportedFlags = kQDUseTrueTypeScalerGlyphs or kQDUseCGTextRendering or kQDUseCGTextMetrics;
	kQDDontChangeFlags = -1; { to request the current state, without changing anything}






{$endc} {TARGET_OS_MAC}

{$ifc not defined MACOSALLINCLUDE or not MACOSALLINCLUDE}

end.
{$endc} {not MACOSALLINCLUDE}
