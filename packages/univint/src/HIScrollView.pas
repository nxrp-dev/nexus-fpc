{
     File:       HIToolbox/HIScrollView.h

     Contains:   Definition of the scrollbar and scroll views provided by HIToolbox.

     Version:    HIToolbox-624~3

     Copyright:  © 2006-2008 by Apple Computer, Inc., all rights reserved.

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
unit HIScrollView;
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
uses MacOsApi.MacTypes,MacOsApi.Appearance,MacOsApi.CarbonEvents,MacOsApi.Controls,MacOsApi.QuickdrawTypes,MacOsApi.HIObject,MacOsApi.HIView;
{$ELSE FPC_DOTTEDUNITS}
uses MacTypes,Appearance,CarbonEvents,Controls,QuickdrawTypes,HIObject,HIView;
{$ENDIF FPC_DOTTEDUNITS}
{$endc} {not MACOSALLINCLUDE}


{$ifc TARGET_OS_MAC}

{$ALIGN POWER}


{
 *  HIScrollView.h
 *
 *  Discussion:
 *    API definitions for the scrollbar and scroll views.
 }
{——————————————————————————————————————————————————————————————————————————————————————}
{  • SCROLL BAR (CDEF 24)                                                              }
{——————————————————————————————————————————————————————————————————————————————————————}
{  This is the new Appearance scroll bar.                                              }
{  Mac OS X has a "Scroll to here" option in the General pane of System Preferences    }
{  which allows users to click in the page up/down regions of a scroll bar and have    }
{  the thumb/indicator jump directly to the clicked position, which alters the value   }
{  of the scroll bar and moves the scrolled content appropriately. As long as the      }
{  mouse button is held down, the click is treated as though the user had clicked in   }
{  the thumb/indicator in the first place.                                             }
{  If you want the scroll bars in your application to work with the "Scroll to here"   }
{  option, you must do the following:                                                  }
{  1. Create live-tracking scroll bars, not scroll bars that show a "ghost" thumb      }
{  when you click on it. You can request live-tracking scroll bars by passing true     }
{  in the liveTracking parameter to CreateScrollBarControl. If you create scroll bars  }
{  with NewControl, use the kControlScrollBarLiveProc.                                 }
{  2. Write an appropriate ControlActionProc and associate it with your scroll bar     }
{  via the SetControlAction API. This allows your application to update its content    }
{  appropriately when the live-tracking scroll bar is clicked.                         }
{  3. When calling HandleControlClick or TrackControl, pass -1 in the action proc      }
{  parameter. This is a request for the Control Manager to use the action proc you     }
{  associated with your control in step 2. If you rely on the standard window event    }
{  handler to do your control tracking, this step is handled for you automatically.    }
{ Theme Scroll Bar proc IDs }
const
	kControlScrollBarProc = 384;  { normal scroll bar}
	kControlScrollBarLiveProc = 386;   { live scrolling variant}

{ Control Kind Tag }
const
	kControlKindScrollBar = FourCharCode('sbar');

{ The HIObject class ID for the HIScrollBar class. }
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kHIScrollBarClassID CFSTRP('com.apple.HIScrollBar')}
{$endc}

const
	kControlScrollBarShowsArrowsTag = FourCharCode('arro'); { Boolean whether or not to draw the scroll arrows}


