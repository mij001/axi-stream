`timescale 1ns / 1ps

// top for the uvm bench. makes a clock, holds reset, wires the design to the
// interface, hands the interface to the config db and calls run_test
// both slaves sit on the same link. slave A drives tready and is the real one,
// slave B sees the same inputs and the assertions below compare them every cycle
//   +UVM_TESTNAME=axis_test_random   mixed backpressure, the default
//   +UVM_TESTNAME=axis_test_last     every packet stalls on its tlast beat
//   +nitems=<n>

module tb_axis_uvm;

   import uvm_pkg::*;
   import axis_pkg::*;

   localparam int DATA_W  = 32;
   localparam int PKT_LEN = 4;

   logic aclk    = 1'b0;
   logic aresetn = 1'b0;

   always #5 aclk = ~aclk;

   axis_if #(.DATA_W(DATA_W)) vif (.aclk(aclk), .aresetn(aresetn));

   logic              a_tready, a_word_valid, a_pkt_done;
   logic [DATA_W-1:0] a_word_data, a_rd_data;
   logic [7:0]        a_word_count;

   logic              b_tready, b_word_valid, b_pkt_done;
   logic [DATA_W-1:0] b_word_data, b_rd_data;
   logic [7:0]        b_word_count;

   axis_master_basic #(.DATA_W(DATA_W), .PKT_LEN(PKT_LEN)) u_master (
      .aclk          (aclk),
      .aresetn       (aresetn),
      .start         (vif.start),
      .busy          (vif.busy),
      .m_axis_tvalid (vif.tvalid),
      .m_axis_tready (vif.tready),
      .m_axis_tdata  (vif.tdata),
      .m_axis_tlast  (vif.tlast)
   );

   axis_slave_basic #(.DATA_W(DATA_W)) u_slave_a (
      .aclk (aclk), .aresetn (aresetn),
      .s_axis_tvalid (vif.tvalid), .s_axis_tready (a_tready),
      .s_axis_tdata  (vif.tdata),  .s_axis_tlast  (vif.tlast),
      .pause (vif.pause), .word_valid (a_word_valid), .word_data (a_word_data),
      .pkt_done (a_pkt_done), .word_count (a_word_count),
      .rd_addr (4'd0), .rd_data (a_rd_data)
   );

   axis_slave_flags #(.DATA_W(DATA_W)) u_slave_b (
      .aclk (aclk), .aresetn (aresetn),
      .s_axis_tvalid (vif.tvalid), .s_axis_tready (b_tready),
      .s_axis_tdata  (vif.tdata),  .s_axis_tlast  (vif.tlast),
      .pause (vif.pause), .word_valid (b_word_valid), .word_data (b_word_data),
      .pkt_done (b_pkt_done), .word_count (b_word_count),
      .rd_addr (4'd0), .rd_data (b_rd_data)
   );

   // slave A is the one in the loop
   assign vif.tready     = a_tready;
   assign vif.word_valid = a_word_valid;
   assign vif.word_data  = a_word_data;
   assign vif.pkt_done   = a_pkt_done;
   assign vif.word_count = a_word_count;

   // the two slaves must agree, every output, every cycle
   a_equiv_tready: assert property (@(posedge aclk) disable iff (!aresetn)
      a_tready === b_tready)
      else $error("slaves disagree on TREADY: A=%b B=%b", a_tready, b_tready);
   a_equiv_valid: assert property (@(posedge aclk) disable iff (!aresetn)
      a_word_valid === b_word_valid) else $error("slaves disagree on word_valid");
   a_equiv_done: assert property (@(posedge aclk) disable iff (!aresetn)
      a_pkt_done === b_pkt_done) else $error("slaves disagree on pkt_done");
   a_equiv_count: assert property (@(posedge aclk) disable iff (!aresetn)
      a_word_count === b_word_count) else $error("slaves disagree on word_count");
   a_equiv_data: assert property (@(posedge aclk) disable iff (!aresetn)
      a_word_valid |-> (a_word_data === b_word_data))
      else $error("slaves disagree on word_data");

   // the corner the whole flags rewrite exists for, as a plain counter, because
   // a cover property that never fires looks like one that was never written
   int unsigned n_both_flags = 0;
   always @(posedge aclk)
      if (aresetn && u_slave_b.stall_q && u_slave_b.closing_q)
         n_both_flags++;

   initial begin
      uvm_config_db #(virtual axis_if)::set(null, "*", "vif", vif);
      repeat (4) @(posedge aclk);
      aresetn <= 1'b1;
   end

   initial begin
      run_test();
   end

   final
      $display("COVER both flags high in the flag slave: %0d cycles", n_both_flags);

endmodule : tb_axis_uvm
