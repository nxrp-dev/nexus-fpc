{
     File:       CarbonCore/AVLTree.h

     Contains:   Interfaces for AVL balanced trees.
                 The contents of this header file are deprecated.

     Copyright:  © 1999-2011 by Apple Inc. All rights reserved.
}
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
unit AVLTree;
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
uses MacOsApi.MacTypes;
{$ELSE FPC_DOTTEDUNITS}
uses MacTypes;
{$ENDIF FPC_DOTTEDUNITS}
{$endc} {not MACOSALLINCLUDE}


{$ifc TARGET_OS_MAC}

{$ALIGN MAC68K}


{
 *  AVLVisitStage
 *
 *  Discussion:
 *    The visit stage for AVLWalk() walkProcs
 }
type
	AVLVisitStage = UInt16;
const
{
   * Passed the first time AVLWalk iterates thru a given node.
   }
	kAVLPreOrder = 0;

  {
   * Passed the AVLWalk iterates thru a given node when it is 'in
   * order'.
   }
	kAVLInOrder = 1;

  {
   * Passed the last time AVLWalk iterates thru a given node.
   }
	kAVLPostOrder = 2;


{
 *  AVLOrder
 *
 *  Discussion:
 *    The order the tree is walked or disposed of.
 }
type
	AVLOrder = UInt16;
const
{
   * Walk the tree in left-to-right order ( smaller to bigger, usually )
   }
	kLeftToRight = 0;

  {
   * Walk the tree in right-to-left order ( bigger to smaller, usually )
   }
	kRightToLeft = 1;


{
 *  AVLNodeType
 *
 *  Discussion:
 *    The type of the node being passed to a callback proc.
 }
type
	AVLNodeType = UInt16;
const
	kAVLIsTree = 0;
	kAVLIsLeftBranch = 1;
	kAVLIsRightBranch = 2;
	kAVLIsLeaf = 3;
	kAVLNullNode = 4;

const
	errItemAlreadyInTree = -960;
	errNotValidTree = -961;
	errItemNotFoundInTree = -962;
	errCanNotInsertWhileWalkProcInProgress = -963;
	errTreeIsLocked = -964;


{
 *  AVLTreeStruct
 *
 *  Summary:
 *    An opaque structure for a balanced binary tree.
 *
 *  Discussion:
 *    The structure of a tree.  It's opaque; don't assume it's 36 bytes
 *    in size.
 }
type
	AVLTreeStructPtr = ^AVLTreeStruct;
	AVLTreeStruct = record
		signature: OSType;
		privateStuff:			array [0..7] of UNSIGNEDLONG;
	end;
type
	AVLTreePtr = AVLTreeStructPtr;

{
 *  AVLCompareItemsProcPtr
 *
 *  Summary:
 *    A callback function which compares two data items and returns
 *    their ordering.
 *
 *  Discussion:
 *    Every tree must have a function which compares the data for two
 *    items and returns < 0, 0, or >0 for the items - < 0 if the first
 *    item is 'before' the second item according to some criteria, == 0
 *    if the two items are identical according to the criteria, or > 0
 *    if the first item is 'after' the second item according to the
 *    criteria.  The comparison function is also passed the node type,
 *    but most of the time this can be ignored.
 *
 *  Parameters:
 *
 *    tree:
 *      The tree which contains the items being compared
 *
 *    i1:
 *      A pointer to the first item
 *
 *    i2:
 *      A pointer to the second item
 *
 *    nd_typ:
 *      The type of the nodes being compared.  This is not terribly
 *      useful most of the time.
 *
 *  Result:
 *    A value < 0 if i1 is 'before' i2, > 0 if i1 is 'after' i2, or ==
 *    0 if i1 is equal to i2.
 }
type
	AVLCompareItemsProcPtr = function( tree: AVLTreePtr; i1: {const} UnivPtr; i2: {const} UnivPtr; nd_typ: AVLNodeType ): SInt32;

{
 *  AVLItemSizeProcPtr
 *
 *  Summary:
 *    A callback function which returns the size of an item.
 *
 *  Discussion:
 *    Every tree must have a itemSizeProc; this routine gets passed a
 *    pointer to the item's data and returns the size of the data.  If
 *    a tree contains records of a fixed size, this function can just
 *    return sizeof( that-struct ); otherwise it should calculate the
 *    size of the item based on the data for the item.
 *
 *  Parameters:
 *
 *    tree:
 *      The tree which contains the item whose size is being requested.
 *
 *    itemPtr:
 *      A pointer to the item whose size is being returned.
 *
 *  Result:
 *    The size of the item.
 }
type
	AVLItemSizeProcPtr = function( tree: AVLTreePtr; itemPtr: {const} UnivPtr ): ByteCount;

{
 *  AVLDisposeItemProcPtr
 *
 *  Summary:
 *    Dispose of any additional memory associated with an item in the
 *    tree.
 *
 *  Discussion:
 *    A tree may have an optional disposeItemProc, which gets called
 *    whenever an item is removed from the tree ( via AVLRemove() or
 *    when AVLDispose() deletes all of the items in the tree ). This
 *    might be useful if the nodes in the tree own 'resources'  ( like,
 *    open files ) which should be released before the item is removed.
 *
 *  Parameters:
 *
 *    tree:
 *      The tree containing the item being disposed.
 *
 *    dataP:
 *      A pointer to the data for the item being disposed.
 }
type
	AVLDisposeItemProcPtr = procedure( tree: AVLTreePtr; dataP: {const} UnivPtr );

