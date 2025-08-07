; EVIV_PLAT.asm
; EV+IV checker by Kalaay,
;
; hooks into both the HandleInput_Main function of the Pokemon Summary and the SetMonDataFromMon function to
; allow toggling between EV, IV, and Stats modes in the summary screen.
; The hook in the HandleInput_Main function allows toggling the mode by pressing R,
; while the hook in SetMonDataFromMon updates the IDs displayed based on the current mode.

.nds
.thumb

AButton equ 1
BButton equ 2
SelectButton equ 4
StartButton equ 8
DPadRight equ 16
DPadLeft equ 32 ; i am not sure about the exact orientations of the DPad
DPadUp equ 64
DPadDown equ 128
RButton equ 256
LButton equ 512
XButton equ 1024
INJECT_ADDR equ 0x023C8000


; ------- Inject hook into arm9.bin -------
.ifdef PATCH
.open "arm9.bin", 0x02000000

.org 0x0208ca34

    bl EV_IV_Viewer     ; HandleInput_Main function

.org 0x0208d3b2

    bl check_current_mode ; SetMonDataFromMon function, hook into stat fetching

.close
.endif

; ------- Write function to synthOverlay 0009 -------
.ifdef PREASSEMBLE
.create "temp.bin", 0x023C8000
.elseifdef PATCH
.open "unpacked/synthOverlay/0009", 0x023C8000
.endif


.org INJECT_ADDR
.ascii "EV+IV_Viewer_start"

; ------- Check for button press and refresh screen -------
EV_IV_Viewer:
    push    {r0} ; Save registers
    ldr     r1, =RButton
    tst     r1, r5
    beq     return     ; if R is not clicked, branch to normal_return
    ldr     r0, =stats
    ldrb    r1, [r0]
    cmp     r1, #0x2
    beq     set_zero
    add     r1, r1, #1 ; Increment stats value
    strb    r1, [r0]   ; Store incremented value back to stats
    b       refresh_screen

set_zero:
    mov     r0, #0x0
    ldr     r1, =stats
    strb    r0, [r1]

refresh_screen:
    pop     {r0}
    mov     r1,  #0x0
    bl      0x0208db10 ; ChangeSummaryMon(summaryScreen, 0) ; refreshes the summary screen
    mov     r0,  #0x2
    pop     {r4, r5, r6, pc}

return:
    pop     {r0} ; Restore r0
    mov     r1,#0x10
    tst     r1, r5
    bx      lr

; ------- Check current mode and write IDs -------
check_current_mode:
    mov     r2, r0 ; Save context pointer
    mov     r0, lr
    mov     r1, #0x4C
    add     r0, r0, r1 ; move context pointer up to skip the instructions we replace
    push    {r0}

    ; Load current byte at 0x0208d3b6 to determine mode
    ldr     r0, =stats
    ldrb    r1, [r0]
    mov     r0, r2 ; Restore context pointer

    ; Check if it's IV mode, write EV IDs
    cmp     r1, #2
    beq     write_ev_ids

    ; Check if it's Stats mode, write IV IDs
    cmp     r1, #1
    beq     write_iv_ids

    ; Default: start with Stats mode
    b       write_stats_ids

write_ev_ids:
    str        r0,[r5,#0x20 ]
    add        r0,r6,#0x0
    mov        r1,#13
    mov        r2,#0x0
    bl         0x02074470
    strh       r0,[r5,#0x24 ]
    add        r0,r6,#0x0
    mov        r1,#13
    mov        r2,#0x0
    bl         0x02074470
    strh       r0,[r5,#0x26 ]
    add        r0,r6,#0x0
    mov        r1,#14
    mov        r2,#0x0
    bl         0x02074470
    strh       r0,[r5,#0x28 ]
    add        r0,r6,#0x0
    mov        r1,#15
    mov        r2,#0x0
    bl         0x02074470
    strh       r0,[r5,#0x2a ]
    add        r0,r6,#0x0
    mov        r1,#17
    mov        r2,#0x0
    bl         0x02074470
    strh       r0,[r5,#0x2c ]
    add        r0,r6,#0x0
    mov        r1,#18
    mov        r2,#0x0
    bl         0x02074470
    strh       r0,[r5,#0x2e ]
    add        r0,r6,#0x0
    mov        r1,#16
    mov        r2,#0x0
    b          normal_return

write_iv_ids:
    str        r0,[r5,#0x20 ]
    add        r0,r6,#0x0
    mov        r1,#70
    mov        r2,#0x0
    bl         0x02074470
    strh       r0,[r5,#0x24 ]
    add        r0,r6,#0x0
    mov        r1,#70
    mov        r2,#0x0
    bl         0x02074470
    strh       r0,[r5,#0x26 ]
    add        r0,r6,#0x0
    mov        r1,#71
    mov        r2,#0x0
    bl         0x02074470
    strh       r0,[r5,#0x28 ]
    add        r0,r6,#0x0
    mov        r1,#72
    mov        r2,#0x0
    bl         0x02074470
    strh       r0,[r5,#0x2a ]
    add        r0,r6,#0x0
    mov        r1,#74
    mov        r2,#0x0
    bl         0x02074470
    strh       r0,[r5,#0x2c ]
    add        r0,r6,#0x0
    mov        r1,#75
    mov        r2,#0x0
    bl         0x02074470
    strh       r0,[r5,#0x2e ]
    add        r0,r6,#0x0
    mov        r1,#73
    mov        r2,#0x0
    b          normal_return

write_stats_ids:
    str        r0,[r5,#0x20 ]
    add        r0,r6,#0x0
    mov        r1,#0xa3
    mov        r2,#0x0
    bl         0x02074470
    strh       r0,[r5,#0x24 ]
    add        r0,r6,#0x0
    mov        r1,#0xa4
    mov        r2,#0x0
    bl         0x02074470
    strh       r0,[r5,#0x26 ]
    add        r0,r6,#0x0
    mov        r1,#0xa5
    mov        r2,#0x0
    bl         0x02074470
    strh       r0,[r5,#0x28 ]
    add        r0,r6,#0x0
    mov        r1,#0xa6
    mov        r2,#0x0
    bl         0x02074470
    strh       r0,[r5,#0x2a ]
    add        r0,r6,#0x0
    mov        r1,#0xa8
    mov        r2,#0x0
    bl         0x02074470
    strh       r0,[r5,#0x2c ]
    add        r0,r6,#0x0
    mov        r1,#0xa9
    mov        r2,#0x0
    bl         0x02074470
    strh       r0,[r5,#0x2e ]
    add        r0,r6,#0x0
    mov        r1,#0xa7
    mov        r2,#0x0

normal_return:
    pop     {pc}

.pool

_stats:
    .byte 0xFF
stats:
    .byte 0x00, 0xFF

.ascii "EV+IV_Viewer_end"

.close