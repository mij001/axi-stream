// one agent, a scoreboard and a coverage collector hanging off the monitor

class axis_env extends uvm_env;

   `uvm_component_utils(axis_env)

   axis_agent      agt;
   axis_scoreboard sb;
   axis_coverage   cov;

   function new(string name, uvm_component parent);
      super.new(name, parent);
   endfunction

   function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      agt = axis_agent::type_id::create("agt", this);
      sb  = axis_scoreboard::type_id::create("sb", this);
      cov = axis_coverage::type_id::create("cov", this);
   endfunction

   function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      agt.mon.ap.connect(sb.analysis_export);
      agt.mon.ap.connect(cov.analysis_export);
   endfunction

endclass : axis_env
