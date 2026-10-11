{
     File:       HIToolbox/HISlider.h

     Contains:   API and type definitions related to HISlider.

     Version:    HIToolbox-624~3

     Copyright:  © 1999-2008 by Apple Computer, Inc., all rights reserved.

     Bugs?:      For bug reports, consult the following page on
                 the World Wide Web:

                     http://bugs.freepascal.org

}
{       Initial Pascal Translation:  Jonas Maebe, <jonas@freepascal.org>, October 2009 }
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
unit HISlider;
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
uses MacOsApi.MacTypes,MacOsApi.HIView,MacOsApi.MacWindows,MacOsApi.Controls,MacOsApi.QuickdrawTypes,MacOsApi.HIObject;
{$ELSE FPC_DOTTEDUNITS}
uses MacTypes,HIView,MacWindows,Controls,QuickdrawTypes,HIObject;
{$ENDIF FPC_DOTTEDUNITS}
{$endc} {not MACOSALLINCLUDE}


{$ifc TARGET_OS_MAC}

{$ALIGN POWER}


{
 *  Discussion:
 *    There are several variants that control the behavior of the
 *    slider control. Any combination of the following three constants
 *    can be added to the basic CDEF ID (kSliderProc).
 *
 *    Mac OS X has a "Scroll to here" option in the General pane of
 *    System Preferences which allows users to click in the page
 *    up/down regions of a slider and have the thumb/indicator jump
 *    directly to the clicked position, which alters the value of the
 *    slider and moves any associated content appropriately. As long as
 *    the mouse button is held down, the click is treated as though the
 *    user had clicked in the thumb/indicator in the first place.
 *
 *
 *    If you want the sliders in your application to work with the
 *    "Scroll to here" option, you must do the following:
 *
 *    1. Create live-tracking sliders, not sliders that show a "ghost"
 *    thumb when you click on it. You can request live-tracking sliders
 *    by passing true in the liveTracking parameter to
 *    CreateSliderControl. If you create sliders with NewControl, use
 *    the kControlSliderLiveFeedback variant.
 *
 *    2. Write an appropriate ControlActionProc and associate it with
 *    your slider via the SetControlAction API. This allows your
 *    application to update its content appropriately when the
 *    live-tracking slider is clicked.
 *
 *    3. When calling HandleControlClick or TrackControl, pass -1 in
 *    the action proc parameter. This is a request for the Control
 *    Manager to use the action proc you associated with your control
 *    in step 2. If you rely on the standard window event handler to do
 *    your control tracking, this step is handled for you automatically.
 }
const
	kControlSliderProc = 48;
	kControlSliderLiveFeedback = 1 shl 0;
	kControlSliderHasTickMarks = 1 shl 1;
	kControlSliderReverseDirection = 1 shl 2;
	kControlSliderNonDirectional = 1 shl 3;


{
 *  ControlSliderOrientation
 *
 *  Discussion:
 *    Slider Orientation
 }
type
	ControlSliderOrientation = UInt16;
const
{
   * If horizontal, the thumb of the slider points downwards. If
   * vertical, the thumb of the slider points to the right. This
   * orientation of slider can show tick marks.
   }
	kControlSliderPointsDownOrRight = 0;

  {
   * If horizontal, the thumb of the slider points upwards. If
   * vertical, the thumb of the slider points to the left. This
   * orientation of slider can show tick marks.
   }
	kControlSliderPointsUpOrLeft = 1;

  {
   * The slider thumb is non-directional. This orientation of slider is
   * not capable of showing tick marks.
   }
	kControlSliderDoesNotPoint = 2;

{ Control Kind Tag }
const
	kControlKindSlider = FourCharCode('sldr');

{ The HIObject class ID for the HISlider class. }
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kHISliderClassID CFSTRP('com.apple.HISlider')}
{$endc}

{$endc} {TARGET_OS_MAC}
{$ifc not defined MACOSALLINCLUDE or not MACOSALLINCLUDE}

end.
{$endc} {not MACOSALLINCLUDE}
