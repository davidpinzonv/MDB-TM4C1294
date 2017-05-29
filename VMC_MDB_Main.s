; VMC_MDB_Main.s
; Runs on TM4C1294
; Implementacion basica de un controlador de maquina expendedroa VCM
; David Pinzon & Alberto Lopez
; May 27, 2017

;THIS SOFTWARE IS PROVIDED "AS IS".  NO WARRANTIES, WHETHER EXPRESS, IMPLIED
;OR STATUTORY, INCLUDING, BUT NOT LIMITED TO, IMPLIED WARRANTIES OF
;MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE APPLY TO THIS SOFTWARE.
;VALVANO SHALL NOT, IN ANY CIRCUMSTANCES, BE LIABLE FOR SPECIAL, INCIDENTAL,
;OR CONSEQUENTIAL DAMAGES, FOR ANY REASON WHATSOEVER.

COIN_CHANGER_ADDR					EQU 0x0008

; functions from PLL.s
        IMPORT PLL_Init

;functions from Systick.s
		IMPORT delay

; function from PortD.s
		IMPORT InitPortD
		IMPORT PortD_clearInterrupt
		IMPORT PortD_detectInterrupt
		IMPORT KeyInput ;(memory adress)

; functions from UARTInts.s
        IMPORT UART_Init
			
; functions from mdb.s
		IMPORT MDB_SendAddress
		IMPORT MDB_SendCommand
		IMPORT MDB_SendACK
		IMPORT MDB_SendRET
		IMPORT MDB_SendNAK
		IMPORT MDB_GetAnswer
		IMPORT MDB_SendBusReset
		IMPORT MDB_InitCoinChanger
		IMPORT MDB_SendPool
		IMPORT MDB_DispenseValue
		
		IMPORT Command
		IMPORT DataIn
		IMPORT Setup_buf
		IMPORT Tube_status_buf
		IMPORT Pool_buf
		IMPORT Identification_buf
		IMPORT Payout_status_buf
		IMPORT Send_diag_status_buf

		AREA	DATA, ALIGN=2
credit		SPACE	4	; holds the credit
items_value	SPACE	14	; holds the items value in Hex ascending order, byte 1 for item 0 upto byte 14 for item D

		EXPORT items_value	; global only for observation using debugger
		EXPORT credit	; global only for observation using debugger

        AREA    |.text|, CODE, READONLY, ALIGN=2
        THUMB
        EXPORT Start

    ALIGN                           ; make sure the end of this section is aligned

Start
    BL  PLL_Init                    ; set system clock to 120 MHz
	BL	InitPortD					; initialize PortD (for MatrixPad)
    BL  UART_Init                   ; initialize UART (portA used)
	BL	Init_items_value			; inicializa el buffer con los valores de los items
	BL	MDB_InitCoinChanger			; Rutina de inicializacion del coin changer
	LDR R0,=credit					; R0 = $credit
	MOV R1,#0						; R1 = 0
	STR R1,[R0]						; [R0] = R1 (initializing credit in 0)
	
	;waiting for coins loop until coin is accepted
WaitingForCoinsLoop
	MOV	R0,#COIN_CHANGER_ADDR		; R0 = COIN_CHANGER_ADDR
	BL	MDB_SendPool				; Sending Pool command
Waiting_gettingAnswer
	LDR R0,=DataIn					; R0 = &DataIn (pointer)
	BL	MDB_GetAnswer				; Geeting Answer in DataIn
	CMP R0,#1						; R0 == 1?
	BEQ	continue_waitingForCoins	; if so, go to continue_waitingForCoins
	CMP R0,#0						; R0 == 0?
	BLEQ MDB_SendRET				; if so, Send Ret
	CMP R0,#0						; R0 == 0?
	BEQ	Waiting_gettingAnswer		; if so, go to Waiting_gettingAnswer
	BL	MDB_SendACK					; Sendind ACK
	LDR R1,=DataIn					; R1 = &DataIn (pointer)
	MOV R0,#0						; R0 = 0 (clean register)
	LDRB R0,[R1]					; R0 = [R1]
	AND R0,R0,#2_11000000			; R0 = R0 && 2_11000000
	CMP R0,#2_01000000				; R0 == 2_01000000? (coin deposited)?
	BNE	continue_waitingForCoins	; if not, go to continue_waitingForCoins
	AND R0,R0,#2_00110000			; R0 = R0 && 2_00110000
	CMP	R0,#2_00100000				; R0 == 2_00100000 ? (coin not used)
	BEQ	continue_waitingForCoins	; if so, go to continue_waitingForCoins
	CMP	R0,#2_00110000				; R0 == 2_00110000 ? (coin reject)
	BEQ	continue_waitingForCoins	; if so, go to continue_waitingForCoins
	LDRB R0,[R1]					; R1 = [R0]
	AND R0,R0,#2_00001111			; R1 = R1 && 2_00001111
	BL	AddCredit					; add credit from coin type deposited (R0)
	B	WithCreditLoop				; go to WithCreditLoop
