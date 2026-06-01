// sequencer, driver and monitor for one axi4-stream link

class axis_agent extends uvm_agent;

   `uvm_component_utils(axis_agent)

   uvm_sequencer #(axis_item) seqr;
   axis_driver                drv;
   axis_monitor               mon;

   function new(string name, uvm_component parent);
      super.new(name, parent);
   endfunction

   function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      mon = axis_monitor::type_id::create("mon", this);
      if (get_is_active() == UVM_ACTIVE) begin
         seqr = uvm_sequencer #(axis_item)::type_id::create("seqr", this);
         drv  = axis_driver::type_id::create("drv", this);
      end
   endfunction

   function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      if (get_is_active() == UVM_ACTIVE)
         drv.seq_item_port.connect(seqr.seq_item_export);
   endfunction

endclass : axis_agent
