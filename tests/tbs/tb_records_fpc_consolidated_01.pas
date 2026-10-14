{ Consolidated records regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}

{ Case tb0310.pas }
{$push}


Type
  tb0310_TRec = record
    X,Y : longint;
    end;

  tb0310_TRecFile = File of tb0310_TRec;

var tb0310_TF : tb0310_TRecFile;
    tb0310_LF : File of longint;
    tb0310_i,tb0310_j,tb0310_k,tb0310_l : longint;
    tb0310_t : tb0310_Trec;


{$pop}

{ Case tb_procvar_declarations.pas }
{$push}

{ Procedural variables, typed constants, parameter names and record fields. }

{ tb0042.pas }

procedure tb_procvar_declarations_test;

  begin
  end;

var
   tb_procvar_declarations_p1 : procedure;
   tb_procvar_declarations_p2 : codepointer;

{ tb0099.pas }
{ Procedural vars cannot be assigned nil ?              OK 0.99.6 (FK) }

  type
    tb_procvar_declarations_ExampleProc = procedure;

  var
    tb_procvar_declarations_Eg: tb_procvar_declarations_ExampleProc;

{ tb0196.pas }
{ const. procedure variables need a special syntax if they use calling specification modifiers }

const
   tb_procvar_declarations_cSemicolonStdCall : procedure;stdcall=nil;   { <----- this doesn't what you expect !!!!}
   tb_procvar_declarations_cInlineStdCall : procedure stdcall=nil;   { so delphi supports also this way of }
                                  { declaration                         }

{ tb0213.pas }
{ typecasting not possible within typed const          OK 0.99.13 (PFV) }

type
  tb_procvar_declarations_TConstProcedure=procedure;
  tb_procvar_declarations_TProcConstRecord=record
    w : tb_procvar_declarations_TConstProcedure;
  end;

procedure tb_procvar_declarations_ConstProcedure;
begin
end;

const
  tb_procvar_declarations_cProcConst:tb_procvar_declarations_TProcConstRecord=(
   w : tb_procvar_declarations_TConstProcedure(@tb_procvar_declarations_ConstProcedure);
  );

{ tb0234.pas }
{ @(proc) is not allowed                               OK 0.99.13 (PFV) }

type
  tb_procvar_declarations_proc=procedure(a:longint);

procedure tb_procvar_declarations_prc(a:longint);
begin
end;

var
  tb_procvar_declarations_lParenthesizedProc : tb_procvar_declarations_proc;

{ tb0445.pas }
type
  tb_procvar_declarations_tproc = procedure(self,l2:longint);

procedure tb_procvar_declarations_TestParameterNames(l1,l2:longint);
begin
end;

var
  tb_procvar_declarations_pv : tb_procvar_declarations_tproc;

{ tb0484.pas }
type
  tb_procvar_declarations_r1 = record
    p : procedure stdcall;
    i : longint;
  end;

  tb_procvar_declarations_r2 = record
    p : procedure;
    i : longint;
  end;

  tb_procvar_declarations_r3 = record
    p : procedure
  end;

  { ugly, but should work (FK) }
  tb_procvar_declarations_r4 = record
    p : procedure stdcall
  end;

{ tw1930.pas }
type
 tb_procvar_declarations_tprocedure = procedure (x: byte);pascal;


{$pop}

{ Case tw0882.pas }
{$push}
{$D+,I+,L+,P-,Q+,R+,S+,T+,V+,X+,Y+}

{$if defined(CPUWASM32)}
  { use the default memory sizes for the platform }
{$else}
  {$M 8192,0,655360}
{$endif}


CONST
        tw0882_maxBlockSize    = 1 SHL 13;
TYPE
        tw0882_byteBlock               = ARRAY[0..PRED(tw0882_maxBlockSize)] OF byte;
VAR
        tw0882_bb0                     : ^tw0882_byteBlock;
TYPE
        tw0882_rec     =       RECORD  i1,     len     : word  END;
VAR
        tw0882_mr              : tw0882_rec;
        tw0882_bw              : word;

{$pop}

{ Case tw0938.pas }
{$push}




type
    tw0938_Vector = record
        X,Y,Z : extended;
        end;
    tw0938_Matrix = array [1..4,1..4] of extended;

Const
  tw0938_IDENTITYMATRIX : tw0938_Matrix =
  ( (1,0,0,0),
    (0,1,0,0),
    (0,0,1,0),
    (0,0,0,1));
{...}

function tw0938_NewVector (ax,ay,az : extended) : tw0938_Vector;
begin
  tw0938_NewVector.X:=ax;
  tw0938_NewVector.Y:=ay;
  tw0938_NewVector.Z:=az;
end;

operator * (V : tw0938_Vector;Value : extended) Result : tw0938_Vector;
  begin
    Result.X:=V.X*Value;
    Result.Y:=V.Y*Value;
    Result.Z:=V.Z*Value;
  end;
{...}
operator * (Value : extended;V : tw0938_Vector) Result : tw0938_Vector;
  begin
    Result.X:=V.X*Value;
    Result.Y:=V.Y*Value;
    Result.Z:=V.Z*Value;
  end;
{...}


operator * (M : tw0938_Matrix;Value : extended) Result : tw0938_Matrix;
 var i,j : longint;
  begin
    for i:=1 to 4 do
      for j:=1 to 4 do
        Result[i,j]:=M[i,j]*Value;
  end;
{...}
operator * (Value : extended;M : tw0938_Matrix) Result : tw0938_Matrix;
 var i,j : longint;
  begin
    for i:=1 to 4 do
      for j:=1 to 4 do
        Result[i,j]:=M[i,j]*Value;
  end;
{...}

var
   tw0938_V1, tw0938_V2 : tw0938_Vector;
   tw0938_M1, tw0938_M2 : tw0938_Matrix;


{$pop}

{ Case tw1097.pas }
{$push}
{$H+}

type
  tw1097_Tsome = Record
    One,Two,Three:String;
  end;

Procedure tw1097_passhere(Some:tw1097_TSome;onemore:String);
Begin
end;

procedure tw1097_fromhere;
Var
  me:tw1097_Tsome;
Begin
 me.one:='blah';
 me.two:='';
 me.three:='';
 tw1097_passhere(Me,'text some');
end;


{$pop}

{ Case tw1412.pas }
{$push}

{$H+}
CONST
  tw1412_bufferSize = 8;
  tw1412_tableSize = 2;

TYPE
  tw1412_bufferRecord = RECORD
    stringBuffer     : String;
    characterBuffer  : ARRAY[ 1..tw1412_bufferSize ] OF CHAR;
  END;

VAR
  tw1412_bufferTable  : ARRAY[ 1..tw1412_tableSize ] OF tw1412_bufferRecord;


{$pop}

{ Case tw14230.pas }
{$push}

//The i's are used to have a better understanding of what is actually happening...
type
  tw14230_tsrec = record tw14230_i: single; end;
var tw14230_i,tw14230_new_i:longword;
    tw14230_j,tw14230_new_j:single;
    tw14230_k:double;
    tw14230_s:string;
    tw14230_Err:integer;
    tw14230_count:int64;

{$pop}

{ Case tw1677.pas }
{$push}
{ Source provided for Free Pascal Bug Report 1677 }
{ Submitted by "Anders Lindeberg" on  2001-11-10 }
{ e-mail: anders.lindeberg@telia.com }

{ inlining causes different ref. counting }
{$inline off}


type tw1677_trec = record i:integer; tw1677_s:ansistring end;

procedure tw1677_RefCount(const tw1677_s : ansistring;var tw1677_rc:sizeint;expect:sizeint);
type
        PLongint = ^Longint;
var
        P : psizeint;
begin
        P := psizeint(tw1677_s);
        tw1677_rc:=0;
        if (p = nil)
        then writeln('Nil string.')
        else
{$ifdef  fpc}
         tw1677_rc:=psizeint(pchar(p)-sizeof(sizeint)*2)^;
{$else}
         tw1677_rc:=plongint(pchar(p)-8)^;
{$endif}
  if expect<>-1 then
    begin
      writeln('Ref count is ',tw1677_rc,' expected ',expect);
      if tw1677_rc<>expect then
        halt(1);
    end
  else
    writeln('Ref count is ',tw1677_rc);
end;


procedure tw1677_p1(const tw1677_r:tw1677_trec);
  begin
  end;

procedure tw1677_p2(tw1677_r:tw1677_trec);
  begin
  end;

procedure tw1677_p3(const a:ansistring);
  begin
  end;

procedure tw1677_p4(a:ansistring);
  begin
  end;

var tw1677_r:tw1677_trec; tw1677_s:ansistring;
    tw1677_hrc,tw1677_rc : sizeint;

{$pop}



{ Case tw2966.pas }
{$push}
{ Source provided for Free Pascal Bug Report 2966 }
{ Submitted by "Alexey Barkovoy" on  2004-02-09 }
{ e-mail: clootie@ixbt.com }


type
  {$ALIGN 8} // Can be 8, 16, 32 other value
  tw2966_TType1 = record
    f: Word;
  end;

  tw2966_TType2 = packed record
    f, g: Word;
  end;

  tw2966_TType3 = record
    f, g: Word;
  end;

var
  tw2966_t: tw2966_TType2;
  tw2966_t2: tw2966_TType3;

{$pop}

{ Case tw29964.pas }
{$push}
{$packrecords 1}
{$r-}

var
  tw29964_r: record
       tw29964_i: int64;
       p: pointer;
       w: smallint;
     end;

var
  tw29964_i: longint;
  tw29964_b: byte;
  tw29964_orgp,tw29964_oldp,tw29964_newp: pointer;

{$pop}

{ Case tw3280.pas }
{$push}
{ Source provided for Free Pascal Bug Report 3280 }
{ Submitted by "Alan Mead" on  2004-08-29 }
{ e-mail: cubrewer@yahoo.com }


var
  tw3280_err : boolean;

type
  tw3280_MatrixType = record
    Mat: array of array of real;
    Rows: Integer;
    Cols: Integer;
    Name: String;
    Transpose: Boolean;
    Diagonal: Boolean;
  end;



  procedure tw3280_MatrixNew(var Mat: tw3280_MatrixType; Rows, Cols: Integer; Name: String; Transpose: Boolean; Diagonal: Boolean);
    begin
      writeln('Found ',Rows,' rows and ',Cols,' columns.');
      {SetLength(Mat.Mat,0,0);}
      SetLength(Mat.Mat,Rows,Cols);
      Mat.Rows := Rows;
      Mat.Cols := Cols;
      Mat.Name := Name;
      Mat.Transpose := Transpose;
      Mat.Diagonal := Diagonal;
      writeln('Created matrix with ',Rows,' rows and ',Cols,' columns.'); { debug }
    end;


  procedure tw3280_ShowResults(RetainedDimensions: Integer);
    var
      i:Integer;
      xv: tw3280_MatrixType;
    begin

      for i := 0 to 2 do
        begin
          writeln('Retained dimensions = ',RetainedDimensions); { debug }
          tw3280_MatrixNew(xv,RetainedDimensions,1,'Term vector',FALSE,FALSE);
          writeln('(',xv.Rows,',',xv.Cols,')');
          if (xv.Rows<>3) or (xv.Cols<>1) then
            tw3280_err:=true;
        end;
    end;


{$pop}

{ Case tw3360.pas }
{$push}
{ Source provided for Free Pascal Bug Report 3360 }
{ Submitted by "Thomas Schatzl" on  2004-10-17 }
{ e-mail:  }
{$R-}
{$Q-}

type
        tw3360_tdef = record
          f1 : longint;
          f2 : longint;
        end;

        tw3360_fileof = file of byte;

        tw3360_enum = (tw3360_a,tw3360_b,tw3360_c,tw3360_d=10);

        tw3360_tset1 = set of tw3360_enum;
        tw3360_tset2 = set of byte;

        tw3360_ttdef = type tw3360_tdef;
        tw3360_tfile = type file;
        tw3360_ttext = type text;
        tw3360_tfileof = type tw3360_fileof;
        tw3360_tvariant = type variant;
        //!! tinterfacedobject2 = type tinterfacedobject;
        tw3360_tenum = type tw3360_enum;
        tw3360_ttset1 = type tw3360_tset1;
        tw3360_ttset2 = type tw3360_tset2;

var
  tw3360_e1 : tw3360_enum;
  tw3360_e2 : tw3360_tenum;
  tw3360_def1 : tw3360_tdef;
  tw3360_def2 : tw3360_ttdef;


{$pop}

{ Case tw41177.pas }
{$push}

{$pointermath on}

type
  tw41177_PRec = ^tw41177_TRec;
  tw41177_TRec = record
  end;


{$pop}

{ Case tw9179.pas }
{$push}
type
 tw9179_fontdataty = record
   name: ansistring;
   int: longint;
 end;

var
  tw9179_r1: tw9179_fontdataty;
  tw9179_r2: tw9179_fontdataty;

{$pop}

begin

{ Case tb0310.pas }
{$push}

begin
  Write ('Writing files...');
  assign (tb0310_LF,'longint.dat');
  rewrite (tb0310_LF);
  for tb0310_i:=1 to 10 do
   write (tb0310_LF,tb0310_i);
  close (tb0310_LF);
  Assign (tb0310_TF,'TRec.dat');
  rewrite (tb0310_TF);
  for tb0310_i:=1 to 10 do
    for tb0310_j:=1 to 10 do
      begin
      tb0310_t.x:=tb0310_i;
      tb0310_t.y:=tb0310_j;
      write (tb0310_TF,tb0310_T);
      end;
  close (tb0310_TF);
  writeln ('Done');
  reset (tb0310_LF);
  reset (tb0310_TF);
  Write ('Sequential read test...');
  for tb0310_i:=1 to 10 do
    begin
    read (tb0310_LF,tb0310_J);
    if tb0310_j<>tb0310_i then writeln ('Read of longint failed at :',tb0310_i);
    end;
  for tb0310_i:=1 to 10 do
    for tb0310_j:=1 to 10 do
      begin
      read (tb0310_tf,tb0310_t);
      if (tb0310_t.x<>tb0310_i) or (tb0310_t.y<>tb0310_j) then
        writeln ('Read of record failed at :',tb0310_i,',',tb0310_j);
      end;
  writeln ('Done.');
  Write ('Random access read test...');
  For tb0310_i:=1 to 10 do
    begin
    tb0310_k:=random(10);
    seek (tb0310_lf,tb0310_k);
    read (tb0310_lf,tb0310_j);
    if tb0310_j<>tb0310_k+1 then
     Writeln ('Failed random read of longint at pos ',tb0310_k,' : ',tb0310_j);
    end;
  For tb0310_i:=1 to 10 do
    for tb0310_j:=1 to 10 do
      begin
      tb0310_k:=random(10);
      tb0310_l:=random(10);
      seek (tb0310_tf,tb0310_k*10+tb0310_l);
      read (tb0310_tf,tb0310_t);
      if (tb0310_t.x<>tb0310_k+1) or (tb0310_t.y<>tb0310_l+1) then
        Writeln ('Failed random read of longint at pos ',tb0310_k,',',tb0310_l,' : ',tb0310_t.x,',',tb0310_t.y);
      end;
  Writeln ('Done.');
  close (tb0310_lf);
  close (tb0310_TF);
  erase (tb0310_lf);
  erase (tb0310_tf);

end;
{$pop}

{ Case tb_procvar_declarations.pas }
{$push}

begin
{ tb0042.pas }
  tb_procvar_declarations_p1:=@tb_procvar_declarations_test;
  tb_procvar_declarations_p2:=@tb_procvar_declarations_test;

  { tb0099.pas }
  tb_procvar_declarations_Eg := nil;  { This produces a compiler error }

  { tb0234.pas }
  tb_procvar_declarations_lParenthesizedProc:=@tb_procvar_declarations_prc;
  tb_procvar_declarations_lParenthesizedProc:=@(tb_procvar_declarations_prc);  { should this be allowed ? }

  { tb0445.pas }
  tb_procvar_declarations_pv:={$ifdef fpc}@{$endif}tb_procvar_declarations_TestParameterNames;
end;
{$pop}

{ Case tw0882.pas }
{$push}
{$D+,I+,L+,P-,Q+,R+,S+,T+,V+,X+,Y+}
{$if defined(CPUWASM32)}
{$else}
{$M 8192,0,655360}
{$endif}
BEGIN
        NEW(tw0882_bb0);
        tw0882_mr.i1:=0; tw0882_mr.len:=0;
        tw0882_bb0^[0] := 1;
        tw0882_bb0^[1] := 2;
       {$T+}
        // Addr return untyped pointer, @ typed
        tw0882_bw:=word((@tw0882_bb0^[tw0882_mr.i1])^);
        if tw0882_bw <> 1 then
          halt(1);
       {$T-}
        tw0882_bw:=word(Addr(tw0882_bb0^[tw0882_mr.i1])^);
{$ifndef ENDIAN_BIG}
        if tw0882_bw <> (2 shl 8 + 1) then
{$else ENDIAN_BIG}
        if tw0882_bw <> (1 shl 8 + 2) then
{$endif ENDIAN_BIG}
          halt(1);
END
;
{$pop}

{ Case tw0938.pas }
{$push}

begin
     tw0938_V1 := tw0938_NewVector (1,1,1);
     tw0938_V2 := tw0938_V1 * 2;
     { Everything ok }


     tw0938_M2 := tw0938_IDENTITYMATRIX;
     tw0938_M1 := tw0938_M2 * 2;
     tw0938_M1 := tw0938_IDENTITYMATRIX * 2;
     tw0938_M2 := tw0938_IDENTITYMATRIX * 4;
     { Error: Incompatible types: got "E3MATRIX" expected "LONGINT"  in both rows. This doesn't happen if I use 2.0 and 4.0 values. }


     {...}
end;
{$pop}

{ Case tw1097.pas }
{$push}
{$H+}
begin
  tw1097_fromhere;
end;
{$pop}

{ Case tw1412.pas }
{$push}
{$H+}
BEGIN
  WRITELN( '< INITIALIZATION BUG HAS NOT OCCURRED!' );
END;
{$pop}

{ Case tw14230.pas }
{$push}

begin
   randomize;
   tw14230_count:=0;
   repeat
      //As k is set to be a single-precision number, there should not be
      //any rounding off or truncation problem...
      tw14230_k:=2*random-1;
      tw14230_j:=tw14230_k;
      tw14230_i:=longword(tw14230_tsrec(tw14230_j));
      Str(tw14230_j,tw14230_s);
      Val(tw14230_s,tw14230_new_j,tw14230_Err);
      if (tw14230_err<>0) then
        break;
      tw14230_new_i:=longword(tw14230_tsrec(tw14230_new_j));
      tw14230_count:=tw14230_count+1;
   until tw14230_count=50000;
   if (tw14230_new_i<>tw14230_i) then
     begin
       writeln;
       writeln('Error occurs');
       writeln;
       writeln(' err=',tw14230_err);
       writeln(' i=',tw14230_i);
       writeln(' j=',tw14230_j);
       writeln(' k=',tw14230_k);
       writeln;
       writeln(' s=',tw14230_s);
       writeln;
       writeln('new_i=',tw14230_new_i);
       writeln('new_j=',tw14230_new_j);
       writeln(' k=',tw14230_k);
       halt(1);
     end;
end;
{$pop}

{ Case tw1677.pas }
{$push}
{$inline off}
{$ifdef  fpc}
{$else}
{$endif}
begin
  tw1677_s:=chr(ord('A')+random(26));
  tw1677_r.tw1677_s:=tw1677_s;
  writeln('init');
  tw1677_RefCount(tw1677_s,tw1677_rc,-1);
  writeln('p1()');
  tw1677_p1(tw1677_r);
  tw1677_RefCount(tw1677_s,tw1677_hrc,tw1677_rc);
  writeln('p2()');
  tw1677_p2(tw1677_r);
  tw1677_RefCount(tw1677_s,tw1677_hrc,tw1677_rc);
  writeln('ok');
end;
{$pop}



{ Case tw2966.pas }
{$push}
{$ALIGN 8}
begin
  WriteLn('Type1 = ', SizeOf(tw2966_TType1));
  WriteLn('Type2 = ', SizeOf(tw2966_TType2));
  WriteLn('Type3 = ', SizeOf(tw2966_TType3));
  WriteLn('It''s OK = ', DWORD(tw2966_t));
  WriteLn('This is the bug = ', DWORD(tw2966_t2)); // Compiler stops here with "Error: Illegal type conversion"
end;
{$pop}

{ Case tw29964.pas }
{$push}
{$packrecords 1}
{$r-}
begin
  tw29964_r.tw29964_i:=-1;
  tw29964_r.w:=-1;
  tw29964_b:=$12;
  ptruint(tw29964_r.p):=tw29964_b;
  for tw29964_i:=2 to sizeof(tw29964_r.p) do
    begin
      tw29964_b:=tw29964_b*3;
      ptruint(tw29964_r.p):=ptruint(tw29964_r.p) shl 8 or tw29964_b;
    end;
  tw29964_orgp:=tw29964_r.p;
  tw29964_newp:=pointer(not ptruint(tw29964_orgp));
  tw29964_oldp:=InterlockedCompareExchangePointer(tw29964_r.p,tw29964_newp,tw29964_r.p);
  if tw29964_oldp<>tw29964_orgp then
    halt(1);
  if tw29964_r.p<>tw29964_newp then
    halt(2);
  if tw29964_r.tw29964_i<>-1 then
    halt(3);
  if tw29964_r.w<>-1 then
    halt(4);
end;
{$pop}

{ Case tw3280.pas }
{$push}

begin
  tw3280_ShowResults(3);
  if tw3280_err then
    halt(1);
end;
{$pop}

{ Case tw3360.pas }
{$push}
{$R-}
{$Q-}
begin
  { enums }
  tw3360_e1:=tw3360_a;
  tw3360_e2:=tw3360_a;
  tw3360_e1:=tw3360_d;
  tw3360_e2:=tw3360_d;

  { sets }
  if ord(tw3360_e1)<>ord(tw3360_e2) then
    halt(1);
  if sizeof(tw3360_tset1)<>sizeof(tw3360_ttset1) then
    halt(2);
  if sizeof(tw3360_tset2)<>sizeof(tw3360_ttset2) then
    halt(3);

  { records }
  tw3360_def1.f1:=$deadbeef;
  tw3360_def1.f2:=$d0d0d0d0;
  if sizeof(tw3360_def1)<>sizeof(tw3360_def2) then
    halt(4);

  move(tw3360_def1,tw3360_def2,sizeof(tw3360_def1));

  if (tw3360_def1.f1<>tw3360_def2.f1) or
    (tw3360_def1.f2<>tw3360_def2.f2) then
    halt(5);

  writeln('ok');
end;
{$pop}

{ Case tw41177.pas }
{$push}
{$pointermath on}
begin
  argv:=@tw41177_PRec(0)[0];   // OK
  argv:=@tw41177_PRec(nil)[0]; // NotOK - "Can't assign values to an address"
end;
{$pop}

{ Case tw9179.pas }
{$push}

begin
  fillchar(tw9179_r1,sizeof(tw9179_r1),0);
  tw9179_r1.int:= 12345;
  writeln(tw9179_r1.int);
  tw9179_r2:=tw9179_r1;
  writeln(tw9179_r2.int);
  if tw9179_r1.int <> tw9179_r2.int then begin
    writeln('Test failed!');
    Halt(1);
  end;
  writeln('Test OK.');
end;
{$pop}

end.
