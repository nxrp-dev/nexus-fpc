{
     File:       HIToolbox/HIAccessibility.h

     Contains:   Accessibility Carbon events and API for HIToolbox

     Version:    HIToolbox-624~3

     Copyright:  © 2005-2008 by Apple Computer, Inc., all rights reserved.

     Bugs?:      For bug reports, consult the following page on
                 the World Wide Web:

                     http://bugs.freepascal.org

}
{       Pascal Translation:  Jonas Maebe, <jonas@freepascal.org>, October 2009 }
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
unit HIAccessibility;
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
uses MacOsApi.MacTypes,MacOsApi.CFBase,MacOsApi.CarbonEvents,MacOsApi.Events,MacOsApi.Menus,MacOsApi.Controls,MacOsApi.MacWindows,MacOsApi.HIObject,MacOsApi.AXUIElement;
{$ELSE FPC_DOTTEDUNITS}
uses MacTypes,CFBase,CarbonEvents,Events,Menus,Controls,MacWindows,HIObject,AXUIElement;
{$ENDIF FPC_DOTTEDUNITS}
{$endc} {not MACOSALLINCLUDE}


{$ifc TARGET_OS_MAC}

{$ALIGN POWER}


{--------------------------------------------------------------------------------------}
{  Accessibility Events                                                                }
{--------------------------------------------------------------------------------------}
{
    kEventClassAccessibility quick reference:

    kEventAccessibleGetChildAtPoint                     =   1,
    kEventAccessibleGetFocusedChild                     =   2,

    kEventAccessibleGetAllAttributeNames                =   21,
    kEventAccessibleGetAllParameterizedAttributeNames   =   25,
    kEventAccessibleGetNamedAttribute                   =   22,
    kEventAccessibleSetNamedAttribute                   =   23,
    kEventAccessibleIsNamedAttributeSettable            =   24,

    kEventAccessibleGetAllActionNames                   =   41,
    kEventAccessiblePerformNamedAction                  =   42,
    kEventAccessibleGetNamedActionDescription           =   44
}
{
 *  kEventClassAccessibility / kEventAccessibleGetChildAtPoint
 *
 *  Summary:
 *    Finds the child of an accessible object at a given point.
 *
 *  Discussion:
 *    The kEventParamMouseLocation parameter will contain a global
 *    point. Your handler for this event should find the child of
 *    yourself which is underneath that point and return it in the
 *    kEventParamAccessibleChild parameter.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Parameters:
 *
 *    --> kEventParamAccessibleObject (in, typeCFTypeRef)
 *          The accessible object, in the form of an AXUIElementRef.
 *
 *    --> kEventParamMouseLocation (in, typeHIPoint)
 *          The location in global coordinates.
 *
 *    <-- kEventParamAccessibleChild (out, typeCFTypeRef)
 *          On exit, contains the child of the accessible object at the
 *          specified point, in the form of an AXUIElementRef. If there
 *          is no child at the given point, you should still return
 *          noErr, but leave the parameter empty (do not call
 *          SetEventParameter). Only return immediate children; do not
 *          return grandchildren of yourself.
 *
 *  Availability:
 *    Mac OS X:         in version 10.2 and later in Carbon.framework
 *    CarbonLib:        not available
 }
const
	kEventAccessibleGetChildAtPoint = 1;

{
 *  kEventClassAccessibility / kEventAccessibleGetFocusedChild
 *
 *  Summary:
 *    Finds the focused child of an accessible object.
 *
 *  Discussion:
 *    Your handler for this event should find the child of itself which
 *    is part of the focus chain and return it in the
 *    kEventParamAccessibleChild parameter.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Parameters:
 *
 *    --> kEventParamAccessibleObject (in, typeCFTypeRef)
 *          The accessible object, in the form of an AXUIElementRef.
 *
 *    <-- kEventParamAccessibleChild (out, typeCFTypeRef)
 *          On exit, contains the focused child of the accessible
 *          object, in the form of an AXUIElementRef. If there is no
 *          child in the focus chain, you should still return noErr,
 *          but leave the parameter empty (do not call
 *          SetEventParameter). Only return immediate children; do not
 *          return grandchildren of yourself.
 *
 *  Availability:
 *    Mac OS X:         in version 10.2 and later in Carbon.framework
 *    CarbonLib:        not available
 }
const
	kEventAccessibleGetFocusedChild = 2;

{
 *  kEventClassAccessibility / kEventAccessibleGetAllAttributeNames
 *
 *  Summary:
 *    Returns the attributes supported by an accessible object. You
 *    must only return the names of your regular (non-parameterized)
 *    attributes via this event. If you support parameterized
 *    attributes, you must return them via the new
 *    kEventAccessibleGetAllParameterizedAttributeNames event.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Parameters:
 *
 *    --> kEventParamAccessibleObject (in, typeCFTypeRef)
 *          The accessible object, in the form of an AXUIElementRef.
 *
 *    <-> kEventParamAccessibleAttributeNames (in/out, typeCFMutableArrayRef)
 *          Add each of the regular (non-parameterized) attribute names
 *          supported by the accessible object to this array, as
 *          CFStringRefs.
 *
 *  Availability:
 *    Mac OS X:         in version 10.2 and later in Carbon.framework
 *    CarbonLib:        not available
 }
