// DUT-specific white-box assertions (bound to axis_fcs_inserter internals)
module fcs_dut_sva (
  input logic       clk,
  input logic       rst_n,
  input logic       in_fcs_state,
  input logic [1:0] fcs_idx,
  input logic       s_axis_tready,
  input logic       m_axis_tvalid,
  input logic       m_axis_tready,
  input logic       m_axis_tlast
);
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  default clocking @(posedge clk); endclocking
  default disable iff (!rst_n);

  // Input must be back-pressured while FCS bytes are being emitted
  a_no_input_in_fcs: assert property (in_fcs_state |-> !s_axis_tready)
    else `uvm_error("FCS_SVA", "s_axis_tready asserted during FCS insertion")

  // Exactly 4 FCS bytes, TLAST only on the last one
  a_fcs_last: assert property (in_fcs_state |-> (m_axis_tlast == (fcs_idx == 2'd3)))
    else `uvm_error("FCS_SVA", "TLAST not aligned with the 4th FCS byte")

  // FCS state always leaves after the 4th accepted byte
  a_fcs_exit: assert property (in_fcs_state && fcs_idx == 2'd3 && m_axis_tready |=> !in_fcs_state)
    else `uvm_error("FCS_SVA", "FSM did not return to DATA after FCS")

  c_fcs_backpressure: cover property (in_fcs_state && m_axis_tvalid && !m_axis_tready);
endmodule
