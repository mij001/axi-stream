`timescale 1ns / 1ps

// the link and the two local controls. clocking blocks so the driver does not
// race the design


interface axis_if #(
    parameter int DATA_W = 32
) (
    input logic aclk,
    input logic aresetn
);

    logic              tvalid;
    logic              tready;
    logic [DATA_W-1:0] tdata;
    logic              tlast;

    // local controls, not part of the protocol
    logic              start = 1'b0;   // pulse to the master
    logic              pause = 1'b0;   // hold high to stall the slave

    logic              word_valid;
    logic [DATA_W-1:0] word_data;
    logic              pkt_done;
    logic [7:0]        word_count;
    logic              busy;

    // driver side: outputs are applied after the edge
    clocking drv_cb @(posedge aclk);
        default input #1step output #0;
        output start, pause;
        input  tvalid, tready, tdata, tlast, busy, pkt_done, word_count;
    endclocking

    // monitor side: everything is an input, sampled just before the edge
    clocking mon_cb @(posedge aclk);
        default input #1step;
        input tvalid, tready, tdata, tlast;
        input word_valid, word_data, pkt_done, word_count, busy;
    endclocking

    modport drv (clocking drv_cb, input aclk, aresetn);
    modport mon (clocking mon_cb, input aclk, aresetn);

endinterface
