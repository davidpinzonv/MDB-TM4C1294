; PLL.s
; Runs on TM4C1294
; A software function to change the bus frequency using the PLL.
; The EQU statement allows the function PLL_Init() to initialize
; the PLL to the desired frequency.
; Daniel Valvano
; April 1, 2014

;  This example accompanies the book
;  "Embedded Systems: Introduction to Arm Cortex M Microcontrollers",
;  ISBN: 978-1469998749, Jonathan Valvano, copyright (c) 2014
;  Program 4.6, Section 4.3
;  "Embedded Systems: Real Time Interfacing to Arm Cortex M Microcontrollers",
;  ISBN: 978-1463590154, Jonathan Valvano, copyright (c) 2014
;  Program 2.10, Figure 2.37
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

; The EQU statement PSYSDIV initializes
; the PLL to the desired frequency.
PSYSDIV                       EQU 3
; bus frequency is 480MHz/(PSYSDIV+1) = 480MHz/(3+1) = 120 MHz
; IMPORTANT: See Step 6) of PLL_Init().  If you change something, change 480 MHz.
; IMPORTANT: You can use the 10-bit PSYSDIV value to generate an extremely slow
; clock, but this may cause the debugger to be unable to connect to the processor
; and return it to full speed.  If this happens, you will need to erase the whole
; flash or somehow slow down the debugger.  You should also insert some mechanism
; to return the processor to full speed such as a key wakeup or a button pressed
; during reset.  The debugger starts to have problems connecting when the system
; clock is about 600,000 Hz or slower; although inserting a failsafe mechanism
; will completely prevent this problem.
; IMPORTANT: Several peripherals (including but not necessarily limited to ADC,
; USB, Ethernet, etc.) require a particular minimum clock speed.  You may need to
; use the 16 MHz PIOSC as the clock for these modules instead of the PLL.

SYSCTL_RIS_R                  EQU 0x400FE050
SYSCTL_RIS_MOSCPUPRIS         EQU 0x00000100  ; MOSC Power Up Raw Interrupt Status
SYSCTL_MOSCCTL_R              EQU 0x400FE07C
SYSCTL_MOSCCTL_PWRDN          EQU 0x00000008  ; Power Down
SYSCTL_MOSCCTL_NOXTAL         EQU 0x00000004  ; No Crystal Connected
SYSCTL_RSCLKCFG_R             EQU 0x400FE0B0
SYSCTL_RSCLKCFG_MEMTIMU       EQU 0x80000000  ; Memory Timing Register Update
SYSCTL_RSCLKCFG_NEWFREQ       EQU 0x40000000  ; New PLLFREQ Accept
SYSCTL_RSCLKCFG_USEPLL        EQU 0x10000000  ; Use PLL
SYSCTL_RSCLKCFG_PLLSRC_M      EQU 0x0F000000  ; PLL Source
SYSCTL_RSCLKCFG_PLLSRC_MOSC   EQU 0x03000000  ; MOSC is the PLL input clock source
SYSCTL_RSCLKCFG_OSCSRC_M      EQU 0x00F00000  ; Oscillator Source
SYSCTL_RSCLKCFG_OSCSRC_MOSC   EQU 0x00300000  ; MOSC is oscillator source
SYSCTL_RSCLKCFG_PSYSDIV_M     EQU 0x000003FF  ; PLL System Clock Divisor
SYSCTL_MEMTIM0_R              EQU 0x400FE0C0
SYSCTL_DSCLKCFG_R             EQU 0x400FE144
SYSCTL_DSCLKCFG_DSOSCSRC_M    EQU 0x00F00000  ; Deep Sleep Oscillator Source
SYSCTL_DSCLKCFG_DSOSCSRC_MOSC EQU 0x00300000  ; MOSC
SYSCTL_PLLFREQ0_R             EQU 0x400FE160
SYSCTL_PLLFREQ0_PLLPWR        EQU 0x00800000  ; PLL Power
SYSCTL_PLLFREQ0_MFRAC_M       EQU 0x000FFC00  ; PLL M Fractional Value
SYSCTL_PLLFREQ0_MINT_M        EQU 0x000003FF  ; PLL M Integer Value
SYSCTL_PLLFREQ0_MFRAC_S       EQU 10
SYSCTL_PLLFREQ0_MINT_S        EQU 0
SYSCTL_PLLFREQ1_R             EQU 0x400FE164
SYSCTL_PLLFREQ1_Q_M           EQU 0x00001F00  ; PLL Q Value
SYSCTL_PLLFREQ1_N_M           EQU 0x0000001F  ; PLL N Value
SYSCTL_PLLFREQ1_Q_S           EQU 8
SYSCTL_PLLFREQ1_N_S           EQU 0
SYSCTL_PLLSTAT_R              EQU 0x400FE168
SYSCTL_PLLSTAT_LOCK           EQU 0x00000001  ; PLL Lock

        AREA    |.text|, CODE, READONLY, ALIGN=2
        THUMB
        EXPORT  PLL_Init

