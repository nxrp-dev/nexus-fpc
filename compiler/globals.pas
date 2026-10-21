{
    Copyright (c) 1998-2002 by Florian Klaempfl

    This unit implements some support functions and global variables

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

 ****************************************************************************
}
unit globals;

{$i fpcdefs.inc}

interface

    uses
TPCompilerReal,
    {$ifdef windows}
      Windows,
{$endif}
{$ifdef hasunix}
      BaseUnix,Unix,
{$endif}

      SysUtils,
      { comphook pulls in sysutils anyways }
      CUtils,CClasses,CFileUtl,
      CPUInfo,
      GlobType,Version,VersionCmp,Systems;

    const
       DelphiModeSwitches =
         [m_delphi,m_class,m_objpas,m_result,m_string_pchar,
          m_pointer_2_procedure,m_autoderef,m_tp_procvar,m_initfinal,m_default_ansistring,
          m_out,m_default_para,m_duplicate_names,m_hintdirective,
          m_property,m_default_inline,m_except,m_advanced_records,
          m_array_operators,m_prefixed_attributes,m_underscoreisseparator,
          m_function_references,m_anonymous_functions,m_multiline_strings,
          m_statement_expressions];
       DelphiUnicodeModeSwitches = DelphiModeSwitches + [m_systemcodepage,m_default_unicodestring];
       FPCModeSwitches =
         [m_fpc,m_string_pchar,m_nested_comment,m_repeat_forward,
          m_cvar_support,m_initfinal,m_hintdirective,
          m_property,m_default_inline];
       ObjFPCModeSwitches =
         [m_objfpc,m_fpc,m_class,m_objpas,m_result,m_string_pchar,m_nested_comment,
          m_repeat_forward,m_cvar_support,m_initfinal,m_out,m_default_para,m_hintdirective,
          m_property,m_default_inline,m_except,m_multiline_strings];
       MacModeSwitches =
         [m_mac,m_cvar_support,m_mac_procvar,m_nested_procvars,m_non_local_goto,m_isolike_unary_minus,m_default_inline];
       ISOModeSwitches =
         [m_iso,m_tp_procvar,m_duplicate_names,m_nested_procvars,m_non_local_goto,m_isolike_unary_minus,m_isolike_io,
          m_isolike_program_para,
          m_isolike_mod];

       { maximum nesting of routines }
       MaxNesting = 32;

       { Filenames and extensions }
       SourceExt  = '.pas';
       PExt       = '.p';

       TreeLogFileName = 'tree.log';

       MathQNaN : TCompDoubleRec = (Bytes : (0,0,0,0,0,0,252,255));
       MathInf : TCompDoubleRec = (Bytes : (0,0,0,0,0,0,240,127));
       MathNegInf : TCompDoubleRec = (Bytes : (0,0,0,0,0,0,240,255));
       MathPosZero : TCompDoubleRec = (Bytes : (0,0,0,0,0,0,0,0));
       MathNegZero : TCompDoubleRec = (Bytes : (0,0,0,0,0,0,0,128));
       MathPi : TCompDoubleRec = (Bytes : (24,45,68,84,251,33,9,64));
       MathPiExtended : TCompExtendedRec = (Bytes : (53,194,104,33,162,218,15,201,0,64));

       CP_UTF8 = 65001;
       CP_UTF16LE = 1200;
       CP_UTF16BE = 1201;
       CP_NONE  = 65535;

    var
       { by default no local variable trashing }
       LocalVarTrashing: LongInt = -1;

    const
       NrOfTrashValues = 4;
       TrashIntValues: array[0..NrOfTrashValues-1] of Int64 = ($5555555555555555,$AAAAAAAAAAAAAAAA,$EFEFEFEFEFEFEFEF,0);

