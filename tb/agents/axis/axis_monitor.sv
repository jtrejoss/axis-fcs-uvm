// Reconstructs frames from handshakes and reports stall/idle statistics.
class axis_monitor extends uvm_monitor;
  `uvm_component_utils(axis_monitor)

  axis_agent_cfg                  cfg;
  virtual axis_if                 vif;
  uvm_analysis_port #(axis_frame) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  task run_phase(uvm_phase phase);
    bit [7:0]    q[$];
    int unsigned stalls, idles;
    axis_frame   f;
    forever begin
      @(vif.mon_cb);
      if (vif.rst_n !== 1'b1) begin
        q.delete(); stalls = 0; idles = 0;
        continue;
      end
      if (vif.mon_cb.tvalid && !vif.mon_cb.tready) stalls++;
      if (!vif.mon_cb.tvalid && q.size() > 0)      idles++;
      if (vif.mon_cb.tvalid && vif.mon_cb.tready) begin
        q.push_back(vif.mon_cb.tdata);
        if (vif.mon_cb.tlast) begin
          f = axis_frame::type_id::create("mon_frame");
          f.data         = q;
          f.len          = q.size();
          f.stall_cycles = stalls;
          f.idle_cycles  = idles;
          `uvm_info("AXIS_MON", {get_full_name(), ": ", f.convert2string()}, UVM_HIGH)
          ap.write(f);
          q.delete(); stalls = 0; idles = 0;
        end
      end
    end
  endtask
endclass
