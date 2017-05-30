; PortD.s
; Runs on TM4C1294
; Configura el puertoD para funcionar con un teclado matricial de 4x4
; Configura los pines D0-D3 como entrada y D4-D7 como salida
; activa pull-up para los pines de entrada
; activa interrupciones por down_edge en pines D0-D3
; conexiones:
;		1	2	3	4	5	6	7	8
;		D2	D0	D1	D3	D6	D7	D4	D5
; David Pinzon
; May 28, 2017

;THIS SOFTWARE IS PROVIDED "AS IS".  NO WARRANTIES, WHETHER EXPRESS, IMPLIED
;OR STATUTORY, INCLUDING, BUT NOT LIMITED TO, IMPLIED WARRANTIES OF
;MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE APPLY TO THIS SOFTWARE.
;VALVANO SHALL NOT, IN ANY CIRCUMSTANCES, BE LIABLE FOR SPECIAL, INCIDENTAL,
;OR CONSEQUENTIAL DAMAGES, FOR ANY REASON WHATSOEVER.

GPIO_PORTD_DATA				EQU	0x4005B000	;GPIO Data

GPIO_PORTD_0123				EQU	0x4005B03C	;GPIO PORTD Mask D0,D1,D2,D3
GPIO_PORTD_4567				EQU	0x4005B3C0	;GPIO PORTD Mask D4,D5,D6,D7

GPIO_PORTD_DIR				EQU	0x4005B400	;GPIO Dir
GPIO_PORTD_IS				EQU	0x4005B404	;GPIO Interrupt Sense
GPIO_PORTD_IBE				EQU	0x4005B408	;GPIO Interrupt Both Edges
GPIO_PORTD_IEV				EQU	0x4005B40C	;GPIO Interrupt Event
GPIO_PORTD_IM				EQU	0x4005B410	;GPIO Interrupt Mask
GPIO_PORTD_RIS				EQU	0x4005B414	;GPIO Raw Interrupt Status
GPIO_PORTD_MIS				EQU	0x4005B418	;GPIO Masked Interrupt Status
GPIO_PORTD_ICR				EQU	0x4005B41C	;GPIO Interrupt Clear
GPIO_PORTD_AFSEL			EQU	0x4005B420	;GPIO Alternate Function
GPIO_PORTD_PUR				EQU	0x4005B510	;GPIO Pull-Up Select
GPIO_PORTD_PDR				EQU	0x4005B514	;GPIO Pull-Down Select
GPIO_PORTD_DEN				EQU	0x4005B51C	;GPIO Digital Enable
GPIO_PORTD_AMSEL			EQU	0x4005B528	;GPIO Analog Mode Select
GPIO_PORTD_PCTL				EQU	0x4005B52C	;GPIO Port Control
GPIO_PORTD_SI				EQU	0x4005B538	;GPIO Select Interrupt
	
SYSCTL_RCGCGPIO_R			EQU 0x400FE608	;General-Purpose Input/Output Run Mode Clock Gating Control
SYSCTL_PRGPIO_R				EQU 0x400FEA08	;General-Purpose Input/Output Peripheral Ready
	
SYSCTL_RCGCGPIO_R3			EQU 0x00000008	;GPIO Port D Run Mode Clock Gating Control
SYSCTL_PRGPIO_R3			EQU 0x00000008	;GPIO Port D Peripheral Ready
	
NVIC_EN0_R					EQU 0xE000E100  ; Interrupt 0 to 31 Set Enable Register
NVIC_EN0_INT3				EQU 0x00000008  ; Interrupt 3 enable (GPIO PORT D)
	

		AREA    DATA, ALIGN=2
KeyInput	SPACE	1

		AREA    |.text|, CODE, READONLY, ALIGN=2
		THUMB
		EXPORT	KeyInput
	;functions to export
		EXPORT	InitPortD
		EXPORT	PORTD_Handler
		EXPORT	PortD_clearInterrupt
		EXPORT	PortD_detectInterrupt
			
;---------InitPortD---------
; Rutina de inicializacion del puerto D
; Input : none
; Output: none
; Modifies: none, all used Register are pushed and poped
InitPortD
	PUSH {R0,R1,LR}					; save current values of R0,R1,LR
	; activate clock for Port D
    LDR R1, =SYSCTL_RCGCGPIO_R      ; R1 = SYSCTL_RCGCGPIO_R (pointer)
    LDR R0, [R1]                    ; R0 = [R1] (value)
    ORR R0, R0, #SYSCTL_RCGCGPIO_R3 ; R0 = R0|SYSCTL_RCGCGPIO_R3
    STR R0, [R1]                    ; [R1] = R0
	
	; allow time for clock to stabilize
    LDR R1, =SYSCTL_PRGPIO_R        ; R1 = SYSCTL_PRGPIO_R (pointer)
