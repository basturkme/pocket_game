
CWD=$(shell pwd)

SIM ?= icarus
TOPLEVEL_LANG ?=verilog

VERILOG_SOURCES =$(CWD)/../HDL/*.v

TOPLEVEL = player_fsm
MODULE := test_reset_and_initial_state
COCOTB_HDL_TIMEUNIT=20ms
COCOTB_HDL_TIMEPRECISION=20ms

# Include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim
