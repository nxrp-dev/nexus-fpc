{
     File:       NSLCore/NSLCore.h

     Contains:   Interface to API for using the NSL Manager

     Version:    NSLCore-145~102

     Copyright:  © 2000-2008 by Apple Computer, Inc., all rights reserved

     Bugs?:      For bug reports, consult the following page on
                 the World Wide Web:

                     http://bugs.freepascal.org

}
{      Pascal Translation Updated:  Jonas Maebe, <jonas@freepascal.org>, October 2009 }
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
unit NSLCore;
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
uses MacOsApi.MacTypes,MacOsApi.MacErrors,MacOsApi.CodeFragments,MacOsApi.Files,MacOsApi.Threads;
{$ELSE FPC_DOTTEDUNITS}
uses MacTypes,MacErrors,CodeFragments,Files,Threads;
{$ENDIF FPC_DOTTEDUNITS}
{$endc} {not MACOSALLINCLUDE}


{$ifc TARGET_OS_MAC}

{$ALIGN MAC68K}


const
	kNSLMinSystemVersion = $0900; { equivalent to 9.0}
	kNSLMinOTVersion = $0130; { equivalent to 1.3}

const
	kNSLDefaultListSize = 256;   { default list size for service and protocol lists}

const
	kNSLURLDelimiter = 44;   { delimits URL's within memory buffers}


const
	kNSLNoContext = 0;     { the default context for NSLError structs}

type
	NSLError = record
		theErr: OSStatus;
		theContext: UInt32;
	end;
	NSLErrorPtr = ^NSLError;
const
{ Constants to use with NSLPrepareRequest}
                                        { kNSLDuplicateSearchInProgress is not strictly an error.  The client is free to ignore}
                                        { this result, and nothing bad will happen if it does.  It is}
                                        { informational only.}
	kNSLDuplicateSearchInProgress = 100;
	kNSLUserCanceled = userCanceledErr; { User hit cancel from the NSLStandardGetURL dialog }
                                        { Invalid enumeratorRef  }
	kNSLInvalidEnumeratorRef = 0;     { this is not an error; it is the equiv to a NULL ptr}

type
	NSLSearchState = UInt16;
const
{ State codes for notifiers.}
	kNSLSearchStateBufferFull = 1;
	kNSLSearchStateOnGoing = 2;
	kNSLSearchStateComplete = 3;
	kNSLSearchStateStalled = 4;
	kNSLWaitingForContinue = 5;

type
	NSLEventCode = UInt32;
const
{ Event codes}
	kNSLServicesLookupDataEvent = 6;
	kNSLNeighborhoodLookupDataEvent = 7;
	kNSLNewDataEvent = 8;
	kNSLContinueLookupEvent = 9;


type
	NSLClientRef = UInt32;
	NSLRequestRef = UInt32;
	NSLOneBasedIndex = UInt32;
	NSLPath = CStringPtr;
	NSLServiceType = CStringPtr;
	NSLServicesList = Handle;
	NSLNeighborhood = UInt8Ptr;
{
   cstring which is a comma delimited list of protocols which can be used to
   create a NSLProtocolList internally
}

{ the async information block for client<->manager interaction}
type
	NSLClientAsyncInfo = record
		clientContextPtr: UnivPtr;       { set by the client for its own use}
		mgrContextPtr: UnivPtr;          { set by NSL mgr; ptr to request object ptr}
		resultBuffer: CStringPtr;
		bufferLen: SIGNEDLONG;
		maxBufferSize: SIGNEDLONG;
		startTime: UInt32;              { when the search starts, to use with maxSearchTime to determine time-out condition}
		intStartTime: UInt32;           { used with alertInterval}
		maxSearchTime: UInt32;          { total time for search, in ticks (0 == no time limit)}
		alertInterval: UInt32;          { call client's notifier or return, every this many ticks ( 0 == don't use this param)}
		totalItems: UInt32;             { total number of tuples currently in buffer}
		alertThreshold: UInt32;         { call client's notifier or return, every this many items found ( 0 == don't use this param)}
		searchState: NSLSearchState;
		searchResult: NSLError;
		searchDataType: NSLEventCode;         { this is a data type code which allows the client's asyncNotifier to properly}
                                              { handle the data in resultBuffer.}
	end;
	NSLClientAsyncInfoPtr = ^NSLClientAsyncInfo;

{ the async information block plugin<->manager interaction}
type
	NSLPluginAsyncInfo = record
		mgrContextPtr: UnivPtr;          { set by NSL mgr; ptr to request object ptr}
		pluginContextPtr: UnivPtr;       { set/used by individual plugins}
		pluginPtr: UnivPtr;              { ptr to the plugin object waiting for continue lookup call}
		resultBuffer: CStringPtr;           { set by plugin to point at data}
		bufferLen: SIGNEDLONG;
		maxBufferSize: SIGNEDLONG;
		maxSearchTime: UInt32;          { total time for search, in ticks (0 == no time limit)}
		reserved1: UInt32;
		reserved2: UInt32;
		reserved3: UInt32;
		clientRef: NSLClientRef;
		requestRef: NSLRequestRef;
		searchState: NSLSearchState;
		searchResult: OSStatus;
	end;
	NSLPluginAsyncInfoPtr = ^NSLPluginAsyncInfo;

{ the manager asynchronous notifier routine.}
type
	NSLMgrNotifyProcPtr = procedure( var thePluginAsyncInfo: NSLPluginAsyncInfo );

{ the client asynchronous notifier routine.}
type
	NSLClientNotifyProcPtr = procedure( var theClientAsyncInfo: NSLClientAsyncInfo );
	NSLMgrNotifyUPP = NSLMgrNotifyProcPtr;
	NSLClientNotifyUPP = NSLClientNotifyProcPtr;
{
 *  NewNSLMgrNotifyUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewNSLMgrNotifyUPP( userRoutine: NSLMgrNotifyProcPtr ): NSLMgrNotifyUPP; external name '_NewNSLMgrNotifyUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  NewNSLClientNotifyUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewNSLClientNotifyUPP( userRoutine: NSLClientNotifyProcPtr ): NSLClientNotifyUPP; external name '_NewNSLClientNotifyUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  DisposeNSLMgrNotifyUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeNSLMgrNotifyUPP( userUPP: NSLMgrNotifyUPP ); external name '_DisposeNSLMgrNotifyUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  DisposeNSLClientNotifyUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeNSLClientNotifyUPP( userUPP: NSLClientNotifyUPP ); external name '_DisposeNSLClientNotifyUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  InvokeNSLMgrNotifyUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure InvokeNSLMgrNotifyUPP( var thePluginAsyncInfo: NSLPluginAsyncInfo; userUPP: NSLMgrNotifyUPP ); external name '_InvokeNSLMgrNotifyUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  InvokeNSLClientNotifyUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure InvokeNSLClientNotifyUPP( var theClientAsyncInfo: NSLClientAsyncInfo; userUPP: NSLClientNotifyUPP ); external name '_InvokeNSLClientNotifyUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)


{
   this struct is a format for dealing with our internal data representation.  Typed data will be contiguous chunk of
   memory, with the first 4 bytes being a data "descriptor".
}
type
	NSLTypedData = record
		dataType: UNSIGNEDLONG;
		lengthOfData: UNSIGNEDLONG;
{  void*                           theData; }
	end;
	NSLTypedDataPtr = ^NSLTypedData;

const
  kNSLDataType = FourCharCode('NSL_');
{
   This is just a header at the beginning of a handle that stores our list of service types.
   Each service type is a pascal string, so each service type starts after the end of the
   previous one.
}
type
	NSLServicesListHeader = record
		numServices: UNSIGNEDLONG;
		logicalLen: UNSIGNEDLONG;             { length of all usable data in handle}
{  Ptr                             firstService; }
	end;
	NSLServicesListHeaderPtr = ^NSLServicesListHeader;

{ some defs for common protocols}

const
	kSLPProtocolType = 'SLP';
const
	kDNSProtocolType = 'DNS';
const
	kLDAPProtocolType = 'LDAP';
const
	kNBPProtocolType = 'NBP';
const
	kNSLDirectoryServiceProtocolType = 'DirService';

{
   general information from a plug-in.  Includes supported protocols, data types and services,
   as well as an info/comment string describing the function of the plug-in in human-readable
   form.  The offsets point to the beginning of each list of data returned, and the protocol
   data offset is the startOfData member of the struct
}
type
	NSLPluginData = record
		reserved1: SIGNEDLONG;
		reserved2: SIGNEDLONG;
		reserved3: SIGNEDLONG;
		supportsRegistration: Boolean;
		isPurgeable: Boolean;
		totalLen: UInt16;               { length of everything, including header}
		dataTypeOffset: UInt16;
		serviceListOffset: UInt16;
		protocolListOffset: UInt16;
		commentStringOffset: UInt16;
{  AnsiChar*                           startOfData; }
                                              { protocol data is first on the list}
	end;
	NSLPluginDataPtr = ^NSLPluginData;

{
  -----------------------------------------------------------------------------
    Finding out if the library is present and getting its version
  -----------------------------------------------------------------------------
}



// #define NSLLibraryPresent()        true


{
  -----------------------------------------------------------------------------
    High level API calls: the following two calls are ALL an application needs
    to register/deregister its service.
    If you use these, you don't need to make any of the other calls to NSLAPI
    (including NSLOpenNavigationAPI)
  -----------------------------------------------------------------------------
}

{ <--- error code from registration }
{ ---> urlToRegister is a null terminated url that has only legal characters defined for URLs.  Use HexEncodeText to encode}
{          portions of the url that have illegal characters }
{ ---> neighborhoodToRegisterIn is an optional parameter for explicitly defining a neighborhood to register in.
            If parameter is NULL, then the plugins will determine where to register the service }

{$ifc OLDROUTINENAMES}
type
	ClientAsyncInfo = NSLClientAsyncInfo;
	PluginAsyncInfo = NSLPluginAsyncInfo;
	TypedData = NSLTypedData;
	PluginData = NSLPluginData;
	ClientAsyncInfoPtr = NSLClientAsyncInfoPtr;
	PluginAsyncInfoPtr = NSLPluginAsyncInfoPtr;
	TypedDataPtr = NSLTypedDataPtr;
	PluginDataPtr = NSLPluginDataPtr;

{$endc} {OLDROUTINENAMES}

{$endc} {TARGET_OS_MAC}
{$ifc not defined MACOSALLINCLUDE or not MACOSALLINCLUDE}

end.
{$endc} {not MACOSALLINCLUDE}
