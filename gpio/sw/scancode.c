//++
//scancode.c - PS/2 scan codes to ASCII translation table
//
// Copyright (C) 2006 by Spare Time Gizmos.  All rights reserved.
//
// This file is part of the Spare Time Gizmos' Elf 2000 GPIO firmware.
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
// Place, Suite 330, Boston, MA  02111-1307  USA
//
// DESCRIPTION:
//   This module contains a table for translating PS/2 keyboard scan codes into
// ASCII characters.  Each scan code has four table entries, corresponding to
// the unshifted, shifted, control, and control-shift modifier states.
//
// REVISION HISTORY:
// dd-mmm-yy    who     description
//  5-Feb-06    RLA     New file.
//--

// Include files...
#include "standard.h"		// standard types - BYTE, WORD, BOOL, etc
#include "scancode.h"		// prototypes for this module


//++
//   The first index in this table is, of course, the scan code from the
// IBM AT/PS2 keyboard.  The second index is the shift/control state as
// follows:
//
//	SHIFT	CONTROL     Index
//	 NO	  NO	      0
//	 YES	  NO	      1
//	 NO	  YES	      2
//	 YES	  YES	      3
//--
PUBLIC BYTE const code g_abScanCodes[128][4] = {
     0,    0,     0,    0,	// 00 - (unused)
     0,    0,     0,    0,	// 01 - F9
     0,    0,     0,    0,	// 02 
     0,    0,     0,    0,	// 03 - F5
     0,    0,     0,    0,	// 04 - F3
     0,    0,     0,    0,	// 05 - F1
     0,    0,     0,    0,	// 06 - F2
     0,    0,     0,    0,	// 07 - F12
     0,    0,     0,    0,	// 08 
     0,    0,     0,    0,	// 09 - F10
     0,    0,     0,    0,	// 0A - F8
     0,    0,     0,    0,	// 0B - F6
     0,    0,     0,    0,	// 0C - F4
  0x09, 0x09,     0,    0,	// 0D - TAB
   '`',  '~',     0,    0,	// 0E - ` (tilde)
     0,    0,     0,    0,	// 0F
     0,    0,     0,    0,	// 10
     0,    0,     0,    0,	// 11 - ALT (left only)
     0,    0,     0,    0,	// 12 - LEFT SHIFT
     0,    0,     0,    0,	// 13
     0,    0,     0,    0,	// 14 - CTRL (left)
   'q',  'Q',  0x11,    0,	// 15 - Q
   '1',  '!',     0,    0,	// 16 - 1
     0,    0,     0,    0,	// 17
     0,    0,     0,    0,	// 18
     0,    0,     0,    0,	// 19
   'z',  'Z',  0x1A,    0,	// 1A - Z
   's',  'S',  0x13,    0,	// 1B - S
   'a',  'A',  0x01,    0,	// 1C - A
   'w',  'W',  0x17,    0,	// 1D - W
   '2',  '@',     0, 0x80,	// 1E - 2
     0,    0,     0,    0,	// 1F
     0,    0,     0,    0,	// 20
   'c',  'C',  0x03,    0,	// 21 - C
   'x',  'X',  0x18,    0,	// 22 - X
   'd',  'D',  0x04,    0,	// 23 - D
   'e',  'E',  0x05,    0,	// 24 - E
   '4',  '$',     0,    0,	// 25 - 4
   '3',  '#',     0,    0,	// 26 - 3
     0,    0,     0,    0,	// 27
     0,    0,     0,    0,	// 28
   ' ',  ' ',     0,    0,	// 29 - SPACE BAR
   'v',  'V',  0x16,    0,	// 2A - V
   'f',  'F',  0x06,    0,	// 2B - F
   't',  'T',  0x14,    0,	// 2C - T
   'r',  'R',  0x12,    0,	// 2D - R
   '5',  '%',     0,    0,	// 2E - 5
     0,    0,     0,    0,	// 2F
     0,    0,     0,    0,	// 30
   'n',  'N',  0x0E,    0,	// 31 - N
   'b',  'B',  0x02,    0,	// 32 - B
   'h',  'H',  0x08,    0,	// 33 - H
   'g',  'G',  0x07,    0,	// 34 - G
   'y',  'Y',  0x19,    0,	// 35 - Y
   '6',  '^',     0, 0x1E,	// 36 - 6
     0,    0,     0,    0,	// 37
     0,    0,     0,    0,	// 38
     0,    0,     0,    0,	// 39
   'm',  'M',  0x0D,    0,	// 3A - M
   'j',  'J',  0x0A,    0,	// 3B - J
   'u',  'U',  0x15,    0,	// 3C - U
   '7',  '&',     0,    0,	// 3D - 7
   '8',  '*',     0,    0,	// 3E - 8
     0,    0,     0,    0,	// 3F
     0,    0,     0,    0,	// 40
   ',',  '<',     0,    0,	// 41 - COMMA
   'k',  'K',  0x0B,    0,	// 42 - K
   'i',  'I',  0x09,    0,	// 43 - I
   'o',  'O',  0x0F,    0,	// 44 - O
   '0',  ')',     0,    0,	// 45 - 0
   '9',  '(',     0,    0,	// 46 - 9
     0,    0,     0,    0,	// 47
     0,    0,     0,    0,	// 48
   '.',  '>',     0,    0,	// 49 - PERIOD
   '/',  '?',     0,    0,	// 4A - QUESTION MARK
   'l',  'L',  0x0C,    0,	// 4B - L
   ';',  ':',     0,    0,	// 4C - SEMICOLON
   'p',  'P',  0x10,    0,	// 4D - P
   '-',  '_',     0, 0x1F,	// 4E - HYPHEN
     0,    0,     0,    0,	// 4F
     0,    0,     0,    0,	// 50
     0,    0,     0,    0,	// 51
  0x27,  '"',     0,    0,	// 52 - QUOTE
     0,    0,     0,    0,	// 53
   '[',  '{',  0x1B,    0,	// 54 - LEFT BRACKET
   '=',  '+',     0,    0,	// 55 - EQUALS
     0,    0,     0,    0,	// 56
     0,    0,     0,    0,	// 57
     0,    0,     0,    0,	// 58
     0,    0,     0,    0,	// 59 - RIGHT SHIFT
  0x0D, 0x0D,     0,    0,	// 5A - RETURN
   ']',  '}',  0x1D,    0,	// 5B - RIGHT BRACKET
     0,    0,     0,    0,	// 5C
   '\\', '|',  0x1C,    0,	// 5D - BACKSLASH
     0,    0,     0,    0,	// 5E
     0,    0,     0,    0,	// 5F
     0,    0,     0,    0,	// 60
     0,    0,     0,    0,	// 61
     0,    0,     0,    0,	// 62
     0,    0,     0,    0,	// 63
     0,    0,     0,    0,	// 64
     0,    0,     0,    0,	// 65
     8,    8,     0,    0,	// 66 - BACKSPACE
     0,    0,     0,    0,	// 67
     0,    0,     0,    0,	// 68
   '1',    0,     0,    0,	// 69 - KEYPAD 1
     0,    0,     0,    0,	// 6A
   '4',    0,     0,    0,	// 6B - KEYPAD 4
   '7',    0,     0,    0,	// 6C - KEYPAD 7
     0,    0,     0,    0,	// 6D
     0,    0,     0,    0,	// 6E
     0,    0,     0,    0,	// 6F
   '0',    0,     0,    0,	// 70 - KEYPAD 0
   '.',    0,     0,    0,	// 71 - KEYPAD PERIOD
   '2',    0,     0,    0,	// 72 - KEYPAD 2
   '5',    0,     0,    0,	// 73 - KEYPAD 5
   '6',    0,     0,    0,	// 74 - KEYPAD 6
   '8',    0,     0,    0,	// 75 - KEYPAD 8
  0x1B, 0x1B,     0,    0,	// 76 - ESCAPE
     0,    0,     0,    0,	// 77 - NUM LOCK
     0,    0,     0,    0,	// 78 - F11
   '+',    0,     0,    0,	// 79 - KEYPAD PLUS
   '3',    0,     0,    0,	// 7A - KEYPAD 3
   '-',    0,     0,    0,	// 7B - KEYPAD MINUS
   '*',    0,     0,    0,	// 7C - KEYPAD ASTERISK
   '9',    0,     0,    0,	// 7D - KEYPAD 9
     0,    0,     0,    0,	// 7E - SCROLL LOCK
     0,    0,     0,    0	// 7F
};
