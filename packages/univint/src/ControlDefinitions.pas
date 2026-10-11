{
     File:       HIToolbox/ControlDefinitions.h

     Contains:   Definitions of controls provided by the Control Manager

     Version:    HIToolbox-624~3

     Copyright:  © 1999-2008 by Apple Computer, Inc., all rights reserved.

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
unit ControlDefinitions;
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
uses MacOsApi.MacTypes,MacOsApi.TextEdit,MacOsApi.AXUIElement,MacOsApi.AEDataModel,MacOsApi.CFBase,MacOsApi.Events,MacOsApi.QuickdrawTypes,MacOsApi.IconsCore,MacOsApi.CFData,MacOsApi.CFDictionary,MacOsApi.CFString,MacOsApi.DateTimeUtils,MacOsApi.Drag,MacOsApi.TextCommon,MacOsApi.Appearance,MacOsApi.CarbonEvents,MacOsApi.Controls,MacOsApi.Lists,MacOsApi.MacHelp,MacOsApi.Menus,MacOsApi.HIObject;
{$ELSE FPC_DOTTEDUNITS}
uses MacTypes,TextEdit,AXUIElement,AEDataModel,CFBase,Events,QuickdrawTypes,IconsCore,CFData,CFDictionary,CFString,DateTimeUtils,Drag,TextCommon,Appearance,CarbonEvents,Controls,Lists,MacHelp,Menus,HIObject;
{$ENDIF FPC_DOTTEDUNITS}
{$endc} {not MACOSALLINCLUDE}


{$ifc TARGET_OS_MAC}

{$ALIGN MAC68K}


{
 *  ControlDefinitions.h
 *
 *  Discussion:
 *    System software supplies a variety of controls for your
 *    applications to use. They are described herein.
 }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Control Definition IDÕs                                                                           }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{ Standard System 7 procIDs}

const
	pushButProc = 0;
	checkBoxProc = 1;
	radioButProc = 2;
	scrollBarProc = 16;
	popupMenuProc = 1008;

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Control Part Codes                                                                }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
const
	kControlLabelPart = 1;
	kControlMenuPart = 2;
	kControlTrianglePart = 4;
	kControlEditTextPart = 5;    { Appearance 1.0 and later}
	kControlPicturePart = 6;    { Appearance 1.0 and later}
	kControlIconPart = 7;    { Appearance 1.0 and later}
	kControlClockPart = 8;    { Appearance 1.0 and later}
	kControlListBoxPart = 24;   { Appearance 1.0 and later}
	kControlListBoxDoubleClickPart = 25;  { Appearance 1.0 and later}
	kControlImageWellPart = 26;   { Appearance 1.0 and later}
	kControlRadioGroupPart = 27;   { Appearance 1.0.2 and later}
	kControlButtonPart = 10;
	kControlCheckBoxPart = 11;
	kControlRadioButtonPart = 11;
	kControlUpButtonPart = kAppearancePartUpButton;
	kControlDownButtonPart = kAppearancePartDownButton;
	kControlPageUpPart = kAppearancePartPageUpArea;
	kControlPageDownPart = kAppearancePartPageDownArea;
	kControlClockHourDayPart = 9;    { Appearance 1.1 and later}
	kControlClockMinuteMonthPart = 10;   { Appearance 1.1 and later}
	kControlClockSecondYearPart = 11;   { Appearance 1.1 and later}
	kControlClockAMPMPart = 12;   { Appearance 1.1 and later}
	kControlDataBrowserPart = 24;   { CarbonLib 1.0 and later}
	kControlDataBrowserDraggedPart = 25;   { CarbonLib 1.0 and later}

{--------------------------------------------------------------------------------------}
{  ¥ DEPRECATED                                                                        }
{  All functions below this point are either deprecated (they continue to function     }
{  but are not the most modern nor most efficient solution to a problem), or they are  }
{  completely unavailable on Mac OS X.                                                 }
{--------------------------------------------------------------------------------------}
{
  ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ
    ¥ EDIT TEXT (CDEF 17)
  ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ
    Use the EditUnicodeText control to replace the Edit Text control. It uses the same
    data tags as the Edit Text control.
}

{ Edit Text proc IDs }
const
	kControlEditTextProc = 272;
	kControlEditTextPasswordProc = 274;

{ proc IDs available with Appearance 1.1 or later }
const
	kControlEditTextInlineInputProc = 276; { Can't combine with the other variants}

{ Control Kind Tag }
const
	kControlKindEditText = FourCharCode('etxt');


const
	kControlEditTextTEHandleTag = FourCharCode('than'); { The TEHandle of the text edit record}
	kControlEditTextInlinePreUpdateProcTag = FourCharCode('prup'); { TSMTEPreUpdateUPP and TSMTEPostUpdateUpp. For use with inline input variant...}
	kControlEditTextInlinePostUpdateProcTag = FourCharCode('poup'); { ...The refCon parameter will contain the ControlRef.}

{
    The classic EditText control also supports these tags defined for the EditUnicodeText control:

        kControlEditTextLockedTag
        kControlEditTextStyleTag
        kControlEditTextFixedTextTag
        kControlEditTextTextTag
        kControlEditTextKeyFilterTag
        kControlEditTextValidationProcTag
        kControlEditTextSelectionTag
        kControlEditTextKeyScriptBehaviorTag
        kControlEditTextCFStringTag
        kControlEditTextPasswordTag
        kControlEditTextPasswordCFStringTag
}

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ PICTURE CONTROL (CDEF 19)                                                         }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  Value parameter should contain the ID of the picture you wish to display when       }
{  creating controls of this type. If you don't want the control tracked at all, use   }
{  the 'no track' variant.                                                             }
{ Picture control proc IDs }
const
	kControlPictureProc = 304;
	kControlPictureNoTrackProc = 305;   { immediately returns kControlPicturePart}

{ Control Kind Tag }
const
	kControlKindPicture = FourCharCode('pict');

{ The HIObject class ID for the HIPictureView class. }
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kHIPictureViewClassID CFSTRP('com.apple.HIPictureView')}
{$endc}

