# Verification Plan — axis_fcs_inserter

## 1. Scope
Block-level verification of `axis_fcs_inserter`: an 8-bit AXI-Stream Ethernet FCS (CRC-32) inserter
with an APB control/status register block.

Out of scope: multi-byte TKEEP datapaths, TUSER/TID/TDEST, clock-domain crossing, mid-frame reset.

## 2. Features, checks and coverage

| ID | Feature | Checking mechanism | Coverage | Tests |
|----|---------|--------------------|----------|-------|
| F1 | CRC-32 FCS appended (EN=1), LSB first, TLAST on last FCS byte | Scoreboard vs. table-driven reference model; `a_fcs_last` | `cg_in.x_len_en` | smoke, random, corner, full |
| F2 | Pass-through when EN=0 (no FCS, TLAST preserved) | Scoreboard | `cg_in.x_len_en` (en=0) | random, corner, full |
| F3 | EN sampled at start of frame | Scoreboard (EN changed only when idle) | `cg_in.cp_en` | random, full |
| F4 | Frame lengths 1..256 incl. single-byte and max frames | Scoreboard | `cg_in.cp_len` (6 bins) | corner, random, full |
| F5 | Data patterns (all-0x00 / all-0xFF / random) | Scoreboard | `cg_in.x_pat_en` | corner, full |
| F6 | Input idle cycles inside a frame | Scoreboard; SVA payload stability | `cg_in.x_gaps_en` | random, corner, full |
| F7 | Output backpressure (TREADY low), incl. during FCS bytes | SVA `a_valid_hold`, `a_payload_stable`, `a_no_input_in_fcs`; scoreboard | `cg_out.x_stall_en`; `c_fcs_backpressure` | backpressure, full |
| F8 | AXI-Stream protocol compliance on both ports | `axis_protocol_sva` (bound) | SVA cover properties | all |
| F9 | CSR reset values and access policies | `uvm_reg_hw_reset_seq`, `uvm_reg_bit_bash_seq` | — | reg |
| F10 | FRAME_CNT / BYTE_CNT accuracy | End-of-test RAL read vs. reference model counters | — | smoke, random, corner, backpressure, full |
| F11 | PSLVERR on unmapped addresses | Directed APB access | — | reg |

## 3. Testbench architecture
- **AXI-Stream agents**: active master (constrained-random frames and idle gaps), sink agent with
  randomized TREADY (`ready_pct` knob, adjustable at runtime), passive monitors on both ports.
- **APB agent** + **RAL model** (`fcs_reg_block`) with `reg2apb_adapter` and explicit `uvm_reg_predictor`.
- **Reference model**: table-driven CRC-32 (independent from the bitwise RTL implementation),
  reads CTRL.EN from the RAL mirror.
- **Scoreboard**: in-order compare through TLM analysis FIFOs; drain check in `check_phase`.
- **Coverage collector**: `cg_in`, `cg_out` covergroups with per-coverpoint report.
- **SVA**: protocol checker bound to both ports + white-box DUT assertions.
- **Virtual sequencer / sequences**: smoke, random, corner, full (closure), register.

## 4. Testbench effectiveness (bug injection) — results on Synopsys VCS

| Define | Injected bug | Test | Detected by |
|--------|--------------|------|-------------|
| `BUG_NO_FINAL_XOR` | FCS missing final inversion | fcs_random_test | Scoreboard `SB_DATA` (75 errors) ✅ |
| `BUG_IGNORE_BACKPRESSURE` | Input accepted while output stalled | fcs_backpressure_test | SVA `a_payload_stable` on output port ✅ |
| `BUG_CNT_ON_VALID` | BYTE_CNT counts TVALID instead of handshakes | fcs_random_test | End-of-test CSR check (28125 vs 22326) ✅ |

## 5. Coverage analysis log
**Hole found (regression 1):** input coverage 76–88% in `fcs_random_test`, output coverage 55–72% in
`fcs_backpressure_test`.

Root causes:
1. **Stimulus bug — `dist :=` vs `:/`.** `len dist {1 := 5, [2:15] := 20, ...}` assigns the weight to
   *each value* of a range, so P(len=1) = P(len=256) ≈ 0.1%. The same issue on the gap constraint made
   ~50% of bytes have idle cycles, so long frames were almost never back-to-back.
   Fix: `:/` (weight split across the range) → P(len=1) = P(len=256) = 5%, P(gap) = 20%.
2. **Per-test bins by design.** At 30% TREADY every frame has heavy stalls, so the `none`/`light`
   stall bins are unreachable in that test; they are hit only at higher TREADY.
   Fix: `fcs_full_test` runs corner frames and then sweeps TREADY 100/80/30% within a single run.

**Result after fixes:** `fcs_random_test` input coverage 88.10% → 96.43% (seed 1).
`fcs_full_test`: 100% input / 100% output functional coverage, all coverpoints and crosses, seeds 1, 7, 42.

Residual holes in `fcs_random_test` (single run, accepted — closed by `fcs_full_test`):
- `pattern x en` 83.3%: all-0x00/0xFF frames are 5% per frame and EN is random per batch, so one EN mode may see too few frames.
- `stalls x en` 83.3%: at 80% TREADY a frame with FCS (len+4 bytes) rarely completes without any stall.

## 6. Sign-off criteria
- All regression tests pass across N seeds per random test.
- 100% functional coverage on `cg_in` / `cg_out` in `fcs_full_test`; code coverage reviewed with exclusions justified.
- Every injected bug detected by at least one test.
