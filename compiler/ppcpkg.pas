program ppcpkg;

{$mode objfpc}

{ Experimental Win64/Linux x86-64 package compiler. The ordinary pp entry point keeps the
  production target flags unchanged. Use with its matching package SDK only. }
uses
{$ifdef linux}
  { The 3.2.2 bootstrap's fpwidestring needs a native fallback when no Unicode
    collation table is installed (for example during resource file lookup). }
  cwstring,
{$endif}
  compiler, systems;

begin
  Include(targetinfos[Ord(system_x86_64_win64)]^.flags,tf_supports_packages);
  Include(targetinfos[Ord(system_x86_64_linux)]^.flags,tf_supports_packages);
  Halt(compiler.Compile(''));
end.
