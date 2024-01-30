	.TITLE	 "VIDEO -- COSMAC Elf 2000 Video Terminal Module"
;	 Bob Armstrong [14-Jun-82]

;       Copyright (C) 2005 By Spare Time Gizmos, Milpitas CA.

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
;
; DESCRIPTION
;   This piece of software is an addition to the standard Spare Time Gizmos
; COSMAC Elf 2000 EPROM; this addition emulates a simple VT52 style video
; terminal using the ElfVideo option card.  The ElfVideo card uses an Intel
; 8275 CRT controller chip and is capable of displaying 80 x 24 text using an
; 8 by 10 font on a standard CGA monitor.
;
;   Note that this firmware is strictly "ouptut only" - it handles the display
; side of the terminal, but not the keyboard input.  The input is handled by
; a completely separate PS/2 to parallel ASCII gizmo, which is independent of
; this module.
;
;   This software is designed to emulate the DEC VT52 terminal as closely as
; possible. In particular, the following features of the VT52 are fully
; supported:
;
;	 * Cursor Up, Down, Left, Right, Home (ESC A, B, C, D, H)
;	 * Scroll Up/Down		      (LF, ESC I)
;	 * Erase to End of Line/Screen	      (ESC K, J)
;	 * Direct Cursor Addressing	      (ESC Y line column)
;	 * Enter/Exit Graphics Mode	      (ESC F, G)
;
;   The only VT52 command sequences which are not supported by this software
; are enter/exit alternate keypad mode (ESC  =, >) and identify (ESC Z).
; Neither of these have any meaning since this is a display only type device
; and the keyboard is an entirely seperate device.  In addition to all normal
; VT52 functions, this  terminal also implements these extensions:
;
;	 * Erase Screen / Raster Test	      (ESC E, R)
;	 * Write Field Attribute Code	      (ESC N)
;	 * Write Line Drawing Code	      (ESC O)
; 	 * Display test screen		      (ESC T)
;
; WARNING
;   With the exception of the INIT75 and VIDISR routines, _everything_ else
; in this module is called via the VTPUTC function, and VTPUTC is called by
; the BIOS F_TYPE function.  The issue is that pretty much all code everywhere
; expects F_TYPE to preserve all the registers, so that means (with the two
; exceptions previously mentioned) every routine in this module is expected to
; save and restore any registers it uses.
;
;   Because they're used so often VTPUTC takes care of saving and restoring
; P1 and DP - any other registers (e.g. T1 or P2) need to be saved in the
; individual routines!
;--

;0000000001111111111222222222233333333334444444444555555555566666666667777777777
;1234567890123456789012345678901234567890123456789012345678901234567890123456789

	.MSFIRST \ .PAGE \ .CODES

	.NOLIST
	.INCLUDE "config.inc"
	.INCLUDE "hardware.inc"
	.INCLUDE "boots.inc"
	.LIST

	.EJECT
;++
; REVISION HISTORY
; 
; 001	-- New file (gotta start somewhere!)...
;
; 002	-- We need to use parenthesis in LINTAB - SCREEN+(3*MAXX) !!
;
; 003	-- LDA missing an argument in WHERE: (should be "LDA DP")...
;
; 004	-- RIGHT and DOWN are missing a SEX DP, but instead of fixing that
;	   I just decided to rewrite them...
;
; 005	-- Use the standard include files - CONFIG, ELF2K and BOOTS - for all
;	   hardware and software definitions shared with BOOTS.ASM
;
; 006	-- Parameterize the code and screen buffer locations.
;
; 007	-- Make VTPUTC save P1, T1 and DP.
;
; 008	-- Save P2 in the few places (FILL, EEOS) where it is used.
;
; 009	-- Rewrite SCRUP so it doesn't use T1.  Make CLRLIN, EEOL and FILL save
;	   T1.  Now VTPUTC doesn't need to save/restore T1.
;
; 010	-- Swap around EEOS and CLRLIN to avoid off page errors...
;
; 011	-- There was a nasty bug in CLRMEM: such that it didn't actually zero
;	   memory, but rather scribbled garbage all over it!
;
; 012	-- Implement LBRI to handle control character, escape character and
;	   escape state tables.  Implement control table, but leave the rest
;	   for later.
;
; 013	-- Implement rudimentary escape processing.
;
; 014	-- A BNF in ESCAP1 should have been a BDF...
;
; 015	-- Fix a misplaced label that causes EEOL <ESC>K to fail...
;
; 016	-- Implement direct cursor addressing (<ESC> Y <row> <col>)
;
; 017	-- Implement the graphics character set and the <ESC>F (select GCS)
;	   and <ESC>G (deselect GCS) escape sequences.  Also implement the
; 	   SI (shift in) and SO (shift out) ASCII control characters to do
;	   the same thing (all of this is just as a real VT52 would have done).
;
; 018	-- Implement <ESC>N <attr> write 8275 field attributes escape sequence.
;
; 019	-- Add ^G (BEL) support using the speaker on the GPIO card...
;
; 020	-- Add line wrapping at the right margin.  A real VT52 didn't do this,
;	   but it's really more useful this way!
;
; 021	-- Add the local copyright notice...
;
; 022	-- Add the screen adjustment/test function, <ESC>T ...
;
; 023	-- Rewrite the ISR to take advantage of new hardware design.
;	   This reduces the interrupt overhead significantly...
;
; 024	-- a "SEP PC" is missing from INIT75 during the 8275 presence test!
; 	   Thanks go to Ian May, fps16xn3@yahoo.com, for figuring this out.
;--
VIDVER	.EQU	24

	.EJECT
;	.SBTTL	Frame Buffer and RAM Storage Map

;   A 80x24 terminal requires 1,920 bytes for the display buffer alone, plus
; whatever local storage the terminal emulator requires.  To make things 
; simple, and to allow for a possible expansion to an 80x25 format, we round
; this off to an even 2K bytes.  Since the monitor already reserves the last
; page of RAM, $7F00..$7FFF, for its use, we're left with reserving $7700 to
; $7EFF for the video system.

	.ORG	SCREEN

;   ASCII frame buffer...   Note that there is a table at LINTAB: which must
; contain at least MAXY entries.  If you change MAXY, it might be a good idea
; to check that table too!
MAXX	.EQU	80		; number of characters per line
MAXY	.EQU	24		; number of lines per screen
	.BLOCK	MAXX * MAXY	; the whole screen lives here!
SCREND	.EQU	$

; Other random VT52 emulator context variables...
;   WARNING!! DO NOT CHANGE THE ORDER OF TOPLIN, CURSX and CURSY!  The code
; DEPENDS on these three bytes being in this particular order!!!
TOPLIN: .BLOCK	1		; the number of the top line on the screen
CURSX:	.BLOCK	1		; the column number of the cursor
CURSY:	.BLOCK	1		; the row number of the cursor
GCSMOD:	.BLOCK	1		; != 0 for graphics character set mode
; DON'T CHANGE THE GROUPING OF ESCSTA, CURCHR AND SAVCHR!!
ESCSTA:	.BLOCK	1		; current ESCape state machine state
CURCHR:	.BLOCK	1		; character we're trying to output
SAVCHR:	.BLOCK	1		; save one character for escape sequences
; DON'T CHANGE THE GROUPING OF FRAME AND BELCNT!!
FRAME:	.BLOCK	1		; incremented by the end of frame ISR
BELCNT:	.BLOCK	1		; timer for ^G bell beeper
DTALEN	.EQU	$-SCREEN	; total size of our RAM space

	.EJECT
;	.SBTTL	Entry Vectors

