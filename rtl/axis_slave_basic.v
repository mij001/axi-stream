`timescale 1ns / 1ps

// slave. one state so b2 needs a priority rule for pause vs closing a packet

module axis_slave_basic #(
    parameter integer DATA_W    = 32,
    parameter integer MEM_DEPTH = 16
) (
    input  wire                aclk,
    input  wire                aresetn,

    // AXI4-Stream slave port. TREADY is the only output
    input  wire                s_axis_tvalid,
    output reg                 s_axis_tready,
    input  wire [DATA_W-1:0]   s_axis_tdata,
    input  wire                s_axis_tlast,

    // local control and status, not part of AXI4-Stream
    input  wire                pause,       // hold high to make the slave stall
    output reg                 word_valid,  // one cycle pulse per accepted transfer
    output reg  [DATA_W-1:0]   word_data,   // payload of that transfer
    output reg                 pkt_done,    // one cycle pulse after a TLAST transfer
    output reg  [7:0]          word_count,  // words accepted in the current packet

    // debug read port into the capture memory. not part of the state machine
    input  wire [3:0]          rd_addr,
    output wire [DATA_W-1:0]   rd_data
);

    localparam [1:0] ST_RX    = 2'd0;   // TREADY high
    localparam [1:0] ST_STALL = 2'd1;   // TREADY low, because pause is high
    localparam [1:0] ST_EOP   = 2'd2;   // TREADY low for one cycle after TLAST

    localparam integer ADDR_W = (MEM_DEPTH <= 1) ? 1 : $clog2(MEM_DEPTH);

    // every register is a pair of names: _q now, _d next
    reg [1:0]        state_q,      state_d;
    reg [ADDR_W-1:0] wr_ptr_q,     wr_ptr_d;
    reg [7:0]        word_count_q, word_count_d;
    reg              word_valid_q, word_valid_d;
    reg [DATA_W-1:0] word_data_q,  word_data_d;
    reg              pkt_done_q,   pkt_done_d;

    reg [DATA_W-1:0] mem [0:MEM_DEPTH-1];
    reg              mem_we;              // decided in block two

    wire handshake = s_axis_tvalid & s_axis_tready;

    //  ------------------------------------------------------------------------- Block
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            state_q      <= ST_RX;
            wr_ptr_q     <= {ADDR_W{1'b0}};
            word_count_q <= 8'd0;
            word_valid_q <= 1'b0;
            word_data_q  <= {DATA_W{1'b0}};
            pkt_done_q   <= 1'b0;
        end else begin
            state_q      <= state_d;
            wr_ptr_q     <= wr_ptr_d;
            word_count_q <= word_count_d;
            word_valid_q <= word_valid_d;
            word_data_q  <= word_data_d;
            pkt_done_q   <= pkt_done_d;

            //  this "if" is the memory's own write enable pin, not a decision. whether
            if (mem_we)
                mem[wr_ptr_q] <= s_axis_tdata;
        end
    end

    //  ------------------------------------------------------------------------- Block
    always @(*) begin
        // defaults. stored values hold. pulses and the write enable fall to zero
        state_d      = state_q;
        wr_ptr_d     = wr_ptr_q;
        word_count_d = word_count_q;
        word_data_d  = word_data_q;
        word_valid_d = 1'b0;
        pkt_done_d   = 1'b0;
        mem_we       = 1'b0;

        case (state_q)
            ST_RX: begin
                // the datapath consequences of a transfer
                if (handshake) begin
                    mem_we       = 1'b1;
                    word_data_d  = s_axis_tdata;
                    word_valid_d = 1'b1;
                    wr_ptr_d     = wr_ptr_q + 1'b1;
                    word_count_d = word_count_q + 8'd1;
                end

                // the control consequences. finishing a packet beats pausing
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
                wr_ptr_d     = {ADDR_W{1'b0}};
                word_count_d = 8'd0;
                state_d      = pause ? ST_STALL : ST_RX;
            end

            default: begin
                state_d      = ST_RX;
                wr_ptr_d     = {ADDR_W{1'b0}};
                word_count_d = 8'd0;
            end
        endcase
    end

    //  ------------------------------------------------------------------------- Block
    always @(*) begin
        s_axis_tready = 1'b0;
        word_valid    = word_valid_q;
        word_data     = word_data_q;
        pkt_done      = pkt_done_q;
        word_count    = word_count_q;

        case (state_q)
            ST_RX:    s_axis_tready = 1'b1;
            ST_STALL: s_axis_tready = 1'b0;
            ST_EOP:   s_axis_tready = 1'b0;
            default:  s_axis_tready = 1'b0;
        endcase
    end

    //  debug read port. a plain lookup into storage, outside the state machine, so it
    assign rd_data = mem[rd_addr[ADDR_W-1:0]];

endmodule
