from migen import Module, Signal, ClockDomain, If, TSTriple

from litex.soc.cores.bitbang import I2CMaster
from litex.soc.cores.clock import ECP5PLL
from litex.soc.interconnect.wishbone import SRAM, Interface

from litehyperram.core import LiteHyperRAMCore
from litehyperram.frontend.wishbone import LiteHyperRAMWishbone2Native
from litehyperram.modules import S27KS0641DP, S70KS1281DP
from litehyperram.phy import ECP5HYPERRAMPHY2x

from litex.build.generic_platform import *

import os

from litex_boards.platforms import orangecart

available_hyperram_modules = {
    "S27KS0641DP": S27KS0641DP,
    "S70KS1281DP": S70KS1281DP
}

def add_platform_args(parser):
    parser.add_argument("--revision", default="1.0", choices=["1.0", "1.2"],
                        help="Board Revision (default=1.0)")
    parser.add_argument(
        "--device", choices=["25F", "45F", "85F"], default="25F",
        help="Select device density"
    )
    parser.add_argument(
        "--hyperram-device", default="S70KS1281DP",
        help="HyperRAM device (default=S70KS1281DP)"
    )
    parser.add_argument(
        "--pmod", default=None, choices=["spi", "serial", "i2c", "i2s"]
    )
    parser.add_argument(
        "--pmod2", default=None, choices=["gpio", "xgpio", "spi", "xspi"]
    )
    parser.add_argument(
        "--toolchain", default="trellis",
        help="Gateware toolchain to use, trellis (default) or diamond"
    )

def platform_argdict(args):
    return {
        "revision":         args.revision,
        "device":           args.device,
        "hyperram_device":  args.hyperram_device,
        "pmod":             args.pmod,
        "pmod2":            args.pmod2,
        "toolchain":        args.toolchain,
    }


class Platform(orangecart.Platform):
    def __init__(self, revision="1.0", device="25F", hyperram_device="S70KS1281DP", pmod=None, pmod2=None, toolchain="trellis"):
        self.revision = revision
        self.device = device
        self.hw_platform = "orangecart"
        self.hyperram_device = hyperram_device
        self.hyperram_module = available_hyperram_modules.get(hyperram_device)
        self.pmod = pmod
        self.pmod2 = pmod2
        orangecart.Platform.__init__(self, device=device, revision=revision, toolchain=toolchain)

    def add_crg(self, soc, sys_clk_freq, with_usb=False):
        soc.submodules.crg = _CRG(self, sys_clk_freq, with_usb)

    def add_cpu_variant(self, soc, debug=False):
        pass

    def add_sram(self, soc):
        sram_size = 16*1024
        soc.submodules.sram = SRAM(sram_size)
        return sram_size

    def add_mram(self, soc):
        soc.submodules.hyperram = hyperram = _HyperRAM(
            self, self.request("hyperram"), soc.sys_clk_freq,
            self.hyperram_module(), soc.mem_map["main_ram"])
        return hyperram.size, hyperram.slave

    def add_self_reset(self, soc):
        rst = Signal()
        ts = TSTriple()
        soc.specials += ts.get_tristate(self.request("rst_n"))
        soc.comb += [
            ts.o.eq(0),
            ts.oe.eq(rst)
        ]
        return rst

    def add_expansions(self, soc):
        if self.pmod == 'spi':
            self.add_extension(orangecart.pmod_spi)
        elif self.pmod == 'serial':
            self.add_extension(orangecart.pmod_serial)
        elif self.pmod == 'i2c':
            self.add_extension(orangecart.pmod_i2c)
            soc.submodules.i2c = I2CMaster(self.request("i2c"))
        elif self.pmod == 'i2s':
            self.add_extension(orangecart.pmod_i2s)
        if self.pmod2 is None:
            pass
        elif self.revision == "1.0":
            raise ValueError("pmod2 not present on revision {}".format(self.revision))
        elif self.pmod2 == 'gpio':
            self.add_extension(orangecart.pmod2_gpio)
        elif self.pmod2 == 'xgpio':
            self.add_extension(orangecart.pmod2_xgpio)
        elif self.pmod2 == 'spi':
            self.add_extension(orangecart.pmod2_spi)
        elif self.pmod2 == 'xspi':
            self.add_extension(orangecart.pmod2_xspi)
        if self.revision != "1.0":
            tusb = self.request("tusb320")
            soc.submodules.tusb320_i2c = I2CMaster(tusb)
            if soc.irq.enabled:
                soc.submodules.tusb320 = Module()
                soc.tusb320.ev = Record([("irq", 1)])
                soc.comb += soc.tusb320.ev.irq.eq(~tusb.int_n)
                soc.irq.add("tusb320", use_loc_if_exists=True)

    def finalise(self, output_dir):
        input_config = os.path.join(output_dir, "gateware", f"{self.name}.config")
        output_bitstream = os.path.join(output_dir, "gateware", f"{self.name}.bit")
        spi_mode = '--spimode qspi --freq 38.8'
        os.system(f"ecppack {spi_mode} --compress --input {input_config} --bit {output_bitstream}")


