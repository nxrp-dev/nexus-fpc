This directory contains retained Free Pascal utilities. NXPC builds
release tools through Forge's Bootstrap/Tools projects and installs their
distribution through the Release project. See ../NXPC.Forge.md.

bin2obj : Converts binary data into Pascal include files; used by fpGUI's
          image-generation tooling.
rstconv : Converts resource-string tables to gettext PO or RC STRINGTABLE;
          used by fpGUI's localization tooling.
creumap : Generates Pascal character-mapping units and binary maps from
          Unicode mapping files. Retained for RTL table regeneration;
          it is not a shipped release executable.

The Pascal Lex/Yacc tools, ppdep, postw32, data2inc and its example,
fpcmake/fpgmake generators, and utility make recipes are retired.

The Free Pascal Development Team.
