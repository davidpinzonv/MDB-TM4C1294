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
	


	;functions to export
		EXPORT	InitPortD
		EXPORT	PORTD_Handler
			
		AREA    |.text|, CODE, READONLY, ALIGN=2
		THUMB
			
InitPortD
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


;---------PORTD_Handler---------
; Rutina de interrupcion para detectar tecla presionada
; Input : none
; Output: none
; Modifies: none, all used Register are pushed and poped
PORTD_Handler
	PUSH {R0,R1,LR}					; save current values of R0,R1,LR
	LDR R1,=GPIO_PORTD_RIS			; R1 = &GPIO_PORTD_RIS (pointer)
	LDR R0, [R1]					; R0 = [R1] (GPIO_PORTD_RIS)	
	;check raw interrupt to find the bit interrupt
	CMP R0, #0x01					; R0 == 0x01 ? (D0 interrupt)
	BNE	handler_check_D1
	; acknowledge D0 interrupt
	
handler_check_D1
	CMP R0, #0x02					; R0 == 0x02 ? (D1 interrupt)
	BNE	handler_check_D2
	; acknowledge D1 interrupt
handler_check_D2
	CMP R0, #0x04					; R0 == 0x04 ? (D2 interrupt)
	BNE	handler_check_D3
	; acknowledge D2 interrupt
handler_check_D3
	CMP R0, #0x08					; R0 == 0x08 ? (D3 interrupt)
	BNE	handler_portd_done
	; acknowledge D3 interrupt
handler_portd_done
	; clear interrupt
	LDR R1,=GPIO_PORTD_ICR	; R1 = GPIO_PORTD_ICR (pointer)
	LDR R0,[R1]				; R0 = [R1] (value)
	ORR R0,R0,#0xFF			; R0 = R0|0x01
	STR R0,[R1]				; [R1] = R0
	
	POP {R0,R1,PC}					; restore previuos values
	
;---------detect_line---------
; Encuentra la line de la tecla presionada
; Input : R0, actual GPIO Raw Interrup Status
; Output: none
; Modifies: none, all used Register are pushed and poped
detect_line
	PUSH {R0,R1,LR}					; save current values of R0,R1,LR
	POP {R0,R1,PC}					; restore previuos values

	ALIGN                           ; make sure the end of this section is aligned
    END                             ; end of file