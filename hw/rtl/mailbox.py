from litex.soc.interconnect import wishbone
from migen import C, Case, If, Memory, Module, Replicate, Signal
from migen.fhdl.bitcontainer import log2_int
from migen.genlib.record import Record

from .ioregisters import Interface

class Mailbox(Module):

    def __init__(self, size=256):
        self.size = size
        self.mem = Memory(32, size//4)
        self.specials += self.mem
        port = self.mem.get_port(write_capable=True, async_read=True,
                                 we_granularity=8)
        self.specials += port
        self.iobus = Interface(log2_int(size))
        self.wb = wishbone.Interface(data_width=32, adr_width=len(port.adr))
        self.ev = Record([("irq", 1)])
        self.irq = Signal()
        self.irq_ext_clear = Signal()
        wb_irq_addr = ~C(0, len(self.iobus.adr))
        iobus_irq_addr = ~C(4, len(self.iobus.adr))
        wb_sel = Signal()
        iobus_irq_clear = Signal()
        wb_irq_trigger = Signal()

        self.comb += [
            If(self.iobus.r_strobe,
               port.adr.eq(self.iobus.adr[2:]),
               Case(self.iobus.adr[:2],
                    { 0: self.iobus.dat_r.eq(port.dat_r[0:8]),
                      1: self.iobus.dat_r.eq(port.dat_r[8:16]),
                      2: self.iobus.dat_r.eq(port.dat_r[16:24]),
                      3: self.iobus.dat_r.eq(port.dat_r[24:32]) }),
               If(self.iobus.adr == iobus_irq_addr, iobus_irq_clear.eq(1))
            ).Elif(self.iobus.w_strobe,
               port.adr.eq(self.iobus.adr[2:]),
               port.dat_w.eq(Replicate(self.iobus.dat_w, 4)),
               port.we.eq(1 << self.iobus.adr[:2]),
               If(self.iobus.adr == wb_irq_addr, wb_irq_trigger.eq(1))
            ).Else(
               port.adr.eq(self.wb.adr),
               If (self.wb.cyc & self.wb.stb,
                   wb_sel.eq(1),
                   If(self.wb.we,
                      port.dat_w.eq(self.wb.dat_w),
                      port.we.eq(self.wb.sel)))
            )
        ]
        self.sync += [
            If(iobus_irq_clear | self.irq_ext_clear, self.irq.eq(0)),
            If(wb_sel,
               self.wb.ack.eq(1),
               If(self.wb.we,
                  If((self.wb.adr == iobus_irq_addr[2:2+len(self.wb.adr)]) &
                     self.wb.sel[3],
                     self.irq.eq(1))
               ).Else(
                  self.wb.dat_r.eq(port.dat_r),
                  If(self.wb.adr == wb_irq_addr[2:2+len(self.wb.adr)],
                     self.ev.irq.eq(0)))
            ).Else(self.wb.ack.eq(0)),
            If(wb_irq_trigger, self.ev.irq.eq(1))
        ]

    def get_bus(self):
        return self.iobus
