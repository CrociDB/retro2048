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

    ; Number test
    push 0x6c00
    push 320
    push 666
    call print_number

main_loop:
    jmp exit

    ;
    ; Draw box function
    ; Params: (bp+2) - line offset
    ;         (bp+4) - row offset
    ;         (bp+6) - box dimensions
    ;         (bp+8) - char/Color
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
    cmp ch, 0                       ; Test the height of the box
    jnz draw_box                    ; If not zero, draw the rest of the box
    ret


    ;
    ; Print string function
    ; Params:   AH - background/foreground color
    ;           BP - string addr
    ;           CX - position/offset
    ;
print_string:
    mov di, cx                      ; Adds offset to DI
    mov al, byte [bp]               ; Copies the char to AL (AH already contains color data)
    cmp al, 0                       ; If the char is zero, string finished
    jz _0                           ; ... return
    stosw
    add cx, 2                       ; Adds more 2 bytes the offset
    inc bp                          ; Increments the string pointer
    jmp print_string                ; Repeats the rest of the string
_0:
    ret
    

    ;
    ; Print number function
    ; Params:   (bp+2) - num value
    ;           (bp+4) - position/offset
    ;           (bp+6) - background/foreground color
    ;
print_number:
    mov bp, sp                      ; Copying stack pointer to get parameters
    xor cx, cx                      ; Resetting CX, it will be our zero-left-counter
    mov bx, 1000                    ; Set decimal to 1000 - our function will only print up to 9999
    mov di, [bp+4]                  ; Setting the screen offset
_1:    
    xor dx, dx                      ; DX has to be zero, because DIV by WORD will use DXAX 
    mov ax, [bp+2]                  ; Get the value to print
    div bx                          ; Divide by the current decimal
    mov dx, ax                      ; Copies decimal total to DL (to subtract from value later)
    add cx, ax                      ; Adds every value: important to ignore 0 on the left
    cmp cx, 0                       ; If counter is zero, that means we're still on zeroes on left
    jz _3                           ; ... then skip printing
    add al, '0'                     ; Add char `0` to value
    mov ah, byte [bp+7]             ; Copy color info
    stosw
_3:
    cmp bx, 1                       ; If our decimal is already 1, then the function is over
    jz _2                           ; ... return

    xor ax, ax                      ; Subtracting the current decimal value from number to print
    mov al, dl                      ; Copying the printed value
    mul bx                          ; Multiply by the current decimal
    sub [bp+2], ax                  ; Finally subtract the total value

    xor ax, ax                      ; Now we need to divide our decimal by 10
    mov ax, bx                      ; Copies the value to AX, where DIV works
    mov bx, 10                      ; Stores 10 on BX
    div bl                          ; Divides decimal by 10
    mov bl, al                      ; Saves it back to BX
    jmp _1                          ; Repeat print
_2:
    ret


exit:
    int 0x20                        ; exit


title_string:       db " 2048 Bootsector ",0
credits_string:     db " by Bruno `CrociDB` Croci ",0
