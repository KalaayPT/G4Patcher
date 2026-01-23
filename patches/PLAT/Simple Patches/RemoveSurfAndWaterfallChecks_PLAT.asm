; RemoveSurfAndWaterfallChecks_PLAT.asm by Kalaay, based on Yako's hexedit
; removes the check for a pokemon in your party having learned surf or waterfall

.nds
.thumb

.open "overlay/overlay_0005.bin", 0x021D0D80

.org 0x021d2832

    .byte 0x00, 0x20, 0x00, 0x00

.close
