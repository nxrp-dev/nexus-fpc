Windows Dialog Resource Demo
============================

This test compiles DIALOG and DIALOGEX resources through the compiler's
Clang and LLVM RC pipeline. Both tools must be in the LLVM toolchain path.

1. Compile the test program with the matching Nexus compiler and RTL:

   fpc windlgtest.lpr

   The {$R testdlg.rc} directive compiles the script and LLD embeds the RES.
   Use -FC<llvm-rc-path> and --resource-clang=<clang-path> for explicit tools.

2. Run windlgtest.exe

   If all went well, it will show two dialogs in sequence:

   - Dialog 100: A DIALOG with labels, text fields, checkbox, groupbox
                 and OK/Cancel buttons
   - Dialog 200: A DIALOGEX with centered text and a Close button

   Each dialog closes when you press OK/Cancel/Close.

Style values used:

The STYLE value 0x10C80080 is:
  WS_VISIBLE     (0x10000000)
  WS_CAPTION     (0x00C00000)  = WS_BORDER | WS_DLGFRAME
  WS_SYSMENU     (0x00080000)
  DS_SETFONT     (0x00000040)
  DS_MODALFRAME  (0x00000080)

EDITTEXT 105 style 0x500100A0 is:
  WS_CHILD       (0x40000000)
  WS_VISIBLE     (0x10000000)
  WS_TABSTOP     (0x00010000)
  ES_PASSWORD    (0x00000020)
  ES_AUTOHSCROLL (0x00000080)
