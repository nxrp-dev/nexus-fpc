{
     File:       HIToolbox/MacWindows.h

     Contains:   Window Manager Interfaces

     Version:    HIToolbox-624~3

     Copyright:  © 1997-2008 by Apple Inc., all rights reserved

     Bugs?:      For bug reports, consult the following page on
                 the World Wide Web:

                     http://bugs.freepascal.org

}
{       Pascal Translation Updated:  Peter N Lewis, <peter@stairways.com.au>, August 2005 }
{       Pascal Translation Updated:  Jonas Maebe, <jonas@freepascal.org>, October 2009 }
{       Pascal Translation Updated:  Gorazd Krosl, <gorazd_1957@yahoo.ca>, October 2009 }
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
unit MacWindows;
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
uses MacOsApi.MacTypes,MacOsApi.Files,MacOsApi.Appearance,MacOsApi.HIGeometry,MacOsApi.HIObject,MacOsApi.HIShape,MacOsApi.HIToolbar,MacOsApi.Aliases,MacOsApi.Collections,MacOsApi.Drag,MacOsApi.Events,MacOsApi.Menus,MacOsApi.QDOffscreen,MacOsApi.QuickdrawTypes,MacOsApi.IconsCore,MacOsApi.CFBase,MacOsApi.CFArray,MacOsApi.CGBase,MacOsApi.CGColorSpace,MacOsApi.CGContext,MacOsApi.CGDirectDisplay,MacOsApi.CGWindow,MacOsApi.CGWindowLevels,MacOsApi.CarbonEventsCore;
{$ELSE FPC_DOTTEDUNITS}
uses MacTypes,Files,Appearance,HIGeometry,HIObject,HIShape,HIToolbar,Aliases,Collections,Drag,Events,Menus,QDOffscreen,QuickdrawTypes,IconsCore,CFBase,CFArray,CGBase,CGColorSpace,CGContext,CGDirectDisplay,CGWindow,CGWindowLevels,CarbonEventsCore;
{$ENDIF FPC_DOTTEDUNITS}
{$endc} {not MACOSALLINCLUDE}


{$ifc TARGET_OS_MAC}

{$ALIGN MAC68K}

