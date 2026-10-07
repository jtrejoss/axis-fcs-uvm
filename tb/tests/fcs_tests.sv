// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
class fcs_base_test extends uvm_test;
  `uvm_component_utils(fcs_base_test)

  fcs_env     env;
  fcs_env_cfg cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // Hooks for derived tests
  virtual function void configure_test(); endfunction
  virtual function fcs_base_vseq make_vseq();
    return fcs_smoke_vseq::type_id::create("vseq");
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // Stop after 20 errors: keeps logs readable (EDA Playground caps output at 5000 lines)
    uvm_report_server::get_server().set_max_quit_count(20);

    cfg         = fcs_env_cfg::type_id::create("cfg");
    cfg.in_cfg  = axis_agent_cfg::type_id::create("in_cfg");
    cfg.out_cfg = axis_agent_cfg::type_id::create("out_cfg");

    if (!uvm_config_db #(virtual axis_if)::get(this, "", "in_vif",  cfg.in_cfg.vif))
      `uvm_fatal("NOVIF", "in_vif not found")
    if (!uvm_config_db #(virtual axis_if)::get(this, "", "out_vif", cfg.out_cfg.vif))
      `uvm_fatal("NOVIF", "out_vif not found")
    if (!uvm_config_db #(virtual apb_if)::get(this, "", "apb_vif",  cfg.apb_vif))
      `uvm_fatal("NOVIF", "apb_vif not found")

    cfg.in_cfg.is_master  = 1;
    cfg.out_cfg.is_master = 0;
    cfg.out_cfg.ready_pct = 80;
    configure_test();

    uvm_config_db #(fcs_env_cfg)::set(this, "env", "cfg", cfg);
    env = fcs_env::type_id::create("env", this);
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    uvm_top.print_topology();
  endfunction

  task run_phase(uvm_phase phase);
    fcs_base_vseq vseq;
    phase.raise_objection(this);
    vseq = make_vseq();
    vseq.start(env.vsqr);
    #100ns;
    phase.drop_objection(this);
  endtask

  function void report_phase(uvm_phase phase);
    uvm_report_server svr = uvm_report_server::get_server();
    if (svr.get_severity_count(UVM_ERROR) + svr.get_severity_count(UVM_FATAL) == 0)
      `uvm_info("RESULT", "** TEST PASSED **", UVM_NONE)
    else
      `uvm_info("RESULT", "** TEST FAILED **", UVM_NONE)
  endfunction
endclass

class fcs_smoke_test extends fcs_base_test;
  `uvm_component_utils(fcs_smoke_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function void configure_test(); cfg.out_cfg.ready_pct = 100; endfunction
endclass

class fcs_random_test extends fcs_base_test;
  `uvm_component_utils(fcs_random_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function fcs_base_vseq make_vseq();
    return fcs_random_vseq::type_id::create("vseq");
  endfunction
endclass

class fcs_backpressure_test extends fcs_random_test;
  `uvm_component_utils(fcs_backpressure_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function void configure_test(); cfg.out_cfg.ready_pct = 30; endfunction
endclass

class fcs_corner_test extends fcs_base_test;
  `uvm_component_utils(fcs_corner_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function fcs_base_vseq make_vseq();
    return fcs_corner_vseq::type_id::create("vseq");
  endfunction
endclass

class fcs_reg_test extends fcs_base_test;
  `uvm_component_utils(fcs_reg_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function fcs_base_vseq make_vseq();
    return fcs_reg_vseq::type_id::create("vseq");
  endfunction
endclass

// Coverage-closure test: corner frames + random traffic across TREADY 100/80/30%
class fcs_full_test extends fcs_base_test;
  `uvm_component_utils(fcs_full_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function void configure_test(); cfg.out_cfg.ready_pct = 100; endfunction
  virtual function fcs_base_vseq make_vseq();
    return fcs_full_vseq::type_id::create("vseq");
  endfunction
endclass
