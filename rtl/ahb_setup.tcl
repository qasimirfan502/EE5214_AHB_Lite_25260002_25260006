# Clear previous session data
clear -all

# Analyze the design and verification files
analyze -sv ahb3lite_pkg.sv design.sv mem.sv ahb_checker.sv bind_ahb.sv

# Elaborate the design
# 'ahb3liten' is the top-level module found in design.txt
# JasperGold will automatically pick up the bind statement in bind_ahb.sv
elaborate -top ahb3liten

# Setup Clock and Reset
# According to the spec (Section 2.1) and DUT (Section 135):
# HCLK is the bus clock
# HRESETn is active-LOW (Section 7.1.2)
clock HCLK
reset ~HRESETn


# Prove the properties
# This will attempt to prove all assertions in ahb_checker.sv
prove -all