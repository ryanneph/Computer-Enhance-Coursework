global read_cacheline_strided

section .text

; read 4 cachelines per loop iteration
;
; where each cacheline is read with 2x 32-byte wide simd moves
; and the read address is incremented a specified amount after each cacheline
;
; proceed in this way for a specified number of cachelines, then reset and
; repeat a specified number of times.
read_cacheline_strided:
    align 64
    %define SOURCE rdi ; data pointer
    %define REPEAT_COUNT rsi ; outer loop counter
    %define LINE_COUNT rdx ; inner loop counter (unique memory read)
    %define STRIDE rcx ; increment between cacheline reads

    %define LINE_REMAIN r10
    %define ADDR r11
.outer_loop:
    mov ADDR, SOURCE
    mov LINE_REMAIN, LINE_COUNT
.inner_loop:
    ; read cacheline #1 then advance
    vmovdqu ymm0, [ADDR       ]
    vmovdqu ymm1, [ADDR + 0x20]
    add ADDR, STRIDE

    dec LINE_REMAIN
    jg .inner_loop

    dec REPEAT_COUNT
    jg .outer_loop
    ret
