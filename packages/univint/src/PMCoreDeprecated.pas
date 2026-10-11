{
     File:       PrintCore/PMCoreDeprecated.h

     Contains:   Deprecated Carbon Printing Manager Interfaces.

     Copyright (c) 1998-2006,2008 by Apple Inc. All Rights Reserved.

     Bugs?:      For bug reports, consult the following page on
                 the World Wide Web:

                     http://bugs.freepascal.org

}
{  Pascal Translation:  Jonas Maebe, <jonas@freepascal.org>, October 2009 }
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
unit PMCoreDeprecated;
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
uses MacOsApi.MacTypes,MacOsApi.Files,MacOsApi.QuickdrawTypes,MacOsApi.PMDefinitions,MacOsApi.ColorSyncDeprecated,MacOsApi.CFBase,MacOsApi.CFArray,MacOsApi.CFData;
{$ELSE FPC_DOTTEDUNITS}
uses MacTypes,Files,QuickdrawTypes,PMDefinitions,ColorSyncDeprecated,CFBase,CFArray,CFData;
{$ENDIF FPC_DOTTEDUNITS}
{$endc} {not MACOSALLINCLUDE}


{$ifc TARGET_OS_MAC}

{$ALIGN POWER}


{
 *  PMFlattenPageFormatToCFData() *** DEPRECATED ***
 *
 *  Discussion:
 *    Use PMPageFormatCreateDataRepresentation instead.
 *
 *  Summary:
 *    Returns a flattened representation of the page format object in a CFDataRef.
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in ApplicationServices.framework but deprecated in 10.5
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
function PMFlattenPageFormatToCFData( pageFormat: PMPageFormat; var flatFormat: CFDataRef ): OSStatus; external name '_PMFlattenPageFormatToCFData';
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  PMFlattenPageFormatToURL() *** DEPRECATED ***
 *
 *  Discussion:
 *    Instead use PMPageFormatCreateDataRepresentation and write the resulting data to your destination.
 *
 *  Summary:
 *    Writes a flattened representation of the print settings to the
 *    URL specified by flattenFileURL.
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in ApplicationServices.framework but deprecated in 10.5
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
function PMFlattenPageFormatToURL( pageFormat: PMPageFormat; flattenFileURL: CFURLRef ): OSStatus; external name '_PMFlattenPageFormatToURL';
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  PMUnflattenPageFormatWithCFData()	*** DEPRECATED ***
 *
 *  Discussion:
 *    Use PMPageFormatCreateWithDataRepresentation instead.
 *
 *  Summary:
 *    Returns a page format object given a CFDataRef to a previously
 *    flattened page format.
 *
 *  Parameters:
 *
 *    flattenCFData:
 *      A CFDataRef containing a flattened print settings.
 *
 *    pageFormat:
 *      On return, a newly created page format object create with the
 *      data contained in 'flattenCFData'. The printing framework will
 *      create the object. The app is responsible for disposing of it.
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in ApplicationServices.framework but deprecated in 10.5
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
function PMUnflattenPageFormatWithCFData( flattenCFData: CFDataRef; var pageFormat: PMPageFormat ): OSStatus; external name '_PMUnflattenPageFormatWithCFData';
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  PMUnflattenPageFormatWithURL()	*** DEPRECATED ***
 *
 *  Discussion:
 *    Instead read the data into a CFData object and use PMPageFormatCreateWithDataRepresentation.
 *
 *  Summary:
 *    Returns a page format object given a CFURLRef referencing a file
 *    containing a previously flattened page format.
 *
 *  Parameters:
 *
 *    flattenFileURL:
 *      A CFURLRef referencing a file that contains a flattened page
 *      format.
 *
 *    pageFormat:
 *      On return, a newly created page format object created from the
 *      flattened page format data specified by 'flattenFileURL'. The
 *      caller is responsible for releasing the page format created.
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in ApplicationServices.framework but deprecated in 10.5
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
function PMUnflattenPageFormatWithURL( flattenFileURL: CFURLRef; var pageFormat: PMPageFormat ): OSStatus; external name '_PMUnflattenPageFormatWithURL';
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  PMFlattenPrintSettingsToCFData()	*** DEPRECATED ***
 *
 *  Discussion:
 *    Use PMPrintSettingsCreateDataRepresentation instead.
 *
 *  Summary:
 *    Returns a flattened print settings object as a CFDataRef.
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in ApplicationServices.framework but deprecated in 10.5
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
function PMFlattenPrintSettingsToCFData( printSettings: PMPrintSettings; var flatSetting: CFDataRef ): OSStatus; external name '_PMFlattenPrintSettingsToCFData';
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  PMFlattenPrintSettingsToURL()	*** DEPRECATED ***
 *
 *  Discussion:
 *    Instead use PMPrintSettingsCreateDataRepresentation and write the resulting data to your destination.
 *
 *  Summary:
 *    Writes a flattened representation of the print settings to the
 *    URL specified by flattenFileURL.
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in ApplicationServices.framework but deprecated in 10.5
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
function PMFlattenPrintSettingsToURL( printSettings: PMPrintSettings; flattenFileURL: CFURLRef ): OSStatus; external name '_PMFlattenPrintSettingsToURL';
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  PMUnflattenPrintSettingsWithCFData()	*** DEPRECATED ***
 *
 *  Discussion:
 *    Use PMPrintSettingsCreateWithDataRepresentation instead.
 *
 *  Summary:
 *    Returns a print settings object given a CFDataRef to a previously
 *    flatten print settings.
 *
 *  Parameters:
 *
 *    flattenCFData:
 *      A CFDataRef containing a flatten print settings.
 *
 *    printSettings:
 *      On return, a newly created print settings object create with
 *      the data contained in 'flattenCFData'. The printing framework
 *      will create the object. The app is responsible for disposing of
 *      it.
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in ApplicationServices.framework but deprecated in 10.5
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
function PMUnflattenPrintSettingsWithCFData( flattenCFData: CFDataRef; var printSettings: PMPrintSettings ): OSStatus; external name '_PMUnflattenPrintSettingsWithCFData';
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  PMUnflattenPrintSettingsWithURL()	*** DEPRECATED ***
 *
 *  Discussion:
 *    Instead read the data into a CFData object and use PMPrintSettingsCreateWithDataRepresentation.
 *
 *  Summary:
 *    Returns a print settings object given a CFURLRef referencing a
 *    file containing a previously flattened print settings.
 *
 *  Parameters:
 *
 *    flattenFileURL:
 *      A CFURLRef referencing a file that contains a flattened print
 *      settings.
 *
 *    printSettings:
 *      On return, a newly created print settings object created with
 *      the data specified by 'flattenFileURL'. The caller is
 *      responsible for releasing the print settings created.
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in ApplicationServices.framework but deprecated in 10.5
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
function PMUnflattenPrintSettingsWithURL( flattenFileURL: CFURLRef; var printSettings: PMPrintSettings ): OSStatus; external name '_PMUnflattenPrintSettingsWithURL';
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  PMGetPrintSettingsExtendedData()	*** DEPRECATED ***
 *
 *  Discussion:
 *    Use PMPrintSettingsGetValue instead.
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   not available
 }
