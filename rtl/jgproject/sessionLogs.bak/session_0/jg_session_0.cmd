# ----------------------------------------
# Jasper Version Info
# tool      : Jasper 2025.06
# platform  : Linux 3.10.0-1160.119.1.el7.x86_64
# version   : 2025.06p002 64 bits
# build date: 2025.08.26 14:59:20 UTC
# ----------------------------------------
# started   : 2026-05-04 17:07:19 PKT
# hostname  : pc3.(none)
# pid       : 19958
# arguments : '-style' 'windows' '-label' 'session_0' '-console' '//127.0.0.1:39354' '-data' 'AAAAfHicY2RgYLCp////PwMYMD6A0Aw2jAyoAMRnQhUJbEChGRhYUZVLMaQxFDCUMcQzFDOkMpQwlAJ5ekA6mSEHrAYA9BgL7A==' '-bridge_url' '10.103.76.67:37001' '-proj' '/home/Abdullah.Rafique/Documents/Formal_Verification/25260002_25260006_Project/EE5214_AHB_Lite_25260002_25260006/rtl/jgproject/sessionLogs/session_0' '-init' '-hidden' '/home/Abdullah.Rafique/Documents/Formal_Verification/25260002_25260006_Project/EE5214_AHB_Lite_25260002_25260006/rtl/jgproject/.tmp/.initCmds.tcl' 'fpv_setup.tcl'
# ============================================================
# STEP 1 — Clear previous session
# ============================================================
clear -all

# Engine settings
set_engine_mode {H B}
set_max_trace_length 40

# ============================================================
# STEP 2 — Analyze
# ============================================================

analyze -sv12 ../packages/ahb3lite_pkg.sv

analyze -sv12 ../rtl/design.sv
analyze -sv12 ../rtl/mem.sv

analyze -sv12 ahb_checker.sv
analyze -sv12 ahb_assumptions.sv
analyze -sv12 ahb_cover.sv
analyze -sv12 bind_fpv.sv

# ============================================================
# STEP 3 — Elaborate
# ============================================================

elaborate -top ahb3liten \
    -parameter MEM_SIZE 32 \
    -parameter MEM_DEPTH 256 \
    -parameter HADDR_SIZE 16 \
    -parameter HDATA_SIZE 32

# ============================================================
# STEP 4 — Clock and Reset (IMPORTANT: before prove)
# ============================================================

clock HCLK
reset -expression {!HRESETn}

# ============================================================
# STEP 5 — Run Proof
# ============================================================

prove -all

# ============================================================
# STEP 6 — Coverage Reports (AFTER prove)
# ============================================================

report -summary
include fpv_setup.tcl
include fpv_setup.tcl
include fpv_setup.tcl
include fpv_setup.tcl
include fpv_setup.tcl
