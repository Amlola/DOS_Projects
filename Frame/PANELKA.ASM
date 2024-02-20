.model tiny
.code
.286
org 100h
locals @@


; ADRESS:
VMEM          equ 0b800h  	
CMD_LINE      equ 00082h     ; First symbol in cmd params


; COLORS:
SHADOW_COLOR  equ 30h        ; blue
COLOR_STRING  equ 1ah        ; light blue \ blue


; CONSTANTS:
SPACE		  equ 20h

COORD_X0      equ 10    
COORD_Y0   	  equ 5          ; start coord for panelka
SCREEN_WIDTH  equ 80

D_ADRESS 	  equ 10		 ; offset to line

ZERO  		  equ 30h
ONE   		  equ 31h		 
TWO   		  equ 32h		 ; number of type
THREE         equ 33h
FOUR          equ 34h

DELTA_X 	  equ 2    		
DELTA_Y 	  equ 1    		 ; delta for shadow

;-----------------------------------------------------------------------------------------------                  

Start:  mov bx, VMEM                  			  		    ; &Vmem          
	    mov es, bx	
		  
	    mov si, CMD_LINE              			  		    ; &CMD_LINE		

	    mov di, (COORD_Y0 * SCREEN_WIDTH + COORD_X0) * 2    ; begin Vmem

main: 	    
		call DataInput

		cmp al, '*'					  			  			 ; custom_call
		je create_panelka
		
		cmp al, ZERO
		mov si, offset STRING_ARRAY
		je create_panelka

		cmp al, ONE
		mov si, offset STRING_ARRAY + D_ADRESS		
		je create_panelka

		cmp al, TWO
		mov si, offset STRING_ARRAY + D_ADRESS * 2
		je create_panelka

		cmp al, THREE
		mov si, offset STRING_ARRAY + D_ADRESS * 3
		je create_panelka

		cmp al, FOUR
		mov si, offset STRING_ARRAY + D_ADRESS * 4
		je create_panelka
		
		create_panelka:
			call WritePanelka
			call PrintText
	    jmp exit

;---------------------------------------------------------------------
;Entry:   si - current &adress CMD_LINE
;Destr:   si
;---------------------------------------------------------------------
SkipSpaces  proc

		    @@cycle:
			    cmp byte ptr [si], SPACE
				jne @@return

				inc si
				jmp @@cycle
				 
			@@return:
			 	ret
			 	endp

;-----------------------------------------input_block---------------------------------------

;---------------------------------------------------------------------
;Entry:   si - current &adress CMD_LINE
;		  al - symbol
;
;Destr:   si, al
;Return:  bx - coord
;---------------------------------------------------------------------
GetInt 			proc

				call SkipSpaces

				lodsb
				sub al, '0'						; get fisrt number			

				cmp byte ptr [si], SPACE
				mov bx, ax						; save number
				je @@return
					
				mov bl, 10
				mul bl

				mov bx, ax
				xor ax, ax

				lodsb
				sub al, '0'
				add bx, ax

				@@return:
					ret
					endp

;---------------------------------------------------------------------
;Entry:   si - current &adress CMD_LINE
;		  al - symbol
;
;Destr:   si, al
;Return:  bx = d_y, cx = d_x 
;---------------------------------------------------------------------
GetCoordinates 	proc

				call GetInt

				mov cx, bx
	
				call GetInt

				ret
				endp

;---------------------------------------------------------------------
;Entry:   si - current &adress CMD_LINE
;		  al - symbol
;
;Destr:   si, al
;Return:  ah - attribute 
;---------------------------------------------------------------------		
GetHexColor     proc

				call SkipSpaces

				lodsb
				sub al, '0'				; al - 30h

				cmp al, 10				; letter > 10
				jae take_letter

				jmp take_first_symbol

				take_letter:
					sub al, 27h			; al - ('a' - 10d), 'a' = 61h
  
				take_first_symbol:
					mov dx, 10h
					mul dx
					mov ah, al

				lodsb
				sub al, '0'

				cmp al, 10
				jae take_second_letter

				jmp take_second_symbol

				take_second_letter:
					sub al, 27h
  
				take_second_symbol:
					add ah, al
				
				ret
				endp

