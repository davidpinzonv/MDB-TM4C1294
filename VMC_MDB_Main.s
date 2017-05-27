; UARTIntsTestMain.s
; Runs on TM4C1294
; Tests the UART0 to implement bidirectional data transfer to and from a
; computer running HyperTerminal.  This time, interrupts and FIFOs
; are used.
; This file is named "UARTInts" because it is the UART with interrupts.
; Daniel Valvano
; May 29, 2014

;  This example accompanies the book
;  "Embedded Systems: Real Time Interfacing to Arm Cortex M Microcontrollers",
;  ISBN: 978-1463590154, Jonathan Valvano, copyright (c) 2014
;  Program 5.11 Section 5.6, Program 3.10
;
;Copyright 2014 by Jonathan W. Valvano, valvano@mail.utexas.edu
;   You may use, edit, run or distribute this file
;   as long as the above copyright notice remains
;THIS SOFTWARE IS PROVIDED "AS IS".  NO WARRANTIES, WHETHER EXPRESS, IMPLIED
;OR STATUTORY, INCLUDING, BUT NOT LIMITED TO, IMPLIED WARRANTIES OF
;MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE APPLY TO THIS SOFTWARE.
;VALVANO SHALL NOT, IN ANY CIRCUMSTANCES, BE LIABLE FOR SPECIAL, INCIDENTAL,
;OR CONSEQUENTIAL DAMAGES, FOR ANY REASON WHATSOEVER.
;For more information about my classes, my research, and my books, see
;http://users.ece.utexas.edu/~valvano/

; U0Rx (VCP receive) connected to PA0
; U0Tx (VCP transmit) connected to PA1
; Note: Connected LaunchPad JP4 and JP5 inserted parallel with long side of board.

; standard ASCII symbols
CR                 EQU 0x0D
LF                 EQU 0x0A
BS                 EQU 0x08
ESC                EQU 0x1B
SPA                EQU 0x20
DEL                EQU 0x7F

; functions in PLL.s
        IMPORT PLL_Init

; functions UART2.s
        IMPORT UART_Init
        IMPORT UART_InChar
        IMPORT UART_OutChar
        IMPORT UART_OutString
        IMPORT UART_InUDec
        IMPORT UART_OutUDec
        IMPORT UART_InUHex
        IMPORT UART_OutUHex
        IMPORT UART_InString

        AREA    DATA, ALIGN=2
STRLEN  EQU     36      ; string holds 19 non-NULL characters
String  SPACE   (STRLEN+1)
Number  SPACE   4
        EXPORT String   ; global only for observation using debugger
        EXPORT Number   ; global only for observation using debugger

        AREA    |.text|, CODE, READONLY, ALIGN=2
        THUMB
        EXPORT Start
;constant string values
InStrPrompt   DCB "InString: ", 0
OutStrPrompt  DCB " OutString=", 0
InUDecPrompt  DCB "InUDec: ", 0
OutUDecPrompt DCB " OutUDec=", 0
InUHexPrompt  DCB "InUHex: ", 0
OutUHexPrompt DCB " OutUHex=", 0
    ALIGN                           ; make sure the end of this section is aligned

;---------------------OutCRLF---------------------
; Output a CR,LF to UART to go to a new line
; Input: none
; Output: none
OutCRLF
    PUSH {LR}                       ; save current value of LR
    MOV R0, #CR                     ; R0 = CR (<carriage return>)
    BL  UART_OutChar                ; send <carriage return> to the UART
    MOV R0, #LF                     ; R0 = LF (<line feed>)
    BL  UART_OutChar                ; send <line feed> to the UART
    POP {PC}                        ; restore previous value of LR into PC (return)

Start
    BL  PLL_Init                    ; set system clock to 120 MHz
    BL  UART_Init                   ; initialize UART
    BL  OutCRLF                     ; go to a new line
    ; print the uppercase alphabet
    MOV R4, #'A'                    ; R4 = 'A'
uppercaseLoop
    MOV R0, R4                      ; R0 = R4
    BL  UART_OutChar                ; send the character (R4) to the UART
    ADD R4, R4, #1                  ; R4 = R4 + 1 (go to the next character in the alphabet)
    CMP R4, #'Z'                    ; is R4 (character) <= 'Z'?
    BLS uppercaseLoop               ; if so, skip to 'uppercaseLoop'
    BL  OutCRLF                     ; go to a new line
    MOV R0, #' '                    ; R0 = ' '
    BL  UART_OutChar                ; send the character (' ') to the UART
    ; print the lowercase alphabet
    MOV R4, #'a'                    ; R4 = 'a'
lowercaseLoop
    MOV R0, R4                      ; R0 = R4
    BL  UART_OutChar                ; send the character (R4) to the UART
    ADD R4, R4, #1                  ; R4 = R4 + 1 (go to the next character in the alphabet)
    CMP R4, #'z'                    ; is R4 (character) <= 'z'?
    BLS lowercaseLoop               ; if so, skip to 'lowercaseLoop'
    BL  OutCRLF                     ; go to a new line
    MOV R0, #'-'                    ; R0 = '-'
    BL  UART_OutChar                ; send the character ('-') to the UART
    MOV R0, #'-'                    ; R0 = '-'
    BL  UART_OutChar                ; send the character ('-') to the UART
    MOV R0, #'>'                    ; R0 = '>'
    BL  UART_OutChar                ; send the character ('>') to the UART
loop
    ; echo a string
    LDR R0, =InStrPrompt            ; R0 = &InStrPrompt
    BL  UART_OutString              ; print the prompt
    LDR R0, =String                 ; R0 = &String
    MOV R1, #STRLEN                 ; R1 = STRLEN (R1 = number of non-NULL characters)
    BL  UART_InString               ; get a string from the terminal
    LDR R0, =OutStrPrompt           ; R0 = &OutStrPrompt
    BL  UART_OutString              ; print the prompt
    LDR R0, =String                 ; R0 = &String
    BL  UART_OutString              ; print the string received from the terminal
    BL  OutCRLF                     ; go to a new line
    ; echo an unsigned decimal number
    LDR R0, =InUDecPrompt           ; R0 = &InUDecPrompt
    BL  UART_OutString              ; print the prompt
    BL  UART_InUDec                 ; get a number from the terminal
    LDR R1, =Number                 ; R1 = &Number
    STR R0, [R1]                    ; [R1] = R0 (save the number)
    LDR R0, =OutUDecPrompt          ; R0 = &OutUDecPrompt
    BL  UART_OutString              ; print the prompt
    LDR R1, =Number                 ; R1 = &Number
    LDR R0, [R1]                    ; R0 = [R1] (recall the number)
    BL  UART_OutUDec                ; print the number received from the terminal
    BL  OutCRLF                     ; go to a new line
    ; echo an unsigned hexidecimal number
    LDR R0, =InUHexPrompt           ; R0 = &InUHexPrompt
    BL  UART_OutString              ; print the prompt
    BL  UART_InUHex                 ; get a number from the terminal
    LDR R1, =Number                 ; R1 = &Number
    STR R0, [R1]                    ; [R1] = R0 (save the number)
    LDR R0, =OutUHexPrompt          ; R0 = &OutUHexPrompt
    BL  UART_OutString              ; print the prompt
    LDR R1, =Number                 ; R1 = &Number
    LDR R0, [R1]                    ; R0 = [R1] (recall the number)
    BL  UART_OutUHex                ; print the number received from the terminal
    BL  OutCRLF                     ; go to a new line
    B   loop                        ; unconditional branch to 'loop'

    ALIGN                           ; make sure the end of this section is aligned
    END                             ; end of file