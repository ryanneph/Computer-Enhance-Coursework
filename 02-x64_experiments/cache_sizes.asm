global read_wrapping_pow2_32x12
global read_wrapping_nonpow2_32x16

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


; nested loops to read N bytes from a subregion of P bytes in chunks of K bytes
; per inner-loop iteration. total read size is N = P * K
;
; outer   - loop over subset of total buffer in 512-byte chunks
;   inner - simd read a small block of 16x32-byte (512 bytes)
;
; rdi - read base pointer
; rsi - read region repeat count (outer loop count)
; rdx - read region chunk count (inner loop count)
read_wrapping_nonpow2_32x16:
    align 64
    %define CHUNK_BASE r10    ; read chunk base pointer
    %define INNER_COUNTER r11 ; inner loop counter
.loop_outer:
    mov CHUNK_BASE, rdi    ; reset to the base pointer
    mov INNER_COUNTER, rdx ; reset the inner loop counter
.loop_inner:
    ; move the stuff
    vmovdqu ymm0, [CHUNK_BASE       ]
    vmovdqu ymm0, [CHUNK_BASE + 0x20]
    vmovdqu ymm0, [CHUNK_BASE + 0x40]
    vmovdqu ymm0, [CHUNK_BASE + 0x60]

    vmovdqu ymm0, [CHUNK_BASE + 0x80]
    vmovdqu ymm0, [CHUNK_BASE + 0xa0]
    vmovdqu ymm0, [CHUNK_BASE + 0xc0]
    vmovdqu ymm0, [CHUNK_BASE + 0xe0]

    vmovdqu ymm0, [CHUNK_BASE + 0x100]
    vmovdqu ymm0, [CHUNK_BASE + 0x120]
    vmovdqu ymm0, [CHUNK_BASE + 0x140]
    vmovdqu ymm0, [CHUNK_BASE + 0x160]

    vmovdqu ymm0, [CHUNK_BASE + 0x180]
    vmovdqu ymm0, [CHUNK_BASE + 0x1a0]
    vmovdqu ymm0, [CHUNK_BASE + 0x1c0]
    vmovdqu ymm0, [CHUNK_BASE + 0x1e0]

    ; advance the inner base pointer by the chunk size and repeat
    add CHUNK_BASE, 0x200
    dec INNER_COUNTER
    jnz .loop_inner

    ; check global counter
    dec rsi
    jnz .loop_outer
    ret
