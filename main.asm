    org 0x0100

start:
    ; Set 80-25 text mode
    mov ax, 0x0002
    int 0x10

setup_screen:
    mov ax, 0xb800              ; Segment for the video data
    mov ds, ax
    mov es, ax

    cld

    ; Clears the screen
    mov cx, 2000
    mov ax, 0x0800
clear:
    stosw
    loop clear

    ; Drawing the line
    mov ax, 0x3800
    mov bh, 23                   ; Starts on column
    mov dh, 37                   ; Prints X columns
    call draw_square

main_loop:
    jmp exit

    ;
    ; Draw square function
    ; Uses AX for color and char, BX for pos and DX for size
    ;
draw_square:
    xor cx, cx                      ; Resets CX
    mov cl, dh                      ; Copy length of line

    xor di, di
    push ax
    xor ax, ax
    mov al, bh
    shl al, 1
    add di, ax
    pop ax
draw_char:
    stosw
    loop draw_char
    ret

exit:
    int 0x20                    ; exit
