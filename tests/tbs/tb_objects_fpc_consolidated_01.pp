{ Consolidated objects regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}

{ Case tb0224.pp }
{$push}

{ Old file: tbs0262.pp }
{ problems with virtual and overloaded methods }



  type
      tb0224_obj1 = object
        st2 : string;
        constructor init;
        procedure writeit;overload;
        procedure writeit(st : string);virtual;overload;
      end;

      tb0224_obj2 = object(tb0224_obj1)
        procedure writeit;virtual;overload;
      end;

      tb0224_obj3 = object(tb0224_obj2)
        l2 : longint;
        procedure writeit(l : longint);virtual;overload;
        procedure writeit(st : string);virtual;overload;
      end;

      tb0224_obj4 = object(tb0224_obj3)
        procedure writeit;virtual;overload;
        procedure writeit(st : string);virtual;overload;
      end;

      tb0224_obj5 = object(tb0224_obj4)
        procedure writeit;virtual;overload;
        procedure writeit(st : string);overload;
        procedure writeit(l : longint);virtual;overload;
      end;

      constructor tb0224_obj1.init;
        begin
        end;

      procedure tb0224_obj1.writeit;
        begin
          Writeln('Obj1 writeit');
        end;

      procedure tb0224_obj1.writeit(st : string);
        begin
          Writeln('Obj1 writeit(string) ',st);
        end;

      procedure tb0224_obj2.writeit;
        begin
          Writeln('Obj2 writeit');
        end;

      procedure tb0224_obj3.writeit(st : string);
        begin
          Writeln('Obj3 writeit(string) ',st);
        end;

      procedure tb0224_obj3.writeit(l : longint);
        begin
          Writeln('Obj2 writeit(longint) ',l);
        end;

      procedure tb0224_obj4.writeit;
        begin
          Writeln('Obj4 writeit');
        end;

      procedure tb0224_obj4.writeit(st : string);
        begin
          Writeln('Obj4 writeit(string) ',st);
        end;

      procedure tb0224_obj5.writeit;
        begin
          Writeln('Obj5 writeit');
        end;

      procedure tb0224_obj5.writeit(st : string);
        begin
          Writeln('Obj5 writeit(string) ',st);
        end;

      procedure tb0224_obj5.writeit(l : longint);
        begin
          Writeln('Obj5 writeit(longint) ',l);
        end;

var
  tb0224_o1 : tb0224_obj1;
  tb0224_o2 : tb0224_obj2;
  tb0224_o3 : tb0224_obj3;
  tb0224_o4 : tb0224_obj4;
  tb0224_o5 : tb0224_obj5;




{$pop}

{ Case tw2178.pp }
{$push}

type
tw2178_stlpos=^tw2178_stlink;
tw2178_stlink=
  packed object
   next,prev:tw2178_stlpos;
   data:string;
   procedure save(var f:file);
   procedure load(var f:file);
  end;
tw2178_list_of_string=
  packed object
   parent:pointer;
   anchor:tw2178_stlpos;
   last:tw2178_stlpos;
   len:longint;
   constructor init(p:pointer);
   function first:tw2178_stlpos;
   function next(p:tw2178_stlpos):tw2178_stlpos;
   function prev(p:tw2178_stlpos):tw2178_stlpos;
   function ret(p:tw2178_stlpos):string;
   function pret(p:tw2178_stlpos):pointer;
   function insert(p:tw2178_stlpos;d:string):tw2178_stlpos;
   function remove(p:tw2178_stlpos):tw2178_stlpos;
   function empty:boolean;
   destructor term;
   procedure save(var f:file);
   procedure load(var f:file);
  end;

tw2178_stack_of_string=
  packed object (tw2178_list_of_string)
   procedure pop(var s:string);
   procedure push(const s:string);
  end;

procedure tw2178_writestring(var f:file;s:string);
begin
  blockwrite(f,s,length(s)+1);
end;

procedure tw2178_readstring(var f:file;var s:string);
var b:byte;
begin
  blockread(f,b,1);
  seek(f,filepos(f)-1);
  blockread(f,s,b+1);
end;

constructor tw2178_list_of_string.init(p:pointer);
begin
  parent:=p;
  new(anchor);
  anchor^.next:=nil;
  anchor^.prev:=nil;
  last:=anchor;
  len:=0;
end;

function tw2178_list_of_string.first:tw2178_stlpos;
begin
  first:=anchor^.next;
end;

function tw2178_list_of_string.next(p:tw2178_stlpos):tw2178_stlpos;
begin
  next:=p^.next;
end;

function tw2178_list_of_string.prev(p:tw2178_stlpos):tw2178_stlpos;
begin
  prev:=p^.prev;
end;