const
	kControlPictureHandleTag = FourCharCode('pich'); { PicHandle}

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ LIST BOX (CDEF 22)                                                                }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  Lists use an auxiliary resource to define their format. The resource type used is   }
{  'ldes' and a definition for it can be found in Appearance.r. The resource ID for    }
{  the ldes is passed in the 'value' parameter when creating the control. You may pass }
{  zero in value. This tells the List Box control to not use a resource. The list will }
{  be created with default values, and will use the standard LDEF (0). You can change  }
{  the list by getting the list handle. You can set the LDEF to use by using the tag   }
{  below (kControlListBoxLDEFTag)                                                      }
{ List Box proc IDs }
const
	kControlListBoxProc = 352;
	kControlListBoxAutoSizeProc = 353;

{ Control Kind Tag }
const
	kControlKindListBox = FourCharCode('lbox');


const
	kControlListBoxListHandleTag = FourCharCode('lhan'); { ListHandle}
	kControlListBoxKeyFilterTag = kControlKeyFilterTag; { ControlKeyFilterUPP}
	kControlListBoxFontStyleTag = kControlFontStyleTag; { ControlFontStyleRec}

{ New tags in 1.0.1 or later }
const
	kControlListBoxDoubleClickTag = FourCharCode('dblc'); { Boolean. Was last click a double-click?}
	kControlListBoxLDEFTag = FourCharCode('ldef'); { SInt16. ID of LDEF to use.}

{ Resource Types }
const
	kControlListDescResType = FourCharCode('ldes'); { used for list box control (Appearance 1.0 and later)}

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ SCROLL TEXT BOX (CDEF 27)                                                         }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  This control implements a scrolling box of (non-editable) text. This is useful for  }
{  credits in about boxes, etc.                                                        }
{  The standard version of this control has a scroll bar, but the autoscrolling        }
{  variant does not. The autoscrolling variant needs two pieces of information to      }
{  work: delay (in ticks) before the scrolling starts, and time (in ticks) between     }
{  scrolls. It will scroll one pixel at a time, unless changed via SetControlData.     }
{  Parameter                   What Goes Here                                          }
{  ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ         ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ    }
{  Value                       Resource ID of 'TEXT'/'styl' content.                   }
{  Min                         Scroll start delay (in ticks)                       .   }
{  Max                         Delay (in ticks) between scrolls.                       }
{  NOTE: This control is only available with Appearance 1.1.                           }
{ Scroll Text Box Proc IDs }
const
	kControlScrollTextBoxProc = 432;
	kControlScrollTextBoxAutoScrollProc = 433;

{ Control Kind Tag }
const
	kControlKindScrollingTextBox = FourCharCode('stbx');


const
	kControlScrollTextBoxDelayBeforeAutoScrollTag = FourCharCode('stdl'); { UInt32 (ticks until autoscrolling starts)}
	kControlScrollTextBoxDelayBetweenAutoScrollTag = FourCharCode('scdl'); { UInt32 (ticks between scrolls)}
	kControlScrollTextBoxAutoScrollAmountTag = FourCharCode('samt'); { UInt16 (pixels per scroll) -- defaults to 1}
	kControlScrollTextBoxContentsTag = FourCharCode('tres'); { SInt16 (resource ID of 'TEXT'/'styl') -- write only!}
	kControlScrollTextBoxAnimatingTag = FourCharCode('anim'); { Boolean (whether the text box should auto-scroll)}

{$ifc OLDROUTINENAMES}
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ OLDROUTINENAMES                                                                   }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
const
	inLabel = kControlLabelPart;
	inMenu = kControlMenuPart;
	inTriangle = kControlTrianglePart;
	inButton = kControlButtonPart;
	inCheckBox = kControlCheckBoxPart;
	inUpButton = kControlUpButtonPart;
	inDownButton = kControlDownButtonPart;
	inPageUp = kControlPageUpPart;
	inPageDown = kControlPageDownPart;

const
	kInLabelControlPart = kControlLabelPart;
	kInMenuControlPart = kControlMenuPart;
	kInTriangleControlPart = kControlTrianglePart;
	kInButtonControlPart = kControlButtonPart;
	kInCheckBoxControlPart = kControlCheckBoxPart;
	kInUpButtonControlPart = kControlUpButtonPart;
	kInDownButtonControlPart = kControlDownButtonPart;
	kInPageUpControlPart = kControlPageUpPart;
	kInPageDownControlPart = kControlPageDownPart;


{$endc}  {OLDROUTINENAMES}


{$endc} {TARGET_OS_MAC}
{$ifc not defined MACOSALLINCLUDE or not MACOSALLINCLUDE}

end.
{$endc} {not MACOSALLINCLUDE}
