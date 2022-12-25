RVCop64
=======

This is a fork of RVCop64 - a firmware for [The Orange Cartridge][1] - 
that implements a
RISC-V co-processor for the 6510/8502 processor in the C64/C128.  The
RISC-V processor is based on [VexRiscv][2] and implements the RV32IM
architecture. Integration of peripherals such as external RAM, SD-card
and USB is done though the [LiteX][3] framework.

This fork supports `rv32imafds` instructions if `--with-fpu` is selected - see below.
Note that due to the FPGA limits, dual-core CPUs cannot be configured with FPU support.

The bitstream includes an EXROM containing [BASIC extensions](doc/basic.md)
and a [machine code monitor](doc/rvmon.md).

For debugging via USB, serial port or JTAG, please see the
[debugging](doc/debugging.md) documentation.


Building
--------

After cloning the repository, make sure you run `git submodule update --init --recursive` on the toplevel directory.

To build the bitstream, go to the `hw` directory and run the python script
`bitstream.py`:
Warning: there's some heavy dependencies to your build-environment, especially when rebuilding the CPU core is necessary.

Example for building a single core CPU featuring FPU support with 80MHz frequency, with the console via USB:
```sh
$ cd hw
$ python3 bitstream.py --platform=orangecart --uart=usb_acm --sys-clk-freq=80e6 --cpu-count=1 --with-fpu --with-wishbone-memory
```
TODO: --with-wishbone-memory seems mandatory, should be made as default.

If all goes well, the bitstream will be created as
`build/gateware/orangecart.bit` under the `hw` directory.
Expect one warning about the use of IDDRXN and ODDRXN primitives on the
same pin.

There are a number of arguments that can be passed to the `bitstream.py`
script:

> --platform {orangecart}

Specifies the hardware platform to target.  This is a mandatory argument.
Currently only the value `orangecart` is valid.

> --sys-clk-freq _SYS_CLK_FREQ_

Changes the clock frequency of the RISC-V processor from the default of
64 MHz.  The speed should be specified in Hz.  If increasing the frequency,
please watch out for warnings from `nextpnr` about failure to close timing.
If decreasing the frequency, be aware that too low frequency can cause
the external RAM to malfunction.

> --uart {serial,usb_acm,jtag_uart,crossover}

Changes the connection of the RISC-V processor's built-in serial port.
By default it is connected to a virtual UART which is accessed through
the `rvterm` BASIC command.  Specifying `serial` connects it to the
physical serial port pins (J2) instead.  Specifying `usb_acm` connects
it to the USB port, as an ACM device.  Specifying `jtag_uart` connects
it to the JTAG, for use with `litex_term jtag`.  Specifying `crossover`
connects it to a virtual UART accessible through [`litex_server`][4]
(please also enable one or more debug ports).

> --usb {eptri,simplehostusb,debug}

Adds custom USB functionality.  This argument can not be used together
with `--uart usb_acm`.  The value `debug` adds a USB bridge for
[`litex_server`][4].  The values `eptri` and `simplehostusb` adds register
interfaces for USB device and USB host respectively, which can be used by
the software running on the RISC-V processor.

> --jtag-debug

Adds a JTAG bridge for [`litex_server`][4].  This argument can not be used
together with `--uart jtag_uart`.

> --serial-debug

Adds a serial port (J2) bridge for [`litex_server`][4].  This argument
can not be used together with `--uart serial`.

> --serial-debug-baudrate _SERIAL_DEBUG_BAUDRATE_

Sets the baudrate for the serial port debug bridge enabled with
`--serial-debug`.  The default is 115200 bps.

> --seed _SEED_

Specifies a random seed for `nextpnr`.  In case routing fails, trying a
different seed might help.  This should normally not be needed.

Releases
--------

For your convenience there may appear some pre-built bitstreams under releases. Besides the bitstream itself, I may provide also the device tree specs in source `.dts` and binary `.dtb` formats. These may be useful to be used in conjunction with the RiscV Linux port - see here: https://github.com/litex-hub/linux-on-litex-vexriscv
(Note: the Linux port was tested - as a principle PoC; due to OrangeCart's RAM limitations, Linux has to use the sdcard rootfs, making the whole system fairly slow. I successfully showed principle functioning of the OrangeCarts features, such as C64 memory access).

*General Disclaimer: all materials here shall be used at ones own risk! The author may not be held responsible for any potential damage on your hardware and/or software equipment.*

[1]: https://github.com/zeldin/OrangeCart.git
[2]: https://github.com/SpinalHDL/VexRiscv
[3]: https://github.com/enjoy-digital/litex
[4]: https://github.com/enjoy-digital/litex/wiki/Use-Host-Bridge-to-control-debug-a-SoC