;------------PLL_Init------------
; Configure the system to get its clock from the PLL.
; Input: none
; Output: none
; Modifies: R0, R1, R2, R3
PLL_Init
    ; 1) Once POR has completed, the PIOSC is acting as the system clock.  Just in case
    ;    this function has been called previously, be sure that the system is not being
    ;    clocked from the PLL while the PLL is being reconfigured.
    LDR R1, =SYSCTL_RSCLKCFG_R                 ; R1 = SYSCTL_RSCLKCFG_R (pointer)
    LDR R0, [R1]                               ; R0 = [R1] (value)
    BIC R0, R0, #SYSCTL_RSCLKCFG_USEPLL        ; R0 = R0&~SYSCTL_RSCLKCFG_USEPLL (clear USEPLL bit to bypass PLL)
    STR R0, [R1]                               ; [R1] = R0
    ; 2) Power up the MOSC by clearing the NOXTAL bit in the SYSCTL_MOSCCTL_R register.
    ; 3) Since crystal mode is required, clear the PWRDN bit.  The datasheet says to do
    ;    these two operations in a single write access to SYSCTL_MOSCCTL_R.
    LDR R1, =SYSCTL_MOSCCTL_R                  ; R1 = SYSCTL_MOSCCTL_R (pointer)
    LDR R0, [R1]                               ; R0 = [R1] (value)
    BIC R0, R0, #SYSCTL_MOSCCTL_NOXTAL         ; R0 = R0&~SYSCTL_MOSCCTL_NOXTAL (clear NOXTAL bit to use external 25 MHz crystal)
    BIC R0, R0, #SYSCTL_MOSCCTL_PWRDN          ; R0 = R0&~SYSCTL_MOSCCTL_PWRDN (clear PWRDN bit to power up main oscillator)
    STR R0, [R1]                               ; [R1] = R0 (both changes in one write access)
    ;    Wait for the MOSCPUPRIS bit to be set in the SYSCTL_RIS_R register, indicating
    ;    that MOSC crystal mode is ready.
    LDR R1, =SYSCTL_RIS_R                      ; R1 = SYSCTL_RIS_R (pointer)
