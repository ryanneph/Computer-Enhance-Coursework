section .text

global mov_32x2
mov_32x2:
    %define DST rdi
    %define DST_SIZE rsi
    %define SRC rdx
    %define SRC_SIZE rcx
    align 64
.reset_src
    ; prepare src read loop counter
    %define READ_ADDR  r11
    %define READ_REMAIN r10
    mov READ_ADDR, SRC
    mov READ_REMAIN, SRC_SIZE
.loop:
    ; read cacheline
    vmovdqa ymm0, [READ_ADDR]
    vmovdqa ymm1, [READ_ADDR + 0x20]

    ; write cacheline (w/ non-temporal hint)
    vmovdqa [DST       ], ymm0
    vmovdqa [DST + 0x20], ymm1

    ; advance read/write pointers
    add READ_ADDR, 0x40
    add DST, 0x40

    ; reached the end of DEST?
    sub DST_SIZE, 0x40
    jbe .end

    ; reached the end of SOURCE?
    sub READ_REMAIN, 0x40
    jbe .reset_src
    jmp .loop
.end:
    ret

global mov_32x2_nt
mov_32x2_nt:
    %define DST rdi
    %define DST_SIZE rsi
    %define SRC rdx
    %define SRC_SIZE rcx
    align 64
.reset_src
    ; prepare src read loop counter
    %define READ_ADDR  r11
    %define READ_REMAIN r10
    mov READ_ADDR, SRC
    mov READ_REMAIN, SRC_SIZE
.loop:
    ; read cacheline
    vmovdqa ymm0, [READ_ADDR]
    vmovdqa ymm1, [READ_ADDR + 0x20]

    ; write cacheline (w/ non-temporal hint)
    vmovntdq [DST       ], ymm0
    vmovntdq [DST + 0x20], ymm1

    ; advance read/write pointers
    add READ_ADDR, 0x40
    add DST, 0x40

    ; reached the end of DEST?
    sub DST_SIZE, 0x40
    jbe .end

    ; reached the end of SOURCE?
    sub READ_REMAIN, 0x40
    jbe .reset_src
    jmp .loop
.end:
    ret