{
 *  AVLWalkProcPtr
 *
 *  Summary:
 *    A callback function which gets passed each item in the tree, in a
 *    specified order.
 *
 *  Discussion:
 *    The common way to iterate across all of the items in a tree is
 *    via AVLWalk(), which takes a walkProcPtr.  This function will get
 *    called for every item in the tree three times, as the tree is
 *    being walked across.  First, the walkProc will get called with
 *    visitStage == kAVLPreOrder, at which point internally the node of
 *    the tree for the given data has just been reached.  Later, this
 *    function will get called with visitStage == kAVLInOrder, and
 *    lastly this function will get called with visitStage ==
 *    kAVLPostOrder. The 'minimum' item in the tree will get called
 *    with visitStage == kInOrder first, followed by the 'next' item in
 *    the tree, up until the last item in the tree structure is called.
 *    In general, you'll only care about calls to this function when
 *    visitStage == kAVLInOrder.
 *
 *  Parameters:
 *
 *    tree:
 *      The tree being walked.
 *
 *    dataPtr:
 *      A pointer to the data for an item in the tree.
 *
 *    visitStage:
 *      The stage of the walk for the given node.
 *
 *    node:
 *      The type of the given node. This is not terribly useful most of
 *      the time.
 *
 *    level:
 *      How 'deep' in the tree the given node is.  This is not terribly
 *      useful most of the time.
 *
 *    balance:
 *      How balanced the given node in the tree is.  This is not
 *      terribly useful most of the time.
 *
 *    refCon:
 *      The refCon passed into AVLWalk() for this call.
 *
 *  Result:
 *    Return 0 to continue walking the tree, or 1 to terminate.
 }
type
	AVLWalkProcPtr = function( tree: AVLTreePtr; dataPtr: {const} UnivPtr; visitStage: AVLVisitStage; node: AVLNodeType; level: UInt32; balance: SInt32; refCon: UnivPtr ): OSErr;
	AVLCompareItemsUPP = AVLCompareItemsProcPtr;
	AVLItemSizeUPP = AVLItemSizeProcPtr;
	AVLDisposeItemUPP = AVLDisposeItemProcPtr;
	AVLWalkUPP = AVLWalkProcPtr;
{
 *  NewAVLCompareItemsUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewAVLCompareItemsUPP( userRoutine: AVLCompareItemsProcPtr ): AVLCompareItemsUPP; external name '_NewAVLCompareItemsUPP';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_5, __IPHONE_NA, __IPHONE_NA) *)

{
 *  NewAVLItemSizeUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewAVLItemSizeUPP( userRoutine: AVLItemSizeProcPtr ): AVLItemSizeUPP; external name '_NewAVLItemSizeUPP';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_5, __IPHONE_NA, __IPHONE_NA) *)

{
 *  NewAVLDisposeItemUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewAVLDisposeItemUPP( userRoutine: AVLDisposeItemProcPtr ): AVLDisposeItemUPP; external name '_NewAVLDisposeItemUPP';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_5, __IPHONE_NA, __IPHONE_NA) *)

{
 *  NewAVLWalkUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function NewAVLWalkUPP( userRoutine: AVLWalkProcPtr ): AVLWalkUPP; external name '_NewAVLWalkUPP';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_5, __IPHONE_NA, __IPHONE_NA) *)

{
 *  DisposeAVLCompareItemsUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeAVLCompareItemsUPP( userUPP: AVLCompareItemsUPP ); external name '_DisposeAVLCompareItemsUPP';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_5, __IPHONE_NA, __IPHONE_NA) *)

{
 *  DisposeAVLItemSizeUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeAVLItemSizeUPP( userUPP: AVLItemSizeUPP ); external name '_DisposeAVLItemSizeUPP';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_5, __IPHONE_NA, __IPHONE_NA) *)

{
 *  DisposeAVLDisposeItemUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeAVLDisposeItemUPP( userUPP: AVLDisposeItemUPP ); external name '_DisposeAVLDisposeItemUPP';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_5, __IPHONE_NA, __IPHONE_NA) *)

{
 *  DisposeAVLWalkUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure DisposeAVLWalkUPP( userUPP: AVLWalkUPP ); external name '_DisposeAVLWalkUPP';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_5, __IPHONE_NA, __IPHONE_NA) *)

{
 *  InvokeAVLCompareItemsUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function InvokeAVLCompareItemsUPP( tree: AVLTreePtr; i1: {const} UnivPtr; i2: {const} UnivPtr; nd_typ: AVLNodeType; userUPP: AVLCompareItemsUPP ): SInt32; external name '_InvokeAVLCompareItemsUPP';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_5, __IPHONE_NA, __IPHONE_NA) *)

{
 *  InvokeAVLItemSizeUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function InvokeAVLItemSizeUPP( tree: AVLTreePtr; itemPtr: {const} UnivPtr; userUPP: AVLItemSizeUPP ): ByteCount; external name '_InvokeAVLItemSizeUPP';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_5, __IPHONE_NA, __IPHONE_NA) *)

{
 *  InvokeAVLDisposeItemUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
procedure InvokeAVLDisposeItemUPP( tree: AVLTreePtr; dataP: {const} UnivPtr; userUPP: AVLDisposeItemUPP ); external name '_InvokeAVLDisposeItemUPP';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_5, __IPHONE_NA, __IPHONE_NA) *)

{
 *  InvokeAVLWalkUPP()
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   available as macro/inline
 }
function InvokeAVLWalkUPP( tree: AVLTreePtr; dataPtr: {const} UnivPtr; visitStage: AVLVisitStage; node: AVLNodeType; level: UInt32; balance: SInt32; refCon: UnivPtr; userUPP: AVLWalkUPP ): OSErr; external name '_InvokeAVLWalkUPP';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_5, __IPHONE_NA, __IPHONE_NA) *)


{$endc} {TARGET_OS_MAC}
{$ifc not defined MACOSALLINCLUDE or not MACOSALLINCLUDE}

end.
{$endc} {not MACOSALLINCLUDE}
