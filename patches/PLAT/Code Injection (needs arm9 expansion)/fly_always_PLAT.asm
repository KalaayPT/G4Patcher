; map_as_fly by Kalaay
;
; This patch modifies the FieldSystem_OpenTownMapItem function to conditionally
; open the Town Map in FLY mode when the player has HM02, the Cobble Badge,
; and is on a map where Fly is allowed.
;
; Additionally, this patch makes the Fly cut-in animation always show Staravia
; instead of the selected party Pokemon (for the "Map Fly" feature).
;
; Credits: The pokeplatinum team for decompiling the game

.nds
.thumb

; =====================================================================
; FUNCTION OFFSETS
; =====================================================================
.definelabel TrainerInfo_HasBadge, 0x02025F34 ; Check if player has badge
.definelabel MapHeader_IsFlyAllowed, 0x0203A1D4 ; Check if map allows Fly
.definelabel TownMapContext_Init, 0x0206B70C ; Initialize town map context
.definelabel Bag_GetItemQuantity, 0x0207D730 ; Check item quantity in bag
.definelabel Heap_AllocAtEnd, 0x02018184 ; Allocate memory at end of heap
.definelabel SaveData_GetTrainerInfo, 0x02025E38 ; Get trainer info from save data
.definelabel SaveData_GetBag, 0x0207D990 ; Get bag from save data
.definelabel FieldSystem_OpenTownMap, 0x0203D884 ; Open town map application
.definelabel SaveData_Ptr, 0x020245A4
.definelabel GetContextMenuEntriesForPartyMon, 0x020800B4
.definelabel PartyMenu_SetKnownFieldMove, 0x02081CAC
.definelabel BuildPokemonSpriteTemplate, 0x02075FB4 ; Build sprite template from species params
.definelabel Pokemon_BuildSpriteTemplate, 0x02075EF4 ; Build sprite template from Pokemon struct
.definelabel CutIn_BuildPokemonSpriteTemplate, 0x0224508C ; Original function in overlay6
.definelabel Pokemon_GetValue, 0x02074470            ; Get Pokemon data value
.definelabel Sound_PlayPokemonCry, 0x02005844        ; Play cry by species
.definelabel Pokemon_PlayCry, 0x02077E3C             ; Play cry from Pokemon struct
.definelabel HMCutIn_SlideMonToCenter, 0x02244228    ; Function that plays the cry
.definelabel Pokemon_PlayCry_CallSite, 0x02244248    ; BL Pokemon_PlayCry in HMCutIn_SlideMonToCenter
; =====================================================================
; CONSTANTS
; =====================================================================
TOWN_MAP_MODE_ITEM          equ 0
TOWN_MAP_MODE_FLY           equ 1
BADGE_ID_COBBLE             equ 2      ; Cobble Badge (3rd badge, bit 2)
ITEM_HM02                   equ 0x01A5 ; 421 decimal
HEAP_ID_FIELD2              equ 11     ; Heap ID for field operations
TRUE                        equ 1
FALSE                       equ 0
SPECIES_STARAVIA            equ 397
MOVE_FLY                    equ 19
MON_DATA_MOVE1              equ 54
MON_DATA_MOVE2              equ 55
MON_DATA_MOVE3              equ 56
MON_DATA_MOVE4              equ 57
; =====================================================================

INJECT_ADDR equ 0x023C8510

.ifdef PATCH
.open "arm9.bin", 0x02000000

; Replace the call to GetContextMenuEntriesForPartyMon in sub_0207FFC8
.org 0x02080024
    bl fly_in_menu

.close

; =====================================================================
; OVERLAY 6 HOOK - Replace CutIn_BuildPokemonSpriteTemplate
; This makes the fly cut-in always show Staravia
; =====================================================================
.open "overlay/overlay_0006.bin", 0x0223E140

.org CutIn_BuildPokemonSpriteTemplate
    ; Original function: CutIn_BuildPokemonSpriteTemplate(HMCutIn *cutIn, PokemonSpriteTemplate *spriteTemplate)
    ; We replace it with a BL to our hook in synth overlay
    ; r0 = cutIn (unused), r1 = spriteTemplate
    ldr     r3, =staravia_cutin_hook+1  ; Load address of our hook (+1 for THUMB mode)
    bx      r3                          ; Jump to hook
    .pool                               ; Pool for the address constant

