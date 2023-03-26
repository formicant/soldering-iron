# Soldering Iron

A program for `ATTiny2313` to control the temperature of a soldering iron.


## Operation

The controller uses PWM to control the soldering iron's temperature.

Both rising and falling edges of the pulses must be synchronized with the moments when the 50 Hz AC power voltage crosses zero.
This is possible thanks to a special circuit generating a sync pulse each time the power voltage crosses zero.

The PWM level is controlled by either of the two 10-positional switches (switch1 and switch2). A two-positional switch (switch0) defines which of the two is currently used. This allows quick switching between two temperature modes (active and passive).

Each 10-positionsl switch has 5 pins: a ground pin and 4 binary bits (1, 2, 4, 8) representing the switch's position (0 to 9) in binary.

The frequency of the PWM is 50 Hz (power) × 2 (zero crossings per period) / 9 (switch positions) ≈ 11 Hz.


## Pins

The controller uses Port B for switches 1 and 2, D6 for switch 0, T0 external timer pin (D5) for sync pulses, and OC0B pin (D4) for PWM output.

```
                   ATTiny 2313
                   ┌───┐ ┌───┐
       (RESET) PA2─┤1  ╰─╯ 20├─VCC
               PD0─┤2      19├─PB7 <- switch2.8
               PD1─┤3      18├─PB6 <- switch2.4
               PA1─┤4      17├─PB5 <- switch2.2
               PA0─┤5      16├─PB4 <- switch2.1
               PD2─┤6      15├─PB3 <- switch1.8
               PD3─┤7      14├─PB2 <- switch1.4
sync ->   (T0) PD4─┤8      13├─PB1 <- switch1.2
pwm  <- (OC0B) PD5─┤9      12├─PB0 <- switch1.1
switch gnd ->  GND─┤10     11├─PD6 <- switch0
                   └─────────┘
```


## Fuses

500 kHz clock frequency is used (4Mhz internal oscillator with 8× prescaler).

- **Low:** `62` (modified)
  |   fuse | bits | value |  state   | description
  |-------:|:----:|:-----:|:--------:|:------------
  | CKDIV8 |    7 |     0 | default  | 8× prescaling enabled
  |  CKOUT |    6 |     1 | default  | clock output disabled
  |    SUT | 5..4 |    10 | default  | slowly rising power
  |  CKSEL | 3..0 |  0010 | modified | internal RC oscillator 4 MHz

- **High:** `DF` (default)
  |     fuse | bits | value |  state  | description
  |---------:|:----:|:-----:|:-------:|:------------
  |     DWEN |    7 |     1 | default | debugWire disabled
  |   EESAVE |    6 |     1 | default | do not preserve EEPROM when flashing
  |    SPIEN |    5 |     0 | default | serial programming enabled
  |    WDTON |    4 |     1 | default | watchdog safety level 1
  | BODLEVEL | 3..1 |   111 | default | BOD disabled
  | RSTDISBL |    0 |     1 | default | reset enabled

- **Extended:** `FF` (default)
  |      fuse | bits |  value  |  state  | description
  |----------:|:----:|:-------:|:-------:|:------------
  | (unused)  | 7..1 | 1111111 | default | 
  | SELFPRGEN |    0 |       1 | default | self-programming disabled

To program the fuses, use `fuse.sh`:
``` bash
avrdude -c usbasp-clone -p t2313 -B 125kHz -U lfuse:w:0x62:m
```


## Building and flashing

The .hex file can be built using [AVRA](https://github.com/Ro5bert/avra).

To build the project, use `build.sh`:
``` bash
avra soldering-iron.asm -o soldering-iron.hex
```

To flash the controller, use `flash.sh`:
``` bash
avrdude -c usbasp-clone -p t2313 -B 125kHz -U flash:w:soldering-iron.hex:a
```

In VSCode, building and flashing can be done via tasks (`Ctrl+Shift+B`).

**Warining!**
Switch 2 uses the pins the USBasp programmer is connected to.
Switch 2 must be in `0` position during flashing!
