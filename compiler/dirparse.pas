{
    Copyright (c) 1998-2002 by Florian Klaempfl

    This unit implements some support functions for the parsing of directives
    and option strings

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

 ****************************************************************************
}

unit dirparse;

{$i fpcdefs.inc}

interface

    uses
      GlobType,
      Systems;

     function UpdateAlignmentStr(s:ShortString;var a:TAlignmentInfo):boolean;
     function UpdateOptimizerStr(s:ShortString;var a:TOptimizerSwitches):boolean;
     function UpdateWpoStr(s: ShortString; var a: TWPOptimizerSwitches): boolean;
     function UpdateDebugStr(s:ShortString;var a:TDebugSwitches):boolean;
     function UpdateTargetSwitchStr(s: ShortString; var a: TTargetSwitches; global: boolean): boolean;

implementation

    uses
      Globals,
      CUtils,
      SymTable;

     function UpdateAlignmentStr(s:ShortString;var a:TAlignmentInfo):boolean;
      var
         tok  : ShortString;
         vstr : ShortString;
        l    : LongInt;
        code : integer;
        b    : TAlignmentInfo;
      begin
        UpdateAlignmentStr:=true;
        UpperVar(s);
        fillchar(b,sizeof(b),0);
        repeat
          tok:=GetToken(s,'=');
          if tok='' then
           break;
          vstr:=GetToken(s,',');
          val(vstr,l,code);
          if tok='PROC' then
           b.ProcAlign:=l
          else if tok='JUMP' then
           b.JumpAlign:=l
          else if tok='LOOP' then
           b.LoopAlign:=l
          else if tok='CONSTMIN' then
           begin
             b.ConstAlignMin:=l;
             if l>b.ConstAlignMax then
               b.ConstAlignMax:=l;
           end
          else if tok='CONSTMAX' then
           b.ConstAlignMax:=l
          else if tok='VARMIN' then
           begin
             b.VarAlignMin:=l;
             if l>b.VarAlignMax then
               b.VarAlignMax:=l;
           end
          else if tok='VARMAX' then
           b.VarAlignMax:=l
          else if tok='LOCALMIN' then
           begin
             b.LocalAlignMin:=l;
             if l>b.LocalAlignMax then
               b.LocalAlignMax:=l;
           end
          else if tok='LOCALMAX' then
           b.LocalAlignMax:=l
          else if tok='RECORDMIN' then
           begin
             b.RecordAlignMin:=l;
             if l>b.RecordAlignMax then
               b.RecordAlignMax:=l;
           end
          else if tok='RECORDMAX' then
           b.RecordAlignMax:=l

