{ Consolidated classes regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case tcalpvr1.pp }
{$push}
{****************************************************************}
{  CODE GENERATOR TEST PROGRAM                                   }
{****************************************************************}
{ NODE TESTED : secondcalln()                                    }
{****************************************************************}
{ PRE-REQUISITES: secondload()                                   }
{                 secondassign()                                 }
{                 secondcalln()                                  }
{                 secondadd()                                    }
{                 secondtypeconv()                               }
{****************************************************************}
{ DEFINES:                                                       }
{****************************************************************}
{ REMARKS: This tests a subset of the secondcalln() , it         }
{          verifies procedural variables for standard            }
{          calling conventions.                                  }
{****************************************************************}


{$R+}

const
   tcalpvr1_RESULT_U8BIT = $55;
   tcalpvr1_RESULT_U16BIT = $500F;
   tcalpvr1_RESULT_S32BIT = $500F0000;
   tcalpvr1_RESULT_S64BIT = -12000;

type

  tcalpvr1_troutine = procedure (x: longint;  y: byte);
  tcalpvr1_troutineresult = function (x: longint; y: byte): int64;

  tcalpvr1_tsimpleobject = object
    constructor init;
    procedure test_normal(x: byte);
    procedure test_static(x: byte);static;
    procedure test_virtual(x: byte);virtual;
  end;

  tcalpvr1_tsimpleclass = class
    constructor create;
    procedure test_normal(x: byte);
    class procedure test_static(x: byte);
    procedure test_virtual(x: byte);virtual;
  end;

  tcalpvr1_tobjectmethod = procedure (x: byte) of object ;
  tcalpvr1_tclassmethod = procedure (x: byte) of object;

var
  tcalpvr1_proc : tcalpvr1_troutine;
  tcalpvr1_func : tcalpvr1_troutineresult;
  tcalpvr1_obj_method : tcalpvr1_tobjectmethod;
  tcalpvr1_cla_method : tcalpvr1_tclassmethod;
  tcalpvr1_global_s32bit : longint;
  tcalpvr1_global_s64bit : int64;
  tcalpvr1_global_u8bit : byte;
  tcalpvr1_value_s32bit : longint;
  tcalpvr1_value_u8bit : byte;
  tcalpvr1_obj : tcalpvr1_tsimpleobject;
  tcalpvr1_cla : tcalpvr1_tsimpleclass;




  procedure tcalpvr1_fail;
   begin
     WriteLn('Failed!');
     halt(1);
   end;

  procedure tcalpvr1_clear_globals;
   begin
     tcalpvr1_global_s32bit := 0;
     tcalpvr1_global_u8bit := 0;
     tcalpvr1_global_s64bit := 0;
   end;

  procedure tcalpvr1_clear_values;
    begin
      tcalpvr1_value_s32bit := 0;
      tcalpvr1_value_u8bit := 0;
    end;


  procedure tcalpvr1_testroutine(x: longint; y: byte);
   begin
     tcalpvr1_global_s32bit := x;
     tcalpvr1_global_u8bit := y;
   end;

  function tcalpvr1_testroutineresult(x: longint; y: byte): int64;
   begin
     tcalpvr1_global_s32bit := x;
     tcalpvr1_global_u8bit := y;
     tcalpvr1_testroutineresult := tcalpvr1_RESULT_S64BIT;
   end;


  function tcalpvr1_getroutine: tcalpvr1_troutine;
    begin
      tcalpvr1_getroutine:=tcalpvr1_proc;
    end;

  function tcalpvr1_getroutineresult : tcalpvr1_troutineresult;
   begin
     tcalpvr1_getroutineresult := tcalpvr1_func;
   end;

{ IMPOSSIBLE TO DO CURRENTLY !
  function get_object_method_static : tnormalmethod;
   begin
     get_object_method_static := @obj.test_static;
   end;
}

  { objects access }
  function tcalpvr1_get_object_method_normal : tcalpvr1_tobjectmethod;
   begin
     tcalpvr1_get_object_method_normal := @tcalpvr1_obj.test_normal;
   end;

  function tcalpvr1_get_object_type_method_virtual : tcalpvr1_tobjectmethod;
   begin
     tcalpvr1_get_object_type_method_virtual := @tcalpvr1_obj.test_virtual;
   end;

  function tcalpvr1_get_object_method_virtual : tcalpvr1_tobjectmethod;
   begin
     tcalpvr1_get_object_method_virtual := @tcalpvr1_obj.test_virtual;
   end;

  function tcalpvr1_get_class_method_normal : tcalpvr1_tclassmethod;
   begin
     tcalpvr1_get_class_method_normal := @tcalpvr1_cla.test_normal;
   end;
{
  function get_class_method_static : tclassmethod;
   begin
     get_class_method_static := @cla.test_static;
   end;}

  function tcalpvr1_get_class_method_virtual : tcalpvr1_tclassmethod;
   begin
     tcalpvr1_get_class_method_virtual := @tcalpvr1_cla.test_virtual;
   end;

 {****************************************************************************************************}

  constructor tcalpvr1_tsimpleobject.init;
   begin
   end;

  procedure tcalpvr1_tsimpleobject.test_normal(x: byte);
   begin
     tcalpvr1_global_u8bit := x;
   end;

  procedure tcalpvr1_tsimpleobject.test_static(x: byte);
   begin
     tcalpvr1_global_u8bit := x;
   end;

  procedure tcalpvr1_tsimpleobject.test_virtual(x: byte);
   begin
     tcalpvr1_global_u8bit := x;
   end;

 {****************************************************************************************************}
  constructor tcalpvr1_tsimpleclass.create;
   begin
    inherited create;
   end;

  procedure tcalpvr1_tsimpleclass. test_normal(x: byte);
   begin
     tcalpvr1_global_u8bit := x;
   end;

  class procedure tcalpvr1_tsimpleclass.test_static(x: byte);
   begin
     tcalpvr1_global_u8bit := x;
   end;

  procedure tcalpvr1_tsimpleclass.test_virtual(x: byte);
   begin
     tcalpvr1_global_u8bit := x;
   end;

var
 tcalpvr1_failed : boolean;

{$pop}

{ Case tcalpvr2.pp }
{$push}
{****************************************************************}
{  CODE GENERATOR TEST PROGRAM                                   }
{****************************************************************}
{ NODE TESTED : secondcalln()                                    }
{****************************************************************}
{ PRE-REQUISITES: secondload()                                   }
{                 secondassign()                                 }
{                 secondcalln()                                  }
{                 secondadd()                                    }
{                 secondtypeconv()                               }
{****************************************************************}
{ DEFINES:                                                       }
{****************************************************************}
{ REMARKS: This tests a subset of the secondcalln() , it         }
{          verifies procedural variables for pascal              }
{          calling conventions.                                  }
{****************************************************************}


{$R+}

const
   tcalpvr2_RESULT_U8BIT = $55;
   tcalpvr2_RESULT_U16BIT = $500F;
   tcalpvr2_RESULT_S32BIT = $500F0000;
   tcalpvr2_RESULT_S64BIT = -12000;

type

  tcalpvr2_troutine = procedure (x: longint;  y: byte);pascal;
  tcalpvr2_troutineresult = function (x: longint; y: byte): int64;pascal;

  tcalpvr2_tsimpleobject = object
    constructor init;
    procedure test_normal(x: byte);pascal;
    procedure test_static(x: byte);static;pascal;
    procedure test_virtual(x: byte);virtual;pascal;
  end;

  tcalpvr2_tsimpleclass = class
    constructor create;
    procedure test_normal(x: byte);pascal;
    class procedure test_static(x: byte);pascal;
    procedure test_virtual(x: byte);virtual;pascal;
  end;

  tcalpvr2_tobjectmethod = procedure (x: byte) of object ;pascal;
  tcalpvr2_tclassmethod = procedure (x: byte) of object;pascal;

var
  tcalpvr2_proc : tcalpvr2_troutine;
  tcalpvr2_func : tcalpvr2_troutineresult;
  tcalpvr2_obj_method : tcalpvr2_tobjectmethod;
  tcalpvr2_cla_method : tcalpvr2_tclassmethod;
  tcalpvr2_global_s32bit : longint;
  tcalpvr2_global_s64bit : int64;
  tcalpvr2_global_u8bit : byte;
  tcalpvr2_value_s32bit : longint;
  tcalpvr2_value_u8bit : byte;
  tcalpvr2_obj : tcalpvr2_tsimpleobject;
  tcalpvr2_cla : tcalpvr2_tsimpleclass;




  procedure tcalpvr2_fail;
   begin
     WriteLn('Failed!');
     halt(1);
   end;

  procedure tcalpvr2_clear_globals;
   begin
     tcalpvr2_global_s32bit := 0;
     tcalpvr2_global_u8bit := 0;
     tcalpvr2_global_s64bit := 0;
   end;

  procedure tcalpvr2_clear_values;
    begin
      tcalpvr2_value_s32bit := 0;
      tcalpvr2_value_u8bit := 0;
    end;


  procedure tcalpvr2_testroutine(x: longint; y: byte);pascal;
   begin
     tcalpvr2_global_s32bit := x;
     tcalpvr2_global_u8bit := y;
   end;

  function tcalpvr2_testroutineresult(x: longint; y: byte): int64;pascal;
   begin
     tcalpvr2_global_s32bit := x;
     tcalpvr2_global_u8bit := y;
     tcalpvr2_testroutineresult := tcalpvr2_RESULT_S64BIT;
   end;


  function tcalpvr2_getroutine: tcalpvr2_troutine;
    begin
      tcalpvr2_getroutine:=tcalpvr2_proc;
    end;

  function tcalpvr2_getroutineresult : tcalpvr2_troutineresult;
   begin
     tcalpvr2_getroutineresult := tcalpvr2_func;
   end;

{ IMPOSSIBLE TO DO CURRENTLY !
  function get_object_method_static : tnormalmethod;
   begin
     get_object_method_static := @obj.test_static;
   end;
}

  { objects access }
  function tcalpvr2_get_object_method_normal : tcalpvr2_tobjectmethod;
   begin
     tcalpvr2_get_object_method_normal := @tcalpvr2_obj.test_normal;
   end;

  function tcalpvr2_get_object_type_method_virtual : tcalpvr2_tobjectmethod;
   begin
     tcalpvr2_get_object_type_method_virtual := @tcalpvr2_obj.test_virtual;
   end;

  function tcalpvr2_get_object_method_virtual : tcalpvr2_tobjectmethod;
   begin
     tcalpvr2_get_object_method_virtual := @tcalpvr2_obj.test_virtual;
   end;

{
  HOW CAN WE GET THIS ADDRESS???
  function get_class_method_static_self : tclassmethodself;
   begin
     get_class_method_static_self := @cla.test_static_self;
   end;
}

  function tcalpvr2_get_class_method_normal : tcalpvr2_tclassmethod;
   begin
     tcalpvr2_get_class_method_normal := @tcalpvr2_cla.test_normal;
   end;
{
  function get_class_method_static : tclassmethod;
   begin
     get_class_method_static := @cla.test_static;
   end;}

  function tcalpvr2_get_class_method_virtual : tcalpvr2_tclassmethod;
   begin
     tcalpvr2_get_class_method_virtual := @tcalpvr2_cla.test_virtual;
   end;

 {****************************************************************************************************}

  constructor tcalpvr2_tsimpleobject.init;
   begin
   end;

  procedure tcalpvr2_tsimpleobject.test_normal(x: byte);pascal;
   begin
     tcalpvr2_global_u8bit := x;
   end;

  procedure tcalpvr2_tsimpleobject.test_static(x: byte);pascal;
   begin
     tcalpvr2_global_u8bit := x;
   end;

  procedure tcalpvr2_tsimpleobject.test_virtual(x: byte);pascal;
   begin
     tcalpvr2_global_u8bit := x;
   end;

 {****************************************************************************************************}
  constructor tcalpvr2_tsimpleclass.create;
   begin
    inherited create;
   end;

  procedure tcalpvr2_tsimpleclass. test_normal(x: byte);pascal;
   begin
     tcalpvr2_global_u8bit := x;
   end;

  class procedure tcalpvr2_tsimpleclass.test_static(x: byte);pascal;
   begin
     tcalpvr2_global_u8bit := x;
   end;

  procedure tcalpvr2_tsimpleclass.test_virtual(x: byte);pascal;
   begin
     tcalpvr2_global_u8bit := x;
   end;


var
 tcalpvr2_failed : boolean;

{$pop}

{ Case tcalpvr3.pp }
{$push}
{****************************************************************}
{  CODE GENERATOR TEST PROGRAM                                   }
{****************************************************************}
{ NODE TESTED : secondcalln()                                    }
{****************************************************************}
{ PRE-REQUISITES: secondload()                                   }
{                 secondassign()                                 }
{                 secondcalln()                                  }
{                 secondadd()                                    }
{                 secondtypeconv()                               }
{****************************************************************}
{ DEFINES:                                                       }
{****************************************************************}
{ REMARKS: This tests a subset of the secondcalln() , it         }
{          verifies procedural variables for cdecl               }
{          calling conventions.                                  }
{****************************************************************}


{$R+}

const
   tcalpvr3_RESULT_U8BIT = $55;
   tcalpvr3_RESULT_U16BIT = $500F;
   tcalpvr3_RESULT_S32BIT = $500F0000;
   tcalpvr3_RESULT_S64BIT = -12000;

type

  tcalpvr3_troutine = procedure (x: longint;  y: byte);cdecl;
  tcalpvr3_troutineresult = function (x: longint; y: byte): int64;cdecl;

  tcalpvr3_tsimpleobject = object
    constructor init;
    procedure test_normal(x: byte);cdecl;
    procedure test_static(x: byte);static;cdecl;
    procedure test_virtual(x: byte);virtual;{$ifndef VER1_0}cdecl;{$endif}
  end;

  tcalpvr3_tsimpleclass = class
    constructor create;
    procedure test_normal(x: byte);cdecl;
    class procedure test_static(x: byte);cdecl;
    procedure test_virtual(x: byte);virtual;{$ifndef VER1_0}cdecl;{$endif}
  end;

  tcalpvr3_tobjectmethod = procedure (x: byte) of object ;cdecl;
  tcalpvr3_tclassmethod = procedure (x: byte) of object;cdecl;

var
  tcalpvr3_proc : tcalpvr3_troutine;
  tcalpvr3_func : tcalpvr3_troutineresult;
  tcalpvr3_obj_method : tcalpvr3_tobjectmethod;
  tcalpvr3_cla_method : tcalpvr3_tclassmethod;
  tcalpvr3_global_s32bit : longint;
  tcalpvr3_global_s64bit : int64;
  tcalpvr3_global_u8bit : byte;
  tcalpvr3_value_s32bit : longint;
  tcalpvr3_value_u8bit : byte;
  tcalpvr3_obj : tcalpvr3_tsimpleobject;
  tcalpvr3_cla : tcalpvr3_tsimpleclass;




  procedure tcalpvr3_fail;
   begin
     WriteLn('Failed!');
     halt(1);
   end;

  procedure tcalpvr3_clear_globals;
   begin
     tcalpvr3_global_s32bit := 0;
     tcalpvr3_global_u8bit := 0;
     tcalpvr3_global_s64bit := 0;
   end;

  procedure tcalpvr3_clear_values;
    begin
      tcalpvr3_value_s32bit := 0;
      tcalpvr3_value_u8bit := 0;
    end;


  procedure tcalpvr3_testroutine(x: longint; y: byte);cdecl;
   begin
     tcalpvr3_global_s32bit := x;
     tcalpvr3_global_u8bit := y;
   end;

  function tcalpvr3_testroutineresult(x: longint; y: byte): int64;cdecl;
   begin
     tcalpvr3_global_s32bit := x;
     tcalpvr3_global_u8bit := y;
     tcalpvr3_testroutineresult := tcalpvr3_RESULT_S64BIT;
   end;


  function tcalpvr3_getroutine: tcalpvr3_troutine;
    begin
      tcalpvr3_getroutine:=tcalpvr3_proc;
    end;

  function tcalpvr3_getroutineresult : tcalpvr3_troutineresult;
   begin
     tcalpvr3_getroutineresult := tcalpvr3_func;
   end;

