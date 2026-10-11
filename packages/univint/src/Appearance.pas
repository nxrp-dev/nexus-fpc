{
     File:       HIToolbox/Appearance.h

     Contains:   Appearance Manager Interfaces.

     Version:    HIToolbox-624~3

     Copyright:  © 1994-2008 by Apple Computer, Inc., all rights reserved

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
unit Appearance;
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
uses MacOsApi.MacTypes,MacOsApi.CFBase,MacOsApi.CGContext,MacOsApi.Collections,MacOsApi.QuickdrawText,MacOsApi.QuickdrawTypes,MacOsApi.MacErrors;
{$ELSE FPC_DOTTEDUNITS}
uses MacTypes,CFBase,CGContext,Collections,QuickdrawText,QuickdrawTypes,MacErrors;
{$ENDIF FPC_DOTTEDUNITS}
{$endc} {not MACOSALLINCLUDE}

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{ Appearance Manager constants, etc.                                               }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{ Appearance Manager Apple Events (1.1 and later)              }

{$ifc TARGET_OS_MAC}

{$ALIGN MAC68K}

const
	kAppearanceEventClass = FourCharCode('appr'); { Event Class }
	kAEAppearanceChanged = FourCharCode('thme'); { Appearance changed (e.g. platinum to hi-tech) }
	kAESystemFontChanged = FourCharCode('sysf'); { system font changed }
	kAESmallSystemFontChanged = FourCharCode('ssfn'); { small system font changed }
	kAEViewsFontChanged = FourCharCode('vfnt'); { views font changed }

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{ Appearance Manager file types                                                    }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
const
	kThemeDataFileType = FourCharCode('thme'); { file type for theme files }
	kThemePlatinumFileType = FourCharCode('pltn'); { file type for platinum appearance }
	kThemeCustomThemesFileType = FourCharCode('scen'); { file type for user themes }
	kThemeSoundTrackFileType = FourCharCode('tsnd');

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{ Appearance Manager Supported Themes                                              }
{ Use CopyThemeIdentifier to get the current theme ID                              }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}

{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kThemeAppearancePlatinum CFSTRP('com.apple.theme.appearance.platinum')}
{$endc}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kThemeAppearanceAqua CFSTRP('com.apple.theme.appearance.aqua')}
{$endc}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kThemeAppearanceAquaBlue CFSTRP('com.apple.theme.appearance.aqua.blue')}
{$endc}
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kThemeAppearanceAquaGraphite CFSTRP('com.apple.theme.appearance.aqua.graphite')}
{$endc}


{
 *  AppearancePartCode
 *
 *  Summary:
 *    These are part codes returned by a few of the hit testing
 *    Appearance APIs. Many of the Control Manager's ControlPartCodes
 *    are based on these part codes.
 }
type
	AppearancePartCode = SInt16;
const
{
   * This represents the lack of a part. It will be returned when the
   * Appearance Manager's hit testing logic determines that the input
   * point is not in any part of the widget.
   }
	kAppearancePartMetaNone = 0;

  {
   * This represents a widget which is not currently clickable because
   * it is disabled.
   }
	kAppearancePartMetaDisabled = 254;

  {
   * This represents a widget which is inactive, presumably because it
   * is in a window that is inactive.
   }
	kAppearancePartMetaInactive = 255;

  {
   * The part of a widget which indicates the widget's value. Scroll
   * bar thumbs and slider thumbs are the two main examples.
   }
	kAppearancePartIndicator = 129;

  {
   * The part of a widget which moves its value visually upward. Scroll
   * bar up arrows are the main example.
   }
	kAppearancePartUpButton = 20;

  {
   * The part of a widget which moves its value visually downward.
   * Scroll bar down arrows are the main example.
   }
	kAppearancePartDownButton = 21;

  {
   * The part of a widget which moves its value visually leftward.
   * Scroll bar left arrows are the main example.
   }
	kAppearancePartLeftButton = kAppearancePartUpButton;

  {
   * The part of a widget which moves its value visually rightward.
   * Scroll bar right arrows are the main example.
   }
	kAppearancePartRightButton = kAppearancePartDownButton;

  {
   * The part of a widget which moves its value visually upward one
   * whole page. Scroll bar page up areas are the main example.
   }
	kAppearancePartPageUpArea = 22;

  {
   * The part of a widget which moves its value visually downward one
   * whole page. Scroll bar page down areas are the main example.
   }
	kAppearancePartPageDownArea = 23;

  {
   * The part of a widget which moves its value visually leftward one
   * whole page. Scroll bar page left areas are the main example.
   }
	kAppearancePartPageLeftArea = kAppearancePartPageUpArea;

  {
   * The part of a widget which moves its value visually rightward one
   * whole page. Scroll bar page right areas are the main example.
   }
	kAppearancePartPageRightArea = kAppearancePartPageDownArea;


{
 *  AppearanceRegionCode
 *
 *  Summary:
 *    These are region codes used by a few of window-related Appearance
 *    APIs. Many of the Window Manager's WindowRegionCodes are based on
 *    these region codes.
 }
type
	AppearanceRegionCode = UInt16;
const
	kAppearanceRegionTitleBar = 0;
	kAppearanceRegionTitleText = 1;
	kAppearanceRegionCloseBox = 2;
	kAppearanceRegionZoomBox = 3;
	kAppearanceRegionDrag = 5;
	kAppearanceRegionGrow = 6;
	kAppearanceRegionCollapseBox = 7;
	kAppearanceRegionTitleProxyIcon = 8;  { Mac OS 8.5 forward}
	kAppearanceRegionStructure = 32;
	kAppearanceRegionContent = 33;   { Content area of the window; empty when the window is collapsed}
	kAppearanceRegionToolbarButton = 41;


{
 *  Discussion:
 *    ThemeBrushes
 }
const
{
   * Use with kModalWindowClass.
   }
	kThemeBrushDialogBackgroundActive = 1;

  {
   * Use with kModalWindowClass.
   }
	kThemeBrushDialogBackgroundInactive = 2;

  {
   * Use with kAlertWindowClass and kMovableAlertWindowClass.
   }
	kThemeBrushAlertBackgroundActive = 3;

  {
   * Use with kAlertWindowClass and kMovableAlertWindowClass.
   }
	kThemeBrushAlertBackgroundInactive = 4;

  {
   * Use with kDocumentWindowClass.
   }
	kThemeBrushModelessDialogBackgroundActive = 5;

  {
   * Use with kDocumentWindowClass.
   }
	kThemeBrushModelessDialogBackgroundInactive = 6;

  {
   * Use with kFloatingWindowClass and kUtilityWindowClass.
   }
	kThemeBrushUtilityWindowBackgroundActive = 7;

  {
   * Use with kFloatingWindowClass and kUtilityWindowClass.
   }
	kThemeBrushUtilityWindowBackgroundInactive = 8;

  {
   * The background used for Finder list views.
   }
	kThemeBrushListViewSortColumnBackground = 9;
	kThemeBrushListViewBackground = 10;
	kThemeBrushIconLabelBackground = 11;
	kThemeBrushListViewSeparator = 12;
	kThemeBrushChasingArrows = 13;
	kThemeBrushDragHilite = 14;

  {
   * Use with kDocumentWindowClass.
   }
	kThemeBrushDocumentWindowBackground = 15;
	kThemeBrushFinderWindowBackground = 16;

  {
   * Available in Appearance 1.1 (Mac OS 8.5) and later.
   }
	kThemeBrushScrollBarDelimiterActive = 17;

  {
   * Available in Appearance 1.1 (Mac OS 8.5) and later.
   }
	kThemeBrushScrollBarDelimiterInactive = 18;

  {
   * Available in Appearance 1.1 (Mac OS 8.5) and later.
   }
	kThemeBrushFocusHighlight = 19;

  {
   * Available in Appearance 1.1 (Mac OS 8.5) and later.
   }
	kThemeBrushPopupArrowActive = 20;

  {
   * Available in Appearance 1.1 (Mac OS 8.5) and later.
   }
	kThemeBrushPopupArrowPressed = 21;

  {
   * Available in Appearance 1.1 (Mac OS 8.5) and later.
   }
	kThemeBrushPopupArrowInactive = 22;

  {
   * Available in Appearance 1.1 (Mac OS 8.5) and later.
   }
	kThemeBrushAppleGuideCoachmark = 23;

  {
   * Available in Appearance 1.1 (Mac OS 8.5) and later.
   }
	kThemeBrushIconLabelBackgroundSelected = 24;

  {
   * Available in Appearance 1.1 (Mac OS 8.5) and later.
   }
	kThemeBrushStaticAreaFill = 25;

  {
   * Available in Appearance 1.1 (Mac OS 8.5) and later.
   }
	kThemeBrushActiveAreaFill = 26;

  {
   * Available in Appearance 1.1 (Mac OS 8.5) and later.
   }
	kThemeBrushButtonFrameActive = 27;

  {
   * Available in Appearance 1.1 (Mac OS 8.5) and later.
   }
	kThemeBrushButtonFrameInactive = 28;

  {
   * Available in Appearance 1.1 (Mac OS 8.5) and later.
   }
	kThemeBrushButtonFaceActive = 29;

  {
   * Available in Appearance 1.1 (Mac OS 8.5) and later.
   }
	kThemeBrushButtonFaceInactive = 30;

  {
   * Available in Appearance 1.1 (Mac OS 8.5) and later.
   }
	kThemeBrushButtonFacePressed = 31;

  {
   * Available in Appearance 1.1 (Mac OS 8.5) and later.
   }
	kThemeBrushButtonActiveDarkShadow = 32;

  {
   * Available in Appearance 1.1 (Mac OS 8.5) and later.
   }
	kThemeBrushButtonActiveDarkHighlight = 33;

  {
   * Available in Appearance 1.1 (Mac OS 8.5) and later.
   }
	kThemeBrushButtonActiveLightShadow = 34;

  {
   * Available in Appearance 1.1 (Mac OS 8.5) and later.
   }
	kThemeBrushButtonActiveLightHighlight = 35;

  {
   * Available in Appearance 1.1 (Mac OS 8.5) and later.
   }
	kThemeBrushButtonInactiveDarkShadow = 36;

  {
   * Available in Appearance 1.1 (Mac OS 8.5) and later.
   }
	kThemeBrushButtonInactiveDarkHighlight = 37;

  {
   * Available in Appearance 1.1 (Mac OS 8.5) and later.
   }
	kThemeBrushButtonInactiveLightShadow = 38;

  {
   * Available in Appearance 1.1 (Mac OS 8.5) and later.
   }
	kThemeBrushButtonInactiveLightHighlight = 39;

  {
   * Available in Appearance 1.1 (Mac OS 8.5) and later.
   }
	kThemeBrushButtonPressedDarkShadow = 40;

  {
   * Available in Appearance 1.1 (Mac OS 8.5) and later.
   }
	kThemeBrushButtonPressedDarkHighlight = 41;

  {
   * Available in Appearance 1.1 (Mac OS 8.5) and later.
   }
	kThemeBrushButtonPressedLightShadow = 42;

  {
   * Available in Appearance 1.1 (Mac OS 8.5) and later.
   }
	kThemeBrushButtonPressedLightHighlight = 43;

  {
   * Available in Appearance 1.1 (Mac OS 8.5) and later.
   }
	kThemeBrushBevelActiveLight = 44;

  {
   * Available in Appearance 1.1 (Mac OS 8.5) and later.
   }
	kThemeBrushBevelActiveDark = 45;

  {
   * Available in Appearance 1.1 (Mac OS 8.5) and later.
   }
	kThemeBrushBevelInactiveLight = 46;

  {
   * Available in Appearance 1.1 (Mac OS 8.5) and later.
   }
	kThemeBrushBevelInactiveDark = 47;

  {
   * Available in Appearance 1.1.1 (Mac OS 9.0) and later.
   }
	kThemeBrushNotificationWindowBackground = 48;

  {
   * Use with kMovableModalWindowClass windows. Available in Mac OS X,
   * and CarbonLib 1.3 and later.
   }
	kThemeBrushMovableModalBackground = 49;

  {
   * Use with kSheetWindowClass and kSheetAlertWindowClass. This is the
   * backwardly compatible sheet background.
   * kThemeBrushSheetBackgroundTransparent is preferred. Available in
   * Mac OS X, and CarbonLib 1.3 and later.
   }
	kThemeBrushSheetBackgroundOpaque = 50;

  {
   * Use with kDrawerWindowClass. Available in Mac OS X, and CarbonLib
   * 1.3 and later.
   }
	kThemeBrushDrawerBackground = 51;

  {
   * Use with kToolbarWindowClass. Available in Mac OS X, and Carbon
   * Lib 1.6 and later.
   }
	kThemeBrushToolbarBackground = 52;

  {
   * Use with kSheetWindowClass and kSheetAlertWindowClass. Not fully
   * transparent -- this brush is the semi-transparent background seen
   * with modern sheets. Available in Mac OS X 10.1 and CarbonLib 1.6,
   * and later.
   }
	kThemeBrushSheetBackgroundTransparent = 53;

  {
   * Available in Mac OS X 10.1 and CarbonLib 1.6, and later.
   }
	kThemeBrushMenuBackground = 54;

  {
   * Available in Mac OS X 10.1 and CarbonLib 1.6, and later.
   }
	kThemeBrushMenuBackgroundSelected = 55;

  {
   * For lists that use different colors as the background for odd and
   * even rows (like iTunes), this brush is the background for the odd
   * numbered rows. Available in Mac OS X 10.3 and later.
   }
	kThemeBrushListViewOddRowBackground = 56;

  {
   * For lists that use different colors as the background for odd and
   * even rows (like iTunes), this brush is the background for the even
   * numbered rows. Available in Mac OS X 10.3 and later.
   }
	kThemeBrushListViewEvenRowBackground = 57;

  {
   * The color for the divider lines drawn between columns in some list
   * views. This brush may have an alpha value associated with it.
   * Drawing this brush with QuickDraw or fetching it as an RGBColor
   * will not necessarily yield satisfactory results. Available in Mac
   * OS X 10.3 and later.
   }
	kThemeBrushListViewColumnDivider = 58;

  {
   * kThemeBrushSheetBackgroundOpaque synonym.
   * kThemeBrushSheetBackgroundOpaque is preferred
   }
	kThemeBrushSheetBackground = kThemeBrushSheetBackgroundOpaque;

  {
   * This is a theme meta-brush. It is a specific color that does not
   * change from theme to theme. Use it instead of a direct RGB value.
   * Available in Mac OS 10.1 and CarbonLib 1.6, and later.
   }
	kThemeBrushBlack = -1;

  {
   * This is a theme meta-brush. It is a specific color that does not
   * change from theme to theme. Use it instead of a direct RGB value.
   * Available in Mac OS 10.1 and CarbonLib 1.6, and later.
   }
	kThemeBrushWhite = -2;

  {
   * This is a theme meta-brush. It is a specific color that does not
   * change from theme to theme. Use it instead of a direct RGB value.
   * Available in Mac OS 10.1 and CarbonLib 1.6, and later.
   }
	kThemeBrushPrimaryHighlightColor = -3;

  {
   * This is a theme meta-brush. It is a specific color that does not
   * change from theme to theme. Use it instead of a direct RGB value.
   * Available in Mac OS 10.1 and CarbonLib 1.6, and later.
   }
	kThemeBrushSecondaryHighlightColor = -4;

  {
   * This is a theme meta-brush. It is a specific color that does not
   * change from theme to theme. Use it instead of a direct RGB value.
   * Available in Mac OS 10.1 and CarbonLib 1.6, and later.
   }
	kThemeBrushAlternatePrimaryHighlightColor = -5;

