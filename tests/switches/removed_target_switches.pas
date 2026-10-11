program removed_target_switches;

{$targetswitch SMALLTOC}
{$targetswitch COMPACTINTARRAYINIT}
{$targetswitch ENUMFIELDINIT}
{$targetswitch THUMBINTERWORKING}
{$targetswitch INITLOCALS}
{$targetswitch FARPROCSPUSHODDBP}
{$targetswitch NOEXCEPTIONS}
{$targetswitch BFEXCEPTIONS}
{$targetswitch WASMEXCEPTIONS}
{$targetswitch LEGACYEXCEPTIONS}
{$targetswitch WASMTHREADS}
{$targetswitch SATURATINGFLOATTOINT}

{$if defined(FPC_FAR_PROCS_PUSH_ODD_BP) or defined(FPC_WASM_NO_EXCEPTIONS) or
     defined(FPC_WASM_BRANCHFUL_EXCEPTIONS) or defined(FPC_WASM_EXNREF_EXCEPTIONS) or
     defined(FPC_WASM_LEGACY_EXCEPTIONS) or defined(FPC_WASM_THREADS) or
     defined(FPC_WASM_SATURATING_FLOAT_TO_INT)}
  {$fatal Retired target switches must not advertise feature support}
{$endif}

{$targetswitch CLD}
{$ifndef FPC_ENABLED_CLD}
  {$fatal The supported CLD target switch must still define its feature macro}
{$endif}
{$targetswitch CLD-}
{$ifdef FPC_ENABLED_CLD}
  {$fatal Disabling CLD must clear its feature macro}
{$endif}

begin
end.
