`timescale 1ns/1ns

module test;

    logic [31:0] probe;
 
    // logic rx, tx;
    logic interrupt;

    logic PCLK, PRESETn; // System bus equivalent Reset
    logic [31:0] PADDR, PWDATA;
    logic PSELx, PENABLE, PWRITE;
    logic [3:0] PSTRB;

    logic [31:0] PRDATA;
    logic PREADY, PSLVERR;

    logic [7:0] TX_DATA;
    logic [7:0] RX_DATA;
    logic [1:0] PARITY_MODE, STOP_BITS;
    logic [31:0] BAUD;
    logic PARITY_ERROR, FRAME_ERROR, BREAK_ERROR;


    logic       rx_done_tick;    // data word received
    logic       tx_done_tick;    // data transmission complete
    logic       tx_fifo_full, tx_fifo_empty;
    logic       rx_fifo_full, rx_fifo_empty;
    logic       rx_fifo_read_en, tx_fifo_write_en;

    localparam [31:0] tx_data_address        ='h0 ; // write     
    localparam [31:0] rx_data_address        ='h4 ; // read      
    localparam [31:0] baud_address           ='h8 ; // read-write
    localparam [31:0] status_address         ='hc ; // read      
    localparam [31:0] control_address        ='h10; // read-write
    localparam [31:0] status_clear_address   ='h14; // write     
    localparam [31:0] interrupt_en_address   ='h18; // read-write

    uart_master UART_MASTER (
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

        .TX_DATA(TX_DATA),
        .RX_DATA(RX_DATA),

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
        .rx_fifo_read_en(rx_fifo_read_en),

        .probe(probe)
    );
    //uart_top dut_c(
    //      rx,
    //      tx,
    //      interrupt,

    //      // APB ports
    //      PCLK,
    //      PRESETn, // System bus equivalent Reset

    //      PADDR,   // Address
    //      PSELx,   // Select
    //      PENABLE, // Enable
    //      PWRITE,  // Direction
    //      PWDATA,  // Write data
    //      PSTRB,   // Write strobes

    //      PREADY,  // Slave interface Ready
    //      PRDATA,  // Slave interface Read Data
    //      PSLVERR // Slave interface Transfer error
	  //);

    integer i,j;
    initial
    begin
        PCLK <= 0;
        forever #5 PCLK = ~PCLK;
    end

    initial
    begin
                                   PRESETn <= 0; PSELx <= 0; PENABLE = 0;
              @(posedge PCLK)      PRESETn = 1;
                                   RX_DATA = 8'ha; rx_fifo_empty = 0;
                                   tx_done_tick = 1; tx_fifo_full = 0;
    repeat(2) @(posedge PCLK);

              @(posedge PCLK)      Write_data(baud_address, 'd1, 4'b0001);
    repeat(2) @(posedge PCLK);

              @(posedge PCLK)      Read_data(baud_address);
    repeat(2) @(posedge PCLK);

              @(posedge PCLK)      PRESETn = 0;
              @(posedge PCLK)      PRESETn = 1;
    repeat(2) @(posedge PCLK);

              @(posedge PCLK)      Write_data(tx_data_address, 32'hdeadbeef, 4'b1111);
    repeat(2) @(posedge PCLK);

              @(posedge PCLK)      Write_data(tx_data_address, 32'h1111dcba, 4'b1111);
    repeat(2) @(posedge PCLK);

              @(posedge PCLK)      Read_data(status_address);
    repeat(4) @(posedge PCLK);

    $finish;
    end

    task Write_data;
      input [31:0] addr, data;
      input [3:0]  strb;
    begin
        @(posedge PCLK);
            PSELx = 1;
            PWRITE = 1;
            PADDR = addr;
            PWDATA = data;
            PSTRB = strb;

        @(posedge PCLK);
            PENABLE = 1;

        @(posedge PCLK);
            PENABLE = 0;
        // @(negedge PCLK);
            PSELx = 0;
    end
    endtask

    task Read_data;
      input [31:0] addr;
    begin 
        @(posedge PCLK);
            PSELx = 1;
            PWRITE = 0;
            PADDR = addr;
            PSTRB = 4'b0000;

        @(posedge PCLK);
            PENABLE = 1;

        @(posedge PCLK);
            PENABLE = 0;
        // @(negedge PCLK);
            PSELx = 0;
    end
    endtask

    //
    // initial
    // begin
    //   $dumpfile("apbWaveform.vcd");
    //   $dumpvars;
    // end

  endmodule
