// ahb_cov.sv
// Functional Coverage for AHB-Lite RAM Verification — Part 1 & Part 3
// Instantiated inside tb_top alongside the DUT.
// Covers all required coverpoints and crosses from the project spec.

module ahb_cov (
    input  logic        HCLK,
    input  logic        HRESETn,
    input  logic        HSEL,
    input  logic        HREADY,
    input  logic        HREADYOUT,
    input  logic        HRESP,
    input  logic        HWRITE,
    input  logic [1:0]  HTRANS,
    input  logic [2:0]  HSIZE,
    input  logic [2:0]  HBURST,
    input  logic [3:0]  HPROT,
    input  logic [15:0] HADDR,
    input  logic [31:0] HWDATA,
    input  logic [31:0] HRDATA
);

 
    // Covergroup 1 — Protocol Signal Coverage
    covergroup cg_protocol @(posedge HCLK);

        option.per_instance = 1;
        option.comment      = "AHB-Lite Protocol Signal Coverage";

        // ------- HTRANS -------
        // All four transfer types must be observed
        cp_htrans: coverpoint HTRANS iff (HRESETn && HSEL) {
            bins idle   = {2'b00};   // IDLE
            bins busy   = {2'b01};   // BUSY
            bins nonseq = {2'b10};   // NONSEQ
            bins seq    = {2'b11};   // SEQ
        }

        // ------- HBURST -------
        // All eight burst types must be observed
        cp_hburst: coverpoint HBURST iff (HRESETn && HSEL &&
                   (HTRANS == 2'b10 || HTRANS == 2'b11)) {
            bins single  = {3'b000};  // SINGLE
            bins incr    = {3'b001};  // INCR (undefined length)
            bins wrap4   = {3'b010};  // WRAP4
            bins incr4   = {3'b011};  // INCR4
            bins wrap8   = {3'b100};  // WRAP8
            bins incr8   = {3'b101};  // INCR8
            bins wrap16  = {3'b110};  // WRAP16
            bins incr16  = {3'b111};  // INCR16
        }

        // ------- HSIZE -------
        // Only BYTE, HWORD, WORD are legal for a 32-bit bus
        // DWORD and larger are excluded — this DUT only supports
        // up to WORD (HSIZE <= 3'b010) per HSIZE_LEGAL_FOR_BUS assumption
        cp_hsize: coverpoint HSIZE iff (HRESETn && HSEL &&
                  (HTRANS == 2'b10 || HTRANS == 2'b11)) {
            bins byte_transfer  = {3'b000};   // 8-bit
            bins hword_transfer = {3'b001};   // 16-bit
            bins word_transfer  = {3'b010};   // 32-bit
            // Excluded: DWORD (3'b011) and larger — DUT is a 32-bit slave,
            // these transfer sizes exceed the bus width and are not
            // supported. Attempting them would require a wider data bus.
            // Excluded bins documented here for report.
            illegal_bins unsupported = {3'b011, 3'b100, 3'b101, 3'b110, 3'b111};
        }

        // ------- HWRITE -------
        // Both read and write must be observed on active transfers
        cp_hwrite: coverpoint HWRITE iff (HRESETn && HSEL &&
                   (HTRANS == 2'b10 || HTRANS == 2'b11)) {
            bins read  = {1'b0};
            bins write = {1'b1};
        }

        // ------- HREADY -------
        // Wait state must be observed at least once
        // Required coverpoint from project spec
        cp_hready: coverpoint HREADY iff (HRESETn && HSEL) {
            bins ready     = {1'b1};
            bins wait_state = {1'b0};   // HREADY=0 — slave inserting wait state
        }

        // ------- HRESP -------
        // HRESP=ERROR is excluded because this DUT hardwires HRESP=OKAY.
        // The assign statement in design.sv makes ERROR structurally
        // unreachable. This is documented in the cover property
        // COV_HRESP_ERROR in ahb_covers.sv as well.
        cp_hresp: coverpoint HRESP iff (HRESETn && HSEL) {
            bins okay  = {1'b0};
            // Excluded: ERROR (1'b1) — DUT hardwires HRESP=OKAY always.
            // No logic path can drive HRESP=1. Formally verified unreachable.
            ignore_bins error_excluded = {1'b1};
        }

        // ------- HADDR — 4-bin address space split -------
        // 16-bit address space (0x0000 to 0xFFFF) divided into 4 equal quadrants
        // Each quadrant is 16KB (0x4000 addresses)
        cp_haddr: coverpoint HADDR[15:14] iff (HRESETn && HSEL &&
                  (HTRANS == 2'b10 || HTRANS == 2'b11)) {
            bins addr_q1 = {2'b00};   // 0x0000 – 0x3FFF  (lower quarter)
            bins addr_q2 = {2'b01};   // 0x4000 – 0x7FFF
            bins addr_q3 = {2'b10};   // 0x8000 – 0xBFFF
            bins addr_q4 = {2'b11};   // 0xC000 – 0xFFFF  (upper quarter)
        }

    endgroup


    // Covergroup 2 — Transfer Type Transitions
    // Captures legal HTRANS state machine sequences
    // Samples on the second cycle of each pair

    covergroup cg_htrans_transitions @(posedge HCLK);

        option.per_instance = 1;
        option.comment      = "HTRANS State Machine Transition Coverage";

        // Previous HTRANS → current HTRANS transitions
        // Only meaningful when HREADY=1 (pipeline advances)
        cp_trans_seq: coverpoint {$past(HTRANS), HTRANS}
                      iff (HRESETn && HSEL && HREADY) {
            bins idle_to_idle   = {4'b00_00};
            bins idle_to_nonseq = {4'b00_10};   // Start of a new transfer
            bins nonseq_to_idle = {4'b10_00};   // Single transfer done
            bins nonseq_to_seq  = {4'b10_11};   // Burst continuing
            bins nonseq_to_nonseq = {4'b10_10}; // Back-to-back — no IDLE gap
            bins seq_to_seq     = {4'b11_11};   // Mid-burst
            bins seq_to_idle    = {4'b11_00};   // Burst ending
            bins seq_to_nonseq  = {4'b11_10};   // Early termination (INCR only)
            bins seq_to_busy    = {4'b11_01};   // Master needs time mid-burst
            bins busy_to_seq    = {4'b01_11};   // Resume after BUSY
            bins nonseq_to_busy = {4'b10_01};   // BUSY after first beat
        }

    endgroup

    // Covergroup 3 — Burst Behavior
    // Covers burst-specific scenarios
    covergroup cg_burst @(posedge HCLK);

        option.per_instance = 1;
        option.comment      = "Burst Transfer Coverage";

        // HBURST x HWRITE cross
        // Required cross from project spec
        // Verifies all burst types are exercised for both reads and writes
        cp_burst_cross_hburst: coverpoint HBURST
                               iff (HRESETn && HSEL && HTRANS == 2'b10) {
            bins single  = {3'b000};
            bins incr    = {3'b001};
            bins wrap4   = {3'b010};
            bins incr4   = {3'b011};
            bins wrap8   = {3'b100};
            bins incr8   = {3'b101};
            bins wrap16  = {3'b110};
            bins incr16  = {3'b111};
        }

        cp_burst_cross_hwrite: coverpoint HWRITE
                               iff (HRESETn && HSEL && HTRANS == 2'b10) {
            bins read  = {1'b0};
            bins write = {1'b1};
        }

        cx_hburst_hwrite: cross cp_burst_cross_hburst, cp_burst_cross_hwrite;

    endgroup

    // Covergroup 4 — Transfer Size x Direction
    // Required cross: HSIZE x HWRITE
    covergroup cg_size_dir @(posedge HCLK);

        option.per_instance = 1;
        option.comment      = "Transfer Size vs Direction Coverage";

        cp_size: coverpoint HSIZE
                 iff (HRESETn && HSEL &&
                     (HTRANS == 2'b10 || HTRANS == 2'b11)) {
            bins byte_sz  = {3'b000};
            bins hword_sz = {3'b001};
            bins word_sz  = {3'b010};
            ignore_bins unsupported = {[3'b011:3'b111]};
        }

        cp_dir: coverpoint HWRITE
                iff (HRESETn && HSEL &&
                    (HTRANS == 2'b10 || HTRANS == 2'b11)) {
            bins read  = {1'b0};
            bins write = {1'b1};
        }

        // Required cross: HSIZE x HWRITE
        // 6 meaningful bins: BYTE_READ, BYTE_WRITE,
        //                    HWORD_READ, HWORD_WRITE,
        //                    WORD_READ, WORD_WRITE
        cx_hsize_hwrite: cross cp_size, cp_dir;

    endgroup


    // Covergroup 5 — HTRANS x HREADY Cross
    // Required cross from project spec
    // Special focus: SEQ with HREADY=0

    covergroup cg_htrans_hready @(posedge HCLK);

        option.per_instance = 1;
        option.comment      = "HTRANS vs HREADY Cross Coverage";

        cp_htrans_x: coverpoint HTRANS iff (HRESETn && HSEL) {
            bins idle   = {2'b00};
            bins busy   = {2'b01};
            bins nonseq = {2'b10};
            bins seq    = {2'b11};
        }

        cp_hready_x: coverpoint HREADY iff (HRESETn && HSEL) {
            bins ready      = {1'b1};
            bins wait_state = {1'b0};
        }

        // Required cross — HTRANS x HREADY
        // Key bin: SEQ with HREADY=0 (master must hold signals stable)
        // Key bin: NONSEQ with HREADY=0 (master must hold address stable)
        cx_htrans_hready: cross cp_htrans_x, cp_hready_x {
            // These are the most important bins per spec Section 3.6
            bins seq_with_wait  = binsof(cp_htrans_x.seq)    &&
                                  binsof(cp_hready_x.wait_state);
            bins nonseq_with_wait = binsof(cp_htrans_x.nonseq) &&
                                    binsof(cp_hready_x.wait_state);
            // All other combinations covered by default cross bins
        }

    endgroup


    // Covergroup 6 — Corner Cases
    // Covers specific interesting scenarios
    // identified during directed testing
    covergroup cg_corner_cases @(posedge HCLK);

        option.per_instance = 1;
        option.comment      = "Corner Case Coverage";

        // Back-to-back NONSEQ — no IDLE between transfers
        // Important for write pipeline and contention logic
        cp_back_to_back: coverpoint {$past(HTRANS), HTRANS}
                         iff (HRESETn && HSEL && HREADY) {
            bins bb_nonseq = {4'b10_10};   // NONSEQ → NONSEQ immediately
        }

        // Write immediately followed by read to same address
        // Exercises the contention resolution logic in design.sv
        cp_write_then_read: coverpoint {$past(HWRITE), HWRITE,
                                        $past(HTRANS),  HTRANS}
                            iff (HRESETn && HSEL && HREADY &&
                                 HADDR == $past(HADDR)) {
            bins wr_then_rd = {6'b1_0_10_10};  // write NONSEQ then read NONSEQ same addr
        }

        // HREADY=0 held — wait state observed
        // Required: HREADY=0 observed at least once
        cp_wait_observed: coverpoint HREADY iff (HRESETn && HSEL) {
            bins wait_hit = {1'b0};
        }

        // Byte lane coverage — which byte within a word is accessed
        // during byte-size transfers
        cp_byte_lane: coverpoint HADDR[1:0]
                      iff (HRESETn && HSEL && HSIZE == 3'b000 &&
                          (HTRANS == 2'b10 || HTRANS == 2'b11)) {
            bins lane0 = {2'b00};   // byte at word offset 0
            bins lane1 = {2'b01};   // byte at word offset 1
            bins lane2 = {2'b10};   // byte at word offset 2
            bins lane3 = {2'b11};   // byte at word offset 3
        }

        // Halfword lane coverage — upper vs lower halfword
        cp_hword_lane: coverpoint HADDR[1]
                       iff (HRESETn && HSEL && HSIZE == 3'b001 &&
                           (HTRANS == 2'b10 || HTRANS == 2'b11)) {
            bins lower_hword = {1'b0};   // HADDR[1]=0, lower halfword
            bins upper_hword = {1'b1};   // HADDR[1]=1, upper halfword
        }

    endgroup


    // Instantiate all covergroups
    cg_protocol        u_cg_protocol;
    cg_htrans_transitions u_cg_transitions;
    cg_burst           u_cg_burst;
    cg_size_dir        u_cg_size_dir;
    cg_htrans_hready   u_cg_htrans_hready;
    cg_corner_cases    u_cg_corner;

    initial begin
        u_cg_protocol    = new();
        u_cg_transitions = new();
        u_cg_burst       = new();
        u_cg_size_dir    = new();
        u_cg_htrans_hready = new();
        u_cg_corner      = new();
    end

endmodule
