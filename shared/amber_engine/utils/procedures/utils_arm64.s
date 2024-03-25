; Various notes:
;   - The procedure snapshot will always contains the following data in the 
;     first (upper) addresses:
;         - offset -8:  empty
;         - offset -16: link return to caller. Set when the procedure is called
;                       with call() and when it is resumed by resume(). 
;         - offset -24: stack pointer of the caller. Set when the procedure is 
;                       called with call() and when it is resumed by resume(). 
;         - offset -32: frame pointer of the caller. Set when the procedure is 
;                       called with call() and when it is resumed by resume(). 
;     Please note that the empty location is necessary, since the stack pointer
;     should always be aligned at 16 bytes (actual arm hardware limitation)
;   - In the procedure the lr register will always point to _return_point, so
;     upon natural return the procedure will be able to return to the caller
;
; General references:
;   - arm64: https://courses.cs.washington.edu/courses/cse469/19wi/arm64.pdf
;   - calling convention: https://learn.microsoft.com/en-us/cpp/build/arm64-windows-abi-conventions?view=msvc-170

.equ REGISTER_SIZE, 8

; Offsets of Register_Snapshot
.equ RS_REGISTER_STATUSES_OFFSET, 0
.equ RS_SIMD_REGISTER_STATUSES_OFFSET, (RS_REGISTER_STATUSES_OFFSET + (14 * REGISTER_SIZE))
.equ RS_FPCR_STATUS_OFFSET, (RS_SIMD_REGISTER_STATUSES_OFFSET + (8 * REGISTER_SIZE))
.equ RS_SIZE, (RS_FPCR_STATUS_OFFSET + REGISTER_SIZE)

; Offsets of Procedure_Stack
.equ PS_STACK_ADDRESS_OFFSET, 0
.equ PS_STACK_SIZE_OFFSET, (PS_STACK_ADDRESS_OFFSET + REGISTER_SIZE)
.equ PS_STACK_BASE_OFFSET, (PS_STACK_SIZE_OFFSET + REGISTER_SIZE)
.equ PS_SIZE, (PS_STACK_BASE_OFFSET + REGISTER_SIZE)

; Offsets of Procedure_Context
.equ PC_CALLER_REGISTERS_OFFSET, 0
.equ PC_CALLEE_REGISTERS_OFFSET, (PC_CALLER_REGISTERS_OFFSET + RS_SIZE)
.equ PC_CALLEE_STACK_OFFSET, (PC_CALLEE_REGISTERS_OFFSET + RS_SIZE)
.equ PC_SIZE, (PC_CALLEE_STACK_OFFSET + PS_SIZE)

.text

; Generates a snapshot of the registers necessary to restore the procedure
; @calling_convention: c
; @modified_registers: x1
; @stack: none
; @parameters: x0 = ^Register_Snapshot
;              x1 = link return
;              x2 = stack pointer
;              x3 = frame pointer
_registersnapshot_create:
        str x18, [x0, RS_REGISTER_STATUSES_OFFSET + (0 * REGISTER_SIZE)]
        str x19, [x0, RS_REGISTER_STATUSES_OFFSET + (1 * REGISTER_SIZE)]
        str x20, [x0, RS_REGISTER_STATUSES_OFFSET + (2 * REGISTER_SIZE)]
        str x21, [x0, RS_REGISTER_STATUSES_OFFSET + (3 * REGISTER_SIZE)]
        str x22, [x0, RS_REGISTER_STATUSES_OFFSET + (4 * REGISTER_SIZE)]
        str x23, [x0, RS_REGISTER_STATUSES_OFFSET + (5 * REGISTER_SIZE)]
        str x24, [x0, RS_REGISTER_STATUSES_OFFSET + (6 * REGISTER_SIZE)]
        str x25, [x0, RS_REGISTER_STATUSES_OFFSET + (7 * REGISTER_SIZE)]
        str x26, [x0, RS_REGISTER_STATUSES_OFFSET + (8 * REGISTER_SIZE)]
        str x27, [x0, RS_REGISTER_STATUSES_OFFSET + (9 * REGISTER_SIZE)]
        str x28, [x0, RS_REGISTER_STATUSES_OFFSET + (10 * REGISTER_SIZE)]

        str x3,  [x0, RS_REGISTER_STATUSES_OFFSET + (11 * REGISTER_SIZE)] ; fp
        str x1,  [x0, RS_REGISTER_STATUSES_OFFSET + (12 * REGISTER_SIZE)] ; lr
        str x2,  [x0, RS_REGISTER_STATUSES_OFFSET + (13 * REGISTER_SIZE)] ; sp

        str d8, [x0, RS_SIMD_REGISTER_STATUSES_OFFSET + (0 * REGISTER_SIZE)]
        str d9, [x0, RS_SIMD_REGISTER_STATUSES_OFFSET + (1 * REGISTER_SIZE)]
        str d10, [x0, RS_SIMD_REGISTER_STATUSES_OFFSET + (2 * REGISTER_SIZE)]
        str d11, [x0, RS_SIMD_REGISTER_STATUSES_OFFSET + (3 * REGISTER_SIZE)]
        str d12, [x0, RS_SIMD_REGISTER_STATUSES_OFFSET + (4 * REGISTER_SIZE)]
        str d13, [x0, RS_SIMD_REGISTER_STATUSES_OFFSET + (5 * REGISTER_SIZE)]
        str d14, [x0, RS_SIMD_REGISTER_STATUSES_OFFSET + (6 * REGISTER_SIZE)]
        str d15, [x0, RS_SIMD_REGISTER_STATUSES_OFFSET + (7 * REGISTER_SIZE)]

        mrs x1, fpcr
        str x1, [x0, RS_FPCR_STATUS_OFFSET]
        
        ret lr

