from migen import Case, If, Module, Signal

class ModeSnooper(Module):

    def __init__(self, reset_in, snoop_ep):
        self.c64_mode = Signal()
        self.c128_mode = Signal()
        mmu_visible = Signal()
        preconfig = Signal(4)
        
        self.sync += [
            If(reset_in,
               # Reset is only way out of C64 mode
               self.c64_mode.eq(0),
               self.c128_mode.eq(0),
               mmu_visible.eq(0),
               preconfig.eq(0)
            ).Elif(~self.c64_mode & snoop_ep.valid & ~snoop_ep.dma & snoop_ep.we,
                   # Write cycle in (possibly) C128 mode
                   If(snoop_ep.addr == 0xff00,
                      # C128 mode confirmed
                      self.c128_mode.eq(1),
                      # Check if MMU exposed at $D5xx
                      mmu_visible.eq(~snoop_ep.data[0])
                   ).Elif(~self.c128_mode,
                          # First write is not to $FF00 -> real C64
                          self.c64_mode.eq(1)
                   ).Elif(snoop_ep.addr == 0xff01,
                          mmu_visible.eq(~preconfig[0])
                   ).Elif(snoop_ep.addr == 0xff02,
                          mmu_visible.eq(~preconfig[1])
                   ).Elif(snoop_ep.addr == 0xff03,
                          mmu_visible.eq(~preconfig[2])
                   ).Elif(snoop_ep.addr == 0xff04,
                          mmu_visible.eq(~preconfig[3])
                   ).Elif((snoop_ep.addr[4:] == 0xd50) & mmu_visible,
                          Case(snoop_ep.addr[:4],
                               { 0: mmu_visible.eq(~snoop_ep.data[0]),
                                 1: preconfig[0].eq(snoop_ep.data[0]),
                                 2: preconfig[1].eq(snoop_ep.data[0]),
                                 3: preconfig[2].eq(snoop_ep.data[0]),
                                 4: preconfig[3].eq(snoop_ep.data[0]),
                                 5: If(snoop_ep.data[6] == 1,
                                       # Go 64
                                       self.c128_mode.eq(0),
                                       self.c64_mode.eq(1))
                               })
                   )
            )
        ]
