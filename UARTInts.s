; Modified by Josue Pinzon Vivas May 24, 2017
; UARTInts.s
; Runs on TM4C1294
; Use UART0 to implement bidirectional data transfer to and from a
; computer running HyperTerminal.  This time, interrupts and FIFOs
; are used.
; This file is named "UARTInts" because it is the UART with interrupts.
; Daniel Valvano
; May 29, 2014
; Modified by EE345L students Charlie Gough && Matt Hawk
; Modified by EE345M students Agustinus Darmawan && Mingjie Qiu

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

NVIC_EN0_INT5      EQU 0x00000020   ; Interrupt 5 enable
NVIC_EN0_R         EQU 0xE000E100   ; IRQ 0 to 31 Set Enable Register
NVIC_PRI1_R        EQU 0xE000E404   ; IRQ 4 to 7 Priority Register
GPIO_PORTA_AFSEL_R EQU 0x40058420
GPIO_PORTA_PUR_R   EQU 0x40058510
GPIO_PORTA_DEN_R   EQU 0x4005851C
GPIO_PORTA_AMSEL_R EQU 0x40058528
GPIO_PORTA_PCTL_R  EQU 0x4005852C	
UART0_DR_R         EQU 0x4000C000
UART0_FR_R         EQU 0x4000C018
UART_FR_RXFF       EQU 0x00000040   ; UART Receive FIFO Full
UART_FR_TXFF       EQU 0x00000020   ; UART Transmit FIFO Full
UART_FR_RXFE       EQU 0x00000010   ; UART Receive FIFO Empty
UART0_IBRD_R       EQU 0x4000C024
UART0_FBRD_R       EQU 0x4000C028
	
UART0_LCRH_R       EQU 0x4000C02C
UART_LCRH_SPS	   EQU 0x00000080	; UART Stick Parity
UART_LCRH_WLEN_8   EQU 0x00000060   ; 8 bit word length
UART_LCRH_FEN      EQU 0x00000010   ; UART Enable FIFOs
UART_LCRH_EPS	   EQU 0x00000004	; UART Even parity Select
UART_LCRH_PEN	   EQU 0x00000002	; UART Parity Enable
	
UART0_CTL_R        EQU 0x4000C030
UART_CTL_HSE       EQU 0x00000020   ; High-Speed Enable
UART_CTL_UARTEN    EQU 0x00000001   ; UART Enable
	
UART0_IFLS_R       EQU 0x4000C034
UART_IFLS_RX1_8    EQU 0x00000000   ; RX FIFO >= 1/8 full
UART_IFLS_TX1_8    EQU 0x00000000   ; TX FIFO <= 1/8 full
	
UART0_IM_R         EQU 0x4000C038
UART_IM_PEIM	   EQU 0x00000100	; UART Parity Error Interrupt Mask
UART_IM_RTIM       EQU 0x00000040   ; UART Receive Time-Out Interrupt Mask
UART_IM_TXIM       EQU 0x00000020   ; UART Transmit Interrupt Mask
UART_IM_RXIM       EQU 0x00000010   ; UART Receive Interrupt Mask

UART0_RIS_R        EQU 0x4000C03C
UART_RIS_RTRIS     EQU 0x00000040   ; UART Receive Time-Out Raw
                                    ; Interrupt Status
UART_RIS_TXRIS     EQU 0x00000020   ; UART Transmit Raw Interrupt
                                    ; Status
UART_RIS_RXRIS     EQU 0x00000010   ; UART Receive Raw Interrupt
                                    ; Status
UART0_ICR_R        EQU 0x4000C044
UART_ICR_RTIC      EQU 0x00000040   ; Receive Time-Out Interrupt Clear
UART_ICR_TXIC      EQU 0x00000020   ; Transmit Interrupt Clear
UART_ICR_RXIC      EQU 0x00000010   ; Receive Interrupt Clear
UART0_CC_R         EQU 0x4000CFC8
UART_CC_CS_M       EQU 0x0000000F   ; UART Baud Clock Source
UART_CC_CS_SYSCLK  EQU 0x00000000   ; System clock (based on clock
                                    ; source and divisor factor)
UART_CC_CS_PIOSC   EQU 0x00000005   ; PIOSC
SYSCTL_ALTCLKCFG_R EQU 0x400FE138
SYSCTL_ALTCLKCFG_ALTCLK_M     EQU 0x0000000F   ; Alternate Clock Source
SYSCTL_ALTCLKCFG_ALTCLK_PIOSC EQU 0x00000000   ; PIOSC
SYSCTL_RCGCGPIO_R  EQU 0x400FE608
SYSCTL_RCGCGPIO_R0 EQU 0x00000001   ; GPIO Port A Run Mode Clock
                                    ; Gating Control
SYSCTL_RCGCUART_R  EQU 0x400FE618
SYSCTL_RCGCUART_R0 EQU 0x00000001   ; UART Module 0 Run Mode Clock
                                    ; Gating Control
SYSCTL_PRGPIO_R    EQU 0x400FEA08
SYSCTL_PRGPIO_R0   EQU 0x00000001   ; GPIO Port A Peripheral Ready
SYSCTL_PRUART_R    EQU 0x400FEA18
SYSCTL_PRUART_R0   EQU 0x00000001   ; UART Module 0 Peripheral Ready

        IMPORT   DisableInterrupts  ; Disable interrupts
        IMPORT   EnableInterrupts   ; Enable interrupts
        IMPORT   StartCritical      ; previous I bit, disable interrupts
        IMPORT   EndCritical        ; restore I bit to previous value
        IMPORT   WaitForInterrupt   ; low power mode

; properties from FIFO.c
                           ; size of the FIFOs (must be power of 2)
FIFOSIZE    EQU 16         ; (copy this value from both places in FIFO.s)
FIFOSUCCESS EQU  1         ; return value on success
FIFOFAIL    EQU  0         ; return value on failure

