// This is the code initially written for Part 3 but it will be used in Part 2 as well
// Here I will write properties which the slave has to follow, these properties are taken from the spec sheet.
// For the Part 3, the assumptions written in the ahb_assumptions file are like master side stimulus and this code will assert the properties
// mentioned here to verify the slave design which is the project

module ahb_checker
import ahb3lite_pkg::*;
(
    input logic        HCLK,
    input logic        HRESETn,
    input logic        HSEL,
    input logic        HREADY,
    input logic        HREADYOUT,
    input logic        HRESP,
    input logic        HWRITE,
    input logic [1:0]  HTRANS,
    input logic [2:0]  HSIZE,
    input logic [2:0]  HBURST,
    input logic [3:0]  HPROT,
    input logic [15:0] HADDR,
    input logic [31:0] HWDATA,
    input logic [31:0] HRDATA
);

    // Default clock and reset
    default clocking cb
        @(posedge HCLK);
    endclocking

    default disable iff (!HRESETn);

// =========================================
    // Optimized Ghost Logic
    // =========================================

    // Basic Phase Signals
    logic ghost_ahb_write;
    assign ghost_ahb_write = HSEL && HWRITE && (HTRANS == HTRANS_NONSEQ || HTRANS == HTRANS_SEQ);
    
    logic ghost_ahb_read;
    assign ghost_ahb_read  = HSEL && !HWRITE && (HTRANS == HTRANS_NONSEQ || HTRANS == HTRANS_SEQ);

    // 1. Write Tracking (Capture Address then Data)
    logic        write_addr_captured;
    logic [15:0] write_addr_latched;
    logic [15:0] last_write_addr;
    logic [31:0] last_write_data;
    logic        last_write_valid;
    logic [2:0]   write_size_latched;

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            write_addr_captured <= 1'b0;
            last_write_valid    <= 1'b0;
            write_size_latched  <= 3'b0;
        end else begin
            // Address Phase Capture
            if (HREADY && ghost_ahb_write) begin
                write_addr_captured <= 1'b1;
                write_addr_latched  <= HADDR;
                write_size_latched  <= HSIZE;
            end else if (HREADY) begin
                write_addr_captured <= 1'b0;
            end

            // Data Phase Commit
            if (write_addr_captured && HREADY && ghost_ahb_write) begin
                last_write_addr  <= write_addr_latched;
                last_write_data  <= HWDATA;
                last_write_valid <= 1'b1;
                end else if (write_addr_captured && !ghost_ahb_write) begin
                last_write_valid <= 1'b0;  // abandoned write
                end
            end
    end

    // 2. Read Tracking & Stability Logic
    logic        read_addr_captured;
    logic [15:0] read_addr_latched;
    logic [15:0] last_read_addr;
    logic [31:0] last_read_data;
    logic        last_read_valid;
    logic        write_to_last_read_addr;

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            read_addr_captured      <= 1'b0;
            last_read_valid         <= 1'b0;
            write_to_last_read_addr <= 1'b0;
        end else begin
            // Address Phase Capture for Read
            if (HREADYOUT && ghost_ahb_read) begin
                read_addr_captured <= 1'b1;
                read_addr_latched  <= HADDR;
            end else if (HREADYOUT && !ghost_ahb_read && HTRANS != HTRANS_BUSY && HTRANS != HTRANS_IDLE) begin
            // Only clear when bus completes something that is NOT a read
            // If !HREADYOUT — hold as-is to survive wait states
            read_addr_captured <= 1'b0;
            end

            // Data Phase Commit for Read
            if (read_addr_captured && HREADYOUT && ghost_ahb_read) begin
                last_read_addr          <= read_addr_latched;
                last_read_data          <= HRDATA;
                last_read_valid         <= 1'b1;
                write_to_last_read_addr <= 1'b0; // Reset tracking for the new address
            end 
            // Check if any write hits our tracked address
            else if (last_read_valid && write_addr_captured && HREADYOUT && (write_addr_latched == last_read_addr)) begin
                write_to_last_read_addr <= 1'b1;
            end
        end
    end

    

    // ---------------------------------------------PROTOCOL ASSERTIONS----------------------------------------------

    
    property IDLE_ZERO_WAIT_PROP;
        (HSEL && HTRANS == HTRANS_IDLE) |=> HREADYOUT;
    endproperty

    IDLE_ZERO_WAIT: assert property (IDLE_ZERO_WAIT_PROP)
        else $error("FAIL: Slave did not provide zero wait state on IDLE");

    property HRESP_ALWAYS_OKAY_PROP;
        HRESP == HRESP_OKAY;
    endproperty

    HRESP_ALWAYS_OKAY: assert property (HRESP_ALWAYS_OKAY_PROP)
        else $error("FAIL: HRESP is not OKAY — DUT should hardwire this");


    property HREADYOUT_DURING_RESET_PROP;
        !HRESETn |-> HREADYOUT;
    endproperty

    HREADYOUT_DURING_RESET: assert property (
        @(posedge HCLK) HREADYOUT_DURING_RESET_PROP)
        else $error("FAIL: HREADYOUT not HIGH during reset");


    property HRESP_ERROR_TWO_CYCLE_PROP;
        (HRESP == HRESP_ERROR && !HREADYOUT) |=>
        (HRESP == HRESP_ERROR && HREADYOUT);
    endproperty

    HRESP_ERROR_TWO_CYCLE: assert property (HRESP_ERROR_TWO_CYCLE_PROP)
        else $error("FAIL: HRESP ERROR did not last exactly 2 cycles");


    property HRESP_OKAY_DURING_WAIT_PROP;
        (!HREADYOUT && HSEL &&
            (HTRANS == HTRANS_NONSEQ ||
            HTRANS == HTRANS_SEQ)) |->
        (HRESP == HRESP_OKAY);
    endproperty

    HRESP_OKAY_DURING_WAIT: assert property (HRESP_OKAY_DURING_WAIT_PROP)
        else $error("FAIL: HRESP not OKAY during wait state");


    property HRESP_STABLE_ERROR_PROP;
        (HRESP == HRESP_ERROR && !HREADYOUT) |=>
        (HRESP == HRESP_ERROR);
    endproperty

    HRESP_STABLE_ERROR: assert property (HRESP_STABLE_ERROR_PROP)
        else $error("FAIL: HRESP did not remain stable during ERROR");


    property NONSEQ_READ_WAIT_STATE_PROP;
        (HSEL && HTRANS == HTRANS_NONSEQ &&
        !HWRITE && HREADYOUT) |=>
        (!HREADYOUT);
    endproperty

    NONSEQ_READ_WAIT_STATE: assert property (NONSEQ_READ_WAIT_STATE_PROP)
        else $error("FAIL: DUT did not insert wait state on NONSEQ read");


    property WRITE_NO_WAIT_STATE_PROP;
        (HSEL && HTRANS == HTRANS_NONSEQ && HWRITE) |=>
        HREADYOUT;
    endproperty

    WRITE_NO_WAIT_STATE: assert property (WRITE_NO_WAIT_STATE_PROP)
        else $error("FAIL: DUT inserted wait state on write transfer");


    property SEQ_READ_NO_WAIT_STATE_PROP;
    (HSEL && HTRANS == HTRANS_SEQ && !HWRITE && HREADYOUT) |=>
    HREADYOUT;
    endproperty

    SEQ_READ_NO_WAIT_STATE: assert property (SEQ_READ_NO_WAIT_STATE_PROP)
        else $error("FAIL: DUT inserted unexpected wait state on SEQ read");

    property HRDATA_VALID_ON_COMPLETE_PROP;
        (HREADYOUT && HSEL && !HWRITE &&
        (HTRANS == HTRANS_NONSEQ || HTRANS == HTRANS_SEQ)) |=>
        !$isunknown(HRDATA);
    endproperty

    HRDATA_VALID_ON_COMPLETE: assert property (HRDATA_VALID_ON_COMPLETE_PROP)
        else $error("FAIL: HRDATA unknown when transfer completed");
   
    // ---------------------------------------------FUNCTIONAL ASSERTIONS----------------------------------------------
   
    DATA_VALIDITY_COVER: cover property (
        last_write_valid ##1
        (HSEL && !HWRITE &&
        HTRANS == HTRANS_NONSEQ &&
        HADDR == last_write_addr)
    );

    property DATA_VALIDITY_PROP;
        // Declare a local variable to lock in the data we want to check
        logic [31:0] expected_data;
       
        // ANTECEDENT (Address Phase)
        (last_write_valid &&
         HSEL && !HWRITE &&
         HTRANS == HTRANS_NONSEQ &&
         HADDR == last_write_addr &&
         HREADYOUT,
         expected_data = last_write_data) // <--- Lock in the data here!
        |=> // Move to Data Phase
        // CONSEQUENT (Data Phase)
        // Wait for HREADYOUT to go high (whether that takes 0, 1, or 50 cycles)
        HREADYOUT[->1] ##0 (HRDATA == expected_data);
    endproperty

    DATA_VALIDITY: assert property (DATA_VALIDITY_PROP)
         else $error("FAIL: Read data was not valid");

    property MEM_STABILITY_PROP;
        // Declare a local variable to lock in the expected stable data
        logic [31:0] expected_data;
       
        // ANTECEDENT (Address Phase)
        (last_read_valid && !write_to_last_read_addr &&
         HSEL && !HWRITE &&
         HTRANS == HTRANS_NONSEQ &&
         HADDR == last_read_addr &&
         HREADYOUT,
         expected_data = last_read_data) // <--- Lock in the data here!
        |=> // Move to Data Phase
        // CONSEQUENT (Data Phase)
        HREADYOUT[->1] ##0 (HRDATA == expected_data);
    endproperty

    MEM_STABILITY: assert property (MEM_STABILITY_PROP)
        else $error("FAIL: Memory content changed at 0x%04h without a write to that address", last_read_addr);

    STABILITY_CHECK_COVER: cover property (
        last_read_valid ##[5:10] (HSEL && !HWRITE && HADDR == last_read_addr && HREADYOUT)
    );


    property BYTE_WRITE_ISOLATION_PROP;
        logic [15:0] target_addr;
        logic [31:0] prev_mem_data;
        
        // ANTECEDENT: A Byte write is starting to a known address
        (last_read_valid && 
         HSEL && HWRITE && HREADYOUT &&
         HTRANS == HTRANS_NONSEQ && 
         HSIZE == 3'b000 &&              // 3'b000 = Byte access
         HADDR == last_read_addr,        // We already know the old data
         target_addr = HADDR,
         prev_mem_data = last_read_data) // Store the "old" 32-bit word
        |=>
        // CONSEQUENT: After the write completes, read the word back 
        // and verify bytes 1, 2, and 3 are unchanged.
        HREADYOUT[->1] ##1               // Wait for write to finish
        (HSEL && !HWRITE && HADDR == target_addr && HREADYOUT) // Trigger a Read
        |=>
        HREADYOUT[->1] ##0 
        (HRDATA[31:8] == prev_mem_data[31:8]); // Check top 3 bytes match old data
    endproperty

    BYTE_WRITE_ISOLATION: assert property (BYTE_WRITE_ISOLATION_PROP)
        else $error("FAIL: Byte write to 0x%0h corrupted neighboring bytes!", last_read_addr);

endmodule