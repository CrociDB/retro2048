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
    mov cx, 72
    call print_string

    ; ; Credits
    ; mov ah, 0x0c
    ; mov bp, credits_string
    ; mov cx, 3948
    ; call print_string

main_loop:
    ; Drawing the box
    push 0x3800
    push 0x1125                 ; Rect size 37x16 (25x11)
    push 44                     ; Offset 22 chars on left
    push 160 * 5                ; Offset 5 lines on top
    call draw_box

    call print_board

check_input:
    mov ah, 0                   ; Get keystroke
    int 0x16                    ; BIOS service to get keyboard

    cmp ah, 0x48                ; Up key
    je _up
    cmp ah, 0x4b                ; Left key
    je _left
    cmp ah, 0x4d                ; Right key
    je _right
    cmp ah, 0x50                ; Down key
    je _down

    cmp ah, 0x1                 ; Esc key
    jne check_input
    jmp exit

_up:
    mov word [current_offset], 4

    mov ax, board
    mov word [current_cell_pointer], ax
    call compute_board_line

    mov ax, board+1
    mov word [current_cell_pointer], ax
    call compute_board_line

    mov ax, board+2
    mov word [current_cell_pointer], ax
    call compute_board_line

    mov ax, board+3
    mov word [current_cell_pointer], ax
    call compute_board_line

    mov word [current_offset], -1
    mov ax, board+15
    mov word [current_cell_pointer], ax
    call check_board

    jmp main_loop
_left:
    mov word [current_offset], 1

    mov ax, board
    mov word [current_cell_pointer], ax
    call compute_board_line

    mov ax, board+4
    mov word [current_cell_pointer], ax
    call compute_board_line

    mov ax, board+8
    mov word [current_cell_pointer], ax
    call compute_board_line

    mov ax, board+12
    mov word [current_cell_pointer], ax
    call compute_board_line

    mov word [current_offset], -1
    mov ax, board+15
    mov word [current_cell_pointer], ax
    call check_board

    jmp main_loop
_right:
    mov word [current_offset], -1

    mov ax, board+3
    mov word [current_cell_pointer], ax
    call compute_board_line

    mov ax, board+7
    mov word [current_cell_pointer], ax
    call compute_board_line

    mov ax, board+11
    mov word [current_cell_pointer], ax
    call compute_board_line

    mov ax, board+15
    mov word [current_cell_pointer], ax
    call compute_board_line

    mov word [current_offset], 1
    mov ax, board
    mov word [current_cell_pointer], ax
    call check_board

    jmp main_loop
_down:
    mov word [current_offset], -4

    mov ax, board+12
    mov word [current_cell_pointer], ax
    call compute_board_line

    mov ax, board+13
    mov word [current_cell_pointer], ax
    call compute_board_line

    mov ax, board+14
    mov word [current_cell_pointer], ax
    call compute_board_line

    mov ax, board+15
    mov word [current_cell_pointer], ax
    call compute_board_line

    mov word [current_offset], 1
    mov ax, board
    mov word [current_cell_pointer], ax
    call check_board

    jmp main_loop


    ;
    ; Check board function - will check victory/loss and add new value
    ; Params -  [current_cell_pointer] - start cell ID
    ;           [current_offset] - offset between items of the line (direction)
    ;
check_board:
    mov cx, 17
    mov bp, [current_cell_pointer]
    mov ax, [current_offset]
_check_item:
    mov dl, byte [bp]
    cmp dl, 0
    je _normal
    add bp, ax
    loop _check_item
    jmp _gameover

_normal:
    mov byte [bp], 1
    ret

_gameover:
    ret





    ;
    ; Compute board line function - this will compute a line/column of the board
    ; Params -  [current_cell_pointer] - start cell ID
    ;           [current_offset] - offset between items of the line (direction)
    ;
compute_board_line:
    mov cx, 3                           ; The amount of iterations we'll do
    
_item:
    mov bp, [current_cell_pointer]
    mov ah, byte [bp]
    cmp ah, 0
    jne _add

; ---- MOVE
_move:
    mov bx, cx
    mov bp, [current_cell_pointer]

_move_find:
    add bp, [current_offset]
    mov dl, byte [bp]
    cmp dl, 0
    je _skip_move
    mov byte [bp], 0
    mov bp, [current_cell_pointer]
    mov byte [bp], dl
    jmp _item

_skip_move:
    dec bx
    cmp bx, 0
    jne _move_find

; ---- ADD
 _add:
    mov bx, cx
    mov bp, [current_cell_pointer]

_add_find:
    add bp, [current_offset]
    mov dl, byte [bp]
    cmp dl, 0
    je _skip_add
    cmp dl, ah
    jne _return
    mov byte [bp], 0
    mov bp, [current_cell_pointer]
    inc byte [bp]
    jmp _return

_skip_add:
    dec bx
    cmp bx, 0
    jne _add_find

_return:
    mov bx, [current_offset]
    add [current_cell_pointer], bx
    loop _item
    ret

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
    xor ah, ah                          ; Resets AH
    mov bp, board
    mov [current_cell_pointer], bp
    add [current_cell_pointer], al

    xor ch, ch
    mov bx, [current_cell_pointer]      ; Pointer to the board
    mov cl, byte [bx]                   ; Gets actual value on the board
    xor bx, bx
    mov bp, board_colors                ; Gets the pointer to the first color
    add bp, cx                          ; Adds the value id to color pointer
    mov bh, [bp]                        ; Gets the value of the color

    ; First print the box
    push bx                             ; Box color
    push 0x0306                         ; Box size

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

    mov bx, [current_cell_pointer]                ; Pointer to the board
    mov cl, byte [bx]                   ; Gets actual value on the board
    cmp cl, 0
    mov ax, 1
    jne _pc0
    mov ax, 0
_pc0:
    shl ax, cl
    push ax                             ; Pushes to print_number function

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


title_string:       db " 2 0 4 8 ",0
; credits_string:     db " by Bruno `CrociDB` Croci ",0

current_cell_pointer:           dw 0x0000
current_offset:                 dw 0x0000

board:
    db 0,0,0,0
    db 0,0,0,0
    db 0,0,1,0
    db 0,1,0,0

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

board_colors:
    ;  0    2     4      8      16      32      64      128     256      512     1024        2048
    db 0x00, 0x2f, 0x1f, 0x4f,  0x5f,   0x6f,   0x79,   0x29,   0x15,    0xce,   0xdc,       0x8e
