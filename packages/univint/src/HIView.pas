{
     File:       HIToolbox/HIView.h

     Contains:   HIView routines

     Version:    HIToolbox-624~3

     Copyright:  © 2001-2008 by Apple Computer, Inc., all rights reserved.

     Bugs?:      For bug reports, consult the following page on
                 the World Wide Web:

                     http://bugs.freepascal.org

}
{     File:       HIView.p(.pas)																	    }
{ 																										}
{     Contains:   CodeWarrior Pascal( GPC) translation of Apple's Mac OS X 10.3 HIView.h		            }
{				  Translation compatible with make-gpc-interfaces.pl generated MWPInterfaces            }
{                 (GPCPInterfaces).  For the 10.2 available APIs, the CodeWarrior Pascal translation    }
{                 is linkable with Mac OS X 10.2.x or higher CFM CarbonLib and the GPC translation is   }
{                 linkable with Mac OS X 10.2.x or higher Mach-O Carbon.framework.  For the 10.3        }
{                 available APIs, the CodeWarrior Pascal translation is only selectively linkable with  }
{                 Mac OS X 10.3.x or higher CFM CarbonLib and the GPC translation is linkable with Mac  }
{                 OS X 10.3.x or higher Mach-O Carbon.framework.                                        }
{ 																										}
{     Version:    1.1																					}
{ 																										}
{	  Pascal Translation:  Gale Paeper, <gpaeper@empirenet.com>, 2004									}
{ 																										}
{     Copyright:  Subject to the constraints of Apple's original rights, you're free to use this		}
{				  translation as you deem fit.															}
{ 																										}
{     Bugs?:      This is an AS IS translation with no express guarantees of any kind.					}
{                 If you do find a bug, please help out the Macintosh Pascal programming community by   }
{				  reporting your bug finding and possible fix to either personal e-mail to Gale Paeper	}
{				  or a posting to the MacPascal mailing list.											}
{
      Change History (most recent first ):

         <4>      4/8/04    GRP     Completed new additions from HIView.h, version HIToolbox-145.33~1.
         <3>      ?/?/04    PNL     Added most new additions from HIView.h, version HIToolbox-145.33~1.
         <2>    10/02/04    GRP     Added support for GPC as well as CodeWarrior Pascal.
         <1>      9/8/03    GRP     First Pascal translation of HIView.h, version HIToolbox-123.6~10.
}
{     Translation assisted by:                                                                          }
{This file was processed by Dan's Source Converter}
{version 1.3 (this version modified by Ingemar Ragnemalm)}
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
unit HIView;
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
uses MacOsApi.MacTypes,MacOsApi.CFArray,MacOsApi.CFBase,MacOsApi.CGBase,MacOsApi.CGContext,MacOsApi.CGImage,MacOsApi.CarbonEventsCore,MacOsApi.Drag,MacOsApi.Events,MacOsApi.QuickdrawTypes,MacOsApi.Menus,MacOsApi.Appearance,MacOsApi.Controls,MacOsApi.CarbonEvents,MacOsApi.HIGeometry,MacOsApi.HIObject,MacOsApi.IconsCore,MacOsApi.Icons,MacOsApi.HIShape,MacOsApi.HITheme,MacOsApi.CTFont;
{$ELSE FPC_DOTTEDUNITS}
uses MacTypes,CFArray,CFBase,CGBase,CGContext,CGImage,CarbonEventsCore,Drag,Events,QuickdrawTypes,Menus,Appearance,Controls,CarbonEvents,HIGeometry,HIObject,IconsCore,Icons,HIShape,HITheme,CTFont;
{$ENDIF FPC_DOTTEDUNITS}
{$endc} {not MACOSALLINCLUDE}


{$ifc TARGET_OS_MAC}

{$ALIGN MAC68K}

type
	HIViewID = ControlID;

{
 *  Discussion:
 *    HIViewZOrderOp
 }
const
{
   * Indicates we wish to order a view above another view.
   }
	kHIViewZOrderAbove = 1;

  {
   * Indicates we wish to order a view below another view.
   }
	kHIViewZOrderBelow = 2;

type
	HIViewZOrderOp = UInt32;

{
 *  HIViewFrameMetrics
 *
 *  Summary:
 *    Describes the offsets from the structure to the content area of a
 *    view; for example, the top metric is the difference between the
 *    vertical coordinate of the top edge of the viewÕs structure
 *    region and the vertical coordinate of the top edge of the viewÕs
 *    content region. This structure is returned by a view in response
 *    to a kEventControlGetFrameMetrics event.
 }
type
	HIViewFrameMetrics = record
{
   * Height of the top of the structure area.
   }
		top: CGFloat;

  {
   * Width of the left of the structure area.
   }
		left: CGFloat;

  {
   * Height of the bottom of the structure area.
   }
		bottom: CGFloat;

  {
   * Width of the right of the structure area.
   }
		right: CGFloat;
	end;
{==============================================================================}
{  ATTRIBUTES                                                                  }
{==============================================================================}

{
 *  Summary:
 *    View attributes are generally determined by clients of the view;
 *    the view itself should observe the attributes and behave
 *    accordingly.
 *
 *  Discussion:
 *    View Attributes
 }
const
{
   * When set, the view will send the command it generates to the user
   * focus and propagate as it would naturally from there. The default
   * is to send the command to itself and then to its parent and so
   * forth.
   }
	kHIViewAttributeSendCommandToUserFocus = 1 shl 0;

  {
   * Indicates that a text editing view should behave appropriately for
   * editing fields in a dialog; specifically, the view should ignore
   * the Return, Enter, Escape, and Tab keys, and allow them to be
   * processed by other participants in the event flow. Available on
   * Mac OS X 10.3 and later.
   }
	kHIViewAttributeIsFieldEditor = 1 shl 1;

  {
   * Legacy synonym for kHIViewAttributeSendCommandToUserFocus. Please
   * use it instead.
   }
	kHIViewSendCommandToUserFocus = kHIViewAttributeSendCommandToUserFocus;


{
 *  HIView features
 *
 *  Summary:
 *    View feature flags are generally determined by the view itself,
 *    and are not typically changed by clients of the view.
 *
 *    Historical note: This list is similar to the list of Control
 *    Feature Bits in Controls.h. This list is shorter because some of
 *    the Control Manager constants were introduced to enable the
 *    Control Manager to tell whether a CDEF supported a new CDEF
 *    message. This capability is not required by the HIView Manager,
 *    because an HIView that doesn't support a particular Carbon event
 *    will simply ignore it.
 }
const
{
   * This view supports using the ghosting protocol when live tracking
   * is not enabled.
   }
	kHIViewFeatureSupportsGhosting = 1 shl 0;

  {
   * This view allows subviews to be embedded within it.
   }
	kHIViewFeatureAllowsSubviews = 1 shl 1;

  {
   * If this view is clicked, the keyboard focus should be set to this
   * view automatically. This is primarily used for edit text views.
   }
	kHIViewFeatureGetsFocusOnClick = 1 shl 8;

  {
   * This view supports the live feedback protocol. Necessary to
   * implement live scroll bar tracking. Clients of a view should never
   * disable this.
   }
	kHIViewFeatureSupportsLiveFeedback = 1 shl 10;

  {
   * This view can be put into a radio group. Radio buttons and bevel
   * buttons report this behavior.
   }
	kHIViewFeatureSupportsRadioBehavior = 1 shl 11;

  {
   * This view supports the auto-toggle protocol and should at the very
   * least auto- toggle from off to on and back. The view can support a
   * carbon event for more advanced auto-toggling of its value. The tab
   * view supports this, for example, so that when a tab is clicked its
   * value changes automatically.
   }
	kHIViewFeatureAutoToggles = 1 shl 14;

  {
   * This is merely informational. Turning it off would not necessarily
   * disable any timer a view might be using, but it could obey this
   * bit if it so desired.
   }
	kHIViewFeatureIdlesWithTimer = 1 shl 23;

  {
   * This tells the Control Manager that the up button part increases
   * the value of the view instead of decreasing it. For example, the
   * Little Arrows (Spinner) view increase its value when the up button
   * is pressed. Scroll bars, on the other hand, decrease the value
   * when their up buttons are pressed.
   }
	kHIViewFeatureInvertsUpDownValueMeaning = 1 shl 24;

  {
   * This is an optimization for determining a view's opaque region.
   * When set, the view system just uses the view's structure region,
   * and can usually avoid having to call the view at all.
   }
	kHIViewFeatureIsOpaque = 1 shl 25;

  {
   * This is an optimization for determining what gets invalidated when
   * views are dirtied. For example, on a metal window, the content
   * view is actually fully transparent, so invalidating it doesn't
   * really help things. By telling the Control Manager that the view
   * is transparent and does not do any drawing, we can avoid trying to
   * invalidate it and instead invalidate views behind it.
   }
	kHIViewFeatureDoesNotDraw = 1 shl 27;

  {
   * Indicates to the Control Manager that this view doesn't use the
   * special part codes for indicator, inactive, and disabled.
   * Available in Mac OS X 10.3 and later.
   }
	kHIViewFeatureDoesNotUseSpecialParts = 1 shl 28;

  {
   * This is an optimization for determining the clickable region of a
   * window (used for metal windows, for example, when doing async
   * window dragging). The presence of this bit tells us not to bother
   * asking the view for the clickable region. A view like the visual
   * separator would set this bit. It's typically used in conjunction
   * with the kHIViewFeatureDoesNotDraw bit.
   }
	kHIViewFeatureIgnoresClicks = 1 shl 29;


{
 *  HIView valid feature sets
 *
 *  Summary:
 *    These are sets of features that are available on the version of
 *    Mac OS X corresponding to that named in the constant.
 }
const
	kHIViewValidFeaturesForPanther = $3B804D03;


{
 *  HIView feature synonyms
 *
 *  Summary:
 *    Legacy synonyms for HIView feature bit names. Please use the
 *    newer names.
 }
const
	kHIViewSupportsGhosting = kHIViewFeatureSupportsGhosting;
	kHIViewAllowsSubviews = kHIViewFeatureAllowsSubviews;
	kHIViewGetsFocusOnClick = kHIViewFeatureGetsFocusOnClick;
	kHIViewSupportsLiveFeedback = kHIViewFeatureSupportsLiveFeedback;
	kHIViewSupportsRadioBehavior = kHIViewFeatureSupportsRadioBehavior;
	kHIViewAutoToggles = kHIViewFeatureAutoToggles;
	kHIViewIdlesWithTimer = kHIViewFeatureIdlesWithTimer;
	kHIViewInvertsUpDownValueMeaning = kHIViewFeatureInvertsUpDownValueMeaning;
	kHIViewIsOpaque = kHIViewFeatureIsOpaque;
	kHIViewDoesNotDraw = kHIViewFeatureDoesNotDraw;
	kHIViewDoesNotUseSpecialParts = kHIViewFeatureDoesNotUseSpecialParts;
	kHIViewIgnoresClicks = kHIViewFeatureIgnoresClicks;


type
	HIViewFeatures = UInt64;
{==============================================================================}
{  VIEW PART CODES                                                             }
{==============================================================================}
type
	HIViewPartCode = ControlPartCode;
	HIViewPartCodePtr = ^HIViewPartCode;

{
 *  HIViewPartCodes
 *
 }
const
	kHIViewNoPart = 0;
	kHIViewIndicatorPart = 129;
	kHIViewDisabledPart = 254;
	kHIViewInactivePart = 255;

  {
   * Use this constant when not referring to a specific part, but
   * rather the entire view.
   }
	kHIViewEntireView = kHIViewNoPart;


{
 *  HIView meta-parts
 *
 *  Summary:
 *    A meta-part is a part used in a call to the HIViewCopyShape API.
 *    These parts might be defined by a view, but should not be
 *    returned from calls such as HIViewGetPartHit. They define a
 *    region of a view.
 *
 *    Along with these parts, you can also pass in normal part codes to
 *    get the regions of those parts. Not all views fully support this
 *    feature.
 }
const
{
   * The entire area that the view will draw into. When a composited
   * view is drawn, the HIView Manager clips the view's drawing to the
   * structure area. This area may extend beyond the bounds of the view
   * (for example, if the view draws a focus ring outside of its
   * bounds). You may return a superset of the drawn area if this is
   * computationally easier to construct. This area is used to
   * determine the area of a window that should be invalidated and
   * redrawn when a view is invalidated. It is not necessary for a view
   * to return a shape that precisely describes the structure area; for
   * example, a view whose structure is an oval may simply return the
   * oval's bounding rectangle. The default handler for the
   * kEventControlGetPartRegion event will return the view's bounds
   * when this part is requested.
   }
	kHIViewStructureMetaPart = -1;

  {
   * The area of the view in which embedded views should be positioned.
   * This part is only defined for views that can contain other views
   * (for example, the group box). This area is largely informational
   * and is not used by the HIView Manager itself. The default handler
   * for the kEventControlGetPartRegion event will return
   * errInvalidPartCode when this part is requested.
   }
	kHIViewContentMetaPart = -2;

  {
   * The area of the view that, when drawn, is filled with opaque
   * pixels. You may also return a subset of the opaque area if this is
   * computationally easier to construct. If a view is contained in a
   * composited window, the HIView Manager will use this area to
   * optimize drawing of other views that intersect this area; views
   * that are entirely contained within the opaque area, and that are
   * z-ordered underneath this view, will not be drawn at all, since
   * any drawing would be completely overwritten by this view. The
   * default handler for the kEventControlGetPartRegion event will
   * return an empty area when this part is requested. This meta-part
   * is available in Mac OS X 10.2 or later.
   }
	kHIViewOpaqueMetaPart = -3;

  {
   * The area of the view that causes a mouse event to be captured by
   * that view. If a mouse event falls inside the view bounds but
   * outside of this area, then the Control Manager will allow the
   * event to pass through the view to the next view behind it in
   * z-order. This area is used to determine which parts of a window
   * should allow async window dragging when clicked (the draggable
   * area is computed by subtracting the clickable areas of views in
   * the window from the window's total area). You can also customize
   * the clickable area of a view if you want the view to have an
   * effectively transparent area (for example, a view that draws
   * multiple tabs might want clicks in the space between the tabs to
   * fall through to the next view rather than be captured by the
   * tab-drawing view). The default handler for the
   * kEventControlGetPartRegion event will return the view's bounds
   * when this part is requested. This meta-part is available in Mac OS
   * X 10.3 or later.
   }
	kHIViewClickableMetaPart = -4;


{
 *  HIView Focus Parts
 *
 }
const
{
   * Tells view to clear its focus
   }
	kHIViewFocusNoPart = kHIViewNoPart;

  {
   * Tells view to focus on the next part
   }
	kHIViewFocusNextPart = -1;

  {
   * Tells view to focus on the previous part
   }
	kHIViewFocusPrevPart = -2;

{==============================================================================}
{  CONTENT                                                                     }
{==============================================================================}
type
	HIViewImageContentType = ControlContentType;
	HIViewImageContentInfo = ControlImageContentInfo;
	HIViewContentType = SInt16;

{
 *  HIViewContentTypes
 *
 *  Summary:
 *    HIView image content types.
 }
const
{
   * The view has no content other than text.
   }
	kHIViewContentTextOnly = 0;

  {
   * The view has no content.
   }
	kHIViewContentNone = 0;

  {
   * The view's content is an IconSuiteRef. The icon suite handle
   * should be placed in HIViewContentInfo.u.iconSuite.
   }
	kHIViewContentIconSuiteRef = 129;

  {
   * The view's content is an IconRef. The IconRef should be placed in
   * HIViewContentInfo.u.iconRef.
   }
	kHIViewContentIconRef = 132;

  {
   * The view's content is a CGImageRef. The CGImageRef should be
   * placed in HIViewContentInfo.u.imageRef. Available in Mac OS X 10.4
   * and later.
   }
	kHIViewContentCGImageRef = 134;

  {
   * The view's content is an image file in the main bundle's Resources
   * directory. The CFStringRef of the full name of the image file
   * should be placed in HIViewContentInfo.u.imageResource. Available
   * in Mac OS X 10.5 and later.
   }
	kHIViewContentImageResource = 135;

  {
   * The view's content is an image file at an arbitrary location. The
   * CFURLRef identifying the image file should be placed in
   * HIViewContentInfo.u.imageFile. Available in Mac OS X 10.5 and
   * later.
   }
	kHIViewContentImageFile = 136;

  {
   * The view's content is an IconRef, specified by an icon type and
   * creator. The type and creator should be placed in
   * HIViewContentInfo.u.iconTypeAndCreator. Available in Mac OS X 10.5
   * and later.
   }
	kHIViewContentIconTypeAndCreator = 137;

  {
   * The view's content is a Note, Caution, or Stop icon, specified by
   * the corresponding icon type (kAlertNoteIcon, kAlertCautionIcon, or
   * kAlertStopIcon). When the icon is drawn, it may be modified to
   * correspond to the current Mac OS X user interface guidelines. The
   * type should be placed in
   * HIViewContentInfo.u.iconTypeAndCreator.type. The creator field of
   * the iconTypeAndCreator field is ignored in this case. Available in
   * Mac OS X 10.5 and later.
   }
	kHIViewContentAlertIconType = 138;

  {
   * The view's content is a reference to an NSImage. The NSImage*
   * should be placed in HIViewContentInfo.u.nsImage. Available in Mac
   * OS X 10.5 and later.
   }
	kHIViewContentNSImage = 139;


{
 *  HITypeAndCreator
 *
 *  Summary:
 *    A type/creator pair used to identify an IconRef.
 }
type
	HITypeAndCreator = record
{
   * The icon type.
   }
		typ: OSType;

  {
   * The icon creator.
   }
		creator: OSType;
	end;

{
 *  HIViewContentInfo
 *
 *  Summary:
 *    Defines the image content of a view.
 *
 *  Discussion:
 *    This structure is the HIView equivalent of the
 *    ControlImageContentInfo structure. On Mac OS X 10.5 and later,
 *    you should use this structure with the HIViewSetImageContent and
 *    HIViewCopyImageContent APIs to set or retrieve the image content
 *    of a view.
 *
 *    Prior to Mac OS X 10.5, you may pass this structure to
 *    GetControlData and SetControlData with the kControlContentTag
 *    constant. Note, however, that the size of this structure as
 *    declared in the Mac OS X 10.5 headers is different (and larger)
 *    than the size of this structure as declared in the Mac OS X 10.4
 *    headers, and the Mac OS X 10.5 version is larger than the size of
 *    the ControlImageContentInfo structure. The view implementations
 *    prior to Mac OS X 10.5 only support Get/SetControlData requests
 *    if the specified data size matches the size of
 *    ControlImageContentInfo. Therefore, if you need to use
 *    Get/SetControlData with this structure prior to Mac OS X 10.5,
 *    you should pass sizeof(ControlImageContentInfo) rather than
 *    sizeof(HIViewContentInfo) as the size of the incoming/outgoing
 *    data buffer.
 }
type
	HIViewContentInfo = record
{
   * The type of content referenced in the content union.
   }
		contentType: HIViewContentType;
		case SInt16 of
		1: (
			iconRef: IconRef_fix;
			);
		2: (
			imagiconTypeAndCreatoreRef: HITypeAndCreator;
			);
		3: (
			imageRef: CGImageRef;
			);
		4: (
			imageResource: CFStringRef;
			);
		5: (
			imageFile: CFURLRef;
			);
	end;
type
	HIViewContentInfoPtr = ^HIViewContentInfo;
{==============================================================================}
{  ERROR CODES                                                                 }
{==============================================================================}

{
 *  Discussion:
 *    View/Control Error Codes
 }
const
{
   * This value will be returned from an HIView API or a Control
   * Manager API when an action that is only supported on a compositing
   * window is attempted on a non-compositing window. This doesn't
   * necessarily mean that the API is only callable for compositing
   * windows; sometimes the legality of the action is based on other
   * parameters of the API. See HIViewAddSubview for one particular use
   * of this error code.
   }
	errNeedsCompositedWindow = -30598;

{==============================================================================}
{  HIOBJECT SUPPORT                                                            }
{  Setting Initial Bounds                                                      }
{  When creating a view using HIObjectCreate, you can set the initial bounds   }
{  automatically by passing in an initialization event into HIObjectCreate     }
{  with a kEventParamBounds parameter as typeHIRect or typeQDRectangle.        }
{==============================================================================}
{ The HIObject class ID for the HIView class. }
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kHIViewClassID CFSTRP('com.apple.hiview')}
{$endc}
{==============================================================================}
{  EMBEDDING                                                                   }
{==============================================================================}


{
 *  HIViewKind
 }
type
	HIViewKind = record
{
   * The signature of the view. Apple reserves all signatures made up
   * of only lowercase characters.
   }
		signature: OSType;

  {
   * The kind of the view. Apple reserves all kinds made up of only
   * lowercase characters.
   }
		kind: OSType;
	end;

{
 *  View signature kind
 *
 }
const
{
   * The signature of all HIToolbox views.
   }
	kHIViewKindSignatureApple = FourCharCode('appl');


type
	HIViewTrackingAreaRef = ^OpaqueHIViewTrackingAreaRef; { an opaque type }
	OpaqueHIViewTrackingAreaRef = record end;
	HIViewTrackingAreaRefPtr = ^HIViewTrackingAreaRef;
const
	kEventParamHIViewTrackingArea = FourCharCode('ctra'); { typeHIViewTrackingAreaRef}
	typeHIViewTrackingAreaRef = FourCharCode('ctra');

{
 *  kEventClassControl / kEventControlTrackingAreaEntered
 *
 *  Summary:
 *    The mouse has entered a tracking area owned by your control.
 *
 *  Discussion:
 *    If you have installed a mouse tracking area in your view, you
 *    will receive this event when the mouse enters that area. The
 *    tracking area reference is sent with the event. This event is
 *    sent only to the view, and is not propagated past it.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Parameters:
 *
 *    --> kEventParamDirectObject (in, typeControlRef)
 *          The control that owns the tracking area and is receiving
 *          the event. This parameter is available on Mac OS X 10.5 and
 *          later.
 *
 *    --> kEventParamHIViewTrackingArea (in, typeHIViewTrackingAreaRef)
 *          The tracking area that was entered.
 *
 *    --> kEventParamKeyModifiers (in, typeUInt32)
 *          The keyboard modifiers that were in effect when the mouse
 *          entered.
 *
 *    --> kEventParamMouseLocation (in, typeHIPoint)
 *          The location of the mouse in view coordinates.
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework
 *    CarbonLib:        not available
 }
const
	kEventControlTrackingAreaEntered = 23;

{
 *  kEventClassControl / kEventControlTrackingAreaExited
 *
 *  Summary:
 *    The mouse has exited a tracking area owned by your control.
 *
 *  Discussion:
 *    If you have installed a mouse tracking area in your view, you
 *    will receive this event when the mouse leaves that area. The
 *    tracking area reference is sent with the event. This event is
 *    sent only to the view, and is not propagated past it.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Parameters:
 *
 *    --> kEventParamDirectObject (in, typeControlRef)
 *          The control that owns the tracking area and is receiving
 *          the event. This parameter is available on Mac OS X 10.5 and
 *          later.
 *
 *    --> kEventParamHIViewTrackingArea (in, typeHIViewTrackingAreaRef)
 *          The tracking area that was entered.
 *
 *    --> kEventParamKeyModifiers (in, typeUInt32)
 *          The keyboard modifiers that were in effect when the mouse
 *          left.
 *
 *    --> kEventParamMouseLocation (in, typeHIPoint)
 *          The location of the mouse in view coordinates. This point
 *          may or may not lie on the boundary of the mouse region. It
 *          is merely where the mouse was relative to the view when the
 *          exit event was generated.
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework
 *    CarbonLib:        not available
 }
const
	kEventControlTrackingAreaExited = 24;


type
	HIViewTrackingAreaID = UInt64;
	HIViewTrackingAreaIDPtr = ^HIViewTrackingAreaID;


{
 *  Summary:
 *    Option bits for use with HIViewAdvanceFocusWithOptions and
 *    HIViewSetFocus.
 }
const
{
   * Explicitly requests "focus on everything" mode. All controls will
   * be considered focusable, regardless of the user's current
   * preferences. If this option is not specified, then setting or
   * advancing focus will obey the user's current preferences for
   * focusing traditionally or focusing on any control.
   }
	kHIViewFocusOnAnyControl = 1 shl 0;

  {
   * Explicitly requests "traditional focus" mode. Only traditionally
   * focusable controls (text and lists) will be considered focusable,
   * regardless of the user's current preference. If this option is not
   * specified, then setting or advancing focus will obey the user's
   * current preferences for focusing traditionally or focusing on any
   * control.
   }
	kHIViewFocusTraditionally = 1 shl 1;

  {
   * If advancing the focus would wrap around to the beginning or end
   * of the focus root, then errCouldntSetFocus is returned. If this
   * option is not specified, then advancing (or reversing) the focus
   * will wrap around to the first (or last) focusable child of the
   * focus root. This option is only valid for the
   * HIViewAdvanceFocusWithOptions API.
   }
	kHIViewFocusWithoutWrapping = 1 shl 2;



{
 *  Summary:
 *    Since horizontal and vertical bindings are very similar in
 *    application, except along different axes, the binding kinds have
 *    been abstracted to minimum and maximum. Synonyms have been
 *    provided for convenience. You are encouraged to use them.
 *
 *  Discussion:
 *    HIBindingKind constants.
 }
const
{
   * No binding is to occur.
   }
	kHILayoutBindNone = 0;

  {
   * Bind to the minimum of the axis.
   }
	kHILayoutBindMin = 1;

  {
   * Bind to the maximum of the axis.
   }
	kHILayoutBindMax = 2;
	kHILayoutBindLeft = kHILayoutBindMin;
	kHILayoutBindRight = kHILayoutBindMax;

  {
   * Synonyms for convenience and clarity.
   }
	kHILayoutBindTop = kHILayoutBindMin;
	kHILayoutBindBottom = kHILayoutBindMax;

type
	HIBindingKind = UInt16;

{
 *  HISideBinding
 *
 *  Summary:
 *    A binding for a side of an HIView.
 *
 *  Discussion:
 *    A side binding is entirely related to the change of the parent's
 *    position or size (but only as the size affects the maximum edge
 *    position). A side binding doesn't mean "move to where my
 *    relative's side is" but rather "move as my relative's side has
 *    moved".
 }
type
	HISideBinding = record
{
   * An HIViewRef to the view to which this side is bound. Can be NULL,
   * indicating that the the side is bound to its parent view.
   }
		toView: HIViewRef;                 { NULL means parent}

  {
   * An HIBindingKind indicating the bind kind.
   }
		kind: HIBindingKind;

  {
   * Not currently used. Must be set to 0.
   }
		offset: CGFloat;
	end;

{
 *  HIBinding
 *
 *  Summary:
 *    A set of Top, Left, Bottom, and Right bindings for an HIView.
 }
type
	HIBinding = record
{
   * The top side bindings.
   }
		top: HISideBinding;

  {
   * The left side bindings.
   }
		left: HISideBinding;

  {
   * The bottom side bindings.
   }
		bottom: HISideBinding;

  {
   * The right side bindings.
   }
		right: HISideBinding;
	end;

{
 *  Discussion:
 *    HIScaleKind constants.
 }
const
{
   * The scale is determined from the axis size.
   }
	kHILayoutScaleAbsolute = 0;


type
	HIScaleKind = UInt16;

{
 *  HIAxisScale
 *
 *  Summary:
 *    A scale description for an axis of an HIView.
 }
type
	HIAxisScale = record
{
   * An HIViewRef to the view to which this axis is scaled. Can be
   * NULL, indicating that the the axis is scaled relative to its
   * parent view.
   }
		toView: HIViewRef;                 { NULL means parent}

  {
   * An HIScaleKind describing the type of scaling to be applied.
   * Currently, this field can't be anything other than
   * kHILayoutScaleAbsolute.
   }
		kind: HIScaleKind;

  {
   * A CGFloat indicating how much to scale the HIView. 0 indicates no
   * scaling. A value of 1 indicates that the view is to always have
   * the same axial size.
   }
		ratio: CGFloat;
	end;

{
 *  HIScaling
 *
 *  Summary:
 *    A set of scaling descriptions for the axes of an HIView.
 }
type
	HIScaling = record
{
   * An HIAxisScale describing the horizontal scaling for an HIView.
   }
		x: HIAxisScale;

  {
   * An HIAxisScale describing the vertical scaling for an HIView.
   }
		y: HIAxisScale;
	end;

{
 *  Summary:
 *    Since horizontal and vertical positions are very similar in
 *    application, except along different axes, the position kinds have
 *    been abstracted to minimum and maximum. Synonyms have been
 *    provided for convenience. You are encouraged to use them.
 *
 *  Discussion:
 *    HIPositionKind constants.
 }
const
{
   * No positioning is to occur.
   }
	kHILayoutPositionNone = 0;

  {
   * Centered positioning will occur. The view will be centered
   * relative to the specified view.
   }
	kHILayoutPositionCenter = 1;

  {
   * Minimum positioning will occur. The view will be left or top
   * aligned relative to the specified view.
   }
	kHILayoutPositionMin = 2;

  {
   * Maximum positioning will occur. The view will be right or bottom
   * aligned relative to the specified view.
   }
	kHILayoutPositionMax = 3;

  {
   * Synonyms for convenience and clarity.
   }
	kHILayoutPositionLeft = kHILayoutPositionMin;
	kHILayoutPositionRight = kHILayoutPositionMax;
	kHILayoutPositionTop = kHILayoutPositionMin;
	kHILayoutPositionBottom = kHILayoutPositionMax;


type
	HIPositionKind = UInt16;

{
 *  HIAxisPosition
 *
 *  Summary:
 *    An axial position description for an HIView.
 }
type
	HIAxisPosition = record
{
   * An HIViewRef to the view relative to which a view will be
   * positioned. Can be NULL, indicating that the the view is
   * positioned relative to its parent view.
   }
		toView: HIViewRef;                 { NULL means parent}

  {
   * An HIPositionKind indicating the kind of positioning to apply.
   }
		kind: HIPositionKind;

  {
   * After the position kind has been applied, the origin component
   * that corresponds to the positioning axis is offet by this value.
   * (ex: Left aligned + 10 ).
   }
		offset: CGFloat;
	end;

{
 *  HIPositioning
 *
 *  Summary:
 *    A positioning description for an HIView.
 }
type
	HIPositioning = record
{
   * An HIAxisPosition describing the horizontal positioning for an
   * HIView.
   }
		x: HIAxisPosition;
		y: HIAxisPosition;
	end;

{
 *  HILayoutInfo
 *
 *  Summary:
 *    A layout description for an HIView.
 *
 *  Discussion:
 *    The different layout transformations are applied sequentially to
 *    the HIView.
 *
 *    First, the bindings are applied. Note that the bindings are
 *    applied recursively to a container's HIViews. This requires care
 *    on your part, especially when applying inter-relational bindings.
 *
 *
 *    Then the scaling is applied (which could potentially override
 *    some of the previously applied bindings). Then the positioning is
 *    applied (which could potentially override some of the previously
 *    applied scaling and bindings).
 }
type
	HILayoutInfo = record
{
   * The version of the structure. The current version is
   * kHILayoutInfoVersionZero.
   }
		version: UInt32;

  {
   * An HIBinding structure describing the bindings to apply to the
   * sides of an HIView.
   }
		binding: HIBinding;

  {
   * An HIScaling structure describing the axial scaling to apply to an
   * HIView.
   }
		scale: HIScaling;

  {
   * An HIPositioning structure describing the positioning to apply to
   * an HIView.
   }
		position: HIPositioning;
	end;
const
	kHILayoutInfoVersionZero = 0;



{
 *  Summary:
 *    Option bits for use with HIViewCreateOffscreenImage.
 }
const
{
   * Requests that the offscreen image should use the resolution of the
   * window's backing store. If the window is using crisp HiDPI mode,
   * the image size will therefore be equal to the view bounds
   * multiplied by the result of HIWindowGetBackingScaleFactor on the
   * view's window. Available in Mac OS X 10.8 and later.
   }
	kHIViewOffscreenImageUseWindowBackingResolution = 1 shl 0;





{
 *  Summary:
 *    Constants for use with the HICreateTransformedCGImage API.
 }
const
{
   * No visual transform should be applied.
   }
	kHITransformNone = $00;

  {
   * The image should be transformed to use a disabled appearance. This
   * transform should not be combined with any other transform.
   }
	kHITransformDisabled = $01;

  {
   * The image should be transformed to use a selected appearance. This
   * transform should not be combined with any other transform.
   }
	kHITransformSelected = $4000;


{$endc} {TARGET_OS_MAC}
{$ifc not defined MACOSALLINCLUDE or not MACOSALLINCLUDE}

end.
{$endc} {not MACOSALLINCLUDE}
