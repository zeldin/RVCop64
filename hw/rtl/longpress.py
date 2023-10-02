from migen import If, Module, Signal

class LongPressDetect(Module):

    def __init__(self, button_in, delay):
        self.out = Signal(reset=0)
        counter = Signal(max=delay, reset=0)
        self.sync += If(~button_in,
                        self.out.eq(0),
                        counter.eq(0)
                     ).Elif(counter == delay,
                            self.out.eq(1)
                     ).Else(counter.eq(counter + 1))
