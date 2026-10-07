`timescale 1ns/1ps
module tb_top;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import fcs_tb_pkg::*;

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  always #5 clk = ~clk;                       // 100 MHz

  initial begin
    rst_n = 1'b0;
    repeat (5) @(posedge clk);
    rst_n <= 1'b1;
  end

  axis_if in_if  (clk, rst_n);
  axis_if out_if (clk, rst_n);
  apb_if  apb    (clk, rst_n);

  axis_fcs_inserter dut (
    .clk           (clk),
    .rst_n         (rst_n),
    .s_axis_tdata  (in_if.tdata),
    .s_axis_tvalid (in_if.tvalid),
    .s_axis_tready (in_if.tready),
    .s_axis_tlast  (in_if.tlast),
    .m_axis_tdata  (out_if.tdata),
    .m_axis_tvalid (out_if.tvalid),
    .m_axis_tready (out_if.tready),
    .m_axis_tlast  (out_if.tlast),
    .psel          (apb.psel),
    .penable       (apb.penable),
    .pwrite        (apb.pwrite),
    .paddr         (apb.paddr),
    .pwdata        (apb.pwdata),
    .prdata        (apb.prdata),
    .pready        (apb.pready),
    .pslverr       (apb.pslverr)
  );

  initial begin
    uvm_config_db #(virtual axis_if)::set(null, "uvm_test_top", "in_vif",  in_if);
    uvm_config_db #(virtual axis_if)::set(null, "uvm_test_top", "out_vif", out_if);
    uvm_config_db #(virtual apb_if)::set(null,  "uvm_test_top", "apb_vif", apb);
    uvm_top.set_timeout(50ms, 0);
    run_test("fcs_smoke_test");
  end

`ifdef FSDB
  initial begin
    $fsdbDumpfile("waves.fsdb");
    $fsdbDumpvars(0, tb_top, "+all");
  end
`endif
`ifdef VCD
  initial begin
    $dumpfile("dump.vcd");      // EDA Playground / EPWave expects dump.vcd
    $dumpvars(0, tb_top);
  end
`endif
endmodule