type
	ThemeBrush = SInt16;
const
	kThemeTextColorDialogActive = 1;
	kThemeTextColorDialogInactive = 2;
	kThemeTextColorAlertActive = 3;
	kThemeTextColorAlertInactive = 4;
	kThemeTextColorModelessDialogActive = 5;
	kThemeTextColorModelessDialogInactive = 6;
	kThemeTextColorWindowHeaderActive = 7;
	kThemeTextColorWindowHeaderInactive = 8;
	kThemeTextColorPlacardActive = 9;
	kThemeTextColorPlacardInactive = 10;
	kThemeTextColorPlacardPressed = 11;
	kThemeTextColorPushButtonActive = 12;
	kThemeTextColorPushButtonInactive = 13;
	kThemeTextColorPushButtonPressed = 14;
	kThemeTextColorBevelButtonActive = 15;
	kThemeTextColorBevelButtonInactive = 16;
	kThemeTextColorBevelButtonPressed = 17;
	kThemeTextColorPopupButtonActive = 18;
	kThemeTextColorPopupButtonInactive = 19;
	kThemeTextColorPopupButtonPressed = 20;
	kThemeTextColorIconLabel = 21;
	kThemeTextColorListView = 22;

{ Text Colors available in Appearance 1.0.1 or later }
const
	kThemeTextColorDocumentWindowTitleActive = 23;
	kThemeTextColorDocumentWindowTitleInactive = 24;
	kThemeTextColorMovableModalWindowTitleActive = 25;
	kThemeTextColorMovableModalWindowTitleInactive = 26;
	kThemeTextColorUtilityWindowTitleActive = 27;
	kThemeTextColorUtilityWindowTitleInactive = 28;
	kThemeTextColorPopupWindowTitleActive = 29;
	kThemeTextColorPopupWindowTitleInactive = 30;
	kThemeTextColorRootMenuActive = 31;
	kThemeTextColorRootMenuSelected = 32;
	kThemeTextColorRootMenuDisabled = 33;
	kThemeTextColorMenuItemActive = 34;
	kThemeTextColorMenuItemSelected = 35;
	kThemeTextColorMenuItemDisabled = 36;
	kThemeTextColorPopupLabelActive = 37;
	kThemeTextColorPopupLabelInactive = 38;


{ Text colors available in Appearance 1.1 or later }
const
	kThemeTextColorTabFrontActive = 39;
	kThemeTextColorTabNonFrontActive = 40;
	kThemeTextColorTabNonFrontPressed = 41;
	kThemeTextColorTabFrontInactive = 42;
	kThemeTextColorTabNonFrontInactive = 43;
	kThemeTextColorIconLabelSelected = 44;
	kThemeTextColorBevelButtonStickyActive = 45;
	kThemeTextColorBevelButtonStickyInactive = 46;

{ Text colors available in Appearance 1.1.1 or later }
const
	kThemeTextColorNotification = 47;


{ Text colors only available later than OS X 10.1.3 }
const
	kThemeTextColorSystemDetail = 48;

{ These values are specific colors that do not change from             }
{ theme to theme. You can use them instead of using direct RGB values. }
const
	kThemeTextColorBlack = -1;
	kThemeTextColorWhite = -2;

type
	ThemeTextColor = SInt16;
{ States to draw primitives: disabled, active, and pressed (hilited) }
const
	kThemeStateInactive = 0;
	kThemeStateActive = 1;
	kThemeStatePressed = 2;
	kThemeStateRollover = 6;
	kThemeStateUnavailable = 7;
	kThemeStateUnavailableInactive = 8;

{ obsolete name }
const
	kThemeStateDisabled = 0;

const
	kThemeStatePressedUp = 2;    { draw with up pressed     (increment/decrement buttons) }
	kThemeStatePressedDown = 3;     { draw with down pressed (increment/decrement buttons) }

type
	ThemeDrawState = UInt32;
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{ Theme cursor selectors available in Appearance 1.1 or later                      }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}

const
	kThemeArrowCursor = 0;
	kThemeCopyArrowCursor = 1;
	kThemeAliasArrowCursor = 2;
	kThemeContextualMenuArrowCursor = 3;
	kThemeIBeamCursor = 4;
	kThemeCrossCursor = 5;
	kThemePlusCursor = 6;
	kThemeWatchCursor = 7;    { Can Animate }
	kThemeClosedHandCursor = 8;
	kThemeOpenHandCursor = 9;
	kThemePointingHandCursor = 10;
	kThemeCountingUpHandCursor = 11;   { Can Animate }
	kThemeCountingDownHandCursor = 12;   { Can Animate }
	kThemeCountingUpAndDownHandCursor = 13; { Can Animate }
	kThemeSpinningCursor = 14;   { Can Animate }
	kThemeResizeLeftCursor = 15;
	kThemeResizeRightCursor = 16;
	kThemeResizeLeftRightCursor = 17;
	kThemeNotAllowedCursor = 18;   { available on Mac OS X 10.2 and later }

  {
   * Available in Mac OS X 10.3 or later.
   }
	kThemeResizeUpCursor = 19;

  {
   * Available in Mac OS X 10.3 or later.
   }
	kThemeResizeDownCursor = 20;

  {
   * Available in Mac OS X 10.3 or later.
   }
	kThemeResizeUpDownCursor = 21;

  {
   * A special cursor to indicate that letting up the mouse will cause
   * a dragged item to go away. When the item goes away, a poof cloud
   * animation should occur. This cursor should be updated dynamically
   * depending on whether the mouse up action will remove the item.
   * Available in Mac OS X 10.3 or later.
   }
	kThemePoofCursor = 22;

type
	ThemeCursor = UInt32;
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{ Theme menu bar drawing states                                                    }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
const
	kThemeMenuBarNormal = 0;
	kThemeMenuBarSelected = 1;

type
	ThemeMenuBarState = UInt16;
{ attributes }
const
	kThemeMenuSquareMenuBar = 1 shl 0;

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{ Theme menu drawing states                                                        }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
const
	kThemeMenuActive = 0;
	kThemeMenuSelected = 1;
	kThemeMenuDisabled = 3;

type
	ThemeMenuState = UInt16;
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{ MenuType: add kThemeMenuTypeInactive to menu type for DrawThemeMenuBackground if entire  }
{ menu is inactive                                                                         }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
const
	kThemeMenuTypePullDown = 0;
	kThemeMenuTypePopUp = 1;
	kThemeMenuTypeHierarchical = 2;
	kThemeMenuTypeInactive = $0100;

type
	ThemeMenuType = UInt16;
