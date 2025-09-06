#include "verilated.h"
#include "Vkian_sim.h"      // Generated top module header from Verilator
#include "verilated_vcd_c.h"  // Optional: for waveform dumping
#include <iostream>

vluint64_t main_time = 0;  // Current simulation time
const unsigned int CLK_PERIOD = 10; // 10 time units clock period

// Called by $time in Verilog
double sc_time_stamp() {
    return main_time;
}

int main(int argc, char** argv, char** env) {
    Verilated::commandArgs(argc, argv);
    Vkian_sim* top = new Vkian_sim;

    VerilatedVcdC* tfp = nullptr;
    bool waveform_on = false;
    for (int i = 1; i < argc; i++) {
        if (std::string(argv[i]) == "+trace") {
            waveform_on = true;
            Verilated::traceEverOn(true);
            tfp = new VerilatedVcdC;
            top->trace(tfp, 99);
            tfp->open("waveform.vcd");
        }
    }

    // Initialize inputs
    top->clk = 0;
    top->resetn = 0;
    // vluint64_t timeout = 10000000;  // Default timeout cycles
    //
    // // Parse timeout from plusargs if provided
    // for (int i = 1; i < argc; i++) {
    //     if (strncmp(argv[i], "+timeout=", 9) == 0) {
    //         timeout = std::stoull(argv[i] + 9);
    //     }
    // }

    // Reset pulse for a few cycles
    for (int i = 0; i < 10; i++) {
        top->clk = 0;
        top->resetn = 0;
        top->eval();
        if (waveform_on) tfp->dump(main_time);
        main_time += CLK_PERIOD / 2;

        top->clk = 1;
        top->eval();
        if (waveform_on) tfp->dump(main_time);
        main_time += CLK_PERIOD / 2;
    }

    top->resetn = 1;

    // Main simulation loop
    bool done = false;
    while (!done){ // && main_time < timeout * CLK_PERIOD) {
        // Clock low phase
        top->clk = 0;
        top->eval();
        if (waveform_on) tfp->dump(main_time);
        main_time += CLK_PERIOD / 2;

        // Clock high phase
        top->clk = 1;
        top->eval();
        if (waveform_on) tfp->dump(main_time);
        main_time += CLK_PERIOD / 2;

        // Check sim_done signal exposed via public_flat_rw
        if (top->sim_done) {
            std::cout << "[" << main_time << "] Simulation DONE signal detected." << std::endl;
            done = true;
        }
    }

    // if (!done) {
    //     std::cerr << "Simulation timeout after " << timeout << " cycles." << std::endl;
    // }

    if (waveform_on) {
        tfp->close();
        delete tfp;
    }

    top->final();
    delete top;
    return done ? 0 : 1;
}
