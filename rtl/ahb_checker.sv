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
    // Ghost code
    // =========================================

    // Track last completed HTRANS
    logic [1:0] htrans_prev;
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn)
            htrans_prev <= HTRANS_IDLE;
        else if (HREADY)
            htrans_prev <= HTRANS;
    end

    // =========================================
    // Write tracking — two stage pipeline
    // Stage 1: capture address phase (HADDR valid)
    // Stage 2: capture data phase (HWDATA valid
    //          one cycle after address phase)
    // =========================================

    // Stage 1 — address phase
    logic [15:0] pending_write_addr;
    logic        pending_write;

always_ff @(posedge HCLK or negedge HRESETn) begin
    if (!HRESETn) begin
        pending_write_addr <= '0;
        pending_write      <= 1'b0;
    end else if (HREADYOUT && HSEL && HWRITE &&
                (HTRANS == HTRANS_NONSEQ ||
                 HTRANS == HTRANS_SEQ)) begin
        // Capture address when slave is ready and write is happening
        // Using HREADYOUT instead of HREADY to ensure slave accepted it
        pending_write_addr <= HADDR;
        pending_write      <= 1'b1;
    end else begin
        pending_write      <= 1'b0;
    end
end

    // Stage 2 — data phase
    logic [15:0] last_write_addr;
    logic [31:0] last_write_data;
    logic        last_write_valid;

always_ff @(posedge HCLK or negedge HRESETn) begin
    if (!HRESETn) begin
        last_write_addr  <= '0;
        last_write_data  <= '0;
        last_write_valid <= 1'b0;
    end else if (pending_write && HSEL && HWRITE) begin
        // Only capture data phase if HWRITE is still high
        // This prevents capturing HWDATA during a subsequent read
        last_write_addr  <= pending_write_addr;
        last_write_data  <= HWDATA;
        last_write_valid <= 1'b1;
    end else if (HREADYOUT && HSEL && HWRITE &&
                (HTRANS == HTRANS_NONSEQ ||
                 HTRANS == HTRANS_SEQ)) begin
        last_write_valid <= 1'b0;
    end
