unit utNXResourceTestArgs;
{$mode objfpc}{$H+}
interface
function ResourceTestArg(AIndex: Integer): string;
function ResourceTestArgCount: Integer;
implementation
function ResourceTestArg(AIndex: Integer): string;
begin Result := ParamStr(AIndex + 1); end;
function ResourceTestArgCount: Integer;
begin Result := ParamCount - 1; end;
end.
