; TODO(Vicix): Find better reference with intel syntax
; References:
;  - asm: https://web.stanford.edu/class/cs107/resources/x86-64-reference.pdf.
;  - stdcall: https://learn.microsoft.com/en-us/cpp/build/x64-calling-convention?view=msvc-170

global get_stack_pointer
global get_location_of_this_instruction
global get_location_of_next_instruction
global advanced_jump
global simple_jump
; global yield
; global restore
global create_proceduresnapshot
global restore_proceduresnapshot
global create_proceduresnapshot_restore_point

; ; @calling_convention: stdcall
; ; @params: RCX = ^scheduler.Procedure_Context,
; ;          RDX = current stack address
; extern procedurecontext_save_stack

; @calling_convention: stdcall
; @params: RCX = ^scheduler.Stack_Snapshot
;          RDX = stack end
;          R8  = current stack
extern create_stacksnapshot

; Register sizes
REGISTER_SIZE equ 8
XMM_REGISTER_SIZE equ 16

; Offsets of scheduler.Procedure_Context fields
; PC_REGISTER_STATUSES_OFFSET equ 0
; PC_SSE_REGISTER_STATUSES_OFFSET equ (PC_REGISTER_STATUSES_OFFSET + (REGISTER_SIZE * 10))
; PC_STACK_START_REGISTER_OFFSET equ (PC_SSE_REGISTER_STATUSES_OFFSET + (XMM_REGISTER_SIZE * 10))
; PC_RETURN_INSTRUCTION_POINTER_OFFSET equ (PC_STACK_START_REGISTER_OFFSET + REGISTER_SIZE)
; PC_RETURN_STACK_POINTER_OFFSET equ (PC_RETURN_INSTRUCTION_POINTER_OFFSET + REGISTER_SIZE)
; PC_STACK_DATA_PTR_OFFSET equ (PC_RETURN_STACK_POINTER_OFFSET + REGISTER_SIZE)
; PC_STACK_LEN_OFFSET equ (PC_STACK_DATA_PTR_OFFSET + REGISTER_SIZE)

; Offsets of scheduler.Register_Snapshot
RS_REGISTER_STATUSES_OFFSET equ 0
RS_SSE_REGISTER_STATUSES_OFFSET equ (RS_REGISTER_STATUSES_OFFSET + (REGISTER_SIZE * 10))
RS_SIZE equ (RS_SSE_REGISTER_STATUSES_OFFSET + (XMM_REGISTER_SIZE * 10))

; Offsets of scheduler.Stack_Snapshot
SS_DATA_PTR_OFFSET equ 0
SS_LET_OFFSET equ (SS_DATA_PTR_OFFSET + REGISTER_SIZE)

; Offsets of scheduler.Procedure_Snapshot
PS_REGISTER_SNAPSHOT_OFFSET equ 0
PS_STACK_SNAPSHOT_OFFSET equ (PS_REGISTER_SNAPSHOT_OFFSET + RS_SIZE)

; Other
SIZE_OF_CALL_INSTRUCTION equ 12

section .text

; @calling_convention: stdcall
; @modified_registers: none
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
        mov [rcx + RS_REGISTER_STATUSES_OFFSET + (8 * REGISTER_SIZE)], rdx
        mov [rcx + RS_REGISTER_STATUSES_OFFSET + (9 * REGISTER_SIZE)], r8
        
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
; @stack: 8 bytes: [0] = stack start
; @params: RCX = ^scheduler.Procedure_Snapshot
;          RDX = stack start
;          R8  = restore point instruction [nullable]
create_proceduresnapshot:
        sub rsp, REGISTER_SIZE
        mov [rsp], rdx
        
        ; rcx is the same parameter
        lea rdx, [rel create_proceduresnapshot_restore_point]
        mov r8,  rsp
        add r8, REGISTER_SIZE ; Account for stack size
        call create_registersnapshot

        ; rcx and r8 do not get modified by create_registersnapshot
        add rcx, PS_STACK_SNAPSHOT_OFFSET
        mov rdx, [rsp]
        ; r8 is the same parameter
        call create_stacksnapshot
        
        add rsp, REGISTER_SIZE

