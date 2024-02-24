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
.equ RS_SIMD_REGISTER_STATUSES_OFFSET, (RS_REGISTER_STATUSES_OFFSET + (15 * REGISTER_SIZE))
.equ RS_FPCR_STATUS_OFFSET, (RS_SIMD_REGISTER_STATUSES_OFFSET + (8 * REGISTER_SIZE))
.equ RS_SIZE, (RS_FPCR_STATUS_OFFSET + REGISTER_SIZE)

; Offsets of Stack_Snapshot
.equ SS_DATA_PTR_OFFSET, 0
.equ SS_LEN_OFFSET, (SS_DATA_PTR_OFFSET + REGISTER_SIZE)
.equ SS_SIZE, (SS_LEN_OFFSET + REGISTER_SIZE)

; Offsets of Procedure_Snapshot
.equ PS_REGISTER_SNAPSHOT_OFFSET, 0
.equ PS_STACK_SNAPSHOT_OFFSET, (PS_REGISTER_SNAPSHOT_OFFSET + RS_SIZE)
.equ PS_SIZE, (PS_STACK_SNAPSHOT_OFFSET + SS_SIZE)

; Offsets of Procedure_Context
.equ PC_CALLEE_SNAPSHOT_OFFSET, 0
.equ PC_CALLER_REGISTERS_OFFSET, (PC_CALLEE_SNAPSHOT_OFFSET + PS_SIZE)
.equ PC_SIZE, (PC_CALLER_REGISTERS_OFFSET + RS_SIZE)

.text

; @calling_convention: c
; @modified_registers: x1
; @parameters: x0 = ^Register_Snapshot
;              x1 = instruction register
;              x2 = link return
;              x3 = stack pointer
;              x4 = frame pointer
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

        str x4,  [x0, RS_REGISTER_STATUSES_OFFSET + (11 * REGISTER_SIZE)] ; fp
        str x2,  [x0, RS_REGISTER_STATUSES_OFFSET + (12 * REGISTER_SIZE)] ; lr
        str x3,  [x0, RS_REGISTER_STATUSES_OFFSET + (13 * REGISTER_SIZE)] ; sp
        str x1,  [x0, RS_REGISTER_STATUSES_OFFSET + (14 * REGISTER_SIZE)] ; ir

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
; @note: sp is not restored
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
        
        ldr fp,  [x0, RS_REGISTER_STATUSES_OFFSET + (11 * REGISTER_SIZE)] ; fp
        ldr lr,  [x0, RS_REGISTER_STATUSES_OFFSET + (12 * REGISTER_SIZE)] ; lr
    
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

        ldr x1,  [x0, RS_REGISTER_STATUSES_OFFSET + (14 * REGISTER_SIZE)] ; ir
        br x1
        ; br lr

; @modified_registers: x0, x1, x2, x3, sp
; @parameters: x0 = ^Procedure_Snapshot
;              x1 = stack base
_stacksnapshot_restore:
        ldr x2, [x0, SS_LEN_OFFSET]
        ldr x0, [x0, SS_DATA_PTR_OFFSET]

        sub x1, x1, x2
        subs x2, x2, 1
        blt  _memcopy_end

_memcopy_start:
        ldrb w3, [x0, x2]
        strb w3, [x1, x2]
        subs x2, x2, 1

        bge _memcopy_start
_memcopy_end:

        mov sp, x1
        ret lr

; @modified_registers: all
; @parameters: x0 = ^Procedure_Snapshot
;              x1 = stack base
;              x2 = instruction resume address
;              x3 = link return
;              x4 = current stack
;              x5 = current frame pointer
;              x6 = caller frame pointer
;              x7 = main link return
_proceduresnapshot_create:
        str lr, [sp, -16]!
        
        mov x8, x1                          ; x6 = stack base

        add x0, x0, PS_REGISTER_SNAPSHOT_OFFSET
        mov x1, x2                          ; x1 = instruction resume address
        mov x2, x3                          ; x2 = link return
        mov x3, x4                          ; x3 = current stack
        mov x4, x5                          ; x4 = current frame pointer
        bl _registersnapshot_create
        ; _registersnapshot_create(
        ;     &Procedure_Snapshot.register_snapshot,
        ;     instruction resume address,
        ;     link return,
        ;     current stack,
        ;     current frame pointer,
        ; )
        ; All register other than x1 are preserved

        add x0, x0, PS_STACK_SNAPSHOT_OFFSET; x0 = &Procedure_Snapshot.stack_snapshot
        mov x1, x8                          ; x1 = stack base
        mov x2, x3                          ; x2 = current stack
        mov x3, x7
        mov x4, x6
        bl _stacksnapshot_create
        ; _stacksnapshot_create(&Procedure_Snapshot.stack_snapshot, stack base, current stack)

        ldr lr, [sp], 16
        ret lr

