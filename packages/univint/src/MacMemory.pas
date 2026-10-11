{
     File:       CarbonCore/MacMemory.h

     Contains:   Memory Manager Interfaces.
                 The contents of this header file are deprecated.
                 Use malloc, free, etc instead.

     Copyright:  © 1985-2011 by Apple Inc. All rights reserved.
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
unit MacMemory;
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


const
	maxSize = $7FFFFFF0; {the largest block possible}

{
    If you define a macro named __MAC_OS_X_MEMORY_MANAGER_CLEAN__ with a non-zero value, then
    some Memory Manager APIs will become inlined, minimal implementations.  See the comments
    below for more information about this.
}
{$setc __MAC_OS_X_MEMORY_MANAGER_CLEAN__ := 0}

{$ifc not __MAC_OS_X_MEMORY_MANAGER_CLEAN__}
const
	defaultPhysicalEntryCount = 8;

const
{ values returned from the GetPageState function }
	kPageInMemory = 0;
	kPageOnDisk = 1;
	kNotPaged = 2;

const
{ masks for Zone->heapType field }
	k32BitHeap = 1;    { valid in all Memory Managers }
	kNewStyleHeap = 2;    { true if new Heap Manager is present }
	kNewDebugHeap = 4;     { true if new Heap Manager is running in debug mode on this heap }


{$endc} {not __MAC_OS_X_MEMORY_MANAGER_CLEAN__}

{ bits for use with HGetState/HSetState}
const
	kHandleIsResourceBit = 5;
	kHandlePurgeableBit = 6;
	kHandleLockedBit = 7;

{ masks for use with HGetState/HSetState}
const
	kHandleIsResourceMask = $20;
	kHandlePurgeableMask = $40;
	kHandleLockedMask = $80;


{
 *  MemError()
 *
 *  Summary:
 *    Determines if an application’s last direct call to a Memory
 *    Manager function executed successfully.
 *
 *  Discussion:
 *    MemError() yields the result code produced by the last Memory
 *    Manager function your application called directly, and resets
 *    MemError() to return noErr in the future. MemError() is useful
 *    during application debugging. You might also use MemError as one
 *    part of a memory-management scheme to identify instances in which
 *    the Memory Manager rejects overly large memory requests by
 *    returning the error code memFullErr.
 *
 *    To view the result codes that MemError() can produce, see "Memory
 *    Manager Result Codes".
 *
 *    Do not rely on MemError() as the only component of a
 *    memory-management scheme. For example, suppose you call NewHandle
 *    or NewPtr and receive the result code noErr, indicating that the
 *    Memory Manager was able to allocate sufficient memory. In this
 *    case, you have no guarantee that the allocation did not deplete
 *    your application’s memory reserves to levels so low that simple
 *    operations might cause your application to crash. Instead of
 *    relying on MemError(), check before making a memory request that
 *    there is enough memory both to fulfill the request and to support
 *    essential operations.
 *
 *    On Mac OS X 10.3 and later, the value of MemError() is kept for
 *    each thread; prior to Mac OS X 10.3.  MemError() is global to the
 *    application.  Because of this, and other problems, the Memory
 *    Manager APIs are not thread safe before Mac OS X 10.3.
 *
 *  Mac OS X threading:
 *    Thread safe since version 10.3
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in InterfaceLib 7.1 and later
 }
function MemError: OSErr; external name '_MemError';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_8, __IPHONE_NA, __IPHONE_NA) *)


{
 *  LMGetMemErr()
 *
 *  Summary:
 *    Returns the result of the last Memory Manager function, without
 *    clearing the value like MemError() does.
 *
 *  Discussion:
 *    LMGetMemErr yields the result code produced by the last Memory
 *    Manager function your application called directly. Unlike
 *    MemError(), this function does not reset the stored value, so
 *    subsequent calls to LMGetMemErr() will still return this value
 *    until the next Memory Manager routine is called or until
 *    MemError() is called to reset the value. LMGetMemErr is useful
 *    during application debugging. You might also use this value as
 *    one part of a memory-management scheme to identify instances in
 *    which the Memory Manager rejects overly large memory requests by
 *    returning the error code memFullErr.
 *
 *    To view the result codes that MemError() can produce, see "Memory
 *    Manager Result Codes".
 *
 *    Do not rely on MemError() as the only component of a
 *    memory-management scheme. For example, suppose you call NewHandle
 *    or NewPtr and receive the result code noErr, indicating that the
 *    Memory Manager was able to allocate sufficient memory. In this
 *    case, you have no guarantee that the allocation did not deplete
 *    your application’s memory reserves to levels so low that simple
 *    operations might cause your application to crash. Instead of
 *    relying on MemError(), check before making a memory request that
 *    there is enough memory both to fulfill the request and to support
 *    essential operations.
 *
 *    On Mac OS X 10.3 and later, the value of MemError() is kept for
 *    each thread; prior to Mac OS X 10.3 there was one global value of
 *    MemError() which all threads shared. Because of this, and other
 *    problems, the Memory Manager APIs are not thread safe before Mac
 *    OS X 10.3.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in InterfaceLib 7.1 and later
 }
