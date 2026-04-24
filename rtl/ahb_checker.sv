module ahb_checker (
    input logic HCLK, HRESETn, HSEL, HREADY, HREADYOUT, HRESP, HWRITE,
    input logic [1:0] HTRANS,
    input logic [2:0] HSIZE, HBURST,
    input logic [3:0] HPROT,
    input logic [15:0] HADDR,
    input logic [31:0] HWDATA, HRDATA
);
	// Standard AHB-Lite Sampling
    	default clocking cb @(posedge HCLK); endclocking
    	// HRESETn is the primary reset; assertions are disabled when active
    	default disable iff (!HRESETn);


    // Properties
    property HADDR_HSIZE_Alignment;
        (HTRANS == 2'b10 || HTRANS == 2'b11) && HSEL -> 
        ( 
            (HSIZE == 3'b001) ? (HADDR == 1'b0) :
            (HSIZE == 3'b010) ? (HADDR[1:0] == 2'b0) :
            1'b1
        );
    endproperty 

    property HREADY_SAMPLE_TIMING;
        (HREADY) |-> ##3 $rose(HCLK);
    endproperty

    // Assertions
    HADDR_alignment_assert: assert property (HADDR_HSIZE_Alignment)
        else $error("AHB-Lite Protocol violation: HADDR is not aligned to HSIZE");
    HREADY_SAMPLE_TIMING_ASSERT: assert property (HREADY_SAMPLE_TIMING);

    // Covers
    HADDR_alignment_cover: cover property (HADDR_HSIZE_Alignment);
    HREADY_SAMPLE_TIMING_COVER: cover property (HREADY_SAMPLE_TIMING);
endmodule