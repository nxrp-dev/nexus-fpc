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
       CClasses,
       GlobType,Globals,cgbase,cgutils,
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
        NodeType2Str : array[TNodeType] of string[24] = (
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
      cNodeTypeConst = [niln,
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
       FlagsEqual : TNodeFlags = [];
       TransientFlagsEqual : TTransientNodeFlags = [tnf_error];

    type
      TNodeList = class
      end;

      PNode = ^TNode;
      { basic class for the intermediated representation fpc uses }
      TNode = class
      private
         FPPUIdx : LongInt;
         function GetPPUIdx:LongInt;
      public
         { type of this node }
         NodeType : TNodeType;
         { type of the current code block, general/const/type }
         BlockType : TBlockType;
         { expected location of the result of this node (pass1) }
         ExpectLoc : TCGLoc;
         { the location of the result of this node (pass2) }
         Location : TLocation;
         { next node in control flow on the same block level, i.e.
           for loop nodes, this is the next node after the end of the loop,
           same for if and case, if this field is nil, the next node is the procedure exit,
           for the last node in a loop this is set to the loop header
           this field is set only for control flow nodes }
         Successor : TNode;
         { there are some properties about the node stored }
         Flags  : TNodeFlags;
         TransientFlags : TTransientNodeFlags;
         ResultDef     : TDef;
         ResultDefDeref : TDeref;
         FileInfo      : TFilePosInfo;
         LocalSwitches : TLocalSwitches;
         Verbosity     : LongInt;
         OptInfo : POptInfo;
         constructor Create(ANodeType:TNodeType);
         { this constructor is only for creating copies of class }
         { the fields are copied by getcopy                      }
         constructor CreateForCopy;
         constructor PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);virtual;
         destructor Destroy;override;
         procedure PPUWrite(APPUFile:TCompilerPPUFile);virtual;
         procedure BuildDerefImpl;virtual;
         procedure DerefImpl;virtual;
         procedure ResolvePPUIdx;virtual;

         { toggles the flag }
         procedure ToggleFlag(AFlag : TNodeFlag);

         { the 1.1 code generator may override pass_1 }
         { and it need not to implement det_* then    }
         { 1.1: pass_1 returns a value<>0 if the node has been transformed }
         { 2.0: runs pass_typecheck and det_temp                           }
         function Pass_1 : TNode;virtual;abstract;
         { dermines the resultdef of the node }
         function Pass_TypeCheck : TNode;virtual;abstract;

         { tries to simplify the node, returns a value <>nil if a simplified
           node has been created }
         function Simplify(AForInline : Boolean) : TNode;virtual;
         { For a t1:=t2 tree, mark the part of the tree t1 that gets
           written to (normally the loadnode) as write access. }
         procedure Mark_Write;virtual;
         { dermines the number of necessary temp. locations to evaluate
           the node }
         procedure Det_Temp;virtual;abstract;

         procedure Pass_Generate_Code;virtual;abstract;

         { comparing of nodes }
         function IsEqual(ANode : TNode) : Boolean;
         { to implement comparison, override this method }
         function DoCompare(ANode : TNode) : Boolean;virtual;
         { wrapper for getcopy }
         function GetCopy : TNode;

         { does the real copying of a node }
         function DoGetCopy : TNode;virtual;

         procedure InsertIntoList(AList : TNodeList);virtual;
         { writes a node for debugging purpose, shouldn't be called }
         { direct, because there is no test for nil, use printnode  }
         { to write a complete tree }
         procedure PrintNodeInfo(var AText:Text);virtual;
         procedure PrintNodeData(var AText:Text);virtual;
         procedure PrintNodeTree(var AText:Text);virtual;
         function IsChild(ANode : TNode) : Boolean;virtual;

         { ensures that the optimizer info record is allocated }
         function AllocOptInfo : POptInfo;inline;
         property PPUIdx:LongInt read GetPPUIdx;
      end;

      TNodeClass = class of TNode;

      TNodeClassArray = array[TNodeType] of TNodeClass;

      { this node is the ancestor for all nodes with at least    }
      { one child, you have to use it if you want to use         }
      { true- and current_procinfo.CurrFalseLabel                                     }
      //punarynode = ^tunarynode;
      TUnaryNode = class(TNode)
         Left : TNode;
         constructor Create(ANodeType:TNodeType;ALeft : TNode);
         constructor PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);override;
         destructor Destroy;override;
         procedure PPUWrite(APPUFile:TCompilerPPUFile);override;
         procedure BuildDerefImpl;override;
         procedure DerefImpl;override;
         function IsChild(ANode : TNode) : Boolean;override;
         function DoCompare(ANode : TNode) : Boolean;override;
         function DoGetCopy : TNode;override;
         procedure InsertIntoList(AList : TNodeList);override;
         procedure PrintNodeData(var AText:Text);override;
         { Marks the current node for deletion and sets 'left' to nil.
           Returns what 'left' was previously set to }
         function PruneKeepLeft: TNode; {$ifdef USEINLINE}inline;{$endif USEINLINE}
      end;

      //pbinarynode = ^tbinarynode;
      TBinaryNode = class(TUnaryNode)
         Right : TNode;
         constructor Create(ANodeType:TNodeType;ALeft,ARight : TNode);
         constructor PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);override;
         destructor Destroy;override;
         procedure PPUWrite(APPUFile:TCompilerPPUFile);override;
         procedure BuildDerefImpl;override;
         procedure DerefImpl;override;
         function IsChild(ANode : TNode) : Boolean;override;
         function DoCompare(ANode : TNode) : Boolean;override;
         procedure SwapLeftRight;
         function DoGetCopy : TNode;override;
         procedure InsertIntoList(AList : TNodeList);override;
         procedure PrintNodeData(var AText:Text);override;
         procedure PrintNodeList(var AText:Text);
         { Marks the current node for deletion and sets 'right' to nil.
           Returns what 'right' was previously set to }
         function PruneKeepRight: TNode; {$IFDEF USEINLINE}inline;{$endif USEINLINE}
      end;

      //ptertiarynode = ^ttertiarynode;
      TTertiaryNode = class(TBinaryNode)
         Third : TNode;
         constructor Create(ANodeType:TNodeType;ALeft,ARight,AThird : TNode);
         constructor PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);override;
         destructor Destroy;override;
         procedure PPUWrite(APPUFile:TCompilerPPUFile);override;
         procedure BuildDerefImpl;override;
         procedure DerefImpl;override;
         function IsChild(ANode : TNode) : Boolean;override;
         function DoCompare(ANode : TNode) : Boolean;override;
         function DoGetCopy : TNode;override;
         procedure InsertIntoList(AList : TNodeList);override;
         procedure PrintNodeData(var AText:Text);override;
         { Marks the current node for deletion and sets 'third' to nil.
           Returns what 'third' was previously set to }
         function PruneKeepThird: TNode; {$IFDEF USEINLINE}inline;{$endif USEINLINE}
      end;

      TBinOpNode = class(TBinaryNode)
         constructor Create(ANodeType:TNodeType;ALeft,ARight : TNode);virtual;
         function DoCompare(ANode : TNode) : Boolean;override;
      end;

    var
      { array with all class types for tnodes }
      NodeClass : TNodeClassArray;

    function NodePPUIdxGet(AIndex:LongInt):TNode;
    function PPULoadNode(APPUFile:TCompilerPPUFile):TNode;
    procedure PPUWriteNode(APPUFile:TCompilerPPUFile;ANode:TNode);
    function PPULoadNodeTree(APPUFile:TCompilerPPUFile):TNode;
    procedure PPUWriteNodeTree(APPUFile:TCompilerPPUFile;ANode:TNode);

    procedure PrintFileInfo(var AText:Text;APos:TFilePosInfo);
    procedure DPrintFileInfo(APos:TFilePosInfo);
    procedure PrintNode(var AText:Text;ANode:TNode);
    procedure DPrintNode(ANode:TNode);
    function Is_ConstNode(ANode : TNode) : Boolean;
    function Is_ConstIntNode(ANode : TNode) : Boolean;
    function Is_ConstCharNode(ANode : TNode) : Boolean;
    function Is_ConstRealNode(ANode : TNode) : Boolean;
    function Is_ConstBoolNode(ANode : TNode) : Boolean;
    function Is_ConstEnumNode(ANode : TNode) : Boolean;
    function Is_ConstWideCharNode(ANode : TNode) : Boolean;
    function Is_ConstPointerNode(ANode : TNode) : Boolean;
    function Is_ConstStringNode(ANode : TNode) : Boolean;
    function Is_ConstWideStringNode(ANode : TNode) : Boolean;
    function Is_ConstString_Or_ConstCharNode(ANode : TNode) : Boolean;


