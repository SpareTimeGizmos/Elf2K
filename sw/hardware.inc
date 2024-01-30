;	TITLE	 COSMAC Elf 2000 and PicoElf Hardware Definitions

;++
;       Copyright (C) 2006-2021 By Spare Time Gizmos, Milpitas CA.
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
;   This file contains hardware related definitions - I/O port addresses,
; bits and fields in I/O registers, EF definitions, macros, etc - for both
; the standard Spare Time Gizmos COSMAC Elf 2000 and Mike Riley's PicoElf.
;
; REVISION HISTORY:
; dd-mmm-yy	who	what
; 23-Fed-06	RLA	Add R/W NVR/UART/IDE/PPI macros...
; 29-Dec-20     RLA	Merge in PicoElf definitions
;			Add NVR BOOTF definitions
;--
;0000000001111111111222222222233333333334444444444555555555566666666667777777777
;1234567890123456789012345678901234567890123456789012345678901234567890123456789

	.EJECT
;	TITLE	Classic Elf Hardware Definitions

; Classic I/O ports ...
LEDS	 .EQU	4	; 2 digit hexadecimal LED display (write only)
SWITCHES .EQU	4	; toggle switches or HEX keypad (read only)
#ifdef PIXIE
CDP1861	 .EQU	1	; CDP1861 pixie chip
#endif

;   These macros branch on the classic Elf INPUT switch which, by tradition,
; is always connected to EF4.  If the hexadecimal keypad is used, then this
; is used to signal data ready...
#ifdef ELF2K
#define B_INPUT(x)	B4	x
#define BN_INPUT(x)	BN4	x
#endif

;   These macros turn the CDP1861 video ON and OFF.  Note that since VIDEO ON
; is an input instruction, it destroys one byte on the stack.  And, since
; PIXIE OFF is an output, it increments the X register.  These macros attempt
; to correct for both conditions...
;
;   BTW, note that the VT1802 80 column video card also uses port 1, so
; you have to be careful not to execute these IOTs if the VT1802 is in use.
#ifdef PIXIE
#define PIXIE_ON	SEX SP\ DEC SP\ INP CDP1861\ INC SP
#define PIXIE_OFF	SEX SP\ OUT CDP1861\ DEC SP
#endif

;   These macros define the console serial port configuration.  They're used
; only if the built-in bit banging routines are enabled (i.e. BIOS=0) - if
; Mike Riley's BIOS is in place, then it handles the console I/O.  BTW, the
; configuration is done this way so that it's easy to change the EF line used
; for input and to accomodate various combinations of inverted/non-inverted
; serial interfaces...
#ifndef BIOS
#define B_SERIAL(x)	BN3	x
#define BN_SERIAL(x)	B3	x
#define SET_SERIAL	REQ
#define RESET_SERIAL	SEQ
#endif

	.EJECT
;	TITLE	UART/RTC/NVR Card Definitions

; I/O ports used by the Elf 2000 Disk/UART/RTC/NVR card ...
#ifdef ELF2K
NVR_SELECT	.EQU	2	; NVR/RTC address (write only)
NVR_DATA	.EQU	3	; NVR/RTC data port (read/write)
UART_SELECT	.EQU	2	; UART register select (write only)
UART_DATA	.EQU	3	; UART data port (read/write)
IDE_SELECT	.EQU	2	; IDE register select (write only)
IDE_DATA	.EQU	3	; IDE data register (read/write)
#endif

; I/O ports used by the PicoElf UART/RTC/NVR card ...
#ifdef PICOELF
NVR_SELECT	.EQU	6	; NVR/RTC address (write only)
NVR_DATA	.EQU	7	; NVR/RTC data port (read/write)
UART_SELECT	.EQU	6	; UART register select (write only)
UART_DATA	.EQU	7	; UART data port (read/write)
IDE_SELECT	.EQU	2	; IDE register select (write only)
IDE_DATA	.EQU	3	; IDE data port (read/write)
#endif

