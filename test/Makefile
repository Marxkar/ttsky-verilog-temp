# ==========================================================
# Cocotb Makefile for JTAG TAP project
# ==========================================================

# Simulator (default = Icarus Verilog)
SIM ?= icarus
TOPLEVEL_LANG ?= verilog

# Source directory (your RTL sources live here)
SRC_DIR = $(PWD)/../src
PROJECT_SOURCES = tt_um_marxkar_jtag.v d_flip_flop.v

# Build directories
ifneq ($(GATES),yes)

# -------------------------
# RTL simulation
# -------------------------
SIM_BUILD        = sim_build/rtl
VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,$(PROJECT_SOURCES))

else

# -------------------------
# Gate-level simulation
# -------------------------
SIM_BUILD        = sim_build/gl
COMPILE_ARGS    += -DGL_TEST
COMPILE_ARGS    += -DFUNCTIONAL
COMPILE_ARGS    += -DUSE_POWER_PINS
COMPILE_ARGS    += -DSIM
COMPILE_ARGS    += -DUNIT_DELAY=\#1

VERILOG_SOURCES += $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog/primitives.v
VERILOG_SOURCES += $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog/sky130_fd_sc_hd.v

# Gate-level netlist (produced by synthesis)
VERILOG_SOURCES += $(PWD)/gate_level_netlist.v

endif

# Allow sharing configuration between design and testbench
COMPILE_ARGS += -I$(SRC_DIR)

# ==========================================================
# Cocotb test configuration
# ==========================================================

# DUT top module (NOT the Verilog testbench anymore)
TOPLEVEL = tt_um_marxkar_jtag

# Python testbench file basename (test_jtag_tap.py → test_jtag_tap)
MODULE   = test_jtag_tap

# ==========================================================
# Include Cocotb make rules
# ==========================================================
include $(shell cocotb-config --makefiles)/Makefile.sim
