.model tiny
.code
.286
org 100h
locals @@


Start:
        jmp main

MyStrlen proc

         push bp
         mov bp, sp

         mov es, ss:[bp + 6]
         mov di, ss:[bp + 4]

         cld

         mov cx, -1

         mov al, '$'
         repne scasb

         neg cx
         sub cx, 2

         mov dx, cx

         pop bp

         ret
         endp


MyMemChr  proc

          push bp
          mov bp, sp

          mov es, ss:[bp + 10]             ; ds
          mov di, ss:[bp + 8]              ; &string
          mov al, ss:[bp + 6]              ; symbol
          mov cx, ss:[bp + 4] 

          repne scasb

          mov bx, di
          sub bx, 1

          cmp es:[bx], al
          je @@return

          cmp cx, 0
          jne @@return

          mov ax, 0

          @@return:
              pop bp
              ret
              endp


MyMemset  proc
          
          push bp
          mov bp, sp

          mov es, ss:[bp + 10]             ; ds
          mov di, ss:[bp + 8]              ; &string
          mov al, ss:[bp + 6]              ; symbol
          mov cx, ss:[bp + 4] 

          @@cycle:
              mov es:[di], al
              inc di
              loop @@cycle

          pop bp
          ret
          endp

MyMemCpy  proc                             ; FIX

          push bp
          mov bp, sp

          mov es, ss:[bp + 10]             ; ds
          mov di, ss:[bp + 8]              ; &string1
          mov si, ss:[bp + 6]              ; &string2
          mov cx, ss:[bp + 4]              ; fix cross elements

          rep movsb

          pop bp
          ret
          endp
       
MyMovMem  proc
          
          push bp
          mov bp, sp

          mov es, ss:[bp + 10]             ; ds
          mov di, ss:[bp + 8]              ; &string1
          mov si, ss:[bp + 6]              ; &string2
          mov cx, ss:[bp + 4]              ; fix cross elements

          rep movsb

          pop bp

          ret
          endp


MyMemCmp  proc

          push bp
          mov bp, sp

          mov es, ss:[bp + 10]             ; ds
          mov di, ss:[bp + 8]              ; &string1
          mov si, ss:[bp + 6]              ; &string2
          mov cx, ss:[bp + 4]              ; fix cross elements
          dec di

          @@cycle:
              lodsb
              inc di
              cmp al, byte ptr es:[di]
              jne @@return

              loop @@cycle
   

          @@return:
              sub al, byte ptr es:[di]
              neg al
              pop bp
              ret
              endp

main:
       mov bx, offset String1
       push ds
       push bx       

       ;call MyStrlen               ; 1

       ;push 'w'
       ;push 7
       ;call MyMemChr               ; 2

       ;push '2'
       ;push 5
       ;call MyMemset               ; 3  

       ;mov dx, offset String2
       ;push dx
       ;push 7
       ;call MyMemCpy               ; 4

       ;mov dx, offset String2
       ;push dx
       ;push 7
       ;call MyMovMem               ; 5

       mov dx, offset String2
       push dx
       push 7
       call MyMemCmp                ; 6


exit:   
       mov ax, 4c00h	     
	int 21h

.data

String1: db 'helly_world$'  
String2: db 'hello_world$'    

end Start