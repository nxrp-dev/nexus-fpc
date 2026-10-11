{
     File:       HIToolbox/HIButtonViews.h

     Contains:   Definitions of the button views provided by HIToolbox.

     Version:    HIToolbox-624~3

     Copyright:  © 2006-2008 by Apple Computer, Inc., all rights reserved.

     Bugs?:      For bug reports, consult the following page on
                 the World Wide Web:

                     http://bugs.freepascal.org

}
{       Initial Pascal Translation:  Jonas Maebe, <jonas@freepascal.org>, October 2009 }
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
unit HIButtonViews;
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
uses MacOsApi.MacTypes,MacOsApi.Appearance,MacOsApi.CarbonEvents,MacOsApi.Controls,MacOsApi.IconsCore,MacOsApi.Icons,MacOsApi.Menus,MacOsApi.QuickdrawTypes,MacOsApi.TextEdit,MacOsApi.CFBase,MacOsApi.HIObject;
{$ELSE FPC_DOTTEDUNITS}
uses MacTypes,Appearance,CarbonEvents,Controls,IconsCore,Icons,Menus,QuickdrawTypes,TextEdit,CFBase,HIObject;
{$ENDIF FPC_DOTTEDUNITS}
{$endc} {not MACOSALLINCLUDE}


{$ifc TARGET_OS_MAC}

{$ALIGN POWER}


{
 *  HIButtonViews.h
 *
 *  Discussion:
 *    API definitions for the simple button views provided by
 *    HIToolbox: pushbutton, checkbox, radio button and radio group,
 *    bevel button, and round button.
 }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{   PUSH BUTTON (CDEF 23)                                                              }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  Two new variants of the standard pushbutton have been added to the standard control }
{  suite that draw a color icon next to the control title. One variant draws the icon  }
{  on the left side, the other draws it on the right side (when the system justifica-  }
{  tion is right to left, these are reversed).                                         }
{  When either of the icon pushbuttons are created, the contrlMax field of the control }
{  record is used to determine the ID of the 'cicn' resource drawn in the pushbutton.  }
{  In addition, a push button can now be told to draw with a default outline using the }
{  SetControlData routine with the kControlPushButtonDefaultTag below.                 }
{  A push button may also be marked using the kControlPushButtonCancelTag. This has    }
{  no visible representation, but does cause the button to play the CancelButton theme }
{  sound instead of the regular pushbutton theme sound when pressed.                   }
{ Push Button proc IDs }
const
	kControlPushButtonProc = 368;
	kControlPushButLeftIconProc = 374;  { Standard pushbutton with left-side icon}
	kControlPushButRightIconProc = 375;   { Standard pushbutton with right-side icon}

{ Push Button Icon Alignments }
type
	ControlPushButtonIconAlignment = UInt16;
const
	kControlPushButtonIconOnLeft = 6;
	kControlPushButtonIconOnRight = 7;

{ Control Kind Tag }
const
	kControlKindPushButton = FourCharCode('push');
	kControlKindPushIconButton = FourCharCode('picn');

{ The HIObject class ID for the HIPushButton class. }
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kHIPushButtonClassID CFSTRP('com.apple.HIPushButton')}
{$endc}
{ Creation APIs: Carbon Only }


{
 *  Summary:
 *    Tagged data supported by standard buttons
 }
const
{
   * Data is a Boolean indicating if a push button is a default button.
   * If so, the button will draw with the appropriate appearance.
   * Available in Mac OS 8.5 and later.
   }
	kControlPushButtonDefaultTag = FourCharCode('dflt');

  {
   * Data is a Boolean indicating if a push button is a cancel button.
   * If so, the button will draw with an appropriate appearance.
   * Available in Mac OS 8.5 and later.
   }
	kControlPushButtonCancelTag = FourCharCode('cncl');

  {
   * Data is a ControlButtonContentInfo or HIViewContentInfo structure.
   * May be used to set or retrieve a button's image content. Available
   * in Mac OS X 10.4 and later. In Mac OS X 10.4, the push button
   * supports the kControlContentCIconRes and kControlContentCGImageRef
   * content types. In Mac OS X 10.5 and later, the push button also
   * supports IconRef content.
   }
	kControlPushButtonContentTag = kControlContentTag;

  {
   * Data is a ControlPushButtonIconAlignment indicating the desired
   * alignment for the button's image content. Applies to all types of
   * image content that may be associated with the push button, not
   * just icons. Available in Mac OS X 10.4 and later.
   }
	kControlPushButtonIconAlignmentTag = FourCharCode('cpia');

  {
   * Data is a Boolean indicating if a push button should animate. Will
   * be True by default even if the button is not a default button and
   * is not currently pulsing. Available in Mac OS X 10.5 and later.
   }
	kControlPushButtonAnimatingTag = FourCharCode('anim');


{
 *  Summary:
 *    Tagged data supported by push buttons
 *
 *  Discussion:
 *    This new tag is available on Mac OS X 10.4 and later. The
 *    constant is not in the Mac OS X 10.4 and Mac OS X 10.5 headers,
 *    but the constant value is functional on both releases.
 }
