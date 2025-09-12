`include "uart_settings.vh"

//////////////////////////////////////////////////////////////////////////////////
// Top Module for the Complete UART System
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
//
// NOTE:
// Use this as the escape sequence to clear screen using UART: `\033[2J\033[H`
// or `0x1B 0x5B 0x32 0x4A 0x1B 0x5B 0x48`
//
//////////////////////////////////////////////////////////////////////////////////

module apb_uart_top #(
    parameter integer DATA_WIDTH     = 32, // number of data bits in a word
                      ADDR_WIDTH    = 32,
                      PARITY_MODE   = 0,
                      STOP_BITS     = 1,
                      BAUD          = 9600,
                      CLK_FREQ      = 100_000_000, // 100 MHz
                      BASE_MMR_ADDRESS  = 32'h0000_0000
) (
    output                        probe_tick,

    // uart ports
    input                         rx,
    output                        tx,

    // APB ports
    input                         PCLK,
    input                         PRESETn, // System bus equivalent Reset

    input      [ADDR_WIDTH - 1:0] PADDR,   // Address
    input                         PSELx,   // Select
    input                         PENABLE, // Enable
    input                         PWRITE,  // Direction
    input      [DATA_WIDTH - 1:0] PWDATA,  // Write data
    input                  [ 3:0] PSTRB,   // Write strobes

    output                        PREADY,  // Slave interface Ready
    output reg [DATA_WIDTH - 1:0] PRDATA,  // Slave interface Read Data
    output                        PSLVERR  // Slave interface Transfer error
);

    localparam BAUD_COUNT = CLK_FREQ / (BAUD * 4);
    // Connection Signals
        wire       tick;            // sample tick from baud rate generator
        wire       rx_done_tick;    // data word received
        wire       tx_done_tick;    // data transmission complete
        wire [7:0] RX_DATA;
        wire [7:0] TX_DATA;

        reg        tx_data_lock, tx_start, tx_start_next;

    baud_rate_generator #( // baud tick generator
        .BAUD_COUNT(BAUD_COUNT)
    ) BAUD_RATE_GEN (
        .clk(PCLK),
        .resetn(PRESETn),
        .tick(tick)
    );

    uart_receiver #(
        .PARITY_MODE(PARITY_MODE),
        .STOP_BITS(STOP_BITS)
    ) UART_RX_UNIT (
        .clk(PCLK),
        .resetn(PRESETn),
        .rx(rx),
        .sample_tick(tick),
        .data_ready(rx_done_tick),
        .data_out(RX_DATA)
    );

    uart_transmitter #(
        .PARITY_MODE(PARITY_MODE),
        .STOP_BITS(STOP_BITS)
    ) UART_TX_UNIT (
        .clk(PCLK),
        .resetn(PRESETn),
        .tx_start(tx_start),
        .sample_tick(tick),
        .data_in(TX_DATA),
        .tx_done(tx_done_tick),
        .tx(tx)
    );

    // mmr logic
        reg  [DATA_WIDTH - 1:0] tx_data_reg;
        reg  [DATA_WIDTH - 1:0] rx_data_reg, rx_data_next;

        reg new_tx_data;

        assign PREADY = PENABLE;

        assign PSLVERR = PENABLE && PWRITE && (PADDR == (BASE_MMR_ADDRESS + 'h00)) && tx_data_lock;
        // asynchronous reseting and Writing Registers
            always@(posedge PCLK, negedge PRESETn) begin
                new_tx_data = 0;

                // register read and write
                    if (!PRESETn) begin // reset register to default values
                        tx_data_reg  <= 'h0;
                    end
                    else if (PREADY) begin
                        if (PWRITE && (PADDR == (BASE_MMR_ADDRESS + 'h00)) && !tx_data_lock) begin
                            new_tx_data = 1;
                            tx_data_reg <= PWDATA;
                        end
                        else if (!PWRITE && (PADDR == (BASE_MMR_ADDRESS + 'h04))) begin
                            PRDATA = rx_data_reg;
                        end
                    end
            end

    // data capture from bus for tx
        reg tx_state, tx_state_next;
        localparam TX_IDLE = 0, TX_SEND_DATA = 1; // states for data fetch

        reg tx_data_lock_next;

        assign TX_DATA      = (tx_state == TX_IDLE)? 8'h00 : tx_data_reg[7:0];
        // Register Logic
            always @(posedge PCLK, negedge PRESETn) begin
                if (!PRESETn) begin
                    tx_state  <= TX_IDLE;
                    tx_data_lock <= 0;
                    tx_start <= 0;
                end else begin
                    tx_state  <= tx_state_next;
                    tx_data_lock <= tx_data_lock_next;
                    tx_start <= tx_start_next;
                end
            end

        // tx state logic
            always @(*) begin
                tx_state_next  = tx_state;
                tx_data_lock_next = tx_data_lock;
                tx_start_next = 0;

                case (tx_state)
                    TX_IDLE: begin
                        tx_start_next = 0;
                        tx_data_lock_next = 1'b0;
                        if (new_tx_data) begin
                            tx_start_next = 1;
                            tx_state_next  = TX_SEND_DATA;
                        end
                    end
                    TX_SEND_DATA: begin
                        tx_data_lock_next = 1'b1;
                        if (tx_done_tick) begin
                            tx_data_lock_next = 1'b0;
                            tx_state_next = TX_IDLE;
                        end
                    end
                    default: begin
                        tx_state_next = TX_IDLE;
                    end
                endcase
            end

    // write to bus from rx

        localparam RX_IDLE = 0, RX_SEND_DATA = 1; // states for data fetch

        reg rx_state, rx_state_next;

        // Register Logic
            always @(posedge PCLK, negedge PRESETn) begin
                if (!PRESETn) begin
                    rx_state <= RX_IDLE;
                    rx_data_reg <= 'd0;
                end else begin
                    rx_state <= rx_state_next;
                    rx_data_reg <= rx_data_next;
                end
            end

        // rx state logic
            always @(*) begin
                rx_state_next  = rx_state;
                rx_data_next   = rx_data_reg;

                case (rx_state)
                    RX_IDLE: begin
                        if (rx_done_tick) begin
                            rx_state_next = RX_SEND_DATA;
                        end
                    end
                    RX_SEND_DATA: begin
                        rx_data_next = {{(DATA_WIDTH - 8){1'b0}}, RX_DATA};
                        rx_state_next = RX_IDLE;
                    end
                    default: begin
                        rx_state_next = RX_IDLE;
                    end
                endcase
            end

    assign probe_tick = tick;
endmodule
