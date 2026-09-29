unit nxPasKeywords;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  TNXKeywordID = Word;

  TNXKeywordInfo = record
    Text: string;
    ID: TNXKeywordID;
    ActiveByDefault: Boolean;
    FPCModeExpression: string;
  end;

  TNXKeywordPolicy = class
  public
    function IsKeyword(const AInfo: TNXKeywordInfo): Boolean; virtual;
  end;

const
  kwNone = 0;
  kwAbsolute = 1;
  kwAbstract = 2;
  kwAdd = 3;
  kwAddref = 4;
  kwAlias = 5;
  kwAnd = 6;
  kwArray = 7;
  kwAs = 8;
  kwAsm = 9;
  kwAsmname = 10;
  kwAssembler = 11;
  kwAt = 12;
  kwBasefirst = 13;
  kwBaselast = 14;
  kwBasenone = 15;
  kwBasereg = 16;
  kwBasesysv = 17;
  kwBegin = 18;
  kwBitpacked = 19;
  kwBitwiseand = 20;
  kwBitwiseor = 21;
  kwBitwisexor = 22;
  kwBreak = 23;
  kwC = 24;
  kwCase = 25;
  kwCblock = 26;
  kwCdecl = 27;
  kwClass = 28;
  kwCompilerproc = 29;
  kwConst = 30;
  kwConstref = 31;
  kwConstructor = 32;
  kwContains = 33;
  kwContinue = 34;
  kwCopy = 35;
  kwCppclass = 36;
  kwCppdecl = 37;
  kwCvar = 38;
  kwDec = 39;
  kwDefault = 40;
  kwDeprecated = 41;
  kwDestructor = 42;
  kwDispid = 43;
  kwDispinterface = 44;
  kwDiv = 45;
  kwDivide = 46;
  kwDo = 47;
  kwDownto = 48;
  kwDynamic = 49;
  kwElse = 50;
  kwEnd = 51;
  kwEnumerator = 52;
  kwEqual = 53;
  kwExcept = 54;
  kwExit = 55;
  kwExperimental = 56;
  kwExplicit = 57;
  kwExport = 58;
  kwExports = 59;
  kwExternal = 60;
  kwFail = 61;
  kwFar = 62;
  kwFar16 = 63;
  kwFile = 64;
  kwFinal = 65;
  kwFinalization = 66;
  kwFinalize = 67;
  kwFinally = 68;
  kwFirst = 69;
  kwFor = 70;
  kwForward = 71;
  kwFunction = 72;
  kwGeneric = 73;
  kwGoto = 74;
  kwGreaterthan = 75;
  kwGreaterthanorequal = 76;
  kwHardfloat = 77;
  kwHelper = 78;
  kwHuge = 79;
  kwIf = 80;
  kwImplementation = 81;
  kwImplements = 82;
  kwImplicit = 83;
  kwIn = 84;
  kwInc = 85;
  kwIndex = 86;
  kwInherited = 87;
  kwInitialization = 88;
  kwInitialize = 89;
  kwInline = 90;
  kwIntdivide = 91;
  kwInterface = 92;
  kwInternconst = 93;
  kwInternproc = 94;
  kwInterrupt = 95;
  kwIocheck = 96;
  kwIs = 97;
  kwLabel = 98;
  kwLast = 99;
  kwLeftshift = 100;
  kwLegacy = 101;
  kwLessthan = 102;
  kwLessthanorequal = 103;
  kwLibrary = 104;
  kwLocal = 105;
  kwLocation = 106;
  kwLogicaland = 107;
  kwLogicalnot = 108;
  kwLogicalor = 109;
  kwLogicalxor = 110;
  kwMessage = 111;
  kwMod = 112;
  kwModulus = 113;
  kwMsAbiCdecl = 114;
  kwMsAbiDefault = 115;
  kwMultiply = 116;
  kwMwpascal = 117;
  kwName = 118;
  kwNear = 119;
  kwNegative = 120;
  kwNested = 121;
  kwNil = 122;
  kwNodefault = 123;
  kwNoinline = 124;
  kwNoreturn = 125;
  kwNostackframe = 126;
  kwNot = 127;
  kwNotequal = 128;
  kwObjccategory = 129;
  kwObjcclass = 130;
  kwObjcprotocol = 131;
  kwObject = 132;
  kwOf = 133;
  kwOldfpccall = 134;
  kwOn = 135;
  kwOpenstring = 136;
  kwOperator = 137;
  kwOptional = 138;
  kwOr = 139;
  kwOtherwise = 140;
  kwOut = 141;
  kwOverload = 142;
  kwOverride = 143;
  kwPackage = 144;
  kwPacked = 145;
  kwPascal = 146;
  kwPlatform = 147;
  kwPositive = 148;
  kwPrivate = 149;
  kwProcedure = 150;
  kwProgram = 151;
  kwPromising = 152;
  kwProperty = 153;
  kwProtected = 154;
  kwPublic = 155;
  kwPublished = 156;
  kwR12Base = 157;
  kwRaise = 158;
  kwRead = 159;
  kwReadonly = 160;
  kwRecord = 161;
  kwReference = 162;
  kwRegister = 163;
  kwReintroduce = 164;
  kwRepeat = 165;
  kwRequired = 166;
  kwRequires = 167;
  kwResident = 168;
  kwResourcestring = 169;
  kwResult = 170;
  kwReturn = 171;
  kwRightshift = 172;
  kwRtlproc = 173;
  kwSafecall = 174;
  kwSealed = 175;
  kwSection = 176;
  kwSelf = 177;
  kwSet = 178;
  kwShl = 179;
  kwShortstring = 180;
  kwShr = 181;
  kwSoftfloat = 182;
  kwSpecialize = 183;
  kwStatic = 184;
  kwStdcall = 185;
  kwStored = 186;
  kwStrict = 187;
  kwString = 188;
  kwSubtract = 189;
  kwSuspending = 190;
  kwSyscall = 191;
  kwSystem = 192;
  kwSysv = 193;
  kwSysvbase = 194;
  kwSysvAbiCdecl = 195;
  kwSysvAbiDefault = 196;
  kwThen = 197;
  kwThreadvar = 198;
  kwTo = 199;
  kwTry = 200;
  kwType = 201;
  kwUnimplemented = 202;
  kwUnit = 203;
  kwUniv = 204;
  kwUntil = 205;
  kwUses = 206;
  kwVar = 207;
  kwVarargs = 208;
  kwVectorcall = 209;
  kwVirtual = 210;
  kwWasmfuncref = 211;
  kwWeakexternal = 212;
  kwWhile = 213;
  kwWinapi = 214;
  kwWith = 215;
  kwWrite = 216;
  kwWriteonly = 217;
  kwXor = 218;

