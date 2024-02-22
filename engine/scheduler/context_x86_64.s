; TODO(Vicix): Find better reference with intel syntax
; References:
;  - asm: https://web.stanford.edu/class/cs107/resources/x86-64-reference.pdf.
;  - stdcall: https://learn.microsoft.com/en-us/cpp/build/x64-calling-convention?view=msvc-170

global procedurecontext_yield
global procedurecontext_call
global procedurecontext_resume
global procedurecontext_force_return

; @calling_convention: stdcall
; @modified_registers: all
; @params: RCX = ^scheduler.Stack_Snapshot
;          RDX = stack end
;          R8  = current stack
extern create_stacksnapshot

; Register sizes
REGISTER_SIZE equ 8
XMM_REGISTER_SIZE equ 16

; Offsets of scheduler.Register_Snapshot
RS_REGISTER_STATUSES_OFFSET equ 0
RS_SSE_REGISTER_STATUSES_OFFSET equ (RS_REGISTER_STATUSES_OFFSET + (REGISTER_SIZE * 10))
RS_SIZE equ (RS_SSE_REGISTER_STATUSES_OFFSET + (XMM_REGISTER_SIZE * 10))

; Offsets of scheduler.Stack_Snapshot
SS_DATA_PTR_OFFSET equ 0
SS_LET_OFFSET equ (SS_DATA_PTR_OFFSET + REGISTER_SIZE)
SS_SIZE equ (SS_LET_OFFSET + REGISTER_SIZE)

; Offsets of scheduler.Procedure_Snapshot
PS_REGISTER_SNAPSHOT_OFFSET equ 0
PS_STACK_SNAPSHOT_OFFSET equ (PS_REGISTER_SNAPSHOT_OFFSET + RS_SIZE)
PS_SIZE equ (RS_SIZE + SS_SIZE)

; Offsets of scheduler.Procedure_Context
PC_CALLEE_SNAPSHOT_OFFSET equ 0
PC_CALLER_REGISTER_SNAPSHOT_OFFSET equ (PC_CALLEE_SNAPSHOT_OFFSET + PS_SIZE)
PC_CALLER_STACK_POINTER_OFFSET equ (PC_CALLER_REGISTER_SNAPSHOT_OFFSET + RS_SIZE)
PC_SIZE equ (PC_CALLER_STACK_POINTER_OFFSET + REGISTER_SIZE)

; Other
SIZE_OF_CALL_INSTRUCTION equ 12

section .text

; @calling_convention: stdcall
; @modified_registers: none
; @stack: none
; @params: RCX = ^scheduler.Register_Snapshot
;          RDX = instruction register
;          r8  = stack pointer
create_registersnapshot:
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
; @stack: 8 bytes: [0] = stack base
; @params: RCX = ^scheduler.Procedure_Snapshot
;          RDX = stack base
;          R8  = restore point instruction [nullable]
;          R9  = current stack [nullable]
create_proceduresnapshot:
        sub rsp, REGISTER_SIZE              ; set stack
        mov [rsp], rdx                      ; stack[0] = stack base
        
        cmp r8, 0                           ; if r8 == 0
        jne setup_register_snapshot         ;     r8 = &&create_proceduresnapshot_restore_point
        lea r8, [rel create_proceduresnapshot_restore_point]
        
setup_register_snapshot:
        ; rcx is the same parameter
        mov rdx, r8                         ; rdx = restore point instruction
        mov r8,  rsp                        ; r8 = rsp - REGISTER_SIZE
        add r8, REGISTER_SIZE               ; Account for stack size
        call create_registersnapshot
        ; create_registersnapshot(rcx, restore point instruction, rsp - REGISTER_SIZE)

        cmp r9, 0                           ; if current stack == 0
        jne setup_stack_snapshot            ;     r9 = rsp - REGISTER_SIZE
        mov r9, r8

setup_stack_snapshot:
        ; rcx and r8 do not get modified by create_registersnapshot
        add rcx, PS_STACK_SNAPSHOT_OFFSET   ; rcx = &rcx.stack_snapshot
        mov rdx, [rsp]                      ; rdx = stack[0] (stack base)
        mov r8, r9                          ; r8 = current stack
        call create_stacksnapshot
        ; create_stacksnapshot(&rcx.stack_snapshot, stack base, current stack)
        
        add rsp, REGISTER_SIZE              ; restore stack

create_proceduresnapshot_restore_point:
        ret

