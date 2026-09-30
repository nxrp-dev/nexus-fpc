# Clang startup-assembly rules layered over the generated Android Makefile.
# Invoke from rtl/android via Invoke-NexusFPCAndroidCrossBuild.ps1.
include Makefile

prt0$(OEXT): prt0.as
	$(AS) $(ASTARGET) -o $(UNITTARGETDIRPREFIX)prt0$(OEXT) -Wa,-defsym,CPU$(CPUBITS)=1 prt0.as

dllprt0$(OEXT): dllprt0.as
	$(AS) $(ASTARGET) -o $(UNITTARGETDIRPREFIX)dllprt0$(OEXT) -Wa,-defsym,CPU$(CPUBITS)=1 dllprt0.as