const
	kThemeMenuItemPlain = 0;
	kThemeMenuItemHierarchical = 1;    { item has hierarchical arrow}
	kThemeMenuItemScrollUpArrow = 2;    { for scrollable menus, indicates item is scroller}
	kThemeMenuItemScrollDownArrow = 3;
	kThemeMenuItemAtTop = $0100; { indicates item is being drawn at top of menu}
	kThemeMenuItemAtBottom = $0200; { indicates item is being drawn at bottom of menu}
	kThemeMenuItemHierBackground = $0400; { item is within a hierarchical menu}
	kThemeMenuItemPopUpBackground = $0800; { item is within a popped up menu}
	kThemeMenuItemHasIcon = $8000; { add into non-arrow type when icon present}
	kThemeMenuItemNoBackground = $4000; { don't draw the menu background while drawing this item (Mac OS X only)}
	kThemeMenuItemAlignRight = $2000; { right-align the content of this menu item (SnowLeopard and later)}

type
	ThemeMenuItemType = UInt16;

{
 *  Discussion:
 *    ThemeBackgroundKinds
 }
const
{
   * The theme background used to draw the fill of a tab pane.
   }
	kThemeBackgroundTabPane = 1;

  {
   * The theme background used to draw the fill of a window placard.
   }
	kThemeBackgroundPlacard = 2;

  {
   * The theme background used to draw the window header of a window of
   * a window that does not contain content that has a hard-lined top
   * edge. An example of this would be icon view in the non side panel
   * Finder.
   }
	kThemeBackgroundWindowHeader = 3;

  {
   * The theme background used to draw the window header of a window of
   * a window that does contain content that has a hard-lined top edge.
   * An example of this would be list view in the non side panel Finder.
   }
	kThemeBackgroundListViewWindowHeader = 4;

  {
   * The theme background used to draw the fill of a secondary group
   * box.
   }
	kThemeBackgroundSecondaryGroupBox = 5;

  {
   * A special theme brush for drawing metal backgrounds. Currently,
   * this brush only works with HIThemeDrawBackground.
   }
	kThemeBackgroundMetal = 6;

type
	ThemeBackgroundKind = UInt32;
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{ Theme Collection tags for Get/SetTheme                                                   }
{  X ALERT: Please note that Get/SetTheme are severely neutered under Mac OS X at present. }
{           The first group of tags below are available to get under both 9 and X. The     }
{           second group is 9 only. None of the tags can be used in SetTheme on X, as it   }
{           is completely inert on X, and will return unimpErr.                            }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
const
	kThemeNameTag = FourCharCode('name'); { Str255}
	kThemeVariantNameTag = FourCharCode('varn'); { Str255}
	kThemeVariantBaseTintTag = FourCharCode('tint'); { RGBColor (10.1 and later)}
	kThemeHighlightColorTag = FourCharCode('hcol'); { RGBColor}
	kThemeScrollBarArrowStyleTag = FourCharCode('sbar'); { ThemeScrollBarArrowStyle}
	kThemeScrollBarThumbStyleTag = FourCharCode('sbth'); { ThemeScrollBarThumbStyle}
	kThemeSoundsEnabledTag = FourCharCode('snds'); { Boolean}
	kThemeDblClickCollapseTag = FourCharCode('coll'); { Boolean}

const
	kThemeAppearanceFileNameTag = FourCharCode('thme'); { Str255}
	kThemeSystemFontTag = FourCharCode('lgsf'); { Str255}
	kThemeSmallSystemFontTag = FourCharCode('smsf'); { Str255}
	kThemeViewsFontTag = FourCharCode('vfnt'); { Str255}
	kThemeViewsFontSizeTag = FourCharCode('vfsz'); { SInt16}
	kThemeDesktopPatternNameTag = FourCharCode('patn'); { Str255}
	kThemeDesktopPatternTag = FourCharCode('patt'); { <variable-length data> (flattened pattern)}
	kThemeDesktopPictureNameTag = FourCharCode('dpnm'); { Str255}
	kThemeDesktopPictureAliasTag = FourCharCode('dpal'); { <alias handle>}
	kThemeDesktopPictureAlignmentTag = FourCharCode('dpan'); { UInt32 (see the Picture Alignments below)}
	kThemeHighlightColorNameTag = FourCharCode('hcnm'); { Str255}
	kThemeExamplePictureIDTag = FourCharCode('epic'); { SInt16}
	kThemeSoundTrackNameTag = FourCharCode('sndt'); { Str255}
	kThemeSoundMaskTag = FourCharCode('smsk'); { UInt32}
	kThemeUserDefinedTag = FourCharCode('user'); { Boolean (this should _always_ be true if present - used by Control Panel).}
	kThemeSmoothFontEnabledTag = FourCharCode('smoo'); { Boolean}
	kThemeSmoothFontMinSizeTag = FourCharCode('smos'); { UInt16 (must be >= 12 and <= 24)}

{ Picture Alignments that might be reported in the data for kThemeDesktopPictureAlignmentTag}
const
	kTiledOnScreen = 1;    { draws picture repeatedly}
	kCenterOnScreen = 2;    { "actual size", shows pattern on sides or clips picture if necessary}
	kFitToScreen = 3;    { shrinks if necessary}
	kFillScreen = 4;    { messes up aspect ratio if necessary}
	kUseBestGuess = 5;     { heuristically determines the best way to display the picture based on picture and monitor sizes}

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{ Theme Control Settings                                                                   }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
const
	kThemeCheckBoxClassicX = 0;    { check box with an 'X'}
	kThemeCheckBoxCheckMark = 1;     { check box with a real check mark}

type
	ThemeCheckBoxStyle = UInt16;
const
	kThemeScrollBarArrowsSingle = 0;    { single arrow on each end}
	kThemeScrollBarArrowsLowerRight = 1;   { double arrows only on right or bottom}

type
	ThemeScrollBarArrowStyle = UInt16;
const
	kThemeScrollBarThumbNormal = 0;    { normal, classic thumb size}
	kThemeScrollBarThumbProportional = 1;  { proportional thumbs}

type
	ThemeScrollBarThumbStyle = UInt16;
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{ Font constants                                                                           }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}

{
 *  Summary:
 *    A ThemeFontID value is a virtual font ID which can be passed to
 *    one of the Appearance Manager's text-related routines. Within
 *    those routines, the ThemeFontID is mapped into the appropriate
 *    real font (or fonts), size, and style based on the system
 *    appearance (Platinum on Mac OS 9, Aqua on Mac OS X), the string
 *    to be rendered (if any), the language/ script that the app is
 *    running in, and possibly other factors. The ThemeFontIDs allow
 *    you to get the correct text appearance for the platform your app
 *    is currently running on.
 }
