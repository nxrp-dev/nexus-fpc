{
     File:       HIToolbox/MacApplication.h

     Contains:   Application-level APIs

     Version:    HIToolbox-624~3

     Copyright:  © 2000-2008 by Apple Inc., all rights reserved.

     Bugs?:      For bug reports, consult the following page on
                 the World Wide Web:

                     http://bugs.freepascal.org

}
{       Pascal Translation Updated:  Peter N Lewis, <peter@stairways.com.au>, August 2005 }
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
unit MacApplication;
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
uses MacOsApi.MacTypes,MacOsApi.CGImage,MacOsApi.Menus,MacOsApi.CGContext,MacOsApi.QuickdrawTypes,MacOsApi.HIObject,MacOsApi.TextCommon,MacOsApi.HIGeometry,MacOsApi.CFBase,MacOsApi.CFDictionary,MacOsApi.CGAffineTransforms,MacOsApi.CGGeometry,MacOsApi.CTFont;
{$ELSE FPC_DOTTEDUNITS}
uses MacTypes,CGImage,Menus,CGContext,QuickdrawTypes,HIObject,TextCommon,HIGeometry,CFBase,CFDictionary,CGAffineTransforms,CGGeometry,CTFont;
{$ENDIF FPC_DOTTEDUNITS}
{$endc} {not MACOSALLINCLUDE}


{$ifc TARGET_OS_MAC}

{$ALIGN POWER}


{
 *  kHIToolboxVersionNumber
 *
 *  Discussion:
 *    The current build number of HIToolbox.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.3 and later in Carbon.framework
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   not available
 }
var kHIToolboxVersionNumber: Float32; external name '_kHIToolboxVersionNumber'; (* attribute const *)
(* AVAILABLE_MAC_OS_X_VERSION_10_3_AND_LATER *)

// the HIToolbox version number for various Mac OS X releases
const
	kHIToolboxVersionNumber10_3 = 145.0;
const
	kHIToolboxVersionNumber10_3_2 = 145.35;
const
	kHIToolboxVersionNumber10_3_3 = 145.38;
const
	kHIToolboxVersionNumber10_3_4 = 145.41;
const
	kHIToolboxVersionNumber10_3_5 = 145.43;
const
	kHIToolboxVersionNumber10_3_9 = 145.48;
const
	kHIToolboxVersionNumber10_4 = 219;
const
	kHIToolboxVersionNumber10_4_1 = 219.1;
const
	kHIToolboxVersionNumber10_4_2 = 220;
const
	kHIToolboxVersionNumber10_4_2_SecUpdate = 221;
const
	kHIToolboxVersionNumber10_4_4 = 222;
const
	kHIToolboxVersionNumber10_4_4_Intel = 223;
const
	kHIToolboxVersionNumber10_4_6 = 225;
const
	kHIToolboxVersionNumber10_4_7 = 226;
const
	kHIToolboxVersionNumber10_4_9 = 227;
const
	kHIToolboxVersionNumber10_5 = 343;
const
	kHIToolboxVersionNumber10_5_1 = 343;
const
	kHIToolboxVersionNumber10_5_2 = 352;
const
	kHIToolboxVersionNumber10_5_3 = 352;
const
	kHIToolboxVersionNumber10_5_4 = 352;
const
	kHIToolboxVersionNumber10_5_5 = 352;
const
	kHIToolboxVersionNumber10_5_6 = 353;
const
	kHIToolboxVersionNumber10_5_7 = 353;


{
 *  kHIApplicationClassID
 *
 *  Discussion:
 *    HIObject class ID for the HIApplication object. Available in Mac
 *    OS X 10.3 and later.
 }
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kHIApplicationClassID CFSTRP('com.apple.HIApplication')}
{$endc}

{
 *  Summary:
 *    Controls the presentation of system-provided user interface
 *    elements.
 *
 *  Discussion:
 *    Note that the system UI mode is a per-process state. Switching
 *    from a process that is suppressing system UI to another process
 *    that is not will cause system UI elements to become visible
 *    automatically. Switching back to the first process will suppress
 *    system UI elements again.
 }
