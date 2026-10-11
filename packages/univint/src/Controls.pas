{
     File:       HIToolbox/Controls.h

     Contains:   Control Manager interfaces

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
unit Controls;
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
uses MacOsApi.MacTypes,MacOsApi.Appearance,MacOsApi.Collections,MacOsApi.Drag,MacOsApi.Events,MacOsApi.Files,MacOsApi.IconsCore,MacOsApi.Icons,MacOsApi.Menus,MacOsApi.QuickdrawTypes,MacOsApi.CFBase,MacOsApi.CGImage,MacOsApi.HIObject;
{$ELSE FPC_DOTTEDUNITS}
uses MacTypes,Appearance,Collections,Drag,Events,Files,IconsCore,Icons,Menus,QuickdrawTypes,CFBase,CGImage,HIObject;
{$ENDIF FPC_DOTTEDUNITS}
{$endc} {not MACOSALLINCLUDE}


{$ifc TARGET_OS_MAC}

{$ALIGN MAC68K}

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Resource Types                                                                                    }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
const
	kControlDefProcType = FourCharCode('CDEF');
	kControlTemplateResourceType = FourCharCode('CNTL');
	kControlColorTableResourceType = FourCharCode('cctb');
	kControlDefProcResourceType = FourCharCode('CDEF');

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Format of a ÔCNTLÕ resource                                                                       }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
type
	ControlTemplate = record
		controlRect: Rect;
		controlValue: SInt16;
		controlVisible: Boolean;
		fill: UInt8;
		controlMaximum: SInt16;
		controlMinimum: SInt16;
		controlDefProcID: SInt16;
		controlReference: SInt32;
		controlTitle: Str255;
	end;
	ControlTemplatePtr = ^ControlTemplate;
type
	ControlTemplateHandle = ^ControlTemplatePtr;


type
	ControlPartCode = SInt16;
	ControlPartCodePtr = ^ControlPartCode; { when a var xx:ControlPartCode parameter can be nil, it is changed to xx: ControlPartCodePtr }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{ ¥ Control ActionProcPtr                                                                              }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
type
	ControlActionProcPtr = procedure( theControl: ControlRef; partCode: ControlPartCode );
type
	ControlActionUPP = ControlActionProcPtr;

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{ ¥ Control ActionProcPtr : Epilogue                                                                   }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{
 *  NewControlActionUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewControlActionUPP( userRoutine: ControlActionProcPtr ): ControlActionUPP; external name '_NewControlActionUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  DisposeControlActionUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeControlActionUPP( userUPP: ControlActionUPP ); external name '_DisposeControlActionUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  InvokeControlActionUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure InvokeControlActionUPP( theControl: ControlRef; partCode: ControlPartCode; userUPP: ControlActionUPP ); external name '_InvokeControlActionUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Control Color Table                                                                               }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
const
	cFrameColor = 0;
	cBodyColor = 1;
	cTextColor = 2;
	cThumbColor = 3;
	kNumberCtlCTabEntries = 4;

type
	CtlCTabPtr = ^CtlCTab;
	CtlCTab = record
		ccSeed: SInt32;
		ccRider: SInt16;
		ctSize: SInt16;
		ctTable: array [0..3] of ColorSpec;
	end;
type
	CCTabPtr = CtlCTabPtr;
type
	CCTabHandle = ^CCTabPtr;

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Control Variants                                                                  }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
type
	ControlVariant = SInt16;
const
	kControlNoVariant = 0;    { No variant}
	kControlUsesOwningWindowsFontVariant = 1 shl 3; { Control uses owning windows font to display text}


{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Control Part Codes                                                                }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{ Basic part codes }
const
	kControlNoPart = kAppearancePartMetaNone;
	kControlIndicatorPart = kAppearancePartIndicator;
	kControlDisabledPart = kAppearancePartMetaDisabled;
	kControlInactivePart = kAppearancePartMetaInactive;

{ Use this constant in Get/SetControlData when the data referred to is not         }
{ specific to a part, but rather the entire control, e.g. the list handle of a     }
{ list box control.                                                                }
const
	kControlEntireControl = kControlNoPart;


