#!/usr/bin/env python3
# This variable defines all the external programs that this module
# relies on.  lxbuildenv reads this variable in order to ensure
# the build will finish without exiting due to missing third-party
# programs.
LX_DEPENDENCIES = ["make", "meson", "riscv", "yosys", "nextpnr-ecp5"]

# Import lxbuildenv to integrate the deps/ directory
import lxbuildenv

import argparse
import contextlib
import json
import os
import sys

from litex.soc.integration.builder import Builder
from litex.tools.litex_json2dts_zephyr import generate_dts_config, print_or_save
from litex.soc.cores.cpu.vexriscv_smp import VexRiscvSMP

from rtl.basesoc import BaseSoC


def main():
    parser = argparse.ArgumentParser(
        description="Build RISC-V coprocessor cartridge")
    parser.add_argument(
        "--platform", choices=["orangecart"], required=True,
        help="build for a particular hardware"
    )
    cpu = parser.add_argument(
        "--cpu", default="vexriscv", choices=["vexriscv", "vexriscv_smp"], 
        help="Choose one of the supported VexRiscV CPUs"
    )
    parser.add_argument(
        "--sys-clk-freq", default=64e6,
        help="System clock frequency (default=64MHz)"
    )
    uart_action = parser.add_argument(
        "--uart", default=None, choices=["serial", "usb_acm", "jtag_uart", "crossover"],
        help="Connect main UART to pins or USB or JTAG, instead of to VUART"
    )
    uart2_action = parser.add_argument(
        "--uart2", default=None, choices=["vuart", "serial", "usb_acm", "jtag_uart", "crossover"],
        help="Create a second UART connected to VUART, pins, USB or JTAG"
    )
    parser.add_argument(
        "--usb", default=None, choices=["eptri", "simplehostusb", "debug"],
        help="Include USB functionality"
    )
    parser.add_argument(
        "--jtag-debug", action='store_true',
        help="Enable litex-server bridge through JTAG")
    parser.add_argument(
        "--serial-debug", action='store_true',
        help="Enable litex-server bridge through serial port pins")
    parser.add_argument(
        "--serial-debug-baudrate", type=int, default=115200,
        help="Set baudrate for serial port debug bridge")
    parser.add_argument(
        "--seed", type=int, default=1, help="seed to use in nextpnr"
    )
    args, _ = parser.parse_known_args()

    # Select platform based arguments
    if args.platform == "orangecart":
        from rtl.platform.orangecart import Platform, add_platform_args, platform_argdict

    if args.cpu == "vexriscv_smp":
        VexRiscvSMP.args_fill(parser)

    # Add any platform dependent args
    add_platform_args(parser)
    args = parser.parse_args()

    # Check for invalid combinations
    if args.uart == "usb_acm" and args.usb is not None:
        parser.error(str(argparse.ArgumentError(uart_action, "invalid choice: 'usb_acm' can not be used together with --usb")))
    if args.uart == "jtag_uart" and args.jtag_debug:
        parser.error(str(argparse.ArgumentError(uart_action, "invalid choice: 'jtag_uart' can not be used together with --jtag-debug")))
    if args.uart == "serial" and args.serial_debug:
        parser.error(str(argparse.ArgumentError(uart_action, "invalid choice: 'serial' can not be used together with --serial-debug")))
    if args.uart2 == (args.uart or "vuart"):
        parser.error(str(argparse.ArgumentError(uart2_action, "invalid choice: can't use same connection as --uart")))
    if args.uart2 == "usb_acm" and args.usb is not None:
        parser.error(str(argparse.ArgumentError(uart2_action, "invalid choice: 'usb_acm' can not be used together with --usb")))
    if args.uart2 == "jtag_uart" and args.jtag_debug:
        parser.error(str(argparse.ArgumentError(uart2_action, "invalid choice: 'jtag_uart' can not be used together with --jtag-debug")))
    if args.uart2 == "serial" and args.serial_debug:
        parser.error(str(argparse.ArgumentError(uart2_action, "invalid choice: 'serial' can not be used together with --serial-debug")))

    # load our platform file
    platform = Platform(**platform_argdict(args))

    output_dir = 'build'
    sw_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "../sw"))

    if args.cpu == "vexriscv_smp":
        cpu_type = "vexriscv_smp"
        cpu_variant = "linux"
        # hardwire wishbone memory - otherwise OC won't boot into BIOS
        args.with_wishbone_memory = True
        VexRiscvSMP.args_read(args)
    else:
        cpu_type = "vexriscv"
        cpu_variant = "standard+debug"
    if not os.path.exists(output_dir):
        os.mkdir(output_dir)
    f = open(os.path.join(output_dir, "build-commandline.log"), "w")
    for arg in enumerate(sys.argv):
        f.write(str(arg[1]) + " ")
    f.write("\n")
    f.close()

    soc = BaseSoC(platform, cpu_type=cpu_type, cpu_variant=cpu_variant,
                  uart_name="stream" if args.uart is None else args.uart,
                  uart2_name="stream" if args.uart2 == "vuart" else args.uart2,
                  usb=args.usb, with_jtagbone=args.jtag_debug,
                  with_uartbone=args.serial_debug,
                  uartbone_baudrate=args.serial_debug_baudrate,
                  clk_freq=int(float(args.sys_clk_freq)),
                  output_dir=output_dir)
    builder = Builder(soc, output_dir=output_dir,
                      csr_csv=os.path.join(output_dir, "csr.csv"),
                      csr_json=os.path.join(output_dir, "csr.json"),
                      csr_svd=os.path.join(output_dir, "soc.svd"),
                      compile_software=True, compile_gateware=True)
    builder.add_software_package("exrom", os.path.join(sw_dir, "exrom"))
    builder_kargs = { "abc9": True,
                      "seed": args.seed
                    } if args.toolchain == "trellis" else {}
    builder.build(**builder_kargs)
    with open(os.path.join(output_dir, "csr.json")) as f:
        csr_json = json.load(f)
    with open(os.devnull, "w") as f, contextlib.redirect_stdout(f):
        dts, config = generate_dts_config(csr_json)
    print_or_save(os.path.join(output_dir, "overlay.dts"), dts)
    print_or_save(os.path.join(output_dir, "overlay.config"), config)
    platform.finalise(output_dir)


if __name__ == "__main__":
    main()
