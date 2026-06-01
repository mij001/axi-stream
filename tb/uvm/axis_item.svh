// one packet request, and how the slave should push back while it runs

class axis_item extends uvm_sequence_item;

   rand int unsigned start_gap;    // idle cycles before asking for a packet
   rand bp_e         bp;           // backpressure style
   rand int unsigned pause_seed;   // seeds this packet's stall pattern

   `uvm_object_utils_begin(axis_item)
      `uvm_field_int(start_gap,  UVM_ALL_ON | UVM_DEC)
      `uvm_field_enum(bp_e, bp,  UVM_ALL_ON)
      `uvm_field_int(pause_seed, UVM_ALL_ON | UVM_DEC)
   `uvm_object_utils_end

   function new(string name = "axis_item");
      super.new(name);
   endfunction

   // mostly short gaps. always back to back never exercises going idle
   constraint c_gap {
      start_gap inside {[0:10]};
      start_gap dist {0 := 30, [1:3] := 45, [4:10] := 25};
   }

   // BP_LAST is the interesting one so it is weighted, not uniform
   constraint c_bp {
      bp dist {BP_NONE := 20, BP_LIGHT := 35, BP_HEAVY := 30, BP_LAST := 15};
   }

   constraint c_seed { pause_seed inside {[1:100000]}; }

   function string convert2string();
      return $sformatf("%s after %0d idle cycles, seed %0d",
                       bp.name(), start_gap, pause_seed);
   endfunction

endclass : axis_item