function FindKeyword(const AText: string; out AInfo: TNXKeywordInfo): Boolean;
function KeywordText(AID: TNXKeywordID): string;

implementation

const
  KeywordTable: array[0..217] of TNXKeywordInfo = (
    (Text:'ABSOLUTE'; ID:1; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'ABSTRACT'; ID:2; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'ADD'; ID:3; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'ADDREF'; ID:4; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'ALIAS'; ID:5; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'AND'; ID:6; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes'),
    (Text:'ARRAY'; ID:7; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes'),
    (Text:'AS'; ID:8; ActiveByDefault:True; FPCModeExpression:'[m_class]'),
    (Text:'ASM'; ID:9; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes-[m_iso]'),
    (Text:'ASMNAME'; ID:10; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'ASSEMBLER'; ID:11; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'AT'; ID:12; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'BASEFIRST'; ID:13; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'BASELAST'; ID:14; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'BASENONE'; ID:15; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'BASEREG'; ID:16; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'BASESYSV'; ID:17; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'BEGIN'; ID:18; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes'),
    (Text:'BITPACKED'; ID:19; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes-[m_iso,m_extpas]'),
    (Text:'BITWISEAND'; ID:20; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'BITWISEOR'; ID:21; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'BITWISEXOR'; ID:22; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'BREAK'; ID:23; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'C'; ID:24; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'CASE'; ID:25; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes'),
    (Text:'CBLOCK'; ID:26; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'CDECL'; ID:27; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'CLASS'; ID:28; ActiveByDefault:True; FPCModeExpression:'[m_class]'),
    (Text:'COMPILERPROC'; ID:29; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'CONST'; ID:30; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes'),
    (Text:'CONSTREF'; ID:31; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'CONSTRUCTOR'; ID:32; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes-[m_iso,m_extpas]'),
    (Text:'CONTAINS'; ID:33; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'CONTINUE'; ID:34; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'COPY'; ID:35; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'CPPCLASS'; ID:36; ActiveByDefault:True; FPCModeExpression:'[m_fpc]'),
    (Text:'CPPDECL'; ID:37; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'CVAR'; ID:38; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'DEC'; ID:39; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'DEFAULT'; ID:40; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'DEPRECATED'; ID:41; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'DESTRUCTOR'; ID:42; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes-[m_iso,m_extpas]'),
    (Text:'DISPID'; ID:43; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'DISPINTERFACE'; ID:44; ActiveByDefault:True; FPCModeExpression:'[m_class]'),
    (Text:'DIV'; ID:45; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes'),
    (Text:'DIVIDE'; ID:46; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'DO'; ID:47; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes'),
    (Text:'DOWNTO'; ID:48; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes'),
    (Text:'DYNAMIC'; ID:49; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'ELSE'; ID:50; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes'),
    (Text:'END'; ID:51; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes'),
    (Text:'ENUMERATOR'; ID:52; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'EQUAL'; ID:53; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'EXCEPT'; ID:54; ActiveByDefault:True; FPCModeExpression:'[m_except]'),
    (Text:'EXIT'; ID:55; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'EXPERIMENTAL'; ID:56; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'EXPLICIT'; ID:57; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'EXPORT'; ID:58; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'EXPORTS'; ID:59; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes-[m_iso,m_extpas]'),
    (Text:'EXTERNAL'; ID:60; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'FAIL'; ID:61; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'FAR'; ID:62; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'FAR16'; ID:63; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'FILE'; ID:64; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes'),
    (Text:'FINAL'; ID:65; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'FINALIZATION'; ID:66; ActiveByDefault:True; FPCModeExpression:'[m_initfinal]'),
    (Text:'FINALIZE'; ID:67; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'FINALLY'; ID:68; ActiveByDefault:True; FPCModeExpression:'[m_except]'),
    (Text:'FIRST'; ID:69; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'FOR'; ID:70; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes'),
    (Text:'FORWARD'; ID:71; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'FUNCTION'; ID:72; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes'),
    (Text:'GENERIC'; ID:73; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'GOTO'; ID:74; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes'),
    (Text:'GREATERTHAN'; ID:75; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'GREATERTHANOREQUAL'; ID:76; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'HARDFLOAT'; ID:77; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'HELPER'; ID:78; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'HUGE'; ID:79; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'IF'; ID:80; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes'),
    (Text:'IMPLEMENTATION'; ID:81; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes-[m_iso,m_extpas]'),
    (Text:'IMPLEMENTS'; ID:82; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'IMPLICIT'; ID:83; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'IN'; ID:84; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes'),
    (Text:'INC'; ID:85; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'INDEX'; ID:86; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'INHERITED'; ID:87; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes-[m_iso,m_extpas]'),
    (Text:'INITIALIZATION'; ID:88; ActiveByDefault:True; FPCModeExpression:'[m_initfinal]'),
    (Text:'INITIALIZE'; ID:89; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'INLINE'; ID:90; ActiveByDefault:True; FPCModeExpression:'[m_tp7]'),
    (Text:'INTDIVIDE'; ID:91; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'INTERFACE'; ID:92; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes-[m_iso,m_extpas]'),
    (Text:'INTERNCONST'; ID:93; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'INTERNPROC'; ID:94; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'INTERRUPT'; ID:95; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'IOCHECK'; ID:96; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'IS'; ID:97; ActiveByDefault:True; FPCModeExpression:'[m_class]'),
    (Text:'LABEL'; ID:98; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes'),
    (Text:'LAST'; ID:99; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'LEFTSHIFT'; ID:100; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'LEGACY'; ID:101; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'LESSTHAN'; ID:102; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'LESSTHANOREQUAL'; ID:103; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'LIBRARY'; ID:104; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes-[m_iso,m_extpas]'),
    (Text:'LOCAL'; ID:105; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'LOCATION'; ID:106; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'LOGICALAND'; ID:107; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'LOGICALNOT'; ID:108; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'LOGICALOR'; ID:109; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'LOGICALXOR'; ID:110; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'MESSAGE'; ID:111; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'MOD'; ID:112; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes'),
    (Text:'MODULUS'; ID:113; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'MS_ABI_CDECL'; ID:114; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'MS_ABI_DEFAULT'; ID:115; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'MULTIPLY'; ID:116; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'MWPASCAL'; ID:117; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'NAME'; ID:118; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'NEAR'; ID:119; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'NEGATIVE'; ID:120; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'NESTED'; ID:121; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'NIL'; ID:122; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes'),
    (Text:'NODEFAULT'; ID:123; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'NOINLINE'; ID:124; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'NORETURN'; ID:125; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'NOSTACKFRAME'; ID:126; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'NOT'; ID:127; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes'),
    (Text:'NOTEQUAL'; ID:128; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'OBJCCATEGORY'; ID:129; ActiveByDefault:True; FPCModeExpression:'[m_objectivec1]'),
    (Text:'OBJCCLASS'; ID:130; ActiveByDefault:True; FPCModeExpression:'[m_objectivec1]'),
    (Text:'OBJCPROTOCOL'; ID:131; ActiveByDefault:True; FPCModeExpression:'[m_objectivec1]'),
    (Text:'OBJECT'; ID:132; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes-[m_iso,m_extpas]'),
    (Text:'OF'; ID:133; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes'),
    (Text:'OLDFPCCALL'; ID:134; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'ON'; ID:135; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'OPENSTRING'; ID:136; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'OPERATOR'; ID:137; ActiveByDefault:True; FPCModeExpression:'[m_fpc]'),
    (Text:'OPTIONAL'; ID:138; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'OR'; ID:139; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes'),
    (Text:'OTHERWISE'; ID:140; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes'),
    (Text:'OUT'; ID:141; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'OVERLOAD'; ID:142; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'OVERRIDE'; ID:143; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'PACKAGE'; ID:144; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'PACKED'; ID:145; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes'),
    (Text:'PASCAL'; ID:146; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'PLATFORM'; ID:147; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'POSITIVE'; ID:148; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'PRIVATE'; ID:149; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'PROCEDURE'; ID:150; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes'),
    (Text:'PROGRAM'; ID:151; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes'),
    (Text:'PROMISING'; ID:152; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'PROPERTY'; ID:153; ActiveByDefault:True; FPCModeExpression:'[m_property]'),
    (Text:'PROTECTED'; ID:154; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'PUBLIC'; ID:155; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'PUBLISHED'; ID:156; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'R12BASE'; ID:157; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'RAISE'; ID:158; ActiveByDefault:True; FPCModeExpression:'[m_except]'),
    (Text:'READ'; ID:159; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'READONLY'; ID:160; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'RECORD'; ID:161; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes'),
    (Text:'REFERENCE'; ID:162; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'REGISTER'; ID:163; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'REINTRODUCE'; ID:164; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'REPEAT'; ID:165; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes'),
    (Text:'REQUIRED'; ID:166; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'REQUIRES'; ID:167; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'RESIDENT'; ID:168; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'RESOURCESTRING'; ID:169; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes-[m_iso,m_extpas]'),
    (Text:'RESULT'; ID:170; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'RETURN'; ID:171; ActiveByDefault:True; FPCModeExpression:'[m_mac]'),
    (Text:'RIGHTSHIFT'; ID:172; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'RTLPROC'; ID:173; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'SAFECALL'; ID:174; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'SEALED'; ID:175; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'SECTION'; ID:176; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'SELF'; ID:177; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'SET'; ID:178; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes'),
    (Text:'SHL'; ID:179; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes-[m_iso,m_extpas]'),
    (Text:'SHORTSTRING'; ID:180; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'SHR'; ID:181; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes-[m_iso,m_extpas]'),
    (Text:'SOFTFLOAT'; ID:182; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'SPECIALIZE'; ID:183; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'STATIC'; ID:184; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'STDCALL'; ID:185; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'STORED'; ID:186; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'STRICT'; ID:187; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'STRING'; ID:188; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes-[m_iso,m_extpas]'),
    (Text:'SUBTRACT'; ID:189; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'SUSPENDING'; ID:190; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'SYSCALL'; ID:191; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'SYSTEM'; ID:192; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'SYSV'; ID:193; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'SYSVBASE'; ID:194; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'SYSV_ABI_CDECL'; ID:195; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'SYSV_ABI_DEFAULT'; ID:196; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'THEN'; ID:197; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes'),
    (Text:'THREADVAR'; ID:198; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes-[m_iso,m_extpas]'),
    (Text:'TO'; ID:199; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes'),
    (Text:'TRY'; ID:200; ActiveByDefault:True; FPCModeExpression:'[m_except]'),
    (Text:'TYPE'; ID:201; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes'),
    (Text:'UNIMPLEMENTED'; ID:202; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'UNIT'; ID:203; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes-[m_iso,m_extpas]'),
    (Text:'UNIV'; ID:204; ActiveByDefault:True; FPCModeExpression:'[m_mac]'),
    (Text:'UNTIL'; ID:205; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes'),
    (Text:'USES'; ID:206; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes-[m_iso,m_extpas]'),
    (Text:'VAR'; ID:207; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes'),
    (Text:'VARARGS'; ID:208; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'VECTORCALL'; ID:209; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'VIRTUAL'; ID:210; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'WASMFUNCREF'; ID:211; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'WEAKEXTERNAL'; ID:212; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'WHILE'; ID:213; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes'),
    (Text:'WINAPI'; ID:214; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'WITH'; ID:215; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes'),
    (Text:'WRITE'; ID:216; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'WRITEONLY'; ID:217; ActiveByDefault:False; FPCModeExpression:'[m_none]'),
    (Text:'XOR'; ID:218; ActiveByDefault:True; FPCModeExpression:'alllanguagemodes')
  );

function TNXKeywordPolicy.IsKeyword(const AInfo: TNXKeywordInfo): Boolean;
begin
  { The FPC table contains contextual/mode-sensitive words whose keyword
    expression is [m_none].  Those stay identifiers by default while retaining
    their keyword-candidate ID in TNXToken.Variant.  NexusFPC can override this
    policy as language-mode work is integrated. }
  Result := AInfo.ActiveByDefault;
end;

function FindKeyword(const AText: string; out AInfo: TNXKeywordInfo): Boolean;
var
  Key: string;
  L, H, M, C: Integer;
begin
  Key := UpperCase(AText);
  L := Low(KeywordTable);
  H := High(KeywordTable);

  while L <= H do
  begin
    M := (L + H) shr 1;
    C := CompareStr(Key, KeywordTable[M].Text);

    if C = 0 then
    begin
      AInfo := KeywordTable[M];
      Exit(True);
    end;

    if C < 0 then
      H := M - 1
    else
      L := M + 1;
  end;

  FillChar(AInfo, SizeOf(AInfo), 0);
  Result := False;
end;

function KeywordText(AID: TNXKeywordID): string;
var
  I: Integer;
begin
  if AID = 0 then
    Exit('');

  for I := Low(KeywordTable) to High(KeywordTable) do
    if KeywordTable[I].ID = AID then
      Exit(KeywordTable[I].Text);

  Result := '';
end;

end.
