/*
-------------------------------------------------------------------
Snezziboy v0.26

Copyright (C) 2006 bubble2k

This program is free software; you can redistribute it and/or 
modify it under the terms of the GNU General Public License as 
published by the Free Software Foundation; either version 2 of 
the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, 
but WITHOUT ANY WARRANTY; without even the implied warranty of 
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the 
GNU General Public License for more details.
-------------------------------------------------------------------
*/

@=========================================================================
@ for easy porting
@=========================================================================

    .equ    bgOffsetRAMBase,    0x02031000
    .equ    snesWramBase,       0x02000000
    .equ    snesVramBase,       0x02020000
    
    .equ    cgramBase,          0x05000000
    .equ    gbaVramBase,        0x06000000
    .equ    oamRamBase,         0x07000000


@=========================================================================
@ GBA IO interrupt
@   r0-r3, safe to use
@=========================================================================
gbaFCount:          .byte   0
gbaVBlankFlag:      .byte   0           @ for v-sync
                    .byte   0
                    .byte   0



@-------------------------------------------------------------------------
@ GBA interrupt
@-------------------------------------------------------------------------
gbaInterrupt:
    ldr     r0, =0x04000202
    ldrh    r1, [r0]
    tsts    r1, #0x02               @ h-blank interrupt
    bne     hblankInterrupt
    tsts    r1, #0x01               @ v-blank interrupt
    bne     vblankInterrupt
    bx      lr

