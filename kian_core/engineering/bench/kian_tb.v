`default_nettype none
module kian_tb;

   reg clk = 1'b0;
   reg rstn = 1'b0;

   always  #5 clk <= !clk;
   initial #10 rstn = 1'b1;

   kian_sim dut (
      .clk (clk),
      .resetn (rstn)
   );

endmodule