{ IMPOSSIBLE TO DO CURRENTLY !
  function get_object_method_static : tnormalmethod;
   begin
     get_object_method_static := @obj.test_static;
   end;
}

  { objects access }
  function tcalpvr3_get_object_method_normal : tcalpvr3_tobjectmethod;
   begin
     tcalpvr3_get_object_method_normal := @tcalpvr3_obj.test_normal;
   end;

  function tcalpvr3_get_object_type_method_virtual : tcalpvr3_tobjectmethod;
   begin
     tcalpvr3_get_object_type_method_virtual := @tcalpvr3_obj.test_virtual;
   end;

  function tcalpvr3_get_object_method_virtual : tcalpvr3_tobjectmethod;
   begin
     tcalpvr3_get_object_method_virtual := @tcalpvr3_obj.test_virtual;
   end;

{
  HOW CAN WE GET THIS ADDRESS???
  function get_class_method_static_self : tclassmethodself;
   begin
     get_class_method_static_self := @cla.test_static_self;
   end;
}

  function tcalpvr3_get_class_method_normal : tcalpvr3_tclassmethod;
   begin
     tcalpvr3_get_class_method_normal := @tcalpvr3_cla.test_normal;
   end;
{
  function get_class_method_static : tclassmethod;
   begin
     get_class_method_static := @cla.test_static;
   end;}

  function tcalpvr3_get_class_method_virtual : tcalpvr3_tclassmethod;
   begin
     tcalpvr3_get_class_method_virtual := @tcalpvr3_cla.test_virtual;
   end;

 {****************************************************************************************************}

  constructor tcalpvr3_tsimpleobject.init;
   begin
   end;

  procedure tcalpvr3_tsimpleobject.test_normal(x: byte);cdecl;
   begin
     tcalpvr3_global_u8bit := x;
   end;

  procedure tcalpvr3_tsimpleobject.test_static(x: byte);cdecl;
   begin
     tcalpvr3_global_u8bit := x;
   end;

  procedure tcalpvr3_tsimpleobject.test_virtual(x: byte);{$ifndef VER1_0}cdecl;{$endif}
   begin
     tcalpvr3_global_u8bit := x;
   end;

 {****************************************************************************************************}
  constructor tcalpvr3_tsimpleclass.create;
   begin
    inherited create;
   end;

  procedure tcalpvr3_tsimpleclass. test_normal(x: byte);cdecl;
   begin
     tcalpvr3_global_u8bit := x;
   end;

  class procedure tcalpvr3_tsimpleclass.test_static(x: byte);cdecl;
   begin
     tcalpvr3_global_u8bit := x;
   end;

  procedure tcalpvr3_tsimpleclass.test_virtual(x: byte);{$ifndef VER1_0}cdecl;{$endif}
   begin
     tcalpvr3_global_u8bit := x;
   end;


var
 tcalpvr3_failed : boolean;

{$pop}

{ Case tcalpvr6.pp }
{$push}
{****************************************************************}
{  CODE GENERATOR TEST PROGRAM                                   }
{****************************************************************}
{ NODE TESTED : secondcalln()                                    }
{****************************************************************}
{ PRE-REQUISITES: secondload()                                   }
{                 secondassign()                                 }
{                 secondcalln()                                  }
{                 secondadd()                                    }
{                 secondtypeconv()                               }
{****************************************************************}
{ DEFINES:                                                       }
{****************************************************************}
{ REMARKS: This tests a subset of the secondcalln() , it         }
{          verifies procedural variables for register            }
{          calling conventions.                                  }
{****************************************************************}


{$R+}

const
   tcalpvr6_RESULT_U8BIT = $55;
   tcalpvr6_RESULT_U16BIT = $500F;
   tcalpvr6_RESULT_S32BIT = $500F0000;
   tcalpvr6_RESULT_S64BIT = -12000;

type

  tcalpvr6_troutine = procedure (x: longint;  y: byte);register;
  tcalpvr6_troutineresult = function (x: longint; y: byte): int64;register;

  tcalpvr6_tsimpleobject = object
    constructor init;
    procedure test_normal(x: byte);register;
    procedure test_static(x: byte);static;register;
    procedure test_virtual(x: byte);virtual;register;
  end;

  tcalpvr6_tsimpleclass = class
    constructor create;
    procedure test_normal(x: byte);register;
    class procedure test_static(x: byte);register;
    procedure test_virtual(x: byte);virtual;register;
  end;

  tcalpvr6_tobjectmethod = procedure (x: byte) of object ;register;
  tcalpvr6_tclassmethod = procedure (x: byte) of object;register;

var
  tcalpvr6_proc : tcalpvr6_troutine;
  tcalpvr6_func : tcalpvr6_troutineresult;
  tcalpvr6_obj_method : tcalpvr6_tobjectmethod;
  tcalpvr6_cla_method : tcalpvr6_tclassmethod;
  tcalpvr6_global_s32bit : longint;
  tcalpvr6_global_s64bit : int64;
  tcalpvr6_global_u8bit : byte;
  tcalpvr6_value_s32bit : longint;
  tcalpvr6_value_u8bit : byte;
  tcalpvr6_obj : tcalpvr6_tsimpleobject;
  tcalpvr6_cla : tcalpvr6_tsimpleclass;




  procedure tcalpvr6_fail;
   begin
     WriteLn('Failed!');
     halt(1);
   end;

  procedure tcalpvr6_clear_globals;
   begin
     tcalpvr6_global_s32bit := 0;
     tcalpvr6_global_u8bit := 0;
     tcalpvr6_global_s64bit := 0;
   end;

  procedure tcalpvr6_clear_values;
    begin
      tcalpvr6_value_s32bit := 0;
      tcalpvr6_value_u8bit := 0;
    end;


  procedure tcalpvr6_testroutine(x: longint; y: byte);register;
   begin
     tcalpvr6_global_s32bit := x;
     tcalpvr6_global_u8bit := y;
   end;

  function tcalpvr6_testroutineresult(x: longint; y: byte): int64;register;
   begin
     tcalpvr6_global_s32bit := x;
     tcalpvr6_global_u8bit := y;
     tcalpvr6_testroutineresult := tcalpvr6_RESULT_S64BIT;
   end;


  function tcalpvr6_getroutine: tcalpvr6_troutine;
    begin
      tcalpvr6_getroutine:=tcalpvr6_proc;
    end;

  function tcalpvr6_getroutineresult : tcalpvr6_troutineresult;
   begin
     tcalpvr6_getroutineresult := tcalpvr6_func;
   end;

{ IMPOSSIBLE TO DO CURRENTLY !
  function get_object_method_static : tnormalmethod;
   begin
     get_object_method_static := @obj.test_static;
   end;
}

  { objects access }
  function tcalpvr6_get_object_method_normal : tcalpvr6_tobjectmethod;
   begin
     tcalpvr6_get_object_method_normal := @tcalpvr6_obj.test_normal;
   end;

  function tcalpvr6_get_object_type_method_virtual : tcalpvr6_tobjectmethod;
   begin
     tcalpvr6_get_object_type_method_virtual := @tcalpvr6_obj.test_virtual;
   end;

  function tcalpvr6_get_object_method_virtual : tcalpvr6_tobjectmethod;
   begin
     tcalpvr6_get_object_method_virtual := @tcalpvr6_obj.test_virtual;
   end;

{
  HOW CAN WE GET THIS ADDRESS???
  function get_class_method_static_self : tclassmethodself;
   begin
     get_class_method_static_self := @cla.test_static_self;
   end;
}

  function tcalpvr6_get_class_method_normal : tcalpvr6_tclassmethod;
   begin
     tcalpvr6_get_class_method_normal := @tcalpvr6_cla.test_normal;
   end;
{
  function get_class_method_static : tclassmethod;
   begin
     get_class_method_static := @cla.test_static;
   end;}

  function tcalpvr6_get_class_method_virtual : tcalpvr6_tclassmethod;
   begin
     tcalpvr6_get_class_method_virtual := @tcalpvr6_cla.test_virtual;
   end;

 {****************************************************************************************************}

  constructor tcalpvr6_tsimpleobject.init;
   begin
   end;

  procedure tcalpvr6_tsimpleobject.test_normal(x: byte);register;
   begin
     tcalpvr6_global_u8bit := x;
   end;

  procedure tcalpvr6_tsimpleobject.test_static(x: byte);register;
   begin
     tcalpvr6_global_u8bit := x;
   end;

  procedure tcalpvr6_tsimpleobject.test_virtual(x: byte);register;
   begin
     tcalpvr6_global_u8bit := x;
   end;

 {****************************************************************************************************}
  constructor tcalpvr6_tsimpleclass.create;
   begin
    inherited create;
   end;

  procedure tcalpvr6_tsimpleclass. test_normal(x: byte);register;
   begin
     tcalpvr6_global_u8bit := x;
   end;

  class procedure tcalpvr6_tsimpleclass.test_static(x: byte);register;
   begin
     tcalpvr6_global_u8bit := x;
   end;

  procedure tcalpvr6_tsimpleclass.test_virtual(x: byte);register;
   begin
     tcalpvr6_global_u8bit := x;
   end;


var
 tcalpvr6_failed : boolean;

{$pop}

{ Case tcalpvr7.pp }
{$push}
{****************************************************************}
{  CODE GENERATOR TEST PROGRAM                                   }
{****************************************************************}
{ NODE TESTED : secondcalln()                                    }
{****************************************************************}
{ PRE-REQUISITES: secondload()                                   }
{                 secondassign()                                 }
{                 secondcalln()                                  }
{                 secondadd()                                    }
{                 secondtypeconv()                               }
{****************************************************************}
{ DEFINES:                                                       }
{****************************************************************}
{ REMARKS: This tests a subset of the secondcalln() , it         }
{          verifies procedural variables for stdcall             }
{          calling conventions.                                  }
{****************************************************************}


{$R+}

const
   tcalpvr7_RESULT_U8BIT = $55;
   tcalpvr7_RESULT_U16BIT = $500F;
   tcalpvr7_RESULT_S32BIT = $500F0000;
   tcalpvr7_RESULT_S64BIT = -12000;

type

  tcalpvr7_troutine = procedure (x: longint;  y: byte);stdcall;
  tcalpvr7_troutineresult = function (x: longint; y: byte): int64;stdcall;

  tcalpvr7_tsimpleobject = object
    constructor init;
    procedure test_normal(x: byte);stdcall;
    procedure test_static(x: byte);static;stdcall;
    procedure test_virtual(x: byte);virtual;stdcall;
  end;

  tcalpvr7_tsimpleclass = class
    constructor create;
    procedure test_normal(x: byte);stdcall;
    class procedure test_static(x: byte);stdcall;
    procedure test_virtual(x: byte);virtual;stdcall;
  end;

  tcalpvr7_tobjectmethod = procedure (x: byte) of object ;stdcall;
  tcalpvr7_tclassmethod = procedure (x: byte) of object;stdcall;

var
  tcalpvr7_proc : tcalpvr7_troutine;
  tcalpvr7_func : tcalpvr7_troutineresult;
  tcalpvr7_obj_method : tcalpvr7_tobjectmethod;
  tcalpvr7_cla_method : tcalpvr7_tclassmethod;
  tcalpvr7_global_s32bit : longint;
  tcalpvr7_global_s64bit : int64;
  tcalpvr7_global_u8bit : byte;
  tcalpvr7_value_s32bit : longint;
  tcalpvr7_value_u8bit : byte;
  tcalpvr7_obj : tcalpvr7_tsimpleobject;
  tcalpvr7_cla : tcalpvr7_tsimpleclass;




  procedure tcalpvr7_fail;
   begin
     WriteLn('Failed!');
     halt(1);
   end;

  procedure tcalpvr7_clear_globals;
   begin
     tcalpvr7_global_s32bit := 0;
     tcalpvr7_global_u8bit := 0;
     tcalpvr7_global_s64bit := 0;
   end;

  procedure tcalpvr7_clear_values;
    begin
      tcalpvr7_value_s32bit := 0;
      tcalpvr7_value_u8bit := 0;
    end;


  procedure tcalpvr7_testroutine(x: longint; y: byte);stdcall;
   begin
     tcalpvr7_global_s32bit := x;
     tcalpvr7_global_u8bit := y;
   end;

  function tcalpvr7_testroutineresult(x: longint; y: byte): int64;stdcall;
   begin
     tcalpvr7_global_s32bit := x;
     tcalpvr7_global_u8bit := y;
     tcalpvr7_testroutineresult := tcalpvr7_RESULT_S64BIT;
   end;


  function tcalpvr7_getroutine: tcalpvr7_troutine;
    begin
      tcalpvr7_getroutine:=tcalpvr7_proc;
    end;

  function tcalpvr7_getroutineresult : tcalpvr7_troutineresult;
   begin
     tcalpvr7_getroutineresult := tcalpvr7_func;
   end;

{ IMPOSSIBLE TO DO CURRENTLY !
  function get_object_method_static : tnormalmethod;
   begin
     get_object_method_static := @obj.test_static;
   end;
}

  { objects access }
  function tcalpvr7_get_object_method_normal : tcalpvr7_tobjectmethod;
   begin
     tcalpvr7_get_object_method_normal := @tcalpvr7_obj.test_normal;
   end;

  function tcalpvr7_get_object_type_method_virtual : tcalpvr7_tobjectmethod;
   begin
     tcalpvr7_get_object_type_method_virtual := @tcalpvr7_obj.test_virtual;
   end;

  function tcalpvr7_get_object_method_virtual : tcalpvr7_tobjectmethod;
   begin
     tcalpvr7_get_object_method_virtual := @tcalpvr7_obj.test_virtual;
   end;

{
  HOW CAN WE GET THIS ADDRESS???
  function get_class_method_static_self : tclassmethodself;
   begin
     get_class_method_static_self := @cla.test_static_self;
   end;
}

  function tcalpvr7_get_class_method_normal : tcalpvr7_tclassmethod;
   begin
     tcalpvr7_get_class_method_normal := @tcalpvr7_cla.test_normal;
   end;
{
  function get_class_method_static : tclassmethod;
   begin
     get_class_method_static := @cla.test_static;
   end;}

  function tcalpvr7_get_class_method_virtual : tcalpvr7_tclassmethod;
   begin
     tcalpvr7_get_class_method_virtual := @tcalpvr7_cla.test_virtual;
   end;

 {****************************************************************************************************}

  constructor tcalpvr7_tsimpleobject.init;
   begin
   end;

  procedure tcalpvr7_tsimpleobject.test_normal(x: byte);stdcall;
   begin
     tcalpvr7_global_u8bit := x;
   end;

  procedure tcalpvr7_tsimpleobject.test_static(x: byte);stdcall;
   begin
     tcalpvr7_global_u8bit := x;
   end;

  procedure tcalpvr7_tsimpleobject.test_virtual(x: byte);stdcall;
   begin
     tcalpvr7_global_u8bit := x;
   end;

 {****************************************************************************************************}
  constructor tcalpvr7_tsimpleclass.create;
   begin
    inherited create;
   end;

  procedure tcalpvr7_tsimpleclass. test_normal(x: byte);stdcall;
   begin
     tcalpvr7_global_u8bit := x;
   end;

  class procedure tcalpvr7_tsimpleclass.test_static(x: byte);stdcall;
   begin
     tcalpvr7_global_u8bit := x;
   end;

  procedure tcalpvr7_tsimpleclass.test_virtual(x: byte);stdcall;
   begin
     tcalpvr7_global_u8bit := x;
   end;


