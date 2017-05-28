; GPTimer.s
; Runs on TM4C1294
; Funciones para el manejo de los GPTimers
; David Pinzon & Alberto Lopez
; May 27, 2017
;-------------GPTimers Registers-------------
;formato a seguir:

;para un registro
;NombreDelRegistro_R					;EQU direccion		 ; breve descripcion o nombre

;para un modulo del registro de un bit
;NombreDelRegistro_NombreDelmodulo		;EQU valueWithBitSet ; breve descripcion o nombre

;para un mudulo del registro de varios bits
;NombreDelRegistro_NombreDelmodulo_M	;EQU valueWithBitsSet ; breve descripcion o nombre

;para un valor de configuracion de un modulo del regitro
;NombreDelRegistro_NombreDelmodulo_(opcion)	;EQU valueToConfig ; breve descripcion o nombre

;para otros valores a definir
;NombreDescriptivoDelValor		; EQU value			; breve descripcion

        AREA    |.text|, CODE, READONLY, ALIGN=2
        THUMB
	;functions to export
		EXPORT Timer_ResponseTime
		EXPORT Timer_ResponseTime_stop
		EXPORT Timer_BreakTime
		EXPORT Timer_SetupTime
		EXPORT Timer_PollingTime
		EXPORT Timer_NoResponseTime
		EXPORT Timer_NoResponseTime_stop

;---------------function_name----------------
; Breve descripcion
; Input : Registros que se leen como entrada y descripcion breve de lo que deben tener
; Output: Registros que se 
; Modifies: Registros que modifica la funcion. Los registros de salido y otros que modifique
	;tratar de que no modifique ninguno con un PUSH y POP al principio y final de la funcion
function_name
	PUSH {R0,R1,R2,LR}			; save current value of R0, R1, R2 and LR
	; hacer cosas de la funcion
	POP	{R0,R1,R2,PC}			; restore previous value of R0 into R0, R1 into R1, and LR into PC (return)

;funciones a implementar
Timer_ResponseTime ;5ms
	PUSH {LR}
	POP {PC}
Timer_ResponseTime_stop
	PUSH {LR}
	POP {PC}
Timer_BreakTime	;100ms
	PUSH {LR}
	POP {PC}
Timer_SetupTime ;200ms
	PUSH {LR}
	POP {PC}
Timer_PollingTime ;150ms
	PUSH {LR}
	POP {PC}
Timer_NoResponseTime ;2s
	PUSH {LR}
	POP {PC}
Timer_NoResponseTime_stop
	PUSH {LR}
	POP {PC}

	ALIGN                           ; make sure the end of this section is aligned
    END                             ; end of file