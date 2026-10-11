{
     File:       QD/ATSUnicodeObjects.h

     Contains:   ATSUI object manipulation functions.

     Version:    Quickdraw-285~150

     Copyright:  © 2003-2008 by Apple Inc. all rights reserved.

     Bugs?:      For bug reports, consult the following page on
                 the World Wide Web:

                     http://bugs.freepascal.org

}
{  Pascal Translation:  Peter N Lewis, <peter@stairways.com.au>, 2004 }
{  Pascal Translation Updated:  Jonas Maebe, <jonas@freepascal.org>, October 2009 }
{  Pascal Translation Updated:  Jonas Maebe, <jonas@freepascal.org>, October 2012 }
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
unit ATSUnicodeObjects;
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
uses MacOsApi.MacTypes,MacOsApi.ATSUnicodeTypes,MacOsApi.TextCommon,MacOsApi.SFNTLayoutTypes;
{$ELSE FPC_DOTTEDUNITS}
uses MacTypes,ATSUnicodeTypes,TextCommon,SFNTLayoutTypes;
{$ENDIF FPC_DOTTEDUNITS}
{$endc} {not MACOSALLINCLUDE}


{$ifc TARGET_OS_MAC}

{$ALIGN POWER}


{ ---------------------------------------------------------------------------- }
{  ATSUI basic style functions                                                 }
{ ---------------------------------------------------------------------------- }


{
 *  ATSUCreateStyle()   *** DEPRECATED ***
 *
 *  Deprecated:
 *    Use CTFontCopyGraphicsFont, CTFontCreateWithGraphicsFont,
 *    CTFontCreateWithPlatformFont, CTFontCreateWithQuickdrawInstance,
 *    CTFontCreateUIFontForLanguage, CTFontCreateCopyWithAttributes,
 *    CTFontCreateCopyWithSymbolicTraits, CTFontCreateCopyWithFamily,
 *    CTFontCreateForString, CTFontCreateWithName, or
 *    CTFontCreateWithFontDescriptor instead.
 *
 *  Summary:
 *    Creates an ATSUStyle object with default settings.
 *
 *  Discussion:
 *    ATSUStyle objects created by this function have a default set of
 *    values for all attributes. The attributes include settings such
 *    as font, point size, color and so on. You can change the
 *    attributes of a style object by calling the function
 *    ATSUSetAttributes. You can also change font features and
 *    variations set in an ATSUStyle by calling the functions
 *    ATSUSetFontFeatures and ATSUSetVariations, respectively.
 *    ATSUStyle objects are used by associating them with a run of
 *    characters in an ATSUTextLayout object. You can do this by
 *    calling functions such as ATSUSetRunStyle or
 *    ATSUCreateTextLayoutWithTextPtr. You are responsible for freeing
 *    memory associated with an ATSUStyle object by calling
 *    ATSUDisposeStyle.
 *
 *  Parameters:
 *
 *    oStyle:
 *      On return, a reference to an ATSUStyle object with default
 *      settings.
 *
 *  Result:
 *    On success, noErr is returned. See MacErrors.h for possible error
 *    codes.
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework but deprecated in 10.6
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in ATSUnicodeLib 8.5 and later
 }
function ATSUCreateStyle( var oStyle: ATSUStyle ): OSStatus; external name '_ATSUCreateStyle';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_6 *)



{
 *  ATSUDisposeStyle()   *** DEPRECATED ***
 *
 *  Deprecated:
 *    Use CoreText API and CFRelease instead.
 *
 *  Summary:
 *    Disposes of the memory associated with a style object.
 *
 *  Discussion:
 *    The ATSUDisposeStyle function frees the memory associated with
 *    the specified style object and its internal structures, including
 *    style run attributes. It does not dispose of the memory pointed
 *    to by application-defined style run attributes or reference
 *    constants. You are responsible for doing so. You should call this
 *    function after calling the function ATSUDisposeTextLayout to
 *    dispose of any text layout objects associated with the style
 *    object. For best performance, once you create a style object, you
 *    should keep it and use it as often as needed. You should dispose
 *    of the style object only when it is no longer needed in your
 *    application.
 *
 *  Parameters:
 *
 *    iStyle:
 *      The style you want to dispose of.
 *
 *  Result:
 *    On success, noErr is returned. See MacErrors.h for possible error
 *    codes.
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework but deprecated in 10.6
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in ATSUnicodeLib 8.5 and later
 }
