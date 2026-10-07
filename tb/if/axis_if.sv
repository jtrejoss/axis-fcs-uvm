// AXI-Stream (8-bit) interface with clocking blocks for master, ready-driver and monitor
interface axis_if (input logic clk, input logic rst_n);
  logic [7:0] tdata;
  logic       tvalid;
  logic       tready;
  logic       tlast;

  clocking drv_cb @(posedge clk);       // upstream master
    default input #1step output #1;
    output tdata, tvalid, tlast;
    input  tready;
  endclocking

  clocking rdy_cb @(posedge clk);       // downstream sink (drives tready)
    default input #1step output #1;
    output tready;
    input  tdata, tvalid, tlast;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1step;
    input tdata, tvalid, tready, tlast;
  endclocking
endinterface
