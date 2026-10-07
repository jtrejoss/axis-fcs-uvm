`timescale 1ns/1ps
// Standalone (non-UVM) RTL sanity test. Runs on open-source Verilator:
//   make -C sim verilator_sanity
// Note: drives/samples on negedge to stay race-free across simulators.
module tb_rtl_sanity;
  logic clk=0, rst_n=0; always #5 clk=~clk;
  logic [7:0] sd, md; logic sv, sr, sl, mv, mr, ml;
  logic psel=0, penable=0, pwrite=0; logic [7:0] paddr=0; logic [31:0] pwdata=0, prdata; logic pready, pslverr;
  axis_fcs_inserter dut(.clk, .rst_n, .s_axis_tdata(sd), .s_axis_tvalid(sv), .s_axis_tready(sr), .s_axis_tlast(sl),
    .m_axis_tdata(md), .m_axis_tvalid(mv), .m_axis_tready(mr), .m_axis_tlast(ml),
    .psel, .penable, .pwrite, .paddr, .pwdata, .prdata, .pready, .pslverr);
  function automatic logic [31:0] crc(input byte unsigned d[$]);
    logic [31:0] c = '1;
    foreach (d[i]) begin c ^= d[i]; repeat(8) c = c[0] ? (c>>1)^32'hEDB88320 : c>>1; end
    return ~c;
  endfunction
  byte unsigned exp_q[$]; int exp_last[$]; int errors=0, nb=0, nf=0, nout=0, ready_pct=50;
  always @(posedge clk) mr <= ($urandom_range(99,0) < ready_pct);
  // output checker
  always @(negedge clk) if (rst_n && mv && mr) begin
    byte unsigned e; int l; e = exp_q.pop_front(); l = exp_last.pop_front();
    if (md !== e || ml !== l[0]) begin errors++; if (errors<10) $display("ERR t=%0t got %h/%b exp %h/%b", $time, md, ml, e, l); end
    nout++;
  end
  task automatic apb(input bit wr, input [7:0] a, input [31:0] d, output [31:0] r);
    @(negedge clk); psel=1; penable=0; pwrite=wr; paddr=a; pwdata=d;
    @(negedge clk); penable=1; r = prdata; @(negedge clk); psel=0; penable=0;
  endtask
  task automatic send(input bit en, input int len);
    byte unsigned d[$]; logic [31:0] f;
    for (int i=0;i<len;i++) d.push_back($urandom);
    f = crc(d);
    foreach (d[i]) begin exp_q.push_back(d[i]); exp_last.push_back(!en && i==len-1); end
    if (en) for (int i=0;i<4;i++) begin exp_q.push_back(f[8*i+:8]); exp_last.push_back(i==3); end
    foreach (d[i]) begin
      @(negedge clk);
      if ($urandom_range(9,0)==0) begin sv=0; repeat($urandom_range(3,1)) @(negedge clk); end
      sv=1; sd=d[i]; sl=(i==len-1);
      while(!sr) @(negedge clk);
      @(posedge clk);
      nb++;
    end
    @(negedge clk); sv=0; sl=0; nf++;
  endtask
  logic [31:0] r;
  initial begin
    sv=0; sl=0; sd=0; mr=0;
    repeat(3) @(posedge clk); rst_n=1;
    apb(0,8'h10,0,r); if (r!==32'h00010000) begin errors++; $display("VERSION %h", r); end
    apb(0,8'h00,0,r); if (r!==1) begin errors++; $display("CTRL reset %h", r); end
    for (int b=0;b<6;b++) begin
      bit en; en = b[0];
      while(exp_q.size()!=0) @(posedge clk); repeat(3) @(posedge clk);
      apb(1,8'h00,en,r);
      ready_pct = (b<2) ? 100 : 30;
      for (int k=0;k<30;k++) send(en, (k==0)?1:(k==1)?256:$urandom_range(256,1));
    end
    while(exp_q.size()!=0) @(posedge clk); repeat(5) @(posedge clk);
    apb(0,8'h04,0,r); if (r!==nf) begin errors++; $display("FRAME_CNT %0d exp %0d", r, nf); end
    apb(0,8'h08,0,r); if (r!==nb) begin errors++; $display("BYTE_CNT %0d exp %0d", r, nb); end
    apb(1,8'h0C,32'hA5A5_5A5A,r); apb(0,8'h0C,0,r); if (r!==32'hA5A55A5A) errors++;
    @(negedge clk); psel=1; paddr=8'h40; pwrite=0; @(negedge clk); penable=1; #1 if(!pslverr) begin errors++; $display("no slverr"); end
    @(negedge clk); psel=0; penable=0;
    $display("frames=%0d bytes=%0d out_bytes=%0d errors=%0d -> %s", nf, nb, nout, errors, errors?"FAIL":"PASS");
    $finish;
  end
  initial begin #20ms; $display("TIMEOUT"); $finish; end
endmodule
