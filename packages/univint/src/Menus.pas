{
     File:       HIToolbox/Menus.h

     Contains:   Menu Manager Interfaces.

     Version:    HIToolbox-624~3

     Copyright:  © 1985-2008 by Apple Computer, Inc., all rights reserved.

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
unit Menus;
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
uses MacOsApi.MacTypes,MacOsApi.AEDataModel,MacOsApi.Appearance,MacOsApi.CFBase,MacOsApi.CFArray,MacOsApi.CFAttributedString,MacOsApi.CGContext,MacOsApi.CTFont,MacOsApi.ATSTypes,MacOsApi.Events,MacOsApi.QuickdrawTypes,MacOsApi.TextCommon,MacOsApi.Collections,MacOsApi.CarbonEventsCore,MacOsApi.HIObject;
{$ELSE FPC_DOTTEDUNITS}
uses MacTypes,AEDataModel,Appearance,CFBase,CFArray,CFAttributedString,CGContext,CTFont,ATSTypes,Events,QuickdrawTypes,TextCommon,Collections,CarbonEventsCore,HIObject;
{$ENDIF FPC_DOTTEDUNITS}
{$endc} {not MACOSALLINCLUDE}


{$ifc TARGET_OS_MAC}

{$ALIGN MAC68K}


{
 *  Menu Manager
 }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Menu Constants                                                                    }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}

const
{
   * Proc ID for a normal text menu. This constant is not typically
   * used.
   }
	textMenuProc = 0;

  {
   * This value may be passed to InsertMenuItem, InsertMenuItemText,
   * and InsertMenuItemTextWithCFString to indicate that the new item
   * should be inserted at the end of the menu. Note that you can also
   * just call AppendMenu[ItemText][WithCFString].
   }
	kHIMenuAppendItem = $0000FFFF;

const
	noMark = 0;     { mark symbol for SetItemMark; other mark symbols are defined in Fonts.h }

{ Constants for use with MacOS 8.0 (Appearance 1.0) and later}
const
	kMenuStdMenuProc = 63;
	kMenuStdMenuBarProc = 63;

{ For use with Get/SetMenuItemModifiers}
const
	kMenuNoModifiers = 0;    { Mask for no modifiers}
	kMenuShiftModifier = 1 shl 0; { Mask for shift key modifier}
	kMenuOptionModifier = 1 shl 1; { Mask for option key modifier}
	kMenuControlModifier = 1 shl 2; { Mask for control key modifier}
	kMenuNoCommandModifier = 1 shl 3; { Mask for no command key modifier}

{ For use with Get/SetMenuItemIconHandle}
const
	kMenuNoIcon = 0;    { No icon}
	kMenuIconType = 1;    { Type for ICON}
	kMenuShrinkIconType = 2;    { Type for ICON plotted 16 x 16}
	kMenuSmallIconType = 3;    { Type for SICN}
	kMenuColorIconType = 4;    { Type for cicn}
	kMenuIconSuiteType = 5;    { Type for Icon Suite}
	kMenuIconRefType = 6;    { Type for Icon Ref}
	kMenuCGImageRefType = 7;    { Type for a CGImageRef (Mac OS X only)}
	kMenuSystemIconSelectorType = 8;    { Type for an OSType identifying an IconRef registered with Icon Services under kSystemIconsCreator (Mac OS X 10.1 and later only)}
	kMenuIconResourceType = 9;     { Type for a CFStringRef with the full name of a .icns resource in the main bundle of the process (Mac OS X 10.1 and later only)}

{ For use with Get/SetMenuItemKeyGlyph}
const
	kMenuNullGlyph = $00; { Null (always glyph 1)}
	kMenuTabRightGlyph = $02; { Tab to the right key (for left-to-right script systems)}
	kMenuTabLeftGlyph = $03; { Tab to the left key (for right-to-left script systems)}
	kMenuEnterGlyph = $04; { Enter key}
	kMenuShiftGlyph = $05; { Shift key}
	kMenuControlGlyph = $06; { Control key}
	kMenuOptionGlyph = $07; { Option key}
	kMenuSpaceGlyph = $09; { Space (always glyph 3) key}
	kMenuDeleteRightGlyph = $0A; { Delete to the right key (for right-to-left script systems)}
	kMenuReturnGlyph = $0B; { Return key (for left-to-right script systems)}
	kMenuReturnR2LGlyph = $0C; { Return key (for right-to-left script systems)}
	kMenuNonmarkingReturnGlyph = $0D; { Nonmarking return key}
	kMenuPencilGlyph = $0F; { Pencil key}
	kMenuDownwardArrowDashedGlyph = $10; { Downward dashed arrow key}
	kMenuCommandGlyph = $11; { Command key}
	kMenuCheckmarkGlyph = $12; { Checkmark key}
	kMenuDiamondGlyph = $13; { Diamond key}
	kMenuAppleLogoFilledGlyph = $14; { Apple logo key (filled)}
	kMenuParagraphKoreanGlyph = $15; { Unassigned (paragraph in Korean)}
	kMenuDeleteLeftGlyph = $17; { Delete to the left key (for left-to-right script systems)}
	kMenuLeftArrowDashedGlyph = $18; { Leftward dashed arrow key}
	kMenuUpArrowDashedGlyph = $19; { Upward dashed arrow key}
	kMenuRightArrowDashedGlyph = $1A; { Rightward dashed arrow key}
	kMenuEscapeGlyph = $1B; { Escape key}
	kMenuClearGlyph = $1C; { Clear key}
	kMenuLeftDoubleQuotesJapaneseGlyph = $1D; { Unassigned (left double quotes in Japanese)}
	kMenuRightDoubleQuotesJapaneseGlyph = $1E; { Unassigned (right double quotes in Japanese)}
	kMenuTrademarkJapaneseGlyph = $1F; { Unassigned (trademark in Japanese)}
	kMenuBlankGlyph = $61; { Blank key}
	kMenuPageUpGlyph = $62; { Page up key}
	kMenuCapsLockGlyph = $63; { Caps lock key}
	kMenuLeftArrowGlyph = $64; { Left arrow key}
	kMenuRightArrowGlyph = $65; { Right arrow key}
	kMenuNorthwestArrowGlyph = $66; { Northwest arrow key}
	kMenuHelpGlyph = $67; { Help key}
	kMenuUpArrowGlyph = $68; { Up arrow key}
	kMenuSoutheastArrowGlyph = $69; { Southeast arrow key}
	kMenuDownArrowGlyph = $6A; { Down arrow key}
	kMenuPageDownGlyph = $6B; { Page down key}
	kMenuAppleLogoOutlineGlyph = $6C; { Apple logo key (outline)}
	kMenuContextualMenuGlyph = $6D; { Contextual menu key}
	kMenuPowerGlyph = $6E; { Power key}
	kMenuF1Glyph = $6F; { F1 key}
	kMenuF2Glyph = $70; { F2 key}
	kMenuF3Glyph = $71; { F3 key}
	kMenuF4Glyph = $72; { F4 key}
	kMenuF5Glyph = $73; { F5 key}
	kMenuF6Glyph = $74; { F6 key}
	kMenuF7Glyph = $75; { F7 key}
	kMenuF8Glyph = $76; { F8 key}
	kMenuF9Glyph = $77; { F9 key}
	kMenuF10Glyph = $78; { F10 key}
	kMenuF11Glyph = $79; { F11 key}
	kMenuF12Glyph = $7A; { F12 key}
	kMenuF13Glyph = $87; { F13 key}
	kMenuF14Glyph = $88; { F14 key}
	kMenuF15Glyph = $89; { F15 key}
	kMenuControlISOGlyph = $8A; { Control key (ISO standard)}
	kMenuEjectGlyph = $8C; { Eject key (available on Mac OS X 10.2 and later)}
	kMenuEisuGlyph = $8D; { Japanese eisu key (available in Mac OS X 10.4 and later)}
	kMenuKanaGlyph = $8E; { Japanese kana key (available in Mac OS X 10.4 and later)}
	kMenuF16Glyph = $8F; { F16 key (available in SnowLeopard and later)}
	kMenuF17Glyph = $90; { F17 key (available in SnowLeopard and later)}
	kMenuF18Glyph = $91; { F18 key (available in SnowLeopard and later)}
	kMenuF19Glyph = $92;  { F19 key (available in SnowLeopard and later)}


