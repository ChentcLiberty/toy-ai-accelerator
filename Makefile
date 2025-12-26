# ============================================================
# Toy AI Accelerator - VCS + Verdi Makefile
# ============================================================

SHELL := /bin/bash

# -------- Project Configuration --------
TOP        ?= tb_mac_pipeline
WAVES      ?= 1
COVERAGE   ?= 0
SEED       ?= 1
TIMESCALE  ?= 1ns/1ps

RTL_DIRS   := rtl
TB_DIRS    := tb
INC_DIRS   := rtl tb

# -------- Tool Detection --------
VERDI_HOME ?= $(NOVAS_HOME)

# -------- Paths (每个 TOP 独立) --------
BUILD      := build
SIMV       := $(BUILD)/simv_$(TOP)
FLIST      := $(BUILD)/filelist.f
FSDB       := $(BUILD)/$(TOP).fsdb
VCS_LOG    := $(BUILD)/vcs_$(TOP).log
RUN_LOG    := $(BUILD)/run_$(TOP).log
COV_DIR    := $(BUILD)/cov

# -------- Auto-discover Testbenches --------
TESTBENCHES := $(basename $(notdir $(wildcard $(TB_DIRS)/tb_*.sv)))

# -------- Source Files --------
SRC_FILES  := $(shell find $(RTL_DIRS) $(TB_DIRS) -type f \( -name "*.sv" -o -name "*.v" \) 2>/dev/null)

# -------- VCS Flags --------
INC_FLAGS      := $(addprefix +incdir+,$(INC_DIRS))
VCS_BASE_FLAGS := -full64 -sverilog -lca -kdb -debug_access+all \
                  -timescale=$(TIMESCALE) \
                  -Mdir=$(BUILD)/csrc_$(TOP) -o $(SIMV) -l $(VCS_LOG)

# -------- Conditional: Waves --------
ifeq ($(WAVES),1)
  ifneq ($(VERDI_HOME),)
    VERDI_PLI    := -P $(VERDI_HOME)/share/PLI/VCS/linux64/novas.tab \
                       $(VERDI_HOME)/share/PLI/VCS/linux64/pli.a
    DEFINE_FLAGS += +define+DUMP_FSDB +define+FSDB_TOP=$(TOP)
    RUN_ARGS     += +fsdbfile=$(FSDB)
  else
    $(warning WAVES=1 but VERDI_HOME not set)
  endif
endif

# -------- Conditional: Coverage --------
ifeq ($(COVERAGE),1)
  COV_FLAGS := -cm line+cond+tgl+fsm -cm_dir $(COV_DIR)
  RUN_ARGS  += -cm_name $(TOP) -cm_dir $(COV_DIR)
endif

# -------- Filelist Generation --------
define GEN_FLIST
	@mkdir -p $(BUILD)
	@find $(RTL_DIRS) $(TB_DIRS) -type f \( -name "*.sv" -o -name "*.v" \) \
	  ! -name "*.svh" ! -name "*.vh" | sort > $(FLIST)
	@echo "Generated $(FLIST) ($$(wc -l < $(FLIST)) files)"
endef

# ============================================================
# Targets
# ============================================================
.PHONY: all build run verdi filelist clean realclean help
.PHONY: run-all run-all-waves list-tb new-tb
.PHONY: $(TESTBENCHES) $(addsuffix -v,$(TESTBENCHES))

all: run

# -------- Build --------
build: $(SIMV)

$(FLIST): $(SRC_FILES)
	$(GEN_FLIST)

$(SIMV): $(FLIST)
	@mkdir -p $(BUILD)
	@echo "Compiling (TOP=$(TOP), WAVES=$(WAVES))..."
	@vcs $(VCS_BASE_FLAGS) $(INC_FLAGS) $(DEFINE_FLAGS) $(VERDI_PLI) $(COV_FLAGS) \
	     -top $(TOP) -f $(FLIST)

# -------- Run --------
run: build
	@echo "Running $(TOP) (SEED=$(SEED))..."
	@$(SIMV) +ntb_random_seed=$(SEED) $(RUN_ARGS) -l $(RUN_LOG)

# -------- Verdi --------
verdi:
	@if [ -z "$$DISPLAY" ]; then \
	  echo "Error: DISPLAY not set."; \
	  exit 1; \
	fi
	@if [ ! -d "$(BUILD)/simv_$(TOP).daidir" ]; then \
	  echo "Error: No database for $(TOP). Run 'make $(TOP)' first."; \
	  exit 1; \
	fi
	@if [ ! -f "$(FSDB)" ]; then \
	  echo "Error: No FSDB: $(FSDB). Run 'make $(TOP)' first."; \
	  exit 1; \
	fi
	@echo "Opening Verdi for $(TOP)..."
	verdi -dbdir $(BUILD)/simv_$(TOP).daidir -ssf $(FSDB) -top $(TOP)