{          disabled for now as - as Jonas pointed out - this
           is a matter of abi

           else if tok='MAXCRECORD' then
           b.maxCrecordalign:=l }
          else { Error }
           UpdateAlignmentStr:=false;
        until false;
        Result:=Result and UpdateAlignment(a,b);
      end;


     function UpdateOptimizerStr(s:ShortString;var a:TOptimizerSwitches):boolean;
      var
         tok   : ShortString;
        doset,
        found : boolean;
        opt   : TOptimizerSwitch;
      begin
        result:=true;
        UpperVar(s);
        repeat
          tok:=GetToken(s,',');
          if tok='' then
           break;
          if Copy(tok,1,2)='NO' then
            begin
              delete(tok,1,2);
              doset:=false;
            end
          else
            doset:=true;
          found:=false;
          for opt:=low(TOptimizerSwitch) to high(TOptimizerSwitch) do
            begin
              if OptimizerSwitchStr[opt]=tok then
                begin
                  found:=true;
                  break;
                end;
            end;
          if found then
            begin
              if doset then
                include(a,opt)
              else
                exclude(a,opt);
            end
          else
            result:=false;
        until false;
      end;


     function UpdateWpoStr(s: ShortString; var a: TWPOptimizerSwitches): boolean;
      var
         tok   : ShortString;
        doset,
        found : boolean;
        opt   : TWPOptimizerSwitch;
      begin
        result:=true;
        UpperVar(s);
        repeat
          tok:=GetToken(s,',');
          if tok='' then
           break;
          if Copy(tok,1,2)='NO' then
            begin
              delete(tok,1,2);
              doset:=false;
            end
          else
            doset:=true;
          found:=false;
          if (tok = 'ALL') then
            begin
              for opt:=low(TWPOptimizerSwitch) to high(TWPOptimizerSwitch) do
                if doset then
                  include(a,opt)
                else
                  exclude(a,opt);
            end
          else
            begin
              for opt:=low(TWPOptimizerSwitch) to high(TWPOptimizerSwitch) do
                begin
                  if WPOptimizerSwitchStr[opt]=tok then
                    begin
                      found:=true;
                      break;
                    end;
                end;
              if found then
                begin
                  if doset then
                    include(a,opt)
                  else
                    exclude(a,opt);
                end
              else
                result:=false;
            end;
        until false;
      end;


     function UpdateDebugStr(s:ShortString;var a:TDebugSwitches):boolean;
      var
         tok   : ShortString;
        doset,
        found : boolean;
        opt   : TDebugSwitch;
      begin
        result:=true;
        UpperVar(s);
        repeat
          tok:=GetToken(s,',');
          if tok='' then
           break;
          if Copy(tok,1,2)='NO' then
            begin
              delete(tok,1,2);
              doset:=false;
            end
          else
            doset:=true;
          found:=false;
          for opt:=low(TDebugSwitch) to high(TDebugSwitch) do
            begin
              if DebugSwitchStr[opt]=tok then
                begin
                  found:=true;
                  break;
                end;
            end;
          if found then
            begin
              if doset then
                include(a,opt)
              else
                exclude(a,opt);
            end
          else
            result:=false;
        until false;
      end;


     function UpdateTargetSwitchStr(s: ShortString; var a: TTargetSwitches; global: boolean): boolean;
      var
        tok,
         value : ShortString;
        setstr: string[2];
        equalspos: LongInt;
        doset,
        gotvalue,
        found : boolean;
        opt   : TTargetSwitch;
      begin
        result:=true;
        value:='';
        repeat
          tok:=GetToken(s,',');
          if tok='' then
           break;
          setstr:=upper(copy(tok,length(tok),1));
          if setstr='-' then
            begin
              SetLength(tok,length(tok)-1);
              doset:=false;
            end
          else
            doset:=true;
          { value specified? }
          gotvalue:=false;
          equalspos:=pos('=',tok);
          if equalspos<>0 then
            begin
              value:=copy(tok,equalspos+1,length(tok));
              delete(tok,equalspos,length(tok));
              gotvalue:=true;
            end;
          found:=false;
          UpperVar(tok);
          for opt:=low(TTargetSwitch) to high(TTargetSwitch) do
            begin
              if TargetSwitchStr[opt].name=tok then
                begin
                  found:=true;
                  break;
                end;
            end;
          if found then
            begin
              if not global and
                 TargetSwitchStr[opt].isglobal then
                result:=false
              else if not TargetSwitchStr[opt].hasvalue then
                begin
                  if gotvalue then
                    result:=false;
                  if (TargetSwitchStr[opt].define<>'') and (doset xor (opt in a)) then
                    if doset then
                      def_system_macro(TargetSwitchStr[opt].define)
                    else
                      undef_system_macro(TargetSwitchStr[opt].define);
                  if doset then
                    include(a,opt)
                  else
                    exclude(a,opt)
                end
              else
                begin
                  if not gotvalue or
                     not doset then
                    result:=false
                  else
                    begin
                      case opt of
                        ts_auto_getter_prefix:
                          Prop_Auto_Getter_Prefix:=value;
                        ts_auto_setter_predix:
                          Prop_Auto_Setter_Prefix:=value;
                        else
                          begin
                            WriteLn('Internalerror 2012053001');
                            halt(1);
                          end;
                      end;
                    end;
                end;
            end
          else
            result:=false;
        until false;
      end;

end.
