.include "tn2313def.inc"

; Port pins
.equ pin_pwm  = PD5     ; output, PWM channel 0B
.equ pin_sync = PD4     ; input, timer source T0
.equ pin_btn  = PD6     ; input with a pull-up resistor, button (0 = up, 1 = down)
.equ pin_led1 = PD0     ; output, green LED indicating passive mode (1)
.equ pin_led2 = PD1     ; output, red LED indicating active mode (2)
.equ pin_snd  = PD2     ; output, speaker

.equ portD_output = (1<<pin_pwm) | (1<<pin_snd) | (1<<pin_led1) | (1<<pin_led2)
.equ portD_pullup = (1<<pin_btn)


; Constants

.equ max_level  = 9

.equ warm_up_time = 1333  ; * 90 ms = 2 min
; time intervals for mode 1 (passive)
.equ warn_time1   = 3222  ; * 90 ms = 4 min 50 s
.equ off_time1    = 3333  ; * 90 ms = 5 min
; time intervals for mode 2 (active)
.equ warn_time2   = 1944  ; * 90 ms = 2 min 55 s
.equ off_time2    = 2000  ; * 90 ms = 3 min
; timeL bit used for LED flashing
.equ flash_bit = 2  ; flash period = 90 ms * 2^(1 + flash_bit) = 0.72 s

; timer0 PWM mode: external clock T0 (falling edge), use OCR0A as TOP
.equ pwm_mode_a = (1<<WGM01) | (1<<WGM00)
.equ pwm_mode_b = (1<<WGM02) | (1<<CS02) | (1<<CS01)
.equ pwm_on     = (1<<COM0B1) ; channel B fast PWM


; Register aliases
.def zero  = r0
.def tmp   = r16
.def mode  = r17  ; 0 = off, 1 = passive, 2 = active
.def level = r18  ; 0..9
.def leds  = r19
.def beep  = r20
.def btn   = r21  ; button state
.def prev  = r22  ; previous button state
.def trash = r23
.def timeL = r24
.def timeH = r25
.def warn  = r26  ; = XL

; Macros

; Compares a 16-bit register pair (L:H) with an immediate value.
.macro cpiw
	.message "no parameters specified"
.endm
.macro cpiw_16_i
      ldi   trash, high(@2)
      cpi   @0, low(@2)
      cpc   @1, trash
.endm


; Interrupt vector table
      rjmp  reset ; RES  Reset
      reti        ; INT0 External Interrupt Request 0
      reti        ; INT1 External Interrupt Request 1
      reti        ; ICP1 Timer/Counter1 Capture Event
      reti        ; OC1A Timer/Counter1 Compare Match A
      reti        ; OVF1 Timer/Counter1 Overflow
      reti        ; OVF0 Timer/Counter0 Overflow
      reti        ; URXC USART, Rx Complete
      reti        ; UDRE USART Data Register Empty
      reti        ; UTXC USART, Tx Complete
      reti        ; ACI  Analog Comparator
      reti        ; PCI0 Pin Change Interrupt Request 0
      reti        ; OC1B Timer/Counter1 Compare Match B
      rjmp  timer ; OC0A Timer/Counter0 Compare Match A
      reti        ; OC0B Timer/Counter0 Compare Match B
      reti        ; USI_START USI Start Condition
      reti        ; USI_OVF   USI Overflow
      reti        ; ERDY EEPROM Ready
      reti        ; WDT  Watchdog Timer Overflow
      reti        ; PCI1 Pin Change Interrupt Request 1
      reti        ; PCI2 Pin Change Interrupt Request 2


; Program starts here after reset
reset:
      clr   zero
      out   SREG, zero
      
      ; initialize stack
      ldi   tmp, low(RAMEND)
      out   SPL, tmp
      
      ; initialize port D:
      ;   pin_pwm, pin_led1, pin_led2 for output
      ;   pin_sync for input
      ;   pin_btn  for input with a pull-up resistor
      ldi   tmp, portD_output
      out   DDRD, tmp
      ldi   tmp, portD_pullup
      out   PORTD, tmp
      
      ; initialize port B for input with pull-up resistors
      out   DDRB, zero
      ser   tmp
      out   PORTB, tmp
      
      ; initialize timer 0 and PWM 0B
      ldi   tmp, max_level - 1
      out   OCR0A, tmp
      ldi   tmp, pwm_mode_a
      out   TCCR0A, tmp
      ldi   tmp, pwm_mode_b
      out   TCCR0B, tmp
      
      ; initialize registers
      ldi   btn, 0            ; button up
      ldi   prev, 0           ; button up
      ldi   mode, 2           ; active
      clr   warn
      clr   timeL
      clr   timeH
      ldi   YL, low (warm_up_time)
      ldi   YH, high(warm_up_time)
      
      ; enable idle sleep mode
      ldi   tmp, (1<<SE)
      out   MCUCR, tmp
      
      ; initialize interrrupt by timer 0A
      ldi   tmp, (1<<OCIE0A)
      out   TIMSK, tmp
      sei