# -------- Filelist --------
filelist:
	$(GEN_FLIST)

# ============================================================
# Auto TB Targets
# ============================================================
$(TESTBENCHES):
	@$(MAKE) --no-print-directory run TOP=$@ WAVES=1

$(addsuffix -v,$(TESTBENCHES)):
	@$(MAKE) --no-print-directory verdi TOP=$(patsubst %-v,%,$@)

# -------- Run All --------
run-all:
	@echo "Running all (no waves)..."
	@passed=0; failed=0; \
	for tb in $(TESTBENCHES); do \
	  echo "======== $$tb ========"; \
	  if $(MAKE) --no-print-directory run TOP=$$tb WAVES=0; then \
	    echo "✓ PASSED"; passed=$$((passed + 1)); \
	  else \
	    echo "✗ FAILED"; failed=$$((failed + 1)); \
	  fi; \
	done; \
	echo "========================================"; \
	echo "Results: $$passed passed, $$failed failed"; \
	[ $$failed -eq 0 ]

run-all-waves:
	@echo "Running all (with waves)..."
	@for tb in $(TESTBENCHES); do \
	  echo "======== $$tb ========"; \
	  $(MAKE) --no-print-directory run TOP=$$tb WAVES=1; \
	done
	@echo "========================================"
	@echo "Done! View with: make <tb_name>-v"
	@echo "========================================"

# -------- List TBs --------
list-tb:
	@echo "Available testbenches:"
	@for tb in $(TESTBENCHES); do echo "  $$tb"; done

# -------- New TB --------
new-tb:
	@if [ -z "$(NAME)" ]; then \
	  echo "Usage: make new-tb NAME=<name>"; \
	  exit 1; \
	fi
	@if [ -f "$(TB_DIRS)/tb_$(NAME).sv" ]; then \
	  echo "Error: tb_$(NAME).sv exists"; \
	  exit 1; \
	fi
	@echo '`timescale 1ns/1ps' > $(TB_DIRS)/tb_$(NAME).sv
	@echo '' >> $(TB_DIRS)/tb_$(NAME).sv
	@echo 'module tb_$(NAME);' >> $(TB_DIRS)/tb_$(NAME).sv
	@echo '  `include "include/fsdb_dump.svh"' >> $(TB_DIRS)/tb_$(NAME).sv
	@echo '' >> $(TB_DIRS)/tb_$(NAME).sv
	@echo '  logic clk, rst_n;' >> $(TB_DIRS)/tb_$(NAME).sv
	@echo '  always #5 clk = ~clk;' >> $(TB_DIRS)/tb_$(NAME).sv
	@echo '' >> $(TB_DIRS)/tb_$(NAME).sv
	@echo '  initial begin' >> $(TB_DIRS)/tb_$(NAME).sv
	@echo '    clk = 0; rst_n = 0;' >> $(TB_DIRS)/tb_$(NAME).sv
	@echo '    #20 rst_n = 1;' >> $(TB_DIRS)/tb_$(NAME).sv
	@echo '    repeat(100) @(posedge clk);' >> $(TB_DIRS)/tb_$(NAME).sv
	@echo '    $$display("TEST PASSED");' >> $(TB_DIRS)/tb_$(NAME).sv
	@echo '    $$finish;' >> $(TB_DIRS)/tb_$(NAME).sv
	@echo '  end' >> $(TB_DIRS)/tb_$(NAME).sv
	@echo 'endmodule' >> $(TB_DIRS)/tb_$(NAME).sv
	@echo "Created: $(TB_DIRS)/tb_$(NAME).sv"

# -------- Clean --------
clean:
	rm -rf $(BUILD)/simv_* $(BUILD)/csrc_* $(BUILD)/*.log

realclean:
	rm -rf $(BUILD)

# -------- Help --------
help:
	@echo "============================================"
	@echo " Toy AI Accelerator Makefile"
	@echo "============================================"
	@echo ""
	@echo "Commands:"
	@echo "  make list-tb          List testbenches"
	@echo "  make <tb>             Run testbench"
	@echo "  make <tb>-v           View waveform"
	@echo "  make run-all          Run all (no waves)"
	@echo "  make run-all-waves    Run all (with waves)"
	@echo "  make new-tb NAME=x    Create testbench"
	@echo "  make clean            Clean build"
	@echo ""
	@echo "Available: $(TESTBENCHES)"
	@echo "============================================"

