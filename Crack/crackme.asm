.model tiny
.code
.286
org 100h
locals @@


REMAINDER equ 2000h
POW       equ 5

START_HASH_VALUE equ 0


Start:
        jmp main

main:
        mov dx, offset enter_message
        call PrintMessage

        call GetPassword

        call CheckPassword
        call PrintMessage

EXIT:   mov ax, 4c00h	     
	    int 21h  

;---------------------------------------------------------------------
; Get password from stdin
; Entry:  nothing
;
; Destr:  ah - keybrd enter
;         dx - &password_buffer 
;--------------------------------------------------------------------- 
GetPassword     proc

                mov ah, 0ah                  
                mov dx, offset password_buffer          
                int 21h                                           

                ret
                endp

;---------------------------------------------------------------------
; Polynome hash
; Entry:  dx - &password_buffer
;
; Destr:  cl - len password
;         bx = dx  
;
; Return: ax - hash_value 
;--------------------------------------------------------------------- 
HashFunc        proc

                push dx

                mov bx, dx
                mov cl, [bx + 1]
                add bx, 2

                mov ax, START_HASH_VALUE 
                xor dx, dx
                mov dl, POW

                @@cycle_hash:
                    mul dl
                    add ax, [bx]
                    and ax, REMAINDER - 1           ; hash_value = (hash_value * pow + letter) % MOD

                    inc bx
                    loop @@cycle_hash

                pop dx

                ret
                endp

;---------------------------------------------------------------------
; Check Password Function
; Entry:  dx - &password_buffer
;
; Destr:  ax - result right hash or no  
;
; Return: dx - offset message result 
;--------------------------------------------------------------------- 
CheckPassword   proc

                mov ax, right_hash_value

                call CheckHash

                cmp ax, 1
                jne wrong_password

                mov dx, offset success_message
                jmp @@return

                wrong_password:
                    mov check_password, 1
                    mov dx, offset denied_message

                @@return:
                    ret
                    endp

;---------------------------------------------------------------------
; Check Hash Function
; Entry:  ax - right hash value
;
; Destr:  bx - temporary storage ax, ax
;
; Return: ax - result right hash or no  
;---------------------------------------------------------------------         
CheckHash       proc

                push ax

                call HashFunc

                pop bx

                cmp ax, bx
                jne wrong_hash

                mov ax, 1
                jmp @@return

                wrong_hash:
                    xor ax, ax

                @@return:
                    ret
                    endp

;---------------------------------------------------------------------
; Check Hash Function
; Entry:  dx - offset message
;
; Destr:  ax - func
;
; Return: nothing  
;---------------------------------------------------------------------  
PrintMessage    proc

                mov ah, 09h 
                int 21h

                ret
                endp

.data
    password_buffer: db 254  
        
    check_password   db 0

    enter_message    db 0dh, 0ah, "Enter Password: $"

    success_message  db 0dh, 0ah, "Password correct$"

    denied_message   db 0dh, 0ah, "Password is incorrect$"

    ;   maybe canary

    right_hash_value dw 0ed2h

    ;   maybe canary

end Start   