var
 tcalpvr7_failed : boolean;

{$pop}

{ Case tclacla1.pp }
{$push}




type
   tclacla1_tbaseclass = class
     x : longint;
     class procedure virtual_class_method; virtual;
     class procedure call_virtual_class_method;
   end;

   tclacla1_tderivedclass = class(tclacla1_tbaseclass)
     y : longint;
     class procedure virtual_class_method; override;
   end;

const
  tclacla1_tbasecalled : boolean = false;
  tclacla1_tderivedcalled : boolean = false;
  tclacla1_has_error : boolean = false;
class procedure tclacla1_tbaseclass.virtual_class_method;

begin
  Writeln('Calling tbase class class method');
  tclacla1_tbasecalled:=true;
end;

class procedure tclacla1_tbaseclass.call_virtual_class_method;
begin
  virtual_class_method;
end;

class procedure tclacla1_tderivedclass.virtual_class_method;

begin
  Writeln('Calling tderived class class method');
  tclacla1_tderivedcalled:=true;
end;

procedure tclacla1_reset_booleans;
begin
  tclacla1_tbasecalled:=false;
  tclacla1_tderivedcalled:=false;
end;

var
  tclacla1_c1,tclacla1_cb : tclacla1_tbaseclass;
  tclacla1_cd : tclacla1_tderivedclass;
  tclacla1_cc : class of tclacla1_tbaseclass;


{$pop}

{ Case tclasize.pp }
{$push}
{$ifdef fpc}{$else}{$J+}{$endif}

type
   tclasize_tbaseclass = class
     x : byte;
     class procedure virtual_class_method; virtual;
     class procedure call_virtual_class_method;
     class function getsize : longint;
     procedure check_size;
   end;

   tclasize_tderivedclass = class(tclasize_tbaseclass)
     y : byte;
     class procedure virtual_class_method; override;
   end;

const
  tclasize_tbasecalled : boolean = false;
  tclasize_tderivedcalled : boolean = false;
  tclasize_has_error : boolean = false;
  tclasize_expected_size_for_tbaseclass = sizeof(pointer) + sizeof(byte);
  tclasize_expected_size_for_tderivedclass = sizeof(pointer) + 2*sizeof(byte);

var
  tclasize_basesize : longint;
  tclasize_derivedsize : longint;

class procedure tclasize_tbaseclass.virtual_class_method;

begin
  Writeln('Calling tbase class class method');
  tclasize_tbasecalled:=true;
  if sizeof(self)<>tclasize_basesize then
    begin
      tclasize_has_error:=true;
      Writeln('Error with sizeof');
    end;
end;

class function tclasize_tbaseclass.getsize : longint;
begin
  getsize:=sizeof(self);
end;

procedure tclasize_tbaseclass.check_size;
begin
  if sizeof(self)<>getsize then
    begin
      Writeln('Compiler creates garbage');
      tclasize_has_error:=true;
    end;
end;

class procedure tclasize_tbaseclass.call_virtual_class_method;
begin
  virtual_class_method;
  if getsize<>sizeof(self) then
    begin
      Writeln('Compiler creates garbage');
      tclasize_has_error:=true;
    end;
end;

class procedure tclasize_tderivedclass.virtual_class_method;

begin
  Writeln('Calling tderived class class method');
  tclasize_tderivedcalled:=true;
  if sizeof(self)<>tclasize_derivedsize then
    begin
      tclasize_has_error:=true;
      Writeln('Error with sizeof');
    end;
end;

procedure tclasize_reset_booleans;
begin
  tclasize_tbasecalled:=false;
  tclasize_tderivedcalled:=false;
end;

type
  tclasize_tcl = class of tclasize_tbaseclass;

var
  tclasize_c1,tclasize_cb : tclasize_tbaseclass;
  tclasize_cd : tclasize_tderivedclass;
  tclasize_cc : tclasize_tcl;


{$pop}

{ Case tclatype.pp }
{$push}




type
   tclatype_tbaseclass = class
     x : longint;
     function get_type : pointer;
     function get_type2 : pointer;virtual;
     procedure check_type;
     class procedure virtual_class_method;virtual;
   end;

   tclatype_tderivedclass = class(tclatype_tbaseclass)
     y : longint;
     function get_type2 : pointer;override;
     class procedure virtual_class_method;override;
   end;

const
  tclatype_tbasecalled : boolean = false;
  tclatype_tderivedcalled : boolean = false;
  tclatype_has_error : boolean = false;
  tclatype_expected_size_for_tbaseclass = sizeof(pointer) + sizeof(longint);
  tclatype_expected_size_for_tderivedclass = sizeof(pointer) + 2*sizeof(longint);

var
  tclatype_basesize : longint;
  tclatype_derivedsize : longint;

function tclatype_tbaseclass.get_type : pointer;
begin
  get_type:=typeof(self);
end;

function tclatype_tbaseclass.get_type2 : pointer;
begin
  get_type2:=typeof(self);
end;

procedure tclatype_tbaseclass.check_type;
begin
  if typeof(self)<>get_type then
    begin
      Writeln('Compiler creates garbage');
      tclatype_has_error:=true;
    end;
  if typeof(self)<>get_type2 then
    begin
      Writeln('Compiler creates garbage');
      tclatype_has_error:=true;
    end;
  if get_type<>get_type2 then
    begin
      Writeln('get_type and get_type2 return different pointers');
      tclatype_has_error:=true;
    end;
end;

class procedure tclatype_tbaseclass.virtual_class_method;
begin
  Writeln('Calling tbase class class method');
  tclatype_tbasecalled:=true;
  if sizeof(self)<>tclatype_basesize then
    begin
      tclatype_has_error:=true;
      Writeln('Error with sizeof');
    end;
end;

function tclatype_tderivedclass.get_type2 : pointer;
begin
  get_type2:=typeof(self);
end;

class procedure tclatype_tderivedclass.virtual_class_method;
begin
  Writeln('Calling tderived class class method');
  tclatype_tderivedcalled:=true;
  if sizeof(self)<>tclatype_derivedsize then
    begin
      tclatype_has_error:=true;
      Writeln('Error with sizeof');
    end;
end;

procedure tclatype_reset_booleans;
begin
  tclatype_tbasecalled:=false;
  tclatype_tderivedcalled:=false;
end;

var
  tclatype_c1,tclatype_cb : tclatype_tbaseclass;
  tclatype_cd : tclatype_tderivedclass;
  tclatype_cc : class of tclatype_tbaseclass;
  tclatype_pb,tclatype_pd : pointer;


{$pop}

{ Case tctr1.pp }
{$push}
{$h+}

type
  tctr1_tobj=class(TObject)
    ffield:boolean;
    constructor Create;
    procedure AfterConstruction;override;
  end;

{ Exit statement in constructor must not jump over AfterConstruction! }
constructor tctr1_tobj.Create;
begin
  exit;
end;

procedure tctr1_tobj.AfterConstruction;
begin
  ffield:=true;
end;


var
  tctr1_o: tctr1_tobj;

{$pop}

{ Case texit2.pp }
{$push}


{ Tests proper setting of fc_no_direct_exit in flowcontrol when the exit statement jumps
  to an extra code instead of immediately finishing execution of the current routine. }

type
  texit2_TSymtable = class
  public
    name      : pshortstring;
    realname  : pshortstring;
    DefList   : TObject;
    SymList   : TObject;
    refcount  : smallint;
    destructor  destroy;override;
    procedure clear;virtual;
    procedure freeinstance;override;
    procedure test_inline_with_exit;virtual;
  end;

var
  texit2_st: texit2_TSymtable;

  procedure texit2_stringdispose(var p : pshortstring); inline;
  begin
   if assigned(p) then
     begin
       freemem(p);
       p:=nil;
     end;
  end;

  procedure texit2_cproc(a,b,c: longint); cdecl;
  begin
  end;

  procedure texit2_inline_with_exit(a,b,c: longint); inline;
  begin
    if a = 12345 then
      exit;
    texit2_cproc(a,b,c);
  end;

  procedure texit2_inline_error;
  begin
    writeln('Inline with exit error.');
    halt(3);
  end;

  procedure texit2_TSymtable.test_inline_with_exit;
  var
    i,j: integer;
  begin
    i:=12345;
    j:=1;
    texit2_stringdispose(name);
    texit2_inline_with_exit(i,j,i+j);
    if i<>12345 then
      texit2_inline_error;
    Inc(i);
    Inc(j);
    texit2_stringdispose(name);
  end;

  procedure texit2_TSymtable.clear;
  begin
  end;

  destructor texit2_TSymtable.destroy;
    var i: longint;
    begin
      i:=1;
      if refcount=0 then
        exit;
      Clear;
      DefList.Free;
      SymList.Free;
      texit2_stringdispose(name);
      texit2_stringdispose(realname);
      refcount:=i;
      { freeinstance is implicitly called here even when 'exit' is executed }
    end;

    procedure texit2_TSymtable.freeinstance;
      begin
        writeln('freeinstance');
        if Self <> texit2_st then
          begin
            writeln('Incorrect self.');
            Halt(1);
          end;

        inherited freeinstance;
        texit2_st:=nil;
      end;


{$pop}

{ Case tloadvmt.pp }
{$push}
{****************************************************************}
{  CODE GENERATOR TEST PROGRAM                                   }
{  By Carl Eric Codere                                           }
{****************************************************************}
{ NODE TESTED : secondloadvmt()                                  }
{****************************************************************}
{ DEFINES:                                                       }
{            FPC     = Target is FreePascal compiler             }
{****************************************************************}
{ REMARKS : Tested with Delphi 3 as reference implementation     }
{****************************************************************}


{$ifdef fpc}

{$endif}

const
  tloadvmt_RESULT_STRING = 'Hello world';

Type
  tloadvmt_TAObject = class(TObject)
    a : longint;
    end;
  tloadvmt_TBObject = Class(tloadvmt_TAObject)
    b : longint;
    s : shortstring;
      constructor create(c: longint);
      function getstring : shortstring;
    end;


    procedure tloadvmt_fail;
    begin
      WriteLn('Failure.');
      halt(1);
    end;


 constructor tloadvmt_tbobject.create(c:longint);
  begin
    tloadvmt_taobject.create;
    b:=c;
    s:=tloadvmt_RESULT_STRING;
  end;

 function tloadvmt_tbobject.getstring : shortstring;
  begin
    getstring := s;
  end;


var
 tloadvmt_bobj: tloadvmt_TBobject;
 tloadvmt_i: integer;
 tloadvmt_l : longint;

{$pop}

begin

{ Case tcalpvr1.pp }
{$push}