;---------------------------------------------------------------------
;Entry:   si - current &adress CMD_LINE
;		  al - symbol
;
;Assumes: ES = ob800h
;Destr:   si, al
;Return:  dx = &text, si = &costum_ramka
;---------------------------------------------------------------------
GetTypeOfRamka	proc

				call SkipSpaces
				
				lodsb
				cmp al, '*'
				je custom_call

				call SkipSpaces
				mov dx, si
				jmp @@return

				custom_call:
					mov dx, si
					add si, 9d					; save &string in dx
					call SkipSpaces
					xchg dx, si

				@@return:
					ret
					endp


DataInput		proc	
		 
				call GetCoordinates

				call GetHexColor

				call GetTypeOfRamka

				ret
				endp
 
;-----------------------------------------print_frame_block---------------------------------------

;---------------------------------------------------------------------
;writes a line to Vmem
;Entry: cx = d_x
;		di - current cell Vmem
;       ah - attribute
;		si = current &frame
;Destr:   si, di, al
;---------------------------------------------------------------------
WriteHorLine proc
		 	 
			 cld
			 
			 push cx	   ; save d_x

			 sub cx, 2     ; !rep

			 lodsb		   ; first
			 stosw		  

			 lodsb		   ; middle
			 rep stosw	   
			
			 lodsb		   ; last
			 stosw

			 pop cx

			 sub si, 3

			 ret
			 endp


;---------------------------------------------------------------------
;Writes frame
;Entry:	di - current cell Vmem
;		si = current &frame
;		cx = d_x 
;		bx = d_y
;Destr:   di, bx, al, si
;Return:  bx = centre_of_frame (y_coord)
;---------------------------------------------------------------------
WritePanelka    proc

				call DrawFirstLine
				cmp bx, 0
				je draw_shadow_under

				draw:
					call WriteHorLine

					call DrawRightShadow

					call VmemShift

					dec bx

					cmp bx, 1
					jne draw

				call DrawLastLine

				draw_shadow_under:
					call DrawShadowUnderPanelka

				add di, (COORD_Y0 * SCREEN_WIDTH + COORD_X0) * 2
				shr di, 1						; fix
				mov ax, di
				mov bl, SCREEN_WIDTH * 2		; save bx centre ramka
				div bl
				xor ah, ah
				mov bx, ax
					
				ret
				endp

;---------------------------------------------------------------------
;Writes frame
;Entry:	 di - current cell Vmem
;		 cx - d_x
;Destr:  di
;Return: di = &new_line
;---------------------------------------------------------------------
VmemShift       proc

				push ax
          
				mov ax, SCREEN_WIDTH    ; to new line
				sub ax, cx				; shift left
				shl ax, 1				; fix
	
				add di, ax

				pop ax

				ret
				endp

;---------------------------------------------------------------------
;Entry: cx = d_x
;		bx = d_y
;		si = current &frame
;Destr: si, bx, di
;---------------------------------------------------------------------
DrawFirstLine	proc

				call WriteHorLine
				call VmemShift
				dec bx
				add si, 3

				ret
				endp

;---------------------------------------------------------------------
;Entry: cx = d_x
;		bx = d_y
;		si = current &frame
;Destr: si, bx, di
;---------------------------------------------------------------------
DrawLastLine	proc

				add si, 3
				call WriteHorLine
				call DrawRightShadow
				call VmemShift

				ret
				endp


;---------------------------------------------------------------------
;Entry: di - current cell Vmem
;	  	ah - color attr
;	  	al - symbol
;Destr: di, ah, al
;---------------------------------------------------------------------
DrawShadowUnderPanelka  proc
						
						push ax
						push cx

						mov ah, SHADOW_COLOR
						mov al, SPACE

						add di, DELTA_X * 2

						rep	stosw

						sub di, DELTA_X * 2

						pop cx
						pop ax
					
						ret
						endp
			

