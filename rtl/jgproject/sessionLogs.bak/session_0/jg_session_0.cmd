# ----------------------------------------
# Jasper Version Info
# tool      : Jasper 2025.06
# platform  : Linux 3.10.0-1160.119.1.el7.x86_64
# version   : 2025.06p002 64 bits
# build date: 2025.08.26 14:59:20 UTC
# ----------------------------------------
# started   : 2026-04-26 05:14:33 PKT
# hostname  : pc3.(none)
# pid       : 32571
# arguments : '-style' 'windows' '-label' 'session_0' '-console' '//127.0.0.1:43190' '-nowindow' '-exitonerror' '-data' 'AAAAmHicY2RgYLCp////PwMYMD6A0Aw2jAyoAMRnQhUJbEChGRhYEZLMQMzDoMuQxJDIUMKQzJAB5HMA+SB2DpAtxZDGUMBQxhDPUMyQChQtBfL04LIMDABZVA+h' '-bridge_url' '10.103.76.67:42057' '-proj' '/home/Abdullah.Rafique/Documents/Formal_Verification/25260002_25260006_Project/EE5214_AHB_Lite_25260002_25260006/rtl/jgproject/sessionLogs/session_0' '-init' '-hidden' '/home/Abdullah.Rafique/Documents/Formal_Verification/25260002_25260006_Project/EE5214_AHB_Lite_25260002_25260006/rtl/jgproject/.tmp/.initCmds.tcl' 'fpv_setup.tcl' '-hidden' '/home/Abdullah.Rafique/Documents/Formal_Verification/25260002_25260006_Project/EE5214_AHB_Lite_25260002_25260006/rtl/jgproject/.tmp/.postCmds.tcl'
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