{
 *  Control meta-parts
 *
 *  Discussion:
 *    If you haven't guessed from looking at other toolbox headers, we
 *    like the word 'meta'. It's cool. So here's one more for you. A
 *    meta-part is a part used in a call to the GetControlRegion API.
 *    These parts might be defined by a control, but should not be
 *    returned from calls such as TestControl, et al. They define a
 *    region of a control.
 *
 *    Along with these parts, you can also pass in normal part codes to
 *    get the regions of the parts. Not all controls fully support this
 *    at the time this was written.
 }
const
{
   * The entire area that the control will draw into. When a composited
   * control is drawn, the Control Manager clips the control's drawing
   * to the structure area. This area may extend beyond the bounds of
   * the control (for example, if the control draws a focus ring
   * outside of its bounds). You may return a superset of the drawn
   * area if this is computationally easier to construct. This area is
   * used to determine the area of a window that should be invalidated
   * and redrawn when a control is invalidated. It is not necessary for
   * a control to return a shape that precisely describes the structure
   * area; for example, a control whose structure is an oval may simply
   * return the oval's bounding rectangle. The default handler for the
   * kEventControlGetPartRegion event will return the control's bounds
   * when this part is requested.
   }
	kControlStructureMetaPart = -1;

  {
   * The area of the control in which embedded controls should be
   * positioned. This part is only defined for controls that can
   * contain other controls (for example, the group box). This area is
   * largely informational and is not used by the Control Manager
   * itself. The default handler for the kEventControlGetPartRegion
   * event will return errInvalidPartCode when this part is requested.
   }
	kControlContentMetaPart = -2;

  {
   * The area of the control that, when drawn, is filled with opaque
   * pixels. You may also return a subset of the opaque area if this is
   * computationally easier to construct. If a control is contained in
   * a composited window, the Control Manager will use this area to
   * optimize drawing of other controls that intersect this area;
   * controls that are entirely contained within the opaque area, and
   * that are z-ordered underneath this control, will not be drawn at
   * all, since any drawing would be completely overwritten by this
   * control. The default handler for the kEventControlGetPartRegion
   * event will return an empty area when this part is requested. This
   * meta-part is available in Mac OS X 10.2 or later.
   }
	kControlOpaqueMetaPart = -3;

  {
   * The area of the control that causes a mouse event to be captured
   * by that control. If a mouse event falls inside the control bounds
   * but outside of this area, then the Control Manager will allow the
   * event to pass through the control to the next control behind it in
   * z-order. This area is used to determine which parts of a window
   * should allow async window dragging when clicked (the draggable
   * area is computed by subtracting the clickable areas of controls in
   * the window from the window's total area). You can also customize
   * the clickable area of a control if you want the control to have an
   * effectively transparent area (for example, a control that draws
   * multiple tabs might want clicks in the space between the tabs to
   * fall through to the next control rather than be captured by the
   * tab-drawing control). The default handler for the
   * kEventControlGetPartRegion event will return the control's bounds
   * when this part is requested. This meta-part is available in Mac OS
   * X 10.3 or later.
   }
	kControlClickableMetaPart = -4;

{ focusing part codes }
const
	kControlFocusNoPart = kControlNoPart; { tells control to clear its focus}
	kControlFocusNextPart = -1;   { tells control to focus on the next part}
	kControlFocusPrevPart = -2;    { tells control to focus on the previous part}

type
	ControlFocusPart = ControlPartCode;
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Control Collection Tags                                                                           }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  These are standard tags that you will find in the initial data Collection that is passed in the     }
{  'param' parameter to the initCntl message, and in the kEventParamInitCollection parameter to the    }
{  kEventControlInitialize event (Carbon only).                                                        }
{  All tags at ID zero in a control's Collection are reserved for Control Manager use.                 }
{  Custom control definitions should use other IDs.                                                    }
{  Most of these tags are interpreted when you call CreateCustomControl; the Control Manager will put  }
{  the value in the right place before calling the control definition with the initialization message. }


{
 *  Discussion:
 *    Control Collection Tags
 }
const
{
   * Rect - the bounding rectangle.
   }
	kControlCollectionTagBounds = FourCharCode('boun');

  {
   * SInt32 - the value
   }
	kControlCollectionTagValue = FourCharCode('valu');

  {
   * SInt32 - the minimum
   }
	kControlCollectionTagMinimum = FourCharCode('min ');

  {
   * SInt32 - the maximum
   }
	kControlCollectionTagMaximum = FourCharCode('max ');

  {
   * SInt32 - the view size
   }
	kControlCollectionTagViewSize = FourCharCode('view');

  {
   * Boolean - the visible state. Only interpreted on CarbonLib
   * versions up through 1.5.x and Mac OS X versions 10.0.x. Not
   * interpreted on CarbonLib 1.6 and later. Not interpreted on Mac OS
   * 10.1 and later. We recommend you do not use this tag at all.
   }
	kControlCollectionTagVisibility = FourCharCode('visi');

  {
   * SRefCon - the refCon
   }
	kControlCollectionTagRefCon = FourCharCode('refc');

  {
   * arbitrarily sized character array - the title
   }
	kControlCollectionTagTitle = FourCharCode('titl');

  {
   * bytes as received via CFStringCreateExternalRepresentation
   }
	kControlCollectionTagUnicodeTitle = FourCharCode('uttl');

  {
   * OSType - the ControlID signature
   }
	kControlCollectionTagIDSignature = FourCharCode('idsi');

  {
   * SInt32 - the ControlID id
   }
	kControlCollectionTagIDID = FourCharCode('idid');

  {
   * UInt32 - the command
   }
	kControlCollectionTagCommand = FourCharCode('cmd ');

  {
   * SInt16 - the variant
   }
	kControlCollectionTagVarCode = FourCharCode('varc');


{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Control Image Content                                                                             }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}

