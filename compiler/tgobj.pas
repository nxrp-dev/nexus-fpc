{
    Copyright (c) 1998-2002 by Florian Klaempfl

    This unit implements the base object for temp. generator

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
{#@abstract(Temporary reference allocator unit)
  Temporary reference allocator unit. This unit contains
  all which is related to allocating temporary memory
  space on the stack, as required, by the code generator.
}

unit tgobj;

{$i fpcdefs.inc}

{ $define DEBUG_FREETEMP}

  interface

    uses
      Globals,GlobType,
      symconst,symdef,symtype,SymTable,
      cpubase,cgbase,cgutils,
      aasmtai,AAsmData;

    type
      PTempRecord = ^TTempRecord;
      TTempRecord = record
         TempType   : TTempType;
         { finalize this temp if it's a managed type }
         Fini       : boolean;
         Alignment  : shortint;
         Pos        : asizeint;
         Size       : asizeint;
         Def        : TDef;
         Next       : PTempRecord;
         NextFree   : PTempRecord; { for faster freeblock checking }
{$ifdef EXTDEBUG}
         PosInfo,
         ReleasePosInfo : TFilePosInfo;
{$endif}
      end;


       {# Generates temporary variables }
       TTGObj = class
       protected
          { contains all free temps using nextfree links }
          FTempFreeList  : PTempRecord;
          procedure AllocTemp(AList: TAsmList; ASize: asizeint; AAlignment: shortint; ATempType: TTempType; ADef: TDef; AFini: boolean; out AReference: TReference); virtual;
          procedure FreeTemp(AList: TAsmList; APos: TRefTempPos; ATempTypes: TTempTypeSet);virtual;
          procedure GetTempInternal(AList: TAsmList; ASize: asizeint; AAlignment: shortint; ATempType: TTempType; ADef: TDef; AFini: boolean; out AReference : TReference);
          procedure FreeTempHook(AList: TAsmList; ATempRecord: PTempRecord); virtual;
       public
          { contains all temps }
          TempList      : PTempRecord;
          { Offsets of the first/last temp }
          FirstTemp,
          LastTemp,
          { Offset of temp base register relative to guaranteed stack alignment
            (note: currently only behaves as expected if it's a power of 2,
               and if all requested alignments are also a power of 2) }
          AlignMismatch: LongInt;
          Direction : shortint;
          constructor Create;virtual;reintroduce;
          {# Clear and free the complete linked list of temporary memory
             locations. The list is set to nil.}
          procedure ResetTempGen;
          {# Sets the first offset from the frame pointer or stack pointer where
             the temporary references will be allocated. It is to note that this
             value should always be negative.

             @param(AOffset start offset where temps will start in stack)
          }
          procedure SetFirstTemp(AOffset: asizeint); virtual;
          procedure SetAlignmentMismatch(AOffset: shortint); virtual;

          { version of gettemp that is compatible with hlcg-based targets;
            always use in common code, only use gettemp in cgobj and
            architecture-specific backends.

            the forcesize parameter is so that it can be used for defs that
            don't have an inherent size (e.g., array of const) }
          procedure GetHLTemp(AList: TAsmList; ADef: TDef; AForceSize: asizeint; ATempType: TTempType; out AReference: TReference); virtual;
          procedure GetHLTempManaged(AList: TAsmList; ADef: TDef; ATempType: TTempType; out AReference: TReference); virtual;
          procedure GetTemp(AList: TAsmList; ASize: asizeint; AAlignment: shortint; ATempType: TTempType; out AReference : TReference);
          procedure GetTempManaged(AList: TAsmList; ADef:TDef;ATempType:TTempType;out AReference : TReference);
          procedure UnGetTemp(AList: TAsmList; const AReference : TReference); virtual;

          function SizeOfTemp(AList: TAsmList; const AReference: TReference): asizeint;
          function ChangeTempType(AList: TAsmList; const AReference:TReference;ATempType:TTempType):boolean;
          function GetTypeOfTemp(const AReference:TReference): TTempType;
          function IsStartOfTemp(const AReference: TReference): boolean;
          {# Returns a reference corresponding to a temp }
          procedure Temp_To_Ref(ATempRecord: PTempRecord; out AReference: TReference); virtual;


          {# Returns TRUE if the reference ref is allocated in temporary volatile memory space,
             otherwise returns FALSE.

             @param(AReference reference to verify)
          }
          function IsTemp(const AReference : TReference) : boolean; virtual;
          {# Frees a reference @var(AReference) which was allocated in the volatile temporary memory space.
             The freed space can later be reallocated and reused. If this reference
             is not in the temporary memory, it is simply not freed.
          }
          procedure UnGetIfTemp(AList: TAsmList; const AReference : TReference); virtual;

          { Allocate space for a local }
          procedure GetLocal(AList: TAsmList; ASize: asizeint; ADef: TDef; var AReference : TReference);
          procedure GetLocal(AList: TAsmList; ASize: asizeint; AAlignment,AExplicitAlignment: shortint; ADef: TDef; ASym : TSym; var AReference : TReference); virtual;
          procedure UnGetLocal(AList: TAsmList; const AReference : TReference);
          { Discard the free list so that previously freed temp slots cannot be
            reused by subsequent allocations. Used on AArch64-Win64 before
            generating exceptfilter code to prevent handler temps from reusing
            freed parent slots. }
          procedure Discard_FreeList;
       end;
       TTGObjClass = class of TTGObj;

     var
       TG: TTGObj;
       TGObjClass: TTGObjClass = TTGObj;

    procedure Location_FreeTemp(AList:TAsmList; const ALocation : TLocation);


implementation

    uses
       CUtils,
       Verbose,
       ProcInfo;


    const
      cFreeTempTypes = [tt_free,tt_freenoreuse,tt_freeregallocator];

{$ifdef EXTDEBUG}
      TempTypeStr : array[TTempType] of string[18] = (
          '<none>',
          'free','normal','persistent',
          'noreuse','freenoreuse',
          'regallocator','freeregallocator'
      );
{$endif EXTDEBUG}

      Used2Free : array[TTempType] of TTempType = (
        tt_none,
        tt_none,tt_free,tt_free,
        tt_freenoreuse,tt_none,
        tt_freeregallocator,tt_none
      );


{*****************************************************************************
                                    Helpers
*****************************************************************************}

    procedure Location_FreeTemp(AList:TAsmList; const ALocation : TLocation);
      begin
        if (ALocation.Loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
         TG.UnGetIfTemp(AList,ALocation.Reference);
      end;


{*****************************************************************************
                                    TTGOBJ
*****************************************************************************}

    constructor TTGObj.Create;

     begin
       FTempFreeList:=nil;
       TempList:=nil;
       { we could create a new child class for this but I don't if it is worth the effort (FK) }
{$ifdef aarch64}
       Direction:=1;
{$else}
       Direction:=-1;
{$endif}
     end;


    procedure TTGObj.ResetTempGen;
      var
         lCurrentTemp : PTempRecord;
      begin
        { Clear the old templist }
        while Assigned(TempList) do
         begin
{$ifdef EXTDEBUG}
           if not(TempList^.TempType in cFreeTempTypes) then
             begin
               Comment(VWarning,'tgobj: (ResetTempgen) temp at pos '+ToStr(TempList^.Pos)+
                       ' with size '+ToStr(TempList^.Size)+' and type '+TempTypeStr[TempList^.TempType]+
                       ' from pos '+ToStr(TempList^.PosInfo.line)+':'+ToStr(TempList^.PosInfo.column)+
                       ' not freed at the end of the procedure');
             end;
{$endif EXTDEBUG}
           lCurrentTemp:=TempList;
           TempList:=lCurrentTemp^.Next;
           dispose(lCurrentTemp);
         end;
        TempList:=nil;
        FTempFreeList:=nil;
        FirstTemp:=0;
        LastTemp:=0;
        AlignMismatch:=0;
{$ifdef EXTDEBUG}
         Comment(VNote,'tgobj: (ResetTempGen) all temps freed');
{$endif}
      end;


    procedure TTGObj.SetFirstTemp(AOffset: asizeint);
      begin
         { this is a negative value normally }
         if AOffset*Direction>=0 then
          begin
            if odd(AOffset) then
             inc(AOffset,Direction);
          end
         else
           InternalError(200204221);
         FirstTemp:=AOffset;
         LastTemp:=AOffset;
{$ifdef EXTDEBUG}
         Comment(VNote,'tgobj: (SetFirstTempGen) set to '+ToStr(AOffset));
{$endif}
      end;


    procedure TTGObj.SetAlignmentMismatch(AOffset: shortint);
      begin
        AlignMismatch:=AOffset*Direction;
      end;


    procedure TTGObj.AllocTemp(AList: TAsmList; ASize: asizeint; AAlignment: shortint; ATempType: TTempType; ADef :TDef; AFini: boolean; out AReference: TReference);
      var
         lTemp,lOtherTemp,
         lBestSlot,lBestPrev,
         lPrev,lCurrentTemp : PTempRecord;
         lFreeType : TTempType;
         lAdjustedPos : LongInt;
         lBestAtEnd,
         lFitAtBegin,
         lFitAtEnd : boolean;
      begin
         lBestPrev:=nil;
         lBestSlot:=nil;
         lTemp:=nil;
         lBestAtEnd:=false;
         CurrentProcInfo.UpdateStackAlignment(AAlignment);

         if ASize=0 then
          begin
{$ifdef EXTDEBUG}
            Comment(VNote,'tgobj: (AllocTemp) temp of size 0 requested, allocating 4 bytes');
{$endif}
            ASize:=4;
          end;

         lFreeType:=Used2Free[ATempType];
         if lFreeType=tt_none then
           InternalError(200208201);
         if ASize>MaxLocalsSize then
            begin
              CGMessage(cg_e_localsize_too_big);
              ASize:=0;  // Prevent further range check errors
            end;
         ASize:=align(ASize,AAlignment);
         { First check the tmpfreelist, but not when
           we don't want to reuse an already allocated block }
         if Assigned(FTempFreeList) and
            (ATempType<>tt_noreuse) then
          begin
            lPrev:=nil;
            lCurrentTemp:=FTempFreeList;
            while Assigned(lCurrentTemp) do
             begin
{$ifdef EXTDEBUG}
               if not(lCurrentTemp^.TempType in cFreeTempTypes) then
                 Comment(VWarning,'tgobj: (AllocTemp) temp at pos '+ToStr(lCurrentTemp^.Pos)+ ' in freelist is not set to  a free temp type !');
{$endif}
               { Check only slots that are
                  - free
                  - share the same type if either has to be finalised
                  - contain enough space
                  - has a correct alignment }
               lAdjustedPos:=lCurrentTemp^.Pos+AlignMismatch;
               if (lCurrentTemp^.TempType=lFreeType) and
                  (lCurrentTemp^.Fini=AFini) and
                  ((lCurrentTemp^.Def=ADef) or
                   not AFini) and
                  (lCurrentTemp^.Size>=ASize) and
                  ((lAdjustedPos=align(lAdjustedPos,AAlignment)) or
                   (lAdjustedPos+lCurrentTemp^.Size-ASize = align(lAdjustedPos+lCurrentTemp^.Size-ASize,AAlignment))) then
                begin
                  { Slot is the same size then leave immediately }
                  if (lCurrentTemp^.Size=ASize) then
                   begin
                     lBestPrev:=lPrev;
                     lBestSlot:=lCurrentTemp;
                     break;
                   end
                  else
                   begin
                     { we can fit a smaller block either at the begin or at }
                     { the end of a block. For direction=-1 we prefer the   }
                     { end, for direction=1 we prefer the begin (i.e.,      }
                     { always closest to the source). We also try to use    }
                     { the block with the worst possible alignment that     }
                     { still suffices. And we pick the block which will     }
                     { have the best alignment after this new block is      }
                     { subtracted from it.                                  }
                     lFitAtEnd:=(lAdjustedPos+lCurrentTemp^.Size-ASize)=align(lAdjustedPos+lCurrentTemp^.Size-ASize,AAlignment);
                     lFitAtBegin:=lAdjustedPos=align(lAdjustedPos,AAlignment);
                     if Assigned(lBestSlot) then
                       begin
                         lFitAtEnd:=lFitAtEnd and
                           ((not lBestAtEnd and
                             (Direction=-1)) or
                            (lBestAtEnd and
                             IsBetterAlignedThan(abs(lBestSlot^.Pos+lCurrentTemp^.Size-ASize),abs(lAdjustedPos+lCurrentTemp^.Size-ASize),CurrentSettings.Alignment.LocalAlignMax)));
                         lFitAtBegin:=lFitAtBegin and
                           (not lBestAtEnd or
                            (Direction=1)) and
                           IsBetterAlignedThan(abs(lAdjustedPos+ASize),abs(lBestSlot^.Pos+ASize),CurrentSettings.Alignment.LocalAlignMax);
                       end;
                     if lFitAtEnd and
                        lFitAtBegin then
                       if IsBetterAlignedThan(abs(lAdjustedPos+lCurrentTemp^.Size-ASize),abs(lAdjustedPos+ASize),CurrentSettings.Alignment.LocalAlignMax) then
                         lFitAtBegin:=false
                       else if IsBetterAlignedThan(abs(lAdjustedPos+ASize),abs(lAdjustedPos+lCurrentTemp^.Size-ASize),CurrentSettings.Alignment.LocalAlignMax) then
                         lFitAtEnd:=false
                       else if (Direction=1) then
                         lFitAtEnd:=false
                       else
                         lFitAtBegin:=false;
                     if lFitAtEnd or
                        lFitAtBegin then
                      begin
                        lBestPrev:=lPrev;
                        lBestSlot:=lCurrentTemp;
                        lBestAtEnd:=lFitAtEnd;
                      end;
                   end;
                end;
               lPrev:=lCurrentTemp;
               lCurrentTemp:=lCurrentTemp^.NextFree;
             end;
          end;
         { Reuse an old temp ? }
         if Assigned(lBestSlot) then
          begin
            if lBestSlot^.Size=ASize then
             begin
               lTemp:=lBestSlot;
               { Remove from the tempfreelist }
               if Assigned(lBestPrev) then
                 lBestPrev^.NextFree:=lTemp^.NextFree
               else
                 FTempFreeList:=lTemp^.NextFree;
             end
            else
             begin
               { Duplicate bestlost and the block in the list }
               new(lTemp);
               move(lBestSlot^,lTemp^,sizeof(TTempRecord));
               lTemp^.Next:=lBestSlot^.Next;
               lBestSlot^.Next:=lTemp;
               { Now we split the block in 2 parts. Depending on the direction
                 we need to resize the newly inserted block or the old reused block.
                 For direction=1 we can use tl for the new block. For direction=-1 we
                 will be reusing bestslot and resize the new block, that means we need
                 to swap the pointers }
               if (Direction=-1) xor
                  lBestAtEnd then
                 begin
                   lOtherTemp:=lTemp;
                   lTemp:=lBestSlot;
                   lBestSlot:=lOtherTemp;
                   { Update the tempfreelist to point to the new block }
                   if Assigned(lBestPrev) then
                     lBestPrev^.NextFree:=lBestSlot
                   else
                     FTempFreeList:=lBestSlot;
                 end;

               if not lBestAtEnd then
                 inc(lBestSlot^.Pos,ASize)
               else
                 inc(lTemp^.Pos,lTemp^.Size-ASize);

               { Create new block and resize the old block }
               lTemp^.Fini:=AFini;
               lTemp^.Size:=ASize;
               lTemp^.NextFree:=nil;
               { Resize the old block }
               dec(lBestSlot^.Size,ASize);
             end;
            lTemp^.TempType:=ATempType;
            lTemp^.Def:=ADef;
            lTemp^.Alignment:=AAlignment;
            lTemp^.NextFree:=nil;
          end
         else
          begin
            { now we can create the templist entry }
            new(lTemp);
            lTemp^.TempType:=ATempType;
            lTemp^.Def:=ADef;

            { Extend the temp }
            if Direction=-1 then
              begin
                if Int64(align(-LastTemp-AlignMismatch,AAlignment))+ASize+AlignMismatch>MaxLocalsSize then
                  begin
                    CGMessage(cg_e_localsize_too_big);
                    ASize:=0;  // Prevent further range check errors
                  end;
                LastTemp:=(-align(-LastTemp-AlignMismatch,AAlignment))-ASize-AlignMismatch;
                lTemp^.Pos:=LastTemp;
              end
            else
              begin
                lTemp^.Pos:=align(LastTemp+AlignMismatch,AAlignment)-AlignMismatch;
                if Int64(lTemp^.Pos)+ASize>MaxLocalsSize then
                  begin
                    CGMessage(cg_e_localsize_too_big);
                    ASize:=0;  // Prevent further range check errors
                  end;
                LastTemp:=lTemp^.Pos+ASize;
              end;
{$ifdef EXTDEBUG}
         Comment(VNote,'tgobj: (AllocTemp) lasttemp set to '+ToStr(LastTemp));
{$endif}
            lTemp^.Fini:=AFini;
            lTemp^.Alignment:=AAlignment;
            lTemp^.Size:=ASize;
            lTemp^.Next:=TempList;
            lTemp^.NextFree:=nil;
            TempList:=lTemp;
          end;
{$ifdef EXTDEBUG}
         lTemp^.PosInfo:=CurrentFilePos;
         if Assigned(lTemp^.Def) then
           AList.concat(TAITempAlloc.allocinfo(lTemp^.Pos,lTemp^.Size,'allocated with type '+TempTypeStr[lTemp^.TempType]+' for def '+lTemp^.Def.TypeName))
         else
           AList.concat(TAITempAlloc.allocinfo(lTemp^.Pos,lTemp^.Size,'allocated with type '+TempTypeStr[lTemp^.TempType]));
         Comment(VNote,'tgobj: (AllocTemp) temp of size '+ToStr(ASize)+' type '+TempTypeStr[lTemp^.TempType]+' requested, allocated at offset '+ToStr(lTemp^.Pos));
{$else}
         AList.concat(TAITempAlloc.alloc(lTemp^.Pos,lTemp^.Size));
{$endif}
         Temp_To_Ref(lTemp,AReference);
      end;


    procedure TTGObj.FreeTemp(AList: TAsmList; APos: TRefTempPos; ATempTypes: TTempTypeSet);
      var
         lCurrentTemp,lNext,lPrev,lPrevFree : PTempRecord;
      begin
         lCurrentTemp:=TempList;
         lPrev:=nil;
         lPrevFree:=nil;
{$ifdef EXTDEBUG}
         Comment(VNote,'tgobj: (FreeTemp) freeing of temp at pos '+ToStr(APos.Val)+' requested');
{$endif}
         while Assigned(lCurrentTemp) do
          begin
            if (lCurrentTemp^.Pos=APos.Val) then
             begin
               { check if already freed }
               if lCurrentTemp^.TempType in cFreeTempTypes then
                begin
{$ifdef EXTDEBUG}
                  Comment(VWarning,'tgobj: (FreeTemp) temp at pos '+ToStr(APos.Val)+ ' is already free !');
                  AList.concat(TAITempAlloc.allocinfo(lCurrentTemp^.Pos,lCurrentTemp^.Size,'temp is already freed'));
{$endif}
                  exit;
                end;
               { check type that are allowed to be released }
               if not(lCurrentTemp^.TempType in ATempTypes) then
                begin
{$ifdef DEBUG_FREETEMP}
                  if lCurrentTemp^.TempType = tt_persistent then
                    Comment(VNote,'tgobj: (Freetemp) temp at pos '+ToStr(APos.Val)+ ' has different type ('+TempTypeStr[lCurrentTemp^.TempType]+'), not releasing')
                  else
                    Comment(VWarning,'tgobj: (Freetemp) temp at pos '+ToStr(APos.Val)+ ' has different type ('+TempTypeStr[lCurrentTemp^.TempType]+'), not releasing');
                  AList.concat(TAITempAlloc.allocinfo(lCurrentTemp^.Pos,lCurrentTemp^.Size,'temp has wrong type ('+TempTypeStr[lCurrentTemp^.TempType]+') not releasing'));
{$endif}
                  exit;
                end;
               FreeTempHook(AList,lCurrentTemp);
               { set this block to free }
               lCurrentTemp^.TempType:=Used2Free[lCurrentTemp^.TempType];
               { Update tempfreelist }
               if Assigned(lPrevFree) then
                begin
                  { Concat blocks when the previous block is free and
                    there is no block assigned for a tdef }
                  if Assigned(lPrev) and
                     (lCurrentTemp^.TempType=tt_free) and
                     not Assigned(lCurrentTemp^.Def) and
                     (lPrev^.TempType=tt_free) and
                     not Assigned(lPrev^.Def) then
                   begin
                     inc(lPrev^.Size,lCurrentTemp^.Size);
                     if Direction=1 then
                       lPrev^.Pos:=lCurrentTemp^.Pos;
                     lPrev^.Next:=lCurrentTemp^.Next;
                     dispose(lCurrentTemp);
                     lCurrentTemp:=lPrev;
                   end
                  else
                   begin
                     lCurrentTemp^.NextFree:=lPrevFree^.NextFree;
                     lPrevFree^.NextFree:=lCurrentTemp;
                   end;
                end
               else
                begin
                  lCurrentTemp^.NextFree:=FTempFreeList;
                  FTempFreeList:=lCurrentTemp;
                end;
               { Concat blocks when the next block is free and
                 there is no block assigned for a tdef }
               lNext:=lCurrentTemp^.Next;
               if Assigned(lNext) and
                  (lCurrentTemp^.TempType=tt_free) and
                  not Assigned(lCurrentTemp^.Def) and
                  (lNext^.TempType=tt_free) and
                  not Assigned(lNext^.Def) then
                begin
                  inc(lCurrentTemp^.Size,lNext^.Size);
                  if Direction=1 then
                    lCurrentTemp^.Pos:=lNext^.Pos;
                  lCurrentTemp^.NextFree:=lNext^.NextFree;
                  lCurrentTemp^.Next:=lNext^.Next;
                  dispose(lNext);
                end;
               { Stop }
               exit;
             end;
            if (lCurrentTemp^.TempType=tt_free) then
              lPrevFree:=lCurrentTemp;
            lPrev:=lCurrentTemp;
            lCurrentTemp:=lCurrentTemp^.Next;
          end;
      end;


    procedure TTGObj.GetHLTemp(AList: TAsmList; ADef: TDef; AForceSize: asizeint; ATempType: TTempType; out AReference: TReference);
      begin
        GetTemp(AList,AForceSize,ADef.Alignment,ATempType,AReference);
      end;


    procedure TTGObj.GetHLTempManaged(AList: TAsmList; ADef: TDef; ATempType: TTempType; out AReference: TReference);
      begin
        GetTempManaged(AList,ADef,ATempType,AReference);
      end;


    procedure TTGObj.GetTemp(AList: TAsmList; ASize: asizeint; AAlignment: shortint; ATempType: TTempType; out AReference : TReference);
      begin
        GetTempInternal(AList,ASize,AAlignment,ATempType,nil,false,AReference);
      end;


    procedure TTGObj.GetTempInternal(AList: TAsmList; ASize: asizeint; AAlignment: shortint; ATempType: TTempType; ADef: TDef; AFini: boolean; out AReference : TReference);
      var
        lVarAlign : shortint;
      begin
        lVarAlign:=Used_Align(AAlignment,CurrentSettings.Alignment.LocalAlignMin,CurrentSettings.Alignment.LocalAlignMax);
        AllocTemp(AList,ASize,lVarAlign,ATempType,ADef,AFini,AReference);
      end;


    procedure TTGObj.FreeTempHook(AList: TAsmList; ATempRecord: PTempRecord);
      begin
        AList.concat(TAITempAlloc.dealloc(ATempRecord^.Pos,ATempRecord^.Size));
      end;


    procedure TTGObj.GetTempManaged(AList: TAsmList; ADef:TDef;ATempType:TTempType;out AReference : TReference);
      begin
        GetTempInternal(AList,ADef.Size,ADef.Alignment,ATempType,ADef,true,AReference);
      end;


    function TTGObj.IsTemp(const AReference : TReference) : boolean;
      begin
         IsTemp:=AReference.TempPos.Val<>CTempPosInvalid.Val;
      end;


    function TTGObj.SizeOfTemp(AList: TAsmList; const AReference: TReference): asizeint;
      var
         lCurrentTemp : PTempRecord;
      begin
         SizeOfTemp := -1;
         lCurrentTemp:=TempList;
         while Assigned(lCurrentTemp) do
           begin
             if (lCurrentTemp^.Pos=AReference.TempPos.Val) then
               begin
                 SizeOfTemp := lCurrentTemp^.Size;
                 exit;
               end;
             lCurrentTemp := lCurrentTemp^.Next;
           end;
{$ifdef EXTDEBUG}
         comment(VDebug,'tgobj: (SizeOfTemp) temp at pos '+ToStr(AReference.TempPos.Val)+' not found !');
         AList.concat(TAITempAlloc.allocinfo(AReference.TempPos.Val,0,'temp not found'));
{$endif}
      end;


    function TTGObj.ChangeTempType(AList: TAsmList; const AReference:TReference; ATempType:TTempType):boolean;
      var
        lCurrentTemp : PTempRecord;
      begin
         ChangeTempType:=false;
         lCurrentTemp:=TempList;
         while Assigned(lCurrentTemp) do
          begin
            if (lCurrentTemp^.Pos=AReference.TempPos.Val) then
             begin
               if lCurrentTemp^.TempType<>tt_free then
                begin
{$ifdef EXTDEBUG}
                  if lCurrentTemp^.TempType=ATempType then
                    Comment(VWarning,'tgobj: (ChangeTempType) temp'+
                       ' at pos '+ToStr(AReference.TempPos.Val)+ ' is already of the correct type !');
                  AList.concat(TAITempAlloc.allocinfo(lCurrentTemp^.Pos,lCurrentTemp^.Size,'type changed to '+TempTypeStr[ATempType]));
{$endif}
                  ChangeTempType:=true;
                  lCurrentTemp^.TempType:=ATempType;
                end
               else
                begin
{$ifdef EXTDEBUG}
                   Comment(VWarning,'tgobj: (ChangeTempType) temp'+
                      ' at pos '+ToStr(AReference.TempPos.Val)+ ' is already freed !');
                  AList.concat(TAITempAlloc.allocinfo(lCurrentTemp^.Pos,lCurrentTemp^.Size,'temp is already freed'));
{$endif}
                end;
               exit;
             end;
            lCurrentTemp:=lCurrentTemp^.Next;
          end;
{$ifdef EXTDEBUG}
         Comment(VWarning,'tgobj: (ChangeTempType) temp'+
            ' at pos '+ToStr(AReference.TempPos.Val)+ ' not found !');
         AList.concat(TAITempAlloc.allocinfo(AReference.TempPos.Val,0,'temp not found'));
{$endif}
      end;


    function TTGObj.GetTypeOfTemp(const AReference:TReference): TTempType;
      var
        lCurrentTemp : PTempRecord;
      begin
         lCurrentTemp:=TempList;
         while Assigned(lCurrentTemp) do
          begin
            if (lCurrentTemp^.Pos=AReference.TempPos.Val) then
             begin
               if lCurrentTemp^.TempType<>tt_free then
                 Result:=lCurrentTemp^.TempType
               else
                 InternalError(2007020810);
               exit;
             end;
            lCurrentTemp:=lCurrentTemp^.Next;
          end;
        Result:=tt_none;
      end;


    function TTGObj.IsStartOfTemp(const AReference: TReference): boolean;
      var
        lCurrentTemp: PTempRecord;
        lTempRef: TReference;
      begin
        lCurrentTemp:=TempList;
        if AReference.TempPos.Val=CTempPosInvalid.Val then
          begin
            Result:=false;
            exit;
          end;
        while Assigned(lCurrentTemp) do
         begin
           if (lCurrentTemp^.Pos=AReference.TempPos.Val) then
            begin
              if lCurrentTemp^.TempType=tt_free then
                begin
                  Result:=false;
                  exit;
                end;
              Temp_To_Ref(lCurrentTemp, lTempRef);
              Result:=References_Equal(AReference, lTempRef);
              exit;
            end;
           lCurrentTemp:=lCurrentTemp^.Next;
         end;
        Result:=false
      end;


    procedure TTGObj.Temp_To_Ref(ATempRecord: PTempRecord; out AReference: TReference);
      var
        lTempPos: TRefTempPos;
      begin
        lTempPos.Val:=ATempRecord^.Pos;
        Reference_Reset_Base(AReference,CurrentProcInfo.FramePointer,ATempRecord^.Pos,lTempPos,ATempRecord^.Alignment,[]);
      end;


    procedure TTGObj.UnGetTemp(AList: TAsmList; const AReference : TReference);
      begin
        FreeTemp(AList,AReference.TempPos,[tt_normal,tt_noreuse,tt_persistent,tt_regallocator]);
      end;


    procedure TTGObj.UnGetIfTemp(AList: TAsmList; const AReference : TReference);
      begin
        if IsTemp(AReference) then
          FreeTemp(AList,AReference.TempPos,[tt_normal]);
      end;


    procedure TTGObj.GetLocal(AList: TAsmList; ASize: asizeint; ADef: TDef; var AReference : TReference);
      begin
        if ADef.inheritsfrom(TAbstractRecordDef) and (ADef.typ in [recorddef])  then
          GetLocal(AList, ASize, ADef.Alignment, TAbstractRecordSymTable(TAbstractRecordDef(ADef).SymTable).ExplicitRecordAlignment, ADef, nil, AReference)
        else
          GetLocal(AList, ASize, ADef.Alignment, 0, ADef, nil, AReference);
      end;


    procedure TTGObj.GetLocal(AList: TAsmList; ASize: asizeint; AAlignment, AExplicitAlignment: shortint; ADef: TDef; ASym : TSym; var AReference : TReference);
      var
        lLocalAlign : shortint;
      begin
        lLocalAlign:=Used_Align(AAlignment,CurrentSettings.Alignment.LocalAlignMin,CurrentSettings.Alignment.LocalAlignMax);
        if (AExplicitAlignment>lLocalAlign) then
          begin
            if Assigned(ASym) then
              CGMessage1(scanner_w_local_alignment_larger_than_max,ASym.name)
            else
              CGMessage1(scanner_w_local_alignment_larger_than_max,ADef.TypeName);
          end
        else if (AAlignment>lLocalAlign) and (CurrentSettings.Alignment.LocalAlignMax>1) then
          begin
            if Assigned(ASym) then
              CGMessage1(scanner_n_local_alignment_larger_than_max,ASym.name)
            else
              CGMessage1(scanner_n_local_alignment_larger_than_max,ADef.TypeName);
	  end;
        AllocTemp(AList,ASize,lLocalAlign,tt_persistent,ADef,false,AReference);
      end;


    procedure TTGObj.UnGetLocal(AList: TAsmList; const AReference : TReference);
      begin
        FreeTemp(AList,AReference.TempPos,[tt_persistent]);
      end;


    procedure TTGObj.Discard_FreeList;
      begin
        FTempFreeList:=nil;
      end;

end.