function ATSUDisposeStyle( iStyle: ATSUStyle ): OSStatus; external name '_ATSUDisposeStyle';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_6 *)



{
 *  ATSUSetAttributes()   *** DEPRECATED ***
 *
 *  Deprecated:
 *    Use CTFontDescriptorCreateWithNameAndSize,
 *    CTFontDescriptorCreateWithAttributes, or
 *    CTFontDescriptorCreateCopyWithAttributes instead.
 *
 *  Summary:
 *    Sets style attribute values in a style object.
 *
 *  Discussion:
 *    Style attributes are a collection of values and settings that
 *    specify information about a style such as font, point size, and
 *    color. To specify a style attribute, ATSUI uses a "triple"
 *    consisting of (1) an attribute tag, (2) a value for that tag, and
 *    (3) the size of the value. For a list of possible tags and their
 *    default values, see the ATSUI documentation, or the definition of
 *    ATSUAttributeTag elsewhere in this header file. When you call
 *    ATSUSetAttributes, any style attributes that you do not set
 *    retain their previous values. To set font features and font
 *    variations, call the functions ATSUSetFontFeatures and
 *    ATSUSetVariations, respectively.
 *
 *  Parameters:
 *
 *    iStyle:
 *      A style in which to set attributes.
 *
 *    iAttributeCount:
 *      An ItemCount value specifying the number of attributes to set.
 *      This value should correspond to the number of elements in the
 *      iTag, iValueSize, and iValue arrays.
 *
 *    iTag:
 *      An array of attribute tags. The number of elements in this
 *      array must not be less than iAttributeCount. Each element in
 *      the array must contain a valid style attribute tag (see the
 *      definition of ATSUAttributeTag for possible values).
 *
 *    iValueSize:
 *      An array of ByteCount values. The number of elements in this
 *      array must not be less than iAttributeCount. Each ByteCount
 *      value corresponds to the size of an element referred to by a
 *      pointer in the iValue array.
 *
 *    iValue:
 *      An array of pointers of type ATSUAttributeValuePtr. Each
 *      pointer refers to a value that corresponds to a tag specified
 *      by the iTag array. The size of the data referred to is
 *      determined by a corresponding element in the iValueSize array.
 *      The number of elements in this array must not be less than
 *      iAttributeCount.
 *
 *  Result:
 *    On success, noErr is returned. See MacErrors.h for possible error
 *    codes.
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework but deprecated in 10.6
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in ATSUnicodeLib 8.5 and later
 }
function ATSUSetAttributes( iStyle: ATSUStyle; iAttributeCount: ItemCount; {const} iTag: {variable-size-array} ATSUAttributeTagPtr; {const} iValueSize: {variable-size-array} ByteCountPtr; {const} iValue: {variable-size-array} ATSUAttributeValuePtrPtr ): OSStatus; external name '_ATSUSetAttributes';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_6 *)



