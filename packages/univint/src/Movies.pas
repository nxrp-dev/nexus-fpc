{
     File:       QuickTime/Movies.h

     Contains:   QuickTime Interfaces.

     Version:    QuickTime 7.7.1

     Copyright:  © 1990-2012 by Apple Inc., all rights reserved

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
unit Movies;
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
uses MacOsApi.MacTypes,MacOsApi.Aliases,MacOsApi.Components,MacOsApi.Dialogs,MacOsApi.Events,MacOsApi.Files,MacOsApi.Menus,MacOsApi.ImageCompression,MacOsApi.QDOffscreen,MacOsApi.QuickdrawTypes,MacOsApi.TextEdit,MacOsApi.HIObject,MacOsApi.CFBase,MacOsApi.CFDictionary,MacOsApi.CFString,MacOsApi.CoreAudioTypes,MacOsApi.AUComponent;
{$ELSE FPC_DOTTEDUNITS}
uses MacTypes,Aliases,Components,Dialogs,Events,Files,Menus,ImageCompression,QDOffscreen,QuickdrawTypes,TextEdit,HIObject,CFBase,CFDictionary,CFString,CoreAudioTypes,AUComponent;
{$ENDIF FPC_DOTTEDUNITS}
{$endc} {not MACOSALLINCLUDE}


{$ifc TARGET_OS_MAC}

{
    Important note regarding availability macros
    ============================================

    QuickTime APIs that were introduced in QuickTime 6.0 and later are tagged with
    availability macros indicating the first Mac OS X version in which they were
    *always* available.  Such APIs may also be present on systems running earlier
    Mac OS X releases when QuickTime updates have been installed.

    For example, QTNewDataReferenceFromCFURL was introduced in QuickTime 6.4.
    It is always available on Mac OS X 10.3, which shipped with QuickTime 6.4.
    However, QuickTime 6.4 can also be installed as an update to Mac OS X 10.2.x,
    so QTNewDataReferenceFromCFURL is also available on some systems running
    Mac OS X 10.2.x.

    QuickTime 6.0 / Mac OS X 10.2  :  AVAILABLE_MAC_OS_X_VERSION_10_2_AND_LATER
    QuickTime 6.4 / Mac OS X 10.3  :  AVAILABLE_MAC_OS_X_VERSION_10_3_AND_LATER
    QuickTime 7.0 / Mac OS X 10.4  :  AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER
    QuickTime 7.2 / Mac OS X 10.5  :  AVAILABLE_MAC_OS_X_VERSION_10_5_AND_LATER

    As described in /usr/include/AvailabilityMacros.h, you can use the
    MAC_OS_X_VERSION_MIN_REQUIRED macro to weak-link to the APIs that may not be
    available on the Mac OS X versions your software targets.
}


{$ALIGN MAC68K}

{ This sets the user defined exportset name i.e. fw_QuickTime_XManchego, available on 10.5 or later, and comment [4486184] }
{ NOTE:  Requires Interfacer-35 or later }
{ <exportset=fw_QuickTime_XManchego> }
{ <exportset=fw_QuickTime_XMaguro> }

{  "kFix1" is defined in FixMath as "fixed1"  }
{ error codes are in Errors.[haa] }
{ gestalt codes are in Gestalt.[hpa] }
const
	MovieFileType = FourCharCode('MooV');
	MovieScrapType = FourCharCode('moov');

const
	MovieResourceType = FourCharCode('moov');
	MovieForwardPointerResourceType = FourCharCode('fore');
	MovieBackwardPointerResourceType = FourCharCode('back');

const
	MovieResourceAtomType = FourCharCode('moov');
	MovieDataAtomType = FourCharCode('mdat');
	FreeAtomType = FourCharCode('free');
	SkipAtomType = FourCharCode('skip');
	WideAtomPlaceholderType = FourCharCode('wide');

const
	MediaHandlerType = FourCharCode('mhlr');
	DataHandlerType = FourCharCode('dhlr');

const
	VideoMediaType = FourCharCode('vide');
	SoundMediaType = FourCharCode('soun');
	TextMediaType = FourCharCode('text');
	BaseMediaType = FourCharCode('gnrc');
	MPEGMediaType = FourCharCode('MPEG');
	MusicMediaType = FourCharCode('musi');
	TimeCodeMediaType = FourCharCode('tmcd');
	SpriteMediaType = FourCharCode('sprt');
	FlashMediaType = FourCharCode('flsh');
	MovieMediaType = FourCharCode('moov');
	TweenMediaType = FourCharCode('twen');
	ThreeDeeMediaType = FourCharCode('qd3d');
	SkinMediaType = FourCharCode('skin');
	HandleDataHandlerSubType = FourCharCode('hndl');
	PointerDataHandlerSubType = FourCharCode('ptr ');
	NullDataHandlerSubType = FourCharCode('null');
	ResourceDataHandlerSubType = FourCharCode('rsrc');
	URLDataHandlerSubType = FourCharCode('url ');
	AliasDataHandlerSubType = FourCharCode('alis');
	WiredActionHandlerType = FourCharCode('wire');
	kQTQuartzComposerMediaType = FourCharCode('qtz ');
	TimeCode64MediaType = FourCharCode('tc64');

const
	VisualMediaCharacteristic = FourCharCode('eyes');
	AudioMediaCharacteristic = FourCharCode('ears');
	kCharacteristicCanSendVideo = FourCharCode('vsnd');
	kCharacteristicProvidesActions = FourCharCode('actn');
	kCharacteristicNonLinear = FourCharCode('nonl');
	kCharacteristicCanStep = FourCharCode('step');
	kCharacteristicHasNoDuration = FourCharCode('noti');
	kCharacteristicHasSkinData = FourCharCode('skin');
	kCharacteristicProvidesKeyFocus = FourCharCode('keyf');
	kCharacteristicSupportsDisplayOffsets = FourCharCode('dtdd');

const
	kUserDataMovieControllerType = FourCharCode('ctyp');
	kUserDataName = FourCharCode('name');
	kUserDataTextAlbum = FourCharCode('©alb');
	kUserDataTextArtist = FourCharCode('©ART');
	kUserDataTextAuthor = FourCharCode('©aut');
	kUserDataTextChapter = FourCharCode('©chp');
	kUserDataTextComment = FourCharCode('©cmt');
	kUserDataTextComposer = FourCharCode('©com');
	kUserDataTextCopyright = FourCharCode('©cpy');
	kUserDataTextCreationDate	= FourCharCode('©day');
	kUserDataTextDescription = FourCharCode('©des');
	kUserDataTextDirector = FourCharCode('©dir');
	kUserDataTextDisclaimer = FourCharCode('©dis');
	kUserDataTextEncodedBy = FourCharCode('©enc');
	kUserDataTextFullName = FourCharCode('©nam');
	kUserDataTextGenre = FourCharCode('©gen');
	kUserDataTextHostComputer	= FourCharCode('©hst');
	kUserDataTextInformation = FourCharCode('©inf');
	kUserDataTextKeywords = FourCharCode('©key');
	kUserDataTextMake = FourCharCode('©mak');
	kUserDataTextModel = FourCharCode('©mod');
	kUserDataTextOriginalArtist	= FourCharCode('©ope');
	kUserDataTextOriginalFormat	= FourCharCode('©fmt');
	kUserDataTextOriginalSource	= FourCharCode('©src');
	kUserDataTextPerformers = FourCharCode('©prf');
	kUserDataTextProducer = FourCharCode('©prd');
	kUserDataTextPublisher = FourCharCode('©pub');
	kUserDataTextProduct = FourCharCode('©PRD');
	kUserDataTextSoftware = FourCharCode('©swr');
	kUserDataTextSpecialPlaybackRequirements = FourCharCode('©req');
	kUserDataTextTrack = FourCharCode('©trk');
	kUserDataTextWarning = FourCharCode('©wrn');
	kUserDataTextWriter = FourCharCode('©wrt');
	kUserDataTextURLLink = FourCharCode('©url');
	kUserDataTextEditDate1 = FourCharCode('©ed1');
	kUserDataAnimatedGIFLoopCount = FourCharCode('gifc'); { data is big-endian UInt16 }
	kQTAnimatedGIFLoopCountInfinite = 0;
	kUserDataAnimatedGIFBufferingSize = FourCharCode('gifb'); { data is big-endian UInt32 }

const
	kUserDataUnicodeBit = 1 shl 7;

const
	DoTheRightThing = 0;




type
	SampleDescription = record
		descSize: SInt32;
		dataFormat: SInt32;
		resvd1: SInt32;
		resvd2: SInt16;
		dataRefIndex: SInt16;
	end;
	SampleDescriptionPtr = ^SampleDescription;
type
	SampleDescriptionHandle = ^SampleDescriptionPtr;


{************************
 * SoundDescription
 ************************}
type
	SoundDescription = record
		descSize: SInt32;               { total size of SoundDescription including extra data }
		dataFormat: SInt32;             { sound format }
		resvd1: SInt32;                 { reserved for apple use. set to zero }
		resvd2: SInt16;                 { reserved for apple use. set to zero }
		dataRefIndex: SInt16;
		version: SInt16;                { which version is this data }
		revlevel: SInt16;               { what version of that codec did this }
		vendor: SInt32;                 { whose  codec compressed this data }
		numChannels: SInt16;            { number of channels of sound }
		sampleSize: SInt16;             { number of bits per sample }
		compressionID: SInt16;          { unused. set to zero. }
		packetSize: SInt16;             { unused. set to zero. }
		sampleRate: UnsignedFixed;             { sample rate sound is captured at }
	end;
	SoundDescriptionPtr = ^SoundDescription;
type
	SoundDescriptionHandle = ^SoundDescriptionPtr;
{ version 1 of the SoundDescription record}
type
	SoundDescriptionV1 = record
{ original fields}
		desc: SoundDescription;
                                              { fixed compression ratio information}
		samplesPerPacket: UInt32;
		bytesPerPacket: UInt32;
		bytesPerFrame: UInt32;
		bytesPerSample: UInt32;
                                              { additional atom based fields ([long size, long type, some data], repeat)}
	end;
	SoundDescriptionV1Ptr = ^SoundDescriptionV1;
type
	SoundDescriptionV1Handle = ^SoundDescriptionV1Ptr;
{
   Definitions for SoundDescriptionV2:
        LPCMFrame = one uncompressed sample in each of the channels (ie. 44100Hz audio has
                44100 LPCMFrames per second, whether it is mono, stereo, 5.1, or whatever).
                In other words, LPCMFrames/audioSampleRate is duration in seconds.
        AudioPacket = For compressed audio, an AudioPacket is the natural compressed access
                unit of that format.  For uncompressed audio, an AudioPacket is simply one
                LPCMFrame.
}
{ version 2 of the SoundDescription record}
type
	SoundDescriptionV2 = record
		descSize: SInt32;               { total size of SoundDescription including extra data }
		dataFormat: OSType;             { 'lpcm' for uncompressed, compression type otherwise (eg. 'ima4') }
		resvd1: SInt32;                 { reserved for apple use. Must be set to zero }
		resvd2: SInt16;                 { reserved for apple use. Must be set to zero }
		dataRefIndex: SInt16;
		version: SInt16;                { which version is this data (2 in this case) }
		revlevel: SInt16;               { what version of that codec did this }
		vendor: SInt32;                 { whose  codec compressed this data }

		always3: SInt16;                { Reserved, must be set to 3 }
		always16: SInt16;               { Reserved, must be set to 16 (0x0010) }
		alwaysMinus2: SInt16;           { Reserved, must be set to -2 (0xFFFE) }
		always0: SInt16;                { Reserved, must be set to 0 }
		always65536: UInt32;            { Reserved, must be set to 65536 (0x00010000) }

		sizeOfStructOnly: UInt32;       { must be set to sizeof(SoundDescriptionV2), ie. offset to extensions }
		audioSampleRate: Float64;        { audio frames per second, eg. 44100.0 }
		numAudioChannels: UInt32;       { any channel assignment info will be in an extension }

		always7F000000: SInt32;         { Reserved, must be set to 0x7F000000 }
		constBitsPerChannel: UInt32;    { only set if constant (and only for uncompressed audio) }

		formatSpecificFlags: UInt32;    { eg. see LPCM flag definitions in CoreAudioTypes.h }
		constBytesPerAudioPacket: UInt32; { only set if constant }
		constLPCMFramesPerAudioPacket: UInt32; { only set if constant }

                                              { additional atom based extensions ([long size, long type, some data], repeat)}
	end;
	SoundDescriptionV2Ptr = ^SoundDescriptionV2;
type
	SoundDescriptionV2Handle = ^SoundDescriptionV2Ptr;



const
	kTx3gSampleType = FourCharCode('tx3g');
	kTx3gFontTableAtomType = FourCharCode('ftab');
	kTx3gBlinkAtomType = FourCharCode('blnk');

type
	Tx3gRGBAColor = record
		red: UInt8;
		green: UInt8;
		blue: UInt8;
		transparency: UInt8;
	end;
type
	Tx3gStyleRecordPtr = ^Tx3gStyleRecord;
	Tx3gStyleRecord = record
		startChar: UInt16;
		endChar: UInt16;
		fontID: UInt16;
		fontFace: UInt8;
		fontSize: UInt8;
		fontColor: Tx3gRGBAColor;
	end;
type
	Tx3gStylePtr = Tx3gStyleRecordPtr;
	Tx3gStyleHandle = ^Tx3gStylePtr;
	Tx3gStyleTableRecordPtr = ^Tx3gStyleTableRecord;
	Tx3gStyleTableRecord = record
		count: UInt16;
    table: array [0..0] of Tx3gStyleRecord;
	end;
type
	Tx3gStyleTablePtr = Tx3gStyleTableRecordPtr;
	Tx3gStyleTableHandle = ^Tx3gStyleTablePtr;
	Tx3gFontRecord = record
		fontID: UInt16;
		nameLength: UInt8;
    name: array[0..0] of SInt8;
	end;
	Tx3gFontRecordPtr = ^Tx3gFontRecord;
type
	Tx3gFontTableRecordPtr = ^Tx3gFontTableRecord;
	Tx3gFontTableRecord = record
		entryCount: UInt16;
    fontEntries: array[0..0] of Tx3gFontRecord;
	end;
type
	Tx3gFontTablePtr = Tx3gFontTableRecordPtr;
	Tx3gFontTableHandle = ^Tx3gFontTablePtr;
	Tx3gDescription = record
		descSize: SInt32;
		dataFormat: SInt32;
		resvd1: SInt32;
		resvd2: SInt16;
		dataRefIndex: SInt16;

		displayFlags: UInt32;
		horizontalJustification: AnsiChar;
		verticalJustification: AnsiChar;
		backgroundColor: Tx3gRGBAColor;
		defaultTextBox: Rect;
		defaultStyle: Tx3gStyleRecord;
	end;
	Tx3gDescriptionPtr = ^Tx3gDescription;
type
	Tx3gDescriptionHandle = ^Tx3gDescriptionPtr;


{ QuickDraw legacy }
type
	QTRGBColor = record
		red: UInt16;                    { magnitude of red component}
		green: UInt16;                  { magnitude of green component}
		blue: UInt16;                   { magnitude of blue component}
	end;


type
	TextDescription = record
		descSize: SInt32;               { Total size of TextDescription}
		dataFormat: SInt32;             { 'text'}

		resvd1: SInt32;
		resvd2: SInt16;
		dataRefIndex: SInt16;

		displayFlags: SInt32;           { see enum below for flag values}

		textJustification: SInt32;      { Can be: teCenter,teFlush -Default,-Right,-Left}




		bgColor: QTRGBColor;                { Background color}



		defaultTextBox: Rect;         { Location to place the text within the track bounds}
		defaultStyle: ScrpSTElement;           { Default style (struct defined in TextEdit.h)}
    defaultFontName: array[0..0] of SInt8;     { Font Name (pascal string - struct extended to fit) }
	end;
	TextDescriptionPtr = ^TextDescription;
type
	TextDescriptionHandle = ^TextDescriptionPtr;


{ Add/GetMediaSample flags }
const
	mediaSampleNotSync = 1 shl 0; { sample is not a sync sample (eg. is frame differenced }
	mediaSampleShadowSync = 1 shl 1; { sample is a shadow sync }
	mediaSampleDroppable = 1 shl 27; { sample is not required to be decoded for later samples to be decoded properly }
	mediaSamplePartialSync = 1 shl 16; { sample is a partial sync (e.g., I frame after open GOP) }
	mediaSampleHasRedundantCoding = 1 shl 24; { sample is known to contain redundant coding }
	mediaSampleHasNoRedundantCoding = 1 shl 25; { sample is known not to contain redundant coding }
	mediaSampleIsDependedOnByOthers = 1 shl 26; { one or more other samples depend upon the decode of this sample }
	mediaSampleIsNotDependedOnByOthers = 1 shl 27; { synonym for mediaSampleDroppable }
	mediaSampleDependsOnOthers = 1 shl 28; { sample's decode depends upon decode of other samples }
	mediaSampleDoesNotDependOnOthers = 1 shl 29; { sample's decode does not depend upon decode of other samples }
	mediaSampleEarlierDisplayTimesAllowed = 1 shl 30; { samples later in decode order may have earlier display times }



{$endc} {TARGET_OS_MAC}
{$ifc not defined MACOSALLINCLUDE or not MACOSALLINCLUDE}

end.
{$endc} {not MACOSALLINCLUDE}