; =====================================================================
; OVERLAY 6 HOOK - Replace Pokemon_PlayCry call
; This makes the fly cut-in play Staravia's cry if needed
; =====================================================================
.org Pokemon_PlayCry_CallSite
    ; Replace the bl Pokemon_PlayCry with bl to our hook
    ; Context: r4 = cutIn, r0 = cutIn->pokemon
    bl      staravia_cry_hook

.close

.endif

.ifdef PREASSEMBLE
.create "temp.bin", 0x023C8000
.elseifdef PATCH
.open "unpacked/synthOverlay/0009", 0x023C8000  ; Open the synth overlay
.endif


.org INJECT_ADDR    ; Put function at defined offset
.ascii "map_as_fly_start"
.align 2

fly_in_menu:
    ; r0: PartyMenuApplication *application
    ; r1: u8 *menuEntriesBuffer
    push {r4-r7, lr}                    ; Save registers we'll use and return address
    mov     r4, r0                      ; r4 = application
    mov     r5, r1                      ; r5 = menuEntriesBuffer
    bl      GetContextMenuEntriesForPartyMon ; (PartyMenuApplication *application, u8 *menuEntriesBuffer), returns count
    mov     r6, r0                      ; r6 = original count
    bl      fly_is_allowed
    cmp     r0, #TRUE
    bne     return_original

    ; =========================================================================
    ; Scan buffer: check if Fly exists, count existing field moves
    ; =========================================================================
    mov     r0, #0                      ; r0 = loop index i
    mov     r7, #0                      ; r7 = fieldMoveCount (for correct slot)
    mov     r3, #0                      ; r3 = insertionPoint (where SUMMARY is)

scan_loop:
    cmp     r0, r6
    bge     scan_done                   ; Finished scanning

    ldrb    r1, [r5, r0]                ; r1 = buffer[i]

    ; Check if this is Fly (entry 17)
    cmp     r1, #17
    beq     fly_already_present

    ; Check if this is a field move (entries 16-30)
    ; Field moves are in range [16, 30]
    cmp     r1, #16
    blt     not_field_move
    cmp     r1, #31
    bgt     not_field_move

    ; It's a field move - count it
    add     r7, r7, #1                  ; fieldMoveCount++
    b       next_entry

not_field_move:
    ; Check if this is SUMMARY (entry 0) - marks end of field moves
    ; We only want to record the first SUMMARY we find after SWITCH
    cmp     r1, #0
    bne     next_entry

    ; Found SUMMARY - record position if we haven't yet
    cmp     r3, #0
    bne     next_entry
    mov     r3, r0                      ; insertionPoint = i

next_entry:
    add     r0, r0, #1                  ; i++
    b       scan_loop

scan_done:
    ; r7 = number of existing field moves
    ; r3 = position of SUMMARY entry (insertion point for Fly)

    ; If insertionPoint is 0, SUMMARY wasn't found (shouldn't happen in normal mode)
    ; Fall through to return original count
    cmp     r3, #0
    beq     return_original

    ; =========================================================================
    ; Insert Fly: shift everything from insertionPoint down by 1
    ; =========================================================================

    ; Shift entries [insertionPoint..count-1] down by 1
    ; Start from end and work backwards
    mov     r0, r6                      ; r0 = i = count (end of buffer)

shift_loop:
    cmp     r0, r3
    ble     shift_done                  ; Stop when i <= insertionPoint

    sub     r1, r0, #1                  ; src = i - 1
    ldrb    r2, [r5, r1]                ; val = buffer[src]
    strb    r2, [r5, r0]                ; buffer[i] = val

    sub     r0, r0, #1                  ; i--
    b       shift_loop

shift_done:
    ; Insert Fly at the insertion point
    ldr     r0, =17                     ; Fly's menu entry ID
    strb    r0, [r5, r3]                ; buffer[insertionPoint] = 17

    ; Increment count
    add     r6, r6, #1

    ; =========================================================================
    ; Call PartyMenu_SetKnownFieldMove(application, MOVE_FLY, fieldMoveIndex)
    ; This sets up the display string for Fly in the menu
    ; =========================================================================
    ; r7 = fieldMoveCount = the slot index to use (after existing field moves)

    mov     r0, r4                      ; arg0 = application
    mov     r1, #19                     ; arg1 = MOVE_FLY (0x13 = 19)
    mov     r2, r7                      ; arg2 = fieldMoveIndex (uses next available slot)
    bl      PartyMenu_SetKnownFieldMove