{
 *  ATSUCreateTextLayoutWithTextPtr()   *** DEPRECATED ***
 *
 *  Deprecated:
 *    Use CTTypesetterCreateWithAttributedString,
 *    CTTypesetterCreateWithAttributedStringAndOptions,
 *    CTLineCreateWithAttributedString, CTLineCreateTruncatedLine, or
 *    CTLineCreateJustifiedLine instead.
 *
 *  Summary:
 *    Creates an opaque text layout object containing default text
 *    layout attributes as well as associated text and text styles.
 *
 *  Discussion:
 *    This function creates a text layout object and associates the
 *    specified text buffer and style runs with it. All layout
 *    attributes are set to their default values. To provide nondefault
 *    line or layout attributes for a text layout object, you can call
 *    the functions ATSUSetLineControls or ATSUSetLayoutControls. After
 *    setting text attributes, call ATSUDrawText to draw the text.
 *    Because the only way that ATSUI interacts with text is via the
 *    memory references you associate with a text layout object, you
 *    are responsible for keeping these references updated through use
 *    of the functions ATSUTextInserted, ATSUTextDeleted,
 *    ATSUTextMoved, and ATSUSetTextPointerLocation. Note that, because
 *    ATSUI objects retain state information, doing superfluous calling
 *    can degrade performance. For example, you could call
 *    ATSUSetTextPointerLocation rather than ATSUTextInserted when the
 *    user inserts text, but there would be a performance penalty, as
 *    all the layout caches are flushed when you call
 *    ATSUSetTextPointerLocation , rather than just the affected ones.
 *    Text layout objects are readily reusable and should themselves be
 *    cached for later use, if possible. Text objects are thread-safe
 *    starting with ATSUI version 2.4.
 *
 *  Parameters:
 *
 *    iText:
 *      A text buffer containing UTF-16Ðencoded text. ATSUI associates
 *      this buffer with the new text layout object and analyzes the
 *      complete text of the buffer when obtaining the layout context
 *      for the current text range. Thus, for paragraph-format text, if
 *      you specify a buffer containing less than a complete paragraph,
 *      some of ATSUI's layout results are not guaranteed to be
 *      accurate. For example, with a buffer of less than a full
 *      paragraph, ATSUI can neither reliably obtain the context for
 *      bidirectional processing nor reliably generate accent
 *      attachments and ligature formations for Roman text.
 *
 *    iTextOffset:
 *      The offset from the beginning of the text buffer to the first
 *      character of the range to include in the layout. To indicate
 *      that the specified text range starts at the beginning of the
 *      text buffer, you can pass the constant kATSUFromTextBeginning.
 *      To specify the entire text buffer, pass kATSUFromTextBeginning
 *      in this parameter and kATSUToTextEnd in the iTextLength
 *      parameter. For best results, use one layout for each paragraph
 *      within the text buffer.
 *
 *    iTextLength:
 *      The length of the text range. Note that the sum of iTextOffset
 *      and iTextLength must be less than or equal to the value of the
 *      iTextTotalLength parameter. If you want the range of text to
 *      extend to the end of the text buffer, you can pass the constant
 *      kATSUToTextEnd. For best results, use one layout for each
 *      paragraph within the text buffer.
 *
 *    iTextTotalLength:
 *      The length of the entire text buffer referred to by iText. This
 *      value should be greater than or equal to the range of text
 *      defined by the iTextLength parameter.
 *
 *    iNumberOfRuns:
 *      The number of text style runs you want to define within the
 *      overall text range. The number of style objects and style run
 *      lengths passed in the iStyles and iRunLengths parameters,
 *      respectively, should be equal to the number of runs specified
 *      here.
 *
 *    iRunLengths:
 *      An array providing ATSUI with the lengths of each of the text's
 *      style runs. You can pass kATSUToTextEnd for the last style run
 *      length if you want the style run to extend to the end of the
 *      text range. If the sum of the style run lengths is less than
 *      the total length of the text range, the remaining characters
 *      are assigned to the last style run.
 *
 *    iStyles:
 *      An array of styles, each corresponding to a style run defined
 *      in iRunLengths. The same ATSUStyle object may be referred to
 *      more than once in this array. The number of elements in this
 *      array must be equal to the value specified by the iNumberOfRuns
 *      parameter.
 *
 *    oTextLayout:
 *      A valid pointer to an ATSUTextLayout value. On return, the
 *      value refers to the newly created text layout object.
 *
 *  Result:
 *    On success, noErr is returned. See MacErrors.h for possible error
 *    codes.
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework but deprecated in 10.6
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in ATSUnicodeLib 8.5 and later
 }
function ATSUCreateTextLayoutWithTextPtr( iText: ConstUniCharArrayPtr; iTextOffset: UniCharArrayOffset; iTextLength: UniCharCount; iTextTotalLength: UniCharCount; iNumberOfRuns: ItemCount; {const} iRunLengths: {variable-size-array} UniCharCountPtr; iStyles: {variable-size-array} ATSUStylePtr; var oTextLayout: ATSUTextLayout ): OSStatus; external name '_ATSUCreateTextLayoutWithTextPtr';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_6 *)


