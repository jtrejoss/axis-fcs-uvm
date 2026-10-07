// Bind assertion modules into the DUT
bind axis_fcs_inserter axis_protocol_sva u_s_axis_sva (
  .clk(clk), .rst_n(rst_n),
  .tvalid(s_axis_tvalid), .tready(s_axis_tready), .tlast(s_axis_tlast), .tdata(s_axis_tdata));

bind axis_fcs_inserter axis_protocol_sva u_m_axis_sva (
  .clk(clk), .rst_n(rst_n),
  .tvalid(m_axis_tvalid), .tready(m_axis_tready), .tlast(m_axis_tlast), .tdata(m_axis_tdata));

bind axis_fcs_inserter fcs_dut_sva u_fcs_dut_sva (
  .clk(clk), .rst_n(rst_n),
  .in_fcs_state(state == S_FCS), .fcs_idx(fcs_idx),
  .s_axis_tready(s_axis_tready),
  .m_axis_tvalid(m_axis_tvalid), .m_axis_tready(m_axis_tready), .m_axis_tlast(m_axis_tlast));
