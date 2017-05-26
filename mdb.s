

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
			
        AREA    DATA, ALIGN=2
CMDLEN  EQU     36      ; max size of command
Command	SPACE   (CMDLEN)
ChkSum	SPACE	1
        EXPORT Command   ; global only for observation using debugger

        AREA    |.text|, CODE, READONLY, ALIGN=2
        THUMB
;-----------MDB_SendAddress-----------
; Envia la direccion de un periferico
; activa High Stick Parity bit
; Input : R0 8-bit address
; Output: none
MDB_SendAddress
	PUSH {R0, R1, LR}          	; save current value of R0, R1 and LR
	BL	UART_HighStickParity	; set high stick parity
	BL	UART_OutChar				; note: modifies R0 and R1
	POP {R0, R1, PC}           	; restore previous value of R0 into R0, R1 into R1, and LR into PC (return)
	
;-----------MDB_SendCommand-----------
; Envia un comando a un periferico
; activa Low Stick Parity
; Input : R0 address (for chkSum), R1 pointer to commands, R2 number of command/data bytes to be send
; Output: none
; Modifies: none, all used Register are pushed and poped
MDB_SendCommand
	PUSH {R0, R1, R2, R3, R4, R5, LR}	; save current value of R0, R1, R2, R3, R4, R5 and LR
	BL	UART_LowStickParity			; set to low stick parity
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
	BL	UART_HighStickParity		; again set High stick parity
	POP {R0, R1, R2, R3, R4, R5, PC}	; R3 into R3, R4 into R4, R5, into R5 and LR into PC (return)


;-----------MDB_SendChk-----------
; Envia el chk sum byte
; activa al final el High Stick Parity
; Input : R0 pointer to commands, R1 number of command/data bytes to be send
; Output: none
; Modifies: none, all used Register are pushed and poped
	PUSH {LR}
	
	BL	UART_OutChar				; envia el CHK SUM byte
	
	BL	UART_LowStickParity
	POP	{PC}
MDB_SendChk
	
	
	ALIGN                           ; make sure the end of this section is aligned
    END                             ; end of file