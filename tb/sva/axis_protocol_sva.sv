// AXI-Stream protocol checker. Bound to both DUT stream ports (see fcs_bind.sv).
module axis_protocol_sva (
  input logic       clk,
  input logic       rst_n,
  input logic       tvalid,
  input logic       tready,
  input logic       tlast,
  input logic [7:0] tdata
);
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  default clocking @(posedge clk); endclocking
  default disable iff (!rst_n);

  // Once asserted, TVALID must stay high until the handshake
  a_valid_hold: assert property (tvalid && !tready |=> tvalid)
    else `uvm_error("AXIS_SVA", $sformatf("%m: TVALID dropped before handshake"))

  // Payload must be stable while stalled
  a_payload_stable: assert property (tvalid && !tready |=> $stable(tdata) && $stable(tlast))
    else `uvm_error("AXIS_SVA", $sformatf("%m: TDATA/TLAST changed while stalled"))

  // No X/Z on control, or on payload when valid
  a_valid_known: assert property (!$isunknown(tvalid))
    else `uvm_error("AXIS_SVA", $sformatf("%m: TVALID is X/Z"))
  a_payload_known: assert property (tvalid |-> !$isunknown({tdata, tlast}))
    else `uvm_error("AXIS_SVA", $sformatf("%m: TDATA/TLAST X/Z while valid"))

  // Coverage of interesting handshake scenarios
  c_stall_then_xfer: cover property (tvalid && !tready ##1 tvalid && tready);
  c_back_to_back:    cover property (tvalid && tready ##1 tvalid && tready);
  c_last_stalled:    cover property (tvalid && tlast && !tready);
endmodule
