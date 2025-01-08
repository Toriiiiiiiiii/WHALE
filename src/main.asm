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

; Enqueue operation to be executed
macro enqueue opcode, operand 
{
    mov     rdi, [op_tail_ptr]
    mov     dword [op_queue + rdi], opcode
    add     rdi, 4
    mov     dword [op_queue + rdi], operand
    add     rdi, 4
    mov     [op_tail_ptr], rdi
}

; Dequeue next operation to be executed
;   -> %eax -> opcode
;   -> %edi -> operand
macro dequeue 
{
    mov     rsi, [op_head_ptr]
    mov     eax, [op_queue + rsi]
    add     rsi, 4
    mov     edi, [op_queue + rsi]
    add     rsi, 4
    mov     [op_head_ptr], rsi
}

; Push value to runtime stack
macro spush type, value 
{
    mov     rdi, [stk_ptr]  
    mov     dword [stk + rdi], type
    add     rdi, 4
    mov     dword [stk + rdi], value
    add     rdi, 4
    mov     [stk_ptr], rdi
}

; Pop value from runtime stack
;   -> %eax -> value
;   -> %edi -> type
macro spop 
{
    mov     rsi, [stk_ptr]
    sub     rsi, 4
    mov     eax, [stk + rsi]
    sub     rsi, 4
    mov     edi, [stk + rsi]
    mov     [stk_ptr], rsi
}

entry main
main:
    push    rbp                                             ; Save the stack frame
    mov     rbp, rsp
    open    input_path, O_RDONLY, input_fd                  ; Open the source file
    cmp     rax, 0                                          ; Check for error
    jge     readinput
    log     err_file_read, err_file_read.size, LOG_ERROR    ; Display error message
    exit    1                                               ; Exit with code 1
    mov     rsp, rbp
    pop     rbp
    ret
readinput:
    read    [input_fd], input, INPUT_SIZE                   ; Read the input file
    cmp     rax, 0                                          ; Check for error
    jge     readdone
    log     err_file_read, err_file_read.size, LOG_ERROR    ; Display error message
    exit    1                                               ; Exit with code 1
    mov     rsp, rbp
    pop     rbp
    ret
readdone:
    close   input_fd                                        ; Close input file

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; LEXICAL ANALYSIS
lex:
    getword input, [input_offset], token                    ; Get the next word 
    add     [input_offset], rbx                             ; Add the offset
    dec     rbx                                             ; Decrement to get token size
    cmp     rax, 0                                          ; End of file
    je      lex_done                 
    call    is_token_integer                                ; Check if token is an integer
    cmp     rax, 0                                          
    je      lex_notint
    call    get_int                                         ; Convert string to integer
    enqueue OP_PUSHINT, eax                                 ; Queue PUSH_INT operation
    jmp     lex                                             ; Restart loop
lex_notint:
    mov     rsi, token                                      ; Check if token is 'print'
    mov     rdi, tok_print
    call    streq
    cmp     rax, 0
    je      lex_notprint
    enqueue OP_PRINT, 0                                     ; Queue PRINT operation
    jmp     lex                                             ; Restart loop
lex_notprint:
    mov     rsi, token                                      ; Check if token is '+'
    mov     rdi, tok_add                                
    call    streq
    cmp     rax, 0
    je      lex_notadd
    enqueue OP_ADD, 0                                       ; Queue ADD operation
    jmp     lex                                             ; Restart loop
lex_notadd:
    mov     rsi, token                                      ; Check if token is '-'
    mov     rdi, tok_sub                                    
    call    streq
    cmp     rax, 0
    je      lex_notsub
    enqueue OP_SUB, 0                                       ; Queue SUB operation
    jmp     lex                                             ; Restart loop
lex_notsub:
    jmp     lex                                             ; Restart loop
lex_done:
    enqueue OP_EOF, 0                                       ; Queue EOF operation

;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; RUNTIME
run:
    dequeue                                                 ; Get next operation from queue
    cmp     eax, OP_EOF                                     ; Check if at end of file
    je      done
    cmp     eax, OP_PUSHINT                                 ; Check if OP == PUSH_INT
    je      pushint
    cmp     eax, OP_PRINT                                   ; Check if OP == PRINT
    je      doprint
    cmp     eax, OP_ADD                                     ; Check if OP == ADD
    je      doadd
    cmp     eax, OP_SUB                                     ; Check if OP == SUB
    je      dosub
    jmp     run                                             ; Restart loop
pushint:                                                    ; PUSH_INT
    mov     rax, rdi                                        ; Move value into EDI
    spush   TYPE_INT, eax                                   ; Push the value to the stack
    jmp     run                                             ; Restart loop
doprint:                                                    ; PRINT
    spop                                                    ; Retrieve value from stack
    cmp     edi, TYPE_INT                                   ; Type check - Integer
    je      printint                                        ; Print integer value
    jmp     run                                             ; Restart loop
printint:                                                   ; Print integer value
    mov     rdi, rax
    call    print
    jmp     run                                             ; Restart loop
