//++
//convert.c - convert keyboard scan codes to ASCII and send to host
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
// Place, Suite 330, Boston, MA  02111-1307  USA.
//
//DESCRIPTION:
//   The ConvertKeys() routine in this module is an endless loop that extracts
// scan codes from the keyboard buffer, converts them to ASCII, and sends them
// to the host CPU.
//
// PS2 to ASCII translation notes
// ------------------------------
//   All printing characters send their corresponding ASCII codes, as do TAB (0x09),
// ENTER (0x0D), BACKSPACE (0x08), and ESC (0x1B).
//
//   The SHIFT (both left and right), CTRL (_left_ control only!) and CAPS LOCK keys
// work as you would expect.  If the "Swap CAPS LOCK and CTRL" option is enabled,
// then these two functions are swapped.  Note that CAPS LOCK is a "CAPS LOCK", _not_
// a "SHIFT LOCK" (i.e. it affects only alphabetic characters).  This is standard
// for PCs, but not all ASCII terminals behaved this way.  The right CTRL (if your
// keyboard has one) and ALT keys (both left and right) do nothing.
//
//   If the "Keypad Application Mode" option is selected, then the numeric keypad
// keys send escape sequences that map approximately to the VT52 keypad.  If the
// application mode option is not enabled, then the numeric keypad sends normal
// characters ('0'..'9', '/', '*', '+', '-' and ENTER).  In either case, the NUM
// LOCK key is not implemented and never does anything.
//
//   The four arrow keys always send the corresponding VT52 escape sequences,
// regardless of the keypad application mode option.
//
//   All the remaining keys do nothing.  This includes the function keys
// (F1..F12), the Windows keys (left, right and menu), the editing keypad
// (INSERT, DELETE, HOME, PAGE UP, PAGE DOWN, and END), NUM LOCK, SCROLL LOCK,
// PAUSE/BREAK and PRINT SCREEN.
//
//   The keyboard LEDs are not used, including CAPS LOCK.
//
// This table summarizes the escape sequences used:
//
//	UP ARROW	<ESC>A
//	DOWN ARROW	<ESC>B
//	RIGHT ARROW	<ESC>C
//	LEFT ARROW	<ESC>D
//	Keypad 0	<ESC>?p
//	Keypad 1	<ESC>?q
//	Keypad 2	<ESC>?r
//	Keypad 3	<ESC>?s
//	Keypad 4	<ESC>?t
//	Keypad 5	<ESC>?u
//	Keypad 6	<ESC>?v
//	Keypad 7	<ESC>?w
//	Keypad 8	<ESC>?x
//	Keypad 9	<ESC>?y
//	Keypad .	<ESC>?z
//	Keypad +	(not used)
//	Keypad /	<ESC>P	(VT52 F1 BLUE key)
//	Keypad *	<ESC>Q	(VT52 F2 RED key)
//	Keypad -	<ESC>R	(VT52 F3 GRAY key)
//	Keypad ENTER	<ESC>?M
//
//REVISION HISTORY:
// dd-mmm-yy    who     description
//  5-Feb-06	RLA	New file.
//  7-May-06	RLA	Convert APPLICATION_KEYPAD and SWAP_CAPSLOCK_AND_CONTROL
//			  #ifdef options into external hardware jumpers that can
//			  be changed at runtime.
//			Don't call putchar() in SendHost() unless DEBUG is defined!
//--

// Include files...
#include <stdio.h>		// needed so DBGOUT(()) can find printf!
#include <ctype.h>		// islower() and toupper()
#include "regx051.h"		// register definitions for the AT89C2051
#include "standard.h"		// standard types - BYTE, WORD, BOOL, etc
#include <stdio.h>		// needed so DBGOUT(()) can find printf!
#include "standard.h"		// standard types - BYTE, WORD, BOOL, etc
#include "gpio.h"		// hardware definitions for this project
#include "debug.h"		// debuging (serial port output) routines
#include "keyboard.h"		// low level keyboard serial I/O functions
#include "scancode.h"		// PS2 scan codes to ASCII translation table
#include "host.h"		// prototypes and options for this module