continue_waitingForCoins
	BL	PortD_detectInterrupt		; R0 = (PORTD Interrupt Status)
	CMP	R0,#1						; R0 == 1 ? (PortD Interrupt Occurred)?
	BEQ	print_item_value			; Imprime al LCD valor del producto, limpia interrupciones
	MOV	R0,#150						; R0 = 150
	BL	delay						; delay for (R0)150ms
	B	WaitingForCoinsLoop			; unconditional branch

	; stay in loop with credit getting coins until buy item or cancel
WithCreditLoop
	LDR	R1,=credit					; R1 = &credit (pointer)
	LDRB R0,[R1]					; R0 = R1
	;R0 has the value, send to print
	;BL LCD_print_value
	MOV	R0,#COIN_CHANGER_ADDR		; R0 = COIN_CHANGER_ADDR
	BL	MDB_SendPool				; Sending Pool command
Waiting_gettingAnswer_2
	LDR R0,=DataIn					; R0 = &DataIn (pointer)
	BL	MDB_GetAnswer				; Geeting Answer in DataIn
	CMP R0,#1						; R0 == 1?
	BEQ	continue_WithCreditLoop		; if so, go to continue_waitingForCoins
	CMP R0,#0						; R0 == 0?
	BLEQ MDB_SendRET				; if so, Send Ret
	CMP R0,#0						; R0 == 0?
	BEQ	Waiting_gettingAnswer_2		; if so, go to Waiting_gettingAnswer
	BL	MDB_SendACK					; Sendind ACK
	LDR R1,=DataIn					; R1 = &DataIn (pointer)
	MOV R0,#0						; R0 = 0 (clean register)
	LDRB R0,[R1]					; R0 = [R1]
	AND R0,R0,#2_11000000			; R0 = R0 && 2_11000000
	CMP R0,#2_01000000				; R0 == 2_01000000? (coin deposited)?
	BNE	continue_WithCreditLoop		; if not, go to continue_WithCreditLoop
	AND R0,R0,#2_00110000			; R0 = R0 && 2_00110000
	CMP	R0,#2_00100000				; R0 == 2_00100000 ? (coin not used)
	BEQ	continue_WithCreditLoop		; if so, go to continue_WithCreditLoop
	CMP	R0,#2_00110000				; R0 == 2_00110000 ? (coin reject)
	BEQ	continue_WithCreditLoop		; if so, go to continue_WithCreditLoop
	LDRB R0,[R1]					; R1 = [R0]
	AND R0,R0,#2_00001111			; R1 = R1 && 2_00001111
	BL	AddCredit					; add credit from coin type deposited (R0)
continue_WithCreditLoop
	BL	PortD_detectInterrupt		; R0 = (PORTD Interrupt Status)
	CMP	R0,#1						; R0 == 1 ? (PortD Interrupt Occurred)?
	BNE	continue_WithCreditLoopYet	; if not, go to continue_WithCreditLoopYet
	; acknowledge key was pressed
	LDR R1,=KeyInput				; R1 = &KeyInput (pointer)
	LDR R0,[R1]						; R0 = [R1]
	CMP R0,#'*'						; R0 == '*' ?
	BLEQ PortD_clearInterrupt		; if so, clean interrupt of portD
	CMP R0,#'*'						; R0 == '*' ?
	BEQ continue_WithCreditLoopYet	; if so, go to continue_WithCreditLoopYet
	CMP R0,#'#'						; R0 == '#' ?
	BNE	time_to_verify_credits		; if not, go to time_to_verify_credits
	BL	PortD_clearInterrupt		; clean interrupt of portD
	LDR R1,=credit					; R1 = &credit (pointer)
	LDR R0, [R1]					; R0 = [R1]
	BL	MDB_DispenseValue			; Dispense Value in R0
	MOV R0,#0						; R0 = 0 (actualiza creditos)
	STR R0,[R1]						; [R1] = R0 (0 creditos)
	B	continue_waitingForCoins	; go to continue_waitingForCoins unconditional
	; acknowledge item solicited
time_to_verify_credits
	
