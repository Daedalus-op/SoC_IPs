`timescale 1ns/1ps
`default_nettype none

// ============================================================================
// Single-file Testbench
// - APB master tasks (write + read) that obey APB timing
// - Simple loopback: miso = mosi (so master reads back what it transmits)
// - Waveform dump (VCD) for inspection
// ============================================================================
module tb_spi_apb_single_file;
    // clock and reset
    reg PCLK = 0;
    always #5 PCLK = ~PCLK; // 100 MHz -> period 10ns

    reg PRESETn;

    // APB signals
    reg  [7:0]  PADDR;
    reg         PSEL;
    reg         PENABLE;
    reg         PWRITE;
    reg  [31:0] PWDATA;
    reg  [3:0]  PSTRB;
    wire [31:0] PRDATA;
    wire        PREADY;

    // SPI lines
    wire sclk;
    wire mosi;
    reg  miso;   // driven by testbench (slave)
    wire cs_n;

    // Instantiate DUT with a visible (small) CLK_DIV so SPI toggles reasonably in sim
    spi_apb #(.CPOL(1'b0), .CLK_DIV(4)) dut (
        .PCLK   (PCLK),
        .PRESETn(PRESETn),
        .PADDR  (PADDR),
        .PSEL   (PSEL),
        .PENABLE(PENABLE),
        .PWRITE (PWRITE),
        .PWDATA (PWDATA),
        .PSTRB  (PSTRB),
        .PRDATA (PRDATA),
        .PREADY (PREADY),
        .sclk   (sclk),
        .mosi   (mosi),
        .miso   (miso),
        .cs_n   (cs_n)
    );

    // Simple loopback mode: drive MISO with MOSI (delayed slightly to model propagation)
    // Implement as a small procedural delay to reflect a real line; use always block to sample.
    reg miso_next;
    initial begin
        miso = 0;
        miso_next = 0;
    end

    // Create a small propagation delay: when MOSI changes, update miso_next after 1 ns
    always @(mosi) begin
        #1 miso_next = mosi;
    end
    // Apply miso_next at a clock boundary (or continuously)
    always @(*) miso = miso_next;

    // ------------------------------------------------------------------------
    // APB master tasks (procedural driver)
    // APB timing:
    //   Cycle N   : PSEL=1, PENABLE=0, PWRITE as required, PADDR,PWDATA,PSTRB valid
    //   Cycle N+1 : PENABLE=1 (transfer takes place)
    //   Cycle N+2 : PSEL=0, PENABLE=0 -> idle
    // ------------------------------------------------------------------------
    
    // old tasks
        // task apb_write(input [7:0] addr, input [31:0] data);
        //     begin
        //         // drive address + write data
        //         @(posedge PCLK);
        //         PADDR   <= addr;
        //         PWRITE  <= 1;
        //         PSEL    <= 1;
        //         PWDATA  <= data;
        //         PSTRB   <= 4'hF;
        //         PENABLE <= 0;
        //         @(posedge PCLK);
        //         // enable phase
        //         PENABLE <= 1;
        //         @(posedge PCLK);
        //         // deassert
        //         PSEL    <= 0;
        //         PENABLE <= 0;
        //         PWRITE  <= 0;
        //         // small nop setup
        //         @(posedge PCLK);
        //     end
        // endtask
        //
        // task apb_read(input [7:0] addr, output [31:0] rdata);
        //     begin
        //         @(posedge PCLK);
        //         PADDR   <= addr;
        //         PWRITE  <= 0;
        //         PSEL    <= 1;
        //         PENABLE <= 0;
        //         @(posedge PCLK);
        //         PENABLE <= 1;
        //         @(posedge PCLK);
        //         rdata = PRDATA;
        //         // deassert
        //         PSEL    <= 0;
        //         PENABLE <= 0;
        //         @(posedge PCLK);
        //     end
        // endtask

    task apb_write;
        input [31:0] addr;
        input [7:0]  data;
        input [3:0]  strb;
        begin
        @(posedge PCLK);
            PSEL = 1;
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
            PSEL = 0;
        end
    endtask

    task apb_read;
        input [31:0] addr;
        begin 
        @(posedge PCLK);
            PSEL = 1;
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
            PSEL = 0;
        end
    endtask

    // ------------------------------------------------------------------------
    // Test sequence
    // 1) Reset
    // 2) Write CTRL register (addr 0x00) -> set CS active (0)
    // 3) Write TX register (addr 0x04) -> causes SPI transfer to start
    // 4) Wait for some cycles to allow transfer
    // 5) Read RX register (addr 0x08)
    // 6) Print results and dump waveforms
    // ------------------------------------------------------------------------
    integer i;
    reg [31:0] read_back;
    initial begin
        // Waveform dump
        // $dumpfile("tb_spi_apb.vcd");
        // $dumpvars(0, tb_spi_apb_single_file);

        // initialize APB signals
        PADDR   = 8'h00;
        PSEL    = 0;
        PENABLE = 0;
        PWRITE  = 0;
        PWDATA  = 32'h0000_0000;
        PSTRB   = 4'h0;

        // reset pulse
        PRESETn = 0;
        repeat(5) @(posedge PCLK);
        PRESETn = 1;
        $display("[%0t] RESET released", $time);

        // small settle
        repeat(5) @(posedge PCLK);

        // Show initial PRDATA
        $display("[%0t] PRDATA before transfers = 0x%0h", $time, PRDATA);

        // Activate CS (write control addr 0x00, PWDATA[0]=0 -> active)
        $display("[%0t] Write CTRL: assert CS (active low)", $time);
        apb_write(8'hac, 32'h0000_0000, 4'hf); // write 0 -> active
        @(posedge PCLK);
        apb_write(8'h00, 32'h0000_0000, 4'hf); // write 0 -> active
        @(posedge PCLK);

        // Write TX value(s) and read back
        for (i = 0; i < 4; i = i + 1) begin
            reg [7:0] txval;
            txval = 8'hA5 + i; // different test bytes: A5, A6, A7, A8
            $display("[%0t] Writing TX = 0x%0h", $time, txval);
            apb_write(8'h04, {24'h0, txval}, 4'hf); // write TX -> starts SPI xfer

            // Wait for a few micro-cycles to allow SPI to finish.
            // Transfer time: each bit needs CLK_DIV+ few PCLK cycles. Wait conservatively.
            repeat(200) @(posedge PCLK);

            // Read RX register
            apb_read(8'h08);
            $display("[%0t] Read RX = 0x%0h (expected ~ 0x%0h)", $time, read_back[7:0], txval);

            // small gap
            repeat(10) @(posedge PCLK);
        end

        // Deactivate CS
        $display("[%0t] Deactivate CS", $time);
        apb_write(8'h00, 32'h0000_0001, 4'hf); // write 1 -> inactive (cs_n = 1)

        // Finish
        repeat(20) @(posedge PCLK);
        $display("[%0t] Test complete. Check tb_spi_apb.vcd for waveforms.", $time);
        $finish;
    end

    // Monitor some signals to console for quick proof
    initial begin
        $display("Time   PRESETn PSEL PENABLE PWRITE PADDR PWDATA PRDATA  cs_n sclk mosi miso");
        forever begin
            @(posedge PCLK);
            $display("%0t  %b       %b    %b      %b      0x%0h  0x%0h  0x%0h  %b    %b    %b   %b",
                     $time, PRESETn, PSEL, PENABLE, PWRITE, PADDR, PWDATA, PRDATA, cs_n, sclk, mosi, miso);
        end
    end

    // initial begin
    //     $dumpfile("spi_apb_wave.vcd");
    //     $dumpvars(0, tb_spi_apb_single_file);
    // end

    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars;
    end

endmodule
