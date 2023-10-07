import os

from litex.soc.cores.cpu import CPUNone
from litex.soc.integration.soc_core import SoCCore, SoCRegion
from litex.soc.interconnect import wishbone
from migen import Memory
from valentyusb.usbcore import io as usbio
from valentyusb.usbcore.cpu import eptri, simplehostusb, dummyusb

from .c64bus import BusManager, Wishbone2BusDMA
from .ioregisters import IORegisters
from .vuart import VUART
from .wbmaster import WBMaster
from .vexriscvdebug import VexRiscvDebug
from .intctrl import InterruptController
from .mailbox import Mailbox
from .ledpwm import LEDPWM
from .modesnooper import ModeSnooper
from .longpress import LongPressDetect


class SoCIORegisters(IORegisters):

    csr_map = {
        "vuart0" : 0xde10,
        "wbmaster" : 0xde20,
        "vexriscv_debug" : 0xde30,
        "intctrl" : 0xde40,
        "mailbox" : 0xdec0
    }

    def __init__(self):
        self.submodules.vuart0 = VUART(rx_fifo_depth = 1024)
        self.submodules.wbmaster = WBMaster()
        self.submodules.vexriscv_debug = VexRiscvDebug()
        self.submodules.intctrl = InterruptController()
        self.submodules.mailbox = Mailbox(64)
        IORegisters.__init__(self)
        self.comb += [
            self.intctrl.irq_status[0].eq(self.mailbox.irq),
            self.mailbox.irq_ext_clear.eq(self.intctrl.irq_clear[0])
        ]


