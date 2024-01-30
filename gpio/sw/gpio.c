//++
//gpio.c - Elf 2000 GPIO PS/2 to Parallel ASCII conversion
//
// Copyright (C) 2006 by Spare Time Gizmos.  All rights reserved.
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
//REVISION HISTORY:
// dd-mmm-yy    who     description
//  4-Feb-06    RLA     New file.
//  8-May-06	RLA	Don't call InitializeDebugSerial() unless DEBUG is defined
//			Shorten and combine firmware/copyright notice to save EPROM
//			Add EPROM checksum verification at startup
//--


// Include files...
#include <stdio.h>		// needed so DBGOUT(()) can find printf!
#include "regx051.h"		// register definitions for the AT89C2051
#include "standard.h"		// standard types - BYTE, WORD, BOOL, etc
#include "gpio.h"		// hardware definitions for this project
#include "debug.h"		// debuging (serial port output) routines
#include "keyboard.h"		// low level keyboard serial I/O functions
#include "scancode.h"		// PS2 scan codes to ASCII translation table
#include "host.h"		// convert scan codes to ASCII and send to host

//   This is the copyright notice, version, and date for the software in plain
// ASCII.  Even though this only gets printed out in the debug version, it's
// always included to identify the ROM's contents...
PUBLIC char const code g_szFirmware[] =
  "PS2 Keyboard Interface (C) 2006 Spare Time Gizmos";


//++
//   This function will calculate the checksum of the program EPROM.  The 
// checksum is calculated so that the 16 bit unsigned sum of all the bytes
// in the ROM, _including_ the checksum in the last two bytes, is equal to
// the last two bytes.  This slightly arcane algorithm is used because it
// gives the same value for the checksum as the Data I/O EEPROM programmer.
//--
PRIVATE WORD ROMChecksum (WORD cbROM)
{
  // cbROM is the size of the system EPROM, in bytes (e.g. 8192 or 32768)...
  WORD wChecksum;	// checksum accumulator
  WORD pcROM;		// pointer to bytes in ROM

  // Just sum up all the bytes, igoring overflows...  Pretty easy.
  for (wChecksum = pcROM = 0;  pcROM != cbROM;  ++pcROM) {
    wChecksum += * (PCBYTE) pcROM;
  }

  //DBGOUT(("ROMChecksum: wChecksum=0x%04X, ROM=0x%04X, cbROM=%u ...\n",
  //  wChecksum, *((PCWORD) (cbROM-2)), cbROM));
  return wChecksum;
}

        
//++
// System initialization and startup...
//--
void main (void)
{
  // A little hack to eliminate "L16: UNCALLED SEGMENT ..." warnings.
  char x = g_szFirmware[0];

  // Verify the ROM checksum and just halt if it doesn't compare...
  if (ROMChecksum(ROMSIZE) != g_wROMChecksum) HALT;

  // Initialize the hardware...
  SET_KEY_DATA_RDY = 0;

#ifdef DEBUG
  InitializeDebugSerial();
  printf("\n\n%s\nV%03u ROM %bdK Checksum %04X\n\n",
    g_szFirmware, (WORD) VERSION, (BYTE) (ROMSIZE >> 10), g_wROMChecksum);
#endif

  // And the process keys and send them to the host...
  InitializeKeyboard();  INT_ON;
  ConvertKeys ();
}

