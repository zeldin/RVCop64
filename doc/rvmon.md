RVMON
=====

The RISC-V machine code monitor is entered with the `RVMON` BASIC statement.
Whenever the monitor is entered, the RISC-V processor is put into the halted
state.

Like the C128 machine code monitor, any numeric input can be specified in
hexadecimal (`$` prefix or no prefix), decimal (`+` prefix), octal (`&` prefix)
or binary (`%` prefix).  Giving a prefixed number as a command displays it
in all bases.

Addresses are specified in the 32-bit address space of the RISC-V processor,
but the first 64K overlaps the internal memory space of the C64 which makes
it possible to for example transfer data between internal and external
memory using the `T` command.


The following commands are supported:


> `D` _start-address_ _end-address_

Disassemble.  Both _start-address_ and _end-address_ can be omitted.


> `F` _start-address_ _end-address_ _byte_

Fill.  Memory starting at _start-address_ and ending at _end-address_ is
filled with _byte_.


> `G` _address_

Go.  Bring the RISC-V processor out of the halted state and exit the monitor.
If an _address_ is provided, then the RISC-V processor will start executing
at that address, otherwise it resumes from the point where it was halted.


> `M` _start-address_ _end-address_

Memory dump.  Both _start-address_ and _end-address_ can be omitted.


> `R`

Register dump.  The first line of the dump contains `pc` and `x1`
through `x3`, the next line `x4` through `x7`, and so on.


> `T` _start-address_ _end-address_ _target-address_

Transfer data.  Memory starting at _start-address_ and ending at
_end-address_ is copied to _target-address_.


> `X`

Exit monitor.  The RISC-V processor is left in the halted state.
To exit the monitor with the RISC-V processor running, use the `G`
command instead.


> `Z` _steps_

Single step.  The RISC-V processor executes _steps_ instructions (1 if
_steps_ is omitted) and then halts again.  The next instruction to execute
is then displayed.


> `>` _addr_ _byte_ ...

Modify memory.  The given bytes are written to memory starting at _addr_.


> `;` _reg_ _value_ ...

Set registers.  Starting with register number _reg_ (which must be
provided in decimal, without the `+` prefix), set registers to the
specified values.  If _reg_ is zero, the first register written is
`pc`, not `x0` (which can not be written).

