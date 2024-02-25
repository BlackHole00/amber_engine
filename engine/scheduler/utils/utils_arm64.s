; References:
;   - https://courses.cs.washington.edu/courses/cse469/19wi/arm64.pdf
;   - https://student.cs.uwaterloo.ca/~cs452/docs/rpi4b/aapcs64.pdf
;   - https://learn.microsoft.com/en-us/cpp/build/arm64-windows-abi-conventions?view=msvc-170

; @calling_convention: c
; @modified_registers: all
; @params: x0 = ^Stack_Snapshot
;          x1 = frame base
;          x2  = current frame
.globl _stacksnapshot_create

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

; @calling_convention: c
; @modified_registers: x1
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

; @calling_convention: c
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
        ldr x1,  [x0, RS_REGISTER_STATUSES_OFFSET + (13 * REGISTER_SIZE)]
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

; @calling_convention: c
; @parameters: x0 = ^Procedure_Context
;              x1 = procedure address
;              x2 = parameter
;              x3 = ^runtime.Context
.globl _asmcall
_asmcall:
        mov x5, x1
        mov x6, lr
        mov x7, x2
        mov x8, x3
        
        mov x1, lr
        mov x2, sp
        mov x3, fp
        bl _registersnapshot_create
        
        ldr x1, [x0, PC_CALLEE_STACK_OFFSET + PS_STACK_BASE_OFFSET]
        sub x1, x1, 8
        str x6, [x1], -8
        mov x6, sp
        str x6, [x1], -8
        str fp, [x1]
        
        adr lr, _return_point
        mov sp, x1
        mov fp, sp

        mov x0, x7
        mov x1, x8
        br x5

; @calling_convention: c
; @parameters: x0 = ^Procedure_Context
.globl _asmyield
_asmyield:
        add x0, x0, PC_CALLEE_REGISTERS_OFFSET
        mov x1, lr
        mov x2, sp
        mov x3, fp
        bl _registersnapshot_create

        sub x0, x0, PC_CALLEE_REGISTERS_OFFSET
        b _registersnapshot_restore_and_jump

; @calling_convention: c
; @parameters: x0 = ^Procedure_Context
.globl _asmresume
_asmresume:
        mov x6, lr
        
        mov x1, lr
        mov x2, sp
        mov x3, fp
        bl _registersnapshot_create

        ldr x1, [x0, PC_CALLEE_STACK_OFFSET + PS_STACK_BASE_OFFSET]
        str x6, [x1, -8]
        str x2, [x1, -16]
        str fp, [x1, -24]

        add x0, x0, PC_CALLEE_REGISTERS_OFFSET
        b _registersnapshot_restore_and_jump
        
        
; @calling_convention: c
; @parameters: x0 = ^Procedure_Context
.globl _asmforce_return
_asmforce_return:
        b _registersnapshot_restore_and_jump

; @calling_convention: c
.globl _asmget_stack_pointer
_asmget_stack_pointer:
        mov x1, rp
        ret lr

_return_point:
        ldr lr, [sp, 16]
        ldr fp, [sp]
        ldr x2, [sp, 8]
        mov sp, x2

        ret lr

