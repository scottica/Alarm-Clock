; AlarmClock.asm

$NOLIST
$MODN76E003
$LIST

;Pin Definitions

CLK           EQU 16600000
TIMER0_RATE   EQU 4096       ; 2kHz tone
TIMER0_RELOAD EQU ((65536-(CLK/TIMER0_RATE)))
TIMER2_RATE   EQU 1000       ; 1ms tick
TIMER2_RELOAD EQU ((65536-(CLK/TIMER2_RATE)))

BTN_MODE      EQU P1.1
BTN_HOUR      EQU P1.2
BTN_MIN       EQU P1.0
BTN_SEC       EQU P3.0
BTN_BONUS     EQU P1.5 
SOUND_OUT     EQU P1.7

LCD_RS  EQU P1.3
LCD_E   EQU P1.4
LCD_D4  EQU P0.0
LCD_D5  EQU P0.1
LCD_D6  EQU P0.2
LCD_D7  EQU P0.3

;   Variables
dseg at 0x30
Count1ms:       ds 2
RTC_S:          ds 1
RTC_M:          ds 1
RTC_H:          ds 1
ALM_M:          ds 1
ALM_H:          ds 1
Current_Mode:   ds 1
Temp_Digit:     ds 1

bseg
RTC_AMPM:       dbit 1
ALM_AMPM:       dbit 1
ALM_ON:         dbit 1
ALM_TRIGGERED:  dbit 1
Update_LCD:     dbit 1

cseg
org 0x0000
    ljmp main

org 0x000B
    ljmp Timer0_ISR

org 0x002B
    ljmp Timer2_ISR

$NOLIST
$include(LCD_4bit.inc)
$LIST

;   Initialization + ISRs
Timer0_Init:
    orl CKCON, #0b00001000
    mov a, TMOD
    anl a, #0xf0
    orl a, #0x01
    mov TMOD, a
    setb ET0
    ret

Timer2_Init:
    mov T2CON, #0
    mov TH2, #high(TIMER2_RELOAD)
    mov TL2, #low(TIMER2_RELOAD)
    orl T2MOD, #0x80
    mov RCMP2H, #high(TIMER2_RELOAD)
    mov RCMP2L, #low(TIMER2_RELOAD)
    clr a
    mov Count1ms+0, a
    mov Count1ms+1, a
    orl EIE, #0x80
    setb TR2
    ret

Timer0_ISR:
    clr TR0
    mov TH0, #high(TIMER0_RELOAD)
    mov TL0, #low(TIMER0_RELOAD)
    setb TR0
    cpl SOUND_OUT
    reti

Timer2_ISR:
    clr TF2
    push acc
    push psw
    
    inc Count1ms+0
    mov a, Count1ms+0
    jnz Check_One_Sec
    inc Count1ms+1

Check_One_Sec:
    mov a, Count1ms+0
    cjne a, #low(1000), Timer2_Done
    mov a, Count1ms+1
    cjne a, #high(1000), Timer2_Done
    
    clr a
    mov Count1ms+0, a
    mov Count1ms+1, a
    setb Update_LCD

    ; Increment Seconds
    mov a, RTC_S
    add a, #1
    da a
    mov RTC_S, a
    cjne a, #0x60, Time_Check_Alarm
    mov RTC_S, #0
    
    ; Increment Minutes
    mov a, RTC_M
    add a, #1
    da a
    mov RTC_M, a
    cjne a, #0x60, Time_Check_Alarm
    mov RTC_M, #0
    
    ; Increment Hours
    mov a, RTC_H
    add a, #1
    da a
    mov RTC_H, a
    cjne a, #0x12, Check_13
    cpl RTC_AMPM
    sjmp Time_Check_Alarm
Check_13:
    cjne a, #0x13, Time_Check_Alarm
    mov RTC_H, #0x01

Time_Check_Alarm:
    jnb ALM_ON, Timer2_Done
    mov a, RTC_H
    cjne a, ALM_H, Timer2_Done
    mov a, RTC_M
    cjne a, ALM_M, Timer2_Done
    mov a, RTC_S
    jnz Timer2_Done
    
    mov C, RTC_AMPM
    mov A, #0
    mov ACC.0, C
    mov C, ALM_AMPM
    subb A, #0
    jnz Timer2_Done
    
    setb ALM_TRIGGERED

