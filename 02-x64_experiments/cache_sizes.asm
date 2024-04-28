global read_wrapping_pow2_32x12

section .text

; rdi - read base pointer
; rsi - read byte count
; rdx - read offset mask (must be pow2)
read_wrapping_pow2_32x12:
    ; 32-byte-wide SIMD read from base pointer + masked offset to register
    ; r10 - read offset
    ; r11 - pointer
    align 64
    xor r10, r10
.loop:
    ; compute pointer
    mov r11, rdi
    add r11, r10

    ; move the stuff
    vmovdqu ymm0, [r11       ]
    vmovdqu ymm0, [r11 + 0x20]
    vmovdqu ymm0, [r11 + 0x40]
    vmovdqu ymm0, [r11 + 0x60]

    vmovdqu ymm0, [r11 + 0x80]
    vmovdqu ymm0, [r11 + 0xa0]
    vmovdqu ymm0, [r11 + 0xc0]
    vmovdqu ymm0, [r11 + 0xe0]

    vmovdqu ymm0, [r11 + 0x100]
    vmovdqu ymm0, [r11 + 0x120]
    vmovdqu ymm0, [r11 + 0x140]
    vmovdqu ymm0, [r11 + 0x160]

    ; advance offset
    add r10, 0x180
    and r10, rdx

    ; decrement counter
    sub rsi, 0x180
    jnle .loop
    ret