GPIOJinitloop
    LDR R0, [R1]                    ; R0 = [R1] (value)
    ANDS R0, R0, #SYSCTL_PRGPIO_R3  ; R0 = R0&SYSCTL_PRGPIO_R3
    BEQ GPIOJinitloop               ; if(R0 == 0), keep polling
	
    ; set direction register
    LDR R1, =GPIO_PORTD_DIR			; R1 = GPIO_PORTD_DIR (pointer)
    LDR R0, [R1]                    ; R0 = [R1] (value)
    BIC R0, R0, #0x000F		        ; R0 = R0&~0x0F (make D0-D3 in)
	ORR R0, R0, #0x00F0				; R0 = R0&0xF0 (make D4-D7 out)
    STR R0, [R1]                    ; [R1] = R0
	
	;alternative functions select
    LDR R1, =GPIO_PORTD_AFSEL		; R1 = GPIO_PORTD_AFSEL (pointer)
    LDR R0, [R1]                    ; R0 = [R1] (value)
    BIC R0, R0, #0x00FF		        ; R0 = R0&~0x00FF (disable alternative functions D0-D7)
    STR R0, [R1]                    ; [R1] = R0
	
	; set pull-up register
    LDR R1, =GPIO_PORTD_PUR		    ; R1 = GPIO_PORTD_PUR (pointer)
    LDR R0, [R1]                    ; R0 = [R1] (value)
    ORR R0, R0, #0x000F				; R0 = R0|0x0F (enable pull-up on D0-D3)
    STR R0, [R1]                    ; [R1] = R0
	
	; set digital enable register
    LDR R1, =GPIO_PORTD_DEN		    ; R1 = GPIO_PORTD_DEN (pointer)
    LDR R0, [R1]                    ; R0 = [R1] (value)
    ORR R0, R0, #0x00FF				; R0 = R0|0xFF (enable digital I/O on D0-D7)
    STR R0, [R1]					; [R1] = R0
	
	; analog mode select register
    LDR R1, =GPIO_PORTD_AMSEL		; R1 = GPIO_PORTD_AMSEL (pointer)
    LDR R0, [R1]                    ; R0 = [R1] (value)
    BIC R0, R0, #0x00FF				; R0 = R0&~0xFF (disable analog functionality on D0-D7)
    STR R0, [R1]                    ; [R1] = R0
	
	; interrupt sense
	LDR R1,=GPIO_PORTD_IS			; R1 = GPIO_PORTD_IS (pointer)
	LDR R0,[R1]						; R0 = [R1] (value)
	BIC R0, R0, #0x0F				; R0 = R0&~0x0F (edge sensitive on D0-D3)
	STR R0,[R1]						; [R1] = R0
	
	; interrupt event
	LDR R1,=GPIO_PORTD_IEV			; R1 = GPIO_PORTD_IEV (pointer)
	LDR R0,[R1]						; R0 = [R1] (value)
	BIC R0, R0, #0x0F				; R0 = R0&~0x0F (falling edge on D0-D3)
	STR R0,[R1]						; [R1] = R0
	
	; interrupt mask
	LDR R1,=GPIO_PORTD_IM			; R1 = GPIO_PORTD_IM (pointer)
	LDR R0,[R1]						; R0 = [R1] (value)
	ORR R0, R0, #0x0F				; R0 = R0&~0x0F (interrupt on D0-D3 sent to the controller)
	STR R0,[R1]						; [R1] = R0
	
	; enable interrupt 3 in NVIC
    LDR R1, =NVIC_EN0_R             ; R1 = &NVIC_EN0_R (pointer)
    LDR R0, =NVIC_EN0_INT3          ; R0 = NVIC_EN0_INT3 (zeros written to enable register have no effect)
    STR R0, [R1]                    ; [R1] = R0
	
	; clear D4-D7
	LDR R1,=GPIO_PORTD_4567			; R1 = GPIO_PORTD_4567 (pointer)
	MOV R0,#0x00					; R0 = 0x00
	STR R0,[R1]						; [R1] = R0 (clear D4-D7)
	
	POP {R0,R1,PC}					; restore previuos values

