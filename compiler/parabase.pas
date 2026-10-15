{
    Copyright (c) 2002 by Florian Klaempfl

    Generic calling convention handling

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
unit parabase;

{$i fpcdefs.inc}

  interface

    uses
       CClasses,GlobType,

       cgbase,cgutils,
       symtype;

    type
       TCGParaReference = record
          index       : TRegister;
          offset      : asizeint;
       end;

       PCGParaLocation = ^TCGParaLocation;
       TCGParaLocation = record
         Next : PCGParaLocation;
         Def  : TDef;
         Size : TCgSize; { size of this location }
         Loc  : TCGLoc;

         case TCGLoc of
           LOC_REFERENCE : (reference : TCGParaReference);
           LOC_FPUREGISTER,
           LOC_CFPUREGISTER,
           LOC_MMREGISTER,
           LOC_CMMREGISTER,
           LOC_REGISTER,
           LOC_CREGISTER : (
             {

             * If shiftval > 0:

             The number of bits the value in the register must be shifted to the left before
             it can be stored to memory in the function prolog.
             This is used for passing OS_NO memory blocks less than register size and of "odd"
             (3, 5, 6, 7) size on big endian machines, so that small memory blocks passed via
             registers are properly aligned.

             E.g. the value $5544433 is passed in bits 40-63 of the register (others are zero),
             but they should actually be stored in the first bits of the stack location reserved
             for this value. So they have to be shifted left by this amount of bits before.

             * if shiftval < 0:

             Similar as above, but the shifting must always be done and
               1) for all parameter sizes < regsize
               2) on the caller side
             }
             shiftval : shortint;
             register : TRegister);
       end;

       { TCGPara }

       TCGPara = object
          Def       : TDef; { Type of the parameter }
          Location  : PCGParaLocation;
          IntSize   : TCGInt; { size of the total location in bytes }
          DefDeref  : TDeref;
          Alignment : ShortInt; { in case of LLVM, a negative alignment mean: force write the alignment }
          Size      : TCgSize;  { Size of the parameter included in all locations }
          Temporary : boolean;  { created on the fly, no permanent references exist to this somewhere that will cause it to be disposed }
          constructor init;
          destructor  done;
          procedure   reset;
          procedure   resetiftemp; { reset if Temporary }
          function    GetCopy:TCGPara;
          procedure   check_simple_location;
          function    add_location:PCGParaLocation;
          procedure   get_location(var newloc:TLocation);
          function    locations_count:integer;
          function    isempty: boolean; { no data, and not varargs para }

          procedure   BuildDeref;
          procedure   deref;
          procedure   ppuwrite(ppufile:TCompilerPPUFile);
          procedure   ppuload(ppufile:TCompilerPPUFile);
       end;
       PCGPara = ^TCGPara;

       TVarArgsInfo = (
         va_uses_float_reg
       );

       TParaList = class(TFPObjectList)
          procedure SortParas;
       end;

       TVarArgsParaList = class(TParaList)
          varargsinfo : set of TVarArgsInfo;
{$ifdef x86_64}
          { x86_64 requires %al to contain the no. SSE regs passed }
          mmregsused  : LongInt;
{$endif x86_64}
       end;


       TRTTIParaLoc = record
         { contains the regtype in bits 0-6 and whether it's reference or not
           in bit 7 }
         loctype : byte;
         regsub : byte;
         regindex : word;
         { either stack offset or shiftval }
         offset : aint;
       end;


       TRTTIParaLocs = array of TRTTIParaLoc;


implementation

    uses
      Systems,Verbose,
      SymSym,defutil;


