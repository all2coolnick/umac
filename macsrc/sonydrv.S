        /* Replacement paravirt Sony driver stubs
         *
         * This is the Basilisk "sony_driver" from the binary code in rom_patches.cpp,
         * except instead of using custom opcodes this driver stores magic values
         * to a magic address.
         *
         * The original code:   Basilisk II (C) Christian Bauer
         * Extensions:          Copyright 2024 Matt Evans
         *
         * GPLv2
         */

#define SONY_REF_NUM            -5
#define SONY_STATUS_SIZE        30

        .org 0
        .globl _start
_start:
        .globl header
header:
        .word 0x6f00            // flags
        .word 0                 // ticks between actions
        .word 0                 // desk accessory event mask
        .word 0                 // menu ID
        .word open
        .word prime
        .word control
        .word status
        .word close
name:
        .byte 5
        .ascii ".Sony"

open:
        // Open()   A0 = pb, A1 = dce
        // Registers: a3 = pb, a4 = dce, a5 = fault address, a2 = drive status
        // block, d3 = number of drives, d4 = drive index.
        movem.l %d3-%d4/%a2-%a5, -(%sp)
        move.l  %a0, %a3
        move.l  %a1, %a4
        move.l  (faulting_address), %a5
        move.b  #4, (%a5)                       // Op 4: d0 = number of drives
        move.l  %d0, %d3
        moveq   #0, %d4
1:      cmp.l   %d3, %d4
        bge.b   5f
        // Allocate drive status block and pass to Open routine:
        moveq   #SONY_STATUS_SIZE, %d0
        .word   0xa71e                          // NewPtrSysClear
        move.l  %a0, %a2
        cmp.l   #0, %a2
        beq     6f                              // lolfail
        move.l  %a3, %a0
        move.l  %a4, %a1
        move.l  %d4, %d1                        // Drive index
        move.b  #0, (%a5)                       // Fault! Open: op 0, d0 = drive number
        tst.l   %d0
        ble.b   2f                              // Not usable, skip
        // Now add the drive:
        swap    %d0                             // Drive number in high word
        move.w  #SONY_REF_NUM, %d0              // Driver refnum in low word
        move.l  %a2, %a0
        add.l   #6, %a0
        .word   0xa04e                          // AddDrive
2:      addq.l  #1, %d4
        bra.b   1b
5:      moveq   #0, %d0
        bra.b   7f
6:      moveq   #-23, %d0
7:      movem.l (%sp)+, %d3-%d4/%a2-%a5
        rts

prime:
        // Prime()
        move.l  (faulting_address), %a2
        move.b  #1, (%a2)                       // Prime: op 1
        bra.b   IOReturn

control:
        // Control()
        move.l  (faulting_address), %a2
        cmp.w   #65, 0x1a(%a0)                  // accRun (periodic)?
        beq.b   accrun
        move.b  #2, (%a2)                       // Control: op 2
        cmp.w   #1, 0x1a(%a0)
        bne.b   IOReturn
        rts

accrun:
        // Periodic: ask the host whether a drive needs mounting.
        movem.l %d3/%a0, -(%sp)
        move.b  #5, (%a2)                       // Op 5: d0 = drive number, or 0
        tst.l   %d0
        beq.b   1f
        move.l  %d0, %d3                        // Drive number
        lea     -80(%sp), %sp                   // Scratch parameter block
        move.l  %sp, %a0
        moveq   #19, %d1
3:      clr.l   (%a0)+
        dbra    %d1, 3b
        move.l  %sp, %a0
        move.w  %d3, 22(%a0)                    // ioVRefNum = drive number
        .word   0xa00f                          // MountVol
        lea     80(%sp), %sp
        swap    %d0                             // Result into high word
        move.w  %d3, %d0                        // Drive number in low word
        move.l  %d0, %a0                        // Event message
        moveq   #7, %d0                         // diskEvt
        .word   0xa02f                          // PostEvent
1:      movem.l (%sp)+, %d3/%a0
        moveq   #0, %d0
        bra.b   IOReturn

status:
        // Status()
        move.l  (faulting_address), %a2
        move.b  #3, (%a2)                       // Status: op 3
        // Fall through

IOReturn:
        // IOReturn
        move.w  6(%a0),%d1                      // IO trap?
        btst    #9,%d1                          // Test queue bit
        beq.b   1f
        tst.w   %d0                             // Not queued; test async result
        ble.b   2f
        clr.w   %d0                             // In progress
2:      move.w  %d0, 0x10(%a0)                  // ImmedRTS
        rts
1:      tst.w   %d0                             // Queued
        ble.b   3f
        clr.w   %d0
        rts
3:      move.l  0x8fc,-(%sp)                    // IODone vector
        rts

close:
        // Close()
        moveq   #-24, %d0                       // closErr
        rts

        .balign 4
faulting_address:
        .long   0