// Global settings...

// Private Variables...
PRIVATE BYTE bdata m_bKeyFlags;		// keyboard flag bits
sbit m_fLeftShiftDown  = m_bKeyFlags^1; //  -> left shift key is pressed now
sbit m_fRightShiftDown = m_bKeyFlags^2; //  -> right  "    "   "  "   "   "
sbit m_fControlDown    = m_bKeyFlags^3; //  -> control key     "  "   "   "
sbit m_fCapsLockOn     = m_bKeyFlags^4;	//  -> CAPS LOCK mode is on


//++
//   This routine returns a scan code from the keyboard buffer.  If the
// buffer is empty, it waits (forever if necessary) until one shows up.
//--
PRIVATE BYTE WaitKey (void)
{
  int nKey;
  while (TRUE) {
    if ((nKey = GetKey()) != -1) return LOBYTE(nKey);
    if ((g_bKeyFlags & KEYBOARD_ERROR_BITS) != 0) {
      DBGOUT(("KBD: Keyboard re-initialized (0x%02bX) !!\n", g_bKeyFlags));
      InitializeKeyboard();
    }
  }
}


//++
//   This routine will send one ASCII character to the host CPU.  If the
// buffer isn't free (because the host hasn't yet read the last character)
// then it will wait (forever, if necessary) for the host.  
//--
PRIVATE void SendHost (BYTE ch)
{
  LED_ON;
  P1 = ch;  SET_KEY_DATA_RDY = 1;
  while (KEY_DATA_RDY == 0) ;
  SET_KEY_DATA_RDY = 0;
  LED_OFF;
#ifdef DEBUG
  // for testing only!!
  putchar(ch);
#endif
}


//++
//   This routine sends an escape character to the host followed by a one or
// more characters.  In the unlikely event that the serial port buffer is full,
// this routine does NOT swap tasks with the ScreenTask() - this prevents two
// escape sequences from becoming intermixed (for example, suppose the host sent
// an IDENTIFY (ESC-Z) sequence at the same time the user presses the keypad
// ENTER key - if we swap tasks, the two escape sequences, ESC ? M for ENTER,
// and ESC / A for inquire, could get mixed).
//--
PRIVATE void SendEscape (char const code *pszEscape)
{
  DBGOUT(("KBD: Send Escape %s\n", pszEscape));
  SendHost('\033');
  while (*pszEscape != '\0')  SendHost(*pszEscape++);
}


//++
//   This routine handles "special" key codes, such as 0xAA ("Self Test Pass"),
// 0xFF ("Error") and so on.  It will return TRUE if it processes the key and
// FALSE if the key code is not one of the "special" ones.  Note that these
// messages never have a release or extended byte associated with them!
//--
PRIVATE BOOL DoSpecial (BYTE bKey)
{
  switch (bKey) {
    case 0xFA:  DBGOUT(("KBD: ACKNOWLEDGE\n"));		  break;
    case 0xAA:  DBGOUT(("KBD: SELF TEST PASSED\n"));
		SendHost(0xAA);	  break;
    case 0xEE:  DBGOUT(("KBD: ECHO\n"));		  break;
    case 0xFE:  DBGOUT(("KBD: RESEND\n"));		  break;
    case 0x00:  DBGOUT(("KBD: ERROR/OVERFLOW\n"));	  break;
    case 0xFF:  DBGOUT(("KBD: ERROR/OVERFLOW\n"));	  break;
    default: return FALSE;
  }
  return TRUE;
}


