/*
-------------------------------------------------------------------
Snezziboy v0.1

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
@ IO routines
@=========================================================================

    .align 4

@-------------------------------------------------------------------------
@ No IO operation
@-------------------------------------------------------------------------
IONOP:
    mov     r1, #0                    
    bx      lr


@=========================================================================
@ GBA IO interrupt
@   r0-r3, safe to use
@=========================================================================
gbaFCount:          .byte   0
gbaVBlankFlag:      .byte   0           @ for v-sync

    .align  4


@-------------------------------------------------------------------------
@ GBA interrupt
@-------------------------------------------------------------------------
gbaInterrupt:
    ldr     r0, =0x04000202
    ldrh    r1, [r0]
    tsts    r1, #0x01               @ v-blank interrupt
    bne     vblankInterrupt
    tsts    r1, #0x02               @ h-blank interrupt
    bne     hblankInterrupt
    bx      lr

@-------------------------------------------------------------------------
@ GBA Hblank interrupt
@-------------------------------------------------------------------------
hblankInterrupt:
    mov     r1, #0x2
    strh    r1, [r0]

    tsts    r1, #0x01               @ v-blank interrupt
    bxne    lr                      @ return if in v-blank

    ldr     r0, =0x04000006
    ldrh    r0, [r0]
    ldrb    r2, gbaFCount
    and     r2, r2, #1
    add     r2, r2, r0              @ for flickering

    ldr     r1, =yOffset
    ldrsb   r0, [r1, r2]            @ r1 = horizontal offset for all backgrounds.
    add     r2, r2, #1
    ldrsb   r1, [r1, r2]            
    cmp     r1, r0
    bxeq    lr                      @ branch away to be faster

    ldr     r3, =(regBG1VOffsetB-2)
    ldr     r2, =0x04000012         @ do vertical scaling for all backgrounds.

    ldrh    r0, [r3, #2]
    add     r0, r0, r1
    bic     r0, r0, #0xfe00
    strh    r0, [r2]

    ldrh    r0, [r3, #6]
    add     r0, r0, r1
    bic     r0, r0, #0xfe00
    strh    r0, [r2, #4]

    ldrh    r0, [r3, #10]
    add     r0, r0, r1
    bic     r0, r0, #0xfe00
    strh    r0, [r2, #8]

    bx      lr

@-------------------------------------------------------------------------
@ GBA vertical blank
@-------------------------------------------------------------------------
vblankInterrupt:
    ldrb    r2, gbaFCount           @ flip the frame-counter
    add     r2, r2, #1
    strb    r2, gbaFCount

    mov     r1, #0x1
    strh    r1, [r0]

    ldrb    r1, gbaVBlankFlag
    cmp     r1, #16
    addlt   r1, r1, #1
    strb    r1, gbaVBlankFlag       @ set the vertical blank for syncing

    bx      lr



@=========================================================================
@ Non-Maskable Interrupts
@=========================================================================
    SetText "NMI"
    .align  4
regHTime:   .word   0
regVTime:   .word   0
regVTime2:  .word   0
regNMI:     .byte   0
regIRQFlag: .byte   0
    .align  4
/*
.macro SetInterruptTimeout      TimeoutCycle, TimeoutAddr
    stmfd   sp!, {r3}
    ldr     r0, SnesCycleDelta
    add     r0, r0, SnesCYCLES
    ldr     r1, =CYCLES_MAX
    cmp     r0, r1
    subge   r0, r0, r1              @ r0 = current SNES CPU cycle

    mov     r2, r0
    ldr     r1, \TimeoutCycle
    subs    r0, r0, r1              @ r0 = current CPU cycle - timeout cycle
    
    ldrpl   r1, =CYCLES_MAX         @
    subpl   r0, r0, r1              @ then r0 = (current cycle - timeout cycle) - CYCLES_MAX

    ldr     r1, =\TimeoutAddr       @ if the timeout addr is the same, then change the timeout
    ldr     r3, InterruptAddr
    cmp     r1, r3
    beq     1f

    cmp     r0, SnesCYCLES          @ if not, check if( r0 < current timeout )
    blt     2f                      @ skip if the timeout is greater

1:
    mov     SnesCYCLES, SnesCYCLES, lsl #20
    add     SnesCYCLES, r0, SnesCYCLES, lsr #20     @ set the IRQ timeout

    sub     r2, r2, r0              @ r2 = current CPU cycle - IRQ timeout
    ldr     r0, =CYCLES_MAX*2
    cmp     r2, r0
    subge   r2, r2, r0, lsr #1
    str     r2, SnesCycleDelta

    str     r1, InterruptAddr       @ set the IRQ timeout address
2:
    ldmfd   sp!, {r3}
.endm
*/
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
    
    ldr     r0, VerticalCount
    cmp     r0, #(-262+225)
    orrge   r1, r1, #0x80

    cmp     SnesCYCLES, #(192 << CYCLE_SHIFT)
    orrge   r1, r1, #0x40

    bx      lr

    .ltorg



@=========================================================================
@ activated upon GBA's hblank interrupt, but executed only after:
@ 1. the current SNES instruction has finished execution, or
@ 2. after the current byte in the DMA has been written
@=========================================================================

snesHDMA:
/*
    stmfd   sp!, { r3-r12, lr }
    ldr     r2, =0x04000006
    ldrh    r2, [r2]                            @ r2 = VCOUNT
    cmp     r2, #0                              @ if VCOUNT=0, initialize the HDMA addresses 
                                                @ for all active channels
    beq     snesHDMA_Init                       @ else do transfer for this line.

@-------------------------------------------------------------------------

    @ begin doing all our transfers
snesHDMA_Transfer:
    ldr     r9, =regHDMALineCounter
    ldr     r10, =regHDMAGBAAddress
    ldr     r11, =regDMAControl
    ldr     r12, =HDMA_WriteJump
    ldrb    r3, regHDMAEnable2
    ldr     r7, =(snesHDMAIOWrite-16)
    mov     r8, #-1

snesHDMA_TransferLoop:
    add     r8, r8, #1
    tsts    r3, #0xff
    beq     snesHDMA_End
    movs    r3, r3, lsr #1
    bcc     snesHDMA_TransferLoop

    @ ok do the transfer here.
HDMA_WriteDirect:
    @ first load the current counter byte from DMA control bytes
    ldrb    r0, [r9, r8]
    cmp     r0, #0
    beq     snesHDMA_TransferLoop
    subs    r0, r0, #1                  @ if line counter is not zero yet,
    strneb  r0, [r9, r8]
    bne     snesHDMA_TransferLoop       @ then, go to next channel

    @ load the repeat/line counter byte
    ldr     r6, [r10, r8, lsl #2]       @ get the address of the HDMA table
    ldrb    r0, [r6], #1                @ r0 = repeat/line counter byte
    tsts    r0, #0x80
    movne   r0, #0x01                   @ if the msb is 1, set the count to 1
    strb    r0, [r9, r8]

    @ the decoder address location for DMA Dest.
    add     r7, r7, #16                 @ r7 = decoder address for DMA Dest

    @ find out the transfer mode and then
    @ jump to the relevant code for the respective transfer mode 
    ldrb    r2, [r11, r8]                 
    and     r2, r2, #0x7                @ ignore rest of flags, just worry about transfer mode.
    ldr     pc, [r12, r2, lsl #2]       @ the routine at HDMAWriteJump will branch back to snesHDMA_NextChannel

snesHDMA_NextChannel:
    str     r6, [r10, r8, lsl #2]        @ save the address

    b       snesHDMA_TransferLoop

@-------------------------------------------------------------------------

snesHDMA_Init:
    @ initialize the HDMA before doing any transfers
    ldrb    r3, regHDMAEnable
    strb    r3, regHDMAEnable2
    mov     r8, #-1
snesHDMA_InitAddrLoop:
    add     r8, r8, #1
    tsts    r3, #0xff
    beq     snesHDMA_Transfer
    movs    r3, r3, lsr #1
    bcc     snesHDMA_InitAddrLoop

    ldr     r0, =regDMASourceL
    ldr     r0, [r0, r8, lsl #2]                @ get the SNES Bank/Address
    Translate                                   @ r0 will store the effective GBA Address
    
    ldr     r1, =regHDMAGBAAddress
    str     r0, [r1, r8, lsl #2]                @ store the starting address of the HDMA table
    
    ldr     r2, =regHDMALineCounter
    mov     r0, #1
    strb    r0, [r2, r8, lsl #2]

    ldr     r1, =regDMADest
    ldrb    r5, [r1, r8]
    add     r5, r5, #0x2100
    ldr     r7, =IOWrite
    add     r5, r7, r5, lsl #2                  @ r4 = decoder address for DMA Dest

    ldr     r4, =snesHDMAIOWrite
    add     r4, r4, r8, lsl #4

    ldr     r7, =HDMA_WriteJump2
    ldr     r6, =regDMAControl
    ldrb    r6, [r6, r8]
    and     r6, r6, #0x7
    ldr     pc, [r7, r6, lsl #2]                @ the routine at HDMA_WriteJump will branch to snesHDMA_InitAddrLoop

HDMA_Read:
snesHDMA_End:
    ldmfd   sp!, { r3-r12, lr }*/
    bx      lr
