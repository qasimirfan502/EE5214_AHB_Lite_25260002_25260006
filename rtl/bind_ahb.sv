module bind_ahb;


bind ahb3liten ahb_checker checker_1 (.HCLK, .HRESETn, .HSEL, .HREADY, .HREADYOUT, .HRESP, .HWRITE, .HTRANS, .HSIZE, .HBURST, .HPROT, .HADDR, .HWDATA, .HRDATA );

endmodule