{
 *  MenuAttributes
 *
 *  Summary:
 *    Menu attributes control behavior of the entire menu. They are
 *    used with the Get/ChangeMenuAttributes APIs.
 }
type
	MenuAttributes = UInt32;
const
{
   * No column space is allocated for the mark character when this menu
   * is drawn.
   }
	kMenuAttrExcludesMarkColumn = 1 shl 0;

  {
   * The menu title is automatically disabled when all items are
   * disabled.
   }
	kMenuAttrAutoDisable = 1 shl 2;

  {
   * The pencil glyph from the Keyboard font (kMenuPencilGlyph) is used
   * to draw the Control modifier key in menu keyboard equivalents.
   * This appearance is typically used only by Japanese input method
   * menus.
   }
	kMenuAttrUsePencilGlyph = 1 shl 3;

  {
   * The menu title is not drawn in the menubar, even when the menu is
   * inserted in the menubar. Useful for adding command keys that don't
   * correspond to a visible menu item; menu items with the desired
   * command keys can be added to the menu and inserted in the menubar
   * without making the menu visible. This attribute is available in
   * Mac OS X 10.2 and later.
   }
	kMenuAttrHidden = 1 shl 4;

  {
   * If menu item separators are present at the beginning or end of the
   * menu, or if multiple contiguous separators are present, the extra
   * separator items are marked as hidden to avoid extra blank space in
   * the menu. The menu is examined for extra separators whenever the
   * menu size is recalculated. This attribute is available in Mac OS X
   * 10.3 and later.
   }
	kMenuAttrCondenseSeparators = 1 shl 5;

  {
   * Disables automatic caching of the menu image by the Menu Manager.
   * Automatic caching is provided for all menus that use an HIView to
   * draw their content. Setting this attribute will prevent the Menu
   * Manager from caching the menu image; instead, the menu will be
   * drawn using the standard HIView drawing mechanism each time that
   * it is displayed. This attribute is available in Mac OS X 10.3 and
   * later.
   }
	kMenuAttrDoNotCacheImage = 1 shl 6;

  {
   * Disables substitution of command keys from the
   * NSUserKeyEquivalents dictionary. By default, all menu items are
   * checked for a match in the dictionary. Note that this attribute,
   * to be effective, should be added at the time that the menu is
   * created; once the menu has been searched for user command keys
   * (which occurs in CalcMenuSize, in GetItemCmd and
   * GetMenuItemCommandKey, and before command key matching), the
   * original command keys are replaced by the user command keys and
   * cannot be retrieved. For this reason, it is also not useful to
   * clear this attribute; the original command keys cannot be
   * restored. This attribute is available in Mac OS X 10.3 and later.
   }
	kMenuAttrDoNotUseUserCommandKeys = 1 shl 7;


{
 *  MenuItemAttributes
 *
 *  Summary:
 *    Menu item attributes control behavior of individual menu items.
 *    They are used with the Get/ChangeMenuItemAttributes APIs.
 }
type
	MenuItemAttributes = UInt32;
