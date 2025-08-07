; ButtonScript_PLAT.asm

.nds
.thumb

; Settings:
PressedButton equ StartButton
ScriptID equ 2058 ; (Commonscript ID)
; ------------------------------------------------------------------------------------
; DO NOT EDIT BELOW HERE UNLESS YOU KNOW WHAT YOURE DOING
; ------------------------------------------------------------------------------------

; Button definitions:
AButton equ 1
BButton equ 2
SelectButton equ 4
StartButton equ 8
DPadRight equ 16
DPadLeft equ 32 ; i am not sure about the exact orientations of the DPad, but it wouldn't be advisable to use them anyway
DPadUp equ 64
DPadDown equ 128
RButton equ 256
LButton equ 512
XButton equ 1024

INJECT_ADDR equ 0x023C8000

; ------- Inject hook into arm9.bin -------
.ifdef PATCH
.open "overlay/overlay_0005.bin", 0x021D0D80

.org 0x021D20CC

    add r1, r4, #0
    bl PortaPC

.close
.endif


; ------- Write function to synthOverlay 0009 -------
.ifdef PREASSEMBLE
.create "temp.bin", 0x023C8000
.elseifdef PATCH
.open "unpacked/synthOverlay/0009", 0x023C8000
.endif


.org INJECT_ADDR
.ascii "ButtonScript_start"

PortaPC:
    add  r4, r1, #0         ; putting fieldSystem back into r4

    ldr  r3, =0x021BF67C    ; r3 = gSystem
    ldr  r2, [r3, #0x48]    ; r2 = gSystem->newKeys
    ldr r3, =PressedButton  ; Button bitmask
    tst  r2, r3             ; check if pressed
    bne  call_script

    add sp, #0x10
    mov r0, #0
    pop  {r3, r4, r5, r6, r7, pc}

call_script:

    add r0, r4, #0
    ldr r1, =ScriptID       ; ScriptID: 2058 (default)
    mov r2, #0              ; MapObject = NULL
    bl 0x0203E880           ; ScriptManager_Set(fieldSystem, 2058, NULL)

    add sp, #0x10
    mov r0, #1
    pop  {r3, r4, r5, r6, r7, pc}

.pool

.ascii "ButtonScript_end"

.close