{ Current documentation for the Mac OS X Window Manager is available on the web:           }
{  <http://developer.apple.com/documentation/Carbon/Reference/Window_Manager/index.html>   }
{——————————————————————————————————————————————————————————————————————————————————————}
{ • HIWindowRef                                                                        }
{——————————————————————————————————————————————————————————————————————————————————————}
type
	HIWindowRef = WindowRef;
	HIWindowRefPtr = ^HIWindowRef;
{——————————————————————————————————————————————————————————————————————————————————————}
{ • Property Types                                                                     }
{——————————————————————————————————————————————————————————————————————————————————————}
type
	PropertyCreator = OSType;
	PropertyTag = OSType;
{——————————————————————————————————————————————————————————————————————————————————————}
{ • Window Classes                                                                     }
{——————————————————————————————————————————————————————————————————————————————————————}

{
 *  WindowClass
 *
 *  Summary:
 *    The types of windows provided by the Window Manager.
 *
 *  Discussion:
 *    The class of a window determines several aspects of the window:
 *    its appearance, its initial window attributes, its initial window
 *    group, and its initial modality. All of these except for the
 *    window's appearance may be changed later using other Window
 *    Manager APIs.
 }
type
	WindowClass = UInt32;
	WindowClass_fix = WindowClass; { used as field type when a record declaration contains a WindowClass field identifier }
const
{
   * An alert window is used when the application needs the user's
   * attention immediately. On Mac OS 9 and earlier, a visible alert
   * window will prevent the user from switching to any other
   * application. Use kThemeBrushAlertBackgroundActive to draw the
   * background of alert windows.
   *
   * Alert windows support compositing mode in Mac OS X 10.5 and later.
   *
   *
   * Alert windows are initially placed in the modal window group,
   * given a modality of kWindowModalityAppModal, and given an
   * activation scope of kWindowActivationScopeAll. Available in Mac OS
   * 8.5 and later.
   }
	kAlertWindowClass = 1;

  {
   * Similar to kAlertWindowClass, but provides a window that is
   * movable and that allows switching to other applications. Generally
   * you should use this window class rather than kAlertWindowClass.
   * Use kThemeBrushAlertBackgroundActive to draw the background of
   * movable alert windows.
   *
   * Movable alert windows support compositing mode in Mac OS X 10.2
   * and later.
   *
   * Movable alert windows are initially placed in the modal window
   * group, given a modality of kWindowModalityAppModal, and given an
   * activation scope of kWindowActivationScopeAll. Available in Mac OS
   * 8.5 and later.
   }
	kMovableAlertWindowClass = 2;

  {
   * A modal window is used to display a dialog (but not an alert; use
   * kAlertWindowClass for alerts). On Mac OS 9 and earlier, a visible
   * modal window will prevent the user from switching to any other
   * application. Use kThemeBrushDialogBackgroundActive to draw the
   * background of modal windows.
   *
   * Modal windows support compositing mode in Mac OS X 10.5 and later.
   *
   *
   * Modal windows are initially placed in the modal window group,
   * given a modality of kWindowModalityAppModal, and given an
   * activation scope of kWindowActivationScopeAll. Available in Mac OS
   * 8.5 and later.
   }
	kModalWindowClass = 3;

  {
   * Similar to kModalWindowClass, but provides a window that is
   * movable and that allows switching to other applications. Generally
   * you should use this window class rather than kModalWindowClass. If
   * you are using CarbonLib 1.3 or later, or Mac OS X, use
   * kThemeBrushMovableModalBackground to draw the background of
   * movable modal windows; on earlier versions of CarbonLib, or for
   * non-Carbon programming, use kThemeBrushDialogBackgroundActive.
   *
   *
   * Movable modal windows support compositing mode in Mac OS X 10.2
   * and later.
   *
   * Movable modal windows are initially placed in the modal window
   * group, given a modality of kWindowModalityAppModal, and given an
   * activation scope of kWindowActivationScopeAll. Available in Mac OS
   * 8.5 and later.
   }
	kMovableModalWindowClass = 4;

  {
   * A floating window is layered above all application windows except
   * for alert and modal windows. It is commonly used for palette
   * windows, inspectors, and other accessory (non-document) windows.
   * Use kThemeBrushUtilityWindowBackgroundActive or
   * kThemeBrushDocumentWindowBackground to draw the background of
   * floating windows.
   *
   * Floating windows support compositing mode in Mac OS X 10.2 and
   * later.
   *
   * Floating windows are initially placed in the floating window
   * group, given a modality of kWindowModalityNone, and given an
   * activation scope of kWindowActivationScopeIndependent. Available
   * in Mac OS 8.6 and later.
   }
	kFloatingWindowClass = 5;

  {
   * A document window is used for normal application document windows.
   * Use kThemeBrushDocumentWindowBackground or your own custom drawing
   * to draw the background of a document window.
   *
   * Document windows support compositing mode in Mac OS X 10.2 and
   * later.
   *
   * Document windows are initially placed in the document window
   * group, given a modality of kWindowModalityNone, and given an
   * activation scope of kWindowActivationScopeAll. Available in Mac OS
   * 8.5 and later.
   }
	kDocumentWindowClass = 6;

  {
   * A utility window is similar to a floating window, but it floats
   * above the windows of all applications rather than just above the
   * windows of the application that creates it. Use
   * kThemeBrushUtilityWindowBackgroundActive or
   * kThemeBrushDocumentWindowBackground to draw the background of
   * utility windows.
   *
   * Utility windows support compositing mode in Mac OS X 10.2 and
   * later.
   *
   * Utility windows are initially placed in the utility window group,
   * given a modality of kWindowModalityNone, and given an activation
   * scope of kWindowActivationScopeIndependent. Available in CarbonLib
   * 1.1 and later, and in Mac OS X.
   }
	kUtilityWindowClass = 8;

  {
   * A help window is used to display help tags. It has no window
   * frame. Typically you should use the Help Manager to display help
   * tags, rather than creating a help tag window yourself.
   *
   * Help windows support compositing mode in Mac OS X 10.3 and later.
   *
   *
   * Help windows are initially placed in the help window group, given
   * a modality of kWindowModalityNone, and given an activation scope
   * of kWindowActivationScopeNone. Available in CarbonLib 1.1 and
   * later, and in Mac OS X.
   }
	kHelpWindowClass = 10;

  {
   * A sheet window is used to display a dialog that is attached
   * directly to its parent window, rather than being a independent
   * window. A sheet dialog only prevents interaction with its parent
   * window; the user may still interact with other windows in the same
   * application. Use kThemeBrushSheetBackgroundOpaque to draw an
   * opaque background for sheet windows, or
   * kThemeBrushSheetBackgroundTransparent to draw a transparent
   * background (the transparent brush is only available in Mac OS X
   * 10.1 and later).
   *
   * Sheet windows support compositing mode in Mac OS X 10.2 and later.
   *
   *
   * Sheet windows are initially placed in the document window group,
   * given a modality of kWindowModalityNone, and given an activation
   * scope of kWindowActivationScopeAll. Available in CarbonLib 1.3 and
   * later, and in Mac OS X; in CarbonLib, a sheet window is actually a
   * movable-modal window, which blocks user interaction with all
   * windows of the application.
   }
	kSheetWindowClass = 11;

  {
   * A toolbar window is used to display a palette of controls. It is
   * similar to a floating window, and like a floating window is
   * layered above all application windows except for alert and modal
   * windows, but is layered beneath floating windows. Use
   * kThemeBrushToolbarBackground to draw the background of a toolbar
   * window in Mac OS X or later; CarbonLib does not currently support
   * kThemeBrushToolbarBackground.
   *
   * Toolbar windows support compositing mode in Mac OS X 10.3 and
   * later.
   *
   * Toolbar windows are initially placed in the toolbar window group,
   * given a modality of kWindowModalityNone, and given an activation
   * scope of kWindowActivationScopeNone. Available in CarbonLib 1.1
   * and later, and Mac OS X.
   }
	kToolbarWindowClass = 12;

  {
   * A plain window has a single-pixel window frame.
   * kThemeBrushDocumentWindowBackground,
   * kThemeBrushDialogBackgroundActive, and application-specific custom
   * drawing are all commonly used to draw the background of a plain
   * window.
   *
   * Plain windows support compositing mode on Mac OS X 10.3 and later.
   *
   *
   * Plain windows are initially placed in the document window group,
   * given a modality of kWindowModalityNone, and given an activation
   * scope of kWindowActivationScopeAll. Available in CarbonLib 1.2.5
   * and later, and Mac OS X.
   }
	kPlainWindowClass = 13;

  {
   * An overlay window is a completely transparent window positioned
   * above all other windows. Overlay windows are intended as a
   * replacement for the pre-Carbon practice of drawing directly into
   * the window manager port; by creating a full-screen overlay window
   * and drawing into it, you can draw over any window in any
   * application without disturbing the contents of the windows
   * underneath your drawing.
   *
   * Overlay windows have a default handler for kEventWindowPaint that
   * uses CGContextClearRect to clear the overlay window's alpha
   * channel to zero. This ensures the initial transparency of the
   * window. You can install your own kEventWindowPaint handler to do
   * your own drawing; typically, you would call through to the default
   * handler with CallNextEventHandler first, and then use
   * QDBeginCGContext to create your own context for drawing. You can
   * use either QuickDraw or CoreGraphics to draw into an overlay
   * window, but you must use CoreGraphics to draw if you need any of
   * your drawing to be non-opaque, since QuickDraw always sets the
   * alpha channel of any pixels that it touches to 1.0.
   *
   * Overlay windows support compositing mode on Mac OS X 10.3 and
   * later. You should draw into a compositing overlay window by adding
   * a standard or custom HIView and implementing the kEventControlDraw
   * event for your view; do not use kEventWindowPaint.
   *
   * You can also use the standard window event handler together with
   * regular controls in an overlay window. When using the standard
   * window event handler, you will probably want your
   * kEventWindowPaint handler to return eventNotHandledErr (after
   * calling the default handler with CallNextEventHandler first) so
   * that after the Paint handler returns, the Window Manager will send
   * a kEventWindowDrawContent event which the standard window event
   * handler can respond to by drawing the controls in the window.
   *
   *
   * Overlay windows are initially placed in the overlay window group,
   * given a modality of kWindowModalityNone, and given an activation
   * scope of kWindowActivationScopeNone. Available in Mac OS X.
   }
	kOverlayWindowClass = 14;

  {
   * A sheet alert window is similar to a sheet window, but is intended
   * to display an alert rather than a dialog. On Mac OS X, the
   * appearance of a sheet window and a sheet alert window is currently
   * identical, but in CarbonLib a sheet alert window has a different
   * appearance from a sheet window. Use
   * kThemeBrushSheetBackgroundOpaque to draw an opaque background for
   * sheet alert windows, or kThemeBrushSheetBackgroundTransparent to
   * draw a transparent background (the transparent brush is only
   * available in Mac OS X 10.1 and later).
   *
   * Sheet alert windows support compositing mode in Mac OS X 10.2 and
   * later.
   *
   * Sheet alert windows are initially placed in the document window
   * group, given a modality of kWindowModalityNone, and given an
   * activation scope of kWindowActivationScopeAll. Available in
   * CarbonLib 1.3 and later, and in Mac OS X 10.1 and later; in
   * CarbonLib, a sheet alert window is actually a movable alert
   * window, which blocks user interaction with all windows of the
   * application.
   }
	kSheetAlertWindowClass = 15;

  {
   * A alternate plain window is similar to a plain window but has a
   * solid black shadow on its right and bottom sides. It is rarely
   * used in modern Mac OS applications.
   * kThemeBrushDocumentWindowBackground,
   * kThemeBrushDialogBackgroundActive, and application-specific custom
   * drawing are all commonly used to draw the background of an
   * alternate plain window.
   *
   * Alternate plain windows support compositing mode in Mac OS X 10.5
   * and later.
   *
   * Alternate plain windows are initially placed in the document
   * window group, given a modality of kWindowModalityNone, and given
   * an activation scope of kWindowActivationScopeAll. Available in
   * CarbonLib 1.3 and later, and Mac OS X 10.1 and later.
   }
	kAltPlainWindowClass = 16;

  {
   * A simple window is the simplest possible window; it has no window
   * frame and its entire content is drawn by the application. Use any
   * theme brush or your own custom drawing to draw the background of a
   * simple window.
   *
   * Simple windows support compositing mode in Mac OS X 10.3 and
   * later.
   *
   * Simple windows are initially placed in the document window group,
   * given a modality of kWindowModalityNone, and given an activation
   * scope of kWindowActivationScopeAll. Available in CarbonLib 1.5 and
   * later, and Mac OS X 10.1 and later.
   }
	kSimpleWindowClass = 18;

  {
   * A drawer window is used when implementing a drawer user interface,
   * in which the drawer window slides out from underneath a document
   * window. Use kThemeBrushDrawerBackground or
   * kThemeBrushDocumentWindowBackground to draw the background of
   * drawer windows.
   *
   * Drawer windows must always use compositing mode.
   *
   * Drawer windows are initially placed in the document window group,
   * given a modality of kWindowModalityNone, and given an activation
   * scope of kWindowActivationScopeAll. Drawer windows must always be
   * created using the Compositing window attribute. Available in Mac
   * OS X 10.2 or later.
   }
	kDrawerWindowClass = 20;

  {
   * Not an actual window class, but a meta-constant that is used with
   * GetFrontWindowOfClass, FindWindowOfClass, and GetNextWindowOfClass
   * to indicate that there should be no restriction on the class of
   * the returned window. Also used with GetWindowGroupOfClass to get
   * the root window group.
   }
	kAllWindowClasses = $FFFFFFFF;


{——————————————————————————————————————————————————————————————————————————————————————}
{ • Window Attributes                                                                  }
{——————————————————————————————————————————————————————————————————————————————————————}

{
 *  Summary:
 *    Window attribute bits.
 }
const
{
   * This window has a close box. Available for windows of
   * kDocumentWindowClass, kFloatingWindowClass, and
   * kUtilityWindowClass; in Mac OS X 10.5 and later, also available
   * for windows of kMovableModalWindowClass.
   }
	kHIWindowBitCloseBox = 1;

  {
   * This window has a zoom box. Available for windows of
   * kDocumentWindowClass, kFloatingWindowClass, and
   * kUtilityWindowClass; in Mac OS X 10.5 and later, also available
   * for windows of kMovableModalWindowClass. Note that when this
   * attribute is set on a window, both the
   * kWindowHorizontalZoomAttribute and kWindowVerticalZoomAttribute
   * bits are set automatically.
   }
	kHIWindowBitZoomBox = 2;

  {
   * This window has a collapse box. Available for windows of
   * kDocumentWindowClass, kFloatingWindowClass, and
   * kUtilityWindowClass. For Floating and Utility window classes on
   * Mac OS X, this attribute must be added to the window using
   * ChangeWindowAttributes after the window is created; it may not be
   * added to the window at creation time.
   }
	kHIWindowBitCollapseBox = 4;

  {
   * This window can be resized. Available for windows of
   * kDocumentWindowClass, kMovableModalWindowClass,
   * kFloatingWindowClass, kUtilityWindowClass, and kSheetWindowClass.
   }
	kHIWindowBitResizable = 5;

  {
   * This window has a vertical titlebar on the side of the window.
   * Available for windows of kFloatingWindowClass and
   * kUtilityWindowClass.
   }
	kHIWindowBitSideTitlebar = 6;

  {
   * This window has a toolbar button. Available for windows of
   * kDocumentWindowClass on Mac OS X.
   }
	kHIWindowBitToolbarButton = 7;

  {
   * This window draws its window title and toolbar using a unified
   * appearance that has no separator between the two areas. A window
   * may not have both kHIWindowBitUnifiedTitleAndToolbar and
   * kHIWindowBitTextured. If a window already has the Textured
   * attribute, attempting to set the Unified attribute will cause
   * ChangeWindowAttributes to return an error, and vice versa. This
   * constant was not added to this header file until Mac OS X 10.5,
   * but it is actually available at runtime on Mac OS X 10.4 and later
   * for windows of kDocumentWindowClass. However, on Mac OS X 10.5 and
   * later, kHIWindowBitUnifiedTitleAndToolbar no longer has any
   * effect, since all windows with toolbars now have a unified look.
   }
	kHIWindowBitUnifiedTitleAndToolbar = 8;

  {
   * This window uses the Textured appearance. Available for document
   * windows on Mac OS X 10.2 and later, and for floating windows on
   * Mac OS X 10.3 and later. Drawers can also be textured, but
   * dynamically adjust their appearance based on their parent window's
   * appearance; it is not necessary to specify this attribute for a
   * textured drawer.
   }
	kHIWindowBitTextured = 9;

  {
   * For Document, Floating, and Utility windows, this attribute allows
   * you to hide the title bar of a window. Available in Mac OS X 10.4
   * and later.
   }
	kHIWindowBitNoTitleBar = 10;

  {
   * Indicates that a textured window should have square corners. By
   * default, a textured window has round corners. When this attribute
   * is set on a window, the window frame view automatically makes the
   * grow box view opaque, and when this attribute is cleared, the
   * window frame view automatically makes the grow box view
   * transparent. You can change the grow box view transparency after
   * modifying this attribute with HIGrowBoxViewSetTransparent.
   * Relevant only for textured windows; ignored in non-textured
   * windows. Available in Mac OS X 10.5 and later for window classes
   * that support the textured appearance.
   }
	kHIWindowBitTexturedSquareCorners = 11;

  {
   * Indicates that no border should be drawn between the toolbar and
   * window content. Relevant only in textured windows. Ignored in
   * non-textured windows.  Available in Mac OS X 10.4 and later for
   * window classes that support the textured appearance.
   }
	kHIWindowBitNoTexturedContentSeparator = 12;

  {
   * Indicates that this window will have rounded bottom corners. By
   * default, a window has squared corners, and the assertion of this
   * bit turns on rounded bottom corners for the window if the window
   * has a bottom bar (set with HIWindowSetContentBorderThickness). If
   * the window does not have a bottom bar, this bit is ignored. If the
   * window has the kHIWindowBitTextured attribute set, the
   * kHIWindowBitRoundBottomBarCorners attribute will be ignored, as
   * that type of window defaults to rounded corners and controls the
   * squareness with the kHIWindowBitTexturedSquareCorners attribute.
   }
	kHIWindowBitRoundBottomBarCorners = 13;

  {
   * This window does not participate in window cycling invoked by
   * cmd-~ or the "Focus on Window" hotkey defined in the Keyboards
   * preference pane. Available for all windows on Mac OS X 10.2 and
   * later.
   }
	kHIWindowBitDoesNotCycle = 16;

  {
   * This window receives no update events. Available for all windows.
   }
	kHIWindowBitNoUpdates = 17;

  {
   * This window receives no activate events. Available for all windows.
   }
	kHIWindowBitNoActivates = 18;

  {
   * This window receives mouse events even for areas of the window
   * that are transparent (have an alpha channel component of zero).
   * Available for windows of kOverlayWindowClass on Mac OS X 10.0 and
   * 10.1, and available for all windows on Mac OS X 10.2 and later.
   }
	kHIWindowBitOpaqueForEvents = 19;

  {
   * This window uses composited drawing. This means that the entire
   * window is comprised of HIViews, and can be treated thusly. This
   * attribute must be specified at window creation, and cannot be
   * changed later with ChangeWindowAttributes. Available on Mac OS X
   * 10.2 and later.
   }
	kHIWindowBitCompositing = 20;

  {
   * This window's backing store can be scaled as necessary for high
   * resolution drawing. This attribute is only consulted/respected if
   * the app's Info.plist includes NSHighResolutionCapable with a value
   * of true. This attribute can only be used when
   * kHIWindowBitCompositing is also enabled for the window. When this
   * attribute is enabled, you may not draw with QuickDraw in the
   * window. You may only specify this attribute at window creation
   * time. Available for all windows in 10.7.4 and later.
   }
	kHIWindowBitHighResolutionCapable = 21;

  {
   * This window has no shadow. Available for all windows on Mac OS X.
   * This attribute is automatically given to windows of
   * kOverlayWindowClass.
   }
	kHIWindowBitNoShadow = 22;

  {
   * This window can be made visible prior to user login. By default,
   * in Mac OS X 10.5 and later no windows can be visible before a user
   * logs into the system; this protects the user against certain types
   * of malicious use of insecure applications. However, some software,
   * such as input methods or other accessibility software, may need to
   * deliberately make windows available prior to user login. Such
   * software should add this window attribute to its windows.
   * Available for all windows in Mac OS X 10.5 and later.
   }
	kHIWindowBitCanBeVisibleWithoutLogin = 23;

  {
   * This window is marked so that the window server will drag the
   * window automatically. Your application should not call DragWindow
   * for this window, else it would confuse the heck out of the drag
   * (it would fight with the window server for control). This
   * attribute is ignored (async drag is not used) if your window is
   * grouped with other windows in a window group that has the
   * kWindowGroupAttrMoveTogether attribute. Available for all windows
   * on Mac OS X 10.3 and later.
   }
	kHIWindowBitAsyncDrag = 24;

  {
   * This window is automatically hidden on suspend and shown on
   * resume. Available for all windows. This attribute is automatically
   * given to windows of kFloatingWindowClass, kHelpWindowClass, and
   * kToolbarWindowClass.
   }
	kHIWindowBitHideOnSuspend = 25;

  {
   * This window has the standard Carbon window event handler
   * installed. Available for all windows.
   }
	kHIWindowBitStandardHandler = 26;

  {
   * This window is automatically hidden during fullscreen mode (when
   * the menubar is invisible) and shown afterwards. Available for all
   * windows. This attribute is automatically given to windows of
   * kUtilityWindowClass.
   }
	kHIWindowBitHideOnFullScreen = 27;

  {
   * This window is added to the standard Window menu. Available for
   * windows of kDocumentWindowClass. This attribute is automatically
   * given to windows of kDocumentWindowClass.
   }
	kHIWindowBitInWindowMenu = 28;

  {
   * This window supports live resizing. Available for all windows on
   * Mac OS X.
   }
	kHIWindowBitLiveResize = 29;

  {
   * This window never receives mouse events, even in areas that are
   * opaque. Instead, clicks on the window will be passed through to
   * windows beneath it. Available for all windows on Mac OS X 10.2 and
   * later.
   }
	kHIWindowBitIgnoreClicks = 30;

  {
   * This window will not be repositioned by the default
   * kEventWindowConstrain handler in response to changes in monitor
   * size, Dock position, and so on. Available for all windows on Mac
   * OS X 10.1 and later, and CarbonLib 1.6 and later.
   }
	kHIWindowBitNoConstrain = 32;

  {
   * Indicates that this window does not hide when the application is
   * hidden. Available for all windows in Mac OS X 10.5 and later. This
   * attribute is automatically given to windows of kUtilityWindowClass.
   }
	kHIWindowBitDoesNotHide = 33;

  {
   * Indicates that this window automatically installs Drag Manager
   * callbacks to detect drag actions, and automatically sends HIView
   * drag Carbon events. Setting this attribute is equivalent to
   * calling the SetAutomaticControlDragTrackingEnabledForWindow API
   * (and calling that API will now set this attribute). Available for
   * all windows in Mac OS X 10.5 and later.
   }
	kHIWindowBitAutoViewDragTracking = 34;

  {
   * Indicates that this window automatically updates its ColorSync
   * profile to the profile of the display containing the greatest area
   * of the window. After the profile is set,
   * kEventWindowColorSpaceChanged is sent to the window. The standard
   * window handler's response is to repaint the entire window.
   * Available for all windows in Mac OS X 10.6 and later. This
   * attribute is automatically given to all compositing windows.
   }
	kHIWindowBitAutoCalibration = 36;

  {
   * Indicates that this window can become fullscreen, and causes the
   * enter fullscreen title bar button to be added to the window's
   * title bar. Including this bit on a window causes HIToolbox to add
   * appropriate Enter/Exit Full Screen menu items to the app's menus,
   * which HIToolbox will update appropriately. Only supported for
   * windows of kDocumentWindowClass. Available in Mac OS X 10.7 and
   * later.
   }
	kHIWindowBitFullScreenPrimary = 45;

  {
   * Indicates that this window can coexist on a fullscreen space with
   * a fullscreen window of another application, but is not capable of
   * becoming fullscreen itself.
   * This window attribute is used in conjunction with the
   * kHIWindowCanJoinAllSpaces Availability option to allow the window
   * to move across FullScreen workspaces. For applications that are
   * BackgroundOnly or UIElements, this is the default behavior when
   * kHIWindowCanJoinAllSpaces is also set. For other applications,
   * kHIWindowBitFullScreenAuxiliary must be specified, and is
   * supported for window classes including kUtilityWindowClass, and
   * kFloatingWindowClass with a WindowActivationScope of
   * kWindowActivationScopeIndependent or kWindowActivationScopeNone.
   * Available in Mac OS X 10.7 and later.
   }
	kHIWindowBitFullScreenAuxiliary = 46;


{
 *  Summary:
 *    Window attributes as bitmasks. In Mac OS X 10.5 and later,
 *    kHIWindowBit constants are preferred.
 *
 *  Discussion:
 *    Note that the kWindowApplicationScaledAttribute constant provided
 *    in Mac OS X 10.4 has been removed in Mac OS X 10.5 and later.
 *    Application-scaled mode was never fully implemented and all
 *    support for it has been removed from HIToolbox in Mac OS X 10.5.
 }
const
{
   * A constant with value zero; the lack of any attributes.
   }
	kWindowNoAttributes = 0;

  {
   * See kHIWindowBitCloseBox.
   }
	kWindowCloseBoxAttribute = (1 shl (kHIWindowBitCloseBox - 1));

  {
   * See kHIWindowBitZoomBox.
   }
	kWindowHorizontalZoomAttribute = (1 shl (kHIWindowBitZoomBox - 1));

  {
   * See kHIWindowBitZoomBox.
   }
	kWindowVerticalZoomAttribute = 1 shl kHIWindowBitZoomBox;

  {
   * See kHIWindowBitZoomBox.
   }
	kWindowFullZoomAttribute = kWindowVerticalZoomAttribute or kWindowHorizontalZoomAttribute;

  {
   * See kHIWindowBitCollapseBox.
   }
	kWindowCollapseBoxAttribute = (1 shl (kHIWindowBitCollapseBox - 1));

  {
   * See kHIWindowBitResizable.
   }
	kWindowResizableAttribute = (1 shl (kHIWindowBitResizable - 1));

  {
   * See kHIWindowBitSideTitlebar.
   }
	kWindowSideTitlebarAttribute = (1 shl (kHIWindowBitSideTitlebar - 1));

  {
   * See kHIWindowBitToolbarButton.
   }
	kWindowToolbarButtonAttribute = (1 shl (kHIWindowBitToolbarButton - 1));

  {
   * See kHIWindowBitUnifiedTitleAndToolbar.
   }
	kWindowUnifiedTitleAndToolbarAttribute = (1 shl (kHIWindowBitUnifiedTitleAndToolbar - 1));

  {
   * See kHIWindowBitTextured.
   }
	kWindowMetalAttribute = (1 shl (kHIWindowBitTextured - 1));

  {
   * See kHIWindowBitNoTitleBar.
   }
	kWindowNoTitleBarAttribute = (1 shl (kHIWindowBitNoTitleBar - 1));

  {
   * See kHIWindowBitTexturedSquareCorners.
   }
	kWindowTexturedSquareCornersAttribute = (1 shl (kHIWindowBitTexturedSquareCorners - 1));

  {
   * See kHIWindowBitNoTexturedContentSeparator.
   }
	kWindowMetalNoContentSeparatorAttribute = (1 shl (kHIWindowBitNoTexturedContentSeparator - 1));
	kWindowHasRoundBottomBarCornersAttribute = (1 shl (kHIWindowBitRoundBottomBarCorners - 1));

  {
   * See kHIWindowBitDoesNotCycle.
   }
	kWindowDoesNotCycleAttribute = (1 shl (kHIWindowBitDoesNotCycle - 1));

  {
   * See kHIWindowBitNoUpdates.
   }
	kWindowNoUpdatesAttribute = (1 shl (kHIWindowBitNoUpdates - 1));

  {
   * See kHIWindowBitNoActivates.
   }
	kWindowNoActivatesAttribute = (1 shl (kHIWindowBitNoActivates - 1));

  {
   * See kHIWindowBitOpaqueForEvents.
   }
	kWindowOpaqueForEventsAttribute = (1 shl (kHIWindowBitOpaqueForEvents - 1));

  {
   * See kHIWindowBitCompositing.
   }
	kWindowCompositingAttribute = (1 shl (kHIWindowBitCompositing - 1));

  {
   * See kHIWindowBitNoShadow.
   }
	kWindowNoShadowAttribute = (1 shl (kHIWindowBitNoShadow - 1));

  {
   * See kHIWindowBitCanBeVisibleWithoutLogin.
   }
	kWindowCanBeVisibleWithoutLoginAttribute = (1 shl (kHIWindowBitCanBeVisibleWithoutLogin - 1));

  {
   * See kHIWindowBitHideOnSuspend.
   }
	kWindowHideOnSuspendAttribute = (1 shl (kHIWindowBitHideOnSuspend - 1));

  {
   * See kHIWindowBitAsyncDrag.
   }
	kWindowAsyncDragAttribute = (1 shl (kHIWindowBitAsyncDrag - 1));

  {
   * See kHIWindowBitStandardHandler.
   }
	kWindowStandardHandlerAttribute = (1 shl (kHIWindowBitStandardHandler - 1));

  {
   * See kHIWindowBitHideOnFullScreen.
   }
	kWindowHideOnFullScreenAttribute = (1 shl (kHIWindowBitHideOnFullScreen - 1));

  {
   * See kHIWindowBitInWindowMenu.
   }
	kWindowInWindowMenuAttribute = (1 shl (kHIWindowBitInWindowMenu - 1));

  {
   * See kHIWindowBitLiveResize.
   }
	kWindowLiveResizeAttribute = (1 shl (kHIWindowBitLiveResize - 1));

  {
   * See kHIWindowBitIgnoreClicks.
   }
	kWindowIgnoreClicksAttribute = (1 shl (kHIWindowBitIgnoreClicks - 1));

  {
   * See kHIWindowBitHighResolutionCapable.
   }
	kWindowHighResolutionCapableAttribute = (1 shl (kHIWindowBitHighResolutionCapable - 1));

  {
   * The minimum set of window attributes commonly used by document
   * windows.
   }
	kWindowStandardDocumentAttributes = kWindowCloseBoxAttribute or kWindowFullZoomAttribute or kWindowCollapseBoxAttribute or kWindowResizableAttribute;

  {
   * The minimum set of window attributes commonly used by floating
   * windows.
   }
	kWindowStandardFloatingAttributes = kWindowCloseBoxAttribute or kWindowCollapseBoxAttribute;


const
{
   * See kHIWindowBitNoConstrain.
   }
	kWindowNoConstrainAttribute = $80000000; // force unsigned by specifying the constant explicitly
type
	WindowAttributes = OptionBits;
  WindowAttributes_fix = WindowAttributes; { used as field type when a record declaration contains a WindowAttributes field identifier }

{
 *  Summary:
 *    DEPRECATED Window attribute bits.
 }
const
{
   * DEPRECATED name and functionality. Replaced conceptually by
   * kHIWindowBitHighResolutionCapable.
   }
	kHIWindowBitFrameworkScaled = kHIWindowBitHighResolutionCapable;


{
 *  Summary:
 *    DEPRECATED Window attribute bitmasks.
 }
const
{
   * DEPRECATED name and functionality. Replaced conceptually by
   * kWindowHighResolutionCapableAttribute.
   }
	kWindowFrameworkScaledAttribute = kWindowHighResolutionCapableAttribute;


{——————————————————————————————————————————————————————————————————————————————————————}
{ • Window Definition Type                                                             }
{——————————————————————————————————————————————————————————————————————————————————————}
const
	kWindowDefProcType = FourCharCode('WDEF');

{——————————————————————————————————————————————————————————————————————————————————————}
{ • Mac OS 7.5 Window Definition Resource IDs                                          }
{——————————————————————————————————————————————————————————————————————————————————————}
const
	kStandardWindowDefinition = 0;    { for document windows and dialogs}
	kRoundWindowDefinition = 1;    { old Desk Accessory-style window}
	kFloatingWindowDefinition = 124;   { for floating windows}

{——————————————————————————————————————————————————————————————————————————————————————}
{ • Variant Codes                                                                      }
{——————————————————————————————————————————————————————————————————————————————————————}
const
{ for use with kStandardWindowDefinition }
	kDocumentWindowVariantCode = 0;
	kModalDialogVariantCode = 1;
	kPlainDialogVariantCode = 2;
	kShadowDialogVariantCode = 3;
	kMovableModalDialogVariantCode = 5;
	kAlertVariantCode = 7;
	kMovableAlertVariantCode = 9;    { for use with kFloatingWindowDefinition }
	kSideFloaterVariantCode = 8;


{——————————————————————————————————————————————————————————————————————————————————————}
{ • DefProc IDs                                                                        }
{——————————————————————————————————————————————————————————————————————————————————————}
const
{ classic ids }
	documentProc = 0;
	dBoxProc = 1;
	plainDBox = 2;
	altDBoxProc = 3;
	noGrowDocProc = 4;
	movableDBoxProc = 5;
	zoomDocProc = 8;
	zoomNoGrow = 12;   { floating window defproc ids }
	floatProc = 1985;
	floatGrowProc = 1987;
	floatZoomProc = 1989;
	floatZoomGrowProc = 1991;
	floatSideProc = 1993;
	floatSideGrowProc = 1995;
	floatSideZoomProc = 1997;
	floatSideZoomGrowProc = 1999;

const
{ Resource IDs for theme-savvy window defprocs }
	kWindowDocumentDefProcResID = 64;
	kWindowDialogDefProcResID = 65;
	kWindowUtilityDefProcResID = 66;
	kWindowUtilitySideTitleDefProcResID = 67;
	kWindowSheetDefProcResID = 68;
	kWindowSimpleDefProcResID = 69;
	kWindowSheetAlertDefProcResID = 70;

const
{ Proc IDs for theme-savvy windows }
	kWindowDocumentProc = 1024;
	kWindowGrowDocumentProc = 1025;
	kWindowVertZoomDocumentProc = 1026;
	kWindowVertZoomGrowDocumentProc = 1027;
	kWindowHorizZoomDocumentProc = 1028;
	kWindowHorizZoomGrowDocumentProc = 1029;
	kWindowFullZoomDocumentProc = 1030;
	kWindowFullZoomGrowDocumentProc = 1031;


const
{ Proc IDs for theme-savvy dialogs }
	kWindowPlainDialogProc = 1040;
	kWindowShadowDialogProc = 1041;
	kWindowModalDialogProc = 1042;
	kWindowMovableModalDialogProc = 1043;
	kWindowAlertProc = 1044;
	kWindowMovableAlertProc = 1045;


const
{ procIDs available from Mac OS 8.1 (Appearance 1.0.1) forward }
	kWindowMovableModalGrowProc = 1046;


const
{ Proc IDs for top title bar theme-savvy floating windows }
	kWindowFloatProc = 1057;
	kWindowFloatGrowProc = 1059;
	kWindowFloatVertZoomProc = 1061;
	kWindowFloatVertZoomGrowProc = 1063;
	kWindowFloatHorizZoomProc = 1065;
	kWindowFloatHorizZoomGrowProc = 1067;
	kWindowFloatFullZoomProc = 1069;
	kWindowFloatFullZoomGrowProc = 1071;


const
{ Proc IDs for side title bar theme-savvy floating windows }
	kWindowFloatSideProc = 1073;
	kWindowFloatSideGrowProc = 1075;
	kWindowFloatSideVertZoomProc = 1077;
	kWindowFloatSideVertZoomGrowProc = 1079;
	kWindowFloatSideHorizZoomProc = 1081;
	kWindowFloatSideHorizZoomGrowProc = 1083;
	kWindowFloatSideFullZoomProc = 1085;
	kWindowFloatSideFullZoomGrowProc = 1087;


const
{ Proc IDs for sheet windows }
	kWindowSheetProc = 1088; { available in Mac OS X and CarbonLib 1.3 }
	kWindowSheetAlertProc = 1120;  { available in Mac OS X 10.1 and CarbonLib 1.3 }


{
 *  Discussion:
 *    Window defproc IDs for simple windows
 }
const
{ Proc IDs for simple windows }

  {
   * A window that has no structure region; the content covers the
   * entire window.
   }
	kWindowSimpleProc = 1104;

  {
   * A window that has a 1-pixel black frame as its structure.
   }
	kWindowSimpleFrameProc = 1105;


{
 *  Discussion:
 *    More window defproc IDs.
 }
const
{
   * Window defproc ID for overlay-class windows.
   }
	kWindowOverlayProc = 1136;

{——————————————————————————————————————————————————————————————————————————————————————}
{ • System 7 Window Positioning Constants                                              }
{ Passed into StandardAlert and used in ‘WIND’, ‘DLOG’, and ‘ALRT’ templates           }
{ StandardAlert uses zero to specify the default position. Other calls use zero to     }
{ specify “no position”.  Do not pass these constants to RepositionWindow.  Do not     }
{ store these constants in the BasicWindowDescription of a ‘wind’ resource.            }
{——————————————————————————————————————————————————————————————————————————————————————}

const
	kWindowNoPosition = $0000;
	kWindowDefaultPosition = $0000; { used by StandardAlert}
	kWindowCenterMainScreen = $280A;
	kWindowAlertPositionMainScreen = $300A;
	kWindowStaggerMainScreen = $380A;
	kWindowCenterParentWindow = $A80A;
	kWindowAlertPositionParentWindow = $B00A;
	kWindowStaggerParentWindow = $B80A;
	kWindowCenterParentWindowScreen = $680A;
	kWindowAlertPositionParentWindowScreen = $700A;
	kWindowStaggerParentWindowScreen = $780A;

{——————————————————————————————————————————————————————————————————————————————————————}
{ • Window Positioning Methods                                                         }
{ Positioning methods passed to RepositionWindow.                                      }
{ Do not use them in WIND, ALRT, DLOG templates.                                       }
{ Do not confuse these constants with the constants above                              }
{——————————————————————————————————————————————————————————————————————————————————————}

{
 *  WindowPositionMethod
 *
 *  Summary:
 *    Positioning methods usable with RepositionWindow.
 *
 *  Discussion:
 *    These constants are for use solely with the RepositionWindow API.
 *    They should not be used in 'WIND', 'ALRT', or 'DLOG' resources.
 }
type
	WindowPositionMethod = UInt32;
	WindowPositionMethod_fix = WindowPositionMethod; { used as field type when a record declaration contains a WindowPositionMethod field identifier }
const
{
   * Centers the window on the main screen.
   }
	kWindowCenterOnMainScreen = 1;

  {
   * Centers the window on its parent window. The parent window must be
   * different from the positioned window.
   }
	kWindowCenterOnParentWindow = 2;

  {
   * Centers the window on the screen containing the largest portion of
   * its parent window. On Mac OS X 10.3 and later, the parent window
   * may be the same as the positioned window. On CarbonLib and earlier
   * versions of Mac OS X, the parent window must be different from the
   * positioned window.
   }
	kWindowCenterOnParentWindowScreen = 3;

  {
   * Cascades the window on the main screen.
   }
	kWindowCascadeOnMainScreen = 4;

  {
   * Cascades the window on its parent window. The parent window must
   * be different from the positioned window.
   }
	kWindowCascadeOnParentWindow = 5;

  {
   * Cascades the window on the screen containing the largest portion
   * of its parent window. On Mac OS X 10.3 and later, the parent
   * window may be the same as the positioned window. On CarbonLib and
   * earlier versions of Mac OS X, the parent window must be different
   * from the positioned window.
   }
	kWindowCascadeOnParentWindowScreen = 6;

  {
   * Cascades the window on the screen containing the largest portion
   * of its parent window, starting below and to the right of its
   * parent window. The parent window must be different from the
   * positioned window. Available in Mac OS X 10.2 and CarbonLib 1.6
   * and later.
   }
	kWindowCascadeStartAtParentWindowScreen = 10;

  {
   * Puts the window into the alert position on the main screen.
   }
	kWindowAlertPositionOnMainScreen = 7;

  {
   * Puts the window into the alert position on its parent window. The
   * parent window must be different from the positioned window.
   }
	kWindowAlertPositionOnParentWindow = 8;

  {
   * Puts the window into the alert position on the screen containing
   * the largest portion of its parent window. On Mac OS X 10.3 and
   * later, the parent window may be the same as the positioned window.
   * On CarbonLib and earlier versions of Mac OS X, the parent window
   * must be different from the positioned window.
   }
	kWindowAlertPositionOnParentWindowScreen = 9;


{——————————————————————————————————————————————————————————————————————————————————————}
{ • GetWindowRegion Types                                                              }
{——————————————————————————————————————————————————————————————————————————————————————}
type
	WindowRegionCode = UInt16;
const
{ Region values to pass into GetWindowRegion & GetWindowBounds. All regions are reported in global coordinates. }
	kWindowTitleBarRgn = 0;
	kWindowTitleTextRgn = 1;
	kWindowCloseBoxRgn = 2;
	kWindowZoomBoxRgn = 3;
	kWindowDragRgn = 5;
	kWindowGrowRgn = 6;
	kWindowCollapseBoxRgn = 7;
	kWindowTitleProxyIconRgn = 8;    { Mac OS 8.5 forward}
	kWindowStructureRgn = 32;
	kWindowContentRgn = 33;   { Content area of the window; empty when the window is collapsed}
	kWindowUpdateRgn = 34;   { Carbon forward}
	kWindowOpaqueRgn = 35;   { Mac OS X: Area of window considered to be opaque. Only valid for windows with alpha channels.}
	kWindowGlobalPortRgn = 40;   { Carbon forward - bounds of the window’s port in global coordinates; not affected by CollapseWindow}
	kWindowToolbarButtonRgn = 41;    { Mac OS X Tiger: the toolbar button area}


{——————————————————————————————————————————————————————————————————————————————————————}
{ • Standard Window Kinds                                                              }
{——————————————————————————————————————————————————————————————————————————————————————}
const
	dialogKind = 2;
	userKind = 8;
	kDialogWindowKind = 2;
	kApplicationWindowKind = 8;


{——————————————————————————————————————————————————————————————————————————————————————}
{ • FindWindow Result Codes                                                            }
{——————————————————————————————————————————————————————————————————————————————————————}
type
	WindowPartCode = SInt16;
	WindowPartCodePtr = ^WindowPartCode; { when a VAR xx: WindowPartCode parameter can be nil, it is changed to xx: WindowPartCodePtr }
const
	inDesk = 0;
	inNoWindow = 0;
	inMenuBar = 1;
	inSysWindow = 2;
	inContent = 3;
	inDrag = 4;
	inGrow = 5;
	inGoAway = 6;
	inZoomIn = 7;
	inZoomOut = 8;
	inCollapseBox = 11;   { Mac OS 8.0 forward}
	inProxyIcon = 12;   { Mac OS 8.5 forward}
	inToolbarButton = 13;   { Mac OS X forward}
	inStructure = 15;    { Mac OS X 10.1 forward}

{——————————————————————————————————————————————————————————————————————————————————————}
{ • Window Definition Hit Test Result Codes                                            }
{——————————————————————————————————————————————————————————————————————————————————————}
type
	WindowDefPartCode = SInt16;
const
	wNoHit = 0;
	wInContent = 1;
	wInDrag = 2;
	wInGrow = 3;
	wInGoAway = 4;
	wInZoomIn = 5;
	wInZoomOut = 6;
	wInCollapseBox = 9;    { Mac OS 8.0 forward}
	wInProxyIcon = 10;   { Mac OS 8.5 forward}
	wInToolbarButton = 11;   { Mac OS X forward}
	wInStructure = 13;    { Mac OS X 10.1 forward}

{——————————————————————————————————————————————————————————————————————————————————————}
{ • Window Feature Bits                                                                }
{——————————————————————————————————————————————————————————————————————————————————————}

{
 *  Summary:
 *    Window feature bits
 *
 *  Discussion:
 *    These feature bits are supplied by window definition functions in
 *    response to the kWindowMsgGetFeatures message or the
 *    kEventWindowInit Carbon event. A window's feature bits can also
 *    be modified dynamically using the HIWindowChangeFeatures API;
 *    typically, feature bits are only modified by a window definition
 *    or window frame view.
 }
const
{
   * Indicates whether the window is resizable. Available on Mac OS 8.0
   * and later. Not supported on Mac OS X; replaced by
   * kWindowResizableAttribute.
   }
	kWindowCanGrow = 1 shl 0;

  {
   * Indicates whether the window can zoom. Available on Mac OS 8.0 and
   * later. Not supported on Mac OS X; replaced by
   * kWindowHorizontal/Vertical/FullZoomAttribute.
   }
	kWindowCanZoom = 1 shl 1;

  {
   * Indicates whether the window can be minimized. Available on Mac OS
   * 8.0 and later. Not supported on Mac OS X; replaced by
   * kWindowCollapseBoxAttribute.
   }
	kWindowCanCollapse = 1 shl 2;

  {
   * Indicates whether the window is application-modal. Available on
   * Mac OS 8.0 and later.
   }
	kWindowIsModal = 1 shl 3;

  {
   * Indicates that the window definition supports the
   * kWindowMsgGetRegion message. Available on Mac OS 8.0 and later.
   * Not supported on Mac OS X. All window definitions that implement
   * the kWindowMsgGetFeatures message automatically get this feature
   * bit on Mac OS X.
   }
	kWindowCanGetWindowRegion = 1 shl 4;

  {
   * Indicates whether the window is an alert. Available on Mac OS 8.0
   * and later.
   }
	kWindowIsAlert = 1 shl 5;

  {
   * Indicates whether the window has a title bar. Available on Mac OS
   * 8.0 and later. This feature is required for async dragging to be
   * enabled for a window.
   }
	kWindowHasTitleBar = 1 shl 6;

  {
   * Indicates that the window definition supports the
   * kWindowMsgDragHilite message. Available on Mac OS 8.5 and later.
   }
	kWindowSupportsDragHilite = 1 shl 7;

  {
   * Indicates that the window definition supports the
   * kWindowMsgModified message. Available on Mac OS 8.5 and later.
   }
	kWindowSupportsModifiedBit = 1 shl 8;

  {
   * Indicates that the window definition supports the
   * kWindowMsgDrawInCurrentPort message. Available on Mac OS 8.5 and
   * later. Not supported on Mac OS X.
   }
	kWindowCanDrawInCurrentPort = 1 shl 9;

  {
   * Indicates that the window definition supports the
   * kWindowMsgSetupProxyDragImage message. Available on Mac OS 8.5 and
   * later.
   }
	kWindowCanSetupProxyDragImage = 1 shl 10;

  {
   * Indicates that the window definition supports the
   * kWindowMsgMeasureTitle message. Available on Mac OS 8.5 and later.
   }
	kWindowCanMeasureTitle = 1 shl 11;

  {
   * Indicates that the window definition wants to receive a
   * kWindowMsgCleanUp message for each existing window when a process
   * is terminated. Available on Mac OS 8.5 and later. Not supported on
   * Mac OS X.
   }
	kWindowWantsDisposeAtProcessDeath = 1 shl 12;

  {
   * Indicates that the window definition supports the
   * kWindowMsgGetGrowImageRegion message. Available on Mac OS X 10.0
   * and later.
   }
	kWindowSupportsGetGrowImageRegion = 1 shl 13;

  {
   * Indicates that the window is entirely opaque. If this feature bit
   * is set, the window will use less memory because no alpha channel
   * information will be stored for the window's pixels. If this
   * feature bit is not set, the Window Manager will send a
   * kEventWindowGetRegion Carbon event to the window with the
   * kWindowOpaqueRgn constant to get a region that describes the
   * opaque area of the window. Available on Mac OS X 10.1 and later.
   }
	kWindowIsOpaque = 1 shl 14;

  {
   * Indicates that the window definition does not require that the
   * current port be the classic Window Manager port. Not supported on
   * Mac OS X.
   }
	kWindowDefSupportsColorGrafPort = $40000002;

{——————————————————————————————————————————————————————————————————————————————————————}
{  • Region Dragging Constants                                                         }
{——————————————————————————————————————————————————————————————————————————————————————}
const
	kMouseUpOutOfSlop = $80008000;


{——————————————————————————————————————————————————————————————————————————————————————}
{ • Window Class Ordering                                                              }
{  Special cases for the “behind” parameter in window creation calls.                  }
{——————————————————————————————————————————————————————————————————————————————————————}
	kFirstWindowOfClass = WindowRef(-1);
	kLastWindowOfClass = WindowRef(0);

{——————————————————————————————————————————————————————————————————————————————————————}
{ • Zoom Information Handle                                                            }
{——————————————————————————————————————————————————————————————————————————————————————}
type
	WStateData = record
		userState: Rect;              {user zoom state}
		stdState: Rect;               {standard zoom state}
	end;
	WStateDataPtr = ^WStateData;
type
	WStateDataHandle = ^WStateDataPtr;
{——————————————————————————————————————————————————————————————————————————————————————}
{ • Window definition function                                                         }
{——————————————————————————————————————————————————————————————————————————————————————}
type
  WindowDefProcPtr = UnivPtr;
	WindowDefUPP = WindowDefProcPtr;

{——————————————————————————————————————————————————————————————————————————————————————}
{ • Window Definition Spec.  Used in Carbon to specify the code that defines a window. }
{——————————————————————————————————————————————————————————————————————————————————————}
const
	kWindowDefProcPtr = 0;    { raw proc-ptr based access}
	kWindowDefObjectClass = 1;    { event-based definition using a ToolboxObjectClassRef (Carbon 1.1 or later)}
	kWindowDefProcID = 2;    { explicit proc ID; overrides the window class default proc ID}
	kWindowDefHIView = 3;     { this window uses an HIView as its frame, not a WDEF}

type
	WindowDefType = UInt32;
	WindowDefSpec = record
		defType: WindowDefType;
		case SInt16 of
		0: (
			defProc: WindowDefUPP;
			);
		1: (
			classRef: UnivPtr;             { ToolboxObjectClassRef}
			);
		2: (
			procID: SInt16;
			);
		3: (
			rootView: UnivPtr;             { HIViewRef}
			);
	end;
	WindowDefSpecPtr = ^WindowDefSpec;
{——————————————————————————————————————————————————————————————————————————————————————}
{ • Window Creation & Persistence                                                      }
{——————————————————————————————————————————————————————————————————————————————————————}
{
    About Window Manager Coordinate Spaces

    All Window Manager API that takes a size, position, or rectangle for input, and does not take an
    HICoordinateSpace parameter, expects that its input parameters are given in the 72DPIGlobal coordinate
    space. Likewise, any API that returns a rect or region and that does not take an HICoordinateSpace
    parameter will provide its output in the 72DPIGlobal coordinate space.

    We expect that most developers will want to work primarily in the 72DPIGlobal space. Doing so makes
    your code independent of the current user interface scale factor, and eases source compatibility with
    earlier versions of Mac OS X that do not support resolution independence. However, there are also certain
    cases where your application must express your window's bounds in pixel coordinates; primarily when you
    need to position your windows so they exactly align with each other or with some other fixed location,
    such as the edge of the display. For these cases, you should use the ScreenPixel coordinate space.

    Note that non-integral pixel coordinates are not available in Mac OS X. If you specify non-integral
    coordinates (in either 72DPIGlobal or ScreenPixel coordinate spaces), they will be rounded to the nearest
    integral value in ScreenPixel space when the window is actually positioned or sized.
}



{
 *  Summary:
 *    Window backing buffer location constants are used with the
 *    HIWindowGet/SetBackingLocation APIs.
 }
const
{
   * The window server determines where to locate the window's backing
   * buffer.
   }
	kHIWindowBackingLocationDefault = 0;

  {
   * The window's backing buffer is stored in video memory. In this
   * case, only Quartz may be used to draw into the window. Use of
   * QuickDraw or direct access will force the window's buffer back
   * into main memory.
   }
	kHIWindowBackingLocationVideoMemory = 1;

  {
   * The window's backing buffer is stored in main memory. In this
   * case, Quartz, QuickDraw, and direct access are all allowed for
   * drawing into the window.
   }
	kHIWindowBackingLocationMainMemory = 2;

type
	HIWindowBackingLocation = UInt32;
	HIWindowBackingLocationPtr = ^HIWindowBackingLocation;


{
 *  Summary:
 *    Window sharing constants are used with the
 *    HIWindowGet/SetSharingType APIs.
 }
const
{
   * Window contents may not be read by another process.
   }
	kHIWindowSharingNone = 0;

  {
   * Window contents may be read but not modified by another process.
   }
	kHIWindowSharingReadOnly = 1;

  {
   * Window contents may be read or modified by another process.
   }
	kHIWindowSharingReadWrite = 2;

type
	HIWindowSharingType = UInt32;


{
 *  WindowModality
 *
 }
type
	WindowModality = UInt32;
const
{
   * A window does not prevent interaction with any other window in the
   * system.
   }
	kWindowModalityNone = 0;

  {
   * A window prevents interaction with all other windows in the
   * system. Only available in CarbonLib. Mapped to
   * kWindowModalityAppModal in Mac OS X.
   }
	kWindowModalitySystemModal = 1;

  {
   * A window prevents interaction with other windows in the same
   * process.
   }
	kWindowModalityAppModal = 2;

  {
   * A window prevents interaction with a single other window.
   }
	kWindowModalityWindowModal = 3;



type
	WindowGroupRef = ^OpaqueWindowGroupRef; { an opaque type }
	OpaqueWindowGroupRef = record end;
	WindowGroupRefPtr = ^WindowGroupRef;  { when a var xx:WindowGroupRef parameter can be nil, it is changed to xx: WindowGroupRefPtr }
{ may be passed as the "behindWindow" parameter to NewCWindow and SendBehind}
const
{ may be passed as the "behindWindow" parameter to NewCWindow and SendBehind}
	kFirstWindowOfGroup = WindowRef(-1);
	kLastWindowOfGroup = nil;
{ may be passed as the "behindGroup" parameter to SendWindowGroupBehind}
	kFirstWindowGroup = WindowGroupRef(-1);
	kLastWindowGroup = nil;

{
 *  WindowGroupAttributes
 *
 *  Summary:
 *    These are attributes that may be applied to a window group.
 }
type
	WindowGroupAttributes = UInt32;
const
{
   * Makes the group behave somewhat as a layer of windows that move
   * together. When any window in the group is brought to the front of
   * the group, the entire group will also be brought to the front of
   * the containing group's child hierarchy.
   }
	kWindowGroupAttrSelectAsLayer = 1 shl 0;

  {
   * The positions of the contents of this group with respect to each
   * other cannot be changed. When one item moves, all other items are
   * moved simultaneously. Note that when one window in the group is
   * moved, the bounds of the other windows in the group may be updated
   * asynchronously.
   }
	kWindowGroupAttrMoveTogether = 1 shl 1;

  {
   * The z-order of the contents of this group with respect to each
   * other cannot be changed. When one item changes z-order, all other
   * items are moved simultaneously. For purposes of z-ordering, the
   * group and all its subgroups are effectively treated as if they
   * were a single window in the parent group of this group.
   }
	kWindowGroupAttrLayerTogether = 1 shl 2;

  {
   * The active state of the windows in this group is shared. The
   * windows in the group are activated or deactivated according to the
   * activation scope of the group, but when any window in the group
   * changes activation, all other windows change to match.
   }
	kWindowGroupAttrSharedActivation = 1 shl 3;

  {
   * When any window in this group is collapsed, all other windows in
   * this group are hidden. All subgroups of this group are also
   * examined for the HideOnCollapse attribute, and any windows of any
   * subgroup with this attribute are also hidden. All windows will be
   * shown again when the collapsed window is expanded.
   }
	kWindowGroupAttrHideOnCollapse = 1 shl 4;

  {
   * This window group's window level should be left unchanged. If this
   * attribute is not specified, this window group's window level will
   * be promoted to a value equal to the level of the next FixedLevel
   * window group beneath it in the window group hierarchy.
   }
	kWindowGroupAttrFixedLevel = 1 shl 5;


{
 *  WindowActivationScope
 *
 *  Discussion:
 *    Every window has a WindowActivationScope. It defines how windows
 *    are activated by the Window Manager with respect to other windows
 *    in the window’s group and in the current process.
 }
type
	WindowActivationScope = UInt32;
const
{
   * Windows with this scope are never activated by the Window Manager.
   * This should be used when the window’s visual state does not change
   * based on activation (for example, tooltip windows), or when the
   * client wishes to manually control all activation. The window owner
   * is free to explicitly activate or deactivate windows using the
   * ActivateWindow API.
   }
	kWindowActivationScopeNone = 0;

  {
   * Windows with this scope are always active if visible. Windows with
   * this scope are unaffected by the activation state of other
   * windows. This activation scope is automatically used by floating
   * windows.
   }
	kWindowActivationScopeIndependent = 1;

  {
   * Windows with this scope are activated relative to other windows
   * with the same scope in the current process. Only one window with
   * this scope can be active in the entire process. This activation
   * scope is automatically used by document and dialog windows.
   }
	kWindowActivationScopeAll = 2;


{
 *  Summary:
 *    These are constants that can be used for the inNextGroup
 *    parameter to GetWindowGroupSibling.
 }
const
{
   * Indicates that GetWindowGroupSibling should return the next deeper
   * sibling group in the z-order.
   }
	kNextWindowGroup = true;

  {
   * Indicates that GetWindowGroupSibling should return the next higher
   * sibling group in the z-order.
   }
	kPreviousWindowGroup = false;


{
 *  WindowGroupContentOptions
 *
 *  Discussion:
 *    Window group contents options are used to control what group
 *    content is counted or returned by the CountWindowGroupContents
 *    and GetWindowGroupContents APIs.
 }
type
	WindowGroupContentOptions = UInt32;
const
{
   * Indicates that Count/GetWindowGroupContents should return the
   * windows in a group. If this option is not set, these APIs return
   * the groups in a group.
   }
	kWindowGroupContentsReturnWindows = 1 shl 0;

  {
   * Indicates that Count/GetWindowGroupContents should include the
   * contents of groups contained by the specified group. If this
   * option is not set, these APIs only return information about the
   * specified group’s contents.
   }
	kWindowGroupContentsRecurse = 1 shl 1;

  {
   * Indicates that Count/GetWindowGroupContents should only include
   * visible windows. Only valid when kWindowGroupContentsReturnWindows
   * is specified.
   }
	kWindowGroupContentsVisible = 1 shl 2;


{----------------------------------------------------------------------------------}
{  • Group creation, destruction, and refcounting                                  }
{----------------------------------------------------------------------------------}


{
 *  Summary:
 *    Parameters to GetWindowGroupLevelOfType and
 *    SetWindowGroupLevelOfType
 }
const
{
   * The window level that is nominally used for windows in the group
   * when the application is active. However, if a group with a higher
   * window level is positioned below group in the window group
   * hierarchy, this group's active level will be promoted to match the
   * level of the group in front of it. You can determine the actual
   * window level in use for a group using the
   * kWindowGroupLevelPromoted constant.
   }
	kWindowGroupLevelActive = 1;

  {
   * The window level that is used for windows in the group when the
   * application is inactive.
   }
	kWindowGroupLevelInactive = 2;

  {
   * The window level that is actually used for windows in the group
   * when the application is active. This level will either be the same
   * as the Active window level, or will be a larger value to match the
   * level of a group below this group.
   *
   * We do not recommend setting the Promoted window level explicitly,
   * because the promoted level is reset by the Window Manager whenever
   * the window group hierarchy structure changes, and therefore any
   * changes that you may make to the promoted level can be
   * overwritten. In general you should only use this API to set the
   * Active and Inactive window levels.
   }
	kWindowGroupLevelPromoted = 3;


const kUserFocusAuto = WindowRef(-1);


{
 *  Summary:
 *    Window backing store depth types.
 }
const
{
   * The window is invalid or its backing store pixel size is unknown.
   }
	kHIWindowDepthInvalid = 0;

  {
   * The window's backing store pixel size should be 32 bits.
   }
	kHIWindowDepth32Bit = 1;

  {
   * The window's backing store pixel size should be 64 bits.
   }
	kHIWindowDepth64Bit = 2;

  {
   * The window's backing store pixel size should be the size of a
   * float.
   }
	kHIWindowDepthFloat = 3;

type
	HIWindowDepth = UInt32;

type
	ScrollWindowOptions = UInt32;
const
	kScrollWindowNoOptions = 0;
	kScrollWindowInvalidate = 1 shl 0; { add the exposed area to the window’s update region}
	kScrollWindowEraseToPortBackground = 1 shl 1; { erase the exposed area using the background color/pattern of the window’s grafport}


{ Routines available from Mac OS 8.1 forward when linking to CarbonLib 1.0 forward}



{
 *  Summary:
 *    Options for the HIWindowFindAtLocation API.
 }
const
{
   * Requests that HIWindowFindAtLocation ignore windows of other
   * processes which might obscure your process's windows. That is, if
   * a window in your process is at the specified point, it will be
   * passed back even if some other process's window obscures it.
   }
	kHIWindowIgnoreObscuringWindows = 1 shl 0;



{
 *  Summary:
 *    Options for the CreateStandardWindowMenu API.
 }
const
{
   * Requests the standard window menu include a Rotate Windows menu
   * item. Available in Mac OS X 10.2.
   }
	kWindowMenuIncludeRotate = 1 shl 0;


{
 *  Summary:
 *    Constants for use with Get/SetMenuItemProperty to access property
 *    data of items in the standard window menu. These constants are
 *    supported on Mac OS X 10.5 and later.
 }
const
{
   * The property creator for accessing standard window menu item
   * properties.
   }
	kHIWindowMenuCreator = FourCharCode('wind');

  {
   * The property tag for accessing standard window menu item
   * properties that hold WindowRefs. Menu items with the
   * kHICommandSelectWindow command ID will have a property with this
   * tag that contains the WindowRef to be activated when that item is
   * selected. Available in Mac OS X 10.5 and later.
   }
	kHIWindowMenuWindowTag = FourCharCode('wind');



{
 *  WindowTransitionEffect
 *
 *  Summary:
 *    Visual effects that are provided by TransitionWindow
 }
type
	WindowTransitionEffect = UInt32;
const
{
   * Finder-like zoom rectangles. Use with TransitionWindow and Show or
   * Hide transition actions. In Mac OS X 10.7 and later, this effect
   * can also be used with the Resize transition action to show the
   * standard animation effect for zooming a window to a new size. The
   * combination of the Zoom effect and the Resize action is only
   * recommended for use with compositing windows.
   }
	kWindowZoomTransitionEffect = 1;

  {
   * Zoom in/out from parent. Use with TransitionWindowAndParent and
   * Show or Hide transition actions. Available in Mac OS X, and in
   * CarbonLib 1.5 and later.
   }
	kWindowSheetTransitionEffect = 2;

  {
   * Slide the window into its new position. Use with TransitionWindow
   * and Move or Resize transition actions. Available in Mac OS X, and
   * in CarbonLib 1.5 and later.
   }
	kWindowSlideTransitionEffect = 3;

  {
   * Fade the window into or out of visibility. Use with the Show or
   * Hide transition actions. Available in Mac OS X 10.3 and later.
   }
	kWindowFadeTransitionEffect = 4;

  {
   * Use the Genie effect that the Dock uses to minimize or maximize a
   * window to show or hide the window. Use with the Show or Hide
   * transition actions. Available in Mac OS X 10.3 and later.
   }
	kWindowGenieTransitionEffect = 5;


{
 *  WindowTransitionAction
 *
 *  Summary:
 *    Modifications to window state that are provided by
 *    TransitionWindow
 }
type
	WindowTransitionAction = UInt32;
const
{
   * Shows the window. Use with the Zoom, Sheet, Fade, or Genie
   * transition effects. For the Zoom, Sheet, and Genie effects, the
   * inRect parameter is the global coordinates from which to start the
   * animation; inRect may be NULL for the Zoom and Sheet effects, and
   * in that case, the animation begins at the center of the window.
   * The Genie effect requires a non-NULL inRect parameter. The Fade
   * effect does not use the inRect parameter.
   }
	kWindowShowTransitionAction = 1;

  {
   * Hides the window. Use with the Zoom, Sheet, Fade, or Genie
   * transition effects. For the Zoom, Sheet, and Genie effects, the
   * inRect parameter is the global coordinates at which to end the
   * animation; inRect may be NULL for the Zoom and Sheet effects, and
   * in that case, the animation ends at the center of the window. The
   * Genie effect requires a non-NULL inRect parameter. The Fade effect
   * does not use the inRect parameter.
   }
	kWindowHideTransitionAction = 2;

  {
   * Moves the window. Use with the Slide transition effect. The inRect
   * parameter is the global coordinates of the window's new structure
   * bounds; inRect must be non-NULL. Available in Mac OS X, and in
   * CarbonLib 1.5 and later.
   }
	kWindowMoveTransitionAction = 3;

  {
   * Resizes the window. Use with the Slide transition effect. In Mac
   * OS X 10.7 and later, the Zoom transition effect is also supported
   * with this action, for use by applications that respond to a zoom
   * box click by resizing the window programmatically without calling
   * the ZoomWindow or ZoomWindowIdeal APIs. The inRect parameter is
   * the global coordinates of the window's new structure bounds;
   * inRect must be non-NULL. Available in Mac OS X, and in CarbonLib
   * 1.5 and later.
   }
	kWindowResizeTransitionAction = 4;



{
 *  TransitionWindowOptions
 *
 *  Summary:
 *    Extensible parameter block for the TransitionWindowWithOptions
 *    API.
 }
type
	TransitionWindowOptions = record
{
   * The structure version. You must put 0 in this field.
   }
		version: UInt32;

  {
   * The duration of the fade, in seconds. For use with the Sheet,
   * Slide, Fade, and Genie transition effects; ignored for other
   * effects. You may pass 0 to use the default duration. The effect is
   * not guaranteed to last precisely this long, but should be a close
   * approximation.
   }
		duration: EventTime;

  {
   * For use with kWindowSheetTransitionEffect. This is the parent
   * window of the sheet.
   }
		window: WindowRef;

  {
   * This value will be sent as the kEventParamUserData parameter for
   * the kEventWindowTransitionStarted and
   * kEventWindowTransitionCompleted events.
   }
		userData: UnivPtr;
	end;
	TransitionWindowOptionsPtr = ^TransitionWindowOptions;


{
 *  WindowConstrainOptions
 *
 }
type
	WindowConstrainOptions = UInt32;
const
{
   * The window may be resized if necessary to make it fit onscreen.
   }
	kWindowConstrainMayResize = 1 shl 0;

  {
   * The window will be moved even if it doesn't fit entirely onscreen.
   }
	kWindowConstrainMoveRegardlessOfFit = 1 shl 1;

  {
   * Allow partial intersection of the specified window region with the
   * screen, instead of requiring total intersection.
   }
	kWindowConstrainAllowPartial = 1 shl 2;

  {
   * Only calculate the new window bounds; don't actually move the
   * window.
   }
	kWindowConstrainCalcOnly = 1 shl 3;

  {
   * Use TransitionWindow with kWindowSlideTransitionEffect to move
   * windows onscreen. Available in Mac OS X 10.2.
   }
	kWindowConstrainUseTransitionWindow = 1 shl 4;

  {
   * Requests that the window be moved the minimum amount necessary to
   * be onscreen. This option applies if a partial fit is not allowed
   * (kWindowConstrainAllowPartial is not specified) or a partial fit
   * is allowed, but the window is not even partially visible. In
   * either case, the window will be moved just enough to be slightly
   * onscreen. You may customize the minimum amount that is required to
   * be visible by passing the desired dimensions in the inMinimumSize
   * parameter to HIWindowConstrain.
   }
	kWindowConstrainMoveMinimum = 1 shl 6;

  {
   * Requests that when determining the bounds of the window region to
   * be constrained, rather than getting the current bounds of the
   * specified region, the Window Manager should use the bounds
   * provided in the ioBounds parameter to HIWindowConstrain. This
   * allows your application to constrain a window to a hypothetical
   * location; for example, if you plan to move your window such that
   * its content rect is at a certain location, and you want to know in
   * advance before moving the window whether the window would be
   * offscreen at that location, you can use this option.
   }
	kWindowConstrainUseSpecifiedBounds = 1 shl 8;

  {
   * The most common options: don't resize the window, move the window
   * regardless of fit to the screen, require total intersection of the
   * specified window region with the screen, and do actually move the
   * window.
   }
	kWindowConstrainStandardOptions = kWindowConstrainMoveRegardlessOfFit;



{
 *  WindowLatentVisibility
 *
 *  Summary:
 *    Reasons why a window is currently invisible when ordinarily it
 *    would be visible.
 }
type
	WindowLatentVisibility = UInt32;
	WindowLatentVisibilityPtr = ^WindowLatentVisibility;
const
{
   * Window is a floater and floating windows are hidden
   }
	kWindowLatentVisibleFloater = 1 shl 0;

  {
   * Window has HideOnSuspend and we are suspended
   }
	kWindowLatentVisibleSuspend = 1 shl 1;

  {
   * Window has HideOnFullScreen and we are full-screen
   }
	kWindowLatentVisibleFullScreen = 1 shl 2;

  {
   * Window's process is hidden
   }
	kWindowLatentVisibleAppHidden = 1 shl 3;

  {
   * Window is in an owned group and the owner was collapsed
   }
	kWindowLatentVisibleCollapsedOwner = 1 shl 4;

  {
   * Window is in a HideOnCollapse group and another window in the
   * group was collapsed
   }
	kWindowLatentVisibleCollapsedGroup = 1 shl 5;



{
 *  Summary:
 *    Window availability options for Exposé and Spaces.
 *
 *  Discussion:
 *    These options are used with the HIWindowGet/ChangeAvailability
 *    APIs to override the default behavior of a window in Exposé and
 *    Spaces. Most applications should not override the default
 *    behavior; these options should only be used in special cases. By
 *    default, newly created windows of class kDocumentWindowClass are
 *    given an availability of zero (meaning that they are available
 *    during Exposé, and are only visible in the Space in which they
 *    were created), and windows from all other window classes are
 *    given an availability of kHIWindowExposeHidden.
 }
const
{
   * This window is hidden during Exposé’s “All windows” and
   * “Application windows” modes, and during the Spaces overview mode.
   * It moves to the current space automatically after a space switch,
   * and does not trigger a space switch when dragged to a space
   * boundary. If this bit is not set, the window is visible during
   * Exposé and Spaces.
   }
	kHIWindowBehaviorTransient = 1 shl 0;

  {
   * This window is visible during Exposé’s “All windows” and
   * “Application windows” modes, and does not move. It remains in its
   * original position and, when clicked in "Show desktop" mode,
   * receives the mouse event.
   }
	kHIWindowBehaviorStationary = 1 shl 1;

  {
   * This window is visible in all window sets managed by Spaces. If
   * this bit is not set, the window is only visible in the Space where
   * it was created. This bit and the kHIWindowMoveToActiveSpace bit
   * should not both be set.
   }
	kHIWindowCanJoinAllSpaces = 1 shl 8;

  {
   * When made visible, this window is always shown in the current
   * Space, rather than the space in which it was last visible. When
   * activated, this window moves to the active space, rather than
   * forcing a switch to the Space on which it was previously located.
   * This option is typically used with modeless dialog windows such as
   * the Quick Search window in BBEdit. This bit and the
   * kHIWindowCanJoinAllSpaces bit should not both be set.
   }
	kHIWindowMoveToActiveSpace = 1 shl 9;

  {
   * The original name for the constant kHIWindowBehaviorTransient.
   * Please do not use this name.
   }
	kHIWindowExposeHidden = kHIWindowBehaviorTransient;

  {
   * The original name for the constant kHIWindowCanJoinAllSpaces.
   * Please do not use this name.
   }
	kHIWindowVisibleInAllSpaces = kHIWindowCanJoinAllSpaces;


type
	HIWindowAvailability = OptionBits;


{
 *  Summary:
 *    Indicates the parent window edge on which a drawer will be shown.
 }
const
{
   * This constant is typically used with the OpenDrawer API; it
   * indicates that the drawer should be opened on whatever edge of the
   * parent window has previously been set as the drawer's preferred
   * edge.
   }
	kWindowEdgeDefault = 0;

  {
   * The drawer should open on the top edge of the parent window.
   }
	kWindowEdgeTop = 1 shl 0;

  {
   * The drawer should open on the left edge of the parent window.
   }
	kWindowEdgeLeft = 1 shl 1;

  {
   * The drawer should open on the bottom edge of the parent window.
   }
	kWindowEdgeBottom = 1 shl 2;

  {
   * The drawer should open on the right edge of the parent window.
   }
	kWindowEdgeRight = 1 shl 3;


{
 *  Summary:
 *    Indicates the current state of a drawer window.
 }
const
{
   * The drawer is opening, but is not yet fully open.
   }
	kWindowDrawerOpening = 1;

  {
   * The drawer is fully open.
   }
	kWindowDrawerOpen = 2;

  {
   * The drawer is closing, but is not yet fully closed.
   }
	kWindowDrawerClosing = 3;

  {
   * The drawer is fully closed.
   }
	kWindowDrawerClosed = 4;

type
	WindowDrawerState = UInt32;



{
 *  kWindowOffsetUnchanged
 *
 *  Discussion:
 *    Pass this value to SetDrawerOffsets to indicate that an existing
 *    offset should not be changed.
 }
const
  kWindowOffsetUnchanged = -1.0;


const
{
   * A SetControlData tag that is used by the standard window frame
   * view to inform the toolbar view whether the view should draw its
   * background or leave its background transparent. The data for this
   * tag is a Boolean. If the data value is true, the toolbar view
   * should draw its background as it desires. If the data value is
   * false, the toolbar view should leave its background transparent so
   * that the window's root view can show through the toolbar view.
   * Currently, the toolbar view will be asked to leave its background
   * transparent for windows with the textured or unified appearance.
   }
	kHIToolbarViewDrawBackgroundTag = FourCharCode('back');



{
 *  HIWindowScaleMode
 *
 *  Discussion:
 *    A window's scale mode indicates in which resolution-independent
 *    scale mode it is operating.
 }
type
	HIWindowScaleMode = UInt32;
const
{
   * The window is not scaled at all because the display scale factor
   * is 1.0.
   }
	kHIWindowScaleModeUnscaled = 0;

  {
   * The window's backing store is being magnified by the window server
   * because the display scale factor != 1.0, and because the window
   * was created without kWindowFrameworkScaledAttribute.
   }
	kHIWindowScaleModeMagnified = 1;

  {
   * The window's context has been scaled to match the display scale
   * factor because the display scale factor != 1.0 and because the
   * window was created with kWindowFrameworkScaledAttribute.
   }
	kHIWindowScaleModeFrameworkScaled = 2;



{
 *  HIContentBorderMetrics
 *
 *  Summary:
 *    Describes the border of the content area of the window that will
 *    contain the window frame gradient.
 }
type
	HIContentBorderMetrics = record
{
   * Height of the top of the content border area.
   }
		top: CGFloat;

  {
   * Width of the left of the content border area.
   }
		left: CGFloat;

  {
   * Height of the bottom of the content border area.
   }
		bottom: CGFloat;

  {
   * Width of the right of the content border area.
   }
		right: CGFloat;
	end;

const
	kWindowPropertyPersistent = $00000001; { whether this property gets saved when flattening the window }


{
 *  GetWindowDataHandle()
 *
 *  Availability:
 *    Mac OS X:         not available
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   available as macro/inline
 }


{
 *  SetWindowDataHandle()
 *
 *  Availability:
 *    Mac OS X:         not available
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   available as macro/inline
 }


{
 *  GetWindowZoomFlag()
 *
 *  Availability:
 *    Mac OS X:         not available
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   available as macro/inline
 }


{
 *  GetWindowStructureRgn()
 *
 *  Availability:
 *    Mac OS X:         not available
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   available as macro/inline
 }


{
 *  GetWindowContentRgn()
 *
 *  Availability:
 *    Mac OS X:         not available
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   available as macro/inline
 }


{
 *  GetWindowUpdateRgn()
 *
 *  Availability:
 *    Mac OS X:         not available
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   available as macro/inline
 }


{
 *  GetWindowTitleWidth()
 *
 *  Availability:
 *    Mac OS X:         not available
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   available as macro/inline
 }


{--------------------------------------------------------------------------------------}
{  • DEPRECATED                                                                        }
{  All functions below this point are either deprecated (they continue to function     }
{  but are not the most modern nor most efficient solution to a problem), or they are  }
{  completely unavailable on Mac OS X.                                                 }
{--------------------------------------------------------------------------------------}
{——————————————————————————————————————————————————————————————————————————————————————}
{ • Window Definition Messages                                                         }
{——————————————————————————————————————————————————————————————————————————————————————}
const
	kWindowMsgDraw = 0;
	kWindowMsgHitTest = 1;
	kWindowMsgCalculateShape = 2;
	kWindowMsgInitialize = 3;
	kWindowMsgCleanUp = 4;
	kWindowMsgDrawGrowOutline = 5;
	kWindowMsgDrawGrowBox = 6;

{ Messages available from Mac OS 8.0 forward}
const
	kWindowMsgGetFeatures = 7;
	kWindowMsgGetRegion = 8;

{ Messages available from Mac OS 8.5 forward}
const
	kWindowMsgDragHilite = 9;    { parameter boolean indicating on or off}
	kWindowMsgModified = 10;   { parameter boolean indicating saved (false) or modified (true)}
	kWindowMsgDrawInCurrentPort = 11;   { same as kWindowMsgDraw, but must draw in current port}
	kWindowMsgSetupProxyDragImage = 12;   { parameter pointer to SetupWindowProxyDragImageRec}
	kWindowMsgStateChanged = 13;   { something about the window's state has changed}
	kWindowMsgMeasureTitle = 14;    { measure and return the ideal title width}

{ Messages only available in Carbon}
const
	kWindowMsgGetGrowImageRegion = 19;    { get region to xor during grow/resize. parameter pointer to GetGrowImageRegionRec.}

{ old names}
const
	wDraw = kWindowMsgDraw;
	wHit = kWindowMsgHitTest;
	wCalcRgns = kWindowMsgCalculateShape;
	wNew = kWindowMsgInitialize;
	wDispose = kWindowMsgCleanUp;
	wGrow = kWindowMsgDrawGrowOutline;
	wDrawGIcon = kWindowMsgDrawGrowBox;

{——————————————————————————————————————————————————————————————————————————————————————}
{ • State-changed Flags for kWindowMsgStateChanged                                     }
{——————————————————————————————————————————————————————————————————————————————————————}
const
	kWindowStateTitleChanged = 1 shl 0;

{——————————————————————————————————————————————————————————————————————————————————————}
{ • WDEF Message Types                                                                 }
{——————————————————————————————————————————————————————————————————————————————————————}
{
   SetupWindowProxyDragImageRec - setup the proxy icon drag image
   Both regions are allocated and disposed by the Window Manager.
   The GWorld is disposed of by the Window Manager, but the WDEF must allocate
   it.  See Technote on Drag Manager 1.1 additions for more information and sample code for
   setting up drag images.
}

type
	SetupWindowProxyDragImageRec = record
		imageGWorld: GWorldPtr;            { locked GWorld containing the drag image - output - can be NULL}
		imageRgn: RgnHandle;               { image clip region, contains the portion of the image which gets blitted to screen - preallocated output - if imageGWorld is NULL, this is ignored}
		outlineRgn: RgnHandle;             { the outline region used on shallow monitors - preallocated output - must always be non-empty}
	end;
{ MeasureWindowTitleRec - a pointer to this is passed in WDEF param for kWindowMsgMeasureTitle}
type
	MeasureWindowTitleRec = record
{ output parameters (filled in by the WDEF)}
		fullTitleWidth: SInt16;         { text + proxy icon width}
		titleTextWidth: SInt16;         { text width}

                                              { input parameters}
		isUnicodeTitle: Boolean;
		unused: Boolean;                 { future use}
	end;
	MeasureWindowTitleRecPtr = ^MeasureWindowTitleRec;
{
   GetGrowImageRegionRec - generate a region to be xored during GrowWindow and ResizeWindow.
   This is passed along with a kWindowMsgGetGrowImageRegion message. On input, the growRect
   parameter is the window's new bounds in global coordinates. The growImageRegion parameter
   will be allocated and disposed automatically; the window definition should alter the
   region appropriately.
}
type
	GetGrowImageRegionRecPtr = ^GetGrowImageRegionRec;
	GetGrowImageRegionRec = record
		growRect: Rect;
		growImageRegion: RgnHandle;
	end;
{ GetWindowRegionRec - a pointer to this is passed in WDEF param for kWindowMsgGetRegion}
type
	GetWindowRegionRec = record
		winRgn: RgnHandle;
		regionCode: WindowRegionCode;
	end;
	GetWindowRegionPtr = ^GetWindowRegionRec;
	GetWindowRegionRecPtr = GetWindowRegionPtr;
{——————————————————————————————————————————————————————————————————————————————————————}
{ • Desktop Pattern Resource ID                                                        }
{——————————————————————————————————————————————————————————————————————————————————————}
const
	deskPatID = 16;

{——————————————————————————————————————————————————————————————————————————————————————}
{ • Window Color Part Codes                                                            }
{——————————————————————————————————————————————————————————————————————————————————————}
const
	wContentColor = 0;
	wFrameColor = 1;
	wTextColor = 2;
	wHiliteColor = 3;
	wTitleBarColor = 4;

{——————————————————————————————————————————————————————————————————————————————————————}
{ • Window Color Table                                                                 }
{——————————————————————————————————————————————————————————————————————————————————————}
type
	WinCTabPtr = ^WinCTab;
	WinCTab = record
		wCSeed: SIGNEDLONG;                 { reserved }
		wCReserved: SInt16;             { reserved }
		ctSize: SInt16;                 { usually 4 for windows }
		ctTable: array [0..4] of ColorSpec;
	end;
type
	WCTabPtr = WinCTabPtr;
type
	WCTabHandle = ^WCTabPtr;

{——————————————————————————————————————————————————————————————————————————————————————}
{  • BasicWindowDescription                                                            }
{  Contains statically-sized basic attributes of the window, for storage in a          }
{  collection item.                                                                    }
{——————————————————————————————————————————————————————————————————————————————————————}
{ constants for the version field}
const
	kWindowDefinitionVersionOne = 1;
	kWindowDefinitionVersionTwo = 2;

{ constants for the stateflags bit field }
const
	kWindowIsCollapsedState = 1 shl 0;

type
	BasicWindowDescriptionPtr = ^BasicWindowDescription;
	BasicWindowDescription = record
		descriptionSize: UInt32;        { sizeof(BasicWindowDescription)}

		windowContentRect: Rect;      { location on screen}
		windowZoomRect: Rect;         { location on screen when zoomed out}
		windowRefCon: URefCon;           { the refcon - __avoid saving stale pointers here__  }
		windowStateFlags: UInt32;       { window state bit flags}
		windowPositionMethod: WindowPositionMethod_fix; { method last used by RepositionWindow to position the window (if any)}

		windowDefinitionVersion: UInt32;
		case SInt16 of
		0: (
			windowDefProc: SInt16;      { defProc and variant}
			windowHasCloseBox: Boolean;
		   );
		1: (
			windowClass: WindowClass_fix;        { the class}
			windowAttributes:	WindowAttributes_fix;   { the attributes}
		   );
	end;
{  the window manager stores the default collection items using these IDs}
const
	kStoredWindowSystemTag = FourCharCode('appl'); { Only Apple collection items will be of this tag}
	kStoredBasicWindowDescriptionID = FourCharCode('sbas'); { BasicWindowDescription}
	kStoredWindowPascalTitleID = FourCharCode('s255'); { pascal title string}
	kStoredWindowTitleCFStringID = FourCharCode('cfst'); { CFString title string}


{
 *  DeskHookProcPtr
 *
 *  Summary:
 *    Callback function that handles mouse clicks on the desktop.
 }
type
	DeskHookProcPtr = procedure( mouseClick: Boolean; var theEvent: EventRecord );

{
 *  WindowPaintProcPtr
 *
 *  Summary:
 *    Callback function that paints a window's content area.
 }
type
	WindowPaintProcPtr = function( device: GDHandle; qdContext: GrafPtr; window: WindowRef; inClientPaintRgn: RgnHandle; outSystemPaintRgn: RgnHandle; refCon: UnivPtr ): OSStatus;
	DeskHookUPP = DeskHookProcPtr;
	WindowPaintUPP = WindowPaintProcPtr;
{
 *  NewDeskHookUPP()
 *
 *  Availability:
 *    Mac OS X:         not available
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   available as macro/inline
 }

{
 *  NewWindowPaintUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewWindowPaintUPP( userRoutine: WindowPaintProcPtr ): WindowPaintUPP; external name '_NewWindowPaintUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  DisposeDeskHookUPP()
 *
 *  Availability:
 *    Mac OS X:         not available
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   available as macro/inline
 }

{
 *  DisposeWindowPaintUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeWindowPaintUPP( userUPP: WindowPaintUPP ); external name '_DisposeWindowPaintUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  InvokeDeskHookUPP()
 *
 *  Availability:
 *    Mac OS X:         not available
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   available as macro/inline
 }

{
 *  InvokeWindowPaintUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function InvokeWindowPaintUPP( device: GDHandle; qdContext: GrafPtr; window: WindowRef; inClientPaintRgn: RgnHandle; outSystemPaintRgn: RgnHandle; refCon: UnivPtr; userUPP: WindowPaintUPP ): OSStatus; external name '_InvokeWindowPaintUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)


const
	kWindowPaintProcOptionsNone = 0;


type
	WindowPaintProcOptions = OptionBits;

const
	kWindowGroupAttrSelectable = kWindowGroupAttrSelectAsLayer;
	kWindowGroupAttrPositionFixed = kWindowGroupAttrMoveTogether;
	kWindowGroupAttrZOrderFixed = kWindowGroupAttrLayerTogether;


{$endc} {TARGET_OS_MAC}
{$ifc not defined MACOSALLINCLUDE or not MACOSALLINCLUDE}

end.
{$endc} {not MACOSALLINCLUDE}
