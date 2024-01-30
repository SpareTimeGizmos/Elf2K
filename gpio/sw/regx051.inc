;++
;regx051.inc
;Header file for the Atmel 89C1051U, 89C2051, 89C4051.
;--

; Registers
SP	DATA	081H
DPL	DATA	082H
DPH	DATA	083H
PCON	DATA	087H
TCON	DATA	088H
TMOD	DATA	089H
TL0	DATA	08AH
TL1	DATA	08BH
TH0	DATA	08CH
TH1	DATA	08DH
P1	DATA	090H
SCON	DATA	098H
SBUF	DATA	099H
IE	DATA	0A8H
P3	DATA	0B0H
IP	DATA	0B8H
PSW	DATA	0D0H
ACC	DATA	0E0H
B	DATA	0F0H

;PCON Bit Values
IDL	EQU	001H
STOP	EQU	002H
EWT	EQU	004H
EPFW	EQU	008H
WTR	EQU	010H
PFW	EQU	020H
POR	EQU	040H
SMOD	EQU	080H

;TCON Bit Registers
IT0	BIT	088H
IE0	BIT	089H
IT1	BIT	08AH
IE1	BIT	08BH
TR0	BIT	08CH
TF0	BIT	08DH
TR1	BIT	08EH
TF1	BIT	08FH

;TMOD Bit Values
T0_M0	EQU	001H
T0_M1	EQU	002H
T0_CT	EQU	004H
T0_GATE	EQU	008H
T0_MASK	EQU	00FH
T1_M0	EQU	010H
T1_M1	EQU	020H
T1_CT	EQU	040H
T1_GATE	EQU	080H
T1_MASK	EQU	0F0H

;P1 Bit Registers
P1_0	BIT	090H
P1_1	BIT	091H
P1_2	BIT	092H
P1_3	BIT	093H
P1_4	BIT	094H
P1_5	BIT	095H
P1_6	BIT	096H
P1_7	BIT	097H
AIN0	BIT	090H       ; + Analog comparator input
AIN1	BIT	091H       ; - Analog comparator input

;SCON Bit Registers
RI	BIT	098H
TI	BIT	099H
RB8	BIT	09AH
TB8	BIT	09BH
REN	BIT	09CH
SM2	BIT	09DH
SM1	BIT	09EH
SM0	BIT	09FH

;IE Bit Registers
EX0	BIT	0A8H       ; 1=Enable External interrupt 0
ET0	BIT	0A9H       ; 1=Enable Timer 0 interrupt
EX1	BIT	0AAH       ; 1=Enable External interrupt 1
ET1	BIT	0ABH       ; 1=Enable Timer 1 interrupt
ES	BIT	0ACH       ; 1=Enable Serial port interrupt
ET2	BIT	0ADH       ; 1=Enable Timer 2 interrupt
EA	BIT	0AFH       ; 0=Disable all interrupts

;P3 Bit Registers (Mnemonics & Ports)
P3_0	BIT	0B0H
P3_1	BIT	0B1H
P3_2	BIT	0B2H
P3_3	BIT	0B3H
P3_4	BIT	0B4H
P3_5	BIT	0B5H
; P3_6 Hardwired as AOUT
P3_7	BIT	0B7H

RXD	BIT	0B0H       ; Serial data input
TXD	BIT	0B1H       ; Serial data output
INT0	BIT	0B2H       ; External interrupt 0
INT1	BIT	0B3H       ; External interrupt 1
T0	BIT	0B4H       ; Timer 0 external input
T1	BIT	0B5H       ; Timer 1 external input
AOUT	BIT	0B6H       ; Analog comparator output

;IP Bit Registers
PX0	BIT	0B8H
PT0	BIT	0B9H
PX1	BIT	0BAH
PT1	BIT	0BBH
PS	BIT	0BCH

;PSW Bit Registers
P	BIT	0D0H
FL	BIT	0D1H
OV	BIT	0D2H
RS0	BIT	0D3H
RS1	BIT	0D4H
F0	BIT	0D5H
AC	BIT	0D6H
CY	BIT	0D7H

; Interrupt vectors...
EX0VEC  EQU     003H    ; External interrupt 0
IT0VEC  EQU     00BH    ; Interval timer 0
EX1VEC  EQU     013H    ; External interrupt 1
IT1VEC  EQU     01BH    ; Interval timer 1
SIOVEC  EQU     023H    ; Serial port 0
