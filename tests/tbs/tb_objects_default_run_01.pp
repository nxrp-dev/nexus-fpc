{ Objects regression cases; original case IDs are retained below. }

{ Case tb0025.pp }
{$push}
{ Old file: tbs0029.pp }
{  tests typeof(object type)                         OK 0.99.1 (FK) }

type
  tb0025_ta = object
    constructor tb0025_init;
    procedure tb0025_test;virtual;
  end;

  constructor tb0025_ta.tb0025_init;
    begin
    end;

  procedure tb0025_ta.tb0025_test;
    begin
    end;

var
   tb0025_p: Pointer;
{$pop}

{ Case tb0067.pp }
{$push}
{ Old file: tbs0074.pp }
{  shows MAJOR bugs when trying to compile valid code    OK 0.99.1 (PM/CEC) }

type
  tb0067_tmyobject = object
    constructor tb0067_init;
    procedure tb0067_callit; virtual;
    destructor tb0067_done; virtual;
  end;

  constructor tb0067_tmyobject.tb0067_init;
  Begin
  end;

  destructor tb0067_tmyobject.tb0067_done;
  Begin
  end;

  procedure tb0067_tmyobject.tb0067_callit;
  Begin
   WriteLn('Hello...');
  end;

  var
   tb0067_obj: tb0067_tmyobject;
{$pop}

{ Case tb0083.pp }
{$push}
{ Old file: tbs0096.pp }
{ problem with objects as parameters                    OK 0.99.6 (PM) }

type
   tb0083_tparent = object
   end;

   tb0083_pparent = ^tb0083_tparent;

   tb0083_tchild = object(tb0083_tparent)
   end;

procedure tb0083_aproc(const x : tb0083_tparent );
begin
end;

procedure tb0083_anotherproc(var x : tb0083_tparent );
begin
end;

var
   tb0083_y : tb0083_tchild;
{$pop}

{ Case tb0091.pp }
{$push}
{ Old file: tbs0107.pp }
{ shows page fault problem (run in TRUE DOS mode)       OK ??.?? }

{ PAGE FAULT PROBLEM ... TEST UNDER DOS ONLY! Not windows... }
{ -Cr -g flags                                               }

type
 tb0091_myobject = object
   constructor tb0091_init;
   procedure tb0091_v;virtual;
 end;

 constructor tb0091_myobject.tb0091_init;
 Begin
 end;

 procedure tb0091_myobject.tb0091_v;
 Begin
  WriteLn('Hello....');
 end;

var
 tb0091_my: tb0091_myobject;
{$pop}

{ Case tb0100.pp }
{$push}
{ Old file: tbs0119.pp }
{ problem with methods                                  OK 0.99.6 (FK) }

   type
     tb0100_objecta = object
       procedure tb0100_greetings;
       procedure tb0100_doit;
     end;
     tb0100_objectb = object (tb0100_objecta)
       procedure tb0100_greetings;
       procedure tb0100_doit;
     end;

   procedure tb0100_objecta.tb0100_greetings;
   begin
     writeln('  A');
   end;
   procedure tb0100_objecta.tb0100_doit;
   begin
     writeln('A ');
     tb0100_greetings;
   end;

   procedure tb0100_objectb.tb0100_greetings;
   begin
     writeln('  B');
   end;
   procedure tb0100_objectb.tb0100_doit;
   begin
     writeln('B');
     tb0100_greetings;
   end;

   var
     tb0100_a: tb0100_objecta;
     tb0100_b: tb0100_objectb;
{$pop}

{ Case tb0117.pp }
{$push}
{ Old file: tbs0137.pp }
{ Cannot assign child object variable to parent objcet type variable OK 0.99.6 }

Type tb0117_tvater = Object
                Constructor tb0117_init;
                Procedure tb0117_gehen; Virtual;
                Procedure tb0117_laufen; Virtual;
              End;

     tb0117_tsohn = Object(tb0117_tvater)
               Procedure tb0117_gehen; Virtual;
             End;

