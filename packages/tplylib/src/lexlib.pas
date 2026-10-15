
{$I-}

{$IFNDEF FPC_DOTTEDUNITS}
unit LexLib;
{$ENDIF FPC_DOTTEDUNITS}

(* Standard Lex library unit for TP Lex Version 3.0.
   2-11-91 AG *)

interface

(* The Lex library unit supplies a collection of variables and routines
   needed by the lexical analyzer routine yylex and application programs
   using Lex-generated lexical analyzers. It also provides access to the
   input/output streams used by the lexical analyzer and the text of the
   matched string, and provides some utility functions which may be used
   in actions.

   This `standard' version of the LexLib unit is used to implement lexical
   analyzers which read from and write to MS-DOS files (using standard input
   and output, by default). It is suitable for many standard applications
   for lexical analyzers, such as text conversion tools or compilers.

   However, you may create your own version of the LexLib unit, tailored to
   your target applications. In particular, you may wish to provide another
   set of I/O functions, e.g., if you want to read from or write to memory
   instead to files, or want to use different file types. *)

(* Variables:

   The variable yytext contains the current match, yyleng its length.
   The variable yyline contains the current input line, and yylineno and
   yycolno denote the current input position (line, column). These values
   are often used in giving error diagnostics (however, they will only be
   meaningful if there is no rescanning across line ends).

   The variables yyinput and yyoutput are the text files which are used
   by the lexical analyzer. By default, they are assigned to standard
   input and output, but you may change these assignments to fit your
   target application (use the Turbo Pascal standard routines assign,
   reset, and rewrite for this purpose). *)

var

YYInput, YYOutput : Text;        (* input and output file *)
YYLine            : ShortString;      (* current input line *)
YYLineNo, YYColNo : Integer;     (* current input position *)
YYText            : ShortString;      (* matched text (should be considered r/o) *)
YYLeng            : Byte         (* length of matched text *)
  absolute YYText;

(* I/O routines:

   The following routines get_char, unget_char and put_char are used to
   implement access to the input and output files. Since \n (newline) for
   Lex means line end, the I/O routines have to translate MS-DOS line ends
   (carriage-return/line-feed) into newline characters and vice versa. Input
   is buffered to allow rescanning text (via input_char).

   The input buffer holds the text of the line to be scanned. When the input
   buffer empties, a new line is obtained from the input stream. Characters
   can be returned to the input buffer by calls to unget_char. At end-of-
   file a null character is returned.

   The input routines also keep track of the input position and set the
   yyline, yylineno, yycolno variables accordingly.

   Since the rest of the Lex library only depends on these three routines
   (there are no direct references to the yyinput and yyoutput files or
   to the input buffer), you can easily replace get_char, unget_char and
   put_char by another suitable set of routines, e.g. if you want to read
   from/write to memory, etc. *)

var get_char: function  : AnsiChar;
  (* obtain one character from the input file (null character at end-of-
     file) *)

var unget_char : procedure ( C : AnsiChar );
  (* return one character to the input file to be reread in subsequent calls
     to get_char *)

var put_char: procedure ( C : AnsiChar );
  (* write one character to the output file *)

(* Utility routines: *)

procedure Echo;
  (* echoes the current match to the output stream *)

procedure YYMore;
  (* append the next match to the current one *)

procedure YYLess ( N : Integer );
  (* truncate yytext to size n and return the remaining characters to the
     input stream *)

procedure Reject;
  (* reject the current match and execute the next one *)

  (* reject does not actually cause the input to be rescanned; instead,
     internal state information is used to find the next match. Hence
     you should not try to modify the input stream or the yytext variable
     when rejecting a match. *)

procedure Return ( N : Integer );
procedure ReturnC ( C : AnsiChar );
  (* sets the return value of yylex *)

procedure Start ( State : Integer );
  (* puts the lexical analyzer in the given start state; state=0 denotes
     the default start state, other values are user-defined *)

(* yywrap:

   The yywrap function is called by yylex at end-of-file (unless you have
   specified a rule matching end-of-file). You may redefine this routine
   in your Lex program to do application-dependent processing at end of
   file. In particular, yywrap may arrange for more input and return false
   in which case the yylex routine resumes lexical analysis. *)

type
  yywrap_t = function (): Boolean;
var
  YYWrap: yywrap_t;
  (* The default yywrap routine supplied here closes input and output files
     and returns true (causing yylex to terminate). *)

(* The following are the internal data structures and routines used by the
   lexical analyzer routine yylex; they should not be used directly. *)

var

YYState    : Integer; (* current state of lexical analyzer *)
YYActChar  : AnsiChar;    (* current character *)
YYLastChar : AnsiChar;    (* last matched character (#0 if none) *)
YYRule     : Integer; (* matched rule *)
YYReject   : Boolean; (* current match rejected? *)
YYDone     : Boolean; (* yylex return value set? *)
YYRetVal   : Integer; (* yylex return value *)

procedure YYNew;
  (* starts next match; initializes state information of the lexical
     analyzer *)

procedure YYScan;
  (* gets next character from the input stream and updates yytext and
     yyactchar accordingly *)

procedure YYMark ( N : Integer );
  (* marks position for rule no. n *)

procedure YYMatch ( N : Integer );
  (* declares a match for rule number n *)

function YYFind ( var N : Integer ) : Boolean;
  (* finds the last match and the corresponding marked position and adjusts
     the matched string accordingly; returns:
     - true if a rule has been matched, false otherwise
     - n: the number of the matched rule *)

function YYDefault : Boolean;
  (* executes the default action (copy character); returns true unless
     at end-of-file *)

procedure YYClear;
  (* reinitializes state information after lexical analysis has been
     finished *)

implementation

procedure Fatal ( Msg : ShortString );
  (* writes a fatal error message and halts program *)
  begin
    WriteLn('LexLib: ', Msg);
    Halt(1);
  end(*fatal*);

(* I/O routines: *)

const NL = #10;  (* newline character *)

const MaxChars = 2048;

var

BufPtr : Integer;
Buf    : array [1..MaxChars] of AnsiChar;

function LexLibGetChar : AnsiChar;
  var I : Integer;
  begin
    if (BufPtr=0) and not EOF(YYInput) then
      begin
        ReadLn(YYInput, YYLine);
        Inc(YYLineNo); YYColNo := 1;
        Buf[1] := NL;
        for I := 1 to Length(YYLine) do
          Buf[I+1] := YYLine[Length(YYLine)-I+1];
        Inc(BufPtr, Length(YYLine)+1);
      end;
    if BufPtr>0 then
      begin
        LexLibGetChar := Buf[BufPtr];
        Dec(BufPtr);
        Inc(YYColNo);
      end
    else
      LexLibGetChar := #0;
  end(*get_char*);

procedure LexLibUngetChar ( C : AnsiChar );
  begin
    if BufPtr=MaxChars then Fatal('input buffer overflow');
    Inc(BufPtr);
    Dec(YYColNo);
    Buf[BufPtr] := C;
  end(*unget_char*);

procedure LexLibPutChar ( C : AnsiChar );
  begin
    if C=#0 then
      { ignore }
    else if C=NL then
      WriteLn(YYOutput)
    else
      Write(YYOutput, C)
  end(*put_char*);

(* Variables:

   Some state information is maintained to keep track with calls to yymore,
   yyless, reject, start and yymatch/yymark, and to initialize state
   information used by the lexical analyzer.
   - yystext: contains the initial contents of the yytext variable; this
     will be the empty string, unless yymore is called which sets yystext
     to the current yytext
   - yysstate: start state of lexical analyzer (set to 0 during
     initialization, and modified in calls to the start routine)
   - yylstate: line state information (1 if at beginning of line, 0
     otherwise)
   - yystack: stack containing matched rules; yymatches contains the number of
     matches
   - yypos: for each rule the last marked position (yymark); zeroed when rule
     has already been considered
   - yysleng: copy of the original yyleng used to restore state information
     when reject is used *)

const

MaxMatches = 1024;
MaxRules   = 256;

var

YYSText            : ShortString;
YYSState, YYLState : Integer;
YYMatches          : Integer;
YYStack            : array [1..MaxMatches] of Integer;
YYPos              : array [1..MaxRules] of Integer;
YYSLeng            : Byte;

(* Utilities: *)

procedure Echo;
  var I : Integer;
  begin
    for I := 1 to YYLeng do
      put_char(YYText[I])
  end(*echo*);

procedure YYMore;
  begin
    YYSText := YYText;
  end(*yymore*);

procedure YYLess ( N : Integer );
  var I : Integer;
  begin
    for I := YYLeng downto N+1 do
      unget_char(YYText[I]);
    YYLeng := N;
  end(*yyless*);

procedure Reject;
  var I : Integer;
  begin
    YYReject := True;
    for I := YYLeng+1 to YYSLeng do
      YYText := YYText+get_char();
    Dec(YYMatches);
  end(*reject*);

procedure Return ( N : Integer );
  begin
    YYRetVal := N;
    YYDone := True;
  end(*return*);

procedure ReturnC ( C : AnsiChar );
  begin
    YYRetVal := Ord(C);
    YYDone := True;
  end(*returnc*);

procedure Start ( State : Integer );
  begin
    YYSState := State;
  end(*start*);

(* yywrap: *)

function LexLibYYWrap : Boolean;
  begin
    Close(YYInput);
    Close(YYOutput);
    LexLibYYWrap := True;
  end(*yywrap*);

(* Internal routines: *)

procedure YYNew;
  begin
    if YYLastChar<>#0 then
      if YYLastChar=NL then
        YYLState := 1
      else
        YYLState := 0;
    YYState := YYSState+YYLState;
    YYText  := YYSText;
    YYSText := '';
    YYMatches := 0;
    YYDone := False;
  end(*yynew*);

procedure YYScan;
  begin
    if YYLeng=255 then Fatal('yytext overflow');
    YYActChar := get_char();
    Inc(YYLeng);
    YYText[YYLeng] := YYActChar;
  end(*yyscan*);

procedure YYMark ( N : Integer );
  begin
    if N>MaxRules then Fatal('too many rules');
    YYPos[N] := YYLeng;
  end(*yymark*);

procedure YYMatch ( N : Integer );
  begin
    Inc(YYMatches);
    if YYMatches>MaxMatches then Fatal('match stack overflow');
    YYStack[YYMatches] := N;
  end(*yymatch*);

function YYFind ( var N : Integer ) : Boolean;
  begin
    YYReject := False;
    while (YYMatches>0) and (YYPos[YYStack[YYMatches]]=0) do
      Dec(YYMatches);
    if YYMatches>0 then
      begin
        YYSLeng := YYLeng;
        N       := YYStack[YYMatches];
        YYLess(YYPos[N]);
        YYPos[N] := 0;
        if YYLeng>0 then
          YYLastChar := YYText[YYLeng]
        else
          YYLastChar := #0;
        YYFind := True;
      end
    else
      begin
        YYLess(0);
        YYLastChar := #0;
        YYFind := False;
      end
  end(*yyfind*);

function YYDefault : Boolean;
  begin
    YYReject := False;
    YYActChar := get_char();
    if YYActChar<>#0 then
      begin
        put_char(YYActChar);
        YYDefault := True;
      end
    else
      begin
        YYLState := 1;
        YYDefault := False;
      end;
    YYLastChar := YYActChar;
  end(*yydefault*);

procedure YYClear;
  begin
    BufPtr := 0;
    YYSState := 0;
    YYLState := 1;
    YYLastChar := #0;
    YYText := '';
    YYSText := '';
  end(*yyclear*);

begin
  YYWrap := @LexLibYYWrap;
  get_char:= @LexLibGetChar;
  unget_char:= @LexLibUngetChar;
  put_char:= @LexLibPutChar;
  Assign(YYInput, '');
  Assign(YYOutput, '');
  Reset(YYInput); Rewrite(YYOutput);
  YYLineNo := 0;
  YYClear;
end(*LexLib*).
