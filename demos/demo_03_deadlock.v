`timescale 1ns / 1ps

// demo 3. why the master is forbidden from waiting for tready
// this master breaks one rule, it will not raise tvalid until it sees tready
// the slave is cautious but legal, it waits for tvalid before tready
// neither is faulty alone

module broken_master (
    input  wire        aclk,
    input  wire        aresetn,
    input  wire        start,
    output reg         tvalid,
    input  wire        tready,
    output reg  [7:0]  tdata
);
    reg have_data;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) have_data <= 1'b0;
        else if (start) have_data <= 1'b1;
    end

    //  THE BUG IS ON THE NEXT LINE. tready appears in the logic that produces tvalid,
    always @(*) begin
        tvalid = have_data && tready;
        tdata  = 8'hA0;
    end
endmodule


module cautious_slave (
    input  wire        aclk,
    input  wire        aresetn,
    input  wire        tvalid,
    output reg         tready,
    input  wire [7:0]  tdata
);
    //  this slave is legal. the spec explicitly permits a slave to wait for TVALID
    always @(*) begin
        tready = tvalid;
    end

    always @(posedge aclk) begin
        if (aresetn && tvalid && tready)
            $display("  slave accepted 0x%02h", tdata);
    end
endmodule


module demo_03_deadlock;
    reg        aclk = 1'b0;
    reg        aresetn = 1'b0;
    reg        start = 1'b0;
    wire       tvalid, tready;
    wire [7:0] tdata;

    always #5 aclk = ~aclk;

    broken_master  u_m (.aclk(aclk), .aresetn(aresetn), .start(start),
                        .tvalid(tvalid), .tready(tready), .tdata(tdata));
    cautious_slave u_s (.aclk(aclk), .aresetn(aresetn),
                        .tvalid(tvalid), .tready(tready), .tdata(tdata));

    integer c;
    initial begin
        repeat (3) @(posedge aclk);
        aresetn = 1'b1;
        @(posedge aclk);
        start = 1'b1;
        @(posedge aclk);
        start = 1'b0;

        for (c = 0; c < 8; c = c + 1) begin
            @(posedge aclk);
            $display("cycle %0d: TVALID=%b TREADY=%b", c, tvalid, tready);
        end

        $display("");
        $display("The master has data and the slave has room, and yet nothing");
        $display("has moved in 8 clock cycles. This is deadlock.");
        $finish;
    end
endmodule