const
{
   * Data is a Boolean indicating if a push button is a textured push
   * button, to be drawn on a textured window. Textured was previously
   * referred to as "metal". This attribute is only to be set on push
   * buttons being used in composited windows.
   }
	kControlPushButtonIsTexturedTag = FourCharCode('metl');

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{   CHECKBOX (CDEF 23)                                                             }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  The standard checkbox view supports a "mixed" value that indicates that the         }
{  current setting contains a mixed set of on and off values. The control value used   }
{  to display this indication is defined below:                                        }
{      kControlCheckBoxMixedValue = 2                                                  }
{ Check Box proc ID }
const
	kControlCheckBoxProc = 369;

{ Variants with Appearance 1.1 or later }
const
	kControlCheckBoxAutoToggleProc = 371;

{ Control Kind Tag }
const
	kControlKindCheckBox = FourCharCode('cbox');

{ The HIObject class ID for the HICheckBox class. }
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kHICheckBoxClassID CFSTRP('com.apple.HICheckBox')}
{$endc}

const
	kControlCheckBoxUncheckedValue = 0;
	kControlCheckBoxCheckedValue = 1;
	kControlCheckBoxMixedValue = 2;


{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{   RADIO BUTTON (CDEF 23)                                                         }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  The standard radio button control supports a "mixed" value that indicates that the  }
{  current setting contains a mixed set of on and off values. The control value used   }
{  to display this indication is defined below:                                        }
{      kControlRadioButtonMixedValue = 2                                               }
{ Radio Button proc IDs }
const
	kControlRadioButtonProc = 370;

{ Variants with Appearance 1.1 or later }
const
	kControlRadioButtonAutoToggleProc = 372;

{ Radio Button Values }
const
	kControlRadioButtonUncheckedValue = 0;
	kControlRadioButtonCheckedValue = 1;
	kControlRadioButtonMixedValue = 2;

{ Control Kind Tag }
const
	kControlKindRadioButton = FourCharCode('rdio');

{ The HIObject class ID for the HIRadioButton class. }
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kHIRadioButtonClassID CFSTRP('com.apple.HIRadioButton')}
{$endc}

const
	kControlRadioGroupProc = 416;

{ Control Kind Tag }
const
	kControlKindRadioGroup = FourCharCode('rgrp');

{ The HIObject class ID for the HIRadioGroup class. }
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kHIRadioGroupClassID CFSTRP('com.apple.HIRadioGroup')}
{$endc}
{ Creation API: Carbon Only }

const
	kControlBevelButtonSmallBevelProc = 32;
	kControlBevelButtonNormalBevelProc = 33;
	kControlBevelButtonLargeBevelProc = 34;

{ Add these variant codes to kBevelButtonSmallBevelProc to change the type of button }
const
	kControlBevelButtonSmallBevelVariant = 0;
	kControlBevelButtonNormalBevelVariant = 1 shl 0;
	kControlBevelButtonLargeBevelVariant = 1 shl 1;
	kControlBevelButtonMenuOnRightVariant = 1 shl 2;

{ Bevel Thicknesses }
type
	ControlBevelThickness = UInt16;
const
	kControlBevelButtonSmallBevel = 0;
	kControlBevelButtonNormalBevel = 1;
	kControlBevelButtonLargeBevel = 2;

{ Behaviors of bevel buttons. These are set up so you can add  }
{ them together with the content types for use in the Min      }
{ parameter of NewControl. Note that the behavior of a bevel   }
{ button cannot be changed after the button is created.        }
const
	kControlBehaviorPushbutton = 0;
	kControlBehaviorToggles = $0100;
	kControlBehaviorSticky = $0200;
	kControlBehaviorOffsetContents = $8000;
	kControlBehaviorSingleValueMenu = 0;
	kControlBehaviorMultiValueMenu = $4000; { only makes sense when a menu is attached.}

{ Behaviors for 1.0.1 or later }
const
	kControlBehaviorCommandMenu = $2000; { menu holds commands, not choices. Overrides multi-value bit.}

type
	ControlBevelButtonBehavior = UInt16;
	ControlBevelButtonMenuBehavior = UInt16;
{ Bevel Button Menu Placements }
type
	ControlBevelButtonMenuPlacement = UInt16;
const
	kControlBevelButtonMenuOnBottom = 0;
	kControlBevelButtonMenuOnRight = 1 shl 2;

{ Control Kind Tag }
const
	kControlKindBevelButton = FourCharCode('bevl');

{ The HIObject class ID for the HIBevelButton class. }
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kHIBevelButtonClassID CFSTRP('com.apple.HIBevelButton')}
{$endc}
{ Creation API: Carbon Only }

type
	ControlButtonGraphicAlignment = SInt16;
const
	kControlBevelButtonAlignSysDirection = -1; { only left or right}
	kControlBevelButtonAlignCenter = 0;
	kControlBevelButtonAlignLeft = 1;
	kControlBevelButtonAlignRight = 2;
	kControlBevelButtonAlignTop = 3;
	kControlBevelButtonAlignBottom = 4;
	kControlBevelButtonAlignTopLeft = 5;
	kControlBevelButtonAlignBottomLeft = 6;
	kControlBevelButtonAlignTopRight = 7;
	kControlBevelButtonAlignBottomRight = 8;

