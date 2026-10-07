// In-order scoreboard: expected (reference model) vs. actual (output monitor)
class fcs_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(fcs_scoreboard)

  uvm_tlm_analysis_fifo #(axis_frame) exp_fifo;
  uvm_tlm_analysis_fifo #(axis_frame) act_fifo;
  int unsigned n_match, n_mismatch, n_compared;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    exp_fifo = new("exp_fifo", this);
    act_fifo = new("act_fifo", this);
  endfunction

  task run_phase(uvm_phase phase);
    axis_frame e, a;
    forever begin
      exp_fifo.get(e);
      act_fifo.get(a);
      compare(e, a);
      n_compared++;
    end
  endtask

  protected function void compare(axis_frame e, axis_frame a);
    if (e.data.size() != a.data.size()) begin
      n_mismatch++;
      `uvm_error("SB_LEN", $sformatf("Frame #%0d length mismatch: exp=%0d act=%0d",
                                     n_compared, e.data.size(), a.data.size()))
      return;
    end
    foreach (e.data[i]) begin
      if (e.data[i] !== a.data[i]) begin
        n_mismatch++;
        `uvm_error("SB_DATA", $sformatf("Frame #%0d byte[%0d] mismatch: exp=%02h act=%02h (len=%0d)",
                                        n_compared, i, e.data[i], a.data[i], e.data.size()))
        return;
      end
    end
    n_match++;
    `uvm_info("SB_MATCH", $sformatf("Frame #%0d OK (%0d bytes)", n_compared, a.data.size()), UVM_HIGH)
  endfunction

  function void check_phase(uvm_phase phase);
    if (exp_fifo.used() != 0)
      `uvm_error("SB_DRAIN", $sformatf("%0d expected frames never observed at output", exp_fifo.used()))
    if (act_fifo.used() != 0)
      `uvm_error("SB_DRAIN", $sformatf("%0d unexpected frames observed at output", act_fifo.used()))
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("SB_SUMMARY", $sformatf("compared=%0d match=%0d mismatch=%0d",
                                      n_compared, n_match, n_mismatch), UVM_NONE)
  endfunction
endclass
