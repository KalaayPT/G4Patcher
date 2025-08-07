; ButtonScript_HG_SS.asm

.nds
.thumb


; Settings:
PressedButton equ StartButton
ScriptID equ 2072 ; (Commonscript ID)
; ------------------------------------------------------------------------------------
; DO NOT EDIT BELOW HERE UNLESS YOU KNOW WHAT YOURE DOING
; ------------------------------------------------------------------------------------

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
.open "overlay/overlay_0001.bin", 0x021E5900

.org 0x021E6D9E

    add r1, r4, #0
    bl PortaPC

.close
.endif

; ------- Write function to synthOverlay 0000 -------
.ifdef PREASSEMBLE
.create "temp.bin", 0x023C8000
.elseifdef PATCH
.open "unpacked/synthOverlay/0000", 0x023C8000
.endif


.org INJECT_ADDR
.ascii "ButtonScript_start"

PortaPC:
    push {r3, r4, r5, r6, r7, lr}

        add  r4, r1, #0         ; putting fieldSystem back into r4
        ; these next two are both overwritten instructions that we have to copy over
        lsl r0, r0, #23
        lsr r0, r0, #31
        beq  end_rel

        ; Access gSystem->newKeys
        ldr  r3, =0x021D110C    ; r3 = gSystem
        ldr  r2, [r3, #0x48]    ; r2 = gSystem->newKeys
        ldr r3, =PressedButton    ; Button bitmask
        tst  r2, r3             ; check if pressed
        bne  call_script
        pop  {r3, r4, r5, r6, r7, pc}

    call_script:
        add r0, r4, #0
        ldr r1, =ScriptID       ; ScriptID: 2072
        mov r2, #0              ; lastInteracted = NULL
        bl 0x0203FE74           ; StartMapSceneScript(fieldSystem, 2072, NULL)
        pop  {r3, r4, r5, r6, r7, pc}

    end_rel:
        mov r0, #0
        pop  {r3, r4, r5, r6, r7, pc}

.pool

.ascii "ButtonScript_end"

.close