function LMGetMemErr: SInt16; external name '_LMGetMemErr';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_8, __IPHONE_NA, __IPHONE_NA) *)


{
 *  LMSetMemErr()
 *
 *  Summary:
 *    Set the value which will be returned by MemError()
 *
 *  Discussion:
 *    User code shouldn't need to call this function, which is used to
 *    set the value which the next call to MemError() will return.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Parameters:
 *
 *    value:
 *      the value which the next MemError() function call should return
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in InterfaceLib 7.1 and later
 }
procedure LMSetMemErr( value: SInt16 ); external name '_LMSetMemErr';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_8, __IPHONE_NA, __IPHONE_NA) *)


{
 *  NewHandle()
 *
 *  Summary:
 *    Allocate a relocatable memory block of a specified size.
 *
 *  Discussion:
 *    The NewHandle function attempts to allocate a new relocatable
 *    block in the current heap zone with a logical size of logicalSize
 *    bytes and then return a handle to the block. The new block is
 *    unlocked and unpurgeable. If NewHandle cannot allocate a block of
 *    the requested size, it returns NULL.  The memory block returned
 *    likely will contain garbage, and will be unlocked and
 *    non-purgeable.
 *
 *    WARNING
 *
 *    Do not try to manufacture your own handles without this function
 *    by simply assigning the address of a variable of type Ptr to a
 *    variable of type Handle. The resulting "fake handle" would not
 *    reference a relocatable block and could cause a system crash.
 *     If this function returns NIL, the error result can be determined
 *    by calling the function MemError().
 *
 *  Mac OS X threading:
 *    Thread safe since version 10.3
 *
 *  Parameters:
 *
 *    byteCount:
 *      the size of the relocatable memory block to allocate.  If this
 *      value is < 0, NIL will be returned. If this value is 0, a
 *      handle to 0 byte block will be returned.
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in InterfaceLib 7.1 and later
 }
function NewHandle( byteCount: Size ): Handle; external name '_NewHandle';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_8, __IPHONE_NA, __IPHONE_NA) *)


{
 *  NewHandleClear()
 *
 *  Summary:
 *    Allocate a relocatable memory block of a specified size.
 *
 *  Discussion:
 *    The NewHandle function attempts to allocate a new relocatable
 *    block in the current heap zone with a logical size of logicalSize
 *    bytes and then return a handle to the block. The new block is
 *    unlocked and unpurgeable. If NewHandle cannot allocate a block of
 *    the requested size, it returns NULL.  The memory block returned
 *    will be zeroed, and will be unlocked and non-purgeable.
 *
 *    WARNING
 *
 *    Do not try to manufacture your own handles without this function
 *    by simply assigning the address of a variable of type Ptr to a
 *    variable of type Handle. The resulting "fake handle" would not
 *    reference a relocatable block and could cause a system crash.
 *     If this function returns NIL, the error result can be determined
 *    by calling the function MemError().
 *
 *  Mac OS X threading:
 *    Thread safe since version 10.3
 *
 *  Parameters:
 *
 *    byteCount:
 *      the size of the relocatable memory block to allocate.  If this
 *      value is < 0, NIL will be returned. If this value is 0, a
 *      handle to 0 byte block will be returned.
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in InterfaceLib 7.1 and later
 }
function NewHandleClear( byteCount: Size ): Handle; external name '_NewHandleClear';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_8, __IPHONE_NA, __IPHONE_NA) *)


{
 *  RecoverHandle()
 *
 *  Summary:
 *    Returns a handle to a relocatable block pointed to by a specified
 *    pointer.
 *
 *  Discussion:
 *    The Memory Manager does not allow you to change relocatable
 *    blocks into nonrelocatable blocks, or vice-versa. However, if you
 *    no longer have access to a handle but still have access to its
 *    master pointer p, you can use the RecoverHandle function to
 *    recreate a handle to the relocatable block referenced by
 *    p.
 *
 *    Call the function MemError() to get the result code. See "Memory
 *    Manager Result Codes".
 *
 *  Mac OS X threading:
 *    Thread safe since version 10.3
 *
 *  Parameters:
 *
 *    p:
 *      the master pointer to a relocatable block.
 *
 *  Result:
 *    A handle to a relocatable block point to by p. If p does not
 *    point to a valid block, this function returns NULL.
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in InterfaceLib 7.1 and later
 }