; Restores a register snapshot (and thus returns the execution to the procedure)
; @calling_convention: c
; @modified_registers: all
; @stack: none - sp will be modified
; @parameters: x0 = ^Register_Snapshot
_registersnapshot_restore_and_jump:
        ldr x18, [x0, RS_REGISTER_STATUSES_OFFSET + (0 * REGISTER_SIZE)]
        ldr x19, [x0, RS_REGISTER_STATUSES_OFFSET + (1 * REGISTER_SIZE)]
        ldr x20, [x0, RS_REGISTER_STATUSES_OFFSET + (2 * REGISTER_SIZE)]
        ldr x21, [x0, RS_REGISTER_STATUSES_OFFSET + (3 * REGISTER_SIZE)]
        ldr x22, [x0, RS_REGISTER_STATUSES_OFFSET + (4 * REGISTER_SIZE)]
        ldr x23, [x0, RS_REGISTER_STATUSES_OFFSET + (5 * REGISTER_SIZE)]
        ldr x24, [x0, RS_REGISTER_STATUSES_OFFSET + (6 * REGISTER_SIZE)]
        ldr x25, [x0, RS_REGISTER_STATUSES_OFFSET + (7 * REGISTER_SIZE)]
        ldr x26, [x0, RS_REGISTER_STATUSES_OFFSET + (8 * REGISTER_SIZE)]
        ldr x27, [x0, RS_REGISTER_STATUSES_OFFSET + (9 * REGISTER_SIZE)]
        ldr x28, [x0, RS_REGISTER_STATUSES_OFFSET + (10 * REGISTER_SIZE)]
        
        ldr fp,  [x0, RS_REGISTER_STATUSES_OFFSET + (11 * REGISTER_SIZE)]
        ldr lr,  [x0, RS_REGISTER_STATUSES_OFFSET + (12 * REGISTER_SIZE)]
        ldr x1,  [x0, RS_REGISTER_STATUSES_OFFSET + (13 * REGISTER_SIZE)] ; sp
        mov sp, x1
    
        ldr d8, [x0, RS_SIMD_REGISTER_STATUSES_OFFSET + (0 * REGISTER_SIZE)]
        ldr d9, [x0, RS_SIMD_REGISTER_STATUSES_OFFSET + (1 * REGISTER_SIZE)]
        ldr d10, [x0, RS_SIMD_REGISTER_STATUSES_OFFSET + (2 * REGISTER_SIZE)]
        ldr d11, [x0, RS_SIMD_REGISTER_STATUSES_OFFSET + (3 * REGISTER_SIZE)]
        ldr d12, [x0, RS_SIMD_REGISTER_STATUSES_OFFSET + (4 * REGISTER_SIZE)]
        ldr d13, [x0, RS_SIMD_REGISTER_STATUSES_OFFSET + (5 * REGISTER_SIZE)]
        ldr d14, [x0, RS_SIMD_REGISTER_STATUSES_OFFSET + (6 * REGISTER_SIZE)]
        ldr d15, [x0, RS_SIMD_REGISTER_STATUSES_OFFSET + (7 * REGISTER_SIZE)]

        ldr x1, [x0, RS_FPCR_STATUS_OFFSET]
        msr fpcr, x1

        br lr

