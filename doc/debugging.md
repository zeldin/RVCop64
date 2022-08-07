# Debugging with RVCop64

## Running `litex_server` and `litex_term`

These tools are python scripts which can be found in
`hw/deps/litex/litex/tools`.  The scripts make use of the `litex` and
`migen` python modules.  Therefore, in addition to adding
`hw/deps/litex/litex/tools` to `$PATH`, you should also add
`hw/deps/litex` and `hw/deps/migen` to `$PYTHONPATH`.  Example
running `litex_term` from the `hw` directory:

```
env PYTHONPATH=deps/litex:deps/migen PATH=deps/litex/litex/tools:"$PATH" litex_term.py
```


## USB debugging

If USB is not needed for something else by the application (i.e. if you
don't need `--usb eptri` or `--usb simplehostusb`), it can be used for
debugging, as a host bridge and/or UART.

### USB host bridge

To get a USB host bridge, use the option `--usb debug` when building the
bitstream.  This will create a USB device with VID 0x1209 and PID 0x5bf0.
Make sure that you have write access to the USB device (using `udev`
rules, or by running `litex_server` as root) and then connect with:

```
litex_server.py --usb --usb-vid 0x1209 --usb-pid 0x5bf0
```

With the `litex_server` running, any debug application using the LiteX
`RemoteClient` API can access the internals of the RVCop64.

### USB UART

If the USB host bridge is used, it is possible to access the UART
of the RISC-V processor via `litex_server`.  Use the `--uart crossover`
option when building the bitstream to connect the UART to a wishbone
VUART.  Then start `litex_server` as before:

```
litex_server.py --usb --usb-vid 0x1209 --usb-pid 0x5bf0
```

With the `litex_server` running, now connect to the crossover VUART using

```
litex_term.py --csr-csv build/csr.csv crossover
```

If the USB host bridge is _not_ used, the USB can instead be used as UART
using the `--uart usb_acm` option when building the bitstream.  In this
case the UART can be accessed as a standard USB-ACM port, visible as
`/dev/ttyACM0` on Linux.  Use

```
litex_term.py /dev/ttyACM0
```

or connect using any other terminal program.


## Serial port debugging

The physical serial port is mainly intended for debugging and can be used
as a host bridge and/or UART with an appropriate 3.3V serial cable.

### Serial port host bridge

To get a serial port host bridge, use the option `--serial-debug` when
building the bitstream.  Then run `litex_server` using the `--uart` option:

```
litex_server.py --uart --uart-port /dev/ttyUSB0
```

(Replace `/dev/ttyUSB0` with the appropriate device name for your host
serial port.)  With the `litex_server` running, any debug application
using the LiteX `RemoteClient` API can access the internals of the RVCop64.

### Serial port UART

If the serial port host bridge is used, it is possible to access the UART
of the RISC-V processor via `litex_server`.  Use the `--uart crossover`
option when building the bitstream to connect the UART to a wishbone
VUART.  Then start `litex_server` as before:

```
litex_server.py --uart --uart-port /dev/ttyUSB0
```

With the `litex_server` running, now connect to the crossover VUART using

```
litex_term.py --csr-csv build/csr.csv crossover
```

If the serial port host bridge is _not_ used, the serial port can instead
be used as UART using the `--uart serial` option when building the bitstream.
In this case the UART can be accessed directly via the serial cable, for
example

```
litex_term.py /dev/ttyUSB0
```

if using an FTDI cable.


## JTAG debugging

The JTAG port can be used as a host bridge and/or UART with the
appropriate cable.

### JTAG host bridge

To get a JTAG host bridge, use the option `--jtag-debug` when building
the bitstream.  Then run `litex_server` using the `--jtag` option:

```
litex_server.py --jtag --jtag-config openocd_orangecart_rpi.cfg
```
(Replace `openocd_orangecart_rpi.cfg` with `openocd_orangecart_ftdi.cfg`
if using an FTDI based JTAG cable.)  With the `litex_server` running,
any debug application using the LiteX `RemoteClient` API can access the
internals of the RVCop64.

### JTAG UART

If the JTAG host bridge is used, it is possible to access the UART
of the RISC-V processor via `litex_server`.  Use the `--uart crossover`
option when building the bitstream to connect the UART to a wishbone
VUART.  Then start `litex_server` as before:

```
litex_server.py --jtag --jtag-config openocd_orangecart_rpi.cfg
```

With the `litex_server` running, now connect to the crossover VUART using

```
litex_term.py --csr-csv build/csr.csv crossover
```

If the JTAG port host bridge is _not_ used, the JTAG can instead be used
as UART using the `--uart jtag_uart` option when building the bitstream.
In this case `litex_term` must be run in the `jtag` mode:

```
litex_term.py --jtag-config openocd_orangecart_rpi.cfg jtag
```

While this mode prevents the simultaneous use of the `RemoteClient` API
over JTAG, it gives much better throughput than when using the crossover mode.
