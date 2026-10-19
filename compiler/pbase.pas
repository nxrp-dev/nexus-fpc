{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Contains some helper routines for the parser

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
unit pbase;

{$i fpcdefs.inc}

interface

    uses
       CUtils,CClasses,
       tokens,GlobType,
       symconst,SymBase,symtype,symdef,SymSym,SymTable
       ;

    const
       { tokens that end a block or statement. And don't require
         a ; on the statement before }
       cEndTokens = [_SEMICOLON,_END,_ELSE,_UNTIL,_EXCEPT,_FINALLY];

    var
       { true, if we are after an assignment }
       AfterAssignment : Boolean = false;

       { true, if we are parsing arguments }
       InArgs : Boolean = false;

       { true, if we are parsing arguments allowing named parameters }
       NamedArgsAllowed : Boolean = false;

       { true, if we got an @ to get the address }
       GotAddrN  : Boolean = false;

       { special for handling procedure vars }
       GetProcVarDef : TProcVarDef = nil;

       { special for function reference vars }
       GetFuncRefDef : TObjectDef = nil;

       { for operators }
       OpToken : TToken;

       { true, if only routine headers should be parsed }
       ParseOnly : Boolean;

       { true, if we found a name for a named arg }
       FoundArgName : Boolean;

       { true, if we are parsing generic declaration }
       ParseGeneric : Boolean;

    procedure IdentifierNotFound(const AName:String);
    procedure IdentifierNotFound(const AName:String;const AFilePos:TFilePosInfo);

{    function tokenstring(i : ttoken):string;}

    { consumes token i, if the current token is unequal i }
    { a syntax error is written                           }
    procedure Consume(AToken : TToken);

    { Same as consume, but will not attempt to read next token if the token is a point }

    procedure ConsumeLastDot;

    {Tries to consume the token i, and returns true if it was consumed:
     if token=i.}
    function TryToConsume(AToken:TToken):Boolean;

    { consumes all tokens til atoken (for error recovering }
    procedure ConsumeAllUntil(AToken : TToken);

    { consumes tokens while they are semicolons }
    procedure ConsumeEmptyStats;

    { reads a list of identifiers into a string list }
    { consume a symbol, if not found give an error and
      and return an errorsym }
    function ConsumeSym(var ASym:TSym;var ASymTable:TSymTable):Boolean;
    function ConsumeSymOrgID(var ASym:TSym;var ASymTable:TSymTable;var AOrgID : String):Boolean;

    type
      TConsumeUnitSymFlag = (
        cufConsumeID,
        cufAllowSpecialize,
        cufCheckAttrSuffix,
        cufAllowUnitOnly  { allow unit name without point, e.g. NameOf(unitname) }
      );
      TConsumeUnitSymFlags = set of TConsumeUnitSymFlag;

    function TryConsumeUnitSym(var ASym:TSym;var ASymTable:TSymTable;var ATokenToConsume:TToken;AFlags:TConsumeUnitSymFlags;out AIsSpecialize:Boolean;ASymPattern:TSymStr):Boolean;
    function TryConsumeUnitSymNoSpecialize(var ASym:TSym;var ASymTable:TSymTable;var ATokenToConsume:TToken;AFlags:TConsumeUnitSymFlags;ASymPattern:TSymStr):Boolean;

    function TryConsumeHintDirective(var ASymOptions:TSymOptions; var ADeprecatedMsg:PShortString):Boolean;

    { just for an accurate position of the end of a procedure (PM) }
    var
       LastEndTokenFilePos: TFilePosInfo;


implementation

    uses
       Globals,Scanner,Verbose,FModule;

{****************************************************************************
                               Token Parsing
****************************************************************************}

     procedure IdentifierNotFound(const AName:String);
       begin
         Message1(sym_e_id_not_found,AName);
         { show a fatal that you need -S2 or -Sd, but only
           if we just parsed the a token that has m_class }
         if not(m_class in CurrentSettings.ModeSwitches) and
            (Upper(AName)=CurrentScanner.FPattern) and
            (m_class in tokeninfo^[CurrentScanner.FIDToken].keyword) then
           Message(parser_f_need_objfpc_or_delphi_mode);
       end;


     procedure IdentifierNotFound(const AName:String;const AFilePos:TFilePosInfo);
       begin
         MessagePos1(AFilePos,sym_e_id_not_found,AName);
         { show a fatal that you need -S2 or -Sd, but only
           if we just parsed the a token that has m_class }
         if not(m_class in CurrentSettings.ModeSwitches) and
            (Upper(AName)=CurrentScanner.FPattern) and
            (m_class in tokeninfo^[CurrentScanner.FIDToken].keyword) then
           MessagePos(AFilePos,parser_f_need_objfpc_or_delphi_mode);
       end;


    { consumes token i, write error if token is different }

    procedure Consume(AToken : TToken);

    begin
        if (CurrentScanner.FToken<>AToken) and (CurrentScanner.FIDToken<>AToken) then
          begin
            if CurrentScanner.FHadMultilineString then
              Message2(scan_f_unterminated_multiline_string,
                       ToStr(CurrentScanner.FMultilineStartLine),
                       ToStr(CurrentScanner.FMultilineStartColumn))
            else if CurrentScanner.FToken=_id then
              Message2(scan_f_syn_expected,tokeninfo^[AToken].str,'identifier '+CurrentScanner.FPattern)
            else
              Message2(scan_f_syn_expected,tokeninfo^[AToken].str,tokeninfo^[CurrentScanner.FToken].str);
          end
        else
          begin
            if CurrentScanner.FToken=_END then
              LastEndTokenFilePos:=CurrentTokenPos;
            CurrentScanner.ReadToken(true);
          end;
      end;

    procedure ConsumeLastDot;

    begin
        if (CurrentScanner.FToken<>_POINT) then
          begin
          if CurrentScanner.FToken=_id then
            Message2(scan_f_syn_expected,tokeninfo^[_POINT].str,'identifier '+CurrentScanner.FPattern)
          else
            Message2(scan_f_syn_expected,tokeninfo^[_POINT].str,tokeninfo^[CurrentScanner.FToken].str)
          end
        else if CurrentScanner.FChar<>#0 then
          CurrentScanner.ReadToken(true);
    end;

    function TryToConsume(AToken:TToken):Boolean;
      begin
        TryToConsume:=false;
        if (CurrentScanner.FToken=AToken) or (CurrentScanner.FIDToken=AToken) then
         begin
           TryToConsume:=true;
           if CurrentScanner.FToken=_END then
            LastEndTokenFilePos:=CurrentTokenPos;
           CurrentScanner.ReadToken(true);
         end;
      end;


    procedure ConsumeAllUntil(AToken : TToken);
      begin
         while (CurrentScanner.FToken<>AToken) and (CurrentScanner.FIDToken<>AToken) do
          begin
            Consume(CurrentScanner.FToken);
            if CurrentScanner.FToken=_EOF then
             begin
               Consume(AToken);
               if CurrentScanner.FHadMultilineString then
                 Message2(scan_f_unterminated_multiline_string,
                          ToStr(CurrentScanner.FMultilineStartLine),
                          ToStr(CurrentScanner.FMultilineStartColumn))
               else
                 Message(scan_f_end_of_file);
               exit;
             end;
          end;
      end;


    procedure ConsumeEmptyStats;
      begin
         repeat
         until not TryToConsume(_SEMICOLON);
      end;


    { check if a symbol contains the hint directive, and if so gives out a hint
      if required.

      If this code is changed, it's likly that consume_sym_orgid and factor_read_id
      must be changed as well (FK)
    }
    function ConsumeSym(var ASym:TSym;var ASymTable:TSymTable):Boolean;
      var
        lToken : TToken;
      begin
        { first check for identifier }
        if CurrentScanner.FToken<>_ID then
          begin
            Consume(_ID);
            ASym:=GenErrorSym;
            ASymTable:=nil;
            Result:=false;
            exit;
          end;
        SearchSym(CurrentScanner.FPattern,ASym,ASymTable);
        { handle unit specification like System.Writeln }
        TryConsumeUnitSymNoSpecialize(ASym,ASymTable,lToken,[cufConsumeID],CurrentScanner.FPattern);
        { if nothing found give error and return errorsym }
        if Assigned(ASym) then
          Check_Hints(ASym,ASym.SymOptions,ASym.DeprecatedMsg)
        else
          begin
            IdentifierNotFound(CurrentScanner.FOrgPattern);
            ASym:=GenErrorSym;
            ASymTable:=nil;
          end;
        Consume(lToken);
        Result:=Assigned(ASym);
      end;


    { check if a symbol contains the hint directive, and if so gives out a hint
      if required and returns the id with it's original casing
    }
    function ConsumeSymOrgID(var ASym:TSym;var ASymTable:TSymTable;var AOrgID : String):Boolean;
      var
        lToken : TToken;
      begin
        { first check for identifier }
        if CurrentScanner.FToken<>_ID then
          begin
            Consume(_ID);
            ASym:=GenErrorSym;
            ASymTable:=nil;
            Result:=false;
            exit;
          end;
        SearchSym(CurrentScanner.FPattern,ASym,ASymTable);
        { handle unit specification like System.Writeln }
        TryConsumeUnitSymNoSpecialize(ASym,ASymTable,lToken,[cufConsumeID],CurrentScanner.FPattern);
        { if nothing found give error and return errorsym }
        if Assigned(ASym) then
          Check_Hints(ASym,ASym.SymOptions,ASym.DeprecatedMsg)
        else
          begin
            IdentifierNotFound(CurrentScanner.FOrgPattern);
            ASym:=GenErrorSym;
            ASymTable:=nil;
          end;
        AOrgID:=CurrentScanner.FOrgPattern;
        Consume(lToken);
        Result:=Assigned(ASym);
      end;


    function TryConsumeUnitSym(var ASym:TSym;var ASymTable:TSymTable;var ATokenToConsume:TToken;AFlags:TConsumeUnitSymFlags;out AIsSpecialize:Boolean;ASymPattern:TSymStr):Boolean;
      var
        lModule: TModule;
        lNamespace:AnsiString;
        lNamespaceSym:TSym;
        lNamespaceItem : TCmdStrListItem;

        procedure ConsumeNamespace;
          begin
            while Assigned(ASym) and (ASym.typ=namespacesym) do
              begin
                { we have a namespace. the next identifier should be either a namespace or a unit }
                SearchSym_In_Module(lModule,lNamespace+'.'+CurrentScanner.FPattern,ASym,ASymTable);
                if Assigned(ASym) and (ASym.typ in [namespacesym,UnitSym]) then
                  begin
                    lNamespace:=lNamespace+'.'+CurrentScanner.FPattern;
                    lNamespaceSym:=ASym;
                    Consume(_ID);
                    Consume(_POINT);
                  end;
              end;
            { check if there is a hidden unit with this current_scanner.pattern in the namespace }
            if not Assigned(ASym) and
               Assigned(lNamespaceSym) and (lNamespaceSym.typ=namespacesym) and Assigned(TNamespaceSym(lNamespaceSym).UnitSym) then
              ASym:=TNamespaceSym(lNamespaceSym).UnitSym;
          end;

      begin
        Result:=false;
        ATokenToConsume:=_ID;
        AIsSpecialize:=false;

        if not Assigned(ASym) and (CurrentScanner.FPattern<>'') and (NamespaceList.count>0) then
          begin
            lModule:=Get_Module(CurrentFilePos.moduleindex);
            if not Assigned(lModule) then
              InternalError(2018050301);

            lNamespaceItem:=TCmdStrListItem(NamespaceList.first);
            while Assigned(lNamespaceItem) do
              begin
                lNamespace:=upper(lNamespaceItem.str)+'.'+ASymPattern;

                if SearchSym_In_Module(lModule,lNamespace,ASym,ASymTable) and
                    (ASym.typ in [UnitSym,namespacesym]) then
                  break;

                lNamespaceItem:=TCmdStrListItem(lNamespaceItem.next);
              end;
          end;

        if Assigned(ASym) and (ASym.typ in [UnitSym,namespacesym]) then
          begin
            if not(ASym.owner.SymTableType in [staticsymtable,GlobalSymTable]) then
              InternalError(2005011503);
            { only allow unit.symbol access if the name was
              found in the current module
              we can use iscurrentunit because generic specializations does not
              change current_unit variable }
            lModule:=Find_Module_From_SymTable(ASym.Owner);
            if not Assigned(lModule) then
              InternalError(2010011201);
            if lModule.ModuleID=CurrentFilePos.moduleindex then
              begin
                if cufConsumeID in AFlags then
                  begin
                    Consume(_ID);
                    if (cufAllowUnitOnly in AFlags) and
                       (CurrentScanner.FToken<>_POINT) then
                      begin
                        ATokenToConsume:=NOTOKEN;
                        exit(true);
                      end;
                  end;
                Consume(_POINT);
                if ASym.typ=namespacesym then
                  begin
                    lNamespace:=ASym.name;
                    lNamespaceSym:=ASym;
                    ConsumeNamespace;
                    if not Assigned(ASym) and (NamespaceList.count>0) then
                      begin
                        lNamespaceItem:=TCmdStrListItem(NamespaceList.first);
                        while Assigned(lNamespaceItem) do
                          begin
                            lNamespace:=upper(lNamespaceItem.str)+'.'+lNamespaceSym.name;

                            if SearchSym_In_Module(lModule,lNamespace,ASym,ASymTable) and
                                (ASym.typ in [UnitSym,namespacesym]) then
                              begin
                                ConsumeNamespace;
                                break;
                              end;

                            lNamespaceItem:=TCmdStrListItem(lNamespaceItem.next);
                          end;
                      end;
                    if Assigned(ASym) and (ASym.typ<>UnitSym) then
                      InternalError(2011082601);
                    if not Assigned(ASym) then
                      begin
                        Result:=true;
                        ASymTable:=nil;
                        exit;
                      end;
                  end;
                case CurrentScanner.FToken of
                  _ID:
                    begin
                      if cufCheckAttrSuffix in AFlags then
                        begin
                          if SearchSym_In_Module(TUnitSym(ASym).module,CurrentScanner.FPattern+CustomAttributeSuffix,ASym,ASymTable) then
                            exit(true);
                        end;
                      { Resolve the default Char/PChar from the invocation's
                        text model, regardless of the System alias. }
                      if ((CurrentScanner.FPattern='CHAR') or
                          (CurrentScanner.FPattern='PCHAR')) and
                         (TModule(TUnitSym(ASym).module).GlobalSymTable=SystemUnit) then
                        begin
                          if CurrentScanner.FPattern='PCHAR' then
                            if m_default_unicodestring in CurrentSettings.ModeSwitches then
                              SearchSym_In_Module(TUnitSym(ASym).module,'PWIDECHAR',ASym,ASymTable)
                            else
                              SearchSym_In_Module(TUnitSym(ASym).module,'PANSICHAR',ASym,ASymTable)
                          else if m_default_unicodestring in CurrentSettings.ModeSwitches then
                            SearchSym_In_Module(TUnitSym(ASym).module,'WIDECHAR',ASym,ASymTable)
                          else
                            SearchSym_In_Module(TUnitSym(ASym).module,'ANSICHAR',ASym,ASymTable)
                        end
                      else
                        if (cufAllowSpecialize in AFlags) and (CurrentScanner.FIDToken=_SPECIALIZE) then
                          begin
                            Consume(_ID);
                            AIsSpecialize:=true;
                            if CurrentScanner.FToken=_ID then
                              begin
                                if (cufCheckAttrSuffix in AFlags) and
                                    SearchSym_In_Module(TUnitSym(ASym).module,CurrentScanner.FPattern+CustomAttributeSuffix,ASym,ASymTable) then
                                  exit(true);
                                SearchSym_In_Module(TUnitSym(ASym).module,CurrentScanner.FPattern,ASym,ASymTable);
                              end;
                          end
                        else
                          SearchSym_In_Module(TUnitSym(ASym).module,CurrentScanner.FPattern,ASym,ASymTable);
                     end;
                  _STRING:
                    begin
                      if cs_compilesystem in CurrentSettings.ModuleSwitches then
                        Message(parser_e_nostringaliasinsystem);
                      { system.string? }
                      if TModule(TUnitSym(ASym).module).GlobalSymTable=SystemUnit then
                        begin
                          if cs_refcountedstrings in CurrentSettings.LocalSwitches then
                            begin
                              if m_default_unicodestring in CurrentSettings.ModeSwitches then
                                SearchSym_In_Module(TUnitSym(ASym).module,'UNICODESTRING',ASym,ASymTable)
                              else
                                SearchSym_In_Module(TUnitSym(ASym).module,'ANSISTRING',ASym,ASymTable)
                            end
                          else
                            SearchSym_In_Module(TUnitSym(ASym).module,'SHORTSTRING',ASym,ASymTable);
                          ATokenToConsume:=_STRING;
                        end;
                    end
                  else
                    ;
                  end;
              end
            else
              begin
                ASym:=nil;
                ASymTable:=nil;
              end;
            Result:=true;
          end;
      end;


    function TryConsumeUnitSymNoSpecialize(var ASym:TSym;var ASymTable:TSymTable;var ATokenToConsume:TToken;AFlags:TConsumeUnitSymFlags;ASymPattern:TSymStr):Boolean;
      var
        lIsSpecialize: Boolean;
      begin
        exclude(AFlags,cufAllowSpecialize);
        Result:=TryConsumeUnitSym(ASym,ASymTable,ATokenToConsume,AFlags,lIsSpecialize,ASymPattern);
      end;

    function TryConsumeHintDirective(var ASymOptions:TSymOptions; var ADeprecatedMsg:PShortString):Boolean;
      var
        lLastIsDeprecated:Boolean;
      begin
        TryConsumeHintDirective:=false;
        if not(m_hintdirective in CurrentSettings.ModeSwitches) then
          exit;
        repeat
          lLastIsDeprecated:=false;
          case CurrentScanner.FIDToken of
            _LIBRARY:
              begin
                if sp_hint_library in ASymOptions then
                  Message1(parser_e_dir_not_allowed,arraytokeninfo[CurrentScanner.FIDToken].str)
                else
                  include(ASymOptions,sp_hint_library);
                TryConsumeHintDirective:=true;
              end;
            _DEPRECATED:
              begin
                if sp_hint_deprecated in ASymOptions then
                  Message1(parser_e_dir_not_allowed,arraytokeninfo[CurrentScanner.FIDToken].str)
                else
                  include(ASymOptions,sp_hint_deprecated);
                TryConsumeHintDirective:=true;
                lLastIsDeprecated:=true;
              end;
            _EXPERIMENTAL:
              begin
                if sp_hint_experimental in ASymOptions then
                  Message1(parser_e_dir_not_allowed,arraytokeninfo[CurrentScanner.FIDToken].str)
                else
                  include(ASymOptions,sp_hint_experimental);
                TryConsumeHintDirective:=true;
              end;
            _PLATFORM:
              begin
                if sp_hint_platform in ASymOptions then
                  Message1(parser_e_dir_not_allowed,arraytokeninfo[CurrentScanner.FIDToken].str)
                else
                  include(ASymOptions,sp_hint_platform);
                TryConsumeHintDirective:=true;
              end;
            _UNIMPLEMENTED:
              begin
                if sp_hint_unimplemented in ASymOptions then
                  Message1(parser_e_dir_not_allowed,arraytokeninfo[CurrentScanner.FIDToken].str)
                else
                  include(ASymOptions,sp_hint_unimplemented);
                TryConsumeHintDirective:=true;
              end;
            else
              break;
          end;
          Consume(CurrentScanner.FToken);
          { handle deprecated message }
          if ((CurrentScanner.FToken=_CSTRING) or (CurrentScanner.FToken=_CCHAR)) and lLastIsDeprecated then
            begin
              if not Assigned(ADeprecatedMsg) then
                begin
                  if CurrentScanner.FToken=_CSTRING then
                    ADeprecatedMsg:=StringDup(CurrentScanner.FCStringPattern)
                  else
                    ADeprecatedMsg:=StringDup(CurrentScanner.FPattern);
                end;
              Consume(CurrentScanner.FToken);
              include(ASymOptions,sp_has_deprecated_msg);
            end;
        until false;
      end;

end.
