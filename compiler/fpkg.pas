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
    sysutils,
    cclasses,
    globtype,
    finput;

  type
    tcontainedunit=record
      module:tmodulebase;
      ppufile:tpathstr;
      offset:longint;
      size:longint;
    end;
    pcontainedunit=^tcontainedunit;

    tpackage=class
    public
      realpackagename,
      packagename : pshortstring;
      containedmodules : TFPHashList;
      requiredpackages : TFPHashObjectList;
      requiredidentities : TFPHashList;
      sdkidentity, buildidentity: shortstring;
      pcpfilename,
      ppafilename,
      pplfilename : tpathstr;
      constructor create(const pn:string);
      destructor destroy;override;
    end;

    tpackageentry=record
      package : tpackage;
      realpkgname : string;
      usedunits : longint;
      direct : boolean;
    end;
    ppackageentry=^tpackageentry;

  function current_package_build_identity: shortstring;

implementation

  uses
    cutils,globals;

  { tpackage }

  function current_package_build_identity: shortstring;
    var g: System.TGuid;
    begin
      if package_build_identity='' then
        begin
          if CreateGUID(g)<>0 then
            raise Exception.Create('Cannot create package build identity');
          package_build_identity:=StringReplace(StringReplace(
            Copy(GUIDToString(g),2,36),'-','',[rfReplaceAll]),'}','',[]);
        end;
      result:=package_build_identity;
    end;

  constructor tpackage.create(const pn: string);
    begin
      realpackagename:=stringdup(pn);
      packagename:=stringdup(upper(pn));
      containedmodules:=TFPHashList.Create;
      requiredpackages:=TFPHashObjectList.Create(false);
      requiredidentities:=TFPHashList.Create;
    end;

  destructor tpackage.destroy;
    var
      p : pcontainedunit;
      i : longint;
    begin
      if assigned(containedmodules) then
        for i:=0 to containedmodules.count-1 do
          begin
            p:=pcontainedunit(containedmodules[i]);
            dispose(p);
          end;
      containedmodules.free;
      containedmodules := nil;
      requiredpackages.free;
      requiredpackages := nil;
      for i:=0 to requiredidentities.Count-1 do
        freemem(requiredidentities[i]);
      requiredidentities.Free;
      inherited destroy;
    end;


    procedure packageinit;
      begin
        packagelist:=TFPHashList.Create;
      end;


    procedure packagedone;
      var
        i : longint;
        pkgentry : ppackageentry;
      begin
        if assigned(packagelist) then
          begin
            for i:=0 to packagelist.count-1 do
              begin
                pkgentry:=ppackageentry(packagelist[i]);
                FreeAndNil(pkgentry^.package);
                dispose(pkgentry);
              end;
          end;
        packagelist.Free;
        packagelist:=nil;
      end;


initialization
  register_initdone_proc(@packageinit,@packagedone);
end.