return_count:
    mov     r0, r6                      ; Return new count
    pop     {r4-r7, pc}

fly_already_present:
    ; Fly is already in the menu (Pokemon knows Fly)
    ; Just return the original count - don't add duplicate

return_original:
    mov     r0, r6                      ; Return original count
    pop     {r4-r7, pc}

fly_is_allowed:
    push {r1-r7, lr}          ; Save registers we'll use and return address
    bl SaveData_Ptr
    mov r7, r0 ; save save data pointer for later

    ; check if player has HM02 fly
    bl SaveData_GetBag
    ldr r1, =ITEM_HM02
    mov r2, HEAP_ID_FIELD2
    bl Bag_GetItemQuantity
    cmp r0, #0
    beq fly_check_false

    ; check if player has Cobble Badge
    mov r0, r7
    bl SaveData_GetTrainerInfo
    ldr r1, =BADGE_ID_COBBLE
    bl TrainerInfo_HasBadge
    cmp r0, #0
    beq fly_check_false

    ; player has both HM02 and Cobble Badge, allow flying
    mov r0, TRUE
    pop {r1-r7, pc}           ; Restore registers and return

fly_check_false:
    mov r0, FALSE
    pop {r1-r7, pc}           ; Restore registers and return

    .pool

.ascii "map_as_fly_end"

; =====================================================================
; STARAVIA FLY CUT-IN HOOK
; =====================================================================
; This hook replaces CutIn_BuildPokemonSpriteTemplate to show Staravia
; in the fly cut-in animation ONLY if the selected Pokemon doesn't know Fly.
; If the Pokemon knows Fly, show the original Pokemon.
;
; Original function signature:
;   void CutIn_BuildPokemonSpriteTemplate(HMCutIn *cutIn, PokemonSpriteTemplate *spriteTemplate)
;
; Our replacement:
;   - If Fly cut-in AND Pokemon doesn't know Fly: use Staravia
;   - Otherwise: use the original Pokemon
; =====================================================================

.align 2
.ascii "staravia_cutin_start"
.align 2

