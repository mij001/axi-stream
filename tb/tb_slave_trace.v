`timescale 1ns / 1ps

// the pause during tlast corner on its own, both slaves side by side

module tb_slave_trace;

    reg aclk    = 1'b0;
    reg aresetn = 1'b0;
    reg start   = 1'b0;
    reg pause   = 1'b0;

    wire        busy, tvalid, tlast;
    wire [31:0] tdata;

    wire        tready_a,     tready_b;
    wire        word_valid_a, word_valid_b;
    wire [31:0] word_data_a,  word_data_b;
    wire        pkt_done_a,   pkt_done_b;
    wire [7:0]  word_count_a, word_count_b;
    wire [31:0] rd_data_a,    rd_data_b;

    integer cyc;

    always #5 aclk = ~aclk;

    axis_master_basic #(.DATA_W(32), .PKT_LEN(4)) u_master (
        .aclk(aclk), .aresetn(aresetn), .start(start), .busy(busy),
        .m_axis_tvalid(tvalid), .m_axis_tready(tready_a),
        .m_axis_tdata(tdata), .m_axis_tlast(tlast)
    );

    axis_slave_basic u_a (
        .aclk(aclk), .aresetn(aresetn),
        .s_axis_tvalid(tvalid), .s_axis_tready(tready_a),
        .s_axis_tdata(tdata), .s_axis_tlast(tlast),
        .pause(pause), .word_valid(word_valid_a), .word_data(word_data_a),
        .pkt_done(pkt_done_a), .word_count(word_count_a),
        .rd_addr(4'd0), .rd_data(rd_data_a)
    );

    axis_slave_flags u_b (
        .aclk(aclk), .aresetn(aresetn),
        .s_axis_tvalid(tvalid), .s_axis_tready(tready_b),
        .s_axis_tdata(tdata), .s_axis_tlast(tlast),
        .pause(pause), .word_valid(word_valid_b), .word_data(word_data_b),
        .pkt_done(pkt_done_b), .word_count(word_count_b),
        .rd_addr(4'd0), .rd_data(rd_data_b)
    );

    function [39:0] state_name;
        input [1:0] s;
        begin
            case (s)
                2'd0:    state_name = "RX   ";
                2'd1:    state_name = "STALL";
                2'd2:    state_name = "EOP  ";
                default: state_name = "???  ";
            endcase
        end
    endfunction

    always @(posedge aclk) begin
        if (aresetn) begin
            $display("cyc %2d | pause=%b TVALID=%b TLAST=%b xfer=%b | A: %s TREADY=%b cnt=%0d done=%b | B: stall=%b closing=%b TREADY=%b cnt=%0d done=%b",
                     cyc, pause, tvalid, tlast, (tvalid && tready_a),
                     state_name(u_a.state_q), tready_a, word_count_a, pkt_done_a,
                     u_b.stall_q, u_b.closing_q, tready_b, word_count_b, pkt_done_b);
            cyc = cyc + 1;
        end
    end

    initial begin
        cyc = 0;
        repeat (3) @(posedge aclk);
        @(negedge aclk) aresetn = 1'b1;

        @(negedge aclk) start = 1'b1;
        @(negedge aclk) start = 1'b0;

        //  wait until the master is offering the TLAST beat to a ready slave, then
        while (!(tvalid && tlast && tready_a)) @(negedge aclk);
        pause = 1'b1;
        repeat (3) @(negedge aclk);
        pause = 1'b0;
        repeat (3) @(negedge aclk);

        $finish;
    end

endmodule
