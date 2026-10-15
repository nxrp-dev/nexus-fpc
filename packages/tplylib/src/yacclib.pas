
{$I-}

{$IFNDEF FPC_DOTTEDUNITS}
unit YaccLib;
{$ENDIF FPC_DOTTEDUNITS}

(* Yacc Library Unit for TP Yacc Version 3.0, 6-17-91 AG *)

interface

const YYMaxDepth = 1024;
  (* default stack size of parser *)

type YYSType = Integer;
  (* default value type, may be redefined in Yacc output file *)

var

YYChar   : Integer; (* current lookahead character *)
YYNErrs  : Integer; (* current number of syntax errors reported by the
                       parser *)
YYDebug  : Boolean; (* set to true to enable debugging output of parser *)

procedure yyerror ( Msg : String );
  (* error message printing routine used by the parser *)

procedure YYClearIn;
  (* delete the current lookahead token *)

procedure YYAccept;
  (* trigger accept action of the parser; yyparse accepts returning 0, as if
     it reached end of input *)

procedure YYAbort;
  (* like yyaccept, but causes parser to return with value 1, as if an
     unrecoverable syntax error had been encountered *)

procedure YYErrLab;
  (* causes error recovery to be started, as if a syntax error had been
     encountered *)

procedure YYErrOK;
  (* when in error mode, resets the parser to its normal mode of
     operation *)

(* Flags used internally by the parser routine: *)

var

YYFlag    : ( yyfnone, yyfaccept, yyfabort, yyferror );
YYErrFlag : Integer;

implementation

procedure yyerror ( Msg : String );
  begin
    WriteLn(Msg);
  end(*yyerrmsg*);

procedure YYClearIn;
  begin
    YYChar := -1;
  end(*yyclearin*);

procedure YYAccept;
  begin
    YYFlag := yyfaccept;
  end(*yyaccept*);

procedure YYAbort;
  begin
    YYFlag := yyfabort;
  end(*yyabort*);

procedure YYErrLab;
  begin
    YYFlag := yyferror;
  end(*yyerrlab*);

procedure YYErrOK;
  begin
    YYErrFlag := 0;
  end(*yyerrork*);

end(*YaccLib*).