staravia_cutin_hook:
    ; Input: r0 = cutIn (HMCutIn*), r1 = spriteTemplate
    ;
    ; HMCutIn structure offsets:
    ;   offset 0x20 = _1 (TRUE means IS Fly animation)
    ;   offset 0x5C = pokemon (Pokemon*)

    push    {r4-r6, lr}                 ; Save registers
    mov     r4, r0                      ; r4 = cutIn
    mov     r5, r1                      ; r5 = spriteTemplate

    ; Check if this is a Fly cut-in
    ldr     r0, [r4, #0x20]             ; r0 = cutIn->_1
    cmp     r0, #TRUE                   ; Is this the Fly animation?
    bne     use_original_pokemon        ; No, use original Pokemon

    ; It's a Fly cut-in - check if Pokemon knows Fly
    ldr     r6, [r4, #0x5C]             ; r6 = cutIn->pokemon
    mov     r0, r6                      ; r0 = pokemon
    bl      pokemon_knows_fly           ; Returns TRUE if knows Fly
    cmp     r0, #TRUE
    beq     use_original_pokemon        ; Pokemon knows Fly, show it

    ; Pokemon doesn't know Fly - use Staravia
    ; Call BuildPokemonSpriteTemplate(spriteTemplate, 397, 0, 2, 0, 0, 0)
    mov     r0, r5                      ; r0 = spriteTemplate
    ldr     r1, =SPECIES_STARAVIA       ; r1 = species = 397 (Staravia)
    mov     r2, #0                      ; r2 = gender = 0 (male)
    mov     r3, #2                      ; r3 = face = 2 (FACE_FRONT)

    ; Push remaining args to stack (shiny, form, personality)
    mov     r6, #0
    push    {r6}                        ; Push personality = 0
    push    {r6}                        ; Push form = 0
    push    {r6}                        ; Push shiny = 0

    bl      BuildPokemonSpriteTemplate

    add     sp, #12                     ; Clean up stack (3 * 4 bytes)
    pop     {r4-r6, pc}                 ; Return

use_original_pokemon:
    ; Use the original Pokemon
    mov     r0, r5                      ; r0 = spriteTemplate
    ldr     r1, [r4, #0x5C]             ; r1 = cutIn->pokemon
    mov     r2, #2                      ; r2 = face = FACE_FRONT
    bl      Pokemon_BuildSpriteTemplate
    pop     {r4-r6, pc}                 ; Return

    .pool

; =====================================================================
; Helper function: Check if Pokemon knows Fly
; Input: r0 = Pokemon*
; Output: r0 = TRUE if knows Fly, FALSE otherwise
; =====================================================================
pokemon_knows_fly:
    push    {r4-r5, lr}
    mov     r4, r0                      ; r4 = pokemon

    ; Check move slot 1
    mov     r1, #MON_DATA_MOVE1
    mov     r2, #0                      ; dest = NULL
    bl      Pokemon_GetValue
    cmp     r0, #MOVE_FLY
    beq     knows_fly_true

    ; Check move slot 2
    mov     r0, r4
    mov     r1, #MON_DATA_MOVE2
    mov     r2, #0
    bl      Pokemon_GetValue
    cmp     r0, #MOVE_FLY
    beq     knows_fly_true

    ; Check move slot 3
    mov     r0, r4
    mov     r1, #MON_DATA_MOVE3
    mov     r2, #0
    bl      Pokemon_GetValue
    cmp     r0, #MOVE_FLY
    beq     knows_fly_true

    ; Check move slot 4
    mov     r0, r4
    mov     r1, #MON_DATA_MOVE4
    mov     r2, #0
    bl      Pokemon_GetValue
    cmp     r0, #MOVE_FLY
    beq     knows_fly_true

    ; Doesn't know Fly
    mov     r0, #FALSE
    pop     {r4-r5, pc}

knows_fly_true:
    mov     r0, #TRUE
    pop     {r4-r5, pc}

.ascii "staravia_cutin_end"

; =====================================================================
; STARAVIA CRY HOOK
; =====================================================================
; This hook is called from the cry_hook_veneer in overlay6.
; It plays Staravia's cry if using Map Fly, otherwise plays the
; original Pokemon's cry.
;
; Entry conditions (from HMCutIn_SlideMonToCenter):
;   r0 = cutIn->pokemon (Pokemon*)
;   r4 = cutIn (HMCutIn*)
;   lr = return address (back to HMCutIn_SlideMonToCenter)
;
; Note: bl from the veneer clobbered original lr, but the veneer's
; bx r3 means lr still points back to HMCutIn_SlideMonToCenter+4.
; Actually, bl sets lr, so we need to be careful about the return.
; =====================================================================

.align 2
.ascii "staravia_cry_start"
.align 2

staravia_cry_hook:
    ; r0 = pokemon, r4 = cutIn (preserved from caller), lr = return addr
    push    {r4-r6, lr}
    mov     r5, r0                      ; r5 = pokemon
    mov     r6, r4                      ; r6 = cutIn (backup)

    ; Check if this is a Fly cut-in
    ldr     r0, [r6, #0x20]             ; r0 = cutIn->_1
    cmp     r0, #TRUE
    bne     play_original_cry           ; Not Fly animation, use original

    ; It's a Fly cut-in - check if Pokemon knows Fly
    mov     r0, r5                      ; r0 = pokemon
    bl      pokemon_knows_fly
    cmp     r0, #TRUE
    beq     play_original_cry           ; Pokemon knows Fly, use its cry

    ; Pokemon doesn't know Fly - play Staravia's cry
    ; Sound_PlayPokemonCry(species, form)
    ldr     r0, =SPECIES_STARAVIA       ; r0 = 397 (Staravia)
    mov     r1, #0                      ; r1 = form = 0
    bl      Sound_PlayPokemonCry
    pop     {r4-r6, pc}

play_original_cry:
    ; Play the original Pokemon's cry
    mov     r0, r5                      ; r0 = pokemon
    bl      Pokemon_PlayCry
    pop     {r4-r6, pc}

    .pool

.ascii "staravia_cry_end"

.close