; functions from FIFO.s
        IMPORT   TxFifo_Init
        IMPORT   TxFifo_Put
        IMPORT   TxFifo_Get
        IMPORT   TxFifo_Size
        IMPORT   RxFifo_Init
        IMPORT   RxFifo_Put
        IMPORT   RxFifo_Get
        IMPORT   RxFifo_Size

; standard ASCII symbols
CR                 EQU 0x0D
LF                 EQU 0x0A
BS                 EQU 0x08
ESC                EQU 0x1B
SPA                EQU 0x20
DEL                EQU 0x7F

        AREA    |.text|, CODE, READONLY, ALIGN=2
        THUMB
        EXPORT UART_Init
        EXPORT UART_InChar
        EXPORT UART_OutChar
        EXPORT UART0_Handler
        EXPORT UART_OutString
        EXPORT UART_InUDec
        EXPORT UART_OutUDec
        EXPORT UART_InUHex
        EXPORT UART_OutUHex
        EXPORT UART_InString
		EXPORT UART_HighStickParity
		EXPORT UART_LowStickParity
; require C function calls to preserve the 8-byte alignment of 8-byte data objects
        PRESERVE8

;------------UART_Init------------
; Initialize UART0 for 9,600 baud rate (clock from 16 MHz PIOSC),
; 8 bit word length, stick parity, one stop bit, FIFOs enabled, interrupt
; after >= 2 characters received or <= 2 characters to transmit or timeout
; Rx with pull-up
; Input: none
; Output: none
; Modifies: R0, R1
UART_Init
    PUSH {LR}                       ; save current value of LR
    BL  DisableInterrupts           ; disable all interrupts (critical section)
    ; activate clock for UART0
    LDR R1, =SYSCTL_RCGCUART_R      ; R1 = &SYSCTL_RCGCUART_R
    LDR R0, [R1]                    ; R0 = [R1]
    ORR R0, R0, #SYSCTL_RCGCUART_R0 ; R0 = R0|SYSCTL_RCGCUART_R0
    STR R0, [R1]                    ; [R1] = R0
    ; activate clock for port A
    LDR R1, =SYSCTL_RCGCGPIO_R      ; R1 = &SYSCTL_RCGCGPIO_R
    LDR R0, [R1]                    ; R0 = [R1]
    ORR R0, R0, #SYSCTL_RCGCGPIO_R0 ; R0 = R0|SYSCTL_RCGCGPIO_R0
    STR R0, [R1]                    ; [R1] = R0
    ; initialize empty FIFOs
    BL  RxFifo_Init
    BL  TxFifo_Init
    ; allow time for clock to stabilize
    LDR R1, =SYSCTL_PRUART_R        ; R1 = &SYSCTL_PRUART_R
UART0initloop
    LDR R0, [R1]                    ; R0 = [R1] (value)
    ANDS R0, R0, #SYSCTL_PRUART_R0  ; R0 = R0&SYSCTL_PRUART_R0
    BEQ UART0initloop               ; if(R0 == 0), keep polling
    ; disable UART
    LDR R1, =UART0_CTL_R            ; R1 = &UART0_CTL_R
    LDR R0, [R1]                    ; R0 = [R1]
    BIC R0, R0, #UART_CTL_UARTEN    ; R0 = R0&~UART_CTL_UARTEN (disable UART)
    STR R0, [R1]                    ; [R1] = R0
    ; set the baud rate (equations on p845 of datasheet)
    LDR R1, =UART0_IBRD_R           ; R1 = &UART0_IBRD_R
    MOV R0, #104					; R0 = IBRD = int(16,000,000 / (16 * 9,600)) = int(104.166)
    STR R0, [R1]                    ; [R1] = R0
    LDR R1, =UART0_FBRD_R           ; R1 = &UART0_FBRD_R
    MOV R0, #11                     ; R0 = FBRD = round(0.166 * 64 + 0.5) = 11
    STR R0, [R1]                    ; [R1] = R0
    ; configure Line Control Register settings
    LDR R1, =UART0_LCRH_R           ; R1 = &UART0_LCRH_R
    LDR R0, [R1]                    ; R0 = [R1]
    BIC R0, R0, #0xFF               ; R0 = R0&~0xFF (clear all fields)
                                    ; 8 bit word length, LOW stick parity, one stop bit, FIFOs
    ADD R0, R0, #(UART_LCRH_WLEN_8+UART_LCRH_FEN+UART_LCRH_PEN+UART_LCRH_EPS+UART_LCRH_SPS)
	; importante:
	; Puede ser que haya que desactivar FIFO
	;
	
    STR R0, [R1]                    ; [R1] = R0
    ; configure Interrupt FIFO Level Select Register settings
    LDR R1, =UART0_IFLS_R           ; R1 = &UART0_IFLS_R
    LDR R0, [R1]                    ; R0 = [R1]
    BIC R0, R0, #0x3F               ; R0 = R0&~0x3F (clear TX and RX interrupt FIFO level fields)
                                    ; configure interrupt for TX FIFO <= 1/8 full
                                    ; configure interrupt for RX FIFO >= 1/8 full
    ADD R0, R0, #(UART_IFLS_TX1_8+UART_IFLS_RX1_8)
    STR R0, [R1]                    ; [R1] = R0
    ; enable interrupts to be requested upon certain conditions
    ; TX FIFO interrupt: when TX FIFO <= 2 elements (<= 1/8 full, configured above)
    ; RX FIFO interrupt; when RX FIFO >= 2 elements (>= 1/8 full, configured above)
    ; RX time-out interrupt: receive FIFO not empty and no more data received in next 32-bit timeframe
    ;               (this causes an interrupt after each keystroke, rather than every other keystroke)
    LDR R1, =UART0_IM_R             ; R1 = &UART0_IM_R
    LDR R0, [R1]                    ; R0 = [R1]
                                    ; enable TX and RX FIFO interrupts, RX time-out interrupt and Parity interrupt
    ORR R0, R0, #(UART_IM_RXIM+UART_IM_TXIM+UART_IM_RTIM+UART_IM_PEIM)
    STR R0, [R1]                    ; [R1] = R0
    ; UART gets its clock from the alternate clock source as defined by SYSCTL_ALTCLKCFG_R
    LDR R1, =UART0_CC_R             ; R1 = &UART0_CC_R
    LDR R0, [R1]                    ; R0 = [R1]
    BIC R0, R0, #UART_CC_CS_M       ; R0 = R0&~UART_CC_CS_M (clear clock source field)
    ADD R0, R0, #UART_CC_CS_PIOSC   ; R0 = R0+UART_CC_CS_PIOSC (configure for alternate clock source for UART0)
    STR R0, [R1]                    ; [R1] = R0
    ; the alternate clock source is the PIOSC (default)
    LDR R1, =SYSCTL_ALTCLKCFG_R     ; R1 = &SYSCTL_ALTCLKCFG_R
    LDR R0, [R1]                    ; R0 = [R1]
                                    ; R0 = R0&~SYSCTL_ALTCLKCFG_ALTCLK_M (clear alternate clock source field)
    BIC R0, R0, #SYSCTL_ALTCLKCFG_ALTCLK_M
                                    ; R0 = R0+SYSCTL_ALTCLKCFG_ALTCLK_PIOSC (configure for PIOSC as alternate clock source)
    ADD R0, R0, #SYSCTL_ALTCLKCFG_ALTCLK_PIOSC
    STR R0, [R1]                    ; [R1] = R0
    ; enable UART
    LDR R1, =UART0_CTL_R            ; R1 = &UART0_CTL_R
    LDR R0, [R1]                    ; R0 = [R1]
    BIC R0, R0, #UART_CTL_HSE       ; R0 = R0&~UART_CTL_HSE (high-speed disable; divide clock by 16 rather than 8 (default))
    ORR R0, R0, #UART_CTL_UARTEN    ; R0 = R0|UART_CTL_UARTEN (enable UART)
    STR R0, [R1]                    ; [R1] = R0
    ; allow time for clock to stabilize
    LDR R1, =SYSCTL_PRGPIO_R        ; R1 = &SYSCTL_PRGPIO_R
