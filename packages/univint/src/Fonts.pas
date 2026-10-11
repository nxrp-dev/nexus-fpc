{
     File:       QD/Fonts.h

     Contains:   Public interface to the Font Manager.

     Version:    Quickdraw-285~150

     Copyright:  © 1985-2008 by Apple Inc. all rights reserved.

     Bugs?:      For bug reports, consult the following page on
                 the World Wide Web:

                     http://bugs.freepascal.org

}
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
unit Fonts;
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
uses MacOsApi.MacTypes,MacOsApi.QuickdrawText,MacOsApi.ATSTypes,MacOsApi.Files,MacOsApi.MacErrors,MacOsApi.QuickdrawTypes,MacOsApi.TextCommon,MacOsApi.CGFont;
{$ELSE FPC_DOTTEDUNITS}
uses MacTypes,QuickdrawText,ATSTypes,Files,MacErrors,QuickdrawTypes,TextCommon,CGFont;
{$ENDIF FPC_DOTTEDUNITS}
{$endc} {not MACOSALLINCLUDE}


{$ifc TARGET_OS_MAC}

{$ALIGN MAC68K}


const
	systemFont = 0;
	applFont = 1;

const
	kFMDefaultOptions = kNilOptions;

{ Activation contexts }
const
	kFMDefaultActivationContext = kFMDefaultOptions;
	kFMGlobalActivationContext = $00000001;
	kFMLocalActivationContext = kFMDefaultActivationContext;

{ Iteration scopes }
const
	kFMDefaultIterationScope = kFMDefaultOptions;
	kFMGlobalIterationScope = $00000001;
	kFMLocalIterationScope = kFMDefaultIterationScope;

{ kPlatformDefaultGuiFontID is used in QuickTime 3.0. }
const
	kPlatformDefaultGuiFontID = applFont;

const
	commandMark = 17;
	checkMark = 18;
	diamondMark = 19;
	appleMark = 20;

const
	propFont = 36864;
	prpFntH = 36865;
	prpFntW = 36866;
	prpFntHW = 36867;
	fixedFont = 45056;
	fxdFntH = 45057;
	fxdFntW = 45058;
	fxdFntHW = 45059;
	fontWid = 44208;

type
	FontRec = record
		fontType: SInt16;               {font type}
		firstChar: SInt16;              {ASCII code of first character}
		lastChar: SInt16;               {ASCII code of last character}
		widMax: SInt16;                 {maximum character width}
		kernMax: SInt16;                {negative of maximum character kern}
		nDescent: SInt16;               {negative of descent}
		fRectWidth: SInt16;             {width of font rectangle}
		fRectHeight: SInt16;            {height of font rectangle}
		owTLoc: UInt16;                 {offset to offset/width table}
		ascent: SInt16;                 {ascent}
		descent: SInt16;                {descent}
		leading: SInt16;                {leading}
		rowWords: SInt16;               {row width of bit image / 2 }
	end;
	FontRecPtr = ^FontRec;
type
	FontRecHdl = ^FontRecPtr;
	FMInput = record
		family: SInt16;
		size: SInt16;
		face: Style;
		needBits: Boolean;
		device: SInt16;
		numer: Point;
		denom: Point;
	end;
	FMInputPtr = ^FMInput;
type
	FamRecPtr = ^FamRec;
	FamRec = record
		ffFlags: SInt16;                {flags for family}
		ffFamID: SInt16;                {family ID number}
		ffFirstChar: SInt16;            {ASCII code of 1st character}
		ffLastChar: SInt16;             {ASCII code of last character}
		ffAscent: SInt16;               {maximum ascent for 1pt font}
		ffDescent: SInt16;              {maximum descent for 1pt font}
		ffLeading: SInt16;              {maximum leading for 1pt font}
		ffWidMax: SInt16;               {maximum widMax for 1pt font}
		ffWTabOff: SInt32;              {offset to width table}
		ffKernOff: SInt32;              {offset to kerning table}
		ffStylOff: SInt32;              {offset to style mapping table}
		ffProperty: array [0..8] of SInt16;          {style property info}
		ffIntl: array [0..1] of SInt16;              {for international use}
		ffVersion: SInt16;              {version number}
	end;
type
	AsscEntryPtr = ^AsscEntry;
	AsscEntry = record
		fontSize: SInt16;
		fontStyle: SInt16;
		fontID: SInt16;                 {font resource ID}
	end;
type
	FontAssocPtr = ^FontAssoc;
	FontAssoc = record
		numAssoc: SInt16;               {number of entries - 1}
	end;
type
	StyleTablePtr = ^StyleTable;
	StyleTable = record
		fontClass: SInt16;
		offset: SInt32;
		reserved: SInt32;
		indexes: array [0..47] of SInt8;
	end;
type
	NameTablePtr = ^NameTable;
	NameTable = record
		stringCount: SInt16;
		baseFontName: Str255;
	end;
type
	KernPairPtr = ^KernPair;
	KernPair = record
		kernFirst: AnsiChar;              {1st character of kerned pair}
		kernSecond: AnsiChar;             {2nd character of kerned pair}
		kernWidth: SInt16;              {kerning in 1pt fixed format}
	end;
