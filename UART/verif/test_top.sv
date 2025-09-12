`timescale 1ns/1ns

module test_top; 
    // (
    // input logic clk,
    // input logic resetn,
    // output logic sim_done
    // );
    logic sim_done;

    // probe wires
        logic [31:0] probe_baud;
        logic [ 1:0] probe_tx_state;
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

    // dut initialize
        apb_uart_top #(
            .BAUD(1),
            .CLK_FREQ(8),
            .PARITY_MODE(0),
            .STOP_BITS(1)
        ) dut (
            .rx(rx),
            .tx(tx),

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
            .probe_tick(probe_tick)
	      );

    initial begin
        PCLK = 0;
        forever #5 PCLK = ~PCLK;
    end

    initial begin // Test cases
                                       sim_done = 0;
                  @(posedge PCLK);     PRESETn = 1; PSELx = 0; PENABLE = 0;
                  @(posedge PCLK);     PRESETn = 0; rx = 1;
                  @(posedge PCLK);     PRESETn = 1;
        repeat(2) @(posedge PCLK);

                  @(posedge PCLK);      Write_data(tx_data_address, 32'h000000a5, 4'b1111);
        repeat(2) @(posedge PCLK);


                  @(posedge PCLK);      Write_data(tx_data_address, 32'h000000c3, 4'b0011);

        repeat(100) @(posedge PCLK);    Write_data(tx_data_address, 32'h000000c3, 4'b0011);

        repeat(10) @(posedge PCLK);     Write_rx(8'ha5, 1'b1);
        repeat( 4) @(posedge PCLK);     Read_data(rx_data_address);
        repeat(10) @(posedge PCLK);     Write_rx(8'hc3, 1'b1);
        repeat( 4) @(posedge PCLK);     Read_data(rx_data_address);



        repeat(200) @(posedge PCLK);     sim_done = 1;

        $finish;
    end

    // initial begin
    //     repeat (1500) @(posedge PCLK); // timeout
    //     $finish;
    // end

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

    task Write_rx;
        input [7:0] data;
        input       parity;
        begin
            repeat (4) @(posedge probe_tick); rx = 0;
            for (int i = 0; i < 8 ; i++) begin
                repeat (4) @(posedge probe_tick); rx = data[i];
            end
            repeat (4) @(posedge probe_tick); rx = parity;
            repeat (4) @(posedge probe_tick); rx = 1;
        end
    endtask

    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars;
    end

endmodule