class _CRG(Module):
    def __init__(self, platform, sys_clk_freq, with_usb):
        clk48_raw = platform.request("clk48")

        self.clock_domains.cd_por = ClockDomain(reset_less=True)
        self.clock_domains.cd_sys = ClockDomain()
        self.clock_domains.cd_sys2x = ClockDomain()
        self.clock_domains.cd_sys2x_90 = ClockDomain()
        platform.add_period_constraint(self.cd_sys.clk, 1e9/sys_clk_freq)
        platform.add_period_constraint(self.cd_sys2x.clk, 1e9/(sys_clk_freq*2))
        platform.add_period_constraint(self.cd_sys2x_90.clk, 1e9/(sys_clk_freq*2))
        if with_usb:
            self.clock_domains.cd_usb_12 = ClockDomain()
            self.clock_domains.cd_usb_48 = ClockDomain()
            platform.add_period_constraint(self.cd_usb_48.clk, 1e9/48e6)
            platform.add_period_constraint(self.cd_usb_12.clk, 1e9/12e6)

        por_count = Signal(16, reset=2**16-1)
        por_done  = Signal()
        self.comb += self.cd_por.clk.eq(clk48_raw)
        self.comb += por_done.eq(por_count == 0)
        self.sync.por += If(~por_done, por_count.eq(por_count - 1))

        self.submodules.pll = pll = ECP5PLL(bel="X70/Y49/EHXPLL_LR")
        self.comb += pll.reset.eq(~por_done)
        pll.register_clkin(clk48_raw, 48e6)
        pll.create_clkout(self.cd_sys, sys_clk_freq, margin = 0)
        pll.create_clkout(self.cd_sys2x, 2*sys_clk_freq, margin = 0)
        pll.create_clkout(self.cd_sys2x_90, 2*sys_clk_freq, margin = 0, phase = 195)

        if with_usb:
            self.submodules.pll2 = pll2 = ECP5PLL()
            self.comb += pll2.reset.eq(~por_done)
            pll2.register_clkin(clk48_raw, 48e6)
            pll2.create_clkout(self.cd_usb_48, 48e6, 0, with_reset=False)
            pll2.create_clkout(self.cd_usb_12, 12e6, 0, with_reset=False)

class _HyperRAM(Module):
    def __init__(self, platform, pins, clk_freq, hypermodule, base_address):
        self.submodules.hyperphy = ECP5HYPERRAMPHY2x(pins)
        self.submodules.hyperram = LiteHyperRAMCore(
                phy      = self.hyperphy,
                module   = hypermodule,
                clk_freq = clk_freq)
        port = self.hyperram.get_port()
        self.size = port.data_width >> 3 << port.address_width
        self.slave = wb_hyperram = Interface()
        self.submodules.wishbone_bridge = LiteHyperRAMWishbone2Native(
                wishbone = wb_hyperram,
                port     = port,
                base_address = base_address)

    def get_csrs(self):
        return self.hyperram.get_csrs()
