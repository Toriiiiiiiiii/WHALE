;;;;;;;;;;;;;;;;;;;;;
; Lexer functions

; Get a single word surrounded by whitespace and store it in <buf>
macro getnextword input, offset, buf {
    local ..loop
    local ..done

    mov rsi, input
    add rsi, offset
    mov rdi, buf

    mov rax, 0
    mov rbx, 0
..loop:
    mov al, [rsi]

    cmp al, 32  ; ' '  
    je ..done

    cmp al, 10  ; '\n'
    je ..done
    
    cmp al, 9   ; '\t'
    je ..done

    cmp al, 0   ; Nullchar
    je ..done

    mov [rdi], al
    inc rsi
    inc rdi
    inc rbx
    jmp ..loop

..done:
    mov byte [rdi], 0
    inc rbx
}


