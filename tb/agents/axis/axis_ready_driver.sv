// Downstream sink model: randomizes TREADY every cycle to create backpressure.
// cfg.ready_pct is read every cycle, so a sequence can change it at runtime.
class axis_ready_driver extends uvm_component;
  `uvm_component_utils(axis_ready_driver)

  axis_agent_cfg  cfg;
  virtual axis_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    vif.rdy_cb.tready <= 1'b0;
    forever begin
      @(vif.rdy_cb);
      vif.rdy_cb.tready <= ($urandom_range(99, 0) < cfg.ready_pct);
    end
  endtask
endclass
