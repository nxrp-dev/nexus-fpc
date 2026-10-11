{
     File:       HIToolbox/MacTextEditor.h

     Contains:   Interfaces for Multilingual Text Engine (MLTE)

     Version:    HIToolbox-624~3

     Copyright:  © 1996-2008 by Apple Computer, Inc., all rights reserved.

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
unit MacTextEditor;
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
uses MacOsApi.MacTypes,MacOsApi.CFBase,MacOsApi.CFURL,MacOsApi.CFArray,MacOsApi.CFData,MacOsApi.CFString,MacOsApi.CFDictionary,MacOsApi.CGBase,MacOsApi.AEDataModel,MacOsApi.TextCommon,MacOsApi.QuickdrawTypes,MacOsApi.QDOffscreen,MacOsApi.Menus,MacOsApi.ATSUnicodeTypes,MacOsApi.ConditionalMacros,MacOsApi.Drag,MacOsApi.MacWindows,MacOsApi.Files,MacOsApi.Events,MacOsApi.MacErrors,MacOsApi.CarbonEvents,MacOsApi.HIObject,MacOsApi.HIView,MacOsApi.HIGeometry;
{$ELSE FPC_DOTTEDUNITS}
uses MacTypes,CFBase,CFURL,CFArray,CFData,CFString,CFDictionary,CGBase,AEDataModel,TextCommon,QuickdrawTypes,QDOffscreen,Menus,ATSUnicodeTypes,ConditionalMacros,Drag,MacWindows,Files,Events,MacErrors,CarbonEvents,HIObject,HIView,HIGeometry;
{$ENDIF FPC_DOTTEDUNITS}
{$endc} {not MACOSALLINCLUDE}

{$ALIGN POWER}

{$ifc TARGET_OS_MAC}

{$ALIGN MAC68K}


{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Various Defs                                                                                      }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
type
	TXNObject = ^OpaqueTXNObject; { an opaque type }
	OpaqueTXNObject = record end;
	TXNObjectPtr = ^TXNObject;  { when a var xx:TXNObject parameter can be nil, it is changed to xx: TXNObjectPtr }
type
	TXNVersionValue = UInt32;

{
 *  TXNFrameID
 *
 *  Summary:
 *    Deprecated.  Pass NULL for any API which uses this type as a
 *    parameter.
 }
type
	TXNFrameID = UInt32;
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Error Status                                                                                      }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  MLTE status errors assigned is -22000 through -22039.  See MacErrors.h for -22000 to -22018.        }

const
	kTXNDisabledFunctionalityErr = -22019; { This routine's functionality is disabled.}
	kTXNOperationNotAllowedErr = -22020; { Returned by MLTE API if function cannot be applied. }

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Feature Bits                                                                                      }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  Useful for the TXNVersionInformation API.                                                           }

const
	kTXNWillDefaultToATSUIBit = 0;
	kTXNWillDefaultToCarbonEventBit = 1;   { Ignored - Carbon events are always used in Mac OS X version 10.1 and later.}

type
	TXNFeatureBits = OptionBits;
const
	kTXNWillDefaultToATSUIMask = 1 shl kTXNWillDefaultToATSUIBit;
	kTXNWillDefaultToCarbonEventMask = 1 shl kTXNWillDefaultToCarbonEventBit;

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ FrameOption Bits                                                                                  }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  Useful for the TXNNewObject and TXNCreateObject APIs.                                               }

const
	kTXNDrawGrowIconBit = 0;
	kTXNShowWindowBit = 1;
	kTXNWantHScrollBarBit = 2;
	kTXNWantVScrollBarBit = 3;
	kTXNReadOnlyBit = 5;
	kTXNNoSelectionBit = 7;
	kTXNSaveStylesAsSTYLResourceBit = 8;
	kOutputTextInUnicodeEncodingBit = 9;
	kTXNDoNotInstallDragProcsBit = 10;
	kTXNAlwaysWrapAtViewEdgeBit = 11;
	kTXNDontDrawSelectionWhenInactiveBit = 13;
	kTXNSingleLineOnlyBit = 14;
	kTXNDisableDragAndDropBit = 15;
	kTXNMonostyledTextBit = 17;
	kTXNDoFontSubstitutionBit = 22;


{
 *  TXNFrameOptions
 *
 *  Summary:
 *    Defines the initial behavior of an MLTE object created with
 *    TXNCreateObject/TXNNewObject.
 *
 *  Discussion:
 *    These masks can be combined and passed to
 *    TXNCreateObject/TXNNewObject to define the initial behavior of a
 *    new object.
 }
type
	TXNFrameOptions = OptionBits;
const
{
   * Indicates that the frame will have a size box.
   }
	kTXNDrawGrowIconMask = 1 shl kTXNDrawGrowIconBit;

  {
   * Indicates that the window associated with the text object will be
   * displayed when the object is created.  The application no longer
   * needs to call the ShowWindow function from the Window Manager;
   * MLTE will do this for you.
   }
	kTXNShowWindowMask = 1 shl kTXNShowWindowBit;

  {
   * Indicates that the frame will have a horizontal scrollbar. The
   * scrollbar will be enabled upon creation.  If there are multiple
   * MLTE objects in the same window, the client will need to
   * explicitly disable the scrollbars for those inactive MLTE objects.
   *  Use TXNSetScrollbarState to deactivate the scrollbar.
   }
	kTXNWantHScrollBarMask = 1 shl kTXNWantHScrollBarBit;

  {
   * Indicates that the frame will have a vertical scrollbar. The
   * scrollbar will be enabled upon creation.  If there are multiple
   * MLTE objects in the same window, the client will need to
   * explicitly disable the scrollbars for those inactive MLTE objects.
   *  Use TXNSetScrollbarState to deactivate the scrollbar.
   }
	kTXNWantVScrollBarMask = 1 shl kTXNWantVScrollBarBit;

  {
   * Indicates that the text object will be read-only.  It is
   * equivalent to setting the object into NoUserIO mode, via the tag
   * kTXNNoUserIOTag in TXNSetTXNObjectControls. See description in
   * individual API to determine if the API will still work in NoUserIO
   * mode.
   }
	kTXNReadOnlyMask = 1 shl kTXNReadOnlyBit;

  {
   * Indicates that the user shouldn't be able to set the insertion
   * point or make a selection.
   }
	kTXNNoSelectionMask = 1 shl kTXNNoSelectionBit;

  {
   * Indicates that the text style will be saved as a
   * kTXNMultipleStylesPerTextDocumentResType resource.  You can set
   * this to assure compatibility with SimpleText.  If you use
   * kTXNMultipleStylesPerTextDocumentResType resources to save style
   * info, your documents can have as many styles as you'd like.
   * However tabs are not saved.  If you don't use this mask, plain
   * text files are saved as kTXNSingleStylePerTextDocumentResType
   * resources, and only the first style in the document is saved.
   * (Your application is expected to apply all style changes to the
   * entire document.)  If you save files with a
   * kTXNSingleStylePerTextDocumentResType resource, their output is
   * similar to those output by CodeWarrior, BBEdit, and MPW.
   }
	kTXNSaveStylesAsSTYLResourceMask = 1 shl kTXNSaveStylesAsSTYLResourceBit;

  {
   * Indicates that plain text will be saved as Unicode.
   }
	kOutputTextInUnicodeEncodingMask = 1 shl kOutputTextInUnicodeEncodingBit;

  {
   * Indicates that MLTE will not install its own drag handler for the
   * text object.  This can be used if the client wants to install
   * their own handler.
   }
	kTXNDoNotInstallDragProcsMask = 1 shl kTXNDoNotInstallDragProcsBit;

  {
   * Indicates that lines will wrap at the edge of the view rectangle.
   }
	kTXNAlwaysWrapAtViewEdgeMask = 1 shl kTXNAlwaysWrapAtViewEdgeBit;

  {
   * Indicates that the selection (if one) shouldn't be drawn when the
   * text object doesn't have focus.
   }
	kTXNDontDrawSelectionWhenInactiveMask = 1 shl kTXNDontDrawSelectionWhenInactiveBit;

  {
   * Indicates that the text object will not scroll vertically,
   * horizontal scrolling will stop when the end of the text is visible
   * (plus any right margin), and there will be no limit to the width
   * of the text.
   }
	kTXNSingleLineOnlyMask = 1 shl kTXNSingleLineOnlyBit;

  {
   * Indicates that drag and drop will not be allowed in the text
   * object.
   }
	kTXNDisableDragAndDropMask = 1 shl kTXNDisableDragAndDropBit;

  {
   * Indicates that the text object will keep in single style no matter
   * what kind of changes made to the object.  Mac OS X only.
   }
	kTXNMonostyledTextMask = 1 shl kTXNMonostyledTextBit;

  {
   * Indicates that ATSUI font substitution will be used.  Mac OS X
   * only.
   }
	kTXNDoFontSubstitutionMask = 1 shl kTXNDoFontSubstitutionBit;

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ TextBox Option Bits                                                                               }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  Useful for TXNDrawUnicodeTextBox and TXNDrawCFStringTextBox APIs. 32 bit only                       }


