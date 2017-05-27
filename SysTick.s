; SysTick.s
; Runs on TM4C1294
; Funciones para el manejo del Systick
; David Pinzon
; May 26, 2017
;-------------SysTick Registers-------------
SYSTICK_STCTRL_R			EQU	0xE000E010	; SysTick Control and status register
SYSTICK_STCTRL_COUNT		EQU	0x00010000	; SysTick Count flag
SYSTICK_STCTRL_CLK_SRC		EQU	0x00000004	; SysTick Clock Source
SYSTICK_STCTRL_CLK_INTEN	EQU	0x00000002	; SysTick Interrup Enable
SYSTICK_STCTRL_CLK_ENABLE	EQU	0x00000001	; SysTick Enable
	
SYSTICK_STRELOAD_R			EQU	0xE000E014	; Reload value register	
SYSTICK_STCURRENT_R			EQU	0xE000E018	; Current value register
	
ONE_MILISECOND				EQU 0x00000FA0	; One milisecond with PIOSC (16MHZ / 4)

        AREA    |.text|, CODE, READONLY, ALIGN=2
        THUMB
		EXPORT delay
		EXPORT systick_interrupt

;-----------------delay----------------
; Proporciona un delay de N milisegundos
; Input : R0 - N miliseconds to delay
; Output: none
; Modifies: none, restore all original values of registers used
delay
	PUSH {R0,R1,R2,LR}			; save current value of R0, R1, R2 and LR
	MOV R2,#ONE_MILISECOND		; R2 = Cicles to generate 1ms (4Mhz)
	MUL R1, R0, R2				; R1 = R0*R2 (Cicles to generate N milisecods on 4Mhz)
	; --- reload value ---
	LDR R0,=SYSTICK_STRELOAD_R	; R0 = &SYSTICK_STRELOAD_R (pointer)
	STR R1, [R0]				; [R0] = R1
	; --- current value ---
	LDR R0,=SYSTICK_STCURRENT_R	; R0 = &SYSTICK_STCURRENT_R (pointer)
	MOV R1, #0					; R1 = 0
	STR R1, [R0]				; [R0] = R1
	;--- control ---
	LDR R0,=SYSTICK_STCTRL_R	; R0 = &SYSTICK_STCTRL_R (pointer)
	MOV R1, #0					; R1 = [R0]
								; Systick enable, Interruptions enable, PIOSC
	ADD R1, R1, #(SYSTICK_STCTRL_CLK_ENABLE+SYSTICK_STCTRL_CLK_INTEN)
	STRB R1, [R0]				; [R0] = R1	
systickLoop	
	B systickLoop
delay_done
	POP	{R0,R1,R2,PC}			; restore previous value of R0 into R0, R1 into R1, and LR into PC (return)

;----------systick_interrupt------------
systick_interrupt
	B delay_done
    ALIGN                           ; make sure the end of this section is aligned
    END                             ; end of file