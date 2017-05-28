; mdb.s
; Runs on TM4C1294
; Modulo de funciones del protocolo MDB
; usando funciones del modulo de UARTInts.s
; David Pinzon & Alberto Lopez
; May 27, 2017

;functions from UARTInts.s
        IMPORT UART_Init
        IMPORT UART_InChar
        IMPORT UART_OutChar
        IMPORT UART0_Handler
        IMPORT UART_OutString
        IMPORT UART_InUDec
        IMPORT UART_OutUDec
        IMPORT UART_InUHex
        IMPORT UART_OutUHex
        IMPORT UART_InString
		IMPORT UART_HighStickParity
		IMPORT UART_LowStickParity

;functions from GPTimer.s
		IMPORT Timer_ResponseTime
		IMPORT Timer_ResponseTime_stop
		IMPORT Timer_BreakTime
		IMPORT Timer_SetupTime
		IMPORT Timer_PollingTime
		IMPORT Timer_NoResponseTime
		IMPORT Timer_NoResponseTime_stop
			
        AREA    DATA, ALIGN=2
CMDLEN  EQU     36      ; max size of command
Command	SPACE   (CMDLEN)
DataIn	SPACE	(CMDLEN)
        EXPORT Command
		EXPORT DataIn
	;functions to export
		EXPORT MDB_SendAddress
		EXPORT MDB_SendCommand
		EXPORT MDB_SendACK
		EXPORT MDB_SendRET
		EXPORT MDB_SendNAK
		EXPORT MDB_GetAnswer
        AREA    |.text|, CODE, READONLY, ALIGN=2
        THUMB

;-----------MDB_SendAddress-----------
; Envia la direccion de un periferico
; activa High Stick Parity bit to send adress
; activa Low Stick parity after send
; Input : R0 8-bit address
; Output: none
MDB_SendAddress
	PUSH {R0, R1, LR}          	; save current value of R0, R1 and LR
	BL	UART_HighStickParity	; set high stick parity
	BL	UART_OutChar				; note: modifies R0 and R1
	BL	UART_LowStickParity			; set to low stick parity
	POP {R0, R1, PC}           	; restore previous value of R0 into R0, R1 into R1, and LR into PC (return)
	
;-----------MDB_SendCommand-----------
; Envia comando/datos a un periferico
; Input : R0 address (for chkSum), R1 pointer to commands, R2 number of command/data bytes to be send
; Output: none
; Modifies: none, all used Register are pushed and poped
MDB_SendCommand
	PUSH {R0, R1, R2, R3, R4, R5, LR}	; save current value of R0, R1, R2, R3, R4, R5 and LR
	MOV R5, R0						; R5 = R0 save initial value of ChkSum
	MOV R4, R1						; R4 = R1 (save the command pointer)
	MOV R3, R2						; R3 = R2 (save number of command/data bytes)
	MOV R2, #0						; initialize counter, contador de datos enviados
outCommandLoop
	CMP R2, R3						; is counter = number of commands to send ?
	BEQ outCommandDone				; if so, its done, skip to 'outCommandDone'
	LDR R0, [R4]					; R0 = [R4] carga el byte a ser enviado
	ADD R5, R5, R0					; actualiza chksum byte
	BL	UART_OutChar				; envia el byte en R0, note: modifies R0 and R1
	ADD R4, R4, #1					; R4 = R4 + 1 incrementa el command pointer
	ADD R2, R2, #1					; R2 = R2 + 1 incrementa el contador
	B	outCommandLoop
outCommandDone
	MOV	R0, R5						; R0 = R5 Copy chksum to R0
	BL	UART_OutChar				; send chksum byte
									; restore previous value of R0 into R0, R1 into R1, R2 into R2
	POP {R0, R1, R2, R3, R4, R5, PC}	; R3 into R3, R4 into R4, R5, into R5 and LR into PC (return)


;-----------MDB_SendACK-----------
; Envia el ACK byte
; Input : none
; Output: none
; Modifies: none, all used Register are pushed and poped
MDB_SendACK
	PUSH {R0, R1, LR}
	MOV R0, #0						; R0 = 0x00H (ACK)
	BL	UART_OutChar				; envia ACK, note: modifies R0 and R1
	POP	{R0, R1, PC}

;-----------MDB_SendRET-----------
; Envia el RET byte
; Input : none
; Output: none
; Modifies: none, all used Register are pushed and poped
MDB_SendRET
	PUSH {R0, R1, LR}
	MOV R0, #170					; R0 = 0xAAH (RET)
	BL	UART_OutChar				; envia RET, note: modifies R0 and R1
	POP	{R0, R1, PC}
	
;-----------MDB_SendNAK-----------
; Envia el NAK byte
; Input : none
; Output: none
; Modifies: none, all used Register are pushed and poped
MDB_SendNAK
	PUSH {R0, R1, LR}
	MOV R0, #255					; R0 = 0xFFH (NAK)
	BL	UART_OutChar				; envia NAK, note: modifies R0 and R1
	POP	{R0, R1, PC}
	
;-----------MDB_GetAnswer-----------
; Recibe datos/respuesta del periferico
; se debe tener activado LOW Stick Parity, o se cicla la funcion
; Input : R0 pointer to DataIn buffer
; Output: R0 number of data bytes getted, included chk(if apply), 0 if chksum failed
; Modifies: R0, all used Register are pushed and poped
; DataIn buffer upgraded.
MDB_GetAnswer
	PUSH {R1, R2, R3, R4, R5, LR}	; save current value of R0, R1, R2, R3, R4, R5 and LR
	MOV R3, R0						; R3 = R0 (save the DataIn pointer buffer)	
	MOV R2, #0						; initialize counter, contador de datos recibidos
	MOV R4, #0						; initialize chksum
	MOV R5, #0						; personal flag for Stick Parity Interrup
getAnswerLoop						; stay in loop util interruption by stick parity detected	
	BL	UART_InChar					; get byte from UART
	STRB R0, [R3]                   ; [R3] = R0 (store 8 least significant bits of R0 into location pointed to by R4)
    ADD R3, R3, #1                  ; R4 = R4 + 1 (bufferPt = bufferPt + 1)
	CMP R5, #1						; R5 = 1 ? (R5 modified by Stick Parity Interrupt Handler)
	BEQ getAnswerEnd				; if so, answer of peripheral MDB is finished
	ADD R4, R4, R0					; actualize chksum	
	B	getAnswerLoop				; unconditional branch to 'inDataLoop'
getAnswerEnd
	MOV R1, R0						; R1 = R0 (chk byte)
	MOV R0, R2						; R0 = R2 number of bytes received
	CMP R0, #1						; R0 = 1 ? (if no needed check sum)
	BEQ getAnswerDone				; if so, answer done
	CMP R4, R1						; R4 = R0 (chksum = chk)?
	MOVNE R0, #0					; R0 = 0 (chksum failed)
getAnswerDone
									; restore previous value of R0 into R0, R1 into R1, R2 into R2
	POP {R1, R2, R3, R4, R5, PC}	; R3 into R3, R4 into R4, R5, into R5 and LR into PC (return)
	
	ALIGN                           ; make sure the end of this section is aligned
    END                             ; end of file