{==============================================================================}
{  HIScrollView                                                                }
{ The scroll view is a new view starting in Mac OS 10.2. It can be used in     }
{ the new compositing mode ONLY due to the nature of how it works. Like all    }
{ new HIFoo views, this view is created invisibly. You must show the view      }
{ after creation if you want to, like, see it and stuff.                       }
{ The HIScrollView will set the frame of the contained view when its bounds    }
{ change, so it is not necessary to set up the layout of the embedded view.    }
{ Using an HIScrollView requires a few steps:                                  }
{ 1. Install your scrollable content view into the HIScrollView instance using }
{    HIViewAddSubview.                                                         }
{ 2. If the scrollable content view doesn't already handle the                 }
{    kEventScrollableGetInfo and kEventScrollableScrollTo events, you must     }
{    install handlers on your scrollable content view and handle those events  }
{    manually. More details on those events can be found below.                }
{ 3. If the scrollable content view doesn't already send out the               }
{    kEventScrollableInfoChanged event to its parent view, you must send this  }
{    event to the HIScrollView instance whenever your scrollable content       }
{    view's size or origin changes. More details on this event can be found    }
{    below.                                                                    }
{==============================================================================}
{ The HIObject class ID for the HIScrollView class. }
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kHIScrollViewClassID CFSTRP('com.apple.HIScrollView')}
{$endc}
{ Control Kind}
const
	kControlKindHIScrollView = FourCharCode('scrl');

{
    kEventClassScrollable quick reference:

    kEventScrollableGetInfo         = 1,
    kEventScrollableInfoChanged     = 2,
    kEventScrollableScrollTo        = 10
}
const
	kEventClassScrollable = FourCharCode('scrl');


const
{
   * The image size is the total size of the scrollable view, including
   * any parts of the view that are not currently visible. For example,
   * a scrollable view that displays a 100-page document would return a
   * horizontal size equal to the width of a page and a vertical image
   * size equal to 100 times the height of a page.
   }
	kEventParamImageSize = FourCharCode('imsz'); { typeHISize}

  {
   * The view size is the current size of the scrollable view.
   * Typically, this is the same as the view's bounds, and can be
   * acquired by calling HIViewGetBounds.
   }
	kEventParamViewSize = FourCharCode('vwsz'); { typeHISize}

  {
   * The line size is the distance that the HIScrollView should scroll
   * its subview when the user clicks the scroll bar arrows. For
   * example, this might be 10 pixels vertically and 20 pixels
   * horizontally.
   }
	kEventParamLineSize = FourCharCode('lnsz'); { typeHISize}

  {
   * The origin is the current view-relative origin with the total
   * scrollable image that is displayed at the top left corner of the
   * view. These coordinates should always be greater than or equal to
   * zero. They should be less than or equal to the view’s image size
   * minus its view size. Typically, a view that implements the
   * kEventScrollableScrollTo event by calling HIViewSetBoundsOrigin
   * will return the current bounds origin for this parameter, and a
   * view that implements the ScrollTo event by storing the origin in
   * its instance data will return its stored origin for this
   * parameter. For example, a scrollable view that is currently
   * displaying page 10 of a 100-page document would return a
   * horizontal origin of zero and a vertical origin equal to 10 times
   * the height of a page.
   }
	kEventParamOrigin = FourCharCode('orgn'); { typeHIPoint}

{
 *  kEventClassScrollable / kEventScrollableGetInfo
 *
 *  Summary:
 *    Requests information from an HIScrollView’s scrollable view about
 *    its size and origin.
 *
 *  Discussion:
 *    This event is sent by an HIScrollView to its scrollable view to
 *    determine the current size and origin of the scrollable view. A
 *    scrollable view must implement this event in order to scroll
 *    properly inside an HIScrollView. This event is sent only to the
 *    view, and is not propagated past it.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Parameters:
 *
 *    <-- kEventParamImageSize (out, typeHISize)
 *          On exit, contains the size of the entire scrollable view.
 *
 *    <-- kEventParamViewSize (out, typeHISize)
 *          On exit, contains the amount of the scrollable view that is
 *          visible.
 *
 *    <-- kEventParamLineSize (out, typeHISize)
 *          On exit, contains the amount that should be scrolled in
 *          response to a single click on a scrollbar arrow.
 *
 *    <-- kEventParamOrigin (out, typeHIPoint)
 *          On exit, contains the scrollable view’s current origin.
 *
 *  Availability:
 *    Mac OS X:         in version 10.2 and later in Carbon.framework
 *    CarbonLib:        not available
 }
const
	kEventScrollableGetInfo = 1;

{
 *  kEventClassScrollable / kEventScrollableInfoChanged
 *
 *  Summary:
 *    Notification that the size or origin of an HIScrollView’s
 *    scrollable view has changed.
 *
 *  Discussion:
 *    This event is not sent by HIScrollView itself; rather, it may be
 *    sent to an instance of HIScrollView to notify the scroll view
 *    that the size or origin of its scrollable view have changed. The
 *    HIScrollView responds to this event by sending a
 *    kEventScrollableGetInfo to its scrollable view. It then updates
 *    the scroll bars appropriately to reflect the new reality of the
 *    scrollable view. It does NOT move the origin of the scrollable
 *    view at all. It is just a notification to allow the scroll view
 *    to sync up with its scrollable view.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.2 and later in Carbon.framework
 *    CarbonLib:        not available
 }
const
	kEventScrollableInfoChanged = 2;

{
 *  kEventClassScrollable / kEventScrollableScrollTo
 *
 *  Summary:
 *    Requests that an HIScrollView’s scrollable view should scroll to
 *    a particular origin.
 *
 *  Discussion:
 *    This event is sent by an HIScrollView to its scrollable view to
 *    request that the scrollable view update its current origin and
 *    redraw. Typically, a scrollable view scrolls its content either
 *    by setting its bounds origin with HIViewSetBoundsOrigin or by
 *    offsetting its drawing by the scroll origin. If the view embeds
 *    other views, it must use HIViewSetBoundsOrigin to allow the
 *    embedded views to scroll along with their containing view. A view
 *    that uses HIViewSetBoundsOrigin should call that API in response
 *    to this event; a view that offsets its drawing by the scroll
 *    origin should update its current origin in its own instance data
 *    in response to this event. A scrollable view should also use
 *    either HIViewScrollRect to scroll its content, or
 *    HIViewSetNeedsDisplay to cause itself to redraw using the new
 *    origin point. A scrollable view must implement this event in
 *    order to scroll properly inside an HIScrollView.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Parameters:
 *
 *    --> kEventParamOrigin (in, typeHIPoint)
 *          The new origin for the scrollable view. The origin
 *          coordinates will vary from (0,0) to the scrollable view’s
 *          image size minus its view size.
 *
 *  Availability:
 *    Mac OS X:         in version 10.2 and later in Carbon.framework
 *    CarbonLib:        not available
 }
const
	kEventScrollableScrollTo = 10;


{
 *  Summary:
 *    HIScrollView options
 }
const
{
   * This indicates that a vertical scroll bar is desired.
   }
	kHIScrollViewOptionsVertScroll = 1 shl 0;

  {
   * This indicates that a horizontal scroll bar is desired.
   }
	kHIScrollViewOptionsHorizScroll = 1 shl 1;

  {
   * This indicates that space for a grow box should be taken into
   * account when laying out scroll bars. On Mac OS X 10.3 and earlier,
   * if both the horizontal and vertical scroll bars are requested,
   * this attribute is assumed. On Mac OS X 10.4 and later, this
   * attribute is *NOT* assumed; this allows the scroll view to support
   * auto-hiding of the two scroll bars independently on Mac OS X 10.4
   * and later. If you want to preserve space for the grow box on all
   * systems, specify this option bit.
   }
	kHIScrollViewOptionsAllowGrow = 1 shl 2;

  {
   * This indicates that if the grow area is visible, then the scroll
   * view should fill it with white. Available in Mac OS X 10.5 and
   * later.
   }
	kHIScrollViewOptionsFillGrowArea = 1 shl 3;

  {
   * Indicates that the scroll view should never use smooth scrolling,
   * overriding the user's preference. Applications should rarely use
   * this option, but it may be appropriate for certain cases.
   }
	kHIScrollViewOptionsDisableSmoothScrolling = 1 shl 4;
	kHIScrollViewValidOptions = kHIScrollViewOptionsVertScroll or kHIScrollViewOptionsHorizScroll or kHIScrollViewOptionsAllowGrow or kHIScrollViewOptionsFillGrowArea or kHIScrollViewOptionsDisableSmoothScrolling;


{
 *  HIScrollViewAction
 *
 *  Summary:
 *    HIScrollView navigation actions. See HIScrollViewNavigate for
 *    more information.
 }
type
	HIScrollViewAction = UInt32;
const
{
   * The scroll view should move to the top of the content.
   }
	kHIScrollViewScrollToTop = 1 shl 0;

  {
   * The scroll view should move to the bottom of the content.
   }
	kHIScrollViewScrollToBottom = 1 shl 1;

  {
   * The scroll view should move to the left of the content.
   }
	kHIScrollViewScrollToLeft = 1 shl 2;

  {
   * The scroll view should move to the right of the content.
   }
	kHIScrollViewScrollToRight = 1 shl 3;

  {
   * The scroll view should page up.
   }
	kHIScrollViewPageUp = 1 shl 4;

  {
   * The scroll view should page down.
   }
	kHIScrollViewPageDown = 1 shl 5;

  {
   * The scroll view should page left.
   }
	kHIScrollViewPageLeft = 1 shl 6;

  {
   * The scroll view should page right.
   }
	kHIScrollViewPageRight = 1 shl 7;


{$endc} {TARGET_OS_MAC}
{$ifc not defined MACOSALLINCLUDE or not MACOSALLINCLUDE}

end.
{$endc} {not MACOSALLINCLUDE}