end

    // =========================================
    // Byte write tracking — two stage pipeline
    // Stage 1: capture address phase of byte write
    // Stage 2: capture correct byte lane from HWDATA
    //          one cycle later when data phase is valid
    // =========================================

    // We need to track HSIZE through the pipeline
    // because HSIZE is only valid in address phase
    logic [2:0] hsize_prev;
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn)
            hsize_prev <= '0;
        else if (HREADY)
            hsize_prev <= HSIZE;
    end

    // Stage 1 — address phase of byte write
    logic [15:0] byte_write_addr_saved;
    logic        byte_write_addr_captured;

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            byte_write_addr_saved    <= '0;
            byte_write_addr_captured <= 1'b0;
        end else if (HREADYOUT && HSEL && HWRITE &&
                     HTRANS == HTRANS_NONSEQ &&
                     HSIZE == HSIZE_BYTE &&
                     !$isunknown(HWDATA)) begin
            byte_write_addr_saved    <= HADDR;
            byte_write_addr_captured <= 1'b1;
        end else begin
            byte_write_addr_captured <= 1'b0;
        end
    end

    // Stage 2 — data phase of byte write
    // HWDATA is valid one cycle after address phase
    // Select correct byte lane based on saved address offset
    logic [7:0]  byte_write_data;
    logic        byte_write_pending;

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            byte_write_data    <= '0;
            byte_write_pending <= 1'b0;
        end else if (byte_write_addr_captured && HSEL && HWRITE) begin
            // Select correct byte lane from HWDATA
            case (byte_write_addr_saved[1:0])
                2'b00: byte_write_data <= HWDATA[7:0];
                2'b01: byte_write_data <= HWDATA[15:8];
                2'b10: byte_write_data <= HWDATA[23:16];
                2'b11: byte_write_data <= HWDATA[31:24];
            endcase
            byte_write_pending <= 1'b1;
        end else begin
            byte_write_pending <= 1'b0;
        end
    end

    // =========================================
    // Spurious write tracking
    // =========================================
    logic        valid_write_occurred;
    logic [15:0] last_valid_write_addr;

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            valid_write_occurred  <= 1'b0;
            last_valid_write_addr <= '0;
        end else if (HREADY && HSEL && HWRITE &&
                    (HTRANS == HTRANS_NONSEQ ||
                     HTRANS == HTRANS_SEQ)) begin
            valid_write_occurred  <= 1'b1;
            last_valid_write_addr <= HADDR;
        end else if (HREADY && HSEL && !HWRITE &&
                    (HTRANS == HTRANS_NONSEQ ||
                     HTRANS == HTRANS_SEQ)) begin
            valid_write_occurred  <= 1'b0;
        end
    end

    //---------------------------------
    // Properties and Assertions
    //---------------------------------

    // The protocol assertions mentioned in the document are Master side obligations, hence they are covered in the assumptions file

    // ---------------------------------------------PROTOCOL PROPERTIES, ASSERTIONS AND COVERS----------------------------------------------

    // First Property | Slaves must always provide a zero wait state OKAY response to IDLE transfers
    property IDLE_TRANSFER_WAIT_STATE_PROP;
        (HTRANS == HTRANS_IDLE && HSEL) |=> HREADYOUT;
    endproperty

    IDLE_TRANSFER_WAIT_STATE: assert property (IDLE_TRANSFER_WAIT_STATE_PROP)
        else $error("FAIL: Slave did not respond with HREADY=1 on IDLE transfer");

    // Second Property | Slaves must always provide a zero wait state OKAY response to BUSY transfers
    property BUSY_TRANSFER_WAIT_STATE_PROP;
        (HTRANS == HTRANS_BUSY && HSEL) |=> HREADYOUT;
    endproperty

    BUSY_TRANSFER_WAIT_STATE: assert property (BUSY_TRANSFER_WAIT_STATE_PROP)
        else $error("FAIL: Slave did not respond with HREADY=1 on BUSY transfer");

    // Third Property | Slave must never generate HRESP=ERROR | SPECIFIC TO THIS DUT ONLY
    property ALWAYS_OK_PROP;
        HRESP == HRESP_OKAY     // Since this is to be true for all cases, we do not need any implications
    endproperty

    ALWAYS_OK: assert property (ALWAYS_OK_PROP)
        else $error("FAIL: Slave did not respond with HRESP_OKAY");

    // Fourth Property | During reset all slaves must ensure HREADYOUT is HIGH
    property DEASSERTION_RESET_PROP;
        !HRESETn |=> HREADYOUT;
    endproperty

    DEASSERTION_RESET: assert property (@(posedge HCLK) DEASSERTION_RESET_PROP) // ADDED THE HCLK to override the disable iff condition since I need to check this
        else $error("FAIL: Slave did not assert HREADYOUT as HIGH on reset");

    // Fifth Property | HRESP=ERROR lasts exactly 2 cycles; HREADY=0 on cycle 1, HREADY=1 on cycle 2
    property TWO_CYCLE_HRESP_ERROR_PROP;
        (HRESP == HRESP_ERROR && HREADYOUT == 0) |=> (HRESP == HRESP_ERROR && HREADYOUT == 1);
    endproperty

    TWO_CYCLE_HRESP_ERROR: assert property (TWO_CYCLE_HRESP_ERROR_PROP)
        else $error("FAIL: Slave did not maintain the error for 2 cycles");

    //Sixth Property - Part A | All transfers in a burst must be aligned to the address boundary equal to the size of the transfer
    /*property BURST_SIZE_ALIGNMENT_BYTE_PROP;
        ((HTRANS == HTRANS_NONSEQ || HTRANS == HTRANS_SEQ) && HSEL && HSIZE == HSIZE_BYTE) |-> 1'b1;
    endproperty

    BURST_SIZE_ALIGNMENT_BYTE: assert property (BURST_SIZE_ALIGNMENT_BYTE_PROP)
        else $error("FAIL: Slave did not maintain the size alignment with the address boundary");

    //Sixth Property - Part B | All transfers in a burst must be aligned to the address boundary equal to the size of the transfer
    property BURST_SIZE_ALIGNMENT_HWORD_PROP;
        ((HTRANS == HTRANS_NONSEQ || HTRANS == HTRANS_SEQ) && HSEL && HSIZE == HSIZE_HWORD) |-> (HADDR[0] == 0);
    endproperty

    BURST_SIZE_ALIGNMENT_HWORD: assert property (BURST_SIZE_ALIGNMENT_HWORD_PROP)
        else $error("FAIL: HADDR not halfword aligned, HADDR=0x%0h", HADDR);

    //Sixth Property - Part C | All transfers in a burst must be aligned to the address boundary equal to the size of the transfer
    property BURST_SIZE_ALIGNMENT_WORD_PROP;
        ((HTRANS == HTRANS_NONSEQ || HTRANS == HTRANS_SEQ) && HSEL && HSIZE == HSIZE_WORD) |-> (HADDR[1:0] == 2'b00);
    endproperty

    BURST_SIZE_ALIGNMENT_WORD: assert property (BURST_SIZE_ALIGNMENT_WORD_PROP)
        else $error("FAIL: HADDR not word aligned, HADDR=0x%0h", HADDR);*/
    
    property HRESP_OKAY_DURING_WAIT_PROP;
        (!HREADYOUT && HSEL && (HTRANS == HTRANS_NONSEQ || HTRANS == HTRANS_SEQ)) |-> (HRESP == HRESP_OKAY);
    endproperty

    HRESP_OKAY_DURING_WAIT: assert property (HRESP_OKAY_DURING_WAIT_PROP)
        else $error("FAIL: HRESP not OKAY during wait state");

    property NONSEQ_READ_WAIT_STATE_PROP;
        (HSEL && HTRANS == HTRANS_NONSEQ && !HWRITE && HREADYOUT) |=> (!HREADYOUT);
    endproperty

    NONSEQ_READ_WAIT_STATE: assert property (NONSEQ_READ_WAIT_STATE_PROP)
        else $error("FAIL: DUT did not insert wait state on NONSEQ read");

    property WRITE_NO_WAIT_STATE_PROP;
        (HSEL && HTRANS == HTRANS_NONSEQ && HWRITE) |=> HREADYOUT;
    endproperty

    WRITE_NO_WAIT_STATE: assert property (WRITE_NO_WAIT_STATE_PROP)
        else $error("FAIL: DUT inserted wait state on write transfer");

    property HRESP_STABLE_TWO_CYCLES_PROP;
        (HRESP == HRESP_ERROR && !HREADYOUT) |-> (HRESP == HRESP_ERROR)[*2];
    endproperty

    HRESP_STABLE_TWO_CYCLES: assert property (HRESP_STABLE_TWO_CYCLES_PROP)
        else $error("FAIL: HRESP did not remain stable during ERROR response");

    property HREADY_EQUALS_HREADYOUT_PROP;
        (HREADY) == HREADYOUT;              // In a single slave system the HREADY is directly driven by HREADYOUT
    endproperty
    
    HREADY_EQUALS_HREADYOUT: assert property(HREADY_EQUALS_HREADYOUT_PROP)
        else $error("FAIL: HREADY does not equal HREADYOUT in single slave system");

    // ---------------------------------------------FUNCTIONAL PROPERTIES, ASSERTIONS AND COVERS----------------------------------------------
    /*
    // First Property | Data written to address A must be readable from address A
    property DATA_VALIDITY;
        // Antecedent: a write just completed and a read
        // starts immediately to the same address
        // HREADYOUT==1 ensures slave is ready for new transfer
        (last_write_valid &&
         !HWRITE &&
         HADDR == last_write_addr &&
         HSEL &&
         HTRANS == HTRANS_NONSEQ &&
         HREADYOUT == 1)
        |->
        ##1 (HREADYOUT == 0)    // DUT inserts 1 wait state on NONSEQ read
        ##1 (HRDATA == last_write_data && HREADYOUT == 1);
    endproperty

    DATA_VALID_CHECK: assert property (DATA_VALIDITY)
        else $error("FAIL: Read data does not match written data at addr 0x%0h", last_write_addr);

    DATA_VALID_COVER: cover property (
        last_write_valid && !HWRITE && HADDR == last_write_addr &&
        HSEL && HTRANS == HTRANS_NONSEQ);

    // Second Property | No memory location changes without a valid write transaction
    property MEM_LOCATION_CHANGE;
        (HTRANS == HTRANS_IDLE && HSEL) |=> HREADYOUT;       // This checks that if no one is writing or reading, is data the same or not. Since we checked data validity above, we dont need more conditions in this
    endproperty

    SPURIOUS_WRITE_CHECK: assert property (MEM_LOCATION_CHANGE)
        else $error("FAIL: A spurious write has been observed");

    //SPURIOUS_WRITE_COVER: cover property (!HSEL || HTRANS == HTRANS_IDLE);

    // Third Property | Byte write to address A does not modify bytes A+1, A+2, A+3
    property WRITE_MODIFICATION;
        // Antecedent: byte write just completed and read
        // starts to same word address while slave is ready
        (byte_write_pending &&
         HSEL && !HWRITE &&
         HTRANS == HTRANS_NONSEQ &&
         HREADYOUT == 1 &&
         HADDR[15:2] == byte_write_addr_saved[15:2])
        |->
        // Wait state from DUT on NONSEQ read
        ##1 (HREADYOUT == 0)
        // Data valid after wait state
        ##1 (
            (byte_write_addr_saved[1:0] == 2'b00) ?
                (HRDATA[7:0]   == byte_write_data) :
            (byte_write_addr_saved[1:0] == 2'b01) ?
                (HRDATA[15:8]  == byte_write_data) :
            (byte_write_addr_saved[1:0] == 2'b10) ?
                (HRDATA[23:16] == byte_write_data) :
                (HRDATA[31:24] == byte_write_data)
        );
    endproperty

    BYTE_WRITE_CHECK: assert property (WRITE_MODIFICATION)
        else $error("FAIL: Byte write at addr 0x%0h modified other bytes", byte_write_addr_saved);

    /*BYTE_WRITE_COVER: cover property (
        byte_write_pending &&
        HSEL && !HWRITE &&
        HTRANS == HTRANS_NONSEQ &&
        HREADYOUT == 1 &&
        HADDR[15:2] == byte_write_addr_saved[15:2]);*/

    

endmodule