; @calling_convention: stdcall
; @modified_registers: rdi, rsi, rbx, rbp, r12, r13, r14, r15, xmm6, xmm7, xmm8,
;                      xmm9, xmm10, xmm11, xmm12, xmm13, xmm14, xmm15
; @stack: none
; @note: this procedure does not restore the rsp
; @params: RCX = ^scheduler.Procedure_Snapshot
restore_registersnapshot_and_jump:
        mov rdi, [rcx + RS_REGISTER_STATUSES_OFFSET + (0 * REGISTER_SIZE)]
        mov rsi, [rcx + RS_REGISTER_STATUSES_OFFSET + (1 * REGISTER_SIZE)]
        mov rbx, [rcx + RS_REGISTER_STATUSES_OFFSET + (2 * REGISTER_SIZE)]
        mov rbp, [rcx + RS_REGISTER_STATUSES_OFFSET + (3 * REGISTER_SIZE)]
        mov r12, [rcx + RS_REGISTER_STATUSES_OFFSET + (4 * REGISTER_SIZE)]
        mov r13, [rcx + RS_REGISTER_STATUSES_OFFSET + (5 * REGISTER_SIZE)]
        mov r14, [rcx + RS_REGISTER_STATUSES_OFFSET + (6 * REGISTER_SIZE)]
        mov r15, [rcx + RS_REGISTER_STATUSES_OFFSET + (7 * REGISTER_SIZE)]
        
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
; @modified_registers: rdx, r8, r9, r10, r11, rsp
; @stack: none
; @params: RCX = ^scheduler.Stack_Snapshot
;          RDX = stack base
;          R8  = link return
; @notes: The link return parameter (r8 register) is used as the return address:
;         since the stack gets modified in this procedure, it might not contain
;         the link return address in the stack, thus it need a custom way to
;         return
;  The stack modification are similar to the ones displayed below:
;    Current stack:                         Next stack (M = modified):
;      | .. | <- base data                    | .. | <- base data
;      |----|                                 |----|
;      | lr | <- lr to base (stack base)      | lr | <- lr to base (stack base)
;      |----|                                 |----|
;      | .. |    previous                    M| .. |
;      | .. | <- procedure(s)                M| .. | <- Stack_Snapshot data
;      | .. |    data                        M| .. |
;      |----|                                M|----|
;     || lr | <- current rsp                |M| lr | <- new rsp [link return]
;     V|----|                               VM|----|
;
restore_stacksnapshot:
        mov r9, [rcx + SS_LET_OFFSET]       ; r9  = len(rcx^)
        mov r10, [rcx + SS_DATA_PTR_OFFSET] ; r10 = &rcx^[0]

        sub rdx, r9                         ; rdx = stack_base - len(rcx^)
        dec r9                              ; r9  = len(rcx^) - 1
memcopy_start:
        cmp r9, 0                           ; if r9 < 0
        jl  memcopy_end                     ;     goto memcopy_end

        mov r11b, byte [r10 + r9]           ; r11 = (byte)(rcx^[r9])
        mov byte [rdx + r9], r11b           ; (byte[^])(rdx)[r9] = r11
        dec r9                              ; r9 = r9 - 1

        jmp memcopy_start                   ; goto memcopy_start
memcopy_end:

        mov rsp, rdx                        ; rsp = rdx
        jmp r8                              ; return (stack less)

; @calling_convention: stdcall
; @modified_registers: all
; @stack: none
; @note: RCX should *not* point to a stack variable not in the base stack space
;        since it will be overwritten
; @params: RCX = ^scheduler.Procedure_Snapshot
;          RDX = stack base
restore_proceduresnapshot:
        add rcx, PS_STACK_SNAPSHOT_OFFSET   ; rcx = &rcx.stack_snapshot
        ; rdx is the same
        lea r8, [rel restore_proceduresnapshot_after_stack_restoration] ; r8 = &&restore_proceduresnapshot_after_stack_restoration
        jmp restore_stacksnapshot           ; jmp is stack-less
        ; restore_stacksnapshot(&rcx.stack_snapshot, stack base, &&restore_proceduresnapshot_after_stack_restoration)

restore_proceduresnapshot_after_stack_restoration:
        ; rcx is not modified by restore_stacksnapshot
        sub rcx, PS_STACK_SNAPSHOT_OFFSET   ; rcx = &rcx
        ; Don't save the link register on the stack
        jmp restore_registersnapshot_and_jump

