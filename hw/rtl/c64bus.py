from migen import C, Cat, DIR_M_TO_S, DIR_S_TO_M, FSM, If, Module
from migen import NextValue, NextState, Signal, TSTriple, Replicate

from litex.soc.interconnect.stream import Endpoint

from .clockrecovery import ClockRecovery
from .resetcontrol import ResetControl


dma_description = [
    ("we",     1, DIR_M_TO_S),
    ("addr",  16, DIR_M_TO_S),
    ("wdata",  8, DIR_M_TO_S),
    ("rdata",  8, DIR_S_TO_M),
]

snoop_description = [
    ("we",     1, DIR_M_TO_S),
    ("addr",  16, DIR_M_TO_S),
    ("data",   8, DIR_M_TO_S),
    ("dma",    1, DIR_M_TO_S),
]

class BusManager(Module):
    def _export_signal(self, pads, value, *names):
        r = False
        for name in names:
            p = getattr(pads, name, None)
            if p is not None:
                self.comb += p.eq(value if len(value) != 1 or len(p) == 1
                                  else Replicate(value, len(p)))
                r = True
            p = getattr(pads, name+"_n", None)
            if p is not None:
                self.comb += p.eq(~value if len(value) != 1 or len(p) == 1
                                  else Replicate(~value, len(p)))
                r = True
        return r

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
            return True
        return False

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

        # Reset

        reset_in = Signal()
        reset_out = Signal()
        self._import_signal(expport, reset_in, "reset_in")
        self._export_signal(expport, reset_out, "reset_out")
        self.submodules.reset_control = ResetControl(reset_in, reset_out)

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

        # IRQ

        self.irq_out = Signal()
        self._export_signal(expport, self.irq_out, "irq_out")
        self.nmi_out = Signal()
        self._export_signal(expport, self.nmi_out, "nmi_out")

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

        # Clock

        self.phi2_in = Signal()
        if not self._import_signal(expport, self.phi2_in, "phi2"):
            return
        self.submodules.clock_recovery = ClockRecovery(self.phi2_in)

        # DMA

        ba = Signal()
        if (not self._import_signal(expport, ba, "ba") or
            not self._export_signal(expport, dma, "dma_out")):
            return

        ba_filter = Signal(2)
        ba_counter = Signal(2)
        rw_in_log = Signal(2)
        self.sync += ba_filter.eq(Cat(ba, ba_filter[:-1]))
        ba_asserted = (ba_filter == 0b00)
        cpu_stopped_by_ba = (ba_counter == 0b11)
        read_follows_write = (rw_in_log == 0b01)
        can_request_dma = cpu_stopped_by_ba | read_follows_write

        self.ff00_w_strobe = Signal()

        self.dma_endpoint = Endpoint(dma_description)
        self.dma_alloc = Signal()

        self.snoop_endpoint = Endpoint(snoop_description)
        self.comb += [ self.snoop_endpoint.dma.eq(dma) ]

        dma_dummy_cycle = Signal()
        dma_delay = Signal(4)
        self.submodules.fsm = fsm = FSM(reset_state="RESET")
        fsm.act("RESET",
                NextValue(d_dir_dma, 0),
                NextValue(d_en_dma, 0),
                NextValue(d_oe_dma, 0),
                NextValue(a_dir_dma, 0),
                NextValue(a_en_dma, 1),
                NextValue(a_oe_dma, 0),
                NextValue(rw_out_dma, 1),
                NextValue(dma, 0),
                NextValue(dma_dummy_cycle, 0),
                If(self.clock_recovery.half.p1,
                   NextState("WAIT_PHASE0")))

        fsm.act("WAIT_PHASE0",
                If(~self.clock_recovery.phi2_out,
                   self.snoop_endpoint.valid.eq(~cpu_stopped_by_ba),
                   NextState("PHASE0_00")
                ).Elif(self.clock_recovery.full.m2,
                   NextValue(self.snoop_endpoint.addr, a_d),
                   NextValue(self.snoop_endpoint.data, d_d),
                   NextValue(self.snoop_endpoint.we, ~rw_in),
                   NextValue(d_en_dma, 0)))

        fsm.act("PHASE0_00",
                If((rw_in == 0b0) & (a_d == 0xff00),
                   NextValue(self.ff00_w_strobe, 1)),
                NextValue(rw_in_log, Cat(rw_in | dma, rw_in_log[:-1])),
                NextState("PHASE0_01"))

        fsm.act("PHASE0_01",
                NextValue(self.ff00_w_strobe, 0),
                NextState("PHASE0_02"))

        fsm.act("PHASE0_02",
                NextValue(d_en_dma, 0),
                NextValue(d_oe_dma, 0),
                NextValue(a_en_dma, 0),
                NextValue(a_oe_dma, 0),
                NextState("PHASE0_03")),

        fsm.act("PHASE0_03",
                NextValue(d_dir_dma, 0),
                NextValue(a_dir_dma, 0),
                NextValue(rw_out_dma, 1),
                NextValue(dma_delay, 15),
                NextState("DMA_SELECT")),

        fsm.act("DMA_SELECT",
                If(dma_delay != 0,
                   NextValue(dma_delay, dma_delay-1)
                ).Else(
                   If(~self.dma_endpoint.valid & ~self.dma_alloc,
                      NextValue(dma, 0)
                   ).Elif(can_request_dma,
                      NextValue(dma, 1)
                   ),
                   NextState("WAIT_PHASE1")
                ))

        fsm.act("WAIT_PHASE1",
                NextValue(a_en_dma, 1),
                If(self.clock_recovery.phi2_out,
                   NextState("PHASE1_00")))

        fsm.act("PHASE1_00",
                If(~ba_asserted,
                   NextValue(ba_counter, 0)
                ).Elif(~cpu_stopped_by_ba,
                   NextValue(ba_counter, ba_counter+1)
                ),
                If(dma & ~ba_asserted,
                   NextValue(a_en_dma, 0),
                   NextState("PHASE1_01")
                ).Else(
                   NextValue(d_en_dma, 1),
                   NextState("WAIT_PHASE0")
                ))

        fsm.act("PHASE1_01",
                If(self.dma_endpoint.valid,
                   NextValue(dma_dummy_cycle, 0),
                   NextValue(a_q, self.dma_endpoint.addr),
                   NextValue(d_q, self.dma_endpoint.wdata),
                   NextValue(d_dir_dma, self.dma_endpoint.we)
                ).Else(
                   NextValue(dma_dummy_cycle, 1),
                   # Read address 0
                   NextValue(a_q, 0)
                ),
                NextValue(a_dir_dma, 1),
                NextState("PHASE1_02"))

        fsm.act("PHASE1_02",
                NextValue(a_en_dma, 1),
                NextValue(a_oe_dma, 1),
                If(~dma_dummy_cycle,
                   NextValue(rw_out_dma, ~d_dir_dma)),
                NextState("PHASE1_03"))

        fsm.act("PHASE1_03",
                If(~rw_out_dma,
                   NextValue(d_oe_dma, 1)),
                NextState("PHASE1_04"))

        fsm.act("PHASE1_04",
                NextValue(d_en_dma, 1),
                NextState("WAIT_PHASE0_DMA"))

        fsm.act("WAIT_PHASE0_DMA",
                If(self.clock_recovery.phi2_out,
                   NextValue(self.dma_endpoint.rdata, d_d),
                   If(self.clock_recovery.full.m2,
                      NextValue(self.snoop_endpoint.addr, a_d),
                      NextValue(self.snoop_endpoint.data, d_d),
                      NextValue(self.snoop_endpoint.we, ~rw_in))
                ).Else(
                   If(~dma_dummy_cycle,
                      self.dma_endpoint.ready.eq(1)),
                   self.snoop_endpoint.valid.eq(1),
                   NextState("PHASE0_00")
                ))

class Wishbone2BusDMA(Module):
    def __init__(self, wishbone, ep, base_address=0x00000000):
        assert len(wishbone.dat_w) == len(ep.wdata)
        self.comb += [
            ep.we.eq(wishbone.we),
            ep.addr.eq((wishbone.adr - base_address)[:len(ep.addr)]),
            ep.wdata.eq(wishbone.dat_w),
            ep.valid.eq(wishbone.cyc & wishbone.stb),

            wishbone.dat_r.eq(ep.rdata),
            wishbone.ack.eq(ep.ready)
        ]
