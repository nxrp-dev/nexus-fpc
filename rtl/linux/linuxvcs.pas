{$IFNDEF FPC_DOTTEDUNITS}
unit linuxvcs;
{$ENDIF FPC_DOTTEDUNITS}

{*****************************************************************************}
                                   interface
{*****************************************************************************}

const vcs_device:shortint=-1;


{*****************************************************************************}
                                 implementation
{*****************************************************************************}

{$IFDEF FPC_DOTTEDUNITS}
uses UnixApi.Base;
{$ELSE FPC_DOTTEDUNITS}
uses baseunix;
{$ENDIF FPC_DOTTEDUNITS}



procedure detect_linuxvcs;

var f:text;
    fields:array [0..60] of int64;
    fieldct,i:integer;
    pid,ppid:longint;
    magnitude:int64;
    s:string[15];
    statln:ansistring;

begin
  {Extremely aggressive VCSA detection. Works even through Midnight
   Commander. Idea from the C++ Turbo Vision project, credits go
   to Martynas Kunigelis <algikun@santaka.sc-uni.ktu.lt>.}
  pid:=fpgetpid;
  repeat
    str(pid,s);
    assign(f, '/proc/'+s+'/stat');
    {$I-}
    reset(f);
    {$I+}
    if ioresult<>0 then
      break;
    readln(f, statln);
    close(f);
    magnitude := 1;
    fieldct := 0;
    fields[fieldct] := 0;
    for i := high(statln) downto low(statln) do
      begin
{$push}{$R-} {$Q-}
        case statln[i] of
          '-': magnitude := -1;
          '0'..'9': begin
            fields[fieldct] := fields[fieldct]
                               + (magnitude * (ord(statln[i]) - ord('0')));
            magnitude := magnitude * 10;
          end;
{$pop}
          ' ': begin
            magnitude := 1;
            fieldct := fieldct + 1;
            fields[fieldct] := 0;
          end;
        else
          break;
        end;
      end;
    ppid := pid;
    pid := fields[fieldct - 1];
    if (fields[fieldct - 4] and $ffffffc0) = $00000400 then {/dev/tty*}
      begin
        vcs_device:=fields[fieldct - 4] and $3f;
        break;
      end;
  until (fields[fieldct - 4]=0) {Not attached to a terminal, i.e. an xterm.}
        or (pid=-1)
        or (ppid=pid);
end;

begin
  {Put in procedure because there are quite a bit of variables which are made
   temporary this way.}
  detect_linuxvcs;
end.
