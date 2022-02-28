from migen import Cat, If, Module, Signal


class ResetControl(Module):

    def __init__(self, reset_in, reset_out):
        deglitch_reset_in = Signal(3)
        self.reset_in = deglitch_reset_in[0]
        self.ext_reset = Signal()
        reset_counter = Signal(12, reset=0)
        self.sync += [
            deglitch_reset_in.eq(Cat(deglitch_reset_in[1:], reset_in)),
            If(self.ext_reset | (self.reset_in & ((~reset_counter) == 0)),
               reset_counter.eq(0)
            ).Elif((~reset_counter) != 0,
                   reset_counter.eq(reset_counter + 1))]
        self.comb += reset_out.eq(~reset_counter[-1])
