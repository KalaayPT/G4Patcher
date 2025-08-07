; Dynamic Encounters and Weather Patch for Pokémon Heartgold and Soulsilver (USA) by Yako
; credit: the pokeheartgold team for decompiling the game; Mikelan98 and Nomura for the arm9 expansion
; Settings

ENCDATA_NARC_index equ 37 ; The index of the encounter data narc. 0x25 = 37 (HG) / 0x88 = 136 (SS)
.notice "Make sure that the ENCDATA_NARC_index variable matches your game version! 37 for HeartGold, 136 for SoulSilver. Currently set to " + ENCDATA_NARC_index

; Script variables to be used as parameters
; You can change these if you like
ScriptVar_Param1 equ 0x4015 ; Controls if encounters or weather are used; 0: encounters, >=1: weather
ScriptVar_Param2 equ 0x4016 ; Controls the encounter bank or weather type
ScriptVar_Param3 equ 0x4017 ; Controls the weather animation toggle; 0: skip animation, 1: play animation; Unused for encounters

; End of settings

.nds
.thumb

; pokeheartgold has different names for the functions but I prefer the pokeplatinum names so I will keep them
FieldSystem_TryGetVar equ 0x020403AC ; FieldSystem_VarGet
MapHeaderData_GetWildEncounters equ 0x0203B344 ; MapHeader_GetWildEncounterBank
NARC_ReadWholeMemberByIndexPair equ 0x02007508 ; ReadWholeNarcMemberByIdPair
SaveData_GetFieldOverworldState equ 0x0203B9C4 ; Save_LocalFieldData_Get
FieldOverworldState_SetWeather equ 0x0203B98C; LocalFieldData_SetWeatherType
UpdateWeatherAnimation equ 0x021EB2B8 ; FieldWeatherUpdate_UsedFlash (this handles more than just flash bad name by pokeheartgold)

INJECT_ADDR equ 0x023C8070

.ifdef PATCH
.open "arm9.bin", 0x02000000  ; Open arm9.bin

.org 0x020fb07c ; Overwrite script command DummyTrainerBattle (0xDF/223)

    .word dyn_enc_weath+1

.close
.endif

.ifdef PREASSEMBLE
.create "temp.bin", 0x023C8000
.elseifdef PATCH
.open "unpacked/synthOverlay/0000", 0x023C8000  ; Open the synth overlay
.endif

.org INJECT_ADDR
.ascii "dyn_enc_weath_start"
.align 2
dyn_enc_weath:
    push {r4, r5, r6, r7, lr}
    mov r4, r0 ; Save the context pointer
    mov r1, 0x80
    add r1, r4, r1 ; r1 = scriptContext + 128 = &fieldSystem
    ldr r5,[r1] ; r5 = scriptContext->fieldSystem
    ldr r1, =ScriptVar_Param1
    mov r0, r5
    bl FieldSystem_TryGetVar ; FieldSystem_TryGetVar(ctx->fieldSystem, param1)
    cmp r0, #0 ; if r0 == 0 -> Dynamic encounters otherwise Dynamic weather
    bne dynamicWeather ; if r0 != 0 -> Dynamic weather
    ldr r1,[r5,#0x14] ; fieldSystem->mapEvents
    mov r0,#0x92 ; r0 = 146
    lsl r0,r0,#0x4 ; r0 = 146 * 16 = 2336 (0x920)
    add r6,r1,r0 ; r6 = fieldSystem->mapEvents + 0x920 = &fieldSystem->mapEvents->wildEncounterData
    ldr r1, =ScriptVar_Param2 ;
    mov r0, r5
    bl FieldSystem_TryGetVar ; FieldSystem_TryGetVar(ctx->fieldSystem, param2)
    mov r2, r0 ; r2 = encounter bank
    mov r0, r6 ; r0 = wildEncounterData
    mov r1, ENCDATA_NARC_index   ; #0x88 ; 34 (HG) / 136 (SS)
    bl NARC_ReadWholeMemberByIndexPair ; NARC_ReadWholeMemberByIndexPair(encData, ENCDATA_NARC, bank);
    mov r0, #0 ; return 0
    pop {r4, r5, r6, r7, pc} ; pop registers and return
    dynamicWeather:
    ldr r0,[r5,#0xc] ; r0 = fieldSystem->saveData
    bl SaveData_GetFieldOverworldState ; r0 = fieldState
    mov r6, r0 ; r6 = fieldState
    ldr r1, =ScriptVar_Param2 ;
    mov r0, r5
    bl FieldSystem_TryGetVar ; FieldSystem_TryGetVar(ctx->fieldSystem, param2)
    mov r7, r0 ; r7 = weatherId
    ldr r1, =ScriptVar_Param3 ;
    mov r0, r5
    bl FieldSystem_TryGetVar ; FieldSystem_TryGetVar(ctx->fieldSystem, param3)
    mov r4, r0 ; r4 = animation toggle
    mov r1, r7 ; weatherId
    mov r0, r6 ; r0 = fieldState
    bl FieldOverworldState_SetWeather ; FieldOverworldState_SetWeather(fieldState, weather);
    cmp r4, #0 ; check if skip animation toggle is 0
    beq dynweather_end ; if animation toggle is 0, skip to end
    mov r0, r5 ; r0 = fieldSystem
    ldr r0,[r0,#0x4] ; r0 = fieldSystem->unk_04
    ldr r0,[r0,#0xc] ; r0 = fieldSystem->unk_04->unk_0C
    mov r1, r7 ; r1 = weatherId
    bl UpdateWeatherAnimation ; (ctx->fieldSystem->unk_04->unk_0C, weather);
    dynweather_end:
    mov r0, #0x0 ; return 0
    pop {r4, r5, r6, r7, pc} ; pop registers and return

.pool

.ascii "dyn_enc_weath_end"

.close