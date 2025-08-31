// Baud Rate Generator for the UART System

module baud_rate_generator (
    input         clk,
    input         reset,
    input  [31:0] baud_rate,   // counter limit value
    output        tick         // sample tick
);

  // Counter Register
  reg  [31:0] counter;  // counter value
  wire [31:0] next;  // next counter value

  // Register Logic
  always @(posedge clk, posedge reset)
    if (reset) counter <= 0;
    else counter <= next;

  // Next Counter Value Logic
  assign next = (counter == (baud_rate - 1)) ? 0 : counter + 1;

  // Output Logic
  assign tick = (counter == (baud_rate - 1)) ? 1'b1 : 1'b0;

endmodule
