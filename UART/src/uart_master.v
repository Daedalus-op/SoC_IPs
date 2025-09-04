`include "uart_settings.vh"

module uart_master #(
    parameter integer BUS_WIDTH  = 32,
                      DMA_WIDTH  = 16,
                      BASE_MMR_ADDRESS  = 32'h0000_0000,
                      BASE_DMA_ADDRESS  = 32'h1000_0000
) (
    input                    clk,
    input                    resetn,

    // APB ports
    input      [BUS_WIDTH - 1:0] PADDR, // Address
    // input                        PPROT, // Protection type
    input                        PSELx, // Select
    input                        PENABLE, // Enable
    input                        PWRITE, // Direction
    input wire [BUS_WIDTH - 1:0] PWDATA, // Write data
    input                 [ 3:0] PSTRB, // Write strobes

    output                       PREADY, // Slave interface Ready
    output reg [BUS_WIDTH - 1:0] PRDATA, // Slave interface Read Data // NOTE: generating an rtl_rom
    output reg                   PSLVERR,

    `ifdef DMA_SUPPORT
    output                       dma_read_req;
    input                        dma_read_ack;
    input                        dma_read_clr;

    output                       dma_write_req;
    input                        dma_write_ack;
    input                        dma_write_clr;

    input      [DMA_WIDTH - 1:0] dma_read_data,
    output reg [DMA_WIDTH - 1:0] dma_write_data,

    output     [BUS_WIDTH - 1:0] dma_read_address,
    output     [BUS_WIDTH - 1:0] dma_write_address,
    `endif

    // tx/rx data signals
    output                [ 7:0] TX_DATA,
    input                 [ 7:0] RX_DATA,

    // configuration signals
    output                [31:0] BAUD,
    output                [ 1:0] PARITY_MODE, // (8N*, 8O*, 8E*) -> (0, 1, 2)
    output                [ 1:0] STOP_BITS,   // 0 - 2

    // status signals
    input                        TX_DONE,
    input                        TX_NOTFULL,
    input                        RX_NOTFULL,
    input                        RX_NOTEMPTY,
    // interrupt signals
    input                        PARITY_ERROR,
    input                        FRAME_ERROR,
    input                        OVERRUN_ERROR,
    input                        BREAK_ERROR,
    output                       interrupt,

    // read & write to fifo
    output                       tx_fifo_write_en,
    output                       rx_fifo_read_en,

    // Probes
    output                       [31:0] probe
);
    
    reg busy, new_tx_data; // TODO: check busy functionality
    assign PREADY = PENABLE & ~busy;

    assign probe = tx_data_reg;

    // Memory Mapped Registers
        // TODO: Verify functionality of each registers

        reg [31:0] baud        ;
        reg [31:0] tx_data_reg ;
        reg [31:0] rx_data_reg ;
        reg [31:0] status      ;
        reg [31:0] control     ;
        reg [31:0] status_clear;
        reg [31:0] interrupt_en;
        reg [ 3:0] strb_reg    ;

        reg BREAK_ERROR_reg  ;
        reg FRAME_ERROR_reg  ;
        reg OVERRUN_ERROR_reg;
        reg PARITY_ERROR_reg ;

        // DMA registers
            `ifdef DMA_SUPPORT
            wire dma_tx_en, dma_rx_en;
            reg [31:0] dma_tx_baddress, dma_rx_baddress, dma_tx_size, dma_rx_size;
            reg DMA_RX_DONE, DMA_TX_DONE;

            assign dma_tx_en = control[4];
            assign dma_rx_en = control[5];
            `endif

        reg [1:0] tx_state, tx_state_next;

        assign BAUD         = baud;
        assign PARITY_MODE  = control[1:0];
        assign STOP_BITS    = control[3:2];

        always@(posedge (PSELx & clk), negedge resetn) begin // asynchronous reseting and Writing Registers
            busy   = 1'b0;
            PSLVERR = 1'b0;

            // ERROR_reg logic
                if (!resetn)
                    BREAK_ERROR_reg <= 1'b0;
                else if(status_clear[3])
                    BREAK_ERROR_reg <= 1'b0;
                else if (BREAK_ERROR_reg)
                    BREAK_ERROR_reg <= 1'b1;
                else
                    BREAK_ERROR_reg <= BREAK_ERROR;

                if (!resetn)
                    FRAME_ERROR_reg <= 1'b0;
                else if(status_clear[2])
                    FRAME_ERROR_reg <= 1'b0;
                else if (FRAME_ERROR_reg)
                    FRAME_ERROR_reg <= 1'b1;
                else
                    FRAME_ERROR_reg <= FRAME_ERROR;

                if (!resetn)
                    PARITY_ERROR_reg <= 1'b0;
                else if(status_clear[0])
                    PARITY_ERROR_reg <= 1'b0;
                else if (PARITY_ERROR_reg)
                    PARITY_ERROR_reg <= 1'b1;
                else
                    PARITY_ERROR_reg <= PARITY_ERROR;

                if (!resetn)
                    OVERRUN_ERROR_reg <= 1'b0;
                else if(status_clear[1])
                    OVERRUN_ERROR_reg <= 1'b0;
                else if (OVERRUN_ERROR_reg)
                    OVERRUN_ERROR_reg <= 1'b1;
                else
                    OVERRUN_ERROR_reg <= OVERRUN_ERROR;

            `ifdef DMA_SUPPORT
                status = {22'd0, DMA_RX_DONE, DMA_TX_DONE, BREAK_ERROR_reg, FRAME_ERROR_reg, OVERRUN_ERROR_reg, PARITY_ERROR_reg,
                        TX_DONE, TX_NOTFULL, RX_NOTFULL, RX_NOTEMPTY};
            `else
                status = {24'd0, BREAK_ERROR_reg, FRAME_ERROR_reg, OVERRUN_ERROR_reg, PARITY_ERROR_reg,
                        TX_DONE, TX_NOTFULL, RX_NOTFULL, RX_NOTEMPTY};
            `endif


            if (!resetn) begin // reset register to default values
                baud         = 'ha2c;
                tx_data_reg  = 'h0;
                status       = 'h7;
                control      = 'h4;
                status_clear = 'h0;
                interrupt_en = 'h0;
                `ifdef DMA_SUPPORT
                dma_tx_baddress = 'h8000_0000;
                dma_rx_baddress = 'hc000_0000;
                `endif
                strb_reg     = 'h0;
            end
            else if (PREADY) begin
                if (PWRITE) begin // write to registers
                    case (PADDR)
                        (BASE_MMR_ADDRESS + 'h00): begin
                            if (tx_state == TX_IDLE) begin
                                strb_reg            <= PSTRB;
                                tx_data_reg[31:24]  <= (PSTRB[3])? PWDATA[31:24] : tx_data_reg[31:24];
                                tx_data_reg[23:16]  <= (PSTRB[2])? PWDATA[23:16] : tx_data_reg[23:16];
                                tx_data_reg[15:08]  <= (PSTRB[1])? PWDATA[15:08] : tx_data_reg[15:08];
                                tx_data_reg[07:00]  <= (PSTRB[0])? PWDATA[07:00] : tx_data_reg[07:00];
                                busy = 1'b0;
                            end
                            else busy = 1'b1;
                        end
                        (BASE_MMR_ADDRESS + 'h08): begin
                            baud[31:24]  <= (PSTRB[3])? PWDATA[31:24] : baud[31:24];
                            baud[23:16]  <= (PSTRB[2])? PWDATA[23:16] : baud[23:16];
                            baud[15:08]  <= (PSTRB[1])? PWDATA[15:08] : baud[15:08];
                            baud[07:00]  <= (PSTRB[0])? PWDATA[07:00] : baud[07:00];
                        end
                        (BASE_MMR_ADDRESS + 'h10): begin
                            control[31:24]  <= (PSTRB[3])? PWDATA[31:24] : control[31:24];
                            control[23:16]  <= (PSTRB[2])? PWDATA[23:16] : control[23:16];
                            control[15:08]  <= (PSTRB[1])? PWDATA[15:08] : control[15:08];
                            control[07:00]  <= (PSTRB[0])? PWDATA[07:00] : control[07:00];
                        end
                        (BASE_MMR_ADDRESS + 'h14): begin
                            status_clear[31:24]  <= (PSTRB[3])? PWDATA[31:24] : status_clear[31:24];
                            status_clear[23:16]  <= (PSTRB[2])? PWDATA[23:16] : status_clear[23:16];
                            status_clear[15:08]  <= (PSTRB[1])? PWDATA[15:08] : status_clear[15:08];
                            status_clear[07:00]  <= (PSTRB[0])? PWDATA[07:00] : status_clear[07:00];
                        end
                        (BASE_MMR_ADDRESS + 'h18): begin
                            interrupt_en[31:24]  <= (PSTRB[3])? PWDATA[31:24] : interrupt_en[31:24];
                            interrupt_en[23:16]  <= (PSTRB[2])? PWDATA[23:16] : interrupt_en[23:16];
                            interrupt_en[15:08]  <= (PSTRB[1])? PWDATA[15:08] : interrupt_en[15:08];
                            interrupt_en[07:00]  <= (PSTRB[0])? PWDATA[07:00] : interrupt_en[07:00];
                        end

                        `ifdef DMA_SUPPORT
                        (BASE_MMR_ADDRESS + 'h22): begin
                            dma_tx_baddress[31:24]  <= (PSTRB[3])? PWDATA[31:24] : dma_tx_baddress[31:24];
                            dma_tx_baddress[23:16]  <= (PSTRB[2])? PWDATA[23:16] : dma_tx_baddress[23:16];
                            dma_tx_baddress[15:08]  <= (PSTRB[1])? PWDATA[15:08] : dma_tx_baddress[15:08];
                            dma_tx_baddress[07:00]  <= (PSTRB[0])? PWDATA[07:00] : dma_tx_baddress[07:00];
                        end
                        (BASE_MMR_ADDRESS + 'h26): begin
                            dma_rx_baddress[31:24]  <= (PSTRB[3])? PWDATA[31:24] : dma_rx_baddress[31:24];
                            dma_rx_baddress[23:16]  <= (PSTRB[2])? PWDATA[23:16] : dma_rx_baddress[23:16];
                            dma_rx_baddress[15:08]  <= (PSTRB[1])? PWDATA[15:08] : dma_rx_baddress[15:08];
                            dma_rx_baddress[07:00]  <= (PSTRB[0])? PWDATA[07:00] : dma_rx_baddress[07:00];
                        end
                        (BASE_MMR_ADDRESS + 'h30): begin
                            dma_tx_size[31:24]  <= (PSTRB[3])? PWDATA[31:24] : dma_tx_size[31:24];
                            dma_tx_size[23:16]  <= (PSTRB[2])? PWDATA[23:16] : dma_tx_size[23:16];
                            dma_tx_size[15:08]  <= (PSTRB[1])? PWDATA[15:08] : dma_tx_size[15:08];
                            dma_tx_size[07:00]  <= (PSTRB[0])? PWDATA[07:00] : dma_tx_size[07:00];
                        end
                        (BASE_MMR_ADDRESS + 'h34): begin
                            dma_rx_size[31:24]  <= (PSTRB[3])? PWDATA[31:24] : dma_rx_size[31:24];
                            dma_rx_size[23:16]  <= (PSTRB[2])? PWDATA[23:16] : dma_rx_size[23:16];
                            dma_rx_size[15:08]  <= (PSTRB[1])? PWDATA[15:08] : dma_rx_size[15:08];
                            dma_rx_size[07:00]  <= (PSTRB[0])? PWDATA[07:00] : dma_rx_size[07:00];
                        end
                        `endif
                        default:               PSLVERR      = 1'b1; // NOTE: generating an rtl_rom
                    endcase
                end
                else begin // read from registers
                    case (PADDR)
                        (BASE_MMR_ADDRESS + 'h04): PRDATA = rx_data_reg;
                        (BASE_MMR_ADDRESS + 'h08): PRDATA = baud;
                        (BASE_MMR_ADDRESS + 'h0c): PRDATA = status ;
                        (BASE_MMR_ADDRESS + 'h10): PRDATA = control;
                        (BASE_MMR_ADDRESS + 'h18): PRDATA = interrupt_en;
                        default:               PSLVERR      = 1'b1; // NOTE: generating an rtl_rom
                    endcase
                end
            end
        end

    // Data capture from DMA/Bus for tx
        // TODO: Verify functionality

        localparam [1:0] TX_IDLE = 2'd0, TX_FETCH_BUS = 2'd1, TX_FETCH_DMA = 2'd2, TX_SEND_DATA = 2'd3; // states for data fetch

        reg [3:0] tx_strb, tx_strb_next;

        assign tx_fifo_write_en = ((tx_state == TX_SEND_DATA) && TX_NOTFULL);

        reg [BUS_WIDTH - 1:0] tx_buffer, tx_buffer_next;
        `ifdef DMA_SUPPORT
        reg [BUS_WIDTH - 1:0] dma_read_address_next;
        `endif

        assign TX_DATA      = tx_buffer[7:0];
        // Register Logic
            always @(posedge clk, negedge resetn)
                if (!resetn) begin
                    tx_state  <= TX_IDLE;
                    tx_buffer <= 0;
                    tx_strb   <= 'd0;
                    `ifdef DMA_SUPPORT
                        dma_read_address <= dma_tx_baddress;
                    `endif
                end else begin
                    tx_state  <= tx_state_next; // NOTE: generating an rtl_rom
                    tx_buffer <= tx_buffer_next;
                    tx_strb      <= tx_strb_next;
                    new_tx_data <= (PADDR == (BASE_MMR_ADDRESS) && PWRITE)? 1'b1 : 1'b0;
                    `ifdef DMA_SUPPORT
                        dma_read_address <= dma_read_address_next;
                    `endif
                end

        // tx state logic
            always @(*) begin // TODO: Complete integrating DMA
                tx_buffer_next = 'd0;
                tx_state_next  = tx_state;
                tx_strb_next   = 4'b0000;
                `ifdef DMA_SUPPORT
                DMA_TX_DONE    = 1'b0;
                dma_read_req   = 1'b0;
                dma_read_address_next = dma_tx_baddress;
                `endif

                case (tx_state)
                    TX_IDLE: begin
                        `ifdef DMA_SUPPORT
                            if (dma_tx_en && (dma_read_address <= dma_tx_baddress + dma_tx_size))
                                tx_state_next = TX_FETCH_DMA;
                            else if ((!dma_tx_en) && (new_tx_data))
                                tx_state_next = TX_FETCH_BUS;
                        `else // Data from bus
                            tx_state_next = (new_tx_data)? TX_FETCH_BUS : TX_IDLE;
                        `endif
                    end
                    TX_FETCH_BUS: begin
                        tx_strb_next = strb_reg;
                        tx_buffer_next = tx_data_reg;
                        tx_state_next = TX_SEND_DATA;
                    end
                    TX_FETCH_DMA: begin // TODO: Revise fuckall
                        `ifdef DMA_SUPPORT
                            dma_read_address_next = dma_read_address + 'd1;
                            dma_read_req = 1'b1;
                            if (dma_read_address < )
                            if (dma_read_clr) begin
                                tx_buffer_next = {16'd0, dma_read_data};
                                tx_strb_next = {1'b1, tx_strb[31:8]}
                                tx_state_next = (dma_read_clr) TX_SEND_DATA : TX_FETCH_DMA;
                            else
                                tx_buffer_next = 'dz;
                        `endif
                    end
                    TX_SEND_DATA: begin
                        if (TX_NOTFULL && tx_strb[0] != 0) begin
                            tx_strb_next = tx_strb >> 1;
                            tx_buffer_next = {8'd0, tx_buffer[31:8]};
                        end

                        `ifdef DMA_SUPPORT
                        if (dma_tx_en)
                            tx_state_next = (dma_read_address == dma_tx_baddress + dma_tx_size)? TX_IDLE : TX_FETCH_DMA;
                            DMA_TX_DONE = (dma_read_address == dma_tx_baddress + dma_tx_size);
                        else
                        `endif
                            tx_state_next = (tx_strb[0])? TX_SEND_DATA : TX_IDLE;

                    end
                    default: begin
                        tx_state_next = TX_IDLE;
                    end
                endcase
            end

    // Write to DMA/bus from rx
        // TODO: Verify functionality

        localparam [1:0] RX_IDLE = 2'd0, RX_RECEIVE_DATA = 2'd1, RX_SEND_DATA = 2'd2; // states for data fetch

        reg [3:0] rx_strb, rx_strb_next;

        reg [1:0] rx_state, rx_state_next;
        reg [31:0] rx_data_next;

        reg [BUS_WIDTH - 1:0] rx_buffer, rx_buffer_next;

        assign rx_fifo_read_en = (rx_state == RX_RECEIVE_DATA);

        // Register Logic
            always @(posedge clk, negedge resetn)
                if (!resetn) begin
                    rx_state <= RX_IDLE;
                    rx_buffer <= 'd0;
                    rx_strb <= 4'd0;
                    rx_data_reg <= 'd0;
                end else begin
                    rx_state <= rx_state_next;
                    rx_buffer <= rx_buffer_next;
                    rx_strb <= rx_strb_next;
                    rx_data_reg <= rx_data_next;
                end

        // rx state logic
            always @(*) begin
                rx_buffer_next = 'd0;
                rx_strb_next   = 4'b0000;
                rx_state_next  = rx_state; // NOTE: generating an rtl_rom
                rx_data_next   = rx_data_reg;

                case (rx_state)
                    RX_IDLE: begin
                        rx_state_next = (RX_NOTEMPTY)? RX_RECEIVE_DATA : RX_IDLE;
                        rx_strb_next = 4'b0000;
                    end
                    RX_RECEIVE_DATA: begin
                        if (RX_NOTEMPTY) begin
                            rx_buffer_next = {rx_buffer[23:0], RX_DATA};
                            rx_strb_next = {rx_strb[3:1], 1'b1};
                        end
                        else begin
                            rx_state_next = RX_SEND_DATA;
                        end

                        `ifdef DMA_SUPPORT // TODO: Integrate DMA
                            if (rx_strb == 4'b0011) || (rx_strb == 4'b1111) begin
                                dma_write_req = 1'b1;
                                dma_write_data[15:8] = (rx_strb[1])? rx_buffer[15:8] : 8'd0;
                                dma_write_data[ 7:0] = (rx_strb[0])? rx_buffer[ 7:0] : 8'd0;
                            end
                                // if (dma_write_clr)
                        `endif
                    end
                    RX_SEND_DATA: begin
                        rx_data_next[31:24] = (rx_strb[3])? rx_buffer[31:24] : 8'd0;
                        rx_data_next[23:16] = (rx_strb[2])? rx_buffer[23:16] : 8'd0;
                        rx_data_next[15: 8] = (rx_strb[1])? rx_buffer[15: 8] : 8'd0;
                        rx_data_next[ 7: 0] = (rx_strb[0])? rx_buffer[ 7: 0] : 8'd0;

                        rx_state_next = RX_IDLE; // : TX_SEND_DATA;
                    end
                    default: begin
                        rx_state_next = RX_IDLE;
                    end
                endcase
            end

    // Interrupt
        wire [31:0] interrupt_mask;
        assign interrupt_mask = interrupt_en && status;
        assign interrupt = |interrupt_mask;

endmodule
