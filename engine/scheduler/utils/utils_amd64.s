; References:
;  - stdcall: https://learn.microsoft.com/en-us/cpp/build/x64-calling-convention?view=msvc-170

global _asmcall
global _asmyield
global _asmresume
global _asmforce_return

; Register sizes
REGISTER_SIZE equ 8
XMM_REGISTER_SIZE equ 16

; Offsets of Register_Snapshot
RS_REGISTER_STATUSES_OFFSET equ 0
RS_SSE_REGISTER_STATUSES_OFFSET equ (RS_REGISTER_STATUSES_OFFSET + (REGISTER_SIZE * 10))
RS_SIZE equ (RS_SSE_REGISTER_STATUSES_OFFSET + (XMM_REGISTER_SIZE * 10))

; Offsets of Procedure_Stack
PS_STACK_ADDRESS_OFFSET equ 0
PS_STACK_SIZE_OFFSET equ (PS_STACK_ADDRESS_OFFSET + REGISTER_SIZE)
PS_STACK_BASE_OFFSET equ (PS_STACK_SIZE_OFFSET + REGISTER_SIZE)
PS_SIZE equ (PS_STACK_BASE_OFFSET + REGISTER_SIZE)

; Offsets of Procedure_Context
PC_CALLER_REGISTERS_OFFSET equ 0
PC_CALLEE_REGISTERS_OFFSET equ (PC_CALLER_REGISTERS_OFFSET + RS_SIZE)
PC_CALLEE_STACK_OFFSET equ (PC_CALLEE_REGISTERS_OFFSET + RS_SIZE)
PC_SIZE equ (PC_CALLEE_STACK_OFFSET + PS_SIZE)

; Other
SIZE_OF_CALL_INSTRUCTION equ 12

section .text

; @calling_convention: stdcall
; @modified_registers: none
; @stack: none
; @params: RCX = ^Register_Snapshot
;          RDX = instruction register
;          r8  = stack pointer
_registersnapshot_create:
        mov [rcx + RS_REGISTER_STATUSES_OFFSET + (0 * REGISTER_SIZE)], rdi
        mov [rcx + RS_REGISTER_STATUSES_OFFSET + (1 * REGISTER_SIZE)], rsi
        mov [rcx + RS_REGISTER_STATUSES_OFFSET + (2 * REGISTER_SIZE)], rbx
        mov [rcx + RS_REGISTER_STATUSES_OFFSET + (3 * REGISTER_SIZE)], rbp
        mov [rcx + RS_REGISTER_STATUSES_OFFSET + (4 * REGISTER_SIZE)], r12
        mov [rcx + RS_REGISTER_STATUSES_OFFSET + (5 * REGISTER_SIZE)], r13
        mov [rcx + RS_REGISTER_STATUSES_OFFSET + (6 * REGISTER_SIZE)], r14
        mov [rcx + RS_REGISTER_STATUSES_OFFSET + (7 * REGISTER_SIZE)], r15
        
        mov [rcx + RS_REGISTER_STATUSES_OFFSET + (8 * REGISTER_SIZE)], rdx ; rip
        mov [rcx + RS_REGISTER_STATUSES_OFFSET + (9 * REGISTER_SIZE)], r8  ; rsp
        
        movups [rcx + RS_SSE_REGISTER_STATUSES_OFFSET + (0 * XMM_REGISTER_SIZE)], xmm6
        movups [rcx + RS_SSE_REGISTER_STATUSES_OFFSET + (1 * XMM_REGISTER_SIZE)], xmm7
        movups [rcx + RS_SSE_REGISTER_STATUSES_OFFSET + (2 * XMM_REGISTER_SIZE)], xmm8
        movups [rcx + RS_SSE_REGISTER_STATUSES_OFFSET + (3 * XMM_REGISTER_SIZE)], xmm9
        movups [rcx + RS_SSE_REGISTER_STATUSES_OFFSET + (4 * XMM_REGISTER_SIZE)], xmm10
        movups [rcx + RS_SSE_REGISTER_STATUSES_OFFSET + (5 * XMM_REGISTER_SIZE)], xmm11
        movups [rcx + RS_SSE_REGISTER_STATUSES_OFFSET + (6 * XMM_REGISTER_SIZE)], xmm12
        movups [rcx + RS_SSE_REGISTER_STATUSES_OFFSET + (7 * XMM_REGISTER_SIZE)], xmm13
        movups [rcx + RS_SSE_REGISTER_STATUSES_OFFSET + (8 * XMM_REGISTER_SIZE)], xmm14
        movups [rcx + RS_SSE_REGISTER_STATUSES_OFFSET + (9 * XMM_REGISTER_SIZE)], xmm15

        ret

