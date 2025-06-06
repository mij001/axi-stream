# icarus and verilator. targets are listed in the readme

RTL     := rtl/axis_master_basic.v rtl/axis_slave_basic.v
CHECKER := tb/axis_protocol_checker.v
SIMDIR  := sim

all: lint run

$(SIMDIR):
	@mkdir -p $(SIMDIR)

$(SIMDIR)/tb_axis_basic.vvp: $(RTL) $(CHECKER) tb/tb_axis_basic.v | $(SIMDIR)
	iverilog -g2005 -o $@ $^

run: $(SIMDIR)/tb_axis_basic.vvp
	vvp $(SIMDIR)/tb_axis_basic.vvp

lint:
	verilator --lint-only -Wall --top-module axis_master_basic rtl/axis_master_basic.v
	verilator --lint-only -Wall --top-module axis_slave_basic rtl/axis_slave_basic.v

clean:
	rm -rf $(SIMDIR)

.PHONY: all run lint clean
