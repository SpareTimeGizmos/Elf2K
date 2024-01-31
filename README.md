# COSMAC Elf 2000

## Overview

The Spare Time Gizmos COSMAC Elf 2000 is a reproduction of the original COSMAC Elf as published in the pages of Popular Electronics magazine, August 1976.  The Spare Time Gizmos Elf 2000 was itself published in the August and September 2006 issues of Nuts and Volts magazine.

Although I tried to keep the look and feel of the original, I had no hesitation about updating the Elf 2000 with the “latest” in hardware. Unlike its ancestor, the Spare Time Gizmos’ COSMAC Elf 2000 features:

* An expanded memory to 32K RAM and an optional 32K EPROM. The EPROM, if installed, contains a power on self test, extended hardware diagnostics, an Editor/Assembler, interpreters for the BASIC, FORTH and CHIP-8 languages, and a BIOS and bootstrap for the ElfOS disk operating system. A jumper is included to allow the CPU to start up at address 0x8000 (EPROM) rather than the normal 0x0000 (RAM).

* An included CDP1861 Pixie chip video display circuit. If you don't have an 1861, the Elf 2000 has space and standoffs to mount a daughter board that plugs into the 1861 socket and contains a discrete logic replacement for the 1861.

* An I/O expansion connector and mounting holes for I/O daughter cards that fit on top of the main board.

* An optional lithium coin cell and a Dallas DS1210 NVR controller to make the RAM non-volatile. Any programs you toggle in or download today will still be there tomorrow!

* A true RS-232 compatible serial port using a DS275 EIA level shifter and a DE9F connector.

* Fully decoded I/O ports, including the CDP1861, switches and display, so there will be no conflicts with any add on peripherals. In addition, all I/O decoding, memory mapping and other control functions are implemented in a 22V10 GAL so they can be easily changed without any wiring modifications.

* Six TIL311 displays for a full address and data display.

* Switches mounted on a separate piece of plastic or aluminum, like the original ELF, that connect to a header on the Elf 2000 PC board. If you don't like toggle switches, the Elf 2000 can also accommodate a Super Elf style hex keypad and push button controls.

* An automatic bootstrap to allow the Elf 2000 to be used without any switches or keypad. On power up, it can wait for download from a PC, or automatically begin running a program stored in EPROM or non-volatile RAM. A VCC low voltage monitor in the Elf 2000 ensures that the CPU is reset on power up and power down regardless of the switch settings.

* A circuit that works with either the original CDP1802 chip or any of the later CDP1804/1805/1806 chips. The classic Elf "load" mode, of course, requires a genuine 1802 chip.

## Expansion Options

A number of daughter cards and other expansion options also exist for the Elf 2000, including:

* STG1681 Pixie Graphics Replacement - If you can't get a CDP1861 Pixie graphics chip then don't despair; the Spare Time Gizmos STG1861 emulator is built on a small daughter card that fits on top of the main Elf 2000 board and plugs into the CDP1861 socket.  The STG1861 uses two PLDs and two 74HCxx TTL chips to emulate the original CDP1861 and is an exact functional replacement for the CDP1861.  No software changes are required and, in fact, the software can't tell the difference!

* Disk, UART and RTC Board - Designed to allow you to run the ElfOS disk operating system, this daughter card contains a CompactFlash/IDE/ATA interface, including an onboard CompactFlash socket and also a standard 40 pin male header for connecting an external drive.  This board also contains an 8250/16450/16550 UART with a programmable baud rate generator and partial modem control.  Lastly, a time of day clock and non-volatile RAM is also provided using the DS12887A, DS12887, DS1287 or MC146818A chips.

* 80 Column Text Video Board - This daughter card is able to generate a real 80 column by 24 line text display on a CGA compatible CRT or RS-170 composite video monitor.  Reverse video, underline, and blinking video attributes and four different character sets may be selected and simultaneously displayed under software control. The 1802's DMA system to fetch ASCII characters directly from a buffer anywhere in RAM or EPROM and, unlike the CDP1861 Pixie, the video timing for the video card is independent of the CPU clock.  The EPROM contains a VT52 terminal emulator that works with the VT1802 and takes care of all the work necessary for maintaining the display. The firmware allows the VT1802 to be used as a replacement for the console terminal and works with BASIC, Forth, EDIT/ASM, or ElfOS.

* General Purpose I/O Card - This daughter card integrates three independent I/O functions onto a single card.  The first, a PS/2 keyboard interface converts the PS/2 protocol and presents the keystrokes the 1802 as if it were a simple parallel ASCII keyboard.  Next is an 8255 programmable parallel I/O (PPI) chip which provides 24 I/O bits that can be configured as inputs, outputs, or as an 8 bit bidirectional port.  And lastly there is a speaker for generating arbitrary tones or even simple music. 

* Music Card - This card contains an AY-3-8912 three channel programmable sound generator chip.  This sound chip was very popular in many arcade games and personal computers of the 1980s, including the ZX Spectrum and the TRS-80 CoCo. 

* Hexadecimal Keypad - This accessory board replaces the standard toggle switches with a push button keypad similar to the Quest Super Elf.  Sixteen keys are provided for direct hexadecimal entry, and five additional buttons (RESET, RUN, LOAD, MP and INPUT) are for mode control.

* Embedded Elf - Not an accessory as such, but a complete Elf in itself, the Embedded Elf is a slightly simplified and much smaller version of the Elf 2000. The Embedded Elf is exactly the same size and form factor as, and stacks perfectly with, any of the above daughter cards to form a cute little cube. The Embedded Elf can run the same software as the Elf 2000 and uses the exact same firmware EPROM as the Elf 2000.