{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ TextBox Options Data                                                                              }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}


{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ File Types                                                                                        }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}

{
 *  TXNFileType
 *
 *  Discussion:
 *    Useful for TXNNewObject and TXNSave APIs.
 }
type
	TXNFileType = OSType;
const
	kTXNTextFile = FourCharCode('TEXT');
	kTXNAIFFFile = FourCharCode('AIFF');
	kTXNUnicodeTextFile = FourCharCode('utxt');
	kTXNTextensionFile = FourCharCode('txtn');


{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Text Encoding Types                                                                               }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}

{
 *  TXNPermanentTextEncodingType
 *
 *  Discussion:
 *    Useful for TXNNewObject and TXNSave APIs.
 }
type
	TXNPermanentTextEncodingType = UInt32;
const
	kTXNSystemDefaultEncoding = 0;
	kTXNMacOSEncoding = 1;
	kTXNUnicodeEncoding = 2;

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Data Types                                                                                        }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}

type
	TXNDataTypePtr = ^TXNDataType;
	TXNDataType = OSType;
const
	kTXNTextData = FourCharCode('TEXT');
	kTXNUnicodeTextData = FourCharCode('utxt');
	kTXNRichTextFormatData = FourCharCode('RTF ');



{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Action constants used in undo/redo functions                                                      }
{  In Mac OS X version 10.4 and later TXNActionKey is deprecated.                                          }
{  The following action constants should be used instead.                                              }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}

{
 *  kTXNActionTyping
 *
 *  Discussion:
 *    Denotes a typing action.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework [32-bit only]
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
var kTXNActionTyping: CFStringRef; external name '_kTXNActionTyping'; (* attribute const *)
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER *)

{
 *  kTXNActionCut
 *
 *  Discussion:
 *    Denotes a cut action.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework [32-bit only]
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
var kTXNActionCut: CFStringRef; external name '_kTXNActionCut'; (* attribute const *)
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER *)

{
 *  kTXNActionPaste
 *
 *  Discussion:
 *    Denotes a paste action.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework [32-bit only]
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
var kTXNActionPaste: CFStringRef; external name '_kTXNActionPaste'; (* attribute const *)
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER *)

{
 *  kTXNActionClear
 *
 *  Discussion:
 *    Denotes a clear action.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework [32-bit only]
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
var kTXNActionClear: CFStringRef; external name '_kTXNActionClear'; (* attribute const *)
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER *)

{
 *  kTXNActionChangeFont
 *
 *  Discussion:
 *    Denotes a change font action.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework [32-bit only]
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
var kTXNActionChangeFont: CFStringRef; external name '_kTXNActionChangeFont'; (* attribute const *)
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER *)

{
 *  kTXNActionChangeColor
 *
 *  Discussion:
 *    Denotes a change color action.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework [32-bit only]
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
var kTXNActionChangeColor: CFStringRef; external name '_kTXNActionChangeColor'; (* attribute const *)
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER *)

{
 *  kTXNActionChangeSize
 *
 *  Discussion:
 *    Denotes a change size action.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework [32-bit only]
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
var kTXNActionChangeSize: CFStringRef; external name '_kTXNActionChangeSize'; (* attribute const *)
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER *)

{
 *  kTXNActionChangeStyle
 *
 *  Discussion:
 *    Denotes a change style action.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework [32-bit only]
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
var kTXNActionChangeStyle: CFStringRef; external name '_kTXNActionChangeStyle'; (* attribute const *)
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER *)

{
 *  kTXNActionAlignLeft
 *
 *  Discussion:
 *    Denotes an align left action.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework [32-bit only]
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
var kTXNActionAlignLeft: CFStringRef; external name '_kTXNActionAlignLeft'; (* attribute const *)
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER *)

{
 *  kTXNActionAlignCenter
 *
 *  Discussion:
 *    Denotes an align center action.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework [32-bit only]
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
var kTXNActionAlignCenter: CFStringRef; external name '_kTXNActionAlignCenter'; (* attribute const *)
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER *)

{
 *  kTXNActionAlignRight
 *
 *  Discussion:
 *    Denotes an align right action.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework [32-bit only]
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
var kTXNActionAlignRight: CFStringRef; external name '_kTXNActionAlignRight'; (* attribute const *)
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER *)

{
 *  kTXNActionDrop
 *
 *  Discussion:
 *    Denotes a drop action.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework [32-bit only]
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
var kTXNActionDrop: CFStringRef; external name '_kTXNActionDrop'; (* attribute const *)
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER *)

{
 *  kTXNActionMove
 *
 *  Discussion:
 *    Denotes a move action.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework [32-bit only]
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
var kTXNActionMove: CFStringRef; external name '_kTXNActionMove'; (* attribute const *)
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER *)

{
 *  kTXNActionChangeFontFeature
 *
 *  Discussion:
 *    Denotes a change font feature action.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework [32-bit only]
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
var kTXNActionChangeFontFeature: CFStringRef; external name '_kTXNActionChangeFontFeature'; (* attribute const *)
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER *)

