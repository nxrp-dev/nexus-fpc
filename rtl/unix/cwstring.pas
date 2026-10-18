{
    This file is part of the Free Pascal run time library.
    Copyright (c) 2005 by Florian Klaempfl,
    member of the Free Pascal development team.

    libc based wide string support

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 **********************************************************************}

{$mode objfpc}
{$h-}
{$inline on}
{$implicitexceptions off}

{$IFNDEF FPC_DOTTEDUNITS}
unit cwstring;
{$ENDIF FPC_DOTTEDUNITS}

interface

procedure SetCWidestringManager;

implementation

{$linklib c}

// Linux (and maybe glibc platforms in general), have iconv in glibc.
{$if defined(linux)}
  {$define iconv_is_in_libc}
{$endif}



{ Modern FreeBSD releases also claim to have iconv
  function inside libc, at least
  this is stated explicitly in iconv(3) man
  of FreeBSD from 10.0 release
  PM 2023-05-05 }

{$ifndef iconv_is_in_libc}
   {$linklib iconv}
 {$define useiconv}
{$endif not iconv_is_in_libc}

{$i rtldefs.inc}

{$IFDEF FPC_DOTTEDUNITS}
Uses
  UnixApi.Base,
  System.CTypes,
  UnixApi.Unix,
  UnixApi.Types,
  System.InitC,
  System.DynLibs,
  UnixApi.CP;
{$ELSE FPC_DOTTEDUNITS}
Uses
  BaseUnix,
  ctypes,
  unix,
  unixtype,
  initc,
  dynlibs,
  unixcp;
{$ENDIF FPC_DOTTEDUNITS}

Const
{$ifndef useiconv}
    libiconvname='c';  // is in libc under Linux.
    libprefix='lib';
{$else}
    {$if defined(darwin)}
      libiconvname='libiconv';
      libprefix='';
    {$else}
      libiconvname='iconv';
      libprefix='lib';
    {$endif}
{$endif}

{ helper functions from libc }
function towlower(__wc:wint_t):wint_t;cdecl;external clib name 'towlower';
function towupper(__wc:wint_t):wint_t;cdecl;external clib name 'towupper';

function wcscoll (__s1:pwchar_t; __s2:pwchar_t):cint;cdecl;external clib name 'wcscoll';
function strcoll (__s1:PAnsiChar; __s2:PAnsiChar):cint;cdecl;external clib name 'strcoll';
function setlocale(category: cint; locale: PAnsiChar): PAnsiChar; cdecl; external clib name 'setlocale';
function mbrtowc(pwc: pwchar_t; const s: PAnsiChar; n: size_t; ps: pmbstate_t): size_t; cdecl; external clib name 'mbrtowc';
function wcrtomb(s: PAnsiChar; wc: wchar_t; ps: pmbstate_t): size_t; cdecl; external clib name 'wcrtomb';
function mbrlen(const s: PAnsiChar; n: size_t; ps: pmbstate_t): size_t; cdecl; external clib name 'mbrlen';


const
{$if defined(linux)}
  __LC_CTYPE = 0;
  LC_ALL = 6;
  _NL_CTYPE_CLASS = (__LC_CTYPE shl 16);
  _NL_CTYPE_CODESET_NAME = (_NL_CTYPE_CLASS)+14;
  CODESET = _NL_CTYPE_CODESET_NAME;
{$elseif defined(darwin)}
  CODESET = 0;
  LC_ALL = 0;
{$else}
{$error lookup the value of CODESET in /usr/include/langinfo.h, and the value of LC_ALL in /usr/include/locale.h for your OS }
// and while doing it, check if iconv is in libc, and if the symbols are prefixed with iconv_ or libiconv_
{$endif}

{ unicode encoding name }
  unicode_encoding2 = 'UTF-16LE';
  unicode_encoding4 = 'UCS-4LE';

