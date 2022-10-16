OLED example
============

This is a simple RISC-V program that speaks to a
[SparkFun LCD-17153](https://www.sparkfun.com/products/17153) OLED display
via I2C.


## Prerequisites

 * The RVCop64 bitstream needs to be built with `--pmod i2c` as an argument
   to `bitstream.py`.

 * The OLED display needs to be connected to the J5 connector on the
   Orange Cartridge using the following pinout:

   | J5 pin | Function      |
   | ------ | ------------- |
   | 1      | No connection |
   | 2      | No connection |
   | 3      | SCL           |
   | 4      | SDA           |
   | 5      | GND           |
   | 6      | +3.3V         |


## Building and running

To build `demo.bin` and `demo.elf`, just run `make`.

To upload the program using the LiteX BIOS serial boot protocol,
run `make UART=your_uart run`, where `your_uart` can be for example
`/dev/ttyUSB0` (hardware serial port through USB dongle) or `crossover`
(see [the debugging docs](../../doc/debugging.md) for details about
 crossover UART).  Then start the serial boot process.
