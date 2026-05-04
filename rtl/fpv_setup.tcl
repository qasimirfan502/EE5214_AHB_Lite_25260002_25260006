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