; @calling_convention: c
; @parameters: x0 = ^Procedure_Snapshot
;              x1 = stack base
_proceduresnapshot_restore:
        mov x4, x0
        
        add x0, x0, PS_STACK_SNAPSHOT_OFFSET
        ; x1 is valid
        bl _stacksnapshot_restore

        mov x0, x4
        b _registersnapshot_restore_and_jump


; @calling_convention: c
; @parameters: x0 = ^Procedure_Context
;              x1 = procedure address
;              x2 = parameter
;              x3 = ^runtime.Context
.globl _call
_call:
        ; str lr, [sp, -16]!
        
        mov x5, x1
        mov x6, x2
        mov x7, x3
        
        add x0, x0, PC_CALLER_REGISTERS_OFFSET
        adr x1, _call_restore_point
        mov x2, lr
        mov x3, sp
        mov x4, fp
        bl _registersnapshot_create
        ; _registersnapshot_create(&Procedure_Context.caller_registers, &&_call_restore_point, lr, sp, fp)

        ; sub x0, x0, PC_CALLER_REGISTERS_OFFSET
        mov x0, x6
        mov x1, x7
        br x5
        ; procedure(parameter, ^runtime.Context)

_call_restore_point:
        ; ldr lr, [sp], 16
        ret lr

; @calling_convention: c
; @parameters: x0 = ^Procedure_Context
.globl _resume
_resume:
        add x0, x0, PC_CALLER_REGISTERS_OFFSET
        adr x1, _resume_restore_point
        mov x2, lr
        mov x3, sp
        mov x4, fp
        bl _registersnapshot_create

        sub x0, x0, PC_CALLER_REGISTERS_OFFSET
        mov x1, sp
        b _proceduresnapshot_restore
        
_resume_restore_point:
        ret lr

; @calling_convention: c
; @parameters: x0 = ^Procedure_Context
.globl _yield
_yield:
        str x0, [sp, -16]!

        add x0, x0, PC_CALLEE_SNAPSHOT_OFFSET
        ldr x1, [x0, PC_CALLER_REGISTERS_OFFSET + RS_REGISTER_STATUSES_OFFSET + (13 * REGISTER_SIZE)] ; x1 = Procedure_Context.caller_registers[.Sp]
        adr x2, _yield_restore_point
        mov x3, lr
        add x4, sp, 16
        mov x5, fp
        ldr x6, [x0, PC_CALLER_REGISTERS_OFFSET + RS_REGISTER_STATUSES_OFFSET + (11 * REGISTER_SIZE)] ; fp
        ldr x7, [x0, PC_CALLER_REGISTERS_OFFSET + RS_REGISTER_STATUSES_OFFSET + (12 * REGISTER_SIZE)] ; lr
        bl _proceduresnapshot_create

        ldr x0, [sp], 16
        ldr x1, [x0, PC_CALLER_REGISTERS_OFFSET + RS_REGISTER_STATUSES_OFFSET + (13 * REGISTER_SIZE)] ; x1 = Procedure_Context.caller_registers[.Sp]
        mov sp, x1
        add x0, x0, PC_CALLER_REGISTERS_OFFSET
        b _registersnapshot_restore_and_jump

_yield_restore_point:
        ret lr

; @calling_convention: c
; @parameters: x0 = ^Procedure_Context
.globl _force_return
_force_return:
        ldr x1, [x0, PC_CALLER_REGISTERS_OFFSET + RS_REGISTER_STATUSES_OFFSET + (13 * REGISTER_SIZE)] ; x1 = Procedure_Context.caller_registers[.Sp]
        mov sp, x1
        add x0, x0, PC_CALLER_REGISTERS_OFFSET
        b _registersnapshot_restore_and_jump

