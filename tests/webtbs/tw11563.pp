{ %target=linux}
{ %result=216 }

program ExecStack;
  procedure DoIt;
  type
    proc = procedure;
  var
{$if defined(cpuaarch64)}
    ret: longint;
{$endif}
{$if defined(cpui386) or defined(cpux86_64)}
    ret: Byte;
{$endif}
{$ifdef cpuarm}
    ret: dword;
{$endif}
{$ifdef cpum68k}
    ret: word;
{$endif}

    DoNothing: proc;

  begin
{$if defined(cpuaarch64)}
    ret := $d65f03c0;
    DoNothing := proc(@ret);
    DoNothing;
{$endif}
{$if defined(cpui386) or defined(cpux86_64)}
    ret := $C3;
    DoNothing := proc(@ret);
    DoNothing;
{$endif}
{$ifdef cpum68k}
    ret:=$4E75;
    DoNothing:=proc(@ret);
    DoNothing;
{$endif cpum68k}

{$ifdef cpuarm}
{$if defined(CPUTHUMB) or defined(CPUTHUMB2)}
{$ifdef CPUARM_HAS_BX}
    ret:=$4770;
{$else}
    ret:=$46f7;
{$endif}
{$else defined(CPUTHUMB) or defined(CPUTHUMB2)}
    ret:=$e8bd8008;
{$endif defined(CPUTHUMB) or defined(CPUTHUMB2)}
{$ifdef ENDIAN_BIG}
    ret:=SwapEndian(ret);
{$endif ENDIAN_BIG}
    DoNothing:=proc(@ret);
    DoNothing;
{$endif cpuarm}


  end;
begin
  DoIt;
end.
