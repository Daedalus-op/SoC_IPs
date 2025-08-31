// UART Transmitter for the UART System

module uart_transmitter (
    input                  clk,   // basys 3 FPGA
    input                  resetn,        // resetn
    input                  tx_start,     // begin data transmission (FIFO NOT empty)
    input                  sample_tick,  // from baud rate generator
    input            [1:0] PARITY_MODE,
    input            [1:0] STOP_BITS,
    input            [7:0] data_in,      // data word from FIFO
    output reg             tx_done,      // end of transmission
    output                 tx            // transmitter data line
);

    // State Machine States
        localparam [1:0] idle = 2'b00, start = 2'b01, data = 2'b10, stop = 2'b11;

    // Registers
        reg [1:0] state, next_state;  // state registers
        reg [1:0] tick_reg, tick_next;  // number of ticks received from baud rate generator
        reg [2:0] nbits_reg, nbits_next;  // number of bits transmitted in data state
        reg [8:0] data_reg, data_next;  // assembled data word to transmit serially
        reg tx_reg, tx_next;  // data filter for potential glitches

    // Parity concat for tx
        wire PARITY_ENABLE = (PARITY_MODE == 2'd1 || PARITY_MODE == 2'd2);
        wire parity_ref = (!PARITY_ENABLE)? 0 : (PARITY_MODE == 2'd1)? ~(^data_in) : (^data_in);

    // Register Logic
    always @(posedge clk, negedge resetn)
        if (!resetn) begin
            state <= idle;
            tick_reg <= 0;
            nbits_reg <= 0;
            data_reg <= 0;
            tx_reg <= 1'b1;
        end else begin
            state <= next_state;
            tick_reg <= tick_next;
            nbits_reg <= nbits_next;
            data_reg <= data_next;
            tx_reg <= tx_next;
        end

    // State Machine Logic
        always @* begin
            next_state = state;
            tx_done = 1'b0;
            tick_next = tick_reg;
            nbits_next = nbits_reg;
            data_next = data_reg;
            tx_next = tx_reg;

            case (state)
                idle: begin  // no data in FIFO
                    tx_next = 1'b1;  // transmit idle
                    if (tx_start) begin  // when FIFO is NOT empty
                        next_state = start;
                        tick_next    = 0;
                        data_next    = {parity_ref, data_in};
                    end
                end

                start: begin
                    tx_next = 1'b0;  // start bit
                    if (sample_tick)
                        if (tick_reg == 3) begin
                            next_state = data;
                            tick_next    = 0;
                            nbits_next = 0;
                        end else tick_next = tick_reg + 1;
                end

                data: begin
                    tx_next = data_reg[0];
                    if (sample_tick)
                        if (tick_reg == 3) begin
                            tick_next = 0;
                            data_next = data_reg >> 1;

                            if (PARITY_ENABLE && nbits_reg == 8) next_state = stop;
                            else if (!PARITY_ENABLE && nbits_reg == 7) next_state = stop;
                            else nbits_next = nbits_reg + 1;

                        end else tick_next = tick_reg + 1;
                end

                stop: begin
                    tx_next = 1'b1;  // back to idle
                    if (sample_tick)
                        if (tick_reg == 3) begin
                            tick_next = 0;

                            if (nbits_reg == (3'd7 + {1'b0, { 1'b0, PARITY_ENABLE} + STOP_BITS })) begin
                                next_state = idle;
                                tx_done = 1'b1;
                            end
                            else nbits_next = nbits_reg + 1;

                        end else tick_next = tick_reg + 1;
                end
            endcase
        end
        
    // Output Logic
        assign tx = tx_reg;

endmodule
