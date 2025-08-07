; Apply status from overworld script command for Platinum by Yako
; Credits: The pokeplatinum team for decompiling the game

.nds
.thumb

ScriptContext_ReadHalfWord equ 0x0203E838
FieldSystem_TryGetVar equ 0x0203F150
SaveData_GetParty equ 0x0207A268
Party_GetPokemonBySlotIndex equ 0x0207A0FC
Pokemon_GetValue equ 0x02074470
Pokemon_SetValue equ 0x02074B30

ScriptVar_8004 equ 0x8004 ; Script variable 0x8004
ScriptVar_8005 equ 0x8005 ; Script variable 0x8005

MON_DATA_STATUS_CONDITION equ 160

INJECT_ADDR equ 0x023C8100

; MON_CONDITION_NONE            0
; MON_CONDITION_SLEEP_0         (1 << 0)
; MON_CONDITION_SLEEP_1         (1 << 1)
; MON_CONDITION_SLEEP_2         (1 << 2)
; MON_CONDITION_POISON          (1 << 3)
; MON_CONDITION_BURN            (1 << 4)
; MON_CONDITION_FREEZE          (1 << 5)
; MON_CONDITION_PARALYSIS       (1 << 6)
; MON_CONDITION_TOXIC           (1 << 7)
; MON_CONDITION_TOXIC_COUNTER_0 (1 << 8)
; MON_CONDITION_TOXIC_COUNTER_1 (1 << 9)
; MON_CONDITION_TOXIC_COUNTER_2 (1 << 10)
; MON_CONDITION_TOXIC_COUNTER_3 (1 << 11)


.ifdef PATCH
.open "arm9.bin", 0x02000000  ; Open arm9.bin

.org 0x020eb194 ; Overwrite pointer in scrcmd replacing DummyUnderground (CMD_335)

    .word apply_status_from_ow + 1 ; Pointer to the function in the synth overlay

.close
.endif

.ifdef PREASSEMBLE
.create "temp.bin", 0x023C8000
.elseifdef PATCH
.open "unpacked/synthOverlay/0009", 0x023C8000  ; Open the synth overlay
.endif


.org INJECT_ADDR

.ascii "status_from_ow_start"
.align 2
apply_status_from_ow:
    push {r4, r5, r6, r7, lr}
    mov r4, r0 ; Save the context pointer
    mov r1, 0x80
    add r1, r4, r1 ; r1 = scriptContext + 128 = &fieldSystem
    ldr r5,[r1] ; r5 = scriptContext->fieldSystem
    ldr r1, =ScriptVar_8004 ; read script variable 0x8004
    mov r0, r5
    bl FieldSystem_TryGetVar ; FieldSystem_TryGetVar(ctx->fieldSystem, 0x8004)
    mov r6, r0 ; r6 = partySlot
    ldr r1, =ScriptVar_8005 ; read script variable 0x8005
    mov r0, r5
    bl FieldSystem_TryGetVar ; FieldSystem_TryGetVar(ctx->fieldSystem, 0x8005)
    mov r4, r0 ; r4 = status parameter
    ldr r0,[r5,#0xc] ; r0 = fieldSystem->saveData
    bl SaveData_GetParty ; SaveData_GetParty(fieldSystem->saveData)
    mov r1, r6
    bl Party_GetPokemonBySlotIndex ; Party_GetPokemonBySlotIndex(SaveData_GetParty(fieldSystem->saveData), partySlot)
    mov r7, r0 ; r7 = mon
    mov r1, MON_DATA_STATUS_CONDITION
    mov r2, 0
    bl Pokemon_GetValue ; Pokemon_GetValue(mon, MON_DATA_STATUS_CONDITION, NULL)
    cmp r0, #0
    beq noStatus ; Only if mon has no status condition
    mov r0, #1 ; return true for failure
    pop {r4, r5, r6, r7, pc} ; pop registers and return

    noStatus: 
    sub sp, #0x4 ; Make space for status parameter
    str r4, [sp] ; Store the status parameter on the stack
    mov r0, r7 ; r0 = mon
    mov r1, MON_DATA_STATUS_CONDITION ; r1 = MON_DATA_STATUS_CONDITION
    mov r2, sp ; r2 = &param
    bl Pokemon_SetValue ; Pokemon_SetValue(mon, MON_DATA_STATUS_CONDITION, &param);
    mov r0, #0 ; return false for success
    add sp, #0x4 ; Clean up the stack
    pop {r4, r5, r6, r7, pc} ; pop registers and return

.pool

.ascii "status_from_ow_end"

.close