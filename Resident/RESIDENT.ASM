.model tiny
.code
.286
org 100h
locals @@


VMEM     equ 0b800h  


.EOI     macro
         nop

         mov al, 20h                         
         out 20h, al                                ; send EOI to intr cntrlr

         nop
         endm


.RESIDENT_EXIT   macro
                 nop

                 mov ax, 3100h                      ; terminate and remain resident
                 mov dx, offset end_of_programm
                 shr dx, 4                          ; paragraph
                 inc dx
                 int 21h

                 nop
                 endm


.PUSH_ALL_REGISTERS macro
                    nop

                    push sp bp ss es ds di si dx cx bx ax

                    mov bp, sp

                    mov ax, [bp + (REG_NUMBER - 2) * 2 + 2]        ; push cs
                    push ax

                    mov ax, [bp + (REG_NUMBER - 2) * 2]            ; push ip
                    push ax
            
                    nop
                    endm

.POP_ALL_REGISTERS  macro

                    pop bx bx ax bx cx dx si di ds es ss bp sp

                    endm

SCREEN_WIDTH  equ 80d
FRAME_WIDTH   equ 11d
FRAME_HEIGHT  equ 15d
COORD_X0      equ 68d    
COORD_Y0      equ 2d          ; start coord for panelka
DELTA_X       equ 1d            
DELTA_Y       equ 1d          ; delta for shadow

SHADOW_COLOR  equ 30h         ; blue
FRAME_COLOR   equ 4eh
REG_COLOR     equ 4eh

SPACE         equ 20h

REG_NUMBER    equ 13d
TITLE_LEN     equ 9d
REG_VALUE_LEN equ 4d

R_SHIFT_PRESSING       equ 36h
R_SHIFT_RELEASE        equ 0b6h
START_REG_VALUE_OFFSET equ 73d

;---------------------------------------RESIDENT_BLOCK---------------------------------------

Start:
                jmp main

main:
;-----------------get_old_keybrd_interrupt_vector-----------------
                mov ax, 3509h                               ; IRQ1 + 8
                int 21h                                     ; fn35 - return es:bx
                mov cs:old_keybrd_int_offset,  bx           
                mov cs:old_keybrd_int_segment, es           ; save &old09

;-----------------get_old_timer_interrupt_vector------------------
                mov ax, 3508h                               ; IRQ0 + 8
                int 21h                                     ; fn35 - return es:bx
                mov cs:old_timer_int_offset,  bx
                mov cs:old_timer_int_segment, es            ; save &old08

;-----------------set_old_keybrd_interrupt_vector-----------------
                push 0                    
                pop es
                mov bx, 4 * 09h                             ; segment + offset                   
                cli
                mov word ptr es:[bx], offset NewIntKeybrd   ; new adress offset
                push cs
                pop ax                                      ; manually, bad because there may be several interrupt tables
                mov es:[bx + 2], ax                         ; new adress segment
                sti

;-----------------set_new_timer_interrupt_vector------------------
                mov ax, 2508h
                push cs
                pop ds
                mov dx, offset NewIntTimer
                int 21h                                     ; DS:DX - interrupt vector

;-----------------------------------------------------------------
                .RESIDENT_EXIT
;-----------------------------------------------------------------

;-----------------------------------------------------------------
; IntKeybrd
; Entry:     Nothing
; Returns:   Nothing
; Destroys:  Nothing
;-----------------------------------------------------------------
NewIntKeybrd    proc
        
                push ax

                in al, 60h                          ; port 60h - contains last scan code
                cmp al, R_SHIFT_PRESSING            ; right_shift_press
                jne @@check_release

                mov cs:frame_flag, 1

                @@check_release:
                    cmp al, R_SHIFT_RELEASE
                    jne @@default_int

                in al, 61h                          ; Blink hi bit in keybd cntrlr
                or al, 80h                          ; make hi bit 1
                out 61h, al                         ; put al in 61h
                and al, not 80h                     ; make hi bit 0
                out 61h, al                         ; put al in 61h

                .EOI

                pop ax
                iret                                ; IP, CS, EFLAGS

                @@default_int:
                    pop ax
                    db 0EAh                         ; far jmp, call default interrupt
                    old_keybrd_int_offset  dw 0
                    old_keybrd_int_segment dw 0
                    endp

