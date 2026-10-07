# Usage:
#   make vcs   TEST=fcs_full_test SEED=7
#   make xrun  TEST=fcs_backpressure_test SEED=3
#   make vcs   TEST=fcs_random_test DEFINES=+define+BUG_NO_FINAL_XOR
#   make verdi                       # open last VCS run in Verdi
#   make cov_vcs                     # merge/report coverage with URG
#   make verilator_sanity            # open-source RTL sanity test (no UVM)

TEST     ?= fcs_smoke_test
SEED     ?= 1
VERB     ?= UVM_MEDIUM
DEFINES  ?=
RUN_ARGS ?=
LOGDIR   ?= logs

VCS_COV  = -cm line+cond+fsm+tgl+branch+assert
VCS_COMP = vcs -full64 -sverilog -ntb_opts uvm-1.2 -timescale=1ns/1ps \
           -debug_access+all -kdb -lca $(VCS_COV) -cm_dir cov.vdb \
           +define+FSDB $(DEFINES) -f files.f -l $(LOGDIR)/compile_vcs.log -o simv

XRUN     = xrun -64bit -sv -uvm -uvmhome CDNS-1.2 -timescale 1ns/1ps -access +rwc \
           -coverage all -covoverwrite -covworkdir cov_work -covscope fcs \
           -covtest $(TEST)_$(SEED) $(DEFINES) -f files.f

.PHONY: all vcs vcs_comp vcs_run xrun verdi cov_vcs clean verilator_sanity

all: vcs

$(LOGDIR):
	mkdir -p $(LOGDIR)

vcs_comp: | $(LOGDIR)
	$(VCS_COMP)

vcs_run: | $(LOGDIR)
	./simv +UVM_TESTNAME=$(TEST) +ntb_random_seed=$(SEED) +UVM_VERBOSITY=$(VERB) \
	  $(VCS_COV) -cm_dir cov.vdb -cm_name $(TEST)_$(SEED) $(RUN_ARGS) \
	  -l $(LOGDIR)/$(TEST)_$(SEED).log

vcs: vcs_comp vcs_run

xrun: | $(LOGDIR)
	$(XRUN) +UVM_TESTNAME=$(TEST) -svseed $(SEED) +UVM_VERBOSITY=$(VERB) $(RUN_ARGS) \
	  -l $(LOGDIR)/$(TEST)_$(SEED).log

verdi:
	verdi -ssf waves.fsdb -dbdir simv.daidir &

cov_vcs:
	urg -dir cov.vdb -format both -report cov_report

# Open-source RTL sanity check (no UVM): Verilator >= 5.0 with --timing
verilator_sanity:
	verilator --binary --timing --timescale 1ns/1ps -Wno-fatal -Wno-lint $(subst +define+,-D,$(DEFINES)) \
	  ../rtl/axis_fcs_inserter.sv ../tb/standalone/tb_rtl_sanity.sv --top-module tb_rtl_sanity -o sanity
	./obj_dir/sanity

clean:
	rm -rf simv* csrc *.vdb *.key ucli.key vc_hdrs.h verdiLog novas* *.fsdb *.vcd \
	       xcelium.d xrun.* cov_work cov_report $(LOGDIR) regress_out obj_dir