Var tb0117_v : tb0117_tvater;
    tb0117_s : tb0117_tsohn;

Constructor tb0117_tvater.tb0117_init;
Begin
End;

Procedure tb0117_tvater.tb0117_gehen;
Begin
  Writeln('langsam gehen');
End;

Procedure tb0117_tvater.tb0117_laufen;
Begin
  tb0117_gehen;
  tb0117_gehen;
End;

Procedure tb0117_tsohn.tb0117_gehen;
Begin
  Writeln('schnell gehen');
End;
{$pop}

{ Case tb0123.pp }
{$push}
{ Old file: tbs0142.pp }
{ sizeof(object) is not tp7 compatible when no constructor is used OK 0.99.9 (PM) }

{$PACKRECORDS 1}

type
tb0123_time = object
  tb0123_h,tb0123_m,tb0123_s:byte;
end;

var tb0123_ot:tb0123_time;
 tb0123_l : longint;
{$pop}

{ Case tb0135.pp }
{$push}
{ Old file: tbs0159.pp }
{ Invalid virtual functions - should compile            OK 0.99.7 (FK) }

Type tb0135_tparent = Object
       Procedure tb0135_someproc;
       end;

     tb0135_tchild = Object(tb0135_tparent)
       Procedure tb0135_someproc; virtual;
       end;

       Procedure tb0135_tparent.tb0135_someproc;
       Begin
       end;

      procedure tb0135_tchild.tb0135_someproc;
      Begin
      end;
{$pop}

{ Case tb0181.pp }
{$push}
{ Old file: tbs0214.pp }
{ bugs for static methods                               OK 0.99.11 (PM) }

{ Note: I've cut a lot out of this program, it did originally have
        constructors, destructors and instanced objects, but this
        is the minimum required to produce the problem, and I think
        that this should work, unless I've misunderstood the use of
        the static keyword. }
Type
   tb0181_tobjecttype1 = Object
      Procedure tb0181_setup; static;
      Procedure tb0181_weird; static;
   End;

Procedure tb0181_tobjecttype1.tb0181_setup;
   Begin
   End;

Procedure tb0181_tobjecttype1.tb0181_weird;
   Begin
   End;
{$pop}

{ Case tb0182.pp }
{$push}
{ Old file: tbs0215.pp }
{ more bugs with static methods                        OK 0.99.11 (PM) }

{ allow static keyword }
{ submitted by Andrew Wilson }

Type
   tb0182_py=^tb0182_y;
   tb0182_y=Object
      tb0182_a : LongInt;
      tb0182_p : tb0182_py; static;
      Constructor tb0182_init(NewA:LongInt);
      Procedure tb0182_staticmethod; static;
      Procedure tb0182_virtualmethod; virtual;
   End;

Constructor tb0182_y.tb0182_init(NewA:LongInt);
   Begin
      tb0182_a:=NewA;
      tb0182_p:=@self;
   End;

Procedure tb0182_y.tb0182_staticmethod;
   Begin
      Writeln(tb0182_p^.tb0182_a);    // Compiler complains about using A.
      tb0182_p^.tb0182_virtualmethod; // Same with the virtual method.
      With tb0182_p^ do begin
         Writeln(tb0182_a);    // These two seem to compile, but I
         tb0182_virtualmethod; // can't get them to work. It seems to
      End;              // be the same problem as last time, so
   End;                 // I'll check it again when I get the
                        // new snapshot.
Procedure tb0182_y.tb0182_virtualmethod;
   Begin
      Writeln('VirtualMethod ',tb0182_a);
   End;

var tb0182_t1,tb0182_t2 :  tb0182_py;
{$pop}