implementation

    uses
       Verbose,EntFile,
       FinPut,CompHook,
       PPU,FModule,
       symconst,
       nutils,nflw,
       defutil;

    const
      cPPUNodeMarker = 255;


{****************************************************************************
                                 Helpers
 ****************************************************************************}

    var
      NodePPUList : TFPObjectList;
      NodePPUIdx  : LongInt;


    procedure NodePPUIdxCreate;
      begin
        NodePPUList:=TFPObjectList.Create(false);
        NodePPUIdx:=0;
      end;


    procedure NodePPUIdxResolve;
      var
        lIndex : LongInt;
        lNode : TNode;
      begin
        for lIndex:=0 to NodePPUList.count-1 do
          begin
            lNode:=TNode(NodePPUList[lIndex]);
            if Assigned(lNode) then
              lNode.ResolvePPUIdx;
          end;
      end;


    procedure NodePPUIdxFree;
      begin
        NodePPUList.free;
        NodePPUList:=nil;
        NodePPUIdx:=0;
      end;


    procedure NodePPUIdxAdd(ANode:TNode);
      var
        lIndex : LongInt;
      begin
        lIndex:=ANode.PPUIdx;
        if lIndex<=0 then
          InternalError(200311072);
        if lIndex>=NodePPUList.capacity then
          NodePPUList.capacity:=((lIndex div 1024)+1)*1024;
        if lIndex>=NodePPUList.count then
          NodePPUList.count:=lIndex+1;
        NodePPUList[lIndex]:=ANode;
      end;


    function NodePPUIdxGet(AIndex:LongInt):TNode;
      begin
        if AIndex<=0 then
          InternalError(200311073);
        Result:=TNode(NodePPUList[AIndex]);
      end;


    function PPULoadNode(APPUFile:TCompilerPPUFile):TNode;
      var
        lMarker : Byte;
        lNodeType : TNodeType;
        lPPUIdx : LongInt;
      begin
        { marker }
        lMarker:=APPUFile.GetByte;
        if lMarker<>cPPUNodeMarker then
          InternalError(200208151);
        { load nodetype }
        lNodeType:=TNodeType(APPUFile.GetByte);
        if lNodeType>high(TNodeType) then
          InternalError(200208152);
        if lNodeType<>emptynode then
         begin
           if not Assigned(NodeClass[lNodeType]) then
             InternalError(200208153);
           lPPUIdx:=APPUFile.GetLongInt;
           //writeln('load: ',nodetype2str[t]);
           { generate node of the correct class }
           Result:=NodeClass[lNodeType].PPULoad(lNodeType,APPUFile);
           Result.FPPUIdx:=lPPUIdx;
           NodePPUIdxAdd(Result);
         end
        else
         Result:=nil;
      end;


    procedure PPUWriteNode(APPUFile:TCompilerPPUFile;ANode:TNode);
      begin
        { marker, read by ppuloadnode }
        APPUFile.PutByte(cPPUNodeMarker);
        { type, read by ppuloadnode }
        if Assigned(ANode) then
         begin
           APPUFile.PutByte(Byte(ANode.NodeType));
           APPUFile.PutLongInt(ANode.PPUIdx);
           //writeln('write: ',nodetype2str[n.nodetype]);
           ANode.PPUWrite(APPUFile);
         end
        else
         APPUFile.PutByte(Byte(emptynode));
      end;


    function PPULoadNodeTree(APPUFile:TCompilerPPUFile):TNode;
      begin
        if APPUFile.ReadEntry<>IBNodeTree then
          Message(unit_f_ppu_read_error);
        NodePPUIdxCreate;
        Result:=PPULoadNode(APPUFile);
        NodePPUIdxResolve;
        NodePPUIdxFree;
      end;


    procedure PPUWriteNodeTree(APPUFile:TCompilerPPUFile;ANode:TNode);
      begin
        NodePPUIdxCreate;
        PPUWriteNode(APPUFile,ANode);
        APPUFile.WriteEntry(IBNodeTree);
        NodePPUIdxFree;
      end;


    procedure PrintNode(var AText:Text;ANode:TNode);
      begin
        if Assigned(ANode) then
         ANode.PrintNodeTree(AText)
        else
         WriteLn(AText,PrintNodeIndention,'nil');
      end;


    procedure DPrintNode(ANode:TNode);
      begin
        PrintNode(Output,ANode);
      end;

    procedure PrintFileInfo(var AText:Text; APos:TFilePosInfo);
      var
	lFileName : string;
	lModule : TModule;
	lFile : TInputFile;
      begin
        lFileName:='inconsistent';
	lModule:=Get_Module(APos.moduleindex);
	if Assigned(lModule) then
          begin
            lFile:=lModule.SourceFiles.Get_File(APos.fileindex);
	    if Assigned(lFile) then
              lFileName:=lFile.name;
	  end;
        write(AText,'(',lFileName,':',APos.line,',',APos.column,')');
      end;

    procedure DPrintFileInfo(APos:TFilePosInfo);
      begin
        PrintFileInfo(Output,APos);
      end;


    function Is_ConstNode(ANode : TNode) : Boolean;
      begin
        Is_ConstNode:=(ANode.NodeType in cNodeTypeConst);
      end;


    function Is_ConstIntNode(ANode : TNode) : Boolean;
      begin
         Is_ConstIntNode:=(ANode.NodeType=ordconstn) and Is_Integer(ANode.ResultDef);
      end;


    function Is_ConstCharNode(ANode : TNode) : Boolean;
      begin
         Is_ConstCharNode:=(ANode.NodeType=ordconstn) and Is_Char(ANode.ResultDef);
      end;


    function Is_ConstWideCharNode(ANode : TNode) : Boolean;
      begin
         Is_ConstWideCharNode:=(ANode.NodeType=ordconstn) and Is_WideChar(ANode.ResultDef);
      end;


    function Is_ConstRealNode(ANode : TNode) : Boolean;
      begin
         Is_ConstRealNode:=(ANode.NodeType=realconstn);
      end;


    function Is_ConstBoolNode(ANode : TNode) : Boolean;
      begin
         Is_ConstBoolNode:=(ANode.NodeType=ordconstn) and Is_Boolean(ANode.ResultDef);
      end;


    function Is_ConstEnumNode(ANode : TNode) : Boolean;
      begin
         Is_ConstEnumNode:=(ANode.NodeType=ordconstn) and (ANode.ResultDef.typ=enumdef);
      end;


    function Is_ConstPointerNode(ANode : TNode) : Boolean;
      begin
         Is_ConstPointerNode:=(ANode.NodeType in [pointerconstn,niln]);
      end;

    function Is_ConstStringNode(ANode : TNode) : Boolean;
      begin
         Is_ConstStringNode :=
           (ANode.NodeType = stringconstn) and
           (Is_CharArray(ANode.ResultDef) or
            Is_ShortString(ANode.ResultDef) or
            Is_AnsiString(ANode.ResultDef));
      end;

    function Is_ConstWideStringNode(ANode : TNode) : Boolean;
      begin
         Is_ConstWideStringNode :=
           (ANode.NodeType = stringconstn) and
           (Is_WideCharArray(ANode.ResultDef) or
            Is_Wide_Or_Unicode_String(ANode.ResultDef));
      end;

    function Is_ConstString_Or_ConstCharNode(ANode : TNode) : Boolean;
      begin
        Is_ConstString_Or_ConstCharNode :=
          Is_ConstStringNode(ANode) or Is_ConstCharNode(ANode) or
          Is_ConstWideStringNode(ANode) or Is_ConstWideCharNode(ANode);
      end;


