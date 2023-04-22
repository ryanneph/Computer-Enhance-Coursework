bits 16

; Setup the stack
mov sp, 65535;

get_user_input:
    ; Interrupt 1 is defined to get a 16-bit integer from the user and
    ; store to memory addressed by [dx].
    mov dx, 8000
    int 1

    ; Interrupt 2 is defined to print a 16-bit integer (stored in register dx),
    ; prepended by a string stored to memory addressed by [cx].
    mov cx, print_prefix
    mov dx, [8000]
    int 2

    jmp get_user_input



section .data
; The 8086 simulator loads the program at byte 0 of a special memory region
; (separate from the processor's addressable memory), and sets ip to 0.
; So we must put all non-instruction data after the program data.
print_prefix: db "Program says: ",0

