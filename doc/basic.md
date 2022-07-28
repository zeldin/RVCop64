RVCop64 BASIC extensions
========================

The following additional BASIC statements / functions are added by the
EXROM:


> `RVHELP`

Display a brief help screen


> `RVTERM`

Enter an ANSI terminal emulator connected to the VUART of the RISC-V
processor.  Press `RUN/STOP+RESTORE` to exit.


> `RVPOKE` _addr_,_byte_,...

Write one or more bytes to the RISC-V processor memory space.
Please note that CSRs (address $f0000000 and up) do not fully
support byte writes -- any attempt to write a byte in a CSR will
clear the other 3 bytes of that CSR.

> `RVPEEK`(_addr_)

Read a byte at the specified RISC-V processor memory space address.


> `RVSTASH` _cnt_,_intsa_,_extsa_

Transfer _cnt_ bytes starting at address _intsa_ in the internal
memory space of the C64 to the RISC-V processor memory space starting
at address _extsa_.  The same caveat about CSRs as in `RVPOKE` applies.


> `RVFETCH` _cnt_,_intsa_,_extsa_

Transfer _cnt_ bytes starting at address _extsa_ in the RISC-V processor
memory space to the internal memory space of the C64 starting at address
_intsa_.


> `RVSWAP` _cnt_,_intsa_,_extsa_

Exchange the contents of the _cnt_ bytes in the internal memory space
of the C64 starting at _intsa_ with the _cnt_ bytes in the RISC-V processor
memory space starting at _extsa_.  The same caveat about CSRs as in `RVPOKE`
applies.


> `RVSYS` _addr_,_args_...

Starts execution of the RISC-V processor at address _addr_.  If it
was previously halted then execution is resumed.  The caches are flushed
before the instruction at address _addr_ is executed.  If additional
arguments are provided after _addr_, they are passed in registers `a0`
through `a7` (aka `x10` through `x17`).  Please note that the return address
register (`ra` / `x1`) is set to _addr_, so the called function should not
attempt to return.  Instead it should execute the instruction `EBREAK`
when it is done.


> `RVMON`

Enter [the RISC-V machine code monitor](rvmon.md).