class BaseSoC(SoCCore):

    csr_map = {
        "ctrl":           0,
        "crg":            1,
        "uart":           2,
        "timer0":         3,
        "leds":           4,
        "spisdcard":      5,
        "hyperram":       6,
        "usb":            7,
        "i2c":            8,
        "uart2":          9,
    }

    interrupt_map = {
        "uart":           0,
        "timer0":         1,
        "usb":            2,
        "uart2":          3,
        "mailbox":        4,
    }

    SoCCore.mem_map = {
        "c64":              0x00000000,
        "sram":             0x10000000,
        "main_ram":         0x40000000,
        "bios_rom":         0x70000000,
        "mailbox":          0xe0000000,
        "csr":              0xf0000000,
        "vexriscv_debug":   0xf00f0000,
    }
    
    def __init__(self, platform,
                 output_dir="build",
                 clk_freq=int(64e6),
                 uart_name="stream", uart2_name=None,
                 usb=None, with_jtagbone=False,
                 with_uartbone=False, uartbone_baudrate=115200,
                 **kwargs):

        self.output_dir = output_dir

        platform.add_crg(self, clk_freq,
                         uart_name=='usb_acm' or uart2_name=='usb_acm' or
                         usb is not None)

        get_integrated_sram_size=getattr(platform, "get_integrated_sram_size",
                                         lambda: 0)
        SoCCore.__init__(self, platform, clk_freq, uart_name=uart_name,
                         cpu_reset_address=self.mem_map["bios_rom"],
                         integrated_sram_size=get_integrated_sram_size(),
                         csr_data_width=32, timer_uptime=True, **kwargs)

        if uart2_name:
            self.add_uart("uart2", uart_name=uart2_name)

        if hasattr(self, "cpu") and not isinstance(self.cpu, CPUNone):
            platform.add_cpu_variant(self)

        if hasattr(platform, "add_sram"):
            sram_size = platform.add_sram(self)
            self.bus.add_slave("sram", self.sram.bus,
                               SoCRegion(self.mem_map["sram"], sram_size))

        if hasattr(platform, "add_mram"):
            mram_size, mram_slave = platform.add_mram(self)
            self.bus.add_slave("main_ram", mram_slave,
                               SoCRegion(origin=self.mem_map["main_ram"], size=mram_size))

        self.integrated_rom_size = bios_size = 0xc000
        self.submodules.rom = wishbone.SRAM(bios_size, read_only=True, init=[])
        self.bus.add_slave("rom", self.rom.bus,
                           SoCRegion(origin=self.cpu.reset_address,
                                     size=bios_size))

        self.submodules.bus_manager = BusManager(
            platform.request("c64expansionport"),
            platform.request("clockport", loose=True))
        self.submodules.mode_snooper = ModeSnooper(
            self.bus_manager.reset_control.reset_in,
            self.bus_manager.snoop_endpoint)

        # ROML
        self.exrom = Memory(8, 8192)
        self.specials += self.exrom
        rdport = self.exrom.get_port()
        self.specials += rdport
        self.comb += [
            self.bus_manager.exrom.eq(self.mode_snooper.c64_mode),
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
        self.bus.add_slave("c64", c64dma_wb, dma_region)
        # Connect VUART
        if uart_name == "stream":
            self.comb += self.ioregs.vuart0.source.connect(self.uart.sink)
            self.comb += self.uart.source.connect(self.ioregs.vuart0.sink)
        elif uart2_name == "stream":
            self.comb += self.ioregs.vuart0.source.connect(self.uart2.sink)
            self.comb += self.uart2.source.connect(self.ioregs.vuart0.sink)
        # Connect WBMaster
        self.bus.add_master(name="c64wbmaster", master=self.ioregs.wbmaster.wishbone)
        # Connect interrupt controller
        self.comb += [
            self.bus_manager.irq_out.eq(self.ioregs.intctrl.irq_out),
            self.bus_manager.nmi_out.eq(self.ioregs.intctrl.nmi_out),
            self.ioregs.intctrl.reset.eq(self.bus_manager.reset_control.reset_in)
        ]
        # Connect Mailbox
        self.mailbox = self.ioregs.mailbox
        mailbox_region = SoCRegion(origin=self.mem_map.get("mailbox"),
                                   size=self.mailbox.size,
                                   cached=False)
        self.bus.add_slave("mailbox", self.mailbox.wb, mailbox_region)
        if self.irq.enabled:
            self.irq.add("mailbox", use_loc_if_exists=True)
        # Debug
        self.bus.regions.pop("vexriscv_debug", None)
        debug_slave = self.bus.slaves.pop("vexriscv_debug", None)
        if debug_slave is not None:
            self.comb += self.ioregs.vexriscv_debug.wishbone.connect(debug_slave)
        # Reset button
        usr_btn = platform.request("usr_btn", loose=True)
        if usr_btn is not None:
            self.comb += self.bus_manager.reset_control.ext_reset.eq(~usr_btn)
            if hasattr(platform, "add_self_reset"):
                self_reset = platform.add_self_reset(self)
                self.submodules.longpress = LongPressDetect(~usr_btn,
                                                            self.sys_clk_freq)
                self.comb += self_reset.eq(self.longpress.out)

        # RGB LED
        rgb_led = platform.request("rgb_led", loose=True)
        if rgb_led is not None:
            self.submodules.leds = LEDPWM(rgb_led, self.sys_clk_freq,
                                          reset_on='g', reset_bright=50)

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
            elif usb == "debug":
                self.submodules.dummy_usb = dummyusb.DummyUsb(usb_iobuf, cdc=True, debug=True)
                self.bus.add_master(name="usbwishbonebridge", master=self.dummy_usb.debug_bridge.wishbone)
            else:
                raise ValueError("Unknown usb implementation " + usb)

        # Expansion
        if hasattr(platform, 'add_expansions'):
            platform.add_expansions(self)

        # JTAG/serial debug
        if with_jtagbone:
            self.add_jtagbone()
        if with_uartbone:
            self.add_uartbone(baudrate=uartbone_baudrate)


    def build(self, *args, **kwargs):
        with open(os.path.join(self.output_dir,
                               "software/exrom/rom.bin"), "rb") as f:
            self.exrom.init = f.read()
        return SoCCore.build(self, *args, **kwargs)

