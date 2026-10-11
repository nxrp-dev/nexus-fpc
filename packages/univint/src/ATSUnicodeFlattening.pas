{
     File:       QD/ATSUnicodeFlattening.h

     Contains:   Public interfaces for Apple Type Services for Unicode Imaging

     Version:    Quickdraw-285~150

     Copyright:  © 2002-2008 by Apple Inc. all rights reserved.

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
unit ATSUnicodeFlattening;
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
uses MacOsApi.MacTypes,MacOsApi.ATSUnicodeTypes,MacOsApi.SFNTTypes;
{$ELSE FPC_DOTTEDUNITS}
uses MacTypes,ATSUnicodeTypes,SFNTTypes;
{$ENDIF FPC_DOTTEDUNITS}
{$endc} {not MACOSALLINCLUDE}


{$ifc TARGET_OS_MAC}

{ ---------------------------------------------------------------------------- }
{ Constants                                                                    }
{ ---------------------------------------------------------------------------- }
{
   ATSUFlattenedDataStreamFormat is used to inform the APIs which flatten and
   unflatten style runs exactly what type of data that they should be generating
   or parsing.
}


{$ALIGN MAC68K}

type
	ATSUFlattenedDataStreamFormat = UInt32;
const
	kATSUDataStreamUnicodeStyledText = FourCharCode('ustl');


{
   ATSUFlattenStyleRunOptions is a bitfield list of options that can be passed
   into the ATSUFlattenStyleRunsToStream API. Currently, there are no options.
   This is here for future expansion.
}
type
	ATSUFlattenStyleRunOptions = UInt32;
const
	kATSUFlattenOptionNoOptionsMask = $00000000;

{
   ATSUUnFlattenStyleRunOptions is a bitfield list of options that can be passed
   into the ATSUUnFlattenStyleRunsToStream API. Currently, there are no options.
   This is here for future expansion.
}
type
	ATSUUnFlattenStyleRunOptions = UInt32;
const
	kATSUUnFlattenOptionNoOptionsMask = $00000000;


{ ---------------------------------------------------------------------------- }
{ Data Types                                                                   }
{ ---------------------------------------------------------------------------- }

{
   ATSUStyleRunInfo is a structure that contains an index into an array of
   unique ATSUStyle objects as well as the length of the run that the style run
   object covers. This structure is utilized by ATSUUnflattenStyleRunsFromStream()
   to return the style run info to the caller.
}
type
	ATSUStyleRunInfo = record
		runLength: UInt32;
		styleObjectIndex: UInt32;
	end;
	ATSUStyleRunInfoPtr = ^ATSUStyleRunInfo;
{ ---------------------------------------------------------------------------- }
{ 'ustl' structure data structures and definitions                             }
{ ---------------------------------------------------------------------------- }
{
   The 'ustl' data structure follows this format:
   1. Main Data Structure Block Header
   2. Flattened Text Layout Data
   3. Flattened Style Run Data
   4. Flattened Style Data
   Per the 'ustl' spec, these structures should maintain four-byte alignment.
   For things that are variable width (such as font names), padding bytes must
   be added to ensure that this alignment is always kept.
}

{
   structure versioning - the version of the 'ustl' that the ATSUI parsing
   and generating functions will handle is version 2 or greater. Earlier
   versions were not completly specified and have been obsoleted.
}
const
	kATSFlatDataUstlVersion0 = 0;
	kATSFlatDataUstlVersion1 = 1;
	kATSFlatDataUstlVersion2 = 2;
	kATSFlatDataUstlCurrentVersion = kATSFlatDataUstlVersion2;

{ ------------------ }
{ Block 1 Structures }
{ ------------------ }

{
   This is the main data structure block header. It describes the rest
   of the data and how it is structured.
}
type
	ATSFlatDataMainHeaderBlock = record
{ the 'ustl' version number. This needs to be the first item in the}
                                              { data block do as not to confuse parsers of earlier (and possibly}
                                              { later) versions of the spec *|}
		version: UInt32;

                                              { the total size of the stream in bytes, including the four bytes in}
                                              { the version above}
		sizeOfDataBlock: UInt32;

                                              { offset from the beginning of the stream to the flattened text layout data.}
                                              { This can be set to 0 if there are no text layouts stored in the stream.}
		offsetToTextLayouts: UInt32;

                                              { offset from the beginning of the stream to the flattened style run data. }
                                              { This can be set to 0 if there is no flattened style run data in the stream}
		offsetToStyleRuns: UInt32;

                                              { offset to the flattened style list data. This can be set to 0 if there}
                                              { is no flattened style list data}
		offsetToStyleList: UInt32;
	end;
	ATSFlatDataMainHeaderBlockPtr = ^ATSFlatDataMainHeaderBlock;
{ ------------------ }
{ Block 2 Structures }
{ ------------------ }
{
   The Block 2 Structures are not currently used by any of ATSUI's internal parsing
   or packing routines. They are, however, part of the 'ustl' standard and are put
   here for developer convenience, as well as to properly define the standard.
}

{
   This is the header that is attached to each flattened text layout. The
   number of flattened text layouts in the stucture is specified by the
   ATSFlatDataTextLayoutHeader structure that is below.
}
type
	ATSFlatDataTextLayoutDataHeader = record
{ the total size of this particular flattened text layout, including any}
                                              { padding bytes and such. }
		sizeOfLayoutData: UInt32;

                                              { the number of characters covered by this flattened text layout}
		textLayoutLength: UInt32;

                                              { the byte offset relative to the start of this structure to the flattened}
                                              { layout control data. This can be set to zero if there are no layout}
                                              { controls.}
		offsetToLayoutControls: UInt32;

                                              { the byte offset, relative to the start of this structure to the}
                                              { flattened line info. This can be set to zero if there is no line info }
                                              { in this layout.}
		offsetToLineInfo: UInt32;

                                              { if the offsetToLayoutControls is non-zero, then following this block}
                                              { there will be a ATSFlattenedLayoutDataFlattenedLayoutControlsHeader}
                                              { followed by an array of ATSFlattenedLayoutDataFlattenedLayoutControls}
                                              { structures. If the offsetToLineInfo is non-zero, then following the}
                                              { flattened layout controls will be a ATSFlatDataLineInfoHeader}
                                              { structure.}
	end;
	ATSFlatDataTextLayoutDataHeaderPtr = ^ATSFlatDataTextLayoutDataHeader;
{
   This is the the main header for block 2. If there is a block 2, then there
   needs to be one of these. This structure is what the offsetToTextLayouts
   points to in block 1.
}
type
	ATSFlatDataTextLayoutHeader = record
{ the total number of flattened text layouts stored in this block.}
                                              { This must be non-zero, as if there were no flattened text layouts, the}
                                              { entire block 2 would not exist}
		numFlattenedTextLayouts: UInt32;

                                              { first of possibly many flattened text layouts. There should be one of}
                                              { these for each flattened text layout as determined by the}
                                              { numFlattenedTextLayouts above. }
		flattenedTextLayouts: array[0..0] of ATSFlatDataTextLayoutDataHeader;
	end;
	ATSFlatDataTextLayoutHeaderPtr = ^ATSFlatDataTextLayoutHeader;
{
   This is the header for the flattened layout controls structure. This is
   the structure that a non-zero offsetToLayoutControls points to in the
   ATSFlatDataTextLayoutDataHeader
}
type
	ATSFlatDataLayoutControlsDataHeader = record
{ the number of flattened layout controls. It is suggested that there be}
                                              { at least one layout control to output the line direction for the layout}
		numberOfLayoutControls: UInt32;

                                              { first of possibly many flattened layout controls. There should be one }
                                              { of these for each layout control as determined by the}
                                              { numberOfLayoutControls above. Of course, if there are no layout controls,}
                                              { then this structure shouldn't even exist. Each attribute info structure}
                                              { in the array could be followed by additional padding bytes in order}
                                              { to maintain four-byte alignment. These padding bytes are not to be}
                                              { included in the fValueSize member of each structure. }
		controlArray: array[0..0] of ATSUAttributeInfo;
	end;
	ATSFlatDataLayoutControlsDataHeaderPtr = ^ATSFlatDataLayoutControlsDataHeader;
type
	ATSFlatDataLineInfoData = record
{ the length of this particular line in UniChars}
		lineLength: UInt32;

                                              { the number of line controls applied to this line. This can be set}
                                              { to zero if there are no special line controls applied to this line.}
		numberOfLineControls: UInt32;

                                              { the numberOfLineControls is non-zero, then following this structure}
                                              { must be an array of ATSUAttributeInfo structures. There must be one}
                                              { ATSUAttributeInfo structure for each numberOfLineControls above.}
	end;
	ATSFlatDataLineInfoDataPtr = ^ATSFlatDataLineInfoData;
{
   This structure is the main data header for the flattened line info data. This
   is what a non-zero offsetToLineInfo points to in the
   ATSFlatDataTextLayoutDataHeader structure above.
}
type
	ATSFlatDataLineInfoHeader = record
{ the number of flattened line info structures that are stored in this}
                                              { block. This value should really be equal to the number of soft line}
                                              { breaks in the layout + 1. Of course if numberOfLines is zero, then}
                                              { this structure shouldn't even be used.}
		numberOfLines: UInt32;

                                              { the first in a array of ATSFlatDataLineInfoData structures. There}
                                              { needs to be a ATSFlatDataLineInfoData for each numberOfLines}
                                              { specified above.}
		lineInfoArray: array[0..0] of ATSFlatDataLineInfoData;
	end;
	ATSFlatDataLineInfoHeaderPtr = ^ATSFlatDataLineInfoHeader;
{ ------------------ }
{ Block 3 Structures }
{ ------------------ }
{
   The block 3 structures are used by ATSUI style run flattening and parsing
   functions, ATSUFlattenStyleRunsToStream and ATSUUnflattenStyleRunsFromStream
   to represent flattened style run information. These structures go hand and
   hand with the block 4 structures.
}

{
   This is the data header that appears before the style run data structures.
   This structure is what a non-zero offsetToStyleRuns in the
   ATSFlatDataMainHeaderBlock points to in block 1.
}
type
	ATSFlatDataStyleRunDataHeader = record
{ the number of style run data structures stored in this block}
		numberOfStyleRuns: UInt32;

                                              { the first in an array of ATSUStyleRunInfo structures. There needs to}
                                              { be a ATSUStyleRunInfo structure for each numberOfStyleRuns specified}
                                              { above. This structure is defined in ATSUnicode.h}
		styleRunArray: array[0..0] of ATSUStyleRunInfo;
	end;
	ATSFlatDataStyleRunDataHeaderPtr = ^ATSFlatDataStyleRunDataHeader;
{ ------------------ }
{ Block 4 Structures }
{ ------------------ }
{
   The block 4 structures store flattened ATSUStyle objects. This too, is
   currently used by the ATSUI style run flattening and parsing functions,
   ATSUFlattenStyleRunsToStream and ATSUUnflattenStyleRunsFromStream.
}

{
   this structure forms the beginning of an individually flattened ATSUStyle
   object.
}
type
	ATSFlatDataStyleListStyleDataHeader = record
{ the size of this flattened style object, including these four bytes and}
                                              { any padding bytes at the end of the structure. Basically, this can be}
                                              { used to determine where the next structure in the array begins.}
		sizeOfStyleInfo: UInt32;

                                              { the number of attributes set in this flattened style object. This should }
                                              { be at least one for the font data, although it can be 0 if this is to be}
                                              { unspecified.}
		numberOfSetAttributes: UInt32;

                                              { the number of font features set in the flattened style object. This can}
                                              { be set to 0 if there are no font features set in the style object. }
		numberOfSetFeatures: UInt32;

                                              { the number of font variations set in the flattened style object. This}
                                              { can be set to 0 if there are no font variations set in the style object.}
		numberOfSetVariations: UInt32;

                                              { after this structure header, there is the following data in this block:}

                                              { 1. if the numberOfSetAttributes is non-zero, then there will be an}
                                              {       array of ATSUAttributeInfo structures immediately following the}
                                              {       above header data to store the style attributes. This is a variable}
                                              {       structure array. There must be one ATSUAttributeInfo for}
                                              {       for each numberOfSetAttributes. If numberOfSetAttributes is zero,}
                                              {       then skip to the next data section 2.}

                                              { 2. if the numberOfSetFeatures is non-zero, then there will be an array}
                                              {       of ATSFlatDataStyleListFeatureData structures immediately after}
                                              {       the ATSUAttributeInfo array above (if any). There must be one}
                                              {       ATSFlatDataStyleListFeatureData structure for each }
                                              {       numberOfSetFeatures set in the header above. If numberOfSetFeatures}
                                              {       is zero, then skip to the next data section 3.}

                                              { 3. if the numberOfSetVariations is non-zero, then there will be an}
                                              {       array of ATSFlatDataStyleListVariationData immediately after the}
                                              {       ATSFlatDataStyleListFeatureData array above (if any). There must be}
                                              {       one ATSFlatDataStyleListVariationData structure for each }
                                              {       numberOfSetVariations set in the header above.}
	end;
	ATSFlatDataStyleListStyleDataHeaderPtr = ^ATSFlatDataStyleListStyleDataHeader;
{
   this structure is the main header for this block. This structure is what a
   non-zero offsetToStyleList in the ATSFlatDataMainHeaderBlock points to in
   block 1.
}
type
	ATSFlatDataStyleListHeader = record
{ the total number of flattened style objects stored in this block}
		numberOfStyles: UInt32;

                                              { the first in an array of flattned style entries. The data stored}
                                              { in them is variably sized, so a simply array access won't do for}
                                              { iterating through these. However, there must be one of these}
                                              { ATSFlatDataStyleListStyleDataHeader structures for each }
                                              { numberOfStyles above.}
		styleDataArray: array[0..0] of ATSFlatDataStyleListStyleDataHeader;
	end;
	ATSFlatDataStyleListHeaderPtr = ^ATSFlatDataStyleListHeader;
{
   this structure stores flattened font feature data. An array of these comes
   after the array of font data attributes (if any) if the numberOfSetFeatures is
   non-zero. There must be one of these structures for each numberOfSetFeatures.
}
type
	ATSFlatDataStyleListFeatureData = record
{ the font feature type}
		theFeatureType: ATSUFontFeatureType;

                                              { the font feature selector}
		theFeatureSelector: ATSUFontFeatureSelector;
	end;
	ATSFlatDataStyleListFeatureDataPtr = ^ATSFlatDataStyleListFeatureData;
{
   this structure stores the flattened font variation data. An array of these
   comes after the array of ATSFlatDataStyleListFeatureData structures (if any)
   if the numberOfSetVariations is non-zero. There must be one of these
   structures for each numberOfSetFeatures.
}
type
	ATSFlatDataStyleListVariationData = record
{ the variation axis}
		theVariationAxis: ATSUFontVariationAxis;

                                              { the variation value}
		theVariationValue: ATSUFontVariationValue;
	end;
	ATSFlatDataStyleListVariationDataPtr = ^ATSFlatDataStyleListVariationData;
{ ------------------------ }
{ Flattened Font Data Info }
{ ------------------------ }
{
   This is somewhat of an addendum to the 'ustl' structure above. These flattened
   data structures are stored in block 4 as a font attribute with the attribute
   tag of kATSUFontTag. They can store font data in a few different ways, such as
   by a FontSync reference or by simple raw font name data. Just as with the
   'ustl' above, this structure must maintain four byte alignment.
}


{ these are the currently supported font specifiers. }
type
	ATSFlatDataFontSpeciferType = UInt32;
const
{ this specifier allows the storage of font data based on name data. This}
                                        { uses the structures below to store the actual data itself.}
	kATSFlattenedFontSpecifierRawNameData = FourCharCode('namd');

{
   this is the main header for the font data. It dictates what type of data
   is stored. The actual data stored must match the type specified by the
   nameSpecType.
}
type
	ATSFlatDataFontNameDataHeader = record
{ the type of data that is flattened in this structure}
		nameSpecifierType: ATSFlatDataFontSpeciferType;

                                              { the size of the data that is flattened in this structure, not including }
                                              { any padding bytes that may be necessary to achieve the four byte }
                                              { alignment of the data, unless they are specified as part of structure, }
                                              { such as with the ATSFlatDataFontSpecRawNameData structure.}
		nameSpecifierSize: UInt32;

                                              { after this header comes the flattened font name data which matches}
                                              { the type specified by the nameSpecifierType above. For instance, if }
                                              { the nameSpecType is kATSFlattenedFontNameSpecifierRawNameData, the}
                                              { structure that immediately follows this would be a}
                                              { ATSFlatDataFontNameRawNameDataHeader structure. }
	end;
	ATSFlatDataFontNameDataHeaderPtr = ^ATSFlatDataFontNameDataHeader;
{
   the next two structures are only used when the nameSpecType is set to
   kATSFlattenedFontSpecifierRawNameData. They are setup to store multiple
   font name table entries for the purposes of reconstructing an ATSUFontID
   for (hopefully) the same font some time in the future.
}
{ this is the structure in which raw font name data is actually stored. }
type
	ATSFlatDataFontSpecRawNameData = record
{ the type of name being specified}
		fontNameType: FontNameCode;

                                              { the platform type of the font name, whether it be Unicode, Mac, etc.  }
                                              { This should be specified if known. If not known, then specify}
                                              { kFontNoPlatform, but then all matching will be done based on the first}
                                              { font in the name table matching the other parameters.}
		fontNamePlatform: FontPlatformCode;

                                              { the script code of the font’s name based on the platform that was passed}
                                              { in above. If set to kFontNoScript, then the name will be matched based}
                                              { on the first font in the name table matching the other font name}
                                              { parameters.}
		fontNameScript: FontScriptCode;

                                              { the language of the font name. If set to kFontNoLanguage, then the name }
                                              { will be matched based on the first font in the name table matching the}
                                              { other font name parameters.}
		fontNameLanguage: FontLanguageCode;

                                              { the length of the font name in bytes, not including any padding bytes}
                                              { added to maintain the four byte alignment}
		fontNameLength: UInt32;

                                              { after the name length comes the actual font name data itself, plus any}
                                              { padding bytes needed to maintain the four byte alignment.}
	end;
	ATSFlatDataFontSpecRawNameDataPtr = ^ATSFlatDataFontSpecRawNameData;
{
   this is a header structure that defines some things constant throughout
   the entire search for the font name, as well as the array of
   ATSFlatDataFontNameData structures. In order to gaurantee that the same font
   will be used, more than one name specifer should be stored. The standard ATSUI
   style run flattening and parsing functions, ATSUFlattenStyleRunsToStream and
   ATSUUnflattenStyleRunsFromStream. These will store both the font's full name
   (kFontFullName) as well as the font's manufacturer name (kFontManufacturerName)
   and match fonts based on both of
   these.
}
type
	ATSFlatDataFontSpecRawNameDataHeader = record
{ the number of flattened font names. There must be at least one flattened }
                                              { font name, otherwise the structure is malformed.}
		numberOfFlattenedNames: UInt32;

                                              { the first in an array of possibly many font name specifiers - depending}
                                              { on how specific the caller wants this. There must be one }
                                              { ATSFlatDataFontNameData structure for each numberOfFlattenedNames}
                                              { above.}
		nameDataArray: array[0..0] of ATSFlatDataFontSpecRawNameData;
	end;
	ATSFlatDataFontSpecRawNameDataHeaderPtr = ^ATSFlatDataFontSpecRawNameDataHeader;
{ ---------------------------------------------------------------------------- }
{ Style Flattening and Parsing Functions                                       }
{ ---------------------------------------------------------------------------- }


{$endc} {TARGET_OS_MAC}
{$ifc not defined MACOSALLINCLUDE or not MACOSALLINCLUDE}

end.
{$endc} {not MACOSALLINCLUDE}
