// UART Receiver for the UART System

module uart_receiver #(
    parameter PARITY_MODE = 0,
              STOP_BITS = 1
) (
    input                  clk,
    input                  resetn,
    input                  rx,           // receiver data line
    input                  sample_tick,  // sample tick from baud rate generator
    output reg             data_ready,
    output           [7:0] data_out
    // output wire debug_start, debug_stop, divs
);
    wire PARITY_ENABLE = (PARITY_MODE == 2'd1 || PARITY_MODE == 2'd2);

    // State Machine States
        localparam [1:0] idle = 2'b00, start = 2'b01, data = 2'b10, stop = 2'b11;

    // Registers
        reg [1:0] state, next_state;  // state registers
        reg [1:0] tick_reg, tick_next;  // number of ticks received from baud rate generator
        reg [3:0] nbits_reg, nbits_next;  // number of bits received in data state
        reg [8:0] data_reg, data_next;  // reassembled data word

        // assign debug_start = state == start;
        // assign debug_stop  = state == stop;
        // assign divs = tick_reg == 2'd3;

    // Register Logic
        always @(posedge clk, negedge resetn)
            if (!resetn) begin
                state <= idle;
                tick_reg <= 0;
                nbits_reg <= 0;
                data_reg <= 0;
            end else begin
                state <= next_state;
                tick_reg <= tick_next;
                nbits_reg <= nbits_next;
                data_reg <= data_next;
            end

    // State Machine Logic
        always @(*) begin
            next_state  = state;
            data_ready  = 1'b0;
            tick_next   = tick_reg;
            nbits_next  = nbits_reg;
            data_next   = data_reg;

            case (state)
                idle:
                if (~rx) begin  // when data line goes LOW (start condition)
                    next_state = start;
                    tick_next  = 0;
                end
                start:
                if (sample_tick) begin
                    // if (tick_reg == 2'd1) begin
                        next_state = data;
                        data_next  = 9'd0;
                        tick_next  = 0;
                        nbits_next = 0;
                    // end else tick_next = tick_reg + 1;
                end
                data:
                if (sample_tick)
                    if (tick_reg == 2'd3) begin
                        tick_next = 0;
                        data_next = (PARITY_ENABLE)? {rx, data_reg[8:1]} : {1'b0, rx, data_reg[7:1]};

                        if (PARITY_ENABLE && nbits_reg == 4'd8) next_state = stop;
                        else if (!PARITY_ENABLE && nbits_reg == 4'd7) next_state = stop;
                        else nbits_next = nbits_reg + 1;

                    end else tick_next = tick_reg + 1;
                stop:
                if (sample_tick)
                    if (tick_reg == 2'd1) begin
                        tick_next = 0;


                        if (nbits_reg == (4'd7 + {2'b0, { 1'b0, PARITY_ENABLE} + STOP_BITS })) begin
                            next_state = idle;
                            data_ready = 1'b1;
                        end
                        else nbits_next = nbits_reg + 1;

                    end else tick_next = tick_reg + 1;
            endcase
        end
    
    // Output Logic
        assign data_out = data_reg[7:0];

endmodule