const
	kEventAccessibleGetAllAttributeNames = 21;

{
 *  kEventClassAccessibility / kEventAccessibleGetAllParameterizedAttributeNames
 *
 *  Summary:
 *    Returns the parameterized attributes supported by an accessible
 *    object. You must not return the names of your regular
 *    (non-parameterized) attributes via this event. If you support
 *    regular attributes, you must return them via the original
 *    kEventAccessibleGetAllAttributeNames event. Parameterized
 *    attributes are introduced in Mac OS X 10.3.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Parameters:
 *
 *    --> kEventParamAccessibleObject (in, typeCFTypeRef)
 *          The accessible object, in the form of an AXUIElementRef.
 *
 *    <-> kEventParamAccessibleAttributeNames (in/out, typeCFMutableArrayRef)
 *          Add each of the parameterized attribute names supported by
 *          the accessible object to this array, as CFStringRefs.
 *
 *  Availability:
 *    Mac OS X:         in version 10.3 and later in Carbon.framework
 *    CarbonLib:        not available
 }
const
	kEventAccessibleGetAllParameterizedAttributeNames = 25;

{
 *  kEventClassAccessibility / kEventAccessibleGetNamedAttribute
 *
 *  Summary:
 *    Returns the value of an attribute of an accessible object.
 *
 *  Discussion:
 *    The kEventParamAccessibleAttributeName parameter will contain an
 *    attribute name in the form of a CFStringRef. If you support the
 *    named attribute, return the attributeÕs value in the
 *    kEventParamAccessibleAttributeValue parameter.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Parameters:
 *
 *    --> kEventParamAccessibleObject (in, typeCFTypeRef)
 *          The accessible object, in the form of an AXUIElementRef.
 *
 *    --> kEventParamAccessibleAttributeName (in, typeCFStringRef)
 *          The name of the requested attribute.
 *
 *    --> kEventParamAccessibleAttributeParameter (in, typeCFTypeRef)
 *          This parameter is optional and will only exist if your
 *          accessible object is being asked for the value of a
 *          parameterized attribute. When present, this event parameter
 *          will contain a CFTypeRef describing the parameters of the
 *          request. Parameterized attributes are introduced in Mac OS
 *          X 10.3.
 *
 *    <-- kEventParamAccessibleAttributeValue (out, typeCFTypeRef)
 *          On exit, contains the attribute's value. The type of this
 *          parameter varies according to the attribute; it might
 *          typically be typeCFStringRef (for a textual attribute),
 *          typeBoolean (for a boolean attribute), or typeSInt32 (for
 *          an integer-valued attribute).
 *
 *  Availability:
 *    Mac OS X:         in version 10.2 and later in Carbon.framework
 *    CarbonLib:        not available
 }
const
	kEventAccessibleGetNamedAttribute = 22;

{
 *  kEventClassAccessibility / kEventAccessibleSetNamedAttribute
 *
 *  Summary:
 *    Sets the value of an attribute of an accessible object.
 *
 *  Discussion:
 *    The kEventParamAccessibleAttributeName parameter will contain an
 *    attribute name in the form of a CFStringRef. The
 *    kEventParamAccessibleAttributeValue parameter will contain data
 *    in an arbitrary format. If you support the named attribute, set
 *    the named attributeÕs value to the data provided in the event.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Parameters:
 *
 *    --> kEventParamAccessibleObject (in, typeCFTypeRef)
 *          The accessible object, in the form of an AXUIElementRef.
 *
 *    --> kEventParamAccessibleAttributeName (in, typeCFStringRef)
 *          The name of the requested attribute.
 *
 *    --> kEventParamAccessibleAttributeValue (in, typeCFTypeRef)
 *          The new value of the attribute. The type of this parameter
 *          varies according to the attribute; it might typically be
 *          typeCFStringRef (for a textual attribute), typeBoolean (for
 *          a boolean attribute), or typeSInt32 (for an integer-valued
 *          attribute).
 *
 *  Availability:
 *    Mac OS X:         in version 10.2 and later in Carbon.framework
 *    CarbonLib:        not available
 }
const
	kEventAccessibleSetNamedAttribute = 23;

{
 *  kEventClassAccessibility / kEventAccessibleIsNamedAttributeSettable
 *
 *  Summary:
 *    Determines whether an attribute of an accessible object can be
 *    modified.
 *
 *  Discussion:
 *    The kEventParamAccessibleAttributeName parameter will contain an
 *    attribute name in the form of a CFStringRef. If you support the
 *    named attribute, set the kEventParamAccessibleAttributeSettable
 *    parameter to a Boolean indicating whether the named attribute can
 *    have its value changed via the kEventAccessibleSetNamedAttribute
 *    event.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Parameters:
 *
 *    --> kEventParamAccessibleObject (in, typeCFTypeRef)
 *          The accessible object, in the form of an AXUIElementRef.
 *
 *    --> kEventParamAccessibleAttributeName (in, typeCFStringRef)
 *          The name of the requested attribute.
 *
 *    <-- kEventParamAccessibleAttributeSettable (out, typeBoolean)
 *          On exit, indicates whether the attribute may be modified.
 *
 *  Availability:
 *    Mac OS X:         in version 10.2 and later in Carbon.framework
 *    CarbonLib:        not available
 }
