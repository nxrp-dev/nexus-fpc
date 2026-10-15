{
    Copyright (c) 2008 by Jonas Maebe

    Collects all whole program optimization plugin units

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

unit wpo;

{$i fpcdefs.inc}

interface

uses
  { all units with whole program optimisation components }
  optvirt,optdead;


  procedure InitWpo;
  procedure DoneWpo;

implementation

  uses
    Globals,
    CompHook,
    wpobase, wpoinfo;

  { called after command line parameters have been parsed }
  procedure InitWpo;
    begin
      { always create so we don't have to litter the source with if-tests }
      wpoinfomanager:=TWPOInfoManager.create;

      { register the classes we can/should potentially use }
      wpoinfomanager.registerwpocomponentclass(TProgDevirtInfo);
      wpoinfomanager.registerwpocomponentclass(TWPODeadCodeInfoFromExternalLinker);

      { assign input/output feedback files }
      if (WPOFeedbackInput<>'') then
        wpoinfomanager.setwpoinputfile(WPOFeedbackInput);
      if (WPOFeedbackOutput<>'') then
        wpoinfomanager.setwpooutputfile(WPOFeedbackOutput);

      { parse input }
      wpoinfomanager.parseandcheckwpoinfo;

      { abort if error }
      if (CodeGenError) then
        raise ECompilerAbort.Create;
    end;


  procedure DoneWpo;
    begin
      wpoinfomanager.free;
      wpoinfomanager:=nil;
      WPOFeedbackInput:='';
      WPOFeedbackOutput:='';
    end;


end.

