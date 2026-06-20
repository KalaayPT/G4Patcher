; turn any pokemon in the party shiny
; original hgss implementation by AdAstra, G4P + Platinum adaptation by Kalaay
; replaces script command 421, as it is ununsed and already takes one argument

.nds
.thumb

.definethumblabel ScriptContext_ReadHalfWord, 0x0203E838
.definethumblabel FieldSystem_TryGetVar, 0x0203F150
.definethumblabel SaveData_GetParty, 0x0207A268
.definethumblabel Party_GetPokemonBySlotIndex, 0x0207A0FC
.definethumblabel Pokemon_GetValue, 0x02074470
.definethumblabel Pokemon_FindShinyPersonality, 0x02075E64
.definethumblabel sub_020780C4, 0x020780C4

INJECT_ADDR equ 0x023C8040
.ifdef PATCH
.open "arm9/arm9.bin", 0x02000000  ; Open arm9.bin

.org 0x020eb2ec ; Overwrite pointer in scrcmd replacing Dummy1A5 (CMD_421)
    .word shinify + 1 ; Pointer to the function in the synth overlay

.close
.endif

.ifdef PREASSEMBLE
.create "temp.bin", 0x023C8000
.elseifdef PATCH
.open "unpacked/synthOverlay/0009", 0x023C8000  ; Open the synth overlay
.endif


.org INJECT_ADDR

.ascii "shinify_start"
.align 2
shinify:
push {r3-r5, lr}

mov r5, r0

bl ScriptContext_ReadHalfWord       ; read u16 from script data
mov r1, r0
mov r0, r5
add r0, #0x80
ldr r0, [r0]
bl FieldSystem_TryGetVar            ; flex disambiguator

add r5, #0x80
mov r4, r0

ldr r0, [r5]
ldr r0, [r0, #0xc]
bl SaveData_GetParty                ; get party
mov r1, r4
bl Party_GetPokemonBySlotIndex      ; get mon by index
mov r4, r0

mov r1, #7
mov r2, #0
bl Pokemon_GetValue                 ; get mon parameter
bl Pokemon_FindShinyPersonality     ; generate shiny personality

mov r1, r0
mov r0, r4
bl sub_020780C4                     ; apply personality

mov r0, #0
pop {r3-r5, pc}

.pool

.ascii "shinify_end"

.close