loop:
      sleep
      rjmp  loop


; Timer0 interrupt (every PWM period, 90 ms)
timer:
      clr   beep

      in    tmp, PIND
      andi  tmp, (1<<pin_btn) ; get button state
      mov   btn, tmp
      
      com   prev
      and   tmp, prev         ; btn is down and prev is up
      mov   prev, btn
      breq  same_mode  

change_mode:
      ldi   tmp, 2
      sub   tmp, warn         ; if warn, switch to the same mode
      cp    mode, tmp
      breq  change_to_passive
change_to_active:
      ldi   mode, 2
      rjmp  reset_time
change_to_passive:
      ldi   mode, 1
reset_time:
      clr   timeL
      clr   timeH
      ldi   beep, 1

same_mode:
      rcall process_mode
      
      ; set PWM value
      dec   level             ; PWM value written to OCR0B should be 
      out   OCR0B, level      ;   less by 1 than the actual level
      ldi   tmp, pwm_mode_a
      sbrs  level, 7          ; if the value is not -1 (actual level > 0)
      ori   tmp, pwm_on       ;   then turn on the PWM
      out   TCCR0A, tmp       ;   else turn off
      
      ; set LEDS
      ldi   tmp, portD_pullup
      or    tmp, leds
      out   PORTD, tmp
      
      ; beep if needed
      sbrc  beep, 0
      rcall do_beep
      clr   beep
      
      reti


; Makes a beep sound
do_beep:
      ldi   trash, 30

do_beep0:
      sbi   PORTD, pin_snd
      ldi   tmp, 51

do_beep1:
      dec   tmp
      brne  do_beep1
      
      nop
      nop
      nop
      
      cbi   PORTD, pin_snd
      ldi   tmp, 51

do_beep2:
      dec   tmp
      brne  do_beep2
      
      dec   trash
      brne  do_beep0
      
      ret


; Calculates `level`, `leds`, `beep`, and `warn` by `mode` and switch position.
; Increments `time` if `mode` != off. Changes `mode` if time is up.
;   input:   `mode`, `time`, `beep`
;   output:  `mode`, `time`, `beep`, `level`, `leds`, `warn`
process_mode:
      clr   leds
      clr   warn
      tst   mode
      breq  mode0
      
      ; decrement warm time if > 0
      mov   tmp, YL
      or    tmp, YH
      breq  is_warm
      sbiw  YL, 1
      rjmp  get_level
      
is_warm:
      adiw  timeL, 1          ; increment time

get_level:
      in    level, PINB       ; get switch 1 and 2 positions
      com   level             ; invert the input bits
      
      cpi   mode, 1
      breq  mode1

; Active mode
mode2:
      andi  level, 0x0F       ; use switch 2 value as level
      
      cpiw  [timeL:timeH, off_time2]
      brsh  mode2_off_time
      
      cpiw  [timeL:timeH, warn_time2]
      brlo  mode2_normal_time

mode2_warn_time:
      ldi   warn, 1
      mov   tmp, timeL
      andi  tmp, (1<<flash_bit)
      breq  mode2_no_led
      ori   beep, 1
mode2_normal_time:
      ldi   leds, (1<<pin_led2)
mode2_no_led:
      ret

mode2_off_time:
      ldi   mode, 1
      clr   timeL
      clr   timeH
      ret


; Passive mode
mode1:
      swap  level
      andi  level, 0x0F       ; use switch 1 value as level
      
      cpiw  [timeL:timeH, off_time1]
      brsh  mode1_off_time
      
      cpiw  [timeL:timeH, warn_time1]
      brlo  mode1_normal_time

mode1_warn_time:
      ldi   warn, 1
      mov   tmp, timeL
      andi  tmp, (1<<flash_bit)
      breq  mode1_no_led
      ori   beep, 1
mode1_normal_time:
      ldi   leds, (1<<pin_led1)
mode1_no_led:
      ret

mode1_off_time:
      clr   mode
      clr   timeL
      clr   timeH
      ret


; Off mode
mode0:
      clr   level             ; switch off PWM
      ldi   YL, low (warm_up_time)
      ldi   YH, high(warm_up_time)
      ret
