; instant_pokeradar_recharge_PLAT.asm
; lets you use the pokeradar without having to recharge it, research by BagBoy and Mikelan98

.nds
.thumb

.open "arm9.bin", 0x02000000

.org 0x02069A42

    .byte 0x00

.close