// directed. one line per cycle so it reads against a hand drawn diagram

`timescale 1ns / 1ps

module tb_axis_basic;

    localparam integer DATA_W  = 32;
    localparam integer PKT_LEN = 4;

    reg  aclk;
    reg  aresetn;
    reg  start;
    reg  pause;

    wire              busy;
    wire              tvalid;
    wire              tready;
    wire [DATA_W-1:0] tdata;
    wire              tlast;

    wire              word_valid;
    wire [DATA_W-1:0] word_data;
    wire              pkt_done;
    wire [7:0]        word_count;

    reg  [3:0]        rd_addr;
    wire [DATA_W-1:0] rd_data;

    integer cycle;
    integer beats_seen;
    integer errors;
    integer i;

    // clock. one full period is 10 ns, so a rising edge every 10 ns
    initial aclk = 1'b0;
    always #5 aclk = ~aclk;

    // device under test
    axis_master_basic #(
        .DATA_W  (DATA_W),
        .PKT_LEN (PKT_LEN)
    ) u_master (
        .aclk          (aclk),
        .aresetn       (aresetn),
        .start         (start),
        .busy          (busy),
        .m_axis_tvalid (tvalid),
        .m_axis_tready (tready),
        .m_axis_tdata  (tdata),
        .m_axis_tlast  (tlast)
    );

    axis_slave_basic #(
        .DATA_W    (DATA_W),
        .MEM_DEPTH (16)
    ) u_slave (
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
        .rd_addr       (rd_addr),
        .rd_data       (rd_data)
    );

    // passive rule checker watching the same wires
    axis_protocol_checker #(.DATA_W(DATA_W), .NAME("master->slave")) u_chk (
        .aclk    (aclk),
        .aresetn (aresetn),
        .tvalid  (tvalid),
        .tready  (tready),
        .tdata   (tdata),
        .tlast   (tlast)
    );

    // cycle counter, used only to label the printed log
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) cycle <= 0;
        else          cycle <= cycle + 1;
    end

    // one printed line per clock cycle. the values printed are the values that existed
    always @(posedge aclk) begin
        if (aresetn) begin
            $display("cyc %0d | start=%b busy=%b | TVALID=%b TREADY=%b TDATA=0x%08h TLAST=%b | %s",
                     cycle, start, busy, tvalid, tready, tdata, tlast,
                     (tvalid && tready) ? "<-- TRANSFER" : "");
        end
    end

    // independent scoreboard. it watches the same wires the slave watches and checks
    always @(posedge aclk) begin
        if (aresetn && tvalid && tready) begin
            if (tdata !== (32'h000000A0 + (beats_seen % PKT_LEN))) begin
                $display("  ERROR at cycle %0d: expected 0x%08h, saw 0x%08h",
                         cycle, 32'h000000A0 + (beats_seen % PKT_LEN), tdata);
                errors <= errors + 1;
            end
            if (tlast !== ((beats_seen % PKT_LEN) == PKT_LEN-1)) begin
                $display("  ERROR at cycle %0d: TLAST wrong on beat %0d",
                         cycle, beats_seen % PKT_LEN);
                errors <= errors + 1;
            end
            beats_seen <= beats_seen + 1;
        end
    end

    // report every completed packet as the slave sees it
    always @(posedge aclk) begin
        if (aresetn && pkt_done)
            $display("  >> slave reports packet complete, %0d words", word_count);
    end

    // stimulus
    initial begin
        $dumpfile("sim/tb_axis_basic.vcd");
        $dumpvars(0, tb_axis_basic);

        beats_seen = 0;
        errors     = 0;
        start      = 1'b0;
        pause      = 1'b0;
        rd_addr    = 4'd0;
        aresetn    = 1'b0;

        // hold reset for a few cycles, then release it synchronously after a rising
        repeat (3) @(posedge aclk);
        @(negedge aclk);
        aresetn = 1'b1;

        $display("");
        $display("=== Packet 1: slave never stalls, TREADY is high the whole time ===");
        @(posedge aclk);
        start = 1'b1;
        @(posedge aclk);
        start = 1'b0;

        wait (pkt_done == 1'b1);
        @(posedge aclk);
        repeat (2) @(posedge aclk);

        $display("");
        $display("=== Packet 2: slave stalls in the middle, TVALID must hold ===");
        @(posedge aclk);
        start = 1'b1;
        @(posedge aclk);
        start = 1'b0;

        // one transfer through, then drop TREADY for three cycles
        @(posedge aclk);
        pause = 1'b1;
        repeat (3) @(posedge aclk);
        pause = 1'b0;

        wait (pkt_done == 1'b1);
        repeat (4) @(posedge aclk);

        // read the capture buffer back out through the slave's read port
        $display("");
        $display("=== Contents of the slave capture buffer after packet 2 ===");
        for (i = 0; i < PKT_LEN; i = i + 1) begin
            rd_addr = i[3:0];
            #1;
            $display("  mem[%0d] = 0x%08h", i, rd_data);
        end

        $display("");
        u_chk.report;
        if (errors == 0 && u_chk.errors == 0 && beats_seen == 2*PKT_LEN)
            $display("RESULT: pass. %0d transfers, 0 errors.", beats_seen);
        else
            $display("RESULT: fail. %0d transfers, %0d errors.", beats_seen, errors);
        $display("");
        $finish;
    end

    // safety net so a protocol deadlock cannot hang the simulation forever
    initial begin
        #5000;
        $display("TIMEOUT: the simulation did not finish. Likely a stuck handshake.");
        $finish;
    end

endmodule
