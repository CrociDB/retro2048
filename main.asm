    org 0x0100

start:
    ; Set 80-25 text mode
    mov ax, 0x0002
    int 0x10

setup_screen:
    mov ax, 0xb800              ; Segment for the video data
    mov es, ax

    cld

    ; Game title
    mov ah, 0x67
    mov bp, title_string
    mov cx, 72
    call print_string

    ; Score
    mov ah, 0x08
    mov bp, score_string
    mov cx, 160*4+44
    call print_string

    ; Drawing the box
    push 0x3800
    push 0x1125                 ; Rect size 37x16 (25x11)
    push 44                     ; Offset 22 chars on left
    push 160 * 5                ; Offset 5 lines on top
    call draw_box


main_loop:
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
    mov bp, movement_up
    jmp _movement
_left:
    mov bp, movement_left
    jmp _movement
_right:
    mov bp, movement_right
    jmp _movement
_down:
    mov bp, movement_down

_movement:
    mov ax, [bp]
    mov word [current_offset], ax
    mov ax, [bp+2]
    mov dx, [bp+4]
    call compute_movement

    call print_board
    call wait_time

    mov ax, [bp+6]
    mov word [current_offset], ax
    mov ax, [bp+8]
    mov word [current_cell_pointer], ax
    call add_new_cell

    jmp main_loop


    ;
    ; Wait time function
    ;
wait_time:
    xor dx, dx
    mov cx, 5
    mov ah, 0x86
    int 0x0015
    mov ah, 0x0c
    int 0x0021
    ret


    ;
    ; Add new cell function
    ;  it will first count how many empty cells there are, then get a random cell and adds a random value
    ;
add_new_cell:
    mov cx, 17                          ; Sets the board size               
    mov bp, board                       ; Gets the pointer to the board
    xor bl, bl                          ; Initializes the zero counter
_count_empty:
    mov dl, byte [bp]                   ; Gets the value of the current cell
    cmp dl, 0                           ; Checks if the current cell is empty
    jne _count_continue                 ; ... if not empty, iterate
    inc bl                              ; ... if empty, increase zero counter
_count_continue:
    inc bp                              ; Increases the pointer to the next cell
    loop _count_empty                   ; Iterates counter
    cmp bl, 0                           ; Checks if there are empty cells
    je _add_new_cell_exit               ; ... if no empty cells, just exit
    
    mov ah, 0x00                        ; BIOS service to get system time
    int 0x1a

    mov ax, dx                          ; Copies the time fetched by interruption
    xor dx, dx                          ; Resets DX because DIV will use DXAX
    div bx                              ; AX = (DXAX) / bx ; DX = remainder
    mov bh, dl                          ; Gets the remainder of the division in BH

    mov cx, 16                          ; Set she board size iterator - we don't need to iterate all the board
    mov bp, board                       ; Gets the pointer to the board
    xor bl, bl                          ; Initializes the zero counter

_check_item:
    mov dl, byte [bp]                   ; Gets the value of the current cell
    cmp dl, 0                           ; Checks if it's an empty cell
    jne _check_item_loop                ; ... if not, iterates
    cmp bl, bh                          ; Compares if the current counter is the randomized value selected
    je _add_and_exit                    ; ... if so, adds new cell and exit
    inc bl                              ; Increases the current zero counter

_check_item_loop:
    inc bp                              ; Increases the pointer to the board
    loop _check_item                    ; Iterates item adding

_add_and_exit:
    and al, 1                           ; Gets one bit of the divided value (our so called random)
    inc al                              ; Adds 1 to it, it it's either 1 or 2 (cell value 2 or 4)
    mov byte [bp], al                   ; Set the above value to the board

_add_new_cell_exit:
    ret



    ;
    ; Compute movement function
    ; Params:   [current_offset]    - the offset between elements
    ;           DX                  - line offset
    ;           AX                  - initial cell pointer
    ;
compute_movement:
    mov cx, 4
