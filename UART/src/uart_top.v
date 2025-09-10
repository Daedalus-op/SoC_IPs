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

module uart_top #(
    parameter integer BUS_WIDTH     = 32, // number of data bits in a word
              // integer FIFO_DEPTH    = 4,
                      FIFO_DEPTH    = 2,
                      BASE_MMR_ADDRESS  = 32'h0000_0000
) (
    // uart ports
    input                        rx,
    output                       tx,

    output                       interrupt,

    // APB ports
    input                        PCLK,
    input                        PRESETn, // System bus equivalent Reset

    input      [BUS_WIDTH - 1:0] PADDR,   // Address
    input                        PSELx,   // Select
    input                        PENABLE, // Enable
    input                        PWRITE,  // Direction
    input      [BUS_WIDTH - 1:0] PWDATA,  // Write data
    input                 [ 3:0] PSTRB,   // Write strobes

    output                       PREADY,  // Slave interface Ready
    output     [BUS_WIDTH - 1:0] PRDATA,  // Slave interface Read Data
    output                       PSLVERR, // Slave interface Transfer error

    output                       probe_tick,
    output                       probe_busy,
    output     [BUS_WIDTH - 1:0] probe_baud
);
    // Connection Signals
        wire       tick;            // sample tick from baud rate generator
        wire       settings_resetn;  // reset blocks after changing settings
        wire       tx_data_lock;
        wire       tx_free;
        wire       tx_start;
        wire       rx_done_tick;    // data word received
        wire       tx_done_tick;    // data transmission complete
        wire [7:0] rx_data_in;
        wire [7:0] tx_data;
        wire [1:0] PARITY_MODE, STOP_BITS;
        wire [31:0] BAUD;
        wire PARITY_ERROR, FRAME_ERROR, BREAK_ERROR;
        wire TX_REG_FREE;

    uart_master #(
        .BUS_WIDTH(BUS_WIDTH),
        .BASE_MMR_ADDRESS(BASE_MMR_ADDRESS)
    ) UART_MASTER (
        .clk(PCLK),
        .resetn(PRESETn),

        // apb bus ports
        .PADDR(PADDR),     // Address
        .PSELx(PSELx),     // Select
        .PENABLE(PENABLE), // Enable
        .PWRITE(PWRITE),   // Direction
        .PWDATA(PWDATA),   // Write data
        .PSTRB(PSTRB),     // Write strobes

        .PREADY(PREADY),   // Slave interface Ready
        .PRDATA(PRDATA),   // Slave interface Read Data
        .PSLVERR(PSLVERR), // Slave interface transfer error

        .TX_DATA(tx_data),
        .RX_DATA(rx_data_in),

        // protocol settings
        .BAUD(BAUD),
        .PARITY_MODE(PARITY_MODE),
        .STOP_BITS(STOP_BITS),

        // status signals
        .TX_DONE(tx_done_tick),
        .TX_FREE(tx_free),
        .RX_DONE(rx_done_tick),

        // interrupt signals
        .PARITY_ERROR(PARITY_ERROR),
        .FRAME_ERROR(FRAME_ERROR),
        // .OVERRUN_ERROR(rx_done_tick & rx_fifo_full),
        .BREAK_ERROR(BREAK_ERROR),
        .interrupt(interrupt),

        .settings_resetn(settings_resetn),
        .tx_start(tx_start),
        .tx_data_lock(tx_data_lock),
        .TX_REG_FREE(TX_REG_FREE)
    );

    baud_rate_generator #( // baud tick generator
    ) BAUD_RATE_GEN (
        .clk(PCLK),
        .resetn(PRESETn & settings_resetn),
        .baud_rate(BAUD),
        .tick(tick)
    );

    uart_receiver #(
    ) UART_RX_UNIT (
        .clk(PCLK),
        .resetn(PRESETn),
        .rx(rx),
        .sample_tick(tick),
        .PARITY_MODE(PARITY_MODE),
        .STOP_BITS(STOP_BITS),
        .PARITY_ERROR(PARITY_ERROR),
        .FRAME_ERROR(FRAME_ERROR),
        .BREAK_ERROR(BREAK_ERROR),
        .data_ready(rx_done_tick),
        .data_out(rx_data_in)
    );

    uart_transmitter #(
    ) UART_TX_UNIT (
        .clk(PCLK),
        .resetn(PRESETn),
        .tx_start(tx_start),
        .sample_tick(tick),
        .PARITY_MODE(PARITY_MODE),
        .STOP_BITS(STOP_BITS),
        .TX_FREE(tx_free),
        .data_in(tx_data),
        .tx_done(tx_done_tick),
        .tx(tx)
    );

    assign probe_baud = BAUD;
    assign probe_tick = tick;

endmodule
