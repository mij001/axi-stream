// what was really exercised, from the observed packet

class axis_coverage extends uvm_subscriber #(axis_pkt);

   `uvm_component_utils(axis_coverage)

   int unsigned beats;
   int unsigned stalls;
   bit          last_stalled;
   int unsigned n_sampled;

   int unsigned n_none, n_few, n_some, n_many;
   int unsigned n_clean, n_stalled;

   covergroup cg_pkt;
      // one bin. this master sends PKT_LEN and nothing else
      cp_beats: coverpoint beats {
         bins full = {PKT_LEN};
      }
      cp_stalls: coverpoint stalls {
         bins none = {0};
         bins few  = {[1:2]};
         bins some = {[3:5]};
         bins many = {[6:1000]};
      }
      cp_last: coverpoint last_stalled {
         bins clean   = {1'b0};
         bins stalled = {1'b1};
      }
      // no stalls and stalled on the last beat cannot both happen
      x_stalls_last: cross cp_stalls, cp_last {
         ignore_bins impossible = binsof(cp_stalls.none) && binsof(cp_last.stalled);
      }
   endgroup

   function new(string name, uvm_component parent);
      super.new(name, parent);
      n_sampled = 0;
      n_none = 0; n_few = 0; n_some = 0; n_many = 0;
      n_clean = 0; n_stalled = 0;
      cg_pkt = new();
   endfunction

   function void write(axis_pkt t);
      beats        = t.beats.size();
      stalls       = t.stall_cycles;
      last_stalled = t.stalled_on_last;
      cg_pkt.sample();
      n_sampled++;

      if      (stalls == 0) n_none++;
      else if (stalls <= 2) n_few++;
      else if (stalls <= 5) n_some++;
      else                  n_many++;

      if (last_stalled) n_stalled++;
      else              n_clean++;
   endfunction : write

   function void report_phase(uvm_phase phase);
      `uvm_info("COV", $sformatf("COVERAGE:   cg_pkt %0.2f%% over %0d samples",
                                 cg_pkt.get_inst_coverage(), n_sampled), UVM_LOW)
      `uvm_info("COV", $sformatf("COVER stalls none/few/some/many : %0d / %0d / %0d / %0d",
                                 n_none, n_few, n_some, n_many), UVM_LOW)
      `uvm_info("COV", $sformatf("COVER last beat clean / stalled : %0d / %0d",
                                 n_clean, n_stalled), UVM_LOW)
   endfunction

endclass : axis_coverage
