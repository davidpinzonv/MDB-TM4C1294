; mdb.s
; Runs on TM4C1294
; Modulo de funciones del protocolo MDB
; usando funciones del modulo de UARTInts.s
; David Pinzon & Alberto Lopez
; May 27, 2017

COIN_CHANGER_ADDR					EQU 0x0008
COMMAND_RESET						EQU 0x0008
COMMAND_SETUP						EQU 0x0009
COMMAND_TUBE_STATUS					EQU 0x000A
COMMAND_POLL						EQU 0x000B
COMMAND_COIN_TYPE					EQU 0x000C
COMMAND_DISPENSE					EQU 0x000D
COMMAND_EXPANSION					EQU 0x000F
COMMAND_EXP_IDENTIFICATION			EQU 0x0F00
COMMAND_EXP_FEATURE_ENEABLE			EQU 0x0F01
COMMAND_EXP_PAYOUT					EQU 0x0F02
COMMAND_EXP_PAYOUT_STATUS			EQU 0x0F03
COMMAND_EXP_PAYOUT_VALUE_POLL		EQU 0x0F04
COMMAND_EXP_SEND_DIAGNOSTIC_STATUS	EQU 0x0F05

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
		IMPORT UART_SendBreak
		IMPORT UART_SendBreak_Disable

;functions from GPTimer.s
		IMPORT Timer_ResponseTime
		IMPORT Timer_ResponseTime_stop
		IMPORT Timer_BreakTime
		IMPORT Timer_SetupTime
		IMPORT Timer_PollingTime
		IMPORT Timer_NoResponseTime
		IMPORT Timer_NoResponseTime_stop

;functions from Systick.s
		IMPORT delay
			
        AREA    DATA, ALIGN=2
CMDLEN			 	EQU     36      ; max size of command
Command				SPACE   (CMDLEN)
DataIn				SPACE	(CMDLEN)
Setup_buf			SPACE	24
Tube_status_buf		SPACE	19
Pool_buf			SPACE	17
Identification_buf	SPACE	34
Payout_status_buf	SPACE	17
Send_diag_status_buf SPACE	17
        EXPORT Command
		EXPORT DataIn
		EXPORT Setup_buf
		EXPORT Tube_status_buf
		EXPORT Pool_buf
		EXPORT Identification_buf
		EXPORT Payout_status_buf
		EXPORT Send_diag_status_buf
	;functions to export
		EXPORT MDB_SendAddress
		EXPORT MDB_SendCommand
		EXPORT MDB_SendACK
		EXPORT MDB_SendRET
		EXPORT MDB_SendNAK
		EXPORT MDB_GetAnswer
		EXPORT MDB_SendBusReset
		EXPORT MDB_InitCoinChanger
		EXPORT MDB_SendPool
		EXPORT MDB_SendSetup
		EXPORT MDB_SendExpIdentification
		
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
	PUSH {R0, R1, LR}				; save current value of R0, R1 and LR
	MOV R0, #0						; R0 = 0x00H (ACK)
	BL	UART_OutChar				; envia ACK, note: modifies R0 and R1
	POP	{R0, R1, PC}				; restore previous value of R0 into R0, R1 into R1, and LR into PC (return)

;-----------MDB_SendRET-----------
; Envia el RET byte
; Input : none
; Output: none
; Modifies: none, all used Register are pushed and poped
MDB_SendRET
	PUSH {R0, R1, LR}				; save current value of R0, R1 and LR
	MOV R0, #170					; R0 = 0xAAH (RET)
	BL	UART_OutChar				; envia RET, note: modifies R0 and R1
	POP	{R0, R1, PC}				; restore previous value of R0 into R0, R1 into R1, and LR into PC (return)
	
;-----------MDB_SendNAK-----------
; Envia el NAK byte
; Input : none
; Output: none
; Modifies: none, all used Register are pushed and poped
MDB_SendNAK
	PUSH {R0, R1, LR}				; save current value of R0, R1 and LR
	MOV R0, #255					; R0 = 0xFFH (NAK)
	BL	UART_OutChar				; envia NAK, note: modifies R0 and R1
	POP	{R0, R1, PC}				; restore previous value of R0 into R0, R1 into R1, and LR into PC (return)
	
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
	