const
{
   * In this mode, all standard system UI elements are visible.
   }
	kUIModeNormal = 0;

  {
   * In this mode, system UI elements which cover the "content area" of
   * the screen (the area other than the menubar) are hidden. However,
   * these elements may automatically show themselves in response to
   * mouse movements or other user activity; specifically, the Dock
   * will still show itself automatically when the mouse moves into the
   * Dock's auto-show region.
   }
	kUIModeContentSuppressed = 1;

  {
   * In this mode, system UI elements which cover the "content area" of
   * the screen (the area other than the menubar) are hidden. Unlike
   * kUIModeContentSuppressed, most UI elements will not automatically
   * show themselves in this mode.
   }
	kUIModeContentHidden = 2;

  {
   * In this mode, all system UI elements, including the menubar, are
   * hidden. However, these elements may automatically show themselves
   * in response to mouse movements or other user activity;
   * specifically, the Dock and menubar will still show themselves
   * automatically when the mouse moves into the Dock's auto-show
   * region. Available in Mac OS X 10.3 and later.
   }
	kUIModeAllSuppressed = 4;

  {
   * In this mode, all system UI elements, including the menubar, are
   * hidden. Most system UI elements will not automatically show
   * themselves in this mode. The application may request that the
   * menubar automatically show itself while in this mode by passing
   * the kUIOptionAutoShowMenuBar flag to SetSystemUIMode.
   }
	kUIModeAllHidden = 3;

type
	SystemUIMode = UInt32;
	SystemUIModePtr = ^SystemUIMode;

{
 *  Summary:
 *    Controls optional behavior of system-provided user interface
 *    elements.
 }
const
{
   * Requests that the menubar automatically show itself when the user
   * moves the mouse into the screen area that would ordinarily be
   * occupied by the menubar. Only valid with kUIModeAllHidden.
   }
	kUIOptionAutoShowMenuBar = 1 shl 0;

  {
   * Requests that the menubar animate on or offscreen, if the UIMode
   * is also being changed such that the menubar will change
   * visibility. Unlike other UI options, this option is not stored and
   * only affects the behavior of this call to SetSystemUIMode. Valid
   * for all modes. Available in Mac OS X 10.7 and later.
   }
	kUIOptionAnimateMenuBar = 1 shl 1;

  {
   * Disables all items in the Apple menu. Valid for all modes.
   }
	kUIOptionDisableAppleMenu = 1 shl 2;

  {
   * The active application may not be changed while this process is
   * active. Currently disables the Command-Tab and Command-Shift-Tab
   * key sequences to switch the active process, and the global window
   * rotation key sequence selected by the user in the Keyboard
   * preference pane. SetFrontProcess may still be used to explicitly
   * switch the active process. Only valid with modes other than
   * kUIModeNormal.
   }
	kUIOptionDisableProcessSwitch = 1 shl 3;

  {
   * The Force Quit window may not be displayed while this process is
   * active. Currently disables the Command-Option-Escape key sequence
   * to open the Force Quit window and the Force Quit menu item in the
   * Apple menu. Only valid with modes other than kUIModeNormal.
   }
	kUIOptionDisableForceQuit = 1 shl 4;

  {
   * The current login session may not be terminated while this process
   * is active. Currently disables the Power key and the Restart, Shut
   * Down, and Log Out menu items in the Apple menu. Only valid with
   * modes other than kUIModeNormal.
   }
	kUIOptionDisableSessionTerminate = 1 shl 5;

  {
   * The Hide menu item in the Application menu is disabled. Note that
   * this option does not prevent this application from being hidden if
   * Hide Others is selected in some other application. Available in
   * Mac OS X 10.3 and later.
   }
	kUIOptionDisableHide = 1 shl 6;

  {
   * Provides the ability to specify whether the menu bar will disable
   * its adaptive transparency. Note this should be used in conjunction
   * with a full-screen window using kUIModeContentSuppressed or
   * kUIModeContentHidden. Available in Mac OS X 10.6 and later. This
   * constant was published in the Mac OS X 10.5 version of
   * MacApplication.h, but had the wrong value (7) and should not be
   * used in Mac OS X 10.5.
   }
	kUIOptionDisableMenuBarTransparency = 1 shl 9;

