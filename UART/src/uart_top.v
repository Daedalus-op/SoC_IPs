`include "uart_settings.vh"

//////////////////////////////////////////////////////////////////////////////////
//
// TODO: Synchronise FIFOs
//
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
              integer FIFO_DEPTH    = 4,
                      BASE_MMR_ADDRESS  = 32'h0000_0000,
                      BASE_DMA_ADDRESS  = 32'h1000_0000
) (
    // uart ports
    input                        rx,
    output                       tx,

    output                       interrupt,

    // dma ports
    `ifdef DMA_SUPPORT
    input  [BUS_WIDTH - 1:0] dma_read_port,
    output [BUS_WIDTH - 1:0] dma_write_port,
    `endif

    // APB ports
    input                        PCLK,
    input                        PRESETn, // System bus equivalent Reset

    input      [BUS_WIDTH - 1:0] PADDR,   // Address
    // input                        PPROT,   // Protection type
    input                        PSELx,   // Select
    input                        PENABLE, // Enable
    input                        PWRITE,  // Direction
    input      [BUS_WIDTH - 1:0] PWDATA,  // Write data
    input                        PSTRB,   // Write strobes

    output                       PREADY,  // Slave interface Ready
    output     [BUS_WIDTH - 1:0] PRDATA,  // Slave interface Read Data
    output                       PSLVERR // Slave interface Transfer error
);

    // Connection Signals
    wire       tick;            // sample tick from baud rate generator
    wire       rx_done_tick;    // data word received
    wire       tx_done_tick;    // data transmission complete
    wire       tx_fifo_full, tx_fifo_empty;
    wire       rx_fifo_full, rx_fifo_empty;
    wire       rx_fifo_read_en, tx_fifo_write_en;
    wire [7:0] tx_data_out, tx_fifo_in;
    wire [7:0] rx_data_in, rx_fifo_out;
    wire [1:0] PARITY_MODE, STOP_BITS;
    wire [31:0] BAUD;
    wire PARITY_ERROR, FRAME_ERROR, BREAK_ERROR;

    uart_master #(
        .BUS_WIDTH(BUS_WIDTH),
        .BASE_MMR_ADDRESS(BASE_MMR_ADDRESS),
        .BASE_DMA_ADDRESS(BASE_DMA_ADDRESS)
    ) UART_MASTER (
        .clk(PCLK),
        .resetn(PRESETn),

        // apb bus ports
        .PADDR(PADDR),     // Address
        // .PPROT(PPROT),     // Protection type //  TODO: pprot required?
        .PSELx(PSELx),     // Select
        .PENABLE(PENABLE), // Enable
        .PWRITE(PWRITE),   // Direction
        .PWDATA(PWDATA),   // Write data
        .PSTRB(PSTRB),     // Write strobes

        .PREADY(PREADY),   // Slave interface Ready
        .PRDATA(PRDATA),   // Slave interface Read Data
        .PSLVERR(PSLVERR), // Slave interface transfer error

        `ifdef DMA_SUPPORT
        .dma_tx_data(dma_read_port),
        .dma_rx_data(dma_write_port),
        `endif

        .TX_DATA(tx_fifo_in),
        .RX_DATA(rx_fifo_out),

        // protocol settings
        .BAUD(BAUD),
        .PARITY_MODE(PARITY_MODE),
        .STOP_BITS(STOP_BITS),

        // status signals
        .TX_DONE(tx_done_tick),
        .TX_NOTFULL(!tx_fifo_full),
        .RX_NOTFULL(!rx_fifo_full),
        .RX_NOTEMPTY(!rx_fifo_empty),

        // interrupt signals
        .PARITY_ERROR(PARITY_ERROR),
        .FRAME_ERROR(FRAME_ERROR),
        .OVERRUN_ERROR(rx_done_tick & rx_fifo_full),
        .BREAK_ERROR(BREAK_ERROR),
        .interrupt(interrupt),

        // read & write to fifo
        .tx_fifo_write_en(tx_fifo_write_en),
        .rx_fifo_read_en(rx_fifo_read_en)
    );

    baud_rate_generator #( // baud tick generator
    ) BAUD_RATE_GEN (
        .clk(PCLK),
        .reset(PRESETn),
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

    fifo #(
        .ADDR_SPACE_EXP(FIFO_DEPTH),  // number of address bits (2^4 = 16 addresses)
        .DATA_SIZE(8)
    ) RX_FIFO (
        .clk(tick),
        .reset(PRESETn),
        .write_to_fifo(rx_done_tick),   // signal start writing to FIFO
        .read_from_fifo(rx_fifo_read_en),  // signal start reading from FIFO
        .write_data_in(rx_data_in),   // data word into FIFO
        .read_data_out(rx_fifo_out),   // data word out of FIFO
        .empty(rx_fifo_empty),           // FIFO is empty (no read)
        .full(rx_fifo_full)             // FIFO is full (no write)
    );

    fifo #(
        .ADDR_SPACE_EXP(FIFO_DEPTH),  // number of address bits (2^4 = 16 addresses)
        .DATA_SIZE(8)
    ) TX_FIFO (
        .clk(tick),
        .reset(PRESETn),
        .write_to_fifo(tx_fifo_write_en),   // signal start writing to FIFO
        .read_from_fifo(tx_done_tick),  // signal start reading from FIFO
        .write_data_in(tx_fifo_in),   // data word into FIFO
        .read_data_out(tx_data_out),   // data word out of FIFO
        .empty(tx_fifo_empty),           // FIFO is empty (no read)
        .full(tx_fifo_full)             // FIFO is full (no write)
    );

    uart_transmitter #(
    ) UART_TX_UNIT (
        .clk(PCLK),
        .resetn(PRESETn),
        .tx_start(!tx_fifo_empty),
        .sample_tick(tick),
        .PARITY_MODE(PARITY_MODE),
        .STOP_BITS(STOP_BITS),
        .data_in(tx_data_out),
        .tx_done(tx_done_tick),
        .tx(tx)
    );

endmodule
