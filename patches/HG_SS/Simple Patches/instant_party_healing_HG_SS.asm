; instant_party_healing_HG_SS.asm
; instant item healing in party menu, research by Fantafaust

.nds
.thumb

.open "arm9.bin", 0x02000000

.org 0x02081750

    .byte 0x21
    .byte 0x00

.close