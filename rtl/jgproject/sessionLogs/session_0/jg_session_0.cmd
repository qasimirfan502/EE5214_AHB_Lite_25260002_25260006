# ----------------------------------------
# Jasper Version Info
# tool      : Jasper 2025.06
# platform  : Linux 3.10.0-1160.119.1.el7.x86_64
# version   : 2025.06p002 64 bits
# build date: 2025.08.26 14:59:20 UTC
# ----------------------------------------
# started   : 2026-05-02 16:25:16 PKT
# hostname  : pc3.(none)
# pid       : 6578
# arguments : '-style' 'windows' '-label' 'session_0' '-console' '//127.0.0.1:33879' '-data' 'AAAAfHicY2RgYLCp////PwMYMD6A0Aw2jAyoAMRnQhUJbEChGRhYUZVLMaQxFDCUMcQzFDOkMpQwlAJ5ekA6mSEHrAYA9BgL7A==' '-bridge_url' '10.103.76.67:40677' '-proj' '/home/Abdullah.Rafique/Documents/Formal_Verification/25260002_25260006_Project/EE5214_AHB_Lite_25260002_25260006/rtl/jgproject/sessionLogs/session_0' '-init' '-hidden' '/home/Abdullah.Rafique/Documents/Formal_Verification/25260002_25260006_Project/EE5214_AHB_Lite_25260002_25260006/rtl/jgproject/.tmp/.initCmds.tcl' 'fpv_setup.tcl'
# ============================================================
# fpv_setup.tcl
# JasperGold FPV Setup Script
# EE-5214 — AHB-Lite Verification — Spring 2025
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

visualize -new_window; visualize -violation -property <embedded>::ahb3liten.checker_i.ASRT_SYMB_COHERENCE -bg
include fpv_setup.tcl
include fpv_setup.tcl
include fpv_setup.tcl
include fpv_setup.tcl
visualize -violation -property <embedded>::ahb3liten.checker_i.DATA_VALIDITY -new_window
include fpv_setup.tcl
include fpv_setup.tcl
visualize -violation -property <embedded>::ahb3liten.checker_i.DATA_VALIDITY -new_window
include fpv_setup.tcl
visualize -violation -property <embedded>::ahb3liten.checker_i.DATA_VALIDITY -new_window
include fpv_setup.tcl
visualize -violation -property <embedded>::ahb3liten.checker_i.DATA_VALIDITY -new_window
include fpv_setup.tcl
include fpv_setup.tcl
visualize -violation -property <embedded>::ahb3liten.checker_i.DATA_VALIDITY -new_window
include fpv_setup.tcl
visualize -violation -property <embedded>::ahb3liten.checker_i.DATA_VALIDITY -new_window
include fpv_setup.tcl
visualize -violation -property <embedded>::ahb3liten.checker_i.DATA_VALIDITY -new_window
include fpv_setup.tcl
visualize -violation -property <embedded>::ahb3liten.checker_i.DATA_VALIDITY -new_window
include fpv_setup.tcl
visualize -violation -property <embedded>::ahb3liten.checker_i.DATA_VALIDITY -new_window
include fpv_setup.tcl
visualize -violation -property <embedded>::ahb3liten.checker_i.DATA_VALIDITY -new_window
include fpv_setup.tcl
visualize -violation -property <embedded>::ahb3liten.checker_i.DATA_VALIDITY -new_window
visualize -violation -property <embedded>::ahb3liten.checker_i.DATA_VALIDITY -new_window
include fpv_setup.tcl
include fpv_setup.tcl
visualize -violation -property <embedded>::ahb3liten.checker_i.DATA_VALIDITY -new_window
include fpv_setup.tcl
visualize -violation -property <embedded>::ahb3liten.checker_i.DATA_VALIDITY -new_window
include fpv_setup.tcl
visualize -violation -property <embedded>::ahb3liten.checker_i.DATA_VALIDITY -new_window
include fpv_setup.tcl
prove -all -bg
include fpv_setup.tcl
include fpv_setup.tcl
visualize -violation -property <embedded>::ahb3liten.checker_i.DATA_VALIDITY -new_window
visualize -property <embedded>::ahb3liten.checker_i.FA1_TRIGGER_COVER -new_window
visualize -violation -property <embedded>::ahb3liten.checker_i.DATA_VALIDITY -new_window
include fpv_setup.tcl
visualize -violation -property <embedded>::ahb3liten.checker_i.DATA_VALIDITY -new_window
include fpv_setup.tcl
visualize -violation -property <embedded>::ahb3liten.checker_i.DATA_VALIDITY -new_window
include fpv_setup.tcl
visualize -violation -property <embedded>::ahb3liten.checker_i.DATA_VALIDITY -new_window
include fpv_setup.tcl
visualize -violation -property <embedded>::ahb3liten.checker_i.DATA_VALIDITY -new_window
include fpv_setup.tcl
visualize -violation -property <embedded>::ahb3liten.checker_i.DATA_VALIDITY -new_window
include fpv_setup.tcl
visualize -violation -property <embedded>::ahb3liten.checker_i.DATA_VALIDITY -new_window
include fpv_setup.tcl
visualize -violation -property <embedded>::ahb3liten.checker_i.FA2_NO_SPURIOUS_WRITE -new_window
include fpv_setup.tcl
visualize -violation -property <embedded>::ahb3liten.checker_i.FA2_NO_SPURIOUS_WRITE -new_window