{
 *  ATSUClearLayoutCache()   *** DEPRECATED ***
 *
 *  Deprecated:
 *    Use CoreText API and CFRelease instead.
 *
 *  Summary:
 *    Clears the layout cache of a line or an entire text layout object.
 *
 *  Discussion:
 *    The layout cache contains all the layout information ATSUI
 *    calculates and needs to draw a range of text in a text layout
 *    object. This includes caret positions, the memory locations of
 *    glyphs, and other information needed to lay out the glyphs. ATSUI
 *    uses information in the layout cache to avoid laying out the text
 *    again, thereby improving performance. When you clear the layout
 *    cache of a line or block of text, ATSUI takes longer to redraw a
 *    line, since it must perform the calculations that support glyph
 *    layout again. You should call the function ATSUClearLayoutCache
 *    when you need to decrease the amount of memory your application
 *    uses. This function reclaims memory at the cost of optimal
 *    performance. By default, the ATSUClearLayoutCache function
 *    removes the layout cache of a single line. To clear the layout
 *    cache for multiple lines, you should call ATSUClearLayoutCache
 *    for each line. To clear the layout cache of an entire text layout
 *    object, pass the constant kATSUFromTextBeginning in the
 *    iLineStart parameter. Note that ATSUClearLayoutCache does not
 *    produce a function error if lines do not have a layout cache. The
 *    ATSUClearLayoutCache function flushes the layout cache but does
 *    not alter previously set text layout attributes, soft line break
 *    positions, or the text memory location. If you do not want to
 *    retain these values, you should dispose of the text layout object
 *    by calling the ATSUDisposeTextLayout function.
 *
 *  Parameters:
 *
 *    iTextLayout:
 *      The layout for which to clear the layout caches.
 *
 *    iLineStart:
 *      The offset from the beginning of the text buffer to the
 *      beginning of the line for which to discard the layout cache. If
 *      the range of text spans multiple lines, you should call
 *      ATSUClearLayoutCache for each line, passing the offset
 *      corresponding to the beginning of the new line to draw with
 *      each call. To clear the layout cache of the entire text layout
 *      object, you can pass the constant kATSUFromTextBeginning.
 *
 *  Result:
 *    On success, noErr is returned. See MacErrors.h for possible error
 *    codes.
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework but deprecated in 10.6
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in ATSUnicodeLib 8.6 and later
 }
function ATSUClearLayoutCache( iTextLayout: ATSUTextLayout; iLineStart: UniCharArrayOffset ): OSStatus; external name '_ATSUClearLayoutCache';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_6 *)


{
 *  ATSUDisposeTextLayout()   *** DEPRECATED ***
 *
 *  Deprecated:
 *    Use CoreText API and CFRelease instead.
 *
 *  Summary:
 *    Disposes of the memory associated with a text layout object.
 *
 *  Discussion:
 *    This function frees the memory associated with the specified text
 *    layout object and its internal structures, including line and
 *    layout control attributes, style runs, and soft line breaks.
 *    ATSUDisposeTextLayout does not dispose of any memory that may be
 *    allocated for the text buffer, style objects, or reference
 *    constants associated with the text layout object. You are
 *    responsible for doing so. For best performance, text layout
 *    objects are readily reusable and should be cached for later use,
 *    if possible. You can reuse a text layout object even if the text
 *    associated with it is altered. Call the functions
 *    ATSUSetTextPointerLocation, ATSUTextDeleted, or ATSUTextInserted
 *    to manage the altered text, rather than disposing of the text
 *    layout object and creating a new one.
 *
 *  Parameters:
 *
 *    iTextLayout:
 *      The layout object to dispose of.
 *
 *  Result:
 *    On success, noErr is returned. See MacErrors.h for possible error
 *    codes.
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework but deprecated in 10.6
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in ATSUnicodeLib 8.5 and later
 }
function ATSUDisposeTextLayout( iTextLayout: ATSUTextLayout ): OSStatus; external name '_ATSUDisposeTextLayout';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_6 *)


{
 *  ATSUSetTextLayoutRefCon()   *** DEPRECATED ***
 *
 *  Deprecated:
 *    Use CFAttributedStringSetAttributes instead.
 *
 *  Summary:
 *    Sets application-specific data for a text layout object.
 *
 *  Discussion:
 *    This function associates a reference constant (that is,
 *    application-specific data) with a text layout object. You might
 *    typically use ATSUSetTextLayoutRefCon to track user preferences
 *    that can effect layout, for example. If you copy or clear a text
 *    layout object containing a reference constant, the reference
 *    constant is not copied or removed. When you dispose of a text
 *    layout object that contains a reference constant, you are
 *    responsible for freeing any memory allocated for the reference
 *    constant. Calling the function ATSUDisposeTextLayout does not do
 *    so.
 *
 *  Parameters:
 *
 *    iTextLayout:
 *      A layout for which you wish to set a reference constant.
 *
 *    iRefCon:
 *      Any arbitrary 32-bit value you wish to store in association
 *      with iTextLayout.
 *
 *  Result:
 *    On success, noErr is returned. See MacErrors.h for possible error
 *    codes.
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework but deprecated in 10.6
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in ATSUnicodeLib 8.5 and later
 }