const
{
   * The font used to draw most interface elements. If you can't find a
   * more appropriate font from the list below, you should use this
   * one. This font is suitable for drawing titles on most custom
   * widgets/buttons, as well as most static text in dialogs and
   * windows.
   }
	kThemeSystemFont = 0;

  {
   * The font used to draw interface elements when space is at a
   * premium. It draws a slightly smaller font compared to
   * kThemeSystemFont.
   }
	kThemeSmallSystemFont = 1;

  {
   * Identical to kThemeSmallSystemFont, except it draws bolded (or
   * otherwise emphasized in some fashion appropriate to your
   * application's language/script).
   }
	kThemeSmallEmphasizedSystemFont = 2;

  {
   * The font used to draw file and folder names in Finder windows or
   * other browsable lists.
   }
	kThemeViewsFont = 3;

  {
   * Identical to kThemeSystemFont, except it draws bolded (or
   * otherwise emphasized in some fashion appropriate to your
   * application's language/script). Only available on Mac OS X or
   * CarbonLib 1.3 or later.
   }
	kThemeEmphasizedSystemFont = 4;

  {
   * An analog to the Script Manager's notion of the Application Font.
   * This font is a suitable default choice for your application's
   * document-style text editing areas. Only available on Mac OS X or
   * CarbonLib 1.3 or later.
   }
	kThemeApplicationFont = 5;

  {
   * Generally smaller than kThemeSmallSystemFont, this font is
   * appropriate for drawing text labels next to image content that
   * reinforces the text's meaning (such as on a bevel button). Only
   * available on Mac OS X or CarbonLib 1.3 or later.
   }
	kThemeLabelFont = 6;
	kThemeSystemFontDetail = 7;
	kThemeSystemFontDetailEmphasized = 8;

  {
   * The font used to draw menu titles in the menu bar. Only available
   * on Mac OS X or CarbonLib 1.3 or later.
   }
	kThemeMenuTitleFont = 100;

  {
   * The font used to draw menu items in the menus. Only available on
   * Mac OS X or CarbonLib 1.3 or later.
   }
	kThemeMenuItemFont = 101;

  {
   * The font used to draw menu item marks in the menus. Only available
   * on Mac OS X or CarbonLib 1.3 or later.
   }
	kThemeMenuItemMarkFont = 102;

  {
   * The font used to draw menu item command key equivalents in the
   * menus. Only available on Mac OS X or CarbonLib 1.3 or later.
   }
	kThemeMenuItemCmdKeyFont = 103;

  {
   * The font used to draw text in most window title bars. Only
   * available on Mac OS X or CarbonLib 1.3 or later.
   }
	kThemeWindowTitleFont = 104;

  {
   * The font used to draw text labels on push buttons. Only available
   * on Mac OS X or CarbonLib 1.3 or later.
   }
	kThemePushButtonFont = 105;

  {
   * The font used to draw text in utility window title bars. Only
   * available on Mac OS X or CarbonLib 1.3 or later.
   }
	kThemeUtilityWindowTitleFont = 106;

  {
   * The font used to draw the first (and most important) message of an
   * alert window. Only available on Mac OS X or CarbonLib 1.3 or later.
   }
	kThemeAlertHeaderFont = 107;

  {
   * The font used to draw the label of a toolbar item. Available in
   * Mac OS X 10.2 or later.
   }
	kThemeToolbarFont = 108;

  {
   * The appropriate system font for mini-sized controls. Available in
   * Mac OS X 10.3 or later.
   }
	kThemeMiniSystemFont = 109;

  {
   * Unlike the other ThemeFontIDs, this one doesn't map to a font
   * appropriate to your application's language or script. It maps
   * directly to the font, size, and style of the current Quickdraw
   * port. This allows you to get somewhat customized behavior out of
   * the APIs which take ThemeFontIDs. Note, however, that
   * kThemeCurrentPortFont does not (and will never) support all
   * Quickdraw styles on all platforms; in particular, outline and
   * shadow style are not supported on Mac OS X. Additionally,
   * kThemeCurrentPortFont is not (and will never be) completely
   * unicode savvy; use of kThemeCurrentPortFont may result in errors
   * having to do with the current port's font not being appropriate
   * for rendering or measuring all glyphs in a given unicode string.
   * Because of overhead associated with gathering Quickdraw font
   * information and converting it to the native font format on Mac OS
   * X, use of kThemeCurrentPortFont may slow down your text drawing
   * and measuring significantly compared to other ThemeFontIDs.
   * Instead of using kThemeCurrentPortFont, your application will
   * probably be better served by using one of the other ThemeFontIDs;
   * use kThemeCurrentPortFont only as a last resort. Only available on
   * Mac OS X or CarbonLib 1.3 or later.
   }
	kThemeCurrentPortFont = 200;

  {
   * Only to be used as a fontID parameter in the HIThemeTextInfo
   * structure. It allows the caller to measure and draw text using a
   * CTFontRef and is the correct method for using custom fonts due to
   * QuickDraw deprecation. When the fontID parameter of the
   * HIThemeTextInfo structure is kThemeSpecifiedFont, the version
   * field must be kHIThemeTextInfoVersionOne and the font field must
   * be a valid CTFontRef. Available in Mac OS X 10.5 or later.
   }
	kThemeSpecifiedFont = 201;

{ This is the total of the PUBLIC ThemeFontIDs!}
const
	kPublicThemeFontCount = 21;

type
	ThemeFontID = UInt16;
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{ Tab constants                                                                            }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
const
	kThemeTabNonFront = 0;
	kThemeTabNonFrontPressed = 1;
	kThemeTabNonFrontInactive = 2;
	kThemeTabFront = 3;
	kThemeTabFrontInactive = 4;
	kThemeTabNonFrontUnavailable = 5;
	kThemeTabFrontUnavailable = 6;

type
	ThemeTabStyle = UInt16;
const
	kThemeTabNorth = 0;
	kThemeTabSouth = 1;
	kThemeTabEast = 2;
	kThemeTabWest = 3;

type
	ThemeTabDirection = UInt16;

{
 *  Summary:
 *    Deprecated tab height and overlap constants.
 *
 *  Discussion:
 *    These constants have been deprecated in favor of theme metrics.
 *    Please do not use them anymore. These constants will be removed
 *    in the next major release of OS X.
 }
const
{
   * Deprecated. Use kThemeMetricSmallTabHeight.
   }
	kThemeSmallTabHeight = 16;

  {
   * Deprecated. Use kThemeMetricLargeTabHeight.
   }
	kThemeLargeTabHeight = 21;

  {
   * Deprecated. Use kThemeMetricTabFrameOverlap.
   }
	kThemeTabPaneOverlap = 3;

  {
   * Deprecated. Use kThemeMetricSmallTabHeight and
   * kThemeMetricSmallTabFrameOverlap.
   }
	kThemeSmallTabHeightMax = 19;

  {
   * Deprecated. Use metric kThemeMetricLargeTabHeight and
   * kThemeMetricTabFrameOverlap.
   }
	kThemeLargeTabHeightMax = 24;


{
 *  Discussion:
 *    ThemeTrackKinds
 }
const
{
   * This is the primitive used to draw the normal variant of the
   * scroll bar control.
   }
	kThemeScrollBarMedium = 0;

  {
   * This is the primitive used to draw the small variant of the scroll
   * bar control.
   }
	kThemeScrollBarSmall = 1;

  {
   * This is the primitive used to draw the normal variant of the
   * slider control.
   }
	kThemeSliderMedium = 2;

  {
   * This is the primitive used to draw the normal variant of the
   * progress bar control.
   }
	kThemeProgressBarMedium = 3;

  {
   * This is the primitive used to draw the normal variant of the
   * indeterminate progress bar control.
   }
	kThemeIndeterminateBarMedium = 4;

  {
   * This is the primitive used to draw the normal variant of the
   * relevance bar control.
   }
	kThemeRelevanceBar = 5;

  {
   * This is the primitive used to draw the small variant of the slider
   * control.
   }
	kThemeSliderSmall = 6;

  {
   * This is the primitive used to draw the large variant of the
   * progress bar control.
   }
	kThemeProgressBarLarge = 7;

  {
   * This is the primitive used to draw the large variant of the
   * indeterminate progress bar control.
   }
	kThemeIndeterminateBarLarge = 8;


{
 *  Discussion:
 *    New ThemeTrackKinds on Mac OS X 10.3 and later. Not all of them
 *    are implemented.
 }
const
{
   * Not implemented. Will return paramErr if used.
   }
	kThemeScrollBarMini = 9;

  {
   * A miniature version of the slider.
   }
	kThemeSliderMini = 10;

  {
   * Not implemented. Will return paramErr if used.
   }
	kThemeProgressBarMini = 11;

  {
   * Not implemented. Will return paramErr if used.
   }
	kThemeIndeterminateBarMini = 12;


{
 *  Discussion:
 *    These are legacy synonyms for previously defined ThemeTrackKinds.
 *    Please use the modern constant names.
 }
const
	kThemeMediumScrollBar = kThemeScrollBarMedium;
	kThemeSmallScrollBar = kThemeScrollBarSmall;
	kThemeMediumSlider = kThemeSliderMedium;
	kThemeMediumProgressBar = kThemeProgressBarMedium;
	kThemeMediumIndeterminateBar = kThemeIndeterminateBarMedium;
	kThemeSmallSlider = kThemeSliderSmall;
	kThemeLargeProgressBar = kThemeProgressBarLarge;
	kThemeLargeIndeterminateBar = kThemeIndeterminateBarLarge;
	kThemeMiniScrollBar = kThemeScrollBarMini;
	kThemeMiniSlider = kThemeSliderMini;
	kThemeMiniProgressBar = kThemeProgressBarMini;
	kThemeMiniIndeterminateBar = kThemeIndeterminateBarMini;

type
	ThemeTrackKind = UInt16;
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{ Track enable states                                                                      }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
const
{ track states }
	kThemeTrackActive = 0;
	kThemeTrackDisabled = 1;
	kThemeTrackNothingToScroll = 2;
	kThemeTrackInactive = 3;

type
	ThemeTrackEnableState = UInt8;
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{ Track pressed states                                                                     }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
const
{ press states (ignored unless track is active) }
	kThemeLeftOutsideArrowPressed = $01;
	kThemeLeftInsideArrowPressed = $02;
	kThemeLeftTrackPressed = $04;
	kThemeThumbPressed = $08;
	kThemeRightTrackPressed = $10;
	kThemeRightInsideArrowPressed = $20;
	kThemeRightOutsideArrowPressed = $40;
	kThemeTopOutsideArrowPressed = kThemeLeftOutsideArrowPressed;
	kThemeTopInsideArrowPressed = kThemeLeftInsideArrowPressed;
	kThemeTopTrackPressed = kThemeLeftTrackPressed;
	kThemeBottomTrackPressed = kThemeRightTrackPressed;
	kThemeBottomInsideArrowPressed = kThemeRightInsideArrowPressed;
	kThemeBottomOutsideArrowPressed = kThemeRightOutsideArrowPressed;

type
	ThemeTrackPressState = UInt8;
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{ Thumb directions                                                                         }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
const
{ thumb direction }
	kThemeThumbPlain = 0;
	kThemeThumbUpward = 1;
	kThemeThumbDownward = 2;

type
	ThemeThumbDirection = UInt8;
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{ Track attributes                                                                         }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}

{
 *  Discussion:
 *    Theme track attributes control the look of the track elements as
 *    drawn by the DrawThemeTrackFoo as well as the region returned by
 *    GetThemeTrackFoo.
 }
const
{
   * The track is drawn horizontally.
   }
	kThemeTrackHorizontal = 1 shl 0;

  {
   * The track progresses from right to left.
   }
	kThemeTrackRightToLeft = 1 shl 1;

  {
   * The track's thumb should be drawn.
   }
	kThemeTrackShowThumb = 1 shl 2;

  {
   * The provided thumbRgn should be drawn opaque, not as a ghost.
   }
	kThemeTrackThumbRgnIsNotGhost = 1 shl 3;

  {
   * The track scroll bar doesn't have arrows.  This attribute
   * currently has no effect
   }
	kThemeTrackNoScrollBarArrows = 1 shl 4;

  {
   * The thumb has focus.  This attribute currently has effect only on
   * sliders.  Available only in Mac OS X 10.2 and later.
   }
	kThemeTrackHasFocus = 1 shl 5;

  {
   * The track's track (i.e. the groove for a slider or the
   * gutter+arrows of a scroll bar) should not be drawn. Available only
   * in Mac OS X 10.5 and later.
   }
	kThemeTrackHideTrack = 1 shl 6;

type
	ThemeTrackAttributes = UInt16;

{
 *  ScrollBarTrackInfo
 *
 *  Summary:
 *    Drawing parameters passed to scroll bar drawing and measuring
 *    theme APIs.
 *
 *  Discussion:
 *    Used in both the old theme APIs and the newer HITheme APIs.
 }
type
	ScrollBarTrackInfoPtr = ^ScrollBarTrackInfo;
	ScrollBarTrackInfo = record
{
   * The current view range size.
   }
		viewsize: SInt32;               { current view range size }

  {
   * ThemeTrackPressState bits that indicate the pressed parts state.
   }
		pressState: SInt8 {ThemeTrackPressState};           { pressed parts state }
		pad: SInt8
	end;

{
 *  SliderTrackInfo
 *
 *  Summary:
 *    Drawing parameters passed to slider drawing and measuring theme
 *    APIs.
 *
 *  Discussion:
 *    Used in both the old theme APIs and the newer HITheme APIs.
 }
type
	SliderTrackInfoPtr = ^SliderTrackInfo;
	SliderTrackInfo = record
{
   * A ThemeThumbDirection indicating the thumb direction.
   }
		thumbDir: SInt8 {ThemeThumbDirection};              { thumb direction }

  {
   * ThemeTrackPressState bits that indicate the pressed parts state.
   }
		pressState: SInt8 {ThemeTrackPressState};           { pressed parts state }
	end;

{
 *  ProgressTrackInfo
 *
 *  Summary:
 *    Drawing parameters passed to (indeterminate) progress bar drawing
 *    and measuring theme APIs.
 *
 *  Discussion:
 *    Used in both the old theme APIs and the newer HITheme APIs.
 }
type
	ProgressTrackInfoPtr = ^ProgressTrackInfo;
	ProgressTrackInfo = record
{
   * A UInt8 indicating the current phase of the track fill.
   }
		phase: UInt8;                  { phase for indeterminate progress }
		pad: SInt8
	end;

{
 *  ThemeTrackDrawInfo
 *
 *  Summary:
 *    Drawing parameters passed to track drawing and measuring theme
 *    APIs.
 *
 *  Discussion:
 *    Use the newer HITheme APIs.
 }
type
	ThemeTrackDrawInfoPtr = ^ThemeTrackDrawInfo;
	ThemeTrackDrawInfo = record
{
   * The ThemeTrackKind of the track being drawn or measured.
   }
		kind: ThemeTrackKind;

  {
   * The bounds of the track is being drawn or measured.
   }
		bounds: Rect;

  {
   * The minimum allowable value for the track being drawn or measured.
   }
		min: SInt32;

  {
   * The maximum allowable value for the track being drawn or measured.
   }
		max: SInt32;

  {
   * The value for the track being drawn or measured.
   }
		value: SInt32;

  {
   * Leave this reserved field set to 0.
   }
		reserved: UInt32;


  {
   * A set of ThemeTrackAttributes for the track to be drawn or
   * measured.
   }
		attributes: ThemeTrackAttributes;

  {
   * A ThemeTrackEnableState describing the state of the track to be
   * drawn or measured.
   }
		enableState: SInt8 {ThemeTrackEnableState};

  {
   * Leave this reserved field set to 0.
   }
		filler1: SInt8;
		case SInt16 of
			0: (
				scrollbar: ScrollBarTrackInfo;
				);
			1: (
				slider: SliderTrackInfo;
				);
			2: (
				progress: ProgressTrackInfo;
				);
	end;

{
 *  Summary:
 *    ThemeWindowAttributes
 *
 *  Discussion:
 *    Theme window attributes control the look of the window elements
 *    as drawn by the DrawThemeWindowFrame.
 }