GPIOAinitloop
    LDR R0, [R1]                    ; R0 = [R1] (value)
    ANDS R0, R0, #SYSCTL_PRGPIO_R0  ; R0 = R0&SYSCTL_PRGPIO_R0
    BEQ GPIOAinitloop               ; if(R0 == 0), keep polling
    ; enable alternate function
    LDR R1, =GPIO_PORTA_AFSEL_R     ; R1 = &GPIO_PORTA_AFSEL_R
    LDR R0, [R1]                    ; R0 = [R1]
    ORR R0, R0, #0x03               ; R0 = R0|0x03 (enable alt funct on PA1-0)
    STR R0, [R1]                    ; [R1] = R0
	; activa resistencia pull-up in RX (PA0)
	LDR R1, =GPIO_PORTA_PUR_R		; R1 = &GPIO_PORTA_PUR_R
	ORR R0, #0x01					; set bit 0 (enable pull-up res in PA0)
	STR R0, [R1]
    ; enable digital port
    LDR R1, =GPIO_PORTA_DEN_R       ; R1 = &GPIO_PORTA_DEN_R
    LDR R0, [R1]                    ; R0 = [R1]
    ORR R0, R0, #0x03               ; R0 = R0|0x03 (enable digital I/O on PA1-0)
    STR R0, [R1]                    ; [R1] = R0
	; configure as UART
    LDR R1, =GPIO_PORTA_PCTL_R      ; R1 = &GPIO_PORTA_PCTL_R
    LDR R0, [R1]                    ; R0 = [R1]
    BIC R0, R0, #0x000000FF         ; R0 = R0&~0x000000FF (clear port control field for PA1-0)
    ADD R0, R0, #0x00000011         ; R0 = R0+0x00000011 (configure PA1-0 as UART)
    STR R0, [R1]                    ; [R1] = R0
    ; disable analog functionality
    LDR R1, =GPIO_PORTA_AMSEL_R     ; R1 = &GPIO_PORTA_AMSEL_R
    MOV R0, #0                      ; R0 = 0 (disable analog functionality on PA)
    STR R0, [R1]                    ; [R1] = R0
    ; set the priority of the UART interrupt
    LDR R1, =NVIC_PRI1_R            ; R1 = &NVIC_PRI1_R
    LDR R0, [R1]                    ; R0 = [R1]
    BIC R0, R0, #0x0000FF00         ; R0 = R0&~0xFFFF00FF (clear NVIC priority field for UART0 interrupt)
    ADD R0, R0, #0x00004000         ; R0 = R0+0x00004000 (UART0 = priority 2; stored in bits 13-15)
    STR R0, [R1]                    ; [R1] = R0
    ; enable interrupt 5 in NVIC
    LDR R1, =NVIC_EN0_R             ; R1 = &NVIC_EN0_R
    LDR R0, =NVIC_EN0_INT5          ; R0 = NVIC_EN0_INT5 (zeros written to enable register have no effect)
    STR R0, [R1]                    ; [R1] = R0
    BL  EnableInterrupts            ; enable all interrupts (end of critical section)
    POP {PC}                        ; restore previous value of LR into PC (return)

; private helper subroutine
; copy from hardware RX FIFO to software RX FIFO
; stop when hardware RX FIFO is empty or software RX FIFO is full
; Modifies: R0, R1
copyHardwareToSoftware
    PUSH {LR}                       ; save current value of LR
