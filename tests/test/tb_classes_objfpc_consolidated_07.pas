{ Consolidated classes regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}
uses classes;

{ Case timplements1.pas }
{$push}
{$ifdef fpc}

{$endif fpc}


type
  timplements1_to1 = class(TObject,IInterface)
    fi : IInterface;
    property i : IInterface read fi implements IInterface;
  end;

var
  timplements1_o1 : timplements1_to1;
  timplements1_i1,timplements1_i2 : IInterface;

{$pop}

{ Case timplements2.pas }
{$push}
{$ifdef fpc}

{$endif fpc}


type
  timplements2_to1 = class(TObject,IInterface)
    fi : IInterface;
    function getfi : IInterface;
    property i : IInterface read getfi implements IInterface;
  end;

function timplements2_to1.getfi : IInterface;
  begin
    result:=fi;
  end;

var
  timplements2_o1 : timplements2_to1;
  timplements2_i1,timplements2_i2 : IInterface;

{$pop}

{ Case timplements3.pas }
{$push}
{$ifdef fpc}

{$endif fpc}


type
  timplements3_to1 = class(TObject,IInterface)
    fi : IInterface;
    function getfi : IInterface;virtual;
    property i : IInterface read getfi implements IInterface;
  end;

function timplements3_to1.getfi : IInterface;
  begin
    result:=fi;
  end;

var
  timplements3_o1 : timplements3_to1;
  timplements3_i1,timplements3_i2 : IInterface;

{$pop}

begin

{ Case timplements1.pas }
{$push}
{$ifdef fpc}

{$endif fpc}
begin
  timplements1_o1:=timplements1_to1.create;
  timplements1_o1.fi:=TInterfacedObject.Create;
  timplements1_i1:=timplements1_o1;
  timplements1_i1.QueryInterface(IInterface,timplements1_i2);
  if timplements1_i2=nil then
    halt(1);
  timplements1_o1.fi:=nil;
  timplements1_i1.QueryInterface(IInterface,timplements1_i2);
  if timplements1_i2=nil then
    halt(1);
  timplements1_o1.free;
  timplements1_i1.QueryInterface(IInterface,timplements1_i2);
  if timplements1_i2=nil then
    halt(1);
  writeln('ok');
end;
{$pop}

{ Case timplements2.pas }
{$push}
{$ifdef fpc}

{$endif fpc}
begin
  timplements2_o1:=timplements2_to1.create;
  timplements2_o1.fi:=TInterfacedObject.Create;
  timplements2_i1:=timplements2_o1;
  timplements2_i1.QueryInterface(IInterface,timplements2_i2);
  if timplements2_i2=nil then
    halt(1);
  timplements2_o1.fi:=nil;
  timplements2_i1.QueryInterface(IInterface,timplements2_i2);
  if timplements2_i2=nil then
    halt(1);
  timplements2_o1.free;
  timplements2_i1.QueryInterface(IInterface,timplements2_i2);
  if timplements2_i2=nil then
    halt(1);
  writeln('ok');
end;
{$pop}

{ Case timplements3.pas }
{$push}
{$ifdef fpc}

{$endif fpc}
begin
  timplements3_o1:=timplements3_to1.create;
  timplements3_o1.fi:=TInterfacedObject.Create;
  timplements3_i1:=timplements3_o1;
  timplements3_i1.QueryInterface(IInterface,timplements3_i2);
  if timplements3_i2=nil then
    halt(1);
  timplements3_o1.fi:=nil;
  timplements3_i1.QueryInterface(IInterface,timplements3_i2);
  if timplements3_i2=nil then
    halt(1);
  timplements3_o1.free;
  timplements3_i1.QueryInterface(IInterface,timplements3_i2);
  if timplements3_i2=nil then
    halt(1);
  writeln('ok');
end;
{$pop}

end.
