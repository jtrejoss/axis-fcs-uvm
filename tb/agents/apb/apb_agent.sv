class apb_agent extends uvm_agent;
  `uvm_component_utils(apb_agent)

  virtual apb_if                vif;
  apb_sequencer                 sqr;
  apb_driver                    drv;
  apb_monitor                   mon;
  uvm_analysis_port #(apb_item) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "apb_if not found")
    mon = apb_monitor::type_id::create("mon", this);
    mon.vif = vif;
    if (get_is_active() == UVM_ACTIVE) begin
      sqr = apb_sequencer::type_id::create("sqr", this);
      drv = apb_driver::type_id::create("drv", this);
      drv.vif = vif;
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    ap = mon.ap;
    if (drv != null) drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction
endclass
