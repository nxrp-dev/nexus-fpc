# Resource regression fixtures

`catalog/` contains small RC scripts, a binary RCDATA payload and generated
one-pixel ICO/CUR inputs. `Run-NXResourceCatalogTests.sh` contains their generation
recipe and exercises string merging and image ID rebasing. These files allow
other host runners to use the same inputs without a retiring converter.

`metadata/versions.tsv` lists eight pairs of read-only executable metadata
fixtures containing versions 1.2.3.4 and 5.6.7.8. They cover old FPC ELF layouts
for i386/x86_64/ARM64, old FPC Mach-O layouts for x86_64/ARM64, and LLVM-linked
PE images for all three Windows CPUs. They are parser inputs, not programs to
execute. `metadata/provenance.json` records the baseline revision, converter
hash, fixture hashes and the retained generation commands. `versions.json`
records the original version-fixture analysis.

The old writer was used only as a migration comparison oracle. The supported
compiler and test pipeline does not invoke it. Run the host checks with stock
FPC 3.2.2 and its RTL, then Nexus and its matching RTL, to check repeated metadata
reads from both these frozen inputs and newly emitted images.
