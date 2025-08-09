; vs_seeker_qol_PLAT.asm
; battery 1 step recharge and 100% chance of finding trainers, research by Memory5ty7

.nds
.thumb

.open "overlay/overlay_0014.bin", 0x0221FC20

.org 0x022249CC

    .byte 0x57

.close