const
	kEventAccessibleIsNamedAttributeSettable = 24;

{
 *  kEventClassAccessibility / kEventAccessibleGetAllActionNames
 *
 *  Summary:
 *    Returns the actions supported by an accessible object.
 *
 *  Discussion:
 *    The kEventParamAccessibleActionNames parameter will contain a
 *    CFMutableArrayRef. Add each of the action names you support to
 *    this array in the form of a CFStringRef.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Parameters:
 *
 *    --> kEventParamAccessibleObject (in, typeCFTypeRef)
 *          The accessible object, in the form of an AXUIElementRef.
 *
 *    <-> kEventParamAccessibleActionNames (in/out, typeCFMutableArrayRef)
 *          Add each of the actions supported by the accessible object
 *          to this array, as CFStringRefs.
 *
 *  Availability:
 *    Mac OS X:         in version 10.2 and later in Carbon.framework
 *    CarbonLib:        not available
 }
const
	kEventAccessibleGetAllActionNames = 41;

{
 *  kEventClassAccessibility / kEventAccessiblePerformNamedAction
 *
 *  Summary:
 *    Requests that a specific action be performed by an accessible
 *    object.
 *
 *  Discussion:
 *    The kEventParamAccessibleActionName parameter will contain an
 *    attribute name in the form of a CFStringRef. If you support the
 *    named action, perform the action. There are times, however, when
 *    performing an action causes an accessible object to call a
 *    routine which may not return immediately, such as StandardAlert
 *    or PopUpMenuSelect. You should only call such routines when you
 *    receive an action request that was queued; if you call such a
 *    routine when processing an event that was directly dispatched,
 *    you will probably cause the assistive app to receive a timeout
 *    error. On Mac OS X 10.3 and later, the
 *    kEventParamAccessibilityEventQueued parameter will indicate
 *    whether the event was queued. If so, process the request
 *    normally. If not, you can request that the event be posted to the
 *    queue and sent to you later by returning
 *    eventDeferAccessibilityEventErr from your handler. On Mac OS X
 *    10.2, the parameter will not exist, the event will always be
 *    directly dispatched, and there is no way to request that it be
 *    posted to the queue; in this case, you should perform the action
 *    even if it will cause the assistive app to receive a timeout
 *    error.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Parameters:
 *
 *    --> kEventParamAccessibleObject (in, typeCFTypeRef)
 *          The accessible object, in the form of an AXUIElementRef.
 *
 *    --> kEventParamAccessibleActionName (in, typeCFStringRef)
 *          The name of the requested action.
 *
 *    --> kEventParamAccessibilityEventQueued (in, typeBoolean)
 *          An indication of whether this event was delivered to you
 *          via the main event queue. This parameter only exists on Mac
 *          OS X 10.3 and later. See the discussion for more details.
 *
 *  Availability:
 *    Mac OS X:         in version 10.2 and later in Carbon.framework
 *    CarbonLib:        not available
 }
const
	kEventAccessiblePerformNamedAction = 42;

{
 *  kEventClassAccessibility / kEventAccessibleGetNamedActionDescription
 *
 *  Summary:
 *    Returns a human-language description of an action supported by an
 *    accessible object.
 *
 *  Discussion:
 *    The kEventParamAccessibleActionName parameter will contain an
 *    attribute name in the form of a CFStringRef. The
 *    kEventParamAccessibleActionDescription parameter will contain a
 *    CFMutableStringRef. If you support the named action, alter the
 *    mutable string to contain a textual description of the actionÕs
 *    significance.
 *
 *  Mac OS X threading:
 *    Not thread safe
 *
 *  Parameters:
 *
 *    --> kEventParamAccessibleObject (in, typeCFTypeRef)
 *          The accessible object, in the form of an AXUIElementRef.
 *
 *    --> kEventParamAccessibleActionName (in, typeCFStringRef)
 *          The name of the requested action.
 *
 *    <-> kEventParamAccessibleActionDescription (in/out, typeCFMutableStringRef)
 *          If you support the action, extract this parameter from the
 *          event and set the contents of the mutable string to contain
 *          a description of the action. Do not set this event
 *          parameter to a CFStringRef of your own creation; you must
 *          modify the preexisting mutable string stored in the event
 *          parameter.
 *
 *  Availability:
 *    Mac OS X:         in version 10.2 and later in Carbon.framework
 *    CarbonLib:        not available
 }
const
	kEventAccessibleGetNamedActionDescription = 44;


{$endc} {TARGET_OS_MAC}
{$ifc not defined MACOSALLINCLUDE or not MACOSALLINCLUDE}

end.
{$endc} {not MACOSALLINCLUDE}
