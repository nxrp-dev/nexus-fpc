{ Records regression cases; original case IDs are retained below. }

{ Case tb0011.pp }
{$push}
{ Old file: tbs0014.pp }
{  }

type
   tb0011_prec = ^tb0011_trec;

   tb0011_trec = record
      tb0011_p : tb0011_prec;
      tb0011_l : longint;
   end;

function tb0011_test(p1,p2 : tb0011_prec) : boolean;

  begin
     if p1^.tb0011_l=12 then
     case p1^.tb0011_l of
        123 : tb0011_test:=(tb0011_test(p1^.tb0011_p,p2^.tb0011_p) and tb0011_test(p1^.tb0011_p,p2^.tb0011_p)) or
                     (tb0011_test(p1^.tb0011_p,p2^.tb0011_p) and tb0011_test(p1^.tb0011_p,p2^.tb0011_p));
        1234 : tb0011_test:=(tb0011_test(p1^.tb0011_p,p2^.tb0011_p) and tb0011_test(p1^.tb0011_p,p2^.tb0011_p)) or
                     (tb0011_test(p1^.tb0011_p,p2^.tb0011_p) and tb0011_test(p1^.tb0011_p,p2^.tb0011_p));
     end;
  end;
{$pop}

{ Case tb0020.pp }
{$push}
{ Old file: tbs0024.pp }
{  }

