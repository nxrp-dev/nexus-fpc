{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Compare definitions and parameter lists

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
unit defcmp;

{$i fpcdefs.inc}

interface

    uses
       CClasses,
       GlobType,Globals,
       Node,
       SymConst,SymType,SymDef,SymBase;

     type
       { if acp is cp_all the var const or nothing are considered equal }
       TCompareParasType = ( cp_none, cp_value_equal_const, cp_all,cp_procvar);
       TCompareParasOption = (
          cpo_allowdefaults,
          cpo_ignorehidden,           // ignore hidden parameters
          cpo_allowconvert,
          cpo_comparedefaultvalue,
          cpo_openequalisexact,
          cpo_ignoreuniv,
          cpo_warn_incompatible_univ,
          cpo_ignorevarspez,          // ignore parameter access type
          cpo_ignoreframepointer,     // ignore frame pointer parameter (for assignment-compatibility of global procedures to nested procvars)
          cpo_compilerproc,
          cpo_rtlproc,
          cpo_generic,                // two different undefined defs (or a constraint in the forward) alone or in open arrays are
                                      // treated as exactly equal (also in open arrays) if they are owned by their respective procdefs
          cpo_ignoreself              // ignore Self parameter, but leave other hidden parameters
       );

       TCompareParasOptions = set of TCompareParasOption;

       TCompareDefsOption = (
          cdo_internal,
          cdo_explicit,
          cdo_check_operator,
          cdo_allow_variant,
          cdo_parameter,
          cdo_warn_incompatible_univ,
          cdo_strict_undefined_check,    // undefined defs are incompatible to everything except other undefined defs
          cdo_equal_check,               // this call is only to check equality -> shortcut some expensive checks
          cdo_strict_genconstraint_check // check that generic constraints match (used for forward declarations)
       );
       TCompareDefsOptions = set of TCompareDefsOption;

       TConvertType = (tc_none,
          tc_equal,
          tc_not_possible,
          tc_string_2_string,
          tc_char_2_string,
          tc_char_2_chararray,
          tc_pchar_2_string,
          tc_cchar_2_pchar,
          tc_cstring_2_pchar,
          tc_cstring_2_int,
          tc_ansistring_2_pchar,
          tc_string_2_chararray,
          tc_chararray_2_string,
          tc_array_2_pointer,
          tc_pointer_2_array,
          tc_int_2_int,
          tc_int_2_bool,
          tc_bool_2_bool,
          tc_bool_2_int,
          tc_real_2_real,
          tc_int_2_real,
          tc_real_2_currency,
          tc_proc_2_procvar,
          tc_nil_2_methodprocvar,
          tc_arrayconstructor_2_set,
          tc_set_to_set,
          tc_cord_2_pointer,
          tc_intf_2_string,
          tc_intf_2_guid,
          tc_class_2_intf,
          tc_char_2_char,
          tc_dynarray_2_openarray,
          tc_pwchar_2_string,
          tc_variant_2_dynarray,
          tc_dynarray_2_variant,
          tc_variant_2_enum,
          tc_enum_2_variant,
          tc_interface_2_variant,
          tc_variant_2_interface,
          tc_array_2_dynarray,
          tc_elem_2_openarray,
          tc_arrayconstructor_2_dynarray,
          tc_arrayconstructor_2_array,
          tc_anonproc_2_funcref,
          tc_procvar_2_funcref
       );

    function Compare_Defs_Ext(DefFrom,DefTo : TDef;
                              FromTreeType : TNodeType;
                              var DoConv : TConvertType;
                              var OperatorPD : TProcDef;
                              CDOptions:TCompareDefsOptions):TEqualType;

    { Returns if the type def_from can be converted to def_to or if both types are equal }
    function Compare_Defs(DefFrom,DefTo:TDef;FromTreeType:TNodeType):TEqualType;

    { Returns true, if def1 and def2 are semantically the same }
    function Equal_Defs(DefFrom,DefTo:TDef):Boolean;

    { Checks for type compatibility (subgroups of type)
      used for case statements... probably missing stuff
      to use on other types }
    function Is_Subequal(Def1, Def2: TDef): Boolean;

     {# true, if two parameter lists are equal
      if acp is cp_all, all have to match exactly
      if acp is cp_value_equal_const call by value
      and call by const parameter are assumed as
      equal
      if acp is cp_procvar then the varspez have to match,
      and all parameter types must be at least te_equal
      if acp is cp_none, then we don't check the varspez at all
      allowdefaults indicates if default value parameters
      are allowed (in this case, the search order will first
      search for a routine with default parameters, before
      searching for the same definition with no parameters)

      para1 is expected to be parameter list of the first encountered
      declaration (interface, forward), and para2 that of the second one
      (important in case of cpo_comparedefaultvalue)
    }
    function Compare_Paras(Para1,Para2 : TFPObjectList; ACP : TCompareParasType; CPOptions: TCompareParasOptions):TEqualType;

    { Compares the compatibility of two return types (in contrast to
      compare_defs the cdo_strict_undefined_check will be passed to
      compare_defs_ext as well) }
    function Compare_RetType(Def1,Def2:TDef):TEqualType;

    { True if a function can be assigned to a procvar }
    { changed first argument type to pabstractprocdef so that it can also be }
    { used to test compatibility between two pprocvardefs (JM)               }
    function Proc_To_ProcVar_Equal(Def1:TAbstractProcDef;Def2:TProcVarDef;CheckIncompatibleUniv: Boolean):TEqualType;

    { True if a function can be assigned to a function reference }
    function Proc_To_FuncRef_Equal(Def1:TAbstractProcDef;Def2:TObjectDef):TEqualType;

    { returns the equality between a function and a function reference }
    function Proc_To_FuncRef_Conv(Def1:TAbstractProcDef;Def2:TObjectDef):TEqualType;

    { Checks if an funcref interface can be assigned to the other }
    function FuncRef_Equal(Def1,Def2:TObjectDef):TEqualType;

    { Parentdef is the definition of a method defined in a parent class or interface }
    { Childdef is the definition of a method defined in a child class, interface or  }
    { a class implementing an interface with parentdef.                              }
    { Returns true if the resultdef of childdef can be used to implement/override    }
    { parentdef's resultdef                                                          }
    function Compatible_ChildMethod_ResultDef(ParentRetDef, ChildRetDef: TDef): Boolean;

    { Checks whether the class impldef or one of its parent classes implements }
    { the interface intfdef and returns the corresponding "implementation link }
    function Find_Implemented_Interface(ImplDef,IntfDef:TObjectDef):TImplementedInterface;

    { Checks whether to defs are related to each other. Thereby the following  }
    { cases of curdef are implemented:                                         }


    { - objectdef: if it inherits from otherdef or they are equal              }
    function Def_Is_Related(CurDef,OtherDef:TDef):Boolean;

    { Checks whether two defs for parameters or result types of a generic }
    { routine can be considered as equal. Requires the symtables of the   }
    { procdefs the parameters defs shall belong to.                       }
    function Equal_GenFunc_ParaDefs(FWDef,CurrDef:TDef;FWPDST,CurrPDST:TSymTable):Boolean;


implementation

    uses
      Verbose,Systems,ConstExp,
      SymTable,SymSym,SymCPU,
      DefUtil,SymUtil;


    function SameGenConstraintInterfaces(IntfFrom,IntfTo:TObject):Boolean;
      begin
        Result:=Equal_Defs(TDef(IntfFrom),TDef(IntfTo));
      end;


    function SameObjectDefImplementedInterfaces(IntfFrom,IntfTo:TObject):Boolean;
      begin
        Result:=Equal_Defs(TImplementedInterface(IntfFrom).IntfDef,TImplementedInterface(IntfTo).IntfDef);
      end;


    function Compare_Defs_Ext(DefFrom,DefTo : TDef;
                              FromTreeType : TNodeType;
                              var DoConv : TConvertType;
                              var OperatorPD : TProcDef;
                              CDOptions:TCompareDefsOptions):TEqualType;

      { tordtype:
           uvoid,
           u8bit,u16bit,u32bit,u64bit,
           s8bit,s16bit,s32bit,s64bit,
           pasbool, bool8bit,bool16bit,bool32bit,bool64bit,
           uchar,uwidechar,scurrency,customint }

      type
        TBaseDef=(bvoid,bchar,bint,bbool);
      const
        BaseDefTbl:array[TOrdType] of TBaseDef =
          (BVoid,
           BInt,BInt,BInt,BInt,BInt,
           BInt,BInt,BInt,BInt,BInt,
           BBool,BBool,BBool,BBool,BBool,
           BBool,BBool,BBool,BBool,
           BChar,BChar,BInt,BInt);

        BaseDefConvertsImplicit : array[TBaseDef,TBaseDef] of TConvertType =
          { void, char, int, bool }
         ((tc_not_possible,tc_not_possible,tc_not_possible,tc_not_possible),
          (tc_not_possible,tc_char_2_char,tc_not_possible,tc_not_possible),
          (tc_not_possible,tc_not_possible,tc_int_2_int,tc_not_possible),
          (tc_not_possible,tc_not_possible,tc_not_possible,tc_bool_2_bool));
        BaseDefConvertsExplicit : array[TBaseDef,TBaseDef] of TConvertType =
          { void, char, int, bool }
         ((tc_not_possible,tc_not_possible,tc_not_possible,tc_not_possible),
          (tc_not_possible,tc_char_2_char,tc_int_2_int,tc_int_2_bool),
          (tc_not_possible,tc_int_2_int,tc_int_2_int,tc_int_2_bool),
          (tc_not_possible,tc_bool_2_int,tc_bool_2_int,tc_bool_2_bool));

      type
        TSameInterfaceFunc = function(intffrom,intfto:TObject):Boolean;

      function SameInterfaceLists(ListFrom,ListTo:TFPObjectList;CheckFunc:TSameInterfaceFunc):Boolean;
        var
          I : LongInt;
        begin
          Result:=False;
          if Assigned(ListFrom) xor Assigned(ListTo) then
            Exit;
          if not Assigned(ListFrom) and not Assigned(ListTo) then
            Exit(True);
          if ListFrom.Count<>ListTo.Count then
            Exit;
          for I:=0 to ListFrom.Count-1 do
            if not CheckFunc(TDef(ListFrom[I]),TDef(ListTo[I])) then
              Exit;
          Result:=True;
        end;


      var
         SubEq,EQ : TEqualType;
         HD1,HD2 : TDef;
         DefGeneric : TStoredDef;
         HCT : TConvertType;
         HObjDef : TObjectDef;
         HPD : TProcDef;
         I : LongInt;
         Diff : Boolean;
         SymFrom,SymTo : TSym;
         GenConstrFrom,GenConstrTo : TGenericConstraintData;
      begin
         EQ:=te_incompatible;
         DoConv:=tc_not_possible;

         { safety check }
         if not(Assigned(DefFrom) and Assigned(DefTo)) then
          begin
            Compare_Defs_Ext:=te_incompatible;
            Exit;
          end;

         { resolve anonymous external definitions }
         if DefFrom.Typ=ObjectDef then
           DefFrom:=Find_Real_Class_Definition(TObjectDef(DefFrom),False);
         if DefTo.Typ=ObjectDef then
           DefTo:=Find_Real_Class_Definition(TObjectDef(DefTo),False);

         { same def? then we've an exact match }
         if DefFrom=DefTo then
          begin
            DoConv:=tc_equal;
            Compare_Defs_Ext:=te_exact;
            Exit;
          end;

         if cdo_strict_undefined_check in CDOptions then
           begin
             { two different undefined defs are not considered equal }
             if (DefFrom.Typ=UndefinedDef) and
                (DefTo.Typ=UndefinedDef) then
              begin
                DoConv:=tc_not_possible;
                Compare_Defs_Ext:=te_incompatible;
                Exit;
              end;

             { if only one def is a undefined def then they are not considered as
               equal}
             if (
                   (DefFrom.Typ=UndefinedDef) or
                   Assigned(TStoredDef(DefFrom).GenConstraintData)
                 ) or (
                   (DefTo.Typ=UndefinedDef) or
                   Assigned(TStoredDef(DefTo).GenConstraintData)
                 ) then
              begin
                DoConv:=tc_not_possible;
                Compare_Defs_Ext:=te_incompatible;
                Exit;
              end;
           end
         else
           begin
             { undefined defs are considered equal to everything }
             if (DefFrom.Typ=UndefinedDef) or
                 (DefTo.Typ=UndefinedDef) then
               begin
                 { for strict checks with genconstraints pure undefineddefs are
                   not compatible with constrained defs }
                 if (cdo_strict_genconstraint_check in CDOptions) and
                     (
                       Assigned(TStoredDef(DefFrom).GenConstraintData) or
                       Assigned(TStoredDef(DefTo).GenConstraintData)
                     ) then
                   begin
                     DoConv:=tc_not_possible;
                     Compare_Defs_Ext:=te_incompatible;
                     Exit;
                   end;
                 DoConv:=tc_equal;
                 Compare_Defs_Ext:=te_exact;
                 Exit;
               end;

             { either type has constraints }
             if Assigned(TStoredDef(DefFrom).GenConstraintData) or
                 Assigned(TStoredDef(DefTo).GenConstraintData) then
               begin
                 { this is basically a poor man's type checking, if there is a chance
                   that the types are equal considering the constraints, this needs probably
                   to be improved and maybe factored out or even result in a recursive compare_defs_ext }
                 if (DefFrom.Typ<>DefTo.Typ) and
                   { formaldefs are compatible with everything }
                   not(DefFrom.Typ in [FormalDef]) and
                   not(DefTo.Typ in [FormalDef]) and
                   { constants could get another deftype (e.g. niln) }
                   not(FromTreeType in cNodeTypeConst) then
                   begin
                     { not compatible anyway }
                     DoConv:=tc_not_possible;
                     Compare_Defs_Ext:=te_incompatible;
                     Exit;
                   end;

                 { for a strict check of the generic constraints the constraints
                   of both parts need to match }
                 if cdo_strict_genconstraint_check in CDOptions then
                   begin
                     GenConstrFrom:=TStoredDef(DefFrom).GenConstraintData;
                     GenConstrTo:=TStoredDef(DefTo).GenConstraintData;
                     if (
                         { both parts need to be constraints }
                         not Assigned(GenConstrFrom) or
                         not Assigned(GenConstrTo)
                       ) or (
                         { same type of def required }
                         DefFrom.Typ<>DefTo.Typ
                       ) or (
                         { for objectdefs same object type as well as parent required }
                         (DefFrom.Typ=ObjectDef) and
                         (
                           (TObjectDef(DefFrom).ObjectType<>TObjectDef(DefTo).ObjectType) or
                           not Equal_Defs(TObjectDef(DefFrom).ChildOf,TObjectDef(DefTo).ChildOf)
                         )
                       ) or (
                         { the flags need to match }
                         GenConstrFrom.Flags<>GenConstrTo.Flags
                       ) or
                       { the interfaces of the constraints need to match }
                       not SameInterfaceLists(GenConstrFrom.Interfaces,GenConstrTo.Interfaces,@SameGenConstraintInterfaces) or
                       (
                         { for objectdefs the implemented interfaces need to match }
                         (DefFrom.Typ=ObjectDef) and not
                         SameInterfaceLists(TObjectDef(DefFrom).ImplementedInterfaces,TObjectDef(DefTo).ImplementedInterfaces,@SameObjectDefImplementedInterfaces)
                       ) then
                       begin
                         DoConv:=tc_not_possible;
                         Compare_Defs_Ext:=te_incompatible;
                         Exit;
                       end;
                   end;

                 { maybe we are in generic type declaration/implementation.
                   In this case constraint in comparison to not specialized generic
                   is not "exact" nor "incompatible" }
                 if not(((df_genconstraint in DefFrom.DefOptions) and
                        ([df_generic,df_specialization]*DefTo.DefOptions=[df_generic])
                      ) or
                      (
                        (df_genconstraint in DefTo.DefOptions) and
                        ([df_generic,df_specialization]*DefFrom.DefOptions=[df_generic]))
                    ) then
                   begin
                     { one is definitely a constraint, for the other we don't
                       care right now }
                     DoConv:=tc_equal;
                     Compare_Defs_Ext:=te_exact;
                     Exit;
                   end;
               end;
           end;

         { two specializations are considered equal if they specialize the same
           generic with the same types }
         if (df_specialization in DefFrom.DefOptions) and
             (df_specialization in DefTo.DefOptions) and
             (TStoredDef(DefFrom).GenericDef=TStoredDef(DefTo).GenericDef) then
           begin
             if Assigned(TStoredDef(DefFrom).GenericParas) xor
                 Assigned(TStoredDef(DefTo).GenericParas) then
               InternalError(2013030901);
             Diff:=False;
             if Assigned(TStoredDef(DefFrom).GenericParas) then
               begin
                 if TStoredDef(DefFrom).GenericParas.Count<>TStoredDef(DefTo).GenericParas.Count then
                   InternalError(2012091301);
                 for I:=0 to TStoredDef(DefFrom).GenericParas.Count-1 do
                   begin
                     if TStoredDef(DefFrom).GenericParas.NameOfIndex(I)<>TStoredDef(DefTo).GenericParas.NameOfIndex(I) then
                       InternalError(2012091302);
                     SymFrom:=TTypeSym(TStoredDef(DefFrom).GenericParas[I]);
                     SymTo:=TTypeSym(TStoredDef(DefTo).GenericParas[I]);
                     if not (SymFrom.Typ in [TypeSym,ConstSym]) or not (SymTo.Typ in [TypeSym,ConstSym]) then
                       InternalError(2012121401);
                     if SymTo.Typ<>SymFrom.Typ then
                       Diff:=True
                     else if (SymFrom.Typ=ConstSym) and (SymTo.Typ=ConstSym) and not Equal_ConstSym(TConstSym(SymFrom),TConstSym(SymTo),True) then
                       Diff:=True
                     else if not Equal_Defs(TTypeSym(SymFrom).TypeDef,TTypeSym(SymTo).TypeDef) then
                       Diff:=True;
                     if Diff then
                       Break;
                   end;
               end;
             if not Diff then
               begin
                 DoConv:=tc_equal;
                 { the definitions are not exactly the same, but only equal }
                 Compare_Defs_Ext:=te_equal;
                 Exit;
               end;
           end;
         { handling of partial specializations }
         if (
               (df_generic in DefTo.DefOptions) and
               (df_specialization in DefFrom.DefOptions) and
               (TStoredDef(DefFrom).GenericDef=DefTo) and
               Assigned(TStoredDef(DefTo).GenericParas)
             ) or (
               (df_generic in DefFrom.DefOptions) and
               (df_specialization in DefTo.DefOptions) and
               (TStoredDef(DefTo).GenericDef=DefFrom) and
               Assigned(TStoredDef(DefFrom).GenericParas)
             ) then
           begin
             if TStoredDef(DefFrom).GenericDef=DefTo then
               DefGeneric:=TStoredDef(DefTo)
             else
               DefGeneric:=TStoredDef(DefFrom);
             if not Assigned(DefGeneric.GenericParas) then
               InternalError(2014052306);
             Diff:=False;
             for I:=0 to DefGeneric.GenericParas.Count-1 do
               begin
                 SymFrom:=TSym(DefGeneric.GenericParas[I]);
                 if SymFrom.Typ<>TypeSym then
                   InternalError(2014052307);
                 if TTypeSym(SymFrom).TypeDef.Typ<>UndefinedDef then
                   Diff:=True;
                 if Diff then
                   Break;
               end;
             if not Diff then
               begin
                 DoConv:=tc_equal;
                 { the definitions are not exactly the same, but only equal }
                 Compare_Defs_Ext:=te_equal;
                 Exit;
               end;
           end;

         { we walk the wanted (def_to) types and check then the def_from
           types if there is a conversion possible }
         case DefTo.Typ of
           OrdDef :
             begin
               case DefFrom.Typ of
                 OrdDef :
                   begin
                     if (TOrdDef(DefFrom).OrdType=TOrdDef(DefTo).OrdType) then
                      begin
                        case TOrdDef(DefFrom).OrdType of
                          UChar,UWideChar,
                          U8Bit,U16Bit,U32Bit,U64Bit,
                          S8Bit,S16Bit,S32Bit,S64Bit:
                            begin
                              if (TOrdDef(DefFrom).Low>=TOrdDef(DefTo).Low) and
                                 (TOrdDef(DefFrom).High<=TOrdDef(DefTo).High) then
                                EQ:=te_equal
                              else
                                begin
                                  DoConv:=tc_int_2_int;
                                  EQ:=te_convert_l1;
                                end;
                            end;
                          UVoid,
                          PasBool1,PasBool8,PasBool16,PasBool32,PasBool64,
                          Bool8Bit,Bool16Bit,Bool32Bit,Bool64Bit,
                          SCurrency:
                            EQ:=te_equal;
                          else
                            InternalError(200210061);
                        end;
                      end
                     { currency cannot be implicitly converted to an ordinal
                       type }
                     else if not Is_Currency(DefFrom) or
                             (cdo_explicit in CDOptions) then
                      begin
                        if cdo_explicit in CDOptions then
                          DoConv:=BaseDefConvertsExplicit[BaseDefTbl[TOrdDef(DefFrom).OrdType],BaseDefTbl[TOrdDef(DefTo).OrdType]]
                        else
                          DoConv:=BaseDefConvertsImplicit[BaseDefTbl[TOrdDef(DefFrom).OrdType],BaseDefTbl[TOrdDef(DefTo).OrdType]];
                        if (DoConv=tc_not_possible) then
                          EQ:=te_incompatible
                        else if (not Is_In_Limit(DefFrom,DefTo)) then
                          { "punish" bad type conversions :) (JM) }
                          EQ:=te_convert_l3
                        else
                          EQ:=te_convert_l1;
                      end;
                   end;
                 EnumDef :
                   begin
                     { needed for char(enum) }
                     if cdo_explicit in CDOptions then
                      begin
                        DoConv:=tc_int_2_int;
                        EQ:=te_convert_l1;
                      end;
                   end;
                 FloatDef :
                   begin
                     if Is_Currency(DefTo) then
                      begin
                        DoConv:=tc_real_2_currency;
                        EQ:=te_convert_l2;
                      end;
                   end;
                 ObjectDef:
                   begin
                     if (m_delphi in CurrentSettings.ModeSwitches) and
                        Is_Implicit_Pointer_Object_Type(DefFrom) and
                        (cdo_explicit in CDOptions) then
                      begin
                        EQ:=te_convert_l1;
                        if (FromTreeType=NilN) then
                         begin
                           { will be handled by the constant folding }
                           DoConv:=tc_equal;
                         end
                        else
                         DoConv:=tc_int_2_int;
                      end;
                   end;
                 ClassRefDef,
                 ProcVarDef,
                 PointerDef :
                   begin
                     if cdo_explicit in CDOptions then
                      begin
                        EQ:=te_convert_l1;
                        if (FromTreeType=NilN) then
                         begin
                           { will be handled by the constant folding }
                           DoConv:=tc_equal;
                         end
                        else
                         DoConv:=tc_int_2_int;
                      end;
                   end;
                 ArrayDef :
                   begin
                     if (m_mac in CurrentSettings.ModeSwitches) and
                        Is_Integer(DefTo) and
                        (FromTreeType=StringConstN) then
                       begin
                         EQ:=te_convert_l3;
                         DoConv:=tc_cstring_2_int;
                       end;
                   end;
                 else
                   ;
               end;
             end;

           StringDef :
             begin
               case DefFrom.Typ of
                 StringDef :
                   begin
                     { Constant string }
                     if (FromTreeType=StringConstN) and
                        Is_ShortString(DefFrom) and
                        Is_ShortString(DefTo) then
                        EQ:=te_equal
                     else if (TStringDef(DefTo).StringType=st_ansistring) and
                             (TStringDef(DefFrom).StringType=st_ansistring) then
                      begin
                        { don't convert ansistrings if any condition is true:
                          1) same encoding
                          2) from explicit codepage ansistring to ansistring and vice versa
                          3) from any ansistring to rawbytestring
                          4) from rawbytestring to any ansistring }
                        if (TStringDef(DefFrom).Encoding=TStringDef(DefTo).Encoding) or
                           ((TStringDef(DefTo).Encoding=0) and (TStringDef(DefFrom).Encoding=GetAnsiStringCodePage)) or
                           ((TStringDef(DefTo).Encoding=GetAnsiStringCodePage) and (TStringDef(DefFrom).Encoding=0)) or
                           (TStringDef(DefTo).Encoding=Globals.CP_NONE) or
                           (TStringDef(DefFrom).Encoding=Globals.CP_NONE) then
                         begin
                           EQ:=te_equal;
                         end
                        else
                         begin
                           DoConv := tc_string_2_string;

                           { prefer conversion to utf8 codepage }
                           if TStringDef(DefTo).Encoding = Globals.CP_UTF8 then
                             EQ:=te_convert_l1
                           { else to AnsiString type }
                           else if DefTo=GetAnsiStringDef then
                             EQ:=te_convert_l2
                           { else to AnsiString with other codepage }
                           else
                             EQ:=te_convert_l3;
                         end
                      end
                     else
                     { same string type ? }
                      if (TStringDef(DefFrom).StringType=TStringDef(DefTo).StringType) and
                        { for shortstrings also the length must match }
                         ((TStringDef(DefFrom).StringType<>st_shortstring) or
                          (TStringDef(DefFrom).Len=TStringDef(DefTo).Len)) and
                         { for ansi- and unicodestrings also the encoding must match }
                         (not(TStringDef(DefFrom).StringType in [st_ansistring,st_unicodestring]) or
                          (TStringDef(DefFrom).Encoding=TStringDef(DefTo).Encoding)) then
                        EQ:=te_equal
                     else
                       begin
                         DoConv:=tc_string_2_string;
                         case TStringDef(DefFrom).StringType of
                           st_widestring :
                             begin
                               case TStringDef(DefTo).StringType of
                                 { Prefer conversions to unicodestring }
                                 st_unicodestring: EQ:=te_convert_l1;
                                 { else prefer conversions to ansistring }
                                 st_ansistring: EQ:=te_convert_l2;
                                 else
                                   EQ:=te_convert_l3;
                               end;
                             end;
                           st_unicodestring :
                             begin
                               case TStringDef(DefTo).StringType of
                                 { Prefer conversions to widestring }
                                 st_widestring: EQ:=te_convert_l1;
                                 { else prefer conversions to ansistring }
                                 st_ansistring: EQ:=te_convert_l2;
                                 else
                                   EQ:=te_convert_l3;
                               end;
                             end;
                           st_shortstring :
                             begin
                               { Prefer shortstrings of different length or conversions
                                 from shortstring to ansistring }
                               case TStringDef(DefTo).StringType of
                                 st_shortstring: EQ:=te_convert_l1;
                                 st_ansistring:
                                   if TStringDef(DefTo).Encoding=Globals.CP_UTF8 then
                                     EQ:=te_convert_l2
                                   else if DefTo=GetAnsiStringDef then
                                     EQ:=te_convert_l3
                                   else
                                     EQ:=te_convert_l4;
                                 st_unicodestring: EQ:=te_convert_l5;
                                 else
                                   EQ:=te_convert_l6;
                               end;
                             end;
                           st_ansistring :
                             begin
                               { Prefer conversion to widestrings }
                               case TStringDef(DefTo).StringType of
                                 st_unicodestring: EQ:=te_convert_l4;
                                 st_widestring: EQ:=te_convert_l5;
                                 else
                                   EQ:=te_convert_l6;
                               end;
                             end;
                           else
                             ;
                         end;
                       end;
                   end;
                 OrdDef :
                   begin
                   { char to string}
                     if Is_Char(DefFrom) then
                       begin
                         DoConv:=tc_char_2_string;
                         case TStringDef(DefTo).StringType of
                           st_shortstring: EQ:=te_convert_l1;
                           st_ansistring: EQ:=te_convert_l2;
                           st_unicodestring: EQ:=te_convert_l3;
                           st_widestring: EQ:=te_convert_l4;
                         else
                           EQ:=te_convert_l5;
                         end;
                       end
                     else
                     if Is_WideChar(DefFrom) then
                      begin
                        DoConv:=tc_char_2_string;
                        case TStringDef(DefTo).StringType of
                          st_unicodestring: EQ:=te_convert_l1;
                          st_widestring: EQ:=te_convert_l2;
                          st_ansistring: EQ:=te_convert_l3;
                          st_shortstring: EQ:=te_convert_l4;
                        else
                          EQ:=te_convert_l5;
                        end;
                      end;
                   end;
                 ArrayDef :
                   begin
                     { array of char to string, the length check is done by the firstpass of this node }
                     if (Is_CharArray(DefFrom) or
                         Is_Open_CharArray(DefFrom)) and
                        { bitpacked arrays of char whose element bitsize is not
                          8 cannot be auto-converted to strings }
                        (not Is_Packed_Array(DefFrom) or
                         (TArrayDef(DefFrom).ElementDef.PackedBitSize=8)) then
                      begin
                        { "Untyped" stringconstn is an array of char }
                        if FromTreeType=StringConstN then
                          begin
                            DoConv:=tc_string_2_string;
                            { prefered string type depends on the $H switch }
                            if (m_default_unicodestring in CurrentSettings.ModeSwitches) and
                               (cs_refcountedstrings in CurrentSettings.LocalSwitches) then
                              case TStringDef(DefTo).StringType of
                                st_unicodestring: EQ:=te_equal;
                                st_widestring: EQ:=te_convert_l1;
                                // widechar: eq:=te_convert_l2;
                                // ansichar: eq:=te_convert_l3;
                                st_ansistring: EQ:=te_convert_l4;
                                st_shortstring: EQ:=te_convert_l5;
                              else
                                EQ:=te_convert_l6;
                              end
                            else if not(cs_refcountedstrings in CurrentSettings.LocalSwitches) and
                               (TStringDef(DefTo).StringType=st_shortstring) then
                              EQ:=te_equal
                            else if not(m_default_unicodestring in CurrentSettings.ModeSwitches) and
                               (cs_refcountedstrings in CurrentSettings.LocalSwitches) and
                               (TStringDef(DefTo).StringType=st_ansistring) then
                              EQ:=te_equal
                            else if TStringDef(DefTo).StringType in [st_widestring,st_unicodestring] then
                              EQ:=te_convert_l3
                            else
                              EQ:=te_convert_l1;
                          end
                        else
                          begin
                          DoConv:=tc_chararray_2_string;
                          if Is_Open_Array(DefFrom) then
                            begin
                              if Is_AnsiString(DefTo) then
                                EQ:=te_convert_l1
                              else if Is_Wide_Or_Unicode_String(DefTo) then
                                EQ:=te_convert_l3
                              else
                                EQ:=te_convert_l2;
                            end
                          else
                            begin
                              if Is_ShortString(DefTo) then
                                begin
                                  { Only compatible with arrays that fit
                                    smaller than 255 chars }
                                  if (DefFrom.Size <= 255) then
                                    EQ:=te_convert_l1;
                                end
                              else if Is_AnsiString(DefTo) then
                                begin
                                  if (DefFrom.Size > 255) then
                                    EQ:=te_convert_l1
                                  else
                                    EQ:=te_convert_l2;
                                end
                              else if Is_Wide_Or_Unicode_String(DefTo) then
                                EQ:=te_convert_l3
                              else
                                EQ:=te_convert_l2;
                            end;
                          end;
                      end
                     else
                     { array of widechar to string, the length check is done by the firstpass of this node }
                      if Is_WideCharArray(DefFrom) or Is_Open_WideCharArray(DefFrom) then
                       begin
                         DoConv:=tc_chararray_2_string;
                         if Is_Wide_Or_Unicode_String(DefTo) then
                           EQ:=te_convert_l1
                         else
                           { size of widechar array is double due the sizeof a widechar }
                           if not(Is_ShortString(DefTo) and (Is_Open_WideCharArray(DefFrom) or (DefFrom.Size>255*SizeOf(WideChar)))) then
                             EQ:=te_convert_l3
                         else
                           EQ:=te_convert_l2;
                       end;
                   end;
                 PointerDef :
                   begin
                      { pchar can be assigned to short/ansistrings }
                      if Is_PChar(DefFrom) then
                           begin
                             DoConv:=tc_pchar_2_string;
                             { prefer ansistrings/unicodestrings because pchars
                               can overflow shortstrings; don't use l1/l2/l3
                               because then pchar -> ansistring has the same
                               preference as conststring -> pchar, and this
                               breaks tbs/tw3328.pas }
                             if Is_AnsiString(DefTo) then
                               EQ:=te_convert_l2
                             else if Is_Wide_Or_Unicode_String(DefTo) then
                               EQ:=te_convert_l3
                             else
                              EQ:=te_convert_l4
                           end
                      else if Is_PWideChar(DefFrom) then
                           begin
                             DoConv:=tc_pwchar_2_string;
                             if Is_Wide_Or_Unicode_String(DefTo) then
                               EQ:=te_convert_l1
                             else
                               { shortstring and ansistring can both result in
                                 data loss, so don't prefer one over the other }
                               EQ:=te_convert_l3;
                            end;
                   end;
                 ObjectDef :
                   begin
                     { corba interface -> id string }
                     if Is_InterfaceCORBA(DefFrom) then
                      begin
                        DoConv:=tc_intf_2_string;
                        EQ:=te_convert_l1;
                      end;
                   end;
                 else
                   ;
               end;
             end;

           FloatDef :
             begin
               case DefFrom.Typ of
                 OrdDef :
                   begin { ordinal to real }
                      if (Is_Integer(DefFrom) or
                         (Is_Currency(DefFrom) and
                          (S64CurrencyType.Typ = FloatDef))) then
                       begin
                         DoConv:=tc_int_2_real;

                         { prefer single over others }
                         if Is_Single(DefTo) then
                           EQ:=te_convert_l3
                         else
                           EQ:=te_convert_l4;
                       end
                     else if Is_Currency(DefFrom)
                             { and (s64currencytype.typ = orddef)) } then
                       begin
                         { prefer conversion to orddef in this case, unless    }
                         { the orddef < currency (then it will get convert l3, }
                         { and conversion to float is favoured)                }
                         DoConv:=tc_int_2_real;
                         if Is_Extended(DefTo) then
                           EQ:=te_convert_l1
                         else if Is_Double(DefTo) then
                           EQ:=te_convert_l2
                         else if Is_Single(DefTo) then
                           EQ:=te_convert_l3
                         else
                           EQ:=te_convert_l2;
                       end;
                   end;
                 FloatDef :
                   begin
                     if TFloatDef(DefFrom).FloatType=TFloatDef(DefTo).FloatType then
                       EQ:=te_equal
                     else
                       begin
                         DoConv:=tc_real_2_real;
                         { do we lose precision? }
                         if (DefTo.Size<DefFrom.Size) or
                           (Is_Currency(DefFrom) and (TFloatDef(DefTo).FloatType in [S32Real,S64Real])) then
                           begin
                             if Is_Currency(DefFrom) and (TFloatDef(DefTo).FloatType=S32Real) then
                               EQ:=te_convert_l3
                             else
                               EQ:=te_convert_l2
                           end
                         else
                           EQ:=te_convert_l1;
                       end;
                   end;
                 else
                   ;
               end;
             end;

           EnumDef :
             begin
               case DefFrom.Typ of
                 EnumDef :
                   begin
                     if cdo_explicit in CDOptions then
                      begin
                        EQ:=te_convert_l1;
                        DoConv:=tc_int_2_int;
                      end
                     else
                      begin
                        HD1:=DefFrom;
                        while Assigned(TEnumDef(HD1).BaseDef) do
                          HD1:=TEnumDef(HD1).BaseDef;
                        HD2:=DefTo;
                        while Assigned(TEnumDef(HD2).BaseDef) do
                          HD2:=TEnumDef(HD2).BaseDef;
                        if (HD1=HD2) then
                          begin
                            EQ:=te_convert_l1;
                            { because of packenum they can have different sizes! (JM) }
                            DoConv:=tc_int_2_int;
                          end
                        else
                          begin
                            { assignment of an enum symbol to an unique type? }
                            if (FromTreeType=OrdConstN) and
                              (TEnumSym(TEnumDef(HD1).GetFirstSym)=TEnumSym(TEnumDef(HD2).GetFirstSym)) then
                              begin
                                { because of packenum they can have different sizes! (JM) }
                                EQ:=te_convert_l1;
                                DoConv:=tc_int_2_int;
                              end;
                          end;
                      end;
                   end;
                 OrdDef :
                   begin
                     if cdo_explicit in CDOptions then
                      begin
                        EQ:=te_convert_l1;
                        DoConv:=tc_int_2_int;
                      end;
                   end;
                 VariantDef :
                   begin
                     EQ:=te_convert_l1;
                     DoConv:=tc_variant_2_enum;
                   end;
                 PointerDef :
                   begin
                     { ugly, but delphi allows it }
                     if cdo_explicit in CDOptions then
                       begin
                         if m_delphi in CurrentSettings.ModeSwitches then
                           begin
                             DoConv:=tc_int_2_int;
                             EQ:=te_convert_l1;
                           end
                       end;
                   end;
                 ObjectDef:
                   begin
                     { ugly, but delphi allows it }
                     if (cdo_explicit in CDOptions) and
                        Is_Class_Or_Interface_Or_DispInterface_Or_ObjC(DefFrom) then
                       begin

                         if m_delphi in CurrentSettings.ModeSwitches then
                           begin
                             DoConv:=tc_int_2_int;
                             EQ:=te_convert_l1;
                           end;
                       end;
                   end;
                 else
                   ;
               end;
             end;

           ArrayDef :
             begin
               { open array is also compatible with a single element of its base type.
                 the extra check for deftyp is needed because equal defs can also return
                 true if the def types are not the same, for example with dynarray to pointer. }
               if Is_Open_Array(DefTo) and
                  (DefFrom.Typ=TArrayDef(DefTo).ElementDef.Typ) and
                  Equal_Defs(DefFrom,TArrayDef(DefTo).ElementDef) then
                begin
                  DoConv:=tc_elem_2_openarray;
                  { also update in htypechk.pas/var_para_allowed if changed
                    here }
                  EQ:=te_convert_l3;
                end
               else
                begin
                  case DefFrom.Typ of
                    ArrayDef :
                      begin
                        { from/to packed array -- packed chararrays are      }
                        { strings in ISO Pascal (at least if the lower bound }
                        { is 1, but GPC makes all equal-length chararrays    }
                        { compatible), so treat those the same as regular    }
                        { char arrays -- except if they use subrange types   }
                        if (Is_Packed_Array(DefFrom) and
                            (not Is_CharArray(DefFrom) or
                             (TArrayDef(DefFrom).ElementDef.PackedBitSize<>8)) and
                            not Is_WideCharArray(DefFrom)) xor
                           (Is_Packed_Array(DefTo) and
                            (not Is_CharArray(DefTo) or
                             (TArrayDef(DefTo).ElementDef.PackedBitSize<>8)) and
                            not Is_WideCharArray(DefTo)) then
                          { both must be packed }
                          begin
                            Compare_Defs_Ext:=te_incompatible;
                            Exit;
                          end
                        { to dynamic array }
                        else if Is_Dynamic_Array(DefTo) then
                         begin
                           if Is_Array_Constructor(DefFrom) then
                             begin
                               { array constructor -> dynamic array }
                               if Is_Void(TArrayDef(DefFrom).ElementDef) then
                                 begin
                                   { only needs to loose to [] -> open array }
                                   EQ:=te_convert_l2;
                                   DoConv:=tc_arrayconstructor_2_dynarray;
                                 end
                               else
                                 begin
                                   { this should loose to the array constructor -> open array conversions,
                                     but it might happen that the end of the convert levels is reached :/ }
                                   SubEq:=Compare_Defs_Ext(TArrayDef(DefFrom).ElementDef,
                                                        TArrayDef(DefTo).ElementDef,
                                                        { reason for cdo_allow_variant: see tbs/tw7070a and tbs/tw7070b }
                                                        ArrayConstructorN,HCT,HPD,[cdo_check_operator,cdo_allow_variant]);
                                   if (SubEq>=te_equal) then
                                     begin
                                       EQ:=te_convert_l2;
                                     end
                                   else
                                     { an array constructor is not a dynamic array, so
                                       use a lower level of compatibility than that one of
                                       of the elements }
                                     if SubEq>te_convert_l5 then
                                      begin
                                        EQ:=Pred(Pred(SubEq));
                                      end
                                    else if SubEq>te_convert_l6 then
                                      EQ:=Pred(SubEq)
                                    else if SubEq=te_convert_operator then
                                      { the operator needs to be applied by element, so we tell
                                        the caller that it's some unpreferred conversion and let
                                        it handle the per-element stuff }
                                      EQ:=te_convert_l6
                                    else
                                      EQ:=SubEq;
                                   DoConv:=tc_arrayconstructor_2_dynarray;
                                 end;
                             end
                           else if Equal_Defs(TArrayDef(DefFrom).ElementDef,TArrayDef(DefTo).ElementDef) then
                             begin
                               { dynamic array -> dynamic array }
                               if Is_Dynamic_Array(DefFrom) then
                                 EQ:=te_equal
                               { regular array -> dynamic array }
                               else if (m_array2dynarray in CurrentSettings.ModeSwitches) and
                                 not(Is_Special_Array(DefFrom)) and
                                 Is_Zero_Based_Array(DefFrom) then
                                 begin
                                   EQ:=te_convert_l2;
                                   DoConv:=tc_array_2_dynarray;
                                 end;
                             end
                         end
                        else
                         { to open array }
                         if Is_Open_Array(DefTo) then
                          begin
                            { array constructor -> open array }
                            if Is_Array_Constructor(DefFrom) then
                             begin
                               if Is_Void(TArrayDef(DefFrom).ElementDef) then
                                begin
                                  DoConv:=tc_equal;
                                  EQ:=te_convert_l1;
                                end
                               else
                                begin
                                  SubEq:=Compare_Defs_Ext(TArrayDef(DefFrom).ElementDef,
                                                       TArrayDef(DefTo).ElementDef,
                                                       { reason for cdo_allow_variant: see tbs/tw7070a and tbs/tw7070b }
                                                       ArrayConstructorN,HCT,HPD,[cdo_check_operator,cdo_allow_variant]);
                                  if (SubEq>=te_equal) then
                                    begin
                                      DoConv:=tc_equal;
                                      EQ:=te_convert_l1;
                                    end
                                  else
                                    { an array constructor is not an open array, so
                                      use a lower level of compatibility than that one of
                                      of the elements }
                                    if SubEq>te_convert_l6 then
                                     begin
                                       DoConv:=HCT;
                                       EQ:=Pred(SubEq);
                                     end
                                   else
                                     EQ:=SubEq;
                                end;
                             end
                            else
                             { dynamic array -> open array }
                             if Is_Dynamic_Array(DefFrom) and
                                Equal_Defs(TArrayDef(DefFrom).ElementDef,TArrayDef(DefTo).ElementDef) then
                               begin
                                 DoConv:=tc_dynarray_2_openarray;
                                 EQ:=te_convert_l2;
                               end
                            else
                             { open array -> open array }
                             if Is_Open_Array(DefFrom) and
                                Equal_Defs(TArrayDef(DefFrom).ElementDef,TArrayDef(DefTo).ElementDef) then
                               if TArrayDef(DefFrom).ElementDef=TArrayDef(DefTo).ElementDef then
                                 EQ:=te_exact
                               else
                                 EQ:=te_equal
                            else
                             { array -> open array }
                             if not(cdo_parameter in CDOptions) and
                                Equal_Defs(TArrayDef(DefFrom).ElementDef,TArrayDef(DefTo).ElementDef) then
                               begin
                                 if FromTreeType=StringConstN then
                                   EQ:=te_convert_l1
                                 else
                                   EQ:=te_equal;
                               end;
                          end
                        else
                         { to array of const }
                         if Is_Array_Of_Const(DefTo) then
                          begin
                            if Is_Array_Of_Const(DefFrom) or
                               Is_Array_Constructor(DefFrom) then
                             begin
                               EQ:=te_equal;
                             end
                            else
                             { array of tvarrec -> array of const }
                             if Equal_Defs(TArrayDef(DefTo).ElementDef,TArrayDef(DefFrom).ElementDef) then
                              begin
                                DoConv:=tc_equal;
                                EQ:=te_convert_l1;
                              end;
                          end
                        else
                          { to array of char, from "Untyped" stringconstn (array of char) }
                          if (FromTreeType=StringConstN) and
                             ((Is_CharArray(DefTo) and
                               { bitpacked arrays of char whose element bitsize is not
                                 8 cannot be auto-converted from strings }
                               (not Is_Packed_Array(DefTo) or
                                (TArrayDef(DefTo).ElementDef.PackedBitSize=8))) or
                              Is_WideCharArray(DefTo)) then
                            begin
                              EQ:=te_convert_l1;
                              DoConv:=tc_string_2_chararray;
                            end
                        else
                          { to normal array }
                          if Is_Normal_Array(DefTo) and Is_Array_Constructor(DefFrom) then
                            begin
                              { element count must match exactly }
                              if TArrayDef(DefTo).EleCount=TArrayDef(DefFrom).EleCount then
                                begin
                                  EQ:=te_convert_l2;
                                  DoConv:=tc_arrayconstructor_2_array;
                                end;
                            end
                        else
                         { other arrays }
                          begin
                            { open array -> array }
                            if not(cdo_parameter in CDOptions) and
                               Is_Open_Array(DefFrom) and
                               Equal_Defs(TArrayDef(DefFrom).ElementDef,TArrayDef(DefTo).ElementDef) then
                              begin
                                EQ:=te_equal
                              end
                            else
                            { array -> array }
                              if ((not(m_delphi in CurrentSettings.ModeSwitches)) or
                                { allow assigning vector results to regular
                                  arrays. TODO: change once we expose vector types }
                                 TArrayDef(DefFrom).Is_HWVector) and
                                (TArrayDef(DefFrom).LowRange=TArrayDef(DefTo).LowRange) and
                                (TArrayDef(DefFrom).HighRange=TArrayDef(DefTo).HighRange) and
                                Equal_Defs(TArrayDef(DefFrom).ElementDef,TArrayDef(DefTo).ElementDef) and
                                (Compare_Defs_Ext(TArrayDef(DefFrom).RangeDef,TArrayDef(DefTo).RangeDef,NothingN,HCT,HPD,[])>te_incompatible) then
                              begin
                                EQ:=te_equal
                              end;
                          end;
                      end;
                    PointerDef :
                      begin
                        { nil and voidpointers are compatible with dyn. arrays }
                        if Is_Dynamic_Array(DefTo) and
                           ((FromTreeType=NilN) or
                            Is_VoidPointer(DefFrom)) then
                         begin
                           DoConv:=tc_equal;
                           EQ:=te_convert_l1;
                         end
                        else
                         if Is_Zero_Based_Array(DefTo) and
                            not Is_Cyclic(DefFrom) and
                            Equal_Defs(TPointerDef(DefFrom).PointedDef,TArrayDef(DefTo).ElementDef) then
                          begin
                            DoConv:=tc_pointer_2_array;
                            EQ:=te_convert_l1;
                          end;
                      end;
                    StringDef :
                      begin
                        { string to char array }
                        if not Is_Special_Array(DefTo) and
                           ((Is_Char(TArrayDef(DefTo).ElementDef) and
                             { bitpacked arrays of char whose element bitsize is not
                               8 cannot be auto-converted from strings }
                             (not Is_Packed_Array(DefTo) or
                              (TArrayDef(DefTo).ElementDef.PackedBitSize=8))) or
                            Is_WideChar(TArrayDef(DefTo).ElementDef)) then
                         begin
                           DoConv:=tc_string_2_chararray;
                           EQ:=te_convert_l1;
                         end;
                      end;
                    OrdDef:
                      begin
                        if Is_CharArray(DefTo) and
                           Is_Char(DefFrom) then
                          begin
                            DoConv:=tc_char_2_chararray;
                            EQ:=te_convert_l2;
                          end;
                      end;
                    RecordDef :
                      begin
                        { tvarrec -> array of const }
                         if Is_Array_Of_Const(DefTo) and
                            Equal_Defs(DefFrom,TArrayDef(DefTo).ElementDef) then
                          begin
                            DoConv:=tc_equal;
                            EQ:=te_convert_l1;
                          end;
                      end;
                    VariantDef :
                      begin
                         if Is_Dynamic_Array(DefTo) then
                           begin
                              DoConv:=tc_variant_2_dynarray;
                              EQ:=te_convert_l1;
                           end;
                      end;
                    SetDef :
                      begin
                        { special case: an empty set constant is compatible as
                          well }
                        if not Assigned(TSetDef(DefFrom).ElementDef)
                            and (FromTreeType=SetConstN) then
                          begin
                            DoConv:=tc_arrayconstructor_2_dynarray;
                            EQ:=te_convert_l1;
                          end;
                      end;
                    else
                      ;
                  end;
                end;
             end;

           VariantDef :
             begin
               if (cdo_allow_variant in CDOptions) then
                 begin
                   case DefFrom.Typ of
                     EnumDef :
                       begin
                         DoConv:=tc_enum_2_variant;
                         EQ:=te_convert_l1;
                       end;
                     ArrayDef :
                       begin
                          if Is_Dynamic_Array(DefFrom) then
                            begin
                               DoConv:=tc_dynarray_2_variant;
                               EQ:=te_convert_l1;
                            end;
                       end;
                     ObjectDef :
                       begin
                         { corbainterfaces not accepted, until we have
                           runtime support for them in Variants (sergei) }
                          if Is_InterfaceCOM_Or_DispInterface(DefFrom) then
                            begin
                               DoConv:=tc_interface_2_variant;
                               EQ:=te_convert_l1;
                            end;
                       end;
                     VariantDef :
                       begin
                         { doing this in the compiler avoids a lot of unnecessary
                           copying }
                         if (TVariantDef(DefFrom).VariantType=vt_olevariant) and
                           (TVariantDef(DefTo).VariantType=vt_normalvariant) then
                           begin
                             DoConv:=tc_equal;
                             EQ:=te_convert_l1;
                           end;
                       end;
                     else
                       ;
                   end;
                 end;
             end;

           PointerDef :
             begin
               case DefFrom.Typ of
                 StringDef :
                   begin
                     { string constant (which can be part of array constructor)
                       to zero terminated string constant }
                     if (FromTreeType = StringConstN) and
                        (Is_PChar(DefTo) or Is_PWideChar(DefTo)) then
                      begin
                        DoConv:=tc_cstring_2_pchar;
                        if Is_PWideChar(DefTo)=(m_default_unicodestring in CurrentSettings.ModeSwitches) then
                          EQ:=te_convert_l2
                        else
                          EQ:=te_convert_l3
                      end
                     else
                      if (cdo_explicit in CDOptions) or (FromTreeType = ArrayConstructorN) then
                       begin
                         { pchar(ansistring) }
                         if Is_PChar(DefTo) and
                            Is_AnsiString(DefFrom) then
                          begin
                            DoConv:=tc_ansistring_2_pchar;
                            EQ:=te_convert_l1;
                          end
                         else
                          { pwidechar(widestring) }
                          if Is_PWideChar(DefTo) and
                            Is_Wide_Or_Unicode_String(DefFrom) then
                           begin
                             DoConv:=tc_ansistring_2_pchar;
                             EQ:=te_convert_l1;
                           end;
                       end;
                   end;
                 OrdDef :
                   begin
                     { char constant to zero terminated string constant }
                     if (FromTreeType in [OrdConstN,ArrayConstructorN]) then
                      begin
                        if (Is_Char(DefFrom) or Is_WideChar(DefFrom)) and
                           (Is_PChar(DefTo) or Is_PWideChar(DefTo)) then
                         begin
                           DoConv:=tc_cchar_2_pchar;
                           if Is_PWideChar(DefTo)=(m_default_unicodestring in CurrentSettings.ModeSwitches) then
                             EQ:=te_convert_l1
                           else
                             EQ:=te_convert_l2
                         end
                        else
                         if (m_delphi in CurrentSettings.ModeSwitches) and Is_Integer(DefFrom) then
                          begin
                            DoConv:=tc_cord_2_pointer;
                            EQ:=te_convert_l5;
                          end;
                      end;
                     { allow explicit typecasts from ordinals to pointer.
                       Support for delphi compatibility
                       Support constructs like pointer(cardinal-cardinal) or pointer(longint+cardinal) where
                        the result of the ordinal operation is int64 also on 32 bit platforms.
                       It is also used by the compiler internally for inc(pointer,ordinal) }
                     if (EQ=te_incompatible) and
                        not Is_Void(DefFrom) and
                        (
                         (
                          (cdo_explicit in CDOptions) and
                          (
                           (m_delphi in CurrentSettings.ModeSwitches) or
                           { Don't allow pchar(char) in fpc modes }
                           Is_Integer(DefFrom)
                          )
                         ) or
                         (cdo_internal in CDOptions)
                        ) then
                       begin
                         DoConv:=tc_int_2_int;
                         EQ:=te_convert_l1;
                       end;
                   end;
                 EnumDef :
                   begin
                     { allow explicit typecasts from enums to pointer.
                       Support for delphi compatibility
                     }

                     if (((cdo_explicit in CDOptions) and
                          (m_delphi in CurrentSettings.ModeSwitches)
                         ) or
                         (cdo_internal in CDOptions)
                        ) then
                       begin

                         if m_delphi in CurrentSettings.ModeSwitches then
                           begin
                             DoConv:=tc_int_2_int;
                             EQ:=te_convert_l1;
                           end;
                       end;
                   end;
                 ArrayDef :
                   begin
                     { string constant (which can be part of array constructor)
                       to zero terminated string constant }
                     if (((FromTreeType = ArrayConstructorN) and
                          { can't use is_chararray, because returns false for }
                          { array constructors                                }
                          Is_Char(TArrayDef(DefFrom).ElementDef)) or
                         (FromTreeType = StringConstN)) and
                        (Is_PChar(DefTo) or Is_PWideChar(DefTo)) then
                      begin
                        DoConv:=tc_cstring_2_pchar;
                        if ((m_default_unicodestring in CurrentSettings.ModeSwitches) xor
                           Is_PChar(DefTo)) then
                          EQ:=te_convert_l2
                        else
                          EQ:=te_convert_l3;
                      end
                     else
                      { chararray to pointer }
                      if (Is_Zero_Based_Array(DefFrom) or
                          Is_Open_Array(DefFrom)) and
                          Equal_Defs(TArrayDef(DefFrom).ElementDef,TPointerDef(DefTo).PointedDef) then
                        begin
                          DoConv:=tc_array_2_pointer;
                          { don't prefer the pchar overload when a constant
                            string was passed }
                          if FromTreeType=StringConstN then
                            EQ:=te_convert_l2
                          else
                            EQ:=te_convert_l1;
                        end
                     else
                       { dynamic array to pointer, delphi only }
                       if (m_delphi in CurrentSettings.ModeSwitches) and
                          Is_Dynamic_Array(DefFrom) and
                          Is_VoidPointer(DefTo) then
                        begin
                          EQ:=te_equal;
                        end;
                   end;
                 PointerDef :
                   begin
                     { check for far pointers }
                     if not TPointerDef(DefFrom).Compatible_With_PointerDef_Size(TPointerDef(DefTo)) then
                       begin
                         if FromTreeType=NilN then
                           EQ:=te_equal
                         else
                           EQ:=te_incompatible;
                       end
                     { the types can be forward type, handle before normal type check !! }
                     else
                      if Assigned(DefTo.TypeSym) and
                         ((TPointerDef(DefTo).PointedDef.Typ=ForwardDef) or
                          (TPointerDef(DefFrom).PointedDef.Typ=ForwardDef)) then
                       begin
                         if (DefFrom.TypeSym=DefTo.TypeSym) or
                            (FromTreeType=NilN) then
                          EQ:=te_equal
                       end
                     else
                       begin
                         { avoid crash/stack overflow on recursive pointer definitions, see tests/webtbf/tw39634.pas }
                         HD1:=TAbstractPointerDef(DefFrom).PointedDef;
                         HD2:=TAbstractPointerDef(DefTo).PointedDef;
                         while Assigned(HD1) and (HD1.Typ=PointerDef) and
                           Assigned(HD2) and (HD2.Typ=PointerDef) do
                           begin
                             if HD1=HD2 then
                               Break;
                             if (HD1=DefFrom) and (HD2=DefTo) then
                               begin
                                 EQ:=te_incompatible;
                                 Break;
                               end;
                             HD1:=TAbstractPointerDef(HD1).PointedDef;
                             HD2:=TAbstractPointerDef(HD2).PointedDef;
                           end;

                         { same types }
                         if not((HD1=DefFrom) and (HD2=DefTo)) and Equal_Defs(TPointerDef(DefFrom).PointedDef,TPointerDef(DefTo).PointedDef) then
                           begin
                             EQ:=te_equal
                           end
                         else
                          { child class pointer can be assigned to ancestor pointers }
                          if (
                              (TPointerDef(DefFrom).PointedDef.Typ=ObjectDef) and
                              (TPointerDef(DefTo).PointedDef.Typ=ObjectDef) and
                              Def_Is_Related(TObjectDef(TPointerDef(DefFrom).PointedDef),
                                TObjectDef(TPointerDef(DefTo).PointedDef))
                             ) then
                           begin
                             DoConv:=tc_equal;
                             EQ:=te_convert_l1;
                           end
                         else
                          { all pointers can be assigned to void-pointer }
                          if Is_Void(TPointerDef(DefTo).PointedDef) then
                           begin
                             DoConv:=tc_equal;
                             { give pwidechar,pchar a penalty so it prefers
                               conversion to ansistring }
                             if Is_PChar(DefFrom) or
                                Is_PWideChar(DefFrom) then
                               EQ:=te_convert_l2
                             else
                               EQ:=te_convert_l1;
                           end
                         else
                          { all pointers can be assigned from void-pointer }
                          if Is_Void(TPointerDef(DefFrom).PointedDef) or
                          { all pointers can be assigned from void-pointer or formaldef pointer, check
                            tw3777 (case in tb_records_delphi_run_01.pas).pas if you change this }
                            (TPointerDef(DefFrom).PointedDef.Typ=FormalDef) then
                           begin
                             DoConv:=tc_equal;
                             { give pwidechar a penalty so it prefers
                               conversion to pchar }
                             if Is_PWideChar(DefTo) then
                               EQ:=te_convert_l2
                             else
                               EQ:=te_convert_l1;
                           end
                         { id = generic class instance. metaclasses are also
                           class instances themselves.  }
                         else if ((DefFrom=ObjC_IDType) and
                                  (DefTo=ObjC_MetaClassType)) or
                                 ((DefTo=ObjC_IDType) and
                                  (DefFrom=ObjC_MetaClassType)) then
                           begin
                             DoConv:=tc_equal;
                             EQ:=te_convert_l2;
                           end;
                       end;
                   end;
                 ProcVarDef :
                   begin
                     { procedure variable can be assigned to an void pointer,
                       this is not allowed for complex procvars }
                     if (Is_Void(TPointerDef(DefTo).PointedDef) or
                         (m_mac_procvar in CurrentSettings.ModeSwitches)) and
                        TProcVarDef(DefFrom).Compatible_With_PointerDef_Size(TPointerDef(DefTo)) then
                      begin
                        DoConv:=tc_equal;
                        EQ:=te_convert_l1;
                      end;
                   end;
                 ProcDef :
                   begin
                     { procedure variable can be assigned to an void pointer,
                       this not allowed for methodpointers }
                     if (m_mac_procvar in CurrentSettings.ModeSwitches) and
                        TProcDef(DefFrom).Compatible_With_PointerDef_Size(TPointerDef(DefTo)) then
                      begin
                        DoConv:=tc_proc_2_procvar;
                        EQ:=te_convert_l2;
                      end;
                   end;
                 ClassRefDef,
                 ObjectDef :
                   begin
                     { implicit pointer object and class reference types
                       can be assigned to void pointers, but it is less
                       preferred than assigning to a related objectdef }
                     if (
                         Is_Implicit_Pointer_Object_Type(DefFrom) or
                         (DefFrom.Typ=ClassRefDef)
                        ) and
                        (TPointerDef(DefTo).PointedDef.Typ=OrdDef) and
                        (TOrdDef(TPointerDef(DefTo).PointedDef).OrdType=UVoid) then
                       begin
                         DoConv:=tc_equal;
                         EQ:=te_convert_l5;
                       end
                     else if (Is_ObjC_Class_Or_Protocol(DefFrom) and
                              (DefTo=ObjC_IDType)) or
                             { classrefs are also instances in Objective-C,
                               hence they're also assignment-compatible with
                               id }
                             (Is_ObjCClassRef(DefFrom) and
                              ((DefTo=ObjC_MetaClassType) or
                               (DefTo=ObjC_IDType))) then
                       begin
                         DoConv:=tc_equal;
                         EQ:=te_convert_l2;
                       end;
                   end;
                 else
                   ;
               end;
             end;

           SetDef :
             begin
               case DefFrom.Typ of
                 SetDef :
                   begin
                     if Assigned(TSetDef(DefFrom).ElementDef) and
                        Assigned(TSetDef(DefTo).ElementDef) then
                      begin
                        { sets with the same size (packset setting), element
                          base type and the same range are equal }
                        if Equal_Defs(TSetDef(DefFrom).ElementDef,TSetDef(DefTo).ElementDef) and
                           (TSetDef(DefFrom).SetBase=TSetDef(DefTo).SetBase) and
                           (TSetDef(DefFrom).SetMax=TSetDef(DefTo).SetMax) and
                           (DefFrom.Size=DefTo.Size) then
                          EQ:=te_equal
                        else if Is_Subequal(TSetDef(DefFrom).ElementDef,TSetDef(DefTo).ElementDef) then
                          begin
                            EQ:=te_convert_l1;
                            DoConv:=tc_set_to_set;
                          end;
                      end
                     else
                      begin
                        { empty set is compatible with everything }
                        EQ:=te_convert_l1;
                        DoConv:=tc_set_to_set;
                      end;
                   end;
                 ArrayDef :
                   begin
                     { automatic arrayconstructor -> set conversion }
                     if Is_Array_Constructor(DefFrom) then
                      begin
                        DoConv:=tc_arrayconstructor_2_set;
                        EQ:=te_convert_l1;
                      end;
                   end;
                 else
                   ;
               end;
             end;

           ProcVarDef :
             begin
               case DefFrom.Typ of
                 ProcDef :
                   begin
                     { proc -> procvar }
                     if (m_tp_procvar in CurrentSettings.ModeSwitches) or
                        (m_mac_procvar in CurrentSettings.ModeSwitches) or
                        (po_anonymous in TProcDef(DefFrom).ProcOptions) then
                      begin
                        SubEq:=Proc_To_ProcVar_Equal(TProcDef(DefFrom),TProcVarDef(DefTo),cdo_warn_incompatible_univ in CDOptions);
                        if SubEq>te_incompatible then
                         begin
                           DoConv:=tc_proc_2_procvar;
                           if SubEq>te_convert_l5 then
                             EQ:=Pred(SubEq)
                           else
                             EQ:=SubEq;
                         end;
                      end;
                   end;
                 ProcVarDef :
                   begin
                     { procvar -> procvar }
                     EQ:=Proc_To_ProcVar_Equal(TProcVarDef(DefFrom),TProcVarDef(DefTo),cdo_warn_incompatible_univ in CDOptions);
                     if EQ<te_equal then
                       DoConv:=tc_proc_2_procvar
                     else
                       DoConv:=tc_equal;
                   end;
                 PointerDef :
                   begin
                     { nil is compatible with procvars }
                     if (FromTreeType=NilN) then
                      begin
                        if not TProcVarDef(DefTo).Is_AddressOnly then
                          {Nil to method pointers requires to convert a single
                           pointer nil value to a two pointer procvardef.}
                          DoConv:=tc_nil_2_methodprocvar
                        else
                          DoConv:=tc_equal;
                        EQ:=te_convert_l1;
                      end
                     else
                      { for example delphi allows the assignment from pointers  }
                      { to procedure variables                                  }
                      if (m_pointer_2_procedure in CurrentSettings.ModeSwitches) and
                         Is_Void(TPointerDef(DefFrom).PointedDef) and
                         TProcVarDef(DefTo).Is_AddressOnly and
                         TProcVarDef(DefTo).Compatible_With_PointerDef_Size(TPointerDef(DefFrom)) then
                       begin
                         DoConv:=tc_equal;
                         EQ:=te_convert_l1;
                       end;
                   end;
                 else
                   ;
               end;
             end;

           ObjectDef :
             begin
               { object pascal objects }
               { don't call def_is_related if we came here from equal_defs, because
                   1) this can never result in an "equal result", and
                   2) def_is_related itself calls equal_defs again for each class in
                      the hierarchy, which will call compare_defs_ext, which will again
                      call def_is_related -> quadratic complexity explosion }
               if not(cdo_equal_check in CDOptions) and
                  (DefFrom.Typ=ObjectDef) and
                  (Def_Is_Related(TObjectDef(DefFrom),TObjectDef(DefTo))) then
                begin
                  DoConv:=tc_equal;
                  { also update in htypechk.pas/var_para_allowed if changed
                    here }
                  EQ:=te_convert_l3;
                end

               else if Is_FuncRef(DefTo) and
                   (DefFrom.Typ=ProcDef) and
                   (po_anonymous in TProcDef(DefFrom).ProcOptions) then
                 begin
                   SubEq:=Proc_To_FuncRef_Conv(TProcDef(DefFrom),TObjectDef(DefTo));
                   if SubEq>te_incompatible then
                     begin
                       DoConv:=tc_anonproc_2_funcref;
                       if SubEq>te_convert_l5 then
                         EQ:=Pred(SubEq)
                       else
                         EQ:=SubEq;
                     end;
                 end
               else if Is_FuncRef(DefTo) and
                   Is_FuncRef(DefFrom) and
                   not (cdo_equal_check in CDOptions) then
                 begin
                   EQ:=FuncRef_Equal(TObjectDef(DefFrom),TObjectDef(DefTo));
                   if EQ>=te_equal then
                     DoConv:=tc_equal;
                 end
               else
               { specific to implicit pointer object types }
                if Is_Implicit_Pointer_Object_Type(DefTo) then
                 begin
                   { void pointer also for delphi mode }
                   if (m_delphi in CurrentSettings.ModeSwitches) and
                      Is_VoidPointer(DefFrom) then
                    begin
                      DoConv:=tc_equal;
                      { prefer pointer-pointer assignments }
                      EQ:=te_convert_l2;
                    end
                   else
                   { nil is compatible with class instances and interfaces }
                    if (FromTreeType=NilN) then
                     begin
                       DoConv:=tc_equal;
                       EQ:=te_convert_l1;
                     end
                   { All Objective-C classes are compatible with ID }
                   else if Is_ObjC_Class_Or_Protocol(DefTo) and
                           (DefFrom=ObjC_IDType) then
                      begin
                       DoConv:=tc_equal;
                       EQ:=te_convert_l2;
                     end
                   { classes can be assigned to interfaces
                     (same with objcclass and objcprotocol) }
                   else if ((Is_Interface(DefTo) and
                             Is_Class(DefFrom)) or
                            (Is_ObjCProtocol(DefTo) and
                             Is_ObjCClass(DefFrom))) and
                           Assigned(TObjectDef(DefFrom).ImplementedInterfaces) then
                     begin
                        { we've to search in parent classes as well }
                        HObjDef:=TObjectDef(DefFrom);
                        while Assigned(HObjDef) do
                          begin
                             if Find_Implemented_Interface(HObjDef,TObjectDef(DefTo))<>nil then
                               begin
                                  if Is_Interface(DefTo) then
                                    DoConv:=tc_class_2_intf
                                  else
                                    { for Objective-C, we don't have to do anything special }
                                    DoConv:=tc_equal;
                                  { don't prefer this over objectdef->objectdef or
                                    inherited objectdef->objectdef }
                                  EQ:=te_convert_l4;
                                  Break;
                               end;
                             HObjDef:=HObjDef.ChildOf;
                          end;
                     end
                   { Interface 2 GUID handling }
                   else if (DefTo=TDef(Rec_TGUID)) and
                           (FromTreeType=TypeN) and
                           Is_Interface(DefFrom) and
                           Assigned(TObjectDef(DefFrom).IIDGUID) then
                     begin
                       EQ:=te_convert_l1;
                       DoConv:=tc_equal;
                     end
                   else if Is_FuncRef(DefTo) and
                     (DefFrom.Typ in [ProcDef,ProcVarDef]) then
                     begin
                       SubEq:=Proc_To_FuncRef_Conv(TAbstractProcDef(DefFrom),TObjectDef(DefTo));
                       if SubEq>te_incompatible then
                         begin
                           DoConv:=tc_procvar_2_funcref;
                           if SubEq>te_convert_l5 then
                             EQ:=Pred(SubEq)
                           else
                             EQ:=SubEq;
                         end;
                     end
                   else if (DefFrom.Typ=VariantDef) and Is_InterfaceCOM_Or_DispInterface(DefTo) then
                     begin
                     { corbainterfaces not accepted, until we have
                       runtime support for them in Variants (sergei) }
                       DoConv:=tc_variant_2_interface;
                       EQ:=te_convert_l2;
                     end
                   { ugly, but delphi allows it (enables typecasting ordinals/
                     enums of any size to pointer-based object defs) }

                   else if ((DefFrom.Typ=EnumDef) or
                            ((DefFrom.Typ=OrdDef) and
                             not Is_Void(DefFrom))) and
                      (m_delphi in CurrentSettings.ModeSwitches) and
                      (cdo_explicit in CDOptions) then
                     begin
                       DoConv:=tc_int_2_int;
                       EQ:=te_convert_l1;
                     end;
                 end;
             end;

           ClassRefDef :
             begin
               { similar to pointerdef wrt forwards }
               if Assigned(DefTo.TypeSym) and
                  (TClassRefDef(DefTo).PointedDef.Typ=ForwardDef) or
                  ((DefFrom.Typ=ClassRefDef) and
                   (TClassRefDef(DefFrom).PointedDef.Typ=ForwardDef)) then
                 begin
                   if (DefFrom.TypeSym=DefTo.TypeSym) or
                      (FromTreeType=NilN) then
                    EQ:=te_equal;
                 end
               else
                { class reference types }
                if (DefFrom.Typ=ClassRefDef) then
                 begin
                   if Equal_Defs(TClassRefDef(DefFrom).PointedDef,TClassRefDef(DefTo).PointedDef) then
                    begin
                      EQ:=te_equal;
                    end
                   else
                    begin
                      DoConv:=tc_equal;
                      if (cdo_explicit in CDOptions) or
                         Def_Is_Related(TObjectDef(TClassRefDef(DefFrom).PointedDef),
                           TObjectDef(TClassRefDef(DefTo).PointedDef)) then
                        EQ:=te_convert_l1;
                    end;
                 end
               else
                 if (m_delphi in CurrentSettings.ModeSwitches) and
                    Is_VoidPointer(DefFrom) then
                  begin
                    DoConv:=tc_equal;
                    { prefer pointer-pointer assignments }
                    EQ:=te_convert_l2;
                  end
                 else
                { nil is compatible with class references }
                if (FromTreeType=NilN) then
                 begin
                   DoConv:=tc_equal;
                   EQ:=te_convert_l1;
                 end
               else
                 { id is compatible with all classref types }
                 if (DefFrom=ObjC_IDType) then
                   begin
                     DoConv:=tc_equal;
                     EQ:=te_convert_l1;
                   end;
             end;

           FileDef :
             begin
               { typed files are all equal to the abstract file type
               name TYPEDFILE in system.pas in is_equal in types.pas
               the problem is that it should be also compatible to FILE
               but this would lead to a problem for ASSIGN RESET and REWRITE
               when trying to find the good overloaded function !!
               so all file function are doubled in system.pas
               this is not very beautiful !!}
               if (DefFrom.Typ=FileDef) then
                begin
                  if (TFileDef(DefFrom).FileTyp=TFileDef(DefTo).FileTyp) then
                   begin
                     if
                        (
                         (TFileDef(DefFrom).TypedFileDef=nil) and
                         (TFileDef(DefTo).TypedFileDef=nil)
                        ) or
                        (
                         (TFileDef(DefFrom).TypedFileDef<>nil) and
                         (TFileDef(DefTo).TypedFileDef<>nil) and
                         Equal_Defs(TFileDef(DefFrom).TypedFileDef,TFileDef(DefTo).TypedFileDef)
                        ) or
                        (
                         (TFileDef(DefFrom).FileTyp = ft_typed) and
                         (TFileDef(DefTo).FileTyp = ft_typed) and
                         (
                          (TFileDef(DefFrom).TypedFileDef = TDef(VoidType)) or
                          (TFileDef(DefTo).TypedFileDef = TDef(VoidType))
                         )
                        ) then
                      begin
                        EQ:=te_equal;
                      end;
                   end
                  else
                   if ((TFileDef(DefFrom).FileTyp = ft_untyped) and
                       (TFileDef(DefTo).FileTyp = ft_typed)) or
                      ((TFileDef(DefFrom).FileTyp = ft_typed) and
                       (TFileDef(DefTo).FileTyp = ft_untyped)) then
                    begin
                      DoConv:=tc_equal;
                      EQ:=te_convert_l1;
                    end;
                end;
             end;

           RecordDef :
             begin
               { interface -> guid }
               if (DefTo=Rec_TGUID) and
                  (Is_InterfaceCOM_Or_DispInterface(DefFrom)) then
                begin
                  DoConv:=tc_intf_2_guid;
                  EQ:=te_convert_l1;
                end;
             end;

           FormalDef :
             begin
               DoConv:=tc_equal;
               if (DefFrom.Typ=FormalDef) then
                 EQ:=te_equal
               else
                { Just about everything can be converted to a formaldef...}
                if not (DefFrom.Typ in [AbstractDef,ErrorDef]) then
                  EQ:=te_convert_l6;
             end;
           else
             ;
        end;

        { if we didn't find an appropriate type conversion yet
          then we search also the := operator }
        if (EQ=te_incompatible) and
           { make sure there is not a single variant if variants   }
           { are not allowed (otherwise if only cdo_check_operator }
           { and e.g. fromdef=stringdef and todef=variantdef, then }
           { the test will still succeed                           }
           ((cdo_allow_variant in CDOptions) or
            ((DefFrom.Typ<>VariantDef) and
             (DefTo.Typ<>VariantDef) and
             { internal typeconversions always have to be bitcasts (except for
               variants) }
             not(cdo_internal in CDOptions)
            )
           ) and
           (
            { Check for variants? }
            (
             (cdo_allow_variant in CDOptions) and
             ((DefFrom.Typ=VariantDef) or (DefTo.Typ=VariantDef))
            ) or
            { Check for operators? }
            (
             (cdo_check_operator in CDOptions) and
             ((DefFrom.Typ<>VariantDef) or (DefTo.Typ<>VariantDef))
            )
           ) then
          begin
            OperatorPD:=Search_Assignment_Operator(DefFrom,DefTo,cdo_explicit in CDOptions);
            if Assigned(OperatorPD) then
             EQ:=te_convert_operator;
          end;

        { update convtype for te_equal when it is not yet set }
        if (EQ=te_equal) and
           (DoConv=tc_not_possible) then
          DoConv:=tc_equal;

        Compare_Defs_Ext:=EQ;
      end;


    function Equal_Defs(DefFrom,DefTo:TDef):Boolean;
      var
        ConvTyp : TConvertType;
        PD : TProcDef;
      begin
        { Compare defs with nothingn and no explicit typecasts and
          searching for overloaded operators is not needed }
        Equal_Defs:=(Compare_Defs_Ext(DefFrom,DefTo,NothingN,ConvTyp,PD,[cdo_equal_check])>=te_equal);
      end;


    function Compare_Defs(DefFrom,DefTo:TDef;FromTreeType:TNodeType):TEqualType;
      var
        DoConv : TConvertType;
        PD : TProcDef;
      begin
        Compare_Defs:=Compare_Defs_Ext(DefFrom,DefTo,FromTreeType,DoConv,PD,[cdo_check_operator,cdo_allow_variant]);
      end;


    function Is_Subequal(Def1, Def2: TDef): Boolean;
      var
         BaseDef1,BaseDef2 : TEnumDef;

      Begin
        Is_Subequal := False;
        if Assigned(Def1) and Assigned(Def2) then
         Begin
           if (Def1.Typ = OrdDef) and (Def2.Typ = OrdDef) then
            Begin
              { see p.47 of Turbo Pascal 7.01 manual for the separation of types }
              { range checking for case statements is done with adaptrange        }
              case TOrdDef(Def1).OrdType of
                U8Bit,U16Bit,U32Bit,U64Bit,
                S8Bit,S16Bit,S32Bit,S64Bit :
                  Is_Subequal:=(TOrdDef(Def2).OrdType in [S64Bit,U64Bit,S32Bit,U32Bit,U8Bit,S8Bit,S16Bit,U16Bit]);
                PasBool1,PasBool8,PasBool16,PasBool32,PasBool64,
                Bool8Bit,Bool16Bit,Bool32Bit,Bool64Bit :
                  Is_Subequal:=(TOrdDef(Def2).OrdType in [PasBool1,PasBool8,PasBool16,PasBool32,PasBool64,Bool8Bit,Bool16Bit,Bool32Bit,Bool64Bit]);
                UChar :
                  Is_Subequal:=(TOrdDef(Def2).OrdType=UChar);
                UWideChar :
                  Is_Subequal:=(TOrdDef(Def2).OrdType=UWideChar);
                CustomInt:
                  Is_Subequal:=(TOrdDef(Def2).Low=TOrdDef(Def1).Low) and (TOrdDef(Def2).High=TOrdDef(Def1).High);
                U128Bit, S128Bit,
                SCurrency,
                UVoid:
                  ;
              end;
            end
           else
            Begin
              { Check if both basedefs are equal }
              if (Def1.Typ=EnumDef) and (Def2.Typ=EnumDef) then
                Begin
                   { get both basedefs }
                   BaseDef1:=TEnumDef(Def1);
                   while Assigned(BaseDef1.BaseDef) do
                     BaseDef1:=BaseDef1.BaseDef;
                   BaseDef2:=TEnumDef(Def2);
                   while Assigned(BaseDef2.BaseDef) do
                     BaseDef2:=BaseDef2.BaseDef;
                   Is_Subequal:=(BaseDef1=BaseDef2);
                end;
            end;
         end;
      end;


    function PotentiallyIncompatibleUnivParas(Def1, Def2: TDef): Boolean;
      begin
        Result :=
          { not entirely safe: different records can be passed differently
            depending on the types of their fields, but they're hard to compare
            (variant records, bitpacked vs non-bitpacked) }
          ((Def1.Typ in [FloatDef,RecordDef,ArrayDef,FileDef,VariantDef]) and
           (Def1.Typ<>Def2.Typ)) or
          { pointers, ordinals and small sets are all passed the same}
          (((Def1.Typ in [OrdDef,EnumDef,PointerDef,ProcVarDef,ClassRefDef]) or
            (Is_Class_Or_Interface_Or_ObjC(Def1)) or
            Is_Dynamic_Array(Def1) or
            Is_SmallSet(Def1) or
            Is_AnsiString(Def1) or
            Is_UnicodeString(Def1)) <>
           (Def2.Typ in [OrdDef,EnumDef,PointerDef,ProcVarDef,ClassRefDef]) or
            (Is_Class_Or_Interface_Or_ObjC(Def2)) or
            Is_Dynamic_Array(Def2) or
             Is_SmallSet(Def2) or
            Is_AnsiString(Def2) or
            Is_UnicodeString(Def2)) or
           { shortstrings }
           (Is_ShortString(Def1)<>
            Is_ShortString(Def2)) or
           { winlike widestrings }
           (Is_WideString(Def1)<>
            Is_WideString(Def2)) or
           { TP-style objects }
           (Is_Object(Def1) <>
            Is_Object(Def2));
      end;


    function Compare_Paras(Para1,Para2 : TFPObjectList; ACP : TCompareParasType; CPOptions: TCompareParasOptions):TEqualType;

      var
         I1,I2     : Byte;

      procedure SkipArgs;
        var
          Skipped : Boolean;
        begin
          repeat
            Skipped:=False;
            if cpo_ignorehidden in CPOptions then
              begin
                while (I1<Para1.Count) and
                      (vo_is_hidden_para in TParaVarSym(Para1[I1]).VarOptions) do
                  begin
                    Inc(I1);
                    Skipped:=True;
                  end;
                while (I2<Para2.Count) and
                      (vo_is_hidden_para in TParaVarSym(Para2[I2]).VarOptions) do
                  begin
                    Inc(I2);
                    Skipped:=True;
                  end;
              end;
            if cpo_ignoreself in CPOptions then
              begin
                if (I1<Para1.Count) and
                   (vo_is_self in TParaVarSym(Para1[I1]).VarOptions) then
                  begin
                    Inc(I1);
                    Skipped:=True;
                  end;
                if (I2<Para2.Count) and
                   (vo_is_self in TParaVarSym(Para2[I2]).VarOptions) then
                  begin
                    Inc(I2);
                    Skipped:=True;
                  end;
              end;
            if cpo_ignoreframepointer in CPOptions then
              begin
                if (I1<Para1.Count) and
                   (vo_is_parentfp in TParaVarSym(Para1[I1]).VarOptions) then
                  begin
                    Inc(I1);
                    Skipped:=True;
                  end;
                if (I2<Para2.Count) and
                   (vo_is_parentfp in TParaVarSym(Para2[I2]).VarOptions) then
                  begin
                    Inc(I2);
                    Skipped:=True;
                  end;
              end;
          until not Skipped;
        end;

      var
        CurrPara1,
        CurrPara2 : TParaVarSym;
        EQ,LowestEq : TEqualType;
        HPD       : TProcDef;
        ConvType  : TConvertType;
        CDOptions : TCompareDefsOptions;
      begin
         Compare_Paras:=te_incompatible;
         CDOptions:=[cdo_parameter,cdo_check_operator,cdo_allow_variant,cdo_strict_undefined_check];
         { we need to parse the list from left-right so the
           not-default parameters are checked first }
         LowestEq:=High(TEqualType);
         I1:=0;
         I2:=0;
         SkipArgs;
         while (I1<Para1.Count) and (I2<Para2.Count) do
           begin
             EQ:=te_incompatible;

             CurrPara1:=TParaVarSym(Para1[I1]);
             CurrPara2:=TParaVarSym(Para2[I2]);

             { Unique types must match exact }
             if ((df_unique in CurrPara1.VarDef.DefOptions) or (df_unique in CurrPara2.VarDef.DefOptions)) and
                (CurrPara1.VarDef<>CurrPara2.VarDef) then
               Exit;

             { Handle hidden parameters separately, because self is
               defined as voidpointer for methodpointers }
             if (vo_is_hidden_para in CurrPara1.VarOptions) or
                (vo_is_hidden_para in CurrPara2.VarOptions) then
              begin
                { both must be hidden }
                if (vo_is_hidden_para in CurrPara1.VarOptions)<>(vo_is_hidden_para in CurrPara2.VarOptions) then
                  Exit;
                EQ:=te_exact;
                if (([vo_is_self,vo_is_vmt]*CurrPara1.VarOptions)=[]) and
                   (([vo_is_self,vo_is_vmt]*CurrPara2.VarOptions)=[]) then
                 begin
                   if not(cpo_ignorevarspez in CPOptions) and
                      (CurrPara1.VarSpez<>CurrPara2.VarSpez) then
                    Exit;
                   EQ:=Compare_Defs_Ext(CurrPara1.VarDef,CurrPara2.VarDef,NothingN,
                                        ConvType,HPD,CDOptions);
                 end
                else if ([vo_is_self,vo_is_vmt]*CurrPara1.VarOptions)<>
                         ([vo_is_self,vo_is_vmt]*CurrPara2.VarOptions) then
                   EQ:=te_incompatible;
              end
             else
              begin
                case ACP of
                  cp_value_equal_const :
                    begin
                       { this one is used for matching parameters from a call
                         statement to a procdef -> univ state can't be equal
                         in any case since the call statement does not contain
                         any information about that }
                       if (
                           not(cpo_ignorevarspez in CPOptions) and
                           (CurrPara1.VarSpez<>CurrPara2.VarSpez) and
                           ((CurrPara1.VarSpez in [vs_var,vs_out,vs_constref]) or
                            (CurrPara2.VarSpez in [vs_var,vs_out,vs_constref]))
                          ) then
                         Exit;
                       EQ:=Compare_Defs_Ext(CurrPara1.VarDef,CurrPara2.VarDef,NothingN,
                                            ConvType,HPD,CDOptions);
                    end;
                  cp_all :
                    begin
                       { used to resolve forward definitions -> headers must
                         match exactly, including the "univ" specifier }
                       if (not(cpo_ignorevarspez in CPOptions) and
                           (CurrPara1.VarSpez<>CurrPara2.VarSpez)) or
                          (CurrPara1.UnivPara<>CurrPara2.UnivPara) then
                         Exit;
                       EQ:=Compare_Defs_Ext(CurrPara1.VarDef,CurrPara2.VarDef,NothingN,
                                            ConvType,HPD,CDOptions);
                    end;
                  cp_procvar :
                    begin
                       if not(cpo_ignorevarspez in CPOptions) and
                          (CurrPara1.VarSpez<>CurrPara2.VarSpez) then
                         Exit;
                       { "univ" state doesn't matter here: from univ to non-univ
                          matches if the types are compatible (i.e., as usual),
                          from from non-univ to univ also matches if the types
                          have the same size (checked below) }
                       EQ:=Compare_Defs_Ext(CurrPara1.VarDef,CurrPara2.VarDef,NothingN,
                                            ConvType,HPD,CDOptions);
                       { Parameters must be at least equal otherwise the are incompatible }
                       if (EQ<te_equal) then
                         EQ:=te_incompatible;
                    end;
                  else
                    EQ:=Compare_Defs_Ext(CurrPara1.VarDef,CurrPara2.VarDef,NothingN,
                                         ConvType,HPD,CDOptions);
                 end;
               end;
              { check type }
              if EQ=te_incompatible then
                begin
                  { special case: "univ" parameters match if their size is equal }
                  if not(cpo_ignoreuniv in CPOptions) and
                     CurrPara2.UnivPara and
                     Is_Valid_Univ_Para_Type(CurrPara1.VarDef) and
                     (CurrPara1.VarDef.Size=CurrPara2.VarDef.Size) then
                    begin
                      { only pick as last choice }
                      EQ:=te_convert_l5;
                      if (ACP=cp_procvar) and
                         (cpo_warn_incompatible_univ in CPOptions) then
                        begin
                          { if the types may be passed in different ways by the
                            calling convention then this can lead to crashes
                            (note: not an exhaustive check, and failing this
                             this check does not mean things will crash on all
                             platforms) }
                          if PotentiallyIncompatibleUnivParas(CurrPara1.VarDef,CurrPara2.VarDef) then
                            Message2(type_w_procvar_univ_conflicting_para,CurrPara1.VarDef.TypeName,CurrPara2.VarDef.TypeName)
                        end;
                    end
                  else if (cpo_generic in CPOptions) then
                    begin
                      if Equal_GenFunc_ParaDefs(CurrPara1.VarDef,CurrPara2.VarDef,CurrPara1.Owner,CurrPara2.Owner) then
                        EQ:=te_exact
                      else
                        Exit;
                    end
                  else
                    Exit;
                end;
              if (EQ=te_equal) and
                  (cpo_generic in CPOptions) then
                begin
                  if Is_Open_Array(CurrPara1.VarDef) and
                      Is_Open_Array(CurrPara2.VarDef) then
                    begin
                      if Equal_GenFunc_ParaDefs(TArrayDef(CurrPara1.VarDef).ElementDef,TArrayDef(CurrPara2.VarDef).ElementDef,CurrPara1.Owner,CurrPara2.Owner) then
                        EQ:=te_exact;
                    end
                  else
                    { for the purpose of forward declarations two equal specializations
                      are considered as exactly equal }
                    if (df_specialization in TStoredDef(CurrPara1.VarDef).DefOptions) and
                        (df_specialization in TStoredDef(CurrPara2.VarDef).DefOptions) then
                      EQ:=te_exact;
                end;
              { open strings can never match exactly, since you cannot define }
              { a separate "open string" type -> we have to be able to        }
              { consider those as exact when resolving forward definitions.   }
              { The same goes for array of const. Open arrays are handled     }
              { already (if their element types match exactly, they are       }
              { considered to be an exact match)                              }
              { And also for "inline defined" function parameter definitions  }
              { (i.e., function types directly declared in a parameter list)  }
              if (Is_Array_Of_Const(CurrPara1.VarDef) or
                  Is_Open_String(CurrPara1.VarDef) or
                  ((CurrPara1.VarDef.Typ = ProcVarDef) and
                   not(Assigned(CurrPara1.VarDef.TypeSym)))) and
                 (EQ=te_equal) and
                 (cpo_openequalisexact in CPOptions) then
                EQ:=te_exact;
              if EQ<LowestEq then
                LowestEq:=EQ;
              { also check default value if both have it declared }
              if (cpo_comparedefaultvalue in CPOptions) then
                begin
                  if Assigned(CurrPara1.DefaultConstSym) and
                     Assigned(CurrPara2.DefaultConstSym) then
                    begin
                      if not Equal_ConstSym(TConstSym(CurrPara1.DefaultConstSym),TConstSym(CurrPara2.DefaultConstSym),True) then
                        Exit;
                    end
                  { cannot have that the second (= implementation) has a default value declared and the
                    other (interface) doesn't }
                  else if not Assigned(CurrPara1.DefaultConstSym) and Assigned(CurrPara2.DefaultConstSym) then
                    Exit;
                end;
              if not(cpo_compilerproc in CPOptions) and
                 not(cpo_rtlproc in CPOptions) and
                 Is_AnsiString(CurrPara1.VarDef) and
                 Is_AnsiString(CurrPara2.VarDef) and
                 (TStringDef(CurrPara1.VarDef).Encoding<>TStringDef(CurrPara2.VarDef).Encoding) and
                 ((TStringDef(CurrPara1.VarDef).Encoding=Globals.CP_NONE) or
                  (TStringDef(CurrPara2.VarDef).Encoding=Globals.CP_NONE)
                 ) then
                EQ:=te_convert_l1;
              if EQ<LowestEq then
                LowestEq:=EQ;
              Inc(I1);
              Inc(I2);
              SkipArgs;
           end;
         { when both lists are empty then the parameters are equal. Also
           when one list is empty and the other has a parameter with default
           value assigned then the parameters are also equal }
         if ((I1>=Para1.Count) and (I2>=Para2.Count)) or
            ((cpo_allowdefaults in CPOptions) and
             (((I1<Para1.Count) and Assigned(TParaVarSym(Para1[I1]).DefaultConstSym)) or
              ((I2<Para2.Count) and Assigned(TParaVarSym(Para2[I2]).DefaultConstSym)))) then
           Compare_Paras:=LowestEq;
      end;


    function Compare_RetType(Def1,Def2:TDef):TEqualType;
      var
        DoConv : TConvertType;
        PD : TProcDef;
      begin
        Result:=Compare_Defs_Ext(Def1,Def2,NothingN,DoConv,PD,[cdo_check_operator,cdo_allow_variant,cdo_strict_undefined_check]);
      end;


    function ProcToProcVarEqualInternal(Def1:TAbstractProcDef;Def2:TAbstractProcDef;CheckIncompatibleUniv,IgnoreSelf: Boolean):TEqualType;
      var
        EQ: TEqualType;
        po_comp: TProcOptions;
        pa_comp: TCompareParasOptions;
        Captured : TFPList;
        DstIsFuncRef : Boolean;
      begin
         ProcToProcVarEqualInternal:=te_incompatible;
         if not(Assigned(Def1)) or not(Assigned(Def2)) then
           Exit;
         { check for method pointer and local procedure pointer:
             a) anything but procvars can be assigned to blocks
             b) depending on their captured symbols anonymous functions can be
                assigned to global, method or nested procvars
             c) anything can be assigned to function references except for
                nested procvars (this is checked in the type conversion)
             d) if one is a procedure of object, the other also has to be one
                ("object static procedure" is equal to procedure as well)
                (except for block)
             e) if one is a pure address, the other also has to be one
                except if def1 is a global proc and def2 is a nested procdef
                (global procedures can be converted into nested procvars)
             f) if def1 is a nested procedure, then def2 has to be a nested
                procvar and def1 has to have the po_delphi_nested_cc option
                or does not use parentfp
             g) if def1 is a procvar, def1 and def2 both have to be nested or
                non-nested (we don't allow assignments from non-nested to
                nested procvars to make sure that we can still implement
                nested procvars using trampolines -- e.g., this would be
                necessary for LLVM or CIL as long as they do not have support
                for Delphi-style frame pointer parameter passing) }
         if Is_Block(Def2) or                                                           { a) }
            (po_anonymous in Def1.ProcOptions) or                                       { b) }
            (po_is_function_ref in Def2.ProcOptions) then                               { c) }
           { can't explicitly check against procvars here, because
             def1 may already be a procvar due to a proc_to_procvar;
             this is checked in the type conversion node itself -> ok }
         else if
            ((Def1.Is_MethodPointer and not (po_staticmethod in Def1.ProcOptions))<> { d) }
             (Def2.Is_MethodPointer and not (po_staticmethod in Def2.ProcOptions))) or
            ((Def1.Is_AddressOnly<>Def2.Is_AddressOnly) and         { e) }
             (Is_Nested_PD(Def1) or
              not Is_Nested_PD(Def2))) or
            ((Def1.Typ=ProcDef) and                                 { f) }
             Is_Nested_PD(Def1) and
             (not(po_delphi_nested_cc in Def1.ProcOptions) or
              not Is_Nested_PD(Def2))) or
            ((Def1.Typ=ProcVarDef) and                              { g) }
             (Is_Nested_PD(Def1)<>Is_Nested_PD(Def2))) then
           Exit;
         pa_comp:=[cpo_ignoreframepointer];
         if Is_Block(Def2) then
           Include(pa_comp,cpo_ignorehidden);
         if (po_anonymous in Def1.ProcOptions) or IgnoreSelf then
           Include(pa_comp,cpo_ignoreself);
         if CheckIncompatibleUniv then
           Include(pa_comp,cpo_warn_incompatible_univ);
         { check return value and options, methodpointer is already checked }
         po_comp:=[po_interrupt,po_iocheck,po_varargs];
         { check static only if we compare method pointers (and function
           references don't count as methodpointers here) }
         if Def1.Is_MethodPointer and
             (
               Def2.Is_MethodPointer and
               not (po_is_function_ref in Def2.ProcOptions)
             ) then
           Include(po_comp,po_staticmethod);
         if (m_delphi in CurrentSettings.ModeSwitches) then
           Exclude(po_comp,po_varargs);
         { for blocks, the calling convention doesn't matter because we have to
           generate a wrapper anyway }
         if ((po_is_block in Def2.ProcOptions) or
             (Def1.ProcCallOption=Def2.ProcCallOption)) and
            ((po_comp * Def1.ProcOptions)= (po_comp * Def2.ProcOptions)) and
            Equal_Defs(Def1.ReturnDef,Def2.ReturnDef) then
          begin
            { return equal type based on the parameters, but a proc->procvar
              is never exact, so map an exact match of the parameters to
              te_equal }
            EQ:=Compare_Paras(Def1.Paras,Def2.Paras,cp_procvar,pa_comp);
            if EQ=te_exact then
             EQ:=te_equal;
            if (EQ=te_equal) then
              begin
                { prefer non-nested to non-nested over non-nested to nested }
                if (Is_Nested_PD(Def1)<>Is_Nested_PD(Def2)) then
                  EQ:=te_convert_l1;
                { in case of non-block to block, we need a type conversion }
                if (po_is_block in Def1.ProcOptions) <> (po_is_block in Def2.ProcOptions) then
                  EQ:=te_convert_l1;
                { for anonymous functions check whether their captured symbols are
                  compatible with the target }
                if po_anonymous in Def1.ProcOptions then
                  begin
                    Captured:=nil;
                    if Def1.Typ=ProcDef then
                      Captured:=TProcDef(Def1).CapturedSyms
                    { def1.typ=procvardef can happen if someone uses procvar := @<anon func> }
                    else if Def1.Typ<>ProcVarDef then
                      InternalError(2021052601);
                    { a function reference can capture anything, but they're
                      rather expensive, so cheaper overloads are preferred }
                    DstIsFuncRef:=Assigned(Def2.Owner) and
                        Assigned(Def2.Owner.DefOwner) and
                        Is_FuncRef(TDef(Def2.Owner.DefOwner));
                    { if no symbol was captured an anonymous function is
                      compatible to all four types of function pointers, but we
                      might need to generate its code differently (e.g. get rid
                      of parentfp parameter for global functions); the order for
                      this is:
                        - procedure variable
                        - method variable
                        - function reference
                        - nested procvar }
                    if not Assigned(Captured) or (Captured.Count=0) then
                      begin
                        if Def1.Typ=ProcVarDef then
                          EQ:=te_incompatible
                        else if po_methodpointer in Def2.ProcOptions then
                          EQ:=te_convert_l2
                        else if po_delphi_nested_cc in Def2.ProcOptions then
                          EQ:=te_convert_l4
                        else if DstIsFuncRef then
                          EQ:=te_convert_l3
                        else
                          EQ:=te_convert_l1
                      end
                    { if only a Self was captured then the function is not
                      compatible to normal function pointers; the order for this
                      is:
                        - method variable
                        - function reference
                        - nested function }
                    else if (Captured.Count=1) and (TSym(PCapturedSymInfo(Captured[0])^.Sym).Typ in [LocalVarSym,ParaVarSym]) and
                         (vo_is_self in TAbstractVarSym(PCapturedSymInfo(Captured[0])^.Sym).VarOptions) then
                      begin
                        if po_methodpointer in Def2.ProcOptions then
                          EQ:=te_convert_l1
                        else if po_delphi_nested_cc in Def2.ProcOptions then
                          EQ:=te_convert_l3
                        else if DstIsFuncRef then
                          EQ:=te_convert_l2
                        else
                          EQ:=te_incompatible;
                      end
                    { otherwise it's compatible to nested function pointers and
                      function references }
                    else
                      begin
                        if DstIsFuncRef then
                          EQ:=te_convert_l1
                        else if po_delphi_nested_cc in Def2.ProcOptions then
                          EQ:=te_convert_l2
                        else
                          EQ:=te_incompatible;
                      end;
                  end
                else if Assigned(Def2.Owner) and
                    Assigned(Def2.Owner.DefOwner) and
                    Is_FuncRef(TDef(Def2.Owner.DefOwner)) then
                  begin
                    { consider assignment to a funcref a bit more expensive
                      then assigning it to a normal proc or method variable }
                    EQ:=te_convert_l2;
                  end;
              end;
            ProcToProcVarEqualInternal:=EQ;
          end;
      end;


    function Proc_To_ProcVar_Equal(Def1:TAbstractProcDef;Def2:TProcVarDef;CheckIncompatibleUniv: Boolean):TEqualType;
      begin
        Result:=ProcToProcVarEqualInternal(Def1,Def2,CheckIncompatibleUniv,False);
      end;


    function Proc_To_FuncRef_Conv(Def1:TAbstractProcDef;Def2:TObjectDef):TEqualType;
      var
        Invoke : TProcDef;
      begin
        Result:=te_incompatible;
        if not Assigned(Def1) or not Assigned(Def2) then
          Exit;
        if not Is_Invokable(Def2) then
          InternalError(2022011601);
        Invoke:=Get_Invoke_ProcDef(Def2);
        Result:=ProcToProcVarEqualInternal(Def1,Invoke,False,True);
      end;


    function Proc_To_FuncRef_Equal(Def1:TAbstractProcDef;Def2:TObjectDef):TEqualType;
      begin
        Result:=Proc_To_FuncRef_Conv(Def1,Def2);
        { as long as the two methods are considered convertible we consider the
          procdef and the function reference as equal }
        if Result>te_convert_operator then
          Result:=te_equal;
      end;


    function FuncRef_Equal(Def1,Def2:TObjectDef):TEqualType;
      var
        Invoke1,
        Invoke2 : TProcDef;
      begin
        if not Is_FuncRef(Def1) then
          InternalError(2022010714);
        if not Is_FuncRef(Def2) then
          InternalError(2022010715);
        Invoke1:=Get_Invoke_ProcDef(Def1);
        Invoke2:=Get_Invoke_ProcDef(Def2);
        Result:=ProcToProcVarEqualInternal(Invoke1,Invoke2,False,True);
        { as long as the two methods are considered convertible we consider the
          two function references as equal }
        if Result>te_convert_operator then
          Result:=te_equal;
      end;


    function Compatible_ChildMethod_ResultDef(ParentRetDef, ChildRetDef: TDef): Boolean;
      begin
        Compatible_ChildMethod_ResultDef :=
          (Equal_Defs(ParentRetDef,ChildRetDef)) or
          ((ParentRetDef.Typ=ObjectDef) and
           (ChildRetDef.Typ=ObjectDef) and
           Is_Class_Or_Interface_Or_ObjC(ParentRetDef) and
           Is_Class_Or_Interface_Or_ObjC(ChildRetDef) and
           (Def_Is_Related(TObjectDef(ChildRetDef),TObjectDef(ParentRetDef))))
      end;


    function Find_Implemented_Interface(ImplDef,IntfDef:TObjectDef):TImplementedInterface;
      var
        ImplIntf : TImplementedInterface;
        I : LongInt;
      begin
        if not Assigned(ImplDef) then
          InternalError(2013102301);
        if not Assigned(IntfDef) then
          InternalError(2013102302);
        Result:=nil;
        if not Assigned(ImplDef.ImplementedInterfaces) then
          Exit;
        for I:=0 to ImplDef.ImplementedInterfaces.Count-1 do
          begin
            ImplIntf:=TImplementedInterface(ImplDef.ImplementedInterfaces[I]);
            if Equal_Defs(ImplIntf.IntfDef,IntfDef) then
              begin
                Result:=ImplIntf;
                Exit;
              end;
          end;
      end;


    { true if prot implements d (or if they are equal) }
    function IsRelatedInterfaceMultiple(Prot:TObjectDef;D:TDef):Boolean;
      var
        I : LongInt;
      begin
        { objcprotocols have multiple inheritance, all protocols from which
          the current protocol inherits are stored in implementedinterfaces }
        Result:=Prot=D;
        if Result then
          Exit;

        for I:=0 to Prot.ImplementedInterfaces.Count-1 do
          begin
            Result:=IsRelatedInterfaceMultiple(TImplementedInterface(Prot.ImplementedInterfaces[I]).IntfDef,D);
            if Result then
              Exit;
          end;
      end;


    function ObjectDefIsRelated(CurDef:TObjectDef;OtherDef:TDef):Boolean;
      var
         RealSelf,
         HP : TObjectDef;
      begin
        if (OtherDef.Typ=ObjectDef) then
          OtherDef:=Find_Real_Class_Definition(TObjectDef(OtherDef),False);
        RealSelf:=Find_Real_Class_Definition(CurDef,False);
        if RealSelf=OtherDef then
          begin
            Result:=True;
            Exit;
          end;

        if (RealSelf.ObjectType in [odt_objcclass,odt_objcprotocol]) and
           (OtherDef=ObjC_IDType) then
          begin
            Result:=True;
            Exit;
          end;

        if (OtherDef.Typ<>ObjectDef) then
          begin
            Result:=False;
            Exit;
          end;

        if Is_FuncRef(RealSelf) and Is_FuncRef(OtherDef) then
          begin
            Result:=(FuncRef_Equal(TObjectDef(RealSelf),TObjectDef(OtherDef))>=te_equal);
            if Result then
              Exit;
          end;


        { Objective-C protocols support multiple inheritance. }
        if (RealSelf.ObjectType in [odt_objcprotocol]) then
          begin
            Result:=IsRelatedInterfaceMultiple(RealSelf,OtherDef);
            Exit;
          end;


        if (RealSelf.ObjectType in [odt_objcclass]) and
           (TObjectDef(OtherDef).ObjectType=CurDef.ObjectType) and
           ((oo_is_formal in CurDef.ObjectOptions) or
            (oo_is_formal in TObjectDef(OtherDef).ObjectOptions)) and
           (CurDef.ObjRealName^=TObjectDef(OtherDef).ObjRealName^) then
          begin
            Result:=True;
            Exit;
          end;

        HP:=RealSelf.ChildOf;
        while Assigned(HP) do
          begin
             if Equal_Defs(HP,OtherDef) then
               begin
                  Result:=True;
                  Exit;
               end;
             HP:=HP.ChildOf;
          end;
        Result:=False;
      end;


    function Def_Is_Related(CurDef,OtherDef:TDef):Boolean;
      begin
        if not Assigned(CurDef) then
          InternalError(2013102303);
        case CurDef.Typ of
          ObjectDef:
            Result:=ObjectDefIsRelated(TObjectDef(CurDef),OtherDef);
          else
            Result:=False;
        end;
      end;


    function Equal_GenFunc_ParaDefs(FWDef,CurrDef:TDef;FWPDST,CurrPDST:TSymTable): Boolean;
      begin
        Result:=False;
        { for open array parameters, typesym might not be assigned }
        if Assigned(FWDef.TypeSym) and (sp_generic_para in FWDef.TypeSym.SymOptions) and
           Assigned(CurrDef.TypeSym) and (sp_generic_para in CurrDef.TypeSym.SymOptions) and
            (FWDef.Owner=FWPDST) and
            (CurrDef.Owner=CurrPDST) then
          begin
            { the forward declaration may have constraints }
            if not (df_genconstraint in CurrDef.DefOptions) and (CurrDef.Typ=UndefinedDef) and
                ((FWDef.Typ=UndefinedDef) or (df_genconstraint in FWDef.DefOptions)) then
              Result:=True;
          end
      end;

end.
