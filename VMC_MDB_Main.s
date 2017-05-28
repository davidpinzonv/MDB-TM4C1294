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

; standard ASCII symbols
CR                 EQU 0x0D
LF                 EQU 0x0A
BS                 EQU 0x08
ESC                EQU 0x1B
SPA                EQU 0x20
DEL                EQU 0x7F

; functions from PLL.s
        IMPORT PLL_Init

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

        AREA    DATA, ALIGN=2
STRLEN  EQU     36      ; string holds 19 non-NULL characters
String  SPACE   (STRLEN+1)
Number  SPACE   4
        EXPORT String   ; global only for observation using debugger
        EXPORT Number   ; global only for observation using debugger

        AREA    |.text|, CODE, READONLY, ALIGN=2
        THUMB
        EXPORT Start

    ALIGN                           ; make sure the end of this section is aligned

Start
    BL  PLL_Init                    ; set system clock to 120 MHz
    BL  UART_Init                   ; initialize UART
	BL	MDB_InitCoinChanger			; Rutina de inicializacion del coin changer


    ALIGN                           ; make sure the end of this section is aligned
    END                             ; end of file