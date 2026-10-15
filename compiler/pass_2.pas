{
    Copyright (c) 1998-2002 by Florian Klaempfl

    This unit handles the codegeneration pass

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
unit pass_2;

{$i fpcdefs.inc}

interface

uses
   node;

    type
       TEnumFlowControl = (
         fc_exit,
         fc_break,
         fc_continue,
         fc_inflowcontrol,
         fc_gotolabel,
         { in block that has an exception handler associated with it
           (try..except, try..finally, exception block of try..except, ... }
         fc_catching_exceptions,
         { in try block of try..finally and target uses specific unwinding }
         fc_unwind_exit,
         fc_unwind_loop,
         { the left side of an expression is already handled, so we are
           not allowed to do ssl }
         fc_lefthandled,
         { in block where the exit statement jumps to an extra code instead of
           immediately finishing execution of the current routine. }
         fc_no_direct_exit);

       TFlowControl = set of TEnumFlowControl;

    var
       flowcontrol : TFlowControl;

{ produces the actual code }
function DoSecondPass(var p : TNode) : boolean;
procedure SecondPass(p : TNode);


implementation

   uses
     CUtils,
     GlobType,Verbose,
     Globals,
     AAsmData,
     cgobj
{$ifdef EXTDEBUG}
     ,cgbase
     ,aasmtai
{$endif}
     ;

{*****************************************************************************
                              SecondPass
*****************************************************************************}

{$ifdef EXTDEBUG}
     var
       secondprefix : string;

     procedure logsecond(ht:TNodeType; entry: boolean);
       const
         secondnames: array[TNodeType] of string[13] =
            ('<emptynode>',
             'add-addn',  {addn}
             'add-muln',  {muln}
             'add-subn',  {subn}
             'moddiv-divn',      {divn}
             'add-symdifn',      {symdifn}
             'moddiv-modn',      {modn}
             'assignment',  {assignn}
             'load',        {loadn}
             'nothing-range',     {range}
             'add-ltn',  {ltn}
             'add-lten',  {lten}
             'add-gtn',  {gtn}
             'add-gten',  {gten}
             'add-equaln',  {equaln}
             'add-unequaln',  {unequaln}
             'in',    {inn}
             'add-orn',  {orn}
             'add-xorn',  {xorn}
             'shlshr-shrn',      {shrn}
             'shlshr-shln',      {shln}
             'add-slashn',  {slashn}
             'add-andn',  {andn}
             'subscriptn',  {subscriptn}
             'deref',       {derefn}
             'addr',        {addrn}
             'ordconst',    {ordconstn}
             'typeconv',    {typeconvn}
             'calln',       {calln}
             'noth-callpar',{callparan}
             'realconst',   {realconstn}
             'unaryminus',  {unaryminusn}
             'unaryplus',   {unaryplusn}
             'asm',         {asmn}
             'vecn',        {vecn}
             'pointerconst',{pointerconstn}
             'stringconst', {stringconstn}
             'not',         {notn}
             'inline',      {inlinen}
             'niln',        {niln}
             'error',       {errorn}
             'nothing-typen',     {typen}
             'setelement',  {setelementn}
             'setconst',    {setconstn}
             'blockn',      {blockn}
             'statement',   {statementn}
             'ifn',         {ifn}
             'breakn',      {breakn}
             'continuen',   {continuen}
             'while_repeat', {whilerepeatn}
             'for',         {forn}
             'exitn',       {exitn}
             'case',        {casen}
             'label',       {labeln}
             'goto',        {goton}
             'tryexcept',   {tryexceptn}
             'raise',       {raisen}
             'tryfinally',  {tryfinallyn}
             'on',    {onn}
             'is',    {isn}
             'as',    {asn}
             'add-starstar',  {starstarn}
             'arrayconstruc', {arrayconstructn}
             'noth-arrcnstr',     {arrayconstructrangen}
             'tempcreaten',
             'temprefn',
             'tempdeleten',
             'addoptn',
             'nothing-nothg',     {nothingn}
             'loadvmt',      {loadvmtn}
             'guidconstn',
             'rttin',
             'loadparentfpn',
             'objselectorn',
             'objcprotocoln',
             'specializen',
             'finalizetemps'
             );
      var
        p: pchar;
      begin
        if entry then
          begin
            secondprefix:=secondprefix+' ';
            p := StrPNew(secondprefix+'second '+secondnames[ht]+' (entry)')
          end
        else
          begin
            p := StrPNew(secondprefix+'second '+secondnames[ht]+' (exit)');
            delete(secondprefix,length(secondprefix),1);
          end;
        CurrentAsmData.CurrAsmList.concat(TAIComment.create(p));
      end;
{$endif EXTDEBUG}

     procedure SecondPass(p : TNode);
      var
         oldcodegenerror  : boolean;
         oldlocalswitches : TLocalSwitches;
         oldpos    : TFilePosInfo;
         oldexecutionweight : LongInt;
      begin
         if not Assigned(p) then
          InternalError(200208221);
         if not(tnf_error in p.transientflags) then
          begin
            { The error flag takes precedence over the 'do not execute' flag,
              as it's assumed the node tree isn't tenable beyond this point }
            if (tnf_do_not_execute in p.transientflags) then
              InternalError(2022112402);

            oldcodegenerror:=CodeGenError;
            oldlocalswitches:=CurrentSettings.LocalSwitches;
            oldpos:=CurrentFilePos;
            CurrentFilePos:=p.fileinfo;
            CurrentSettings.LocalSwitches:=p.LocalSwitches;
            CodeGenError:=false;
            oldexecutionweight:=cg.executionweight;
            if Assigned(p.optinfo) then
              cg.executionweight:=min(p.optinfo^.executionweight,high(cg.executionweight))
            else
              cg.executionweight:=100;
{$ifdef EXTDEBUG}
            if (p.expectloc=LOC_INVALID) then
              Comment(VWarning,'ExpectLoc is not set before secondpass: '+nodetype2str[p.nodetype]);
            if (p.location.loc<>LOC_INVALID) then
              Comment(VWarning,'Location.Loc is already set before secondpass: '+nodetype2str[p.nodetype]);
            if (cs_asm_nodes in CurrentSettings.GlobalSwitches) then
              logsecond(p.nodetype,true);
{$endif EXTDEBUG}
            p.pass_generate_code;
{$ifdef EXTDEBUG}
            if (cs_asm_nodes in CurrentSettings.GlobalSwitches) then
              logsecond(p.nodetype,false);
            if (not CodeGenError) then
             begin
               if (p.location.loc<>p.expectloc) then
                 begin
                   if ((p.location.loc=loc_register) and (p.expectloc=loc_cregister))
                      or ((p.location.loc=loc_fpuregister) and (p.expectloc=loc_cfpuregister))
{$ifdef SUPPORT_MMX}
                      or ((p.location.loc=loc_mmxregister) and (p.expectloc=loc_cmmxregister))
{$endif SUPPORT_MMX}
                      or ((p.location.loc=loc_reference) and (p.expectloc=loc_creference))
                      or ((p.location.loc=loc_void) and (p.nodetype = calln)) then
                     Comment(VNote,'Location ('+tcgloc2str[p.location.loc]+') not equal to expectloc ('+tcgloc2str[p.expectloc]+'): '+nodetype2str[p.nodetype])
                   else
                     Comment(VWarning,'Location ('+tcgloc2str[p.location.loc]+') not equal to expectloc ('+tcgloc2str[p.expectloc]+'): '+nodetype2str[p.nodetype]);
                 end;
               if (p.location.loc=LOC_INVALID) then
                 Comment(VWarning,'Location not set in secondpass: '+nodetype2str[p.nodetype]);
             end;
{$endif EXTDEBUG}
            if CodeGenError then
              include(p.transientflags,tnf_error);
            CodeGenError:=CodeGenError or oldcodegenerror;
            CurrentSettings.LocalSwitches:=oldlocalswitches;
            CurrentFilePos:=oldpos;
            cg.executionweight:=oldexecutionweight;
          end
         else
           CodeGenError:=true;
      end;


    function DoSecondPass(var p : TNode) : boolean;
      begin
         { current_asmdata.CurrAsmList must be empty }
         if not CurrentAsmData.CurrAsmList.empty then
           InternalError(200405201);

         { clear errors before starting }
         CodeGenError:=false;
         if not(tnf_error in p.transientflags) then
           SecondPass(p);
         DoSecondPass:=CodeGenError;
      end;


end.
