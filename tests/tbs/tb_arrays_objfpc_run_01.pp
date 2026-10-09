{ Arrays regression cases; original case IDs are retained below. }

{ Case tb0340.pp }
{$push}
{$mode objfpc}
var
  tb0340_v : tvarrec;
  tb0340_error : boolean;
procedure tb0340_p(a:array of const);
var
  tb0340_i : integer;
begin
  for tb0340_i:=low(a) to high(a) do
   with a[tb0340_i] do
    begin
      case vtype of
        vtInteger :
          begin
            writeln('Integer: ',VInteger);
            if VInteger=1000 then
             tb0340_error:=false;
          end;
        else
          writeln('Error!');
      end;
    end;
end;
{$pop}

{ Case tb0394.pp }
{$push}
{$ifdef fpc}{$mode objfpc}{$endif}

var
  tb0394_err : boolean;
procedure tb0394_demo(x:array of longint);
 var
  tb0394_i:longint;
 begin
   if high(x)<>4 then
    tb0394_err:=true
   else if x[4]<>14 then
    tb0394_err:=true;
  for tb0394_i:=low(x)to high(x)do
   writeln(tb0394_i,' ',x[tb0394_i]);
 end;
var
 tb0394_y:array[10..40]of longint;
 tb0394_i:longint;
{$pop}

{ Case tb0402.pp }
{$push}
{$mode objfpc}
type
   tb0402_ta = array of longint;

procedure tb0402_p(i : iunknown;tb0402_a : tb0402_ta = nil);

  begin
  end;

var
   tb0402_o : tinterfacedobject;
{$pop}

{ Case tb0436.pp }
{$push}
{$mode objfpc}

procedure tb0436_pext(a:array of extended);
begin
end;

procedure tb0436_p(a:array of const);
begin
end;
{$pop}

{ Case tb0438.pp }
{$push}
{$ifdef fpc}{$mode objfpc}{$endif}

procedure tb0438_p(tb0438_a : array of const);
  var
    tb0438_i : integer;
  begin
    for tb0438_i:=low(tb0438_a) to high(tb0438_a) do
     begin
       write(tb0438_i,': ');
       if (tb0438_a[tb0438_i].vtype=vtpchar) then
        begin
          writeln('"',tb0438_a[tb0438_i].vpchar,'"');
          if (tb0438_a[tb0438_i].vpchar<>'test') then
           begin
             writeln('Wrong string content');
             halt(1);
           end;
        end
       else
        begin
          writeln('No string type (',tb0438_a[tb0438_i].vtype,')');
          halt(1);
        end;
     end;
  end;

var
   tb0438_a : array[0..25] of char;
{$pop}

{ Case tb0581.pp }
{$push}
{$mode objfpc}

procedure tb0581_dirtystack;
var
  tb0581_s: shortstring;
begin
  fillchar(tb0581_s,sizeof(tb0581_s),255);
end;

procedure tb0581_test(const arr: array of const);
begin
  if arr[0].vinteger<>ord('$') then
    halt(1);
end;

procedure tb0581_doit;
begin
  tb0581_test(['$']);
end;
{$pop}

{ Case tw1351.pp }
{$push}
{$mode objfpc}

procedure tw1351_test(ParArr :array of const);
begin
   writeln(ParArr[0].vtype,' ',vtObject,' ',vtclass);
   if ParArr[0].vtype<>vtObject then
    halt(1);
end;
{$pop}

{ Case tw2159.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2159 }
{ Submitted by "Yakov Sudeikin" on  2002-10-03 }
{ e-mail: yashka@exebook.com }
{$ifdef fpc}{$mode objfpc}{$endif}

var
 tw2159_a,tw2159_b,tw2159_c: array of string;
{$pop}

{ Case tw24410.pp }
{$push}
{$mode objfpc}

procedure tw24410_xx(var s:shortstring);
var tw24410_dirbuf:array[0..1321] of widechar;
begin
  s:=tw24410_dirbuf;
end;
{$pop}

{ Case tw29250.pp }
{$push}
{$mode objfpc}

function tw29250_comparearr(const tw29250_a,tw29250_b: array of byte; tw29250_len: integer): Boolean;
var
  tw29250_i : integer;
begin
  for tw29250_i:=0 to tw29250_len-1 do
    if tw29250_a[tw29250_i]<>tw29250_b[tw29250_i] then begin
      Result:=false;
      Exit;
    end;
  Result:=true;
end;

procedure tw29250_printarr(const tw29250_a: array of byte);
var
  tw29250_i : integer;
begin
  for tw29250_i:=0 to length(tw29250_a)-1 do write(tw29250_a[tw29250_i],' ');
  writeln;
end;

const
  tw29250_size_cnt = 8;
  tw29250_size_inc = 20;
  tw29250_size_dec = 4;

var
  tw29250_a: array of byte;
  tw29250_b: array of byte;
  tw29250_i: integer;
  tw29250_r: integer;
{$pop}

