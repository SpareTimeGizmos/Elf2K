//++
//debug.c - 8051 serial port debugging I/O
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
// WARNING:
//   The serial port uses timer 1 for baud rate generation!
//
//REVISION HISTORY:
// dd-mmm-yy    who     description
//  4-Feb-06    RLA     New file.
//--

// Include files...
#include <stdio.h>		// needed so DBGOUT(()) can find printf!
#include "regx051.h"		// register definitions for the AT89C2051
#include "standard.h"		// standard types - BYTE, WORD, BOOL, etc
#include "debug.h"		// debuging (serial port output) routines


#ifdef DEBUG
PUBLIC void InitializeDebugSerial (void)
{
  //++
  //   This routine will initialize the 8051's internal UART.  This interface
  // is used only for debugging purposes, so the baud rate is fixed at 9600. 
  // Timer 1 is used to generate the baud rate clock, and interrupts are _not_
  // enabled for the UART!
  //--
  SCON = 0x52;			// select mode 1 - 8 bit UART, set REN, TI
  TMOD = (TMOD & 0x0F) | 0x20;	// timer 1 mode 2 - 8 bit auto reload
  TH1 = T1RELOAD;		// set the divisor for the baud rate
  PCON &= 0x7F;			// always use SMOD=0 for the baud rate
  TR1 = 1;			// and start the timer running
}
#endif

