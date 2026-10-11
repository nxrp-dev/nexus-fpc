{
     File:       HIToolbox/HIDataBrowser.h

     Contains:   API and type definitions related to Data Browser.

     Version:    HIToolbox-624~3

     Copyright:  © 1999-2008 by Apple Computer, Inc., all rights reserved.

     Bugs?:      For bug reports, consult the following page on
                 the World Wide Web:

                     http://bugs.freepascal.org

}
{       Initial Pascal Translation:  Jonas Maebe, <jonas@freepascal.org>, October 2009 }
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
unit HIDataBrowser;
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
uses MacOsApi.MacTypes,MacOsApi.TextEdit,MacOsApi.AXUIElement,MacOsApi.AEDataModel,MacOsApi.CFBase,MacOsApi.Events,MacOsApi.QuickdrawTypes,MacOsApi.IconsCore,MacOsApi.Icons,MacOsApi.CFData,MacOsApi.CFDictionary,MacOsApi.DateTimeUtils,MacOsApi.Drag,MacOsApi.TextCommon,MacOsApi.Appearance,MacOsApi.CarbonEvents,MacOsApi.Controls,MacOsApi.Lists,MacOsApi.MacHelp,MacOsApi.Menus,MacOsApi.CFString,MacOsApi.CGBase,MacOsApi.HIObject;
{$ELSE FPC_DOTTEDUNITS}
uses MacTypes,TextEdit,AXUIElement,AEDataModel,CFBase,Events,QuickdrawTypes,IconsCore,Icons,CFData,CFDictionary,DateTimeUtils,Drag,TextCommon,Appearance,CarbonEvents,Controls,Lists,MacHelp,Menus,CFString,CGBase,HIObject;
{$ENDIF FPC_DOTTEDUNITS}
{$endc} {not MACOSALLINCLUDE}


{$ifc TARGET_OS_MAC}


