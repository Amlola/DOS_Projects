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

        push dx

        mov dx, offset to_next_line
        call PrintMessage

        pop dx

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

                cmp received_hash, 0000h            ; specifically so that it can be hacked through a hash
                jne @@return

                mov received_hash, ax
                mov cl, 1

                @@return:
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

                cmp check_password, 0
                jne right_password

                mov dx, offset denied_message
                jmp @@return

                right_password:
                    mov dx, offset success_message

                @@return:
                    ret
                    endp

;---------------------------------------------------------------------
; Check Hash Function
; Entry:  ax - right hash value
;
; Destr:  bx - temporary storage ax, ax
;---------------------------------------------------------------------         
CheckHash       proc

                push ax

                call HashFunc

                pop bx

                cmp cl, 1
                je comparation

                xchg bl, bh

                comparation:
                    cmp received_hash, bx
                    jne @@return

                mov check_password, 1                   ; if hash1 == hash2, flag = 1

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
    password_buffer: 
                     db 254
                     db 14 dup(0)           

    received_hash    dw 0000h

    enter_message    db "Enter Password: $"

    check_password   db 0

    denied_message   db "Password is incorrect$"

    success_message  db "Password correct$"

    to_next_line     db 0dh, 0ah, "$"

    right_hash_value dw 0e48h               ; notaH

end Start   