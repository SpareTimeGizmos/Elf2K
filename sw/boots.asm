	.TITLE	 "BTS1802 -- Monitor for the COSMAC Elf 2000"
;	 Bob Armstrong [14-Jun-82]

;       Copyright (C) 2004-2020 By Spare Time Gizmos, Milpitas CA.
;	Copyright (C) 1982 By Robert Armstrong, Indianapolis, IN.

;   This program is free software; you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation; either version 2 of the License, or
; (at your option) any later version.
;
;   This program is distributed in the hope that it will be useful, but
; WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
; or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
; for more details.
;
;   You should have received a copy of the GNU General Public License along
; with this program; if not, write to the Free Software Foundation, Inc.,
; 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

;     BBBBBBBB	      OOOOOO	    OOOOOO	TTTTTTTTTT	SSSSSS
;     BBBBBBBBB	     OOOOOOOO	   OOOOOOOO	TTTTTTTTTT     SSSSSSSS
;     BB      BB    OO	    OO	  OO	  OO	    TT	      SS      SS
;     BB      BB    OO	    OO	  OO	  OO	    TT	      SS      SS
;     BB      BB    OO	    OO	  OO	  OO	    TT	      SS
;     BB      BB    OO	    OO	  OO	  OO	    TT	      SS
;     BBBBBBBB	    OO	    OO	  OO	  OO	    TT	       SSSSSSS
;     BBBBBBBB	    OO	    OO	  OO	  OO	    TT		SSSSSSS
;     BB      BB    OO	    OO	  OO	  OO	    TT		      SS
;     BB      BB    OO	    OO	  OO	  OO	    TT		      SS
;     BB      BB    OO	    OO	  OO	  OO	    TT	      SS      SS
;     BB      BB    OO	    OO	  OO	  OO	    TT	      SS      SS
;     BBBBBBBBB	     OOOOOOOO	   OOOOOOOO	    TT	       SSSSSSSS
;     BBBBBBBB	      OOOOOO	    OOOOOO	    TT		SSSSSS
;
;
;   This is a multi-propose piece of software which lives in the EPROM of the
; Spare Time Gizmos COSMAC Elf 2000.  First of all, it's a diagnostic tool -
; it contains a power on self test (POST) that performs a basic test of the
; Elf 2000 components (e.g. an EPROM checksum test, a simple terminal test, 
; etc), and commands for more in-depth tests of individual Elf subsections 
; (e.g. a CDP1861 Pixie test, an extensive RAM diagnostic, etc).
;
;   It contains a simple monitor with a "bit banged" serial terminal interface
; that allows you to examine and change memory bytes, fill RAM with a constant,
; checksum or move blocks of RAM from one address to another, and start running
; a user program.  The monitor also contains a rudimentary breakpoint function
; which allows you to place breakpoints in a user program, stop and examine
; memory or registers, and then continue.  Finally, the monitor allows Intel
; HEX file records to be downloaded directly from a PC - just send the HEX file
; lines over the serial port and the monitor will decode them and deposit the
; data in 1802 memory.
;
;   The EPROM image also contains several small but useful 1802 programming 
; languages from Mike Riley, including Forth, BASIC, and an editor/assembler.
; These languages can be easily bootstrapped with a single command, and
; programs stored in the nonvolatile RAM of the Elf 2000 will not be lost when
; power is turned off.

;0000000001111111111222222222233333333334444444444555555555566666666667777777777
;1234567890123456789012345678901234567890123456789012345678901234567890123456789

	.MSFIRST \ .PAGE \ .CODES

	.NOLIST
	.INCLUDE "config.inc"
	.INCLUDE "hardware.inc"
	.INCLUDE "boots.inc"
	.INCLUDE "bios.inc"
	.LIST
	
	.EJECT
;++
; REVISION HISTORY
;
; 001	-- Convert from SMILE to TASM assembly language.
;
; 002	-- Change memory layout to low RAM/high ROM.  Add entry vectors page.
;
; 003	-- Add a super simple POST with a memory test...
;
; 004	-- Add DIVIDE and TDEC16 to type 16 bit unsigned decimal values...
;
; 005	-- Add Intel Hex file downloads.
;
; 006   -- Make SCRT preserve both D and DF...  Change INCHRW/OUTCHR to pass
;	   ASCII characters in D (to conform to TB calling conventions).  Add
;	   BRKCHK...
;
; 007	-- Add rudimentary breakpoint support.
;
; 008	-- Fix BREAK routine to conform to TB standards.  Add INCHWE function
;	   (input character with wait and echo) for Tiny Basic...
;
; 009	-- Change the breakpoint procedure to make the MARK instruction the
;	   responsibility of the caller (a breakpoint now requrires two
;	   bytes - $79, $D1).  This allows us to save both X and P, and
;	   makes it possible to continue.
;
; 010	-- Make the E(xamine) command print both hex and ASCII...
;
; 011	-- Add basic support for the CDP1861 (in 64x32 resolution mode) and
; 	   add a copy of the famous "Starship Enterprise" picture for testing.
;
; 012	-- Integrate with Mike Riley's ElfOS BIOS....
;
; 013	-- Add BASIC, LISP and Forth commands...
;
; 014	-- Add RUN, CALL and CONTINUE commands...
;
; 015	-- Add exhaustive RAMTEST function.  Rewrite startup code to size
;	   SRAM only rather than testing all of memory.  Now we do a trivial
;	   memory test on the monitor's data page (RAMPAGE) only...
;
; 016	-- Disable interrupts on boot, and then re-enable (and disable)
;	   interrupts as needed for the video test...
;
; 017	-- Make sure that R0 is always cleared by the CONTinue command (it
;	   breaks Tiny BASIC if it isn't!!)...
;
; 020	-- Add "For help type HELP." message and (it seems only fair!) add
;	   the "HELP" command...
;
; 021	-- Mark's latest BIOS no longer requires a DEC P1 after F_HEXIN...
;
; 022	-- If the switches are 0x81 on bootup, then bypass any console
;	   interaction and go directly to the video test...
;
; 023	-- Integrate new BIOS from Mike which fixes the hex number input
;	   problem!
;
; 024	-- Add IN[PUT] and OUT[PUT] commands to test I/O ports...
;
; 025	-- Add SEQ, REQ and EF commands...
;
; 026	-- Add initialization and POST code for the ELFDISK board UART.
;
; 027	-- Add intialization and POST code for the ELFDISK board NVR/RTC..
;
; 028	-- If the NVR is installed, print the current date/time on boot.
;
; 029	-- During initialization, probe for any attached IDE drives and, if
;	   any are found, initialize them...
;
; 030	-- Force RAM initialization (and autobaud!) if the switches are set
;	   to 0x42 ("0100 0010") during startup.
;
; 031	-- Fix up a few error messages that were being corrupted by the
; 	   INLMES() macro bug....
;
; 032	-- Add the DA[TIME] command to set and show the RTC...
;
; 033	-- Use f_input instead of f_inputl so that the user can't overflow
;	   the command buffer...
;
; 034	-- Change some of the BIOS error returns to be more consistent about
;	   using DF.
;
; 035	-- Hack up NVR code to reset the UART (yes, that's right!)
;
; 036	-- Rewrite UART self test so that it actually works...
;
; 037	-- Remove main board UART polarity test (POST 18) and substitute
;	   NVR initialization (when switches are set to 0x43) instead!
;
; 038	-- Invent the SET, SHOW and TEST commands and group various less used
;	   commands (e.g. TEST RAM, SHOW RTC, SET Q, etc) together under them.
;
; 040   -- Purge the code for a lot od dead commands (e.g. P1, P2, DSKRD, NVRRD,
;	   and stuff like that)...
;
; 040	-- Add the SET RESTART [ffff | BOOT | NONE] command.
;
; 041	-- Update the HELP text...
;
; 042	-- Allow the MEMDMP routine (used to generate the output from the E
;	   command) to terminate early if the user presses BREAK on the console.
;
; 043	-- Remove the LISP command, and add the ASM command...
;
; 044	-- Adding the call to TTYINI accidentally broke the TRAP routine.
;	   Move the TTYINI call to a more prudent location!
;
; 045	-- Add more SHOW commands - TERMINAL, VERSION, MEMORY, and RESTART.
;
; 046	-- On a cold start, only clear the monitor's data page to zero,
;	   instead of clearing all of memory...
;
; 047	-- Add a switch combination to force SRAM, NVR or both to be initalized
; 	   on startup.  Startup switch combinations....
;
;		1 0 0 0   0 0 0 1 - Special CHM startup mode
;		0 1 0 0   0 0 1 0 - force SRAM to be initialized
;		0 1 0 0   0 0 1 1 - force SRAM and NVR both to be initialized
;
; 048	-- Eliminate garbage characters after "Booting Primary IDE..." message.
;
; 049	-- Add Mike's SEDIT (Sector EDIT) program to the ROM...
;
; 050	-- Add monitor warm start vector at $8003.  Move Tiny BASIC vectors
;	   down by three...
;
; 051	-- Allow the BOOT command to be abbreviated to just "B"...
;
; 052	-- Add the "SHOW REGISTERS" command...
;
; 053	-- Give a better error message for the "SET Q" command when the Q
;	   output is being used for the console serial port...
;
; 054	-- Fix a spelling error in the help text ("INTEL" not "INTEX"). Rewrite
;	   the help to include all the new monitior commands and to still (I
;	   hope!) look reasonably pretty...
;
; 055	-- Disallow (give an error message for) SET, SHOW and TEST commands
;	   without any argument...
;
; 056	-- Allow a BREAK on the console to interrupt the video and/or RAM test.
;
; 057	-- Fix a spelling error (it's that ***#$$# INLMES bug!) in VIDEO...
;
; 058	-- Remove some unused Tiny BASIC vectors...
;
; 059	-- Ignore any command lines that are terminated by ^C...
;
; 060	-- Fix SETQ, which was broken by edit 053 (don't ever confuse RET with
;	   RETURN!!)
;
; 061	-- Change BATTERY OK message to CONTENTS OK to avoid confusion.
;
; 062	-- Change the TEST VIDEO command to TEST PIXIE (to avoid confusion
;	   with the 80 column video card).  Change some internal labels from
;	   VIDEOxx to PIXIExx for the same reason...
;
; 063	-- Change the POST for SCRT initialization to 40, and then call the
;	   8275 video POST/initialization from the SYSINI code.  Note that
;	   this has to happen AFTER SCRT is initialized!
;
; 064   -- Relocate DSKBUF so that it's below the screen buffer!
;
; 065	-- Add the POST for the GPIO card PS/2 keyboard interface.
;
; 066	-- When the video card is active, disallow RUN and CONTINUE commands.
;
; 067	-- Don't load RLDI(1,TRAP) at MAIN1 if video is in use.
;
; 068	-- If the NVR says to restart at an address and the video is active,
;	   then just ignore it and go to MAIN0.  Also disallow the SET RESTART
;	   xxxx form when video is active.  These are both impossible because
;	   the ASTART1 code uses R0 to restart the user's program.
;
; 069	-- Change the TEST VIDEO command to TEST PIXIE to avoid confusion.
;	   Disallow this command if the real Elf 80 column video card is
;	   in use...
;
; 070	-- The help text for SET DATIME is wrong - the format should be
;	   mm/dd/yyyy, not dd/mm/yyyy...
;
; 071	-- Update the copyright notices for 2006...
;
; 072	-- If the video card and PS2 keyboard is in use, make the SHOW TERMINAL
;	   command report the VT52 emulator and PS2 APU firmware versions.
;
; 073	-- Make the TEST RAM command respect the frame buffer when the video
;	   card is in use.  Display the number of bytes to be tested before
;	   starting.  Display the pass count on the LEDs too.
;
; 074	-- If there's no PS/2 keyboard or VT1802 video installed, then don't
;	   use as the console even if the NVR says to!  Likewise, if there's
;	   no UART installed then don't use it as the console even if the
;	   NVR says to!
;
; 075	-- Add the SHOW CPU command to report the CPU type and speed.
;
; 076	-- Add POST functions for the PPI and SPEAKER options...
;
; 077	-- Add post code $10 for auto IDE boot, and add text error message for
;	   autoboot failure...
;
; 078	-- Turns out that TASM limits any macro argument to a maximum of 16
;	   characters, which is something of a problem for INLMES()...  Go
;	   thru the BOOTS source and fix a few INLMES calls that are broken.
;
; 079	-- Use the master memory configuration file, config.inc, which is
;	   generated by the Makefile.  Also, now we use the same bios
;	   definitions that Mike does, from bios.inc..
;
; 080	-- Move help text into a separate file, HELP.TXT.  This gets "compiled"
;	   by the ROMTEXT program and then merged into the EPROM image...
;
; 081	-- Implement the "SET NVR DEFAULT" command...
;
; 082	-- When the VT1802 is in use, have the "SHOW TERMINAL" command print
;	   the VT1802 firmware identification string directly from the VT1802
;	   code.  A pointer to this string is stored in entry vector 3 of the
;	   VT1802 firmware.
;
; 083	-- Add "more" style pagination to the HELP command when the VT1802
;	   is used.  For all other terminals, we just do the same as before.
;
; 084	-- Add the "TEST VT1802" command to display a test pattern on the
;	   VT1802 screen.
;
; 085	-- Add the CLS command to clear the VT1802 screen.
;
; 086	-- Make the POST for the speaker generate a short tone.
;
; 087	-- Shorten SCANP1 slightly (it contains some stupid code).
;
; 088	-- ISCRTC/NOCRTC breaks the RUN command (and probably others) because
; 	   it trashes P1.  ISCRTC really should use T1 instead.  Thanks go to
;	   Dave Ruske for figuring this one out.
;
;	   Also change "Joeseph Weisberger..." to "Weisbecker" ...
;
; 089	-- Sprinkle some "#ifdef VIDEO" around here and there so that BOOTS can
; 	   actually assemble without the VT1802 video support.
;
; 090	-- Start porting to the Pico/Elf by adding some "#ifdef ELF2K"s ...
;
; 091	-- Put the CDP1861/PIXIE code under "#ifdef PIXIE" ...
;
; 092	-- Add "VIsual" command to invoke Mike's Visual/02 ...
;
; 093   -- Update Mike's copyright notice .
;
; 094	-- Make SHOW RTC give an error if the RTC isn't installed ...
;
; 095	-- SHOW RTC and SHOW CPU need to use NVR_SELECT/NVR_DATA ports ...
;
; 096	-- Add the PicoElf style NVR/RTC/UART reset code ...
;
; 097	-- Change "SHOW RTC" to "SHOW NVR" ...
;	   Also make SHOW NVR show the size and checksum as well ...
;
; 098	-- In PROBE: make sure the model number string is null terminated.
;	   Apparently some manufacturers don't bother!
;
; 099	-- Fix a BIOS bug in the software serial that always set the MSB of
;	   echoed characters ...
;
; 100	-- Change most of the short branch (BR/BZ/BDF/...) to the long form.
;	   This eliminates a lot of "off page" errors caused by the various
;	   assembly options.  There are still a few short branches left.
;
; 101	-- Rearrange the code at SYSINI so the DIS is first, then the POST.
;
; 102	-- When booting IDE, distinguish hardware errors from non-bootable
;	   volumes.  Also remove the "AUTOBOOT FAIL" message from the
;	   startup code - there are already error messages for booting.
;
; 103   -- Extensive rewrites for the restart logic - Use constants ABTNONE,
;	   ABTDISK and ABTADDR for BOOTF.  None of these are zero and none are
;	   0xFF to avoid any uexpected results when clearing NVR!
;
; 104	-- Clean up the TTYINI code a little bit to ensure that BAUD1/0 values
;	   of $FF/$FF (what you get after initializing NVR!) will autobaud.
;
; 105	-- Store the monitor version (MONVER) in NVR.  Check it on startup at
;	   SYSIN3 and force NVR to be initialized if it doesn't match ours.
;
; 106	-- For SET RESTART xxxx, set both X and P to zero before jumping.
;	   Also print "RESTART @xxxx" during boot to make it clear ...
;
; 107	-- The BIOS serial output sense (i.e. SEQ/REQ) is reversed on the Elf2K.
;
; 108   -- Change SET/SHOW DATIME to SET/SHOW DATE.
;          Change SHOW CPU to report CDP1804/5/6
;
; 109	-- [edit deleted - not  good idea!]
; 110	-- [edit deleted - not  good idea!]
;
; 111	-- Fix the conditionals at PIXTEST: so that the PIXIE code still works
; 	   if VIDEO is not defined.  (Thanks, Gaston Williams!).=
;
; 112	-- Reorder some of the code around FOLD: and TCRLF et al to fix some
;	   off page errors caused by edit 111.
;
; 113   -- Reorder the code at SYSINI: so that we don't depend on X=0!
;
; 114	-- Update some of Mike's XMODEM and EDTASM code.
;
; 115	-- Fix yet another XMODEM bug (thanks, David Madole!).
;
; 116	-- Fixes to rc/BASIC and Forth from Al Williams.
;
; 117	-- More Forth improvements from Al Williams.
;
; 118	-- Still more Forth improvements from Al Williams.
;
; 119   -- BIOS and Visual/02 changes for ElfOS v5 from Gaston Williams.
;
; 120	-- F_IDESIZE returns zero in P1 if the drive is bad, not D!
;--
MONVER	.EQU	120

; SUGGESTIONS FOR ENHANCEMENTS
; Add hardware flow control for loading HEX files over UART?
; Make the cold start entry point at $8000 work even if X!=P!=0
; add a hardware bit vector and a SHOW CONFIG command 
;   DEVICES: UART, RTC, IDE, VIDEO, PS2, PPI, PIXIE, SPEAKER
;	bit-banged-serial
; PS/2 keyboard attached test (0xAA, TPS25:) doesn't work!!
;   Requires APU firmware update to support bidirectional communication.
; Maybe we ought to add xon/xoff support?
;  (Talk to mike about adding it to the BIOS)
; Add a "TEST NVR" command
; figure out why Kevin Timmerman's 1861 test program doesn't work
;   it's because our RUN command doesn't enable interrupts.
;   _Should_ our RUN command enable interrupts?????
; Add a BEEP command to beep
; Add TEST SPEAKER to play a simple song?
; Add TEST PS2 to echo any PS/2 keyboard input?
; All VT1802 to be used even w/o GPIO card
;	- Allow interrupts (fix CALL command) and DMA
;	- Allow TEST VT1802
;	- disallow VT1802 with bit banged serial port
; Add multiple commands per line with ";" separator
; Add a REPEAT (RP) command

	.EJECT
;	.SBTTL	RAM Page Storage Map

;   The monitor requires one page of SRAM for internal data, command line
; buffers, and housekeeping.  Normally this would be page zero of memory
; (SRAM addresses $0000..$00FF), but it could also be the last page ($7F00..
; $7FFF) or, for that matter, any page.  In absolute principle it doesn't
; really matter if one of the EPROM languages (Forth,  BASIC, etc)
; scribbles over the monitor's data, but if it does you won't be able to
; use the monitor's breakpoint feature, nor will you be able to get back
; to the monitor without resetting the system.

;   Note that variables marked with a [NVR] tag are also saved to the RTC/NVR
; (aka CMOS) memory if one exists.  Of course, the main board also supports
; a battery backup and, if that is installed, all SRAM is preserved.

;   By convention, whenever the monitor is active the DP register always
; contains RAMPAGE in its upper eight bits.  This allows the DP register
; to be used for direct addressing of any data on this page simply by
; reloading the lower byte rather than the entire register...
	.ORG	RAMPAGE

;   In addition to its internal data page, the monitor occasionally needs 512
; bytes of RAM to use as a disk buffer.  This two page buffer is located just
; below RAMPAGE...
#ifdef VIDEO
DSKBUF	.EQU	SCREEN-512
#else
DSKBUF	.EQU	RAMPAGE-512
#endif

;   Since the CDP1802 stack grows downward, ideally we'd like to pack all
; the static variables into the high part of the data page, and then start
; the stack just below the first variable.  Unfortunately there's no easy
; way to do that, so we just make an educated guess...
	.ORG	$+120
STACK	.EQU	$-1

;   If the bytes in this "key" matches with the EPROM signature then the
; SRAM contents are valid. 
KEY:	.BLOCK	5	; 3 "key" bytes plus the EPROM checksum...

;   The byte at NVRVER contains the "version" of the non-volatile RAM data, if
; present.  This is compared with MONVER to see if the NVR data is current.
NVRVER:	.BLOCK	1	; [NVR] associated monitor version number

;   On a break point, as much of the user state as we can recover is saved
; here.  Note that the order of these bytes is critical - you can't change
; 'em without also changing the code at TRAP:...
SAVEXP:	.BLOCK	1	; saved state of the user's X register
SAVED:	.BLOCK	1	;   "    "    "   "    "    D    "
SAVEDF:	.BLOCK	1	;   "    "    "   "    "    DF   "
REGS:	.BLOCK	16*2	; All user registers after a breakpoint

;   These two locations are used for (gasp!) self modifying code.  The first
; byte gets either an INP or OUT instruction, and the second a "SEP PC".  The
; entire fragment runs with T1 as the program counter and is used so that
; we can compute an I/O instruction to a variable port address...
IOT:	.BLOCK	3

;   These two bytes keep track of the console terminal baud rate and port in
; use.  BAUD1 is a copy of BAUD.1 (RE.1) and contains the baud rate constant
; for the bit banged serial port.  If this value is non-zero then the software
; port is in use.  BAUD0 contains a copy of the hardware UART parameters (as
; passed to F_USETBD) if the hardware UART is used for the serial port.
BAUD1:	.BLOCK	1	; [NVR] backup of the baud rate constant from BAUD.1
BAUD0:	.BLOCK	1	; [NVR]   "    "   "  UART settings from RF.0

;   Other miscellaneous data.  As much as I hate to say it, you should
; be careful before changing the order of any of these locations.  The
; 1802 makes direct memory addressing so painful that that code is often
; tempted to take shortcuts and make assumptions about the order of these
; items!
TIMBUF:	.BLOCK	6	; buffer for the DA[TIME] command
BATTOK:	.BLOCK	1	; 1 if RAM battery backup is OK
VRTC:	.BLOCK	1	; CDP1861 vertical retrace counter
PASSK:	.BLOCK	2	; pass count for MEMTEST and other diagnostics
ERRORK:	.BLOCK	2	; error  "    "     "     "    "        "
UARTOK:	.BLOCK	1	; non-zero if a high speed UART is present

;   The following two bytes contain the version numbers of the PS/2 keyboard
; APU firmware (that's the firmware in our 89C2051 chip on the Elf 2000 GPIO
; board, NOT the firmware of the keyboard itself!) and the version of the
; VT52 emulator firmware for the Elf 2000 video card.  If either one of these
; values is zero, the corresponding option is not present.  DON'T CHANGE THE
; ORDER OF THESE TWO BYTES - the code assumes they're together!
#ifdef ELF2K
PS2VER:	.BLOCK	1	; PS2 keyboard version number
VIDVER:	.BLOCK	1	; VT52 emulator video card version
#endif

;   These three bytes are used for the power fail auto restart/auto bootstrap
; data.  If the boot flag (BOOTF) is zero, then nothing special happens and the
; monitor enters the normal command loop after SYSINI finishes.  If BOOTF is
; 1, then the monitor jumps to RESTA (which should contain the address of the
; restart routine!).  If BOOTF is 0xFF then the monitor attempts to boot from
; the primary IDE drive...
BOOTF:	.BLOCK	1	; [NVR] 0=HALT, 1=RESTART, FF=BOOTSTRAP
RESTA:	.BLOCK	2	; [NVR] restart address when BOOTF==1

; Command line buffer...
CMDMAX	.EQU	64	; maximum command line length
CMDBUF:	.BLOCK	CMDMAX+1; buffer for a line of text read from the terminal

; If we've overflowed the data page, then cause an assembly error...
#if ( ($ & $FF00) != (STACK & $FF00))
	.ECHO	"**** ERROR **** Data page overflow!"
#endif

	.EJECT
;	.SBTTL	Monitor Startup Vectors

;   In the COSMAC Elf 2000, a hardware reset sets the BOOTSTRAP flag (a one
; bit flip flop in the hardware) and this flag, as long as it is set, forces
; EPROM to be selected for all memory accesses regardless of A15.  That's
; how the hardware tricks the processor into starting at location $8000 rather
; than $0000 after a reset.  The BOOTSTRAP flag will stay set until either one
; of two things happens.  Either a) the hardware detects a real memory ref-
; erence with the A15 bit set, or b) when the hardware detects an output to
; any port with N3=1 (i.e. ports 4..7).  The first condition is met by the
; "LBR SYSINI" below, and the second condition is met when SYSINI immedately
; sets the POST code to $99.  It's important to remember that the system
; SRAM is untouchable until this happens!!!
	.ORG	BOOTS
	LBR	SYSINI		; 8000 hardware reset (cold start) vector
	LBR	MAIN		; 8003 warm start vector

;   This dummy vector is used only by Tiny BASIC to fix a bug (er, umm,
; "incompatibility") between TB and Mike's BIOS...
;;BTYPE:SEX	R2		; ensure that the stack is selected
;;	LBR	F_TTY		; and type a character from D

;   The romcksum program computes a sixteen bit checksum for the entire EPROM
; image and stores it in the last two bytes of memory.  The EPROM is computed
; such that the sum of ALL bytes in the EPROM (including the last two!) is
; equal to the sixteen bit value represented by the last two bytes.  This
; rather arcane system is used because it gives the same value for the EPROM
; checksum that the Data I/O and other EPROM programmers report.
;
;   Since the checksum is included in itself, we have to go to some lengths
; to prevent the checksum value from affecting its own calculation.  The way
; that's done is to actually use the last FOUR bytes of the ROM - the last
; two contain the checksum and the two before that contain the complement of
; each byte in the checksum.  The sum of a byte and its complement is always
; 0x0100, and since there are two such bytes, adding a checksum to the ROM in
; this way always adds 0x0200 to the original checksum REGARDLESS of what
; the actual checksum value may be.  The ROMCKSUM program that's used to
; calculate and store the checksum in the .HEX file takes this into account,
; so we can simply ignore the whole issue here.
CHKSUM	.EQU	$FFFE		; high byte first, then low byte

;  And last but not least, the copyright notice or notices always appear in
; plain ASCII near the beginning of the EPROM.  We don't want them to be hard
; to find, after all :-)
SYSTEM:
#ifdef ELF2K
	.TEXT	"\r\nCOSMAC ELF 2000 \000"
