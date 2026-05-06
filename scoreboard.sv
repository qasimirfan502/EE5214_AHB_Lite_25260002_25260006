`ifndef SCOREBOARD_SV
`define SCOREBOARD_SV

class ahb_scoreboard;

  // INTERNAL METRICS ***************************************************************
  
  int total_passes;
  int total_fails;

  // CONSTRUCTOR ***************************************************************
  
  function new();
    
    begin
      total_passes = 0;
      total_fails  = 0;
    end
    
  endfunction

  // CHECK --> SINGLE BEAT ***************************************************************
  
  function void check_beat(string test_name, logic [31:0] expected, logic [31:0] actual, int beat_num = -1);
    string beat_str = (beat_num >= 0) ? $sformatf("Beat %0d:", beat_num) : "";
    
    begin
      
      if (actual !== expected) begin
        $display("[%8t] [FAIL] %s %s Expected %h, Got %h", $time, test_name, beat_str, expected, actual);
        total_fails++;
      end else begin
        $display("[%8t] [PASS] %s %s Read %h correct", $time, test_name, beat_str, actual);
        total_passes++;
      end
      
    end
    
  endfunction

  // CHECK --> ENTIRE BURST ARRAY ***************************************************************
  
  function void check_burst(string test_name, ref logic [31:0] expected[], ref logic [31:0] actual[]);
    
    begin
      
      if (expected.size() != actual.size()) begin
        $display("[%8t] [FATAL] %s: Array size mismatch.... Expected %0d, Actual %0d", 
                  $time, test_name, expected.size(), actual.size());
        total_fails++;
        return;
      end

      for (int i = 0; i < expected.size(); i++) begin
        check_beat(test_name, expected[i], actual[i], i);
      end
      
    end
    
  endfunction

  // CHECK RESP 2-CYCLE RULE ***************************************************************
  
  function void check_protocol_error(string test_name, bit c1_resp, bit c1_rdy, bit c2_resp, bit c2_rdy);
    
    begin
      
      if (c1_resp == 1'b1 && c1_rdy == 1'b0 && c2_resp == 1'b1 && c2_rdy == 1'b1) begin
        $display("[%8t] [PASS] %s: Correct 2-Cycle format -> C1(RESP=1, RDY=0) | C2(RESP=1, RDY=1)", $time, test_name);
        total_passes++;
      end else begin
        $display("[%8t] [FAIL] %s: Invalid format -> C1(RESP=%b, RDY=%b) | C2(RESP=%b, RDY=%b)", 
                 $time, test_name, c1_resp, c1_rdy, c2_resp, c2_rdy);
        total_fails++;
      end
      
    end
    
  endfunction

  // CHECK --> ADDRESS ALIGNMENT ***************************************************************
  
  function void check_alignment(logic [31:0] addr, logic [2:0] size);
    logic [31:0] aligned;
    
    begin
      
      case (size)
        3'b001: aligned = {addr[31:1], 1'b0}; 
        3'b010: aligned = {addr[31:2], 2'b00};
        default: aligned = addr;
      endcase
      
      if (aligned != addr) begin
        $display("[%8t] [FAIL]  Unaligned address detected! Size: %b, Addr: %h", $time, size, addr);
        total_fails++;
      end
      
    end
    
  endfunction
  
  function void print_report();
    
    begin
      
      $display("\n*******************************************************************");
      $display("               SUMMARY                                        ");
      $display("*******************************************************************\n");
      $display(" Passes : %0d", total_passes);
      $display(" Fails  : %0d", total_fails);
      $display("-------------------------------------------------------");
      
      if (total_fails == 0)
        $display(" STATUS   :   [ SUCCESS ] - No bugs :) ");
      else
        $display(" STATUS   :   [ FAILED  ] - Bugs :( ");
        
      $display("*******************************************************************\n");
      
    end
    
  endfunction

endclass

`endif