const
{
   * This item is disabled.
   }
	kMenuItemAttrDisabled = 1 shl 0;

  {
   * This item's icon is disabled.
   }
	kMenuItemAttrIconDisabled = 1 shl 1;

  {
   * Allows the parent item of a submenu to be selectable.
   }
	kMenuItemAttrSubmenuParentChoosable = 1 shl 2;

  {
   * This item changes dynamically based on modifier key state.
   }
	kMenuItemAttrDynamic = 1 shl 3;

  {
   * This item is not part of the same dynamic group as the previous
   * item.
   }
	kMenuItemAttrNotPreviousAlternate = 1 shl 4;

  {
   * This item is not drawn when the menu is displayed. It is also not
   * included in command key matching, unless the item also has either
   * the Dynamic or IncludeInCmdKeyMatching attributes.
   }
	kMenuItemAttrHidden = 1 shl 5;

  {
   * This item is a separator; the text of the item is ignored.
   }
	kMenuItemAttrSeparator = 1 shl 6;

  {
   * This item is a menu section header; it is disabled and
   * unselectable.
   }
	kMenuItemAttrSectionHeader = 1 shl 7;

  {
   * Metacharacters in the text of this item (such as the dash) are
   * ignored.
   }
	kMenuItemAttrIgnoreMeta = 1 shl 8;

  {
   * This item is recognized by IsMenuKeyEvent when it is passed an
   * auto-repeat keyboard event.
   }
	kMenuItemAttrAutoRepeat = 1 shl 9;

  {
   * When MenuEvent and IsMenuKeyEvent compare this item's keyboard
   * equivalent against a keyboard event, they use the item's virtual
   * keycode equivalent rather than its character code equivalent.
   }
	kMenuItemAttrUseVirtualKey = 1 shl 10;

  {
   * This item is drawn in a customized fashion by the application.
   * Causes custom menu item drawing Carbon events to be sent. This
   * attribute is available in CarbonLib 1.4 and Mac OS X 10.1, and
   * later.
   }
	kMenuItemAttrCustomDraw = 1 shl 11;

  {
   * This item is examined during command key matching by MenuKey,
   * MenuEvent, and IsMenuKeyEvent. Normally, visible menu items are
   * included in command key matching, but hidden menu items are
   * excluded (unless the item also has the Dynamic menu item
   * attribute). The IncludeInCmdKeyMatching attribute can be used to
   * force a hidden, non-dynamic menu item to be included in command
   * key matching when it normally wouldn't. This attribute is
   * available in CarbonLib 1.6 and Mac OS X 10.2 and later.
   }
	kMenuItemAttrIncludeInCmdKeyMatching = 1 shl 12;

  {
   * This item is automatically disabled if, when
   * kEventCommandUpdateStatus is sent for this item, no handler is
   * installed or all handlers return eventNotHandledErr. A return
   * value from any handler of any value other than eventNotHandledErr
   * will prevent automatic disabling. This attribute is useful for
   * applications that use kEventCommandUpdateStatus events for all
   * menu item enabling; previously, an application would need to
   * install UpdateStatus handlers on its application target to disable
   * all items in the application that were unnecessary when no
   * document windows were open. By setting this attribute, all menu
   * items will be disabled automatically unless specifically enabled
   * by an UpdateStatus handler on a window, control, or application
   * target. This attribute is available in Mac OS X 10.3 and later.
   }
	kMenuItemAttrAutoDisable = 1 shl 13;

  {
   * During command key matching, the Menu Manager uses a cache of the
   * available command keys to locate the menu item that matches an
   * event. Before returning this item, the Menu Manager sends a
   * kEventMenuEnableItems event to the menu containing the item, and a
   * kEventCommandUpdateStatus event to each item in the menu, so that
   * the item can be properly enabled or disabled. For some
   * applications, updating the item status for each item in the menu
   * is quite expensive, and also unnecessary since only a single item
   * actually needs to be updated. Setting this attribute indicates to
   * the Menu Manager that it only needs to send a
   * kEventCommandUpdateStatus event to this menu item before returning
   * it from command key matching; kEventMenuEnableItems will not be
   * sent to the menu, and no other menu item will receive
   * kEventCommandUpdateStatus. This attribute is available in Mac OS X
   * 10.3 and later.
   }
	kMenuItemAttrUpdateSingleItem = 1 shl 14;


{
 *  MenuTrackingMode
 *
 *  Summary:
 *    A menu tracking mode constant is part of the
 *    kEventMenuBeginTracking and kEventMenuChangeTrackingMode Carbon
 *    events. It indicates whether menus are being tracked using the
 *    mouse or keyboard.
 }
type
	MenuTrackingMode = UInt32;
const
{
   * Menus are being tracked using the mouse.
   }
	kMenuTrackingModeMouse = 1;

  {
   * Menus are being tracked using the keyboard.
   }
	kMenuTrackingModeKeyboard = 2;


{
 *  MenuEventOptions
 *
 *  Summary:
 *    Menu event options control how the menus are searched for an item
 *    matching a particular keyboard event. They are used with the
 *    IsMenuKeyEvent API.
 }
type
	MenuEventOptions = UInt32;
const
{
   * Disabled items are examined for a match.
   }
	kMenuEventIncludeDisabledItems = $0001;

  {
   * Don't hilite the menu title if a match is found.
   }
	kMenuEventQueryOnly = $0002;

  {
   * Don't look for a match in submenus of the starting menu.
   }
	kMenuEventDontCheckSubmenus = $0004;

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Menu Types                                                                        }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
type
	MenuID = SInt16;
	MenuItemIndex = UInt16;
	MenuItemIndex_fix = MenuItemIndex; { used as field type when a record declaration contains a MenuItemIndex field identifier }
	MenuItemIndexPtr = ^MenuItemIndex;
	MenuCommand = UInt32;
type
	MenuRef = ^OpaqueMenuRef; { an opaque type }
	OpaqueMenuRef = record end;
	MenuRef_fix = MenuRef; { used as field type when a record declaration contains a MenuRef field identifier }
	MenuRefPtr = ^MenuRef;
{ MenuHandle is old name for MenuRef}
type
	MenuHandle = MenuRef;

{
   A MenuBarHandle is a handle to a MenuBarHeader. An instance of this structure is returned
   by the GetMenuBar and GetNewMBar APIs. It is typedef'd to a plain Handle to retain
   source compatibility with previous versions of this header file.
}
type
	MenuBarHandle = Handle;

{
 *  MenuBarHeader
 *
 *  Summary:
 *    This structure is contained in a MenuBarHandle. It contains a
 *    list of the non-hierarchical menus that have been inserted into
 *    the menubar.
 *
 *  Discussion:
 *    The MenuBarHandle is a dynamically sized object which cannot be
 *    directly expressed as a C or Pascal structure. First is the
 *    MenuBarHeader structure, followed by a dynamically sized array of
 *    MenuBarMenus, one for each menu. This array is followed by the
 *    HMenuBarHeader, followed by another dynamically sized array of
 *    HMenuBarMenus, one for each hierarchical menu.
 }
type
	MenuBarHeaderPtr = ^MenuBarHeader;
	MenuBarHeader = record
{
   * Offset in bytes from the start of the header to the last menu in
   * the array of MenuBarMenus.
   }
		lastMenu: UInt16;

  {
   * Global coordinate of the right edge of the rightmost menu; unused
   * in a MenuBarHandle returned by GetMenuBar or GetNewMBar.
   }
		lastRight: SInt16;

  {
   * The MBDF resource ID; unused in a MenuBarHandle returned by
   * GetMenuBar or GetNewMBar.
   }
		mbResID: SInt16;
	end;

{
 *  HMenuBarHeader
 *
 *  Summary:
 *    This structure is contained in a MenuBarHandle. It contains a
 *    list of the hierarchical menus that have been inserted into the
 *    menubar with InsertMenu( menu, -1 ).
 *
 *  Discussion:
 *    The hierarchical portion of the menubar follows the
 *    non-hierarchical portion in a menubar handle. The hierarchical
 *    portion begins with the HMenuBarHeader structure, followed by a
 *    dynamically sized array of HMenuBarMenus.
 }
type
	HMenuBarHeaderPtr = ^HMenuBarHeader;
	HMenuBarHeader = record
{
   * Offset in bytes from the start of the header to the last menu in
   * the array of HMenuBarMenus.
   }
		lastHMenu: UInt16;

  {
   * Saved bits behind the hilited menu title; unused in a
   * MenuBarHandle returned by GetMenuBar or GetNewMBar.
   }
		menuTitleBits: PixMapHandle;
	end;

