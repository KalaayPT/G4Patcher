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
; =====================================================================

INJECT_ADDR equ 0x023C8940

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
; This hook replaces CutIn_BuildPokemonSpriteTemplate to always show
; Staravia in the fly cut-in animation instead of the selected Pokemon.
;
; Original function signature:
;   void CutIn_BuildPokemonSpriteTemplate(HMCutIn *cutIn, PokemonSpriteTemplate *spriteTemplate)
;
; Our replacement calls BuildPokemonSpriteTemplate directly with Staravia:
;   void BuildPokemonSpriteTemplate(PokemonSpriteTemplate *spriteTemplate, u16 species,
;                                    u8 gender, u8 face, u8 shiny, u8 form, u32 personality)
; =====================================================================

.align 2
.ascii "staravia_cutin_start"
.align 2

staravia_cutin_hook:
    ; Input: r0 = cutIn (HMCutIn*), r1 = spriteTemplate
    ; We need to check if this is a Fly cut-in (cutIn->_1 == TRUE)
    ; If so, use Staravia. Otherwise, call original Pokemon_BuildSpriteTemplate.
    ;
    ; HMCutIn structure offsets:
    ;   offset 0x20 = _1 (isNotFly, but actually TRUE means IS Fly)
    ;   offset 0x5C = pokemon (Pokemon*)

    push    {r4, r5, lr}                ; Save registers
    mov     r4, r0                      ; r4 = cutIn
    mov     r5, r1                      ; r5 = spriteTemplate

    ; Check if this is a Fly cut-in
    ; cutIn->_1 is at offset 0x20 (32 bytes)
    ldr     r0, [r4, #0x20]             ; r0 = cutIn->_1
    cmp     r0, #TRUE                   ; Is this the Fly animation?
    beq     use_staravia                ; Yes, use Staravia

    ; Not Fly - call original Pokemon_BuildSpriteTemplate with the party Pokemon
    mov     r0, r5                      ; r0 = spriteTemplate
    ldr     r1, [r4, #0x5C]             ; r1 = cutIn->pokemon
    mov     r2, #2                      ; r2 = face = FACE_FRONT
    bl      Pokemon_BuildSpriteTemplate
    pop     {r4, r5, pc}                ; Return

use_staravia:
    ; Fly animation - use Staravia
    ; Call BuildPokemonSpriteTemplate(spriteTemplate, 397, 0, 2, 0, 0, 0)
    mov     r0, r5                      ; r0 = spriteTemplate
    ldr     r1, =SPECIES_STARAVIA       ; r1 = species = 397 (Staravia)
    mov     r2, #0                      ; r2 = gender = 0 (male)
    mov     r3, #2                      ; r3 = face = 2 (FACE_FRONT)

    ; Push remaining args to stack (personality, form, shiny - in reverse order)
    mov     r4, #0                      ; r4 = 0
    push    {r4}                        ; Push personality = 0
    push    {r4}                        ; Push form = 0
    push    {r4}                        ; Push shiny = 0

    bl      BuildPokemonSpriteTemplate

    add     sp, #12                     ; Clean up stack (3 * 4 bytes)
    pop     {r4, r5, pc}                ; Return

    .pool

.ascii "staravia_cutin_end"

.close