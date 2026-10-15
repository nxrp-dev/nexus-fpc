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

     function UpdateAlignmentStr(S:ShortString;var A:TAlignmentInfo):Boolean;
     function UpdateOptimizerStr(S:ShortString;var A:TOptimizerSwitches):Boolean;
     function UpdateWPOStr(S: ShortString; var A: TWPOptimizerSwitches): Boolean;
     function UpdateDebugStr(S:ShortString;var A:TDebugSwitches):Boolean;
     function UpdateTargetSwitchStr(S: ShortString; var A: TTargetSwitches; Global: Boolean): Boolean;

implementation

    uses
      Globals,
      CUtils,
      SymTable;

     function UpdateAlignmentStr(S:ShortString;var A:TAlignmentInfo):Boolean;
      var
         Tok  : ShortString;
         VStr : ShortString;
        L    : LongInt;
        Code : Integer;
        B    : TAlignmentInfo;
      begin
        UpdateAlignmentStr:=True;
        UpperVar(S);
        FillChar(B,SizeOf(B),0);
        repeat
          Tok:=GetToken(S,'=');
          if Tok='' then
           Break;
          VStr:=GetToken(S,',');
          Val(VStr,L,Code);
          if Tok='PROC' then
           B.ProcAlign:=L
          else if Tok='JUMP' then
           B.JumpAlign:=L
          else if Tok='LOOP' then
           B.LoopAlign:=L
          else if Tok='CONSTMIN' then
           begin
             B.ConstAlignMin:=L;
             if L>B.ConstAlignMax then
               B.ConstAlignMax:=L;
           end
          else if Tok='CONSTMAX' then
           B.ConstAlignMax:=L
          else if Tok='VARMIN' then
           begin
             B.VarAlignMin:=L;
             if L>B.VarAlignMax then
               B.VarAlignMax:=L;
           end
          else if Tok='VARMAX' then
           B.VarAlignMax:=L
          else if Tok='LOCALMIN' then
           begin
             B.LocalAlignMin:=L;
             if L>B.LocalAlignMax then
               B.LocalAlignMax:=L;
           end
          else if Tok='LOCALMAX' then
           B.LocalAlignMax:=L
          else if Tok='RECORDMIN' then
           begin
             B.RecordAlignMin:=L;
             if L>B.RecordAlignMax then
               B.RecordAlignMax:=L;
           end
          else if Tok='RECORDMAX' then
           B.RecordAlignMax:=L