function ATSUSetTextLayoutRefCon( iTextLayout: ATSUTextLayout; iRefCon: URefCon ): OSStatus; external name '_ATSUSetTextLayoutRefCon';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_6 *)



{
 *  ATSUTextMoved()   *** DEPRECATED ***
 *
 *  Deprecated:
 *    Use CoreText API instead.
 *
 *  Summary:
 *    Informs ATSUI of the new memory location of relocated text.
 *
 *  Discussion:
 *    You should call the ATSUTextMoved function when a range of text
 *    consisting of less than an entire text buffer has been moved. The
 *    ATSUTextMoved function informs ATSUI of the new memory location
 *    of the text. You are responsible for moving the text. The text
 *    buffer should remain otherwise unchanged.
 *
 *  Parameters:
 *
 *    iTextLayout:
 *      The text layout containing the moved text.
 *
 *    iNewLocation:
 *      The new memory location of the moved text.
 *
 *  Result:
 *    On success, noErr is returned. See MacErrors.h for possible error
 *    codes.
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework but deprecated in 10.6
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in ATSUnicodeLib 8.5 and later
 }
function ATSUTextMoved( iTextLayout: ATSUTextLayout; iNewLocation: ConstUniCharArrayPtr ): OSStatus; external name '_ATSUTextMoved';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_6 *)


{ ---------------------------------------------------------------------------- }
{  ATSUI layout controls                                                       }
{ ---------------------------------------------------------------------------- }

{
 *  ATSUSetLayoutControls()   *** DEPRECATED ***
 *
 *  Deprecated:
 *    Use CoreText API and CFAttributedStringSetAttributes instead.
 *
 *  Summary:
 *    Sets layout control attribute values in a text layout object.
 *
 *  Discussion:
 *    When you use ATSUI to image your text, you can control the text's
 *    display and formatting at a number of different levels: layout,
 *    line, and run. The level affected by this function is the layout
 *    level, which is that of the entire text range associated with
 *    your text layout object. Attributes at this level affect the
 *    width of the text area from margin to margin, the alignment of
 *    the text, its justification, rotation, and direction, as well as
 *    other layout options. See ATSUSetLineControls for information
 *    about controlling text and the line level. Similar to style
 *    attributes, you use a "triple" to specify a line or layout
 *    control attribute. That is, (1) an attribute tag, (2) the size
 *    (in bytes) of the attribute value, and (3) the value of the
 *    attribute it sets. Attribute tags are constants supplied by
 *    ATSUI. Attribute values may be a scalar, a structure, or a
 *    pointer. And as with style attributes, you can also create a
 *    custom attribute for a line or layout attribute for which ATSUI
 *    does not provide a tag. For a list of layout control tags defined
 *    by ATSUI and their default values, see the definition of
 *    ATSUAttributeTag.
 *
 *  Parameters:
 *
 *    iTextLayout:
 *      The text layout in which to set layout-level controls.
 *
 *    iAttributeCount:
 *      The number of attributes to set. This value should correspond
 *      to the number of elements in the iTag, iValueSize, and iValue
 *      arrays.
 *
 *    iTag:
 *      An array of attribute tags to set. For a list of layout control
 *      tags defined by ATSUI and their default values, see the
 *      definition of ATSUAttributeTag.
 *
 *    iValueSize:
 *      An array of values indicating the sizes of the values pointed
 *      to by the elements in the iValue array.
 *
 *    iValue:
 *      An array of attribute value pointers. Each value in the array
 *      must correspond to a tag in the iTag array and be a legal value
 *      for that tag.
 *
 *  Result:
 *    On success, noErr is returned. See MacErrors.h for possible error
 *    codes.
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework but deprecated in 10.6
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in ATSUnicodeLib 8.5 and later
 }