/*
snesHDMAIOWrite:
    .rept   8*4
    .word
    .endr   
*/
/*
@-------------------------------------------------------------------------
@ Some HDMA macros
@-------------------------------------------------------------------------
.macro hdmaWrite r1, r2, r3, r4, length
    .ifge   \length-1
        ldrb    r1, [r6], #1                @ direct addressing... (indirect address...? later)
        mov     lr, pc
        ldr     pc, [r7, #\r1*4]
    .endif
    .ifge   \length-2
        ldrb    r1, [r6], #1
        mov     lr, pc
        ldr     pc, [r7, #\r2*4]
    .endif
    .ifge   \length-4
        ldrb    r1, [r6], #1
        mov     lr, pc
        ldr     pc, [r7, #\r3*4]

        ldrb    r1, [r6], #1
        mov     lr, pc
        ldr     pc, [r7, #\r4*4]
    .endif
    b       snesHDMA_NextChannel
.endm
*/
/*
HDMA_Write_0:
    hdmaWrite    0, 0, 0, 0, 1

HDMA_Write_1:
    hdmaWrite    0, 1, 0, 1, 2

HDMA_Write_2:
    hdmaWrite    0, 0, 0, 0, 2

HDMA_Write_3:
    hdmaWrite    0, 0, 1, 1, 4

HDMA_Write_4:
    hdmaWrite    0, 1, 2, 3, 4

HDMA_Write_5:
    hdmaWrite    0, 1, 0, 1, 4

HDMA_Write_6:
    hdmaWrite    0, 0, 0, 0, 2

HDMA_Write_7:
    hdmaWrite    0, 0, 1, 1, 4

HDMA_WriteJump:
    .long   HDMA_Write_0, HDMA_Write_1, HDMA_Write_2, HDMA_Write_3
    .long   HDMA_Write_4, HDMA_Write_5, HDMA_Write_6, HDMA_Write_7*/

@-------------------------------------------------------------------------
@ More HDMA macros for initialization
@-------------------------------------------------------------------------
/*
.macro LoadIOWrite r1, r2, r3, r4
    .ifeq (\r1+\r2+\r3+\r4)-0
        ldmia   r5!, {r9}
        stmia   r4!, {r9}
    .endif
    .ifeq (\r1+\r2+\r3+\r4)-2
        ldmia   r5!, {r9, r10}
        stmia   r4!, {r9, r10}
    .endif
    .ifeq (\r1+\r2+\r3+\r4)-6
        ldmia   r5!, {r9-r12}
        stmia   r4!, {r9-r12}
    .endif
    b       snesHDMA_InitAddrLoop
.endm

HDMA_Write_0000:
    LoadIOWrite    0, 0, 0, 0

HDMA_Write_0011:
    LoadIOWrite    0, 0, 1, 1

HDMA_Write_0101:
    LoadIOWrite    0, 1, 0, 1

HDMA_Write_0123:
    LoadIOWrite    0, 1, 2, 3

HDMA_WriteJump2:
    .long   HDMA_Write_0000, HDMA_Write_0101, HDMA_Write_0000, HDMA_Write_0011
    .long   HDMA_Write_0123, HDMA_Write_0101, HDMA_Write_0000, HDMA_Write_0011
*/

@=========================================================================
@ DMA
@=========================================================================
    SetText     "DMA"
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

    .rept   14
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
regDMACycles:   .word   0
regDMAEnable:   .byte   0
regHDMAEnable:  .byte   0
regHDMAEnable2: .byte   0
    .align  4

W420B:
    strb    r1, regDMAEnable
    stmfd   sp!, {r3-r12, lr}
    mov     r2, #0
    str     r2, regDMACycles
    mov     r8, #-1

