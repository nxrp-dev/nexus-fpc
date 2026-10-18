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

       CGBase,CGUtils,
       SymType;

    type
       TCGParaReference = record
          Index       : TRegister;
          Offset      : ASizeInt;
       end;

       PCGParaLocation = ^TCGParaLocation;
       TCGParaLocation = record
         Next : PCGParaLocation;
         Def  : TDef;
         Size : TCgSize; { size of this location }
         Loc  : TCGLoc;

         case TCGLoc of
           LOC_REFERENCE : (Reference : TCGParaReference);
           LOC_FPUREGISTER,
           LOC_CFPUREGISTER,
           LOC_MMREGISTER,
           LOC_CMMREGISTER,
           LOC_REGISTER,
           LOC_CREGISTER : (
             Register : TRegister);
       end;

       { TCGPara }

       TCGPara = object
          Def       : TDef; { Type of the parameter }
          Location  : PCGParaLocation;
          IntSize   : TCGInt; { size of the total location in bytes }
          DefDeref  : TDeref;
          Alignment : ShortInt; { in case of LLVM, a negative alignment mean: force write the alignment }
          Size      : TCgSize;  { Size of the parameter included in all locations }
          Temporary : Boolean;  { created on the fly, no permanent references exist to this somewhere that will cause it to be disposed }
          constructor Init;
          destructor  Done;
          procedure   Reset;
          procedure   ResetIfTemp; { reset if Temporary }
          function    GetCopy:TCGPara;
          procedure   Check_Simple_Location;
          function    Add_Location:PCGParaLocation;
          procedure   Get_Location(var NewLoc:TLocation);
          function    Locations_Count:Integer;
          function    IsEmpty: Boolean; { no data, and not varargs para }

          procedure   BuildDeref;
          procedure   Deref;
          procedure   PPUWrite(PPUFile:TCompilerPPUFile);
          procedure   PPULoad(PPUFile:TCompilerPPUFile);
       end;
       PCGPara = ^TCGPara;

       TVarArgsInfo = (
         va_uses_float_reg
       );

       TParaList = class(TFPObjectList)
          procedure SortParas;
       end;

       TVarArgsParaList = class(TParaList)
          VarArgsInfo : set of TVarArgsInfo;
{$ifdef x86_64}
          { x86_64 requires %al to contain the no. SSE regs passed }
          MMRegsUsed  : LongInt;
{$endif x86_64}
       end;


       TRTTIParaLoc = record
         { contains the regtype in bits 0-6 and whether it's reference or not
           in bit 7 }
         LocType : Byte;
         RegSub : Byte;
         RegIndex : Word;
         { Stack offset; zero for register locations. }
         Offset : AInt;
       end;


       TRTTIParaLocs = array of TRTTIParaLoc;


implementation

    uses
      Systems,Verbose,
      SymSym,DefUtil;


