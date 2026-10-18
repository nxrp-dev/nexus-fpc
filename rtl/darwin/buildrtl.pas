{ This unit is only used to edit the rtl with lazarus }
unit buildrtl;

  interface

    uses
      { those units are directly build using make:
        system uuchar objpas macpas iso7185 cpall lnfodwrf
      }
      macpas, iso7185,
      fpintres, // $(SYSINIT_UNITS) \
      si_prc, si_c, si_dll,
      unixtype, ctypes, baseunix, strings, extpas, syscall, unixutil,
      heaptrc,
      termio, unix, initc, cmem,
{$ifdef CPUI386}
      mmx,
{$endif CPUI386}
      linuxvcs,
      sysutils, typinfo, math,
      charset, CPAll, character, unixcp, getopts,
      errors, dl, dynlibs,
      types, sysconst, fpwidestring,
      cthreads, sortbase, classes, rtlconsts, dos, cwstring, bsd;

  implementation

end.