{$R+}
Begin
 { setup variables }
 tcalpvr1_proc := @tcalpvr1_testroutine;
 tcalpvr1_func := @tcalpvr1_testroutineresult;
 tcalpvr1_obj.init;
 tcalpvr1_cla:=tcalpvr1_tsimpleclass.create;

 {****************************************************************************************************}

 Write('Testing procedure variable call (LOC_REGISTER)..');

 tcalpvr1_clear_globals;
 tcalpvr1_clear_values;
 tcalpvr1_failed := false;

 { parameters in LOC_CONSTANT, routine address in LOC_REGISTER }
 tcalpvr1_troutine(tcalpvr1_getroutine)(tcalpvr1_RESULT_S32BIT,tcalpvr1_RESULT_U8BIT);
 if tcalpvr1_global_u8bit <> tcalpvr1_RESULT_U8BIT then
   tcalpvr1_failed := true;
 if tcalpvr1_global_s32bit <> tcalpvr1_RESULT_S32BIT then
   tcalpvr1_failed := true;

 tcalpvr1_clear_globals;
 tcalpvr1_clear_values;
 { parameters in LOC_REFERENCE,routine address in LOC_REGISTER }
 tcalpvr1_value_s32bit := tcalpvr1_RESULT_S32BIT;
 tcalpvr1_value_u8bit := tcalpvr1_RESULT_U8BIT;
 tcalpvr1_troutine(tcalpvr1_getroutine)(tcalpvr1_value_s32bit , tcalpvr1_value_u8bit);
 if tcalpvr1_global_u8bit <> tcalpvr1_RESULT_U8BIT then
   tcalpvr1_failed := true;
 if tcalpvr1_global_s32bit <> tcalpvr1_RESULT_S32BIT then
   tcalpvr1_failed := true;

 If tcalpvr1_failed then
   tcalpvr1_fail
 else
   WriteLn('Passed!');


 Write('Testing procedure variable call (LOC_REFERENCE)..');

 tcalpvr1_clear_globals;
 tcalpvr1_clear_values;
 tcalpvr1_failed := false;

 { parameters in LOC_CONSTANT, routine address in LOC_REGISTER }
 tcalpvr1_proc(tcalpvr1_RESULT_S32BIT,tcalpvr1_RESULT_U8BIT);
 if tcalpvr1_global_u8bit <> tcalpvr1_RESULT_U8BIT then
   tcalpvr1_failed := true;
 if tcalpvr1_global_s32bit <> tcalpvr1_RESULT_S32BIT then
   tcalpvr1_failed := true;

 tcalpvr1_clear_globals;
 tcalpvr1_clear_values;
 { parameters in LOC_REFERENCE,routine address in LOC_REGISTER }
 tcalpvr1_value_s32bit := tcalpvr1_RESULT_S32BIT;
 tcalpvr1_value_u8bit := tcalpvr1_RESULT_U8BIT;
 tcalpvr1_proc(tcalpvr1_value_s32bit , tcalpvr1_value_u8bit);
 if tcalpvr1_global_u8bit <> tcalpvr1_RESULT_U8BIT then
   tcalpvr1_failed := true;
 if tcalpvr1_global_s32bit <> tcalpvr1_RESULT_S32BIT then
   tcalpvr1_failed := true;

 If tcalpvr1_failed then
   tcalpvr1_fail
 else
   WriteLn('Passed!');
 {****************************************************************************************************}
 Write('Testing function variable call (LOC_REGISTER)..');

 tcalpvr1_clear_globals;
 tcalpvr1_clear_values;
 tcalpvr1_failed := false;

 { parameters in LOC_CONSTANT, routine address in LOC_REGISTER }
 tcalpvr1_global_s64bit := tcalpvr1_troutineresult(tcalpvr1_getroutineresult)(tcalpvr1_RESULT_S32BIT,tcalpvr1_RESULT_U8BIT);
 if tcalpvr1_global_u8bit <> tcalpvr1_RESULT_U8BIT then
   tcalpvr1_failed := true;
 if tcalpvr1_global_s32bit <> tcalpvr1_RESULT_S32BIT then
   tcalpvr1_failed := true;
 if tcalpvr1_global_s64bit <> tcalpvr1_RESULT_S64BIT then
   tcalpvr1_failed := true;

 tcalpvr1_clear_globals;
 tcalpvr1_clear_values;
 { parameters in LOC_REFERENCE,routine address in LOC_REGISTER }
 tcalpvr1_value_s32bit := tcalpvr1_RESULT_S32BIT;
 tcalpvr1_value_u8bit := tcalpvr1_RESULT_U8BIT;
 tcalpvr1_global_s64bit := tcalpvr1_troutineresult(tcalpvr1_getroutineresult)(tcalpvr1_value_s32bit , tcalpvr1_value_u8bit);
 if tcalpvr1_global_u8bit <> tcalpvr1_RESULT_U8BIT then
   tcalpvr1_failed := true;
 if tcalpvr1_global_s32bit <> tcalpvr1_RESULT_S32BIT then
   tcalpvr1_failed := true;
 if tcalpvr1_global_s64bit <> tcalpvr1_RESULT_S64BIT then
   tcalpvr1_failed := true;

 If tcalpvr1_failed then
   tcalpvr1_fail
 else
   WriteLn('Passed!');


 Write('Testing function variable call (LOC_REFERENCE)..');

 tcalpvr1_clear_globals;
 tcalpvr1_clear_values;
 tcalpvr1_failed := false;

 { parameters in LOC_CONSTANT, routine address in LOC_REGISTER }
 tcalpvr1_global_s64bit := tcalpvr1_func(tcalpvr1_RESULT_S32BIT,tcalpvr1_RESULT_U8BIT);
 if tcalpvr1_global_u8bit <> tcalpvr1_RESULT_U8BIT then
   tcalpvr1_failed := true;
 if tcalpvr1_global_s32bit <> tcalpvr1_RESULT_S32BIT then
   tcalpvr1_failed := true;
 if tcalpvr1_global_s64bit <> tcalpvr1_RESULT_S64BIT then
   tcalpvr1_failed := true;

 tcalpvr1_clear_globals;
 tcalpvr1_clear_values;
 { parameters in LOC_REFERENCE,routine address in LOC_REGISTER }
 tcalpvr1_value_s32bit := tcalpvr1_RESULT_S32BIT;
 tcalpvr1_value_u8bit := tcalpvr1_RESULT_U8BIT;
 tcalpvr1_global_s64bit := tcalpvr1_func(tcalpvr1_value_s32bit , tcalpvr1_value_u8bit);
 if tcalpvr1_global_u8bit <> tcalpvr1_RESULT_U8BIT then
   tcalpvr1_failed := true;
 if tcalpvr1_global_s32bit <> tcalpvr1_RESULT_S32BIT then
   tcalpvr1_failed := true;
 if tcalpvr1_global_s64bit <> tcalpvr1_RESULT_S64BIT then
   tcalpvr1_failed := true;

 If tcalpvr1_failed then
   tcalpvr1_fail
 else
   WriteLn('Passed!');
 {****************************************************************************************************}
 Write('Testing object method variable call (LOC_REGISTER) ..');

 tcalpvr1_clear_globals;
 tcalpvr1_clear_values;
 tcalpvr1_failed := false;

 tcalpvr1_tobjectmethod(tcalpvr1_get_object_method_normal)(tcalpvr1_RESULT_U8BIT);
 if tcalpvr1_global_u8bit <> tcalpvr1_RESULT_U8BIT then
   tcalpvr1_failed := true;

 tcalpvr1_clear_globals;
 tcalpvr1_clear_values;

 tcalpvr1_tobjectmethod(tcalpvr1_get_object_type_method_virtual)(tcalpvr1_RESULT_U8BIT);
 if tcalpvr1_global_u8bit <> tcalpvr1_RESULT_U8BIT then
   tcalpvr1_failed := true;

 tcalpvr1_clear_globals;
 tcalpvr1_clear_values;

 tcalpvr1_tobjectmethod(tcalpvr1_get_object_method_virtual)(tcalpvr1_RESULT_U8BIT);
 if tcalpvr1_global_u8bit <> tcalpvr1_RESULT_U8BIT then
   tcalpvr1_failed := true;

 tcalpvr1_clear_globals;
 tcalpvr1_clear_values;

 tcalpvr1_value_u8bit := tcalpvr1_RESULT_U8BIT;
 tcalpvr1_tobjectmethod(tcalpvr1_get_object_method_normal)(tcalpvr1_value_u8bit);
 if tcalpvr1_global_u8bit <> tcalpvr1_RESULT_U8BIT then
   tcalpvr1_failed := true;

 tcalpvr1_clear_globals;
 tcalpvr1_clear_values;

 tcalpvr1_value_u8bit := tcalpvr1_RESULT_U8BIT;
 tcalpvr1_tobjectmethod(tcalpvr1_get_object_type_method_virtual)(tcalpvr1_value_u8bit);
 if tcalpvr1_global_u8bit <> tcalpvr1_RESULT_U8BIT then
   tcalpvr1_failed := true;

 tcalpvr1_clear_globals;
 tcalpvr1_clear_values;

 tcalpvr1_value_u8bit := tcalpvr1_RESULT_U8BIT;
 tcalpvr1_tobjectmethod(tcalpvr1_get_object_method_virtual)(tcalpvr1_value_u8bit);
 if tcalpvr1_global_u8bit <> tcalpvr1_RESULT_U8BIT then
   tcalpvr1_failed := true;


 If tcalpvr1_failed then
   tcalpvr1_fail
 else
   WriteLn('Passed!');

 Write('Testing object method variable call (LOC_REFERENCE) ..');

 tcalpvr1_clear_globals;
 tcalpvr1_clear_values;
 tcalpvr1_failed := false;

 tcalpvr1_obj_method:=@tcalpvr1_obj.test_normal;
 tcalpvr1_obj_method(tcalpvr1_RESULT_U8BIT);
 if tcalpvr1_global_u8bit <> tcalpvr1_RESULT_U8BIT then
   tcalpvr1_failed := true;

 tcalpvr1_clear_globals;
 tcalpvr1_clear_values;

 tcalpvr1_obj_method:=@tcalpvr1_obj.test_virtual;
 tcalpvr1_obj_method(tcalpvr1_RESULT_U8BIT);
 if tcalpvr1_global_u8bit <> tcalpvr1_RESULT_U8BIT then
   tcalpvr1_failed := true;

 tcalpvr1_clear_globals;
 tcalpvr1_clear_values;

 tcalpvr1_obj_method:=@tcalpvr1_obj.test_virtual;
 tcalpvr1_obj_method(tcalpvr1_RESULT_U8BIT);
 if tcalpvr1_global_u8bit <> tcalpvr1_RESULT_U8BIT then
   tcalpvr1_failed := true;

 tcalpvr1_clear_globals;
 tcalpvr1_clear_values;

 tcalpvr1_value_u8bit := tcalpvr1_RESULT_U8BIT;
 tcalpvr1_obj_method:=@tcalpvr1_obj.test_normal;
 tcalpvr1_obj_method(tcalpvr1_value_u8bit);
 if tcalpvr1_global_u8bit <> tcalpvr1_RESULT_U8BIT then
   tcalpvr1_failed := true;

 tcalpvr1_clear_globals;
 tcalpvr1_clear_values;

 tcalpvr1_value_u8bit := tcalpvr1_RESULT_U8BIT;
 tcalpvr1_obj_method:=@tcalpvr1_obj.test_virtual;
 tcalpvr1_obj_method(tcalpvr1_value_u8bit);
 if tcalpvr1_global_u8bit <> tcalpvr1_RESULT_U8BIT then
   tcalpvr1_failed := true;

 tcalpvr1_clear_globals;
 tcalpvr1_clear_values;

 tcalpvr1_value_u8bit := tcalpvr1_RESULT_U8BIT;
 tcalpvr1_obj_method:=@tcalpvr1_obj.test_normal;
 tcalpvr1_obj_method(tcalpvr1_value_u8bit);
 if tcalpvr1_global_u8bit <> tcalpvr1_RESULT_U8BIT then
   tcalpvr1_failed := true;


 If tcalpvr1_failed then
   tcalpvr1_fail
 else
   WriteLn('Passed!');

 {****************************************************************************************************}
 Write('Testing class method variable call (LOC_REGISTER) ..');

 tcalpvr1_clear_globals;
 tcalpvr1_clear_values;
 tcalpvr1_failed := false;

 tcalpvr1_tclassmethod(tcalpvr1_get_class_method_normal)(tcalpvr1_RESULT_U8BIT);
 if tcalpvr1_global_u8bit <> tcalpvr1_RESULT_U8BIT then
   tcalpvr1_failed := true;

 If tcalpvr1_failed then
   tcalpvr1_fail
 else
   WriteLn('Passed!');


 tcalpvr1_clear_globals;
 tcalpvr1_clear_values;


 tcalpvr1_tclassmethod(tcalpvr1_get_class_method_virtual)(tcalpvr1_RESULT_U8BIT);
 if tcalpvr1_global_u8bit <> tcalpvr1_RESULT_U8BIT then
   tcalpvr1_failed := true;

 tcalpvr1_clear_globals;
 tcalpvr1_clear_values;


 Write('Testing class method variable call (LOC_REFERENCE)...');

 tcalpvr1_clear_globals;
 tcalpvr1_clear_values;
 tcalpvr1_failed := false;

 tcalpvr1_cla_method := @tcalpvr1_cla.test_normal;
 tcalpvr1_cla_method(tcalpvr1_RESULT_U8BIT);
 if tcalpvr1_global_u8bit <> tcalpvr1_RESULT_U8BIT then
   tcalpvr1_failed := true;

 tcalpvr1_clear_globals;
 tcalpvr1_clear_values;


 tcalpvr1_cla_method := @tcalpvr1_cla.test_virtual;
 tcalpvr1_cla_method(tcalpvr1_RESULT_U8BIT);
 if tcalpvr1_global_u8bit <> tcalpvr1_RESULT_U8BIT then
   tcalpvr1_failed := true;

 tcalpvr1_clear_globals;
 tcalpvr1_clear_values;

 tcalpvr1_cla_method := @tcalpvr1_cla.test_virtual;
 tcalpvr1_cla_method(tcalpvr1_RESULT_U8BIT);
 if tcalpvr1_global_u8bit <> tcalpvr1_RESULT_U8BIT then
   tcalpvr1_failed := true;

 tcalpvr1_clear_globals;
 tcalpvr1_clear_values;

{ cla_method := @cla.test_static;
 cla_method(RESULT_U8BIT);
 if global_u8bit <> RESULT_U8BIT then
   failed := true;}

 tcalpvr1_clear_globals;
 tcalpvr1_clear_values;


{ cla_method := @cla.test_static;
 cla_method(RESULT_U8BIT);
 if global_u8bit <> RESULT_U8BIT then
   failed := true;}

 If tcalpvr1_failed then
   tcalpvr1_fail
 else
   WriteLn('Passed!');

end;
{$pop}

{ Case tcalpvr2.pp }
{$push}

