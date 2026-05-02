`timescale 1ns / 1ps

// slave. one state so b2 needs a priority rule for pause vs closing a packet


module axis_slave_basic #(
    parameter int DATA_W    = 32,
    parameter int MEM_DEPTH = 16
) (
    input  logic                aclk,
    input  logic                aresetn,

    // slave port. tready is the only output
    input  logic                s_axis_tvalid,
    output logic                s_axis_tready,
    input  logic [DATA_W-1:0]   s_axis_tdata,
    input  logic                s_axis_tlast,

    // local control and status, not part of the protocol
    input  logic                pause,       // hold high to make the slave stall
    output logic                word_valid,  // one cycle pulse per accepted transfer
    output logic [DATA_W-1:0]   word_data,   // payload of that transfer
    output logic                pkt_done,    // one cycle pulse after a TLAST transfer
    output logic [7:0]          word_count,  // words accepted in the current packet

    // debug read port into the mem, outside the state machine
    input  logic [3:0]          rd_addr,
    output logic [DATA_W-1:0]   rd_data
);

    typedef enum logic [1:0] {
        ST_RX    = 2'd0,   // TREADY high
        ST_STALL = 2'd1,   // TREADY low, because pause is high
        ST_EOP   = 2'd2    // TREADY low for one cycle after TLAST
    } state_e;

    localparam int ADDR_W = (MEM_DEPTH <= 1) ? 1 : $clog2(MEM_DEPTH);

    // _q now, _d next
    state_e             state_q,      state_d;
    logic [ADDR_W-1:0]  wr_ptr_q,     wr_ptr_d;
    logic [7:0]         word_count_q, word_count_d;
    logic               word_valid_q, word_valid_d;
    logic [DATA_W-1:0]  word_data_q,  word_data_d;
    logic               pkt_done_q,   pkt_done_d;

    logic [DATA_W-1:0] mem [0:MEM_DEPTH-1];
    logic              mem_we;              // decided in b2

    logic handshake;
    assign handshake = s_axis_tvalid & s_axis_tready;

    // b1
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            state_q      <= ST_RX;
            wr_ptr_q     <= '0;
            word_count_q <= 8'd0;
            word_valid_q <= 1'b0;
            word_data_q  <= '0;
            pkt_done_q   <= 1'b0;
        end else begin
            state_q      <= state_d;
            wr_ptr_q     <= wr_ptr_d;
            word_count_q <= word_count_d;
            word_valid_q <= word_valid_d;
            word_data_q  <= word_data_d;
            pkt_done_q   <= pkt_done_d;

            // the mem's own we pin, decided in b2
            if (mem_we)
                mem[wr_ptr_q] <= s_axis_tdata;
        end
    end

    // b2
    always_comb begin
        // stored values hold, pulses and the we fall to zero
        state_d      = state_q;
        wr_ptr_d     = wr_ptr_q;
        word_count_d = word_count_q;
        word_data_d  = word_data_q;
        word_valid_d = 1'b0;
        pkt_done_d   = 1'b0;
        mem_we       = 1'b0;

        unique case (state_q)
            ST_RX: begin
                // datapath side
                if (handshake) begin
                    mem_we       = 1'b1;
                    word_data_d  = s_axis_tdata;
                    word_valid_d = 1'b1;
                    wr_ptr_d     = wr_ptr_q + 1'b1;
                    word_count_d = word_count_q + 8'd1;
                end

                // control side. closing a packet beats pausing
                if (handshake && s_axis_tlast) begin
                    pkt_done_d = 1'b1;
                    state_d    = ST_EOP;
                end else if (pause) begin
                    state_d    = ST_STALL;
                end
            end

            ST_STALL: begin
                if (!pause)
                    state_d = ST_RX;
            end

            ST_EOP: begin
                wr_ptr_d     = '0;
                word_count_d = 8'd0;
                // if/else not a ternary. icarus wants a cast on the enum
                if (pause) state_d = ST_STALL;
                else       state_d = ST_RX;
            end

            default: begin
                state_d      = ST_RX;
                wr_ptr_d     = '0;
                word_count_d = 8'd0;
            end
        endcase
    end

    // b3
    always_comb begin
        s_axis_tready = 1'b0;
        word_valid    = word_valid_q;
        word_data     = word_data_q;
        pkt_done      = pkt_done_q;
        word_count    = word_count_q;

        unique case (state_q)
            ST_RX:    s_axis_tready = 1'b1;
            ST_STALL: s_axis_tready = 1'b0;
            ST_EOP:   s_axis_tready = 1'b0;
            default:  s_axis_tready = 1'b0;
        endcase
    end

    // plain lookup, outside the state machine, so b3 rules do not apply
    assign rd_data = mem[rd_addr[ADDR_W-1:0]];

endmodule