PLL_Init_step3loop
    LDR R0, [R1]                               ; R0 = [R1] (value)
    ANDS R0, R0, #SYSCTL_RIS_MOSCPUPRIS        ; R0 = R0&SYSCTL_RIS_MOSCPUPRIS
    BEQ PLL_Init_step3loop                     ; if(R0 == 0), keep polling
    ; 4) Set both the OSCSRC and PLLSRC fields to 0x3 in the SYSCTL_RSCLKCFG_R register
    ;    at offset 0x0B0.
    LDR R1, =SYSCTL_RSCLKCFG_R                 ; R1 = SYSCTL_RSCLKCFG_R (pointer)
    LDR R0, [R1]                               ; R0 = [R1] (value)
    BIC R0, R0, #SYSCTL_RSCLKCFG_OSCSRC_M      ; R0 = R0&~SYSCTL_RSCLKCFG_OSCSRC_M (clear system run/sleep clock source field)
    ADD R0, R0, #SYSCTL_RSCLKCFG_OSCSRC_MOSC   ; R0 = R0 + SYSCTL_RSCLKCFG_OSCSRC_MOSC (configure to temporarily get run/sleep clock from 25 MHz main oscillator)
    BIC R0, R0, #SYSCTL_RSCLKCFG_PLLSRC_M      ; R0 = R0&~SYSCTL_RSCLKCFG_PLLSRC_M (clear PLL clock source field)
    ADD R0, R0, #SYSCTL_RSCLKCFG_PLLSRC_MOSC   ; R0 = R0 + SYSCTL_RSCLKCFG_PLLSRC_MOSC (configure for PLL clock from main oscillator)
    STR R0, [R1]                               ; [R1] = R0
    ; 5) If the application also requires the MOSC to be the deep-sleep clock source,
    ;    then program the DSOSCSRC field in the SYSCTL_DSCLKCFG_R register to 0x3.
    LDR R1, =SYSCTL_DSCLKCFG_R                 ; R1 = SYSCTL_DSCLKCFG_R (pointer)
    LDR R0, [R1]                               ; R0 = [R1] (value)
    BIC R0, R0, #SYSCTL_DSCLKCFG_DSOSCSRC_M    ; R0 = R0&~SYSCTL_DSCLKCFG_DSOSCSRC_M (clear system deep-sleep clock source field)
    ADD R0, R0, #SYSCTL_DSCLKCFG_DSOSCSRC_MOSC ; R0 = R0 + SYSCTL_DSCLKCFG_DSOSCSRC_MOSC (configure to get deep-sleep clock from main oscillator)
    STR R0, [R1]                               ; [R1] = R0
    ; 6) Write the SYSCTL_PLLFREQ0_R and SYSCTL_PLLFREQ1_R registers with the values of
    ;    Q, N, MINT, and MFRAC to configure the desired VCO frequency setting.
    ;    ************
    ;    The datasheet implies that the VCO frequency can go as high as 25.575 GHz
    ;    with MINT=1023 and a 25 MHz crystal.  This is clearly unreasonable.  For lack
    ;    of a recommended VCO frequency, this program sets Q, N, and MINT for a VCO
    ;    frequency of 480 MHz with MFRAC=0 to reduce jitter.  To run at a frequency
    ;    that is not an integer divisor of 480 MHz, change this section.
    ;    fVC0 = (fXTAL/(Q + 1)/(N + 1))*(MINT + (MFRAC/1,024))
    ;    fVCO = 480,000,000 Hz (arbitrary, but presumably as small as needed)
FXTAL  EQU 25000000                 ; fixed, this crystal is soldered to the Connected Launchpad
Q      EQU        0
N      EQU        4                 ; chosen for reference frequency within 4 to 30 MHz
MINT   EQU       96                 ; 480,000,000 = (25,000,000/(0 + 1)/(4 + 1))*(96 + (0/1,024))
MFRAC  EQU        0                 ; zero to reduce jitter
    ;    SysClk = fVCO / (PSYSDIV + 1)
