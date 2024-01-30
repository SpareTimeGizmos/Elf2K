#++
# Makefile - Makefile for the Spare Time Gizmos' Elf 2000 EPROM
#
# Copyright (C) 2020 by Spare Time Gizmos.  All rights reserved.
#
# This firmware is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 2 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place, Suite 330, Boston, MA  02111-1307  USA
#
#DESCRIPTION:
#   This Makefile will build the Spare Time Gizmos Elf EPROM image for the
# Spare Time Gizmos Elf 2000.  The result is a file called Elf2K.hex, which is
# ready to burn into a 27C256 EPROM...
#
#TARGETS:
#  make all	- rebuild PicoElf.hex
#  make clean	- clean up all generated files _except_ PicoElf.hex
#  make distro	- make the PicoElf.zip source file distribution
#
# REVISION HISTORY:
# dd-mmm-yy	who     description
# 22-Feb-06	RLA	New file.
# 12-Jun-08	RLA	Update for the latest GNU make.
#  2-Dec-20	RLA	Add support for Visual/02 and XMODEM.
# 16-Dec-20     RLA     Change output to PicoElf.hex and clean things up
# 19-Dec-20     RLA     Create Elf2K version from PicoElf
#  3-Jan-21	RLA	Make the help file platform dependent
#--

#   Set PLATFORM to either "Elf2K" or "PicoElf" for the desired target...
# Set ALTERNATE to "-alternate" to make the alternate Elf2K EPROM, otherwise
# set it to a null string for the standard Elf2K or PicoElf EPROMs.
PLATFORM=PicoElf
ALTERNATE=
-include config.$(PLATFORM)$(ALTERNATE)

#   This "subroutine" (don't know what else to call it!) converts its argument
# to upper case.  You'd think there would be a built in function for this, but
# no, at least not in GNU Make.  It's a bit brute force, but it works!
UC = $(subst a,A,$(subst b,B,$(subst c,C,$(subst d,D,$(subst e,E,$(subst f,F,$(subst g,G,$(subst h,H,$(subst i,I,$(subst j,J,$(subst k,K,$(subst l,L,$(subst m,M,$(subst n,N,$(subst o,O,$(subst p,P,$(subst q,Q,$(subst r,R,$(subst s,S,$(subst t,T,$(subst u,U,$(subst v,V,$(subst w,W,$(subst x,X,$(subst y,Y,$(subst z,Z,$1))))))))))))))))))))))))))

# Tool paths and options - you can change these as necessary...
TASM=/usr/local/bin/tasm/tasm
export TASMTABS=/usr/local/bin/tasm/
TASMOPTS=-t1802 -la -g0 -i -DTASM -D$(call UC,$(PLATFORM)) -DSTGROM
ASM02=/usr/local/bin/tools/asm02
ASMOPTS=-i -L -s -D$(call UC,$(PLATFORM)) -DSTGROM
RCASM=/usr/local/bin/rcasm/rcasm
export RCASM_DIR=/usr/local/bin/rcasm/
RCASMOPTS=-v -h -l -x -d1802 -D$(call UC,$(PLATFORM)) -DSTGROM
ROMMERGE=/usr/local/bin/tools/rommerge
ROMCKSUM=/usr/local/bin/tools/romcksum
ROMTEXT=/usr/local/bin/tools/romtext
CPP=/usr/bin/cpp -E 
ZIP="C:/Program Files/7-Zip/7z.exe"
ECHO=/usr/bin/echo
RM=/usr/bin/rm

#   Now make a list of all the .HEX files that will be required to build the
# EPROM image.  Some are obvious, like boots.hex or bios.hex, but others
# depend on the configuration options selected...
HEXFILES = $(strip							\
	     boots.hex bios.hex $(if $(VIDEO), video.hex)		\
	     $(if $(SEDIT), sedit.hex) $(if $(FORTH), forth.hex)	\
	     $(if $(EDTASM), edtasm.hex) $(if $(BASIC), rcbasic.hex)	\
	     $(if $(VISUAL), visual02.hex) $(if $(XMODEM), xmodem.hex)	\
	     $(if $(HELP), help.hex)					\
	   )
LISTFILES = $(HEXFILES:.hex=.lst)

# The default target builds everything...
all:	$(PLATFORM)$(ALTERNATE).hex


boots.hex:	boots.asm config.inc hardware.inc boots.inc bios.inc
	@$(ECHO) -e "\nBuilding Elf 2000 Monitor ..."
	$(TASM) $(TASMOPTS) $< $@

video.hex:	video.asm config.inc hardware.inc boots.inc
	@$(ECHO) -e "\nBuilding VT1802 support firmware ..."
	$(TASM) $(TASMOPTS) $< $@

bios.hex:	bios.asm config.inc bios.inc
	@$(ECHO) -e "\nBuilding BIOS ..."
	$(RCASM) $(RCASMOPTS) $< >$(@:.hex=.lst)

xmodem.hex:	xmodem.asm config.inc bios.inc
	@$(ECHO) -e "\nBuilding XMODEM ..."
	$(RCASM) $(RCASMOPTS) $< >$(@:.hex=.lst)

rcbasic.hex:	rcbasic.asm config.inc bios.inc
	@$(ECHO) -e "\nBuilding rc/BASIC ..."