#endif
#ifdef PICOELF
	.TEXT	"\r\r\nPICO ELF \000"
#endif
RIGHTS:	.TEXT	"Copyright (C) 2004-2020 by Spare Time Gizmos.  All rights reserved.\r\n"
#ifdef BIOS
	.TEXT	"ElfOS BIOS Copyright (C) 2004-2020 by Mike Riley.\r\n"
#endif
	.TEXT	"\r\n\000"

;   This table gives the "factory default" settings for the non-volatile RAM.
; It's used to re-initialize the NVR any time the switches are set to 0x43
; on startup...
NVRDEFAULT:
	.DB	ABTNONE, $80, 0	; default boot/restart flag
	.DB	0, 0		; default software and hardware UART settings
	.DB	MONVER		; associated monitor version number

	.EJECT
;	.SBTTL	POST Code Summary

;	99 -- basic CPU checks
;	98 -- calculating EPROM checksum
;	97 -- EPROM checksum failure
;	89 -- sizing SRAM
;	88 -- SRAM size wrong (no monitor data page)
;	87 -- testing SRAM key
;	86 -- monitor data page failure
;	85 -- clearing memory
;	84 -- initializing monitor data page
;	79 -- NVR/RTC/UART Reset (PicoElf only!)
;	76 -- NVR/RTC Initialization
;	75 -- RTC clock not ticking
;	74 -- RTC battery fail
;	69 -- UART Reset (Elf2K only!)
;	68 -- UART initialization
;	67 -- UART loopback failure (waiting for THRE set and DR clear)
;	66 -- UART loopback failure (THRE won't clear)
;	65 -- UART loopback failure (waiting for DR set)
;	64 -- UART loopback failure (wrong data)
;	63 -- UART loopback failure (waiting for THRE set and DR clear)
;	59 -- PPI detect
;	58 -- PPI data test
;	57 -- PPI address test
;	54 -- testing for GPIO PS/2 keyboard APU
;	53 -- waiting for PS/2 APU version byte
;	52 -- no PS/2 keyboard attached
;	40 -- initialize SCRT
;	39 -- CRTC status register test
;	38 -- CRTC command/error test
;	37 -- initialize video frame buffer
;	36 -- enable video interrupts
;	35 -- no video DMA
;	34 -- no video end of frame interrupt
;	19 -- initializing BIOS (SCRT)
;	18 -- console terminal failure or polarity wrong
;	17 -- special CHM bootstrap mode
;	16 -- waiting for autobaud
;	15 -- printing system sign on message
;	14 -- intializing master IDE drive
;	13 -- intializing slave IDE drive
;	12 -- printing date/time
;	11 -- autorestart
;	10 -- autoboot
;       0x -- used by ElfOS
;	00 -- startup done
;
; Note that POST tests $5x and $3x are used on the Elf2K only!

	.EJECT
;	.SBTTL	System Initialization (EPROM Test)

;    This routine is entered thru the cold start vector after the processor is
; reset.  It will test EPROM checksum and then, if that's successful, it will
; test and initialize SRAM.  I apologize for the rather "linear" nature of this
; code, but remember - at this point we don't even have a stack we can trust!
; That makes it hard to call subroutines :-)
;
; REMEMBER!  At this point , X=P=0!
SYSINI:	POST($99)		; POST code 99 - the CPU is alive!
	DIS			; disable interrupts ...
	.DB	$00		; ... and set X=P=0

;   There are supposed to be some rudimentary CPU tests here, but I never
; got around to writing any!  We'll just fall into the EPROM checksum test...

;   The first thing we do is to calculate the checksum of the program EPROM.
; The checksum is calculated so that the 16 bit unsigned sum of all the bytes
; in the ROM, INCLUDING the last two bytes, is equal to the last two bytes.
;
;   Note that this code assumes a 32K byte EPROM starting at address $8000.
ROMCHK:	POST($98)		; POST code 98 - EPROM test
	RLDI(P1,BOOTS)		; initialize P1 to the start of EPROM 
	RCLEAR(P2)		; and accumulate the checksum in P2
	SEX	P1		; use P1 to address memory now

; Read a byte and accumulate a 16 bit checksum in P2...
ROMCK1: GLO	P2		; get the low byte of the current total
	ADD			; add another byte from M(R(X))
	PLO	P2		; update the low byte
	GHI	P2		; and propagate any carry bit
	ADCI	$00		; ...
	PHI	P2		; ...
	IRX			; on to the next byte
	GHI	P1		; have we rolled over from $FFFF to $0000?
	LBNZ	ROMCK1		; nope - keep checking

;   If the checksum doesn't match the last two bytes in EPROM, then this POST
; test fails with code $97 displayed...
	SEX	PC0		; back to X=P=0
	POST($97)		; POST code 97 - EPROM checksum failure
	RLDI(P1,CHKSUM)		; the checksum lives here in EPROM
	SEX	P1		; ....
	GHI	P2		; get the high byte first
	SM			; does it equal the byte at $FFFE ?
	BNZ	$		; fail if it doesn't
	IRX			; test the low byte next
	GLO	P2		; ...
	SM			; ...
	BNZ	$		; ...
	SEX	PC0		; the EPROM checksum is OK!

; Fall thru into the RAM test code...
	.EJECT

;	.SBTTL	System Initialization (RAM Size Test)

;   The first stage in RAM testing is simply a matter of sizing RAM.  This
; test starts from location zero and works upward until it finds the first
; non-read/write location (either nonexistent memory or EPROM - it doesn't
; matter which!).
;
;   One important point - this is a NON-DESTRUCTIVE test!  This is a big
; deal because the ELF2K has (potentially at least) non-volatile memory
; and there might be a thousand line BASIC program or something in there!
SIZMEM:	POST($89)		; POST code 89 - sizing memory
	RCLEAR(P1)		; start scanning from location zero
	SEX	P1		; and use P1 to address memory
SIZME1:	LDX			; get a byte
	PLO	P2		; save temporarily
	XRI	$FF		; make the byte different
	STR	P1		; and write it to memory
	GLO	P2		; get the original value
	ADD			; that plus its complement
	ADI	1		; should always total $FF
	LBNZ	SIZME2		; branch if no memory here
	GLO	P2		; once again get the original value
	STR	P1		; and restore memory
	INC	P1		; on to the next byte
	LBR	SIZME1		; and keep looping

; Here when we find a location that can't be written..
SIZME2:	DEC	P1		; back to the last writable location
	SEX	PC0		; back to the regular X
	POST($88)		; and clear post code 89

;   The monitor always uses the last page of SRAM for its data (RAMPAGE) and
; the sad, sad truth is that the monitor can't actually adjust to different
; memory sizes.  If the amount of memory we found isn't exactly what we expect
; (i.e. RAMPAGE+FF), then we just halt with post code 88 displayed...
	GHI	P1		; get the high order byte of memory size
	XRI	HIGH(RAMPAGE)	; is it the monitor's page??
	BNZ	$		; nope - halt with post code 88
	GLO	P1		; and the low byte must be $FF
	XRI	$FF		; ...
	BNZ	$		; ...

; Fall thru into the RAM initialization test...
	.EJECT
;	.SBTTL	System Initialization (RAM Key Test)

;   If the RAM size is correct, then the next step is to see whether the
; current RAM contents are valid.  We do that by comparing the key in the
; SRAM (location KEY:) against the signature built into EPROM.  If they
; match, then we assume the RAM is initialized and we proceed with the current
; RAM contents.
RAMTS1:	SEX	PC0		; just in case
	POST($87)		; POST code 87 - RAM initialization test
	RLDI(SP,STACK-1)	; try to point SP at some RAM somewhere
#ifdef ELF2K
	SEX	SP		; ...
	INP	SWITCHES	; and read the switches
	ANI	$FE		; ignore the LSB for this test
	XRI	$42		; are they set to 0x42 or 0x43 ??
	LBZ	DPTEST		; yes - force ram initialization
#endif
	RLDI(P1,KEY)		; P1 points to the SRAM key
	RLDI(P2,CHKSUM)		; and P2 points to the EPROM checksum
	SEX	P1		; let X point to EPROM

; Compare the SRAM key with the EPROM signature...
	LDXA			; get the first byte of the key
	XRI	'r'		; test it
	LBNZ	DPTEST		; branch if the key doesn't match
	LDXA			; next byte
	XRI	'l'		; ...
	LBNZ	DPTEST		; ...
	LDXA			; and the third
	XRI	'a'		; ...
	LBNZ	DPTEST		; ...
	LDN	P2		; finally, test the last two bytes ...
	XOR			;  ... against the EPROM checksum
	LBNZ	DPTEST		; ...
	IRX\ INC P2		; advance both pointers
	LDN	P2		; and test one more byte
	XOR			; ...
	LBNZ	DPTEST		; ...

; Here if the current RAM contents are valid...
	RLDI(DP,BATTOK)		; set the "battery OK" flag
	LDI	$FF		; ...
	STR	DP		; ...
	LBR	DPDONE		; and then proceed with the initialization

	.EJECT
;	.SBTTL	System Initialization (RAM Initialization)

;   The SRAM is (apparently) uninitialized, so we proceed with a very simple
; memory test on the monitor's data page only (not all of SRAM!), then we
; initialize all of SRAM to zeros, and finally we initialize the monitor's
; data page and key...
;
;   This loop does a very, very simple test on the monitor's data page
; just to ensure that it has 256 bytes of R/W memory.  It doesn't check
; the memory addressing beyond that, and it's not much to speak of.  Once
; the monitor is running, the RAMTEST command can be used for a much more
; exhaustive memory test...
DPTEST:	SEX	PC0		; back to the regular X register
	POST($86)		; monitor data page test
	RLDI(DP,RAMPAGE+$FF)	; point to the monitor's data page
	SEX	DP		; use DP to address memory
DPTES1:	GLO	DP		; get the low byte of the address
	STXD			; store it and decrement DP
	BNZ	DPTES1		; branch if there are still more to do
	RLDI(DP,RAMPAGE)	; yes - start over again
DPTES2:	GLO	DP		; this time compare memory
	SM			; ...
	BNZ	$		; POST code 86 - monitor data page failure
	INC	DP		; on to the next (previous) address
	GLO	DP		; done 'em all
	LBNZ	DPTES2		; no - keep testing

;   The monitor's RAM page tests OK.  Now initialize all memory, from $0000
; to RAMPAGE+$FF, to zero...
	SEX	PC0		; back to the usual X register
	POST($85)		; POST code 85 - clearing memory
	RLDI(P1,RAMPAGE+$FF)	; start at the top of memory again
	SEX	P1		; ...
CLRRAM:	LDI	$00		; set memory to zero
	STXD			; do the next byte
; [RLA] Actually, we just initialize the data page to zeros...
;	GHI	P1		; did we roll over from $0000 to $FFFF?
	GLO	P1		; did we roll over from $7F00 to $7EFF?
	XRI	$FF		; ...
	BNZ	CLRRAM		; nope - keep clearing...

;   And lastly we're ready to store the signature in the monitor's RAM page.
; That's actually the only non-zero data that's presently required in the
; data page, but if the if the monitor had any other data that needed initial-
; izing, this would be the time to do it!
	SEX	PC0		; ...
	POST($84)		; POST code 84 - initializing monitor data page
	RLDI(DP,KEY+4)		; P1 points to the SRAM key
	RLDI(P2,CHKSUM+1)	; and P2 points to the EPROM checksum
	SEX	DP		; use DP to address memory