;-----------------------------------------------------------------
; IntTimer
; Entry:      Nothing
; Returns:    Nothing
; Destroys:   Nothing
;-----------------------------------------------------------------
NewIntTimer     proc

                .PUSH_ALL_REGISTERS                 ; save all registers

                cmp cs:frame_flag, 0
                je @@default_int                    ; check if frame is on

                push cs                             ; change ds to use lodsb/stosw
                pop ds

                call DrawRegistrFrame

                @@default_int:
                    .POP_ALL_REGISTERS
                    db 0EAh                         ; far jmp, call default interrupt
                    old_timer_int_offset  dw 0
                    old_timer_int_segment dw 0
                    endp

;---------------------------------------FRAME_BLOCK-----------------------------------------

;-----------------------------------------------------------------
; draw frame with registers
; Entry:  register values in stack
; Return: nothing
;-----------------------------------------------------------------
DrawRegistrFrame    proc

                    push bp
                    mov bp, sp 

                    push VMEM                       
                    pop es

                    call DrawFrame                                     
                    
                    call WriteRegistrValue

                    pop bp

                    ret
                    endp

;-----------------------------------------------------------------
; writes registers value
; Entry:  register values in stack
;         di - current cell Vmem
; Return: nothing
; Destroys: di, bp
;-----------------------------------------------------------------
WriteRegistrValue   proc

                    mov cx, REG_NUMBER
                    add bp, 4
                    mov di, ((COORD_Y0 + 1) * SCREEN_WIDTH + START_REG_VALUE_OFFSET) * 2           

                    @@print:
                        mov dx, [bp]                       
                        call PrintHexWord

                        add bp, 2                                           ; next reg
                        add di, (SCREEN_WIDTH - REG_VALUE_LEN) * 2

                        loop @@print
        
                    ret
                    endp

;-----------------------------------------------------------------
; Entry:    dx - reg value
; Return:   nothing
; Destroys: ah - color attr, dh, dl
;-----------------------------------------------------------------
PrintHexWord    proc

                mov ah, REG_COLOR

                xchg dl, dh
                call PrintHexByte                 ; hi byte

                xchg dl, dh
                call PrintHexByte                 ; low byte

                ret
                endp

;-----------------------------------------------------------------
; print hex byte reg
; Entry:    dl - byte
;           ah - color attr
; Return:   nothing
; Destroys: bx, al
;-----------------------------------------------------------------
PrintHexByte        proc

                    push bx ax

                    xor bh, bh

                    mov bl, dl
                    and bl, 0f0h
                    shr bl, 4 
                    mov al, ds:[offset hex_alphabet + bx] 
                    stosw 


                    mov bl, dl
                    and bl, 0fh
                    mov al, ds:[offset hex_alphabet + bx]
                    stosw

                    pop ax bx

                    ret
                    endp

;-----------------------------------------------------------------
; writes a line to Vmem
; Entry:   cx = delta_x
;           di - current cell Vmem
;          ah - color attribute
;           si = current &frame
; Destr:   si, di, al
;-----------------------------------------------------------------
WriteHorLine proc

             cld
             
             push cx       ; save d_x

             sub cx, 2     ; !rep

             lodsb         ; first
             stosw          

             lodsb         ; middle
             rep stosw       
            
             lodsb         ; last
             stosw

             pop cx

             sub si, 3

             ret
             endp

