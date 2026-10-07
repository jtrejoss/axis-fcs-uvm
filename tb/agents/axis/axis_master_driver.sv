// Drives frames on an AXI-Stream master port, honoring TREADY and per-byte gaps.
class axis_master_driver extends uvm_driver #(axis_frame);
  `uvm_component_utils(axis_master_driver)

  axis_agent_cfg  cfg;
  virtual axis_if vif;
  protected time  last_edge = -1;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // Align to a clocking event so synchronous drives take effect on this edge
  protected task sync();
    if ($time != last_edge) @(vif.drv_cb);
    last_edge = $time;
  endtask

  protected task tick();
    @(vif.drv_cb);
    last_edge = $time;
  endtask

  task run_phase(uvm_phase phase);
    vif.drv_cb.tvalid <= 1'b0;
    vif.drv_cb.tlast  <= 1'b0;
    vif.drv_cb.tdata  <= '0;
    wait (vif.rst_n === 1'b1);
    forever begin
      seq_item_port.get_next_item(req);
      `uvm_info("AXIS_DRV", {"Driving ", req.convert2string()}, UVM_HIGH)
      drive_frame(req);
      seq_item_port.item_done();
    end
  endtask

  protected task drive_frame(axis_frame f);
    sync();
    foreach (f.data[i]) begin
      if (f.gap[i] > 0) begin
        vif.drv_cb.tvalid <= 1'b0;
        repeat (f.gap[i]) tick();
      end
      vif.drv_cb.tvalid <= 1'b1;
      vif.drv_cb.tdata  <= f.data[i];
      vif.drv_cb.tlast  <= (i == f.data.size() - 1);
      tick();
      while (vif.drv_cb.tready !== 1'b1) tick();
    end
    vif.drv_cb.tvalid <= 1'b0;
    vif.drv_cb.tlast  <= 1'b0;
  endtask
endclass
