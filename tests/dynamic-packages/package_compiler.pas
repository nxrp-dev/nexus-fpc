program package_compiler;
{$mode objfpc}
uses compiler, systems;
begin
  Include(targetinfos[Ord(system_x86_64_win64)]^.flags,tf_supports_packages);
  Halt(compiler.Compile(''));
end.
