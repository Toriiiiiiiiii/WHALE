;;;;;;;;;;;;;;;;;;;;;
; Lexer functions

; Get a single word surrounded by whitespace and store it in <buf>
macro getword input, offset, buf 
{
    local   ..loop                  ; Define local labels
    local   ..done                  ; Only accessible from within the macro.
    mov     rsi, input              ; Load the input string into RSI
    add     rsi, offset             ; Add the input offset to RSI
    mov     rdi, buf                ; Load the buffer address into RDI
    mov     rax, 0                  ; RAX is used to store the last character
    mov     rbx, 0                  ; RBX is used to return the number of bytes read
..loop:
    mov     al, [rsi]               ; Load the next character from the input
    cmp     al, 32                  ; ' '  
    je      ..done
    cmp     al, 10                  ; '\n'
    je      ..done
    cmp     al, 9                   ; '\t'
    je      ..done
    cmp     al, 0                   ; Nullchar
    je      ..done                  ; End of buffer reached.
    mov     [rdi], al               ; Store the character to output buffer
    inc     rsi                     ; Incrememnt source pointer
    inc     rdi                     ; Increment buffer pointer
    inc     rbx                     ; Increment read counter
    jmp     ..loop                  ; Restart loop
..done:
    mov     byte [rdi], 0           ; null-terminate output buffer
    inc     rbx                     ; Increment read counter
}