function RecoverHandle( p: Ptr ): Handle; external name '_RecoverHandle';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_8, __IPHONE_NA, __IPHONE_NA) *)


{
 *  NewPtr()
 *
 *  Summary:
 *    Allocates a nonrelocatable block of memory of a specified size.
 *
 *  Discussion:
 *    The NewPtr function attempts to reserve space for the new block.
 *    If it is able to reserve the requested amount of space, NewPtr
 *    allocates the nonrelocatable block.  Otherwise, NewPtr returns
 *    NULL and generates a memFullErr error. On Mac OS X, NewPtr will
 *    never fail because it is unable to allocate the pointer. Certain
 *    old versions of Mac OS X return a NULL pointer when asked to
 *    allocate a pointer of size 0.
 *    Call the function MemError to get the result code. See "Memory
 *    Manager Result Codes".
 *
 *  Mac OS X threading:
 *    Thread safe since version 10.3
 *
 *  Parameters:
 *
 *    byteCount:
 *      The requested size (in bytes) of the nonrelocatable block.  If
 *      you pass a value of zero, this function returns a valid zero
 *      length pointer.
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in InterfaceLib 7.1 and later
 }
function NewPtr( byteCount: Size ): Ptr; external name '_NewPtr';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_8, __IPHONE_NA, __IPHONE_NA) *)


{
 *  NewPtrClear()
 *
 *  Summary:
 *    Allocates a nonrelocatable block of memory of a specified size
 *    with all its bytes set to 0.
 *
 *  Discussion:
 *    The NewPtr function attempts to reserve space for the new block.
 *    If it is able to reserve the requested amount of space, NewPtr
 *    allocates the nonrelocatable block.  Otherwise, NewPtr returns
 *    NULL and generates a memFullErr error. On Mac OS X, NewPtr will
 *    never fail because it is unable to allocate the pointer. Certain
 *    old versions of Mac OS X return a NULL pointer when asked to
 *    allocate a pointer of size 0.
 *    Call the function MemError to get the result code. See "Memory
 *    Manager Result Codes".
 *
 *  Mac OS X threading:
 *    Thread safe since version 10.3
 *
 *  Parameters:
 *
 *    byteCount:
 *      The requested size (in bytes) of the nonrelocatable block.  If
 *      you pass a value of zero, this function returns a valid zero
 *      length pointer.
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in InterfaceLib 7.1 and later
 }
function NewPtrClear( byteCount: Size ): Ptr; external name '_NewPtrClear';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_8, __IPHONE_NA, __IPHONE_NA) *)



{
 *  NewEmptyHandle()
 *
 *  Summary:
 *    Initializes a new handle without allocating any memory for it to
 *    control.
 *
 *  Discussion:
 *    When you want to allocate memory for the empty handle, use the
 *    ReallocateHandle function.
 *    Call the function MemError to get the result code. See "Memory
 *    Manager Result Codes".
 *
 *  Mac OS X threading:
 *    Thread safe since version 10.3
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in InterfaceLib 7.1 and later
 }
function NewEmptyHandle: Handle; external name '_NewEmptyHandle';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_8, __IPHONE_NA, __IPHONE_NA) *)


{
 *  HLock()
 *
 *  Summary:
 *    Lock a relocatable block so that it does not move in the heap
 *
 *  Discussion:
 *    The HLock procedure locks the relocatable block to which h is a
 *    handle, preventing it from being moved within its heap zone. If
 *    the block is already locked,HLock does nothing.
 *
 *    On Mac OS X, the behaviour of the Memory Manager and of heaps in
 *    general is different than on Mac OS 9.x and earlier. In
 *    particular, the heap on Mac OS X is never purged or compacted.
 *    Therefore, an unlocked handle will never be relocated except as a
 *    result of a direct action by something calling SetHandleSize() or
 *    by using a function like PtrAndHand() which implicitly resizes
 *    the handle to append data to it.  Because of this, most locking
 *    and unlocking of handles is unnecessary on Mac OS X, and the use
 *    of HLock() and other functions is being deprecated.  If you
 *    define a macro named __MAC_OS_X_MEMORY_MANAGER_CLEAN__ to 1 in
 *    your sources before you include MacMemory.h, then HLock() and
 *    several other functions will become empty operations, removing
 *    the overhead of a function call.
 *
 *    However, some applications are relying on the behavior that
 *    resizing a locked handle produces an error, or tracking the state
 *    of the locked bit for a give handle via the HGetState() function.
 *     Applications which rely on this can not use
 *    __MAC_OS_X_MEMORY_MANAGER_CLEAN__.
 *
 *  Mac OS X threading:
 *    Thread safe since version 10.3
 *
 *  Parameters:
 *
 *    h:
 *      the handle to lock.  If h is == NULL, then HLock() sets
 *      MemError() to noErr.
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in InterfaceLib 7.1 and later
 }
