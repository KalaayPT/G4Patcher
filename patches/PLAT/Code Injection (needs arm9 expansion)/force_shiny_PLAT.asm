; Force Shiny Pokémon Encounter Patch for Pokémon Platinum by Yako
; Credits: the pokeplatinum team for decompiling the game

; Settings

ShinyFlag equ 2570 ; Flag that determines whether encounter is shiny

; End of settings

.nds
.thumb

FieldSystem_TryGetVar equ 0x020403AC
SaveData_GetVarsFlags equ 0x020507E4
VarsFlags_CheckFlag equ 0x020507F0
CreateWildMon equ 0x02241CC0
CreateWildMonShinyWithGenderOrNature equ 0x02241BAC

INJECT_ADDR equ 0x023C8020

.ifdef PATCH
.open "overlay/overlay_0006.bin", 0x0223E140  ; Open Overlay 6

.org 0x02241CC2

    bl hook
    sub sp, #0x14

.close
.endif

.ifdef PREASSEMBLE
.create "temp.bin", 0x023C8000
.elseifdef PATCH
.open "unpacked/synthOverlay/0009", 0x023C8000  ; Open the synth overlay
.endif

.org INJECT_ADDR
.ascii "force_shiny_start"
.align 2
hook:
    push {r0-r3, lr}
    ; On the stack now: r0-r3, lr | r4-r7, lr | firstPartyMon, battleParams
    ldr r6, [sp,#0x2C] ; r6 = battleParams
    ldr r1, =0x1c0
    add r0, r6, r1
    ldr r0, [r0] ; r4 = battleParams->*saveData
    bl SaveData_GetVarsFlags ; r0 = varsFlags
    ldr r1, =ShinyFlag
    bl VarsFlags_CheckFlag
    cmp r0, #1 ; Check if the flag is set
    beq forceShiny
    pop {r0-r3}
    ; overwritten instructions of CreateWildMon
    add r7, r0, #0
    mov r0, #0xb
    pop {pc} ; Return to CreateWildMon
forceShiny:
    ; Prepare stack for CreateWildMonShinyWithGenderOrNature
    pop {r0-r3} ; pop the registers we pushed earlier
    ; On the stack now: lr | r4-r7, lr | firstPartyMon, battleParams
    add r4, r3, #0 ; r4 = WildEncounters_FieldParams
    ldr r5, [sp,#0x28] ; r5 = firstPartyMon
    ldr r3, [r3] ; r3 = WildEncounters_FieldParams->trainerID
    push {r4-r6} ; Push parameters to stack
    ; On the stack now: r4 = WildEncounters_FieldParams, r5 = firstPartyMon, r6 = battleParams, lr | r4-r7, lr | firstPartyMon, battleParams
    bl CreateWildMonShinyWithGenderOrNature
    add sp, #0x10 ; Cleanup parameters
    pop {r4-r7, pc} ; pop and return, stack should now be in original state before CreateWildMon was called
.pool

.ascii "force_shiny_end"

.close