const
{
   * This bit means that the size of the window can be changed by the
   * user. The window is drawn with a grow box.
   }
	kThemeWindowHasGrow = 1 shl 0;

  {
   * This bit means that the window can be zoomed horizontally. The
   * window is drawn with a zoom box.
   }
	kThemeWindowHasHorizontalZoom = 1 shl 3;

  {
   * This bit means that the window can be zoomed vertically. The
   * window is drawn with a zoom box.
   }
	kThemeWindowHasVerticalZoom = 1 shl 4;

  {
   * This bit means that the window can be zoomed horizontally and
   * vertically. The window is drawn with a zoom box.
   }
	kThemeWindowHasFullZoom = kThemeWindowHasHorizontalZoom + kThemeWindowHasVerticalZoom;

  {
   * This bit means that the window can be closed. The window is drawn
   * with a close box.
   }
	kThemeWindowHasCloseBox = 1 shl 5;

  {
   * This bit means that the window can be collapsed. The window is
   * drawn with a collapse box.
   }
	kThemeWindowHasCollapseBox = 1 shl 6;

  {
   * This bit means that the window has title text and/or a title icon.
   }
	kThemeWindowHasTitleText = 1 shl 7;

  {
   * This bit means that the window has been collapsed.
   }
	kThemeWindowIsCollapsed = 1 shl 8;

  {
   * This bit means that the window has dirty content. Get your mind
   * out of the gutter. That means that the content of the window has
   * changed and needs to be saved. If the window is drawing a close
   * box, it will be drawn dirty.
   }
	kThemeWindowHasDirty = 1 shl 9;

  {
   * This bit means that the window has a toolbar toggling button.
   }
	kThemeWindowHasToolbarButton = 1 shl 11;


type
	ThemeWindowAttributes = UInt32;

{
 *  Summary:
 *    ThemeWindowTypes
 *
 *  Discussion:
 *    Window Types Supported by the Appearance Manager.
 }
const
	kThemeDocumentWindow = 0;
	kThemeDialogWindow = 1;
	kThemeMovableDialogWindow = 2;
	kThemeAlertWindow = 3;
	kThemeMovableAlertWindow = 4;
	kThemePlainDialogWindow = 5;
	kThemeShadowDialogWindow = 6;
	kThemePopupWindow = 7;
	kThemeUtilityWindow = 8;
	kThemeUtilitySideWindow = 9;
	kThemeSheetWindow = 10;
	kThemeDrawerWindow = 11;

type
	ThemeWindowType = UInt16;

{
 *  Summary:
 *    ThemeTitleBarWidgets
 *
 *  Discussion:
 *    Window Widgets Supported by the Appearance Manager.
 }
const
	kThemeWidgetCloseBox = 0;
	kThemeWidgetZoomBox = 1;
	kThemeWidgetCollapseBox = 2;
	kThemeWidgetDirtyCloseBox = 6;
	kThemeWidgetToolbarButton = 7;

const
{ Old/Obsolete name to be removed}
	kThemeWidgetABox = 3;
	kThemeWidgetBBox = 4;
	kThemeWidgetBOffBox = 5;

type
	ThemeTitleBarWidget = UInt16;

{
 *  Summary:
 *    ThemeArrowOrientation
 *
 *  Discussion:
 *    Popup arrow orientations.
 }
const
	kThemeArrowLeft = 0;
	kThemeArrowDown = 1;
	kThemeArrowRight = 2;
	kThemeArrowUp = 3;

type
	ThemeArrowOrientation = UInt16;

{
 *  Summary:
 *    ThemePopupArrowSizes
 *
 *  Discussion:
 *    Popup arrow sizes.
 }
const
	kThemeArrow3pt = 0;
	kThemeArrow5pt = 1;
	kThemeArrow7pt = 2;
	kThemeArrow9pt = 3;

type
	ThemePopupArrowSize = UInt16;

{
 *  Summary:
 *    ThemeGrowDirections
 *
 *  Discussion:
 *    Grow box directions.
 }
const
	kThemeGrowLeft = 1 shl 0; { can grow to the left }
	kThemeGrowRight = 1 shl 1; { can grow to the right }
	kThemeGrowUp = 1 shl 2; { can grow up }
	kThemeGrowDown = 1 shl 3; { can grow down }

type
	ThemeGrowDirection = UInt16;

{
 *  Discussion:
 *    ThemeButtonKinds
 }
const
{
   * Dynamically-sized push button kind. Prior to Mac OS X 10.3 all
   * push button sizes could be determined dynamically: either they
   * were smaller than normal size and therefore small or they were
   * normal size. This constant will never describe a mini push button,
   * regardless of associated bounds. Please use the explicitly-sized
   * kThemePushButton(Normal,Small,Mini) constants.
   }
	kThemePushButton = 0;
	kThemeCheckBox = 1;
	kThemeRadioButton = 2;

  {
   * Bevel button (obsolete)
   }
	kThemeBevelButton = 3;

  {
   * Popup button without text (no label). See ThemeButtonAdornment for
   * glyphs. The arrow button theme name is somewhat confusing. This is
   * the primitive used to draw the control known as the disclosure
   * button.
   }
	kThemeArrowButton = 4;

  {
   * Dynamically-sized popup button kind. Prior to Mac OS X 10.3 all
   * popup button sizes could be determined dynamically: either they
   * were smaller than normal size and therefore small or they were
   * normal size. This constant will never describe a mini popup
   * button, regardless of associated bounds. Please use the
   * explicitly-sized kThemePopupButton(Normal,Small,Mini) constants.
   }
	kThemePopupButton = 5;

  {
   * This is a disclosure triangle with a label beside it. Used to be
   * confusingly named kThemeDisclosureTriangle.
   }
	kThemeDisclosureTriangle = 6;

  {
   * Increment/decrement buttons (no label). This is the primitive used
   * to draw the LittleArrows control.
   }
	kThemeIncDecButton = 7;

  {
   * Small-shadow bevel button
   }
	kThemeBevelButtonSmall = 8;

  {
   * Med-shadow bevel button
   }
	kThemeBevelButtonMedium = 3;

  {
   * Large-shadow bevel button
   }
	kThemeBevelButtonLarge = 9;

  {
   * Sort button for top of a list. This is the theme primitive used to
   * draw the top of the columns in the data browser.
   }
	kThemeListHeaderButton = 10;

  {
   * This is the primitive used to draw the normal variant of the round
   * button control.
   }
	kThemeRoundButton = 11;

  {
   * This is the primitive used to draw the large variant of the round
   * button control.
   }
	kThemeRoundButtonLarge = 12;

  {
   * This is the primitive used to draw the small variant of the check
   * box control.
   }
	kThemeCheckBoxSmall = 13;

  {
   * This is the primitive used to draw the small variant of the radio
   * button control.
   }
	kThemeRadioButtonSmall = 14;

  {
   * This is the primitive used to draw the rounded-corner variant of
   * the bevel button control.
   }
	kThemeRoundedBevelButton = 15;

  {
   * This is the primitive used to draw the normal variant of the combo
   * box control.
   }
	kThemeComboBox = 16;

  {
   * This is the primitive used to draw the small variant of the combo
   * box control.
   }
	kThemeComboBoxSmall = 17;


{
 *  Discussion:
 *    New ThemeButtonKinds available on Mac OS X 10.3 and later.
 }
const
{
   * This is the primitive used to draw the mini variant of the combo
   * box control.
   }
	kThemeComboBoxMini = 18;

  {
   * This is the primitive used to draw the mini variant of the check
   * box control.
   }
	kThemeCheckBoxMini = 19;

  {
   * This is the primitive used to draw the mini variant of the radio
   * button control.
   }
	kThemeRadioButtonMini = 20;

  {
   * This is the primitive used to draw the small variant of the
   * LittleArrows control.
   }
	kThemeIncDecButtonSmall = 21;

  {
   * This is the primitive used to draw the mini variant of the
   * LittleArrows control.
   }
	kThemeIncDecButtonMini = 22;

  {
   * The arrow button theme name is somewhat confusing. This is the
   * primitive used to draw the small variant of the control known as
   * the disclosure button.
   }
	kThemeArrowButtonSmall = 23;

  {
   * The arrow button theme name is somewhat confusing. This is the
   * primitive used to draw the mini variant of the control known as
   * the disclosure button.
   }
	kThemeArrowButtonMini = 24;

  {
   * Explicitly-sized normal push button kind. Prior to Mac OS X 10.3
   * all push button sizes could be determined dynamically: either they
   * were smaller than normal size and therefore small or they were
   * normal size. Using this constant, an explicitly-sized normal push
   * button can be specified.
   }
	kThemePushButtonNormal = 25;

  {
   * Explicitly-sized small push button kind. Prior to Mac OS X 10.3
   * all push button sizes could be determined dynamically: either they
   * were smaller than normal size and therefore small or they were
   * normal size. Using this constant, an explicitly-sized small push
   * button can be specified.
   }
	kThemePushButtonSmall = 26;

  {
   * Explicitly-sized mini push button kind. Prior to Mac OS X 10.3 all
   * push button sizes could be determined dynamically: either they
   * were smaller than normal size and therefore small or they were
   * normal size. Since a mini variant was introduced in Mac OS X 10.3,
   * smaller than normal size is can also mean mini. To avoid confusion
   * with existing code, the mini variant will never be implicitly
   * determined and must be explicitly requested with the
   * kThemePushButtonMini constant.
   }
	kThemePushButtonMini = 27;

  {
   * Explicitly-sized normal popup button kind. Prior to Mac OS X 10.3
   * all popup button sizes could be determined dynamically: either
   * they were smaller than normal size and therefore small or they
   * were normal size. Using this constant, an explicitly-sized normal
   * popup button can be specified.
   }
	kThemePopupButtonNormal = 28;

  {
   * Explicitly-sized small popup button kind. Prior to Mac OS X 10.3
   * all popup button sizes could be determined dynamically: either
   * they were smaller than normal size and therefore small or they
   * were normal size. Using this constant, an explicitly-sized small
   * popup button can be specified.
   }
	kThemePopupButtonSmall = 29;

  {
   * Explicitly-sized mini popup button kind. Prior to Mac OS X 10.3
   * all popup button sizes could be determined dynamically: either
   * they were smaller than normal size and therefore small or they
   * were normal size. Since a mini variant was introduced in Mac OS X
   * 10.3, smaller than normal size is can also mean mini. To avoid
   * confusion with existing code, the mini variant will never be
   * implicitly determined and must be explicitly requested with the
   * kThemePopupButtonMini constant.
   }
	kThemePopupButtonMini = 30;


{
 *  Discussion:
 *    New ThemeButtonKinds available on Mac OS X 10.4 and later.
 }
const
{
   * This is the primitive used to draw the inset variant of the bevel
   * button control.
   }
	kThemeBevelButtonInset = 31;

  {
   * This is the primitive used to draw the textured variant of the
   * push button. Similar to kThemePushButtonNormal, but textured, to
   * be rendered on a textured window.
   }
	kThemePushButtonTextured = 32;

  {
   * This is the primitive used to draw the small, textured variant of
   * the push button. Similar to kThemePushButtonNormal, but textured,
   * to be rendered on a textured window.
   }
	kThemePushButtonTexturedSmall = 33;

  {
   * This is the primitive used to draw the help variant of the round
   * button.
   }
	kThemeRoundButtonHelp = 34;

  {
   * This is a synonym for kThemePushButtonTextured for code
   * compatibility. Please use kThemePushButtonTextured instead.
   }
	kThemePushButtonInset = kThemePushButtonTextured;

  {
   * This is a synonym for kThemePushButtonTexturedSmall for code
   * compatibility. Please use kThemePushButtonTexturedSmall instead.
   }
	kThemePushButtonInsetSmall = kThemePushButtonTexturedSmall;


