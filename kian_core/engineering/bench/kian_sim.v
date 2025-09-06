`default_nettype none
module kian_sim (
    input wire	      clk,
    input wire	      resetn,
    output wire       sim_done
);

    wire cpu_mem_valid  /* verilator public_flat_rw */;

    wire [3:0] cpu_mem_wstrb  /* verilator public_flat_rw */;
    wire [31:0] cpu_mem_addr  /* verilator public_flat_rw */;
    wire [31:0] cpu_mem_wdata  /* verilator public_flat_rw */;
    wire [31:0] cpu_mem_rdata  /* verilator public_flat_rw */;
    wire [63:0] counter  /* verilator public_flat_rw */;

    kianv_modified kianv_I (
        .clk           (clk),
        .resetn        (resetn),
        .mem_ready     (1'b1),
        .mem_valid     (cpu_mem_valid),
        .mem_wstrb     (cpu_mem_wstrb),
        /* verilator lint_off WIDTHEXPAND */
        .mem_addr      (cpu_mem_addr),
        /* verilator lint_on WIDTHEXPAND */
        .mem_wdata     (cpu_mem_wdata),
        .mem_rdata     (cpu_mem_rdata),
        .access_fault  (),
        .timer_counter (counter),
        .is_instruction(),
        .IRQ3          (),
        .IRQ7          (),
        .IRQ9          (),
        .IRQ11         (),
        .PC            (),
        .sim_done      (sim_done)
    );

    ram #(
    ) bram_I (
        .clk  (clk),
        .addr (cpu_mem_addr),
        .wdata(cpu_mem_wdata),
        .rdata(cpu_mem_rdata),
        .wmask(cpu_mem_wstrb),
        .sim_done(sim_done),
        .counter(counter)
    );

endmodule

