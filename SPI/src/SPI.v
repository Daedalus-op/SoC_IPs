`timescale 1ns/1ps
`default_nettype none

module spi_apb #(
    parameter CPOL = 1'b0,
    parameter CLK_DIV = 18'd2
)(
    // --- APB Slave Interface ---
    input  wire        PCLK,
    input  wire        PRESETn,
    input  wire [7:0]  PADDR,
    input  wire        PSEL,
    input  wire        PENABLE,
    input  wire        PWRITE,
    input  wire [3:0]  PSTRB,
    input  wire [31:0] PWDATA,
    output reg  [31:0] PRDATA,
    output wire        PREADY,

    // --- SPI Interface ---
    output wire        sclk,
    output wire        mosi,
    input  wire        miso,
    output wire        cs_n
);

    // ------------------------------------------------------------------------
    //  APB Register Addresses
    // ------------------------------------------------------------------------
    localparam ADDR_TXDATA = 8'h00;
    localparam ADDR_RXDATA = 8'h04;
    localparam ADDR_STATUS = 8'h08;

    // APB Ready always 1
    assign PREADY = 1'b1;

    // Internal registers
    reg [7:0]  tx_data;
    reg [7:0]  rx_data;
    reg [2:0]  bit_cnt;
    reg [7:0]  spi_buf;
    reg [17:0] clk_div_cnt;
    reg        sclk_reg;
    reg        spi_cen;
    reg [1:0]  state;
    reg        transfer_done;

    // FSM states
    localparam S_IDLE  = 2'd0;
    localparam S_LOAD  = 2'd1;
    localparam S_SHIFT = 2'd2;

    // ------------------------------------------------------------------------
    //  APB Write Logic
    // ------------------------------------------------------------------------
    wire write_en = PSEL & PENABLE & PWRITE;
    wire read_en  = PSEL & PENABLE & ~PWRITE;

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            tx_data <= 8'd0;
        else if (write_en && PADDR == ADDR_TXDATA)
            tx_data <= PWDATA[7:0];
    end

    // ------------------------------------------------------------------------
    //  APB Read Logic (COMBINATIONAL)
    // ------------------------------------------------------------------------
    always @(*) begin
        case (PADDR)
            ADDR_RXDATA: PRDATA = {24'd0, rx_data};
            ADDR_STATUS: PRDATA = {31'd0, transfer_done};
            default:     PRDATA = 32'd0;
        endcase
    end

    // ------------------------------------------------------------------------
    //  SPI Master FSM
    // ------------------------------------------------------------------------
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            sclk_reg      <= CPOL;
            spi_cen       <= 1'b1;
            bit_cnt       <= 3'd7;
            clk_div_cnt   <= 18'd0;
            state         <= S_IDLE;
            transfer_done <= 1'b0;
            spi_buf       <= 8'd0;
            rx_data       <= 8'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    transfer_done <= 1'b0;
                    if (write_en && PADDR == ADDR_TXDATA) begin
                        spi_buf     <= tx_data;
                        spi_cen     <= 1'b0;
                        bit_cnt     <= 3'd7;
                        clk_div_cnt <= 18'd0;
                        sclk_reg    <= CPOL;
                        state       <= S_LOAD;
                    end
                end

                S_LOAD: begin
                    clk_div_cnt <= clk_div_cnt + 1'b1;
                    if (clk_div_cnt == CLK_DIV) begin
                        clk_div_cnt <= 0;
                        state <= S_SHIFT;
                    end
                end

                S_SHIFT: begin
                    clk_div_cnt <= clk_div_cnt + 1'b1;
                    if (clk_div_cnt == CLK_DIV) begin
                        clk_div_cnt <= 0;
                        sclk_reg <= ~sclk_reg;

                        // sample and shift on falling edge
                        if (sclk_reg == ~CPOL) begin
                            spi_buf <= {spi_buf[6:0], 1'b0};
                            bit_cnt <= bit_cnt - 1'b1;

                            if (bit_cnt == 1) begin
                                rx_data <= {spi_buf[6:0], miso};
                                sclk_reg <= CPOL;
                                spi_cen  <= 1'b1;
                                transfer_done <= 1'b1;
                                state <= S_IDLE;
                            end
                        end
                    end
                end
            endcase
        end
    end

    // ------------------------------------------------------------------------
    //  Outputs
    // ------------------------------------------------------------------------
    assign sclk = sclk_reg;
    assign mosi = spi_buf[7];
    assign cs_n = spi_cen;

endmodule
`default_nettype wire
