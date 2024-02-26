.286
.model tiny
.code
org 100h
locals @@

Start:
        push cs
        pop cx

        call PrintHexWord
  
        mov ax, 1111h
        mov bx, 2222h
        mov cx, 3333h
        mov dx, 4444h
        mov si, 5555h
        mov di, 6666h
        mov bp, 7777h

@@cycle:  
        in al, 60h
        cmp al, 1
        jne @@cycle

Exit:
	mov ax, 4c00h
	int 21h


PrintHexWord    proc

                mov ah, 2

                xchg cl, ch
                call PrintHexByte                 ; hi byte

                xchg cl, ch
                call PrintHexByte                 ; low byte

                ret
                endp

PrintHexByte    proc

                push bx ax

                xor bh, bh

                mov bl, cl
                and bl, 0f0h
                shr bl, 4 
                mov dl, ds:[offset hex_alphabet + bx] 
                
                int 21h

                pop ax
                push ax

                mov bl, cl
                and bl, 0fh
                mov dl, ds:[offset hex_alphabet + bx]
                
                int 21h

                pop ax bx

                ret
                endp

hex_alphabet db '0123456789ABCDEF'

end Start