from litex.soc.cores.uart import UARTInterface
from litex.soc.interconnect.csr import AutoCSR, CSR, CSRField, CSRStatus
from litex.soc.interconnect.stream import SyncFIFO
from migen import Module

def _get_uart_fifo(depth):
    return SyncFIFO([("data", 8)], depth, buffered=True)

class VUART(Module, AutoCSR, UARTInterface):

    def __init__(self, tx_fifo_depth = 16, rx_fifo_depth = 16):
        self._rxtx    = CSR(8)
        self._status  = CSRStatus(fields=[
            CSRField("txfull",  size=1, offset=6),
            CSRField("rxempty", size=1, offset=7)])

        UARTInterface.__init__(self)

        # TX
        self.submodules.tx_fifo = tx_fifo = _get_uart_fifo(tx_fifo_depth)
        self.comb += [
            tx_fifo.sink.valid.eq(self._rxtx.re),
            tx_fifo.sink.data.eq(self._rxtx.r),
            tx_fifo.source.connect(self.source),
            self._status.fields.txfull.eq(~tx_fifo.sink.ready)
        ]

        # RX
        self.submodules.rx_fifo = rx_fifo = _get_uart_fifo(rx_fifo_depth)
        self.comb += [
            self.sink.connect(rx_fifo.sink),
            self._rxtx.w.eq(rx_fifo.source.data),
            rx_fifo.source.ready.eq(self._rxtx.we),
            self._status.fields.rxempty.eq(~rx_fifo.source.valid)
        ]
