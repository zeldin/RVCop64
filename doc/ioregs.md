I/O registers
=============

The RVCop64 bitstream includes a number of extra I/O registers in the I/O1
region accessible by the 6510/8502.  The basic extensions and machine code
monitor utilize some of these registers, but they can also be accessed
directly by user code.


## Overview

The following is an overview of the I/O1 address ranges defined by the
RVCop64 bitstream.  The individual functions are detailed in the following
sections.

| Address     | Function          |
| ----------- | ----------------- |
| $DE10-$DE11 | VUART             |
| $DE20-$DE25 | Wishbone master   |
| $DE30-$DE37 | RISC-V core debug |
| $DEC0-$DEFF | Mailbox           |


### VUART

The VUART function provides a virtual serial port which is connected
to a corresponding function on the RISC-V side.  The `RVTERM` basic
command uses this function to interact with the RISC-V system's boot
console.

| Address | Register   |
| ------- | ---------- |
| $DE10   | `RXTX`     |
| $DE11   | `STATUS`   |

Writing to the `RXTX` register commits a character to the TX FIFO making
it available for the RISC-V side to read.  If the register is written
when the FIFO is full, the character is lost.

Reading from the `RXTX` register pops the first available character from
the RX FIFO, where data provided from the RISC-V side appears.

The `STATUS` register provides information about the status of the FIFOs.
If the MSB is set, then the RX FIFO is empty, and reading from `RXTX` will
not give a valid character.  If the bit below the MSB is set, then the TX
FIFO is full, and any character written to `RXTX` will be lost.


### Wishbone master

The Wishbone master function provides access to the entire 4GB memory
space of the RISC-V system.  It is used by the `RVPOKE` and `RVPEEK` basic
commands.

| Address      | Register         |
| ------------ | ---------------- |
| $DE20-$DE23  | `ADDR`           |
| $DE24        | `DATA`           |
| $DE25        | `STATUS_CONTROL` |

The `ADDR` register contains the 32-bit address to access on the RISC-V
system bus.  $DE20 contains the 8 lowest bits, and $DE23 the 8 highest bits.

The `DATA` register is used to write data to be written on the RISC-V
system bus, and holds the resulting byte after reading from the RISC-V
system bus.

#### `STATUS_CONTROL` register

The `STATUS_CONTROL` register controls the mode of operation, and
returns the status of the latest bus operation.  It consists of 6
read/write mode bits, and two bits which act as status flags
or trigger bits depending on whether they are read or written.

| Bit         | Function         |
| ----------- | ---------------- |
| $01         | `WRITE_ON_WDATA` |
| $02         | `INC_ON_WDATA`   |
| $04         | `READ_ON_RDATA`  |
| $08         | `INC_ON_RDATA`   |
| $10         | `READ_ON_WADDR`  |
| $20         | `INC_ON_WADDR`   |
| $40 (read)  | `ERROR`          |
| $40 (write) | `READ_NOW`       |
| $80 (read)  | `BUSY`           |
| $80 (write) | `INC_NOW`        |

If the `WRITE_ON_WDATA` mode is enabled, a write to the `DATA` register
will start a write cycle on the RISC-V system bus.  When the cycle completes
the `BUSY` status flag returns to 0.

If the `INC_ON_WDATA` mode is enabled, a write to the `DATA` register
will increment the `ADDR` register by one.  It is possible for
`WRITE_ON_WDATA` and `INC_ON_WDATA` to be enabled at the same time;
in this case the data will be written to the address contained in `ADDR`
before it was incremented.

If the `READ_ON_RDATA` mode is enabled, a read from the `DATA` register
will start a read cycle on the RISC-V system bus.  When the cycle completes
the `BUSY` status flag returns to 0.  Note that the data actually
retrieved from the `DATA` register in this mode will not be the result
of the newly started read cycle, but that of the previous one.  Therefore
it is necessary to start with a "dummy" read.  However, this mode can
still be useful when reading multiple bytes of data.

If the `INC_ON_RDATA` mode is enabled, a read from the `DATA` register
will increment the `ADDR` register by one.  It is possible for
`READ_ON_RDATA` and `INC_ON_RDATA` to be enabled at the same time;
in this case the data will be read from the address contained in `ADDR`
before it was incremented.

If the `READ_ON_WADDR` mode is enabled, a write to the most significant
byte of `ADDR` ($DE23) will start a read cycle on the RISC-V system bus.
This can be useful for random access reads.

If the `INC_ON_WADDR` mode is enabled, a write to the most significant
byte of `ADDR` ($DE23) will cause the other bits of `ADDR` to increment
by one.  Note that because the write operation replaces the most
significant byte, there is no carry from bit 23 to bit 24.  `READ_ON_WADDR`
and `INC_ON_WADDR` can be enabled at the same time; in this case
the data will be read from the address contained in `ADDR` before
it was incremented and the most significant byte replaced.

The `ERROR` status flag indicates if the last bus transaction failed.
It is valid only when `BUSY` is 0.

The `BUSY` status flag indicates that the most recently started bus
transaction is still in progress.  It is not possible to inspect the
resulting `DATA` of a read operation, or the `ERROR` status of a read
or write operation, until `BUSY` has returned to 0.

