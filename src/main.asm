format ELF64 executable 3
segment readable executable 

INPUT_SIZE = 8192

OP_PUSHINT = 0
OP_ADD     = 1
OP_SUB     = 2
OP_MUL     = 3
OP_DIV     = 4
OP_PRINT   = 5
OP_EOF     = 6

TYPE_INT = 0

include "sys.inc"
include "log.inc"
include "strucs.inc"
include "lexer.inc"
include "print.inc"

macro enqueue_op opcode, operand {
    mov rdi, [op_tail_ptr]
    mov dword [op_queue + rdi], opcode
    add rdi, 4
    mov dword [op_queue + rdi], operand
    add rdi, 4
    mov [op_tail_ptr], rdi
}

macro dequeue_op {
    mov rsi, [op_head_ptr]
    mov eax, [op_queue + rsi]
    add rsi, 4
    mov edi, [op_queue + rsi]
    add rsi, 4
    mov [op_head_ptr], rsi
}

macro stack_push type, value {
    mov rdi, [stk_ptr]  
    mov dword [stk + rdi], type
    add rdi, 4
    mov dword [stk + rdi], value
    add rdi, 4
    mov [stk_ptr], rdi
}

macro stack_pop {
    mov rsi, [stk_ptr]
    sub rsi, 4
    mov eax, [stk + rsi]
    sub rsi, 4
    mov edi, [stk + rsi]
    mov [stk_ptr], rsi
}

entry main
main:
    push rbp                                            ; Save the stack frame
    mov rbp, rsp

    open input_path, O_RDONLY, input_fd                 ; Open the source file
    cmp rax, 0                                          ; Check for error
    jge readinput

    log err_file_read, err_file_read.size, LOG_ERROR    ; Display error message
    exit 1                                              ; Exit with code 1
    mov rsp, rbp
    pop rbp
    ret

readinput:
    read [input_fd], input, INPUT_SIZE                  ; Read the input file
    cmp rax, 0                                          ; Check for error
    jge readdone

    log err_file_read, err_file_read.size, LOG_ERROR    ; Display error message
    exit 1                                              ; Exit with code 1
    mov rsp, rbp
    pop rbp
    ret

readdone:
    close input_fd                                      ; Close input file

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; LEXICAL ANALYSIS
lex:
    getnextword input, [input_offset], token            ; Get the next word 
    add [input_offset], rbx                             ; Add the offset
    dec rbx                                             ; Decrement to get token size

    cmp rax, 0                                          ; End of file
    je lex_done                 

    call is_token_integer   
    cmp rax, 0
    je lex_notint

    call get_int
    enqueue_op OP_PUSHINT, eax
    jmp lex

lex_notint:
    mov rsi, token
    mov rdi, tok_print
    call streq
    cmp rax, 0
    je lex_notprint

    enqueue_op OP_PRINT, 0
    jmp lex

lex_notprint:
    mov rsi, token
    mov rdi, tok_add
    call streq
    cmp rax, 0
    je lex_notadd

    enqueue_op OP_ADD, 0
    jmp lex

lex_notadd:
    mov rsi, token
    mov rdi, tok_sub
    call streq
    cmp rax, 0
    je lex_notsub

    enqueue_op OP_SUB, 0
    jmp lex

lex_notsub:
    jmp lex

lex_done:
    enqueue_op OP_EOF, 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; RUNTIME
run:
    dequeue_op
    cmp eax, OP_EOF
    je done

    cmp eax, OP_PUSHINT
    je pushint

    cmp eax, OP_PRINT
    je doprint

    cmp eax, OP_ADD
    je doadd

    cmp eax, OP_SUB
    je dosub

    jmp run

pushint:
    mov rax, rdi
    stack_push TYPE_INT, eax

    jmp run

doprint:
    stack_pop

    cmp edi, TYPE_INT
    je printint

    jmp run

printint:
    mov rdi, rax
    call print
    jmp run