{****************************************************************************
                                 TNODE
 ****************************************************************************}

    constructor TNode.Create(ANodeType:TNodeType);

      begin
         inherited Create;
         NodeType:=ANodeType;
         BlockType:=Block_Type;
         { updated by firstpass }
         ExpectLoc:=LOC_INVALID;
         { updated by secondpass }
         Location.Loc:=LOC_INVALID;
         { save local info }
         FileInfo:=CurrentFilePos;
         LocalSwitches:=CurrentSettings.LocalSwitches;
         Verbosity:=status.Verbosity;
         ResultDef:=nil;
         Flags:=[];
      end;

    constructor TNode.CreateForCopy;

      begin
      end;

    constructor TNode.PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);

      begin
        NodeType:=ANodeType;
        { tnode fields }
        BlockType:=TBlockType(APPUFile.GetByte);
        APPUFile.GetPosInfo(FileInfo);
        APPUFile.GetSet(TPPUSet5(LocalSwitches));
        Verbosity:=APPUFile.GetLongInt;
        APPUFile.GetDeref(ResultDefDeref);
        APPUFile.GetSet(TPPUSet2(Flags));
        { updated by firstpass }
        ExpectLoc:=LOC_INVALID;
        { updated by secondpass }
        Location.Loc:=LOC_INVALID;
      end;


    procedure TNode.PPUWrite(APPUFile:TCompilerPPUFile);
      begin
        APPUFile.PutByte(Byte(BlockType));
        APPUFile.PutPosInfo(FileInfo);
        APPUFile.PutSet(TPPUSet5(LocalSwitches));
        APPUFile.PutLongInt(Verbosity);
        APPUFile.PutDeref(ResultDefDeref);
        APPUFile.PutSet(TPPUSet2(Flags));
      end;


    function TNode.GetPPUIdx:LongInt;
      begin
        if FPPUIdx=0 then
          begin
            inc(NodePPUIdx);
            FPPUIdx:=NodePPUIdx;
          end;
         Result:=FPPUIdx;
       end;


    procedure TNode.ResolvePPUIdx;
      begin
      end;


    procedure TNode.BuildDerefImpl;
      begin
        ResultDefDeref.Build(ResultDef);
      end;


    procedure TNode.DerefImpl;
      begin
        ResultDef:=TDef(ResultDefDeref.resolve);
      end;


    procedure TNode.ToggleFlag(AFlag : TNodeFlag);
      begin
         if AFlag in Flags then
           exclude(Flags,AFlag)
         else
           include(Flags,AFlag);
      end;


    function TNode.Simplify(AForInline : Boolean) : TNode;
      begin
        Result:=nil;
      end;


    destructor TNode.Destroy;
      begin
         if Assigned(OptInfo) then
           dispose(OptInfo);
      end;


    function TNode.IsChild(ANode : TNode) : Boolean;
      begin
         IsChild:=false;
      end;


    procedure TNode.Mark_Write;
      begin
{$ifdef EXTDEBUG}
        Comment(VWarning,'mark_write not implemented for '+NodeType2Str[NodeType]);
{$endif EXTDEBUG}
      end;


    procedure TNode.PrintNodeInfo(var AText:Text);
      var
        lNodeFlag : TNodeFlag;
        lFirst : Boolean;
      begin
        write(AText,NodeType2Str[NodeType]);
        if Assigned(ResultDef) then
          write(AText,', resultdef = ',ResultDef.TypeSymbolPrettyName,' = "',ResultDef.GetTypeName,'" ')
        else
          write(AText,', resultdef = <nil> ');
        PrintFileInfo(AText,FileInfo);
	write(AText,', loc = ',TCGLoc2Str[Location.Loc],
                  ', expectloc = ',TCGLoc2Str[ExpectLoc],
                  ', flags = [');
        lFirst:=true;
        for lNodeFlag:=low(TNodeFlag) to high(TNodeFlag) do
          if lNodeFlag in Flags then
            begin
              if not(lFirst) then
                write(AText,',')
              else
                lFirst:=false;
              write(AText, lNodeFlag);
            end;
        write(AText,']');
        if (tnf_pass1_done in TransientFlags) then
          write(AText,', cmplx = ',Node_Complexity(self));
        if Assigned(OptInfo) then
          write(AText,', optinfo = ',HexStr(OptInfo));
      end;


    procedure TNode.PrintNodeData(var AText:Text);
      begin
      end;


    procedure TNode.PrintNodeTree(var AText:Text);
      begin
         write(AText,PrintNodeIndention,'(');
         PrintNodeInfo(AText);
         WriteLn(AText);
         PrintNodeIndent;
         PrintNodeData(AText);
         PrintNodeUnindent;
         WriteLn(AText,PrintNodeIndention,')');
      end;


    function TNode.IsEqual(ANode : TNode) : Boolean;
      begin
         IsEqual:=
           (not Assigned(self) and not Assigned(ANode)) or
           (Assigned(self) and Assigned(ANode) and
            { optimized subclasses have the same nodetype as their        }
            { superclass (for compatibility), so also check the classtype (JM) }
            (ANode.classtype=classtype) and
            (ANode.NodeType=NodeType) and
            (Flags*FlagsEqual=ANode.Flags*FlagsEqual) and
            (TransientFlags*TransientFlagsEqual=ANode.TransientFlags*TransientFlagsEqual) and
            DoCompare(ANode));
      end;



    function TNode.DoCompare(ANode : TNode) : Boolean;
      begin
         DoCompare:=true;
      end;


    function CleanupCopiedTo(var ANode : TNode;AArg : Pointer) : TForEachNodeResult;
      begin
        Result:=fen_true;
        if ANode.NodeType=labeln then
          TLabelNode(ANode).CopiedTo:=nil;
      end;


    function SetupLabelNode(var ANode : TNode;AArg : Pointer) : TForEachNodeResult;
      begin
        Result:=fen_true;
        if (ANode.NodeType=goton) and Assigned(TGotoNode(ANode).LabelNode) and
          Assigned(TGotoNode(ANode).LabelNode.CopiedTo) then
          TGotoNode(ANode).LabelNode:=TGotoNode(ANode).LabelNode.CopiedTo;
      end;


    function TNode.GetCopy : TNode;
      begin
        Result:=DoGetCopy;
        ForEachNodeStatic(pm_postprocess,Result,@SetupLabelNode,nil);
        ForEachNodeStatic(pm_postprocess,self,@CleanupCopiedTo,nil);
      end;


    function TNode.DoGetCopy : TNode;
      var
         lCopy : TNode;
      begin
         { this is quite tricky because we need a node of the current }
         { node type and not one of tnode!                            }
         lCopy:=TNodeClass(classtype).CreateForCopy;
         lCopy.NodeType:=NodeType;
         lCopy.ExpectLoc:=ExpectLoc;
         lCopy.Location:=Location;
         lCopy.Flags:=Flags;
         lCopy.TransientFlags:=TransientFlags;
         lCopy.ResultDef:=ResultDef;
         lCopy.FileInfo:=FileInfo;
         lCopy.LocalSwitches:=LocalSwitches;
         lCopy.Verbosity:=Verbosity;
{         p.list:=list; }
         Result:=lCopy;
      end;


    procedure TNode.InsertIntoList(AList : TNodeList);
      begin
      end;


    { ensures that the optimizer info record is allocated }
    function TNode.AllocOptInfo : POptInfo;inline;
      begin
        if not(Assigned(OptInfo)) then
          begin
            new(OptInfo);
            fillchar(OptInfo^,sizeof(OptInfo^),0);
          end;
        Result:=OptInfo;
      end;

