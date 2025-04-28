/*
-------------------------------------------------------------------
Snezziboy v0.21

Copyright (C) 2006 bubble2k

This program is free software; you can redistribute it and/or 
modify it under the terms of the GNU General Public License as 
published by the Free Software Foundation; either version 2 of 
the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, 
but WITHOUT ANY WARRANTY; without even the implied warranty of 
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the 
GNU General Public License for more details.

You should have received a copy of the GNU General Public 
License along with this program; if not, write to the Free 
Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, 
MA 02111-1307 USA
-------------------------------------------------------------------
*/

@-------------------------------------------------------------------------
@ Macros
@-------------------------------------------------------------------------
    .arm

@-------------------------------------------------------------------------
@ GBA ROM Header
@-------------------------------------------------------------------------
    .global     _start
    .section    .rom, "ax", %progbits
_start:
    b       Start
    
    @ taken from snes advance
    @
	.byte   36,255,174,81,105,154,162,33,61,132,130,10,132,228,9,173
	.byte   17,36,139,152,192,129,127,33,163,82,190,25,147,9,206,32
	.byte   16,70,74,74,248,39,49,236,88,199,232,51,130,227,206,191
	.byte   133,244,223,148,206,75,9,193,148,86,138,192,19,114,167,252
	.byte   159,132,77,115,163,202,154,97,88,151,163,39,252,3,152,118
	.byte   35,29,199,97,3,4,174,86,191,56,132,0,64,167,14,253
	.byte   255,82,254,3,111,149,48,241,151,251,192,133,96,214,128,37
	.byte   169,99,190,3,1,78,56,226,249,162,52,255,187,62,3,68
	.byte   120,0,144,203,136,17,58,148,101,192,124,99,135,240,60,175
	.byte   214,37,228,139,56,10,172,114,33,212,248,7

	.fill	16,1,0			@ Game Title
	.byte   0x30,0x31		@ Maker Code (80000B0h)
	.byte   0x96			@ Fixed Value (80000B2h)
	.byte   0x00			@ Main Unit Code (80000B3h)
	.byte   0x00			@ Device Type (80000B4h)
	.fill	7,1,0			@ unused
	.byte	0x00			@ Software Version No (80000BCh)
	.byte	0xf0			@ Complement Check (80000BDh)
	.byte	0x00,0x00    	@ Checksum (80000BEh)

    .equ    magicNumber, 0x51aeff24

@-------------------------------------------------------------------------
@ Macros
@-------------------------------------------------------------------------
    .include    "macroopcode.s"

	.equ	debugMemoryBase, 0x02030000

.macro  SetText t
    .ascii      "\t"
    .align  4
.endm

@-------------------------------------------------------------------------
@ Bootstrap
@-------------------------------------------------------------------------
    .align  4
    .ascii  "BOOTSTRP"
    .align  4
Start:
    @ copy iwram code
    ldr     r2, =0x03000000
    ldr     r0, =ROMEnd
    add     r0, r0, #0x100
    bic     r0, r0, #0xFF
    ldr     r1, =IWRAMEnd
    add     r1, r1, #0x3
    bic     r1, r1, #0x3
    sub     r1, r1, r0
    add     r1, r1, #0x3
    bic     r1, r1, #0x3

copyiwram:
    ldmia   r0!, {r3,r4,r5,r6}
    stmia   r2!, {r3,r4,r5,r6}
    subs    r1, r1, #16
    bpl     copyiwram
    
    ldr     pc, =HardReset
    .ltorg

@-------------------------------------------------------------------------
@ Code/Data
@-------------------------------------------------------------------------
    .include    "coderom.s"
    
ROMEnd:
    .align      4
    .ascii      ".ROMEND"
    .align      4

    .include    "codeiwram_cpu.s"
    .include    "codeiwram_io.s"

    .section    .rom2, "ax", %progbits

IWRAMEnd:
    .align      4
    .ascii      ".IWRAMEND"
    .align      4