{
 *  kTXNActionChangeFontVariation
 *
 *  Discussion:
 *    Denotes a change font variation action.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework [32-bit only]
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
var kTXNActionChangeFontVariation: CFStringRef; external name '_kTXNActionChangeFontVariation'; (* attribute const *)
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER *)

{
 *  kTXNActionChangeGlyphVariation
 *
 *  Discussion:
 *    Denotes a change glyph variation action.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework [32-bit only]
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
var kTXNActionChangeGlyphVariation: CFStringRef; external name '_kTXNActionChangeGlyphVariation'; (* attribute const *)
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER *)

{
 *  kTXNActionChangeTextPosition
 *
 *  Discussion:
 *    Denotes a change text's position action, which includes changing
 *    the space before/after characters and shifting the text's
 *    baseline.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework [32-bit only]
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
var kTXNActionChangeTextPosition: CFStringRef; external name '_kTXNActionChangeTextPosition'; (* attribute const *)
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER *)

{
 *  kTXNActionUndoLast
 *
 *  Discussion:
 *    Used in undo/redo functions if none of the other constants apply.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework [32-bit only]
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
var kTXNActionUndoLast: CFStringRef; external name '_kTXNActionUndoLast'; (* attribute const *)
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER *)


{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Format Setting Constants                                                                          }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}

type
	TXNTabType = SInt8;
const
	kTXNRightTab = -1;
	kTXNLeftTab = 0;
	kTXNCenterTab = 1;

type
	TXNTabPtr = ^TXNTab;
	TXNTab = record
		value: SInt16;
		tabType: TXNTabType;
		filler: UInt8;
	end;
const
	kTXNLeftToRight = 0;
	kTXNRightToLeft = 1;

const
	kTXNFlushDefault = 0;    { Flush according to the line direction    }
	kTXNFlushLeft = 1;
	kTXNFlushRight = 2;
	kTXNCenter = 4;
	kTXNFullJust = 8;
	kTXNForceFullJust = 16;    { Flush left and right for all lines   }


{
 *  TXNMargins
 *
 *  Discussion:
 *    In MLTE version 1.2 and later you can change the top, left and
 *    right margins.
 }
type
	TXNMarginsPtr = ^TXNMargins;
	TXNMargins = record
		topMargin: SInt16;
		leftMargin: SInt16;
		bottomMargin: SInt16;

  {
   * The bottom margin is a placeholder for possible future
   * enhancements.
   }
		rightMargin: SInt16;
	end;

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Control Tags                                                                                      }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}

{
 *  TXNControlTag
 *
 }
type
	TXNControlTag = FourCharCode;
	TXNControlTagPtr = ^TXNControlTag; { when a VAR xx: TXNControlTag parameter can be nil, it is changed to xx: TXNControlTagPtr }
const
	kTXNLineDirectionTag = FourCharCode('lndr'); { Not functional when userIO is not allowed   }
	kTXNJustificationTag = FourCharCode('just'); { Not functional when userIO is not allowed   }
	kTXNIOPrivilegesTag = FourCharCode('iopv');
	kTXNSelectionStateTag = FourCharCode('slst');
	kTXNInlineStateTag = FourCharCode('inst');
	kTXNWordWrapStateTag = FourCharCode('wwrs');
	kTXNAutoIndentStateTag = FourCharCode('auin');
	kTXNTabSettingsTag = FourCharCode('tabs');
	kTXNRefConTag = FourCharCode('rfcn');
	kTXNMarginsTag = FourCharCode('marg');
	kTXNFlattenMoviesTag = FourCharCode('flat');
	kTXNDoFontSubstitution = FourCharCode('fSub'); { Note: This can degrade performance greatly in the case of large documents }
	kTXNNoUserIOTag = FourCharCode('nuio');

  {
   * In Mac OS X version 10.4 and later this constant is deprecated.
   * The functions TXNSetEventTarget and TXNGetEventTarget should be
   * used instead.
   }
	kTXNUseCarbonEvents = FourCharCode('cbcb');
	kTXNDrawSelectionWhenInactiveTag = FourCharCode('dsln');
	kTXNDisableDragAndDropTag = FourCharCode('drag');
	kTXNSingleLevelUndoTag = FourCharCode('undo'); { Set this state during creation of the object.  Switching Undo level back and forth is not recommended.}
	kTXNVisibilityTag = FourCharCode('visb'); { Set the visibility state of the object }

  {
   * In Mac OS X version 10.4 or later use this tag to disable and
   * re-enable layout and drawing. It optimizes performance when adding
   * data incrementally to a text object.
   }
	kTXNDisableLayoutAndDrawTag = kTXNVisibilityTag; { Turn on / off layout and drawing. Same as kTXNVisibilityTag but makes clear what the tag does}

  {
   * In Mac OS X version 10.4 or later use this constant to set
   * autoscroll behaviour.  See the discussion below for the enum
   * TXNAutoScrollBehavior for the types of autoscrolling supported.
   }
	kTXNAutoScrollBehaviorTag = FourCharCode('sbev');


{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Convenience Constants for TXNGet/SetTXNControls                                                   }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}

const
	kTXNClearThisControl = $FFFFFFFF; { To clear an object control setting }
	kTXNClearTheseFontFeatures = $80000000; { To clear ATSUI font feature(s) }

{ kTXNIOPrivilegesTag}
const
	kTXNReadWrite = false;
	kTXNReadOnly = true;

{ kTXNSelectionStateTag}
const
	kTXNSelectionOn = true;
	kTXNSelectionOff = false;

{ kTXNInlineStateTag}
const
	kTXNUseInline = false;
	kTXNUseBottomline = true;

{ kTXNWordWrapStateTag}
const
	kTXNAutoWrap = false;
	kTXNNoAutoWrap = true;

{ kTXNAutoIndentStateTag}
const
	kTXNAutoIndentOff = false;
	kTXNAutoIndentOn = true;

{ kTXNDrawSelectionWhenInactiveTag}
const
	kTXNDontDrawSelectionWhenInactive = false;
	kTXNDrawSelectionWhenInactive = true;

{ kTXNDisableDragAndDropTag}
const
	kTXNEnableDragAndDrop = false;
	kTXNDisableDragAndDrop = true;

{kTXNDisableLayoutAndDraw}
const
	kTXNDisableLayoutAndDraw = true;
	kTXNEnableLayoutAndDraw = false;

type
	TXNControlDataPtr = ^TXNControlData;
	TXNControlData = record
		case SInt16 of
		0: (
			uValue: UNSIGNEDLONG;
			);
		1: (
			sValue: SIGNEDLONG;
			);
		2: (
			tabValue: TXNTab;
			);
		3: (
			marginsPtr: TXNMarginsPtr;
			);
	end;

{
 *  TXNAutoScrollBehavior
 *
 *  Summary:
 *    Set of values that can be passed to the function
 *    TXNSetTXNObjectControls along with the control tag
 *    kTXNAutoScrollBehaviorTag to control scrolling behavior.
 *
 *  Discussion:
 *    Beginning with Mac OS X version 10.4, MLTE supports 3 types of
 *    autoscroll behavior.  These are: always scroll a new insertion
 *    into view, only scroll if the insertion point was visible and the
 *    end of the new insertion is out of view, and never auto scroll
 *    under any circumstance.
 }
