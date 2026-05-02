`timescale 1ns / 1ps
// demo 6. a register in the loop does NOT cure a deadlock
// two masters, both with a registered tvalid, so no combinational path from
// tready to tvalid at all. each talks to its own cautious but legal slave
// a decides to raise tvalid from its own data.  legal
// b decides to raise tvalid from tready.        not legal, and it hangs

module demo_master #(
    parameter WAITS_FOR_TREADY = 0
) (
    input  wire       aclk,
    input  wire       aresetn,
    input  wire       start,
    output reg        tvalid,
    input  wire       tready,
    output reg  [7:0] tdata
);
    reg have_data_q, have_data_d;
    reg tvalid_q,    tvalid_d;

    wire handshake = tvalid & tready;

    // block one
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            have_data_q <= 1'b0;
            tvalid_q    <= 1'b0;
        end else begin
            have_data_q <= have_data_d;
            tvalid_q    <= tvalid_d;
        end
    end

    // block two
    always @(*) begin
        have_data_d = have_data_q;
        tvalid_d    = tvalid_q;

        if (start)
            have_data_d = 1'b1;

        if (!tvalid_q) begin
            // deciding whether to RAISE TVALID next cycle
            if (WAITS_FOR_TREADY)
                tvalid_d = have_data_q & tready;   // master B: waits for TREADY
            else
                tvalid_d = have_data_q;            // master A: does not wait
        end else if (handshake) begin
            // deciding to LOWER TVALID. allowed, because the transfer completed
            tvalid_d    = 1'b0;
            have_data_d = 1'b0;
        end
    end

    // block three
    always @(*) begin
        tvalid = tvalid_q;
        tdata  = 8'hA0;
    end
endmodule


module demo_cautious_slave (
    input  wire       aclk,
    input  wire       aresetn,
    input  wire       tvalid,
    output reg        tready,
    input  wire [7:0] tdata
);
    reg       tready_q, tready_d;
    reg [7:0] count_q,  count_d;

    wire handshake = tvalid & tready;

    // block one
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            tready_q <= 1'b0;
            count_q  <= 8'd0;
        end else begin
            tready_q <= tready_d;
            count_q  <= count_d;
        end
    end

    // block two: raise TREADY one cycle after seeing TVALID, drop it after a transfer
    always @(*) begin
        tready_d = tvalid & ~handshake;
        count_d  = handshake ? count_q + 8'd1 : count_q;
    end

    // block three
    always @(*) begin
        tready = tready_q;
    end
endmodule


module demo_06_registered_deadlock;
    reg aclk    = 1'b0;
    reg aresetn = 1'b0;
    reg start   = 1'b0;
    always #5 aclk = ~aclk;

    wire       va, ra, vb, rb;
    wire [7:0] da, db;

    demo_master #(.WAITS_FOR_TREADY(0)) u_ma (.aclk(aclk), .aresetn(aresetn), .start(start),
                                              .tvalid(va), .tready(ra), .tdata(da));
    demo_cautious_slave                 u_sa (.aclk(aclk), .aresetn(aresetn),
                                              .tvalid(va), .tready(ra), .tdata(da));

    demo_master #(.WAITS_FOR_TREADY(1)) u_mb (.aclk(aclk), .aresetn(aresetn), .start(start),
                                              .tvalid(vb), .tready(rb), .tdata(db));
    demo_cautious_slave                 u_sb (.aclk(aclk), .aresetn(aresetn),
                                              .tvalid(vb), .tready(rb), .tdata(db));

    integer c;
    initial begin
        repeat (3) @(posedge aclk);
        @(negedge aclk) aresetn = 1'b1;
        @(negedge aclk) start   = 1'b1;
        @(negedge aclk) start   = 1'b0;

        $display("");
        $display("          | master A (legal)            | master B (waits for TREADY)");
        $display("          | have_data TVALID TREADY xfr | have_data TVALID TREADY xfr");
        for (c = 0; c < 8; c = c + 1) begin
            @(posedge aclk);
            $display("cycle %0d   |     %b       %b      %b    %s  |     %b       %b      %b    %s",
                     c,
                     u_ma.have_data_q, va, ra, (va && ra) ? "yes" : " - ",
                     u_mb.have_data_q, vb, rb, (vb && rb) ? "yes" : " - ");
        end
        $display("");
        $display("transfers completed: master A = %0d, master B = %0d", u_sa.count_q, u_sb.count_q);
        $display("Master B has a register between TREADY and TVALID and still never sends.");
        $display("");
        $finish;
    end
endmodule