{
 *  Summary:
 *    Control image content types
 }
const
{
   * The control has no content other than text.
   }
	kControlContentTextOnly = 0;

  {
   * The control has no content.
   }
	kControlNoContent = 0;

  {
   * The control's content is an icon suite identified by a resource
   * ID. The resource ID of the 'icns' resource should be placed in
   * ControlImageContentInfo.u.resID .
   }
	kControlContentIconSuiteRes = 1;

  {
   * The control's content is a color icon identified by a resource ID.
   * The resource ID of the 'cicn' resource should be placed in
   * ControlImageContentInfo.u.resID .
   }
	kControlContentCIconRes = 2;

  {
   * The control's content is a picture identified by a resource ID.
   * The resource ID of the 'PICT' resource should be placed in
   * ControlImageContentInfo.u.resID .
   }
	kControlContentPictRes = 3;

  {
   * The control's content is an icon identified by a resource ID. The
   * resource ID of the 'ICON' resource should be placed in
   * ControlImageContentInfo.u.resID .
   }
	kControlContentICONRes = 4;

  {
   * The control's content is a note, caution, or stop icon identified
   * by a resource ID. The resource ID should be placed in
   * ControlImageContentInfo.u.resID. The resource ID must be one of
   * kStopIcon, kNoteIcon, or kCautionIcon. When the icon is drawn, it
   * may be modified to correspond to the current Mac OS X user
   * interface guidelines. This content type is supported on Mac OS X
   * 10.1 and later by the Icon control.
   }
	kControlContentAlertIconRes = 5;

  {
   * The control's content is an IconSuiteHandle. The icon suite handle
   * should be placed in HIViewContentInfo.u.iconSuite.
   }
	kControlContentIconSuiteHandle = 129;

  {
   * The control's content is a CIconHandle. The color icon handle
   * should be placed in HIViewContentInfo.u.cIconHandle.
   }
	kControlContentCIconHandle = 130;

  {
   * The control's content is a PicHandle. The picture handle should be
   * placed in HIViewContentInfo.u.picture.
   }
	kControlContentPictHandle = 131;

  {
   * The control's content is an IconRef. The IconRef should be placed
   * in HIViewContentInfo.u.iconRef.
   }
	kControlContentIconRef = 132;

  {
   * The control's content is a handle to a monochrome icon. The icon
   * handle should be placed in HIViewContentInfo.u.ICONHandle.
   }
	kControlContentICON = 133;

  {
   * The control's content is a CGImageRef. The CGImageRef should be
   * placed in HIViewContentInfo.u.imageRef. This content type is
   * supported on Mac OS X 10.4 and later.
   }
	kControlContentCGImageRef = 134;

