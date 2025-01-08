; Syscall codes
SYS_READ  = 0
SYS_WRITE = 1
SYS_OPEN  = 2
SYS_CLOSE = 3
SYS_EXIT  = 60

; File open flags
O_RDONLY = 0
O_WRONLY = 1
O_RDWR   = 2
O_CREAT  = 64

; File permission flags
S_IRWXU = 448
S_IROTH = 4
S_IWOTH = 2
S_IWUSR = 128
S_IRUSR = 256

; Standard file descriptors
STDIN  = 0
STDOUT = 1
STDERR = 2

; Read up to <count> bytes from file <fd> into <buf>
macro read fd, buf, count 
{
    mov     rax, SYS_READ
    mov     rdi, fd
    mov     rsi, buf
    mov     rdx, count
    syscall
}

; Write <size> bytes from <buf> to file <fd>
macro write fd, buf, size 
{
    mov     rax, SYS_WRITE
    mov     rdi, fd
    mov     rsi, buf
    mov     rdx, size
    syscall
}

; Exit from program with code <code>
macro exit code 
{
    mov     rax, SYS_EXIT
    mov     rdi, code
    syscall
}

; Open file <path> with flags <flags> and store file descriptor in <fd>
macro open path, flags, fd
{
    mov     rax, SYS_OPEN
    mov     rdi, path
    mov     rsi, flags
    mov     rdx, S_IRUSR or S_IWUSR
    syscall
    mov     [fd], rax
}

; Close file with descriptor stored at <fd>
macro close fd
{
    mov     rax, SYS_CLOSE
    mov     rdi, [fd]
    syscall
}
