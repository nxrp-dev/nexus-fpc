{
    Copyright (c) 2014 by Jonas Maebe, member of the Free Pascal development
    team

    This unit implements typed constant data elements at the assembler level

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
unit aasmcnst;

{$i fpcdefs.inc}

interface

uses
  CClasses,GlobType,ConstExp,WideStr,
  aasmbase,AAsmData,aasmtai,
  symconst,SymBase,symtype,symdef,SymSym;

type
   { typed const: integer/floating point/string/pointer/... const along with
     tdef info }
   TTypedConstKind = (tck_simple, tck_array, tck_record);

   { the type of the element and its def }
   TAIAbstractTypedConst = class abstract (TAI)
    private
     procedure setdef(def: TDef);
    protected
     fadetyp: TTypedConstKind;
     { the def of this element }
     fdef: TDef;
    public
     constructor create(_adetyp: TTypedConstKind; _def: TDef);
     property adetyp: TTypedConstKind read fadetyp;
     property def: TDef read fdef write setdef;
   end;

   { a simple data element; the value is stored as a tai }
   TAISimpleTypedConst = class(TAIAbstractTypedConst)
    private
     procedure setval(AValue: TAI);
    protected
     fval: TAI;
    public
     constructor create(_def: TDef; _val: TAI);
     destructor Destroy; override;
     property val: TAI read fval write setval;
   end;


   { an aggregate data element (record or array). Values are stored as an
     array of tsimpledataelement. }
   TAIAggregateTypedConst = class(TAIAbstractTypedConst)
    public type
     { iterator to walk over all individual items in the aggregate }
     TADEEnumerator = class(tobject)
      private
       fvalues: TFPObjectList;
       fvaluespos: LongInt;
       function getcurrent: TAIAbstractTypedConst;
      public
       constructor create(data: TAIAggregateTypedConst);
       function movenext: boolean;
       procedure reset;
       property current: TAIAbstractTypedConst read getcurrent;
     end;

    protected
     fvalues: TFPObjectList;
     fisstring: boolean;

     { converts the existing data to a single tai_string }
     procedure convert_to_string;
     procedure add_to_string(strtai: TAIString; othertai: TAI);
    public
     constructor create(_adetyp: TTypedConstKind; _fdef: TDef);
     function getenumerator: TADEEnumerator;
     procedure addvalue(val: TAIAbstractTypedConst); virtual;
     function valuecount: LongInt;
     procedure insertvaluebeforepos(val: TAIAbstractTypedConst; pos: LongInt);
     procedure replacevalueatpos(val: TAIAbstractTypedConst; pos: LongInt);
     { change the type to a record, regardless of how the aggregate was created;
       the size of the original type and the record must match }
     procedure changetorecord(_def: TRecordDef);
     procedure finish;
     destructor Destroy; override;
   end;


    TAsmLabOfs = record
      lab: TAsmLabel;
      ofs: asizeint;
    end;

   { flags for the finalisation of the typed const builder asmlist }
   TTCAsmListOption = (
     { the tasmsymbol is a tasmlabel }
     tcalo_is_lab,
     { start a new section (e.g., because we don't know the current section
       type) }
     tcalo_new_section,
     { this symbol is the start of a block of data that should be
       dead-stripable/smartlinkable; may imply starting a new section, but
       not necessarily (depends on what the platform requirements are) }
     tcalo_make_dead_strippable,
     { this symbol should never be removed by the linker }
     tcalo_no_dead_strip,
     { start of a vectorized but individually dead strippable list of elements,
       like the resource strings of a unit: they have to stay in this order,
       but individual elements can be removed }
     tcalo_vectorized_dead_strip_start,
     { item in the above list }
     tcalo_vectorized_dead_strip_item,
     { end of the above list }
     tcalo_vectorized_dead_strip_end,
     { symbol should be weakly defined }
     tcalo_weak,
     { symbol should be registered with the unit's public assembler symbols }
     tcalo_is_public_asm,
     { symbol should be declared with AT_DATA_FORCEINDIRECT }
     tcalo_data_force_indirect,
     { apply const_align() to the alignment, for user-defined data }
     tcalo_apply_constalign
   );
   TTCAsmListOptions = set of TTCAsmListOption;

   TTCDeadStripSectionSymbolOption = (
     { define the symbol }
     tcdssso_define,
     { register the assembler symbol either with the public or extern assembler
       symbols of the unit }
     tcdssso_register_asmsym,
     { use the indirect symbol }
     tcdssso_use_indirect
   );
  TTCDeadStripSectionSymbolOptions = set of TTCDeadStripSectionSymbolOption;

   { information about aggregates we are parsing }
   TAggregateInformation = class
    private
     fnextfieldname: TIDString;
     function getcuroffset: asizeint;
     procedure setnextfieldname(const AValue: TIDString);
    protected
     { type of the aggregate }
     fdef: TDef;
     { type of the aggregate }
     ftyp: TTypedConstKind;
     { symtable entry of the previously emitted field in case of a
       record/object (nil if none emitted yet), used to insert alignment bytes
       if necessary for variant records and objects }
     fcurfield,
     { field corresponding to the data that will be emitted next in case of a
       record/object (nil if not set), used to handle variant records and
       objects }
     fnextfield: TFieldVarSym;
     { similar as the fcurfield/fnextfield above, but instead of fieldvarsyms
       these are indices in the symlist of a recorddef that correspond to
       fieldvarsyms. These are used only for non-variant records, simply
       traversing the fields in order. We could use the above method here as
       well, but to find the next field we'd always have to use
       symlist.indexof(fcurfield), which would be quite slow. These have -1 as
       value if they're not set }
     fcurindex,
     fnextindex: LongInt;
     { anonymous record that is being built as we add constant data }
     fanonrecord: boolean;

     property curindex: LongInt read fcurindex write fcurindex;
     property nextindex: LongInt read fnextindex write fnextindex;
    public
     constructor create(_def: TDef; _typ: TTypedConstKind); virtual;
     { calculated padding bytes for alignment if needed, and add the def of the
       next field in case we are constructing an anonymous record }
     function prepare_next_field(nextfielddef: TDef): asizeint; virtual;

     property def: TDef read fdef;
     property typ: TTypedConstKind read ftyp;
     property curfield: TFieldVarSym read fcurfield write fcurfield;
     property nextfield: TFieldVarSym read fnextfield write fnextfield;
     property nextfieldname: TIDString write setnextfieldname;
     property curoffset: asizeint read getcuroffset;
     property anonrecord: boolean read fanonrecord write fanonrecord;
   end;
   TAggregateInformationClass = class of TAggregateInformation;

   { information about a placeholder element that has been added, and which has
     to be replaced later with a real data element }
   TTypedConstPlaceholder = class abstract
     def: TDef;
     constructor create(d: TDef);
     { same usage as ttai_typedconstbuilder.emit_tai }
     procedure replace(ai: TAI; d: TDef); virtual; abstract;
   end;

   { Warning: never directly create a ttai_typedconstbuilder instance,
     instead create a cai_typedconstbuilder (this class can be overridden) }
   TTAITypedConstBuilder = class abstract
    { class type to use when creating new aggregate information instances }
    protected class var
     CAggregateInformation: TAggregateInformationClass;
    private
     function getcurragginfo: TAggregateInformation;
     procedure set_next_field(AValue: TFieldVarSym);
     procedure set_next_field_name(const AValue: TIDString);
    protected
     { temporary list in which all data is collected }
     fasmlist: TAsmList;
     { options for the final asmlist }
     foptions: TTCAsmListOptions;

     { while queueing elements of a compound expression, this is the current
       offset in the top-level array/record }
     fqueue_offset: asizeint;
     fqueued_def: TDef;

     { array of caggregateinformation instances }
     faggregateinformation: TFPObjectList;

    { Support for generating data that is only referenced from the typed
      constant data that we are currently generated. Such data can all be put
      in the same dead-strippable unit, as it's either all included or none of
      it is included. This data can be spread over multiple kinds of sections
      though (e.g. rodata and rodata_no_rel), so per section keep track whether
      we already started a dead-strippable unit and if so, what the section
      name was (so that on platforms that perform the dead stripping based on
      sections, we put all data for one typed constant into a single section
      with the same name) }
    protected type
     TInternalDataSectionInfo = record
       secname: TSymStr;
       sectype: TAsmSectiontype;
     end;
    protected var
     { all internally generated data must be stored in the same list, as it must
       be consecutive (if it's spread over multiple lists, we don't know in
       which order they'll be concatenated) -> keep track of this list }
     finternal_data_asmlist: TAsmList;
     { kind of the last section we started in the finternal_data_asmlist, to
       avoid creating unnecessary section statements }
     finternal_data_current_section: TAsmSectiontype;
     { info about in which kinds of sections we have already emitted internal
       data, and what their names were }
     finternal_data_section_info: array of TInternalDataSectionInfo;

     { ensure that finalize_asmlist is called only once }
     fasmlist_finalized: boolean;
     { ensure that if it's vectorized dead strippable data, we called
       finalize_vectorized_dead_strip_asmlist instead of finalize_asmlist }
     fvectorized_finalize_called: boolean;

     { returns whether def must be handled as an aggregate on the current
       platform }
     function aggregate_kind(def: TDef): TTypedConstKind; virtual;
     { finalize the asmlist: add the necessary symbols etc }
     procedure finalize_asmlist(asmsym: TAsmSymbol; sym: TSym; def: TDef; section: TAsmSectiontype; const secname: TSymStr; alignment: shortint; const options: TTCAsmListOptions); virtual;
     procedure finalize_asmlist_add_indirect_sym(sym: TAsmSymbol; def: TDef; section: TAsmSectiontype; const secname: TSymStr; alignment: shortint; const options: TTCAsmListOptions); virtual;
     { prepare finalization (common for the default and overridden versions }
     procedure finalize_asmlist_prepare(const options: TTCAsmListOptions; var alignment: shortint);

     { functionality of the above for vectorized dead strippable sections }
     procedure finalize_vectorized_dead_strip_asmlist(sym: TSym; def: TDef; const basename, itemname: TSymStr; st: TSymTable; alignment: shortint; options: TTCAsmListOptions); virtual;

     { called by the public emit_tai() routines to actually add the typed
       constant data; the public ones also take care of adding extra padding
       bytes etc (by calling this one) }
     procedure do_emit_tai(p: TAI; def: TDef); virtual;

     { calls prepare_next_field() and adds the padding bytes in the current
       location }
     procedure pad_next_field(nextfielddef: TDef);

     { returns the index in finternal_data_section_info of the info for the
       section of type typ. Returns -1 if there is no such info yet }
     function get_internal_data_section_index(typ: TAsmSectiontype): LongInt;

     { get a start label for an internal data section (at the start of a
       potentially dead-strippable part) }
     function get_internal_data_section_start_label: TAsmLabel; virtual;
     { get a label in the middle of an internal data section (no dead
       stripping) }
     function get_internal_data_section_internal_label: TAsmLabel; virtual;
     { adds a new entry to current_module.linkorderedsymbols }
     procedure add_link_ordered_symbol(sym: TAsmSymbol; const secname: TSymStr); virtual;

     { easy access to the top level aggregate information instance }
     property curagginfo: TAggregateInformation read getcurragginfo;
    public
     constructor create(const options: TTCAsmListOptions); virtual;
     destructor Destroy; override;

    public
     { returns a builder for generating data that is only referenced by the
       typed constant date we are currently generating (e.g. string data for a
       pchar constant). Also returns the label that will be placed at the start
       of that data. list is the tasmlist to which the data will be added.
       secname can be empty to use a default }
     procedure start_internal_data_builder(list: TAsmList; sectype: TAsmSectiontype; const secname: TSymStr; out tcb: TTAITypedConstBuilder; out l: TAsmLabel);
     { finish a previously started internal data builder, including
       concatenating all generated data to the provided list and freeing the
       builder }
     procedure finish_internal_data_builder(var tcb: TTAITypedConstBuilder; l: TAsmLabel; def: TDef; alignment: LongInt);

     { add a simple constant data element (p) to the typed constant.
       def is the type of the added value }
     procedure emit_tai(p: TAI; def: TDef); virtual;
     { same as above, for a special case: when the def is a procvardef and we
       want to use it explicitly as a procdef (i.e., not as a record with a
       code and data pointer in case of a complex procvardef) }
     procedure emit_tai_procvar2procdef(p: TAI; pvdef: TProcVarDef); virtual;

    protected
     procedure maybe_emit_tail_padding(def: TDef); virtual;
     function emit_string_const_common(StringType: TStringType; len: asizeint; encoding: TStringEncoding; var startlab: TAsmLabel):TAsmLabOfs;
     function get_dynstring_def_for_type(StringType: TStringType; winlikewidestring: boolean): TStringDef;
     procedure begin_aggregate_internal(def: TDef; anonymous: boolean); virtual;
     procedure end_aggregate_internal(def: TDef; anonymous: boolean); virtual;
     { when building an anonymous record, we cannot immediately insert the
       alignment before it in case it's nested, since we only know the required
       alignment once all fields have been inserted -> mark the location before
       the anonymous record, and insert the alignment once it's finished }
     procedure mark_anon_aggregate_alignment; virtual; abstract;
     procedure insert_marked_aggregate_alignment(def: TDef); virtual; abstract;
     class function get_vectorized_dead_strip_section_symbol(const basename: string; st: TSymTable; options: TTCDeadStripSectionSymbolOptions; start: boolean): TAsmSymbol; virtual;
    public
     class function get_vectorized_dead_strip_custom_section_name(const basename: TSymStr; st: TSymTable; options: TTCAsmListOptions; out secname: TSymStr): boolean; virtual;
     { get the start/end symbol for a dead stripable vectorized section, such
       as the resourcestring data of a unit }
     class function get_vectorized_dead_strip_section_symbol_start(const basename: string; st: TSymTable; options: TTCDeadStripSectionSymbolOptions): TAsmSymbol; virtual;
     class function get_vectorized_dead_strip_section_symbol_end(const basename: string; st: TSymTable; options: TTCDeadStripSectionSymbolOptions): TAsmSymbol; virtual;
     { returns true if smartlinking of the dead stripable vectorized lists is supported }
     class function is_smartlink_vectorized_dead_strip: boolean; virtual;

     class function get_dynstring_rec_name(typ: TStringType; winlike: boolean; len: asizeint): TSymStr;
     class function get_dynstring_rec(typ: TStringType; winlike: boolean; len: asizeint): TRecordDef;
     { the datalist parameter specifies where the data for the string constant
       will be emitted (via an internal data builder)
       Note: data does not have to be #0-terminated (len specifies the length of the valid data) }
     function emit_ansistring_const(datalist: TAsmList; data: pchar; len: asizeint; encoding: TStringEncoding): TAsmLabOfs;
     function emit_unicodestring_const(datalist: TAsmList; data: TCompilerWideString; encoding: TStringEncoding; winlike: boolean):TAsmLabOfs;
     { emits a tasmlabofs as returned by emit_*string_const }
     procedure emit_string_offset(const ll: TAsmLabOfs; const strlength: LongInt; const st: TStringType; const winlikewidestring: boolean; const charptrdef: TDef);virtual;

     { emits a tasmlabofs as returned by begin_dynarray_const }
     procedure emit_dynarray_offset(const ll:TAsmLabOfs;const arrlength:asizeint;const arrdef:TArrayDef; const arrconstdatadef: TRecordDef);virtual;
     { starts a dynamic array constant so that its data can be emitted directly afterwards }
     function begin_dynarray_const(arrdef:TDef;var startlab:TAsmLabel;out arrlengthloc:TTypedConstPlaceholder):TAsmLabOfs;virtual;
     { ends a dynamic array constant by updating the count field; the arrlengthloc will be freed }
     function end_dynarray_const(arrdef:TDef;arrlength:asizeint;arrlengthloc:TTypedConstPlaceholder;llofs:TAsmLabOfs):TDef;virtual;

     { emit a shortstring constant, and return its def }
     function emit_shortstring_const(const str: shortstring): TDef;
     { emit a pchar string constant (the characters, not a pointer to them), and return its def;
       len does not include the terminating #0 (will be added) }
     function emit_pchar_const(str: pchar; len: PInt): TDef;
     { emit a guid constant }
     procedure emit_guid_const(const guid: TGUID);
     { emit a procdef constant }
     procedure emit_procdef_const(pd: TProcDef);
     { emit an ordinal constant }
     procedure emit_ord_const(value: int64; def: TDef);

     { emit a reference to a pooled shortstring constant }
     procedure emit_pooled_shortstring_const_ref(const str:shortstring);

     { begin a potential aggregate type. Must be called for any type
       that consists of multiple tai constant data entries, or that
       represents an aggregate at the Pascal level (a record, a non-dynamic
       array, ... }
     procedure maybe_begin_aggregate(def: TDef);
     { end a potential aggregate type. Must be paired with every
       maybe_begin_aggregate }
     procedure maybe_end_aggregate(def: TDef);
     { similar as above, but in case
        a) it's definitely a record
        b) the def of the record should be automatically constructed based on
           the types of the emitted fields

        packrecords: same as "packrecords x"
        recordalign: specify the (minimum) alignment of the start of the record
          (no equivalent in source code), used as an alternative for explicit
          align statements. Use "1" if it should be calculated based on the
          fields
        recordalignmin: same as "codealign recordmin=x"
        maxcrecordalign: specify maximum C record alignment (no equivalent in
          source code)
     }
     function begin_anonymous_record(const optionalname: string; PackRecords, recordalign, RecordAlignMin: shortint): TRecordDef; virtual;
     function end_anonymous_record: TRecordDef; virtual;

     { add a placeholder element at the current position that later can be
       filled in with the actual data (via ttypedconstplaceholder.replace)

       useful in case you have table preceded by the number of elements, and
       you count the elements while building the table }
     function emit_placeholder(def: TDef): TTypedConstPlaceholder; virtual; abstract;
     { Add a comment line
     }
     procedure emit_comment(const comment : string);
    protected
     { common code to check whether a placeholder can be added at the current
       position }
     procedure check_add_placeholder(def: TDef);
    public
     { The next group of routines are for constructing complex expressions.
       While parsing a typed constant these operators are encountered from
       outer to inner, so that is also the order in which they should be
       added to the queue. Only one queue can be active at a time. }
     { Init the queue. Gives an internalerror if a queue was already active }
     procedure queue_init(todef: TDef); virtual;
     { queue an array/string indexing operation (performs all range checking,
       so it doesn't have to be duplicated in all descendents). }
     procedure queue_vecn(def: TDef; const index: TConstExprInt); virtual;
     { queue a subscripting operation }
     procedure queue_subscriptn(def: TAbstractRecordDef; vs: TFieldVarSym); virtual;
     { queue indexing a record recursively via several field names. The fields
       are specified in the inner to outer order (i.e., def.field1.field2) }
     function queue_subscriptn_multiple_by_name(def: TAbstractRecordDef; const fields: array of TIDString): TDef;
     { queue a type conversion operation }
     procedure queue_typeconvn(fromdef, todef: TDef); virtual;
     { queue a pointer add operation }
     procedure queue_pointeraddn(def: TPointerDef; const index: TConstExprInt); virtual;
     { queue a pointer sub operation }
     procedure queue_pointersubn(def: TPointerDef; const index: TConstExprInt); virtual;
     { finalise the queue (so a new one can be created) and flush the
        previously queued operations, applying them in reverse order on a...}
     { ... procdef }
     procedure queue_emit_proc(pd: TProcDef); virtual;
     { ... staticvarsym }
     procedure queue_emit_staticvar(vs: TStaticVarSym); virtual;
     { ... labelsym }
     procedure queue_emit_label(l: TLabelSym); virtual;
     { ... constsym }
     procedure queue_emit_const(cs: TConstSym); virtual;
     { ... asmsym/asmlabel }
     procedure queue_emit_asmsym(sym: TAsmSymbol; def: TDef); virtual;
     { ... an ordinal constant }
     procedure queue_emit_ordconst(value: int64; def: TDef); virtual;
    protected
     { returns whether queue_init has been called without a corresponding
       queue_emit_* to finish it }
     function queue_is_active: boolean;
    public

     { finalize the internal asmlist (if necessary) and return it.
       This asmlist will be freed when the builder is destroyed, so add its
       contents to another list first. This property should only be accessed
       once all data has been added. }
     function get_final_asmlist(asmsym: TAsmSymbol; sym: TSym; def: TDef; section: TAsmSectiontype; const secname: TSymStr; alignment: LongInt): TAsmList;
     { same as above, passes nil as sym }
     function get_final_asmlist(asmsym: TAsmSymbol; def: TDef; section: TAsmSectiontype; const secname: TSymStr; alignment: LongInt): TAsmList; inline;
     function get_final_asmlist_vectorized_dead_strip(sym: TSym; def: TDef; const basename, itemname: TSymStr; st: TSymTable; alignment: LongInt): TAsmList;

     { returns the offset of the string data relative to ansi/unicode/widestring
       constant labels. On most platforms, this is 0 (with the header at a
       negative offset), but on some platforms such negative offsets are not
       supported this is equal to the header size }
     class function get_string_symofs(typ: TStringType; winlikewidestring: boolean): PInt; virtual;

     { returns the offset of the array data relative to dynamic array constant
       labels. On most platforms, this is 0 (with the header at a negative
       offset), but on some platforms such negative offsets are not supported
       and thus this is equal to the header size }
     class function get_dynarray_symofs:PInt;virtual;

     { set the fieldvarsym whose data we will emit next; needed
       in case of variant records, so we know which part of the variant gets
       initialised. Also in case of objects, because the fieldvarsyms are spread
       over the symtables of the entire inheritance tree }
     property next_field: TFieldVarSym write set_next_field;
     { set the name of the next field that will be emitted for an anonymous
       record (also if that field is a nested anonymous record) }
     property next_field_name: TIDString write set_next_field_name;
    protected
     { these ones always return the actual offset, called by the above (and
       overridden versions) }
     class function get_string_header_size(typ: TStringType; winlikewidestring: boolean): PInt;
     class function get_dynarray_header_size:PInt;
   end;
   TTAITypedConstBuilderClass = class of TTAITypedConstBuilder;

   TLowLevelAggregateInformation = class(TAggregateInformation)
    protected
     fanonrecmarker: TAI;
    public
     property anonrecmarker: TAI read fanonrecmarker write fanonrecmarker;
   end;

   TLowLevelTypedConstPlaceholder = class(TTypedConstPlaceholder)
     list: TAsmList;
     insertpos: TAI;
     constructor create(l: TAsmList; pos: TAI; d: TDef);
     procedure replace(ai: TAI; d: TDef); override;
   end;

   TTAILowLevelTypedConstBuilder = class(TTAITypedConstBuilder)
    protected
     procedure mark_anon_aggregate_alignment; override;
     procedure insert_marked_aggregate_alignment(def: TDef); override;
     procedure finalize_asmlist(asmsym: TAsmSymbol; sym: TSym; def: TDef; section: TAsmSectiontype; const secname: TSymStr; alignment: shortint; const options: TTCAsmListOptions); override;
    public
     { set the default value for caggregateinformation (= tlowlevelaggregateinformation) }
     class constructor classcreate;
     function emit_placeholder(def: TDef): TTypedConstPlaceholder; override;
   end;

   var
     CTAITypedConstBuilder: TTAITypedConstBuilderClass;

implementation

   uses
     CUtils,
     Verbose,Globals,Systems,
     FModule,
     SymTable,symutil,defutil;

{****************************************************************************
                       taggregateinformation
 ****************************************************************************}

    function TAggregateInformation.getcuroffset: asizeint;
      var
        field: TFieldVarSym;
      begin
        if Assigned(curfield) then
          result:=curfield.FieldOffset+curfield.vardef.size
        else if curindex<>-1 then
          begin
            field:=TFieldVarSym(TAbstractRecordDef(def).SymTable.SymList[curindex]);
            result:=field.FieldOffset+field.vardef.size
          end
        else
          result:=0
      end;


    procedure TAggregateInformation.setnextfieldname(const AValue: TIDString);
      begin
        if (fnextfieldname<>'') or
           not anonrecord then
          InternalError(2015071503);
        fnextfieldname:=AValue;
      end;


    constructor TAggregateInformation.create(_def: TDef; _typ: TTypedConstKind);
      begin
        fdef:=_def;
        ftyp:=_typ;
        fcurindex:=-1;
        fnextindex:=-1;
      end;


    function TAggregateInformation.prepare_next_field(nextfielddef: TDef): asizeint;
      var
        sym: TSym;
        currentoffset,nextoffset: asizeint;
        i: LongInt;
      begin
        { get the next field and its offset, and make that next field the current
          one }
        if Assigned(nextfield) then
          begin
            nextoffset:=nextfield.FieldOffset;
            currentoffset:=curoffset;
            curfield:=nextfield;
          end
        else
          begin
            { must set nextfield for unions and objects, as we cannot
              automatically detect the "next" field in that case }
            if ((def.typ=recorddef) and
                TRecordDef(def).IsUnion) or
               Is_Object(def) then
              InternalError(2014091202);
            { if we are constructing this record as data gets emitted, add a field
              for this data }
            if anonrecord then
              begin
                TRecordDef(def).Add_Field_By_Def(fnextfieldname,nextfielddef);
                fnextfieldname:='';
              end
            else if fnextfieldname<>'' then
              InternalError(2015071501);
            currentoffset:=curoffset;
            { find next field }
            i:=curindex;
            repeat
              inc(i);
              sym:=TSym(TAbstractRecordDef(def).SymTable.SymList[i]);
            until is_normal_fieldvarsym(sym);
            curfield:=TFieldVarSym(sym);
            nextoffset:=curfield.FieldOffset;
            curindex:=i;
          end;
        { need padding? }
        result:=nextoffset-currentoffset;
      end;


{****************************************************************************
                             ttypedconstplaceholder
 ****************************************************************************}

    constructor TTypedConstPlaceholder.create(d: TDef);
      begin
        def:=d;
      end;

{****************************************************************************
                            tai_abstracttypedconst
 ****************************************************************************}

   procedure TAIAbstractTypedConst.setdef(def: TDef);
     begin
       { should not be changed, rewrite the calling code if this happens }
       if Assigned(fdef) then
         InternalError(2014080203);
       fdef:=def;
     end;

   constructor TAIAbstractTypedConst.create(_adetyp: TTypedConstKind; _def: TDef);
     begin
       inherited create;
       typ:=ait_typedconst;
       fadetyp:=_adetyp;
       fdef:=_def;
     end;


{****************************************************************************
                                tai_simpletypedconst
 ****************************************************************************}

    procedure TAISimpleTypedConst.setval(AValue: TAI);
      begin
        fval:=AValue;
      end;


   constructor TAISimpleTypedConst.create(_def: TDef; _val: TAI);
     begin
       inherited create(tck_simple,_def);
       fval:=_val;
     end;


   destructor TAISimpleTypedConst.Destroy;
     begin
       fval.free;
       fval := nil;
       inherited Destroy;
     end;


{****************************************************************************
              tai_aggregatetypedconst.tadeenumerator
 ****************************************************************************}

   constructor TAIAggregateTypedConst.TADEEnumerator.create(data: TAIAggregateTypedConst);
     begin
       fvalues:=data.fvalues;
       fvaluespos:=-1;
     end;


   function TAIAggregateTypedConst.TADEEnumerator.getcurrent: TAIAbstractTypedConst;
     begin
       result:=TAIAbstractTypedConst(fvalues[fvaluespos]);
     end;


   function TAIAggregateTypedConst.TADEEnumerator.movenext: boolean;
     begin
       if fvaluespos<pred(fvalues.count) then
         begin
           inc(fvaluespos);
           result:=true
         end
       else
         result:=false;
     end;


   procedure TAIAggregateTypedConst.TADEEnumerator.reset;
     begin
       fvaluespos:=0
     end;


{****************************************************************************
                            tai_aggregatetypedconst
 ****************************************************************************}

   procedure TAIAggregateTypedConst.convert_to_string;
     var
       ai: TAIAbstractTypedConst;
       newstr: TAIString;
     begin
       newstr:=TAIString.Create('');
       for ai in self do
          begin
            if ai.adetyp<>tck_simple then
              InternalError(2014070103);
            add_to_string(newstr,TAISimpleTypedConst(ai).val);
            ai.free; // no nil needed
          end;
       fvalues.count:=0;
       { the "nil" def will be replaced with an array def of the appropriate
         size once we're finished adding data, so we don't create intermediate
         arraydefs all the time }
       fvalues.add(TAISimpleTypedConst.create(nil,newstr));
     end;

   procedure TAIAggregateTypedConst.add_to_string(strtai: TAIString; othertai: TAI);
     var
       len1,len2,lent : Integer;
       lother_string : TAIString absolute othertai;
     begin
       case othertai.typ of
         ait_string:
           begin
             len1:=strtai.len;
             len2:=lother_string.len;
             lent:=len1+len2;
             SetLength(strtai.str,lent);
             move(lother_string.str[0],strtai.str[len1],len2);
           end;
         ait_const:
           begin
             if TAIConst(othertai).size<>1 then
               InternalError(2014070101);
             len1:=length(strtai.str);
             SetLength(strtai.str,len1+1);
             strtai.str[len1]:=ansichar(TAIConst(othertai).value);
           end;
         else
           InternalError(2014070102);
       end;
     end;


   constructor TAIAggregateTypedConst.create(_adetyp: TTypedConstKind; _fdef: TDef);
     begin
       inherited;
       fisstring:=false;
       fvalues:=TFPObjectList.create(true);
     end;


   function TAIAggregateTypedConst.getenumerator: TADEEnumerator;
     begin
       result:=TADEEnumerator.create(self);
     end;


   procedure TAIAggregateTypedConst.addvalue(val: TAIAbstractTypedConst);
     begin
       { merge string constants and ordinal constants added in an array of
         char, to unify the length and the string data }
       if fisstring or
          ((val.adetyp=tck_simple) and
           (TAISimpleTypedConst(val).val.typ=ait_string)) then
         begin
           if not fisstring and
              (fvalues.count>0) then
             convert_to_string;
           fisstring:=true;
           case fvalues.count of
             0: fvalues.add(val);
             1:
               begin
                 add_to_string(TAIString(TAISimpleTypedConst(fvalues[0]).val),TAISimpleTypedConst(val).val);
                 val.free;
                 val := nil;
               end
             else
               InternalError(2014070104);
           end;
         end
       else
         fvalues.add(val);
     end;


   function TAIAggregateTypedConst.valuecount: LongInt;
     begin
       result:=fvalues.count;
     end;


   procedure TAIAggregateTypedConst.insertvaluebeforepos(val: TAIAbstractTypedConst; pos: LongInt);
     begin
       fvalues.insert(pos,val);
     end;


   procedure TAIAggregateTypedConst.replacevalueatpos(val: TAIAbstractTypedConst; pos: LongInt);
     begin
       { since fvalues owns its elements, it will automatically free the old value }
       fvalues[pos]:=val;
     end;


   procedure TAIAggregateTypedConst.changetorecord(_def: TRecordDef);
     begin
       { must be a record of the same size as the current data }
       if Assigned(fdef) and
          (fdef.size<>_def.size) then
         InternalError(2015122402);
       fdef:=_def;
       fadetyp:=tck_record;
     end;


   procedure TAIAggregateTypedConst.finish;
     var
       lString : TAIString;
       len : integer;
     begin
       if fisstring then
         begin
           { set the def: an array of char with the same length as the string
             data }
           if fvalues.count<>1 then
             InternalError(2014070105);
           lString:=TAIString(TAISimpleTypedConst(fvalues[0]).val);
           len:=lString.len;
           TAISimpleTypedConst(fvalues[0]).fdef:=CArrayDef.getreusable(CAnsiCharType,len);
         end;
     end;


   destructor TAIAggregateTypedConst.Destroy;
     begin
       fvalues.free;
       fvalues := nil;
       inherited Destroy;
     end;


 {*****************************************************************************
                              ttai_typedconstbuilder
 *****************************************************************************}

   function TTAITypedConstBuilder.getcurragginfo: TAggregateInformation;
     begin
       if Assigned(faggregateinformation) and
          (faggregateinformation.count>0) then
         result:=TAggregateInformation(faggregateinformation[faggregateinformation.count-1])
       else
         result:=nil;
     end;


   procedure TTAITypedConstBuilder.set_next_field(AValue: TFieldVarSym);
     var
       info: TAggregateInformation;
     begin
       info:=curagginfo;
       if not Assigned(info) then
         InternalError(2014091206);
       info.nextfield:=AValue;
     end;


    procedure TTAITypedConstBuilder.set_next_field_name(const AValue: TIDString);
      var
        info: TAggregateInformation;
      begin
        info:=curagginfo;
        if not Assigned(info) then
          InternalError(2015071502);
        info.nextfieldname:='$'+AValue;
      end;


   procedure TTAITypedConstBuilder.pad_next_field(nextfielddef: TDef);
     var
       fillbytes: asizeint;
     begin
       fillbytes:=curagginfo.prepare_next_field(nextfielddef);
       while fillbytes>0 do
         begin
           do_emit_tai(TAIConst.create_8bit(0),U8IntType);
           dec(fillbytes);
         end;
     end;


   function TTAITypedConstBuilder.get_internal_data_section_index(typ: TAsmSectiontype): LongInt;
     begin
       { avoid wrong warning by -Oodfa }
       result:=-1;
       for result:=low(finternal_data_section_info) to high(finternal_data_section_info) do
         if finternal_data_section_info[result].sectype=typ then
           exit;
       result:=-1;
     end;


   function TTAITypedConstBuilder.get_internal_data_section_start_label: TAsmLabel;
     begin
       { on Darwin, dead code/data stripping happens based on non-temporary
         labels (any label that doesn't start with "L" -- it doesn't have
         to be global) }
       if TargetInfo.system in systems_darwin then
         CurrentAsmData.getstaticdatalabel(result)
       else if create_smartlink_library then
         CurrentAsmData.getglobaldatalabel(result)
       else
         CurrentAsmData.getlocaldatalabel(result);
     end;


   function TTAITypedConstBuilder.get_internal_data_section_internal_label: TAsmLabel;
     begin
       if create_smartlink_library then
         { all labels need to be global in case they're in another object }
         CurrentAsmData.getglobaldatalabel(result)
       else
         { no special requirement for the label -> just get a local one }
         CurrentAsmData.getlocaldatalabel(result);
     end;


   procedure TTAITypedConstBuilder.add_link_ordered_symbol(sym: TAsmSymbol; const secname: TSymStr);
     begin
       CurrentModule.LinkOrderedSymbols.concat(sym.Name);
     end;


   function TTAITypedConstBuilder.aggregate_kind(def: TDef): TTypedConstKind;
     begin
       if (def.typ in [recorddef,filedef,variantdef]) or
          Is_Object(def) or
          ((def.typ=procvardef) and
           not TProcVarDef(def).Is_AddressOnly and
           not is_block(def)) then
         result:=tck_record
       else if ((def.typ=arraydef) and
           not is_dynamic_array(def)) or
          ((def.typ=setdef) and
           not is_smallset(def)) or
          is_shortstring(def) then
         result:=tck_array
       else
         result:=tck_simple;
     end;


   procedure TTAITypedConstBuilder.finalize_asmlist_prepare(const options: TTCAsmListOptions; var alignment: shortint);
     begin
       if tcalo_apply_constalign in options then
         alignment:=Const_Align(alignment);
       { have we finished all aggregates? }
       if (getcurragginfo<>nil) and
          { in case of syntax errors, the aggregate may not have been finished }
          (ErrorCount=0) then
         InternalError(2015072301);

       { must call finalize_vectorized_dead_strip_asmlist() instead }
       if (([tcalo_vectorized_dead_strip_start,
             tcalo_vectorized_dead_strip_item,
             tcalo_vectorized_dead_strip_end]*options)<>[]) and
          not fvectorized_finalize_called then
         InternalError(2015110602);
     end;


   procedure TTAITypedConstBuilder.finalize_asmlist(asmsym: TAsmSymbol; sym: TSym; def: TDef; section: TAsmSectiontype; const secname: TSymStr; alignment: shortint; const options: TTCAsmListOptions);
     var
       prelist: TAsmList;
     begin
       finalize_asmlist_prepare(options, alignment);
       prelist:=TAsmList.create;
       { only now add items based on the symbolname, because it may be
         modified by the "section" specifier in case of a typed constant }

       { both in case the data should be dead strippable and never dead
         stripped, it should be in a separate section (so this property doesn't
         affect other data) }
       if ([tcalo_no_dead_strip,tcalo_make_dead_strippable]*options)<>[] then
         begin
           maybe_new_object_file(prelist);
           { we always need a new section here, since if we started a new
             object file then we have to say what the section is, and otherwise
             we need a new section because that's how the dead stripping works }
           new_section(prelist,section,secname,alignment);
         end
       else if tcalo_new_section in options then
         new_section(prelist,section,secname,alignment)
       else
         prelist.concat(CAIAlign.Create(alignment));

       { On Darwin, use .reference to ensure the data doesn't get dead stripped.
         On other platforms, the data must be in the .fpc section (which is
         kept via the linker script) }
       if tcalo_no_dead_strip in options then
         begin
           if (TargetInfo.system in systems_darwin) then
             begin
              { Objective-C section declarations contain "no_dead_strip"
                attributes if none of their symbols need to be stripped -> don't
                add extra ".reference" statement for their symbols (gcc/clang
                don't either) }
              if not(section in [low(TObjCAsmSectionType)..high(TObjCAsmSectionType)]) then
                prelist.concat(TAIDirective.Create(asd_reference,asmsym.name))
             end
           else if not(section in [sec_fpc,sec_note]) then
             InternalError(2015101402);
         end;

       if not(tcalo_is_lab in options) then
         if asmsym.bind=AB_LOCAL then
           prelist.concat(TAISymbol.Create(asmsym,0))
         else
           prelist.concat(TAISymbol.Create_Global(asmsym,0))
       else
         prelist.concat(TAILabel.Create(TAsmLabel(asmsym)));

       { Newly referenced symbol }
       asmsym.increfs;

       if tcalo_weak in options then
         prelist.concat(TAIDirective.Create(asd_weak_definition,asmsym.name));
       { insert the symbol information before the data }
       fasmlist.InsertList(prelist);
       { end of the symbol }
       fasmlist.concat(TAISymbolEnd.Createname(asmsym.name));
       { free the temporary list }
       prelist.free;
       prelist := nil;
     end;


   procedure TTAITypedConstBuilder.finalize_asmlist_add_indirect_sym(sym: TAsmSymbol; def: TDef; section: TAsmSectiontype; const secname: TSymStr; alignment: shortint; const options: TTCAsmListOptions);
     var
       ptrdef : TDef;
       symind : TAsmSymbol;
       indtcb : TTAITypedConstBuilder;
       indsecname : TSymStr;
     begin
       if (tcalo_data_force_indirect in options) and
          (sym.bind in [AB_GLOBAL,AB_COMMON]) and
          (sym.typ=AT_DATA) then
         begin
           ptrdef:=CPointerDef.getreusable(def);
           symind:=CurrentAsmData.DefineAsmSymbol(sym.name,AB_INDIRECT,AT_DATA,ptrdef);
           { reuse the section if possible }
           if section=sec_rodata then
             indsecname:=secname
           else
             indsecname:=lower(symind.name);
           indtcb:=CTAITypedConstBuilder.create([tcalo_new_section,tcalo_make_dead_strippable]);
           indtcb.emit_tai(TAIConst.create_sym_offset(sym,0),ptrdef);
           CurrentAsmData.asmlists[al_indirectglobals].ConcatList(indtcb.get_final_asmlist(
             symind,
             ptrdef,
             sec_rodata,
             indsecname,
             ptrdef.alignment));

           symind.increfs;

           indtcb.free;
           indtcb := nil;
           if not (TargetInfo.system in systems_indirect_var_imports) then
             CurrentModule.Add_Public_AsmSym(symind.name,AB_INDIRECT,AT_DATA);
         end;
     end;


   procedure TTAITypedConstBuilder.finalize_vectorized_dead_strip_asmlist(sym: TSym; def: TDef; const basename, itemname: TSymStr; st: TSymTable; alignment: shortint; options: TTCAsmListOptions);
     var
       asmsym: TAsmSymbol;
       secname: TSymStr;
       sectype: TAsmSectiontype;
       asmtype : TAsmsymtype;
       customsecname: boolean;
       dsopts : TTCDeadStripSectionSymbolOptions;
     begin
       fvectorized_finalize_called:=true;
       asmsym:=nil;
       customsecname:=get_vectorized_dead_strip_custom_section_name(basename,st,options,secname);
       if customsecname then
         sectype:=sec_user
       else
         sectype:=sec_data;
       dsopts:=[tcdssso_define];
       if tcalo_is_public_asm in options then
         include(dsopts,tcdssso_register_asmsym);
       if tcalo_data_force_indirect in options then
         include(dsopts,tcdssso_use_indirect);
       if tcalo_vectorized_dead_strip_start in options then
         begin
           { the start and end names are predefined }
           if itemname<>'' then
             InternalError(2015110801);
           asmsym:=get_vectorized_dead_strip_section_symbol_start(basename,st,dsopts);
           if not customsecname then
             secname:=Make_MangledName(basename,st,'1_START');
         end
       else if tcalo_vectorized_dead_strip_end in options then
         begin
           { the start and end names are predefined }
           if itemname<>'' then
             InternalError(2015110802);
           asmsym:=get_vectorized_dead_strip_section_symbol_end(basename,st,dsopts);
           if not customsecname then
             secname:=Make_MangledName(basename,st,'3_END');
         end
       else if tcalo_vectorized_dead_strip_item in options then
         begin
           if tcalo_data_force_indirect in options then
             asmtype:=AT_DATA_FORCEINDIRECT
           else
             asmtype:=AT_DATA;
           asmsym:=CurrentAsmData.DefineAsmSymbol(Make_MangledName(basename,st,itemname),AB_GLOBAL,asmtype,def);
           if tcalo_is_public_asm in options then
             CurrentModule.Add_Public_AsmSym(asmsym);
           if not customsecname then
             secname:=Make_MangledName(basename,st,'2_'+itemname);
         end;
       add_link_ordered_symbol(asmsym,secname);
       if is_smartlink_vectorized_dead_strip then
         options:=options+[tcalo_new_section,tcalo_make_dead_strippable]
       else
         begin
           { if smartlinking of vectorized lists is not supported,
             put the whole list into a single section. }
           options:=options-[tcalo_new_section,tcalo_make_dead_strippable];
           if tcalo_vectorized_dead_strip_start in options then
             include(options,tcalo_new_section);
         end;
       finalize_asmlist(asmsym,sym,def,sectype,secname,alignment,options);
     end;


   procedure TTAITypedConstBuilder.do_emit_tai(p: TAI; def: TDef);
     begin
       { by default we don't care about the type }
       fasmlist.concat(p);
     end;


   function TTAITypedConstBuilder.get_final_asmlist(asmsym: TAsmSymbol; sym: TSym; def: TDef; section: TAsmSectiontype; const secname: TSymStr; alignment: LongInt): TAsmList;
     begin
       if not fasmlist_finalized then
         begin
           finalize_asmlist(asmsym,sym,def,section,secname,alignment,foptions);
           finalize_asmlist_add_indirect_sym(asmsym,def,section,secname,alignment,foptions);
           fasmlist_finalized:=true;
         end;
       result:=fasmlist;
     end;



   function TTAITypedConstBuilder.get_final_asmlist(asmsym: TAsmSymbol; def: TDef; section: TAsmSectiontype; const secname: TSymStr; alignment: LongInt): TAsmList; inline;
     begin
       result:=get_final_asmlist(asmsym,nil,def,section,secname,alignment);
     end;


   function TTAITypedConstBuilder.get_final_asmlist_vectorized_dead_strip(sym: TSym; def: TDef; const basename, itemname: TSymStr; st: TSymTable; alignment: LongInt): TAsmList;
     begin
       if not fasmlist_finalized then
         begin
           finalize_vectorized_dead_strip_asmlist(sym,def,basename,itemname,st,alignment,foptions);
           fasmlist_finalized:=true;
         end;
       result:=fasmlist;
     end;


   class function TTAITypedConstBuilder.get_string_symofs(typ: TStringType; winlikewidestring: boolean): PInt;
     begin
       { darwin's linker does not support negative offsets }
       if not(TargetInfo.system in systems_darwin) and
          { it seems that clang's assembler has a bug with the ADRP instruction... }
          (TargetInfo.system<>system_aarch64_win64) then
         result:=0
       else
         result:=get_string_header_size(typ,winlikewidestring);
     end;


   class function TTAITypedConstBuilder.get_dynarray_symofs:PInt;
     begin
       { darwin's linker does not support negative offsets }
       if not (TargetInfo.system in systems_darwin) and
          { it seems that clang's assembler has a bug with the ADRP instruction... }
          (TargetInfo.system<>system_aarch64_win64) then
         result:=0
       else
         result:=get_dynarray_header_size;
     end;


   class function TTAITypedConstBuilder.get_string_header_size(typ: TStringType; winlikewidestring: boolean): PInt;
     var
       ansistring_header_size: PInt;
       unicodestring_header_size: PInt;
     begin
       ansistring_header_size:=
         { encoding }
         2 +
         { elesize }
         2 +
         { reference count }
{$ifdef cpu64bitaddr}
         S32IntType.size +
{$else !cpu64bitaddr}
         SizeSIntType.size +
{$endif !cpu64bitaddr}
         { length }
         SizeSIntType.size;
       unicodestring_header_size:=ansistring_header_size;
       case typ of
         st_ansistring:
           result:=ansistring_header_size;
         st_unicodestring:
           result:=unicodestring_header_size;
         st_widestring:
           if winlikewidestring then
             result:=0
           else
             result:=unicodestring_header_size;
         else
           result:=0;
       end;
     end;


   class function TTAITypedConstBuilder.get_dynarray_header_size:PInt;
     begin
       result:=
         { reference count }
         PtrSIntType.size +
         { high value }
         SizeSIntType.size;
     end;


   constructor TTAITypedConstBuilder.create(const options: TTCAsmListOptions);
     begin
       inherited create;
       fasmlist:=TAsmList.create;
       foptions:=options;
       { queue is empty }
       fqueue_offset:=low(fqueue_offset);
       finternal_data_current_section:=sec_none;
     end;


   destructor TTAITypedConstBuilder.Destroy;
     begin
       { the queue should have been flushed if it was used
         (but if there were errors, we may have aborted before that happened) }
       if (fqueue_offset<>low(fqueue_offset)) and
          (ErrorCount=0) then
         InternalError(2014062901);
       faggregateinformation.free;
       faggregateinformation := nil;
       fasmlist.free;
       fasmlist := nil;
       inherited Destroy;
     end;


   procedure TTAITypedConstBuilder.start_internal_data_builder(list: TAsmList; sectype: TAsmSectiontype; const secname: TSymStr; out tcb: TTAITypedConstBuilder; out l: TAsmLabel);
     var
       options: TTCAsmListOptions;
       foundsec: LongInt;
     begin
       { you can't start multiple concurrent internal data builders for the
         same tcb, finish the first before starting another }
       if finternal_data_current_section<>sec_none then
         InternalError(2016082801);
       { we don't know what was previously added to this list, so always add
         a section header. We'll use the same section name in case multiple
         items are added to the same kind of section (rodata, rodata_no_rel,
         ...), so that everything will still end up in the same section even if
         there are multiple section headers }
       options:=[tcalo_is_lab,tcalo_new_section];
       finternal_data_current_section:=sectype;
       l:=nil;
       { did we already create a section of this type for the internal data of
         this builder? }
       foundsec:=get_internal_data_section_index(sectype);
       if foundsec=-1 then
         begin
           { we only need to start a dead-strippable section of data at the
             start of the first subsection of this kind for this block.

             exception: if dead stripping happens based on objects/libraries,
             then we only have to create a new object file for the first
             internal data section of any kind (all the rest will simply be put
             in the same object file) }
           if create_smartlink then
             begin
               if not create_smartlink_library or
                  (length(finternal_data_section_info)=0) then
                 include(options,tcalo_make_dead_strippable);
               { on Darwin, dead code/data stripping happens based on non-
                 temporary labels (any label that doesn't start with "L" -- it
                 doesn't have to be global) -> add a non-temporary lobel at the
                 start of every kind of subsection created in this builder }
               if TargetInfo.system in systems_darwin then
                 l:=get_internal_data_section_start_label;
             end;
           foundsec:=length(finternal_data_section_info);
           SetLength(finternal_data_section_info,foundsec+1);
           finternal_data_section_info[foundsec].sectype:=sectype;
         end;
       if not Assigned(finternal_data_asmlist) and
          (cs_create_smart in CurrentSettings.ModuleSwitches) then
         begin
           l:=get_internal_data_section_start_label;
           { the internal data list should only be assigned by this routine,
             the first time that an internal data block is started }
           if not Assigned(list) or
              Assigned(finternal_data_asmlist) then
             InternalError(2015032101);
           finternal_data_asmlist:=list;
         end
       { all internal data for this tcb must go to the same list (otherwise all
         data we want to add to the dead-strippable block is not guaranteed to
         be sequential and e.g. in the same object file in case of library-based
         dead stripping) }
       else if (Assigned(finternal_data_asmlist) and
           (list<>finternal_data_asmlist)) or
           not Assigned(list) then
         InternalError(2015032102);
       finternal_data_asmlist:=list;
       if not Assigned(l) then
         l:=get_internal_data_section_internal_label;
       { first section of this kind -> set name }
       if finternal_data_section_info[foundsec].secname='' then
         if secname='' then
           finternal_data_section_info[foundsec].secname:=l.Name
         else
           finternal_data_section_info[foundsec].secname:=secname
       { if the name is specified multiple times, it must match }
       else if (secname<>'') and
               (finternal_data_section_info[foundsec].secname<>secname) then
         InternalError(2015032401);
       tcb:=TTAITypedConstBuilderClass(classtype).create(options);
     end;


   procedure TTAITypedConstBuilder.finish_internal_data_builder(var tcb: TTAITypedConstBuilder; l: TAsmLabel; def: TDef; alignment: LongInt);
     begin
       finternal_data_asmlist.ConcatList(tcb.get_final_asmlist(l,def,
         finternal_data_current_section,
         finternal_data_section_info[get_internal_data_section_index(finternal_data_current_section)].secname,
         alignment));
       tcb.free;
       tcb:=nil;
       finternal_data_current_section:=sec_none;
     end;


   procedure TTAITypedConstBuilder.emit_tai(p: TAI; def: TDef);
     var
       kind: TTypedConstKind;
       info: TAggregateInformation;
     begin
       { these elements can be aggregates themselves, e.g. a shortstring can
         be emitted as a series of bytes and char arrays }
       kind:=aggregate_kind(def);
       info:=curagginfo;
       if (kind<>tck_simple) and
          (not Assigned(info) or
           (info.typ<>kind)) then
         InternalError(2014091001);
       { if we're emitting a record, handle the padding bytes, and in case of
         an anonymous record also add the next field }
       if Assigned(info) then
         begin
           { queue_init already adds padding }
           if not queue_is_active and
               (Is_Record(info.def) or
                Is_Object(info.def)) and
              { may add support for these later }
              not is_packed_record_or_object(info.def) then
             pad_next_field(def);
         end;
       { emit the data }
       do_emit_tai(p,def);
     end;


   procedure TTAITypedConstBuilder.emit_tai_procvar2procdef(p: TAI; pvdef: TProcVarDef);
     begin
       { nothing special by default, since we don't care about the type }
       emit_tai(p,pvdef);
     end;


   procedure TTAITypedConstBuilder.maybe_emit_tail_padding(def: TDef);
     var
       info: TAggregateInformation;
       fillbytes: asizeint;
     begin
       info:=curagginfo;
       if not Assigned(info) then
         InternalError(2014091002);
       if def<>info.def then
         InternalError(2014091205);
       if (Is_Record(def) or
           Is_Object(def)) and
          not is_packed_record_or_object(def) then
         begin
           fillbytes:=def.size-info.curoffset;
           while fillbytes>0 do
             begin
               do_emit_tai(TAIConst.Create_8bit(0),U8IntType);
               dec(fillbytes)
             end;
         end;
     end;


   function TTAITypedConstBuilder.emit_string_const_common(StringType: TStringType; len: asizeint; encoding: TStringEncoding; var startlab: TAsmLabel): TAsmLabOfs;
     var
       string_symofs: asizeint;
       charptrdef: TDef;
       EleSize: word;
     begin
       result.lab:=startlab;
       result.ofs:=0;
       { pack the data, so that we don't add unnecessary null bytes after the
         constant string }
       begin_anonymous_record(get_dynstring_rec_name(StringType,false,len),1,sizeof(TConstPtrUInt),1);
       string_symofs:=get_string_symofs(StringType,false);
       { encoding }
       emit_tai(TAIConst.create_16bit(encoding),U16IntType);
       inc(result.ofs,2);
       { element size }
       case StringType of
         st_ansistring:
           begin
             EleSize:=1;
             charptrdef:=CharPointerType;
           end;
         st_unicodestring:
           begin
             EleSize:=2;
             charptrdef:=WideCharPointerType;
           end
         else
           InternalError(2014080401);
       end;
       emit_tai(TAIConst.create_16bit(EleSize),U16IntType);
       inc(result.ofs,2);
{$ifdef cpu64bitaddr}
       emit_tai(TAIConst.Create_32bit(-1),S32IntType);
       inc(result.ofs,S32IntType.size);
{$else !cpu64bitaddr}
       emit_tai(TAIConst.create_sizeint(-1),SizeSIntType);
       inc(result.ofs,SizeSIntType.size);
{$endif !cpu64bitaddr}
       emit_tai(TAIConst.create_sizeint(len),SizeSIntType);
       inc(result.ofs,SizeSIntType.size);
       if string_symofs=0 then
         begin
           { results in slightly more efficient code }
           emit_tai(TAILabel.create(result.lab),charptrdef);
           result.ofs:=0;
           { create new label of the same kind (including whether or not the
             name starts with target_asm.labelprefix in case it's AB_LOCAL,
             so we keep the difference depending on whether the original was
             allocated via getstatic/getlocal/getglobal datalabel) }
           startlab:=TAsmLabel.create(CurrentAsmData.AsmSymbolDict,startlab.name+'$strlab',startlab.bind,startlab.typ);
         end;
       { sanity check }
       if result.ofs<>string_symofs then
         InternalError(2012051701);
     end;


   function TTAITypedConstBuilder.get_dynstring_def_for_type(StringType: TStringType; winlikewidestring: boolean): TStringDef;
     begin
       if StringType=st_ansistring then
         result:=TStringDef(CAnsiStringType)
       else if (StringType=st_unicodestring) or
               ((StringType=st_widestring) and
                not winlikewidestring) then
         result:=TStringDef(CUnicodeStringType)
       else if StringType=st_widestring then
         result:=TStringDef(CWideStringType)
       else
         InternalError(2015122101);
     end;


   procedure TTAITypedConstBuilder.begin_aggregate_internal(def: TDef; anonymous: boolean);
     var
       info: TAggregateInformation;
       tck: TTypedConstKind;
     begin
       tck:=aggregate_kind(def);
       if tck=tck_simple then
         exit;
       if not Assigned(faggregateinformation) then
         faggregateinformation:=TFPObjectList.create
       { if we're starting an anonymous record, we can't align it yet because
         the alignment depends on the fields that will be added -> we'll do
         it at the end }
       else if not anonymous or
          ((def.typ<>recorddef) and
           not Is_Object(def)) then
         begin
           { add padding if necessary, and update the current field/offset }
           info:=curagginfo;
           if (Is_Record(curagginfo.def) or
               Is_Object(curagginfo.def)) and
              not is_packed_record_or_object(curagginfo.def) then
             begin
               if queue_is_active then
                 InternalError(2015073001);
               pad_next_field(def);
             end;
         end
       { if this is the outer record, no padding is required; the alignment
         has to be specified explicitly in that case via get_final_asmlist() }
       else if Assigned(curagginfo) and
               (curagginfo.def.typ=recorddef) then
         { mark where we'll have to insert the padding bytes at the end }
         mark_anon_aggregate_alignment;
       info:=CAggregateInformation.create(def,aggregate_kind(def));
       faggregateinformation.add(info);
     end;


   procedure TTAITypedConstBuilder.end_aggregate_internal(def: TDef; anonymous: boolean);
     var
       info: TAggregateInformation;
       tck: TTypedConstKind;
     begin
       tck:=aggregate_kind(def);
       if tck=tck_simple then
         exit;
       { add tail padding if necessary }
       maybe_emit_tail_padding(def);
       { pop and free the information }
       info:=curagginfo;
       faggregateinformation.count:=faggregateinformation.count-1;
       info.free;
       info := nil;
     end;


   class function TTAITypedConstBuilder.get_vectorized_dead_strip_section_symbol(const basename: string; st: TSymTable; options: TTCDeadStripSectionSymbolOptions; start: boolean): TAsmSymbol;
     var
       name: TSymStr;
       asmtype : TAsmsymtype;
     begin
       if start then
         name:=Make_MangledName(basename,st,'START')
       else
         name:=Make_MangledName(basename,st,'END');
       if tcdssso_define in options then
         begin
           if tcdssso_use_indirect in options then
             asmtype:=AT_DATA_FORCEINDIRECT
           else
             asmtype:=AT_DATA;
           result:=CurrentAsmData.DefineAsmSymbol(name,AB_GLOBAL,asmtype,VoidPointerType);
           if tcdssso_register_asmsym in options then
             CurrentModule.Add_Public_AsmSym(result);
         end
       else
         begin
           result:=CurrentAsmData.RefAsmSymbol(name,AT_DATA,tcdssso_use_indirect in options);
           if tcdssso_register_asmsym in options then
             CurrentModule.Add_Extern_AsmSym(result);
         end;
     end;


   class function TTAITypedConstBuilder.get_vectorized_dead_strip_custom_section_name(const basename: TSymStr; st: TSymTable; options: TTCAsmListOptions; out secname: TSymStr): boolean;
     begin
       result:=false;
     end;


   class function TTAITypedConstBuilder.get_vectorized_dead_strip_section_symbol_start(const basename: string; st: TSymTable; options: TTCDeadStripSectionSymbolOptions): TAsmSymbol;
     begin
       result:=get_vectorized_dead_strip_section_symbol(basename,st,options,true);
     end;


   class function TTAITypedConstBuilder.get_vectorized_dead_strip_section_symbol_end(const basename: string; st: TSymTable; options: TTCDeadStripSectionSymbolOptions): TAsmSymbol;
     begin
       result:=get_vectorized_dead_strip_section_symbol(basename,st,options,false);
     end;


   class function TTAITypedConstBuilder.is_smartlink_vectorized_dead_strip: boolean;
     begin
       result:=(tf_smartlink_sections in TargetInfo.flags) and
               (not(TargetInfo.system in systems_darwin) or
                (tf_supports_symbolorderfile in TargetInfo.flags));
     end;


   class function TTAITypedConstBuilder.get_dynstring_rec_name(typ: TStringType; winlike: boolean; len: asizeint): TSymStr;
     begin
       case typ of
         st_ansistring:
           result:='$ansistrrec';
         st_unicodestring,
         st_widestring:
           if (typ=st_unicodestring) or
              not winlike then
             result:='$unicodestrrec'
           else
             result:='$widestrrec';
         else
           InternalError(2014080402);
       end;
       result:=result+ToStr(len);
     end;


   class function TTAITypedConstBuilder.get_dynstring_rec(typ: TStringType; winlike: boolean; len: asizeint): TRecordDef;
     var
       name: TSymStr;
       streledef: TDef;
       strtypesym: TTypeSym;
       srsym: TSym;
       srsymtable: TSymTable;
     begin
       name:=get_dynstring_rec_name(typ,winlike,len);
       { search in the interface of all units for the type to reuse it }
       if SearchSym_Type(name,srsym,srsymtable) then
         begin
           result:=TRecordDef(TTypeSym(srsym).typedef);
           exit;
         end
       else
         begin
           { also search the implementation of the current unit }
           strtypesym:=Try_Search_Current_Module_Type(name);
           if Assigned(strtypesym) then
             begin
               result:=TRecordDef(strtypesym.typedef);
               exit;
             end;
         end;
       if (typ<>st_widestring) or
          not winlike then
         begin
           result:=CRecordDef.Create_Global_Internal('$'+name,1,1);
           { encoding }
           result.Add_Field_By_Def('',U16IntType);
           { element size }
           result.Add_Field_By_Def('',U16IntType);
           { elements }
           case typ of
             st_ansistring:
               streledef:=CAnsiCharType;
             st_unicodestring:
               streledef:=CWideCharType;
             else
               InternalError(2016082301);
           end;
           { reference count }
{$ifdef cpu64bitaddr}
           result.Add_Field_By_Def('',S32IntType);
{$else !cpu64bitaddr}
           result.Add_Field_By_Def('',SizeSIntType);
{$endif !cpu64bitaddr}
           { length in elements }
           result.Add_Field_By_Def('',SizeSIntType);
         end
       else
         begin
           result:=CRecordDef.Create_Global_Internal('$'+name,4,
             targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
           { length in bytes }
           result.Add_Field_By_Def('',S32IntType);
           streledef:=CWideCharType;
         end;
       { data (include zero terminator) }
       result.Add_Field_By_Def('',CArrayDef.getreusable(streledef,len+1));
       TRecordSymTable(TRecordDef(result).SymTable).AddAlignmentPadding;
     end;


   function TTAITypedConstBuilder.emit_ansistring_const(datalist: TAsmList; data: pchar; len: asizeint; encoding: TStringEncoding): TAsmLabOfs;
     var
       startlab: TAsmLabel;
       ansistrrecdef: TRecordDef;
       datadef: TDef;
       datatcb: TTAITypedConstBuilder;
       ts : TAIString;
     begin
       start_internal_data_builder(datalist,sec_rodata_norel,'',datatcb,startlab);
       result:=datatcb.emit_string_const_common(st_ansistring,len,encoding,startlab);

       { add room for the #0-terminator }
       datadef:=CArrayDef.getreusable(CAnsiCharType,len+1);
       datatcb.maybe_begin_aggregate(datadef);
       ts:=TAIString.Create_Data(data,len,true);
       datatcb.emit_tai(ts,datadef);
       datatcb.maybe_end_aggregate(datadef);
       ansistrrecdef:=datatcb.end_anonymous_record;
       finish_internal_data_builder(datatcb,startlab,ansistrrecdef,Const_Align(VoidPointerType.alignment));
     end;


   function TTAITypedConstBuilder.emit_unicodestring_const(datalist: TAsmList; data: TCompilerWideString; encoding: TStringEncoding; winlike: boolean):TAsmLabOfs;
     var
       i, strlength: LongInt;
       string_symofs: asizeint;
       startlab: TAsmLabel;
       datadef: TDef;
       datatcb: TTAITypedConstBuilder;
       unicodestrrecdef: TRecordDef;
     begin
       start_internal_data_builder(datalist,sec_rodata_norel,'',datatcb,startlab);
       strlength:=GetLengthWideString(data);
       if winlike then
         begin
           result.lab:=startlab;
           datatcb.begin_anonymous_record(get_dynstring_rec_name(st_widestring,true,strlength),
             4,4,
             targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
           datatcb.emit_tai(TAIConst.Create_32bit(strlength*CWideCharType.size),S32IntType);
           { can we optimise by placing the string constant label at the
             required offset? }
           string_symofs:=get_string_symofs(st_widestring,true);
           if string_symofs=0 then
             begin
               { yes }
               datatcb.emit_tai(TAILabel.Create(result.lab),WideCharPointerType);
               { allocate a separate label for the start of the data (see
                 emit_string_const_common() for explanation) }
               startlab:=TAsmLabel.create(CurrentAsmData.AsmSymbolDict,startlab.name+'$strlab',startlab.bind,startlab.typ);
             end
           else
             InternalError(2015031502);
           result.ofs:=string_symofs;
         end
       else
         begin
           result:=datatcb.emit_string_const_common(st_unicodestring,strlength,encoding,startlab);
         end;
       if CWideCharType.size = 2 then
         begin
           datadef:=CArrayDef.getreusable(CWideCharType,strlength+1);
           datatcb.maybe_begin_aggregate(datadef);
           for i:=0 to strlength-1 do
             datatcb.emit_tai(TAIConst.Create_16bit(data.data[i]),CWideCharType);
           { ending #0 }
           datatcb.emit_tai(TAIConst.Create_16bit(0),CWideCharType);
           datatcb.maybe_end_aggregate(datadef);
           unicodestrrecdef:=datatcb.end_anonymous_record;
         end
       else
         { code generation for other sizes must be written }
         InternalError(200904271);
       finish_internal_data_builder(datatcb,startlab,unicodestrrecdef,Const_Align(VoidPointerType.alignment));
     end;


   procedure TTAITypedConstBuilder.emit_string_offset(const ll: TAsmLabOfs; const strlength: LongInt; const st: TStringType; const winlikewidestring: boolean; const charptrdef: TDef);
     begin
       emit_tai(TAIConst.Create_sym_offset(ll.lab,ll.ofs),get_dynstring_def_for_type(st,winlikewidestring));
     end;


   procedure TTAITypedConstBuilder.emit_dynarray_offset(const ll:TAsmLabOfs;const arrlength:asizeint;const arrdef:TArrayDef; const arrconstdatadef: TRecordDef);
     begin
       emit_tai(TAIConst.create_sym_offset(ll.lab,ll.ofs),arrdef);
     end;


   function TTAITypedConstBuilder.begin_dynarray_const(arrdef:TDef;var startlab:TAsmLabel;out arrlengthloc:TTypedConstPlaceholder):TAsmLabOfs;
     var
       dynarray_symofs: asizeint;
     begin
       result.lab:=startlab;
       result.ofs:=0;
       { pack the data, so that we don't add unnecessary null bytes after the
         constant string }
       begin_anonymous_record('',1,sizeof(TConstPtrUInt),1);
       dynarray_symofs:=get_dynarray_symofs;
       { what to do if ptrsinttype <> sizesinttype??? }
       emit_tai(TAIConst.create_sizeint(-1),PtrSIntType);
       inc(result.ofs,PtrSIntType.size);
       arrlengthloc:=emit_placeholder(SizeSIntType);
       inc(result.ofs,SizeSIntType.size);
       if dynarray_symofs=0 then
         begin
           { results in slightly more efficient code }
           emit_tai(TAILabel.create(result.lab),arrdef);
           result.ofs:=0;
           { create new label of the same kind (including whether or not the
             name starts with target_asm.labelprefix in case it's AB_LOCAL,
             so we keep the difference depending on whether the original was
             allocated via getstatic/getlocal/getglobal datalabel) }
           startlab:=TAsmLabel.create(CurrentAsmData.AsmSymbolDict,startlab.name+'$dynarrlab',startlab.bind,startlab.typ);
         end;
       { sanity check }
       if result.ofs<>dynarray_symofs then
         InternalError(2018020601);
     end;


   function TTAITypedConstBuilder.end_dynarray_const(arrdef:TDef;arrlength:asizeint;arrlengthloc:TTypedConstPlaceholder;llofs:TAsmLabOfs):TDef;
     begin
       { we emit the high value, not the count }
       arrlengthloc.replace(TAIConst.Create_sizeint(arrlength-1),SizeSIntType);
       arrlengthloc.free;
       arrlengthloc := nil;
       if get_dynarray_symofs=0 then
         emit_tai(TAISymbolEnd.create(llofs.lab),arrdef);
       result:=end_anonymous_record;
     end;


   function TTAITypedConstBuilder.emit_shortstring_const(const str: shortstring): TDef;
     begin
       { we use an arraydef instead of a shortstringdef, because we don't have
         functionality in place yet to reuse shortstringdefs of the same length
         and neither the lowlevel nor the llvm typedconst builder cares about
         this difference }
       result:=CArrayDef.getreusable(CAnsiCharType,length(str)+1);
       maybe_begin_aggregate(result);
       emit_tai(TAIConst.Create_8bit(length(str)),U8IntType);
       if str<>'' then
         emit_tai(TAIString.Create(str),CArrayDef.getreusable(CAnsiCharType,length(str)));
       maybe_end_aggregate(result);
     end;


   function TTAITypedConstBuilder.emit_pchar_const(str: pchar; len: PInt): TDef;
     begin
       result:=CArrayDef.getreusable(CAnsiCharType,len+1);
       maybe_begin_aggregate(result);
       if len=0 then
         emit_tai(TAIConst.Create_8bit(0),CAnsiCharType)
       else
         emit_tai(TAIString.Create_Data(str,len,true),result);
       maybe_end_aggregate(result);
     end;


   procedure TTAITypedConstBuilder.emit_guid_const(const guid: TGUID);
     var
       i: LongInt;
       field: TFieldVarSym;
     begin
       maybe_begin_aggregate(Rec_TGUID);
       { variant record -> must specify which fields get initialised }
       next_field:=TFieldVarSym(Rec_TGUID.SymTable.Find('DATA1'));
       emit_tai(TAIConst.Create_32bit(LongInt(guid.D1)),U32IntType);
       next_field:=TFieldVarSym(Rec_TGUID.SymTable.Find('DATA2'));
       emit_tai(TAIConst.Create_16bit(guid.D2),U16IntType);
       next_field:=TFieldVarSym(Rec_TGUID.SymTable.Find('DATA3'));
       emit_tai(TAIConst.Create_16bit(guid.D3),U16IntType);
       field:=TFieldVarSym(Rec_TGUID.SymTable.Find('DATA4'));
       next_field:=field;
       { the array }
       maybe_begin_aggregate(field.vardef);
       for i:=Low(guid.D4) to High(guid.D4) do
         emit_tai(TAIConst.Create_8bit(guid.D4[i]),U8IntType);
       maybe_end_aggregate(field.vardef);
       maybe_end_aggregate(Rec_TGUID);
     end;

   procedure TTAITypedConstBuilder.emit_procdef_const(pd: TProcDef);
     begin
       emit_tai(TAIConst.Createname(pd.MangledName,AT_FUNCTION,0),CProcVarDef.GetReusableProcAddr(pd,pc_address_only));
     end;


   procedure TTAITypedConstBuilder.emit_ord_const(value: int64; def: TDef);
     begin
       case def.size of
         1:
           emit_tai(TAIConst.Create_8bit(byte(value)),def);
         2:
           emit_tai(TAIConst.Create_16bit(word(value)),def);
         4:
           emit_tai(TAIConst.Create_32bit(LongInt(value)),def);
         8:
           emit_tai(TAIConst.Create_64bit(value),def);
         else
           InternalError(2014100501);
       end;
     end;


   procedure TTAITypedConstBuilder.emit_pooled_shortstring_const_ref(const str:shortstring);
     var
       pool : THashSet;
       entry : PHashSetItem;
       strlab : TAsmLabel;
       l : LongInt;
       datadef : TDef;
       strtcb : TTAITypedConstBuilder;
     begin
       pool:=CurrentAsmData.ConstPools[sp_shortstr];

       entry:=pool.FindOrAdd(@str[1],length(str));

       { :-(, we must generate a new entry }
       if not Assigned(entry^.Data) then
         begin
           CurrentAsmData.getglobaldatalabel(strlab);

           { include length and terminating zero for quick conversion to pchar }
           l:=length(str);
           datadef:=CArrayDef.getreusable(CAnsiCharType,l+2);

           { we start a new constbuilder as we don't know whether we're called
             from inside an internal constbuilder }
           strtcb:=CTAITypedConstBuilder.create([tcalo_is_lab,tcalo_make_dead_strippable,tcalo_apply_constalign]);

           strtcb.maybe_begin_aggregate(datadef);
           { l+1: include length byte; true: add terminating #0 }
           strtcb.emit_tai(TAIString.Create_Data(@str[0],l+1,true),datadef);
           strtcb.maybe_end_aggregate(datadef);

           CurrentAsmData.asmlists[al_typedconsts].ConcatList(
             strtcb.get_final_asmlist(strlab,datadef,sec_rodata_norel,strlab.name,Const_Align(sizeof(PInt)))
           );
           strtcb.free;
           strtcb := nil;

           entry^.Data:=strlab;
           { Make sure strlab has a reference }
           strlab.increfs;
         end
       else
         strlab:=TAsmLabel(entry^.Data);

       emit_tai(TAIConst.Create_sym(strlab),CharPointerType);
     end;


   procedure TTAITypedConstBuilder.maybe_begin_aggregate(def: TDef);
     begin
       begin_aggregate_internal(def,false);
     end;


   procedure TTAITypedConstBuilder.maybe_end_aggregate(def: TDef);
     begin
       end_aggregate_internal(def,false);
     end;


   function TTAITypedConstBuilder.begin_anonymous_record(const optionalname: string; PackRecords, recordalign, RecordAlignMin: shortint): TRecordDef;
     var
       anonrecorddef: TRecordDef;
       TypeSym: TTypeSym;
     begin
       { if the name is specified, we create a typesym with that name in order
         to ensure we can find it again later with that name -> reuse here as
         well if possible (and that also avoids duplicate type name issues) }
       if optionalname<>'' then
         begin
           TypeSym:=Try_Search_Current_Module_Type(optionalname);
           if Assigned(TypeSym) then
             begin
               if TypeSym.typedef.typ<>recorddef then
                 InternalError(2015071401);
               result:=TRecordDef(TypeSym.typedef);
               maybe_begin_aggregate(result);
               exit;
             end;
         end;
       { create skeleton def }
       anonrecorddef:=CRecordDef.Create_Global_Internal(optionalname,PackRecords,RecordAlignMin);
       TRecordSymTable(anonrecorddef.SymTable).RecordAlignment:=recordalign;
       { generic aggregate housekeeping }
       begin_aggregate_internal(anonrecorddef,true);
       { mark as anonymous record }
       curagginfo.anonrecord:=true;
       { in case a descendent wants to do something with the anonrecorddef too }
       result:=anonrecorddef;
     end;


   function TTAITypedConstBuilder.end_anonymous_record: TRecordDef;
     var
       info: TAggregateInformation;
       anonrecord: boolean;
     begin
       info:=curagginfo;
       if not Assigned(info) or
          (info.def.typ<>recorddef) then
         InternalError(2014080201);
       result:=TRecordDef(info.def);
       { make a copy, as we need it after info has been freed by
         maybe_end_aggregate(result) }
       anonrecord:=info.anonrecord;
       { finalise the record skeleton (all fields have been added already by
         emit_tai()) -- anonrecord may not be set in case we reused an earlier
         constructed def }
       if anonrecord then
         TRecordSymTable(result.SymTable).AddAlignmentPadding;
       end_aggregate_internal(result,true);
       if anonrecord and
          Assigned(curagginfo) and
          (curagginfo.def.typ=recorddef) then
         insert_marked_aggregate_alignment(result);
     end;

   procedure TTAITypedConstBuilder.emit_comment(const comment: string);
   var
     comm: TAIComment;
   begin
     if (length(comment)=0) then
       exit;
     comm:=TAIComment.Create(StrPNew(comment));
     fasmlist.concat(comm);
   end;


   procedure TTAITypedConstBuilder.check_add_placeholder(def: TDef);
     begin
       { it only makes sense to add a placeholder inside an aggregate
         (otherwise there can be but one element)

         we cannot add a placeholder in the middle of a queued expression
         either

         the placeholder cannot be an aggregate }
       if not Assigned(curagginfo) or
          queue_is_active or
          (aggregate_kind(def)<>tck_simple) then
         InternalError(2015091001);
     end;


   procedure TTAITypedConstBuilder.queue_init(todef: TDef);
     var
       info: TAggregateInformation;
     begin
       { nested call to init? }
       if fqueue_offset<>low(fqueue_offset) then
         InternalError(2014062101);

       { insert padding bytes before starting the queue, so that the first
         padding byte won't be interpreted as the emitted value for this queue }
       info:=curagginfo;
       if Assigned(info) then
         begin
           if ((info.def.typ=recorddef) or
               Is_Object(info.def)) and
              { may add support for these later }
              not is_packed_record_or_object(info.def) then
             pad_next_field(todef);
         end;

       fqueue_offset:=0;
       fqueued_def:=todef;
     end;


   procedure TTAITypedConstBuilder.queue_vecn(def: TDef; const index: TConstExprInt);
     var
       elelen,
       vecbase: asizeint;
       v: TConstExprInt;
     begin
       elelen:=1;
       vecbase:=0;
       case def.typ of
         stringdef :
           ;
         arraydef :
           begin
             if not is_packed_array(def) then
               begin
                 elelen:=TArrayDef(def).EleSize;
                 vecbase:=TArrayDef(def).LowRange;
               end
             else
               Message(parser_e_packed_dynamic_open_array);
           end;
         else
           Message(parser_e_illegal_expression);
       end;
       { Prevent overflow }
       v:=index-vecbase;
       if (v<int64(low(fqueue_offset))) or (v>int64(high(fqueue_offset))) then
         message3(type_e_range_check_error_bounds,ToStr(v),ToStr(low(fqueue_offset)),ToStr(high(fqueue_offset)));
       if high(fqueue_offset)-fqueue_offset div elelen>v then
         inc(fqueue_offset,elelen*v.svalue)
       else
         message3(type_e_range_check_error_bounds,ToStr(index),ToStr(vecbase),ToStr(high(fqueue_offset)-fqueue_offset div elelen+vecbase))
     end;


   procedure TTAITypedConstBuilder.queue_pointeraddn(def: TPointerDef; const index: TConstExprInt);
     begin
       inc(fqueue_offset,def.PointedDef.size*int64(index));
     end;


   procedure TTAITypedConstBuilder.queue_pointersubn(def: TPointerDef; const index: TConstExprInt);
     begin
       dec(fqueue_offset,def.PointedDef.size*int64(index));
     end;


   procedure TTAITypedConstBuilder.queue_subscriptn(def: TAbstractRecordDef; vs: TFieldVarSym);
     begin
       inc(fqueue_offset,vs.FieldOffset);
     end;


   function TTAITypedConstBuilder.queue_subscriptn_multiple_by_name(def: TAbstractRecordDef; const fields: array of TIDString): TDef;
     var
       syms,
       parentdefs: TFPList;
       sym: TSym;
       curdef: TDef;
       i: LongInt;
     begin
       result:=nil;
       if length(fields)=0 then
         InternalError(2015071601);
       syms:=TFPList.Create;
       syms.count:=length(fields);
       parentdefs:=TFPList.create;
       parentdefs.Count:=length(fields);
       curdef:=def;
       for i:=low(fields) to high(fields) do
         begin
           sym:=Search_Struct_Member_No_Helper(TAbstractRecordDef(curdef),fields[i]);
           if not Assigned(sym) or
              not is_normal_fieldvarsym(sym) or
              ((i<>high(fields)) and
               not(TFieldVarSym(sym).vardef.typ in [objectdef,recorddef])) then
             InternalError(2015071505);
           syms[i]:=sym;
           parentdefs[i]:=curdef;
           curdef:=TFieldVarSym(sym).vardef;
           result:=curdef;
         end;
       for i:=high(fields) downto low(fields) do
         queue_subscriptn(TAbstractRecordDef(parentdefs[i]),TFieldVarSym(syms[i]));
       syms.free;
       syms := nil;
       parentdefs.free;
       parentdefs := nil;
     end;


   procedure TTAITypedConstBuilder.queue_typeconvn(fromdef, todef: TDef);
     begin
       { do nothing }
     end;


   procedure TTAITypedConstBuilder.queue_emit_proc(pd: TProcDef);
     begin
       if fqueue_offset<>0 then
         InternalError(2014092101);
       emit_procdef_const(pd);
       fqueue_offset:=low(fqueue_offset);
     end;


   procedure TTAITypedConstBuilder.queue_emit_staticvar(vs: TStaticVarSym);
     begin
       { pointerdef because we are emitting a pointer to the staticvarsym
         data, not the data itself }
       emit_tai(TAIConst.Createname(vs.MangledName,AT_DATA,fqueue_offset),CPointerDef.getreusable(vs.vardef));
       fqueue_offset:=low(fqueue_offset);
     end;


   procedure TTAITypedConstBuilder.queue_emit_label(l: TLabelSym);
     begin
       emit_tai(TAIConst.Createname(l.MangledName,fqueue_offset),VoidCodePointerType);
       fqueue_offset:=low(fqueue_offset);
     end;


   procedure TTAITypedConstBuilder.queue_emit_const(cs: TConstSym);
     var
       resourcestrrec: TRecordDef;
     begin
       if not (cs.ConstTyp in [constresourcestring,constwresourcestring]) then
         InternalError(2014062102);
       if fqueue_offset<>0 then
         InternalError(2014062103);
       { warning: update if/when the type of resource strings changes }
       case cs.ConstTyp of
         constwresourcestring,
         constresourcestring:
           begin
             resourcestrrec:=TRecordDef(Search_System_Type('TRESOURCESTRINGRECORD').typedef);
             queue_subscriptn_multiple_by_name(resourcestrrec,['CURRENTVALUE']);
             queue_emit_asmsym(CurrentAsmData.RefAsmSymbol(
               Make_MangledName('RESSTR',cs.owner,cs.name),AT_DATA),resourcestrrec
             );
           end;
         { can these occur? }
         constord,
         conststring,constreal,
         constset,constpointer,constnil,
         constwstring,constguid:
           InternalError(2015090903);
         else
           InternalError(2015090904);
       end;
       fqueue_offset:=low(fqueue_offset);
     end;


   procedure TTAITypedConstBuilder.queue_emit_asmsym(sym: TAsmSymbol; def: TDef);
     begin
       { pointerdef, because "sym" represents the address of whatever the
         data is }
       def:=CPointerDef.getreusable(def);
       emit_tai(TAIConst.Create_sym_offset(sym,fqueue_offset),def);
       fqueue_offset:=low(fqueue_offset);
     end;


   procedure TTAITypedConstBuilder.queue_emit_ordconst(value: int64; def: TDef);
     begin
       emit_ord_const(value,def);
       fqueue_offset:=low(fqueue_offset);
     end;


   function TTAITypedConstBuilder.queue_is_active: boolean;
     begin
       result:=fqueue_offset<>low(fqueue_offset)
     end;

   {****************************************************************************
                         tlowleveltypedconstplaceholder
   ****************************************************************************}

   constructor TLowLevelTypedConstPlaceholder.create(l: TAsmList; pos: TAI; d: TDef);
     begin
       inherited create(d);
       list:=l;
       insertpos:=pos;
     end;


   procedure TLowLevelTypedConstPlaceholder.replace(ai: TAI; d: TDef);
     begin
       if d<>def then
         InternalError(2015091007);
       list.insertafter(ai,insertpos);
       list.remove(insertpos);
       insertpos.free;
       insertpos := nil;
     end;


{****************************************************************************
                           tai_abstracttypedconst
 ****************************************************************************}

   class constructor TTAILowLevelTypedConstBuilder.classcreate;
     begin
       CAggregateInformation:=TLowLevelAggregateInformation;
     end;


   function TTAILowLevelTypedConstBuilder.emit_placeholder(def: TDef): TTypedConstPlaceholder;
     var
       p: TAI;
     begin
       check_add_placeholder(def);
       p:=TAIMarker.Create(mark_position);
       emit_tai(p,def);
       result:=TLowLevelTypedConstPlaceholder.create(fasmlist,p,def);
     end;


   procedure TTAILowLevelTypedConstBuilder.mark_anon_aggregate_alignment;
     var
       marker: TAIMarker;
     begin
       marker:=TAIMarker.Create(mark_position);
       fasmlist.concat(marker);
       TLowLevelAggregateInformation(curagginfo).anonrecmarker:=marker;
     end;


   procedure TTAILowLevelTypedConstBuilder.insert_marked_aggregate_alignment(def: TDef);
     var
       info: TLowLevelAggregateInformation;
       fillbytes: asizeint;
     begin
       info:=TLowLevelAggregateInformation(curagginfo);
       if not Assigned(info.anonrecmarker) then
         InternalError(2014091401);
       fillbytes:=info.prepare_next_field(def);
       while fillbytes>0 do
         begin
           fasmlist.insertafter(TAIConst.create_8bit(0),info.anonrecmarker);
           dec(fillbytes);
         end;
       fasmlist.remove(info.anonrecmarker);
       info.anonrecmarker.free;
       info.anonrecmarker:=nil;
     end;

   procedure TTAILowLevelTypedConstBuilder.finalize_asmlist(asmsym: TAsmSymbol; sym: TSym; def: TDef; section: TAsmSectiontype; const secname: TSymStr; alignment: shortint; const options: TTCAsmListOptions);
     begin
       inherited;
       { The darwin/ppc64 assembler or linker seems to have trouble       }
       { if a section ends with a global label without any data after it. }
       { So for safety, just put a dummy value here.                      }
       { Further, the regular linker also kills this symbol when turning  }
       { on smart linking in case no value appears after it, so put the   }
       { dummy byte there always                                          }
       { Update: the Mac OS X 10.6 linker orders data that needs to be    }
       { relocated before all other data, so make this data relocatable,  }
       { otherwise the end label won't be moved with the rest             }
       if (tcalo_vectorized_dead_strip_end in options) and
          (TargetInfo.system in systems_darwin) then
         fasmlist.concat(TAIConst.create_sym(asmsym));
     end;



begin
  CTAITypedConstBuilder:=TTAILowLevelTypedConstBuilder;
end.

