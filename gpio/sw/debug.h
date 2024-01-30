//++
//debug.h - declarations for debug.a51
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
//--
#ifndef _debug_h_
#define _debug_h_

//   The serial port baud rate is generated by timer 1 in 8 bit auto reload
// mode, and the rate is determined by:
//
//  T1RELOAD = 256 - ( CPU_CLOCK / (16*12*BAUD_RATE) ) [SMOD == 1]
//  T1RELOAD = 256 - ( CPU_CLOCK / (32*12*BAUD_RATE) ) [SMOD == 0]
//
#define T1RELOAD	0xFD	// 96000 bps with SMOD==0 and 11.0592MHz clock	

// Debugging macros...
#ifdef DEBUG
#define DBGOUT(x)	printf x
#define ASSERT(c,x)	if (!(c)) printf x
#define VERIFY(c,x)	if (!(c)) printf x
#else
#define DBGOUT(x)
#define ASSERT(c,x)
#define VERIFY(c,x)	c 
#endif

// Intialize the 8051's internal UART ...
extern void InitializeDebugSerial (void);

#endif	// _debug_h_
