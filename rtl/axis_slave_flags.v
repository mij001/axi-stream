`timescale 1ns / 1ps

// same slave with two flags insted of the state. no priority rule needed

module axis_slave_flags #(
    parameter integer DATA_W    = 32,
    parameter integer MEM_DEPTH = 16
) (
    input  wire                aclk,
    input  wire                aresetn,

    input  wire                s_axis_tvalid,
    output reg                 s_axis_tready,
    input  wire [DATA_W-1:0]   s_axis_tdata,
    input  wire                s_axis_tlast,

    input  wire                pause,
    output reg                 word_valid,
    output reg  [DATA_W-1:0]   word_data,
    output reg                 pkt_done,
    output reg  [7:0]          word_count,

    input  wire [3:0]          rd_addr,
    output wire [DATA_W-1:0]   rd_data
);

    localparam integer ADDR_W = (MEM_DEPTH <= 1) ? 1 : $clog2(MEM_DEPTH);

    // control flags
    reg              stall_q,      stall_d;
    reg              closing_q,    closing_d;

    // datapath registers
    reg [ADDR_W-1:0] wr_ptr_q,     wr_ptr_d;
    reg [7:0]        word_count_q, word_count_d;
    reg              word_valid_q, word_valid_d;
    reg [DATA_W-1:0] word_data_q,  word_data_d;
    reg              pkt_done_q,   pkt_done_d;

    reg [DATA_W-1:0] mem [0:MEM_DEPTH-1];
    reg              mem_we;

    wire handshake = s_axis_tvalid & s_axis_tready;

    //  ------------------------------------------------------------------------- Block
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            stall_q      <= 1'b0;
            closing_q    <= 1'b0;
            wr_ptr_q     <= {ADDR_W{1'b0}};
            word_count_q <= 8'd0;
            word_valid_q <= 1'b0;
            word_data_q  <= {DATA_W{1'b0}};
            pkt_done_q   <= 1'b0;
        end else begin
            stall_q      <= stall_d;
            closing_q    <= closing_d;
            wr_ptr_q     <= wr_ptr_d;
            word_count_q <= word_count_d;
            word_valid_q <= word_valid_d;
            word_data_q  <= word_data_d;
            pkt_done_q   <= pkt_done_d;

            if (mem_we)
                mem[wr_ptr_q] <= s_axis_tdata;
        end
    end

    //  ------------------------------------------------------------------------- Block
    always @(*) begin
        // control. one line each, and neither flag mentions the other
        stall_d   = pause;
        closing_d = handshake & s_axis_tlast;

        // datapath defaults
        wr_ptr_d     = wr_ptr_q;
        word_count_d = word_count_q;
        word_data_d  = word_data_q;
        word_valid_d = 1'b0;
        pkt_done_d   = 1'b0;
        mem_we       = 1'b0;

        if (closing_q) begin
            //  TREADY is low whenever closing_q is high, so no transfer can be
            wr_ptr_d     = {ADDR_W{1'b0}};
            word_count_d = 8'd0;
        end else if (handshake) begin
            mem_we       = 1'b1;
            word_data_d  = s_axis_tdata;
            word_valid_d = 1'b1;
            wr_ptr_d     = wr_ptr_q + 1'b1;
            word_count_d = word_count_q + 8'd1;
            pkt_done_d   = s_axis_tlast;
        end
    end

    //  ------------------------------------------------------------------------- Block
    always @(*) begin
        s_axis_tready = ~stall_q & ~closing_q;
        word_valid    = word_valid_q;
        word_data     = word_data_q;
        pkt_done      = pkt_done_q;
        word_count    = word_count_q;
    end

    // debug read port, outside the state machine
    assign rd_data = mem[rd_addr[ADDR_W-1:0]];

endmodule