function ATSUSetLayoutControls( iTextLayout: ATSUTextLayout; iAttributeCount: ItemCount; {const} iTag: {variable-size-array} ATSUAttributeTagPtr; {const} iValueSize: {variable-size-array} ByteCountPtr; {const} iValue: {variable-size-array} ATSUAttributeValuePtrPtr ): OSStatus; external name '_ATSUSetLayoutControls';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_6 *)



{
 *  ATSUSetRunStyle()   *** DEPRECATED ***
 *
 *  Deprecated:
 *    Use CoreText API and CFAttributedStringSetAttributes instead.
 *
 *  Summary:
 *    Defines a style run by associating style information with a run
 *    of text.
 *
 *  Discussion:
 *    A text run consists of one or more characters that are contiguous
 *    in memory. If you associate these characters with a distinct
 *    style, you define a style run. You can use the ATSUSetRunStyle
 *    function to define a style run, by associating a style object
 *    with a run of text in a text layout object. Each text run must be
 *    assigned a style object, which may or may not differ from other
 *    style objects assigned to other text runs in a given text layout
 *    object. After calling ATSUSetRunStyle, you can call the function
 *    ATSUDrawText to display the styled text. When you call
 *    ATSUDrawText, if you have not previously assigned styles to all
 *    the characters you request to be drawn, ATSUI automatically does
 *    so. Specifically, ATSUI extends the first style it locates
 *    immediately prior (in storage order) to the unstyled characters
 *    to include those unassigned characters. If the unstyled
 *    characters are at the beginning of the text stream, ATSUI finds
 *    the first style run in the stream and extends it backward to the
 *    first character. You should call ATSUSetRunStyle whenever you
 *    create a new text layout object without any associated styles, as
 *    by using the function ATSUCreateTextLayout. You should also call
 *    ATSUSetRunStyle to assign a style to a text run in response to a
 *    user action, such as when the user selects a run of text and
 *    changes the font. You do not need to call ATSUSetRunStyle when
 *    you change style attributes or text layout attributes. In such
 *    cases, ATSUI automatically updates the layout of the text as
 *    appropriate.
 *
 *  Parameters:
 *
 *    iTextLayout:
 *      The layout in which you wish to set the style run.
 *
 *    iStyle:
 *      The style to be assigned to the run of characters.
 *
 *    iRunStart:
 *      The start of the run of characters. To specify the beginning of
 *      the text buffer, pass kATSUFromTextBeginning for this parameter.
 *
 *    iRunLength:
 *      The end of the run of characters. To specify a run that
 *      continues to the end of the text buffer, pass kATSUToTextEnd
 *      for this parameter.
 *
 *  Result:
 *    On success, noErr is returned. See MacErrors.h for possible error
 *    codes.
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework but deprecated in 10.6
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in ATSUnicodeLib 8.5 and later
 }
function ATSUSetRunStyle( iTextLayout: ATSUTextLayout; iStyle: ATSUStyle; iRunStart: UniCharArrayOffset; iRunLength: UniCharCount ): OSStatus; external name '_ATSUSetRunStyle';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_6 *)



