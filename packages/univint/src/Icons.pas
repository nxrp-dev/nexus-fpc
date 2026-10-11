{
     File:       HIServices/Icons.h

     Contains:   Icon Utilities and Icon Services Interfaces.

     Version:    HIServices-416~44

     Copyright:  © 1990-2008 by Apple Computer, Inc. All rights reserved

     Bugs?:      For bug reports, consult the following page on
                 the World Wide Web:

                     http://bugs.freepascal.org

}

{  Pascal Translation Updated:  Gale R Paeper, <gpaeper@empirenet.com>, 2006 }
{  Pascal Translation Updated:  Jonas Maebe, <jonas@freepascal.org>, October 2009 }
{  Pascal Translation Updated:  Gorazd Krosl, <gorazd_1957@yahoo.ca>, October 2009 }
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
unit Icons;
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
uses MacOsApi.MacTypes,MacOsApi.CFBase,MacOsApi.CGGeometry,MacOsApi.QuickdrawTypes,MacOsApi.IconStorage,MacOsApi.IconsCore,MacOsApi.Files,MacOsApi.CGContext,MacOsApi.HIShape;
{$ELSE FPC_DOTTEDUNITS}
uses MacTypes,CFBase,CGGeometry,QuickdrawTypes,IconStorage,IconsCore,Files,CGContext,HIShape;
{$ENDIF FPC_DOTTEDUNITS}
{$endc} {not MACOSALLINCLUDE}


{$ifc TARGET_OS_MAC}

{$ALIGN MAC68K}

{ Alignment type values. }
const
	kAlignNone = $00;
	kAlignVerticalCenter = $01;
	kAlignTop = $02;
	kAlignBottom = $03;
	kAlignHorizontalCenter = $04;
	kAlignAbsoluteCenter = kAlignVerticalCenter or kAlignHorizontalCenter;
	kAlignCenterTop = kAlignTop or kAlignHorizontalCenter;
	kAlignCenterBottom = kAlignBottom or kAlignHorizontalCenter;
	kAlignLeft = $08;
	kAlignCenterLeft = kAlignVerticalCenter or kAlignLeft;
	kAlignTopLeft = kAlignTop or kAlignLeft;
	kAlignBottomLeft = kAlignBottom or kAlignLeft;
	kAlignRight = $0C;
	kAlignCenterRight = kAlignVerticalCenter or kAlignRight;
	kAlignTopRight = kAlignTop or kAlignRight;
	kAlignBottomRight = kAlignBottom or kAlignRight;

{ Obsolete. Use names defined above. }
const
	atNone = kAlignNone;
	atVerticalCenter = kAlignVerticalCenter;
	atTop = kAlignTop;
	atBottom = kAlignBottom;
	atHorizontalCenter = kAlignHorizontalCenter;
	atAbsoluteCenter = kAlignAbsoluteCenter;
	atCenterTop = kAlignCenterTop;
	atCenterBottom = kAlignCenterBottom;
	atLeft = kAlignLeft;
	atCenterLeft = kAlignCenterLeft;
	atTopLeft = kAlignTopLeft;
	atBottomLeft = kAlignBottomLeft;
	atRight = kAlignRight;
	atCenterRight = kAlignCenterRight;
	atTopRight = kAlignTopRight;
	atBottomRight = kAlignBottomRight;

type
	IconAlignmentType = SInt16;
{ Transform type values. }
const
	kTransformNone = $00;
	kTransformDisabled = $01;
	kTransformOffline = $02;
	kTransformOpen = $03;
	kTransformLabel1 = $0100;
	kTransformLabel2 = $0200;
	kTransformLabel3 = $0300;
	kTransformLabel4 = $0400;
	kTransformLabel5 = $0500;
	kTransformLabel6 = $0600;
	kTransformLabel7 = $0700;
	kTransformSelected = $4000;
	kTransformSelectedDisabled = kTransformSelected or kTransformDisabled;
	kTransformSelectedOffline = kTransformSelected or kTransformOffline;
	kTransformSelectedOpen = kTransformSelected or kTransformOpen;

{ Obsolete. Use names defined above. }
const
	ttNone = kTransformNone;
	ttDisabled = kTransformDisabled;
	ttOffline = kTransformOffline;
	ttOpen = kTransformOpen;
	ttLabel1 = kTransformLabel1;
	ttLabel2 = kTransformLabel2;
	ttLabel3 = kTransformLabel3;
	ttLabel4 = kTransformLabel4;
	ttLabel5 = kTransformLabel5;
	ttLabel6 = kTransformLabel6;
	ttLabel7 = kTransformLabel7;
	ttSelected = kTransformSelected;
	ttSelectedDisabled = kTransformSelectedDisabled;
	ttSelectedOffline = kTransformSelectedOffline;
	ttSelectedOpen = kTransformSelectedOpen;

