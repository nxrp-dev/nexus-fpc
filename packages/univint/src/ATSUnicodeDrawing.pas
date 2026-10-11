{
     File:       QD/ATSUnicodeDrawing.h

     Contains:   ATSUI drawing, measuring, and highlighting functions.

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
unit ATSUnicodeDrawing;
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
uses MacOsApi.MacTypes,MacOsApi.TextCommon,MacOsApi.QuickdrawTypes,MacOsApi.ATSLayoutTypes,MacOsApi.ATSUnicodeTypes;
{$ELSE FPC_DOTTEDUNITS}
uses MacTypes,TextCommon,QuickdrawTypes,ATSLayoutTypes,ATSUnicodeTypes;
{$ENDIF FPC_DOTTEDUNITS}
{$endc} {not MACOSALLINCLUDE}


{$ifc TARGET_OS_MAC}

{$ALIGN POWER}


{ ---------------------------------------------------------------------------- }
{  ATSUI drawing and measuring                                                 }
{ ---------------------------------------------------------------------------- }


{
 *  ATSUDrawText()   *** DEPRECATED ***
 *
 *  Deprecated:
 *    Use CTFrameDraw, CTLiineDraw, or CTRunDraw instead.
 *
 *  Summary:
 *    Draws a specified range of text in a QuickDraw graphics port or
 *    Quartz graphics context.
 *
 *  Discussion:
 *    Before calling ATSUDrawText, you will most likely want to call
 *    ATSUSetLayoutControls to set a value for the kATSUCGContextTag
 *    attribute in order to specify your current graphics context.
 *    Otherwise, ATSUI will attempt to draw using Quickdraw style text
 *    rendering in whatever Quickdraw GrafPort is currently active (use
 *    SetPort to determine the currently active Quickdraw GrafPort, see
 *    Quickdraw.h). Carbon applications can create a CGContext from a
 *    Quickdraw GrafPort using the functions QDBeginCGContext and
 *    QDEndCGContext (see Quickdraw.h). Cocoa applications can call the
 *    method "graphicsPort" on the current NSGraphicsContext in order
 *    to get a CGContextRef to pass into ATSUI (use the method
 *    "currentContext" to obtain the current NSGraphicsContext, see
 *    NSGraphicsContext.h for more information). ATSUDrawText examines
 *    the text layout object to ensure that each of the characters in
 *    the range is assigned to a style run. If there are gaps between
 *    style runs, ATSUI assigns the characters in the gap to the style
 *    run that precedes (in storage order) the gap. If there is no
 *    style run at the beginning of the text range, ATSUI assigns these
 *    characters to the first style run it finds. If there is no style
 *    run at the end of the text range, ATSUI assigns the remaining
 *    characters to the last style run it finds. If you want to draw a
 *    range of text that spans multiple lines, you should call
 *    ATSUDrawText for each line of text to draw, even if all the lines
 *    are in the same text layout object. You should adjust the
 *    iLineOffset parameter to reflect the beginning of each line to be
 *    drawn. Please note that when drawing into a GrafPort, calls to
 *    QDSwapTextFlags have no effect on ATSUI text rendering. The
 *    proper way to achieve Quartz text rendering from ATSUI is to use
 *    the kATSUCGContextTag attribute to specify a CGContextRef in each
 *    ATSUTextLayout before calling ATSUDrawText.
 *
 *  Parameters:
 *
 *    iTextLayout:
 *      A layout containing text to draw.
 *
 *    iLineOffset:
 *      The starting offset of the range of text to draw. To specify
 *      the beginning of the text buffer, pass kATSUFromTextBeginning
 *      for this parameter.
 *
 *    iLineLength:
 *      The length of the range of text to draw. To specify a range
 *      that continues to the end of the text buffer, pass
 *      kATSUToTextEnd for this parameter.
 *
 *    iLocationX:
 *      The x-coordinate of the origin (in either the current graphics
 *      port or Quartz graphics context) of the line containing the
 *      text range to render. Note that the ATSUTextMeasurement type is
 *      defined as a Fixed value, so you must ensure that your
 *      coordinates are converted to Fixed values before passing them
 *      to this function (see FixMath.h for conversion functions). Pass
 *      the constant kATSUUseGrafPortPenLoc to draw relative to the
 *      current pen location in the current graphics port.
 *
 *    iLocationY:
 *      The y-coordinate of the origin (in either the current graphics
 *      port or Quartz graphics context) of the line containing the
 *      text range to render. Note that the ATSUTextMeasurement type is
 *      defined as a Fixed value, so you must ensure that your
 *      coordinates are converted to Fixed values before passing them
 *      to this function (see FixMath.h for conversion functions). Pass
 *      the constant kATSUUseGrafPortPenLoc to draw relative to the
 *      current pen location in the current graphics port.
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
function ATSUDrawText( iTextLayout: ATSUTextLayout; iLineOffset: UniCharArrayOffset; iLineLength: UniCharCount; iLocationX: ATSUTextMeasurement; iLocationY: ATSUTextMeasurement ): OSStatus; external name '_ATSUDrawText';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_6 *)



{
 *  ATSUGetGlyphBounds()   *** DEPRECATED ***
 *
 *  Deprecated:
 *    Use CTRunGetTypographicBounds, CTLineGetTypographicBounds,
 *    CTFontGetAscent, CTFontGetDescent, CTFontGetLeading, or
 *    CTFontGetUnitsPerEm instead.
 *
 *  Summary:
 *    Obtains the typographic bounds of a line of glyphs after final
 *    layout.
 *
 *  Discussion:
 *    This function produces the enclosing trapezoid(s) that represent
 *    the typographic bounds for glyphs in a final, laid-out range of
 *    text. You typically call this function when you need to obtain an
 *    enclosing trapezoid for a line, taking rotation and all other
 *    layout attributes into account. ATSUI determines the height of
 *    each trapezoid by examining any line ascent and descent attribute
 *    values you may have set for the line. If you have not set these
 *    attributes for the line, the ATSUGetGlyphBounds function uses any
 *    line ascent and descent values you may have set for the text
 *    layout object containing the line. If these are not set,
 *    ATSUGetGlyphBounds uses the font's natural line ascent and
 *    descent values for the line. If these are previously set,
 *    ATSUGetGlyphBounds uses the ATSUStyle ascent and or
 *    descent/leading values. Note that the coordinates produced for
 *    the trapezoid(s) are offset by the amount specified in the
 *    iTextBasePointX and iTextBasePointY parameters. If your goal in
 *    calling the ATSUGetGlyphBounds function is to obtain metrics for
 *    drawing the typographic bounds on the screen, pass the position
 *    of the origin of the line in the current graphics port or
 *    graphics context in these parameters. This enables
 *    ATSUGetGlyphBounds to match the trapezoids to their onscreen
 *    image. When the range specified by the iBoundsCharStart and
 *    iBoundsCharLength parameters covers an entire line, you are
 *    guaranteed to receive only one trapezoid on return. Otherwise,
 *    multiple trapezoids may be returned to cover incomplete sections
 *    of bidi runs. In such cases, you would typically call
 *    ATSUGetGlyphBounds twice, as follows: (1) Pass NULL for the
 *    oGlyphBounds parameter, 0 for the iMaxNumberOfBounds parameter,
 *    and valid values for the other parameters. The ATSUGetGlyphBounds
 *    function returns the actual number of trapezoids needed to
 *    enclose the glyphs in the oActualNumberOfBounds parameter. (2)
 *    Allocate enough space for a buffer of the returned size, then
 *    call the function again, passing a valid pointer to the buffer in
 *    the oGlyphBounds parameter. On return, the buffer contains the
 *    trapezoids for the glyphs' typographic bounds. To obtain the
 *    typographic bounds of a line of text prior to line layout, call
 *    the function ATSUGetUnjustifiedBounds. To calculate the image
 *    bounding rectangle for a final laid-out line, call the function
 *    ATSUMeasureTextImage. For more information about the difference
 *    between typographic and image bounds, please refer to the ATSUI
 *    documentation.
 *
 *  Parameters:
 *
 *    iTextLayout:
 *      The text layout object for which glyph bounds are to be
 *      obtained.
 *
 *    iTextBasePointX:
 *      The x-coordinate of the origin of the line containing the
 *      glyphs in the current graphics port or Quartz graphics context.
 *      Pass the constant kATSUUseGrafPortPenLoc to obtain the glyph
 *      bounds relative to the current pen location in the current
 *      graphics port or graphics context. You may pass 0 to obtain
 *      only the dimensions of the bounds relative to one another, not
 *      their actual onscreen position.
 *
 *    iTextBasePointY:
 *      The y-coordinate of the origin of the line containing the
 *      glyphs in the current graphics port or Quartz graphics context.
 *      Pass the constant kATSUUseGrafPortPenLoc to obtain the glyph
 *      bounds relative to the current pen location in the current
 *      graphics port or graphics context. You may pass 0 to obtain
 *      only the dimensions of the bounds relative to one another, not
 *      their actual onscreen position.
 *
 *    iBoundsCharStart:
 *      The offset from the beginning of the text buffer to the
 *      character corresponding to the first glyph to measure. To
 *      indicate that the text range starts at the beginning of the
 *      text buffer, you can pass the constant kATSUFromTextBeginning.
 *
 *    iBoundsCharLength:
 *      The length of text range to measure. If you want the range to
 *      extend to the end of the text buffer, you can pass the constant
 *      kATSUToTextEnd.
 *
 *    iTypeOfBounds:
 *      The type of bounds you wish to obtain. See ATSLayoutTypes.h for
 *      a list of possible values to pass in here.
 *
 *    iMaxNumberOfBounds:
 *      The maximum number of bounding trapezoids to obtain. Typically,
 *      this is equivalent to the number of bounds in the oGlyphBounds
 *      array. To determine this value, see the Discussion.
 *
 *    oGlyphBounds:
 *      A pointer to memory you have allocated for an array of
 *      ATSTrapezoid values. On return, the array contains a trapezoid
 *      representing the typographic bounds for glyphs in the text
 *      range. If the specified range of text encloses nested
 *      bidirectional text, ATSUGetGlyphBounds produces multiple
 *      trapezoids defining these regions.In ATSUI 1.1, the maximum
 *      number of enclosing trapezoids that can be returned is 31; in
 *      ATSUI 1.2, the maximum number is 127. If you pass a range that
 *      covers an entire line, ATSUGetGlyphBounds always returns only 1
 *      trapezoid. If you are uncertain of how much memory to allocate
 *      for this array, see the Discussion.
 *
 *    oActualNumberOfBounds:
 *      On return, the value specifies the actual number of enclosing
 *      trapezoids bounding the specified characters. This may be
 *      greater than the value you provide in the iMaxNumberOfBounds
 *      parameter.
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
function ATSUGetGlyphBounds( iTextLayout: ATSUTextLayout; iTextBasePointX: ATSUTextMeasurement; iTextBasePointY: ATSUTextMeasurement; iBoundsCharStart: UniCharArrayOffset; iBoundsCharLength: UniCharCount; iTypeOfBounds: UInt16; iMaxNumberOfBounds: ItemCount; oGlyphBounds: {variable-size-array} ATSTrapezoidPtr { can be NULL }; var oActualNumberOfBounds: ItemCount  ): OSStatus; external name '_ATSUGetGlyphBounds';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_6 *)


{ ---------------------------------------------------------------------------- }
{  ATSUI line breaking                                                         }
{ ---------------------------------------------------------------------------- }

{
 *  ATSUPositionToOffset()   *** DEPRECATED ***
 *
 *  Deprecated:
 *    Use CTLineGetStringIndexForPosition instead.
 *
 *  Summary:
 *    Obtains the memory offset for the glyph edge nearest a mouse-down
 *    event.
 *
 *  Discussion:
 *    The process of hit-testing text obtains the location of a
 *    mouse-down event relative both to the position of onscreen glyphs
 *    and to the corresponding offset between character codes in
 *    memory. You can then use the location information obtained by
 *    hit-testing to set the insertion point (that is, the caret) or
 *    selection range (for highlighting). Hit-testing text is
 *    complicated by the fact that a given line of text may be
 *    bidirectional. Therefore, the onscreen order of glyphs may not
 *    readily correspond to the storage order of the corresponding
 *    character codes. And the concept of which glyph comes "first" in
 *    a line of text cannot always be limited to the visual terms
 *    "left" and "right." Because of these complexities, it is more
 *    accurate to speak in terms of "leading" and "trailing" edges to
 *    glyphs. A "leading edge" is defined as the edge of a glyph that
 *    you first encounter when you read the text that includes that
 *    glyph. For example, when reading Roman text, you first encounter
 *    the left edge of a Roman glyph. Similarly, the "trailing edge" is
 *    defined as the edge of the glyph encountered last. This function
 *    produces the memory offset corresponding to the glyph edge
 *    nearest the event. If the mouse-down event occurs at a line
 *    direction boundary or within a glyph cluster,
 *    ATSUPositionToOffset produces two offsets. You can then provide
 *    the offset(s) to the ATSUOffsetToPosition function to obtain the
 *    actual caret position(s) for the event. When you call the
 *    ATSUPositionToOffset function, ATSUI examines the Unicode
 *    directionality of the character corresponding to the event
 *    location. The ATSUPositionToOffset function produces a value of
 *    true in the oIsLeading parameter if the offset is leading (that
 *    is, more closely associated with the subsequent character in
 *    memory and therefore indicative of a left-to-right line
 *    direction). It produces a value of false if the offset is
 *    trailing (that is, more closely associated with the preceding
 *    character in memory and indicative of a right-to-left line
 *    direction). Finally, note that when the event occurs beyond the
 *    leftmost or rightmost caret positions of the line (not taking
 *    into account line rotation), such that no glyph corresponds to
 *    the location of the hit, the ATSUPositionToOffset function
 *    produces the primary offset of the closest edge of the line to
 *    the input location. The oIsLeading flag depends on the
 *    directionality of the closest glyph and the side of the line to
 *    which the input location is closest. In this case, the secondary
 *    offset is equal to the primary offset, since no glyph was hit.
 *
 *  Parameters:
 *
 *    iTextLayout:
 *      The layout object in which the mouse-down event occurred.
 *
 *    iLocationX:
 *      The x-coordinate of the event, in local coordinates, relative
 *      to the origin of the line where the event occurred. That is, to
 *      specify the x-coordinate value, you should subtract the
 *      x-coordinate of the line origin from the x-coordinate of the
 *      hit point (in local coordinates). You can pass the constant
 *      kATSUUseGrafPortPenLoc for the location of the mouse-down event
 *      relative to the current pen location in the current graphics
 *      port.
 *
 *    iLocationY:
 *      The y-coordinate of the event, in local coordinates, relative
 *      to the origin of the line where the event occurred. That is, to
 *      specify the y-coordinate value, you should subtract the
 *      y-coordinate of the line origin from the y-coordinate of the
 *      hit point (in local coordinates). You can pass the constant
 *      kATSUUseGrafPortPenLoc for the location of the mouse-down event
 *      relative to the current pen location in the current graphics
 *      port.
 *
 *    ioPrimaryOffset:
 *      On input, a pointer to a UniCharArrayOffset value specifying
 *      the offset corresponding to the beginning of the line where the
 *      event occurred. On return, the value specifies the offset
 *      corresponding to the glyph edge that is visually closest to the
 *      event. To determine whether this offset indicates the leading
 *      or trailing edge of the glyph, you can examine the value
 *      produced in the oIsLeading parameter.
 *
 *    oIsLeading:
 *      On return, the value indicates whether the offset produced in
 *      the ioPrimaryOffset parameter is leading or trailing. The
 *      function ATSUPositionToOffset produces a value of true if the
 *      offset is leading (that is, more closely associated with the
 *      subsequent character in memory). It produces a value of false
 *      if the offset is trailing (that is, more closely associated
 *      with the preceding character in memory).
 *
 *    oSecondaryOffset:
 *      On return, the value typically specifies the same offset as
 *      that produced in the ioPrimaryOffset parameter, unless the
 *      event occurred within a glyph cluster or at a line direction
 *      boundary. If so, the value specifies a secondary offset. The
 *      secondary offset is associated with the glyph that has a
 *      different direction from the primary line direction.
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
function ATSUPositionToOffset( iTextLayout: ATSUTextLayout; iLocationX: ATSUTextMeasurement; iLocationY: ATSUTextMeasurement; var ioPrimaryOffset: UniCharArrayOffset; var oIsLeading: Boolean; var oSecondaryOffset: UniCharArrayOffset ): OSStatus; external name '_ATSUPositionToOffset';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_6 *)



{$endc} {TARGET_OS_MAC}
{$ifc not defined MACOSALLINCLUDE or not MACOSALLINCLUDE}

end.
{$endc} {not MACOSALLINCLUDE}
