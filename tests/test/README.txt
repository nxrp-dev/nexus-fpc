This directory contains tests for several parts of the compiler and RTL


--------------------------------------------------------------------
                      Code generator
--------------------------------------------------------------------
These tests should be considered unitary, as they only verify
simple cases of the code generator. Used for porting to other
architectures. Tries to validate all possible Location types
valid for that node. They are based on tests on these
reference platforms:
  Borland Pascal v7.01
  Delphi 3.0
  Delphi 4.0
  Delphi 6.0 Personal Edition

'Natural type' is a signed 32-bit value on 32-bit architectures.
'Natural type' is a signed 64-bit value on 64-bit architectures.


--------------------------------------------------------------------
                        Compiler
--------------------------------------------------------------------


Shortstrings .......... tb_strings_fpc_consolidated_01.pas [case tstring1]    compatibility and speed of shortstrings
                        tstring2.pas    some misc. tests mainly collected
                                       from bug reports
                        tstring3.pas    Typed Constant string loading from
                                       other constants
                        tstring4.pas    Ansistring #1
                        tstring5.pas    Ansistring #2
Classes ............... tb_classes_objfpc_consolidated_02.pas [case tclass1]     AfterConstruction
                        tb_classes_objfpc_consolidated_02.pas [case tclass2]     BeforeDestruction
Objects ............... tobject1.pas    Fail in constructor
Exceptions ............ texception1.pas
                        texception2.pas
                        texception3.pas
                        texception4.pas Math exceptions
Procedure Variable .... tprocvar1.pas
                        tprocvar2.pas
Libraries ............. testlib.pas     a very primitive test
Parameter passing ..... cg/tb_integers_fpc_consolidated_01.pas [case tpara1]      Out Parameter

Units ................. testu1.pas      tests init. & finalization and halt
                        testu2.pas      in finalization
                        testu3.pas      a type redefining problem
                        testu4.pas
                        testu5.pas
case .................. tb_integers_fpc_consolidated_01.pas [case tcase1]      tests case statements with byte and word
                                       sized decision variables
                        tb_enumerations_fpc_consolidated_01.pas [case tcase2]      tests case with sub enum types
Arrays ................ tb_classes_objfpc_consolidated_02.pas [case tarray1]     open arrays with classes
                        tarray2.pas     Array of const
                        tb_strings_fpc_consolidated_01.pas [case tarray3]     Array of Char #1 (Known bug)
                        tarray4.pas     Array of Char #2 (Known bug)
Enumerations .......... tb_enumerations_fpc_consolidated_01.pas [case tenum1]      tests assignments of subrange
                                       enumerations
Codegenerration ....... tcg1.pas        i386 pushw
                        tcg2.pas        saveregisters
                        tb_integers_fpc_consolidated_01.pas [case tinivar]     initial values for local variables (1.1)
Inline ................ tb_integers_fpc_consolidated_01.pas [case tinline1]    tests recursive inlining, inlining
                                       a procedure multiple times and
                                       inlining procedures in other
                                       inline procedures.
                        tb_integers_fpc_consolidated_01.pas [case tinlin64]    tests for a problem in pushing 64bit parameters
                                       by value.
TypeInfo .............. tb_integers_fpc_consolidated_01.pas [case trtti2]      test the function system.typeinfo
                        tb_strings_delphi_consolidated_01.pas [case trtti3]      tests the procedure system.finalize
Resourcestrings ....... tresstr.pas     tests a simple resource string
Range checking ........ trange1.pas     range checking when converting int64/
                                       qword to longint/cardinal
                        ../tbs/tb_integers_objfpc_consolidated_05.pas [case trange2]     range checking when converting
                                       between longint and cardinal
                        trange3.pas     range checking for array
                        tb_integers_fpc_consolidated_01.pas [case trange4]     range checking when assigning
                                       values to int64/qword
Floating Point ........ tfpu1.pas
                        tfpu2.pas
Assembler readers...... tasmread.pas    tests for support of unit or program specifier
                        testmovd.pas    testspecial issues about MOVD instruction
Variants............... tvariant.pas    tests the variant support of FPC
                        tasout.pas      tests a problem if a unit is compiled with nasm

Code Page strings       tpcstr1.pas     tests the new codepage string type introduced
                         ...           in the 'cpstrnew' branch.
                        tcpstrXX.pas

--------------------------------------------------------------------
                            RTL
--------------------------------------------------------------------

SYSTEM
------
str/write(real_type) .. tb_floating_point_fpc_consolidated_01.pas [case tstrreal1]   test correct rounding
                        tb_floating_point_fpc_consolidated_01.pas [case tstrreal2]   test correct writing of 10 till 1e-24
Heap .................. theap.pas       Heap manager test
input/output .......... /units/system/tiorte.pas   tests inoutres values of invalid operations
Random ................ /units/system/trandom.pas  tests random (interactive)

DOS
---
General .............. /units/dos/tdos.pas         (interactive)
General .............. /units/dos/testdos.pas     (interactive)
FExpand .............. /units/dos/tfexpand.pas

CRT
---
General .............. /units/crt/tcrt.pas          tests most crt unit functions (interactive)
