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
		EXPORT SysTick_Init_Count
		EXPORT SysTick_Check_Count
		EXPORT systick_interrupt

;-----------------delay----------------
; Proporciona un delay de N milisegundos
; Input : R0 - N miliseconds to delay
; Output: none
; Modifies: none, restore all original values of registers used
delay
	PUSH {R0,R1,R2,LR}			; save current value of R0, R1, R2 and LR
	; Systick disable
	LDR R1,=SYSTICK_STCTRL_R	; R0 = &SYSTICK_STCTRL_R (pointer)
	MOV R2, #0					; R1 = [R0]								
	STR R2, [R1]				; [R0] = R1
	; start iinit sequence
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
	ADD R1, R1, #(SYSTICK_STCTRL_CLK_ENABLE)
	STRB R1, [R0]				; [R0] = R1
systickLoop
	LDR	R1, [R0]				; R1 = [R0]
	MOV R2,#SYSTICK_STCTRL_COUNT	; R2 = SYSTICK_STCTRL_COUNT
	ANDS R1,R1,R2				; R1 = R1 && R2
	BEQ systickLoop				; If ZERO, counter bit low, go to systickLoop
delay_done
	MOV R1, #0					; R1 = [R0]
								; Systick disable
	STRB R1, [R0]				; [R0] = R1	
	POP	{R0,R1,R2,PC}			; restore previous value of R0 into R0, R1 into R1, and LR into PC (return)

;-----------------SysTick_Init_Count----------------
; Activa el systick con un conteo de N milisegundos
; Input : R0 - N miliseconds to delay
; Output: none
; Modifies: none, restore all original values of registers used
SysTick_Init_Count
	PUSH {R0,R1,R2,LR}			; save current value of R0, R1, R2 and LR
	; Systick disable
	LDR R1,=SYSTICK_STCTRL_R	; R0 = &SYSTICK_STCTRL_R (pointer)
	MOV R2, #0					; R1 = [R0]								
	STR R2, [R1]				; [R0] = R1
	; start init sequence
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
	ADD R1, R1, #(SYSTICK_STCTRL_CLK_ENABLE)
	STRB R1, [R0]				; [R0] = R1
	POP	{R0,R1,R2,PC}			; restore previous value of R0 into R0, R1 into R1, and LR into PC (return)
	
;-----------------SysTick_Check_Count----------------
; Verifica el estado del Count en el Systick
; Input : none
; Output: R0, 1 if count=1, 0 if not
; Modifies: R0 (out), restore all original values of registers used
SysTick_Check_Count
	PUSH {R1,R2,LR}			; save current value of R0, R1, R2 and LR
	LDR R0,=SYSTICK_STCTRL_R	; R0 = &SYSTICK_STCTRL_R (pointer)
	LDR	R1, [R0]				; R1 = [R0]
	MOV R0,#SYSTICK_STCTRL_COUNT	; R2 = SYSTICK_STCTRL_COUNT
	ANDS R0,R0,R1				; R1 = R1 && R2
	BEQ SysTick_Check_Count_done		; If ZERO, counter bit low, go to SysTick_Check_Count_done
	MOV R0,#1					; R1 = 1
	LDR R1,=SYSTICK_STCTRL_R	; R1 = &SYSTICK_STCTRL_R (pointer)
	MOV R2,#0					; R2 = 0
								; Systick disable
	STRB R2, [R1]				; [R0] = R1
SysTick_Check_Count_done
	POP	{R1,R2,PC}			; restore previous value of R0 into R0, R1 into R1, and LR into PC (return)

;----------systick_interrupt------------
systick_interrupt
	POP {R0}
	POP {R0}
	POP {R0}
	POP {R0}
	POP {R0}
	POP {R0}
	POP {R0}
	POP {R0}
	POP {R0}
	LDR R0,=SYSTICK_STCTRL_R	; R0 = &SYSTICK_STCTRL_R (pointer)
	MOV R1, #0					; R1 = [R0]
								; Systick DISABLE, Interruptions enable, PIOSC
	;ADD R1, R1, #(SYSTICK_STCTRL_CLK_INTEN)
	STR R1, [R0]				; [R0] = R1	
	B delay_done
    ALIGN                           ; make sure the end of this section is aligned
    END                             ; end of file