{****************************************************************************
                                 TUNARYNODE
 ****************************************************************************}

    constructor TUnaryNode.Create(ANodeType:TNodeType;ALeft : TNode);
      begin
         inherited Create(ANodeType);
         { transfer generic paramater flag }
         if Assigned(ALeft) and (nf_generic_para in ALeft.Flags) then
           include(Flags,nf_generic_para);
         Left:=ALeft;
      end;


    constructor TUnaryNode.PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);
      begin
        inherited PPULoad(ANodeType,APPUFile);
        Left:=PPULoadNode(APPUFile);
      end;


    destructor TUnaryNode.Destroy;
      begin
        Left.free;
        Left := nil;
        inherited Destroy;
      end;


    procedure TUnaryNode.PPUWrite(APPUFile:TCompilerPPUFile);
      begin
        inherited PPUWrite(APPUFile);
        PPUWriteNode(APPUFile,Left);
      end;


    procedure TUnaryNode.BuildDerefImpl;
      begin
        inherited BuildDerefImpl;
        if Assigned(Left) then
          Left.BuildDerefImpl;
      end;


    procedure TUnaryNode.DerefImpl;
      begin
        inherited DerefImpl;
        if Assigned(Left) then
          Left.DerefImpl;
      end;


    function TUnaryNode.DoCompare(ANode : TNode) : Boolean;
      begin
         DoCompare:=(inherited DoCompare(ANode) and
           ((Left=nil) or Left.IsEqual(TUnaryNode(ANode).Left))
         );
      end;


    function TUnaryNode.DoGetCopy : TNode;
      var
         lCopy : TUnaryNode;
      begin
         lCopy:=TUnaryNode(inherited DoGetCopy);
         if Assigned(Left) then
           lCopy.Left:=Left.DoGetCopy
         else
           lCopy.Left:=nil;
         Result:=lCopy;
      end;


    procedure TUnaryNode.InsertIntoList(AList : TNodeList);
      begin
      end;


    procedure TUnaryNode.PrintNodeData(var AText:Text);
      begin
         inherited PrintNodeData(AText);
         PrintNode(AText,Left);
      end;


    function TUnaryNode.IsChild(ANode : TNode) : Boolean;
      begin
         IsChild:=ANode=Left;
      end;


    { Marks the current node for deletion and sets 'left' to nil.
      Returns what 'left' was previously set to }
    function TUnaryNode.PruneKeepLeft: TNode; {$IFDEF USEINLINE}inline;{$endif USEINLINE}
      begin
        Result := Left;
        Left := nil;
        Include(TransientFlags, tnf_do_not_execute);
      end;


