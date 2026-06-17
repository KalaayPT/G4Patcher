; The GivePokemon script command automatically sends a given Pokemon to the player's PC
; if their party is full. returns 2 if the Pokemon was sent, 1 otherwise.
; 0 if the party is full and the Pokemon could not be sent
; Credits:
; patch: Kalaay, pokeplatinum team: decompiling the game

.nds
.thumb

; ScrCmd_GivePokemon calls Pokemon_GiveMonFromScript, which in turn calls
; result = Party_AddPokemon(party, mon);
; result is false if the party is full, true otherwise
;
; function for automatically finding space in the pc and sending the Pokemon there:
; BOOL PCBoxes_TryStoreBoxMon(PCBoxes *pcBoxes, BoxPokemon *boxMon)
; returns true if sent successfully, false otherwise
;
; needs PCBoxes and BoxPokemon structs.
; BoxPokemon: conversion through Pokemon_GetBoxPokemon(mon)
; PCBoxes *pcBoxes = SaveData_GetPCBoxes(saveData);
;
; hook point: result = Party_AddPokemon(party, mon);
; if false,
; init BoxPokemon with Pokemon_GetBoxPokemon(mon)
; init pcBoxes with SaveData_GetPCBoxes(saveData)
; call PCBoxes_TryStoreBoxMon(pcBoxes, boxMon)
; with pcBoxes and the converted BoxPokemon
; to send the Pokemon to the PC

.definethumblabel Pokemon_GiveMonFromScript, 0x20548b0
.definethumblabel Party_AddPokemon, 0x207a048
.definethumblabel Pokemon_GetBoxPokemon, 0x2076b10
.definethumblabel SaveData_GetPCBoxes, 0x2024420
.definethumblabel PCBoxes_TryStoreBoxMon, 0x2079868

INJECT_ADDR equ 0x023C80C0

.ifdef PATCH
.open "arm9/arm9.bin", 0x02000000  ; Open arm9.bin

.org Pokemon_GiveMonFromScript + 0x64
    bl givepokemon_pc

.close
.endif

.ifdef PREASSEMBLE
.create "temp.bin", 0x023C8000
.elseifdef PATCH
.open "unpacked/synthOverlay/0009", 0x023C8000  ; Open the synth overlay
.endif


.org INJECT_ADDR

.ascii "givepokemon_pc_start"
.align 2

givepokemon_pc:
    push {r1-r7, lr}
    ; r6 = saveData
    push {r1}
    bl  Party_AddPokemon
    pop {r1}                    ; r1 = mon
    cmp r0, #1
    beq .partysuccess
    mov r0, r1                  ; r0 = mon
    bl  Pokemon_GetBoxPokemon
    mov r1, r0                  ; r1 = boxMon
    push {r1}
    mov r0, r6                  ; r0 = saveData
    bl  SaveData_GetPCBoxes     ; r0 = pcBoxes
    pop {r1}                    ; r1 = boxMon
    bl  PCBoxes_TryStoreBoxMon     ; r0 = result
    cmp r0, #1
    beq .boxsuccess

.fail:
    mov r0, #0
    pop {r1-r7, pc}
.partysuccess:
    mov r0, #1
    pop {r1-r7, pc}
.boxsuccess:
    mov r0, #2
    pop {r1-r7, pc}

.pool

.ascii "givepokemon_pc_end"

.close