{$R+}
Begin
 { setup variables }
 tcalpvr2_proc := @tcalpvr2_testroutine;
 tcalpvr2_func := @tcalpvr2_testroutineresult;
 tcalpvr2_obj.init;
 tcalpvr2_cla:=tcalpvr2_tsimpleclass.create;

 {****************************************************************************************************}

 Write('Testing procedure variable call (LOC_REGISTER)..');

 tcalpvr2_clear_globals;
 tcalpvr2_clear_values;
 tcalpvr2_failed := false;

 { parameters in LOC_CONSTANT, routine address in LOC_REGISTER }
 tcalpvr2_troutine(tcalpvr2_getroutine)(tcalpvr2_RESULT_S32BIT,tcalpvr2_RESULT_U8BIT);
 if tcalpvr2_global_u8bit <> tcalpvr2_RESULT_U8BIT then
   tcalpvr2_failed := true;
 if tcalpvr2_global_s32bit <> tcalpvr2_RESULT_S32BIT then
   tcalpvr2_failed := true;

 tcalpvr2_clear_globals;
 tcalpvr2_clear_values;
 { parameters in LOC_REFERENCE,routine address in LOC_REGISTER }
 tcalpvr2_value_s32bit := tcalpvr2_RESULT_S32BIT;
 tcalpvr2_value_u8bit := tcalpvr2_RESULT_U8BIT;
 tcalpvr2_troutine(tcalpvr2_getroutine)(tcalpvr2_value_s32bit , tcalpvr2_value_u8bit);
 if tcalpvr2_global_u8bit <> tcalpvr2_RESULT_U8BIT then
   tcalpvr2_failed := true;
 if tcalpvr2_global_s32bit <> tcalpvr2_RESULT_S32BIT then
   tcalpvr2_failed := true;

 If tcalpvr2_failed then
   tcalpvr2_fail
 else
   WriteLn('Passed!');


 Write('Testing procedure variable call (LOC_REFERENCE)..');

 tcalpvr2_clear_globals;
 tcalpvr2_clear_values;
 tcalpvr2_failed := false;

 { parameters in LOC_CONSTANT, routine address in LOC_REGISTER }
 tcalpvr2_proc(tcalpvr2_RESULT_S32BIT,tcalpvr2_RESULT_U8BIT);
 if tcalpvr2_global_u8bit <> tcalpvr2_RESULT_U8BIT then
   tcalpvr2_failed := true;
 if tcalpvr2_global_s32bit <> tcalpvr2_RESULT_S32BIT then
   tcalpvr2_failed := true;

 tcalpvr2_clear_globals;
 tcalpvr2_clear_values;
 { parameters in LOC_REFERENCE,routine address in LOC_REGISTER }
 tcalpvr2_value_s32bit := tcalpvr2_RESULT_S32BIT;
 tcalpvr2_value_u8bit := tcalpvr2_RESULT_U8BIT;
 tcalpvr2_proc(tcalpvr2_value_s32bit , tcalpvr2_value_u8bit);
 if tcalpvr2_global_u8bit <> tcalpvr2_RESULT_U8BIT then
   tcalpvr2_failed := true;
 if tcalpvr2_global_s32bit <> tcalpvr2_RESULT_S32BIT then
   tcalpvr2_failed := true;

 If tcalpvr2_failed then
   tcalpvr2_fail
 else
   WriteLn('Passed!');
 {****************************************************************************************************}
 Write('Testing function variable call (LOC_REGISTER)..');

 tcalpvr2_clear_globals;
 tcalpvr2_clear_values;
 tcalpvr2_failed := false;

 { parameters in LOC_CONSTANT, routine address in LOC_REGISTER }
 tcalpvr2_global_s64bit := tcalpvr2_troutineresult(tcalpvr2_getroutineresult)(tcalpvr2_RESULT_S32BIT,tcalpvr2_RESULT_U8BIT);
 if tcalpvr2_global_u8bit <> tcalpvr2_RESULT_U8BIT then
   tcalpvr2_failed := true;
 if tcalpvr2_global_s32bit <> tcalpvr2_RESULT_S32BIT then
   tcalpvr2_failed := true;
 if tcalpvr2_global_s64bit <> tcalpvr2_RESULT_S64BIT then
   tcalpvr2_failed := true;

 tcalpvr2_clear_globals;
 tcalpvr2_clear_values;
 { parameters in LOC_REFERENCE,routine address in LOC_REGISTER }
 tcalpvr2_value_s32bit := tcalpvr2_RESULT_S32BIT;
 tcalpvr2_value_u8bit := tcalpvr2_RESULT_U8BIT;
 tcalpvr2_global_s64bit := tcalpvr2_troutineresult(tcalpvr2_getroutineresult)(tcalpvr2_value_s32bit , tcalpvr2_value_u8bit);
 if tcalpvr2_global_u8bit <> tcalpvr2_RESULT_U8BIT then
   tcalpvr2_failed := true;
 if tcalpvr2_global_s32bit <> tcalpvr2_RESULT_S32BIT then
   tcalpvr2_failed := true;
 if tcalpvr2_global_s64bit <> tcalpvr2_RESULT_S64BIT then
   tcalpvr2_failed := true;

 If tcalpvr2_failed then
   tcalpvr2_fail
 else
   WriteLn('Passed!');


 Write('Testing function variable call (LOC_REFERENCE)..');

 tcalpvr2_clear_globals;
 tcalpvr2_clear_values;
 tcalpvr2_failed := false;

 { parameters in LOC_CONSTANT, routine address in LOC_REGISTER }
 tcalpvr2_global_s64bit := tcalpvr2_func(tcalpvr2_RESULT_S32BIT,tcalpvr2_RESULT_U8BIT);
 if tcalpvr2_global_u8bit <> tcalpvr2_RESULT_U8BIT then
   tcalpvr2_failed := true;
 if tcalpvr2_global_s32bit <> tcalpvr2_RESULT_S32BIT then
   tcalpvr2_failed := true;
 if tcalpvr2_global_s64bit <> tcalpvr2_RESULT_S64BIT then
   tcalpvr2_failed := true;

 tcalpvr2_clear_globals;
 tcalpvr2_clear_values;
 { parameters in LOC_REFERENCE,routine address in LOC_REGISTER }
 tcalpvr2_value_s32bit := tcalpvr2_RESULT_S32BIT;
 tcalpvr2_value_u8bit := tcalpvr2_RESULT_U8BIT;
 tcalpvr2_global_s64bit := tcalpvr2_func(tcalpvr2_value_s32bit , tcalpvr2_value_u8bit);
 if tcalpvr2_global_u8bit <> tcalpvr2_RESULT_U8BIT then
   tcalpvr2_failed := true;
 if tcalpvr2_global_s32bit <> tcalpvr2_RESULT_S32BIT then
   tcalpvr2_failed := true;
 if tcalpvr2_global_s64bit <> tcalpvr2_RESULT_S64BIT then
   tcalpvr2_failed := true;

 If tcalpvr2_failed then
   tcalpvr2_fail
 else
   WriteLn('Passed!');
 {****************************************************************************************************}
 Write('Testing object method variable call (LOC_REGISTER) ..');

 tcalpvr2_clear_globals;
 tcalpvr2_clear_values;
 tcalpvr2_failed := false;

 tcalpvr2_tobjectmethod(tcalpvr2_get_object_method_normal)(tcalpvr2_RESULT_U8BIT);
 if tcalpvr2_global_u8bit <> tcalpvr2_RESULT_U8BIT then
   tcalpvr2_failed := true;

 tcalpvr2_clear_globals;
 tcalpvr2_clear_values;

 tcalpvr2_tobjectmethod(tcalpvr2_get_object_type_method_virtual)(tcalpvr2_RESULT_U8BIT);
 if tcalpvr2_global_u8bit <> tcalpvr2_RESULT_U8BIT then
   tcalpvr2_failed := true;

 tcalpvr2_clear_globals;
 tcalpvr2_clear_values;

 tcalpvr2_tobjectmethod(tcalpvr2_get_object_method_virtual)(tcalpvr2_RESULT_U8BIT);
 if tcalpvr2_global_u8bit <> tcalpvr2_RESULT_U8BIT then
   tcalpvr2_failed := true;

 tcalpvr2_clear_globals;
 tcalpvr2_clear_values;

 tcalpvr2_value_u8bit := tcalpvr2_RESULT_U8BIT;
 tcalpvr2_tobjectmethod(tcalpvr2_get_object_method_normal)(tcalpvr2_value_u8bit);
 if tcalpvr2_global_u8bit <> tcalpvr2_RESULT_U8BIT then
   tcalpvr2_failed := true;

 tcalpvr2_clear_globals;
 tcalpvr2_clear_values;

 tcalpvr2_value_u8bit := tcalpvr2_RESULT_U8BIT;
 tcalpvr2_tobjectmethod(tcalpvr2_get_object_type_method_virtual)(tcalpvr2_value_u8bit);
 if tcalpvr2_global_u8bit <> tcalpvr2_RESULT_U8BIT then
   tcalpvr2_failed := true;

 tcalpvr2_clear_globals;
 tcalpvr2_clear_values;

 tcalpvr2_value_u8bit := tcalpvr2_RESULT_U8BIT;
 tcalpvr2_tobjectmethod(tcalpvr2_get_object_method_virtual)(tcalpvr2_value_u8bit);
 if tcalpvr2_global_u8bit <> tcalpvr2_RESULT_U8BIT then
   tcalpvr2_failed := true;


 If tcalpvr2_failed then
   tcalpvr2_fail
 else
   WriteLn('Passed!');

 Write('Testing object method variable call (LOC_REFERENCE) ..');

 tcalpvr2_clear_globals;
 tcalpvr2_clear_values;
 tcalpvr2_failed := false;

 tcalpvr2_obj_method:=@tcalpvr2_obj.test_normal;
 tcalpvr2_obj_method(tcalpvr2_RESULT_U8BIT);
 if tcalpvr2_global_u8bit <> tcalpvr2_RESULT_U8BIT then
   tcalpvr2_failed := true;

 tcalpvr2_clear_globals;
 tcalpvr2_clear_values;

 tcalpvr2_obj_method:=@tcalpvr2_obj.test_virtual;
 tcalpvr2_obj_method(tcalpvr2_RESULT_U8BIT);
 if tcalpvr2_global_u8bit <> tcalpvr2_RESULT_U8BIT then
   tcalpvr2_failed := true;

 tcalpvr2_clear_globals;
 tcalpvr2_clear_values;

 tcalpvr2_obj_method:=@tcalpvr2_obj.test_virtual;
 tcalpvr2_obj_method(tcalpvr2_RESULT_U8BIT);
 if tcalpvr2_global_u8bit <> tcalpvr2_RESULT_U8BIT then
   tcalpvr2_failed := true;

 tcalpvr2_clear_globals;
 tcalpvr2_clear_values;

 tcalpvr2_value_u8bit := tcalpvr2_RESULT_U8BIT;
 tcalpvr2_obj_method:=@tcalpvr2_obj.test_normal;
 tcalpvr2_obj_method(tcalpvr2_value_u8bit);
 if tcalpvr2_global_u8bit <> tcalpvr2_RESULT_U8BIT then
   tcalpvr2_failed := true;

 tcalpvr2_clear_globals;
 tcalpvr2_clear_values;

 tcalpvr2_value_u8bit := tcalpvr2_RESULT_U8BIT;
 tcalpvr2_obj_method:=@tcalpvr2_obj.test_virtual;
 tcalpvr2_obj_method(tcalpvr2_value_u8bit);
 if tcalpvr2_global_u8bit <> tcalpvr2_RESULT_U8BIT then
   tcalpvr2_failed := true;

 tcalpvr2_clear_globals;
 tcalpvr2_clear_values;

 tcalpvr2_value_u8bit := tcalpvr2_RESULT_U8BIT;
 tcalpvr2_obj_method:=@tcalpvr2_obj.test_normal;
 tcalpvr2_obj_method(tcalpvr2_value_u8bit);
 if tcalpvr2_global_u8bit <> tcalpvr2_RESULT_U8BIT then
   tcalpvr2_failed := true;


 If tcalpvr2_failed then
   tcalpvr2_fail
 else
   WriteLn('Passed!');

 {****************************************************************************************************}
 Write('Testing class method variable call (LOC_REGISTER) ..');

 tcalpvr2_clear_globals;
 tcalpvr2_clear_values;
 tcalpvr2_failed := false;

 tcalpvr2_tclassmethod(tcalpvr2_get_class_method_normal)(tcalpvr2_RESULT_U8BIT);
 if tcalpvr2_global_u8bit <> tcalpvr2_RESULT_U8BIT then
   tcalpvr2_failed := true;

 tcalpvr2_clear_globals;
 tcalpvr2_clear_values;


 tcalpvr2_tclassmethod(tcalpvr2_get_class_method_virtual)(tcalpvr2_RESULT_U8BIT);
 if tcalpvr2_global_u8bit <> tcalpvr2_RESULT_U8BIT then
   tcalpvr2_failed := true;

 If tcalpvr2_failed then
   tcalpvr2_fail
 else
   WriteLn('Passed!');

 Write('Testing class method variable call (LOC_REFERENCE)...');

 tcalpvr2_clear_globals;
 tcalpvr2_clear_values;
 tcalpvr2_failed := false;


 tcalpvr2_cla_method := @tcalpvr2_cla.test_normal;
 tcalpvr2_cla_method(tcalpvr2_RESULT_U8BIT);
 if tcalpvr2_global_u8bit <> tcalpvr2_RESULT_U8BIT then
   tcalpvr2_failed := true;

 tcalpvr2_clear_globals;
 tcalpvr2_clear_values;


 tcalpvr2_cla_method := @tcalpvr2_cla.test_virtual;
 tcalpvr2_cla_method(tcalpvr2_RESULT_U8BIT);
 if tcalpvr2_global_u8bit <> tcalpvr2_RESULT_U8BIT then
   tcalpvr2_failed := true;

 tcalpvr2_clear_globals;
 tcalpvr2_clear_values;

 tcalpvr2_cla_method := @tcalpvr2_cla.test_virtual;
 tcalpvr2_cla_method(tcalpvr2_RESULT_U8BIT);
 if tcalpvr2_global_u8bit <> tcalpvr2_RESULT_U8BIT then
   tcalpvr2_failed := true;

 tcalpvr2_clear_globals;
 tcalpvr2_clear_values;

{ cla_method := @cla.test_static;
 cla_method(RESULT_U8BIT);
 if global_u8bit <> RESULT_U8BIT then
   failed := true;}

 tcalpvr2_clear_globals;
 tcalpvr2_clear_values;


{ cla_method := @cla.test_static;
 cla_method(RESULT_U8BIT);
 if global_u8bit <> RESULT_U8BIT then
   failed := true;}

 If tcalpvr2_failed then
   tcalpvr2_fail
 else
   WriteLn('Passed!');

end;
{$pop}

{ Case tcalpvr3.pp }
{$push}