continue_WithCreditLoopYet
	MOV	R0,#150						; R0 = 150
	BL	delay						; delay for (R0)150ms
	B	WithCreditLoop				; unconditional branch


;---------print_item_value---------
; Imprime el valor del producto seleccionado por KeyInput
; Limpia interrupcion del puertoD
; Input : none
; Output: none (print to lcd)
; Modifies: none, all used Registers are pushed and poped
print_item_value
	PUSH {R0,R1,R2,LR}				; save current values of R0,R1,LR
	BL	PortD_clearInterrupt		; Clear PortD Raw Status Interrupt
	LDR R2,=items_value				; R2 = $items_value (pointer)
	LDR R0,=KeyInput				; R0 = $KeyInput (pointer)
	LDR R1,[R0]						; R1 = [R0]
	CMP R1,#'0'						; R1 == '0' ?
	LDRBEQ R0,[R2]					; if so, R0 = [R2]
	CMP R1,#'1'						; R1 == '1' ?
	LDRBEQ R0,[R2,#1]				; if so, R0 = [R2]
	CMP R1,#'2'						; R1 == '2' ?
	LDRBEQ R0,[R2,#2]				; if so, R0 = [R2]
	CMP R1,#'3'						; R1 == '3' ?
	LDRBEQ R0,[R2,#3]				; if so, R0 = [R2]
	CMP R1,#'4'						; R1 == '4' ?
	LDRBEQ R0,[R2,#4]				; if so, R0 = [R2]
	CMP R1,#'5'						; R1 == '5' ?
	LDRBEQ R0,[R2,#5]				; if so, R0 = [R2]
	CMP R1,#'6'						; R1 == '6' ?
	LDRBEQ R0,[R2,#6]				; if so, R0 = [R2]
	CMP R1,#'7'						; R1 == '7' ?
	LDRBEQ R0,[R2,#7]				; if so, R0 = [R2]
	CMP R1,#'8'						; R1 == '8' ?
	LDRBEQ R0,[R2,#8]				; if so, R0 = [R2]
	CMP R1,#'9'						; R1 == '9' ?
	LDRBEQ R0,[R2,#9]				; if so, R0 = [R2]
	CMP R1,#'A'						; R1 == 'A' ?
	LDRBEQ R0,[R2,#10]				; if so, R0 = [R2]
	CMP R1,#'B'						; R1 == 'B' ?
	LDRBEQ R0,[R2,#11]				; if so, R0 = [R2]
	CMP R1,#'C'						; R1 == 'C' ?
	LDRBEQ R0,[R2,#12]				; if so, R0 = [R2]
	CMP R1,#'D'						; R1 == 'D' ?
	LDRBEQ R0,[R2,#13]				; if so, R0 = [R2]
	;R0 has the value, send to print
	;BL LCD_print_value
	POP {R0,R1,R2,PC}				; restore previuos values
	
;---------Init_items_value---------
; Inicializa los valores de los items avender
; Valores de prueba: item_value=#item+1
; Input : none
; Output: none
; Modifies: none, all used Registers are pushed and poped
Init_items_value
	PUSH {R0,R1,LR}				; save current values of R0,R1,LR
	LDR R1,=items_value				; R1 = &items_value (pointer)
	MOV R0,#1						; R0 = 1
items_value_loop
	STRB R0,[R1],#1					; [R1] = R0, R1 = R1+1 (increment pointer after sstore)
	ADD R0,R0,#1					; R0 = R0 + 1
	CMP	R0,#15						; R0 == 15 ?
	BNE	items_value_loop			; if not, go to	items_value_loop
	POP {R0,R1,PC}				; restore previuos values
	
;---------AddCredit---------
; Actualiza el valor de credito disponible
; Input : R0, coin type deposited
; Output: none
; Modifies: none, all used Registers are pushed and poped
AddCredit
	PUSH {R0,R1,R2,LR}			; save current values of R0,R1,LR
	LDR R2,=credit				; R2 = &credit (pointer)
	LDR R1,[R2]					; R1 = [R2] (actual credit)
	LDR R2,=Setup_buf			; R2 = &Setup_buf (pointer)
	ADD R2,R2,#7				; R2 = R3 + 7
	ADD R2,R2,R0				; R2 = R2 + R0
	LDR R0, [R2]				; R0 = [R2] (coin value)
	ADD R1, R1, R0				; R1 = R1 + R0
	LDR R0,=credit				; R0 = &credit (pointer)
	STR R1,[R0]					; [R0] = R1
	POP {R0,R1,PC}				; restore previuos values
	
    ALIGN                           ; make sure the end of this section is aligned
    END                             ; end of file