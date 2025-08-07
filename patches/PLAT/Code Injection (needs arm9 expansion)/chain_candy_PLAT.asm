; Chain Rare Candies for Pokémon Platinum (USA) by Yako
; Credit: Kalaay and Mixone for figuring this one out with me, the pokeplatinum team for decompiling the game, Mikelan98 and Nomura for the arm9 expansion 

.nds
.thumb

; External function declarations
Bag_CanRemoveItem equ 0x0207D688
Window_EraseMessageBox equ 0x0200E084
PartyMenu_PrintToWindow32 equ 0x020826E0

INJECT_ADDR equ 0x023C8000

; Open arm9
.ifdef PATCH
.open "arm9.bin", 0x02000000  

; Branch to hook
.org 0x02085ec6

    bl hook

.close
.endif

; Open the synth overlay
.ifdef PREASSEMBLE
.create "temp.bin", 0x023C8000
.elseifdef PATCH
.open "unpacked/synthOverlay/0009", 0x023C8000  ; Open the synth overlay
.endif


.org INJECT_ADDR
.ascii "chain_candy_start"
.align 2
.func hook
    push {r5, lr}
    strb r0,[r1,#0x0]
    cmp r0, #0
    bne exit ; Pokémon is going to evolve, exit the function

    ldr r0, =1444
    add r1, r4, r0 ; r1 = 1444 + r4
    ldr r5, [r1] ; r2 = partyMenu->partyManagementData ; using pokeplatinum names
    ldr r0, [r5, #0x4] ; r0 = partyManagementData->bag
    mov r1, #50        ; Set the item ID for Rare Candy
    mov r2, #1         ; Set the quantity to 1
    mov r3, #12        ; Set the heap id to 12
    bl Bag_CanRemoveItem ; Check if we can remove a Rare Candy from the bag
    cmp r0, #0
    beq exit ; If we can't remove a Rare Candy, exit the function
    mov r1, #50
    mov r0, #36
    add r0, r5
    strh r1, [r0] ; Set the item ID to Rare Candy in the party management data as it may be overwritten when learning a move
    mov r0, r4
    ldr r1, =548
    add r0, r1 ; r0 = &partyMenu->window[34]
    mov r1, #0
    bl Window_EraseMessageBox ; Erase the message box
    mov r0, r4
    mov r1, #32
    mov r2, #1
    bl PartyMenu_PrintToWindow32 ; Print the message "Use on which Pokémon?" to the window
    mov r0, #4
    pop {r5, pc} ; Return to the caller
exit:
    mov r0, #0x20
    pop {r5, pc}
.endfunc
.pool

.close