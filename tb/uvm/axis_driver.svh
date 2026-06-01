// the only class that moves a pin

class axis_driver extends uvm_driver #(axis_item);

   `uvm_component_utils(axis_driver)

   virtual axis_if vif;

   function new(string name, uvm_component parent);
      super.new(name, parent);
   endfunction

   function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db #(virtual axis_if)::get(this, "", "vif", vif))
         `uvm_fatal("NOVIF", "no virtual interface set for the driver")
   endfunction

   task run_phase(uvm_phase phase);
      axis_item req;
      // nothing is accepted while reset is low, and run_phase starts at time
      // zero, so the driver waits for reset itself
      wait (vif.aresetn === 1'b1);
      forever begin
         seq_item_port.get_next_item(req);
         drive(req);
         seq_item_port.item_done();
      end
   endtask : run_phase

   // own generator so a seed reproduces a run in any simulator
   local function int unsigned next_rand(ref int unsigned s);
      s = (s * 32'd1103515245) + 32'd12345;
      return (s >> 16) & 32'h7fff;
   endfunction

   task drive(axis_item it);
      int unsigned s;
      int unsigned pct;
      int          guard;
      int          hs_count;

      s        = it.pause_seed;
      guard    = 0;
      hs_count = 0;

      // line up with the clocking event first or the write is just lost, and
      // BP_LAST needs the packet to start on a known phase or it misses the beat
      @(vif.drv_cb);
      vif.drv_cb.pause <= 1'b0;
      repeat (it.start_gap) @(vif.drv_cb);

      vif.drv_cb.start <= 1'b1;
      @(vif.drv_cb);
      vif.drv_cb.start <= 1'b0;

      // hold the chosen backpressure until the slave says the packet closed
      while (!vif.drv_cb.pkt_done && guard < 1000) begin
         case (it.bp)
            BP_NONE:  vif.drv_cb.pause <= 1'b0;
            BP_LIGHT: begin
               pct = next_rand(s) % 100;
               vif.drv_cb.pause <= (pct < 15);
            end
            BP_HEAVY: begin
               pct = next_rand(s) % 100;
               vif.drv_cb.pause <= (pct < 60);
            end
            // pause HIGH during the tlast transfer, that is what puts both flags up
            BP_LAST: begin
               if (vif.drv_cb.tvalid && vif.drv_cb.tready)
                  hs_count++;
               vif.drv_cb.pause <= (hs_count == (PKT_LEN - 1));
            end
            default:  vif.drv_cb.pause <= 1'b0;
         endcase
         @(vif.drv_cb);
         guard++;
      end

      vif.drv_cb.pause <= 1'b0;
      if (guard >= 1000)
         `uvm_fatal("DRV", $sformatf("packet never completed. bp=%s gap=%0d",
                                     it.bp.name(), it.start_gap))
   endtask : drive

endclass : axis_driver
