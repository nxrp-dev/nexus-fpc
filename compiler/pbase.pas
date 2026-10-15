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
       endtokens = [_SEMICOLON,_END,_ELSE,_UNTIL,_EXCEPT,_FINALLY];

    var
       { true, if we are after an assignment }
       afterassignment : boolean = false;

       { true, if we are parsing arguments }
       in_args : boolean = false;

       { true, if we are parsing arguments allowing named parameters }
       named_args_allowed : boolean = false;

       { true, if we got an @ to get the address }
       got_addrn  : boolean = false;

       { special for handling procedure vars }
       getprocvardef : TProcVarDef = nil;

       { special for function reference vars }
       getfuncrefdef : TObjectDef = nil;

       { for operators }
       optoken : TToken;

       { true, if only routine headers should be parsed }
       parse_only : boolean;

       { true, if we found a name for a named arg }
       found_arg_name : boolean;

       { true, if we are parsing generic declaration }
       parse_generic : boolean;

    procedure identifier_not_found(const s:string);
    procedure identifier_not_found(const s:string;const filepos:TFilePosInfo);

{    function tokenstring(i : ttoken):string;}

    { consumes token i, if the current token is unequal i }
    { a syntax error is written                           }
    procedure consume(i : TToken);

    { Same as consume, but will not attempt to read next token if the token is a point }

    procedure consume_last_dot;

    {Tries to consume the token i, and returns true if it was consumed:
     if token=i.}
    function try_to_consume(i:TToken):boolean;

    { consumes all tokens til atoken (for error recovering }
    procedure consume_all_until(atoken : TToken);

    { consumes tokens while they are semicolons }
    procedure consume_emptystats;

    { reads a list of identifiers into a string list }
    { consume a symbol, if not found give an error and
      and return an errorsym }
    function consume_sym(var srsym:TSym;var srsymtable:TSymTable):boolean;
    function consume_sym_orgid(var srsym:TSym;var srsymtable:TSymTable;var s : string):boolean;

    type
      TConsumeUnitSymFlag = (
        cuf_consume_id,
        cuf_allow_specialize,
        cuf_check_attr_suffix,
        cuf_allow_unit_only  { allow unit name without point, e.g. NameOf(unitname) }
      );
      TConsumeUnitSymFlags = set of TConsumeUnitSymFlag;

    function try_consume_unitsym(var srsym:TSym;var srsymtable:TSymTable;var tokentoconsume:TToken;flags:TConsumeUnitSymFlags;out is_specialize:boolean;sympattern:TSymStr):boolean;
    function try_consume_unitsym_no_specialize(var srsym:TSym;var srsymtable:TSymTable;var tokentoconsume:TToken;flags:TConsumeUnitSymFlags;sympattern:TSymStr):boolean;

    function try_consume_hintdirective(var symopt:TSymOptions; var deprecatedmsg:PShortString):boolean;

    { just for an accurate position of the end of a procedure (PM) }
    var
       last_endtoken_filepos: TFilePosInfo;


implementation

    uses
       Globals,Scanner,Verbose,FModule;

{****************************************************************************
                               Token Parsing
****************************************************************************}

     procedure identifier_not_found(const s:string);
       begin
         Message1(sym_e_id_not_found,s);
         { show a fatal that you need -S2 or -Sd, but only
           if we just parsed the a token that has m_class }
         if not(m_class in CurrentSettings.ModeSwitches) and
            (Upper(s)=CurrentScanner.pattern) and
            (m_class in tokeninfo^[CurrentScanner.idtoken].keyword) then
           Message(parser_f_need_objfpc_or_delphi_mode);
       end;


     procedure identifier_not_found(const s:string;const filepos:TFilePosInfo);
       begin
         MessagePos1(filepos,sym_e_id_not_found,s);
         { show a fatal that you need -S2 or -Sd, but only
           if we just parsed the a token that has m_class }
         if not(m_class in CurrentSettings.ModeSwitches) and
            (Upper(s)=CurrentScanner.pattern) and
            (m_class in tokeninfo^[CurrentScanner.idtoken].keyword) then
           MessagePos(filepos,parser_f_need_objfpc_or_delphi_mode);
       end;


    { consumes token i, write error if token is different }

    procedure consume(i : TToken);

    begin
        if (CurrentScanner.token<>i) and (CurrentScanner.idtoken<>i) then
          begin
            if CurrentScanner.had_multiline_string then
              Message2(scan_f_unterminated_multiline_string,
                       ToStr(CurrentScanner.multiline_start_line),
                       ToStr(CurrentScanner.multiline_start_column))
            else if CurrentScanner.token=_id then
              Message2(scan_f_syn_expected,tokeninfo^[i].str,'identifier '+CurrentScanner.pattern)
            else
              Message2(scan_f_syn_expected,tokeninfo^[i].str,tokeninfo^[CurrentScanner.token].str);
          end
        else
          begin
            if CurrentScanner.token=_END then
              last_endtoken_filepos:=CurrentTokenPos;
            CurrentScanner.readtoken(true);
          end;
      end;

    procedure consume_last_dot;

    begin
        if (CurrentScanner.token<>_POINT) then
          begin
          if CurrentScanner.token=_id then
            Message2(scan_f_syn_expected,tokeninfo^[_POINT].str,'identifier '+CurrentScanner.pattern)
          else
            Message2(scan_f_syn_expected,tokeninfo^[_POINT].str,tokeninfo^[CurrentScanner.token].str)
          end
        else if CurrentScanner.c<>#0 then
          CurrentScanner.readtoken(true);
    end;

    function try_to_consume(i:TToken):boolean;
      begin
        try_to_consume:=false;
        if (CurrentScanner.token=i) or (CurrentScanner.idtoken=i) then
         begin
           try_to_consume:=true;
           if CurrentScanner.token=_END then
            last_endtoken_filepos:=CurrentTokenPos;
           CurrentScanner.readtoken(true);
         end;
      end;


    procedure consume_all_until(atoken : TToken);
      begin
         while (CurrentScanner.token<>atoken) and (CurrentScanner.idtoken<>atoken) do
          begin
            Consume(CurrentScanner.token);
            if CurrentScanner.token=_EOF then
             begin
               Consume(atoken);
               if CurrentScanner.had_multiline_string then
                 Message2(scan_f_unterminated_multiline_string,
                          ToStr(CurrentScanner.multiline_start_line),
                          ToStr(CurrentScanner.multiline_start_column))
               else
                 Message(scan_f_end_of_file);
               exit;
             end;
          end;
      end;


    procedure consume_emptystats;
      begin
         repeat
         until not try_to_consume(_SEMICOLON);
      end;


    { check if a symbol contains the hint directive, and if so gives out a hint
      if required.

      If this code is changed, it's likly that consume_sym_orgid and factor_read_id
      must be changed as well (FK)
    }
    function consume_sym(var srsym:TSym;var srsymtable:TSymTable):boolean;
      var
        t : TToken;
      begin
        { first check for identifier }
        if CurrentScanner.token<>_ID then
          begin
            consume(_ID);
            srsym:=generrorsym;
            srsymtable:=nil;
            result:=false;
            exit;
          end;
        searchsym(CurrentScanner.pattern,srsym,srsymtable);
        { handle unit specification like System.Writeln }
        try_consume_unitsym_no_specialize(srsym,srsymtable,t,[cuf_consume_id],CurrentScanner.pattern);
        { if nothing found give error and return errorsym }
        if Assigned(srsym) then
          check_hints(srsym,srsym.symoptions,srsym.deprecatedmsg)
        else
          begin
            identifier_not_found(CurrentScanner.orgpattern);
            srsym:=generrorsym;
            srsymtable:=nil;
          end;
        consume(t);
        result:=Assigned(srsym);
      end;


    { check if a symbol contains the hint directive, and if so gives out a hint
      if required and returns the id with it's original casing
    }
    function consume_sym_orgid(var srsym:TSym;var srsymtable:TSymTable;var s : string):boolean;
      var
        t : TToken;
      begin
        { first check for identifier }
        if CurrentScanner.token<>_ID then
          begin
            consume(_ID);
            srsym:=generrorsym;
            srsymtable:=nil;
            result:=false;
            exit;
          end;
        searchsym(CurrentScanner.pattern,srsym,srsymtable);
        { handle unit specification like System.Writeln }
        try_consume_unitsym_no_specialize(srsym,srsymtable,t,[cuf_consume_id],CurrentScanner.pattern);
        { if nothing found give error and return errorsym }
        if Assigned(srsym) then
          check_hints(srsym,srsym.symoptions,srsym.deprecatedmsg)
        else
          begin
            identifier_not_found(CurrentScanner.orgpattern);
            srsym:=generrorsym;
            srsymtable:=nil;
          end;
        s:=CurrentScanner.orgpattern;
        consume(t);
        result:=Assigned(srsym);
      end;


    function try_consume_unitsym(var srsym:TSym;var srsymtable:TSymTable;var tokentoconsume:TToken;flags:TConsumeUnitSymFlags;out is_specialize:boolean;sympattern:TSymStr):boolean;
      var
        hmodule: TModule;
        ns:AnsiString;
        nssym:TSym;
        nsitem : TCmdStrListItem;

        procedure consume_namespace;
          begin
            while Assigned(srsym) and (srsym.typ=namespacesym) do
              begin
                { we have a namespace. the next identifier should be either a namespace or a unit }
                searchsym_in_module(hmodule,ns+'.'+CurrentScanner.pattern,srsym,srsymtable);
                if Assigned(srsym) and (srsym.typ in [namespacesym,unitsym]) then
                  begin
                    ns:=ns+'.'+CurrentScanner.pattern;
                    nssym:=srsym;
                    consume(_ID);
                    consume(_POINT);
                  end;
              end;
            { check if there is a hidden unit with this current_scanner.pattern in the namespace }
            if not Assigned(srsym) and
               Assigned(nssym) and (nssym.typ=namespacesym) and Assigned(TNamespaceSym(nssym).unitsym) then
              srsym:=TNamespaceSym(nssym).unitsym;
          end;

      begin
        result:=false;
        tokentoconsume:=_ID;
        is_specialize:=false;

        if not Assigned(srsym) and (CurrentScanner.pattern<>'') and (NamespaceList.count>0) then
          begin
            hmodule:=Get_Module(CurrentFilePos.moduleindex);
            if not Assigned(hmodule) then
              InternalError(2018050301);

            nsitem:=TCmdStrListItem(NamespaceList.first);
            while Assigned(nsitem) do
              begin
                ns:=upper(nsitem.str)+'.'+sympattern;

                if searchsym_in_module(hmodule,ns,srsym,srsymtable) and
                    (srsym.typ in [unitsym,namespacesym]) then
                  break;

                nsitem:=TCmdStrListItem(nsitem.next);
              end;
          end;

        if Assigned(srsym) and (srsym.typ in [unitsym,namespacesym]) then
          begin
            if not(srsym.owner.symtabletype in [staticsymtable,GlobalSymTable]) then
              InternalError(2005011503);
            { only allow unit.symbol access if the name was
              found in the current module
              we can use iscurrentunit because generic specializations does not
              change current_unit variable }
            hmodule:=find_module_from_symtable(srsym.Owner);
            if not Assigned(hmodule) then
              InternalError(2010011201);
            if hmodule.ModuleID=CurrentFilePos.moduleindex then
              begin
                if cuf_consume_id in flags then
                  begin
                    consume(_ID);
                    if (cuf_allow_unit_only in flags) and
                       (CurrentScanner.token<>_POINT) then
                      begin
                        tokentoconsume:=NOTOKEN;
                        exit(true);
                      end;
                  end;
                consume(_POINT);
                if srsym.typ=namespacesym then
                  begin
                    ns:=srsym.name;
                    nssym:=srsym;
                    consume_namespace;
                    if not Assigned(srsym) and (NamespaceList.count>0) then
                      begin
                        nsitem:=TCmdStrListItem(NamespaceList.first);
                        while Assigned(nsitem) do
                          begin
                            ns:=upper(nsitem.str)+'.'+nssym.name;

                            if searchsym_in_module(hmodule,ns,srsym,srsymtable) and
                                (srsym.typ in [unitsym,namespacesym]) then
                              begin
                                consume_namespace;
                                break;
                              end;

                            nsitem:=TCmdStrListItem(nsitem.next);
                          end;
                      end;
                    if Assigned(srsym) and (srsym.typ<>unitsym) then
                      InternalError(2011082601);
                    if not Assigned(srsym) then
                      begin
                        result:=true;
                        srsymtable:=nil;
                        exit;
                      end;
                  end;
                case CurrentScanner.token of
                  _ID:
                    begin
                      if cuf_check_attr_suffix in flags then
                        begin
                          if searchsym_in_module(TUnitSym(srsym).module,CurrentScanner.pattern+CustomAttributeSuffix,srsym,srsymtable) then
                            exit(true);
                        end;
                      { Resolve the default Char/PChar from the invocation's
                        text model, regardless of the System alias. }
                      if ((CurrentScanner.pattern='CHAR') or
                          (CurrentScanner.pattern='PCHAR')) and
                         (TModule(TUnitSym(srsym).module).GlobalSymTable=systemunit) then
                        begin
                          if CurrentScanner.pattern='PCHAR' then
                            if m_default_unicodestring in CurrentSettings.ModeSwitches then
                              searchsym_in_module(TUnitSym(srsym).module,'PWIDECHAR',srsym,srsymtable)
                            else
                              searchsym_in_module(TUnitSym(srsym).module,'PANSICHAR',srsym,srsymtable)
                          else if m_default_unicodestring in CurrentSettings.ModeSwitches then
                            searchsym_in_module(TUnitSym(srsym).module,'WIDECHAR',srsym,srsymtable)
                          else
                            searchsym_in_module(TUnitSym(srsym).module,'ANSICHAR',srsym,srsymtable)
                        end
                      else
                        if (cuf_allow_specialize in flags) and (CurrentScanner.idtoken=_SPECIALIZE) then
                          begin
                            consume(_ID);
                            is_specialize:=true;
                            if CurrentScanner.token=_ID then
                              begin
                                if (cuf_check_attr_suffix in flags) and
                                    searchsym_in_module(TUnitSym(srsym).module,CurrentScanner.pattern+CustomAttributeSuffix,srsym,srsymtable) then
                                  exit(true);
                                searchsym_in_module(TUnitSym(srsym).module,CurrentScanner.pattern,srsym,srsymtable);
                              end;
                          end
                        else
                          searchsym_in_module(TUnitSym(srsym).module,CurrentScanner.pattern,srsym,srsymtable);
                     end;
                  _STRING:
                    begin
                      if cs_compilesystem in CurrentSettings.ModuleSwitches then
                        Message(parser_e_nostringaliasinsystem);
                      { system.string? }
                      if TModule(TUnitSym(srsym).module).GlobalSymTable=systemunit then
                        begin
                          if cs_refcountedstrings in CurrentSettings.LocalSwitches then
                            begin
                              if m_default_unicodestring in CurrentSettings.ModeSwitches then
                                searchsym_in_module(TUnitSym(srsym).module,'UNICODESTRING',srsym,srsymtable)
                              else
                                searchsym_in_module(TUnitSym(srsym).module,'ANSISTRING',srsym,srsymtable)
                            end
                          else
                            searchsym_in_module(TUnitSym(srsym).module,'SHORTSTRING',srsym,srsymtable);
                          tokentoconsume:=_STRING;
                        end;
                    end
                  else
                    ;
                  end;
              end
            else
              begin
                srsym:=nil;
                srsymtable:=nil;
              end;
            result:=true;
          end;
      end;


    function try_consume_unitsym_no_specialize(var srsym:TSym;var srsymtable:TSymTable;var tokentoconsume:TToken;flags:TConsumeUnitSymFlags;sympattern:TSymStr):boolean;
      var
        dummy: Boolean;
      begin
        exclude(flags,cuf_allow_specialize);
        result:=try_consume_unitsym(srsym,srsymtable,tokentoconsume,flags,dummy,sympattern);
      end;

    function try_consume_hintdirective(var symopt:TSymOptions; var deprecatedmsg:PShortString):boolean;
      var
        last_is_deprecated:boolean;
      begin
        try_consume_hintdirective:=false;
        if not(m_hintdirective in CurrentSettings.ModeSwitches) then
          exit;
        repeat
          last_is_deprecated:=false;
          case CurrentScanner.idtoken of
            _LIBRARY:
              begin
                if sp_hint_library in symopt then
                  Message1(parser_e_dir_not_allowed,arraytokeninfo[CurrentScanner.idtoken].str)
                else
                  include(symopt,sp_hint_library);
                try_consume_hintdirective:=true;
              end;
            _DEPRECATED:
              begin
                if sp_hint_deprecated in symopt then
                  Message1(parser_e_dir_not_allowed,arraytokeninfo[CurrentScanner.idtoken].str)
                else
                  include(symopt,sp_hint_deprecated);
                try_consume_hintdirective:=true;
                last_is_deprecated:=true;
              end;
            _EXPERIMENTAL:
              begin
                if sp_hint_experimental in symopt then
                  Message1(parser_e_dir_not_allowed,arraytokeninfo[CurrentScanner.idtoken].str)
                else
                  include(symopt,sp_hint_experimental);
                try_consume_hintdirective:=true;
              end;
            _PLATFORM:
              begin
                if sp_hint_platform in symopt then
                  Message1(parser_e_dir_not_allowed,arraytokeninfo[CurrentScanner.idtoken].str)
                else
                  include(symopt,sp_hint_platform);
                try_consume_hintdirective:=true;
              end;
            _UNIMPLEMENTED:
              begin
                if sp_hint_unimplemented in symopt then
                  Message1(parser_e_dir_not_allowed,arraytokeninfo[CurrentScanner.idtoken].str)
                else
                  include(symopt,sp_hint_unimplemented);
                try_consume_hintdirective:=true;
              end;
            else
              break;
          end;
          consume(CurrentScanner.token);
          { handle deprecated message }
          if ((CurrentScanner.token=_CSTRING) or (CurrentScanner.token=_CCHAR)) and last_is_deprecated then
            begin
              if not Assigned(deprecatedmsg) then
                begin
                  if CurrentScanner.token=_CSTRING then
                    deprecatedmsg:=StringDup(CurrentScanner.cstringpattern)
                  else
                    deprecatedmsg:=StringDup(CurrentScanner.pattern);
                end;
              consume(CurrentScanner.token);
              include(symopt,sp_has_deprecated_msg);
            end;
        until false;
      end;

end.