;---------PORTD_Handler---------
; Rutina de interrupcion para detectar tecla presionada
; Input : none
; Output: none (character stored in KeyInput)
; Modifies: none, all used Register are pushed and poped
PORTD_Handler
	PUSH {R0,R1,R2,LR}				; save current values of R0,R1,LR
	LDR R1,=GPIO_PORTD_RIS			; R1 = &GPIO_PORTD_RIS (pointer)
	LDR R0, [R1]					; R0 = [R1] (GPIO_PORTD_RIS)	
	;check raw interrupt to find the bit interrupt
	CMP R0, #0x01					; R0 == 0x01 ? (D0 interrupt)
	BNE	handler_check_D1			; if not, go to handler_check_D1
	; acknowledge D0 interrupt
	BL	detect_line					; R0 = (line detected)
	LDR R1,=KeyInput				; R1 = &KeyInput (pointer)
	MOV R2, #'6'					; R2 = '6'
	CMP R0,#4						; R0 == 4 ?(KEY D0,D4?)
	STRBEQ R2,[R1]					; if so, [R1] = R2
	MOV R2, #'3'					; R2 = '3'
	CMP R0,#5						; R0 == 5 ?(KEY D0,D5?)
	STRBEQ R2,[R1]					; if so, [R1] = R2
	MOV R2, #'#'					; R2 = '#'
	CMP R0,#6						; R0 == 6 ?(KEY D0,D6?)
	STRBEQ R2,[R1]					; if so, [R1] = R2
	MOV R2, #'9'					; R2 = '9'
	CMP R0,#7						; R0 == 7 ?(KEY D0,D7?)
	STRBEQ R2,[R1]					; if so, [R1] = R2
handler_check_D1
	CMP R0, #0x02					; R0 == 0x02 ? (D1 interrupt)
	BNE	handler_check_D2			; if not, go to handler_check_D2
	; acknowledge D1 interrupt
	BL	detect_line					; R0 = (line detected)
	LDR R1,=KeyInput				; R1 = &KeyInput (pointer)
	MOV R2, #'5'					; R2 = '5'
	CMP R0,#4						; R0 == 4 ?(KEY D1,D4?)
	STRBEQ R2,[R1]					; if so, [R1] = R2
	MOV R2, #'2'					; R2 = '2'
	CMP R0,#5						; R0 == 5 ?(KEY D1,D5?)
	STRBEQ R2,[R1]					; if so, [R1] = R2
	MOV R2, #'0'					; R2 = '0'
	CMP R0,#6						; R0 == 6 ?(KEY D1,D6?)
	STRBEQ R2,[R1]					; if so, [R1] = R2
	MOV R2, #'8'					; R2 = '8'
	CMP R0,#7						; R0 == 7 ?(KEY D1,D7?)
	STRBEQ R2,[R1]					; if so, [R1] = R2	
handler_check_D2
	CMP R0, #0x04					; R0 == 0x04 ? (D2 interrupt)
	BNE	handler_check_D3			; if not, go to handler_check_D3
	; acknowledge D2 interrupt
	BL	detect_line					; R0 = (line detected)
	LDR R1,=KeyInput				; R1 = &KeyInput (pointer)
	MOV R2, #'B'					; R2 = 'B'
	CMP R0,#4						; R0 == 4 ?(KEY D2,D4?)
	STRBEQ R2,[R1]					; if so, [R1] = R2
	MOV R2, #'A'					; R2 = 'A'
	CMP R0,#5						; R0 == 5 ?(KEY D2,D5?)
	STRBEQ R2,[R1]					; if so, [R1] = R2
	MOV R2, #'D'					; R2 = 'D'
	CMP R0,#6						; R0 == 6 ?(KEY D2,D6?)
	STRBEQ R2,[R1]					; if so, [R1] = R2
	MOV R2, #'C'					; R2 = 'C'
	CMP R0,#7						; R0 == 7 ?(KEY D2,D7?)
	STRBEQ R2,[R1]					; if so, [R1] = R2
handler_check_D3
	CMP R0, #0x08					; R0 == 0x08 ? (D3 interrupt)
	BNE	handler_portd_done			; if not, go to handler_portd_done
	; acknowledge D3 interrupt
	BL	detect_line					; R0 = (line detected)
	LDR R1,=KeyInput				; R1 = &KeyInput (pointer)
	MOV R2, #'4'					; R2 = '4'
	CMP R0,#4						; R0 == 4 ?(KEY D3,D4?)
	STRBEQ R2,[R1]					; if so, [R1] = R2
	MOV R2, #'1'					; R2 = '1'
	CMP R0,#5						; R0 == 5 ?(KEY D3,D5?)
	STRBEQ R2,[R1]					; if so, [R1] = R2
	MOV R2, #'*'					; R2 = '*'
	CMP R0,#6						; R0 == 6 ?(KEY D3,D6?)
	STRBEQ R2,[R1]					; if so, [R1] = R2
	MOV R2, #'7'					; R2 = '7'
	CMP R0,#7						; R0 == 7 ?(KEY D3,D7?)
	STRBEQ R2,[R1]					; if so, [R1] = R2	
handler_portd_done
	;No se limpian las interrupociones
	;pograma VMC_MDB_MAIN debe limpiarlas
	
	POP {R0,R1,R2,PC}					; restore previuos values