{
 *  MenuBarMenu
 *
 *  Summary:
 *    This structure contains a single menu in the menubar. It is an
 *    element in an array in the MenuBarHeader data structure.
 }
type
	MenuBarMenuPtr = ^MenuBarMenu;
	MenuBarMenu = record
{
   * A menu in the menubar.
   }
		menu: MenuRef;

  {
   * The global coordinate of the left edge of the menu title; unused
   * in a MenuBarHandle returned by GetMenuBar or GetNewMBar.
   }
		menuLeft: SInt16;
	end;

{
 *  HMenuBarMenu
 *
 *  Summary:
 *    This structure contains a single hierarchical menu in the
 *    menubar. It is an element in an array in the HMenuBarHeader data
 *    structure.
 }
type
	HMenuBarMenuPtr = ^HMenuBarMenu;
	HMenuBarMenu = record
{
   * An hierarchical menu in the menubar.
   }
		menu: MenuRef;

  {
   * This field is currently unused.
   }
		reserved: SInt16;
	end;
{
 *  MenuTrackingData
 *
 *  Summary:
 *    The MenuTrackingData structure contains information about a menu
 *    currently being displayed. It is used with the
 *    GetMenuTrackingData API.
 }
type
	MenuTrackingData = record
		menu: MenuRef;
		itemSelected: MenuItemIndex;
		itemUnderMouse: MenuItemIndex;
		itemRect: Rect;
		virtualMenuTop: SInt32;
		virtualMenuBottom: SInt32;
	end;
	MenuTrackingDataPtr = ^MenuTrackingData;

{
 *  Summary:
 *    A MenuItemDataFlags value indicates which fields of a
 *    MenuItemDataRec structure should be used by the
 *    Copy/SetMenuItemData APIs. All MenuItemDataFlags may be used when
 *    getting or setting the contents of a menu item; some may also be
 *    used when getting or setting information about the menu itself,
 *    if the item index given to Copy/SetMenuItemData is 0.
 }
const
{
   * Set or return the Str255 text of a menu using the
   * MenuItemDataRec.text field. If getting the text, the text field
   * must be initialized with a pointer to a Str255 variable before
   * calling CopyMenuItemData. If both kMenuItemDataText and
   * kMenuItemCFString are set on entry to CopyMenuItemData, the API
   * will determine whether the menu text was most recently set using a
   * Str255 or CFString, and return only that text format; the flags
   * value for the other format will be cleared. Valid for both menu
   * items and the menu title (if item number is 0).
   *
   * Note that this option is not supported in the 64-bit HIToolbox API.
   }
	kMenuItemDataText = 1 shl 0;

  {
   * Set or return the mark character of a menu item using the
   * MenuItemDataRec.mark field. Valid only for menu items.
   }
	kMenuItemDataMark = 1 shl 1;

  {
   * Set or return the command key of a menu item using the
   * MenuItemDataRec.cmdKey field. Valid only for menu items.
   }
	kMenuItemDataCmdKey = 1 shl 2;

  {
   * Set or return the command key glyph of a menu item using the
   * MenuItemDataRec.cmdKeyGlyph field. Valid only for menu items.
   }
	kMenuItemDataCmdKeyGlyph = 1 shl 3;

  {
   * Set or return the command key modifiers of a menu item using the
   * MenuItemDataRec.cmdKeyModifiers field. Valid only for menu items.
   }
	kMenuItemDataCmdKeyModifiers = 1 shl 4;

  {
   * Set or return the QuickDraw text style of a menu item using the
   * MenuItemDataRec.style field. Valid only for menu items.
   }
	kMenuItemDataStyle = 1 shl 5;

  {
   * Set or return the enable state of a menu using the
   * MenuItemDataRec.enabled field. Valid for both menu items and the
   * menu itself (if item number is 0).
   }
	kMenuItemDataEnabled = 1 shl 6;

  {
   * Set or return the enable state of a menu item icon using the
   * MenuItemDataRec.iconEnabled field. Valid only for menu items.
   }
	kMenuItemDataIconEnabled = 1 shl 7;

  {
   * Set or return the icon resource ID of a menu item using the
   * MenuItemDataRec.iconID field. Valid only for menu items.
   *
   * Note that this option is not supported in the 64-bit HIToolbox API.
   }
	kMenuItemDataIconID = 1 shl 8;

  {
   * Set or return the icon handle of a menu item using the
   * MenuItemDataRec.iconType and MenuItemDataRec.iconHandle fields.
   * Both fields must be initialized if setting the icon handle; both
   * fields will be returned when getting the handle. The iconType
   * field should contain one of the constants kMenuIconType,
   * kMenuShrinkIconType, kMenuSmallIconType, kMenuColorIconType,
   * kMenuIconSuiteType, kMenuIconRefType, kMenuCGImageRefType,
   * kMenuSystemIconSelectorType, or kMenuIconResourceType. An icon
   * handle may be a handle to an ICON resource, a SICN resource, a
   * cicn resource, an IconSuite, an IconRef, a CGImageRef, an OSType,
   * or a CFStringRef. Valid only for menu items. When used with
   * CopyMenuItemData, the caller does not need to release the returned
   * icon handle.
   }
	kMenuItemDataIconHandle = 1 shl 9;

  {
   * Set or return the command ID of a menu item using the
   * MenuItemDataRec.cmdID field. Valid only for menu items.
   }
	kMenuItemDataCommandID = 1 shl 10;

  {
   * Set or return the text encoding of a menu item using the
   * MenuItemDataRec.encoding field. Valid only for menu items.
   *
   *
   * Note that this option is not supported in the 64-bit HIToolbox API.
   }
	kMenuItemDataTextEncoding = 1 shl 11;

  {
   * Set or return the menu ID of a item's submenu using the
   * MenuItemDataRec.submenuID field. Valid only for menu items.
   }
	kMenuItemDataSubmenuID = 1 shl 12;

  {
   * Set or return the menu handle of an item's submenu using the
   * MenuItemDataRec.submenuHandle field. Valid only for menu items.
   * When used with CopyMenuItemData, the caller does not need to
   * release the returned MenuRef.
   }
	kMenuItemDataSubmenuHandle = 1 shl 13;

  {
   * Set or return the QuickDraw font ID of a menu item using the
   * MenuItemDataRec.fontID field. Valid only for menu items.
   }
	kMenuItemDataFontID = 1 shl 14;

  {
   * Set or return the refcon of a menu using the
   * MenuItemDataRec.refcon field. Valid for both menu items and the
   * menu itself (if item number is 0).
   }
	kMenuItemDataRefcon = 1 shl 15;

  {
   * Set or return the attributes of a menu using the
   * MenuItemDataRec.attr field. Valid for both menu items, in which
   * case the attr field should contain values from the
   * MenuItemAttributes enumeration, and for the menu itself (if item
   * number is 0), in which case the attr field should contain values
   * from the MenuAttributes enumeration.
   }
	kMenuItemDataAttributes = 1 shl 16;

  {
   * Set or return the CFString text of a menu using the
   * MenuItemDataRec.cfText field. If setting the CFString text, the
   * Menu Manager increments the refcount of the text; the caller may
   * safely release the text after setting it. If getting the CFString
   * text, the caller receives a copy of the text owned by the Menu
   * Manager; modifications on the text by the caller will have no
   * effect on the text of the menu, and the caller should release the
   * text when finished with it. If both kMenuItemDataText and
   * kMenuItemCFString are set on entry to CopyMenuItemData, the API
   * will determine whether the menu text was most recently set using a
   * Str255 or CFString, and return only that text format; the flags
   * value for the other format will be cleared. Valid for both menu
   * items and the menu title (if item number is 0). When used with
   * CopyMenuItemData, the caller must release the returned CFStringRef.
   }
	kMenuItemDataCFString = 1 shl 17;

  {
   * Set or return the properties of a menu using the
   * MenuItemDataRec.properties field. If setting the properties, the
   * properties field should contain a collection with the new
   * properties; existing menu properties with the same collection
   * creator and tag will be replaced by the new properties. If getting
   * the properties, the properties field should either be set to NULL
   * or to a valid Collection. If NULL, a new collection is allocated
   * by the CopyMenuItemData and returned in the properties field. If
   * not NULL, the entire contents of the collection are replaced by
   * the properties of the menu. Valid for both menu items and the menu
   * itself (if item number is 0).
   }
	kMenuItemDataProperties = 1 shl 18;

  {
   * Set or return the item indent level of a menu item using the
   * MenuItemDataRec.indent field. Valid only for menu items.
   }
	kMenuItemDataIndent = 1 shl 19;

  {
   * Set or return the virtual key code keyboard equivalent of a menu
   * item using the MenuItemDataRec.cmdVirtualKey field. Valid only for
   * menu items. On output, only valid if the item has the
   * kMenuItemAttrUseVirtualKeyCode attribute. Available in Mac OS X
   * and CarbonLib 1.1 and later.
   }
	kMenuItemDataCmdVirtualKey = 1 shl 20;

  {
   * Set or return the attributed text of a menu item using the
   * MenuItemDataRec.attributedText field. If setting the attributed
   * text, the Menu Manager increments the refcount of the text; the
   * caller may safely release the text after setting it. If getting
   * the attributed text, the caller receives a copy of the text owned
   * by the Menu Manager; modifications on the text by the caller will
   * have no effect on the text of the menu, and the caller should
   * release the text when finished with it. Valid only for menu items.
   * Available in Mac OS X 10.5 and later.
   }
	kMenuItemDataAttributedText = 1 shl 21;

  {
   * Set or return the CTFontRef of a menu using the
   * MenuItemDataRec.font field. If setting the font, the Menu Manager
   * increments the refcount of the font; the caller may safely release
   * the font after setting it. If getting the font, the caller
   * receives a retained instance of the font owned by the Menu
   * Manager; the caller should release the font when finished with it.
   * Valid for both menu items and the menu title (if item number is
   * 0). Available in Mac OS X 10.5 and later.
   }
	kMenuItemDataFont = 1 shl 22;
	kMenuItemDataAllDataVersionOne = $000FFFFF;
	kMenuItemDataAllDataVersionTwo = kMenuItemDataAllDataVersionOne or kMenuItemDataCmdVirtualKey;
	kMenuItemDataAllDataVersionThree = kMenuItemDataAllDataVersionTwo or kMenuItemDataAttributedText or kMenuItemDataFont;

