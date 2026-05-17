.nds
.thumb

; Wild Boss Battle Patch by Yako

; Credits:
; - The pokeplatinum team for decompiling the game
; - Mikelan and Nomura for the arm9 expansion

; =========================
;        SETTINGS
; =========================

; File paths
ARM9_PATH               equ "arm9.bin"
OVERLAY_14_PATH         equ "overlay/overlay_0014.bin"
OVERLAY_16_PATH         equ "overlay/overlay_0016.bin"
SYNTH_OVERLAY_FILE_ID   equ "0009"
SYNTH_OVERLAY_PATH      equ "unpacked/synthOverlay/" + SYNTH_OVERLAY_FILE_ID

NO_ITEM_FLAG                        equ 2650     ; Flag to indicate no item usage in battles
WILD_BOSS_FLAG                      equ 2651     ; Flag to indicate wild boss battle status (trainer AI + no running)
DISABLE_ITEMS_IN_TRAINER_BATTLES    equ 1        ; Set to 1 to always disallow item usage in trainer battles, 0 to allow unless NO_ITEM_FLAG is set
AFFECT_ROAMERS                      equ 1        ; Automatically apply the same AI changes to roaming Pokémon, giving them good AI when trapped
ESCAPE_FAIL_MSG_ID                  equ 794      ; Message to display when player tries to run from the battle (default: "Can’t escape!\r")

; Bitfield for AI behavior in wild boss battles. 
WILD_BOSS_AI_FLAGS                  equ 0b111
; This corresponds to the following flags:
; Bit 0 (1 << 0): Basic AI
; Bit 1 (1 << 1): Evaluate attack
; Bit 2 (1 << 2): Expert AI
                                                    
; =========================
;      END SETTINGS
; =========================

INJECT_ADDR equ 0x023C8000

; = Function Addresses =

SaveData_Ptr                        equ 0x020245A4
SaveData_GetVarsFlags               equ 0x020507E4
CheckFlag                           equ 0x0206A8EC
BattleSystem_BattleType             equ 0x0223DF0C
BattleSystem_GetBattlerSide         equ 0x0223E208

; =========================

.ifdef PATCH
.open OVERLAY_16_PATH, 0x0223B140
; Disallow item usage in trainer battles and when the wild boss flag is set.
.org 0x0224be98                     ; part of the main battle player input handling
    bl      CheckItemUsageAllowed
    mov     r0, r0                  ; alignment nop
    cmp     r0, #1

.org 0x02260dde                     ; hook in Task_RunBattlerAI, responsible for running the AI for each battler
    bl      Hook_Task_RunBattlerAI
    cmp     r0, #1

.org 0x02255c0c
    bl      Hook_IsBattlerTrapped
.close

.open OVERLAY_14_PATH, 0x0221FC20
.org 0x0221fcc0
    bl      Hook_AI_Init
    cmp     r1, #1
    beq     0x0221fcca
.close
.endif

.ifdef PREASSEMBLE
.create "temp.bin", 0x023C8000
.elseifdef PATCH
.open SYNTH_OVERLAY_PATH, 0x023C8000
.endif

.org INJECT_ADDR
.ascii "WildBossBattle"
.align 2
; Convenience function to check a flag
.func CheckFlagHelper
    push    {r4, r5, lr}
    mov     r4, r0
    bl      SaveData_Ptr
    bl      SaveData_GetVarsFlags
    mov     r1, r4
    bl      CheckFlag
    pop     {r4, r5, pc}
.endfunc
.pool

.align 2
; Function to check if item usage is allowed
.func CheckItemUsageAllowed
    push    {r4, lr}
    mov     r4, r0                      ; Save battle system pointer for later use
    ; Check if NO_ITEM_FLAG is set
    ldr     r0, =NO_ITEM_FLAG
    bl      CheckFlagHelper
    cmp     r0, #1
    beq     @@disallow_items
    
    mov     r0, r4                      ; Restore battle system pointer
    bl      BattleSystem_BattleType
    .if DISABLE_ITEMS_IN_TRAINER_BATTLES
    mov     r1, #0x85                   ; BATTLE_TYPE_NO_ITEMS ( 1 << 7 | 1 << 2 ) | BATTLE_TYPE_TRAINER (1 << 0)
    .else
    mov     r1, #0x84                   ; BATTLE_TYPE_NO_ITEMS ( 1 << 7 | 1 << 2 )
    .endif
    tst     r0, r1
    beq     @@allow_items    

@@disallow_items:
    ; If flag is set, disallow item usage
    mov     r0, #0
    b       @@return

@@allow_items:
    mov     r0, #1
@@return:
    pop     {r4, pc}
.endfunc
.pool

.align 2
.func Hook_Task_RunBattlerAI
    push    {lr}
    bl      BattleSystem_GetBattlerSide
    cmp     r0, #0                      ; Check if the battler is on the player's side (0 = player, 1 = opponent)
    beq     @@run_ai                    ; If it's the player's side, run the AI as normal (this is how the original code works)
    ldr     r0, =WILD_BOSS_FLAG
    bl      CheckFlagHelper
    b       @@return                    ; return the return value of the flag, which will be 1 if it's a wild boss battle, 0 otherwise
@@run_ai:
    mov     r0, #1
@@return:
    pop     {pc}
.endfunc
.pool

.align 2
.func Hook_AI_Init                      
    push    {r4, lr}
    mov     r4, #1
    tst     r4, r1                      ; r1 contains the battle type here
    bne     @@trainer_battle            ; If it's a trainer battle, return 1 in r1 and let the original code handle it
    mov     r0, #0
    lsl     r4, #0x8                    ; r4 = 256 = BATTLE_TYPE_ROAMER
    tst     r4, r1
    beq     @@not_roamer
    lsl     r4, #0x15                   ; r4 = AI_FLAG_ROAMING_POKEMON = 2^29
    mov     r0, r4
    .if AFFECT_ROAMERS == 0
    b       @@return_wild_battle        ; If it's a roaming Pokémon, return now
    .endif
@@not_roamer:
    ldr     r4, =WILD_BOSS_AI_FLAGS
    orr     r0, r4
@@return_wild_battle:
    mov     r1, #0
    pop     {r4, pc}
@@trainer_battle:
    mov     r1, #1
    pop     {r4, pc}
.endfunc
.pool


; r7 = battleSys
; r5 = battleCtx
; r6 = battlerId
; r4 = msgOut
.align 2
.func Hook_IsBattlerTrapped
    push    {lr}
    bl      BattleSystem_GetBattlerSide
    cmp     r0, #0                      ; Check if the battler is on the player's side 
    bne     @@return_to_parent          
    ldr     r0, =WILD_BOSS_FLAG
    bl      CheckFlagHelper
    cmp     r0, #1
    bne     @@return_to_parent
    cmp     r4, #0                      ; Check if msgOut is NULL, if it is we can terminate the parent now
    beq     @@return_true
    mov     r0, #0
    strb    r0, [r4, #0x1]
    ldr     r1, =ESCAPE_FAIL_MSG_ID
    strh    r1, [r4, #0x2]
@@return_true:
    mov     r0, #1
    add     sp, #0x18                   ; clean up lr and the parent function's stack
    pop     {r4-r7, pc}                 ; pop parent's pushed registers and return
@@return_to_parent:
    mov     r0, r7                      ; battleSys
    bl      BattleSystem_BattleType     ; original instruction from parent function
    pop     {pc}
.endfunc
.pool


.close
.notice "Applied"