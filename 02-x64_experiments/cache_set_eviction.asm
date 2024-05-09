global read_32x8

section .text

; read 4 cachelines per loop iteration
;
; where each cacheline is read with 2x 32-byte wide simd moves
; and the read address is incremented a specified amount after each cacheline
;
; proceed in this way for a specified number of cachelines, then reset and
; repeat a specified number of times.
read_32x8:
    align 64
    %define BUF rdi
    %define BUF_SIZE rsi
    %define LINE_COUNT rdx
    %define INCREMENT rcx

    %define LINE_REMAIN r10
    %define ADDR r11
.reset:
    mov ADDR, BUF
    mov LINE_REMAIN, LINE_COUNT
.loop:
    ; read cacheline #1 then advance
    vmovdqu ymm0, [ADDR       ]
    vmovdqu ymm1, [ADDR + 0x20]
    add ADDR, INCREMENT

    ; read cacheline #2 then advance
    vmovdqu ymm0, [ADDR       ]
    vmovdqu ymm1, [ADDR + 0x20]
    add ADDR, INCREMENT

    ; read cacheline #3 then advance
    vmovdqu ymm0, [ADDR       ]
    vmovdqu ymm1, [ADDR + 0x20]
    add ADDR, INCREMENT

    ; read cacheline #4 then advance
    vmovdqu ymm0, [ADDR       ]
    vmovdqu ymm1, [ADDR + 0x20]
    add ADDR, INCREMENT

    sub BUF_SIZE, 0xa0
    sub LINE_REMAIN, 4
    jg .loop

    cmp BUF_SIZE, 0
    jg .reset
    ret