doadd:
    stack_pop

    mov rbx, rdi
    mov rcx, rax

    stack_pop

    cmp rbx, rdi
    jne type_err

    add rax, rcx
    stack_push ebx, eax
    jmp run

dosub:
    stack_pop

    mov rbx, rdi
    mov rcx, rax

    stack_pop

    cmp rbx, rdi
    jne type_err

    sub rax, rcx
    stack_push ebx, eax
    jmp run
    
done:
    ; Exit program
    exit 0                                              ; Exit with code 0
    mov rsp, rbp
    pop rbp
    ret

type_err:
    log err_type_mismatch, err_type_mismatch.size, LOG_ERROR
    exit 1
    mov rsp, rbp
    pop rbp
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;
; Utility functions

; strlen :- Get length of a c-style string.
; Parameters:
;   -> %rdi: string to get the length of
;
; Return values:
;   -> %rax: length of the string
strlen:
    push rbp                                            ; Preserve stack frame
    mov rbp, rsp

    mov rax, 0                                          ; Reset registers
    mov rbx, 0
strlen_lp:
    mov al, [rdi]                                       ; Read next character
    cmp al, 0                                           ; Break if at end of string
    je strlen_done

    add rbx, 1                                             ; Increment counter
    add rdi, 1                                             ; Increment pointer
    jmp strlen_lp                                       ; Begin next iteration

strlen_done:
    mov rax, rbx
    mov rsp, rbp                                        ; Restore stack frame
    pop rbp
    ret                                                 ; Return


streq:
    push rbp
    mov rbp, rsp

    mov rax, 0
    mov rbx, 0
streq_leneq:
    mov al, [rsi]
    mov bl, [rdi]

    cmp rax, rbx
    jne streq_neq

    cmp rax, 0
    je streq_eq

    inc rsi
    inc rdi
    jmp streq_leneq

streq_eq:
    mov rax, 1
    mov rsp, rbp
    pop rbp
    ret

streq_neq:
    mov rax, 0
    mov rsp, rbp
    pop rbp
    ret


is_token_integer:
    push rbp
    mov rbp, rsp

    mov rdi, token
    mov rax, 1
tokint_lp:
    mov bl, [rdi]
    cmp bl, 0
    je tokint_dn

    cmp bl, 48
    jge tokint_high

    mov rax, 0
    jmp tokint_dn

tokint_high:
    cmp bl, 57
    jle tokint_aftercheck

    mov rax, 0
    jmp tokint_dn

tokint_aftercheck:
    inc rdi
    jmp tokint_lp

tokint_dn:
    mov rsp, rbp
    pop rbp
    ret

get_int:
    push rbp
    mov rbp, rsp

    mov rdi, token
    mov rax, 0
    mov rbx, 0
getint_lp:
    mov bl, [rdi]
    cmp bl, 0
    je getint_dn

    imul rax, 10
    sub bl, 48
    add rax, rbx
    
    inc rdi
    jmp getint_lp

getint_dn:
    mov rsp, rbp
    pop rbp
    ret


segment readable writeable

err_file_read str "Could not read file.", 10
err_type_mismatch str "Type mismatch.", 10
newln str 10

push_msg str "Pushing integer value!", 10
print_msg str "Printing something!", 10

; Allocate 16mb to input string
input: rb INPUT_SIZE
input_offset: dq 0
input_path: db "test.wle"
input_fd: dq 0

token: rb 512

tok_print db "print", 0
tok_add   db "+", 0
tok_sub   db "-", 0

; Operation consists of 2 dwords (big endian):
; High: Operation
; Low: Operand
op_queue: rq 8192
op_tail_ptr: dq 0
op_head_ptr: dq 0

; Stack value consists of 2 dwords (big endian):
; High: Type
; Low: Value
stk: rq 8192
stk_ptr: dq 0

trace_level:   dq 0
trace_info:    db "INFO:    "
trace_warning: db "WARNING: "
trace_err:     db "ERROR:   "
