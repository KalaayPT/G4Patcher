; SetModeFastTextDefault_HG_SS.asm
; Set Battle Mode and Fast Text are set as the default when starting a game

.nds
.thumb

.open "arm9.bin", 0x02000000

.org 0x0202ACBA
    .byte 0x02

.org 0x0202acca
    .byte 0x40, 0x20, 0x01, 0x43

.close