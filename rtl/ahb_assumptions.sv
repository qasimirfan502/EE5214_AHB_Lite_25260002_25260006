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
    input logic        HREADYOUT,
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
    int unsigned beat_count;
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn)
            beat_count <= 0;
        else if (HREADY && HSEL) begin
            if (HTRANS == HTRANS_NONSEQ)
                beat_count <= 1;
            else if (HTRANS == HTRANS_SEQ)
                beat_count <= beat_count + 1;       // address related to previous transfer
            else    
                beat_count <= 0;
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


    // Now writing assumptions

    // Reset State Assumption | Spec ref: Section 7.1.2
    HTRANS_IDLE_DURING_RESET: assume property (
        @(posedge HCLK)
        !HRESETn |-> (HTRANS == HTRANS_IDLE) && (!$isunknown({master_bus}))
    );

    //---------------------------------------
    // Normal Transfer - WRITE OPERATION
    //---------------------------------------
    NORMAL_TRANSFER_START: assume property(
        (HWRITE == 1 && HSEL) |-> (HTRANS == HTRANS_NONSEQ || HTRANS == HTRANS_SEQ)
    );

    NORMAL_TRANSFER_BUS_WRITE: assume property (
        (HSEL && HTRANS == HTRANS_NONSEQ && HWRITE == 1) |-> ##1 !($isunknown(HWDATA))      // antecedant is the address phase
    );

    NORMAL_TRANSFER_BUS_COMPLETE: assume property (
        (HSEL && HTRANS == HTRANS_NONSEQ && HBURST == HBURST_SINGLE && HREADY) |=> (HTRANS == HTRANS_IDLE || HTRANS == HTRANS_NONSEQ)   // The antecedant checks whether its a single transfer or back to back transfer
    );


    // Signal stability checks
    SLAVE_REQUESTING_WAIT: assume property (
        (!HREADY && HSEL && (HTRANS == HTRANS_NONSEQ || HTRANS == HTRANS_SEQ)) |=> $stable({master_bus})        // Checking if slave requests wait states, the master must not change the address or control signals
    );


    //---------------------------------------
    // Normal Transfer - READ OPERATION
    //---------------------------------------
    READ_STABILITY: assume property (
        (HWRITE == 0 && HSEL && (HTRANS == HTRANS_NONSEQ || HTRANS == HTRANS_SEQ)) |-> !HWRITE
    );


    //---------------------------------------
    // Burst Transfers
    //---------------------------------------

    // First obligation of Burst | This is known by HTRANS being NONSEQ since that is the first beat
    BURST_START_CHECK: assume property (
        (HTRANS == HTRANS_NONSEQ && HSEL && 
        (HBURST == HBURST_INCR4  || HBURST == HBURST_INCR8  ||
             HBURST == HBURST_INCR16 || HBURST == HBURST_WRAP4  ||
             HBURST == HBURST_WRAP8  || HBURST == HBURST_WRAP16)) 
        |-> htrans_prev == HTRANS_IDLE      // htrans_prev stored the previous state in the ghost code above which we are checking
    );

    // Second obligation of Burst | SEQ must follow NONSEQ for the remaining beats
    SEQ_FOLLOW_NONSEQ: assume property (
        (HTRANS == HTRANS_SEQ && HSEL && 
            (HBURST == HBURST_INCR4  || HBURST == HBURST_INCR8  ||
             HBURST == HBURST_INCR16 || HBURST == HBURST_WRAP4  ||
             HBURST == HBURST_WRAP8  || HBURST == HBURST_WRAP16))
        |-> (htrans_prev == HTRANS_NONSEQ || htrans_prev == HTRANS_SEQ)
    );

    // Third obligation of Burst | HBURST must not change
    BURST_TYPE_STABLE: assume property (
        (HTRANS == HTRANS_SEQ && HSEL) |-> HBURST == burst_at_start     // So burst_at_start stores the HBURST at the moment NONSEQ was seen, hence value compared to it
    );

    // Fourth obilgation of Burst | HADDR must increment correctly | Only for INCR
    HADDR_INCREMENT_INCR: assume property (
        (HTRANS == HTRANS_SEQ && HSEL && 
        (HBURST == HBURST_INCR4  || HBURST == HBURST_INCR8  ||
             HBURST == HBURST_INCR16))
        |-> HADDR == haddr_at_ready + (1 << HSIZE)
    );

    // Fourth obilgation of Burst | HADDR must increment correctly | Only for WRAPS
    HADDR_INCREMENT_WRAP4: assume property (
        (HTRANS == HTRANS_SEQ && HSEL && HBURST == HBURST_WRAP4) |-> HADDR == wrapped_addr_4
    );

    HADDR_INCREMENT_WRAP8: assume property (
        (HTRANS == HTRANS_SEQ && HSEL && HBURST == HBURST_WRAP8) |-> HADDR == wrapped_addr_8
    );

    HADDR_INCREMENT_WRAP16: assume property (
        (HTRANS == HTRANS_SEQ && HSEL && HBURST == HBURST_WRAP16) |-> HADDR == wrapped_addr_16
    );

    // Fifth obligation of Burst | Burst must complete exactly N beats | After NONSEQ, exactly N-1 SEQ beats must follow
    BURST_COMPLETE: assume property (
        (HSEL && HTRANS == HTRANS_SEQ && HREADY &&
        (
            // beat_count reaches N-1 meaning this is the last SEQ beat
            (burst_at_start == HBURST_INCR4  && beat_count == 3) ||
            (burst_at_start == HBURST_WRAP4  && beat_count == 3) ||
            (burst_at_start == HBURST_INCR8  && beat_count == 7) ||
            (burst_at_start == HBURST_WRAP8  && beat_count == 7) ||
            (burst_at_start == HBURST_INCR16 && beat_count == 15)||
            (burst_at_start == HBURST_WRAP16 && beat_count == 15)
        )) |=> (HTRANS == HTRANS_IDLE || HTRANS == HTRANS_NONSEQ)
    );

    // Sixth obligation of Burst | 1KB Boundary | Masters should not attempt to start an increment that crosses 1KB boundary
    BURST_1KB_BOUNDARY: assume property (
        (HTRANS == HTRANS_SEQ && HSEL &&
        (HBURST == HBURST_INCR4  || HBURST == HBURST_INCR8 ||
        HBURST == HBURST_INCR16)) |->
        HADDR[15:10] == burst_start_page
    );


    //---------------------------------------
    // Wait state behavior stability check | HWDATA must be held valid until transfer completes
    //---------------------------------------
    HWDATA_STABLE_DURING_WAIT: assume property (
        (!HREADY && HSEL && HWRITE && (HTRANS == HTRANS_NONSEQ || HTRANS == HTRANS_SEQ))
        |=> $stable(HWDATA)
    );

    //---------------------------------------
    // HSIZE and Address alignment
    // 2 rules: 
    //        - HSIZE must be legal for 32-bit bus |"Transfer size must be less than or equal to the width of the data bus"
    //        - Address must be natrually aligned to HSIZE | "All transfers in a burst must be aligned to the address boundary equal to the size of the transfer"
    //---------------------------------------
    HSIZE_LEGAL: assume property (
        (HSEL && (HTRANS == HTRANS_NONSEQ || HTRANS == HTRANS_SEQ))
        |-> (HSIZE <= HSIZE_WORD)
    );

    // Address must be naturally aligned to transfer size
    HADDR_ALIGNED: assume property (
        (HSEL && (HTRANS == HTRANS_NONSEQ || HTRANS == HTRANS_SEQ)) |->
        (
            (HSIZE == HSIZE_BYTE)  ? 1'b1                :  // always aligned
            (HSIZE == HSIZE_HWORD) ? (HADDR[0] == 1'b0)  :  // bit 0 must be 0
            (HSIZE == HSIZE_WORD)  ? (HADDR[1:0] == 2'b00): // bits 1:0 must be 00
            1'b0                                             // larger sizes illegal
        )
    );

endmodule