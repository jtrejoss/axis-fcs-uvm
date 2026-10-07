// One AXI-Stream frame (packet). Randomizable payload, length and per-byte idle gaps.
typedef enum {PAT_RANDOM, PAT_ZEROS, PAT_ONES} axis_pattern_e;

class axis_frame extends uvm_sequence_item;
  rand int unsigned   len;
  rand bit [7:0]      data[];
  rand int unsigned   gap[];        // idle cycles inserted before each byte (driver)
  rand axis_pattern_e pattern;

  // Knob (non-random): upper bound for idle gaps
  int unsigned max_gap = 10;

  // Observed by monitors (not randomized)
  int unsigned stall_cycles;        // cycles with TVALID=1, TREADY=0
  int unsigned idle_cycles;         // cycles with TVALID=0 inside the frame

  // ':/' splits the weight across a range. (The first version used ':=', which assigns
  // the weight to EACH value: len=1 and len=256 became ~0.1% likely and 50% of bytes
  // had idle gaps -> coverage holes found during regression.)
  constraint c_len  { len inside {[1:256]};
                      len dist {1 :/ 5, [2:15] :/ 20, [16:63] :/ 30,
                                [64:127] :/ 25, [128:255] :/ 15, 256 :/ 5}; }
  constraint c_size { data.size() == len; gap.size() == len; }
  constraint c_gap  { foreach (gap[i]) { gap[i] <= max_gap;
                                         gap[i] dist {0 :/ 80, [1:3] :/ 15, [4:10] :/ 5}; } }
  constraint c_pat  { pattern dist {PAT_RANDOM := 90, PAT_ZEROS := 5, PAT_ONES := 5};
                      foreach (data[i]) {
                        (pattern == PAT_ZEROS) -> data[i] == 8'h00;
                        (pattern == PAT_ONES)  -> data[i] == 8'hFF; } }

  `uvm_object_utils_begin(axis_frame)
    `uvm_field_int(len, UVM_DEFAULT | UVM_DEC)
    `uvm_field_array_int(data, UVM_DEFAULT)
    `uvm_field_array_int(gap, UVM_DEFAULT | UVM_NOCOMPARE)
    `uvm_field_enum(axis_pattern_e, pattern, UVM_DEFAULT | UVM_NOCOMPARE)
  `uvm_object_utils_end

  function new(string name = "axis_frame");
    super.new(name);
  endfunction

  function string convert2string();
    string s = $sformatf("len=%0d stalls=%0d idles=%0d data=", data.size(), stall_cycles, idle_cycles);
    foreach (data[i]) begin
      if (i == 8) begin s = {s, "..."}; break; end
      s = {s, $sformatf("%02h ", data[i])};
    end
    return s;
  endfunction
endclass

typedef uvm_sequencer #(axis_frame) axis_sequencer;