procedure HLock( h: Handle ); external name '_HLock';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_8, __IPHONE_NA, __IPHONE_NA) *)


{
 *  HLockHi()
 *
 *  Summary:
 *    Lock a relocatable handle.
 *
 *  Discussion:
 *    The HLockHi() function locks a handle in memory.  On versions of
 *    Mac OS before Mac OS X, it would first attempt to move the handle
 *    as high in memory as feasible.  However, on Mac OS X and later,
 *    there is no advantage to having handles high in memory, and so
 *    this function never moves a handle before locking it.
 *    See the discussion about handle locking above the function
 *    HLock().
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Parameters:
 *
 *    h:
 *      the handle to lock.  If h is == NULL, then HLockHi() sets
 *      MemError() to noErr.
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in InterfaceLib 7.1 and later
 }
procedure HLockHi( h: Handle ); external name '_HLockHi';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_8, __IPHONE_NA, __IPHONE_NA) *)


{
 *  HUnlock()
 *
 *  Summary:
 *    Unlock a relocatable block so that it does not move in the heap
 *
 *  Discussion:
 *    The HUnlock procedure unlocks the relocatable block to which h is
 *    a handle, allowing it from being moved within its heap zone. If
 *    the block is already unlocked, HUnlock does nothing.
 *
 *    See the discussion about handles and locking on Mac OS X above
 *    the HLock() function.
 *
 *  Mac OS X threading:
 *    Thread safe since version 10.3
 *
 *  Parameters:
 *
 *    h:
 *      the handle to unlock.  If h is == NULL, then HUnlock() sets
 *      MemError() to noErr.
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in InterfaceLib 7.1 and later
 }
procedure HUnlock( h: Handle ); external name '_HUnlock';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_8, __IPHONE_NA, __IPHONE_NA) *)



{
 *  TempNewHandle()
 *
 *  Summary:
 *    Allocate a relocatable memory block of a specified size.
 *
 *  Discussion:
 *    The TempNewHandle function attempts to allocate a new relocatable
 *    block in the current heap zone with a logical size of logicalSize
 *    bytes and then return a handle to the block. The new block is
 *    unlocked and unpurgeable. If NewHandle cannot allocate a block of
 *    the requested size, it returns NULL.  The memory block returned
 *    likely will contain garbage.
 *
 *    WARNING
 *
 *    Do not try to manufacture your own handles without this function
 *    by simply assigning the address of a variable of type Ptr to a
 *    variable of type Handle. The resulting "fake handle" would not
 *    reference a relocatable block and could cause a system crash.
 *     If this function returns NIL, the error result can be determined
 *    by calling the function MemError().
 *
 *    On Mac OS X, there is no temporary memory heap, and thus no
 *    difference between the handles returned by TempNewHandle() and
 *    those returned by NewHandle().  The only difference between the
 *    two is that TempNewHandle() also returns the error result of the
 *    call in resultCode.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Parameters:
 *
 *    logicalSize:
 *      the size of the relocatable memory block to allocate.  If this
 *      value is < 0, NIL will be returned. If this value is 0, a
 *      handle to 0 byte block will be returned.
 *
 *    resultCode:
 *      On exit, this will be set to the result of the operation.
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in InterfaceLib 7.1 and later
 }
function TempNewHandle( logicalSize: Size; var resultCode: OSErr ): Handle; external name '_TempNewHandle';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_8, __IPHONE_NA, __IPHONE_NA) *)



{
 *  DisposePtr()
 *
 *  Summary:
 *    Release memory occupied by a nonrelocatable block
 *
 *  Discussion:
 *    When you no longer need a nonrelocatable block, call the
 *    DisposePtr function to free it for other uses.
 *    Call the function MemError to get the result code. See "Memory
 *    Manager Result Codes".
 *    After a call to DisposePtr, all pointers to the released block
 *    become invalid and should not be used again. Any subsequent use
 *    of a pointer to the released block might cause a system error.
 *    You can pass the value NULL as the pointer to dispose.
 *
 *  Mac OS X threading:
 *    Thread safe since version 10.3
 *
 *  Parameters:
 *
 *    p:
 *      A pointer to the nonrelocatable block you want to dispose of
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in InterfaceLib 7.1 and later
 }
procedure DisposePtr( p: Ptr ); external name '_DisposePtr';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_8, __IPHONE_NA, __IPHONE_NA) *)


