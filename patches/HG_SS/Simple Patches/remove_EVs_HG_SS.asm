; remove_EVs_HG_SS.asm
; remove EV gain in battle, by Kalaay

.nds
.thumb

.open "arm9_overlays/ov012.bin", 0x022378C0

.org 0x22465A4

    .byte 0x00
    .byte 0x00
    .byte 0x00
    .byte 0x00

.close