;---------------------------------------------------------------------
;Entry: di - current cell Vmem
;	  	ah - color attr
;	  	al - symbol
;Destr: di, ah, al
;---------------------------------------------------------------------
DrawRightShadow		proc

					push cx	
					push ax

					mov cx, DELTA_X
					mov ah, SHADOW_COLOR
					mov al, SPACE

					rep	stosw

					sub di, DELTA_X * 2

					pop ax
					pop cx

					ret
					endp

;-----------------------------------------print_text_block---------------------------------------

;---------------------------------------------------------------------
;Entry:   si = &string
;Destr:   si, al
;Return:  dx = len(str), ax = len(title)
;---------------------------------------------------------------------
GetSizeTextAndTitle proc

					push si								; save &string

					mov al, ':'							; delimetr

					jmp @@cycle

					@@check_title:
						push dx
						mov al, 0dh

					@@cycle:
						cmp byte ptr [si], 0dh
						je @@print						;  dx = len(str)

						cmp byte ptr [si], al
						je @@check_title

						inc si
						inc dx				
						jmp @@cycle
						
					@@print:
					cmp al, ':'
					je @@no_title

					pop ax								; ax = len(title)
					jmp @@return

					@@no_title:
					xor ax, ax

					@@return:
						pop si  						; si = &string
						ret
						endp

;---------------------------------------------------------------------
;Entry:   di - current cell Vmem
;		  cx = d_x
;		  ax = len(title)
;		  dx = len(text)
;Destr:   di, cx, ax, dx
;Return:  di = &centre_of_frame (given the line)
;---------------------------------------------------------------------
Get_DI_Of_Center	proc

					push ax							; len(title)
					push cx							; delta_x		

					add cx, dx
					mov ax, cx
					and ax, 1						; fix
					cmp ax, 1
					jne even_number

					add di, 1

					even_number:
						pop cx
						add di, cx
						sub di, dx
						add di, 2 * COORD_X0		; get di center for text

						mov ax, bx
						mov bx, SCREEN_WIDTH * 2
						mul bx
						add di, ax

					pop ax							; ax = len(title)

					ret
					endp

;---------------------------------------------------------------------
;Entry:   di - current cell Vmem
;		  cx = d_x
;		  ax = len(title)
;Destr:   di, cx, ax, dx
;Return:  di = &centre_of_title (given the line)
;---------------------------------------------------------------------
Get_DI_Centre_Title 	proc

						mov dx, di
						push cx

						mov di, (COORD_Y0 * SCREEN_WIDTH + COORD_X0) * 2
						add cx, bx
						mov ax, cx
						and ax, 1

						cmp ax, 1
						jne @@even_number

						add di, 1

						@@even_number:
							pop cx
							add di, cx
							sub di, bx

						ret
						endp


;---------------------------------------------------------------------
;Entry:   di - current cell Vmem
;	  	  dx - current &string
;		  cx = d_x
;		  bx = d_y  
;Destr:   ah, di, al
;---------------------------------------------------------------------
PrintText	proc

			mov si, dx						; si = &string
			xor dx, dx

			call GetSizeTextAndTitle

			xor di, di
			sub dx, ax
			sub dx, 1						; -delimetr

			call Get_DI_Of_Center
			
			cmp ax, 0						; no title
			mov bx, ax
			mov ah, COLOR_STRING
			je @@print_text

			call Get_DI_Centre_Title

			mov ah, COLOR_STRING
			@@print_title:
				lodsb
				cmp al, ':'
				je di_to_center

				stosw
				jmp @@print_title

			di_to_center:
				mov di, dx

			@@print_text:
				lodsb
				cmp al, 0dh
				je @@return
				
				stosw
				jmp @@print_text
					
			@@return:
				ret
				endp


exit:   mov ax, 4c00h	     
	    int 21h

.data	
	STRING_ARRAY: db '         $'
		      	  db 0dah, 0c4h, 0bfh, 0b3h, 020h, 0b3h, 0c0h, 0c4h, 0d9h, '$'
		      	  db 0c9h, 0cdh, 0bbh, 0bah, 020h, 0bah, 0c8h, 0cdh, 0bch, '$'
				  db ' $' 
		      	  db '/-\+ *\-/$'
end Start