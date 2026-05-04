// ahb_covers.sv
// Part 3 Task 3.2
// These cover interesting corner cases to confirm reachability as mentioned in the given document
// Any unreachable cover is explained in the report.

module ahb_covers
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

    default clocking cb
        @(posedge HCLK);
    endclocking

    default disable iff (!HRESETn);

    // -----------------------------------------
    // Ghost state for write-read tracking
    // -----------------------------------------

    logic [15:0] prev_write_addr;
    logic        prev_write_valid;

    // Track the address phase of a write
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            prev_write_addr  <= '0;
            prev_write_valid <= 1'b0;
        end else if (HREADYOUT && HSEL && HWRITE &&
                     (HTRANS == HTRANS_NONSEQ || HTRANS == HTRANS_SEQ)) begin
            prev_write_addr  <= HADDR;
            prev_write_valid <= 1'b1;
        end else if (HTRANS == HTRANS_IDLE) begin
            prev_write_valid <= 1'b0;
        end
    end
    // ----------------------------------------------------------------
    //          COVERS GIVEN IN THE DOCUMENT
    // ----------------------------------------- ----------------------
    COV_HREADY_LOW_3_CYCLES: cover property (
        !HREADYOUT ##1 !HREADYOUT ##1 !HREADYOUT
    );


    logic [15:0] prev_seq_addr;
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn)
            prev_seq_addr <= '0;
        else if (HREADYOUT && HSEL && HTRANS == HTRANS_SEQ)
            prev_seq_addr <= HADDR;
    end
    COV_WRAP4_WRAP_OCCURS: cover property (
        // A WRAP4 burst is in progress
        (HSEL && HTRANS == HTRANS_SEQ && HBURST == HBURST_WRAP4 && HREADYOUT)
        // And the address wrapped — current SEQ address is less than previous
        // which is the signature of a wrap event
        ##0 (HADDR < prev_seq_addr)
    );


    COV_WRITE_THEN_READ_SAME_ADDR: cover property (
        // Cycle N: write address phase
        (HSEL && HWRITE && HTRANS == HTRANS_NONSEQ && HREADYOUT)
        // Cycle N+1: read address phase to the same address immediately after
        ##1 (HSEL && !HWRITE && HTRANS == HTRANS_NONSEQ &&
             HADDR == $past(HADDR) && HREADYOUT)
    );


    COV_HRESP_ERROR: cover property (
        HRESP == HRESP_ERROR
    );


    COV_BACK_TO_BACK_NONSEQ: cover property (
        // First NONSEQ completes with HREADYOUT=1
        (HSEL && HTRANS == HTRANS_NONSEQ && HREADYOUT)
        // Immediately followed by another NONSEQ — no IDLE gap
        ##1 (HSEL && HTRANS == HTRANS_NONSEQ && HREADYOUT)
    );

    // ----------------------------------------------------------------
    //          COVERS APART FROM THE ONE'S GIVEN IN THE DOCUMENT
    // ----------------------------------------- ----------------------

    COV_SEQ_READ_COMPLETES: cover property (
        (HSEL && HTRANS == HTRANS_SEQ && !HWRITE && HREADYOUT)
        ##1 HREADYOUT  // no wait state inserted
    );


    COV_CONTENTION_PATH: cover property (
        (HSEL && HWRITE && HTRANS == HTRANS_NONSEQ && HREADYOUT)
        ##1 (HSEL && !HWRITE && HTRANS == HTRANS_NONSEQ &&
            HADDR == $past(HADDR) && HREADYOUT)
    );


    COV_BYTE_WRITE_OCCURS: cover property (
        HSEL && HWRITE && HSIZE == HSIZE_BYTE &&
        HTRANS == HTRANS_NONSEQ && HREADYOUT
    );


    COV_HWORD_WRITE_OCCURS: cover property (
        HSEL && HWRITE && HSIZE == HSIZE_HWORD &&
        HTRANS == HTRANS_NONSEQ && HREADYOUT
    );


    COV_WORD_WRITE_OCCURS: cover property (
        HSEL && HWRITE && HSIZE == HSIZE_WORD &&
        HTRANS == HTRANS_NONSEQ && HREADYOUT
    );


    COV_INCR_BURST_3_BEATS: cover property (
        (HSEL && HTRANS == HTRANS_NONSEQ && HBURST == HBURST_INCR && HREADYOUT)
        ##1 (HSEL && HTRANS == HTRANS_SEQ  && HBURST == HBURST_INCR && HREADYOUT)
        ##1 (HSEL && HTRANS == HTRANS_SEQ  && HBURST == HBURST_INCR && HREADYOUT)
    );



    COV_WADDR_RADDR_BUG_SCENARIO: cover property (
        // Write to address A
        (HSEL && HWRITE && HTRANS == HTRANS_NONSEQ && HREADYOUT)
        // Write to different address B (moves waddr away from A)
        ##1 (HSEL && HWRITE && HTRANS == HTRANS_NONSEQ && HREADYOUT &&
            HADDR != $past(HADDR))
        // Read back from address A — waddr now points to B, not A
        ##1 (HSEL && !HWRITE && HTRANS == HTRANS_NONSEQ && HREADYOUT &&
            HADDR == $past(HADDR, 2))
    );


    COV_BYTE_LANE0_READ_BACK: cover property (
        (HSEL && HWRITE && HTRANS == HTRANS_NONSEQ &&
            HSIZE == HSIZE_BYTE && HADDR[1:0] == 2'b00 && HREADYOUT)
            ##[1:3] (HSEL && !HWRITE && HTRANS == HTRANS_NONSEQ && HREADYOUT)
    );


    COV_BYTE_LANE1_READ_BACK: cover property (
        (HSEL && HWRITE && HTRANS == HTRANS_NONSEQ &&
        HSIZE == HSIZE_BYTE && HADDR[1:0] == 2'b01 && HREADYOUT)
        ##[1:3] (HSEL && !HWRITE && HTRANS == HTRANS_NONSEQ && HREADYOUT)
    );

    COV_BYTE_LANE2_READ_BACK: cover property (
        (HSEL && HWRITE && HTRANS == HTRANS_NONSEQ &&
        HSIZE == HSIZE_BYTE && HADDR[1:0] == 2'b10 && HREADYOUT)
        ##[1:3] (HSEL && !HWRITE && HTRANS == HTRANS_NONSEQ && HREADYOUT)
    );

    COV_BYTE_LANE3_READ_BACK: cover property (
        (HSEL && HWRITE && HTRANS == HTRANS_NONSEQ &&
        HSIZE == HSIZE_BYTE && HADDR[1:0] == 2'b11 && HREADYOUT)
        ##[1:3] (HSEL && !HWRITE && HTRANS == HTRANS_NONSEQ && HREADYOUT)
    );

endmodule