type
  tb0020_charset=set of char;

  tb0020_trec=record
     tb0020_junk : array[1..32] of byte;
     tb0020_t    : tb0020_charset;
  end;

  var
     tb0020_tr    : tb0020_trec;
     tb0020_tp    : ^tb0020_trec;

  procedure tb0020_crash(const k:tb0020_charset);

    begin
       tb0020_tp^.tb0020_t:=[#7..#10]+k;
    end;
{$pop}

{ Case tb0021.pp }
{$push}
{ Old file: tbs0025.pp }
{  tests for a wrong uninit. var. warning              OK 0.9.3 }

procedure tb0021_p1;
type
  tb0021_datetime=record
    tb0021_junk : string;
end;
var
  tb0021_dt : tb0021_datetime;
begin
  fillchar(tb0021_dt,sizeof(tb0021_dt),0);
end;
{$pop}

{ Case tb0094.pp }
{$push}
{ Old file: tbs0112.pp }
{ still generates an internal error 10                  OK 0.99.1 (FK) }

type
  tb0094_textbuf=array[0..127] of char;
  tb0094_textrec=record
    tb0094_bufptr : ^tb0094_textbuf;
    tb0094_bufpos : word;
  end;

Function tb0094_readnumeric(var f:tb0094_textrec;var tb0094_s:string;tb0094_base:longint):Boolean;
{
  Read Numeric Input, if buffer is empty then return True
}
begin
  while ((tb0094_base>=10) and (f.tb0094_bufptr^[f.tb0094_bufpos] in ['0'..'9'])) or
        ((tb0094_base=16) and (f.tb0094_bufptr^[f.tb0094_bufpos] in ['A'..'F'])) or
        ((tb0094_base=2) and (f.tb0094_bufptr^[f.tb0094_bufpos] in ['0'..'1'])) do
   Begin
   End;
end;
{$pop}

{ Case tb0095.pp }
{$push}
{ Old file: tbs0113.pp }
{ point initialization problems                         OK 0.99.1 (PM/FK) }

type tb0095_precord = ^tb0095_arecord;
     tb0095_arecord = record
                     tb0095_next : tb0095_precord;
                     tb0095_a, tb0095_b, tb0095_c : integer;
               end;

const tb0095_rec1 : tb0095_arecord = (tb0095_next : nil; tb0095_a : 10; tb0095_b : 20; tb0095_c : 30);
      tb0095_rec2 : tb0095_arecord = (tb0095_next : @tb0095_rec1; tb0095_a : 20; tb0095_b : 30; tb0095_c : 40);
{$pop}

{ Case tb0139.pp }
{$push}
{ Old file: tbs0164.pp }
{ crash when using undeclared array index in with statement OK 0.99.8 (PFV) }

type tb0139_t1r = record
             tb0139_a, tb0139_b: Byte;
           end;
     tb0139_t2r = record
             tb0139_l1, tb0139_l2: Array[1..4] Of tb0139_t1r;
           end;

Var tb0139_r: tb0139_t2r;
    tb0139_counter : byte;
{$pop}

{ Case tb0167.pp }
{$push}
{ Old file: tbs0199.pp }
{ bugs in mul code                                       OK 0.99.11  (FK) }

TYPE
  tb0167_ptrec = ^tb0167_trec;
  tb0167_trec = Record
           tb0167_d : DWORD;
         END;

VAR
  tb0167_pr1, tb0167_pr2 : tb0167_ptrec;
{$pop}

{ Case tb0183.pp }
{$push}
{ Old file: tbs0216.pp }
{ problem with with fields as function args            OK 0.99.11 (PM) }

type tb0183_rec = record
         tb0183_a : Longint;
         tb0183_b : Longint;
         tb0183_c : Longint;
         tb0183_d : record
           tb0183_e : Longint;
           tb0183_f : Word;
         end;
         tb0183_g : Longint;
     end;

const tb0183_r : tb0183_rec = (
        tb0183_a : 100; tb0183_b : 200; tb0183_c : 300; tb0183_d : (tb0183_e : 20; tb0183_f : 30); tb0183_g : 10);
{$pop}

{ Case tb0258.pp }
{$push}
{ Old file: tbs0299.pp }
{ passing Array[0..1] of char by value to proc leads to problems OK 0.99.13 (PM)
passing Array[0..1] of char by value to proc leads to problems }

type
  tb0258_twochar = Array[0..1] of char;
  tb0258_empty = Record
          End;
const
  tb0258_asd : tb0258_twochar = ('a','b');

procedure tb0258_tester(i:tb0258_twochar; tb0258_a: tb0258_empty;tb0258_l : longint;var tb0258_ll : longint);
begin
  i[0]:=i[1];
  Writeln('l = ',tb0258_l,' @l = ',hexstr(longint(@tb0258_l),8),' @a = ',hexstr(longint(@tb0258_a),8));
  inc(tb0258_ll);
end;

var
  tb0258_a : tb0258_empty;
  tb0258_l,tb0258_ll : longint;
{$pop}

{ Case tb0277.pp }
{$push}
{ Old file: tbs0329.pp }
{  }

{$packrecords c}

type
     tb0277_short=smallint;
     tb0277_winbool = longbool;
     tb0277_wchar=word;
     tb0277_uint=cardinal;

     tb0277_coord = record
          tb0277_x : tb0277_short;
          tb0277_y : tb0277_short;
       end;

     tb0277_key_event_record = packed record
          tb0277_bkeydown : tb0277_winbool;
          tb0277_wrepeatcount : WORD;
          tb0277_wvirtualkeycode : WORD;
          tb0277_wvirtualscancode : WORD;
          case longint of
             0 : ( UnicodeChar : tb0277_wchar;
                   tb0277_dwcontrolkeystate : DWORD; );
             1 : ( AsciiChar : CHAR );
       end;

     tb0277_mouse_event_record = record
          tb0277_dwmouseposition : tb0277_coord;
          tb0277_dwbuttonstate : DWORD;
          tb0277_dwcontrolkeystate : DWORD;
          tb0277_dweventflags : DWORD;
       end;

     tb0277_window_buffer_size_record = record
          tb0277_dwsize : tb0277_coord;
       end;

     tb0277_menu_event_record = record
          tb0277_dwcommandid : tb0277_uint;
       end;

     tb0277_focus_event_record = record
          tb0277_bsetfocus : tb0277_winbool;
       end;

     tb0277_input_record = record
          tb0277_eventtype : WORD;
              case longint of
                 0 : ( KeyEvent : tb0277_key_event_record );
                 1 : ( MouseEvent : tb0277_mouse_event_record );
                 2 : ( WindowBufferSizeEvent : tb0277_window_buffer_size_record );
                 3 : ( MenuEvent : tb0277_menu_event_record );
                 4 : ( FocusEvent : tb0277_focus_event_record );
       end;

const
{$ifdef cpu68k}
  { GNU C only aligns at word boundaries
    for m68k cpu PM }
  tb0277_correct_size = 18;
{$else }
  tb0277_correct_size = 20;
{$endif }
{$pop}

{ Case tb0290.pp }
{$push}
{ Old file: tbs0344.pp }
{  }

var
  tb0290_r : record
        word : array[1..2] of word;
      end;
{$pop}

{ Case tb0296.pp }
{$push}
{ Old file: tbs0355.pp }
{  }

{MvdV; published in core.
    Element that is in the type zz too is not recognised as such.
    }

type tb0296_xx=(notinsubset1,insubset1,insubset2,notinsubset2);
     tb0296_zz=insubset1..insubset2;

     tb0296_ll=record
         tb0296_yy:tb0296_zz;
         end;

const tb0296_oo : array[0..1] of tb0296_ll = (
                                  (tb0296_yy:insubset1),
                                  (tb0296_yy:insubset2));
{$pop}

begin
  { Case tb0020.pp }
  {$push}

  begin
tb0020_tp:=@tb0020_tr;
     tb0020_crash([#20..#32]);
  end;
  {$pop}

  { Case tb0021.pp }
  {$push}

  begin
tb0021_p1;
  end;
  {$pop}

  { Case tb0139.pp }
  {$push}

  begin
tb0139_counter:=2;

  with tb0139_r.tb0139_l1[tb0139_counter] Do
    Inc(tb0139_a)
  end;
  {$pop}

  { Case tb0167.pp }
  {$push}

  begin
GetMem(tb0167_pr1, SizeOf(tb0167_trec));
  GetMem(tb0167_pr2, SizeOf(tb0167_trec));

  tb0167_pr1^.tb0167_d := 10;
  Move(tb0167_pr1^,tb0167_pr2^,SizeOf(tb0167_trec));
  WriteLn(tb0167_pr1^.tb0167_d:16,tb0167_pr2^.tb0167_d:16);

  tb0167_pr1^.tb0167_d := 1;
  tb0167_pr2^.tb0167_d := tb0167_pr1^.tb0167_d*2;                   { THE BUG IS HERE }
  WriteLn(tb0167_pr1^.tb0167_d:16,tb0167_pr2^.tb0167_d:16);
  if (tb0167_pr1^.tb0167_d<>1) or (tb0167_pr2^.tb0167_d<>2) then
    Halt(1);
  end;
  {$pop}

  { Case tb0183.pp }
  {$push}

  begin
with tb0183_r do begin
          Writeln('A : ', tb0183_a);
          if tb0183_a<>100 then halt(1);
          Writeln('B : ', tb0183_b);
          if tb0183_b<>200 then halt(1);
          Writeln('C : ', tb0183_c);
          if tb0183_c<>300 then halt(1);
          Writeln('D');
          with tb0183_d do begin
               Writeln('E : ', tb0183_e);
               if tb0183_e<>20 then halt(1);
               Writeln('F : ', tb0183_f);
               if tb0183_f<>30 then halt(1);
          end;
          Writeln('G : ', tb0183_g);
          if tb0183_g<>10 then halt(1);
     end;
  end;
  {$pop}

  { Case tb0258.pp }
  {$push}

  begin
tb0258_l:=6;
  tb0258_ll:=15;
  Writeln(Sizeof(tb0258_asd));
  tb0258_tester(tb0258_asd,tb0258_a,tb0258_l,tb0258_ll);
  Writeln(tb0258_asd);
  if (tb0258_ll<>16) then
    Begin
      Writeln('Error with passing value parameter of type array [1..2] of char');
      Halt(1);
    end;
  end;
  {$pop}

  { Case tb0277.pp }
  {$push}
{$packrecords c}
{$ifdef cpu68k}
{$else }
{$endif }
  begin
if sizeof(tb0277_input_record)<>tb0277_correct_size then
   begin
     writeln('Wrong packing for Packrecords C and union ',sizeof(tb0277_input_record),' instead of ',tb0277_correct_size);
     halt(1);
   end;
  end;
  {$pop}

end.
