`timescale 1ns / 1ps
// demo 5. the two timelines
// one counter, three ways of turning it into an output. they are not the same

module demo_05_two_timelines;

    reg clk = 1'b0;
    reg rstn = 1'b0;
    always #5 clk = ~clk;

    // --------------------------------------------------------------------- the
    reg [3:0] count_q;

    // the combinational logic that decides what the register becomes next this is "next
    wire [3:0] count_d = count_q + 4'd1;

    always @(posedge clk or negedge rstn) begin
        if (!rstn) count_q <= 4'd0;
        else       count_q <= count_d;
    end

    // --------------------------------------------------------------------- output
    wire [7:0] out_comb = 8'hA0 + {4'd0, count_q};

    // --------------------------------------------------------------------- output
    reg [7:0] out_reg_late;
    always @(posedge clk or negedge rstn) begin
        if (!rstn) out_reg_late <= 8'h00;
        else       out_reg_late <= 8'hA0 + {4'd0, count_q};
    end

    // --------------------------------------------------------------------- output
    reg [7:0] out_reg_aligned;
    always @(posedge clk or negedge rstn) begin
        if (!rstn) out_reg_aligned <= 8'hA0;
        else       out_reg_aligned <= 8'hA0 + {4'd0, count_d};
    end

    integer i;
    initial begin
        repeat (2) @(posedge clk);
        @(negedge clk);
        rstn = 1'b1;

        $display("");
        $display("            | count_q | count_d | out_comb | out_reg_late | out_reg_aligned");
        $display("            |  (now)  | (next)  |  (now)   |  (one late)  |   (in step)");
        $display("------------+---------+---------+----------+--------------+----------------");
        for (i = 0; i < 6; i = i + 1) begin
            @(posedge clk);
            #1;
            $display("during cyc %0d |    %0d    |    %0d    |   0x%02h   |     0x%02h     |      0x%02h",
                     i, count_q, count_d, out_comb, out_reg_late, out_reg_aligned);
        end
        $display("");
        $finish;
    end

endmodule