//++
//   This routine handles the various "shift" keys - left/right shift, left/right
// control, caps lock, left/right alt, and the infamous "Windows" keys.  Some of
// these keys are just ignored, and the ones that aren't either set or clear bits
// in the g_bKeyFlags byte.  The fRelease parameter indicates whether a release
// code (0xF0) was seen before this key code.  TRUE is returned if the key is
// handled, and FALSE is returned if the code is not a "shift" key...
//
//   This routine is also called to handle entended key codes for the right hand
// ALT and CONTROL keys.  Convenienty the right side control and alt keys have
// the same keycode as their left hand counterparts, but with the extended
// prefix...
//
//   All these keys are processed even while Setup mode is active just so that
// we can keep track of the keyboard state, but none of them actually does
// anything in Setup mode.
//--
PRIVATE BOOL DoShift (BYTE bKey, BOOL fRelease, BOOL fExtended)
{
  // A small "hack" to swap the CAPS LOCK and CONTROL keys on the keyboard...
  if (SWAP_CAPSLOCK_AND_CONTROL) {
    if (bKey == 0x58)
      bKey = 0x14;
    else if (bKey == 0x14)
      bKey = 0x58;
  }

  switch (bKey) {
    // Left shift, right shift...
    case 0x12:  m_fLeftShiftDown = ~fRelease;  return TRUE;
    case 0x59:  m_fRightShiftDown = ~fRelease;  return TRUE;

    // Control key...
    case 0x14:
      // The right control key is not currently implemented...
      if (fExtended) return FALSE;
      m_fControlDown = ~fRelease;  return TRUE;

    // CAPS LOCK key...
    case 0x58:  
      if (fRelease) break;
      m_fCapsLockOn = ~m_fCapsLockOn;  return TRUE;

    // Alt key (ignored)...
    case 0x11:  return TRUE;

    // Windows keys...
    case 0x1F:	// WINDOWS key (left)
    case 0x27:	// WINDOWS key (right)
    case 0x2F:	// "Menu" key
      if (fExtended) {
        if (!fRelease) DBGOUT(("KBD: Windows key pressed 0x%02bX\n", bKey));
      } else
        return FALSE;

    // Everything else ...
    default:
      return FALSE;
  }
  
}


//++
//   This routine will handle the numeric keypad keys which don't send extended
// codes (that's all of them, except "/" and ENTER).  These keys always send
// escape sequences that map (more or less) to the corresponding VT52 keypad.
//
//   Of course, the real VT52 keypad has both application and numeric mode, but
// in this instance we're an output only device (i.e. there's no way for the host
// to send us an escape sequence that changes they keypad mode), so we're always
// stuck in "application" mode...
//--
PRIVATE BOOL DoKeypad (BYTE bKey, BOOL fRelease)
{
  switch (bKey) {
    // The number keys and "." map obviously onto VT52 keys...
    case 0x70:	// "0"
      if (!fRelease) SendEscape("?p");
      return TRUE;
    case 0x69:	// "1"
      if (!fRelease) SendEscape("?q");
      return TRUE;
    case 0x72:	// "2"
      if (!fRelease) SendEscape("?r");
      return TRUE;
    case 0x7A:	// "3"
      if (!fRelease) SendEscape("?s");
      return TRUE;
    case 0x6B:	// "4"
      if (!fRelease) SendEscape("?t");
      return TRUE;
    case 0x73:	// "5"
      if (!fRelease) SendEscape("?u");
      return TRUE;
    case 0x74:	// "6"
      if (!fRelease) SendEscape("?v");
      return TRUE;
    case 0x6C:	// "7"
      if (!fRelease) SendEscape("?w");
      return TRUE;
    case 0x75:	// "8"
      if (!fRelease) SendEscape("?x");
      return TRUE;
    case 0x7D:	// "9"
      if (!fRelease) SendEscape("?y");
      return TRUE;
    case 0x71:	// "."
      if (!fRelease) SendEscape("?z");
      return TRUE;

    //   The "*" maps onto the VT52 RED (F2) key and the "-" key maps onto the
    // VT52 GRAY (F3) key.  The "/" maps onto the VT52 BLUE (F1) key, but that's
    // handled in DoExtended()...      
    case 0x7C:	// "*"
      if (!fRelease) SendEscape("Q");
      return TRUE;
    case 0x7B:	// "-"
      if (!fRelease) SendEscape("R");
      return TRUE;

    // The remaining two keys, NUM LOCK and "+", aren't currently used...
    case 0x77:	// Num Lock
    case 0x79:	// "+"
      return TRUE;

    // All other keys are unknown...
    default:
      return FALSE;
  }
}


