global read_x1
global read_x2
global read_x3
global read_x4
global read_1x2
global read_8x2

section .text

; rdi - data pointer
; rsi - count
read_x1:
    align 64
.loop:
    mov rax, [rdi]
    sub rsi, 1
    jnle .loop
    ret

read_x2:
    align 64
.loop:
    mov rax, [rdi]
    mov rax, [rdi]
    sub rsi, 2
    jnle .loop
    ret

read_x3:
    align 64
.loop:
    mov rax, [rdi]
    mov rax, [rdi]
    mov rax, [rdi]
    sub rsi, 3
    jnle .loop
    ret

read_x4:
    align 64
.loop:
    mov rax, [rdi]
    mov rax, [rdi]
    mov rax, [rdi]
    mov rax, [rdi]
    sub rsi, 4
    jnle .loop
    ret

read_1x2:
    align 64
.loop:
    mov al, [rdi]
    mov al, [rdi]
    sub rsi, 2
    jnle .loop
    ret

read_8x2:
    align 64
.loop:
    mov rax, [rdi]
    mov rax, [rdi]
    sub rsi, 2
    jnle .loop
    ret
