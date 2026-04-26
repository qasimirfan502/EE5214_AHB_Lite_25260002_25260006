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

    // Ghost code 
    // Track last completed HTRANS
    logic [1:0] htrans_prev;
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn)
            htrans_prev <= HTRANS_IDLE;
        else if (HREADY)
            htrans_prev <= HTRANS;
    end

    // Track write address and data
    logic [15:0] last_write_addr;
    logic [31:0] last_write_data;
    logic        last_write_valid;

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            last_write_addr  <= '0;
            last_write_data  <= '0;
            last_write_valid <= 1'b0;
        end else if (HREADY && HSEL && HWRITE &&
            (HTRANS == HTRANS_NONSEQ || HTRANS == HTRANS_SEQ)) begin
            last_write_addr  <= HADDR;      // captured in address phase
            last_write_data  <= HWDATA;     // captured in data phase
            last_write_valid <= 1'b1;
        end
    end

    // Ghost code needed to check the functional property of Byte write to address A does not modify bytes A+1, A+2, A+3
    // Track last completed read address and data
    logic [15:0] last_read_addr;
    logic [31:0] last_read_data;

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            last_read_addr <= '0;
            last_read_data <= '0;
        end else if (HREADY && HSEL && !HWRITE &&
                 HTRANS == HTRANS_NONSEQ) begin
            last_read_addr <= HADDR;
            last_read_data <= HRDATA;
        end
    end

    // Track byte write with valid preceding read
    logic [31:0] pre_write_data;
    logic [15:0] pre_write_addr;
    logic        pre_write_data_valid;
    logic        byte_write_pending;

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            pre_write_data       <= '0;
            pre_write_addr       <= '0;
            pre_write_data_valid <= 1'b0;
            byte_write_pending   <= 1'b0;
        end else if (HREADY && HSEL && HWRITE &&
                 HTRANS == HTRANS_NONSEQ &&
                 HSIZE == HSIZE_BYTE &&
                 // Only valid if preceding read was to same word address
                 last_read_addr[15:2] == HADDR[15:2]) begin
            pre_write_addr       <= HADDR;
            pre_write_data       <= last_read_data;
            pre_write_data_valid <= 1'b1;
            byte_write_pending   <= 1'b1;
        end else begin
            byte_write_pending   <= 1'b0;
            pre_write_data_valid <= 1'b0;
        end
    end
    //---------------------------------
    // Properties and Assertions
    //---------------------------------

    // The protocol assertions mentioned in the document are Master side obligations, hence they are covered in the assumptions file

    // ---------------------------------------------PROTOCOL PROPERTIES, ASSERTIONS AND COVERS----------------------------------------------
    // First Property | Slaves must always provide a zero wait state OKAY response to IDLE transfers
    property IDLE_TRANSFER_WAIT_STATE;
        (HTRANS == HTRANS_IDLE && HSEL) |-> HREADYOUT;
    endproperty

    IDLE_ZERO_WAIT: assert property (IDLE_TRANSFER_WAIT_STATE)
    else $error("FAIL: Slave did not respond with HREADY=1 on IDLE transfer");

    IDLE_ZERO_WAIT_COVER: cover property (
        HSEL && HTRANS == HTRANS_IDLE);

    // Second Property | Slaves must always provide a zero wait state OKAY response to BUSY transfers
    property BUSY_TRANSFER_WAIT_STATE;
        (HTRANS == HTRANS_BUSY && HSEL) |-> HREADYOUT;
    endproperty

    BUSY_ZERO_WAIT: assert property (BUSY_TRANSFER_WAIT_STATE)
    else $error("FAIL: Slave did not respond with HREADY=1 on BUSY transfer");

    BUSY_ZERO_WAIT_COVER: cover property (
        HSEL && HTRANS == HTRANS_BUSY);
    

    // Third Property | Slave must never generate HRESP=ERROR | SPECIFIC TO THIS DUT ONLY
    property ALWAYS_OK;
        HRESP == HRESP_OKAY     // Since this is to be true for all cases, we do not need any implications
    endproperty

    RESP_OK:assert property (ALWAYS_OK)
    else $error("FAIL: Slave did not respond with HRESP_OKAY");

    RESP_OK_COVER: cover property (
        HRESP == HRESP_OKAY);


    // Fourth Property | During reset all slaves must ensure HREADYOUT is HIGH
    property DEASSERTION_RESET;           // ADDED THE HCLK to override the disable iff condition since I need to check this
        $rose(HRESETn) |=> HREADYOUT;
    endproperty
    
    HREADY_RESET_SLAVE:assert property ( @(posedge HCLK) DEASSERTION_RESET)
    else $error("FAIL: Slave did not assert HREADYOUT as HIGH on reset");

    RESET_RECOVERY_COVER: cover property (
        @(posedge HCLK) $rose(HRESETn));

    // Fifth Property | HRESP=ERROR lasts exactly 2 cycles; HREADY=0 on cycle 1, HREADY=1 on cycle 2
    property TWO_CYCLE_HRESP_ERROR;
        (HRESP == HRESP_ERROR && HREADYOUT == 0) |=> (HRESP == HRESP_ERROR && HREADYOUT == 1); 
    endproperty

    TWO_CYCLE_RESP:assert property (TWO_CYCLE_HRESP_ERROR)
    else $error("FAIL: Slave did not maintain the error for 2 cycles");

    TWO_CYCLE_RESP_COVER: cover property (HRESP == HRESP_ERROR && !HREADYOUT);        // THIS WILL SHOW 0 HITS since we have HRESP SET TO HRESP_OKAY

    // ---------------------------------------------FUNCTIONAL PROPERTIES, ASSERTIONS AND COVERS----------------------------------------------
    // First Property | Data written to address A must be readable from address A
    property DATA_VALIDITY;
        (last_write_valid && !HWRITE && HADDR == last_write_addr && HSEL && HTRANS == HTRANS_NONSEQ) |->  ##1 (HREADYOUT ==  0) ##1 (HRDATA == last_write_data && HREADYOUT == 1); 
    endproperty

    DATA_VALID_CHECK:assert property(DATA_VALIDITY)
    else $error("FAIL: Read data does not match written data at addr 0x%0h", last_write_addr);

    DATA_VALID_COVER:cover property (last_write_valid && !HWRITE && HADDR == last_write_addr && HSEL && HTRANS == HTRANS_NONSEQ);


    // Second Property | No memory location changes without a valid write transaction
    property MEM_LOCATION_CHANGE;
        (!HSEL || HTRANS == HTRANS_IDLE) |=> $stable(HRDATA);       // This checks that if no one is writing or reading, is data the same or not. Since we checked data validity above, we dont need more conditions in this
    endproperty

    SPURIOUS_WRITE_CHECK: assert property (MEM_LOCATION_CHANGE)
    else $error("FAIL: A spurious write has been observed");

    SPURIOUS_WRITE_COVER: cover property (!HSEL || HTRANS == HTRANS_IDLE);

    // Third Property | Byte write to address A does not modify bytes A+1, A+2, A+3
   property WRITE_MODIFICATION;
        (byte_write_pending && pre_write_data_valid &&
            HSEL && !HWRITE && 
            HTRANS == HTRANS_NONSEQ &&
            HADDR[15:2] == pre_write_addr[15:2])
        |-> ##1 (HREADYOUT == 0) ##1 (
                (pre_write_addr[1:0] == 2'b00) ? 
                (HRDATA[31:8]  == pre_write_data[31:8])  :
                (pre_write_addr[1:0] == 2'b01) ? 
                    (HRDATA[31:16] == pre_write_data[31:16] && 
                    HRDATA[7:0]   == pre_write_data[7:0])   :
                    (pre_write_addr[1:0] == 2'b10) ? 
                    (HRDATA[31:24] == pre_write_data[31:24] && 
                    HRDATA[15:0]  == pre_write_data[15:0])  :
                    (HRDATA[23:0]  == pre_write_data[23:0])
        );
    endproperty

    BYTE_WRITE_CHECK: assert property (WRITE_MODIFICATION)
    else $error("FAIL: Byte write at addr 0x%0h modified other bytes", pre_write_addr);

    BYTE_WRITE_COVER: cover property (
    // Read to a word address
    (HSEL && !HWRITE && HTRANS == HTRANS_NONSEQ && HREADY)
    // Followed by byte write to same word address
    ##1 (HSEL && HWRITE && HTRANS == HTRANS_NONSEQ && 
         HSIZE == HSIZE_BYTE &&
         HADDR[15:2] == $past(HADDR[15:2]))
    // Followed by read back to same word address
    ##1 (HSEL && !HWRITE && HTRANS == HTRANS_NONSEQ &&
         HADDR[15:2] == $past(HADDR[15:2]))
    );


endmodule