#	$(ASM02) $(ASMOPTS) -DLEVEL=2 $< >$(@:.hex=.lst)
	$(RM) -f temp.asm $@
	$(CPP) -DSTGROM -DLEVEL=2 -Id:\\elf\\sw\\rcbasic\\ $< >temp.asm
	$(RCASM) $(RCASMOPTS) temp.asm >$(@:.hex=.lst)
	mv temp.hex $@

visual02.hex:	visual02.asm config.inc bios.inc
	@$(ECHO) -e "\nBuilding VISUAL/02 ..."
	$(ASM02) $(ASMOPTS) $< >$(@:.hex=.lst)

edtasm.hex:	edtasm.asm config.inc bios.inc
	@$(ECHO) -e "\nBuilding Editor/Assembler ..."
	$(RCASM) $(RCASMOPTS) $< >$(@:.hex=.lst)

forth.hex:	forth.asm config.inc bios.inc
	@$(ECHO) -e "\nBuilding rc/Forth ..."
	$(RCASM) $(RCASMOPTS) -DNO_BLOAD $< >$(@:.hex=.lst)

sedit.hex:	sedit.asm config.inc bios.inc
	@$(ECHO) -e "\nBuilding Disk Sector Editor ..."
	$(RCASM) $(RCASMOPTS) $< >$(@:.hex=.lst)

help.hex:	help.$(PLATFORM)$(ALTERNATE) config.inc
	@$(ECHO) -e "\nCompiling help text ..."
	$(ROMTEXT) -a0x$(strip $(HELP:H=)) $< $@

merged.hex:	$(HEXFILES)
	@$(ECHO) -e "\nMerging files into EPROM image ..."
	$(ROMMERGE) -s32k -o32768 merged.hex $(HEXFILES)

$(PLATFORM)$(ALTERNATE).hex:	merged.hex
	@$(ECHO) -e "\nCalculating EPROM checksum ..."
	$(ROMCKSUM) merged.hex -s32K -o32768 -c32764 $(PLATFORM)$(ALTERNATE).hex

# The "clean" target does what you'd expect...
clean:
	$(RM) -f $(HEXFILES)
	$(RM) -f $(LISTFILES)
	$(RM) -f video.hex merged.hex config.inc temp.asm
	$(RM) -f *.*\~ \#*.*\#

#   The file config.inc is included by all the source files (including Mike's)
# and defines the EPROM addresses of the various components.  This target will
# actually create a new config.inc file from the definitions in config.
config.inc:	config.$(PLATFORM)$(ALTERNATE)
	@echo Creating config.inc from config.$(PLATFORM)$(ALTERNATE) ...
	@$(RM) -f config.inc
	@echo "; DO NOT EDIT THIS FILE - EDIT CONFIG. INSTEAD!!" >>config.inc
	@echo "#define BOOTS	 $(strip $(BOOTS))"   >>config.inc
	@echo "#define WARMB	 $(strip $(WARMB))"   >>config.inc
	$(if $(HELP),  @echo "#define HELP	 $(strip $(HELP))"   >>config.inc)
	@echo "#define RAMPAGE	 $(strip $(RAMPAGE))" >>config.inc
	@echo "#define BIOS	 $(strip $(BIOS))"    >>config.inc
	$(if $(EBIOS),  @echo "#define EBIOS	 $(strip $(EBIOS))"   >>config.inc)
ifneq ($(VIDEO),)
	@echo "#define VIDEO	 $(strip $(VIDEO))"   >>config.inc
	@echo "#define INIT75	 $(strip $(INIT75))"  >>config.inc
	@echo "#define VTPUTC	 $(strip $(VTPUTC))"  >>config.inc
	@echo "#define SCREEN	 $(strip $(SCREEN))"  >>config.inc
endif
	$(if $(PIXIE),  @echo "#define PIXIE	                  "   >>config.inc)
	$(if $(SEDIT),  @echo "#define SEDIT	 $(strip $(SEDIT))"   >>config.inc)
	$(if $(FORTH),  @echo "#define FORTH	 $(strip $(FORTH))"   >>config.inc)
	$(if $(EDTASM), @echo "#define EDTASM	 $(strip $(EDTASM))"  >>config.inc)
	$(if $(BASIC),  @echo "#define BASIC	 $(strip $(BASIC))"   >>config.inc)
	$(if $(VISUAL), @echo "#define VISUAL	 $(strip $(VISUAL))"  >>config.inc)
	$(if $(XMODEM), @echo "#define XMODEM	 $(strip $(XMODEM))"  >>config.inc)

#   The "distro" target builds a Elf2K.zip file which contains all the tools,
# source files, readme files, license files, etc that are usually included in
# the source distribution.  (A binary distribution, of course, only contains
# the Elf2K.hex file!)  Note that a source distribution only contains Spare
# Time Gizmos' files - source files for other things, notably Mike Riley's
# software, rcasm and TASM, and the tools used to build the EPROM image, are
# not included!
distro:
	@echo Building source distribution ...
	$(RM) -f STGROM.zip
	$(ZIP) a STGROM.zip \
	  boots.asm video.asm boots.inc hardware.inc \
	  help.PicoElf help.Elf2K config.PicoElf config.Elf2K	\
	  Makefile. readme.txt license.txt Elf2K.hex PicoElf.hex \
	  $(ROMMERGE) $(ROMCKSUM) $(ROMTEXT)