{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{    ¥ DATA BROWSER                                                                    }
{     (CDEF 29)                                                                        }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  This control implements a user interface component for browsing (optionally)        }
{  hierarchical data structures. The browser supports multiple presentation styles     }
{  including, but not limited to:                                                      }
{      kDataBrowserListView   - items and item properties in                           }
{                               multi-column (optionally outline) format               }
{      kDataBrowserColumnView - in-place browsing using fixed navigation columns       }
{  The browser manages all view styles through a single high-level interface.          }
{  The high-level interface makes the following assumptions:                           }
{      - Items have unique 32-bit identifiers (0 is reserved)                          }
{      - Items have two kinds of named and typed properties:                           }
{           - Predefined attribute properties ( < 1024 )                               }
{             (including some display properties)                                      }
{           - Client-defined display properties ( >= 1024 )                            }
{      - Some items are containers of other items                                      }
{      - Items may be sorted by any property                                           }
{  Because a browser doesn't know all details about the type of objects it manages,    }
{  some implementation responsibility is best handled by its client. The client must   }
{  provide a set of callback routines which define the item hierarchy and help to      }
{  populate the browser with items. The client may also provide callbacks for handling }
{  custom data types and doing low-level event management.                             }
{  The API is subdivided into a "universal" set of routines that applies to all view   }
{  styles, and a set of routines unique to each view style. kDataBrowserListView and   }
{  kDataBrowserColumnView share an (internal) TableView abstract base class. The       }
{  TableView formatting options and API applies to both of these view styles.          }
{  NOTE: This control is only available with CarbonLib 1.1.                            }
{  NOTE: This control must be created with the CreateDataBrowserControl API in         }
{        CarbonLib 1.1 through 1.4. In Mac OS X and CarbonLib 1.5 and later, you       }
{        may use the control's procID (29) to create the control with NewControl       }
{        or with a 'CNTL' resource.                                                    }
{ The HIObject class ID for the HIDataBrowser class. }


{$ALIGN MAC68K}

{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kHIDataBrowserClassID CFSTRP('com.apple.HIDataBrowser')}
{$endc}
{ Control Kind Tag }
const
	kControlKindDataBrowser = FourCharCode('datb');

{ Error Codes }
const
	errDataBrowserNotConfigured = -4970;
	errDataBrowserItemNotFound = -4971;
	errDataBrowserItemNotAdded = -4975;
	errDataBrowserPropertyNotFound = -4972;
	errDataBrowserInvalidPropertyPart = -4973;
	errDataBrowserInvalidPropertyData = -4974;
	errDataBrowserPropertyNotSupported = -4979; { Return from DataBrowserGetSetItemDataProc }

const
{ Generic Control Tags }
	kControlDataBrowserIncludesFrameAndFocusTag = FourCharCode('brdr'); { Boolean }
	kControlDataBrowserKeyFilterTag = kControlKeyFilterTag;
	kControlDataBrowserEditTextKeyFilterTag = kControlDataBrowserKeyFilterTag;
	kControlDataBrowserEditTextValidationProcTag = FourCharCode('vali'); { ControlEditTextValidationUPP. Called when a key filter can't be: after cut, paste, etc.}

{ Data Browser View Styles }
type
	DataBrowserViewStyle = OSType;
const
	kDataBrowserNoView = $3F3F3F3F; { Error State }
	kDataBrowserListView = FourCharCode('lstv');
	kDataBrowserColumnView = FourCharCode('clmv');

{ Selection Flags }
type
	DataBrowserSelectionFlags = UInt32;
const
	kDataBrowserDragSelect = 1 shl 0; { Å ListMgr lNoRect }
	kDataBrowserSelectOnlyOne = 1 shl 1; { Å ListMgr lOnlyOne }
	kDataBrowserResetSelection = 1 shl 2; { Å ListMgr lNoExtend }
	kDataBrowserCmdTogglesSelection = 1 shl 3; { Å ListMgr lUseSense }
	kDataBrowserNoDisjointSelection = 1 shl 4; { Å ListMgr lNoDisjoint }
	kDataBrowserAlwaysExtendSelection = 1 shl 5; { Å ListMgr lExtendDrag }
	kDataBrowserNeverEmptySelectionSet = 1 shl 6; { Å ListMgr lNoNilHilite }

{ Data Browser Sorting }
type
	DataBrowserSortOrder = UInt16;
const
	kDataBrowserOrderUndefined = 0;    { Not currently supported }
	kDataBrowserOrderIncreasing = 1;
	kDataBrowserOrderDecreasing = 2;

{ Data Browser Item Management }
type
	DataBrowserItemID = UNSIGNEDLONG;
	DataBrowserItemIDPtr = ^DataBrowserItemID;
const
	kDataBrowserNoItem = 0;     { Reserved DataBrowserItemID }

type
	DataBrowserItemState = UInt32;
const
	kDataBrowserItemNoState = 0;
	kDataBrowserItemAnyState = $FFFFFFFF;
	kDataBrowserItemIsSelected = 1 shl 0;
	kDataBrowserContainerIsOpen = 1 shl 1;
	kDataBrowserItemIsDragTarget = 1 shl 2; { During a drag operation }

{ Options for use with RevealDataBrowserItem }
type
	DataBrowserRevealOptions = UInt8;
const
	kDataBrowserRevealOnly = 0;
	kDataBrowserRevealAndCenterInView = 1 shl 0;
	kDataBrowserRevealWithoutSelecting = 1 shl 1;

{ Set operations for use with SetDataBrowserSelectedItems }
type
	DataBrowserSetOption = UInt32;
const
	kDataBrowserItemsAdd = 0;    { add specified items to existing set }
	kDataBrowserItemsAssign = 1;    { assign destination set to specified items }
	kDataBrowserItemsToggle = 2;    { toggle membership state of specified items }
	kDataBrowserItemsRemove = 3;     { remove specified items from existing set }

{ Commands for use with MoveDataBrowserSelectionAnchor }
type
	DataBrowserSelectionAnchorDirection = UInt32;
const
	kDataBrowserSelectionAnchorUp = 0;
	kDataBrowserSelectionAnchorDown = 1;
	kDataBrowserSelectionAnchorLeft = 2;
	kDataBrowserSelectionAnchorRight = 3;

{ Edit menu command IDs for use with Enable/ExecuteDataBrowserEditCommand }
type
	DataBrowserEditCommand = UInt32;
const
	kDataBrowserEditMsgUndo = kHICommandUndo;
	kDataBrowserEditMsgRedo = kHICommandRedo;
	kDataBrowserEditMsgCut = kHICommandCut;
	kDataBrowserEditMsgCopy = kHICommandCopy;
	kDataBrowserEditMsgPaste = kHICommandPaste;
	kDataBrowserEditMsgClear = kHICommandClear;
	kDataBrowserEditMsgSelectAll = kHICommandSelectAll;

{ Notifications used in DataBrowserItemNotificationProcPtr }
type
	DataBrowserItemNotification = UInt32;
const
	kDataBrowserItemAdded = 1;    { The specified item has been added to the browser }
	kDataBrowserItemRemoved = 2;    { The specified item has been removed from the browser }
	kDataBrowserEditStarted = 3;    { Starting an EditText session for specified item }
	kDataBrowserEditStopped = 4;    { Stopping an EditText session for specified item }
	kDataBrowserItemSelected = 5;    { Item has just been added to the selection set }
	kDataBrowserItemDeselected = 6;    { Item has just been removed from the selection set }
	kDataBrowserItemDoubleClicked = 7;
	kDataBrowserContainerOpened = 8;    { Container is open }
	kDataBrowserContainerClosing = 9;    { Container is about to close (and will real soon now, y'all) }
	kDataBrowserContainerClosed = 10;   { Container is closed (y'all come back now!) }
	kDataBrowserContainerSorting = 11;   { Container is about to be sorted (lock any volatile properties) }
	kDataBrowserContainerSorted = 12;   { Container has been sorted (you may release any property locks) }
	kDataBrowserUserToggledContainer = 16; { _User_ requested container open/close state to be toggled }
	kDataBrowserTargetChanged = 15;   { The target has changed to the specified item }
	kDataBrowserUserStateChanged = 13;   { The user has reformatted the view for the target }
	kDataBrowserSelectionSetChanged = 14;  { The selection set has been modified (net result may be the same) }


{
 *  DataBrowserPropertyID
 *
 *  Discussion:
 *    Properties with values 0 through 1023 are reserved for Apple's
 *    use. Values greater than or equal to 1024 are for client use.
 }
const
{ Predefined attribute properties, optional & non-display unless otherwise stated }
	kDataBrowserItemNoProperty = 0;    { The anti-property (no associated data) }
	kDataBrowserItemIsActiveProperty = 1; { Boolean typed data (defaults to true) }
	kDataBrowserItemIsSelectableProperty = 2; { Boolean typed data (defaults to true) }
	kDataBrowserItemIsEditableProperty = 3; { Boolean typed data (defaults to false, used for editable properties) }
	kDataBrowserItemIsContainerProperty = 4; { Boolean typed data (defaults to false) }
	kDataBrowserContainerIsOpenableProperty = 5; { Boolean typed data (defaults to true) }
	kDataBrowserContainerIsClosableProperty = 6; { Boolean typed data (defaults to true) }
	kDataBrowserContainerIsSortableProperty = 7; { Boolean typed data (defaults to true) }
	kDataBrowserItemSelfIdentityProperty = 8; { kDataBrowserIconAndTextType (display property; ColumnView only) }

  {
   * kDataBrowserContainerAliasIDProperty is sent to your
   * DataBrowserItemDataProcPtr callback to give you a chance to follow
   * an alias or symlink that the item might represent. If the incoming
   * item is an alias to another item, you can call
   * SetDataBrowserItemDataItemID to let Data Browser know which other
   * item the incoming item points to.
   *
   * This is only sent from column view, and your support for it is
   * optional. It allows Data Browser to be more memory efficient with
   * its internal storage. If a given container item is an alias to an
   * item whose contents are already displayed in an existing column
   * view column, the contents can be shared between those two columns.
   }
	kDataBrowserContainerAliasIDProperty = 9; { DataBrowserItemID (alias/symlink an item to a container item) }

  {
   * kDataBrowserColumnViewPreviewProperty is sent to various callbacks
   * to give you a chance to draw or track in the preview column of
   * column view.
   *
   * You can also pass kDataBrowserColumnViewPreviewProperty in the
   * property parameter of RevealDataBrowserItem in conjunction with
   * the appropriate DataBrowserItemID of the item whose preview is
   * being displayed when you want to make sure the preview column is
   * visible to the user.
   *
   * kDataBrowserColumnViewPreviewProperty is only supported in column
   * view.
   }
	kDataBrowserColumnViewPreviewProperty = 10; { kDataBrowserCustomType (display property; ColumnView only) }

  {
   * kDataBrowserItemParentContainerProperty is sent to your
   * DataBrowserItemDataProcPtr callback when Data Browser needs to
   * know the parent container item for a given item.
   *
   * In column view, this allows the internals of SetDataBrowserTarget
   * to work. The target is the container whose contents you wish to
   * display, which is the rightmost column in column view. However,
   * unlike SetDataBrowserColumnViewPath, SetDataBrowserTarget doesn't
   * offer a way for you to communicate the DataBrowserItemIDs of the
   * rest of the column containers, so SetDataBrowserTarget needs to
   * ask for them explicitly by asking for the container's parent, then
   * the container's parent's parent, and so on.
   *
   * In list view, this allows you to pass a non-container to
   * SetDataBrowserTarget. In this situation, Data Browser will ask you
   * for the parent of the target so it knows which container to
   * display the contents of in the list view.
   *
   * In both list and column views, your DataBrowserItemDataProcPtr
   * callback might be called with
   * kDataBrowserItemParentContainerProperty at a variety of other
   * times, so you should be sure to support this property if your Data
   * Browser displays a containment hierarchy.
   }
	kDataBrowserItemParentContainerProperty = 11; { DataBrowserItemID (the parent of the specified item, used by ColumnView) }

type
	DataBrowserPropertyID = UNSIGNEDLONG;
{ DataBrowser Property Types (for display properties; i.e. ListView columns) }
{      These are primarily presentation types (or styles) although         }
{      they also imply a particular set of primitive types or structures.  }
type
	DataBrowserPropertyType = OSType;
const
{ == Corresponding data type or structure == }
	kDataBrowserCustomType = $3F3F3F3F; { No associated data, custom callbacks used }
	kDataBrowserIconType = FourCharCode('icnr'); { IconRef, IconTransformType, RGBColor }
	kDataBrowserTextType = FourCharCode('text'); { CFStringRef }
	kDataBrowserDateTimeType = FourCharCode('date'); { DateTime or LongDateTime }
	kDataBrowserSliderType = FourCharCode('sldr'); { Min, Max, Value }
	kDataBrowserCheckboxType = FourCharCode('chbx'); { ThemeButtonValue }
	kDataBrowserProgressBarType = FourCharCode('prog'); { Min, Max, Value }
	kDataBrowserRelevanceRankType = FourCharCode('rank'); { Min, Max, Value }
	kDataBrowserPopupMenuType = FourCharCode('menu'); { MenuRef, Value }
	kDataBrowserIconAndTextType = FourCharCode('ticn'); { IconRef, CFStringRef, etc }

{ DataBrowser Property Parts }
{      Visual components of a property type.      }
{      For use with GetDataBrowserItemPartBounds. }
type
	DataBrowserPropertyPart = OSType;
const
	kDataBrowserPropertyEnclosingPart = 0;
	kDataBrowserPropertyContentPart = FourCharCode('----');
	kDataBrowserPropertyDisclosurePart = FourCharCode('disc');
	kDataBrowserPropertyTextPart = kDataBrowserTextType;
	kDataBrowserPropertyIconPart = kDataBrowserIconType;
	kDataBrowserPropertySliderPart = kDataBrowserSliderType;
	kDataBrowserPropertyCheckboxPart = kDataBrowserCheckboxType;
	kDataBrowserPropertyProgressBarPart = kDataBrowserProgressBarType;
	kDataBrowserPropertyRelevanceRankPart = kDataBrowserRelevanceRankType;

{ Modify appearance/behavior of display properties }
type
	DataBrowserPropertyFlags = UInt32;
{ Low 8 bits apply to all property types }
const
	kDataBrowserUniversalPropertyFlagsMask = $FF;
	kDataBrowserPropertyIsMutable = 1 shl 0;
	kDataBrowserDefaultPropertyFlags = 0 shl 0;
	kDataBrowserUniversalPropertyFlags = kDataBrowserUniversalPropertyFlagsMask; { support for an old name}
	kDataBrowserPropertyIsEditable = kDataBrowserPropertyIsMutable; { support for an old name}

{ Next 8 bits contain property-specific modifiers }

{
 *  Summary:
 *    Data Browser Property Flags
 }
const
	kDataBrowserPropertyFlagsOffset = 8;
	kDataBrowserPropertyFlagsMask = $FF shl kDataBrowserPropertyFlagsOffset;
	kDataBrowserCheckboxTriState = 1 shl kDataBrowserPropertyFlagsOffset; { kDataBrowserCheckboxType}
	kDataBrowserDateTimeRelative = 1 shl (kDataBrowserPropertyFlagsOffset); { kDataBrowserDateTimeType }
	kDataBrowserDateTimeDateOnly = 1 shl (kDataBrowserPropertyFlagsOffset + 1); { kDataBrowserDateTimeType }
	kDataBrowserDateTimeTimeOnly = 1 shl (kDataBrowserPropertyFlagsOffset + 2); { kDataBrowserDateTimeType }
	kDataBrowserDateTimeSecondsToo = 1 shl (kDataBrowserPropertyFlagsOffset + 3); { kDataBrowserDateTimeType }
	kDataBrowserSliderPlainThumb = kThemeThumbPlain shl kDataBrowserPropertyFlagsOffset; { kDataBrowserSliderType }
	kDataBrowserSliderUpwardThumb = kThemeThumbUpward shl kDataBrowserPropertyFlagsOffset; { kDataBrowserSliderType }
	kDataBrowserSliderDownwardThumb = kThemeThumbDownward shl kDataBrowserPropertyFlagsOffset; { kDataBrowserSliderType }
	kDataBrowserDoNotTruncateText = 3 shl kDataBrowserPropertyFlagsOffset; { kDataBrowserTextType && kDataBrowserIconAndTextType }
	kDataBrowserTruncateTextAtEnd = 2 shl kDataBrowserPropertyFlagsOffset; { kDataBrowserTextType && kDataBrowserIconAndTextType }
	kDataBrowserTruncateTextMiddle = 0 shl kDataBrowserPropertyFlagsOffset; { kDataBrowserTextType && kDataBrowserIconAndTextType }
	kDataBrowserTruncateTextAtStart = 1 shl kDataBrowserPropertyFlagsOffset; { kDataBrowserTextType && kDataBrowserIconAndTextType }

  {
   * This flag is only for use with columns of type
   * kDataBrowserPopupMenuType. This flag indicates that the popup be
   * drawn in a sleek buttonless fashion. The text will be drawn next
   * to a popup glyph, and the whole cell will be clickable. Available
   * on 10.4 and later.
   }
	kDataBrowserPopupMenuButtonless = 1 shl kDataBrowserPropertyFlagsOffset; { kDataBrowserPopupMenuType}
	kDataBrowserPropertyModificationFlags = kDataBrowserPropertyFlagsMask; { support for an old name}
	kDataBrowserRelativeDateTime = kDataBrowserDateTimeRelative; { support for an old name}

{
   Next 8 bits contain viewStyle-specific modifiers
   See individual ViewStyle sections below for flag definitions
}
const
	kDataBrowserViewSpecificFlagsOffset = 16;
	kDataBrowserViewSpecificFlagsMask = $FF shl kDataBrowserViewSpecificFlagsOffset;
	kDataBrowserViewSpecificPropertyFlags = kDataBrowserViewSpecificFlagsMask; { support for an old name}

{ High 8 bits are reserved for client application use }
const
	kDataBrowserClientPropertyFlagsOffset = 24;
	kDataBrowserClientPropertyFlagsMask = $FF shl kDataBrowserClientPropertyFlagsOffset;

{ Client defined property description }
type
	DataBrowserPropertyDescPtr = ^DataBrowserPropertyDesc;
	DataBrowserPropertyDesc = record
		propertyID: DataBrowserPropertyID;
		propertyType: DataBrowserPropertyType;
		propertyFlags: DataBrowserPropertyFlags;
	end;
{ Callback definition for use with ForEachDataBrowserItem }
type
	DataBrowserItemProcPtr = procedure( item: DataBrowserItemID; state: DataBrowserItemState; clientData: UnivPtr );
	DataBrowserItemUPP = DataBrowserItemProcPtr;
{
 *  NewDataBrowserItemUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
function NewDataBrowserItemUPP( userRoutine: DataBrowserItemProcPtr ): DataBrowserItemUPP; external name '_NewDataBrowserItemUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  DisposeDataBrowserItemUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
procedure DisposeDataBrowserItemUPP( userUPP: DataBrowserItemUPP ); external name '_DisposeDataBrowserItemUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  InvokeDataBrowserItemUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
procedure InvokeDataBrowserItemUPP( item: DataBrowserItemID; state: DataBrowserItemState; clientData: UnivPtr; userUPP: DataBrowserItemUPP ); external name '_InvokeDataBrowserItemUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{ Creation/Configuration }


{
 *  Summary:
 *    Data Browser attributes
 *
 *  Discussion:
 *    For use with DataBrowserChangeAttributes and
 *    DataBrowserGetAttributes. Available in Mac OS X 10.4 and later.
 }
const
{
   * A constant with value zero; the lack of any attributes.
   }
	kDataBrowserAttributeNone = 0;

  {
   * In Column View, this Data Browser is allowed to resize the owning
   * window whenever necessary. This includes, but is not necessarily
   * limited to, situations where column resize operations need more
   * visible space in the window. If you turn this attribute on, your
   * window must tolerate being resized behind your app's back. If your
   * window needs to react to bounds changes, use a
   * kEventWindowBoundsChanged event handler. If you need to constrain
   * your window's minimum and maximum bounds, use
   * kEventWindowGetMinimum/MaximumSize handlers, the
   * SetWindowResizeLimits API, or something similar.
   }
	kDataBrowserAttributeColumnViewResizeWindow = 1 shl 0;

  {
   * In List View, this Data Browser should draw alternating row
   * background colors.
   }
	kDataBrowserAttributeListViewAlternatingRowColors = 1 shl 1;

  {
   * In List View, this Data Browser should draw a vertical line
   * between the columns.
   }
	kDataBrowserAttributeListViewDrawColumnDividers = 1 shl 2;

  {
   * Whether the Data Browser should hide scroll bar when they are not
   * necessary, and use the additional space to draw more content. By
   * default this attribute is turned off. This attribute is available
   * on Mac OS X 10.5 and later.
   * As of Mac OS X 10.5, this is only respected in list view, but it
   * may be respected in column view in the future. If you set this now
   * for a Data Browser instance that uses column view, you must be
   * prepared for the scroll bars to auto hide in the future. This
   * attribute is only respected in compositing mode; it will be
   * ignored in non-compositing mode.
   * When this attribute is turned on for a Data Browser instance that
   * is allowed to use both horizontal and vertical scroll bars (see
   * SetDataBrowserHasScrollBars), the Data Browser will attempt to use
   * the square space at the bottom right of the scroll bar area
   * whenever necessary. In other words, when the vertical scroll bar
   * is not necessary, the Data Browser will stretch the horizontal
   * scroll bar across the entire width. If your code needs Data
   * Browser to *not* use that square space - possibly because your
   * window's grow box will overlap that area - you should also turn on
   * the kDataBrowserAttributeReserveGrowBoxSpace attribute whenever
   * you turn on scroll bar auto hiding.
   }
	kDataBrowserAttributeAutoHideScrollBars = 1 shl 3;

  {
   * Whether the Data Browser should avoid positioning either of its
   * scroll bars such that they overlap the very bottom right of the
   * content area, where you'd typically have a grow box. By default,
   * this attribute is turned off. This attribute is available on Mac
   * OS X 10.5 and later.
   }
	kDataBrowserAttributeReserveGrowBoxSpace = 1 shl 4;



{
 *  Summary:
 *    DataBrowserMetric values
 *
 *  Discussion:
 *    For use with DataBrowserSetMetric.
 }
const
{
   * The content (icon, text, etc.) within a cell is drawn a certain
   * amount in from the left & right edges of the cell. This metric
   * governs the amount of inset.
   }
	kDataBrowserMetricCellContentInset = 1;

  {
   * This metric controls the space between the icon and text within a
   * column of type kDataBrowserIconAndTextType.
   }
	kDataBrowserMetricIconAndTextGap = 2;

  {
   * In List View only, this metric is similar to
   * kDataBrowserMetricCellContentInset, but it only affects the
   * disclosure column and it only affects the side of the cell that
   * displays the disclosure triangle. In other words, this metric is
   * used instead of (not in addition to)
   * DataBrowserMetricCellContentInset for one side of the disclosure
   * column.
   }
	kDataBrowserMetricDisclosureColumnEdgeInset = 3;

  {
   * In List View only, this metric controls the amount of space
   * between the disclosure triangle and the cell's content.
   }
	kDataBrowserMetricDisclosureTriangleAndContentGap = 4;

  {
   * In List View only, this metric controls the amount of space in the
   * disclosure column for each level of indentation in progressively
   * deeper hierarchies of disclosed items.
   }
	kDataBrowserMetricDisclosureColumnPerDepthGap = 5;
	kDataBrowserMetricLast = kDataBrowserMetricDisclosureColumnPerDepthGap;


type
	DataBrowserMetric = UInt32;

type
	DataBrowserItemDataRef = UnivPtr;

type
	DataBrowserItemDataProcPtr = function( browser: ControlRef; item: DataBrowserItemID; property: DataBrowserPropertyID; itemData: DataBrowserItemDataRef; setValue: Boolean ): OSStatus;
	DataBrowserItemDataUPP = DataBrowserItemDataProcPtr;

{ Item Comparison }
type
	DataBrowserItemCompareProcPtr = function( browser: ControlRef; itemOne: DataBrowserItemID; itemTwo: DataBrowserItemID; sortProperty: DataBrowserPropertyID ): Boolean;
	DataBrowserItemCompareUPP = DataBrowserItemCompareProcPtr;

{ ItemEvent Notification }
{  A Very Important Note about DataBrowserItemNotificationProcPtr:                                     }
{  Under all currently shipping versions of CarbonLib (eg. up through 1.3), your callback is called    }
{  just as the prototype appears in this header. It should only be expecting three parameters because  }
{  DataBrowser will only pass three parameters.                                                        }
{  Under Mac OS X, your callback is called with an additional parameter. If you wish to interpret      }
{  the additional parameter, your callback should have the same prototype as the                       }
{  DataBrowserItemNotificationWithItemProcPtr (below). You may freely take a callback with this        }
{  prototype and pass it to NewDataBrowserItemNotificationUPP in order to generate a                   }
{  DataBrowserItemNotificationUPP that you can use just like any other DataBrowserItemNotificationUPP. }
{  If you use this technique under CarbonLib, you will *not* receive valid data in the fourth          }
{  parameter, and any attempt to use the invalid data will probably result in a crash.                 }
type
	DataBrowserItemNotificationWithItemProcPtr = procedure( browser: ControlRef; item: DataBrowserItemID; message: DataBrowserItemNotification; itemData: DataBrowserItemDataRef );
	DataBrowserItemNotificationProcPtr = procedure( browser: ControlRef; item: DataBrowserItemID; message: DataBrowserItemNotification );
	DataBrowserItemNotificationWithItemUPP = DataBrowserItemNotificationWithItemProcPtr;
	DataBrowserItemNotificationUPP = DataBrowserItemNotificationProcPtr;


{ Drag & Drop Processing }
type
	DataBrowserAddDragItemProcPtr = function( browser: ControlRef; theDrag: DragReference; item: DataBrowserItemID; var itemRef: ItemReference ): Boolean;
	DataBrowserAcceptDragProcPtr = function( browser: ControlRef; theDrag: DragReference; item: DataBrowserItemID ): Boolean;
	DataBrowserReceiveDragProcPtr = function( browser: ControlRef; theDrag: DragReference; item: DataBrowserItemID ): Boolean;
	DataBrowserPostProcessDragProcPtr = procedure( browser: ControlRef; theDrag: DragReference; trackDragResult: OSStatus );
	DataBrowserAddDragItemUPP = DataBrowserAddDragItemProcPtr;
	DataBrowserAcceptDragUPP = DataBrowserAcceptDragProcPtr;
	DataBrowserReceiveDragUPP = DataBrowserReceiveDragProcPtr;
	DataBrowserPostProcessDragUPP = DataBrowserPostProcessDragProcPtr;

{ Contextual Menu Support }
type
	DataBrowserGetContextualMenuProcPtr = procedure( browser: ControlRef; var menu: MenuRef; var helpType: UInt32; var helpItemString: CFStringRef; var selection: AEDesc );
	DataBrowserSelectContextualMenuProcPtr = procedure( browser: ControlRef; menu: MenuRef; selectionType: UInt32; menuID: SInt16; menuItem: MenuItemIndex );
	DataBrowserGetContextualMenuUPP = DataBrowserGetContextualMenuProcPtr;
	DataBrowserSelectContextualMenuUPP = DataBrowserSelectContextualMenuProcPtr;

{ Help Manager Support }
type
	DataBrowserItemHelpContentProcPtr = procedure( browser: ControlRef; item: DataBrowserItemID; property: DataBrowserPropertyID; inRequest: HMContentRequest; var outContentProvided: HMContentProvidedType; var ioHelpContent: HMHelpContentRec );
	DataBrowserItemHelpContentUPP = DataBrowserItemHelpContentProcPtr;
{
 *  NewDataBrowserItemDataUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
function NewDataBrowserItemDataUPP( userRoutine: DataBrowserItemDataProcPtr ): DataBrowserItemDataUPP; external name '_NewDataBrowserItemDataUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  NewDataBrowserItemCompareUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
function NewDataBrowserItemCompareUPP( userRoutine: DataBrowserItemCompareProcPtr ): DataBrowserItemCompareUPP; external name '_NewDataBrowserItemCompareUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  NewDataBrowserItemNotificationWithItemUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.1 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.5 and later
 *    Non-Carbon CFM:   not available
 }
function NewDataBrowserItemNotificationWithItemUPP( userRoutine: DataBrowserItemNotificationWithItemProcPtr ): DataBrowserItemNotificationWithItemUPP; external name '_NewDataBrowserItemNotificationWithItemUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_1_AND_LATER *)

{
 *  NewDataBrowserItemNotificationUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
function NewDataBrowserItemNotificationUPP( userRoutine: DataBrowserItemNotificationProcPtr ): DataBrowserItemNotificationUPP; external name '_NewDataBrowserItemNotificationUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  NewDataBrowserAddDragItemUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
function NewDataBrowserAddDragItemUPP( userRoutine: DataBrowserAddDragItemProcPtr ): DataBrowserAddDragItemUPP; external name '_NewDataBrowserAddDragItemUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  NewDataBrowserAcceptDragUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
function NewDataBrowserAcceptDragUPP( userRoutine: DataBrowserAcceptDragProcPtr ): DataBrowserAcceptDragUPP; external name '_NewDataBrowserAcceptDragUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  NewDataBrowserReceiveDragUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
function NewDataBrowserReceiveDragUPP( userRoutine: DataBrowserReceiveDragProcPtr ): DataBrowserReceiveDragUPP; external name '_NewDataBrowserReceiveDragUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  NewDataBrowserPostProcessDragUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
function NewDataBrowserPostProcessDragUPP( userRoutine: DataBrowserPostProcessDragProcPtr ): DataBrowserPostProcessDragUPP; external name '_NewDataBrowserPostProcessDragUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  NewDataBrowserGetContextualMenuUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
function NewDataBrowserGetContextualMenuUPP( userRoutine: DataBrowserGetContextualMenuProcPtr ): DataBrowserGetContextualMenuUPP; external name '_NewDataBrowserGetContextualMenuUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  NewDataBrowserSelectContextualMenuUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
function NewDataBrowserSelectContextualMenuUPP( userRoutine: DataBrowserSelectContextualMenuProcPtr ): DataBrowserSelectContextualMenuUPP; external name '_NewDataBrowserSelectContextualMenuUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  NewDataBrowserItemHelpContentUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
function NewDataBrowserItemHelpContentUPP( userRoutine: DataBrowserItemHelpContentProcPtr ): DataBrowserItemHelpContentUPP; external name '_NewDataBrowserItemHelpContentUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  DisposeDataBrowserItemDataUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
procedure DisposeDataBrowserItemDataUPP( userUPP: DataBrowserItemDataUPP ); external name '_DisposeDataBrowserItemDataUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  DisposeDataBrowserItemCompareUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
procedure DisposeDataBrowserItemCompareUPP( userUPP: DataBrowserItemCompareUPP ); external name '_DisposeDataBrowserItemCompareUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  DisposeDataBrowserItemNotificationWithItemUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.1 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.5 and later
 *    Non-Carbon CFM:   not available
 }
procedure DisposeDataBrowserItemNotificationWithItemUPP( userUPP: DataBrowserItemNotificationWithItemUPP ); external name '_DisposeDataBrowserItemNotificationWithItemUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_1_AND_LATER *)

{
 *  DisposeDataBrowserItemNotificationUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
procedure DisposeDataBrowserItemNotificationUPP( userUPP: DataBrowserItemNotificationUPP ); external name '_DisposeDataBrowserItemNotificationUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  DisposeDataBrowserAddDragItemUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
procedure DisposeDataBrowserAddDragItemUPP( userUPP: DataBrowserAddDragItemUPP ); external name '_DisposeDataBrowserAddDragItemUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  DisposeDataBrowserAcceptDragUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
procedure DisposeDataBrowserAcceptDragUPP( userUPP: DataBrowserAcceptDragUPP ); external name '_DisposeDataBrowserAcceptDragUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  DisposeDataBrowserReceiveDragUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
procedure DisposeDataBrowserReceiveDragUPP( userUPP: DataBrowserReceiveDragUPP ); external name '_DisposeDataBrowserReceiveDragUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  DisposeDataBrowserPostProcessDragUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
procedure DisposeDataBrowserPostProcessDragUPP( userUPP: DataBrowserPostProcessDragUPP ); external name '_DisposeDataBrowserPostProcessDragUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  DisposeDataBrowserGetContextualMenuUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
procedure DisposeDataBrowserGetContextualMenuUPP( userUPP: DataBrowserGetContextualMenuUPP ); external name '_DisposeDataBrowserGetContextualMenuUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  DisposeDataBrowserSelectContextualMenuUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
procedure DisposeDataBrowserSelectContextualMenuUPP( userUPP: DataBrowserSelectContextualMenuUPP ); external name '_DisposeDataBrowserSelectContextualMenuUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  DisposeDataBrowserItemHelpContentUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
procedure DisposeDataBrowserItemHelpContentUPP( userUPP: DataBrowserItemHelpContentUPP ); external name '_DisposeDataBrowserItemHelpContentUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  InvokeDataBrowserItemDataUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
function InvokeDataBrowserItemDataUPP( browser: ControlRef; item: DataBrowserItemID; property: DataBrowserPropertyID; itemData: DataBrowserItemDataRef; setValue: Boolean; userUPP: DataBrowserItemDataUPP ): OSStatus; external name '_InvokeDataBrowserItemDataUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  InvokeDataBrowserItemCompareUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
function InvokeDataBrowserItemCompareUPP( browser: ControlRef; itemOne: DataBrowserItemID; itemTwo: DataBrowserItemID; sortProperty: DataBrowserPropertyID; userUPP: DataBrowserItemCompareUPP ): Boolean; external name '_InvokeDataBrowserItemCompareUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  InvokeDataBrowserItemNotificationWithItemUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.1 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.5 and later
 *    Non-Carbon CFM:   not available
 }
procedure InvokeDataBrowserItemNotificationWithItemUPP( browser: ControlRef; item: DataBrowserItemID; message: DataBrowserItemNotification; itemData: DataBrowserItemDataRef; userUPP: DataBrowserItemNotificationWithItemUPP ); external name '_InvokeDataBrowserItemNotificationWithItemUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_1_AND_LATER *)

{
 *  InvokeDataBrowserItemNotificationUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
procedure InvokeDataBrowserItemNotificationUPP( browser: ControlRef; item: DataBrowserItemID; message: DataBrowserItemNotification; userUPP: DataBrowserItemNotificationUPP ); external name '_InvokeDataBrowserItemNotificationUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  InvokeDataBrowserAddDragItemUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
function InvokeDataBrowserAddDragItemUPP( browser: ControlRef; theDrag: DragReference; item: DataBrowserItemID; var itemRef: ItemReference; userUPP: DataBrowserAddDragItemUPP ): Boolean; external name '_InvokeDataBrowserAddDragItemUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  InvokeDataBrowserAcceptDragUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
function InvokeDataBrowserAcceptDragUPP( browser: ControlRef; theDrag: DragReference; item: DataBrowserItemID; userUPP: DataBrowserAcceptDragUPP ): Boolean; external name '_InvokeDataBrowserAcceptDragUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  InvokeDataBrowserReceiveDragUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
function InvokeDataBrowserReceiveDragUPP( browser: ControlRef; theDrag: DragReference; item: DataBrowserItemID; userUPP: DataBrowserReceiveDragUPP ): Boolean; external name '_InvokeDataBrowserReceiveDragUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  InvokeDataBrowserPostProcessDragUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
procedure InvokeDataBrowserPostProcessDragUPP( browser: ControlRef; theDrag: DragReference; trackDragResult: OSStatus; userUPP: DataBrowserPostProcessDragUPP ); external name '_InvokeDataBrowserPostProcessDragUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  InvokeDataBrowserGetContextualMenuUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
procedure InvokeDataBrowserGetContextualMenuUPP( browser: ControlRef; var menu: MenuRef; var helpType: UInt32; var helpItemString: CFStringRef; var selection: AEDesc; userUPP: DataBrowserGetContextualMenuUPP ); external name '_InvokeDataBrowserGetContextualMenuUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  InvokeDataBrowserSelectContextualMenuUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
procedure InvokeDataBrowserSelectContextualMenuUPP( browser: ControlRef; menu: MenuRef; selectionType: UInt32; menuID: SInt16; menuItem: MenuItemIndex; userUPP: DataBrowserSelectContextualMenuUPP ); external name '_InvokeDataBrowserSelectContextualMenuUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)

{
 *  InvokeDataBrowserItemHelpContentUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
procedure InvokeDataBrowserItemHelpContentUPP( browser: ControlRef; item: DataBrowserItemID; property: DataBrowserPropertyID; inRequest: HMContentRequest; var outContentProvided: HMContentProvidedType; ioHelpContent: HMHelpContentPtr; userUPP: DataBrowserItemHelpContentUPP ); external name '_InvokeDataBrowserItemHelpContentUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER *)


{ Standard Callback (vtable) Structure }
const
	kDataBrowserLatestCallbacks = 0;

type
	DataBrowserCallbacksPtr = ^DataBrowserCallbacks;
	DataBrowserCallbacks = record
		version: UInt32;                { Use kDataBrowserLatestCallbacks }
		case SInt16 of
		0: (
			itemDataCallback:	DataBrowserItemDataUPP;
			itemCompareCallback: DataBrowserItemCompareUPP;
			itemNotificationCallback: DataBrowserItemNotificationUPP;
			addDragItemCallback: DataBrowserAddDragItemUPP;
			acceptDragCallback:	DataBrowserAcceptDragUPP;
			receiveDragCallback: DataBrowserReceiveDragUPP;
			postProcessDragCallback: DataBrowserPostProcessDragUPP;
			itemHelpContentCallback: DataBrowserItemHelpContentUPP;
			getContextualMenuCallback: DataBrowserGetContextualMenuUPP;
			selectContextualMenuCallback: DataBrowserSelectContextualMenuUPP;
		   );
	end;


{
 *  Summary:
 *    Event class
 }
const
{
   * Events related to DataBrowser.
   }
	kEventClassDataBrowser = FourCharCode('hidb');

{
    kEventClassDataBrowser quick reference:

    kEventDataBrowserDrawCustomItem         = 1
}

{ DataBrowser parameters}

const
	kEventParamDataBrowserItemID = FourCharCode('dbid'); { typeRefCon}
	kEventParamDataBrowserPropertyID = FourCharCode('dbpd'); { typeRefCon}
	kEventParamDataBrowserItemState = FourCharCode('dbis'); { typeUInt32}

{
 *  kEventClassDataBrowser / kEventDataBrowserDrawCustomItem
 *
 *  Summary:
 *    DataBrowser is requesting a custom item be drawn.
 *
 *  Discussion:
 *    If the client has installed a custom item draw handler on a data
 *    browser containing custom items, as indicated by the
 *    kDataBrowserCustomType property, this message will be sent at
 *    data browser draw time for all custom items currently showing.
 *    This event does not propagate past the Data Browser control and
 *    is only sent in compositing mode. If a result other than noErr is
 *    returned the DataBrowserDrawItemProcPtr will be invoked if it has
 *    bee installed.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Parameters:
 *
 *    --> kEventParamDirectObject (in, typeControlRef)
 *          The DataBrowser requesting a custom item be drawn.
 *
 *    --> kEventParamDataBrowserItemID (in, typeRefCon)
 *          The item ID for the item to draw.
 *
 *    --> kEventParamDataBrowserPropertyID (in, typeRefCon)
 *          The property ID for the item. In list view, this is the
 *          four-character sequence that you previously assigned to the
 *          column. In column view, this is the property
 *          kDataBrowserItemSelfIdentityProperty.
 *
 *    --> kEventParamDataBrowserItemState (in, typeUInt32)
 *          The state to use when drawing the item.
 *
 *    --> kEventParamBounds (in, typeHIRect)
 *          The bounding rectangle that specifies where in the provided
 *          context to draw the item. This rectangle is the content
 *          rectangle, not the enclosing rectangle.
 *
 *    --> kEventParamCGContextRef (in, typeCGContext)
 *          The context into which the custom drawing should be
 *          performed. The context will be automatically flipped to use
 *          a top left orientation similar to the kEventControlDraw
 *          event.
 *
 *  Availability:
 *    Mac OS X:         in version 10.5 and later in Carbon.framework
 *    CarbonLib:        not available
 }
const
	kEventDataBrowserDrawCustomItem = 1;


{ Custom Format Callbacks (kDataBrowserCustomType display properties) }

type
	DataBrowserDragFlags = UInt32;
	DataBrowserTrackingResult = SInt16;
const
	kDataBrowserContentHit = 1;
	kDataBrowserNothingHit = 0;
	kDataBrowserStopTracking = -1;

type
	DataBrowserDrawItemProcPtr = procedure( browser: ControlRef; item: DataBrowserItemID; property: DataBrowserPropertyID; itemState: DataBrowserItemState; const (*var*) theRect: Rect; gdDepth: SInt16; colorDevice: Boolean );
	DataBrowserEditItemProcPtr = function( browser: ControlRef; item: DataBrowserItemID; property: DataBrowserPropertyID; theString: CFStringRef; var maxEditTextRect: Rect; var shrinkToFit: Boolean ): Boolean;
	DataBrowserHitTestProcPtr = function( browser: ControlRef; itemID: DataBrowserItemID; property: DataBrowserPropertyID; const (*var*) theRect: Rect; const (*var*) mouseRect: Rect ): Boolean;
	DataBrowserTrackingProcPtr = function( browser: ControlRef; itemID: DataBrowserItemID; property: DataBrowserPropertyID; const (*var*) theRect: Rect; startPt: Point; modifiers: EventModifiers ): DataBrowserTrackingResult;
	DataBrowserItemDragRgnProcPtr = procedure( browser: ControlRef; itemID: DataBrowserItemID; property: DataBrowserPropertyID; const (*var*) theRect: Rect; dragRgn: RgnHandle );
	DataBrowserItemAcceptDragProcPtr = function( browser: ControlRef; itemID: DataBrowserItemID; property: DataBrowserPropertyID; const (*var*) theRect: Rect; theDrag: DragReference ): DataBrowserDragFlags;
	DataBrowserItemReceiveDragProcPtr = function( browser: ControlRef; itemID: DataBrowserItemID; property: DataBrowserPropertyID; dragFlags: DataBrowserDragFlags; theDrag: DragReference ): Boolean;
	DataBrowserDrawItemUPP = DataBrowserDrawItemProcPtr;
	DataBrowserEditItemUPP = DataBrowserEditItemProcPtr;
	DataBrowserHitTestUPP = DataBrowserHitTestProcPtr;
	DataBrowserTrackingUPP = DataBrowserTrackingProcPtr;
	DataBrowserItemDragRgnUPP = DataBrowserItemDragRgnProcPtr;
	DataBrowserItemAcceptDragUPP = DataBrowserItemAcceptDragProcPtr;
	DataBrowserItemReceiveDragUPP = DataBrowserItemReceiveDragProcPtr;
{
 *  NewDataBrowserDrawItemUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.1 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
function NewDataBrowserDrawItemUPP( userRoutine: DataBrowserDrawItemProcPtr ): DataBrowserDrawItemUPP; external name '_NewDataBrowserDrawItemUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_1_AND_LATER *)

{
 *  NewDataBrowserEditItemUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.1 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
function NewDataBrowserEditItemUPP( userRoutine: DataBrowserEditItemProcPtr ): DataBrowserEditItemUPP; external name '_NewDataBrowserEditItemUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_1_AND_LATER *)

{
 *  NewDataBrowserHitTestUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.1 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
function NewDataBrowserHitTestUPP( userRoutine: DataBrowserHitTestProcPtr ): DataBrowserHitTestUPP; external name '_NewDataBrowserHitTestUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_1_AND_LATER *)

{
 *  NewDataBrowserTrackingUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.1 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
function NewDataBrowserTrackingUPP( userRoutine: DataBrowserTrackingProcPtr ): DataBrowserTrackingUPP; external name '_NewDataBrowserTrackingUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_1_AND_LATER *)

{
 *  NewDataBrowserItemDragRgnUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.1 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
function NewDataBrowserItemDragRgnUPP( userRoutine: DataBrowserItemDragRgnProcPtr ): DataBrowserItemDragRgnUPP; external name '_NewDataBrowserItemDragRgnUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_1_AND_LATER *)

{
 *  NewDataBrowserItemAcceptDragUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.1 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
function NewDataBrowserItemAcceptDragUPP( userRoutine: DataBrowserItemAcceptDragProcPtr ): DataBrowserItemAcceptDragUPP; external name '_NewDataBrowserItemAcceptDragUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_1_AND_LATER *)

{
 *  NewDataBrowserItemReceiveDragUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.1 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
function NewDataBrowserItemReceiveDragUPP( userRoutine: DataBrowserItemReceiveDragProcPtr ): DataBrowserItemReceiveDragUPP; external name '_NewDataBrowserItemReceiveDragUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_1_AND_LATER *)

{
 *  DisposeDataBrowserDrawItemUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.1 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
procedure DisposeDataBrowserDrawItemUPP( userUPP: DataBrowserDrawItemUPP ); external name '_DisposeDataBrowserDrawItemUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_1_AND_LATER *)

{
 *  DisposeDataBrowserEditItemUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.1 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
procedure DisposeDataBrowserEditItemUPP( userUPP: DataBrowserEditItemUPP ); external name '_DisposeDataBrowserEditItemUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_1_AND_LATER *)

{
 *  DisposeDataBrowserHitTestUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.1 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
procedure DisposeDataBrowserHitTestUPP( userUPP: DataBrowserHitTestUPP ); external name '_DisposeDataBrowserHitTestUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_1_AND_LATER *)

{
 *  DisposeDataBrowserTrackingUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.1 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
procedure DisposeDataBrowserTrackingUPP( userUPP: DataBrowserTrackingUPP ); external name '_DisposeDataBrowserTrackingUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_1_AND_LATER *)

{
 *  DisposeDataBrowserItemDragRgnUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.1 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
procedure DisposeDataBrowserItemDragRgnUPP( userUPP: DataBrowserItemDragRgnUPP ); external name '_DisposeDataBrowserItemDragRgnUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_1_AND_LATER *)

{
 *  DisposeDataBrowserItemAcceptDragUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.1 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
procedure DisposeDataBrowserItemAcceptDragUPP( userUPP: DataBrowserItemAcceptDragUPP ); external name '_DisposeDataBrowserItemAcceptDragUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_1_AND_LATER *)

{
 *  DisposeDataBrowserItemReceiveDragUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.1 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
procedure DisposeDataBrowserItemReceiveDragUPP( userUPP: DataBrowserItemReceiveDragUPP ); external name '_DisposeDataBrowserItemReceiveDragUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_1_AND_LATER *)

{
 *  InvokeDataBrowserDrawItemUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.1 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
procedure InvokeDataBrowserDrawItemUPP( browser: ControlRef; item: DataBrowserItemID; property: DataBrowserPropertyID; itemState: DataBrowserItemState; const (*var*) theRect: Rect; gdDepth: SInt16; colorDevice: Boolean; userUPP: DataBrowserDrawItemUPP ); external name '_InvokeDataBrowserDrawItemUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_1_AND_LATER *)

{
 *  InvokeDataBrowserEditItemUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.1 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
function InvokeDataBrowserEditItemUPP( browser: ControlRef; item: DataBrowserItemID; property: DataBrowserPropertyID; theString: CFStringRef; var maxEditTextRect: Rect; var shrinkToFit: Boolean; userUPP: DataBrowserEditItemUPP ): Boolean; external name '_InvokeDataBrowserEditItemUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_1_AND_LATER *)

{
 *  InvokeDataBrowserHitTestUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.1 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
function InvokeDataBrowserHitTestUPP( browser: ControlRef; itemID: DataBrowserItemID; property: DataBrowserPropertyID; const (*var*) theRect: Rect; const (*var*) mouseRect: Rect; userUPP: DataBrowserHitTestUPP ): Boolean; external name '_InvokeDataBrowserHitTestUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_1_AND_LATER *)

{
 *  InvokeDataBrowserTrackingUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.1 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
function InvokeDataBrowserTrackingUPP( browser: ControlRef; itemID: DataBrowserItemID; property: DataBrowserPropertyID; const (*var*) theRect: Rect; startPt: Point; modifiers: EventModifiers; userUPP: DataBrowserTrackingUPP ): DataBrowserTrackingResult; external name '_InvokeDataBrowserTrackingUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_1_AND_LATER *)

{
 *  InvokeDataBrowserItemDragRgnUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.1 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
procedure InvokeDataBrowserItemDragRgnUPP( browser: ControlRef; itemID: DataBrowserItemID; property: DataBrowserPropertyID; const (*var*) theRect: Rect; dragRgn: RgnHandle; userUPP: DataBrowserItemDragRgnUPP ); external name '_InvokeDataBrowserItemDragRgnUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_1_AND_LATER *)

{
 *  InvokeDataBrowserItemAcceptDragUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.1 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
function InvokeDataBrowserItemAcceptDragUPP( browser: ControlRef; itemID: DataBrowserItemID; property: DataBrowserPropertyID; const (*var*) theRect: Rect; theDrag: DragReference; userUPP: DataBrowserItemAcceptDragUPP ): DataBrowserDragFlags; external name '_InvokeDataBrowserItemAcceptDragUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_1_AND_LATER *)

{
 *  InvokeDataBrowserItemReceiveDragUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.1 and later in Carbon.framework
 *    CarbonLib:        in CarbonLib 1.1 and later
 *    Non-Carbon CFM:   not available
 }
function InvokeDataBrowserItemReceiveDragUPP( browser: ControlRef; itemID: DataBrowserItemID; property: DataBrowserPropertyID; dragFlags: DataBrowserDragFlags; theDrag: DragReference; userUPP: DataBrowserItemReceiveDragUPP ): Boolean; external name '_InvokeDataBrowserItemReceiveDragUPP';
(* AVAILABLE_MAC_OS_X_VERSION_10_1_AND_LATER *)


{ Custom Callback (vtable) Structure }
const
	kDataBrowserLatestCustomCallbacks = 0;

type
	DataBrowserCustomCallbacksPtr = ^DataBrowserCustomCallbacks;
	DataBrowserCustomCallbacks = record
		version: UInt32;                { Use kDataBrowserLatestCustomCallbacks }
		case SInt16 of
		0: (
			drawItemCallback:	DataBrowserDrawItemUPP;
			editTextCallback:	DataBrowserEditItemUPP;
			hitTestCallback:	DataBrowserHitTestUPP;
			trackingCallback:	DataBrowserTrackingUPP;
			dragRegionCallback:	DataBrowserItemDragRgnUPP;
			acceptDragCallback:	DataBrowserItemAcceptDragUPP;
			receiveDragCallback: DataBrowserItemReceiveDragUPP;
		   );
	end;

type
	DataBrowserTableViewHiliteStyle = UInt32;
const
	kDataBrowserTableViewMinimalHilite = 0;
	kDataBrowserTableViewFillHilite = 1;

type
	DataBrowserTableViewPropertyFlags = UInt32;
const
{ kDataBrowserTableView DataBrowserPropertyFlags }
	kDataBrowserTableViewSelectionColumn = 1 shl kDataBrowserViewSpecificFlagsOffset;

{ The row and column indices are zero-based }

type
	DataBrowserTableViewRowIndex = UNSIGNEDLONG;
	DataBrowserTableViewColumnIndex = UNSIGNEDLONG;
	DataBrowserTableViewColumnID = DataBrowserPropertyID;
	DataBrowserTableViewColumnDesc = DataBrowserPropertyDesc;
{ TableView API }
{ Use when setting column position }
const
	kDataBrowserTableViewLastColumn = -1;



{
 *  Discussion:
 *    DataBrowserPropertyFlags that are specific to kDataBrowserListView
 }
const
	kDataBrowserListViewSelectionColumn = kDataBrowserTableViewSelectionColumn;
	kDataBrowserListViewMovableColumn = 1 shl (kDataBrowserViewSpecificFlagsOffset + 1);
	kDataBrowserListViewSortableColumn = 1 shl (kDataBrowserViewSpecificFlagsOffset + 2);

  {
   * kDataBrowserListViewTypeSelectColumn marks a column as
   * type-selectable. If one or more of your list view columns are
   * marked as type-selectable, Data Browser will do type-selection for
   * you automatically. Data Browser applies the typing to the first
   * column (in the system direction) with this property flag. This
   * flag only intended for use with columns of type
   * kDataBrowserTextType, kDataBrowserIconAndTextType, and
   * kDataBrowserDateTimeType; if you set it for a column of another
   * type, the type-selection behavior is undefined. Turning on this
   * flag also causes Data Browser to gather all keyboard input via a
   * carbon event handler instead of relying on calls to
   * HandleControlKey; therefore, you will never see these keyboard
   * events come out of WaitNextEvent. Only available on 10.3 and later.
   }
	kDataBrowserListViewTypeSelectColumn = 1 shl (kDataBrowserViewSpecificFlagsOffset + 3);

  {
   * Normally the text in a header button for a column of type
   * kDataBrowserIconAndTextType is aligned as though it has an icon
   * next to it even if no icon is specified for the header button; in
   * other words, space is reserved for an icon in the header button
   * even if no icon is displayed. However, this flag indicates that
   * space should not be reserved for an icon if no icon is provided
   * for the header button. This flag allows a client to justify the
   * left edge of the text in a header button to the left edge of the
   * icon in the cells beneath it. Available on 10.4 and later.
   }
	kDataBrowserListViewNoGapForIconInHeaderButton = 1 shl (kDataBrowserViewSpecificFlagsOffset + 4);
	kDataBrowserListViewDefaultColumnFlags = kDataBrowserListViewMovableColumn + kDataBrowserListViewSortableColumn;

type
	DataBrowserListViewPropertyFlags = DataBrowserPropertyFlags;
const
	kDataBrowserListViewLatestHeaderDesc = 0;

type
	DataBrowserListViewHeaderDescPtr = ^DataBrowserListViewHeaderDesc;
	DataBrowserListViewHeaderDesc = record
		version: UInt32;                { Use kDataBrowserListViewLatestHeaderDesc }

		minimumWidth: UInt16;
		maximumWidth: UInt16;

		titleOffset: SInt16;
		titleString: CFStringRef;
		initialOrder: DataBrowserSortOrder;
		btnFontStyle: ControlFontStyleRec;
		btnContentInfo: ControlButtonContentInfo;
	end;
type
	DataBrowserListViewColumnDescPtr = ^DataBrowserListViewColumnDesc;
	DataBrowserListViewColumnDesc = record
		propertyDesc: DataBrowserTableViewColumnDesc;
		headerBtnDesc: DataBrowserListViewHeaderDesc;
	end;
{ DataBrowserListView API }
const
	kDataBrowserListViewAppendColumn = kDataBrowserTableViewLastColumn;



{
 *  DataBrowserAccessibilityItemInfoV0
 *
 *  Summary:
 *    A specific description of Data Browser accessibility item
 *    information.
 *
 *  Discussion:
 *    If you fill this structure as part of a
 *    DataBrowserAccessibilityItemInfo, you must set the
 *    DataBrowserAccessibilityItemInfo's version field to zero.
 }
type
	DataBrowserAccessibilityItemInfoV0 = record
{
   * The DataBrowserItemID of the container the AXUIElementRef
   * represents or lives within. Even kDataBrowserNoItem might be
   * meaningful, since it is the root container ID if you haven't
   * overridden it via SetDataBrowserTarget. In list view, the
   * container helps narrow down the AXUIElementRef to either a
   * disclosed child of another row, or the list as a whole. In column
   * view, the container helps narrow down the AXUIElementRef to a
   * column; also see the columnProperty description below.
   }
		container: DataBrowserItemID;

  {
   * The DataBrowserItemID of the item the AXUIElementRef represents or
   * lives within. If item is kDataBrowserNoItem, the AXUIElementRef
   * represents just the container. In list view, the item helps narrow
   * down the AXUIElementRef to either a row, or the root container as
   * a whole. In column view, the item helps narrow down the
   * AXUIElementRef to either a cell, or a column as a whole; also see
   * the columnProperty description below.
   }
		item: DataBrowserItemID;

  {
   * The DataBrowserPropertyID of the column the AXUIElementRef
   * represents or lives within. If columnProperty is
   * kDataBrowserItemNoProperty and item is not kDataBrowserNoItem, the
   * AXUIElementRef represents a whole row. In list view, this field
   * helps narrow down the AXUIElementRef to either a cell, or a row as
   * a whole. In column view, the columnProperty will/must always be
   * set to kDataBrowserItemNoProperty unless the AXUIElementRef
   * represents the preview column. When the AXUIElementRef represents
   * the preview column, the columnProperty will/must always be set to
   * kDataBrowserColumnViewPreviewProperty, and the other fields of
   * this structure will/must be set to zero or the equivalent constant.
   }
		columnProperty: DataBrowserPropertyID;

  {
   * The DataBrowserPropertyPart of the sub-cell part the
   * AXUIElementRef represents. Examples include the disclosure
   * triangle in a cell, the text in a cell, and the check box in a
   * cell. If propertyPart is kDataBrowserPropertyEnclosingPart and
   * columnProperty is not kDataBrowserItemNoProperty, the
   * AXUIElementRef represents the cell as a whole. In both list view
   * and column view, this field helps narrow down the AXUIElementRef
   * to either a sub-cell part, or a cell as a whole. For column view,
   * also see the columnProperty description above.
   }
		propertyPart: DataBrowserPropertyPart;
	end;

{
 *  DataBrowserAccessibilityItemInfoV1
 *
 *  Summary:
 *    A specific description of Data Browser accessibility item
 *    information.
 *
 *  Discussion:
 *    If you fill this structure as part of a
 *    DataBrowserAccessibilityItemInfo, you must set the
 *    DataBrowserAccessibilityItemInfo's version field to one.
 *
 *    This structure is identical to the V0 structure except for the
 *    inclusion of row and column indices. These indices may be useful
 *    to clients who call AXUIElementGetDataBrowserItemInfo.
 *    If your Data Browser instance allows a given item and/or
 *    container to be displayed more than once at a given point in
 *    time, you can use the row and column indices to differentiate the
 *    particular visual occurances of that item when calling
 *    AXUIElementCreateWithDataBrowserAndItemInfo. See the additional
 *    details in the rowIndex and columnIndex discussions below.
 }
type
	DataBrowserAccessibilityItemInfoV1 = record
{
   * The DataBrowserItemID of the container the AXUIElementRef
   * represents or lives within. Even kDataBrowserNoItem might be
   * meaningful, since it is the root container ID if you haven't
   * overridden it via SetDataBrowserTarget. In list view, the
   * container helps narrow down the AXUIElementRef to either a
   * disclosed child of another row, or the list as a whole. In column
   * view, the container helps narrow down the AXUIElementRef to a
   * column; also see the columnProperty description below.
   }
		container: DataBrowserItemID;

  {
   * The DataBrowserItemID of the item the AXUIElementRef represents or
   * lives within. If item is kDataBrowserNoItem, the AXUIElementRef
   * represents just the container. In list view, the item helps narrow
   * down the AXUIElementRef to either a row, or the root container as
   * a whole. In column view, the item helps narrow down the
   * AXUIElementRef to either a cell, or a column as a whole; also see
   * the columnProperty description below.
   }
		item: DataBrowserItemID;

  {
   * The DataBrowserPropertyID of the column the AXUIElementRef
   * represents or lives within. If columnProperty is
   * kDataBrowserItemNoProperty and item is not kDataBrowserNoItem, the
   * AXUIElementRef represents a whole row. In list view, this field
   * helps narrow down the AXUIElementRef to either a cell, or a row as
   * a whole. In column view, the columnProperty will/must always be
   * set to kDataBrowserItemNoProperty unless the AXUIElementRef
   * represents the preview column. When the AXUIElementRef represents
   * the preview column, the columnProperty will/must always be set to
   * kDataBrowserColumnViewPreviewProperty, and the other fields of
   * this structure will/must be set to zero or the equivalent constant.
   }
		columnProperty: DataBrowserPropertyID;

  {
   * The DataBrowserPropertyPart of the sub-cell part the
   * AXUIElementRef represents. Examples include the disclosure
   * triangle in a cell, the text in a cell, and the check box in a
   * cell. If propertyPart is kDataBrowserPropertyEnclosingPart and
   * columnProperty is not kDataBrowserItemNoProperty, the
   * AXUIElementRef represents the cell as a whole. In both list view
   * and column view, this field helps narrow down the AXUIElementRef
   * to either a sub-cell part, or a cell as a whole. For column view,
   * also see the columnProperty description above.
   }
		propertyPart: DataBrowserPropertyPart;

  {
   * The zero-based DataBrowserTableViewRowIndex of the row specified
   * by the other parts of this structure. If the other parts of this
   * structure do not specify a row or a part thereof, this field
   * will/must be set to zero; because this field is zero based, you
   * must test the other parts this structure to see whether this field
   * is meaningful. In list view, when the other parts of this
   * structure specify an item or part thereof, this field will/must be
   * set to the row index at which the specified item can be found. In
   * column view, when the other parts of this structure specify a cell
   * or part thereof, this field will/must be set to the row index at
   * which the specified cell can be found.
   }
		rowIndex: DataBrowserTableViewRowIndex;

  {
   * The zero-based DataBrowserTableViewColumnIndex of the column
   * specified by the other parts of this structure. If the other parts
   * of this structure do not specify a column or a part thereof, this
   * field will/must be set to zero; because this field is zero based,
   * you must test the other parts this structure to see whether this
   * field is meaningful. In list view, when the other parts of this
   * structure specify a cell or part thereof, this field will/must be
   * set to the column index at which the specified cell can be found.
   * In column view, when the other parts of this structure specify a
   * column or part thereof, this field will/must be set to the column
   * index at which the specified cell can be found.
   }
		columnIndex: DataBrowserTableViewColumnIndex;
	end;

{
 *  DataBrowserAccessibilityItemInfo
 *
 *  Summary:
 *    A generalized description of Data Browser accessibility item
 *    information.
 *
 *  Discussion:
 *    Pass this structure to AXUIElementGetDataBrowserItemInfo or
 *    AXUIElementCreateWithDataBrowserAndItemInfo.
 }
type
	DataBrowserAccessibilityItemInfo = record
{
   * A UInt32 which identifies how to interpret the following union.
   * Set this field to zero if you fill out the union's data in the
   * form of a DataBrowserAccessibilityItemInfoV0 structure. Set this
   * field to one if you fill out the union's data in the form of a
   * DataBrowserAccessibilityItemInfoV1 structure.
   }
		version: UInt32;
		case SInt16 of
		0: (
			v0: DataBrowserAccessibilityItemInfoV0;
		);
		1: (
			v1: DataBrowserAccessibilityItemInfoV1;
		);
	end;

{$endc} {TARGET_OS_MAC}
{$ifc not defined MACOSALLINCLUDE or not MACOSALLINCLUDE}

end.
{$endc} {not MACOSALLINCLUDE}
