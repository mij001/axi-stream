# axi-stream

AXI4-Stream master and slave, written from the ARM spec IHI 0051A.

There is also a protocol checker in `tb/` that watches the link and shouts when a
rule is broken. It drives nothing, so it fits any link.

`demos/` has the small ones. The deadlock pair is the interesting one.

Needs icarus verilog and verilator.

```
make lint
make run
make random
make regress
make equiv
make trace
make demos
```
