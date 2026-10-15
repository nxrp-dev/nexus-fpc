{ Consolidated objects regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}

{ Case taddr1.pas }
{$push}
{****************************************************************}
{  CODE GENERATOR TEST PROGRAM                                   }
{****************************************************************}
{ NODE TESTED : secondaddr()                                     }
{****************************************************************}
{ PRE-REQUISITES: secondload()                                   }
{                 secondassign()                                 }
{                 secondcalln()                                  }
{****************************************************************}
{ DEFINES:                                                       }
{****************************************************************}
{ REMARKS:                                                       }
{****************************************************************}


{$ifdef fpc}
  
{$endif}

   procedure taddr1_testprocvar;
     begin
       WriteLn('Hello world!');
     end;

type
  taddr1_tmyobj = object
    procedure writeit;
  end;


  procedure taddr1_tmyobj.writeit;
   begin
       WriteLn('Salutations!');
   end;


const
 taddr1_chararray : array[0..7] of char =
 ('A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
  #0
 );

var
 taddr1_procptr: procedure;
 taddr1_pcharptr : pchar;
 taddr1_plongint : ^longint;
 taddr1_long: longint;
 taddr1_ptr: codepointer;

{$pop}

{ Case tobjsiz2.pas }
{$push}

{ Variation without virtual classes : no VMT }
{ here sizeof directly returns a constant value }


type
   tobjsiz2_pbaseclass = ^tobjsiz2_tbaseclass;
   tobjsiz2_pderivedclass = ^tobjsiz2_tderivedclass;

   tobjsiz2_tbaseclass = object
     x : byte;
     function getsize : longint; static;
     procedure check_size;
   end;

   tobjsiz2_tderivedclass = object(tobjsiz2_tbaseclass)
     y : byte;
   end;

const
  tobjsiz2_expected_size_for_tbaseclass = sizeof(byte);
  tobjsiz2_expected_size_for_tderivedclass = 2*sizeof(byte);

var
  tobjsiz2_basesize : longint;
  tobjsiz2_derivedsize : longint;

function tobjsiz2_tbaseclass.getsize : longint;
begin
  { self = pointer to VMT }
  getsize:=sizeof(self);
end;

procedure tobjsiz2_tbaseclass.check_size;
begin
  if getsize<>sizeof(pointer) then
    begin
      Writeln('Compiler creates garbage ',sizeof(self),'<>',sizeof(pointer));
      halt(1);
    end;
end;


var
  tobjsiz2_cb : tobjsiz2_tbaseclass;
  tobjsiz2_cd : tobjsiz2_tderivedclass;
  tobjsiz2_c1 : tobjsiz2_pbaseclass;

{$pop}

{ Case tobjsize.pas }
{$push}
type
   tobjsize_pbaseclass = ^tobjsize_tbaseclass;
   tobjsize_pderivedclass = ^tobjsize_tderivedclass;

   tobjsize_tbaseclass = object
     x : longint;
     constructor init;
     destructor done; virtual;
   end;

   tobjsize_tderivedclass = object(tobjsize_tbaseclass)
     y : longint;
   end;

const
  tobjsize_has_error : boolean = false;
  tobjsize_expected_size_for_tbaseclass = sizeof(pointer) + sizeof(longint);
  tobjsize_expected_size_for_tderivedclass = sizeof(pointer) + 2*sizeof(longint);

var
  tobjsize_basesize : longint;
  tobjsize_derivedsize : longint;

constructor tobjsize_tbaseclass.init;
begin
end;

destructor tobjsize_tbaseclass.done;
begin
end;

var
  tobjsize_cb : tobjsize_tbaseclass;
  tobjsize_cd : tobjsize_tderivedclass;

{$pop}

begin

{ Case taddr1.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
 { Test procedure variable }
 taddr1_procptr:=@taddr1_testprocvar;
 Write('Value should be ''Hello world!''...');
 taddr1_procptr;
 { Test normal variable }
 taddr1_pcharptr := @taddr1_chararray;
 Inc(taddr1_pcharptr,2);
 Write('Value should be ''CDEFG''...');
 WriteLn(taddr1_pcharptr);
 taddr1_long := $F0F0;
 taddr1_plongint := @taddr1_long;
 Write('Value should be 61680...');
 WriteLn(taddr1_plongint^);
 { Test method pointers }
 { PROCVARLOAD = TRUE testing }
 { Write('Value should be ''Salutations!''...');}
 taddr1_ptr:=@taddr1_tmyobj.writeit;
{ ptr;}
end;
{$pop}

{ Case tobjsiz2.pas }
{$push}

begin
 new(tobjsiz2_c1);

 tobjsiz2_basesize:=sizeof(tobjsiz2_cb);
 Writeln('Sizeof(cb)=',tobjsiz2_basesize);
 if tobjsiz2_basesize<>tobjsiz2_expected_size_for_tbaseclass then
   begin
     Writeln('not the expected size : ',tobjsiz2_expected_size_for_tbaseclass);
     halt(1);
   end;

 tobjsiz2_derivedsize:=sizeof(tobjsiz2_cd);
 Writeln('Sizeof(ct)=',tobjsiz2_derivedsize);
 if tobjsiz2_derivedsize<>tobjsiz2_expected_size_for_tderivedclass then
   begin
     Writeln('not the expected size : ',tobjsiz2_expected_size_for_tderivedclass);
     halt(1);
   end;

  tobjsiz2_cb.check_size;
end;
{$pop}

{ Case tobjsize.pas }
{$push}

begin
 tobjsize_cb.init;
 tobjsize_cd.init;

 tobjsize_basesize:=sizeof(tobjsize_cb);
 Writeln('Sizeof(cb)=',tobjsize_basesize);
 if tobjsize_basesize<>tobjsize_expected_size_for_tbaseclass then
   Writeln('not the expected size : ',tobjsize_expected_size_for_tbaseclass);

 tobjsize_derivedsize:=sizeof(tobjsize_cd);
 Writeln('Sizeof(ct)=',tobjsize_derivedsize);
 if tobjsize_derivedsize<>tobjsize_expected_size_for_tderivedclass then
   Writeln('not the expected size : ',tobjsize_expected_size_for_tderivedclass);

end;
{$pop}

end.
