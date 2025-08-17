; infinite_TMs_HG_SS.asm
; forgettable HMs in overworld and in battle, HexEdit by Drayano, research by Mikelan98, NextWorld, BagBoy
; Mikelan98 requests that you give credit to him if you implement this in your hack.

.nds
.thumb

.open "overlay/overlay_0015.bin", 0x021F9380

.org 0x021FF5B9

    .byte 0xE0

.close

.open "arm9.bin", 0x02000000

.org 0x020825A7

    .byte 0xE0

.close