Timer2_Done:
    pop psw
    pop acc
    reti

;   Main Program
main:
    mov SP, #0x7F
    
    mov P0M1, #0x00
    mov P0M2, #0x00
    mov P1M1, #0x00
    mov P1M2, #0x80
    mov P3M2, #0x00
    
    mov RTC_H, #0x12
    mov RTC_M, #0x00
    mov RTC_S, #0x00
    clr RTC_AMPM
    
    mov ALM_H, #0x12
    mov ALM_M, #0x00
    clr ALM_AMPM
    clr ALM_ON
    clr ALM_TRIGGERED
    mov Current_Mode, #0
    
    lcall Timer0_Init
    lcall Timer2_Init
    lcall LCD_4BIT
    setb EA

Loop:
    jb ALM_TRIGGERED, Play_Morse_Sequence
    
    clr TR0
    setb SOUND_OUT
    ljmp Check_Buttons

Play_Morse_Sequence:
    lcall Play_Current_Time_Morse
    clr ALM_TRIGGERED
    setb Update_LCD
    ljmp Loop

;   Morse Code Subroutines
Wait_250ms:
    Wait_Milli_Seconds(#250)
    ret

Wait_500ms:
    Wait_Milli_Seconds(#250)
    Wait_Milli_Seconds(#250)
    ret

Wait_750ms:
    lcall Wait_500ms
    lcall Wait_250ms
    ret

; Used for word spaces (approx 1.5s)
Gap_Word:
    setb SOUND_OUT
    lcall Wait_750ms
    lcall Wait_750ms
    ret

; GIVE ME A GOOD MARK
Play_Bonus_Morse:
    mov dptr, #Bonus_Msg
Bonus_Loop:
    clr a
    movc a, @a+dptr
    jz Bonus_End 
    inc dptr
    
    cjne a, #1, Try_Dash

    lcall Beep_Dot
    lcall Gap_Symbol
    sjmp Bonus_Loop

Try_Dash:
    cjne a, #2, Try_Char_Gap
    ; Is Dash
    lcall Beep_Dash
    lcall Gap_Symbol
    sjmp Bonus_Loop

Try_Char_Gap:
    cjne a, #3, Try_Word_Gap
    ; Is End of Letter
    lcall Gap_Char
    sjmp Bonus_Loop

Try_Word_Gap:
    ; Is Space between words
    lcall Gap_Word 
    sjmp Bonus_Loop

Bonus_End:
    ret

Play_Current_Time_Morse:
    mov a, RTC_H
    swap a
    anl a, #0x0F
    mov Temp_Digit, a
    lcall Play_Digit_Morse
    
    mov a, RTC_H
    anl a, #0x0F
    mov Temp_Digit, a
    lcall Play_Digit_Morse
    
    lcall Wait_500ms
    lcall Wait_500ms
    lcall Wait_500ms
    
    mov a, RTC_M
    swap a
    anl a, #0x0F
    mov Temp_Digit, a
    lcall Play_Digit_Morse

    mov a, RTC_M
    anl a, #0x0F
    mov Temp_Digit, a
    lcall Play_Digit_Morse
    ret

Play_Digit_Morse:
    mov a, Temp_Digit
    mov b, #5
    mul ab            
    mov R0, a        
    mov dptr, #Morse_Table
    
    mov R1, #0        
Morse_Symbol_Loop:
    mov a, R0        
    add a, R1        
    movc a, @a+dptr  
    
    cjne a, #1, Do_Dash
    lcall Beep_Dot
    sjmp Symbol_Done
Do_Dash:
    lcall Beep_Dash
    
Symbol_Done:
    lcall Gap_Symbol
    inc R1
    cjne R1, #5, Morse_Symbol_Loop
    
    lcall Gap_Char
    ret

Beep_Dot:
    setb TR0
    lcall Wait_250ms    ; 0.25s
    clr TR0
    ret

Beep_Dash:
    setb TR0
    lcall Wait_500ms    ; 0.50s
    clr TR0
    ret

Gap_Symbol:
    setb SOUND_OUT
    lcall Wait_250ms    ; 0.25s 
    ret

Gap_Char:
    setb SOUND_OUT
    lcall Wait_750ms    ; 0.75s 
    ret


;   Button Logic
Check_Buttons:
    jnb BTN_MODE, Mode_Pressed
    ljmp Check_Hour
Mode_Pressed:
    Wait_Milli_Seconds(#50)
    jb BTN_MODE, Check_Hour_Jump
    jnb BTN_MODE, $
    
    inc Current_Mode
    mov a, Current_Mode
    cjne a, #3, Mode_Updated
    mov Current_Mode, #0
Mode_Updated:
    setb Update_LCD

Check_Hour_Jump:
    ljmp Check_Hour

Check_Hour:
    jnb BTN_HOUR, Hour_Pressed
    ljmp Check_Min
Hour_Pressed:
    Wait_Milli_Seconds(#50)
    jb BTN_HOUR, Check_Min_Jump
    jnb BTN_HOUR, $
    
    mov a, Current_Mode
    cjne a, #1, Not_Set_Time_H
    mov a, RTC_H
    add a, #1
    da a
    mov RTC_H, a
    cjne a, #0x12, Chk_RTC_H13
    cpl RTC_AMPM
    ljmp Flag_LCD
Chk_RTC_H13:
    cjne a, #0x13, Flag_LCD_Jump
    mov RTC_H, #0x01
    ljmp Flag_LCD

Not_Set_Time_H:
    cjne a, #2, Check_Min_Jump
    mov a, ALM_H
    add a, #1
    da a
    mov ALM_H, a
    cjne a, #0x12, Chk_ALM_H13
    cpl ALM_AMPM
    ljmp Flag_LCD
Chk_ALM_H13:
    cjne a, #0x13, Flag_LCD_Jump
    mov ALM_H, #0x01
    ljmp Flag_LCD

Check_Min_Jump:
    ljmp Check_Min
Flag_LCD_Jump:
    ljmp Flag_LCD

Check_Min:
    jnb BTN_MIN, Min_Pressed
    ljmp Check_Sec
Min_Pressed:
    Wait_Milli_Seconds(#50)
    jb BTN_MIN, Check_Sec_Jump
    jnb BTN_MIN, $

    mov a, Current_Mode
    cjne a, #1, Not_Set_Time_M
    mov a, RTC_M
    add a, #1
    da a
    mov RTC_M, a
    cjne a, #0x60, Flag_LCD_Jump
    mov RTC_M, #0
    ljmp Flag_LCD
    
Not_Set_Time_M:
    cjne a, #2, Check_Sec_Jump
    mov a, ALM_M
    add a, #1
    da a
    mov ALM_M, a
    cjne a, #0x60, Flag_LCD_Jump
    mov ALM_M, #0
    ljmp Flag_LCD

Check_Sec_Jump:
    ljmp Check_Sec

Check_Sec:
    jnb BTN_SEC, Sec_Pressed
    ljmp Check_Bonus
Sec_Pressed:
    Wait_Milli_Seconds(#50)
    jb BTN_SEC, Check_Bonus_Jump
    jnb BTN_SEC, $
    
    mov a, Current_Mode
    jz Toggle_Alarm_Enable
    cjne a, #1, Flag_LCD_Jump
    mov RTC_S, #0x00
    ljmp Flag_LCD

Toggle_Alarm_Enable:
    cpl ALM_ON
    ljmp Flag_LCD

Check_Bonus_Jump:
    ljmp Check_Bonus

;NEW BUTTON CHECK
Check_Bonus:
    jnb BTN_BONUS, Bonus_Pressed
    ljmp Check_LCD
Bonus_Pressed:
    Wait_Milli_Seconds(#50)
    jb BTN_BONUS, Check_LCD_Jump ; Debounce
    jnb BTN_BONUS, $             ; Wait release
    
    lcall Play_Bonus_Morse       
    ljmp Flag_LCD

Check_LCD_Jump:
    ljmp Check_LCD

Flag_LCD:
    setb Update_LCD

Check_LCD:
    jb Update_LCD, Do_Update
    ljmp Loop_End
Do_Update:
    clr Update_LCD
    
    Set_Cursor(1, 1)
    Send_Constant_String(#Txt_Time)
    Display_BCD(RTC_H)
    Display_char(#':')
    Display_BCD(RTC_M)
    Display_char(#':')
    Display_BCD(RTC_S)
    
    Display_char(#' ')
    jnb RTC_AMPM, Disp_AM
    Display_char(#'P')
    sjmp Disp_M
Disp_AM:
    Display_char(#'A')
Disp_M:
    Display_char(#'M')

Line2:
    Set_Cursor(2, 1)
    
    mov a, Current_Mode
    jz Disp_Mode_Run
    cjne a, #1, Disp_Mode_SetAlm
    
    Send_Constant_String(#Txt_SetTime)
    ljmp Loop_End
    
Disp_Mode_SetAlm:
    Send_Constant_String(#Txt_SetAlm)
    Display_BCD(ALM_H)
    Display_char(#':')
    Display_BCD(ALM_M)
    
    Display_char(#' ')
    jnb ALM_AMPM, Disp_SetAlm_AM
    Display_char(#'P')
    sjmp Disp_SetAlm_M
Disp_SetAlm_AM:
    Display_char(#'A')
Disp_SetAlm_M:
    Display_char(#'M')
    ljmp Loop_End

Disp_Mode_Run:
    Send_Constant_String(#Txt_Alarm)
    jnb ALM_ON, Disp_Off
    Send_Constant_String(#Txt_On)
    Display_char(#' ')
    Display_BCD(ALM_H)
    Display_char(#':')
    Display_BCD(ALM_M)
    
    Display_char(#' ')
    jnb ALM_AMPM, Disp_Run_AM
    Display_char(#'P')
    sjmp Disp_Run_M
Disp_Run_AM:
    Display_char(#'A')
Disp_Run_M:
    Display_char(#'M')
    ljmp Loop_End

Disp_Off:
    Send_Constant_String(#Txt_Off)

Loop_End:
    ljmp Loop

;-------------------------------------------------------------------------------
;   Data Tables
;-------------------------------------------------------------------------------
; Morse Code Table
Morse_Table:
    db 3, 3, 3, 3, 3 ; 0
    db 1, 3, 3, 3, 3 ; 1
    db 1, 1, 3, 3, 3 ; 2
    db 1, 1, 1, 3, 3 ; 3
    db 1, 1, 1, 1, 3 ; 4
    db 1, 1, 1, 1, 1 ; 5
    db 3, 1, 1, 1, 1 ; 6
    db 3, 3, 1, 1, 1 ; 7
    db 3, 3, 3, 1, 1 ; 8
    db 3, 3, 3, 3, 1 ; 9

Bonus_Msg:
    ; G (--.)
    db 2, 2, 1, 3
    ; I (..)
    db 1, 1, 3
    ; V (...-)
    db 1, 1, 1, 2, 3
    ; E (.) + Space
    db 1, 4

    ; M (--)
    db 2, 2, 3
    ; E (.) + Space
    db 1, 4
    
    ; A (.-) + Space
    db 1, 2, 4
    
    ; G (--.)
    db 2, 2, 1, 3
    ; O (---)
    db 2, 2, 2, 3
    ; O (---)
    db 2, 2, 2, 3
    ; D (-..) + Space
    db 2, 1, 1, 4
    
    ; M (--)
    db 2, 2, 3
    ; A (.-)
    db 1, 2, 3
    ; R (.-.)
    db 1, 2, 1, 3
    ; K (-.-) + END
    db 2, 1, 2, 0

; Strings
Txt_Time:    db 'Time:', 0
Txt_Alarm:   db 'Alm:', 0
Txt_On:      db 'ON ', 0
Txt_Off:     db 'OFF       ', 0
Txt_SetTime: db 'Set Time      ', 0
Txt_SetAlm:  db 'Set Alm ', 0

END