{****************************************************************************
                                TCGPara
****************************************************************************}

    constructor TCGPara.Init;
      begin
        Alignment:=0;
        Size:=OS_NO;
        IntSize:=0;
        Location:=nil;
        Def:=nil;
        Temporary:=False;
      end;


    destructor TCGPara.Done;
      begin
        Reset;
      end;


    procedure TCGPara.Reset;
      var
        HLocation : PCGParaLocation;
      begin
        while Assigned(Location) do
          begin
            HLocation:=Location^.Next;
            Dispose(Location);
            Location:=HLocation;
          end;
        Alignment:=0;
        Size:=OS_NO;
        IntSize:=0;
      end;

    procedure TCGPara.ResetIfTemp;
      begin
        if Temporary then
          Reset;
      end;


    function TCGPara.GetCopy:TCGPara;
      var
        SrcLoc,HLocation : PCGParaLocation;
      begin
        Result.Init;
        SrcLoc:=Location;
        while Assigned(SrcLoc) do
          begin
            HLocation:=Result.Add_Location;
            HLocation^:=SrcLoc^;
            HLocation^.Next:=nil;
            SrcLoc:=SrcLoc^.Next;
          end;
        Result.Alignment:=Alignment;
        Result.Size:=Size;
        Result.IntSize:=IntSize;
        Result.Def:=Def;
        Result.Temporary:=Temporary;
      end;


    function TCGPara.Add_Location:PCGParaLocation;
      var
        PrevLocation,
        HLocation : PCGParaLocation;
      begin
        PrevLocation:=nil;
        HLocation:=Location;
        while Assigned(HLocation) do
          begin
            PrevLocation:=HLocation;
            HLocation:=HLocation^.Next;
          end;
        New(HLocation);
        FillChar(HLocation^,SizeOf(TCGParaLocation),0);
        if Assigned(PrevLocation) then
          PrevLocation^.Next:=HLocation
        else
          Location:=HLocation;
        Result:=HLocation;
      end;


    procedure TCGPara.Check_Simple_Location;
      begin
        if not Assigned(Location) then
          InternalError(200408161);
        if Assigned(Location^.Next) then
          InternalError(200408162);
      end;


    procedure TCGPara.Get_Location(var NewLoc:TLocation);
      begin
        if not Assigned(Location) then
          InternalError(200408205);
        FillChar(NewLoc,SizeOf(NewLoc),0);
        NewLoc.Loc:=Location^.Loc;
        NewLoc.Size:=Size;
        case Location^.Loc of
          LOC_REGISTER :
            begin
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
              if Size in [OS_64,OS_S64] then
                begin
                  if not Assigned(Location^.Next) then
                    InternalError(200408206);
                  if (Location^.Next^.Loc<>LOC_REGISTER) then
                    InternalError(200408207);
                  begin
                      NewLoc.Register64.RegLo:=Location^.Register;
                      NewLoc.Register64.RegHi:=Location^.Next^.Register;
                    end;
                end
              else
{$endif}
                NewLoc.Register:=Location^.Register;
            end;
          LOC_FPUREGISTER,
          LOC_MMREGISTER :
            NewLoc.Register:=Location^.Register;
          LOC_REFERENCE :
            begin
              NewLoc.Reference.Base:=Location^.Reference.Index;
              NewLoc.Reference.Offset:=Location^.Reference.Offset;
              NewLoc.Reference.Alignment:=Alignment;
            end;
          LOC_VOID:
            ;
          else
            InternalError(2019050705);
        end;
      end;


    function TCGPara.Locations_Count: Integer;
      var
        HLocation: PCGParaLocation;
      begin
        Result:=0;
        HLocation:=Location;
        while Assigned(HLocation) do
          begin
            Inc(Result);
            HLocation:=HLocation^.Next;
          end;
      end;


    function TCGPara.IsEmpty: Boolean;
      var
        HLocation: PCGParaLocation;
      begin
        { can happen if e.g. [] is passed to a cdecl varargs para }
        if not Assigned(Def) then
          Exit(True);
        if Is_Array_Of_Const(Def) then
          Exit(False);
        HLocation:=Location;
        while Assigned(HLocation) do
          begin
            if HLocation^.Loc<>LOC_VOID then
              Exit(False);
            HLocation:=HLocation^.Next;
          end;
        Result:=True;
      end;

    procedure TCGPara.BuildDeref;
      begin
        DefDeref.Build(Def);
      end;


    procedure TCGPara.Deref;
      begin
        Def:=TDef(DefDeref.Resolve);
      end;


    procedure TCGPara.PPUWrite(PPUFile: TCompilerPPUFile);
      var
        HParaLoc: PCGParaLocation;
        NParaLoc: Byte;
      begin
        PPUFile.PutByte(Byte(Alignment));
        PPUFile.PutByte(Ord(Size));
        PPUFile.PutAInt(IntSize);
        PPUFile.PutDeref(DefDeref);
        NParaLoc:=0;
        HParaLoc:=Location;
        while Assigned(HParaLoc) do
          begin
            Inc(NParaLoc);
            HParaLoc:=HParaLoc^.Next;
          end;
        PPUFile.PutByte(NParaLoc);
        HParaLoc:=Location;
        while Assigned(HParaLoc) do
          begin
            PPUFile.PutByte(Byte(HParaLoc^.Size));
            PPUFile.PutByte(Byte(HParaLoc^.Loc));
            case HParaLoc^.Loc of
              LOC_REFERENCE:
                begin
                  PPUFile.PutLongInt(LongInt(HParaLoc^.Reference.Index));
                  PPUFile.PutAInt(HParaLoc^.Reference.Offset);
                end;
              LOC_FPUREGISTER,
              LOC_CFPUREGISTER,
              LOC_MMREGISTER,
              LOC_CMMREGISTER,
              LOC_REGISTER,
              LOC_CREGISTER :
                begin
                  PPUFile.PutByte(0); { Reserved parameter-alignment byte. }
                  PPUFile.PutLongInt(LongInt(HParaLoc^.Register));
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
            HParaLoc:=HParaLoc^.Next;
          end;
      end;


    procedure TCGPara.PPULoad(PPUFile: TCompilerPPUFile);
      var
        HParaLoc: PCGParaLocation;
        NParaLoc: Byte;
      begin
        Reset;
        Alignment:=ShortInt(PPUFile.GetByte);
        Size:=TCgSize(PPUFile.GetByte);
        IntSize:=PPUFile.GetAInt;
        PPUFile.GetDeref(DefDeref);
        NParaLoc:=PPUFile.GetByte;
        while NParaLoc>0 do
          begin
            HParaLoc:=Add_Location;
            HParaLoc^.Size:=TCgSize(PPUFile.GetByte);
            HParaLoc^.Loc:=TCGLoc(PPUFile.GetByte);
            case HParaLoc^.Loc of
              LOC_REFERENCE:
                begin
                  HParaLoc^.Reference.Index:=TRegister(PPUFile.GetLongInt);
                  HParaLoc^.Reference.Offset:=PPUFile.GetAInt;
                end;
              LOC_FPUREGISTER,
              LOC_CFPUREGISTER,
              LOC_MMREGISTER,
              LOC_CMMREGISTER,
              LOC_REGISTER,
              LOC_CREGISTER :
                begin
                  PPUFile.GetByte; { Reserved parameter-alignment byte. }
                  HParaLoc^.Register:=TRegister(PPUFile.GetLongInt);
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
            Dec(NParaLoc);
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