@-------------------------------------------------------------------------
@ GBA Hblank interrupt
@-------------------------------------------------------------------------
hblankInterrupt:
    mov     r1, #0x2
    strh    r1, [r0]

    mov     r3, #0x04000000         @ version 0.25, minor optimization
    ldrh    r0, [r3, #6]            @ r0 = GBA vertical count
    cmp     r0, #162
    bxge    lr
    
    ldr     r1, =bgOffset
    add     r1, r1, r0, lsl #1
    ldrh    r1, [r1]                @ r1 = frame number that the BG OFS was set
    ldr     r2, bgOffsetPrevFrame   @ r0 = previous frame number
    cmp     r1, r2                  @ if they match, copy all BG OFS
    beq     hblankInterrupt_CopyBGOFS
    ldr     r2, bgOffsetCurrFrame   @ r0 = current frame number
    cmp     r1, r2                  @ if they match, copy all BG OFS
    beq     hblankInterrupt_CopyBGOFS

    @ here we determine the vertical offset,
    @ which we use to scale the screen
    @
    ldr     r1, =yOffset
    ldrb    r2, gbaFCount
    add     r2, r2, r0              @ r2 = adjusted GBA vertical count in order
                                    @ to flicker the scaled background
                                    
    ldrsb   r0, [r1, r2]            @ r1 = horizontal offset for all backgrounds.
    add     r2, r2, #1
    ldrsb   r1, [r1, r2]            
    cmp     r1, r0
    bxeq    lr                      @ branch away to be faster
    
    ldr     pc, scaleAddress

hblankInterrupt_ScaleNonMode7:
    @ do vertical scaling for non-mode 7 backgrounds
    ldr     r2, =(regBG1VOffsetB)   @ do vertical scaling for all backgrounds.

    ldrh    r0, [r2], #2            @ and update the GBA H/V OFS
    add     r0, r0, r1
    strh    r0, [r3, #0x12]

    ldrh    r0, [r2], #2
    add     r0, r0, r1
    strh    r0, [r3, #0x16]

    ldrh    r0, [r2], #2
    add     r0, r0, r1
    strh    r0, [r3, #0x1A]
    bx      lr

hblankInterrupt_ScaleMode7:
    @ do vertical scaling for mode 7 backgrounds
    @
    ldrh    r2, [r3, #0x6]
    cmp     r2, #160
    moveq   r1, #0
    addne   r1, r2, r1
    
    ldr     r0, mode7dx
    mul     r2, r0, r1
    ldr     r0, mode7x
    add     r2, r0, r2
    str     r2, [r3, #0x28]

    ldr     r0, mode7dy
    mul     r2, r0, r1
    ldr     r0, mode7y
    add     r2, r0, r2
    str     r2, [r3, #0x2C]
    bx      lr
    
hblankInterrupt_CopyBGOFS:
    
    stmfd   sp!, {r0}       
    ldr     r2, =bgOffsetRAMBase
    add     r0, r2, r0, lsl #4
    ldr     r1, =regBG1VOffsetB             @ r2 = BG offset in IWRAM
    
    @ copy 8 times, for all V/H of 4 backgrounds
    @
    @ BG 1
    ldrh    r2, [r0], #2                    @ horizontal offsets
    add     r2, r2, #8
    strh    r2, [r3, #0x10]
    ldrh    r2, [r0], #2                    @ vertical offsets
    strh    r2, [r1], #2
    
    @ BG 2
    ldrh    r2, [r0], #2
    add     r2, r2, #8
    strh    r2, [r3, #0x14]
    ldrh    r2, [r0], #2
    strh    r2, [r1], #2
    
    @ BG 3
    ldrh    r2, [r0], #2
    add     r2, r2, #8
    strh    r2, [r3, #0x18]
    ldrh    r2, [r0], #2
    strh    r2, [r1], #2
    
    ldmfd   sp!, {r0}
    
    ldr     r1, =yOffset
    ldrb    r2, gbaFCount
    add     r2, r2, r0              @ r2 = adjusted GBA vertical count in order
                                    @ to flicker the scaled background
    add     r2, r2, #1
    ldrsb   r1, [r1, r2]            
    ldr     pc, scaleAddress

scaleAddress:   
    .word   hblankInterrupt_ScaleNonMode7

@-------------------------------------------------------------------------
@ GBA vertical blank
@-------------------------------------------------------------------------
vblankInterrupt:
    ldrb    r2, gbaFCount           @ flip the frame-counter
    eor     r2, r2, #1
    strb    r2, gbaFCount

    mov     r1, #0x1
    strh    r1, [r0]
    strb    r1, gbaVBlankFlag       @ set the vertical blank for syncing

    bx      lr


    .ltorg

@=========================================================================
@ Non-Maskable Interrupts
@=========================================================================
regHTime:   .word   0
regVTime:   .word   0
regVTime2:  .word   0
regNMI:     .byte   0
regIRQFlag: .byte   0
            .byte   0
            .byte   0

@-------------------------------------------------------------------------
@ 0x4200 NMITIMEN - Interrupt Enable Flags
@-------------------------------------------------------------------------
W4200:
    strb    r1, regNMI
    
    tsts    r1, #0x30               @ clear the interrupt jump
    moveq   r0, #0
    streq   r0, IRQJump1
    streq   r0, IRQJump2
    bxeq    lr

    ldr     r0, IRQJumpCode         @ set the interrupt jump
    str     r0, IRQJump1
    ldr     r0, IRQJumpCode+4
    str     r0, IRQJump2

    tsts    r1, #0x20
    ldrne   r0, =CheckVIRQ
    ldreq   r0, =CheckHIRQ
    str     r0, IRQJumpAddress
    bx      lr


@-------------------------------------------------------------------------
@ 0x4207  HTIMEL - H Timer low byte
@ 0x4208  HTIMEH - H Timer high byte
@   -------h hhhhhhhh
@-------------------------------------------------------------------------
W4207:
    strb    r1, regHTime
    bx      lr

W4208:
    and     r1, r1, #1
    strb    r1, regHTime+1
    bx      lr

@-------------------------------------------------------------------------
@ 0x4209  VTIMEL - V Timer low byte
@ 0x420a  VTIMEH - V Timer high byte
@   -------v vvvvvvvv
@-------------------------------------------------------------------------
W4209:
    strb    r1, regVTime
    
    ldr     r1, regVTime
    ldr     r2, =NUM_SCANLINES
    sub     r1, r1, r2
    str     r1, regVTime2
    bx      lr

W420A:
    and     r1, r1, #1
    strb    r1, regVTime+1
    
    ldr     r1, regVTime
    ldr     r2, =NUM_SCANLINES
    sub     r1, r1, r2
    str     r1, regVTime2
    bx      lr

@-------------------------------------------------------------------------
@ 0x4211 TIMEUP - IRQ timeup
@-------------------------------------------------------------------------
R4211:
    ldrb    r1, regIRQFlag
    mov     r0, #0
    strb    r0, regIRQFlag
    bx      lr

@-------------------------------------------------------------------------
@ 0x4212 HVBJOY - Vertical blank and horizontal blank
@   vh-----a
@-------------------------------------------------------------------------
R4212:
    mov     r1, #0
    ldr     r0, =0x04000004
    ldrh    r0, [r0]
    
    ldr     r2, vBlankScan
    ldr     r0, VerticalCount
    cmp     r0, r2
    orrge   r1, r1, #0x81
    
    @ version 0.23 fix
    @
    add     r2, r2, #3
    cmp     r0, r2
    bicge   r1, r1, #0x01

    cmp     SnesCYCLES, #((CYCLES_HBLANK-CYCLES_PER_SCANLINE) << CYCLE_SHIFT)
    orrge   r1, r1, #0x40

    bx      lr

    .ltorg



NMIaddress:         .word   0
COPaddress:         .word   0
BRKaddress:         .word   0
IRQaddress:         .word   0

vblankFlag:         .word   0
codeRenderMode7Reg: .word   0

@=========================================================================
@ SNES Rendering the screen at scanline = vblank
@ version 0.23 fix
@=========================================================================
snesRenderScreenAtVBlank:
    stmfd   sp!, {lr}

    @---------------------------------
    @ enabled/disable BGs and OBJs
    @---------------------------------
    @ version 0.23 
    @
    @ added so to take into account mid-frame BG enable/disable changes
    @ (we take the union of all enabled BGs per frame)
    @
    ldrb    r1, regMainScreen
    cmp     r1, #0x80
    ldreqb  r1, regMainScreenCopy2
    strneb  r1, regMainScreenCopy2
    
    ldrb    r2, regSubScreen
    cmp     r2, #0x80
    ldreqb  r2, regSubScreenCopy2
    strneb  r2, regSubScreenCopy2
    orr     r1, r1, r2
    
    ldrb    r0, regBGMode
snesRenderScreenAtVBlank_ForceMode:
    and     r0, r0, #0x7
    ldr     r2, =bgMask
    ldrb    r2, [r2, r0]
    cmp     r0, #7
    blt     snesRenderScreenAtVBlank_NotMode7
    
    @ mode 7
    orr     r0, r1, #0x01
    orr     r1, r1, r0, lsl #2
    ldr     r0, =hblankInterrupt_ScaleMode7
    str     r0, scaleAddress
    ldr     r0, codeRenderMode7Reg
    
    b       snesRenderScreenAtVBlank_Continue
    
snesRenderScreenAtVBlank_NotMode7:
    ldr     r0, =hblankInterrupt_ScaleNonMode7
    str     r0, scaleAddress
    mov     r0, #0
    
snesRenderScreenAtVBlank_Continue:
    str     r0, snesRenderScreen_RenderMode7Reg
    and     r1, r1, r2

    @ version 0.25
    @ update the mode 7 wrap around flag
    blt     snesRenderScreenAtVBlank_DontUpdateWrap
    ldrb    r2, regM7Sel
    tsts    r2, #0x80               @ test for mode 7 wrap around
    ldr     r2, =0x0400000c
    ldrh    r0, [r2]
    orreq   r0, r0, #(1<<13)
    bicne   r0, r0, #(1<<13)
    strh    r0, [r2]
snesRenderScreenAtVBlank_DontUpdateWrap:

    @ version 0.23 
    @ added so that we do not have to store special 4 color palettes
    @
    ldrb    r0, regBGMode
    tst     r0, #2                  @ test for modes 2, 3, 6, 7 (these modes do not have 4 color backgrounds)
    ldreq   r0, codeCGRAMHas4color1
    ldrne   r0, codeCGRAMNo4color1
    str     r0, W2122_4colors1
    ldreq   r0, codeCGRAMHas4color2
    ldrne   r0, codeCGRAMNo4color2
    str     r0, W2122_4colors2

    @ write the enabled BGS to the
    @ GBA DISPCNT
    @    
    ldr     r2, =0x04000000
    ldrh    r0, [r2]
    bic     r0, r0, #0x1f00
    orr     r0, r0, r1, lsl #8
    strh    r0, [r2]

    @---------------------------------
    @ Fading
    @---------------------------------
    @ version 0.23 
    @ fixed to use the brightest color per frame
    @
    ldrb    r1, regInitDisp
    cmp     r1, #0x70
    ldreqb  r1, regInitDispPrev
    strb    r1, regInitDispPrev
    mov     r0, #0x70
    strb    r0, regInitDisp
    tsts    r1, #0x80
    movne   r1, #0

    @---------------------------------
    @ Color Math
    @---------------------------------
    @
    ldr     r2, =0x04000050
    mov     r0, #0xff
    strh    r0, [r2]
    and     r1, r1, #0x0F
    rsb     r1, r1, #0x0F
    strh    r1, [r2, #4]

    cmp     r1, #0x0                    @ is it full brightness?
    bne     vBlankColorMathSkip

    stmfd   sp!, {r3-r5}
    ldrb    r1, regColorMath            @ if full brightness, restore any color math
    ands    r3, r1, #0x3f
    beq     vBlankColorMathNoBlend
    
    @ version 0.26 fix
    ldrb    r5, regColorSelect
    eor     r5, r5, #0x30
    ands    r5, r5, #0x30
    beq     vBlankColorMathNoBlend
    @ version 0.26 fix end

    ldrb    r5, regSubScreen
    and     r5, r5, #0x1f

    orr     r5, r5, r3, lsl #8
    orr     r5, r5, #(1<<6)
    ldr     r0, =0x04000050
    strh    r5, [r0]

    tsts    r1, #0x40
    ldrne   r2, =0x00000707
    ldreq   r2, =0x00000F0F
    ldr     r0, =0x04000052
    strh    r2, [r0]
    b       vBlankColorMathEnd

vBlankColorMathNoBlend:
    mov     r2, #0xFF
    ldr     r0, =0x04000050
    strh    r2, [r0]

vBlankColorMathEnd:
    ldmfd   sp!, {r3-r5}
    
vBlankColorMathSkip:    

    @---------------------------------
    @ copy backdrop color
    @---------------------------------
    ldr     r0, =configBackdrop
    ldrb    r0, [r0]
    cmp     r0, #1
    bne     renderScreen_SkipBackDrop
    ldr     r0, regBackDrop
    ldr     r1, =cgramBase
    strh    r0, [r1]
renderScreen_SkipBackDrop:

    @---------------------------------
    @ Render Frame
    @---------------------------------
    ldr     r1, =configBGEnable
    ldrb    r1, [r1]
    tsts    r1, r1
    ldreq   r0, =regMainScreen
    ldreqh  r1, [r0]
    streqh  r1, [r0, #-2]           @ forces the screen to refresh
    
    ldr     r0, screenPrev1
    ldr     r1, screenCurr1
    cmp     r0, r1
    bne     vBlankRefreshScreen

    ldr     r0, screenPrev2
    ldr     r1, screenCurr2
    cmp     r0, r1
    bne     vBlankRefreshScreen

    ldr     r0, screenPrev3
    ldr     r1, screenCurr3
    cmp     r0, r1
    bne     vBlankRefreshScreen
    
    @ otherwise, don't refresh and return
    @
    b       snesRenderEnd

vBlankRefreshScreen:
    ldr     r0, screenCurr1
    str     r0, screenPrev1
    ldr     r0, screenCurr2
    str     r0, screenPrev2
    ldr     r0, screenCurr3
    str     r0, screenPrev3

    ldrb    r0, regBGMode
vBlankRefreshScreen_ForceMode:
    and     r0, r0, #0x7
    ldr     r1, =ModeRender
    ldr     pc, [r1, r0, lsl #2]

    @------------------------------------
    @ clear the main screen flags
    @------------------------------------
snesRenderEnd:
    mov     r0, #0x80
    strb    r0, regMainScreen
    strb    r0, regSubScreen
    ldmfd   sp!, {pc}


@=========================================================================
@ keypad stuff
@=========================================================================
keypadRead:         .word   0
regJoyA:	        .hword	0xffff
regJoyB:	        .hword	0xffff
regJoyX:	        .hword	0xffff
regJoyY:	        .hword	0xffff

bgMask:     .byte   0x1f, 0x17, 0x13, 0x13
            .byte   0x13, 0x13, 0x14, 0x14

mode7x:     .word   0
mode7y:     .word   0
mode7dx:    .word   0
mode7dy:    .word   0

.equ	snesJoyA, 0x0080
.equ	snesJoyB, 0x8000
.equ	snesJoyX, 0x0040
.equ	snesJoyY, 0x4000


@=========================================================================
@ SNES Rendering the screen at scanline = 0
@=========================================================================
snesRenderScreen:
    stmfd   sp!, {lr}
    
    @---------------------------------
    @ Compute and copy the mode 7 
    @ registers
    @---------------------------------
snesRenderScreen_RenderMode7Reg:
    bl      snesRenderCopyMode7

    @---------------------------------
    @ increment the frame number
    @---------------------------------
    ldr     r0, bgOffsetCurrFrame
    str     r0, bgOffsetPrevFrame
    adds    r0, r0, #1
    bics    r0, r0, #0x00ff0000
    str     r0, bgOffsetCurrFrame
    bne     1f
    
    stmfd   sp!, {r3}
    ldr     r3, =0xffff
    moveq   r0, #1
    str     r0, bgOffsetCurrFrame
    mov     r1, #160
    
    @ version 0.26 fix
    ldr     r0, =bgOffset       @ critical bug, this was left out 
    @ version 0.26 fix end
    
snesRenderScreen_ClearFrameNumbers:
    ldrh    r2, [r0], #2
    cmp     r2, r3
    movne   r2, #0x0000
    strh    r2, [r0, #-2]
    subs    r1, r1, #1
    bne     snesRenderScreen_ClearFrameNumbers
    ldmfd   sp!, {r3}
1:

    @---------------------------------
	@ Read and map the GBA key pad 
    @ to the SNES key
    @---------------------------------
    ldr     r0, =0x04000130      
	ldrh    r1, [r0]
    ldr     r2, =keypadMap
    mov     r1, r1, lsl #1
    ldrh    r0, [r2, r1]
    mov     r1, r1, lsr #1

    ldrh    r2, regJoyA
    tsts    r1, r2
    orreq   r0, r0, #snesJoyA
    ldrh    r2, regJoyB
    tsts    r1, r2
    orreq   r0, r0, #snesJoyB
    ldrh    r2, regJoyX
    tsts    r1, r2
    orreq   r0, r0, #snesJoyX
    ldrh    r2, regJoyY
    tsts    r1, r2
    orreq   r0, r0, #snesJoyY

    strh    r0, keypadRead

    @---------------------------------
	@ Check if the config key combi
	@ (L+R+start)
	@ is pressed
    @---------------------------------
    ldr     r0, =0x04000130      
	ldrh    r0, [r0]
	tsts	r0, #(1<<8) + (1<<9)        @ L + R
	bne		renderScreen

    @---------------------------------
    @ branch to the configuration 
    @---------------------------------
    mov     r1, #0
    tsts    r0, #(1<<3)                 @ start
    ldreq   r1, =configScreen
    tsts    r0, #(1<<2)+(1<<6)          @ select+UP
    ldreq   r1, =configCycleBGPriority
    tsts    r0, #(1<<2)+(1<<7)          @ select+DOWN
    ldreq   r1, =configCycleBGForcedMode
    tsts    r1, r1
    beq     renderScreen
    
	mov     lr, pc
	bx      r1

renderScreen:

    @---------------------------------
    @ copy SNES sprites to GBA
    @ (takes approx 4,000 cycles)
    @---------------------------------
    ldr     r0, oamDirtyBit
    tsts    r0, r0
    beq     vblankSkipSpritesAltogether

    stmfd   sp!, {r3-r12, r14}      
    ldr     r1, =(oamBase)
    ldr     r2, =(oamBase+512)
    ldr     r12, =(oamRamBase)
    ldr     r7, =oamX
    ldr     r8, =oamY
    ldr     r9, =oamControl
    mov     r6, #128
    ldrb    r14, regObSel           @ r14 = ggg?????
    mov     r14, r14, lsr #5        @ r3 = 00000ggg

    beq     vblankCopySpriteEnd

vblankCopySpriteLoop:
    ldrb    r4, [r2], #1            @ r4 = sXsXsXsX

vblankCopySpriteSmallLoop:
    and     r5, r4, #0x3            @ r5 = 000000sX                                 1
    mov     r4, r4, lsr #2          @                                               1
    orr     r5, r5, r14, lsl #2     @ r5 = 000gggsX                                 1
    
    ldrb    r3, [r1, #1]            @ r3 = 00000000 00000000 00000000 yyyyyyyy      1
    orr     r3, r3, r5, lsl #8      @ r3 = 00000000 00000000 000gggsX yyyyyyyy      1
    add     r3, r3, r3              @                                               1
    ldrh    r3, [r8, r3]            @ r3 = 00000000 00000000 00000001 YYYYYYYY      3
    strh    r3, [r12], #2           @ store to VRAM                                 1

    ldrb    r3, [r1], #2            @ r3 = 00000000 00000000 00000000 xxxxxxxx      1
    orr     r3, r3, r5, lsl #8      @ r3 = 00000000 00000000 000gggsX xxxxxxxx      1
    ldrh    r10, [r1], #2           @ r10 = 00000000 00000000 vhoopppN cccccccc     1
    and     r11, r10, #0xC000       @ r11 = 00000000 00000000 vh000000 00000000     1

    add     r3, r3, r3              @                                               1
    ldrh    r3, [r7, r3]            @ r3  = 00000000 00000000 SS00000X XXXXXXXX     3
    orr     r3, r3, r11, lsr #5     @ r3  = 00000000 00000000 SS000vhX XXXXXXXX     1
    strh    r3, [r12], #2           @ store to VRAM                                 1

    bic     r10, r10, #0xC000       @ r10 = 00000000 00000000 00oopppN cccccccc     1
    add     r10, r10, r10           @                                               1
    ldrh    r10, [r9, r10]          @ r10 = 00000000 00000000 1pppooNc ccc0cccc     3
    strh    r10, [r12], #4          @ store to VRAM                                 1
                                    
    subs    r6, r6, #1              @                                               1
    beq     vblankCopySpriteEnd     @                                               1
                                    @                                      total = ~28 cycles, ROM ws = 2/1
    tsts    r6, #0x3
    bne     vblankCopySpriteSmallLoop
    b       vblankCopySpriteLoop

vblankCopySpriteEnd:
    ldmfd   sp!, {r3-r12, r14}
    mov     r0, #0
    str     r0, oamDirtyBit

vblankSkipSpritesAltogether:
    
    ldmfd   sp!, {pc}


    .ltorg


@=========================================================================
@ Mode 7 
@ (code from Snes Advance)
@=========================================================================
snesRenderCopyMode7:
    stmfd   sp!, {r0-r9}
    ldr     r9, =regM7A
	ldrsh   r0, [r9], #2
	ldrsh   r1, [r9], #2
	ldrsh   r2, [r9], #2
	ldrsh   r3, [r9], #2
	ldrh    r4, [r9], #2
	ldrh    r5, [r9], #2
	
	mov     r4, r4, lsl#19
	mov     r4, r4, asr#19
	mov     r5, r5, lsl#19
	mov     r5, r5, asr#19
	ldr     r9, =regBG1HOffset
	ldrsh   r7, [r9], #2
	ldrsh   r8, [r9], #2
	add     r7, r7, #8

	sub     r7, r7, r4	
	sub     r8, r8, r5	
	ldr     r9, =0x4000020
	strh    r0, [r9], #2
	strh    r1, [r9], #2
	strh    r2, [r9], #2
	strh    r3, [r9], #2
	str     r1, mode7dx
	str     r3, mode7dy

	mul     r0, r7, r0	
	mul     r2, r7, r2	
	add     r0, r0, r4, lsl#8
	add     r2, r2, r5, lsl#8
	mla     r1, r8, r1, r0	
	mla     r3, r8, r3, r2	
	str     r1, mode7x
	str     r3, mode7y
	ldmfd   sp!, {r0-r9}
	bx      lr


@=========================================================================
@ SNES Copy Sprites
@=========================================================================
vBlankCopySprites:
    bx      lr


@=========================================================================
@ Screen/backgrounds
@=========================================================================

regOAMAddrInternal: .word   0

regInitDisp:        .byte   0
regInitDispPrev:    .byte   0
regMOSAIC:          .byte   0
                    .byte   0
                    
@ v0.24 fix for hword alignment (thanks to Gladius)
regOAMAddrLo:       .byte   0
regOAMAddrHi:       .byte   0
                    .byte   0
                    .byte   0

screenPrev1:
                    .word   0
screenCurr1:
regBGMode:          .byte   0xff
regObSel:           .byte   0
regMainScreenCopy:  .byte   0
                    .byte   0
                    
regMainScreen:      .byte   0
regSubScreen:       .byte   0
regMainScreenCopy2: .byte   0
regSubScreenCopy2:  .byte   0

@-------------------------------------------------------------------------
@ 0x2100 - INIDISP
@   x000bbbb
@   x           = on/off
@   bbbb        = brightness
@-------------------------------------------------------------------------
W2100:
    @ version 0.23 fix, 
    @ picks the highest brightness in any frame
    @ to fix some of the games in which the screen is too dark 
    @
    ldrb    r0, regInitDisp
    and     r0, r0, #0xf
    and     r2, r1, #0xf
    cmp     r2, r0
    strgeb  r1, regInitDisp
    bx      lr

@-------------------------------------------------------------------------
@ 0x4210 RDNMI - NMI Flag and 5A22 Version
@   n---vvvv
@   n           = NMI flag
@   vvvv        = 5A22 version
@-------------------------------------------------------------------------
R4210:
    mov     r1, #0x02

    ldrb    r2, vblankFlag
    tsts    r2, r2
    bxeq    lr

    orr     r1, r1, r2
    mov     r2, #0
    strb    r2, vblankFlag

    bx      lr
    .ltorg

@-------------------------------------------------------------------------
@ 0x2101 - OBSEL
@   sssnnbbb
@   sss         = 000: 8x8  /16x16
@                 001: 8x8  /32x32
@                 010: 8x8  /64x64
@                 011: 16x16/32x32
@                 100: 16x16/64x64
@                 101: 32x32/64x64
@                 110: 16x32/32x64 (undocumented)
@                 111: 16x32/32x32 (undocumented)
@   nn          = name selection (4k word addr)
@   bbb         = base selection (8k word segment addr)
@-------------------------------------------------------------------------
W2101:
    strb    r1, regObSel
    bx      lr

@-------------------------------------------------------------------------
@ 0x2102 - OAMADDL
@   aaaaaaaa    = low-address
@-------------------------------------------------------------------------
W2102:
    strb    r1,regOAMAddrLo
    b       W2103_SetAddr

@-------------------------------------------------------------------------
@ 0x2103 - OAMADDH
@   p------b    
@   p           = priority rotation bit
@   b           = high address
@-------------------------------------------------------------------------
W2103:
    strb    r1,regOAMAddrHi

W2103_SetAddr:
    @ sets the internal OAM address
    ldrh    r2, regOAMAddrLo
    bic     r2, r2, #0xfe00
    mov     r2, r2, lsl #1
    strh    r2, regOAMAddrInternal
    bx      lr

@-------------------------------------------------------------------------
@ 0x2104 - OAMDATA
@   dddddddd    = byte to write 
@-------------------------------------------------------------------------
W2104:
    ldrh    r2,regOAMAddrInternal   @ gets the internal OAM address
    cmp     r2, #544                @ is the OAM address greater than 544 byte addresses?
    bxge    lr

    ldr     r0, =oamBase            @ write only if the OAM address is within range
    strb    r1, [r0, r2]
    
    mov     r1, #1
    str     r1, oamDirtyBit

    add     r2, r2, #1
    strh    r2,regOAMAddrInternal
    bx      lr

@-------------------------------------------------------------------------
@ 0x2138 - OAM DATA Read
@-------------------------------------------------------------------------
R2138:
    ldrh    r2,regOAMAddrInternal   @ gets the internal OAM address
    cmp     r2, #544                @ is the OAM address greater than 544 byte addresses?
    bxge    lr

    ldr     r0, =oamBase            @ write only if the OAM address is within range
    ldrb    r1, [r0, r2]
    
    add     r2, r2, #1
    strh    r2,regOAMAddrInternal
    bx      lr

oamBase:
    .rept 544
    .byte   0
    .endr

oamDirtyBit:
    .long   0

@-------------------------------------------------------------------------
@ 0x2105 - BGMODE
@   DCBAemmm    
@   DCBA        = BG character size for BG 4/3/2/1.
@                 (1=16x16, 0=8x8)
@   e           = Mode 1 BG 3 priority bit
@   mmm         = BG Mode
@-------------------------------------------------------------------------
W2105:
    strb    r1, regBGMode
    bx      lr

@-------------------------------------------------------------------------
@ 0x2106 - MOSAIC
@   xxxxDCBA
@   xxxx        = pixel size
@   DCBA        = for BG 4/3/2/1.
@-------------------------------------------------------------------------
W2106:
    strb    r1, regMOSAIC
    bx      lr

    .ltorg

@-------------------------------------------------------------------------
@ IO registers
@-------------------------------------------------------------------------

    .equ        SCANLINE_BLANK,         225
    .equ        SCANLINE_BLANK_OSCAN,   241

regBG1VOffsetB:     .hword  0
regBG2VOffsetB:     .hword  0
regBG3VOffsetB:     .hword  0
regBG4VOffsetB:     .hword  0

regBG1HOffset:      .hword  0
regBG1VOffset:      .hword  0
regBG2HOffset:      .hword  0
regBG2VOffset:      .hword  0
regBG3HOffset:      .hword  0
regBG3VOffset:      .hword  0
regBG4HOffset:      .hword  0
regBG4VOffset:      .hword  0

screenPrev2:
                    .word   0
screenCurr2:
regBG1SC:           .byte   0
regBG2SC:           .byte   0
regBG3SC:           .byte   0
regBG4SC:           .byte   0

screenPrev3:
                    .word   0
screenCurr3:
regBG1NBA:          .byte   0
regBG2NBA:          .byte   0
regBG3NBA:          .byte   0
regBG4NBA:          .byte   0
    
@-------------------------------------------------------------------------
@ Function to set BG HOFS/VOFS
@   r0: offset 
@-------------------------------------------------------------------------
WriteBGOFS:
    ldrh    r2, [r0]
    mov     r2, r2, lsr #8
    orr     r2, r2, r1, lsl #8
    strh    r2, [r0]
    
    ldr     r0, ScanlineEnd_Code
    ldr     r1, =ScanlineEnd_Copy
    str     r0, [r1]
    bx      lr

.macro  SetBGVOFS    ofs
    ldr     r0, =(regBG1VOffset+\ofs*4)
    b       WriteBGOFS
.endm

.macro  SetBGHOFS    ofs
    ldr     r0, =(regBG1HOffset+\ofs*4)
    b       WriteBGOFS
.endm

@-------------------------------------------------------------------------
@ 0x210D BG1HOFS - BG1 Horizontal Scroll
@   ------xx xxxxxxxx = The BG offset, 10 bits.
@-------------------------------------------------------------------------
W210D:
    SetBGHOFS    0

@-------------------------------------------------------------------------
@ 0x210E BG1VOFS - BG1 Vertical Scroll
@   ------xx xxxxxxxx = The BG offset, 10 bits.
@-------------------------------------------------------------------------
W210E:
    SetBGVOFS    0

@-------------------------------------------------------------------------
@ 0x210F BG2HOFS - BG2 Horizontal Scroll
@   ------xx xxxxxxxx = The BG offset, 10 bits.
@-------------------------------------------------------------------------
W210F:
    SetBGHOFS    1

    .ltorg

@-------------------------------------------------------------------------
@ 0x2110 BG2VOFS - BG2 vertical Scroll
@   ------xx xxxxxxxx = The BG offset, 10 bits.
@-------------------------------------------------------------------------
W2110:
    SetBGVOFS    1

@-------------------------------------------------------------------------
@ 0x2111 BG3HOFS - BG3 Horizontal Scroll
@   ------xx xxxxxxxx = The BG offset, 10 bits.
@-------------------------------------------------------------------------
W2111:
    SetBGHOFS    2

@-------------------------------------------------------------------------
@ 0x2112 BG3VOFS - BG3 vertical Scroll
@   ------xx xxxxxxxx = The BG offset, 10 bits.
@-------------------------------------------------------------------------
W2112:
    SetBGVOFS    2

@-------------------------------------------------------------------------
@ 0x2113 BG4HOFS - BG4 Horizontal Scroll
@   ------xx xxxxxxxx = The BG offset, 10 bits.
@-------------------------------------------------------------------------
W2113:
    SetBGHOFS    3

@-------------------------------------------------------------------------
@ 0x2114 BG4VOFS - BG4 Vertical Scroll
@   ------xx xxxxxxxx = The BG offset, 10 bits.
@-------------------------------------------------------------------------
W2114:
    SetBGVOFS    3

    .ltorg

@-------------------------------------------------------------------------
@ 0x2107 - BG1SC - BG1 Tilemap Address and Size
@ 0x2108 - BG1SC - BG1 Tilemap Address and Size
@ 0x2109 - BG1SC - BG1 Tilemap Address and Size
@ 0x210A - BG1SC - BG1 Tilemap Address and Size
@   aaaaaayx
@   aaaaaa      = Tilemap address in VRAM (Addr>>10)
@   x           = Tilemap horizontal mirroring
@   y           = Tilemap veritcal mirroring
@-------------------------------------------------------------------------

W2107:
    strb    r1, regBG1SC
    bx      lr

W2108:
    strb    r1, regBG2SC
    bx      lr

W2109:
    strb    r1, regBG3SC
    bx      lr

W210A:
    strb    r1, regBG4SC
    bx      lr

@-------------------------------------------------------------------------
@ 0x210B - BG1/2NBA - BG1 and 2 Chr Address
@ 0x210C - BG3/4NBA - BG3 and 4 Chr Address
@   bbbbaaaa
@   aaaa = Base address for BG1/3 (Addr>>13)
@   bbbb = Base address for BG2/4 (Addr>>13)
@-------------------------------------------------------------------------
W210B:
    and     r0, r1, #0x7
    strb    r0, regBG1NBA

    mov     r0, r1, lsr #4
    and     r0, r0, #0x7
    strb    r0, regBG2NBA
    bx      lr

W210C:
    and     r0, r1, #0x7
    strb    r0, regBG3NBA

    mov     r0, r1, lsr #4
    and     r0, r0, #0x7
    strb    r0, regBG4NBA
    bx      lr


    .ltorg

@-------------------------------------------------------------------------
@ 0x2133 SETINI - Screen Mode/Video Select
@   se--poIi
@   s           = external sync
@   e           = extra Mode 7 BG
@   p           = pseudo hi-res
@   o           = Overscan
@   I           = object interlace
@   i           = screen interlace
@-------------------------------------------------------------------------
W2133:
    tsts    r1, #0x04
    
    ldrne   r0, =SCANLINE_BLANK_OSCAN @ if overscan=1, vblank = 241
    ldreq   r0, =SCANLINE_BLANK       @ if overscan=0, vblank = 225
    sub     r0, r0, #255
    sub     r0, r0, #7
    ldr     r1, =vBlankScan
    str     r0, [r1]
    
    ldr     r1, =ScanlineEnd_VBlankCheck
    ldrne   r0, W2133_VBlank_Overscan
    ldreq   r0, W2133_VBlank
    str     r0, [r1]

    bx      lr

W2133_VBlank:
    cmp     r1, #(-262+SCANLINE_BLANK)
W2133_VBlank_Overscan:
    cmp     r1, #(-262+SCANLINE_BLANK_OSCAN)
    
    .ltorg

@=========================================================================
@ VRAM
@=========================================================================
@-------------------------------------------------------------------------
@ IO registers
@-------------------------------------------------------------------------
regVideoMain:       .byte   0
                    .byte   0
                    .byte   0
                    .byte   0

@-------------------------------------------------------------------------
@ 0x2115 VMAIN - Video Port Control
@       i---mmii
@       i    = Address increment mode:
@               0 => increment after writing $2118/reading $2139
@               1 => increment after writing $2119/reading $213a
@
@       ii = Address increment amount
@           00 = Normal increment by 1
@           01 = Increment by 32
@           10 = Increment by 128
@           11 = Increment by 128
@
@       mm = Address remapping
@           00 = No remapping
@           01 = Remap addressing aaaaaaaaBBBccccc => aaaaaaaacccccBBB
@           10 = Remap addressing aaaaaaaBBBcccccc => aaaaaaaccccccBBB
@           11 = Remap addressing aaaaaaBBBccccccc => aaaaaacccccccBBB
@-------------------------------------------------------------------------
.macro  ModifyAddrXlateNop label
    mov     r0, #0
    ldr     r2, =\label
    str     r0, [r2]
.endm

.macro  ModifyAddrXlate label, label2
    ldr     r2, =\label
    ldr     r0, =\label2
    ldr     r0, [r0]
    str     r0, [r2]
.endm

W2115:
    strb    r1, regVideoMain
    
    @ modify to take care of the address increment mode
    @
    tsts    r1, #0x00000080
    
    ldr     r0, =W2115_Inc
    ldreq   r0, [r0]
    ldrne   r0, [r0, #4]
    str     r0, W2118_Inc
    str     r0, R2139_Inc
    
    ldr     r0, =W2115_Inc
    ldrne   r0, [r0]
    ldreq   r0, [r0, #4]
    str     r0, W2119_Inc
    str     r0, R213A_Inc

    @ take care of the increment counter
    @
    ldr     r0, =W2115_IncCount
    and     r2, r1, #0x03               @ r2 = 000000ii
    ldr     r0, [r0, r2, lsl #2]
    ldr     r2, =W2118_IncCount
    str     r0, [r2]
    ldr     r2, =W2119_IncCount
    str     r0, [r2]
    ldr     r2, =R2139_IncCount
    str     r0, [r2]
    ldr     r2, =R213A_IncCount
    str     r0, [r2]

    @ take care of the address translation
    @
    mov     r1, r1, lsr #2              @ r1 = 00i---mm
    ands    r1, r1, #0x03               @ r1 = 000000mm
    bne     w2115_ModifyAddrXlate
    
    ModifyAddrXlateNop  W2118_AddrXlate
    ModifyAddrXlateNop  W2119_AddrXlate
    bx      lr

w2115_ModifyAddrXlate:
    ldr     r0, =vramTranslation
    sub     r1, r1, #1
    add     r0, r0, r1, lsl #17
    ModifyAddrXlate     W2118_AddrXlate, W2118_AddrXlateOp
    ModifyAddrXlate     W2119_AddrXlate, W2119_AddrXlateOp
    bx      lr

W2115_Inc:
    mov     r0, r0
    bx      lr

W2115_IncCount:
    add     r2, r2, #1
    add     r2, r2, #32
    add     r2, r2, #128
    add     r2, r2, #128

W2118_AddrXlateOp:
    nop
W2119_AddrXlateOp:
    nop

@-------------------------------------------------------------------------
@ IO registers
@-------------------------------------------------------------------------
regVRAMAddrLo:      .byte   0
regVRAMAddrHi:      .byte   0
                    .byte   0       @ reserved, don't put anything here
                    .byte   0       @ reserved, don't put anything here

@-------------------------------------------------------------------------
@ 0x2116  VMADDL - VRAM Address low byte
@-------------------------------------------------------------------------
W2116:
    strb    r1, regVRAMAddrLo
    b       W2117_SetupVRAMRead

@-------------------------------------------------------------------------
@ 0x2116  VMADDH - VRAM Address high byte
@-------------------------------------------------------------------------
W2117:
    strb    r1, regVRAMAddrHi

W2117_SetupVRAMRead:
    @ set up the correct VRAM buffer for reading
    @ (version 0.23 fix, thanks to Gladius)
    @
    ldr     r2, regVRAMAddrLo     
    bic     r2, r2, #0x8000
    ldr     r0, =snesVramBase
    add     r0, r0, r2, lsl #1
    ldrh    r0, [r0]
    strh    r0, vramTemp

    bx      lr
    
@-------------------------------------------------------------------------
@ 0x2118  VMDATAL - VRAM Data Write low byte
@-------------------------------------------------------------------------
vramTranslateAddr:  .word   vramTranslation

W2118:
    ldr     r0, regVRAMAddrLo
    bic     r0, r0, #0x8000
W2118_AddrXlate:
    b       w2118_VramAddrXlate     @ (self modifying code) (b W211x_VramAddrXlate, or nop)
w2118_Write:
    ldr     r2, =snesVramBase       @ VRAM base (low byte)
    strb    r1, [r2, r0, lsl #1]
W2118_Inc:
    bx      lr                      @ (self modifying code) (or mov r0, r0)
    ldr     r2, regVRAMAddrLo       
W2118_IncCount:
    add     r2, r2, #1              @ (self modifying code) (or add r1, r1, #nn)
    strh     r2, regVRAMAddrLo       
    
    @ jump to VRAM write table
    mov     r0, r0, lsl #1
    mov     r1, r0, lsr #11
    
    ldr     r2, =VRAMWrite
    stmfd   sp!, {r0, r1, lr}
    mov     lr, pc
    ldr     pc, [r2, r1, lsl #2]
    ldmfd   sp!, {r0, r1, lr}
    
    ldr     r2, =VRAMObjWrite
    ldr     pc, [r2, r1, lsl #2]

w2118_VramAddrXlate:
    ldr     r2, vramTranslateAddr
    add     r2, r2, r0, lsl #1
    ldrh    r0, [r2]
    b       w2118_Write

@-------------------------------------------------------------------------
@ 0x2119  VMDATAH - VRAM Data Write high byte
@-------------------------------------------------------------------------
W2119:
    ldr     r0, regVRAMAddrLo
    bic     r0, r0, #0x8000
W2119_AddrXlate:
    b       W2119_VramAddrXlate     @ (self modifying code) (b W211x_VramAddrXlate, or nop)
w2119_Write:
    ldr     r2, =(snesVramBase+1)   @ VRAM base (high byte)
    strb    r1, [r2, r0, lsl #1]
W2119_Inc:
    bx      lr                      @ (self modifying code) (or mov r0, r0)
    ldr     r2, regVRAMAddrLo       
W2119_IncCount:
    add     r2, r2, #1              @ (self modifying code) (or add r1, r1, #nn)
    strh    r2, regVRAMAddrLo       

    @ jump to VRAM write table
    mov     r0, r0, lsl #1
    mov     r1, r0, lsr #11
    
    ldr     r2, =VRAMWrite
    stmfd   sp!, {r0, r1, lr}
    mov     lr, pc
    ldr     pc, [r2, r1, lsl #2]
    ldmfd   sp!, {r0, r1, lr}
    
    ldr     r2, =VRAMObjWrite
    ldr     pc, [r2, r1, lsl #2]


W2119_VramAddrXlate:
    ldr     r2, vramTranslateAddr
    add     r2, r2, r0, lsl #1
    ldrh    r0, [r2]
    b       w2119_Write



@-------------------------------------------------------------------------
vramTemp:   .hword  0
            .hword  0

@-------------------------------------------------------------------------
@ 0x2139  VMDATALREAD - VRAM Data read low byte
@-------------------------------------------------------------------------
R2139:
    ldrb    r1, vramTemp
R2139_Inc:
    bx      lr                      @ (self modifying code) (or mov r0, r0)
    ldr     r2, regVRAMAddrLo       
    
    @ version 0.23 fix, thanks to Gladius
    @
    bic     r2, r2, #0x8000
    ldr     r0, =snesVramBase
    add     r0, r0, r2, lsl #1
    ldrh    r0, [r0]
    strh    r0, vramTemp
R2139_IncCount:
    add     r2, r2, #1              @ (self modifying code) (or add r1, r1, #nn)
    str     r2, regVRAMAddrLo       
    
    bx      lr

@-------------------------------------------------------------------------
@ 0x213A  VMDATAHREAD - VRAM Data read high byte
@-------------------------------------------------------------------------
R213A:
    ldrb    r1, vramTemp+1
R213A_Inc:
    bx      lr                      @ (self modifying code) (or mov r0, r0)
    ldr     r2, regVRAMAddrLo       
    
    @ version 0.23 fix, thanks to Gladius
    @
    bic     r2, r2, #0x8000
    ldr     r0, =snesVramBase
    add     r0, r0, r2, lsl #1
    ldrh    r0, [r0]
    strh    r0, vramTemp
R213A_IncCount:
    add     r2, r2, #1              @ (self modifying code) (or add r1, r1, #nn)
    str     r2, regVRAMAddrLo       
    
    bx      lr


@=========================================================================
@ Special VRAM functions
@=========================================================================

@-------------------------------------------------------------------------
@ Jump table for VRAM writes (idea from SNESAdvance)
@ each is a 2 kilobyte (0x800) block
@-------------------------------------------------------------------------
VRAMWrite:
    .rept   32
    .long   VRAMWriteNOP
    .endr

@-------------------------------------------------------------------------
@ For writing objects to memory
@-------------------------------------------------------------------------
VRAMObjWrite:
    .rept   32
    .long   VRAMWriteNOP
    .endr

@-------------------------------------------------------------------------
@ The BG that each 16k block corresponds to
@-------------------------------------------------------------------------
VRAMBG:
    .rept   32
    .byte   0xff
    .endr

@-------------------------------------------------------------------------
@ The number of colors that 16k BG character block corresponds to
@   0 = 4 colors
@   1 = 16 colors
@   2 = 256 colors
@-------------------------------------------------------------------------
VRAMBGColors:
    .rept   32
    .byte   0xff
    .endr

@=========================================================================
@ Mode 7 Stuff (also the multiply operation)
@=========================================================================
regM7A:         .hword   0
regM7B:         .hword   0
regM7C:         .hword   0
regM7D:         .hword   0
regM7X:         .hword   0
regM7Y:         .hword   0
regMulResult:   .word    0
regM7Sel:       .byte    0
                .byte    0
                .byte    0
                .byte    0

W211A:
    strb    r1, regM7Sel

W211B:
    ldrh    r0,regM7A
    mov     r0, r0, lsr #8
    add     r0, r0, r1, lsl #8
    strh    r0,regM7A
    bx      lr

W211C:
    ldrh    r0,regM7B
    mov     r0, r0, lsr #8
    add     r0, r0, r1, lsl #8
    strh    r0,regM7B

    @ r1 stores the multiplicand
    ldrsh   r0,regM7A
    ldrsb   r1,(regM7B+1)
    mul     r0, r1, r0
    str     r0,regMulResult

    bx      lr

W211D:
    ldrh    r0,regM7C
    mov     r0, r0, lsr #8
    add     r0, r0, r1, lsl #8
    strh    r0,regM7C
    bx      lr

W211E:
    ldrh    r0,regM7D
    mov     r0, r0, lsr #8
    add     r0, r0, r1, lsl #8
    strh    r0,regM7D
    bx      lr

W211F:
    ldrh    r0,regM7X
    mov     r0, r0, lsr #8
    add     r0, r0, r1, lsl #8
    strh    r0,regM7X
    bx      lr

W2120:
    ldrh    r0,regM7Y
    mov     r0, r0, lsr #8
    add     r0, r0, r1, lsl #8
    strh    r0,regM7Y
    bx      lr

@=========================================================================
@ Multiplication result
@=========================================================================
R2134:
    ldrb    r1, regMulResult
    bx      lr

R2135:
    ldrb    r1, regMulResult+1
    bx      lr

R2136:
    ldrb    r1, regMulResult+2
    bx      lr


@=========================================================================
@ CGRAM
@=========================================================================

regCGRAMAddr:   .word   0
regCGRAMLatch:  .word   0

codeCGRAMHas4color1:    streqh  r0, [r1]
codeCGRAMNo4color1:     strh    r0, [r1]
codeCGRAMHas4color2:    cmp     r2, #64
codeCGRAMNo4color2:     cmp     r2, #0

@-------------------------------------------------------------------------
@ 0x2121: CGADD - CGRAM Address
@-------------------------------------------------------------------------
W2121:
    mov     r1, r1, lsl #1
    bic     r1, r1, #0xFE00
    strh    r1, regCGRAMAddr
    bx      lr

@-------------------------------------------------------------------------
@ 0x2122: CGDATA - CGRAM Data write
@   -bbbbbgg gggrrrrr: BGR components of the palette
@-------------------------------------------------------------------------
W2122:
    ldrh    r2,regCGRAMAddr         @ gets the internal CGRAM address
    ldrh    r0, regCGRAMLatch       @ r0 = pppppppp qqqqqqqq
    mov     r0, r0, ror #8          @ r0 = 00000000 pppppppp
    orr     r0, r0, r1, lsl #8      @ r0 = rrrrrrrr pppppppp
    strh    r0, regCGRAMLatch
    add     r2, r2, #1
    strh    r2,regCGRAMAddr

    @ write through to GBA's CGRAM
    tsts    r2, #1
    bxne    lr
    
    sub     r2, r2, #2              @ r2 = 0000000c ccccccc0
    bic     r2, r2, #0xFE00
    
    tsts    r2, r2                  @ is it zero?
    bne     1f
    ldr     r1, =configBackdrop
    ldrb    r1, [r1]
    cmp     r1, #1
    bxeq    lr

1:
    tsts    r2, #0x0100
    add     r1, r2, #cgramBase      @ write BG (16-color) palette
W2122_4colors1:
    streqh  r0, [r1]
    add     r1, r1, #0x0200         @ write OBJ palette
    strh    r0, [r1]

W2122_4colors2:
    cmp     r2, #64                 @ is palette index >= 64?
    bxge    lr                      @ return if so, otherwise...
    and     r1, r2, #0xF8           @ r1 = 00000000 000cc000
    and     r2, r2, #0x06           @ r2 = 00000000 00000cc0
    add     r2, r2, r1, lsl #2      @ r2 = 00000000 0cc00cc0
    add     r2, r2, #cgramBase
    add     r2, r2, #0x00000100
    strleh  r0, [r2]                @ ...write BG (4-color) palette

    bx      lr

    .ltorg

@=========================================================================
@ Main/sub screen and color math
@=========================================================================
regBackDrop:    .byte   0
                .byte   0
regColorSelect: .byte   0
regColorMath:   .byte   0

W212C:
    ldrb    r0, regMainScreen
    orr     r1, r0, r1
    strb    r1, regMainScreen
    bx      lr

W212D:
    ldrb    r0, regSubScreen
    orr     r1, r0, r1
    strb    r1, regSubScreen
    bx      lr

W2130:
    strb    r1, regColorSelect
    bx      lr

W2131:
    strb    r1, regColorMath
    bx      lr

W2132:
    ldrh    r0, regBackDrop
    and     r2, r1, #0x1f
    
    tsts    r1, #(1<<7)         
    bicne   r0, r0, #(0x1f << 10)
    orrne   r0, r0, r2, lsl #10
    tsts    r1, #(1<<6)         
    bicne   r0, r0, #(0x1f << 5)
    orrne   r0, r0, r2, lsl #5
    tsts    r1, #(1<<5)         
    bicne   r0, r0, #(0x1f << 0)
    orrne   r0, r0, r2, lsl #0
    
    strh    r0, regBackDrop
    
    bx      lr


@=========================================================================
@ H/V Counters
@=========================================================================
regHCounter:    .word   0
regVCounter:    .word   0
regPALNTSC:     .byte   0           @ 1 for PAL, 0 for NTSC
                .byte   0
                .byte   0
                .byte   0
    
@-------------------------------------------------------------------------
@ 0x2137 - SLHV - Software Latch for H/V Counter
@-------------------------------------------------------------------------
R2137:
    mov     r0, SnesCV, lsr #CYCLE_SHIFT
    add     r0, r0, #255
    add     r0, r0, #7
    strh    r0, regHCounter
    
    ldr     r0, =VerticalCount
    ldr     r0, [r0]
    add     r0, r0, #255
    add     r0, r0, #7
    strh    r0, regVCounter
    bx      lr

@-------------------------------------------------------------------------
@ 0x213c - OPHCT  - Software Latch for H Counter
@-------------------------------------------------------------------------
R213C:
	ldr     r0, regHCounter
	eors    r0, r0, #0x80000000
	str     r0, regHCounter
	movpl   r0, r0, lsr#8           @ do a high read
	and     r1, r0, #0xff
	bx      lr

@-------------------------------------------------------------------------
@ 0x213d - OPVCT  - Software Latch for V Counter
@-------------------------------------------------------------------------
R213D:
	ldr     r0, regVCounter
	eors    r0, r0, #0x80000000
	str     r0, regVCounter
	movpl   r0, r0, lsr#8           @ do a high read
	and     r1, r0, #0xff
	bx      lr

@-------------------------------------------------------------------------
@ 0x213E: STAT77 - PPU Status Flag and Version
@-------------------------------------------------------------------------
R213E:
    mov     r1, #0
    bx      lr

@-------------------------------------------------------------------------
@ 0x213F: STAT78 - PPU Status Flag and Version
@-------------------------------------------------------------------------
R213F:
    @ version 0.25 fix
    @ reset the high/low selector
    mov     r0, #0
    ldr     r2, =(regHCounter+3)
    strb    r0, [r2]
    ldr     r2, =(regVCounter+3)
    strb    r0, [r2]
    
    mov     r1, #1
    ldrb    r0, regPALNTSC
    add     r1, r1, r0, lsl #4
    
    bx      lr

@=========================================================================
@ APU (SPC-700 registers)
@=========================================================================

    .equ    APUReadMaxCount, 7

regAPU0:            .byte   0
regAPU1:            .byte   0
regAPUReadCount:    .byte   (APUReadMaxCount-1)
                    .byte   0
regAPUCounter:      .hword  0
                    .hword  0
spcReadTable:       .word   spcRead6, spcRead4, spcRead5, spcRead2, spcRead3, spcRead0, spcRead1

@-------------------------------------------------------------------------
@ 0x2140 APUIO0 - APU I/O register 0
@ 0x2141 APUIO1 - APU I/O register 1
@ 0x2142 APUIO2 - APU I/O register 2
@ 0x2143 APUIO3 - APU I/O register 3
@-------------------------------------------------------------------------
R2140:
R2141:
R2142:
R2143:
	ldrb    r2, regAPUReadCount
	subs    r2, r2, #1
	movmi   r2, #(APUReadMaxCount-1)
	strb    r2, regAPUReadCount

	ldr     r0, =spcReadTable
	ldr     pc, [r0, r2, lsl #2]

spcRead6:
    mov     r1, #0
    bx      lr


spcRead5:
    tsts    SnesMXDI, #SnesFlagM        @ low byte

    @ 8-bit
    movne   r1, SnesA, lsr #24

    @ 16-bit
    moveq   r1, SnesA, lsr #16
    biceq   r1, r1, #0x0000ff00
    bx      lr

spcRead4:
    tsts    SnesMXDI, #SnesFlagM        @ high byte

    @ 8-bit
    ldrne   r1, =SnesB
    ldrne   r1, [r1]
    movne   r1, r1, lsr #24

    @ 16-bit
    moveq   r1, SnesA, lsr #24
    bx      lr

spcRead3:
    mov     r1, #0xaa                   @ high byte
	bx      lr

spcRead2:
    mov     r1, #0xbb                   @ low byte
	bx      lr

spcRead1:       
    ldrb    r1, regAPU1                 @ high byte
	bx      lr

spcRead0:
    ldrb    r1, regAPU0                 @ low byte
    ldrh    r2, regAPU0
    add     r2, r2, #1
    strh    r2, regAPU0
	bx      lr


W2140:  
W2142:
    @mov     r2, #(APUReadMaxCount-1)
	@strb    r2, regAPUReadCount
    strb    r1, regAPU0
    bx      lr

W2141:
W2143:
    strb    r1, regAPU1
    bx      lr

@=========================================================================
@ WRAM
@=========================================================================

regWRAMAddr:                .long   0

@-------------------------------------------------------------------------
@ 0x2180
@-------------------------------------------------------------------------
W2180:
    ldr     r0, regWRAMAddr
    strb    r1, [r0], #1
    bic     r0, r0, #0x00fe0000
    str     r0, regWRAMAddr
    bx      lr

R2180:
    ldr     r0, regWRAMAddr
    ldrb    r1, [r0], #1
    bic     r0, r0, #0x00fe0000
    str     r0, regWRAMAddr
    bx      lr

@-------------------------------------------------------------------------
@ 0x2181  WMADDL - WRAM Address low byte
@-------------------------------------------------------------------------
W2181:
    strb    r1, regWRAMAddr
    b       W218xTranslate

@-------------------------------------------------------------------------
@ 0x2182  WMADDM - WRAM Address middle byte
@-------------------------------------------------------------------------
W2182:
    strb    r1, regWRAMAddr+1
    b       W218xTranslate

@-------------------------------------------------------------------------
@ 0x2183  WMADDH - WRAM Address high byte
@-------------------------------------------------------------------------
W2183:
    and     r1, r1, #1
    strb    r1, regWRAMAddr+2
    
W218xTranslate:
    ldr     r0, regWRAMAddr
    orr     r0, r0, #snesWramBase
    str     r0, regWRAMAddr
    bx      lr


@=========================================================================
@ Joypad 
@=========================================================================

regJoyLatch:    .word   0xffffffff

@-------------------------------------------------------------------------
@ 0x4016 rwb++++ JOYSER0 - NES-style Joypad Access Port 1
@   Rd: ------ca
@   Wr: -------l
@-------------------------------------------------------------------------
W4016:
    @ latch the joypad state
    @ (only when bit 1 is set)
    @ version 0.23 fix
    @ 
    tsts    r1, #1
    bxeq    lr
    
    ldr     r0, =keypadRead
    ldrh    r0, [r0]
    strh    r0, regJoyLatch
    bx      lr

R4016:
    ldrh    r0, regJoyLatch
    tsts    r0, #0x8000
    moveq   r1, #0
    movne   r1, #1
    mov     r0, r0, lsl #1
    orr     r0, r0, #1
    strh    r0, regJoyLatch
    bx      lr

@-------------------------------------------------------------------------
@ 0x4218 JOY1L - Controller Port 1 Data1 Register low byte
@-------------------------------------------------------------------------
R4218:
    ldr     r0, =keypadRead
    ldrb    r1, [r0]
    bx      lr

@-------------------------------------------------------------------------
@ 0x4219 JOY1H - Controller Port 1 Data1 Register high byte
@-------------------------------------------------------------------------
R4219:
    ldr     r0, =keypadRead+1
    ldrb    r1, [r0]
	bx      lr

R421A:
R421B:
R421C:
R421D:
R421E:
R421F:
    mov     r1, #0
    bx      lr

    .ltorg

@=========================================================================
@ Mul/Divide registers
@=========================================================================

regMulA:        .byte   0
regDivisor:     .byte   0
                .byte   0
                .byte   0
regMulResult2:  .word   0
regDividend:    .word   0
regDivResult:   .word   0

@-------------------------------------------------------------------------
@ 0x4202 WRMPYA - Multiplicand A
@-------------------------------------------------------------------------
W4202:
    strb    r1, regMulA
    bx      lr

@-------------------------------------------------------------------------
@ 0x4203 WRMPYA - Multiplicand B
@-------------------------------------------------------------------------
W4203:
    ldrb    r0, regMulA
    mul     r0, r1, r0
    strh    r0, regMulResult2
    bx      lr

@-------------------------------------------------------------------------
@ 0x4204 WRDIVL - Dividend C low byte
@-------------------------------------------------------------------------
W4204:
    strb    r1, regDividend
    bx      lr

@-------------------------------------------------------------------------
@ 0x4205 WRDIVL - Dividend C high byte
@-------------------------------------------------------------------------
W4205:
    strb    r1, regDividend+1
    bx      lr

@-------------------------------------------------------------------------
@ 0x4206 WRDIVB - Divisor B
@-------------------------------------------------------------------------
W4206:
    @ from Snes Advance
	ldrh    r0, regDividend
	ands    r1, r1, #0xff
	subeq   r2, r1, #1
	beq     div0			    @ div by 0: quotient.r2 = -1, remainder.r0 = dividend

	stmfd   sp!, {r3}		    @ unsigned divide - r2=r0/r1, r0=remainder
	mov     r3, r1              @ r3 = divisor.r1
	cmp     r3, r0, lsr#1       
div1:                           @ while( r3 < dividend.r0*2 )    
    addls   r3, r3, r3          @   { r3 = r3 * 2 }
	cmp     r3, r0, lsr#1       
	bls     div1
	mov     r2, #0              @ initialize r2 as the result to 0
div2:	
    cmp     r0, r3              @ do 
	subcs   r0, r0, r3          @   if (dividend.r0>=r3) then dividend.r0 = dividend.r0 - r3 
	adc     r2, r2, r2          @   if (dividend.r0>=r3) then r2 = (r2 * 2) + 1 else r2 = (r2 * 2)
	mov     r3, r3, lsr#1       @   r3 = r3 / 2
	cmp     r3, r1              @ while ( r3 > divisor.r1 )
	bhs     div2
	ldmfd   sp!, {r3}
div0:
	strh    r0, regMulResult2
	strh    r2, regDivResult
    bx      lr

@-------------------------------------------------------------------------
@ 0x4214 RDDIVL - Quotient of Divide Result low byte
@-------------------------------------------------------------------------
R4214:
    ldrb    r1, regDivResult
    bx      lr

@-------------------------------------------------------------------------
@ 0x4215 RDDIVL - Quotient of Divide Result high byte
@-------------------------------------------------------------------------
R4215:
    ldrb    r1, regDivResult+1
    bx      lr

@-------------------------------------------------------------------------
@ 0x4216 RDMPYL - Multiplication Product or Divide Remainder low byte
@-------------------------------------------------------------------------
R4216:
    ldrb    r1, regMulResult2
    bx      lr

@-------------------------------------------------------------------------
@ 0x4217 RDMPYH - Multiplication Product or Divide Remainder high byte
@-------------------------------------------------------------------------
R4217:
    ldrb    r1, regMulResult2+1
    bx      lr


@=========================================================================
@ ROM Access Speed
@=========================================================================
regROMAccess:   .byte   0
                .byte   0
                .byte   0
                .byte   0

@-------------------------------------------------------------------------
@ 0x420D MEMSEL - ROM Access Speed
@-------------------------------------------------------------------------
W420D:
    strb    r1, regROMAccess
    tsts    r1, #1
    ldreq   r0, ScanlineCode
    ldrne   r0, ScanlineCodeFast
    
    ldr     r2, =Scanline_Cycle1
    str     r0, [r2]
    ldr     r2, =Scanline_Cycle2
    str     r0, [r2]
    ldr     r2, =Scanline_Cycle3
    str     r0, [r2]
    bx      lr

ScanlineCode:
    subs    SnesCYCLES, SnesCYCLES, #(CYCLES_PER_SCANLINE<<CYCLE_SHIFT)
ScanlineCodeFast:    
    subs    SnesCYCLES, SnesCYCLES, #(CYCLES_PER_SCANLINE_FAST<<CYCLE_SHIFT)
    
    .ltorg


@=========================================================================
@ IO routines
@=========================================================================

@-------------------------------------------------------------------------
@ No IO operation
@-------------------------------------------------------------------------
IONOP:
    mov     r1, #0                    
    bx      lr


@=========================================================================
@ SAVE RAM Input/Output
@=========================================================================
R_SAV:
    mov     r1, #0
    ldr     r2, =SaveRAMMask
    ldr     r2, [r2]
    cmp     r2, #0
    bxeq    lr

    and     r0, r0, r2
    add     r0, r0, #0x0e000000
    ldrb    r1, [r0]
    
    bx      lr

W_SAV:
    ldr     r2, =SaveRAMMask
    ldr     r2, [r2]
    cmp     r2, #0
    bxeq    lr
    
    and     r0, r0, r2
    add     r0, r0, #0x0e000000
    strb    r1, [r0]

    bx      lr
    

@=========================================================================
@ DMA
@=========================================================================
regDMAControl:      .byte 0,0,0,0,0,0,0,0       
regDMADest:         .byte 0,0,0,0,0,0,0,0
regDMASourceL:       
    .byte   0
regDMASourceH:
    .byte   0
regDMASourceB:
    .byte   0
    .byte   0
    
    .rept   28
    .byte   0
    .endr
regDMASizeL:         
    .byte   0
regDMASizeH:
    .byte   0
regHDMAIndAddressB:
    .byte   0
    .byte   0

    .rept   28
    .byte   0
    .endr

regHDMAAddressL:     
    .byte   0
regHDMAAddressH:
    .byte   0
regHDMAAddressB:
    .byte   0
    .byte   0

    .rept   28
    .byte   0
    .endr

regHDMAGBAAddress:
    .rept   8
    .word   0
    .endr

regHDMALinecounter:     
    .byte  0,0,0,0,0,0,0,0

regHDMAVcounter:     
    .byte  0,0,0,0,0,0,0,0

DMATransferModeLength:
    .byte   1,2,2,4,4,4,2,4


@-------------------------------------------------------------------------
@ Some DMA macros
@-------------------------------------------------------------------------
.macro movpc reg
    .ifeq \reg-0
        mov pc, r9
    .endif
    .ifeq \reg-1
        mov pc, r10
    .endif
    .ifeq \reg-2
        mov pc, r11
    .endif
    .ifeq \reg-3
        mov pc, r12
    .endif
.endm

.macro dmaWrite r1, r2, r3, r4
    .ifeq (\r1+\r2+\r3+\r4)-0
        ldmia   r3!, {r9}
    .endif
    .ifeq (\r1+\r2+\r3+\r4)-2
        ldmia   r3!, {r9, r10}
    .endif
    .ifeq (\r1+\r2+\r3+\r4)-6
        ldmia   r3!, {r9-r12}
    .endif
1:
    ldrb    r1, [r6], r5
    mov     lr, pc
    movpc   \r1
    subs    r4, r4, #0x00010000
    beq     DMA_NextChannel

    ldrb    r1, [r6], r5                
    mov     lr, pc
    movpc   \r2
    subs    r4, r4, #0x00010000
    beq     DMA_NextChannel

    ldrb    r1, [r6], r5
    mov     lr, pc
    movpc   \r3
    subs    r4, r4, #0x00010000
    beq     DMA_NextChannel

    ldrb    r1, [r6], r5
    mov     lr, pc
    movpc   \r4
    subs    r4, r4, #0x00010000
    beq     DMA_NextChannel

    b       1b
.endm

.macro dmaRead r1, r2, r3, r4
    .ifeq (\r1+\r2+\r3+\r4)-0
        ldmia   r3!, {r9}
    .endif
    .ifeq (\r1+\r2+\r3+\r4)-2
        ldmia   r3!, {r9, r10}
    .endif
    .ifeq (\r1+\r2+\r3+\r4)-6
        ldmia   r3!, {r9-r12}
    .endif
1:
    mov     lr, pc
    movpc   \r1
    strb    r1, [r6], r5
    subs    r4, r4, #0x00010000
    beq     DMA_NextChannel

    mov     lr, pc
    movpc   \r2
    strb    r1, [r6], r5
    subs    r4, r4, #0x00010000
    beq     DMA_NextChannel

    mov     lr, pc
    movpc   \r3
    strb    r1, [r6], r5
    subs    r4, r4, #0x00010000
    beq     DMA_NextChannel

    mov     lr, pc
    movpc   \r4
    strb    r1, [r6], r5
    subs    r4, r4, #0x00010000
    beq     DMA_NextChannel

    b       1b
.endm



@-------------------------------------------------------------------------
@ 0x420B DMA Enable
@   76543210    (channels)
@-------------------------------------------------------------------------
regDMACycles:       .word   0
regDMAEnable:       .byte   0
regHDMAEnable:      .byte   0
regHDMAEnable2:     .byte   0
                    .byte   0

W420B:
    strb    r1, regDMAEnable
    stmfd   sp!, {r3-r12, lr}
    mov     r2, #0
    str     r2, regDMACycles
    mov     r8, #-1

DMA_Setup:
    @ set up the DMA transfer
    @
    ldrb    r1, regDMAEnable
    add     r8, r8, #1
    tsts    r1, #0xff
    beq     DMA_End
    
    movs    r1, r1, lsr #1
    strb    r1, regDMAEnable
    bcc     DMA_Setup

    ldr     r0, =regDMAControl
    ldrb    r0, [r0, r8]
    tsts    r0, #0x10
    movne   r5, #-1
    moveq   r5, #1
    tsts    r0, #0x08
    movne   r5, #0                      @ r5, increment/decrement register
    tsts    r0, #0x80                   @ cpsr = read or write?

    and     r7, r0, #0x7                @ r7 is now the transfer mode
    ldr     r0, =regDMADest
    ldrb    r4, [r0, r8]                
    add     r4, r4, #0x2100             
    ldreq   r3, =IOWrite                 
    ldrne   r3, =IORead
    add     r3, r3, r4, lsl #2          @ r3 = decoder address for DMA Dest

    ldr     r0, =regDMASourceL
    ldr     r0, [r0, r8, lsl #2]        
    
    TranslateAddressDMA

    mov     r6, r0                      @ r6 = GBA effective address

    ldr     r4, =regDMASizeL
    ldr     r4, [r4, r8, lsl #2]        @ r4 = 00000000 ????????? ssssssss ssssssss (DMA transfer size)
    mov     r4, r4, lsl #16             @ r4 = ssssssss sssssssss 00000000 00000000 (DMA transfer size)
    
    ldr     r2, regDMACycles
    add     r2, r2, #(4<<CYCLE_SHIFT)   @ overhead per channel
    
    .ifgt CYCLE_SHIFT-16
    add     r2, r2, r4, lsl #(CYCLE_SHIFT-16) @ r2 = stores the cycles used for the DMA transfer
    .else
    add     r2, r2, r4, lsr #(16-CYCLE_SHIFT) @ r2 = stores the cycles used for the DMA transfer
    .endif
    
    str     r2, regDMACycles

    ldreq   r0, =DMA_WriteJump          @ write
    ldrne   r0, =DMA_ReadJump           @ read
    ldr     pc, [r0, r7, lsl #2]        @ jump to the appropriate DMA transfer mode

    @ version 0.22 fix
    @ updates the DMA source address

DMA_NextChannel:
    @ increment the DMA register here
    @
    ldr     r7, =regDMASizeL
    add     r7, r7, r8, lsl #2
    mov     r6, #0
    ldrh    r4, [r7]
    bic     r4, r4, #0x00ff0000         @ r4 = 00000000 00000000 ssssssss ssssssss (DMA transfer size)
    strh    r6, [r7]
    
    ldr     r7, =regDMASourceL
    ldr     r6, [r7, r8, lsl #2]                    
    
    @ version 0.25 fix
    @ increment/decrement the source address based on the increment mode.
    @ but make sure we don't modify the bank
    @
    mul     r4, r5, r4
    add     r6, r6, r4
    add     r7, r7, r8, lsl #2
    strh    r6, [r7]
    
    b       DMA_Setup

DMA_End:
    ldmfd   sp!, {r3-r12, lr}
    
    ldr     r2, regDMACycles
    add     SnesCYCLES, SnesCYCLES, r2
    bx      lr

@-------------------------------------------------------------------------
@ DMA Writes
@-------------------------------------------------------------------------
DMA_Write_0000:
    dmaWrite    0, 0, 0, 0

DMA_Write_0011:
    dmaWrite    0, 0, 1, 1

DMA_Write_0101:
    dmaWrite    0, 1, 0, 1

DMA_Write_0123:
    dmaWrite    0, 1, 2, 3

DMA_WriteJump:
    .long   DMA_Write_0000, DMA_Write_0101, DMA_Write_0000, DMA_Write_0011
    .long   DMA_Write_0123, DMA_Write_0101, DMA_Write_0000, DMA_Write_0011


@-------------------------------------------------------------------------
@ DMA Reads
@-------------------------------------------------------------------------
DMA_Read_0000:
    dmaRead    0, 0, 0, 0

DMA_Read_0011:
    dmaRead    0, 0, 1, 1

DMA_Read_0101:
    dmaRead    0, 1, 0, 1

DMA_Read_0123:
    dmaRead    0, 1, 2, 3

DMA_ReadJump:
    .long   DMA_Read_0000, DMA_Read_0101, DMA_Read_0000, DMA_Read_0011
    .long   DMA_Read_0123, DMA_Read_0101, DMA_Read_0000, DMA_Read_0011


@-------------------------------------------------------------------------
@ 0x420C HDMA Enable
@   76543210    (channels)
@-------------------------------------------------------------------------
W420C:
    strb    r1, regHDMAEnable
    strb    r1, regHDMAEnable2
    
    cmp     r1, #0
    moveq   r2, #0
    ldrne   r2, =HDMAFrameInit_Code
    ldrne   r2, [r2]

    ldr     r0, =Scanline0_FrameInit
    str     r2, [r0]
    
    mov     r2, #0
    ldr     r0, =ScanlineEnd_HDMA
    str     r2, [r0]
    
    @ version 0.26 fix
    @ why is this here in the first place???!!! :(
    @ bx lr
    @ version 0.26 fix end
    
    @ if not in vblank, initialize the frame
    @
    ldr     r2, =vBlankScan
    ldr     r2, [r2]
    ldr     r0, =VerticalCount              
    ldr     r0, [r0]
    cmp     r0, r2
    @cmp     r0, #-62                    @ hack, don't start HDMA after scan 200...
    bxge    lr
    
    stmfd   sp!, {lr}
    bl      HDMA_FrameInit
    ldmfd   sp!, {lr}
    bx      lr

.macro  GetDMAChannel
    mov     r0, r0, lsr #4
    and     r0, r0, #0x7
.endm

@-------------------------------------------------------------------------
@ DMA Write
@-------------------------------------------------------------------------
W43x0:
    GetDMAChannel
    ldr     r2, =regDMAControl
    strb    r1, [r2, r0]
    bx      lr

W43x1:
    GetDMAChannel
    ldr     r2, =regDMADest
    strb    r1, [r2, r0]
    bx      lr

W43x2:
    GetDMAChannel
    ldr     r2, =regDMASourceL
    strb    r1, [r2, r0, lsl #2]
    bx      lr

W43x3:
    GetDMAChannel
    ldr     r2, =regDMASourceH
    strb    r1, [r2, r0, lsl #2]
    bx      lr

W43x4:
    GetDMAChannel
    ldr     r2, =regDMASourceB
    strb    r1, [r2, r0, lsl #2]
    ldr     r2, =regHDMAAddressB
    strb    r1, [r2, r0, lsl #2]
    bx      lr

W43x5:
    GetDMAChannel
    ldr     r2, =regDMASizeL
    strb    r1, [r2, r0, lsl #2]
    bx      lr

W43x6:
    GetDMAChannel
    ldr     r2, =regDMASizeH
    strb    r1, [r2, r0, lsl #2]
    bx      lr

W43x7:
    GetDMAChannel
    ldr     r2, =regHDMAIndAddressB
    strb    r1, [r2, r0, lsl #2]
    bx      lr

W43x8:
    GetDMAChannel
    ldr     r2, =regHDMAAddressL
    strb    r1, [r2, r0, lsl #2]
    bx      lr

W43x9:
    GetDMAChannel
    ldr     r2, =regHDMAAddressH
    strb    r1, [r2, r0, lsl #2]
    bx      lr

W43xA:
    GetDMAChannel
    ldr     r2, =regHDMALinecounter
    strb    r1, [r2, r0]
    bx      lr


@-------------------------------------------------------------------------
@ DMA Read
@-------------------------------------------------------------------------
R43x0:
    GetDMAChannel
    ldr     r2, =regDMAControl
    ldrb    r1, [r2, r0]
    bx      lr

R43x1:
    GetDMAChannel
    ldr     r2, =regDMADest
    ldrb    r1, [r2, r0]
    bx      lr

R43x2:
    GetDMAChannel
    ldr     r2, =regDMASourceL
    ldrb    r1, [r2, r0, lsl #2]
    bx      lr

R43x3:
    GetDMAChannel
    ldr     r2, =regDMASourceH
    ldrb    r1, [r2, r0, lsl #2]
    bx      lr

R43x4:
    GetDMAChannel
    ldr     r2, =regDMASourceB
    ldrb    r1, [r2, r0, lsl #2]
    bx      lr

R43x5:
    GetDMAChannel
    ldr     r2, =regDMASizeL
    ldrb    r1, [r2, r0, lsl #2]
    bx      lr

R43x6:
    GetDMAChannel
    ldr     r2, =regDMASizeH
    ldrb    r1, [r2, r0, lsl #2]
    bx      lr

R43x7:
    GetDMAChannel
    ldr     r2, =regHDMAIndAddressB
    ldrb    r1, [r2, r0, lsl #2]
    bx      lr

R43x8:
    GetDMAChannel
    ldr     r2, =regHDMAAddressL
    ldrb    r1, [r2, r0, lsl #2]
    bx      lr

R43x9:
    GetDMAChannel
    ldr     r2, =regHDMAAddressH
    ldrb    r1, [r2, r0, lsl #2]
    bx      lr

R43xA:
    GetDMAChannel
    ldr     r2, =regHDMALinecounter
    ldrb    r1, [r2, r0]
    bx      lr

    .ltorg


@-------------------------------------------------------------------------
@ version 0.25
@ HDMA. Called at the beginning of every frame
@-------------------------------------------------------------------------
HDMA_FrameInit:
    nop                                     @ self-modifying code. either nop or bx lr
    ldr     r2, =HDMA_Code
    ldr     r2, [r2]
    ldr     r0, =ScanlineEnd_HDMA
    str     r2, [r0]
    
    ldrb    r0, regHDMAEnable
    
    stmfd   sp!, {r3-r12}
    mov     r8, #-1
    
    ldrb    r3, regHDMAEnable
    ldr     r2, =(HDMA_Register-32)
    
HDMA_FrameInit_Setup:
    add     r2, r2, #32
    add     r8, r8, #1
    cmp     r8, #8
    beq     HDMA_FrameInit_End
    
    mov     r0, #1
    tsts    r3, r0, lsl r8
    beq     HDMA_FrameInit_Setup

    ldr     r0, =regDMASourceL
    ldr     r5, [r0, r8, lsl #2]            @ 
    mov     r0, r5
    TranslateAddressDMA r5                  @ r5 = translated HDMA table address

    ldr     r0, =regDMADest
    ldrb    r0, [r0, r8]                
    ldr     r6, =HDMAWrite                 
    add     r6, r6, r0, lsl #2              
    ldmfd   r6, {r9, r10, r11, r12}         @ r9-r12 stores the IO address to write to
    
    ldr     r6, =IONOP
    cmp     r9, r6
    mov     r0, #1
    biceq   r3, r3, r0, lsl r8

    ldr     r0, =regDMAControl
    ldrb    r0, [r0, r8]
    and     r7, r0, #0x7                    @ r7 least sig BYTE is now the transfer mode
    and     r0, r0, #0x40
    orr     r7, r7, r0, lsl #25             @ r7 most sig BIT = indirect/direct mode

    tsts    r7, #0x80000000

    ldrb    r4, [r5], #1
    mov     r6, r5

    beq     HDMA_FrameInit_Direct
    ldrb    r0, [r5], #1                    @ if indirect mode, load HDMA address from parent table
    ldrb    r1, [r5], #1
    add     r0, r0, r1, lsl #8
    ldr     r1, =regHDMAIndAddressB         @ join it with the bank, 
    ldrb    r1, [r1, r8, lsl #2]
    add     r0, r0, r1, lsl #16
    TranslateAddressDMA     r6              @ translated address and store in r6
    
HDMA_FrameInit_Direct:
    stmia   r2, {r4-r7, r9-r12}
    b       HDMA_FrameInit_Setup
    
HDMA_FrameInit_End:
    strb    r3, HDMAChannelEnable
    strb    r3, HDMADoTransfer
    ldmfd   sp!, {r3-r12}
    bx      lr

@-------------------------------------------------------------------------
@ version 0.25
@ HDMA code. This is called normally at the end of EVERY scanline up to
@ VBlank when HDMA is activated.
@
@ (very slow!)
@-------------------------------------------------------------------------
HDMAChannelEnable:  .byte   0
HDMADoTransfer:     .byte   0
HDMACycleCount:     .hword  0

HDMA_Start:
    nop                                     @ self-modifying code. either nop or bx lr
    stmfd   sp!, {r3-r12, lr}
    
    ldrh    r3, HDMAChannelEnable
    cmp     r3, #0
    ldreq   r0, =ScanlineEnd_HDMA
    streq   r3, [r0]
    beq     HDMA_End
    
    add     r3, r3, #0x00040000             @ add ~4 cycle overhead 
    mov     r8, #-1

HDMA_Setup:
    @ set up the HDMA transfer
    @
    add     r8, r8, #1
    cmp     r8, #8
    beq     HDMA_End
    
    mov     r0, #1
    tsts    r3, r0, lsl r8
    beq     HDMA_Setup
    
    add     r3, r3, #0x00020000             @ active HDMA channel: add ~2 cycle overhead
    
    ldr     r2, =HDMA_Register
    add     r2, r2, r8, lsl #5
    ldmia   r2, {r4-r7, r9-r12}             @ load the GBA registers for this HDMA channel

    mov     r0, #0x100                      
    tsts    r3, r0, lsl r8                  @ is DoTransfer = true?

    ldrne   r0, =HDMA_WriteJump             @ yes, perform HDMA write
    ldrne   pc, [r0, r7, lsl #2]            @ jump to the appropriate DMA transfer mode,
                                            @ otherwise, skip and proceed to next scanline

HDMA_EndWrite:    
    sub     r4, r4, #1
    movs    r1, r4, lsl #25                 @ get the repeat flag (in carry) and test if counter = 0
    
    mov     r1, #0x100
    biccc   r3, r3, r1, lsl r8              @ Set DoTransfer = repeat bit
    orrcs   r3, r3, r1, lsl r8

    ldr     r2, =HDMA_Register              @ load into r2, the location to save the registers
    add     r2, r2, r8, lsl #5

    stmneia r2, {r4-r7, r9-r12}             @ if Counter > 0, save the GBA registers
    bne     HDMA_Setup                      @ and go to next channel
    
    tsts    r7, #0x80000000
    ldrneb  r4, [r5], #1                    @ otherwise, read the Line Counter from the parent HDMA table (indirect mode)
    ldreqb  r4, [r6], #1                    @ otherwise, read the Line Counter from the HDMA table (direct mode)
    
    cmp     r4, #0                          @ if the counter loaded = 0, 
    beq     HDMA_ChannelTerminated          @   terminate the channel
    orr     r3, r3, r1, lsl r8              @ set DoTransfer = true
    
    tsts    r7, #0x80000000                 @ if direct mode
    stmeqia r2, {r4-r7, r9-r12}             @   go to next channel
    beq     HDMA_Setup
    
    ldrb    r0, [r5], #1                    @ else if indirect mode, load HDMA address from parent table
    ldrb    r1, [r5], #1
    add     r0, r0, r1, lsl #8
    ldr     r1, =regHDMAIndAddressB         @ join it with the bank, 
    ldrb    r1, [r1, r8, lsl #2]
    add     r0, r0, r1, lsl #16
    TranslateAddressDMA     r6              @ translated address and store in r6
    stmia   r2, {r4-r7, r9-r12}             @ save the GBA registers for this HDMA channel
    b       HDMA_Setup                      @ go to next channel
    
HDMA_ChannelTerminated:
    stmia   r2, {r4-r7, r9-r12}             @ save the GBA registers for this HDMA channel
    mov     r2, #0x001
    bic     r3, r3, r1, lsl r8              @ terminate channel and set ChannelEnable = false
    bic     r3, r3, r2, lsl r8              @ terminate channel and set ChannelEnable = false
    b       HDMA_Setup                      @ go to next channel
    
HDMA_End:
    strh    r3, HDMAChannelEnable
    mov     r0, r3, lsr #16
    ldmfd   sp!, {r3-r12, lr}
    
    add     SnesCYCLES, SnesCYCLES, r0, lsl #CYCLE_SHIFT
    bx      lr
    
@-------------------------------------------------------------------------
@ version 0.25
@ HDMA write macro
@-------------------------------------------------------------------------
.macro hdmaWrite r1, r2, r3, r4, len
    .ifge   \len-1
    ldrb    r1, [r6], #1
    mov     lr, pc
    movpc   \r1
    .endif

    .ifge   \len-2
    ldrb    r1, [r6], #1                
    mov     lr, pc
    movpc   \r2
    .endif

    .ifge   \len-3
    ldrb    r1, [r6], #1
    mov     lr, pc
    movpc   \r3
    .endif

    .ifge   \len-4
    ldrb    r1, [r6], #1
    mov     lr, pc
    movpc   \r4
    .endif
    
    add     r3, r3, #(\len << 16)           @ so add the number of cycles into r3
    b       HDMA_EndWrite
.endm


@-------------------------------------------------------------------------
@ version 0.25
@ HDMA register restore
@-------------------------------------------------------------------------

HDMA_Register:
    .rept   8
    
    @       r4 = Line Counter
    @       r5 = parent HDMA table address (only used for indirect mode)
    @       r6 = values table address  (translated to GBA space)
    @       r7 = transfer mode + indirect/direct
    @       r9-r12 = IO write addresses
    @
    .word   0,0,0,0,0,0,0,0
    .endr 


@-------------------------------------------------------------------------
@ version 0.25
@ HDMA Writes
@-------------------------------------------------------------------------
HDMA_Write_0000_1:
    hdmaWrite    0, 0, 0, 0, 1

HDMA_Write_0000_2:
    hdmaWrite    0, 0, 0, 0, 2

HDMA_Write_0011_4:
    hdmaWrite    0, 0, 1, 1, 4

HDMA_Write_0101_2:
    hdmaWrite    0, 1, 0, 1, 2

HDMA_Write_0101_4:
    hdmaWrite    0, 1, 0, 1, 4

HDMA_Write_0123_4:
    hdmaWrite    0, 1, 2, 3, 4

HDMA_WriteJump:
    .long   HDMA_Write_0000_1, HDMA_Write_0101_2, HDMA_Write_0000_2, HDMA_Write_0011_4
    .long   HDMA_Write_0123_4, HDMA_Write_0101_4, HDMA_Write_0000_2, HDMA_Write_0011_4


    
    .ltorg

@=========================================================================
@ Renderer
@=========================================================================

@-------------------------------------------------------------------------
@ Renderer variables
@-------------------------------------------------------------------------

bgCurTileOffset:  .word   0x06010000

ScreenMode:       .word   0

bg1VRAMOffset:    .word   0x00000000  
bg2VRAMOffset:    .word   0x00000000  
bg3VRAMOffset:    .word   0x00000000  
bg4VRAMOffset:    .word   0x00000000
bg3Base:          .word   0x00000000

bg1TileOffset:    .word   0x00000000  
bg2TileOffset:    .word   0x00000000  
bg3TileOffset:    .word   0x00000000  
bg4TileOffset:    .word   0x00000000

NumColors:        .word   0

@=========================================================================
@ Tilemap copy
@=========================================================================

@-------------------------------------------------------------------------
@ Copy 1024 Tile Maps
@   r0: VRAM Offset from 0x02020000
@   r1: BG number (0-3)
@   r9: palette use (#0x00000000, or #0x0008000)
@ destroys: r0, r1, r2, r3, r4, r8
@-------------------------------------------------------------------------
CopyTileMap:
    ldr     r3, =bg1TileOffset
    ldr     r3, [r3, r1, lsl #2]
    add     r3, r3, r0
    bic     r3, r3, #0x00ff0000         @ v0.24 sanity fix 

    ldr     r2, =tileMap

    ldr     r1, =snesVramBase
    add     r1, r1, r0

    mov     r8, #1024
copyTileMapLoop:
    ldrh    r4, [r1], #2                @ 3 
    ldrb    r0, [r2, r4, lsr #8]        @ 1
    bic     r4, r4, #0xff00             @ 1
    orr     r4, r4, r0, lsl #8          @ 1
    orr     r4, r4, r9
    strh    r4, [r3], #2                @ 3
    bic     r3, r3, #0x00ff0000         @ v0.24 sanity fix 
    subs    r8, r8, #1
    bne     copyTileMapLoop
    mov     pc, lr

    .ltorg

@-------------------------------------------------------------------------
@ Unpack 256 color SNES VRAM Tile character to GBA VRAM Tile Character
@   r0: SNES bitmap
@   r1: SNES VRAM address
@   r2: address to the byte unpack mapper
@   r3: GBA VRAM address
@   r4: unpacked GBA bitmap
@   r5: result GBA bitmap
@-------------------------------------------------------------------------
.macro  CopyChar_1row_256plane colorPlane, offset
    ldrb    r0, [r1, #\offset]      @ r0 = 00000000 00000000 00000000 abcdefgh
    
    and     r7, r0, #0xf
    ldr     r4, [r2, r7, lsl #2]    @ r4 = 0000000e 0000000f 0000000g 0000000h 
    orr     r6, r6, r4, lsl #\colorPlane
    
    mov     r7, r0, lsr #4
    ldr     r4, [r2, r7, lsl #2]    @ r4 = 0000000a 0000000b 0000000c 0000000d 
    orr     r5, r5, r4, lsl #\colorPlane
.endm

.macro  CopyChar_1row_256color row
    mov     r5, #0
    mov     r6, #0
    CopyChar_1row_256plane      0, 0
    CopyChar_1row_256plane      1, 1
    CopyChar_1row_256plane      2, 16
    CopyChar_1row_256plane      3, 17
    CopyChar_1row_256plane      4, 32
    CopyChar_1row_256plane      5, 33
    CopyChar_1row_256plane      6, 48
    CopyChar_1row_256plane      7, 49
    str     r5, [r3], #4            @ write to GBA VRAM
    str     r6, [r3], #4            @ write to GBA VRAM
.endm


@-------------------------------------------------------------------------
@ Unpack 4/16 color SNES VRAM Tile character to GBA VRAM Tile Character
@   r0: SNES bitmap
@   r1: SNES VRAM address
@   r2: address to the byte unpack mapper
@   r3: GBA VRAM address
@   r4: unpacked GBA bitmap
@   r5: result GBA bitmap
@-------------------------------------------------------------------------
.macro  CopyChar_1row_16plane colorPlane, offset
    ldrb    r0, [r1, #\offset]      @ r0 = 00000000 00000000 00000000 abcdefgh
    ldr     r4, [r2, r0, lsl #2]    @ r4 = 000a000b 000c000d 000e000f 000g000h 
    orr     r5, r5, r4, lsl #\colorPlane
.endm

.macro  CopyChar_1row_16color numColors
    mov     r5, #0
    CopyChar_1row_16plane       0, 0
    CopyChar_1row_16plane       1, 1
    .ifeq   \numColors-16
        CopyChar_1row_16plane   2, 16
        CopyChar_1row_16plane   3, 17
    .endif
    str     r5, [r3], #4            @ write to GBA VRAM
.endm


@-------------------------------------------------------------------------
@ Unpack 256 color SNES VRAM Tile character to GBA VRAM Tile Character
@   r1: SNES VRAM address
@   r2: address to the byte unpack mapper
@   r3: GBA VRAM address
@-------------------------------------------------------------------------
CopyChar_256color:
    mov     r8, #1024
CopyChar_256Loop:
    mov     r9, #8
CopyChar_256Loop2:
    CopyChar_1row_256color 
    add     r1, r1, #2
    subs    r9, r9, #1
    bne     CopyChar_256Loop2
    
    add     r1, r1, #48
    subs    r8, r8, #1
    bne     CopyChar_256Loop
    mov     pc, lr

@-------------------------------------------------------------------------
@ Unpack 4/16 color SNES VRAM Tile character to GBA VRAM Tile Character
@   r1: SNES VRAM address
@   r2: address to the byte unpack mapper
@   r3: GBA VRAM address
@-------------------------------------------------------------------------
CopyChar_16color:
    mov     r8, #1024
CopyChar_16Loop:
    mov     r9, #8
CopyChar_16Loop2:
    CopyChar_1row_16color 16
    add     r1, r1, #2
    subs    r9, r9, #1
    bne     CopyChar_16Loop2

    add     r1, r1, #16
    subs    r8, r8, #1
    bne     CopyChar_16Loop
    mov     pc, lr


@-------------------------------------------------------------------------
@ Unpack 4/16 color SNES VRAM Tile character to GBA VRAM Tile Character
@   r1: SNES VRAM address
@   r2: address to the byte unpack mapper
@   r3: GBA VRAM address
@-------------------------------------------------------------------------
CopyChar_4color:
    mov     r8, #1024
CopyChar_4Loop:
    mov     r9, #8
CopyChar_4Loop2:
    CopyChar_1row_16color 4
    add     r1, r1, #2
    subs    r9, r9, #1
    bne     CopyChar_4Loop2

    subs    r8, r8, #1
    bne     CopyChar_4Loop
    mov     pc, lr


@-------------------------------------------------------------------------
@ Unpack 16 color SNES VRAM OBJ character to GBA VRAM OBJ Character
@   r1: SNES VRAM address
@   r2: address to the byte unpack mapper
@   r3: GBA VRAM address
@-------------------------------------------------------------------------
CopyObjChar_16color:
    mov     r8, #256
    sub     r3, r3, #512
CopyObjChar_16Loop:
    tsts    r8, #0xF
    addeq   r3, r3, #512

    mov     r9, #8
CopyObjChar_16Loop2:
    CopyChar_1row_16color 16
    add     r1, r1, #2
    subs    r9, r9, #1
    bne     CopyObjChar_16Loop2
    
    add     r1, r1, #16
    subs    r8, r8, #1
    bne     CopyObjChar_16Loop
    mov     pc, lr



@=========================================================================
@ VRAM write-through functions
@   r0: stores the VRAM offset 
@       from SNES VRAM base (0x02020000)
@=========================================================================

@-------------------------------------------------------------------------
@ Do nothing
@-------------------------------------------------------------------------
VRAMWriteNOP2:
    bx      lr
    
VRAMWriteNOP:
    bx      lr

@-------------------------------------------------------------------------
@ VRAM Write Tilemap
@-------------------------------------------------------------------------
VRAMWriteTileMap:
    stmfd   sp!, {r3-r5}

    ldr     r2, =VRAMBG
    ldrb    r2, [r2, r1]                @ r2 = BG number

    cmp     r2, #2
    moveq   r5, #0x8000                 @ use the 4-color palette
    movne   r5, #0x0000                 @ use the 16-color palette

    ldr     r3, =bg1TileOffset
    ldr     r3, [r3, r2, lsl #2]
    add     r3, r3, r0                  
    bic     r3, r3, #0x00ff0000         @ v0.24 sanity fix
    
    ldr     r2, =tileMap

    ldr     r1, =snesVramBase
    add     r1, r1, r0

    ldrh    r4, [r1], #2                @ 3 
    ldrb    r0, [r2, r4, lsr #8]        @ 1
    bic     r4, r4, #0xff00             @ 1
    orr     r4, r4, r0, lsl #8          @ 1
    orr     r4, r4, r5
    strh    r4, [r3], #2                @ 3

    ldmfd   sp!, {r3-r5}
    bx      lr

@-------------------------------------------------------------------------
@ VRAM Write BG character
@-------------------------------------------------------------------------
VRAMWriteBGCharOr:  .byte   0, 0xe, 0x1e, 0x3e
VRAMWriteBGCopyCharTable:
    .word   VRAMWriteNOP, CopyChar_4Loop, CopyChar_16Loop, VRAMWriteNOP

VRAMWriteBGChar:
    stmfd   sp!, {r3}
    ldr     r3, =VRAMBGColors
    ldrb    r3, [r3, r1]                        @ r3 = number of colors, 0=na, 1=4, 2=16, 3=256
    
    ldr     r2, =VRAMWriteBGCharOr              
    ldrb    r2, [r2, r3]                        @ r2 = OR mask for the bitmap location.
    and     r1, r0, r2
    cmp     r1, r2
    ldmnefd sp!, {r3}
    bxne    lr

    stmfd   sp!, {r4-r9, lr}
    mov     r1, r0, lsr #11
    mov     r6, r2
    ldr     r2, =RenderCopyCharUnpackTable      @ r2 = char unpacker table
    ldr     r2, [r2, r3, lsl #2]

    ldr     r7, =VRAMWriteBGCopyCharTable       @ r4 = jump address
    ldr     r7, [r7, r3, lsl #2]

    orr     r6, r6, #1
    bic     r0, r0, r6

    ldr     r3, =VRAMBG
    ldrb    r3, [r3, r1]
    ldr     r4, =bg1VRAMOffset
    ldr     r3, [r4, r3, lsl #2]

    ldr     r1, =snesVramBase
    add     r1, r1, r0                          @ r1 = stores the SNES VRAM address     

    cmp     r6, #0xf
    addne   r3, r3, r0                          @ r3 = BG vram offset
    bne     VRAMWriteBGCharFinal  
    
    @ special case for 4 color characters
    @
    ldr     r6, bg3Base
    sub     r0, r0, r6
    add     r6, r6, r0, lsl #1
    add     r3, r3, r6

VRAMWriteBGCharFinal:
    ldr     r4, bgCurTileOffset
    cmp     r3, r4
    bge     VRAMWriteBGCharEnd

    mov     r8, #1
    mov     lr, pc
    bx      r7
    
VRAMWriteBGCharEnd:  
    ldmfd   sp!, {r4-r9, lr}
    ldmfd   sp!, {r3}
    bx      lr


@-------------------------------------------------------------------------
@ VRAM Write OBJ 16 color CHR
@-------------------------------------------------------------------------
VRAMWriteObj1Char_16color:
    and     r1, r0, #0x1e
    cmp     r1, #0x1e
    bxne    lr

    stmfd   sp!, {r3-r9, lr}
    ldr     r3, VRAMObj1Offset
    b       VRAMWriteObj

VRAMWriteObj0Char_16color:
    and     r1, r0, #0x1e
    cmp     r1, #0x1e
    bxne    lr

    stmfd   sp!, {r3-r9, lr}
    ldr     r3, VRAMObj0Offset

VRAMWriteObj:
    ldr     r2, =charUnpack4
    ldr     r1, =snesVramBase
    bic     r0, r0, #0x1f           @ r0 = 00000000 00000000 aaaaaaaa aaa00000  (offset in SNES VRAM)
    add     r1, r1, r0
    
    and     r4, r0, #(0xF << 9)     @ r4 = 00000000 00000000 000aaaa0 00000000
    bic     r0, r0, #(0xF << 9)     @ r0 = 00000000 00000000 aaa0000a aaa00000
    add     r0, r0, r4, lsl #1
    add     r3, r3, r0
    mov     r8, #1
    bl      CopyObjChar_16Loop
    ldmfd   sp!, {r3-r9, lr}
    bx      lr

VRAMObj0Offset:   .word   0
VRAMObj1Offset:   .word   0
    .ltorg


@-------------------------------------------------------------------------
@ VRAM Mode 7 BG CHR/TILE
@ version 0.23 
@-------------------------------------------------------------------------
VRAMWriteMode7:
    stmfd   sp!, {r3}
    
    ldr     r1, =snesVramBase
    ldrh    r1, [r1, r0]
    mov     r1, r1, ror #8
    mov     r0, r0, lsr #1
    tsts    r0, #1
    bic     r0, r0, #1

    @ character
    @
    ldr     r2, =(gbaVramBase)
    ldrh    r2, [r2, r0]
    
    biceq   r2, r2, #0x00ff
    orreq   r3, r2, r1
    bicne   r2, r2, #0xff00
    orrne   r3, r2, r1, lsl #8
    
    ldr     r2, =(gbaVramBase)
    strh    r3, [r2, r0]
    
    @ tile
    @
    mov     r1, r1, lsr #24
    ldr     r2, =(gbaVramBase+0x8000)
    ldrh    r2, [r2, r0]

    biceq   r2, r2, #0x00ff
    orreq   r3, r2, r1
    bicne   r2, r2, #0xff00
    orrne   r3, r2, r1, lsl #8
    
    ldr     r2, =(gbaVramBase+0x8000)
    strh    r3, [r2, r0]

    ldmfd   sp!, {r3}
    
    bx      lr


yOffset:
    .byte 0xff
    .byte 0x00,0x00,0x00,0x01,0x01,0x01,0x02,0x02,0x03,0x03,0x03,0x04,0x04,0x05,0x05,0x05
    .byte 0x06,0x06,0x07,0x07,0x07,0x08,0x08,0x09,0x09,0x09,0x0a,0x0a,0x0b,0x0b,0x0b,0x0c
    .byte 0x0c,0x0d,0x0d,0x0d,0x0e,0x0e,0x0f,0x0f,0x0f,0x10,0x10,0x11,0x11,0x11,0x12,0x12
    .byte 0x13,0x13,0x13,0x14,0x14,0x15,0x15,0x15,0x16,0x16,0x17,0x17,0x17,0x18,0x18,0x19
    .byte 0x19,0x19,0x1a,0x1a,0x1b,0x1b,0x1b,0x1c,0x1c,0x1d,0x1d,0x1d,0x1e,0x1e,0x1f,0x1f
    .byte 0x1f,0x20,0x20,0x21,0x21,0x21,0x22,0x22,0x23,0x23,0x23,0x24,0x24,0x25,0x25,0x25
    .byte 0x26,0x26,0x27,0x27,0x27,0x28,0x28,0x29,0x29,0x29,0x2a,0x2a,0x2b,0x2b,0x2b,0x2c
    .byte 0x2c,0x2d,0x2d,0x2d,0x2e,0x2e,0x2f,0x2f,0x2f,0x30,0x30,0x31,0x31,0x31,0x32,0x32
    .byte 0x33,0x33,0x33,0x34,0x34,0x35,0x35,0x35,0x36,0x36,0x37,0x37,0x37,0x38,0x38,0x39
    .byte 0x39,0x39,0x3a,0x3a,0x3b,0x3b,0x3b,0x3c,0x3c,0x3d,0x3d,0x3d,0x3e,0x3e,0x3f,0x3f
    .byte 0x3f

    .rept 68
    .byte 0x00
    .endr
    .byte 0x00

@-------------------------------------------------------------------------
@ This is used for any mid-frame change for BG HOFS/VOFS
@-------------------------------------------------------------------------
    .align   4

bgOffset:
    .rept 161
    .hword 0x00
    .endr

    .hword  0

@-------------------------------------------------------------------------
@ Some variables for configuration
@-------------------------------------------------------------------------
configCursor:
    .word   0


@-------------------------------------------------------------------------
@ For debugging
@-------------------------------------------------------------------------
.ifeq   debug-1
    SetDebugState:
        ldr     r2, =debugMemoryBase
        ldr     r2, [r2, #0x7C]             @ r2 = breakpoint
        mov     r2, r2, lsr #8
        cmp     r2, #1
        bne     SetDebugState_TraceAndBreakpoint    
        
        subs    SnesCYCLES, SnesCYCLES, #0
        bx      lr

    SetDebugState_TraceAndBreakpoint:
        stmfd   sp!, {r3}
        
        mov     r1, SnesPC
        ldr     r3, =SnesPCOffset
        ldr     r3, [r3]
        add     r3, r1, r3

        cmp     r2, #0                      @ if not step through?
        ldreq   pc, =SetDebugState_UpdateState   @ then, update the state

        @ set the CPU state for every 1024 
        @ instructions executed
        @
        ldr     r1, =debugMemoryBase
        ldrh    r0, [r1, #0x80]
        add     r0, r0, #1
        strh    r0, [r1, #0x80]
        ldr     r1, =0x03ff
        tsts    r0, r1
        ldreq   pc, =SetDebugState_UpdateState

    SetDebugState_SkipUpdateState:

        cmp     r2, r3                  @ break point met, step through code
        bne     SetDebugState_Step

        ldr     r2, =debugMemoryBase
        mov     r0, #0
        str     r0, [r2, #0x7C]
        ldreq   pc, =SetDebugState_UpdateState

    SetDebugState_Step:
        cmp     r2, #0                  @ always step through code
        beq     VBAStep
        
        ldmfd   sp!, {r3}
        subs    SnesCYCLES, SnesCYCLES, #0
        bx      lr

    VBAStep:
        ldr     r1, =(debugMemoryBase+0x7C)
        mov     r0, #0
        strb    r0, [r1]                @ stop execution
        mov     r0, #0
        strb    r0, [r1, #1]            @ clear break point
        strb    r0, [r1, #2]
        strb    r0, [r1, #3]
    VBAStepLoop:
        ldrb    r0, [r1]
        cmp     r0, #1
        bne     VBAStepLoop             @ loop around here to simulate code stepping
        mov     r0, #0
        strb    r0, [r1]
    VBARun:
        ldmfd   sp!, {r3}
        subs    SnesCYCLES, SnesCYCLES, #0
        bx      lr


    .ltorg
.endif



    