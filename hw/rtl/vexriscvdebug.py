from litex.soc.interconnect.csr import AutoCSR, CSRAccess, CSRField
from litex.soc.interconnect import wishbone
from migen import If, Module, Mux, Signal
from .csrextra import CSRStatusAndControl

class VexRiscvDebug(Module, AutoCSR):

    def __init__(self):
        self.live_csr_data = True
        self.wishbone = wishbone.Interface(data_width=32, adr_width=1)
        self._status_control = CSRStatusAndControl(fields=[
            CSRField("reset_it", 1, access=CSRAccess.ReadOnly),
            CSRField("halt_it", 1, access=CSRAccess.ReadOnly),
            CSRField("is_pip_busy", 1, access=CSRAccess.ReadOnly),
            CSRField("halted_by_break", 1, access=CSRAccess.ReadOnly),
            CSRField("step_it", 1),
            CSRField("set_reset_it", 1, offset=16, access=CSRAccess.WriteOnly, pulse=True),
            CSRField("set_halt_it", 1, access=CSRAccess.WriteOnly, pulse=True),
            CSRField("clear_reset_it", 1, offset=24, access=CSRAccess.WriteOnly, pulse=True),
            CSRField("clear_halts", 1, access=CSRAccess.WriteOnly, pulse=True)])
        self._reg_instr = CSRStatusAndControl(fields=[
            CSRField("reg_value", 32, access=CSRAccess.ReadOnly),
            CSRField("instr", 32, access=CSRAccess.WriteOnly)])

        cmd = Signal(32)

        self.comb += [
            self.wishbone.dat_w.eq(Mux(self.wishbone.adr[0],
                                       self._reg_instr.fields.instr, cmd)),
            cmd[4].eq(self._status_control.fields.step_it)
        ]

        self.sync += \
            If(self.wishbone.cyc,
               If (self.wishbone.ack,
                   # Wishbone cycle complete
                   If(~self.wishbone.adr[0] & ~self.wishbone.we,
                      # Read address 0 complete
                      self._status_control.fields.reset_it.eq(self.wishbone.dat_r[0]),
                      self._status_control.fields.halt_it.eq(self.wishbone.dat_r[1]),
                      self._status_control.fields.is_pip_busy.eq(self.wishbone.dat_r[2]),
                      self._status_control.fields.halted_by_break.eq(self.wishbone.dat_r[3]),
                      self._status_control.fields.step_it.eq(self.wishbone.dat_r[4])
                    ).Elif(self.wishbone.adr[0] & ~self.wishbone.we,
                           # Read address 4 complete
                           self._reg_instr.fields.reg_value.eq(self.wishbone.dat_r)),
                   self.wishbone.stb.eq(0),
                   self.wishbone.cyc.eq(0))
            ).Else(
                If(self._status_control.fields.step_it.re |
                   self._status_control.fields.set_reset_it |
                   self._status_control.fields.set_halt_it |
                   self._status_control.fields.clear_reset_it |
                   self._status_control.fields.clear_halts,
                   # Write address 0
                   cmd[16].eq(self._status_control.fields.set_reset_it),
                   cmd[17].eq(self._status_control.fields.set_halt_it),
                   cmd[24].eq(self._status_control.fields.clear_reset_it),
                   cmd[25].eq(self._status_control.fields.clear_halts),
                   self.wishbone.adr.eq(0),
                   self.wishbone.we.eq(1),
                   self.wishbone.stb.eq(1),
                   self.wishbone.cyc.eq(1)),
                If(self._reg_instr.re[-1],
                   # Write address 4
                   self.wishbone.adr.eq(1),
                   self.wishbone.we.eq(1),
                   self.wishbone.stb.eq(1),
                   self.wishbone.cyc.eq(1)),
                If(self._status_control.we[0],
                   # Read address 0
                   self.wishbone.adr.eq(0),
                   self.wishbone.we.eq(0),
                   self.wishbone.stb.eq(1),
                   self.wishbone.cyc.eq(1)),
                If(self._reg_instr.we[0],
                   # Read address 4
                   self.wishbone.adr.eq(1),
                   self.wishbone.we.eq(0),
                   self.wishbone.stb.eq(1),
                   self.wishbone.cyc.eq(1))
            )
