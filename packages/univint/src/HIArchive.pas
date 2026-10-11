{
     File:       HIToolbox/HIArchive.h

     Contains:   HIArchive Interfaces.

     Version:    HIToolbox-624~3

     Copyright:  © 2004-2008 by Apple Inc., all rights reserved.

     Bugs?:      For bug reports, consult the following page on
                 the World Wide Web:

                     http://bugs.freepascal.org

}
{       Pascal Translation:  Peter N Lewis, <peter@stairways.com.au>, August 2005 }
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
unit HIArchive;
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
uses MacOsApi.MacTypes,MacOsApi.CFBase,MacOsApi.CFData,MacOsApi.CFNumber,MacOsApi.HIObject;
{$ELSE FPC_DOTTEDUNITS}
uses MacTypes,CFBase,CFData,CFNumber,HIObject;
{$ENDIF FPC_DOTTEDUNITS}
{$endc} {not MACOSALLINCLUDE}


{$ifc TARGET_OS_MAC}

{$ALIGN POWER}


{
 *  HIArchive
 *
 *  Discussion:
 *    HIArchive provides a standard, extensible mechanism to flatten
 *    objects for storage in memory or on disk for later retrieval or
 *    transfer to another application. The archive is encoded using the
 *    binary property list format. The binary plist can be converted to
 *    text XML with /usr/bin/plutil for development purposes. Details
 *    on how to create an object that supports the HIArchive protocol
 *    are provided in HIToolbox/HIObject.h.
 *
 *    When writing data out to an archive, the client must first use
 *    HIArchiveCreateForEncoding to generate the archive into which the
 *    data will be encoded. From there, data may be added to the
 *    archive by calling HIArchiveEncodeBoolean, HIArchiveEncodeNumber,
 *    and HIArchiveEncodeCFType. If HIArchiveEncodeCFType is being
 *    called on one of your custom HIObjects, HIToolbox will send it
 *    the kEventHIObjectEncode event (see HIObject.h). In order to
 *    receive this event your HIObject must first have set its
 *    archiving-ignored value to false via HIObjectSetArchivingIgnored.
 *    This lets HIToolbox know your object supports archiving. The
 *    kEventParamHIArchive parameter contains the HIArchiveRef into
 *    which it should encode all of its relevant state information. All
 *    information added to the archive is written with a key. This key
 *    is used later during the unarchiving process to pull the encoded
 *    data from the archive. System supplied HIObjects namespace their
 *    keys with an HI prefix. Subclasses of system supplied HIObjects
 *    should only use this namespace if explicitly overriding a value
 *    written to the archive by the superclass. Take care to mantain
 *    the same data format when overriding the default to avoid
 *    incompatibilities. When your archiving process is complete,
 *    HIArchiveCopyEncodedData will compress the data into the archive
 *    and return it in a CFDataRef. This CFDataRef can be sent to
 *    another application or written out to disk for later retrieval.
 *    Once the encoded data is compressed, no more data may be added to
 *    the archive. At this point, the HIArchiveRef must be released via
 *    CFRelease.
 *
 *    When retrieving data from an archive, the client must first use
 *    HIArchiveCreateForDecoding to create an archive reference capable
 *    of decoding the data from the provided CFDataRef. Given the
 *    HIArchiveRef, data may be pulled from the archive via
 *    HIArchiveDecodeBoolean, HIArchiveDecodeNumber, and
 *    HIArchiveCopyDecodedCFType. If HIArchiveCopyDecodedCFType is
 *    called on one of your custom HIObjects, HIToolbox will send it
 *    the kEventHIObjectInitialize event (see HIOject.h). The
 *    kEventParamHIArchive parameter contains the HIArchiveRef from
 *    which it should decode all of its relevant state information.
 *    Because these data values were written by key, they can be read
 *    in any order regardless of how they were written. This also means
 *    new keyed values can be added without breaking existing decoding
 *    routines. Once all data has been read from the archive, it may
 *    simply be released via CFRelease.
 *
 *    For those clients who wish to provide HIArchive editing features
 *    there are a few tricks necessary to achieve the desired behavior.
 *    A generic HIArchive editor will likely be used by clients to edit
 *    objects for which it has no direct knowledge (or which have not
 *    yet been designed). For instance, it may provide users with the
 *    ability to edit custom HIViews, including generic functionality
 *    to set the view's class identifier, title, frame, etc. In this
 *    case, it is necessary to instantiate the superclass
 *    ("com.apple.hiview") of the custom view object because the custom
 *    view class itself hasn't been registered within the editor.
 *
 *
 *    After the user has completed editing the object and desires to
 *    write out the archive, the editor must set the custom archive
 *    data to the object with HIObjectSetCustomArchiveData as a
 *    CFDictionary. Standard keys for initialization parameter types,
 *    names and values, class and superclass identifiers and CDEF
 *    procID are provided in HIToolbox/HIObject.h. Of particular
 *    importance are the object's class and superclass identifier.
 *    HIArchive uses these values to instantiate the proper object when
 *    loading the archive within the client's application. The
 *    parameter types, names and values are then automatically passed
 *    to the client object through its initialization event.
 *
 *    At this point, the object can simply be written into the archive
 *    with HIArchiveCreateForEncoding and HIArchiveEncodeCFType.
 *    HIArchive will handle writing the appropriate classID based on
 *    the custom data that was assigned earlier.
 *
 *    Generic HIArchive editing applications will also need to handle
 *    loading client archives. In this case, the archive is decoded in
 *    editing mode by passing the
 *    kHIArchiveDecodeSuperclassForUnregisteredObjects proxy bit in
 *    HIArchiveCreateForDecoding. When objects not registered in the
 *    current application are decoded, HIArchive will notice this and
 *    look into the custom data for the object's superclass identifier,
 *    instantiate an object of that type instead and attach the custom
 *    data to the newly created object. The editor can then look at the
 *    attached custom data with HIObjectCopyCustomArchiveData and
 *    provide it in the UI for the user to edit.
 }
