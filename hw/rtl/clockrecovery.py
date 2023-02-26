from migen import Cat, If, Module, Mux, Record, Signal

_edge_layout = [
    ("m2", 1),
    ("m1", 1),
    ("p0", 1),
    ("p1", 1)
]

class Phi2In(Module):
    def __init__(self, phi2_in, cntbits=8):
        shiftreg = Signal(8)
        popcount = Signal(3)
        deglitched = Signal(1)
        self.edge = Signal()
        self.cnt = Signal(cntbits)
        self.lost = Signal()
        self.sync += [
            shiftreg.eq(Cat(phi2_in, shiftreg[:-1])),
            If(shiftreg[0] & ~shiftreg[-1],
               popcount.eq(popcount+1)
            ).Elif(shiftreg[-1] & ~shiftreg[0],
               popcount.eq(popcount-1)
            ),
            If((popcount[1:] == 3) & ~deglitched,
               deglitched.eq(1)),
            If((popcount[1:] == 0) & deglitched,
               deglitched.eq(0),
               self.edge.eq(1)
            ).Else(
               self.edge.eq(0)
            ),
            If(self.edge,
               self.cnt.eq(0),
               self.lost.eq(0),
            ).Elif(self.cnt == 0xff,
               self.lost.eq(1)
            ).Else(
               self.cnt.eq(self.cnt+1)
            )
        ]

class NCO(Module):
    def __init__(self, bits, guard_bits):
        self.divider = Signal(bits)
        frac_divider = Signal(guard_bits)
        new_divider = Signal(bits + guard_bits)
        self.div_adjust = Signal((bits+1, True))
        self.cnt = Signal(bits)
        frac_cnt = Signal(guard_bits)
        new_frac = Signal(guard_bits+1)
        self.align = Signal()
        self.align_target = Signal(bits)
        self.comb += [
            new_divider.eq(Cat(frac_divider, self.divider) + self.div_adjust),
            new_frac.eq(Cat(frac_cnt, 0) + Cat(~frac_divider, 0))
        ]
        self.sync += [
            self.divider.eq(new_divider[guard_bits:]),
            frac_divider.eq(new_divider[:guard_bits]),
            If(self.align,
               frac_cnt.eq(new_frac[:guard_bits]),
               self.cnt.eq(self.align_target + new_frac[-1])
            ).Elif(self.cnt >= self.divider,
               self.cnt.eq(0)
            ).Else(
               self.cnt.eq(self.cnt+1)
            )
        ]

class ClockRecovery(Module):

    def __init__(self, phi2_in, phase_shift=17, guard_bits=4): # phase_shift=10 original
        self.phi2_out = Signal()
        self.phi2_out_lock = Signal()
        self.full = Record(_edge_layout)
        self.half = Record(_edge_layout)

        self.submodules.phi2in = Phi2In(phi2_in)
        self.submodules.nco = NCO(len(self.phi2in.cnt), guard_bits)

        self.comb += [
            self.nco.align.eq(self.full.m1),
            self.nco.align_target.eq(self.phi2in.cnt)
        ]

        shifted_cnt = self.nco.cnt + phase_shift
        self.sync += [
            self.nco.div_adjust.eq(Mux(self.phi2in.edge,
                                       self.phi2in.cnt - self.nco.divider, 0)),
            self.half.m2.eq(Mux(shifted_cnt == Cat(self.nco.divider[1:], 0),
                                1, 0)),
            self.half.m1.eq(self.half.m2),
            self.half.p0.eq(self.half.m1),
            self.half.p1.eq(self.half.p0),
            self.full.m2.eq(Mux(shifted_cnt == self.nco.divider, 1, 0)),
            self.full.m1.eq(self.full.m2),
            self.full.p0.eq(self.full.m1),
            self.full.p1.eq(self.full.p0),
            If(self.full.m1,
               self.phi2_out.eq(0)
            ).Elif(self.half.m1,
               self.phi2_out.eq(1)
            )
        ]

        lock_cnt = Signal(4)
        self.sync += If(self.phi2in.lost,
                        lock_cnt.eq(0)
                     ).Elif((self.nco.div_adjust[2:] != 0) &
                        ((~self.nco.div_adjust[2:]) != 0),
                        If(lock_cnt != 0, lock_cnt.eq(lock_cnt-1))
                     ).Elif(self.phi2in.edge,
                        If(lock_cnt != (1<<lock_cnt.nbits)-1,
                           lock_cnt.eq(lock_cnt+1))
                     )
        self.comb += self.phi2_out_lock.eq(lock_cnt[-1])
