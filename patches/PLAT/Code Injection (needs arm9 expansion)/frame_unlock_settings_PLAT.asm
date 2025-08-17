; frame_unlock_settings_PLAT.asm
;
; replaces the "button mode" setting with a "unlock fps" setting
; initially implemented by Mikelan98 and AdAstra in Following Platinum, reverse engineered and adapted for G4P by Kalaay
; requires you to change the settings strings to "UNLOCK FPS", "OFF", "BATTLE" and "ALWAYS"

.nds
.thumb

INJECT_ADDR equ 0x023C8000

OS_WaitIrq equ 0x020C12B4
SaveData_GetOptions equ 0x02025E44
Options_ButtonMode equ 0x02027B30
SaveData_Ptr equ 0x020245A4

.ifdef PATCH

.open "arm9.bin", 0x02000000
.org 0x02000DCE
    bl function
.org 0x02017CA0 ; ApplyButtonModeToInput skip
    b 0x02017dc4
.close

.endif

.ifdef PREASSEMBLE
.create "temp.bin", 0x023C8000
.elseifdef PATCH
.open "unpacked/synthOverlay/0009", 0x023C8000
.endif

.org INJECT_ADDR
.ascii "frame_unlock_settings_start"
.align 4

function:
    push       {r4,lr}
    mov        r4,r0
    bl         SaveData_Ptr
    bl         SaveData_GetOptions
    bl         Options_ButtonMode
    cmp        r0,#0x1
    bne        LAB_023cdb9e
    ldr        r1,=0x021BF370   ; loaded overlay
    ldr        r1,[r1]
    cmp        r1,#0x10         ; 16 = battle overlay
    bne        LAB_023cdb9e
    mov        r4,#0x0
    b          LAB_023cdba4
LAB_023cdb9e:
    cmp        r0,#0x2
    bne        LAB_023cdba4
    mov        r4,#0x0
LAB_023cdba4:
    mov        r0,r4
    mov        r1,#0x1
    blx        OS_WaitIrq
    pop        {r4,pc}

.pool
.align 4

FUN_023c9b0c:
    ldr        r0, =0x02101D2C ; currApplication
    ldr        r0,[r0,#0x0]
    ldr        r0,[r0,#0x1c]
    bx         lr

.pool
.align 4

.ascii "frame_unlock_settings_end"

.close