
extern void ScriptManager_Set(void); // 0x0203E880

__attribute__((naked))  __attribute__((used)) void use_item_fix(void) {
    __asm__ volatile (
        "push {lr}\n"
        "bl ScriptManager_Set\n"
        "movs r3, #0x3a\n"
        "subs r0, r3\n"
        "strh r2, [r1, r0]\n"
        "ldr r0, [sp, #8]\n"
        "adds r0, r0, #4\n"
        "str r0, [sp, #8]\n"
        "pop {pc}\n"
    );
}