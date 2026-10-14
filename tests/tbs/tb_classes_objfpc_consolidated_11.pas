{ Consolidated classes regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case testcompo.pas }
{$push}
{
  mips-linux had a bug that was only having an effect on
  the jvm compiler built on mips-linux system.

  In a_cmp_ref_reg_label method of Thlcgcpu in jvm/hlcgcpu.pas unit,
  in line 1310, a temp is allocated of size 56,
  corresponding to a temporary partial copy of the reference record
  for the part that is put on stack at $sp+16
  when a_load_ref_stack is called,
  but the temp is never copied back to correct location $sp+16
.Lj518:
# Temp 192,56 allocated
	# Register a0 allocated
	.stabn 68,0,1310,.Ll540 - HLCGCPU$_$THLCGJVM_$__$$_A_CMP_REF_REG_LABEL$TASMLIST$TDEF$TOPCMP$TREFERENCE$TREGISTER$TASMLABEL
.Ll540:
# [1310] a_load_ref_stack(list,size,ref,prepare_stack_for_ref(list,ref,false))
	addiu	$a0,$fp,16
	# Register a1 allocated
	addiu	$a1,$sp,192
	# Register v0 allocated
	addiu	$v0,$zero,14

  This test tries to generate a simple example displaying the same problem
}



const
  testcompo_NR_NO=0;
  testcompo_NR_EVAL_STACK_BASE=$55443322;
  testcompo_NR_STACK_POINTER_REG=$55010101;
  testcompo_NR_BASE=$BA;
  testcompo_NR_INDEX=$1D;
  testcompo_test_offset = $ABCDEF;

type

  testcompo_TCGInt = Int64;
  testcompo_Tai = class
    next : testcompo_tai;
  end;

  testcompo_Tdef = class
      testcompo_size : longint;
      constructor create;
    end;

  testcompo_TOrdDef = class(testcompo_Tdef)
      high : testcompo_TCgint;
    end;

  testcompo_TSymbol = class
    end;
  testcompo_TAsmLabel = class
    end;

  testcompo_topcmp = (testcompo_op_none,testcompo_op_eq,testcompo_op_gt,testcompo_op_lt,testcompo_op_ge,testcompo_op_le,
    testcompo_op_ne,testcompo_op_and,testcompo_op_or,testcompo_op_xor);

  testcompo_tregister = longint;

  testcompo_treference = record
    base : ptruint;
    index : ptruint;
    offset : testcompo_TCGInt;
    symbol : testcompo_tsymbol;
  end;

  testcompo_tasmop = (testcompo_a_none,testcompo_a_mov,testcompo_a_swap,testcompo_a_dup,testcompo_a_putfield,testcompo_a_getfield,
            testcompo_a_checkcast,testcompo_a_putstatic,testcompo_a_getstatic,
            testcompo_a_iload,testcompo_a_istore);

  testcompo_TAsmList = class
    first, last : testcompo_tai;
    constructor create;
    procedure concat(next : testcompo_tai);
  end;

  testcompo_TaiCPU = class(testcompo_tai)
    constructor testcompo_op_none(op : testcompo_tasmop);
    constructor op_reg(op : testcompo_tasmop; testcompo_reg : testcompo_tregister);
    constructor op_ref(op : testcompo_tasmop; testcompo_ref : testcompo_treference);
    constructor op_const(op : testcompo_tasmop; val : testcompo_tcgint);
  end;

  testcompo_thlcgjvm = class
    fstackpos : longint;
    constructor create;
    function loadstoreopc(def: testcompo_tdef; isload, isarray: boolean; out finishandval: testcompo_tcgint): testcompo_tasmop;
    procedure incstack(testcompo_list: testcompo_TasmList;slots: longint);
    function prepare_stack_for_ref(testcompo_list: testcompo_TAsmList; const testcompo_ref: testcompo_treference; dup: boolean): longint;
    procedure a_load_reg_stack(testcompo_list : testcompo_TAsmList;testcompo_size: testcompo_tdef;testcompo_reg: testcompo_tregister);
    procedure a_load_ref_stack(testcompo_list : testcompo_TAsmList;testcompo_size: testcompo_tdef;const testcompo_ref: testcompo_treference;extra_slots: longint);
    procedure a_cmp_ref_reg_label(testcompo_list: testcompo_TAsmList; testcompo_size: testcompo_tdef; testcompo_cmp_op: testcompo_topcmp; const testcompo_ref: testcompo_treference; testcompo_reg: testcompo_tregister; testcompo_l: testcompo_tasmlabel);
    function loadstoreopcref(def: testcompo_tdef; isload: boolean; const testcompo_ref: testcompo_treference; out finishandval: testcompo_tcgint): testcompo_tasmop;
  end;

