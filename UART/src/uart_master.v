`include "uart_settings.vh"

module uart_master #(
    parameter integer BUS_WIDTH  = 32,
                      BASE_MMR_ADDRESS  = 32'h0000_0000
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

    // tx/rx data signals
    output                [ 7:0] TX_DATA,
    input                 [ 7:0] RX_DATA,

    // configuration signals
    output                [31:0] BAUD,
    output                [ 1:0] PARITY_MODE, // (8N*, 8O*, 8E*) -> (0, 1, 2)
    output                [ 1:0] STOP_BITS,   // 0 - 2

    // status signals
    input                        TX_DONE,
    input                        TX_FREE,
    input                        RX_DONE,
    // interrupt signals
    input                        PARITY_ERROR,
    input                        FRAME_ERROR,
    input                        OVERRUN_ERROR,
    input                        BREAK_ERROR,
    output                       interrupt,

    output                       tx_start,
    output reg                   settings_resetn,
    output reg                   tx_data_lock,
    output                       TX_REG_FREE,

    // Probes
    output                       [31:0] probe_tx_reg,
    output                              probe_tx_state,
    output                              probe_busy
);
    
    reg busy, busy_next; // TODO: check busy functionality
    reg new_tx_data;
    assign PREADY = PSELx & PENABLE & ~busy;

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

        reg tx_state, tx_state_next;
        localparam TX_IDLE = 0, TX_SEND_DATA = 1; // states for data fetch

        assign BAUD         = baud;
        assign PARITY_MODE  = control[3:2];
        assign STOP_BITS    = control[1:0];

        // busy fsm
            always @(*) begin
                busy_next = busy;
                case (busy)
                    0: begin
                        // if (PSELx && PWRITE && (PADDR == BASE_MMR_ADDRESS + 'h00)) begin
                            if (tx_state != TX_IDLE) begin
                                busy_next = 1'b1;
                            end
                        // end 
                    end
                    1: begin
                        if (tx_state == TX_IDLE) begin
                            busy_next = 1'b0;
                        end
                    end
                default: begin
                    busy_next = 1'b0;
                end
                endcase
            end

        // asynchronous reseting and Writing Registers
            always@(posedge clk) begin //, negedge resetn) begin // NOTE: causes error with yosys
                new_tx_data = 0;
                settings_resetn = 1'b1;
                PSLVERR = 1'b0;

                // busy fsm switch
                    if (!resetn) begin
                        busy <= 1'b0;
                    end else begin
                        busy <= busy_next;
                    end

                // ERROR_reg logic
                    if (!resetn) begin
                        BREAK_ERROR_reg <= 1'b0;
                        FRAME_ERROR_reg <= 1'b0;
                        OVERRUN_ERROR_reg <= 1'b0;
                        PARITY_ERROR_reg <= 1'b0;
                    end
                    else begin
                        if(status_clear[7])
                            BREAK_ERROR_reg <= 1'b0;
                        else if (BREAK_ERROR)
                            BREAK_ERROR_reg <= 1'b1;

                        if(status_clear[6])
                            FRAME_ERROR_reg <= 1'b0;
                        else if (FRAME_ERROR)
                            FRAME_ERROR_reg <= 1'b1;

                        if(status_clear[5])
                            OVERRUN_ERROR_reg <= 1'b0;
                        else if (OVERRUN_ERROR)
                            OVERRUN_ERROR_reg <= 1'b1;

                        if(status_clear[4])
                            PARITY_ERROR_reg <= 1'b0;
                        else if (PARITY_ERROR)
                            PARITY_ERROR_reg <= 1'b1;
                    end

                // status logic
                    status = {24'd0, BREAK_ERROR_reg, FRAME_ERROR_reg, OVERRUN_ERROR_reg, PARITY_ERROR_reg,
                            TX_DONE, TX_FREE, TX_REG_FREE, RX_DONE};

                // register read and write
                    if (!resetn) begin // reset register to default values
                        baud         <= 'ha2c;
                        tx_data_reg  <= 'h0;
                        status        = 'h7;
                        control      <= 'h4;
                        status_clear <= 'h0;
                        interrupt_en <= 'h0;
                        strb_reg     <= 'h0;
                    end
                    else if (PREADY) begin
                        if (PWRITE) begin // write to registers
                            case (PADDR)
                                (BASE_MMR_ADDRESS + 'h00): begin
                                    if (!tx_data_lock) begin // || tx_state == TX_SEND_DATA) begin // TODO: improve delay (clock cycles) between writes to tx_data_reg
                                        new_tx_data = 1;
                                        strb_reg            <= PSTRB;
                                        tx_data_reg[31:24]  <= (PSTRB[3])? PWDATA[31:24] : tx_data_reg[31:24];
                                        tx_data_reg[23:16]  <= (PSTRB[2])? PWDATA[23:16] : tx_data_reg[23:16];
                                        tx_data_reg[15:08]  <= (PSTRB[1])? PWDATA[15:08] : tx_data_reg[15:08];
                                        tx_data_reg[07:00]  <= (PSTRB[0])? PWDATA[07:00] : tx_data_reg[07:00];
                                    end
                                end
                                (BASE_MMR_ADDRESS + 'h08): begin
                                    baud[31:24]  <= (PSTRB[3])? PWDATA[31:24] : baud[31:24];
                                    baud[23:16]  <= (PSTRB[2])? PWDATA[23:16] : baud[23:16];
                                    baud[15:08]  <= (PSTRB[1])? PWDATA[15:08] : baud[15:08];
                                    baud[07:00]  <= (PSTRB[0])? PWDATA[07:00] : baud[07:00];
                                    settings_resetn = 1'b0;
                                end
                                (BASE_MMR_ADDRESS + 'h10): begin
                                    control[31:24]  <= (PSTRB[3])? PWDATA[31:24] : control[31:24];
                                    control[23:16]  <= (PSTRB[2])? PWDATA[23:16] : control[23:16];
                                    control[15:08]  <= (PSTRB[1])? PWDATA[15:08] : control[15:08];
                                    control[07:00]  <= (PSTRB[0])? PWDATA[07:00] : control[07:00];
                                    settings_resetn = 1'b0;
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
                                default:                   PSLVERR      = 1'b1; // NOTE: generating an rtl_rom
                            endcase
                        end
                    end
            end

    // Data capture from Bus for tx
        reg [3:0] tx_strb, tx_strb_next;
        reg tx_data_lock_next;

        reg [BUS_WIDTH - 1:0] tx_buffer, tx_buffer_next;

        assign TX_DATA      = (tx_state == TX_IDLE)? 8'h00 : tx_buffer[7:0];
        // Register Logic
            always @(posedge clk, negedge resetn) begin // TODO: check negedge busy
                if (!resetn) begin
                    tx_state  <= TX_IDLE;
                    tx_buffer <= 0;
                    tx_strb   <= 'd0;
                    tx_data_lock <= 0;
                end else begin
                    tx_state  <= tx_state_next; // NOTE: generating an rtl_rom
                    tx_buffer <= tx_buffer_next;
                    tx_strb     <= tx_strb_next;
                    tx_data_lock <= tx_data_lock_next;
                end
            end

        // tx state logic
            always @(*) begin
                tx_strb_next = tx_strb;
                tx_buffer_next = tx_buffer;
                tx_state_next  = tx_state;
                tx_data_lock_next = tx_data_lock;

                case (tx_state)
                    TX_IDLE: begin
                        tx_data_lock_next = (new_tx_data && strb_reg != 4'd0);

                        if (tx_data_lock) begin
                            tx_strb_next   = strb_reg;
                            tx_buffer_next = tx_data_reg;
                            tx_state_next  = TX_SEND_DATA;
                        end
                    end
                    TX_SEND_DATA: begin
                        tx_data_lock_next = 1'b1;
                        if (TX_FREE && (tx_strb[1] != 0)) begin
                            tx_strb_next = {1'b0, tx_strb[3:1]};
                            tx_buffer_next = {8'd0, tx_buffer[31:8]};
                        end
                        else if ((tx_strb[1] == 0) && TX_DONE) begin
                            tx_data_lock_next = 1'b0;
                            tx_strb_next = {1'b0, tx_strb[3:1]};
                            tx_state_next = TX_IDLE;
                        end
                    end
                    default: begin
                        tx_state_next = TX_IDLE;
                    end
                endcase
            end

        assign tx_start = (tx_state == TX_SEND_DATA);

    // Write to bus from rx
        // TODO: Verify functionality

        localparam [1:0] RX_IDLE = 2'd0, RX_RECEIVE_DATA = 2'd1, RX_SEND_DATA = 2'd2; // states for data fetch

        reg [3:0] rx_strb, rx_strb_next;

        reg [1:0] rx_state, rx_state_next;
        reg [31:0] rx_data_next;

        reg [BUS_WIDTH - 1:0] rx_buffer, rx_buffer_next;

        // Register Logic
            always @(posedge clk, negedge resetn) begin
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
            end

        // rx state logic
            always @(*) begin
                rx_buffer_next = rx_buffer;
                rx_strb_next   = rx_strb;
                rx_state_next  = rx_state; // NOTE: generating an rtl_rom
                rx_data_next   = rx_data_reg;

                case (rx_state)
                    RX_IDLE: begin
                        rx_buffer_next = 32'd0;
                        rx_strb_next = 4'b0000;
                        if (RX_DONE) begin
                            rx_state_next = RX_RECEIVE_DATA;
                            rx_buffer_next = {24'd0, RX_DATA};
                        end
                    end
                    RX_RECEIVE_DATA: begin
                        if (RX_DONE) begin
                            rx_buffer_next = {rx_buffer[23:0], RX_DATA};
                            rx_strb_next = {rx_strb[2:0], 1'b1};
                        end
                        else if (rx_strb >= 4'b0111) begin
                            rx_strb_next = {rx_strb[2:0], 1'b1};
                            rx_state_next = RX_SEND_DATA;
                        end

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
        assign TX_REG_FREE = (tx_strb == 4'd0) && ~tx_data_lock;
        wire [31:0] interrupt_mask;
        assign interrupt_mask = interrupt_en & status;
        assign interrupt = |interrupt_mask;

    assign probe_tx_reg = tx_data_reg; // TODO: temp
    assign probe_tx_state = tx_state; // TODO: temp
    assign probe_busy = busy;

endmodule
