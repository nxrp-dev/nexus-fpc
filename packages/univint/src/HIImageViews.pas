{
     File:       HIToolbox/HIImageViews.h

     Contains:   API and type definitions related to views that display image content.

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
unit HIImageViews;
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
uses MacOsApi.MacTypes,MacOsApi.HIView,MacOsApi.Controls,MacOsApi.IconsCore,MacOsApi.Icons,MacOsApi.QuickdrawTypes,MacOsApi.CGBase,MacOsApi.CGImage,MacOsApi.HIObject;
{$ELSE FPC_DOTTEDUNITS}
uses MacTypes,HIView,Controls,IconsCore,Icons,QuickdrawTypes,CGBase,CGImage,HIObject;
{$ENDIF FPC_DOTTEDUNITS}
{$endc} {not MACOSALLINCLUDE}


{$ifc TARGET_OS_MAC}

{$ALIGN POWER}


{==============================================================================}
{  HIImageView                                                                 }
{ The image view is a new view starting in Mac OS 10.2. It can only be used    }
{ in a compositing window. Like all new HIFoo views, this view is initially    }
{ invisible. You must show the view after creation.                            }
{==============================================================================}
{ The HIObject class ID for the HIImageView class. }
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kHIImageViewClassID CFSTRP('com.apple.HIImageView')}
{$endc}

const
{
   * The control kind of the image view
   }
	kControlKindHIImageView = FourCharCode('imag');



{
 *  HIImageViewAutoTransformOptions
 *
 *  Summary:
 *    These are the available options for applying automatic transforms
 *    on image views and can be accessed with the
 *    HIImageViewSetAutoTransform and HIImageViewGetAutoTransform APIs.
 *
 *  Discussion:
 *    Currently, the auto transforms for disabled or inactive image
 *    views is similar to the transform applied to the image of an
 *    image well or the image in a bevel button when those controls are
 *    disabled or inactive.
 }
type
	HIImageViewAutoTransformOptions = UInt32;
const
{
   * No transform is applied to the image.
   }
	kHIImageViewAutoTransformNone = 0;

  {
   * Transforms are applied to the image view's image when the view is
   * disabled.
   }
	kHIImageViewAutoTransformOnDisable = 1 shl 0;

  {
   * Transforms are applied to the image view's image when the view is
   * deactivated.
   }
	kHIImageViewAutoTransformOnDeactivate = 1 shl 1;



const
{
   * This tag is used with GetControlData and SetControlData to get or
   * set the CGImageRef associated with an HIImageView. This constant
   * is deprecated; use the HIImageViewCopyImage and
   * HIImageViewSetImage APIs to get or set the image for an image view.
   }
	kHIImageViewImageTag = FourCharCode('imag');

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ ICON CONTROL (CDEF 20)                                                            }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  Value parameter should contain the ID of the ICON or cicn you wish to display when  }
{  creating controls of this type. If you don't want the control tracked at all, use   }
{  the 'no track' variant.                                                             }
{ Icon control proc IDs }
const
	kControlIconProc = 320;
	kControlIconNoTrackProc = 321;  { immediately returns kControlIconPart}
	kControlIconSuiteProc = 322;
	kControlIconSuiteNoTrackProc = 323;   { immediately returns kControlIconPart}

const
{ icon ref controls may have either an icon, color icon, icon suite, or icon ref.}
                                        { for data other than icon, you must set the data by passing a}
                                        { ControlButtonContentInfo to SetControlData}
	kControlIconRefProc = 324;
	kControlIconRefNoTrackProc = 325;   { immediately returns kControlIconPart}

{ Control Kind Tag }
const
	kControlKindIcon = FourCharCode('icon');

{ The HIObject class ID for the HIIconView class. }
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kHIIconViewClassID CFSTRP('com.apple.HIIconView')}
{$endc}

const
	kControlIconTransformTag = FourCharCode('trfm'); { IconTransformType}
	kControlIconAlignmentTag = FourCharCode('algn'); { IconAlignmentType}

{ Tags available with appearance 1.1 or later }
const
	kControlIconResourceIDTag = FourCharCode('ires'); { SInt16 resource ID of icon to use}
	kControlIconContentTag = kControlContentTag; { ControlImageContentInfo}

{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  ¥ IMAGE WELL (CDEF 11)                                                              }
{ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ}
{  Image Wells allow you to control the content type (pict/icon/etc.) shown in the     }
{  well.                                                                               }
{  This is made possible by overloading the Min and Value parameters for the control.  }
{  Parameter                   What Goes Here                                          }
{  ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ         ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ      }
{  Min                         content type (see constants for bevel buttons)          }
{  Value                       Resource ID of content type, if resource-based.         }
{  Handle-based Content                                                                }
{  ÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑÑ                                                                }
{  You can create your control and then set the content to an existing handle to an    }
{  icon suite, etc. using the macros below. Please keep in mind that resource-based    }
{  content is owned by the control, handle-based content is owned by you. The CDEF will}
{  not try to dispose of handle-based content. If you are changing the content type of }
{  the button on the fly, you must make sure that if you are replacing a handle-       }
{  based content with a resource-based content to properly dispose of the handle,      }
{  else a memory leak will ensue.                                                      }
{ Image Well proc IDs }
const
	kControlImageWellProc = 176;

{ Control Kind Tag }
const
	kControlKindImageWell = FourCharCode('well');

{ The HIObject class ID for the HIImageWell class. }
{$ifc USE_CFSTR_CONSTANT_MACROS}
{$definec kHIImageWellClassID CFSTRP('com.apple.HIImageWell')}
{$endc}
{ Creation API: Carbon only }

const
	kControlImageWellContentTag = kControlContentTag; { ControlImageContentInfo}
	kControlImageWellTransformTag = FourCharCode('tran'); { IconTransformType}
	kControlImageWellIsDragDestinationTag = FourCharCode('drag'); { Boolean}

{ Helper routines are available only thru the shared library/glue. }

{$endc} {TARGET_OS_MAC}
{$ifc not defined MACOSALLINCLUDE or not MACOSALLINCLUDE}

end.
{$endc} {not MACOSALLINCLUDE}
