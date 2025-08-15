; QoLItems_HG_SS.asm

.nds
.thumb

ScriptID equ 2072 ; (Commonscript ID)

NULL equ 0x00000000
ItemFieldUseFunc_Generic equ 0x02065150+1
ItemMenuUseFunc_HealingItem equ 0x02064B54+1
ItemCheckUseFunc_Dummy equ 0x02064BF4+1
ItemMenuUseFunc_Bicycle equ 0x02064BFC+1
ItemFieldUseFunc_Bicycle equ 0x02064C30+1
ItemCheckUseFunc_Bicycle equ 0x02064DA8+1
ItemMenuUseFunc_TMHM equ 0x02064E18+1
ItemMenuUseFunc_Mail equ 0x02064EB8+1
ItemMenuUseFunc_Berry equ 0x02064F08+1
ItemCheckUseFunc_Berry equ 0x02064F04+1
ItemMenuUseFunc_PalPad equ 0x02064F28+1
ItemFieldUseFunc_PalPad equ 0x02064F5C+1
ItemMenuUseFunc_Honey equ 0x02064F7C+1
ItemMenuUseFunc_OldRod equ 0x02064FD4+1
ItemFieldUseFunc_OldRod equ 0x02065010+1
ItemMenuUseFunc_GoodRod equ 0x02065030+1
ItemFieldUseFunc_GoodRod equ 0x0206506C+1
ItemMenuUseFunc_SuperRod equ 0x0206508C+1
ItemFieldUseFunc_SuperRod equ 0x020650C8+1
ItemCheckUseFunc_FishingRod equ 0x020650E8+1
ItemMenuUseFunc_EvoStone equ 0x02065258+1
ItemMenuUseFunc_EscapeRope equ 0x02065310+1
ItemCheckUseFunc_EscapeRope equ 0x0206536C+1
ItemMenuUseFunc_ApricornBox equ 0x020653D8+1
ItemFieldUseFunc_ApricornBox equ 0x02065408+1
ItemMenuUseFunc_BerryPots equ 0x02065428+1
ItemFieldUseFunc_BerryPots equ 0x02065458+1
ItemMenuUseFunc_UnownReport equ 0x02065474+1
ItemFieldUseFunc_UnownReport equ 0x020654A4+1
ItemMenuUseFunc_DowsingMchn equ 0x020654C0+1
ItemFieldUseFunc_DowsingMchn equ 0x020654F4+1
ItemMenuUseFunc_Gracidea equ 0x020655B8+1
ItemFieldUseFunc_Gracidea equ 0x020655F0+1
ItemMenuUseFunc_VSRecorder equ 0x02065614+1
ItemFieldUseFunc_VSRecorder equ 0x02065648+1
ItemFieldUseFunc_GbSounds equ 0x02065560+1

SEQ_SE_DP_CARD2 equ 1535
PlaySE equ 0x0200604C  ; PlaySE(soundId)
SaveData_Get equ 0x020272B0
Save_VarsFlags_Get equ 0x020503D0
Save_VarsFlags_GetVarAddr	equ 0x020504A4
RepelFlag equ 0x416F ; (Flag ID, Hexadecimal)
Save_VarsFlags_SetFlagInArray equ 0x02050408
Save_VarsFlags_GetFlagAddr equ 0x0205045C
Save_VarsFlags_ClearFlagInArray equ 0x02050430
TaskManager_GetFieldSystem equ 0x0205064C
TaskManager_GetEnvironment equ 0x02050650
FieldSystem_LoadFieldOverlay equ 0x020505C0
AllocFromHeap equ 0x0201AA8C
NewMsgDataFromNarc equ 0x0200BAF8
NewString_ReadMsgData equ 0x0200BBA0
DestroyMsgData equ 0x0200BB44
FieldSystem_CreateTask equ 0x020504F0
String_New equ 0x02026354
TryFormatRegisteredKeyItemUseMessage equ 0x02077980
SoundSys_GetGBSoundsState equ 0x02005C18
SoundSys_ToggleGBSounds equ 0x02005C24
StringExpandPlaceholders equ 0x0200CBBC
String_Delete equ 0x02026380
HealParty equ 0x02090C1C
SaveArray_Party_Get equ 0x02074904
SEQ_SE_DP_KAIFUKU equ 1516 ; pokemon healed sound effect
StartMapSceneScript equ 0x0203FE74 ; StartMapSceneScript(fieldSystem, scriptID, lastInteracted)
Task_MountOrDismountBicycle equ 0x02064C59
Task_RunScripts equ 0x0203FF44
ScriptEnvironment_New equ 0x0204001C
SetupScriptEngine equ 0x0204005C
Task_StartMenu_HandleReturn equ 0x0203CFC0

