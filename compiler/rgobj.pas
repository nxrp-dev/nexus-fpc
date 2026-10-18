{
    Copyright (c) 1998-2012 by the Free Pascal team

    This unit implements the base class for the register allocator

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

{$i fpcdefs.inc}

{ $define DEBUG_REGALLOC}
{ $define DEBUG_SPILLCOALESCE}
{ $define DEBUG_REGISTERLIFE}

{ Allow duplicate allocations, can be used to get the .s file written }
{ $define ALLOWDUPREG}


{$ifdef DEBUG_REGALLOC}
{$define EXTDEBUG}
{$endif DEBUG_REGALLOC}

unit rgobj;

  interface

    uses
      CUtils, CPUBase,
      AAsmTAI,AAsmData,AAsmSym,AAsmCPU,
      CClasses,GlobType,CGBase,CGUtils;

    const
      InterferenceBitmap2Size = 256;

    type
      {
        The interference bitmap contains of 2 layers:
          layer 1 - 256*256 blocks with pointers to layer 2 blocks
          layer 2 - blocks of 32*256 (32 bytes = 256 bits)
      }

      Tinterferencebitmap2 = array of set of Byte;
      Tinterferencebitmap1 = array[Byte] of TInterferenceBitmap2;
      tinterferencebitmap1Array = array of TInterferenceBitmap1;

      Tinterferencebitmap=class
      private
        MaxX1,
        MaxY1    : Byte;
        FBitmap  : TInterferenceBitmap1Array;
        function GetBitmap(X,Y:TSuperRegister):Boolean;
        procedure SetBitmap(X,Y:TSuperRegister;B:Boolean);
      public
        constructor Create;
        destructor Destroy;override;
        property Bitmap[X,Y:TSuperRegister]:Boolean read GetBitmap write SetBitmap;default;
      end;

      {In the register allocator we keep track of move instructions.
       These instructions are moved between five linked lists. There
       is also a linked list per register to keep track about the moves
       it is associated with. Because we need to determine quickly in
       which of the five lists it is we add anu enumeration to each
       move instruction.}

      Tmoveset=(ms_coalesced_moves,ms_constrained_moves,ms_frozen_moves,
                ms_worklist_moves,ms_active_moves);
      Tmoveins=class(TLinkedListItem)
        MoveSet:TMoveSet;
        X,Y:TSuperRegister;
        ID:LongInt;
      end;

      Tmovelistheader=record
        Count,
        MaxCount,
        SortedUntil : Cardinal;
      end;

      Tmovelist=record
        Header : TMoveListHeader;
        Data : array[TSuperRegister] of TMoveIns;
      end;
      Pmovelist=^TMoveList;

      Treginfoflag=(
        ri_coalesced,       { the register is coalesced with other register }
        ri_selected,        { the register is put to selectstack }
        ri_spill_helper,    { the register contains a value of a previously spilled register }
        ri_has_initial_loc  { the register has the initial memory location (e.g. a parameter in the stack) }
      );
      Treginfoflagset=set of TRegInfoFlag;

      Treginfo=record
        LiveStart,
        LiveEnd   : TAI;
        SubReg   : TSubRegister;
        Alias    : TSuperRegister;
        { The register allocator assigns each register a colour }
        Colour   : TSuperRegister;
        MoveList : PMoveList;
        AdjList  : PSuperRegisterWorkList;
        Degree   : TSuperRegister;
        Flags    : TRegInfoFlagSet;
        Weight   : LongInt;

        CountUses : LongInt;
        TotalInterferences : LongInt;
        RealRegInterferences: Word;
      end;
      // Preginfo=^TReginfo;
      TReginfoArray = Array of TRegInfo;

      TSpillRegInfo = record
        { a single register may appear more than once in an instruction,
          but with different subregister types -> store all subregister types
          that occur, so we can add the necessary constraints for the inline
          register that will have to replace it }
        SpillRegConstraints : set of TSubRegister;
        OrgReg : TSuperRegister;
        LoadReg,
        StoreReg: TRegister;
        RegRead, RegWritten, MustBeSpilled: Boolean;
      end;
      TSpillRegsInfo = record
        SpillRegInfoCount: LongInt;
        SpillRegInfo: array[0..3] of TSpillRegInfo;
      end;

//      Pspill_temp_list=^Tspill_temp_list;
      TSpillTempList = array of TReference;


      { used to store where a register is spilled and what interferences it has at the point of being spilled }
      TSpillInfo = record
        SpillLocation : TReference;
        Spilled : Boolean;
        Interferences : TInterferenceBitmap;
      end;

      {#------------------------------------------------------------------

      This class implements the default register allocator. It is used by the
      code generator to allocate and free registers which might be valid
      across nodes. It also contains utility routines related to registers.

      Some of the methods in this class should be overridden
      by cpu-specific implementations.

      --------------------------------------------------------------------}
       TRGObj=class
        PreservedByProc : TCPURegisterSet;
        UsedInProc : TCPURegisterSet;
        { generate SSA code? }
        SSASafe: Boolean;

        constructor Create(ARegType:TRegisterType;
                           ADefaultSub:TSubRegister;
                           const AUsable:array of TSuperRegister;
                           AFirstImaginary:TSuperRegister;
                           APreservedByProc:TCPURegisterSet);
        destructor Destroy;override;

        { Allocate a register. An internalerror will be generated if there is
         no more free registers which can be allocated.}
        function GetRegister(List:TAsmList;SubReg:TSubRegister):TRegister;virtual;
        { Get the register specified.}
        procedure GetCPURegister(List:TAsmList;R:TRegister);virtual;
        procedure UngetCPURegister(List:TAsmList;R:TRegister);virtual;
        { Get multiple registers specified.}
        procedure AllocCPURegisters(List:TAsmList;const R:TCPURegisterSet);virtual;
        { Free multiple registers specified.}
        procedure DeallocCPURegisters(List:TAsmList;const R:TCPURegisterSet);virtual;
        function Uses_Registers:Boolean;virtual;
        procedure Add_Reg_Instruction(Instr:TAI;R:TRegister;AWeight:LongInt);
        procedure Add_Move_Instruction(Instr:TAICPU);
        { Do the register allocation.}
        procedure Do_Register_Allocation(List:TAsmList;HeaderTAI:TAI);virtual;
        { Adds an interference edge.
          don't move this to the protected section, the arm cg requires to access this (FK) }
        procedure Add_Edge(U,V:TSuperRegister);
        { translates a single given imaginary register to it's real register }
        procedure Translate_Register(var Reg : TRegister);
        { sets the initial memory location of the register }
        procedure Set_Reg_Initial_Location(Reg: TRegister; const Ref: TReference);
      protected
        MaxRegInfo,
        MaxRegInfoInc,
        MaxReg            : TSuperRegister;

        RegType           : TRegisterType;
        { default subregister used }
        DefaultSub        : TSubRegister;
        LiveRegisters:TSuperRegisterWorkList;
        SpilledNodes: TSuperRegisterWorkList;

        { can be overridden to add cpu specific interferences }
        procedure Add_CPU_Interferences(P : TAI);virtual;
        procedure Add_Constraints(Reg:TRegister);virtual;
        function  GetRegisterInline(List:TAsmList;const SubRegConstraints:TSubRegisterSet):TRegister;
        procedure UngetRegisterInline(List:TAsmList;R:TRegister);
        function  Get_Spill_SubReg(R : TRegister) : TSubRegister;virtual;
        function  Do_Spill_Replace(List:TAsmList;Instr:TAICPUAbstractSym;OrgReg:TSuperRegister;const SpillTemp:TReference):Boolean;virtual;
        { the orgrsupeg parameter is only here for the llvm target, so it can
          discover the def to use for the load }
        procedure Do_Spill_Read(List:TAsmList;Pos:TAI;const SpillTemp:TReference;TempReg:TRegister;OrgSupReg:TSuperRegister);virtual;
        procedure Do_Spill_Written(List:TAsmList;Pos:TAI;const SpillTemp:TReference;TempReg:TRegister;OrgSupReg:TSuperRegister);virtual;

        function AddRegInfo(var SpRegs: TSpillRegsInfo; const R: TSuperRegisterSet; Reg: TRegister; Operation: TOperType): Boolean;
        function Instr_Get_Oper_Spilling_Info(var SpRegs: TSpillRegsInfo; const R: TSuperRegisterSet; Instr: TAICPUAbstractSym; OpIdx: LongInt): Boolean; virtual;
        procedure Substitute_Spilled_Registers(const SpRegs: TSpillRegsInfo; Instr: TAICPUAbstractSym; OpIdx: LongInt); virtual;
        procedure Try_Replace_Reg(const SpRegs: TSpillRegsInfo; var Reg: TRegister; UseLoadReg: Boolean);
        function Instr_Spill_Register(List:TAsmList;
                                      Instr:TAICPUAbstractSym;
                                      const R:TSuperRegisterSet;
                                      const SpillTempList:TSpillTempList): Boolean;virtual;
        procedure Insert_RegAlloc_Info_All(List:TAsmList);
        procedure Determine_Spill_Registers(List:TAsmList;HeaderTail:TAI); virtual;
        procedure Get_Spill_Temp(List:TAsmList;SpillTemps: TSpillTempList; SupReg: TSuperRegister);virtual;
      strict protected
        { Highest register allocated until now.}
        RegInfo           : TRegInfoArray;
        UsableRegistersCount : Word;
      private
        IntLiveRangeDirection: TRADirection;
        { First imaginary register.}
        FirstImaginary   : TSuperRegister;
        UsableRegisters  : array[0..MaxCPURegister] of TSuperRegister;
        UsableRegisterSet : TCPURegisterSet;
        IBitmap           : TInterferenceBitmap;
        SimplifyWorkList,
        FreezeWorkList,
        SpillWorkList,
        CoalescedNodes,
        SelectStack       : TSuperRegisterWorkList;
        WorkListMoves,
        ActiveMoves,
        FrozenMoves,
        CoalescedMoves,
        ConstrainedMoves,
        { in this list we collect all moveins which should be disposed after register allocation finishes,
          we still need the moves for spill coalesce for the whole register allocation process, so they cannot be
          released as soon as they are frozen or whatever }
        MoveGarbage : TLinkedList;
        ExtendedBackwards,
        BackwardsWasFirst : TBitSet;
        HasUsedMarks: Boolean;
        HasDirectAlloc: Boolean;
        SpillInfo : array of TSpillInfo;
        MoveInsIDCounter: LongInt;

        { Disposes of the reginfo array.}
        procedure Dispose_RegInfo;
        { Prepare the register colouring.}
        procedure Prepare_Colouring;
        { Clean up after register colouring.}
        procedure Epilogue_Colouring;
        { Colour the registers; that is do the register allocation.}
        procedure Colour_Registers;
        procedure Insert_RegAlloc_Info(List:TAsmList;U:TSuperRegister);
        procedure Generate_Interference_Graph(List:TAsmList;HeaderTAI:TAI);
        { sort spilled nodes by increasing number of interferences }
        procedure Sort_SpilledNodes;
        { translates the registers in the given assembler list }
        procedure Translate_Registers(List:TAsmList);
        function  Spill_Registers(List:TAsmList;HeaderTAI:TAI):Boolean;virtual;
        function  GetNewReg(SubReg:TSubRegister):TSuperRegister;
        procedure Add_Edges_Used(U:TSuperRegister);
        procedure Add_To_MoveList(U:TSuperRegister;Ins:TMoveIns);
        function Move_Related(N:TSuperRegister):Boolean;
        procedure Make_Work_List;
        procedure Sort_Simplify_WorkList;
        procedure Enable_Moves(N:TSuperRegister);
        procedure Decrement_Degree(M:TSuperRegister);
        procedure Simplify;
        procedure Add_WorkList(U:TSuperRegister);
        function Adjacent_Ok(U,V:TSuperRegister):Boolean;
        function Conservative(U,V:TSuperRegister):Boolean;
        procedure Coalesce;
        procedure Freeze_Moves(U:TSuperRegister);
        procedure Freeze;
        procedure Select_Spill;
        procedure Assign_Colours;
        procedure Clear_Interferences(U:TSuperRegister);
        procedure Set_Live_Range_Direction(Dir: TRADirection);
        procedure Set_Live_Start(Reg : TSuperRegister;T : TAI);
        function Get_Live_Start(Reg : TSuperRegister) : TAI;
        procedure Set_Live_End(Reg : TSuperRegister;T : TAI);
        function Get_Live_End(Reg : TSuperRegister) : TAI;
        procedure Alloc_SpillInfo(AMaxReg: TSuperRegister);
        { Remove p from the list and set p to the next element in the list }
        procedure Remove_AI(List:TAsmList; var P:TAI);
{$ifdef DEBUG_SPILLCOALESCE}
        procedure Write_Spill_Stats;
{$endif DEBUG_SPILLCOALESCE}
       public
{$ifdef EXTDEBUG}
        procedure WriteGraph(LoopIdx:LongInt);
{$endif EXTDEBUG}
        procedure Combine(U,V:TSuperRegister);
        { set v as an alias for u }
        procedure Set_Alias(U,V:TSuperRegister);
        function  Get_Alias(N:TSuperRegister):TSuperRegister;
        property LiveRangeDirection: TRADirection read IntLiveRangeDirection write Set_Live_Range_Direction;
        property LiveStart[Reg : TSuperRegister]: TAI read Get_Live_Start write Set_Live_Start;
        property LiveEnd[Reg : TSuperRegister]: TAI read Get_Live_End write Set_Live_End;
      end;

    const
      FirstReg = 0;
      LastReg = High(TSuperRegister)-1;
      MaxSpillingCounter = 20;


  implementation

    uses
      SysUtils,
      Globals,
      Verbose,TGObj,ProcInfo,CGObj;

    procedure SortMoveList(ML:PMoveList);

    var H,I,P:LongWord;
        T:TMoveIns;

    begin
      with ML^ do
        begin
          if Header.Count<2 then
            Exit;
          P:=LongWord(1) shl BsrDWord(Header.Count-1);
          repeat
            for H:=P to Header.Count-1 do
              begin
                I:=H;
                T:=Data[I];
                repeat
                  if Data[I-P].ID<=T.ID then
                    Break;
                  Data[I]:=Data[I-P];
                  Dec(I,P);
                until I<P;
                Data[I]:=T;
              end;
            P:=P shr 1;
          until P=0;
          Header.SortedUntil:=Header.Count-1;
        end;
    end;

{******************************************************************************
                              tinterferencebitmap
******************************************************************************}

    constructor TInterferenceBitmap.Create;
      begin
        inherited Create;
        MaxX1:=1;
        SetLength(FBitmap,2);
      end;


    destructor TInterferenceBitmap.Destroy;

    var I,J:Byte;

    begin
      for I:=0 to MaxX1 do
        for J:=0 to MaxY1 do
          if Assigned(FBitmap[I,J]) then
            FBitmap[I,J]:=nil;
      FBitmap:=nil;
    end;


    function TInterferenceBitmap.GetBitmap(X,Y:TSuperRegister):Boolean;
      var
        Page : TInterferenceBitmap2;
      begin
        Result:=False;
        if (X shr 8>MaxX1) then
          Exit;
        Page:=FBitmap[X shr 8,Y shr 8];
        Result:=Assigned(Page) and
          ((X and $ff) in Page[Y and $ff]);
      end;


    procedure TInterferenceBitmap.SetBitmap(X,Y:TSuperRegister;B:Boolean);
      var
        X1,Y1 : Byte;
      begin
        X1:=X shr 8;
        Y1:=Y shr 8;
        if X1>MaxX1 then
          begin
            SetLength(FBitmap,X1+1);
            MaxX1:=X1;
          end;
        if not Assigned(FBitmap[X1,Y1]) then
          begin
            if Y1>MaxY1 then
              MaxY1:=Y1;
            SetLength(FBitmap[X1,Y1],InterferenceBitmap2Size);
          end;
        if B then
          Include(FBitmap[X1,Y1][Y and $ff],(X and $ff))
        else
          Exclude(FBitmap[X1,Y1][Y and $ff],(X and $ff));
      end;


{******************************************************************************
                                trgobj
******************************************************************************}

    constructor TRGObj.Create(ARegType:TRegisterType;
                              ADefaultSub:TSubRegister;
                              const AUsable:array of TSuperRegister;
                              AFirstImaginary:TSuperRegister;
                              APreservedByProc:TCPURegisterSet);
       var
         I : Cardinal;
       begin
         { empty super register sets can cause very strange problems }
         if High(AUsable)=-1 then
           InternalError(200210181);
         LiveRangeDirection:=rad_forward;
         FirstImaginary:=AFirstImaginary;
         MaxReg:=AFirstImaginary;
         RegType:=ARegType;
         DefaultSub:=ADefaultSub;
         PreservedByProc:=APreservedByProc;
         // default values set by newinstance
         // used_in_proc:=[];
         // ssa_safe:=false;
         LiveRegisters.Init;
         { Get reginfo for CPU registers }
         MaxRegInfo:=FirstImaginary;
         MaxRegInfoInc:=16;
         MoveInsIDCounter:=0;
         WorkListMoves:=TLinkedList.Create;
         MoveGarbage:=TLinkedList.Create;
         SetLength(RegInfo,FirstImaginary);
         for I:=0 to FirstImaginary-1 do
           begin
             RegInfo[I].Degree:=High(TSuperRegister);
             RegInfo[I].Alias:=RSInvalid;
           end;
         { Usable registers }
         // default value set by constructor
         // fillchar(usable_registers,sizeof(usable_registers),0);
         for I:=Low(AUsable) to High(AUsable) do
           begin
             UsableRegisters[I]:=AUsable[I];
	     if (AUsable[I] in UsableRegisterSet) then
               InternalError(2025112601)
             else
               begin
                 Include(UsableRegisterSet,AUsable[I]);
                 Inc(UsableRegistersCount);
               end;
           end;
         { Initialize Worklists }
         SpilledNodes.Init;
         SimplifyWorkList.Init;
         FreezeWorkList.Init;
         SpillWorkList.Init;
         CoalescedNodes.Init;
         SelectStack.Init;
      end;


    destructor TRGObj.Destroy;
      begin
        SpilledNodes.Done;
        SimplifyWorkList.Done;
        FreezeWorkList.Done;
        SpillWorkList.Done;
        CoalescedNodes.Done;
        SelectStack.Done;
        LiveRegisters.Done;

        MoveGarbage.Free;
        MoveGarbage := nil;
        WorkListMoves.Free;
        WorkListMoves := nil;

        Dispose_RegInfo;
        ExtendedBackwards.Free;
        ExtendedBackwards := nil;
        BackwardsWasFirst.Free;
        BackwardsWasFirst := nil;
      end;


    procedure TRGObj.Dispose_RegInfo;
      var
        I : Cardinal;
      begin
        if RegInfo<>nil then
          begin
            for I:=0 to MaxReg-1 do
              with RegInfo[I] do
                begin
                  if AdjList<>nil then
                    Dispose(AdjList,Done);
                  if MoveList<>nil then
                    Dispose(MoveList);
                end;
            RegInfo:=nil;
          end;
      end;


    function TRGObj.GetNewReg(SubReg:TSubRegister):TSuperRegister;
      var
        OldMaxRegInfo : TSuperRegister;
      begin
        Result:=MaxReg;
        Inc(MaxReg);
        if MaxReg>=LastReg then
          Message(parser_f_too_complex_proc);
        if MaxReg>=MaxRegInfo then
          begin
            OldMaxRegInfo:=MaxRegInfo;
            { Prevent overflow }
            if MaxRegInfoInc>LastReg-MaxRegInfo then
              MaxRegInfo:=LastReg
            else
              begin
                Inc(MaxRegInfo,MaxRegInfoInc);
                if MaxRegInfoInc<256 then
                  MaxRegInfoInc:=MaxRegInfoInc*2;
              end;
            SetLength(RegInfo,MaxRegInfo);
          end;
        RegInfo[Result].SubReg:=SubReg;
      end;


    function TRGObj.GetRegister(List:TAsmList;SubReg:TSubRegister):TRegister;
      begin
        {$ifdef EXTDEBUG}
        if RegInfo=nil then
          InternalError(2004020901);
        {$endif EXTDEBUG}
        if DefaultSub=R_SUBNONE then
          Result:=NewReg(RegType,GetNewReg(R_SUBNONE),R_SUBNONE)
        else
          Result:=NewReg(RegType,GetNewReg(SubReg),SubReg);
      end;


    function TRGObj.Uses_Registers:Boolean;
      begin
        Result:=(MaxReg>FirstImaginary) or HasUsedMarks or HasDirectAlloc;
      end;


    procedure TRGObj.UngetCPURegister(List:TAsmList;R:TRegister);
      begin
        if (GetSupReg(R)>=FirstImaginary) then
          InternalError(2004020902);
        List.Concat(TAIRegAlloc.Dealloc(R,nil));
      end;


    procedure TRGObj.GetCPURegister(List:TAsmList;R:TRegister);
      var
        SupReg:TSuperRegister;
      begin
        SupReg:=GetSupReg(R);
        if SupReg>=FirstImaginary then
          InternalError(2003121503);
        Include(UsedInProc,SupReg);
        HasDirectAlloc:=True;
        List.Concat(TAIRegAlloc.Alloc(R,nil));
      end;


    procedure TRGObj.AllocCPURegisters(List:TAsmList;const R:TCPURegisterSet);

    var I:Cardinal;

    begin
      for I:=0 to FirstImaginary-1 do
        if I in R then
          GetCPURegister(List,NewReg(RegType,I,DefaultSub));
    end;


    procedure TRGObj.DeallocCPURegisters(List:TAsmList;const R:TCPURegisterSet);

    var I:Cardinal;

    begin
      for I:=0 to FirstImaginary-1 do
        if I in R then
          UngetCPURegister(List,NewReg(RegType,I,DefaultSub));
    end;

    var
      RTIndex : LongInt = 0;
    procedure TRGObj.Do_Register_Allocation(List:TAsmList;HeaderTAI:TAI);
      var
        SpillingCounter:LongInt;
        EndSpill:Boolean;
        I : LongInt;
      begin
        { Insert regalloc info for imaginary registers }
        Insert_RegAlloc_Info_All(List);
        IBitmap:=TInterferenceBitmap.Create;
        Generate_Interference_Graph(List,HeaderTAI);
{$ifdef DEBUG_SPILLCOALESCE}
        if MaxReg>FirstImaginary then
          WriteLn(CurrentProcInfo.ProcDef.MangledName, ': register allocation [',RegType,']');
{$endif DEBUG_SPILLCOALESCE}
{$ifdef DEBUG_REGALLOC}
        if MaxReg>FirstImaginary then
          WriteGraph(RTIndex);
{$endif DEBUG_REGALLOC}
        Inc(RTIndex);
        { Don't do the real allocation when -sr is passed }
        if (cs_no_regalloc in CurrentSettings.GlobalSwitches) then
          Exit;
        { Spill registers which interfere with all usable real registers.
          It is pointless to keep them for further processing. Also it may
          cause endless spilling.

          This can happen when compiling for very constrained CPUs such as
          i8086 where indexed memory access instructions allow only
          few registers as arguments and additionally the calling convention
          provides no general purpose volatile registers.

          Also spill registers which have the initial memory location
          and are used only once. This allows to access the memory location
          directly, without preloading it to a register.
        }
        for I:=FirstImaginary to MaxReg-1 do
          with RegInfo[I] do
            if (RealRegInterferences>=UsableRegistersCount) or
               { also spill registers which have the initial memory location
                 and are used only once }
               ((ri_has_initial_loc in Flags) and (Weight<=200)) then
              SpilledNodes.Add(I);
        if SpilledNodes.Length<>0 then
          begin
            Spill_Registers(List,HeaderTAI);
            SpilledNodes.Clear;
          end;
        {Do register allocation.}
        SpillingCounter:=0;
        repeat
          Determine_Spill_Registers(List,HeaderTAI);
          EndSpill:=True;
          if SpilledNodes.Length<>0 then
            begin
              Inc(SpillingCounter);
              if SpillingCounter>MaxSpillingCounter then
                begin
{$ifdef EXTDEBUG}
                  { Only exit here so the .s file is still generated. Assembling
                    the file will still trigger an error }
                  Exit;
{$else}
                  InternalError(200309041);
{$endif}
                end;
              EndSpill:=not Spill_Registers(List,HeaderTAI);
            end;
        until EndSpill;
        IBitmap.Free;
        IBitmap := nil;

        Translate_Registers(List);

{$ifdef DEBUG_SPILLCOALESCE}
        Write_Spill_Stats;
{$endif DEBUG_SPILLCOALESCE}

        { we need the translation table for debugging info and verbose assembler output,
          so not dispose them yet (FK)
        }

        for I:=0 to High(SpillInfo) do
          FreeAndNil(SpillInfo[I].Interferences);
        SpillInfo:=nil;
      end;


    procedure TRGObj.Add_Constraints(Reg:TRegister);

    begin
    end;


    procedure TRGObj.Add_Edge(U,V:TSuperRegister);

    {This procedure will add an edge to the virtual interference graph.}

      procedure AddAdj(U,V:TSuperRegister);

      begin
{$ifdef EXTDEBUG}
        if (U>=MaxRegInfo) then
          InternalError(2012101901);
{$endif}
        with RegInfo[U] do
          begin
            if AdjList=nil then
              New(AdjList,Init);
            AdjList^.Add(V);
            if (V<FirstImaginary) and
               (V in UsableRegisterSet) then
              Inc(RealRegInterferences);
          end;
      end;

    begin
      if (U<>V) and not(IBitmap[V,U]) then
        begin
          IBitmap[V,U]:=True;
          IBitmap[U,V]:=True;
          {Precoloured nodes are not stored in the interference graph.}
          if (U>=FirstImaginary) then
            AddAdj(U,V);
          if (V>=FirstImaginary) then
            AddAdj(V,U);
        end;
    end;


    procedure TRGObj.Add_Edges_Used(U:TSuperRegister);

    var I:Cardinal;

    begin
      with LiveRegisters do
        if Length>0 then
          for I:=0 to Length-1 do
            Add_Edge(U,Get_Alias(Buf[I]));
    end;

{$ifdef EXTDEBUG}
    procedure TRGObj.WriteGraph(LoopIdx:LongInt);

    {This procedure writes out the current interference graph in the
    register allocator.}


    var F:Text;
        I,J:Cardinal;
    begin
      Assign(F,OutputUnitDir+CurrentProcInfo.ProcDef.MangledName+'_igraph'+ToStr(LoopIdx));
      Rewrite(F);
      WriteLn(F,'Interference graph of ',CurrentProcInfo.ProcDef.FullProcName(True));
      WriteLn(F,'Register type: ',RegType,', First imaginary register is ',FirstImaginary,' ($',HexStr(FirstImaginary,2),')');
      WriteLn(F);
      write(F,'                                   ');
      for I:=0 to MaxReg div 16 do
        for J:=0 to 15 do
          write(F,HexStr(I,1));
      WriteLn(F);
      write(F,'Weight Degree Uses   IntfCnt       ');
      for I:=0 to MaxReg div 16 do
        write(F,'0123456789ABCDEF');
      WriteLn(F);
      for I:=0 to MaxReg-1 do
        begin
          write(F,RegInfo[I].Weight:5,'  ',RegInfo[I].Degree:5,'  ',RegInfo[I].CountUses:5,'  ',RegInfo[I].TotalInterferences:5,'  ');
          if (I<FirstImaginary) and
            (findreg_by_number(NewReg(RegType,TSuperRegister(I),DefaultSub))<>0) then
            write(F,std_regname(NewReg(RegType,TSuperRegister(I),DefaultSub))+':'+HexStr(I,2):7)
          else
            write(F,'   ',HexStr(I,2):4);
          for J:=0 to MaxReg-1 do
            if IBitmap[I,J] then
              write(F,'*')
            else
              write(F,'-');
          WriteLn(F);
        end;
      Close(F);
    end;
{$endif EXTDEBUG}

    procedure TRGObj.Add_To_MoveList(U:TSuperRegister;Ins:TMoveIns);
    begin
{$ifdef EXTDEBUG}
        if (U>=MaxRegInfo) then
          InternalError(2012101902);
{$endif}
      with RegInfo[U] do
        begin
          if MoveList=nil then
            begin
              { don't use sizeof(tmovelistheader), because that ignores alignment }
              GetMem(MoveList,PtrUInt(@MoveList^.Data)-PtrUInt(MoveList)+16*SizeOf(Pointer));
              MoveList^.Header.MaxCount:=16;
              MoveList^.Header.Count:=0;
              MoveList^.Header.SortedUntil:=0;
            end
          else
            begin
              if MoveList^.Header.Count>=MoveList^.Header.MaxCount then
                begin
                  MoveList^.Header.MaxCount:=MoveList^.Header.MaxCount*2;
                  { don't use sizeof(tmovelistheader), because that ignores alignment }
                  ReallocMem(MoveList,PtrUInt(@MoveList^.Data)-PtrUInt(MoveList)+MoveList^.Header.MaxCount*SizeOf(Pointer));
                end;
            end;
          MoveList^.Data[MoveList^.Header.Count]:=Ins;
          Inc(MoveList^.Header.Count);
        end;
    end;


    procedure TRGObj.Set_Live_Range_Direction(Dir: TRADirection);
      begin
        if (Dir in [rad_backwards,rad_backwards_reinit]) then
          begin
            if not Assigned(ExtendedBackwards) then
              begin
                { create expects a "size", not a "max bit" parameter -> +1 }
                BackwardsWasFirst:=TBitSet.Create(MaxReg+1);
                ExtendedBackwards:=TBitSet.Create(MaxReg+1);
              end
            else
              begin
                if (Dir=rad_backwards_reinit) then
                  ExtendedBackwards.Clear;
                BackwardsWasFirst.Clear;
              end;
            IntLiveRangeDirection:=rad_backwards;
          end
        else
          IntLiveRangeDirection:=rad_forward;
      end;


    procedure TRGObj.Set_Live_Start(Reg: TSuperRegister; T: TAI);
      begin
        RegInfo[Reg].LiveStart:=T;
      end;


    function TRGObj.Get_Live_Start(Reg: TSuperRegister): TAI;
      begin
        Result:=RegInfo[Reg].LiveStart;
      end;


    procedure TRGObj.Set_Live_End(Reg: TSuperRegister; T: TAI);
      begin
        RegInfo[Reg].LiveEnd:=T;
      end;


    function TRGObj.Get_Live_End(Reg: TSuperRegister): TAI;
      begin
        Result:=RegInfo[Reg].LiveEnd;
      end;


    procedure TRGObj.Alloc_SpillInfo(AMaxReg: TSuperRegister);
      var
        J: LongInt;
      begin
        if Length(SpillInfo)<AMaxReg then
          begin
            J:=Length(SpillInfo);
            SetLength(SpillInfo,AMaxReg);
            FillChar(SpillInfo[J],SizeOf(SpillInfo[0])*(Length(SpillInfo)-J),0);
          end;
      end;


    procedure TRGObj.Add_Reg_Instruction(Instr:TAI;R:TRegister;AWeight:LongInt);
      var
        SupReg : TSuperRegister;
      begin
        SupReg:=GetSupReg(R);
{$ifdef extdebug}
        if not (cs_no_regalloc in CurrentSettings.GlobalSwitches) and
           (SupReg>=MaxRegInfo) then
          InternalError(200411061);
{$endif extdebug}
        if SupReg>=FirstImaginary then
          with RegInfo[SupReg] do
            begin
              { avoid overflow }
              if High(Weight)-AWeight<Weight then
                Weight:=High(Weight)
              else
                Inc(Weight,AWeight);

              if (LiveRangeDirection=rad_forward) then
                begin
                  if not Assigned(LiveStart) then
                    LiveStart:=Instr;
                  LiveEnd:=Instr;
                end
               else
                 begin
                   if not ExtendedBackwards.IsSet(SupReg) then
                     begin
                       ExtendedBackwards.Include(SupReg);
                       LiveStart := Instr;
                       if not Assigned(LiveEnd) then
                         begin
                           BackwardsWasFirst.Include(SupReg);
                           LiveEnd := Instr;
                         end;
                     end
                   else
                     begin
                       if BackwardsWasFirst.IsSet(SupReg) then
                         LiveEnd := Instr;
                     end
                 end
            end;
      end;


    procedure TRGObj.Add_Move_Instruction(Instr:TAICPU);

    {This procedure notifies a certain as a move instruction so the
     register allocator can try to eliminate it.}

    var I:TMoveIns;
        SReg, DReg : TRegister;
        SSupReg,DSupReg:TSuperRegister;

    begin
    {$ifdef extdebug}
      if (Instr.Oper[O_MOV_SOURCE]^.Typ<>top_reg) or
         (Instr.Oper[O_MOV_DEST]^.Typ<>top_reg) then
        InternalError(200311291);
    {$endif}
      SReg:=Instr.Oper[O_MOV_SOURCE]^.Reg;
      DReg:=Instr.Oper[O_MOV_DEST]^.Reg;
      { How should we handle m68k move %d0,%a0? }
      if (GetRegType(SReg)<>GetRegType(DReg)) then
        Exit;
      if MoveInsIDCounter=High(MoveInsIDCounter) then
        InternalError(2021112701);
      Inc(MoveInsIDCounter);
      I:=TMoveIns.Create;
      I.ID:=MoveInsIDCounter;
      I.MoveSet:=ms_worklist_moves;
      WorkListMoves.Insert(I);
      SSupReg:=GetSupReg(SReg);
      Add_To_MoveList(SSupReg,I);
      DSupReg:=GetSupReg(DReg);
      { On m68k move can mix address and integer registers,
        this leads to problems ... PM }
      if (SSupReg<>DSupReg) {and (getregtype(sreg)=getregtype(dreg))} then
        {Avoid adding the same move instruction twice to a single register.}
        Add_To_MoveList(DSupReg,I);
      I.X:=SSupReg;
      I.Y:=DSupReg;
    end;

    function TRGObj.Move_Related(N:TSuperRegister):Boolean;

    var I:Cardinal;

    begin
      Move_Related:=False;
      with RegInfo[N] do
        if MoveList<>nil then
          with MoveList^ do
            for I:=0 to Header.Count-1 do
              if TMoveIns(Data[I]).MoveSet in [ms_worklist_moves,ms_active_moves] then
                begin
                  Move_Related:=True;
                  Break;
                end;
    end;

    procedure TRGObj.Sort_Simplify_WorkList;

    {Sorts the simplifyworklist by the number of interferences the
     registers in it cause. This allows simplify to execute in
     constant time.

     Sort the list in the descending order, since items of simplifyworklist
     are retrieved from end to start and then items are added to selectstack.
     The selectstack list is also processed from end to start.

     Such way nodes with most interferences will get their colors first.
     Since degree of nodes in simplifyworklist before sorting is always
     less than the number of usable registers this should not trigger spilling
     and should lead to a better register allocation in some cases.
    }

    var P,H,I,LenI,LenT:LongWord;
        T:TSuperRegister;
        Adji,AdjT:PSuperRegisterWorkList;

    begin
      with SimplifyWorkList do
        begin
          if Length<2 then
            Exit;
          P:=LongWord(1) shl BsrDWord(Length-1);
          repeat
            for H:=P to Length-1 do
              begin
                I:=H;
                T:=Buf[I];
                AdjT:=RegInfo[Buf[I]].AdjList;
                LenT:=0;
                if AdjT<>nil then
                  LenT:=AdjT^.Length;
                repeat
                  Adji:=RegInfo[Buf[I-P]].AdjList;
                  LenI:=0;
                  if Adji<>nil then
                    LenI:=Adji^.Length;
                  if LenI>=LenT then
                    Break;
                  Buf[I]:=Buf[I-P];
                  Dec(I,P)
                until I<P;
                Buf[I]:=T;
              end;
            P:=P shr 1;
          until P=0;
        end;
    end;


    { sort spilled nodes by increasing number of interferences }
    procedure TRGObj.Sort_SpilledNodes;
      var
        P,H,I,LenI,LenT:LongWord;
        T:TSuperRegister;
        Adji,AdjT:PSuperRegisterWorkList;
      begin
        with SpilledNodes do
          begin
            if Length<2 then
              Exit;
            P:=LongWord(1) shl BsrDWord(Length-1);
            repeat
              for H:=P to Length-1 do
                begin
                  I:=H;
                  T:=Buf[I];
                  AdjT:=RegInfo[Buf[I]].AdjList;
                  LenT:=0;
                  if AdjT<>nil then
                    LenT:=AdjT^.Length;
                  repeat
                    Adji:=RegInfo[Buf[I-P]].AdjList;
                    LenI:=0;
                    if Adji<>nil then
                      LenI:=Adji^.Length;
                    if LenI<=LenT then
                      Break;
                    Buf[I]:=Buf[I-P];
                    Dec(I,P)
                  until I<P;
                  Buf[I]:=T;
                end;
              P:=P shr 1;
            until P=0;
          end;
      end;


    procedure TRGObj.Make_Work_List;

    var N:Cardinal;

    begin
      {If we have 7 cpu registers, and the degree of a node >= 7, we cannot
       assign it to any of the registers, thus it is significant.}
      for N:=FirstImaginary to MaxReg-1 do
        with RegInfo[N] do
          begin
            if AdjList=nil then
              Degree:=0
            else
              Degree:=AdjList^.Length;
            if Degree>=UsableRegistersCount then
              SpillWorkList.Add(N)
            else if Move_Related(N) then
              FreezeWorkList.Add(N)
            else if not(ri_coalesced in Flags) then
              SimplifyWorkList.Add(N);
          end;
      Sort_Simplify_WorkList;
    end;


    procedure TRGObj.Prepare_Colouring;
    begin
      Make_Work_List;
      ActiveMoves:=TLinkedList.Create;
      FrozenMoves:=TLinkedList.Create;
      CoalescedMoves:=TLinkedList.Create;
      ConstrainedMoves:=TLinkedList.Create;
      SelectStack.Clear;
    end;

    procedure TRGObj.Enable_Moves(N:TSuperRegister);

    var M:TLinkedListItem;
        I:Cardinal;

    begin
      with RegInfo[N] do
        if MoveList<>nil then
          for I:=0 to MoveList^.Header.Count-1 do
            begin
              M:=MoveList^.Data[I];
              if TMoveIns(M).MoveSet=ms_active_moves then
                begin
                  {Move m from the set active_moves to the set worklist_moves.}
                  ActiveMoves.Remove(M);
                  TMoveIns(M).MoveSet:=ms_worklist_moves;
                  WorkListMoves.Concat(M);
                end;
          end;
    end;

    procedure TRGObj.Decrement_Degree(M:TSuperRegister);

    var Adj : PSuperRegisterWorkList;
        N : TSuperRegister;
        D,I : Cardinal;

    begin
      with RegInfo[M] do
        begin
          D:=Degree;
          if D=0 then
            InternalError(200312151);
          Dec(Degree);
          if D=UsableRegistersCount then
            begin
              {Enable moves for m.}
              Enable_Moves(M);
              {Enable moves for adjacent.}
              Adj:=AdjList;
              if Adj<>nil then
                for I:=1 to Adj^.Length do
                  begin
                    N:=Adj^.Buf[I-1];
                    if RegInfo[N].Flags*[ri_selected,ri_coalesced]<>[] then
                      Enable_Moves(N);
                  end;
              {Remove the node from the spillworklist.}
              if not SpillWorkList.Delete(M) then
                InternalError(200310145);

              if Move_Related(M) then
                FreezeWorkList.Add(M)
              else
                SimplifyWorkList.Add(M);
            end;
        end;
    end;

    procedure TRGObj.Simplify;

    var Adj : PSuperRegisterWorkList;
        M,N : TSuperRegister;
        I : Cardinal;
    begin
      {We take the element with the least interferences out of the
       simplifyworklist. Since the simplifyworklist is now sorted, we
       no longer need to search, but we can simply take the first element.}
      M:=SimplifyWorkList.Get;

      {Push it on the selectstack.}
      SelectStack.Add(M);
      with RegInfo[M] do
        begin
          Include(Flags,ri_selected);
          Adj:=AdjList;
        end;
      if Adj<>nil then
        for I:=1 to Adj^.Length do
          begin
            N:=Adj^.Buf[I-1];
            if (N>=FirstImaginary) and
               (RegInfo[N].Flags*[ri_selected,ri_coalesced]=[]) then
              Decrement_Degree(N);
          end;
    end;

    function TRGObj.Get_Alias(N:TSuperRegister):TSuperRegister;

    begin
      if N>=MaxReg then
        InternalError(2021121201);
      while ri_coalesced in RegInfo[N].Flags do
        N:=RegInfo[N].Alias;
      Get_Alias:=N;
    end;

    procedure TRGObj.Add_WorkList(U:TSuperRegister);
      begin
        if (U>=FirstImaginary) and
           (not Move_Related(U)) and
           (RegInfo[U].Degree<UsableRegistersCount) then
          begin
            if not FreezeWorkList.Delete(U) then
              InternalError(200308161); {must be found}
            SimplifyWorkList.Add(U);
          end;
      end;


    function TRGObj.Adjacent_Ok(U,V:TSuperRegister):Boolean;

    {Check wether u and v should be coalesced. u is precoloured.}

      function Ok(T,R:TSuperRegister):Boolean;

      begin
        Ok:=(T<FirstImaginary) or
            (RegInfo[T].Degree<UsableRegistersCount) or
            IBitmap[R,T];
      end;

    var Adj : PSuperRegisterWorkList;
        I : Cardinal;
        N : TSuperRegister;

    begin
      with RegInfo[V] do
        begin
          Adjacent_Ok:=True;
          Adj:=AdjList;
          if Adj<>nil then
            for I:=1 to Adj^.Length do
              begin
                N:=Adj^.Buf[I-1];
                if (RegInfo[N].Flags*[ri_coalesced]=[]) and not Ok(N,U) then
                  begin
                    Adjacent_Ok:=False;
                    Break;
                  end;
              end;
        end;
    end;

    function TRGObj.Conservative(U,V:TSuperRegister):Boolean;

    var Adj : PSuperRegisterWorkList;
        Done : TSuperRegisterSet; {To prevent that we count nodes twice.}
        I,K:Cardinal;
        N : TSuperRegister;

    begin
      K:=0;
      SupRegSet_Reset(Done,False,MaxReg);
      with RegInfo[U] do
        begin
          Adj:=AdjList;
          if Adj<>nil then
            for I:=1 to Adj^.Length do
              begin
                N:=Adj^.Buf[I-1];
                if RegInfo[N].Flags*[ri_coalesced,ri_selected]=[] then
                  begin
                    SupRegSet_Include(Done,N);
                    if RegInfo[N].Degree>=UsableRegistersCount then
                      Inc(K);
                  end;
              end;
        end;
      Adj:=RegInfo[V].AdjList;
      if Adj<>nil then
        for I:=1 to Adj^.Length do
          begin
            N:=Adj^.Buf[I-1];
            if (U<FirstImaginary) and
               (N>=FirstImaginary) and
               not IBitmap[U,N] and
               (UsableRegistersCount-RegInfo[N].RealRegInterferences<=1) then
              begin
                { Do not coalesce if 'u' is the last usable real register available
                  for imaginary register 'n'. }
                Conservative:=False;
                Exit;
              end;
            if not SupRegSet_In(Done,N) and
               (RegInfo[N].Degree>=UsableRegistersCount) and
               (RegInfo[N].Flags*[ri_coalesced,ri_selected]=[]) then
              Inc(K);
          end;
      Conservative:=(K<UsableRegistersCount);
    end;

    procedure TRGObj.Set_Alias(U,V:TSuperRegister);

    begin
      { don't make registers that the register allocator shouldn't touch (such
        as stack and frame pointers) be aliases for other registers, because
        then it can propagate them and even start changing them if the aliased
        register gets changed }
      if ((U<FirstImaginary) and
          not(U in UsableRegisterSet)) or
         ((V<FirstImaginary) and
          not(V in UsableRegisterSet)) then
        Exit;
      Include(RegInfo[V].Flags,ri_coalesced);
      if RegInfo[V].Alias<>0 then
        InternalError(200712291);
      RegInfo[V].Alias:=Get_Alias(U);
      CoalescedNodes.Add(V);
    end;


    procedure TRGObj.Combine(U,V:TSuperRegister);

    var Adj : PSuperRegisterWorkList;
        OriginalUCount, I,N,P,Q:Cardinal;
        T : TSuperRegister;
        Searched:TMoveIns;
        Found : Boolean;

    begin
      if not FreezeWorkList.Delete(V) then
        SpillWorkList.Delete(V);
      CoalescedNodes.Add(V);
      Include(RegInfo[V].Flags,ri_coalesced);
      RegInfo[V].Alias:=U;

      {Combine both movelists. Since the movelists are sets, only add
       elements that are not already present. The movelists cannot be
       empty by definition; nodes are only coalesced if there is a move
       between them. To prevent quadratic time blowup (movelists of
       especially machine registers can get very large because of moves
       generated during calls) we need to go into disgusting complexity.

       (See tbs/tw2242 for an example that stresses this.)

       We want to sort the movelist to be able to search logarithmically.
       Unfortunately, sorting the movelist every time before searching
       is counter-productive, since the movelist usually grows with a few
       items at a time. Therefore, we split the movelist into a sorted
       and an unsorted part and search through both. If the unsorted part
       becomes too large, we sort.}
      if Assigned(RegInfo[U].MoveList) then
        begin
          {We have to weigh the cost of sorting the list against searching
           the cost of the unsorted part. I use factor of 8 here; if the
           number of items is less than 8 times the numer of unsorted items,
           we'll sort the list.}
          with RegInfo[U].MoveList^ do
            if Header.Count<8*(Header.Count-Header.SortedUntil) then
              SortMoveList(RegInfo[U].MoveList);
          if Assigned(RegInfo[V].MoveList) then
            begin
              OriginalUCount:=RegInfo[U].MoveList^.Header.Count;
              for N:=0 to RegInfo[V].MoveList^.Header.Count-1 do
                begin
                  {Binary search the sorted part of the list.}
                  Searched:=RegInfo[V].MoveList^.Data[N];
                  P:=0;
                  Q:=RegInfo[U].MoveList^.Header.SortedUntil;
                  I:=0;
                  if Q<>0 then
                    repeat
                      I:=(P+Q) shr 1;
                      if Searched.ID>RegInfo[U].MoveList^.Data[I].ID then
                        P:=I+1
                      else
                        Q:=I;
                    until P=Q;
                  with RegInfo[U].MoveList^ do
                    if Searched<>Data[I] then
                      begin
                        {Linear search the unsorted part of the list.}
                        Found:=False;
                        { no need to search the instructions we've already added
                          from v, we know we won't find a match there }
                        for I:=Header.SortedUntil+1 to OriginalUCount-1 do
                          if Searched.ID=Data[I].ID then
                            begin
                              Found:=True;
                              Break;
                            end;
                        if not Found then
                          Add_To_MoveList(U,Searched);
                      end;
                end;
            end;
        end;

      Enable_Moves(V);

      Adj:=RegInfo[V].AdjList;
      if Adj<>nil then
        for I:=1 to Adj^.Length do
          begin
            T:=Adj^.Buf[I-1];
            with RegInfo[T] do
              if not(ri_coalesced in Flags) then
                begin
                  {t has a connection to v. Since we are adding v to u, we
                   need to connect t to u. However, beware if t was already
                   connected to u...}
                  if (IBitmap[T,U]) and not (ri_selected in Flags) then
                    begin
                      {... because in that case, we are actually removing an edge
                       and the degree of t decreases.}
                      Decrement_Degree(T);
                      { if v is combined with a real register, retry
                        coalescing of interfering nodes since it may succeed now. }
                      if (U<FirstImaginary) and
                         (Adj^.Length>=UsableRegistersCount) and
                         (RegInfo[T].Degree>UsableRegistersCount) then
                        Enable_Moves(T);
                    end
                  else
                    begin
                      Add_Edge(T,U);
                      {We have added an edge to t and u. So their degree increases.
                       However, v is added to u. That means its neighbours will
                       no longer point to v, but to u instead. Therefore, only the
                       degree of u increases.}
                      if (U>=FirstImaginary) and not (ri_selected in Flags) then
                        Inc(RegInfo[U].Degree);
                    end;
                end;
          end;
      if (RegInfo[U].Degree>=UsableRegistersCount) and FreezeWorkList.Delete(U) then
        SpillWorkList.Add(U);
    end;


    procedure TRGObj.Coalesce;

    var M:TMoveIns;
        X,Y,U,V:Cardinal;

    begin
      M:=TMoveIns(WorkListMoves.GetFirst);
      X:=Get_Alias(M.X);
      Y:=Get_Alias(M.Y);
      if (Y<FirstImaginary) then
        begin
          U:=Y;
          V:=X;
        end
      else
        begin
          U:=X;
          V:=Y;
        end;
      if (U=V) then
        begin
          M.MoveSet:=ms_coalesced_moves;  {Already coalesced.}
          CoalescedMoves.Insert(M);
          Add_WorkList(U);
        end
      {Do u and v interfere? In that case the move is constrained. Two
       precoloured nodes interfere always. If v is precoloured, by the above
       code u is precoloured, thus interference...}
      else if (V<FirstImaginary) or IBitmap[U,V] then
        begin
          M.MoveSet:=ms_constrained_moves;  {Cannot coalesce yet...}
          ConstrainedMoves.Insert(M);
          Add_WorkList(U);
          Add_WorkList(V);
        end
      {Next test: is it possible and a good idea to coalesce?? Note: don't
       coalesce registers that should not be touched by the register allocator,
       such as stack/framepointers, because otherwise they can be changed }
      else if (((U<FirstImaginary) and Adjacent_Ok(U,V)) or
               Conservative(U,V)) and
              ((U>=FirstImaginary) or
               (U in UsableRegisterSet)) and
              ((V>=FirstImaginary) or
               (V in UsableRegisterSet)) then
        begin
          M.MoveSet:=ms_coalesced_moves;  {Move coalesced!}
          CoalescedMoves.Insert(M);
          Combine(U,V);
          Add_WorkList(U);
        end
      else
        begin
          M.MoveSet:=ms_active_moves;
          ActiveMoves.Insert(M);
        end;
    end;

    procedure TRGObj.Freeze_Moves(U:TSuperRegister);

    var I:Cardinal;
        M:TLinkedListItem;
        V,X,Y:TSuperRegister;

    begin
      if RegInfo[U].MoveList<>nil then
        for I:=0 to RegInfo[U].MoveList^.Header.Count-1 do
          begin
            M:=RegInfo[U].MoveList^.Data[I];
            if TMoveIns(M).MoveSet in [ms_worklist_moves,ms_active_moves] then
              begin
                X:=TMoveIns(M).X;
                Y:=TMoveIns(M).Y;
                if Get_Alias(Y)=Get_Alias(U) then
                  V:=Get_Alias(X)
                else
                  V:=Get_Alias(Y);
                {Move m from active_moves/worklist_moves to frozen_moves.}
                if TMoveIns(M).MoveSet=ms_active_moves then
                  ActiveMoves.Remove(M)
                else
                  WorkListMoves.Remove(M);
                TMoveIns(M).MoveSet:=ms_frozen_moves;
                FrozenMoves.Insert(M);

                if (V>=FirstImaginary) and not(Move_Related(V)) and
                   (RegInfo[V].Degree<UsableRegistersCount) then
                  begin
                    FreezeWorkList.Delete(V);
                    SimplifyWorkList.Add(V);
                  end;
              end;
          end;
    end;

    procedure TRGObj.Freeze;

    var N:TSuperRegister;

    begin
      { We need to take a random element out of the freezeworklist. We take
        the last element. Dirty code! }
      N:=FreezeWorkList.Get;
      {Add it to the simplifyworklist.}
      SimplifyWorkList.Add(N);
      Freeze_Moves(N);
    end;

{ $define SPILLING_NEW}
{$ifndef SPILLING_NEW}
{$define SPILLING_OLD}
{$endif SPILLING_NEW}
    procedure TRGObj.Select_Spill;
    var
      N : TSuperRegister;
      Adj : PSuperRegisterWorkList;
      MaxLength,MinLength,P,I :Word;
      MinWeight: LongInt;
      {$ifdef SPILLING_NEW}
      Dist: Double;
      {$endif}
    begin
{$ifdef SPILLING_NEW}
      { This new approach for selecting the next spill candidate takes care of the weight of a register:
        It spills the register with the lowest weight but only if it is expected that it results in convergence of
        register allocation. Convergence is expected if a register is spilled where the average of the active interferences
        - active interference means that the register is used in an instruction - is lower than
        the degree.

        Example (modify means read and the write):

        modify reg1

        loop:
          modify reg2
          modify reg3
          modify reg4
          modify reg5
          modify reg6
          modify reg7

        modify reg1

        In this example, all register have the same degree. However, spilling reg1 is most beneficial as it is used least. Furthermore,
        spilling reg1 is a step toward solving the coloring problem as the registers used during spilling will have a lower degree
        as no register are in use at the location where reg1 is spilled.
      }
      MinWeight:=High(LongInt);
      P:=0;
      with SpillWorkList do
        begin
          { Safe: This procedure is only called if length<>0 }
          for I:=0 to Length-1 do
            begin
              Adj:=RegInfo[Buf^[I]].AdjList;
              Dist:=Adj^.Length-RegInfo[Buf^[I]].TotalInterferences/RegInfo[Buf^[I]].CountUses;
              if Assigned(Adj) and
                (RegInfo[Buf^[I]].Weight<MinWeight) and
                (Dist>=1) and
                (RegInfo[Buf^[I]].Weight>0) then
                begin
                  P:=I;
                  MinWeight:=RegInfo[Buf^[I]].Weight;
                end;
            end;
          N:=Buf^[P];
          DeleteIdx(P);
        end;
{$endif SPILLING_NEW}
{$ifdef SPILLING_OLD}
      { We must look for the element with the most interferences in the
        spillworklist. This is required because those registers are creating
        the most conflicts and keeping them in a register will not reduce the
        complexity and even can cause the help registers for the spilling code
        to get too much conflicts with the result that the spilling code
        will never converge (PFV)

        We need a special processing for nodes with the ri_spill_helper flag set.
        These nodes contain a value of a previously spilled node.
        We need to avoid another spilling of ri_spill_helper nodes, since it will
        likely lead to an endless loop and the register allocation will fail.
      }
      MaxLength:=0;
      MinWeight:=High(LongInt);
      P:=High(P);
      with SpillWorkList do
        begin
          {Safe: This procedure is only called if length<>0}
          { Search for a candidate to be spilled, ignoring nodes with the ri_spill_helper flag set. }
          for I:=0 to Length-1 do
            if not(ri_spill_helper in RegInfo[Buf[I]].Flags) then
              begin
                Adj:=RegInfo[Buf[I]].AdjList;
                if Assigned(Adj) and
                   (
                    (Adj^.Length>MaxLength) or
                    ((Adj^.Length=MaxLength) and (RegInfo[Buf[I]].Weight<MinWeight))
                   ) then
                  begin
                    P:=I;
                    MaxLength:=Adj^.Length;
                    MinWeight:=RegInfo[Buf[I]].Weight;
                  end;
              end;

          if P=High(P) then
            begin
              { If no normal nodes found, then only ri_spill_helper nodes are present
                in the list. Finding the node with the least interferences and
                the least weight.
                This allows us to put the most restricted ri_spill_helper nodes
                to the top of selectstack so they will be the first to get
                a color assigned.
              }
              MinLength:=High(MaxLength);
              MinWeight:=High(MinWeight);
              P:=0;
              for I:=0 to Length-1 do
                begin
                  Adj:=RegInfo[Buf[I]].AdjList;
                  if Assigned(Adj) and
                     (
                      (Adj^.Length<MinLength) or
                      ((Adj^.Length=MinLength) and (RegInfo[Buf[I]].Weight<MinWeight))
                     ) then
                    begin
                      P:=I;
                      MinLength:=Adj^.Length;
                      MinWeight:=RegInfo[Buf[I]].Weight;
                    end;
                end;
            end;
          N:=Buf[P];
          DeleteIdx(P);
        end;
{$endif SPILLING_OLD}
      SimplifyWorkList.Add(N);
      Freeze_Moves(N);
    end;

    procedure TRGObj.Assign_Colours;

    {Assign_colours assigns the actual colours to the registers.}

    var
      ColouredNodes : TSuperRegisterSet;

      procedure Reset_Colours;
        var
          N : TSuperRegister;
        begin
          SpilledNodes.Clear;
          {Reset colours}
          for N:=0 to MaxReg-1 do
            RegInfo[N].Colour:=N;
          {Colour the cpu registers...}
          SupRegSet_Reset(ColouredNodes,False,MaxReg);
          for N:=0 to FirstImaginary-1 do
            SupRegSet_Include(ColouredNodes,N);
        end;

    function Colour_Register(N : TSuperRegister) : Boolean;
      var
        J,K : Cardinal;
        Adj : PSuperRegisterWorkList;
        AdjColours:set of 0..255;
        A,C : TSuperRegister;
        TmpR: TRegister;
      begin
        {Create a list of colours that we cannot assign to n.}
        AdjColours:=[];
        Adj:=RegInfo[N].AdjList;
        if Adj<>nil then
          for J:=0 to Adj^.Length-1 do
            begin
              A:=Get_Alias(Adj^.Buf[J]);
              if SupRegSet_In(ColouredNodes,A) and (RegInfo[A].Colour<=255) then
                Include(AdjColours,RegInfo[A].Colour);
            end;
        { FIXME: temp variable r is needed here to avoid Internal error 20060521 }
        {        while compiling the compiler. }
        TmpR:=NR_STACK_POINTER_REG;
        if (RegType=GetRegType(TmpR)) then
          Include(AdjColours,RS_STACK_POINTER_REG);
        {Assume a spill by default...}
        Result:=False;
        {Search for a colour not in this list.}
        for K:=0 to UsableRegistersCount-1 do
          begin
            C:=UsableRegisters[K];
            if not(C in AdjColours) then
              begin
                RegInfo[N].Colour:=C;
                Result:=True;
                SupRegSet_Include(ColouredNodes,N);
                Break;
              end;
          end;
        if not Result then
          SpilledNodes.Add(N);
      end;

    var
        I,K : Cardinal;
        N : TSuperRegister;
        SpillLoop : Boolean;
    begin
      Reset_Colours;
      {Now colour the imaginary registers on the select-stack.}
      SpillLoop:=False;
      for I:=SelectStack.Length downto 1 do
        begin
          N:=SelectStack.Buf[I-1];
          if not Colour_Register(N) and
            (ri_spill_helper in RegInfo[N].Flags) then
            begin
              { Register n is a helper register which holds the value
                of a previously spilled register. Register n must never
                be spilled. Report the spilling loop and break. }
              SpillLoop:=True;
              Break;
            end;
        end;

      if SpillLoop then
        begin
          { Spilling loop is detected when colouring registers using the select-stack order.
            Trying to eliminate this by using a different colouring order. }
          Reset_Colours;
          { To prevent spilling of helper registers it is needed to assign colours to them first. }
          for I:=SelectStack.Length downto 1 do
            begin
              N:=SelectStack.Buf[I-1];
              if ri_spill_helper in RegInfo[N].Flags then
                if not Colour_Register(N) then
                  { Can't colour the spill helper register n.
                    This can happen only when the code generator produces invalid code
                    or sue to incorrect node coalescing. }
                  InternalError(2021091001);
            end;
          { Assign colours for the rest of the registers }
          for I:=SelectStack.Length downto 1 do
            begin
              N:=SelectStack.Buf[I-1];
              if not (ri_spill_helper in RegInfo[N].Flags) then
                Colour_Register(N);
            end;
        end;

      {Finally colour the nodes that were coalesced.}
      for I:=1 to CoalescedNodes.Length do
        begin
          N:=CoalescedNodes.Buf[I-1];
          K:=Get_Alias(N);
          RegInfo[N].Colour:=RegInfo[K].Colour;
        end;
    end;

    procedure TRGObj.Colour_Registers;

    begin
      repeat
        if SimplifyWorkList.Length<>0 then
          Simplify
        else if not(WorkListMoves.Empty) then
          Coalesce
        else if FreezeWorkList.Length<>0 then
          Freeze
        else if SpillWorkList.Length<>0 then
          Select_Spill;
      until (SimplifyWorkList.Length=0) and
            WorkListMoves.Empty and
            (FreezeWorkList.Length=0) and
            (SpillWorkList.Length=0);
      Assign_Colours;
    end;

    procedure TRGObj.Epilogue_Colouring;
    begin
      { remove all items from the worklists, but do not free them, they are still needed for spill coalesce }

      MoveGarbage.ConcatList(WorkListMoves);

      MoveGarbage.ConcatList(ActiveMoves);
      ActiveMoves.Free;
      ActiveMoves:=nil;

      MoveGarbage.ConcatList(FrozenMoves);
      FrozenMoves.Free;
      FrozenMoves:=nil;

      MoveGarbage.ConcatList(CoalescedMoves);
      CoalescedMoves.Free;
      CoalescedMoves:=nil;

      MoveGarbage.ConcatList(ConstrainedMoves);
      ConstrainedMoves.Free;
      ConstrainedMoves:=nil;
    end;


    procedure TRGObj.Clear_Interferences(U:TSuperRegister);

    {Remove node u from the interference graph and remove all collected
     move instructions it is associated with.}

    var I : Word;
        V : TSuperRegister;
        Adj,Adj2 : PSuperRegisterWorkList;

    begin
      Adj:=RegInfo[U].AdjList;
      if Adj<>nil then
        begin
          for I:=1 to Adj^.Length do
            begin
              V:=Adj^.Buf[I-1];
              {Remove (u,v) and (v,u) from bitmap.}
              IBitmap[U,V]:=False;
              IBitmap[V,U]:=False;
              {Remove (v,u) from adjacency list.}
              Adj2:=RegInfo[V].AdjList;
              if Adj2<>nil then
                begin
                  Adj2^.Delete(U);
                  if Adj2^.Length=0 then
                    begin
                      Dispose(Adj2,Done);
                      RegInfo[V].AdjList:=nil;
                    end;
                end;
            end;
          {Remove ( u,* ) from adjacency list.}
          Dispose(Adj,Done);
          RegInfo[U].AdjList:=nil;
        end;
    end;


    function TRGObj.GetRegisterInline(List:TAsmList;const SubRegConstraints:TSubRegisterSet):TRegister;
      var
        P : TSuperRegister;
        SubReg: TSubRegister;
      begin
        for SubReg:=High(TSubRegister) downto Low(TSubRegister) do
          if SubReg in SubRegConstraints then
            Break;
        P:=GetNewReg(SubReg);
        LiveRegisters.Add(P);
        Result:=NewReg(RegType,P,SubReg);
        Add_Edges_Used(P);
        Add_Constraints(Result);
        { also add constraints for other sizes used for this register }
        if SubReg<>Low(TSubRegister) then
          for SubReg:=Pred(SubReg) downto Low(TSubRegister) do
            if SubReg in SubRegConstraints then
              Add_Constraints(NewReg(RegType,GetSupReg(Result),SubReg));
      end;


    procedure TRGObj.UngetRegisterInline(List:TAsmList;R:TRegister);
      var
        SupReg:TSuperRegister;
      begin
        SupReg:=GetSupReg(R);
        LiveRegisters.Delete(SupReg);
        Insert_RegAlloc_Info(List,SupReg);
      end;


    procedure TRGObj.Insert_RegAlloc_Info(List:TAsmList;U:TSuperRegister);
      var
        P : TAI;
        R : TRegister;
        PAlloc,
        PDealloc : TAIRegAlloc;
      begin
        { Insert regallocs for all imaginary registers }
        with RegInfo[U] do
          begin
            R:=NewReg(RegType,U,SubReg);
            if Assigned(LiveStart) then
              begin
                { Generate regalloc and bind it to an instruction, this
                  is needed to find all live registers belonging to an
                  instruction during the spilling }
                if LiveStart.Typ=ait_instruction then
                  PAlloc:=TAIRegAlloc.Alloc(R,LiveStart)
                else
                  PAlloc:=TAIRegAlloc.Alloc(R,nil);
                if Assigned(LiveEnd) and (LiveEnd.Typ=ait_instruction) then
                  PDealloc:=TAIRegAlloc.Dealloc(R,LiveEnd)
                else
                  PDealloc:=TAIRegAlloc.Dealloc(R,nil);
                { Insert live start allocation before the instruction/reg_a_sync }
                List.InsertBefore(PAlloc,LiveStart);
                { Insert live end deallocation before reg allocations
                  to reduce conflicts }
                P:=LiveEnd;
                if Assigned(P) then
                  begin
                    while Assigned(P.Previous) and
                      (
                        (
                          (TAI(P.Previous).Typ=ait_regalloc) and
                          (
                            (
                              (TAIRegAlloc(P.Previous).RAType=ra_alloc) and
                              (TAIRegAlloc(P.Previous).Reg<>R)
                            ) or (
                              (TAIRegAlloc(P.Previous).RAType=ra_resize)
                              { Don't worry if a resize for the same supreg as
                                r appears - it won't cause issues in the end
                                since it's stripped out anyway and the deallocs
                                are adjusted after graph colouring }
                            )
                          )
                        ) or
                        (TAI(P.Previous).Typ in [ait_comment,ait_tempalloc,ait_varloc])
                      ) do
                      P:=TAI(P.Previous);
                    { , but add release after a reg_a_sync }
                    if (P.Typ=ait_regalloc) and
                      (TAIRegAlloc(P).RAType=ra_sync) then
                    P:=TAI(P.Next);
                  end;
                if Assigned(P) then
                  List.InsertBefore(PDealloc,P)
                else
                  List.Concat(PDealloc);
              end;
          end;
      end;


    procedure TRGObj.Insert_RegAlloc_Info_All(List:TAsmList);
      var
        SupReg : TSuperRegister;
      begin
        { Insert regallocs for all imaginary registers }
        for SupReg:=FirstImaginary to MaxReg-1 do
          Insert_RegAlloc_Info(List,SupReg);
      end;


    procedure TRGObj.Determine_Spill_Registers(List: TAsmList; HeaderTail: TAI);
      begin
        Prepare_Colouring;
        Colour_Registers;
        Epilogue_Colouring;
      end;


    procedure TRGObj.Get_Spill_Temp(List: TAsmList; SpillTemps: TSpillTempList; SupReg: TSuperRegister);
      var
        Size: PtrInt;
      begin
        {Get a temp for the spilled register, the size must at least equal a complete register,
         take also care of the fact that subreg can be larger than a single register like doubles
         that occupy 2 registers }
        { only force the whole register in case of integers. Storing a register that contains
          a single precision value as a double can cause conversion errors on e.g. ARM VFP }
        if (RegType=R_INTREGISTER) then
          Size:=Max(TCgSize2Size[reg_cgsize(NewReg(RegType,SupReg,R_SUBWHOLE))],
                         TCgSize2Size[reg_cgsize(NewReg(RegType,SupReg,RegInfo[SupReg].SubReg))])
        else
          Size:=TCgSize2Size[reg_cgsize(NewReg(RegType,SupReg,RegInfo[SupReg].SubReg))];
        TG.GetTemp(List,
                   Size,Size,
                   tt_noreuse,SpillTemps[SupReg]);
      end;


    procedure TRGObj.Add_CPU_Interferences(P : TAI);
      begin
      end;


    procedure TRGObj.Generate_Interference_Graph(List:TAsmList;HeaderTAI:TAI);

      procedure RecordUse(var R : TRegInfo);
        begin
          Inc(R.TotalInterferences,LiveRegisters.Length);
          Inc(R.CountUses);
        end;

      var
        P : TAI;
        I : Integer;
        SupReg, U: TSuperRegister;
      begin
        { All allocations are available. Now we can generate the
          interference graph. Walk through all instructions, we can
          start with the headertai, because before the header tai is
          only symbols. }
        LiveRegisters.Clear;
        P:=HeaderTAI;
        while Assigned(P) do
          begin
            Prefetch(Pointer(P.Next)^);
            case P.Typ of
              ait_instruction:
                with TAICPU(P) do
                  begin
                    CurrentFilePos:=FileInfo;
                    {For speed reasons, get_alias isn't used here, instead,
                     assign_colours will also set the colour of coalesced nodes.
                     If there are registers with colour=0, then the coalescednodes
                     list probably doesn't contain these registers, causing
                     assign_colours not to do this properly.}
                    for I:=0 to Ops-1 do
                      with Oper[I]^ do
                        case Typ of
                          top_reg:
                             if (GetRegType(Reg)=RegType) then
                               begin
                                 U:=GetSupReg(Reg);
{$ifdef EXTDEBUG}
                                 if (U>=MaxRegInfo) then
                                   InternalError(2018111701);
{$endif}
                                 RecordUse(RegInfo[U]);
                               end;
                          top_ref:
                            begin
                              if RegType in [R_INTREGISTER,R_ADDRESSREGISTER] then
                                with Ref^ do
                                  begin
                                    if (Base<>NR_NO) and
                                       (GetRegType(Base)=RegType) then
                                      begin
                                        U:=GetSupReg(Base);
{$ifdef EXTDEBUG}
                                        if (U>=MaxRegInfo) then
                                          InternalError(2018111702);
{$endif}
                                        RecordUse(RegInfo[U]);
                                      end;
                                    if (Index<>NR_NO) and
                                       (GetRegType(Index)=RegType) then
                                      begin
                                        U:=GetSupReg(Index);
{$ifdef EXTDEBUG}
                                        if (U>=MaxRegInfo) then
                                          InternalError(2018111703);
{$endif}
                                        RecordUse(RegInfo[U]);
                                      end;
{$if defined(x86)}
                                    if (Segment<>NR_NO) and
                                       (GetRegType(Segment)=RegType) then
                                      begin
                                        U:=GetSupReg(Segment);
{$ifdef EXTDEBUG}
                                        if (U>=MaxRegInfo) then
                                          InternalError(2018111704);
{$endif}
                                        RecordUse(RegInfo[U]);
                                      end;
{$endif defined(x86)}
                                  end;
                            end;
                          else
                            ;
                        end;
                  end;
              ait_regalloc:
                with TAIRegAlloc(P) do
                  begin
                    if (GetRegType(Reg)=RegType) then
                      begin
                        SupReg:=GetSupReg(Reg);
                        case RAType of
                          ra_alloc :
                            begin
                              LiveRegisters.Add(SupReg);
{$ifdef DEBUG_REGISTERLIFE}
                              write(LiveRegisters.Length,'  ');
                              for I:=0 to LiveRegisters.Length-1 do
                                write(std_regname(NewReg(RegType,LiveRegisters.Buf[I],DefaultSub)),' ');
                              WriteLn;
{$endif DEBUG_REGISTERLIFE}
                              Add_Edges_Used(SupReg);
                            end;
                          ra_dealloc :
                            begin
                              LiveRegisters.Delete(SupReg);
{$ifdef DEBUG_REGISTERLIFE}
                              write(LiveRegisters.Length,'  ');
                              for I:=0 to LiveRegisters.Length-1 do
                                write(std_regname(NewReg(RegType,LiveRegisters.Buf[I],DefaultSub)),' ');
                              WriteLn;
{$endif DEBUG_REGISTERLIFE}
                              Add_Edges_Used(SupReg);
                            end;
                          ra_markused :
                            if (SupReg<FirstImaginary) then
                              begin
                                Include(UsedInProc,SupReg);
                                HasUsedMarks:=True;
                              end;
                          else
                            ;
                        end;
                        { constraints needs always to be updated }
                        Add_Constraints(Reg);
                      end;
                  end;
              else
                ;
            end;
            Add_CPU_Interferences(P);
            P:=TAI(P.Next);
          end;

{$ifdef EXTDEBUG}
        if LiveRegisters.Length>0 then
          begin
            for I:=0 to LiveRegisters.Length-1 do
              begin
                { Only report for imaginary registers }
                if LiveRegisters.Buf[I]>=FirstImaginary then
                  Comment(VWarning,'Register '+std_regname(NewReg(RegType,LiveRegisters.Buf[I],DefaultSub))+' not released');
              end;
          end;
{$endif}
      end;


    procedure TRGObj.Translate_Register(var Reg : TRegister);
      begin
        if (GetRegType(Reg)=RegType) then
          SetSupReg(Reg,RegInfo[GetSupReg(Reg)].Colour)
        else
          InternalError(200602021);
      end;


    procedure TRGObj.Set_Reg_Initial_Location(Reg: TRegister; const Ref: TReference);
      var
        SupReg: TSuperRegister;
      begin
        SupReg:=GetSupReg(Reg);
        if (SupReg<FirstImaginary) or (SupReg>=MaxReg) then
          InternalError(2020090501);
        Alloc_SpillInfo(SupReg+1);
        SpillInfo[SupReg].SpillLocation:=Ref;
        Include(RegInfo[SupReg].Flags,ri_has_initial_loc);
      end;


    procedure TRGObj.Translate_Registers(List: TAsmList);

      function Get_Reg_Name_Full(R: TRegister; include_prefix: Boolean): string;
        var
          RR:TRegister;
          SR:TSuperRegister;
        begin
          SR:=GetSupReg(R);
          if RegInfo[SR].LiveStart=nil then
            begin
              Result:='';
              Exit;
            end;
          if (SR<Length(SpillInfo)) and SpillInfo[SR].Spilled then
            with SpillInfo[SR].SpillLocation do
              begin
                Result:='['+std_regname(Base);
                if Offset>=0 then
                  Result:=Result+'+';
                Result:=Result+IntToStr(Offset)+']';
                if include_prefix then
                  Result:='stack '+Result;
              end
          else
            begin
              RR:=R;
              SetSupReg(RR,RegInfo[SR].Colour);
              Result:=std_regname(RR);
              if include_prefix then
                Result:='register '+Result;
            end;

        end;

      var
        HP,P:TAI;
        I:ShortInt;
        U:LongInt;
        S:string;

      begin
        { Leave when no imaginary registers are used }
        if MaxReg<=FirstImaginary then
          Exit;
        P:=TAI(List.First);
        while Assigned(P) do
          begin
            Prefetch(Pointer(P.Next)^);
            case P.Typ of
              ait_regalloc:
                with TAIRegAlloc(P) do
                  begin
                    if (GetRegType(Reg)=RegType) then
                      begin
                        { Only alloc/dealloc is needed for the optimizer, remove
                          other regalloc }
                        if not(RAType in [ra_alloc,ra_dealloc]) then
                          begin
                            Remove_AI(List,P);
                            Continue;
                          end
                        else
                          begin
                            U:=RegInfo[GetSupReg(Reg)].Colour;
                            Include(UsedInProc,U);
{$ifdef DEBUG_SPILLCOALESCE}
                            if (RAType=ra_alloc) and (ri_coalesced in RegInfo[GetSupReg(Reg)].Flags) then
                              begin
                                HP:=TAIComment.Create(StrPNew('Coalesced '+std_regname(Reg)+'->'+
                                                       std_regname(NewReg(RegType,RegInfo[GetSupReg(Reg)].Alias,RegInfo[GetSupReg(Reg)].SubReg))+
                                                       ' ('+std_regname(NewReg(RegType,U,RegInfo[GetSupReg(Reg)].SubReg))+')'));
                                List.InsertAfter(HP,P);
                              end;
{$endif DEBUG_SPILLCOALESCE}
{$ifdef EXTDEBUG}
                            if U>=MaxRegInfo then
                              InternalError(2015040501);
{$endif}
                            SetSupReg(Reg,U);
                          end;
                      end;
                  end;
              ait_varloc:
                begin
                  if (GetRegType(TAIVarLoc(P).NewLocation)=RegType) then
                    begin
                      if (cs_asm_source in CurrentSettings.GlobalSwitches) then
                        begin
                          S:=Get_Reg_Name_Full(TAIVarLoc(P).NewLocation,TAIVarLoc(P).NewLocationHi=NR_NO);
                          if S<>'' then
                            begin
                              if TAIVarLoc(P).NewLocationHi<>NR_NO then
                                S:=Get_Reg_Name_Full(TAIVarLoc(P).NewLocationHi,True)+':'+S;
                              HP:=TAIComment.Create(StrPNew('Var '+TAIVarLoc(P).VarSym.RealName+' located in '+S));
                              List.InsertAfter(HP,P);
                            end;
                          SetSupReg(TAIVarLoc(P).NewLocation,RegInfo[GetSupReg(TAIVarLoc(P).NewLocation)].Colour);
                          if TAIVarLoc(P).NewLocationHi<>NR_NO then
                            SetSupReg(TAIVarLoc(P).NewLocationHi,RegInfo[GetSupReg(TAIVarLoc(P).NewLocationHi)].Colour);
                        end;
                      Remove_AI(List,P);
                      Continue;
                    end;
                end;

              ait_instruction:
                with TAICPU(P) do
                  begin
                    CurrentFilePos:=FileInfo;
                    {For speed reasons, get_alias isn't used here, instead,
                     assign_colours will also set the colour of coalesced nodes.
                     If there are registers with colour=0, then the coalescednodes
                     list probably doesn't contain these registers, causing
                     assign_colours not to do this properly.}
                    for I:=0 to Ops-1 do
                      with Oper[I]^ do
                        case Typ of
                          Top_reg:
                             if (GetRegType(Reg)=RegType) then
                               begin
                                 U:=GetSupReg(Reg);
{$ifdef EXTDEBUG}
                                 if (U>=MaxRegInfo) then
                                   InternalError(2012101903);
{$endif}
                                 SetSupReg(Reg,RegInfo[U].Colour);
                               end;
                          Top_ref:
                            begin
                              if RegType in [R_INTREGISTER,R_ADDRESSREGISTER] then
                                with Ref^ do
                                  begin
                                    if (Base<>NR_NO) and
                                       (GetRegType(Base)=RegType) then
                                      begin
                                        U:=GetSupReg(Base);
{$ifdef EXTDEBUG}
                                        if (U>=MaxRegInfo) then
                                          InternalError(2012101904);
{$endif}
                                        SetSupReg(Base,RegInfo[U].Colour);
                                      end;
                                    if (Index<>NR_NO) and
                                       (GetRegType(Index)=RegType) then
                                      begin
                                        U:=GetSupReg(Index);
{$ifdef EXTDEBUG}
                                        if (U>=MaxRegInfo) then
                                          InternalError(2012101905);
{$endif}
                                        SetSupReg(Index,RegInfo[U].Colour);
                                      end;
{$if defined(x86)}
                                    if (Segment<>NR_NO) and
                                       (GetRegType(Segment)=RegType) then
                                      begin
                                        U:=GetSupReg(Segment);
{$ifdef EXTDEBUG}
                                        if (U>=MaxRegInfo) then
                                          InternalError(2013052401);
{$endif}
                                        SetSupReg(Segment,RegInfo[U].Colour);
                                      end;
{$endif defined(x86)}
                                  end;
                            end;
                          else
                            ;
                        end;

                    { Maybe the operation can be removed when
                      it is a move and both arguments are the same }
                    if is_same_reg_move(RegType) then
                      begin
                        { Be careful of dangling pointers in previous reg_allocs,
                          ss these can confuse the register allocator }
                        HP:=TAI(P.Previous);
                        while Assigned(HP) do
                          begin
                            if (HP.Typ in [ait_comment,ait_tempalloc,ait_varloc]) then
                              { Do nothing, but pass control flow to
                                "hp:=tai(hp.previous)" and continue the loop }
                            else if (HP.Typ=ait_regalloc) then
                              begin
                                if TAIRegAlloc(HP).Instr=P then
                                  TAIRegAlloc(HP).Instr:=nil;
                              end
                            else
                              Break;
                            HP:=TAI(HP.Previous);
                          end;
                        Remove_AI(List,P);
                        Continue;
                      end;
                  end;
              else
                ;
            end;
            P:=TAI(P.Next);
          end;
        CurrentFilePos:=CurrentProcInfo.ExitPos;
      end;


    function TRGObj.Spill_Registers(List:TAsmList;HeaderTAI:TAI):Boolean;
    { Returns true if any help registers have been used }
      var
        I : Cardinal;
        T : TSuperRegister;
        P : TAI;
        RegsToSpillSet:TSuperRegisterSet;
        SpillTemps : TSpillTempList;
        SupReg,X,Y : TSuperRegister;
        TempList : TAsmList;
        J : LongInt;
        GetNewSpillLoc : Boolean;
      begin
        Spill_Registers:=False;
        LiveRegisters.Clear;
        { spilling should start with the node with the highest number of interferences, so we can coalesce as
          much as possible spilled nodes (coalesce in case of spilled node means they share the same memory location) }
        Sort_SpilledNodes;
        for I:=FirstImaginary to MaxReg-1 do
          Exclude(RegInfo[I].Flags,ri_selected);
        SetLength(SpillTemps,MaxReg);
        SupRegSet_Reset(RegsToSpillSet,False,$ffff);

{$ifdef DEBUG_SPILLCOALESCE}
        WriteLn('trgobj.spill_registers: Got maxreg ',MaxReg);
        WriteLn('trgobj.spill_registers: Spilling ',SpilledNodes.Length,' nodes');
{$endif DEBUG_SPILLCOALESCE}
        { after each round of spilling, more registers could be used due to allocations for spilling }
        Alloc_SpillInfo(MaxReg);
        { Allocate temps and insert in front of the list }
        TempList:=TAsmList.Create;
        { Safe: this procedure is only called if there are spilled nodes. }
        with SpilledNodes do
          { the node with the highest interferences is the last one }
          for I:=Length-1 downto 0 do
            begin
              T:=Buf[I];

{$ifdef DEBUG_SPILLCOALESCE}
              WriteLn('trgobj.spill_registers: Spilling ',T);
{$endif DEBUG_SPILLCOALESCE}

              SpillInfo[T].Interferences:=TInterferenceBitmap.Create;

              { copy interferences }
              for J:=0 to MaxReg-1 do
                SpillInfo[T].Interferences[0,J]:=IBitmap[T,J];

              { Alternative representation. }
              SupRegSet_Include(RegsToSpillSet,T);
              { Clear all interferences of the spilled register. }
              Clear_Interferences(T);

              GetNewSpillLoc:=not (ri_has_initial_loc in RegInfo[T].Flags);
              if not GetNewSpillLoc then
                SpillTemps[T]:=SpillInfo[T].SpillLocation;

              { check if we can "coalesce" spilled nodes. To do so, it is required that they do not
                interfere but are connected by a move instruction

                doing so might save some mem->mem moves }
              if (cs_opt_level3 in CurrentSettings.OptimizerSwitches) and
                 GetNewSpillLoc and
                 Assigned(RegInfo[T].MoveList) then
                for J:=0 to RegInfo[T].MoveList^.Header.Count-1 do
                  begin
                    X:=TMoveIns(RegInfo[T].MoveList^.Data[J]).X;
                    Y:=TMoveIns(RegInfo[T].MoveList^.Data[J]).Y;
                    if (X=T) and
                      (SpillInfo[Get_Alias(Y)].Spilled) and
                      not(SpillInfo[Get_Alias(Y)].Interferences[0,T]) then
                      begin
                        SpillTemps[T]:=SpillInfo[Get_Alias(Y)].SpillLocation;
{$ifdef DEBUG_SPILLCOALESCE}
                        WriteLn('trgobj.spill_registers: Spill coalesce ',T,' to ',Y);
{$endif DEBUG_SPILLCOALESCE}
                        GetNewSpillLoc:=False;
                        Break;
                      end
                    else if (Y=T) and
                      (SpillInfo[Get_Alias(X)].Spilled) and
                      not(SpillInfo[Get_Alias(X)].Interferences[0,T]) then
                      begin
{$ifdef DEBUG_SPILLCOALESCE}
                        WriteLn('trgobj.spill_registers: Spill coalesce ',T,' to ',X);
{$endif DEBUG_SPILLCOALESCE}
                        SpillTemps[T]:=SpillInfo[Get_Alias(X)].SpillLocation;
                        GetNewSpillLoc:=False;
                        Break;
                      end;
                  end;

              if GetNewSpillLoc then
                Get_Spill_Temp(TempList,SpillTemps,T);

{$ifdef DEBUG_SPILLCOALESCE}
              WriteLn('trgobj.spill_registers: Spill temp: ',GetSupReg(SpillTemps[T].Base),'+',SpillTemps[T].Offset);
{$endif DEBUG_SPILLCOALESCE}

              { set spilled only as soon as a temp is assigned, else a mov iregX,iregX results in a spill coalesce with itself }
              SpillInfo[T].Spilled:=True;

              SpillInfo[T].SpillLocation:=SpillTemps[T];
            end;
        List.InsertListAfter(HeaderTAI,TempList);
        TempList.Free;
        TempList := nil;
        { Walk through all instructions, we can start with the headertai,
          because before the header tai is only symbols }
        P:=HeaderTAI;
        while Assigned(P) do
          begin
            case P.Typ of
              ait_regalloc:
                with TAIRegAlloc(P) do
                  begin
                    if (GetRegType(Reg)=RegType) then
                      begin
                        {A register allocation of the spilled register (and all coalesced registers)
                         must be removed.}
                        SupReg:=Get_Alias(GetSupReg(Reg));
                        if SupRegSet_In(RegsToSpillSet,SupReg) then
                          begin
                            { Remove loading of the register from its initial memory location
                              (e.g. load of a stack parameter to the register). }
                            if (RAType=ra_alloc) and
                               (ri_has_initial_loc in RegInfo[SupReg].Flags) and
                               (Instr<>nil) then
                              begin
                                List.Remove(Instr);
                                FreeAndNil(Instr);
                                Dec(RegInfo[SupReg].Weight,100);
                              end;
                            { Remove the regalloc }
                            Remove_AI(List,P);
                            Continue;
                          end
                        else
                          begin
                            case RAType of
                              ra_alloc :
                               LiveRegisters.Add(SupReg);
                              ra_dealloc :
                               LiveRegisters.Delete(SupReg);
                              else
                                ;
                            end;
                          end;
                      end;
                  end;

              ait_instruction:
                with TAICPUAbstractSym(P) do
                  begin
//                    writeln(gas_op2str[tai_cpu_abstract_sym(p).opcode]);
                    CurrentFilePos:=FileInfo;
                    if Instr_Spill_Register(List,TAICPUAbstractSym(P),RegsToSpillSet,SpillTemps) then
                      Spill_Registers:=True;
                  end;
              else
                ;
            end;
            P:=TAI(P.Next);
          end;
        CurrentFilePos:=CurrentProcInfo.ExitPos;
        {Safe: this procedure is only called if there are spilled nodes.}
        with SpilledNodes do
          for I:=0 to Length-1 do
            begin
              J:=Buf[I];
              if TG.IsTemp(SpillTemps[J]) then
                TG.UnGetTemp(List,SpillTemps[J]);
            end;
        SpillTemps:=nil;
      end;


    function TRGObj.Do_Spill_Replace(List:TAsmList;Instr:TAICPUAbstractSym;OrgReg:TSuperRegister;const SpillTemp:TReference):Boolean;
      begin
        Result:=False;
      end;


    procedure TRGObj.Do_Spill_Read(List:TAsmList;Pos:TAI;const SpillTemp:TReference;TempReg:TRegister;OrgSupReg:TSuperRegister);
      var
        Ins:TAICPUAbstractSym;
      begin
        Ins:=spilling_create_load(SpillTemp,TempReg);
        Add_CPU_Interferences(Ins);
        List.InsertAfter(Ins,Pos);
        {$ifdef DEBUG_SPILLING}
        List.InsertBefore(TAIComment.Create(StrPNew('Spilling: Spill Read')),Ins);
        {$endif}
      end;


    procedure TRGObj.Do_Spill_Written(List:TAsmList;Pos:TAI;const SpillTemp:TReference;TempReg:TRegister;OrgSupReg:TSuperRegister);
      var
        Ins:TAICPUAbstractSym;
      begin
        Ins:=spilling_create_store(TempReg,SpillTemp);
        Add_CPU_Interferences(Ins);
        List.InsertAfter(Ins,Pos);
        {$ifdef DEBUG_SPILLING}
        List.InsertBefore(TAIComment.Create(StrPNew('Spilling: Spill Write')),Ins);
        {$endif}
      end;


    function TRGObj.Get_Spill_SubReg(R : TRegister) : TSubRegister;
      begin
        Result:=DefaultSub;
      end;


    function TRGObj.AddRegInfo(var SpRegs: TSpillRegsInfo; const R: TSuperRegisterSet; Reg: TRegister; Operation: TOperType): Boolean;
      var
        I, TmpIndex: LongInt;
        SupReg: TSuperRegister;
      begin
        Result:=False;
        TmpIndex := SpRegs.SpillRegInfoCount;
        SupReg := Get_Alias(GetSupReg(Reg));
        { did we already encounter this register? }
        for I := 0 to Pred(SpRegs.SpillRegInfoCount) do
          if (SpRegs.SpillRegInfo[I].OrgReg = SupReg) then
            begin
              TmpIndex := I;
              Break;
            end;
        if TmpIndex > High(SpRegs.SpillRegInfo) then
          InternalError(2003120301);
        SpRegs.SpillRegInfo[TmpIndex].OrgReg := SupReg;
        Include(SpRegs.SpillRegInfo[TmpIndex].SpillRegConstraints,Get_Spill_SubReg(Reg));
        if SupRegSet_In(R,SupReg) then
          begin
            { add/update info on this register }
            SpRegs.SpillRegInfo[TmpIndex].MustBeSpilled := True;
            case Operation of
              operand_read:
                SpRegs.SpillRegInfo[TmpIndex].RegRead := True;
              operand_write:
                SpRegs.SpillRegInfo[TmpIndex].RegWritten := True;
              operand_readwrite:
                begin
                  SpRegs.SpillRegInfo[TmpIndex].RegRead := True;
                  SpRegs.SpillRegInfo[TmpIndex].RegWritten := True;
                end;
            end;
            Result:=True;
          end;
        Inc(SpRegs.SpillRegInfoCount,Ord(SpRegs.SpillRegInfoCount=TmpIndex));
      end;


    function TRGObj.Instr_Get_Oper_Spilling_Info(var SpRegs: TSpillRegsInfo; const R: TSuperRegisterSet; Instr: TAICPUAbstractSym; OpIdx: LongInt): Boolean;
      begin
        Result:=False;
        with Instr.Oper[OpIdx]^ do
          begin
            case Typ of
              top_reg:
                begin
                  if (GetRegType(Reg) = RegType) then
                    Result:=AddRegInfo(SpRegs,R,Reg,Instr.spilling_get_operation_type(OpIdx));
                end;
              top_ref:
                begin
                  if RegType in [R_INTREGISTER,R_ADDRESSREGISTER] then
                    with Ref^ do
                      begin
                        if (Base <> NR_NO) and
                            (GetRegType(Base)=RegType) then
                          Result:=AddRegInfo(SpRegs,R,Base,Instr.spilling_get_operation_type_ref(OpIdx,Base));
                        if (Index <> NR_NO) and
                            (GetRegType(Index)=RegType) then
                          Result:=AddRegInfo(SpRegs,R,Index,Instr.spilling_get_operation_type_ref(OpIdx,Index)) or Result;
{$if defined(x86)}
                        if (Segment <> NR_NO) and
                            (GetRegType(Segment)=RegType) then
                          Result:=AddRegInfo(SpRegs,R,Segment,Instr.spilling_get_operation_type_ref(OpIdx,Segment)) or Result;
{$endif defined(x86)}
                      end;
                end;
              else
                ;
            end;
          end;
      end;


    procedure TRGObj.Try_Replace_Reg(const SpRegs: TSpillRegsInfo; var Reg: TRegister; UseLoadReg: Boolean);
      var
        I: LongInt;
        SupReg: TSuperRegister;
      begin
        SupReg:=Get_Alias(GetSupReg(Reg));
        for I:=0 to Pred(SpRegs.SpillRegInfoCount) do
          if (SpRegs.SpillRegInfo[I].MustBeSpilled) and
             (SpRegs.SpillRegInfo[I].OrgReg=SupReg) then
            begin
              { Only replace supreg }
              if UseLoadReg then
                SetSupReg(Reg, GetSupReg(SpRegs.SpillRegInfo[I].LoadReg))
              else
                SetSupReg(Reg, GetSupReg(SpRegs.SpillRegInfo[I].StoreReg));
              Break;
            end;
      end;


    procedure TRGObj.Substitute_Spilled_Registers(const SpRegs: TSpillRegsInfo; Instr: TAICPUAbstractSym; OpIdx: LongInt);
      begin
        with Instr.Oper[OpIdx]^ do
          case Typ of
            top_reg:
              begin
                if (GetRegType(Reg) = RegType) then
                  Try_Replace_Reg(SpRegs, Reg, not SSASafe or
                    (Instr.spilling_get_operation_type(OpIdx)=operand_read));
              end;
            top_ref:
              begin
                if RegType in [R_INTREGISTER, R_ADDRESSREGISTER] then
                  begin
                    if (Ref^.Base <> NR_NO) and
                        (GetRegType(Ref^.Base)=RegType) then
                      Try_Replace_Reg(SpRegs, Ref^.Base,
                        not SSASafe or (Instr.spilling_get_operation_type_ref(OpIdx, Ref^.Base)=operand_read));
                    if (Ref^.Index <> NR_NO) and
                        (GetRegType(Ref^.Index)=RegType) then
                      Try_Replace_Reg(SpRegs, Ref^.Index,
                        not SSASafe or (Instr.spilling_get_operation_type_ref(OpIdx, Ref^.Index)=operand_read));
  {$if defined(x86)}
                    if (Ref^.Segment <> NR_NO) and
                        (GetRegType(Ref^.Segment)=RegType) then
                      Try_Replace_Reg(SpRegs, Ref^.Segment, True { always read-only });
  {$endif defined(x86)}
                  end;
              end;
            else
              ;
          end;
      end;


    function TRGObj.Instr_Spill_Register(List:TAsmList;
                                         Instr:TAICPUAbstractSym;
                                         const R:TSuperRegisterSet;
                                         const SpillTempList:TSpillTempList): Boolean;
      var
        Counter: LongInt;
        SpRegs: TSpillRegsInfo;
        Spilled: Boolean;
      var
        LoadPos,
        StorePos : TAI;
        OldLiveRegisters : TSuperRegisterWorkList;
      begin
        Result := False;
        FillChar(SpRegs,SizeOf(SpRegs),0);
        for Counter := Low(SpRegs.SpillRegInfo) to High(SpRegs.SpillRegInfo) do
          begin
            SpRegs.SpillRegInfo[Counter].OrgReg := RSInvalid;
            SpRegs.SpillRegInfo[Counter].LoadReg := NRInvalid;
            SpRegs.SpillRegInfo[Counter].StoreReg := NRInvalid;
          end;
        Spilled := False;

        { check whether and if so which and how (read/written) this instructions contains
          registers that must be spilled }
        for Counter := 0 to Instr.Ops-1 do
          Spilled:=Instr_Get_Oper_Spilling_Info(SpRegs,R,Instr,Counter) or Spilled;

        { if no spilling for this instruction we can leave }
        if not Spilled then
          Exit;

        { Check if the instruction is "OP reg1,reg2" and reg1 is coalesced with reg2 }
        if (SpRegs.SpillRegInfoCount=1) and (Instr.Ops=2) and
          (Instr.Oper[0]^.Typ=top_reg) and (Instr.Oper[1]^.Typ=top_reg) and
          (GetRegType(Instr.Oper[0]^.Reg)=GetRegType(Instr.Oper[1]^.Reg)) then
          begin
            { Set both registers in the instruction to the same register }
            SetSupReg(Instr.Oper[0]^.Reg, SpRegs.SpillRegInfo[0].OrgReg);
            SetSupReg(Instr.Oper[1]^.Reg, SpRegs.SpillRegInfo[0].OrgReg);
            { In case of MOV reg,reg no spilling is needed.
              This MOV will be removed later in translate_registers() }
            if Instr.is_same_reg_move(RegType) then
              Exit;
          end;

{$if defined(x86)}
        { Try replacing the register with the spilltemp. This is useful only
          for the i386,x86_64 that support memory locations for several instructions

          For non-x86 it is nevertheless possible to replace moves to/from the register
          with loads/stores to spilltemp (Sergei) }
        for Counter := 0 to Pred(SpRegs.SpillRegInfoCount) do
          with SpRegs.SpillRegInfo[Counter] do
            begin
              if MustBeSpilled then
                begin
                  if Do_Spill_Replace(List,Instr,OrgReg,SpillTempList[OrgReg]) then
                    MustBeSpilled:=False;
                end;
            end;
{$endif}

        {
          There are registers that need are spilled. We generate the
          following code for it. The used positions where code need
          to be inserted are marked using #. Note that code is always inserted
          before the positions using pos.previous. This way the position is always
          the same since pos doesn't change, but pos.previous is modified every time
          new code is inserted.

          [
            - reg_allocs load spills
            - load spills
          ]
          [#loadpos
            - reg_deallocs
            - reg_allocs
          ]
          [
            - reg_deallocs for load-only spills
            - reg_allocs for store-only spills
          ]
          [#instr
            - original instruction
          ]
          [
            - store spills
            - reg_deallocs store spills
          ]
          [#storepos
          ]
        }

        Result := True;
        OldLiveRegisters.CopyFrom(LiveRegisters);

        { Process all tai_regallocs belonging to this instruction, ignore explicit
          inserted regallocs. These can happened for example in i386:
             mov ref,ireg26
             <regdealloc ireg26, instr=taicpu of lea>
             <regalloc edi, insrt=nil>
             lea [ireg26+ireg17],edi
          All released registers are also added to the live_registers because
          they can't be used during the spilling }
        LoadPos:=TAI(Instr.Previous);
        while Assigned(LoadPos) and
          (
            (LoadPos.Typ in [ait_comment,ait_tempalloc,ait_varloc]) or
            (
              (LoadPos.Typ=ait_regalloc) and
              (
                (TAIRegAlloc(LoadPos).Instr=nil) or
                (TAIRegAlloc(LoadPos).Instr=Instr)
              )
            )
          ) do
          begin
            { Only add deallocs belonging to the instruction. Explicit inserted deallocs
              belong to the previous instruction and not the current instruction }
            if (LoadPos.Typ=ait_regalloc) and
               (TAIRegAlloc(LoadPos).Instr=Instr) and
               (TAIRegAlloc(LoadPos).RAType=ra_dealloc) then
              LiveRegisters.Add(Get_Alias(GetSupReg(TAIRegAlloc(LoadPos).Reg)));
            LoadPos:=TAI(LoadPos.Previous);
          end;
        LoadPos:=TAI(LoadPos.Next);

        { Load the spilled registers }
        for Counter := 0 to Pred(SpRegs.SpillRegInfoCount) do
          with SpRegs.SpillRegInfo[Counter] do
            begin
              if MustBeSpilled and RegRead then
                begin
                  LoadReg:=GetRegisterInline(List,SpRegs.SpillRegInfo[Counter].SpillRegConstraints);
                  Do_Spill_Read(List,TAI(LoadPos.Previous),SpillTempList[OrgReg],LoadReg,OrgReg);
                  Include(RegInfo[GetSupReg(LoadReg)].Flags,ri_spill_helper);
                end;
            end;

        { Release temp registers of read-only registers, and add reference of the instruction
          to the reginfo }
        for Counter := 0 to Pred(SpRegs.SpillRegInfoCount) do
          with SpRegs.SpillRegInfo[Counter] do
            begin
              if MustBeSpilled and RegRead and
                (SSASafe or
                 not RegWritten) then
                begin
                  { The original instruction will be the next that uses this register

                    set weigth of the newly allocated register higher than the old one,
                    so it will selected for spilling with a lower priority than
                    the original one, this prevents an endless spilling loop if orgreg
                    is short living, see e.g. tw25164.pas

                    the min trick is needed to avoid an overflow in case weight=high(weight which might happen }
                  Add_Reg_Instruction(Instr,LoadReg,Min(High(RegInfo[OrgReg].Weight)-1,RegInfo[OrgReg].Weight)+1);
                  UngetRegisterInline(List,LoadReg);
                end;
            end;

        { Allocate temp registers of write-only registers, and add reference of the instruction
          to the reginfo }
        for Counter := 0 to Pred(SpRegs.SpillRegInfoCount) do
          with SpRegs.SpillRegInfo[Counter] do
            begin
              if MustBeSpilled and RegWritten then
                begin
                  { When the register is also loaded there is already a register assigned }
                  if (not RegRead) or
                     SSASafe then
                    begin
                      StoreReg:=GetRegisterInline(List,SpRegs.SpillRegInfo[Counter].SpillRegConstraints);
                      Include(RegInfo[GetSupReg(StoreReg)].Flags,ri_spill_helper);
                      { we also use loadreg for store replacements in case we
                        don't have ensure ssa -> initialise loadreg even if
                        there are no reads }
                      if not RegRead  then
                       LoadReg:=StoreReg;
                    end
                  else
                    StoreReg:=LoadReg;
                  { The original instruction will be the next that uses this register, this
                    also needs to be done for read-write registers,

                    set weigth of the newly allocated register higher than the old one,
                    so it will selected for spilling with a lower priority than
                    the original one, this prevents an endless spilling loop if orgreg
                    is short living, see e.g. tw25164.pas

                    the min trick is needed to avoid an overflow in case weight=high(weight which might happen }
                  Add_Reg_Instruction(Instr,StoreReg,Min(High(RegInfo[OrgReg].Weight)-1,RegInfo[OrgReg].Weight)+1);
                end;
            end;

        { store the spilled registers }
        if not Assigned(Instr.Next) then
          List.Concat(TAIMarker.Create(mark_Position));
        StorePos:=TAI(Instr.Next);
        for Counter := 0 to Pred(SpRegs.SpillRegInfoCount) do
          with SpRegs.SpillRegInfo[Counter] do
            begin
              if MustBeSpilled and RegWritten then
                begin
                  Do_Spill_Written(List,TAI(StorePos.Previous),SpillTempList[OrgReg],StoreReg,OrgReg);
                  UngetRegisterInline(List,StoreReg);
                end;
            end;

        { now all spilling code is generated we can restore the live registers. This
          must be done after the store because the store can need an extra register
          that also needs to conflict with the registers of the instruction }
        LiveRegisters.Done;
        LiveRegisters:=OldLiveRegisters;

        { substitute registers }
        for Counter:=0 to Instr.Ops-1 do
          Substitute_Spilled_Registers(SpRegs,Instr,Counter);
        { We have modified the instruction; perhaps the new instruction has
          certain constraints regarding which imaginary registers interfere
          with certain physical registers. }
        Add_CPU_Interferences(Instr);
      end;


    procedure TRGObj.Remove_AI(List:TAsmList; var P:TAI);
      var
        Q:TAI;
      begin
        Q:=TAI(P.Next);
        List.Remove(P);
        P.Free;
        P:=Q;
      end;


{$ifdef DEBUG_SPILLCOALESCE}
    procedure TRGObj.Write_Spill_Stats;

      { This procedure outputs spilling statistics.
        If no spilling has occurred, no output is provided.
        NUM is the number of spilled registers.
        EFF is efficiency of the spilling which is based on
            weight and usage count of registers. Range 0-100%.
            0% means all imaginary registers have been spilled.
            100% means no imaginary registers have been spilled
            (no output in this case).
            Higher value is better.
      }
      var
        I,J,SpillingCounter,MaxWeight:LongInt;
        AllWeight,SpillWeight,D: Double;
      begin
        MaxWeight:=1;
        for I:=FirstImaginary to MaxReg-1 do
          with RegInfo[I] do
            if Weight>MaxWeight then
              MaxWeight:=Weight;

        SpillingCounter:=0;
        SpillWeight:=0;
        AllWeight:=0;
        for I:=FirstImaginary to MaxReg-1 do
          with RegInfo[I] do
            if not (ri_spill_helper in Flags) then
              begin
                D:=Weight/MaxWeight;
                AllWeight:=AllWeight+D;
                if (ri_coalesced in Flags) and (Alias>=FirstImaginary) then
                  J:=Alias
                else
                  J:=I;
                if (RegInfo[J].Weight>100) and
                   (J<=High(SpillInfo)) and
                   SpillInfo[J].Spilled then
                  begin
                    Inc(SpillingCounter);
                    SpillWeight:=SpillWeight+D;
                  end;
              end;
        if SpillingCounter>0 then
          begin
            D:=(1.0-SpillWeight/AllWeight)*100.0;
            WriteLn(CurrentProcInfo.ProcDef.MangledName,' [',RegType,']: spill stats: NUM: ',SpillingCounter, ', EFF: ',D:4:1,'%');
          end;
      end;
{$endif DEBUG_SPILLCOALESCE}

end.