type
	SystemUIOptions = OptionBits;
	SystemUIOptionsPtr = ^SystemUIOptions;
{
 *  SetSystemUIMode()
 *
 *  Summary:
 *    Sets the presentation mode for system-provided user interface
 *    elements.
 *
 *  Discussion:
 *    The presentation mode of an application determines which
 *    system-provided user interface elements are visible on these
 *    screen. When the frontmost application changes its presentation
 *    mode, a kEventAppSystemUIModeChanged Carbon event is sent to all
 *    applications that have registered for the event. This event is
 *    also sent when an application is activated; it contains the newly
 *    active application's presentation mode.
 *
 *    Note that SetSystemUIMode should _not_ be used from UIElement or
 *    BackgroundOnly applications. The presentation mode of the current
 *    login session is determined by the presentation mode of the
 *    frontmost fateful application. Therefore, the presentation mode
 *    of a UIElement or BackgroundOnly application will be ignored,
 *    since these types of applications can't be the frontmost faceful
 *    application.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Parameters:
 *
 *    inMode:
 *      The new mode.
 *
 *    inOptions:
 *      Options controlling how the new mode behaves. Not all options
 *      are valid for all modes. Options that are invalid for the
 *      specified mode are silently ignored.
 *
 *  Result:
 *    An operating system result code.
 *
 *  Availability:
 *    Mac OS X:         in version 10.2 and later in Carbon.framework
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.2 and later
 *    Non-Carbon CFM:   not available
 }
function SetSystemUIMode( inMode: SystemUIMode; inOptions: SystemUIOptions ): OSStatus; external name '_SetSystemUIMode';
(* AVAILABLE_MAC_OS_X_VERSION_10_2_AND_LATER *)


{
 *  GetSystemUIMode()
 *
 *  Summary:
 *    Returns the presentation mode of the current application.
 *
 *  Discussion:
 *    Note that GetSystemUIMode returns the presentation mode of the
 *    calling application, _not_ the mode of the current login session.
 *    The login session mode may be different, since the login session
 *    mode is determined by the presentation mode of the frontmost
 *    fateful application. If the calling application is not currently
 *    the frontmost fateful application, then its presentation mode
 *    will not be in use. You may use the kEventAppSystemUIModeChanged
 *    Carbon event to track changes in the login session's presentation
 *    mode.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Parameters:
 *
 *    outMode:
 *      On exit, contains the current mode. You may pass NULL if you
 *      don't need this information.
 *
 *    outOptions:
 *      On exit, contains the current options for the mode. You may
 *      pass NULL if you don't need this information.
 *
 *  Availability:
 *    Mac OS X:         in version 10.2 and later in Carbon.framework
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.2 and later
 *    Non-Carbon CFM:   not available
 }
procedure GetSystemUIMode( outMode: SystemUIModePtr { can be NULL }; outOptions: SystemUIOptionsPtr { can be NULL } ); external name '_GetSystemUIMode';
(* AVAILABLE_MAC_OS_X_VERSION_10_2_AND_LATER *)



{
 *  GetApplicationTextEncoding()
 *
 *  Summary:
 *    Returns the application's primary text encoding.
 *
 *  Discussion:
 *    The application text encoding is used when you create a
 *    CFStringRef from text stored in Resource Manager resources, which
 *    typically uses one of the Mac encodings such as MacRoman or
 *    MacJapanese. The encoding is determined by: (a) if your app is
 *    bundled, the encoding of the .lproj directory chosen by CFBundle,
 *    (b) else if your plist has a CFBundleDevelopmentRegionKey, the
 *    encoding specified by that key, (c) else if your app has a 'vers'
 *    resource, the encoding for the region field in the 'vers', (d)
 *    else the current localization of the operating system.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.2 and later
 *    Non-Carbon CFM:   not available
 }
