;
; LOAD
;
global read_8x1
global read_8x2
global read_8x3
global read_8x4
global read_1x16

section .text

; rdi - data pointer
; rsi - count
read_8x1:
    align 64
.loop:
    mov rax, [rdi]
    sub rsi, 8
    jnle .loop
    ret

read_8x2:
    align 64
.loop:
    mov rax, [rdi]
    mov rax, [rdi]
    sub rsi, 16
    jnle .loop
    ret

read_8x3:
    align 64
.loop:
    mov rax, [rdi]
    mov rax, [rdi]
    mov rax, [rdi]
    sub rsi, 24
    jnle .loop
    ret

read_8x4:
    align 64
.loop:
    mov rax, [rdi]
    mov rax, [rdi]
    mov rax, [rdi]
    mov rax, [rdi]
    sub rsi, 32
    jnle .loop
    ret

read_1x16:
    align 64
.loop:
%rep 16
    mov al, [rdi]
%endrep
    sub rsi, 16
    jnle .loop
    ret


;
; STORE
;
global write_8x1
global write_8x2
global write_8x3
global write_8x4
global write_1x16

; rdi - data pointer
; rsi - count
write_8x1:
    align 64
.loop:
    mov [rdi], rax
    sub rsi, 8
    jnle .loop
    ret

write_8x2:
    align 64
.loop:
    mov [rdi], rax
    mov [rdi], rax
    sub rsi, 16
    jnle .loop
    ret

write_8x3:
    align 64
.loop:
    mov [rdi], rax
    mov [rdi], rax
    mov [rdi], rax
    sub rsi, 24
    jnle .loop
    ret

write_8x4:
    align 64
.loop:
    mov [rdi], rax
    mov [rdi], rax
    mov [rdi], rax
    mov [rdi], rax
    sub rsi, 32
    jnle .loop
    ret

write_1x16:
    align 64
.loop:
%rep 16
    mov [rdi], al
%endrep
    sub rsi, 16
    jnle .loop
    ret