type
	ControlContentType = SInt16;
type
	ControlButtonContentInfo = record
		contentType: ControlContentType;
		case SInt16 of
		0: (
			resID: SInt16;
			);
		1: (
			iconRef: IconRef_fix;
			);
		2: (
			imageRef: CGImageRef;
			);
	end;
	ControlButtonContentInfoPtr = ^ControlButtonContentInfo;
type
	ControlImageContentInfo = ControlButtonContentInfo;
	ControlImageContentInfoPtr = ControlButtonContentInfoPtr;
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Control Key Script Behavior                                                                       }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
const
	kControlKeyScriptBehaviorAllowAnyScript = FourCharCode('any '); { leaves the current keyboard alone and allows user to change the keyboard.}
	kControlKeyScriptBehaviorPrefersRoman = FourCharCode('prmn'); { switches the keyboard to roman, but allows them to change it as desired.}
	kControlKeyScriptBehaviorRequiresRoman = FourCharCode('rrmn'); { switches the keyboard to roman and prevents the user from changing it.}

type
	ControlKeyScriptBehavior = UInt32;
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Control Font Style                                                                                }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{    SPECIAL FONT USAGE NOTES: You can specify the font to use for many control types.
    The constants below are meta-font numbers which you can use to set a particular
    control's font usage. There are essentially two modes you can use: 1) default,
    which is essentially the same as it always has been, i.e. it uses the system font, unless
    directed to use the window font via a control variant. 2) you can specify to use
    the big or small system font in a generic manner. The Big system font is the font
    used in menus, etc. Chicago has filled that role for some time now. Small system
    font is currently Geneva 10. The meta-font number implies the size and style.

    NOTE:       Not all font attributes are used by all controls. Most, in fact, ignore
                the fore and back color (Static Text is the only one that does, for
                backwards compatibility). Also size, face, and addFontSize are ignored
                when using the meta-font numbering.
}
{ Meta-font numbering - see note above }
const
	kControlFontBigSystemFont = -1;   { force to big system font}
	kControlFontSmallSystemFont = -2;   { force to small system font}
	kControlFontSmallBoldSystemFont = -3; { force to small bold system font}
	kControlFontViewSystemFont = -4;   { force to views system font (DataBrowser control only)}
	kControlFontMiniSystemFont = -5;    { force to mini system font}

{ Add these masks together to set the flags field of a ControlFontStyleRec }
{ They specify which fields to apply to the text. It is important to make  }
{ sure that you specify only the fields that you wish to set.              }
const
	kControlUseFontMask = $0001;
	kControlUseFaceMask = $0002;
	kControlUseSizeMask = $0004;
	kControlUseForeColorMask = $0008;
	kControlUseBackColorMask = $0010;
	kControlUseModeMask = $0020;
	kControlUseJustMask = $0040;
	kControlUseAllMask = $00FF;
	kControlAddFontSizeMask = $0100;