type
	HIArchiveRef = ^OpaqueHIArchiveRef; { an opaque type }
	OpaqueHIArchiveRef = record end;

{
 *  Discussion:
 *    HIArchive errors
 }
const
{
   * The archive was created specifically for encoding or decoding but
   * passed into a non-corresponding routine.
   }
	hiArchiveTypeMismatchErr = -6780;

  {
   * The keyed value requested does not exist in the archive.
   }
	hiArchiveKeyNotAvailableErr = -6781;

  {
   * HIArchiveCopyEncodedData has been called and no more data may be
   * encoded.
   }
	hiArchiveEncodingCompleteErr = -6782;

  {
   * The HIObject does not support the archiving protocol.
   }
	hiArchiveHIObjectIgnoresArchivingErr = -6783;


{
 *  Discussion:
 *    HIArchiveCreateForDecoding options
 }
const
{
   * kDecodeSuperclassForUnregisteredObjects is passed to
   * HIArchiveCreateForDecoding indicating that if an HIObject's class
   * has not been registered before it is pulled from the archive,
   * HIArchiveCopyDecodedCFType will automatically instantiate the
   * unarchived object as its superclass if it exists. For instance, a
   * custom HIView of class "com.myco.customview" being unarchived will
   * be instantiated as class "com.apple.hiview" if your app has not
   * yet registered "com.myco.customview". This is useful for archive
   * editors that do not implement all objects contained in a client
   * archive. Note that only data written to the archive by the
   * superclass will be decoded. All data unique to the unregistered
   * subclass will be ignored. This option also signals the HIObject to
   * load its custom archive data so it can be accessed via
   * HIObjectCopyCustomArchiveData. HIArchive is unable to instantiate
   * unregistered objects whose superclasses are also unregistered.
   }
	kHIArchiveDecodeSuperclassForUnregisteredObjects = 1 shl 0;

  {
   * Indicates that an archive is being decoded by an archive editor.
   * This information is passed to the object being decoded via the
   * kEventParamDecodingForEditor parameter in the
   * kEventHIObjectInitialize and kEventHIObjectCreatedFromArchive
   * event. This option may be used in Mac OS X 10.5 and later.
   }
	kHIArchiveDecodingForEditor = 1 shl 1;


{$endc} {TARGET_OS_MAC}
{$ifc not defined MACOSALLINCLUDE or not MACOSALLINCLUDE}

end.
{$endc} {not MACOSALLINCLUDE}
