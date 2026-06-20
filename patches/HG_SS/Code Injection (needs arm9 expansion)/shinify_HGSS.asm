; turn any pokemon in the party shiny
; research by AdAstra, G4P adaptation by Kalaay
; replaces script command 612, as it is ununsed and already takes one argument

.nds
.thumb

.definethumblabel ScriptReadHalfword, 0x0203FE2C
.definethumblabel FieldSystem_VarGet, 0x020403AC
.definethumblabel SaveArray_Party_Get, 0x02074904
.definethumblabel Party_GetMonByIndex, 0x02074644
.definethumblabel GetMonData, 0x0206E540
.definethumblabel GenerateShinyPersonality, 0x02070094
.definethumblabel SetMonPersonality, 0x0207235C

INJECT_ADDR equ 0x023C8000
.ifdef PATCH
.open "arm9/arm9.bin", 0x02000000  ; Open arm9.bin

.org 0x020fb690 ; Overwrite pointer in scrcmd replacing GetNPCTradeUnusedFlag (CMD_612)
    .word shinify + 1 ; Pointer to the function in the synth overlay

.close
.endif

.ifdef PREASSEMBLE
.create "temp.bin", 0x023C8000
.elseifdef PATCH
.open "unpacked/synthOverlay/0000", 0x023C8000  ; Open the synth overlay
.endif


.org INJECT_ADDR

.ascii "shinify_start"
.align 2
shinify:
push {r3-r5, lr}

mov r5, r0

bl  ScriptReadHalfword         ; read u16 from script data
mov r1, r0
mov r0, r5
add r0, #0x80
ldr r0, [r0]
bl  FieldSystem_VarGet         ; flex disambiguator

add r5, #0x80
mov r4, r0

ldr r0, [r5]
ldr r0, [r0, #0xc]
bl  SaveArray_Party_Get         ; get party
mov r1, r4
bl  Party_GetMonByIndex         ; get mon by index
mov r4, r0

mov r1, #7
mov r2, #0
bl  GetMonData                  ; get mon parameter
bl  GenerateShinyPersonality    ; generate shiny personality

mov r1, r0
mov r0, r4
bl  SetMonPersonality           ; apply personality

mov r0, #0
pop {r3-r5, pc}

.pool

.ascii "shinify_end"

.close