    org 0x0100

start:
    ; Set 80-25 text mode
    mov ax, 0x0002
    int 0x10

setup_screen:
    mov ax, 0xb800              ; Segment for the video data
    ; mov ds, ax
    mov es, ax

    cld

    ; Clears the screen
    mov cx, 2000
    mov ax, 0x0800
clear:
    stosw
    loop clear

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
    ; Drawing the box
    push 0x3800
    push 0x1125                 ; Rect size 37x16 (25x11)
    push 44                     ; Offset 22 chars on left
    push 160 * 5                ; Offset 5 lines on top
    call draw_box

    call print_board

    jmp exit


    ;
    ; Print board function
    ;
print_board:
    mov cx, 17                          ; The amount of cells
_loop_cell:
    push cx                             ; Saves the counter, because print_cell uses it
    mov al, cl                          ; Saves the id to AL, input to print_cell
    dec al                              ; Decreases 1 from the counter
    call print_cell
    pop cx
    loop _loop_cell

    ret


    ;
    ; Print cell function
    ; Params:   AL - board index
    ;
print_cell:
    ; First print the box
    push 0x1F00                         ; Box color
    push 0x0306                         ; Box size

    xor ah, ah                          ; Resets AH
    mov byte [current_cell], al         ; Saves the current cell id

    mov bx, board_offset_row            ; Gets the row offset
    xor cx, cx                          ; Resets CX
    mov cl, al
    shl cl, 1                           ; Multiplies the current cell id by two because the row offset is a word
    add bx, cx                          ; Adds the id to the pointer
    mov cx, word [bx]                   ; Gets the offset value
    mov [current_offset], cx            ; Saves the offset value, to be used on the number
    push cx                             ; Pushes to draw_box function
    
    mov bx, board_offset_column         ; Gets the column offset
    add bx, ax                          ; Gets the cell id
    xor cx, cx                          ; Resets CX
    mov cl, byte [bx]                   ; Copies the value of the offset (byte)
    add [current_offset], cx            ; Adds it to current_offset, to be used on the number
    push cx                             ; Pushes to draw_box function

    call draw_box
    add sp, 6                           ; Remove parameters from stack, but not the color

    mov bx, [current_offset]            ; Gets the current total screen offset
    add bx, 162                         ; Adds one line and one char
    push bx                             ; Pushes current position offset to print_number function

    mov bx, board                       ; Pointer to the board
    xor ah, ah                          ; Resets AH
    mov al, byte [current_cell]         ; Gets cell id
    add bx, ax                          ; Adds cell id to pointer
    xor cx, cx                          ; Resets CX
    mov cl, byte [bx]                   ; Gets actual on the board
    push cx                             ; Pushes to print_number function

    call print_number
    add sp, 6                           ; Removes parameters from stack

    ret


    ;
    ; Draw box function
    ; Params:   [bp+2] - row offset
    ;           [bp+4] - column offset
    ;           [bp+6] - box dimensions
    ;           [bp+8] - char/Color
    ;
draw_box:
    mov bp, sp                      ; Store the base of the stack, to get arguments
    xor di, di                      ; Sets DI to screen origin
    add di, [bp+2]                  ; Adds the row offset to DI

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
    ; Params:   [bp+2] - num value
    ;           [bp+4] - position/offset
    ;           [bp+6] - background/foreground color
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

current_cell:       db 0x00
current_offset:     dw 0x0000

board:
    db 0,0,0,0
    db 0,0,0,0
    db 0,0,2,0
    db 0,2,0,0

board_offset_row:
    dw 160*6,  160*6,  160*6,  160*6
    dw 160*10,  160*10,  160*10,  160*10
    dw 160*14, 160*14, 160*14, 160*14
    dw 160*18, 160*18, 160*18, 160*18

board_offset_column:
    db 48, 66, 84, 102
    db 48, 66, 84, 102
    db 48, 66, 84, 102
    db 48, 66, 84, 102