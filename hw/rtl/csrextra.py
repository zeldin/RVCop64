from litex.soc.interconnect.csr import _CompoundCSR, CSR, CSRAccess, CSRFieldAggregate
from migen import If, Replicate, Signal


# CSRFieldAggregate which allows read-only and write-only fields to overlap

class CSRStatusAndControlFieldAggregate(CSRFieldAggregate):
    def __init__(self, fields):
        self.check_names(fields)
        # Order read fields
        self.check_ordering_overlap(field for field in fields
                                    if field.access != CSRAccess.WriteOnly)
        # Order write fields
        self.check_ordering_overlap(field for field in fields
                                    if field.access != CSRAccess.ReadOnly)
        self.fields = fields
        self.size = 0
        for field in fields:
            if field.access is None:
                field.access = CSRAccess.ReadWrite
            if field.access != CSRAccess.WriteOnly:
                assert not field.pulse
            if field.offset + field.size > self.size:
                self.size = field.offset + field.size
            setattr(self, field.name, field)

    def get_size(self):
        return self.size


# Variant of CSRStatus/CSRStorage which allows a mix of read-only, write-only
# and read-write fields

class CSRStatusAndControl(_CompoundCSR):
    def __init__(self, size=1, fields=[], name=None, description=None):
        if fields != []:
            self.fields = CSRStatusAndControlFieldAggregate(fields)
            size = self.fields.get_size()
        _CompoundCSR.__init__(self, size, name)
        self.description = description
        self.we = Signal(self.size)
        self.re = Signal(self.size)
        self.w = Signal(self.size)
        self.r = Signal(self.size)
        for field in fields:
            if field.access != CSRAccess.WriteOnly:
                self.comb += self.w[field.offset:field.offset + field.size].eq(getattr(self.fields, field.name))
                field.we = (self.re[field.offset:field.offset + field.size] != 0)
            if field.access != CSRAccess.ReadOnly:
                for bit in range(field.size):
                    field_assign = If(self.re[field.offset+bit],
                                      getattr(self.fields, field.name)[bit].eq(
                                          self.r[field.offset+bit]))
                    if field.pulse:
                        self.comb += field_assign
                    else:
                        self.sync += field_assign
                field.re = (self.re[field.offset:field.offset + field.size] != 0)

    def do_finalize(self, busword, ordering):
        nwords = (self.size + busword - 1)//busword
        for i in reversed(range(nwords)) if ordering == "big" else range(nwords):
            nbits = min(self.size - i*busword, busword)
            sc    = CSR(nbits, self.name + str(i) if nwords else self.name)
            self.simple_csrs.append(sc)
            lo = i*busword
            hi = lo+nbits
            self.comb += [
                sc.w.eq(self.w[lo:hi]),
                self.we[lo:hi].eq(Replicate(sc.we, nbits)),
                self.r[lo:hi].eq(sc.r),
                self.re[lo:hi].eq(Replicate(sc.re, nbits))]
