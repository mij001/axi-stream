`timescale 1ns / 1ps
// demonstration one: what the two assignment operators actually do
// two circuits that look almost identical in the source but are different
// hardware. run it and compare the printed numbers

module demo_01_nonblocking;

    reg clk;
    reg [7:0] a_blk, b_blk;    // built with = inside a clocked block
    reg [7:0] a_nb,  b_nb;     // built with <= inside a clocked block

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // blocking. runs in order, each finishes before the next starts
    always @(posedge clk) begin
        a_blk = b_blk;
        b_blk = a_blk;
    end

    // nonblocking. both right sides read first with the old values, then assign
    always @(posedge clk) begin
        a_nb <= b_nb;
        b_nb <= a_nb;
    end

    integer i;
    initial begin
        a_blk = 8'd10; b_blk = 8'd20;
        a_nb  = 8'd10; b_nb  = 8'd20;

        $display("start      : blocking a=%0d b=%0d   nonblocking a=%0d b=%0d",
                 a_blk, b_blk, a_nb, b_nb);

        for (i = 0; i < 3; i = i + 1) begin
            @(posedge clk);
            #1;
            $display("after edge %0d: blocking a=%0d b=%0d   nonblocking a=%0d b=%0d",
                     i+1, a_blk, b_blk, a_nb, b_nb);
        end

        $finish;
    end

endmodule