{****************************************************************************
                                TCGPara
****************************************************************************}

    constructor TCGPara.init;
      begin
        alignment:=0;
        size:=OS_NO;
        intsize:=0;
        location:=nil;
        def:=nil;
        temporary:=false;
      end;


    destructor TCGPara.done;
      begin
        reset;
      end;


    procedure TCGPara.reset;
      var
        hlocation : PCGParaLocation;
      begin
        while Assigned(location) do
          begin
            hlocation:=location^.next;
            dispose(location);
            location:=hlocation;
          end;
        alignment:=0;
        size:=OS_NO;
        intsize:=0;
      end;

    procedure TCGPara.resetiftemp;
      begin
        if temporary then
          reset;
      end;


    function TCGPara.GetCopy:TCGPara;
      var
        srcloc,hlocation : PCGParaLocation;
      begin
        result.init;
        srcloc:=location;
        while Assigned(srcloc) do
          begin
            hlocation:=result.add_location;
            hlocation^:=srcloc^;
            hlocation^.next:=nil;
            srcloc:=srcloc^.next;
          end;
        result.alignment:=alignment;
        result.size:=size;
        result.intsize:=intsize;
        result.def:=def;
        result.Temporary:=Temporary;
      end;


    function TCGPara.add_location:PCGParaLocation;
      var
        prevlocation,
        hlocation : PCGParaLocation;
      begin
        prevlocation:=nil;
        hlocation:=location;
        while Assigned(hlocation) do
          begin
            prevlocation:=hlocation;
            hlocation:=hlocation^.next;
          end;
        new(hlocation);
        Fillchar(hlocation^,sizeof(TCGParaLocation),0);
        if Assigned(prevlocation) then
          prevlocation^.next:=hlocation
        else
          location:=hlocation;
        result:=hlocation;
      end;


    procedure TCGPara.check_simple_location;
      begin
        if not Assigned(location) then
          InternalError(200408161);
        if Assigned(location^.next) then
          InternalError(200408162);
      end;


    procedure TCGPara.get_location(var newloc:TLocation);
      begin
        if not Assigned(location) then
          InternalError(200408205);
        fillchar(newloc,sizeof(newloc),0);
        newloc.loc:=location^.loc;
        newloc.size:=size;
        case location^.loc of
          LOC_REGISTER :
            begin
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
              if size in [OS_64,OS_S64] then
                begin
                  if not Assigned(location^.next) then
                    InternalError(200408206);
                  if (location^.next^.loc<>LOC_REGISTER) then
                    InternalError(200408207);
                  if (TargetInfo.endian = ENDIAN_BIG) then
                    begin
                      newloc.register64.reghi:=location^.register;
                      newloc.register64.reglo:=location^.next^.register;
                    end
                  else
                    begin
                      newloc.register64.reglo:=location^.register;
                      newloc.register64.reghi:=location^.next^.register;
                    end;
                end
              else
{$endif}
                newloc.register:=location^.register;
            end;
          LOC_FPUREGISTER,
          LOC_MMREGISTER :
            newloc.register:=location^.register;
          LOC_REFERENCE :
            begin
              newloc.reference.base:=location^.reference.index;
              newloc.reference.offset:=location^.reference.offset;
              newloc.reference.alignment:=alignment;
            end;
          LOC_VOID:
            ;
          else
            InternalError(2019050705);
        end;
      end;


    function TCGPara.locations_count: integer;
      var
        hlocation: PCGParaLocation;
      begin
        result:=0;
        hlocation:=location;
        while Assigned(hlocation) do
          begin
            inc(result);
            hlocation:=hlocation^.next;
          end;
      end;


    function TCGPara.isempty: boolean;
      var
        hlocation: PCGParaLocation;
      begin
        { can happen if e.g. [] is passed to a cdecl varargs para }
        if not Assigned(def) then
          exit(true);
        if is_array_of_const(def) then
          exit(false);
        hlocation:=location;
        while Assigned(hlocation) do
          begin
            if hlocation^.Loc<>LOC_VOID then
              exit(false);
            hlocation:=hlocation^.next;
          end;
        result:=true;
      end;

    procedure TCGPara.BuildDeref;
      begin
        DefDeref.build(def);
      end;


    procedure TCGPara.deref;
      begin
        def:=TDef(DefDeref.resolve);
      end;


    procedure TCGPara.ppuwrite(ppufile: TCompilerPPUFile);
      var
        hparaloc: PCGParaLocation;
        nparaloc: byte;
      begin
        ppufile.PutByte(byte(Alignment));
        ppufile.PutByte(ord(Size));
        ppufile.PutAInt(IntSize);
        ppufile.PutDeref(DefDeref);
        nparaloc:=0;
        hparaloc:=location;
        while Assigned(hparaloc) do
          begin
            inc(nparaloc);
            hparaloc:=hparaloc^.Next;
          end;
        ppufile.PutByte(nparaloc);
        hparaloc:=location;
        while Assigned(hparaloc) do
          begin
            ppufile.PutByte(byte(hparaloc^.Size));
            ppufile.PutByte(byte(hparaloc^.loc));
            case hparaloc^.loc of
              LOC_REFERENCE:
                begin
                  ppufile.PutLongInt(LongInt(hparaloc^.reference.index));
                  ppufile.PutAInt(hparaloc^.reference.offset);
                end;
              LOC_FPUREGISTER,
              LOC_CFPUREGISTER,
              LOC_MMREGISTER,
              LOC_CMMREGISTER,
              LOC_REGISTER,
              LOC_CREGISTER :
                begin
                  ppufile.PutByte(hparaloc^.shiftval);
                  ppufile.PutLongInt(LongInt(hparaloc^.register));
                end;
              { This seems to be required for systems using explicitparaloc (eg. MorphOS)
                or otherwise it hits the internalerror below. I don't know if this is
                the proper way to fix this, someone else with clue might want to take a
                look. The compiler cycles on the affected systems with this enabled. (KB) }
              LOC_VOID:
                begin end
              else
                InternalError(2010053115);
            end;
            hparaloc:=hparaloc^.next;
          end;
      end;


    procedure TCGPara.ppuload(ppufile: TCompilerPPUFile);
      var
        hparaloc: PCGParaLocation;
        nparaloc: byte;
      begin
        reset;
        Alignment:=shortint(ppufile.GetByte);
        Size:=TCgSize(ppufile.GetByte);
        IntSize:=ppufile.GetAInt;
        ppufile.GetDeref(DefDeref);
        nparaloc:=ppufile.GetByte;
        while nparaloc>0 do
          begin
            hparaloc:=add_location;
            hparaloc^.size:=TCgSize(ppufile.GetByte);
            hparaloc^.loc:=TCGLoc(ppufile.GetByte);
            case hparaloc^.loc of
              LOC_REFERENCE:
                begin
                  hparaloc^.reference.index:=TRegister(ppufile.GetLongInt);
                  hparaloc^.reference.offset:=ppufile.GetAInt;
                end;
              LOC_FPUREGISTER,
              LOC_CFPUREGISTER,
              LOC_MMREGISTER,
              LOC_CMMREGISTER,
              LOC_REGISTER,
              LOC_CREGISTER :
                begin
                  hparaloc^.shiftval:=ppufile.GetByte;
                  hparaloc^.register:=TRegister(ppufile.GetLongInt);
                end;
              { This seems to be required for systems using explicitparaloc (eg. MorphOS)
                or otherwise it hits the internalerror below. I don't know if this is
                the proper way to fix this, someone else with clue might want to take a
                look. The compiler cycles on the affected systems with this enabled. (KB) }
              LOC_VOID:
                begin end
              else
                InternalError(2010051301);
            end;
            dec(nparaloc);
          end;
      end;


{****************************************************************************
                          TParaList
****************************************************************************}

    function ParaNrCompare(Item1, Item2: Pointer): Integer;
      var
        I1 : TParaVarSym absolute Item1;
        I2 : TParaVarSym absolute Item2;
      begin
        Result:=LongInt(I1.ParaNr)-LongInt(I2.ParaNr);
      end;


    procedure TParaList.SortParas;
      begin
        Sort(@ParaNrCompare);
      end;


end.
