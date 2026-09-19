# axi-stream

An AXI4-Stream master and two slaves, written from the ARM spec IHI 0051A, in
SystemVerilog. Around them a passive protocol checker, the same rules again as
assertions, and a uvm bench with constrained random stimulus and functional
coverage.

The point was not to make it work. It was to make it work for the reason the spec
gives, and then to check that the checking is doing something.

Every number below came from a real run here, not a guess.

## The rule that matters

Section 2.2.1. A master must not wait for TREADY before it raises TVALID. A slave
is allowed to wait for TVALID before it raises TREADY.

Break the first half and nothing tells you. It works against every slave you own,
then hangs forever against a legal one somebody else wrote.

`demos/demo_03_deadlock.sv` builds that pair. An illegal master and a cautious but
legal slave, neither faulty alone. Nothing moves in 8 cycles and the demo says so.

`demos/demo_06_registered_deadlock.sv` is the one to read. Two masters, both with
a registered TVALID, so neither has any combinational path from TREADY to TVALID
at all. One still deadlocks. Registering the output does not remove the dependency
if the decision still looks at TREADY.

## Three always blocks

Every synthesisable module here is written the same way.

| Block | What is allowed in it |
|-------|-----------------------|
| One   | Registers only, every line is `x_q <= x_d`, no decisions |
| Two   | Next value of every register, all decisions live here |
| Three | Every output, from `_q` only, reads no inputs |

More typing than needed. It also means "is this a latch", "is this output
combinational on that input" and "where was this decided" are answered by which
block the line is in. `always_ff` and `always_comb` make the tool check the claim.

## Two slaves, same behaviour

`axis_slave_basic.sv` has one three valued state. A single state variable holds
one value at a time, so "pausing" and "closing a packet" cannot both be true, and
block two needs a priority rule to choose.

`axis_slave_flags.sv` keeps `stall_q` and `closing_q` apart, TREADY is just
`~stall_q & ~closing_q`, and the priority rule is gone.

`make equiv` runs both on identical stimulus and compares every output every
cycle:

```
CHECKER master->slave: 17856 transfers, 4464 packets, 9633 stall cycles, 0 rule violations
cycles where the flag slave had stall_q AND closing_q high: 1557
output mismatches between the two slaves: 0
```

1557 is the number that matters. Those are cycles the single state variable could
not have represented, and the outputs still match, so the priority rule it needed
was the right one.

## How it is checked

`tb/axis_protocol_checker.sv` drives nothing and knows nothing about what the
master meant, so it fits any link. `sva/axis_sva.sv` says the same rules as SVA in
about a fifth of the lines, because `$past` and `$stable` do the remembering. Both
are kept, since the hand written one runs under icarus and carries on after a
violation while the assertions stop the run.

`make sva` runs a master with one deliberately wrong line past both:

```
[165000] broken CHECK FAIL: TDATA changed while stalled (0x000000a1 -> 0x000000a2)
[165000] %Error: Assertion failed in ...a_tdata_holds: broken: TDATA changed while stalled
```

Same edge, same values.

The uvm bench in `tb/uvm/` is the usual layering: item, sequence, sequencer,
driver, monitor, scoreboard, coverage, agent, env and test, in one package, built
and connected in `build_phase` / `connect_phase` / `run_phase` / `report_phase`.

This is real uvm, uvm 1.2, the library vivado ships with, run under xsim. That
is the only reason `make uvm` needs vivado, nothing else here does.

```
SCOREBOARD: 1000 packets checked, 0 errors
COVERAGE:   cg_pkt 100.00% over 1000 samples
COVER both flags high in the flag slave: 451 cycles
```

## The bug that makes the case for coverage

`axis_seq_last` exists to hit one corner and nothing else. It passed. 1000
packets, scoreboard clean.

Then I counted the corner itself and it said **0 cycles**. On the test written for
it. TREADY comes from `stall_q`, a register holding last cycle's pause, so a pause
raised in the same cycle as TLAST is one cycle too late. The fix was to count
handshakes and raise pause on the one before last. Now 1000 of 1000.

Passing told me nothing. The counter told me the test had been lying.

`cg_pkt` sat at 93.33% for a while and would not move. That one was not mine.
Verilator counts unreachable cross bins in the denominator, and a fourteen line
reproducer says the same thing. Under xsim the identical covergroup reads
100.00%. Both stories are in [docs/debug_log.md](docs/debug_log.md).

## Running it

Icarus and verilator cover everything except `make uvm`, which wants vivado.

```
make lint      verilator -Wall on the rtl
make run       directed test, one line per cycle
make regress   ten seeds
make equiv     the two slaves, cycle by cycle
make trace     the pause-during-tlast corner, both slaves
make demos     all seven demonstrations
make sva       the planted bug, caught by the assertions
make uvm       uvm bench under xsim, constrained random
make uvm_last  the same bench, aimed at the stall-on-last corner
```

Ten seeds pass with 0 protocol violations. Verilator `-Wall` is clean on all three
modules.

## Not there yet

Continuous aligned streams only. No TKEEP, TSTRB, TID, TDEST or TUSER, so no width
conversion, no sparse packets and no routing. The slave capture memory is 16 deep
and nothing reads it back except a debug port.

There is no interconnect between master and slave, which in a real system is where
the awkward cases live.

One master, two slaves, one interface. No second agent and no virtual sequencer.
Coverage is on the packet only.

None of this has been on an fpga. It lints, it simulates, and that is the claim.
