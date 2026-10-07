// UVM register model for axis_fcs_inserter
class fcs_ctrl_reg extends uvm_reg;
  `uvm_object_utils(fcs_ctrl_reg)
  rand uvm_reg_field en;

  function new(string name = "fcs_ctrl_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    en = uvm_reg_field::type_id::create("en");
    //            parent size lsb access volatile reset has_reset is_rand indiv
    en.configure(this, 1,   0,  "RW",  0,       1'b1, 1,        1,      0);
  endfunction
endclass

// Generic single-field 32-bit register; access/volatile/reset set before build()
class fcs_reg32 extends uvm_reg;
  `uvm_object_utils(fcs_reg32)
  rand uvm_reg_field value;
  string             acc     = "RW";
  bit                vol     = 0;
  uvm_reg_data_t     rst_val = 0;

  function new(string name = "fcs_reg32");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    value = uvm_reg_field::type_id::create("value");
    value.configure(this, 32, 0, acc, vol, rst_val, 1, (acc == "RW"), 0);
  endfunction
endclass

class fcs_reg_block extends uvm_reg_block;
  `uvm_object_utils(fcs_reg_block)

  rand fcs_ctrl_reg ctrl;
  rand fcs_reg32    frame_cnt;
  rand fcs_reg32    byte_cnt;
  rand fcs_reg32    scratch;
  rand fcs_reg32    version;

  function new(string name = "fcs_reg_block");
    super.new(name, UVM_NO_COVERAGE);
  endfunction

  local function fcs_reg32 mk(string name, string acc, bit vol, uvm_reg_data_t rst);
    fcs_reg32 r = fcs_reg32::type_id::create(name);
    r.acc = acc; r.vol = vol; r.rst_val = rst;
    r.configure(this);
    r.build();
    return r;
  endfunction

  virtual function void build();
    default_map = create_map("default_map", 'h0, 4, UVM_LITTLE_ENDIAN);

    ctrl = fcs_ctrl_reg::type_id::create("ctrl");
    ctrl.configure(this);
    ctrl.build();

    frame_cnt = mk("frame_cnt", "RO", 1, 0);
    byte_cnt  = mk("byte_cnt",  "RO", 1, 0);
    scratch   = mk("scratch",   "RW", 0, 0);
    version   = mk("version",   "RO", 0, 32'h0001_0000);

    default_map.add_reg(ctrl,      'h00, "RW");
    default_map.add_reg(frame_cnt, 'h04, "RO");
    default_map.add_reg(byte_cnt,  'h08, "RO");
    default_map.add_reg(scratch,   'h0C, "RW");
    default_map.add_reg(version,   'h10, "RO");

    // Traffic-dependent counters are excluded from bit-bash
    uvm_resource_db #(bit)::set({"REG::", frame_cnt.get_full_name()}, "NO_REG_BIT_BASH_TEST", 1, this);
    uvm_resource_db #(bit)::set({"REG::", byte_cnt.get_full_name()},  "NO_REG_BIT_BASH_TEST", 1, this);

    lock_model();
  endfunction
endclass

class reg2apb_adapter extends uvm_reg_adapter;
  `uvm_object_utils(reg2apb_adapter)

  function new(string name = "reg2apb_adapter");
    super.new(name);
    supports_byte_enable = 0;
    provides_responses   = 0;
  endfunction

  virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
    apb_item it = apb_item::type_id::create("reg_item");
    it.write = (rw.kind == UVM_WRITE);
    it.addr  = rw.addr;
    it.data  = rw.data;
    return it;
  endfunction

  virtual function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
    apb_item it;
    if (!$cast(it, bus_item)) `uvm_fatal("CAST", "bus2reg: not an apb_item")
    rw.kind   = it.write ? UVM_WRITE : UVM_READ;
    rw.addr   = it.addr;
    rw.data   = it.data;
    rw.status = it.slverr ? UVM_NOT_OK : UVM_IS_OK;
  endfunction
endclass
