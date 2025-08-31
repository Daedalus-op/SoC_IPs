`timescale 1ns/1ns

module test;
 
    wire rx, tx, interrupt;

    reg PCLK, PRESETn; // System bus equivalent Reset
    reg [31:0] PADDR, PWDATA;
    reg PSELx, PENABLE, PWRITE;
    reg [3:0] PSTRB;

    wire [31:0] PRDATA;
    wire PREADY, PSLVERR;

    wire [7:0] TX_DATA;
    reg  [7:0] RX_DATA;
    wire [1:0] PARITY_MODE, STOP_BITS;
    wire [31:0] BAUD;
    wire PARITY_ERROR, FRAME_ERROR, BREAK_ERROR;


    reg       rx_done_tick;    // data word received
    reg       tx_done_tick;    // data transmission complete
    reg       tx_fifo_full, tx_fifo_empty;
    reg       rx_fifo_full, rx_fifo_empty;
    reg       rx_fifo_read_en, tx_fifo_write_en;

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
        .rx_fifo_read_en(rx_fifo_read_en)
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
              @(posedge PCLK)      PRESETn = 1;                                     //no write address available but request for write operation
    repeat(2) @(posedge PCLK);
              @(negedge PCLK)      Write_data(baud_address, 'd1);        // write operation

    repeat(2) @(posedge PCLK);
    //           @(posedge PCLK)     PRESETn<=0; transfer<=0; 
    //           @(posedge PCLK)     PRESETn = 1;
    // repeat(3) @(posedge PCLK)     transfer = 1;                             // no read address available but request for read operation
    // repeat(2) @(posedge PCLK)     Read_slave1;                             //read operation
    //
    // repeat(3) @(posedge PCLK);   Read_slave2;
    // repeat(3) @(posedge PCLK);   apb_read_paddr = 9'd45;                 //data not inserted in write operation but requested for read operation
    // repeat(4) @(posedge PCLK);
    $finish;
    end

    task Write_data;
      input [31:0] addr, data;
    begin
        @(posedge PCLK);
            PSELx = 1;
            PWRITE = 1;
            PADDR = addr;
            PWDATA = data;
            PSTRB = 4'b1111;

        @(posedge PCLK);
            PENABLE = 1;

        repeat(2)@(posedge PCLK);
            PSELx = 0;
            PENABLE = 0;
    end
    endtask

    task Read_data;
      input [31:0] addr;
    begin 
        @(posedge PCLK);
            PSELx = 1;
            PWRITE = 1;
            PADDR = addr;
            PSTRB = 4'b0000;

        @(posedge PCLK);
            PENABLE = 1;

        repeat(2)@(posedge PCLK);
            PSELx = 0;
            PENABLE = 0;
    end
    endtask

    //
    // initial
    // begin
    //   $dumpfile("apbWaveform.vcd");
    //   $dumpvars;
    // end

  endmodule
