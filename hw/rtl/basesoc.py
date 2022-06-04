import os

from litex.soc.cores.cpu import CPUNone
from litex.soc.integration.soc_core import SoCCore, SoCRegion
from litex.soc.interconnect import wishbone
from migen import Memory
from valentyusb.usbcore import io as usbio
from valentyusb.usbcore.cpu import eptri, simplehostusb

from .c64bus import BusManager, Wishbone2BusDMA
from .ioregisters import IORegisters
from .vuart import VUART
from .wbmaster import WBMaster
from .vexriscvdebug import VexRiscvDebug


class SoCIORegisters(IORegisters):

    csr_map = {
        "vuart0" : 0xde10,
        "wbmaster" : 0xde20,
        "vexriscv_debug" : 0xde30
    }

    def __init__(self):
        self.submodules.vuart0 = VUART(rx_fifo_depth = 1024)
        self.submodules.wbmaster = WBMaster()
        self.submodules.vexriscv_debug = VexRiscvDebug()
        IORegisters.__init__(self)


class BaseSoC(SoCCore):

    csr_map = {
        "ctrl":           0,
        "crg":            1,
        "uart":           2,
        "timer0":         3,
    }

    SoCCore.mem_map = {
        "c64":              0x00000000,
        "sram":             0x10000000,
        "main_ram":         0x40000000,
        "bios_rom":         0x70000000,
        "csr":              0xf0000000,
        "vexriscv_debug":   0xf00f0000,
    }
    
    def __init__(self, platform,
                 output_dir="build",
                 clk_freq=int(64e6),
                 usb=None,
                 **kwargs):

        self.output_dir = output_dir

        platform.add_crg(self, clk_freq, usb is not None)

        get_integrated_sram_size=getattr(platform, "get_integrated_sram_size",
                                         lambda: 0)
        SoCCore.__init__(self, platform, clk_freq, uart_name="stream",
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

        self.integrated_rom_size = bios_size = 0xc000
        self.submodules.rom = wishbone.SRAM(bios_size, read_only=True, init=[])
        self.register_rom(self.rom.bus, bios_size)

        self.submodules.bus_manager = BusManager(
            platform.request("c64expansionport"),
            platform.request("clockport", loose=True))
        # ROML
        self.exrom = Memory(8, 8192)
        self.specials += self.exrom
        rdport = self.exrom.get_port()
        self.specials += rdport
        self.comb += [
            self.bus_manager.exrom.eq(1),
            self.bus_manager.romdata.eq(rdport.dat_r),
            rdport.adr.eq(self.bus_manager.a[:13])
        ]
        # IO1/2
        self.submodules.ioregs = SoCIORegisters()
        self.comb += [
            self.bus_manager.iodata.eq(self.ioregs.bus.dat_r),
            self.ioregs.bus.dat_w.eq(self.bus_manager.d),
            self.ioregs.bus.adr.eq(self.bus_manager.a[:9]),
            self.ioregs.bus.r_strobe.eq(self.bus_manager.io_r_strobe),
            self.ioregs.bus.w_strobe.eq(self.bus_manager.io_w_strobe)
        ]
        # DMA
        c64dma_wb = wishbone.Interface(data_width=8)
        dma_region = SoCRegion(origin=self.mem_map.get("c64"), size=0x10000)
        self.submodules.c64dma_wb = Wishbone2BusDMA(c64dma_wb, self.bus_manager.dma_endpoint, base_address=dma_region.origin)
        self.bus.add_region("c64", dma_region)
        self.bus.add_slave("c64", c64dma_wb)
        # Connect VUART
        self.comb += self.ioregs.vuart0.source.connect(self.uart.sink)
        self.comb += self.uart.source.connect(self.ioregs.vuart0.sink)
        # Connect WBMaster
        self.bus.add_master(name="c64wbmaster", master=self.ioregs.wbmaster.wishbone)
        # Debug
        self.bus.regions.pop("vexriscv_debug", None)
        debug_slave = self.bus.slaves.pop("vexriscv_debug", None)
        if debug_slave is not None:
            self.comb += self.ioregs.vexriscv_debug.wishbone.connect(debug_slave)
        # Reset button
        usr_btn = platform.request("usr_btn", loose=True)
        if usr_btn is not None:
            self.comb += self.bus_manager.reset_control.ext_reset.eq(~usr_btn)

        # SDCard
        self.add_spi_sdcard()

        # USB
        if usb is not None:
            usb_pads = platform.request("usb")
            usb_iobuf = usbio.IoBuf(usb_pads.d_p, usb_pads.d_n, usb_pads.pullup)
            if usb == "eptri":
                self.submodules.usb = eptri.TriEndpointInterface(usb_iobuf, cdc=True)
            elif usb == "simplehostusb":
                self.submodules.usb = simplehostusb.SimpleHostUsb(usb_iobuf, cdc=True)
            else:
                raise ValueError("Unknown usb implementation " + usb)
            if self.irq.enabled:
                self.irq.add('usb')

    def build(self, *args, **kwargs):
        with open(os.path.join(self.output_dir,
                               "software/exrom/rom.bin"), "rb") as f:
            self.exrom.init = f.read()
        SoCCore.build(self, *args, **kwargs)

