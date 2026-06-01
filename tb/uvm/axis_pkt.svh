// what the monitor saw, built from the wires only

class axis_pkt extends uvm_sequence_item;

   logic [DATA_W-1:0] beats[$];
   int unsigned       stall_cycles;
   bit                stalled_on_last;

   `uvm_object_utils_begin(axis_pkt)
      `uvm_field_int(stall_cycles,    UVM_ALL_ON | UVM_DEC)
      `uvm_field_int(stalled_on_last, UVM_ALL_ON)
   `uvm_object_utils_end

   function new(string name = "axis_pkt");
      super.new(name);
      stall_cycles    = 0;
      stalled_on_last = 1'b0;
   endfunction

   function string convert2string();
      return $sformatf("%0d beats, %0d stall cycles%s", beats.size(),
                       stall_cycles, stalled_on_last ? ", stalled on last" : "");
   endfunction

endclass : axis_pkt