type
	IconTransformType = SInt16;
{ Selector mask values. }
const
	kSelectorLarge1Bit = $00000001;
	kSelectorLarge4Bit = $00000002;
	kSelectorLarge8Bit = $00000004;
	kSelectorLarge32Bit = $00000008;
	kSelectorLarge8BitMask = $00000010;
	kSelectorSmall1Bit = $00000100;
	kSelectorSmall4Bit = $00000200;
	kSelectorSmall8Bit = $00000400;
	kSelectorSmall32Bit = $00000800;
	kSelectorSmall8BitMask = $00001000;
	kSelectorMini1Bit = $00010000;
	kSelectorMini4Bit = $00020000;
	kSelectorMini8Bit = $00040000;
	kSelectorHuge1Bit = $01000000;
	kSelectorHuge4Bit = $02000000;
	kSelectorHuge8Bit = $04000000;
	kSelectorHuge32Bit = $08000000;
	kSelectorHuge8BitMask = $10000000;
	kSelectorAllLargeData = $000000FF;
	kSelectorAllSmallData = $0000FF00;
	kSelectorAllMiniData = $00FF0000;
	kSelectorAllHugeData = $FF000000;
	kSelectorAll1BitData = kSelectorLarge1Bit or kSelectorSmall1Bit or kSelectorMini1Bit or kSelectorHuge1Bit;
	kSelectorAll4BitData = kSelectorLarge4Bit or kSelectorSmall4Bit or kSelectorMini4Bit or kSelectorHuge4Bit;
	kSelectorAll8BitData = kSelectorLarge8Bit or kSelectorSmall8Bit or kSelectorMini8Bit or kSelectorHuge8Bit;
	kSelectorAll32BitData = kSelectorLarge32Bit or kSelectorSmall32Bit or kSelectorHuge32Bit;
	kSelectorAllAvailableData = $FFFFFFFF;

type
	IconSelectorValue = UInt32;
{ Obsolete. Use names defined above. }
const
	svLarge1Bit = kSelectorLarge1Bit;
	svLarge4Bit = kSelectorLarge4Bit;
	svLarge8Bit = kSelectorLarge8Bit;
	svSmall1Bit = kSelectorSmall1Bit;
	svSmall4Bit = kSelectorSmall4Bit;
	svSmall8Bit = kSelectorSmall8Bit;
	svMini1Bit = kSelectorMini1Bit;
	svMini4Bit = kSelectorMini4Bit;
	svMini8Bit = kSelectorMini8Bit;
	svAllLargeData = kSelectorAllLargeData;
	svAllSmallData = kSelectorAllSmallData;
	svAllMiniData = kSelectorAllMiniData;
	svAll1BitData = kSelectorAll1BitData;
	svAll4BitData = kSelectorAll4BitData;
	svAll8BitData = kSelectorAll8BitData;
	svAllAvailableData = kSelectorAllAvailableData;

type
	IconActionProcPtr = function( theType: ResType; var theIcon: Handle; yourDataPtr: UnivPtr ): OSErr;
	IconGetterProcPtr = function( theType: ResType; yourDataPtr: UnivPtr ): Handle;
	IconActionUPP = IconActionProcPtr;
	IconGetterUPP = IconGetterProcPtr;
{
 *  NewIconActionUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewIconActionUPP( userRoutine: IconActionProcPtr ): IconActionUPP; external name '_NewIconActionUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  NewIconGetterUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
 { old name was NewIconGetterProc }
 function NewIconGetterUPP( userRoutine: IconGetterProcPtr ): IconGetterUPP; external name '_NewIconGetterUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  DisposeIconActionUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeIconActionUPP( userUPP: IconActionUPP ); external name '_DisposeIconActionUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  DisposeIconGetterUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeIconGetterUPP( userUPP: IconGetterUPP ); external name '_DisposeIconGetterUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  InvokeIconActionUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
 { old name was CallIconActionProc }
 function InvokeIconActionUPP( theType: ResType; var theIcon: Handle; yourDataPtr: UnivPtr; userUPP: IconActionUPP ): OSErr; external name '_InvokeIconActionUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  InvokeIconGetterUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function InvokeIconGetterUPP( theType: ResType; yourDataPtr: UnivPtr; userUPP: IconGetterUPP ): Handle; external name '_InvokeIconGetterUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)




{
 *  PlotIconRefFlags
 *
 *  Discussion:
 *    Flags that can be passed to the PlotIconRefInContext routine.
 }
type
	PlotIconRefFlags = UInt32;
