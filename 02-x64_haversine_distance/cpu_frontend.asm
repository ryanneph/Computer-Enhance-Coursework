global mov_all_bytes_asm
global nop_all_bytes_asm
global cmp_all_bytes_asm
global dec_all_bytes_asm


section .text

; move the element index, cast to u8 into the element memory (byte-wise)
; rdi - dest  (*u8)
; rsi - count (u64)
; ret - none
mov_all_bytes_asm:
    xor rax, rax
.loop:
    mov [rdi + rax], al
    inc rax
    cmp rax, rsi
    jb .loop
    ret

nop_all_bytes_asm:
    xor rax, rax
.loop:
    db 0x0f, 0x1f, 0x00 ; 3-byte nop
    inc rax
    cmp rax, rsi
    jb .loop
    ret

cmp_all_bytes_asm:
    xor rax, rax
.loop:
    inc rax
    cmp rax, rsi
    jb .loop
    ret

dec_all_bytes_asm:
.loop:
    dec rsi
    jnz .loop
    ret
