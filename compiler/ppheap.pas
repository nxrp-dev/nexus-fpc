{
    Copyright (c) 1998-2002 by Pierre Muller

    Simple unit to add source line and column to each
    memory allocation made with heaptrc unit

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

 ****************************************************************************}
unit ppheap;

{$i fpcdefs.inc}

interface

    uses heaptrc;

    { call this function before any memory allocation
      in a unit initialization code (PM) }

    procedure pp_heap_init;

    procedure ppheap_register_file(name : string;index : LongInt);


implementation

    uses
       CUtils,GlobType,Globals,FModule;

{*****************************************************************************
                            Filename registration
*****************************************************************************}


    { We need to avoid using memory allocation here
      and thus use a fixed size static array }
    const
      MaxFiles = 1024;
      MaxNameLength = 39;

    type
      THeapFileInfo = record
        name : string[MaxNameLength];
        index : LongInt;
      end;

      TFileInfoArray = array [1..MaxFiles] of THeapFileInfo;

    var
      fileinfoarray : TFileInfoArray;
      last_index : LongInt;


    procedure ppheap_register_file(name : string;index : LongInt);
      var
        len,pos : LongInt;
      begin
        inc(last_index);
        if last_index <= MaxFiles then
          begin
            { Keep last part of name if too long }
            len:=length(name);
            if len>MaxNameLength then
              begin
                pos:=len-MaxNameLength+4;
                fileinfoarray[last_index].name:='...'+copy(name,pos,MaxNameLength);
              end
            else
              begin
                pos:=1;
                fileinfoarray[last_index].name:=copy(name,pos,MaxNameLength);
              end;
            fileinfoarray[last_index].Index:=index;
          end
        else
          WriteLn(stderr,'file',name,' has index ',index);
      end;


    function getfilename(index : LongInt) : string;
      var
        i : LongInt;
      begin
        for i:=1 to last_index do
          begin
            if fileinfoarray[i].Index=index then
              begin
                getfilename:=fileinfoarray[i].name;
                exit;
              end;
          end;
        getfilename:=ToStr(index);
      end;


{*****************************************************************************
                              Heaptrc callbacks
*****************************************************************************}

    type
      PExtraInfo = ^TExtraInfo;
      TExtraInfo = record
        line,
        col,
        fileindex : LongInt;
      end;

    procedure set_extra_info(p : pointer);
      begin
        with PExtraInfo(p)^ do
         begin
           line:=CurrentFilePos.line;
           col:=CurrentFilePos.column;
           if Assigned(CurrentModule) then
            fileindex:=CurrentModule.ModuleID*100000+CurrentFilePos.fileindex
           else
            fileindex:=CurrentFilePos.fileindex;
         end;
      end;


    procedure show_extra_info(var t : text;p : pointer);
      begin
        with PExtraInfo(p)^ do
         begin
           WriteLn(t,'Memory allocated at '+getfilename(fileindex)+'('+ToStr(line)+','+ToStr(col)+') ');
         end;
      end;


  var
     pp_heap_inited : boolean = false;

  procedure pp_heap_init;
    begin
       if not pp_heap_inited then
         begin
{$ifdef extheaptrc}
            keepreleased:=true;
{$endif extheaptrc}
            SetHeapTraceOutput('heap.log');
            SetHeapExtraInfo(sizeof(TExtraInfo),
                             @set_extra_info,
                             @show_extra_info);
         end;
       pp_heap_inited:=true;
    end;


begin
  pp_heap_init;
end.