type
	TXNAutoScrollBehavior = UInt32;
const
{
   * The default auto scrolling behavior. When text is inserted the
   * document is scrolled to show the new insertion.  This was the only
   * type of autoscrolling prior to Mac OS X version 10.4.
   }
	kTXNAutoScrollInsertionIntoView = 0;

  {
   * Never autoscroll.  This includes mouse dragging and text
   * insertion. The only way to scroll the document is for the user to
   * use the scrollbar or to scroll programatically.
   }
	kTXNAutoScrollNever = 1;

  {
   * This type of autoscrolling is best for implementing terminal or
   * log windows. Autoscrolling only happens when the insertion offset
   * is currently in the users view.  This means that if the user is
   * looking at page 1 of a 10 page document and text is inserted at
   * the end of the document than no autoscrolling will occur. However,
   * if the user was looking at page 10 and text was inserted there the
   * document would scroll.
   }
	kTXNAutoScrollWhenInsertionVisible = 2;


{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Offset/Selection Constants                                                                        }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
type
	TXNOffset = UInt32;
	TXNOffsetPtr				= ^TXNOffset; { when a VAR xx: TXNOffset parameter can be nil, it is changed to xx: TXNOffsetPtr }
const
	kTXNUseCurrentSelection = $FFFFFFFF;
	kTXNStartOffset = 0;
	kTXNEndOffset = $7FFFFFFF;

{ Useful for TXNShowSelection API.}
const
	kTXNShowStart = false;
	kTXNShowEnd = true;

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Resource Constants                                                                                }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{ Useful for saving document.                                                                          }

const
	kTXNSingleStylePerTextDocumentResType = FourCharCode('MPSR');
	kTXNMultipleStylesPerTextDocumentResType = FourCharCode('styl');

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ URL Constants                                                                                     }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}

{
 *  TXNHyperLinkState
 *
 *  Discussion:
 *    For future use.  Currently not available.
 }
type
	TXNHyperLinkState = UInt32;
const
	kTXNLinkNotPressed = 0;
	kTXNLinkWasPressed = 1;
	kTXNLinkTracking = 3;

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Type Attributes / ATSUI Features and Variations                                                   }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  Since MLTE currently uses ATSUI by default, the available face types for kTXNQDFontStyleAttribute   }
{  are limited by what's available in ATSUI.  Currently, MLTE supports types defined in MacTypes.h     }
{  which are normal, bold, italic, underline, condensed, and extended.  An alternative is to use       }
{  available QD compatibility tags defined in ATSUnicode.h.                                            }
{  Deprecate all QD TXNTypeRunAttributes/TXNTypeRunAttributeSizes constants. Use kTXNATSUIStyle or     }
{  ATSUI tags ATSUFontTag, kATSUColorTag and kATSUSizeTag to Set/Get the font, color or size           }
type
	TXNTypeRunAttributes = FourCharCode;
const
	kTXNTextEncodingAttribute = FourCharCode('encd');
	kTXNATSUIFontFeaturesAttribute = FourCharCode('atfe');
	kTXNATSUIFontVariationsAttribute = FourCharCode('atva');
	kTXNURLAttribute = FourCharCode('urla');
	kTXNATSUIStyle = FourCharCode('astl');

type
	TXNTypeRunAttributeSizes = ByteCount;
const
	kTXNTextEncodingAttributeSize = SizeOf(TextEncoding);
	kTXNATSUIStyleSize = SizeOf(ATSUStyle);

type
	TXNATSUIFeaturesPtr = ^TXNATSUIFeatures;
	TXNATSUIFeatures = record
		featureCount: ItemCount;
		featureTypes: ATSUFontFeatureTypePtr;
		featureSelectors: ATSUFontFeatureSelectorPtr;
	end;

type
	TXNATSUIVariationsPtr = ^TXNATSUIVariations;
	TXNATSUIVariations = record
		variationCount: ItemCount;
		variationAxis: ATSUFontVariationAxisPtr;
		variationValues: ATSUFontVariationValuePtr;
	end;

	TXNAttributeDataPtr = ^TXNAttributeData;
	TXNAttributeData = record
		case SInt16 of
		0: (
			dataPtr: UnivPtr;
			);
		1: (
			dataValue: UInt32;
			);
		2: (
			atsuFeatures: TXNATSUIFeaturesPtr;
			);
		3: (
			atsuVariations: TXNATSUIVariationsPtr;
			);
		4: (
			urlReference: CFURLRef;
			);
	end;

type
	TXNTypeAttributesPtr = ^TXNTypeAttributes;
	TXNTypeAttributes = record
		tag: TXNTypeRunAttributes;
		size: ByteCount;
		data: TXNAttributeData;
	end;

const
	kTXNDontCareTypeSize = $FFFFFFFF;
	kTXNDontCareTypeStyle = $FF;
	kTXNIncrementTypeSize = $00000001;
	kTXNDecrementTypeSize = $80000000;
	kTXNUseScriptDefaultValue = -1;

  {
   * kTXNNoFontVariations is returned in the dataValue field when the
   * caller as asked to see if the variation is continuous and there
   * was no variation in the continuous range.
   }
	kTXNNoFontVariations = $7FFF;

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Style Continuous Bits                                                                             }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{ Useful for TXNGetContinuousTypeAttributes API.                                                       }

const
	kTXNFontContinuousBit = 0;
	kTXNSizeContinuousBit = 1;
	kTXNStyleContinuousBit = 2;
	kTXNColorContinuousBit = 3;
	kTXNATSUIStyleContinuousBit = 4;

type
	TXNContinuousFlags = OptionBits;
const
	kTXNFontContinuousMask = 1 shl kTXNFontContinuousBit;
	kTXNSizeContinuousMask = 1 shl kTXNSizeContinuousBit;
	kTXNStyleContinuousMask = 1 shl kTXNStyleContinuousBit;
	kTXNColorContinuousMask = 1 shl kTXNColorContinuousBit;
	kTXNATSUIStyleContinuousMask = 1 shl kTXNATSUIStyleContinuousBit;

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Match Options Bits                                                                                }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{ Useful for TXNFind API.                                                                              }

const
	kTXNIgnoreCaseBit = 0;
	kTXNEntireWordBit = 1;
	kTXNUseEncodingWordRulesBit = 31;

type
	TXNMatchOptions = OptionBits;
const
	kTXNIgnoreCaseMask = 1 shl kTXNIgnoreCaseBit;
	kTXNEntireWordMask = 1 shl kTXNEntireWordBit;
	kTXNUseEncodingWordRulesMask = 1 shl kTXNUseEncodingWordRulesBit;

type
	TXNMatchTextRecordPtr = ^TXNMatchTextRecord;
	TXNMatchTextRecord = record
		iTextPtr: {const} UnivPtr;
		iTextToMatchLength: SIGNEDLONG;
		iTextEncoding: TextEncoding;
	end;

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Font Description                                                                                  }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}


{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Background                                                                                        }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}

