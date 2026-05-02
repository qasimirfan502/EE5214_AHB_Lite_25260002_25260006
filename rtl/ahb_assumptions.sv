// This is the assumptions code which is basically serving as a stimulus for the slave design for formal verification
// Jasper will be treating the inputs as free variables but I am trying to constraint them in order to behave as a Master IP

// Some design constraints being considered while writing this code:
//      - HADDR is 16-bit as it is defined as such in the given slave code POTENTIAL BUG 
//      - HDATA is 32-bit as defined in the slave code                     POTENTIAL BUG since the sizes dont match
//      - NO HMASTLOCK feature hence not tested, might add later for bonus points
//      - We have a single slave hence we do not actually need a decoder or a MUX, it is noticed that the design had a HSEL
//        signal which cannot be stimulated from the Master since its sent from the decoder, so we might give HSEL a const value

module ahb_assumptions
import ahb3lite_pkg::*;
(
    input logic        HCLK,
    input logic        HRESETn,
    input logic        HSEL,
    input logic        HREADY,
    input logic        HWRITE,
    input logic [1:0]  HTRANS,
    input logic [2:0]  HSIZE,
    input logic [2:0]  HBURST,
    input logic [3:0]  HPROT,
    input logic [15:0] HADDR,
    input logic [31:0] HWDATA 
);


    // There are many behavioral constructs for a master where the signals are referred to as the address signals and we have to check them together
    // hence I initially wrote long expressions checking each, but I figured I can make a struct and refer to them as a group of signals hence making one below
    typedef struct packed {
    logic        HWRITE;
    logic [1:0]  HTRANS;
    logic [2:0]  HSIZE;
    logic [2:0]  HBURST;
    logic [3:0]  HPROT;
    logic [15:0] HADDR;
    } master_address_control_signals;

    master_address_control_signals master_bus;

    assign master_bus = '{HWRITE, HTRANS, HSIZE, HBURST, HPROT, HADDR};


    // Checking the following assumption 
    initial begin                           
        assume (!HRESETn);
        assume(HTRANS == HTRANS_IDLE);
    end
    // Default clock and reset
    default clocking cb 
            @(posedge HCLK);
    endclocking

    default disable iff (!HRESETn);

    // Adding some logic for internal tracking signals

    // Track the last HTRANS value when HREADY was high, this tells us that the slave doesnt want to add more delays
    logic [1:0] htrans_prev;        // variable to store the previous state
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) 
            htrans_prev <= HTRANS_IDLE;
        else if (HREADY)
            htrans_prev <= HTRANS;          // this means that if the transaction is completed we set the variable back to HTRANS which would have the next value
    end

    // Tracking the beat count
    //int unsigned beat_count;
    logic [4:0] beat_count;
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn)
            beat_count <= 5'd0;
        else if (HREADY) begin
            if (HTRANS == HTRANS_NONSEQ)
                beat_count <= 5'd1;
            else if (HTRANS == HTRANS_SEQ)
                beat_count <= beat_count + 5'd1;
            else if (HTRANS == HTRANS_IDLE)
                beat_count <= 5'd0;
        end
    end

    // Track burst type at burst start (for beat-count checking)
    logic [2:0] burst_at_start;
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn)
            burst_at_start <= HBURST_SINGLE;
        else if (HREADY && HSEL && HTRANS == HTRANS_NONSEQ)
            burst_at_start <= HBURST;
    end

    // Track address-phase signals at last HREADY=1 moment
    logic [1:0]  htrans_at_ready;
    logic [15:0] haddr_at_ready;
    logic        hwrite_at_ready;
    logic [2:0]  hsize_at_ready;
    logic [2:0]  hburst_at_ready;

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            htrans_at_ready <= HTRANS_IDLE;
            haddr_at_ready  <= '0;
            hwrite_at_ready <= '0;
            hsize_at_ready  <= '0;
            hburst_at_ready <= '0;
        end else if (HREADY) begin
            htrans_at_ready <= HTRANS;
            haddr_at_ready  <= HADDR;
            hwrite_at_ready <= HWRITE;
            hsize_at_ready  <= HSIZE;
            hburst_at_ready <= HBURST;
        end
    end

    // HWRITE value at burst start (must remain constant throughout burst)
    logic hwrite_at_burst_start;
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn)
            hwrite_at_burst_start <= 1'b0;
        else if (HREADY && HSEL && HTRANS == HTRANS_NONSEQ)
            hwrite_at_burst_start <= HWRITE;
    end

    // =============================================
    // Wrap address helper logic
    // =============================================

    // WRAP4 — 4 beats, boundary = 4 * (1 << HSIZE)
    logic [15:0] wrap_mask_4;
    logic [15:0] next_addr_4;
    logic [15:0] wrapped_addr_4;

    assign wrap_mask_4   = (4 * (1 << HSIZE)) - 1;
    assign next_addr_4   = haddr_at_ready + (1 << HSIZE);
    assign wrapped_addr_4 = (next_addr_4 & wrap_mask_4) | 
                        (haddr_at_ready & ~wrap_mask_4);

    // WRAP8 — 8 beats, boundary = 8 * (1 << HSIZE)
    logic [15:0] wrap_mask_8;
    logic [15:0] next_addr_8;
    logic [15:0] wrapped_addr_8;

    assign wrap_mask_8   = (8 * (1 << HSIZE)) - 1;
    assign next_addr_8   = haddr_at_ready + (1 << HSIZE);
    assign wrapped_addr_8 = (next_addr_8 & wrap_mask_8) | 
                        (haddr_at_ready & ~wrap_mask_8);

    // WRAP16 — 16 beats, boundary = 16 * (1 << HSIZE)
    logic [15:0] wrap_mask_16;
    logic [15:0] next_addr_16;
    logic [15:0] wrapped_addr_16;

    assign wrap_mask_16   = (16 * (1 << HSIZE)) - 1;
    assign next_addr_16   = haddr_at_ready + (1 << HSIZE);
    assign wrapped_addr_16 = (next_addr_16 & wrap_mask_16) | 
                         (haddr_at_ready & ~wrap_mask_16);


    // 1KB Boundary check logic
    logic [15:10] burst_start_page;
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn)
            burst_start_page <= '0;
        else if (HREADY && HSEL && HTRANS == HTRANS_NONSEQ)
            burst_start_page <= HADDR[15:10];
    end

    // ==========================================================================================
    //                                  WRITING ASSUMPTIONS
    // ==========================================================================================

    // Add this to ensure reset stays high after the first cycle
    RESET_STAYS_HIGH: assume property (@(posedge HCLK) $past(!HRESETn) |-> HRESETn[*1:$]);
    // First of all, since we have only one slave keeping HSEL high from the master
    ASSUME_HSEL_ALWAYS_ON: assume property (HRESETn |-> HSEL == 1'b1);

    SEQ_FOLLOWS_NONSEQ_OR_SEQ: assume property (
        (HTRANS == HTRANS_SEQ && HSEL && 
            (HBURST == HBURST_INCR4  || HBURST == HBURST_INCR8  ||
             HBURST == HBURST_INCR16 || HBURST == HBURST_WRAP4  ||
             HBURST == HBURST_WRAP8  || HBURST == HBURST_WRAP16))
        |-> (htrans_prev == HTRANS_NONSEQ || htrans_prev == HTRANS_SEQ)
    );    


    // NO_SEQ_AFTER_IDLE: A SEQ transfer cannot follow an IDLE transfer
    NO_SEQ_AFTER_IDLE: assume property (
        (htrans_prev == HTRANS_IDLE) |-> (HTRANS != HTRANS_SEQ)
    );    


    NO_BUSY_AFTER_SINGLE: assume property (
        (HSEL && HTRANS == HTRANS_NONSEQ && HBURST == HBURST_SINGLE && HREADY) |=> (HTRANS != HTRANS_BUSY)
    );    


    FIXED_BURST_COUNT_INCR4: assume property (
        (HSEL && HTRANS == HTRANS_SEQ && HREADY && burst_at_start == HBURST_INCR4 && beat_count == 3) 
        |=> (HTRANS == HTRANS_IDLE || HTRANS == HTRANS_NONSEQ)
    );

    FIXED_BURST_COUNT_INCR8: assume property (
        (HSEL && HTRANS == HTRANS_SEQ && HREADY && burst_at_start == HBURST_INCR8 && beat_count == 7) 
        |=> (HTRANS == HTRANS_IDLE || HTRANS == HTRANS_NONSEQ)
    );   

    FIXED_BURST_COUNT_INCR16: assume property (
        (HSEL && HTRANS == HTRANS_SEQ && HREADY && burst_at_start == HBURST_INCR16 && beat_count == 15) 
        |=> (HTRANS == HTRANS_IDLE || HTRANS == HTRANS_NONSEQ)
    );    

    FIXED_BURST_COUNT_WRAP4: assume property (
        (HSEL && HTRANS == HTRANS_SEQ && HREADY && burst_at_start == HBURST_WRAP4 && beat_count == 3) 
        |=> (HTRANS == HTRANS_IDLE || HTRANS == HTRANS_NONSEQ)
    );    

    FIXED_BURST_COUNT_WRAP8: assume property (
        (HSEL && HTRANS == HTRANS_SEQ && HREADY && burst_at_start == HBURST_WRAP8 && beat_count == 7) 
        |=> (HTRANS == HTRANS_IDLE || HTRANS == HTRANS_NONSEQ)
    );

    FIXED_BURST_COUNT_WRAP16: assume property (
        (HSEL && HTRANS == HTRANS_SEQ && HREADY && burst_at_start == HBURST_WRAP16 && beat_count == 15) 
        |=> (HTRANS == HTRANS_IDLE || HTRANS == HTRANS_NONSEQ)
    );    


    HTRANS_STABLE_NONSEQ_SEQ: assume property (
        (!HREADY && HSEL && (HTRANS == HTRANS_NONSEQ || HTRANS == HTRANS_SEQ)) 
        |=> $stable(HTRANS)
    );

    // HTRANS_WAIT_IDLE_TO_NONSEQ: During a waited transfer, IDLE can only change to NONSEQ
    HTRANS_WAIT_IDLE_TO_NONSEQ: assume property (
        (!HREADY && HSEL && HTRANS == HTRANS_IDLE) 
        |=> (HTRANS == HTRANS_IDLE || HTRANS == HTRANS_NONSEQ)
    );    

    HTRANS_WAIT_BUSY_TO_SEQ: assume property (
        (!HREADY && HSEL && HTRANS == HTRANS_BUSY && burst_at_start != HBURST_INCR) 
        |=> (HTRANS == HTRANS_BUSY || HTRANS == HTRANS_SEQ)
    );

    // HTRANS_WAIT_BUSY_ANY: During a waited INCR burst, BUSY can change to any type
    HTRANS_WAIT_BUSY_ANY: assume property (
    (!HREADY && HSEL && 
     HTRANS == HTRANS_BUSY && 
     burst_at_start == HBURST_INCR) |=>
    (HTRANS == HTRANS_SEQ    || 
     HTRANS == HTRANS_IDLE   || 
     HTRANS == HTRANS_NONSEQ ||
     HTRANS == HTRANS_BUSY)
    );

    HADDR_STABLE_DURING_WAIT: assume property (
        (!HREADY && HSEL && (HTRANS == HTRANS_NONSEQ || HTRANS == HTRANS_SEQ)) |=> $stable(HADDR)
    );

    HWRITE_STABLE_DURING_WAIT: assume property (
        (!HREADY && HSEL && (HTRANS == HTRANS_NONSEQ || HTRANS == HTRANS_SEQ)) |=> $stable(HWRITE)
    );


    HSIZE_STABLE_DURING_WAIT: assume property (
        (!HREADY && HSEL && (HTRANS == HTRANS_NONSEQ || HTRANS == HTRANS_SEQ)) |=> $stable(HSIZE)
    );


    HBURST_STABLE_DURING_WAIT: assume property (
        (HTRANS == HTRANS_SEQ && HSEL) |-> (HBURST == burst_at_start)     // So burst_at_start stores the HBURST at the moment NONSEQ was seen, hence value compared to it
    );

    // Address must be naturally aligned to transfer size
    HADDR_ALIGNED_HWORD: assume property(
        (HSEL && (HTRANS == HTRANS_NONSEQ || HTRANS == HTRANS_SEQ)) && HSIZE == HSIZE_HWORD |-> (HADDR[0] == 1'b0)
    );

    HADDR_ALIGNED_WORD: assume property (
        (HSEL && (HTRANS == HTRANS_NONSEQ || HTRANS == HTRANS_SEQ)) && HSIZE == HSIZE_WORD |-> (HADDR[1:0] == 2'b00)
    );

    HSIZE_LEGAL_FOR_BUS: assume property (
        (HSEL && (HTRANS == HTRANS_NONSEQ || HTRANS == HTRANS_SEQ))
        |-> (HSIZE <= HSIZE_WORD)
    );

    HWRITE_CONSTANT_IN_BURST: assume property (
        (HSEL && HTRANS == HTRANS_SEQ) |=> (HWRITE == hwrite_at_burst_start)      // it was too restrictive causing issues for read and write
    );

   // HBURST_CONSTANT_IN_BURST: HBURST must remain constant throughout the burst
    HBURST_CONSTANT_IN_BURST: assume property (
        (HSEL && (HTRANS == HTRANS_SEQ || HTRANS == HTRANS_BUSY)) |-> (HBURST == burst_at_start)
    );

    HSIZE_CONSTANT_IN_BURST: assume property(
        (HSEL && HTRANS == HTRANS_SEQ) |-> (HSIZE == hsize_at_ready)
    );

    // Sixth obligation of Burst | 1KB Boundary | Masters should not attempt to start an increment that crosses 1KB boundary
    INCR_NO_1KB_BOUNDARY: assume property (
        (HTRANS == HTRANS_SEQ && HSEL &&
        (HBURST == HBURST_INCR4  || HBURST == HBURST_INCR8 ||
        HBURST == HBURST_INCR16)) |->
        HADDR[15:10] == burst_start_page
    );

    HADDR_INCR4_INCREMENT: assume property(
        (HTRANS == HTRANS_SEQ && HSEL && HBURST == HBURST_INCR4 && HREADY) |-> HADDR == haddr_at_ready + (1 << HSIZE)
    );

    HADDR_INCR8_INCREMENT: assume property(
        (HTRANS == HTRANS_SEQ && HSEL && HBURST == HBURST_INCR8 && HREADY) |-> HADDR == haddr_at_ready + (1 << HSIZE)
    );

    HADDR_INCR16_INCREMENT: assume property(
        (HTRANS == HTRANS_SEQ && HSEL && HBURST == HBURST_INCR16 && HREADY) |-> (HADDR == haddr_at_ready + (1 << HSIZE))
    );    

    // Fourth obilgation of Burst | HADDR must increment correctly | Only for WRAPS
    HADDR_WRAP4_BOUNDARY: assume property (
        (HTRANS == HTRANS_SEQ && HSEL && HBURST == HBURST_WRAP4 && HREADY) |-> HADDR == wrapped_addr_4
    );

    HADDR_WRAP8_BOUNDARY: assume property (
        (HTRANS == HTRANS_SEQ && HSEL && HBURST == HBURST_WRAP8 && HREADY) |-> HADDR == wrapped_addr_8
    );

    HADDR_WRAP16_BOUNDARY: assume property (
        (HTRANS == HTRANS_SEQ && HSEL && HBURST == HBURST_WRAP16 && HREADY) |-> HADDR == wrapped_addr_16
    );    

    HSEL_STABLE_DURING_BURST: assume property (
        (HSEL && HTRANS == HTRANS_SEQ) |-> $stable(HSEL)
    );

    // Optional assumption added for generic implementation | HPROT not in this design but can be in some other slave module
    HPROT_STABLE_IN_BURST: assume property (
        (HSEL && HTRANS == HTRANS_SEQ) |-> $stable(HPROT)
    );

    HPROT_KNOWN_ON_TRANSFER: assume property (
        (HSEL && (HTRANS == HTRANS_NONSEQ || HTRANS == HTRANS_SEQ)) |-> !$isunknown(HPROT) 
    );

    BUSY_PERMITTED_IN_BURST: assume property (
        (HSEL && HTRANS == HTRANS_BUSY) |->
        (
            (htrans_prev == HTRANS_NONSEQ || 
            htrans_prev == HTRANS_SEQ    ||
            htrans_prev == HTRANS_BUSY)
            &&
            (HBURST != HBURST_SINGLE)
        )
    );

    // Once HTRANS changes to NONSEQ during a wait it must stay NONSEQ
    HTRANS_NONSEQ_STABLE_DURING_WAIT: assume property (
        (!HREADY && HSEL && HTRANS == HTRANS_NONSEQ) |=>
        HTRANS == HTRANS_NONSEQ
    );
    
    // Wait state behavior stability check | HWDATA must be held valid until transfer completes
    //---------------------------------------
    HWDATA_STABLE_DURING_WAIT: assume property (
        (!HREADY)
        |=> $stable(HWDATA)
    );    

    // Signal stability checks
    SLAVE_REQUESTING_WAIT: assume property (
        (!HREADY && HSEL && (HTRANS == HTRANS_NONSEQ || HTRANS == HTRANS_SEQ)) |=> $stable({master_bus})        // Checking if slave requests wait states, the master must not change the address or control signals
    );

    NORMAL_TRANSFER_START: assume property(
        (HSEL && (HTRANS == HTRANS_NONSEQ || HTRANS == HTRANS_SEQ) && HWRITE)
        |-> ##1 !($isunknown(HWDATA))
    );


    NORMAL_TRANSFER_BUS_WRITE: assume property (
        (HSEL && HTRANS == HTRANS_NONSEQ && HWRITE == 1) |-> ##1 !($isunknown(HWDATA))      // antecedant is the address phase
    );

    // Once HTRANS changes to SEQ during a fixed burst wait it must stay SEQ
    SEQ_STABLE_DURING_FIXED_BURST_WAIT: assume property (
        (!HREADY && HSEL && HTRANS == HTRANS_SEQ &&
            (burst_at_start == HBURST_INCR4  || 
            burst_at_start == HBURST_INCR8  ||
            burst_at_start == HBURST_INCR16 ||
            burst_at_start == HBURST_WRAP4  ||
            burst_at_start == HBURST_WRAP8  ||
            burst_at_start == HBURST_WRAP16) &&
            // Do not force stability on last beat
            !(beat_count == 3  && (burst_at_start == HBURST_INCR4  || burst_at_start == HBURST_WRAP4))  &&
            !(beat_count == 7  && (burst_at_start == HBURST_INCR8  || burst_at_start == HBURST_WRAP8))  &&
            !(beat_count == 15 && (burst_at_start == HBURST_INCR16 || burst_at_start == HBURST_WRAP16))
        ) |=> HTRANS == HTRANS_SEQ
    );

    FIXED_BURST_NO_BUSY_LAST: assume property (
        (HSEL && HREADY && 
        ((burst_at_start == HBURST_INCR4 && beat_count == 3) ||
         (burst_at_start == HBURST_INCR8 && beat_count == 7) ||    
         (burst_at_start == HBURST_INCR16 && beat_count == 15) ||
         (burst_at_start == HBURST_WRAP4 && beat_count == 3) ||
         (burst_at_start == HBURST_WRAP8 && beat_count == 7) ||
         (burst_at_start == HBURST_WRAP16 && beat_count == 15))) |->
         (HTRANS != HTRANS_BUSY)
    );

    NORMAL_TRANSFER_BUS_COMPLETE: assume property (
        (HSEL && HTRANS == HTRANS_NONSEQ && HBURST == HBURST_SINGLE && HREADY) |=> (HTRANS == HTRANS_IDLE || HTRANS == HTRANS_NONSEQ)   // The antecedant checks whether its a single transfer or back to back transfer
    );    

endmodule