function GetApplicationTextEncoding: TextEncoding; external name '_GetApplicationTextEncoding';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)



{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kHIAboutBoxNameKey CFSTRP('HIAboutBoxName')}
{$endc}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kHIAboutBoxVersionKey CFSTRP('HIAboutBoxVersion')}
{$endc}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kHIAboutBoxCopyrightKey CFSTRP('HIAboutBoxCopyright')}
{$endc}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kHIAboutBoxDescriptionKey CFSTRP('HIAboutBoxDescription')}
{$endc}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kHIAboutBoxStringFileKey CFSTRP('HIAboutBoxStringFile')}
{$endc}


{
 *  HISearchWindowShow()
 *
 *  Summary:
 *    Requests that the Spotlight search window be displayed.
 *
 *  Discussion:
 *    Brings up "search for string" Spotlight UI. The window is shown
 *    in the default configuration.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Parameters:
 *
 *    inSearchString:
 *      A CFString for which to search. You may pass NULL to open the
 *      search window with no initial query string.
 *
 *    inFlags:
 *      Optional flags. Use kNilOptions for now.
 *
 *  Result:
 *    An operating system status code.
 *
 *  Availability:
 *    Mac OS X:         in version 10.4 and later in Carbon.framework
 *    CarbonLib:        not available in CarbonLib 1.x, is available on Mac OS X version 10.4 and later
 *    Non-Carbon CFM:   not available
 }
function HISearchWindowShow( inSearchString: CFStringRef { can be NULL }; inFlags: OptionBits ): OSStatus; external name '_HISearchWindowShow';
(* AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER *)


{
 *  HIDictionaryWindowShow()
 *
 *  Summary:
 *    Implements "Look up in Dictionary" context menu action.
 *
 *  Discussion:
 *    Opens Dictionary.app or panel to show the definition of a word or
 *    phrase.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Parameters:
 *
 *    dictionary:
 *      This parameter is not supported now. You should always pass
 *      NULL.
 *
 *    textString:
 *      Text that contains the word or phrase to look up. The data type
 *      must be either CFStringRef, CFAttributedStringRef, or CFDataRef
 *      containing Rich Text Format data. Text attributes are used to
 *      draw the title of the Dictionary Panel.
 *
 *    selectionRange:
 *      Specifies the selection range in textString. If there is no
 *      selection, use the range returned by DCSGetTermRangeInString()
 *      in CoreServices/DictionaryServices.
 *
 *    textFont:
 *      Required only when the textString is CFStringRef and otherwise
 *      ignored. Specifies CTFontRef that corresponds to
 *      selectionRange.location. The font is used to draw the title of
 *      the Dictionary Panel.
 *
 *    textOrigin:
 *      Typographic baseline origin point of the character at
 *      selectionRange.location in screen pixels (the top left of the
 *      screen is 0, 0)
 *
 *    verticalText:
 *      Set true if the text is drawn in vertical orientation
 *
 *    viewTransform:
 *      Affine transformation matrix being applied to the view contains
 *      textString. Set NULL to use identity matrix. This is used to
 *      align Dictionary Panel title with the original text. Currently,
 *      only scaling factor is supported.
 *
 *  Availability:
 *    Mac OS X:         in version 10.5 and later in Carbon.framework
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   not available
 }
(*
Requires translation of DictionaryServices framework

procedure HIDictionaryWindowShow( dictionary: DCSDictionaryRef { can be NULL }; textString: CFTypeRef; selectionRange: CFRange; textFont: CTFontRef { can be NULL }; textOrigin: CGPoint; verticalText: Boolean; {const} viewTransform: CGAffineTransformPtr { can be NULL } ); external name '_HIDictionaryWindowShow';
*)
//AVAILABLE_MAC_OS_X_VERSION_10_5_AND_LATER;

{$endc} {TARGET_OS_MAC}
{$ifc not defined MACOSALLINCLUDE or not MACOSALLINCLUDE}

end.
{$endc} {not MACOSALLINCLUDE}