The `READ_NOW` trigger bit can be written with 1 to start a read
transaction.  This is an alternative to using the `READ_ON_RDATA` mode,
or can be used to trigger the first read in `READ_ON_RDATA` mode in place
of the dummy read.  Writing 0 to the trigger bit does nothing.

The `INC_NOW` trigger bit can be written with 1 to increment the contents
of the `ADDR` register by 1.  Writing 0 to the trigger bit does nothing.
It is possible to write both `READ_NOW` and `INC_NOW` as 1 at the same
time.  In this case the daat will be read from the address contained in
`ADDR` before it was incremented.


### RISC-V core debug

The RISC-V core debug function provides the means to directly control the
RISC-V core from the 6510/8502.  It is used by the `RVMON` command.

| Address      | Register         |
| ------------ | ---------------- |
| $DE30        | `STATUS`         |
| $DE32        | `SET`            |
| $DE33        | `CLEAR`          |
| $DE34-$DE37  | `INSTR_REGVAL`   |

#### `STATUS` register

The `STATUS` register can be read to find out the current state of the
RISC-V core.  It also contains the single step mode bit.

| Bit  | Function          |
| ---- | ----------------- |
| $01  | `RESET_IT`        |
| $02  | `HALT_IT`         |
| $04  | `IS_PIP_BUSY`     |
| $08  | `HALTED_BY_BREAK` |
| $10  | `STEP_IT`         |

The `RESET_IT` bit indicates if the RISC-V core is currently being
forced into reset.  The bit is read-only here, but can be modified
using the `SET` and `RESET` registers.

The `HALT_IT` bit indicates if the RISC-V core is currently being
forced into a halt.  The bit is read-only here, but can be modified
using the `SET` and `RESET` registers.

The read-only `IS_PIP_BUSY` bit indicates if the RISC-V core is unable
to accept instruction input through this interface.

The read-only `HALTED_BY_BREAK` bit indicates if the RISC-V core has
halted itself due to executing an `EBREAK` instruction.

The read-write `STEP_IT` bit controls single step mode.  If single
step mode is enabled, `HALT_IT` will automatically be set after executing
each instruction.

#### `SET` register

The `SET` register can be written to set the corresponding bit in
the `STATUS` register, thus forcing the RISC-V core into either reset
or halt state.

| Bit  | Function                  |
| ---- | ------------------------- |
| $01  | Write 1 to set `RESET_IT` |
| $02  | Write 1 to set `HALT_IT`  |

#### `CLEAR` register

The `CLEAR` register can be written to clear the corresponding bit in
the `STATUS` register, thus releasing the RISC-V core from reset
or halt state.

| Bit  | Function                                         |
| ---- | ------------------------------------------------ |
| $01  | Write 1 to clear `RESET_IT`                      |
| $02  | Write 1 to clear `HALT_IT` and `HALTED_BY_BREAK` |

Note that writing this register to clear a halt will also resume
execution after a voluntary halt due to the `EBREAK` instruction.
Clearing a halt in single step mode will execute one instruction and
then halt again.  Clearing a halt when single step mode is not enabled
will resume execution until another `EBREAK` or a write to `SET` enabling
`HALT_IT` is encountered.

#### `INSTR_REGVAL` register

The `INSTR_REGVAL` register is a 32-bit register which has different
functions depending on whether it is written or read.  Writing this
register tells the RISC-V core to execute an arbitrary RV32I instruction.
The instruction is executed when the most significant byte of the register
($DE37) is written, so this byte must be written last.  In order for
this register to be used, the core must be halted through `HALT_IT` or
`HALTED_BY_BREAK`, and `IS_PIP_BUSY` must be 0.

Reading the register returns the data written to the destination register
by the latest executed instruction.  This works also when the destination
register is `X0`.  Therefore writing an instruction to `INSTR_REGVAL` which
copies the contents from any general purpose register or CSR into `X0` can
be used to find the value of that register.


### Mailbox

The mailbox function provides a small shared memory area that both the
6510/8502 can access without latency.  The area appears on the RISC-V
system bus at address 0xe0000000-0xe000003f, and this memory range
can be accessed without causing any DMA cycles that would pause the
execution of the 6510/8502.  The range is also inside the non-cacheable
region, so no data cache flushes are needed to access the data.

The last 5 bytes of the area contain a doorbell function.  If the
6510/8502 writes to $DEFF, this will trigger an interrupt (IRQ#4)
to the RISC-V core.  If this interrupt is enabled, the interrupt
handler needs to clear the interrupt by making a read of any size from
the range 0xe000003c-0xe000003f.

Conversely, if the RISC-V core writes to 0xe000003b, this will trigger
an interrupt to the 6510/8502 which is cleared by reading $DEFB.

The doorbell bytes can be read and written from both sides, and will
retain any values written to them just like the rest of the mailbox area.
Only writes from one side will trigger the interrupt function of each
doorbell region, i.e. it is not possible to push your own doorbell but
it is possible to modify the value stored there.

| 6510/8502 address | RISC-V address        | Function                    |
| ----------------- | --------------------- | --------------------------- |
| $DEC0-$DEFA       | 0xe0000000-0xe000003a | General purpose RAM         |
| $DEFB             | 0xe000003b            | RISC-V → 6510/8502 doorbell |
| $DEFC-$DEFF       | 0xe000003c-0xe000003f | 6510/8502 → RISC-V doorbell |
