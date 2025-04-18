`timescale 1ns / 1ps

// axi4-stream master. three always block form, b1 regs b2 next b3 out

module axis_master_basic #(
    parameter integer DATA_W  = 32,   // TDATA width in bits, a multiple of 8
    parameter integer PKT_LEN = 4     // transfers in one packet
) (
    input  wire                aclk,
    input  wire                aresetn,   // active LOW

    // local control, not part of AXI4-Stream
    input  wire                start,     // pulse high while idle to send a packet
    output reg                 busy,      // high while a packet is in flight

    // AXI4-Stream master port
    output reg                 m_axis_tvalid,
    input  wire                m_axis_tready,
    output reg  [DATA_W-1:0]   m_axis_tdata,
    output reg                 m_axis_tlast
);

    localparam [0:0] ST_IDLE = 1'b0;   // TVALID low
    localparam [0:0] ST_SEND = 1'b1;   // TVALID high

    localparam integer      CNT_W       = (PKT_LEN <= 1) ? 1 : $clog2(PKT_LEN);
    localparam integer      LAST_BEAT_I = PKT_LEN - 1;
    localparam [CNT_W-1:0]  LAST_BEAT   = LAST_BEAT_I[CNT_W-1:0];
    localparam [DATA_W-1:0] SEED        = {{(DATA_W-8){1'b0}}, 8'hA0};

    //  every register is a pair of names: _q is its value now, _d is its value next
    reg [0:0]       state_q, state_d;
    reg [CNT_W-1:0] beat_q,  beat_d;

    // named "now" helpers. plain gates, readable from any block
    wire last_beat = (beat_q == LAST_BEAT);
    wire handshake = m_axis_tvalid & m_axis_tready;

    //  ------------------------------------------------------------------------- Block
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            state_q <= ST_IDLE;
            beat_q  <= {CNT_W{1'b0}};
        end else begin
            state_q <= state_d;
            beat_q  <= beat_d;
        end
    end

    //  ------------------------------------------------------------------------- Block
    always @(*) begin
        // default for every register: next cycle, hold what you hold now
        state_d = state_q;
        beat_d  = beat_q;

        case (state_q)
            ST_IDLE: begin
                // we are leaving a TVALID-low state. TREADY must not appear here
                if (start) begin
                    state_d = ST_SEND;
                    beat_d  = {CNT_W{1'b0}};
                end
            end

            ST_SEND: begin
                //  we are in a TVALID-high state. nothing that changes what we drive
                if (handshake) begin
                    if (last_beat) begin
                        state_d = ST_IDLE;
                        beat_d  = {CNT_W{1'b0}};
                    end else begin
                        beat_d  = beat_q + 1'b1;
                    end
                end
            end

            default: begin
                state_d = ST_IDLE;
                beat_d  = {CNT_W{1'b0}};
            end
        endcase
    end

    //  ------------------------------------------------------------------------- Block
    always @(*) begin
        m_axis_tvalid = 1'b0;
        m_axis_tdata  = {DATA_W{1'b0}};
        m_axis_tlast  = 1'b0;
        busy          = 1'b0;

        case (state_q)
            ST_IDLE: begin
                // everything stays at its default
            end

            ST_SEND: begin
                m_axis_tvalid = 1'b1;
                m_axis_tdata  = SEED + {{(DATA_W-CNT_W){1'b0}}, beat_q};
                m_axis_tlast  = last_beat;
                busy          = 1'b1;
            end

            default: begin
                // everything stays at its default
            end
        endcase
    end

endmodule
