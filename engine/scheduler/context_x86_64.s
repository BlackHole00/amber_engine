; TODO(Vicix): Find better reference with intel syntax
; References:
;  - asm: https://web.stanford.edu/class/cs107/resources/x86-64-reference.pdf.
;  - stdcall: https://learn.microsoft.com/en-us/cpp/build/x64-calling-convention?view=msvc-170

global get_stack_pointer
global get_location_of_this_instruction
global get_location_of_next_instruction
global advanced_jump
global simple_jump
global yield
global restore

; @calling_convention: stdcall
; @params: RCX = ^scheduler.Procedure_Context,
;          RDX = current stack address
extern procedurecontext_save_stack

; Register sizes
REGISTER_SIZE equ 8
XMM_REGISTER_SIZE equ 16

; Offsets of scheduler.Procedure_Context fields
PC_REGISTER_STATUSES_OFFSET equ 0
PC_SSE_REGISTER_STATUSES_OFFSET equ (PC_REGISTER_STATUSES_OFFSET + (REGISTER_SIZE * 10))
PC_STACK_START_REGISTER_OFFSET equ (PC_SSE_REGISTER_STATUSES_OFFSET + (XMM_REGISTER_SIZE * 10))
PC_RETURN_INSTRUCTION_POINTER_OFFSET equ (PC_STACK_START_REGISTER_OFFSET + REGISTER_SIZE)
PC_RETURN_STACK_POINTER_OFFSET equ (PC_RETURN_INSTRUCTION_POINTER_OFFSET + REGISTER_SIZE)
PC_STACK_DATA_PTR_OFFSET equ (PC_RETURN_STACK_POINTER_OFFSET + REGISTER_SIZE)
PC_STACK_LEN_OFFSET equ (PC_STACK_DATA_PTR_OFFSET + REGISTER_SIZE)

; Other
SIZE_OF_CALL_INSTRUCTION equ 12

section .text

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
                
; @calling_convention: stdcall 
; @params: RCX = ^scheduler.Procedure_Context
yield:
        mov [rcx + PC_REGISTER_STATUSES_OFFSET + (0 * REGISTER_SIZE)], rdi
        mov [rcx + PC_REGISTER_STATUSES_OFFSET + (1 * REGISTER_SIZE)], rsi
        mov [rcx + PC_REGISTER_STATUSES_OFFSET + (2 * REGISTER_SIZE)], rbx
        mov [rcx + PC_REGISTER_STATUSES_OFFSET + (3 * REGISTER_SIZE)], rbp
        mov [rcx + PC_REGISTER_STATUSES_OFFSET + (4 * REGISTER_SIZE)], rsp
        mov [rcx + PC_REGISTER_STATUSES_OFFSET + (5 * REGISTER_SIZE)], r12
        mov [rcx + PC_REGISTER_STATUSES_OFFSET + (6 * REGISTER_SIZE)], r13
        mov [rcx + PC_REGISTER_STATUSES_OFFSET + (7 * REGISTER_SIZE)], r14
        mov [rcx + PC_REGISTER_STATUSES_OFFSET + (8 * REGISTER_SIZE)], r15

        lea rax, [rel yield_rip_next_instruction]
        mov [rcx + PC_REGISTER_STATUSES_OFFSET + (9 * REGISTER_SIZE)], rax

        movups [rcx + PC_SSE_REGISTER_STATUSES_OFFSET + (0 * XMM_REGISTER_SIZE)], xmm6
        movups [rcx + PC_SSE_REGISTER_STATUSES_OFFSET + (1 * XMM_REGISTER_SIZE)], xmm7
        movups [rcx + PC_SSE_REGISTER_STATUSES_OFFSET + (2 * XMM_REGISTER_SIZE)], xmm8
        movups [rcx + PC_SSE_REGISTER_STATUSES_OFFSET + (3 * XMM_REGISTER_SIZE)], xmm9
        movups [rcx + PC_SSE_REGISTER_STATUSES_OFFSET + (4 * XMM_REGISTER_SIZE)], xmm10
        movups [rcx + PC_SSE_REGISTER_STATUSES_OFFSET + (5 * XMM_REGISTER_SIZE)], xmm11
        movups [rcx + PC_SSE_REGISTER_STATUSES_OFFSET + (6 * XMM_REGISTER_SIZE)], xmm12
        movups [rcx + PC_SSE_REGISTER_STATUSES_OFFSET + (7 * XMM_REGISTER_SIZE)], xmm13
        movups [rcx + PC_SSE_REGISTER_STATUSES_OFFSET + (8 * XMM_REGISTER_SIZE)], xmm14
        movups [rcx + PC_SSE_REGISTER_STATUSES_OFFSET + (9 * XMM_REGISTER_SIZE)], xmm15

        sub rsp, 8
        mov [rsp], rcx

        mov rdx, rsp
        ; Account for rcx in the stack
        add rdx, 8
        call procedurecontext_save_stack

        mov rcx, [rsp]

        mov rsp, [rcx + PC_RETURN_STACK_POINTER_OFFSET]
        jmp [rcx + PC_RETURN_INSTRUCTION_POINTER_OFFSET]

