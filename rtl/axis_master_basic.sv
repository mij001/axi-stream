`timescale 1ns / 1ps

// axi4-stream master. three always block form, b1 regs b2 next b3 out


module axis_master_basic #(
    parameter int DATA_W  = 32,   // TDATA width in bits, a multiple of 8
    parameter int PKT_LEN = 4     // transfers in one packet
) (
    input  logic                aclk,
    input  logic                aresetn,   // active LOW

    // local control, not part of AXI4-Stream
    input  logic                start,     // pulse high while idle to send a packet
    output logic                busy,      // high while a packet is in flight

    // AXI4-Stream master port
    output logic                m_axis_tvalid,
    input  logic                m_axis_tready,
    output logic [DATA_W-1:0]   m_axis_tdata,
    output logic                m_axis_tlast
);

    // enum so the default case really is impossible
    typedef enum logic {
        ST_IDLE = 1'b0,   // TVALID low
        ST_SEND = 1'b1    // TVALID high
    } state_e;

    localparam int          CNT_W       = (PKT_LEN <= 1) ? 1 : $clog2(PKT_LEN);
    localparam int          LAST_BEAT_I = PKT_LEN - 1;
    localparam logic [CNT_W-1:0]  LAST_BEAT = LAST_BEAT_I[CNT_W-1:0];
    localparam logic [DATA_W-1:0] SEED      = {{(DATA_W-8){1'b0}}, 8'hA0};

    // _q now, _d next
    state_e            state_q, state_d;
    logic  [CNT_W-1:0] beat_q,  beat_d;

    // plain gates
    logic last_beat, handshake;
    assign last_beat = (beat_q == LAST_BEAT);
    assign handshake = m_axis_tvalid & m_axis_tready;

    // b1
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            state_q <= ST_IDLE;
            beat_q  <= '0;
        end else begin
            state_q <= state_d;
            beat_q  <= beat_d;
        end
    end

    // b2
    always_comb begin
        // default is hold
        state_d = state_q;
        beat_d  = beat_q;

        unique case (state_q)
            ST_IDLE: begin
                // tvalid low here. no tready allowed in this branch
                if (start) begin
                    state_d = ST_SEND;
                    beat_d  = '0;
                end
            end

            ST_SEND: begin
                // tvalid high. nothing changes without a handshake
                if (handshake) begin
                    if (last_beat) begin
                        state_d = ST_IDLE;
                        beat_d  = '0;
                    end else begin
                        beat_d  = beat_q + 1'b1;
                    end
                end
            end

            default: begin
                state_d = ST_IDLE;
                beat_d  = '0;
            end
        endcase
    end

    // b3
    always_comb begin
        m_axis_tvalid = 1'b0;
        m_axis_tdata  = '0;
        m_axis_tlast  = 1'b0;
        busy          = 1'b0;

        unique case (state_q)
            ST_IDLE: begin
            end

            ST_SEND: begin
                m_axis_tvalid = 1'b1;
                m_axis_tdata  = SEED + {{(DATA_W-CNT_W){1'b0}}, beat_q};
                m_axis_tlast  = last_beat;
                busy          = 1'b1;
            end

            default: begin
            end
        endcase
    end

endmodule
