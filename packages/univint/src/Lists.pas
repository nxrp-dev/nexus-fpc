{
     File:       HIToolbox/Lists.h

     Contains:   List Manager Interfaces.

     Version:    HIToolbox-624~3

     Copyright:  © 1985-2008 by Apple Computer, Inc., all rights reserved

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
unit Lists;
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
uses MacOsApi.MacTypes,MacOsApi.Events,MacOsApi.QuickdrawTypes,MacOsApi.Controls,MacOsApi.HIObject;
{$ELSE FPC_DOTTEDUNITS}
uses MacTypes,Events,QuickdrawTypes,Controls,HIObject;
{$ENDIF FPC_DOTTEDUNITS}
{$endc} {not MACOSALLINCLUDE}


{$ifc TARGET_OS_MAC}

{$ALIGN MAC68K}

{
 *  List Manager
 *
 *  Discussion:
 *    The List Manager is deprecated in Mac OS X 10.5 and later, and is
 *    not included in the 64-bit version of HIToolbox. Applications
 *    should use the Data Browser instead of the List Manager.
 }
type
	Cell = Point;
	CellPtr = ^Cell;
type
	ListBounds = Rect;
	ListBoundsPtr = ^ListBounds;
	DataArray = packed array [0..32000] of AnsiChar;
type
	DataPtr = ^DataArray;
	DataHandle = ^DataPtr;
	ListSearchProcPtr = function( aPtr: Ptr; bPtr: Ptr; aLen: SInt16; bLen: SInt16 ): SInt16;
	ListClickLoopProcPtr = function: Boolean;
	ListSearchUPP = ListSearchProcPtr;
	ListClickLoopUPP = ListClickLoopProcPtr;
	ListRecPtr = ^ListRec;
	ListRec = record
		rView: Rect;                  { in Carbon use Get/SetListViewBounds}
		port: GrafPtr;                   { in Carbon use Get/SetListPort}
		indent: Point;                 { in Carbon use Get/SetListCellIndent}
		cellSize: Point;               { in Carbon use Get/SetListCellSize}
		visible: ListBounds;                { in Carbon use GetListVisibleCells}
		vScroll: ControlRef;                { in Carbon use GetListVerticalScrollBar}
		hScroll: ControlRef;                { in Carbon use GetListHorizontalScrollBar}
		selFlags: SInt8;               { in Carbon use Get/SetListSelectionFlags}
		lActive: Boolean;                { in Carbon use LActivate, GetListActive}
		lReserved: SInt8;              { not supported in Carbon }
		listFlags: SInt8;              { in Carbon use Get/SetListFlags }
		clikTime: SIGNEDLONG;               { in Carbon use Get/SetListClickTime}
		clikLoc: Point;                { in Carbon use GetListClickLocation}
		mouseLoc: Point;               { in Carbon use GetListMouseLocation}
		lClickLoop: ListClickLoopUPP;             { in Carbon use Get/SetListClickLoop}
		lastClick: Cell;              { in Carbon use SetListLastClick}
		refCon: SIGNEDLONG;                 { in Carbon use Get/SetListRefCon}
		listDefProc: Handle;            { not supported in Carbon }
		userHandle: Handle;             { in Carbon use Get/SetListUserHandle}
		dataBounds: ListBounds;             { in Carbon use GetListDataBounds}
		cells: DataHandle;                  { in Carbon use LGet/SetCell}
		maxIndex: SInt16;               { in Carbon use LGet/SetCell}
		cellArray: array [0..0] of SInt16; { in Carbon use LGet/SetCell}
	end;
type
	ListPtr = ListRecPtr;
type
	ListHandle = ^ListPtr;
{ ListRef is obsolete.  Use ListHandle. }
type
	ListRef = ListHandle;


const
{ ListRec.listFlags bits}
	lDrawingModeOffBit = 3;
	lDoVAutoscrollBit = 1;
	lDoHAutoscrollBit = 0;

const
{ ListRec.listFlags masks}
	lDrawingModeOff = 8;
	lDoVAutoscroll = 2;
	lDoHAutoscroll = 1;


const
{ ListRec.selFlags bits}
	lOnlyOneBit = 7;
	lExtendDragBit = 6;
	lNoDisjointBit = 5;
	lNoExtendBit = 4;
	lNoRectBit = 3;
	lUseSenseBit = 2;
	lNoNilHiliteBit = 1;


const
{ ListRec.selFlags masks}
  lOnlyOne = $FFFFFF80; {-128}
	lExtendDrag = 64;
	lNoDisjoint = 32;
	lNoExtend = 16;
	lNoRect = 8;
	lUseSense = 4;
	lNoNilHilite = 2;


const
{ LDEF messages}
	lInitMsg = 0;
	lDrawMsg = 1;
	lHiliteMsg = 2;
	lCloseMsg = 3;

{
   StandardIconListCellDataRec is the cell data format for
   use with the standard icon list (kListDefStandardIconType).
}
type
	StandardIconListCellDataRec = record
		iconHandle: Handle;
		font: SInt16;
		face: SInt16;
		size: SInt16;
		name: Str255;
	end;
	StandardIconListCellDataPtr = ^StandardIconListCellDataRec;


type
	ListDefProcPtr = procedure( lMessage: SInt16; lSelect: Boolean; var lRect: Rect; lCell: Cell; lDataOffset: SInt16; lDataLen: SInt16; lHandle: ListHandle );
	ListDefUPP = ListDefProcPtr;
{
 *  NewListSearchUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewListSearchUPP( userRoutine: ListSearchProcPtr ): ListSearchUPP; external name '_NewListSearchUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  NewListClickLoopUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewListClickLoopUPP( userRoutine: ListClickLoopProcPtr ): ListClickLoopUPP; external name '_NewListClickLoopUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  NewListDefUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewListDefUPP( userRoutine: ListDefProcPtr ): ListDefUPP; external name '_NewListDefUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  DisposeListSearchUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeListSearchUPP( userUPP: ListSearchUPP ); external name '_DisposeListSearchUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  DisposeListClickLoopUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeListClickLoopUPP( userUPP: ListClickLoopUPP ); external name '_DisposeListClickLoopUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  DisposeListDefUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeListDefUPP( userUPP: ListDefUPP ); external name '_DisposeListDefUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  InvokeListSearchUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function InvokeListSearchUPP( aPtr: Ptr; bPtr: Ptr; aLen: SInt16; bLen: SInt16; userUPP: ListSearchUPP ): SInt16; external name '_InvokeListSearchUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  InvokeListClickLoopUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function InvokeListClickLoopUPP( userUPP: ListClickLoopUPP ): Boolean; external name '_InvokeListClickLoopUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  InvokeListDefUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure InvokeListDefUPP( lMessage: SInt16; lSelect: Boolean; var lRect: Rect; lCell: Cell; lDataOffset: SInt16; lDataLen: SInt16; lHandle: ListHandle; userUPP: ListDefUPP ); external name '_InvokeListDefUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

const
	kListDefProcPtr = 0;
	kListDefUserProcType = kListDefProcPtr;
	kListDefStandardTextType = 1;
	kListDefStandardIconType = 2;

type
	ListDefType = UInt32;
	ListDefSpec = record
		defType: ListDefType;
		case SInt16 of
		0: (
			userProc: ListDefUPP;
			);
	end;
type
	ListDefSpecPtr = ^ListDefSpec;


{ Getters }

{$endc} {TARGET_OS_MAC}
{$ifc not defined MACOSALLINCLUDE or not MACOSALLINCLUDE}

end.
{$endc} {not MACOSALLINCLUDE}
