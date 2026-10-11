{
     File:       QD/FontSync.h

     Contains:   Public interface for FontSync

     Version:    Quickdraw-262~1

     Copyright:  © 1999-2008 by Apple Inc. all rights reserved.

     Bugs?:      For bug reports, consult the following page on
                 the World Wide Web:

                     http://bugs.freepascal.org

}
{   Pascal Translation Updated:  Jonas Maebe, <jonas@freepascal.org>, October 2009 }
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
unit FontSync;
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
uses MacOsApi.MacTypes,MacOsApi.ATSTypes,MacOsApi.Files,MacOsApi.Fonts,MacOsApi.SFNTTypes,MacOsApi.MacErrors;
{$ELSE FPC_DOTTEDUNITS}
uses MacTypes,ATSTypes,Files,Fonts,SFNTTypes,MacErrors;
{$ENDIF FPC_DOTTEDUNITS}
{$endc} {not MACOSALLINCLUDE}


{$ifc TARGET_OS_MAC}

{$ALIGN POWER}


{ Matching Options }
type
	FNSMatchOptions = UInt32;
	FNSMatchOptionsPtr = ^FNSMatchOptions; { when a VAR xx: FNSMatchOptions parameter can be nil, it is changed to xx: FNSMatchOptionsPtr }
const
	kFNSMatchNames = $00000001; { font names must match }
	kFNSMatchTechnology = $00000002; { scaler technology must match }
	kFNSMatchGlyphs = $00000004; { glyph data must match }
	kFNSMatchEncodings = $00000008; { cmaps must match }
	kFNSMatchQDMetrics = $00000010; { QuickDraw Text metrics must match }
	kFNSMatchATSUMetrics = $00000020; { ATSUI metrics (incl. vertical) must match }
	kFNSMatchKerning = $00000040; { kerning data must match }
	kFNSMatchWSLayout = $00000080; { WorldScript layout tables must match }
	kFNSMatchAATLayout = $00000100; { AAT (incl. OpenType) layout tables must match }
	kFNSMatchPrintEncoding = $00000200; { PostScript font and glyph names and re-encoding vector must match }
	kFNSMissingDataNoMatch = $80000000; { treat missing data as mismatch }
	kFNSMatchAll = $FFFFFFFF; { everything must match }
	kFNSMatchDefaults = 0;     { use global default match options }


type
	FNSObjectVersion = UInt32;
const
	kFNSVersionDontCare = 0;
	kFNSCurSysInfoVersion = 1;

{ No features defined yet.}
type
	FNSFeatureFlags = UInt32;
{
   The FontSync library version number is binary-coded decimal:
   8 bits of major version, 4 minor version and 4 bits revision.
}
type
	FNSSysInfoPtr = ^FNSSysInfo;
	FNSSysInfo = record
		iSysInfoVersion: FNSObjectVersion;        { fill this in before calling FNSSysInfoGet}
		oFeatures: FNSFeatureFlags;
		oCurRefVersion: FNSObjectVersion;
		oMinRefVersion: FNSObjectVersion;
		oCurProfileVersion: FNSObjectVersion;
		oMinProfileVersion: FNSObjectVersion;
		oFontSyncVersion: UInt16;
	end;

type
	FNSFontReference = ^SInt32; { an opaque type }
	FNSFontReferencePtr = ^FNSFontReference;  { when a var xx:FNSFontReference parameter can be nil, it is changed to xx: FNSFontReferencePtr }

const
	kFNSCreatorDefault = 0;
	kFNSProfileFileType = FourCharCode('fnsp');

type
	FNSFontProfile = ^SInt32; { an opaque type }
	FNSFontProfilePtr = ^FNSFontProfile;  { when a var xx:FNSFontProfile parameter can be nil, it is changed to xx: FNSFontProfilePtr }


{$endc} {TARGET_OS_MAC}

{$ifc not defined MACOSALLINCLUDE or not MACOSALLINCLUDE}

end.
{$endc} {not MACOSALLINCLUDE}
