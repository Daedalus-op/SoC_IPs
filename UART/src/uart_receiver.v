// UART Receiver for the UART System

module uart_receiver (
    input                  clk,
    input                  resetn,
    input                  rx,           // receiver data line
    input                  sample_tick,  // sample tick from baud rate generator
    input            [1:0] PARITY_MODE,
    input            [1:0] STOP_BITS,
    output reg             data_ready,
    output           [7:0] data_out,
    output                 PARITY_ERROR,
    output reg             FRAME_ERROR,
    output reg             BREAK_ERROR
);
    wire PARITY_ENABLE = (PARITY_MODE == 2'd1 || PARITY_MODE == 2'd2);

    // State Machine States
        localparam [1:0] idle = 2'b00, start = 2'b01, data = 2'b10, stop = 2'b11;

    // Registers
        reg [1:0] state, next_state;  // state registers
        reg [1:0] tick_reg, tick_next;  // number of ticks received from baud rate generator
        reg [2:0] nbits_reg, nbits_next;  // number of bits received in data state
        reg [8:0] data_reg, data_next;  // reassembled data word

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
            FRAME_ERROR = 1'b0;
            BREAK_ERROR = 1'b0;

            case (state)
                idle:
                if (~rx) begin  // when data line goes LOW (start condition)
                    next_state = start;
                    tick_next  = 0;
                end
                start:
                if (sample_tick) begin
                    next_state = data;
                    tick_next  = 0;
                    nbits_next = 0;
                end
                data:
                if (sample_tick)
                    if (tick_reg == 3) begin
                        tick_next = 0;
                        data_next = {rx, data_reg[7:1]};

                        if (PARITY_ENABLE && nbits_reg == 8) next_state = stop;
                        else if (!PARITY_ENABLE && nbits_reg == 7) next_state = stop;
                        else nbits_next = nbits_reg + 1;

                    end else tick_next = tick_reg + 1;
                stop:
                if (sample_tick)
                    if (tick_reg == 3) begin
                        tick_next = 0;

                        if(STOP_BITS != 0 && rx == 0) FRAME_ERROR = 1'b1;
                        if(STOP_BITS != 0 && data_reg == 0) BREAK_ERROR = 1'b1;

                        if (nbits_reg == (3'd7 + {1'b0, { 1'b0, PARITY_ENABLE} + STOP_BITS })) begin
                            next_state = idle;
                            data_ready = 1'b1;
                        end
                        else nbits_next = nbits_reg + 1;

                    end else tick_next = tick_reg + 1;
            endcase
        end
    
    // Parity check for rx
        wire parity_ref = (PARITY_MODE == 2'd0 || PARITY_MODE == 2'd3)? 0 : (PARITY_MODE == 2'd1)? ~(^data_reg[7:0]) : (^data_reg[7:0]);
        
        assign PARITY_ERROR = (PARITY_ENABLE) && (parity_ref == data_reg[8]);

    // Output Logic
        assign data_out = data_reg[7:0];

endmodule