;   Like most of the other EPROM components, the VT52 emulator has a standard
; set of entry vectors located at the start of its ROM space.  These vectors
; are the only standard entry points to this module, and should be used by all
; other modules to invoke us.  This allows code in the VT52 emulator to change
; and move around without affecting anything else...
;
;   With the exception of the version, all entry points should be CALLed
; using SCRT and the standard BOOTS/BIOS register assignments!
	.ORG	VIDEO
	LBR	INIT75_		; initialize the video card
	LBR	VTPUTC_		; output a character to the virtual VT52
	.DB 0 \ .DW RIGHTS	; dummy vector for the copyright notice

; Copyright notice, in plain ASCII...
RIGHTS:	.TEXT	"VT1802 Video Card Firmware V"
	.DB	(VIDVER/10)+'0', (VIDVER%10)+'0', 0
	.TEXT	"Copyright (C) 2006 by Spare Time Gizmos. All rights reserved."
	.DB	0

	.EJECT
;	.SBTTL	8275 Initialization and POST ...

;  This code will figure out whether the 80 column video card is installed and,
; if it finds one, will initialize the 8275 CRT controller and clears the
; screen buffer.  As an inseparable part of this it also does the POST of the
; video card, including displaying the POST codes on the LEDs.  It's normally
; called only once, during SYSINI.
;
;   If the video card is installed it'll be left running, with a blank screen
; and only the cursor displayed.  After that, text can be displayed by calling
; VTPUTC.  If no video card is installed, then it doesn't touch any of the
; RAM allocated to the screen buffer - this is critical, because this memory
; can be reused for other purposes if the video isn't present.
;
;  It returns with DF=1 if the video card is installed and working, and DF=0
; if it isn't installed or isn't working...
;
;  One final note - unlike most other POST routines, this one is called after
; SCRT is initialized.  That means we have P=3 here, rather than the usual P=0.
; That's a necessary evil, because we need R0 and R1 in order to start up the
; CRTC DMA and interrupts...
INIT75_:

;   One nasty problem with the 8275 is that it doesn't have a RESET input, so
; it's possible for it to power up doing almost anything.  Worse, if the 8275
; is already running and you press the RESET button on the Elf 2000, the 8275
; keeps right on going!  This is especially a problem for the 1802, which has
; no way to inhibit DMA requests.
;
;  To solve this problem, the ElfVideo hardware inhibits the 8275 interrupt and
; DMA requests, as well as the sync outputs to the monitor, until the status
; register is read for the first time.  I'm telling you all this because it's
; critical that we don't do anything to read the status register until we've
; initialized the CRTC!

;   Just blindly (since we don't yet know whether it's there or not!) send
; a RESET command to the 8275.  This command requires four parameter bytes
; which set the format, timing, cursor type, etc for the display.  After
; this, the 8275 will be in a known state and it will be stay stopped (i.e.
; no DMA and no IRQs) until we issue a START DISPLAY command.
	SEX	PC			; set X=P
	OUT	CRTCC			; write the command register
	.DB	CRTC_RESET		;  ... reset the 8275
	OUT	CRTCP			; write the parameters
	.DB	$00 + (MAXX-1)		;  ... P1 -> characters per row
	OUT	CRTCP			;  ...
	.DB	(2-1)<<6 + (MAXY-1)	;  ... P2 -> rows per VRTC,
					;	     rows per screen
	OUT	CRTCP			;  ...
	.DB	$89			;  ... P3 -> scan line for underline,
					;	     total scan lines per font
	OUT	CRTCP			;  ...
	.DB	$C0 + (0<<4) + (16>>1)-1;  ... P4 -> offset line counter,
					;      non-transparent field attributes
					;      blinking block cursor
					;      characters per HRTC

;   Ok, now it's safe to read the 8275 status register.  We actually have to
; read it twice (because RESET doesn't clear all the status bits, and there
; may be some garbage left over), but the second time should return with
; all status bits cleared...
	OUTI(LEDS,$39)		; start of video subsytem test
	SEX	SP		; (OUTI leaves X==SP!)
	INP	CRTCS		; read status and enable video
	NOP			; (small delay in case the 8275 needs it)
	INP	CRTCS		; then read it again
	BNZ	NO8275		; there's no 8275 if it is non-zero

;   Now we intentionally issue a bad command sequence - a LOAD CURSOR followed
; by a STOP DISPLAY, with no parameters for the LOAD CURSOR.  If the 8275 is
; really present this should make it set the IMPROPER COMMAND status bit.
	OUTI(LEDS,$38)		; command/status register test
	SEX	PC		; [024] output bytes inline
	OUT	CRTCC		; write the command register
	.DB	CRTC_LDCURS	;  ... load cursor address
	OUT	CRTCC		; then do it again
	.DB	CRTC_STOP	;  ... stop video command
	SEX	SP		; back to the regular stack
	INP	CRTCS		; and read the status
	XRI	CRTC_IC		; it'd better say "IMPROPER COMMAND"...
	BNZ	NO8275		; there's no 8275 if it doesn't

;   Ok - we know that there's an 8275 present, so it's fair to take over the
; chunk of RAM that belongs to us and initialize our own local data and the
; frame buffer...
	OUTI(LEDS,$37)		; initialize screen buffer
	RLDI(P1,SCREEN)		; point P1 at the start of our RAM area
	RLDI(P2,DTALEN)		; and load the length of that area
CLRMEM:	LDI	0		; fill everything with zeros
	STR	P1		; clear a byte
	INC	P1		; and keep count
	DEC	P2		; ...
	GLO	P2		; have we done them all?
	BNZ	CLRMEM		;  ... nope
	GHI	P2		; gotta check both bytes
	BNZ	CLRMEM		;  ... nope - keep going
	CALL(ERASE)		; yes - now clear the screen and load the cursor

; Now start up the display...
	OUTI(LEDS,$36)		; initialize display, interrupts on
	RLDI(DMAPTR,SCREEN)	; preload the DMA and
	RLDI(INTPC,VIDISR)	;  .... interrupt registers
	SEX	PC		; back to X=P
	OUT	CRTCC		; Enable CRTC interrupts
	.DB	CRTC_EI		;  ...
	OUT	CRTCC		; Preload the counters
	.DB	CRTC_PRESET	;  ...
	OUT	CRTCC		; Finally, turn on the video
	.DB	CRTC_START+3	;  ... (use maximum DMA rate)
	INT_ON			; what a big leap of faith this is!

;   Now make sure that both the DMA and the end-of-frame interrupts are actually
; happening.  That's easy enough to do simply by watching for the DMA pointer
; (R0) and the frame counter (FRAME:) to change - if they don't change, then
; we'll just spin here forever with the appropriate POST code displayed...
	OUTI(LEDS,$35)		; no DMA
TSTDMA:	GLO	DMAPTR		; get the current DMA pointer
	BZ	TSTDMA		; and wait for it to change
	OUTI(LEDS,$34)		; no end of frame interrupt
	RLDI(P1,FRAME)		; point at the frame counter
TSTEOF:	LDN	P1		; get the current count
	SMI	60		; wait for a full second to go by
	BNF	TSTEOF		; ...

;  That's it - the video card is alive and ready...
	SDF			; DF=1 for success
	LDI	VIDVER		; and return our version number in D
	RETURN

; Here if no video card is installed...
NO8275:	CDF			; return DF=0
	LDI	0		;  and D=0
	RETURN

	.EJECT
	.ORG	VIDEO+256+$30-2+10;; TEMPORARY - for alignment only!
	.EJECT
;	.SBTTL	8275 Interrupt Service