; @calling_convention: stdcall
; @modified_registers: all
; @stack: 8 bytes: [0] = ^scheduler.Procedure_Context 
; @params: RCX = ^scheduler.Procedure_Context
procedurecontext_yield:
        sub rsp, REGISTER_SIZE              ; setup stack
        mov [rsp], rcx                      ; stack[0] = rcx
        
        ; rcx is the same
        mov rdx, [rcx + PC_CALLER_STACK_POINTER_OFFSET] ; rdx = rcx.caller_stack_pointer
        lea r8, [rel yield_restore_point]               ; r8 = &&yield_restore_point
        mov r9, rsp                                     ; r9 = rsp + REGISTER_SIZE
        add r9, REGISTER_SIZE
        call create_proceduresnapshot
        ; create_proceduresnapshot(
        ;     ^scheduler.Procedure_Context, 
        ;     rcx.caller_stack_pointer, 
        ;     &&yield_restore_point, 
        ;     rsp + REGISTER_SIZE,
        ; )

        mov rcx, [rsp]                      ; rcx = stack[0] (^scheduler.Procedure_Context)
        mov rsp, [rcx + PC_CALLER_STACK_POINTER_OFFSET] ; rsp = rcx.caller_stack_pointer
        add rcx, PC_CALLER_REGISTER_SNAPSHOT_OFFSET ; rcx = &rcx.caller_register_snapshot
        jmp restore_registersnapshot_and_jump
        ; restore_registersnapshot_and_jump(&rcx.caller_register_snapshot, rcx.caller_stack_pointer)

yield_restore_point:
        ret

; @calling_convention: stdcall
; @modified_registers: all
; @stack: none
; @params: RCX = ^scheduler.Procedure_Context
;          RDX = address of procedure
;          R8  = ^scheduler.Task
;          R9  = ^runtime.Context
procedurecontext_call:
        mov [rcx + PC_CALLER_STACK_POINTER_OFFSET], rsp ; rcx.caller_stack_pointer = rsp
        mov r10, rdx                        ; r10 = address of procedure
        mov r11, r8                         ; r11 = ^runtime.Context

        add rcx, PC_CALLER_REGISTER_SNAPSHOT_OFFSET ; rcx = &rcx.caller_register_snapshot
        lea rdx, [rel call_restore_point]   ; rcx = &&call_restore_point
        mov r8, rsp                         ; r8 = rsp
        call create_registersnapshot
        ; create_registersnapshot(&rcx.caller_register_snapshot, &&call_restore_point, rsp)

        sub rcx, PC_CALLER_REGISTER_SNAPSHOT_OFFSET ; rcx = ^scheduler.Procedure_Context
        mov rdx, r9                          ; rdx = ^scheduler.Task
        mov r8, r10                          ; r8 = ^runtime.Context
        jmp r10                              ; jmp address of procedure
        ; prodecure(^scheduler.Task, ^runtime.Context)
        
call_restore_point:
        ret

; @calling_convention: stdcall
; @modified_registers: all
; @stack: none
; @params: RCX = ^scheduler.Procedure_Context
procedurecontext_resume: 
        mov [rcx + PC_CALLER_STACK_POINTER_OFFSET], rsp ; rcx.caller_stack_pointer = rsp

        add rcx, PC_CALLER_REGISTER_SNAPSHOT_OFFSET ; rcx = &rcx.caller_register_snapshot
        lea rdx, [rel resume_restore_point] ; rdx, &&resume_restore_point
        mov r8, rsp                         ; r8 = rsp
        call create_registersnapshot
        ; create_registersnapshot(^scheduler.Procedure_Context, &&resume_restore_point, rsp)

        sub rcx, PC_CALLER_REGISTER_SNAPSHOT_OFFSET ; rcx = ^scheduler.Procedure_Context
        mov rdx, [rcx + PC_CALLER_STACK_POINTER_OFFSET] ; rdx = rcx.caller_stack_pointer
        jmp restore_proceduresnapshot
        ; restore_proceduresnapshot(^scheduler.Procedure_Context, rcx.caller_stack_pointer)

resume_restore_point:
        ret


; @calling_convention: stdcall
; @modified_registers: all
; @stack: none
; @params: RCX = ^scheduler.Procedure_Context
procedurecontext_force_return:
        mov rsp, [rcx + PC_CALLER_STACK_POINTER_OFFSET] ; rsp = rcx.caller_stack_pointer
        add rcx, PC_CALLER_REGISTER_SNAPSHOT_OFFSET ; rcx = &rcx.caller_register_snapshot
        jmp restore_registersnapshot_and_jump
     
