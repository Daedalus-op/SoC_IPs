`timescale 1ns/1ns

module test_top;

    // probe wires
        logic [31:0] probe_baud;
        logic [ 1:0] probe_tx_state;
        // logic        probe_busy;
        logic        probe_tick;
        logic        probe_fifo_write_en;
 
    // testbench wires
        logic rx, tx;
        logic interrupt;

        logic PCLK, PRESETn; // System bus equivalent Reset
        logic [31:0] PADDR, PWDATA;
        logic PSELx, PENABLE, PWRITE;
        logic [3:0] PSTRB;

        logic [31:0] PRDATA;
        logic PREADY, PSLVERR;

    // register addresses
        localparam [31:0] tx_data_address        ='h0 ; // write     
        localparam [31:0] rx_data_address        ='h4 ; // read      
        localparam [31:0] baud_address           ='h8 ; // read-write
        localparam [31:0] status_address         ='hc ; // read      
        localparam [31:0] control_address        ='h10; // read-write
        localparam [31:0] status_clear_address   ='h14; // write     
        localparam [31:0] interrupt_en_address   ='h18; // read-write

    // dut initialize
        uart_top dut_c(
            .rx(rx),
            .tx(tx),
            .interrupt(interrupt),

            // APB ports
            .PCLK(PCLK),
            .PRESETn(PRESETn), // System bus equivalent Reset

            .PADDR(PADDR),     // Address
            .PSELx(PSELx),     // Select
            .PENABLE(PENABLE), // Enable
            .PWRITE(PWRITE),   // Direction
            .PWDATA(PWDATA),   // Write data
            .PSTRB(PSTRB),     // Write strobes

            .PREADY(PREADY),   // Slave interface Ready
            .PRDATA(PRDATA),   // Slave interface Read Data
            .PSLVERR(PSLVERR), // Slave interface transfer error
            .probe_baud(probe_baud),
            .probe_fifo_write_en(probe_fifo_write_en),
            .probe_tick(probe_tick)
	      );

    initial begin
        PCLK <= 0;
        forever #5 PCLK = ~PCLK;
    end

    initial begin // Test cases
                  @(posedge PCLK);     PRESETn = 1; PSELx = 0; PENABLE = 0;
                  @(posedge PCLK);     PRESETn = 0;
                  @(posedge PCLK);     PRESETn = 1;
        repeat(2) @(posedge PCLK);

                  @(posedge PCLK)      Write_data(baud_address, 'd3, 4'b0001);
        repeat(2) @(posedge PCLK);

                  @(posedge PCLK)      Read_data(baud_address);
        repeat(2) @(posedge PCLK);

                  @(posedge PCLK)      PRESETn = 0;
                  @(posedge PCLK)      PRESETn = 1;
        repeat(2) @(posedge PCLK);

                  @(posedge PCLK)      Write_data(tx_data_address, 32'hdeadbeef, 4'b1111);

                  @(posedge PCLK)      Write_data(tx_data_address, 32'h1111dcba, 4'b0011);

                  @(posedge PCLK)      Read_data(status_address);

                  @(posedge PCLK)      Write_data(interrupt_en_address, 32'h00000040, 4'b0001);

                  @(posedge PCLK)      Write_data(status_clear_address, 32'h000000ff, 4'b0001);

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
        if (!PREADY) begin
            @(posedge (PREADY & PCLK));
            @(posedge PCLK);
        end

            PENABLE = 0;
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
        if (!PREADY) begin
            @(posedge (PREADY & PCLK));
            @(posedge PCLK);
        end

            PENABLE = 0;
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