const
{
   * Draw the icon image and alpha channel.
   }
	kPlotIconRefNormalFlags = 0;

  {
   * Only draw the alpha channel.
   }
	kPlotIconRefNoImage = 1 shl 1;

  {
   * Only draw the image.
   }
	kPlotIconRefNoMask = 1 shl 2;


{
  ==============================================================================
   Converting data structures
  ==============================================================================
}


{
   IconRefToIconFamily
   This routines returns a new IconFamily that contains the data corresponding
   to the specified IconRef.
}

{
 *  IconRefToIconFamily()
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in IconServicesLib 8.5 and later
 }
function IconRefToIconFamily( theIconRef: IconRef; whichIcons: IconSelectorValue; var iconFamily: IconFamilyHandle ): OSErr; external name '_IconRefToIconFamily';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)


{
   IconFamilyToIconSuite
   This routine transfers the data from an icon family handle into an icon suite.
}


{
 *  SetIconFamilyData()
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in IconServicesLib 8.5 and later
 }
function SetIconFamilyData( iconFamily: IconFamilyHandle; iconType: OSType; h: Handle ): OSErr; external name '_SetIconFamilyData';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)


{
   GetIconFamilyData
   Return a copy of the data in the icon family.
   The type can be one of the icon type, or 'PICT'
   The data will be returned uncompressed.
   The handle (h) will be resized as appropriate. If no data of the
   requested type is present, the handle size will be set to 0.
}

{
 *  GetIconFamilyData()
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in IconServicesLib 8.5 and later
 }
function GetIconFamilyData( iconFamily: IconFamilyHandle; iconType: OSType; h: Handle ): OSErr; external name '_GetIconFamilyData';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)


{
   PlotIconRef

   This routine plots the IconRef.  It mostly takes the same parameters as
   PlotIconSuite. Pass kIconServicesNormalUsageFlag as a default value for
   IconServicesUsageFlags.
}


{
 *  PlotIconRefInContext()
 *
 *  Discussion:
 *    This routines plots an IconRef using Quartz/CoreGraphics.
 *
 *  Mac OS X threading:
 *    Thread safe since version 10.4
 *
 *  Parameters:
 *
 *    inContext:
 *      The graphics context to use.
 *
 *    inRect:
 *      The rect to plot the icon in.
 *
 *    inAlign:
 *      The icon alignment.
 *
 *    inTransform:
 *      The icon transform.
 *
 *    inLabelColor:
 *      The icon label color.
 *
 *    inFlags:
 *      The drawing flags to use (usually kPlotIconRefNormalFlags).
 *
 *    inIconRef:
 *      The IconRef to plot.
 *
 *  Availability:
 *    Mac OS X:         in version 10.1 and later in ApplicationServices.framework
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.1 and later
 *    Non-Carbon CFM:   not available
 }
function PlotIconRefInContext( inContext: CGContextRef; const (*var*) inRect: CGRect; inAlign: IconAlignmentType; inTransform: IconTransformType; inLabelColor: RGBColorPtr; inFlags: PlotIconRefFlags; inIconRef: IconRef ): OSStatus; external name '_PlotIconRefInContext';
(* AVAILABLE_MAC_OS_X_VERSION_10_1_AND_LATER *)


{
   PtInIconRef

   This routine indicates if testPt would hit the icon designated by iconRef.
   It mostly takes the same parameters as PtInIconSuite.
   Pass kIconServicesNormalUsageFlag as a default value for IconServicesUsageFlags.
   This call is deprecated. Please use IconRefContainsCGPoint() instead.
}



{
 *  IconRefContainsCGPoint()
 *
 *  Discussion:
 *    Tests whether a specified point falls within an icon’s mask.
 *
 *  Mac OS X threading:
 *    Thread safe since version 10.5
 *
 *  Parameters:
 *
 *    testPt:
 *      A pointer to the location that IconServices tests to see
 *      whether is falls within the mask of indicated icon.
 *
 *    iconRect:
 *      A pointer to the rectangle defining the area that Icon Services
 *      uses to determine which icon is hit-tested. Use the same CGRect
 *      value as when the icon was last drawn.
 *
 *    align:
 *      A value that specifies how the indicated icon is aligned within
 *      the rectangle specified in the iconRect parameter. Use the same
 *      IconAlignmentType value as when the icon was last drawn.
 *
 *    iconServicesUsageFlags:
 *      Reserved for future use. Pass the kIconServicesNormalUsageFlag
 *      constant in this parameter.
 *
 *    theIconRef:
 *      The icon to be tested.
 *
 *  Availability:
 *    Mac OS X:         in version 10.5 and later in ApplicationServices.framework
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   not available
 }
