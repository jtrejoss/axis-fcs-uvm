// -----------------------------------------------------------------------------
// axis_fcs_inserter
//   AXI-Stream (8-bit) Ethernet FCS (CRC-32) inserter with an APB register block.
//   - When CTRL.EN = 1, the CRC-32 of each input frame is appended as 4 bytes
//     (LSB first, Ethernet transmission order) and TLAST moves to the last FCS byte.
//   - When CTRL.EN = 0, frames pass through unmodified.
//   - CTRL.EN is sampled at the first byte of each frame.
//
//   Register map (APB, 32-bit, byte addressing)
//     0x00 CTRL       RW  [0] EN (reset 1)
//     0x04 FRAME_CNT  RO  input frames accepted
//     0x08 BYTE_CNT   RO  input bytes accepted
//     0x0C SCRATCH    RW  32-bit scratch register
//     0x10 VERSION    RO  VERSION parameter
//     other           PSLVERR = 1
//
//   Bug injection (for demonstrating testbench effectiveness):
//     +define+BUG_NO_FINAL_XOR        FCS missing final inversion
//     +define+BUG_IGNORE_BACKPRESSURE s_axis_tready ignores m_axis_tready
//     +define+BUG_CNT_ON_VALID        BYTE_CNT counts tvalid instead of handshakes
// -----------------------------------------------------------------------------
module axis_fcs_inserter #(
  parameter logic [31:0] VERSION = 32'h0001_0000
) (
  input  logic        clk,
  input  logic        rst_n,
  // AXI-Stream slave (input)
  input  logic [7:0]  s_axis_tdata,
  input  logic        s_axis_tvalid,
  output logic        s_axis_tready,
  input  logic        s_axis_tlast,
  // AXI-Stream master (output)
  output logic [7:0]  m_axis_tdata,
  output logic        m_axis_tvalid,
  input  logic        m_axis_tready,
  output logic        m_axis_tlast,
  // APB slave
  input  logic        psel,
  input  logic        penable,
  input  logic        pwrite,
  input  logic [7:0]  paddr,
  input  logic [31:0] pwdata,
  output logic [31:0] prdata,
  output logic        pready,
  output logic        pslverr
);

  localparam logic [7:0] A_CTRL      = 8'h00;
  localparam logic [7:0] A_FRAME_CNT = 8'h04;
  localparam logic [7:0] A_BYTE_CNT  = 8'h08;
  localparam logic [7:0] A_SCRATCH   = 8'h0C;
  localparam logic [7:0] A_VERSION   = 8'h10;

  // Reflected CRC-32 (poly 0x04C11DB7 -> 0xEDB88320), one byte per call
  function automatic logic [31:0] crc32_byte(input logic [31:0] crc, input logic [7:0] d);
    logic [31:0] c;
    c = crc ^ {24'h0, d};
    for (int i = 0; i < 8; i++)
      c = c[0] ? ((c >> 1) ^ 32'hEDB8_8320) : (c >> 1);
    return c;
  endfunction

  typedef enum logic {S_DATA, S_FCS} state_t;

  state_t      state;
  logic [31:0] crc;
  logic [31:0] fcs;
  logic [1:0]  fcs_idx;
  logic        sof;        // next accepted byte is first byte of a frame
  logic        en_frame;   // EN latched for the current frame
  logic        reg_en;
  logic [31:0] frame_cnt, byte_cnt, scratch;

  wire in_fire = s_axis_tvalid && s_axis_tready;
  wire en_cur  = sof ? reg_en : en_frame;

  // ---------------------------------------------------------------- datapath
  always_comb begin
    if (state == S_DATA) begin
      m_axis_tvalid = s_axis_tvalid;
      m_axis_tdata  = s_axis_tdata;
      m_axis_tlast  = s_axis_tlast && !en_cur;
`ifdef BUG_IGNORE_BACKPRESSURE
      s_axis_tready = 1'b1;
`else
      s_axis_tready = m_axis_tready;
`endif
    end else begin
      m_axis_tvalid = 1'b1;
      m_axis_tdata  = fcs[8*fcs_idx +: 8];
      m_axis_tlast  = (fcs_idx == 2'd3);
      s_axis_tready = 1'b0;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state    <= S_DATA;
      crc      <= '1;
      fcs      <= '0;
      fcs_idx  <= '0;
      sof      <= 1'b1;
      en_frame <= 1'b1;
    end else begin
      case (state)
        S_DATA: if (in_fire) begin
          if (sof) en_frame <= reg_en;
          if (s_axis_tlast) begin
            sof <= 1'b1;
            crc <= '1;
            if (en_cur) begin
`ifdef BUG_NO_FINAL_XOR
              fcs <= crc32_byte(crc, s_axis_tdata);
`else
              fcs <= ~crc32_byte(crc, s_axis_tdata);
`endif
              fcs_idx <= '0;
              state   <= S_FCS;
            end
          end else begin
            sof <= 1'b0;
            crc <= crc32_byte(crc, s_axis_tdata);
          end
        end
        S_FCS: if (m_axis_tready) begin
          fcs_idx <= fcs_idx + 2'd1;
          if (fcs_idx == 2'd3) state <= S_DATA;
        end
        default: state <= S_DATA;
      endcase
    end
  end

  // ---------------------------------------------------------------- APB CSRs
  wire apb_access = psel && penable;
  wire apb_wr     = apb_access && pwrite;
  wire addr_ok    = (paddr == A_CTRL) || (paddr == A_FRAME_CNT) || (paddr == A_BYTE_CNT) ||
                    (paddr == A_SCRATCH) || (paddr == A_VERSION);

  assign pready  = 1'b1;
  assign pslverr = apb_access && !addr_ok;

`ifdef BUG_CNT_ON_VALID
  wire byte_evt = s_axis_tvalid;
`else
  wire byte_evt = in_fire;
`endif

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      reg_en    <= 1'b1;
      scratch   <= '0;
      frame_cnt <= '0;
      byte_cnt  <= '0;
    end else begin
      if (apb_wr && paddr == A_CTRL)    reg_en  <= pwdata[0];
      if (apb_wr && paddr == A_SCRATCH) scratch <= pwdata;
      if (byte_evt)                     byte_cnt  <= byte_cnt + 32'd1;
      if (in_fire && s_axis_tlast)      frame_cnt <= frame_cnt + 32'd1;
    end
  end

  always_comb begin
    case (paddr)
      A_CTRL:      prdata = {31'b0, reg_en};
      A_FRAME_CNT: prdata = frame_cnt;
      A_BYTE_CNT:  prdata = byte_cnt;
      A_SCRATCH:   prdata = scratch;
      A_VERSION:   prdata = VERSION;
      default:     prdata = '0;
    endcase
  end

endmodule
