class axis_agent_cfg extends uvm_object;
  `uvm_object_utils(axis_agent_cfg)

  virtual axis_if         vif;
  uvm_active_passive_enum is_active = UVM_ACTIVE;
  bit                     is_master = 1;   // 1: drives TVALID/TDATA; 0: drives TREADY
  int unsigned            ready_pct = 100; // sink: probability (%) of TREADY=1 per cycle

  function new(string name = "axis_agent_cfg");
    super.new(name);
  endfunction
endclass
