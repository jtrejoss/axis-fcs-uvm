class apb_driver extends uvm_driver #(apb_item);
  `uvm_component_utils(apb_driver)
  virtual apb_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    vif.cb.psel    <= 1'b0;
    vif.cb.penable <= 1'b0;
    wait (vif.presetn === 1'b1);
    forever begin
      seq_item_port.get_next_item(req);
      @(vif.cb);                                   // SETUP
      vif.cb.psel    <= 1'b1;
      vif.cb.penable <= 1'b0;
      vif.cb.pwrite  <= req.write;
      vif.cb.paddr   <= req.addr;
      vif.cb.pwdata  <= req.data;
      @(vif.cb);                                   // ACCESS
      vif.cb.penable <= 1'b1;
      @(vif.cb);
      while (vif.cb.pready !== 1'b1) @(vif.cb);
      req.slverr = vif.cb.pslverr;
      if (!req.write) req.data = vif.cb.prdata;
      vif.cb.psel    <= 1'b0;
      vif.cb.penable <= 1'b0;
      `uvm_info("APB_DRV", req.convert2string(), UVM_HIGH)
      seq_item_port.item_done();
    end
  endtask
endclass
