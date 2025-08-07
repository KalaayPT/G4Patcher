;
;	LEVEL CAP PATCH FOR POKEMON PLATINUM
;			made by Memory5ty7
;	 	  Please credit if used
;

; 		INSTALLATION
;
; - Modify the VarNum variable below to match your DSPRE settings
; - Modify the game scripts using DSPRE to set the selected variable to the level cap you want (the levelcap is 0 by default)
;
; - If the patch doesnt work, DM me on Discord (memory5ty7) or join my Discord Server (http://discord.gg/9VQTJEyVZu) for help
;

;  	    CONFIGURATION

	VarNum equ 16422 							; Variable used for the level cap

;		CREDITS
;
;	PokePlat (JimB16) 		: Unfinished disassembly of Pokemon Platinum
;	hg-engine (various) 	: Research on variables and level caps
;	BluRose, Lhea			: ASM Explanations
;	Kingdom of DS Hacking	: Gold Mine of useful information about Pokémon Rom Hacking
;

; 	START OF CUSTOM CODE - DO NOT MODIFY UNLESS YOU KNOW WHAT YOU ARE DOING

.nds
.thumb

INJECT_ADDR equ 0x023C8B20

.ifdef PATCH
.open "arm9.bin", 0x02000000

.org 0x2096558		; Rare Candy repoint

	bl candycheck
	
.fill 34,0x0

.close

.open "overlay/overlay_0016.bin", 0x0223B140

.org 0x2249008		; In-Battle EXP repoint

	bl inbattlecheck
	
.close
.endif

.ifdef PREASSEMBLE
.create "temp.bin", 0x023C8000
.elseifdef PATCH
.open "unpacked/synthOverlay/0009", 0x023C8000
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
    bl #0x224900c
    blt end
	
end:
	bl #0x224900e
		
candycheck:
	add r0, r4, #0
	mov r1, #0x19
	bl 0x207d014
	cmp r0, #0
	beq end2
	add r0, r6, #0
	mov r1, #0xa1
	mov r2, #0
	bl 0x2074470
	
	push {r0}
	bl getlevelcap
	mov r3, r0
	pop {r0}
	cmp r0, r3
	bhs end2
		
	add r0, r4, #0
	bl 0x20181c4
	add sp, #0x18
	mov r0, #1
	pop {r3, r4, r5, r6, r7, pc}

end2:
	bl 0x209657e

end3:
	pop {r0-r2}
	bl 0x209657e	
	
getlevelcap:
	push {r3-r7,lr}
	bl getscriptvar
	pop {r3-r7,pc}
	
getscriptvar:
	bl 0x020245a4
	bl 0x020507E4
	ldr r1, =VarNum
	bl 0x020508B8
	ldrh r0, [r0]
	pop {r3-r7,pc}
	
.pool

.ascii "LevelCaps_end"

.close

;  END OF CUSTOM CODE