doadd:                                                      ; ADD
    spop                                                    ; b = pop()
    mov     rbx, rdi                                        ; Save value & type of B
    mov     rcx, rax
    spop                                                    ; a = pop()
    cmp     rbx, rdi                                        ; Ensure types are the same
    jne     type_err
    add     rax, rcx                                        ; Add values
    spush   ebx, eax                                        ; Push result to stack
    jmp     run                                             ; Restart loop
dosub:                                                      ; SUB
    spop                                                    ; b = pop()
    mov     rbx, rdi                                        ; Save value & type of B
    mov     rcx, rax
    spop                                                    ; a = pop()
    cmp     rbx, rdi                                        ; Ensure types are the same
    jne     type_err
    sub     rax, rcx                                        ; Subtract values
    spush   ebx, eax                                        ; Push result to stack
    jmp     run                                             ; Restart loop
done:
    exit    0                                               ; Exit with code 0
    mov     rsp, rbp
    pop     rbp
    ret

type_err:
    log     err_type_mismatch, err_type_mismatch.size, LOG_ERROR
    exit    1
    mov     rsp, rbp
    pop     rbp
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
    push    rbp                                             ; Preserve stack frame
    mov     rbp, rsp
    mov     rax, 0                                          ; Reset registers
    mov     rbx, 0
strlen_lp:
    mov     al, [rdi]                                       ; Read next character
    cmp     al, 0                                           ; Break if at end of string
    je      strlen_done
    add     rbx, 1                                          ; Increment counter
    add     rdi, 1                                          ; Increment pointer
    jmp     strlen_lp                                       ; Begin next iteration
strlen_done:
    mov     rax, rbx
    mov     rsp, rbp                                        ; Restore stack frame
    pop     rbp
    ret                                                     ; Return


; streq :- Determine if two strings are equal
; Parameters:
;   -> %rdi: string 1
;   -> %rsi: string 2
;
; Return values:
;   -> %rax: 1 if strings are equal, 0 otherwise.
streq:
    push    rbp                                             ; Preserve stack fram
    mov     rbp, rsp
    mov     rax, 0                                          ; Reset RAX
    mov     rbx, 0                                          ; Reset RBX
streq_leneq:
    mov     bl, [rdi]                                       ; Get char from string 1
    mov     al, [rsi]                                       ; Get char from string 2
    cmp     rax, rbx                                        ; Compare characters
    jne     streq_neq                                       ; Return 0 if not equal
    cmp     rax, 0                                          ; Return 1 if at end of string
    je      streq_eq                                        ; Any inequalities would've been found by this point.
    inc     rsi                                             ; Increment pointers
    inc     rdi
    jmp     streq_leneq                                     ; Restart loop
streq_eq:
    mov     rax, 1                                          ; Return value = 1
    mov     rsp, rbp                                        ; Restore stack frame
    pop     rbp
    ret                                                     ; Return
streq_neq:
    mov     rax, 0                                          ; Return value = 0
    mov     rsp, rbp                                        ; Restore stack frame
    pop     rbp
    ret                                                     ; Return


; is_token_integer :- Determine if currently stored token is valid number
; Parameters:
;   -> None
;
; Return values:
;   -> %rax: 1 if token is an integer, 0 otherwise.
is_token_integer:
    push    rbp                                             ; Preserve stack frame
    mov     rbp, rsp
    mov     rdi, token                                      ; Load pointer to token
    mov     rax, 1                                          ; Return value - will stay as 1 unless overwritten
tokint_lp:
    mov     bl, [rdi]                                       ; Load next character
    cmp     bl, 0                                           ; Check if NULLCHAR
    je      tokint_dn                                       ; Break out of loop at end of string
    cmp     bl, 48                                          ; Compare character with ASCII code for '0'
    jge     tokint_high                                     ; Continue if greater
    mov     rax, 0                                          ; If less than 48, return 0
    jmp     tokint_dn
tokint_high:
    cmp     bl, 57                                          ; Compare character with ASCII code for '9'
    jle     tokint_aftercheck                               ; If <= 57, character is a numeric digit
    mov     rax, 0                                          ; Return 0 if > 57
    jmp     tokint_dn
tokint_aftercheck:
    inc     rdi                                             ; Increment pointer
    jmp     tokint_lp                                       ; Restart loop
tokint_dn:
    mov     rsp, rbp                                        ; Restore stack frame
    pop     rbp
    ret                                                     ; Return


; get_int :- Convert token value to an integer
; Parameters:
;   -> None
;
; Return values:
;   -> %rax: The integer value represented by [token]
get_int:
    push    rbp
    mov     rbp, rsp
    mov     rdi, token
    mov     rax, 0
    mov     rbx, 0
getint_lp:
    mov     bl, [rdi]
    cmp     bl, 0
    je      getint_dn
    imul    rax, 10
    sub     bl, 48
    add     rax, rbx
    inc     rdi
    jmp     getint_lp
getint_dn:
    mov     rsp, rbp
    pop     rbp
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
register
trace_level:   dq 0
trace_info:    db "INFO:    "
trace_warning: db "WARNING: "
trace_err:     db "ERROR:   "
