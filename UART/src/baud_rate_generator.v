// Baud Rate Generator for the UART System
//
// Setup for 9600 Baud Rate
//
// For 9600 baud with 100MHz FPGA clock:
// 9600 * 4 = 38,400
// 100 * 10^6 / 38,400 = ~2604 (0xA2C) (counter limit M)
//
// For 19,200 baud rate with a 100MHz FPGA clock signal:
// 19,200 * 4 = 76,800
// 100 * 10^6 / 76,800 = ~130 (0x82)   (counter limit M)

module baud_rate_generator #(
    parameter integer BAUD_COUNT = 2604
)(
    input         clk,
    input         resetn,
    output        tick         // sample tick
);

    // Counter Register
    reg  [31:0] counter;  // counter value
    wire [31:0] next;  // next counter value

    // Register Logic
    always @(posedge clk, negedge resetn)
        if (!resetn) counter <= 0;
        else counter <= next;

    // Next Counter Value Logic
    assign next = (counter == (BAUD_COUNT - 1) || !resetn) ? 0 : counter + 1;

    // Output Logic
    assign tick = (counter == (BAUD_COUNT - 1)) ? 1'b1 : 1'b0;

endmodule
