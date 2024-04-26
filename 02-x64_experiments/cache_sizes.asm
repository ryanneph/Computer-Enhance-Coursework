global read_wrapping_pow2

section .text

; rdi - read base pointer
; rsi - read byte count
; rdx - read offset mask (must be pow2)
read_wrapping_pow2:
    ; 32-byte-wide SIMD read from base pointer + masked offset to register
    ; rax - read offset
    align 64
    xor rax, rax
.loop:
    vmovdqu ymm0, [rdi + rax]
    vmovdqu ymm0, [rdi + rax + 32]
    vmovdqu ymm0, [rdi + rax + 64]
    vmovdqu ymm0, [rdi + rax + 96]
    add rax, 128
    and rax, rdx
    sub rsi, 128
    jnle .loop
    ret