SYSCLK EQU (FXTAL/(Q+1)/(N+1))*(MINT+MFRAC/1024)/(PSYSDIV+1)
    LDR R1, =SYSCTL_PLLFREQ0_R                 ; R1 = SYSCTL_PLLFREQ0_R (pointer)
    LDR R0, [R1]                               ; R0 = [R1] (value)
    LDR R3, =SYSCTL_PLLFREQ0_MFRAC_M           ; R3 = SYSCTL_PLLFREQ0_MFRAC_M (mask)
    BIC R0, R0, R3                             ; R0 = R0&~SYSCTL_PLLFREQ0_MFRAC_M (clear MFRAC field)
    LDR R3, =(MFRAC<<SYSCTL_PLLFREQ0_MFRAC_S)  ; R3 = (MFRAC<<SYSCTL_PLLFREQ0_MFRAC_S) (shifted value)
    ADD R0, R0, R3                             ; R0 = R0 + (MFRAC<<SYSCTL_PLLFREQ0_MFRAC_S) (configure MFRAC as defined above)
    LDR R3, =SYSCTL_PLLFREQ0_MINT_M            ; R3 = SYSCTL_PLLFREQ0_MINT_M (mask)
    BIC R0, R0, R3                             ; R0 = R0&~SYSCTL_PLLFREQ0_MINT_M (clear MINT field)
    ADD R0, R0, #(MINT<<SYSCTL_PLLFREQ0_MINT_S); R0 = R0 + (MINT<<SYSCTL_PLLFREQ0_MINT_S) (configure MINT as defined above)
    STR R0, [R1]                               ; [R1] = R0 (MFRAC and MINT changed but not locked in yet)
    LDR R1, =SYSCTL_PLLFREQ1_R                 ; R1 = SYSCTL_PLLFREQ1_R (pointer)
    LDR R0, [R1]                               ; R0 = [R1] (value)
    BIC R0, R0, #SYSCTL_PLLFREQ1_Q_M           ; R0 = R0&~SYSCTL_PLLFREQ1_Q_M (clear Q field)
    ADD R0, R0, #(Q<<SYSCTL_PLLFREQ1_Q_S)      ; R0 = R0 + (Q<<SYSCTL_PLLFREQ1_Q_S) (configure Q as defined above)
    BIC R0, R0, #SYSCTL_PLLFREQ1_N_M           ; R0 = R0&~SYSCTL_PLLFREQ1_N_M (clear N field)
    ADD R0, R0, #(N<<SYSCTL_PLLFREQ1_N_S)      ; R0 = R0 + (N<<SYSCTL_PLLFREQ1_N_S) (configure N as defined above)
    STR R0, [R1]                               ; [R1] = R0 (Q and N changed but not locked in yet)
    LDR R1, =SYSCTL_PLLFREQ0_R                 ; R1 = SYSCTL_PLLFREQ0_R (pointer)
    LDR R0, [R1]                               ; R0 = [R1] (value)
    ORR R0, R0, #SYSCTL_PLLFREQ0_PLLPWR        ; R0 = R0|SYSCTL_PLLFREQ0_PLLPWR (turn on power to PLL)
    STR R0, [R1]                               ; [R1] = R0
    LDR R1, =SYSCTL_RSCLKCFG_R                 ; R1 = SYSCTL_RSCLKCFG_R (pointer)
    LDR R0, [R1]                               ; R0 = [R1] (value)
    ORR R0, R0, #SYSCTL_RSCLKCFG_NEWFREQ       ; R0 = R0|SYSCTL_RSCLKCFG_NEWFREQ (lock in register changes)
    STR R0, [R1]                               ; [R1] = R0
    ; 7) Write the SYSCTL_MEMTIM0_R register to correspond to the new clock setting.
    ;    ************
    ;    Set the timing parameters to the main Flash and EEPROM memories, which
    ;    depend on the system clock frequency.  See Table 5-12 in datasheet.
    LDR R1, =SYSCTL_MEMTIM0_R                  ; R1 = SYSCTL_MEMTIM0_R (pointer)
    LDR R0, [R1]                               ; R0 = [R1] (value)
    LDR R3, =0x03EF03EF                        ; R3 = 0x03EF03EF (mask)
    BIC R0, R0, R3                             ; R0 = R0&~0x03EF03EF (clear EBCHT, EBCE, EWS, FBCHT, FBCE, and FWS fields)
    LDR R2, =SYSCLK                            ; R2 = (FXTAL/(Q+1)/(N+1))*(MINT+MFRAC/1024)/(PSYSDIV+1)
    LDR R3, =120000000                         ; R3 = 120,000,000 (value)
    CMP R2, R3                                 ; is R2 (SysClk) <= R3 (120,000,000 Hz)?
    BLS PLL_Init_step7fullspeed                ; if so, skip to the next test