function IconRefContainsCGPoint( const (*var*) testPt: CGPoint; const (*var*) iconRect: CGRect; align: IconAlignmentType; theIconServicesUsageFlags: IconServicesUsageFlags; theIconRef: IconRef ): Boolean; external name '_IconRefContainsCGPoint';
(* AVAILABLE_MAC_OS_X_VERSION_10_5_AND_LATER *)


{
 *  IconRefIntersectsCGRect()
 *
 *  Discussion:
 *    Tests whether a specified rectangle falls within an icon’s mask.
 *
 *  Mac OS X threading:
 *    Thread safe since version 10.5
 *
 *  Parameters:
 *
 *    testRect:
 *      A pointer to the rectangle that IconServices tests to see
 *      whether is falls within the mask of indicated icon.
 *
 *    iconRect:
 *      A pointer to the rectangle defining the area that Icon Services
 *      uses to determine which icon is hit-tested. Use the same CGRect
 *      value as when the icon was last drawn.
 *
 *    align:
 *      A value that specifies how the indicated icon is aligned within
 *      the rectangle specified in the iconRect parameter. Use the same
 *      IconAlignmentType value as when the icon was last drawn.
 *
 *    iconServicesUsageFlags:
 *      Reserved for future use. Pass the kIconServicesNormalUsageFlag
 *      constant in this parameter.
 *
 *    theIconRef:
 *      The icon to be tested.
 *
 *  Availability:
 *    Mac OS X:         in version 10.5 and later in ApplicationServices.framework
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   not available
 }
function IconRefIntersectsCGRect( const (*var*) testRect: CGRect; const (*var*) iconRect: CGRect; align: IconAlignmentType; theIconServicesUsageFlags: IconServicesUsageFlags; theIconRef: IconRef ): Boolean; external name '_IconRefIntersectsCGRect';
(* AVAILABLE_MAC_OS_X_VERSION_10_5_AND_LATER *)

{
 *  IconRefToHIShape()
 *
 *  Discussion:
 *    Converts an IconRef-derived icon into an HIShape.
 *
 *  Mac OS X threading:
 *    Thread safe since version 10.5
 *
 *  Parameters:
 *
 *    iconRect:
 *      A pointer to the rectangle defining the area that Icon Services
 *      uses as the bounding box of the region.
 *
 *    align:
 *      The value which determines how Icon Services aligns the region
 *      within the rectangle.
 *
 *    iconServicesUsageFlags:
 *      Reserved for future use. Pass the kIconServicesNormalUsageFlag
 *      constant in this parameter.
 *
 *    theIconRef:
 *      The icon to be tested.
 *
 *  Availability:
 *    Mac OS X:         in version 10.5 and later in ApplicationServices.framework
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   not available
 }
function IconRefToHIShape( const (*var*) iconRect: CGRect; align: IconAlignmentType; theIconServicesUsageFlags: IconServicesUsageFlags; theIconRef: IconRef ): HIShapeRef; external name '_IconRefToHIShape';
(* AVAILABLE_MAC_OS_X_VERSION_10_5_AND_LATER *)


{
   GetIconSizesFromIconRef

   This routine returns an IconSelectorValue indicating the depths and sizes of
   icon data which are actually available.  It takes an IconSelectorValue
   indicating which sizes/depths the caller is interested and returns an
   IconSelectorValue indicating which sizes/depths exist.

   Caution:

   This is potentially an extremely expensive call as IconServices may be forced
   to attempt fetching the data for the IconRef's sizes/depths which may result
   in hitting the local disk or even the network to obtain the data to determine
   which sizes/depths actually exist.
   Pass kIconServicesNormalUsageFlag as a default value for IconServicesUsageFlags.

   This call is deprecated. Please use IsDataAvailableInIconRef() instead.
}


{
 *  IsIconRefMaskEmpty()
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in IconServicesLib 8.5 and later
 }
function IsIconRefMaskEmpty( iconRef_: IconRef ): Boolean; external name '_IsIconRefMaskEmpty';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)


{
   GetIconRefVariant
   Icon variants allows different images to be used with different icon state.
   For example, the 'open' variant for a folder could be represented with
   an open folder.
   Given an icon ref and a desired variant, this routine returns an icon
   ref (which may be the same as the input icon ref) and a transformation
   which should be used with PlotIconRef() to render the icon appropriately.
   The returned icon ref should be used to do hit-testing.
}

{
 *  GetIconRefVariant()
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in IconServicesLib 9.0 and later
 }
function GetIconRefVariant( inIconRef: IconRef; inVariant: OSType; var outTransform: IconTransformType ): IconRef; external name '_GetIconRefVariant';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{$endc} {TARGET_OS_MAC}

{$ifc not defined MACOSALLINCLUDE or not MACOSALLINCLUDE}

end.
{$endc} {not MACOSALLINCLUDE}