{
 *  GetPtrSize()
 *
 *  Summary:
 *    Returns the logical size of the nonrelocatable block
 *    corresponding to a pointer.
 *
 *  Discussion:
 *    This function returns the number of bytes used for the given
 *    pointer.  Call the function MemError to get the result code. See
 *    "Memory Manager Result Codes".
 *
 *  Mac OS X threading:
 *    Thread safe since version 10.3
 *
 *  Parameters:
 *
 *    p:
 *      a pointer to a nonrelocatable block.
 *
 *  Result:
 *    The logical size, in bytes, of the nonrelocatable block pointed
 *    to by p. In case of error, the function returns 0.
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in InterfaceLib 7.1 and later
 }
function GetPtrSize( p: Ptr ): Size; external name '_GetPtrSize';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_8, __IPHONE_NA, __IPHONE_NA) *)


{
 *  SetPtrSize()
 *
 *  Mac OS X threading:
 *    Thread safe since version 10.3
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in InterfaceLib 7.1 and later
 }
procedure SetPtrSize( p: Ptr; newSize: Size ); external name '_SetPtrSize';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_8, __IPHONE_NA, __IPHONE_NA) *)


{
 *  DisposeHandle()
 *
 *  Summary:
 *    Releases memory occupied by a relocatable block.
 *
 *  Discussion:
 *    The DisposeHandle function releases the memory occupied by the
 *    relocatable block whose handle is h. It also frees the handle’s
 *    master pointer for other uses.
 *    Do not use DisposeHandle to dispose of a handle obtained from the
 *    Resource Manager (for example, by a previous call to
 *    GetResource), useReleaseResource instead. If, however, you have
 *    called DetachResource on a resource handle, you should dispose of
 *    the storage by callingDisposeHandle.
 *    Call the function MemError to get the result code. See "Memory
 *    Manager Result Codes".
 *    After a call to DisposeHandle, all handles to the released block
 *    become invalid and should not be used again. Any subsequent calls
 *    to DisposeHandleusing an invalid handle might damage the master
 *    pointer list.  You can pass the value NULL as the handle to
 *    dispose.
 *
 *  Mac OS X threading:
 *    Thread safe since version 10.3
 *
 *  Parameters:
 *
 *    h:
 *      A handle to a relocatable block.
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in InterfaceLib 7.1 and later
 }
procedure DisposeHandle( h: Handle ); external name '_DisposeHandle';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_8, __IPHONE_NA, __IPHONE_NA) *)


{
 *  SetHandleSize()
 *
 *  Summary:
 *    Changes the logical size of the relocatable block corresponding
 *    to the specified handle.
 *
 *  Discussion:
 *    Change the logical size of the relocatable block corresponding to
 *    the specified handle. SetHandleSize might need to move the
 *    relocatable block to obtain enough space for the resized block.
 *    Thus, for best results you should unlock a block before resizing
 *    it.
 *
 *    An attempt to increase the size of a locked block might fail,
 *    because of blocks above and below it that are either
 *    nonrelocatable or locked. You should be prepared for this
 *    possibility.
 *
 *    Instead of using the SetHandleSize function to set the size of a
 *    handle to 0, you can use the EmptyHandle function.
 *
 *  Mac OS X threading:
 *    Thread safe since version 10.3
 *
 *  Parameters:
 *
 *    h:
 *      a handle to a relocatable block.
 *
 *    newSize:
 *      the desired new logical size, in bytes, of the relocatable
 *      block.
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in InterfaceLib 7.1 and later
 }
procedure SetHandleSize( h: Handle; newSize: Size ); external name '_SetHandleSize';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_8, __IPHONE_NA, __IPHONE_NA) *)


{
 *  GetHandleSize()
 *
 *  Summary:
 *    Returns the logical size of the relocatable block corresponding
 *    to a handle.
 *
 *  Discussion:
 *    Returns the logical size of the relocatable block corresponding
 *    to a handle.  Call the function MemError to get the result code.
 *    See "Memory Manager Result Codes".
 *
 *  Mac OS X threading:
 *    Thread safe since version 10.3
 *
 *  Parameters:
 *
 *    h:
 *      a handle to a relocatable block.
 *
 *  Result:
 *    The logical size, in bytes, of the relocatable block whose handle
 *    is h. In case of error, the function return 0.
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in InterfaceLib 7.1 and later
 }
function GetHandleSize( h: Handle ): Size; external name '_GetHandleSize';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_8, __IPHONE_NA, __IPHONE_NA) *)