{$R+}
{$ifndef VER1_0}
{$endif}
{$ifndef VER1_0}
{$endif}
{$ifndef VER1_0}
{$endif}
{$ifndef VER1_0}
{$endif}
Begin
 { setup variables }
 tcalpvr3_proc := @tcalpvr3_testroutine;
 tcalpvr3_func := @tcalpvr3_testroutineresult;
 tcalpvr3_obj.init;
 tcalpvr3_cla:=tcalpvr3_tsimpleclass.create;

 {****************************************************************************************************}

 Write('Testing procedure variable call (LOC_REGISTER)..');

 tcalpvr3_clear_globals;
 tcalpvr3_clear_values;
 tcalpvr3_failed := false;

 { parameters in LOC_CONSTANT, routine address in LOC_REGISTER }
 tcalpvr3_troutine(tcalpvr3_getroutine)(tcalpvr3_RESULT_S32BIT,tcalpvr3_RESULT_U8BIT);
 if tcalpvr3_global_u8bit <> tcalpvr3_RESULT_U8BIT then
   tcalpvr3_failed := true;
 if tcalpvr3_global_s32bit <> tcalpvr3_RESULT_S32BIT then
   tcalpvr3_failed := true;

 tcalpvr3_clear_globals;
 tcalpvr3_clear_values;
 { parameters in LOC_REFERENCE,routine address in LOC_REGISTER }
 tcalpvr3_value_s32bit := tcalpvr3_RESULT_S32BIT;
 tcalpvr3_value_u8bit := tcalpvr3_RESULT_U8BIT;
 tcalpvr3_troutine(tcalpvr3_getroutine)(tcalpvr3_value_s32bit , tcalpvr3_value_u8bit);
 if tcalpvr3_global_u8bit <> tcalpvr3_RESULT_U8BIT then
   tcalpvr3_failed := true;
 if tcalpvr3_global_s32bit <> tcalpvr3_RESULT_S32BIT then
   tcalpvr3_failed := true;

 If tcalpvr3_failed then
   tcalpvr3_fail
 else
   WriteLn('Passed!');


 Write('Testing procedure variable call (LOC_REFERENCE)..');

 tcalpvr3_clear_globals;
 tcalpvr3_clear_values;
 tcalpvr3_failed := false;

 { parameters in LOC_CONSTANT, routine address in LOC_REGISTER }
 tcalpvr3_proc(tcalpvr3_RESULT_S32BIT,tcalpvr3_RESULT_U8BIT);
 if tcalpvr3_global_u8bit <> tcalpvr3_RESULT_U8BIT then
   tcalpvr3_failed := true;
 if tcalpvr3_global_s32bit <> tcalpvr3_RESULT_S32BIT then
   tcalpvr3_failed := true;

 tcalpvr3_clear_globals;
 tcalpvr3_clear_values;
 { parameters in LOC_REFERENCE,routine address in LOC_REGISTER }
 tcalpvr3_value_s32bit := tcalpvr3_RESULT_S32BIT;
 tcalpvr3_value_u8bit := tcalpvr3_RESULT_U8BIT;
 tcalpvr3_proc(tcalpvr3_value_s32bit , tcalpvr3_value_u8bit);
 if tcalpvr3_global_u8bit <> tcalpvr3_RESULT_U8BIT then
   tcalpvr3_failed := true;
 if tcalpvr3_global_s32bit <> tcalpvr3_RESULT_S32BIT then
   tcalpvr3_failed := true;

 If tcalpvr3_failed then
   tcalpvr3_fail
 else
   WriteLn('Passed!');
 {****************************************************************************************************}
 Write('Testing function variable call (LOC_REGISTER)..');

 tcalpvr3_clear_globals;
 tcalpvr3_clear_values;
 tcalpvr3_failed := false;

 { parameters in LOC_CONSTANT, routine address in LOC_REGISTER }
 tcalpvr3_global_s64bit := tcalpvr3_troutineresult(tcalpvr3_getroutineresult)(tcalpvr3_RESULT_S32BIT,tcalpvr3_RESULT_U8BIT);
 if tcalpvr3_global_u8bit <> tcalpvr3_RESULT_U8BIT then
   tcalpvr3_failed := true;
 if tcalpvr3_global_s32bit <> tcalpvr3_RESULT_S32BIT then
   tcalpvr3_failed := true;
 if tcalpvr3_global_s64bit <> tcalpvr3_RESULT_S64BIT then
   tcalpvr3_failed := true;

 tcalpvr3_clear_globals;
 tcalpvr3_clear_values;
 { parameters in LOC_REFERENCE,routine address in LOC_REGISTER }
 tcalpvr3_value_s32bit := tcalpvr3_RESULT_S32BIT;
 tcalpvr3_value_u8bit := tcalpvr3_RESULT_U8BIT;
 tcalpvr3_global_s64bit := tcalpvr3_troutineresult(tcalpvr3_getroutineresult)(tcalpvr3_value_s32bit , tcalpvr3_value_u8bit);
 if tcalpvr3_global_u8bit <> tcalpvr3_RESULT_U8BIT then
   tcalpvr3_failed := true;
 if tcalpvr3_global_s32bit <> tcalpvr3_RESULT_S32BIT then
   tcalpvr3_failed := true;
 if tcalpvr3_global_s64bit <> tcalpvr3_RESULT_S64BIT then
   tcalpvr3_failed := true;

 If tcalpvr3_failed then
   tcalpvr3_fail
 else
   WriteLn('Passed!');


 Write('Testing function variable call (LOC_REFERENCE)..');

 tcalpvr3_clear_globals;
 tcalpvr3_clear_values;
 tcalpvr3_failed := false;

 { parameters in LOC_CONSTANT, routine address in LOC_REGISTER }
 tcalpvr3_global_s64bit := tcalpvr3_func(tcalpvr3_RESULT_S32BIT,tcalpvr3_RESULT_U8BIT);
 if tcalpvr3_global_u8bit <> tcalpvr3_RESULT_U8BIT then
   tcalpvr3_failed := true;
 if tcalpvr3_global_s32bit <> tcalpvr3_RESULT_S32BIT then
   tcalpvr3_failed := true;
 if tcalpvr3_global_s64bit <> tcalpvr3_RESULT_S64BIT then
   tcalpvr3_failed := true;

 tcalpvr3_clear_globals;
 tcalpvr3_clear_values;
 { parameters in LOC_REFERENCE,routine address in LOC_REGISTER }
 tcalpvr3_value_s32bit := tcalpvr3_RESULT_S32BIT;
 tcalpvr3_value_u8bit := tcalpvr3_RESULT_U8BIT;
 tcalpvr3_global_s64bit := tcalpvr3_func(tcalpvr3_value_s32bit , tcalpvr3_value_u8bit);
 if tcalpvr3_global_u8bit <> tcalpvr3_RESULT_U8BIT then
   tcalpvr3_failed := true;
 if tcalpvr3_global_s32bit <> tcalpvr3_RESULT_S32BIT then
   tcalpvr3_failed := true;
 if tcalpvr3_global_s64bit <> tcalpvr3_RESULT_S64BIT then
   tcalpvr3_failed := true;

 If tcalpvr3_failed then
   tcalpvr3_fail
 else
   WriteLn('Passed!');
 {****************************************************************************************************}
 Write('Testing object method variable call (LOC_REGISTER) ..');

 tcalpvr3_clear_globals;
 tcalpvr3_clear_values;
 tcalpvr3_failed := false;

 tcalpvr3_tobjectmethod(tcalpvr3_get_object_method_normal)(tcalpvr3_RESULT_U8BIT);
 if tcalpvr3_global_u8bit <> tcalpvr3_RESULT_U8BIT then
   tcalpvr3_failed := true;

 tcalpvr3_clear_globals;
 tcalpvr3_clear_values;

 tcalpvr3_tobjectmethod(tcalpvr3_get_object_type_method_virtual)(tcalpvr3_RESULT_U8BIT);
 if tcalpvr3_global_u8bit <> tcalpvr3_RESULT_U8BIT then
   tcalpvr3_failed := true;

 tcalpvr3_clear_globals;
 tcalpvr3_clear_values;

 tcalpvr3_tobjectmethod(tcalpvr3_get_object_method_virtual)(tcalpvr3_RESULT_U8BIT);
 if tcalpvr3_global_u8bit <> tcalpvr3_RESULT_U8BIT then
   tcalpvr3_failed := true;

 tcalpvr3_clear_globals;
 tcalpvr3_clear_values;

 tcalpvr3_value_u8bit := tcalpvr3_RESULT_U8BIT;
 tcalpvr3_tobjectmethod(tcalpvr3_get_object_method_normal)(tcalpvr3_value_u8bit);
 if tcalpvr3_global_u8bit <> tcalpvr3_RESULT_U8BIT then
   tcalpvr3_failed := true;

 tcalpvr3_clear_globals;
 tcalpvr3_clear_values;

 tcalpvr3_value_u8bit := tcalpvr3_RESULT_U8BIT;
 tcalpvr3_tobjectmethod(tcalpvr3_get_object_type_method_virtual)(tcalpvr3_value_u8bit);
 if tcalpvr3_global_u8bit <> tcalpvr3_RESULT_U8BIT then
   tcalpvr3_failed := true;

 tcalpvr3_clear_globals;
 tcalpvr3_clear_values;

 tcalpvr3_value_u8bit := tcalpvr3_RESULT_U8BIT;
 tcalpvr3_tobjectmethod(tcalpvr3_get_object_method_virtual)(tcalpvr3_value_u8bit);
 if tcalpvr3_global_u8bit <> tcalpvr3_RESULT_U8BIT then
   tcalpvr3_failed := true;


 If tcalpvr3_failed then
   tcalpvr3_fail
 else
   WriteLn('Passed!');

 Write('Testing object method variable call (LOC_REFERENCE) ..');

 tcalpvr3_clear_globals;
 tcalpvr3_clear_values;
 tcalpvr3_failed := false;

 tcalpvr3_obj_method:=@tcalpvr3_obj.test_normal;
 tcalpvr3_obj_method(tcalpvr3_RESULT_U8BIT);
 if tcalpvr3_global_u8bit <> tcalpvr3_RESULT_U8BIT then
   tcalpvr3_failed := true;

 tcalpvr3_clear_globals;
 tcalpvr3_clear_values;

 tcalpvr3_obj_method:=@tcalpvr3_obj.test_virtual;
 tcalpvr3_obj_method(tcalpvr3_RESULT_U8BIT);
 if tcalpvr3_global_u8bit <> tcalpvr3_RESULT_U8BIT then
   tcalpvr3_failed := true;

 tcalpvr3_clear_globals;
 tcalpvr3_clear_values;

 tcalpvr3_obj_method:=@tcalpvr3_obj.test_virtual;
 tcalpvr3_obj_method(tcalpvr3_RESULT_U8BIT);
 if tcalpvr3_global_u8bit <> tcalpvr3_RESULT_U8BIT then
   tcalpvr3_failed := true;

 tcalpvr3_clear_globals;
 tcalpvr3_clear_values;

 tcalpvr3_value_u8bit := tcalpvr3_RESULT_U8BIT;
 tcalpvr3_obj_method:=@tcalpvr3_obj.test_normal;
 tcalpvr3_obj_method(tcalpvr3_value_u8bit);
 if tcalpvr3_global_u8bit <> tcalpvr3_RESULT_U8BIT then
   tcalpvr3_failed := true;

 tcalpvr3_clear_globals;
 tcalpvr3_clear_values;

 tcalpvr3_value_u8bit := tcalpvr3_RESULT_U8BIT;
 tcalpvr3_obj_method:=@tcalpvr3_obj.test_virtual;
 tcalpvr3_obj_method(tcalpvr3_value_u8bit);
 if tcalpvr3_global_u8bit <> tcalpvr3_RESULT_U8BIT then
   tcalpvr3_failed := true;

 tcalpvr3_clear_globals;
 tcalpvr3_clear_values;

 tcalpvr3_value_u8bit := tcalpvr3_RESULT_U8BIT;
 tcalpvr3_obj_method:=@tcalpvr3_obj.test_normal;
 tcalpvr3_obj_method(tcalpvr3_value_u8bit);
 if tcalpvr3_global_u8bit <> tcalpvr3_RESULT_U8BIT then
   tcalpvr3_failed := true;


 If tcalpvr3_failed then
   tcalpvr3_fail
 else
   WriteLn('Passed!');

 {****************************************************************************************************}
 Write('Testing class method variable call (LOC_REGISTER) ..');

 tcalpvr3_clear_globals;
 tcalpvr3_clear_values;
 tcalpvr3_failed := false;

 tcalpvr3_tclassmethod(tcalpvr3_get_class_method_normal)(tcalpvr3_RESULT_U8BIT);
 if tcalpvr3_global_u8bit <> tcalpvr3_RESULT_U8BIT then
   tcalpvr3_failed := true;

 tcalpvr3_clear_globals;
 tcalpvr3_clear_values;


 tcalpvr3_tclassmethod(tcalpvr3_get_class_method_virtual)(tcalpvr3_RESULT_U8BIT);
 if tcalpvr3_global_u8bit <> tcalpvr3_RESULT_U8BIT then
   tcalpvr3_failed := true;

 If tcalpvr3_failed then
   tcalpvr3_fail
 else
   WriteLn('Passed!');

 Write('Testing class method variable call (LOC_REFERENCE)...');

 tcalpvr3_clear_globals;
 tcalpvr3_clear_values;
 tcalpvr3_failed := false;


 tcalpvr3_cla_method := @tcalpvr3_cla.test_normal;
 tcalpvr3_cla_method(tcalpvr3_RESULT_U8BIT);
 if tcalpvr3_global_u8bit <> tcalpvr3_RESULT_U8BIT then
   tcalpvr3_failed := true;

 tcalpvr3_clear_globals;
 tcalpvr3_clear_values;


 tcalpvr3_cla_method := @tcalpvr3_cla.test_virtual;
 tcalpvr3_cla_method(tcalpvr3_RESULT_U8BIT);
 if tcalpvr3_global_u8bit <> tcalpvr3_RESULT_U8BIT then
   tcalpvr3_failed := true;

 tcalpvr3_clear_globals;
 tcalpvr3_clear_values;

 tcalpvr3_cla_method := @tcalpvr3_cla.test_virtual;
 tcalpvr3_cla_method(tcalpvr3_RESULT_U8BIT);
 if tcalpvr3_global_u8bit <> tcalpvr3_RESULT_U8BIT then
   tcalpvr3_failed := true;

 tcalpvr3_clear_globals;
 tcalpvr3_clear_values;

{ cla_method := @cla.test_static;
 cla_method(RESULT_U8BIT);
 if global_u8bit <> RESULT_U8BIT then
   failed := true;}

 tcalpvr3_clear_globals;
 tcalpvr3_clear_values;


{ cla_method := @cla.test_static;
 cla_method(RESULT_U8BIT);
 if global_u8bit <> RESULT_U8BIT then
   failed := true;}

 If tcalpvr3_failed then
   tcalpvr3_fail
 else
   WriteLn('Passed!');

end;
{$pop}

{ Case tcalpvr6.pp }
{$push}

{$R+}
Begin
 { setup variables }
 tcalpvr6_proc := @tcalpvr6_testroutine;
 tcalpvr6_func := @tcalpvr6_testroutineresult;
 tcalpvr6_obj.init;
 tcalpvr6_cla:=tcalpvr6_tsimpleclass.create;

 {****************************************************************************************************}

 Write('Testing procedure variable call (LOC_REGISTER)..');

 tcalpvr6_clear_globals;
 tcalpvr6_clear_values;
 tcalpvr6_failed := false;

 { parameters in LOC_CONSTANT, routine address in LOC_REGISTER }
 tcalpvr6_troutine(tcalpvr6_getroutine)(tcalpvr6_RESULT_S32BIT,tcalpvr6_RESULT_U8BIT);
 if tcalpvr6_global_u8bit <> tcalpvr6_RESULT_U8BIT then
   tcalpvr6_failed := true;
 if tcalpvr6_global_s32bit <> tcalpvr6_RESULT_S32BIT then
   tcalpvr6_failed := true;

 tcalpvr6_clear_globals;
 tcalpvr6_clear_values;
 { parameters in LOC_REFERENCE,routine address in LOC_REGISTER }
 tcalpvr6_value_s32bit := tcalpvr6_RESULT_S32BIT;
 tcalpvr6_value_u8bit := tcalpvr6_RESULT_U8BIT;
 tcalpvr6_troutine(tcalpvr6_getroutine)(tcalpvr6_value_s32bit , tcalpvr6_value_u8bit);
 if tcalpvr6_global_u8bit <> tcalpvr6_RESULT_U8BIT then
   tcalpvr6_failed := true;
 if tcalpvr6_global_s32bit <> tcalpvr6_RESULT_S32BIT then
   tcalpvr6_failed := true;

 If tcalpvr6_failed then
   tcalpvr6_fail
 else
   WriteLn('Passed!');


 Write('Testing procedure variable call (LOC_REFERENCE)..');

 tcalpvr6_clear_globals;
 tcalpvr6_clear_values;
 tcalpvr6_failed := false;

 { parameters in LOC_CONSTANT, routine address in LOC_REGISTER }
 tcalpvr6_proc(tcalpvr6_RESULT_S32BIT,tcalpvr6_RESULT_U8BIT);
 if tcalpvr6_global_u8bit <> tcalpvr6_RESULT_U8BIT then
   tcalpvr6_failed := true;
 if tcalpvr6_global_s32bit <> tcalpvr6_RESULT_S32BIT then
   tcalpvr6_failed := true;

 tcalpvr6_clear_globals;
 tcalpvr6_clear_values;
 { parameters in LOC_REFERENCE,routine address in LOC_REGISTER }
 tcalpvr6_value_s32bit := tcalpvr6_RESULT_S32BIT;
 tcalpvr6_value_u8bit := tcalpvr6_RESULT_U8BIT;
 tcalpvr6_proc(tcalpvr6_value_s32bit , tcalpvr6_value_u8bit);
 if tcalpvr6_global_u8bit <> tcalpvr6_RESULT_U8BIT then
   tcalpvr6_failed := true;
 if tcalpvr6_global_s32bit <> tcalpvr6_RESULT_S32BIT then
   tcalpvr6_failed := true;

 If tcalpvr6_failed then
   tcalpvr6_fail
 else
   WriteLn('Passed!');
 {****************************************************************************************************}
 Write('Testing function variable call (LOC_REGISTER)..');

 tcalpvr6_clear_globals;
 tcalpvr6_clear_values;
 tcalpvr6_failed := false;

 { parameters in LOC_CONSTANT, routine address in LOC_REGISTER }
 tcalpvr6_global_s64bit := tcalpvr6_troutineresult(tcalpvr6_getroutineresult)(tcalpvr6_RESULT_S32BIT,tcalpvr6_RESULT_U8BIT);
 if tcalpvr6_global_u8bit <> tcalpvr6_RESULT_U8BIT then
   tcalpvr6_failed := true;
 if tcalpvr6_global_s32bit <> tcalpvr6_RESULT_S32BIT then
   tcalpvr6_failed := true;
 if tcalpvr6_global_s64bit <> tcalpvr6_RESULT_S64BIT then
   tcalpvr6_failed := true;

 tcalpvr6_clear_globals;
 tcalpvr6_clear_values;
 { parameters in LOC_REFERENCE,routine address in LOC_REGISTER }
 tcalpvr6_value_s32bit := tcalpvr6_RESULT_S32BIT;
 tcalpvr6_value_u8bit := tcalpvr6_RESULT_U8BIT;
 tcalpvr6_global_s64bit := tcalpvr6_troutineresult(tcalpvr6_getroutineresult)(tcalpvr6_value_s32bit , tcalpvr6_value_u8bit);
 if tcalpvr6_global_u8bit <> tcalpvr6_RESULT_U8BIT then
   tcalpvr6_failed := true;
 if tcalpvr6_global_s32bit <> tcalpvr6_RESULT_S32BIT then
   tcalpvr6_failed := true;
 if tcalpvr6_global_s64bit <> tcalpvr6_RESULT_S64BIT then
   tcalpvr6_failed := true;

 If tcalpvr6_failed then
   tcalpvr6_fail
 else
   WriteLn('Passed!');


 Write('Testing function variable call (LOC_REFERENCE)..');

 tcalpvr6_clear_globals;
 tcalpvr6_clear_values;
 tcalpvr6_failed := false;

 { parameters in LOC_CONSTANT, routine address in LOC_REGISTER }
 tcalpvr6_global_s64bit := tcalpvr6_func(tcalpvr6_RESULT_S32BIT,tcalpvr6_RESULT_U8BIT);
 if tcalpvr6_global_u8bit <> tcalpvr6_RESULT_U8BIT then
   tcalpvr6_failed := true;
 if tcalpvr6_global_s32bit <> tcalpvr6_RESULT_S32BIT then
   tcalpvr6_failed := true;
 if tcalpvr6_global_s64bit <> tcalpvr6_RESULT_S64BIT then
   tcalpvr6_failed := true;

 tcalpvr6_clear_globals;
 tcalpvr6_clear_values;
 { parameters in LOC_REFERENCE,routine address in LOC_REGISTER }
 tcalpvr6_value_s32bit := tcalpvr6_RESULT_S32BIT;
 tcalpvr6_value_u8bit := tcalpvr6_RESULT_U8BIT;
 tcalpvr6_global_s64bit := tcalpvr6_func(tcalpvr6_value_s32bit , tcalpvr6_value_u8bit);
 if tcalpvr6_global_u8bit <> tcalpvr6_RESULT_U8BIT then
   tcalpvr6_failed := true;
 if tcalpvr6_global_s32bit <> tcalpvr6_RESULT_S32BIT then
   tcalpvr6_failed := true;
 if tcalpvr6_global_s64bit <> tcalpvr6_RESULT_S64BIT then
   tcalpvr6_failed := true;

 If tcalpvr6_failed then
   tcalpvr6_fail
 else
   WriteLn('Passed!');
 {****************************************************************************************************}
 Write('Testing object method variable call (LOC_REGISTER) ..');

 tcalpvr6_clear_globals;
 tcalpvr6_clear_values;
 tcalpvr6_failed := false;

 tcalpvr6_tobjectmethod(tcalpvr6_get_object_method_normal)(tcalpvr6_RESULT_U8BIT);
 if tcalpvr6_global_u8bit <> tcalpvr6_RESULT_U8BIT then
   tcalpvr6_failed := true;

 tcalpvr6_clear_globals;
 tcalpvr6_clear_values;

 tcalpvr6_tobjectmethod(tcalpvr6_get_object_type_method_virtual)(tcalpvr6_RESULT_U8BIT);
 if tcalpvr6_global_u8bit <> tcalpvr6_RESULT_U8BIT then
   tcalpvr6_failed := true;

 tcalpvr6_clear_globals;
 tcalpvr6_clear_values;

 tcalpvr6_tobjectmethod(tcalpvr6_get_object_method_virtual)(tcalpvr6_RESULT_U8BIT);
 if tcalpvr6_global_u8bit <> tcalpvr6_RESULT_U8BIT then
   tcalpvr6_failed := true;

 tcalpvr6_clear_globals;
 tcalpvr6_clear_values;

 tcalpvr6_value_u8bit := tcalpvr6_RESULT_U8BIT;
 tcalpvr6_tobjectmethod(tcalpvr6_get_object_method_normal)(tcalpvr6_value_u8bit);
 if tcalpvr6_global_u8bit <> tcalpvr6_RESULT_U8BIT then
   tcalpvr6_failed := true;

 tcalpvr6_clear_globals;
 tcalpvr6_clear_values;

 tcalpvr6_value_u8bit := tcalpvr6_RESULT_U8BIT;
 tcalpvr6_tobjectmethod(tcalpvr6_get_object_type_method_virtual)(tcalpvr6_value_u8bit);
 if tcalpvr6_global_u8bit <> tcalpvr6_RESULT_U8BIT then
   tcalpvr6_failed := true;

 tcalpvr6_clear_globals;
 tcalpvr6_clear_values;

 tcalpvr6_value_u8bit := tcalpvr6_RESULT_U8BIT;
 tcalpvr6_tobjectmethod(tcalpvr6_get_object_method_virtual)(tcalpvr6_value_u8bit);
 if tcalpvr6_global_u8bit <> tcalpvr6_RESULT_U8BIT then
   tcalpvr6_failed := true;


 If tcalpvr6_failed then
   tcalpvr6_fail
 else
   WriteLn('Passed!');

 Write('Testing object method variable call (LOC_REFERENCE) ..');

 tcalpvr6_clear_globals;
 tcalpvr6_clear_values;
 tcalpvr6_failed := false;

 tcalpvr6_obj_method:=@tcalpvr6_obj.test_normal;
 tcalpvr6_obj_method(tcalpvr6_RESULT_U8BIT);
 if tcalpvr6_global_u8bit <> tcalpvr6_RESULT_U8BIT then
   tcalpvr6_failed := true;

 tcalpvr6_clear_globals;
 tcalpvr6_clear_values;

 tcalpvr6_obj_method:=@tcalpvr6_obj.test_virtual;
 tcalpvr6_obj_method(tcalpvr6_RESULT_U8BIT);
 if tcalpvr6_global_u8bit <> tcalpvr6_RESULT_U8BIT then
   tcalpvr6_failed := true;

 tcalpvr6_clear_globals;
 tcalpvr6_clear_values;

 tcalpvr6_obj_method:=@tcalpvr6_obj.test_virtual;
 tcalpvr6_obj_method(tcalpvr6_RESULT_U8BIT);
 if tcalpvr6_global_u8bit <> tcalpvr6_RESULT_U8BIT then
   tcalpvr6_failed := true;

 tcalpvr6_clear_globals;
 tcalpvr6_clear_values;

 tcalpvr6_value_u8bit := tcalpvr6_RESULT_U8BIT;
 tcalpvr6_obj_method:=@tcalpvr6_obj.test_normal;
 tcalpvr6_obj_method(tcalpvr6_value_u8bit);
 if tcalpvr6_global_u8bit <> tcalpvr6_RESULT_U8BIT then
   tcalpvr6_failed := true;

 tcalpvr6_clear_globals;
 tcalpvr6_clear_values;

 tcalpvr6_value_u8bit := tcalpvr6_RESULT_U8BIT;
 tcalpvr6_obj_method:=@tcalpvr6_obj.test_virtual;
 tcalpvr6_obj_method(tcalpvr6_value_u8bit);
 if tcalpvr6_global_u8bit <> tcalpvr6_RESULT_U8BIT then
   tcalpvr6_failed := true;

 tcalpvr6_clear_globals;
 tcalpvr6_clear_values;

 tcalpvr6_value_u8bit := tcalpvr6_RESULT_U8BIT;
 tcalpvr6_obj_method:=@tcalpvr6_obj.test_normal;
 tcalpvr6_obj_method(tcalpvr6_value_u8bit);
 if tcalpvr6_global_u8bit <> tcalpvr6_RESULT_U8BIT then
   tcalpvr6_failed := true;


 If tcalpvr6_failed then
   tcalpvr6_fail
 else
   WriteLn('Passed!');

 {****************************************************************************************************}
 Write('Testing class method variable call (LOC_REGISTER) ..');

 tcalpvr6_clear_globals;
 tcalpvr6_clear_values;
 tcalpvr6_failed := false;

 tcalpvr6_tclassmethod(tcalpvr6_get_class_method_normal)(tcalpvr6_RESULT_U8BIT);
 if tcalpvr6_global_u8bit <> tcalpvr6_RESULT_U8BIT then
   tcalpvr6_failed := true;

 tcalpvr6_clear_globals;
 tcalpvr6_clear_values;


 tcalpvr6_tclassmethod(tcalpvr6_get_class_method_virtual)(tcalpvr6_RESULT_U8BIT);
 if tcalpvr6_global_u8bit <> tcalpvr6_RESULT_U8BIT then
   tcalpvr6_failed := true;

 If tcalpvr6_failed then
   tcalpvr6_fail
 else
   WriteLn('Passed!');

 Write('Testing class method variable call (LOC_REFERENCE)...');

 tcalpvr6_clear_globals;
 tcalpvr6_clear_values;
 tcalpvr6_failed := false;


 tcalpvr6_cla_method := @tcalpvr6_cla.test_normal;
 tcalpvr6_cla_method(tcalpvr6_RESULT_U8BIT);
 if tcalpvr6_global_u8bit <> tcalpvr6_RESULT_U8BIT then
   tcalpvr6_failed := true;

 tcalpvr6_clear_globals;
 tcalpvr6_clear_values;


 tcalpvr6_cla_method := @tcalpvr6_cla.test_virtual;
 tcalpvr6_cla_method(tcalpvr6_RESULT_U8BIT);
 if tcalpvr6_global_u8bit <> tcalpvr6_RESULT_U8BIT then
   tcalpvr6_failed := true;

 tcalpvr6_clear_globals;
 tcalpvr6_clear_values;

 tcalpvr6_cla_method := @tcalpvr6_cla.test_virtual;
 tcalpvr6_cla_method(tcalpvr6_RESULT_U8BIT);
 if tcalpvr6_global_u8bit <> tcalpvr6_RESULT_U8BIT then
   tcalpvr6_failed := true;

 tcalpvr6_clear_globals;
 tcalpvr6_clear_values;