{
 *  Discussion:
 *    These are legacy synonyms for previously defined
 *    ThemeButtonKinds. Please use the modern constant names.
 }
const
	kThemeNormalCheckBox = kThemeCheckBox;
	kThemeNormalRadioButton = kThemeRadioButton;
	kThemeLargeBevelButton = kThemeBevelButtonLarge;
	kThemeMediumBevelButton = kThemeBevelButtonMedium;
	kThemeMiniCheckBox = kThemeCheckBoxMini;
	kThemeMiniRadioButton = kThemeRadioButtonMini;
	kThemeSmallBevelButton = kThemeBevelButtonSmall;
	kThemeSmallCheckBox = kThemeCheckBoxSmall;
	kThemeSmallRadioButton = kThemeRadioButtonSmall;
	kThemeLargeRoundButton = kThemeRoundButtonLarge;
	kThemeDisclosureButton = kThemeDisclosureTriangle;

type
	ThemeButtonKind = UInt16;

{
 *  Summary:
 *    ThemeButtonValues
 *
 *  Discussion:
 *    Common button values
 }
const
	kThemeButtonOff = 0;
	kThemeButtonOn = 1;
	kThemeButtonMixed = 2;
	kThemeDisclosureRight = 0;
	kThemeDisclosureDown = 1;
	kThemeDisclosureLeft = 2;

type
	ThemeButtonValue = UInt16;


{
 *  Summary:
 *    ThemeButtonAdornments
 *
 *  Discussion:
 *    Use these adornments when drawing buttons using the theme
 *    primitive. Note that the bits starting at (1 << 6) are recycled
 *    and have different meanings depending on ThemeButtonKind.
 }
const
{
   * No adornments.
   }
	kThemeAdornmentNone = 0;

  {
   * Draw default ornamentation (for push button and generic well).
   }
	kThemeAdornmentDefault = 1 shl 0;

  {
   * Draw focus.
   }
	kThemeAdornmentFocus = 1 shl 2;

  {
   * Draw right to left label.
   }
	kThemeAdornmentRightToLeft = 1 shl 4;

  {
   * Don't draw or erase label (radio, check, disclosure).
   }
	kThemeAdornmentDrawIndicatorOnly = 1 shl 5;

  {
   * Draw the left border of the button as selected (list header button
   * only).
   }
	kThemeAdornmentHeaderButtonLeftNeighborSelected = 1 shl 6;

  {
   * Draw the right border of the button (list header button only).
   }
	kThemeAdornmentHeaderButtonRightNeighborSelected = 1 shl 7;

  {
   * Draw the sort indicator pointing upward (list header button only).
   }
	kThemeAdornmentHeaderButtonSortUp = 1 shl 8;

  {
   * Draw as a header menu button (list header button only).
   }
	kThemeAdornmentHeaderMenuButton = 1 shl 9;

  {
   * Draw the non-shadow area of the button (list header button only).
   }
	kThemeAdornmentHeaderButtonNoShadow = 1 shl 10;

  {
   * Draw the only the shadow area of the button (list header button
   * only).
   }
	kThemeAdornmentHeaderButtonShadowOnly = 1 shl 11;

  {
   * When drawn selected, do not draw the sort direction arrow (list
   * header button only). Mac OS X 10.4 and later.
   }
	kThemeAdornmentHeaderButtonNoSortArrow = 1 shl 12;

  {
   * Draw a left arrow on the arrow button or draw left disclosure
   * triangle. Can be combined with kThemeAdornmentArrowDownArrow to
   * draw an intermediate disclosure triangle.
   }
	kThemeAdornmentArrowLeftArrow = 1 shl 6;

  {
   * Draw a down arrow on the arrow button or draw right disclosure
   * triangle. Can be combined with kThemeAdornmentArrowLeftArrow to
   * draw an intermediate disclosure triangle.
   }
	kThemeAdornmentArrowDownArrow = 1 shl 7;

  {
   * Draw a double arrow on the arrow button.
   }
	kThemeAdornmentArrowDoubleArrow = 1 shl 8;

  {
   * Draw a up arrow on the arrow button.
   }
	kThemeAdornmentArrowUpArrow = 1 shl 9;

  {
   * Draw a right disclosure triangle. Can be combined with
   * kThemeAdornmentArrowDownArrow to draw an intermediate disclosure
   * triangle.
   }
	kThemeAdornmentArrowRightArrow = 1 shl 10;


{
 *  Discussion:
 *    These are legacy synonyms for previously defined
 *    ThemeButtonAdornments. Please use the modern constant names.
 }
const
	kThemeAdornmentNoShadow = kThemeAdornmentHeaderButtonNoShadow;
	kThemeAdornmentShadowOnly = kThemeAdornmentHeaderButtonShadowOnly;

type
	ThemeButtonAdornment = UInt16;

{
 *  ThemeButtonDrawInfo
 *
 *  Summary:
 *    Drawing parameters passed to button drawing and measuring theme
 *    APIs.
 *
 *  Discussion:
 *    Use the newer HITheme APIs.
 }
type
	ThemeButtonDrawInfo = record
{
   * The ThemeDrawState of the button being drawn or measured.
   }
		state: ThemeDrawState;

  {
   * The ThemeButtonValue of the button being drawn or measured.
   }
		value: ThemeButtonValue;

  {
   * The ThemeButtonAdornment(s) with which the button is being drawn
   * or measured.
   }
		adornment: ThemeButtonAdornment;
	end;
	ThemeButtonDrawInfoPtr = ^ThemeButtonDrawInfo;
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{ Sound Support                                                                            }
{  X ALERT: Please note that none of the theme sound APIs currently function on X.         }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{ Sound classes                                                                            }
{ You can use the constants below to set what sounds are active using the SetTheme API.    }
{ Use these with the kThemeSoundMask tag.                                                  }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
const
	kThemeNoSounds = 0;
	kThemeWindowSoundsMask = 1 shl 0;
	kThemeMenuSoundsMask = 1 shl 1;
	kThemeControlSoundsMask = 1 shl 2;
	kThemeFinderSoundsMask = 1 shl 3;


