`timescale 1ns / 1ps

// the same rules as the hand checker but as sva. bound at the bottom


module axis_sva #(
    parameter int DATA_W = 32,
    parameter string NAME = "axis"
) (
    input logic              aclk,
    input logic              aresetn,
    input logic              tvalid,
    input logic              tready,
    input logic [DATA_W-1:0] tdata,
    input logic              tlast
);

    // 2.7.2  TVALID is driven low during reset
    property p_reset_tvalid_low;
        @(posedge aclk) (!aresetn) |-> (tvalid === 1'b0);
    endproperty
    a_reset_tvalid_low: assert property (p_reset_tvalid_low)
        else $error("%s: TVALID not low during reset", NAME);

    // 2.7.2 fig 2-4. tvalid may only rise an edge after reset was already high
    property p_no_tvalid_on_first_edge;
        @(posedge aclk) ($rose(aresetn)) |-> (tvalid === 1'b0);
    endproperty
    a_no_tvalid_on_first_edge: assert property (p_no_tvalid_on_first_edge)
        else $error("%s: TVALID high on the first edge after reset", NAME);

    // 2.2.1 Once TVALID is asserted it stays asserted until the handshake read it as:
    property p_tvalid_holds;
        @(posedge aclk) disable iff (!aresetn)
            (tvalid && !tready) |=> tvalid;
    endproperty
    a_tvalid_holds: assert property (p_tvalid_holds)
        else $error("%s: TVALID dropped before the handshake", NAME);

    // 2.2.1, the text under figure 2-1: payload must hold while stalled
    property p_tdata_holds;
        @(posedge aclk) disable iff (!aresetn)
            (tvalid && !tready) |=> $stable(tdata);
    endproperty
    a_tdata_holds: assert property (p_tdata_holds)
        else $error("%s: TDATA changed while stalled, 0x%0h -> 0x%0h",
                    NAME, $past(tdata), tdata);

    property p_tlast_holds;
        @(posedge aclk) disable iff (!aresetn)
            (tvalid && !tready) |=> $stable(tlast);
    endproperty
    a_tlast_holds: assert property (p_tlast_holds)
        else $error("%s: TLAST changed while stalled", NAME);

    // nothing offered may be unknown
    property p_payload_known;
        @(posedge aclk) disable iff (!aresetn)
            tvalid |-> (!$isunknown({tdata, tlast}));
    endproperty
    a_payload_known: assert property (p_payload_known)
        else $error("%s: X or Z in the payload while TVALID is high", NAME);

    property p_handshake_known;
        @(posedge aclk) disable iff (!aresetn)
            (!$isunknown({tvalid, tready}));
    endproperty
    a_handshake_known: assert property (p_handshake_known)
        else $error("%s: X or Z on TVALID or TREADY", NAME);

    // cover points. an assertion that never fails proves nothing if the interesting
    c_transfer: cover property (
        @(posedge aclk) disable iff (!aresetn) tvalid && tready);

    c_stall_then_transfer: cover property (
        @(posedge aclk) disable iff (!aresetn) (tvalid && !tready) ##1 (tvalid && tready));

    c_long_stall: cover property (
        @(posedge aclk) disable iff (!aresetn) (tvalid && !tready)[*3] ##1 (tvalid && tready));

    c_back_to_back: cover property (
        @(posedge aclk) disable iff (!aresetn) (tvalid && tready)[*2]);

    c_packet_end: cover property (
        @(posedge aclk) disable iff (!aresetn) tvalid && tready && tlast);

    c_stall_on_last: cover property (
        @(posedge aclk) disable iff (!aresetn) (tvalid && !tready && tlast) ##1 (tvalid && tready && tlast));

endmodule


// attach without touching the design. every axis_master_basic in any testbench gets
bind axis_master_basic axis_sva #(
    .DATA_W (DATA_W),
    .NAME   ("master")
) u_sva (
    .aclk    (aclk),
    .aresetn (aresetn),
    .tvalid  (m_axis_tvalid),
    .tready  (m_axis_tready),
    .tdata   (m_axis_tdata),
    .tlast   (m_axis_tlast)
);