{ cla_method := @cla.test_static;
 cla_method(RESULT_U8BIT);
 if global_u8bit <> RESULT_U8BIT then
   failed := true;}

 tcalpvr6_clear_globals;
 tcalpvr6_clear_values;


{ cla_method := @cla.test_static;
 cla_method(RESULT_U8BIT);
 if global_u8bit <> RESULT_U8BIT then
   failed := true;}

 If tcalpvr6_failed then
   tcalpvr6_fail
 else
   WriteLn('Passed!');

end;
{$pop}

{ Case tcalpvr7.pp }
{$push}

{$R+}
Begin
 { setup variables }
 tcalpvr7_proc := @tcalpvr7_testroutine;
 tcalpvr7_func := @tcalpvr7_testroutineresult;
 tcalpvr7_obj.init;
 tcalpvr7_cla:=tcalpvr7_tsimpleclass.create;

 {****************************************************************************************************}

 Write('Testing procedure variable call (LOC_REGISTER)..');

 tcalpvr7_clear_globals;
 tcalpvr7_clear_values;
 tcalpvr7_failed := false;

 { parameters in LOC_CONSTANT, routine address in LOC_REGISTER }
 tcalpvr7_troutine(tcalpvr7_getroutine)(tcalpvr7_RESULT_S32BIT,tcalpvr7_RESULT_U8BIT);
 if tcalpvr7_global_u8bit <> tcalpvr7_RESULT_U8BIT then
   tcalpvr7_failed := true;
 if tcalpvr7_global_s32bit <> tcalpvr7_RESULT_S32BIT then
   tcalpvr7_failed := true;

 tcalpvr7_clear_globals;
 tcalpvr7_clear_values;
 { parameters in LOC_REFERENCE,routine address in LOC_REGISTER }
 tcalpvr7_value_s32bit := tcalpvr7_RESULT_S32BIT;
 tcalpvr7_value_u8bit := tcalpvr7_RESULT_U8BIT;
 tcalpvr7_troutine(tcalpvr7_getroutine)(tcalpvr7_value_s32bit , tcalpvr7_value_u8bit);
 if tcalpvr7_global_u8bit <> tcalpvr7_RESULT_U8BIT then
   tcalpvr7_failed := true;
 if tcalpvr7_global_s32bit <> tcalpvr7_RESULT_S32BIT then
   tcalpvr7_failed := true;

 If tcalpvr7_failed then
   tcalpvr7_fail
 else
   WriteLn('Passed!');


 Write('Testing procedure variable call (LOC_REFERENCE)..');

 tcalpvr7_clear_globals;
 tcalpvr7_clear_values;
 tcalpvr7_failed := false;

 { parameters in LOC_CONSTANT, routine address in LOC_REGISTER }
 tcalpvr7_proc(tcalpvr7_RESULT_S32BIT,tcalpvr7_RESULT_U8BIT);
 if tcalpvr7_global_u8bit <> tcalpvr7_RESULT_U8BIT then
   tcalpvr7_failed := true;
 if tcalpvr7_global_s32bit <> tcalpvr7_RESULT_S32BIT then
   tcalpvr7_failed := true;

 tcalpvr7_clear_globals;
 tcalpvr7_clear_values;
 { parameters in LOC_REFERENCE,routine address in LOC_REGISTER }
 tcalpvr7_value_s32bit := tcalpvr7_RESULT_S32BIT;
 tcalpvr7_value_u8bit := tcalpvr7_RESULT_U8BIT;
 tcalpvr7_proc(tcalpvr7_value_s32bit , tcalpvr7_value_u8bit);
 if tcalpvr7_global_u8bit <> tcalpvr7_RESULT_U8BIT then
   tcalpvr7_failed := true;
 if tcalpvr7_global_s32bit <> tcalpvr7_RESULT_S32BIT then
   tcalpvr7_failed := true;

 If tcalpvr7_failed then
   tcalpvr7_fail
 else
   WriteLn('Passed!');
 {****************************************************************************************************}
 Write('Testing function variable call (LOC_REGISTER)..');

 tcalpvr7_clear_globals;
 tcalpvr7_clear_values;
 tcalpvr7_failed := false;

 { parameters in LOC_CONSTANT, routine address in LOC_REGISTER }
 tcalpvr7_global_s64bit := tcalpvr7_troutineresult(tcalpvr7_getroutineresult)(tcalpvr7_RESULT_S32BIT,tcalpvr7_RESULT_U8BIT);
 if tcalpvr7_global_u8bit <> tcalpvr7_RESULT_U8BIT then
   tcalpvr7_failed := true;
 if tcalpvr7_global_s32bit <> tcalpvr7_RESULT_S32BIT then
   tcalpvr7_failed := true;
 if tcalpvr7_global_s64bit <> tcalpvr7_RESULT_S64BIT then
   tcalpvr7_failed := true;

 tcalpvr7_clear_globals;
 tcalpvr7_clear_values;
 { parameters in LOC_REFERENCE,routine address in LOC_REGISTER }
 tcalpvr7_value_s32bit := tcalpvr7_RESULT_S32BIT;
 tcalpvr7_value_u8bit := tcalpvr7_RESULT_U8BIT;
 tcalpvr7_global_s64bit := tcalpvr7_troutineresult(tcalpvr7_getroutineresult)(tcalpvr7_value_s32bit , tcalpvr7_value_u8bit);
 if tcalpvr7_global_u8bit <> tcalpvr7_RESULT_U8BIT then
   tcalpvr7_failed := true;
 if tcalpvr7_global_s32bit <> tcalpvr7_RESULT_S32BIT then
   tcalpvr7_failed := true;
 if tcalpvr7_global_s64bit <> tcalpvr7_RESULT_S64BIT then
   tcalpvr7_failed := true;

 If tcalpvr7_failed then
   tcalpvr7_fail
 else
   WriteLn('Passed!');


 Write('Testing function variable call (LOC_REFERENCE)..');

 tcalpvr7_clear_globals;
 tcalpvr7_clear_values;
 tcalpvr7_failed := false;

 { parameters in LOC_CONSTANT, routine address in LOC_REGISTER }
 tcalpvr7_global_s64bit := tcalpvr7_func(tcalpvr7_RESULT_S32BIT,tcalpvr7_RESULT_U8BIT);
 if tcalpvr7_global_u8bit <> tcalpvr7_RESULT_U8BIT then
   tcalpvr7_failed := true;
 if tcalpvr7_global_s32bit <> tcalpvr7_RESULT_S32BIT then
   tcalpvr7_failed := true;
 if tcalpvr7_global_s64bit <> tcalpvr7_RESULT_S64BIT then
   tcalpvr7_failed := true;

 tcalpvr7_clear_globals;
 tcalpvr7_clear_values;
 { parameters in LOC_REFERENCE,routine address in LOC_REGISTER }
 tcalpvr7_value_s32bit := tcalpvr7_RESULT_S32BIT;
 tcalpvr7_value_u8bit := tcalpvr7_RESULT_U8BIT;
 tcalpvr7_global_s64bit := tcalpvr7_func(tcalpvr7_value_s32bit , tcalpvr7_value_u8bit);
 if tcalpvr7_global_u8bit <> tcalpvr7_RESULT_U8BIT then
   tcalpvr7_failed := true;
 if tcalpvr7_global_s32bit <> tcalpvr7_RESULT_S32BIT then
   tcalpvr7_failed := true;
 if tcalpvr7_global_s64bit <> tcalpvr7_RESULT_S64BIT then
   tcalpvr7_failed := true;

 If tcalpvr7_failed then
   tcalpvr7_fail
 else
   WriteLn('Passed!');
 {****************************************************************************************************}
 Write('Testing object method variable call (LOC_REGISTER) ..');

 tcalpvr7_clear_globals;
 tcalpvr7_clear_values;
 tcalpvr7_failed := false;

 tcalpvr7_tobjectmethod(tcalpvr7_get_object_method_normal)(tcalpvr7_RESULT_U8BIT);
 if tcalpvr7_global_u8bit <> tcalpvr7_RESULT_U8BIT then
   tcalpvr7_failed := true;

 tcalpvr7_clear_globals;
 tcalpvr7_clear_values;

 tcalpvr7_tobjectmethod(tcalpvr7_get_object_type_method_virtual)(tcalpvr7_RESULT_U8BIT);
 if tcalpvr7_global_u8bit <> tcalpvr7_RESULT_U8BIT then
   tcalpvr7_failed := true;

 tcalpvr7_clear_globals;
 tcalpvr7_clear_values;

 tcalpvr7_tobjectmethod(tcalpvr7_get_object_method_virtual)(tcalpvr7_RESULT_U8BIT);
 if tcalpvr7_global_u8bit <> tcalpvr7_RESULT_U8BIT then
   tcalpvr7_failed := true;

 tcalpvr7_clear_globals;
 tcalpvr7_clear_values;

 tcalpvr7_value_u8bit := tcalpvr7_RESULT_U8BIT;
 tcalpvr7_tobjectmethod(tcalpvr7_get_object_method_normal)(tcalpvr7_value_u8bit);
 if tcalpvr7_global_u8bit <> tcalpvr7_RESULT_U8BIT then
   tcalpvr7_failed := true;

 tcalpvr7_clear_globals;
 tcalpvr7_clear_values;

 tcalpvr7_value_u8bit := tcalpvr7_RESULT_U8BIT;
 tcalpvr7_tobjectmethod(tcalpvr7_get_object_type_method_virtual)(tcalpvr7_value_u8bit);
 if tcalpvr7_global_u8bit <> tcalpvr7_RESULT_U8BIT then
   tcalpvr7_failed := true;

 tcalpvr7_clear_globals;
 tcalpvr7_clear_values;

 tcalpvr7_value_u8bit := tcalpvr7_RESULT_U8BIT;
 tcalpvr7_tobjectmethod(tcalpvr7_get_object_method_virtual)(tcalpvr7_value_u8bit);
 if tcalpvr7_global_u8bit <> tcalpvr7_RESULT_U8BIT then
   tcalpvr7_failed := true;


 If tcalpvr7_failed then
   tcalpvr7_fail
 else
   WriteLn('Passed!');

 Write('Testing object method variable call (LOC_REFERENCE) ..');

 tcalpvr7_clear_globals;
 tcalpvr7_clear_values;
 tcalpvr7_failed := false;

 tcalpvr7_obj_method:=@tcalpvr7_obj.test_normal;
 tcalpvr7_obj_method(tcalpvr7_RESULT_U8BIT);
 if tcalpvr7_global_u8bit <> tcalpvr7_RESULT_U8BIT then
   tcalpvr7_failed := true;

 tcalpvr7_clear_globals;
 tcalpvr7_clear_values;

 tcalpvr7_obj_method:=@tcalpvr7_obj.test_virtual;
 tcalpvr7_obj_method(tcalpvr7_RESULT_U8BIT);
 if tcalpvr7_global_u8bit <> tcalpvr7_RESULT_U8BIT then
   tcalpvr7_failed := true;

 tcalpvr7_clear_globals;
 tcalpvr7_clear_values;

 tcalpvr7_obj_method:=@tcalpvr7_obj.test_virtual;
 tcalpvr7_obj_method(tcalpvr7_RESULT_U8BIT);
 if tcalpvr7_global_u8bit <> tcalpvr7_RESULT_U8BIT then
   tcalpvr7_failed := true;

 tcalpvr7_clear_globals;
 tcalpvr7_clear_values;

 tcalpvr7_value_u8bit := tcalpvr7_RESULT_U8BIT;
 tcalpvr7_obj_method:=@tcalpvr7_obj.test_normal;
 tcalpvr7_obj_method(tcalpvr7_value_u8bit);
 if tcalpvr7_global_u8bit <> tcalpvr7_RESULT_U8BIT then
   tcalpvr7_failed := true;

 tcalpvr7_clear_globals;
 tcalpvr7_clear_values;

 tcalpvr7_value_u8bit := tcalpvr7_RESULT_U8BIT;
 tcalpvr7_obj_method:=@tcalpvr7_obj.test_virtual;
 tcalpvr7_obj_method(tcalpvr7_value_u8bit);
 if tcalpvr7_global_u8bit <> tcalpvr7_RESULT_U8BIT then
   tcalpvr7_failed := true;

 tcalpvr7_clear_globals;
 tcalpvr7_clear_values;

 tcalpvr7_value_u8bit := tcalpvr7_RESULT_U8BIT;
 tcalpvr7_obj_method:=@tcalpvr7_obj.test_normal;
 tcalpvr7_obj_method(tcalpvr7_value_u8bit);
 if tcalpvr7_global_u8bit <> tcalpvr7_RESULT_U8BIT then
   tcalpvr7_failed := true;


 If tcalpvr7_failed then
   tcalpvr7_fail
 else
   WriteLn('Passed!');

 {****************************************************************************************************}
 Write('Testing class method variable call (LOC_REGISTER) ..');

 tcalpvr7_clear_globals;
 tcalpvr7_clear_values;
 tcalpvr7_failed := false;

 tcalpvr7_tclassmethod(tcalpvr7_get_class_method_normal)(tcalpvr7_RESULT_U8BIT);
 if tcalpvr7_global_u8bit <> tcalpvr7_RESULT_U8BIT then
   tcalpvr7_failed := true;

 tcalpvr7_clear_globals;
 tcalpvr7_clear_values;


 tcalpvr7_tclassmethod(tcalpvr7_get_class_method_virtual)(tcalpvr7_RESULT_U8BIT);
 if tcalpvr7_global_u8bit <> tcalpvr7_RESULT_U8BIT then
   tcalpvr7_failed := true;

 If tcalpvr7_failed then
   tcalpvr7_fail
 else
   WriteLn('Passed!');

 Write('Testing class method variable call (LOC_REFERENCE)...');

 tcalpvr7_clear_globals;
 tcalpvr7_clear_values;
 tcalpvr7_failed := false;


 tcalpvr7_cla_method := @tcalpvr7_cla.test_normal;
 tcalpvr7_cla_method(tcalpvr7_RESULT_U8BIT);
 if tcalpvr7_global_u8bit <> tcalpvr7_RESULT_U8BIT then
   tcalpvr7_failed := true;

 tcalpvr7_clear_globals;
 tcalpvr7_clear_values;


 tcalpvr7_cla_method := @tcalpvr7_cla.test_virtual;
 tcalpvr7_cla_method(tcalpvr7_RESULT_U8BIT);
 if tcalpvr7_global_u8bit <> tcalpvr7_RESULT_U8BIT then
   tcalpvr7_failed := true;

 tcalpvr7_clear_globals;
 tcalpvr7_clear_values;

 tcalpvr7_cla_method := @tcalpvr7_cla.test_virtual;
 tcalpvr7_cla_method(tcalpvr7_RESULT_U8BIT);
 if tcalpvr7_global_u8bit <> tcalpvr7_RESULT_U8BIT then
   tcalpvr7_failed := true;

 tcalpvr7_clear_globals;
 tcalpvr7_clear_values;