;---------MDB_SendBusReset---------
; Manda un bus reset a los perifericos
; Input : none
; Output: none
; Modifies: none, all used Register are pushed and poped
MDB_SendBusReset
	PUSH {R0, R1, LR}				; save current values of R0, R1, LR
	BL	UART_SendBreak				; send break
	BL	Timer_BreakTime				; start Timer_BreakTime (100ms)
sendBusResetLoop
	B	sendBusResetLoop
sendBusResetDone
	BL	UART_SendBreak_Disable		; stop break
	POP	{R0, R1, PC}				; restore previous value of R0 into R0, R1 into R1, and LR into PC (return)

;---------MDB_SendPool---------
; Manda un el comando POOL
; Input : R0, peripheral addres to send the pool command
; Output: none
; Modifies: none, all used Register are pushed and poped
MDB_SendPool
	PUSH {R0, R1, R2, LR}			; save current values of R0, R1, R2, LR
	LDR	R1,=Command					; R1 = &Command (pointer)
	MOV	R2,#COMMAND_POLL			; R2 = COMMAND_POLL
	STRB R2,[R1]					; [R1] = R2 (COMMAND_POLL)
	MOV R2,#1						; R2 = 1 (number of command bytes to send)
	BL	MDB_SendAddress				; send the peripheral address
	BL	MDB_SendCommand				; send pool command with chk byte
	POP	{R0, R1, R2, PC}			; restore previous value of R0 into R0, R1 into R1, and LR into PC (return)
	
;---------MDB_SendSetup---------
; Manda un el comando SETUP
; Input : R0, peripheral addres to send the Setup command
; Output: none
; Modifies: none, all used Register are pushed and poped
MDB_SendSetup
	PUSH {R0, R1, R2, LR}			; save current values of R0, R1, R2, LR
	LDR	R1,=Command					; R1 = &Command (pointer)
	MOV	R2,#COMMAND_SETUP			; R2 = COMMAND_SETUP
	STRB R2,[R1]					; [R1] = R2 (COMMAND_SETUP)
	MOV R2,#1						; R2 = 1 (number of command bytes to send)
	BL	MDB_SendAddress				; send the peripheral address
	BL	MDB_SendCommand				; send pool command with chk byte
	POP	{R0, R1, R2, PC}			; restore previous value of R0 into R0, R1 into R1, and LR into PC (return)
	
;---------MDB_SendExpIdentification---------
; Manda un el comando-exp  Identification
; Input : R0, peripheral addres to send the Identification command
; Output: none
; Modifies: none, all used Register are pushed and poped
MDB_SendExpIdentification
	PUSH {R0, R1, R2, LR}			; save current values of R0, R1, R2, LR
	LDR	R1,=Command					; R1 = &Command (pointer)
	MOV	R2,#COMMAND_EXP_IDENTIFICATION; R2 = COMMAND_EXP_IDENTIFICATION
	STRB R2,[R1]					; [R1] = R2 (COMMAND_EXP_IDENTIFICATION)
	MOV R2,#1						; R2 = 1 (number of command bytes to send)
	BL	MDB_SendAddress				; send the peripheral address
	BL	MDB_SendCommand				; send pool command with chk byte
	POP	{R0, R1, R2, PC}			; restore previous value of R0 into R0, R1 into R1, and LR into PC (return)
	
;---------MDB_SendExpSendDiagStatus---------
; Manda el comando-exp Send Diagnostic status
; Input : R0, peripheral addres to send the SendDiagStatus comand
; Output: none
; Modifies: none, all used Register are pushed and poped
MDB_SendExpSendDiagStatus
	PUSH {R0, R1, R2, LR}			; save current values of R0, R1, R2, LR
	LDR	R1,=Command					; R1 = &Command (pointer)
	MOV	R2,#COMMAND_EXP_SEND_DIAGNOSTIC_STATUS; R2 = COMMAND_EXP_SEND_DIAGNOSTIC_STATUS
	STRB R2,[R1]					; [R1] = R2 (COMMAND_EXP_SEND_DIAGNOSTIC_STATUS)
	MOV R2,#1						; R2 = 1 (number of command bytes to send)
	BL	MDB_SendAddress				; send the peripheral address
	BL	MDB_SendCommand				; send pool command with chk byte
	POP	{R0, R1, R2, PC}			; restore previous value of R0 into R0, R1 into R1, and LR into PC (return)
	