DMA_NextChannel:
    @ set up the DMA transfer
    @
    ldrb    r1, regDMAEnable
    add     r8, r8, #1
    tsts    r1, #0xff
    beq     DMA_End
    
    movs    r1, r1, lsr #1
    strb    r1, regDMAEnable
    bcc     DMA_NextChannel

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
    add     r2, r2, r4, lsr #4          @ r2 = stores the cycles used for the DMA transfer
    str     r2, regDMACycles

    ldreq   r0, =DMA_WriteJump          @ write
    ldrne   r0, =DMA_ReadJump           @ read
    ldr     pc, [r0, r7, lsl #2]        @ jump to the appropriate DMA transfer mode

DMA_End:
    ldmfd   sp!, {r3-r12, lr}
    
    ldr     r2, regDMACycles
    add     SnesCYCLES, SnesCYCLES, r2
    bx      lr

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
    tsts    r1, #0xff
    /*biceq   SnesIRQ, SnesIRQ, #IRQ_HDMA
    orrne   SnesIRQ, SnesIRQ, #IRQ_HDMA*/
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
    strb    r1, [r2, r0, lsl #1]
    bx      lr

W43x9:
    GetDMAChannel
    ldr     r2, =regHDMAAddressH
    strb    r1, [r2, r0, lsl #1]
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
    ldrb    r1, [r2, r0, lsl #1]
    bx      lr

R43x9:
    GetDMAChannel
    ldr     r2, =regHDMAAddressH
    ldrb    r1, [r2, r0, lsl #1]
    bx      lr

R43xA:
    GetDMAChannel
    ldr     r2, =regHDMALinecounter
    ldrb    r1, [r2, r0]
    bx      lr

    .ltorg

NMIaddress:         .word   0
COPaddress:         .word   0
BRKaddress:         .word   0
IRQaddress:         .word   0

vblankFlag:         .word   0

@=========================================================================
@ keypad stuff
@=========================================================================
    SetText     "KEYPAD--"
keypadRead:         .word   0
regJoyA:	        .hword	0xffff
regJoyB:	        .hword	0xffff
regJoyX:	        .hword	0xffff
regJoyY:	        .hword	0xffff

.equ	snesJoyA, 0x0080
.equ	snesJoyB, 0x8000
.equ	snesJoyX, 0x0040
.equ	snesJoyY, 0x4000

@=========================================================================
@ SNES Rendering the screen at scanline = 0
@=========================================================================

snesRenderScreen:

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
	ldr		r1, =( (1<<3) + (1<<8) + (1<<9) )
	tsts	r0, r1
	bne		renderScreen

    @---------------------------------
    @ branch to the configuration 
	@ screen routine
    @---------------------------------
	stmfd	sp!, {lr}
    mov     lr, pc
    ldr     pc, =configScreen
	ldmfd	sp!, {lr}

renderScreen:

    @---------------------------------
    @ copy v offsets
    @---------------------------------
    ldr     r1, =regBG1VOffsetB
    ldrh    r0, [r1, #2]
    strh    r0, [r1], #4
    ldrh    r0, [r1, #2]
    strh    r0, [r1], #4
    ldrh    r0, [r1, #2]
    strh    r0, [r1], #4
    ldrh    r0, [r1, #2]
    strh    r0, [r1], #4

    @---------------------------------
    @ OAM reset
    @---------------------------------
    ldr     r2, regOAMAddrLo
    bic     r2, r2, #0xfe00
    mov     r2, r2, lsl #1
    str     r2, regOAMAddrInternal

    @---------------------------------
    @ copy all BG's HOffset
    @---------------------------------
    ldr     r0, =0x04000010
    ldr     r1, =regBG1HOffsetWord
    
    ldrh    r2, [r1, #2]
    bic     r2, r2, #0xfe00
    strh    r2, [r0]

    ldrh    r2, [r1, #6]
    bic     r2, r2, #0xfe00
    strh    r2, [r0, #4]

    ldrh    r2, [r1, #10]
    bic     r2, r2, #0xfe00
    strh    r2, [r0, #8]

    ldrh    r2, [r1, #14]
    bic     r2, r2, #0xfe00
    strh    r2, [r0, #12]

    @---------------------------------
    @ copy SNES sprites to GBA
    @ (takes approx 4,000 cycles)
    @---------------------------------
    ldr     r0, oamDirtyBit
    tsts    r0, r0
    beq     vblankSkipSpritesAltogether

    stmfd   sp!, {r3-r12, r14}      
    ldr     r1, =(oamBase-16)
    ldr     r2, =(oamBase+512-1)
    ldr     r12, =(0x07000000-32)
    ldr     r7, =oamX
    ldr     r8, =oamY
    ldr     r9, =oamControl
    mov     r6, #132
    ldrb    r14, regObSel           @ r14 = ggg?????
    mov     r14, r14, lsr #5        @ r3 = 00000ggg

vblankCopySpriteSkip:
    add     r1, r1, #16
    add     r2, r2, #1
    add     r12, r12, #32
    subs    r6, r6, #4
    beq     vblankCopySpriteEnd

vblankCopySpriteLoop:
    @movs    r0, r0, lsr #1
    @bcc     vblankCopySpriteSkip

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
    @---------------------------------
    @ Fading/Color Math
    @---------------------------------
    
    ldrb    r1, regInitDisp
    tsts    r1, #0x80
    movne   r1, #0

    ldr     r2, =0x04000050
    mov     r0, #0xff
    strh    r0, [r2]
    and     r1, r1, #0x0F
    rsb     r1, r1, #0x0F
    strh    r1, [r2, #4]

    cmp     r1, #0x0                    @ is it full brightness?
    bne     vBlankRenderFrame

    stmfd   sp!, {r3-r5}
    ldrb    r1, regColorMath            @ if full brightness, restore any color math
    mov     r3, r1
    ands    r3, r3, #0x3f
    beq     vBlankColorMathNoBlend

    ldrb    r5, regSubScreen

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

vBlankRenderFrame:
    @---------------------------------
    @ Render Frame
    @---------------------------------
    ldrb    r1, regSnesVideoDirty
    tsts    r1, #1
    bxeq    lr
    mov     r1, #0
    strb    r1, regSnesVideoDirty

    ldrb    r0, regBGMode
    and     r0, r0, #0x7
    ldr     r1, =ModeRender
    ldr     pc, [r1, r0, lsl #2]


@=========================================================================
@ Screen/backgrounds
@=========================================================================

    .align  4
    SetText     "INIDSP"
    .align  4
regOAMAddrInternal: .word   0
regInitDisp:        .byte   0
regObSel:           .byte   0
regOAMAddrLo:       .byte   0
regOAMAddrHi:       .byte   0
                    .byte   0
                    .byte   0

regBGMode:          .byte   0
regBGModePrev:      .byte   0
regMOSAIC:          .byte   0

regSnesVideoDirty:  .byte   0
    .align  4

@-------------------------------------------------------------------------
@ 0x2100 - INIDISP
@   x000bbbb
@   x           = on/off
@   bbbb        = brightness
@-------------------------------------------------------------------------
W2100:
    strb    r1, regInitDisp
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
    ldrb    r2, regObSel
    cmp     r2, r1
    bxeq    lr

    strb    r1, regObSel
    mov     r0, #1
    strb    r0, regSnesVideoDirty

    bx      lr

@-------------------------------------------------------------------------
@ 0x2102 - OAMADDL
@   aaaaaaaa    = low-address
@-------------------------------------------------------------------------
W2102:
    strb    r1,regOAMAddrLo
    
    @ sets the internal OAM address
    ldrh    r2, regOAMAddrLo
    bic     r2, r2, #0xfe00
    mov     r2, r2, lsl #1
    strh    r2, regOAMAddrInternal
    bx      lr

@-------------------------------------------------------------------------
@ 0x2103 - OAMADDH
@   p------b    
@   p           = priority rotation bit
@   b           = high address
@-------------------------------------------------------------------------
W2103:
    strb    r1,regOAMAddrHi

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
    ldrb    r2, regBGMode
    cmp     r2, r1
    bxeq    lr

    strb    r1, regBGMode
    mov     r0, #1
    strb    r0, regSnesVideoDirty
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

    .align  4

    .equ        SCANLINE_BLANK,         225
    .equ        SCANLINE_BLANK_OSCAN,   241

regBG1VOffsetB:     .hword  0
regBG1VOffset:      .hword  0
regBG2VOffsetB:     .hword  0
regBG2VOffset:      .hword  0
regBG3VOffsetB:     .hword  0
regBG3VOffset:      .hword  0
regBG4VOffsetB:     .hword  0
regBG4VOffset:      .hword  0

regBG1HOffsetWord:  .hword  0
regBG1HOffset:      .hword  0
regBG2HOffsetWord:  .hword  0
regBG2HOffset:      .hword  0
regBG3HOffsetWord:  .hword  0
regBG3HOffset:      .hword  0
regBG4HOffsetWord:  .hword  0
regBG4HOffset:      .hword  0

regBG1SC:           .byte   0
regBG2SC:           .byte   0
regBG3SC:           .byte   0
regBG4SC:           .byte   0
regBG1NBA:          .byte   0
regBG2NBA:          .byte   0
regBG3NBA:          .byte   0
regBG4NBA:          .byte   0
    
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
    .align  4
W2107:
    ldrb    r2, regBG1SC
    cmp     r2, r1
    bxeq    lr

    strb    r1, regBG1SC
    mov     r0, #1
    strb    r0, regSnesVideoDirty
    bx      lr

W2108:
    ldrb    r2, regBG2SC
    cmp     r2, r1
    bxeq    lr

    strb    r1, regBG2SC
    mov     r0, #1
    strb    r0, regSnesVideoDirty
    bx      lr

W2109:
    ldrb    r2, regBG3SC
    cmp     r2, r1
    bxeq    lr

    strb    r1, regBG3SC
    mov     r0, #1
    strb    r0, regSnesVideoDirty
    bx      lr

W210A:
    ldrb    r2, regBG4SC
    cmp     r2, r1
    bxeq    lr

    strb    r1, regBG4SC
    mov     r0, #1
    strb    r0, regSnesVideoDirty
    bx      lr

@-------------------------------------------------------------------------
@ 0x210B - BG1/2NBA - BG1 and 2 Chr Address
@ 0x210C - BG3/4NBA - BG3 and 4 Chr Address
@   bbbbaaaa
@   aaaa = Base address for BG1/3 (Addr>>13)
@   bbbb = Base address for BG2/4 (Addr>>13)
@-------------------------------------------------------------------------
prevW210B:  .byte   0
prevW210C:  .byte   0
    .align  4

W210B:
    ldrb    r0, prevW210B
    cmp     r0, r1
    bxeq    lr

    and     r0, r1, #0x7
    strb    r0, regBG1NBA

    mov     r0, r1, lsr #4
    and     r0, r0, #0x7
    strb    r0, regBG2NBA

    strb    r1, prevW210B
    
    mov     r0, #1
    strb    r0, regSnesVideoDirty
    bx      lr

W210C:
    ldrb    r0, prevW210C
    cmp     r0, r1
    bxeq    lr

    and     r0, r1, #0x7
    strb    r0, regBG3NBA

    mov     r0, r1, lsr #4
    and     r0, r0, #0x7
    strb    r0, regBG4NBA
    
    strb    r1, prevW210C
    
    mov     r0, #1
    strb    r0, regSnesVideoDirty
    bx      lr


@-------------------------------------------------------------------------
@ Generic macro to set BG HOFS/VOFS
@   r0: offset from regBG1HOffset
@-------------------------------------------------------------------------
WriteBGOFS:
    ldrh    r2, [r0, #2]
    mov     r2, r2, lsr #8
    orr     r2, r2, r1, lsl #8
    strh    r2, [r0, #2]
    bx      lr

.macro  SetBGVOFS    ofs
    ldr     r0, =(regBG1VOffsetB+\ofs*4)
    b       WriteBGOFS
.endm

.macro  SetBGHOFS    ofs
    ldr     r0, =(regBG1HOffsetWord+\ofs*4)
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
    str     r0, vBlankScan

    bx      lr


@=========================================================================
@ VRAM
@=========================================================================
@-------------------------------------------------------------------------
@ IO registers
@-------------------------------------------------------------------------
    .align 4
regVideoMain:       .byte   0
    .align 4

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
    ldr     r0, W2115_AddrXlateNop
    ldr     r2, =\label
    str     r0, [r2]
    str     r0, [r2, #4]
    str     r0, [r2, #8]
.endm

.macro  ModifyAddrXlate label
    ldr     r2, =\label
    ldr     r0, W2115_AddrXlateNop
    ldr     r0, [r0, r1, lsl #4]
    str     r0, [r2]

    ldr     r0, W2115_AddrXlateNop+4
    ldr     r0, [r0, r1, lsl #4]
    str     r0, [r2, #4]

    ldr     r0, W2115_AddrXlateNop+8
    ldr     r0, [r0, r1, lsl #4]
    str     r0, [r2, #8]
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
    @str     r2, W2139_Inc
    
    ldr     r0, =W2115_Inc
    ldrne   r0, [r0]
    ldreq   r0, [r0, #4]
    str     r0, W2119_Inc
    @str     r2, W213a_Inc

    @ take care of the increment counter
    @
    ldr     r0, =W2115_IncCount
    and     r2, r1, #0x03               @ r2 = 000000ii
    ldr     r0, [r0, r2, lsl #2]
    ldr     r2, =W2118_IncCount
    str     r0, [r2]
    ldr     r2, =W2119_IncCount
    str     r0, [r2]
    @ldr     r2, =W2139_IncCount
    str     r0, [r2]
    @ldr     r2, =W213a_IncCount
    str     r0, [r2]

    @ take care of the address translation
    @
    mov     r1, r1, lsr #2              @ r1 = 00i---mm
    ands    r1, r1, #0x03               @ r1 = 000000mm
/*    bne     w2115_ModifyAddrXlate
    
    ModifyAddrXlateNop  W2118_AddrXlate
    ModifyAddrXlateNop  W2119_AddrXlate*/
    bx      lr

w2115_ModifyAddrXlate:
/*    ModifyAddrXlate     W2118_AddrXlate
    ModifyAddrXlate     W2119_AddrXlate*/
    bx      lr

W2115_Inc:
    mov     r0, r0
    bx      lr

W2115_IncCount:
    add     r2, r2, #1
    add     r2, r2, #32
    add     r2, r2, #128
    add     r2, r2, #128

W2115_AddrXlateNop:
    mov     r0, r0

W2115_AddrXlateOp:
    add     r2, r2, #(1<<17)        @ (self modifying code) (or, mov r0, r0, or mov r2, r2, #(mm<<17))
    add     r2, r2, r0, lsl #1      @ (self modifying code) (or, mov r0, r0) 
    ldrh    r0, [r2]                @ (self modifying code) (or, mov r0, r0) 
    mov     r0, r0
    add     r2, r2, #(2<<17)        @ (self modifying code) (or, mov r0, r0, or mov r2, r2, #(mm<<17))
    add     r2, r2, r0, lsl #1      @ (self modifying code) (or, mov r0, r0) 
    ldrh    r0, [r2]                @ (self modifying code) (or, mov r0, r0) 
    mov     r0, r0
    add     r2, r2, #(3<<17)        @ (self modifying code) (or, mov r0, r0, or mov r2, r2, #(mm<<17))
    add     r2, r2, r0, lsl #1      @ (self modifying code) (or, mov r0, r0) 
    ldrh    r0, [r2]                @ (self modifying code) (or, mov r0, r0) 
    mov     r0, r0

@-------------------------------------------------------------------------
@ IO registers
@-------------------------------------------------------------------------
    .align 4
regVRAMAddrLo:      .byte   0
regVRAMAddrHi:      .byte   0
    .align 4

@-------------------------------------------------------------------------
@ 0x2116  VMADDL - VRAM Address low byte
@-------------------------------------------------------------------------
W2116:
    strb    r1, regVRAMAddrLo
    bx      lr

@-------------------------------------------------------------------------
@ 0x2116  VMADDH - VRAM Address high byte
@-------------------------------------------------------------------------
W2117:
    strb    r1, regVRAMAddrHi
    bx      lr

/*RecomputeVRAMAddr:
    ldrh    r1, regVRAMAddrLo
    bx      lr*/

@-------------------------------------------------------------------------
@ 0x2118  VMDATAL - VRAM Data Write low byte
@-------------------------------------------------------------------------
W2118:
    ldrh    r0, regVRAMAddrLo
    bic     r0, r0, #0x8000
/*    ldr     r2, =vramTranslation
W2118_AddrXlate:
    add     r2, r2, #(1<<17)        @ (self modifying code) (or, mov r0, r0, or mov r2, r2, #(mm<<17))
    add     r2, r2, r0, lsl #1      @ (self modifying code) (or, mov r0, r0) 
    ldrh    r0, [r2]                @ (self modifying code) (or, mov r0, r0) */
    ldr     r2, =0x02020000         @ VRAM base (low byte)
    strb    r1, [r2, r0, lsl #1]
W2118_Inc:
    bx      lr                      @ (self modifying code) (or mov r0, r0)
    ldrh    r2, regVRAMAddrLo       
W2118_IncCount:
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

@-------------------------------------------------------------------------
@ 0x2119  VMDATAH - VRAM Data Write high byte
@-------------------------------------------------------------------------
W2119:
    ldrh    r0, regVRAMAddrLo
    bic     r0, r0, #0x8000
/*    ldr     r2, =vramTranslation       
W2119_AddrXlate:
    add     r2, r2, #(1<<17)        @ (self modifying code) (or, mov r0, r0, or mov r2, r2, #(mm<<17))
    add     r2, r2, r0, lsl #1      @ (self modifying code) (or, mov r0, r0) 
    ldrh    r0, [r2]                @ (self modifying code) (or, mov r0, r0) */
    ldr     r2, =0x02020001         @ VRAM base (high byte)
    strb    r1, [r2, r0, lsl #1]
W2119_Inc:
    bx      lr                      @ (self modifying code) (or mov r0, r0)
    ldrh    r2, regVRAMAddrLo       
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


@=========================================================================
@ Special VRAM functions
@=========================================================================

    SetText     "VRAMJUMP"

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
    .align  4
regM7A:         .hword   0
regM7B:         .hword   0
regM7C:         .hword   0
regM7D:         .hword   0
regM7X:         .hword   0
regM7Y:         .hword   0
regMulResult:   .long   0
    .align  4

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
    .align  4
regCGRAMAddr:   .word   0
regCGRAMLatch:  .word   0
    .align  4
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
    
    tsts    r2, #0x0100
    add     r1, r2, #0x05000000     @ write BG (16-color) palette
    streqh  r0, [r1]
    add     r1, r1, #0x0200         @ write OBJ palette
    strh    r0, [r1]

    cmp     r2, #64                 @ is palette index >= 64?
    bxge    lr                      @ return if so, otherwise...

    and     r1, r2, #0xF8           @ r1 = 00000000 000cc000
    and     r2, r2, #0x06           @ r2 = 00000000 00000cc0
    add     r2, r2, r1, lsl #2      @ r2 = 00000000 0cc00cc0
    add     r2, r2, #0x05000000
    add     r2, r2, #0x00000100
    strleh  r0, [r2]                @ ...write BG (4-color) palette

    bx      lr

    .ltorg

@=========================================================================
@ Main/sub screen and color math
@=========================================================================
    .align  4
regMainScreen:  .byte   0
regSubScreen:   .byte   0
regColorMath:   .byte   0
regBreak:   .byte   0
    .align  4

W212C:
    ldrb    r0, regMainScreen
    cmp     r0, r1
    bxeq    lr

    strb    r1, regMainScreen
    mov     r0, #1
    strb    r0, regSnesVideoDirty
    bx      lr

W212D:
    ldrb    r0, regSubScreen
    cmp     r0, r1
    bxeq    lr
    strb    r1, regSubScreen
    
    mov     r0, #1
    strb    r0, regSnesVideoDirty
    bx      lr

W2130:
    bx      lr

W2131:
    strb    r1, regColorMath
    bx      lr


@=========================================================================
@ H/V Counters
@=========================================================================
    .align  4
regHCounter:    .word   0
regVCounter:    .word   0
    .align  4
    
@-------------------------------------------------------------------------
@ 0x2137 - SLHV - Software Latch for H/V Counter
@-------------------------------------------------------------------------
R2137:
    @mov     r0, SnesHC, lsr #16
    strh    r0, regHCounter
    @mov     r0, SnesVC, lsr #16
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
	/*ldr     r0, regVCounter
    bic     r0, r0, #0x80000000
	str     r0, regVCounter
	ldr     r0, regHCounter
    bic     r0, r0, #0x80000000
	str     r0, regHCounter*/
	
    @ldr    r0,=romflags1
	@ldr    r0,[r0]
	@tst    r0,#2			;PAL game?
	@mov    r1,#0x01		;Version
	@orrne  r1,r1,#0x10	    ;PAL bit
    mov     r1, #0
    bx      lr

@=========================================================================
@ APU (SPC-700 registers)
@=========================================================================

    .align  4
regAPU0:            .byte   0
regAPU1:            .byte   0
regAPUReadCount:    .byte   0
                    .byte   0
regAPUCounter:      .hword  0
                    .hword  0
spcReadTable:       .word   spcRead0, spcRead1, spcRead2, spcRead3, spcRead4, spcRead5, spcRead6

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
	movmi   r2, #6
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
    mov     r1, #0xbb                   @ high byte
	bx      lr

spcRead2:
    mov     r1, #0xaa                   @ low byte
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
    strb    r1, regAPU0
    bx      lr

W2141:
W2143:
    strb    r1, regAPU1
    bx      lr

@=========================================================================
@ WRAM
@=========================================================================

    .align  4
regWRAMAddr:    .long   0
    .align  4

@-------------------------------------------------------------------------
@ 0x2180
@-------------------------------------------------------------------------
W2180:
    ldr     r0, regWRAMAddr
    strb    r1, [r0], #1
    bic     r0, r0, #0x20000
    str     r0, regWRAMAddr
    bx      lr

R2180:
    ldr     r0, regWRAMAddr
    ldrb    r1, [r0], #1
    bic     r0, r0, #0x20000
    str     r0, regWRAMAddr
    bx      lr

@-------------------------------------------------------------------------
@ 0x2181  WMADDL - WRAM Address low byte
@-------------------------------------------------------------------------
W2181:
    strb    r1, regWRAMAddr
    bx      lr

@-------------------------------------------------------------------------
@ 0x2182  WMADDM - WRAM Address middle byte
@-------------------------------------------------------------------------
W2182:
    strb    r1, regWRAMAddr+1
    bx      lr


@-------------------------------------------------------------------------
@ 0x2183  WMADDH - WRAM Address high byte
@-------------------------------------------------------------------------
W2183:
    strb    r1, regWRAMAddr+2
    bx      lr


@=========================================================================
@ Joypad 
@=========================================================================

    .align  4
regJoyState:    .word   0
regJoyLatch:    .word   0

    .align  4

@-------------------------------------------------------------------------
@ 0x4016 rwb++++ JOYSER0 - NES-style Joypad Access Port 1
@   Rd: ------ca
@   Wr: -------l
@-------------------------------------------------------------------------
W4016:
    @ latch the joypad state
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
    and     r0, r0, #1
    strh    r0, regJoyLatch
    bx      lr

@-------------------------------------------------------------------------
@ 0x4218 JOY1L - Controller Port 1 Data1 Register low byte
@-------------------------------------------------------------------------
R4218:
R421C:
    ldr     r0, =keypadRead
    ldrb    r1, [r0]
    bx      lr

@-------------------------------------------------------------------------
@ 0x4219 JOY1H - Controller Port 1 Data1 Register high byte
@-------------------------------------------------------------------------
R4219:
R421D:
    ldr     r0, =keypadRead+1
    ldrb    r1, [r0]
	bx      lr


    .ltorg

@=========================================================================
@ Mul/Divide registers
@=========================================================================

    .align  4
regMulA:        .byte   0
regDivisor:     .byte   0
    .align  4
regMulResult2:  .word   0
regDividend:    .word   0
regDivResult:   .word   0
    .align  4
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
@ Renderer
@=========================================================================
    SetText     "RENDER"

@-------------------------------------------------------------------------
@ Renderer variables
@-------------------------------------------------------------------------
renderMode1BG1Priority:     .byte   0x01        @ (either 0xff=auto, 0x00, 0x01, 0x02, 0x03)
renderMode1BG2Priority:     .byte   0x02        @ (either 0xff=auto, 0x00, 0x01, 0x02, 0x03)
renderMode1BG3Priority:     .byte   0x00        @ (either 0xff=auto, 0x00, 0x01, 0x02, 0x03)
.byte 0

bgCurTileOffset:  .word   0x00000000

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

/*
.macro  StartRenderer
    stmfd   sp!, {r3-r9, lr}
.endm

.macro  EndRenderer
    ldmfd   sp!, {r3-r9, lr}
    bx      lr
.endm

@-------------------------------------------------------------------------
@ Enable backgrounds according to flags
@-------------------------------------------------------------------------
EnableBG:
    ldr     r2, =0x04000000 
    ldrh    r0, [r2]
    ldrb    r1, regMainScreen
    ldrb    r3, regSubScreen
    orr     r1, r1, r3

    bic     r0, r0, #0x1f
    and     r1, r1, #0x1f
    orr     r0, r0, r1, lsl #8
    bic     r0, r0, #(1<<11)            @ don't enable BG3
    strh    r0, [r2]
    ldr     r4, =0x06010000
    str     r4, bgCurTileOffset
    
    bx      lr

@-------------------------------------------------------------------------
@ Copy BG CHAR 
@   r7 = number of colors for bg3, bg2, bg1, bg0
@        (0 = no background, 1 = 4 color, 2 = 16 color, 3 = 256 color)
@ destroys r3-r8
@-------------------------------------------------------------------------

RenderCopyBGChar2:
    @ set up the VRAM BG and BG color table 
    mov     r8, #32
    mov     r2, #0xff
    mov     r3, #0xff
    ldr     r4, =VRAMBG
    ldr     r5, =VRAMBGColors
    
RenderCopyBGChar2_Loop:
    ldrb    r6, [r4]
    cmp     r6, #0xff
    movne   r2, r6
    ldrneb  r3, [r5]
    strb    r2, [r4], #1
    strb    r3, [r5], #1
    subs    r8, r8, #1
    bne     RenderCopyBGChar2_Loop
    
    @ SNES character address
    mov     r0, #0

RenderCopyBGChar2_Loop2:
    ldrb    r1, regMainScreen
    ldrb    r2, regSubScreen
    orr     r1, r2, r1
    mov     r2, #1
    tsts    r1, r2, lsl r0
    beq     RenderCopyBGChar2_SkipLoop      @ skip if background is not activated in main/sub screen

    ldr     r1, =regBG1NBA
    ldrb    r1, [r1, r0]
    and     r1, r1, #0x07                   @ r6 = 00000aaa
    mov     r6, r1                          @ r6 = 00000aaa
    mov     r1, r1, lsl #13
    add     r1, r1, #0x02000000             
    add     r1, r1, #0x00020000

    and     r5, r7, #0xff
    ldr     r2, =RenderCopyCharUnpackTable
    ldr     r2, [r2, r5, lsl #2]

    ldr     r3, =bg1VRAMOffset
    ldr     r3, [r3, r0, lsl #2]
    add     r3, r3, r6, lsl #13

    stmfd   sp!, {r0, lr}
    ldr     r4, =RenderCopyBGCopyCharTable
    mov     lr, pc
    ldr     pc, [r4, r5, lsl #2]
    ldmfd   sp!, {r0, lr}

RenderCopyBGChar2_SkipLoop:
    add     r0, r0, #1
    cmp     r0, #4
    mov     r7, r7, lsr #8
    bne     RenderCopyBGChar2_Loop2
    bx      lr


.macro CopyBGCharEx  bg1Colors, bg2Colors, bg3Colors, bg4Colors
    ldr     r7, =((\bg4Colors)*256*256*256 + (\bg3Colors)*256*256 + (\bg2Colors)*256 + (\bg1Colors))
    bl      RenderCopyBGChar2
.endm


@-------------------------------------------------------------------------
@ Copy BG TileMap
@   r0: bgNumber
@-------------------------------------------------------------------------
RenderCopyBGTileMap:
    strb    r0, ScreenMode
    ldrb    r1, regMainScreen
    ldrb    r2, regSubScreen
    orr     r1, r2, r1
    mov     r2, #1
    tsts    r1, r2, lsl r0
    bxeq    lr                              @ skip if background is not activated in main/sub screen
    
    cmp     r0, #2                          @ if this is BG3, 
    moveq   r9, #0x8000                     @ add to the tile map palette
    movne   r9, #0x0000

    stmfd   sp!, {lr}
    ldr     r1, =regBG1SC
    ldrb    r1, [r1, r0]                    @ r1 = 00000000 ttttttyx
    and     r1, r1, #0x7f                   @ r1 = 00000000 0tttttyx
    mov     r0, r1, lsr #2                  @ r0 = 00000000 000ttttt
    and     r7, r1, #0x03                   @ r7 = 00000000 000000yx

    ldr     r5, =VRAMWrite
    add     r5, r5, r0, lsl #2

    mov     r0, r0, lsl #11                 @ r0 = ttttt000 00000000
    mov     r6, r0

    ldrb    r1, ScreenMode
    ldr     r4, =VRAMWriteTileMap
    str     r4, [r5], #4
    bl      CopyTileMap
    tsts    r7, #0x03
    beq     CopyBGTileMap_End

    ldrb    r1, ScreenMode
    add     r0, r6, #0x800
    ldr     r4, =VRAMWriteTileMap
    str     r4, [r5], #4
    bl      CopyTileMap
    cmp     r7, #0x03
    bne     CopyBGTileMap_End

    ldrb    r1, ScreenMode
    add     r0, r6, #0x1000
    ldr     r4, =VRAMWriteTileMap
    str     r4, [r5], #4
    bl      CopyTileMap

    ldrb    r1, ScreenMode
    add     r0, r6, #0x1800
    ldr     r4, =VRAMWriteTileMap
    str     r4, [r5], #4
    bl      CopyTileMap

CopyBGTileMap_End:
    ldmfd   sp!, {lr}
    bx      lr

.macro  CopyBGTileMap   bgNumber
    mov     r0, #\bgNumber
    bl      RenderCopyBGTileMap
.endm

    SetText "OBJCHAR"
@-------------------------------------------------------------------------
@ Copy OBJ char
@   r8: nameAddress (0, 1)
@-------------------------------------------------------------------------
RenderCopyOBJChar:
    ldrb    r0, regObSel
    mov     r1, r0
    and     r0, r0, #0x07           @ r0 = -----aaa
    mov     r0, r0, lsl #3          @ r0 = --aaa000
    
    tsts    r8, #1
    andne   r5, r1, #0x18           @ r5 = ---nn---
    addne   r5, r5, #0x08           @ r5+= 00001000
    addne   r0, r0, r5, lsr #1      @ r0 = --aa*n00
    and     r0, r0, #0x1f           @ r0 = --0a*n00

    ldr     r1, =VRAMObjWrite
    add     r1, r1, r0, lsl #2
    
    tsts    r8, #1
    ldrne   r6, =VRAMWriteObj1Char_16color
    ldreq   r6, =VRAMWriteObj0Char_16color

    str     r6, [r1], #4
    str     r6, [r1], #4
    str     r6, [r1], #4
    str     r6, [r1], #4

    ldr     r2, =charUnpack4
    ldr     r1, =0x02020000
    add     r1, r1, r0, lsl #11
    
    ldr     r3, =0x06010000
    tsts    r8, #1
    addne   r3, r3, #0x00004000

    sub     r4, r3, r0, lsl #11
    streq   r4, VRAMObj0Offset
    strne   r4, VRAMObj1Offset

    stmfd   sp!, {lr}
    bl      CopyObjChar_16color
    ldmfd   sp!, {lr}
    bx      lr

.macro  CopyOBJChar nameAddress
    mov     r8, #\nameAddress
    bl      RenderCopyOBJChar
.endm

.macro  CopyOBJCharEx nameAddress
    mov     r8, #\nameAddress
    bl      RenderCopyOBJChar
.endm

    .ltorg

@-------------------------------------------------------------------------
@ Copy BG control bits and allocate GBA VRAM for snes background
@   r0 = bgNumber (0-3)
@   r2 = priority (0-3)
@   r6 = numColors (0=na, 1=4, 2=16, 3=256)
@ destroys r3-r8
@-------------------------------------------------------------------------
RenderCopyBGCNT:
    strb    r6, NumColors
    ldrb    r1, regMainScreen
    ldrb    r2, regSubScreen
    orr     r1, r2, r1
    mov     r2, #1
    tsts    r1, r2, lsl r0
    bxeq    lr                              @ skip if background is not activated in main/sub screen

    ldr     r3, =renderMode1BG1Priority     @ override the default SNES priority
    ldrb    r3, [r3, r0]
    cmp     r3, #0xff
    movne   r2, r3                          @ r2 = 00000000 000000pp

    cmp     r6, #COLOR_256                  
    orreq   r2, r2, #(1 << 7)
    orrne   r2, r2, #(0 << 7)               @ r2 = 00000000 c00000pp

    ldr     r1, =regBG1NBA
    ldrb    r1, [r1, r0]                    @ r1 = 0000aaaa
    and     r1, r1, #0x07
    mov     r7, r1                          @ r1, r7 = 00000aaa (stores the SNES VRAM 8k-block)

    @ set up the VRAM write table for the BG char
    @
    ldr     r4, =VRAMBGColors
    strb    r6, [r4, r7, lsl #2]
    ldr     r4, =VRAMBG
    strb    r0, [r4, r7, lsl #2]
    ldr     r4, =VRAMWrite
    mov     r7, r7, lsl #2
    mov     r8, #16
1:  ldr     r6, [r4, r7, lsl #2]
    ldr     r5, =VRAMWriteNOP
    cmp     r6, r5
    ldr     r5, =VRAMWriteBGChar
    streq   r5, [r4, r7, lsl #2]
    add     r7, r7, #1
    cmp     r7, #32
    bge     2f
    subs    r8, r8, #1
    bne     1b
2:  

    @ determine the 16-k blocks in GBA VRAM for the character maps.
    @
    mov     r7, r1
    ldrb    r5, regBG1NBA
    ldrb    r6, regBG2NBA
    cmp     r0, #1                          @ are we doing BG1?
    moveq   r1, #0                          @ if so, use block #0, temporarily.
    cmp     r5, r6                          @ but is NBA for BG1 != BG2?
    movne   r1, #1                          @ if so, use block #1 instead
    cmp     r0, #0                          @ are we doing BG1?
    moveq   r1, #0                          @ if so, use block #0
    cmp     r0, #2                          @ are we doing BG3?
    moveq   r1, #2                          @ if so, use block #2
    mov     r5, #0x06000000
    add     r5, r5, r1, lsl #14             @ r5 = 0x0600?000 (GBA VRAM address for the characters)
    sub     r5, r5, r7, lsl #13
    orr     r2, r2, r1, lsl #2              @ r2 = 00000000 c000AApp
    ldr     r3, =bg1VRAMOffset
    str     r5, [r3, r0, lsl #2]
    cmp     r0, #2                          @ are we doing BG3?
    moveq   r7, r7, lsl #13
    streq   r7, bg3Base

    @ mosaic
    @
    mov     r1, #1
    mov     r4, r1, lsl r0
    ldr     r1, =regMOSAIC
    ldrb    r1, [r1]
    tsts    r1, r4
    orrne   r2, r2, #(1 << 6)               @ r2 = 00000000 cm00AApp

    @ SNES tilemap address
    ldr     r3, =regBG1SC                   @ load tilemap address
    ldrb    r3, [r3, r0]                    @ r3 = 00000000 ttttttyx
    orr     r2, r2, r3, lsl #14             @ r2 = yx000000 cm00AApp

    @ allocate tile map in GBA VRAM
    @ (allocates from the bottom of the VRAM segment to minimize
    @ chance of overwriting)
    @
    and     r5, r3, #0x03                   @ r5 = 00000000 000000yx
    ldr     r4, bgCurTileOffset
    cmp     r5, #0
    moveq   r8, #1
    cmp     r5, #1
    moveq   r8, #2
    cmp     r5, #2
    moveq   r8, #2
    cmp     r5, #3
    moveq   r8, #4
    sub     r4, r4, r8, lsl #11             @ r4 = 0x0600??00
    str     r4, bgCurTileOffset
    and     r6, r4, #0xF800                 @ r6 = 0x0000??00
    orr     r2, r2, r6, lsr #3              @ r2 = yx0ttttt cm00AApp

    @ set up the VRAMWrite table for tile map
    @
    ldr     r6, =VRAMWrite
    ldr     r5, =VRAMWriteTileMap
    and     r3, r3, #0x7c                   @ r3 = 00000000 0ttttt00
    add     r6, r6, r3
1:  str     r5, [r6], #4
    subs    r8, r8, #1
    bne     1b
    sub     r4, r4, r3, lsl #9
    ldr     r5, =bg1TileOffset
    str     r4, [r5, r0, lsl #2]
    ldr     r4, =VRAMBG
    strb    r0, [r4, r3, lsr #2]
    ldr     r4, =VRAMBGColors
    ldrb    r5, NumColors
    strb    r5, [r4, r3, lsr #2]

    ldr     r3, =(0x4000008)                @ gba BGxCNT address
    add     r3, r3, r0, lsl #1
    strh    r2, [r3]
    bx      lr    

.macro CopyBGCNT  bgNumber, numColors, priority
    mov     r0, #\bgNumber
    mov     r2, #\priority
    mov     r6, #\numColors
    bl      RenderCopyBGCNT
.endm

@-------------------------------------------------------------------------
@ Mode 0
@-------------------------------------------------------------------------
RenderMode0:
    StartRenderer
    EndRenderer

@-------------------------------------------------------------------------
@ Mode 1
@-------------------------------------------------------------------------
RenderMode1:
    StartRenderer

    bl              EnableBG

    CopyBGCNT       0, COLOR_16, 1
    CopyBGCNT       1, COLOR_16, 1
    CopyBGCNT       2, COLOR_4, 1
    CopyBGCharEx    COLOR_16, COLOR_16, COLOR_4, COLOR_NONE
    CopyOBJChar     1
    CopyOBJChar     0

    CopyBGTileMap   0
    CopyBGTileMap   1
    CopyBGTileMap   2

    EndRenderer

@-------------------------------------------------------------------------
@ Mode 2
@-------------------------------------------------------------------------
RenderMode2:
    StartRenderer
    EndRenderer

@-------------------------------------------------------------------------
@ Mode 3
@-------------------------------------------------------------------------
RenderMode3:
    StartRenderer
    EndRenderer

@-------------------------------------------------------------------------
@ Mode 4
@-------------------------------------------------------------------------
RenderMode4:
    StartRenderer
    EndRenderer

@-------------------------------------------------------------------------
@ Mode 5
@-------------------------------------------------------------------------
RenderMode5:
    StartRenderer
    EndRenderer

@-------------------------------------------------------------------------
@ Mode 6
@-------------------------------------------------------------------------
RenderMode6:
    StartRenderer
    EndRenderer

@-------------------------------------------------------------------------
@ Mode 7
@-------------------------------------------------------------------------
RenderMode7:
    StartRenderer
    EndRenderer

    .ltorg
*/
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

    ldr     r2, =tileMap

    ldr     r1, =0x02020000
    add     r1, r1, r0

    mov     r8, #1024
copyTileMapLoop:
    ldrh    r4, [r1], #2                @ 3 
    ldrb    r0, [r2, r4, lsr #8]        @ 1
    bic     r4, r4, #0xff00             @ 1
    orr     r4, r4, r0, lsl #8          @ 1
    orr     r4, r4, r9
    strh    r4, [r3], #2                @ 3
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

.macro  CopyChar_1row_256color row, numColors
    mov     r5, #0
    mov     r6, #0
    CopyChar_1row_256plane      0, 0+(\row*2) 
    CopyChar_1row_256plane      1, 1+(\row*2)
    CopyChar_1row_256plane      2, 16+(\row*2)
    CopyChar_1row_256plane      3, 17+(\row*2)
    CopyChar_1row_256plane      4, 32+(\row*2)
    CopyChar_1row_256plane      5, 33+(\row*2)
    CopyChar_1row_256plane      6, 48+(\row*2)
    CopyChar_1row_256plane      7, 49+(\row*2)
    str     r5, [r3, #(\row*8)]                     @ write to GBA VRAM
    str     r6, [r3, #(\row*8+4)]                   @ write to GBA VRAM
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

.macro  CopyChar_1row_16color row, numColors
    mov     r5, #0
    CopyChar_1row_16plane       0, 0+(\row*2)       @ for 4, 16 colors
    CopyChar_1row_16plane       1, 1+(\row*2)
    .ifeq   \numColors-16
        CopyChar_1row_16plane   2, 16+(\row*2)      @ only for 16 colors
        CopyChar_1row_16plane   3, 17+(\row*2)
    .endif
    str     r5, [r3, #(\row*4)]                     @ write to GBA VRAM
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
    CopyChar_1row_256color 0, 16   
    CopyChar_1row_256color 1, 16 
    CopyChar_1row_256color 2, 16
    CopyChar_1row_256color 3, 16
    CopyChar_1row_256color 4, 16
    CopyChar_1row_256color 5, 16
    CopyChar_1row_256color 6, 16
    CopyChar_1row_256color 7, 16
    add     r1, r1, #32
    add     r3, r3, #32
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
    CopyChar_1row_16color 0, 16   
    CopyChar_1row_16color 1, 16 
    CopyChar_1row_16color 2, 16
    CopyChar_1row_16color 3, 16
    CopyChar_1row_16color 4, 16
    CopyChar_1row_16color 5, 16
    CopyChar_1row_16color 6, 16
    CopyChar_1row_16color 7, 16
    add     r1, r1, #32
    add     r3, r3, #32
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
    CopyChar_1row_16color 0, 4   
    CopyChar_1row_16color 1, 4 
    CopyChar_1row_16color 2, 4
    CopyChar_1row_16color 3, 4
    CopyChar_1row_16color 4, 4
    CopyChar_1row_16color 5, 4
    CopyChar_1row_16color 6, 4
    CopyChar_1row_16color 7, 4
    add     r1, r1, #16
    add     r3, r3, #32
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
    CopyChar_1row_16color 0, 16
    CopyChar_1row_16color 1, 16 
    CopyChar_1row_16color 2, 16
    CopyChar_1row_16color 3, 16
    CopyChar_1row_16color 4, 16
    CopyChar_1row_16color 5, 16
    CopyChar_1row_16color 6, 16
    CopyChar_1row_16color 7, 16
    add     r1, r1, #32
    add     r3, r3, #32
    subs    r8, r8, #1
    bne     CopyObjChar_16Loop
    mov     pc, lr



@=========================================================================
@ VRAM write-through functions
@   r0: stores the VRAM offset 
@       from SNES VRAM base (0x02020000)
@=========================================================================

    SetText "VRAMNOP"
@-------------------------------------------------------------------------
@ Do nothing
@-------------------------------------------------------------------------
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
    moveq   r5, #0x8000
    movne   r5, #0x0000

    ldr     r3, =bg1TileOffset
    ldr     r3, [r3, r2, lsl #2]
    add     r3, r3, r0
    
    ldr     r2, =tileMap

    ldr     r1, =0x02020000
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

    stmfd   sp!, {r4-r8, lr}
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

    ldr     r1, =0x02020000
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
    
    ldr     r4, =bgCurTileOffset
    cmp     r3, r4
    bge     VRAMWriteBGCharEnd

VRAMWriteBGCharFinal:
    mov     r8, #1
    mov     lr, pc
    bx      r7
    
VRAMWriteBGCharEnd:  
    ldmfd   sp!, {r4-r8, lr}
    ldmfd   sp!, {r3}
    bx      lr




@-------------------------------------------------------------------------
@ VRAM Write OBJ 16 color CHR
@-------------------------------------------------------------------------
VRAMWriteObj1Char_16color:
    and     r1, r0, #0x1e
    cmp     r1, #0x1e
    bxne    lr

    stmfd   sp!, {r3-r8, lr}
    ldr     r3, VRAMObj1Offset
    b       VRAMWriteObj

VRAMWriteObj0Char_16color:
    and     r1, r0, #0x1e
    cmp     r1, #0x1e
    bxne    lr

    stmfd   sp!, {r3-r8, lr}
    ldr     r3, VRAMObj0Offset

VRAMWriteObj:
    ldr     r2, =charUnpack4
    ldr     r1, =0x02020000
    bic     r0, r0, #0x1f           @ r0 = 00000000 00000000 aaaaaaaa aaa00000  (offset in SNES VRAM)
    add     r1, r1, r0
    
    and     r4, r0, #(0xF << 9)     @ r4 = 00000000 00000000 000aaaa0 00000000
    bic     r0, r0, #(0xF << 9)     @ r0 = 00000000 00000000 aaa0000a aaa00000
    add     r0, r0, r4, lsl #1
    add     r3, r3, r0
    mov     r8, #1
    bl      CopyObjChar_16Loop
    ldmfd   sp!, {r3-r8, lr}
    bx      lr

VRAMObj0Offset:   .word   0
VRAMObj1Offset:   .word   0
    .ltorg


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

    .align   4

@-------------------------------------------------------------------------
@ Some variables for configuration
@-------------------------------------------------------------------------
configCursor:
    .word   0

