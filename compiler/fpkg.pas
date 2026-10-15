{
    Copyright (c) 2013-2016 by Free Pascal Development Team

    This unit implements basic parts of the package system

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
unit fpkg;

{$i fpcdefs.inc}

interface

  uses
    SysUtils,
    CClasses,
    GlobType,
    FinPut;

  type
    TContainedUnit=record
      module:TModuleBase;
      ppufile:TPathStr;
      offset:LongInt;
      size:LongInt;
    end;
    PContainedUnit=^TContainedUnit;

    TPackage=class
    public
      realpackagename,
      packagename : PShortString;
      containedmodules : TFPHashList;
      requiredpackages : TFPHashObjectList;
      requiredidentities : TFPHashList;
      sdkidentity, buildidentity: shortstring;
      pcpfilename,
      ppafilename,
      pplfilename : TPathStr;
      constructor create(const pn:string);
      destructor Destroy;override;
    end;

    TPackageEntry=record
      package : TPackage;
      realpkgname : string;
      usedunits : LongInt;
      direct : boolean;
    end;
    PPackageEntry=^TPackageEntry;

  function current_package_build_identity: shortstring;

implementation

  uses
    CUtils,Globals;

  { tpackage }

  function current_package_build_identity: shortstring;
    var g: System.TGUID;
    begin
      if Package_Build_Identity='' then
        begin
          if CreateGUID(g)<>0 then
            raise Exception.Create('Cannot create package build identity');
          Package_Build_Identity:=StringReplace(StringReplace(
            Copy(GUIDToString(g),2,36),'-','',[rfReplaceAll]),'}','',[]);
        end;
      result:=Package_Build_Identity;
    end;

  constructor TPackage.create(const pn: string);
    begin
      realpackagename:=StringDup(pn);
      packagename:=StringDup(upper(pn));
      containedmodules:=TFPHashList.Create;
      requiredpackages:=TFPHashObjectList.Create(false);
      requiredidentities:=TFPHashList.Create;
    end;

  destructor TPackage.Destroy;
    var
      p : PContainedUnit;
      i : LongInt;
    begin
      if Assigned(containedmodules) then
        for i:=0 to containedmodules.count-1 do
          begin
            p:=PContainedUnit(containedmodules[i]);
            dispose(p);
          end;
      containedmodules.free;
      containedmodules := nil;
      requiredpackages.free;
      requiredpackages := nil;
      for i:=0 to requiredidentities.Count-1 do
        FreeMem(requiredidentities[i]);
      requiredidentities.Free;
      inherited Destroy;
    end;


    procedure packageinit;
      begin
        PackageList:=TFPHashList.Create;
      end;


    procedure packagedone;
      var
        i : LongInt;
        pkgentry : PPackageEntry;
      begin
        if Assigned(PackageList) then
          begin
            for i:=0 to PackageList.count-1 do
              begin
                pkgentry:=PPackageEntry(PackageList[i]);
                FreeAndNil(pkgentry^.package);
                dispose(pkgentry);
              end;
          end;
        PackageList.Free;
        PackageList:=nil;
      end;


initialization
  Register_InitDone_Proc(@packageinit,@packagedone);
end.