function PMGetPrintSettingsExtendedData( printSettings: PMPrintSettings; dataID: OSType; var size: UInt32; extendedData: UnivPtr ): OSStatus; external name '_PMGetPrintSettingsExtendedData';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_6 *)

{
 *  PMSetPrintSettingsExtendedData()	*** DEPRECATED ***
 *
 *  Discussion:
 *    Use PMPrintSettingsSetValue instead.
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in ApplicationServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   not available
 }
function PMSetPrintSettingsExtendedData( printSettings: PMPrintSettings; dataID: OSType; size: UInt32; extendedData: UnivPtr ): OSStatus; external name '_PMSetPrintSettingsExtendedData';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_6 *)

{
 *  PMPaperGetName()
 *
 *  Summary:
 *    Returns the name for a given paper.
 *
 *  Discussion:
 *		Use PMPaperCreateLocalizedName instead
 *
 *  Parameters:
 *
 *    paper:
 *      Obtain the name for this paper.
 *
 *    paperName:
 *      If successful noErr is returned and *paperName is set to the
 *      name of the paper. The returned paper name is that appropriate
 *      to display to a user.
 *
 *  Availability:
 *    Mac OS X:         in version 10.3 and later in ApplicationServices.framework but deprecated in 10.7
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.3 and later
 *    Non-Carbon CFM:   not available
 *
 *  Compatibility:
 *  	Not appropriate for CUPS filters, drivers, and backends.
 *
 }
function PMPaperGetName( paper: PMPaper; var paperName: CFStringRef ): OSStatus; external name '_PMPaperGetName';
(* AVAILABLE_MAC_OS_X_VERSION_10_3_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_7 *)

{
 *  PMPrinterCreatePaperInfoListForMenu()
 *
 *  Summary:
 *    Hand back a list of paper info items that can be used to create a
 *    paper size menu. Each item is a dictionary describing the menu item.
 *
 *  Parameters:
 *
 *    printer:
 *      The printer whose page size list should be enumerated. To get
 *      the session's current printer, see PMSessionGetCurrentPrinter().
 *
 *    pageFormat:
 *      The page format object that contains the current paper size.
 *
 *    paperInfoList:
 *      If this function is successful then noErr will be returned and
 *      *'paperInfoList' will be set to a newly created CFArray. Each
 *      element in the array will be a CFDictionary describing the
 *      menu item that needs to be added for the paper size menu. If this
 *      function fails then a non-zero error code will be returned and
 *      *'paperInfoList' will be set to NULL.
 *
 }
function PMPrinterCreatePaperInfoListForMenu( printer: PMPrinter; pageFormat: PMPageFormat; paperInfoList: CFArrayRefPtr ): OSStatus; external name '_PMPrinterCreatePaperInfoListForMenu';
(* AVAILABLE_MAC_OS_X_VERSION_10_3_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_7 *)


{$endc} {TARGET_OS_MAC}
{$ifc not defined MACOSALLINCLUDE or not MACOSALLINCLUDE}

end.
{$endc} {not MACOSALLINCLUDE}
