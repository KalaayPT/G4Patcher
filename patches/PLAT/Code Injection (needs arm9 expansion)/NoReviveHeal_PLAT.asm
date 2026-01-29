; NoReviveHeal_PLAT.asm
; makes full party heals not revive fainted pokemon, by Kalaay

.nds
.thumb

; ------------------------------------------------------------------------------------
; DO NOT EDIT BELOW HERE UNLESS YOU KNOW WHAT YOURE DOING
; ------------------------------------------------------------------------------------

; GetMonData in HGSS
Pokemon_GetValue equ 0x02074470

INJECT_ADDR equ 0x023C8000

; ------- Inject hook into arm9.bin -------
.ifdef PATCH
.open "arm9.bin", 0x02000000

.org 0x020972b4 ; hook into Pokemon_GetValue(uVar2,MON_DATA_MAX_HP,0);
    bl ReviveCheck

.close
.endif

; ------- Write function to synthOverlay 0009 -------
.ifdef PREASSEMBLE
.create "temp.bin", 0x023C8000
.elseifdef PATCH
.open "unpacked/synthOverlay/0009", 0x023C8000
.endif


.org INJECT_ADDR
.ascii "NoReviveHeal_start"

ReviveCheck:
    push    {r3-r7, pc}
    add     r0,r5,#0x0      ; mon
    mov     r1,#0xA3        ; MON_DATA_CURRENT_HP
    mov     r2,#0x0
    bl      Pokemon_GetValue
    cmp     r0,#0x0         ; check if mon is alive
    beq     return_defeated  ; if mon is defeated, branch to return_defeated

return_normal:
    add     r0,r5,#0x0      ; mon
    mov     r1,#0xA4        ; MON_DATA_MAX_HP
    mov     r2,#0x0
    bl      Pokemon_GetValue
    pop     {r3-r7, pc}

return_defeated:
    mov     r0,#0x0
    pop     {r3-r7, pc}

.pool

.ascii "NoReviveHeal_end"

.close
