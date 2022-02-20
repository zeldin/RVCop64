from litex.soc.interconnect.csr import AutoCSR, CSR, CSRAccess, CSRField, CSRStorage
from litex.soc.interconnect import wishbone
from migen import If, Module, Signal
from .csrextra import CSRStatusAndControl

class WBMaster(Module, AutoCSR):

    def __init__(self):
        self.wishbone = wishbone.Interface(data_width=8, adr_width=32)
        self._addr = CSRStorage(32, write_from_dev=True)
        self._data = CSR(8)
        self._status_control = CSRStatusAndControl(fields=[
            CSRField("write_on_wdata", 1),
            CSRField("inc_on_wdata", 1),
            CSRField("read_on_rdata", 1),
            CSRField("inc_on_rdata", 1),
            CSRField("read_on_waddr", 1),
            CSRField("inc_on_waddr", 1),
            CSRField("read_now", 1, access=CSRAccess.WriteOnly, pulse=True),
            CSRField("inc_now", 1, access=CSRAccess.WriteOnly, pulse=True),
            CSRField("error", 1, access=CSRAccess.ReadOnly),
            CSRField("busy", 1, access=CSRAccess.ReadOnly)])

        self.comb += [
            self._addr.dat_w.eq(self._addr.storage + 1),
            self._addr.we.eq(
                self._status_control.fields.inc_now |
                (self._status_control.fields.inc_on_waddr & self._addr.re) |
                (self._status_control.fields.inc_on_rdata & self._data.we) |
                (self._status_control.fields.inc_on_wdata & self._data.re))]

        start_read = Signal()
        self.comb += start_read.eq(
                self._status_control.fields.read_now |
                (self._status_control.fields.read_on_waddr & self._addr.re) |
                (self._status_control.fields.read_on_rdata & self._data.we))

        start_write = Signal()
        self.comb += start_write.eq(
                self._status_control.fields.write_on_wdata & self._data.re)

        data = Signal(8)
        self.comb += self._data.w.eq(data)
        self.sync += If(self._data.re, data.eq(self._data.r)
                ).Elif(self.wishbone.cyc & self.wishbone.ack &
                         ~self.wishbone.we, data.eq(self.wishbone.dat_r))

        self.sync += If(self.wishbone.cyc,
                        If(self.wishbone.ack | self.wishbone.err,
                           self.wishbone.cyc.eq(0),
                           self.wishbone.stb.eq(0),
                           self._status_control.fields.error.eq(self.wishbone.err))
                    ).Elif(start_read | start_write,
                        self.wishbone.adr.eq(self._addr.storage),
                        self.wishbone.we.eq(start_write),
                        self.wishbone.cyc.eq(1),
                        self.wishbone.stb.eq(1))
        self.comb += [
            self.wishbone.dat_w.eq(data),
            self.wishbone.sel.eq(1)]

        self.comb += self._status_control.fields.busy.eq(self.wishbone.cyc)
