---
---
# Test Plan
---
---
## Phase 1: Single Transfers

| Scenario | Address | Stimulus | Expected Result |
|----------|----------|----------|-----------------|
| Single Word write/read | `0x0010` | `HDATA = 32'hDEADBEEF`, `HSIZE = 3'b010` | `s_rdata == 32'hDEADBEEF` |
| Single Halfword write/read | `0x0014` | `HWDATA = 32'h0000BEEF`, `HSIZE = 3'b001` | `s_rdata[15:0] = 16'hBEEF` |
| Single Byte write/read | `0x0018` | `HWDATA = 32'h000000EF`, `HSIZE = 3'b000` | `s_rdata[7:0] = 8'hEF` |

---

## Phase 2: Incrementing Bursts

| Scenario | Address | Stimulus | Expected Result |
|----------|---------|--------------------------|-----------------|
| INCR (undef length) Word | `0x00A0` | `B001B001, B002B002, B003B003, B004B004, B005B005` | `s_rdata[N] == s_wdata[N]` for all 5 beats |
| INCR (undef length) Halfword | `0x00C0` | `0000C001, 0000C002, 0000C003, 0000C004, 0000C005` | `s_rdata[N][15:0] == s_wdata[N][15:0]` for all 5 beats |
| INCR (undef length) Byte | `0x00E0` | `000000D1, 000000D2, 000000D3, 000000D4, 000000D5` | `s_rdata[N][7:0] == s_wdata[N][7:0]` for all 5 beats |
| INCR4 Word | `0x0100` | `11111111, 22222222, 33333333, 44444444` | `s_rdata[N] == s_wdata[N]` for all 4 beats |
| INCR4 Halfword | `0x0120` | `00002220, 00002221, 00002222, 00002223` | `s_rdata[N][15:0] == s_wdata[N][15:0]` for all 4 beats |
| INCR4 Byte | `0x0140` | `00000030, 00000031, 00000032, 00000033` | `s_rdata[N][7:0] == s_wdata[N][7:0]` for all 4 beats |
| INCR8 Word | `0x0200` | `A0A0A0A0, A1A1A1A1, A2A2A2A2, A3A3A3A3, A4A4A4A4, A5A5A5A5, A6A6A6A6, A7A7A7A7` | `s_rdata[N] == s_wdata[N]` for all 8 beats |
| INCR8 Halfword | `0x0240` | `0000B0B0, 0000B1B1, 0000B2B2, 0000B3B3, 0000B4B4, 0000B5B5, 0000B6B6, 0000B7B7` | `s_rdata[N][15:0] == s_wdata[N][15:0]` for all 8 beats |
| INCR8 Byte | `0x0280` | `000000C0, 000000C1, 000000C2, 000000C3, 000000C4, 000000C5, 000000C6, 000000C7` | `s_rdata[N][7:0] == s_wdata[N][7:0]` for all 8 beats |
| INCR16 Word | `0x0300` | `C0000000, C0000100, C0000200, C0000300, C0000400, C0000500, C0000600, C0000700, C0000800, C0000900, C0000A00, C0000B00, C0000C00, C0000D00, C0000E00, C0000F00` | `s_rdata[N] == s_wdata[N]` for all 16 beats |
| INCR16 Halfword | `0x0380` | `0000D000, 0000D010, 0000D020, 0000D030, 0000D040, 0000D050, 0000D060, 0000D070, 0000D080, 0000D090, 0000D0A0, 0000D0B0, 0000D0C0, 0000D0D0, 0000D0E0, 0000D0F0` | `s_rdata[N][15:0] == s_wdata[N][15:0]` for all 16 beats |
| INCR16 Byte | `0x0400` | `000000E0, 000000E1, 000000E2, 000000E3, 000000E4, 000000E5, 000000E6, 000000E7, 000000E8, 000000E9, 000000EA, 000000EB, 000000EC, 000000ED, 000000EE, 000000EF` | `s_rdata[N][7:0] == s_wdata[N][7:0]` for all 16 beats |

---

## Phase 3: Wrapping Bursts

| Scenario | Address | Stimulus  | Expected Result |
|----------|---------|--------------------------|-----------------|
| WRAP4 Word | `0x0808` | `44440000, 44440001, 44440002, 44440003` | `s_rdata[N] == s_wdata[N]` for all 4 beats |
| WRAP4 Halfword | `0x0826` | `00004420, 00004421, 00004422, 00004423` | `s_rdata[N][15:0] == s_wdata[N][15:0]` for all 4 beats |
| WRAP4 Byte | `0x0843` | `00000040, 00000041, 00000042, 00000043` | `s_rdata[N][7:0] == s_wdata[N][7:0]` for all 4 beats |
| WRAP8 Word | `0x0918` | `88880000, 88880001, 88880002, 88880003, 88880004, 88880005, 88880006, 88880007` | `s_rdata[N] == s_wdata[N]` for all 8 beats |
| WRAP8 Halfword | `0x092E` | `00008820, 00008821, 00008822, 00008823, 00008824, 00008825, 00008826, 00008827` | `s_rdata[N][15:0] == s_wdata[N][15:0]` for all 8 beats |
| WRAP8 Byte | `0x0947` | `00000080, 00000081, 00000082, 00000083, 00000084, 00000085, 00000086, 00000087` | `s_rdata[N][7:0] == s_wdata[N][7:0]` for all 8 beats |

---

## Phase 4: Wait State Tests

| Scenario | Address | Stimulus | Expected Result |
|----------|----------|----------|-----------------|
| Word write/read | `0x0A00` with 3-cycle wait | `HWDATA = 32'hCAFEBABE`, `HSIZE = 3'b010`, `HREADYOUT = 0` for 3 cycles | Transaction completes; `s_rdata == 32'hCAFEBABE` |
| Halfword write/read| `0x0A04` with 3-cycle wait | `HWDATA = 32'h0000BABE`, `HSIZE = 3'b001`, `HREADYOUT = 0` for 3 cycles | Transaction completes; `s_rdata[15:0] == 16'hBABE` |
| Byte write/read | `0x0A08` with 3-cycle wait | `HWDATA = 32'h000000BE`, `HSIZE = 3'b000`, `HREADYOUT = 0` for 3 cycles | Transaction completes; `s_rdata[7:0] == 8'hBE` |

---

## Phase 5: Back-to-Back Transfers

| Scenario | Address | Stimulus | Expected Result |
|----------|----------|----------|-----------------|
| NONSEQ Beat 1 write/read | `0x0B00` | `HWDATA = 32'hAAAA1111`, `HTRANS = NONSEQ`, no IDLE gap | `s_rdata == 32'hAAAA1111` |
| NONSEQ Beat 2 write/read | `0x0B04` | `HWDATA = 32'hBBBB2222`, `HTRANS = NONSEQ`, no IDLE gap | `s_rdata == 32'hBBBB2222` |

---

## Phase 6: 2-Cycle Error Response Test

| Scenario | Address | Stimulus | Expected Result |
|----------|----------|----------|-----------------|
| Unaligned Word write | `0x0A01` | `HWDATA = 32'hDEADDEAD`, `HSIZE = 3'b010` (unaligned address) | `HRESP = 1` on cycle 1 with `HREADYOUT = 0`; `HRESP = 1` on cycle 2 with `HREADYOUT = 1` |

---

## Phase 7: Protection Fault Injection

| HPROT | Expected Result |
|----------|--------------|
| `4'b0001`##1 `4'b0011` | `HRESP = 1` |

## Phase 8: Random Testing

All the above (directed) tests will be conducted with random data values and random starting addresses.
