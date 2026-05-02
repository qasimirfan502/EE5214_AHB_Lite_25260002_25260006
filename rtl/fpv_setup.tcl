# ============================================================
# fpv_setup.tcl
# JasperGold FPV Setup Script
# EE-5214 — AHB-Lite Verification Project - 25260002-25260006
# ============================================================

# ------------------------------------------------------------
# STEP 1 — Clear previous session
# ------------------------------------------------------------
clear -all


# JG settings for lab
set_engine_mode {H B}
set_max_trace_length 100
# ------------------------------------------------------------
# STEP 2 — Analyze (compile) all files
# Order matters:
#   1. Package first — defines constants used by everything
#   2. DUT files
#   3. Checker and assumptions
#   4. Bind file last — references all other modules
# ------------------------------------------------------------

# Package
analyze -sv12 ../packages/ahb3lite_pkg.sv

# DUT
analyze -sv12 ../rtl/design.sv
analyze -sv12 ../rtl/mem.sv

# Checker and assumptions
analyze -sv12 ahb_checker.sv
analyze -sv12 ahb_assumptions.sv

# Bind file — must be last
analyze -sv12 bind_fpv.sv

# ------------------------------------------------------------
# STEP 3 — Elaborate
# Top module is the DUT
# Parameters match design.sv defaults
# ------------------------------------------------------------
elaborate -top ahb3liten \
    -parameter MEM_SIZE 32 \
    -parameter MEM_DEPTH 256 \
    -parameter HADDR_SIZE 16 \
    -parameter HDATA_SIZE 32

# ------------------------------------------------------------
# STEP 4 — Clock and reset
# HCLK  : rising edge triggered
# HRESETn : active low reset
# ------------------------------------------------------------
clock HCLK
reset -expression {!HRESETn} 
# Connected HREADY to HREADYOUT since single slave system
assume -name HREADY_TIES {HREADY == HREADYOUT}

# Setting this because some assumptions require more cycles such as INCR16 and WRAP16
set_max_trace_length 40

# ------------------------------------------------------------
# STEP 6 — Run proof
# ------------------------------------------------------------
prove -all

