{
    Copyright (c) 1998-2002 by Florian Klaempfl

    This unit handles the pass_typecheck and node conversion pass

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
unit pass_1;

{$i fpcdefs.inc}

interface

    uses
       node;

    procedure TypeCheckPass(var p : TNode);
    function  DoTypeCheckPass(var p : TNode) : boolean;
    function  DoTypeCheckPassChanged(var p : TNode; out nodechanged: boolean) : boolean;

    procedure FirstPass(var p : TNode);
    function  DoFirstPass(var p : TNode) : boolean;
{$ifdef state_tracking}
    procedure  DoTrackStatePass(p:TNode);
{$endif}


implementation

    uses
      GlobType,CompHook,
      Globals,
      ProcInfo,
      Verbose,
      symdef
{$ifdef extdebug}
      ,htypechk
      ,cgbase
{$endif extdebug}
{$ifdef state_tracking}
      ,nstate
{$endif}
      ;

{*****************************************************************************
                            Global procedures
*****************************************************************************}

    procedure TypeCheckPassInternalLoop(var p : TNode; out node_changed: boolean);
      var
         hp        : TNode;
         oldflags  : TNodeFlags;
      begin
        CodeGenError:=false;
        repeat
          CurrentFilePos:=p.fileinfo;
          CurrentSettings.LocalSwitches:=p.LocalSwitches;
          status.verbosity:=p.verbosity;
          hp:=p.pass_typecheck;
          { should the node be replaced? }
          if Assigned(hp) then
            begin
              node_changed:=true;
              oldflags:=p.flags;
              p.free;
              { switch to new node }
              p:=hp;
              { transfer generic parameter flag }
              if nf_generic_para in oldflags then
                include(p.flags,nf_generic_para);
            end;
        until not Assigned(hp) or
              Assigned(hp.resultdef);
        if CodeGenError then
          begin
            include(p.transientflags,tnf_error);
            { default to errortype if no type is set yet }
            if p.resultdef=nil then
              p.resultdef:=generrordef;
          end;
      end;

    procedure TypeCheckPassInternal(var p : TNode; out node_changed: boolean);
      var
         oldcodegenerror  : boolean;
         oldlocalswitches : TLocalSwitches;
         oldverbosity     : LongInt;
         oldpos    : TFilePosInfo;
      begin
        node_changed:=false;
        if (p.resultdef=nil) then
          begin
            oldcodegenerror:=CodeGenError;
            oldpos:=CurrentFilePos;
            oldlocalswitches:=CurrentSettings.LocalSwitches;
            oldverbosity:=status.verbosity;
            TypeCheckPassInternalLoop(p, node_changed);
            CurrentSettings.LocalSwitches:=oldlocalswitches;
            CurrentFilePos:=oldpos;
            status.verbosity:=oldverbosity;
            CodeGenError:=CodeGenError or oldcodegenerror;
          end
        else
          begin
            { update the codegenerror boolean with the previous result of this node }
            if (tnf_error in p.transientflags) then
              CodeGenError:=true;
          end;
      end;


    procedure TypeCheckPass(var p : TNode);
      var
        node_changed: boolean;
      begin
        TypeCheckPassInternal(p,node_changed);
      end;


    function DoTypeCheckPassChanged(var p : TNode; out nodechanged: boolean) : boolean;
      begin
         CodeGenError:=false;
         TypeCheckPassInternal(p,nodechanged);
         DoTypeCheckPassChanged:=CodeGenError;
      end;


    function DoTypeCheckPass(var p : TNode) : boolean;
      var
        nodechanged: boolean;
      begin
         result:=DoTypeCheckPassChanged(p,nodechanged);
      end;


    procedure FirstPass(var p : TNode);
      var
         oldcodegenerror  : boolean;
         oldlocalswitches : TLocalSwitches;
         oldpos    : TFilePosInfo;
         oldverbosity: LongInt;
         hp : TNode;
         nodechanged : boolean;
      begin
         if (tnf_pass1_done in p.transientflags) then
           exit;

         if not(tnf_error in p.transientflags) then
           begin
             oldcodegenerror:=CodeGenError;
             oldpos:=CurrentFilePos;
             oldlocalswitches:=CurrentSettings.LocalSwitches;
             oldverbosity:=status.verbosity;
             CodeGenError:=false;
             repeat
               { The error flag takes precedence over the 'do not execute' flag,
                 as it's assumed the node tree isn't tenable beyond this point }
               if (tnf_do_not_execute in p.transientflags) then
                 InternalError(2022112401);

               { checks make always a call }
               if ([cs_check_range,cs_check_overflow,cs_check_stack] * CurrentSettings.LocalSwitches <> []) then
                 include(CurrentProcInfo.flags,pi_do_call);
               { determine the resultdef if not done }
               if (p.resultdef=nil) then
                 begin
                   TypeCheckPassInternalLoop(p,nodechanged);
                 end;

               hp:=nil;
               if not(tnf_error in p.transientflags) then
                 begin
                   CurrentFilePos:=p.fileinfo;
                   CurrentSettings.LocalSwitches:=p.LocalSwitches;
                   status.verbosity:=p.verbosity;
                   { first pass }
                   hp:=p.pass_1;
                   { inlining happens in pass_1 and can cause new }
                   { simplify opportunities                       }
                   if not Assigned(hp) then
                     hp:=p.simplify(true);
                   { should the node be replaced? }
                   if Assigned(hp) then
                     begin
                       p.free;
                       { switch to new node }
                       p:=hp;
                     end;
                   if CodeGenError then
                     include(p.transientflags,tnf_error);
                 end;
             until not Assigned(hp) or
                   (tnf_pass1_done in hp.transientflags);
             include(p.transientflags,tnf_pass1_done);
{$ifdef EXTDEBUG}
             if not(tnf_error in p.transientflags) then
               begin
                 if (p.expectloc=LOC_INVALID) then
                   Comment(VWarning,'Expectloc is not set in firstpass: '+nodetype2str[p.nodetype]);
               end;
{$endif EXTDEBUG}
             CodeGenError:=CodeGenError or oldcodegenerror;
             CurrentSettings.LocalSwitches:=oldlocalswitches;
             CurrentFilePos:=oldpos;
             status.verbosity:=oldverbosity;
           end
         else
           CodeGenError:=true;
      end;


    function DoFirstPass(var p : TNode) : boolean;
      begin
         CodeGenError:=false;
         FirstPass(p);
{$ifdef state_tracking}
         WriteLn('TRACKSTART');
         WriteLn('before');
         writenode(p);
         DoTrackStatePass(p);
         WriteLn('after');
         writenode(p);
         WriteLn('TRACKDONE');
{$endif}
         DoFirstPass:=CodeGenError;
      end;

{$ifdef state_tracking}
     procedure DoTrackStatePass(p:TNode);

     begin
        aktstate:=Tstate_storage.create;
        p.track_state_pass(true);
            aktstate.free;
            aktstate := nil;
     end;
{$endif}

end.
