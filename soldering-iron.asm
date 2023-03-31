.include "tn2313def.inc"

; Port pins
.equ pin_pwm  = PD5     ; output, PWM channel 0B
.equ pin_sync = PD4     ; input, timer source T0
.equ pin_sw0  = PD6     ; input with a pull-up resistor

; Constants
.equ max_level  = 9
; timer0 PWM mode: external clock T0 (falling edge), use OCR0A as TOP
.equ pwm_mode_a = (1<<WGM01) | (1<<WGM00)
.equ pwm_mode_b = (1<<WGM02) | (1<<CS02) | (1<<CS01)
.equ pwm_on     = (1<<COM0B1) ; channel B fast PWM

; Register aliases
.def zero  = r0
.def tmp   = r16
.def level = r17


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
      ;   pin_pwm  for output
      ;   pin_sync for input
      ;   pin_sw0  for input with a pull-up resistor
      ldi   tmp, (1<<pin_pwm)
      out   DDRD, tmp
      ldi   tmp, (1<<pin_sw0)
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
      
      ; initialize interrrupt by timer 0A
      ldi   tmp, (1<<OCIE0A)
      out   TIMSK, tmp
      sei
      
      ; enable idle sleep mode
      ldi   tmp, (1<<SE)
      out   MCUCR, tmp

loop:
      sleep
      rjmp  loop


; Timer0 interrupt (every PWM period)
timer:
      in    level, PINB       ; get switch 1 and 2 position
      com   level             ; invert the input bits
      sbic  PIND, pin_sw0     ; if switch0 is 1 (off)
      swap  level             ;   then use switch 2
      andi  level, 0x0F       ;   else use switch 1
      subi  level, 1          ; PWM value written to OCR0B should be 
      out   OCR0B, level      ;   less by 1 than the actual level
      
      ldi   tmp, pwm_mode_a
      sbrs  level, 7          ; if the value is not -1 (actual level > 0)
      ori   tmp, pwm_on       ;   then turn on the PWM
      out   TCCR0A, tmp       ;   else turn off
      
      reti