h2sloop
    ; repeat the loop while (hardware receive FIFO not empty) and (software receive FIFO not full)
    LDR R1, =UART0_FR_R             ; R1 = &UART0_FR_R
    LDR R0, [R1]                    ; R0 = [R1]
    AND R0, R0, #UART_FR_RXFE       ; R0 = R0&UART_FR_RXFE
    CMP R0, #UART_FR_RXFE           ; is R0 (UART0_FR_R&UART_FR_RXFE) == UART_FR_RXFE? (is hardware receive FIFO empty?)
    BEQ h2sdone                     ; if so, skip to 'h2sdone'
    BL  RxFifo_Size
    CMP R0, #(FIFOSIZE - 1)         ; is R0 (RxFifo_Size()) == (FIFOSIZE - 1)? (is software receive FIFO full?)
    BEQ h2sdone                     ; if so, skip to 'h2sdone'
    ; read a character from the hardware FIFO
    LDR R1, =UART0_DR_R             ; R1 = &UART0_DR_R
    LDR R0, [R1]                    ; R0 = [R1]
    ; store R0 (UART0_DR_R) in software receive FIFO
    BL  RxFifo_Put
    B   h2sloop                     ; unconditional branch to 'h2sloop'
h2sdone
    POP {PC}                        ; restore previous value of LR into PC (return)

; private helper subroutine
; copy from software TX FIFO to hardware TX FIFO
; stop when software TX FIFO is empty or hardware TX FIFO is full
copySoftwareToHardware
    PUSH {LR}                       ; save current value of LR
s2hloop
    ; repeat the loop while (hardware transmit FIFO not full) and (software transmit FIFO not empty)
    LDR R1, =UART0_FR_R             ; R1 = &UART0_FR_R
    LDR R0, [R1]                    ; R0 = [R1]
    AND R0, R0, #UART_FR_TXFF       ; R0 = R0&UART_FR_TXFF
    CMP R0, #UART_FR_TXFF           ; is R0 (UART0_FR_R&UART_FR_TXFF) == UART_FR_TXFF? (is hardware transmit FIFO full?)
    BEQ s2hdone                     ; if so, skip to 's2hdone'
    BL  TxFifo_Size
    CMP R0, #0                      ; is R0 (TxFifo_Size()) == 0? (is software transmit FIFO empty?)
    BEQ s2hdone                     ; if so, skip to 's2hdone'
    ; read a character from the software FIFO
    PUSH {R0}                       ; allocate local variable
    MOV R0, SP                      ; R0 = SP (R0 points to local variable)
    BL  TxFifo_Get                  ; get from software transmit FIFO into pointer R0
    POP {R0}                        ; pop data into R0
    ; store R0 (data from TxFifo_Get()) in hardware transmit FIFO
    LDR R1, =UART0_DR_R             ; R1 = &UART0_DR_R
    STR R0, [R1]                    ; [R1] = R0
    B   s2hloop                     ; unconditional branch to 'h2sloop'
s2hdone
    POP {PC}                        ; restore previous value of LR into PC (return)

;------------UART_InChar------------
; input ASCII character from UART
; spin if RxFifo is empty
; Input: none
; Output: R0  character in from UART
; Very Important: The UART0 interrupt handler automatically
;  empties the hardware receive FIFO into the software FIFO as
;  the hardware gets data.  If the UART0 interrupt is
;  disabled, the software receive FIFO may become empty, and
;  this function will stall forever.
;  Ensure that the UART0 module is initialized and its
;  interrupt is enabled before calling this function.  Do not
;  use UART I/O functions within a critical section of your
;  main program.
UART_InChar
    MOV R0, #0                      ; initialize local variable
    PUSH {R0, LR}                   ; save current value of LR and allocate local variable
inCharLoop
    MOV R0, SP                      ; R0 = SP (R0 points to local variable)
    BL  RxFifo_Get                  ; get from software receive FIFO into pointer R0
    CMP R0, #FIFOFAIL               ; is R0 (RxFifo_Get()) == FIFOFAIL (value returned when FIFO empty)?
    BEQ inCharLoop                  ; if so, skip to 'inCharLoop' (spin until receive a character)
    POP {R0, PC}                    ; pop data into R0 and restore LR into PC (return)

;------------UART_OutChar------------
; output ASCII character to UART
; spin if TxFifo is full
; Input: R0  character out to UART
; Output: none
; Modifies: R0, R1
; Very Important: The UART0 interrupt handler automatically
;  empties the software transmit FIFO into the hardware FIFO as
;  the hardware sends data.  If the UART0 interrupt is
;  disabled, the software transmit FIFO may become full, and
;  this function will stall forever.
;  Ensure that the UART0 module is initialized and its
;  interrupt is enabled before calling this function.  Do not
;  use UART I/O functions within a critical section of your
;  main program.
UART_OutChar
    PUSH {R4, LR}                   ; save current value of R4 and LR
    MOV R4, R0                      ; R4 = R0 (save the output character)
outCharLoop
    MOV R0, R4                      ; R0 = R4 (recall the output character)
    BL  TxFifo_Put                  ; store R0 (output character) in software transmit FIFO
    CMP R0, #FIFOFAIL               ; is R0 (TxFifo_Put()) == FIFOFAIL (value returned when FIFO full)?
    BEQ outCharLoop                 ; if so, skip to 'outCharLoop' (spin until space in software transmit FIFO)
    LDR R4, =UART0_IM_R             ; R4 = &UART0_IM_R
    LDR R0, [R4]                    ; R0 = [R4]
    BIC R0, R0, #UART_IM_TXIM       ; R0 = R0&~UART_IM_TXIM (disable TX FIFO interrupt)
    STR R0, [R4]                    ; [R4] = R0
    BL  copySoftwareToHardware      ; private helper subroutine
    LDR R0, [R4]                    ; R0 = [R4]
    ORR R0, R0, #UART_IM_TXIM       ; R0 = R0|UART_IM_TXIM (enable TX FIFO interrupt)
    STR R0, [R4]                    ; [R4] = R0
    POP {R4, PC}                    ; restore previous value of R4 into R4 and LR into PC (return)

