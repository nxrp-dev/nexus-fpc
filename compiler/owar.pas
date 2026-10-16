{
    Copyright (c) 1998-2002 by Peter Vreman

    Contains the stuff for writing .a files directly

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
unit owar;

{$i fpcdefs.inc}

interface

uses
  GlobType,
  CClasses,
  owbase;

type
  TArHdr=packed record
    name : array[0..15] of char;
    date : array[0..11] of char;
    uid  : array[0..5] of char;
    gid  : array[0..5] of char;
    mode : array[0..7] of char;
    size : array[0..9] of char;
    fmag : array[0..1] of char;
  end;

  TArObjectWriter=class(TObjectWriter)
    constructor createAr(const Aarfn:string);override;
    destructor  Destroy;override;
    function  CreateFile(const fn:string):boolean;override;
    procedure CloseFile;override;
    procedure writesym(const sym:string);override;
    procedure write(const b;len:LongWord);override;
  private
    arfn        : string;
    arhdr       : TArHdr;
    symreloc,
    symstr,
    lfnstr,
    ardata      : TDynamicArray;
    objpos      : LongInt;
    objfn       : string;
    timestamp   : string[12];
    procedure createarhdr(fn:string;asize:LongInt;const gid,uid,mode:string);
    procedure writear;
  end;

  TArObjectReader=class(TObjectReader)
  private
    ArSymbols : TFPHashObjectList;
    LFNStrs   : TAnsiCharDynArray;
    LFNSize   : LongInt;
    CurrMemberPos,
    CurrMemberSize : LongInt;
    CurrMemberName : string;
    isar: boolean;
    function  DecodeMemberName(ahdr:TArHdr):ShortString;
    function  DecodeMemberSize(ahdr:TArHdr):LongInt;
    procedure ReadArchive;
  protected
    function getfilename:string;override;
    function GetSize: LongInt;override;
    function GetPos: LongInt;override;
    function GetIsArchive: boolean; override;
  public
    constructor createAr(const Aarfn:string;allow_nonar:boolean=false);override;
    destructor  Destroy;override;
    function  openfile(const fn:string):boolean;override;
    procedure CloseFile;override;
    procedure seek(len:LongInt);override;
  end;


implementation

    uses
      SysUtils,
      CStreams,
      Systems,
      Globals,
      Verbose;

    const
      symrelocbufsize = 4096;
      symstrbufsize = 8192;
      lfnstrbufsize = 4096;
      arbufsize  = 65536;

      armagic:array[1..8] of char='!<arch>'#10;

    type
      TArSymbol = class(TFPHashObject)
        MemberPos : LongInt;
      end;


{*****************************************************************************
                                   Helpers
*****************************************************************************}

      const
        C1970=2440588;
        D0=1461;
        D1=146097;
        D2=1721119;
    Function Gregorian2Julian(DT:TSystemTime):LongInt;
      Var
        Century,XYear,Month : LongInt;
      Begin
        Month:=DT.Month;
        If Month<=2 Then
         Begin
           Dec(DT.Year);
           Inc(Month,12);
         End;
        Dec(Month,3);
        Century:=(LongInt(DT.Year Div 100)*D1) shr 2;
        XYear:=(LongInt(DT.Year Mod 100)*D0) shr 2;
        Gregorian2Julian:=((((Month*153)+2) div 5)+DT.Day)+D2+XYear+Century;
      End;


    function DT2Unix(DT:TSystemTime):LongInt;
      Begin
        DT2Unix:=(Gregorian2Julian(DT)-C1970)*86400+(LongInt(DT.Hour)*3600)+(DT.Minute*60)+DT.Second;
      end;


    function lsb2msb(l:LongInt):LongInt;
      type
        TByteArr=array[0..3] of byte;
      begin
{$ifndef FPC_BIG_ENDIAN}
        TByteArr(result)[0]:=TByteArr(l)[3];
        TByteArr(result)[1]:=TByteArr(l)[2];
        TByteArr(result)[2]:=TByteArr(l)[1];
        TByteArr(result)[3]:=TByteArr(l)[0];
{$else}
        result:=l;
{$endif}
      end;


{*****************************************************************************
                                TArObjectWriter
*****************************************************************************}

    constructor TArObjectWriter.createAr(const Aarfn:string);
      var
        time  : TSystemTime;
      begin
        arfn:=Aarfn;
        ardata:=TDynamicArray.Create(arbufsize);
        symreloc:=TDynamicArray.Create(symrelocbufsize);
        symstr:=TDynamicArray.Create(symstrbufsize);
        lfnstr:=TDynamicArray.Create(lfnstrbufsize);
        { create timestamp }
        GetLocalTime(time);
        Str(DT2Unix(time),timestamp);
      end;


    destructor TArObjectWriter.Destroy;
      begin
        if ErrorCount=0 then
         writear;
        arData.Free;
        arData := nil;
        symreloc.Free;
        symreloc := nil;
        symstr.Free;
        symstr := nil;
        lfnstr.Free;
        lfnstr := nil;
      end;


    procedure TArObjectWriter.createarhdr(fn:string;asize:LongInt;const gid,uid,mode:string);
      var
        tmp : string[9];
        hfn : string;
      begin
        { create ar header }
        fillchar(arhdr,sizeof(TArHdr),' ');
        { win32 will change names starting with .\ to ./ when using lfn, corrupting
          the sort order required for the idata sections. To prevent this strip
          always the path from the filename. (PFV) }
        hfn:=ExtractFileName(fn);
        if hfn='' then
          hfn:=fn;
        fn:=hfn+'/';
        if length(fn)>16 then
         begin
           arhdr.name[0]:='/';
           str(lfnstr.Size,tmp);
           move(tmp[1],arhdr.name[1],length(tmp));
           fn:=fn+#10;
           lfnstr.write(fn[1],length(fn));
         end
        else
         move(fn[1],arhdr.name,length(fn));
        { don't write a date if also no gid/uid/mode is specified }
        if gid<>'' then
          move(timestamp[1],arhdr.date,length(timestamp));
        str(asize,tmp);
        move(tmp[1],arhdr.Size,length(tmp));
        move(gid[1],arhdr.gid,length(gid));
        move(uid[1],arhdr.uid,length(uid));
        move(mode[1],arhdr.mode,length(mode));
        arhdr.fmag:='`'#10;
      end;


    function TArObjectWriter.CreateFile(const fn:string):boolean;
      begin
        objfn:=fn;
        objpos:=ardata.Size;
        ardata.seek(objpos + sizeof(TArHdr));
        CreateFile:=true;
        fobjsize:=0;
      end;


    procedure TArObjectWriter.CloseFile;
      const
        LF:char=#10;
      var
        filesize:LongInt;
      begin
        { preserve file size, before aligning on an even boundary }
        filesize:=ardata.Size-objpos-sizeof(TArHdr);
        { align on an even boundary, by inserting an LF if necessary }
        if odd(ardata.Size) then
          write(LF,1);
        { fix the size in the header }
        createarhdr(objfn,filesize,'42','42','644');
        { write the header }
        ardata.seek(objpos);
        ardata.write(arhdr,sizeof(TArHdr));
        fobjsize:=0;
      end;


    procedure TArObjectWriter.writesym(const sym:string);
      var
        c : char;
      begin
        c:=#0;
        symreloc.write(objpos,4);
        symstr.write(sym[1],length(sym));
        symstr.write(c,1);
      end;


    procedure TArObjectWriter.write(const b;len:LongWord);
      begin
        inc(fobjsize,len);
        inc(fsize,len);
        ardata.write(b,len);
      end;


    procedure TArObjectWriter.writear;
      var
        arf      : TCCustomFileStream;
        fixup,l,
        relocs,i : LongInt;
      begin
        arf:=CFileStreamClass.Create(arfn,fmCreate);
        if CStreamError<>0 then
          begin
             Message1(exec_e_cant_create_archivefile,arfn);
             exit;
          end;
        arf.Write(armagic,sizeof(armagic));
        { align first, because we need the size for the fixups of the symbol reloc }
        if lfnstr.Size>0 then
         lfnstr.align(2);
        if symreloc.Size>0 then
         begin
           symstr.align(2);
           fixup:=12+sizeof(TArHdr)+symreloc.Size+symstr.Size;
           if lfnstr.Size>0 then
            inc(fixup,lfnstr.Size+sizeof(TArHdr));
           relocs:=symreloc.Size div 4;
           { fixup relocs }
           for i:=0to relocs-1 do
            begin
              symreloc.seek(i*4);
              symreloc.read(l,4);
              symreloc.seek(i*4);
              l:=lsb2msb(l+fixup);
              symreloc.write(l,4);
            end;
           createarhdr('',4+symreloc.Size+symstr.Size,'0','0','0');
           arf.Write(arhdr,sizeof(TArHdr));
           relocs:=lsb2msb(relocs);
           arf.Write(relocs,4);
           symreloc.WriteStream(arf);
           symstr.WriteStream(arf);
         end;
        if lfnstr.Size>0 then
         begin
           createarhdr('/',lfnstr.Size,'','','');
           arf.Write(arhdr,sizeof(TArHdr));
           lfnstr.WriteStream(arf);
         end;
        ardata.WriteStream(arf);
        Arf.Free;
        Arf := nil;
      end;


{*****************************************************************************
                                TArObjectReader
*****************************************************************************}


    constructor TArObjectReader.createAr(const Aarfn:string;allow_nonar:boolean);
      var
        magic:array[0..sizeof(armagic)-1] of char;
      begin
        inherited Create;
        ArSymbols:=TFPHashObjectList.Create(true);
        CurrMemberPos:=0;
        CurrMemberSize:=0;
        CurrMemberName:='';
        if inherited openfile(Aarfn) then
          begin
            Read(magic,sizeof(armagic));
            isar:=(CompareByte(magic,armagic,sizeof(armagic))=0);
            if isar then
              ReadArchive
            else if (not allow_nonar) then
              Comment(VError,'Not a ar file, illegal magic: '+FileName);
            Seek(0);
          end;
      end;


    destructor  TArObjectReader.Destroy;
      begin
        inherited CloseFile;
        ArSymbols.Free;
        ArSymbols := nil;
        LFNStrs:=nil;
        inherited Destroy;
      end;


    function TArObjectReader.getfilename : string;
      begin
        result:=inherited getfilename;
        if CurrMemberName<>'' then
          result:=result+'('+CurrMemberName+')';
      end;


    function TArObjectReader.GetSize: LongInt;
      begin
        result:=CurrMemberSize;
      end;


    function TArObjectReader.GetPos: LongInt;
      begin
        result:=inherited GetPos-CurrMemberPos;
      end;


    function TArObjectReader.GetIsArchive: boolean;
      begin
        Result:=isar;
      end;


    function TArObjectReader.DecodeMemberName(ahdr:TArHdr):ShortString;
      var
        hs : ShortString;
        code : integer;
        hsp,
        p : pchar;
        lfnidx : LongInt;
      begin
        result:='';
        p:=@ahdr.name[0];
        hsp:=@hs[1];
        while (p^<>' ') and (hsp-@hs[1]<16) do
          begin
            hsp^:=p^;
            inc(p);
            inc(hsp);
          end;
        hs[0]:=chr(hsp-@hs[1]);
        if (hs[1]='/') and (hs[2] in ['0'..'9']) then
          begin
            Delete(hs,1,1);
            val(hs,lfnidx,code);
            if (lfnidx<0) or (lfnidx>=LFNSize) then
              begin
                Comment(VError,'Invalid ar member lfn name index in '+FileName);
                exit;
              end;
            p:=@LFNStrs[lfnidx];
            hsp:=@result[1];
            while p^<>#10 do
              begin
                hsp^:=p^;
                inc(p);
                inc(hsp);
              end;
            result[0]:=chr(hsp-@result[1]);
          end
        else
          result:=hs;
        { Strip ending / }
        if result[length(result)]='/' then
         dec(result[0]);
      end;


    function TArObjectReader.DecodeMemberSize(ahdr:TArHdr):LongInt;
      var
        hs : ShortString;
        code : integer;
        hsp,
        p : pchar;
      begin
        p:=@ahdr.Size[0];
        hsp:=@hs[1];
        while p^<>' ' do
          begin
            hsp^:=p^;
            inc(p);
            inc(hsp);
          end;
        hs[0]:=chr(hsp-@hs[1]);
        val(hs,result,code);
        if result<=0 then
          Comment(VError,'Invalid ar member size in '+FileName);
      end;


    procedure TArObjectReader.ReadArchive;
      var
        currarhdr   : TArHdr;
        nrelocs,
        relocidx,
        currfilesize,
        relocsize,
        symsize     : LongInt;
        arsym       : TArSymbol;
        s           : string;
        currp,
        endp,
        startp      : integer;
        syms : TAnsiCharDynArray;
        relocs      : Array of LongInt;
      begin
        Read(currarhdr,sizeof(currarhdr));
        { Read number of relocs }
        Read(nrelocs,sizeof(nrelocs));
        nrelocs:=lsb2msb(nrelocs);
        { Calculate sizes }
        currfilesize:=DecodeMemberSize(currarhdr);
        relocsize:=nrelocs*4;
        symsize:=currfilesize-relocsize-4;
        if symsize<0 then
          begin
            Comment(VError,'Illegal symtable in ar file '+FileName);
            exit;
          end;
        { Read relocs }
        SetLength(Relocs,relocsize);
        Read(relocs[0],relocsize);
        { Read symbols, force terminating #0 to prevent overflow }
        SetLength(syms,symsize+1);
        syms[symsize]:=#0;
        Read(syms[0],symsize);
        { Parse symbols }
        relocidx:=0;
        currp:=0;
        endp:=symsize;
        for relocidx:=0 to nrelocs-1 do
          begin
            startp:=currp;
            while (syms[currp]<>#0) do
              inc(currp);
            SetLength(s,currp-startp);
            move(syms[startp],s[1],currp-startp);
            arsym:=TArSymbol.create(ArSymbols,s);
            arsym.MemberPos:=lsb2msb(relocs[relocidx]);
            inc(currp);
            if currp>endp then
              begin
                Comment(VError,'Illegal symtable in ar file '+FileName);
                break;
              end;
          end;
        relocs:=nil;
        syms:=nil;
        { LFN names }
        Read(currarhdr,sizeof(currarhdr));
        if DecodeMemberName(currarhdr)='/' then
          begin
            lfnsize:=DecodeMemberSize(currarhdr);
            SetLength(lfnstrs,lfnsize);
            Read(lfnstrs[0],lfnsize);
          end;
      end;


    function  TArObjectReader.openfile(const fn:string):boolean;
      var
        arsym : TArSymbol;
        arhdr : TArHdr;
      begin
        result:=false;
        arsym:=TArSymbol(ArSymbols.Find(fn));
        if not Assigned(arsym) then
          exit;
        inherited Seek(arsym.MemberPos);
        Read(arhdr,sizeof(arhdr));
        CurrMemberName:=DecodeMemberName(arhdr);
        CurrMemberSize:=DecodeMemberSize(arhdr);
        CurrMemberPos:=arsym.MemberPos+sizeof(arhdr);
        result:=true;
      end;


    procedure TArObjectReader.CloseFile;
      begin
        CurrMemberPos:=0;
        CurrMemberSize:=0;
        CurrMemberName:='';
      end;


    procedure TArObjectReader.seek(len:LongInt);
      begin
        inherited Seek(CurrMemberPos+len);
      end;

end.