{
 *  TXNBackgroundType
 *
 *  Discussion:
 *    Currently only an RGBColor is supported for the background.
 }
type
	TXNBackgroundType = UInt32;
const
	kTXNBackgroundTypeRGB = 1;


{
 *  TXNBackgroundData
 *
 *  Discussion:
 *    The TXNBackgroundData is left as a union so that it can be
 *    expanded in the future to support other background types.
 }
type
	TXNBackgroundDataPtr = ^TXNBackgroundData;
	TXNBackgroundData = record
		case SInt16 of
{
   * Currently only an RGBColor is supported.
   }
		0: (
			color: RGBColor;
			);
	end;

type
	TXNBackgroundPtr = ^TXNBackground;
	TXNBackground = record
		bgType: TXNBackgroundType;
		bg: TXNBackgroundData;
	end;


{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Constants passed in iTXNActionName parameter of TXNGet/ClearCountForActionType                    }
{    functions. In Mac OS X version 10.4 and later TXNCountOptions is deprecated.                      }
{    The following action count constants should be used instead.                                      }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}

{
 *  kTXNActionCountOfTextChanges
 *
 *  Discussion:
 *    All text changes other than style changes and custom defined
 *    actions are included in this action count. Includes key presses,
 *    inline sessions, cut/copy/paste, and drop, etc. Undo or redo
 *    events of the kind listed above are also included in this action
 *    count.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework [32-bit only]
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
var kTXNActionCountOfTextChanges: CFStringRef; external name '_kTXNActionCountOfTextChanges'; (* attribute const *)
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER *)

{
 *  kTXNActionCountOfStyleChanges
 *
 *  Discussion:
 *    Any text style change are included in this action count.  Style
 *    changes include changing font/font face/font size/font
 *    feature/font variation/glyph variation/text position, and font
 *    color, etc. Undo or redo events of the kind listed above are also
 *    included in this action count.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework [32-bit only]
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
var kTXNActionCountOfStyleChanges: CFStringRef; external name '_kTXNActionCountOfStyleChanges'; (* attribute const *)
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER *)

{
 *  kTXNActionCountOfAllChanges
 *
 *  Discussion:
 *    A constant used to request the total count of actions including
 *    all text and style changes, as well as custom defined actions.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework [32-bit only]
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
var kTXNActionCountOfAllChanges: CFStringRef; external name '_kTXNActionCountOfAllChanges'; (* attribute const *)
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER *)

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Scrolling                                                                                         }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}

{
 *  TXNScrollUnit
 *
 *  Discussion:
 *    Use as a parameter in TXNScroll.
 }
type
	TXNScrollUnit = UInt32;
const
	kTXNScrollUnitsInPixels = 0;
	kTXNScrollUnitsInLines = 1;
	kTXNScrollUnitsInViewRects = 2;


{
 *  TXNScrollBarOrientation
 *
 *  Discussion:
 *    Use as a parameter in ScrollInfo callback.
 }
type
	TXNScrollBarOrientation = UInt32;
const
	kTXNHorizontal = 0;
	kTXNVertical = 1;


{
 *  TXNScrollBarState
 *
 *  Discussion:
 *    Use as a parameter in TXNActivate and TXNSetScrollbarState.
 }
type
	TXNScrollBarState = Boolean;
const
	kScrollBarsAlwaysActive = true;
	kScrollBarsSyncWithFocus = false;

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Draw Item Bits                                                                                    }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  Specifies which element(s) of the text object to render.   Useful in TXNDrawObject API.             }

const
	kTXNDrawItemScrollbarsBit = 0;
	kTXNDrawItemTextBit = 1;
	kTXNDrawItemTextAndSelectionBit = 2;

type
	TXNDrawItems = OptionBits;
const
	kTXNDrawItemScrollbarsMask = 1 shl kTXNDrawItemScrollbarsBit;
	kTXNDrawItemTextMask = 1 shl kTXNDrawItemTextBit;
	kTXNDrawItemTextAndSelectionMask = 1 shl kTXNDrawItemTextAndSelectionBit;
	kTXNDrawItemAllMask = $FFFFFFFF;

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Rectangle Keys                                                                                    }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  Each key corresponds to a specific bound for the object.  Useful in TXNGetHIRect API.               }

type
	TXNRectKey = UInt32;
const
	kTXNViewRectKey = 0;
	kTXNDestinationRectKey = 1;
	kTXNTextRectKey = 2;
	kTXNVerticalScrollBarRectKey = 3;
	kTXNHorizontalScrollBarRectKey = 4;

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Carbon Event Info                                                                                 }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}

{ Dictionary keys currently supported in the TXNCarbonEventInfo dictionary }
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTXNTextHandlerKey CFSTRP('TextInput')}
{$endc}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTXNWindowEventHandlerKey CFSTRP('WindowEvent')}
{$endc}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTXNWindowResizeEventHandlerKey CFSTRP('WindowResize')}
{$endc}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTXNCommandTargetKey CFSTRP('CommandTarget')}
{$endc}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTXNCommandUpdateKey CFSTRP('CommandUpdate')}
{$endc}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTXNActionNameMapperKey CFSTRP('ActionNameMapper')}
{$endc}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTXNWheelMouseEventHandlerKey CFSTRP('WheelMouseEvent')}
{$endc}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTXNTSMDocumentAccessHandlerKey CFSTRP('TSMDocumentAccess')}
{$endc}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTXNFontPanelEventHandlerKey CFSTRP('FontPanel')}
{$endc}

{
 *  TXNCarbonEventInfo
 *
 *  Summary:
 *    Used to pass an EventTargetRef to MLTE via
 *    TXNSetTXNObjectControls API.
 }
type
	TXNCarbonEventInfoPtr = ^TXNCarbonEventInfo;
	TXNCarbonEventInfo = record
{
   * Pass TRUE.  MLTE no longer uses AppleEvents.
   }
		useCarbonEvents: Boolean;

  {
   * Pass NULL.
   }
		filler: UInt8;

  {
   * Pass NULL.  AppleEvent flags have been deprecated.
   }
		flags: UInt16;

  {
   * A reference to a Core Foundation dictionary whose keys are the
   * events you want handled and whose values are event target
   * references associated with the events. See the above list of
   * predefined keys you can use to build the dictionary.
   }
		fDictionary: CFDictionaryRef;
	end;


{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ------------}
{  ¥ Definition of dictionary keys for DocumentAttribute dictionary used in TXNWriteRangeToCFURL(), and            }
{    and TXNReadFromCFURL().                                                                                       }
{    When writing data out, document attributes are embedded into the data stream for document formats that        }
{    support them (ie. MLTE native format and RTF); when reading data in document attributes are extracted         }
{    from the data stream if the document format supports them.                                                    }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ------------ÑÑÑ}

{
 *  kTXNDocumentAttributeTitleKey
 *
 *  Discussion:
 *    CFString containing document title
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework [32-bit only]
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
var kTXNDocumentAttributeTitleKey: CFStringRef; external name '_kTXNDocumentAttributeTitleKey'; (* attribute const *)
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER *)

