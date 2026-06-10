# icarus for the directed benches, verilator for lint and the assertions,
# xsim for the uvm bench because uvm needs a simulator that ships it. targets
# are listed in the readme
#
# xsim and uvm come from vivado. set XILINX_DIR if yours is somewhere else

RTL     := rtl/axis_master_basic.sv rtl/axis_slave_basic.sv
CHECKER := tb/axis_protocol_checker.sv
SVA     := sva/axis_sva.sv
SIMDIR  := sim
SEED    ?= 1
PAUSE   ?= 30
STARTP  ?= 10
NITEMS  ?= 1000

ALL_RTL := $(RTL) rtl/axis_slave_flags.sv
XILINX_DIR ?= /opt/Xilinx/2026.1/Vivado
XSIM_BIN   := $(XILINX_DIR)/bin
UVM_SRC    := $(ALL_RTL) tb/uvm/axis_if.sv tb/uvm/axis_pkg.sv tb/uvm/tb_axis_uvm.sv

VFLAGS  := --binary --timing --assert -Wno-fatal

all: lint run random equiv uvm

$(SIMDIR):
	@mkdir -p $(SIMDIR)

# ---------------------------------------------------------------- Icarus benches
$(SIMDIR)/tb_axis_basic.vvp: $(RTL) $(CHECKER) tb/tb_axis_basic.sv | $(SIMDIR)
	iverilog -g2012 -o $@ $^

$(SIMDIR)/tb_axis_random.vvp: $(RTL) $(CHECKER) tb/tb_axis_random.sv | $(SIMDIR)
	iverilog -g2012 -o $@ $^

$(SIMDIR)/tb_slave_equiv.vvp: $(ALL_RTL) $(CHECKER) tb/tb_slave_equiv.sv | $(SIMDIR)
	iverilog -g2012 -o $@ $^

$(SIMDIR)/tb_slave_trace.vvp: $(ALL_RTL) tb/tb_slave_trace.sv | $(SIMDIR)
	iverilog -g2012 -o $@ $^

run: $(SIMDIR)/tb_axis_basic.vvp
	vvp $(SIMDIR)/tb_axis_basic.vvp

random: $(SIMDIR)/tb_axis_random.vvp
	vvp $(SIMDIR)/tb_axis_random.vvp +seed=$(SEED) +pause_pct=$(PAUSE) +start_pct=$(STARTP)

regress: $(SIMDIR)/tb_axis_random.vvp
	@for s in 1 2 3 4 5 6 7 8 9 10; do \
	  vvp $(SIMDIR)/tb_axis_random.vvp +seed=$$s +pause_pct=$(PAUSE) +start_pct=$(STARTP) | grep -E 'RESULT' | sed "s/^/seed $$s: /"; \
	done

equiv: $(SIMDIR)/tb_slave_equiv.vvp
	vvp $(SIMDIR)/tb_slave_equiv.vvp +seed=$(SEED)

trace: $(SIMDIR)/tb_slave_trace.vvp
	vvp $(SIMDIR)/tb_slave_trace.vvp

demos: | $(SIMDIR)
	@for d in demo_01_nonblocking demo_03_deadlock demo_04_counter demo_05_two_timelines demo_06_registered_deadlock; do \
	  echo "=== $$d"; iverilog -g2012 -o $(SIMDIR)/$$d.vvp demos/$$d.sv && vvp $(SIMDIR)/$$d.vvp; \
	done
	@echo "=== demo_07_checker_catches (hand written checker only, Icarus)"
	@iverilog -g2012 -o $(SIMDIR)/demo_07.vvp rtl/axis_slave_basic.sv $(CHECKER) demos/demo_07_checker_catches.sv && vvp $(SIMDIR)/demo_07.vvp

wave: run
	gtkwave $(SIMDIR)/tb_axis_basic.vcd &

# ---------------------------------------------------------- Verilator, assertions
$(SIMDIR)/sva_demo: rtl/axis_slave_basic.sv $(SVA) $(CHECKER) demos/demo_07_checker_catches.sv | $(SIMDIR)
	@echo "  verilating demo_07 with assertions"
	@verilator $(VFLAGS) --top-module demo_07_checker_catches \
	  -Mdir $(SIMDIR)/obj_sva -o ../sva_demo $^ > $(SIMDIR)/build_sva.log 2>&1 \
	  || (cat $(SIMDIR)/build_sva.log; false)

sva: $(SIMDIR)/sva_demo
	-@$(SIMDIR)/sva_demo

# ----------------------------------------------------------- xsim, the uvm bench
$(SIMDIR)/xsim/.built: $(UVM_SRC) $(wildcard tb/uvm/*.svh) | $(SIMDIR)
	@mkdir -p $(SIMDIR)/xsim
	@echo "  xvlog + xelab, uvm from $(XILINX_DIR)"
	@cd $(SIMDIR)/xsim && $(XSIM_BIN)/xvlog -sv -L uvm -i ../../tb/uvm \
	  $(addprefix ../../,$(UVM_SRC)) > xvlog.log 2>&1 || (cat xvlog.log; false)
	@cd $(SIMDIR)/xsim && $(XSIM_BIN)/xelab -L uvm tb_axis_uvm -s axis_uvm \
	  --timescale 1ns/1ps > xelab.log 2>&1 || (cat xelab.log; false)
	@touch $@

uvm: $(SIMDIR)/xsim/.built
	@cd $(SIMDIR)/xsim && $(XSIM_BIN)/xsim axis_uvm -R \
	  -testplusarg UVM_TESTNAME=axis_test_random -testplusarg nitems=$(NITEMS) \
	  | grep -E 'SCOREBOARD|COVERAGE|COVER|RESULT|UVM_ERROR|UVM_FATAL'

uvm_last: $(SIMDIR)/xsim/.built
	@cd $(SIMDIR)/xsim && $(XSIM_BIN)/xsim axis_uvm -R \
	  -testplusarg UVM_TESTNAME=axis_test_last -testplusarg nitems=$(NITEMS) \
	  | grep -E 'SCOREBOARD|COVER both|RESULT|UVM_ERROR|UVM_FATAL'

lint:
	verilator --lint-only -Wall --top-module axis_master_basic rtl/axis_master_basic.sv
	verilator --lint-only -Wall --top-module axis_slave_basic  rtl/axis_slave_basic.sv
	verilator --lint-only -Wall --top-module axis_slave_flags  rtl/axis_slave_flags.sv

clean:
	rm -rf $(SIMDIR)

.PHONY: all run random regress equiv trace demos wave lint sva uvm uvm_last clean