;-----------------------------------------------------------------
; Writes frame
; Entry:    di - current cell Vmem
;            si = current &frame
;
; Destr:    di, bx, al, si
;-----------------------------------------------------------------
DrawFrame       proc

                mov si, offset border
                mov ah, FRAME_COLOR

                mov bx, FRAME_HEIGHT
                mov cx, FRAME_WIDTH

                mov di, (COORD_Y0 * SCREEN_WIDTH + COORD_X0) * 2

                call DrawFirstLine

                draw:
                    call WriteHorLine

                    call DrawRightShadow

                    call VmemShift

                    dec bx

                    cmp bx, 1
                    jne draw

                call DrawLastLine

                call DrawShadowUnderPanelka

                call DrawTitle

                call DrawRegisterNames
                    
                ret
                endp

;-----------------------------------------------------------------
; Writes reg names
; Entry:    nothing
;
; Destr:    di, al, si, cx
;-----------------------------------------------------------------
DrawRegisterNames   proc

                    mov di, ((COORD_Y0 + 1) * SCREEN_WIDTH + COORD_X0 + 2) * 2

                    mov cx, REG_NUMBER

                    mov si, offset register_names

                    @@cycle:
                        lodsb
                        stosw

                        lodsb
                        stosw

                        add di, (SCREEN_WIDTH - 2) * 2
                        loop @@cycle

                    ret
                    endp

;-----------------------------------------------------------------
; Entry:    nothing
;
; Destr:    di, al, si, cx
;-----------------------------------------------------------------
DrawTitle       proc

                mov di, (COORD_Y0 * SCREEN_WIDTH + COORD_X0 + 1) * 2

                mov cx, TITLE_LEN

                mov si, offset frame_title

                @@cycle:
                    lodsb
                    stosw
                    loop @@cycle

                ret
                endp


;-----------------------------------------------------------------
;Writes frame
;Entry:     di - current cell Vmem
;         cx = delta_x
;Destr:  di
;Return: di = &new_line
;-----------------------------------------------------------------
VmemShift       proc

                push ax
          
                mov ax, SCREEN_WIDTH    ; to new line
                sub ax, cx                ; shift left
                shl ax, 1                ; fix
    
                add di, ax

                pop ax

                ret
                endp

            
;-----------------------------------------------------------------
;Entry: cx = delta_x
;        bx = delta_y
;        si - current &frame
;
;Destr: si, bx, di
;-----------------------------------------------------------------
DrawFirstLine   proc

                call WriteHorLine
                call VmemShift
                dec bx
                add si, 3

                ret
                endp

;-----------------------------------------------------------------
;Entry: cx = d_x
;        bx = d_y
;        si = current &frame
;
;Destr: si, bx, di
;-----------------------------------------------------------------
DrawLastLine    proc

                add si, 3
                call WriteHorLine
                call DrawRightShadow
                call VmemShift

                ret
                endp


;-----------------------------------------------------------------
;Entry: di - current cell Vmem
;          ah - color attr
;          al - symbol
;
;Destr: di, ah, al
;-----------------------------------------------------------------
DrawRightShadow     proc

                    push cx ax

                    mov cx, DELTA_X
                    mov ah, SHADOW_COLOR
                    mov al, SPACE

                    rep stosw

                    sub di, DELTA_X * 2

                    pop ax cx

                    ret
                    endp

;-----------------------------------------------------------------
;Entry: di - current cell Vmem
;          al - symbol
;
;Destr: di, ah, al
;-----------------------------------------------------------------
DrawShadowUnderPanelka  proc
                        
                        push ax cx

                        mov ah, SHADOW_COLOR
                        mov al, SPACE

                        add di, DELTA_X * 2

                        rep    stosw

                        sub di, DELTA_X * 2

                        pop cx ax
                    
                        ret
                        endp

.data

    border  db 0c9h, 0cdh, 0bbh, 0bah, 020h, 0bah, 0c8h, 0cdh, 0bch, '$'   ; second type

    frame_flag db 0

    hex_alphabet db '0123456789ABCDEF'

    register_names db "ip", "cs", "ax", "bx", "cx", "dx", "si", "di", "ds", "es", "ss", "bp", "sp"

    frame_title db 'registers$'

end_of_programm:
    end Start