{ cla_method := @cla.test_static;
 cla_method(RESULT_U8BIT);
 if global_u8bit <> RESULT_U8BIT then
   failed := true;}

 tcalpvr7_clear_globals;
 tcalpvr7_clear_values;


{ cla_method := @cla.test_static;
 cla_method(RESULT_U8BIT);
 if global_u8bit <> RESULT_U8BIT then
   failed := true;}

 If tcalpvr7_failed then
   tcalpvr7_fail
 else
   WriteLn('Passed!');

end;
{$pop}

{ Case tclacla1.pp }
{$push}

begin
 tclacla1_cb:=tclacla1_tbaseclass.create;
 tclacla1_cd:=tclacla1_tderivedclass.create;
 tclacla1_c1:=tclacla1_tbaseclass.create;

 tclacla1_tbaseclass.virtual_class_method;
 if not tclacla1_tbasecalled then
   tclacla1_has_error:=true;
 tclacla1_reset_booleans;

 tclacla1_tbaseclass.call_virtual_class_method;
 if not tclacla1_tbasecalled then
   tclacla1_has_error:=true;
 tclacla1_reset_booleans;

 tclacla1_tderivedclass.virtual_class_method;
 if not tclacla1_tderivedcalled then
   tclacla1_has_error:=true;
 tclacla1_reset_booleans;

 tclacla1_tderivedclass.call_virtual_class_method;
 if not tclacla1_tderivedcalled then
   tclacla1_has_error:=true;
 tclacla1_reset_booleans;

 tclacla1_c1.virtual_class_method;
 if not tclacla1_tbasecalled then
   tclacla1_has_error:=true;
 tclacla1_reset_booleans;

 tclacla1_c1.call_virtual_class_method;
 if not tclacla1_tbasecalled then
   tclacla1_has_error:=true;
 tclacla1_reset_booleans;

 tclacla1_c1.destroy;

 tclacla1_c1:=tclacla1_tderivedclass.create;

 tclacla1_c1.virtual_class_method;
 if not tclacla1_tderivedcalled then
   tclacla1_has_error:=true;
 tclacla1_reset_booleans;

 tclacla1_c1.call_virtual_class_method;
 if not tclacla1_tderivedcalled then
   tclacla1_has_error:=true;
 tclacla1_reset_booleans;

 tclacla1_c1.destroy;

 tclacla1_cc:=tclacla1_tbaseclass;

 tclacla1_cc.virtual_class_method;
 if not tclacla1_tbasecalled then
   tclacla1_has_error:=true;
 tclacla1_reset_booleans;

 tclacla1_cc.call_virtual_class_method;
 if not tclacla1_tbasecalled then
   tclacla1_has_error:=true;
 tclacla1_reset_booleans;

 tclacla1_cc:=tclacla1_tderivedclass;

 tclacla1_cc.virtual_class_method;
 if not tclacla1_tderivedcalled then
   tclacla1_has_error:=true;
 tclacla1_reset_booleans;

 tclacla1_cc.call_virtual_class_method;
 if not tclacla1_tderivedcalled then
   tclacla1_has_error:=true;
 tclacla1_reset_booleans;

 if tclacla1_has_error then
   begin
     Writeln('Error with class methods');
     halt(1);
   end;

end;
{$pop}

{ Case tclasize.pp }
{$push}
{$ifdef fpc}

{$else}
{$J+}
{$endif}
begin
 tclasize_cb:=tclasize_tbaseclass.create;
 tclasize_cd:=tclasize_tderivedclass.create;
 tclasize_c1:=tclasize_tbaseclass.create;

 tclasize_basesize:=sizeof(tclasize_cb);
 Writeln('Sizeof(cb)=',tclasize_basesize);
 if tclasize_basesize<>sizeof(pointer) then
   Writeln('not the expected size : ',sizeof(pointer));
 Writeln('cb.InstanceSize=',tclasize_Cb.InstanceSize);
 if tclasize_cb.InstanceSize<>tclasize_expected_size_for_tbaseclass then
   Writeln('not the expected size : ',tclasize_expected_size_for_tbaseclass);
 Writeln('Tbaseclass.InstanceSize=',tclasize_Tbaseclass.InstanceSize);
 if tclasize_TBaseClass.InstanceSize<>tclasize_expected_size_for_tbaseclass then
   Writeln('not the expected size : ',tclasize_expected_size_for_tbaseclass);

 tclasize_derivedsize:=sizeof(tclasize_cd);
 Writeln('Sizeof(ct)=',tclasize_derivedsize);
 if tclasize_derivedsize<>sizeof(pointer) then
   Writeln('not the expected size : ',sizeof(pointer));

 tclasize_cb.check_size;
 tclasize_cd.check_size;

 tclasize_tbaseclass.virtual_class_method;
 if not tclasize_tbasecalled then
   tclasize_has_error:=true;
 tclasize_reset_booleans;

 tclasize_tbaseclass.call_virtual_class_method;
 if not tclasize_tbasecalled then
   tclasize_has_error:=true;
 tclasize_reset_booleans;

 tclasize_tderivedclass.virtual_class_method;
 if not tclasize_tderivedcalled then
   tclasize_has_error:=true;
 tclasize_reset_booleans;

 tclasize_tderivedclass.call_virtual_class_method;
 if not tclasize_tderivedcalled then
   tclasize_has_error:=true;
 tclasize_reset_booleans;

 tclasize_c1.virtual_class_method;
 if not tclasize_tbasecalled then
   tclasize_has_error:=true;
 tclasize_reset_booleans;

 tclasize_c1.call_virtual_class_method;
 if not tclasize_tbasecalled then
   tclasize_has_error:=true;
 tclasize_reset_booleans;

 tclasize_c1.destroy;

 tclasize_c1:=tclasize_tderivedclass.create;

 tclasize_c1.virtual_class_method;
 if not tclasize_tderivedcalled then
   tclasize_has_error:=true;
 tclasize_reset_booleans;

 tclasize_c1.call_virtual_class_method;
 if not tclasize_tderivedcalled then
   tclasize_has_error:=true;
 tclasize_reset_booleans;

 tclasize_c1.destroy;

 tclasize_cc:=tclasize_tbaseclass;

 tclasize_cc.virtual_class_method;
 if not tclasize_tbasecalled then
   tclasize_has_error:=true;
 tclasize_reset_booleans;

 tclasize_cc.call_virtual_class_method;
 if not tclasize_tbasecalled then
   tclasize_has_error:=true;
 tclasize_reset_booleans;

 tclasize_cc:=tclasize_tderivedclass;

 tclasize_cc.virtual_class_method;
 if not tclasize_tderivedcalled then
   tclasize_has_error:=true;
 tclasize_reset_booleans;

 tclasize_cc.call_virtual_class_method;
 if not tclasize_tderivedcalled then
   tclasize_has_error:=true;
 tclasize_reset_booleans;

 Writeln('Sizeof(cc)=',sizeof(tclasize_cc));

 if tclasize_has_error then
   begin
     Writeln('Error with class methods');
     halt(1);
   end;

end;
{$pop}

{ Case tclatype.pp }
{$push}

begin
 tclatype_cb:=tclatype_tbaseclass.create;
 tclatype_cd:=tclatype_tderivedclass.create;
 tclatype_c1:=tclatype_tbaseclass.create;

 tclatype_basesize:=sizeof(tclatype_cb);
 Writeln('Sizeof(cb)=',tclatype_basesize);
 if tclatype_basesize<>sizeof(pointer) then
   Writeln('not the expected size : ',sizeof(pointer));

 tclatype_derivedsize:=sizeof(tclatype_cd);
 Writeln('Sizeof(ct)=',tclatype_derivedsize);
 if tclatype_derivedsize<>sizeof(pointer) then
   Writeln('not the expected size : ',sizeof(pointer));

 tclatype_cb.check_type;
 tclatype_cd.check_type;

 tclatype_c1.destroy;

 tclatype_c1:=tclatype_tderivedclass.create;

 tclatype_c1.virtual_class_method;
 if not tclatype_tderivedcalled then
   tclatype_has_error:=true;
 tclatype_reset_booleans;

 tclatype_c1.destroy;

 tclatype_cc:=tclatype_tbaseclass;

 tclatype_cc.virtual_class_method;
 if not tclatype_tbasecalled then
   tclatype_has_error:=true;
 tclatype_reset_booleans;

 tclatype_cc:=tclatype_tderivedclass;


 tclatype_cc.virtual_class_method;
 if not tclatype_tderivedcalled then
   tclatype_has_error:=true;
 tclatype_reset_booleans;

 if tclatype_has_error then
   begin
     Writeln('Error with class methods');
     halt(1);
   end;

end;
{$pop}

{ Case tctr1.pp }
{$push}

{$h+}
begin
  tctr1_o:=tctr1_tobj.create;
  if not tctr1_o.ffield then
    Halt(1);
end;
{$pop}

{ Case texit2.pp }
{$push}

begin
  texit2_st:=texit2_TSymtable.Create;
  texit2_st.test_inline_with_exit;
  texit2_st.Free;
  if texit2_st <> nil then
    begin
      writeln('freeinstance has not called.');
      Halt(1);
    end;
  writeln('OK');
end;
{$pop}

{ Case tloadvmt.pp }
{$push}
{$ifdef fpc}

{$endif}
Begin
  tloadvmt_i:=$7f;
  Write('Secondloadvmt test...');
  tloadvmt_bobj:=tloadvmt_TBobject.create(tloadvmt_i);
  if tloadvmt_bobj.getstring <> tloadvmt_RESULT_STRING then
    tloadvmt_fail
  else
    WriteLn('Success!');
end;
{$pop}

end.