;---------MDB_SendTubeStatus---------
; Manda el comando Tube Status
; Input : R0, peripheral addres to send the Tube Status comand
; Output: none
; Modifies: none, all used Register are pushed and poped
MDB_SendTubeStatus
	PUSH {R0, R1, R2, LR}			; save current values of R0, R1, R2, LR
	LDR	R1,=Command					; R1 = &Command (pointer)
	MOV	R2,#COMMAND_TUBE_STATUS		; R2 = COMMAND_TUBE_STATUS
	STRB R2,[R1]					; [R1] = R2 (COMMAND_TUBE_STATUS)
	MOV R2,#1						; R2 = 1 (number of command bytes to send)
	BL	MDB_SendAddress				; send the peripheral address
	BL	MDB_SendCommand				; send pool command with chk byte
	POP	{R0, R1, R2, PC}			; restore previous value of R0 into R0, R1 into R1, and LR into PC (return)

;---------MDB_InitCoinChanger---------
; Secuencia de inicializacion requerida para el Coin Changer
; Input : none
; Output: none
; Modifies: none, all used Register are pushed and poped
MDB_InitCoinChanger
	PUSH {R0, R1, R2, LR}			; save current values of R0, R1, R2, LR
	;reset all
InitSendBusReset
	BL	MDB_SendBusReset
	;wait after first pool
	LDR R0,=InitTimerSetupDone		; Addres to jump after Timer_SetupTime
	BL	Timer_SetupTime 			; Timer 200ms, in: R0
InitResetLoop
	B	InitResetLoop				; loop for wait Timer_SetupTime interrupt
InitTimerSetupDone
	;send first pool to obtain "just reset" response
InitSendPool
	MOV R0, #COIN_CHANGER_ADDR		; R0 = COIN_CHANGER_ADDR
	BL	MDB_SendPool				; Send command pool to R0 (coin changer)
InitGetPool
	LDR R0, =Pool_buf				; R0 = &Pool_buf (pointer)
	BL	MDB_GetAnswer				; Get answer from peripheral
	CMP	R0,#2						; R0 == 2? (received 2 bytes - JustReset & Chk)
	BNE	InitSendBusReset			; if not, go to InitNoResponsePoolLoop
	LDR R0, =DataIn					; R0 = &DataIn (pointer)
	LDR R1, [R0]					; R1 = [R0]
	CMP R1,#2_00001011				; R1 == 00001011B (Changer was Reset)
	BNE InitSendBusReset			; if not, go to InitSendBusReset
	BL	MDB_SendACK					; Sending ACK
	;send first setup, to obtain changer level and configuration information
InitSendSetup	
	MOV R0, #COIN_CHANGER_ADDR		; R0 = COIN_CHANGER_ADDR
	BL	MDB_SendSetup				; Send command setup to R0
InitGetSetup
	LDR R0, =Setup_buf				; R0 = &Setup_buf (pointer)
	BL	MDB_GetAnswer				; Get answer from peripheral
	CMP R0, #0						; R0 == 0? (Chksum Failed)
	BNE	InitSetupDone				; if not, go to InitSetupDone
	BL	MDB_SendRET					; Sending RET
	B	InitGetSetup				; go to InitGetSetup, for getting answer again
InitSetupDone
	BL	MDB_SendACK					; Sending ACK
	;send expansion indentification, to obtain additional changer information and options
InitSendExpIdentification
	MOV R0, #COIN_CHANGER_ADDR		; R0 = COIN_CHANGER_ADDR
	BL	MDB_SendExpIdentification	; Send expansion command Identification to R0
InitGetExpIdentification
	LDR R0, =Identification_buf		; R0 = &Identification_buf (pointer)
	BL	MDB_GetAnswer				; Get answer from peripheral
	CMP R0, #0						; R0 == 0? (Chksum Failed)
	BNE	InitExpIdentificationDone	; if not, go to InitExpIdentificationDone
	BL	MDB_SendRET					; Sending RET
	B	InitGetExpIdentification	; go to InitGetIdentification, for getting answer again
InitExpIdentificationDone
	BL	MDB_SendACK					; Sending ACK
	;send Feature Enable, To enable desired options
