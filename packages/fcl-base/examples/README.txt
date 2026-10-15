This directory contains test programs for different elements/classes in
the FCL.

If you add a test give in this file a short description of what
class/function it tests, and your initials..

Names
-----
MVC : Michael Van Canneyt
SG  : Sebastian Guenther
MH  : Michael Hess
MG  : Mattias Gaertner
VS  : Vincent Snijders


File         Tests what ?
----         ------------

list.pas      TList object from unit 'classes'.  (MVC)
mstream.pas   TMemorySteam object from unit 'classes' (MVC)
fstream.pas   TFileStream object from unit 'classes' (MVC)
dparser.pas   TParser object from unit 'classes' (MVC)
stringl.pas   TStringList object from unit classes' (MVC)
thread.pas    TTHread object from unit classes (PFV)
testz.pas     T(De)Compressionstream objects from Zstream (MVC)
testz2.pas    TGZFilestream object from Zstream (MVC)
testrtf.pas   TRTFParser object from rtfpars (MVC)
cfgtest.pas   Example for using XML read/write as cfg file (SG)
xmldump.pas   xml dump program (SG)
htdump.pas    htdump dumps XL IDL definition as ObjectPascal classes (MVC)
tidea.pas     test program for IDEA encryption/decryption streams (MVC)
b64test.pas   test program for base64 encoding streams (SG)
b64test2.pas  test program for base64 encoding streams (SG)
b64enc.pas    base64-encodes StdIn to StdOut (SG)
b64dec.pas    base64-decodes StdIn to StdOut (SG)
restest.pas   test program for resourcestrings with GNU gettext. (MVC)
             (see also intl subdirectory)
istream.pas   testprogram for input/output streams.
testproc.pas  testprogram for TProcess object. Needs doecho to be compiled
             also.
socksvr.pas   Unix socket server application. Tests TUnixServer in ssockets.
isocksvr.pas  Inet socket server application. Tests TInetServer in ssockets.
dsocksvr.pas  Unix socket server application. Tests ssockets.
sockcli.pas   Unix socket client application. Tests TUnixStream in ssockets.
isockcli.pas  Inet socket server application. Tests TInetStream in ssockets.
dsockcli.pas  Dual socket server application. Tests ssockets.
sstream.pas   Tests TStringStream object.
testol.pas    Tests TObjectList in contnrs. (MVC)
testcont.pas  Tests TStack/TQueue in contnrs. (MVC)
testhres.pas  Test hostresolver in resolve (MVC)
testnres.pas  Test netresolver in resolve (MVC)
testsres.pas  Test serviceresolver in resolve (MVC)
testrhre.pas  Test reverse hostresolver in resolve (MVC)
testrnre.pas  Test reverse netresolver in resolve (MVC)
testrsre.pas  Test reverse serviceresolver in resolve (MVC)
txmlreg.pas   Test of xmlreg unit (xml-like registry) (MVC)
testreg.pas   Test of registry unit. (MVC)
tstelcmd.pas  Test of eventlog unit, command-line version.
testur.pas    Test of TURIParser class. (MVC)
testapp.pas   Test of TCustomApplication. (MVC)
testbs.pas    Test of TBufStream buffered stream (MVC)
ipcserver    Server part of SimpleIPC unit test, console app (MVC)
ipcclient    Client part of SimpleIPC unit test, console app (MVC)
testdebug    Client part of dbugintf debugging info test (MVC)
testbf.pas    Test for BlowFish encryption (MVC)
testbf2.pas    Test for BlowFish 2 encryption (MVC)
testbfs.pas   Test for BlowFish encryption/decryption stream (MVC)
testbf2s.pas   Test for BlowFish 2 encryption/decryption stream (MVC)
testzip.pas   Test for TZipper class (MVC)
poolmm1.pas   Test for pooledmm (free) (MG)
poolmm2.pas   Test for pooledmm (nonfree) (VS)
daemon.pas    Test for daemonapp (MVC)
testtimer.pas Test for TFPTimer (MVC)
testini.pas   Test/Demo for inifiles, ReadSectionValues.
condition.pas    Test/Demo for iterators in contnr.pas
csvbom.pas    Test/Demo for BOM detection in CSV document. (needs databom.txt)
testappexit.pas Test/Demo for TApplication exit code handling. (ExitCode and ExceptionExitcode)
demoio.pas    Demo for AssignStream from streamio unit.
testthreadpool  Demo for fpthreadpool unit.
demolg       TLockGuard demo.
demo_spinlock TSpinLock demo.
