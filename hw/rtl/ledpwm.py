from migen import If, Module, Signal
from litex.soc.interconnect.csr import AutoCSR, CSRStorage, CSRField

class LEDPWM(Module, AutoCSR):
    def __init__(self, pads, sys_clk_freq, reset_on="", reset_bright=100):
        self.out = CSRStorage(fields=[
            CSRField(pad[0], size=8,
                     reset=reset_bright if pad[0] in reset_on else 0)
            for pad in reversed(pads.layout)])

        divider = int(sys_clk_freq * 5e-6) # counter increments every 5 us
        div_counter = Signal(max=divider)  # giving a period of 1.28 ms
        counter = Signal(8)

        self.sync += If(div_counter == divider-1,
                        counter.eq(counter+1),
                        div_counter.eq(0)
                     ).Else(div_counter.eq(div_counter+1))

        self.sync += [
            getattr(pads, pad[0]).eq(counter >= getattr(self.out.fields, pad[0]))
            for pad in pads.layout]
