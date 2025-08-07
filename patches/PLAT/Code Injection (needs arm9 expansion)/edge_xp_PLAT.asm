; Set pokemon xp to be 1 point away from the next level, by Kalaay
; this is most useful for level-capped nuzlockes
; Thanks: The pret pokeplatinum team for decompiling the game

.nds
.thumb

SaveData_GetParty equ 0x0207A268
Party_GetPokemonBySlotIndex equ 0x0207A0FC
Pokemon_GetValue equ 0x02074470
Pokemon_SetValue equ 0x02074B30
Pokemon_GetExpToNextLevel equ 0x02075A70
Pokemon_CalcLevelAndStats equ 0x0207418C
Party_GetCurrentCount equ 0x0207A0F8

INJECT_ADDR equ 0x023C8000

.ifdef PATCH
.open "arm9.bin", 0x02000000  ; Open arm9.bin

.org 0x020EB390 ; Overwrite pointer in scrcmd replacing ScrCmd_1CE (CMD_462)

    .word edge_xp + 1 ; Pointer to the function in the synth overlay

.close
.endif

.ifdef PREASSEMBLE
.create "temp.bin", 0x023C8000
.elseifdef PATCH
.open "unpacked/synthOverlay/0009", 0x023C8000  ; Open the synth overlay
.endif


.org INJECT_ADDR

.ascii "edge_xp_start"
.align 2
edge_xp:
    push    {r1-r7, lr}                 ; Save registers
    sub     sp, #0x4                    ; Make space for status parameter
    mov     r4, r0                      ; Save the context pointer
    mov     r1, 0x80
    add     r1, r4, r1                  ; r1 = scriptContext + 128 = &fieldSystem
    ldr     r5,[r1]                     ; r5 = scriptContext->fieldSystem
    ldr     r0,[r5,#0xc]                ; r0 = fieldSystem->saveData
    bl      SaveData_GetParty           ; SaveData_GetParty(fieldSystem->saveData)
    mov     r4, r0                      ; r7 = party pointer
    bl      Party_GetCurrentCount       ; Get the current count of the party
    mov     r6, r0                      ; r6 = partyCount

edge_xp_loop:
    mov     r0, r4                      ; r0 = party pointer
    sub     r6, r6, #1                  ; Decrement partyCount
    mov     r1, r6                      ; r1 = partySlot (current index)
    bl      Party_GetPokemonBySlotIndex ; Party_GetPokemonBySlotIndex(SaveData_GetParty(fieldSystem->saveData), partySlot)
    mov     r7, r0                      ; r7 = mon
    mov     r1,#0x8                     ; r1 = MON_DATA_EXP
    mov     r2,#0x0                     ; NULL
    bl      Pokemon_GetValue            ; Pokemon_GetValue(mon, MON_DATA_EXP, NULL)
    mov     r5, r0                      ; r5 = current mon exp
    mov     r0, r7                      ; r0 = mon
    bl      Pokemon_GetExpToNextLevel   ; Get the exp needed for the next level
    sub     r0, r0, #1                  ; r0 = exp needed for next level - 1 (edge XP)
    add     r2, r0, r5                  ; r0 = current exp + edge XP
    str     r2, [sp]                    ; Store the edge XP on the stack
    mov     r2, sp                      ; r2 = &edgeXP
    mov     r0,r7                       ; r0 = mon
    mov     r1,#0x8                     ; r1 = MON_DATA_EXP
    bl      Pokemon_SetValue            ; Pokemon_SetValue(mon, MON_DATA_EXP, edgeXP);
    mov     r0, r7                      ; r0 = mon
    bl      Pokemon_CalcLevelAndStats   ; Recalculate stats after setting new exp
    cmp     r6, #0x0                    ; Check if we have more mons in the party
    bne     edge_xp_loop                ; If there are more mons, repeat the loop

return:
    add     sp, #0x4                    ; Clean up the stack
    mov     r0, #0                      ; return false for success
    pop     {r1-r7, pc}                 ; pop registers and return

.pool

.ascii "edge_xp_end"

.close