{
 *  kTXNDocumentAttributeCompanyNameKey
 *
 *  Discussion:
 *    CFString containing company name
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework [32-bit only]
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
var kTXNDocumentAttributeCompanyNameKey: CFStringRef; external name '_kTXNDocumentAttributeCompanyNameKey'; (* attribute const *)
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER *)

{
 *  kTXNDocumentAttributeSubjectKey
 *
 *  Discussion:
 *    CFString containing subject
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework [32-bit only]
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
var kTXNDocumentAttributeSubjectKey: CFStringRef; external name '_kTXNDocumentAttributeSubjectKey'; (* attribute const *)
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER *)

{
 *  kTXNDocumentAttributeAuthorKey
 *
 *  Discussion:
 *    CFString containing author name (not necessarily same as "last
 *    editor," see editor key below)
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework [32-bit only]
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
var kTXNDocumentAttributeAuthorKey: CFStringRef; external name '_kTXNDocumentAttributeAuthorKey'; (* attribute const *)
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER *)

{
 *  kTXNDocumentAttributeKeywordsKey
 *
 *  Discussion:
 *    CFArray of CFString, containing keywords
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework [32-bit only]
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
var kTXNDocumentAttributeKeywordsKey: CFStringRef; external name '_kTXNDocumentAttributeKeywordsKey'; (* attribute const *)
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER *)

{
 *  kTXNDocumentAttributeCommentKey
 *
 *  Discussion:
 *    CFString containing comments
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework [32-bit only]
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
var kTXNDocumentAttributeCommentKey: CFStringRef; external name '_kTXNDocumentAttributeCommentKey'; (* attribute const *)
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER *)

{
 *  kTXNDocumentAttributeEditorKey
 *
 *  Discussion:
 *    CFString containing name of person who last edited the document
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework [32-bit only]
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
var kTXNDocumentAttributeEditorKey: CFStringRef; external name '_kTXNDocumentAttributeEditorKey'; (* attribute const *)
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER *)

{
 *  kTXNDocumentAttributeCreationTimeKey
 *
 *  Discussion:
 *    CFAbsoluteTime containing document comments; note that this is
 *    not the file system creation date of the file, but of the
 *    document, as it's stored in the document
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework [32-bit only]
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
var kTXNDocumentAttributeCreationTimeKey: CFStringRef; external name '_kTXNDocumentAttributeCreationTimeKey'; (* attribute const *)
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER *)

{
 *  kTXNDocumentAttributeModificationTimeKey
 *
 *  Discussion:
 *    CFAbsoluteTime containing the last modification date of the
 *    document contents
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework [32-bit only]
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
var kTXNDocumentAttributeModificationTimeKey: CFStringRef; external name '_kTXNDocumentAttributeModificationTimeKey'; (* attribute const *)
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER *)
{
 *  kTXNDocumentAttributeCopyrightKey
 *
 *  Discussion:
 *    CFString containing the copyright of the document
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework [32-bit only]
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
var kTXNDocumentAttributeCopyrightKey: CFStringRef; external name '_kTXNDocumentAttributeCopyrightKey'; (* attribute const *)
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER *)

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ------------}
{  ¥ Key and value definitions for DataOption dictionary used in TXNWriteRangeToCFURL(), and TXNReadFromCFURL().   }
{    Data options are used to specify options for reading in and writing out data.                                 }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ------------ÑÑÑ}

{
 *  kTXNDataOptionDocumentTypeKey
 *
 *  Discussion:
 *    CFString containing the document format. Supported string values:
 *    kTXNPlainTextDocumentType, kTXNMLTEDocumentType,
 *    kTXNRTFDocumentType, kTXNQuickTimeDocumentType
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework [32-bit only]
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
var kTXNDataOptionDocumentTypeKey: CFStringRef; external name '_kTXNDataOptionDocumentTypeKey'; (* attribute const *)
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER *)

{
 *  kTXNDataOptionCharacterEncodingKey
 *
 *  Discussion:
 *    CFNumber of type kCFNumberSInt32Type containing the character
 *    encoding as specified in CFString.h and CFStringEncodingExt.h
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework [32-bit only]
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
var kTXNDataOptionCharacterEncodingKey: CFStringRef; external name '_kTXNDataOptionCharacterEncodingKey'; (* attribute const *)
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER *)

{ Document Type constants to be used as values for kTXNDataOptionDocumentTypeKey  }

{
 *  kTXNPlainTextDocumentType
 *
 *  Discussion:
 *    Plain Text document
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework [32-bit only]
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
var kTXNPlainTextDocumentType: CFStringRef; external name '_kTXNPlainTextDocumentType'; (* attribute const *)
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER *)

{
 *  kTXNMLTEDocumentType
 *
 *  Discussion:
 *    MLTE native document
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework [32-bit only]
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
var kTXNMLTEDocumentType: CFStringRef; external name '_kTXNMLTEDocumentType'; (* attribute const *)
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER *)

{
 *  kTXNRTFDocumentType
 *
 *  Discussion:
 *    RTF document
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework [32-bit only]
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
var kTXNRTFDocumentType: CFStringRef; external name '_kTXNRTFDocumentType'; (* attribute const *)
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER *)
{
 *  kTXNQuickTimeDocumentType
 *
 *  Discussion:
 *    Multimedia file that can be opened by QuickTime
 *    importers
 *    <BR>NOTE:Only supported for reading data, not writing.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework [32-bit only]
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
var kTXNQuickTimeDocumentType: CFStringRef; external name '_kTXNQuickTimeDocumentType'; (* attribute const *)
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER *)
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Callbacks                                                                                         }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}

type
	TXNFindProcPtr = function( const (*var*) matchData: TXNMatchTextRecord; iDataType: TXNDataType; iMatchOptions: TXNMatchOptions; iSearchTextPtr: {const} UnivPtr; encoding: TextEncoding; absStartOffset: TXNOffset; searchTextLength: ByteCount; var oStartMatch: TXNOffset; var oEndMatch: TXNOffset; var ofound: Boolean; refCon: URefCon ): OSStatus;
	TXNActionNameMapperProcPtr = function( actionName: CFStringRef; commandID: UInt32; inUserData: UnivPtr ): CFStringRef;
	TXNContextualMenuSetupProcPtr = procedure( iContextualMenu: MenuRef; objct: TXNObject; inUserData: UnivPtr );
	TXNScrollInfoProcPtr = procedure( iValue: SInt32; iMaximumValue: SInt32; iScrollBarOrientation: TXNScrollBarOrientation; iRefCon: SRefCon );
type
	TXNFindUPP = TXNFindProcPtr;
type
	TXNActionNameMapperUPP = TXNActionNameMapperProcPtr;
type
	TXNContextualMenuSetupUPP = TXNContextualMenuSetupProcPtr;
type
	TXNScrollInfoUPP = TXNScrollInfoProcPtr;
{
 *  NewTXNFindUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewTXNFindUPP( userRoutine: TXNFindProcPtr ): TXNFindUPP; external name '_NewTXNFindUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  NewTXNActionNameMapperUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewTXNActionNameMapperUPP( userRoutine: TXNActionNameMapperProcPtr ): TXNActionNameMapperUPP; external name '_NewTXNActionNameMapperUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER *)

