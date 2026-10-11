{ Consolidated records regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}
uses sysutils;

{ Case tw0776.pp }
{$push}


 var tw0776_i:integer;
     tw0776_j : record
        x,y : longint;
     end;

{$pop}

{ Case tw13536.pp }
{$push}

// without -O3 prints  0002020200010101
// with -O3 prints 0001010100010101

{$H+}



Const
   tw13536_MAXDWORD = $FFFFFFFF;


Type
 tw13536_Filetime=longint;
 tw13536_tchar=char;
 tw13536_XWIN32_FIND_DATA = record
          dwFileAttributes : DWORD;
          ftLastWriteTime : tw13536_FILETIME;
          nFileSizeHigh : DWORD;
          nFileSizeLow : DWORD;
          cFileName : array[0..(MAX_PATH)-1] of tw13536_TCHAR;
       end;

Type
  tw13536_TMySearchRec = Record
    Time : Longint;
    Size : Int64;
    Attr : Longint;
    Name : TFileName;
    ExcludeAttr : Longint;
    FindHandle : THandle;
    FindData : tw13536_XWIN32_FIND_DATA;
  end;

function tw13536_getlasterror:integer;
begin
end;

function tw13536_aFindNextFile (F:thandle;fd:tw13536_XWIN32_FIND_DATA):boolean;
begin

end;

function tw13536_WinToDosTime( Var Wtime : tw13536_FileTime;var DTime:longint):longbool;
begin
end;

Function tw13536_aFindMatch(var f: tw13536_TMySearchRec) : Longint;
begin
  // commenting code before the f.size:= line seems to alter the behaviour
  { Find file with correct attribute }
  While (F.FindData.dwFileAttributes and cardinal(F.ExcludeAttr))<>0 do
   begin
     if not tw13536_aFindNextFile (F.FindHandle,F.FindData) then
      begin
        Result:=tw13536_GetLastError;
        exit;
      end;
   end;

  { Convert some attributes back }
  tw13536_WinToDosTime(F.FindData.ftLastWriteTime,F.Time);

  f.size:=F.FindData.NFileSizeLow+(qword(tw13536_maxdword)+1)*F.FindData.NFileSizeHigh;
  f.attr:=F.FindData.dwFileAttributes;
  f.Name:=StrPas(@F.FindData.cFileName[0]);
  Result:=0;
end;

var tw13536_n : tw13536_TMySearchRec;


{$pop}

{ Case tw29669.pp }
{$push}






type
  tw29669_TPackedIdLevel1 = 0..255;
  tw29669_TPackedIdLevel2 = 0..65535;
  tw29669_TPackedIdLevel3 = 0..65535;
  tw29669_TPackedIdLevel4 = 0..65535;
  tw29669_TPackedIdLevel5 = 0..255;

  tw29669_TPackedId = bitpacked record
    clusterId : tw29669_TPackedIdLevel5;
    agentId : tw29669_TPackedIdLevel4;
    dataSourceId : tw29669_TPackedIdLevel3;
    deviceId : tw29669_TPackedIdLevel2;
    esmId : tw29669_TPackedIdLevel1;
  end;

function tw29669_PackedIdToStr(const ipsid : qword) : string;
begin
  result := IntToStr(tw29669_TPackedId(ipsid).esmId) + '-' +
            IntToStr(tw29669_TPackedId(ipsid).deviceId) + '-' +
            IntToStr(tw29669_TPackedId(ipsid).dataSourceId) + '-' +
            IntToStr(tw29669_TPackedId(ipsid).agentId) + '-' +
            IntToStr(tw29669_TPackedId(ipsid).clusterId);
  if tw29669_TPackedId(ipsid).clusterid<>123 then
    halt(1);
  if tw29669_TPackedId(ipsid).agentid<>45678 then
    halt(2);
  if tw29669_TPackedId(ipsid).datasourceid<>9012 then
    halt(3);
  if tw29669_TPackedId(ipsid).deviceid<>34567 then
    halt(4);
  if tw29669_TPackedId(ipsid).esmid<>89 then
    halt(5);

end;

var
  tw29669_pi: tw29669_TPackedId;

{$pop}

{ Case tw29669a.pp }
{$push}






type
  tw29669a_TPackedIdLevel1 = 0..255;
  tw29669a_TPackedIdLevel2 = 0..65535;
  tw29669a_TPackedIdLevel3 = 0..65535;
  tw29669a_TPackedIdLevel4 = 0..65535;
  tw29669a_TPackedIdLevel5 = 0..255;

  tw29669a_TPackedId = bitpacked record
    clusterId : tw29669a_TPackedIdLevel5;
    esmId : tw29669a_TPackedIdLevel1;
    agentId : tw29669a_TPackedIdLevel4;
    dataSourceId : tw29669a_TPackedIdLevel3;
    deviceId : tw29669a_TPackedIdLevel2;
  end;

function tw29669a_PackedIdToStr(const ipsid : qword) : string;
begin
  result := IntToStr(tw29669a_TPackedId(ipsid).esmId) + '-' +
            IntToStr(tw29669a_TPackedId(ipsid).deviceId) + '-' +
            IntToStr(tw29669a_TPackedId(ipsid).dataSourceId) + '-' +
            IntToStr(tw29669a_TPackedId(ipsid).agentId) + '-' +
            IntToStr(tw29669a_TPackedId(ipsid).clusterId);
  if tw29669a_TPackedId(ipsid).clusterid<>123 then
    halt(1);
  if tw29669a_TPackedId(ipsid).agentid<>45678 then
    halt(2);
  if tw29669a_TPackedId(ipsid).datasourceid<>9012 then
    halt(3);
  if tw29669a_TPackedId(ipsid).deviceid<>34567 then
    halt(4);
  if tw29669a_TPackedId(ipsid).esmid<>89 then
    halt(5);

end;

var
  tw29669a_pi: tw29669a_TPackedId;

{$pop}

begin

{ Case tw0776.pp }
{$push}

begin
 tw0776_i:=0;
 format('%d', [tw0776_i]);
 with tw0776_j do
   begin
     x:=2;
     y:=4;
     Writeln('j.x=',x,' j.y=',y);
   end;
end;
{$pop}

{ Case tw13536.pp }
{$push}

{$H+}
begin
 // make sure it gets past the while loop.
 tw13536_n.finddata.dwfileattributes:=1;
 tw13536_n.excludeattr:=0;

 tw13536_n.FindData.NFileSizeLow:=$10101;
 tw13536_n.FindData.NFileSizehigh:=$20202;
 // attempt to avoid problems with strpas.
 tw13536_n.finddata.cfilename:='bla'#0;
 tw13536_aFindMatch(tw13536_n);

 writeln(tw13536_n.size);
 writeln(inttohex(tw13536_n.size,16));
 if (tw13536_n.size<>$0002020200010101) then
   halt(1);
end;
{$pop}

{ Case tw29669.pp }
{$push}

begin
  tw29669_pi.clusterid:=123;
  tw29669_pi.agentid:=45678;
  tw29669_pi.datasourceid:=9012;
  tw29669_pi.deviceid:=34567;
  tw29669_pi.esmid:=89;
  writeln(tw29669_PackedIdToStr(qword(tw29669_pi)));
end;
{$pop}

{ Case tw29669a.pp }
{$push}

begin
  tw29669a_pi.clusterid:=123;
  tw29669a_pi.agentid:=45678;
  tw29669a_pi.datasourceid:=9012;
  tw29669a_pi.deviceid:=34567;
  tw29669a_pi.esmid:=89;
  writeln(tw29669a_PackedIdToStr(qword(tw29669a_pi)));
end;
{$pop}

end.
