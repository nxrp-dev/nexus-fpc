{ %norun }
{ %needlibrary }
{ %target=win64,darwin,linux,freebsd,solaris,android,haiku}

{$mode delphi}

{$ifdef darwin}
{$PIC+}
{$endif darwin}

{$ifdef CPUX86_64}
{$ifndef WINDOWS}
{$PIC+}
{$endif WINDOWS}
{$endif CPUX86_64}

library tw8730a;

uses uw8730a;

exports
_Lib1Func;

end.

//= END OF FILE ===============================================================
