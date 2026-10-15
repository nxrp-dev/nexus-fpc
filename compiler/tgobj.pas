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
         temptype   : TTempType;
         { finalize this temp if it's a managed type }
         fini       : boolean;
         alignment  : shortint;
         pos        : asizeint;
         size       : asizeint;
         def        : TDef;
         next       : PTempRecord;
         nextfree   : PTempRecord; { for faster freeblock checking }
{$ifdef EXTDEBUG}
         posinfo,
         releaseposinfo : TFilePosInfo;
{$endif}
      end;


       {# Generates temporary variables }
       TTGObj = class
       protected
          { contains all free temps using nextfree links }
          tempfreelist  : PTempRecord;
          procedure alloctemp(list: TAsmList; size: asizeint; alignment: shortint; temptype: TTempType; def: TDef; fini: boolean; out ref: TReference); virtual;
          procedure freetemp(list: TAsmList; pos: TRefTempPos; temptypes: TTempTypeSet);virtual;
          procedure gettempinternal(list: TAsmList; size: asizeint; alignment: shortint; temptype: TTempType; def: TDef; fini: boolean; out ref : TReference);
          procedure freetemphook(list: TAsmList; temp: PTempRecord); virtual;
       public
          { contains all temps }
          templist      : PTempRecord;
          { Offsets of the first/last temp }
          firsttemp,
          lasttemp,
          { Offset of temp base register relative to guaranteed stack alignment
            (note: currently only behaves as expected if it's a power of 2,
               and if all requested alignments are also a power of 2) }
          alignmismatch: LongInt;
          direction : shortint;
          constructor create;virtual;reintroduce;
          {# Clear and free the complete linked list of temporary memory
             locations. The list is set to nil.}
          procedure resettempgen;
          {# Sets the first offset from the frame pointer or stack pointer where
             the temporary references will be allocated. It is to note that this
             value should always be negative.

             @param(l start offset where temps will start in stack)
          }
          procedure setfirsttemp(l: asizeint); virtual;
          procedure setalignmentmismatch(l: shortint); virtual;

          { version of gettemp that is compatible with hlcg-based targets;
            always use in common code, only use gettemp in cgobj and
            architecture-specific backends.

            the forcesize parameter is so that it can be used for defs that
            don't have an inherent size (e.g., array of const) }
          procedure gethltemp(list: TAsmList; def: TDef; forcesize: asizeint; temptype: TTempType; out ref: TReference); virtual;
          procedure gethltempmanaged(list: TAsmList; def: TDef; temptype: TTempType; out ref: TReference); virtual;
          procedure gettemp(list: TAsmList; size: asizeint; alignment: shortint; temptype: TTempType; out ref : TReference);
          procedure gettempmanaged(list: TAsmList; def:TDef;temptype:TTempType;out ref : TReference);
          procedure ungettemp(list: TAsmList; const ref : TReference); virtual;

          function sizeoftemp(list: TAsmList; const ref: TReference): asizeint;
          function changetemptype(list: TAsmList; const ref:TReference;temptype:TTempType):boolean;
          function gettypeoftemp(const ref:TReference): TTempType;
          function isstartoftemp(const ref: TReference): boolean;
          {# Returns a reference corresponding to a temp }
          procedure temp_to_ref(p: PTempRecord; out ref: TReference); virtual;


          {# Returns TRUE if the reference ref is allocated in temporary volatile memory space,
             otherwise returns FALSE.

             @param(ref reference to verify)
          }
          function istemp(const ref : TReference) : boolean; virtual;
          {# Frees a reference @var(ref) which was allocated in the volatile temporary memory space.
             The freed space can later be reallocated and reused. If this reference
             is not in the temporary memory, it is simply not freed.
          }
          procedure ungetiftemp(list: TAsmList; const ref : TReference); virtual;

          { Allocate space for a local }
          procedure getlocal(list: TAsmList; size: asizeint; def: TDef; var ref : TReference);
          procedure getlocal(list: TAsmList; size: asizeint; alignment,explicitalignment: shortint; def: TDef; sym : TSym; var ref : TReference); virtual;
          procedure UnGetLocal(list: TAsmList; const ref : TReference);
          { Discard the free list so that previously freed temp slots cannot be
            reused by subsequent allocations. Used on AArch64-Win64 before
            generating exceptfilter code to prevent handler temps from reusing
            freed parent slots. }
          procedure discard_freelist;
       end;
       TTGObjClass = class of TTGObj;

     var
       tg: TTGObj;
       tgobjclass: TTGObjClass = TTGObj;

    procedure location_freetemp(list:TAsmList; const l : TLocation);


implementation

    uses
       CUtils,
       Verbose,
       ProcInfo;


    const
      FreeTempTypes = [tt_free,tt_freenoreuse,tt_freeregallocator];

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

    procedure location_freetemp(list:TAsmList; const l : TLocation);
      begin
        if (l.loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
         tg.ungetiftemp(list,l.reference);
      end;


{*****************************************************************************
                                    TTGOBJ
*****************************************************************************}

    constructor TTGObj.create;

     begin
       tempfreelist:=nil;
       templist:=nil;
       { we could create a new child class for this but I don't if it is worth the effort (FK) }
{$ifdef aarch64}
       direction:=1;
{$else}
       direction:=-1;
{$endif}
     end;


    procedure TTGObj.resettempgen;
      var
         hp : PTempRecord;
      begin
        { Clear the old templist }
        while Assigned(templist) do
         begin
{$ifdef EXTDEBUG}
           if not(templist^.temptype in FreeTempTypes) then
             begin
               Comment(VWarning,'tgobj: (ResetTempgen) temp at pos '+ToStr(templist^.pos)+
                       ' with size '+ToStr(templist^.size)+' and type '+TempTypeStr[templist^.temptype]+
                       ' from pos '+ToStr(templist^.posinfo.line)+':'+ToStr(templist^.posinfo.column)+
                       ' not freed at the end of the procedure');
             end;
{$endif EXTDEBUG}
           hp:=templist;
           templist:=hp^.next;
           dispose(hp);
         end;
        templist:=nil;
        tempfreelist:=nil;
        firsttemp:=0;
        lasttemp:=0;
        alignmismatch:=0;
{$ifdef EXTDEBUG}
         Comment(VNote,'tgobj: (ResetTempGen) all temps freed');
{$endif}
      end;


    procedure TTGObj.setfirsttemp(l: asizeint);
      begin
         { this is a negative value normally }
         if l*direction>=0 then
          begin
            if odd(l) then
             inc(l,direction);
          end
         else
           InternalError(200204221);
         firsttemp:=l;
         lasttemp:=l;
{$ifdef EXTDEBUG}
         Comment(VNote,'tgobj: (SetFirstTempGen) set to '+ToStr(l));
{$endif}
      end;


    procedure TTGObj.setalignmentmismatch(l: shortint);
      begin
        alignmismatch:=l*direction;
      end;


    procedure TTGObj.alloctemp(list: TAsmList; size: asizeint; alignment: shortint; temptype: TTempType; def :TDef; fini: boolean; out ref: TReference);
      var
         tl,htl,
         bestslot,bestprev,
         hprev,hp : PTempRecord;
         freetype : TTempType;
         adjustedpos : LongInt;
         bestatend,
         fitatbegin,
         fitatend : boolean;
      begin
         bestprev:=nil;
         bestslot:=nil;
         tl:=nil;
         bestatend:=false;
         CurrentProcInfo.updatestackalignment(alignment);

         if size=0 then
          begin
{$ifdef EXTDEBUG}
            Comment(VNote,'tgobj: (AllocTemp) temp of size 0 requested, allocating 4 bytes');
{$endif}
            size:=4;
          end;

         freetype:=Used2Free[temptype];
         if freetype=tt_none then
           InternalError(200208201);
         if size>MaxLocalsSize then
            begin
              CGMessage(cg_e_localsize_too_big);
              size:=0;  // Prevent further range check errors
            end;
         size:=align(size,alignment);
         { First check the tmpfreelist, but not when
           we don't want to reuse an already allocated block }
         if Assigned(tempfreelist) and
            (temptype<>tt_noreuse) then
          begin
            hprev:=nil;
            hp:=tempfreelist;
            while Assigned(hp) do
             begin
{$ifdef EXTDEBUG}
               if not(hp^.temptype in FreeTempTypes) then
                 Comment(VWarning,'tgobj: (AllocTemp) temp at pos '+ToStr(hp^.pos)+ ' in freelist is not set to  a free temp type !');
{$endif}
               { Check only slots that are
                  - free
                  - share the same type if either has to be finalised
                  - contain enough space
                  - has a correct alignment }
               adjustedpos:=hp^.pos+alignmismatch;
               if (hp^.temptype=freetype) and
                  (hp^.fini=fini) and
                  ((hp^.def=def) or
                   not fini) and
                  (hp^.size>=size) and
                  ((adjustedpos=align(adjustedpos,alignment)) or
                   (adjustedpos+hp^.size-size = align(adjustedpos+hp^.size-size,alignment))) then
                begin
                  { Slot is the same size then leave immediately }
                  if (hp^.size=size) then
                   begin
                     bestprev:=hprev;
                     bestslot:=hp;
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
                     fitatend:=(adjustedpos+hp^.size-size)=align(adjustedpos+hp^.size-size,alignment);
                     fitatbegin:=adjustedpos=align(adjustedpos,alignment);
                     if Assigned(bestslot) then
                       begin
                         fitatend:=fitatend and
                           ((not bestatend and
                             (direction=-1)) or
                            (bestatend and
                             IsBetterAlignedThan(abs(bestslot^.pos+hp^.size-size),abs(adjustedpos+hp^.size-size),CurrentSettings.alignment.LocalAlignMax)));
                         fitatbegin:=fitatbegin and
                           (not bestatend or
                            (direction=1)) and
                           IsBetterAlignedThan(abs(adjustedpos+size),abs(bestslot^.pos+size),CurrentSettings.alignment.LocalAlignMax);
                       end;
                     if fitatend and
                        fitatbegin then
                       if IsBetterAlignedThan(abs(adjustedpos+hp^.size-size),abs(adjustedpos+size),CurrentSettings.alignment.LocalAlignMax) then
                         fitatbegin:=false
                       else if IsBetterAlignedThan(abs(adjustedpos+size),abs(adjustedpos+hp^.size-size),CurrentSettings.alignment.LocalAlignMax) then
                         fitatend:=false
                       else if (direction=1) then
                         fitatend:=false
                       else
                         fitatbegin:=false;
                     if fitatend or
                        fitatbegin then
                      begin
                        bestprev:=hprev;
                        bestslot:=hp;
                        bestatend:=fitatend;
                      end;
                   end;
                end;
               hprev:=hp;
               hp:=hp^.nextfree;
             end;
          end;
         { Reuse an old temp ? }
         if Assigned(bestslot) then
          begin
            if bestslot^.size=size then
             begin
               tl:=bestslot;
               { Remove from the tempfreelist }
               if Assigned(bestprev) then
                 bestprev^.nextfree:=tl^.nextfree
               else
                 tempfreelist:=tl^.nextfree;
             end
            else
             begin
               { Duplicate bestlost and the block in the list }
               new(tl);
               move(bestslot^,tl^,sizeof(TTempRecord));
               tl^.next:=bestslot^.next;
               bestslot^.next:=tl;
               { Now we split the block in 2 parts. Depending on the direction
                 we need to resize the newly inserted block or the old reused block.
                 For direction=1 we can use tl for the new block. For direction=-1 we
                 will be reusing bestslot and resize the new block, that means we need
                 to swap the pointers }
               if (direction=-1) xor
                  bestatend then
                 begin
                   htl:=tl;
                   tl:=bestslot;
                   bestslot:=htl;
                   { Update the tempfreelist to point to the new block }
                   if Assigned(bestprev) then
                     bestprev^.nextfree:=bestslot
                   else
                     tempfreelist:=bestslot;
                 end;

               if not bestatend then
                 inc(bestslot^.pos,size)
               else
                 inc(tl^.pos,tl^.size-size);

               { Create new block and resize the old block }
               tl^.fini:=fini;
               tl^.size:=size;
               tl^.nextfree:=nil;
               { Resize the old block }
               dec(bestslot^.size,size);
             end;
            tl^.temptype:=temptype;
            tl^.def:=def;
            tl^.alignment:=alignment;
            tl^.nextfree:=nil;
          end
         else
          begin
            { now we can create the templist entry }
            new(tl);
            tl^.temptype:=temptype;
            tl^.def:=def;

            { Extend the temp }
            if direction=-1 then
              begin
                if Int64(align(-lasttemp-alignmismatch,alignment))+size+alignmismatch>MaxLocalsSize then
                  begin
                    CGMessage(cg_e_localsize_too_big);
                    size:=0;  // Prevent further range check errors
                  end;
                lasttemp:=(-align(-lasttemp-alignmismatch,alignment))-size-alignmismatch;
                tl^.pos:=lasttemp;
              end
            else
              begin
                tl^.pos:=align(lasttemp+alignmismatch,alignment)-alignmismatch;
                if Int64(tl^.pos)+size>MaxLocalsSize then
                  begin
                    CGMessage(cg_e_localsize_too_big);
                    size:=0;  // Prevent further range check errors
                  end;
                lasttemp:=tl^.pos+size;
              end;
{$ifdef EXTDEBUG}
         Comment(VNote,'tgobj: (AllocTemp) lasttemp set to '+ToStr(lasttemp));
{$endif}
            tl^.fini:=fini;
            tl^.alignment:=alignment;
            tl^.size:=size;
            tl^.next:=templist;
            tl^.nextfree:=nil;
            templist:=tl;
          end;
{$ifdef EXTDEBUG}
         tl^.posinfo:=CurrentFilePos;
         if Assigned(tl^.def) then
           list.concat(TAITempAlloc.allocinfo(tl^.pos,tl^.size,'allocated with type '+TempTypeStr[tl^.temptype]+' for def '+tl^.def.TypeName))
         else
           list.concat(TAITempAlloc.allocinfo(tl^.pos,tl^.size,'allocated with type '+TempTypeStr[tl^.temptype]));
         Comment(VNote,'tgobj: (AllocTemp) temp of size '+ToStr(size)+' type '+TempTypeStr[tl^.temptype]+' requested, allocated at offset '+ToStr(tl^.pos));
{$else}
         list.concat(TAITempAlloc.alloc(tl^.pos,tl^.size));
{$endif}
         temp_to_ref(tl,ref);
      end;


    procedure TTGObj.FreeTemp(list: TAsmList; pos: TRefTempPos; temptypes: TTempTypeSet);
      var
         hp,hnext,hprev,hprevfree : PTempRecord;
      begin
         hp:=templist;
         hprev:=nil;
         hprevfree:=nil;
{$ifdef EXTDEBUG}
         Comment(VNote,'tgobj: (FreeTemp) freeing of temp at pos '+ToStr(pos.val)+' requested');
{$endif}
         while Assigned(hp) do
          begin
            if (hp^.pos=pos.val) then
             begin
               { check if already freed }
               if hp^.temptype in FreeTempTypes then
                begin
{$ifdef EXTDEBUG}
                  Comment(VWarning,'tgobj: (FreeTemp) temp at pos '+ToStr(pos.val)+ ' is already free !');
                  list.concat(TAITempAlloc.allocinfo(hp^.pos,hp^.size,'temp is already freed'));
{$endif}
                  exit;
                end;
               { check type that are allowed to be released }
               if not(hp^.temptype in temptypes) then
                begin
{$ifdef DEBUG_FREETEMP}
                  if hp^.temptype = tt_persistent then
                    Comment(VNote,'tgobj: (Freetemp) temp at pos '+ToStr(pos.val)+ ' has different type ('+TempTypeStr[hp^.temptype]+'), not releasing')
                  else
                    Comment(VWarning,'tgobj: (Freetemp) temp at pos '+ToStr(pos.val)+ ' has different type ('+TempTypeStr[hp^.temptype]+'), not releasing');
                  list.concat(TAITempAlloc.allocinfo(hp^.pos,hp^.size,'temp has wrong type ('+TempTypeStr[hp^.temptype]+') not releasing'));
{$endif}
                  exit;
                end;
               freetemphook(list,hp);
               { set this block to free }
               hp^.temptype:=Used2Free[hp^.temptype];
               { Update tempfreelist }
               if Assigned(hprevfree) then
                begin
                  { Concat blocks when the previous block is free and
                    there is no block assigned for a tdef }
                  if Assigned(hprev) and
                     (hp^.temptype=tt_free) and
                     not Assigned(hp^.def) and
                     (hprev^.temptype=tt_free) and
                     not Assigned(hprev^.def) then
                   begin
                     inc(hprev^.size,hp^.size);
                     if direction=1 then
                       hprev^.pos:=hp^.pos;
                     hprev^.next:=hp^.next;
                     dispose(hp);
                     hp:=hprev;
                   end
                  else
                   begin
                     hp^.nextfree:=hprevfree^.nextfree;
                     hprevfree^.nextfree:=hp;
                   end;
                end
               else
                begin
                  hp^.nextfree:=tempfreelist;
                  tempfreelist:=hp;
                end;
               { Concat blocks when the next block is free and
                 there is no block assigned for a tdef }
               hnext:=hp^.next;
               if Assigned(hnext) and
                  (hp^.temptype=tt_free) and
                  not Assigned(hp^.def) and
                  (hnext^.temptype=tt_free) and
                  not Assigned(hnext^.def) then
                begin
                  inc(hp^.size,hnext^.size);
                  if direction=1 then
                    hp^.pos:=hnext^.pos;
                  hp^.nextfree:=hnext^.nextfree;
                  hp^.next:=hnext^.next;
                  dispose(hnext);
                end;
               { Stop }
               exit;
             end;
            if (hp^.temptype=tt_free) then
              hprevfree:=hp;
            hprev:=hp;
            hp:=hp^.next;
          end;
      end;


    procedure TTGObj.gethltemp(list: TAsmList; def: TDef; forcesize: asizeint; temptype: TTempType; out ref: TReference);
      begin
        gettemp(list,forcesize,def.alignment,temptype,ref);
      end;


    procedure TTGObj.gethltempmanaged(list: TAsmList; def: TDef; temptype: TTempType; out ref: TReference);
      begin
        gettempmanaged(list,def,temptype,ref);
      end;


    procedure TTGObj.gettemp(list: TAsmList; size: asizeint; alignment: shortint; temptype: TTempType; out ref : TReference);
      begin
        gettempinternal(list,size,alignment,temptype,nil,false,ref);
      end;


    procedure TTGObj.gettempinternal(list: TAsmList; size: asizeint; alignment: shortint; temptype: TTempType; def: TDef; fini: boolean; out ref : TReference);
      var
        varalign : shortint;
      begin
        varalign:=Used_Align(alignment,CurrentSettings.alignment.LocalAlignMin,CurrentSettings.alignment.LocalAlignMax);
        alloctemp(list,size,varalign,temptype,def,fini,ref);
      end;


    procedure TTGObj.freetemphook(list: TAsmList; temp: PTempRecord);
      begin
        list.concat(TAITempAlloc.dealloc(temp^.pos,temp^.size));
      end;


    procedure TTGObj.gettempmanaged(list: TAsmList; def:TDef;temptype:TTempType;out ref : TReference);
      begin
        gettempinternal(list,def.size,def.alignment,temptype,def,true,ref);
      end;


    function TTGObj.istemp(const ref : TReference) : boolean;
      begin
         istemp:=ref.temppos.val<>ctempposinvalid.val;
      end;


    function TTGObj.sizeoftemp(list: TAsmList; const ref: TReference): asizeint;
      var
         hp : PTempRecord;
      begin
         SizeOfTemp := -1;
         hp:=templist;
         while Assigned(hp) do
           begin
             if (hp^.pos=ref.temppos.val) then
               begin
                 sizeoftemp := hp^.size;
                 exit;
               end;
             hp := hp^.next;
           end;
{$ifdef EXTDEBUG}
         comment(VDebug,'tgobj: (SizeOfTemp) temp at pos '+ToStr(ref.temppos.val)+' not found !');
         list.concat(TAITempAlloc.allocinfo(ref.temppos.val,0,'temp not found'));
{$endif}
      end;


    function TTGObj.changetemptype(list: TAsmList; const ref:TReference; temptype:TTempType):boolean;
      var
        hp : PTempRecord;
      begin
         ChangeTempType:=false;
         hp:=templist;
         while Assigned(hp) do
          begin
            if (hp^.pos=ref.temppos.val) then
             begin
               if hp^.temptype<>tt_free then
                begin
{$ifdef EXTDEBUG}
                  if hp^.temptype=temptype then
                    Comment(VWarning,'tgobj: (ChangeTempType) temp'+
                       ' at pos '+ToStr(ref.temppos.val)+ ' is already of the correct type !');
                  list.concat(TAITempAlloc.allocinfo(hp^.pos,hp^.size,'type changed to '+TempTypeStr[temptype]));
{$endif}
                  ChangeTempType:=true;
                  hp^.temptype:=temptype;
                end
               else
                begin
{$ifdef EXTDEBUG}
                   Comment(VWarning,'tgobj: (ChangeTempType) temp'+
                      ' at pos '+ToStr(ref.temppos.val)+ ' is already freed !');
                  list.concat(TAITempAlloc.allocinfo(hp^.pos,hp^.size,'temp is already freed'));
{$endif}
                end;
               exit;
             end;
            hp:=hp^.next;
          end;
{$ifdef EXTDEBUG}
         Comment(VWarning,'tgobj: (ChangeTempType) temp'+
            ' at pos '+ToStr(ref.temppos.val)+ ' not found !');
         list.concat(TAITempAlloc.allocinfo(ref.temppos.val,0,'temp not found'));
{$endif}
      end;


    function TTGObj.gettypeoftemp(const ref:TReference): TTempType;
      var
        hp : PTempRecord;
      begin
         hp:=templist;
         while Assigned(hp) do
          begin
            if (hp^.pos=ref.temppos.val) then
             begin
               if hp^.temptype<>tt_free then
                 result:=hp^.temptype
               else
                 InternalError(2007020810);
               exit;
             end;
            hp:=hp^.next;
          end;
        result:=tt_none;
      end;


    function TTGObj.isstartoftemp(const ref: TReference): boolean;
      var
        hp: PTempRecord;
        tmpref: TReference;
      begin
        hp:=templist;
        if ref.temppos.val=ctempposinvalid.val then
          begin
            result:=false;
            exit;
          end;
        while Assigned(hp) do
         begin
           if (hp^.pos=ref.temppos.val) then
            begin
              if hp^.temptype=tt_free then
                begin
                  result:=false;
                  exit;
                end;
              temp_to_ref(hp, tmpref);
              result:=references_equal(ref, tmpref);
              exit;
            end;
           hp:=hp^.next;
         end;
        result:=false
      end;


    procedure TTGObj.temp_to_ref(p: PTempRecord; out ref: TReference);
      var
        t: TRefTempPos;
      begin
        t.val:=p^.pos;
        reference_reset_base(ref,CurrentProcInfo.framepointer,p^.pos,t,p^.alignment,[]);
      end;


    procedure TTGObj.UnGetTemp(list: TAsmList; const ref : TReference);
      begin
        FreeTemp(list,ref.temppos,[tt_normal,tt_noreuse,tt_persistent,tt_regallocator]);
      end;


    procedure TTGObj.UnGetIfTemp(list: TAsmList; const ref : TReference);
      begin
        if istemp(ref) then
          FreeTemp(list,ref.temppos,[tt_normal]);
      end;


    procedure TTGObj.getlocal(list: TAsmList; size: asizeint; def: TDef; var ref : TReference);
      begin
        if def.inheritsfrom(TAbstractRecordDef) and (def.typ in [recorddef])  then
          getlocal(list, size, def.alignment, TAbstractRecordSymTable(TAbstractRecordDef(def).SymTable).ExplicitRecordAlignment, def, nil, ref)
        else
          getlocal(list, size, def.alignment, 0, def, nil, ref);
      end;


    procedure TTGObj.getlocal(list: TAsmList; size: asizeint; alignment, explicitalignment: shortint; def: TDef; sym : TSym; var ref : TReference);
      var
        lalign : shortint;
      begin
        lalign:=Used_Align(alignment,CurrentSettings.alignment.LocalAlignMin,CurrentSettings.alignment.LocalAlignMax);
        if (explicitalignment>lalign) then
          begin
            if Assigned(sym) then
              CGMessage1(scanner_w_local_alignment_larger_than_max,sym.name)
            else
              CGMessage1(scanner_w_local_alignment_larger_than_max,def.TypeName);
          end
        else if (alignment>lalign) and (CurrentSettings.alignment.LocalAlignMax>1) then
          begin
            if Assigned(sym) then
              CGMessage1(scanner_n_local_alignment_larger_than_max,sym.name)
            else
              CGMessage1(scanner_n_local_alignment_larger_than_max,def.TypeName);
	  end;
        alloctemp(list,size,lalign,tt_persistent,def,false,ref);
      end;


    procedure TTGObj.UnGetLocal(list: TAsmList; const ref : TReference);
      begin
        FreeTemp(list,ref.temppos,[tt_persistent]);
      end;


    procedure TTGObj.discard_freelist;
      begin
        tempfreelist:=nil;
      end;

end.
