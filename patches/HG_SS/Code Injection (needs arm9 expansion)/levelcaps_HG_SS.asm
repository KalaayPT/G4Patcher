;
;	LEVEL CAP PATCH FOR POKEMON HEARTGOLD/SOULSILVER
;			original Platinum concept by Memory5ty7
;           adapted for HGSS by Kalaay
;	 	  Please credit if used
;

; 		INSTALLATION
;
; - Modify the VarNum variable below to match your DSPRE settings
; - Modify the game scripts using DSPRE to set the selected variable to the level cap you want (the levelcap is 0 by default)
;
; - If the patch doesnt work, DM me on Discord (Kalaay) or join the Kingdom of DS hacking Discord Server (https://discord.gg/zAtqJDW2jC) for help
;

;  	    CONFIGURATION

	VarNum equ 0x4156 							; Variable used for the level cap

;		LIMITATIONS
;
; - when trying to apply a rare candy at level cap, the level doesnt increase but the candy gets used anyways. make sure to consider that.
;

; 	START OF CUSTOM CODE - DO NOT MODIFY UNLESS YOU KNOW WHAT YOU ARE DOING

.nds
.thumb

; GetItemAttr_PreloadedItemData in HGSS
Item_Get equ 0x02077DAC
; GetMonData in HGSS
Pokemon_GetValue equ 0x0206E540
Heap_Free equ 0x0201AB0C
; SaveData_Get in HGSS
SaveData_Ptr equ 0x020272B0
; Save_VarsFlags_Get in HGSS
SaveData_GetVarsFlags equ 0x020503D0
; Save_VarsFlags_GetVarAddr in HGSS
VarsFlags_GetVarAddress	equ 0x020504A4

INJECT_ADDR equ 0x023C8E30

.ifdef PATCH
.open "arm9.bin", 0x02000000

.org 0x02090438		; Rare Candy repoint, hooks into UseItemOnPokemon

	bl candycheck
	
;.fill 34,0x0

.close

.open "overlay/overlay_0012.bin", 0x022378C0

.org 0x2245A2C		; In-Battle EXP repoint, hooks into Task_GetExp

	bl inbattlecheck
	
.close
.endif

.ifdef PREASSEMBLE
.create "temp.bin", 0x023C8000
.elseifdef PATCH
.open "unpacked/synthOverlay/0000", 0x023C8000
.endif


.org INJECT_ADDR
.ascii "LevelCaps_start"
.align 2

inbattlecheck:
    push {r0}
    bl getlevelcap
    mov r1, r0
    pop {r0}
    cmp r0, r1
    blt end
    bl #0x2245A30
    blt end

end:
	bl #0x2245A32

candycheck:
	push {r0}
	bl getlevelcap
	mov r1, r0
	pop {r0}
	cmp r0, r1
	bge end2

	bl 0x0209043c

end2:
	bl 0x02090474

getlevelcap:
	push {r3-r7,lr}
	bl getscriptvar

getscriptvar:
	bl SaveData_Ptr
	bl SaveData_GetVarsFlags
	ldr r1, =VarNum
	bl VarsFlags_GetVarAddress
	ldrh r0, [r0]
	pop {r3-r7,pc}

.pool
.align 4

;cap_set:
;   .ascii "LevelCaps_apply"
;   .byte 0x00 ; end of string
;
;cap_unset:
;   .ascii "LevelCaps_dontapply"
;   .byte 0x00 ; end of string
;
;debug:
;    .ascii "LevelCaps_debug"
;    .byte 0x00 ; end of string

.ascii "LevelCaps_end"

.close

;  END OF CUSTOM CODE