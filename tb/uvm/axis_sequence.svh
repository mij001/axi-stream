// the constrained random one. xsim solves the constraint blocks itself

class axis_sequence extends uvm_sequence #(axis_item);

   `uvm_object_utils(axis_sequence)

   rand int unsigned n_items;
   constraint c_n { n_items inside {[1:100000]}; }

   function new(string name = "axis_sequence");
      super.new(name);
      n_items = 200;
   endfunction

   task body();
      axis_item req;
      repeat (n_items) begin
         req = axis_item::type_id::create("req");
         start_item(req);
         if (!req.randomize())
            `uvm_fatal("SEQ", "randomize failed")
         `uvm_info("SEQ", {"sending ", req.convert2string()}, UVM_HIGH)
         finish_item(req);
      end
   endtask : body

endclass : axis_sequence


// directed. every packet stalls on tlast, the corner the two slaves differ on
class axis_seq_last extends uvm_sequence #(axis_item);

   `uvm_object_utils(axis_seq_last)

   rand int unsigned n_items;
   constraint c_n { n_items inside {[1:100000]}; }

   function new(string name = "axis_seq_last");
      super.new(name);
      n_items = 200;
   endfunction

   task body();
      axis_item req;
      repeat (n_items) begin
         req = axis_item::type_id::create("req");
         start_item(req);
         if (!req.randomize() with { bp == BP_LAST; start_gap inside {[0:2]}; })
            `uvm_fatal("SEQ", "randomize failed")
         `uvm_info("SEQ", {"sending ", req.convert2string()}, UVM_HIGH)
         finish_item(req);
      end
   endtask : body

endclass : axis_seq_last
