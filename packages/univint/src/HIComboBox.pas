{
     File:       HIToolbox/HIComboBox.h

     Contains:   Definition of the combo box view provided by HIToolbox.

     Version:    HIToolbox-624~3

     Copyright:  © 2006-2008 by Apple Computer, Inc., all rights reserved.

     Bugs?:      For bug reports, consult the following page on
                 the World Wide Web:

                     http://bugs.freepascal.org

}
{       Translation Updated:  Jonas Maebe, <jonas@freepascal.org>, October 2009 }
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
unit HIComboBox;
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
uses MacOsApi.MacTypes,MacOsApi.Appearance,MacOsApi.CarbonEvents,MacOsApi.Controls,MacOsApi.CFBase,MacOsApi.CFArray,MacOsApi.HIGeometry,MacOsApi.HIObject,MacOsApi.HIView;
{$ELSE FPC_DOTTEDUNITS}
uses MacTypes,Appearance,CarbonEvents,Controls,CFBase,CFArray,HIGeometry,HIObject,HIView;
{$ENDIF FPC_DOTTEDUNITS}
{$endc} {not MACOSALLINCLUDE}


{$ifc TARGET_OS_MAC}

{$ALIGN POWER}


{
 *  HIComboBox.h
 *
 *  Discussion:
 *    API definitions for the combo box view.
 }
{==============================================================================}
{ HIComboBox                                                                   }
{ The combo box is a new view starting in Mac OS 10.2. It can be used in       }
{ both the new compositing mode, as well as the traditional Control Manager    }
{ mode. Like all new HIFoo views, this view is created invisible. You must     }
{ show the view after creation if you want to, like, see it and stuff.         }
{==============================================================================}
{ The HIObject class ID for the HIComboBox class. }
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kHIComboBoxClassID CFSTRP('com.apple.HIComboBox')}
{$endc}
{
    kEventClassHIComboBox quick reference:

    kEventComboBoxListItemSelected  = 1
}
const
	kEventClassHIComboBox = FourCharCode('hicb');

const
	kEventParamComboBoxListSelectedItemIndex = FourCharCode('cbli');

{
 *  kEventClassHIComboBox / kEventComboBoxListItemSelected
 *
 *  Summary:
 *    Notification that an item in the ComboBox disclosure list has
 *    been selected.
 *
 *  Discussion:
 *    This event is sent as a notification when an item in the ComboBox
 *    disclosure list has been selected.  This event is sent to all
 *    handlers installed on the view. This does not imply that the
 *    selection has been accepted; for that you will need to register
 *    for the kEventClassTextField/kEventTextAccepted event; you can
 *    register for that event in order to make live selections however.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Parameters:
 *
 *    --> kEventParamDirectObject (in, typeControlRef)
 *          The ComboBox view that has sent the notification.
 *
 *    --> kEventParamComboBoxListSelectedItemIndex (in, typeCFIndex)
 *          The index of the combo box list item that has been selected.
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework
 *    CarbonLib:        not available
 }
const
	kEventComboBoxListItemSelected = 1;


{
 *  Summary:
 *    ComboBox attributes
 }
const
{
   * A constant with value zero; the lack of any attributes.
   }
	kHIComboBoxNoAttributes = 0;

  {
   * The view will attempt to auto complete the text the user is typing
   * with an item in the ComboBox list that is the closest appropriate
   * match.
   }
	kHIComboBoxAutoCompletionAttribute = 1 shl 0;

  {
   * The view will disclose the ComboBox list after the user enters
   * text.
   }
	kHIComboBoxAutoDisclosureAttribute = 1 shl 1;

  {
   * The items in the ComboBox list will be automatically sorted in
   * alphabetical order.
   }
	kHIComboBoxAutoSortAttribute = 1 shl 2;

  {
   * The ComboBox list will be automatically sized to fit the Human
   * Interface Guidelines.
   }
	kHIComboBoxAutoSizeListAttribute = 1 shl 3;

  {
   * The minimum set of ComboBox attributes commonly used.
   }
	kHIComboBoxStandardAttributes = kHIComboBoxAutoCompletionAttribute or kHIComboBoxAutoDisclosureAttribute or kHIComboBoxAutoSizeListAttribute;

{ ControlKind}
const
	kControlKindHIComboBox = FourCharCode('cbbx');

{ ComboBox Part codes}
const
	kHIComboBoxEditTextPart = 5;
	kHIComboBoxDisclosurePart = 28;

{
    The ComboBox view supports these tags previously defined for the EditUnicodeText view.
    These tags are available through Get/SetControlData with a ControlPartCode of kHIComboBoxEditTextPart:

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
 *  Discussion:
 *    ComboBox ControlData tags available with Mac OS X 10.2 and later.
 }
const
{
   * Extract the contents of the ComboBox list as a CFArray. The
   * CFArray will be retained: if you get the array, you own it and
   * will be required to release it; if you set it the toolbox makes a
   * copy of it and you are free to release your reference.
   }
	kHIComboBoxListTag = FourCharCode('cbls'); { CFArrayRef; bumps the refCount on get/retains on set}

  {
   * The width of the ComboBox list. This can be customized. This
   * disables the autosize attribute.
   }
	kHIComboBoxListPixelWidthTag = FourCharCode('cblw'); { UInt32 }

  {
   * The height of the ComboBox list. This can be customized. This
   * disables the autosize attribute.
   }
	kHIComboBoxListPixelHeightTag = FourCharCode('cblh'); { UInt32}

  {
   * The number of visible items in the list. This can be customized.
   * This disables the autosize attribute.
   }
	kHIComboBoxNumVisibleItemsTag = FourCharCode('cbni'); { UInt32}


{$endc} {TARGET_OS_MAC}
{$ifc not defined MACOSALLINCLUDE or not MACOSALLINCLUDE}

end.
{$endc} {not MACOSALLINCLUDE}
