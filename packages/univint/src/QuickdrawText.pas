{
     File:       QD/QuickdrawText.h

     Contains:   Quickdraw Text Interfaces.

     Version:    Quickdraw-262~1

     Copyright:  © 1983-2008 by Apple Inc. all rights reserved.

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
unit QuickdrawText;
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
uses MacOsApi.MacTypes,MacOsApi.MixedMode,MacOsApi.IntlResources;
{$ELSE FPC_DOTTEDUNITS}
uses MacTypes,MixedMode,IntlResources;
{$ENDIF FPC_DOTTEDUNITS}
{$endc} {not MACOSALLINCLUDE}


{$ifc TARGET_OS_MAC}

{$ALIGN MAC68K}

{
 *  The remaining functions in this file have all been deprecated on Mac OS X 10.4. There are other
 *  solutions that are recommended that provide better compatibility with the rest of the operating
 *  system.
 *
 *  Instead of using the QuickDraw functions, you should consider the following:
 *
 *  1.  For drawing and measuring text, you can use the Appearance Manager API in HITheme.h or the
 *      ATSUI API in ATSUnicode.h to render text directly through a Quartz graphics context.
 *
 *  2.  For accessing information on fonts tracked by the operating system, please refer to the
 *      functions described in ATSFont.h.
 *
 *  3.  For accessing and modifying information on fonts in a Quartz graphics context, please refer
 *      to the functions described in CoreGraphics.h.
 }
const
{ CharToPixel directions }
	leftCaret = 0;    {Place caret for left block}
	rightCaret = -1;   {Place caret for right block}
	kHilite = 1;     {Direction is SysDirection}

const
	smLeftCaret = 0;    {Place caret for left block - obsolete }
	smRightCaret = -1;   {Place caret for right block - obsolete }
	smHilite = 1;     {Direction is TESysJust - obsolete }

{ Constants for styleRunPosition argument in PortionLine, DrawJustified, MeasureJustified, CharToPixel, and PixelToChar. }
const
	onlyStyleRun = 0;    { This is the only style run on the line }
	leftStyleRun = 1;    { This is leftmost of multiple style runs on the line }
	rightStyleRun = 2;    { This is rightmost of multiple style runs on the line }
	middleStyleRun = 3;    { There are multiple style runs on the line and this is neither the leftmost nor the rightmost. }
	smOnlyStyleRun = 0;    { obsolete }
	smLeftStyleRun = 1;    { obsolete }
	smRightStyleRun = 2;    { obsolete }
	smMiddleStyleRun = 3;     { obsolete }

{  Type for styleRunPosition parameter in PixelToChar etc. }
type
	JustStyleCode = SInt16;
{  Type for truncWhere parameter in TruncString, TruncText }
type
	TruncCode = SInt16;
{  Constants for truncWhere argument in TruncString and TruncText }
const
	truncEnd = 0;    { Truncate at end }
	truncMiddle = $4000; { Truncate in middle }
	smTruncEnd = 0;    { Truncate at end - obsolete }
	smTruncMiddle = $4000; { Truncate in middle - obsolete }

{  Constants for TruncString and TruncText results }
const
	notTruncated = 0;    { No truncation was necessary }
	truncated = 1;    { Truncation performed }
	truncErr = -1;   { General error }
	smNotTruncated = 0;    { No truncation was necessary - obsolete }
	smTruncated = 1;    { Truncation performed   - obsolete }
	smTruncErr = -1;    { General error - obsolete }

type
	StyledLineBreakCode = SInt8;
const
	smBreakWord = 0;
	smBreakChar = 1;
	smBreakOverflow = 2;

{ Constants for txFlags (which used to be the pad field after txFace) in QuickTime 3.0. }
const
	tfAntiAlias = 1 shl 0;
	tfUnicode = 1 shl 1;

type
	FontInfoPtr = ^FontInfo;
	FontInfo = record
		ascent: SInt16;
		descent: SInt16;
		widMax: SInt16;
		leading: SInt16;
	end;
type
	FormatOrder = array [0..0] of SInt16;
	FormatOrderPtr = ^FormatOrder;
{ FormatStatus was moved to TextUtils.i.}
{ OffsetTable moved to IntlResources.i.}


type
	StyleRunDirectionProcPtr = function( styleRunIndex: SInt16; dirParam: UnivPtr ): Boolean;
	StyleRunDirectionUPP = StyleRunDirectionProcPtr;
{
 *  NewStyleRunDirectionUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewStyleRunDirectionUPP( userRoutine: StyleRunDirectionProcPtr ): StyleRunDirectionUPP; external name '_NewStyleRunDirectionUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_4 *)

{
 *  DisposeStyleRunDirectionUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeStyleRunDirectionUPP( userUPP: StyleRunDirectionUPP ); external name '_DisposeStyleRunDirectionUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_4 *)

{
 *  InvokeStyleRunDirectionUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function InvokeStyleRunDirectionUPP( styleRunIndex: SInt16; dirParam: UnivPtr; userUPP: StyleRunDirectionUPP ): Boolean; external name '_InvokeStyleRunDirectionUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_4 *)




{$endc} {TARGET_OS_MAC}
{$ifc not defined MACOSALLINCLUDE or not MACOSALLINCLUDE}

end.
{$endc} {not MACOSALLINCLUDE}
