//++
//gpio.h
//
// Copyright (C) 2005 by Spare Time Gizmos.  All rights reserved.
//
// This file is part of the Spare Time Gizmos'??????? firmware.
//
// This firmware is free software; you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by the Free
// Software Foundation; either version 2 of the License, or (at your option)
// any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
// more details.
//
// You should have received a copy of the GNU General Public License along with
// this program; if not, write to the Free Software Foundation, Inc., 59 Temple
// Place, Suite 330, Boston, MA  02111-1307  USA.
//
// DESCRIPTION
//   This file contans mostly hardware related defintions (e.g. I/O ports and
// bits, clock speeds, memory sizes, etc) for the PS2 keyboard to parallel project.
//
// REVISION HISTORY:
// dd-mmm-yy    who     description
//  4-Feb-06    RLA     New file.
//  7-May-06	RLA	Add APPLICATION_KEYPAD (P3_1) external jumper
//			Add SWAP_CAPSLOCK_AND_CONTROL (P3_0) jumper
//--
#ifndef _gpio_h_
#define _gpio_h_

// System clock information...
#define	CPU_CLOCK        11059200L	// 8051 CPU crystal frequency

// System configuration parameters...
#ifndef VERSION
#define VERSION		000		// version number of this firmware
#endif
#ifndef ROMSIZE
#error Define ROMSIZE!!!		// size of the Flash ROM used ...
#endif

// Status LED ...
#define LED_BIT		P3_5
#define LED_ON	{LED_BIT = 0;}
#define LED_OFF	{LED_BIT = 1;}

// External options jumpers...
#ifndef DEBUG
#define APPLICATION_KEYPAD	  	\
	(P3_1 == 0)			// JP3 - application keypad mode (active low!)
#define SWAP_CAPSLOCK_AND_CONTROL	\
	(P3_0 == 0)			// JP4 - caps lock/control mode (active low!)
#else
#define APPLICATION_KEYPAD	  (1)	// in DEBUG mode these two pins are used
#define SWAP_CAPSLOCK_AND_CONTROL (1)	//  ... for the serial port instead
#endif

// Handshaking flags...
#define SET_KEY_DATA_RDY P3_4		// set the KEY_DATA_RDY flip-flop
#define KEY_DATA_RDY	 P3_3		// byte is waiting for the host

// Public variables in the main module...
extern char const code g_szFirmware[];
#define g_wROMChecksum (*((PCWORD) (ROMSIZE-2)))

#endif	// _gpio_h_

