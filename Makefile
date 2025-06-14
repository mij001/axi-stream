# icarus and verilator. targets are listed in the readme

RTL     := rtl/axis_master_basic.v rtl/axis_slave_basic.v
CHECKER := tb/axis_protocol_checker.v
SIMDIR  := sim
SEED    ?= 1
PAUSE   ?= 30
STARTP  ?= 10

all: lint run random

$(SIMDIR):
	@mkdir -p $(SIMDIR)

$(SIMDIR)/tb_axis_basic.vvp: $(RTL) $(CHECKER) tb/tb_axis_basic.v | $(SIMDIR)
	iverilog -g2005 -o $@ $^

$(SIMDIR)/tb_axis_random.vvp: $(RTL) $(CHECKER) tb/tb_axis_random.v | $(SIMDIR)
	iverilog -g2005 -o $@ $^

run: $(SIMDIR)/tb_axis_basic.vvp
	vvp $(SIMDIR)/tb_axis_basic.vvp

random: $(SIMDIR)/tb_axis_random.vvp
	vvp $(SIMDIR)/tb_axis_random.vvp +seed=$(SEED) +pause_pct=$(PAUSE) +start_pct=$(STARTP)

regress: $(SIMDIR)/tb_axis_random.vvp
	@for s in 1 2 3 4 5 6 7 8 9 10; do \
	  vvp $(SIMDIR)/tb_axis_random.vvp +seed=$$s +pause_pct=$(PAUSE) +start_pct=$(STARTP) | grep -E 'RESULT' | sed "s/^/seed $$s: /"; \
	done

lint:
	verilator --lint-only -Wall --top-module axis_master_basic rtl/axis_master_basic.v
	verilator --lint-only -Wall --top-module axis_slave_basic rtl/axis_slave_basic.v

clean:
	rm -rf $(SIMDIR)

.PHONY: all run random regress lint clean