;------------UART0_Handler------------
; at least one of three things has happened:
; hardware TX FIFO goes from 3 to 2 or less items
; hardware RX FIFO goes from 1 to 2 or more items
; UART receiver has timed out
UART0_Handler
    PUSH {LR}                       ; save current value of LR
    ; check the flags to determine which interrupt condition occurred
handlerCheck0
    LDR R1, =UART0_RIS_R            ; R1 = &UART0_RIS_R
    LDR R0, [R1]                    ; R0 = [R1]
    AND R0, R0, #UART_RIS_TXRIS     ; R0 = R0&UART_RIS_TXRIS
    CMP R0, #UART_RIS_TXRIS         ; is R0 (UART0_RIS_R&UART_RIS_TXRIS) == UART_RIS_TXRIS? (does hardware TX FIFO have <= 2 items?)
    BNE handlerCheck1               ; if not, skip to 'handlerCheck1' and check the next flag
    ; acknowledge TX FIFO interrupt
    LDR R1, =UART0_ICR_R            ; R1 = &UART0_ICR_R
    LDR R0, =UART_ICR_TXIC          ; R0 = UART_ICR_TXIC (zeros written to interrupt clear register have no effect)
    STR R0, [R1]                    ; [R1] = R0
    ; copy from software TX FIFO to hardware TX FIFO
    BL  copySoftwareToHardware      ; private helper subroutine
    ; if the software transmit FIFO is now empty, disable TX FIFO interrupt
    ; UART_OutChar() will re-enable the TX FIFO interrupt when it is needed
    BL  TxFifo_Size
    CMP R0, #0                      ; is R0 (TxFifo_Size()) == 0? (is software transmit FIFO empty?)
    BNE handlerCheck1               ; if not, skip to 'handlerCheck1'
    LDR R1, =UART0_IM_R             ; R1 = &UART0_IM_R
    LDR R0, [R1]                    ; R0 = [R1]
    BIC R0, R0, #UART_IM_TXIM       ; R0 = R0&~UART_IM_TXIM (disable TX FIFO interrupt)
    STR R0, [R1]                    ; [R1] = R0
handlerCheck1
    LDR R1, =UART0_RIS_R            ; R1 = &UART0_RIS_R
    LDR R0, [R1]                    ; R0 = [R1]
    AND R0, R0, #UART_RIS_RXRIS     ; R0 = R0&UART_RIS_RXRIS
    CMP R0, #UART_RIS_RXRIS         ; is R0 (UART0_RIS_R&UART_RIS_RXRIS) == UART_RIS_RXRIS? (does hardware RX FIFO have >= 2 items?)
    BNE handlerCheck2               ; if not, skip to 'handlerCheck2' and check the next flag
    ; acknowledge RX FIFO interrupt
    LDR R1, =UART0_ICR_R            ; R1 = &UART0_ICR_R
    LDR R0, =UART_ICR_RXIC          ; R0 = UART_ICR_RXIC (zeros written to interrupt clear register have no effect)
    STR R0, [R1]                    ; [R1] = R0
    ; copy from hardware RX FIFO to software RX FIFO
    BL  copyHardwareToSoftware      ; private helper subroutine
handlerCheck2
    LDR R1, =UART0_RIS_R            ; R1 = &UART0_RIS_R
    LDR R0, [R1]                    ; R0 = [R1]
    AND R0, R0, #UART_RIS_RTRIS     ; R0 = R0&UART_RIS_RTRIS
    CMP R0, #UART_RIS_RTRIS         ; is R0 (UART0_RIS_R&UART_RIS_RTRIS) == UART_RIS_RTRIS? (did the receiver timeout?)
    BNE handlerDone                 ; if not, skip to 'handlerDone'
    ; acknowledge receiver timeout interrupt
    LDR R1, =UART0_ICR_R            ; R1 = &UART0_ICR_R
    LDR R0, =UART_ICR_RTIC          ; R0 = UART_ICR_RTIC (zeros written to interrupt clear register have no effect)
    STR R0, [R1]                    ; [R1] = R0
    ; copy from hardware RX FIFO to software RX FIFO
    BL  copyHardwareToSoftware      ; private helper subroutine
handlerDone
    POP {PC}                        ; restore previous value of LR into PC (return from interrupt)

;------------UART_OutString------------
; Output String (NULL termination)
; Input: R0  pointer to a NULL-terminated string to be transferred
; Output: none
UART_OutString
    PUSH {R4, LR}                   ; save current value of R4 and LR
    MOV R4, R0                      ; R4 = R0 (save the string pointer)
outStringLoop
    LDRB R0, [R4]                   ; R0 = [R4] (R0 gets unsigned character pointed to by R4, promoted to 32 bits)
    CMP R0, #0                      ; is R0 (next character in string) == 0 (NULL)?
    BEQ outStringDone               ; if so, skip to 'outStringDone'
    BL  UART_OutChar                ; send the character to the UART
    ADD R4, R4, #1                  ; R4 = R4 + 1 (increment string pointer)
    B   outStringLoop               ; unconditional branch to 'outStringLoop'
outStringDone
    POP {R4, PC}                    ; restore previous value of R4 into R4 and LR into PC (return)

;------------UART_InUDec------------
; InUDec accepts ASCII input in unsigned decimal format
;     and converts to a 32-bit unsigned number
;     valid range is 0 to 4294967295 (2^32-1)
; Input: none
; Output: R0  32-bit unsigned number
; If you enter a number above 4294967295, it will return an incorrect value
; Backspace will remove last digit typed
UART_InUDec
    PUSH {R4, R5, LR}               ; save current value of R4, R5, and LR
    MOV R4, #0                      ; R4 = 0 (number = 0)
    MOV R5, #0                      ; R5 = 0 (length = 0)
