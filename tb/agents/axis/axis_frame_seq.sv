// Sends n_frames random frames within [min_len:max_len]
class axis_frame_seq extends uvm_sequence #(axis_frame);
  `uvm_object_utils(axis_frame_seq)

  int unsigned   n_frames    = 10;
  int unsigned   min_len     = 1;
  int unsigned   max_len     = 256;
  int unsigned   max_gap     = 10;
  bit            fix_pattern = 0;
  axis_pattern_e pattern     = PAT_RANDOM;

  function new(string name = "axis_frame_seq");
    super.new(name);
  endfunction

  task body();
    repeat (n_frames) begin
      req = axis_frame::type_id::create("req");
      start_item(req);
      req.max_gap = max_gap;
      if (!req.randomize() with {
            len inside {[local::min_len : local::max_len]};
            local::fix_pattern -> pattern == local::pattern; })
        `uvm_fatal("RAND", "axis_frame randomization failed")
      finish_item(req);
    end
  endtask
endclass