INJECT_ADDR equ 0x023C8000

; ------- Inject hook into arm9.bin -------
.ifdef PATCH
.open "arm9.bin", 0x02000000

.org 0x020649ac
    .word sItemFieldUseFuncs
.org 0x020649b0
    .word sItemFieldUseFuncs+4
.org 0x020649b4
    .word sItemFieldUseFuncs+8

.org 0x0210051C ; overwrite narc ids table for entry 113, make infinite repel
; this copies the max repel entry, but with a different narc id, you will have to create this narc (0514) yourself
    .byte 0x02, 0x02, 0x6D, 0x00, 0x6F, 0x00, 0x54, 0x00

;.org 0x02100524 ; overwrite narc ids table for entry 114, make infinite candy/cap candy, NOT IMPLEMENTED YET
;; this copies the rare candy entry, but with a different narc id, you will have to create this narc (0515) yourself
;    .byte 0x03, 0x02, 0x5A, 0x00, 0x5B, 0x00, 0x44, 0x00

.org 0x0210052C ; overwrite narc ids table for entry 115, make medkit
; this copies the full restore entry, but with a different narc id, you will have to create this narc (0516) yourself
    .byte 0x04, 0x02, 0x21, 0x00, 0x22, 0x00, 0x13, 0x00

.org 0x02100534 ; overwrite narc ids table for entry 116, make pkmn box link
; this copies the gracidea entry, but with a different narc id, you will have to create this narc (0517) yourself
    .byte 0x05, 0x02, 0xBF, 0x02, 0xC0, 0x02, 0x00, 0x00

.close

.open "overlay/overlay_0015.bin", 0x021F9380
.org 0x021FBA76
    bl BagApp_UseItemExpansion ; overwrite the return of the BagApp_TryUseItemInPlace function
.close

.endif

; ------- Write function to synthOverlay 0000 -------
.ifdef PREASSEMBLE
.create "temp.bin", 0x023C8000
.elseifdef PATCH
.open "unpacked/synthOverlay/0000", 0x023C8000
.endif


.org INJECT_ADDR
.ascii "QoLItems_start"

.align 4
sItemFieldUseFuncs:
    .word NULL,                        ItemFieldUseFunc_Generic,     NULL
    .word ItemMenuUseFunc_HealingItem, NULL,                         NULL
    .word NULL,                        NULL,                         ItemCheckUseFunc_Dummy
    .word NULL,                        NULL,                         ItemCheckUseFunc_Dummy
    .word ItemMenuUseFunc_Bicycle,     ItemFieldUseFunc_Bicycle,     ItemCheckUseFunc_Bicycle
    .word NULL,                        NULL,                         ItemCheckUseFunc_Dummy
    .word ItemMenuUseFunc_TMHM,        NULL,                         NULL
    .word ItemMenuUseFunc_Mail,        NULL,                         NULL
    .word ItemMenuUseFunc_Berry,       NULL,                         ItemCheckUseFunc_Berry
    .word NULL,                        NULL,                         ItemCheckUseFunc_Dummy
    .word ItemMenuUseFunc_PalPad,      ItemFieldUseFunc_PalPad,      NULL
    .word NULL,                        NULL,                         ItemCheckUseFunc_Dummy
    .word NULL,                        NULL,                         ItemCheckUseFunc_Dummy
    .word NULL,                        NULL,                         ItemCheckUseFunc_Dummy
    .word ItemMenuUseFunc_Honey,       NULL,                         NULL
    .word NULL,                        NULL,                         ItemCheckUseFunc_Dummy
    .word ItemMenuUseFunc_OldRod,      ItemFieldUseFunc_OldRod,      ItemCheckUseFunc_FishingRod
    .word ItemMenuUseFunc_GoodRod,     ItemFieldUseFunc_GoodRod,     ItemCheckUseFunc_FishingRod
    .word ItemMenuUseFunc_SuperRod,    ItemFieldUseFunc_SuperRod,    ItemCheckUseFunc_FishingRod
    .word NULL,                        ItemFieldUseFunc_Generic,     NULL
    .word ItemMenuUseFunc_EvoStone,    NULL,                         NULL
    .word ItemMenuUseFunc_EscapeRope,  NULL,                         ItemCheckUseFunc_EscapeRope
    .word NULL,                        NULL,                         ItemCheckUseFunc_Dummy
    .word ItemMenuUseFunc_ApricornBox, ItemFieldUseFunc_ApricornBox, NULL
    .word ItemMenuUseFunc_BerryPots,   ItemFieldUseFunc_BerryPots,   NULL
    .word ItemMenuUseFunc_UnownReport, ItemFieldUseFunc_UnownReport, NULL
    .word ItemMenuUseFunc_DowsingMchn, ItemFieldUseFunc_DowsingMchn, NULL
    .word NULL,                        ItemFieldUseFunc_GbSounds,    NULL
    .word ItemMenuUseFunc_Gracidea,    ItemFieldUseFunc_Gracidea,    NULL
    .word ItemMenuUseFunc_VSRecorder,  ItemFieldUseFunc_VSRecorder,  NULL                       ; normal table until here
    .word NULL,                        ItemFieldUseFunc_InfiniteRepel+1,NULL                    ; new entry 30: infinite repel
    .word NULL,                        ItemFieldUseFunc_MedKit+1, NULL                          ; new entry 31: medkit
    .word ItemMenuUseFunc_PKMNBoxLink+1,ItemFieldUseFunc_PKMNBoxLink+1,NULL                     ; new entry 32: pkmn box link

