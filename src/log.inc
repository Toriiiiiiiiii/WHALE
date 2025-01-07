LOG_INFO    = 0
LOG_WARNING = 1
LOG_ERROR   = 2

macro log msg, size, level {
    local ..ignore
    mov rax, level
    cmp rax, [trace_level]
    jl ..ignore

    mov rsi, level
    imul rsi, 9
    add rsi, trace_info
    write 1, rsi, 9
    write 1, msg, size
..ignore:
}