var
  testcompo_voidpointertype : testcompo_torddef;
  testcompo_gsym : testcompo_tsymbol;
const
  testcompo_test_count : longint = 0;
  testcompo_error_count : longint = 0;

  procedure testcompo_test(testcompo_ref : testcompo_treference);
    begin
      if (testcompo_ref.base<>testcompo_NR_BASE) or (testcompo_ref.index <>testcompo_NR_INDEX) or
         (testcompo_ref.offset<>testcompo_test_offset) or (testcompo_ref.symbol<>testcompo_gsym) then
        begin
          writeln('Error in generated code');
          inc(testcompo_error_count);
        end;
      inc(testcompo_test_count);
    end;

  procedure testcompo_internalerror(v : longint);
    begin
      writeln('Internal error ',v);
    end;

  constructor testcompo_tdef.create;
    begin
      testcompo_size:=4;
    end;

   constructor testcompo_tasmlist.create;
    begin
      first:=nil;
      last:=nil;
    end;

  procedure testcompo_tasmlist.concat(next : testcompo_tai);
    begin
      if not assigned(first) then
        begin
          first:=next;
          last:=next;
        end
      else
        begin
          last.next:=next;
          last:=next;
        end;
    end;

  constructor testcompo_TaiCPU.testcompo_op_none(op : testcompo_tasmop);
    begin
    end;

  constructor testcompo_TaiCPU.op_reg(op : testcompo_tasmop; testcompo_reg : testcompo_tregister);
    begin
    end;

  constructor testcompo_TaiCPU.op_ref(op : testcompo_tasmop; testcompo_ref : testcompo_treference);
    begin
    end;

  constructor testcompo_TaiCPU.op_const(op : testcompo_tasmop; val : testcompo_tcgint);
    begin
    end;


   procedure testcompo_a_op_const_stack(testcompo_list : testcompo_tasmlist;op : testcompo_topcmp;testcompo_size:testcompo_tdef;finishandval : testcompo_TCGInt);
     begin
       testcompo_list.concat(testcompo_taicpu.op_const(testcompo_a_none,finishandval));
     end;


  constructor testcompo_thlcgjvm.create;
    begin
    end;

  procedure testcompo_thlcgjvm.incstack(testcompo_list: testcompo_TasmList;slots: longint);
    begin
      if slots=0 then
        exit;
      inc(fstackpos,slots);
    end;


   procedure testcompo_thlcgjvm.a_cmp_ref_reg_label(testcompo_list: testcompo_TAsmList; testcompo_size: testcompo_tdef; testcompo_cmp_op: testcompo_topcmp; const testcompo_ref: testcompo_treference; testcompo_reg: testcompo_tregister; testcompo_l: testcompo_tasmlabel);
    var
      extraslots : longint;
    begin
      writeln('a_cmp_ref_reg_label');
      a_load_reg_stack(testcompo_list,testcompo_size,testcompo_reg);
      { First separated }
      extraslots:=prepare_stack_for_ref(testcompo_list,testcompo_ref,false);
      a_load_ref_stack(testcompo_list,testcompo_size,testcompo_ref,extraslots);
      a_load_ref_stack(testcompo_list,testcompo_size,testcompo_ref,prepare_stack_for_ref(testcompo_list,testcompo_ref,false));
    end;

  function testcompo_thlcgjvm.loadstoreopc(def: testcompo_tdef; isload, isarray: boolean; out finishandval: testcompo_tcgint): testcompo_tasmop;
    var
      testcompo_size: longint;
    begin
      finishandval:=-1;
      testcompo_size:=def.testcompo_size;
      if isload then
        result:=testcompo_a_iload
      else
        result:=testcompo_a_istore;
    end;

  procedure testcompo_thlcgjvm.a_load_reg_stack(testcompo_list: testcompo_TAsmList; testcompo_size: testcompo_tdef; testcompo_reg: testcompo_tregister);
    var
      opc: testcompo_tasmop;
      finishandval: testcompo_tcgint;
    begin
      writeln('a_load_reg_stack');
      opc:=loadstoreopc(testcompo_size,true,false,finishandval);
      testcompo_list.concat(testcompo_taicpu.op_reg(opc,testcompo_reg));
      incstack(testcompo_list,1+ord(testcompo_size.testcompo_size>4));
    end;

  procedure testcompo_thlcgjvm.a_load_ref_stack(testcompo_list: testcompo_TAsmList; testcompo_size: testcompo_tdef; const testcompo_ref: testcompo_treference; extra_slots: longint);
    var
      opc: testcompo_tasmop;
      finishandval: testcompo_tcgint;
    begin
      writeln('a_load_ref_stack');
      testcompo_test(testcompo_ref);
      opc:=loadstoreopcref(testcompo_size,true,testcompo_ref,finishandval);
      incstack(testcompo_list,1+ord(testcompo_size.testcompo_size>4)-extra_slots);
      if finishandval<>-1 then
        testcompo_a_op_const_stack(testcompo_list,testcompo_OP_AND,testcompo_size,finishandval);
    end;

  function testcompo_thlcgjvm.prepare_stack_for_ref(testcompo_list: testcompo_TAsmList; const testcompo_ref: testcompo_treference; dup: boolean): longint;
    var
      href: testcompo_treference;
    begin
      writeln('prepare_stack_for_ref');
      result:=0;
      testcompo_test(testcompo_ref);
        begin
          if (testcompo_ref.base<>testcompo_NR_NO) then
            begin
              if (testcompo_ref.base<>testcompo_NR_STACK_POINTER_REG) then
                begin
                  { regular field -> load self on the stack }
                  a_load_reg_stack(testcompo_list,testcompo_voidpointertype,testcompo_ref.base);
                  if dup then
                    begin
                      testcompo_list.concat(testcompo_taicpu.testcompo_op_none(testcompo_a_dup));
                      incstack(testcompo_list,1);
                    end;
                  result:=1;
                end
              else
                begin
                  if assigned(testcompo_ref.symbol) then
                    testcompo_internalerror(2010120523);
                end;
            end
          else
            begin
              { static field -> nothing to do here, except for validity check }
              if not assigned(testcompo_ref.symbol) or
                 (testcompo_ref.offset<>0) then
                testcompo_internalerror(2010120525);
            end;
        end;
    end;

  function testcompo_thlcgjvm.loadstoreopcref(def: testcompo_tdef; isload: boolean; const testcompo_ref: testcompo_treference; out finishandval: testcompo_tcgint): testcompo_tasmop;
    const
                     { isload  static }
      getputopc: array[boolean,boolean] of testcompo_tasmop =
        ((testcompo_a_putfield,testcompo_a_putstatic),
         (testcompo_a_getfield,testcompo_a_getstatic));
    begin
      if assigned(testcompo_ref.symbol) then
        begin
          result:=getputopc[isload,testcompo_ref.base=testcompo_NR_NO];
          finishandval:=-1;
            case def.testcompo_size of
              1: if (testcompo_torddef(def).high>127) then
                   finishandval:=255;
              2: if (testcompo_torddef(def).high>32767) then
                   finishandval:=65535;
            end;
        end;
    end;