_compute_line:
    mov word [current_cell_pointer], ax
    pusha
    call compute_board_line
    popa
    add ax, dx
    loop _compute_line
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
    add byte [score], dl
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
    pusha                               ; Saves the counter, because print_cell uses it
    mov al, cl                          ; Saves the id to AL, input to print_cell
    dec al                              ; Decreases 1 from the counter
    call print_cell
    popa
    loop _loop_cell
    

    push 0x8f00
    push 160*4+58
    mov ax, word [score]
    call print_number
    add sp, 4

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
    xor bl, bl
    mov bp, board_colors                ; Gets the pointer to the first color
    add bp, cx                          ; Adds the value id to color pointer
    mov bh, [bp]                        ; Gets the value of the color

    ; First print the box
    push bx                             ; Box color
    push 0x0306                         ; Box size

    mov bx, board_offset_row            ; Gets the row offset
    xor ch, ch                          ; Resets CX
    mov cl, al
    shr cl, 2                           ; Divides by four since the offset is the same for every 4 items
    shl cl, 1                           ; Multiplies the current cell id by two because the row offset is a word
    add bx, cx                          ; Adds the id to the pointer
    mov cx, word [bx]                   ; Gets the offset value
    mov [current_offset], cx            ; Saves the offset value, to be used on the number
    push cx                             ; Pushes to draw_box function

    mov bl, 4
    div bl                              ; Divides current index by 4
    shr ax, 8                           ; And get the remainder, because the column offset cycles 0-3
    mov bx, board_offset_column         ; Gets the column offset
    add bx, ax                          ; Gets the cell id
    xor ch, ch                          ; Resets CX
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
    je _pc_exit
    mov ax, 1
    shl ax, cl
    call print_number
_pc_exit:
    add sp, 4                           ; Removes parameters from stack
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
    mov bl, dh                      ; Get the height of the box

    xor ch, ch                      ; Resets CX
    mov cl, dl                      ; Copy the width of the box
    add di, [bp+4]                  ; Adds the line offset to DI
    rep stosw

    add word [bp+2], 160            ; Add a line (180 bytes) to offset
    sub byte [bp+7], 0x01           ; Remove one line of height - it's 0x0100 because height is stored in the msb
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
    ; Params:   AX      - num value
    ;           [bp+2]  - position/offset
    ;           [bp+4]  - background/foreground color
    ;
print_number:
    cmp ax, 0
    je _p_exit
    mov bp, sp
    mov di, [bp+2]
    xor cx, cx
_get_unit:
    cmp ax, 0
    je _print
    xor dx, dx
    mov bx, 10
    div bx
    xor bx, bx
    mov bl, dl
    push bx
    inc cx
    jmp _get_unit

_print:
    pop ax
    add al, '0'                     ; Add char `0` to value
    mov ah, byte [bp+5]             ; Copy color info
    stosw
    loop _print
_p_exit:
    ret



exit:
    int 0x20                        ; exit


title_string:       db " 2 0 4 8 ",0
score_string:       db "Score: ",0

current_cell_pointer:           dw 0x0000
current_offset:                 dw 0x0000

score: dw 0x0000

board:
    db 0,0,0,0
    db 0,0,0,0
    db 0,0,1,0
    db 0,1,0,0
    shr cl, 2                           ; Multiplies the current cell id by two because the row offset is a word

board_offset_row:
    dw 160*6,  160*10, 160*14, 160*18

board_offset_column:
    db 48, 66, 84, 102

board_colors:
    ;  0    2     4      8      16      32      64      128     256      512     1024        2048
    db 0x00, 0x2f, 0x1f, 0x4f,  0x5f,   0x6f,   0x79,   0x29,   0x15,    0xce,   0xdc,       0x8e

movement_up:    dw 4, board, 1, -1, board+15
movement_left:  dw 1, board, 4, -1, board+15
movement_right: dw -1, board+3, 4, 1, board
movement_down:  dw -4, board+12, 1, 1, board
