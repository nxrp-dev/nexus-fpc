{ Sets regression cases; original case IDs are retained below. }

{ Case tw11255.pp }
{$push}
{$mode objfpc}{$h+}

type
  tw11255_tlclplatform = (
    lpCarbon
    );

  tw11255_tlclplatforms = set of tw11255_tlclplatform;

var
  tw11255_widgetsets: tw11255_tlclplatforms;

function tw11255_dirnametolclplatform: tw11255_tlclplatform;
begin
  Result:=lpCarbon;
end;
{$pop}

{ Case tw23912.pp }
{$push}
{$mode objfpc}{$H+}

//uses

type
  tw23912_tsyncommenttype = (sctAnsi, sctBor, sctSlash);
  tw23912_tsyncommentindentflag = (
    // * For Matching lines (FCommentMode)
      // By default indent is the same as for none comment lines (none overrides sciAlignOpen)
      sciNone,      // Does not Indent comment lines (Prefix may contain a fixed indent)
      sciAlignOpen, // Indent to real opening pos on first line, if comment does not start at BOL "Foo(); (*"
      sciAddTokenLen,        // add 1 or 2 spaces to indent (for the length of the token)
      sciAddPastTokenIndent, // Adds any indent found past the opening token  "(*", "{" or "//".
      sciMatchOnlyTokenLen,        // Apply the Above only if first line matches. (Only if sciAddTokenLen is specified)
      sciMatchOnlyPastTokenIndent,
      sciAlignOnlyTokenLen,        // Apply the Above only if sciAlignOpen was used (include via max)
      sciAlignOnlyPastTokenIndent,
      sciApplyIndentForNoMatch  // Apply above rules For NONE Matching lines (FCommentMode),
                                // includes FIndentFirstLineExtra
    );
  tw23912_tsyncommentindentflags = set of tw23912_tsyncommentindentflag;
  tw23912_tsyncommentcontinemode = (
      sccNoPrefix,      // May still do indent, if matched
      sccPrefixAlways,  // If the pattern did not match all will be done, except the indent AFTER the prefix (can not be detected)
      sccPrefixMatch
    );
  tw23912_tsyncommentmatchmode = (
      scmMatchAfterOpening, // will not include (*,{,//. The ^ will match the first char after
      scmMatchOpening,      // will include (*,{,//. The ^ will match the ({/
      scmMatchWholeLine,    // Match the entire line
      scmMatchAtAsterisk    // AnsiComment only, will match the * of (*, but not the (
    );
  tw23912_tsyncommentmatchline = (
      sclMatchFirst, // Match the first line of the comment to get substitutes for Prefix ($1)
      sclMatchPrev   // Match the previous line of the comment to get substitutes for Prefix ($1)
    );
  tw23912_tsynbeautifierindenttype = (sbitSpace, sbitCopySpaceTab, sbitPositionCaret);
  tw23912_tsyncommentextendmode = (
      sceNever,                // Never Extend
      sceAlways,               // Always
      sceSplitLine,            // If the line was split (caret was not at EOL, when enter was pressed
      sceMatching,             // If the line matched (even if sccPrefixAlways or sccNoPrefix
      sceMatchingSplitLine
    );

function tw23912_dbgs(AIndentFlag: tw23912_tsyncommentindentflag): String;
begin
  Result := ''; WriteStr(Result, AIndentFlag);
end;

function tw23912_dbgs(AIndentFlags: tw23912_tsyncommentindentflags): String;
var
  tw23912_i: tw23912_tsyncommentindentflag;
begin
  Result := '';
  for tw23912_i := low(tw23912_tsyncommentindentflag) to high(tw23912_tsyncommentindentflag) do
    if tw23912_i in AIndentFlags then
      if Result = ''
      then Result := tw23912_dbgs(tw23912_i)
      else Result := Result + ',' + tw23912_dbgs(tw23912_i);
  if Result <> '' then
    Result := '[' + Result + ']';
end;

procedure tw23912_foo(Atype: tw23912_tsyncommenttype;
    tw23912_aindentmode: tw23912_tsyncommentindentflags;
    tw23912_aindentfirstlinemax:   Integer; tw23912_aindentfirstlineextra: String;
    tw23912_acommentmode: tw23912_tsyncommentcontinemode; tw23912_amatchmode: tw23912_tsyncommentmatchmode;
    tw23912_amatchline: tw23912_tsyncommentmatchline; tw23912_acommentindent: tw23912_tsynbeautifierindenttype;
    tw23912_amatch: String;  tw23912_aprefix: String;
    tw23912_aextenbslash: tw23912_tsyncommentextendmode = sceNever);
var
  tw23912_s: String;
begin
    writestr(tw23912_s, AType,':',
             ' IMode=', tw23912_dbgs(tw23912_aindentmode), ' IMax=', tw23912_aindentfirstlinemax, ' IExtra=', tw23912_aindentfirstlineextra,
             ' CMode=', tw23912_acommentmode, ' CMatch=', tw23912_amatchmode, ' CLine=', tw23912_amatchline,
             ' M=''', tw23912_amatch, ''' R=''', tw23912_aprefix, ''' CIndent=', tw23912_acommentindent
            );
    if tw23912_s<>'sctAnsi: IMode=[sciAddTokenLen] IMax=5 IExtra=   CMode=sccPrefixMatch CMatch=scmMatchOpening CLine=sclMatchPrev M=''.'' R=''+'' CIndent=sbitCopySpaceTab' then
      halt(1);
end;
{$pop}

begin
  { Case tw11255.pp }
  {$push}

  begin
tw11255_widgetsets := [tw11255_dirnametolclplatform];
  if tw11255_widgetsets<>[lpcarbon] then
    halt(1);
  end;
  {$pop}

  { Case tw23912.pp }
  {$push}

  begin
tw23912_foo(sctAnsi, [sciAddTokenLen], 5, '  ', sccPrefixMatch, scmMatchOpening,
      sclMatchPrev, sbitCopySpaceTab, '.', '+');
  end;
  {$pop}

end.
