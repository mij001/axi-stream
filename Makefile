# icarus and verilator. targets are listed in the readme

RTL     := rtl/axis_master_basic.v rtl/axis_slave_basic.v
CHECKER := tb/axis_protocol_checker.v
SIMDIR  := sim

$(SIMDIR):
	@mkdir -p $(SIMDIR)

lint:
	verilator --lint-only -Wall --top-module axis_master_basic rtl/axis_master_basic.v

clean:
	rm -rf $(SIMDIR)

.PHONY: lint clean
