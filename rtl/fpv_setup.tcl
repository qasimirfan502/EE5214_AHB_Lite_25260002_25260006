# ============================================================
# fpv_setup.tcl
# JasperGold FPV Setup Script
# EE-5214 — AHB-Lite Verification — Spring 2025
# ============================================================

# ------------------------------------------------------------
# STEP 1 — Clear previous session
# ------------------------------------------------------------
clear -all

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

# ------------------------------------------------------------
# STEP 5 — Run proof
# ------------------------------------------------------------
prove -task FPV

# ------------------------------------------------------------
# STEP 7 — Report results
# ------------------------------------------------------------
report -type summary  -file results_summary.txt  -force
report -type detail   -file results_detail.txt   -force
report -type cover    -file results_cover.txt    -force

puts "============================================"
puts "FPV run complete"
puts "Check results_summary.txt for results"
puts "============================================"