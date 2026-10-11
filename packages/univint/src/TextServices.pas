{
     File:       HIToolbox/TextServices.h

     Contains:   Text Services Manager Interfaces.

     Version:    HIToolbox-624~3

     Copyright:  © 1991-2008 by Apple Computer, Inc., all rights reserved.

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
unit TextServices;
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
uses MacOsApi.MacTypes,MacOsApi.QuickdrawTypes,MacOsApi.ConditionalMacros,MacOsApi.CFBase,MacOsApi.CarbonEventsCore,MacOsApi.ATSTypes,MacOsApi.CFArray,MacOsApi.CFDictionary,MacOsApi.Events,MacOsApi.Menus,MacOsApi.AEDataModel,MacOsApi.AERegistry,MacOsApi.AEInteraction,MacOsApi.Components,MacOsApi.CarbonEvents;
{$ELSE FPC_DOTTEDUNITS}
uses MacTypes,QuickdrawTypes,ConditionalMacros,CFBase,CarbonEventsCore,ATSTypes,CFArray,CFDictionary,Events,Menus,AEDataModel,AERegistry,AEInteraction,Components,CarbonEvents;
{$ENDIF FPC_DOTTEDUNITS}
{$endc} {not MACOSALLINCLUDE}


{$ifc TARGET_OS_MAC}

{$ALIGN MAC68K}

const
	kTextService = FourCharCode('tsvc'); { component type for the component description }


{
 *  Summary:
 *    TSM Version Gestalt values
 *
 *  Discussion:
 *    Gestalt values for gestaltTSMgrVersion selector (Gestalt.h)
 }
const
	kTSMVersion = $0150; { Version 1.5 of the Text Services Manager }
	kTSM15Version = kTSMVersion;
	kTSM20Version = $0200; { Version 2.0 as of Mac OS X 10.0 }
	kTSM22Version = $0220; { Version 2.2 as of Mac OS X 10.3 }
	kTSM23Version = $0230; { Version 2.3 as of Mac OS X 10.4 }
	kTSM24Version = $0240; { Version 2.4 as of Mac OS X 10.5 }


{  Interface types for NewTSMDocument}
type
	InterfaceTypeList = array[0..$7F000000 div SizeOf(OSType)-1] of OSType;
	InterfaceTypeListPtr = ^InterfaceTypeList;
type
	TSMDocumentInterfaceType = OSType;

{
 *  Summary:
 *    InterfaceTypeList - array of OSTypes passed to NewTSMDocument to
 *    specify capabilities of the new TSMDocument.
 *
 *  Discussion:
 *    TSM's Interface types, as of 10.3, are also stored as TSMDocument
 *    properties, so once a TSMDocument is created, you can easily find
 *    out what were its InterfaceTypes at document creation.
 }
const
{
   * This is the traditional TSMDocument type.  It does not support
   * Unicode. TSM will convert all Unicode produced by input methods to
   * the Mac encoding represented by the current keyboard script (or
   * the Mac encoding specified by the input method producing text.)
   * Full Unicode input sources may not be selectable when this
   * TSMDocument is active.
   }
	kTextServiceDocumentInterfaceType = kTextService; { TSM Document type for traditional (non-Unicode) NewTSMDocument }

  {
   * TSMTE document type.  This requests automatic management of inline
   * input sessions by TextEdit (the text engine.)  See Technote TE27 -
   * Inline Input for TextEdit with TSMTE.  This property (like
   * TextEdit) is not supported on 64-bit.
   }
	kTSMTEDocumentInterfaceType = FourCharCode('tmTE'); { TSM Document type for TSMTE document (see kTSMTEInterfaceType - TSMTE.h) }

  {
   * Unicode-savvy TSMDocument.  TSM will pass thru all Unicode text
   * unchanged. When this TSMDocument is active, the full range of
   * input sources is available to the user, such as Unicode keyboard
   * layouts.
   }
	kUnicodeDocumentInterfaceType = FourCharCode('udoc'); { TSM Document type for Unicode-savvy application }
                                        {    Older names, to be deprecated}
	kUnicodeDocument = kUnicodeDocumentInterfaceType; { TSM Document type for Unicode-savvy application }

{
    TextServiceClass constants supported by TSM
    Same as component subtype for the component description
}
type
	TextServiceClass = OSType;

{
 *  Summary:
 *    TextService classes
 *
 *  Discussion:
 *    Text Service classes fall into three categories or behaviors.
 *
 *    (1) KeyboardInputMethodClass text services are exclusive of one
 *    another in terms of being the default for a given Mac script
 *    code, and at most one of these - regardless of script - can be
 *    currently selected.
 *    (2) Only zero or one InkInputMethodClass text services can be
 *    selected; this is independent of what other input sources are
 *    selected.
 *    (3) Zero or more input methods of other classes can be selected,
 *    regardless of what other input sources are selected (they are
 *    additive in nature, regardless of the current keyboard script).
 }
const
{
   * Text service class for keyboard input methods. Behavior is
   * exclusive. Input Methods in this class are normally associated
   * with a Mac ScriptCode or Unicode, although they can be associated
   * with several scripts by adopting the Input Mode protocol. Keyboard
   * input methods are always visible in the System UI.
   }
	kKeyboardInputMethodClass = FourCharCode('inpm');

  {
   * Text service class for Ink (Handwriting) input methods. At most
   * one of these can be enabled and active regardless of script. Text
   * Services in the Ink class do not belong to any given script in the
   * sense that those of the Keyboard class do. Once selected, this
   * kind of text service will remain active regardless of the current
   * keyboard script. Although text services in this class are keyboard
   * script agnostic, like input methods of the keyboard class they can
   * still profess to produce only those Unicodes that are encoded in
   * the mac encoding specified in their component description record
   * or their implementation of the GetScriptLanguageSupport component
   * call.
   *
   * Mac OS X only provides System UI for enabling Apple's Ink input
   * method, not for other Ink input methods.
   }
	kInkInputMethodClass = FourCharCode('ink ');

  {
   * Text service class for Character Palette input methods.  Behavior
   * is Additive. Text Services in the character palette class do not
   * belong to any given script in the same sense that do those of the
   * Keyboard class.  Once selected, this kind of text service will
   * remain active regardless of the current keyboard script. Although
   * text services in this class are keyboard script agnostic, like
   * input methods of the keyboard class they can still profess to
   * produce only those Unicodes that are encoded in the mac encoding
   * specified in their component description record or their
   * implementation of the GetScriptLanguageSupport component call.
   *
   *
   * Unlike input methods in the keyboard class, multiple such text
   * services can be activated in parallel, and unlike input methods in
   * the Ink class, Mac OS X provides System UI to allow the user to
   * both enable and select multiple such input methods. Use the
   * kComponentBundleInvisibleInSystemUIKey plist key to make Character
   * Palette input methods invisible to the System UI.
   *
   * (Dictionary Service input methods are visible in the system UI by
   * default.  Use the kComponentBundleInvisibleInSystemUIKey plist key
   * to make them invisible if a developer-provided UI is to be used
   * instead.)
   }
	kCharacterPaletteInputMethodClass = FourCharCode('cplt');

  {
   * Text Service class for Speech input methods.  Behavior is
   * Additive.
   *
   * Similar to Character palette class.  System UI for these has not
   * yet been determined.
   }
	kSpeechInputMethodClass = FourCharCode('voic');

  {
   * Text Service class for Optical Character Recognition input
   * methods.  Behavior is Additive.
   *
   * Similar to Character palette class.  System UI for these has not
   * yet been determined.
   }
	kOCRInputMethodClass = FourCharCode('ocr ');

{ New opaque definitions for types }
type
	TSMDocumentID = ^OpaqueTSMDocumentID; { an opaque type }
	OpaqueTSMDocumentID = record end;
{ TSMDocumentID Properties}
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{ TSMDocumentID Properties                                                             }
{ With the following property APIs, you can attach any piece of data you'd like to a   }
{ TSMDocument.}
{ to attach the data to the menu itself, and not to any specific menu item.            }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
type
	TSMDocumentPropertyTag = OSType;

{
 *  Summary:
 *    TSMDocument Property Tags
 *
 *  Discussion:
 *    With the following property APIs, you can attach any piece of
 *    data you'd like to a TSMDocument.  The property tags pre-defined
 *    below by TSM fall in several categories. Read-only properties:
 *    these property tags are actually the interface type used to
 *    create a TSMDocument, such as kUnicodeDocumentInterfaceType.
 *    These properties are all property value-independent... see below.
 *    Value-independent properties:  these property tags are value
 *    independent. Only the fact that the tag is or is not a property
 *    of a TSMDocument is important.  These are used where the
 *    existence of the property is sufficient... Read-only TSMDocment
 *    properties are examples of value independent properties.
 *    SupportGlyphInfo is another. Pass a non-NULL actualSize parameter
 *    and a NULL propertyBuffer to check if the property exists (i.e.
 *    to obtain the size.) Value-dependent properties:  these are
 *    properties for which the value is meaningful.  Examples of this
 *    are the Refcon ProtocolVersion properties. NOTE:
 *    Value-independent properties can read by other clients, in
 *    particular input methods.  For example, input methods may want to
 *    query the current TSMDocument to see if supports unrestricted
 *    Unicode input, or if it supports the GlyphInfo protocol.
 }
const
                                        {    Property values for value-independent property tags (i.e. only the existence of}
                                        {    the property is meaningful).  To remove these properties, use TSMRemoveDocumentProperty.}
                                        {    To test these properties, it is sufficient to obtain the property's size, i.e. buffer = NULL}
                                        {    and test for error.}
                                        {    Read-only (value-independent) properties}
                                        {    Identical to Interface types passed to NewTSMDocument}

  {
   * Property is read-only, value-independent.  The value is identical
   * to the TextServiceDocument interface type, but is not needed.
   * Simply test for existence of the property. Property available in
   * TSM 2.2 and later
   }
	kTSMDocumentTextServicePropertyTag = kTextServiceDocumentInterfaceType;

  {
   * Property is read-only, value-independent.  The value is identical
   * to the UnicodeDocument interface type, but is not needed.  Simply
   * test for existence of the property. Property available in TSM 2.2
   * and later
   }
	kTSMDocumentUnicodePropertyTag = kUnicodeDocumentInterfaceType;

  {
   * Property is read-only, value-independent.  The value is identical
   * to the TSMTEDocument interface type, but is not needed.  Simply
   * test for existence of the property. Property available in TSM 2.2
   * and later
   }
	kTSMDocumentTSMTEPropertyTag = kTSMTEDocumentInterfaceType; {    }
                                        {    Settable value-independent properties}

  {
   * Property is value-independent.  The existence of this property in
   * a TSMDocument indicates that the event handlers associated with
   * the TSMDocument are aware of TSM's GlyhInfo data structure.  This
   * structure allows the input source producing text to apply Glyph
   * IDs, CIDs, or Fonts to subranges of text produced. This is useful
   * for characters in Unicode private use area, such as Windings. For
   * more information, see the Glyph Access protocol described in
   * TechNote TN20TT. By convention, this value can be a UInt32 with a
   * value of 0, but this is really arbitrary.  Simply test for
   * existence of the property. Property available in TSM 1.5 from
   * MacOSX 10.2 and later
   }
	kTSMDocumentSupportGlyphInfoPropertyTag = FourCharCode('dpgi'); {  property value is arbitrary}

  {
   * Property is value-independent.  The presence of this property tag
   * indicates that the TSMDocument should use TSM's floating input
   * window to handle input from input methods.  This form of input
   * does not support Unicode input by default, unless the
   * UnicodeInputWindow property is set. By convention, this value can
   * be a UInt32 with a value of 0, but this is really arbitrary.
   * Simply test for existence of the property. Property available in
   * TSM 2.2 and later
   }
	kTSMDocumentUseFloatingWindowPropertyTag = FourCharCode('uswm'); {    use bottom-line input (floating TSM) window for text input}

  {
   * Property is value-independent.  The presence of this property tag
   * indicates that although the TSMDocument has been told to use TSM's
   * floating input window to handle input from input methods, the
   * floating window is to support Unicode input.  This is useful when
   * non input-related activity is to produce Unicode, such as keyboard
   * navigation . By convention, this value can be a UInt32 with a
   * value of 0, but this is really arbitrary.  Simply test for
   * existence of the property. Property available in TSM 2.2 and later
   }
	kTSMDocumentUnicodeInputWindowPropertyTag = FourCharCode('dpub'); {    Unicode support in bottom line input window}

  {
   * Property is value-independent.  The presence of this property tag
   * indicates that the event handlers associated with this TSMDocument
   * support TSM's DocumentAccess event suite (see CarbonEvents.h) This
   * property also indicates that the handler for TSM's
   * kEventTextInputUpdateActiveInputArea event supports the
   * 'replaceRange' parameter and that the handler is a Carbon event
   * handler, not an AppleEvent handler. By convention, this value can
   * be a UInt32 with a value of 0, but this is really arbitrary.
   * Simply test for existence of the property. Property available in
   * TSM 2.2 and later
   }
	kTSMDocumentSupportDocumentAccessPropertyTag = FourCharCode('dapy'); {    support TSM Document Access protocol}
                                        {    Older names, to be deprecated}
	kTSMDocumentPropertySupportGlyphInfo = kTSMDocumentSupportGlyphInfoPropertyTag;
	kTSMDocumentPropertyUnicodeInputWindow = kTSMDocumentUnicodeInputWindowPropertyTag; {    }
                                        {    Settable value-dependent properties}
                                        {    Property values for the following property tags are meaningful}

  {
   * Property is value-dependent.  The property value initially
   * contains the Refcon value passed to NewTSMDocument. This property
   * is useful for changing the refcon on-the-fly after the TSMDocument
   * has been created. Property available in TSM 2.2 and later
   }
	kTSMDocumentRefconPropertyTag = FourCharCode('refc'); {    refcon passed to NewTSMDocument (SRefCon)}

  {
   * Property is value-dependent.  The property value indicates which
   * input mode should be used by the current keyboard-class input
   * method.  It is useful for temporarily restricting text input to a
   * subset of characters normally produced by an input method in a
   * given script, such as Katakana for Japanese input.  See details in
   * TextServiceProperty API below. Also note that this property tag
   * and value are passed unchanged to the TextServiceProperty API, so
   * it also serves as a TextServicePropertyTag. See
   * kTextServiceInputModePropertyTag for discussion on the values
   * associated with this property. Usage Note:  Property value is a
   * CFStringRef. With TSMGetDocumentProperty, the behavior is that of
   * a Copy function, and TSMSetDocumentProperty retain the CFString...
   * in either case the caller is responsible for releasing its
   * reference. Property available in TSM 2.2 and later
   }
	kTSMDocumentInputModePropertyTag = FourCharCode('imim'); {    Input mode property for input methods (CFStringRef - see Input Modes below)}

  {
   * Property is value-dependent.  The property value indicates the
   * level of the window that will host inline input sessions for a
   * given TSMDocument. Input Methods will query this property to
   * determine the level above which its "candidate" (floating)
   * window(s) should be positioned, typically by adding its window to
   * a window group (see Carbon's WindowGroup API) and incrementing the
   * level for the group.  If no level is available, the input method
   * is expected to use the default behavior, i.e. let the Window
   * Manager manage the level for floating windows. Window levels are
   * typed as CGWindowLevel. NSWindow levels are accessed through
   * NSWindow's (int)level method. Property available in TSM 2.3 and
   * later
   }
	kTSMDocumentWindowLevelPropertyTag = FourCharCode('twlp'); {    document window level (CGWindowLevel)}

  {
   * Property is value-dependent.  The property value is a
   * TISInputSourceRef specifying a keyboard input source that should
   * override whatever the System considers to be the current input
   * source at the time the TSMDocument is activated (i.e. when the
   * text field gains focus).  If the TSMDocument is already active
   * when this property is set, the specified input source is selected.
   * Usage Note:  Property value is a TISInputSourceRef. With
   * TSMGetDocumentProperty, the behavior is that of a Copy function,
   * and TSMSetDocumentProperty retain the CFString... in either case
   * the caller is responsible for releasing its reference. Property
   * available in TSM 2.4 (Mac OS X 10.5) and later
   }
	kTSMDocumentInputSourceOverridePropertyTag = FourCharCode('inis'); {  Set an override (Initial) Input source}

  {
   * Property is value-dependent.  The property value is a CFArrayRef
   * containing an array of keyboard input sources (TISInputSourceRef)
   * available to the user. This is used to restrict keyboard input to
   * the specified set of input sources. The array should be a subset
   * of those keyboard input sources available to the user according to
   * the System, i.e. the enabled input sources in the International
   * Preferences pane or the Text Input menu. Since this input source
   * may need to be recomputed when input sources are enabled or
   * disabled either by the user or programmatically, this value should
   * be recomputed when the
   * kTISNotifyEnabledKeyboardInputSourcesChanged notification is
   * received or before a call to ActivateTSMDocument. If the set of
   * enabled input sources specified consists of only one input source,
   * it will be automatically selected. Usage Note:  Property value is
   * a CFArrayRef. With TSMGetDocumentProperty, the behavior is that of
   * a Copy function, and TSMSetDocumentProperty retain the CFString...
   * in either case the caller is responsible for releasing its
   * reference. Property available in TSM 2.4 (Mac OS X 10.5) and later
   }
	kTSMDocumentEnabledInputSourcesPropertyTag = FourCharCode('enis'); {  Restrict input to this set of enabled Input sources}


{
 *  TSMSetDocumentProperty()
 *
 *  Summary:
 *    Set a TSMDocument property
 *
 *  Discussion:
 *    With the following property APIs, you can attach any piece of
 *    data you'd like to a TSMDocument.  Other uses include setting a
 *    (value-independent) property for input methods to query in order
 *    to determine an application's compliance with various TSM
 *    protocols. NOTE:  Property values are currently typed as SInt32,
 *    but should really be a void* since a variety of data types are
 *    used in practice. Note that the semantics for refcounted objects
 *    is ambiguous, so retain/release model is discussed for each
 *    TSM-defined property individually.  (See notes for
 *    TSMDocumentPropertyTag) Error Codes (MacErrors.h):
 *    tsmComponentPropertyUnsupportedErr tsmInputModeChangeFailedErr
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.2 and later in Carbon.framework
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.2 and later
 *    Non-Carbon CFM:   not available
 }
function TSMSetDocumentProperty( docID: TSMDocumentID; propertyTag: TSMDocumentPropertyTag; propertySize: UInt32; propertyData: UnivPtr ): OSStatus; external name '_TSMSetDocumentProperty';
(* AVAILABLE_MAC_OS_X_VERSION_10_2_AND_LATER *)


{
 *  TSMGetDocumentProperty()
 *
 *  Summary:
 *    Get a TSMDocument property
 *
 *  Discussion:
 *    With the following property APIs, you can attach any piece of
 *    data you'd like to a TSMDocument.  Other uses include setting a
 *    (value-independent) property for input methods to query in order
 *    to determine an application's compliance with various TSM
 *    protocols. NOTE:  Property values are currently typed as SInt32,
 *    but should really be a void* since a variety of data types are
 *    used in practice. Note that the semantics for refcounted objects
 *    is ambiguous, so retain/release model is discussed for each
 *    TSM-defined property individually.  (See notes for
 *    TSMDocumentPropertyTag) Error Codes (MacErrors.h)
 *    tsmDocPropertyNotFoundErr tsmDocPropertyBufferTooSmallErr
 *    tsmComponentPropertyNotFoundErr tsmComponentPropertyUnsupportedErr
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.2 and later in Carbon.framework
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.2 and later
 *    Non-Carbon CFM:   not available
 }
function TSMGetDocumentProperty( docID: TSMDocumentID; propertyTag: TSMDocumentPropertyTag; bufferSize: UInt32; var actualSize: UInt32; propertyBuffer: UnivPtr { can be NULL } ): OSStatus; external name '_TSMGetDocumentProperty';
(* AVAILABLE_MAC_OS_X_VERSION_10_2_AND_LATER *)


{
 *  TSMRemoveDocumentProperty()
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.2 and later in Carbon.framework
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.2 and later
 *    Non-Carbon CFM:   not available
 }
function TSMRemoveDocumentProperty( docID: TSMDocumentID; propertyTag: TSMDocumentPropertyTag ): OSStatus; external name '_TSMRemoveDocumentProperty';
(* AVAILABLE_MAC_OS_X_VERSION_10_2_AND_LATER *)


{ Language and Script constants}
const
	kUnknownLanguage = $FFFF;
	kUnknownScript = $FFFF;
	kNeutralScript = $FFFF;


const
{ Component Flags in ComponentDescription }
	bTakeActiveEvent = 15;   { bit set if the component takes active event }
	bHandleAERecording = 16;   { bit set if the component takes care of recording Apple Events <new in vers2.0> }
	bScriptMask = $00007F00; { bit 8 - 14 }
	bLanguageMask = $000000FF; { bit 0 - 7  }
	bScriptLanguageMask = bScriptMask + bLanguageMask; { bit 0 - 14  }


const
{ Low level routines which are dispatched directly to the Component Manager }
	kCMGetScriptLangSupport = $0001; { Component Manager call selector 1 }
	kCMInitiateTextService = $0002; { Component Manager call selector 2 }
	kCMTerminateTextService = $0003; { Component Manager call selector 3 }
	kCMActivateTextService = $0004; { Component Manager call selector 4 }
	kCMDeactivateTextService = $0005; { Component Manager call selector 5 }
	kCMTextServiceEvent = $0006; { Component Manager call selector 6 }
	kCMTextServiceEventRef = kCMTextServiceEvent;
	kCMGetTextServiceMenu = $0007; { Component Manager call selector 7 }
	kCMTextServiceMenuSelect = $0008; { Component Manager call selector 8 }
	kCMFixTextService = $0009; { Component Manager call selector 9 }
	kCMSetTextServiceCursor = $000A; { Component Manager call selector 10 }
	kCMHidePaletteWindows = $000B; { Component Manager call selector 11 }
	kCMGetTextServiceProperty = $000C; { Component Manager call selector 12 }
	kCMSetTextServiceProperty = $000D; { Component Manager call selector 13 }
	kCMUCTextServiceEvent = $000E; { Component Manager call selector 14 }
	kCMCopyTextServiceInputModeList = $000F; { Component Manager call selector 15 }
	kCMInputModePaletteItemHit = $0010; { Component Manager call selector 16 }
	kCMGetInputModePaletteMenu = $0011; { Component Manager call selector 17 }


{ extract Script/Language code from Component flag ... }
// #define     mGetScriptCode(cdRec)       ((ScriptCode)   ((cdRec.componentFlags & bScriptMask) >> 8))
// #define     mGetLanguageCode(cdRec)     ((LangCode)     cdRec.componentFlags & bLanguageMask)

{ Text Service Info List }
type
	TextServiceInfo = record
		fComponent: Component;
		fItemName: Str255;
	end;
	TextServiceInfoPtr = ^TextServiceInfo;
type
	TextServiceList = record
		fTextServiceCount: SInt16;      { number of entries in the 'fServices' array }
		fServices: array [0..0] of TextServiceInfo;		{  Note: array of 'TextServiceInfo' records follows  }
	end;
	TextServiceListPtr = ^TextServiceList;
type
	TextServiceListHandle = ^TextServiceListPtr;
	ScriptLanguageRecord = record
		fScript: ScriptCode;
		fLanguage: LangCode;
	end;
	ScriptLanguageRecordPtr = ^ScriptLanguageRecord;
type
	ScriptLanguageSupport = record
		fScriptLanguageCount: SInt16;   { number of entries in the 'fScriptLanguageArray' array }
		fScriptLanguageArray:	array [0..0] of ScriptLanguageRecord;	{  Note: array of 'ScriptLanguageRecord' records follows  }
	end;
	ScriptLanguageSupportPtr = ^ScriptLanguageSupport;
type
	ScriptLanguageSupportHandle = ^ScriptLanguageSupportPtr;
	TSMGlyphInfo = record
		range: CFRange;                  {    two SInt32s}
		fontRef: ATSFontRef;
		collection: UInt16;             {    kGlyphCollectionXXX enum}
		glyphID: UInt16;                {    GID (when collection==0) or CID}
	end;
type
	TSMGlyphInfoArray = record
		numGlyphInfo: ItemCount;           {    UInt32}
		glyphInfo: array[0..$7F000000 div SizeOf(TSMGlyphInfo)-1] of TSMGlyphInfo;
	end;

{ High level TSM Document routines }



type
	TextServicePropertyTag = OSType;

{
 *  Summary:
 *    TextService Properties
 *
 *  Discussion:
 *    Text Service properties are passed directly to a text service
 *    component via Component Mgr glue provided by TSM.  Applications
 *    that have special knowledge of specific input methods can
 *    communicate private properties between each other. The 2
 *    following errors have been introduced (as of Mac OS X 10.3) to
 *    better support these API: tsmComponentPropertyUnsupportedErr  //
 *    SetTextServiceProperty failed tsmComponentPropertyNotFoundErr
 *    //  GetTextServiceProperty failed
 }
const
{ Typing input mode property tag }

  {
   * The JaTypingMethod property is becoming obsolete.  It was
   * introduced as a way for the Setup Assistant to tell Apple's
   * Kotoeri (Japanese) input method to switch to either Roman or
   * Katakana input mode in certain text fields. The entire input mode
   * mechanism is being superseded by kTextServiceInputModePropertyTag.
   * Property available in TSM 1.5 on MacOSX 10.0 and later
   }
	kTextServiceJaTypingMethodPropertyTag = FourCharCode('jtyp'); { Japanese input method typing property}

  {
   * The InputMode property is a CFStringRef that uniquely identifies
   * which input mode should be made current by a keyboard class input
   * method, if possible. Input modes are either generic, i.e.
   * pre-defined by TSM, or specific to an input method.  An example of
   * a generic input mode is Katakana input (Japanese) where input in a
   * text field needs to be restricted to that character subset.
   * Another is Roman input mode.  This is useful to temporarily
   * provide Roman input from an input method that normally allows text
   * input in another script. The advantage to this over forcing the
   * keyboard script to Roman is that the same input method's UI
   * continues to be available to the user, even though the input
   * script has changed. An example of a special input mode (input
   * method specific) is Hanin input mode in Traditional Chinese input
   * methods. To temporarily change the current input mode from
   * whatever it is to a generic one, use GetTextServiceProperty to
   * obtain the current input mode, then SetTextServiceProperty to
   * switch to the generic mode, and when done restore the original
   * input mode. Input Methods themselves make known what input modes
   * they support via the CopyTextServiceInputModeList component call.
   * If the input method does not support a specified inputMode,
   * GetTextServiceProperty and SetTextServiceProperty will return
   * tsmComponentPropertyUnsupportedErr.  GetTextServiceProperty will
   * return tsmComponentPropertyNotFoundErr.  RemoveTextServiceProperty
   * is not supported with this tag. NOTE: This property tag is
   * identical to the kTSMDocumentInputModePropertyTag passed to the
   * TSMDocumentProperty API.  This allows the tag and value to be
   * passed through without interpretation. NOTE: Input modes
   * CFStringRef's are cast to SInt32 in these API. Property available
   * in TSM 2.2 and later Error Codes (MacErrors.h)
   * tsmComponentPropertyUnsupportedErr - SetTextServiceProperty does
   * not support the specified inputMode. tsmInputModeChangeFailedErr -
   * can be returned if an input method failed to succeed in switching
   * to the requested input mode.
   }
	kTextServiceInputModePropertyTag = kTSMDocumentInputModePropertyTag; { input mode property for input methods}
                                        {    NOTE:  This property is being deprecated.  Use kTextServiceInputModePropertyTag instead. }
	kIMJaTypingMethodProperty = kTextServiceJaTypingMethodPropertyTag; { Typing method property for Japanese input methods}
                                        { Typing method property values for kTextServiceJaTypingMethodPropertyTag }
	kIMJaTypingMethodRoman = FourCharCode('roma'); { Roman typing}
	kIMJaTypingMethodKana = FourCharCode('kana'); { Kana typing}


type
	TextServicePropertyValue = UnivPtr;


{
    Generic, restricted, input modes
    Used as values for kTextServiceInputModePropertyTag TextServiceProperty API.
    These values require a cast from CFStringRef to SInt32.
}

{  Restrict output to Roman characters only}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTextServiceInputModeRoman CFSTRP('com.apple.inputmethod.Roman')}
{$endc}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTextServiceInputModePassword CFSTRP('com.apple.inputmethod.Password')}
{$endc}
{  Restrict output to Hiragana characters only (no conversion to Kanji, i.e. yomi)}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTextServiceInputModeJapaneseHiragana CFSTRP('com.apple.inputmethod.Japanese.Hiragana')}
{$endc}
{  Restrict output to Katakana characters only (no conversion to Kanji)}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTextServiceInputModeJapaneseKatakana CFSTRP('com.apple.inputmethod.Japanese.Katakana')}
{$endc}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTextServiceInputModeJapaneseFullWidthRoman CFSTRP('com.apple.inputmethod.Japanese.FullWidthRoman')}
{$endc}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTextServiceInputModeJapaneseHalfWidthKana CFSTRP('com.apple.inputmethod.Japanese.HalfWidthKana')}
{$endc}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTextServiceInputModeJapanesePlaceName CFSTRP('com.apple.inputmethod.Japanese.PlaceName')}
{$endc}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTextServiceInputModeJapaneseFirstName CFSTRP('com.apple.inputmethod.Japanese.FirstName')}
{$endc}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTextServiceInputModeJapaneseLastName CFSTRP('com.apple.inputmethod.Japanese.LastName')}
{$endc}
{  Restrict output to Bopomofo characters only (no conversion to Han)}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTextServiceInputModeBopomofo CFSTRP('com.apple.inputmethod.TradChinese.Bopomofo')}
{$endc}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTextServiceInputModeTradChinesePlaceName CFSTRP('com.apple.inputmethod.TradChinese.PlaceName')}
{$endc}
{  Restrict output to Hangul syllables only (no conversion to Hanja)}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTextServiceInputModeHangul CFSTRP('com.apple.inputmethod.Korean.Hangul')}
{$endc}
{
    Generic, unrestricted, Input Mode strings
    Used as values for kTextServiceInputModePropertyTag in TextServiceProperty API.
    Unrestricted Japanese output
}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTextServiceInputModeJapanese CFSTRP('com.apple.inputmethod.Japanese')}
{$endc}
{  Traditional Chinese generic (unrestricted) input mode}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTextServiceInputModeTradChinese CFSTRP('com.apple.inputmethod.TradChinese')}
{$endc}
{  Simplified Chinese generic (unrestricted) input mode}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTextServiceInputModeSimpChinese CFSTRP('com.apple.inputmethod.SimpChinese')}
{$endc}
{  Korean generic (unrestricted) output (i.e. Hanja possible)}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTextServiceInputModeKorean CFSTRP('com.apple.inputmethod.Korean')}
{$endc}



