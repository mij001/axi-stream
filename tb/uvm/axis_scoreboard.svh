// knows what the design promised. never looks at a pin

class axis_scoreboard extends uvm_subscriber #(axis_pkt);

   `uvm_component_utils(axis_scoreboard)

   int unsigned n_pkt;
   int unsigned n_err;

   function new(string name, uvm_component parent);
      super.new(name, parent);
      n_pkt = 0;
      n_err = 0;
   endfunction

   function void write(axis_pkt t);
      logic [DATA_W-1:0] want;
      n_pkt++;

      if (t.beats.size() != PKT_LEN) begin
         `uvm_error("SB", $sformatf("packet %0d had %0d beats, expected %0d",
                                    n_pkt, t.beats.size(), PKT_LEN))
         n_err++;
         return;
      end

      foreach (t.beats[i]) begin
         want = SEED + DATA_W'(i);
         if (t.beats[i] !== want) begin
            `uvm_error("SB", $sformatf("packet %0d beat %0d was 0x%0h, expected 0x%0h",
                                       n_pkt, i, t.beats[i], want))
            n_err++;
         end
      end
   endfunction : write

   function void report_phase(uvm_phase phase);
      `uvm_info("SB", $sformatf("SCOREBOARD: %0d packets checked, %0d errors",
                                n_pkt, n_err), UVM_LOW)
   endfunction

endclass : axis_scoreboard