inUDecLoop
    ; accepts characters until <enter> is typed
    BL  UART_InChar                 ; get a character from the UART
    CMP R0, #CR                     ; is R0 (most recent character) == 0x0D (<enter>)?
    BEQ inUDecDone                  ; if so, skip to 'inUDecDone'
    ; check if the input is a digit, 0-9
    ; if the character is not 0-9, it is ignored and not echoed
    CMP R0, #'0'                    ; is R0 (most recent character) < '0'?
    BLO inUDecNAN                   ; if so, skip to 'inUDecNAN'
    CMP R0, #'9'                    ; is R0 (most recent character) > '9'?
    BHI inUDecNAN                   ; if so, skip to 'inUDecNAN'
    MOV R1, #10                     ; R1 = 10
    MUL R4, R4, R1                  ; R4 = R4*R1 (number = number*10)
    ADD R4, R4, R0                  ; R4 = R4 + R0 (number = number*10 + character)
    SUB R4, R4, #'0'                ; R4 = R4 - '0' (number = number*10 + character - '0')
    ADD R5, R5, #1                  ; R5 = R5 + 1 (length = length + 1)
    BL  UART_OutChar                ; echo the character to the UART
    B   inUDecLoop                  ; unconditional branch to 'inUDecLoop'
inUDecNAN
    ; if the input is a backspace, then the return number is
    ; changed and a backspace is outputted to the screen
    CMP R0, #BS                     ; is R0 (most recent character) == 0x08 (<backspace>)?
    BNE inUDecLoop                  ; if not, skip to 'inUDecLoop'
    CMP R5, #0                      ; is R5 (length) == 0?
    BEQ inUDecLoop                  ; if so, skip to 'inUDecLoop'
    MOV R1, #10                     ; R1 = 10
    UDIV R4, R4, R1                 ; R4 = R4/R1 (number = number/10)
    SUB R5, R5, #1                  ; R5 = R5 - 1 (length = length - 1)
    BL  UART_OutChar                ; echo the character to the UART
;    MOV R0, #SPA                    ; R0 = SPA (<space>)
;    BL  UART_OutChar                ; echo additional <space> to the UART
;    MOV R0, #BS                     ; R0 = BS (<backspace>)
;    BL  UART_OutChar                ; echo additional <backspace> to the UART
    B   inUDecLoop                  ; unconditional branch to 'inUDecLoop'
inUDecDone
    MOV R0, R4                      ; R0 = R4 (return 'number' in R0)
    POP {R4, R5, PC}                ; restore previous value of R4 into R4, R5 into R5, and LR into PC (return)

;Modulus macro from Section 5.4
;Mod and Divnd must not be the same register
    MACRO
    UMOD  $Mod,$Divnd,$Divsr ;MOD,DIVIDEND,DIVISOR
    UDIV  $Mod,$Divnd,$Divsr ;Mod = DIVIDEND/DIVISOR
    MUL   $Mod,$Mod,$Divsr   ;Mod = DIVISOR*(DIVIDEND/DIVISOR)
    SUB   $Mod,$Divnd,$Mod   ;Mod = DIVIDEND-DIVISOR*(DIVIDEND/DIVISOR)
    MEND

;-----------------------UART_OutUDec-----------------------
; Output a 32-bit number in unsigned decimal format
; Input: R0  32-bit number to be transferred
; Output: none
; Variable format 1-10 digits with no space before or after
UART_OutUDec
    ; This function uses recursion to convert decimal number
    ;   of unspecified length as an ASCII string
    PUSH {LR}                       ; save current value of LR
    CMP R0, #10                     ; is R0 (number) < 10?
    BLO outUDecDone                 ; if so, skip to 'outUDecDone'
    ; R0 (number) >= 10
    ; recursive call to UART_OutUDec with R0/10 (number/10)
    PUSH {R0}                       ; save current value of R0 (number)
    MOV R1, #10                     ; R1 = 10
    UDIV R0, R0, R1                 ; R0 = R0/R1 (number = number/10)
    BL  UART_OutUDec
    POP {R0}                        ; restore previous value of R0 into R0
    ; extract the ones digit of R0 (number) with R0 = R0%10
    MOV R1, #10                     ; R1 = 10
    MOV R2, R0                      ; R2 = R0 (temporarily holds number)
    UMOD R0, R2, R1                 ; R0 = R2%R1 (number = number%10)
outUDecDone
    ; R0 (number) is between 0 and 9
    ADD R0, R0, #'0'                ; R0 = R0 + '0' (number = number + '0')
    BL  UART_OutChar                ; send the character to the UART
    POP {PC}                        ; restore previous value of LR into PC (return)

;---------------------UART_InUHex----------------------------------------
; Accepts ASCII input in unsigned hexadecimal (base 16) format
; Input: none
; Output: R0  32-bit unsigned number
; No '$' or '0x' need be entered, just the 1 to 8 hex digits
; It will convert lower case a-f to uppercase A-F
;     and converts to a 32-bit unsigned number
;     value range is 0 to FFFFFFFF
; If you enter a number above FFFFFFFF, it will return an incorrect value
; Backspace will remove last digit typed
UART_InUHex
    PUSH {R4, R5, LR}               ; save current value of R4, R5, and LR
    MOV R4, #0                      ; R4 = 0 (number = 0)
    MOV R5, #0                      ; R5 = 0 (length = 0)
