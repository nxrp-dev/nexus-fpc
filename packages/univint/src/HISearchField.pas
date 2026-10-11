{
     File:       HIToolbox/HISearchField.h

     Contains:   Definition of the search field view provided by HIToolbox.

     Version:    HIToolbox-624~3

     Copyright:  © 2006-2008 by Apple Computer, Inc., all rights reserved.

     Bugs?:      For bug reports, consult the following page on
                 the World Wide Web:

                     http://bugs.freepascal.org

}
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
unit HISearchField;
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
uses MacOsApi.MacTypes,MacOsApi.Appearance,MacOsApi.CarbonEvents,MacOsApi.Controls,MacOsApi.Menus,MacOsApi.HIGeometry,MacOsApi.HIObject,MacOsApi.HIView,MacOsApi.CFBase;
{$ELSE FPC_DOTTEDUNITS}
uses MacTypes,Appearance,CarbonEvents,Controls,Menus,HIGeometry,HIObject,HIView,CFBase;
{$ENDIF FPC_DOTTEDUNITS}
{$endc} {not MACOSALLINCLUDE}


{$ifc TARGET_OS_MAC}

{$ALIGN POWER}


{
 *  HISearchField.h
 *
 *  Discussion:
 *    API definitions for the search field view.
 }
{==============================================================================}
{  HISearchField                                                               }
{  HISearchField is a new view available in Mac OS X 10.3.                     }
{  This view is designed to be used for applications that provide searching    }
{  functionality. Visually, it is a standard text field optionally adorned     }
{  with a search icon on the left and/or a cancel image on the right.          }
{  When the user has accepted the text by pressing the return or enter key     }
{  a Carbon Event of kEventClassTextField / kEventTextAccepted will be sent    }
{  to the view. This will be the indication that the search should begin.      }
{  This view will also respond to all the standard control data tags that are  }
{  used by the EditUnicodeText view.                                           }
{==============================================================================}
{ The HIObject class ID for the HISearchField class. }
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kHISearchFieldClassID CFSTRP('com.apple.HISearchField')}
{$endc}
{ ControlKind}
const
	kControlKindHISearchField = FourCharCode('srfd');

{ HISearchField part codes}
const
	kControlSearchFieldCancelPart = 30;
	kControlSearchFieldMenuPart = 31;

{
    The SearchField view supports those tags previously defined for the EditUnicodeText view.
    These tags are available through Get/SetControlData with ControlPartCode of kControlEditTextPart:

        kControlFontStyleTag
        kControlEditTextFixedTextTag
        kControlEditTextTextTag
        kControlEditTextKeyFilterTag
        kControlEditTextValidationProcTag
        kControlEditUnicodeTextPostUpdateProcTag
        kControlEditTextSelectionTag
        kControlEditTextKeyScriptBehaviorTag
        kControlEditTextCharCount
        kControlEditTextCFStringTag
}

{
 *  Summary:
 *    HISearchField attributes
 }
const
{
   * A constant with value zero; the lack of any attributes.
   }
	kHISearchFieldNoAttributes = 0;

  {
   * This view contains the cancel icon in the text field.
   }
	kHISearchFieldAttributesCancel = 1 shl 0;

  {
   * This view contains the search icon in the text field. If a menu is
   * associated with the search field, this attribute is implicitly set
   * and the search icon will display with a menu disclosure badge.
   * Available in Mac OS X 10.4 and later.
   }
	kHISearchFieldAttributesSearchIcon = 1 shl 1;

{ Event Classes}
const
	kEventClassSearchField = FourCharCode('srfd');

{
 *  kEventClassSearchField / kEventSearchFieldCancelClicked
 *
 *  Summary:
 *    Notification that the cancel icon has been depressed.
 *
 *  Discussion:
 *    This event is sent by the HISearchField view if the cancel icon
 *    is enabled (attribute of kHISearchFieldAttributesCancel), and
 *    the cancel has been clicked.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Parameters:
 *
 *    --> kEventParamDirectObject (in, typeControlRef)
 *          The HISearchField that has sent the notification.
 *
 *  Availability:
 *    Mac OS X:         in version 10.3 and later in Carbon.framework
 *    CarbonLib:        not available
 }
const
	kEventSearchFieldCancelClicked = 1;

{
 *  kEventClassSearchField / kEventSearchFieldSearchClicked
 *
 *  Summary:
 *    Notification that the search icon has been depressed.
 *
 *  Discussion:
 *    This event is sent by the HISearchField view if the search icon
 *    is enabled (attribute of kHISearchFieldAttributesSearchIcon or a
 *    menu is associated with the search field), and the search icon
 *    has been clicked. If a menu is associated with the search field,
 *    the search field will handle the display and tracking of the menu
 *    by default. This event is sent to the search field only, it will
 *    not propagate.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Parameters:
 *
 *    --> kEventParamDirectObject (in, typeControlRef)
 *          The HISearchField that has sent the notification.
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework
 *    CarbonLib:        not available
 }
const
	kEventSearchFieldSearchClicked = 2;


{$endc} {TARGET_OS_MAC}

{$ifc not defined MACOSALLINCLUDE or not MACOSALLINCLUDE}

end.
{$endc} {not MACOSALLINCLUDE}
