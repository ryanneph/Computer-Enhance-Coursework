;
; LOAD
;
global read_4x2
global read_8x2
global read_16x2
global read_32x2

global read_4x3
global read_8x3
global read_16x3
global read_32x3

global read_4x4
global read_8x4
global read_16x4
global read_32x4

section .text

; rdi - data pointer
; rsi - count
read_4x2:
    align 64
.loop:
    mov eax, [rdi]
    mov eax, [rdi + 4]
    sub rsi, 8
    jnle .loop
    ret

read_8x2:
    align 64
.loop:
    mov rax, [rdi]
    mov rax, [rdi + 8]
    sub rsi, 16
    jnle .loop
    ret

read_16x2:
    align 64
.loop:
    vmovdqu xmm0, [rdi]
    vmovdqu xmm1, [rdi + 16]
    sub rsi, 32
    jnle .loop
    ret

read_32x2:
    align 64
.loop:
    vmovdqu ymm0, [rdi]
    vmovdqu ymm1, [rdi + 32]
    sub rsi, 64
    jnle .loop
    ret


read_4x3:
    align 64
.loop:
    mov eax, [rdi]
    mov eax, [rdi + 4]
    mov eax, [rdi + 8]
    sub rsi, 12
    jnle .loop
    ret

read_8x3:
    align 64
.loop:
    mov rax, [rdi]
    mov rax, [rdi + 8]
    mov rax, [rdi + 16]
    sub rsi, 24
    jnle .loop
    ret

read_16x3:
    align 64
.loop:
    vmovdqu xmm0, [rdi]
    vmovdqu xmm1, [rdi + 16]
    vmovdqu xmm2, [rdi + 32]
    sub rsi, 48
    jnle .loop
    ret

read_32x3:
    align 64
.loop:
    vmovdqu ymm0, [rdi]
    vmovdqu ymm1, [rdi + 32]
    vmovdqu ymm2, [rdi + 64]
    sub rsi, 96
    jnle .loop
    ret

read_4x4:
    align 64
.loop:
    mov eax, [rdi]
    mov eax, [rdi + 4]
    mov eax, [rdi + 8]
    mov eax, [rdi + 12]
    sub rsi, 16
    jnle .loop
    ret

read_8x4:
    align 64
.loop:
    mov rax, [rdi]
    mov rax, [rdi + 8]
    mov rax, [rdi + 16]
    mov rax, [rdi + 24]
    sub rsi, 32
    jnle .loop
    ret

read_16x4:
    align 64
.loop:
    vmovdqu xmm0, [rdi]
    vmovdqu xmm1, [rdi + 16]
    vmovdqu xmm2, [rdi + 32]
    vmovdqu xmm3, [rdi + 48]
    sub rsi, 64
    jnle .loop
    ret

read_32x4:
    align 64
.loop:
    vmovdqu ymm0, [rdi]
    vmovdqu ymm1, [rdi + 32]
    vmovdqu ymm2, [rdi + 64]
    vmovdqu ymm3, [rdi + 96]
    sub rsi, 128
    jnle .loop
    ret
