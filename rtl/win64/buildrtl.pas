unit buildrtl;

interface

{$IFDEF FPC_DOTTEDUNITS}
uses
  sysinit,
  extpas,
  heaptrc,
  fpintres,
  System.CTypes, System.Strings,
  WinApi.Windows,  System.CMem, System.DynLibs,
  TP.DOS, WinApi.Messages,
  System.RtlConsts, System.SysConst, System.SysUtils, System.Math, System.Types,
  System.TypInfo, System.Classes,
  System.CharSet, System.Character, System.GetOpts,
  System.FPWideString,
  WinApi.ShareMem, System.ExeInfo, WinApi.WinDirs
  {$ifndef CPUAARCH64}, System.CPU, WinApi.Signals{$endif};
{$ELSE FPC_DOTTEDUNITS}
uses
  sysinit,
  extpas,
  heaptrc,
  fpintres,
  ctypes, strings,
  windows,  cmem, dynlibs,
  dos, messages,
  rtlconsts, sysconst, sysutils, math, types,
  typinfo, classes,
  charset, character, getopts,
  fpwidestring,
  sharemem, exeinfo,  windirs
  {$ifndef CPUAARCH64}, cpu, signals{$endif};
{$ENDIF FPC_DOTTEDUNITS}

implementation

end.