{ Verbosity constants }
Const
  { Levels }
  VNone         = $0;
  VFatal        = $1;
  VError        = $2;
  VNormal       = $4; { doesn't show a text like Error: }
  VWarning      = $8;
  VNote         = $10;
  VHint         = $20;
  VLineInfoMask = $fff;
  { From here by default no line info }
  VInfo         = $1000;
  VStatus       = $2000;
  VUsed         = $4000;
  VTried        = $8000;
  VConditional  = $10000;
  VDebug        = $20000;
  VExecutable   = $40000;
  VTimeStamps   = $80000;
  VLevelMask    = $ffffff;
  VAll          = VLevelMask;
  VDefault      = VFatal + VError + VNormal;
  { Flags }
  VLineInfo     = $10000000;
  VParallel     = $20000000;


    type
       { this is written to ppus during token recording for generics,
         it used to required to be packed,
         but this requirement is now obsolete,
         as the fields are written one by one. PM 2012-06-13 }
       TSettings = record
         Alignment       : TAlignmentInfo;
         GlobalSwitches  : TGlobalSwitches;
         TargetSwitches  : TTargetSwitches;
         ModuleSwitches  : TModuleSwitches;
         LocalSwitches   : TLocalSwitches;
         ModeSwitches    : TModeSwitches;
         OptimizerSwitches : TOptimizerSwitches;
         { generate information necessary to perform these wpo's during a subsequent compilation }
         GenWPOptimizerSwitches: TWPOptimizerSwitches;
         { perform these wpo's using information generated during a previous compilation }
         DoWPOptimizerSwitches: TWPOptimizerSwitches;
         DebugSwitches   : TDebugSwitches;
         { 0: old behaviour for sets <=256 elements
           >0: round to this size }
         SetAlloc,
         PackEnum        : ShortInt;

         PackRecords     : ShortInt;
         MaxFPURegisters : ShortInt;

         Verbosity       : LongInt;

         CPUType,
         OptimizeCPUType,
         AsmCPUType      : TCPUType;
         FPUType         : TFPUType;
         AsmMode         : TAsmMode;
         InterfaceType   : TInterfaceTypes;
         DefProcCall     : TProcCallOption;
         SourceCodePage  : TStringEncoding;

         MinFPConstPrec  : TFloatType;

         DisableDirCache : Boolean;

         TLSModel : TTLSModel;

         { WARNING: pmessage cannot be written as such in record token
              pmessage is the top of a stack of message/verbosity changes
              RestoreLocalVerbosity applies the current stack. }
         PMessage : PMessageStateRecord;

         LineEndingType : TLineEndingType;

         WhitespaceTrimCount : Word;

         WhitespaceTrimAuto : Boolean;

{$if defined(generic_cpu)}
         case Byte of
{$endif}
{$if defined(generic_cpu)}
   {$ifdef generic_cpu} 1:({$endif}
           X86MemoryModel  : TX86MemoryModel;
   {$ifdef generic_cpu}   );{$endif}
{$endif defined(generic_cpu)}

{$if defined(generic_cpu)}
   {$ifdef generic_cpu} 2:({$endif}
         InstructionSet : TInstructionSet;
   {$ifdef generic_cpu}   );{$endif}
{$endif}

       end;

    const
      LinkMapWeightDefault = 1000;
{$ifdef CPU_BC_HAS_SIZE_LIMIT}
{$endif CPU_BC_HAS_SIZE_LIMIT}

    type
      TLinkRec = record
        Key   : AnsiString;
        Value : AnsiString; // key expands to valuelist "value"
        Weight: LongInt;
      end;

      TLinkStrMap  = class
      private
        ItemCnt : LongInt;
        FMap : Array Of TLinkRec;
        function  Lookup(const Key:AnsiString):LongInt;
        function GetLinkRec(I:LongInt):TLinkRec;
      public
        procedure Add(const Key:AnsiString;const Value:AnsiString='';Weight:LongInt=LinkMapWeightDefault);
        procedure AddSeries(const Keys:AnsiString;Weight:LongInt=LinkMapWeightDefault);
        function  AddDep(const KeyValue:String):Boolean;
        function  AddWeight(const KeyValue:String):Boolean;
        procedure SetValue(const Key:AnsiString;Weight:Integer);
        procedure SortOnWeight;
        function Find(const Key:AnsiString):AnsiString;
        procedure Expand(Src:TCmdStrList;Dest: TLinkStrMap);
        procedure UpdateWeights(WeightMap:TLinkStrMap);
        constructor Create;
        property Count : LongInt read ItemCnt;
        property Items[I:LongInt]:TLinkRec read GetLinkRec; default;
      end;

      TPendingStateFlag = (
        psf_alignment_changed,
        psf_verbosity_full_switched,
        psf_local_switches_changed,
        psf_packenum_changed,
        psf_packrecords_changed,
        psf_setalloc_changed,
        psf_asmmode_changed,
        psf_optimizerswitches_changed
      );
      TPendingStateFlags = set of TPendingStateFlag;

      TPendingState = record
        NextVerbosityStr : ShortString;
        NextLocalSwitches : TLocalSwitches;
        NextVerbosityFullSwitch: LongInt;
        NextCallingStr : ShortString;
        NextMessageRecord : PMessageStateRecord;
        NextAlignment : TAlignmentInfo;
        NextPackEnum : ShortInt;
        NextPackRecords : ShortInt;
        NextSetAlloc : ShortInt;
        NextAsmMode : TAsmMode;
        NextOptimizerSwitches : TOptimizerSwitches;
        Flags : TPendingStateFlags;
      end;


    var
       { specified inputfile }
       InputFilePath     : string;
       InputFileName     : string;
       { specified outputfile with -o parameter }
       OutputFileName    : string;
       OutputPrefix      : PShortString;
       OutputSuffix      : PShortString;
       { selected subtarget }
       SubTarget         : string;

       { specified with -FE or -FU }
       OutputExeDir      : TPathStr;
       OutputUnitDir     : TPathStr;
       { specified with -FW and -Fw }
       WPOFeedbackInput,
       WPOFeedbackOutput : TPathStr;
       { external assembler extra option }
       AsmExtraOpt       : string;

       { things specified with parameters }
       ParaLinkOptions   : TCmdStr;
       ParaDynamicLinker : string;
       ParaPrintNodeTree : Byte;
       PrintNodeFile     : Text;

       {  typical cross compiling params}

       { directory where the utils can be found (options -FD) }
       UtilsDirectory : TPathStr;
       { targetname specific prefix used by these utils (options -XP<path>) }
       UtilsPrefix    : TCmdStr;

       { Suffix for LLVM utilities, e.g. '-7' for clang-7 }
       LLVMUtilsSuffix     : TCmdStr;

       CShared        : Boolean;        { pass --shared to ld to link C libs shared}
       DontLinkStdlibPath: Boolean;     { Don't add std paths to linkpath}
       RLinkPath      : TCmdStr;        { rpath-link linkdir override}
       SysRootPath    : TCmdStr;        { target system root to search dyn linker }

       { some flags for global compiler switches }
       Do_Build,
       Do_Release,
       Do_Make       : Boolean;

       TimeStr,
       DateStr : string;
       { Path to ppc }
       ExePath       : TPathStr;
       { Path to unicode charmap/collation binaries }
       UnicodePath   : TPathStr;
       { path for searching units, different paths can be separated by ; }
       LibrarySearchPath,
       UnitSearchPath,
       ObjectSearchPath,
       IncludeSearchPath,
       FrameworkSearchPath  : TSearchPathList;
       PackageSearchPath     : TSearchPathList;

       { list of default namespaces }
       NamespaceList : TCmdStrList;
       // During scanning/parsing, a module may not yet be available.
       // Scanner checks first current_namespacelist, then local_namespacelist
       PreModule_NamespaceList,                    // always set: used as long as current_namespacelist is not correctly set.
       CurrentNamespaceList : TCmdStrList;        // Set when parsing module to the current module's namespace.
       { contains tpackageentry entries }
       PackageList : TFPHashList;
       Package_SDK_Identity, Package_Build_Identity: ShortString;
       Embed_Package_Metadata: Boolean;
       AutoloadUnits      : string;

       { linking }
       UseWindowAPI  : Boolean;
       Description   : string;
       SetPEFlagsSetExplicity,
       SetPEOptFlagsSetExplicity,
       SetPEOSVersionSetExplicitely,
       SetPESubSysVersionSetExplicitely,
       SetPEUserVersionSetExplicitely,
       ImageBaseSetExplicity,
       MinStackSizeSetExplicity,
       MaxStackSizeSetExplicity,
       DescriptionSetExplicity : Boolean;
       DLLVersion    : string;
       DLLMajor,
       DLLMinor,
       { win pe  }
       PEOSVersionMinor,
       PEOSVersionMajor,
       PESubSysVersionMinor,
       PESubSysVersionMajor,
       PEUserVersionMinor,
       PEUserVersionMajor : Word;
       PEOptFlags,
       PEFlags : LongInt;
       MinStackSize,
       MaxStackSize,
       ImageBase     : PUint;
       UseDefFileForExports    : Boolean;
       UseDefFileForExportsSetExplicitly : Boolean;
       GenerateImportSection,
       GenerateImportSectionSetExplicitly,
       RelocSection : Boolean;

       MacOSXVersionMin,
       IPhoneOSVersionMin: TVersion;
       RelocSectionSetExplicitly : Boolean;

       CurrentTokenPos,                  { position of the last token }
       CurrentFilePos : TFilePosInfo;    { current position }

       CodeGenError : Boolean;           { true if there is an error reported }
       Exception_Raised : Boolean;           { true if there is an exception reported }

       Block_Type : TBlockType;         { type of currently parsed block }

       ExceptBlockCounter    : Integer;  { each except block gets a unique number check gotos      }
       Current_ExceptBlock        : Integer;  { the exceptblock number of the current block (0 if none) }
       LinkLibraryAliases : TLinkStrMap;
       LinkLibraryOrder   : TLinkStrMap;


       InitSettings,
       CurrentSettings   : TSettings;

       { The default text type belongs to the compiler invocation, not to
         an individual module or its language mode. }
       CompilerWide_Unicode_Strings : Boolean;
       CompilerWide_String_Mode_Explicit : Boolean;

       PendingState       : TPendingState;
     { Memory sizes }
       HeapSize,
       MaxHeapSize : Int64;
       StackSize   : LongInt;

{$Ifdef EXTDEBUG}
     { parameter switches }
       DebugStop : Boolean;
{$EndIf EXTDEBUG}
       { Application type (platform specific)
         see globtype.pas for description }
       AppType : TAppType;

       Features : TFeatures;

       CGBackend: TCGBackend;

       Inside_Asm_Statement : Boolean = False;

       Global_Unit_Count : Word = 0;

       { for error info in pp.pas }
       Parser_Current_File : string = '';


    const
       { default name of the C-style "main" procedure of the library/program }
       { (this will be prefixed with the target_info.cprefix)                }
       DefaultMainAliasName = 'main';

    var
       MainAliasName : string = DefaultMainAliasName;

    const
       CustomAttributeSuffix = 'ATTRIBUTE';

    var
      LTOExt: TCmdStr = '';

      Default_Settings : TSettings = (
        Alignment : (
          ProcAlign : 0;
          LoopAlign : 0;
          JumpAlign : 0;
          JumpAlignSkipMax    : 0;
          CoalesceAlign   : 0;
          CoalesceAlignSkipMax: 0;
          ConstAlignMin : 0;
          ConstAlignMax : 0;
          VarAlignMin : 0;
          VarAlignMax : 0;
          LocalAlignMin : 0;
          LocalAlignMax : 0;
          RecordAlignMin : 0;
          RecordAlignMax : 0;
          MaxCRecordAlign : 0;
        );
        GlobalSwitches : [cs_check_unit_name,cs_link_static,cs_link_lld];
        TargetSwitches : [];
        ModuleSwitches : [cs_extsyntax,cs_implicit_exceptions,cs_support_c_operators];
        LocalSwitches : [cs_check_io,cs_typed_const_writable,cs_pointermath,cs_refcountedstrings];
        ModeSwitches : FPCModeSwitches + [m_default_ansistring];
        OptimizerSwitches : [];
        GenWPOptimizerSwitches : [];
        DoWPOptimizerSwitches : [];

        DebugSwitches : [ds_dwarf_sets];


        SetAlloc : 0;
        PackEnum : 4;


        PackRecords     : 0;

        MaxFPURegisters : 0;

        Verbosity : VDefault;

{ Note: GENERIC_CPU is used together with generic subdirectory to
  be able to compile some of the units without any real CPU.
  This is used to generate a CPU independant PPUDUMP utility. PM }
{$ifdef GENERIC_CPU}
        CPUType : cpu_none;
        OptimizeCPUType : cpu_none;
        AsmCPUType : cpu_none;
        FPUType : fpu_none;
{$else not GENERIC_CPU}
  {$ifdef i386}
        CPUType : cpu_Pentium2;
        OptimizeCPUType : cpu_Pentium3;
        AsmCPUType : cpu_none;
        FPUType : fpu_x87;
  {$endif i386}
  {$ifdef x86_64}
        CPUType : cpu_athlon64;
        OptimizeCPUType : cpu_athlon64;
        AsmCPUType : cpu_none;
        FPUType : fpu_sse64;
  {$endif x86_64}
  {$ifdef aarch64}
        CPUType : cpu_armv8;
        OptimizeCPUType : cpu_armv8;
        AsmCPUType : cpu_none;
        FPUType : fpu_vfp;
  {$endif aarch64}


{$endif not GENERIC_CPU}
        AsmMode : asmmode_standard;
        InterfaceType : it_interfacecom;
        DefProcCall : pocall_default;
        SourceCodePage : 28591;
        MinFPConstPrec : S32Real;

        DisableDirCache : False;

        TLSModel : tlsm_none;
        PMessage : nil;
        LineEndingType : le_platform;
        WhitespaceTrimCount : 0;
        WhitespaceTrimAuto : False;
{$if defined(GENERIC_CPU)}
        X86MemoryModel : mm_small;
{$endif defined(GENERIC_CPU)}
      );

      StartTime  : Real;
      StartSysTime : TSystemTime;

    function GetDateStr:string;
    function GetTimeStr:string;
    function FileTimeString( T : LongInt) : string;
    function GetRealTime(const ST: TSystemTime) : Real;
    function GetRealTime : Real;

    procedure DefaultReplacements(var S:AnsiString; SubstituteEnvVariables:Boolean=True);

    function  GetEnvPChar(const EnvName:AnsiString):PChar;
    procedure FreeEnvPChar(P:PChar);

    function Is_Number_Float(D : BestReal) : Boolean;
    { discern +0.0 and -0.0 }
    function Get_Real_Sign(R: BestReal): LongInt;

    function IsPosZero(Value: BestReal): Boolean; {$ifdef USEINLINE}inline;{$endif USEINLINE}
    function IsNegZero(Value: BestReal): Boolean; {$ifdef USEINLINE}inline;{$endif USEINLINE}

    procedure InitGlobals;
    procedure DoneGlobals;
    procedure Register_InitDone_Proc(Init,Done:TProcedure);

    function  String2GUID(const S: string; var GUID: TGUID): Boolean;
    function  GUID2String(const GUID: TGUID): string;

    function SetAktProcCall(const S:string; var A:TProcCallOption):Boolean;
    function SetABIType(const S:string;var A:TABI):Boolean;
    function SetOptimizeCPUType(const S:string;var A:TCPUType):Boolean;
    function SetCPUType(const S:string;var A:TSettings):Boolean;
    function SetFPUType(const S:string;var A:TFPUType):Boolean;
    function HandleFeature(const S : string) : Boolean;
    function SetMinFPConstPrec(const S: string; var A: TFloatType) : Boolean;

    {# Routine to get the required alignment for size of data, which will
       be placed in bss segment, according to the current alignment requirements }
    function Size_2_Align(Len : ASizeUInt) : LongInt;
    function Var_Align(WantAlign: LongInt): ShortInt;
    function Var_Align_Size(Siz: ASizeUInt): ShortInt;
    {# Routine to get the required alignment for size of data, which will
       be placed in data/const segment, according to the current alignment requirements }
    function Const_Align(WantAlign: LongInt): ShortInt;
    function Const_Align_Size(Siz: ASizeUInt): ShortInt;
    function Floating_Point_Range_Check_Error : Boolean;

  { hide Sysutils.ExecuteProcess in units using this one after SysUtils}
  const
    ExecuteProcess = 'Do not use' deprecated 'Use cfileutil.RequotedExecuteProcess instead, ExecuteProcess cannot deal with single quotes as used by Unix command lines';

  var
    AllowedFilenameTransFormations : TFileNameTransformations = AllTransformations;


implementation

{$if defined(mswindows)}
    uses
      WinDirs;
{$endif}

{****************************************************************************
                                 TLinkStrMap
****************************************************************************}

    Constructor TLinkStrMap.Create;
      begin
        inherited;
        ItemCnt:=0;
      end;


    procedure TLinkStrMap.Add(const Key:AnsiString;const Value:AnsiString='';Weight:LongInt=LinkMapWeightDefault);
      begin
        if Lookup(Key)<>-1 Then
          Exit;
        if ItemCnt<=Length(FMap) Then
          SetLength(FMap,ItemCnt+10);
        FMap[ItemCnt].Key:=Key;
        FMap[ItemCnt].Value:=Value;
        FMap[ItemCnt].Weight:=Weight;
        Inc(ItemCnt);
      end;


    function  TLinkStrMap.AddDep(const KeyValue:String):Boolean;
      var
        I : LongInt;
      begin
        AddDep:=False;
        I:=Pos('=',KeyValue);
        if I=0 then
          Exit;
        Add(Copy(KeyValue,1,I-1),Copy(KeyValue,I+1,Length(KeyValue)-I));
        AddDep:=True;
      end;


    function  TLinkStrMap.AddWeight(const KeyValue:String):Boolean;
      var
        I,J    : LongInt;
        Code : Word;
        S    : AnsiString;
      begin
        AddWeight:=False;
        I:=Pos('=',KeyValue);
        if I=0 then
          Exit;
        S:=Copy(KeyValue,I+1,Length(KeyValue)-I);
        Val(S,J,Code);
        if Code=0 Then
          begin
            Add(Copy(KeyValue,1,I-1),'',J);
            AddWeight:=True;
          end;
      end;


    procedure TLinkStrMap.AddSeries(const Keys:AnsiString;Weight:LongInt);
      var
        I,J,K : LongInt;
      begin
       K:=Length(Keys);
       I:=1;
       while I<=K do
         begin
           J:=I;
           while (I<=K) and (Keys[I]<>',') do
             Inc(I);
           Add(Copy(Keys,J,I-J),'',Weight);
           Inc(I);
         end;
      end;

    procedure TLinkStrMap.SetValue(const Key:AnsiString;Weight:Integer);
      var
        J : LongInt;
      begin
         J:=Lookup(Key);
         if J<>-1 then
          FMap[J].Weight:=Weight;
      end;


    function TLinkStrMap.Find(const Key:AnsiString):AnsiString;
      var
        J : LongInt;
      begin
         Find:='';
         J:=Lookup(Key);
         if J<>-1 then
          Find:=FMap[J].Value;
      end;


    function TLinkStrMap.Lookup(const Key:AnsiString):LongInt;
      var
        I : LongInt;
      begin
         Lookup:=-1;
         I:=0;
         while (I<ItemCnt) and (FMap[I].Key<>Key) do
           Inc(I);
         if I<>ItemCnt then
            Lookup:=I;
      end;


    procedure TLinkStrMap.SortOnWeight;
      var
        I, J : LongInt;
        M    : TLinkRec;
      begin
        if ItemCnt <2 then Exit;
        for I:=0 to ItemCnt-1 do
          for J:=I+1 to ItemCnt-1 do
            begin
            if FMap[I].Weight>FMap[J].Weight Then
              begin
                M:=FMap[I];
                FMap[I]:=FMap[J];
                FMap[J]:=M;
              end;
           end;
      end;


    function TLinkStrMap.GetLinkRec(I:LongInt):TLinkRec;
      begin
        Result:=FMap[I];
      end;


    procedure TLinkStrMap.Expand(Src:TCmdStrList;Dest:TLinkStrMap);
      // expands every thing in Src to Dest for linkorder purposes.
      var
        R  : LongInt;
        LibN    : TCmdStr;
      begin
        while not Src.Empty do
          begin
            LibN:=Src.GetFirst;
            R:=Lookup (LibN);
            if R=-1 then
              Dest.Add(LibN)
            else
              Dest.AddSeries(FMap[R].Value);
          end;
      end;

    procedure TLinkStrMap.UpdateWeights(WeightMap:TLinkStrMap);
      var
        L,R : LongInt;
      begin
        for L := 0 to ItemCnt-1 do
          begin
            R:=WeightMap.Lookup (FMap[L].Key);
            if R<>-1 then
              FMap[L].Weight:=WeightMap[R].Weight;
          end;
      end;


{****************************************************************************
                               Time Handling
****************************************************************************}

    Function L0(L:LongInt):string;
    {
      return the string of value l, if l<10 then insert a zero, so
      the string is always at least 2 chars '01','02',etc
    }
      var
        S : string;
      begin
        Str(L,S);
        if L<10 then
         S:='0'+S;
        L0:=S;
      end;


   function GetTimeStr:string;
   {
     get the current time in a string HH:MM:SS
   }
      var
        ST: TSystemTime;
      begin
        GetLocalTime(ST);
        GetTimeStr:=L0(ST.Hour)+':'+L0(ST.Minute)+':'+L0(ST.Second);
      end;


   function GetDateStr:string;
   {
     get the current date in a string YY/MM/DD
   }
      var
        ST: TSystemTime;
      begin
        GetLocalTime(ST);
        GetDateStr:=L0(ST.Year)+'/'+L0(ST.Month)+'/'+L0(ST.Day);
      end;


   function  FileTimeString( T : LongInt) : string;
   {
     convert dos datetime t to a string YY/MM/DD HH:MM:SS
   }
     var
       DT : TDateTime;
       HSec : Word;
       Year,Month,Day: Word;
       Hour,Min,Sec : Word;
     begin
       if T=-1 then
        begin
          Result := 'Not Found';
          Exit;
        end;
       DT := FileDateToDateTime(T);
       DecodeTime(DT,Hour,Min,Sec,HSec);
       DecodeDate(DT,Year,Month,Day);
       Result := L0(Year)+'/'+L0(Month)+'/'+L0(Day)+' '+L0(Hour)+':'+L0(Min)+':'+L0(Sec);
     end;

   function GetRealTime(const ST: TSystemTime) : Real;
     begin
       Result := ST.Hour*3600.0 + ST.Minute*60.0 + ST.Second + ST.MilliSecond/1000.0;
     end;

   function GetRealTime : Real;
     var
       ST:TSystemTime;
     begin
       GetLocalTime(ST);
       Result:=GetRealTime(ST);
     end;

   function IDFVersionString(Version : LongInt):string;
   {
     Convert back the numerical idf_version for esp32 to string
   }
     begin
       Result := '';
       if Version > 0 then
         begin
           Result := IntToStr(Version div 10000)+'.';
           Version := Version - (Version div 10000)*10000;
           Result := Result + IntToStr(Version div 100)+'.';
           Version := Version - (Version div 100)*100;
           Result := Result + IntToStr(Version);
         end;
     end;

{****************************************************************************
                          Default Macro Handling
****************************************************************************}


     procedure DefaultReplacements(var S:AnsiString; SubstituteEnvVariables:Boolean=True);
{$ifdef mswindows}
       procedure ReplaceSpecialFolder(const MacroName: string; const Id: Integer);
         begin
           // Only try to receive the special folders (and thus dynamically
           // load shfolder.dll) when that's needed.
           if Pos(MacroName,S)>0 then
             Replace(S,MacroName,GetWindowsSpecialDir(Id));
         end;

{$endif mswindows}
       var
         EnvStr: string;
         EnvValue: PChar;
         I: Integer;
       begin
         { Replace some macros }
         Replace(S,'$FPCVERSION',Version_String);
         Replace(S,'$FPCFULLVERSION',Full_Version_String);
         Replace(S,'$FPCDATE',DateString);
         Replace(S,'$FPCCPU',TargetCPUString);
         Replace(S,'$FPCOS',TargetOSString);
         Replace(S,'$FPCBINDIR',ExePath);
         if (tf_use_8_3 in SourceInfo.Flags) or
            (tf_use_8_3 in TargetInfo.Flags) then
           Replace(S,'$FPCTARGET',TargetOSString)
         else if SubTarget<>'' then
           Replace(S,'$FPCTARGET',TargetFullString+'-'+Lower(SubTarget))
         else
           Replace(S,'$FPCTARGET',TargetFullString);
         Replace(S,'$FPCSUBARCH',Lower(CPUTypeStr[InitSettings.CPUType]));
         Replace(S,'$FPCABI',Lower(ABIInfo[TargetInfo.ABI].Name));

         Replace(S,'$FPCMEMORYMODEL','flat');

{$ifdef mswindows}
         ReplaceSpecialFolder('$LOCAL_APPDATA',CSIDL_LOCAL_APPDATA);
         ReplaceSpecialFolder('$APPDATA',CSIDL_APPDATA);
         ReplaceSpecialFolder('$COMMON_APPDATA',CSIDL_COMMON_APPDATA);
         ReplaceSpecialFolder('$PERSONAL',CSIDL_PERSONAL);
         ReplaceSpecialFolder('$PROGRAM_FILES',CSIDL_PROGRAM_FILES);
         ReplaceSpecialFolder('$PROGRAM_FILES_COMMON',CSIDL_PROGRAM_FILES_COMMON);
         ReplaceSpecialFolder('$PROFILE',CSIDL_PROFILE);
{$endif mswindows}

         if not SubstituteEnvVariables then
           Exit;
         { Replace environment variables between dollar signs }
         I := Pos('$',S);
         while I>0 do
          begin
            EnvStr:=Copy(S,I+1,Length(S)-I);
            I:=Pos('$',EnvStr);
            if I>0 then
             begin
               EnvStr := Copy(EnvStr,1,I-1);
               EnvValue := GetEnvPChar(EnvStr);
               if Assigned(EnvValue) then
                 begin
                 Replace(S,'$'+EnvStr+'$',EnvValue);
                 // Look if there is another env.var in the string
                 I:=Pos('$',S);
                 end
               else
                 // if the env.var is not set, do not replace the env.variable
                 // and stop looking for more env.var within the string
                 I := 0;
              FreeEnvPChar(EnvValue);
             end;
          end;
       end;


 {****************************************************************************
                               OS Dependent things
 ****************************************************************************}

    function GetEnvPChar(const EnvName:AnsiString):PChar;
      {$ifdef mswindows}
      var
        S     : string;
        I,Len : LongInt;
        HP,P,P2 : PChar;
      {$endif}
      begin
      {$ifdef hasunix}
        GetEnvPChar:=BaseUnix.FpGetEnv(PAnsiChar(EnvName));
        {$define GETENVOK}
      {$endif}
      {$ifdef mswindows}
        GetEnvPChar:=nil;
        P:=GetEnvironmentStringsA;
        HP:=P;
        while HP^<>#0 do
         begin
           S:=StrPas(HP);
           I:=Pos('=',S);
           Len:=StrLen(HP);
           if Upper(Copy(S,1,I-1))=Upper(EnvName) then
            begin
              GetMem(P2,Len-Length(EnvName));
              Move(HP[I],P2^,Len-Length(EnvName));
              GetEnvPChar:=P2;
              Break;
            end;
           { next string entry}
           HP:=HP+Len+1;
         end;
        FreeEnvironmentStrings(P);
        {$define GETENVOK}
      {$endif}
      {$ifdef GETENVOK}
        {$undef GETENVOK}
      {$else}
        GetEnvPChar:=StrPNew(GetEnvironmentVariable(EnvName));
        if (Length(GetEnvPChar)=0) then
          begin
            FreeEnvPChar(GetEnvPChar);
            GetEnvPChar:=nil;
          end;
      {$endif}
      end;


    procedure FreeEnvPChar(P:PChar);
      begin
      {$ifndef hasunix}
        FreeMem(P);
      {$endif}
      end;

      function Is_Number_Float(D : BestReal) : Boolean;
      begin
        Result:=BestRealRec(D).SpecialType in
          [fsZero,fsNZero,fsDenormal,fsNDenormal,fsPositive,fsNegative];
      end;

    function Get_Real_Sign(R: BestReal): LongInt;
      begin
        if BestRealRec(R).Sign then Result:=-1 else Result:=1;
      end;

    function ConvertDoubleRec(D : TCompDoubleRec) : TCompDoubleRec;{$ifdef USEINLINE}inline;{$endif}
      begin
        Result:=D;
      end;

    function IsPosZero(Value: BestReal): Boolean; {$ifdef USEINLINE}inline;{$endif USEINLINE}
      begin
        Result:=BestRealRec(Value).SpecialType=fsZero;
      end;

    function IsNegZero(Value: BestReal): Boolean; {$ifdef USEINLINE}inline;{$endif USEINLINE}
      begin
        Result:=BestRealRec(Value).SpecialType=fsNZero;
      end;

    { '('D1:'00000000-'D2:'0000-'D3:'0000-'D4:'0000-000000000000)' }
    function String2GUID(const S: string; var GUID: TGUID): Boolean;
        function IsHexStr(const HS: string): Boolean;
          var
            I: Integer;
          begin
            IsHexStr:=False;
            for I:=1 to Length(HS) do begin
              if not (HS[I] in ['0'..'9','A'..'F','a'..'f']) then
                Exit;
            end;
            IsHexStr:=True;
          end;
        function HexStr2LongInt(const HexS: string): LongInt;
          var
            I: Integer;
            RL: LongInt;
          begin
            RL:=0;
            for I:=1 to Length(HexS) do begin
              RL:=RL shl 4;
              case HexS[I] of
                '0'..'9' : Inc(RL,Ord(HexS[I])-Ord('0'));
                'A'..'F' : Inc(RL,Ord(HexS[I])-Ord('A')+10);
                'a'..'f' : Inc(RL,Ord(HexS[I])-Ord('a')+10);
              end
            end;
            HexStr2LongInt:=RL;
          end;
      var
        I: Integer;
      begin
        if (Length(S)=38) and (S[1]='{') and (S[38]='}') and
           (S[10]='-') and (S[15]='-') and (S[20]='-') and (S[25]='-') and
           IsHexStr(Copy(S,2,8)) and IsHexStr(Copy(S,11,4)) and
           IsHexStr(Copy(S,16,4)) and IsHexStr(Copy(S,21,4)) and
           IsHexStr(Copy(S,26,12)) then begin
          GUID.D1:=DWord(HexStr2LongInt(Copy(S,2,8)));
          { these values are already in the correct range (4 chars = word) }
          GUID.D2:=Word(HexStr2LongInt(Copy(S,11,4)));
          GUID.D3:=Word(HexStr2LongInt(Copy(S,16,4)));
          for I:=0 to 1 do
            GUID.D4[I]:=Byte(HexStr2LongInt(Copy(S,21+I*2,2)));
          for I:=2 to 7 do
            GUID.D4[I]:=Byte(HexStr2LongInt(Copy(S,22+I*2,2)));
          String2GUID:=True;
        end
        else if (Length(S)=0) then
          begin
          FillChar(GUID,SizeOf(GUID),0);
          String2GUID:=True;
          end
        else
          String2GUID:=False;
      end;


    function GUID2String(const GUID: TGUID): string;

      begin
        GUID2String:=
          '{'+HexStr(GUID.D1,8)+
          '-'+HexStr(GUID.D2,4)+
          '-'+HexStr(GUID.D3,4)+
          '-'+HexStr(GUID.D4[0],2)+HexStr(GUID.D4[1],2)+
          '-'+HexStr(GUID.D4[2],2)+HexStr(GUID.D4[3],2)+
              HexStr(GUID.D4[4],2)+HexStr(GUID.D4[5],2)+
              HexStr(GUID.D4[6],2)+HexStr(GUID.D4[7],2)+
          '}';
      end;


    function SetAktProcCall(const S:string; var A:TProcCallOption):Boolean;
      const
        DefProcCallName : array[TProcCallOption] of string[16] = ('',
         'CDECL',
         'CPPDECL',
         'FAR16',
         'OLDFPCCALL',
         '', { internproc }
         'PASCAL',
         'REGISTER',
         'SAFECALL',
         'STDCALL',
         'SOFTFLOAT',
         'MWPASCAL',
         'INTERRUPT',
         'HARDFLOAT',
         'SYSV_ABI_DEFAULT',
         'SYSV_ABI_CDECL',
         'MS_ABI_DEFAULT',
         'MS_ABI_CDECL',
         'VECTORCALL'
        );
      var
        T  : TProcCallOption;
        HS : string;
      begin
        Result:=False;
        if (S = '') then
          Exit;
        HS:=Upper(S);
        if (HS = 'DEFAULT') then
          begin
            A := pocall_default;
            Result := True;
            Exit;
          end;
        for T:=Low(TProcCallOption) to High(TProcCallOption) do
         if DefProcCallName[T]=HS then
          begin
            A:=T;
            Result:=True;
            Break;
          end;
      end;


    function SetABIType(const S:string;var A:TABI):Boolean;
      var
        T  : TABI;
        HS : string;
      begin
        Result:=False;
        HS:=Upper(S);
        for T:=Low(T) to High(T) do
          if ABIInfo[T].Supported and
             (ABIInfo[T].Name=HS) then
            begin
              A:=T;
              { abi_old_win32_gnu is a win32 i386 specific "feature" }
              if (T<>abi_old_win32_gnu) or (TargetInfo.System=system_i386_win32) then
                Result:=True;
              Break;
            end;
      end;


    function SetOptimizeCPUType(const S:string;var A:TCPUType):Boolean;
      var
        T  : TCPUType;
        HS : string;
      begin
        Result:=False;
        HS:=Upper(S);
        for T:=Low(TCPUType) to High(TCPUType) do
          if CPUTypeStr[T]=HS then
            begin
              A:=T;
              Result:=True;
              Break;
            end;
      end;


    function SetCPUType(const S:string;var A:TSettings):Boolean;
      var
        T  : TCPUType;
        HS : string;
      begin
        Result:=False;
        HS:=Upper(S);
        for T:=Low(TCPUType) to High(TCPUType) do
          if CPUTypeStr[T]=HS then
            begin
              A.CPUType:=T;
              Result:=True;
              Break;
            end;
      end;


    function SetFPUType(const S:string;var A:TFPUType):Boolean;
      var
        T : TFPUType;
      begin
        Result:=False;
        for T:=Low(TFPUType) to High(TFPUType) do
          if (FPUTypeStr[T]<>'') and (FPUTypeStr[T]=S) then
            begin
              A:=T;
              Result:=True;
              Break;
            end;
      end;


    function HandleFeature(const S : string) : Boolean;
      var
        I : TFeature;
      begin
        Result:=True;
        for I:=Low(TFeature) to High(TFeature) do
          if S=FeatureStr[I] then
            begin
              Include(Features,I);
              Exit;
            end;
        { Also support -Sfnoheap to exclude heap }
        if Copy(S,1,2)='NO' then
          for I:=Low(TFeature) to High(TFeature) do
            if S='NO'+FeatureStr[I] then
              begin
                Exclude(Features,I);
                Exit;
              end;
        Result:=False;
      end;


    function SetMinFPConstPrec(const S: string; var A: TFloatType) : Boolean;
      var
        Value, Error: LongInt;
      begin
        if (Upper(S)='DEFAULT') then
          begin
            A:=S32Real;
            Result:=True;
            Exit;
          end;
        Result:=False;
        Val(S,Value,Error);
        if (Error<>0) then
          Exit;
        case Value of
          32: A:=S32Real;
          64: A:=S64Real;
          { adding support for 80 bit here is tricky, since we can't really }
          { check whether the target cpu+OS actually supports it            }
          else
            Exit;
        end;
        Result:=True;
      end;


    function Size_2_Align(Len : ASizeUInt) : LongInt;
      begin
         if Len>16 then
           Size_2_Align:=32
         else if Len>8 then
           Size_2_Align:=16
         else if Len>4 then
           Size_2_Align:=8
         else if Len>2 then
           Size_2_Align:=4
         else if Len>1 then
           Size_2_Align:=2
         else
           Size_2_Align:=1;
      end;


    function Var_Align(WantAlign: LongInt): ShortInt;
      begin
        Var_Align := Used_Align(WantAlign,CurrentSettings.Alignment.VarAlignMin,CurrentSettings.Alignment.VarAlignMax);
      end;


    function Var_Align_Size(Siz: ASizeUInt): ShortInt;
      begin
        Siz := Size_2_Align(Siz);
        Var_Align_Size := Var_Align(Siz);
      end;


    function Const_Align(WantAlign: LongInt): ShortInt;
      begin
        Const_Align := Used_Align(WantAlign,CurrentSettings.Alignment.ConstAlignMin,CurrentSettings.Alignment.ConstAlignMax);
      end;


    function Const_Align_Size(Siz: ASizeUInt): ShortInt;
      begin
        Siz := Size_2_Align(Siz);
        Const_Align_Size := Const_Align(Siz);
      end;




    function Floating_Point_Range_Check_Error : Boolean;
      begin
        Result:=cs_ieee_errors in CurrentSettings.LocalSwitches;
      end;


{****************************************************************************
                                    Init
****************************************************************************}

{$ifdef unix}
  {$define need_path_search}
{$endif unix}

   procedure GetExePath;
     var
       LocalExePath : TCmdStr;
       ExeName:TCmdStr;
{$ifdef need_path_search}
       HS1 : TPathStr;
{$endif need_path_search}
     begin
       LocalExePath:=GetEnvironmentVariable('NXPC_EXEC_PATH');
       ExeName := '';
       if LocalExePath='' then
         begin
           ExeName := FixFileName(System.ParamStr(0));
           LocalExePath := ExtractFilePath(ExeName);
         end;
{$ifdef need_path_search}
       if LocalExePath='' then
        begin
          HS1 := ExtractFileName(ExeName);
          HS1 := ChangeFileExt(HS1,SourceInfo.ExeExt);
          FindFile(HS1,GetEnvironmentVariable('PATH'),False,LocalExePath);
          LocalExePath:=ExtractFilePath(LocalExePath);
        end;
{$endif need_path_search}
       ExePath:=FixPath(LocalExePath,False);
     end;



   type
     TInitDoneEntry=record
       Init:TProcedure;
       Done:TProcedure;
     end;
     PInitDoneEntry=^TInitDoneEntry;


   var
     InitDoneProcs : TFPList = nil;


   procedure Register_InitDone_Proc(Init,Done:TProcedure);
     var
       Entry : PInitDoneEntry;
     begin
       New(Entry);
       Entry^.Init:=Init;
       Entry^.Done:=Done;
       TFPList.AddOnDemand(InitDoneProcs,Entry);
     end;


   procedure CallInitProcs;
     var
       I : LongInt;
     begin
       if not Assigned(InitDoneProcs) then
         Exit;
       for I:=0 to InitDoneProcs.Count-1 do
         with PInitDoneEntry(InitDoneProcs[I])^ do
           if Assigned(Init) then
             Init();
     end;


   procedure CallDoneProcs;
     var
       I : LongInt;
     begin
       if not Assigned(InitDoneProcs) then
         Exit;
       for I:=0 to InitDoneProcs.Count-1 do
         with PInitDoneEntry(InitDoneProcs[I])^ do
           if Assigned(Done) then
             Done();
     end;


   procedure DoneGlobals;
     begin
       CallDoneProcs;
       LibrarySearchPath.Free;
       LibrarySearchPath := nil;
       UnitSearchPath.Free;
       UnitSearchPath := nil;
       ObjectSearchPath.Free;
       ObjectSearchPath := nil;
       IncludeSearchPath.Free;
       IncludeSearchPath := nil;
       FrameworkSearchPath.Free;
       FrameworkSearchPath := nil;
       LinkLibraryAliases.Free;
       LinkLibraryAliases := nil;
       LinkLibraryOrder.Free;
       LinkLibraryOrder := nil;
       PackageSearchPath.Free;
       PackageSearchPath := nil;
       NamespaceList.Free;
       NamespaceList := nil;
       PreModule_NamespaceList.Free;
       PreModule_NamespaceList := nil;
       CurrentNamespaceList:=Nil;
     end;

   procedure InitGlobals;
     begin
        GetExePath;

        { reset globals }
        Do_Build:=False;
        Do_Release:=False;
        Do_Make:=True;
        CodeGenError:=False;
        Global_Unit_Count:=0;

        { Output }
        OutputFileName:='';
        OutputPrefix:=Nil;
        OutputSuffix:=Nil;

        OutputExeDir:='';
        OutputUnitDir:='';

        { Utils directory }
        UtilsDirectory:='';
        UtilsPrefix:='';
        LLVMUtilsSuffix:='';
        CShared:=False;
        RLinkPath:='';
        SysRootPath:='';

        { Search Paths }
        UnicodePath:='';
        LibrarySearchPath:=TSearchPathList.Create;
        UnitSearchPath:=TSearchPathList.Create;
        IncludeSearchPath:=TSearchPathList.Create;
        ObjectSearchPath:=TSearchPathList.Create;
        FrameworkSearchPath:=TSearchPathList.Create;
        PackageSearchPath:=TSearchPathList.Create;
        Package_SDK_Identity:='';
        Package_Build_Identity:='';
        Embed_Package_Metadata:=True;
        NamespaceList:=TCmdStrList.Create;
        PreModule_NamespaceList:=TCmdStrList.Create;
        CurrentNamespaceList:=Nil;
        { Def file }
        UseWindowAPI:=False;
        Description:='Compiled by FPC '+Version_String+' - '+TargetCPUString;
        DescriptionSetExplicity:=False;
        SetPEFlagsSetExplicity:=False;
        SetPEOptFlagsSetExplicity:=False;
        SetPEOSVersionSetExplicitely:=False;
        SetPESubSysVersionSetExplicitely:=False;
        SetPEUserVersionSetExplicitely:=False;
        ImageBaseSetExplicity:=False;
        MinStackSizeSetExplicity:=False;
        MaxStackSizeSetExplicity:=False;

        DLLVersion:='';
        DLLMajor:=1;
        DLLMinor:=0;
        UseDefFileForExports:=False;
        UseDefFileForExportsSetExplicitly:=False;
        GenerateImportSection:=False;
        RelocSection:=False;
        RelocSectionSetExplicitly:=False;
        MacOSXVersionMin.Invalidate;
        IPhoneOSVersionMin.Invalidate;
        { memory sizes, will be overridden by parameter or default for target
          in options or init_parser }
        StackSize:=0;
        { not initialized yet }
        AppType:=app_cui;

        { Init values }
        CompilerWide_Unicode_Strings:=False;
        CompilerWide_String_Mode_Explicit:=False;
        InitSettings:=Default_Settings;
        if InitSettings.OptimizeCPUType=cpu_none then
          InitSettings.OptimizeCPUType:=InitSettings.CPUType;

        LinkLibraryAliases :=TLinkStrMap.Create;
        LinkLibraryOrder   :=TLinkStrMap.Create;

        { enable all features by default }
        Features:=[Low(TFeature)..High(TFeature)];

        CallInitProcs;
     end;

initialization

  CGBackend:=cg_fpc;

finalization
  TFPList.FreeAndNilDisposing(InitDoneProcs,TypeInfo(TInitDoneEntry));
end.
