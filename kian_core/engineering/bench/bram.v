/*
 *  kianv.v - a simple RISC-V rv32i
 *
 *  copyright (c) 2022 hirosh dabui <hirosh@dabui.de>
 *
 *  permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  the software is provided "as is" and the author disclaims all warranties
 *  with regard to this software including all implied warranties of
 *  merchantability and fitness. in no event shall the author be liable for
 *  any special, direct, indirect, or consequential damages or any damages
 *  whatsoever resulting from loss of use, data or profits, whether in an
 *  action of contract, negligence or other tortious action, arising out of
 *  or in connection with the use or performance of this software.
 *
 */
`default_nettype none

module ram
(
    input wire clk,
    input wire [31:0] addr,
    input wire [31:0] wdata,
    output reg [31:0] rdata,
    input wire [3:0]  wmask,
    input wire        sim_done,
    input wire [63:0] counter
);

  localparam integer MEM_DEPTH = 30000; // (1 << 32);
  reg [31:0] memI[0:MEM_DEPTH-1];
  reg [31:0] memD[0:MEM_DEPTH-1];

  reg [8*256-1:0] firmware_file = "/home/xubundadu/Desktop/Cores/kian_core/engineering/bench/my.hex";
  reg [8*256-1:0] signature_file = "/home/xubundadu/Desktop/Cores/kian_core/engineering/bench/my_sig.signature";
  reg [63:0] timeout;
  integer sig_start = 'h80006110;
  integer sig_end  = 'h80006a50;
  integer i;
  integer sfd;

  wire time_exceed;
  assign time_exceed = (rdata == 'hdeadbeef);
  // assign time_exceed = (counter >= (timeout - 'd10));

  initial begin
    forever begin
      @(posedge clk) 
    end

  initial begin
    if (!$value$plusargs("firmware=%s", firmware_file)) begin
      $display("Error: firmware file argument missing");
      // $finish;
    end
    if (!$value$plusargs("signature=%s", signature_file)) begin
      $display("Error: signature file argument missing");
      // $finish;
    end
    if (!$value$plusargs("sig_start=%h", sig_start)) begin
      $display("Error: sig_start argument missing");
      // $finish;
    end
    if (!$value$plusargs("sig_end=%h", sig_end)) begin
      $display("Error: sig_end argument missing");
      // $finish;
    end
    if (!$value$plusargs("timeout_cycles=%d", timeout)) begin
      $display("Warning: timeout argument missing");
      timeout = 10000; // Default timeout if not provided
    end

    $readmemh(firmware_file, memI);

    @(posedge sim_done, posedge time_exceed);
    $display("DONE: wfi_event detected, test finished instruction:- %h", rdata);
    sfd = $fopen(signature_file, "w");
    for (i = sig_start/4; i < sig_end/4; i = i + 4)
        $fdisplay(sfd, "%08x", memI[i]);
    $fclose(sfd);
    $finish;
  end

  always @(posedge clk) begin
    if (addr <= MEM_DEPTH) begin
      if (wmask[0]) memI[addr][ 7: 0] <= wdata[7:0];
      if (wmask[1]) memI[addr][15: 8] <= wdata[15:8];
      if (wmask[2]) memI[addr][23:16] <= wdata[23:16];
      if (wmask[3]) memI[addr][31:24] <= wdata[31:24];
      // if (wmask == 'hf) $display("writing data into memI %0h, %0h to %0h", memI[addr], wdata, addr);
      // if (wmask == 'h0 && rdata != 'h0) $display("reading data into memI %0h, %0h to %0h", memI[addr], rdata, addr);
    end
    else if (addr > 32'h80000000) begin
      if (wmask[0]) memD[addr][ 7: 0] <= wdata[7:0];
      if (wmask[1]) memD[addr][15: 8] <= wdata[15:8];
      if (wmask[2]) memD[addr][23:16] <= wdata[23:16];
      if (wmask[3]) memD[addr][31:24] <= wdata[31:24];
      // if (wmask == 'hf) $display("memD writing data %0h, %0h to %0h", memD[addr], wdata, addr);
    end
    // else
      // if (wmask == 'hf) $display("writing data %0h, %0h to %0h", memD[addr], wdata, addr);

  end

  always @(*) begin
    if (addr < MEM_DEPTH)
      rdata = memI[addr];
    else if (addr > MEM_DEPTH + 32'h80000000)
      rdata = memD[addr];
    else 
      rdata = 32'd0;
  end

endmodule