;---------PortD_clearInterrupt---------
; Clear all raw interrupt vector of PORTD by writting FF in ICR
; Input : none
; Output: none
; Modifies: all used Register are pushed and poped
PortD_clearInterrupt
	PUSH {R0,R1,LR}			; save current values of R0,R1,LR
	LDR R1,=GPIO_PORTD_ICR	; R1 = GPIO_PORTD_ICR (pointer)
	LDR R0,[R1]				; R0 = [R1] (value)
	MOV R0,#0xFF			; R0 = 0xFF
	STR R0,[R1]				; [R1] = R0
	POP {R0,R1,PC}			; restore previuos values
	
;---------PortD_detectInterrupt---------
; Detect if an interrupt on PortD has ocurred
; Input : none
; Output: R0 = 1 on interrupt detected, 0 if not
; Modifies: R0 out, all used Register are pushed and poped
PortD_detectInterrupt
	PUSH {R1,LR}			; save current values of R0,R1,LR
	LDR R1,=GPIO_PORTD_RIS	; R1 = GPIO_PORTD_RIS (pointer)
	LDR R0,[R1]				; R0 = [R1] (value)
	ANDS R0, R0,#0xFF		; R0 = R0|0xFF
	POPEQ {R1,PC}			; If cero, no interrup, restore previuos values and return
	MOV R0,#1				; interrupt ocurred
	POP {R1,PC}				; restore previuos values
	
;---------detect_line---------
; Encuentra la line de la tecla presionada
; Input : none
; Output: R0, number of line detected (D4-D7)
; Modifies: R0 out, all used Register are pushed and poped
detect_line
	PUSH {R1,R2,R3,LR}			; save current values of R0,R1,LR
	LDR R3,=GPIO_PORTD_0123			; R2 = &GPIO_PORTD_0123
	LDR R0,[R3]						; R0 = [R2] (actual value of D0-D3)
	MOV R1,#0xFF					; R1 = 0xFF
detect_line_D4
	LDR R2,=GPIO_PORTD_DATA+0x40	; R2 = &(GPIO_PORTD_DATA+0x040)(D4 mask)
	STR R1,[R2]						; [R2] = R1 (set D4)
	LDR R2,[R3]						; R2 = [R3] (GPIO_PORTD_0123)
	CMP R0, R2						; R0 == R2 ? (no change on PORTD_0123 ?)
	BEQ detect_line_D5				; if so, go to detect_line_D5
	; acknowledge D4 line
	MOV R0,#4
	B	detect_line_done	
detect_line_D5
	LDR R2,=GPIO_PORTD_DATA+0x80	; R2 = &(GPIO_PORTD_DATA+0x080)(D5 mask)
	STR R1,[R2]						; [R2] = R1 (set D5)
	LDR R2,[R3]						; R2 = [R3] (GPIO_PORTD_0123)
	CMP R0, R2						; R0 == R2 ? (no change on PORTD_0123 ?)
	BEQ detect_line_D6				; if so, go to detect_line_D6
	; acknowledge D5 line
	MOV R0,#5
	B	detect_line_done
detect_line_D6
	LDR R2,=GPIO_PORTD_DATA+0x100	; R2 = &(GPIO_PORTD_DATA+0x100)(D6 mask)
	STR R1,[R2]						; [R2] = R1 (set D6)
	LDR R2,[R3]						; R2 = [R3] (GPIO_PORTD_0123)
	CMP R0, R2						; R0 == R2 ? (no change on PORTD_0123 ?)
	BEQ detect_line_D7				; if so, go to detect_line_D7
	; acknowledge D6 line
	MOV R0,#6
	B	detect_line_done
detect_line_D7
	LDR R2,=GPIO_PORTD_DATA+0x200	; R2 = &(GPIO_PORTD_DATA+0x200)(D7 mask)
	STR R1,[R2]						; [R2] = R1 (set D7)
	LDR R2,[R3]						; R2 = [R3] (GPIO_PORTD_0123)
	CMP R0, R2						; R0 == R2 ? (no change on PORTD_0123 ?)
	BEQ detect_line_done			; if so, go to detect_line_done
	; acknowledge D5 line
	MOV R0,#7
	B	detect_line_done
detect_line_done
	; clear D4-D7
	LDR R1,=GPIO_PORTD_4567			; R1 = GPIO_PORTD_4567 (pointer)
	MOV R2,#0x00					; R2 = 0x00
	STR R2,[R1]						; [R1] = R2 (clear D4-D7)	
	POP {R1,R2,R3,PC}			; restore previuos values

	ALIGN                           ; make sure the end of this section is aligned
    END                             ; end of file