var
  testcompo_ref : testcompo_treference;
  testcompo_size : testcompo_torddef;
  testcompo_cmp_op : testcompo_topcmp;
  testcompo_reg : testcompo_tregister;
  testcompo_l : testcompo_TAsmLabel;
  testcompo_hlcg : testcompo_thlcgjvm;
  testcompo_list : testcompo_TAsmlist;

{$pop}

{ Case tinline5.pas }
{$push}
{$inline on}


type
  tinline5_tc = class
    lf: longint;
    procedure tinline5_t(const l: longint); inline;
  end;

var
  tinline5_a: longint;

procedure tinline5_tc.tinline5_t(const l: longint); inline;
begin
  lf := 10;
  if (l <> 5) then
    begin
      writeln('error class');
      halt(1);
    end;
end;


procedure tinline5_t(const l: longint); inline;
begin
  tinline5_a := 10;
  if (l <> 5) then
    begin
      writeln('error proc');
      halt(1);
    end;
end;

var
  tinline5_c: tinline5_tc;


{$pop}

{ Case tinline6.pas }
{$push}
{$inline on}


type
  tinline6_tc = class
    lf: longint;
    procedure tinline6_t(l: longint); inline;
  end;

var
  tinline6_a: longint;

procedure tinline6_tc.tinline6_t(l: longint); inline;
begin
  lf := 10;
  if (l <> 5) then
    begin
      writeln('error class');
      halt(1);
    end;
