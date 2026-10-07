#!/usr/bin/env python3
"""
Multi-seed regression runner for the axis_fcs_inserter UVM environment.

Examples
  python3 scripts/regress.py --sim vcs --seeds 10
  python3 scripts/regress.py --sim xrun --tests fcs_random_test fcs_backpressure_test --seeds 20
  python3 scripts/regress.py --sim vcs --bug BUG_NO_FINAL_XOR      # negative test: expects failures

Outputs a summary table and regress_out/summary.csv; exit code != 0 on any unexpected result.
"""
import argparse
import csv
import random
import re
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SIM_DIR = ROOT / "sim"
OUT_DIR = SIM_DIR / "regress_out"

DEFAULT_TESTS = [
    "fcs_smoke_test",
    "fcs_reg_test",
    "fcs_corner_test",
    "fcs_random_test",
    "fcs_backpressure_test",
    "fcs_full_test",
]
SINGLE_SEED_TESTS = {"fcs_smoke_test", "fcs_reg_test"}

RE_ERR = re.compile(r"^UVM_ERROR\s*:\s*(\d+)", re.M)
RE_FATAL = re.compile(r"^UVM_FATAL\s*:\s*(\d+)", re.M)
RE_COV = re.compile(r"Functional coverage: input=([\d.]+)% output=([\d.]+)%")
RE_SB = re.compile(r"compared=(\d+) match=(\d+) mismatch=(\d+)")


def sh(cmd, log=None):
    with open(log, "w") if log else open("/dev/null", "w") as fh:
        return subprocess.run(cmd, cwd=SIM_DIR, shell=True, stdout=fh, stderr=subprocess.STDOUT).returncode


def compile_vcs(defines):
    (SIM_DIR / "logs").mkdir(exist_ok=True)
    rc = sh(f"make vcs_comp DEFINES='{defines}'", OUT_DIR / "compile.log")
    if rc:
        sys.exit(f"Compilation failed, see {OUT_DIR / 'compile.log'}")


def run_one(sim, test, seed, defines, verbosity):
    log = OUT_DIR / f"{test}_{seed}.log"
    if sim == "vcs":
        cmd = (f"./simv +UVM_TESTNAME={test} +ntb_random_seed={seed} +UVM_VERBOSITY={verbosity} "
               f"-cm line+cond+fsm+tgl+branch+assert -cm_dir cov.vdb -cm_name {test}_{seed}")
    else:
        cmd = f"make xrun TEST={test} SEED={seed} VERB={verbosity} DEFINES='{defines}'"
    t0 = time.time()
    sh(cmd, log)
    return parse_log(log, time.time() - t0)


def parse_log(log, elapsed):
    txt = log.read_text(errors="ignore") if log.exists() else ""
    errs = sum(int(x) for x in RE_ERR.findall(txt))
    fatals = sum(int(x) for x in RE_FATAL.findall(txt))
    passed = "** TEST PASSED **" in txt and errs == 0 and fatals == 0
    cov = RE_COV.search(txt)
    sb = RE_SB.search(txt)
    return {
        "status": "PASS" if passed else "FAIL",
        "errors": errs,
        "fatals": fatals,
        "cov_in": cov.group(1) if cov else "-",
        "cov_out": cov.group(2) if cov else "-",
        "frames": sb.group(1) if sb else "-",
        "time_s": f"{elapsed:.1f}",
        "log": log.name,
    }


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--sim", choices=["vcs", "xrun"], default="vcs")
    ap.add_argument("--tests", nargs="+", default=DEFAULT_TESTS)
    ap.add_argument("--seeds", type=int, default=5, help="seeds per random test")
    ap.add_argument("--seed-base", type=int, default=None, help="reproducible seed list")
    ap.add_argument("--bug", default=None, help="inject RTL bug define; failures are then EXPECTED")
    ap.add_argument("--verbosity", default="UVM_LOW")
    args = ap.parse_args()

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    defines = f"+define+{args.bug}" if args.bug else ""
    rng = random.Random(args.seed_base)

    if args.sim == "vcs":
        compile_vcs(defines)

    rows = []
    for test in args.tests:
        n = 1 if test in SINGLE_SEED_TESTS else args.seeds
        for _ in range(n):
            seed = rng.randint(1, 2**31 - 1)
            r = run_one(args.sim, test, seed, defines, args.verbosity)
            r.update(test=test, seed=seed)
            rows.append(r)
            print(f"{r['status']:4}  {test:24} seed={seed:<11} err={r['errors']} fatal={r['fatals']} "
                  f"cov_in={r['cov_in']}% cov_out={r['cov_out']}% ({r['time_s']} s)")

    with open(OUT_DIR / "summary.csv", "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=["test", "seed", "status", "errors", "fatals",
                                           "cov_in", "cov_out", "frames", "time_s", "log"])
        w.writeheader()
        w.writerows(rows)

    n_pass = sum(r["status"] == "PASS" for r in rows)
    print(f"\n{n_pass}/{len(rows)} runs passed. Summary: {OUT_DIR / 'summary.csv'}")

    if args.sim == "vcs" and not args.bug:
        sh("make cov_vcs", OUT_DIR / "urg.log")
        print(f"Code/functional coverage report: {SIM_DIR / 'cov_report' / 'dashboard.txt'}")

    if args.bug:
        detected = n_pass < len(rows)
        print(f"Bug {args.bug}: {'DETECTED' if detected else 'NOT DETECTED (testbench hole!)'}")
        sys.exit(0 if detected else 1)
    sys.exit(0 if n_pass == len(rows) else 1)


if __name__ == "__main__":
    main()
