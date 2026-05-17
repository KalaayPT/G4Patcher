; remove_EVs_HG_SS.asm
; remove EV gain in battle, by Kalaay

.nds
.thumb

.open "arm9_overlays/ov016.bin", 0x0223B140

.org 0x2249B7C

    .byte 0x00
    .byte 0x00
    .byte 0x00
    .byte 0x00

.close
