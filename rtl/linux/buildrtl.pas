unit buildrtl;

  interface
{$IFDEF FPC_DOTTEDUNITS}
    uses
      si_prc,
      Unix.CThreads, TP.DOS, System.SysUtils,

      System.ExeInfo,

      System.CTypes, System.Strings,
      System.RtlConsts, System.SysConst, System.Math, System.Types,

{$ifdef cpui386}
      System.CPU, System.CPU.MMX, System.LineInfo.Dwarf,
{$endif}
{$ifdef cpux86_64}
      System.CPU,
{$endif}

      System.TypInfo, System.SortBase, System.Classes,
      System.CharSet, System.Character, System.GetOpts,
      System.FPWideString, fpintres, System.CodePages.All;
{$ELSE FPC_DOTTEDUNITS}
    uses
      si_prc,
      cthreads, dos, sysutils,

      ctypes, strings,
      rtlconsts, sysconst, math, types,

      exeinfo,
{$ifdef cpui386}
      cpu, mmx, lnfodwrf,
{$endif}
{$ifdef cpux86_64}
      cpu,
{$endif}

      typinfo, sortbase, classes,
      charset, character, getopts,
      fpwidestring, fpintres;
{$ENDIF FPC_DOTTEDUNITS}
  implementation

end.