;   The ElfVideo card interrupts the 1802 CPU at the end of every display row
; and once again at the end of each frame.  For a 24 line display, that's a
; total of 25 interrupts per frame!  We'd like to do away with with interrupt
; per character row, but it's essential to the way scrolling is handled that
; we check the DMA pointer at the end of each row...

; Here to exit from the interrupt (and leave the PC pointing to VIDISR!)...
VIDRET:	INC	SP		; [2] point SP back to the saved D register
VIDRE1:	LDXA			; [2] restore the D register from the stack
	RET			; [2] and return from the interrupt

;   Here is the video interrupt service routine.  Note that the only context
; this saves is X, P and D - be very, very careful not to change anything else,
; especially DF!!!
VIDISR:	DEC	SP		; [2] make a space on the stack
	SAV			; [2] and push T (the saved X,P)
	DEC	SP		; [2] make another spot
	STXD			; [2] and now save the D register too
	B1	EOFISR		; [2] branch for end of frame interrupt

;   At the end of each chararacter row we have to check the DMA pointer to
; see if it's reached the end of the screen buffer and, if it has, wrap it
; around back to the start of the buffer.  The scrolling depends on this, and
; it's the reason why we need interrupts at the end of each row...
ROWEND:	GHI	DMAPTR		; [2] get the high byte of the DMA pointer
	XRI	HIGH(SCREND)	; [2] compare to the end of the screen buffer
	BNZ	VIDRET		; [2] not the same - just return
	GLO	DMAPTR		; [2] do the same for the low byte
	XRI	LOW(SCREND)	; [2] ...
	BNZ	VIDRET		; [2] return if not the end of the buffer

; We've reached the end of the screen buffer - wrap around...
	RLDI(DMAPTR,SCREEN)	; [8] reset the DMA pointer back to the start
	BR	VIDRET		; [2] and return from interrupt


;   Here for the end of frame interrupt.  In this case we need to compute the
; address of the first line on the screen, based on TOPLIN, and initialize
; the DMA pointer to that row in the screen buffer.  BTW, since this interrupt
; occurs only once per frame we don't have to be quite so careful about speed.
EOFISR:	PUSHR(P1)		; [8] save a temporary register
	INP	CRTCS		; [2] read the status register to clear the IRQ
	SHLC			; [2] and save DF
	STR	SP		; [2] ...
	RLDI(P1,TOPLIN)		; [8] point to TOPLIN
	LDN	P1		; [2] load the value of TOPLIN
	SHL			; [2] multiply it by two
	ADI	LOW(LINTAB)	; [2] index into the line pointer table
	PLO	P1		; [2] save that
	LDI	HIGH(LINTAB)	; [2] compute the high byte
	ADCI	0		; [2] with carry
	PHI	P1		; [2] ...
	LDA	P1		; [2] get the first byte of the line address
	PHI	DMAPTR		; [2] update the DMA pointer for the next frame
	LDN	P1		; [2] next byte too
	PLO	DMAPTR		; [2] ...

;  Increment the frame counter - this is used by the POST to determine whether
; the interrupts are working, and it's used to keep track of time (e.g. for
; beeping the beeper) ...
	RLDI(P1,FRAME)		; [8] point at FRAME
	LDN	P1		; [2] get the current count
	ADI	1		; [2] and increment it
	STR	P1		; [2] ignoring any carry

;   If the bell timer (BELCNT, which is conveniently located at FRAME+1!) is
; non-zero, then the GPIO beeper is turned on and we should decrement BELCNT.
; When BELCNT reaches zero, we turn off the GPIO speaker.  This is used to
; implement the ^G bell function of the VT52...
	INC	P1		; [2] point to BELCNT
	LDN	P1		; [2]  get the value now
	BZ	EOFIS1		; [2] just return now if it's zero
	SMI	1		; [2] otherwise decrement it
	STR	P1		; [2] and update BELCNT
	BNZ	EOFIS1		; [2] just keep going until it reaches zero
	SEX	PC0		; [2] it's done - turn off the speaker now
	OUT	GPIO		; [2]  ...
	.DB	SPOFF		; [2] (speaker off function code)
	SEX	SP		; [2]  ...

; Here to return from the frame interrupt...
EOFIS1:	LDXA			; [2] restore DF
	SHRC			; [2] ...
	POPR(P1)		; [8] restore P1
	BR	VIDRE1		; [2] and return

	.EJECT
;	.SBTTL	Compute the Address of Any Line

