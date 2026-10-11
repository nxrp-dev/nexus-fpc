{
     File:       LangAnalysis/Dictionary.h

     Contains:   Dictionary Manager Interfaces

     Version:    LanguageAnalysis-242~23

     Copyright:  © 1992-2008 by Apple Inc., all rights reserved.

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
unit Dictionary;
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
uses MacOsApi.MacTypes,MacOsApi.AEDataModel,MacOsApi.Files,MacOsApi.AERegistry,MacOsApi.CodeFragments,MacOsApi.MacErrors;
{$ELSE FPC_DOTTEDUNITS}
uses MacTypes,AEDataModel,Files,AERegistry,CodeFragments,MacErrors;
{$ENDIF FPC_DOTTEDUNITS}
{$endc} {not MACOSALLINCLUDE}


{$ifc TARGET_OS_MAC}

{$ALIGN POWER}

{
=============================================================================================
 Modern Dictionary Manager
=============================================================================================
}
{
    Dictionary information
}
const
	kDictionaryFileType = FourCharCode('dict');
	kDCMDictionaryHeaderSignature = FourCharCode('dict');
	kDCMDictionaryHeaderVersion = 2;

const
	kDCMAnyFieldTag = typeWildCard;
	kDCMAnyFieldType = typeWildCard;

{
    Contents of a Field Info Record (an AERecord)
}
const
	keyDCMFieldTag = FourCharCode('ftag'); { typeEnumeration }
	keyDCMFieldType = FourCharCode('ftyp'); { typeEnumeration }
	keyDCMMaxRecordSize = FourCharCode('mrsz'); { typeMagnitude }
	keyDCMFieldAttributes = FourCharCode('fatr');
	keyDCMFieldDefaultData = FourCharCode('fdef');
	keyDCMFieldName = FourCharCode('fnam'); { typeChar }
	keyDCMFieldFindMethods = FourCharCode('ffnd'); { typeAEList of typeDCMFindMethod }

{
    Special types for fields of a Field Info Record
}
const
	typeDCMFieldAttributes = FourCharCode('fatr');
	typeDCMFindMethod = FourCharCode('fmth');


{
    Field attributes
}
const
	kDCMIndexedFieldMask = $00000001;
	kDCMRequiredFieldMask = $00000002;
	kDCMIdentifyFieldMask = $00000004;
	kDCMFixedSizeFieldMask = $00000008;
	kDCMHiddenFieldMask = $80000000;

type
	DCMFieldAttributes = OptionBits;
{
    Standard dictionary properties
}
const
	pDCMAccessMethod = FourCharCode('amtd'); { data type: typeChar ReadOnly }
	pDCMPermission = FourCharCode('perm'); { data type: typeUInt16 }
	pDCMListing = FourCharCode('list'); { data type: typeUInt16 }
	pDCMMaintenance = FourCharCode('mtnc'); { data type: typeUInt16 }
	pDCMLocale = FourCharCode('locl'); { data type: typeUInt32.  Optional; default = kLocaleIdentifierWildCard }
	pDCMClass = pClass; { data type: typeUInt16 }
	pDCMCopyright = FourCharCode('info'); { data type: typeChar }

{
    pDCMPermission property constants
}
const
	kDCMReadOnlyDictionary = 0;
	kDCMReadWriteDictionary = 1;

{
    pDCMListing property constants
}
const
	kDCMAllowListing = 0;
	kDCMProhibitListing = 1;

{
    pDCMClass property constants
}
const
	kDCMUserDictionaryClass = 0;
	kDCMSpecificDictionaryClass = 1;
	kDCMBasicDictionaryClass = 2;

{
    Standard search method
}
const
	kDCMFindMethodExactMatch = kAEEquals;
	kDCMFindMethodBeginningMatch = kAEBeginsWith;
	kDCMFindMethodContainsMatch = kAEContains;
	kDCMFindMethodEndingMatch = kAEEndsWith;
	kDCMFindMethodForwardTrie = FourCharCode('ftri'); { used for morphological analysis}
	kDCMFindMethodBackwardTrie = FourCharCode('btri'); { used for morphological analysis}

type
	DCMFindMethod = OSType;
	DCMFindMethodPtr = ^DCMFindMethod;
{
    AccessMethod features
}
const
	kDCMCanUseFileDictionaryMask = $00000001;
	kDCMCanUseMemoryDictionaryMask = $00000002;
	kDCMCanStreamDictionaryMask = $00000004;
	kDCMCanHaveMultipleIndexMask = $00000008;
	kDCMCanModifyDictionaryMask = $00000010;
	kDCMCanCreateDictionaryMask = $00000020;
	kDCMCanAddDictionaryFieldMask = $00000040;
	kDCMCanUseTransactionMask = $00000080;

type
	DCMAccessMethodFeature = OptionBits;
	DCMUniqueID = UInt32;
	DCMObjectID = ^OpaqueDCMObjectID; { an opaque type }
	OpaqueDCMObjectID = record end;
	DCMObjectIDPtr = ^DCMObjectID;  { when a var xx:DCMObjectID parameter can be nil, it is changed to xx: DCMObjectIDPtr }
	DCMAccessMethodID = DCMObjectID;
	DCMDictionaryID = DCMObjectID;
	DCMObjectRef = ^OpaqueDCMObjectRef; { an opaque type }
	OpaqueDCMObjectRef = record end;
	DCMObjectRefPtr = ^DCMObjectRef;  { when a var xx:DCMObjectRef parameter can be nil, it is changed to xx: DCMObjectRefPtr }
	DCMDictionaryRef = DCMObjectRef;
	DCMDictionaryStreamRef = DCMObjectRef;
	DCMObjectIterator = ^OpaqueDCMObjectIterator; { an opaque type }
	OpaqueDCMObjectIterator = record end;
	DCMObjectIteratorPtr = ^DCMObjectIterator;  { when a var xx:DCMObjectIterator parameter can be nil, it is changed to xx: DCMObjectIteratorPtr }
	DCMAccessMethodIterator = DCMObjectIterator;
	DCMDictionaryIterator = DCMObjectIterator;
	DCMFoundRecordIterator = ^OpaqueDCMFoundRecordIterator; { an opaque type }
	OpaqueDCMFoundRecordIterator = record end;
	DCMFoundRecordIteratorPtr = ^DCMFoundRecordIterator;  { when a var xx:DCMFoundRecordIterator parameter can be nil, it is changed to xx: DCMFoundRecordIteratorPtr }
{
    Field specification declarations
}
type
	DCMFieldTag = DescType;
	DCMFieldTagPtr = ^DCMFieldTag;
	DCMFieldType = DescType;
{
    Dictionary header information
}
type
	DCMDictionaryHeader = record
		headerSignature: FourCharCode;
		headerVersion: UInt32;
		headerSize: UInt32;
		accessMethod: Str63;
	end;
{
    Callback routines
}
type
	DCMProgressFilterProcPtr = function( determinateProcess: Boolean; percentageComplete: UInt16; callbackUD: UInt32 ): Boolean;
	DCMProgressFilterUPP = DCMProgressFilterProcPtr;
{
 *  NewDCMProgressFilterUPP()
 *
 *  Availability:
 *    Mac OS X:         not available
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   available as macro/inline
 }

{
 *  DisposeDCMProgressFilterUPP()
 *
 *  Availability:
 *    Mac OS X:         not available
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   available as macro/inline
 }

{
 *  InvokeDCMProgressFilterUPP()
 *
 *  Availability:
 *    Mac OS X:         not available
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   available as macro/inline
 }


{
    Check Dictionary Manager availability
}
{$ifc TARGET_RT_MAC_CFM}
{
        DCMDictionaryManagerAvailable() is a macro available only in C/C++.
        To get the same functionality from pascal or assembly, you need
        to test if Dictionary Manager functions are not NULL.
        For instance:

            IF @DCMLibraryVersion <> kUnresolvedCFragSymbolAddress THEN
                gDictionaryManagerAvailable = TRUE;
            ELSE
                gDictionaryManagerAvailable = FALSE;
            end

}
{$elsec}
  {$ifc TARGET_RT_MAC_MACHO}
{ Dictionary Manager is always available on OS X }
  {$endc}
{$endc}

{
=============================================================================================
    Definitions for Japanese Analysis Module
=============================================================================================
}
{
    Default dictionary access method for Japanese analysis
}
const
	kAppleJapaneseDefaultAccessMethodName = 'DAM:Apple Backward Trie Access Method';
{
    Data length limitations of Apple Japanese dictionaries
}

const
	kMaxYomiLengthInAppleJapaneseDictionary = 40;
	kMaxKanjiLengthInAppleJapaneseDictionary = 64;

{
    Defined field tags of Apple Japanese dictionary
}
const
	kDCMJapaneseYomiTag = FourCharCode('yomi');
	kDCMJapaneseHyokiTag = FourCharCode('hyok');
	kDCMJapaneseHinshiTag = FourCharCode('hins');
	kDCMJapaneseWeightTag = FourCharCode('hind');
	kDCMJapanesePhoneticTag = FourCharCode('hton');
	kDCMJapaneseAccentTag = FourCharCode('acnt');
	kDCMJapaneseOnKunReadingTag = FourCharCode('OnKn');
	kDCMJapaneseFukugouInfoTag = FourCharCode('fuku');

const
	kDCMJapaneseYomiType = typeUnicodeText;
	kDCMJapaneseHyokiType = typeUnicodeText;
	kDCMJapaneseHinshiType = FourCharCode('hins');
	kDCMJapaneseWeightType = typeSInt16;
	kDCMJapanesePhoneticType = typeUnicodeText;
	kDCMJapaneseAccentType = FourCharCode('byte');
	kDCMJapaneseOnKunReadingType = typeUnicodeText;
	kDCMJapaneseFukugouInfoType = FourCharCode('fuku');


{$endc} {TARGET_OS_MAC}

{$ifc not defined MACOSALLINCLUDE or not MACOSALLINCLUDE}

end.
{$endc} {not MACOSALLINCLUDE}
