{
     File:       QuickTime/ImageCompression.h

     Contains:   QuickTime Image Compression Interfaces.

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
unit ImageCompression;
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
uses MacOsApi.MacTypes,MacOsApi.Components,MacOsApi.CGLTypes,MacOsApi.ColorSyncDeprecated,MacOsApi.CVBase,MacOsApi.CVImageBuffer,MacOsApi.CVPixelBuffer,MacOsApi.CVPixelBufferPool,MacOsApi.Files,MacOsApi.Dialogs,MacOsApi.OSUtils,MacOsApi.QuickdrawTypes,MacOsApi.QDOffscreen,MacOsApi.CFBase,MacOsApi.CFData,MacOsApi.CFDictionary,MacOsApi.CGContext,MacOsApi.CGImage;
{$ELSE FPC_DOTTEDUNITS}
uses MacTypes,Components,CGLTypes,ColorSyncDeprecated,CVBase,CVImageBuffer,CVPixelBuffer,CVPixelBufferPool,Files,Dialogs,OSUtils,QuickdrawTypes,QDOffscreen,CFBase,CFData,CFDictionary,CGContext,CGImage;
{$ENDIF FPC_DOTTEDUNITS}
{$endc} {not MACOSALLINCLUDE}


{$ifc TARGET_OS_MAC}

{$ALIGN MAC68K}


type
	MatrixRecord = record
		matrix: array [0..2,0..2] of Fixed;
	end;
	MatrixRecordPtr = ^MatrixRecord;
const
	kRawCodecType = FourCharCode('raw ');
	kCinepakCodecType = FourCharCode('cvid');
	kGraphicsCodecType = FourCharCode('smc ');
	kAnimationCodecType = FourCharCode('rle ');
	kVideoCodecType = FourCharCode('rpza');
	kComponentVideoCodecType = FourCharCode('yuv2');
	kJPEGCodecType = FourCharCode('jpeg');
	kMotionJPEGACodecType = FourCharCode('mjpa');
	kMotionJPEGBCodecType = FourCharCode('mjpb');
	kSGICodecType = FourCharCode('.SGI');
	kPlanarRGBCodecType = FourCharCode('8BPS');
	kMacPaintCodecType = FourCharCode('PNTG');
	kGIFCodecType = FourCharCode('gif ');
	kPhotoCDCodecType = FourCharCode('kpcd');
	kQuickDrawGXCodecType = FourCharCode('qdgx');
	kAVRJPEGCodecType = FourCharCode('avr ');
	kOpenDMLJPEGCodecType = FourCharCode('dmb1');
	kBMPCodecType = FourCharCode('WRLE');
	kWindowsRawCodecType = FourCharCode('WRAW');
	kVectorCodecType = FourCharCode('path');
	kQuickDrawCodecType = FourCharCode('qdrw');
	kWaterRippleCodecType = FourCharCode('ripl');
	kFireCodecType = FourCharCode('fire');
	kCloudCodecType = FourCharCode('clou');
	kH261CodecType = FourCharCode('h261');
	kH263CodecType = FourCharCode('h263');
	kDVCNTSCCodecType = FourCharCode('dvc '); { DV - NTSC and DVCPRO NTSC (available in QuickTime 6.0 or later)}
                                        { NOTE: kDVCProNTSCCodecType is deprecated.  }
                                        { Use kDVCNTSCCodecType instead -- as far as the codecs are concerned, }
                                        { the two data formats are identical.}
	kDVCPALCodecType = FourCharCode('dvcp');
	kDVCProPALCodecType = FourCharCode('dvpp'); { available in QuickTime 6.0 or later}
	kDVCPro50NTSCCodecType = FourCharCode('dv5n');
	kDVCPro50PALCodecType = FourCharCode('dv5p');
	kDVCPROHD720p60CodecType = FourCharCode('dvhp');
	kDVCPROHD720p50CodecType = FourCharCode('dvhq');
	kDVCPROHD720pCodecType = kDVCPROHD720p60CodecType;
	kDVCPro100NTSCCodecType = FourCharCode('dv1n');
	kDVCPro100PALCodecType = FourCharCode('dv1p');
	kDVCPROHD1080i60CodecType = FourCharCode('dvh6');
	kDVCPROHD1080i50CodecType = FourCharCode('dvh5');
	kDVCPROHD1080p30CodecType = FourCharCode('dvh3');
	kDVCPROHD1080p25CodecType = FourCharCode('dvh2');
	kBaseCodecType = FourCharCode('base');
	kFLCCodecType = FourCharCode('flic');
	kTargaCodecType = FourCharCode('tga ');
	kPNGCodecType = FourCharCode('png ');
	kTIFFCodecType = FourCharCode('tiff'); { NOTE: despite what might seem obvious from the two constants}
                                        { below and their names, they really are correct. 'yuvu' really }
                                        { does mean signed, and 'yuvs' really does mean unsigned. Really. }
	kComponentVideoSigned = FourCharCode('yuvu');
	kComponentVideoUnsigned = FourCharCode('yuvs');
	kCMYKCodecType = FourCharCode('cmyk');
	kMicrosoftVideo1CodecType = FourCharCode('msvc');
	kSorensonCodecType = FourCharCode('SVQ1');
	kSorenson3CodecType = FourCharCode('SVQ3'); { available in QuickTime 5 and later}
	kIndeo4CodecType = FourCharCode('IV41');
	kMPEG4VisualCodecType = FourCharCode('mp4v');
	k64ARGBCodecType = FourCharCode('b64a');
	k48RGBCodecType = FourCharCode('b48r');
	k32AlphaGrayCodecType = FourCharCode('b32a');
	k16GrayCodecType = FourCharCode('b16g');
	kMpegYUV420CodecType = FourCharCode('myuv');
	kYUV420CodecType = FourCharCode('y420');
	kSorensonYUV9CodecType = FourCharCode('syv9');
	k422YpCbCr8CodecType = FourCharCode('2vuy'); { Component Y'CbCr 8-bit 4:2:2  }
	k444YpCbCr8CodecType = FourCharCode('v308'); { Component Y'CbCr 8-bit 4:4:4  }
	k4444YpCbCrA8CodecType = FourCharCode('v408'); { Component Y'CbCrA 8-bit 4:4:4:4 }
	k422YpCbCr16CodecType = FourCharCode('v216'); { Component Y'CbCr 10,12,14,16-bit 4:2:2}
	k422YpCbCr10CodecType = FourCharCode('v210'); { Component Y'CbCr 10-bit 4:2:2 }
	k444YpCbCr10CodecType = FourCharCode('v410'); { Component Y'CbCr 10-bit 4:4:4 }
	k4444YpCbCrA8RCodecType = FourCharCode('r408'); { Component Y'CbCrA 8-bit 4:4:4:4, rendering format. full range alpha, zero biased yuv}
	kJPEG2000CodecType = FourCharCode('mjp2');
	kPixletCodecType = FourCharCode('pxlt');
	kH264CodecType = FourCharCode('avc1');



type
	CodecType = OSType;
	CodecType_fix = CodecType; { used as field type when a record declaration contains a CodecType field identifier }
	CodecFlags = UInt16;
	CodecQ = UInt32;


type
	ImageDescription = packed record
		idSize: SInt32;                 { total size of ImageDescription including extra data ( CLUTs and other per sequence data ) }
		cType: CodecType;                  { what kind of codec compressed this data }
		resvd1: SInt32;                 { reserved for Apple use }
		resvd2: SInt16;                 { reserved for Apple use }
		dataRefIndex: SInt16;           { set to zero  }
		version: SInt16;                { which version is this data }
		revisionLevel: SInt16;          { what version of that codec did this }
		vendor: SInt32;                 { whose  codec compressed this data }
		temporalQuality: CodecQ;        { what was the temporal quality factor  }
		spatialQuality: CodecQ;         { what was the spatial quality factor }
		width: SInt16;                  { how many pixels wide is this data }
		height: SInt16;                 { how many pixels high is this data }
		hRes: Fixed;                   { horizontal resolution }
		vRes: Fixed;                   { vertical resolution }
		dataSize: SInt32;               { if known, the size of data for this image descriptor }
		frameCount: SInt16;             { number of frames this description applies to }
		name: Str31;                   { name of codec ( in case not installed )  }
		depth: SInt16;                  { what depth is this data (1-32) or ( 33-40 grayscale ) }
		clutID: SInt16;                 { clut id or if 0 clut follows  or -1 if no clut }
	end;
	ImageDescriptionPtr = ^ImageDescription;
type
	ImageDescriptionHandle = ^ImageDescriptionPtr;


{ See Movies.h for the flags themselves. }
type
	MediaSampleFlags = UInt32;


{$endc} {TARGET_OS_MAC}
{$ifc not defined MACOSALLINCLUDE or not MACOSALLINCLUDE}

end.
{$endc} {not MACOSALLINCLUDE}
