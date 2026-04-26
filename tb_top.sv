`timescale 1ns/1ps

//`include "packages/ahb3lite_pkg.sv"


// Place this right after your imports/includes and BEFORE module tb_top;

class ahb_master;
    
    // Random variables for 10k transactions 
    rand logic [31:0] haddr;
    rand logic [1:0]  htrans;
    rand logic        hwrite;
    rand logic [2:0]  hsize;
    rand logic [2:0]  hburst;
    rand logic [31:0] hwdata []; // To feed bursts of 16 beats

    // <--- FIX: Intermediate variables for the constraint solver
    rand int num_beats;
    rand int beat_bytes;

    // Constraints [Chapter 3]----------------------------------------------------------------------

    // <--- FIX: Let the solver calculate the beats and bytes directly to prevent array crashes
    constraint c_beat_calc {
        beat_bytes == (1 << hsize); // 3'b000 = 1 byte, 3'b001 = 2 bytes, 3'b010 = 4 bytes....

        if (hburst == 3'b010 || hburst == 3'b011) num_beats == 4;       // WRAP4  | INCR4
        else if (hburst == 3'b100 || hburst == 3'b101) num_beats == 8;  // WRAP8  | INCR8
        else if (hburst == 3'b110 || hburst == 3'b111) num_beats == 16; // WRAP16 | INCR16
        else num_beats == 1;                                            // SINGLE | INCR
    }

    // Address Alignment [Spec 3.4]
    constraint c_alignment {
        haddr % beat_bytes == 0;
    }

    // 1 KB Boundary Restriction [Spec 3.5]
    /*
    * a = Start Addr/1024
    * b = End Addr/1024
    * if (a != b){
    * the burst crossed into a new 1 KB block.
    * }
    */
    constraint c_1kb_boundary {
        if (hburst == 3'b011 || hburst == 3'b101 || hburst == 3'b111) { // INCR4, INCR8, INCR16
            (haddr / 1024) == ((haddr + (num_beats * beat_bytes) - 1) / 1024);
        }
    }

    // 32-bit data width according to key signals in project description 
    constraint c_max_size {
        hsize <= 3'b010; 
    }

    // new transactions should always start as a NONSEQ transfer... SEQ continues it — SEQ cannot follow IDLE are handled in driver task
    constraint c_valid_htrans {
        htrans == 2'b10; 
    }
    
    // Make the data array match the burst length
    constraint c_hwdata_size {
        hwdata.size() == num_beats;
    }

endclass

module tb_top;
    import ahb3lite_pkg::*;
    logic HCLK;     // rising edge clk 
    logic HRESETn;  // rst @ 0 (active low)

    // Master Control Signals
    logic [31:0]    HADDR;        // Address — must be aligned to HSIZE
    logic [1:0]     HTRANS;       // IDLE=00, BUSY=01, NONSEQ=10, SEQ=11
    logic           HWRITE;       // 1=write, 0=read
    logic [2:0]     HSIZE;        // Transfer size: byte/halfword/word
    logic [2:0]     HBURST;       // SINGLE, INCR, WRAP4/8/16, INCR4/8/16
    logic           HMASTLOCK;    // High = current transfer is part of a locked sequence
    logic [3:0]     HPROT;
    logic           HREADYOUT;
    
    logic [31:0]    HWDATA;       

    // clk generation
    initial begin
        HCLK = 1'b0;
        forever #5 HCLK = ~HCLK; 
    end

    // reset generation & test execution
    initial begin
        // The reset can be asserted asynchronously 
        HRESETn = 1'b0; 
        HTRANS    = 2'b00; // IDLE as required
        HADDR     = 32'h0;
        HBURST    = 3'b000;
        HSIZE     = 3'b000;
        HWRITE    = 1'b0;
        HPROT     = 4'b0000;
        HMASTLOCK = 1'b0;

        // Hold reset active for a few clock cycles
        repeat(5) @(posedge HCLK);

        // Reset is deasserted synchronously after the rising edge of HCLK. 
        #1 HRESETn = 1'b1;

        // **************************TODO: Directed tests here****************************************

        // (Inside your initial block, after reset deasserts)
        begin
            ahb_master my_txn = new();
            
            repeat(10) begin
                if (my_txn.randomize()) begin
                    $display("[%0t] Driving Burst: HADDR=%0h, HBURST=%0b", $time, my_txn.haddr, my_txn.hburst);
                    execute_txn(my_txn); // Drive it!
                end else begin
                    $error("Randomization failed!");
                end
            end
        end
        
        #100 $finish; // End simulation neatly
    end

    // Dummy ready signal so the while loop doesn't hang
    assign HREADYOUT = 1'b1; 

    task execute_txn(ahb_master txn);
        int beats;
        logic [31:0] current_addr;
        
        // <--- FIX: Using the direct variables instead of function calls
        beats = txn.num_beats; 
        current_addr = txn.haddr;
        
        // @ beat 0
        @(posedge HCLK);
        HADDR  <= current_addr;
        HWRITE <= txn.hwrite;
        HSIZE  <= txn.hsize;
        HBURST <= txn.hburst;
        HTRANS <= 2'b10; // First beat -> NONSEQ [Spec 3.2]
        
        //loop to iterate through rest of the beats
        for (int i = 0; i < beats; i++) begin
            @(posedge HCLK);
            
            // wait -> HREADYOUT == 0.
            while (HREADYOUT == 1'b0) begin
                @(posedge HCLK);
            end
            
            // Data phase 
            if (txn.hwrite) begin
                HWDATA <= txn.hwdata[i];
            end

            // Addr phase for next beat 
            if (i < (beats - 1)) begin
                current_addr = current_addr + txn.beat_bytes; // Increment address
                HADDR  <= current_addr;
                HTRANS <= 2'b11; // SEQ continues the transfer after NONSEQ state
            end else begin
                HTRANS <= 2'b00; //IDLE
            end
        end
    endtask
endmodule
