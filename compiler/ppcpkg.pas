program ppcpkg;

{$mode objfpc}

{ Experimental Win64 package compiler. The ordinary pp entry point keeps the
  production target flags unchanged. Use with its matching package SDK only. }
uses compiler, systems;

begin
  Include(targetinfos[Ord(system_x86_64_win64)]^.flags,tf_supports_packages);
  Halt(compiler.Compile(''));
end.
