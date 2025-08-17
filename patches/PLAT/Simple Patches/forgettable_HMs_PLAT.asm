; forgettable_HMs_PLAT.asm
; forgettable HMs in overworld and in battle, research by AdAstra
; make sure to not let players softlock themselves

.nds
.thumb

.open "overlay/overlay_0013.bin", 0x0221FC20

.org 0x0222056E

    .byte 0xC0, 0x46, 0x00, 0x20, 0x01, 0x28

.close

.open "arm9.bin", 0x02000000

.org 0x0208CDD2

    .byte 0xC0, 0x46, 0x00, 0x20, 0x01, 0x28

.close