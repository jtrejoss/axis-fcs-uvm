class fcs_env_cfg extends uvm_object;
  `uvm_object_utils(fcs_env_cfg)
  axis_agent_cfg in_cfg;
  axis_agent_cfg out_cfg;
  virtual apb_if apb_vif;
  function new(string name = "fcs_env_cfg");
    super.new(name);
  endfunction
endclass

class fcs_vsequencer extends uvm_sequencer;
  `uvm_component_utils(fcs_vsequencer)
  axis_sequencer axis_sqr;
  apb_sequencer  apb_sqr;
  fcs_reg_block  regmodel;
  fcs_ref_model  ref_m;
  fcs_scoreboard sb;
  axis_agent_cfg out_cfg;   // lets sequences change TREADY probability at runtime
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass

class fcs_env extends uvm_env;
  `uvm_component_utils(fcs_env)

  fcs_env_cfg                   cfg;
  axis_agent                    in_agt;
  axis_agent                    out_agt;
  apb_agent                     apb_agt;
  fcs_ref_model                 ref_m;
  fcs_scoreboard                sb;
  fcs_coverage                  cov;
  fcs_vsequencer                vsqr;
  fcs_reg_block                 regmodel;
  reg2apb_adapter               adapter;
  uvm_reg_predictor #(apb_item) predictor;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(fcs_env_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("NOCFG", "fcs_env_cfg not found")

    uvm_config_db #(axis_agent_cfg)::set(this, "in_agt",  "cfg", cfg.in_cfg);
    uvm_config_db #(axis_agent_cfg)::set(this, "out_agt", "cfg", cfg.out_cfg);
    uvm_config_db #(virtual apb_if)::set(this, "apb_agt", "vif", cfg.apb_vif);

    in_agt    = axis_agent::type_id::create("in_agt", this);
    out_agt   = axis_agent::type_id::create("out_agt", this);
    apb_agt   = apb_agent::type_id::create("apb_agt", this);
    ref_m     = fcs_ref_model::type_id::create("ref_m", this);
    sb        = fcs_scoreboard::type_id::create("sb", this);
    cov       = fcs_coverage::type_id::create("cov", this);
    vsqr      = fcs_vsequencer::type_id::create("vsqr", this);
    predictor = uvm_reg_predictor #(apb_item)::type_id::create("predictor", this);
    adapter   = reg2apb_adapter::type_id::create("adapter");

    regmodel = fcs_reg_block::type_id::create("regmodel");
    regmodel.configure(null, "");
    regmodel.build();
    regmodel.reset();
  endfunction

  function void connect_phase(uvm_phase phase);
    // RAL: front door through APB, explicit prediction from the bus monitor
    regmodel.default_map.set_sequencer(apb_agt.sqr, adapter);
    regmodel.default_map.set_auto_predict(0);
    predictor.map     = regmodel.default_map;
    predictor.adapter = adapter;
    apb_agt.ap.connect(predictor.bus_in);

    // Checking and coverage
    in_agt.ap.connect(ref_m.analysis_export);
    ref_m.ap.connect(sb.exp_fifo.analysis_export);
    out_agt.ap.connect(sb.act_fifo.analysis_export);
    in_agt.ap.connect(cov.in_imp);
    out_agt.ap.connect(cov.out_imp);
    ref_m.regmodel = regmodel;
    cov.regmodel   = regmodel;

    // Virtual sequencer handles
    vsqr.axis_sqr = in_agt.sqr;
    vsqr.apb_sqr  = apb_agt.sqr;
    vsqr.regmodel = regmodel;
    vsqr.ref_m    = ref_m;
    vsqr.sb       = sb;
    vsqr.out_cfg  = cfg.out_cfg;
  endfunction
endclass