{ AddToMetaFont indicates that we want to start with a standard system     }
{ font, but then we'd like to add the other attributes. Normally, the meta }
{ font ignores all other flags                                             }
const
	kControlAddToMetaFontMask = $0200; { Available in Appearance 1.1 or later}

{ UseThemeFontID indicates that the font field of the ControlFontStyleRec  }
{ should be interpreted as a ThemeFontID (see Appearance.h). In all other  }
{ ways, specifying a ThemeFontID is just like using one of the control     }
{ meta-fonts IDs. kControlUseThemeFontIDMask and kControlUseFontMask are   }
{ mutually exclusive; you can only specify one of them. If you specify     }
{ both of them, the behavior is undefined.                                 }
const
	kControlUseThemeFontIDMask = $0080; { Available in Mac OS X or later}

type
	ControlFontStyleRecPtr = ^ControlFontStyleRec;
	ControlFontStyleRec = record
		flags: SInt16;
		font: SInt16;
		size: SInt16;
		style: SInt16;
		mode: SInt16;
		just: SInt16;
		foreColor: RGBColor;
		backColor: RGBColor;
	end;
type
	ControlFontStylePtr = ControlFontStyleRecPtr;
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Click Activation Results                                                                          }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  These are for use with GetControlClickActivation. The enumerated values should be pretty            }
{  self-explanatory, but just in case:                                                                 }
{  ¥ Activate/DoNotActivate indicates whether or not to change the owning window's z-ordering before   }
{      processing the click. If activation is requested, you may also want to immediately redraw the   }
{      newly exposed portion of the window.                                                            }
{  ¥ Ignore/Handle Click indicates whether or not to call an appropriate click handling API (like      }
{      HandleControlClick) in response to the event.                                                   }
const
	kDoNotActivateAndIgnoreClick = 0;    { probably never used. here for completeness.}
	kDoNotActivateAndHandleClick = 1;    { let the control handle the click while the window is still in the background.}
	kActivateAndIgnoreClick = 2;    { control doesn't want to respond directly to the click, but window should still be brought forward.}
	kActivateAndHandleClick = 3;     { control wants to respond to the click, but only after the window has been activated.}

type
	ClickActivationResult = UInt32;
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Common data tags for Get/SetControlData                                                           }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}

{
 *  Summary:
 *    Get/SetControlData Common Tags
 }
const
	kControlFontStyleTag = FourCharCode('font');
	kControlKeyFilterTag = FourCharCode('fltr');

  {
   * Sent with a pointer to a ControlKind record to be filled in.  Only
   * valid for GetControlData.
   }
	kControlKindTag = FourCharCode('kind');

  {
   * Sent with a pointer to a ControlSize. Only valid with explicitly
   * sizeable controls. Supported in 10.2 by the check box, combo box,
   * progress bar, indeterminate progress bar, radio button, round
   * button, scroll bar, slider and the tab. Check your return value
   * from SetControlData to determine if the control supports the size
   * that you requested.
   *
   * As of 10.2.5, the push button and DataBrowser accept this tag. The
   * DataBrowser only changes the size of its scrollbars.
   *
   * As of 10.3, the chasing arrows, disclosure button, popup button,
   * scroll view, search field and little arrows controls also accept
   * this tag.
   *
   * As of 10.4, if the font of the editable text has not been
   * overridden, the font size of the combo box and search field will
   * adjust to respect the size of the control. Also, if the font of a
   * static text control has not been overridden, the font size of the
   * static text control will respect the size of the control. Note,
   * however, that if the font _has_ been overridden (using
   * SetControlFontStyle), then these controls may return a control
   * size in response to GetControlData that is different from the
   * effective font size.
   *
   * As of 10.5, the bevel button control now supports the small
   * control size, and uses its control size to determine the size of
   * its popup menu arrow (if it has a menu associated with the
   * control). The default behavior is to use the width of the button
   * to determine whether to use a small or normal-sized arrow. This
   * behavior can be explicitly requested using kControlSizeAuto.
   * However, you may also use kControlSizeSmall and kControlSizeNormal
   * to explicitly request a small or normal-sized popup arrow.
   *
   *
   * Also as of 10.5, the group box now supports the normal, small, and
   * mini sizes. <BR><BR> Still check your return values!
   }
	kControlSizeTag = FourCharCode('size');

  {
   * Sent with a pointer to a ControlImageContentInfo (or
   * HIViewContentInfo) structure. Valid for both GetControlData and
   * SetControlData. All controls that support this tag will retain
   * refcountable image content when SetControlData is used to supply
   * new image content. Most controls that support this tag will not
   * retain refcountable image content when GetControlData is used to
   * retrieve image content; the exception is the tab control, which
   * does retain IconRef and CGImageRef content in response to
   * GetControlData. If you are implementing support for this tag in a
   * new view, you should retain refcountable image content when new
   * content is provided with SetControlData, but should not retain
   * refcountable image content when returning current image content in
   * response to GetControlData.
   }
	kControlContentTag = FourCharCode('cont');

  {
   * Sent with a pointer to a CTFontRef. Valid for both GetControlData
   * and SetControlData. The value of this CTFontRef must be retained
   * by the view when SetControlData is used and the view must retain
   * it when passing it back as a result of GetControlData. It is up to
   * the caller to release this value when it is no longer needed.
   }
	kControlThemeTextFontTag = FourCharCode('thft');

  {
   * Sent with a pointer to an HIThemeTextHorizontalFlush. Valid for
   * both GetControlData and SetControlData.
   }
	kControlThemeTextHorizontalFlushTag = FourCharCode('thhf');

  {
   * Sent with a pointer to an HIThemeTextVerticalFlush. Valid for both
   * GetControlData and SetControlData.
   }
	kControlThemeTextVerticalFlushTag = FourCharCode('thvf');

  {
   * Sent with a pointer to an HIThemeTextTruncation. Valid for both
   * GetControlData and SetControlData.
   }
	kControlThemeTextTruncationTag = FourCharCode('thtt');

  {
   * Sent with a pointer to an HIThemeTextInfo. Valid for
   * GetControlData. The version field of the HIThemeTextInfo must be
   * initialized to the version number of the structure that the client
   * is requesting the information for. When being requested with the
   * API HIViewGetThemeTextInfo, the version field will be initialized
   * to that which is given in the inVersion parameter.
   }
	kControlThemeTextInfoTag = FourCharCode('thti');

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Control Feature Bits                                                                              }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}

