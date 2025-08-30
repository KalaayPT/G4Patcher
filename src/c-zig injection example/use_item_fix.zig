extern fn ScriptManager_Set() void;

pub export fn use_item_fix() callconv(.naked) void {
    asm volatile (
        \\ push {lr}
        \\ bl ScriptManager_Set
        \\ movs r3, #0x3a
        \\ subs r0, r3
        \\ strh r2, [r1, r0]
        \\ ldr r0, [sp, #8]
        \\ adds r0, r0, #4
        \\ str r0, [sp, #8]
        \\ pop {pc}
    );
}
