class apb_item extends uvm_sequence_item;
  rand bit [7:0]  addr;
  rand bit [31:0] data;
  rand bit        write;
  bit             slverr;

  `uvm_object_utils_begin(apb_item)
    `uvm_field_int(addr,   UVM_DEFAULT)
    `uvm_field_int(data,   UVM_DEFAULT)
    `uvm_field_int(write,  UVM_DEFAULT)
    `uvm_field_int(slverr, UVM_DEFAULT)
  `uvm_object_utils_end

  function new(string name = "apb_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("%s addr=0x%02h data=0x%08h slverr=%0b",
                     write ? "WR" : "RD", addr, data, slverr);
  endfunction
endclass

typedef uvm_sequencer #(apb_item) apb_sequencer;

class apb_single_seq extends uvm_sequence #(apb_item);
  `uvm_object_utils(apb_single_seq)
  bit [7:0]  addr;
  bit [31:0] data;
  bit        write;
  bit        slverr;

  function new(string name = "apb_single_seq");
    super.new(name);
  endfunction

  task body();
    req = apb_item::type_id::create("req");
    start_item(req);
    req.addr = addr; req.data = data; req.write = write;
    finish_item(req);
    data = req.data; slverr = req.slverr;
  endtask
endclass
