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
    // Auxilary Code
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
    // Stage 1: address phase (HADDR valid)
    // Stage 2: data phase (HWDATA valid next cycle)
    // =========================================
    logic        write_addr_captured;
    logic [15:0] write_addr_latched;

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            write_addr_captured <= 1'b0;
            write_addr_latched  <= '0;
        end else begin
            if (HREADY && HSEL && HWRITE &&
                (HTRANS == HTRANS_NONSEQ || HTRANS == HTRANS_SEQ)) begin
                write_addr_captured <= 1'b1;
                write_addr_latched  <= HADDR;
            end else begin
                write_addr_captured <= 1'b0;
            end
        end
    end

    logic [15:0] last_write_addr;
    logic [31:0] last_write_data;
    logic        last_write_valid;
    // Ghost signal that mirrors the DUT's internal ahb_write
    logic ghost_ahb_write;
    assign ghost_ahb_write = HSEL & HWRITE & (HTRANS != HTRANS_BUSY) & (HTRANS != HTRANS_IDLE);
    // Ghost signal that mirrors the DUT's internal ahb_read
    logic ghost_ahb_read;
    assign ghost_ahb_read = HSEL & ~HWRITE & (HTRANS != HTRANS_BUSY) & (HTRANS != HTRANS_IDLE);

    // Stage 2: only commit when the data phase is also a genuine write
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            last_write_addr  <= '0;
            last_write_data  <= '0;
            last_write_valid <= 1'b0;
        end else if (write_addr_captured && HREADY && ghost_ahb_write) begin
        // ghost_ahb_write ensures data phase is a real write, not BUSY/IDLE
            last_write_addr  <= write_addr_latched;
            last_write_data  <= HWDATA;
            last_write_valid <= 1'b1;
        end else if (write_addr_captured && ghost_ahb_write && !HREADY) begin
            // Address phase happened but data phase is not a write — abandoned
            last_write_valid <= 1'b0;
        end
    end

    // =========================================
    // Byte write tracking — two stage pipeline
    // =========================================
    logic [15:0] byte_write_addr_saved;
    logic        byte_write_addr_captured;

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            byte_write_addr_saved    <= '0;
            byte_write_addr_captured <= 1'b0;
        end else if (HREADYOUT && HSEL && HWRITE && HTRANS == HTRANS_NONSEQ && HSIZE == HSIZE_BYTE) begin
            byte_write_addr_saved    <= HADDR;
            byte_write_addr_captured <= 1'b1;
        end else begin
            byte_write_addr_captured <= 1'b0;
        end
    end

    logic [7:0]  byte_write_data;
    logic        byte_write_pending;

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            byte_write_data    <= '0;
            byte_write_pending <= 1'b0;
        end else if (byte_write_addr_captured && HSEL && HWRITE) begin
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
    // Read tracking — two stage pipeline
    // =========================================
    logic        read_addr_captured;
    logic [15:0] read_addr_latched;

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            read_addr_captured <= 1'b0;
            read_addr_latched  <= '0;
        end else begin
            if (HREADYOUT && HSEL && !HWRITE &&
                (HTRANS == HTRANS_NONSEQ || HTRANS == HTRANS_SEQ) &&
                !(HTRANS == HTRANS_SEQ && $past(HWRITE))) begin  // not a direction flip
                read_addr_captured <= 1'b1;
                read_addr_latched  <= HADDR;
            end else begin
                read_addr_captured <= 1'b0;
            end
        end
    end

    logic [15:0] last_read_addr;
    logic [31:0] last_read_data;
    logic        last_read_valid;
    logic        valid_write_between;

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            last_read_addr  <= '0;
            last_read_data  <= '0;
            last_read_valid <= 1'b0;
        end else if (read_addr_captured && HREADYOUT && ghost_ahb_read) begin
            last_read_addr  <= read_addr_latched;
            last_read_data  <= HRDATA;
            last_read_valid <= 1'b1;
        end
    end

    // Track whether a valid write occurred between two reads
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            valid_write_between <= 1'b0;
        end else if (write_addr_captured && HREADYOUT && ghost_ahb_write) begin
            valid_write_between <= 1'b1;
        end else if (read_addr_captured && HREADYOUT && ghost_ahb_read) begin
            valid_write_between <= 1'b0;
        end
    end

 


    // ---------------------------------------------PROTOCOL ASSERTIONS----------------------------------------------

    
    property IDLE_ZERO_WAIT_PROP;
        (HSEL && HTRANS == HTRANS_IDLE) |=> HREADYOUT;
    endproperty

    IDLE_ZERO_WAIT: assert property (IDLE_ZERO_WAIT_PROP)
        else $error("FAIL: Slave did not provide zero wait state on IDLE");


    property BUSY_ZERO_WAIT_PROP;
        (HSEL && HTRANS == HTRANS_BUSY) |=> HREADYOUT;
    endproperty

    BUSY_ZERO_WAIT: assert property (BUSY_ZERO_WAIT_PROP)
        else $error("FAIL: Slave did not provide zero wait state on BUSY");

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


    property HREADY_EQUALS_HREADYOUT_PROP;
        HREADY == HREADYOUT;
    endproperty

    HREADY_EQUALS_HREADYOUT: assert property (HREADY_EQUALS_HREADYOUT_PROP)
        else $error("FAIL: HREADY does not equal HREADYOUT");
    
    // ---------------------------------------------FUNCTIONAL ASSERTIONS----------------------------------------------
   
    DATA_VALIDITY_COVER: cover property (
        last_write_valid ##1
        (HSEL && !HWRITE &&
        HTRANS == HTRANS_NONSEQ &&
        HADDR == last_write_addr)
    );

    property DATA_VALIDITY_PROP;
        (last_write_valid &&
        HSEL && !HWRITE &&
        HTRANS == HTRANS_NONSEQ &&
        HADDR == last_write_addr &&
        HREADYOUT)
        |->
        ##1 (!HREADYOUT)
        ##1 (HREADYOUT && (HRDATA == $past(last_write_data, 2)));
    endproperty

    DATA_VALIDITY: assert property (DATA_VALIDITY_PROP)
         else $error("FAIL: Read data was not valid");

    NO_MEMORY_LOCATION_CHANGE_COVER: cover property (
        last_read_valid &&
        !valid_write_between ##1
        (HSEL && !HWRITE &&
        HTRANS == HTRANS_NONSEQ &&
        HADDR == last_read_addr)
    );

    property NO_MEMORY_LOCATION_CHANGE_PROP;
        (last_read_valid &&
        !valid_write_between &&
        HSEL && !HWRITE &&
        HTRANS == HTRANS_NONSEQ &&
        HADDR == last_read_addr &&
        HREADYOUT)
        |-> ##1 (!HREADYOUT) ##1 (HREADYOUT && (HRDATA == $past(last_read_data, 2)));
    endproperty

    NO_MEMORY_LOCATION_CHANGE: assert property (NO_MEMORY_LOCATION_CHANGE_PROP)
    else $error("FA2 FAIL: Memory at addr 0x%04h changed without a valid write",
            last_read_addr);

endmodule