{ Text Alignments }
type
	ControlButtonTextAlignment = SInt16;
const
	kControlBevelButtonAlignTextSysDirection = teFlushDefault;
	kControlBevelButtonAlignTextCenter = teCenter;
	kControlBevelButtonAlignTextFlushRight = teFlushRight;
	kControlBevelButtonAlignTextFlushLeft = teFlushLeft;

{ Text Placements }
type
	ControlButtonTextPlacement = SInt16;
const
	kControlBevelButtonPlaceSysDirection = -1; { if graphic on right, then on left}
	kControlBevelButtonPlaceNormally = 0;
	kControlBevelButtonPlaceToRightOfGraphic = 1;
	kControlBevelButtonPlaceToLeftOfGraphic = 2;
	kControlBevelButtonPlaceBelowGraphic = 3;
	kControlBevelButtonPlaceAboveGraphic = 4;


{ Data tags supported by the bevel button controls }
const
	kControlBevelButtonContentTag = kControlContentTag; { ControlImageContentInfo}
	kControlBevelButtonTransformTag = FourCharCode('tran'); { IconTransformType}
	kControlBevelButtonTextAlignTag = FourCharCode('tali'); { ButtonTextAlignment}
	kControlBevelButtonTextOffsetTag = FourCharCode('toff'); { SInt16}
	kControlBevelButtonGraphicAlignTag = FourCharCode('gali'); { ButtonGraphicAlignment}
	kControlBevelButtonGraphicOffsetTag = FourCharCode('goff'); { Point}
	kControlBevelButtonTextPlaceTag = FourCharCode('tplc'); { ButtonTextPlacement}
	kControlBevelButtonMenuValueTag = FourCharCode('mval'); { SInt16}
	kControlBevelButtonMenuHandleTag = FourCharCode('mhnd'); { MenuRef}
	kControlBevelButtonMenuRefTag = FourCharCode('mhnd'); { MenuRef}
	kControlBevelButtonCenterPopupGlyphTag = FourCharCode('pglc'); { Boolean: true = center, false = bottom right}

{ These are tags in 1.0.1 or later }
const
	kControlBevelButtonLastMenuTag = FourCharCode('lmnu'); { SInt16: menuID of last menu item selected from}
	kControlBevelButtonMenuDelayTag = FourCharCode('mdly'); { SInt32: ticks to delay before menu appears}

{ tags available with Appearance 1.1 or later }
const
{ Boolean: True = if an icon of the ideal size for}
                                        { the button isn't available, scale a larger or}
                                        { smaller icon to the ideal size. False = don't}
                                        { scale; draw a smaller icon or clip a larger icon.}
                                        { Default is false. Only applies to IconSuites and}
	kControlBevelButtonScaleIconTag = FourCharCode('scal'); { IconRefs.}

{ tags available in Mac OS X and later }
const
	kControlBevelButtonOwnedMenuRefTag = FourCharCode('omrf'); { MenuRef (control will dispose)}
	kControlBevelButtonKindTag = FourCharCode('bebk'); { ThemeButtonKind ( kTheme[Small,Medium,Large,Rounded]BevelButton )}


{
 *  Summary:
 *    Tags available with Mac OS X 10.3 or later
 }
const
{
   * Passed data is an Boolean.  Gets or sets whether or not the
   * associated menu is a multi-value menu or not.  True means that the
   * menu can have multiple selections.
   }
	kControlBevelButtonIsMultiValueMenuTag = FourCharCode('mult');

{ Helper routines are available only thru the shared library/glue. }


{
 *  ControlRoundButtonSize
 *
 *  Discussion:
 *    Button Sizes
 }
type
	ControlRoundButtonSize = SInt16;
const
{
   * A 20 pixel diameter button.
   }
	kControlRoundButtonNormalSize = kControlSizeNormal;

  {
   * A 25 pixel diameter button.
   }
	kControlRoundButtonLargeSize = kControlSizeLarge;

{ Data tags supported by the round button controls }
const
	kControlRoundButtonContentTag = kControlContentTag; { ControlImageContentInfo}
	kControlRoundButtonSizeTag = kControlSizeTag; { ControlRoundButtonSize}

{ Control Kind Tag }
const
	kControlKindRoundButton = FourCharCode('rndb');

{ The HIObject class ID for the HIRoundButton class. }
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kHIRoundButtonClassID CFSTRP('com.apple.HIRoundButton')}
{$endc}

{$ifc OLDROUTINENAMES}
const
	kControlCheckboxUncheckedValue = kControlCheckBoxUncheckedValue;
	kControlCheckboxCheckedValue = kControlCheckBoxCheckedValue;
	kControlCheckboxMixedValue = kControlCheckBoxMixedValue;

{$endc}  { OLDROUTINENAMES }

{$endc} {TARGET_OS_MAC}
{$ifc not defined MACOSALLINCLUDE or not MACOSALLINCLUDE}

end.
{$endc} {not MACOSALLINCLUDE}