;   16450/16550 UART register addresses and bits ...  Note that these
; addresses all have $10 addded to them - this allows them to be written
; directly to the DSELECT register...
RBR	.EQU	$10	; receiver buffer register (DLAB = 0) (R/O)
THR	.EQU	$10	; transmitter holding register (DLAB = 0) (W/O)
DLL	.EQU	$10	; divisor latch low byte (DLAB = 1) (R/W)
IER	.EQU	$11	; interrupt enable register (DLAB = 0) (R/W)
DLH	.EQU	$11	; divisor latch high byte (DLAB = 1) (R/W)
IIR	.EQU	$12	; interrupt identification register (R/O)
FCR	.EQU	$12	; FIFO control register (W/O)
LCR	.EQU	$13	; line control register (R/W)
DLAB	  .EQU	  $80	;  divisor latch access bit
MCR	.EQU	$14	; modem control register (R/W)
LSR	.EQU	$15	; line status register (R/O)
DR	  .EQU	  $01	;  data ready
OE	  .EQU	  $02	;  overrun error
PE	  .EQU	  $04	;  parity error
FE	  .EQU	  $08	;  framing error
THRE	  .EQU	  $20	;  transmitter holding register empty
TEMT	  .EQU	  $40	;  transmitter empty
MSR	.EQU	$16	; modem status register (R/O)
SCR	.EQU	$17	; scratch register (450/550 only!)

;   DS1287/DS12887/DS12887A NVR and RTC definitions...  Note that these
; addresses all have $80 added to what you'll find in the data sheet -
; this allows them to be written directly to the DSELECT register...
NVRA	.EQU	$8A	; register "A" address
UIP	 .EQU	 $80	;  update in progress bit
DV2	 .EQU	 $40	;  oscillator control bit
DV1	 .EQU	 $20	;    "    "     "  "   "
DV0	 .EQU	 $10	;    "    "     "  "   "
NVRB	.EQU	$8B	; register "B" address
SQWE	 .EQU    $08	;  square wave enable
DM	 .EQU	 $04	;  (binary) data mode
HR24	 .EQU	 $02	;  24 hour mode
DSE	 .EQU	 $01	;  daylight savings time enable
NVRC	.EQU	$8C	; register "C" address
PF	 .EQU	 $40	;  periodic interrupt flag
NVRD	.EQU	$8D	; register "D" address
VRT	 .EQU	 $80	;  valid RAM and TIME bit (battery OK)
NVRFREE	.EQU	$8E	; first free RAM location

; Address map of monitor data stored in NVR...
NVRBASE	.EQU	$00	; offset of monitor block in NVR (relative to NVRFREE!)
NVRBOOT	 .EQU NVRBASE+0	; three bytes for the boot flag and restart address
ABTNONE	  .EQU	$FF	;  no autoboot (enter monitor command loop)
ABTADDR	  .EQU  $5A	;  jump to restart address given
ABTDISK	  .EQU	$A5	;  attempt to boot from IDE master 
NVRBAUD	 .EQU NVRBOOT+3	; two bytes for BAUD1 and BAUD0
NVRVERS	 .EQU NVRBAUD+2	; associated monitor version
NVRSIZE	 .EQU NVRVERS+1	; number of NVR bytes used by monitor

; These macros will read and write NVR and UART registers ...
#define WNVR(r,v)	OUT NVR_SELECT \ .DB r\ OUT NVR_DATA\ .DB v
#define RNVR(r)		OUT NVR_SELECT \ .DB r\ SEX SP\ INP NVR_DATA
#define WUART(r,v)	OUT UART_SELECT\ .DB r\ OUT UART_DATA\ .DB v
#define RUART(r)	OUT UART_SELECT\ .DB r\ SEX SP\ INP UART_DATA

	.EJECT
;	TITLE	IDE Definitions

; Classic IDE register definitions...
IDEDATA	.EQU	$00	; data register (R/W)
IDEERR	.EQU	$01	; error register (R/O)
IDESCT	.EQU	$02	; sector count (R/W)
IDELBA0	.EQU	$03	; LBA register (low byte)
IDELBA1	.EQU	$04	;  "     "
IDELBA2	.EQU	$05	;  "     "
IDELBA3	.EQU	$06	;  "     "     (high byte)
IDECMD	.EQU	$07	; command register (W/O)
IDESTS	.EQU	$07	; status register (R/O)