type
	MenuItemDataFlags = UInt64;

{
 *  MenuItemDataRec
 *
 *  Summary:
 *    The MenuItemDataRec structure is used to get and change aspects
 *    of a menu item. It is used with the Copy/SetMenuItemData APIs.
 *
 *  Discussion:
 *    When using this structure with Copy/SetMenuItemData, the caller
 *    must first set the whichData field to a combination of
 *    MenuItemDataFlags indicating which specific data should be
 *    retrieved or set. Some fields also require initialization before
 *    calling CopyMenuItemData; see the individual MenuItemDataFlags
 *    documentation for details. When used with CopyMenuItemData, the
 *    whichData field will be updated on exit to indicate which data
 *    fields have actually been returned. If the caller requests data
 *    that does not exist for that menu or menu item, the corresponding
 *    bit in the whichData field will be cleared, and the field in the
 *    MenuItemDataRec for that data will be set to zero.
 }
type
	MenuItemDataRecPtr = ^MenuItemDataRec;
	MenuItemDataRec = record
		whichData: MenuItemDataFlags;
		text: StringPtr;
		mark: UniChar;
		cmdKey: UniChar;
		cmdKeyGlyph: UInt32;
		cmdKeyModifiers: UInt32;
		style: Style_fix;
		enabled: Boolean;
		iconEnabled: Boolean;
		filler1: UInt8;
		iconID: SInt32;
		iconType: UInt32;
		iconHandle: Handle;
		cmdID: MenuCommand;
		encoding: TextEncoding;
		submenuID: MenuID;
		submenuHandle: MenuRef;
		fontID: SInt32;
		refcon: URefCon;
		attr: OptionBits;
		cfText: CFStringRef;
		properties: Collection;
		indent: UInt32;
		cmdVirtualKey: UInt16;
		attributedText: CFAttributedStringRef;
		font: CTFontRef;
	end;
type
	MenuItemDataPtr = MenuItemDataRecPtr;
	MenuItemID = UInt32;

{
 *  MenuDefType
 *
 *  Summary:
 *    Types of custom menu definitions.
 }
const
{
   * A custom menu definition using a function pointer based on the
   * pre-Carbon MDEF model. This type of custom menu definition is not
   * supported by 64-bit HIToolbox.
   }
	kMenuDefProcPtr = 0;

  {
   * A custom menu definition using an HIView subclass. Available in
   * Mac OS X 10.3 and later.
   }
	kMenuDefClassID = 1;

type
	MenuDefType = UInt32;
type
	MenuDefUPP = UnivPtr;


{
 *  MenuDefSpec
 *
 *  Summary:
 *    Specifies a custom menu definition.
 }