{ Case tb0221.pp }
{$push}
{ Old file: tbs0260.pp }
{ problem with VMT generation if non virtual method has a virtual overload                        OK 0.99.12 (PM) }

  type
      tb0221_obj1 = object
        tb0221_st : string;
      constructor tb0221_init;
      procedure tb0221_writeit;
      end;

      tb0221_obj2 = object(tb0221_obj1)
      procedure tb0221_writeit;virtual;
      end;

      tb0221_obj3 = object(tb0221_obj2)
        tb0221_l : longint;
      end;

      constructor tb0221_obj1.tb0221_init;
        begin
        end;

      procedure tb0221_obj1.tb0221_writeit;
        begin
        end;

      procedure tb0221_obj2.tb0221_writeit;
        begin
        end;
{$pop}

{ Case tb0264.pp }
{$push}
{ Old file: tbs0307.pp }
{ "with object_type" doesn't work correctly!           OK 0.99.13 (?) }

type
  tb0264_tobj = object
    tb0264_l: longint;
    constructor tb0264_init;
    procedure tb0264_setv(v: longint);
    destructor tb0264_done;
  end;

constructor tb0264_tobj.tb0264_init;
begin
  tb0264_l := 0;
end;

procedure tb0264_tobj.tb0264_setv(v: longint);
begin
  tb0264_l := v;
end;

destructor tb0264_tobj.tb0264_done;
begin
end;

var tb0264_t: tb0264_tobj;
{$pop}

begin
  { Case tb0025.pp }
  {$push}

  begin
tb0025_p := pointer(TypeOf(tb0025_ta));
  end;
  {$pop}

  { Case tb0067.pp }
  {$push}

  begin
tb0067_obj.tb0067_init;
    tb0067_obj.tb0067_callit;
{    obj.done;}
  end;
  {$pop}

  { Case tb0083.pp }
  {$push}

  begin
tb0083_aproc(tb0083_y);
      tb0083_anotherproc(tb0083_y);
  end;
  {$pop}

  { Case tb0091.pp }
  {$push}

  begin
tb0091_my.tb0091_init;
 tb0091_my.tb0091_v;
  end;
  {$pop}

  { Case tb0100.pp }
  {$push}

  begin
tb0100_a.tb0100_doit;
     tb0100_b.tb0100_doit;
     writeln; writeln('Now doing it directly:');
     tb0100_a.tb0100_greetings;
     tb0100_b.tb0100_greetings;
  end;
  {$pop}

  { Case tb0117.pp }
  {$push}

  begin
tb0117_v.tb0117_init;
  tb0117_s.tb0117_init;
  tb0117_v.tb0117_laufen;
  Writeln;
  tb0117_s.tb0117_laufen;
  Writeln;
  tb0117_v := tb0117_s;
  tb0117_v.tb0117_gehen;
  end;
  {$pop}

  { Case tb0123.pp }
  {$push}
{$PACKRECORDS 1}
  begin
tb0123_l:=SizeOf(tb0123_ot);
  end;
  {$pop}

  { Case tb0181.pp }
  {$push}

  begin
tb0181_tobjecttype1.tb0181_setup;
   tb0181_tobjecttype1.tb0181_weird;
   tb0181_tobjecttype1.tb0181_weird; // GPFs before exiting "Weird"
   Writeln('THE END.');
  end;
  {$pop}

  { Case tb0182.pp }
  {$push}

  begin
New(tb0182_t1,tb0182_init(1));
  New(tb0182_t2,tb0182_init(2));
  tb0182_t1^.tb0182_virtualmethod;
  tb0182_t2^.tb0182_virtualmethod;
  tb0182_y.tb0182_staticmethod;
  tb0182_t1^.tb0182_staticmethod;
  tb0182_t2^.tb0182_staticmethod;
  end;
  {$pop}

  { Case tb0264.pp }
  {$push}

  begin
tb0264_t.tb0264_init;
  with tb0264_t do
    tb0264_setv(5);
  writeln(tb0264_t.tb0264_l, ' (should be 5!)');
  if tb0264_t.tb0264_l<>5 then
    Halt(1);
  tb0264_t.tb0264_done;
  end;
  {$pop}

end.
