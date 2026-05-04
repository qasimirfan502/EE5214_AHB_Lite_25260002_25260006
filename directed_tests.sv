task automatic run_directed_tests(ahb_scoreboard sb);
  logic [31:0] s_wdata, s_rdata;
  logic [31:0] wdata_dyn [], rdata_dyn [];
  logic [31:0] bb_data2;  // second beat for back-to-back test

  $display("\n*****************************************************************************");
  $display("               PHASE 1: SINGLE TRANSFERS               ");
  $display("*****************************************************************************\n");
  TEST_TYPE = "DIRECTED";

  //  Single Transfer: WORD (3'b010) *****************************************************************************
  s_wdata = 32'hDEADBEEF;
  ahb_write(16'h0010, s_wdata, 3'b010);
  ahb_read (16'h0010, s_rdata, 3'b010);
  sb.check_beat("SINGLE DIRECTED (WORD)", s_wdata, s_rdata);

  //  Single Transfer: HALFWORD (3'b001) *****************************************************************************
  s_wdata = 32'h0000BEEF;
  ahb_write(16'h0014, s_wdata, 3'b001);
  ahb_read (16'h0014, s_rdata, 3'b001);
  sb.check_beat("SINGLE DIRECTED (HALFWORD)", s_wdata[15:0], s_rdata[15:0]);

  //  Single Transfer: BYTE (3'b000) *****************************************************************************
  s_wdata = 32'h000000EF;
  ahb_write(16'h0018, s_wdata, 3'b000);
  ahb_read (16'h0018, s_rdata, 3'b000);
  sb.check_beat("SINGLE DIRECTED (BYTE)", s_wdata[7:0], s_rdata[7:0]);


  $display("\n*****************************************************************************");
  $display("               PHASE 2: INCREMENTING BURSTS            ");
  $display("*****************************************************************************\n");

  // INCR BURSTS (UNDEFINED LENGTH) *****************************************************************************
    wdata_dyn = new[5]; rdata_dyn = new[5];

  // WORD (3'b010)
  wdata_dyn[0] = 32'hB001B001;
  wdata_dyn[1] = 32'hB002B002;
  wdata_dyn[2] = 32'hB003B003;
  wdata_dyn[3] = 32'hB004B004;
  wdata_dyn[4] = 32'hB005B005;
  ahb_b2b_write_read_burst(16'h00A0, wdata_dyn, 16'h00A0, rdata_dyn, 5, BURST_INCR, 3'b010);
  sb.check_burst("INCR DIRECTED (WORD)", wdata_dyn, rdata_dyn);

  // HALFWORD (3'b001)
  wdata_dyn[0] = 32'h0000C001;
  wdata_dyn[1] = 32'h0000C002;
  wdata_dyn[2] = 32'h0000C003;
  wdata_dyn[3] = 32'h0000C004;
  wdata_dyn[4] = 32'h0000C005;
  ahb_b2b_write_read_burst(16'h00C0, wdata_dyn, 16'h00C0, rdata_dyn, 5, BURST_INCR, 3'b001);
  sb.check_burst("INCR DIRECTED (HALFWORD)", wdata_dyn, rdata_dyn);

  // BYTE (3'b000)
  wdata_dyn[0] = 32'h000000D1;
  wdata_dyn[1] = 32'h000000D2;
  wdata_dyn[2] = 32'h000000D3;
  wdata_dyn[3] = 32'h000000D4;
  wdata_dyn[4] = 32'h000000D5;
  ahb_b2b_write_read_burst(16'h00E0, wdata_dyn, 16'h00E0, rdata_dyn, 5, BURST_INCR, 3'b000);
  sb.check_burst("INCR DIRECTED (BYTE)", wdata_dyn, rdata_dyn);

  // INCR4 BURSTS *****************************************************************************

  wdata_dyn = new[4]; rdata_dyn = new[4];

  // WORD (3'b010)
  wdata_dyn[0] = 32'h11111111;
  wdata_dyn[1] = 32'h22222222;
  wdata_dyn[2] = 32'h33333333;
  wdata_dyn[3] = 32'h44444444;
  ahb_write_burst(16'h0100, wdata_dyn, 4, BURST_INCR4, 3'b010);
  ahb_read_burst (16'h0100, rdata_dyn, 4, BURST_INCR4, 3'b010);
  sb.check_burst("INCR4 DIRECTED (WORD)", wdata_dyn, rdata_dyn);

  // HALFWORD (3'b001)
  wdata_dyn[0] = 32'h00002220;
  wdata_dyn[1] = 32'h00002221;
  wdata_dyn[2] = 32'h00002222;
  wdata_dyn[3] = 32'h00002223;
  ahb_write_burst(16'h0120, wdata_dyn, 4, BURST_INCR4, 3'b001);
  ahb_read_burst (16'h0120, rdata_dyn, 4, BURST_INCR4, 3'b001);
  sb.check_burst("INCR4 DIRECTED (HALFWORD)", wdata_dyn, rdata_dyn);

  // BYTE (3'b000)
  wdata_dyn[0] = 32'h00000030;
  wdata_dyn[1] = 32'h00000031;
  wdata_dyn[2] = 32'h00000032;
  wdata_dyn[3] = 32'h00000033;
  ahb_write_burst(16'h0140, wdata_dyn, 4, BURST_INCR4, 3'b000);
  ahb_read_burst (16'h0140, rdata_dyn, 4, BURST_INCR4, 3'b000);
  sb.check_burst("INCR4 DIRECTED (BYTE)", wdata_dyn, rdata_dyn);

  // INCR8 BURSTS*****************************************************************************
  wdata_dyn = new[8]; rdata_dyn = new[8];

  // WORD (3'b010)
  wdata_dyn[0] = 32'hA0A0A0A0;
  wdata_dyn[1] = 32'hA1A1A1A1;
  wdata_dyn[2] = 32'hA2A2A2A2;
  wdata_dyn[3] = 32'hA3A3A3A3;
  wdata_dyn[4] = 32'hA4A4A4A4;
  wdata_dyn[5] = 32'hA5A5A5A5;
  wdata_dyn[6] = 32'hA6A6A6A6;
  wdata_dyn[7] = 32'hA7A7A7A7;
  ahb_write_burst(16'h0200, wdata_dyn, 8, BURST_INCR8, 3'b010);
  ahb_read_burst (16'h0200, rdata_dyn, 8, BURST_INCR8, 3'b010);
  sb.check_burst("INCR8 DIRECTED (WORD)", wdata_dyn, rdata_dyn);

  // HALFWORD (3'b001)
  wdata_dyn[0] = 32'h0000B0B0;
  wdata_dyn[1] = 32'h0000B1B1;
  wdata_dyn[2] = 32'h0000B2B2;
  wdata_dyn[3] = 32'h0000B3B3;
  wdata_dyn[4] = 32'h0000B4B4;
  wdata_dyn[5] = 32'h0000B5B5;
  wdata_dyn[6] = 32'h0000B6B6;
  wdata_dyn[7] = 32'h0000B7B7;
  ahb_write_burst(16'h0240, wdata_dyn, 8, BURST_INCR8, 3'b001);
  ahb_read_burst (16'h0240, rdata_dyn, 8, BURST_INCR8, 3'b001);
  sb.check_burst("INCR8 DIRECTED (HALFWORD)", wdata_dyn, rdata_dyn);

  // BYTE (3'b000)
  wdata_dyn[0] = 32'h000000C0;
  wdata_dyn[1] = 32'h000000C1;
  wdata_dyn[2] = 32'h000000C2;
  wdata_dyn[3] = 32'h000000C3;
  wdata_dyn[4] = 32'h000000C4;
  wdata_dyn[5] = 32'h000000C5;
  wdata_dyn[6] = 32'h000000C6;
  wdata_dyn[7] = 32'h000000C7;
  ahb_write_burst(16'h0280, wdata_dyn, 8, BURST_INCR8, 3'b000);
  ahb_read_burst (16'h0280, rdata_dyn, 8, BURST_INCR8, 3'b000);
  sb.check_burst("INCR8 DIRECTED (BYTE)", wdata_dyn, rdata_dyn);

  // INCR16 BURSTS*****************************************************************************
  wdata_dyn = new[16]; rdata_dyn = new[16];

  // WORD (3'b010)
  wdata_dyn[0]  = 32'hC0000000;
  wdata_dyn[1]  = 32'hC0000100;
  wdata_dyn[2]  = 32'hC0000200;
  wdata_dyn[3]  = 32'hC0000300;
  wdata_dyn[4]  = 32'hC0000400;
  wdata_dyn[5]  = 32'hC0000500;
  wdata_dyn[6]  = 32'hC0000600;
  wdata_dyn[7]  = 32'hC0000700;
  wdata_dyn[8]  = 32'hC0000800;
  wdata_dyn[9]  = 32'hC0000900;
  wdata_dyn[10] = 32'hC0000A00;
  wdata_dyn[11] = 32'hC0000B00;
  wdata_dyn[12] = 32'hC0000C00;
  wdata_dyn[13] = 32'hC0000D00;
  wdata_dyn[14] = 32'hC0000E00;
  wdata_dyn[15] = 32'hC0000F00;
  ahb_write_burst(16'h0300, wdata_dyn, 16, BURST_INCR16, 3'b010);
  ahb_read_burst (16'h0300, rdata_dyn, 16, BURST_INCR16, 3'b010);
  sb.check_burst("INCR16 DIRECTED (WORD)", wdata_dyn, rdata_dyn);

  // HALFWORD (3'b001)
  wdata_dyn[0]  = 32'h0000D000;
  wdata_dyn[1]  = 32'h0000D010;
  wdata_dyn[2]  = 32'h0000D020;
  wdata_dyn[3]  = 32'h0000D030;
  wdata_dyn[4]  = 32'h0000D040;
  wdata_dyn[5]  = 32'h0000D050;
  wdata_dyn[6]  = 32'h0000D060;
  wdata_dyn[7]  = 32'h0000D070;
  wdata_dyn[8]  = 32'h0000D080;
  wdata_dyn[9]  = 32'h0000D090;
  wdata_dyn[10] = 32'h0000D0A0;
  wdata_dyn[11] = 32'h0000D0B0;
  wdata_dyn[12] = 32'h0000D0C0;
  wdata_dyn[13] = 32'h0000D0D0;
  wdata_dyn[14] = 32'h0000D0E0;
  wdata_dyn[15] = 32'h0000D0F0;
  ahb_write_burst(16'h0380, wdata_dyn, 16, BURST_INCR16, 3'b001);
  ahb_read_burst (16'h0380, rdata_dyn, 16, BURST_INCR16, 3'b001);
  sb.check_burst("INCR16 DIRECTED (HALFWORD)", wdata_dyn, rdata_dyn);

  // BYTE (3'b000)
  wdata_dyn[0]  = 32'h000000E0;
  wdata_dyn[1]  = 32'h000000E1;
  wdata_dyn[2]  = 32'h000000E2;
  wdata_dyn[3]  = 32'h000000E3;
  wdata_dyn[4]  = 32'h000000E4;
  wdata_dyn[5]  = 32'h000000E5;
  wdata_dyn[6]  = 32'h000000E6;
  wdata_dyn[7]  = 32'h000000E7;
  wdata_dyn[8]  = 32'h000000E8;
  wdata_dyn[9]  = 32'h000000E9;
  wdata_dyn[10] = 32'h000000EA;
  wdata_dyn[11] = 32'h000000EB;
  wdata_dyn[12] = 32'h000000EC;
  wdata_dyn[13] = 32'h000000ED;
  wdata_dyn[14] = 32'h000000EE;
  wdata_dyn[15] = 32'h000000EF;
  ahb_write_burst(16'h0400, wdata_dyn, 16, BURST_INCR16, 3'b000);
  ahb_read_burst (16'h0400, rdata_dyn, 16, BURST_INCR16, 3'b000);
  sb.check_burst("INCR16 DIRECTED (BYTE)", wdata_dyn, rdata_dyn);


  $display("\n*****************************************************************************");
  $display("               PHASE 3: WRAPPING BURSTS                ");
  $display("*****************************************************************************\n");

  // WRAP4 BURSTS*****************************************************************************
  wdata_dyn = new[4]; rdata_dyn = new[4];

  // WORD (3'b010)
  wdata_dyn[0] = 32'h44440000;
  wdata_dyn[1] = 32'h44440001;
  wdata_dyn[2] = 32'h44440002;
  wdata_dyn[3] = 32'h44440003;
  ahb_write_burst(16'h0808, wdata_dyn, 4, BURST_WRAP4, 3'b010);
  ahb_read_burst (16'h0808, rdata_dyn, 4, BURST_WRAP4, 3'b010);
  sb.check_burst("WRAP4 DIRECTED (WORD)", wdata_dyn, rdata_dyn);

  // HALFWORD (3'b001)
  wdata_dyn[0] = 32'h00004420;
  wdata_dyn[1] = 32'h00004421;
  wdata_dyn[2] = 32'h00004422;
  wdata_dyn[3] = 32'h00004423;
  ahb_write_burst(16'h0826, wdata_dyn, 4, BURST_WRAP4, 3'b001);
  ahb_read_burst (16'h0826, rdata_dyn, 4, BURST_WRAP4, 3'b001);
  sb.check_burst("WRAP4 DIRECTED (HALFWORD)", wdata_dyn, rdata_dyn);

  // BYTE (3'b000)
  wdata_dyn[0] = 32'h00000040;
  wdata_dyn[1] = 32'h00000041;
  wdata_dyn[2] = 32'h00000042;
  wdata_dyn[3] = 32'h00000043;
  ahb_write_burst(16'h0843, wdata_dyn, 4, BURST_WRAP4, 3'b000);
  ahb_read_burst (16'h0843, rdata_dyn, 4, BURST_WRAP4, 3'b000);
  sb.check_burst("WRAP4 DIRECTED (BYTE)", wdata_dyn, rdata_dyn);


  // WRAP8 BURSTS *****************************************************************************
  wdata_dyn = new[8]; rdata_dyn = new[8];

  // WORD (3'b010)
  wdata_dyn[0] = 32'h88880000;
  wdata_dyn[1] = 32'h88880001;
  wdata_dyn[2] = 32'h88880002;
  wdata_dyn[3] = 32'h88880003;
  wdata_dyn[4] = 32'h88880004;
  wdata_dyn[5] = 32'h88880005;
  wdata_dyn[6] = 32'h88880006;
  wdata_dyn[7] = 32'h88880007;
  ahb_write_burst(16'h0918, wdata_dyn, 8, BURST_WRAP8, 3'b010);
  ahb_read_burst (16'h0918, rdata_dyn, 8, BURST_WRAP8, 3'b010);
  sb.check_burst("WRAP8 DIRECTED (WORD)", wdata_dyn, rdata_dyn);

  // HALFWORD (3'b001)
  wdata_dyn[0] = 32'h00008820;
  wdata_dyn[1] = 32'h00008821;
  wdata_dyn[2] = 32'h00008822;
  wdata_dyn[3] = 32'h00008823;
  wdata_dyn[4] = 32'h00008824;
  wdata_dyn[5] = 32'h00008825;
  wdata_dyn[6] = 32'h00008826;
  wdata_dyn[7] = 32'h00008827;
  ahb_write_burst(16'h092E, wdata_dyn, 8, BURST_WRAP8, 3'b001);
  ahb_read_burst (16'h092E, rdata_dyn, 8, BURST_WRAP8, 3'b001);
  sb.check_burst("WRAP8 DIRECTED (HALFWORD)", wdata_dyn, rdata_dyn);

  // BYTE (3'b000)
  wdata_dyn[0] = 32'h00000080;
  wdata_dyn[1] = 32'h00000081;
  wdata_dyn[2] = 32'h00000082;
  wdata_dyn[3] = 32'h00000083;
  wdata_dyn[4] = 32'h00000084;
  wdata_dyn[5] = 32'h00000085;
  wdata_dyn[6] = 32'h00000086;
  wdata_dyn[7] = 32'h00000087;
  ahb_write_burst(16'h0947, wdata_dyn, 8, BURST_WRAP8, 3'b000);
  ahb_read_burst (16'h0947, rdata_dyn, 8, BURST_WRAP8, 3'b000);
  sb.check_burst("WRAP8 DIRECTED (BYTE)", wdata_dyn, rdata_dyn);


  $display("\n*****************************************************************************");
  $display("               PHASE 4: WAIT STATE TESTS               ");
  $display("*****************************************************************************\n");

  //  Wait state: WORD *****************************************************************************
  s_wdata = 32'hCAFEBABE;
  force HREADYOUT = 1'b0;
  fork
    begin
      repeat(3) @(posedge HCLK); release HREADYOUT;
    end
    begin
      ahb_write(16'h0A00, s_wdata, 3'b010);        
    end
  
  join
  ahb_read(16'h0A00, s_rdata, 3'b010);
  sb.check_beat("WAIT STATE WRITE (WORD)",     s_wdata,       s_rdata);

  //  Wait state: HALFWORD *****************************************************************************
  s_wdata = 32'h0000BABE;
  force HREADYOUT = 1'b0;
  fork
    begin
      repeat(3) @(posedge HCLK); release HREADYOUT;
    end

    begin
      ahb_write(16'h0A04, s_wdata, 3'b001);
    end
  join
  ahb_read(16'h0A04, s_rdata, 3'b001);
  sb.check_beat("WAIT STATE WRITE (HALFWORD)", s_wdata[15:0], s_rdata[15:0]);

  //  Wait state: BYTE *****************************************************************************
  s_wdata = 32'h000000BE;
  force HREADYOUT = 1'b0;
  fork
    begin
      repeat(3) @(posedge HCLK); release HREADYOUT;
    end
    begin
      ahb_write(16'h0A08, s_wdata, 3'b000);
    end
  join
  ahb_read(16'h0A08, s_rdata, 3'b000);
  sb.check_beat("WAIT STATE WRITE (BYTE)",     s_wdata[7:0],  s_rdata[7:0]);


  $display("\n*****************************************************************************");
  $display("               PHASE 5: BACK-TO-BACK TRANSFERS         ");
  $display("*****************************************************************************\n");

  s_wdata  = 32'hAAAA1111;   // beat 1
  bb_data2 = 32'hBBBB2222;   // beat 2

  // Address phase — beat 1
  @(cb); while (!cb.HREADYOUT) @(cb);
  cb.HADDR <= 16'h0B00; cb.HWRITE <= 1'b1; cb.HTRANS <= TRANS_NONSEQ;
  cb.HBURST <= BURST_SINGLE; cb.HSIZE <= 3'b010;

  // Address phase — beat 2 / Data phase — beat 1  (NONSEQ, no IDLE gap)
  @(cb); while (!cb.HREADYOUT) @(cb);
  cb.HADDR  <= 16'h0B04; cb.HTRANS <= TRANS_NONSEQ;
  cb.HWDATA <= align_wdata(s_wdata, 3'b010);

  // Data phase — beat 2, then IDLE
  @(cb); while (!cb.HREADYOUT) @(cb);
  cb.HTRANS <= TRANS_IDLE; cb.HWDATA <= align_wdata(bb_data2, 3'b010);

  @(cb); while (!cb.HREADYOUT) @(cb);
  cb.HWRITE <= 1'b0;

  // Read back and verify both beats
  ahb_read(16'h0B00, s_rdata, 3'b010);
  sb.check_beat("BACK-TO-BACK WRITE (beat 1)", s_wdata,  s_rdata);
  ahb_read(16'h0B04, s_rdata, 3'b010);
  sb.check_beat("BACK-TO-BACK WRITE (beat 2)", bb_data2, s_rdata);


  $display("\n*****************************************************************************");
  $display("               PHASE 6: 2-CYCLE ERROR RESPONSE TEST          ");
  $display("*****************************************************************************\n");
  TEST_TYPE = "ERROR_TEST";

  fork
    // Thread 1: The Protocol Monitor
    begin
      int wait_cycles = 0;
      bit error_seen = 0;
      bit c1_resp, c1_rdy;
      bit c2_resp, c2_rdy;

      while (wait_cycles < 30) begin
        @(cb);
        if (cb.HRESP == 1'b1) begin
           error_seen = 1;
           c1_resp = cb.HRESP;
           c1_rdy  = cb.HREADYOUT;
           @(cb);
           c2_resp = cb.HRESP;
           c2_rdy  = cb.HREADYOUT;
           
           sb.check_protocol_error("HRESP 2-CYCLE RULE", c1_resp, c1_rdy, c2_resp, c2_rdy);
           break;
        end
        wait_cycles++;
      end
      
      if (!error_seen) begin
         $display("[%8t] [FAIL] HRESP 2-CYCLE RULE: Slave never asserted HRESP=1 during the invalid transaction", $time);
         sb.total_fails++;
      end
    end

    begin
      s_wdata = 32'hDEADDEAD;
      ahb_write(16'h0A01, s_wdata, 3'b010); // Unaligned Word Write
    end
  join


  $display("\n*****************************************************************************");
  $display("               PHASE 7: PROTECTION FAULT INJECTION           ");
  $display("*****************************************************************************\n");
  TEST_TYPE = "PROTECTION_TEST";

  // HPROT[1] = 0
  @(cb);
  cb.HPROT <= 4'b0001; 

  fork
    // err expected
    begin
      int wait_cycles = 0;
      bit error_seen = 0;
      bit c1_resp, c1_rdy, c2_resp, c2_rdy;

      while (wait_cycles < 30) begin
        @(cb);
        
        if (cb.HRESP == 1'b1) begin
           error_seen = 1;
           c1_resp = cb.HRESP; c1_rdy = cb.HREADYOUT;
           @(cb);
           c2_resp = cb.HRESP; c2_rdy = cb.HREADYOUT;
           
           sb.check_protocol_error("HPROT USER FAULT REJECTED", c1_resp, c1_rdy, c2_resp, c2_rdy);
           break;
        
        end
        wait_cycles++;
      
      end
      
      if (!error_seen) begin
         $display("[%8t] [FAIL] HPROT : Slave allowed User access!", $time);
         sb.total_fails++;
      end
    end

    begin
      s_wdata = 32'h1234B23F;
      ahb_write(16'h0E00, s_wdata, 3'b010); 
    end
  join

  @(cb);
  cb.HPROT <= 4'b0011; //restore value 

endtask