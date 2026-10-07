// Functional coverage collected from input and output monitors
`uvm_analysis_imp_decl(_in)
`uvm_analysis_imp_decl(_out)

class fcs_coverage extends uvm_component;
  `uvm_component_utils(fcs_coverage)

  uvm_analysis_imp_in  #(axis_frame, fcs_coverage) in_imp;
  uvm_analysis_imp_out #(axis_frame, fcs_coverage) out_imp;
  fcs_reg_block regmodel;

  // sampled values
  int unsigned s_len, s_stalls;
  bit          s_en, s_gaps;
  int          s_pat;  // 0: mixed, 1: all-zeros, 2: all-ones

  // NOTE: 'small', 'medium', 'large' are Verilog keywords -> bins named by range
  covergroup cg_in;
    option.per_instance = 1;
    cp_len: coverpoint s_len {
      bins len_1       = {1};
      bins len_2_15    = {[2:15]};
      bins len_16_63   = {[16:63]};
      bins len_64_127  = {[64:127]};
      bins len_128_255 = {[128:255]};
      bins len_256     = {256};
    }
    cp_en:      coverpoint s_en;
    cp_gaps:    coverpoint s_gaps { bins back_to_back = {0}; bins with_idles = {1}; }
    cp_pattern: coverpoint s_pat  { bins mixed = {0}; bins all_zeros = {1}; bins all_ones = {2}; }
    x_len_en:   cross cp_len, cp_en;
    x_gaps_en:  cross cp_gaps, cp_en;
    x_pat_en:   cross cp_pattern, cp_en;
  endgroup

  covergroup cg_out;
    option.per_instance = 1;
    cp_stalls: coverpoint s_stalls { bins none = {0}; bins light = {[1:3]}; bins heavy = {[4:$]}; }
    cp_en:     coverpoint s_en;
    x_stall_en: cross cp_stalls, cp_en;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    in_imp  = new("in_imp", this);
    out_imp = new("out_imp", this);
    cg_in   = new();
    cg_out  = new();
  endfunction

  protected function int pattern_of(axis_frame t);
    bit all0 = 1, all1 = 1;
    foreach (t.data[i]) begin
      if (t.data[i] != 8'h00) all0 = 0;
      if (t.data[i] != 8'hFF) all1 = 0;
    end
    return all0 ? 1 : (all1 ? 2 : 0);
  endfunction

  function void write_in(axis_frame t);
    s_len  = t.data.size();
    s_en   = regmodel.ctrl.en.get_mirrored_value();
    s_gaps = (t.idle_cycles > 0);
    s_pat  = pattern_of(t);
    cg_in.sample();
  endfunction

  function void write_out(axis_frame t);
    s_stalls = t.stall_cycles;
    s_en     = regmodel.ctrl.en.get_mirrored_value();
    cg_out.sample();
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("COV", $sformatf("Functional coverage: input=%0.2f%% output=%0.2f%%",
                               cg_in.get_inst_coverage(), cg_out.get_inst_coverage()), UVM_NONE)
    // Per-coverpoint breakdown makes holes visible directly in the log
    `uvm_info("COV", $sformatf({"  cg_in : len=%0.1f en=%0.1f gaps=%0.1f pattern=%0.1f | ",
                                "len x en=%0.1f gaps x en=%0.1f pattern x en=%0.1f"},
              cg_in.cp_len.get_inst_coverage(),   cg_in.cp_en.get_inst_coverage(),
              cg_in.cp_gaps.get_inst_coverage(),  cg_in.cp_pattern.get_inst_coverage(),
              cg_in.x_len_en.get_inst_coverage(), cg_in.x_gaps_en.get_inst_coverage(),
              cg_in.x_pat_en.get_inst_coverage()), UVM_NONE)
    `uvm_info("COV", $sformatf("  cg_out: stalls=%0.1f en=%0.1f | stalls x en=%0.1f",
              cg_out.cp_stalls.get_inst_coverage(), cg_out.cp_en.get_inst_coverage(),
              cg_out.x_stall_en.get_inst_coverage()), UVM_NONE)
  endfunction
endclass