function tw2178_list_of_string.ret(p:tw2178_stlpos):string;
begin
  ret:=p^.data;
end;

function tw2178_list_of_string.pret(p:tw2178_stlpos):pointer;
begin
  pret:=@(p^.data);
end;

function tw2178_list_of_string.insert(p:tw2178_stlpos;d:string):tw2178_stlpos;
var t:tw2178_stlpos;
begin
  new(t);
  t^.prev:=p;
  t^.next:=p^.next;
  p^.next:=t;
  if t^.next<>nil then
   t^.next^.prev:=t
  else
   last:=t;
  t^.data:=d;
  inc(len);
  insert:=t;
end;

function tw2178_list_of_string.remove(p:tw2178_stlpos):tw2178_stlpos;
begin
  if p^.prev<>nil then
   p^.prev^.next:=p^.next;
  if p^.next<>nil then
   p^.next^.prev:=p^.prev
  else
   last:=p^.prev;
  dispose(p);
  dec(len);
  remove:=p^.next;
end;

function tw2178_list_of_string.empty:boolean;
begin
  empty:=(last=anchor);
end;

destructor tw2178_list_of_string.term;
begin
  while not empty do
   remove(last);
  dispose(anchor);
  last:=nil;
end;

procedure tw2178_stlink.save(var f:file);
begin
  tw2178_writestring(f,data);
end;

procedure tw2178_list_of_string.save(var f:file);
var
  l,i:longint;
  p:tw2178_stlpos;
begin
  l:=len;
  blockwrite(f,l,sizeof(longint));
  p:=first;
  for i:=1 to l do
   begin
    p^.save(f);
    p:=next(p);
   end;
end;

procedure tw2178_stlink.load(var f:file);
begin
  tw2178_readstring(f,data);
end;

procedure tw2178_list_of_string.load(var f:file);
var
  l,i:longint;
  d:tw2178_stlink;
begin
  blockread(f,l,sizeof(longint));
  for i:=1 to l do
   begin
    d.load(f);
    insert(last,d.data);
   end;
end;

procedure tw2178_stack_of_string.pop(var s:string);
begin
  if not empty then
   begin
    s:=first^.data;
    remove(first);
   end;
end;

procedure tw2178_stack_of_string.push(const s:string);
begin
  insert(anchor,s);
end;

var
  tw2178_gs:tw2178_stack_of_string;
  tw2178_opaddr : ^string;

{$pop}

{ Case tw2306.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2306 }
{ Submitted by "Sergey Kosarevsky" on  2003-01-03 }
{ e-mail: netsurfer@au.ru }
{$H-}

Const tw2306_LONG_STR_SIZE=4096;

Type tw2306_tLongStr=Object  // try to change this
                      // to Record
        LStr:Array[0..tw2306_LONG_STR_SIZE] Of Char;
        LLength:Longint;
     End;


Operator := (S:String) R:tw2306_tLongStr;
Begin
   R.LLength:=Length(S);
   Move(S[1],R.LStr[1],Length(S));
End;

Var tw2306_T:tw2306_tLongStr;


{$pop}

begin

{ Case tb0224.pp }
{$push}

begin
  tb0224_o1.init;
  tb0224_o1.writeit;
  tb0224_o1.writeit('o1');
  tb0224_o2.init;
  tb0224_o2.writeit;
  tb0224_o2.writeit('o2');
  tb0224_o3.init;
  tb0224_o3.writeit;
  tb0224_o3.writeit('o3');
  tb0224_o3.writeit(3);
  tb0224_o4.init;
  tb0224_o4.writeit;
  tb0224_o4.writeit('o4');
  tb0224_o4.writeit(4);
  tb0224_o5.init;
  tb0224_o5.writeit;
  tb0224_o5.writeit('o5');
  tb0224_o5.writeit(5);
end;
{$pop}

{ Case tw2178.pp }
{$push}

begin
  tw2178_gs.init(nil);
  tw2178_gs.push('test');

  {perfectly compiles}
  tw2178_opaddr:=@((tw2178_gs.first)^.data);
  writeln(tw2178_opaddr^);
  if (tw2178_opaddr^<>'test') then
   halt(1);

  {reports error ") expected ^ but found"}
  tw2178_opaddr:=@(tw2178_gs.first^.data);
  writeln(tw2178_opaddr^);
  if (tw2178_opaddr^<>'test') then
   halt(1);


end;
{$pop}

{ Case tw2306.pp }
{$push}
{$H-}
Begin
   tw2306_T:='Hello';
   if (tw2306_T.LLength<>5) or
      (tw2306_T.LStr[1]<>'H') or
      (tw2306_T.LStr[5]<>'o') then
    begin
      writeln('Error!');
      halt(1);
    end;

End;
{$pop}

end.
