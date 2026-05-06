`timescale 1ns/1ps

`include "scoreboard.sv"

module tb_top;

  parameter HADDR_SIZE = 16;
  parameter HDATA_SIZE = 32;

  localparam TRANS_IDLE   = 2'b00;
  localparam TRANS_BUSY   = 2'b01; 
  localparam TRANS_NONSEQ = 2'b10;
  localparam TRANS_SEQ    = 2'b11;

  localparam BURST_SINGLE = 3'b000;
  localparam BURST_INCR   = 3'b001;

  localparam BURST_WRAP4  = 3'b010;
  localparam BURST_WRAP8  = 3'b100;
  localparam BURST_WRAP16 = 3'b110;

  localparam BURST_INCR4  = 3'b011;
  localparam BURST_INCR8  = 3'b101;
  localparam BURST_INCR16 = 3'b111;

  logic                  HCLK;
  logic                  HRESETn;
  logic                  HSEL;
  logic [HADDR_SIZE-1:0] HADDR;
  logic [HDATA_SIZE-1:0] HWDATA;
  logic [HDATA_SIZE-1:0] HRDATA;
  logic                  HWRITE;
  logic [2:0]            HSIZE;
  logic [2:0]            HBURST;
  logic [3:0]            HPROT;
  logic [1:0]            HTRANS;
  logic                  HMASTLOCK;
  logic                  HREADY;
  logic                  HREADYOUT;
  logic                  HRESP;

  string TEST_TYPE;

  assign HREADY = HREADYOUT; 

  ahb3liten #(
    .HADDR_SIZE (HADDR_SIZE),
    .HDATA_SIZE (HDATA_SIZE)
  ) dut (
    .HCLK      (HCLK),
    .HRESETn   (HRESETn),
    .HSEL      (HSEL),
    .HADDR     (HADDR),
    .HWDATA    (HWDATA),
    .HRDATA    (HRDATA),
    .HWRITE    (HWRITE),
    .HSIZE     (HSIZE),
    .HBURST    (HBURST),
    .HPROT     (HPROT),
    .HTRANS    (HTRANS),
    .HREADYOUT (HREADYOUT),
    .HREADY    (HREADY),
    .HRESP     (HRESP)
  );

  ahb_cov u_ahb_cov (
    .HCLK      (HCLK),
    .HRESETn   (HRESETn),
    .HSEL      (HSEL),
    .HREADY    (HREADY),
    .HREADYOUT (HREADYOUT),
    .HRESP     (HRESP),
    .HWRITE    (HWRITE),
    .HTRANS    (HTRANS),
    .HSIZE     (HSIZE),
    .HBURST    (HBURST),
    .HPROT     (HPROT),
    .HADDR     (HADDR),
    .HWDATA    (HWDATA),
    .HRDATA    (HRDATA)
);

  // clocking block to avoid any race conditions caused by this master
  clocking cb @(posedge HCLK);
    input  HRDATA, HREADYOUT, HRESP;
    output HADDR, HWDATA, HWRITE, HSIZE, HBURST, HPROT, HTRANS, HMASTLOCK;
  endclocking

  initial HCLK = 0;
  always #5 HCLK = ~HCLK;

  initial begin
    HRESETn   = 0;
    HSEL      = 1'b1;
    TEST_TYPE = "INIT";
    HADDR     = '0;
    HWDATA    = '0;
    HWRITE    = 1'b0;
    HSIZE     = 3'b010; 
    HBURST    = BURST_SINGLE;
    HPROT     = 4'b0011; 
    HTRANS    = TRANS_IDLE;
    HMASTLOCK = 1'b0;
    
    repeat(5) @(posedge HCLK);
    HRESETn = 1;
  end

  // FUNCTIONS *****************************************************************************

  function automatic logic [15:0] get_safe_rand_addr(int num_beats);
    logic [15:0] addr;
    int max_page_offset = 1024 - (num_beats * 4); 
    addr[15:10] = $urandom; 
    addr[9:0] = ($urandom_range(0, max_page_offset)) & 10'h3FC; 
    return addr;
  endfunction

  function automatic void check_alignment(logic [31:0] addr, logic [2:0] size);
    logic [31:0] aligned;
    case (size)
      3'b001: aligned = {addr[31:1], 1'b0}; 
      3'b010: aligned = {addr[31:2], 2'b00};
      default: aligned = addr;
    endcase
    if (aligned != addr) begin
      $error("[AHB PROTOCOL VIOLATION] Unaligned address detected! Size: %b, Addr: %h", size, addr);
    end
  endfunction
  
  function automatic logic [31:0] align_wdata(logic [31:0] data, logic [2:0] size);
    if (size == 3'b000) return {4{data[7:0]}}; 
    if (size == 3'b001) return {2{data[15:0]}};
    return data;
  endfunction

  function automatic logic [31:0] extract_data(logic [31:0] raw_data, logic [1:0] lane, logic [2:0] size);
    int shift_amt = lane * 8;
    logic [31:0] shifted = raw_data >> shift_amt;
    if (size == 3'b000) return shifted & 32'hFF;
    if (size == 3'b001) return shifted & 32'hFFFF;
    return shifted;
  endfunction

  function automatic logic [31:0] get_next_addr(logic [31:0] addr, logic [2:0] burst, logic [2:0] size);
    int beat_bytes = 1 << size;
    int num_beats;
    logic [31:0] wrap_boundary, wrap_mask;
    
    case (burst)
      BURST_WRAP4:  num_beats = 4;
      BURST_WRAP8:  num_beats = 8;
      BURST_WRAP16: num_beats = 16;
      default: return addr + beat_bytes; 
    endcase
    
    wrap_boundary = num_beats * beat_bytes;
    wrap_mask = ~(wrap_boundary - 1);
    
    return (addr & wrap_mask) | ((addr + beat_bytes) % wrap_boundary);
  endfunction

  // TASKS *****************************************************************************
 
  task automatic ahb_write(input [HADDR_SIZE-1:0] addr, input [31:0] data, input [2:0] size);
    bit err = 0;
    
    begin
      check_alignment(addr, size);
      
      @(cb); 
      while (!cb.HREADYOUT) @(cb);
      cb.HADDR <= addr; cb.HWRITE <= 1'b1; cb.HTRANS <= TRANS_NONSEQ; cb.HBURST <= BURST_SINGLE; cb.HSIZE <= size;
      @(cb); 
      cb.HWDATA <= align_wdata(data, size); cb.HTRANS <= TRANS_IDLE;
      @(cb); 
      
      while (!cb.HREADYOUT) begin
      
        if (cb.HRESP) begin err = 1; cb.HTRANS <= TRANS_IDLE; end
        @(cb);
      
      end
      if (cb.HRESP) err = 1; 
      cb.HWRITE <= 1'b0; 
    
    end
  
  endtask



  task automatic ahb_read(input [HADDR_SIZE-1:0] addr, output [31:0] data, input [2:0] size);
    bit err = 0;
    
    begin
      check_alignment(addr, size);
      @(cb);
      
      while (!cb.HREADYOUT) @(cb);
      
      cb.HADDR <= addr; cb.HWRITE <= 1'b0; cb.HTRANS <= TRANS_NONSEQ; cb.HBURST <= BURST_SINGLE; cb.HSIZE <= size;
      
      @(cb); 
      cb.HTRANS <= TRANS_IDLE;  
      @(cb); 
      
      while (!cb.HREADYOUT) begin
      
        if (cb.HRESP) begin err = 1; cb.HTRANS <= TRANS_IDLE; end
        @(cb);
      
      end
      if (cb.HRESP) err = 1;
      
      data = extract_data(cb.HRDATA, addr[1:0], size); 
    
    end
  
  endtask



  task automatic ahb_write_burst(input [HADDR_SIZE-1:0] base_addr, ref logic [31:0] data [], input int length, input [2:0] burst_type, input [2:0] size);
    int i;
    logic [HADDR_SIZE-1:0] curr_addr;
    bit err = 0;
  
    begin
      
      check_alignment(base_addr, size);
      curr_addr = base_addr;
      @(cb); 
      
      while (!cb.HREADYOUT) @(cb);
      
      cb.HADDR <= curr_addr; cb.HWRITE <= 1'b1; cb.HTRANS <= TRANS_NONSEQ; cb.HBURST <= burst_type; cb.HSIZE <= size;
      
      for (i = 1; i < length; i++) begin
        curr_addr = get_next_addr(curr_addr, burst_type, size); 
        @(cb); 
      
        while (!cb.HREADYOUT) begin
      
          if (cb.HRESP) begin err = 1; cb.HTRANS <= TRANS_IDLE; end
          @(cb);
        
        end
        
        if (err) begin cb.HWRITE <= 1'b0; return; end
        
        cb.HADDR <= curr_addr; cb.HTRANS <= TRANS_SEQ; cb.HWDATA <= align_wdata(data[i-1], size);       
      
      end
      
      @(cb); 
      
      while (!cb.HREADYOUT) begin
      
        if (cb.HRESP) begin err = 1; cb.HTRANS <= TRANS_IDLE; end
        @(cb);
      
      end
      cb.HTRANS <= TRANS_IDLE; cb.HBURST <= BURST_SINGLE; cb.HWDATA <= align_wdata(data[length-1], size);
      @(cb);
      
      while (!cb.HREADYOUT) @(cb);
      
      cb.HWRITE <= 1'b0;
    
    end
  
  endtask



  task automatic ahb_read_burst(input [HADDR_SIZE-1:0] base_addr, ref logic [31:0] data [], input int length, input [2:0] burst_type, input [2:0] size);
    int i;
    logic [HADDR_SIZE-1:0] curr_addr;
    logic [HADDR_SIZE-1:0] dphase_addrs []; 
    bit err = 0;

    begin
      check_alignment(base_addr, size);
      dphase_addrs = new[length];
      curr_addr = base_addr;
      dphase_addrs[0] = curr_addr;
      @(cb); while (!cb.HREADYOUT) @(cb);
      cb.HADDR <= curr_addr; cb.HWRITE <= 1'b0; cb.HTRANS <= TRANS_NONSEQ; cb.HBURST <= burst_type; cb.HSIZE <= size;

      for (i = 1; i < length; i++) begin
        curr_addr = get_next_addr(curr_addr, burst_type, size);
        dphase_addrs[i] = curr_addr;
        @(cb); 
        
        while (!cb.HREADYOUT) begin
          if (cb.HRESP) begin err = 1; cb.HTRANS <= TRANS_IDLE; end
          @(cb);
        end
        
        if (err) return;
        
        if (i > 1) data[i-2] = extract_data(cb.HRDATA, dphase_addrs[i-2][1:0], size); 
        cb.HADDR <= curr_addr; cb.HTRANS <= TRANS_SEQ; 

      end
      @(cb); 
      
      while (!cb.HREADYOUT) begin
      
        if (cb.HRESP) begin err = 1; cb.HTRANS <= TRANS_IDLE; end
        @(cb);
      
      end
      if (length > 1) data[length-2] = extract_data(cb.HRDATA, dphase_addrs[length-2][1:0], size);
      cb.HTRANS <= TRANS_IDLE; cb.HBURST <= BURST_SINGLE; 
      @(cb); while (!cb.HREADYOUT) @(cb);
      data[length-1] = extract_data(cb.HRDATA, dphase_addrs[length-1][1:0], size);
    end
  endtask



  task automatic ahb_b2b_write_read_burst(input [HADDR_SIZE-1:0] w_addr, ref logic [31:0] w_data [], input [HADDR_SIZE-1:0] r_addr, ref logic [31:0] r_data [], input int length, input [2:0] burst_type, input [2:0] size);
    int i;
    logic [HADDR_SIZE-1:0] curr_waddr;
    logic [HADDR_SIZE-1:0] curr_raddr;
    logic [HADDR_SIZE-1:0] dphase_raddrs []; 
    bit err = 0;

    begin
      
      check_alignment(w_addr, size);
      check_alignment(r_addr, size);
      dphase_raddrs = new[length];
      curr_waddr = w_addr;
      
      @(cb); 
      
      while (!cb.HREADYOUT) @(cb);
      
      cb.HADDR <= curr_waddr; cb.HWRITE <= 1'b1; cb.HTRANS <= TRANS_NONSEQ; cb.HBURST <= burst_type; cb.HSIZE <= size;
      
      for (i = 1; i < length; i++) begin
        curr_waddr = get_next_addr(curr_waddr, burst_type, size); 
        @(cb); 
      
        while (!cb.HREADYOUT) begin
      
          if (cb.HRESP) begin err = 1; cb.HTRANS <= TRANS_IDLE; end
          @(cb);
        
        end
        
        if (err) begin cb.HWRITE <= 1'b0; return; end
        
        cb.HADDR <= curr_waddr; cb.HTRANS <= TRANS_SEQ; cb.HWDATA <= align_wdata(w_data[i-1], size);       
      
      end
      
      @(cb); 
      
      while (!cb.HREADYOUT) begin
      
        if (cb.HRESP) begin err = 1; cb.HTRANS <= TRANS_IDLE; end
        @(cb);
      
      end
      
      // B2B TRANSITION: Drive final write data AND initiate NONSEQ read address phase simultaneously
      cb.HWDATA <= align_wdata(w_data[length-1], size);
      
      curr_raddr = r_addr;
      dphase_raddrs[0] = curr_raddr;
      cb.HADDR <= curr_raddr; cb.HWRITE <= 1'b0; cb.HTRANS <= TRANS_NONSEQ; cb.HBURST <= burst_type; 

      for (i = 1; i < length; i++) begin
        curr_raddr = get_next_addr(curr_raddr, burst_type, size);
        dphase_raddrs[i] = curr_raddr;
        @(cb); 
        
        while (!cb.HREADYOUT) begin
          if (cb.HRESP) begin err = 1; cb.HTRANS <= TRANS_IDLE; end
          @(cb);
        end
        
        if (err) return;
        
        if (i > 1) r_data[i-2] = extract_data(cb.HRDATA, dphase_raddrs[i-2][1:0], size); 
        cb.HADDR <= curr_raddr; cb.HTRANS <= TRANS_SEQ; 

      end
      
      @(cb); 
      
      while (!cb.HREADYOUT) begin
      
        if (cb.HRESP) begin err = 1; cb.HTRANS <= TRANS_IDLE; end
        @(cb);
      
      end
      
      if (length > 1) r_data[length-2] = extract_data(cb.HRDATA, dphase_raddrs[length-2][1:0], size);
      cb.HTRANS <= TRANS_IDLE; cb.HBURST <= BURST_SINGLE; 
      
      @(cb); 
      
      while (!cb.HREADYOUT) @(cb);
      
      r_data[length-1] = extract_data(cb.HRDATA, dphase_raddrs[length-1][1:0], size);
      
    end
    
  endtask



  `include "directed_tests.sv"

  // MAIN *****************************************************************************

  logic [31:0] s_wdata, s_rdata;
  logic [31:0] wdata_dyn [], rdata_dyn [];
  
  ahb_scoreboard sb;
  
  initial begin
  
    sb = new(); 
    wait(HRESETn);
    repeat(2) @(posedge HCLK);

    run_directed_tests(sb);

    $display("\n*****************************************************************************");
    $display("               PHASE 8 --> RANDOMIZED TESTS  ~10,000     ");
    $display("*****************************************************************************\n");
    TEST_TYPE = "RANDOM";

    begin
      int fails_before_random; 
      int rand_len;
      fails_before_random = sb.total_fails; 

      for (int k = 0; k < 550; k++) begin
      
        logic [15:0] rand_addr;

        // SINGLE RANDOM *****************************************************************************
        // WORD
        rand_addr = get_safe_rand_addr(1);
        s_wdata = $urandom;
        ahb_write(rand_addr, s_wdata, 3'b010);
        ahb_read (rand_addr, s_rdata, 3'b010);
        sb.check_beat("RANDOM SINGLE (WORD)", s_wdata, s_rdata);

        // HALFWORD
        rand_addr = get_safe_rand_addr(1);
        s_wdata = $urandom;
        ahb_write(rand_addr, s_wdata, 3'b001);
        ahb_read (rand_addr, s_rdata, 3'b001);
        sb.check_beat("RANDOM SINGLE (HALFWORD)", s_wdata[15:0], s_rdata[15:0]);

        // BYTE
        rand_addr = get_safe_rand_addr(1);
        s_wdata = $urandom;
        ahb_write(rand_addr, s_wdata, 3'b000);
        ahb_read (rand_addr, s_rdata, 3'b000);
        sb.check_beat("RANDOM SINGLE (BYTE)", s_wdata[7:0], s_rdata[7:0]);


        // INCR RANDOM (UNDEFINED LENGTH) *****************************************************************************
        rand_len = $urandom_range(2, 12); // Undefined length means the master picks a dynamic beat length at runtime
        
        // WORD
        rand_addr = get_safe_rand_addr(rand_len);
        wdata_dyn = new[rand_len]; rdata_dyn = new[rand_len];
        foreach(wdata_dyn[i]) wdata_dyn[i] = $urandom; 
        ahb_b2b_write_read_burst(rand_addr, wdata_dyn, rand_addr, rdata_dyn, rand_len, BURST_INCR, 3'b010);
        sb.check_burst("RANDOM INCR (WORD)", wdata_dyn, rdata_dyn);

        // HALFWORD
        rand_addr = get_safe_rand_addr(rand_len);
        wdata_dyn = new[rand_len]; rdata_dyn = new[rand_len];
        foreach(wdata_dyn[i]) wdata_dyn[i] = $urandom & 32'h0000FFFF; 
        ahb_b2b_write_read_burst(rand_addr, wdata_dyn, rand_addr, rdata_dyn, rand_len, BURST_INCR, 3'b001);
        sb.check_burst("RANDOM INCR (HALFWORD)", wdata_dyn, rdata_dyn);

        // BYTE
        rand_addr = get_safe_rand_addr(rand_len);
        wdata_dyn = new[rand_len]; rdata_dyn = new[rand_len];
        foreach(wdata_dyn[i]) wdata_dyn[i] = $urandom & 32'h000000FF; 
        ahb_b2b_write_read_burst(rand_addr, wdata_dyn, rand_addr, rdata_dyn, rand_len, BURST_INCR, 3'b000);
        sb.check_burst("RANDOM INCR (BYTE)", wdata_dyn, rdata_dyn);


        // INCR4 RANDOM *****************************************************************************
        // WORD
        rand_addr = get_safe_rand_addr(4);
        wdata_dyn = new[4]; rdata_dyn = new[4];
        foreach(wdata_dyn[i]) wdata_dyn[i] = $urandom; 
        ahb_write_burst(rand_addr, wdata_dyn, 4, BURST_INCR4, 3'b010);
        ahb_read_burst (rand_addr, rdata_dyn, 4, BURST_INCR4, 3'b010);
        sb.check_burst("RANDOM INCR4 (WORD)", wdata_dyn, rdata_dyn);

        // HALFWORD
        rand_addr = get_safe_rand_addr(4);
        wdata_dyn = new[4]; rdata_dyn = new[4];
        foreach(wdata_dyn[i]) wdata_dyn[i] = $urandom & 32'h0000FFFF; 
        ahb_write_burst(rand_addr, wdata_dyn, 4, BURST_INCR4, 3'b001);
        ahb_read_burst (rand_addr, rdata_dyn, 4, BURST_INCR4, 3'b001);
        sb.check_burst("RANDOM INCR4 (HALFWORD)", wdata_dyn, rdata_dyn);

        // BYTE
        rand_addr = get_safe_rand_addr(4);
        wdata_dyn = new[4]; rdata_dyn = new[4];
        foreach(wdata_dyn[i]) wdata_dyn[i] = $urandom & 32'h000000FF; 
        ahb_write_burst(rand_addr, wdata_dyn, 4, BURST_INCR4, 3'b000);
        ahb_read_burst (rand_addr, rdata_dyn, 4, BURST_INCR4, 3'b000);
        sb.check_burst("RANDOM INCR4 (BYTE)", wdata_dyn, rdata_dyn);


        // INCR8 RANDOM *****************************************************************************
        // WORD
        rand_addr = get_safe_rand_addr(8);
        wdata_dyn = new[8]; rdata_dyn = new[8];
        foreach(wdata_dyn[i]) wdata_dyn[i] = $urandom; 
        ahb_write_burst(rand_addr, wdata_dyn, 8, BURST_INCR8, 3'b010);
        ahb_read_burst (rand_addr, rdata_dyn, 8, BURST_INCR8, 3'b010);
        sb.check_burst("RANDOM INCR8 (WORD)", wdata_dyn, rdata_dyn);

        // HALFWORD
        rand_addr = get_safe_rand_addr(8);
        wdata_dyn = new[8]; rdata_dyn = new[8];
        foreach(wdata_dyn[i]) wdata_dyn[i] = $urandom & 32'h0000FFFF; 
        ahb_write_burst(rand_addr, wdata_dyn, 8, BURST_INCR8, 3'b001);
        ahb_read_burst (rand_addr, rdata_dyn, 8, BURST_INCR8, 3'b001);
        sb.check_burst("RANDOM INCR8 (HALFWORD)", wdata_dyn, rdata_dyn);

        // BYTE
        rand_addr = get_safe_rand_addr(8);
        wdata_dyn = new[8]; rdata_dyn = new[8];
        foreach(wdata_dyn[i]) wdata_dyn[i] = $urandom & 32'h000000FF; 
        ahb_write_burst(rand_addr, wdata_dyn, 8, BURST_INCR8, 3'b000);
        ahb_read_burst (rand_addr, rdata_dyn, 8, BURST_INCR8, 3'b000);
        sb.check_burst("RANDOM INCR8 (BYTE)", wdata_dyn, rdata_dyn);


        // INCR16 RANDOM *****************************************************************************
        // WORD
        rand_addr = get_safe_rand_addr(16);
        wdata_dyn = new[16]; rdata_dyn = new[16];
        foreach(wdata_dyn[i]) wdata_dyn[i] = $urandom; 
        ahb_write_burst(rand_addr, wdata_dyn, 16, BURST_INCR16, 3'b010);
        ahb_read_burst (rand_addr, rdata_dyn, 16, BURST_INCR16, 3'b010);
        sb.check_burst("RANDOM INCR16 (WORD)", wdata_dyn, rdata_dyn);

        // HALFWORD
        rand_addr = get_safe_rand_addr(16);
        wdata_dyn = new[16]; rdata_dyn = new[16];
        foreach(wdata_dyn[i]) wdata_dyn[i] = $urandom & 32'h0000FFFF; 
        ahb_write_burst(rand_addr, wdata_dyn, 16, BURST_INCR16, 3'b001);
        ahb_read_burst (rand_addr, rdata_dyn, 16, BURST_INCR16, 3'b001);
        sb.check_burst("RANDOM INCR16 (HALFWORD)", wdata_dyn, rdata_dyn);

        // BYTE
        rand_addr = get_safe_rand_addr(16);
        wdata_dyn = new[16]; rdata_dyn = new[16];
        foreach(wdata_dyn[i]) wdata_dyn[i] = $urandom & 32'h000000FF; 
        ahb_write_burst(rand_addr, wdata_dyn, 16, BURST_INCR16, 3'b000);
        ahb_read_burst (rand_addr, rdata_dyn, 16, BURST_INCR16, 3'b000);
        sb.check_burst("RANDOM INCR16 (BYTE)", wdata_dyn, rdata_dyn);


        // WRAP4 RANDOM *****************************************************************************
        // WORD
        rand_addr = get_safe_rand_addr(4);
        wdata_dyn = new[4]; rdata_dyn = new[4];
        foreach(wdata_dyn[i]) wdata_dyn[i] = $urandom; 
        ahb_write_burst(rand_addr, wdata_dyn, 4, BURST_WRAP4, 3'b010);
        ahb_read_burst (rand_addr, rdata_dyn, 4, BURST_WRAP4, 3'b010);
        sb.check_burst("RANDOM WRAP4 (WORD)", wdata_dyn, rdata_dyn);

        // HALFWORD
        rand_addr = get_safe_rand_addr(4);
        wdata_dyn = new[4]; rdata_dyn = new[4];
        foreach(wdata_dyn[i]) wdata_dyn[i] = $urandom & 32'h0000FFFF; 
        ahb_write_burst(rand_addr, wdata_dyn, 4, BURST_WRAP4, 3'b001);
        ahb_read_burst (rand_addr, rdata_dyn, 4, BURST_WRAP4, 3'b001);
        sb.check_burst("RANDOM WRAP4 (HALFWORD)", wdata_dyn, rdata_dyn);

        // BYTE
        rand_addr = get_safe_rand_addr(4);
        wdata_dyn = new[4]; rdata_dyn = new[4];
        foreach(wdata_dyn[i]) wdata_dyn[i] = $urandom & 32'h000000FF; 
        ahb_write_burst(rand_addr, wdata_dyn, 4, BURST_WRAP4, 3'b000);
        ahb_read_burst (rand_addr, rdata_dyn, 4, BURST_WRAP4, 3'b000);
        sb.check_burst("RANDOM WRAP4 (BYTE)", wdata_dyn, rdata_dyn);


        // WRAP8 RANDOM *****************************************************************************
        // WORD
        rand_addr = get_safe_rand_addr(8);
        wdata_dyn = new[8]; rdata_dyn = new[8];
        foreach(wdata_dyn[i]) wdata_dyn[i] = $urandom; 
        ahb_write_burst(rand_addr, wdata_dyn, 8, BURST_WRAP8, 3'b010);
        ahb_read_burst (rand_addr, rdata_dyn, 8, BURST_WRAP8, 3'b010);
        sb.check_burst("RANDOM WRAP8 (WORD)", wdata_dyn, rdata_dyn);

        // HALFWORD
        rand_addr = get_safe_rand_addr(8);
        wdata_dyn = new[8]; rdata_dyn = new[8];
        foreach(wdata_dyn[i]) wdata_dyn[i] = $urandom & 32'h0000FFFF; 
        ahb_write_burst(rand_addr, wdata_dyn, 8, BURST_WRAP8, 3'b001);
        ahb_read_burst (rand_addr, rdata_dyn, 8, BURST_WRAP8, 3'b001);
        sb.check_burst("RANDOM WRAP8 (HALFWORD)", wdata_dyn, rdata_dyn);

        // BYTE
        rand_addr = get_safe_rand_addr(8);
        wdata_dyn = new[8]; rdata_dyn = new[8];
        foreach(wdata_dyn[i]) wdata_dyn[i] = $urandom & 32'h000000FF; 
        ahb_write_burst(rand_addr, wdata_dyn, 8, BURST_WRAP8, 3'b000);
        ahb_read_burst (rand_addr, rdata_dyn, 8, BURST_WRAP8, 3'b000);
        sb.check_burst("RANDOM WRAP8 (BYTE)", wdata_dyn, rdata_dyn);


        // WRAP16 RANDOM *****************************************************************************
        // WORD
        rand_addr = get_safe_rand_addr(16);
        wdata_dyn = new[16]; rdata_dyn = new[16];
        foreach(wdata_dyn[i]) wdata_dyn[i] = $urandom; 
        ahb_write_burst(rand_addr, wdata_dyn, 16, BURST_WRAP16, 3'b010);
        ahb_read_burst (rand_addr, rdata_dyn, 16, BURST_WRAP16, 3'b010);
        sb.check_burst("RANDOM WRAP16 (WORD)", wdata_dyn, rdata_dyn);

        // HALFWORD
        rand_addr = get_safe_rand_addr(16);
        wdata_dyn = new[16]; rdata_dyn = new[16];
        foreach(wdata_dyn[i]) wdata_dyn[i] = $urandom & 32'h0000FFFF; 
        ahb_write_burst(rand_addr, wdata_dyn, 16, BURST_WRAP16, 3'b001);
        ahb_read_burst (rand_addr, rdata_dyn, 16, BURST_WRAP16, 3'b001);
        sb.check_burst("RANDOM WRAP16 (HALFWORD)", wdata_dyn, rdata_dyn);

        // BYTE
        rand_addr = get_safe_rand_addr(16);
        wdata_dyn = new[16]; rdata_dyn = new[16];
        foreach(wdata_dyn[i]) wdata_dyn[i] = $urandom & 32'h000000FF; 
        ahb_write_burst(rand_addr, wdata_dyn, 16, BURST_WRAP16, 3'b000);
        ahb_read_burst (rand_addr, rdata_dyn, 16, BURST_WRAP16, 3'b000);
        sb.check_burst("RANDOM WRAP16 (BYTE)", wdata_dyn, rdata_dyn);

//  UNCOMMENT TO CHECK DIRECTED TESTS FROM THE CONSOLE******************************************************************************************************************************************
/*         
        if (sb.total_fails > fails_before_random) begin
          $display("\n[FATAL] Scoreboard mismatch detected in Random Phase! Halting random tests to prevent log flood.");
          break;
        end
 */     
      end
    
    end

    #50;
    sb.print_report();
    $finish;
  
  end

endmodule