{ Case tw32645.pp }
{$push}
{$mode objfpc}

var tw32645_myarray : array ['a'..'z'] of integer; //operator is not overloaded 'char' - 'char'
//var myarray : array ['a'..'zz'] of integer; //signal 291
//var myarray : array ['a'..'z'*5] of integer; //signal 291

procedure tw32645_myproc (tw32645_myarray: array of integer);
begin
  if high(tw32645_myarray)<>25 then
    halt(1);
end;
{$pop}

{ Case tw34055.pp }
{$push}
{$mode objfpc}

 type
  tw34055_tdos_fieldnames = (
                      Dos_Signature, // ord = 0
                      Dos_OffsetToNewExecutable // ord = 1
                    );

const
  tw34055_dosfieldlabelsb : array[tw34055_tdos_fieldnames]
                        of pwidechar =
  (
    'DOS signature',
    'offset to new executable'
  );

  tw34055_d : ppwidechar = @tw34055_dosfieldlabelsb[Dos_OffsetToNewExecutable];
{$pop}

begin
  { Case tb0340.pp }
  {$push}

  begin
tb0340_error:=true;
  tb0340_v.vtype:=vtInteger;
  tb0340_v.VInteger:=1000;
  tb0340_p(tb0340_v);
  if tb0340_error then
   Halt(1);
  end;
  {$pop}

  { Case tb0394.pp }
  {$push}
{$ifdef fpc}
{$endif}
  begin
for tb0394_i:=10 to 40 do
  tb0394_y[tb0394_i]:=tb0394_i;
 tb0394_demo(slice(tb0394_y,5));
 if tb0394_err then
  begin
    writeln('ERROR!');
    halt(1);
  end;
  end;
  {$pop}

  { Case tb0402.pp }
  {$push}

  begin
tb0402_p(tb0402_o);
  end;
  {$pop}

  { Case tb0436.pp }
  {$push}

  begin
tb0436_p([0.0]);
  tb0436_p([pi]);
  tb0436_pext([0.0]);
  end;
  {$pop}

  { Case tb0438.pp }
  {$push}
{$ifdef fpc}
{$endif}
  begin
tb0438_a:='test';
   tb0438_p([tb0438_a,tb0438_a]);
  end;
  {$pop}

  { Case tb0581.pp }
  {$push}

  begin
tb0581_dirtystack;
  tb0581_doit;
  end;
  {$pop}

  { Case tw1351.pp }
  {$push}

  begin
tw1351_test([TObject.Create]);
  end;
  {$pop}

  { Case tw2159.pp }
  {$push}
{$ifdef fpc}
{$endif}
  begin
setlength(tw2159_a, 2);
 tw2159_a[0] := 'asd';
 tw2159_a[1] := 'qwe';
 tw2159_b := copy(tw2159_a);
 tw2159_c := copy(tw2159_a, 1, 1);
 if tw2159_b[0]<>'asd' then
  begin
    writeln('Error 1');
    halt(1);
  end;
 if tw2159_b[1]<>'qwe' then
  begin
    writeln('Error 2');
    halt(1);
  end;
 if tw2159_c[0]<>'qwe' then
  begin
    writeln('Error 3');
    halt(1);
  end;
  end;
  {$pop}

  { Case tw29250.pp }
  {$push}

  begin
SetLength(tw29250_a, tw29250_size_cnt);
  for tw29250_i:=0 to length(tw29250_a)-1 do tw29250_a[tw29250_i]:=$F0+tw29250_i;

  // test decrease size
  // match, by less size
  tw29250_b:=tw29250_a;
  SetLength(tw29250_b, tw29250_size_dec);
  if not tw29250_comparearr(tw29250_a,tw29250_b,length(tw29250_b))  then
    halt(1);

  // test same size/copy
  // full match
  tw29250_b:=tw29250_a;
  SetLength(tw29250_b, length(tw29250_b));
  if not tw29250_comparearr(tw29250_a,tw29250_b,length(tw29250_b)) then
    halt(1);

  // test increase size
  // first part must match, last part must be zero
  tw29250_b:=tw29250_a;
  SetLength(tw29250_b, tw29250_size_inc);
  if not tw29250_comparearr(tw29250_a,tw29250_b,length(tw29250_a)) then
    halt(1);
  tw29250_r:=1;
  for tw29250_i:=length(tw29250_a) to length(tw29250_b)-1 do
    if tw29250_b[tw29250_i]<>0 then begin tw29250_r:=0; halt(1) end;
  writeln('ok');
  end;
  {$pop}

  { Case tw32645.pp }
  {$push}

  begin
tw32645_myproc(tw32645_myarray);
  end;
  {$pop}

  { Case tw34055.pp }
  {$push}

  begin
if tw34055_d<>@tw34055_dosfieldlabelsb[Dos_OffsetToNewExecutable] then
    halt(1);
  end;
  {$pop}

end.