{
 *  ReallocateHandle()
 *
 *  Summary:
 *    Allocates a new relocatable block of a specified size and sets a
 *    handle’s master pointer to point to the new block.
 *
 *  Discussion:
 *    Usually you use ReallocateHandle to reallocate space for a block
 *    that you have emptied. If the handle references an existing
 *    block, ReallocateHandle releases that block before creating a new
 *    one.
 *
 *    To reallocate space for a resource that has been purged, you
 *    should call LoadResource, not ReallocateHandle. To resize
 *    relocatable blocks, you should call the SetHandleSize
 *    function.
 *
 *    Call the function MemError to get the result code. See "Memory
 *    Manager Result Codes".
 *
 *  Mac OS X threading:
 *    Thread safe since version 10.3
 *
 *  Parameters:
 *
 *    h:
 *      A handle to a relocatable block.
 *
 *    byteCount:
 *      the desired new logical size (in bytes) of the relocatable
 *      block. The new block is unlocked and unpurgeable.
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in InterfaceLib 7.1 and later
 }
procedure ReallocateHandle( h: Handle; byteCount: Size ); external name '_ReallocateHandle';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_8, __IPHONE_NA, __IPHONE_NA) *)


{
 *  EmptyHandle()
 *
 *  Summary:
 *    Purges a relocatable block and sets the corresponding handle’s
 *    master pointer to NULL.
 *
 *  Discussion:
 *    The EmptyHandle function purges the relocatable block whose
 *    handle is h and sets the handle’s master pointer to NULL. The
 *    EmptyHandle function allows you to free memory taken by a
 *    relocatable block without freeing the relocatable block’s master
 *    pointer for other uses. The block whose handle is h must be
 *    unlocked but need not be purgeable.
 *
 *    Note that if there are multiple handles to the relocatable block,
 *    then calling the EmptyHandle function empties them all, because
 *    all of the handles share a common master pointer. When you later
 *    use ReallocateHandle to reallocate space for the block, the
 *    master pointer is updated, and all of the handles reference the
 *    new block correctly.
 *
 *    To free the memory taken up by a relocatable block and release
 *    the block’s master pointer for other uses, use the DisposeHandle
 *    function.
 *
 *    Call the function MemError to get the result code. See "Memory
 *    Manager Result Codes".
 *
 *  Mac OS X threading:
 *    Thread safe since version 10.3
 *
 *  Parameters:
 *
 *    h:
 *      a handle to a relocatable block.
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in InterfaceLib 7.1 and later
 }
procedure EmptyHandle( h: Handle ); external name '_EmptyHandle';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_8, __IPHONE_NA, __IPHONE_NA) *)


{
 *  HSetRBit()
 *
 *  Summary:
 *    Set the "R" bit for the handle state.
 *
 *  Mac OS X threading:
 *    Thread safe since version 10.3
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in InterfaceLib 7.1 and later
 }
procedure HSetRBit( h: Handle ); external name '_HSetRBit';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_8, __IPHONE_NA, __IPHONE_NA) *)


{
 *  HClrRBit()
 *
 *  Summary:
 *    Clear the "R" bit for the handle state.
 *
 *  Mac OS X threading:
 *    Thread safe since version 10.3
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in InterfaceLib 7.1 and later
 }
procedure HClrRBit( h: Handle ); external name '_HClrRBit';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_8, __IPHONE_NA, __IPHONE_NA) *)


{
 *  HGetState()
 *
 *  Summary:
 *    Get the current state of the handle's locked, purgeable, and R
 *    bits
 *
 *  Discussion:
 *    The HGetState function returns a signed byte (AnsiChar) containing
 *    the flags of the master pointer for the given handle. You can
 *    save this byte, change the state of any of the flags using the
 *    functions described in this section, and then restore their
 *    original states by passing the byte to the HSetState
 *    function.
 *
 *    You can use bit-manipulation functions on the returned signed
 *    byte to determine the value of a given attribute.
 *    Currently the following bits are used:
 *    kHandleIsResourceBit    - if set, handle is a resource
 *     kHandlePurgeableBit - if set, handle is purgeable
 *     kHandleLockedBit - if set, handle is locked
 *    On Mac OS X and later, heaps are never purged, so the purgeable
 *    bit is used but its setting is essentially ignored. Also, since
 *    heaps are never compacted, and therefore the only time a handle
 *    moves is when that handle is resized, the danger of using
 *    defererenced handles is lower and so handles likely do not need
 *    to be locked as often. Because of this, the state for a handle is
 *    less useful, and HGetState() and other functions is being
 *    deprecated.  If you define a macro named
 *    __MAC_OS_X_MEMORY_MANAGER_CLEAN__ in your sources before you
 *    include MacMemory.h, then HGetState() and several other functions
 *    will become empty operations, removing the overhead of a function
 *    call.
 *
 *    However, some applications may depend on the state bits of a
 *    handle being correct or changing as functions like HLock(), etc.,
 *    are called.  Applications which rely on this can not use
 *    __MAC_OS_X_MEMORY_MANAGER_CLEAN__.
 *
 *  Mac OS X threading:
 *    Thread safe since version 10.3
 *
 *  Parameters:
 *
 *    h:
 *      the handle to get the state for
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in InterfaceLib 7.1 and later
 }