{ en_US.UTF-8 needs maximally 6 chars, UCS-4/UTF-32 needs 4   }
{ -> 10 should be enough? Should actually use MB_CUR_MAX, but }
{ that's a libc macro mapped to internal functions/variables  }
{ and thus not a stable external API on systems where libc    }
{ breaks backwards compatibility every now and then           }
  MB_CUR_MAX = 10;

{ Requests for iconvctl }
  ICONV_TRIVIALP          = 0; // int *argument
  ICONV_GET_TRANSLITERATE = 1; // int *argument
  ICONV_SET_TRANSLITERATE = 2; // const int *argument
  ICONV_GET_DISCARD_ILSEQ = 3; // int *argument
  ICONV_SET_DISCARD_ILSEQ = 4; // const int *argument
  ICONV_SET_HOOKS         = 5; // const struct iconv_hooks *argument
  ICONV_SET_FALLBACKS     = 6; // const struct iconv_fallbacks *argument

type
  piconv_t = ^iconv_t;
  iconv_t = pointer;
  nl_item = cint;

  function nl_langinfo(__item:nl_item):PAnsiChar;cdecl;external libiconvname name 'nl_langinfo';

{$if ((not (defined(bsd))) or (defined(iconv_is_in_libc))) or (defined(darwin))}
function iconv_open(__tocode:PAnsiChar; __fromcode:PAnsiChar):iconv_t;cdecl;external libiconvname name 'iconv_open';
function iconv(__cd:iconv_t; __inbuf:PPAnsiChar; __inbytesleft:psize_t; __outbuf:PPAnsiChar; __outbytesleft:psize_t):size_t;cdecl;external libiconvname name 'iconv';
function iconv_close(__cd:iconv_t):cint;cdecl;external libiconvname name 'iconv_close';
const
  iconvctlname='iconvctl';
{$else}
function iconv_open(__tocode:PAnsiChar; __fromcode:PAnsiChar):iconv_t;cdecl;external libiconvname name 'libiconv_open';
function iconv(__cd:iconv_t; __inbuf:PPAnsiChar; __inbytesleft:psize_t; __outbuf:PPAnsiChar; __outbytesleft:psize_t):size_t;cdecl;external libiconvname name 'libiconv';
function iconv_close(__cd:iconv_t):cint;cdecl;external libiconvname name 'libiconv_close';
const
  iconvctlname='libiconvctl';
{$endif}
var
  iconvctl:function(__cd:iconv_t; __request:cint; __argument:pointer):cint;cdecl;

procedure fpc_rangeerror; [external name 'FPC_RANGEERROR'];

Const
  UTF8Name : ShortString = 'UTF-8';
  TransLitname : ShortString ='//TRANSLIT';

threadvar
  iconv_ansi2wide,
  iconv_wide2ansi : iconv_t;
  { since we cache the iconv_t converters, we have to do the same
    for the DefaultSystemCodePage variable since if it changes, we
    have to re-initialize the converters too. We can't do that via
    a callback in the widestring manager because DefaultSystemCodePage
    is not a threadvar and we can't automatically change this in all
    threads }
  current_DefaultSystemCodePage: TSystemCodePage;


procedure InitThread;
var
  transliterate: cint;
{$if not(defined(darwin) and defined(cpuaarch64)) and not defined(iphonesim)}
  iconvindex: longint;
{$endif}
  iconvname, toencoding: shortstring;
begin
  current_DefaultSystemCodePage:=DefaultSystemCodePage;
{$if not(defined(darwin) and defined(cpuaarch64)) and not defined(iphonesim)}
  iconvindex:=GetCodepageData(DefaultSystemCodePage);
  if iconvindex<>-1 then
    iconvname:=UnixCpMap[iconvindex].name
  else
    { default to UTF-8 on Unix platforms }
    iconvname:=UTF8Name;
{$else}
  { Unix locale settings are ignored on iPhoneOS/iPhoneSimulator }
  iconvname:='UTF-8';
{$endif darwin arm/aarch64 or iphonesim}
  toencoding:=iconvname;
  if not assigned(iconvctl) then
    toencoding:=toencoding+TransLitName+#0
  else
    toencoding:=toencoding+#0;
  iconvname:=iconvname+#0;
  iconv_wide2ansi:=iconv_open(PAnsiChar(@toencoding[1]),unicode_encoding2);
  iconv_ansi2wide:=iconv_open(unicode_encoding2,PAnsiChar(@iconvname[1]));
  if assigned(iconvctl) and
     (iconv_wide2ansi<>iconv_t(-1)) then
  begin
    transliterate:=1;
    iconvctl(iconv_wide2ansi,ICONV_SET_TRANSLITERATE,@transliterate);
  end;
end;


procedure FiniThread;
begin
  if (iconv_wide2ansi <> iconv_t(-1)) then
    iconv_close(iconv_wide2ansi);
  if (iconv_ansi2wide <> iconv_t(-1)) then
    iconv_close(iconv_ansi2wide);
end;




function open_iconv_for_cps(cp: TSystemCodePage; const otherencoding: PAnsiChar; cp_is_from: boolean): iconv_t;
  var
    iconvindex: longint;
    toencoding: rawbytestring;
    transliterate: cint;
  begin
    { TODO: add caching (then we also don't need separate code for
      the default system page and other ones)

      -- typecasting an ansistring function result to PAnsiChar is
        unsafe normally, but these are constant strings -> no
        problem }
    open_iconv_for_cps:=iconv_t(-1);
    iconvindex:=GetCodepageData(cp);
    if iconvindex=-1 then
      exit;
    repeat
      if cp_is_from then
        open_iconv_for_cps:=iconv_open(otherencoding,PAnsiChar(UnixCpMap[iconvindex].name))
      else
      begin
        toencoding:=UnixCpMap[iconvindex].name;
        if not assigned(iconvctl) then
          toencoding:=toencoding+'//TRANSLIT';
        open_iconv_for_cps:=iconv_open(PAnsiChar(toencoding),otherencoding);
      end;
      inc(iconvindex);
    until (open_iconv_for_cps<>iconv_t(-1)) or
          (iconvindex>high(UnixCpMap)) or
          (UnixCpMap[iconvindex].cp<>cp);
    if not cp_is_from and
      (open_iconv_for_cps<>iconv_t(-1)) and
      assigned(iconvctl) then
    begin
      transliterate:=1;
      iconvctl(open_iconv_for_cps,ICONV_SET_TRANSLITERATE,@transliterate);
    end;
  end;


procedure Wide2AnsiMove(source:pwidechar; var dest:RawByteString; cp:TSystemCodePage; len:SizeInt);
  var
    outlength,
    outoffset,
    srclen,
    outleft : size_t;
    use_iconv: iconv_t;
    srcpos : pwidechar;
    destpos: PAnsiChar;
    mynil : PAnsiChar;
    my0 : size_t;
    err : longint;
    transliterate: cint;
    free_iconv: boolean;
  begin
    if (cp=DefaultSystemCodePage) then
      begin
        { update iconv converter in case the DefaultSystemCodePage has been
          changed }
        if current_DefaultSystemCodePage<>DefaultSystemCodePage then
          begin
            FiniThread;
            InitThread;
          end;
        use_iconv:=iconv_wide2ansi;
        free_iconv:=false;
      end
    else
      begin
        use_iconv:=open_iconv_for_cps(cp,unicode_encoding2,false);
        if (use_iconv<>iconv_t(-1)) and
           assigned(iconvctl) then
        begin
          transliterate:=1;
          iconvctl(use_iconv,ICONV_SET_TRANSLITERATE,@transliterate);
        end;
        free_iconv:=true;
      end;
    { unsupported encoding -> default move }
    if use_iconv=iconv_t(-1) then
      begin
        DefaultUnicode2AnsiMove(source,dest,DefaultSystemCodePage,len);
        exit;
      end;
    mynil:=nil;
    my0:=0;
    { rought estimation }
    setlength(dest,len*3);
    outlength:=len*3;
    srclen:=len*2;
    srcpos:=source;
    destpos:=PAnsiChar(dest);
    outleft:=outlength;
    while iconv(use_iconv,PPAnsiChar(@srcpos),@srclen,@destpos,@outleft)=size_t(-1) do
      begin
        err:=fpgetCerrno;
        case err of
          { last character is incomplete sequence }
          ESysEINVAL,
          { incomplete sequence in the middle }
          ESysEILSEQ:
            begin
              { skip and set to '?' }
              inc(srcpos);
              dec(srclen,2);
              destpos^:='?';
              inc(destpos);
              dec(outleft);
              { reset }
              iconv(use_iconv,@mynil,@my0,@mynil,@my0);
              if err=ESysEINVAL then
                break;
            end;
          ESysE2BIG:
            begin
              outoffset:=destpos-PAnsiChar(dest);
              { extend }
              setlength(dest,outlength+len*3);
              inc(outleft,len*3);
              inc(outlength,len*3);
              { string could have been moved }
              destpos:=PAnsiChar(dest)+outoffset;
            end;
          else
            runerror(231);
        end;
      end;
    // truncate string
    setlength(dest,length(dest)-outleft);
    SetCodePage(dest,cp,false);
    if free_iconv then
      iconv_close(use_iconv);
  end;


procedure Ansi2WideMove(source:PAnsiChar; cp:TSystemCodePage; var dest:widestring; len:SizeInt);
  var
    outlength,
    outoffset,
    outleft : size_t;
    use_iconv: iconv_t;
    srcpos,
    destpos: PAnsiChar;
    mynil : PAnsiChar;
    my0 : size_t;
    err: cint;
    iconvindex: longint;
    free_iconv: boolean;
  begin
    if (cp=DefaultSystemCodePage) then
      begin
        { update iconv converter in case the DefaultSystemCodePage has been
          changed }
        if current_DefaultSystemCodePage<>DefaultSystemCodePage then
          begin
            FiniThread;
            InitThread;
          end;
        use_iconv:=iconv_ansi2wide;
        free_iconv:=false;
        // Using Unicode RTL, we can end up here when iconv_ansi2wide is not yet initialized
        if (use_iconv=Nil) then
          begin
          DefaultAnsi2UnicodeMove(source,DefaultSystemCodePage,dest,len);
          exit;
          end;
      end
    else
      begin
        { TODO: add caching (then we also don't need separate code for
          the default system page and other ones)

          -- typecasting an ansistring function result to PAnsiChar is
            unsafe normally, but these are constant strings -> no
            problem }
        use_iconv:=open_iconv_for_cps(cp,unicode_encoding2,true);
        free_iconv:=true;
      end;
    { unsupported encoding -> default move }
    if use_iconv=iconv_t(-1) then
      begin
        DefaultAnsi2UnicodeMove(source,DefaultSystemCodePage,dest,len);
        exit;
      end;
    mynil:=nil;
    my0:=0;
    // extra space
    outlength:=len+1;
    setlength(dest,outlength);
    srcpos:=source;
    destpos:=PAnsiChar(dest);
    outleft:=outlength*2;
    while iconv(use_iconv,@srcpos,psize(@len),@destpos,@outleft)=size_t(-1) do
      begin
        err:=fpgetCerrno;
        case err of
         ESysEINVAL,
         ESysEILSEQ:
            begin
              { skip and set to '?' }
              inc(srcpos);
              dec(len);
              pwidechar(destpos)^:='?';
              inc(destpos,2);
              dec(outleft,2);
              { reset }
              iconv(use_iconv,@mynil,@my0,@mynil,@my0);
              if err=ESysEINVAL then
                break;
            end;
          ESysE2BIG:
            begin
              outoffset:=destpos-PAnsiChar(dest);
              { extend }
              setlength(dest,outlength+len);
              inc(outleft,len*2);
              inc(outlength,len);
              { string could have been moved }
              destpos:=PAnsiChar(dest)+outoffset;
            end;
          else
            runerror(231);
        end;
      end;
    // truncate string
    setlength(dest,length(dest)-outleft div 2);
    if free_iconv then
      iconv_close(use_iconv);
  end;


function LowerWideString(const s : WideString) : WideString;
  var
    i : SizeInt;
  begin
    SetLength(result,length(s));
    for i:=0 to length(s)-1 do
      pwidechar(result)[i]:=WideChar(towlower(wint_t(s[i+1])));
  end;


function UpperWideString(const s : WideString) : WideString;
  var
    i : SizeInt;
  begin
    SetLength(result,length(s));
    for i:=0 to length(s)-1 do
      pwidechar(result)[i]:=WideChar(towupper(wint_t(s[i+1])));
  end;


procedure EnsureAnsiLen(var S: AnsiString; const len: SizeInt); inline;
begin
  if (len>length(s)) then
    if (length(s) < 10*256) then
      setlength(s,length(s)+10)
    else
      setlength(s,length(s)+length(s) shr 8);
end;


procedure ConcatCharToAnsiStr(const c: AnsiChar; var S: AnsiString; var index: SizeInt);
begin
  EnsureAnsiLen(s,index);
  PAnsiChar(@s[index])^:=c;
  inc(index);
end;


{ concatenates an utf-32 Char to a ansistring. S *must* be unique when entering. }
procedure ConcatUTF32ToAnsiStr(const nc: wint_t; var S: AnsiString; var index: SizeInt; var mbstate: mbstate_t);
var
  p     : PAnsiChar;
  mblen : size_t;
begin
  { we know that s is unique -> avoid uniquestring calls}
  p:=@s[index];
  if (nc<=127) then
    ConcatCharToAnsiStr(AnsiChar(nc),s,index)
  else
    begin
      EnsureAnsiLen(s,index+MB_CUR_MAX);
      mblen:=wcrtomb(p,wchar_t(nc),@mbstate);
      if (mblen<>size_t(-1)) then
        inc(index,mblen)
      else
        begin
          { invalid wide AnsiChar }
          p^:='?';
          inc(index);
        end;
    end;
end;


function LowerAnsiString(const s : AnsiString) : AnsiString;
  var
    i, slen,
    resindex : SizeInt;
    mblen    : size_t;
    ombstate,
    nmbstate : mbstate_t;
    wc       : wchar_t;
  begin
    fillchar(ombstate,sizeof(ombstate),0);
    fillchar(nmbstate,sizeof(nmbstate),0);
    slen:=length(s);
    SetLength(result,slen+10);
    i:=1;
    resindex:=1;
    while (i<=slen) do
      begin
        if (s[i]<=#127) then
          begin
            wc:=wchar_t(s[i]);
            mblen:= 1;
          end
        else
          mblen:=mbrtowc(@wc, PAnsiChar(@s[i]), slen-i+1, @ombstate);
        case mblen of
          size_t(-2):
            begin
              { partial invalid character, copy literally }
              while (i<=slen) do
                begin
                  ConcatCharToAnsiStr(s[i],result,resindex);
                  inc(i);
                end;
            end;
          size_t(-1), 0:
            begin
              { invalid or null character }
              ConcatCharToAnsiStr(s[i],result,resindex);
              inc(i);
            end;
          else
            begin
              { a valid sequence }
              { even if mblen = 1, the lowercase version may have a }
              { different length                                     }
              { We can't do anything special if wchar_t is 16 bit... }
              ConcatUTF32ToAnsiStr(towlower(wint_t(wc)),result,resindex,nmbstate);
              inc(i,mblen);
            end;
          end;
      end;
    SetLength(result,resindex-1);
  end;


function UpperAnsiString(const s : AnsiString) : AnsiString;
  var
    i, slen,
    resindex : SizeInt;
    mblen    : size_t;
    ombstate,
    nmbstate : mbstate_t;
    wc       : wchar_t;
  begin
    fillchar(ombstate,sizeof(ombstate),0);
    fillchar(nmbstate,sizeof(nmbstate),0);
    slen:=length(s);
    SetLength(result,slen+10);
    i:=1;
    resindex:=1;
    while (i<=slen) do
      begin
        if (s[i]<=#127) then
          begin
            wc:=wchar_t(s[i]);
            mblen:= 1;
          end
        else
          mblen:=mbrtowc(@wc, PAnsiChar(@s[i]), slen-i+1, @ombstate);
        case mblen of
          size_t(-2):
            begin
              { partial invalid character, copy literally }
              while (i<=slen) do
                begin
                  ConcatCharToAnsiStr(s[i],result,resindex);
                  inc(i);
                end;
            end;
          size_t(-1), 0:
            begin
              { invalid or null character }
              ConcatCharToAnsiStr(s[i],result,resindex);
              inc(i);
            end;
          else
            begin
              { a valid sequence }
              { even if mblen = 1, the uppercase version may have a }
              { different length                                     }
              { We can't do anything special if wchar_t is 16 bit... }
              ConcatUTF32ToAnsiStr(towupper(wint_t(wc)),result,resindex,nmbstate);
              inc(i,mblen);
            end;
          end;
      end;
    SetLength(result,resindex-1);
  end;

function WideStringToUCS4StringNoNulls(const s : WideString) : UCS4String;
  var
    i, slen,
    destindex : SizeInt;
    uch       : UCS4Char;
  begin
    slen:=length(s);
    setlength(result,slen+1);
    i:=1;
    destindex:=0;
    while (i<=slen) do
      begin
        uch:=UCS4Char(s[i]);
        if (uch=0) then
          result[destindex]:=32
        else if (uch<=$d7ff) or (uch>=$e000) then
          result[destindex]:=uch
        else if (uch<=$dbff) and
          (i<slen) and
          (s[i+1]>=#$dc00) and
          (s[i+1]<=#$dfff) then
          begin
            result[destindex]:=(UCS4Char(uch-$d7c0) shl 10)+(UCS4Char(s[i+1]) xor $dc00);
            inc(i);
          end
        else { invalid surrogate pair }
          result[destindex]:=uch;
        inc(i);
        inc(destindex);
      end;
    result[destindex]:=UCS4Char(0);
    { Trimming length in this particular case is just a waste of time,
      because result will be interpreted as null-terminated and discarded
      almost immediately }
  end;


function CompareWideString(const s1, s2 : WideString; Options : TCompareOptions) : PtrInt;
  var
    hs1,hs2 : UCS4String;
    us1,us2 : WideString;

  begin
    { wcscoll interprets null chars as end-of-string -> filter out }
    if coIgnoreCase in Options then
      begin
      us1:=UpperWideString(s1);
      us2:=UpperWideString(s2);
      end
    else
      begin
      us1:=s1;
      us2:=s2;
      end;
    hs1:=WideStringToUCS4StringNoNulls(us1);
    hs2:=WideStringToUCS4StringNoNulls(us2);
    result:=wcscoll(pwchar_t(hs1),pwchar_t(hs2));
  end;



{ return value: number of code points in the string. Whenever an invalid
  code point is encountered, all characters part of this invalid code point
  are considered to form one "character" and the next character is
  considered to be the start of a new (possibly also invalid) code point }
function CharLengthPChar(const Str: PAnsiChar): PtrInt;
  var
    nextlen: ptrint;
    s: PAnsiChar;
    mbstate: mbstate_t;
  begin
    result:=0;
    s:=str;
    fillchar(mbstate,sizeof(mbstate),0);
    repeat
      nextlen:=ptrint(mbrlen(s,MB_CUR_MAX,@mbstate));
      { skip invalid/incomplete sequences }
      if (nextlen<0) then
        nextlen:=1;
      inc(result,1);
      inc(s,nextlen);
    until (nextlen=0);
  end;


function CodePointLength(const Str: PAnsiChar; maxlookahead: ptrint): PtrInt;
  var
    mbstate: mbstate_t;
  begin
    fillchar(mbstate,sizeof(mbstate),0);
    result:=ptrint(mbrlen(str,maxlookahead,@mbstate));
    { mbrlen can also return -2 for "incomplete but potentially valid character
      and data has been processed" }
    if result<0 then
      result:=-1;
  end;


function StrCompAnsiIntern(s1,s2 : PAnsiChar; len1, len2: PtrInt; canmodifys1, canmodifys2: boolean): PtrInt;
  var
    a,b: PAnsiChar;
    i: PtrInt;
  begin
    if not(canmodifys1) then
      getmem(a,len1+1)
    else
      a:=s1;
    for i:=0 to len1-1 do
      if s1[i]<>#0 then
        a[i]:=s1[i]
      else
        a[i]:=#32;
    a[len1]:=#0;

    if not(canmodifys2) then
      getmem(b,len2+1)
    else
      b:=s2;
    for i:=0 to len2-1 do
      if s2[i]<>#0 then
        b[i]:=s2[i]
      else
        b[i]:=#32;
    b[len2]:=#0;
    result:=strcoll(a,b);
    if not(canmodifys1) then
      freemem(a);
    if not(canmodifys2) then
      freemem(b);
  end;


function CompareStrAnsiString(const s1, s2: ansistring): PtrInt;
  begin
    result:=StrCompAnsiIntern(PAnsiChar(s1),PAnsiChar(s2),length(s1),length(s2),false,false);
  end;


function StrCompAnsi(s1,s2 : PAnsiChar): PtrInt;
  begin
    result:=strcoll(s1,s2);
  end;


function AnsiCompareText(const S1, S2: ansistring): PtrInt;
  var
    a, b: AnsiString;
  begin
    a:=UpperAnsistring(s1);
    b:=UpperAnsistring(s2);
    result:=StrCompAnsiIntern(PAnsiChar(a),PAnsiChar(b),length(a),length(b),true,true);
  end;


function AnsiStrIComp(S1, S2: PAnsiChar): PtrInt;
  begin
    result:=AnsiCompareText(ansistring(s1),ansistring(s2));
  end;


function AnsiStrLComp(S1, S2: PAnsiChar; MaxLen: PtrUInt): PtrInt;
  var
    a, b: PAnsiChar;
begin
  if (maxlen=0) then
    exit(0);
  if (s1[maxlen]<>#0) then
    begin
      getmem(a,maxlen+1);
      move(s1^,a^,maxlen);
      a[maxlen]:=#0;
    end
  else
    a:=s1;
  if (s2[maxlen]<>#0) then
    begin
      getmem(b,maxlen+1);
      move(s2^,b^,maxlen);
      b[maxlen]:=#0;
    end
  else
    b:=s2;
  result:=StrCompAnsiIntern(a,b,maxlen,maxlen,a<>s1,b<>s2);
  if (a<>s1) then
    freemem(a);
  if (b<>s2) then
    freemem(b);
end;


function AnsiStrLIComp(S1, S2: PAnsiChar; MaxLen: PtrUInt): PtrInt;
  var
    a, b: ansistring;
begin
  if (maxlen=0) then
    exit(0);
  setlength(a,maxlen);
  move(s1^,a[1],maxlen);
  setlength(b,maxlen);
  move(s2^,b[1],maxlen);
  result:=AnsiCompareText(a,b);
end;


procedure ansi2pchar(const s: ansistring; const orgp: PAnsiChar; out p: PAnsiChar);
var
  newlen: sizeint;
begin
  newlen:=length(s);
  if newlen>strlen(orgp) then
    fpc_rangeerror;
  p:=orgp;
  if (newlen>0) then
    move(s[1],p[0],newlen);
  p[newlen]:=#0;
end;


function AnsiStrLower(Str: PAnsiChar): PAnsiChar;
var
  temp: ansistring;
begin
  temp:=loweransistring(str);
  ansi2pchar(temp,str,result);
end;


function AnsiStrUpper(Str: PAnsiChar): PAnsiChar;
var
  temp: ansistring;
begin
  temp:=upperansistring(str);
  ansi2pchar(temp,str,result);
end;


function envvarset(const varname: PAnsiChar): boolean;
var
  varval: PAnsiChar;
begin
  varval:=fpgetenv(varname);
  result:=
    assigned(varval) and
    (varval[0]<>#0);
end;


function GetStandardCodePage(const stdcp: TStandardCodePageEnum): TSystemCodePage;
var
  langinfo: PAnsiChar;
begin
{$ifdef FPCRTL_FILESYSTEM_UTF8}
  if stdcp=scpFileSystemSingleByte then
    begin
      result:=CP_UTF8;
      exit;
    end;
{$endif}
  { if none of the relevant LC_* environment variables are set, fall back to
    UTF-8 (this happens under some versions of OS X for GUI applications, which
    otherwise get CP_ASCII) }
  if envvarset('LC_ALL') or
     envvarset('LC_CTYPE') or
     envvarset('LANG') then
    begin
      langinfo:=nl_langinfo(CODESET);
      { there's a bug in the Mac OS X 10.5 libc (based on FreeBSD's)
        that causes it to return an empty string of UTF-8 locales
        -> patch up (and in general, UTF-8 is a good default on
        Unix platforms) }
      if not assigned(langinfo) or
         (langinfo^=#0) then
        langinfo:='UTF-8';
      Result:=GetCodepageByName(ansistring(langinfo));
    end
  else
    Result:={$IFDEF FPC_DOTTEDUNITS}UnixApi.CP{$ELSE}unixcp{$ENDIF}.GetSystemCodepage;
end;

procedure SetStdIOCodePage(var T: Text); inline;
begin
  case TextRec(T).Mode of
    fmInput:TextRec(T).CodePage:=GetStandardCodePage(scpConsoleInput);
    fmOutput:TextRec(T).CodePage:=GetStandardCodePage(scpConsoleOutput);
  end;
end;

procedure SetStdIOCodePages; inline;
begin
  SetStdIOCodePage(Input);
  SetStdIOCodePage(Output);
  SetStdIOCodePage(ErrOutput);
  SetStdIOCodePage(StdOut);
  SetStdIOCodePage(StdErr);
end;

var
  OrgWideStringManager: TUnicodeStringManager;

Procedure SetCWideStringManager;
Var
  CWideStringManager : TUnicodeStringManager;
begin
  GetUnicodeStringManager(OrgWideStringManager);
  CWideStringManager:=OrgWideStringManager;
  With CWideStringManager do
    begin
      Wide2AnsiMoveProc:=@Wide2AnsiMove;
      Ansi2WideMoveProc:=@Ansi2WideMove;

      UpperWideStringProc:=@UpperWideString;
      LowerWideStringProc:=@LowerWideString;

      CompareWideStringProc:=@CompareWideString;
//      CompareTextWideStringProc:=@CompareTextWideString;

      CharLengthPCharProc:=@CharLengthPChar;
      CodePointLengthProc:=@CodePointLength;

      UpperAnsiStringProc:=@UpperAnsiString;
      LowerAnsiStringProc:=@LowerAnsiString;
      CompareStrAnsiStringProc:=@CompareStrAnsiString;
      CompareTextAnsiStringProc:=@AnsiCompareText;
      StrCompAnsiStringProc:=@StrCompAnsi;
      StrICompAnsiStringProc:=@AnsiStrIComp;
      StrLCompAnsiStringProc:=@AnsiStrLComp;
      StrLICompAnsiStringProc:=@AnsiStrLIComp;
      StrLowerAnsiStringProc:=@AnsiStrLower;
      StrUpperAnsiStringProc:=@AnsiStrUpper;
      ThreadInitProc:=@InitThread;
      ThreadFiniProc:=@FiniThread;
      { Unicode }
      Unicode2AnsiMoveProc:=@Wide2AnsiMove;
      Ansi2UnicodeMoveProc:=@Ansi2WideMove;
      UpperUnicodeStringProc:=@UpperWideString;
      LowerUnicodeStringProc:=@LowerWideString;
      CompareUnicodeStringProc:=@CompareWideString;
      { CodePage }
      GetStandardCodePageProc:=@GetStandardCodePage;
    end;
  SetUnicodeStringManager(CWideStringManager);
end;

var
  iconvlib:TLibHandle;

initialization
  SetCWideStringManager;

  { you have to call setlocale(LC_ALL,'') to initialise the langinfo stuff  }
  { with the information from the environment variables according to POSIX  }
  { (some OSes do this automatically, but e.g. Darwin and Solaris don't)    }
  setlocale(LC_ALL,'');

  { load iconv library and iconvctl function }
  iconvlib:=LoadLibrary(libprefix+libiconvname+'.'+SharedSuffix);
  if iconvlib=0 then
    iconvlib:=LoadLibrary(libprefix+libiconvname+'.'+SharedSuffix+'.6');
  if iconvlib<>0 then
    pointer(iconvctl):=GetProcAddress(iconvlib,iconvctlname);

  { set the DefaultSystemCodePage }
  DefaultSystemCodePage:=GetStandardCodePage(scpAnsi);
  DefaultFileSystemCodePage:=GetStandardCodePage(scpFileSystemSingleByte);
  DefaultRTLFileSystemCodePage:=DefaultFileSystemCodePage;

  SetStdIOCodePages;

  { init conversion tables for main program }
  InitThread;
finalization
  { fini conversion tables for main program }
  FiniThread;
  { unload iconv library }
  if iconvlib<>0 then
    FreeLibrary(iconvlib);
  { restore previous (probably default) widestring manager so that subsequent calls
    into the widestring manager won't trigger the finalized functionality }
  SetWideStringManager(OrgWideStringManager);
end.
