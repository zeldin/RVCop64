from migen import If, Module, Signal
from migen.genlib.record import DIR_M_TO_S, DIR_S_TO_M, Record
from migen.util.misc import xdir

from litex.soc.interconnect.csr import GenericBank

_layout = [
    ("adr",      9, DIR_M_TO_S),
    ("w_strobe", 1, DIR_M_TO_S),
    ("r_strobe", 1, DIR_M_TO_S),
    ("dat_w",    8, DIR_M_TO_S),
    ("dat_r",    8, DIR_S_TO_M)
]

class Interface(Record):
    def __init__(self):
        Record.__init__(self, _layout)
        self.adr.reset_less = True
        self.dat_w.reset_less = True
        self.dat_r.reset_less = True

class CSRBank(GenericBank):
    def __init__(self, description, address=0, bus=None, live_data=False):
        if bus is None:
            bus = Interface()
        self.bus = bus
        GenericBank.__init__(self,
            description = description,
            busword     = len(self.bus.dat_w),
            ordering    = "little"
        )                            
        for i, c in enumerate(self.simple_csrs):
            sel = Signal()
            self.comb += [
                sel.eq(self.bus.adr ==
                       ((address + i) & ((1<<len(self.bus.adr)) - 1))),
                c.r.eq(self.bus.dat_w[:c.size]),
                If(sel & self.bus.w_strobe, c.re.eq(1)),
                If(sel & self.bus.r_strobe, c.we.eq(1))
            ]
            self.sync += If(sel & (live_data | self.bus.r_strobe), self.bus.dat_r.eq(c.w))

class IORegisters(Module):

    csr_map = {}

    def __init__(self):
        self.bus = Interface()
        self.sync += If(self.bus.r_strobe, self.bus.dat_r.eq(0))
        self.scan(self)

    def address_map(self, name, memory):
        if memory is not None:
            name = name + "_" + memory.name_override
        return self.csr_map[name]

    def scan(self, source):
        brcases = {}
        for name, obj in xdir(source, True):
            if not hasattr(obj, "get_csrs"):
                continue
            csrs = obj.get_csrs()
            if csrs:
                mapaddr = self.address_map(name, None)
                if mapaddr is None:
                    continue
                self.submodules += CSRBank(csrs, mapaddr, self.bus,
					   getattr(obj, "live_csr_data", False))
