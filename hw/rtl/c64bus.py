from migen import C, Cat, If, Module, Signal, TSTriple, Replicate

class BusManager(Module):
    def _export_signal(self, pads, value, *names):
        for name in names:
            p = getattr(pads, name, None)
            if p is not None:
                self.comb += p.eq(value if len(value) != 1 or len(p) == 1
                                  else Replicate(value, len(p)))
            p = getattr(pads, name+"_n", None)
            if p is not None:
                self.comb += p.eq(~value if len(value) != 1 or len(p) == 1
                                  else Replicate(~value, len(p)))

    def _import_signal(self, pads, value, *names):
        signals = []
        for name in names:
            p = getattr(pads, name, None)
            if p is not None:
                signals.append(p)
            p = getattr(pads, name+"_n", None)
            if p is not None:
                signals.append(~p)
        if signals:
            signals = [s if len(s) == 1 else s != 0 for s in signals]
            signal = signals[0]
            for i in range(1,len(signals)):
                signal |= signals[i]
            self.comb += value.eq(signal)

    def __init__(self, expport, clockport=None):

        dma, rw_out_dma = Signal(), Signal(reset=1)
        a_dir_dma, a_en_dma, a_oe_dma = Signal(), Signal(reset=1), Signal()
        d_dir_dma, d_en_dma, d_oe_dma = Signal(), Signal(), Signal()

        # Address and data bus

        a_pads = expport.a
        a_t = TSTriple(len(a_pads))
        self.specials += a_t.get_tristate(a_pads)
        a_d, a_q, a_oe = a_t.i, a_t.o, a_t.oe
        self.a = a_d
        
        d_pads = expport.d
        d_t = TSTriple(len(d_pads))
        self.specials += d_t.get_tristate(d_pads)
        d_d, d_q, d_oe = d_t.i, d_t.o, d_t.oe
        self.d = d_d

        a_en = Signal(reset=1)
        self._export_signal(expport, a_en, "a_en")
        a_dir = Signal()
        self._export_signal(expport, a_dir, "a_dir")

        d_en = Signal()
        self._export_signal(expport, d_en, "d_en")
        d_dir = Signal()
        self._export_signal(expport, d_dir, "d_dir")

        # Clockport

        self.clockport_active = Signal()
        clockport_read = Signal()
        clockport_write = Signal()
        if clockport is not None:
            self._export_signal(clockport, clockport_read, "iord")
            self._export_signal(clockport, clockport_write, "iowr")

        # Bus control

        rw_in = expport.rw_in if hasattr(expport, "rw_in") else C(1)
        self._export_signal(expport, rw_out_dma, "rw_out")

        io12 = Signal()
        self._import_signal(expport, io12, "io1", "io2", "io12")
        romlh = Signal()
        self._import_signal(expport, romlh, "roml", "romh", "romlh")

        # Cartridge address mapping

        self.exrom = Signal()
        self._export_signal(expport, self.exrom, "exrom")
        self.game = Signal()
        self._export_signal(expport, self.game, "game")

        # Bus direction setup

        io12_filter = Signal(8)
        self.sync += io12_filter.eq(Cat(io12, io12_filter[:-1]))
        romlh_filter = Signal(2)
        self.sync += romlh_filter.eq(Cat(romlh, romlh_filter[:-1]))

        self.romdata = Signal(8)
        self.iodata = Signal(8)

        self.sync += If(romlh_filter == 0b11,
                        # External ROM access
                        d_dir.eq(1),
                        d_en.eq(1),
                        d_oe.eq(1),
                        If(rw_in, d_q.eq(self.romdata)),
                        a_dir.eq(0),
                        a_en.eq(1),
                        a_oe.eq(0),
                        If(dma,
                           a_dir.eq(a_dir_dma),
                           a_en.eq(a_en_dma),
                           a_oe.eq(a_oe_dma),
                           d_dir.eq(d_dir_dma),
                           d_en.eq(0)
                        )
                     ).Elif(io12_filter[:2] == 0b11,
                        # External IO access
                        If(self.clockport_active,
                           d_dir.eq(0),
                           d_en.eq(1),
                           d_oe.eq(0),
                           clockport_read.eq(rw_in),
                           clockport_write.eq(~rw_in),
                        ).Else(
                           d_dir.eq(rw_in),
                           d_en.eq(1),
                           d_oe.eq(rw_in)
                        ),
                        If(rw_in, d_q.eq(self.iodata)),
                        a_dir.eq(0),
                        a_en.eq(1),
                        a_oe.eq(0),
                        If(dma,
                           a_dir.eq(a_dir_dma),
                           a_en.eq(a_en_dma),
                           a_oe.eq(a_oe_dma),
                           d_dir.eq(d_dir_dma),
                           If(self.clockport_active,
                              d_en.eq(d_en_dma),
                              d_oe.eq(d_oe_dma)
                           ).Else(
                              d_en.eq(0),
                              d_oe.eq(1),
                           )
                        )
                     ).Else(
                        # Internal address access
                     	d_dir.eq(d_dir_dma),
                        d_en.eq(d_en_dma),
                        d_oe.eq(d_oe_dma),
                        a_dir.eq(a_dir_dma),
                        a_en.eq(a_en_dma),
                        a_oe.eq(a_oe_dma)
                     )

        # ROM and I/O

        self.rom_r_strobe = Signal()
        self.io_r_strobe = Signal()
        self.io_w_strobe = Signal()
        self.comb += [
            self.rom_r_strobe.eq(romlh_filter == 0b01),
            self.io_r_strobe.eq((rw_in == 1) & (io12_filter[:2] == 0b01) &
                                ~self.clockport_active),
            self.io_w_strobe.eq((rw_in == 0) & (io12_filter == 0b01111111) &
                                ~self.clockport_active)
        ]
