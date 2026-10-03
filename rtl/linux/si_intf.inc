{$SMARTLINK OFF}

{$ifndef FPC_HAS_INDIRECT_ENTRY_INFORMATION}
var
  initialstkptr: pointer; public name '__stkptr';
  operatingsystem_parameter_envp: PPAnsiChar; public name 'operatingsystem_parameter_envp';
  operatingsystem_parameter_argc: longint; public name 'operatingsystem_parameter_argc';
  operatingsystem_parameter_argv: PPAnsiChar; public name 'operatingsystem_parameter_argv';
{$endif FPC_HAS_INDIRECT_ENTRY_INFORMATION}