{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{ Drag Sounds                                                                              }
{ Drag sounds are looped for the duration of the drag.                                     }
{ Call BeginThemeDragSound at the start of the drag.                                       }
{ Call EndThemeDragSound when the drag has finished.                                       }
{ Note that in order to maintain a consistent user experience, only one drag sound may     }
{ occur at a time.  The sound should be attached to a mouse action, start after the        }
{ mouse goes down and stop when the mouse is released.                                     }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
const
	kThemeDragSoundNone = 0;
	kThemeDragSoundMoveWindow = FourCharCode('wmov');
	kThemeDragSoundGrowWindow = FourCharCode('wgro');
	kThemeDragSoundMoveUtilWindow = FourCharCode('umov');
	kThemeDragSoundGrowUtilWindow = FourCharCode('ugro');
	kThemeDragSoundMoveDialog = FourCharCode('dmov');
	kThemeDragSoundMoveAlert = FourCharCode('amov');
	kThemeDragSoundMoveIcon = FourCharCode('imov');
	kThemeDragSoundSliderThumb = FourCharCode('slth');
	kThemeDragSoundSliderGhost = FourCharCode('slgh');
	kThemeDragSoundScrollBarThumb = FourCharCode('sbth');
	kThemeDragSoundScrollBarGhost = FourCharCode('sbgh');
	kThemeDragSoundScrollBarArrowDecreasing = FourCharCode('sbad');
	kThemeDragSoundScrollBarArrowIncreasing = FourCharCode('sbai');
	kThemeDragSoundDragging = FourCharCode('drag');

type
	ThemeDragSoundKind = OSType;
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{ State-change sounds                                                      }
{ State-change sounds are played asynchronously as a one-shot.             }
{ Call PlayThemeSound to play the sound.  The sound will play              }
{ asynchronously until complete, then stop automatically.                  }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
const
	kThemeSoundNone = 0;
	kThemeSoundMenuOpen = FourCharCode('mnuo'); { menu sounds }
	kThemeSoundMenuClose = FourCharCode('mnuc');
	kThemeSoundMenuItemHilite = FourCharCode('mnui');
	kThemeSoundMenuItemRelease = FourCharCode('mnus');
	kThemeSoundWindowClosePress = FourCharCode('wclp'); { window sounds }
	kThemeSoundWindowCloseEnter = FourCharCode('wcle');
	kThemeSoundWindowCloseExit = FourCharCode('wclx');
	kThemeSoundWindowCloseRelease = FourCharCode('wclr');
	kThemeSoundWindowZoomPress = FourCharCode('wzmp');
	kThemeSoundWindowZoomEnter = FourCharCode('wzme');
	kThemeSoundWindowZoomExit = FourCharCode('wzmx');
	kThemeSoundWindowZoomRelease = FourCharCode('wzmr');
	kThemeSoundWindowCollapsePress = FourCharCode('wcop');
	kThemeSoundWindowCollapseEnter = FourCharCode('wcoe');
	kThemeSoundWindowCollapseExit = FourCharCode('wcox');
	kThemeSoundWindowCollapseRelease = FourCharCode('wcor');
	kThemeSoundWindowDragBoundary = FourCharCode('wdbd');
	kThemeSoundUtilWinClosePress = FourCharCode('uclp'); { utility window sounds }
	kThemeSoundUtilWinCloseEnter = FourCharCode('ucle');
	kThemeSoundUtilWinCloseExit = FourCharCode('uclx');
	kThemeSoundUtilWinCloseRelease = FourCharCode('uclr');
	kThemeSoundUtilWinZoomPress = FourCharCode('uzmp');
	kThemeSoundUtilWinZoomEnter = FourCharCode('uzme');
	kThemeSoundUtilWinZoomExit = FourCharCode('uzmx');
	kThemeSoundUtilWinZoomRelease = FourCharCode('uzmr');
	kThemeSoundUtilWinCollapsePress = FourCharCode('ucop');
	kThemeSoundUtilWinCollapseEnter = FourCharCode('ucoe');
	kThemeSoundUtilWinCollapseExit = FourCharCode('ucox');
	kThemeSoundUtilWinCollapseRelease = FourCharCode('ucor');
	kThemeSoundUtilWinDragBoundary = FourCharCode('udbd');
	kThemeSoundWindowOpen = FourCharCode('wopn'); { window close and zoom action }
	kThemeSoundWindowClose = FourCharCode('wcls');
	kThemeSoundWindowZoomIn = FourCharCode('wzmi');
	kThemeSoundWindowZoomOut = FourCharCode('wzmo');
	kThemeSoundWindowCollapseUp = FourCharCode('wcol');
	kThemeSoundWindowCollapseDown = FourCharCode('wexp');
	kThemeSoundWindowActivate = FourCharCode('wact');
	kThemeSoundUtilWindowOpen = FourCharCode('uopn');
	kThemeSoundUtilWindowClose = FourCharCode('ucls');
	kThemeSoundUtilWindowZoomIn = FourCharCode('uzmi');
	kThemeSoundUtilWindowZoomOut = FourCharCode('uzmo');
	kThemeSoundUtilWindowCollapseUp = FourCharCode('ucol');
	kThemeSoundUtilWindowCollapseDown = FourCharCode('uexp');
	kThemeSoundUtilWindowActivate = FourCharCode('uact');
	kThemeSoundDialogOpen = FourCharCode('dopn');
	kThemeSoundDialogClose = FourCharCode('dlgc');
	kThemeSoundAlertOpen = FourCharCode('aopn');
	kThemeSoundAlertClose = FourCharCode('altc');
	kThemeSoundPopupWindowOpen = FourCharCode('pwop');
	kThemeSoundPopupWindowClose = FourCharCode('pwcl');
	kThemeSoundButtonPress = FourCharCode('btnp'); { button }
	kThemeSoundButtonEnter = FourCharCode('btne');
	kThemeSoundButtonExit = FourCharCode('btnx');
	kThemeSoundButtonRelease = FourCharCode('btnr');
	kThemeSoundDefaultButtonPress = FourCharCode('dbtp'); { default button }
	kThemeSoundDefaultButtonEnter = FourCharCode('dbte');
	kThemeSoundDefaultButtonExit = FourCharCode('dbtx');
	kThemeSoundDefaultButtonRelease = FourCharCode('dbtr');
	kThemeSoundCancelButtonPress = FourCharCode('cbtp'); { cancel button }
	kThemeSoundCancelButtonEnter = FourCharCode('cbte');
	kThemeSoundCancelButtonExit = FourCharCode('cbtx');
	kThemeSoundCancelButtonRelease = FourCharCode('cbtr');
	kThemeSoundCheckboxPress = FourCharCode('chkp'); { checkboxes }
	kThemeSoundCheckboxEnter = FourCharCode('chke');
	kThemeSoundCheckboxExit = FourCharCode('chkx');
	kThemeSoundCheckboxRelease = FourCharCode('chkr');
	kThemeSoundRadioPress = FourCharCode('radp'); { radio buttons }
	kThemeSoundRadioEnter = FourCharCode('rade');
	kThemeSoundRadioExit = FourCharCode('radx');
	kThemeSoundRadioRelease = FourCharCode('radr');
	kThemeSoundScrollArrowPress = FourCharCode('sbap'); { scroll bars }
	kThemeSoundScrollArrowEnter = FourCharCode('sbae');
	kThemeSoundScrollArrowExit = FourCharCode('sbax');
	kThemeSoundScrollArrowRelease = FourCharCode('sbar');
	kThemeSoundScrollEndOfTrack = FourCharCode('sbte');
	kThemeSoundScrollTrackPress = FourCharCode('sbtp');
	kThemeSoundSliderEndOfTrack = FourCharCode('slte'); { sliders }
	kThemeSoundSliderTrackPress = FourCharCode('sltp');
	kThemeSoundBalloonOpen = FourCharCode('blno'); { help balloons }
	kThemeSoundBalloonClose = FourCharCode('blnc');
	kThemeSoundBevelPress = FourCharCode('bevp'); { Bevel buttons }
	kThemeSoundBevelEnter = FourCharCode('beve');
	kThemeSoundBevelExit = FourCharCode('bevx');
	kThemeSoundBevelRelease = FourCharCode('bevr');
	kThemeSoundLittleArrowUpPress = FourCharCode('laup'); { Little Arrows }
	kThemeSoundLittleArrowDnPress = FourCharCode('ladp');
	kThemeSoundLittleArrowEnter = FourCharCode('lare');
	kThemeSoundLittleArrowExit = FourCharCode('larx');
	kThemeSoundLittleArrowUpRelease = FourCharCode('laur');
	kThemeSoundLittleArrowDnRelease = FourCharCode('ladr');
	kThemeSoundPopupPress = FourCharCode('popp'); { Popup Buttons }
	kThemeSoundPopupEnter = FourCharCode('pope');
	kThemeSoundPopupExit = FourCharCode('popx');
	kThemeSoundPopupRelease = FourCharCode('popr');
	kThemeSoundDisclosurePress = FourCharCode('dscp'); { Disclosure Buttons }
	kThemeSoundDisclosureEnter = FourCharCode('dsce');
	kThemeSoundDisclosureExit = FourCharCode('dscx');
	kThemeSoundDisclosureRelease = FourCharCode('dscr');
	kThemeSoundTabPressed = FourCharCode('tabp'); { Tabs }
	kThemeSoundTabEnter = FourCharCode('tabe');
	kThemeSoundTabExit = FourCharCode('tabx');
	kThemeSoundTabRelease = FourCharCode('tabr');
	kThemeSoundDragTargetHilite = FourCharCode('dthi'); { drag manager }
	kThemeSoundDragTargetUnhilite = FourCharCode('dtuh');
	kThemeSoundDragTargetDrop = FourCharCode('dtdr');
	kThemeSoundEmptyTrash = FourCharCode('ftrs'); { finder }
	kThemeSoundSelectItem = FourCharCode('fsel');
	kThemeSoundNewItem = FourCharCode('fnew');
	kThemeSoundReceiveDrop = FourCharCode('fdrp');
	kThemeSoundCopyDone = FourCharCode('fcpd');
	kThemeSoundResolveAlias = FourCharCode('fral');
	kThemeSoundLaunchApp = FourCharCode('flap');
	kThemeSoundDiskInsert = FourCharCode('dski');
	kThemeSoundDiskEject = FourCharCode('dske');
	kThemeSoundFinderDragOnIcon = FourCharCode('fdon');
	kThemeSoundFinderDragOffIcon = FourCharCode('fdof');

type
	ThemeSoundKind = OSType;
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{ Window Metrics                                                                           }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  Window metrics are used by the Appearance manager to fill in the blanks necessary to    }
{  draw windows. If a value is not appropriate for the type of window, be sure to fill in  }
{  the slot in the structure with zero.    For the popupTabOffset parameter, you can pass a}
{  real value based on the left edge of the window. This value might be interpreted in a   }
{  different manner when depending on the value of the popupTabPosition field. The values  }
{  you can pass into popupTabPosition are:                                                 }
{  kThemePopupTabNormalPosition                                                            }
{      Starts the tab left edge at the position indicated by the popupTabOffset field.     }
{  kThemePopupTabCenterOnWindow                                                            }
{      tells us to ignore the offset field and instead simply center the width of the      }
{      handle on the window.                                                               }
{  kThemePopupTabCenterOnOffset                                                            }
{      tells us to center the width of the handle around the value passed in offset.       }
{  The Appearance Manager will try its best to accommodate the requested placement, but may}
{  move the handle slightly to make it fit correctly.                                      }
const
	kThemePopupTabNormalPosition = 0;
	kThemePopupTabCenterOnWindow = 1;
	kThemePopupTabCenterOnOffset = 2;

type
	ThemeWindowMetrics = record
		metricSize: UInt16;             { should be always be sizeof( ThemeWindowMetrics )}
		titleHeight: SInt16;
		titleWidth: SInt16;
		popupTabOffset: SInt16;
		popupTabWidth: SInt16;
		popupTabPosition: UInt16;
	end;
	ThemeWindowMetricsPtr = ^ThemeWindowMetrics;
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{ Drawing State                                                                            }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
type
	ThemeDrawingState = ^OpaqueThemeDrawingState; { an opaque type }
	OpaqueThemeDrawingState = record end;
	ThemeDrawingStatePtr = ^ThemeDrawingState;  { when a var xx:ThemeDrawingState parameter can be nil, it is changed to xx: ThemeDrawingStatePtr }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{ Callback procs                                                                           }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}

{
 *  ThemeTabTitleDrawProcPtr
 *
 *  Summary:
 *    Callback function for drawing the label text of a tab.
 }
type
	ThemeTabTitleDrawProcPtr = procedure( const (*var*) bounds: Rect; style: ThemeTabStyle; direction: ThemeTabDirection; depth: SInt16; isColorDev: Boolean; userData: URefCon );

{
 *  ThemeEraseProcPtr
 *
 *  Summary:
 *    Callback function for erasing the background behind a theme
 *    primitive.
 }
type
	ThemeEraseProcPtr = procedure( const (*var*) bounds: Rect; eraseData: URefCon; depth: SInt16; isColorDev: Boolean );

{
 *  ThemeButtonDrawProcPtr
 *
 *  Summary:
 *    Callback function for drawing the label text of a button.
 }
type
	ThemeButtonDrawProcPtr = procedure( const (*var*) bounds: Rect; kind: ThemeButtonKind; const (*var*) info: ThemeButtonDrawInfo; userData: URefCon; depth: SInt16; isColorDev: Boolean );

{
 *  WindowTitleDrawingProcPtr
 *
 *  Summary:
 *    Callback function for drawing the title text of a window.
 }
type
	WindowTitleDrawingProcPtr = procedure( const (*var*) bounds: Rect; depth: SInt16; colorDevice: Boolean; userData: URefCon );

{
 *  ThemeIteratorProcPtr
 *
 *  Summary:
 *    Callback function for iterating over all known themes.
 }
type
	ThemeIteratorProcPtr = function( const (*var*) inFileName: Str255; resID: SInt16; inThemeSettings: Collection; inUserData: PRefCon ): Boolean;
type
	ThemeTabTitleDrawUPP = ThemeTabTitleDrawProcPtr;
type
	ThemeEraseUPP = ThemeEraseProcPtr;
type
	ThemeButtonDrawUPP = ThemeButtonDrawProcPtr;
type
	WindowTitleDrawingUPP = WindowTitleDrawingProcPtr;
