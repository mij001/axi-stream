`timescale 1ns / 1ps
// demonstration four: the shape that all synchronous hardware has
// a register, some logic, and the logic's answer fed back to the register
// this is what "register transfer level" literally describes

module demo_04_counter;

    reg clk = 1'b0;
    reg rstn = 1'b0;
    always #5 clk = ~clk;

    reg  [3:0] count_q;      // the register: four flip flops side by side
    wire [3:0] count_next;   // the logic's answer, a bundle of four wires

    // the logic. an adder. it is always computing, all the time, with no clock
    assign count_next = count_q + 4'd1;

    // the register. once per rising edge it grabs whatever the logic is offering and
    always @(posedge clk or negedge rstn) begin
        if (!rstn) count_q <= 4'd0;
        else       count_q <= count_next;
    end

    integer i;
    initial begin
        repeat (2) @(posedge clk);
        rstn = 1'b1;
        for (i = 0; i < 6; i = i + 1) begin
            @(posedge clk);
            #1;
            $display("after edge %0d: count_q = %0d, adder is already offering %0d",
                     i+1, count_q, count_next);
        end
        $finish;
    end

endmodule
