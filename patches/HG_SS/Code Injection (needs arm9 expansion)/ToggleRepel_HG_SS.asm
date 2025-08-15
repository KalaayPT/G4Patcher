; ToggleRepel_HG_SS.asm
; toggles the repel depending on a flag
; if toggle repel is off, preserves standard repel behavior for those hard of reading

.nds
.thumb

; Settings:
RepelFlag equ 0x416F ; (Flag ID, Hexadecimal)

; ------------------------------------------------------------------------------------
; DO NOT EDIT BELOW HERE UNLESS YOU KNOW WHAT YOURE DOING
; ------------------------------------------------------------------------------------

SaveData_Get equ 0x020272B0
Save_VarsFlags_GetFlagAddr equ 0x0205045C
Save_VarsFlags_Get equ 0x020503D0
Save_VarsFlags_GetVarAddr equ 0x020504A4


INJECT_ADDR equ 0x023C8000

; ------- Inject hook into arm9.bin -------
.ifdef PATCH
.open "arm9.bin", 0x02000000

.org 0x0202DB08 ; RoamerSave_RepelNotInUse
    push    {lr}
    bl      ToggleRepel
    pop     {pc}

.close
.endif

; ------- Write function to synthOverlay 0000 -------
.ifdef PREASSEMBLE
.create "temp.bin", 0x023C8000
.elseifdef PATCH
.open "unpacked/synthOverlay/0000", 0x023C8000
.endif


.org INJECT_ADDR
.ascii "ToggleRepel_start"
.align 2

ToggleRepel:
    push    {lr}
    push    {r0}                        ; probably not necessary but cba to confirm
    bl      SaveData_Get
    bl      Save_VarsFlags_Get
	ldr     r1, =RepelFlag
	bl      Save_VarsFlags_GetFlagAddr
	ldr     r0, [r0]                    ; Load the flag value
    cmp     r0, #0                      ; Check if the flag is set
    beq     normal_repel
    pop     {r0}                        ; Restore the pointer
    mov     r0, #0                      ; If set, return false: repel in use
    pop     {pc}                        ; Return

normal_repel:                           ; can probably be reduced to a bl back into the function
    pop     {r0}                        ; Restore the pointer
    add     r0,#0x65
    ldrb    r0,[r0,#0x0 ]
    cmp     r0,#0x0
    bne     LAB_0202db14
    mov     r0,#0x1
    pop     {pc}                        ; Return
LAB_0202db14:
    mov     r0,#0x0
    pop     {pc}                        ; Return

.pool

end:
.ascii "ToggleRepel_end"

.close