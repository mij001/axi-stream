`timescale 1ns / 1ps

// randomised. +seed= +pause_pct= +start_pct=

module tb_axis_random;

    localparam integer DATA_W  = 32;
    localparam integer PKT_LEN = 4;
    localparam integer N_CYC   = 20000;

    reg  aclk    = 1'b0;
    reg  aresetn = 1'b0;
    reg  start   = 1'b0;
    reg  pause   = 1'b0;

    wire              busy;
    wire              tvalid;
    wire              tready;
    wire [DATA_W-1:0] tdata;
    wire              tlast;

    wire              word_valid;
    wire [DATA_W-1:0] word_data;
    wire              pkt_done;
    wire [7:0]        word_count;
    wire [DATA_W-1:0] rd_data;

    integer seed;
    integer pause_pct;
    integer start_pct;

    // $random(seed) writes a new value back into seed every call, so the values given
    integer seed0;
    integer pause_pct0;
    integer start_pct0;

    integer cyc;
    integer beats_seen;
    integer pkts_requested;
    integer pkts_reported;
    integer errors;

    // coverage counters. each one counts how often a named corner case occurred
    integer cov_stall_mid_packet;     // stalled on a beat that is not the last
    integer cov_stall_on_last;        // stalled on the TLAST beat
    integer cov_pause_with_tlast_hs;  // pause arrives in the same cycle as the TLAST transfer
    integer cov_start_while_busy;     // start pulse while a packet is already in flight
    integer cov_start_on_last_hs;     // start arrives in the same cycle the packet ends
    integer cov_long_stall;           // a stall lasting 5 or more cycles
    integer stall_run;
    integer longest_stall;

    always #5 aclk = ~aclk;

    axis_master_basic #(.DATA_W(DATA_W), .PKT_LEN(PKT_LEN)) u_master (
        .aclk          (aclk),
        .aresetn       (aresetn),
        .start         (start),
        .busy          (busy),
        .m_axis_tvalid (tvalid),
        .m_axis_tready (tready),
        .m_axis_tdata  (tdata),
        .m_axis_tlast  (tlast)
    );

    axis_slave_basic #(.DATA_W(DATA_W), .MEM_DEPTH(16)) u_slave (
        .aclk          (aclk),
        .aresetn       (aresetn),
        .s_axis_tvalid (tvalid),
        .s_axis_tready (tready),
        .s_axis_tdata  (tdata),
        .s_axis_tlast  (tlast),
        .pause         (pause),
        .word_valid    (word_valid),
        .word_data     (word_data),
        .pkt_done      (pkt_done),
        .word_count    (word_count),
        .rd_addr       (4'd0),
        .rd_data       (rd_data)
    );

    axis_protocol_checker #(.DATA_W(DATA_W), .NAME("master->slave")) u_chk (
        .aclk    (aclk),
        .aresetn (aresetn),
        .tvalid  (tvalid),
        .tready  (tready),
        .tdata   (tdata),
        .tlast   (tlast)
    );

    // random stimulus. driven on the falling edge so that every input is stable long
    always @(negedge aclk) begin
        if (aresetn) begin
            pause <= ({$random(seed)} % 100) < pause_pct;
            start <= ({$random(seed)} % 100) < start_pct;
        end
    end

    // scoreboard and coverage, sampled at every rising edge
    always @(posedge aclk) begin
        if (aresetn) begin
            // a request only counts if the master was idle to hear it
            if (start && !busy)
                pkts_requested = pkts_requested + 1;

            if (tvalid && tready) begin
                if (tdata !== (32'h000000A0 + (beats_seen % PKT_LEN))) begin
                    $display("SCOREBOARD FAIL at cycle %0d: expected 0x%08h saw 0x%08h",
                             cyc, 32'h000000A0 + (beats_seen % PKT_LEN), tdata);
                    errors = errors + 1;
                end
                if (tlast !== ((beats_seen % PKT_LEN) == PKT_LEN - 1)) begin
                    $display("SCOREBOARD FAIL at cycle %0d: TLAST wrong on beat %0d",
                             cyc, beats_seen % PKT_LEN);
                    errors = errors + 1;
                end
                beats_seen = beats_seen + 1;
            end

            if (pkt_done) begin
                pkts_reported = pkts_reported + 1;
                if (word_count !== PKT_LEN) begin
                    $display("SCOREBOARD FAIL at cycle %0d: slave reported %0d words", cyc, word_count);
                    errors = errors + 1;
                end
            end

            if (tvalid && !tready && !tlast) cov_stall_mid_packet    = cov_stall_mid_packet + 1;
            if (tvalid && !tready &&  tlast) cov_stall_on_last       = cov_stall_on_last + 1;
            if (tvalid && tready && tlast && pause)
                                             cov_pause_with_tlast_hs = cov_pause_with_tlast_hs + 1;
            if (start && busy)               cov_start_while_busy    = cov_start_while_busy + 1;
            if (start && tvalid && tready && tlast)
                                             cov_start_on_last_hs    = cov_start_on_last_hs + 1;

            if (tvalid && !tready) begin
                stall_run = stall_run + 1;
                if (stall_run == 5)            cov_long_stall = cov_long_stall + 1;
                if (stall_run > longest_stall) longest_stall  = stall_run;
            end else begin
                stall_run = 0;
            end

            cyc = cyc + 1;
        end
    end

    initial begin
        if (!$value$plusargs("seed=%d", seed))           seed      = 1;
        if (!$value$plusargs("pause_pct=%d", pause_pct)) pause_pct = 30;
        if (!$value$plusargs("start_pct=%d", start_pct)) start_pct = 10;
        seed0      = seed;
        pause_pct0 = pause_pct;
        start_pct0 = start_pct;

        cyc = 0; beats_seen = 0; pkts_requested = 0; pkts_reported = 0; errors = 0;
        cov_stall_mid_packet = 0; cov_stall_on_last = 0; cov_pause_with_tlast_hs = 0;
        cov_start_while_busy = 0; cov_start_on_last_hs = 0; cov_long_stall = 0;
        stall_run = 0; longest_stall = 0;

        repeat (3) @(posedge aclk);
        @(negedge aclk);
        aresetn = 1'b1;

        repeat (N_CYC) @(posedge aclk);

        // stop making requests and let any packet in flight finish
        @(negedge aclk);
        start_pct = 0;
        pause_pct = 0;
        repeat (50) @(posedge aclk);

        $display("");
        $display("seed=%0d pause_pct=%0d start_pct=%0d cycles=%0d", seed0, pause_pct0, start_pct0, cyc);
        u_chk.report;
        $display("SCOREBOARD: %0d packets requested, %0d reported by slave, %0d beats, %0d mismatches",
                 pkts_requested, pkts_reported, beats_seen, errors);
        $display("COVER stall mid packet        : %0d cycles", cov_stall_mid_packet);
        $display("COVER stall on TLAST beat     : %0d cycles", cov_stall_on_last);
        $display("COVER pause with TLAST xfer   : %0d times",  cov_pause_with_tlast_hs);
        $display("COVER start while busy        : %0d times (ignored by this master)", cov_start_while_busy);
        $display("COVER start on last transfer  : %0d times", cov_start_on_last_hs);
        $display("COVER stalls of 5+ cycles     : %0d times, longest %0d", cov_long_stall, longest_stall);

        if (u_chk.errors == 0 && errors == 0 &&
            pkts_requested == pkts_reported &&
            beats_seen == pkts_reported * PKT_LEN)
            $display("RESULT: PASS");
        else
            $display("RESULT: FAIL");
        $display("");
        $finish;
    end

endmodule