InitSendExpFeatureEnable
	LDR R1, =Command				; R1 = &Command (pointer)
	MOV R0, #COMMAND_EXP_FEATURE_ENEABLE; R0 = COMMAND_EXP_FEATURE_ENEABLE
	STRB R0, [R1]					; [R1] = R0 (upgrade command buffer)
	LDR R2, =Identification_buf		; R2 = &Identification_buf (pointer)
	LDR R0, [R2,#29]				; R0 = [R2+29] (features availables)
	STR R0, [R1,#1]				; [R1+1] = R0 (activate all features)
	MOV R0, #COIN_CHANGER_ADDR		; R0 = COIN_CHANGER_ADDR
	MOV R2, #5						; R2 = 5 (number of command/data bytes to send)
	BL MDB_SendCommand				; envia a R0, R2 comandos en &R1
InitGetExpFeatureEnable
	LDR R0, =DataIn					; R0 = &DataIn (pointer)
	BL	MDB_GetAnswer				; Get answer from peripheral
	LDR R0, =DataIn					; R0 = &DataIn (pointer)
	LDR R1, [R0]					; R1 = [R0] (answer)
	CMP R1, #0						; R1 == 00H ? (R1 == ACK?)
	BNE	InitSendExpFeatureEnable	; if not, go to InitSendExpFeatureEnable
	;send expansion SEND DIAGNOSTIC STATUS, to request the changer to report its current state of operation
InitSendExpSendDiagStatus
	MOV R0, #COIN_CHANGER_ADDR		; R0 = COIN_CHANGER_ADDR
	BL	MDB_SendExpSendDiagStatus	; Send expansion command send diagnostic status to R0
InitGetExpSendDiagStatus
	LDR R0, =Send_diag_status_buf	; R0 = &Send_diag_status_buf (pointer)
	BL	MDB_GetAnswer				; Get answer from peripheral
	CMP R0, #0						; R0 == 0? (Chksum Failed)
	BNE	InitExpSendDiagStatusDone	; if not, go to InitExpSendDiagStatusDone
	BL	MDB_SendRET					; Sending RET
	B	InitGetExpSendDiagStatus	; go to InitGetExpSendDiagStatus, for getting answer again
InitExpSendDiagStatusDone
	BL	MDB_SendACK					; Sending ACK
	;wait before first TUBE STATUS
	MOV R0, #250
	BL delay
	;send TUBE STATUS, to obtain tube status / change information
InitSendTubeStatus
	MOV R0, #COIN_CHANGER_ADDR		; R0 = COIN_CHANGER_ADDR
	BL	MDB_SendTubeStatus			; Send command Send Tube Status to R0
InitGetTubeStatus
	LDR R0, =Tube_status_buf		; R0 = &Tube_status_buf (pointer)
	BL	MDB_GetAnswer				; Get answer from peripheral
	CMP R0, #0						; R0 == 0? (Chksum Failed)
	BNE	InitTubeStatusDone			; if not, go to InitTubeStatusDone
	BL	MDB_SendRET					; Sending RET
	B	InitGetTubeStatus			; go to InitGetTubeStatus, for getting answer again
InitTubeStatusDone
	BL	MDB_SendACK					; Sending ACK
	;send Coin type, to enable desired coin acceptance and disable manual coin payout if desired
InitSendCoinType
	LDR R1, =Command				; R1 = &Command (pointer)
	MOV R0, #COMMAND_COIN_TYPE		; R0 = COMMAND_COIN_TYPE
	STRB R0, [R1]					; [R1] = R0 (upgrade command buffer)
	LDR R0,=0x000FFFFF				; enable b0-b4 acepted coins, and all coins to manual dispense
	STR R0, [R1,#1]					; [R1+1] = R0 (upgrade command buffer)
	MOV R0, #COIN_CHANGER_ADDR		; R0 = COIN_CHANGER_ADDR
	MOV R2, #5						; R2 = 5 (number of command/data bytes to send)
	BL MDB_SendCommand				; envia a R0, R2 comandos en &R1
InitGetCoinType
	LDR R0, =DataIn					; R0 = &DataIn (pointer)
	BL	MDB_GetAnswer				; Get answer from peripheral
	LDR R0, =DataIn					; R0 = &DataIn (pointer)
	LDR R1, [R0]					; R1 = [R0] (answer)
	CMP R1, #0x00					; R1 == 00H ? (R1 == ACK?)
	BNE	InitSendCoinType			; if not, go to InitSendExpFeatureEnable
	
	POP	{R0, R1, R2, PC}			; restore previous value of R0 into R0, R1 into R1, R2 into R2 and LR into PC (return)
	
	ALIGN                           ; make sure the end of this section is aligned
    END                             ; end of file