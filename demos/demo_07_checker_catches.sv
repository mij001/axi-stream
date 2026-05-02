`timescale 1ns / 1ps
// demo 7. the checker catching a bug nobody wrote a test for
// one wrong line in b2, the beat counter advances every cycle in ST_SEND
// instead of only on a handshake
// against a slave that never stalls it looks perfect

module broken_master #(
    parameter integer PKT_LEN = 4
) (
    input  wire        aclk,
    input  wire        aresetn,
    input  wire        start,
    output reg         m_axis_tvalid,
    input  wire        m_axis_tready,
    output reg  [31:0] m_axis_tdata,
    output reg         m_axis_tlast
);
    localparam [0:0] ST_IDLE = 1'b0;
    localparam [0:0] ST_SEND = 1'b1;

    reg [0:0] state_q, state_d;
    reg [1:0] beat_q,  beat_d;

    wire last_beat = (beat_q == 2'd3);

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            state_q <= ST_IDLE;
            beat_q  <= 2'd0;
        end else begin
            state_q <= state_d;
            beat_q  <= beat_d;
        end
    end

    always @(*) begin
        state_d = state_q;
        beat_d  = beat_q;
        case (state_q)
            ST_IDLE: if (start) begin state_d = ST_SEND; beat_d = 2'd0; end
            ST_SEND: begin
                // THE BUG: no "if (handshake)" around these lines
                beat_d = beat_q + 2'd1;
                if (last_beat) state_d = ST_IDLE;
            end
            default: begin state_d = ST_IDLE; beat_d = 2'd0; end
        endcase
    end

    always @(*) begin
        m_axis_tvalid = (state_q == ST_SEND);
        m_axis_tdata  = (state_q == ST_SEND) ? (32'hA0 + beat_q) : 32'd0;
        m_axis_tlast  = (state_q == ST_SEND) && last_beat;
    end
endmodule


module demo_07_checker_catches;
    reg aclk = 1'b0, aresetn = 1'b0, start = 1'b0, pause = 1'b0;
    always #5 aclk = ~aclk;

    wire        tvalid, tready, tlast, word_valid, pkt_done;
    wire [31:0] tdata, word_data, rd_data;
    wire [7:0]  word_count;

    broken_master u_m (.aclk(aclk), .aresetn(aresetn), .start(start),
                       .m_axis_tvalid(tvalid), .m_axis_tready(tready),
                       .m_axis_tdata(tdata), .m_axis_tlast(tlast));

    axis_slave_basic u_s (.aclk(aclk), .aresetn(aresetn),
                          .s_axis_tvalid(tvalid), .s_axis_tready(tready),
                          .s_axis_tdata(tdata), .s_axis_tlast(tlast),
                          .pause(pause), .word_valid(word_valid), .word_data(word_data),
                          .pkt_done(pkt_done), .word_count(word_count),
                          .rd_addr(4'd0), .rd_data(rd_data));

    axis_protocol_checker #(.DATA_W(32), .NAME("broken")) u_chk (
        .aclk(aclk), .aresetn(aresetn), .tvalid(tvalid), .tready(tready),
        .tdata(tdata), .tlast(tlast));

    initial begin
        repeat (3) @(posedge aclk);
        @(negedge aclk) aresetn = 1'b1;

        $display("");
        $display("--- run 1: slave never stalls ---");
        @(negedge aclk) start = 1'b1;
        @(negedge aclk) start = 1'b0;
        repeat (8) @(posedge aclk);
        u_chk.report;

        $display("");
        $display("--- run 2: slave stalls for two cycles in the middle ---");
        @(negedge aclk) start = 1'b1;
        @(negedge aclk) begin start = 1'b0; pause = 1'b1; end
        repeat (2) @(negedge aclk);
        pause = 1'b0;
        repeat (8) @(posedge aclk);
        u_chk.report;
        $display("");
        $finish;
    end
endmodule

// the same broken master, seen by the assertions in sva/axis_sva.sv. the hand written
bind broken_master axis_sva #(
    .DATA_W (32),
    .NAME   ("broken")
) u_sva (
    .aclk    (aclk),
    .aresetn (aresetn),
    .tvalid  (m_axis_tvalid),
    .tready  (m_axis_tready),
    .tdata   (m_axis_tdata),
    .tlast   (m_axis_tlast)
);
