#!/usr/bin/env python3
# This variable defines all the external programs that this module
# relies on.  lxbuildenv reads this variable in order to ensure
# the build will finish without exiting due to missing third-party
# programs.
LX_DEPENDENCIES = ["make", "meson", "riscv", "yosys", "nextpnr-ecp5"]

# Import lxbuildenv to integrate the deps/ directory
import lxbuildenv

import argparse
import os

from litex.soc.integration.builder import Builder

from rtl.basesoc import BaseSoC


def main():
    parser = argparse.ArgumentParser(
        description="Build RISC-V coprocessor cartridge")
    parser.add_argument(
        "--platform", choices=["orangecart"], required=True,
        help="build for a particular hardware"
    )
    parser.add_argument(
        "--sys-clk-freq", default=64e6,
        help="System clock frequency (default=64MHz)"
    )
    uart_action = parser.add_argument(
        "--uart", default=None, choices=["serial", "usb_acm"],
        help="Connect main UART to pins or USB, instead of to VUART"
    )
    parser.add_argument(
        "--usb", default=None, choices=["eptri", "simplehostusb", "debug"],
        help="Include USB functionality"
    )
    parser.add_argument(
        "--seed", type=int, default=1, help="seed to use in nextpnr"
    )
    args, _ = parser.parse_known_args()

    # Select platform based arguments
    if args.platform == "orangecart":
        from rtl.platform.orangecart import Platform, add_platform_args, platform_argdict

    # Add any platform dependent args
    add_platform_args(parser)
    args = parser.parse_args()

    # Check for invalid combinations
    if args.uart == "usb_acm" and args.usb is not None:
        parser.error(str(argparse.ArgumentError(uart_action, "invalid choice: 'usb_acm' can not be used together with --usb")))

    # load our platform file
    platform = Platform(**platform_argdict(args))

    output_dir = 'build'
    sw_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "../sw"))

    cpu_type = "vexriscv"
    cpu_variant = "standard+debug"

    soc = BaseSoC(platform, cpu_type=cpu_type, cpu_variant=cpu_variant,
                  uart_name="stream" if args.uart is None else args.uart,
                  usb=args.usb, clk_freq=int(float(args.sys_clk_freq)),
                  output_dir=output_dir)
    builder = Builder(soc, output_dir=output_dir,
                      csr_csv=os.path.join(output_dir, "csr.csv"),
                      csr_svd=os.path.join(output_dir, "soc.svd"),
                      compile_software=True, compile_gateware=True)
    builder.add_software_package("exrom", os.path.join(sw_dir, "exrom"))
    builder_kargs = { "abc9": True,
                      "seed": args.seed
                    } if args.toolchain == "trellis" else {}
    builder.build(**builder_kargs)
    platform.finalise(output_dir)


if __name__ == "__main__":
    main()
