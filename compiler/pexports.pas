{
    Copyright (c) 1998-2005 by Florian Klaempfl

    This unit handles the exports parsing

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
unit pexports;

{$i fpcdefs.inc}

interface

    { reads an exports statement in a library }
    procedure read_exports;

implementation

    uses
       { common }
       CUtils,
       { global }
       Globals,GlobType,tokens,Verbose,ConstExp,
       Systems,
       ppu,FModule,
       { symtable }
       symconst,SymBase,symdef,symtype,SymSym,
       { pass 1 }
       node,
       ncon,
       { parser }
       Scanner,
       pbase,pexpr,
       { obj-c }
       objcutil,
       { link }
       gendef,export
       ;


    procedure read_exports;
      var
        orgs,
        DefString,
        InternalProcName : string;
        pd         : TProcDef;
        pt         : TNode;
        srsym      : TSym;
        srsymtable : TSymTable;
        hpname     : shortstring;
        index      : LongInt;
        options    : TExportOptions;

        function IsGreater(hp1,hp2:TExportedItem):boolean;
        var
          i2 : boolean;
        begin
          i2:=eo_index in hp2.options;
          if eo_index in hp1.options then
           begin
             if i2 then
               IsGreater:=hp1.index>hp2.index
             else
               IsGreater:=false;
           end
          else
            IsGreater:=i2;
        end;

      begin
         include(CurrentModule.moduleflags,mf_has_exports);
         DefString:='';
         InternalProcName:='';
         consume(_EXPORTS);
         repeat
           hpname:='';
           options:=[];
           index:=0;
           if CurrentScanner.token=_ID then
             begin
                consume_sym_orgid(srsym,srsymtable,orgs);
                { current_scanner.orgpattern is still valid here }
                InternalProcName:='';
                case srsym.typ of
                  staticvarsym :
                    InternalProcName:=TStaticVarSym(srsym).mangledname;
                  procsym :
                    begin
                      pd:=TProcDef(TProcSym(srsym).ProcdefList[0]);
                      if (TProcSym(srsym).ProcdefList.Count>1) or
                         (po_kylixlocal in pd.procoptions) or
                         ((tf_need_export in TargetInfo.flags) and
                          not(po_exports in pd.procoptions)) then
                        Message(parser_e_illegal_symbol_exported)
                      else
                        InternalProcName:=pd.mangledname;
                    end;
                  typesym :
                    begin
                      if not is_objcclass(TTypeSym(srsym).typedef) then
                        Message(parser_e_illegal_symbol_exported)
                    end;
                  else
                    Message(parser_e_illegal_symbol_exported)
                end;
                if (srsym.typ<>typesym) then
                  begin
                    if InternalProcName<>'' then
                     begin
                       { This is wrong if the first is not
                         an underline }
                       if InternalProcName[1]='_' then
                         delete(InternalProcName,1,1)
                       else if (TargetInfo.system=system_i386_win32) and UseDefFileForExports then
                         begin
                           Message(parser_e_dlltool_unit_var_problem);
                           Message(parser_e_dlltool_unit_var_problem2);
                         end;
                       if length(InternalProcName)<2 then
                        Message(parser_e_procname_to_short_for_export);
                       DefString:=srsym.realname+'='+InternalProcName;
                     end;
                    if try_to_consume(_INDEX) then
                     begin
                       pt:=comp_expr([ef_accept_equal]);
                       if pt.nodetype=ordconstn then
                        if (TOrdConstNode(pt).value<int64(low(index))) or
                           (TOrdConstNode(pt).value>int64(high(index))) then
                          begin
                            index:=0;
                            message3(type_e_range_check_error_bounds,ToStr(TOrdConstNode(pt).value),ToStr(low(index)),ToStr(high(index)))
                          end
                        else
                          index:=TOrdConstNode(pt).value.svalue
                       else
                        begin
                          index:=0;
                          message(type_e_ordinal_expr_expected);
                        end;
                       include(options,eo_index);
                       pt.free;
                       pt := nil;
                       if TargetInfo.system=system_i386_win32 then
                        DefString:=srsym.realname+'='+InternalProcName+' @ '+ToStr(index)
                       else
                        DefString:=srsym.realname+'='+InternalProcName; {Index ignored!}
                     end;
                    if try_to_consume(_NAME) then
                     begin
                       pt:=comp_expr([ef_accept_equal]);
                       if pt.nodetype=stringconstn then
                         hpname:=StrPas(pchar(@TStringConstNode(pt).valueas[0]))
                       else if is_constcharnode(pt) then
                         hpname:=chr(TOrdConstNode(pt).value.svalue and $ff)
                       else
                         message(type_e_string_expr_expected);
                       include(options,eo_name);
                       pt.free;
                       pt := nil;
                       DefString:=hpname+'='+InternalProcName;
                     end;
                    if try_to_consume(_RESIDENT) then
                     begin
                       include(options,eo_resident);
                       DefString:=srsym.realname+'='+InternalProcName;{Resident ignored!}
                     end;
                    if try_to_consume(_PROMISING) then
                     begin
                       Message(parser_e_promising_exports_not_supported_on_current_platform);
                       if not try_to_consume(_FIRST) then
                         try_to_consume(_LAST);
                     end;
                    if (DefString<>'') and
                        (
                          UseDefFileForExports or
                          (cs_link_deffile in CurrentSettings.GlobalSwitches)
                        ) then
                     DefFile.AddExport(DefString);
                  end;
                // consumed the symbol. Only do something if there was no error.
                if ErrorCount=0 then
                  case srsym.typ of
                    procsym:
                      begin
                       { if no specific name or index was given, then if }
                       { the procedure has aliases defined export those, }
                       { otherwise export the name as it appears in the  }
                       { export section (it doesn't make sense to export }
                       { the generic mangled name, because the name of   }
                       { the parent unit is used in that)                }
                       if (options*[eo_name,eo_index]=[]) and
                          (TProcDef(TProcSym(srsym).procdeflist[0]).aliasnames.count>1) then
                         exportallprocsymnames(TProcSym(srsym),options)
                       else
                         begin
                           { there's a name or an index -> export only one name   }
                           { correct? Or can you export multiple names with the   }
                           { same index? And/or should we also export the aliases }
                           { if a name is specified? (JM)                         }

                           if not (eo_name in options) then
                             { Export names are not mangled on Windows }
                             if (TargetInfo.system in systems_all_windows) then
                               hpname:=orgs
                             { Use set mangled name in case of cdecl/cppdecl/mwpascal }
                             { and no name specified                                  }
                             else if (TProcDef(TProcSym(srsym).procdeflist[0]).proccalloption in [pocall_cdecl,pocall_mwpascal]) then
                               hpname:=TargetInfo.cprefix+TProcSym(srsym).realname
                             else if (TProcDef(TProcSym(srsym).procdeflist[0]).proccalloption in [pocall_cppdecl]) then
                               hpname:=TargetInfo.cprefix+TProcDef(TProcSym(srsym).procdeflist[0]).cplusplusmangledname
                             else
                               hpname:=orgs;

                           exportprocsym(srsym,hpname,index,options);
                         end
                      end;
                    staticvarsym:
                      begin
                        if not (eo_name in options) then
                          { for "cvar" }
                          if (vo_has_mangledname in TStaticVarSym(srsym).varoptions) then
                            hpname:=srsym.mangledname
                          else
                            hpname:=orgs;
                        exportvarsym(srsym,hpname,index,options);
                      end;
                    typesym:
                      begin
                        case TTypeSym(srsym).typedef.typ of
                          objectdef:
                            case TObjectDef(TTypeSym(srsym).typedef).objecttype of
                              odt_objcclass:
                                exportobjcclass(TObjectDef(TTypeSym(srsym).typedef));
                              else
                                InternalError(2009092601);
                            end;
                          else
                            InternalError(2009092602);
                        end;
                      end;
                   else
                     InternalError(2019050502);
                   end; // Case srsym.typ
             end
           else
             consume(_ID);
         until not try_to_consume(_COMMA);
         consume(_SEMICOLON);
        if not DefFile.empty then
         DefFile.writefile;
      end;

end.
