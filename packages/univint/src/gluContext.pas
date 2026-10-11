{
	Copyright:	(c) 1999-2008 Apple Inc. All rights reserved.
}
{       Pascal Translation:  Gorazd Krosl, <gorazd_1957@yahoo.ca>, October 2009 }

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
unit gluContext;
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
uses MacOsApi.MacTypes, MacOsApi.Macgl, MacOsApi.Macglu, MacOsApi.CGLTypes;
{$ELSE FPC_DOTTEDUNITS}
uses MacTypes, macgl, macglu, CGLTypes;
{$ENDIF FPC_DOTTEDUNITS}
{$endc} {not MACOSALLINCLUDE}


{$ifc TARGET_OS_MAC}

{$ALIGN POWER}

{
** GLU Context routines
}
function gluBuild1DMipmapsCTX( ctx: CGLContextObj; target: GLenum; internalFormat: GLint; width: GLsizei; format: GLenum; typ: GLenum; data: {const} UnivPtr ): GLint; external name '_gluBuild1DMipmapsCTX';
function gluBuild2DMipmapsCTX( ctx: CGLContextObj; target: GLenum; internalFormat: GLint; width: GLsizei; height: GLsizei; format: GLenum; typ: GLenum; data: {const} UnivPtr ): GLint; external name '_gluBuild2DMipmapsCTX';
function gluBuild3DMipmapsCTX( ctx: CGLContextObj; target: GLenum; internalFormat: GLint; width: GLsizei; height: GLsizei; depth: GLsizei; format: GLenum; typ: GLenum; data: {const} UnivPtr ): GLint; external name '_gluBuild3DMipmapsCTX';
function gluBuild1DMipmapLevelsCTX( ctx: CGLContextObj; target: GLenum; internalFormat: GLint; width: GLsizei; format: GLenum; typ: GLenum; level: GLint; base: GLint; max: GLint; data: {const} UnivPtr ): GLint; external name '_gluBuild1DMipmapLevelsCTX';
function gluBuild2DMipmapLevelsCTX( ctx: CGLContextObj; target: GLenum; internalFormat: GLint; width: GLsizei; height: GLsizei; format: GLenum; typ: GLenum; level: GLint; base: GLint; max: GLint; data: {const} UnivPtr ): GLint; external name '_gluBuild2DMipmapLevelsCTX';
function gluBuild3DMipmapLevelsCTX( ctx: CGLContextObj; target: GLenum; internalFormat: GLint; width: GLsizei; height: GLsizei; depth: GLsizei; format: GLenum; typ: GLenum; level: GLint; base: GLint; max: GLint; data: {const} UnivPtr ): GLint; external name '_gluBuild3DMipmapLevelsCTX';

procedure gluLookAtCTX( ctx: CGLContextObj; eyeX: GLdouble; eyeY: GLdouble; eyeZ: GLdouble; centerX: GLdouble; centerY: GLdouble; centerZ: GLdouble; upX: GLdouble; upY: GLdouble; upZ: GLdouble ); external name '_gluLookAtCTX';
function gluNewNurbsRendererCTX( ctx: CGLContextObj ): PGLUnurbs; external name '_gluNewNurbsRendererCTX';
function gluNewQuadricCTX( ctx: CGLContextObj ): PGLUquadric; external name '_gluNewQuadricCTX';
function gluNewTessCTX( ctx: CGLContextObj ): PGLUtesselator; external name '_gluNewTessCTX';
procedure gluOrtho2DCTX( ctx: CGLContextObj; left: GLdouble; right: GLdouble; bottom: GLdouble; top: GLdouble ); external name '_gluOrtho2DCTX';
procedure gluPerspectiveCTX( ctx: CGLContextObj; fovy: GLdouble; aspect: GLdouble; zNear: GLdouble; zFar: GLdouble ); external name '_gluPerspectiveCTX';
procedure gluPickMatrixCTX( ctx: CGLContextObj; x: GLdouble; y: GLdouble; delX: GLdouble; delY: GLdouble; var viewport: GLint ); external name '_gluPickMatrixCTX';
function gluScaleImageCTX( ctx: CGLContextObj; format: GLenum; wIn: GLsizei; hIn: GLsizei; typeIn: GLenum; dataIn: {const} UnivPtr; wOut: GLsizei; hOut: GLsizei; typeOut: GLenum; dataOut: UnivPtr ): GLint; external name '_gluScaleImageCTX';

{$endc} {TARGET_OS_MAC}
{$ifc not defined MACOSALLINCLUDE or not MACOSALLINCLUDE}

end.
{$endc} {not MACOSALLINCLUDE}