{
 *  ATSUMatchFontsToText()   *** DEPRECATED ***
 *
 *  Deprecated:
 *    Use CTFontCreateForString instead.
 *
 *  Summary:
 *    Examines a text range for characters that cannot be drawn with
 *    the current font and suggests a substitute font, if necessary.
 *
 *  Discussion:
 *    When you call the ATSUMatchFontsToText function, ATSUI scans the
 *    given range of text for characters that cannot be drawn with the
 *    currently assigned font. When ATSUI finds such a character, it
 *    identifies a substitute font for drawing the character. ATSUI
 *    then continues scanning the text range for subsequent characters
 *    that cannot be drawn, stopping when it finds a character that can
 *    be drawn with the currently assigned font, or finds a character
 *    that cannot be drawn with either the currently assigned font or
 *    the substitute font, or reaches the end of the text range you
 *    have specified. ATSUI's default behavior for finding a substitute
 *    font is to recommend the first valid font that it finds when
 *    scanning the fonts in the user's system. ATSUI first searches in
 *    the standard application fonts for various languages. If that
 *    fails, ATSUI searches through the remaining fonts on the system
 *    in the order in which the Font Manager returns the fonts. After
 *    ATSUI has searched all the fonts in the system, any unmatched
 *    text is drawn using the last-resort font. That is, missing glyphs
 *    are represented by and empty box to indicate to the user that a
 *    valid font for that character is not installed on their system.
 *    You can alter ATSUI's default search behavior by calling the
 *    function ATSUCreateFontFallbacks and defining your own font
 *    fallback settings for the text layout object. Because ATSUI does
 *    not necessarily completely scan the text range you specify with
 *    each call to ATSUMatchFontsToText, if ATSUI does find any
 *    characters that cannot be rendered with their current font, you
 *    should call ATSUMatchFontsToText again and update the input range
 *    to check that all the subsequent characters in the range can be
 *    drawn. For that reason, you should call ATSUMatchFontsToText from
 *    within a loop to assure that the entire range of text is checked.
 *    Note that calling ATSUMatchFontsToText does not cause the
 *    suggested font substitution to be performed. If you want ATSUI to
 *    perform font substitution automatically, you can call the
 *    function ATSUSetTransientFontMatching.
 *
 *  Parameters:
 *
 *    iTextLayout:
 *      The text layout object to examine.
 *
 *    iTextStart:
 *      The first character of the range to examine. To start at the
 *      beginning of the text buffer, pass the constant
 *      kATSUFromTextBeginning.
 *
 *    iTextLength:
 *      The length of the text range to examine. If you want the range
 *      of text to extend to the end of the text buffer, you can pass
 *      the constant kATSUToTextEnd.
 *
 *    oFontID:
 *      On return, the value provides a font ID for the suggested
 *      substitute font or kATSUInvalidFontID, if no substitute font is
 *      available.
 *
 *    oChangedOffset:
 *      On return, this value specifies the offset from the beginning
 *      of the text buffer to the first character that cannot be drawn
 *      with the current font.
 *
 *    oChangedLength:
 *      On return, this value specifies the length of the text range
 *      that cannot be drawn with the current font.
 *
 *  Result:
 *    The result code noErr indicates that all the characters in the
 *    given range can be rendered with their current font(s) and no
 *    font substitution is needed. If you receive either of the result
 *    codes kATSUFontsMatched or kATSUFontsNotMatched, you should
 *    update the input range and call ATSUMatchFontsToText again to
 *    ensure that all the characters in the range can be drawn. See
 *    MacErrors.h for other possible error codes.
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework but deprecated in 10.6
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in ATSUnicodeLib 8.5 and later
 }
function ATSUMatchFontsToText( iTextLayout: ATSUTextLayout; iTextStart: UniCharArrayOffset; iTextLength: UniCharCount; var oFontID: ATSUFontID; var oChangedOffset: UniCharArrayOffset; var oChangedLength: UniCharCount ): OSStatus; external name '_ATSUMatchFontsToText';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_6 *)


{
 *  ATSUSetTransientFontMatching()   *** DEPRECATED ***
 *
 *  Deprecated:
 *    Use CoreText API instead.
 *
 *  Summary:
 *    Sets the current transient font matching state for a given layout.
 *
 *  Discussion:
 *    Transient font matching allows ATSUI to automatically substitute
 *    glyphs from other fonts if the specified styles do not contain
 *    glyphs for all the characters in the text. You can change the
 *    behavior of this font substitution by calling the function
 *    ATSUCreateFontFallbacks and defining your own font fallback
 *    settings for the text layout object.
 *
 *  Parameters:
 *
 *    iTextLayout:
 *      A layout for which to set the current transient font matching
 *      state.
 *
 *    iTransientFontMatching:
 *      A boolean value indicating if the current transient font
 *      matching state to set.
 *
 *  Result:
 *    On success, noErr is returned. See MacErrors.h for possible error
 *    codes.
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework but deprecated in 10.6
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in ATSUnicodeLib 8.5 and later
 }
function ATSUSetTransientFontMatching( iTextLayout: ATSUTextLayout; iTransientFontMatching: Boolean ): OSStatus; external name '_ATSUSetTransientFontMatching';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_6 *)



{$endc} {TARGET_OS_MAC}
{$ifc not defined MACOSALLINCLUDE or not MACOSALLINCLUDE}

end.
{$endc} {not MACOSALLINCLUDE}
