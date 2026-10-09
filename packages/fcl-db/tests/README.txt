This directory contains the retained standalone FCL database tests.

testsqlscanner.lpr and testsqlscanner_gui.lpr run the SQL scanner, parser,
and SQL generation tests in tcsqlscanner.pas, tcparser.pas, and tcgensql.pas.
testsqlfiles.lpr checks SQL source files.
testjsondataset.pp exercises the JSON dataset.
testsqlscript.pas and testdddiff.pp contain independent FPCUnit test suites.

toolsunit.pas and dbftoolsunit.pas are retained because the compiler
regression tests in tests/test/packages/fcl-db use them.
