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

    ; Drawing the box
    push 0x3800
    push 0x0F25                 ; Rect size 37x15 (25x0F)
    push 44                     ; Offset 23 chars on left
    push 160 * 5                ; Offset 7 lines on top
    call draw_box

    ; Game title
    mov ah, 0x6c
    mov bp, title_string
    mov cx, 64
    call print_string

    ; Credits
    mov ah, 0x0c
    mov bp, credits_string
    mov cx, 3948
    call print_string

main_loop:
    jmp exit

    ;
    ; Draw box function
    ; Params: (1) Line offset       (bp+2)
    ;         (2) Row offset        (bp+4)
    ;         (3) Box dimensions    (bp+6)
    ;         (4) Char/Color        (bp+8)
    ;
draw_box:
    mov bp, sp                      ; Store the base of the stack, to get arguments
    xor di, di                      ; Sets DI to screen origin
    add di, [bp+2]                  ; Adds the line offset to DI

    mov dx, [bp+6]                  ; Copy dimensions of the box
    mov ax, [bp+8]                  ; Copy the char/color to print
    xor bx, bx
    mov bl, dh                      ; Get the height of the box

    xor cx, cx                      ; Resets CX
    mov cl, dl                      ; Copy the width of the box
    add di, [bp+4]                  ; Adds the line offset to DI

draw_char:
    stosw
    loop draw_char

    add word [bp+2], 160            ; Add a line (180 bytes) to offset
    sub word [bp+6], 0x0100         ; Remove one line of height - it's 0x0100 because height is stored in the msb
    mov cx, [bp+6]                  ; Copy the size of the box to test
    cmp ch, 0                       ; Test the hight of the box
    jnz draw_box                    ; If not zero, draw the rest of the box
    ret


    ;
    ; Print string function
    ; Params:   AH - background/foreground color
    ;           BP - string addr
    ;           CX - position/offset
    ;
print_string:
    mov di, cx
    mov al, byte [bp]
    cmp al, 0
    jz _0
    stosw
    add cx, 2
    inc bp
    jmp print_string
_0:
    ret
    



exit:
    int 0x20                    ; exit


title_string:       db " 2048 Bootsector ",0
credits_string:     db " by Bruno `CrociDB` Croci ",0
