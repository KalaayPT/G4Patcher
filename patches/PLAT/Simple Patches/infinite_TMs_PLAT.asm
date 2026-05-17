; infinite_TMs_PLAT.asm
; forgettable HMs in overworld and in battle, HexEdit by Drayano, research by Mikelan98, NextWorld, BagBoy
; Mikelan98 requests that you give credit to him if you implement this in your hack.

.nds
.thumb

.open "arm9_overlays/ov084.bin", 0x0223B5A0

.org 0x0223F912

    .word 0

.close

.open "arm9/arm9.bin", 0x02000000

.org 0x020865EB

    .byte 0xE0

.close
