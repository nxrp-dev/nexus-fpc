unit buildrtl;

  interface

{$IFDEF FPC_DOTTEDUNITS}
    uses
      sysinitpas, sysinitcyg, sysinitgprof,
      heaptrc,
      System.CTypes, System.Strings,
      WinApi.Windows,  initc,  System.CMem, System.DynLibs, WinApi.Signals,
      TP.DOS, WinApi.Messages,
      System.RtlConsts, System.SysConst, System.SysUtils, System.Math, System.Types,
      System.TypInfo, System.Classes,
      System.CPU, System.CPU.MMX, System.Intrinsics,
      System.CharSet, System.Character, System.GetOpts,
      System.FPWideString,
      WinApi.WinSysUt, WinApi.ShareMem, fpintres, WinApi.WinDirs;
{$ELSE FPC_DOTTEDUNITS}
  uses
      sysinitpas, sysinitcyg, sysinitgprof,
      heaptrc,
      ctypes, strings,
      windows,  initc, cmem, dynlibs, signals,
      dos, messages,
      rtlconsts, sysconst, sysutils, math, types,
      typinfo, classes,
      cpu, mmx, intrinsics,
      charset, character, getopts,
      fpwidestring,
      winsysut, sharemem, fpintres, windirs;
{$ENDIF FPC_DOTTEDUNITS}
  implementation

end.
