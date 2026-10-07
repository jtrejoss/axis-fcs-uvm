class axis_agent extends uvm_agent;
  `uvm_component_utils(axis_agent)

  axis_agent_cfg                  cfg;
  axis_sequencer                  sqr;
  axis_master_driver              drv;
  axis_ready_driver               rdy;
  axis_monitor                    mon;
  uvm_analysis_port #(axis_frame) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(axis_agent_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("NOCFG", "axis_agent_cfg not found")
    mon = axis_monitor::type_id::create("mon", this);
    mon.cfg = cfg; mon.vif = cfg.vif;
    if (cfg.is_active == UVM_ACTIVE) begin
      if (cfg.is_master) begin
        sqr = axis_sequencer::type_id::create("sqr", this);
        drv = axis_master_driver::type_id::create("drv", this);
        drv.cfg = cfg; drv.vif = cfg.vif;
      end else begin
        rdy = axis_ready_driver::type_id::create("rdy", this);
        rdy.cfg = cfg; rdy.vif = cfg.vif;
      end
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    ap = mon.ap;
    if (drv != null) drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction
endclass