{****************************************************************************
                            TBINARYNODE
 ****************************************************************************}

    constructor TBinaryNode.Create(ANodeType:TNodeType;ALeft,ARight : TNode);
      begin
         inherited Create(ANodeType,ALeft);
         { transfer generic paramater flag }
         if Assigned(ARight) and (nf_generic_para in ARight.Flags) then
           include(Flags,nf_generic_para);
         Right:=ARight;
      end;


    constructor TBinaryNode.PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);
      begin
        inherited PPULoad(ANodeType,APPUFile);
        Right:=PPULoadNode(APPUFile);
      end;


    destructor TBinaryNode.Destroy;
      begin
        Right.free;
        Right := nil;
        inherited Destroy;
      end;


    procedure TBinaryNode.PPUWrite(APPUFile:TCompilerPPUFile);
      begin
        inherited PPUWrite(APPUFile);
        PPUWriteNode(APPUFile,Right);
      end;


    procedure TBinaryNode.BuildDerefImpl;
      begin
        inherited BuildDerefImpl;
        if Assigned(Right) then
          Right.BuildDerefImpl;
      end;


    procedure TBinaryNode.DerefImpl;
      begin
        inherited DerefImpl;
        if Assigned(Right) then
          Right.DerefImpl;
      end;


    function TBinaryNode.IsChild(ANode : TNode) : Boolean;
      begin
         IsChild:=(ANode=Right);
      end;


    function TBinaryNode.DoCompare(ANode : TNode) : Boolean;
      begin
         DoCompare:=(inherited DoCompare(ANode) and
             ((Right=nil) or Right.IsEqual(TBinaryNode(ANode).Right))
         );
      end;


    function TBinaryNode.DoGetCopy : TNode;
      var
         lCopy : TBinaryNode;
      begin
         lCopy:=TBinaryNode(inherited DoGetCopy);
         if Assigned(Right) then
           lCopy.Right:=Right.DoGetCopy
         else
           lCopy.Right:=nil;
         Result:=lCopy;
      end;


    procedure TBinaryNode.InsertIntoList(AList : TNodeList);
      begin
      end;


    procedure TBinaryNode.SwapLeftRight;
      var
         lSwapNode : TNode;
      begin
         lSwapNode:=Right;
         Right:=Left;
         Left:=lSwapNode;
         if nf_swapped in Flags then
           exclude(Flags,nf_swapped)
         else
           include(Flags,nf_swapped);
      end;


    procedure TBinaryNode.PrintNodeData(var AText:Text);
      begin
         inherited PrintNodeData(AText);
         PrintNode(AText,Right);
      end;


    procedure TBinaryNode.PrintNodeList(var AText:Text);
      var
        lNode : TBinaryNode;
      begin
        lNode:=self;
        while Assigned(lNode) do
         begin
           write(AText,PrintNodeIndention,'(');
           PrintNodeIndent;
           lNode.PrintNodeInfo(AText);
           WriteLn(AText);
           PrintNode(AText,lNode.Left);
           WriteLn(AText);
           PrintNodeUnindent;
           WriteLn(AText,PrintNodeIndention,')');
           lNode:=TBinaryNode(lNode.Right);
         end;
      end;


    { Marks the current node for deletion and sets 'right' to nil.
      Returns what 'right' was previously set to }
    function TBinaryNode.PruneKeepRight: TNode; {$IFDEF USEINLINE}inline;{$endif USEINLINE}
      begin
        Result := Right;
        Right := nil;
        Include(TransientFlags, tnf_do_not_execute);
      end;


