`timescale 1ns / 1ps

// both slaves on the same stimulus, every output compared every cycle

module tb_slave_equiv;

    localparam integer DATA_W  = 32;
    localparam integer PKT_LEN = 4;
    localparam integer N_CYC   = 50000;

    reg aclk    = 1'b0;
    reg aresetn = 1'b0;
    reg start   = 1'b0;
    reg pause   = 1'b0;

    wire              busy;
    wire              tvalid;
    wire [DATA_W-1:0] tdata;
    wire              tlast;

    wire              tready_a,     tready_b;
    wire              word_valid_a, word_valid_b;
    wire [DATA_W-1:0] word_data_a,  word_data_b;
    wire              pkt_done_a,   pkt_done_b;
    wire [7:0]        word_count_a, word_count_b;
    wire [DATA_W-1:0] rd_data_a,    rd_data_b;
    reg  [3:0]        rd_addr = 4'd0;

    integer seed;
    integer seed0;
    integer cyc;
    integer mismatches;
    integer reachable_both_flags;
    integer i;

    always #5 aclk = ~aclk;

    axis_master_basic #(.DATA_W(DATA_W), .PKT_LEN(PKT_LEN)) u_master (
        .aclk(aclk), .aresetn(aresetn), .start(start), .busy(busy),
        .m_axis_tvalid(tvalid), .m_axis_tready(tready_a),
        .m_axis_tdata(tdata), .m_axis_tlast(tlast)
    );

    axis_slave_basic #(.DATA_W(DATA_W)) u_a (
        .aclk(aclk), .aresetn(aresetn),
        .s_axis_tvalid(tvalid), .s_axis_tready(tready_a),
        .s_axis_tdata(tdata), .s_axis_tlast(tlast),
        .pause(pause), .word_valid(word_valid_a), .word_data(word_data_a),
        .pkt_done(pkt_done_a), .word_count(word_count_a),
        .rd_addr(rd_addr), .rd_data(rd_data_a)
    );

    axis_slave_flags #(.DATA_W(DATA_W)) u_b (
        .aclk(aclk), .aresetn(aresetn),
        .s_axis_tvalid(tvalid), .s_axis_tready(tready_b),
        .s_axis_tdata(tdata), .s_axis_tlast(tlast),
        .pause(pause), .word_valid(word_valid_b), .word_data(word_data_b),
        .pkt_done(pkt_done_b), .word_count(word_count_b),
        .rd_addr(rd_addr), .rd_data(rd_data_b)
    );

    axis_protocol_checker #(.DATA_W(DATA_W), .NAME("master->slave")) u_chk (
        .aclk(aclk), .aresetn(aresetn), .tvalid(tvalid), .tready(tready_a),
        .tdata(tdata), .tlast(tlast)
    );

    always @(negedge aclk) begin
        if (aresetn) begin
            pause <= ({$random(seed)} % 100) < 35;
            start <= ({$random(seed)} % 100) < 20;
        end
    end

    always @(posedge aclk) begin
        if (aresetn) begin
            if (tready_a     !== tready_b     ||
                word_valid_a !== word_valid_b ||
                word_data_a  !== word_data_b  ||
                pkt_done_a   !== pkt_done_b   ||
                word_count_a !== word_count_b) begin
                if (mismatches < 5)
                    $display("MISMATCH at cycle %0d: TREADY %b/%b word_valid %b/%b pkt_done %b/%b count %0d/%0d",
                             cyc, tready_a, tready_b, word_valid_a, word_valid_b,
                             pkt_done_a, pkt_done_b, word_count_a, word_count_b);
                mismatches = mismatches + 1;
            end

            // cycles where the two-flag slave has both flags up
            if (u_b.stall_q && u_b.closing_q)
                reachable_both_flags = reachable_both_flags + 1;

            cyc = cyc + 1;
        end
    end

    initial begin
        if (!$value$plusargs("seed=%d", seed)) seed = 1;
        seed0 = seed;
        cyc = 0; mismatches = 0; reachable_both_flags = 0;

        repeat (3) @(posedge aclk);
        @(negedge aclk);
        aresetn = 1'b1;

        repeat (N_CYC) @(posedge aclk);

        // compare the two capture memories as well
        for (i = 0; i < 16; i = i + 1) begin
            @(negedge aclk);
            rd_addr = i[3:0];
            #1;
            if (rd_data_a !== rd_data_b) begin
                $display("MEMORY MISMATCH at address %0d: 0x%08h / 0x%08h", i, rd_data_a, rd_data_b);
                mismatches = mismatches + 1;
            end
        end

        $display("");
        $display("seed=%0d, %0d cycles compared", seed0, cyc);
        u_chk.report;
        $display("cycles where the flag slave had stall_q AND closing_q high: %0d", reachable_both_flags);
        $display("output mismatches between the two slaves: %0d", mismatches);
        if (mismatches == 0 && u_chk.errors == 0)
            $display("RESULT: EQUIVALENT on this run");
        else
            $display("RESULT: DIFFERENT");
        $display("");
        $finish;
    end

endmodule
