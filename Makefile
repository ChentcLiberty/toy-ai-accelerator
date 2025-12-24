# Minimal, stable VCS + Verdi Makefile
# - Auto-discovers RTL/TB sources
# - Supports FSDB with Verdi (WAVES=1), coverage (COVERAGE=1)
# - Override variables via command line: e.g. make run TOP=tb_mac_pipeline DEFINES="SIM=1" SEED=42

SHELL := /bin/bash

# -------- Project knobs (override on cmdline as needed) --------
TOP        ?= tb_mac_pipeline        # Testbench top module name
INC_DIRS   ?= rtl tb                 # +incdir paths (space-separated)
DEFINES    ?=                        # +define+FOO+BAR=1
WAVES      ?= 1                      # 1: link Verdi FSDB VPI and enable dumping via DUMP_FSDB define
COVERAGE   ?= 0                      # 1: enable VCS coverage
SEED       ?= 1                      # Random seed
SIM_ARGS   ?=                        # Extra args to pass to simv (e.g. +trace +dump)
TIMESCALE  ?= 1ns/1ps                # VCS timescale

# Root source dirs (auto-recursive)
RTL_DIRS   ?= rtl
TB_DIRS    ?= tb

# -------- Tool/env detection --------
# Try VERDI_HOME first, fallback to NOVAS_HOME
VERDI_HOME ?= $(if $(VERDI_HOME),$(VERDI_HOME),$(NOVAS_HOME))

# -------- Paths --------
BUILD      ?= build
CSRC_DIR   := $(BUILD)/csrc
SIMV       := $(BUILD)/simv
FLIST      := $(BUILD)/filelist.f
VCS_LOG    := $(BUILD)/vcs.log
RUN_LOG    := $(BUILD)/run.log
COV_DIR    := $(BUILD)/cov
FSDB       := $(BUILD)/waves.fsdb

# -------- Common flags --------
INC_FLAGS      := $(addprefix +incdir+,$(INC_DIRS))
DEFINE_FLAGS   := $(addprefix +define+,$(DEFINES))
VCS_BASE_FLAGS := -full64 -sverilog -lca -kdb -debug_access+all -timescale=$(TIMESCALE) \
                  -Mdir=$(CSRC_DIR) -o $(SIMV) -l $(VCS_LOG)

# Verdi FSDB VPI linkage (WAVES=1)
ifeq ($(WAVES),1)
  ifneq ($(VERDI_HOME),)
    # Modern Verdi VPI load
    VERDI_PLI := -load $(VERDI_HOME)/share/PLI/VCS/LINUX64/novas.vpi:novas_bootstrap
    # Also define DUMP_FSDB so TB can conditionally call $fsdbDumpvars
    DEFINE_FLAGS += +define+DUMP_FSDB
    DEFINE_FLAGS += +define+FSDB_TOP=$(TOP)
    RUN_WAVE_ARGS := +fsdbfile+$(FSDB)
  else
    $(warning WAVES requested but VERDI_HOME/NOVAS_HOME not set; FSDB will be unavailable)
  endif
endif

# Coverage flags
ifeq ($(COVERAGE),1)
  COV_FLAGS := -cm line+cond+tgl+fsm -cm_dir $(COV_DIR)
  RUN_COV_ARGS := -cm_name $(TOP) -cm_dir $(COV_DIR)
endif

# -------- Source discovery (prefer rg for speed) --------
# Builds a filelist with all .sv/.v/.svh/.vh in RTL_DIRS and TB_DIRS
define GEN_FLIST
mkdir -p $(BUILD) ; \
if command -v rg >/dev/null 2>&1 ; then \
  rg --files $(RTL_DIRS) $(TB_DIRS) | rg -E '\.(sv|v|svh|vh)$$' | sort > $(FLIST) ; \
else \
  find $(RTL_DIRS) $(TB_DIRS) -type f \( -name "*.sv" -o -name "*.v" -o -name "*.svh" -o -name "*.vh" \) | sort > $(FLIST) ; \
fi ; \
echo "Generated $(FLIST) (`wc -l < $(FLIST)` files)"
endef

# -------- Phony targets --------
.PHONY: all build run verdi clean realclean filelist help covreport

all: run

build: $(SIMV)

$(SIMV): $(FLIST)
	@mkdir -p $(BUILD)
	@echo "Compiling with VCS (top=$(TOP))..."
	@vcs $(VCS_BASE_FLAGS) $(INC_FLAGS) $(DEFINE_FLAGS) $(VERDI_PLI) $(COV_FLAGS) \
	     -top $(TOP) -f $(FLIST)

run: build
	@echo "Running simv (seed=$(SEED))..."
	@$(SIMV) +ntb_random_seed=$(SEED) $(RUN_WAVE_ARGS) $(RUN_COV_ARGS) $(SIM_ARGS) -l $(RUN_LOG)

verdi:
	@if [ ! -f "$(FSDB)" ]; then \
	  echo "No FSDB at $(FSDB). Enable WAVES=1 and ensure TB calls $${fsdbDumpvars} when DUMP_FSDB is defined."; \
	  echo "Example TB guard: \
\`ifdef DUMP_FSDB \
  initial begin \
    $${fsdbDumpfile}(\"$(FSDB)\"); \
    $${fsdbDumpvars}(0, $(TOP)); \
  end \
\`endif"; \
	else \
	  echo "Launching Verdi with $(FSDB) ..."; \
	  verdi -ssf $(FSDB) -top $(TOP) & \
	fi

filelist: $(FLIST)
$(FLIST):
	@$(GEN_FLIST)

covreport:
	@if [ "$(COVERAGE)" != "1" ]; then echo "Enable COVERAGE=1 first."; exit 1; fi
	@mkdir -p $(COV_DIR)
	@echo "Generating coverage report in $(COV_DIR)..."
	@urg -full64 -dir $(COV_DIR) -format both -report $(COV_DIR)/report

clean:
	@rm -rf $(SIMV) $(CSRC_DIR) $(VCS_LOG) $(RUN_LOG)

realclean: clean
	@rm -rf $(BUILD)

help:
	@echo "Targets:"
	@echo "  build           Compile only (VCS)"
	@echo "  run             Compile + run (default)"
	@echo "  verdi           Open Verdi on $(FSDB)"
	@echo "  filelist        (Re)generate file list"
	@echo "  covreport       Build coverage report (COVERAGE=1)"
	@echo "  clean|realclean Clean build artifacts"
	@echo ""
	@echo "Common overrides:"
	@echo "  TOP=<tb_top>          (default: $(TOP))"
	@echo "  DEFINES=\"FOO BAR=1\"  -> +define+FOO +define+BAR=1"
	@echo "  INC_DIRS=\"rtl tb\"    -> +incdir+..."
	@echo "  WAVES=0|1             (default: $(WAVES))"
	@echo "  COVERAGE=0|1          (default: $(COVERAGE))"
	@echo "  SEED=<int>            (default: $(SEED))"
	@echo "  SIM_ARGS=\"+args\"     (extra simv args)"

