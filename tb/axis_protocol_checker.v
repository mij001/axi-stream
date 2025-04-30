`timescale 1ns / 1ps

// passive checker for one link. drives nothing, fits any link
// counts nothing yet, it only shouts

module axis_protocol_checker #(
    parameter integer DATA_W = 32,
    parameter         NAME   = "axis"
) (
    input wire              aclk,
    input wire              aresetn,
    input wire              tvalid,
    input wire              tready,
    input wire [DATA_W-1:0] tdata,
    input wire              tlast
);

    reg              aresetn_prev_q;
    reg              tvalid_prev_q;
    reg              tready_prev_q;
    reg [DATA_W-1:0] tdata_prev_q;
    reg              tlast_prev_q;

    integer errors;

    initial begin
        errors         = 0;
        aresetn_prev_q = 1'b0;
        tvalid_prev_q  = 1'b0;
        tready_prev_q  = 1'b0;
        tdata_prev_q   = {DATA_W{1'b0}};
        tlast_prev_q   = 1'b0;
    end

    always @(posedge aclk) begin

        // spec 2.7.2: during reset TVALID must be driven LOW.
        if (!aresetn && tvalid !== 1'b0) begin
            $display("[%0t] %s CHECK FAIL: TVALID not low during reset", $time, NAME);
            errors = errors + 1;
        end

        if (aresetn) begin

            //  spec 2.7.2 and Figure 2-4: TVALID may only rise at an edge after an
            if (!aresetn_prev_q && tvalid === 1'b1) begin
                $display("[%0t] %s CHECK FAIL: TVALID high on the first edge after reset", $time, NAME);
                errors = errors + 1;
            end

            //  spec 2.2.1: once TVALID is asserted it must remain asserted until the
            if (aresetn_prev_q && tvalid_prev_q && !tready_prev_q && tvalid !== 1'b1) begin
                $display("[%0t] %s CHECK FAIL: TVALID dropped before the handshake", $time, NAME);
                errors = errors + 1;
            end

            //  spec 2.2.1, text under Figure 2-1: the information from the master must
            if (aresetn_prev_q && tvalid_prev_q && !tready_prev_q && tvalid === 1'b1) begin
                if (tdata !== tdata_prev_q) begin
                    $display("[%0t] %s CHECK FAIL: TDATA changed while stalled (0x%h -> 0x%h)",
                             $time, NAME, tdata_prev_q, tdata);
                    errors = errors + 1;
                end
                if (tlast !== tlast_prev_q) begin
                    $display("[%0t] %s CHECK FAIL: TLAST changed while stalled", $time, NAME);
                    errors = errors + 1;
                end
            end
        end

        // remember this edge for the next one
        aresetn_prev_q <= aresetn;
        tvalid_prev_q  <= tvalid;
        tready_prev_q  <= tready;
        tdata_prev_q   <= tdata;
        tlast_prev_q   <= tlast;
    end

endmodule