yield_rip_next_instruction:
        ret

; @calling_convention: stdcall
; @params: RCX = ^scheduler.Procedure_Context
;          RDX = new_stack_base
restore:
        mov rsp, rdx
        
        ; Poor man's mem copy
        mov rax, [rcx + PC_STACK_DATA_PTR_OFFSET]
        mov rbx, [rcx + PC_STACK_LEN_OFFSET]

mem_copy_loop_start:
        cmp rbx, 0
        jle mem_copy_loop_end

        mov r8, [rbx]
        mov [rsp], rbx
        sub rsp, REGISTER_SIZE
        sub rbx, REGISTER_SIZE
mem_copy_loop_end:
        
        mov rdi, [rcx + PC_REGISTER_STATUSES_OFFSET + (0 * REGISTER_SIZE)] 
        mov rsi, [rcx + PC_REGISTER_STATUSES_OFFSET + (1 * REGISTER_SIZE)] 
        mov rbx, [rcx + PC_REGISTER_STATUSES_OFFSET + (2 * REGISTER_SIZE)] 
        mov rbp, [rcx + PC_REGISTER_STATUSES_OFFSET + (3 * REGISTER_SIZE)] 
        mov rsp, [rcx + PC_REGISTER_STATUSES_OFFSET + (4 * REGISTER_SIZE)] 
        mov r12, [rcx + PC_REGISTER_STATUSES_OFFSET + (5 * REGISTER_SIZE)] 
        mov r13, [rcx + PC_REGISTER_STATUSES_OFFSET + (6 * REGISTER_SIZE)] 
        mov r14, [rcx + PC_REGISTER_STATUSES_OFFSET + (7 * REGISTER_SIZE)] 
        mov r15, [rcx + PC_REGISTER_STATUSES_OFFSET + (8 * REGISTER_SIZE)] 

        movups [rcx + PC_SSE_REGISTER_STATUSES_OFFSET + (0 * XMM_REGISTER_SIZE)], xmm6
        movups [rcx + PC_SSE_REGISTER_STATUSES_OFFSET + (1 * XMM_REGISTER_SIZE)], xmm7
        movups [rcx + PC_SSE_REGISTER_STATUSES_OFFSET + (2 * XMM_REGISTER_SIZE)], xmm8
        movups [rcx + PC_SSE_REGISTER_STATUSES_OFFSET + (3 * XMM_REGISTER_SIZE)], xmm9
        movups [rcx + PC_SSE_REGISTER_STATUSES_OFFSET + (4 * XMM_REGISTER_SIZE)], xmm10
        movups [rcx + PC_SSE_REGISTER_STATUSES_OFFSET + (5 * XMM_REGISTER_SIZE)], xmm11
        movups [rcx + PC_SSE_REGISTER_STATUSES_OFFSET + (6 * XMM_REGISTER_SIZE)], xmm12
        movups [rcx + PC_SSE_REGISTER_STATUSES_OFFSET + (7 * XMM_REGISTER_SIZE)], xmm13
        movups [rcx + PC_SSE_REGISTER_STATUSES_OFFSET + (8 * XMM_REGISTER_SIZE)], xmm14
        movups [rcx + PC_SSE_REGISTER_STATUSES_OFFSET + (9 * XMM_REGISTER_SIZE)], xmm15

        mov [rcx + PC_STACK_START_REGISTER_OFFSET], rdx

        lea rdx, [rel restore_rip_next_instruction]
        mov [rcx + PC_RETURN_INSTRUCTION_POINTER_OFFSET], rdx
        mov [rcx + PC_RETURN_STACK_POINTER_OFFSET], rsp
        
        ; Should jump to yield_rip_next_instruction
        jmp [rcx + PC_REGISTER_STATUSES_OFFSET + (9 * REGISTER_SIZE)] 

restore_rip_next_instruction:
        ret

        
