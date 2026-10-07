// ---------------------------------------------------------------------------
// Virtual sequences
// ---------------------------------------------------------------------------
class fcs_base_vseq extends uvm_sequence;
  `uvm_object_utils(fcs_base_vseq)
  `uvm_declare_p_sequencer(fcs_vsequencer)

  int unsigned drain_timeout_ns = 2_000_000;   // 2 ms per drain

  function new(string name = "fcs_base_vseq");
    super.new(name);
  endfunction

  task set_enable(bit en);
    uvm_status_e st;
    p_sequencer.regmodel.ctrl.write(st, en, .parent(this));
    if (st != UVM_IS_OK) `uvm_error("VSEQ", "CTRL write failed")
    `uvm_info("VSEQ", $sformatf("CTRL.EN <= %0b", en), UVM_MEDIUM)
  endtask

  task send(int unsigned n, int unsigned min_len = 1, int unsigned max_len = 256,
            int unsigned max_gap = 10, bit fix_pat = 0, axis_pattern_e pat = PAT_RANDOM);
    axis_frame_seq s = axis_frame_seq::type_id::create("s");
    s.n_frames = n; s.min_len = min_len; s.max_len = max_len; s.max_gap = max_gap;
    s.fix_pattern = fix_pat; s.pattern = pat;
    s.start(p_sequencer.axis_sqr, this);
  endtask

  // Wait until every predicted frame has been compared at the output
  task drain();
    fork
      wait (p_sequencer.sb.n_compared == p_sequencer.ref_m.n_frames);
      begin
        #(drain_timeout_ns * 1ns);
        `uvm_fatal("DRAIN", $sformatf("Timeout: %0d of %0d frames compared",
                   p_sequencer.sb.n_compared, p_sequencer.ref_m.n_frames))
      end
    join_any
    disable fork;
  endtask

  // End-of-test CSR check: hardware counters vs. reference model
  task check_counters();
    uvm_status_e   st;
    uvm_reg_data_t frames, bytes;
    p_sequencer.regmodel.frame_cnt.read(st, frames, .parent(this));
    p_sequencer.regmodel.byte_cnt.read(st, bytes, .parent(this));
    if (frames != p_sequencer.ref_m.n_frames)
      `uvm_error("CSR", $sformatf("FRAME_CNT=%0d expected %0d", frames, p_sequencer.ref_m.n_frames))
    if (bytes != p_sequencer.ref_m.n_bytes)
      `uvm_error("CSR", $sformatf("BYTE_CNT=%0d expected %0d", bytes, p_sequencer.ref_m.n_bytes))
    `uvm_info("CSR", $sformatf("FRAME_CNT=%0d BYTE_CNT=%0d", frames, bytes), UVM_LOW)
  endtask
endclass

// Directed bring-up: a few short frames, FCS enabled
class fcs_smoke_vseq extends fcs_base_vseq;
  `uvm_object_utils(fcs_smoke_vseq)
  function new(string name = "fcs_smoke_vseq"); super.new(name); endfunction
  task body();
    set_enable(1);
    send(5, 1, 64, 0);
    drain();
    check_counters();
  endtask
endclass

// Constrained-random traffic in batches, toggling CTRL.EN between batches
class fcs_random_vseq extends fcs_base_vseq;
  `uvm_object_utils(fcs_random_vseq)
  int unsigned n_batches = 8;
  int unsigned frames_per_batch = 25;
  function new(string name = "fcs_random_vseq"); super.new(name); endfunction
  task body();
    for (int b = 0; b < n_batches; b++) begin
      bit en = (b < 2) ? b[0] : $urandom_range(1, 0);   // guarantee both modes
      set_enable(en);
      send(frames_per_batch);
      drain();                                          // EN only changes when idle
    end
    check_counters();
  endtask
endclass

// Length and data-pattern corners
class fcs_corner_vseq extends fcs_base_vseq;
  `uvm_object_utils(fcs_corner_vseq)
  function new(string name = "fcs_corner_vseq"); super.new(name); endfunction
  task body();
    int unsigned lens[] = '{1, 2, 255, 256};
    for (int en = 0; en < 2; en++) begin
      set_enable(en[0]);
      foreach (lens[i]) send(1, lens[i], lens[i], 0);
      send(2, 1, 256, 0, 1, PAT_ZEROS);
      send(2, 1, 256, 0, 1, PAT_ONES);
      send(4, 1, 8, 10);                                // short frames with idles
      drain();
    end
    check_counters();
  endtask
endclass

// Coverage closure: corner frames, then random traffic swept across TREADY 100/80/30%
class fcs_full_vseq extends fcs_base_vseq;
  `uvm_object_utils(fcs_full_vseq)
  function new(string name = "fcs_full_vseq"); super.new(name); endfunction
  task body();
    fcs_corner_vseq corner = fcs_corner_vseq::type_id::create("corner");
    int unsigned    rdy[]  = '{100, 80, 30};
    corner.start(p_sequencer, this);
    foreach (rdy[r]) begin
      p_sequencer.out_cfg.ready_pct = rdy[r];
      `uvm_info("VSEQ", $sformatf("TREADY probability = %0d%%", rdy[r]), UVM_LOW)
      for (int b = 0; b < 4; b++) begin
        set_enable(b[0]);
        send(25);
        drain();
      end
    end
    check_counters();
  endtask
endclass

// Register checks: reset values, bit-bash, unmapped address error response
class fcs_reg_vseq extends fcs_base_vseq;
  `uvm_object_utils(fcs_reg_vseq)
  function new(string name = "fcs_reg_vseq"); super.new(name); endfunction
  task body();
    uvm_reg_hw_reset_seq rst_seq = uvm_reg_hw_reset_seq::type_id::create("rst_seq");
    uvm_reg_bit_bash_seq bb_seq  = uvm_reg_bit_bash_seq::type_id::create("bb_seq");
    apb_single_seq       bad     = apb_single_seq::type_id::create("bad");

    rst_seq.model = p_sequencer.regmodel;
    rst_seq.start(null, this);

    bb_seq.model = p_sequencer.regmodel;
    bb_seq.start(null, this);

    bad.addr = 8'h40; bad.write = 0;
    bad.start(p_sequencer.apb_sqr, this);
    if (!bad.slverr) `uvm_error("REG", "Unmapped read 0x40 did not return PSLVERR")
    bad.addr = 8'h44; bad.write = 1; bad.data = 32'hDEAD_BEEF;
    bad.start(p_sequencer.apb_sqr, this);
    if (!bad.slverr) `uvm_error("REG", "Unmapped write 0x44 did not return PSLVERR")
  endtask
endclass
