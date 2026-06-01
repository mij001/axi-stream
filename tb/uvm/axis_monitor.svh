// rebuilds packets from the wires alone. drives nothing

class axis_monitor extends uvm_monitor;

   `uvm_component_utils(axis_monitor)

   virtual axis_if vif;
   uvm_analysis_port #(axis_pkt) ap;
   int unsigned n_beats;

   function new(string name, uvm_component parent);
      super.new(name, parent);
      n_beats = 0;
   endfunction

   function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      ap = new("ap", this);
      if (!uvm_config_db #(virtual axis_if)::get(this, "", "vif", vif))
         `uvm_fatal("NOVIF", "no virtual interface set for the monitor")
   endfunction

   task run_phase(uvm_phase phase);
      axis_pkt p;
      p = axis_pkt::type_id::create("p");
      forever begin
         @(vif.mon_cb);
         if (!vif.aresetn) begin
            p = axis_pkt::type_id::create("p");
            continue;
         end
         if (vif.mon_cb.tvalid === 1'b1 && vif.mon_cb.tready !== 1'b1) begin
            p.stall_cycles++;
            if (vif.mon_cb.tlast === 1'b1)
               p.stalled_on_last = 1'b1;
         end
         if (vif.mon_cb.tvalid === 1'b1 && vif.mon_cb.tready === 1'b1) begin
            p.beats.push_back(vif.mon_cb.tdata);
            n_beats++;
            if (vif.mon_cb.tlast === 1'b1) begin
               `uvm_info("MON", p.convert2string(), UVM_HIGH)
               ap.write(p);
               p = axis_pkt::type_id::create("p");
            end
         end
      end
   endtask : run_phase

endclass : axis_monitor