function HGetState( h: Handle ): SInt8; external name '_HGetState';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_8, __IPHONE_NA, __IPHONE_NA) *)


{
 *  HSetState()
 *
 *  Summary:
 *    Set the current state of the handle's locked, purgeable, and R
 *    bits
 *
 *  Discussion:
 *    See the discussion about handle state and Mac OS X above the
 *    function HGetState().
 *
 *  Mac OS X threading:
 *    Thread safe since version 10.3
 *
 *  Parameters:
 *
 *    h:
 *      the handle to set the state for
 *
 *    flags:
 *      the flags to set for the handle
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in InterfaceLib 7.1 and later
 }
procedure HSetState( h: Handle; flags: SInt8 ); external name '_HSetState';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_8, __IPHONE_NA, __IPHONE_NA) *)


{****************************************************************************

    Beginning in Mac OS X Tiger, BlockMove, BlockMoveData, BlockMoveUncached,
    BlockMoveDataUncached, BlockZero, and BlockZeroUncached are inlined to a
    direct call to the posix memmove or bzero functions; this allows the
    compiler to optimize in some cases.

    However, CarbonCore.framework still exports functions with these names,
    both so old code which linked them there will run and to support
    compilers which don't support inline function definitions.

    To use the exported version of BlockMove, #define NO_BLOCKMOVE_INLINE
    in your source code ( or prefix header file ) before including any headers
    which would include MacMemory.h.

****************************************************************************}



{
 *  HandToHand()
 *
 *  Summary:
 *    Copies all of the data from one relocatable block to a new
 *    relocatable block.
 *
 *  Discussion:
 *    The HandToHand function attempts to copy the information in the
 *    relocatable block to which theHndl is a handle; if successful,
 *    HandToHand sets theHndlto a handle pointing to the new
 *    relocatable block.
 *
 *    If successful in creating a new relocatable block, the HandToHand
 *    function does not duplicate the properties of the original block.
 *    The new block is unlocked, unpurgeable, and not a resource. Call
 *    HLock or HPurge to adjust the properties of the new
 *    block.
 *
 *    To copy only part of a relocatable block into a new relocatable
 *    block, use the PtrToHand function. Before calling PtrToHand, lock
 *    and dereference the handle pointing to the relocatable block you
 *    want to copy.
 *
 *    Because HandToHand replaces its parameter with the new handle,
 *    you should retain the original parameter value somewhere else,
 *    otherwise you will not be able to access it.
 *
 *  Mac OS X threading:
 *    Thread safe since version 10.3
 *
 *  Parameters:
 *
 *    theHndl:
 *      a handle to the relocatable block whose data HandToHand will
 *      copy.  On return, theHndl contains a handle to a new
 *      relocatable block whose data duplicates the original.
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in InterfaceLib 7.1 and later
 }
function HandToHand( var theHndl: Handle ): OSErr; external name '_HandToHand';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_8, __IPHONE_NA, __IPHONE_NA) *)


{
 *  PtrToXHand()
 *
 *  Summary:
 *    Copies data referenced by a pointer to an existing relocatable
 *    block.
 *
 *  Discussion:
 *    The PtrToXHand function copies the specified number of bytes from
 *    the location specified by srcPtr to the handle specified by
 *    dstHndl.
 *
 *  Mac OS X threading:
 *    Thread safe since version 10.3
 *
 *  Parameters:
 *
 *    srcPtr:
 *      the address of the first byte to copy.
 *
 *    dstHndl:
 *      a handle to an existing relocatable block.
 *
 *    size:
 *      the number of bytes to copy.
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in InterfaceLib 7.1 and later
 }
function PtrToXHand( srcPtr: {const} UnivPtr; dstHndl: Handle; size: SIGNEDLONG ): OSErr; external name '_PtrToXHand';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_8, __IPHONE_NA, __IPHONE_NA) *)