; Store the rest of the SRAM "key"...
	LDN	P2		; store the two checksum bytes first
	STXD			; ...
	DEC	P2		; (and in "backwards" order!
	LDN	P2		; ...
	STXD			; ...
	LDI	'a'		; now store the rest of the key
	STXD			; (again, "backwards"!)
	LDI	'l'		; ...
	STXD			; ...
	LDI	'r'		; ...
	STXD			; ...

; Fall into RTCINI...
DPDONE:
	.EJECT
;	.SBTTL	Option Board Initialization (RTC)

;   Initialize and test the real time clock on the disk/UART/RTC/NVR option
; board.  In particular, if the clock is present, make sure the lithium
; battery isn't dead and make sure that the clock is running...
RTCINI:

;   The Elf2K Disk/UART/RTC board requires a horrific kludge to reset the UART
; (you can read the whole story at NVRL2:, below) but the PicoElf UART/RTC board
; is much cleaner.  Both the HART and DS12887 chip will be reset when a byte is
; written to the select register with bit 7 cleared and bit 6 set.  The reset
; condition is removed by writing a byte with bit 6 cleared (and bit 7 doesn't
; matter).
;
;   FWIW, resetting the DS12887 clears all pending interrupt requests and all
; interrupt enables.  It doesn't affect the current time nor the RAM contents.
#ifdef PICOELF
	SEX	PC0		; all OUTs are inline
	POST($79)		; ...
	OUT	NVR_SELECT	; write the UART/NVR select register
	.DB	$40		; ... bit 7 cleared and bit 6 set
	NOP\ NOP\ NOP		; stall for a few microseconds
	OUT	NVR_SELECT	; and then remove the reset condition
	.DB	$00		; ...
#endif

; Now proceed with testing the RTC/NVR chip ...
	RLDI(SP,STACK-1)	; for some of this we need a valid RAM pointer
	SEX	PC0		; X=P
	POST($76)		; NVR initialization
	RNVR(NVRFREE)		; read the first free RAM location
	PLO	T1		; save that data for a minute
	SEX	PC0		; ...
	WNVR(NVRFREE,$5A)	; write a test byte
	SEX	PC0		; ...
	RNVR(NVRFREE)		; and read it back
	XRI	$5A		; is it what we expect?
	LBNZ	NONVR		; jump if no NVR present
	SEX	PC0		; ...
	WNVR(NVRFREE,$A5)	; write another test byte
	SEX	PC0		; ...
	RNVR(NVRFREE)		; read it back
	XRI	$A5		; did this work too?
	LBNZ	NONVR		; jump if no NVR present
	SEX	PC0		; restore the original value
	OUT	NVR_SELECT	; ...
	.DB	NVRFREE		; ...
	SEX	SP		; ...
	GLO	T1		; ...
	STR	SP		; ...
	OUT	NVR_DATA		; ...

;   If we really have a NVR/RTC chip, then perform two tests on it.  First,
; be sure that the VRT (battery OK) bit is set and second, be sure that
; the clock is ticking...
	SEX	PC0		; X=P
	WNVR(NVRA,DV1)		; be sure the oscillator is enabled
NVRL1:	SEX	PC0		; X=P again
	POST($75)		; POST code 75 RTC not ticking
	RNVR(NVRA)		; read status register A
	ANI	UIP		; test the update in progress bit
	BZ	NVRL1		; wait for it to set
	SEX	PC0		; X=P
	POST($74)		; NVR battery dead
	RNVR(NVRD)		; read control register D
	XRI	VRT		; the VRT bit should be set, all others zero
	BNZ	$		; loop on failure

#ifdef ELF2K
;   And now it's time for a monumental (and I mean really monumental) hack.
; In the original prototype disk/uart/rtc cards, there was no way to reset
; the UART.  This was a serious oversight, and there were no gates left over,
; no bits left over anywhere, and the _only_ halfway general purpose output
; available to us is the SQW (square wave) output of the DS1287.  Yep, you
; guessed it - the prototype boards were ECO'ed to connect the UART reset
; input the the DS1287 SQW output.  The 8250 data sheet specified a minimum
; pulse width of 1ms for the RESET input, and so our job here is to generate
; a 1us or more pulse on the DS1287 SQW output.
	SEX	PC0		; X=P
	POST($69)		; reset UART
	WNVR(NVRA,DV1+$03)	; turn on periodic interrupt divider chain
	WNVR(NVRB,SQWE+DM+HR24+DSE); turn on the square wave output
NVRL2:	SEX	PC0		; wait for the PF flag to set, and clear again
	RNVR(NVRC)		; read register C
	ANI	PF		; check the PF bit
	BZ	NVRL2		; wait for it to set
NVRL3:	SEX	PC0		; ...
	RNVR(NVRC)		; read register C
	ANI	PF		; check the PF bit
	BNZ	NVRL3		; wait for it to clear
	SEX	PC0		; turn off the square wave output
	WNVR(NVRB,DM+HR24+DSE)	; ...
	WNVR(NVRA,DV1)		; and turn off the divider chain
#endif

; Here if no NVR/RTC chip is installed...
NONVR:
; Fall into UINI...
#ifdef PICOELF
       LBR	UINI		; adjust the alignment for all the
       PAGE			;  ... code that's removed on the PicoElf
#endif
	
	.EJECT
;	.SBTTL	Option Board Initialization (UART)

;   This routine will initialize the UART on the Elf2K disk option board.
; There are several complications here - first, the UART and/or the entire
; disk board may be absent, second, any one of the 8250/16450/16550 UARTs
; or their cousins may be used.  Third, revision 1A of the ELFDISK boards
; had a bug such that a hardware reset did NOT reset the UART chip, so at
; at this point the UART may be in any kind of state at all!
UINI:	RLDI(DP,UARTOK)		; set the UART flag to zero
	LDI	0		;  ...
	STR	DP		; until we know better!
	RLDI(SP,STACK-1)	; for some of this we need a valid RAM pointer
	SEX	PC0		; back to X=P
	POST($68)		; POST code for UART initialization
	WUART(MCR,$10)		; enable loopback, all modem bits OFF
	RUART(MSR)		; read the modem status register
	ANI	$F0		; check the current modem status
	LBNZ	NOUART		; all bits should be zero now
	SEX	PC0		; back to X=P
	WUART(MCR,$1F)		; enable loopback, turn all modem bits ON
	RUART(MSR)		; and read the modem status register again
	ANI	$F0		; check the current modem status
	XRI	$F0		; all bits should be one this time
	LBNZ	NOUART		; no UART if they aren't

; Initialize the UART with some default parameters...
	SEX	PC0		; X=P
	WUART(FCR,$06)		; reset 16550 FIFO and turn it off
	WUART(IER,$00)		; turn off all interrupt sources
	WUART(LCR,DLAB)		; turn on divisor latch access bit
	WUART(DLL,$10)		; set divisor to $0010 for 9600 bps
	WUART(DLH,$00)		; ...
	WUART(LCR,$03)		; select 8N1 character format
	RUART(LSR)		; read the LSR to clear the error bits
	SEX	PC0		; ...
	RUART(RBR)		; next read the data register to clear DR

;   Ok, now let's test the UART for real.  Turn on loopback mode and walk
; thru transmitting and receiving a byte just to make sure everything works
; as we expect!

;   Wait for THRE to set and then transmit a test byte.  Remember that we're
; still in loopback mode, so we'll jsut receive it right back again...
UINI2:	SEX	PC0		; ...
	POST($67)		; UART loopback test (THRE won't set)
	RUART(LSR)		; finally, read the LSR again
	ANI	THRE+DR		; wait for THRE set and DR clear
	XRI	THRE		; ...
	BNZ	UINI2		; wait for it if necessary
	SEX	PC0		; ...
	WUART(THR,$5A)		; transmit a test byte

; And DR should set when the character is received...
UINI4:	SEX	PC0		; ...
	POST($65)		; UART loopback test (waiting for DR set)
	RUART(LSR)		; read the LSR
	ANI	DR		; and look for DR set
	BZ	UINI4		; wait for it

; Read the receiver buffer and make sure we got the right byte...
	SEX	PC0		; ...
	POST($64)		; UART loopback test (wrong data received)
	RUART(RBR)		; finally, read the receiver data buffer
	XRI	$5A		; we'd better read what we wrote!
	BNZ	$		; fail if not

;   Finally check the LSR again - THRE should be set, DR and all the error bits
; should be cleared...
UINI5:	SEX	PC0		; ...
	POST($63)		; UART loopback test (waiting for THRE and DR)
	RUART(LSR)		; back to the LSR register
	ANI	THRE+DR+OE+FE+PE; THRE should be set and DR and error bits clear
	XRI	THRE		; ...
	BNZ	$ ;UNI5		; ...

; Return the UART to normal mode and we're done!
	SEX	PC0		; ...
	POST($60)		; UART tests done
	WUART(MCR,$03)		; turn off loop back; set RTS and DTR
	LDI	$FF		; set the UART present flag to TRUE
	STR	DP		; (DP still points to UARTOK!)

; Here if there's no UART installed...
NOUART:

; Fall into the GPIO PPI/Speaker test ...
	.EJECT
;	.SBTTL	PPI and Speaker Initialization

#ifdef ELF2K
;   The speaker test is pretty simple - it has to be, because there's no way
; we can tell whether the speaker hardware is even installed, let alone
; functioning.  We could take a guess and say that if the PPI and PS/2 key-
; board are installed the speaker probably is, but that's no guarantee because
; the GPIO subsystems are all independent and optional.
;
;   The only thing we can do is to turn the speaker on with its built in tone
; generator for about 1/4 second, and then turn it off.  If it's working, the
; user will hear a "beep" at startup.  Even this is pretty suboptimal, however,
; because the delay is calculated for a 3MHz clock.  At 1.77Mhz it'll be about
; 1.69x longer and at 5Mhz it'll be 1.66x shorter!
	POST($59)		; start of speaker test
	OUT	GPIO		; turn the speaker on
	.DB	SPTONE		;  ... with a fixed tone
	RLDI(P1,$51FF)		; 20991 iterations of this loop
SPTST1:	DEC	P1		; [2] count down
	GHI	P1		; [2] and wait for zero
	BNZ	SPTST1		; [2] ...
	OUT	GPIO		; then turn the speaker off
	.DB	SPOFF		; ...

;   We'd like to do some simple tests on the 8255 PPI to be sure its address
; and data lines are working OK.  You might be tempted to use the control for
; this, but according to the "official" Intel 8255 data sheet this register
; is write only.  Actually, all the 82C55s I've seen allow you to read back the
; control register, but I guess we can't depend on this.
;
;   The big problem with doing read/write test on the other registers is that
; we have to configure all the PPI bits as outputs first; otherwise when we
; read the port register we'll read the actual state of the pins and not what
; we last wrote there.  The problem with this is that it may cause contention
; if any of the 8255 port pins happen to be wired up to external drivers.
;
;  That's why there are series current limiting resistors on the GPIO card!

; Write the control register and condition all three ports as outputs.
	POST($58)		; PPI control register test
	WPPI(PPICTL,$9B)	; first make all ports inputs
	RPPI(PPICTL)		; try to read the control word back
	XRI	$9B		; did we read it successfully?
	LBNZ	NOPPI		; nope - no PPI installed
	SEX	PC0		; now make all the ports outputs
	WPPI(PPICTL,$80)	; ...
	RPPI(PPICTL)		; ...
	XRI	$80		; ...
	LBNZ	NOPPI		; nope - no PPI installed

; Super simple PPI data bus test to check for shorts or opens...
	POST($57)		; PPI data bus test
	WPPI(PPIPA,$AA)		; write pattern #1
	RPPI(PPIPA)		; and read it back
	XRI	$AA		; did we read it OK?
	BNZ	$		; nope - loop forever
	SEX	PC0		; ...
	WPPI(PPIPA,$55)		; one more simple test
	RPPI(PPIPA)		; ...
	XRI	$55		; ...
	BNZ	$		; and that's enough for now

; Now a simple PPI address bus test...
	POST($56)		; PPI address bus test
	WPPI(PPIPA,$AA)		; write one value to register A
	WPPI(PPIPB,$BB)		; and another to register B
	WPPI(PPIPC,$CC)		; and a third to register C
	RPPI(PPIPA)		; read 'em back and see if they're OK
	XRI	$AA		; ???
	NOP			; needed for page alignment!
	BNZ	$		; just loop forever if one fails
	SEX	PC0		; ...
	RPPI(PPIPB)		; ...
	XRI	$BB		; ...
	BNZ	$		; ...
	SEX	PC0		; one more time!
	RPPI(PPIPC)		; ...
	XRI	$CC		; ...
	BNZ	$		; ...

; Leave the PPI in input mode and we're done...
	SEX	PC0		; ...
	WPPI(PPICTL,$9B)	; ...
#endif

NOPPI:
; Fall into the PS/2 keyboard test...

	.EJECT
;	.SBTTL	PS/2 Keyboard Initialization

#ifdef ELF2K
;   After a power up or a reset the keyboard APU, if it is alive and well,
; sends three bytes - 0xCB, 0x42 ("KB") and then the APU firmware version.
; After that it sends either 0xAA if the keyboard is connected and OK, or
; nothing if there's no keyboard or the keyboard failed its own internal
; self test.
;
;   Remember, though, that the PS/2 keyboard interface may not even be
; present on this Elf 2000 system, so we can't wait forever for the "KB"
; to show up - there has to be a simple time out.
TSTPS2:	POST($54)		; PS/2 keyboard test
	RLDI(P1,PS2VER)		; start by initializing the PS2 keyboard
	LDI	0		;  ... APU firmware version to zero
	STR	P1		;  ... which means "no keyboard attached"!

;   Note that the keyboard APU is pretty fast by 1802 standards, and so for
; a time out we simply count up in the D register.  When it overflows, the
; time out has expired!
TPS21:	BPS2(TPS22)		; branch if the keyboard flag is set
	ADI	1		; nope - increment D
	BNF	TPS21		; and keep going 'till it overflows
	LBR	NOKBD		; no keyboard present

; Read the first byte from the keyboard ...
TPS22:	SEX	SP		; be sure X points to real memory
	INP	PS2KBD		; and read the keyboard data
	XRI	'K'+$80		; check the first magic byte
	LBNZ	NOKBD		; no keyboard if that's not it

; Wait for the second byte...
TPS23:	BPS2(TPS24)		; ...
	ADI	1		; ...
	BNF	TPS23		; ...
	LBR	NOKBD		; no keyboard present

; Read the second byte from the keyboard ...
TPS24:	INP	PS2KBD		; ...
	XRI	'B'		; and check this one too
	LBNZ	NOKBD		; no keyboard ..

;   Having received those two bytes succesfully, we now assume that there's
; an Elf 2000 GPIO card with the PS/2 keyboard APU present.  Now we wait,
; forever if necessary, for the firmware version number...
	POST($53)		; waiting for keyboard version
	BNPS2($)		; wait for the flag to set
	SEX	P1		; read the version directly into
	INP	PS2KBD		;  ... location PS2VER in RAM

;   That's it for the canned part of the APU firmware startup.  If there is
; really a keyboard connected to the GPIO card, then it will send 0xAA to the
; APU when the keyboard completes its own internal self test.  The APU passes
; that along to us, which we wait for here.  Notice that if the GPIO and APU
; is present but no keyboard is plugged in, we'll actually loop forever with
; POST code 57 displayed ...
;
;   NOTE - we'd like to do this, but we can't.  An 1802 RESET doesn't reset
; the PS/2 keyboard, so if the system is reset after a power up the keyboard
; won't send the 0xAA byte.  The APU _is_ reset by a 1802 RESET, however, and
; the way to fix this would be to make the APU firmware transmit a reset
; command to the keyboard whenever the APU is restarted, but the current APU
; firmware is receive only and doesn't have the ability to transmit anything.
;TPS25:	POST($52)		; no PS/2 keyboard
;	BNPS2($)		; wait for some data
;	SEX	SP		; ...
;	INP	PS2KBD		; now read what it is
;	XRI	$AA		; if it isn't keyboard OK
;	BNZ	TPS25		; then keep waiting!
#endif

NOKBD:
; Fall into SYSI2B...

	.EJECT
;	.SBTTL	Software Initialization

;   When we get here, both the EPROM and SRAM have been tested and the SRAM
; cleared OR, if the battery backup is working, then the SRAM contents have
; been tested and found to be valid.  Now we set up all the software, including
; the SCRT (standard call/return technique) linkage, the software stack, and
; initialize the terminal...

;   Time to initialize SCRT before going any further.  It may not sound like
; much, but remember that from here on P=3!!
SYSI2B:	SEX	PC0		; do POST() one last time
	POST($40)		; ...
	RLDI(SP,STACK)		; initialize the stack pointer
	RLDI(A,SYSIN3)		; continue processing from SYSIN3:
	LBR	F_INITCALL	; and intialize the SCRT routines

;   Change the POST to 19 to indicate that all hardware tests have passed.
; Post codes in the range $10..$19 are used for various software initialization
; stages...

;   If the non-volatile RAM chip is installed, then check then see if the NVR
; contents are valid and if they match the version number of this monitor.
; If the contents are invalid or if they're leftover from a different monitor
; version then load the NVR with the default settings now.
;
;   As a special hack for the ELF2K only, if the switch register is set to 0x43
; then re-initialize the NVR (assuming it's present) regardless ...
SYSIN3:	OUTI(LEDS,$18)		; set the LEDs 18 to indicate BIOS OK
	CALL(F_RTCTEST)		; is the RTC/NVR installed?
	LBNF	SYSI3B		; nope - there's nothing to do

; See if the switches are set to $43 ...
#ifdef ELF2K
	SEX	SP		; address temporary RAM
	INP	SWITCHES	; read the switch register
	XRI	$43		; are they set to 43?
	LBZ	SYSI3A		; yes - force NVR to be initialized
#endif

; Read the version number stored in the NVR and compare to MONVER ...
	RLDI(P1,NVRVERS)	; offset of the NVR version number
	RLDI(P2,NVRVER)		; store what we read here
	RLDI(P3,1)		; and read just one byte
	CALL(F_RDNVR)		; try to read NVR
	LBDF	SYSI3A		; NVR contents are not valid - initialize
	RLDI(DP,NVRVER)		; point to the NVRVER in RAM
	LDN	DP		; and see what we got
	XRI	MONVER		; does it match our version?
	LBZ	SYSI3B		; yes - NVR contents are valid!

; Initialize NVR with all the default settings ...
SYSI3A:	RLDI(P1,NVRBASE)	; offset of monitor data in NVR
	RLDI(P2,NVRDEFAULT)	; pointer to default NVR data in ROM
	RLDI(P3,NVRSIZE)	; count of bytes to write
	CALL(F_WRNVR)		; attempt to save it

;   If the data switches are set to 0x81 then just go directly to the video
; test without messing with the terminal or autobaud...
SYSI3B:
#ifdef PIXIE
	OUTI(LEDS,$17)		; special CHM startup mode
	SEX	SP		; address the stack
	INP	SWITCHES	; SWITCHES -> D, R(X)
	XRI	$81		; are they set to 0x81??
	LBZ	PIXCHM		; yes - just do the video test now
#endif

;   See if the 8275 video card is installed and, if it is, then start it
; up.  Remember that this card uses DMA and interrupts, so from here on R0
; and R1 are off limits!!
#ifdef VIDEO
	CALL(VIDEO)		; call INIT75
	PUSHD			; temporarily save the status
	RLDI(P1,VIDVER)		;  ... so we can save it in VIDVER
	POPD			; ...
	STR	P1		; ...
#endif

;   Now initialize (or re-initialize) the console serial port.  The console can
; be either the bit banged serial port on the main board, or the UART port on
; the disk card, and either one supports several different baud rates.  If this
; is a warm start and serial port data is saved in SRAM or NVR, the TTYINI
; routine will attempt to restore the previous console state. Otherwise it will
; call the BIOS autobaud function to determine the correct console port and
; speed...
	CALL(TTYINI)

;   Now print a sign on message with a whole bunch of information about the
; system configuration (well, a little bit at least!)...
SYSI30:	OUTI(LEDS,$15)		; POST code 15 - software initialization done
	OUTSTR(SYSTEM)		; "COSMAC ELF 2000" ...

; Print the EPROM version and checksum...
	INLMES(" EPROM V")	; ...
	RLDI(P1,MONVER)		; print the EPROM version number
	CALL(TDEC16)		; always in decimal
	INLMES(" CHECKSUM ")	; and the EPROM checksum
	RLDI(P2,CHKSUM)		; stored here by the romcksum program
	SEX	P2		; use P2 to address memory
	POPR(P1)		; and fetch the checksum into P1
	CALL(THEX4)		; type that in HEX

;   Now give the RAM status...  We could actually call the BIOS F_FREEMEM
; function here to determine the SRAM size, but this code (especially the
; RAM test) is pretty much hardwired for a 32K SRAM.  Also, F_FREEMEM takes
; several seconds to execute, which is annoying here.
RAMSIZE	.EQU	(RAMPAGE+$100) / 1024
	INLMES("  SRAM ")	; print the SRAM size
	RLDI(P1,RAMSIZE)	; in decimal kilobytes
	CALL(TDEC16)		; ...
	INLMES("K ")		; ...
	RLDI(DP,BATTOK)		; get the battery backup flag
	LDN	DP		; from the monitor's RAM page
	LBNZ	SYSIN4		; branch if battery backup was OK
	INLMES("INITIALIZED")	; SRAM was initialized from scratch
	LBR	SYSI4A		; ...
SYSIN4:	INLMES("CONTENTS OK")	; current SRAM contents were used

; That's the end of line 1. Next, print all the copyright notice(s)...
SYSI4A:	CALL(TCRLF)		; ...
	OUTSTR(RIGHTS)		; type the copyright notices

; Fall into the IDE drive discovery...
	.EJECT
;	.SBTTL	Probe for IDE drives

;  Probe for a master and/or slave ide drive and identify what we find...
SYSI5A:	OUTI(LEDS,$14)		; POST code for IDE master
	LDI	0		; first test the IDE master drive
	CALL(PROBE)		; ...
;   Currently the IDE slave isn't supported by the BIOS, so there's no reason
; to probe for it.  It just makes the boot take longer!
;	OUTI(LEDS,$13)		; POST code for IDE slave
;	LDI	1		; then test the IDE slae
;	CALL(PROBE)		; ...

; If this system as a RTC and NVR, then print the date and time...
	OUTI(LEDS,$12)		; printing date and time
	CALL(F_RTCTEST)		; is the real time clock installed?
	BNF	SYSI5B		; skip if not
	CALL(SHOWNOW)		; type the current date/time
	CALL(TCRLF)		; and finish the line

; Fall into the auto [re]start routine...
SYSI5B:

	.EJECT
;	.SBTTL	System Auto [Re]Start

;   The boot flag (BOOTF) can be set to a non-zero value to cause the system
; to automatically restart or boot on a power up. Remember that, so long as the
; main board has the battery backup installed, all of SRAM will be preserved
; while power is off.  If the BOOTF flag is ABTADDR then RESTA is assumed to
; contain a 16 bit restart address and we jump there before starting the
; monitor's command scanner.
;
;   If the BOOTF flag contains ABTDISK, then we'll attempt to boot the primary
; IDE drive.  If this is succesful then we can go directly to ElfOS without
; needing to type the monitor "BOOT" command.  If the bootstrap is unsuccessful
; (i.e. there's no IDE drive or the media is not bootable) then we simply
; enter the monitor's command loop anyway.
;
;   If the system contains NVR (non-volatile RAM) then it's possible to store
; the boot flag in NVR as well.
ASTART:	OUTI(LEDS, $11)		; POST code 11 for restart
	RLDI(DP,BOOTF)		; point DP to the boot flag
	LDN	DP		; and then load the boot flag
	LBNZ	ASTAR1		; if it's not zero, then decode it

; See if there's an NVR attached, and attempt to read the boot flag from it.
	RLDI(P1,NVRBOOT)	; offset of the boot flag in NVR
	RLDI(P2,BOOTF)		; where to store the data in SRAM
	RLDI(P3,3)		; number of bytes to read
	CALL(F_RDNVR)		; ...
;   Note that if this fails (either because there's no NVR installed or because
; the NVR contents are invalid) then BOOTF will be unchanged and remain zero.
	RLDI(DP,BOOTF)		; F_RDNVR trashes DP, so reload it
	LDA	DP		; get the new boot flag

; Decode the restart option selected ...
ASTAR1:	LBZ	MAIN0		; if it's zero, then start the command scanner
	XRI	ABTDISK		; autoboot from IDE?
	LBZ	ASTAR2		; yes - go do that
	LDA	DP		; get the boot flag again
	XRI	ABTADDR		; "SET RESTART xxxx" ?
	LBNZ	MAIN0		; nope - default to SET RESTART NONE

; Here to restart at a specific address ...
#ifdef VIDEO
	CALL(ISCRTC)		; is the video card installed?
	LBDF	MAIN0		; yes - can't do this (it uses R0!)
#endif
	CALL(RESADR)		; print "RESTART @...."
	RLDI(DP,RESTA)		; point to the restart address
	SEX	DP		; ...
	POPR(PC0)		; load PC0
	SEX	PC0		; set X=0 too
	SEP	PC0		; and hope for the best!


; Attempt to bootstrap the primary IDE drive...
ASTAR2:	POST($10)		; autoboot
	CALL(BOOTIDE)		; this returns only if the bootstrap fails!
;	OUTSTR(ABTMSG)		; BOOTIDE already prints an error message!
	LBR	MAIN0		; so if it does fail, just run the monitor

; These messages are used during a cold start...
;ABTMSG:	.TEXT	"?AUTOBOOT FAIL\r\n\000"
#ifdef HELP
FORHLP:	.TEXT	"For help type HELP\000"
#endif

	.EJECT
;	.SBTTL	BOOTS Command Scanner

;   This is the 'main program' for BOOTS. It reads a command line, decodes
; the name of the command, and dispatches to the correct command processor
; routine...

; Print the "For help type HELP" message...
MAIN0:
#ifdef HELP
	OUTSTR(FORHLP)	; print the help message and we're done
#endif
MAIN2:	CALL(TCRLF)	; finish the line

;  Initialize (or rather, re-initialize) enough context so that the monitor
; can still run even if some registers have been screwed up...
MAIN:	OUTI(LEDS,$00)	; change the POST code to 00
MAIN1:	RLDI(SP,STACK)	; reset the stack pointer to the TOS
	SEX	SP	; and reset X
	RLDI(DP,BAUD1)	; set DP and, as as side effect, ...
	LDN	DP	;  ... reset the baud rate constant
	PHI	BAUD	;  ...

;   Normally we set R1 to point at the TRAP routine so that break points can
; be used inside monitor commands too (after all, there are sometimes bugs
; in the monitor too!) but if the video is active then we can't do that...
#ifdef VIDEO
	CALL(ISCRTC)	; is the video card active:
	BDF	MAIN10	; yep - skip this
#endif
	RLDI(1,TRAP)	; allow breakpoints to be used inside monitor commands
MAIN10:

; Print the monitor prompt and scan a command line...
	INLMES(">>>")	; print the monitor prompt
	RLDI(P1,CMDBUF)	; address of the command line buffer
	RLDI(P3,CMDMAX)	; and the length of the same
	CALL(F_INPUTL)	; read a command line
	LBDF	MAIN2	; branch if the line was terminated by ^C
	CALL(TCRLF)	; F_INPUT doesn't echo a <LF> at the end

;   Parse the command name, look it up, and execute it.  By convention while
; we're parsing the command line (which occupies a good bit of code, as you
; might imagine), P1 is always used as a command line pointer...
	RLDI(P1,CMDBUF)	; P1 always points to the command line
	CALL(F_LTRIM)	; skip any leading spaces
	CALL(ISEOL)	; is the line blank???
	LBDF	MAIN	; yes - just go read another
	RLDI(P2,CMDTBL)	; table of top level commands
	CALL(COMND)	; parse and execute the command
	LBR	MAIN	; and the do it all over again

	.EJECT
;	.SBTTL	Lookup and Dispatch Command Verbs

;   This routine is called with P1 pointing to the first letter of a command
; (usually the first thing in the command buffer) and P2 pointing to a table
; of commands.  It searches the command table for a command that matches the
; command line and, if it finds one, dispatches to the correct action routine.
;
;   Commands can be any number of characters (not necessarily even letters)
; and may be abbreviated to a minimum length specified in the command table.
; For example, "BA", "BAS", "BASI" and "BASIC" are all valid for the "BASIC"
; command, however "BASEBALL" is not.  
COMND:	RCOPY(P3,P1)	; save the command line pointer so we can back up
COMND1:	RCOPY(P1,P3)	; reset the command line pointer
	LDA	P2	; get the minimum match count for the next command
	LBZ	ERRALL	; end of command table if it's zero
	PLO	P4	; save the minimum match count

;   Compare characters on the command line with those in the command table
; and, as long as they match, advance both pointers....
COMND2:	LDN	P2	; take a peek at the next command table byte
	LBZ	COMN3A	; branch if it's the end of this command
	LDN	P1	; and get the next character
	CALL(FOLD)	; make it upper case
	SEX	P2	; now address the command table
	SM		; does the command line match the table?
	BNZ	COMND3	; nope - skip over this command
	INC	P2	; yes - increment P2
	INC	P1	; and P1 ...
	DEC	P4	; and keep count of the number of matches
	LBR	COMND2	; keep comparing characters

;   Here when we find something that doesn't match.  If enough characters
; DID match, then this is the command; otherwise move on to the next table
; entry...
COMND3:	SEX	P2	; be sure P2 is at the end of this command
	LDXA		; ???
	BNZ	$-1	; keep going until we're there
	SKP		; skip over the IRX
COMN3A:	IRX		; skip over the null byte to the dispatch address
	GLO	P4	; how many characters matched?
	BZ	COMND4	; branch if an exact match
	SHL		; test the sign bit of P4.0
	BDF	COMND4	; more than an exact match

; This command doesn't match.  Skip it and move on to the next...
	INC P2\ INC P2	; skip two bytes for the dispatch address
	LBR	COMND1	; and then start over again

; This command matches!
COMND4:	RLDI(T1,COMND5)	; switch the PC temporarily
	SEP	T1	; ...
COMND5:	SEX	P2	; ...
	POPR(PC)	; load the dispatch address into the PC
	SEX	SP	; return to the usual X value
	SEP	PC	; branch to the action routine

	.EJECT
;	.SBTTL	Command Parsing Functions

;   Examine the character pointed to by P1 and if it's a space, tab, or end
; of line (NULL) then return with DF=1...
ISSPAC:	LDN	P1	; get the byte from the command line
	BZ	ISSPA1	; return TRUE for EOL
	SMI	CHTAB	; is it a tab?
	BZ	ISSPA1	; yes - return true for that too
	SMI   ' '-CHTAB	; no - what about a space?
	BZ	ISSPA1	; that works as well
	CDF		; it's not a space, return DF=0
	RETURN		; ...
ISSPA1:	SDF		; it IS a space!
	RETURN

; If the character pointed to by P1 is EOL, then return with DF=1...
ISEOL:	LDN	P1	; get the byte from the command line
	LBZ	ISSPA1	; return DF=1 if it's EOL
	CDF		; otherwise return DF=0
	RETURN		; ...

;   This routine will echo a question mark, then all the characters from
; the start of the command buffer up to the location addressed by P1, and
; then another question mark and a CRLF.  After that it does a LBR to MAIN
; to restart the command scanner.  It's used to report syntax errors; for
; example, if the user types "BASEBALL" instead of "BASIC", he will see
; "?BASE?"...
CMDERR:	LDI	$00	; terminate the string in the command buffer
	INC	P1	; ...
	STR	P1	; at the location currently addressed by P1
;   Enter here (again with an LBR) to do the same thing, except at this
; point we'll echo the entire command line regardless of P1...
ERRALL:	CALL(TQUEST)	; print a question mark
	OUTSTR(CMDBUF)	; and whatever's in the command buffer
	CALL(TQUEST)	; and another question mark
	CALL(TCRLF)	; end the line
	LBR	MAIN	; and go read a new command
	CALL(F_TTY)	; ...

	.EJECT
;	.SBTTL	Scan Command Parameter Lists

;   These routines will scan the parameter lists for commands which either
; one, two or three parameters, all of which are hex numbers.

; Scan two parameters and return them in registers P4 and P3...
SCANP2:	CALL(SCANP1)	; scan the first parameter
	RCOPY(P3,P2)	; and save it
	CALL(ISEOL)	; there had better be more there
	LBDF	CMDERR	; error if not
			; and fall into SCANP1 to get the other parameter

; Scan a single parameter and return its value in register P4...
SCANP1:	CALL(F_LTRIM)	; ignore any leading spaces
	LDN	P1	; get the next character
	CALL(ISHEX)	; is it a hex digit?
	LBNF	CMDERR	; no - print error message and restart
	LBR	F_HEXIN	; scan a number and return in P2

	.EJECT
;	.SBTTL	SHOW, SET and TEST Commands

;   These three little routines parse the SHOW, SET and TEST commands, each of
; which takes a secondary argument - e.g. "SHOW RTC", "SET BOOT", or "TEST RAM"!
SHOW:	CALL(F_LTRIM)	; skip any spaces
	CALL(ISEOL)	; there has to be an argument there
	LBDF	CMDERR	; error if not
	RLDI(P2,SHOCMD)	; point to the table of SHOW commands
	LBR	COMND	; parse it (and call CMDERR if we can't!)

SHOCMD:	CMD(4, "TERMINAL", SHOTERM)	; show terminal settings
	CMD(3, "NVR",      SHOWRTC)	; dump RTC/NVR chip
	CMD(3, "IDE",	   SHOWIDE)	; identify IDE drives
	CMD(3, "MEMORY",   SHOMEM)	; show memory size
	CMD(3, "VERSION",  SHOVER)	; show monitor and BIOS version number
	CMD(3, "RESTART",  SHORES)	; show restart option
	CMD(3, "REGISTERS",SHOREG)	; show registers (after a breakpoint)
	CMD(2, "DP",       DPDUMP)	; show monitor data page
	CMD(2, "DATE",     SHOWTIME)	; show the real time clock
	CMD(2, "EF",	   SHOWEF)	; print status of EF inputs
	CMD(3, "CPU",      SHOCPU)	; print CPU type and speed
	.DB	0


; Set command...
SET:	CALL(F_LTRIM)	; ...
	CALL(ISEOL)	; ...
	LBDF	CMDERR	; ...
	RLDI(P2,SETCMD)	; ...
	LBR	COMND	; ...

SETCMD:	CMD(1, "Q",	  SETQ)		; set Q (for testing)
	CMD(2, "DATE",    SETTIME)	; set the real time clock
	CMD(3, "RESTART", SETRESTA)	; set the boot options
	CMD(3, "NVR",     SETNVR)	; set the NVR contents
	.DB	0


; Test command...
TEST:	CALL(F_LTRIM)	; ...
	CALL(ISEOL)	; ...
	LBDF	CMDERR	; ...
	RLDI(P2,TSTCMD)	; ...
	LBR	COMND

TSTCMD:	CMD(3, "RAM",   RAMTEST)	; exhaustive RAM test
#ifdef PIXIE
	CMD(3, "PIXIE", PIXTEST)	; test CDP1861 video
#endif
#ifdef VIDEO
	CMD(2, "VT1802",VTTEST)		; test VT1802 video terminal
#endif
	.DB	0

	.EJECT
;	.SBTTL	INPUT Command

;   The IN[PUT] command reads the specified I/O port, 1..7, and prints
; the byte received in hexadecimal...
INPUT:	CALL(SCANP1)		; read the port number
	CALL(ISEOL)		; and that had better be all
	LBNF	CMDERR		; error if there's more
	RLDI(P4,IOT)		; point T1 at the IOT buffer
	GLO	P2		; get the port address
	ANI	$07		; trim it to just 3 bits
	LBZ	CMDERR		; error if port 0 selected
	ORI	$68		; turn it into an input instruction
	STR	P4		; and store it in IOT
	INC	P4		; point to IOT+1
	LDI	$D0+PC		; load a "SEP PC" instruction
	STR	P4		; and store that in IOT+1
	DEC	P4		; back to IOT:

; Execute the IOT and type the result...
	INLMES("Port ")
	LDN	P4		; get the INP instruction again
	ANI	$07		; convert the port number to ASCII
	ORI	'0'		; ...
	CALL(F_TTY)		; ...
	INLMES(" = ")
	SEP	P4		; execute the input and hold your breath!
	CALL(THEX2)		; type that in hex
	CALL(TCRLF)		; finish the line
	LBR	MAIN		; and we're done here!

	.EJECT
;	.SBTTL	OUTPUT Command

;   The OUT[PUT] command (i.e. ">>>OUT <port> <byte>") writes the specified
; byte to the specified I/O port.
OUTPUT:	CALL(SCANP2)		; read the port number and the byte
	CALL(ISEOL)		; there should be no more
	LBNF	CMDERR		; error if there is
	RLDI(P4,IOT)		; point P4 at the IOT buffer
	GLO	P3		; get the port address
	ANI	$07		; trim it to just 3 bits
	LBZ	CMDERR		; error if port 0 selected
	ORI	$60		; turn it into an input instruction
	STR	P4		; and store it in IOT
	INC	P4		; point to IOT+1
	GLO	P2		; get the data byte
	STR	P4		; and store that
	INC	P4		; point to IOT+2
	LDI	$D0+PC		; load a "SEP PC" instruction
	STR	P4		; and store that in IOT+2
	DEC	P4		; back to IOT:
	DEC	P4		; ...
	SEX	P4		; set X=P for IOT
	SEP	P4		; now call the output routine

;   A branch to MAIN: will change the data LEDs back to $00.  There's no
; real harm in this, but just for fun (and so that we can test the data
; LEDs with the OUTPUT command) this command bypasses that.
	LBR	MAIN1		; and we're done

	.EJECT
;	.SBTTL	Examine Memory Command

;  This routine processes the EXAMINE command. This command will allow the user
; to examine one or more bytes of memory. The E command accepts two formats of
; operands:
;
;	>>>E xxxx yyyy
;	- or -
;	>>>E xxxx
;
;   The first format will print the contents of all locations from x to y (with
; 16 bytes per line). The second format will print the contents of only
; location x (all addresses are in hex, of course)...

EXAM:	CALL(SCANP1)	; to scan the first parameter and put it in P2
	RCOPY(P3,P2)	; save that in a safe place
	CALL(ISEOL)	; is there more?
	LBDF	EXAM1	; no - examine with one operand
	CALL(SCANP1)	; otherwise scan a second parameter
	RCOPY(P4,P2)	; and save it in P4 for a while
	CALL(ISEOL)	; now there had better be no more
	LBNF	CMDERR	; error if there's extra junk at the end
	CALL(P3LEP4)	; are the parameters in the right order??
	LBNF	CMDERR	; error if not
	CALL(MEMDMP)	; go print in the memory dump format
	LBR	MAIN	; and then on to the next command

; Here for the one address for of the command...
EXAM1:	RCOPY(P1,P3)	; copy the address
	CALL(THEX4)	; and type it out
	INLMES("> ")	; ...
	LDN	P3	; now fetch the contents of that byte
	CALL(THEX2)	; and type that too
	CALL(TCRLF)	; type a CRLF and we're done
	LBR	MAIN	; ...

	.EJECT
;	.SBTTL	Generic Memory Dump

;   This routine will dump, in both hexadecimal and ASCII, the block of 
; memory between P3 and P4.  It's used by the EXAMINE command, but it
; can also be called from other random places, which is especially handy
; for chasing down bugs...
MEMDMP:	GLO	P3	; round P3 off to $xxx0
	ANI	$F0	; ...
	PLO	P3	; ...
	GLO	P4	; and round P4 off to $xxxF
	ORI	$0F	; ...
	PLO	P4	; ...
	CALL(F_INMSG)
	.TEXT	"        0  1  2  3  4  5  6  7  8  9  A  B  C  D  E  F\r\n\000"

; Print the address of this line (the first of a row of 16 bytes)...
MEMDM2:	RCOPY(P1,P3)	; copy the address of this byte
	CALL(THEX4)	; and then type it in hex
	INLMES("> ")	; type a > character after the address
	SKP		; skip the INC P3 the first time around

; Now print a row of 16 bytes in hexadecimal...
MEMDM3:	INC	P3	; on to the next byte...
	CALL(TSPACE)	; leave some room between bytes
	LDN	P3	; get the next byte from memory
	CALL(THEX2)	; and type the data in two hex digits

; Here to advance to the next data byte...
MEMDM4:	GLO	P3	; get the current address
	ANI	$0F	; have we done sixteen bytes??
	XRI	$0F	; ???
	LBNZ	MEMDM3	; no - on to the next address

; Print all sixteen bytes again, put this time in ASCII...
MEMDM5:	CALL(TSPACE)	; leave a few blanks
	CALL(TSPACE)	; ...
	GLO	P3	; restore the address back to the
	ANI	$F0	;  ... beginning of the line
	PLO	P3	; ...
	SKP		; skip the INC P3 the first time around

; If the next byte is a printing ASCII character, $20..$7E, then print it.
MEMDM6:	INC	P3	; on to the next byte
	LDN	P3	; get the byte
	ANI	$60	; is it a control character??
	LBZ	MEMDM7	; yep - print a dot
	LDN	P3	; no - get the byte again
	ANI	$7F	; ignore the 8th bit
	XRI	$7F	; and is it a delete (rubout) ??
	LBZ	MEMDM7	; yep - print a dot
	XRI	$7F	; no - restore the original byte
	CALL(F_TTY)	; and type it
	LBR	MEMDM8	; on to the next byte

; Here if the character isn't printing - print a "." instead...
MEMDM7:	OUTCHR('.')	; do just that
MEMDM8:	GLO	P3	; get the current address
	ANI	$0F	; have we done sixteen bytes?
	XRI	$0F	; ???
	LBNZ	MEMDM6	; nope - keep printing

; We're done with this line of sixteen bytes....
	CALL(TCRLF)	; finish the line
	CALL(F_BRKTEST)	; does the user want to stop early?
	LBDF	MEMDM9	; branch if yes
	INC	P3	; on to the next byte
	CALL(P3LEP4)	; have we done all of them?
	LBDF	MEMDM2	; nope, keep going
MEMDM9:	RETURN		; yep - all done

	.EJECT
;	.SBTTL	Deposit Memory Command

;   The DEPOSIT command is used	to store bytes in memory.  It accepts an
; address and a list of data as operands:
;
;	>>>D xxxx dd dd dd dd dd dd dd dd ....
;
; This command will deposit the data specified by d into memory addresses
; beginning at xxxx.  Any number of data bytes may be specified; they are
; deposited into sequential addresses...

DEPOSIT:CALL(SCANP1) 	; scan the address first
	RCOPY(P3,P2)	; then save the address where it is safe
	CALL(ISSPAC)	; we'd better have found a space
	LBNF	CMDERR	; error if not

; This loop will read and store bytes...
DEP1:	CALL(SCANP1)	; read another parameter
	CALL(ISSPAC)	; and we'd better have found a space or EOL
	LBNF	CMDERR	; error if not
	GLO	P2	; get the low byte of the data scanned
	STR	P3	; and store it in memory at (P3)
	SEX	P3	; then see if it was stored correctly
	SM		; ...
	LBNZ	DEP3	; memory error
	INC	P3	; on to the next address
	CALL(ISEOL)	; end of line?
	LBNF	DEP1	; nope - keep scanning

; Here when we have finished the command....
DEP2:	RETURN

;   Here if the memory doesn't change - that could be because the command
; file attempted to change EPROM or non-existent memory...
DEP3:	OUTSTR(MERMSG)
	RETURN
MERMSG:	.DB	"?MEMORY ERROR\r\n", 0

	.EJECT
;	.SBTTL	RUN and CALL Commands

;   The RUN command will begin execution of a user's program with X=P=0 and
; all other registers undefined.  The starting address may be specified as
; an argument to RUN (e.g. "RUN 100" starts at $0100) or it may be omitted
; in which case execution starts at location zero.  Since this command runs
; a program with X=P=0, it mimics the behavior of the bare hardware when no
; monitor is present.  In this case the user's program must return control to
; the monitor with a "LBR $8000" instruction.
;
;   Note that the RUN command can't be used when the Elf 2000 video card
; is used because the video card requires that interrupts and DMA be active
; all the time (that's how we get the video, after all) so it's impossible
; to start a program with X=P=0.  Your only option in that case is to use
; the CALL command...
RUNUSR:
#ifdef VIDEO
	CALL(NOCRTC)	; not allowed when the video card is in use
	LBDF	RUN0	; ...
#endif
	CALL(ISEOL)	; is there any argument to the RUN command?
	LBDF	RUN1	; no - start from address $0000
	CALL(SCANP1)	; yes - go read the starting address
	CALL(ISEOL)	; and then that had better be the end
	LBNF	CMDERR	; ...
	RCOPY(0,P2)	; put the start address in R0
	LBR	RUN2	; and start running from there
RUN0:	RETURN		; here if error

; Here to start running from location zero...
RUN1:	RCLEAR(0)	; set at location $0000
RUN2:	RLDI(1,TRAP)	; register 1 still points to the TRAP function
	SEX	0	; and start with X=P=0
	SEP	0	; away we go!
	LBR	MAIN	; should never get here!!

;   The CALL command invokes a user's program as if it were a subroutine of
; this monitor.  The address specified in the CALL command, which is required
; in this case, is called via SCRT just as if it were a subroutine.  All the
; standard monitor registers, including A, CALLPC, RETPC, SP, DP, BAUD, etc.
; will have the same values they have here.  X will point to the SP (R2)
; which will point to the monitor's stack area.  The user's program can return
; to the monitor simply by executing a RETURN (SEP RETPC) instruction.
CALUSR:	CALL(SCANP1)	; in this case a parameter is required...
	CALL(ISEOL)	; and then no more
	LBNF	CMDERR	; ...
	RLDI(T1,CALUS1)	; execute the rest of the code with P=T1
	SEP	T1	; ...

; Here to branch to the user's function...
CALUS1:	RCOPY(PC,P2)	; copy the address of the user's code to R3
	SEP	PC	; and pretend as if we just branched to it...
	LBR	MAIN	; should never get here!!

	.EJECT
;	.SBTTL	SHOW EF Command

;   The SHOW EF command prints the current state of all four EF inputs.
; The state printed is the logical status, so EFx=1 implies that the input
; pin is low and vice versa...
SHOWEF:
	CALL(ISEOL)		; no arguments allowed
	LBNF	CMDERR		; ...

; Print EF1...
	INLMES("EF1=")
	LDI	'0'		; assume it's zero
	BN1	EFS1		; and branch if it really is zero
	LDI	'1'		; nope - it's one
EFS1:	CALL(F_TTY)

; Print EF2...
	INLMES(" EF2=")
	LDI	'0'		; assume it's zero
	BN2	EFS2		; and branch if it really is zero
	LDI	'1'		; nope - it's one
EFS2:	CALL(F_TTY)

; Print EF3...
	INLMES(" EF3=")
	LDI	'0'		; assume it's zero
	BN3	EFS3		; and branch if it really is zero
	LDI	'1'		; nope - it's one
EFS3:	CALL(F_TTY)

; Print EF4...
	INLMES(" EF4=")
	LDI	'0'		; assume it's zero
	BN4	EFS4		; and branch if it really is zero
	LDI	'1'		; nope - it's one
EFS4:	CALL(F_TTY)

; All done!
	CALL(TCRLF)
	LBR	MAIN

	.EJECT
;	.SBTTL	SET RESTART Command

;   The SET RESTART command allows the user to specify the action taken on a
; warm start.  A warm start occurs when the basic ELF2K has the memory battery
; backup option installed and the memory contents are valid on startup, OR if
; the UART/NVR/RTC card is installed and the NVR contents are valid.  The
; SET RESTART command has three basic forms:
;
;	SET RESTART xxxx	- restart at memory address xxxx
;	SET RESTART BOOT	- attempt to boot from primary IDE disk
;	SET RESTART NONE	- no restart action (prompt for monitor command)
;

SETRESTA:
	CALL(F_LTRIM)		; skip any spaces
	CALL(ISEOL)		; and there had better be an argument there
	LBDF	CMDERR		; error if none
	RCOPY(T1,P1)		; save a copy of the command line pointer

;   First attempt to scan the hex version of the command.  If this succeeds,
; then we know that's what we have.  If it fails to parse, then back up and
; rescan with the NONE or BOOT options instead...
	LDN	P1		; get the first character
	CALL(ISHEX)		; is it a hex number?
	LBNF	SETRE1		; nope - try NONE or BOOT
	CALL(SCANP1)		; read a hex number
	CALL(ISEOL)		; and check for end of line
	LBNF	SETRE1		; error - try the other format

; Here for the SET RESTART xxxx form.
#ifdef VIDEO
	CALL(NOCRTC)		; not allowed with the video card
	LBDF	CMDERR		; ...
#endif
	RLDI(DP,RESTA+1)	; point to RESTA
	SEX	DP		; and use DP to address memory
	PUSHR(P2)		; save the restart address to RESTA
	LDI	ABTADDR		; finally, set the BOOT FLAG to ABTADDR
	LBR	SETBO1		; set BOOTF and update NVR

;   Here to test for the SET RESTART BOOT and SET RESTART NONE forms of the
; command.  If it's not one of these, it's wrong :-)
SETRE1:	RCOPY(P1,T1)		; restore the command line pointer
	RLDI(P2,RESCMD)		; point to the table of restart options
	RLDI(DP,BOOTF)		; and leave DP pointing to BOOTF
	LBR	COMND		; parse it (or call CMDERR if it doesn't parse!)

; Table of SET RESTART commands...
RESCMD:	CMD(3, "BOOT", SETRBO)	; SET RESTART BOOT
	CMD(2, "NONE", SETRNO)	; SET RESTART NONE
	.DB	0		; end of table


; Here for SET RESTART BOOT...
SETRBO:	LDI	ABTDISK		; set BOOTF to ABTDISK for BOOT IDE
	BR	SETBO1		; and then update the NVR and we're done..

; Here for SET RESTART NONE...
SETRNO:	LDI	ABTNONE		; set BOOTF to ABTNONE for no restart action
SETBO1:	STR	DP		; first update BOOTF
	RLDI(P1,NVRBOOT)	; offset in NVR of the boot flag byte
	RLDI(P2,BOOTF)		; pointer to data in main memory
	RLDI(P3,3)		; number of bytes to write
	LBR	F_WRNVR		; write to NVR and return

	.EJECT
;	.SBTTL	BOOT and SHOW IDE Commands

;   The BOOT command attempts to bootstrap the IDE master device.  It has no
; arguments and there's not much more to it than that!
BOOTCMD:CALL(ISEOL)		; make sure there are no arguments
	LBNF	CMDERR		; fail if there is

; The SYSINI routine calls here if the boot flag is set to BOOT...
BOOTIDE:OUTSTR(BOOMSG)		; tell the user what we're doing
	CALL(F_BOOTIDE)		; and ask the BIOS to bootstrap
	LBNF	NOBOOT		; hardware OK but no ElfOS boot
	OUTSTR(BADDR1)		; ?DRIVE ERROR
	RETURN			; ...

; Here if the attached volume is not bootable ...
NOBOOT:	OUTSTR(BFAMSG)		; ?NOT BOOTABLE
	RETURN			; ...

; IDE bootstrap messages ...
BOOMSG:	.TEXT	"Booting primary IDE ...\r\n\000"
BFAMSG:	.TEXT	"?NOT BOOTABLE\r\n\000"

;   The SHOW IDE command prints a list of the IDE devices (there are at most
; two!) attached.  It's the same information printed at startup by SYSINI.
SHOWIDE:CALL(ISEOL)		; arguments are neither required nor allowed
	LBNF	CMDERR		; error if there's more
	LDI	$00		; first probe for drive 0 (the master)
	CALL(PROBE)		; and print what we find
	LDI	$01		; then probe for drive 1 (slave)
	LBR	PROBE		; ...

	.EJECT
;	.SBTTL	Probe For IDE Drives

;   This routine will probe the IDE bus for the existence of a drive and,
; if a drive is found, the BIOS will be used to reset and initialize it.
; Once the drive is initialized the BIOS identify device function is used
; to determine the drive size and manufacturer.  When called, D should
; contain zero to test the primary (master) drive or 1 to test the secondary
; (slave) drive...
PROBE:	STXD			; save the unit number on the stack
	SHL\ SHL\ SHL\ SHL	; turn unit 1 to 0x10; unit zero stays zero
	ORI	$E0		; the rest of these bits should be 1
	STR	SP		; and save the drive select on the stack
	SEX	PC		; and write the IDE drive select register
	OUT	IDE_SELECT	; ...
	.DB	IDELBA3		; head/drive select register
	SEX	SP		; back to the stack
	OUT	IDE_DATA	; and write the drive select bit
	DEC	SP		; correct for OUT instruction

;   Now test two of the LBA/cylinder/sector registers to see if R/W memory
; actually exists.  If it does, there's probably drive there.  Writing these
; registers is safe enough because their contents doesn't mean anything until
; a command is issued, which we won't do!
	SEX	PC		; X=P
	WIDE(IDELBA0,$AA)	; write $AA to the low LBA register
	WIDE(IDELBA1,$55)	; and then $55 to the next LBA register
	SEX	PC		; X=P
	RIDE(IDELBA0)		; then read back LBA0
	XRI	$AA		; if we get back what we wrote
	LBNZ	NODRIVE		;  ... then there's probably a drive there!
	SEX	PC		; X=P
	RIDE(IDELBA1)		; but just to be safe read the other register
	XRI	$55		; ...
	BZ	PROBE1		; ...
	SEX	SP		; ...

; If no drive is found, fix the stack and return DF=1...
NODRIVE:IRX			; remove the unit select from the stack
	SDF			; set DF=1
	RETURN			; and we're outta here

; Identify the unit we've found...
PROBE1:	IRX\ LDX\ DEC SP	; get the unit number back from the stack
	BZ	PROB1A		; jump if unit 0 selected
	INLMES("IDE Slave:  ")
	BR	PROB1B
PROB1A:	INLMES("IDE Master: ")

; Call the BIOS to reset the drive and then get its size in Mb...
PROB1B:	IRX\ LDX\ DEC SP	; get the unit number back again
	PLO	P2		; store it for the BIOS
	CALL(F_IDERESET)	; and reset the drive
	LBDF	BADDRV		; branch if hard drive error
	IRX\ LDX\ DEC SP	; get the unit number back again
	PLO	P2		; store it for the BIOS
	CALL(F_IDESIZE)		; now get the size of the drive
	GHI	P1		; check for zero drive size
	LBNZ	PROB1C		; ...
	GLO	P1		; ...
	LBZ	BADDRV		; zero means an unusable drive
PROB1C:	CALL(TDEC16)		; type the size in megabytes
	INLMES("Mb ")		; ...

;   Now send an IDENTIFY DEVICE command to the drive and print various
; interesting tidbits (such as the drive's model number)...
	RLDI(P1,DSKBUF)		; point to the disk buffer
	IRX\ LDX\ DEC SP	; get the unit number back again
	PLO	P2		; store it for the BIOS
	CALL(F_IDEID)		; ...
	LBDF	BADDRV		; this shouldn't fail, but...
	RLDI(P1,DSKBUF+$36+39)	; make sure the model number is
	LDI	0		; ...
	STR	P1		; ...
	OUTSTR(DSKBUF+$36)	; type the model number
	CALL(TCRLF)		; and finish the line
	IRX			; fix the stack
	CDF			; set DF=0
	RETURN			; and we're done

; Here if the drive has some hard error ...
BADDRV:	OUTSTR(BADDR1)		; ?DRIVE ERROR
	LBR	NODRIVE		; return DF=0 and quit
BADDR1:	.TEXT	"?DRIVE ERROR\r\n\000"

	.EJECT
;	.SBTTL	SET Q Command

;   The "SET Q 0" and "SET Q 1" commands may be used to test the Q output, but
; ONLY if the bit banging serial I/O is NOT in use!  The reason should be
; obvious :-)
SETQ:	CALL(SCANP1)		; one parameter is required
	CALL(ISEOL)		; no more arguments allowed
	LBNF	CMDERR		; error if there are any
	GHI	BAUD		; is the bit banging port in use?
	ANI	$FE		; ignore the local echo bit
	LBNZ	NOSETQ		; can't do this command if it is
	GLO	P2		; get the LSB of the argument
	SHR			; and put the LSB in DF
	BNF	RESETQ		; reset Q if the LSB is zero
	SEQ			; nope - set Q
	RETURN			; and return

; Here for "SET Q 0"...
RESETQ:	REQ			; reset Q
	RETURN			; and return

; Here if the Q output is being used for the console terminal...
NOSETQ:	RLDI(P1,NOQMSG)		; print an error message
	LBR	F_MSG		;  ... and return
NOQMSG:	.TEXT	"?CAN'T - CONSOLE\r\n\000"

	.EJECT
;	.SBTTL	Show the Current Date and Time

;   The "SHOW DA[TIME]" command shows the current date and time.  Needless to
; say, it takes no arguments.  The SHOWNOW routine is called from SYSINI to
; display the current date and time...
SHOWTIME:CALL(ISEOL)		; no arguments allowed
	LBNF	CMDERR		; error if there are any
	CALL(SHOWNOW)		; show the current date/time
	LBR	TCRLF		; print a CRLF and return

; Here to show the current date/time....
SHOWNOW:RLDI(P1,TIMBUF)		; point to the six byte buffer
	CALL(F_GETTOD)		; ask the BIOS to read the clock
	LBDF	NOTIME		; no RTC or time not set
	RLDI(P1,CMDBUF)		; point to a temporary string
	RLDI(P2,TIMBUF)		; and point to the date buffer
	CALL(F_DTTOAS)		; convert the date to ASCII
	RLDI(P2,TIMBUF+3)	; point to the time buffer
	CALL(F_TMTOAS)		; and then conver the time
	OUTSTR(CMDBUF)		; print the date/time
	RETURN			; and we're all done

; Here if no RTC is installed or the clock is not set...
NOTIME:	BNZ	NOTSET
NORTC:	OUTSTR(RTCMS1)
	RETURN
NOTSET:	OUTSTR(RTCMS2)
	RETURN

	.EJECT
;	.SBTTL	Set Current Date and TIme

;   The "SET DA[TIME] mm/dd/yyyy hh:mm:ss" command sets the RTC clock to the
; date and time given.  Note that the syntax used for the date/time is exactly
; the same as the way it's printed by "SHOW DA[TIME]"...
SETTIME:CALL(F_LTRIM)	; ignore any leading spaces
	RLDI(0AH,TIMBUF); point to the time buffer
	CALL(F_ASTODT)	; try to parse an ASCII date
	LBDF	CMDERR	; branch if the format is illegal
	LDN	P1	; get the break character
	SMI	' '	; it had better be a space
	LBNZ	CMDERR	; bad date otherwise
;	CALL(F_LTRIM)	; skip the spaces
	CALL(F_ASTOTM)	; and now parse the time
	LBDF	CMDERR	; bad date
	CALL(ISEOL)	; that should be the end
	LBNF	CMDERR	; error if it isn't

; If all is well, proceed to set the time...
	RLDI(P1,TIMBUF)	; point to the tim buffer again
	CALL(F_SETTOD)	; set the clock
	LBDF	NOTIME	; branch if error
	CALL(SHOWNOW)	; echo the new time
	LBR	TCRLF	; finish the line and return...

; RTC mesages...
RTCMS1:	.DB	"?RTC NOT INSTALLED\r\n", 0
RTCMS2:	.DB	"?RTC NOT SET\r\n", 0

	.EJECT
;	.SBTTL	SHOW RTC Comand

;   This routine will dump all 128 bytes of the Elf 2000 disk board real
; time clock and non-volatile RAM chip.  It does this by reading the clock
; chip hardware directly and doesn't use the BIOS, so it's perfect for
; double checking that the software is doing what it's supposed to!
SHOWRTC:
	CALL(ISEOL)		; no arguments ...
	LBNF	CMDERR		; ...
	CALL(F_RTCTEST)		; is the RTC installed?
	LBNF	NORTC		; nope - quit now

; Type the detected NVR size, in bytes ...
	PUSHD			; save the size for a minute
	INLMES("NVR SIZE=")
	POPD			; recover the size
	PLO	P1		; ...
	LDI	0		; ...
	PHI	P1		; ...
	CALL(TDEC16)		; and type in decimal

; Type the computed NVR checksum ...
	INLMES(" CHECKSUM=")
	CALL(F_NVRCCHK)		; compute the actual checksum
	CALL(THEX4)		; print that
	CALL(TCRLF)		; and we're done

; Set the RTC to binary mode...
;	SEX	PC		; X=P
;	OUT	NVR_SELECT	; write the expansion board select register
;	.DB	$8B		; select RTC/NVR chip, register B
;	OUT	NVR_DATA	; then write the data
;	.DB	$07		; select 24hr, DST and binary mode

;   Now copy all 128 bytes of NVR to the disk buffer.  This includes the bytes
; in the clock/calendar chip and, if we happen to have a 64 byte chip, it
; actually copies everything twice (because the 64 byte chip doesn't decode
; A6!)....
	RLDI(P1,DSKBUF)		; point P1 to the disk buffer
RTDMP:	ORI	$80		; add the RTC select bit to the address
	SEX	SP		; point to the stack
	STR	SP		; and save the RTC register address
	OUT	NVR_SELECT	; write it to the register select port
	DEC	SP		; (OUT increments the SP)
	SEX	P1		; now point to the data buffer
	INP	NVR_DATA	; and read the addressed byte from NVR
	INC	P1		; increment the address for next time
	GLO	P1		; get the low byte of the address
	ANI	$7F		; have we done 128 bytes?
	LBNZ	RTDMP		; keep going until we have

; Now use the MEMDMP routine to dump out the DSKBUF that contains the RTC data.
	RLDI(P3,DSKBUF)		; first address to dump
	RLDI(P4,DSKBUF+$7F)	; last   "   "   "   "
	LBR	MEMDMP		; and print it in HEX and ASCII

	.EJECT
;	.SBTTL	SHOW DP and SHOW MEMORY Commands

;   The "SHOW DP" command dumps the monitor data page (all 256 bytes of it!).
; It's equivalent to "EXAMINE 7F00 7FFF" and is a handy shortcut for debugging.
DPDUMP:	CALL(ISEOL)
	LBNF	CMDERR
DDUMP1:	RLDI(P3,RAMPAGE)
	RLDI(P4,RAMPAGE+$FF)
	LBR	MEMDMP


;   The "SHOW MEMORY" command prints the number of bytes of free RAM, as
; returned by the BIOS F_FREEMEM routine...
SHOMEM:	CALL(ISEOL)		; no arguments allowed
	LBNF	CMDERR		; error if there's more
	CALL(F_FREEMEM)		; ask the BIOS to figure it out
;  The F_FREEMEM function actually returns the address of the last usable byte,
; which is one less than the actual number of free bytes!!
	INC	P1		; correct for that
	CALL(TDEC16)		; and type in decimal
	OUTSTR(FREMSG)		; finish the line and
	RETURN			; ... all done
FREMSG:	.TEXT	" bytes free\r\n\000"

	.EJECT
;	.SBTTL	SHOW TERMINAL Command

;   The "SHOW TERMINAL" command prints the current terminal settings (i.e.
; BAUD1 and BAUD0).  It doesn't bother to decode them for you, however!
; If BAUD.1 (register RE.1) is 0xFE, then the video card and PS/2 keyboard
; are in use as the console.  In that case, we report the version number
; of the firmware for those two components instead...
SHOTERM:CALL(ISEOL)		; no arguments
	LBNF	CMDERR		; ...
#ifdef VIDEO
	GHI	BAUD		; check for a video/PS2 console
	ANI	$FE		; ignore the echo bit
	XRI	$FE		; is it 0xFE?
	LBZ	SHOVID		; yep - go show video/PS2 version instead
#endif
	INLMES("BAUD1=0x")
	RLDI(DP,BAUD1)		; point to the values saved in memory
	LDA	DP		; and get BAUD1
	CALL(THEX2)		; type that in hex
	INLMES(" BAUD0=0x")
	LDA	DP		; and now BAUD0
	CALL(THEX2)		; ...
	LBR	TCRLF		; type CRLF and return

#ifdef VIDEO
;   Here if the video card and PS2 keyboard are in use.  Note that the name
; and copyright notice for the VT1802 firmware (but not the version!) are
; actually stored, in ASCII, in the VT1802 code.  The third entry point to
; the video module points at this text...
SHOVID:	RLDI(P2,VIDEO+7)	; point at the third vector
	SEX	P2		; ...
	POPR(P1)		; and then get the address of the notice
	CALL(F_MSG)		; print that
	CALL(TCRLF)		; and finish the line

; Now give the version of the PS/2 keyboard APU ...
	OUTSTR(PS2TX1)		; PS/2 keyboard APU
	RLDI(P1,PS2VER)		; this time the PS2 APU version
	LDN	P1		; ...
	PLO	P1		; ...
	LDI	0		; (these version are only 1 byte)
	PHI	P1		; ...
	CALL(TDEC16)		; type in decimal
	LBR	TCRLF		; and we're done

PS2TX1:	.TEXT	"PS/2 Keyboard APU Firmware V\000"
#endif

	.EJECT
;	.SBTTL	SHOW RESTART Command

; The "SHOW RESTART" command prints the current restart option and address...
SHORES:	CALL(ISEOL)		; no arguments allowed here!
	LBNF	CMDERR		; ...
	RLDI(DP,BOOTF)		; point to the boot flag
	LDN	DP		; get the restart option
	XRI	ABTDISK		; test for BOOT
	LBZ	RESBOO		; branch if BOOT
	LDA	DP		; get BOOTF again
	XRI	ABTADDR		; test for RESTART xxxx
	LBZ	RESADR		; handle that

; Here for RESTART NONE (or unknown) ...
RESHLT:	INLMES("NONE")
	LBR	TCRLF

; Here for RESTART xxxx ...
RESADR:	INLMES("RESTART @")
	SEX	DP		; use DP to address memory
	POPR(P1)		; and get the restart address
	CALL(THEX4)		; type that in hex
	LBR	TCRLF		; finish the line and return

; And here for RESTART BOOT ...
RESBOO:	INLMES("BOOT")
	LBR	TCRLF

	.EJECT
;	.SBTTL	SHOW CPU Command

;   The SHOW CPU command will figure out whether the CPU is an original
; 1802 or an 1805/6.  Better than that, if this system has the RTC/NVR
; (DS12887) option installed, this command will attempt to determine the
; CPU clock frequency.  This speed measurement is done with interrupts and
; DMA left ON, so it's especially handy if you're using the video card
; because it allows you to estimate the video display overhead.
;
;   BTW, the CPU speed is measured only if the RTC is present because we
; need the RTC's internal clock to give us a measurement of time that's
; independent of the CPU speed.  In principle there are other things that
; could be used as an independent time base (e.g. if the video card is
; installed you could use the VRTC, or you could even use the baud rate
; clock for the UART) but I'm too lazy to code all those options.
;
;   One more thing - in principle the 1804 is the same as the 1805/6, but
; the 1804 had on chip mask programmed ROM and I really doubt that anybody
; is using one of these.  AFAIK, there's no software way to distinguish any
; of the 1804, 1805, or 1806 processors.
SHOCPU:

;  The first thing is to figure out whether the CPU is an 1802 or the newer
; 1805/6.  This is pretty easy because the 1805/6 have additional two byte
; opcodes which use 0x68 as the prefix, and on the original 1802 opcode 0x68
; is a no-op.  So the two byte sequence 0x68, 0x68 is just two no-ops on the
; 1802, and on the 1805/6 it's the "RLXA 8" (register load via X and advance)
; instruction.
	PUSHR(8)		; save register 8 just in case it's important
	RCLEAR(P1)		; make P1 be zero
	SEX	P1		; and then use that for X
	.DB	68H, 68H	; then do "RLXA 8"
	SEX	SP		; back to the real stack
	IRX			; and restore R8
	POPRL(8)		; ...

;   If P1 is still zero, then the CPU is an 1802.  If P1 has been incremented,
; then the CPU is a 1805/6...
	GLO	P1		; let's see
	BZ	CPU02		; branch if it's a 1802
	INLMES("CDP1804/5/6")	; nope - it's a 1805/6 - lucky you!
	BR	SHOCP0		; then continue with the speed measurement
CPU02:	INLMES("CDP1802")	; a more traditional type
SHOCP0:	

;   See if the RTC is present and, if it is, then turn on the periodic divider
; chain and program it for 2Hz (500ms intervals).  Note that we don't enable
; either the square wave output or the interrupt output so nothing outside
; the RTC is affected, but we can still tell when the flag sets by watching 
; the PF bit in status register C.
	CALL(F_RTCTEST)		; is the NVR/RC chip present?
	LBNF	SHOCP9		; nope - just skip all this mess
	INLMES(" - SPEED=")
	RCLEAR(P1)		; clear P1 (we'll use this for counting, later)
	SEX	PC		; now we do a bunch of inline outputs
	WNVR(NVRA,DV1+$0F)	; turn on the divider and select 2Hz
	RNVR(NVRC)		; read register C to be sure PF is cleared

;   Now wait for the PF bit to set, just to be sure we're synchronized with
; the NVR clock.  The act of reading register C will clear the PF bit, so
; after we find it set we can wait for it to set again and have an exactly
; known interval...
SHOCP1:	SEX	PC		; RNVR does an inline OUT
	RNVR(NVRC)		; read register C
	ANI	PF		; is the PF bit set?
	BZ	SHOCP1		; nope - keep waiting

;   Now that we have a known real time interval, measuring the CPU clock is
; pretty simple.  We simply execute a loop that uses a known number of CPU
; cycles and count the iterations while we're waiting for the PF flag to
; set again.
;
;   But wait, let's think for a minute first.  Suppose we use a loop something
; like the one above (at SHOCP1).  This loop will take about 14 machine cycles,
; including an extra 2 for an "INC P1" instruction, or 112 clocks.  To convert
; the iteration count to megahertz we just need to multiply by 112 (number of
; clocks per iteration) and then by 2 (since we only count for 1/2 second).
; Easy enough on paper, but it will require a 16x16 bit --> 32 bit multiply
; operation and, worse yet, it'll require a 32 bit binary to decimal conversion
; in order to print the result.  All that on a 1802!  Just thinking about it
; makes me want to go lie down...
;
;   Suppose we were a little bit smarter and made the loop take 500 clocks
; instead of 112??  Then we'd have to multiply the iteration count by 500x2
; or 1000.  But wait, multiplying by 1000 is as easy as printing "000" after
; we type out the original count! No quad precision multiplication or division,
; and we can use the regular TDEC16 routine to print the result.  Alright!
;
;   But, it's not that easy.  On the 1802 the number of clocks per cycle is
; always 8 and we can't change that, so if we want the loop to take 500 clocks
; that means it has to take 500/8 = 62.5 machine cycles.  You aren't going to
; find any instruction that takes 0.5 machine cycles.  Bummer!
;
;   However, we can make a loop that takes 2000 clocks because 2000/8=125.
; For a given clock frequency, a loop that takes 2000 clocks will execute half
; as many times as one that takes 1000, so all we need to do is multiply the
; iteration count by 2 before we print it and we're set!
;
;   Now aren't you glad we thought about it first???
SHOCP2:	INC	P1		; [2] count iterations
	LDI	26		; [2] set up an inner delay loop
SHOC2A:	SMI	1		;   [2] count down
	BNZ	SHOC2A		;   [2]  ... until we get to zero
	BR	$+2		; [2] we need two more cycles
	NOP			; [3] plus three cycles for an odd total
	SEX	PC		; [2] do an inline OUT
	OUT	NVR_SELECT	; [2] select NVR register C
	.DB	NVRC		; [0]
	SEX	SP		; [2] point X at some RAM
	INP	NVR_DATA	; [2] and read register C
	ANI	PF		; [2] is the PF bit set yet?
	LBZ	SHOCP2		; [2] nope - keep waiting
				; Total = 26*4 + 9*2 + 3 = 125!!!

; All done, and the loop count is now in P1.
	SEX	PC		; before anything else 
	WNVR(NVRA,DV1)		;  ... turn off the divider chain again
	RSHL(P1)		; multiply P1 by 2
	CALL(TDEC16)		; and type the result
	INLMES("000")		; multiply by 1000
SHOCP9:	LBR	TCRLF		; finish the line and we're done!!!

	.EJECT
;	.SBTTL	The SHOW VERSION Command

;   The "SHOW VERSION" command prints (what else) the version numbers of the
; monitor and the BIOS along with a list of the features assembled into this
; BIOS...
SHOVER:	CALL(ISEOL)		; no arguments
	LBNF	CMDERR		; ...
	OUTSTR(VERM1)
	RLDI(P1,MONVER)		; print the EPROM version number
	CALL(TDEC16)		; always in decimal
	OUTSTR(VERM2)
	RLDI(DP,F_VERSION)	; point to the version number
	LDA	DP		; get the first byte
	PLO	P1		; and type it in decimal
	LDI	0		; (unfortunately it's only 8 bits)
	PHI	P1		; ...
	CALL(TDEC16)		; ...
	INLMES(".")		; ...
	LDA	DP		; second byte
	PLO	P1		; ...
	CALL(TDEC16)		; ...
	INLMES(".")		; ...
	LDA	DP		; and the third byte
	PLO	P1		; ...
	CALL(TDEC16)		; ...
	OUTSTR(VERM3)
	CALL(F_GETDEV)		; get supported devices
	CALL(THEX4)		; and type that in hexadecimal
	LBR	TCRLF		; all done!

; Messages....
VERM1:	.TEXT	"Monitor V\000"
VERM2:	.TEXT	" - BIOS V\000"
VERM3:	.TEXT	" features 0x\000"

	.EJECT
;	.SBTTL	VT1802 Video Terminal Test

#ifdef VIDEO
;   The "TEST VT1802" command displays a test pattern on the VT1802 screen.
; It's handy for adjusting the monitor, checking that all the video attributes
; work, viewing the complete character font, and little things like that...
VTTEST:	CALL(ISEOL)		; no more arguments allowed
	LBNF	CMDERR		; ...
	CALL(ISCRTC)		; is the video card installed?
	BDF	VTTES0		; yes - go ahead
	INLMES("?NO VIDEO")
	RETURN

;   The video test screen couldn't be easier, because all the real work is
; done by video.asm.  After the screen is displayed, we wait for any character,
; clear the screen, and then continue...
VTTES0:	OUTSTR(VTTMSG)		; display the test screen
	CALL(F_READ)		; wait for any character
	OUTSTR(CLSMSG)		; clear the screen
	RETURN			; and we're done

; Test messages...
VTTMSG:	.TEXT	"\033T\033Y2:[PRESS ANY KEY TO CONTINUE]\033Y3G\000"
CLSMSG:	.TEXT	"\033E\000"
#endif

	.EJECT
;	.SBTTL	SET NVR Command

;   The command "SET NVR DEFAULT" will return all NVR settings to their default
; values.  It's a useful way to get back to a known state after things have 
; been fiddled with.  When we get here, only the "SET NVR" part of the command
; has been parsed - before proceeding, we need to parse the "DEFAULT" part,
; even thought there is no other option.  It acts as a kind of confirmation -
; saying "SET NVR <anything else>" is an error...
SETNVR:	CALL(F_LTRIM)		; ignore any leading spaces
	CALL(ISEOL)		; and there'd bettter be more out there
	LBDF	CMDERR		; nope - error
	RLDI(P2,NVRCMD)		; point to the list of options
	LBR	COMND		; parse it and continue

;   Table of "SET NVR" arguments - currently there's only one!  Note that
; "DEFAULT" can't be abbreviated (it's a sort of safety feature).
NVRCMD:	CMD(7, "DEFAULT", NVRCLR)
	.DB	0

; Here when the command has been parsed...
NVRCLR:	CALL(ISEOL)		; this has to be the end
	LBNF	CMDERR		; ...

; Reset all the NVR locations (the ones we actually use, at least) to default.
	RLDI(P1,NVRBASE)	; offset of monitor data in NVR
	RLDI(P2,NVRDEFAULT)	; pointer to default NVR data in ROM
	RLDI(P3,NVRSIZE)	; count of bytes to write
	CALL(F_WRNVR)		; attempt to save it

;   Clear the BOOTF location in memory so that it agrees with what is now in
; NVR.  This isn't really necessary, but it ensures that if the user gives
; a "SHOW RESTART" command he'll actually see the correct value...
	RLDI(P1,BOOTF)		; where to store the data in SRAM
	LDI	0		; ...
	STR	P1		; ...

;   And lastly, although it isn't strictly necessary, trash the "key" that's
; stored in SRAM too.  This ensures that, if the SRAM battery backup is
; installed, it will also look uninitialized next time we reboot...
	RLDI(P1,KEY)		; point to the key
	LDI	0		; and trash it
	STR	P1		; just one byte is enough
	RETURN			; that's all!

	.EJECT
;	.SBTTL	Load Intel HEX Records

; Parse an Intel hex file record and, if it's valid, deposit it in memory...
;
;	P1   - pointer to CMDBUF (contains the HEX record)
;	P2   - Load address
;	P3.0 - record length
;	P3.1 - record type
;	P4.0 - record checksum (8 bits only!)

IHEX:	CALL(GHEX2)	; first two characters are the record length
	LBNF	CMDERR	; syntax error
	PLO	P3	; save the record length in P2.0
	CALL(GHEX4)	; the next four characters are the load address
	LBNF	CMDERR	; syntax error
;	RCOPY(P3,P2)	; save the load address in P3
	CALL(GHEX2)	; and the next two characters are the record type
	PHI	P3	; save that just in case we need it

; The only allowed record types are 0 (data) and 1 (EOF)....
	LBZ	IHEX1	; branch if a data record
	ADI	$FF	; is it one?
	LBZ	IHEX4	; yes - EOF record

; Here for an unknown record type...
	OUTSTR(URCMSG)
	RETURN

;   For a data record, check the address and be sure that it's not on the
; monitor's data page.  Downloading the monitor's data page could corrupt
; the stack, the command line buffer, and cause all sorts of confusion!
IHEX1:	GHI	P2	; get the high byte of the address
	SMI HIGH(RAMPAGE); is it the same as the monitor's data page?
	LBNZ	IHEX1A	; nope - keep going
	OUTSTR(OVMMSG)	; ?WOULD OVERWRITE MONITOR
	RETURN		; yes - refuse to load it

;   Here for a data record - begin by accumulating the checksum.  Remember
; that the record checksum includes the four bytes (length, type and address)
; we already read, although we can safely skip the record type since we know
; it's zero!
IHEX1A:	GLO	P3	; get the record length
	STXD		; push in on the stack for a moment
	GHI	P2	; and the high address byte
	STR	SP	; stack it too
	GLO	P2	; now the low address byte
	ADD		; add the high address byte
	IRX		; ...
	ADD		; and add the record length
	PLO	P4	; accumulate the checksum here

; Now read the number of data bytes specified by P3.0...
IHEX2:	GLO	P3	; any more bytes to read???
	LBZ	IHEX3	; nope - test the checksum
	CALL(GHEX2)	; yes - get another data value
	LBNF	CMDERR	; syntax error
	STR	SP	; save the byte on the stack for a minute
	GLO	P4	; and accumulate the checksum
	ADD		; ...
	PLO	P4	; ...
	LDX		; get the data again
	STR	P2	; and store it in memory at the record address
	LDA	P2	; get the byte we just stored and advance P3
	SM		; did memory really change
	LBNZ	IHEX5	; memory error
	DEC	P3	; count another byte read
	LBR	IHEX2	; and keep going

; Here when we've read all the data - verify the checksum byte...
IHEX3:	CALL(GHEX2)	; one more time
	LBNF	CMDERR	; synxtax error
	STR	SP	; save checksum byte on the stack
	GLO	P4	; get the running total so far
	ADD		; that plus this should be zero
	LBNZ	IHEX6	; checksum error
	INLMES("OK\r\n"); successful (believe it or not!!)
	RETURN

; Here for an EOF record...
IHEX4:	INLMES("EOF\r\n")
	RETURN

;   Here if the memory doesn't change - that could be because the .HEX
; file attempted to load into EPROM or non-existent memory...
IHEX5:	OUTSTR(MERMSG)
	RETURN

;   And here if the record checksum doesn't add up.  Ideally we should just
; ignore this entire record, but unfortunatley we've already stuffed all or
; part of it into memory.  It's too late now!
IHEX6:	OUTSTR(HCKMSG)
	RETURN

; HEX file parsing messages ...
HCKMSG:	.TEXT	"?CHECKSUM MISMATCH\r\n\000"
URCMSG:	.TEXT	"?UNKNOWN HEX RECORD TYPE\r\n\000"
OVMMSG:	.TEXT	"?WOULD OVERWRITE MONITOR\r\n\000"

	.EJECT
;	.SBTTL	Continue Execution after a Break Point

;   This routine handles the CONTINUE command which will attempt to restore
; the original user's context at the time of a break point and continue exec-
; ution at the next step.  It'll actually work (believe it or not!) provided
; the user's program meets all the necessary restrictions: 1) the contents
; of R0 and R1 are not restored, 2) interrupts are disabled, and 3) there
; must be a valid stack pointer in R2...
CONTINUE:
	CALL(ISEOL)		; there are no arguments to this command
	LBNF	CMDERR		; ...
#ifdef VIDEO
	CALL(NOCRTC)		; not allowed when the video card is active
	LBDF	CONT0		;  ...
#endif
	RLDI(1,CONT1)		; use R1 as the PC from now on
	SEP	1		; ...
CONT0:	RETURN			; here if error

; Here to restore the user's registers R2 thru RF...
CONT1:	RLDI(0,REGS+4)		; point R0 at the saved registers
	SEX	0		; use that as a stack pointer
	POPR(2)			; ...
	POPR(3)			; ... 
	POPR(4)			; ...
	POPR(5)			; ...
	POPR(6)			; ...
	POPR(7)			; ...
	POPR(8)			; ...
	POPR(9)			; ...
	POPR($A)		; ...
	POPR($B)		; ...
	POPR($C)		; ...
	POPR($D)		; ...
	POPR($E)		; ...
	POPR($F)		; ...

;   Now recover (X,P), D and DF.  Unfortunately the only way to do this is to
; temporarily push them on the user's stack first, which works so long as
; R2 points to a valid stack...
	RLDI(0,SAVEXP)		; point R0 at (X,P), D and DF...
	LDXA			; get (X,P)
;  Note that the final instruction we execute, DIS (or RET - it doesn't matter)
; is a little backwards in that it does M(R(X))->(X,P) FIRST, and then R(X)+1
; second.  So we have to decrement the user's stack pointer first, which has
; the effect of wasting a byte, so that in the end it comes out right.
	DEC	2		; and save them on the user's stack
	STR	2		; ...
	LDXA			; now load D from SAVED
	DEC	2		; and temporarily save that ...
	STR	2		; ... on the user's stack
	LDXA			; and finally load SAVEDF
	SHRC			; restore DF
	SEX	2		; switch to the user's stack
	LDXA			; and restore D

;  The last instruction is a minor trick - we have to restore (X,P) from the
; user's stack while at the same time leaving R1 (our current PC) pointing
; to TRAP:.  The contents of R0 are never restored...
;;RLA;;	RCLEAR(0)		; always clear R0 for Tiny BASIC
	LBR	TRAPX		; go restore (X,P)

	.EJECT
;	.SBTTL	Save User Context after Breakpoint

;   Whenever the monitor starts a user program running, it will initialize R1
; with the address of this routine.  Provided that the user program does not 
; use R1 or R0 for anything, a break point can be placed in the program with a
; two byte sequence:
;
;	MARK	; $79
;	SEP  R1	; $D1
;
; R1, as you may remember, normally points to an  interrupt service routine
; and R0 is the DMA pointer.  This code will save all of the users registers,
; except R0, R1, but it does mange to save X, P, D and DF...

;   The CONTINUE command (read on - it's coming up in a page or two!) branches
; here as the final step in restoring the user's context.  This restores the
; original X and P registers while leaving R1 pointing at TRAP: once again..
TRAPX:	DIS		; restore (X,P) and turn interrupts off

;   Save the current D and DF by assuming that there's a valid stack pointer
; (and that it points to a valid stack!) in R(2)...  The MARK instruction
; executed by the caller already pushed (X,P)...
TRAP:	SEX	2	; and assume there's a stack pointer in R(2)
	STXD		; save D assuming that the user has a valid stack
	LDI	0	; put DF into the LSB of D
	SHLC		; ...
	STR	2	; and then save that too

; Save registers R(F) thru R(2) in memory at REGS:...
	RLDI(R0,REGS+32-1)
	SEX	0
	PUSHR($F)
	PUSHR($E)
	PUSHR($D)
	PUSHR($C)
	PUSHR($B)
	PUSHR($A)
	PUSHR(9)
	PUSHR(8)
	PUSHR(7)
	PUSHR(6)
	PUSHR(5)
	PUSHR(4)
	PUSHR(3)
	PUSHR(2)

;   The next two registers, R1 and R0, don't really contain useful data but
; we need to skip over those before we can save D, DF and X...
	LDI	00
	STXD\ STXD	; save R1 as all zeros
	STXD\ STXD	; and save R0 as all zeros

; Recover DF, D and X from the user's stack and save them in our memory...
	LDN	2	; get the DF
	STXD		; store that at SAVEDF:
	INC	2	; ..
	LDN	2	; then get D
	STXD		; and store that at SAVED:
	INC	2	; and lastly get X
	LDN	2	; ...
	STXD		; and store it at SAVEXP:

;   Finally, update the value of register 2 that we saved so that it shows the
; current (and correct) value, before we pushed three bytes onto the stack...
	RLDI(R0,REGS+5)
	PUSHR(2)

;   We're all done saving stuff - now intialize enough of the real monitor
; context so that things will work (e.g. OUTCHR, THEX4, etc)...
	RLDI(SP,STACK)		; initialize the stack
	RLDI(A,TRAP2)		; continue processing from TRAP2:
	LBR	F_INITCALL	; and initialize the SCRT routines

;   We get here once all the context has been saved after a breakpoint.
; At this time the normal BOOTS context has been re-established and things
; should work pretty much as we expect.  Nwo we type out the user's registers
; (the same as the "SHOW REGISTERS" command) and then rejoin the main monitor
; loop...
TRAP2:	CALL(TTYINI)		; reset the terminal baud rate
	CALL(SHORE1)		; print the registers 
	LBR	MAIN		; and go print a monitor prompt
	.EJECT
;	.SBTTL	Display the User Context after a Break

;   This routine will display the contents of the user's registers that were
; saved after the last break point.  It's used by the "SHOW REGISTERS" command,
; and also is called directly whenever a break point is encountered.

; Here for the "SHOW REGISTERS" command...
SHOREG:	CALL(ISEOL)		; should be the end of the line
	LBNF	CMDERR		; error if not
; Fall into SHORE1 ....

; Here to display the registers after a break point....
SHORE1:	RLDI(DP,SAVEXP)		; point DP at the user's context info
	OUTSTR(BPTMSG)		; print "BREAKPOINT ..."

; Print a couple of CRLFs and then display X, D and DF...
	INLMES(" @ XP=")	; ...
	SEX	DP		; get the value of (X,P)
	LDXA			; ...
	CALL(THEX2)		; ...
	INLMES(" D=")		; ...
	SEX	DP		; now display D
	LDXA			; ...
	CALL(THEX2)		; that's easy
	INLMES(" DF=")		; ...
	SEX	DP		; and lastly get DF
	LDXA			; it should be just one bit
	CALL(THEX1)		; but it's already positioned correctly
	CALL(TCRLF)		; finish that line

;   Print the registers R(0) thru R(F) (remembering, of course, that R0 and
; R1 aren't really valid) on four lines, four registers per line...
	LDI	0		; start counting the registers
	PLO	P3		; here...
TRAP2A:	OUTCHR('R')		; type "Rn="
	GLO	P3		; get the register number
	CALL(THEX1)		; ...
	OUTCHR('=')		; ...
	SEX	DP		; now load the register contents from REGS:
	LDXA			; high byte first
	PHI	P1		; ...
	LDXA			; then low
	PLO	P1		; ...
	CALL(THEX4)		; type the value
	CALL(TTABC)		; finish with a tab
	INC	P3		; on to the next register
	GLO	P3		; get the register number
	ANI	$3		; have we done a multiple of four?
	LBNZ	TRAP2A		; nope - keep going

; Here to end the line...
	CALL(TCRLF)		; finish off this line
	GLO	P3		; and get the register number again
	ANI	$F		; have we done all sixteen??
	LBNZ	TRAP2A		; nope - not yet
	LBR	TCRLF		; yes - print another CRLF and return

; Messages...
BPTMSG:	.TEXT	"\r\nBREAKPOINT \000"

	.EJECT
;	.SBTTL	PIXIE Test Command

#ifdef PIXIE
;   The EF1 test ensures that the CDP1861 chip is isntalled and that it's
; counter chain is running at something like the correct rate.  Remember
; that the 1861 asserts EF1 at the end of every scan line, and this test
; works because the 1861 divider chain and the EF1 output continue to run
; all the time, regardless of whether the video or DMA is enabled or not.
PIXTEST:CALL(ISEOL)		; there should be no more text
	LBNF	CMDERR		; ... after the command
#ifdef VIDEO
	CALL(NOCRTC)		; not allowed if the real video card is active
	BNF	PIXIE0		; Ok - go start
	RETURN			; not OK - give up now
#endif
PIXIE0:	PIXIE_ON		; enable the display 
	INLMES("EF1 ... ")

;   Count the number of cycles in a complete period, low then high then
; low again, in EF1.  If the count overflows, then something's wrong...
EF1T1:	RLDI(P1,$FFFF)		; initialize P1 to $FFFF
EF1T2:	B1	EF1T3		; wait for the positive edge on EF1
	DEC	P1		; count down as we wait
	GHI	P1		; have we waited too long?
	BNZ	EF1T2		; nope - keep waiting
	RLDI(P1,NO1861)		; no CDP1861 detected\r\n
	LBR	F_MSG		; just give up if there's no chip

; Count for a complete cycle (both high and low parts) of EF1...
EF1T3:	RCLEAR(P1)		; found the rising edge - reset the counter
EF1T4:	INC	P1		; count while we wait
	B1	EF1T4		; and keep counting 'till the falling edge
EF1T5:	INC	P1		; keep counting for the low part of EF1
	BN1	EF1T5		; and keep counting 'till the rising edge

;   Empirically, this should give a count somewhere between 440 and 475 in
; P1.  Since the CDP8161 shares the same oscillator as the CPU, this count
; is independent of the crystal frequency and (sadly) can't be used to detect
; whether the wrong crystal is installed.
	CALL(TDEC16)
	INLMES(" OK\r\n");
	OUTSTR(VIDMSG)

; For the "special" CHM mode startup, we jump here directly from SYSINI.
PIXCHM:	RLDI(INTPC,INT1PG)	; ISR -> 64x32 video interrupt service routine
	RLDI(P1,NCC1701)	; P1 -> bitmap to display
;	RLDI(P1,INT1RT)

; Turn on the display and hold your breath!!!
	INT_ON			; interrupts on
	PIXIE_ON		; and enable the display
PIXIE1:	;CALL(F_BRKTEST)	; check for a break on the console
	;BDF	PIXIE2		; yes - quit now
	BN4	PIXIE1		; or break when INPUT is pressed
PIXIE2:	PIXIE_OFF		; turn the display off
	INT_OFF			; now disable interrupts again
	LBR	TCRLF		; finish the line and back to the monitor

; Messages...
NO1861:	.TEXT	"?NO CDP1861 DETECTED\r\n\000"
VIDMSG:	.TEXT	"The COSMAC Elf Enterprise - Joeseph Weisbecker P-E 1976\r\n"
	.TEXT	"[Toggle INPUT to end]\000"
#endif

	.EJECT
;	.SBTTL	Video (CDP1861) Interrupt Service routines

#ifdef PIXIE
;   This is the classic CDP1861 interrupt service routine for 64x32 resolution
; displays, stolen right out of the CDP1861 data sheet.  Yes, that's 64 pixels
; by 32 pixels, for a whopping total of 256 bytes (1 page!) of display memory.
; The background code must keep a display buffer pointer in P1 while this code
; is active - at the start of every new frame it will re-initialize the DMA
; register (R0) from P1.  Of course, nothing prevents the background code from
; changing P1 betwen frames; this allows for scrolling or animation effects.
INT1RT:	LDXA			; restore the D register from the stack
	RET			; and return from the interrupt
				;  ... while leaving R1 pointing to INT1PG!
;   A reasonable person might ask how this works - in principle it's very easy;
; we simply repeat each scan line (consisting of 64 pixels or 8 bytes) a total
; of four times, thus reducing the native 1861 vertical resolution from 128 to
; 32 lines.  The puzzling thing is that there's no flag or other test to find
; the start of a scan line - the code simply "knows" when it happens.  This
; works because the 1861 clock is locked to the 1802's and every scan line
; simply locks out the processor completely (i.e. no 1802 instructions get
; executed!) while the 1861 uses DMA to fetch 8 bytes.  By very carefully count-
; int cycles, this code always stays synchronized with the 1861.
INT1PG:	NOP			; correct for the S3 (interrupt ACK) timing
	DEC	SP		; make a space on the stack
	SAV			; and push T (the saved X,P)
	DEC	SP		; make another spot
	STR	SP		; and now save the D register too
	RCOPY(DMAPTR,P1)	; copy R0 <= P1
	NOP\ NOP		; correct the timing
DSP1PG:	SEX	SP		; two cycle delay (NOP is 3 cycles!)
	GLO	DMAPTR		; save start of line address in D
	SEX	SP		; (the 1861 DMAs 8 bytes now!!!)
	DEC	DMAPTR		; reset R0.1 if we passed a page
	PLO	DMAPTR		; and reset R0.0
	SEX	SP		; do it all over again
	DEC	DMAPTR		; ...
	PLO	DMAPTR		; ...
	SEX	SP		; and one more time!
	DEC	DMAPTR		; ...
	PLO	DMAPTR		; ...
	BN1	DSP1PG		; keep going until the end of frame
;   At the end of each frame (when the timing is no longer critical!)
; increment the vertical retrace counter (CRTC) in the monitor's data
; page.  This can be used to count frames and keep track of the time
; of day, and it also serves as a simple "video running" test.  Note
; that since the 1861 is done for a while, it's safe to use DMAPTR to
; address memory.  This saves the need to store another register on
; the stack!  Sadly, there's no way to increment the byte without also
; trashing DF, which isn't cool, so we have to save and restore that bit
; too...
;	SHLC			; DF -> LSB of D
;	DEC	SP		; stack DF too
;	STR	SP		; ...
;	RLDI(DMAPTR,VRTC)	; point to the vertical retrace counter
;	LDA	DMAPTR		; get the current value
;	DEC	DMAPTR
;	SMI	59		; have we done sixty frames?
;	BNF	INT2		; store zero if yes
;	ADI	59+1		; restore and increment the count
;INT2:	STR	DMAPTR		; put the count back in memory
;	LDXA			; retrieve DF from the stack
;	SHRC			; and restore it
	BR	INT1RT		; and return when the frame is finished
#endif

	.EJECT
;	.SBTTL	Help Command

;   The HELP command prints a canned help file, which is stored in EPROM in
; plain ASCII.  If the current console is a VT1802, then we do some extra
; work to paginate the output in the style of the Un*x "more" command - this
; prevents the good stuff from scrolling off the top of the screen before
; you can see it!
PHELP:	CALL(ISEOL)		; HELP has no arguments
	LBNF	CMDERR		; error if it does
#ifdef VIDEO
	CALL(ISCRTC)		; is the VT1802 in use ??
	LBDF	PHELP0		; branch if so
#endif
	RLDI(P1,HELP)		; nope - just print the whole text
	LBR	F_MSG		; ... print it and return

#ifdef VIDEO
;  We get here if the VT1802 video terminal is in use as the console.
PHELP0:	RLDI(P2,HELP)		; point to the help text
PHELP1:	LDI	0		; keep count of the number of lines
	PLO	P3		;  ... here ...
PHELP2:	LDA	P2		; get a byte from the message
	LBZ	PHELP9		; quit at the end of the string
	CALL(F_TTY)		; type it out
	XRI	CHLFD		; was it a line feed?
	BNZ	PHELP2		; nope - nothing special

; Count the lines ...
	INC	P3		; count the lines
	GLO	P3		; ...
	SMI	23		; have we done a full screen?
	BL	PHELP2		; nope - keep going just the same

; We've done a full screen - say MORE and wait for input...
	OUTSTR(MORMSG)		; "--More--"
	CALL(F_READ)		; wait for input
	XRI	CHCTC		; is it a Control-C ??
	LBZ	PHELP9		; yes - just quit now
	OUTSTR(EELMSG)		; nope - erase the More message
	LBR	PHELP1		; and keep typing

; Here when we're done...
PHELP9:	OUTSTR(EELMSG)
	RETURN

; Messages...
MORMSG:	.TEXT	"          \033N@\015\033NP--More--\000"
EELMSG:	.TEXT	"\015\033K\000"
#endif
#ifndef HELP
HELP:	.TEXT	"?NO HELP\000"
#endif

	.EJECT
;	.SBTTL	Clear Screen Command

;  This little command clears the screen on the VT1802.  All it really
; has to do is to send the right escape sequence to the VT1802 firmware -
; all the rest is just a matter of parsing the command line...
#ifdef VIDEO
CLSCMD:	CALL(ISEOL)		; no arguments allowed
	LBNF	CMDERR		; quit if it's wrong
	CALL(ISCRTC)		; and the VT1802 has to be in use
	LBNF	CMDERR		; just ignore it if not
	OUTSTR(CLSMSG)		; the rest is easy
	RETURN			; ...
#endif

	.EJECT
;	.SBTTL	Exhaustive Memory Test

;   This routine will perform an exhaustive test on memory using the "Knaizuk
; and Hartmann" algorithm (Proceedings of the IEEE April 1977).  This algorithm
; first fills memory with all ones ($FF bytes) and then writes a byte of zeros
; to every third location.  These values are read back and tested for errors,
; and then the procedure is repeated twice more, changing the positon of the
; 00 bytes each time.  After that, the entire algorithm is repeated three
; more times, this time using a memory fill of $00 and every third byte is
; written with $FF.  Strange as it may seem, this test can actually detect
; any combination of stuck data and/or stuck address bits.  Each pass (six
; iterations) requires about 30 seconds for 32K RAM on a 1.7Mhz CDP1802.
;
; Register usage:
;	P2   = memory address
;	P3.1 = filler byte
;	P3.0 = test byte
;	P4.0 = modulo 3 counter (current)
;	P4.1 = iteration number (modulo 3 counter for this pass)
;
; NOTE
;   The memory test assumes that the monitor's data page occupies the top 256
; bytes of memory and it tests all memory from $0000 to RAMPAGE-1.

; RAM test messages...
RTSMSG:	.TEXT	"Testing RAM \000"
REAMSG:	.TEXT	"\r\n?RAM ERROR AT \000"

; Start the memory test ...
RAMTEST:CALL(ISEOL)		; there should be no more text
	LBNF	CMDERR		; ... after the command		
	CALL(CLRPEK)		; clear PASSK and ERRORK

;   It's not safe to test the monitor's RAM page, nor is it a good idea to
; scribble over the frame buffer if the video card is active.  Compute the
; top of RAM as either RAMPAGE or SCREEN and push it onto the stack...
#ifdef VIDEO
	CALL(ISCRTC)		; is the video card active?
	BDF	RAMTE0		; yes - test only up to SCREEN
#endif
	LDI	HIGH(RAMPAGE)	; nope - test all the way up to RAMPAGE
#ifdef VIDEO
	BR	RAMTE1		; ...
RAMTE0:	LDI	HIGH(SCREEN)	; put the memory size on the stack
#endif
RAMTE1:	STXD			; ...
	CALL(PRTSBM)		; print the memory size 
				;  ... and "press BREAK to abort"

; Here to start another complete pass (six iterations per pass)...
RAMT0:	OUTSTR(RTSMSG)		; "Testing RAM "
	RLDI(P3,$FF00)		; load the first test pattern
RAMT0A:	LDI	2		; initialize the modulo 3 counter
	PHI	P4		; ...

; Loop 1 - fill memory with the filler byte...
RAMT1:	SEX	SP		; point at the stack
	IRX			; point to the memory size on the TOS
	LDX			; get that
	SMI	1		; minus 1
	PHI	P2		; and point P2 at the top of memory
	DEC	SP		; protect the TOS
	LDI	$FF		; and the low byte is always FF
	PLO	P2		; ...
RAMT1A:	GHI	P3		; get the filler byte
	SEX	P2		; and use P2 to address memory
	STXD			; and store it
	GHI	P2		; check the high address byte
	ANI	$80		; have we rolled over from $0000 to $FFFF?
	LBZ	RAMT1A		; nope - keep filling
	CALL(F_BRKTEST)		; does the user want to stop now?
	LBDF	MAIN		; yes - quit now

; Loop 2 - fill every third byte with the test byte...
RAMT2:	RCLEAR(P2)		; this time start at $0000
	GHI	P4		; reset the modulo 3 counter
	PLO	P4		; ...
RAMT2A:	GLO	P4		; get the modulo 3 counter
	LBNZ	RAMT2B		; branch if not the third iteration
	GLO	P3		; third byte - get the test byte
	STR	P2		; and store it in memory
	LDI	3		; then re-initialize the modulo 3 counter
	PLO	P4		; ...
RAMT2B:	DEC	P4		; decremement the modulo 3 counter
	INC	P2		; and increment the address
	GHI	P2		; get the high address byte
	SEX	SP		; point at the stack
	IRX			; point to the memory size on the TOS
	XOR			; are they equal?
	DEC	SP		; (protect the TOS)
	LBNZ	RAMT2A		; nope - keep going
	CALL(F_BRKTEST)		; does the user want to stop now?
	LBDF	MAIN		; yes - quit now

; Loop 3 - nearly the same as Loop2, except this time we test the bytes...
RAMT3:	RCLEAR(P2)		; start at $0000
	GHI	P4		; reset the modulo 3 counter
	PLO	P4		; ...
RAMT3A:	GLO	P4		; get the modulo 3 counter
	LBNZ	RAMT3B		; branch if not the third iteration
	LDI	3		; re-initialize the modulo 3 counter
	PLO	P4		; ...
	GLO	P3		; and get the test byte
	SKP			; ...
RAMT3B:	GHI	P3		; not third byte - test against fill byte
	SEX	P2		; address memory with P2
	XOR			; does this byte match??
	LBZ	RAMT3C		; branch if success

; Here if a test fails...
	OUTSTR(REAMSG)
	RCOPY(P1,P2)
	CALL(THEX4)
	CALL(TCRLF)
	CALL(INERRK)

; Here if the test passes - on to the next location...
RAMT3C:	DEC	P4		; decremement the modulo 3 counter
	INC	P2		; and increment the address
	GHI	P2		; get the high address byte
	SEX	SP		; address the stack
	IRX			; point to the memory size on the TOS
	XOR			; are they equal??
	DEC	SP		; (protect the TOS)
	LBNZ	RAMT3A		; nope - keep going
	CALL(F_BRKTEST)		; does the user want to stop now?
	LBDF	MAIN		; yes - quit now

; This pass is completed - move the position of the test byte and repeat...
	OUTCHR('.')
	GHI	P4		; get the current modulo counter
	SMI	1		; decrement it
	BL	RAMT4		; branch if we've done three passes
	PHI	P4		; nope - try it again
	LBR	RAMT1		; and do another pass

;   We've done three passes with this test pattern.  Swap the filler and
; test bytes and repeat...
RAMT4:	GLO	P3		; is the test byte $00??
	LBNZ	RAMT5		; nope - we've been here before
	RLDI(P3,$00FF)		; yes - use 00 as the fill and FF as the test
	LBR	RAMT0A		; reset the modulo counter and test again

; One complete test (six passes total) are completed..
RAMT5:	CALL(INPASK)		; increment PASSK
	CALL(PRTPEK)		; print the pass/error count
	CALL(TCRLF)		; finish the line
	LBR	RAMT0		; and go start another pass

	.EJECT
;	.SBTTL	Diagnostic Support Routines

; We assume these two items are in order!
#if ((ERRORK-PASSK) != 2)
	.ECHO	"**** ERROR **** PASSK/ERRORK out of order!"
#endif

;   This little routine will clear the current diagnostic pass and error
; counts (PASSK: and ERRORK:).  It's called at the start of most diagnostics.
CLRPEK:	LDI	LOW(PASSK+3)	; PASSK is first, then ERRORK
	PLO	DP		; ...
	SEX	DP		; ...
	LDI	0		; ...
	STXD\ STXD		; clear ERRORK
	STXD\ STXD		; and clear PASSK
	RETURN			; all done

; Incrememnt the current diagnostic pass counter...
INPASK:	LDI	LOW(PASSK+1)	; point to the LSB first
	LSKP			; and fall into INERRK...

; Increment the current diagnostic error counter...
INERRK:	LDI	LOW(ERRORK+1)	; point to ERRORK this time
	PLO	DP		; ...
	SEX	DP		; ...
	LDX			; get the lest significant byte
	ADI	1		; increment it
	STXD			; and put it back
	LDX			; now get the high byte
	ADCI	0		; include the carry (if any)
	STR	DP		; put it back
	RETURN			; and we're done

; Print the current diagnostic pass and error count...
PRTPEK:	INLMES(" Pass ")
	LDI	LOW(PASSK)	; point DP at the pass counter
	PLO	DP		; ...
	SEX	DP		; and use DP to address memory
	POPR(P1)		; load PASSK into P1
	DEC	DP		; point at the low byte again
	OUT	LEDS		; display the pass count on the LEDs
	CALL(TDEC16)		; print the pass count in decimal
	INLMES(" Errors ")	; ...
	SEX	DP		; (SCRT changes X!)
	POPR(P1)		; and now get ERRORK
	LBR	TDEC16		; print that and return

; Print memory size and break message...
PRTSBM:	PUSHD			; save the upper byte of the size
	INLMES("Testing ")
	POPD			; and get the number of pages back
	PHI	P1		; into P1
	LDI	0		; the bottom byte is always zero
	PLO	P1		; ...
	CALL(TDEC16)		; type the memory size
	OUTSTR(RTMSG1)
	LBR	TCRLF

; Messages (some) ...
RTMSG1:	.TEXT	" bytes - press BREAK to abort\000"

	.EJECT
;	.SBTTL	Initialize the Console Terminal

;   This routine will (re) initialize the console terminal.  It first restores
; the contents of BAUD1 to the upper byte of register E.  The low order bit of
; this value is the local echo flag and is ignored, however the rest of it is
; the software bit rate for the bit banging console and is non-zero any time
; the software serial console is in use.
;
;   If the software baud rate is zero, then this routine examines BAUD0 for a
; non-zero value and, if it finds one, the UART is being used for a console
; terminal. This byte represents the hardware UART settings and the console baud
; rate is restored by a call to F_SETBD).
;
;   If BAUD1 is 0xFE (again, ignoring the LSB local echo bit) then the PS/2
; keyboard and 80 column video card are in use as the console and we don't
; need to do anything further (beyond restoring RE.1) to enable the console.
;
;   If BAUD0 and BAUD1 are both zero, or if both are $FF, then the NVR has been
; (re)initialized and we need to autobaud again.  Once the autobaud is done the
; serial parameters are saved in BAUD0/1, and in NVR if present, for next time.

TTYINI:
;   If BOTH the GPIO PS/2 interface and the 80 column video card are installed
; on this system then we always use them for the console, no matter what UARTs
; or NVRs or whatever else may be installed.
#ifdef ELF2K
	RLDI(P1,PS2VER)		; point to the PS/2 keyboard status
	SEX	P1		; ...
	LDXA			; load the PS/2 version
	BZ	TTYIN0		;  if it's zero then there's no PS2 keyboard
	LDX			; now get the video card version
	BZ	TTYIN0		;  if that's zero then there's no video card
	RLDI(BAUD,$FF00)	; force the BIOS to use the PS2/video
	LBR	TTYAU1		; save that in BAUD1/0 and return
#endif

;   If there's an NVR (aka CMOS) on this system, then attempt to reload
; BAUD1 and BAUD0 from CMOS.  Note that if this doesn't work (no NVR or the
; NVR contents are invalid) then BAUD1 and BAUD0 in RAM will be unchanged.
TTYIN0:	RLDI(P1,NVRBAUD)	; offset of baud rate data in NVR
	RLDI(P2,BAUD1)		; pointer to data area in main SRAM
	RLDI(P3,2)		; count of bytes to read
	CALL(F_RDNVR)		; attempt to read NVR first
; We don't care whether this works or not!

; Reload the baud registers from memory...
	RLDI(DP,BAUD1)		; point to BAUD1 first
	LDA	DP		; and get it
	PHI	BAUD		; reload that register
;   If BAUD.1 is $FE or $FF, then either the RAM/NVR was initialized, OR the
; PS/2 keyboard and 80 column video card was in use last time.  Either way,
; we need to autobaud now.  Likewise, if BAUD.1 is zero then either the RAM/NVR
; was initialized OR the hardware UART was in use last time around ...
	ANI	$FE		; ignore the local echo bit
	LBZ	TTYIN1		; branch if we need to try the UART
	XRI	$FE		; test for $FF or $FE
	LBZ	TTYAUT		; branch if we need to autobaud
; Otherwis the software serial console was in use last time around ...
	RETURN			; there's nothing more to do!

;   Here if BAUD1 is zero; now check BAUD0.  If the latter is nonzero then the
; UART was in use last time.  We need to make sure the UART is still present
; and, provided that it is, restore the UART settings.  If both BAUD1 and BAUD0
; are zero, then the NVR/RAM was just initialized and we need autobaud ...
TTYIN1:	LDA	DP		; load BAUD0 next
	PLO	P1		; save it for a minute
	LBZ	TTYAUT		; if both are zero, then autobaud
	RLDI(DP,UARTOK)		; check the UART flag
	LDN	DP		; ... to see if the UART is installed
	LBZ	TTYAUT		; go autobaud if it isn't
	GLO	P1		; get the UART settings back
	LBR	F_USETBD	; and re-initialize the hardware UART settings

;   Here if there's no record of which UART was in use; we'll have to call the
; BIOS auto baud routine to determine which port and what speed.  Note that
; this label can also be used as an alternate entry point to force an autobaud
; regardless of the current settings!
TTYAUT:	OUTI(LEDS,$16)		; show "16" on the data LEDs
	CALL(F_SETBD)		; and then let the BIOS auto baud
TTYAU1:	RLDI(DP,BAUD1)		; (F_SETBD trashes DP!)
	GHI	BAUD		; store BAUD1
	STR	DP		; ...
	INC	DP		; and store BAUD0 too
	GLO	P1		; ...
	STR	DP		; ...

;   And lastly, if there is a NVR/CMOS on this system, attempt to save the UART
; settings for next time around!
	RLDI(P1,NVRBAUD)	; offset of baud rate data in NVR
	RLDI(P2,BAUD1)		; pointer to data area in main SRAM
	RLDI(P3,2)		; count of bytes to write
	LBR	F_WRNVR		; attempt to save it and return

	.EJECT
;	.SBTTL	Elf Video Card and PS/2 Keyboard Routines

;   This routine will return with DF=1 if the Elf 2000 video board is
; installed and active and DF=0 if it is not.  Note that "installed and
; active" doesn't necessarily mean that the video is being used as the
; console - if there's no PS/2 keyboard present, then it's possible for
; the video to be active even though the UART is used as the console.
;
;   Why is this important?  Well, the video requires that interrupts and
; DMA be in constant use so that it can refresh the display and that's
; incompatible with some monitor commands (e.g. RUN, break points, CONTINUE,
; etc).
#ifdef VIDEO
ISCRTC:	RLDI(T1,VIDVER)		; get the version number of the video firmware
	LDN	T1		; ...
	CDF			; set DF=0
	BZ	ISCRT1		;  and return that if there's no video
	SDF			; not zero - return DF=1
ISCRT1:	RETURN			; and done
#endif

;   This is the same as ISCRTC except that it actually prints an error message
; before it returns if the video card is present...
#ifdef VIDEO
NOCRTC:	CALL(ISCRTC)		; see if the video card is installed
	LBNF	ISCRT1		; nope - just return now
	OUTSTR(NOCRT1)		; print an error message
	SDF			; be sure DF is still 1
	RETURN			; and return
NOCRT1:	.TEXT	"?VIDEO ACTIVE\r\n\000"
#endif

	.EJECT
;	.SBTTL	Type Various Special Characters

; This routine will type a carriage return/line feed pair on the console...
TCRLF:	LDI	CHCRT		; type carriage return
	CALL(F_TTY)		; ...
	LDI	CHLFD		; and then line feed
	LBR	F_TTY		; ...

; Type a single space on the console...
TSPACE:	LDI	' '		; this is what we want
	LBR	F_TTY		; and this is where we want it

; Type a (horizontal) tab...
TTABC:	LDI	CHTAB		; ...
	LBR	F_TTY		; ...

; Type a question mark...
TQUEST:	LDI	'?'		; ...
	LBR	F_TTY		; ...

	.EJECT
;	.SBTTL	Scan Two and Four Digit Hex Values

;   This routine will read a four digit hex number pointed to by P1 and return
; its value in P2.  Other than a doubling of precision, it's exactly the same
; as GHEX2...
GHEX4:	CALL(GHEX2)	; get the first two digits
	BNF	GHEX40	; quit if we don't find them
	PHI	P2	; then save those values for a minute
	CALL(GHEX2)	; then the next two digits
	BNF	GHEX40	; not there
	PLO	P2	; put them with the low
	SDF		; and return with DF set
GHEX40:	RETURN		; all done

;   This routine will scan a two hex number pointed to by P1 and return its
; value in D.  Unlike F_HEXIN, which will scan an arbitrary number of digits,
; in this case the number must contain exactly two digits - no more, and no
; less.  If we don't find two hex digits in the string addressed by P1, the
; DF bit will be cleared on return and P1 left pointing to the non-hex char.
GHEX2:	LDN	P1	; get the first character
	CALL(ISHEX)	; is it a hex digit???
	BNF	GHEX40	; nope - quit now
	SHL\ SHL	; shift the first nibble left 4 bits
	SHL\ SHL	; ...
	PLO	T1	; and save it temporarily in T1
	INC	P1	; ...
	LDN	P1	; then get the next character
	CALL(ISHEX)	; is it a hex digit?
	BNF	GHEX20	; not there - quit now
	STXD		; stack the second digit
	IRX		; and then address it
	GLO	T1	; get the first four bits
	OR		; and put them together
	INC	P1	; on to the next digit
	SDF		; return with DF set
GHEX20:	RETURN		; and we're all done

	.EJECT
;	.SBTTL	Arithmetic Comparisons

;   This routine will examine the ASCII character in D and, if it is a lower
; case letter 'a'..'z', it will fold it to upper case.  All other ASCII
; characters are left unchanged...
FOLD:	ANI	$7F	; only use seven bits
	PLO	BAUD	; save the character (very) temporarily
	SMI	'a'	; is it a lower case letter ???
	BL	FOLD1	; not this time
	SMI   'z'-'a'+1	; check it against both ends of the range
	BGE	FOLD1	; nope -- it's not a letter
	GLO	BAUD	; it is lower case - get the original character
	SMI	$20	; convert it to upper case
	RETURN		; and return that
FOLD1:	GLO	BAUD	; it's not lower case ...
	RETURN		; ... return the original character


;   This routine will examine the ASCII character in D and, if it is a hex
; character '0'..'9' or 'A'..'Z', it will convert it to the equivalent binary
; value and return it in D.  If the character in D is not a hex digit, then
; the DF will be cleared on return.
ISHEX:	ANI	$7F	; ...
	PLO	BAUD	; save the character temporarily
	SMI	'0'	; is the character a digit '0'..'9'??
	BL	ISHEX3	; nope - there's no hope...
	SMI	10	; check the other end of the range
	BL	ISHEX2	; it's a decimal digit - that's fine
	GLO	BAUD	; It isn't a decimal digit, so try again...
	CALL(FOLD)	; convert lower case 'a'..'z' to upper
	SMI	'A'	; ... check for a letter from A - F
	BL	ISHEX3	; nope -- not a hex digit
	SMI	6	; check the other end of the range
	BGE	ISHEX3	; no way this isn't a hex digit
; Here for a letter 'A' .. 'F'...
	ADI	6	; convert 'A' back to the value 10
; Here for a digit '0' .. '9'...
ISHEX2:	ADI	10	; convert '0' back to the value 0
	SDF		; just in case
	RETURN		; return with DF=1!
; Here if the character isn't a hex digit at all...
ISHEX3:	GLO	BAUD	; get the original character back
	CDF		; and return with DF=0
	RETURN		; ...


; This routine will return DF=1 if (P3 .LE. P4) and DF=0 if it is not...
P3LEP4: GHI	P3	; First compare the high bytes
	STR	SP	; ....
	GHI	P4	; ....
	SM		; See if P4-P3 < 0 (which implies that P3 > P4)
	BL	P3GTP4	; because it is an error if so
	BNZ	P3LE0	; Return if the high bytes are not the same
	GLO	P3	; The high bytes are the same, so we must
	STR	SP	; repeat the test for the low bytes
	GLO	P4	; ....
	SM		; ....
	BL	P3GTP4	; ....
P3LE0:	SDF		; return DF=1
	RETURN		; Everything is in the right order...
P3GTP4:	CDF		; return DF=0
	RETURN		; ...

	.EJECT
;	.SBTTL	Output Decimal and Hexadecimal Numbers

;   This routine will convert a four bit value in D (0..15) to a single hex
; digit and then type it on the console...
THEX1:	ANI	$0F		; trim to just 4 bits
	ADI	'0'		; convert to ASCII
	SMI	'9'+1		; is this digit A..F?
	BL	THEX11		; branch if not
	ADI	'A'-'9'-1	; yes - adjust the range
THEX11:	ADI	'9'+1		; and restore the original character
	LBR	F_TTY		; type it and return

; This routine will type a two digit (1 byte) hex value from D...
THEX2:	PUSHD			; save the whole byte for a minute
	SHR\ SHR\ SHR\ SHR	; and type type MSD first
	CALL(THEX1)		; ...
	POPD			; pop the original byte
	LBR	THEX1		; and type the least significant digit

; This routine will type a four digit (16 bit) hex value from P1...
THEX4:	GHI	P1		; get the high byte
	CALL(THEX2)		; and type that first
	GLO	P1		; then type the low byte next
	LBR	THEX2		; and we're done

;   And finally, this routine will type an unsigned 16 bit value from P1 as
; a decimal number.  It's a pretty straight forward recursive routine and
; depends heavily on the BIOS F_DIVIDE function!
TDEC16:	RLDI(P2,10)		; set the divisor
	CALL(F_DIV16)		; divide P1 by ten
	GLO	P1		; get the remainder
	PUSHD			; and stack that for a minute
	RCOPY(P1,P4)		; transfer the quotient back to P1
	BNZ	TDEC1A		; if the quotient isn't zero ...
	GHI	P1		;  ... then keep dividing
	BZ	TDEC1B		;  ...
TDEC1A:	CALL(TDEC16)		; keep typing P1 recursively
TDEC1B:	POPD			; then get back the remainder
	LBR	THEX1		; type it in ASCII and return

	.EJECT
;	.SBTTL	BASIC, Forth, ASM, VISUAL and SEDIT Commands

;   Each of these commands invokes the corresponding software package in the
; EPROM (if it's present, that is).  Each one of these languages has the
; ability to either create a new program (the normal case) or to recover a
; program already stored in SRAM.  This latter case is particularly useful
; with battery backup for the SRAM, because you can enter you long BASIC,
; Forth or assembly program today and it'll still be there tomorrow!  This
; alternate function is accessed by an alternate entry point at the main
; entry point +3 bytes.
#ifdef BASIC
RBASIC:	RLDI(T2,BASIC)
#endif

;   Here's the common code for all cases...  When we get here, the main entry
; point for the language should be in T2...
RBAS1:	CALL(ISEOL)	; is there more on the command line
	LBNF	RBAS2	; if there is more, check for NEW or OLD argument
	OUTSTR(NEWOLD)	; ask "New or Old ?"
	RLDI(P1,CMDBUF)	; read another command line
	RLDI(P3,CMDMAX)	; ...
	CALL(F_INPUTL)	; ...
	CALL(TCRLF)	; ...
	RLDI(P1,CMDBUF)	; setup P1 to point to the new "command"
RBAS2:	CALL(F_LTRIM)	; skip any leading spaces
	RLDI(P2,BASCMD)	; try to parse either "NEW" or "OLD"
	LBR	COMND	; (and call CMDERR if we can't!)

; Table of NEW and OLD options...
BASCMD:	CMD(3, "NEW", BASNEW)
	CMD(3, "OLD", BASOLD)
	.DB	0

;   Here for the "BASIC OLD" command.  Adjust the entry point (passed in T1)
; by three bytes.  Since we know the entry points are always aligned on at
; least a page boundary, we can take the easy way out on this...
BASOLD:	LDI	3	; set the entry point offset
	PLO	T2	; ... in T2
; Here for the "BASIC NEW" command...
BASNEW:	RLDI(T1,BASGO)	; we can't use R3 as the PC right now
	SEP	T1	; so we'll go back to R0
BASGO:	RCOPY(PC,T2)	; put the address in R3
	SEP	PC	; and then branch to the interpreter

; Messages...
NEWOLD:	.TEXT	"New or Old ?\000"


; The ASM command is pretty much the same...
#ifdef EDTASM
RASM:	RLDI(T2,EDTASM)
	LBR	RBAS1
#endif

; And Forth...
#ifdef FORTH
RFORTH:	RLDI(T2,FORTH)
	LBR	RBAS1
#endif

; The SEDIT command is even easier - there's no new or old nonsense...
#ifdef SEDIT
RSEDIT:	CALL(ISEOL)	; should be no arguments
	LBNF	CMDERR	; error if there are
	LBR	SEDIT	; start SEDIT ...
#endif

; And lastly, Visual/02 ...
#ifdef VISUAL
RVISUAL:CALL(ISEOL)	; there are no arguments
	LBNF	CMDERR	; error if there are
	LBR	VISUAL	; start Visual/02 ...
#endif

	.EJECT
;	.SBTTL	Primary Command Table

;   The command table contains one or more command entries organized like
; this:
;
;	.DB	2, "BASIC", 0
;	.DW	BASIC
;
;  The first byte, 2 in this case, is the minimum number of characters that
; must match the command name ("BA" for "BASIC" in this case).  The next
; bytes are the full name of the command, terminated by a zero byte, and
; the last two bytes are the address of the routine that processes this
; command.

; Here's the table of monitor commands....
CMDTBL:	CMD(4, "CONTINUE", CONTINUE)	; continue after a breakpoint
#ifdef FORTH
	CMD(3, "FORTH",    RFORTH)	;  "     "   "  Forth   "   "
#endif
#ifdef SEDIT
	CMD(3, "SEDIT",    RSEDIT)	; SEDIT
#endif
#ifdef EDTASM
	CMD(3, "ASM",	   RASM)	; editor/assembler
#endif
#ifdef VISUAL
	CMD(2, "VISUAL",   RVISUAL)	; Visual/02 debugger
#endif
	CMD(2, "OUTPUT",   OUTPUT)	;  "   output  "
	CMD(2, "INPUT",    INPUT)	; test input port
	CMD(2, "CALL",     CALUSR)	; "call" a user's program
	CMD(2, "RUN",      RUNUSR)	; "run"  "   "     "   "
	CMD(2, "HELP",	   PHELP)	; print help text
	CMD(2, "SET",      SET)
	CMD(2, "SHOW",     SHOW)
	CMD(2, "TEST",	   TEST)
#ifdef BASIC
	CMD(2, "BASIC",    RBASIC)	; start the ROM BASIC
#endif
	CMD(1, "BOOT",     BOOTCMD)	; boot from the primary IDE disk
	CMD(1, "EXAMINE",  EXAM)	; examine/dump memory bytes
	CMD(1, "DEPOSIT",  DEPOSIT)	; deposit data in memory
	CMD(1, ":",        IHEX)	; load Intel .HEX format files
	CMD(1, ";",	   MAIN)	; a comment
#ifdef VIDEO
	CMD(3, "CLS",      CLSCMD)	; clear the VT1802 screen
#endif

; The table always ends with a zero byte...
	.DB	0

	.EJECT
;	.SBTTL	Sample Bitmaps for CDP1861 Display

;   The classic "Starship Enterprise" outline for the CDP1861 by Joseph
; Weisbecker.  Note that the bitmap must be aligned on a multiple of
; sixteen bytes in order for it to be positioned correctly on the CRT...
	

#ifdef PIXIE
	PAGE
NCC1701:
; SPARE TIME GIZMOS...
	.DB	$EE,$EE,$E3,$BA,$B8,$E7,$75,$77
	.DB	$8A,$AA,$81,$13,$A0,$82,$17,$54
	.DB	$EE,$EC,$C1,$12,$B0,$A2,$25,$57
	.DB	$28,$AA,$81,$12,$A0,$92,$45,$51
	.DB	$E8,$AA,$E1,$3A,$B8,$E7,$75,$77
	.DB	$00,$00,$00,$00,$00,$00,$00,$00
	.DB	$00,$00,$00,$00,$00,$00,$00,$00
	.DB	$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF

; The original NCC1701 starts here....
	.DB	$00,$00,$00,$00,$00,$00,$00,$00
	.DB	$00,$00,$00,$00,$00,$00,$00,$00
	.DB	$7B,$DE,$DB,$DE,$00,$00,$00,$00
	.DB	$4A,$50,$DA,$52,$00,$00,$00,$00
	.DB	$42,$5E,$AB,$D0,$00,$00,$00,$00
	.DB	$4A,$42,$8A,$52,$00,$00,$00,$00
	.DB	$7B,$DE,$8A,$5E,$00,$00,$00,$00
	.DB	$00,$00,$00,$00,$00,$00,$00,$00
	.DB	$00,$00,$00,$00,$00,$00,$07,$E0
	.DB	$00,$00,$00,$00,$FF,$FF,$FF,$FF
	.DB	$00,$06,$00,$01,$00,$00,$00,$01
	.DB	$00,$7F,$E0,$01,$00,$00,$00,$02
	.DB	$7F,$C0,$3F,$E0,$FC,$FF,$FF,$FE
	.DB	$40,$0F,$00,$10,$04,$80,$00,$00
	.DB	$7F,$C0,$3F,$E0,$04,$80,$00,$00
	.DB	$00,$3F,$D0,$40,$04,$80,$00,$00
	.DB	$00,$0F,$08,$20,$04,$80,$7A,$1E
	.DB	$00,$00,$07,$90,$04,$80,$42,$10
	.DB	$00,$00,$18,$7F,$FC,$F0,$72,$1C
	.DB	$00,$00,$30,$00,$00,$10,$42,$10
	.DB	$00,$00,$73,$FC,$00,$10,$7B,$D0
	.DB	$00,$00,$30,$00,$3F,$F0,$00,$00
	.DB	$00,$00,$18,$0F,$C0,$00,$00,$00
	.DB	$00,$00,$07,$F0,$00,$00,$00,$00
#endif

	.EJECT
	.END