; These macros will read and write IDE registers ...
#define WIDE(r,v)	OUT IDE_SELECT\ .DB r\ OUT IDE_DATA\ .DB v
#define RIDE(r)		OUT IDE_SELECT\ .DB r\ SEX SP\ INP IDE_DATA

	.EJECT
;	TITLE	VT1802 80 Column Video Card Definitions

#ifdef ELF2K
;   In case you don't already know, the "brains" of the VT1802 is an Intel 8275
; CRT controller chip.  Most of the definitions you'll find here, with the
; exception of the 1802 port addresses, are for that chip.

CRTCP	.EQU	1		; CRTC parameter port

CRTCC	.EQU	5		; CRTC command port
CRTC_RESET	.EQU	$00	;  RESET command
CRTC_START	.EQU	$20	;  START display command
CRTC_STOP	.EQU	$40	;  STOP display command
CRTC_LDCURS	.EQU	$80	;  LOAD CURSOR command
CRTC_EI		.EQU	$A0	;  ENABLE INTERRUPT command
CRTC_DI		.EQU	$C0	;  DISABLE INTERRUPT command
CRTC_PRESET	.EQU	$E0	;  PRESET COUNTERS command

CRTCS	.EQU	5		; CRTC status port
CRTC_IE		.EQU	$40	;  INTERRUPT ENABLE bit
CRTC_IR		.EQU	$20	;  INTERRUPT REQUEST (end of frame)
CRTC_LP		.EQU	$10	;  LIGHT PEN hit detected
CRTC_IC		.EQU	$08	;  IMPROPER COMMAND
CRTC_VE		.EQU	$04	;  VIDEO ENABLE
CRTC_DU		.EQU	$02	;  DMA UNDERRUN
CRTC_FO		.EQU	$01	;  FIFO OVERRUN
#endif

	.EJECT
;	TITLE	PS/2 Keyboard Definitions

;   The PS/2 keyboard interface (courtesy of the 89C2051 APU on the Elf 2000
; GPIO card!) just outputs 7 bit parallel ASCII characters to this I/O port.
PS2KBD	.EQU	7	; PS/2 keyboard data port

;   The keyboard interface also sets the EF2 flag whenever it has data
; ready for the 1802 to read...
#define BPS2(x)		B2	x
#define BNPS2(x)	BN2	x

	.EJECT
;	.TITLE	GPIO Card Definitions


#ifdef ELF2K
;   I/O Ports used by the GPIO card.  Note that only one data port is used
; by the PPI even though it actually has four internal registers - the actual
; PPI register accessed depends on the setting of the PPI_Ax bits in the
; GPIO control register.  Also note that the GPIO control register is write
; only - the "read side" of this I/O port is the keyboard data register.
PPI	.EQU	6	; PPI data read/write 
GPIO	.EQU	7	; write GPIO control register

; GPIO Control register bits...
SPEN	.EQU	$20	; enable loading of SP0-1
SP1	.EQU	$10	;  speaker mode bit 1
SP0	.EQU	$08	;   "  "    "    "  0
PPIEN	.EQU	$04	; enable loading of PPIA0-1
PPIA1	.EQU	$02	;  PPI register select bit 1
PPIA0	.EQU	$01	;   "   "   "     "     "  0

; Speaker mode settings...
SPOFF	.EQU	(SPEN)			; speaker off
SPQ	.EQU	(SPEN+SP1)		; speaker follows Q output
SPTONE	.EQU	(SPEN+SP0)		; speaker continuous tone
SPON	.EQU	(SPEN+SP1+SP0)		; speaker "on" (click)

; PPI register mnemonics...
PPIPA	.EQU	(PPIEN)			; select PPI port A
PPIPB	.EQU	(PPIEN+PPIA0)		;  "  "   "   "   B
PPIPC	.EQU	(PPIEN+PPIA1)		;  "  "   "   "   C
PPICTL	.EQU	(PPIEN+PPIA0+PPIA1)	;  "  "   "   " control register

; Read and write PPI registers, loading the PPI register select bits first...
#define WPPI(r,v)	OUT GPIO\ .DB r\ OUT PPI\ .DB v
#define RPPI(r)		OUT GPIO\ .DB r\ SEX SP\ INP PPI
#endif

	.EJECT
