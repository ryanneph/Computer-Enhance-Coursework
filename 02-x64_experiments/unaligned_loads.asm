global read_32x4

section .text

read_32x4:
    %define src rdi
    %define counter rsi
    %define offset_mask rdx

    %define offset r10
    %define read_base r11
    align 64
    xor offset, offset
.loop:
    ; mask the offset and compute iteration base address
    mov read_base, src
    add read_base, offset

    ; move 256 bytes
    vmovdqu ymm0, [read_base]
    vmovdqu ymm0, [read_base + 0x20]
    vmovdqu ymm0, [read_base + 0x40]
    vmovdqu ymm0, [read_base + 0x60]

    vmovdqu ymm0, [read_base + 0x80]
    vmovdqu ymm0, [read_base + 0xa0]
    vmovdqu ymm0, [read_base + 0xc0]
    vmovdqu ymm0, [read_base + 0xe0]

    vmovdqu ymm0, [read_base + 0x100]
    vmovdqu ymm0, [read_base + 0x120]
    vmovdqu ymm0, [read_base + 0x140]
    vmovdqu ymm0, [read_base + 0x160]

    ; increment and mask offset
    add offset, 0x180
    and offset, offset_mask

    sub counter, 0x180
    jnle .loop
    ret
