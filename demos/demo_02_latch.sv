`timescale 1ns / 1ps
// demonstration two: the accidental memory element
// both blocks below are meant to be pure logic gates. only one of them is

module demo_02_latch (
    input  wire [1:0] sel,
    input  wire [7:0] in_a,
    input  wire [7:0] in_b,
    output reg  [7:0] out_bad,
    output reg  [7:0] out_good
);

    // BAD: sel = 2 and sel = 3 are not covered, so out_bad has to remember its previous
    always @(*) begin
        case (sel)
            2'd0: out_bad = in_a;
            2'd1: out_bad = in_b;
        endcase
    end

    // GOOD: a default value is assigned first, so every possible path through the block
    always @(*) begin
        out_good = 8'd0;
        case (sel)
            2'd0: out_good = in_a;
            2'd1: out_good = in_b;
            default: out_good = 8'd0;
        endcase
    end

endmodule