type
	MenuDefSpec = record
{
   * The type of menu definition: either kMenuDefProcPtr or
   * kMenuDefClassID. kMenuDefClassID may only be used in Mac OS X 10.3
   * and later. On 64-bit HIToolbox, kMenuDefProcPtr is not supported.
   }
		defType: MenuDefType;
		case SInt16 of
		0: (
			defProc: MenuDefUPP;
			);
		1: (
			classID: CFStringRef;
			initEvent: EventRef;
			);
	end;
	MenuDefSpecPtr = ^MenuDefSpec;
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ Menu Manipulation                                                                 }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}


{
 *  Summary:
 *    Menu dismissal causation constants
 }
const
{
   * The menu was dismissed by the selection of a menu item.
   }
	kHIMenuDismissedBySelection = 1;

  {
   * The menu was dismissed because the user canceled menu tracking.
   }
	kHIMenuDismissedByUserCancel = 2;

  {
   * The menu was dismissed by a mouse-down somewhere that did not
   * result in menu item selection.
   }
	kHIMenuDismissedByMouseDown = 3;

  {
   * The menu was dismissed by a mouse-up.
   }
	kHIMenuDismissedByMouseUp = 4;

  {
   * The menu was dismissed by a keyboard event.
   }
	kHIMenuDismissedByKeyEvent = 5;

  {
   * The menu was dismissed because the current application was no
   * longer frontmost.
   }
	kHIMenuDismissedByAppSwitch = 6;

  {
   * The menu was dismissed because menu tracking mode timed out.
   }
	kHIMenuDismissedByTimeout = 7;

  {
   * The menu was dismissed by the CancelMenuTracking API.
   }
	kHIMenuDismissedByCancelMenuTracking = 8;

  {
   * The menu was dismissed because the active window changed.
   }
	kHIMenuDismissedByActivationChange = 9;

  {
   * The menu was dismissed bcause the user focus window changed, or
   * because keyboard focus was removed from the current process.
   }
	kHIMenuDismissedByFocusChange = 10;


const
	kMenuPropertyPersistent = $00000001; { whether this property gets saved when archiving the menu; however, ignored in Mac OS X 10.4}


{
 *  GetMenuTrackingData()
 *
 *  Summary:
 *    Gets information about the menu currently selected by the user.
 *
 *  Discussion:
 *    This API replaces direct access to the low-memory globals
 *    TopMenuItem, AtMenuBottom, MenuDisable, and mbSaveLoc. It is only
 *    valid to call this API while menu tracking is occurring. This API
 *    will most commonly be used by custom MDEFs.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Parameters:
 *
 *    theMenu:
 *      The menu about which to get tracking information. May be NULL
 *      to get information about the menu that the user is currently
 *      selecting. If the menu is not currently open, menuNotFoundErr
 *      is returned.
 *
 *    outData:
 *      On exit, contains tracking data about the menu. On CarbonLib,
 *      the itemRect field is not supported and is always set to an
 *      empty rect.
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   not available
 }
function GetMenuTrackingData( theMenu: MenuRef; var outData: MenuTrackingData ): OSStatus; external name '_GetMenuTrackingData';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)



const
	kHierarchicalFontMenuOption = $00000001;


const
	gestaltContextualMenuAttr = FourCharCode('cmnu');
	gestaltContextualMenuUnusedBit = 0;
	gestaltContextualMenuTrapAvailable = 1;
	gestaltContextualMenuHasAttributeAndModifierKeys = 2; { Contextual Menu Manager supports keyContextualMenuAttributes and keyContextualMenuModifiers }
	gestaltContextualMenuHasUnicodeSupport = 3; { Contextual Menu Manager supports typeUnicodeText and typeCFStringRef }


{
 *  Summary:
 *    Values indicating what kind of help the application supports
 }
const
{
   * The application does not support any help. The Menu Manager will
   * put an appropriate help string into the contextual menu and
   * disable the Help item.
   }
	kCMHelpItemNoHelp = 0;

  {
   * The application supports Apple Guide help. The Menu Manager will
   * put the name of the main Guide file into the contextual menu and
   * enable the Help item.
   }
	kCMHelpItemAppleGuide = 1;

  {
   * The application supports some other form of help. In this case,
   * the application must also pass a valid string into the
   * inHelpItemString parameter of ContextualMenuSelect. This string
   * will be the text of the Help item in the contextual menu, and the
   * Help item will be enabled.
   }
	kCMHelpItemOtherHelp = 2;

  {
   * The application does not support any help. The Menu Manager will
   * remove the Help item from the contextual menu. This constant is
   * available in Mac OS X and CarbonLib 1.6, and later; however, in
   * CarbonLib it is translated to kCMHelpItemNoHelp, and the Help item
   * is only disabled, not removed.
   }
	kCMHelpItemRemoveHelp = 3;


{
 *  Summary:
 *    Values indicating what was chosen from a contextual menu
 }
const
{
   * The user did not choose an item from the contextual menu and the
   * application should do no further processing of the event.
   }
	kCMNothingSelected = 0;

  {
   * The user chose one of the application's items from the menu. The
   * application can examine the outMenuID and outMenuItem parameters
   * of ContextualMenuSelect to see what the menu selection was, and it
   * should then handle the selection appropriately.
   }
	kCMMenuItemSelected = 1;

  {
   * The user chose the Help item from the menu. The application should
   * open an Apple Guide database to a section appropriate for the
   * selection. If the application supports some other form of help, it
   * should be presented instead.
   }
	kCMShowHelpSelected = 3;


{
 *  Summary:
 *    AERecord keywords used by the ExamineContext method of a
 *    Contextual Menu plugin to specify menu item contents.
 }
const
{
   * Specifies the text of an item in a contextual menu. Data for this
   * parameter can be in one of several formats. In Mac OS 7/8/9.x and
   * Mac OS X 10.0 and 10.1, typeChar and typeIntlText are supported.
   * In Mac OS X 10.2 and later, typeStyledText, typeAEText,
   * typeUnicodeText, and typeCFStringRef are also supported. If you
   * provide data as typeCFStringRef, the Contextual Menu Manager will
   * automatically release the CFStringRef once the menu has been
   * displayed. If you need the CFStringRef to have a longer timetime,
   * your plugin should retain the CFStringRef before inserting it into
   * the AERecord.
   }
	keyContextualMenuName = FourCharCode('pnam');

  {
   * Specifies the command ID of an item in a contextual menu. Data for
   * this parameter should be typeSInt32.
   }
	keyContextualMenuCommandID = FourCharCode('cmcd');

  {
   * Specifies a contextual menu item with a submenu. Typically used
   * with AEPutKeyDesc to add an entire AEDesc containing the submenu
   * as the data for the parameter.
   }
	keyContextualMenuSubmenu = FourCharCode('cmsb');

  {
   * Specifies the menu item attributes of an item in a contextual
   * menu. Data for this parameter should be typeSInt32. Available in
   * Mac OS X 10.2 and later.
   }
	keyContextualMenuAttributes = FourCharCode('cmat');

  {
   * Specifies the modifier keys of an item in a contextual menu (see
   * kMenuShiftModifier, kMenuControlModifier, etc.) Data for this
   * parameter should be typeSInt32. Using this parameter together with
   * the keyContextualMenuAttributes parameter, it is possible to
   * create a contextual menu with dynamic items which change according
   * to the modifier keys pressed by the user. Available in Mac OS X
   * 10.2 and later.
   }
	keyContextualMenuModifiers = FourCharCode('cmmd');


