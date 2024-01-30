;	TITLE	 COSMAC Elf STG Monitor EPROM Definitions

;++
;       Copyright (C) 2006-2020 By Spare Time Gizmos, Milpitas CA.
;
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
; DESCRIPTION:
;   This file contains definitions for the Spare Time Gizmos monitor EPROM for
; both the Elf 2000 and the Pico Elf.  It's used by the monitor itself and the
; video module, as well as any user programs that care to call the monitor.
;
; REVISION HISTORY:
; dd-mmm-yy	who     description
; 22-Feb-06	RLA	Move BIOS declarations to bios.inc
; 30-Nov-20     RLA	Add PicoElf
;--

;0000000001111111111222222222233333333334444444444555555555566666666667777777777
;1234567890123456789012345678901234567890123456789012345678901234567890123456789

	.EJECT
;	TITLE	Register Definitions and Subroutine Linkages

; Hardware defined registers...
PC0	.EQU	0	; PC register for initialization
DMAPTR	.EQU	0	; Register used for DMA
INTPC	.EQU	1	; PC register for interrupt service
SP	.EQU	2	; Stack pointer

; Standard call and return (aka SCRT) registers...
PC	.EQU	3	; Normal PC register (both for BOOTS and user programs)
CALLPC	.EQU	4	; The PC register dedicated to the CALL routine
RETPC	.EQU	5	; " "	"	"	"	" RETURN "
A	.EQU	6	; Call linkage register (i.e. the argument list pointer)

; Parameter passing registers for subroutines...
P1	.EQU	0FH	; The first of 3 parameter/permanant registers
P2	.EQU	0DH	;  "  second " "	"		"
P3	.EQU	0CH	;  "  third  " "	"		"
P4	.EQU	0BH	;  and fourth...

;  DP always contains in its upper byte the monitor's data page number (e.g.
; RAMPAGE) whenever the monitor is running.  This allows code to address
; variables on the monitor's data page simply by switching values in the low
; byte...
DP	.EQU	7	; monitor's data page

; Temporary (sometimes extremely temporary!) registers...
T1	.EQU	9	; The first of 4 temporary registers
T2	.EQU	0AH	; " second " "	"

;   The BAUD register (RE) is used to hold the baud rate constant for the
; bit banged serial port in RE.1.  Besides that, RE.0 (BAUD.0) is used as a
; temporary location everywhere, including in the SCRT routines!
;
;   If BAUD.1 & 0xFE != 0, then the bit banged "UART" is in use and
; BAUD.1 & 0xFE determines the baud rate (it's the delay constant).
; In this case the LSB of BAUD.1 (i.e. BAUD.1 & 1) is the local echo
; flag - if this is 1 then all input is echoed back to the terminal.
; If it's zero, no echo is performed.
;
; If (BAUD.1 & $FE) == 0 (i.e. the baud rate is zero) then the hardware UART
; is used for console I/O. If (BAUD.1 & $FE) == $FE then the Elf 2000 80
; column video card and PS/2 keyboard interface are used for console I/O. In
; either case, the LSB of BAUD.1 still controls local echo.
BAUD	.EQU	0EH	; magic baud rate constant for terminal I/O

; Standard call and return macros...
#define CALL(ADDR)	SEP CALLPC\ .DW ADDR
#define RETURN		SEP RETPC

	.EJECT
;	TITLE	Useful Macro Definitions

; Advance the current origin to the next page...
#define PAGE	.ORG (* + $FF) & $FF00

; Return the high and/or low bytes of a 16 bit value...
#define HIGH(x)	(((x)>>8) & $FF)
#define LOW(x)	( (x) & $FF)

; Push and Pop the D register from the stack...
#define PUSHD	STXD
#define POPD	IRX\ LDX

; Set and clear the DF flag...
#define CDF	ADI 0
#define SDF	SMI 0

;   Sixteen bit register operations...  Note that these are all compatible with
; the 1804/5/6 CPU and, if you had one of those CPUs and were so inclined, you
; could replace these macros with the appropriate extended instructions and save
; quite a bit of code space ...
;
; Register load immedate...
#define RLDI(R,V)	LDI HIGH(V)\ PHI R\ LDI LOW(V)\ PLO R
; Copy source register to the destination...
#define RCOPY(D,S)	GHI S\ PHI D\ GLO S\ PLO D
; Clear a register...
#define RCLEAR(R)	LDI $00\ PHI R\ PLO R
; Shift a sixteen bit register left 1 bit...
#define RSHL(R)		GLO R\ SHL\ PLO R\ GHI R\ SHLC\ PHI R
; Push a complete 16 bit register...
#define PUSHR(r)	GLO r\ STXD\ GHI r\ STXD
; Pop a 16 bit register...
#define POPR(r)		LDXA\ PHI r\ LDXA\ PLO r
; Pop the last register in a series...
#define POPRL(r)	LDXA\ PHI r\ LDX\ PLO r

; Enable and disable interrupts (P = PC)...
#define INT_ON		SEX PC\ RET\ .DB (SP<<4) | PC
#define INT_OFF		SEX PC\ DIS\ .DB (SP<<4) | PC

;   This macro displays a POST code on the LEDs.  It can only be used during
; the system initialization phase because it assumes that P=0.  Notice that
; it changes the X register!
#define	POST(n)		SEX 0\ OUT LEDS\ .DB n

;   This macro does the equivalent of an "OUT immediate" instruction with the
; specified port and data.  It's very similar to the POST macro, but it assumes
; the standard register usage while the monitor is running...
#define	OUTI(p,n)	SEX PC\ OUT p\ .DB n\ SEX SP

; Debugger breakpoint (cause a trap to TRAP:)...
#define	BREAK	MARK\ SEP 1

; Common ASCII characters...
CHCTC	.EQU	$03		; control-C
CHBSP	.EQU	$08		; backspace
CHTAB	.EQU	$09		; (horizontal) tab
CHLFD	.EQU	$0A		; line feed
CHCRT	.EQU	$0D		; carriage return
CHFFD	.EQU	$0C		; form feed
CHESC	.EQU	$1B		; escape
CHRUB	.EQU	$7F		; rubout (and filler)

; Creat a command table entry ...
#define CMD(len,name,routine)	.DB len, name, 0\ .DW routine

; Macros for some common BIOS functions...
#define OUTSTR(pstr)	RLDI(P1,pstr)\ CALL(F_MSG)
#define OUTCHR(c)	LDI c\ CALL(F_TTY)

;   INLMES() simply prints out an ASCII string "in line", which saves us the
; trouble of defining a label and a .TEXT constant for OUTSTR().  The catch
; is that TASM HAS A 16 CHARACTER LIMIT ON THE LENGTH OF A MACRO ARGUMENT!
; That's not many when it comes to messages, so use INLMES with caution...
#define	INLMES(str)	CALL(F_INMSG)\ .TEXT str \ .DB 0

	.EJECT