.align 4

ItemFieldUseFunc_InfiniteRepel:
    push       {r4,r5,r6,lr}
    add        r6,r0,#0x0
    mov        r0,#0xb
    mov        r1,#0x18
    bl         AllocFromHeap
    add        r4,r0,#0x0
    mov        r0,#0x0
    mov        r1,#0x1b
    mov        r2,#0xa
    mov        r3,#0xb
    strh       r0,[r4,#0x16]
    bl         NewMsgDataFromNarc
    add        r5,r0,#0x0
    bl         IsRepelOn
    cmp        r0,#0x0
    beq        LAB_02065590
    add        r0,r5,#0x0
    mov        r1,#66
    bl         NewString_ReadMsgData
    b          LAB_02065598
LAB_02065590:
    add        r0,r5,#0x0
    mov        r1,#67
    bl         NewString_ReadMsgData
LAB_02065598:
    str        r0,[r4,#0x10]
    add        r0,r5,#0x0
    bl         DestroyMsgData
    bl         UseInfiniteRepel
    ldr        r0,[r6]
    ldr        r1,=0x0206518D
    add        r2,r4,#0x0
    bl         FieldSystem_CreateTask
    mov        r0,#0x0
    pop        {r4,r5,r6,pc}

ItemMenuUseFunc_PKMNBoxLink:
    push        {r0-r7,lr}
    add         r4,r0,#0x0
    ldr         r0,[r4,#0x0 ]
    bl          TaskManager_GetFieldSystem
    add         r5,r0,#0x0
    ldr         r0,[r4,#0x0 ]
    bl          TaskManager_GetEnvironment
    add         r4,r0,#0x0
    add         r0,r5,#0x0
    bl          FieldSystem_LoadFieldOverlay ; leave the bag
    bl          ScriptEnvironment_New
    mov         r6,r0                   ; r6 = ScriptEnvironment *scriptEnvironment
    mov         r0,r5                   ; r0 = fieldSystem
    mov         r1,r6                   ; r1 = scriptEnvironment
    ldr         r2,=ScriptID            ; ScriptID: 2072
    mov         r3,#0                   ; lastInteracted = NULL
    push        {r4}
    mov         r4,#0                   ; NULL
    bl          SetupScriptEngine       ; SetupScriptEngine(fieldSystem, scriptEnvironment, 2072, NULL, NULL)
    pop         {r4}                    ; r4 = env->taskManager
    mov         r0,#0xd5
    ldr         r1,=Task_RunScripts+1   ; env->exitTaskFunc
    lsl         r0,r0,#0x2
    str         r1,[r4,r0]
    mov         r1,r6                   ; env->exitTaskEnvironment
    add         r0,#0x2c
    str         r1,[r4,r0]
    mov         r0,#12                  ; env->state
    strh        r0,[r4,#0x26]
    pop         {r0-r7,pc}

ItemFieldUseFunc_PKMNBoxLink:
    push        {r0-r7,lr}
    ldr         r0,[r0]                     ; r0 = fieldSystem
    ldr         r1,=ScriptID                ; ScriptID: 2072
    mov         r2,#0                       ; lastInteracted = NULL
    bl          StartMapSceneScript         ; StartMapSceneScript(fieldSystem, ScriptID, NULL)
    pop         {r0-r7,pc}

ItemFieldUseFunc_MedKit:
    push       {r4,r5,r6,lr}
    add        r6,r0,#0x0
    mov        r0,#0xb
    mov        r1,#0x18
    bl         AllocFromHeap
    add        r4,r0,#0x0
    mov        r0,#0x0
    mov        r1,#0x1b
    mov        r2,#0xa
    mov        r3,#0xb
    strh       r0,[r4,#0x16]
    bl         NewMsgDataFromNarc
    add        r5,r0,#0x0
    add        r0,r5,#0x0
    mov        r1,#68
    bl         NewString_ReadMsgData
    str        r0,[r4,#0x10]
    add        r0,r5,#0x0
    bl         DestroyMsgData
    bl         UseMedKit
    ldr        r0,[r6]
    ldr        r1,=0x0206518D
    add        r2,r4,#0x0
    bl         FieldSystem_CreateTask
    mov        r0,#0x0
    pop        {r4,r5,r6,pc}


BagApp_UseItemExpansion:
check_infinite_repel:
	mov     r0, #113 ; =ITEM_INFINITE_REPEL
	cmp     r5, r0
	bne     check_cap_candy
    add     r0,r4,#0x0
    add     r1,r5,#0x0
    bl      BagApp_UseInfiniteRepel
    add     r5,r0,#0x0
    b       used_item
check_cap_candy: ; NOT IMPLEMENTED YET
;    mov     r0, #114 ; =ITEM_CAP_CANDY
;    cmp     r5, r0
;    bne     check_medkit
;    add     r0,r4,#0x0
;    add     r1,r5,#0x0
;    bl      BagApp_UseCapCandy
;    add     r5,r0,#0x0
;    b       used_item
check_medkit:
    mov     r0, #115 ; =ITEM_MEDKIT
    cmp     r5, r0
    bne     return ; if not medkit, return
    add     r0,r4,#0x0
    add     r1,r5,#0x0
    bl      BagApp_UseMedKit
    add     r5,r0,#0x0
    b       used_item
return:
	mov     r0, #0
	pop     {r3, r4, r5, pc} ; return false
used_item:
	bl      0x021fba7a ; call the original function to handle the cleanup after using an item

BagApp_UseInfiniteRepel:
	push    {r3, r4, r5, pc}
	add     r4, r0, #0
	add     r5, r1, #0
	bl      IsRepelOn
	cmp     r0, #0
	bne     _021FBAC4
    bl      UseInfiniteRepel
	mov     r0, #0x2f
	lsl     r0, r0, #4
	ldr     r0, [r4, r0]
	mov     r1, #67
	bl      NewString_ReadMsgData
	pop     {r3, r4, r5, pc}
_021FBAC4:
    bl      UseInfiniteRepel
	mov     r0, #0x2f
	lsl     r0, r0, #4
	ldr     r0, [r4, r0]
	mov     r1, #66
	bl      NewString_ReadMsgData
	pop     {r3, r4, r5, pc}

UseInfiniteRepel:
    push    {r3,r4,r5,lr}
    ldr     r0, =SEQ_SE_DP_CARD2
    bl      PlaySE
    bl      IsRepelOn
    cmp     r0, #0 ; Check if the flag is set
    bne     repel_in_use
    bl      SaveData_Get
    bl      Save_VarsFlags_Get
    ldr     r1, =RepelFlag ; RepelFlag
    bl      Save_VarsFlags_SetFlagInArray
    pop     {r3,r4,r5,pc}
repel_in_use:
    bl      SaveData_Get
    bl      Save_VarsFlags_Get
    ldr     r1, =RepelFlag ; RepelFlag
    bl      Save_VarsFlags_ClearFlagInArray
    pop     {r3,r4,r5,pc}

IsRepelOn:
    push    {r3,r4,r5,lr}
    bl      SaveData_Get
    bl      Save_VarsFlags_Get
    ldr     r1, =RepelFlag ; RepelFlag
    bl      Save_VarsFlags_GetFlagAddr
    ldr     r0, [r0] ; Load the flag value
    pop     {r3,r4,r5,pc}

BagApp_UseMedKit:
	push    {r3, r4, r5, pc}
	add     r4, r0, #0
	add     r5, r1, #0
    bl      UseMedKit
	mov     r0, #0x2f
	lsl     r0, r0, #4
	ldr     r0, [r4, r0]
	mov     r1, #68
	bl      NewString_ReadMsgData ; prints "Party Healed!", you need to add this string to line 68 in file 10
	pop     {r3, r4, r5, pc}

UseMedKit:
    push       {r3,r4,r5,lr}
    ldr        r0, =SEQ_SE_DP_KAIFUKU ; pokemon healed sound effect
    bl         PlaySE
    bl         SaveData_Get
    bl         SaveArray_Party_Get
    add        r4,r0,#0x0
    bl         HealParty
    pop        {r3,r4,r5,pc}


.pool

.ascii "QoLItems_end"

.close