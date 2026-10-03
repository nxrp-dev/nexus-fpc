program WindowsAPIAliases;

{$mode objfpc}

uses
  Windows;

{$IFDEF FPC_OS_UNICODE}
procedure RequireAPIPointer(var Value: PWideChar);
begin
end;
{$ELSE}
procedure RequireAPIPointer(var Value: PAnsiChar);
begin
end;
{$ENDIF}

var
  WindowsName: Windows.LPCTSTR;

begin
  RequireAPIPointer(WindowsName);
end.
