# Debug log

Things that broke while building this, and how I found each one. I keep this
because the bug list is the part I actually learned from. The rtl was mostly
fine. Almost everything here is the testbench being wrong about the design, or
me being wrong about the tool.

Every number below is from a real run. Nothing is from memory.

---

## 1. the driver said it pulsed start, and start never moved

**Symptom.** Class based bench, first packet, nothing happens. Driver prints that
it pulsed `start`. Then the guard counter in `drive()` gives up after 1000
cycles.

```
[55000] DRV start pulsed, gap=0 bp=BP_LAST busy=0 tvalid=0 pkt_done=0
[10055000] %Fatal: axis_driver: packet never completed, gap=0 bp=BP_LAST
```

**What I tried first.** I thought two drivers on the same wire. The top had
`vif.start = 1'b0;` in its initial block and the driver wrote the same variable
through the clocking block. That is a real problem so I fixed it, moved the
initial value into the interface declaration. Did not help. Still 0.

**How I actually found it.** Stopped guessing. Put a probe in the top printing
every interface signal each cycle.

```
cyc 0 start=0 busy=0 tvalid=0 tready=1 tlast=0 pause=0 done=0
cyc 1 start=0 busy=0 tvalid=0 tready=1 tlast=0 pause=0 done=0
...
```

`start` is 0 forever. So the driver is not driving, the master is not ignoring.
That splits the problem in half and the half that was left was small.

Then I built the smallest thing that could show it. Fourteen lines: an
interface, a clocking block output, a module that registers it. That one worked.
So clocking outputs are fine in verilator, and my driver was doing something the
small one was not.

**The cause.** `drive()` wrote `vif.drv_cb.pause <= 1'b0;` as its first line,
before ever waiting on `@(vif.drv_cb)`. A clocking block output written before
the process has lined up with the clocking event has no edge to attach to. It is
dropped. Silently.

**The fix.** One line. Wait for the clocking event first.

```systemverilog
@(vif.drv_cb);              // line up first
vif.drv_cb.pause <= 1'b0;
```

**What I take from it.** A probe that prints the wires beat a whole afternoon of
reading my own code. And the minimal reproducer is not extra work, it is the
fast path.

---

## 2. my own stimulus deadlocked itself

**Symptom.** Same guard, different reason. Only on `BP_LAST` packets.

**The cause.** I wrote the backpressure as "pause while TLAST is being offered".

```systemverilog
BP_LAST: vif.drv_cb.pause <= (vif.drv_cb.tvalid & vif.drv_cb.tlast);
```

Read it again and it is obviously circular. Pause goes high because TLAST is
offered. Slave stops taking the beat. So TLAST stays offered. So pause stays
high. Nothing moves, forever.

The design is not wrong here. The design is doing exactly what a legal slave
does. My stimulus asked for something impossible.

**The fix.** Pause for a bounded time, not for a condition the pause itself keeps
true.

**What I take from it.** A guard counter in the driver is worth the five lines.
Without it this is a simulation that runs until the timeout and tells you
nothing. With it, it names the packet and the mode.

---

## 3. the directed test hit the corner zero times

This one is my favourite because the test passed the whole time.

**Background.** There are two slaves. One has a three valued state, one has two
independent flags. The flags version exists because a single state variable
cannot be "pausing" and "closing a packet" at the same time. The corner worth
testing is the cycle where both flags are high.

I wrote `axis_seq_last` to do nothing else but hit that corner. It passed.
Scoreboard clean, 1000 packets, 0 errors.

**Symptom.** Then I added a counter for the corner itself.

```
COVER both flags high in the flag slave: 0 cycles
```

Zero. On the test written for it. And the random test was hitting it 451 times.

**The cause.** TREADY comes from `stall_q`, and `stall_q` is a register. It holds
last cycle's pause. So a pause raised in the same cycle TLAST is offered is one
cycle too late. By the time TREADY could drop, the last beat is already taken and
the packet is over.

Fixing bug 2 had moved the pulse to "one cycle when TLAST is first seen", which
does not hang, and also does not do anything.

**The fix.** Stop reacting, start predicting. Count handshakes and raise pause on
the one before last, so it is already high during the cycle the TLAST transfer
completes.

```systemverilog
BP_LAST: begin
    if (vif.drv_cb.tvalid && vif.drv_cb.tready) hs_count++;
    vif.drv_cb.pause <= (hs_count == (PKT_LEN - 1));
end
```

**Result.** 1000 of 1000 packets now hit it.

```
COVER both flags high in the flag slave: 1000 cycles
```

