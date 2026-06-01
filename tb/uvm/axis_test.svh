// base test. the env, and the number of packets off the command line

class axis_test_base extends uvm_test;

   `uvm_component_utils(axis_test_base)

   axis_env     env;
   int unsigned n_items;

   function new(string name, uvm_component parent);
      super.new(name, parent);
      n_items = 200;
   endfunction

   function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      void'($value$plusargs("nitems=%d", n_items));
      env = axis_env::type_id::create("env", this);
   endfunction

   function void report_phase(uvm_phase phase);
      if (env.sb.n_err == 0 && env.sb.n_pkt > 0)
         `uvm_info("TEST", "RESULT: PASS", UVM_LOW)
      else
         `uvm_error("TEST", "RESULT: FAIL")
   endfunction

endclass : axis_test_base


// mixed backpressure, the default
class axis_test_random extends axis_test_base;

   `uvm_component_utils(axis_test_random)

   function new(string name, uvm_component parent);
      super.new(name, parent);
   endfunction

   task run_phase(uvm_phase phase);
      axis_sequence seq;
      phase.raise_objection(this);
      seq = axis_sequence::type_id::create("seq");
      seq.n_items = n_items;
      seq.start(env.agt.seqr);
      repeat (60) @(posedge env.agt.mon.vif.aclk);
      phase.drop_objection(this);
   endtask

endclass : axis_test_random


// every packet stalls on its tlast beat
class axis_test_last extends axis_test_base;

   `uvm_component_utils(axis_test_last)

   function new(string name, uvm_component parent);
      super.new(name, parent);
   endfunction

   task run_phase(uvm_phase phase);
      axis_seq_last seq;
      phase.raise_objection(this);
      seq = axis_seq_last::type_id::create("seq");
      seq.n_items = n_items;
      seq.start(env.agt.seqr);
      repeat (60) @(posedge env.agt.mon.vif.aclk);
      phase.drop_objection(this);
   endtask

endclass : axis_test_last
