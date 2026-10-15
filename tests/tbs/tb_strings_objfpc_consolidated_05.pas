{ Consolidated strings regressions; original case IDs and assertions are retained. }
{ %NORUN }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case tw40142.pas }
{$push}




{$H+}
{$ModeSwitch anonymousfunctions}
{$ModeSwitch functionreferences}
{$ModeSwitch nestedprocvars}

type
  tw40142_TVoidFunc = reference to procedure;
  tw40142_TFuncMaker = reference to function(const thing: string): tw40142_TVoidFunc;

procedure tw40142_main;
  var
    cool_bingo: tw40142_TVoidFunc;
    coolifier: tw40142_TFuncMaker;
  begin
    coolifier := function (const thing: string) : tw40142_TVoidFunc
    begin
      result := procedure begin writeln('cool ', thing) end;
    end;
    cool_bingo := coolifier('bingo');
    cool_bingo();
  end;


{$pop}

{ Case tw40143.pas }
{$push}




{$H+}
{$ModeSwitch anonymousfunctions}
{$ModeSwitch functionreferences}
{$ModeSwitch nestedprocvars}

type
  tw40143_TVoidFunc = reference to procedure;
  tw40143_TFuncMaker = reference to function(const thing: string): tw40143_TVoidFunc;

procedure tw40143_something;
  begin
    writeln('something...');
  end;

procedure tw40143_main;
  var
    cool_bingo: tw40143_TVoidFunc;
    coolifier: tw40143_TFuncMaker;
  begin
    coolifier := function (const thing: string): tw40143_TVoidFunc
    begin
      // result := procedure begin writeln('cool ', thing) end;
      result := tw40143_TVoidFunc(@tw40143_something);
    end;
    cool_bingo := coolifier('bingo');
    cool_bingo();
  end;


{$pop}

{ Case tw40144.pas }
{$push}




{$H+}
{$ModeSwitch anonymousfunctions}
{$ModeSwitch functionreferences}
{$ModeSwitch nestedprocvars}

type
  tw40144_TVoidFunc = reference to procedure;
  tw40144_TFuncMaker = reference to function(const thing: string): tw40144_TVoidFunc;

procedure tw40144_main;
  var
    cool_bingo: tw40144_TVoidFunc;
    coolifier: tw40144_TFuncMaker;
  begin
    cool_bingo := default(tw40144_TVoidFunc);
    coolifier := default(tw40144_TFuncMaker);
    coolifier := function (const thing: string): tw40144_TVoidFunc
    var
      func: tw40144_TVoidFunc;
    begin
      result := default(tw40144_TVoidFunc); // <-- This is line 23
      func := procedure begin writeln('cool ', thing) end;
      result := func;
    end;
    cool_bingo := coolifier('bingo');
    cool_bingo();
  end;


{$pop}

{ Case tw40145.pas }
{$push}




{$H+}
{$ModeSwitch anonymousfunctions}
{$ModeSwitch functionreferences}
{$ModeSwitch nestedprocvars}

type
  tw40145_TVoidFunc = reference to procedure;
  tw40145_TFuncMaker = reference to function(const thing: string): tw40145_TVoidFunc;

procedure tw40145_main;
  var
    cool_bingo: tw40145_TVoidFunc;
    coolifier: tw40145_TFuncMaker;
  begin
    cool_bingo := default(tw40145_TVoidFunc);
    coolifier := default(tw40145_TFuncMaker);
    coolifier := function (const thing: string): tw40145_TVoidFunc
    var
      func: tw40145_TVoidFunc;
    begin
      func := procedure begin writeln('cool ', thing) end;
      result := func; // <-- This is line 24
    end;
    cool_bingo := coolifier('bingo');
    cool_bingo();
  end;


{$pop}

begin

{ Case tw40142.pas }
{$push}

{$H+}
{$ModeSwitch anonymousfunctions}
{$ModeSwitch functionreferences}
{$ModeSwitch nestedprocvars}
begin
  tw40142_main;
end;
{$pop}

{ Case tw40143.pas }
{$push}

{$H+}
{$ModeSwitch anonymousfunctions}
{$ModeSwitch functionreferences}
{$ModeSwitch nestedprocvars}
begin
  tw40143_main;
end;
{$pop}

{ Case tw40144.pas }
{$push}

{$H+}
{$ModeSwitch anonymousfunctions}
{$ModeSwitch functionreferences}
{$ModeSwitch nestedprocvars}
begin
  tw40144_main;
end;
{$pop}

{ Case tw40145.pas }
{$push}

{$H+}
{$ModeSwitch anonymousfunctions}
{$ModeSwitch functionreferences}
{$ModeSwitch nestedprocvars}
begin
  tw40145_main;
end;
{$pop}

end.
