class apb_monitor extends uvm_monitor;
  `uvm_component_utils(apb_monitor)
  virtual apb_if                vif;
  uvm_analysis_port #(apb_item) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  task run_phase(uvm_phase phase);
    apb_item it;
    forever begin
      @(vif.mon_cb);
      if (vif.presetn === 1'b1 && vif.mon_cb.psel && vif.mon_cb.penable && vif.mon_cb.pready) begin
        it        = apb_item::type_id::create("mon_item");
        it.addr   = vif.mon_cb.paddr;
        it.write  = vif.mon_cb.pwrite;
        it.data   = vif.mon_cb.pwrite ? vif.mon_cb.pwdata : vif.mon_cb.prdata;
        it.slverr = vif.mon_cb.pslverr;
        ap.write(it);
      end
    end
  endtask
endclass