//++
//   This routine handles an "extended" key code (i.e. one of the new keys that
// were added to the PC/AT keyboard!).  It's called whenever the 0xE0 "extended"
// prefix is found, so there's no need for it to return TRUE or FALSE - we aleady
// know that an extended code is coming...
//
//   Note that most of the numeric keypad keys are NOT extended, with the notable
// exceptions of the keypad "/" (upper row, 2nd from the left) and keypad ENTER.
// The arrow keys, however, are ALL extended keys as are the DEL/END/HOME/PAGE UP/
// PAGE DN/INS etc keys.
//
//   The up and down arrow keys are used in Setup mode to move the cursor, but
// all others are ignored while in Setup.
//--
PRIVATE DoExtended (void)
{
  BYTE bExtended = WaitKey();  BOOL fRelease = FALSE;
  if (bExtended == 0xF0) {
    fRelease = TRUE;  bExtended = WaitKey();
  }

  switch (bExtended) {

    // Arrow keys...
    case 0x75:	// Up arrow
      if (!fRelease) SendEscape("A");
      break;
    case 0x72:	// Down arrow
      if (!fRelease) SendEscape("B");
      break;
    case 0x74:	// Right arrow
      if (!fRelease) SendEscape("C");
      break;
    case 0x6B:	// Left arrow
      if (!fRelease) SendEscape("D");
      break;

    // Editing keys...
    case 0x69:	// END
    case 0x6C:	// HOME
    case 0x70:	// INSERT
    case 0x71:	// DELETE
    case 0x7A:	// PAGE DOWN
    case 0x7D:	// PAGE UP
      if (!fRelease) DBGOUT(("KBD: editing key pressed 0x%02bX\n", bExtended));
      break;

    // Other keypad keys...
    case 0x5A:	// (keypad) Enter
      if (APPLICATION_KEYPAD) {
        if (!fRelease) SendEscape("?M");
      } else {
        if (!fRelease) SendHost('\015');
      }
      break;
    case 0x4A: // (keypad) "/"
      if (APPLICATION_KEYPAD) {
        // This corresponds to the "blue" key (F1) on the VT52...
        if (!fRelease) SendEscape("P");
      } else {
        if (!fRelease) SendHost('/');
      }
      break;

    // Right ALT and right CONTROL keys...
    case 0x11:  case 0x14:
      DoShift(bExtended, fRelease, TRUE);
      break;

    // Windows keys...
    case 0x1F:	// WINDOWS key (left)
    case 0x27:	// WINDOWS key (right)
    case 0x2F:	// "Menu" key
      DoShift(bExtended, fRelease, TRUE);
      break;

    //   The PRINT SCREEN key is a little bizzare - when pressed, it sends
    // _two_ extended key sequences, E0 12 followed by E0 7C.  These are treated
    // like two keys that are both ignored!  BTW, when it's released, PRINT
    // SCREEN sends E0 F0 12 and then E0 F0 7C (which is what you'd expect).
    case 0x12:  case 0x7C:
      if (!fRelease) DBGOUT(("KBD: PRINT SCREEN pressed 0x%02bX\n", bExtended));
      break;

    default:
      DBGOUT(("KBD: unknown extended key code E0 0x%02bX\n", bExtended));
  }
}