{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kComponentBundleInputModeDictKey CFSTRP('ComponentInputModeDict')}
{$endc}

{
    Info.plist keys for an Input Method icon TIFF file.
    The filepath (.tif or .icns file) specified for an icon is relative to the input method bundle's Resources directory.
    NOTE:  This key is required if the input method (Component) does not contain a resource fork icon.  This icon will
            also be used for any input modes that do not specify their own icon.
}

{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTSInputMethodIconFileKey CFSTRP('tsInputMethodIconFileKey')}
{$endc}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTSInputMethodAlternateIconFileKey CFSTRP('tsInputMethodAlternateIconFileKey')}
{$endc}

{
    Key for dictionary of individual input modes
    NOTE:  This key is used both in the Component bundle's Info.plist dictionary and the dictionary
            returned by the CopyTextServiceInputModeList() component call.
}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTSInputModeListKey CFSTRP('tsInputModeListKey')}
{$endc}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTSInputModeMenuIconFileKey CFSTRP('tsInputModeMenuIconFileKey')}
{$endc}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTSInputModeAlternateMenuIconFileKey CFSTRP('tsInputModeAlternateMenuIconFileKey')}
{$endc}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTSInputModePaletteIconFileKey CFSTRP('tsInputModePaletteIconFileKey')}
{$endc}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTSInputModeDefaultStateKey CFSTRP('tsInputModeDefaultStateKey')}
{$endc}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTSInputModeScriptKey CFSTRP('tsInputModeScriptKey')}
{$endc}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTSInputModePrimaryInScriptKey CFSTRP('tsInputModePrimaryInScriptKey')}
{$endc}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTSInputModeIsVisibleKey CFSTRP('tsInputModeIsVisibleKey')}
{$endc}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTSInputModeKeyEquivalentModifiersKey CFSTRP('tsInputModeKeyEquivalentModifiersKey')}
{$endc}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTSInputModeKeyEquivalentKey CFSTRP('tsInputModeKeyEquivalentKey')}
{$endc}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTSInputModeJISKeyboardShortcutKey CFSTRP('tsInputModeJISKeyboardShortcutKey')}
{$endc}
{
    Key for array of visible input modes to determine UI ordering
    NOTE:  This key is intended to be used both in the Component bundle's Info.plist dictionary and in
            in the dictionary returned by the CopyTextServiceInputModeList() component call.  In the latter
            case, the array should contain only the set of visible input modes that are also enabled.
}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTSVisibleInputModeOrderedArrayKey CFSTRP('tsVisibleInputModeOrderedArrayKey')}
{$endc}

