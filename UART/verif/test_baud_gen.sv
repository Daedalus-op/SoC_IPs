`timescale 1ns/1ns

module test_baud_gen;

    // probe wires
        // logic [ 1:0] probe_tx_state;
        // logic        probe_busy;
 
    // testbench wires
        // logic rx, tx;
        // logic interrupt;

        logic PCLK, PRESETn; // System bus equivalent Reset
        logic [31:0] BAUD;
        logic tick;

    // dut initialize
        baud_rate_generator #( // baud tick generator
        ) BAUD_RATE_GEN (
            .clk(PCLK),
            .resetn(PRESETn),
            .baud_rate(BAUD),
            .tick(tick)
        );

    initial begin
        PCLK <= 0;
        forever #5 PCLK = ~PCLK;
    end

    initial begin // Test cases
        repeat(2) @(posedge PCLK);

                  @(posedge PCLK)      BAUD = 32'd2;
                  @(posedge PCLK)      PRESETn = 1;
                  @(posedge PCLK)      PRESETn = 0;
                  @(posedge PCLK)      PRESETn = 1;

        repeat(8) @(posedge PCLK);

        $finish;
    end

endmodule