{****************************************************************************
                                 TTERTIARYNODE
 ****************************************************************************}

    constructor TTertiaryNode.Create(ANodeType:TNodeType;ALeft,ARight,AThird : TNode);
      begin
         inherited Create(ANodeType,ALeft,ARight);
         { transfer generic parameter flag }
         if Assigned(AThird) and (nf_generic_para in AThird.Flags) then
           include(Flags,nf_generic_para);
         Third:=AThird;
      end;


    constructor TTertiaryNode.PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);
      begin
        inherited PPULoad(ANodeType,APPUFile);
        Third:=PPULoadNode(APPUFile);
      end;


    destructor TTertiaryNode.Destroy;
      begin
        Third.free;
        Third := nil;
        inherited Destroy;
      end;


    procedure TTertiaryNode.PPUWrite(APPUFile:TCompilerPPUFile);
      begin
        inherited PPUWrite(APPUFile);
        PPUWriteNode(APPUFile,Third);
      end;


    procedure TTertiaryNode.BuildDerefImpl;
      begin
        inherited BuildDerefImpl;
        if Assigned(Third) then
          Third.BuildDerefImpl;
      end;


    procedure TTertiaryNode.DerefImpl;
      begin
        inherited DerefImpl;
        if Assigned(Third) then
          Third.DerefImpl;
      end;


    function TTertiaryNode.DoCompare(ANode : TNode) : Boolean;
      begin
         DoCompare:=(inherited DoCompare(ANode) and
           ((Third=nil) or Third.IsEqual(TTertiaryNode(ANode).Third))
         );
      end;


    function TTertiaryNode.DoGetCopy : TNode;
      var
         lCopy : TTertiaryNode;
      begin
         lCopy:=TTertiaryNode(inherited DoGetCopy);
         if Assigned(Third) then
           lCopy.Third:=Third.DoGetCopy
         else
           lCopy.Third:=nil;
         Result:=lCopy;
      end;


    procedure TTertiaryNode.InsertIntoList(AList : TNodeList);
      begin
      end;


    procedure TTertiaryNode.PrintNodeData(var AText:Text);
      begin
         inherited PrintNodeData(AText);
         PrintNode(AText,Third);
      end;


    function TTertiaryNode.IsChild(ANode : TNode) : Boolean;
      begin
         IsChild:=ANode=Third;
      end;


    { Marks the current node for deletion and sets 'third' to nil.
      Returns what 'third' was previously set to }
    function TTertiaryNode.PruneKeepThird: TNode; {$IFDEF USEINLINE}inline;{$endif USEINLINE}
      begin
        Result := Third;
        Third := nil;
        Include(TransientFlags, tnf_do_not_execute);
      end;


{****************************************************************************
                            TBINOPNODE
 ****************************************************************************}

    constructor TBinOpNode.Create(ANodeType:TNodeType;ALeft,ARight : TNode);
      begin
         inherited Create(ANodeType,ALeft,ARight);
      end;


    function TBinOpNode.DoCompare(ANode : TNode) : Boolean;
      begin
         DoCompare:=(inherited DoCompare(ANode)) or
           { if that's in the flags, is p then always a tbinopnode (?) (JM) }
           ((tnf_swapable in TransientFlags) and
            Left.IsEqual(TBinOpNode(ANode).Right) and
            Right.IsEqual(TBinOpNode(ANode).Left));
      end;


var
  PrintFileInfo_Address : Pointer;
  PrintNode_Address : Pointer;

begin
{$push}{$warnings off}
  { tvaroption must fit into a 4 byte set for speed reasons }
  if ord(high(TVarOption))>31 then
    InternalError(201110301);
(*  { tnodeflags must fit into a 4 byte set for speed reasons }
  if ord(high(tnodeflags))>31 then
    internalerror(2014020701); *)
{$pop}
  PrintFileInfo_Address:=@DPrintFileInfo;
  PrintNode_Address:=@DPrintNode;
end.