PLL_Init_step7toofast                          ; 120 MHz < SysClk: "too fast"
    ; A setting is invalid, and the PLL cannot clock the system faster than 120 MHz.
    ; Skip the rest of the initialization, leaving the system clocked from the MOSC,
    ; which is a 25 MHz crystal.
    BX  LR                                     ; return
PLL_Init_step7fullspeed                        ; 100 MHz < SysClk <= 120 MHz: "full speed"
    LDR R3, =100000000                         ; R3 = 100,000,000 (value)
    CMP R2, R3                                 ; is R2 (SysClk) <= R3 (100,000,000 Hz)?
    BLS PLL_Init_step7veryfast                 ; if so, skip to the next test
    LDR R3, =0x01850185                        ; R3 = 0x01850185 (shifted values)
    ADD R0, R0, R3                             ; R0 = R0 + 0x01850185 (FBCHT/EBCHT = 6, FBCE/EBCE = 0, FWS/EWS = 5)
    B   PLL_Init_step7done                     ; unconditional branch to the end
PLL_Init_step7veryfast                         ; 80 MHz < SysClk <= 100 MHz: "very fast"
    LDR R3, =80000000                          ; R3 = 80,000,000 (value)
    CMP R2, R3                                 ; is R2 (SysClk) <= R3 (80,000,000 Hz)?
    BLS PLL_Init_step7fast                     ; if so, skip to the next test
    LDR R3, =0x01440144                        ; R3 = 0x01440144 (shifted values)
    ADD R0, R0, R3                             ; R0 = R0 + 0x01440144 (FBCHT/EBCHT = 5, FBCE/EBCE = 0, FWS/EWS = 4)
    B   PLL_Init_step7done                     ; unconditional branch to the end
PLL_Init_step7fast                             ; 60 MHz < SysClk <= 80 MHz: "fast"
    LDR R3, =60000000                          ; R3 = 60,000,000 (value)
    CMP R2, R3                                 ; is R2 (SysClk) <= R3 (60,000,000 Hz)?
    BLS PLL_Init_step7medium                   ; if so, skip to the next test
    LDR R3, =0x01030103                        ; R3 = 0x01030103 (shifted values)
    ADD R0, R0, R3                             ; R0 = R0 + 0x01030103 (FBCHT/EBCHT = 4, FBCE/EBCE = 0, FWS/EWS = 3)
    B   PLL_Init_step7done                     ; unconditional branch to the end
PLL_Init_step7medium                           ; 40 MHz < SysClk <= 60 MHz: "medium"
    LDR R3, =40000000                          ; R3 = 40,000,000 (value)
    CMP R2, R3                                 ; is R2 (SysClk) <= R3 (40,000,000 Hz)?
    BLS PLL_Init_step7slow                     ; if so, skip to the next test
    ADD R0, R0, #0x00C200C2                    ; R0 = R0 + 0x00C200C2 (FBCHT/EBCHT = 3, FBCE/EBCE = 0, FWS/EWS = 2)
    B   PLL_Init_step7done                     ; unconditional branch to the end
PLL_Init_step7slow                             ; 16 MHz < SysClk <= 40 MHz: "slow"
    LDR R3, =16000000                          ; R3 = 16,000,000 (value)
    CMP R2, R3                                 ; is R2 (SysClk) <= R3 (16,000,000 Hz)?
    BLS PLL_Init_step7veryslow                 ; if so, skip to the next test
    ADD R0, R0, #0x00810081                    ; R0 = R0 + 0x00810081 (FBCHT/EBCHT = 2, FBCE/EBCE = 1, FWS/EWS = 1)
    B   PLL_Init_step7done                     ; unconditional branch to the end
