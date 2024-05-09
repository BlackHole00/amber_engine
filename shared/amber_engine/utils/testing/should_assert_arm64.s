.text

.globl _asm_escape_assertion
_asm_escape_assertion:
        ; Skip assertion_proc data
        add sp, sp, #0xd0
        ; Skip internal assert data
        add sp, sp, #0x60

        ldp fp, lr, [sp, #-0x10]
        ret lr