{
 *  Discussion:
 *    Control Feature Bits - Returned by GetControlFeatures
 *
 *    This list is similar to the list of HIView features in HIView.h.
 *    Historical note: This list is longer because some of these
 *    constants were introduced to enable the Control Manager to tell
 *    whether a CDEF supported a new CDEF message.
 }
const
	kControlSupportsGhosting = 1 shl 0;
	kControlSupportsEmbedding = 1 shl 1;
	kControlSupportsFocus = 1 shl 2;
	kControlWantsIdle = 1 shl 3;
	kControlWantsActivate = 1 shl 4;
	kControlHandlesTracking = 1 shl 5;
	kControlSupportsDataAccess = 1 shl 6;
	kControlHasSpecialBackground = 1 shl 7;
	kControlGetsFocusOnClick = 1 shl 8;
	kControlSupportsCalcBestRect = 1 shl 9;
	kControlSupportsLiveFeedback = 1 shl 10;
	kControlHasRadioBehavior = 1 shl 11; { Available in Appearance 1.0.1 or later}
	kControlSupportsDragAndDrop = 1 shl 12; { Available in Carbon}
	kControlAutoToggles = 1 shl 14; { Available in Appearance 1.1 or later}
	kControlSupportsGetRegion = 1 shl 17; { Available in Appearance 1.1 or later}
	kControlSupportsFlattening = 1 shl 19; { Available in Carbon}
	kControlSupportsSetCursor = 1 shl 20; { Available in Carbon}
	kControlSupportsContextualMenus = 1 shl 21; { Available in Carbon}
	kControlSupportsClickActivation = 1 shl 22; { Available in Carbon}
	kControlIdlesWithTimer = 1 shl 23; { Available in Carbon - this bit indicates that the control animates automatically}

  {
   * Reported by controls that expect clients to use an action proc
   * that increments its value when the up button is pressed and
   * decrement its value when the down button is pressed. (Most
   * controls, such as scroll bars and sliders, expect the opposite).
   * This allows the Control Manager to calculate the proper amount of
   * sleep time during a tracking loop. This is only respected in Mac
   * OS X 10.3 and later.
   }
	kControlInvertsUpDownValueMeaning = 1 shl 24;

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Control Messages                                                                                  }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Control Sizes                                                                     }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}

{
 *  Discussion:
 *    ControlSize values to be used in conjunction with SetControlData
 *    and the kControlSizeTag constant.
 }