; @see call(), _call()
; @calling_convention: c
; @modified_registers: all
; @stack: none - sp will be modified
; @parameters: x0 = ^Procedure_Context
;              x1 = procedure address
;              x2 = procedure parameter
;              x3 = ^runtime.Context
.globl _asmcall
_asmcall:
        mov x5, x1                          ; x5 = procedure address
        mov x6, x2                          ; x6 = procedure parameter
        mov x7, x3                          ; x7 = ^runtime.Context
        mov x8, lr                          ; x8 = lr
        
        mov x1, lr                          ; x1 = lr
        mov x2, sp                          ; x2 = sp
        mov x3, fp                          ; x3 = fp
        bl _registersnapshot_create
        ; _registersnapshot_create(&Procedure_Context.caller_registers, lr, sp, fp)
        
        ; setup stack
        ldr x1, [x0, PC_CALLEE_STACK_OFFSET + PS_STACK_BASE_OFFSET] 
        sub x1, x1, 8                       ; x1 = Procedure_Context.callee_stack.stack_base
        str x8, [x1], -8                    ; (stack_base - 8)^ = lr
        str x2, [x1], -8                    ; (stack_base - 16)^ = sp
        str fp, [x1]                        ; (stack_base - 24)^ = fp
        
        adr lr, _return_point               ; lr = &&_return_point
        mov sp, x1                          ; sp = stack_base - 24
        mov fp, x1                          ; fp = stack_base - 24

        mov x0, x6                          ; x0 = procedure parameter
        mov x1, x7                          ; x1 = ^runtime.Context
        br x5
        ; procedure address(procedure parameter, ^runtime.Context)

; @see yield()
; @calling_convention: c
; @modified_registers: all
; @stack: none - sp will be modified
; @parameters: x0 = ^Procedure_Context
.globl _asmyield
_asmyield:
        add x0, x0, PC_CALLEE_REGISTERS_OFFSET ; x0 = &Procedure_Context.callee_registers
        mov x1, lr                          ; x1 = lr
        mov x2, sp                          ; x2 = sp
        mov x3, fp                          ; x3 = fp
        bl _registersnapshot_create
        ; _registersnapshot_create(&Procedure_Context.callee_registers, lr, sp, fp)

        sub x0, x0, PC_CALLEE_REGISTERS_OFFSET ; x0 = &Procedure_Context.caller_registers
        b _registersnapshot_restore_and_jump
        ; _registersnapshot_restore_and_jump(&Procedure_Context.caller_registers)

; @see resume()
; @calling_convention: c
; @modified_registers: all
; @stack: none - sp will be modified
; @parameters: x0 = ^Procedure_Context
.globl _asmresume
_asmresume:
        mov x6, lr                          ; x6 = lr
        
        mov x1, lr                          ; x1 = lr
        mov x2, sp                          ; x2 = sp
        mov x3, fp                          ; x3 = fp
        bl _registersnapshot_create
        ; _registersnapshot_create(&Procedure_Context.caller_registers)

        ; setup stack
        ldr x1, [x0, PC_CALLEE_STACK_OFFSET + PS_STACK_BASE_OFFSET] ; x1 = &Procedure_Context.callee_stack.stack_base
        str x6, [x1, -8]                    ; (stack_base - 8)^ = lr
        str x2, [x1, -16]                   ; (stack_base - 16)^ = sp
        str fp, [x1, -24]                   ; (stack_base - 24)^ = fp

        add x0, x0, PC_CALLEE_REGISTERS_OFFSET ; x0 = &Procedure_Context.callee_registers
        b _registersnapshot_restore_and_jump
        ; _registersnapshot_restore_and_jump(&Procedure_Context.callee_registers)
        
        
; @see force_return()
; @calling_convention: c
; @modified_registers: all
; @stack: none - sp will be modified
; @parameters: x0 = ^Procedure_Context
.globl _asmforce_return
_asmforce_return:
        b _registersnapshot_restore_and_jump
        ; _registersnapshot_restore_and_jump(&Procedure_Context.caller_registers)

; @calling_convention: c
; @modified_registers: x1
; @stack: none 
; @return: stack pointer of caller
.globl _asmget_stack_pointer
_asmget_stack_pointer:
        mov x0, sp
        ret lr

; Once a procedue called with call() returns normally (without force_return())
; it will return here. The original stack pointer, frame pointer and link return
; of the caller are restored from the stack, in order to return to normal 
; execution
_return_point:
        ldr lr, [sp, 16]
        ldr fp, [sp]
        ldr x2, [sp, 8]
        mov sp, x2

        ret lr

