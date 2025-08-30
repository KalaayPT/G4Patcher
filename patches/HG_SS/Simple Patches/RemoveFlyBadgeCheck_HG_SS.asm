; FramerateUnlock_HG_SS.asm

.nds
.thumb

.open "arm9.bin", 0x02000000

.org 0x0206802c

    .byte 0x01
    .byte 0xE0

.close