const
{
   * Use the control's default drawing variant. This does not apply to
   * Scroll Bars, for which Normal is Large.
   }
	kControlSizeNormal = 0;

  {
   * Use the control's small drawing variant. Supported in 10.4 by the
   * Check Box, Combo Box, Disclosure Button, HIScrollView,
   * HISearchField, HISegmentedView, Little Arrows, Popup Button, Push
   * Button, Radio Button, Scroll Bar, Slider, Static Text, and Tab
   * controls. Supported in 10.5 by the Bevel Button and Group Box.
   }
	kControlSizeSmall = 1;

  {
   * Use the control's large drawing variant. Supported in 10.4 by the
   * Indeterminate Progress Bar, Progress Bar, Round Button, and Static
   * Text controls. Supported in 10.5 by the Chasing Arrows control.
   }
	kControlSizeLarge = 2;

  {
   * Use the control's miniature drawing variant. Supported in 10.4 by
   * the Check Box, Combo Box, Disclosure Button, HISearchField, Little
   * Arrows, Popup Button, Push Button, Radio Button, Slider, Static
   * Text, and Tabs controls. Supported in 10.5 by the Group Box
   * control.
   }
	kControlSizeMini = 3;

  {
   * Used by certain controls to support their legacy behavior of
   * drawing differently based on the control's bounds. Supported in
   * 10.4 by the Scroll Bar, Popup Button, Push Button, and Static Text
   * controls. Supported in 10.5 by the Bevel Button and Chasing Arrows
   * controls. It is preferred to explicitly use one of the available
   * control sizes.
   }
	kControlSizeAuto = $FFFF;

type
	ControlSize = UInt16;
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Constants for drawCntl message (passed in param)                                  }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
const
	kDrawControlEntireControl = 0;
	kDrawControlIndicatorOnly = 129;

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Drag Constraint Structure for thumbCntl message (passed in param)                 }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
type
	IndicatorDragConstraint = record
		limitRect: Rect;
		slopRect: Rect;
		axis: DragConstraint;
	end;
	IndicatorDragConstraintPtr = ^IndicatorDragConstraint;

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  Control Key Filter                                                                  }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{ Certain controls can have a keyfilter attached to them.                              }
{ Definition of a key filter for intercepting and possibly changing keystrokes         }
{ which are destined for a control.                                                    }
{ IMPORTANT! Because this filter provides WorldScript-encoded text in its parameters,  }
{ it provides no meaningful information for key events generated when a Unicode        }
{ keyboard layout or input method is active; these layouts and input methods generate  }
{ Unicode text that often cannot be translated into any WorldScript encoding. On       }
{ Mac OS X, you should avoid using this filter, or at most, use the filter as an       }
{ indication that the text is changing but do not depend on the charCode parameter to  }
{ the filter. Use a kEventTextInputUnicodeForKeyEvent Carbon event handler as a        }
{ replacement for the ControlKeyFilter callback; on Mac OS X 10.4 and later, you can   }
{ also use a kEventTextShouldChangeInRange or kEventTextDidChange event handler.       }
{ Key Filter Result Codes                                                          }
{ The filter proc should return one of the two constants below. If                 }
{ kKeyFilterBlockKey is returned, the key is blocked and never makes it to the     }
{ control. If kKeyFilterPassKey is returned, the control receives the keystroke.   }
const
	kControlKeyFilterBlockKey = 0;
	kControlKeyFilterPassKey = 1;

type
	ControlKeyFilterResult = SInt16;
	ControlKeyFilterProcPtr = function( theControl: ControlRef; var keyCode: SInt16; var charCode: SInt16; var modifiers: EventModifiers ): ControlKeyFilterResult;
	ControlKeyFilterUPP = ControlKeyFilterProcPtr;
{
 *  NewControlKeyFilterUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewControlKeyFilterUPP( userRoutine: ControlKeyFilterProcPtr ): ControlKeyFilterUPP; external name '_NewControlKeyFilterUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  DisposeControlKeyFilterUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeControlKeyFilterUPP( userUPP: ControlKeyFilterUPP ); external name '_DisposeControlKeyFilterUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  InvokeControlKeyFilterUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function InvokeControlKeyFilterUPP( theControl: ControlRef; var keyCode: SInt16; var charCode: SInt16; var modifiers: EventModifiers; userUPP: ControlKeyFilterUPP ): ControlKeyFilterResult; external name '_InvokeControlKeyFilterUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)


{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ DragGrayRgn Constants                                                             }
{   For DragGrayRgnUPP used in TrackControl()                                          }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
const
	noConstraint = kNoConstraint;
	hAxisOnly = 1;
	vAxisOnly = 2;

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Control Creation/Deletion/Persistence                                             }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}






