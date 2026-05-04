module bind_fpv;

    // -------------------------------------------------------------------------
    // 1. Assertion checker — assert and cover properties
    // -------------------------------------------------------------------------
    bind ahb3liten ahb_checker checker_i (
        .HCLK      ( HCLK      ),
        .HRESETn   ( HRESETn   ),
        .HSEL      ( HSEL      ),
        .HREADY    ( HREADY    ),
        .HREADYOUT ( HREADYOUT ),
        .HRESP     ( HRESP     ),
        .HWRITE    ( HWRITE    ),
        .HTRANS    ( HTRANS    ),
        .HSIZE     ( HSIZE     ),
        .HBURST    ( HBURST    ),
        .HPROT     ( HPROT     ),
        .HADDR     ( HADDR     ),
        .HWDATA    ( HWDATA    ),
        .HRDATA    ( HRDATA    )
    );

    // -------------------------------------------------------------------------
    // 2. Assumptions — constrain master to legal AHB-Lite behavior
    // Without this, JasperGold treats all inputs as free variables and
    // will generate counterexamples from illegal master behavior.
    // -------------------------------------------------------------------------
    bind ahb3liten ahb_assumptions assumptions_i (
        .HCLK      ( HCLK      ),
        .HRESETn   ( HRESETn   ),
        .HSEL      ( HSEL      ),
        .HREADY    ( HREADYOUT    ),
        .HWRITE    ( HWRITE    ),
        .HTRANS    ( HTRANS    ),
        .HSIZE     ( HSIZE     ),
        .HBURST    ( HBURST    ),
        .HPROT     ( HPROT     ),
        .HADDR     ( HADDR     ),
        .HWDATA    ( HWDATA    )
    );

    // -------------------------------------------------------------------------
    // 3. Cover properties — corner case reachability checks
    // -------------------------------------------------------------------------
    bind ahb3liten ahb_covers covers_i (
        .HCLK      ( HCLK      ),
        .HRESETn   ( HRESETn   ),
        .HSEL      ( HSEL      ),
        .HREADY    ( HREADY    ),
        .HREADYOUT ( HREADYOUT ),
        .HRESP     ( HRESP     ),
        .HWRITE    ( HWRITE    ),
        .HTRANS    ( HTRANS    ),
        .HSIZE     ( HSIZE     ),
        .HBURST    ( HBURST    ),
        .HPROT     ( HPROT     ),
        .HADDR     ( HADDR     ),
        .HWDATA    ( HWDATA    ),
        .HRDATA    ( HRDATA    )
    );

endmodule