; @calling_convention: stdcall
; @modified_registers: all
; @stack: none
; @params: RCX = ^Procedure_Snapshot
_registersnapshot_restore_and_jump:
        mov rdi, [rcx + RS_REGISTER_STATUSES_OFFSET + (0 * REGISTER_SIZE)]
        mov rsi, [rcx + RS_REGISTER_STATUSES_OFFSET + (1 * REGISTER_SIZE)]
        mov rbx, [rcx + RS_REGISTER_STATUSES_OFFSET + (2 * REGISTER_SIZE)]
        mov rbp, [rcx + RS_REGISTER_STATUSES_OFFSET + (3 * REGISTER_SIZE)]
        mov r12, [rcx + RS_REGISTER_STATUSES_OFFSET + (4 * REGISTER_SIZE)]
        mov r13, [rcx + RS_REGISTER_STATUSES_OFFSET + (5 * REGISTER_SIZE)]
        mov r14, [rcx + RS_REGISTER_STATUSES_OFFSET + (6 * REGISTER_SIZE)]
        mov r15, [rcx + RS_REGISTER_STATUSES_OFFSET + (7 * REGISTER_SIZE)]
        mov rsp, [rcx + RS_REGISTER_STATUSES_OFFSET + (9 * REGISTER_SIZE)]
        
        movups xmm6, [rcx + RS_SSE_REGISTER_STATUSES_OFFSET + (0 * XMM_REGISTER_SIZE)]
        movups xmm7, [rcx + RS_SSE_REGISTER_STATUSES_OFFSET + (1 * XMM_REGISTER_SIZE)]
        movups xmm8, [rcx + RS_SSE_REGISTER_STATUSES_OFFSET + (2 * XMM_REGISTER_SIZE)]
        movups xmm9, [rcx + RS_SSE_REGISTER_STATUSES_OFFSET + (3 * XMM_REGISTER_SIZE)]
        movups xmm10, [rcx + RS_SSE_REGISTER_STATUSES_OFFSET + (4 * XMM_REGISTER_SIZE)]
        movups xmm11, [rcx + RS_SSE_REGISTER_STATUSES_OFFSET + (5 * XMM_REGISTER_SIZE)]
        movups xmm12, [rcx + RS_SSE_REGISTER_STATUSES_OFFSET + (6 * XMM_REGISTER_SIZE)]
        movups xmm13, [rcx + RS_SSE_REGISTER_STATUSES_OFFSET + (7 * XMM_REGISTER_SIZE)]
        movups xmm14, [rcx + RS_SSE_REGISTER_STATUSES_OFFSET + (8 * XMM_REGISTER_SIZE)]
        movups xmm15, [rcx + RS_SSE_REGISTER_STATUSES_OFFSET + (9 * XMM_REGISTER_SIZE)]

        jmp [rcx + RS_REGISTER_STATUSES_OFFSET + (8 * REGISTER_SIZE)]

; @calling_convention: stdcall
; @modified_registers: all
; @stack: none
; @params: RCX = ^Procedure_Context
;          RDX = address of procedure
;          R8  = ^Task
;          R9  = ^runtime.Context
_asmcall:
        mov r10, rdx
        mov r11, r8

        mov rdx, [rsp]                      ; rdx = lr
        mov r8, rsp
        add r8, REGISTER_SIZE               ; r8 = rsp + REGISTER_SIZE (rsp of caller)
        call _registersnapshot_create
        ; _registersnapshot_create(&Procedure_Context.caller_registers, lr, rsp of caller)

        ; setup stack
        mov rsp, [rcx + PC_CALLEE_STACK_OFFSET + PS_STACK_BASE_OFFSET] ; rsp = Procedure_Context.callee_stack.stack_base
        mov [rsp - 0 ], rdx                 ; rsp[0] = lr
        mov [rsp - 8 ], r8                  ; rsp[-8] = rsp of caller
        lea rdx, [rel _return_point]        
        mov [rsp - 16], rdx                 ; rsp[-16] = &&_return_point
        sub rsp, 16

        mov rcx, r11                        ; rcx = ^Task
        mov rdx, r9                         ; rdx = ^runtime.Context
        jmp r10
        ; procedure(^Task, ^runtime.Context)

; @calling_convention: stdcall
; @modified_registers: all
; @stack: 8 bytes: [0] = ^Procedure_Context 
; @params: RCX = ^Procedure_Context
_asmyield:
        add rcx, PC_CALLEE_REGISTERS_OFFSET ; rcx = &Procedure_Context.callee_registers
        mov rdx, [rsp]                      ; rdx = lr
        mov r8, rsp
        add r8, REGISTER_SIZE               ; r8 = rsp of caller
        call _registersnapshot_create
        ; _registersnapshot_create(&Procedure_Context.callee_registers, lr, rsp of caller)

        sub rcx, PC_CALLEE_REGISTERS_OFFSET ; rcx = &Procedure_Context.caller_registers
        jmp _registersnapshot_restore_and_jump
        ; _registersnapshot_restore_and_jump(&Procedure_Context.caller_registers)

; @calling_convention: stdcall
; @modified_registers: all
; @stack: none
; @params: RCX = ^Procedure_Context
_asmresume: 
        mov rdx, [rsp]                      ; rdx = lr
        mov r8, rsp
        add r8, REGISTER_SIZE               ; r8 = rsp of caller
        call _registersnapshot_create
        ; _registersnapshot_create(&Procedure_Context.caller_registers, lr, rsp of caller)

        ; setup stack
        mov r9, [rcx + PC_CALLEE_STACK_OFFSET + PS_STACK_BASE_OFFSET] ; r9 = Procedure_Context.callee_stack.stack_base
        mov [r9 - 0 ], rdx                  ; stack_base[0] = lr
        mov [r9 - 8 ], r8                   ; stack_base[-8] = rsp of caller

        add rcx, PC_CALLEE_REGISTERS_OFFSET ; rcx = &Procedure_Context.callee_registers
        jmp _registersnapshot_restore_and_jump
        ; _registersnapshot_restore_and_jump(&Procedure_Context.callee_registers)
        
; @calling_convention: stdcall
; @modified_registers: all
; @stack: none
; @params: RCX = ^Procedure_Context
_asmforce_return:
        jmp _registersnapshot_restore_and_jump
        ; _registersnapshot_restore_and_jump(&Procedure_Context.caller_registers)

_return_point:
        mov rcx, [rsp + 8]
        mov rsp, [rsp]

        jmp rcx
        
