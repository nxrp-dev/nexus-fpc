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
    procedure ReadExports;

implementation

    uses
       { common }
       CUtils,
       { global }
       Globals,GlobType,tokens,Verbose,ConstExp,
       Systems,
       PPU,FModule,
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


    procedure ReadExports;
      var
        lOriginalName,
        lDefString,
        lInternalProcName : String;
        lProcDef         : TProcDef;
        lNode         : TNode;
        lSearchSym      : TSym;
        lSearchSymTable : TSymTable;
        lExportName     : ShortString;
        lIndex      : LongInt;
        lOptions    : TExportOptions;

        function IsGreater(AFirstItem,ASecondItem:TExportedItem):Boolean;
        var
          lSecondHasIndex : Boolean;
        begin
          lSecondHasIndex:=eo_index in ASecondItem.options;
          if eo_index in AFirstItem.options then
           begin
             if lSecondHasIndex then
               IsGreater:=AFirstItem.Index>ASecondItem.Index
             else
               IsGreater:=false;
           end
          else
            IsGreater:=lSecondHasIndex;
        end;

      begin
         include(CurrentModule.ModuleFlags,mf_has_exports);
         lDefString:='';
         lInternalProcName:='';
         Consume(_EXPORTS);
         repeat
           lExportName:='';
           lOptions:=[];
           lIndex:=0;
           if CurrentScanner.FToken=_ID then
             begin
                ConsumeSymOrgID(lSearchSym,lSearchSymTable,lOriginalName);
                { current_scanner.orgpattern is still valid here }
                lInternalProcName:='';
                case lSearchSym.typ of
                  staticvarsym :
                    lInternalProcName:=TStaticVarSym(lSearchSym).MangledName;
                  ProcSym :
                    begin
                      lProcDef:=TProcDef(TProcSym(lSearchSym).ProcdefList[0]);
                      if (TProcSym(lSearchSym).ProcdefList.Count>1) or
                         (po_kylixlocal in lProcDef.ProcOptions) or
                         ((tf_need_export in TargetInfo.flags) and
                          not(po_exports in lProcDef.ProcOptions)) then
                        Message(parser_e_illegal_symbol_exported)
                      else
                        lInternalProcName:=lProcDef.MangledName;
                    end;
                  TypeSym :
                    begin
                      if not Is_ObjCClass(TTypeSym(lSearchSym).TypeDef) then
                        Message(parser_e_illegal_symbol_exported)
                    end;
                  else
                    Message(parser_e_illegal_symbol_exported)
                end;
                if (lSearchSym.typ<>TypeSym) then
                  begin
                    if lInternalProcName<>'' then
                     begin
                       { This is wrong if the first is not
                         an underline }
                       if lInternalProcName[1]='_' then
                         delete(lInternalProcName,1,1)
                       else if (TargetInfo.system=system_i386_win32) and UseDefFileForExports then
                         begin
                           Message(parser_e_dlltool_unit_var_problem);
                           Message(parser_e_dlltool_unit_var_problem2);
                         end;
                       if length(lInternalProcName)<2 then
                        Message(parser_e_procname_to_short_for_export);
                       lDefString:=lSearchSym.realname+'='+lInternalProcName;
                     end;
                    if TryToConsume(_INDEX) then
                     begin
                       lNode:=CompExpr([efAcceptEqual]);
                       if lNode.nodetype=ordconstn then
                        if (TOrdConstNode(lNode).Value<Int64(low(lIndex))) or
                           (TOrdConstNode(lNode).Value>Int64(high(lIndex))) then
                          begin
                            lIndex:=0;
                            message3(type_e_range_check_error_bounds,ToStr(TOrdConstNode(lNode).Value),ToStr(low(lIndex)),ToStr(high(lIndex)))
                          end
                        else
                          lIndex:=TOrdConstNode(lNode).Value.svalue
                       else
                        begin
                          lIndex:=0;
                          message(type_e_ordinal_expr_expected);
                        end;
                       include(lOptions,eo_index);
                       lNode.free;
                       lNode := nil;
                       if TargetInfo.system=system_i386_win32 then
                        lDefString:=lSearchSym.realname+'='+lInternalProcName+' @ '+ToStr(lIndex)
                       else
                        lDefString:=lSearchSym.realname+'='+lInternalProcName; {Index ignored!}
                     end;
                    if TryToConsume(_NAME) then
                     begin
                       lNode:=CompExpr([efAcceptEqual]);
                       if lNode.nodetype=stringconstn then
                         lExportName:=StrPas(PChar(@TStringConstNode(lNode).ValueAS[0]))
                       else if Is_ConstCharNode(lNode) then
                         lExportName:=chr(TOrdConstNode(lNode).Value.svalue and $ff)
                       else
                         message(type_e_string_expr_expected);
                       include(lOptions,eo_name);
                       lNode.free;
                       lNode := nil;
                       lDefString:=lExportName+'='+lInternalProcName;
                     end;
                    if TryToConsume(_RESIDENT) then
                     begin
                       include(lOptions,eo_resident);
                       lDefString:=lSearchSym.realname+'='+lInternalProcName;{Resident ignored!}
                     end;
                    if TryToConsume(_PROMISING) then
                     begin
                       Message(parser_e_promising_exports_not_supported_on_current_platform);
                       if not TryToConsume(_FIRST) then
                         TryToConsume(_LAST);
                     end;
                    if (lDefString<>'') and
                        (
                          UseDefFileForExports or
                          (cs_link_deffile in CurrentSettings.GlobalSwitches)
                        ) then
                     DefFile.AddExport(lDefString);
                  end;
                // consumed the symbol. Only do something if there was no error.
                if ErrorCount=0 then
                  case lSearchSym.typ of
                    ProcSym:
                      begin
                       { if no specific name or index was given, then if }
                       { the procedure has aliases defined export those, }
                       { otherwise export the name as it appears in the  }
                       { export section (it doesn't make sense to export }
                       { the generic mangled name, because the name of   }
                       { the parent unit is used in that)                }
                       if (lOptions*[eo_name,eo_index]=[]) and
                          (TProcDef(TProcSym(lSearchSym).procdeflist[0]).AliasNames.count>1) then
                         exportallprocsymnames(TProcSym(lSearchSym),lOptions)
                       else
                         begin
                           { there's a name or an index -> export only one name   }
                           { correct? Or can you export multiple names with the   }
                           { same index? And/or should we also export the aliases }
                           { if a name is specified? (JM)                         }

                           if not (eo_name in lOptions) then
                             { Export names are not mangled on Windows }
                             if (TargetInfo.system in systems_all_windows) then
                               lExportName:=lOriginalName
                             { Use set mangled name in case of cdecl/cppdecl/mwpascal }
                             { and no name specified                                  }
                             else if (TProcDef(TProcSym(lSearchSym).procdeflist[0]).ProcCallOption in [pocall_cdecl,pocall_mwpascal]) then
                               lExportName:=TargetInfo.cprefix+TProcSym(lSearchSym).realname
                             else if (TProcDef(TProcSym(lSearchSym).procdeflist[0]).ProcCallOption in [pocall_cppdecl]) then
                               lExportName:=TargetInfo.cprefix+TProcDef(TProcSym(lSearchSym).procdeflist[0]).CPlusPlusMangledName
                             else
                               lExportName:=lOriginalName;

                           exportprocsym(lSearchSym,lExportName,lIndex,lOptions);
                         end
                      end;
                    staticvarsym:
                      begin
                        if not (eo_name in lOptions) then
                          { for "cvar" }
                          if (vo_has_mangledname in TStaticVarSym(lSearchSym).VarOptions) then
                            lExportName:=lSearchSym.MangledName
                          else
                            lExportName:=lOriginalName;
                        exportvarsym(lSearchSym,lExportName,lIndex,lOptions);
                      end;
                    TypeSym:
                      begin
                        case TTypeSym(lSearchSym).TypeDef.typ of
                          objectdef:
                            case TObjectDef(TTypeSym(lSearchSym).TypeDef).ObjectType of
                              odt_objcclass:
                                ExportObjCClass(TObjectDef(TTypeSym(lSearchSym).TypeDef));
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
             Consume(_ID);
         until not TryToConsume(_COMMA);
         Consume(_SEMICOLON);
        if not DefFile.empty then
         DefFile.writefile;
      end;

end.