{
 *  PtrToHand()
 *
 *  Summary:
 *    Copies data referenced by a pointer to a new relocatable block.
 *
 *  Discussion:
 *    If you dereference and lock a handle, the PtrToHand function can
 *    copy its data to a new handle. However, for copying data from one
 *    handle to another, the HandToHand function is more efficient.
 *
 *  Mac OS X threading:
 *    Thread safe since version 10.3
 *
 *  Parameters:
 *
 *    srcPtr:
 *      the address of the first byte to copy.
 *
 *    dstHndl:
 *      a handle for which you have not yet allocated any memory. The
 *      PtrToHand function allocates memory for the handle and copies
 *      the specified number of bytes beginning at srcPtr into it. The
 *      dstHndl parameter is an output parameter that will hold the
 *      result. Its value on entry is ignored. If no error occurs, on
 *      exit it points to an unlocked, non-purgeable Handle of the
 *      requested size.
 *
 *    size:
 *      the number of bytes to copy.
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in InterfaceLib 7.1 and later
 }
function PtrToHand( srcPtr: {const} UnivPtr; var dstHndl: Handle; size: SIGNEDLONG ): OSErr; external name '_PtrToHand';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_8, __IPHONE_NA, __IPHONE_NA) *)


{
 *  HandAndHand()
 *
 *  Summary:
 *    Use the HandAndHand function to concatenate two relocatable
 *    blocks.
 *
 *  Discussion:
 *    The HandAndHand function concatenates the information from the
 *    relocatable block to which aHndl is a handle onto the end of the
 *    relocatable block to which bHndl is a handle. The aHndl variable
 *    remains unchanged.
 *
 *    WARNING
 *
 *    The HandAndHand function dereferences the handle aHndl. You must
 *    call the HLock procedure to lock the block before calling
 *    HandAndHand. Afterward, you can call the HUnlock procedure to
 *    unlock it. Alternatively, you can save the block's original state
 *    by calling the HGetState function, lock the block by calling
 *    HLock, and then restore the original settings by calling
 *    HSetState.
 *
 *  Mac OS X threading:
 *    Thread safe since version 10.3
 *
 *  Parameters:
 *
 *    hand1:
 *      A handle to the first relocatable block, whose contents do not
 *      change but are concatenated to the end of the second
 *      relocatable block.
 *
 *    hand2:
 *      A handle to the second relocatable block, whose size the Memory
 *      Manager expands so that it can concatenate the information from
 *      aHndl to the end of the contents of this block.
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in InterfaceLib 7.1 and later
 }
function HandAndHand( hand1: Handle; hand2: Handle ): OSErr; external name '_HandAndHand';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_8, __IPHONE_NA, __IPHONE_NA) *)


{
 *  PtrAndHand()
 *
 *  Summary:
 *    Concatenates part or all of a memory block to the end of a
 *    relocatable block.
 *
 *  Discussion:
 *    The PtrAndHand function takes the number of bytes specified by
 *    the size parameter, beginning at the location specified by ptr1,
 *    and concatenates them onto the end of the relocatable block to
 *    which hand2 is a handle. The contents of the source block remain
 *    unchanged.
 *
 *  Mac OS X threading:
 *    Thread safe since version 10.3
 *
 *  Parameters:
 *
 *    ptr1:
 *      a pointer to the beginning of the data that the Memory Manager
 *      is to concatenate onto the end of the relocatable block.
 *
 *    hand2:
 *      a handle to the relocatable block, whose size the Memory
 *      Manager expands so that it can concatenate the information from
 *      ptr1 onto the end of this block.
 *
 *    size:
 *      the number of bytes of the block referenced by ptr1 to copy.
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in InterfaceLib 7.1 and later
 }
function PtrAndHand( ptr1: {const} UnivPtr; hand2: Handle; size: SIGNEDLONG ): OSErr; external name '_PtrAndHand';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_8, __IPHONE_NA, __IPHONE_NA) *)



{
 *  IsHeapValid()
 *
 *  Summary:
 *    Check if the heap is valid.
 *
 *  Mac OS X threading:
 *    Thread safe since version 10.4
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   not available
 }
function IsHeapValid: Boolean; external name '_IsHeapValid';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_8, __IPHONE_NA, __IPHONE_NA) *)


{ It is invalid to pass a NULL or an empty Handle to IsHandleValid }
{
 *  IsHandleValid()
 *
 *  Mac OS X threading:
 *    Thread safe since version 10.3
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   not available
 }
function IsHandleValid( h: Handle ): Boolean; external name '_IsHandleValid';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_8, __IPHONE_NA, __IPHONE_NA) *)


{ It is invalid to pass a NULL Pointer to IsPointerValid }
{
 *  IsPointerValid()
 *
 *  Mac OS X threading:
 *    Thread safe since version 10.3
 *
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   not available
 }
function IsPointerValid( p: Ptr ): Boolean; external name '_IsPointerValid';
(* __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_8, __IPHONE_NA, __IPHONE_NA) *)




{$endc} {TARGET_OS_MAC}
{$ifc not defined MACOSALLINCLUDE or not MACOSALLINCLUDE}

end.
{$endc} {not MACOSALLINCLUDE}