;   This subroutine will calculate the address of any line on the screen.
; The absolute number of the line (i.e. not relative to any scrolling) should
; be passed in the D and the resulting address is returned in P1...  Uses
; (but doesn't save!) DP...
LINADD:	SMI	MAXY		; if the line number is off the screen
	BDF	LINADD		; reduce it modulo MAXY
	ADI	MAXY		; until it's on the screen
LINAD1: SHL			; now double the line number
	ADI	LOW(LINTAB)	; and then point to the address table
	PLO	DP		; save the low byte of the address
	LDI	HIGH(LINTAB)	; now do the high byte
	ADCI	0		; include any carry from the low byte
	PHI	DP		; ...
	LDA	DP		; now get the first byte from the table
	PHI	P1		; that's the line address
	LDN	DP		; and the second byte
	PLO	P1		; ...
	RETURN			; and then that's all there is to do

;   This table is used to translate character row numbers into actual screen
; buffer addresses.  It is indexed by twice the row number (0, 2, 4, ... 48) and
; contains the corresponding RAM address of that line. This address is stored in
; two bytes, with the low order bits of the address being first.  Needless to
; say, it should have at least MAXY entries!  More entries won't hurt, but too
; few is really bad...
LINTAB:	.DW	SCREEN+( 0*MAXX)	; line #0
	.DW	SCREEN+( 1*MAXX)	; line #1
	.DW	SCREEN+( 2*MAXX)	; line #2
	.DW	SCREEN+( 3*MAXX)	; line #3
	.DW	SCREEN+( 4*MAXX)	; line #4
	.DW	SCREEN+( 5*MAXX)	; line #5
	.DW	SCREEN+( 6*MAXX)	; line #6
	.DW	SCREEN+( 7*MAXX)	; line #7
	.DW	SCREEN+( 8*MAXX)	; line #8
	.DW	SCREEN+( 9*MAXX)	; line #9
	.DW	SCREEN+(10*MAXX)	; line #10
	.DW	SCREEN+(11*MAXX)	; line #11
	.DW	SCREEN+(12*MAXX)	; line #12
	.DW	SCREEN+(13*MAXX)	; line #13
	.DW	SCREEN+(14*MAXX)	; line #14
	.DW	SCREEN+(15*MAXX)	; line #15
	.DW	SCREEN+(16*MAXX)	; line #16
	.DW	SCREEN+(17*MAXX)	; line #17
	.DW	SCREEN+(18*MAXX)	; line #18
	.DW	SCREEN+(19*MAXX)	; line #19
	.DW	SCREEN+(20*MAXX)	; line #20
	.DW	SCREEN+(21*MAXX)	; line #21
	.DW	SCREEN+(22*MAXX)	; line #22
	.DW	SCREEN+(23*MAXX)	; line #23
	.DW	SCREEN+(24*MAXX)	; line #24

	.EJECT
;	.SBTTL	Cursor Primitives

;   This routine will update the 8275 cursor location so that it agrees with
; the software location.  This is called after most cursor motion functions
; to actually change the picture on the screen...  Uses (but doesn't save) DP!
LDCURS:	RLDI(DP,CURSX)		; point to the cursor location
	SEX	PC		; set X=P for a moment
	OUT	CRTCC		; give the load cursor command
	.DB	CRTC_LDCURS	; ...
	SEX	SP		; back to the stack
	LDA	DP		; get the X location
	STR	SP		; save it on the stack for a moment
	OUT	CRTCP		; and send it to the CRTC
	DEC	SP		; (correct for the OUT instruction)
	LDA	DP		; and get CURSY next
	STR	SP		; do the same with it
	OUT	CRTCP		; ...
	DEC	SP		; ...
	RETURN			; that's all there is to it

;   This subroutine will compute the actual address of the character under the
; cursor.  This address depends on the cursor location (obviously) and also
; the value of TOPLIN (which represents the number of the top line on the
; screen after scrolling).  The address computed is returned in P1.
WHERE:	RLDI(DP,TOPLIN)		; point to TOPLIN for starters
	LDA	DP		; and get that value
	INC	DP		; (skip over CURSX for a moment)
	SEX	DP		; ...
	ADD			; compute TOPLIN+CURSY
	CALL(LINADD)		; set P1 = address of the cursor line
	RLDI(DP,CURSX)		; (LINADD trashes DP anyway!)
	GLO	P1		; get the low byte of the line address
	SEX	DP		; and add CURSX
	ADD			; ...
	PLO	P1		; put it back
	GHI	P1		; and propagate the carry
	ADCI	0		; to the high byte
	PHI	P1		; ...
CURRET:	RETURN			; leave the address in P1 and we're done...

	.EJECT
;	.SBTTL	Basic Cursor Motions

;   This routine will implement the cursor left function. This will move the
; cursor left one character. If, however, the cursor is already against the
; left  margin of the screen, then no action occurs.
LEFT:	RLDI(DP,CURSX)		; get the cursor column number
	LDN	DP		; ...
	SMI	1		; and move it left one space
	LBNF	CURRET		; return now if the result is .LT. 0
	STR	DP		; no -- change the software location
	LBR	LDCURS		; and go change the picture on the screen

;   This routine will implement the cursor right function. This will move the
; cursor right one character. If, however, the cursor is already against the
; right margin of the screen, then no action occurs.
RIGHT:	RLDI(DP,CURSX) 		; get the cursor X location
	LDN	DP		; ...
	XRI	MAXX-1		; don't allow it to move past this
	LBZ	CURRET		; already at the right margin - quit now
RIGHT1:	LDN	DP		; nope - its safe to increment the cursor
	ADI	1		; ...
	STR	DP		; update memory
	LBR	LDCURS		; and tell the 8275 about the change

;   This routine will implement the cursor up function.  This will move the
; cursor up one character line. If, however, the cursor is already at the top
; of the screen, then no action occurs.;
UP:	RLDI(DP,CURSY)		; get the row which contains the cursor
	LDN	DP		; ...
	SMI	1		; and move it up one character row
	LBNF	CURRET		; return now if the new position is .LT. 0
	STR	DP		; no -- change the virtual location
	LBR	LDCURS		; and change the picture

;   This routine will implement the cursor down function. This will move the
; cursor down one character line. If, however, the cursor is already at the
; bottom of the screen, then no action occurs.
DOWN:	RLDI(DP,CURSY)		; get the row number where the cursor is
	LDN	DP		; ...
	XRI	MAXY-1		; don't allow the Y position to exceed this
	LBZ	CURRET		; return if we can't move any more
	LDN	DP		; nope - its safe to increment the cursor
	ADI	1		; ...
	STR	DP		; ...
	LBR	LDCURS		; and go tell the 8275

	.EJECT
;	.SBTTL	Screen Scrolling Routines

;   This routine will scroll the screen down one line. The new top line on the
; screen (which used to be the bottom line) is the cleared to all spaces.
; Note that this routine does not change the cursor location (normally it
; won't  need  to be changed).
SCRDWN:	RLDI(DP,TOPLIN)		; get the line number of the top of the screen
	LDN	DP		; ...
	SMI	1		; and move it down one line
	BDF	SCRDW1		; jump if we don't need to wrap around
	LDI	MAXY-1		; wrap around to the other end of the screen
SCRDW1: STR	DP		; update the top line on the screen
	CALL(LINADD)		; calculate the address of this line
	LBR	CLRLIN		; and then go clear it

;   This routine will scroll the screen up one line. The new bottom line on
; the screen (which used to be the top line) is then cleared to	all spaces.
; Note that this routine does not change the cursor location (normally it
; won't need to be changed).
SCRUP:	RLDI(DP,TOPLIN)		; get the current top line on the screen
	LDN	DP		; ...
	PLO	P1		; and remember that for later
	ADI	1		; then move the top line down to the next line
	STR	DP		; ...
	SMI	MAXY		; do we need to wrap the line counter around ?
	BNF	SCRUP1		; Jump if not
	LDI	0		; yes -- reset the counter back to the first
	STR	DP		; ... line on the screen
SCRUP1:	GLO	P1		; then get back the number of the bottom line
	CALL(LINADD)		; calculate its address
	LBR	CLRLIN		; and then go clear it

	.EJECT
;	.SBTTL	Advanced Cursor Motions

;   This routine implements the tab function. This will move the cursor to
; the next tab stop.  Tabs stops are located in columns 9, 17, 25, 33, etc
; (i.e. column 8i+1, 0<=i<=9). But after column 73, a tab will only advance
; the cursor to the next character, and once the cursor reaches the right
; margin a tab will not advance it any further.
TAB:	RLDI(DP,CURSX)		; get the current column of the cursor
	LDN	DP		; ...
	SMI	MAXX-8-1	; are we close to the right edge of the screen?
	LBDF	RIGHT		; just do a single right motion if we are
	LDN	DP		; no - get the current column back again
	ANI	$F8		; and clear the low 3 bits of the address
	ADI	8		; advance to the next multiple of 8
	STR	DP		; update the software cursor location
	LBR	LDCURS		; and also change the picture on the screen

;   This routine will implement the carriage return function. This will move
; the cursor back to the start of the current line.
CRET:	RLDI(DP,CURSX)		; point to the X cursor location
	LDI	0		; and set it to the first column
	STR	DP		; just put the cursor there
	LBR	LDCURS		; now go tell the 8275

;   This routine will implement the home function.  This will move the cursor
; to the upper left corner of the screen.
HOME:	RLDI(DP,CURSX)		; (CURSX comes before CURSY)
	LDI	0		; set both CURSX and CURSY to zero
	STR	DP		; CURSX...
	INC	DP		; ...
	STR	DP		; and CURSY...
	LBR	LDCURS		; then let the user see the change

;   This routine will implement the line feed function. This function will
; move the cursor down one line, unless the cursor happens to be on the
; bottom of the screen. In this case the screen is scrolled up one line and
; the cursor remains in the same location (on the screen).
AUTONL:	CALL(CRET)		; here for an auto carriage return/line feed
LINEFD: RLDI(DP,CURSY)		; get the line location of the cursor
	LDN	DP		; ...
	SMI	MAXY-1		; is it on the bottom of the screen ?
	LBNF	DOWN		; just do a down operation if it is
	LBR	SCRUP		; otherwise go scroll the screen up

;   This routine will implement the reverse line feed function.  This
; function will move the cursor up one line, unless the cursor happens to
; be on the top of the screen. In this case the screen is scrolled down one
; line and the cursor remains in the same location (on the screen).
RLF:	RLDI(DP,CURSY)		; load the current Y location of the cursor
	LDN	DP		; is it on the top of the screen ?
	LBNZ	UP		; just do an up operation if it isn't
	LBR	SCRDWN		; otherwise go scroll the screen down

	.EJECT
;	.SBTTL	Screen Erase Functions

;   This routine will erase all characters from the current cursor location
; to the end of the screen, including the character under the cursor.
EEOS:	PUSHR(P2)		; save P2
	RLDI(DP,TOPLIN)		; find the line that's on the top of the screen
	LDN	DP		; ...
	CALL(LINADD)		; then calculate its address in P1
	RCOPY(P2,P1)		; put that address in P1 for a while
	CALL(WHERE)		; and find out where the cursor is
EEOS1:	LDI	' '		; clear this character
	STR	P1		; ...
	INC	P1		; and increment the pointer
	GLO	P1		; get the low bits of the address
	XRI	LOW(SCREND)	; have we reached the end of the screen space ?
	BNZ	EEOS2		; jump if we haven't
	GHI	P1		; yes -- check the high order bits too
	XRI	HIGH(SCREND)	; well, ???
	BNZ	EEOS2		; again jump if we haven't
	RLDI(P1,SCREEN)		; yes -- wrap around to the start of the screen
EEOS2:	GLO	P1		; get the low byte of the address (again!)
	STR	SP		; ...
	GLO	P2		; have we reached the top of the screen yet ?
	XOR			; ???
	BNZ	EEOS1		; keep clearing if we haven't
	GHI	P1		; maybe -- we need to check the high byte too
	STR	SP		; ...
	GHI	P2		; ????
	XOR			; ...
	BNZ	EEOS1		; keep on going if we aren't there yet
	IRX			; return and restore P2
	POPRL(P2)		; ...
	RETURN			; otherwise that's all there is to it

;   This routine will clear 80 characters in the display RAM.  This is normally
; used to erase lines for scrolling purposes. It expects the address of the
; first byte to be passed in P1; this byte and the next 79 are set to a space
; character.
CLRLIN:	PUSHR(T1)		; save T1.0 so we can use it as a temporary
	LDI	MAXX		; get the number of characters per line
	PLO	T1		; and store that here
CLRLI1: LDI	' '		; set this byte to a space
	STR	P1		; ...
	INC	P1		; and advance to the next one
	DEC	T1		; decrement the counter
	GLO	T1		; and loop if there are more bytes to be done
	BNZ	CLRLI1		; ...
	IRX			; restore T1.0 before we return
	POPRL(T1)		;  ...
	RETURN			; and that's all for now

;   This routine will erase all characters from the current cursor location to
; the end of the line, including the character under the cursor.
EEOL:	PUSHR(T1)		; save T1 so we can use it as a temporary
	CALL(WHERE)		; set P1 = address of the cursor
	RLDI(DP,CURSX)		; get the current column of the cursor
	LDN	DP		; ... and then figure out how many characters
	SMI	MAXX		; ... remain until the end of the line
	PLO	T1		; and save that for later
EEOL1:	LDI	' '		; clear this character to a blank
	STR	P1		; ...
	INC	P1		; ... and advance to the next character
	INC	T1		; count the number of characters cleared
	GLO	T1		; have we reached the end of the line yet ??
	BNZ	EEOL1		; nope - keep going
	IRX			; restore T1 before we return
	POPRL(T1)		; ...
	RETURN			; then that's all there is

	.EJECT
;	.SBTTL	Bell (^G) Function

;   Just like a real terminal, we have a bell that can be sounded by the ^G
; character.  This is implemented using the speaker and fixed frequency tone
; generator on the GPIO card - all we have to do is turn it on (easy) and then
; turn it off again in a little bit (harder!).  To arrange for the speaker
; to be turned off, we set the location BELCNT to a non-zero value.  When ever
; BELCNT is non-zero the end of video frame ISR will decrement the counter
; and, when BELCNT makes the 1->0 transition, turns off the speaker.

BELL:	OUTI(GPIO,SPTONE)	; turn on the speaker
	RLDI(DP,BELCNT)		; point to BELCNT
;  The value we store into BELCNT determines the length of the tone, in frames.
; About one sixth of a second sounds like a good value...
	LDI	10		; ...
	STR	DP		; set BELCNT=30
	RETURN			; that's all we have to do!

	.EJECT
;	.SBTTL	Clear Screen (<ESC>E or ^L/FF) Function

;  This  routine will implement the erase function. This will move the cursor
; to the home position and fill the entire screen with blank characters.
ERASE:	LDI	' '		; fill the screen with a blank character
				; and fall into the fill routine

;   This is a local routine to home the cursor and fill the screen with the
; character contained in D.
FILL:	PLO	P1		; save the fill character for a while
	PUSHR(T1)		; save T1 for a temporary register
	PUSHR(P2)		; we need to use P2 also
	GLO	P1		; now move the fill character to a safe
	PLO	T1		;  ... place
	CALL(HOME)		; go move the cursor to home
	RLDI(P1,SCREEN)		; then point to the start of the screen space
	RLDI(P2,MAXX*MAXY)	; and load the number of characters here
FILL1:	GLO	T1		; get the filler byte back
	STR	P1		; put the fill character in this location
	INC	P1		; and move to the next one
	DEC	P2		; decrement the counter
	GLO	P2		; all done?
	BNZ	FILL1		; nope - keep going
	GHI	P2		; check both halves
	BNZ	FILL1		; ...
	IRX			; restore T1 and P2 before we return
	POPR(P2)		; ...
	POPRL(T1)		; ...
	RETURN			; all done!

	.EJECT
;	.SBTTL	Write Characters to the Screen

;   This routine is called whenever a printing character is received.  This
; character will be written to the screen at the current cusror location.
; After this operation, the cursor will move right one character.  If the
; cursor is at the right edge of the screen, it will not 'wrap around' to the
; next line.  The character to be written should be passed in D.
;
;   Like the VT52, we have both a "normal" mode and an alternate (graphics)
; character set mode.  In graphics character set (aka GCS) mode, if we
; receive an ASCII character from 0x60..0x7E (i.e. a lower case character)
; then it's replaced with the corresponding character from the GCS instead.
; In our particular case, the GCS is stored in the character generator ROM
; locations corresponding to codes 0x00..0x1F, so we have to convert the
; 0x60..0x7E code into this range.
;
;   Note that upper case ASCII characters in the range 0x20..0x5F are not
; affected by the character set mode.  Also note that our graphics font
; isn't necessarily the same as the VT52!
NORMAL:	PUSHD			; save the character for a minute

; Check the character set mode...
	SMI	$60		; is this even a lower case letter anyway?
	BNF	NORMA1		; nope - just continue normally
	RLDI(DP,GCSMOD)		; yes - get the character set mode flag
	LDN	DP		; ...
	BZ	NORMA1		; branch if normal mode
	IRX			; GCS mode - point to the original character
	LDI	$60		; and shift it down to 0x00..0x1F
	SD			; ...
	STXD			; and store it back

; Now store the character in memory (finally!)
NORMA1:	CALL(WHERE)		; calculate the address of the cursor
	POPD			; ....
	STR	P1		; then write the character there

;   After storing the character we want to move the cursor right.  This could
; be as simple as just calling RIGHT:, but but that will stop moving the cursor
; at the right margin.  We'd prefer to have autowrap, which means that we need
; to start a new line if we jsut wrote the 80th character on this line...
	RLDI(DP,CURSX) 		; get the cursor X location
	LDN	DP		; ...
	XRI	MAXX-1		; are we at the right edge?
	LBNZ	RIGHT1		; nope - just move right and return
	LBR	AUTONL		; yes - do an automatic new line

	.EJECT
;	.SBTTL	Interpret Escape Sequences

;   This routine is called whenever an escape character is detected and what
; happens depends, of course, on what comes next.  Unfortunately, that's
; something of a problem in this case - in a real terminal we could simply
; wait for the next character to arrive, but in this case nothing's going
; to happen until we return control to the application. 
;
;   The only solution is to keep a "flag" which lets us know that the last
; character was an ESCape, and then the next time we're called we process
; the current character differently.  Since many escape sequences interpret
; more than one character after the ESCape, we actually need a little state
; machine to keep track of what we shold do with the current character.
ESCAPE:	LDI	EFIRST		; next state is EFIRST (ESCAP1)
ESCNXT:	STR	SP		; save that for a second
	RLDI(DP,ESCSTA)		; point to the escape state
	LDN	SP		; and get the next state back
	STR	DP		; store it for next time
ESCRET:	RETURN			; and then wait for another character

;   Here for the first character after the <ESC> - this alone is enough
; for most (but not all!) escape sequences.  To that end, we start off by
; setting the next state to zero, so if this isn't changed by the action
; routine this byte will by default be the last one in the escape sequence.
ESCAP1:	LDI	0		; set the next state to zero
	CALL(ESCNXT)		; because that's the most likely outcome
	RLDI(DP,CURCHR)		; get the current character back again
	LDN	DP		; ....
	SMI	'A'		; is it less than 'A' ?
	BNF	ESCRET		; bad sequence if it is
	SMI	'Z'-'A'+1	; check the other end of the sequence
	BDF	ESCRET		; still bad
	LDN	DP		; get the escape character back again
	SMI	'A'		; convert to a zero based index
	CALL(LBRI)		; and dispatch to the right routine
	.DW	ESCCHR		; ...
	RETURN			; just return

	.EJECT
;	.SBTTL	Raster Test (<ESC>Q) Function

;   This routine will implement the raster test escape sequence.  The <ESC>Q
; sequence is followed by a single printing character, and the cursor is then
; moved to the home position and the entire screen is filled with this
; character. If the next character after this function should happen to not be
; a printing character, then the screen is filled with blanks...
;
;   Note that this is an extension to the VT52 command set!
RTEST:	LDI	ERNEXT		; wait for the next byte
	LBR	ESCNXT		; store ESCSTA and return

; Here with the raster test character in CURCUR...
RTEST1:	LDI	0		; first set ESCSTA to zero
	CALL(ESCNXT)		; so that this is the end of the sequence
	RLDI(DP,CURCHR)		; then get the current character
	LDN	DP		; ...
	SMI	' '		; make sure it is a printing character
	LBNF	ERASE		; jump if it is .LT. 32
	LDN	DP		; get the character back again
	XRI	$7F		; make sure it isn't RUBOUT
	LBZ	ERASE		; use space instead if it is
	LDN	DP		; nope - one more time
	LBR	FILL		; and go fill the screen with it

	.EJECT
;	.SBTTL	<ESC>Y - Direct Cursor Addressing

;  This routine implements the direct cursor addressing escape sequence.  The
; <ESC>Y sequence is followed by two data bytes which indicate the line and
; column (in that order) that the cursor is to move to. Both values are biased
; by 32 so that they are appear as printing ASCII characters.  The line number
; character should be in the range 32 to 55 (decimal), and the column number
; character may range from 32 to 112 (decimal).  If either byte is out of
; range, then the cursor will only move as far as the margin.
;
;   For example:
;	<ESC>Y<SP><SP>	- move to (0,0) (i.e. home)
;	<ESC>Y7o	- move to (79,23) (i.e. lower right)

; Here for part 1 - <ESC>Y has been received so far...
DIRECT:	LDI	EYNEXT		; next state is get Y
	LBR	ESCNXT		; update ESCSTA and continue

; Part 2 - the current character is Y, save it and wait for X...
DIRECY:	RLDI(DP,CURCHR)		; get the current character
	LDA	DP		; load CURCHR, point to SAVCHR
	STR	DP		; and save CURCHR in SAVCHR
	LDI	EXNEXT		; next state is "get X"
	LBR	ESCNXT		; ...

; Part 3 - CURCHR is X and SAVCHR is Y.
DIRECX:	RLDI(P1,CURCHR)		; point P1 at CURCHR/SAVCHR
	RLDI(DP,CURSX)		; and DP at CURSX/CURSY

;  First handle the X coordinate.  Remember that the cursor moves to the
; corresponding margin if the coordinate give is less than 0 or greater than
; MAXX-1!
	LDN	P1		; get the current (X) addressing byte
	SMI	' '		; adjust for the ASCII bias
	BDF	DIREC1		; branch if greater than zero
	LDI	0		; less than zero - use zero instead
	BR	DIRE12		; change X and proceed
DIREC1:	SMI	MAXX		; would it be greater than MAXX-1?
	BNF	DIRE11		; branch if not
	LDI	MAXX-1		; yes - just use MAXX-1 instead
	BR	DIRE12		; rejoin the main code
DIRE11:	LDN	P1		; the original coordinate is OK
	SMI	' '		; readjust for the bias
DIRE12:	STR	DP		; and update CURSX

; Now handle the Y coordinate (in SAVCHR) the same way...
	INC	P1		; point to SAVCHR
	INC	DP		; and point to CURSY
	LDN	P1		; pretty much the same as before
	SMI	' '		; adjust for ASCII bias
	BDF	DIREC2		; branch if greater than zero
	LDI	0		; nope - use zero instead
	BR	DIRE22		; ...
DIREC2:	SMI	MAXY		; is it too big for the screen?
	BNF	DIRE21		; branch if not
	LDI	MAXY-1		; yes - use the bottom margin instead
	BR	DIRE22		; ...
DIRE21:	LDN	P1		; the value is OK - get it back again
	SMI	' '		; ...
DIRE22:	STR	DP		; and update CURSY

;   Finally, update the cursor on the screen and we're done.  DON'T FORGET to
; change the next state (ESCSTA) to zero to mark the end of this sequence!
	CALL(LDCURS)		; load the cursor
	LDI	0		; next state is zero (back to normal)
	LBR	ESCNXT		; change ESCSTA and return

	.EJECT
;	.SBTTL	Select (<ESC>F) and Deselect (<ESC>G) Graphics Character Set

;   On the VT52, the <ESC>F command selects the alternate graphics character
; set, and the <ESC>G command deselects it.  The SI (Shift In) and SO (Shift
; Out) control characters do the same...

; Enable the graphics character set...
ENAGCS:	RLDI(DP,GCSMOD)		; point to the GCS mode flag
	LDI	$FF		; set it to non-zero to enable
	STR	DP		; ...
	RETURN			; and we're done

; Disable the graphics character set...
DSAGCS:	RLDI(DP,GCSMOD)		; same as before
	LDI	0		; but set the GCS flag to zero
	STR	DP		; ...
	RETURN			; ...

	.EJECT
;	.SBTTL	Write Field Attribute Code (<ESC>N)

;   This routine is called to processes the Write Field Attribute escape
; sequence.  The <ESC>N sequence is followed by a single parameter byte, the
; the lower 6 bits of which are written to screen memory as an 8275 field
; attribute code (refer to the 8275 data sheet for more information).  The
; 8275 is set up in non-transparent attribute mode, so each attribute byte
; requires a character location on the screen (which is blanked by the VSP
; output).
;
;   This allows us to get blinking, reverse video, and underline, as well as
; select any one of four alternate character sets stored in the EPROM.
; Needless to say, the VT52 didn't have this function!
WFAC:	LDI	EANEXT		; wait for the field attribute code
	LBR	ESCNXT		; set ESCSTA and return

; Here when we receive the next byte...
WFAC1:	LDI	0		; first, set ESCSTA to zero
	CALL(ESCNXT)		;  ... to end this escape sequence
	RLDI(DP,CURCHR)		; and then get the current character
	LDN	DP		; ...
	ANI	$3F		; trim it to only six bits
	ORI	$80		; and make it into a field attribute code
	PUSHD			; save it on the stack for NORMA1
	LBR	NORMA1		; and then go store it in screen memory

	.EJECT
;	.SBTTL	Write Line Drawing Code (<ESC>O)

;   This routine is called to processes the Write Line Drawing Code escape
; sequence.  It's pretty much the same "syntax" as the write field attribute
; function.  The <ESC>O sequence is followed by a single parameter byte, the
; the lower 6 bits of which are written to screen memory as an 8275 line
; attribute code.  There are actually only about ten line drawing codes (that's
; only four bits worth), but the lower two bits allow the blink and/or reverse
; video attributes to be applied to any line drawing character. Refer to the
; 8275 data sheet for more information.
WLINE:	LDI	ELNEXT		; wait for a line drawing code
	LBR	ESCNXT		; set ESCSTA and return

; Here when we receive the next byte...
WLINE1:	LDI	0		; first, set ESCSTA to zero
	CALL(ESCNXT)		;  ... to end this escape sequence
	RLDI(DP,CURCHR)		; and then get the current character
	LDN	DP		; ...
	ANI	$3F		; trim it to only six bits
	ORI	$C0		; and make it into a line drawing code
	PUSHD			; save it on the stack for NORMA1
	LBR	NORMA1		; and then go store it in screen memory

	.EJECT
;	.SBTTL	Indirect Table Jump

;   This routine will take a table of two byte addresses, add the index passed
; in the D register, and then jump to the selected routine.  It's used to
; dispatch control characters, escape characters, and the next state for the
; escape sequence state machine.
;
; CALL:
;	 <put the jump index, 0..n, in D>
;	 CALL(LBRI)
;	 .DW	TABLE
;  	 .....
; TABLE: .DW	fptr0	; address of routine 0
;	 .DW	fptr1	;  "   "  "   "   "  1
;	 ....
;
;   Notice that the index starts with zero, not one, and that it's actually
; an index rather than a table offset.  The difference is that the former 
; is multiplied by two (since every table entry is a byte) and the latter
; wouldn't be!
;
;   Since this function is called by a CALL() and it actually jumps to the
; destination routine, that routine can simply execute a RETURN to return
; back to the original caller.  The inline table address will be automatically
; skipped.
LBRI:	SHL			; multiply the jump index by 2
	STR	SP		; and then save it on the stack for later
	LDA	A		; get the high byte of the table address
	PHI	DP		; and save that
	LDA	A		; then the low byte
	ADD			; add in the index
	PLO	DP		; store the low part
	GHI	DP		; and then propagate the carry bit
	ADCI	0		; ...
	PHI	DP		; now DP points to the correct entry
	RLDI(P1,LBRI1)		; then switch the PC to P1 
	SEP	P1		; ...

; Load the address pointed to by DP into the PC and continue
LBRI1:	LDA	DP		; get the high byte of the address
	PHI	PC		; ...
	LDA	DP		; and then the low byte
	PLO	PC		; ...
	SEP	PC		; and away we go!

	.EJECT
;	.SBTTL	Interpret Characters

;   This routine is called whenever a normal (i.e. non-escape sequence)
; character is to be sent to the terminal.  It handles both printing 
; characters and control characters...
VTPUTC_:PLO	BAUD		; save character in a safe place
;   This SEX SP may seem unnecessary.  After all, we just got here via SCRT
; CALL, right?  Well, not necessarily - some code simply LBRs here and doesn't
; guarantee the value of X...
	SEX	SP		; just in case
	PUSHR(DP)		; save DP
	PUSHR(P1)		;  ... and P1
	RLDI(DP,CURCHR)		; point to our local storage
	SEX	DP		; ...
	GLO	BAUD		; get the original character back
	STXD			; store it in CURCHR
	LDXA			; and then load ESCSTA
	BNZ	VTPUT2		; jump if we're processing an escape sequence

; This character is not part of an escape sequence...
	LDX			; get the original character back
	ANI	$7F		; and trim it to 7 bits
	BZ	VTPUT9		; ignore null characters
	XRI	$7F		; and ignore RUBOUTs too
	BZ	VTPUT9		; ...
	LDX			; restore the original character
	SMI	' '		; is this a control character ?
	BNF	VTPUT1		; branch if yes

; This character is a normal, printing, character...
	LDX			; get it back one more time
	CALL(NORMAL)		; display it as a normal character

;   And return...  It's a bit of extra work, but it's really important that
; we return the same value in D that we were originally called with.  Some
; code, especially the part of the BIOS that echos terminal input, depends
; on this!
VTPUT9:	RLDI(DP,CURCHR)		; gotta get back the original data
	LDN	DP		; ...
	PLO	BAUD		; save it in a temporary location
	SEX	SP		; just in case somebody changed it
	IRX			; now restore the registers we used
	POPR(P1)		; ...
	POPRL(DP)		; ...
	GLO	BAUD		; get the character one more time
	RETURN			; and we're done!

; Here if this character is a control character...
VTPUT1:	LDX			; restore the original character
	CALL(LBRI)		; and dispatch to the correct routine
	.DW	CTLTAB		; ...
	BR	VTPUT9		; then return normally

; Here if this character is part of an escape sequence...
VTPUT2:	CALL(LBRI)		; branch to the next state in escape processing
	.DW	ESTATE		; table of escape states
	BR	VTPUT9		; and return

	.EJECT
;	.SBTTL	Output Text String

;   This little routine will pass an entire string of characters to VTPUTC.
; The pointer to the string is passed inline after the CALL(VTPUTS), and the
; the string should be terminated by a NULL byte.  It's actually only used
; internally to this module...
VTPUTS:	PUSHR(P1)		; save P1
	LDA	A		; get the address of the string
	PHI	P1		; save it here
	LDA	A		; ...
	PLO	P1		; ...

;   Remember that VTPUTC saves _all_ registers, so we conveniently don't have to
; worry about saving P1!...
PUTS1:	LDA	P1		; get the next byte
	BZ	PUTS9		; quit when we find a NULL
	CALL(VTPUTC)		; otherwise send it out
	BR	PUTS1		; and keep going

; Here when we reach the end of the string...
PUTS9:	IRX			; restore P1
	POPRL(P1)		;  ...
	RETURN			; and we're done
	
	.EJECT
;	.SBTTL	Control Character Dispatch Table

;   This table is used by LBRI and VTPUTC to dispatch to the correct function
; for any ASCII code .LT. 32.  Any unused control characters should just
; point to NOOP, which simply executes a RETURN instruction.  Note that the
; ASCII NUL code is trapped in VTPUTC and never gets here, but its table
; entry is required anyway to make the rest of the offsets correct.
CTLTAB:	.DW	NOOP		; 0x00 ^@ NUL
	.DW	NOOP		; 0x01 ^A SOH
	.DW	NOOP		; 0x02 ^B STX
	.DW	NOOP		; 0x03 ^C ETX
	.DW	NOOP		; 0x04 ^D EOT
	.DW	NOOP		; 0x05 ^E ENQ
	.DW	NOOP		; 0x06 ^F ACK
	.DW	BELL		; 0x07 ^G BEL - ring the "bell" on the GPIO card
	.DW	LEFT		; 0x08 ^H BS  - cursor left (backspace)
	.DW	TAB		; 0x09 ^I HT  - move right to next tab stop
	.DW	LINEFD		; 0x0A ^J LF  - cursor down and scroll up
	.DW	LINEFD		; 0x0B ^K VT  - vertical tab is the same as LF
	.DW	ERASE		; 0x0C ^L FF  - form feed erases the screen
	.DW	CRET		; 0x0D ^M CR  - move cursor to left margin
	.DW	DSAGCS		; 0x0E ^N SO  - select normal character set
	.DW	ENAGCS		; 0x0F ^O SI  - select graphics character set
	.DW	NOOP		; 0x10 ^P DLE
	.DW	NOOP		; 0x11 ^Q DC1
	.DW	NOOP		; 0x12 ^R DC2
	.DW	NOOP		; 0x13 ^S DC3
	.DW	NOOP		; 0x14 ^T DC4
	.DW	NOOP		; 0x15 ^U NAK
	.DW	NOOP		; 0x16 ^V SYN
	.DW	NOOP		; 0x17 ^W ETB
	.DW	NOOP		; 0x18 ^X CAN
	.DW	NOOP		; 0x19 ^Y EM
	.DW	NOOP		; 0x1A ^Z SUB
	.DW	ESCAPE		; 0x1B ^[ ESC - introducer for escape sequences
	.DW	NOOP		; 0x1C ^\
	.DW	NOOP		; 0x1D ^] GS
	.DW	NOOP		; 0x1E ^^ RS
	.DW	NOOP		; 0x1F ^_ US

NOOP:	RETURN

	.EJECT
;	.SBTTL	Escape Sequence State Table

;   Whenever we're processing an escape sequence, the index of the next
; state is stored in location ESCSTA.  When the next character arrives
; that value is used as an index into this table to call the next state.

#define XX(n,r)	.dw r\n .equ ($-ESTATE-2)/2

ESTATE:	.DW	0		; 0 - never used
	XX(EFIRST,ESCAP1)	; 1 - first character after <ESC>
	XX(EYNEXT,DIRECY)	; 2 - <ESC>Y, get first byte (Y)
	XX(EXNEXT,DIRECX)	; 3 - <ESC>Y, get second byte (X)
	XX(ERNEXT,RTEST1)	; 4 - <ESC>Q, get first byte
	XX(EANEXT,WFAC1)	; 5 - <ESC>N, get attribute byte
	XX(ELNEXT,WLINE1)	; 6 - <ESC>O, get line drawing code

	.EJECT
;	.SBTTL	Escape Sequence Dispatch Table

;   This table is used to decode the first character in an escape sequence
; (not the ESCape, but the one right after the escape!).  It contains only
; letters - the code range checks and ignores anything else...
ESCCHR: .DW	UP		; <ESC>A -- Cursor Up
	.DW	DOWN		; <ESC>B -- Cursor Down
	.DW	RIGHT		; <ESC>C -- Cursor Right
	.DW	LEFT		; <ESC>D -- Cursor Left
	.DW	ERASE		; <ESC>E -- Erase Screen
	.DW	ENAGCS		; <ESC>F -- Select Alternate Character Set
	.DW	DSAGCS		; <ESC>G -- Select ASCII Character Set
	.DW	HOME		; <ESC>H -- Cursor Home
	.DW	RLF		; <ESC>I -- Reverse Line Feed
	.DW	EEOS		; <ESC>J -- Erase to end of Screen
	.DW	EEOL		; <ESC>K -- Erase to end of Line
	.DW	NOOP		; <ESC>L -- Unimplemented
	.DW	NOOP		; <ESC>M -- Unimplemented
	.DW	WFAC		; <ESC>N -- Write Field Attribute Code
	.DW	WLINE		; <ESC>O -- Write Line Drawing Code
	.DW	NOOP		; <ESC>P -- Unimplemented
	.DW	RTEST		; <ESC>Q -- Unimplemented
	.DW	RTEST		; <ESC>R -- Raster Test
	.DW	NOOP		; <ESC>S -- Unimplemented
	.DW	TEST		; <ESC>T -- Unimplemented
	.DW	NOOP		; <ESC>U -- Unimplemented
	.DW	NOOP		; <ESC>V -- Unimplemented
	.DW	NOOP		; <ESC>W -- Unimplemented
	.DW	NOOP		; <ESC>X -- Unimplemented
	.DW	DIRECT		; <ESC>Y -- Direct Cursor Addressing
	.DW	NOOP		; <ESC>Z -- Unimplemented

	.EJECT
;	.SBTTL	VT1802 Test/Calibrarion Function

;   This function fills the screen buffer with a test pattern.  Unlike the
; POST test in INIT75, this test is used to adjusting the monitor and checking
; out your character generator - it's not really a test of the VT1802 hardware.
; This function is normally invoked by an escape sequence and it returns as
; soon as the display buffer is filled - the test pattern will remain until
; the 1802 code writes something else to the display...
TEST:	LDI	$7F		; first fill the screen 
	CALL(FILL)		;  ... with "pin cushion" symbols

;   The only goal of all this code is to clear out a rectangle in the middle
; of the screen.  It takes more code then I'd like, but there's no other way!
	RLDI(P1,CURSY)		; point to the Y location
	LDI	2		; start on line 2
	STR	P1		; ...
TEST10:	RLDI(P1,CURSX)		; reset X to our right margin
	LDI	4		; ...
	STR	P1		; ...

; Store 72 spaces in screen memory starting at the current cursor location..
	CALL(WHERE)		; get the screen buffer address in P1
	LDI	0		; count the characters stored
	PLO	DP		; here...
TEST11:	LDI	' '		; store spaces
	STR	P1		; ...
	INC	P1		; ...
	INC	DP		; count the characters stored
	GLO	DP		; ...
	SMI	72		; have we done a line?
	BL	TEST11		; nope - keep going

; Advance to the next line ...
	RLDI(P1,CURSY)		; get the current Y location
	LDN	P1		; ...
	ADI	1		; increment the line number
	STR	P1		; put it back
	SMI	22		; have we done 18 lines?
	BL	TEST10		; nope - go do more

;   Now we have a "frame" of pin cushion symbols with a blank rectangle in the
; middle.  Let's fill all that in with demos of the various video attributes,
; and the character sets...
	CALL(VTPUTS)		; first a little self promotion
	.DW	TSTMS1		;  ...
	CALL(VTPUTS)		; display the name and version number
	.DW	RIGHTS		;  ... of this firmware
	CALL(VTPUTS)		; then display everything else
	.DW	TSTMS2		; ...
	RETURN			; and we're done here!

; Messages...
TSTMS1:	.TEXT	"\033Y$'Spare Time Gizmos COSMAC Elf 2000 \000"
TSTMS2:	.TEXT	"\033Y'e\033N@\033Y')NORMAL TEXT\033N UNDERLINED TEXT"
	.TEXT	"\033NPREVERSE VIDEO TEXT\033NBBLINKING TEXT"
	.TEXT	"\033Y*F\033N@\033Y*&\033NP     GRAPHICS CHARACTER SET"
	.TEXT	"\033Y+'\033F`abcdefghijklmnopqrstuvwxyz{|}~\033G"
	.TEXT	"\033Y*i\033N@\033Y*H\033NP       DEFAULT CHARACTER SET"
	.TEXT	"\033Y+I !\"#$%&'()*+,-./0123456789:;<=>?"
	.TEXT	"\033Y,I@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_"
	.TEXT	"\033Y-I`abcdefghijklmnopqrstuvwxyz{|}~"
	.DB	0

	.EJECT
	.END