create_proceduresnapshot_restore_point:
        ret

; @calling_convention: stdcall
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
        ; mov rsp, [rcx + RS_REGISTER_STATUSES_OFFSET + (8 * REGISTER_SIZE)]
        
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
; @dirty_registers: rdx, r8, r9, r10
; @params: RCX = ^scheduler.Stack_Snapshot
;          RDX = stack base
;          R8  = link return
; @notes:
;  TODO(Vicix): This graph should be reversed, since rsp grows torwards the 
;               bottom
;  Current stack:                           Next stack (M = modified):
;    |----|                                  M|----|
;    | lr | <- current rsp                   M| lr | <- new rsp [link return]
;    |----|                                  M|----|
;    | .. |    previous                      M| .. |
;    | .. | <- procedure(s)                  M| .. | <- Stack_Snapshot data
;    | .. |    data                          M| .. |
;    |----|                                   |----|
;    | lr | <- lr to base (stack base)        | lr | <- lr to base (stack base)
;    |----|                                   |----|
;    | .. | <- base data                      | .. | <- base data
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

; TODO(Vicix): Make this work with also stack variables
; @calling_convention: stdcall
; @note: RCX should *not* point to a stack variable since it will be overwritten
; @params: RCX = ^scheduler.Procedure_Snapshot
;          RDX = stack base
restore_proceduresnapshot:
        add rcx, PS_STACK_SNAPSHOT_OFFSET
        ; rdx is the same
        lea r8, [rel restore_proceduresnapshot_after_stack_restoration]
        jmp restore_stacksnapshot

restore_proceduresnapshot_after_stack_restoration:
        ; rcx is not modified by restore_stacksnapshot
        sub rcx, PS_STACK_SNAPSHOT_OFFSET
        ; Don't save the link register on the stack
        jmp restore_registersnapshot_and_jump

; @calling_convention: stdcall
; @params: RCX = ^scheduler.Procedure_Context
yield:
        

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; @calling_convention: none
; @note: this function in stdcall should not cause anything to be stored in the
;        stack (thus the stack pointer should be the same as the caller)
; @return: current stack pointer
get_stack_pointer:
        mov rax, rsp
        add rax, REGISTER_SIZE  ; Account for the link return size as it is also 
                                ; implicitly stored into the stack when the call 
                                ; instruction is used
        ret

; @calling_convention: none
; @return: the location of the `call get_location_of_this_function` instruction
get_location_of_this_instruction:
        pop rcx ; Since there isn't any argument, the first thing in the stack
                ; is the link return register (which points to the next 
                ; instruction is the caller procedure)
        mov rax, rcx
        sub rax, SIZE_OF_CALL_INSTRUCTION       ; If the location of the call
                                                ; instruction is needed we need
                                                ; to put the instruction
                                                ; register back to the desired
                                                ; instruction
        jmp rcx ; Since rcx is no longer into the stack, it is not possible to
                ; call ret, so we jump instead.

; @calling_convention: none
; @note: this procedure gets the address of the next *assembly* instruction,
;        which is almost always a stack manipulation instruction.
; @return: the location of the instruction that comes after the `call 
;          get_location_of_next_instruction`
get_location_of_next_instruction:
        pop rax
        jmp rax

; @calling_convention: stdcall
; @params: RCX = jump instruction target
;          RDX = stack pointer target
advanced_jump:
        mov rsp, rdx
        jmp rcx

; @calling_convention: stdcall
; @note: Since this procedure does not manipulate the stack, you should only use
;        this to jump within the function
; @params: RCX = jump instruction target
simple_jump:
        pop rax ; Pops the link return
        jmp rcx
                
