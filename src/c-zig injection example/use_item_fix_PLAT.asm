; use_item_fix.asm
.nds
.thumb
.include "../symbols.asm"

INJECT_ADDR equ 0x023C8000

; --- Place the compiled object into the synth overlay (or temp) --------------
.ifdef PREASSEMBLE
.create "temp.bin", 0x023C8000
.elseifdef PATCH
.open "unpacked/synthOverlay/0009", 0x023C8000    ; synth overlay base
.endif

.org INJECT_ADDR
.align 2
    .importobj "use_item_fix.o"
.close

; --- Hook the original code to call the Zig function -------------------------
.ifdef PATCH
.open "overlay/overlay_0014.bin", 0x0221FC20      ; trainer AI overlay base
.org 0x0222487A
    bl  use_item_fix                               ; call symbol from the object
.close
.endif
