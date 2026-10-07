#!/usr/bin/env python3
"""
Flattens the project into the two files EDA Playground expects:
  eda_playground/design.sv     (RTL)
  eda_playground/testbench.sv  (interfaces, SVA, bind, UVM package, top)
Settings on EDA Playground: Testbench + Design = SystemVerilog/Verilog, UVM/OVM = UVM 1.2,
Tools = Synopsys VCS, Compile options: -timescale=1ns/1ns +vcs+flush+all +warn=all -sverilog
Run options: +UVM_TESTNAME=fcs_full_test
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INC_DIRS = [ROOT / "tb" / d for d in ("agents/axis", "agents/apb", "ral", "env", "seqs", "tests")]
RE_INC = re.compile(r'^\s*`include\s+"([^"]+)"\s*$')


def resolve(name):
    for d in INC_DIRS:
        if (d / name).exists():
            return d / name
    return None


def flatten(path: Path) -> str:
    out = []
    for line in path.read_text().splitlines():
        m = RE_INC.match(line)
        inc = resolve(m.group(1)) if m else None
        if inc:
            out.append(f"// ---- begin {inc.relative_to(ROOT)} ----")
            out.append(flatten(inc))
            out.append(f"// ---- end {inc.relative_to(ROOT)} ----")
        else:
            out.append(line)   # keeps `include "uvm_macros.svh"
    return "\n".join(out)


def main():
    out = ROOT / "eda_playground"
    out.mkdir(exist_ok=True)
    (out / "design.sv").write_text("`timescale 1ns/1ps\n" + flatten(ROOT / "rtl" / "axis_fcs_inserter.sv") + "\n")
    tb_files = ["tb/if/axis_if.sv", "tb/if/apb_if.sv", "tb/sva/axis_protocol_sva.sv",
                "tb/sva/fcs_dut_sva.sv", "tb/sva/fcs_bind.sv", "tb/fcs_tb_pkg.sv", "tb/top/tb_top.sv"]
    tb = ["`timescale 1ns/1ps", '`include "uvm_macros.svh"']
    tb += [f"// ==== {f} ====\n" + flatten(ROOT / f) for f in tb_files]
    (out / "testbench.sv").write_text("\n\n".join(tb) + "\n")
    print(f"Wrote {out / 'design.sv'} and {out / 'testbench.sv'}")


if __name__ == "__main__":
    main()
