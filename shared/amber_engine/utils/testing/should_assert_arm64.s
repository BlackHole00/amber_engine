.data
.globl _ESCAPE_ASSERTION_OFFSETS

.text
.globl _asm_escape_assertion
_asm_escape_assertion:
        ; x1 = &_ESCAPE_ASSERTION_OFFSET
        adrp x1, _ESCAPE_ASSERTION_OFFSETS@PAGE
        add x1, x1, _ESCAPE_ASSERTION_OFFSETS@PAGEOFF

        ; x2 = x1.assertion_proc_offset
        ldr x2, [x1, #0x8]
        ; x1 = x1.internal_assertion_offset
        ldr x1, [x1]

        ; Skip assertion_proc data
        add sp, sp, x1
        ; Skip internal assert data
        add sp, sp, x2

        ; Restore fp, lr, sp and jump
        ldp fp, lr, [sp, #-0x10]
        ret lr