{
    Key for Component bundle's Info.plist, controls visibility in System UI.
    Value is a CFBoolean.
    NOTE:  Keyboard input methods are always visible in System UI.
}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kComponentBundleInvisibleInSystemUIKey CFSTRP('ComponentInvisibleInSystemUI')}
{$endc}


{
 *  TSMGetActiveDocument()
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.3 and later
 *    Non-Carbon CFM:   not available
 }
function TSMGetActiveDocument: TSMDocumentID; external name '_TSMGetActiveDocument';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)



{-------------------------------------------}
{ Input Mode Palette configuration routines }
{-------------------------------------------}


{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTSInputModePaletteItemTypeKey CFSTRP('tsInputModePaletteItemTypeKey')}
{$endc}
{ CFNumber - the type of control (0: push button, 1: toggle button, 2: pulldown menu) }

{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTSInputModePaletteItemIconKey CFSTRP('tsInputModePaletteItemIconKey')}
{$endc}
{ CFString - icon file name (File located in IM bundle's resource directory, so this is just the file name, not full path) }

{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTSInputModePaletteItemAltIconKey CFSTRP('tsInputModePaletteItemAltIconKey')}
{$endc}
{ CFString - alternate icon file name (File located in IM bundle's resource directory, so this is just the file name, not full path) }

{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTSInputModePaletteItemStateKey CFSTRP('tsInputModePaletteItemStateKey')}
{$endc}
{ CFNumber - state of the control (0: clear/unpressed, 1: checked/pressed, 2: mixed) }

{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTSInputModePaletteItemEnabledKey CFSTRP('tsInputModePaletteItemEnabledKey')}
{$endc}
{ CFBoolean - enabled state of the control }

{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTSInputModePaletteItemIDKey CFSTRP('tsInputModePaletteItemIDKey')}
{$endc}
{ CFNumber - UInt32 tag ID for control }



{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTSInputModePaletteItemTitleKey CFSTRP('tsInputModePaletteItemTitleKey')}
{$endc}
{ CFString - menu item title (use '-' for a separator) }

{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTSInputModePaletteItemKeyEquivalentKey CFSTRP('tsInputModePaletteItemKeyEquivalentKey')}
{$endc}
{ CFString - menu item keyboard shortcut (example: 'j') }

{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kTSInputModePaletteItemKeyEquivalentModifiersKey CFSTRP('tsInputModePaletteItemKeyEquivalentModifiersKey')}
{$endc}
{ CFNumber - menu item keyboard shortcut modifiers (from Events.h) }


{$endc} {TARGET_OS_MAC}
{$ifc not defined MACOSALLINCLUDE or not MACOSALLINCLUDE}

end.
{$endc} {not MACOSALLINCLUDE}