inUHexLoop
    ; accepts characters until <enter> is typed
    BL  UART_InChar                 ; get a character from the UART
    CMP R0, #CR                     ; is R0 (most recent character) == 0x0D (<enter>)?
    BEQ inUHexDone                  ; if so, skip to 'inUHexDone'
    ; check if the input is a digit, 0-9
    ; if the character is not 0-9, check for other valid input
    CMP R0, #'0'                    ; is R0 (most recent character) < '0'?
    BLO inUHexNotDigit              ; if so, skip to 'inUHexNotDigit'
    CMP R0, #'9'                    ; is R0 (most recent character) > '9'?
    BHI inUHexNotDigit              ; if so, skip to 'inUHexNotDigit'
    MOV R1, #0x10                   ; R1 = 0x10 = 16
    MUL R4, R4, R1                  ; R4 = R4*R1 (number = number*16)
    ADD R4, R4, R0                  ; R4 = R4 + R0 (number = number*16 + character)
    SUB R4, R4, #'0'                ; R4 = R4 - '0' (number = number*16 + character - '0')
    ADD R5, R5, #1                  ; R5 = R5 + 1 (length = length + 1)
    BL  UART_OutChar                ; echo the character to the UART
    B   inUHexLoop                  ; unconditional branch to 'inUHexLoop'
inUHexNotDigit
    ; check if the input is an uppercase letter, 'A'-'F'
    CMP R0, #'A'                    ; is R0 (most recent character) < 'A'?
    BLO inUHexNotUpper              ; if so, skip to 'inUHexNotUpper'
    CMP R0, #'F'                    ; is R0 (most recent character) > 'F'?
    BHI inUHexNotUpper              ; if so, skip to 'inUHexNotUpper'
    MOV R1, #0x10                   ; R1 = 0x10 = 16
    MUL R4, R4, R1                  ; R4 = R4*R1 (number = number*16)
    ADD R4, R4, R0                  ; R4 = R4 + R0 (number = number*16 + character)
    SUB R4, R4, #'A'                ; R4 = R4 - '0' (number = number*16 + character - 'A')
    ADD R4, R4, #0xA                ; R4 = R4 + 0xA (number = number*16 + character - 'A' + 10)
    ADD R5, R5, #1                  ; R5 = R5 + 1 (length = length + 1)
    BL  UART_OutChar                ; echo the character to the UART
    B   inUHexLoop                  ; unconditional branch to 'inUHexLoop'
inUHexNotUpper
    ; check if the input is a lowercase letter, 'a'-'f'
    CMP R0, #'a'                    ; is R0 (most recent character) < 'a'?
    BLO inUHexOther                 ; if so, skip to 'inUHexOther'
    CMP R0, #'f'                    ; is R0 (most recent character) > 'f'?
    BHI inUHexOther                 ; if so, skip to 'inUHexOther'
    MOV R1, #0x10                   ; R1 = 0x10 = 16
    MUL R4, R4, R1                  ; R4 = R4*R1 (number = number*16)
    ADD R4, R4, R0                  ; R4 = R4 + R0 (number = number*16 + character)
    SUB R4, R4, #'a'                ; R4 = R4 - '0' (number = number*16 + character - 'a')
    ADD R4, R4, #0xA                ; R4 = R4 + 0xA (number = number*16 + character - 'a' + 10)
    ADD R5, R5, #1                  ; R5 = R5 + 1 (length = length + 1)
    BL  UART_OutChar                ; echo the character to the UART
    B   inUHexLoop                  ; unconditional branch to 'inUHexLoop'
inUHexOther
    ; if the input is a backspace, then the return number is
    ; changed and a backspace is outputted to the screen
    CMP R0, #BS                     ; is R0 (most recent character) == 0x08 (<backspace>)?
    BNE inUHexLoop                  ; if not, skip to 'inUHexLoop'
    CMP R5, #0                      ; is R5 (length) == 0?
    BEQ inUHexLoop                  ; if so, skip to 'inUHexLoop'
    MOV R1, #0x10                   ; R1 = 0x10 = 16
    UDIV R4, R4, R1                 ; R4 = R4/R1 (number = number/16)
    SUB R5, R5, #1                  ; R5 = R5 - 1 (length = length - 1)
    BL  UART_OutChar                ; echo the character to the UART
;    MOV R0, #SPA                    ; R0 = SPA (<space>)
;    BL  UART_OutChar                ; echo additional <space> to the UART
;    MOV R0, #BS                     ; R0 = BS (<backspace>)
;    BL  UART_OutChar                ; echo additional <backspace> to the UART
    B   inUHexLoop                  ; unconditional branch to 'inUHexLoop'
inUHexDone
    MOV R0, R4                      ; R0 = R4 (return 'number' in R0)
    POP {R4, R5, PC}                ; restore previous value of R4 into R4, R5 into R5, and LR into PC (return)

;--------------------------UART_OutUHex----------------------------
; Output a 32-bit number in unsigned hexadecimal format
; Input: R0  32-bit number to be transferred
; Output: none
; Variable format 1 to 8 digits with no space before or after
UART_OutUHex
    ; This function uses recursion to convert the number of
    ;   unspecified length as an ASCII string
    PUSH {LR}                       ; save current value of LR
    CMP R0, #0x10                   ; is R0 (number) < 16?
    BLO outUHexOneDigit             ; if so, skip to 'outUHexOneDigit'
outUHexManyDigits
    ; R0 (number) >= 16
    ; recursive call to UART_OutUHex with R0/0x10 (number/0x10)
    PUSH {R0}                       ; save current value of R0 (number)
    MOV R1, #0x10                   ; R1 = 0x10 = 16
    UDIV R0, R0, R1                 ; R0 = R0/R1 (number = number/0x10)
    BL  UART_OutUHex
    POP {R0}                        ; restore previous value of R0 into R0
    ; recursive call to UART_OutUHex with R0%0x10 (number%0x10)
    PUSH {R0}                       ; save current value of R0 (number)
    MOV R1, #0x10                   ; R1 = 0x10 = 16
    MOV R2, R0                      ; R2 = R0 (temporarily holds number)
    UMOD R0, R2, R1                 ; R0 = R2%R1 (number = number%0x10)
    BL  UART_OutUHex
    POP {R0}                        ; restore previous value of R0 into R0
    B   outUHexDone                 ; unconditional branch to 'outUHexDone'