//++
// Handle the function (F1..F12) keys...  All are currently ignored...
//--
PRIVATE BOOL DoFunction (BYTE bKey, BOOL fRelease)
{
  switch (bKey) {
    // Function keys F1..F12 (all are currently ignored).
    case 0x05:	// F1
    case 0x06:	// F2
    case 0x04:  // F3
    case 0x0C:	// F4
    case 0x03:	// F5
    case 0x0B:	// F6
    case 0x83:	// F7
    case 0x0A:	// F8
    case 0x01:	// F9
    case 0x09:	// F10
    case 0x78:	// F11
    case 0x07:	// F12
      if (!fRelease) DBGOUT(("KBD: function key pressed 0x%02bX\n", bKey));
      return TRUE;

    default:
      return FALSE;
  }
}


//++
//   And lastly this routine will attempt to translate the key code into an
// ASCII character.  If it's successful then it will return TRUE and send the
// ASCII code to the serial port, and if it's unsuccessful it returns FALSE.
// Note that the ASCII code generated depends on some of the global g_bKeyFlags
// (e.g. shift, control, caps lock) flags.  Also note that ASCII keys only care
// about the down event and never the release, so ASCII characters are sent
// to the host only if fRelease == FALSE;
//--
PRIVATE BOOL DoASCII (BYTE bKey, BOOL fRelease)
{
  BYTE bASCII, bShift;
  bShift = (m_fLeftShiftDown | m_fRightShiftDown) ? 1 : 0;
  if (m_fControlDown) bShift |= 2;
  bASCII = g_abScanCodes[bKey][bShift];
  if (bASCII == 0) return FALSE;
  if (fRelease) return TRUE;
  bASCII &= 0x7F;
  if (m_fCapsLockOn && islower(bASCII))
    bASCII = toupper(bASCII);
  SendHost(bASCII);
  return TRUE;
}


//++
//   This routine is the keyboard "task" - it's an endless loop that runs
// forever reading bytes from the keyboard, converting them to ASCII, and
// sending them to the host.  It never returns ...
//--
PUBLIC void ConvertKeys (void)
{
  BYTE bKey;  BOOL fRelease;
  m_bKeyFlags = 0;
  SendHost('K' | 0x80);  SendHost ('B');  SendHost(VERSION);
  DBGOUT(("ConvertKeys() initialized ...\n"));
  while (TRUE) {
    bKey = WaitKey();  fRelease = FALSE;

    if (DoSpecial(bKey)) continue;
    if (bKey == 0xE0) {
      DoExtended();  continue;
    }
    if (bKey == 0xE1) {
      //   When pressed, the PAUSE/BREAK key sends the absolutely bizzare
      // sequence E1 14 77 E1 F0 14 F0 77.  We don't do anything with this
      // key, but we need to read and throw away these bytes so that they
      // don't get misinterpreted as something else.  BTW, what does PAUSE/
      // BREAK send when it's released ??  Answer: Absolutely nothing!
      if (WaitKey() != 0x14) continue;
      if (WaitKey() != 0x77) continue;
      if (WaitKey() != 0xE1) continue;
      if (WaitKey() != 0xF0) continue;
      if (WaitKey() != 0x14) continue;
      if (WaitKey() != 0xF0) continue;
      if (WaitKey() != 0x77) continue;
      DBGOUT(("KBD: PAUSE/BREAK pressed\n"));
      continue;
    }
    if (bKey == 0xF0) {
      fRelease = TRUE;  bKey = WaitKey();
    }
    if (bKey == 0x77) {
      if (!fRelease) DBGOUT(("KBD: NUM LOCK pressed\n"));
      continue;
    }
    if (bKey == 0x7E) {
      if (!fRelease) DBGOUT(("KBD: SCROLL LOCK pressed\n"));
      continue;
    }
    if (DoShift(bKey, fRelease, FALSE)) continue;
    if (DoFunction (bKey, fRelease)) continue;
    if (APPLICATION_KEYPAD && DoKeypad(bKey, fRelease)) continue;
    if (DoASCII(bKey, fRelease)) continue;

    DBGOUT(("KBD: unknown scan code 0x%02bx\n", bKey));
  }
}

