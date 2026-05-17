; vs_seeker_qol_PLAT.asm
; battery 1 step recharge and 100% chance of finding trainers, research by BagBoy

.nds
.thumb

.open "arm9_overlays/ov005.bin", 0x021D0D80

.org 0x021DBBC4

    .byte 0x64
    .byte 0x26
    .byte 0x31

.org 0x021DBD28

    .byte 0x64

.close
