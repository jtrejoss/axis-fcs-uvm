// Transaction-level reference model: predicts the output frame from the input frame.
// Uses a table-driven CRC-32, intentionally different from the bitwise RTL implementation.
class fcs_ref_model extends uvm_subscriber #(axis_frame);
  `uvm_component_utils(fcs_ref_model)

  uvm_analysis_port #(axis_frame) ap;
  fcs_reg_block                   regmodel;
  int unsigned                    n_frames;   // input frames observed
  longint unsigned                n_bytes;    // input bytes observed
  protected bit [31:0]            table_q[256];

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
    foreach (table_q[i]) begin
      bit [31:0] c = i;
      repeat (8) c = c[0] ? ((c >> 1) ^ 32'hEDB8_8320) : (c >> 1);
      table_q[i] = c;
    end
  endfunction

  function bit [31:0] crc32(bit [7:0] d[]);
    bit [31:0] c = '1;
    foreach (d[i]) c = table_q[(c ^ d[i]) & 8'hFF] ^ (c >> 8);
    return ~c;
  endfunction

  function void write(axis_frame t);
    axis_frame exp = axis_frame::type_id::create("exp");
    bit        en  = regmodel.ctrl.en.get_mirrored_value();
    int        n   = t.data.size();
    n_frames++;
    n_bytes += n;
    if (en) begin
      bit [31:0] fcs = crc32(t.data);
      exp.data = new[n + 4](t.data);
      for (int i = 0; i < 4; i++) exp.data[n + i] = fcs[8*i +: 8];
    end else begin
      exp.data = t.data;
    end
    exp.len = exp.data.size();
    ap.write(exp);
  endfunction
endclass