outUHexOneDigit
    ; R0 (number) is between 0 and 15
    CMP R0, #0xA                    ; is R0 (number) < 10?
    BLO outUHexOneNumber            ; if so, skip to 'outUHexOneNumber'
outUHexOneLetter
    ; R0 (number) is between 10 and 15
    ; convert R0 to a character between 'A' and 'F'
    SUB R0, R0, #0xA                ; R0 = R0 - 10 (number = number - 0xA)
    ADD R0, R0, #'A'                ; R0 = R0 + 'A' (number = number - 0xA + 'A')
    BL  UART_OutChar                ; send the character to the UART
    B   outUHexDone                 ; unconditional branch to 'outUHexDone'
outUHexOneNumber
    ; R0 (number) is between 0 and 9
    ; convert R0 to a character between '0' and '9'
    ADD R0, R0, #'0'                ; R0 = R0 + 'A' (number = number + '0')
    BL  UART_OutChar                ; send the character to the UART
outUHexDone
    POP {PC}                        ; restore previous value of LR into PC (return)

;------------UART_InString------------
; Accepts ASCII characters from the serial port
;    and adds them to a string until <enter> is typed
;    or until max length of the string is reached.
; It echoes each character as it is inputted.
; If a backspace is inputted, the string is modified
;    and the backspace is echoed
; terminates the string with a null character
; uses busy-waiting synchronization on RDRF
; Input: R0  pointer to empty buffer
;        R1  number of non-NULL characters that can
;            fit in the buffer (in other words size-1)
; Output: R0  pointer to NULL-terminated string
; -- Modified by Agustinus Darmawan + Mingjie Qiu --
UART_InString
    PUSH {R4, R5, R6, LR}           ; save current value of R4, R5, R6, and LR
    MOV R4, R0                      ; R4 = R0 (save the buffer pointer parameter)
    MOV R5, #0                      ; R5 = 0 (length = 0)
    MOV R6, R1                      ; R6 = R1 (save the max length parameter)
inStringLoop
    ; accepts characters until <enter> is typed
    BL  UART_InChar                 ; get a character from the UART
    CMP R0, #CR                     ; is R0 (most recent character) == 0x0D (<enter>)?
    BEQ inStringDone                ; if so, skip to 'inStringDone'
    ; if the input is a backspace, then the return string is
    ; changed and a backspace is outputted to the screen
    CMP R0, #BS                     ; is R0 (most recent character) == 0x08 (<backspace>)?
    BNE inStringCont                ; if not, skip to 'inStringCont'
    CMP R5, #0                      ; is R5 (length) == 0?
    BEQ inStringLoop                ; if so, skip to 'inStringLoop'
    SUB R4, R4, #1                  ; R4 = R4 - 1 (bufferPt = bufferPt - 1)
    SUB R5, R5, #1                  ; R5 = R5 - 1 (length = length - 1)
    BL  UART_OutChar                ; echo the character to the UART
;    MOV R0, #SPA                    ; R0 = SPA (<space>)
;    BL  UART_OutChar                ; echo additional <space> to the UART
;    MOV R0, #BS                     ; R0 = BS (<backspace>)
;    BL  UART_OutChar                ; echo additional <backspace> to the UART
    B   inStringLoop                ; unconditional branch to 'inStringLoop'
inStringCont
    ; if the buffer has room for another character, add the
    ; incoming character to the buffer
    CMP R5, R6                      ; is R5 (length) == R6 (max length)?
    BEQ inStringLoop                ; if so, skip to 'inUDecLoop'
    STRB R0, [R4]                   ; [R4] = R0 (store 8 least significant bits of R0 into location pointed to by R4)
    ADD R4, R4, #1                  ; R4 = R4 + 1 (bufferPt = bufferPt + 1)
    ADD R5, R5, #1                  ; R5 = R5 + 1 (length = length + 1)
    BL  UART_OutChar                ; echo the character to the UART
    B   inStringLoop                ; unconditional branch to 'inStringLoop'
inStringDone
    ; NULL terminate the string
    MOV R0, #0                      ; R0 = 0 = NULL
    STRB R0, [R4]                   ; [R4] = R0 (store R0 (NULL) into location pointed to by R4)
    MOV R0, R4                      ; R0 = R4 (return the buffer pointer in R0)
    POP {R4, R5, R6, PC}            ; restore previous value of R4 into R4, R5 into R5, R6 into R6, and LR into PC (return)

;;------------UART_HighStickParity------------
; Configura el SPS, EPS y PEN del UART0
; para que el bit de paridad envie 1
UART_HighStickParity
	PUSH {R0, R1, LR}           ; save current value of R0, R1 and LR
	LDR R1, =UART0_LCRH_R           ; R1 = &UART0_LCRH_R
    LDR R0, [R1]                    ; R0 = [R1]
	BIC R0, R0, #UART_LCRH_EPS		; HIGH Stick Parity
    STR R0, [R1]                    ; [R1] = R0
	POP {R0, R1, PC}            ; restore previous value of R0 into R0, R1 into R1, and LR into PC (return)
;;------------UART_LowStickParity------------
; Configura el SPS, EPS y PEN del UART0
; para que el bit de paridad envie 0
UART_LowStickParity
	PUSH {R0, R1, LR}           ; save current value of R0, R1 and LR
	LDR R1, =UART0_LCRH_R           ; R1 = &UART0_LCRH_R
    LDR R0, [R1]                    ; R0 = [R1]
	ORR R0, R0, #UART_LCRH_EPS		; LOW Stick Parity
    STR R0, [R1]                    ; [R1] = R0
	POP {R0, R1, PC}            ; restore previous value of R0 into R0, R1 into R1, and LR into PC (return)
	

	ALIGN                           ; make sure the end of this section is aligned
    END                             ; end of file