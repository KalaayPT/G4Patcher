; instant_party_healing_PLAT.asm
; instant item healing in party menu, research by Yako

.nds
.thumb

.open "arm9.bin", 0x02000000

.org 0x02085734

    .byte 0x21
    .byte 0x46

.close