{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  Contextual Menu Plugin Interface                                                    }
{  For Mac OS X 10.1, we support a new type of Contextual Menu Plugin: the CFPlugIn    }
{  based plugin.  Each plugin must be in a CFPlugIn in the Contextual Menu Items       }
{  folder in one of these paths:                                                       }
{      /System/Library/Contextual Menu Items/                                          }
{      /Library/Contextual Menu Items/                                                 }
{      ~/Library/Contextual Menu Items/                                                }
{  It must export the following functions using the following interface or a C++       }
{  interface inheriting from IUnknown and including similar functions.                 }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
(*
{ The Contextual Menu Manager will only load CFPlugIns of type kContextualMenuTypeID }
#define kContextualMenuTypeID ( CFUUIDGetConstantUUIDWithBytes( NULL, \
  0x2F, 0x65, 0x22, 0xE9, 0x3E, 0x66, 0x11, 0xD5, \
  0x80, 0xA7, 0x00, 0x30, 0x65, 0xB3, 0x00, 0xBC ) )
 { 2F6522E9-3E66-11D5-80A7-003065B300BC }

{ Contextual Menu Plugins must implement this Contexual Menu Plugin Interface }
#define kContextualMenuInterfaceID    ( CFUUIDGetConstantUUIDWithBytes( NULL, \
  0x32, 0x99, 0x7B, 0x62, 0x3E, 0x66, 0x11, 0xD5, \
  0xBE, 0xAB, 0x00, 0x30, 0x65, 0xB3, 0x00, 0xBC ) )
 { 32997B62-3E66-11D5-BEAB-003065B300BC }

#define CM_IUNKNOWN_C_GUTS \
   void *_reserved; \
 SInt32 (*QueryInterface)(void *thisPointer, CFUUIDBytes iid, void ** ppv); \
   UInt32 (*AddRef)(void *thisPointer); \
 UInt32 (*Release)(void *thisPointer)

{ The function table for the interface }
type
	ContextualMenuInterfaceStruct = record
CM_IUNKNOWN_C_GUTS;
    OSStatus ( *ExamineContext )(
          void*               thisInstance,
          const AEDesc*       inContext,
         AEDescList*         outCommandPairs );
 OSStatus ( *HandleSelection )(
         void*               thisInstance,
          AEDesc*             inContext,
         SInt32              inCommandID );
 void ( *PostMenuCleanup )(
         void*               thisInstance );
	end;
*)
{
 *  CMPluginExamineContext()
 *
 *  Availability:
 *    Implemented by client
 }
function CMPluginExamineContext( thisInstance: UnivPtr; const (*var*) inContext: AEDesc; var outCommandPairs: AEDescList ): OSStatus; external name '_CMPluginExamineContext';


{
 *  CMPluginHandleSelection()
 *
 *  Availability:
 *    Implemented by client
 }
function CMPluginHandleSelection( thisInstance: UnivPtr; var inContext: AEDesc; inCommandID: SInt32 ): OSStatus; external name '_CMPluginHandleSelection';


{
 *  CMPluginPostMenuCleanup()
 *
 *  Availability:
 *    Implemented by client
 }
procedure CMPluginPostMenuCleanup( thisInstance: UnivPtr ); external name '_CMPluginPostMenuCleanup';


{ previously in LowMem.h.  This functions return the menu ID of the hilited menu }

const
{ menu defProc messages }
	kMenuDrawMsg = 0;
	kMenuSizeMsg = 2;
	kMenuPopUpMsg = 3;    { position the popup menu rect appropriately }
	kMenuCalcItemMsg = 5;
	kMenuThemeSavvyMsg = 7;    { is your MDEF theme-savvy?  If so, return kThemeSavvyMenuResponse in the whichItem parameter}
	kMenuInitMsg = 8;    { Return an error code in *whichItem to indicate success or failure. Only supported in Carbon. }
	kMenuDisposeMsg = 9;    { The menu is being destroyed. Only supported in Carbon.}
	kMenuFindItemMsg = 10;   { Determine which item is under the mouse. Only supported in Carbon.}
	kMenuHiliteItemMsg = 11;   { Hilite the specified item. Only supported in Carbon.}
	kMenuDrawItemsMsg = 12;   { Draw a range of items. Only supported in Carbon.}
	mDrawMsg = kMenuDrawMsg; { obsolete constant name}
	mSizeMsg = kMenuSizeMsg; { obsolete constant name}
	mPopUpMsg = kMenuPopUpMsg; { obsolete constant name}
	mCalcItemMsg = kMenuCalcItemMsg; { obsolete constant name}


const
	kThemeSavvyMenuResponse = $7473; { should be returned in *whichItem when handling kMenuThemeSavvyMsg}


{
 *  MDEFHiliteItemData
 *
 *  Summary:
 *    The MDEFHiliteItemData structure contains information about which
 *    menu items should be hilited and unhilited as the user moves
 *    through the menus. It is used by menu definition functions, which
 *    receive a pointer to an MDEFHiliteItemData structure as the
 *    whichItem parameter during kMenuHiliteItemMsg.
 }
type
	MDEFHiliteItemData = record
{
   * The item that was previously selected. It should be redrawn in an
   * unhilited state. May be zero if no item was previously selected.
   }
		previousItem: MenuItemIndex;

  {
   * The item that is now selected. It should be redrawn in a hilited
   * state. May be zero if no item is now selected.
   }
		newItem: MenuItemIndex;

  {
   * A CoreGraphics context that the MDEF should draw into. The Menu
   * Manager will flush the context after the MDEF has returned.
   }
		context: UnivPtr;
	end;
	MDEFHiliteItemDataPtr = ^MDEFHiliteItemData;
type
	HiliteMenuItemData = MDEFHiliteItemData;
	HiliteMenuItemDataPtr = MDEFHiliteItemDataPtr;

