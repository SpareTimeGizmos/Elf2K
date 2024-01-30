# Elf2K
The Spare Time Gizmos’ COSMAC Elf 2000 is a reproduction of the original COSMAC Elf as published in the pages of Popular Electronics magazine, August 1976, and the Elf 2000 was itself published in the August and September 2006 issues of Nuts and Volts magazine.

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
