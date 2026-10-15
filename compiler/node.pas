{
    Copyright (c) 2000-2002 by Florian Klaempfl

    Basic node handling

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
unit node;

{$i fpcdefs.inc}

interface

    uses
       cclasses,
       globtype,globals,cgbase,cgutils,
       symtype,
       optbase;

    type
       TNodeType = (
          emptynode,        {No node (returns nil when loading from ppu)}
          addn,             {Represents the + operator}
          muln,             {Represents the * operator}
          subn,             {Represents the - operator}
          divn,             {Represents the div operator}
          symdifn,          {Represents the >< operator}
          modn,             {Represents the mod operator}
          assignn,          {Represents an assignment}
          loadn,            {Represents the use of a variable}
          rangen,           {Represents a range (i.e. 0..9)}
          ltn,              {Represents the < operator}
          lten,             {Represents the <= operator}
          gtn,              {Represents the > operator}
          gten,             {Represents the >= operator}
          equaln,           {Represents the = operator}
          unequaln,         {Represents the <> operator}
          inn,              {Represents the in operator}
          orn,              {Represents the or operator}
          xorn,             {Represents the xor operator}
          shrn,             {Represents the shr operator}
          shln,             {Represents the shl operator}
          slashn,           {Represents the / operator}
          andn,             {Represents the and operator}
          subscriptn,       {Field in a record/object}
          derefn,           {Dereferences a pointer}
          addrn,            {Represents the @ operator}
          ordconstn,        {Represents an ordinal value}
          typeconvn,        {Represents type-conversion/typecast}
          calln,            {Represents a call node}
          callparan,        {Represents a parameter}
          realconstn,       {Represents a real value}
          unaryminusn,      {Represents a sign change (i.e. -2)}
          unaryplusn,       {Represents a check for +Value}
          asmn,             {Represents an assembler node }
          vecn,             {Represents array indexing}
          pointerconstn,    {Represents a pointer constant}
          stringconstn,     {Represents a string constant}
          notn,             {Represents the not operator}
          inlinen,          {Internal procedures (i.e. writeln)}
          niln,             {Represents the nil pointer}
          errorn,           {This part of the tree could not be
                             parsed because of a compiler error}
          typen,            {A type name. Used for i.e. typeof(obj)}
          setelementn,      {A set element(s) (i.e. [a,b] and also [a..b])}
          setconstn,        {A set constant (i.e. [1,2])}
          blockn,           {A block of statements}
          statementn,       {One statement in a block of nodes}
          ifn,              {An if statement / expression}
          breakn,           {A break statement}
          continuen,        {A continue statement}
          whilerepeatn,     {A while or repeat statement}
          forn,             {A for loop}
          exitn,            {An exit statement}
          casen,            {A case statement / expression}
          labeln,           {A label}
          goton,            {A goto statement}
          tryexceptn,       {A try except block / expression}
          raisen,           {A raise statement}
          tryfinallyn,      {A try finally statement}
          onn,              {For an on statement in exception code}
          isn,              {Represents the is operator}
          asn,              {Represents the as typecast}
          starstarn,        {Represents the ** operator exponentiation }
          arrayconstructorn, {Construction node for [...] parsing}
          arrayconstructorrangen, {Range element to allow sets in array construction tree}
          tempcreaten,      { for temps in the result/firstpass }
          temprefn,         { references to temps }
          tempdeleten,      { for temps in the result/firstpass }
          addoptn,          { added for optimizations where we cannot suppress }
          nothingn,         { NOP, Do nothing}
          loadvmtaddrn,     { Load the address of the VMT of a class/object}
          guidconstn,       { A GUID COM Interface constant }
          rttin,            { Rtti information so they can be accessed in result/firstpass}
          loadparentfpn,    { Load the framepointer of the parent for nested procedures }
          objcselectorn,    { node for an Objective-C message selector }
          objcprotocoln,    { node for an Objective-C @protocol() expression (returns metaclass associated with protocol) }
          specializen,      { parser-only node to handle Delphi-mode inline specializations }
          finalizetempsn        { Internal node used to clean up code generator temps (warning: must NOT create additional tepms that may need to be finalised!) }
       );

       TNodeTypeSet = set of TNodeType;
       PNodeTypeSet = ^TNodeTypeSet;

      const
        nodetype2str : array[TNodeType] of string[24] = (
          '<emptynode>',
          'addn',
          'muln',
          'subn',
          'divn',
          'symdifn',
          'modn',
          'assignn',
          'loadn',
          'rangen',
          'ltn',
          'lten',
          'gtn',
          'gten',
          'equaln',
          'unequaln',
          'inn',
          'orn',
          'xorn',
          'shrn',
          'shln',
          'slashn',
          'andn',
          'subscriptn',
          'derefn',
          'addrn',
          'ordconstn',
          'typeconvn',
          'calln',
          'callparan',
          'realconstn',
          'unaryminusn',
          'unaryplusn',
          'asmn',
          'vecn',
          'pointerconstn',
          'stringconstn',
          'notn',
          'inlinen',
          'niln',
          'errorn',
          'typen',
          'setelementn',
          'setconstn',
          'blockn',
          'statementn',
          'ifn',
          'breakn',
          'continuen',
          'whilerepeatn',
          'forn',
          'exitn',
          'casen',
          'labeln',
          'goton',
          'tryexceptn',
          'raisen',
          'tryfinallyn',
          'onn',
          'isn',
          'asn',
          'starstarn',
          'arrayconstructn',
          'arrayconstructrangen',
          'tempcreaten',
          'temprefn',
          'tempdeleten',
          'addoptn',
          'nothingn',
          'loadvmtaddrn',
          'guidconstn',
          'rttin',
          'loadparentfpn',
          'objcselectorn',
          'objcprotocoln',
          'specializen',
          'finalizetempsn');

      { a set containing all const nodes }
      nodetype_const = [niln,
                        ordconstn,
                        pointerconstn,
                        stringconstn,
                        guidconstn,
                        realconstn,
                        setconstn];

    type
       { all boolean field of ttree are now collected in flags }
       TNodeFlag = (
         { tbinop operands are swapped    }
         nf_swapped,

         { general }
         { Node is written to    }
         nf_write,
         { Node is modified      }
         nf_modify,
         { address of node is taken }
         nf_address_taken,
         nf_is_funcret,
         nf_isproperty,
         { Node cannot be assigned to }
         nf_no_lvalue,
         { this node is the user code entry, if a node with this flag is removed
           during simplify, the flag must be moved to another node.  Though
           normally applicable to block nodes, they can also appear on asm nodes
           in the case of pure assembly routines }
         nf_usercode_entry,

         { tloadnode/ttypeconvnode }
         nf_absolute,

         { taddnode, but appears in typeconv nodes as well among other places }
         { if the result type of a node is currency, then this flag denotes, that the value is already multiplied by 10000 }
         nf_is_currency,

         { ttypeconvnode, and the first one also treal/ord/pointerconstn }
         { second one also for subtractions of u32-u32 implicitly upcasted to s64 }
         { last one also used on addnode to inhibit procvar calling }
         nf_explicit,
         nf_internal,  { no warnings/hints generated }
         nf_load_procvar,

         { tblocknode / this is not node-specific because it can also appear on
           implicit try/finally nodes }
         nf_block_with_exit,

         { tloadvmtaddrnode / tisnode }
         nf_ignore_for_wpo, { we know that this loadvmtaddrnode cannot be used to construct a class instance }

         { node is derived from generic parameter }
         nf_generic_para
       );

       TNodeFlags = set of TNodeFlag;

       TTransientNodeFlag = (
         { general }
         tnf_pass1_done,
         tnf_error,

         { tbinop operands can be swapped }
         tnf_swapable,

         tnf_processing,

         { internal flag to indicate that this node has been removed from the tree or must otherwise not be
           execute.  Running it through firstpass etc. will raise an internal error }
         tnf_do_not_execute
       );

       TTransientNodeFlags = set of TTransientNodeFlag;


    const
       { contains the flags which must be equal for the equality }
       { of nodes                                                }
       flagsequal : TNodeFlags = [];
       transientflagsequal : TTransientNodeFlags = [tnf_error];

    type
      TNodeList = class
      end;

      PNode = ^TNode;
      { basic class for the intermediated representation fpc uses }
      TNode = class
      private
         fppuidx : longint;
         function getppuidx:longint;
      public
         { type of this node }
         nodetype : TNodeType;
         { type of the current code block, general/const/type }
         blocktype : TBlockType;
         { expected location of the result of this node (pass1) }
         expectloc : tcgloc;
         { the location of the result of this node (pass2) }
         location : tlocation;
         { next node in control flow on the same block level, i.e.
           for loop nodes, this is the next node after the end of the loop,
           same for if and case, if this field is nil, the next node is the procedure exit,
           for the last node in a loop this is set to the loop header
           this field is set only for control flow nodes }
         successor : TNode;
         { there are some properties about the node stored }
         flags  : TNodeFlags;
         transientflags : TTransientNodeFlags;
         resultdef     : TDef;
         resultdefderef : TDeref;
         fileinfo      : TFilePosInfo;
         localswitches : TLocalSwitches;
         verbosity     : longint;
         optinfo : poptinfo;
         constructor create(t:TNodeType);
         { this constructor is only for creating copies of class }
         { the fields are copied by getcopy                      }
         constructor createforcopy;
         constructor ppuload(t:TNodeType;ppufile:TCompilerPPUFile);virtual;
         destructor destroy;override;
         procedure ppuwrite(ppufile:TCompilerPPUFile);virtual;
         procedure buildderefimpl;virtual;
         procedure derefimpl;virtual;
         procedure resolveppuidx;virtual;

         { toggles the flag }
         procedure toggleflag(f : TNodeFlag);

         { the 1.1 code generator may override pass_1 }
         { and it need not to implement det_* then    }
         { 1.1: pass_1 returns a value<>0 if the node has been transformed }
         { 2.0: runs pass_typecheck and det_temp                           }
         function pass_1 : TNode;virtual;abstract;
         { dermines the resultdef of the node }
         function pass_typecheck : TNode;virtual;abstract;

         { tries to simplify the node, returns a value <>nil if a simplified
           node has been created }
         function simplify(forinline : boolean) : TNode;virtual;
{$ifdef state_tracking}
         { Does optimizations by keeping track of the variable states
           in a procedure }
         function track_state_pass(exec_known:boolean):boolean;virtual;
{$endif}
         { For a t1:=t2 tree, mark the part of the tree t1 that gets
           written to (normally the loadnode) as write access. }
         procedure mark_write;virtual;
         { dermines the number of necessary temp. locations to evaluate
           the node }
         procedure det_temp;virtual;abstract;

         procedure pass_generate_code;virtual;abstract;

         { comparing of nodes }
         function isequal(p : TNode) : boolean;
         { to implement comparison, override this method }
         function docompare(p : TNode) : boolean;virtual;
         { wrapper for getcopy }
         function getcopy : TNode;

         { does the real copying of a node }
         function dogetcopy : TNode;virtual;

         procedure insertintolist(l : TNodeList);virtual;
         { writes a node for debugging purpose, shouldn't be called }
         { direct, because there is no test for nil, use printnode  }
         { to write a complete tree }
         procedure printnodeinfo(var t:text);virtual;
         procedure printnodedata(var t:text);virtual;
         procedure printnodetree(var t:text);virtual;
{$ifdef DEBUG_NODE_XML}
         { For writing nodes to XML files - do not call directly, but
           instead call XMLPrintNode to write a complete tree }
         procedure XMLPrintNodeInfo(var T: Text); dynamic;
         procedure XMLPrintNodeData(var T: Text); virtual;
         procedure XMLPrintNodeTree(var T: Text); virtual;
{$endif DEBUG_NODE_XML}
         function ischild(p : TNode) : boolean;virtual;

         { ensures that the optimizer info record is allocated }
         function allocoptinfo : poptinfo;inline;
         property ppuidx:longint read getppuidx;
      end;

      TNodeClass = class of TNode;

      tnodeclassarray = array[TNodeType] of TNodeClass;

      { this node is the ancestor for all nodes with at least    }
      { one child, you have to use it if you want to use         }
      { true- and current_procinfo.CurrFalseLabel                                     }
      //punarynode = ^tunarynode;
      TUnaryNode = class(TNode)
         left : TNode;
         constructor create(t:TNodeType;l : TNode);
         constructor ppuload(t:TNodeType;ppufile:TCompilerPPUFile);override;
         destructor destroy;override;
         procedure ppuwrite(ppufile:TCompilerPPUFile);override;
         procedure buildderefimpl;override;
         procedure derefimpl;override;
         function ischild(p : TNode) : boolean;override;
         function docompare(p : TNode) : boolean;override;
         function dogetcopy : TNode;override;
         procedure insertintolist(l : TNodeList);override;
         procedure printnodedata(var t:text);override;
{$ifdef DEBUG_NODE_XML}
         procedure XMLPrintNodeData(var T: Text); override;
{$endif DEBUG_NODE_XML}
         { Marks the current node for deletion and sets 'left' to nil.
           Returns what 'left' was previously set to }
         function PruneKeepLeft: TNode; {$ifdef USEINLINE}inline;{$endif USEINLINE}
      end;

      //pbinarynode = ^tbinarynode;
      TBinaryNode = class(TUnaryNode)
         right : TNode;
         constructor create(t:TNodeType;l,r : TNode);
         constructor ppuload(t:TNodeType;ppufile:TCompilerPPUFile);override;
         destructor destroy;override;
         procedure ppuwrite(ppufile:TCompilerPPUFile);override;
         procedure buildderefimpl;override;
         procedure derefimpl;override;
         function ischild(p : TNode) : boolean;override;
         function docompare(p : TNode) : boolean;override;
         procedure swapleftright;
         function dogetcopy : TNode;override;
         procedure insertintolist(l : TNodeList);override;
         procedure printnodedata(var t:text);override;
{$ifdef DEBUG_NODE_XML}
         procedure XMLPrintNodeTree(var T: Text); override;
         procedure XMLPrintNodeData(var T: Text); override;
{$endif DEBUG_NODE_XML}
         procedure printnodelist(var t:text);
         { Marks the current node for deletion and sets 'right' to nil.
           Returns what 'right' was previously set to }
         function PruneKeepRight: TNode; {$IFDEF USEINLINE}inline;{$endif USEINLINE}
      end;

      //ptertiarynode = ^ttertiarynode;
      TTertiaryNode = class(TBinaryNode)
         third : TNode;
         constructor create(_t:TNodeType;l,r,t : TNode);
         constructor ppuload(t:TNodeType;ppufile:TCompilerPPUFile);override;
         destructor destroy;override;
         procedure ppuwrite(ppufile:TCompilerPPUFile);override;
         procedure buildderefimpl;override;
         procedure derefimpl;override;
         function ischild(p : TNode) : boolean;override;
         function docompare(p : TNode) : boolean;override;
         function dogetcopy : TNode;override;
         procedure insertintolist(l : TNodeList);override;
         procedure printnodedata(var t:text);override;
{$ifdef DEBUG_NODE_XML}
         procedure XMLPrintNodeData(var T: Text); override;
{$endif DEBUG_NODE_XML}
         { Marks the current node for deletion and sets 'third' to nil.
           Returns what 'third' was previously set to }
         function PruneKeepThird: TNode; {$IFDEF USEINLINE}inline;{$endif USEINLINE}
      end;

      TBinOpNode = class(TBinaryNode)
         constructor create(t:TNodeType;l,r : TNode);virtual;
         function docompare(p : TNode) : boolean;override;
{$ifdef DEBUG_NODE_XML}
         procedure XMLPrintNodeData(var T: Text); override;
{$endif DEBUG_NODE_XML}
      end;

    var
      { array with all class types for tnodes }
      nodeclass : tnodeclassarray;

    function nodeppuidxget(i:longint):TNode;
    function ppuloadnode(ppufile:TCompilerPPUFile):TNode;
    procedure ppuwritenode(ppufile:TCompilerPPUFile;n:TNode);
    function ppuloadnodetree(ppufile:TCompilerPPUFile):TNode;
    procedure ppuwritenodetree(ppufile:TCompilerPPUFile;n:TNode);

    procedure printfileinfo(var t:text;pos:TFilePosInfo);
    procedure dprintfileinfo(pos:TFilePosInfo);
    procedure printnode(var t:text;n:TNode);
    procedure dprintnode(n:TNode);
{$ifdef DEBUG_NODE_XML}
    procedure XMLPrintNode(var T: Text; N: TNode);
{$endif DEBUG_NODE_XML}
    function is_constnode(p : TNode) : boolean;
    function is_constintnode(p : TNode) : boolean;
    function is_constcharnode(p : TNode) : boolean;
    function is_constrealnode(p : TNode) : boolean;
    function is_constboolnode(p : TNode) : boolean;
    function is_constenumnode(p : TNode) : boolean;
    function is_constwidecharnode(p : TNode) : boolean;
    function is_constpointernode(p : TNode) : boolean;
    function is_conststringnode(p : TNode) : boolean;
    function is_constwidestringnode(p : TNode) : boolean;
    function is_conststring_or_constcharnode(p : TNode) : boolean;


implementation

    uses
       verbose,entfile,
       finput,comphook,
{$ifdef DEBUG_NODE_XML}
       cutils,
{$endif DEBUG_NODE_XML}
       ppu,fmodule,
       symconst,
       nutils,nflw,
       defutil;

    const
      ppunodemarker = 255;


{****************************************************************************
                                 Helpers
 ****************************************************************************}

    var
      nodeppulist : TFPObjectList;
      nodeppuidx  : longint;


    procedure nodeppuidxcreate;
      begin
        nodeppulist:=TFPObjectList.Create(false);
        nodeppuidx:=0;
      end;


    procedure nodeppuidxresolve;
      var
        i : longint;
        n : TNode;
      begin
        for i:=0 to nodeppulist.count-1 do
          begin
            n:=TNode(nodeppulist[i]);
            if assigned(n) then
              n.resolveppuidx;
          end;
      end;


    procedure nodeppuidxfree;
      begin
        nodeppulist.free;
        nodeppulist:=nil;
        nodeppuidx:=0;
      end;


    procedure nodeppuidxadd(n:TNode);
      var
        i : longint;
      begin
        i:=n.ppuidx;
        if i<=0 then
          internalerror(200311072);
        if i>=nodeppulist.capacity then
          nodeppulist.capacity:=((i div 1024)+1)*1024;
        if i>=nodeppulist.count then
          nodeppulist.count:=i+1;
        nodeppulist[i]:=n;
      end;


    function nodeppuidxget(i:longint):TNode;
      begin
        if i<=0 then
          internalerror(200311073);
        result:=TNode(nodeppulist[i]);
      end;


    function ppuloadnode(ppufile:TCompilerPPUFile):TNode;
      var
        b : byte;
        t : TNodeType;
        hppuidx : longint;
      begin
        { marker }
        b:=ppufile.getbyte;
        if b<>ppunodemarker then
          internalerror(200208151);
        { load nodetype }
        t:=TNodeType(ppufile.getbyte);
        if t>high(TNodeType) then
          internalerror(200208152);
        if t<>emptynode then
         begin
           if not assigned(nodeclass[t]) then
             internalerror(200208153);
           hppuidx:=ppufile.getlongint;
           //writeln('load: ',nodetype2str[t]);
           { generate node of the correct class }
           result:=nodeclass[t].ppuload(t,ppufile);
           result.fppuidx:=hppuidx;
           nodeppuidxadd(result);
         end
        else
         result:=nil;
      end;


    procedure ppuwritenode(ppufile:TCompilerPPUFile;n:TNode);
      begin
        { marker, read by ppuloadnode }
        ppufile.putbyte(ppunodemarker);
        { type, read by ppuloadnode }
        if assigned(n) then
         begin
           ppufile.putbyte(byte(n.nodetype));
           ppufile.putlongint(n.ppuidx);
           //writeln('write: ',nodetype2str[n.nodetype]);
           n.ppuwrite(ppufile);
         end
        else
         ppufile.putbyte(byte(emptynode));
      end;


    function ppuloadnodetree(ppufile:TCompilerPPUFile):TNode;
      begin
        if ppufile.readentry<>ibnodetree then
          Message(unit_f_ppu_read_error);
        nodeppuidxcreate;
        result:=ppuloadnode(ppufile);
        nodeppuidxresolve;
        nodeppuidxfree;
      end;


    procedure ppuwritenodetree(ppufile:TCompilerPPUFile;n:TNode);
      begin
        nodeppuidxcreate;
        ppuwritenode(ppufile,n);
        ppufile.writeentry(ibnodetree);
        nodeppuidxfree;
      end;


    procedure printnode(var t:text;n:TNode);
      begin
        if assigned(n) then
         n.printnodetree(t)
        else
         writeln(t,printnodeindention,'nil');
      end;


    procedure dprintnode(n:TNode);
      begin
        printnode(output,n);
      end;

    procedure printfileinfo(var t:text; pos:TFilePosInfo);
      var
	infile : string;
	module : tmodule;
	afile : tinputfile;
      begin
        infile:='inconsistent';
	module:=get_module(pos.moduleindex);
	if assigned(module) then
          begin
            afile:=module.sourcefiles.get_file(pos.fileindex);
	    if assigned(afile) then
              infile:=afile.name;
	  end;
        write(t,'(',infile,':',pos.line,',',pos.column,')');
      end;

    procedure dprintfileinfo(pos:TFilePosInfo);
      begin
        printfileinfo(output,pos);
      end;

{$ifdef DEBUG_NODE_XML}
    procedure XMLPrintNode(var T: Text; N: TNode);
      begin
        if Assigned(N) then
          N.XMLPrintNodeTree(T);
      end;
{$endif DEBUG_NODE_XML}

    function is_constnode(p : TNode) : boolean;
      begin
        is_constnode:=(p.nodetype in nodetype_const);
      end;


    function is_constintnode(p : TNode) : boolean;
      begin
         is_constintnode:=(p.nodetype=ordconstn) and is_integer(p.resultdef);
      end;


    function is_constcharnode(p : TNode) : boolean;
      begin
         is_constcharnode:=(p.nodetype=ordconstn) and is_char(p.resultdef);
      end;


    function is_constwidecharnode(p : TNode) : boolean;
      begin
         is_constwidecharnode:=(p.nodetype=ordconstn) and is_widechar(p.resultdef);
      end;


    function is_constrealnode(p : TNode) : boolean;
      begin
         is_constrealnode:=(p.nodetype=realconstn);
      end;


    function is_constboolnode(p : TNode) : boolean;
      begin
         is_constboolnode:=(p.nodetype=ordconstn) and is_boolean(p.resultdef);
      end;


    function is_constenumnode(p : TNode) : boolean;
      begin
         is_constenumnode:=(p.nodetype=ordconstn) and (p.resultdef.typ=enumdef);
      end;


    function is_constpointernode(p : TNode) : boolean;
      begin
         is_constpointernode:=(p.nodetype in [pointerconstn,niln]);
      end;

    function is_conststringnode(p : TNode) : boolean;
      begin
         is_conststringnode :=
           (p.nodetype = stringconstn) and
           (is_chararray(p.resultdef) or
            is_shortstring(p.resultdef) or
            is_ansistring(p.resultdef));
      end;

    function is_constwidestringnode(p : TNode) : boolean;
      begin
         is_constwidestringnode :=
           (p.nodetype = stringconstn) and
           (is_widechararray(p.resultdef) or
            is_wide_or_unicode_string(p.resultdef));
      end;

    function is_conststring_or_constcharnode(p : TNode) : boolean;
      begin
        is_conststring_or_constcharnode :=
          is_conststringnode(p) or is_constcharnode(p) or
          is_constwidestringnode(p) or is_constwidecharnode(p);
      end;


{****************************************************************************
                                 TNODE
 ****************************************************************************}

    constructor TNode.create(t:TNodeType);

      begin
         inherited create;
         nodetype:=t;
         blocktype:=block_type;
         { updated by firstpass }
         expectloc:=LOC_INVALID;
         { updated by secondpass }
         location.loc:=LOC_INVALID;
         { save local info }
         fileinfo:=CurrentFilePos;
         localswitches:=CurrentSettings.localswitches;
         verbosity:=status.verbosity;
         resultdef:=nil;
         flags:=[];
      end;

    constructor TNode.createforcopy;

      begin
      end;

    constructor TNode.ppuload(t:TNodeType;ppufile:TCompilerPPUFile);

      begin
        nodetype:=t;
        { tnode fields }
        blocktype:=TBlockType(ppufile.getbyte);
        ppufile.getposinfo(fileinfo);
        ppufile.getset(tppuset5(localswitches));
        verbosity:=ppufile.getlongint;
        ppufile.getderef(resultdefderef);
        ppufile.getset(tppuset2(flags));
        { updated by firstpass }
        expectloc:=LOC_INVALID;
        { updated by secondpass }
        location.loc:=LOC_INVALID;
      end;


    procedure TNode.ppuwrite(ppufile:TCompilerPPUFile);
      begin
        ppufile.putbyte(byte(blocktype));
        ppufile.putposinfo(fileinfo);
        ppufile.putset(tppuset5(localswitches));
        ppufile.putlongint(verbosity);
        ppufile.putderef(resultdefderef);
        ppufile.putset(tppuset2(flags));
      end;


    function TNode.getppuidx:longint;
      begin
        if fppuidx=0 then
          begin
            inc(nodeppuidx);
            fppuidx:=nodeppuidx;
          end;
         result:=fppuidx;
       end;


    procedure TNode.resolveppuidx;
      begin
      end;


    procedure TNode.buildderefimpl;
      begin
        resultdefderef.build(resultdef);
      end;


    procedure TNode.derefimpl;
      begin
        resultdef:=TDef(resultdefderef.resolve);
      end;


    procedure TNode.toggleflag(f : TNodeFlag);
      begin
         if f in flags then
           exclude(flags,f)
         else
           include(flags,f);
      end;


    function TNode.simplify(forinline : boolean) : TNode;
      begin
        result:=nil;
      end;


    destructor TNode.destroy;
      begin
         if assigned(optinfo) then
           dispose(optinfo);
      end;


    function TNode.ischild(p : TNode) : boolean;
      begin
         ischild:=false;
      end;


    procedure TNode.mark_write;
      begin
{$ifdef EXTDEBUG}
        Comment(V_Warning,'mark_write not implemented for '+nodetype2str[nodetype]);
{$endif EXTDEBUG}
      end;


    procedure TNode.printnodeinfo(var t:text);
      var
        i : TNodeFlag;
        first : boolean;
      begin
        write(t,nodetype2str[nodetype]);
        if assigned(resultdef) then
          write(t,', resultdef = ',resultdef.typesymbolprettyname,' = "',resultdef.GetTypeName,'" ')
        else
          write(t,', resultdef = <nil> ');
        printfileinfo(t,fileinfo);
	write(t,', loc = ',tcgloc2str[location.loc],
                  ', expectloc = ',tcgloc2str[expectloc],
                  ', flags = [');
        first:=true;
        for i:=low(TNodeFlag) to high(TNodeFlag) do
          if i in flags then
            begin
              if not(first) then
                write(t,',')
              else
                first:=false;
              write(t, i);
            end;
        write(t,']');
        if (tnf_pass1_done in transientflags) then
          write(t,', cmplx = ',node_complexity(self));
        if assigned(optinfo) then
          write(t,', optinfo = ',HexStr(optinfo));
      end;


    procedure TNode.printnodedata(var t:text);
      begin
      end;


    procedure TNode.printnodetree(var t:text);
      begin
         write(t,printnodeindention,'(');
         printnodeinfo(t);
         writeln(t);
         printnodeindent;
         printnodedata(t);
         printnodeunindent;
         writeln(t,printnodeindention,')');
      end;

{$ifdef DEBUG_NODE_XML}
    { For writing nodes to XML files - do not call directly, but
      instead call XMLPrintNode to write a complete tree }
    procedure TNode.XMLPrintNodeInfo(var T: Text);
      var
        i_nf: TNodeFlag;
        i_tnf: TTransientNodeFlag;
        first: Boolean;
      begin
        if Assigned(resultdef) then
          Write(T,' resultdef="', SanitiseXMLString(resultdef.typesymbolprettyname), '"');

        Write(T,' pos="',fileinfo.line,',',fileinfo.column);

        First := True;
        for i_nf in flags do
          begin
            if First then
              begin
                Write(T, '" flags="', i_nf);
                First := False;
              end
            else
              Write(T, ',', i_nf)
          end;

        First := True;
        for i_tnf in transientflags do
          begin
            if First then
              begin
                Write(T, '" transientflags="', i_tnf);
                First := False;
              end
            else
              Write(T, ',', i_tnf)
          end;
        write(T,'"');

        if (tnf_pass1_done in transientflags) then
          write(t,' complexity="',node_complexity(self),'"');
      end;

    procedure TNode.XMLPrintNodeData(var T: Text);
      begin
        { Nothing by default }
      end;

    procedure TNode.XMLPrintNodeTree(var T: Text);
      begin
        Write(T, PrintNodeIndention, '<', nodetype2str[nodetype]);
        XMLPrintNodeInfo(T);
        WriteLn(T, '>');
        PrintNodeIndent;
        XMLPrintNodeData(T);
        PrintNodeUnindent;
        WriteLn(T, PrintNodeIndention, '</', nodetype2str[nodetype], '>');
      end;
{$endif DEBUG_NODE_XML}

    function TNode.isequal(p : TNode) : boolean;
      begin
         isequal:=
           (not assigned(self) and not assigned(p)) or
           (assigned(self) and assigned(p) and
            { optimized subclasses have the same nodetype as their        }
            { superclass (for compatibility), so also check the classtype (JM) }
            (p.classtype=classtype) and
            (p.nodetype=nodetype) and
            (flags*flagsequal=p.flags*flagsequal) and
            (transientflags*transientflagsequal=p.transientflags*transientflagsequal) and
            docompare(p));
      end;

{$ifdef state_tracking}
    function TNode.track_state_pass(exec_known:boolean):boolean;
      begin
        track_state_pass:=false;
      end;
{$endif state_tracking}


    function TNode.docompare(p : TNode) : boolean;
      begin
         docompare:=true;
      end;


    function cleanupcopiedto(var n : TNode;arg : pointer) : foreachnoderesult;
      begin
        result:=fen_true;
        if n.nodetype=labeln then
          tlabelnode(n).copiedto:=nil;
      end;


    function setuplabelnode(var n : TNode;arg : pointer) : foreachnoderesult;
      begin
        result:=fen_true;
        if (n.nodetype=goton) and assigned(tgotonode(n).labelnode) and
          assigned(tgotonode(n).labelnode.copiedto) then
          tgotonode(n).labelnode:=tgotonode(n).labelnode.copiedto;
      end;


    function TNode.getcopy : TNode;
      begin
        result:=dogetcopy;
        foreachnodestatic(pm_postprocess,result,@setuplabelnode,nil);
        foreachnodestatic(pm_postprocess,self,@cleanupcopiedto,nil);
      end;


    function TNode.dogetcopy : TNode;
      var
         p : TNode;
      begin
         { this is quite tricky because we need a node of the current }
         { node type and not one of tnode!                            }
         p:=TNodeClass(classtype).createforcopy;
         p.nodetype:=nodetype;
         p.expectloc:=expectloc;
         p.location:=location;
         p.flags:=flags;
         p.transientflags:=transientflags;
         p.resultdef:=resultdef;
         p.fileinfo:=fileinfo;
         p.localswitches:=localswitches;
         p.verbosity:=verbosity;
{         p.list:=list; }
         result:=p;
      end;


    procedure TNode.insertintolist(l : TNodeList);
      begin
      end;


    { ensures that the optimizer info record is allocated }
    function TNode.allocoptinfo : poptinfo;inline;
      begin
        if not(assigned(optinfo)) then
          begin
            new(optinfo);
            fillchar(optinfo^,sizeof(optinfo^),0);
          end;
        result:=optinfo;
      end;

{****************************************************************************
                                 TUNARYNODE
 ****************************************************************************}

    constructor TUnaryNode.create(t:TNodeType;l : TNode);
      begin
         inherited create(t);
         { transfer generic paramater flag }
         if assigned(l) and (nf_generic_para in l.flags) then
           include(flags,nf_generic_para);
         left:=l;
      end;


    constructor TUnaryNode.ppuload(t:TNodeType;ppufile:TCompilerPPUFile);
      begin
        inherited ppuload(t,ppufile);
        left:=ppuloadnode(ppufile);
      end;


    destructor TUnaryNode.destroy;
      begin
        left.free;
        left := nil;
        inherited destroy;
      end;


    procedure TUnaryNode.ppuwrite(ppufile:TCompilerPPUFile);
      begin
        inherited ppuwrite(ppufile);
        ppuwritenode(ppufile,left);
      end;


    procedure TUnaryNode.buildderefimpl;
      begin
        inherited buildderefimpl;
        if assigned(left) then
          left.buildderefimpl;
      end;


    procedure TUnaryNode.derefimpl;
      begin
        inherited derefimpl;
        if assigned(left) then
          left.derefimpl;
      end;


    function TUnaryNode.docompare(p : TNode) : boolean;
      begin
         docompare:=(inherited docompare(p) and
           ((left=nil) or left.isequal(TUnaryNode(p).left))
         );
      end;


    function TUnaryNode.dogetcopy : TNode;
      var
         p : TUnaryNode;
      begin
         p:=TUnaryNode(inherited dogetcopy);
         if assigned(left) then
           p.left:=left.dogetcopy
         else
           p.left:=nil;
         result:=p;
      end;


    procedure TUnaryNode.insertintolist(l : TNodeList);
      begin
      end;


    procedure TUnaryNode.printnodedata(var t:text);
      begin
         inherited printnodedata(t);
         printnode(t,left);
      end;

{$ifdef DEBUG_NODE_XML}
    procedure TUnaryNode.XMLPrintNodeData(var T: Text);
      begin
         inherited XMLPrintNodeData(T);
         XMLPrintNode(T, Left);
      end;
{$endif DEBUG_NODE_XML}

    function TUnaryNode.ischild(p : TNode) : boolean;
      begin
         ischild:=p=left;
      end;


    { Marks the current node for deletion and sets 'left' to nil.
      Returns what 'left' was previously set to }
    function TUnaryNode.PruneKeepLeft: TNode; {$IFDEF USEINLINE}inline;{$endif USEINLINE}
      begin
        Result := left;
        left := nil;
        Include(transientflags, tnf_do_not_execute);
      end;


{****************************************************************************
                            TBINARYNODE
 ****************************************************************************}

    constructor TBinaryNode.create(t:TNodeType;l,r : TNode);
      begin
         inherited create(t,l);
         { transfer generic paramater flag }
         if assigned(r) and (nf_generic_para in r.flags) then
           include(flags,nf_generic_para);
         right:=r;
      end;


    constructor TBinaryNode.ppuload(t:TNodeType;ppufile:TCompilerPPUFile);
      begin
        inherited ppuload(t,ppufile);
        right:=ppuloadnode(ppufile);
      end;


    destructor TBinaryNode.destroy;
      begin
        right.free;
        right := nil;
        inherited destroy;
      end;


    procedure TBinaryNode.ppuwrite(ppufile:TCompilerPPUFile);
      begin
        inherited ppuwrite(ppufile);
        ppuwritenode(ppufile,right);
      end;


    procedure TBinaryNode.buildderefimpl;
      begin
        inherited buildderefimpl;
        if assigned(right) then
          right.buildderefimpl;
      end;


    procedure TBinaryNode.derefimpl;
      begin
        inherited derefimpl;
        if assigned(right) then
          right.derefimpl;
      end;


    function TBinaryNode.ischild(p : TNode) : boolean;
      begin
         ischild:=(p=right);
      end;


    function TBinaryNode.docompare(p : TNode) : boolean;
      begin
         docompare:=(inherited docompare(p) and
             ((right=nil) or right.isequal(TBinaryNode(p).right))
         );
      end;


    function TBinaryNode.dogetcopy : TNode;
      var
         p : TBinaryNode;
      begin
         p:=TBinaryNode(inherited dogetcopy);
         if assigned(right) then
           p.right:=right.dogetcopy
         else
           p.right:=nil;
         result:=p;
      end;


    procedure TBinaryNode.insertintolist(l : TNodeList);
      begin
      end;


    procedure TBinaryNode.swapleftright;
      var
         swapp : TNode;
      begin
         swapp:=right;
         right:=left;
         left:=swapp;
         if nf_swapped in flags then
           exclude(flags,nf_swapped)
         else
           include(flags,nf_swapped);
      end;


    procedure TBinaryNode.printnodedata(var t:text);
      begin
         inherited printnodedata(t);
         printnode(t,right);
      end;

{$ifdef DEBUG_NODE_XML}
    procedure TBinaryNode.XMLPrintNodeTree(var T: Text);
      begin
        Write(T, PrintNodeIndention, '<', nodetype2str[nodetype]);
        XMLPrintNodeInfo(T);
        WriteLn(T, '>');
        PrintNodeIndent;
        XMLPrintNodeData(T);
      end;


    procedure TBinaryNode.XMLPrintNodeData(var T: Text);
      begin
        inherited XMLPrintNodeData(T);
        PrintNodeUnindent;
        WriteLn(T, PrintNodeIndention, '</', nodetype2str[nodetype], '>');
        { Right nodes are on the same indentation level }
        XMLPrintNode(T, Right);
      end;
{$endif DEBUG_NODE_XML}

    procedure TBinaryNode.printnodelist(var t:text);
      var
        hp : TBinaryNode;
      begin
        hp:=self;
        while assigned(hp) do
         begin
           write(t,printnodeindention,'(');
           printnodeindent;
           hp.printnodeinfo(t);
           writeln(t);
           printnode(t,hp.left);
           writeln(t);
           printnodeunindent;
           writeln(t,printnodeindention,')');
           hp:=TBinaryNode(hp.right);
         end;
      end;


    { Marks the current node for deletion and sets 'right' to nil.
      Returns what 'right' was previously set to }
    function TBinaryNode.PruneKeepRight: TNode; {$IFDEF USEINLINE}inline;{$endif USEINLINE}
      begin
        Result := right;
        right := nil;
        Include(transientflags, tnf_do_not_execute);
      end;


{****************************************************************************
                                 TTERTIARYNODE
 ****************************************************************************}

    constructor TTertiaryNode.create(_t:TNodeType;l,r,t : TNode);
      begin
         inherited create(_t,l,r);
         { transfer generic parameter flag }
         if assigned(t) and (nf_generic_para in t.flags) then
           include(flags,nf_generic_para);
         third:=t;
      end;


    constructor TTertiaryNode.ppuload(t:TNodeType;ppufile:TCompilerPPUFile);
      begin
        inherited ppuload(t,ppufile);
        third:=ppuloadnode(ppufile);
      end;


    destructor TTertiaryNode.destroy;
      begin
        third.free;
        third := nil;
        inherited destroy;
      end;


    procedure TTertiaryNode.ppuwrite(ppufile:TCompilerPPUFile);
      begin
        inherited ppuwrite(ppufile);
        ppuwritenode(ppufile,third);
      end;


    procedure TTertiaryNode.buildderefimpl;
      begin
        inherited buildderefimpl;
        if assigned(third) then
          third.buildderefimpl;
      end;


    procedure TTertiaryNode.derefimpl;
      begin
        inherited derefimpl;
        if assigned(third) then
          third.derefimpl;
      end;


    function TTertiaryNode.docompare(p : TNode) : boolean;
      begin
         docompare:=(inherited docompare(p) and
           ((third=nil) or third.isequal(TTertiaryNode(p).third))
         );
      end;


    function TTertiaryNode.dogetcopy : TNode;
      var
         p : TTertiaryNode;
      begin
         p:=TTertiaryNode(inherited dogetcopy);
         if assigned(third) then
           p.third:=third.dogetcopy
         else
           p.third:=nil;
         result:=p;
      end;


    procedure TTertiaryNode.insertintolist(l : TNodeList);
      begin
      end;


    procedure TTertiaryNode.printnodedata(var t:text);
      begin
         inherited printnodedata(t);
         printnode(t,third);
      end;

{$ifdef DEBUG_NODE_XML}
    procedure TTertiaryNode.XMLPrintNodeData(var T: Text);
      begin
         if Assigned(Third) then
           begin
             WriteLn(T, PrintNodeIndention, '<third-branch>');
             PrintNodeIndent;
             XMLPrintNode(T, Third);
             PrintNodeUnindent;
             WriteLn(T, PrintNodeIndention, '</third-branch>');
           end;

         inherited XMLPrintNodeData(T);
      end;
{$endif DEBUG_NODE_XML}

    function TTertiaryNode.ischild(p : TNode) : boolean;
      begin
         ischild:=p=third;
      end;


    { Marks the current node for deletion and sets 'third' to nil.
      Returns what 'third' was previously set to }
    function TTertiaryNode.PruneKeepThird: TNode; {$IFDEF USEINLINE}inline;{$endif USEINLINE}
      begin
        Result := third;
        third := nil;
        Include(transientflags, tnf_do_not_execute);
      end;


{****************************************************************************
                            TBINOPNODE
 ****************************************************************************}

    constructor TBinOpNode.create(t:TNodeType;l,r : TNode);
      begin
         inherited create(t,l,r);
      end;


    function TBinOpNode.docompare(p : TNode) : boolean;
      begin
         docompare:=(inherited docompare(p)) or
           { if that's in the flags, is p then always a tbinopnode (?) (JM) }
           ((tnf_swapable in transientflags) and
            left.isequal(TBinOpNode(p).right) and
            right.isequal(TBinOpNode(p).left));
      end;

{$ifdef DEBUG_NODE_XML}
    procedure TBinOpNode.XMLPrintNodeData(var T: Text);
      begin
        { For binary operations, put the left and right branches on the same level for clarity }
        XMLPrintNode(T, Left);
        XMLPrintNode(T, Right);
        PrintNodeUnindent;
        WriteLn(T, PrintNodeIndention, '</', nodetype2str[nodetype], '>');
      end;
{$endif DEBUG_NODE_XML}

var
  printfileinfo_address : pointer;
  printnode_address : pointer;

begin
{$push}{$warnings off}
  { tvaroption must fit into a 4 byte set for speed reasons }
  if ord(high(TVarOption))>31 then
    internalerror(201110301);
(*  { tnodeflags must fit into a 4 byte set for speed reasons }
  if ord(high(tnodeflags))>31 then
    internalerror(2014020701); *)
{$pop}
  printfileinfo_address:=@dprintfileinfo;
  printnode_address:=@dprintnode;
end.