end;


procedure tinline6_t(l: longint); inline;
begin
  tinline6_a := 10;
  if (l <> 5) then
    begin
      writeln('error proc');
      halt(1);
    end;
end;

var
  tinline6_c: tinline6_tc;


{$pop}

begin

{ Case testcompo.pas }
{$push}

begin
  writeln('Start of test');
  testcompo_gsym:=testcompo_tsymbol.create;
  testcompo_ref.base:=testcompo_NR_BASE;
  testcompo_ref.index:=testcompo_NR_INDEX;
  testcompo_ref.offset:=testcompo_test_offset;
  testcompo_ref.symbol:=testcompo_gsym;
  testcompo_list:=testcompo_tasmlist.create;
  testcompo_l:=testcompo_tasmlabel.create;
  testcompo_size:=testcompo_torddef.create;
  testcompo_size.testcompo_size:=1;
  testcompo_size.high:=255;
  testcompo_voidpointertype:=testcompo_torddef.create;
  testcompo_voidpointertype.testcompo_size:=sizeof(ptrint);
  testcompo_voidpointertype.high:=testcompo_TCGInt(high(ptrint));
  testcompo_hlcg:=testcompo_thlcgjvm.create;
  testcompo_hlcg.a_cmp_ref_reg_label(testcompo_list,testcompo_size, testcompo_cmp_op, testcompo_ref, testcompo_reg, testcompo_l);
  writeln('End of test, number of test: ',testcompo_test_count);
  if testcompo_error_count > 0 then
    begin
      writeln(testcompo_error_count,' errors found');
      halt(1);
    end;
end;
{$pop}

{ Case tinline5.pas }
{$push}
{$inline on}

begin
  tinline5_c := tinline5_tc.create;
  tinline5_c.lf := 5;
  tinline5_c.tinline5_t(tinline5_c.lf);
  tinline5_a := 5;
  tinline5_t(tinline5_a);
end;
{$pop}

{ Case tinline6.pas }
{$push}
{$inline on}

begin
  tinline6_c := tinline6_tc.create;
  tinline6_c.lf := 5;
  tinline6_c.tinline6_t(tinline6_c.lf);
  tinline6_a := 5;
  tinline6_t(tinline6_a);
end;
{$pop}

end.