PLL_Init_step7veryslow                         ; SysClk == 16 MHz: "very slow"
    LDR R3, =16000000                          ; R3 = 16,000,000 (value)
    CMP R2, R3                                 ; is R2 (SysClk) < R3 (16,000,000 Hz)?
    BLO PLL_Init_step7extremelyslow            ; if so, skip to the next test
    ADD R0, R0, #0x00200020                    ; R0 = R0 + 0x00200020 (FBCHT/EBCHT = 0, FBCE/EBCE = 1, FWS/EWS = 0)
    B   PLL_Init_step7done                     ; unconditional branch to the end
PLL_Init_step7extremelyslow                    ; SysClk < 16 MHz: "extremely slow"
    ADD R0, R0, #0x00000000                    ; R0 = R0 + 0x00000000 (FBCHT/EBCHT = 0, FBCE/EBCE = 0, FWS/EWS = 0)
PLL_Init_step7done
    STR R0, [R1]                               ; [R1] = R0 (SYSCTL_MEMTIM0_R changed but not locked in yet)
    ; 8) Wait for the SYSCTL_PLLSTAT_R register to indicate that the PLL has reached
    ;    lock at the new operating point (or that a timeout period has passed and lock
    ;    has failed, in which case an error condition exists and this sequence is
    ;    abandoned and error processing is initiated).
    LDR R1, =SYSCTL_PLLSTAT_R                  ; R1 = SYSCTL_PLLSTAT_R (pointer)
    MOV R2, #0                                 ; R2 = 0 (timeout counter)
    MOV R3, #0xFFFF                            ; R3 = 0xFFFF (value)
PLL_Init_step8loop
    LDR R0, [R1]                               ; R0 = [R1] (value)
    ANDS R0, R0, #SYSCTL_PLLSTAT_LOCK          ; R0 = R0&SYSCTL_PLLSTAT_LOCK
    BNE PLL_Init_step8done                     ; if(R0 != 0), done polling
    ADD R2, R2, #1                             ; R2 = R2 + 1 (increment timeout counter)
    CMP R2, R3                                 ; if(R2 < 0xFFFF), keep polling
    BLO PLL_Init_step8loop
    ; The PLL never locked or is not powered.
    ; Skip the rest of the initialization, leaving the system clocked from the MOSC,
    ; which is a 25 MHz crystal.
    BX  LR                                     ; return
PLL_Init_step8done
    ; 9)Write the SYSCTL_RSCLKCFG_R register's PSYSDIV value, set the USEPLL bit to
    ;   enabled, and set the MEMTIMU bit.
    LDR R1, =SYSCTL_RSCLKCFG_R                 ; R1 = SYSCTL_RSCLKCFG_R (pointer)
    LDR R0, [R1]                               ; R0 = [R1] (value)
    LDR R3, =SYSCTL_RSCLKCFG_PSYSDIV_M         ; R3 = SYSCTL_RSCLKCFG_PSYSDIV_M (mask)
    BIC R0, R0, R3                             ; R0 = R0&~SYSCTL_RSCLKCFG_PSYSDIV_M (clear PSYSDIV field)
    ADD R0, R0, #(PSYSDIV&SYSCTL_RSCLKCFG_PSYSDIV_M); R0 = R0 + (PSYSDIV&SYSCTL_RSCLKCFG_PSYSDIV_M) (configure PSYSDIV as defined above)
    ORR R0, R0, #SYSCTL_RSCLKCFG_MEMTIMU       ; R0 = R0|SYSCTL_RSCLKCFG_MEMTIMU (set MEMTIMU bit to update memory timing parameters)
    ORR R0, R0, #SYSCTL_RSCLKCFG_USEPLL        ; R0 = R0|SYSCTL_RSCLKCFG_USEPLL (set USEPLL bit to get clock from PLL)
    STR R0, [R1]                               ; [R1] = R0 (execution and access are suspended while memory timing updates occur)
    BX  LR                                     ; return

    ALIGN                           ; make sure the end of this section is aligned
    END                             ; end of file
