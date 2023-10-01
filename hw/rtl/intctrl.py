from functools import reduce
from litex.soc.interconnect.csr import AutoCSR, CSR, CSRStorage
from migen import If, Module, Signal
from operator import or_

class InterruptController(Module, AutoCSR):

    def __init__(self):
        self._irq_status = CSR(8)
        self._irq_enable = CSRStorage(8)
        self._nmi_enable = CSRStorage(8)
        self.irq_status = Signal(8)
        self.irq_clear = Signal(8)
        self.irq_out = Signal(reset_less=True)
        self.nmi_out = Signal(reset_less=True)

        self.reset = Signal()
        self.sync += [
            self.irq_out.eq(reduce(or_, self.irq_status &
                                   self._irq_enable.storage)),
            self.nmi_out.eq(reduce(or_, self.irq_status &
                                   self._nmi_enable.storage)),
            If(self.reset,
               self._irq_enable.storage.eq(0),
               self._nmi_enable.storage.eq(0))
        ]
        self.comb += [
            self._irq_status.w.eq(self.irq_status),
            If(self.reset,
               self.irq_clear.eq(0xff)
            ).Elif(self._irq_status.re,
                   self.irq_clear.eq(self._irq_status.r)
            ).Else(self.irq_clear.eq(0))
        ]