type
	KernEntryPtr = ^KernEntry;
	KernEntry = record
		kernStyle: SInt16;              {style the entry applies to}
		kernLength: SInt16;             {length of this entry}
	end;
type
	KernTablePtr = ^KernTable;
	KernTable = record
		numKerns: SInt16;               {number of kerning entries}
	end;
	FMOutput = record
		errNum: SInt16;
		fontHandle: Handle;
		boldPixels: UInt8;
		italicPixels: UInt8;
		ulOffset: UInt8;
		ulShadow: UInt8;
		ulThick: UInt8;
		shadowPixels: UInt8;
		extra: SInt8;
		ascent: UInt8;
		descent: UInt8;
		widMax: UInt8;
		leading: SInt8;
		curStyle: SInt8;
		numer: Point;
		denom: Point;
	end;
	FMOutputPtr = ^FMOutput;
type
	FMOutPtr = FMOutputPtr;
	FMetricRec = record
		ascent: Fixed;                 {base line to top}
		descent: Fixed;                {base line to bottom}
		leading: Fixed;                {leading between lines}
		widMax: Fixed;                 {maximum character width}
		wTabHandle: Handle;             {handle to font width table}
	end;
	FMetricRecPtr = ^FMetricRec;
type
	FMetricRecHandle = ^FMetricRecPtr;

{
 *  FlushFonts()
 *
 *  Availability:
 *    Mac OS X:         not available
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   in InterfaceLib 7.1 and later
 }




type
	FontFamilyID = FMFontFamily;
	FontPointSize = FMFontSize;
const
	kFMUseGlobalScopeOption = $00000001;

{
 *  The font identifier constants are deprecated; use ATSFontFamilyFindFromQuickDrawName in ATSFont.h
 *  to find a font family from a standard QuickDraw name.
 }
const
	kFontIDNewYork = 2;
	kFontIDGeneva = 3;
	kFontIDMonaco = 4;
	kFontIDVenice = 5;
	kFontIDLondon = 6;
	kFontIDAthens = 7;
	kFontIDSanFrancisco = 8;
	kFontIDToronto = 9;
	kFontIDCairo = 11;
	kFontIDLosAngeles = 12;
	kFontIDTimes = 20;
	kFontIDHelvetica = 21;
	kFontIDCourier = 22;
	kFontIDSymbol = 23;
	kFontIDMobile = 24;

{
 *  The following data structures referenced by the low memory global variables of QuickDraw are
 *  deprecated on Mac OS X and CarbonLib 1.1. The low memory global variables are not shared between
 *  processes and may result in inconsistencies compared to previous releases of the system software.
 *  Changes made to the information contained in the low memory global variables, including any
 *  indirectly referenced width tables, font family records, and font records, are not reflected in
 *  the global state for QuickDraw and should only be accessed through the font access and data
 *  management functions of ATS.
 }
type
	WidEntryPtr = ^WidEntry;
	WidEntry = record
		widStyle: SInt16;               {style entry applies to}
	end;
type
	WidTablePtr = ^WidTable;
	WidTable = record
		numWidths: SInt16;              {number of entries - 1}
	end;
type
	WidthTable = packed record
		tabData: array [0..255] of Fixed;           {character widths}
		tabFont: Handle;                {font record used to build table}
		sExtra: SIGNEDLONG;                 {space extra used for table}
		style: SIGNEDLONG;                  {extra due to style}
		fID: SInt16;                    {font family ID}
		fSize: SInt16;                  {font size request}
		face: SInt16;                   {style (face) request}
		device: SInt16;                 {device requested}
		inNumer: Point;                {scale factors requested}
		inDenom: Point;                {scale factors requested}
		aFID: SInt16;                   {actual font family ID for table}
		fHand: Handle;                  {family record used to build up table}
		usedFam: Boolean;                {used fixed point family widths}
		aFace: UInt8;                  {actual face produced}
		vOutput: SInt16;                {vertical scale output value}
		hOutput: SInt16;                {horizontal scale output value}
		vFactor: SInt16;                {vertical scale output value}
		hFactor: SInt16;                {horizontal scale output value}
		aSize: SInt16;                  {actual size of actual font used}
		tabSize: SInt16;                {total size of table}
	end;
	WidthTablePtr = ^WidthTable;
type
	WidthTableHdl = ^WidthTablePtr;
{$ifc OLDROUTINENAMES}
const
	newYork = kFontIDNewYork;
	geneva = kFontIDGeneva;
	monaco = kFontIDMonaco;
	venice = kFontIDVenice;
	london = kFontIDLondon;
	athens = kFontIDAthens;
	sanFran = kFontIDSanFrancisco;
	toronto = kFontIDToronto;
	cairo = kFontIDCairo;
	losAngeles = kFontIDLosAngeles;
	times = kFontIDTimes;
	helvetica = kFontIDHelvetica;
	courier = kFontIDCourier;
	symbol = kFontIDSymbol;
	mobile = kFontIDMobile;

{$endc} {OLDROUTINENAMES}


{$endc} {TARGET_OS_MAC}

{$ifc not defined MACOSALLINCLUDE or not MACOSALLINCLUDE}

end.
{$endc} {not MACOSALLINCLUDE}