type
	ThemeIteratorUPP = ThemeIteratorProcPtr;
{
 *  NewThemeTabTitleDrawUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewThemeTabTitleDrawUPP( userRoutine: ThemeTabTitleDrawProcPtr ): ThemeTabTitleDrawUPP; external name '_NewThemeTabTitleDrawUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  NewThemeEraseUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewThemeEraseUPP( userRoutine: ThemeEraseProcPtr ): ThemeEraseUPP; external name '_NewThemeEraseUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  NewThemeButtonDrawUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewThemeButtonDrawUPP( userRoutine: ThemeButtonDrawProcPtr ): ThemeButtonDrawUPP; external name '_NewThemeButtonDrawUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  NewWindowTitleDrawingUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewWindowTitleDrawingUPP( userRoutine: WindowTitleDrawingProcPtr ): WindowTitleDrawingUPP; external name '_NewWindowTitleDrawingUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  NewThemeIteratorUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewThemeIteratorUPP( userRoutine: ThemeIteratorProcPtr ): ThemeIteratorUPP; external name '_NewThemeIteratorUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  DisposeThemeTabTitleDrawUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeThemeTabTitleDrawUPP( userUPP: ThemeTabTitleDrawUPP ); external name '_DisposeThemeTabTitleDrawUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  DisposeThemeEraseUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeThemeEraseUPP( userUPP: ThemeEraseUPP ); external name '_DisposeThemeEraseUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  DisposeThemeButtonDrawUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeThemeButtonDrawUPP( userUPP: ThemeButtonDrawUPP ); external name '_DisposeThemeButtonDrawUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  DisposeWindowTitleDrawingUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeWindowTitleDrawingUPP( userUPP: WindowTitleDrawingUPP ); external name '_DisposeWindowTitleDrawingUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  DisposeThemeIteratorUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeThemeIteratorUPP( userUPP: ThemeIteratorUPP ); external name '_DisposeThemeIteratorUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  InvokeThemeTabTitleDrawUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure InvokeThemeTabTitleDrawUPP( const (*var*) bounds: Rect; style: ThemeTabStyle; direction: ThemeTabDirection; depth: SInt16; isColorDev: Boolean; userData: URefCon; userUPP: ThemeTabTitleDrawUPP ); external name '_InvokeThemeTabTitleDrawUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  InvokeThemeEraseUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure InvokeThemeEraseUPP( const (*var*) bounds: Rect; eraseData: URefCon; depth: SInt16; isColorDev: Boolean; userUPP: ThemeEraseUPP ); external name '_InvokeThemeEraseUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  InvokeThemeButtonDrawUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure InvokeThemeButtonDrawUPP( const (*var*) bounds: Rect; kind: ThemeButtonKind; const (*var*) info: ThemeButtonDrawInfo; userData: URefCon; depth: SInt16; isColorDev: Boolean; userUPP: ThemeButtonDrawUPP ); external name '_InvokeThemeButtonDrawUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  InvokeWindowTitleDrawingUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure InvokeWindowTitleDrawingUPP( const (*var*) bounds: Rect; depth: SInt16; colorDevice: Boolean; userData: URefCon; userUPP: WindowTitleDrawingUPP ); external name '_InvokeWindowTitleDrawingUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  InvokeThemeIteratorUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function InvokeThemeIteratorUPP( const (*var*) inFileName: Str255; resID: SInt16; inThemeSettings: Collection; inUserData: PRefCon; userUPP: ThemeIteratorUPP ): Boolean; external name '_InvokeThemeIteratorUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{ Menu Drawing callbacks                                                           }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}

{
 *  MenuTitleDrawingProcPtr
 *
 *  Summary:
 *    Callback function for drawing the title text of a menu.
 }
type
	MenuTitleDrawingProcPtr = procedure( const (*var*) inBounds: Rect; inDepth: SInt16; inIsColorDevice: Boolean; inUserData: SRefCon );

{
 *  MenuItemDrawingProcPtr
 *
 *  Summary:
 *    Callback function for drawing the text of a menu item.
 }
type
	MenuItemDrawingProcPtr = procedure( const (*var*) inBounds: Rect; inDepth: SInt16; inIsColorDevice: Boolean; inUserData: SRefCon );
type
	MenuTitleDrawingUPP = MenuTitleDrawingProcPtr;
type
	MenuItemDrawingUPP = MenuItemDrawingProcPtr;
{
 *  NewMenuTitleDrawingUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewMenuTitleDrawingUPP( userRoutine: MenuTitleDrawingProcPtr ): MenuTitleDrawingUPP; external name '_NewMenuTitleDrawingUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  NewMenuItemDrawingUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewMenuItemDrawingUPP( userRoutine: MenuItemDrawingProcPtr ): MenuItemDrawingUPP; external name '_NewMenuItemDrawingUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  DisposeMenuTitleDrawingUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeMenuTitleDrawingUPP( userUPP: MenuTitleDrawingUPP ); external name '_DisposeMenuTitleDrawingUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  DisposeMenuItemDrawingUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeMenuItemDrawingUPP( userUPP: MenuItemDrawingUPP ); external name '_DisposeMenuItemDrawingUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  InvokeMenuTitleDrawingUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure InvokeMenuTitleDrawingUPP( const (*var*) inBounds: Rect; inDepth: SInt16; inIsColorDevice: Boolean; inUserData: SRefCon; userUPP: MenuTitleDrawingUPP ); external name '_InvokeMenuTitleDrawingUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{
 *  InvokeMenuItemDrawingUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure InvokeMenuItemDrawingUPP( const (*var*) inBounds: Rect; inDepth: SInt16; inIsColorDevice: Boolean; inUserData: SRefCon; userUPP: MenuItemDrawingUPP ); external name '_InvokeMenuItemDrawingUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_5 *)

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  Appearance Manager APIs                                                         }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{ Registering Appearance-Savvy Applications }
const
	appearanceBadBrushIndexErr = themeInvalidBrushErr; { pattern index invalid }
	appearanceProcessRegisteredErr = themeProcessRegisteredErr;
	appearanceProcessNotRegisteredErr = themeProcessNotRegisteredErr;
	appearanceBadTextColorIndexErr = themeBadTextColorErr;
	appearanceThemeHasNoAccents = themeHasNoAccentsErr;
	appearanceBadCursorIndexErr = themeBadCursorIndexErr;

const
	kThemeActiveDialogBackgroundBrush = kThemeBrushDialogBackgroundActive;
	kThemeInactiveDialogBackgroundBrush = kThemeBrushDialogBackgroundInactive;
	kThemeActiveAlertBackgroundBrush = kThemeBrushAlertBackgroundActive;
	kThemeInactiveAlertBackgroundBrush = kThemeBrushAlertBackgroundInactive;
	kThemeActiveModelessDialogBackgroundBrush = kThemeBrushModelessDialogBackgroundActive;
	kThemeInactiveModelessDialogBackgroundBrush = kThemeBrushModelessDialogBackgroundInactive;
	kThemeActiveUtilityWindowBackgroundBrush = kThemeBrushUtilityWindowBackgroundActive;
	kThemeInactiveUtilityWindowBackgroundBrush = kThemeBrushUtilityWindowBackgroundInactive;
	kThemeListViewSortColumnBackgroundBrush = kThemeBrushListViewSortColumnBackground;
	kThemeListViewBackgroundBrush = kThemeBrushListViewBackground;
	kThemeIconLabelBackgroundBrush = kThemeBrushIconLabelBackground;
	kThemeListViewSeparatorBrush = kThemeBrushListViewSeparator;
	kThemeChasingArrowsBrush = kThemeBrushChasingArrows;
	kThemeDragHiliteBrush = kThemeBrushDragHilite;
	kThemeDocumentWindowBackgroundBrush = kThemeBrushDocumentWindowBackground;
	kThemeFinderWindowBackgroundBrush = kThemeBrushFinderWindowBackground;

const
	kThemeActiveScrollBarDelimiterBrush = kThemeBrushScrollBarDelimiterActive;
	kThemeInactiveScrollBarDelimiterBrush = kThemeBrushScrollBarDelimiterInactive;
	kThemeFocusHighlightBrush = kThemeBrushFocusHighlight;
	kThemeActivePopupArrowBrush = kThemeBrushPopupArrowActive;
	kThemePressedPopupArrowBrush = kThemeBrushPopupArrowPressed;
	kThemeInactivePopupArrowBrush = kThemeBrushPopupArrowInactive;
	kThemeAppleGuideCoachmarkBrush = kThemeBrushAppleGuideCoachmark;

const
	kThemeActiveDialogTextColor = kThemeTextColorDialogActive;
	kThemeInactiveDialogTextColor = kThemeTextColorDialogInactive;
	kThemeActiveAlertTextColor = kThemeTextColorAlertActive;
	kThemeInactiveAlertTextColor = kThemeTextColorAlertInactive;
	kThemeActiveModelessDialogTextColor = kThemeTextColorModelessDialogActive;
	kThemeInactiveModelessDialogTextColor = kThemeTextColorModelessDialogInactive;
	kThemeActiveWindowHeaderTextColor = kThemeTextColorWindowHeaderActive;
	kThemeInactiveWindowHeaderTextColor = kThemeTextColorWindowHeaderInactive;
	kThemeActivePlacardTextColor = kThemeTextColorPlacardActive;
	kThemeInactivePlacardTextColor = kThemeTextColorPlacardInactive;
	kThemePressedPlacardTextColor = kThemeTextColorPlacardPressed;
	kThemeActivePushButtonTextColor = kThemeTextColorPushButtonActive;
	kThemeInactivePushButtonTextColor = kThemeTextColorPushButtonInactive;
	kThemePressedPushButtonTextColor = kThemeTextColorPushButtonPressed;
	kThemeActiveBevelButtonTextColor = kThemeTextColorBevelButtonActive;
	kThemeInactiveBevelButtonTextColor = kThemeTextColorBevelButtonInactive;
	kThemePressedBevelButtonTextColor = kThemeTextColorBevelButtonPressed;
	kThemeActivePopupButtonTextColor = kThemeTextColorPopupButtonActive;
	kThemeInactivePopupButtonTextColor = kThemeTextColorPopupButtonInactive;
	kThemePressedPopupButtonTextColor = kThemeTextColorPopupButtonPressed;
	kThemeIconLabelTextColor = kThemeTextColorIconLabel;
	kThemeListViewTextColor = kThemeTextColorListView;

const
	kThemeActiveDocumentWindowTitleTextColor = kThemeTextColorDocumentWindowTitleActive;
	kThemeInactiveDocumentWindowTitleTextColor = kThemeTextColorDocumentWindowTitleInactive;
	kThemeActiveMovableModalWindowTitleTextColor = kThemeTextColorMovableModalWindowTitleActive;
	kThemeInactiveMovableModalWindowTitleTextColor = kThemeTextColorMovableModalWindowTitleInactive;
	kThemeActiveUtilityWindowTitleTextColor = kThemeTextColorUtilityWindowTitleActive;
	kThemeInactiveUtilityWindowTitleTextColor = kThemeTextColorUtilityWindowTitleInactive;
	kThemeActivePopupWindowTitleColor = kThemeTextColorPopupWindowTitleActive;
	kThemeInactivePopupWindowTitleColor = kThemeTextColorPopupWindowTitleInactive;
	kThemeActiveRootMenuTextColor = kThemeTextColorRootMenuActive;
	kThemeSelectedRootMenuTextColor = kThemeTextColorRootMenuSelected;
	kThemeDisabledRootMenuTextColor = kThemeTextColorRootMenuDisabled;
	kThemeActiveMenuItemTextColor = kThemeTextColorMenuItemActive;
	kThemeSelectedMenuItemTextColor = kThemeTextColorMenuItemSelected;
	kThemeDisabledMenuItemTextColor = kThemeTextColorMenuItemDisabled;
	kThemeActivePopupLabelTextColor = kThemeTextColorPopupLabelActive;
	kThemeInactivePopupLabelTextColor = kThemeTextColorPopupLabelInactive;

const
	kAEThemeSwitch = kAEAppearanceChanged; { Event ID's: Theme Switched }

const
	kThemeNoAdornment = kThemeAdornmentNone;
	kThemeDefaultAdornment = kThemeAdornmentDefault;
	kThemeFocusAdornment = kThemeAdornmentFocus;
	kThemeRightToLeftAdornment = kThemeAdornmentRightToLeft;
	kThemeDrawIndicatorOnly = kThemeAdornmentDrawIndicatorOnly;

const
	kThemeBrushPassiveAreaFill = kThemeBrushStaticAreaFill;

const
	kThemeScrollBar = kThemeMediumScrollBar;
	kThemeSlider = kThemeMediumSlider;
	kThemeProgressBar = kThemeMediumProgressBar;
	kThemeIndeterminateBar = kThemeMediumIndeterminateBar;

{$endc} {TARGET_OS_MAC}

{$ifc not defined MACOSALLINCLUDE or not MACOSALLINCLUDE}

end.
{$endc} {not MACOSALLINCLUDE}
