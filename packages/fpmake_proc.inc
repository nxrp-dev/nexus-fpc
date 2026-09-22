procedure add_cocoaint(const ADirectory: string);
begin
  with Installer do
{$include cocoaint/fpmake.pp}
end;

procedure add_fcl_async(const ADirectory: string);
begin
  with Installer do
{$include fcl-async/fpmake.pp}
end;

procedure add_fcl_base(const ADirectory: string);
begin
  with Installer do
{$include fcl-base/fpmake.pp}
end;

{$include fcl-db/fpmake.pp}

procedure add_fcl_fpcunit(const ADirectory: string);
begin
  with Installer do
{$include fcl-fpcunit/fpmake.pp}
end;

procedure add_fcl_hash(const ADirectory: string);
begin
  with Installer do
{$include fcl-hash/fpmake.pp}
end;

procedure add_fcl_image(const ADirectory: string);
begin
  with Installer do
{$include fcl-image/fpmake.pp}
end;

procedure add_fcl_json(const ADirectory: string);
begin
  with Installer do
{$include fcl-json/fpmake.pp}
end;

procedure add_fcl_net(const ADirectory: string);
begin
  with Installer do
{$include fcl-net/fpmake.pp}
end;

procedure add_fcl_process(const ADirectory: string);
begin
  with Installer do
{$include fcl-process/fpmake.pp}
end;

procedure add_fcl_registry(const ADirectory: string);
begin
  with Installer do
{$include fcl-registry/fpmake.pp}
end;

procedure add_fcl_res(const ADirectory: string);
begin
  with Installer do
{$include fcl-res/fpmake.pp}
end;

procedure add_fcl_xml(const ADirectory: string);
begin
  with Installer do
{$include fcl-xml/fpmake.pp}
end;

procedure add_fpmkunit(const ADirectory: string);
begin
  with Installer do
{$include fpmkunit/fpmake.pp}
end;

procedure add_hash(const ADirectory: string);
begin
  with Installer do
{$include hash/fpmake.pp}
end;

procedure add_iconvenc(const ADirectory: string);
begin
  with Installer do
{$include iconvenc/fpmake.pp}
end;

procedure add_iosxlocale(const ADirectory: string);
begin
  with Installer do
{$include iosxlocale/fpmake.pp}
end;

procedure add_jni(const ADirectory: string);
begin
  with Installer do
{$include jni/fpmake.pp}
end;

procedure add_libffi(const ADirectory: string);
begin
  with Installer do
{$include libffi/fpmake.pp}
end;

procedure add_libtar(const ADirectory: string);
begin
  with Installer do
{$include libtar/fpmake.pp}
end;

procedure add_openssl(const ADirectory: string);
begin
  with Installer do
{$include openssl/fpmake.pp}
end;

procedure add_pasjpeg(const ADirectory: string);
begin
  with Installer do
{$include pasjpeg/fpmake.pp}
end;

procedure add_paszlib(const ADirectory: string);
begin
  with Installer do
{$include paszlib/fpmake.pp}
end;

procedure add_pthreads(const ADirectory: string);
begin
  with Installer do
{$include pthreads/fpmake.pp}
end;

{$include rtl-extra/fpmake.pp}

{$include rtl-generics/fpmake.pp}

{$include rtl-objpas/fpmake.pp}

procedure add_sqlite(const ADirectory: string);
begin
  with Installer do
{$include sqlite/fpmake.pp}
end;

procedure add_tplylib(const ADirectory: string);
begin
  with Installer do
{$include tplylib/fpmake.pp}
end;

procedure add_univint(const ADirectory: string);
begin
  with Installer do
{$include univint/fpmake.pp}
end;

procedure add_winunits_base(const ADirectory: string);
begin
  with Installer do
{$include winunits-base/fpmake.pp}
end;

procedure add_x11(const ADirectory: string);
begin
  with Installer do
{$include x11/fpmake.pp}
end;

