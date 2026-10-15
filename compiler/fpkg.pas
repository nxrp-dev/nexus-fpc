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
      Module:TModuleBase;
      PPUFile:TPathStr;
      Offset:LongInt;
      Size:LongInt;
    end;
    PContainedUnit=^TContainedUnit;

    TPackage=class
    public
      RealPackageName,
      PackageName : PShortString;
      ContainedModules : TFPHashList;
      RequiredPackages : TFPHashObjectList;
      RequiredIdentities : TFPHashList;
      SDKIdentity, BuildIdentity: ShortString;
      PCPFileName,
      PPAFileName,
      PPLFileName : TPathStr;
      constructor Create(const PN:string);
      destructor Destroy;override;
    end;

    TPackageEntry=record
      Package : TPackage;
      RealPkgName : string;
      UsedUnits : LongInt;
      Direct : Boolean;
    end;
    PPackageEntry=^TPackageEntry;

  function Current_Package_Build_Identity: ShortString;

implementation

  uses
    CUtils,Globals;

  { tpackage }

  function Current_Package_Build_Identity: ShortString;
    var G: System.TGUID;
    begin
      if Package_Build_Identity='' then
        begin
          if CreateGUID(G)<>0 then
            raise Exception.Create('Cannot create package build identity');
          Package_Build_Identity:=StringReplace(StringReplace(
            Copy(GUIDToString(G),2,36),'-','',[rfReplaceAll]),'}','',[]);
        end;
      Result:=Package_Build_Identity;
    end;

  constructor TPackage.Create(const PN: string);
    begin
      RealPackageName:=StringDup(PN);
      PackageName:=StringDup(Upper(PN));
      ContainedModules:=TFPHashList.Create;
      RequiredPackages:=TFPHashObjectList.Create(False);
      RequiredIdentities:=TFPHashList.Create;
    end;

  destructor TPackage.Destroy;
    var
      P : PContainedUnit;
      I : LongInt;
    begin
      if Assigned(ContainedModules) then
        for I:=0 to ContainedModules.Count-1 do
          begin
            P:=PContainedUnit(ContainedModules[I]);
            Dispose(P);
          end;
      ContainedModules.Free;
      ContainedModules := nil;
      RequiredPackages.Free;
      RequiredPackages := nil;
      for I:=0 to RequiredIdentities.Count-1 do
        FreeMem(RequiredIdentities[I]);
      RequiredIdentities.Free;
      inherited Destroy;
    end;


    procedure PackageInit;
      begin
        PackageList:=TFPHashList.Create;
      end;


    procedure PackageDone;
      var
        I : LongInt;
        PkgEntry : PPackageEntry;
      begin
        if Assigned(PackageList) then
          begin
            for I:=0 to PackageList.Count-1 do
              begin
                PkgEntry:=PPackageEntry(PackageList[I]);
                FreeAndNil(PkgEntry^.Package);
                Dispose(PkgEntry);
              end;
          end;
        PackageList.Free;
        PackageList:=nil;
      end;


initialization
  Register_InitDone_Proc(@PackageInit,@PackageDone);
end.