**What I take from it.** This is the whole argument for functional coverage in
one bug. The test passed before and after. Passing told me nothing. The counter
told me the test had been lying for three versions in a row. A directed test that
does not check it reached its target is just a test that runs.

---

## 4. covergroup stuck at 93.33% with everything covered

**Symptom.** `cg_pkt` sits at 93.33% under verilator and will not move. 100
packets, 1000 packets, same number. But the plain histogram says every bucket has
hits.

```
COVERAGE:   cg_pkt 93.33% over 1000 samples
COVER stalls none/few/some/many : 589 / 203 / 111 / 97
COVER last beat clean / stalled : 776 / 224
COVER cross stalled-on-last x   : few 79, some 71, many 74
```

14 of 15 bins. One bin unreachable by construction: a packet with zero stall
cycles cannot also be stalled on its last beat.

**What I tried.**

1. `ignore_bins` on the impossible cross. No change.
2. Listed the seven reachable cross bins by hand instead. No change.
3. Removed an `illegal_bins default` from the beats coverpoint. No change.

Three fixes, all of them correct systemverilog, none of them moved the number.

**How I found it.** Same move as bug 1. Smallest possible case, no design in it
at all, just two coverpoints and a cross with seven named bins, and I sample
every reachable combination by hand.

```
DENOM TEST coverage = 92.86%
```

13 of 14. Every reachable bin hit. So verilator 5.052 puts the full 4x2 cross
product in the denominator no matter what `bins` or `ignore_bins` say.

**Status.** Not mine to fix, so I left the covergroup as it should be and
reported the histogram next to the percentage.

That was where it sat until the bench had a second simulator to run under. Same
covergroup, same stimulus, not a line changed:

```
COVERAGE: cg_pkt 100.00% over 1000 samples
```

Which is the answer. It was the denominator all along.

**What I take from it.** Know which number your tool is actually computing. I
nearly rewrote a correct covergroup three times to chase a denominator, and the
thing that saved me was the fourteen line case that has no design in it.

---

## 5. Icarus will not take a ternary over two enum names

**Symptom.** Verilator clean, icarus refuses.

```
rtl/axis_slave_basic.sv:138: error: This assignment requires an explicit cast.
```

Line was `state_d = pause ? ST_STALL : ST_RX;`.

**The cause.** A conditional expression over two enum literals loses the enum
type. Assigning that back to an enum variable needs an explicit cast, and icarus
enforces it. Verilator does not.

**The fix.** If / else. One line more, no cast, both tools happy.

Icarus also says `sorry: Case unique/unique0 qualities are ignored` on every
`unique case`. That is a note and not an error. It means the `unique` is doing
nothing under icarus, and the check only really exists under verilator. Worth
knowing rather than assuming the check runs everywhere.

---

## 6. the assertions catch the planted bug, same edge as the hand written checker

Not a bug, a check that the new stuff works.

`demos/demo_07_checker_catches.sv` has a master with one wrong line: the beat
counter advances every cycle in `ST_SEND` instead of only on a handshake. With a
slave that never stalls it looks perfect.

Hand written checker, from `tb/axis_protocol_checker.sv`:

```
[165000] broken CHECK FAIL: TDATA changed while stalled (0x000000a1 -> 0x000000a2)
```

Assertions, from `sva/axis_sva.sv`, bound to the same module:

```
[165000] %Error: Assertion failed in ...u_sva.a_tdata_holds:
         broken: TDATA changed while stalled, 0xa1 -> 0xa2
```

Same edge, same values. The assertion version is four lines and the hand written
one is about ten, and the assertion one is the one I trust more, because $past
does the remembering instead of me.

One difference worth noting. A failed assertion stops the run, so the second half
of the demo does not execute. The hand written checker counts and carries on. For
a demo the second behaviour is nicer, for a regression the first is.

---

## 7. uvm starts the run phase at time zero, and reset had not happened yet

**Symptom.** First run of the whole bench. The first packet came out wrong, and
the protocol checker was already unhappy one cycle before it.

**The cause.** I had written the top the way I write every top: an `initial` that
pulls reset low, waits, puts it back high, and then gets the stimulus going. Under
`run_test()` that last part is not mine to order. Every component's `run_phase`
starts at time zero, so the driver was already pushing a packet at the design
while `aresetn` was still low.

**The fix.** The driver waits for reset itself:

```systemverilog
wait (vif.aresetn === 1'b1);
```

**What I take from it.** The phases are not just places to put code. They decide
when things happen, and the ordering between reset and the first stimulus is the
one thing a hand written top gives you for free and this does not.

