; Time_of_day_evos_HG_SS.asm
; removes the time of day requirement from HeldItem-TimeofDay evolutions, by Kalaay

.nds
.thumb

.open "arm9.bin", 0x02000000

.org 0x0207109a

    .byte 0x00
    .byte 0x00
    .byte 0x00
    .byte 0x00

.org 0x020710b2

    .byte 0x00
    .byte 0x00
    .byte 0x00
    .byte 0x00

.close