{
 *  NewTXNContextualMenuSetupUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewTXNContextualMenuSetupUPP( userRoutine: TXNContextualMenuSetupProcPtr ): TXNContextualMenuSetupUPP; external name '_NewTXNContextualMenuSetupUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER *)

{
 *  NewTXNScrollInfoUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.1 and later in Carbon.framework
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.1 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewTXNScrollInfoUPP( userRoutine: TXNScrollInfoProcPtr ): TXNScrollInfoUPP; external name '_NewTXNScrollInfoUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_1_AND_LATER *)

{
 *  DisposeTXNFindUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeTXNFindUPP( userUPP: TXNFindUPP ); external name '_DisposeTXNFindUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  DisposeTXNActionNameMapperUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeTXNActionNameMapperUPP( userUPP: TXNActionNameMapperUPP ); external name '_DisposeTXNActionNameMapperUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER *)

{
 *  DisposeTXNContextualMenuSetupUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeTXNContextualMenuSetupUPP( userUPP: TXNContextualMenuSetupUPP ); external name '_DisposeTXNContextualMenuSetupUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER *)

{
 *  DisposeTXNScrollInfoUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.1 and later in Carbon.framework
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.1 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeTXNScrollInfoUPP( userUPP: TXNScrollInfoUPP ); external name '_DisposeTXNScrollInfoUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_1_AND_LATER *)

{
 *  InvokeTXNFindUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function InvokeTXNFindUPP( const (*var*) matchData: TXNMatchTextRecord; iDataType: TXNDataType; iMatchOptions: TXNMatchOptions; iSearchTextPtr: {const} UnivPtr; encoding: TextEncoding; absStartOffset: TXNOffset; searchTextLength: ByteCount; var oStartMatch: TXNOffset; var oEndMatch: TXNOffset; var ofound: Boolean; refCon: URefCon; userUPP: TXNFindUPP ): OSStatus; external name '_InvokeTXNFindUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  InvokeTXNActionNameMapperUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function InvokeTXNActionNameMapperUPP( actionName: CFStringRef; commandID: UInt32; inUserData: UnivPtr; userUPP: TXNActionNameMapperUPP ): CFStringRef; external name '_InvokeTXNActionNameMapperUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER *)

{
 *  InvokeTXNContextualMenuSetupUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure InvokeTXNContextualMenuSetupUPP( iContextualMenu: MenuRef; objct: TXNObject; inUserData: UnivPtr; userUPP: TXNContextualMenuSetupUPP ); external name '_InvokeTXNContextualMenuSetupUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER *)

{
 *  InvokeTXNScrollInfoUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.1 and later in Carbon.framework
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.1 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure InvokeTXNScrollInfoUPP( iValue: SInt32; iMaximumValue: SInt32; iScrollBarOrientation: TXNScrollBarOrientation; iRefCon: SRefCon; userUPP: TXNScrollInfoUPP ); external name '_InvokeTXNScrollInfoUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_1_AND_LATER *)


{ **************************************************************************************************** }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{                                  ¥  MLTE APIs ¥                                                      }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{ **************************************************************************************************** }

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Creating and Destroying Object                                                                    }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}



{
 *  TXNCommandEventSupportOptions
 *
 *  Discussion:
 *    Use these constants to turn support for specific HICommands in a
 *    given MLTE object.
 }
type
	TXNCommandEventSupportOptions = OptionBits;
const
{
   * Setting this bit enables processing for these HICommands:
   * kHICommandUndo, kHICommandRedo, kHICommandCut, kHICommandCopy,
   * kHICommandPaste, kHICommandClear, kHICommandSelectAll.
   }
	kTXNSupportEditCommandProcessing = 1 shl 0;

  {
   * Setting this bit turns support on for updating the the menu item
   * associated with the above edit commands. What that means is:
   *
   *
   * For Undo the undo item will be enabled if there are any undoable
   * actions in MLTE's command stack.  Additionally, if you have
   * installed an action key mapper proc that will be called to get the
   * appropriate string for the undo item.
   *
   * For Redo the Redo item is enabled if there are any redoable
   * actions and the action key mapper callback will be called if it is
   * installed.
   *
   * For Cut and Clear the item is enabled if a the current selection
   * is not empty.  If the selection is empty this is disabled.
   *
   *
   * For Paste the item is enabled if the clipboard is not empty.  It
   * is disabled if the clipboard is empty or contains data that MLTE
   * does not understand.
   * <BR> For Select All the item is always enabled.
   }
	kTXNSupportEditCommandUpdating = 1 shl 1;

  {
   * Turns on support for spell checking.  The spell checking commands
   * supported are kHICommandShowSpellingPanel,
   * kHICommandCheckSpelling, kHICommandChangeSpelling,
   * kHICommandCheckSpellingAsYouType, kHICommandIgnoreSpelling, and
   * kHICommandLearnWord.
   }
	kTXNSupportSpellCheckCommandProcessing = 1 shl 2;

  {
   * Turns on support for updating the menu item associated with a
   * given spell checking command.
   *
   * Show Spelling: This item is always enabled.
   *
   * Check Spelling: This item is always enabled.
   *
   * Change Spelling:  Typically this is not included in a spelling
   * menu.  If it is included it is enabled if the current selection is
   * a misspelled word.  It is disabled if the current selection is
   * empty or is not a misspelled word.
   *
   * Check Spelling as You Type:  This item is always enabled.  It is
   * checked if this feature has been enabled.  By default when you
   * turn on spell checking this is enabled. If this feature has been
   * disabled the item is unchecked.
   *
   * Ignore Spelling.  This is a command that usually does not have a
   * corresponding menu item.  If a menu does have this item it is
   * disabled if the current selection is empty or is not a misspelled
   * word.  It is enabled if the current selection is a misspelled
   * word.
   *
   * Learn Spelling.  Another command that typically does not have a
   * corresponding menu item.  It behaves exactly like the Ignore
   * spelling command.
   }
	kTXNSupportSpellCheckCommandUpdating = 1 shl 3;

  {
   * Setting this bit to turn on Carbon Font Panel support. Once
   * support is turned on, MLTE handles the following Carbon Events
   * defined in FontPanel.h: ¥ kHICommandShowHideFontPanel and
   * kEventFontPanelClosed to show and hide the Carbon font panel ¥
   * kEventFontSelection event to update the document after you select
   * a new font, size, style, color, or any features setting from the
   * Typography Panel.
   }
	kTXNSupportFontCommandProcessing = 1 shl 4;

  {
   * Setting this bit to turn on support for updating the selection in
   * Carbon Font Panel when the current selection in MLTE document is
   * changed. When you set this bit, kTXNSupportFontCommandProcessing
   * has to be set also, which means that you only can get this support
   * if Carbon Font Panel support is on.
   }
	kTXNSupportFontCommandUpdating = 1 shl 5;




{
 *  TXTNTag
 *
 *  Summary:
 *    Deprecated. Use TXNTypeRunAttributes.
 }

type
	TXTNTag = FourCharCode;

{
 *  TXNErrors
 *
 *  Summary:
 *    Deprecated. Use OSStatus.
 }
type
	TXNErrors = OSStatus;

{
 *  TXNObjectRefcon
 *
 *  Summary:
 *    Deprecated. Only used by TXNNewObject API, which has been
 *    deprecated.
 }
type
	TXNObjectRefcon = UnivPtr;

{
 *  TXNLongRect
 *
 *  Summary:
 *    Deprecated. Only used by TXNGetRectBounds/TXNSetRectBounds APIs,
 *    which have been deprecated.
 }
type
	TXNLongRectPtr = ^TXNLongRect;
	TXNLongRect = record
		top: SInt32;
		left: SInt32;
		bottom: SInt32;
		right: SInt32;
	end;

{
 *  TXNFrameType
 *
 *  Summary:
 *    Deprecated.  Only used by TXNNewObject API, which has been
 *    deprecated. Only kTXNTextEditStyleFrameType is supported.
 }
type
	TXNFrameType = UInt32;
const
	kTXNTextEditStyleFrameType = 1;
	kTXNPageFrameType = 2;    { Not supported}
	kTXNMultipleFrameType = 3;     { Not supported}


{  Deprecated all QD TXNTypeRunAttributes & TXNTypeRunAttributeSizes constants.}
const
	kTXNQDFontNameAttribute = FourCharCode('fntn');
	kTXNQDFontFamilyIDAttribute = FourCharCode('font');
	kTXNQDFontSizeAttribute = FourCharCode('size'); {the corresponding TXNTypeRunAttributeSizes is kTXNFontSizeAttributeSize}
	kTXNQDFontStyleAttribute = FourCharCode('face');
	kTXNQDFontColorAttribute = FourCharCode('klor');

const
	kTXNQDFontNameAttributeSize = SizeOf(Str255);
	kTXNQDFontFamilyIDAttributeSize = SizeOf(SInt16);
	kTXNFontSizeAttributeSize = SizeOf(Fixed);
	kTXNQDFontSizeAttributeSize = SizeOf(SInt16);
	kTXNQDFontStyleAttributeSize = SizeOf(Style);
	kTXNQDFontColorAttributeSize = SizeOf(RGBColor);

{
    Deprecated QuickDraw imaging constants.
    On Mac OS X version 10.4 and later, MLTE always uses Quartz imaging.
}

const
	kTXNUseQDforImagingBit = 16;

const
	kTXNUseQDforImagingMask = 1 shl kTXNUseQDforImagingBit;

const
	kTXNImageWithQDBit = 8;

const
	kTXNImageWithQDMask = 1 shl kTXNImageWithQDBit;


{
    Deprecated TXNControlTag constant.
    On Mac OS X version 10.4 and later, MLTE never draws the caret when inactive.
}

const
	kTXNDrawCaretWhenInactiveTag = FourCharCode('dcrt'); { Caret will never be drawn when inactive.}

const
	kTXNDontDrawCaretWhenInactive = false;
	kTXNDrawCaretWhenInactive = true;

const
	kTXNDontDrawCaretWhenInactiveBit = 12;

const
	kTXNDontDrawCaretWhenInactiveMask = 1 shl kTXNDontDrawCaretWhenInactiveBit;


{
    Deprecated TSM constants.
    On Mac OS X, MLTE uses the Text Services Manager.
}

const
	kTXNNoTSMEverBit = 4;

const
	kTXNNoTSMEverMask = 1 shl kTXNNoTSMEverBit;


{
    Deprecated TXNCarbonEventInfo flag constants.
    MLTE does not support AppleEvents on Mac OS X version 10.1 and later.
}

const
	kTXNNoAppleEventHandlersBit = 0;
	kTXNRestartAppleEventHandlersBit = 1;

const
	kTXNNoAppleEventHandlersMask = 1 shl kTXNNoAppleEventHandlersBit;
	kTXNRestartAppleEventHandlersMask = 1 shl kTXNRestartAppleEventHandlersBit;


{
 *  TXNActionKey
 *
 }
type
	TXNActionKeyPtr = ^TXNActionKey; { when a VAR xx: TXNActionKey parameter can be nil, it is changed to xx: TXNActionKeyPtr }
	TXNActionKey = UInt32;
const
	kTXNTypingAction = 0;
	kTXNCutAction = 1;
	kTXNPasteAction = 2;
	kTXNClearAction = 3;
	kTXNChangeFontAction = 4;
	kTXNChangeFontColorAction = 5;
	kTXNChangeFontSizeAction = 6;
	kTXNChangeStyleAction = 7;
	kTXNAlignLeftAction = 8;
	kTXNAlignCenterAction = 9;
	kTXNAlignRightAction = 10;
	kTXNDropAction = 11;
	kTXNMoveAction = 12;
	kTXNFontFeatureAction = 13;
	kTXNFontVariationAction = 14;

  {
   * Use if none of the above apply.
   }
	kTXNUndoLastAction = 1024;

{ Deprecated on Mac OS X version 10.4 and later, use kTXNActionNameMapperKey instead.}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTXNActionKeyMapperKey CFSTRP('ActionKeyMapper')}
{$endc}

{ Deprecated on Mac OS X version 10.4 and later, use TXNActionNameMapperProcPtr instead.}
type
	TXNActionKeyMapperProcPtr = function( actionKey: TXNActionKey; commandID: UInt32 ): CFStringRef;
type
	TXNActionKeyMapperUPP = TXNActionKeyMapperProcPtr;
{
 *  NewTXNActionKeyMapperUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.3 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewTXNActionKeyMapperUPP( userRoutine: TXNActionKeyMapperProcPtr ): TXNActionKeyMapperUPP; external name '_NewTXNActionKeyMapperUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_4 *)

{
 *  DisposeTXNActionKeyMapperUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.3 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeTXNActionKeyMapperUPP( userUPP: TXNActionKeyMapperUPP ); external name '_DisposeTXNActionKeyMapperUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_4 *)

{
 *  InvokeTXNActionKeyMapperUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.3 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function InvokeTXNActionKeyMapperUPP( actionKey: TXNActionKey; commandID: UInt32; userUPP: TXNActionKeyMapperUPP ): CFStringRef; external name '_InvokeTXNActionKeyMapperUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_4 *)

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Count Option Bits                                                                                 }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  Options for TXNGet/ClearActionChangeCount to decide what type(s) of action count to use.            }

const
	kTXNTextInputCountBit = 0;
	kTXNRunCountBit = 1;


{
 *  TXNCountOptions
 *
 }
type
	TXNCountOptions = OptionBits;
const
	kTXNTextInputCountMask = 1 shl kTXNTextInputCountBit;
	kTXNRunCountMask = 1 shl kTXNRunCountBit;
	kTXNAllCountMask = kTXNTextInputCountMask or kTXNRunCountMask;


{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ DEPRECATED APIs,  Mac OS X version 10.2 and later                                                 }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}


{$endc} {TARGET_OS_MAC}

{$ifc not defined MACOSALLINCLUDE or not MACOSALLINCLUDE}

end.
{$endc} {not MACOSALLINCLUDE}