{
 *  MDEFDrawData
 *
 *  Summary:
 *    The MDEFDrawData structure contains information needed to draw a
 *    menu. It is used by menu definition functions, which receive a
 *    pointer to an MDEFDrawData structure as the whichItem parameter
 *    during kMenuDrawMsg.
 }
type
	MDEFDrawData = record
{
   * Information about the menu being drawn. The MDEF should fill in
   * the virtualMenuTop and virtualMenuBottom fields of this structure
   * while drawing the menu.
   }
		trackingData: MenuTrackingData;

  {
   * A CoreGraphics context that the MDEF should draw into. The Menu
   * Manager will flush the context after the MDEF has returned.
   }
		context: UnivPtr;
	end;
	MDEFDrawDataPtr = ^MDEFDrawData;

{
 *  MDEFFindItemData
 *
 *  Summary:
 *    The MDEFFindItemData structure contains information needed to
 *    determine which item is currently selected by the user. It is
 *    used by menu definition functions, which receive a pointer to an
 *    MDEFDrawData structure as the whichItem parameter during
 *    kMenuFindItemMsg.
 }
type
	MDEFFindItemData = record
{
   * Information about the menu being drawn. The MDEF should fill in
   * the itemSelected, itemUnderMouse, and itemRect fields of this
   * structure after determining which item is at the specified point.
   }
		trackingData: MenuTrackingData;

  {
   * A CoreGraphics context that the MDEF should draw into if it needs
   * to scroll the menu during the FindItem message. The Menu Manager
   * will flush the context after the MDEF has returned.
   }
		context: UnivPtr;
	end;
	MDEFFindItemDataPtr = ^MDEFFindItemData;

{
 *  MDEFDrawItemsData
 *
 *  Summary:
 *    The MDEFDrawItemsData structure contains information about which
 *    menu items to redraw. It is used by menu definition functions,
 *    which receive a pointer to an MDEFDrawItemsData structure as the
 *    whichItem parameter during kMenuDrawItemsMsg.
 }
type
	MDEFDrawItemsData = record
{
   * The first item to draw.
   }
		firstItem: MenuItemIndex;

  {
   * The last item to draw.
   }
		lastItem: MenuItemIndex;

  {
   * Information about the menu's tracking state. The virtualMenuTop
   * and virtualMenuBottom fields in this structure will be the most
   * useful in handling the DrawItems message.
   }
		trackingData: MenuTrackingDataPtr;

  {
   * A CoreGraphics context that the MDEF should draw into. The Menu
   * Manager will flush the context after the MDEF returns.
   }
		context: UnivPtr;
	end;
	MDEFDrawItemsDataPtr = ^MDEFDrawItemsData;
{ obsolete menu color table constants}
const
	mctAllItems = -98;  {search for all Items for the given ID}
	mctLastIDIndic = -99;   {last color table entry has this in ID field}

type
	MCEntry = record
		mctID: MenuID;                  {menu ID.  ID = 0 is the menu bar}
		mctItem: SInt16;                {menu Item. Item = 0 is a title}
		mctRGB1: RGBColor;                {usage depends on ID and Item}
		mctRGB2: RGBColor;                {usage depends on ID and Item}
		mctRGB3: RGBColor;                {usage depends on ID and Item}
		mctRGB4: RGBColor;                {usage depends on ID and Item}
		mctReserved: SInt16;            {reserved for internal use}
	end;
	MCEntryPtr = ^MCEntry;
type
	MCTable = array [0..0] of MCEntry;	{ARRAY [1..numEntries] of MCEntry}
	MCTablePtr = ^MCTable;
	MCTableHandle = ^MCTablePtr;
type
	MenuCRsrc = record
		numEntries: SInt16;             {number of entries}
		mcEntryRecs: MCTable;            {ARRAY [1..numEntries] of MCEntry}
	end;
	MenuCRsrcPtr = ^MenuCRsrc;
type
	MenuCRsrcHandle = ^MenuCRsrcPtr;


const
{
   * Menu item command ID to indicate a hierarchical menu; the item
   * icon ID is the hierarchical menu ID. This constant is deprecated.
   * Use SetMenuItemHierarchicalID or SetMenuItemHierarchicalMenu
   * instead of using this constant.
   }
	hMenuCmd = 27;

  {
   * A menu ID used with InsertMenu to insert a menu into the
   * hierarchical portion of the menubar. Rather than inserting menus
   * into the hierarchical portion of the menubar, we recommend that
   * your application use SetMenuItemHierarchicalMenu to directly
   * specify the submenu's MenuRef.
   }
	kInsertHierarchicalMenu = -1;

  {
   * The old name for kInsertHierarchicalMenu. This constant is
   * deprecated.
   }
	hierMenu = -1;


type
	MenuBarDefProcPtr = function( selector: SInt16; message: SInt16; parameter1: SInt16; parameter2: SIGNEDLONG ): SIGNEDLONG;
	MenuHookProcPtr = procedure;
	MBarHookProcPtr = function( var menuRect: Rect ): SInt16;
	MenuBarDefUPP = MenuBarDefProcPtr;
	MenuHookUPP = MenuHookProcPtr;
	MBarHookUPP = MBarHookProcPtr;
{
 *  NewMenuBarDefUPP()
 *
 *  Availability:
 *    Mac OS X:         not available
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   available as macro/inline
 }

{
 *  NewMenuHookUPP()
 *
 *  Availability:
 *    Mac OS X:         not available
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   available as macro/inline
 }

{
 *  NewMBarHookUPP()
 *
 *  Availability:
 *    Mac OS X:         not available
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   available as macro/inline
 }

{
 *  DisposeMenuBarDefUPP()
 *
 *  Availability:
 *    Mac OS X:         not available
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   available as macro/inline
 }

{
 *  DisposeMenuHookUPP()
 *
 *  Availability:
 *    Mac OS X:         not available
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   available as macro/inline
 }

{
 *  DisposeMBarHookUPP()
 *
 *  Availability:
 *    Mac OS X:         not available
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   available as macro/inline
 }

{
 *  InvokeMenuBarDefUPP()
 *
 *  Availability:
 *    Mac OS X:         not available
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   available as macro/inline
 }

{
 *  InvokeMenuHookUPP()
 *
 *  Availability:
 *    Mac OS X:         not available
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   available as macro/inline
 }

{
 *  InvokeMBarHookUPP()
 *
 *  Availability:
 *    Mac OS X:         not available
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   available as macro/inline
 }

{$endc} {TARGET_OS_MAC}

{$ifc not defined MACOSALLINCLUDE or not MACOSALLINCLUDE}
implementation

{$ifc TARGET_OS_MAC}

{$endc} {TARGET_OS_MAC}

end.

{$endc} {not MACOSALLINCLUDE}
