#!/usr/bin/env python3
# This variable defines all the external programs that this module
# relies on.  lxbuildenv reads this variable in order to ensure
# the build will finish without exiting due to missing third-party
# programs.
LX_DEPENDENCIES = ["make", "riscv", "yosys", "nextpnr-ecp5"]

# Import lxbuildenv to integrate the deps/ directory
import lxbuildenv

from litex.soc.cores.cpu import CPUNone
from litex.soc.integration.soc_core import SoCCore, SoCRegion
from litex.soc.integration.builder import Builder
from litex.soc.interconnect import wishbone
from migen import Memory

from rtl.c64bus import BusManager

import argparse
import os

class BaseSoC(SoCCore):

    csr_map = {
        "ctrl":           0,
        "crg":            1,
        "uart_phy":       2,
        "uart":           3,
        "identifier_mem": 4,
        "timer0":         5,
    }

    SoCCore.mem_map = {
        "sram":             0x10000000,
        "main_ram":         0x40000000,
        "bios_rom":         0x70000000,
        "csr":              0xf0000000,
        "vexriscv_debug":   0xf00f0000,
    }
    
    def __init__(self, platform,
                 output_dir="build",
                 clk_freq=int(64e6),
                 **kwargs):

        self.output_dir = output_dir

        platform.add_crg(self, clk_freq)

        get_integrated_sram_size=getattr(platform, "get_integrated_sram_size",
                                         lambda: 0)
        SoCCore.__init__(self, platform, clk_freq,
                         cpu_reset_address=self.mem_map["bios_rom"],
                         integrated_sram_size=get_integrated_sram_size(),
                         csr_data_width=32, **kwargs)

        if hasattr(self, "cpu") and not isinstance(self.cpu, CPUNone):
            platform.add_cpu_variant(self)

        if hasattr(platform, "add_sram"):
            sram_size = platform.add_sram(self)
            self.register_mem("sram", self.mem_map["sram"], self.sram.bus, sram_size)

        if hasattr(platform, "add_mram"):
            mram_size, mram_slave = platform.add_mram(self)
            self.bus.add_region("main_ram", SoCRegion(origin=self.mem_map["main_ram"], size=mram_size))
            self.bus.add_slave("main_ram", mram_slave)

        self.integrated_rom_size = bios_size = 0x8000
        self.submodules.rom = wishbone.SRAM(bios_size, read_only=True, init=[])
        self.register_rom(self.rom.bus, bios_size)

        self.submodules.bus_manager = BusManager(
            platform.request("c64expansionport"),
            platform.request("clockport", loose=True))
        self.exrom = Memory(8, 8192)
        self.specials += self.exrom
        rdport = self.exrom.get_port()
        self.specials += rdport
        self.comb += [
            self.bus_manager.exrom.eq(1),
            self.bus_manager.romdata.eq(rdport.dat_r),
            rdport.adr.eq(self.bus_manager.a[:13])
        ]

    def build(self, *args, **kwargs):
        with open(os.path.join(self.output_dir,
                               "software/exrom/rom.bin"), "rb") as f:
            self.exrom.init = f.read()
        SoCCore.build(self, *args, **kwargs)

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

    # load our platform file
    platform = Platform(**platform_argdict(args))

    output_dir = 'build'
    sw_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "../sw"))

    cpu_type = "vexriscv"
    cpu_variant = "standard"

    soc = BaseSoC(platform, cpu_type=cpu_type, cpu_variant=cpu_variant,
                            clk_freq=int(float(args.sys_clk_freq)),
                            output_dir=output_dir)
    builder = Builder(soc, output_dir=output_dir,
                      csr_csv=os.path.join(output_dir, "csr.csv"),
                      csr_svd=os.path.join(output_dir, "soc.svd"),
                      compile_software=True, compile_gateware=True)
    builder.add_software_package("exrom", os.path.join(sw_dir, "exrom"))
    builder_kargs = { "abc9": True,
                      "seed": args.seed
                    } if args.toolchain == "trellis" else {}
    soc.do_exit(builder.build(**builder_kargs))
    platform.finalise(output_dir)


if __name__ == "__main__":
    main()
