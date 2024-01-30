		Rebuilding the Elf 2000 EPROM Image
		-----------------------------------

PREREQUISITES

  A little background - the Spare Time Gizmos Elf 2000 EPROM is actually
made by combining a number of different and mostly independent pieces of
software into a single memory image.  Some of the major components are

	boots	- Elf 2000 monitor, diagnostics, debugger and bootstrap
	video	- VT52 emulator for the VT1802 video card
	sedit	- Disk sector editor
	edtasm  - Interactive editor and assembler
	forth   - Forth interpreter
	basic	- BASIC interpreter
	bios	- BIOS for everything, including ElfOS

  The source for boots, video and some of the tools used to generate the EPROM
image (e.g. rommerge, romcksum, etc) are copyright (C) 2004-2024 by Spare Time
Gizmos.  In general, but not in every cases, these files are distributed under
the terms of the GNU General Public License, a copy of which is included with
this distribution in the file LICENSE.TXT.  Refer to the individual program
or source file for specific licensing terms.

  Most of the other EPROM components, including sedit, edtasm, forth, basic
and the bios, are copyright (C) 2004-2006 by Michael H Riley. Mike has kindly
granted permission to use these components in both the Elf 2000 and the 
Embedded Elf.  This permission does not extend to third parties, and if you
want to use Mike's code, either separately or as part of the Elf 2000 EPROM,
in your own commercial application you will need to obtain his permission.

  Mike's software and contact information may be obtained from his github
archive, https://github.com/rileym65.  The source for Mike's software,
including his Rc/asm and Asm/02 assemblers, are not included here and you will
need to obtain those components from his archive before you can rebuild the
Elf 2000 EPROM.

  In addition, the Spare Time Gizmos code is assembled with TASM (the Telemark
Assembler) which is also not included in this distribution.  The official
distribution for TASM can be found at http://home.comcast.net/~tasm/.  Note
that TASM isn't freeware, and if you use it you should pay Tom Anderson his
registration fee - it's only a few dollars and TASM is certainly worth it.

  One problem is that the official TASM release doesn't support the 1802!
I didn't know this when I started this project, but it turns out that other
people have added 1802 support to TASM and then restributed it.  The best
1802 table, and the one I use, is from Steve Brune, http://sbrune.com/COSMAC/.
As far as I can find, Steve doesn't give any copyright information or mention
any licensing terms for the file TASM1802.TAB, which is really the only part
he wrote.  The rest of TASM is from Tom Anderson's distribution.

  BTW, the version of TASM (3.1) on Steve's site is out of date, but you can
simply copy the TASM1802.TAB file and use it with the latest TASM release.

  Lastly, if you want to use the Makefile included with this distribution,
you'll need a copy of Make.  I use GNU Make, which is available from the
GNU web site http://www.gnu.org/software/make/make.html.


BUILDING THE IMAGE

  TASM requires the environment variable TASMTABS to be defined to point
at its table file, and linewise rcasm needs RCASM_DIR for the same purpose.
The file SETUP.BAT in this distribution contains sample definitions for
these paths; one way or another you'll need to add these values to your
environment.

  In addition, you'll probably need to edit the Makefile and change the
tool paths at the very top of the file to suit your system.  Note that
one component, rc/Basic, requires a C pre-processor to build from sources.
The Makefile supplied is set up to use the MSVC 1.51 (the last DOS version
of MSVC) compiler for cpp - if you have something else, you'll need to
change this as well.

  You'll need to obtain the source files for SEDIT, Forth, EDT/ASM, rc/Basic
and the BIOS from Mike Riley's web site.  Mike supplies a Makefile, a bios
include file, and other tools for each of his components, but in this case you
don't need or want any of them.  Just extract the assembly source for each of
these components from Mike's distribution and put the .asm file in the Elf
2000 EPROM directory.

  When you've got everything together, you should just be able to type
"make" and stand back - if all is well you will be left with a file,
EPROM.HEX, that's ready for burning into a 27C256.

  The Makefile has a few other targets too, such as "make clean".  Read the
comments at the top of the Makefile for more information.


CHANGING THE CONFIGURATION

  In principle you can change the configuration of the Elf 2000 EPROM - e.g.
remove BASIC, add something else, move things around in memory - by editing
the file Config.  In practice this doesn't always work as well as you might
hope, particularly because the 1802 short branch instructions are sensitive
to the location of code in memory, and shifting things around tends to cause
"off page" errors.  You're welcome to experiment, but any configuration other
than the official one supplied by Spare Time Gizmos is unsupported.
