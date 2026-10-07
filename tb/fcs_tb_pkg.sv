package fcs_tb_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // AXI-Stream agent
  `include "axis_frame.sv"
  `include "axis_agent_cfg.sv"
  `include "axis_master_driver.sv"
  `include "axis_ready_driver.sv"
  `include "axis_monitor.sv"
  `include "axis_agent.sv"
  `include "axis_frame_seq.sv"
  // APB agent
  `include "apb_pkg_items.sv"
  `include "apb_driver.sv"
  `include "apb_monitor.sv"
  `include "apb_agent.sv"
  // Register model
  `include "fcs_reg_block.sv"
  // Environment
  `include "fcs_ref_model.sv"
  `include "fcs_scoreboard.sv"
  `include "fcs_coverage.sv"
  `include "fcs_env.sv"
  // Sequences and tests
  `include "fcs_vseqs.sv"
  `include "fcs_tests.sv"
endpackage