{          disabled for now as - as Jonas pointed out - this
           is a matter of abi

           else if tok='MAXCRECORD' then
           b.maxCrecordalign:=l }
          else { Error }
           UpdateAlignmentStr:=False;
        until False;
        Result:=Result and UpdateAlignment(A,B);
      end;


     function UpdateOptimizerStr(S:ShortString;var A:TOptimizerSwitches):Boolean;
      var
         Tok   : ShortString;
        DoSet,
        Found : Boolean;
        Opt   : TOptimizerSwitch;
      begin
        Result:=True;
        UpperVar(S);
        repeat
          Tok:=GetToken(S,',');
          if Tok='' then
           Break;
          if Copy(Tok,1,2)='NO' then
            begin
              Delete(Tok,1,2);
              DoSet:=False;
            end
          else
            DoSet:=True;
          Found:=False;
          for Opt:=Low(TOptimizerSwitch) to High(TOptimizerSwitch) do
            begin
              if OptimizerSwitchStr[Opt]=Tok then
                begin
                  Found:=True;
                  Break;
                end;
            end;
          if Found then
            begin
              if DoSet then
                Include(A,Opt)
              else
                Exclude(A,Opt);
            end
          else
            Result:=False;
        until False;
      end;


     function UpdateWPOStr(S: ShortString; var A: TWPOptimizerSwitches): Boolean;
      var
         Tok   : ShortString;
        DoSet,
        Found : Boolean;
        Opt   : TWPOptimizerSwitch;
      begin
        Result:=True;
        UpperVar(S);
        repeat
          Tok:=GetToken(S,',');
          if Tok='' then
           Break;
          if Copy(Tok,1,2)='NO' then
            begin
              Delete(Tok,1,2);
              DoSet:=False;
            end
          else
            DoSet:=True;
          Found:=False;
          if (Tok = 'ALL') then
            begin
              for Opt:=Low(TWPOptimizerSwitch) to High(TWPOptimizerSwitch) do
                if DoSet then
                  Include(A,Opt)
                else
                  Exclude(A,Opt);
            end
          else
            begin
              for Opt:=Low(TWPOptimizerSwitch) to High(TWPOptimizerSwitch) do
                begin
                  if WPOptimizerSwitchStr[Opt]=Tok then
                    begin
                      Found:=True;
                      Break;
                    end;
                end;
              if Found then
                begin
                  if DoSet then
                    Include(A,Opt)
                  else
                    Exclude(A,Opt);
                end
              else
                Result:=False;
            end;
        until False;
      end;


     function UpdateDebugStr(S:ShortString;var A:TDebugSwitches):Boolean;
      var
         Tok   : ShortString;
        DoSet,
        Found : Boolean;
        Opt   : TDebugSwitch;
      begin
        Result:=True;
        UpperVar(S);
        repeat
          Tok:=GetToken(S,',');
          if Tok='' then
           Break;
          if Copy(Tok,1,2)='NO' then
            begin
              Delete(Tok,1,2);
              DoSet:=False;
            end
          else
            DoSet:=True;
          Found:=False;
          for Opt:=Low(TDebugSwitch) to High(TDebugSwitch) do
            begin
              if DebugSwitchStr[Opt]=Tok then
                begin
                  Found:=True;
                  Break;
                end;
            end;
          if Found then
            begin
              if DoSet then
                Include(A,Opt)
              else
                Exclude(A,Opt);
            end
          else
            Result:=False;
        until False;
      end;


     function UpdateTargetSwitchStr(S: ShortString; var A: TTargetSwitches; Global: Boolean): Boolean;
      var
        Tok,
         Value : ShortString;
        SetStr: string[2];
        EqualsPos: LongInt;
        DoSet,
        GotValue,
        Found : Boolean;
        Opt   : TTargetSwitch;
      begin
        Result:=True;
        Value:='';
        repeat
          Tok:=GetToken(S,',');
          if Tok='' then
           Break;
          SetStr:=Upper(Copy(Tok,Length(Tok),1));
          if SetStr='-' then
            begin
              SetLength(Tok,Length(Tok)-1);
              DoSet:=False;
            end
          else
            DoSet:=True;
          { value specified? }
          GotValue:=False;
          EqualsPos:=Pos('=',Tok);
          if EqualsPos<>0 then
            begin
              Value:=Copy(Tok,EqualsPos+1,Length(Tok));
              Delete(Tok,EqualsPos,Length(Tok));
              GotValue:=True;
            end;
          Found:=False;
          UpperVar(Tok);
          for Opt:=Low(TTargetSwitch) to High(TTargetSwitch) do
            begin
              if TargetSwitchStr[Opt].Name=Tok then
                begin
                  Found:=True;
                  Break;
                end;
            end;
          if Found then
            begin
              if not Global and
                 TargetSwitchStr[Opt].IsGlobal then
                Result:=False
              else if not TargetSwitchStr[Opt].HasValue then
                begin
                  if GotValue then
                    Result:=False;
                  if (TargetSwitchStr[Opt].Define<>'') and (DoSet xor (Opt in A)) then
                    if DoSet then
                      def_system_macro(TargetSwitchStr[Opt].Define)
                    else
                      undef_system_macro(TargetSwitchStr[Opt].Define);
                  if DoSet then
                    Include(A,Opt)
                  else
                    Exclude(A,Opt)
                end
              else
                begin
                  if not GotValue or
                     not DoSet then
                    Result:=False
                  else
                    begin
                      case Opt of
                        ts_auto_getter_prefix:
                          Prop_Auto_Getter_Prefix:=Value;
                        ts_auto_setter_predix:
                          Prop_Auto_Setter_Prefix:=Value;
                        else
                          begin
                            WriteLn('Internalerror 2012053001');
                            Halt(1);
                          end;
                      end;
                    end;
                end;
            end
          else
            Result:=False;
        until False;
      end;

end.
