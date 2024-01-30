//++
//standard.h
//
// Copyright (C) 2005 by Spare Time Gizmos.  All rights reserved.
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
// DESCRIPTION:
//   This file contains "standard" declarations that I use with Keil C51 and
// more-or-less all projects!
//
// REVISION HISTORY:
// dd-mmm-yy    who     description
//  5-Nov-98    RLA     New file.
// 19-Oct-05	RLA	Add STACKSLOCS for SDCC (see below)...
//--
#ifndef _standard_h_
#define _standard_h_

//++
// Modified Hungarian
// -------- ---------
//
//   Most of the projects use a modified version of Hungarian notation (sorry,
// Bill) that's more suitable for the 8051 environment:
//
//	n  -> numeric (e.g. int, unsigned, could also be BYTE, WORD, etc)
//	b  -> BYTE
//	w  -> WORD
//	l  -> LONG
//	c  -> char
//	f  -> flags (normally bits, also used for BOOLeans)
//
//   Note that n is used when we don't really care about the size of the datum,
// and b, w, and l are used when we do.  n doesn't distinguish signed from
// unsigned and can be used for either.
//
//	cb -> count of bytes (or characters)
//	cw -> count of words
//	s  -> string
//	sz -> zero terminated string
//
//	p  -> pointer type (generic or internal)
//       (e.g. psz == pointer to string, pw == pointer to word)
//	pi -> pointer to idata
//	px -> pointer to xdata
//	pc -> pointer to code
//
//	a  -> array type
//       (e.g. ab == array of bytes, aw == array of words)
//
//   If there's a type ABC, then there's usually a PABC, meaning a pointer to
// ABC.  Frequently there are also PXABC (pointer to ABC in external RAM),
// PCABC (ABC in code memory), etc...
//
//   The rule is: use BYTE, WORD or LONG when you care exactly how many bits
// something has, and use unsigned, int or char when you don't.
//--

///////////////////////////////////////////////////////////////////////////////
//   D A T A   T Y P E S   A N D   P O I N T E R S
///////////////////////////////////////////////////////////////////////////////

//   The upper case equivalents for DATA, IDATA, XDATA, etc should be used in
// preference to the C51 built in versions.  If you do this, then it's easy
// to port the code to another, non-C51 and maybe even non-8051, compiler!
#define	CODE	code	// 8051 code memory space
#define	DATA	data	// 8051 internal RAM directly addressed memory
#define	IDATA	idata	// 8051 internal RAM indirectly addressed memory
#define	XDATA	xdata	// 8051 external RAM

// 8 bit unsigned data...
typedef unsigned char BYTE;
typedef unsigned char       *PBYTE;
typedef unsigned char code  *PCBYTE;
typedef unsigned char xdata *PXBYTE;
typedef unsigned char idata *PIBYTE;
typedef unsigned char data  *PDBYTE;

// 16 bit unsigned data...
typedef unsigned int WORD;
typedef unsigned int       *PWORD;
typedef unsigned int code  *PCWORD;
typedef unsigned int xdata *PXWORD;
typedef unsigned int idata *PIWORD;
typedef unsigned int data  *PDWORD;

// 32 bit unsigned data...
typedef unsigned long LONG;
typedef unsigned long       *PLONG;
typedef unsigned long code  *PCLONG;
typedef unsigned long xdata *PXLONG;
typedef unsigned long idata *PILONG;
typedef unsigned long data  *PDLONG;

// Signed data types...
typedef signed char  INT8;
typedef signed short INT16;
typedef signed long  INT32;

// Character string types (i.e. LPSTR, LPCSTR!)...
typedef char code *PCSTRING;
typedef char xdata *PXSTRING;

// Untyped pointers...
typedef void *PVOID;
typedef void code *PCVOID;
typedef void xdata *PXVOID;

// Boolean types...
typedef unsigned char BOOL;
#define FALSE	((BOOL) 0)
#define TRUE	((BOOL) (~FALSE))


///////////////////////////////////////////////////////////////////////////////
//   U S E F U L   M A C R O S
///////////////////////////////////////////////////////////////////////////////

//   These macros are used mostly for documentation purposes to indicate that
// a variable of a function is to be visible within the current module only
// (PRIVATE) or to other modules as well (PUBLIC)...
#define PRIVATE	static
#define PUBLIC

// Set, clear or test bits in a value...
#define SETB(x,b)	x |= b
#define CLRB(x,b)	x &= ~(b)
#define ISSET(x,b)	(((x) & (b)) != 0)

//   Masks for individual bits (to make it easier to type in code from
// the data books!)...
enum BITS {BIT0= 0x0001, BIT1= 0x0002, BIT2= 0x0004, BIT3= 0x0008,
           BIT4= 0x0010, BIT5= 0x0020, BIT6= 0x0040, BIT7= 0x0080,
	   BIT8= 0x0100, BIT9= 0x0200, BIT10=0x0400, BIT11=0x0800,
	   BIT12=0x1000, BIT13=0x2000, BIT14=0x4000, BIT15=0x8000};

// Assemble and disassemble words and longwords...
#define LOBYTE(x) 	((BYTE) ((x) & 0xFF))
#define HIBYTE(x) 	((BYTE) (((x) >> 8) & 0xFF))
#define LOWORD(x) 	((WORD)	((x) & 0xFFFF))
#define HIWORD(x)	( (WORD) (((x) & 0xFFFF0000L) >> 16) )
#define MKWORD(h,l)	((WORD) ((((h) & 0xFF) << 8) | ((l) & 0xFF)))
#define MKLONG(h,l)	((LONG) (( (LONG) ((h) & 0xFFFF) << 16) | (LONG) ((l) & 0xFFFF)))

// Simple arithmetic functions...
#define ABS(x)		 (((x) < 0) ? -(x) : (x))
#define MAX(a,b)	 (((a) > (b)) ? (a) : (b))
#define MIN(a,b)	 (((a) < (b)) ? (a) : (b))
#define LIMIT(x,min,max) ( (x) > (max) ? (max) : (x) < (min) ? (min) : (x) )
#define TOXDIGIT(x)	((x) > 9 ? (x)-10+'A' : (x)+'0')

// Turn the interrupt system on and off...
#define INT_ON		EA = 1
#define INT_OFF		EA = 0

// Stop execution ...
#define HALT {INT_OFF;  while (1) ;}  //(well, what else can we do in an embedded system??)

#endif	// _standard_h_