{
 *  ControlID
 *
 *  Summary:
 *    A unique identifier for a control in a window.
 }
type
	ControlIDPtr = ^ControlID;
	ControlID = record
{
   * A four-character signature. When assigning a control ID to your
   * own controls, you should typically use your application signature
   * here, or some other signature with an uppercase character. Apple
   * reserves signatures that contain only lowercase characters.
   }
		signature: OSType;

  {
   * A integer identifying the control. This value should be unique for
   * a given control across all controls in the same window with the
   * same signature.
   }
		id: SInt32;
	end;

type
	ControlKindPtr = ^ControlKind;
	ControlKind = record
		signature: OSType;
		kind: OSType;
	end;

{
 *  Discussion:
 *    Control signature kind
 }
const
{
   * Signature of all system controls.
   }
	kControlKindSignatureApple = FourCharCode('appl');


const
	kControlPropertyPersistent = $00000001; { whether this property gets saved when flattening the control}


{
 *  Discussion:
 *    DragTrackingMessage values for use with
 *    HandleControlDragTracking. These are deprecated in favor of the
 *    drag Carbon Events introduced in Mac OS X 10.2 via HIView.
 }
const
{
   * The drag was previously outside the control and it just now
   * entered the control.
   }
	kDragTrackingEnterControl = 2;

  {
   * The drag was previously inside the control and it is still inside
   * the control.
   }
	kDragTrackingInControl = 3;

  {
   * The drag was previously inside the control and it just now left
   * the control.
   }
	kDragTrackingLeaveControl = 4;



(*
#if OLDROUTINENAMES
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ OLDROUTINENAMES                                                                   }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
const
	useWFont = kControlUsesOwningWindowsFontVariant;

const
	inThumb = kControlIndicatorPart;
	kNoHiliteControlPart = kControlNoPart;
	kInIndicatorControlPart = kControlIndicatorPart;
	kReservedControlPart = kControlDisabledPart;
	kControlInactiveControlPart = kControlInactivePart;


#define SetCTitle(theControl, title) SetControlTitle(theControl, title)
#define GetCTitle(theControl, title) GetControlTitle(theControl, title)
#define UpdtControl(theWindow, updateRgn) UpdateControls(theWindow, updateRgn)
#define SetCtlValue(theControl, theValue) SetControlValue(theControl, theValue)
#define GetCtlValue(theControl) GetControlValue(theControl)
#define SetCtlMin(theControl, minValue) SetControlMinimum(theControl, minValue)
#define GetCtlMin(theControl) GetControlMinimum(theControl)
#define SetCtlMax(theControl, maxValue) SetControlMaximum(theControl, maxValue)
#define GetCtlMax(theControl) GetControlMaximum(theControl)
#define GetAuxCtl(theControl, acHndl) GetAuxiliaryControlRecord(theControl, acHndl)
#define SetCRefCon(theControl, data) SetControlReference(theControl, data)
#define GetCRefCon(theControl) GetControlReference(theControl)
#define SetCtlAction(theControl, actionProc) SetControlAction(theControl, actionProc)
#define GetCtlAction(theControl) GetControlAction(theControl)
#define SetCtlColor(theControl, newColorTable) SetControlColor(theControl, newColorTable)
#define GetCVariant(theControl) GetControlVariant(theControl)
#define getctitle(theControl, title) getcontroltitle(theControl, title)
#define setctitle(theControl, title) setcontroltitle(theControl, title)
#endif  { OLDROUTINENAMES }
*)

{ Getters }

{--------------------------------------------------------------------------------------}
{  ¥ DEPRECATED                                                                        }
{  All functions below this point are either deprecated (they continue to function     }
{  but are not the most modern nor most efficient solution to a problem), or they are  }
{  completely unavailable on Mac OS X.                                                 }
{--------------------------------------------------------------------------------------}



{$endc} {not TARGET_OS_MAC}

{$ifc not defined MACOSALLINCLUDE or not MACOSALLINCLUDE}

end.
{$endc} {not MACOSALLINCLUDE}
