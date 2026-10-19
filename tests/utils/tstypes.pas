{
    This file is part of the Free Pascal test suite.
    Copyright (c) 2007 by the Free Pascal development team.

    This unit contains the shared compiler fixture directives.

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

{ Compiler fixture directive data. Native nxtest owns execution and results. }
unit tstypes;
{$mode objfpc}{$H+}{$modeswitch advancedrecords}
interface
type
  TCharSet = set of Char;
  TVerboseLevel = (V_Abort, V_Error, V_Warning, V_Normal, V_Debug, V_SQL);
  TTestInfo = record
    Name : String;
    CPU : String;
    OS : string;
    Version : string;
    AddDate : TDateTime;
    Graph : boolean;
    Interactive : boolean;
    Result :  integer;
    Fail : boolean;
    ReCompile : boolean;
    NoRun : boolean;
    NeedLibrary : boolean;
    KnownRunError : Integer;
    Known : boolean;
    Note : String;
    Description : String;
    Source : String;
    Opts : String;
    DelOptions,
    SkipCPU,
    SkipEmu,
    NeedTarget,
    SkipTarget,
    MaxVersion,
    KnownRunNote,
    KnownCompileNote,
    RecompileOpt: string;
    KnownCompileError : longint;
    NeededAfter   : boolean;
    IsKnownRunError : Boolean;
    Timeout       : longint;
    Category      : string;
    Files         : string;
    ConfigFileSrc : string;
    ConfigFileDst : string;
    WpoParas      : string;
    WpoPasses     : longint;
    DelFiles      : string;
    ExpectMsgs    : array of longint;
    Property NeedCPU : String Read CPU Write CPU;
    Property MinVersion : String Read Version Write Version;
    Property UsesGraph : boolean read Graph Write Graph;
    Property IsInteractive : boolean Read Interactive write INTERACTIVE;
    Property ResultCode : Integer Read RESULT Write RESULT;
    Property ShouldFail : Boolean Read FAIL Write Fail;
    Property NeedRecompile : Boolean Read Recompile Write Recompile;
    Property IsKnownCompileError : Boolean read KNOWN Write KNown;
    Property NeedOptions : String Read OPTS Write OPTS;
  end;
  TConfig = TTestInfo;
implementation
end.
